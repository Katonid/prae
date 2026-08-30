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
    ///
    /// **Die Luftrüssel-Aufnahme ist raus** (gemeldet: klingt gequält).
    /// Ein Klang, der schlecht klingt, ist schlechter als keiner —
    /// besonders bei etwas, das Freude machen soll. Ersetzt durch Tusch
    /// und Applaus, die beide von echten Aufnahmen kommen.
    func klaenge(fanfare: Fanfare = .tusch) -> [(datei: String, nach: Double)] {
        let tusch = fanfare.datei
        switch self {
        case .geschenk:
            return [(tusch, 0), ("geburtstag-applaus", 1.6)]
        case .rakete:
            return [(tusch, 0), ("geburtstag-applaus", 2.6)]
        case .ballons:
            return [("geburtstag-lied", 0)]
        case .feuerwerk:
            return [(tusch, 0), ("geburtstag-applaus", 2.2)]
        case .torte:
            return [("geburtstag-lied", 0), ("geburtstag-applaus", 12.6)]
        case .konfetti:
            return [("geburtstag-applaus", 0), ("geburtstag-lied", 0.4)]
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

/// Welche Fanfare den Auftritt eröffnet.
///
/// Zwei Aufnahmen, beide Militärkapelle, beide gemeinfrei, beide auf
/// dieselbe Lautheit gebracht (gemessen im lautesten 300-ms-Fenster:
/// −13,23 und −13,00 dBFS — beim Wechseln ist kein Sprung zu hören).
///
/// Gewünscht war ausdrücklich eine **ähnliche** Alternative, keine andere
/// Machart: Tusch und Applaus waren das, was gefiel (Nutzer, 08/2026).
/// Deshalb wieder eine Blaskapelle und nicht etwa ein Gong.
///
/// Als Rohwert gespeichert, damit eine Tafel eine Fanfare übersteht, die
/// ihre Fassung noch nicht kennt.
enum Fanfare: String, CaseIterable, Identifiable {
    /// US Air Force Heritage of America Band, „Ceremonial Fanfare".
    case tusch
    /// US Navy Band, „Jubilant Fanfare" — die erste Phrase.
    case jubel

    var id: String { rawValue }

    static func aus(_ rohwert: String) -> Fanfare {
        Fanfare(rawValue: rohwert) ?? .tusch
    }

    /// Abwechseln, statt zu würfeln: Bei zwei Möglichkeiten fiele der
    /// Zufall in der Hälfte der Fälle auf dieselbe — und genau das sollte
    /// er nicht.
    static func naechste(nach vorige: [String]) -> Fanfare {
        guard let letzte = vorige.last.map(aus) else { return .tusch }
        return letzte == .tusch ? .jubel : .tusch
    }

    var titel: String {
        switch self {
        case .tusch: return "Tusch (Air Force)"
        case .jubel: return "Fanfare (Navy)"
        }
    }

    var datei: String {
        switch self {
        case .tusch: return "geburtstag-tusch"
        case .jubel: return "geburtstag-tusch2"
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
