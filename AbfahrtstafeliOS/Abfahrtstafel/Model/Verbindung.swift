import CoreLocation
import Foundation

/// Eine Verbindung von A nach B — ein Vorschlag der Auskunft.
///
/// Sie ist die Antwort auf eine andere Frage als die Abfahrtstafel: nicht
/// „was fährt hier weg", sondern **„wie komme ich dorthin"**. Beides in einer
/// Liste zu mischen wäre die naheliegende Sparsamkeit und wäre falsch — eine
/// Abfahrt gilt für alle, die an der Haltestelle stehen; eine Verbindung gilt
/// nur für den, der dieses Ziel eingetippt hat.
struct Verbindung: Identifiable, Hashable, Sendable {
    let id: String
    let abfahrt: Date
    let ankunft: Date
    /// Die planmäßigen Zeiten, falls die Quelle sie getrennt führt. `nil`
    /// heißt „nichts zu vergleichen" und wird auch so gezeigt — nicht als 0.
    let geplanteAbfahrt: Date?
    let geplanteAnkunft: Date?
    let umstiege: Int
    let abschnitte: [Verbindungsabschnitt]
    /// Wer diese Verbindung ausgerechnet hat.
    ///
    /// Sie steht an der EINZELNEN Verbindung und nicht am Dienst, aus
    /// demselben Grund wie `Abfahrt.quelle`: Unter der Liste soll stehen, wer
    /// wirklich beigetragen hat. „Transitous" unter einer Auskunft, die vom
    /// VRR kam, weil Transitous gerade nicht antwortete, wäre eine Angabe
    /// über die App und nicht über die Daten.
    let quelle: String

    var dauer: TimeInterval { ankunft.timeIntervalSince(abfahrt) }

    /// Die Fahrtabschnitte ohne die Fußwege — das, was auf der Zeile als
    /// Linienschilder steht.
    var fahrten: [Verbindungsabschnitt] { abschnitte.filter { $0.art == .fahrt } }

    /// Wie weit insgesamt gelaufen wird. Die Zahl steht an der Verbindung,
    /// weil sie der häufigste Grund ist, eine Verbindung NICHT zu nehmen.
    var fussmeter: Int { abschnitte.compactMap(\.meter).reduce(0, +) }

    /// Verspätung der Abfahrt in vollen Minuten, oder `nil`.
    var verspaetungMinuten: Int? {
        guard let plan = geplanteAbfahrt else { return nil }
        let minuten = Int((abfahrt.timeIntervalSince(plan) / 60).rounded())
        return minuten == 0 ? nil : minuten
    }

    /// Ob irgendein Abschnitt dieser Verbindung ausfällt.
    ///
    /// Eine Verbindung, von der ein Glied ausfällt, ist keine Verbindung. Sie
    /// wird trotzdem GEZEIGT und nicht stillschweigend weggelassen: Wer sie
    /// im Kopf hat, sucht sie sonst und hält die App für unvollständig.
    var faelltAus: Bool { abschnitte.contains(where: \.faelltAus) }

    /// Ob für diese Verbindung überhaupt eine Echtzeitmeldung vorliegt.
    /// Wenn nicht, steht „Plan" daran — dieselbe Regel wie an einer Abfahrt.
    var hatEchtzeit: Bool { fahrten.contains(where: \.istEchtzeit) }

    // Verglichen und gehasht wird über die KENNUNG. Der erzeugte Leser käme
    // nicht durch: In den Abschnitten stecken `CLLocationCoordinate2D`, und
    // die sind nicht `Hashable`. Gebraucht wird beides ohnehin nur für
    // `navigationDestination(for:)`.
    static func == (links: Verbindung, rechts: Verbindung) -> Bool { links.id == rechts.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Ein Glied einer Verbindung: ein Fußweg oder eine Fahrt.
struct Verbindungsabschnitt: Identifiable, Sendable {
    enum Art: Sendable { case fussweg, fahrt }

    let id: String
    let art: Art
    /// Die Namen stehen getrennt von den Haltestellen, weil ein Fußweg an
    /// einer Adresse beginnen kann und dort keine Haltestelle steht.
    let vonName: String
    let nachName: String
    let von: Haltestelle?
    let nach: Haltestelle?
    let start: Date
    let ende: Date
    let geplanterStart: Date?
    let geplantesEnde: Date?

    let linie: Linienkennung?
    let richtung: String?
    /// Die Fahrtkennung — nur damit lässt sich der ganze Lauf öffnen. Fehlt
    /// sie, steht die Zeile ohne Pfeil da; dieselbe Regel wie in der Tafel.
    let fahrtId: String?
    let halte: [Zwischenhalt]
    let strecke: [CLLocationCoordinate2D]
    /// Nur beim Fußweg: die Länge in Metern.
    let meter: Int?
    let faelltAus: Bool
    let istEchtzeit: Bool

    var dauer: TimeInterval { ende.timeIntervalSince(start) }

    var verspaetungMinuten: Int? {
        guard let plan = geplanterStart else { return nil }
        let minuten = Int((start.timeIntervalSince(plan) / 60).rounded())
        return minuten == 0 ? nil : minuten
    }

    /// Die Halte ZWISCHEN Ein- und Ausstieg — ohne die beiden selbst.
    var zwischenhalte: [Zwischenhalt] {
        guard halte.count > 2 else { return [] }
        return Array(halte.dropFirst().dropLast())
    }

    var entfallendeHalte: [Zwischenhalt] { halte.filter(\.faelltAus) }
}

/// Ein Treffer der Ortssuche — Haltestelle, Adresse oder Ort.
///
/// **Nicht nur Haltestellen**, obwohl die Vorschlagsliste von ihnen lebt: Ein
/// Ziel ist oft eine Adresse („wo ich morgen hinmuss"), und die Auskunft
/// rechnet ohnehin mit Koordinaten. Was es ist, steht an der Zeile — ein
/// Vorschlag, der aussieht wie eine Haltestelle und keine ist, wäre eine
/// Falle.
struct Ortstreffer: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    /// Stadt oder Gegend, damit „Hauptbahnhof" unterscheidbar ist.
    let gegend: String?
    let koordinate: CLLocationCoordinate2D
    let istHaltestelle: Bool

    var symbol: String { istHaltestelle ? "tram.fill" : "mappin" }

    static func == (links: Ortstreffer, rechts: Ortstreffer) -> Bool { links.id == rechts.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    /// Luftlinie zu einem Bezugspunkt — für die Sortierung der Vorschläge und
    /// für die Zeile darunter. Wie überall in dieser App eine LUFTLINIE, und
    /// das steht auch dabei.
    func entfernung(von punkt: CLLocationCoordinate2D?) -> CLLocationDistance? {
        guard let punkt else { return nil }
        return CLLocation(latitude: punkt.latitude, longitude: punkt.longitude)
            .distance(from: CLLocation(latitude: koordinate.latitude, longitude: koordinate.longitude))
    }
}
