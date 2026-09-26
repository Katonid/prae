import Foundation
import Photos

// DIE ÜBERGABE AUS FERNWEH EINLESEN (ab 1.0.106).
//
// Ansage des Nutzers, 09/2026: „Bitte baue einen Import für die
// Übergabedatei aus Fernweh ein; das Format steht in
// FernwehiOS/docs/UEBERGABE.md." Das Papier dort ist der VERTRAG zwischen
// beiden Apps. **Wer hier ein Feld liest, das dort nicht steht, oder eines
// anders deutet, ändert das Papier mit.**
//
// Was hereinkommt, und wohin:
//
//  - **Text.** Fernweh kennt mehrere Einträge je Tag (mehrere Miturlauber,
//    morgens und abends geschrieben). Sie werden in ihrer Reihenfolge
//    aneinandergehängt; ein Eintrag mit eigenem Titel bekommt ihn als
//    eigene Zeile davor. Wer was geschrieben hat, steht auf Wunsch darunter
//    — vorbelegt nur, wenn es überhaupt mehr als eine Person war.
//  - **Überschriften.** Der Titel des ersten Eintrags wird die Überschrift
//    des Tages, sein Ort die zweite. Ohne Titel ist der Ort die Überschrift
//    — so zeigt es auch Fernweh.
//  - **Orte und Reisespur.** Die Orte der Einträge tragen einen NAMEN und
//    werden nie ausgedünnt; die Spur ist schon in Fernweh auf 15 m gedünnt
//    und wird hier auf den Mindestabstand des Buches gebracht, wie jede
//    andere Spur. Haben zwei Miturlauber am selben Tag aufgezeichnet,
//    stehen zwei Spuren desselben Weges in der Datei — genommen wird die
//    mit den meisten Punkten, und die Vorschau sagt das.
//  - **Fotos.** Die Kennung des Fotos aus Fernweh wird die Kennung des
//    Fotos im Buch. Wer dieselbe Datei zweimal einliest, bekommt jedes Foto
//    deshalb nur einmal. Der Tag ist der des EINTRAGS (der Vertrag sagt es
//    ausdrücklich: Wer ein Foto einem Eintrag zugeordnet hat, hat damit
//    entschieden, wohin es gehört).
//  - **Wetter.** Seit 1.0.108 hat das Reisebuch dafür ein eigenes Feld am
//    Tag (`Reisetag.wetter`), das als eigene Zeile auf die Seite kommt.
//    Wahlweise steht es wie bis 1.0.107 unter dem Text. Eine Vorhersage
//    sagt, dass sie eine ist.
//
// **Zeiten.** In der Datei stehen Augenblicke (mit Versatz, bzw. als
// Unix-Sekunden bei der Spur). Im Buch steht die WANDUHR AM ORT — dieselbe
// Regel wie bei der Tagesspur seit 1.0.19, und derselbe Weg: je Tag die
// Zone am ersten Ort nachschlagen, sonst die eingestellte nehmen und das
// sagen. Der TAG wird dabei nie neu gerechnet; er steht in der Datei als
// Text, und der gilt.
enum Fernweheinfuhr {
    static let endung = "fernweh"

    // MARK: - Die Datei (Decodable, alles wahlweise)

    // Jedes Feld ist wahlweise und jede Liste nachsichtig: Der Vertrag sagt
    // „neue Felder werden angehängt, ein Leser überliest, was er nicht
    // kennt" — und ein einzelner kaputter Eintrag darf nicht die ganze Reise
    // mitnehmen.
    struct Datei: Decodable {
        var format: String?
        var version: Int?
        var erzeugt: String?
        var app: String?
        var fotos: String?
        var reise: ReiseTeil?
        var tage: Nachsichtig<TagTeil>?
    }

    struct ReiseTeil: Decodable {
        var kennung: String?
        var titel: String?
        var untertitel: String?
        var symbol: String?
        var beginn: String?
        var ende: String?
    }

    struct TagTeil: Decodable {
        var datum: String?
        var eintraege: Nachsichtig<EintragTeil>?
        var spuren: Nachsichtig<SpurTeil>?
    }

    struct EintragTeil: Decodable {
        var kennung: String?
        var zeitpunkt: String?
        var uhrzeit: String?
        var titel: String?
        var text: String?
        var autor: String?
        var ort: OrtTeil?
        var orte: Nachsichtig<OrtTeil>?
        var wetter: WetterTeil?
        var fotos: Nachsichtig<FotoTeil>?
    }

    struct OrtTeil: Decodable {
        var name: String?
        var land: String?
        var breite: Double?
        var laenge: Double?
        var uhrzeit: String?
    }

    struct WetterTeil: Decodable {
        var vorhersage: Bool?
        var abschnitte: Nachsichtig<AbschnittTeil>?
    }

    struct AbschnittTeil: Decodable {
        var name: String?
        var beschreibung: String?
        var tiefst: Double?
        var hoechst: Double?
        var regen: Double?
    }

    struct FotoTeil: Decodable {
        var kennung: String?
        var datei: String?
        var fehlt: String?
        var aufnahme: String?
        var breite: Double?
        var laenge: Double?
        var pixelBreite: Double?
        var pixelHoehe: Double?
        var reihenfolge: Int?
        var mediathek: String?
        var icloud: String?
    }

