import Foundation

/// Was am Ende eines Timers erklingt.
///
/// Sieben fertige Klänge liegen im Bündel (Ordner `Klaenge/`, erzeugt von
/// `TafelbildiOS/scripts/make-endklaenge.py`) — dazu die Möglichkeit, eine
/// eigene Tondatei zu wählen oder etwas aufzunehmen.
///
/// Die Auswahl reicht bewusst von sehr leise bis sehr deutlich: Eine
/// Stillarbeitsphase will man mit einer Klangschale beenden, eine
/// Gruppenarbeit in einer lauten Klasse braucht die Klingel.
///
/// **Gespeichert wird der Rohwert, nicht der Fall selbst** (siehe
/// `TimerContent.endklang`). Fällt hier je ein Fall weg, liest die alte
/// Tafel weiter — sie bekommt dann die Vorgabe statt eines Fehlers. Ein
/// erzeugter Leser würde an dieser Stelle die ganze Tafel verwerfen.
enum Endklang: String, CaseIterable, Identifiable {
    case glocke
    case glockenspiel
    case triangel
    case klangschale
    case gong
    case wecker
    case piep
    /// Eigene Aufnahme oder gewählte Datei — der Name steht in
    /// `TimerContent.endklangDatei`.
    case eigener

    static let vorgabe: Endklang = .glocke

    /// Aus dem gespeicherten Rohwert. Unbekanntes wird zur Vorgabe.
    static func aus(_ rohwert: String) -> Endklang {
        Endklang(rawValue: rohwert) ?? .vorgabe
    }

    var id: String { rawValue }

    var titel: String {
        switch self {
        case .glocke:       return "Handglocke"
        case .glockenspiel: return "Glockenspiel"
        case .triangel:     return "Triangel"
        case .klangschale:  return "Klangschale"
        case .gong:         return "Gong"
        case .wecker:       return "Klingel"
        case .piep:         return "Piepton"
        case .eigener:      return "Eigener Klang"
        }
    }

    var hinweis: String {
        switch self {
        case .glocke:
            return "Zwei Schläge auf die Glocke vom Lehrerpult. Deutlich, "
                 + "ohne zu erschrecken."
        case .glockenspiel:
            return "Drei Töne aufwärts — ein freundliches „fertig“, gut für "
                 + "kurze Arbeitsphasen."
        case .triangel:
            return "Hell und fein. Trägt erstaunlich weit, ohne laut zu sein."
        case .klangschale:
            return "Ruhig und lang ausklingend. Für Stillarbeit und zum "
                 + "Zurruhekommen."
        case .gong:
            return "Tief und weich. Der leiseste Weg, eine Klasse zu "
                 + "unterbrechen."
        case .wecker:
            return "Eine Klingel, die schnell schlägt. Kommt auch durch eine "
                 + "laute Gruppenarbeit."
        case .piep:
            return "Drei kurze Töne. Nüchtern, ohne Stimmung — wie eine "
                 + "Küchenuhr."
        case .eigener:
            return "Eine eigene Aufnahme oder eine Tondatei vom Gerät. Sie "
                 + "geht über iCloud an alle Geräte mit."
        }
    }

    var symbol: String {
        switch self {
        case .glocke:       return "bell"
        case .glockenspiel: return "music.note"
        case .triangel:     return "triangle"
        case .klangschale:  return "circle.circle"
        case .gong:         return "circle.hexagongrid"
        case .wecker:       return "alarm"
        case .piep:         return "waveform"
        case .eigener:      return "mic"
        }
    }

    /// Dateiname im Bündel — nil bei „Eigener Klang“, der aus den
    /// Mediendateien der Tafel kommt.
    var datei: String? {
        switch self {
        case .eigener: return nil
        default:       return "endklang-\(rawValue)"
        }
    }

    /// Die fertigen Klänge, ohne „Eigener Klang“.
    static var mitgelieferte: [Endklang] {
        allCases.filter { $0 != .eigener }
    }
}
