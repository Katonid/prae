import CoreLocation
import Foundation

/// Eine Quelle, die NUR Verbindungen kann.
///
/// **Das dritte Protokoll dieser App, und es hat denselben Grund wie das
/// zweite:** Nicht jede Quelle kann alles. `Abfahrtsquelle` gibt es, weil die
/// Verbünde vorzügliche Abfahrtstafeln liefern und keine Streckengeometrie zu
/// einer einzelnen Fahrt; `Verbindungsquelle` gibt es, weil dieselben Stellen
/// eine vollständige Reiseauskunft herausgeben, aber weder eine Ortssuche für
/// die Vorschlagsliste noch einen Fahrtlauf, den man aus der Tafel heraus
/// öffnen könnte. Sie als `Fahrplandienst` auszugeben hieße, sechs Methoden zu
/// versprechen und vier mit „geht nicht" zu beantworten.
///
/// Die Ansichten sehen weiterhin nur `Fahrplandienst`; `Kettendienst` fügt
/// zusammen.
///
/// **Nachgemessen am 19.09.2026, nicht angenommen:** `XSLT_TRIP_REQUEST2`
/// antwortete an ALLEN acht Stellen aus `EfaDienst.alle` mit vollständigen
/// Verbindungen — Fußwege, Umstiege, Zwischenhalte, Streckengeometrie und
/// Echtzeit an jedem Fahrtabschnitt. `transport.opendata.ch/v1/connections`
/// ebenso, ohne Geometrie. Was hier steht, ist gemessen; was sich nicht messen
/// ließ, steht nicht hier.
protocol Verbindungsquelle: Sendable {
    /// Der Name, der unter der Ergebnisliste steht. Woher die Auskunft kommt,
    /// gehört dem Nutzer gesagt — besonders dann, wenn es nicht die gewohnte
    /// Quelle war.
    var name: String { get }

    /// Ob diese Quelle für DIESE Reise überhaupt zuständig ist.
    ///
    /// **Beide Punkte müssen im Gebiet liegen, nicht nur einer.** Das ist der
    /// Unterschied zur Abfahrtstafel: Eine Tafel gilt für einen Punkt, eine
    /// Verbindung für zwei. Eine EFA-Stelle kennt Fahrten in ihrem Gebiet;
    /// von Dortmund nach Köln reicht der VRR nicht, und eine Anfrage, die
    /// garantiert nichts bringt, ist in einer Kette nur Wartezeit.
    func zustaendig(von: CLLocationCoordinate2D, nach: CLLocationCoordinate2D) -> Bool

    func verbindungen(
        von: CLLocationCoordinate2D,
        nach: CLLocationCoordinate2D,
        zeitpunkt: Date,
        ankunft: Bool,
        anzahl: Int,
        nurNahverkehr: Bool
    ) async throws -> [Verbindung]
}
