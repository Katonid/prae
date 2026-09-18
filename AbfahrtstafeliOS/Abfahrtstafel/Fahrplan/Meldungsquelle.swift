import Foundation

/// Eine Quelle, die Betriebsmeldungen kennt.
///
/// **Das dritte Protokoll, und es ist kein Versehen.** `Fahrplandienst` kann
/// alles, `Abfahrtsquelle` nur Abfahrten — und `Meldungsquelle` nur
/// Betriebsmeldungen. Der Grund steht in `Betriebsmeldung`: Die Quelle, die
/// die Zeiten liefert, kennt die Umleitung nicht, und die Quelle, die die
/// Umleitung kennt, ist nicht überall zuständig.
///
/// Anders als bei `Abfahrtsquelle` wird hier NICHT gekettet. Meldungen sind
/// keine Rückfallauskunft: Antwortet der Verbund nicht, gibt es eben keine —
/// und die App sagt dann nichts, statt etwas zu behaupten.
protocol Meldungsquelle: Sendable {
    var name: String { get }
    func zustaendig(fuer haltestelle: Haltestelle) -> Bool
    func meldungen(um haltestelle: Haltestelle, umkreis meter: Int) async throws -> [Betriebsmeldung]
}
