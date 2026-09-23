import Foundation

/// Ein Ort, den jemand als Start oder Ziel gewählt hat.
struct Ort: Hashable, Codable {
    var name: String
    var punkt: Punkt
}

/// Was auf einem Stück der Route zu tun ist. Beim Fahrrad ist das die
/// eigentliche Auskunft: Wo muss ich absteigen?
enum Abschnittsart: String, Hashable {
    /// Gewöhnlich fahren (oder gehen).
    case fahren
    /// Gehweg oder Fußgängerzone ohne Radfreigabe: absteigen und schieben.
    case schieben
    /// Treppe: tragen.
    case treppe
    /// Straße mit benutzungspflichtigem Radweg daneben (`bicycle=use_sidepath`).
    /// Auf der Fahrbahn darf man dort nicht fahren; der Router führt über sie,
    /// weil der Radweg in den Daten nicht als eigener Weg eingetragen ist.
    case radwegPflicht

    var name: String {
        switch self {
        case .fahren: return "Fahren"
        case .schieben: return "Schieben"
        case .treppe: return "Treppe (tragen)"
        case .radwegPflicht: return "Radweg neben der Fahrbahn benutzen"
        }
    }
}

struct Abschnitt: Identifiable, Hashable {
    let id = UUID()
    var art: Abschnittsart
    var punkte: [Punkt]
    var laengeM: Double
    /// Die Wegart aus den Daten, z. B. „Fußgängerzone" — gezeigt in der Liste
    /// der Schiebestrecken, damit man die Stelle wiedererkennt.
    var wegart: String?
}

struct Anweisung: Identifiable, Hashable {
    let id = UUID()
    var text: String
    var laengeM: Double
}

struct Hinweis: Identifiable, Hashable {
    enum Stufe: Int, Hashable { case info = 0, warnung = 1, gefahr = 2 }
    let id = UUID()
    var stufe: Stufe
    var text: String
}

/// Wie die Fahrzeit zustande kommt. Jede Zeile ist eine Zahl mit ihrem
/// Grund — eine nackte Minutenzahl wäre eine Zusage, keine Rechnung.
struct Zeitposten: Identifiable, Hashable {
    let id = UUID()
    var text: String
    var sekunden: Double
}

struct Route {
    var punkte: [Punkt]
    var abschnitte: [Abschnitt]
    var laengeM: Double
    /// Die eigene Rechnung: Summe der Posten.
    var posten: [Zeitposten]
    /// Was der Routendienst selbst ausgerechnet hat — zum Vergleich.
    var zeitDienstS: Double?
    var anweisungen: [Anweisung]
    var hinweise: [Hinweis]
    /// Meldungen, die auf der Route liegen und berücksichtigt wurden.
    var meldungen: [Verkehrsmeldung]
    /// Meldungen, die die erste Route blockierten und umfahren werden.
    var umfahren: [Verkehrsmeldung]
    /// Angekündigte Meldungen auf der Route (noch nicht gültig).
    var angekuendigt: [Verkehrsmeldung]
    /// Der Dienst, der WIRKLICH geantwortet hat.
    var quelle: String
    /// Ob Verkehrsmeldungen überhaupt nachgesehen wurden.
    var verkehrGeprueft: Bool

    var zeitS: Double { posten.reduce(0) { $0 + $1.sekunden } }

    var schiebestrecken: [Abschnitt] { abschnitte.filter { $0.art != .fahren } }
}
