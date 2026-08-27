import Foundation
import SwiftUI

/// Hält alles zusammen: Zugangsschlüssel, Zwischenspeicher der
/// Spieltage und Tabellen sowie den Liveticker.
@MainActor
final class Datenhaltung: ObservableObject {

    // MARK: Zustand

    @Published private(set) var schluessel: String
    @Published var beispielmodus: Bool {
        didSet {
            UserDefaults.standard.set(beispielmodus, forKey: Self.beispielSchluessel)
            if beispielmodus != oldValue {
                leeren()
            }
        }
    }

    @Published private(set) var ticker: [Tickermeldung] = []
    @Published private(set) var liveSpiele: [Spiel] = []
    @Published private(set) var tickerLaeuft = false
    @Published private(set) var tickerFehler: String?
    @Published private(set) var letzterAbruf: Date?

    @Published private(set) var nachrichten: [Nachricht] = []
    @Published private(set) var nachrichtenLaeuft = false

    @Published private(set) var spieltage: [Liga: [Int: [Spiel]]] = [:]
    @Published private(set) var tabellen: [Liga: Tabelle] = [:]
    @Published private(set) var torjaeger: [Liga: [Torjaeger]] = [:]
    @Published private(set) var laufenderSpieltag: [Liga: Int] = [:]
    @Published private(set) var ligaFehler: [Liga: String] = [:]
    @Published private(set) var ligaLaedt: Set<Liga> = []

    private var abrufzeit: [String: Date] = [:]
    /// Was gerade schon unterwegs ist. Ohne das laufen zwei gleiche
    /// Abfragen nebeneinander — bei zehn Abfragen je Minute zählt jede.
    private var imFlug: Set<String> = []
    private static let beispielSchluessel = "beispielmodus"

    var schluesselVorhanden: Bool { !schluessel.isEmpty }
    /// Ob die App gerade echte Daten holen kann.
    var einsatzbereit: Bool { schluesselVorhanden || beispielmodus }

    private var dienst: FussballDienst { FussballDienst(schluessel: schluessel) }

    // MARK: Aufbau

    init() {
        schluessel = Schluesselbund.lesen()
        beispielmodus = UserDefaults.standard.bool(forKey: Self.beispielSchluessel)
        ticker = Tickerspeicher.laden()
        nachrichten = Nachrichtenspeicher.laden()
    }

    func schluesselSetzen(_ neu: String) {
        let sauber = neu.trimmingCharacters(in: .whitespacesAndNewlines)
        Schluesselbund.schreiben(sauber)
        schluessel = sauber
        if !sauber.isEmpty { beispielmodus = false }
        leeren()
    }

    func schluesselLoeschen() {
        Schluesselbund.loeschen()
        schluessel = ""
        leeren()
    }

    private func leeren() {
        spieltage = [:]
        tabellen = [:]
        torjaeger = [:]
        laufenderSpieltag = [:]
        ligaFehler = [:]
        abrufzeit = [:]
        imFlug = []
        Standspeicher.leeren()
        liveSpiele = []
        ticker = []
        Tickerspeicher.sichern([])
        letzterAbruf = nil
        tickerFehler = nil
    }

    // MARK: Nachrichten rund um die Ligen

    /// Holt die Ligameldungen. Ohne `erzwingen` nur, wenn seit dem letzten
    /// Abruf genug Zeit vergangen ist — die Quellen sollen nicht bei jedem
    /// Blick auf die Liste erneut behelligt werden.
    func nachrichtenLaden(wunsch: Meldungswunsch, erzwingen: Bool = false) async {
        guard wunsch.willNachrichten else {
            nachrichten = []
            return
        }
        guard !nachrichtenLaeuft else { return }
        nachrichtenLaeuft = true
        defer { nachrichtenLaeuft = false }
        nachrichten = await Nachrichtenpflege.durchgang(wunsch: wunsch, erzwingen: erzwingen)
    }

    func nachrichtenLeeren() {
        nachrichten = []
        Nachrichtenspeicher.leeren()
        Nachrichtenpflege.zeitVergessen()
    }

