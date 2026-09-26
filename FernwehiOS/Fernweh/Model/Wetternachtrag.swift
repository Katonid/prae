import Foundation
import CoreData
import CoreLocation

// DAS WETTER JEDES TAGES AM JEWEILIGEN ORT (ab 1.0.18, Ansage des Nutzers
// 09/2026: „Ich möchte auch das Wetter an den einzelnen Tagen am jeweiligen
// Ort einfügen. Morgens, mittags, nachmittags, nachts … All das soll an das
// Fotobuch mit übergeben werden.")
//
// Geholt wurde es seit 1.0.1 — aber nur im Editor, also nur für Einträge, die
// dort geschrieben oder geöffnet wurden. Es fehlte in drei Fällen:
//
// 1. **Einträge ohne Wetter**: ältere, solche, bei denen das Netz fehlte, und
//    Einträge, deren Ort erst später kam. `nachtragen` holt es für sie — am
//    Ort des Eintrags, sonst am Ort seines ersten Fotos, sonst am ersten
//    Punkt der Spur dieses Tages.
// 2. **Vorhersagen**: Ein Tag, der beim Holen noch nicht vorbei war, ist
//    keine Messung. Sobald er vorbei ist, wird er ersetzt.
// 3. **Tage ohne Eintrag**, an denen nur eine Spur entstand. Für sie gibt es
//    keinen Datensatz, an dem das Wetter stehen könnte; es wird deshalb
//    nicht gespeichert, sondern bei Bedarf geholt und für die Sitzung
//    gemerkt (`Wettervorrat`) — für die Anzeige unter dem Tag und für die
//    Übergabe ans Fotobuch.
//
// Gedrosselt: höchstens 30 Einträge je Lauf, einer nach dem anderen. Open-
// Meteo ist frei, aber nicht zum Durchhämmern gedacht; der nächste Lauf macht
// weiter. Geschrieben wird nur, was ich bearbeiten darf.

@MainActor
enum Wetternachtrag {
    private static var laeuft = false
    /// Was in dieser Sitzung vergeblich gefragt wurde — nicht bei jedem
    /// Öffnen noch einmal.
    private static var vergeblich: Set<NSManagedObjectID> = []

    /// Braucht dieser Eintrag Wetter? Freie Seiten nie.
    static func fehlt(_ e: Eintrag) -> Bool {
        guard e.eintragsart != .seite, let tag = e.tagDatum else { return false }
        guard let w = e.tageswetter else { return (e.wetter ?? "").isEmpty }
        // Eine Vorhersage wird ersetzt, wenn der Tag gut vorbei ist.
        return w.vorhersage && Tag.ende(tag).addingTimeInterval(6 * 3600) < Date()
    }

    /// Wo das Wetter eines Eintrags gilt.
    static func ort(_ e: Eintrag) -> CLLocationCoordinate2D? {
        if let k = e.koordinate { return k }
        if let k = e.fotoListe.compactMap(\.koordinate).first { return k }
        if let k = e.streckenpunkte.first?.koordinate { return k }
        if let reise = e.reise, let tag = e.tagDatum,
           let p = reise.spuren(am: tag).flatMap(\.punktListe).min(by: { $0.zeit < $1.zeit }) {
            return p.koordinate
        }
        return nil
    }

    /// Holt fehlendes Wetter für diese Einträge. Gibt zurück, wie viele es
    /// bekommen haben.
    @discardableResult
    static func nachtragen(_ eintraege: [Eintrag]) async -> Int {
        guard !laeuft else { return 0 }
        laeuft = true
        defer { laeuft = false }
        let persistenz = Persistenz.shared
        var geholt = 0
        var versucht = 0
        for e in eintraege where fehlt(e) && !vergeblich.contains(e.objectID) && persistenz.darfBearbeiten(e) {
            guard versucht < 30 else { break }
            versucht += 1
            guard let k = ort(e), let tag = e.tagDatum,
                  let w = try? await Wetterdienst.wetter(am: tag, bei: k) else {
                vergeblich.insert(e.objectID)
                continue
            }
            e.tageswetter = w
            geholt += 1
            if geholt % 5 == 0 { persistenz.sichern() }
        }
        if geholt > 0 { persistenz.sichern() }
        return geholt
    }

    /// Das Wetter eines Tages der Reise: aus dem ersten Eintrag mit Wetter,
    /// sonst — an einem Tag nur mit Spur — am Anfang der Spur geholt.
    struct Tageswahl {
        let wetter: Tageswetter
        let ortName: String
        let ort: CLLocationCoordinate2D
    }

    static func tag(_ schluessel: String, in reise: Reise) async -> Tageswahl? {
        let eintraege = reise.eintragListe.filter {
            $0.tagSchluessel == schluessel && $0.eintragsart != .seite
                && !Buecherei.shared.istGesperrt($0.tagebuchName)
        }
        for e in eintraege {
            if let w = e.tageswetter, let k = ort(e) {
                let name = (e.ortsname ?? "").trimmingCharacters(in: .whitespaces)
                return Tageswahl(wetter: w, ortName: name, ort: k)
            }
        }
        guard let datum = Tag.datum(schluessel: schluessel) else { return nil }
        let punkte = reise.spurListe.filter { $0.tag == schluessel }.flatMap(\.punktListe)
        guard let erster = (punkte.min { $0.zeit < $1.zeit }?.koordinate)
                ?? eintraege.compactMap(ort).first else { return nil }
        guard let w = await Wettervorrat.shared.wetter(am: datum, bei: erster) else { return nil }
        let name = await Ortsnamen.shared.name(fuer: erster)
        return Tageswahl(wetter: w, ortName: name.map { $0.stadt.isEmpty ? $0.titel : $0.stadt } ?? "", ort: erster)
    }
}

/// Das Wetter von Tagen, für die es keinen Eintrag gibt — gemerkt für die
/// Sitzung, nicht gespeichert.
actor Wettervorrat {
    static let shared = Wettervorrat()
    private var gemerkt: [String: Tageswetter] = [:]
    private var vergeblich: Set<String> = []

    func wetter(am tag: Date, bei k: CLLocationCoordinate2D) async -> Tageswetter? {
        let schluessel = Tag.schluessel(tag) + String(format: "|%.2f,%.2f", k.latitude, k.longitude)
        if let da = gemerkt[schluessel] { return da }
        if vergeblich.contains(schluessel) { return nil }
        guard let w = try? await Wetterdienst.wetter(am: tag, bei: k) else {
            vergeblich.insert(schluessel)
            return nil
        }
        gemerkt[schluessel] = w
        return w
    }
}
