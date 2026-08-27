import Foundation

// MARK: - Mannschaft

struct Mannschaft: Identifiable, Hashable, Codable {
    let id: Int
    let name: String
    let kurzname: String
    let kuerzel: String
    let wappen: URL?

    /// Kurzer Name für schmale Zeilen, mit Rückfall auf den langen.
    var anzeige: String { kurzname.isEmpty ? name : kurzname }

    /// Drei Buchstaben für das Ersatzwappen.
    var zeichen: String {
        if !kuerzel.isEmpty { return kuerzel }
        let woerter = name.split(separator: " ")
        let anfaenge = woerter.compactMap { $0.first }.prefix(3)
        return String(anfaenge).uppercased()
    }

    /// football-data.org liefert teils SVG-Wappen — die kann `AsyncImage`
    /// nicht zeichnen. Nur Rasterbilder werden geladen, sonst gilt das
    /// Buchstaben-Wappen.
    var ladbaresWappen: URL? {
        guard let wappen else { return nil }
        let endung = wappen.pathExtension.lowercased()
        return (endung == "png" || endung == "jpg" || endung == "jpeg") ? wappen : nil
    }
}

// MARK: - Spielstatus

enum Spielstatus: String, Codable, Hashable {
    case geplant
    case laeuft
    case pause
    case beendet
    case verschoben
    case abgesagt

    init(rohwert: String) {
        switch rohwert.uppercased() {
        case "IN_PLAY": self = .laeuft
        case "PAUSED": self = .pause
        case "FINISHED", "AWARDED": self = .beendet
        case "POSTPONED", "SUSPENDED": self = .verschoben
        case "CANCELLED", "CANCELED": self = .abgesagt
        default: self = .geplant
        }
    }

    var laeuftGerade: Bool { self == .laeuft || self == .pause }

    var beschriftung: String {
        switch self {
        case .geplant: return "geplant"
        case .laeuft: return "läuft"
        case .pause: return "Halbzeit"
        case .beendet: return "Endstand"
        case .verschoben: return "verlegt"
        case .abgesagt: return "abgesagt"
        }
    }
}

// MARK: - Tor

struct Tor: Identifiable, Hashable, Codable {
    let id: String
    let minute: Int?
    let nachspielzeit: Int?
    let schuetze: String
    let fuerHeim: Bool
    let standHeim: Int?
    let standGast: Int?

    var minutentext: String {
        guard let minute else { return "" }
        if let nachspielzeit, nachspielzeit > 0 { return "\(minute)+\(nachspielzeit)'" }
        return "\(minute)'"
    }
}

// MARK: - Spiel

struct Spiel: Identifiable, Hashable, Codable {
    let id: Int
    let liga: Liga
    let spieltag: Int
    let anstoss: Date
    let status: Spielstatus
    let minute: Int?
    let heim: Mannschaft
    let gast: Mannschaft
    let toreHeim: Int?
    let toreGast: Int?
    let halbzeitHeim: Int?
    let halbzeitGast: Int?
    var tore: [Tor]
    /// Beides liefert der Dienst nicht zu jeder Begegnung — deshalb wahlfrei.
    /// Wahlfrei heißt zugleich: Ein gesicherter Spielstand aus einer älteren
    /// Fassung lässt sich weiterhin lesen.
    var spielort: String?
    var schiedsrichter: String?
    /// Woher die Torfolge stammt, wenn nicht von football-data.org. Steht
    /// hier etwas, sagt die Spielansicht es auch dazu.
    var torfolgeQuelle: String?
    /// Wahr, wenn die Quelle weniger Tore nennt, als der Spielstand sagt —
    /// bei TheSportsDB deckelt die freie Stufe die Ereignisliste.
    var torfolgeUnvollstaendig = false

    var hatStand: Bool { toreHeim != nil && toreGast != nil }

    /// Wie viele Tore insgesamt gefallen sind — daran misst sich, ob eine
    /// nachgeladene Torfolge vollständig ist.
    var toreGesamt: Int { (toreHeim ?? 0) + (toreGast ?? 0) }