    // MARK: Liveticker

    /// Läuft, solange die Ticker-Ansicht sichtbar ist. Wartet länger,
    /// wenn gerade kein Spiel läuft — der freie Zugang ist knapp bemessen.
    func tickerBeobachten() async {
        while !Task.isCancelled {
            await tickerAktualisieren()
            let pause: UInt64 = liveSpiele.contains { $0.status.laeuftGerade } ? 45 : 300
            try? await Task.sleep(nanoseconds: pause * 1_000_000_000)
        }
    }

    func tickerAktualisieren() async {
        guard einsatzbereit else { return }
        tickerLaeuft = true
        defer { tickerLaeuft = false }

        do {
            let frisch: [Spiel]
            if beispielmodus {
                frisch = Beispieldaten.spieleHeute()
            } else {
                frisch = try await dienst.spieleHeute()
            }
            // Fuer die Bundesliga die fehlende Torfolge nachziehen, BEVOR
            // verglichen wird — sonst entstuenden Tormeldungen ohne Namen,
            // die sich hinterher nicht mehr nachbessern lassen.
            let vollstaendig = beispielmodus ? frisch : await Torschuetzendienst.torfolgeErgaenzen(frisch)
            meldungenAblegen(vollstaendig)
            Vereinsverzeichnis.merken(spiele: vollstaendig)
            liveSpiele = vollstaendig.sorted(by: Self.reihenfolge)
            letzterAbruf = Date()
            tickerFehler = nil
        } catch {
            tickerFehler = (error as? DienstFehler)?.errorDescription ?? error.localizedDescription
        }
    }

    /// Vergleicht den neuen Stand mit dem gesicherten, schreibt die Meldungen
    /// in den Ticker und schickt sie — soweit freigeschaltet — als Mitteilung
    /// auf den Sperrbildschirm. Die Rechnung selbst steckt im `Tickerwerk`,
    /// damit der Hintergrundlauf dieselbe macht.
    private func meldungenAblegen(_ frisch: [Spiel]) {
        let vorher = Standspeicher.laden()
        let neue = Tickerwerk.meldungen(frisch: frisch, vorher: vorher)

        var stand = vorher
        for spiel in frisch { stand[spiel.id] = spiel }
        Standspeicher.sichern(stand)

        guard !neue.isEmpty else { return }
        ticker = Tickerspeicher.anhaengen(neue)
        Benachrichtiger.melden(neue, wunsch: Meldungswunsch.gesichert())
    }

    /// Stellt die Anpfiff-Wecker neu — aus allem, was die App gerade kennt:
    /// heutige Spiele, geladene Spieltage und der gesicherte Stand.
    func erinnerungenPflegen(wunsch: Meldungswunsch) async {
        var eindeutig: [Int: Spiel] = Standspeicher.laden()
        for spiel in liveSpiele { eindeutig[spiel.id] = spiel }
        for (_, tage) in spieltage {
            for (_, spiele) in tage {
                for spiel in spiele { eindeutig[spiel.id] = spiel }
            }
        }
        await Benachrichtiger.anstosserinnerungenPlanen(spiele: Array(eindeutig.values), wunsch: wunsch)
    }

    func tickerLeeren() {
        ticker = []
        Tickerspeicher.sichern([])
    }

    // MARK: Spieltage und Tabellen

    func spieltag(_ liga: Liga, _ nummer: Int) -> [Spiel]? {
        spieltage[liga]?[nummer]
    }

