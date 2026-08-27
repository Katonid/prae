import SwiftUI

/// Die fünf großen europäischen Ligen. Der Rohwert ist zugleich der
/// Wettbewerbscode von football-data.org, damit keine zweite Tabelle
/// gepflegt werden muss.
enum Liga: String, CaseIterable, Identifiable, Codable, Hashable {
    case bundesliga = "BL1"
    case premierLeague = "PL"
    case laLiga = "PD"
    case serieA = "SA"
    case ligue1 = "FL1"

    var id: String { rawValue }

    /// Feste, kleine Kennzahl. Anders als `hashValue` bleibt sie über
    /// Programmstarts hinweg gleich — die Beispieldaten hängen daran.
    var kennzahl: Int {
        switch self {
        case .bundesliga: return 1
        case .premierLeague: return 2
        case .laLiga: return 3
        case .serieA: return 4
        case .ligue1: return 5
        }
    }

    var name: String {
        switch self {
        case .bundesliga: return "Bundesliga"
        case .premierLeague: return "Premier League"
        case .laLiga: return "La Liga"
        case .serieA: return "Serie A"
        case .ligue1: return "Ligue 1"
        }
    }

    var land: String {
        switch self {
        case .bundesliga: return "Deutschland"
        case .premierLeague: return "England"
        case .laLiga: return "Spanien"
        case .serieA: return "Italien"
        case .ligue1: return "Frankreich"
        }
    }

    /// Flaggen-Emoji statt Bilddateien: keine Ladezeit, keine Rechtefragen.
    var flagge: String {
        switch self {
        case .bundesliga: return "\u{1F1E9}\u{1F1EA}"
        case .premierLeague: return "\u{1F3F4}\u{E0067}\u{E0062}\u{E0065}\u{E006E}\u{E0067}\u{E007F}"
        case .laLiga: return "\u{1F1EA}\u{1F1F8}"
        case .serieA: return "\u{1F1EE}\u{1F1F9}"
        case .ligue1: return "\u{1F1EB}\u{1F1F7}"
        }
    }

    var farbe: Color {
        switch self {
        case .bundesliga: return Color(red: 0.83, green: 0.10, blue: 0.15)
        case .premierLeague: return Color(red: 0.36, green: 0.05, blue: 0.55)
        case .laLiga: return Color(red: 0.93, green: 0.45, blue: 0.05)
        case .serieA: return Color(red: 0.02, green: 0.35, blue: 0.68)
        case .ligue1: return Color(red: 0.05, green: 0.55, blue: 0.45)
        }
    }

    /// Anzahl der Spieltage einer vollständigen Saison. Dient nur der
    /// Bedienung (Auswahlliste); die echten Spieltage kommen vom Dienst.
    var spieltage: Int {
        switch self {
        case .bundesliga: return 34
        default: return 38
        }
    }

    /// Wie viele Mannschaften am Ende absteigen — färbt die Tabelle ein.
    var abstiegsplaetze: Int { 3 }

    /// Plätze, die direkt in die Champions League führen (Näherung; die
    /// Feinheiten der UEFA-Rangliste bildet die App bewusst nicht nach).
    var championsLeaguePlaetze: Int { 4 }
}