    var standtext: String {
        guard let toreHeim, let toreGast else { return "–:–" }
        return "\(toreHeim):\(toreGast)"
    }

    var halbzeittext: String? {
        guard let halbzeitHeim, let halbzeitGast else { return nil }
        return "\(halbzeitHeim):\(halbzeitGast)"
    }

    /// Was in der Zeile rechts steht: Uhrzeit vor dem Anpfiff, Minute
    /// während des Spiels, sonst der Zustand.
    var zeittext: String {
        switch status {
        case .geplant:
            return Zeitformate.uhrzeit.string(from: anstoss)
        case .laeuft:
            if let minute { return "\(minute)'" }
            return "läuft"
        case .pause:
            return "HZ"
        case .beendet:
            return "Ende"
        case .verschoben:
            return "verlegt"
        case .abgesagt:
            return "abgesagt"
        }
    }

    var istHeute: Bool { Calendar.current.isDateInToday(anstoss) }
}

// MARK: - Direkter Vergleich

/// Die bisherige Bilanz zweier Mannschaften gegeneinander.
///
/// Achtung: Das ist eine **eigene** Unterabfrage (`/matches/{id}/head2head`)
/// und keine Beigabe zur Spielabfrage — in 1.0.7 stand das falsch im Code,
/// weshalb der Vergleich nie erschien. Sie wird nur beim Öffnen einer
/// einzelnen Begegnung gestellt und geht dann von den zehn Abfragen je
/// Minute ab; bleibt sie ohne Antwort, entfällt der Abschnitt einfach.
struct Vergleich: Hashable, Codable {
    let spiele: Int
    let siegeHeim: Int
    let siegeGast: Int
    let unentschieden: Int
    /// Der Dienst nennt nur die Gesamtzahl der Tore beider Seiten, nicht
    /// die Aufteilung — also steht hier auch nur die.
    let toreGesamt: Int

    var hatInhalt: Bool { spiele > 0 }
}

// MARK: - Tabelle

struct Tabellenzeile: Identifiable, Hashable, Codable {
    var id: Int { mannschaft.id }
    let platz: Int
    let mannschaft: Mannschaft
    let spiele: Int
    let siege: Int
    let unentschieden: Int
    let niederlagen: Int
    let toreFuer: Int
    let toreGegen: Int
    let tordifferenz: Int
    let punkte: Int
    /// Die letzten Ergebnisse, neuestes zuletzt: "S", "U" oder "N".
    let form: [String]

    /// „1 Spiel" statt „1 Spiele" — und ausgeschrieben statt „0-1-0".
    var bilanztext: String {
        let partien = spiele == 1 ? "1 Spiel" : "\(spiele) Spiele"
        return "\(partien) · \(siege) S, \(unentschieden) U, \(niederlagen) N · \(toreFuer):\(toreGegen) Tore"
    }
}

struct Tabelle: Hashable, Codable {
    let liga: Liga
    let spieltag: Int
    let zeilen: [Tabellenzeile]
    let stand: Date
    /// Der Dienst schickt zur Gesamttabelle auch eine Heim- und eine
    /// Auswärtstabelle mit — in derselben Antwort, also ohne zusätzliche
    /// Abfrage. Liefert er sie nicht, bleiben sie leer.
    var heimzeilen: [Tabellenzeile] = []
    var auswaertszeilen: [Tabellenzeile] = []

    func heim(_ mannschaft: Mannschaft) -> Tabellenzeile? {
        heimzeilen.first { $0.mannschaft.id == mannschaft.id }
    }

    func auswaerts(_ mannschaft: Mannschaft) -> Tabellenzeile? {
        auswaertszeilen.first { $0.mannschaft.id == mannschaft.id }
    }
}

// MARK: - Aufstellung

/// Ein Platz in der Aufstellung. Nummer und Position liefert der Dienst
/// nicht immer mit — deshalb wahlfrei.
struct Spielerposten: Identifiable, Hashable, Codable {
    var id: String { (nummer.map(String.init) ?? "") + name }
    let name: String
    let nummer: Int?
    let position: String?

