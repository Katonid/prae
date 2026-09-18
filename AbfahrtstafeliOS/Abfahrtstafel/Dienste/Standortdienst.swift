import CoreLocation
import Foundation

/// Der Standort — und vor allem: was die App tut, wenn es ihn nicht gibt.
///
/// Eine Abfahrtstafel ohne Standort ist nicht kaputt, sie braucht dann einen
/// Ort von Hand. Deshalb hat dieser Dienst keinen Zustand „Fehler", sondern
/// einen `stand`, den die Oberfläche in einen Satz übersetzt und daneben den
/// Ausweg anbietet.
@MainActor
final class Standortdienst: NSObject, ObservableObject {
    enum Stand: Equatable {
        case nochNichtGefragt
        case wirdGefragt
        case abgelehnt
        case ausgeschaltet
        case sucht
        case da(CLLocationCoordinate2D)

        static func == (a: Stand, b: Stand) -> Bool {
            switch (a, b) {
            case (.nochNichtGefragt, .nochNichtGefragt), (.wirdGefragt, .wirdGefragt),
                 (.abgelehnt, .abgelehnt), (.ausgeschaltet, .ausgeschaltet), (.sucht, .sucht):
                return true
            case (.da(let x), .da(let y)):
                return x.latitude == y.latitude && x.longitude == y.longitude
            default:
                return false
            }
        }
    }

    @Published private(set) var stand: Stand = .nochNichtGefragt

    fileprivate let werk = CLLocationManager()

    override init() {
        super.init()
        werk.delegate = self
        // Haltestellen stehen an Straßenecken, nicht auf dem Zentimeter. Eine
        // genauere Ortung kostet Strom und bringt für diese App nichts.
        werk.desiredAccuracy = kCLLocationAccuracyHundredMeters
        // Erst bei zwanzig Metern Bewegung eine neue Meldung. Ohne das
        // schriebe der Dienst im Gehen jede Sekunde einen neuen Punkt, und
        // die Abfahrtstafel lüde sich in einer Endlosschleife nach.
        werk.distanceFilter = 20
        uebernimmBerechtigung(werk.authorizationStatus)
    }

    /// Fragt die Erlaubnis nach, wenn sie noch nie erfragt wurde, und startet
    /// sonst die Ortung. Beides in einem Aufruf, weil die Ansicht die
    /// Unterscheidung nicht treffen soll.
    func anfangen() {
        switch werk.authorizationStatus {
        case .notDetermined:
            stand = .wirdGefragt
            werk.requestWhenInUseAuthorization()
        case .denied:
            stand = .abgelehnt
        case .restricted:
            stand = .ausgeschaltet
        default:
            if case .da = stand {} else { stand = .sucht }
            werk.startUpdatingLocation()
        }
    }

    func aufhoeren() {
        werk.stopUpdatingLocation()
    }

    private func uebernimmBerechtigung(_ status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined: stand = .nochNichtGefragt
        case .denied: stand = .abgelehnt
        case .restricted: stand = .ausgeschaltet
        default: break
        }
    }
}

extension Standortdienst: CLLocationManagerDelegate {
    /// Die Fassung OHNE Statusargument. Die alte
    /// (`locationManager(_:didChangeAuthorization:)`) ist seit iOS 14
    /// abgekündigt und kostet bei jedem Bau eine Warnung — und der Bau dieses
    /// Repos listet Warnungen auf, damit sie nicht zur Tapete werden.
    nonisolated func locationManagerDidChangeAuthorization(_ werk: CLLocationManager) {
        let status = werk.authorizationStatus
        Task { @MainActor in
            self.uebernimmBerechtigung(status)
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                self.stand = .sucht
                // `self.werk` und nicht das Argument: Der Rückruf kommt von
                // außerhalb des Hauptfadens, und den Manager aus einem
                // nonisolated-Zusammenhang in eine Aufgabe zu reichen ist
                // genau die Art Übergabe, die Swift 6 später verbietet.
                self.werk.startUpdatingLocation()
            }
        }
    }

    nonisolated func locationManager(_ werk: CLLocationManager, didUpdateLocations orte: [CLLocation]) {
        guard let letzter = orte.last else { return }
        Task { @MainActor in
            self.stand = .da(letzter.coordinate)
        }
    }

    nonisolated func locationManager(_ werk: CLLocationManager, didFailWithError fehler: Error) {
        Task { @MainActor in
            // Ein einzelner Fehlschlag ist kein Zustand: iOS meldet ihn auch,
            // wenn es gerade noch sucht. Nur wenn NOCH NIE etwas kam, bleibt
            // die App beim Suchen stehen — einen schon gefundenen Punkt
            // wegzuwerfen wäre schlechter als ein etwas alter Punkt.
            if case .da = self.stand { return }
            if (fehler as? CLError)?.code == .denied {
                self.stand = .abgelehnt
            } else {
                self.stand = .sucht
            }
        }
    }
}