    struct SpurTeil: Decodable {
        var geraet: String?
        var reisender: String?
        var punkte: Nachsichtig<[Double]>?
        var besuche: Nachsichtig<BesuchTeil>?
    }

    struct BesuchTeil: Decodable {
        var breite: Double?
        var laenge: Double?
        var ankunft: String?
    }

    // MARK: - Was die Vorschau zeigt

    struct Eintrag {
        var titel: String
        var text: String
        var autor: String
        var ortName: String
    }

    struct Fotoangabe {
        var kennung: UUID?
        var datei: String?
        var fehlt: String?
        // Ein AUGENBLICK — umgerechnet wird er erst mit der Zone des Tages.
        var aufnahme: Date?
        var koordinate: Koordinate?
        var breite: Double
        var hoehe: Double
        var mediathek: String?
        var icloud: String?
    }

    struct Tag: Identifiable {
        var datum: Tagesdatum
        var eintraege: [Eintrag] = []
        var fotos: [Fotoangabe] = []
        // Die Spur, die genommen wird, und die benannten Orte — beide mit
        // Augenblicken, bis `ortszeitenSetzen` gelaufen ist.
        var spur: [Reisepunkt] = []
        var orte: [Reisepunkt] = []
        var spurenInDatei: Int = 0
        var wetter: String?
        var zone: TimeZone?
        var zoneNachgeschlagen = false

        var id: String { datum.schluessel }
    }

    struct Befund {
        var app = ""
        var fotoart = "keine"
        var titel = ""
        var untertitel = ""
        var tage: [Tag] = []
        var zone: TimeZone = .current
        // Was sich nicht lesen ließ. Nicht still übergehen — zählen und
        // sagen (der Vertrag verlangt es für fehlende Fotos, und dieselbe
        // Regel gilt für alles andere).
        var verworfen = 0
        var tageOhneDatum = 0

        var eintraege: Int { tage.reduce(0) { $0 + $1.eintraege.count } }
        var fotos: Int { tage.reduce(0) { $0 + $1.fotos.count } }
        var fotosMitDatei: Int { tage.reduce(0) { $0 + $1.fotos.filter { $0.datei != nil }.count } }
        var fotosFehlt: Int { tage.reduce(0) { $0 + $1.fotos.filter { $0.fehlt != nil }.count } }
        var spurpunkte: Int { tage.reduce(0) { $0 + $1.spur.count } }
        var orte: Int { tage.reduce(0) { $0 + $1.orte.count } }
        var autoren: [String] {
            var gesehen: [String] = []
            for tag in tage {
                for eintrag in tag.eintraege where !eintrag.autor.isEmpty
                    && !gesehen.contains(eintrag.autor)
                {
                    gesehen.append(eintrag.autor)
                }
            }
            return gesehen
        }

        var fotoartName: String {
            switch fotoart {
            case "kopie": return "verkleinerte Kopien"
            case "original": return "Originale"
            default: return "ohne Bilder"
            }
        }
    }

    enum Fehler: LocalizedError {
        case keineUebergabe
        case unbekannteFassung(Int)
        case kaputt(String)
        case leer

        var errorDescription: String? {
            switch self {
            case .keineUebergabe:
                return "Das ist keine Übergabedatei aus Fernweh. Sie entsteht dort unter Reise \u{2192} \u{201E}\u{2026}\u{201C} \u{2192} \u{201E}Fürs Fotobuch übergeben\u{201C}."
            case let .unbekannteFassung(nummer):
                return "Diese Übergabedatei hat die Fassung \(nummer). Diese Fassung des Reisebuchs kennt nur Fassung 1 \u{2014} bitte das Reisebuch aktualisieren."
            case let .kaputt(grund):
                return "Die Datei ließ sich nicht lesen: \(grund)"
            case .leer:
                return "In der Übergabe steht kein einziger Tag."
            }
        }
    }

    // MARK: - Lesen

    // Speicherabgebildet: Eine Übergabe mit Originalen wiegt Gigabyte. Im
    // Speicher liegt nur, was gerade gelesen wird.
    static func oeffnen(_ ort: URL) throws -> Data {
        do {
            return try Data(contentsOf: ort, options: .mappedIfSafe)
        } catch {
            throw Fehler.kaputt(error.localizedDescription)
        }
    }