    /// Die Kürzel des Dienstes auf Deutsch. Unbekanntes bleibt, wie es ist.
    var positionstext: String? {
        switch (position ?? "").uppercased() {
        case "G": return "Tor"
        case "D": return "Abwehr"
        case "M": return "Mittelfeld"
        case "F": return "Angriff"
        case "": return nil
        default: return position
        }
    }
}

struct Aufstellung: Hashable, Codable {
    let mannschaft: String
    let formation: String?
    let trainer: String?
    let startelf: [Spielerposten]
    let bank: [Spielerposten]

    var hatInhalt: Bool { !startelf.isEmpty }
}

struct Aufstellungen: Hashable, Codable {
    let heim: Aufstellung
    let gast: Aufstellung

    var hatInhalt: Bool { heim.hatInhalt || gast.hatInhalt }
}

// MARK: - Torjäger

/// Ein Eintrag der Torjägerliste. Das Einzige an Spielerdaten, das der
/// freie Zugang hergibt — Aufstellungen gehören nicht dazu.
struct Torjaeger: Identifiable, Hashable, Codable {
    let id: Int
    let platz: Int
    let name: String
    let mannschaft: Mannschaft?
    let tore: Int
    let vorlagen: Int?
    let elfmeter: Int?
    let spiele: Int?

    /// „12 Tore in 8 Spielen, davon 2 Elfmeter" — aber nur mit dem, was
    /// wirklich mitkam.
    var beitext: String {
        var teile: [String] = []
        if let spiele, spiele > 0 {
            teile.append(spiele == 1 ? "1 Spiel" : "\(spiele) Spiele")
        }
        if let vorlagen, vorlagen > 0 {
            teile.append(vorlagen == 1 ? "1 Vorlage" : "\(vorlagen) Vorlagen")
        }
        if let elfmeter, elfmeter > 0 {
            teile.append(elfmeter == 1 ? "1 Elfmeter" : "\(elfmeter) Elfmeter")
        }
        return teile.joined(separator: " · ")
    }
}

// MARK: - Ticker

struct Tickermeldung: Identifiable, Hashable, Codable {
    enum Art: String, Codable, Hashable, CaseIterable, Identifiable {
        case anpfiff
        case tor
        case halbzeit
        case abpfiff

        var id: String { rawValue }

        var symbol: String {
            switch self {
            case .anpfiff: return "flag.checkered"
            case .tor: return "soccerball"
            case .halbzeit: return "pause.circle"
            case .abpfiff: return "flag.checkered.circle"
            }
        }

        var name: String {
            switch self {
            case .anpfiff: return "Anpfiff"
            case .tor: return "Tor"
            case .halbzeit: return "Halbzeit"
            case .abpfiff: return "Abpfiff"
            }
        }

        var beschreibung: String {
            switch self {
            case .anpfiff: return "Das Spiel hat begonnen."
            case .tor: return "Sobald sich der Spielstand ändert."
            case .halbzeit: return "Der Stand zur Pause."
            case .abpfiff: return "Der Endstand."
            }
        }
    }

    let id: String
    let zeitpunkt: Date
    let liga: Liga
    let spielID: Int
    let art: Art
    let paarung: String
    let stand: String
    let zusatz: String
    let minute: Int?

    var minutentext: String {
        guard let minute else { return "" }
        return "\(minute)'"
    }
}

// MARK: - Zeitformate

enum Zeitformate {
    static let uhrzeit: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "HH:mm"
        return f
    }()

    static let wochentagDatum: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "EEEE, d. MMMM"
        return f
    }()

    static let kurzdatum: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "EE d.M."
        return f
    }()

    static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static let isoMitBruchteil: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static func datum(aus text: String) -> Date? {
        iso.date(from: text) ?? isoMitBruchteil.date(from: text)
    }

    static let tagesschluessel: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
