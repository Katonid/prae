import CoreLocation
import Foundation

/// Ein gemessener Fußweg zwischen zwei Punkten.
///
/// **Das ist etwas anderes als die Entfernungen in der Liste.** Dort stehen
/// Luftlinien, und das steht auch dabei: Eine Routing-Abfrage je Haltestelle
/// wäre ein Dutzend Anfragen für eine Zahl, die niemand angefordert hat. Hier
/// hat jemand ausdrücklich nach einem Fußweg gefragt — eine Abfrage für eine
/// Auskunft, um die gebeten wurde.
struct Fussweg {
    let start: CLLocationCoordinate2D
    let ziel: CLLocationCoordinate2D
    /// Die Länge des WEGES in Metern, nicht die Luftlinie.
    let meter: CLLocationDistance
    /// Die Gehzeit, wie die Quelle sie rechnet.
    ///
    /// **Das ist eine Annahme der Quelle und keine Messung an einem Menschen.**
    /// Gemessen am 20.09.2026 rechnet Transitous mit rund 1,19 m/s, also gut
    /// 4,3 km/h. Wer langsamer geht, ein Kind an der Hand hat oder eine Treppe
    /// nicht nehmen kann, braucht länger — und genau das schreibt die
    /// Oberfläche hin, statt die Zahl als Zusage auszugeben.
    let dauer: TimeInterval
    /// Der Weg selbst. **Leer heißt: es gibt keinen gezeichneten Verlauf** —
    /// dann bleibt nur die Luftlinie, und die wird gestrichelt gezeichnet.
    let linienzug: [CLLocationCoordinate2D]
    let quelle: String

    /// Die Luftlinie derselben Strecke.
    ///
    /// Sie steht IMMER daneben, auch wenn ein Weg gefunden wurde: Der
    /// Unterschied zwischen beiden ist die eigentliche Auskunft — 1,7 km Weg
    /// über 1,1 km Luftlinie heißt, dass ein Fluss, ein Gleis oder eine
    /// Schnellstraße dazwischenliegt.
    var luftlinie: CLLocationDistance {
        CLLocation(latitude: start.latitude, longitude: start.longitude)
            .distance(from: CLLocation(latitude: ziel.latitude, longitude: ziel.longitude))
    }

    /// Das Gehtempo, mit dem die Quelle gerechnet hat, in Metern je Sekunde.
    /// `nil`, wenn sich daraus nichts ableiten lässt.
    var tempo: Double? {
        guard dauer > 0, meter > 0 else { return nil }
        return meter / dauer
    }
}

/// Wer einen Fußweg ausrechnen kann.
///
/// **Ein eigenes Protokoll, aus demselben Grund wie `Abfahrtsquelle` und
/// `Verbindungsquelle`:** Nicht jede Quelle kann alles. Die Verbünde geben
/// Fußwege nur INNERHALB einer Verbindungsauskunft heraus, nicht zu zwei frei
/// gewählten Punkten; der Schweizer Dienst gar nicht. Sie als `Fahrplandienst`
/// zu verpflichten hieße, eine Methode zu versprechen und sie mit „geht nicht"
/// zu beantworten — das ist keine Trennung, sondern eine Lüge mit Protokoll.
protocol Fusswegquelle: Sendable {
    var quellenname: String { get }

    /// Der Fußweg von A nach B — Länge, Gehzeit und Verlauf.
    ///
    /// Wirft `Fahrplanfehler.keinFussweg`, wenn es keinen gibt. Das ist kein
    /// Ausfall, sondern eine Auskunft: zwischen einer Insel und dem Festland
    /// führt kein Weg, und über hundert Kilometer rechnet keine Quelle einen
    /// aus. Die Antwort darauf ist die Luftlinie mit einem Satz dazu, nicht
    /// ein zweiter Versuch.
    func fussweg(
        von: CLLocationCoordinate2D,
        nach: CLLocationCoordinate2D
    ) async throws -> Fussweg
}

/// Eine Quelle, die ALLES kann — Fahrplan und Fußweg.
///
/// Sie steht hier, damit `Kettendienst` seine vollen Quellen in EINER Liste
/// führen kann. Zwei Listen mit denselben Adressen liefen irgendwann
/// auseinander, und ein `as?`-Versuch zur Laufzeit verschöbe den Fehler vom
/// Übersetzer auf das Gerät.
typealias VolleQuelle = Fahrplandienst & Fusswegquelle