    static func lesen(_ daten: Data, zone: TimeZone) throws -> Befund {
        let verzeichnis: [String: Zipleser.Eintrag]
        do {
            verzeichnis = try Zipleser.verzeichnis(daten)
        } catch Zipleser.Fehler.keinArchiv {
            throw Fehler.keineUebergabe
        } catch {
            throw Fehler.kaputt(error.localizedDescription)
        }
        guard let eintrag = verzeichnis["uebergabe.json"] else { throw Fehler.keineUebergabe }
        let roh: Data
        do {
            roh = try Zipleser.inhalt(eintrag, aus: daten)
        } catch {
            throw Fehler.kaputt(error.localizedDescription)
        }
        let datei: Datei
        do {
            datei = try JSONDecoder().decode(Datei.self, from: roh)
        } catch {
            throw Fehler.kaputt(error.localizedDescription)
        }
        guard datei.format == "fernweh-uebergabe" else { throw Fehler.keineUebergabe }
        // Eine NEUERE Fassung wird nicht erraten. Neue Felder überliest der
        // Leser ohnehin; eine neue Fassungsnummer hieße, dass sich an den
        // alten etwas geändert hat.
        if let fassung = datei.version, fassung > 1 { throw Fehler.unbekannteFassung(fassung) }

        var befund = Befund(zone: zone)
        befund.app = datei.app ?? ""
        befund.fotoart = datei.fotos ?? "keine"
        befund.titel = datei.reise?.titel ?? ""
        befund.untertitel = datei.reise?.untertitel ?? ""
        befund.verworfen += datei.tage?.verworfen ?? 0

        for teil in datei.tage?.werte ?? [] {
            guard let schluessel = teil.datum, let datum = Tagesdatum(schluessel: schluessel),
                  datum.gueltig
            else {
                befund.tageOhneDatum += 1
                continue
            }
            var tag = Tag(datum: datum)
            befund.verworfen += (teil.eintraege?.verworfen ?? 0) + (teil.spuren?.verworfen ?? 0)

            for eintrag in teil.eintraege?.werte ?? [] {
                befund.verworfen += (eintrag.fotos?.verworfen ?? 0) + (eintrag.orte?.verworfen ?? 0)
                let versatz = eintrag.zeitpunkt.flatMap { versatzSekunden($0) }
                let ortName = (eintrag.ort?.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                tag.eintraege.append(Eintrag(
                    titel: (eintrag.titel ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                    text: (eintrag.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                    autor: (eintrag.autor ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                    ortName: ortName
                ))

                // Der Ort des Eintrags — mit seinem Zeitpunkt.
                if let ort = eintrag.ort, let stelle = koordinate(ort.breite, ort.laenge) {
                    tag.orte.append(Reisepunkt(koordinate: stelle, name: ortName,
                                               zeit: eintrag.zeitpunkt.flatMap { augenblick($0) },
                                               quelle: .tagesspur))
                }
                // Die weiteren Orte tragen nur eine Wanduhr („10:40") — in
                // der Zone des Geräts, das die Datei geschrieben hat. Welche
                // das war, verrät der Versatz am Zeitpunkt des Eintrags.
                for ort in eintrag.orte?.werte ?? [] {
                    guard let stelle = koordinate(ort.breite, ort.laenge) else { continue }
                    let zeit = ort.uhrzeit.flatMap { augenblick(datum, uhrzeit: $0, versatz: versatz) }
                    tag.orte.append(Reisepunkt(koordinate: stelle,
                                               name: (ort.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                                               zeit: zeit, quelle: .tagesspur))
                }

                if tag.wetter == nil, let wetter = eintrag.wetter {
                    tag.wetter = wetterzeile(wetter)
                }

                let fotos = (eintrag.fotos?.werte ?? []).sorted {
                    ($0.reihenfolge ?? 0) < ($1.reihenfolge ?? 0)
                }
                for foto in fotos {
                    // Eine Datei, die die Beschreibung nennt und die im Archiv
                    // nicht liegt, ist ein FEHLENDES Bild — nicht eines ohne
                    // Datei. Der Unterschied gehört in die Zählung.
                    var datei: String?
                    var fehlt = foto.fehlt
                    if let pfad = foto.datei {
                        if verzeichnis[pfad] != nil {
                            datei = pfad
                        } else if fehlt == nil {
                            fehlt = "steht nicht im Archiv: " + pfad
                        }
                    }
                    tag.fotos.append(Fotoangabe(
                        kennung: foto.kennung.flatMap { UUID(uuidString: $0) },
                        datei: datei,
                        fehlt: fehlt,
                        aufnahme: foto.aufnahme.flatMap { augenblick($0) },
                        koordinate: koordinate(foto.breite, foto.laenge),
                        breite: foto.pixelBreite ?? 0,
                        hoehe: foto.pixelHoehe ?? 0,
                        mediathek: foto.mediathek,
                        icloud: foto.icloud
                    ))
                }
            }

            // Mehrere Spuren desselben Tages sind mehrere GERÄTE auf
            // demselben Weg. Zwei Linien übereinander wären keine Auskunft,
            // sondern ein Strich doppelter Breite; genommen wird die mit
            // den meisten Punkten.
            let spuren = teil.spuren?.werte ?? []
            tag.spurenInDatei = spuren.count
            if let beste = spuren.max(by: { ($0.punkte?.werte.count ?? 0) < ($1.punkte?.werte.count ?? 0) }) {
                var punkte: [Reisepunkt] = []
                for roh in beste.punkte?.werte ?? [] {
                    guard roh.count >= 2, let stelle = koordinate(roh[0], roh[1]) else { continue }
                    let zeit = roh.count >= 3 ? Date(timeIntervalSince1970: roh[2]) : nil
                    punkte.append(Reisepunkt(koordinate: stelle, zeit: zeit, quelle: .tagesspur))
                }
                for besuch in beste.besuche?.werte ?? [] {
                    guard let stelle = koordinate(besuch.breite, besuch.laenge) else { continue }
                    punkte.append(Reisepunkt(koordinate: stelle,
                                             zeit: besuch.ankunft.flatMap { augenblick($0) },
                                             quelle: .tagesspur))
                }
                tag.spur = punkte.sorted { ($0.zeit ?? .distantFuture) < ($1.zeit ?? .distantFuture) }
            }

            // Derselbe Tag zweimal in der Datei: zusammenlegen statt den
            // zweiten stillschweigend zu verlieren.
            if let schon = befund.tage.firstIndex(where: { $0.datum == datum }) {
                befund.tage[schon].eintraege += tag.eintraege
                befund.tage[schon].fotos += tag.fotos
                befund.tage[schon].orte += tag.orte
                if tag.spur.count > befund.tage[schon].spur.count { befund.tage[schon].spur = tag.spur }
                befund.tage[schon].spurenInDatei += tag.spurenInDatei
                if befund.tage[schon].wetter == nil { befund.tage[schon].wetter = tag.wetter }
            } else {
                befund.tage.append(tag)
            }
        }
        befund.tage.sort { $0.datum < $1.datum }
        guard !befund.tage.isEmpty else { throw Fehler.leer }
        return befund
    }

    // MARK: - Ortszeit

    // Dieselbe Rechnung wie bei der Tagesspur (`Spureinfuhr.ortszeitenSetzen`):
    // je TAG die Zone am ersten Ort, sonst die eingestellte. Umgerechnet
    // werden Spur, Orte und die Aufnahmezeiten der Fotos.
    static func ortszeitenSetzen(_ befund: Befund) async -> Befund {
        var neu = befund
        for stelle in neu.tage.indices {
            let tag = neu.tage[stelle]
            let ersterOrt = tag.orte.first?.koordinate ?? tag.spur.first?.koordinate
                ?? tag.fotos.compactMap(\.koordinate).first
            var zone = befund.zone
            var nachgeschlagen = false
            if let ersterOrt, let gefunden = await Zonensucher.geteilt.zone(fuer: ersterOrt) {
                zone = gefunden
                nachgeschlagen = true
            }
            neu.tage[stelle].zone = zone
            neu.tage[stelle].zoneNachgeschlagen = nachgeschlagen
        }
        return neu
    }

    // Die Uhrzeiten eines Tages in Wanduhr am Ort — aufgerufen beim
    // ÜBERNEHMEN, damit ein erneutes Nachschlagen nicht doppelt umrechnet.
    static func amOrt(_ punkte: [Reisepunkt], zone: TimeZone) -> [Reisepunkt] {
        punkte.map { punkt in
            guard let augenblick = punkt.zeit else { return punkt }
            var umgerechnet = punkt
            umgerechnet.zeit = Ortszeit.wanduhr(augenblick, in: zone)
            return umgerechnet
        }
    }

    // MARK: - Text

    struct Tagestext {
        var ueberschrift: String
        var unterueberschrift: String
        var text: String
    }

    static func tagestext(_ tag: Tag, autorenNennen: Bool, wetterAnhaengen: Bool) -> Tagestext {
        let ersterTitel = tag.eintraege.first { !$0.titel.isEmpty }?.titel ?? ""
        let ersterOrt = tag.eintraege.first { !$0.ortName.isEmpty }?.ortName ?? ""
        let ueberschrift = ersterTitel.isEmpty ? ersterOrt : ersterTitel
        let unter = (!ersterTitel.isEmpty && ersterOrt != ersterTitel) ? ersterOrt : ""

        var absaetze: [String] = []
        for eintrag in tag.eintraege {
            // Der eigene Titel eines späteren Eintrags steht als Zeile davor
            // — sonst verschwände der Übergang zwischen zwei Einträgen im
            // Fließtext. Der erste steht ohnehin oben als Überschrift.
            if !eintrag.titel.isEmpty, eintrag.titel != ueberschrift {
                absaetze.append(eintrag.titel)
            }
            if !eintrag.text.isEmpty { absaetze.append(eintrag.text) }
            if autorenNennen, !eintrag.autor.isEmpty, !eintrag.text.isEmpty {
                absaetze.append("\u{2014} " + eintrag.autor)
            }
        }
        if wetterAnhaengen, let wetter = tag.wetter { absaetze.append(wetter) }
        return Tagestext(ueberschrift: ueberschrift, unterueberschrift: unter,
                         text: absaetze.joined(separator: "\n\n"))
    }

    // „Wetter: Vormittag überwiegend klar, 19–25 °C · Nacht leichter Regen,
    // 14–16 °C, 2,1 mm." Eine Vorhersage sagt, dass sie eine ist — sie ist
    // keine Messung (derselbe Unterschied wie „Plan" gegen „pünktlich").
    static func wetterzeile(_ wetter: WetterTeil) -> String? {
        let zahl = NumberFormatter()
        zahl.locale = Locale(identifier: "de_DE")
        zahl.maximumFractionDigits = 1
        var teile: [String] = []
        for abschnitt in wetter.abschnitte?.werte ?? [] {
            var satz = abschnitt.name ?? ""
            if let beschreibung = abschnitt.beschreibung, !beschreibung.isEmpty {
                satz += (satz.isEmpty ? "" : " ") + beschreibung.lowercasedFirst
            }
            if let tief = abschnitt.tiefst, let hoch = abschnitt.hoechst {
                let t = Int(tief.rounded()), h = Int(hoch.rounded())
                satz += t == h ? ", \(t) °C" : ", \(t)\u{2013}\(h) °C"
            }
            if let regen = abschnitt.regen, regen >= 0.1,
               let text = zahl.string(from: NSNumber(value: regen))
            {
                satz += ", \(text) mm"
            }
            if !satz.isEmpty { teile.append(satz) }
        }
        guard !teile.isEmpty else { return nil }
        let kopf = wetter.vorhersage == true ? "Wetter (Vorhersage): " : "Wetter: "
        return kopf + teile.joined(separator: " \u{00B7} ")
    }

    // MARK: - Kleinteile

    private static func koordinate(_ breite: Double?, _ laenge: Double?) -> Koordinate? {
        guard let breite, let laenge else { return nil }
        let ort = Koordinate(breite: breite, laenge: laenge)
        return ort.gueltig ? ort : nil
    }

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let isoBruch: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static func augenblick(_ text: String) -> Date? {
        let sauber = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return iso.date(from: sauber) ?? isoBruch.date(from: sauber)
    }

    // Der Versatz eines ISO-Zeitpunkts in Sekunden: „+02:00" → 7200, „Z" → 0.
    static func versatzSekunden(_ text: String) -> Int? {
        let sauber = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if sauber.hasSuffix("Z") { return 0 }
        guard sauber.count >= 6 else { return nil }
        let ende = String(sauber.suffix(6))
        let zeichen = ende.first
        guard zeichen == "+" || zeichen == "-", ende.dropFirst(3).first == ":",
              let stunden = Int(ende.dropFirst().prefix(2)),
              let minuten = Int(ende.suffix(2))
        else { return nil }
        let betrag = stunden * 3600 + minuten * 60
        return zeichen == "-" ? -betrag : betrag
    }

    // Tag und Wanduhr zusammen zu einem Augenblick. Ohne bekannten Versatz
    // gilt die Zone dieses Geräts — geraten ist das auch, aber es ist
    // dieselbe Annahme, die Fernweh beim Schreiben getroffen hat, wenn beide
    // Geräte daheim liegen.
    private static func augenblick(_ datum: Tagesdatum, uhrzeit: String, versatz: Int?) -> Date? {
        let teile = uhrzeit.split(separator: ":").compactMap { Int($0) }
        guard teile.count >= 2, (0 ... 23).contains(teile[0]), (0 ... 59).contains(teile[1])
        else { return nil }
        var kalender = Calendar(identifier: .gregorian)
        kalender.timeZone = versatz.flatMap { TimeZone(secondsFromGMT: $0) } ?? .current
        var feld = DateComponents()
        feld.year = datum.jahr
        feld.month = datum.monat
        feld.day = datum.tag
        feld.hour = teile[0]
        feld.minute = teile[1]
        return kalender.date(from: feld)
    }
}

// Eine Liste, in der ein unlesbares Element übersprungen und GEZÄHLT wird,
// statt die ganze Liste mitzunehmen. Der erzeugte Leser eines Arrays
// scheitert am ersten falschen Element — bei einer Reise hieße das: ein
// kaputter Eintrag, und die ganze Übergabe ist weg.
struct Nachsichtig<T: Decodable>: Decodable {
    var werte: [T] = []
    var verworfen = 0

    init() {}

    init(from decoder: Decoder) throws {
        var liste = try decoder.unkeyedContainer()
        while !liste.isAtEnd {
            if let wert = try? liste.decode(T.self) {
                werte.append(wert)
            } else {
                // Ein misslungener Versuch rückt nicht weiter; ein leerer
                // Leser nimmt das Element ab, ohne etwas daraus zu lesen.
                verworfen += 1
                guard (try? liste.decode(Ueberspringen.self)) != nil else { break }
            }
        }
    }

    private struct Ueberspringen: Decodable {
        init(from decoder: Decoder) throws {}
    }
}

private extension String {
    // „Überwiegend klar" wird hinter dem Abschnittsnamen zu „überwiegend
    // klar". Nur der erste Buchstabe, und nur, wenn der zweite klein ist —
    // eine Abkürzung am Anfang bliebe sonst verstümmelt.
    var lowercasedFirst: String {
        guard let erstes = first else { return self }
        let rest = dropFirst()
        if let zweites = rest.first, zweites.isUppercase { return self }
        return erstes.lowercased() + rest
    }
}

// MARK: - Übernehmen

extension Reisewerk {
    struct Fernwehwunsch {
        var tage: Set<String>
        var ersetzen = false
        var autorenNennen = false
        var titel = false
        var ausMediathek = true
        // Die EINZELNEN FILTER (ab 1.0.108, Ansage des Nutzers 09/2026:
        // „Tagebuch erstellt eine Gesamtdatei, Fotobuch hat einzelne
        // Importfilter (Wetter, Fotos, Orte…)"). Die Datei bringt alles
        // mit; was davon ins Buch kommt, entscheidet jeder Schalter für
        // sich.
        var texte = true
        var fotos = true
        var wetter: Wetterziel = .zeile
        var orte: Ortswahl = .fernweh
    }

    enum Wetterziel: Hashable {
        // Ein eigenes Feld am Tag, auf der Seite eine eigene Zeile.
        case zeile
        // Wie bis 1.0.107: als letzter Absatz im Tagebuchtext.
        case unterText
        case keins
    }

    // WOHER die Orte kommen — eine Entscheidung des Menschen, nicht der
    // App (Ansage des Nutzers, 09/2026). `.fernweh` nimmt Spur, benannte
    // Orte und die Fotoorte aus der Datei; `.fotos` lässt alles davon
    // liegen und baut die Reisepunkte allein aus den BILDERN — dem EXIF
    // der Datei und, wo das fehlt, dem Aufnahmeort in der eigenen
    // Mediathek. Das ist derselbe Weg wie bei jeder anderen Fotoeinfuhr.
    enum Ortswahl: Hashable {
        case fernweh
        case fotos
    }

    // Ein Foto, das schon auf der Platte liegt, aber noch in keinem Buch.
    private struct Abgelegt {
        var tag: String
        var angabe: Fernweheinfuhr.Fotoangabe
        var datei: String
        var befund: Bildbefund
    }

    // ZWEI HÄLFTEN, und die Reihenfolge ist die Sache.
    //
    // Erst werden die BILDER abseits des Hauptfadens aus dem Archiv geholt
    // und abgelegt — eine Übergabe mit Originalen bewegt Gigabyte (die Lehre
    // aus 1.0.103). Erst DANACH wird das Buch in einem Zug geändert: EIN
    // `merken()`, also EIN Schritt „Widerrufen" für die ganze Übergabe,
    // und keine halb übernommene Reise, falls unterwegs etwas abbricht.
    func fernwehUebernehmen(_ befund: Fernweheinfuhr.Befund, daten: Data,
                            wunsch: Fernwehwunsch,
                            fortschritt: @escaping @MainActor (String) -> Void) async -> String
    {
        let auswahl = befund.tage.filter { wunsch.tage.contains($0.id) }
        let vorhanden = Set(reise.fotos.map(\.id))

        // 1. Die Bilder.
        var offen: [(tag: String, angabe: Fernweheinfuhr.Fotoangabe)] = []
        var schonImBuch = 0
        for tag in auswahl where wunsch.fotos {
            for angabe in tag.fotos {
                if let kennung = angabe.kennung, vorhanden.contains(kennung) {
                    schonImBuch += 1
                } else {
                    offen.append((tag.id, angabe))
                }
            }
        }

        var abgelegt: [Abgelegt] = []
        var ohneBild = 0
        var ausMediathek = 0
        let reiseID = reise.id
        let darfMediathek = wunsch.ausMediathek
            && (Self.mediathekStand == .authorized || Self.mediathekStand == .limited)
        let verzeichnis = try? Zipleser.verzeichnis(daten)

        for (nummer, stueck) in offen.enumerated() {
            fortschritt("Foto \(nummer + 1) von \(offen.count)")
            var geholt: (String, Bildbefund)?
            if let pfad = stueck.angabe.datei, let eintrag = verzeichnis?[pfad] {
                let endung = (pfad as NSString).pathExtension.lowercased()
                geholt = await Task.detached(priority: .userInitiated) {
                    Self.ablegen(aus: daten, eintrag: eintrag, reise: reiseID,
                                 endung: endung.isEmpty ? "jpg" : endung)
                }.value
            } else if darfMediathek, let eintrag = Self.fernwehAsset(stueck.angabe),
                      let roh = await Zeitraumeinfuhr.rohbild(eintrag)
            {
                geholt = await Task.detached(priority: .userInitiated) {
                    Self.ablegen(roh.daten, reise: reiseID, endung: roh.endung)
                }.value
                if geholt != nil { ausMediathek += 1 }
            }
            guard let fertig = geholt else {
                ohneBild += 1
                continue
            }
            let (datei, bildbefund) = fertig
            abgelegt.append(Abgelegt(tag: stueck.tag, angabe: stueck.angabe,
                                     datei: datei, befund: bildbefund))
        }

        // 2. Das Buch — in einem Zug.
        fortschritt("Tage werden übernommen\u{2026}")
        merken()
        let bekannt = Set(reise.tage.map(\.schluessel))
        var neueTage = 0
        var ergaenzt = 0
        var mitSpur = 0
        var spurGeleert = 0
        var mitWetter = 0
        var wetterNachAnordnen = 0

        for tag in auswahl {
            if !bekannt.contains(tag.id) { neueTage += 1 }
            let stelle = reise.tagIndex(fuer: tag.datum)
            // Ohne den Filter „Texte" bleibt nur, was ausdrücklich in den Text
            // soll: das Wetter, wenn es dort stehen soll.
            let neu = wunsch.texte
                ? Fernweheinfuhr.tagestext(tag, autorenNennen: wunsch.autorenNennen,
                                           wetterAnhaengen: wunsch.wetter == .unterText)
                : Fernweheinfuhr.Tagestext(
                    ueberschrift: "", unterueberschrift: "",
                    text: wunsch.wetter == .unterText ? (tag.wetter ?? "") : "")
            // Das Wetter als eigenes Feld. Es gilt dieselbe Regel wie bei
            // den Überschriften: Ein leerer Fund überschreibt nichts.
            if wunsch.wetter == .zeile, let wetter = tag.wetter, !wetter.isEmpty,
               reise.tage[stelle].wetter.isEmpty || wunsch.ersetzen
            {
                reise.tage[stelle].wetter = wetter
                mitWetter += 1
                // Ein Tag mit Handarbeit wird unten nicht neu gesetzt —
                // steht dort noch keine Wetterzeile, kommt sie erst mit
                // „Seiten neu anordnen". Das wird gezählt und gesagt.
                let hatZeile = reise.tage[stelle].seiten.contains {
                    $0.bloecke.contains { $0.inhalt == .wetter }
                }
                if !hatZeile, reise.tage[stelle].seiten.contains(where: \.vonHand) {
                    wetterNachAnordnen += 1
                }
            }

            // Dieselbe Regel wie beim Textimport: Überschriften werden nur
            // gesetzt, wo keine steht — oder wenn ersetzt werden soll. Ein
            // LEERER Fund überschreibt nie etwas.
            if !neu.ueberschrift.isEmpty,
               reise.tage[stelle].ueberschrift.isEmpty || wunsch.ersetzen
            {
                reise.tage[stelle].ueberschrift = neu.ueberschrift
            }
            if !neu.unterueberschrift.isEmpty,
               reise.tage[stelle].unterueberschrift.isEmpty || wunsch.ersetzen
            {
                reise.tage[stelle].unterueberschrift = neu.unterueberschrift
            }
            if !neu.text.isEmpty {
                let alt = reise.tage[stelle].text
                if wunsch.ersetzen || alt.isEmpty {
                    reise.tage[stelle].text = neu.text
                } else if !alt.contains(neu.text) {
                    // Steht der Text schon da, war das ein zweites Einlesen
                    // derselben Datei — angehängt ergäbe es jeden Absatz
                    // zweimal.
                    reise.tage[stelle].text = alt + "\n\n" + neu.text
                    ergaenzt += 1
                }
            }

            let zone = tag.zone ?? befund.zone
            guard wunsch.orte == .fernweh else {
                // Aus den Fotos: Fernwehs Spur und Orte bleiben draußen. Soll
                // ersetzt werden, geht auch, was ein früheres Einlesen an
                // Spurpunkten hinterlassen hat — sonst stünde neben den
                // Fotopunkten weiter die alte Fernweh-Spur. Ohne „ersetzen“
                // bleibt die Spur des Tages, wie sie ist.
                if wunsch.ersetzen, reise.tage[stelle].spur.contains(where: { $0.quelle == .tagesspur }) {
                    reise.tage[stelle].spur.removeAll { $0.quelle == .tagesspur }
                    spurGeleert += 1
                }
                continue
            }
            let strecke = Spurbau.ausgeduennt(Fernweheinfuhr.amOrt(tag.spur, zone: zone),
                                              mindestabstand: reise.gestaltung.mindestabstandSpur)
            var punkte = strecke
            // Benannte Orte werden NIE ausgedünnt — sie tragen die Auskunft.
            for ort in Fernweheinfuhr.amOrt(tag.orte, zone: zone) {
                guard let zeit = ort.zeit else {
                    punkte.append(ort)
                    continue
                }
                let wohin = punkte.firstIndex { ($0.zeit ?? .distantFuture) > zeit } ?? punkte.count
                punkte.insert(ort, at: wohin)
            }
            if !punkte.isEmpty {
                var spur = Spureinfuhr.Tagesspur(datum: tag.datum, punkte: punkte,
                                                 rohzahl: tag.spur.count + tag.orte.count,
                                                 aufenthalte: tag.orte.count, gerechnet: false)
                spur.zone = zone
                spur.zoneNachgeschlagen = tag.zoneNachgeschlagen
                tagesspurEinsetzen(spur, an: stelle)
                mitSpur += 1
            }
        }

        var mitOrt = 0
        var ortNachgesehen = 0
        var ortNurInDatei = 0
        let darfOrtNachsehen = Self.mediathekStand == .authorized || Self.mediathekStand == .limited
        for stueck in abgelegt {
            guard let tagDaten = auswahl.first(where: { $0.id == stueck.tag }),
                  let stelle = reise.tage.firstIndex(where: { $0.schluessel == stueck.tag })
            else { continue }
            let zone = tagDaten.zone ?? befund.zone
            // EXIF vor JSON: Ein Original trägt die Wanduhr und den Ort
            // selbst. Eine Kopie hat kein EXIF — dann gilt, was Fernweh aus
            // der Mediathek mitgeschickt hat.
            let aufnahme = stueck.befund.aufnahme
                ?? stueck.angabe.aufnahme.map { Ortszeit.wanduhr($0, in: zone) }
            var ort = stueck.befund.koordinate
            var quelle: Ortsquelle = ort != nil ? stueck.befund.quelle : .keiner
            if ort == nil {
                switch wunsch.orte {
                case .fernweh:
                    // Was Fernweh aus seiner Mediathek mitgeschickt hat.
                    if let mitgeschickt = stueck.angabe.koordinate {
                        ort = mitgeschickt
                        quelle = .mediathek
                    }
                case .fotos:
                    // Die App sieht SELBST nach — im Aufnahmeort des Bildes in
                    // der eigenen Mediathek. Die Angabe aus der Datei wird
                    // dabei bewusst nicht genommen, auch wenn sie da ist.
                    if darfOrtNachsehen, let eintrag = Self.fernwehAsset(stueck.angabe),
                       let gefunden = eintrag.location
                    {
                        let koordinate = Koordinate(gefunden.coordinate)
                        if koordinate.gueltig {
                            ort = koordinate
                            quelle = .mediathek
                            ortNachgesehen += 1
                        }
                    }
                    if ort == nil, stueck.angabe.koordinate != nil { ortNurInDatei += 1 }
                }
            }
            let foto = Foto(
                id: stueck.angabe.kennung ?? UUID(),
                datei: stueck.datei,
                breite: stueck.befund.breite,
                hoehe: stueck.befund.hoehe,
                aufnahme: aufnahme,
                // Der Tag des EINTRAGS, nicht der der Aufnahme (Vertrag).
                tagesschluessel: stueck.tag,
                koordinate: ort,
                ortsquelle: quelle
            )
            reise.fotos.append(foto)
            reise.tage[stelle].fotos.append(foto.id)
            if foto.hatOrt { mitOrt += 1 }
        }
        // Die Fotopunkte kommen dazu, wie bei jeder Einfuhr.
        for tag in auswahl {
            if let tagID = reise.tage.first(where: { $0.schluessel == tag.id })?.id {
                spurAktualisieren(tagID)
            }
        }

        if wunsch.titel {
            if !befund.titel.isEmpty { reise.titel = befund.titel }
            if !befund.untertitel.isEmpty { reise.untertitel = befund.untertitel }
        }

        alleNeuAnordnen(nurUnberuehrte: true)
        sofortSichern()

        var zeilen = ["\(auswahl.count) Tage aus Fernweh übernommen."]
        if neueTage > 0 { zeilen.append("\(neueTage) davon neu angelegt.") }
        if ergaenzt > 0 { zeilen.append("Bei \(ergaenzt) Tagen wurde der vorhandene Text ergänzt.") }
        if mitSpur > 0 { zeilen.append("\(mitSpur) Tage haben Orte oder eine Spur.") }
        if mitWetter > 0 { zeilen.append("Bei \(mitWetter) Tagen steht das Wetter als eigene Zeile.") }
        if wetterNachAnordnen > 0 {
            zeilen.append("\(wetterNachAnordnen) davon tragen Handarbeit \u{2014} dort erscheint die Wetterzeile erst nach \u{201E}Seiten neu anordnen\u{201C}.")
        }
        if !wunsch.texte { zeilen.append("Texte und Überschriften wurden nicht übernommen.") }
        if !wunsch.fotos { zeilen.append("Fotos wurden nicht übernommen.") }
        if wunsch.orte == .fotos {
            zeilen.append("Orte und Spur aus Fernweh wurden nicht übernommen; die Reisepunkte kommen aus den Fotos.")
            if spurGeleert > 0 {
                zeilen.append("Bei \(spurGeleert) Tagen wurde die Spur eines früheren Einlesens entfernt.")
            }
            if ortNachgesehen > 0 {
                zeilen.append("\(ortNachgesehen) Fotoorte wurden in der eigenen Mediathek nachgesehen.")
            }
            if ortNurInDatei > 0 {
                zeilen.append("\(ortNurInDatei) Fotos bleiben ohne Ort \u{2014} ihren Ort kannte nur Fernweh.")
            }
        }
        if !abgelegt.isEmpty {
            zeilen.append("\(abgelegt.count) Fotos eingelesen, \(mitOrt) mit Ort.")
        }
        if ausMediathek > 0 {
            zeilen.append("\(ausMediathek) davon aus der eigenen Mediathek geholt.")
        }
        if schonImBuch > 0 {
            zeilen.append("\(schonImBuch) Fotos standen schon im Buch und wurden nicht doppelt aufgenommen.")
        }
        if ohneBild > 0 {
            zeilen.append("\(ohneBild) Fotos kamen ohne Bild an \u{2014} sie fehlen im Buch.")
        }
        return zeilen.joined(separator: " ")
    }

    // MARK: Abseits des Hauptfadens

    nonisolated private static func ablegen(aus daten: Data, eintrag: Zipleser.Eintrag,
                                            reise: UUID, endung: String) -> (String, Bildbefund)?
    {
        guard let bild = try? Zipleser.inhalt(eintrag, aus: daten) else { return nil }
        return ablegen(bild, reise: reise, endung: endung)
    }

    nonisolated private static func ablegen(_ bild: Data, reise: UUID,
                                            endung: String) -> (String, Bildbefund)?
    {
        let befund = Bildleser.befund(datei: bild)
        guard befund.breite > 0, befund.hoehe > 0,
              let name = try? Bildarchiv.shared.ablegen(bild, reise: reise, endung: endung)
        else { return nil }
        return (name, befund)
    }

    // Ein Foto der Übergabe in DIESER Mediathek wiederfinden. `icloud` gilt
    // auf jedem Gerät derselben Apple-ID; `mediathek` nur auf dem Gerät, das
    // die Datei geschrieben hat — deshalb erst das eine, dann das andere.
    private static func fernwehAsset(_ angabe: Fernweheinfuhr.Fotoangabe) -> PHAsset? {
        var kennungen: [String] = []
        if let wolke = angabe.icloud, !wolke.isEmpty {
            let schluessel = PHCloudIdentifier(stringValue: wolke)
            let treffer = PHPhotoLibrary.shared().localIdentifierMappings(for: [schluessel])
            if case let .success(lokal)? = treffer[schluessel] { kennungen.append(lokal) }
        }
        if let lokal = angabe.mediathek, !lokal.isEmpty { kennungen.append(lokal) }
        for kennung in kennungen {
            if let eintrag = PHAsset.fetchAssets(withLocalIdentifiers: [kennung], options: nil).firstObject {
                return eintrag
            }
        }
        return nil
    }
}
