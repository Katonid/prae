import CoreLocation
import Foundation

/// Der ganze Lauf einer Fahrt: Start, alle Zwischenhalte, Ziel — und die
/// Strecke als Linienzug für die Karte.
///
/// Das ist es, was der Nutzer beim Tippen auf eine Abfahrt sehen will: nicht
/// „U6 Richtung Garching", sondern welche Halte dazwischenliegen und wann die
/// Bahn dort ist.
struct Fahrt: Identifiable, Sendable {
    let id: String
    let linie: Linienkennung
    /// Das Fahrtziel vom Zugschild. Kann von `halte.last` abweichen.
    let richtung: String

    /// ALLE Halte der Fahrt, in Fahrtrichtung, Start und Ziel eingeschlossen.
    /// Eine Fahrt ohne Zwischenhalte ist kein Sonderfall, sondern eine Liste
    /// mit zwei Einträgen.
    let halte: [Zwischenhalt]

    /// Die gefahrene Strecke. LEER heißt „der Dienst hat keine Geometrie
    /// mitgeschickt" — dann zeichnet die Karte die Luftlinie zwischen den
    /// Halten und SAGT das auch. Eine erfundene Strecke, die wie eine echte
    /// aussieht, wäre schlimmer als gar keine.
    let strecke: [CLLocationCoordinate2D]

    var start: Zwischenhalt? { halte.first }
    var ziel: Zwischenhalt? { halte.last }

    /// Der Index des Haltes, an dem man einsteigt — gesetzt, wenn die Fahrt
    /// aus einer bestimmten Abfahrt heraus geöffnet wurde. Danach richtet sich,
    /// was die Ansicht hervorhebt und wohin sie scrollt.
    var einstiegIndex: Int?

    /// Der letzte Halt, den die Fahrt zu einem Zeitpunkt schon hinter sich hat.
    /// Grundlage für den Fortschrittsbalken in der Halteliste.
    func indexErreicht(_ jetzt: Date) -> Int? {
        var letzter: Int?
        for (i, halt) in halte.enumerated() {
            guard let zeit = halt.abfahrt ?? halt.ankunft else { continue }
            if zeit <= jetzt { letzter = i }
        }
        return letzter
    }
}

/// Ein Halt im Lauf einer Fahrt.
///
/// Ankunft und Abfahrt sind getrennt und beide sind optional: Der Starthalt hat
/// keine Ankunft, der Zielhalt keine Abfahrt. Sie zusammenzuziehen spart ein
/// Feld und kostet genau die Unterscheidung, um die es an einem Umsteigehalt
/// geht.
struct Zwischenhalt: Identifiable, Hashable, Sendable {
    var id: String { "\(haltestelle.id)#\(nummer)" }
    /// Die Stelle im Lauf. Ohne sie wäre eine Ringlinie, die dieselbe
    /// Haltestelle zweimal anfährt, für `Identifiable` ein einziger Eintrag.
    let nummer: Int

    let haltestelle: Haltestelle
    let steig: String?

    let ankunft: Date?
    let geplanteAnkunft: Date?
    let abfahrt: Date?
    let geplanteAbfahrt: Date?
    let faelltAus: Bool

    /// Die Zeit, die in der Liste steht: Abfahrt, sonst Ankunft. An einem
    /// Zwischenhalt interessiert den Fahrgast, wann es weitergeht.
    var zeit: Date? { abfahrt ?? ankunft }
    var geplanteZeit: Date? { geplanteAbfahrt ?? geplanteAnkunft }

    /// Verspätung in vollen Minuten, oder nil, wenn es nichts zu vergleichen
    /// gibt. `nil` heißt „unbekannt" und wird auch so gezeigt — nicht als 0.
    var verspaetungMinuten: Int? {
        guard let ist = zeit, let plan = geplanteZeit else { return nil }
        let minuten = Int((ist.timeIntervalSince(plan) / 60).rounded())
        return minuten == 0 ? nil : minuten
    }
}
