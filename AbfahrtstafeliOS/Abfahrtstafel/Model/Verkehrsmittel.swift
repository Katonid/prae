import SwiftUI

/// Die Verkehrsmittelarten, die diese App unterscheidet.
///
/// Bewusst GRÖBER als das, was ein Fahrplandienst liefert. GTFS kennt über
/// hundert `route_type`-Werte (109 = S-Bahn, 400 = U-Bahn, 900 = Tram …), und
/// wer die alle durchreicht, baut die Umrechnung an jeder Ansicht noch einmal.
/// Hier steht sie einmal, im jeweiligen Dienst — die Oberfläche kennt nur
/// diese neun Fälle.
enum Verkehrsmittel: String, Codable, CaseIterable, Identifiable, Sendable {
    case sBahn
    case uBahn
    case tram
    case bus
    case regionalzug
    case fernzug
    case fernbus
    case faehre
    case sonstiges

    var id: String { rawValue }

    /// Der Name in der Oberfläche. Einzahl, weil er an einer einzelnen Fahrt
    /// steht.
    var name: String {
        switch self {
        case .sBahn: return "S-Bahn"
        case .uBahn: return "U-Bahn"
        case .tram: return "Tram"
        case .bus: return "Bus"
        case .regionalzug: return "Regionalzug"
        case .fernzug: return "Fernzug"
        case .fernbus: return "Fernbus"
        case .faehre: return "Fähre"
        case .sonstiges: return "Sonstiges"
        }
    }

    /// Die Mehrzahl — für die Filterleiste, wo mehrere gemeint sind.
    var mehrzahl: String {
        switch self {
        case .sBahn: return "S-Bahnen"
        case .uBahn: return "U-Bahnen"
        case .tram: return "Trams"
        case .bus: return "Busse"
        case .regionalzug: return "Regionalzüge"
        case .fernzug: return "Fernzüge"
        case .fernbus: return "Fernbusse"
        case .faehre: return "Fähren"
        case .sonstiges: return "Sonstiges"
        }
    }

    var symbol: String {
        switch self {
        case .sBahn: return "tram.fill"
        case .uBahn: return "tram.fill.tunnel"
        case .tram: return "tram"
        case .bus: return "bus.fill"
        case .regionalzug: return "train.side.front.car"
        case .fernzug: return "train.side.front.car"
        case .fernbus: return "bus.doubledecker.fill"
        case .faehre: return "ferry.fill"
        case .sonstiges: return "figure.walk"
        }
    }

    /// Die Rückfallfarbe für das Liniensymbol. Sie gilt nur, wenn der
    /// Fahrplandienst keine eigene Farbe mitschickt — und das tut er oft, denn
    /// die Linienfarben stehen in den GTFS-Daten der Verkehrsbetriebe.
    /// Absichtlich die gewohnten deutschen: S-Bahn grün, U-Bahn blau, Tram rot,
    /// Bus violett. Wer sie ändert, ändert etwas, das Fahrgäste seit
    /// Jahrzehnten lesen, ohne hinzusehen.
    var rueckfallfarbe: Color {
        switch self {
        case .sBahn: return Color(red: 0.00, green: 0.51, blue: 0.29)
        case .uBahn: return Color(red: 0.06, green: 0.33, blue: 0.66)
        case .tram: return Color(red: 0.78, green: 0.13, blue: 0.13)
        case .bus: return Color(red: 0.48, green: 0.22, blue: 0.62)
        case .regionalzug: return Color(red: 0.42, green: 0.45, blue: 0.50)
        case .fernzug: return Color(red: 0.16, green: 0.18, blue: 0.22)
        // Olivbraun: gemessen der kleinste Abstand zu allen anderen
        // Rückfallfarben dE 37,8 (zu „Sonstiges"), Schriftkontrast 7,0:1.
        // Ein Fernbus ist weder Stadtbus noch Zug — er darf wie keins von
        // beiden aussehen.
        case .fernbus: return Color(red: 0.42, green: 0.34, blue: 0.14)
        case .faehre: return Color(red: 0.05, green: 0.47, blue: 0.62)
        case .sonstiges: return Color(red: 0.40, green: 0.42, blue: 0.45)
        }
    }

    /// Ob dieses Verkehrsmittel als NAHVERKEHR gilt — das, was ein
    /// Deutschland-Ticket abdeckt.
    ///
    /// **Die Regel steht hier und nirgends sonst** (ab 1.1.20, Ansage des
    /// Nutzers 09/2026: „Es soll möglich sein, nur Verbindungen anzeigen zu
    /// lassen, die mit dem Deutschland-Ticket befahrbar sind."). Sie wird an
    /// zwei Enden gebraucht — die Anfrage an Transitous schickt die passenden
    /// MOTIS-Modi mit, und jede Antwort wird zusätzlich hier geprüft. Zwei
    /// Fassungen liefen auseinander, und die eine, die mehr durchließe, wäre
    /// die teure.
    ///
    /// **Im Zweifel NICHT abgedeckt.** Die beiden Fehler sind nicht gleich
    /// schwer: Eine Verbindung zu viel wegzulassen kostet eine Auskunft, eine
    /// zu viel zu zeigen kostet ein erhöhtes Beförderungsentgelt. Deshalb
    /// fallen `sonstiges` (unbekanntes Mittel) und `faehre` heraus — manche
    /// Fähren sind Nahverkehr (die HADAG in Hamburg gehört zum HVV), viele
    /// sind es nicht, und welche, steht in keinem Feld.
    ///
    /// **Was diese Eigenschaft NICHT kann**, und was die Oberfläche deshalb
    /// dazuschreibt: Sie kennt das Verkehrsmittel, nicht das LAND. Gemessen
    /// am 19.09.2026: München → Zürich gibt mit Nahverkehrsmodi eine
    /// vollständige Verbindung aus Regionalzügen zurück — die ist ab der
    /// Grenze nicht im Deutschland-Ticket. Und sie kennt keine Ausnahme
    /// einzelner Linien.
    var imDeutschlandTicket: Bool {
        switch self {
        case .sBahn, .uBahn, .tram, .bus, .regionalzug: return true
        case .fernzug, .fernbus, .faehre, .sonstiges: return false
        }
    }

    /// Die Reihenfolge in der Filterleiste und in Gruppierungen. Schiene vor
    /// Straße, weil die meisten Fahrgäste zuerst danach suchen.
    var rang: Int {
        switch self {
        case .sBahn: return 0
        case .uBahn: return 1
        case .tram: return 2
        case .bus: return 3
        case .regionalzug: return 4
        case .fernzug: return 5
        case .fernbus: return 6
        case .faehre: return 7
        case .sonstiges: return 8
        }
    }
}