    func spieltagLaden(liga: Liga, nummer: Int, erzwingen: Bool = false) async {
        let marke = "\(liga.rawValue)-\(nummer)"
        if !erzwingen, spieltag(liga, nummer) != nil, frisch(marke, sekunden: 60) { return }
        guard einsatzbereit, !imFlug.contains(marke) else { return }

        imFlug.insert(marke)
        ligaLaedt.insert(liga)
        defer {
            imFlug.remove(marke)
            ligaLaedt.remove(liga)
        }

        do {
            let liste: [Spiel]
            if beispielmodus {
                liste = Beispieldaten.spiele(liga: liga, spieltag: nummer)
            } else {
                liste = try await dienst.spiele(liga: liga, spieltag: nummer)
            }
            let vollstaendig = beispielmodus ? liste : await Torschuetzendienst.torfolgeErgaenzen(liste)
            Vereinsverzeichnis.merken(spiele: vollstaendig)
            var tage = spieltage[liga] ?? [:]
            tage[nummer] = vollstaendig.sorted(by: Self.reihenfolge)
            spieltage[liga] = tage
            abrufzeit[marke] = Date()
            ligaFehler[liga] = nil
        } catch {
            ligaFehler[liga] = (error as? DienstFehler)?.errorDescription ?? error.localizedDescription
        }
    }

    func tabelleLaden(liga: Liga, erzwingen: Bool = false) async {
        let marke = "\(liga.rawValue)-tabelle"
        if !erzwingen, tabellen[liga] != nil, frisch(marke, sekunden: 120) { return }
        guard einsatzbereit, !imFlug.contains(marke) else { return }

        imFlug.insert(marke)
        ligaLaedt.insert(liga)
        defer {
            imFlug.remove(marke)
            ligaLaedt.remove(liga)
        }

        do {
            let tafel: Tabelle
            if beispielmodus {
                tafel = Beispieldaten.tabelle(liga)
            } else {
                tafel = try await dienst.tabelle(liga: liga)
            }
            tabellen[liga] = tafel
            Vereinsverzeichnis.merken(tafel.zeilen.map(\.mannschaft), liga: liga)
            if laufenderSpieltag[liga] == nil, tafel.spieltag > 0 {
                laufenderSpieltag[liga] = min(tafel.spieltag, liga.spieltage)
            }
            abrufzeit[marke] = Date()
            ligaFehler[liga] = nil
        } catch {
            ligaFehler[liga] = (error as? DienstFehler)?.errorDescription ?? error.localizedDescription
        }
    }

    /// Ermittelt den Spieltag, der gerade läuft. Die Tabelle liefert ihn
    /// mit; nur wenn die noch nicht geladen ist, wird eigens gefragt.
    @discardableResult
    func spieltagErmitteln(liga: Liga) async -> Int {
        if let bekannt = laufenderSpieltag[liga] { return bekannt }
        if beispielmodus {
            let tag = Beispieldaten.laufenderSpieltag(liga)
            laufenderSpieltag[liga] = tag
            return tag
        }
        if let tafel = tabellen[liga], tafel.spieltag > 0 {
            let tag = min(tafel.spieltag, liga.spieltage)
            laufenderSpieltag[liga] = tag
            return tag
        }
        guard schluesselVorhanden else { return 1 }
        do {
            let tag = min(max(try await dienst.laufenderSpieltag(liga: liga), 1), liga.spieltage)
            laufenderSpieltag[liga] = tag
            return tag
        } catch {
            ligaFehler[liga] = (error as? DienstFehler)?.errorDescription ?? error.localizedDescription
            return 1
        }
    }

    /// Holt Torschützen zu einem einzelnen Spiel nach.
    func spielNachladen(_ spiel: Spiel) async -> Spiel? {
        guard !beispielmodus else { return spiel }
        guard schluesselVorhanden else { return nil }
        guard let frisch = try? await dienst.spiel(id: spiel.id) else { return nil }
        return await Torschuetzendienst.torfolgeErgaenzen([frisch]).first ?? frisch
    }

    /// Die Tabellenzeile einer Mannschaft, falls die Tabelle schon geladen
    /// ist. Nur zum Anzeigen — es wird dafür nichts nachgefordert.
    func tabellenzeile(_ mannschaft: Mannschaft, liga: Liga) -> Tabellenzeile? {
        tabellen[liga]?.zeilen.first { $0.mannschaft.id == mannschaft.id }
    }

