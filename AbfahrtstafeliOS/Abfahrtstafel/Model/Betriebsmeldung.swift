import Foundation

/// Eine Betriebsmeldung: Umleitung, Sperrung, Ersatzverkehr, entfallender Halt.
///
/// **Warum es diesen Typ überhaupt gibt** (gemeldet 09/2026: „Ich weiß, dass
/// bei mir vor Ort eine Buslinie gerade eine Umleitung fahren muss … Dieser
/// aktuelle Stand ist in der App aber leider nicht zu sehen."):
///
/// Nachgemessen am 18.09.2026 führt **Transitous überhaupt keine
/// Betriebsmeldungen** — weder an den Abfahrten noch am Fahrtlauf. Es kennt
/// Verspätungen und Ausfälle, aber nicht den Grund und nicht die Folgen. Eine
/// Umleitung ist damit für die erste Quelle unsichtbar, und die App war es
/// auch. Die Verkehrsverbünde führen sie sehr wohl.
///
/// Deshalb sind Meldungen **eine eigene Sache neben der Abfahrtskette** und
/// kein weiteres Feld an `Abfahrt`: Sie kommen aus einer anderen Quelle als
/// die Zeiten, sie ändern sich in Stunden statt in Sekunden, und sie gelten
/// einer LINIE, nicht einer einzelnen Fahrt.
struct Betriebsmeldung: Identifiable, Hashable, Codable, Sendable {
    let id: String
    /// Die Überschrift, wie der Verbund sie schreibt („Linie 453: Sperrung
    /// Kronprinzenstraße wegen Arbeiten an Versorgungsleitungen").
    let titel: String
    /// Der volle Text, von HTML befreit. Leer, wenn der Verbund keinen
    /// mitschickt — dann steht die Überschrift für sich.
    let text: String
    /// Die Linien, die diese Meldung betrifft.
    ///
    /// **Sie kommt aus den DATEN, nicht aus dem Titel.** Der Verbund hängt
    /// jede Meldung an die Abfahrten, für die sie gilt; welche Linien das
    /// sind, steht damit fest. Den Titel nach „Linie 453" zu durchsuchen wäre
    /// die naheliegende Alternative und würde bei „Linien 400, 401" schon
    /// wackeln und bei „Airport Express // Airport Shuttle" ganz aufgeben.
    let linien: Set<String>
    /// Der Verbund, der sie gemeldet hat.
    let quelle: String
    /// Ob der Verbund sie als dringend gekennzeichnet hat.
    let dringend: Bool
    /// Weiterführende Adresse, sofern eine brauchbare mitkam.
    let adresse: URL?

    /// Ob diese Meldung eine bestimmte Linie betrifft.
    ///
    /// Verglichen wird ohne Rücksicht auf Groß- und Kleinschreibung und ohne
    /// Leerzeichen: Der eine Verbund schreibt „RE 57", der andere „RE57", und
    /// es ist dieselbe Linie.
    func betrifft(_ linie: Linienkennung) -> Bool {
        let gesucht = Self.vergleichbar(linie.name)
        guard !gesucht.isEmpty else { return false }
        return linien.contains { Self.vergleichbar($0) == gesucht }
    }

    static func vergleichbar(_ name: String) -> String {
        name.lowercased().filter { !$0.isWhitespace }
    }
}
