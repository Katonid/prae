import Foundation

/// Was von einer Verbindungssuche verlangt wird: bestimmte Verkehrsmittel,
/// und/oder nur das, was ein Deutschland-Ticket abdeckt.
///
/// **Ein Wert und nicht zwei Schalter nebeneinander** (ab 1.1.27, Ansage des
/// Nutzers 09/2026: „Beim Verbindungsplaner möchte ich Verkehrsmittel filtern
/// können … Ich möchte z. B. einstellen können, dass eine Verbindung nur per
/// Bus geschehen soll."). Bis 1.1.26 reiste ein nacktes `nurNahverkehr: Bool`
/// durch alle drei Protokolle. Ein zweites Feld daneben hätte an jeder Quelle
/// und an jeder Siebstelle einzeln beachtet werden müssen — und was an sechs
/// Stellen einzeln beachtet werden muss, wird irgendwo vergessen.
///
/// **Die beiden Einschränkungen UNDen sich** (`geltendeMittel`). Das ist keine
/// Feinheit: „nur Fernzug" und „Deutschland-Ticket" zusammen ergeben die leere
/// Menge, und eine Anfrage ohne ein einziges erlaubtes Verkehrsmittel brächte
/// eine leere Liste, die wie eine Aussage über den Fahrplan aussähe.
/// `istWiderspruch` fängt das ab, bevor irgendjemand gefragt wird.
struct Verbindungsfilter: Equatable, Sendable {

    /// Die gewünschten Verkehrsmittel. **Leer heißt „keine Einschränkung"**,
    /// nicht „nichts erlaubt" — dieselbe Lesart wie beim Filter der Tafel.
    var mittel: Set<Verkehrsmittel> = []

    /// Nur Verbindungen, die ein Deutschland-Ticket abdeckt.
    var nurDeutschlandTicket = false

    static let alles = Verbindungsfilter()

    /// Die Verkehrsmittel, die diese Suche zulässt — `nil` heißt „alle".
    ///
    /// **`nil` und „alle acht" sind nicht dasselbe**, und der Unterschied
    /// landet in der Anfrage: Ohne Einschränkung wird gar kein `transitModes`
    /// mitgeschickt, und dann liefert die Quelle auch Fahrten, deren Art diese
    /// App nicht kennt (`sonstiges`). Wer statt `nil` die volle Liste schickte,
    /// siebte diese Fahrten stillschweigend aus.
    var geltendeMittel: Set<Verkehrsmittel>? {
        let gewaehlt: Set<Verkehrsmittel>? = mittel.isEmpty ? nil : mittel
        guard nurDeutschlandTicket else { return gewaehlt }
        let ticket = Set(Verkehrsmittel.allCases.filter(\.imDeutschlandTicket))
        guard let gewaehlt else { return ticket }
        return gewaehlt.intersection(ticket)
    }

    /// Die Auswahl schließt sich selbst aus — etwa „nur Fernzug" zusammen mit
    /// dem Deutschland-Ticket.
    var istWiderspruch: Bool { geltendeMittel?.isEmpty == true }

    var aktiv: Bool { !mittel.isEmpty || nurDeutschlandTicket }

    mutating func umschalten(_ eines: Verkehrsmittel) {
        if mittel.contains(eines) { mittel.remove(eines) } else { mittel.insert(eines) }
    }

    /// Ob eine gefundene Verbindung durchgeht.
    ///
    /// Gefragt wird nach ALLEN Fahrten: Eine Verbindung, die zur Hälfte aus
    /// einem Bus und zur Hälfte aus einem ICE besteht, ist keine Busfahrt.
    /// **Fußwege zählen nicht mit** — sie sind kein Verkehrsmittel, und eine
    /// Verbindung ganz ohne Fahrt (nur zu Fuß) geht immer durch: Sie mit einem
    /// Verkehrsmittelfilter wegzunehmen wäre die eine Antwort, die sicher
    /// falsch ist.
    func passt(_ verbindung: Verbindung) -> Bool {
        guard let erlaubt = geltendeMittel else { return true }
        return verbindung.fahrten.allSatisfy { erlaubt.contains($0.linie?.mittel ?? .sonstiges) }
    }

    /// Die Verkehrsmittel, an denen eine Verbindung scheitert — für die
    /// Meldung. Eine Liste, die leer bleibt und nicht sagt WARUM, ist die
    /// Frage von vorhin noch einmal.
    func stoerenfriede(in verbindung: Verbindung) -> [Verkehrsmittel] {
        guard let erlaubt = geltendeMittel else { return [] }
        var gesehen: Set<Verkehrsmittel> = []
        return verbindung.fahrten
            .map { $0.linie?.mittel ?? .sonstiges }
            .filter { !erlaubt.contains($0) && gesehen.insert($0).inserted }
    }

    /// Wie der Filter in einer Meldung heißt — im Klartext, weil der Nutzer
    /// ihn liest.
    var beschreibung: String {
        let namen = mittel.sorted { $0.rang < $1.rang }.map(\.mehrzahl)
        switch (namen.isEmpty, nurDeutschlandTicket) {
        case (true, true): return "Deutschland-Ticket"
        case (false, false): return "nur \(namen.joined(separator: ", "))"
        case (false, true): return "nur \(namen.joined(separator: ", ")) und Deutschland-Ticket"
        case (true, false): return "kein Filter"
        }
    }

    /// **Die Verkehrsmittel, die sich überhaupt filtern lassen.**
    ///
    /// `sonstiges` steht bewusst NICHT darin: Das ist der Sammelfall für
    /// alles, was diese App nicht zuordnen konnte, und „nur Sonstiges" ist
    /// kein Wunsch, den jemand hat. Es als Zeile anzubieten hieße obendrein,
    /// eine Anfrage nach Modi zu stellen, die an dieser Strecke niemals
    /// fahren.
    static var waehlbare: [Verkehrsmittel] {
        Verkehrsmittel.allCases.filter { $0 != .sonstiges }.sorted { $0.rang < $1.rang }
    }
}
