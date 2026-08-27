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

    var hatStand: Bool { toreHeim != nil && toreGast != nil }

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
}

struct Tabelle: Hashable, Codable {
    let liga: Liga
    let spieltag: Int
    let zeilen: [Tabellenzeile]
    let stand: Date
}

// MARK: - Ticker

struct Tickermeldung: Identifiable, Hashable, Codable {
    enum Art: String, Codable, Hashable {
        case anpfiff
        case tor
        case halbzeit
        case abpfiff

        var symbol: String {
            switch self {
            case .anpfiff: return "flag.checkered"
            case .tor: return "soccerball"
            case .halbzeit: return "pause.circle"
            case .abpfiff: return "flag.checkered.circle"
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