    /// Holt den direkten Vergleich. Das ist eine eigene Unterabfrage und
    /// wird deshalb nur beim Öffnen einer einzelnen Begegnung gestellt.
    func vergleichLaden(_ spiel: Spiel) async -> Vergleich? {
        guard !beispielmodus, schluesselVorhanden else { return nil }
        let marke = "vergleich-\(spiel.id)"
        guard !imFlug.contains(marke) else { return nil }
        imFlug.insert(marke)
        defer { imFlug.remove(marke) }
        return await dienst.vergleich(spielID: spiel.id)
    }

    // MARK: Torjäger

    func torjaegerLaden(liga: Liga, erzwingen: Bool = false) async {
        let marke = "\(liga.rawValue)-torjaeger"
        if !erzwingen, torjaeger[liga] != nil, frisch(marke, sekunden: 600) { return }
        guard einsatzbereit, !imFlug.contains(marke) else { return }

        imFlug.insert(marke)
        ligaLaedt.insert(liga)
        defer {
            imFlug.remove(marke)
            ligaLaedt.remove(liga)
        }

        do {
            let liste: [Torjaeger]
            if beispielmodus {
                liste = Beispieldaten.torjaeger(liga)
            } else {
                liste = try await dienst.torjaeger(liga: liga)
            }
            torjaeger[liga] = liste
            abrufzeit[marke] = Date()
            ligaFehler[liga] = nil
        } catch {
            ligaFehler[liga] = (error as? DienstFehler)?.errorDescription ?? error.localizedDescription
        }
    }

    // MARK: Hilfen

    private func frisch(_ marke: String, sekunden: TimeInterval) -> Bool {
        guard let zeit = abrufzeit[marke] else { return false }
        return Date().timeIntervalSince(zeit) < sekunden
    }

    /// Laufende Spiele zuerst, danach nach Anstoß und Paarung.
    static func reihenfolge(_ a: Spiel, _ b: Spiel) -> Bool {
        if a.status.laeuftGerade != b.status.laeuftGerade { return a.status.laeuftGerade }
        if a.anstoss != b.anstoss { return a.anstoss < b.anstoss }
        return a.heim.anzeige < b.heim.anzeige
    }
}

// MARK: - Ticker auf der Platte

/// Der Ticker soll einen Programmstart überleben, aber nicht ewig
/// wachsen: gesichert werden die letzten Meldungen der vergangenen Tage.
enum Tickerspeicher {
    private static let grenze = 250

    private static var ort: URL? {
        let ordner = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        return ordner?.appendingPathComponent("ticker.json")
    }

    static func laden() -> [Tickermeldung] {
        guard let ort, let daten = try? Data(contentsOf: ort) else { return [] }
        let alle = JSONDecoder().nachsichtigeListe(Tickermeldung.self, aus: daten)
        let grenze = Date().addingTimeInterval(-60 * 60 * 30)
        return alle.filter { $0.zeitpunkt > grenze }
    }

    /// Fügt neue Meldungen hinzu, wirft Doppelte weg, sortiert und kürzt.
    /// Gibt die neue Liste zurück, damit der Aufrufer sie anzeigen kann.
    @discardableResult
    static func anhaengen(_ neue: [Tickermeldung]) -> [Tickermeldung] {
        var bekannt = Set<String>()
        var zusammen: [Tickermeldung] = []
        for meldung in laden() + neue where !bekannt.contains(meldung.id) {
            bekannt.insert(meldung.id)
            zusammen.append(meldung)
        }
        zusammen.sort { links, rechts in
            if links.zeitpunkt != rechts.zeitpunkt { return links.zeitpunkt > rechts.zeitpunkt }
            return (links.minute ?? 0) > (rechts.minute ?? 0)
        }
        let gekuerzt = Array(zusammen.prefix(grenze))
        sichern(gekuerzt)
        return gekuerzt
    }

    static func sichern(_ meldungen: [Tickermeldung]) {
        guard let ort else { return }
        let ordner = ort.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        guard let daten = try? JSONEncoder().encode(meldungen) else { return }
        try? daten.write(to: ort, options: .atomic)
    }
}
