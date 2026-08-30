import Foundation

/// Was passiert, wenn jemand auf das Geburtstagselement tippt.
///
/// **Es soll nicht bei jedem Kind dasselbe sein.** Sechs Abläufe, und
/// welcher gilt, wird beim Anlegen der Seite ausgewürfelt und dann dort
/// gespeichert — nicht bei jedem Tippen neu. Sonst bekäme ein Kind bei
/// jedem Antippen etwas anderes, und die Feier wäre nicht *seine*.
///
/// Jede Art bringt ihr eigenes Bild und ihren eigenen Klang mit; die
/// Glückwünsche wechseln zusätzlich (siehe `Gluecksatz`).
enum Feierart: String, CaseIterable, Identifiable {
    /// Ein Geschenk, das aufspringt, und Konfetti steigt heraus.
    case geschenk
    /// Eine Rakete steigt und zerplatzt oben in Funken.
    case rakete
    /// Luftballons steigen von unten auf.
    case ballons
    /// Ein Feuerwerk aus mehreren Bällen.
    case feuerwerk
    /// Eine Torte, deren Kerzen angehen.
    case torte
    /// Konfettiregen von oben, dicht und lang.
    case konfetti

    var id: String { rawValue }

    /// Aus dem gespeicherten Rohwert. Unbekanntes wird zum Geschenk.
    static func aus(_ rohwert: String) -> Feierart {
        Feierart(rawValue: rohwert) ?? .geschenk
    }

    /// Eine Art aussuchen — möglichst nicht die, die zuletzt dran war.
    ///
    /// Reiner Zufall wiederholt sich häufiger, als es sich anfühlt: Bei
    /// sechs Möglichkeiten kommt im Schnitt jedes sechste Mal dasselbe
    /// zweimal hintereinander. In einer Klasse mit zwei Geburtstagen an
    /// einem Tag fiele das sofort auf.
    static func naechste(nach vorige: [String]) -> Feierart {
        let verbraucht = Set(vorige.suffix(3))
        let offen = allCases.filter { !verbraucht.contains($0.rawValue) }
        return (offen.isEmpty ? allCases : offen).randomElement() ?? .geschenk
    }

    var titel: String {
        switch self {
        case .geschenk:  return "Geschenk"
        case .rakete:    return "Rakete"
        case .ballons:   return "Luftballons"
        case .feuerwerk: return "Feuerwerk"
        case .torte:     return "Torte"
        case .konfetti:  return "Konfetti"
        }
    }

    /// Welche Klänge dazugehören, in der Reihenfolge des Abspielens, mit
    /// Verzögerung in Sekunden.
    ///
    /// Der Tusch kommt sofort, der Applaus erst, wenn das Bild seinen
    /// Höhepunkt hat — ein Beifall, der vor der Pointe einsetzt, wirkt
    /// nicht.
    var klaenge: [(datei: String, nach: Double)] {
        switch self {
        case .geschenk:
            return [("geburtstag-tusch", 0), ("geburtstag-applaus", 1.6)]
        case .rakete:
            return [("geburtstag-truete", 0), ("geburtstag-tusch", 0.9)]
        case .ballons:
            return [("geburtstag-lied", 0)]
        case .feuerwerk:
            return [("geburtstag-tusch", 0), ("geburtstag-applaus", 2.2)]
        case .torte:
            return [("geburtstag-lied", 0), ("geburtstag-applaus", 12.6)]
        case .konfetti:
            return [("geburtstag-truete", 0), ("geburtstag-applaus", 0.5)]
        }
    }

    /// Wie lange der Auftritt dauert.
    var dauer: Double {
        switch self {
        case .geschenk:  return 6.5
        case .rakete:    return 6.0
        case .ballons:   return 9.0
        case .feuerwerk: return 7.5
        case .torte:     return 14.5
        case .konfetti:  return 6.0
        }
    }
}

/// Glückwünsche, die während der Feier erscheinen.
///
/// Getrennt von der Feierart, damit sich beides unabhängig mischt: Zwei
/// Kinder mit derselben Rakete bekommen trotzdem andere Worte.
enum Gluecksatz {
    static let alle = [
        "Herzlichen Glückwunsch!",
        "Alles Gute zum Geburtstag!",
        "Hoch sollst du leben!",
        "Ein wunderschöner Tag für dich!",
        "Wir freuen uns mit dir!",
        "Auf ein tolles neues Jahr!",
        "Feier schön!",
        "Die ganze Klasse gratuliert!",
        "Alles Liebe für dich!",
        "Lass dich feiern!"
    ]

    /// Drei verschiedene Wünsche, in zufälliger Reihenfolge.
    static func auswahl(_ anzahl: Int = 3) -> [String] {
        Array(alle.shuffled().prefix(max(1, anzahl)))
    }
}
