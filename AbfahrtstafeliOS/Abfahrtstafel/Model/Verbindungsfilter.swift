import CoreLocation
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

    /// **Wie weit höchstens zu Fuß — zur ersten und von der letzten
    /// Haltestelle** (ab 1.1.28, Ansage des Nutzers 09/2026: „Vielleicht ist
    /// es manchmal nötig, eine Strecke zu Fuß zu gehen, damit eine Verbindung
    /// zustandekommt. Ich möchte die maximale Länge dieser Strecke festlegen
    /// können."). `nil` heißt „keine eigene Grenze"; dann gilt, was der
    /// Dienst von Haus aus zulässt — gemessen 21.09.2026 sind das
    /// **900 Sekunden**, also gut einen Kilometer.
    ///
    /// **Gemeint ist EINE Strecke, nicht die Summe.** Der Nutzer hat nach der
    /// Länge „dieser Strecke" gefragt, und das ist der Weg am Anfang bzw. am
    /// Ende — genau das, was sich beim Dienst auch einstellen lässt.
    var hoechsterFussweg: Int?

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

    var aktiv: Bool { !mittel.isEmpty || nurDeutschlandTicket || hoechsterFussweg != nil }

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
        guard fussweglaengePasst(verbindung) else { return false }
        guard let erlaubt = geltendeMittel else { return true }
        return verbindung.fahrten.allSatisfy { erlaubt.contains($0.linie?.mittel ?? .sonstiges) }
    }

    /// **Die Fußweggrenze wird NACHGEPRÜFT und nicht der Anfrage überlassen**
    /// (ab 1.1.28). Der Dienst kennt nur eine Grenze in SEKUNDEN, und die
    /// hält keine Grenze in Metern: Gemessen 21.09.2026 gab eine Anfrage mit
    /// 888 Sekunden (aus 800 m gerechnet) am Dortmunder Stadtrand Zugangswege
    /// von 983 m zurück, eine mit 555 Sekunden (aus 500 m) solche von 626 m.
    /// Das liegt nicht an einem falschen Tempo: Der Dienst rundet jede
    /// Gehdauer auf volle Minuten, und sein Tempo schwankt je Weg zwischen
    /// 0,93 und 1,48 m/s. **Die Zeit fragt also grosszügig, die Zahl hält
    /// diese Prüfung** — wer nur das eine täte, versprächse eine Zahl, die
    /// nicht gilt, oder verlöre Verbindungen, die gepasst hätten.
    ///
    /// Gefragt wird nach dem WEG AM ANFANG und dem AM ENDE, einzeln. Ein
    /// Umstiegsweg mitten in der Verbindung bleibt aussen vor: Er steht als
    /// Fusspfad im Fahrplan, lässt sich beim Dienst nicht begrenzen, und ihn
    /// hier wegzusieben nähme Verbindungen weg, ohne dass es eine Anfrage
    /// gäbe, die sie vermeidet. Die Oberfläche schreibt das hin.
    private func fussweglaengePasst(_ verbindung: Verbindung) -> Bool {
        guard let grenze = hoechsterFussweg else { return true }
        return verbindung.randfusswege.allSatisfy { $0 <= Double(grenze) }
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
        var teile: [String] = []
        let namen = mittel.sorted { $0.rang < $1.rang }.map(\.mehrzahl)
        if !namen.isEmpty { teile.append("nur \(namen.joined(separator: ", "))") }
        if nurDeutschlandTicket { teile.append("Deutschland-Ticket") }
        if let grenze = hoechsterFussweg {
            teile.append("höchstens \(Haltestelle.entfernungstext(Double(grenze))) zu Fuß")
        }
        return teile.isEmpty ? "kein Filter" : teile.joined(separator: ", ")
    }

    /// Die Stufen, die zur Wahl stehen — `nil` ist „ohne Grenze".
    ///
    /// Stufen und kein Schieberegler: Eine Grenze auf den Meter genau
    /// einzustellen, täuschte eine Genauigkeit vor, die es nicht gibt (der
    /// gezeigte Weg ist der des Dienstes, nicht der, den jemand wirklich
    /// geht), und ein Regler in einer schmalen Leiste trifft ohnehin niemand.
    static let fussweggrenzen: [Int?] = [nil, 200, 300, 500, 800, 1200, 2000]

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
