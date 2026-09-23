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

/// Der Belag eines Weges, grob in fünf Klassen — gelesen aus dem
/// OSM-Merkmal `surface`, das BRouter je Stück mitschickt (gemessen
/// 23.09.2026 an einer Dortmunder Radroute: asphalt, paving_stones und
/// Stücke ganz ohne Angabe). Was nicht in der Liste steht, ist „unbekannt"
/// und wird nicht geraten.
enum Belag: String, CaseIterable, Hashable {
    case glatt, pflaster, wassergebunden, unbefestigt, unbekannt

    var name: String {
        switch self {
        case .glatt: return "Asphalt, Beton, Platten"
        case .pflaster: return "Kopfsteinpflaster"
        case .wassergebunden: return "Schotter, Split (wassergebunden)"
        case .unbefestigt: return "Erde, Gras, Sand"
        case .unbekannt: return "Belag nicht eingetragen"
        }
    }

    static func aus(_ surface: String?) -> Belag {
        guard let s = surface?.lowercased(), !s.isEmpty else { return .unbekannt }
        if s.hasPrefix("concrete") { return .glatt }
        switch s {
        case "asphalt", "paved", "paving_stones", "chipseal", "metal", "wood", "rubber":
            return .glatt
        case "sett", "cobblestone", "unhewn_cobblestone", "cobblestone:flattened", "grass_paver":
            return .pflaster
        case "compacted", "fine_gravel", "gravel", "pebblestone", "rock":
            return .wassergebunden
        case "unpaved", "ground", "dirt", "earth", "grass", "sand", "mud", "woodchips":
            return .unbefestigt
        default:
            return .unbekannt
        }
    }
}

struct Belagstueck: Identifiable, Hashable {
    let id = UUID()
    var belag: Belag
    var punkte: [Punkt]
    var laengeM: Double
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
    /// Der Belag je Stück — nur bei Radrouten über BRouter, denn nur dort
    /// steht `surface` in der Antwort. Leer heißt „nicht bekannt", nicht
    /// „asphaltiert". Steht zuletzt, damit es in den Aufrufen fehlen darf.
    var belaege: [Belagstueck] = []

    var zeitS: Double { posten.reduce(0) { $0 + $1.sekunden } }

    var schiebestrecken: [Abschnitt] { abschnitte.filter { $0.art != .fahren } }
}
