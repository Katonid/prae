import CoreLocation
import MapKit

/// Der eigene Standort, nur „während der Benutzung". Wird die Ortung
/// abgelehnt, ist das kein Fehler — Start und Ziel lassen sich suchen.
final class Standort: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var punkt: Punkt?
    @Published private(set) var erlaubnis: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()

    override init() {
        super.init()
        erlaubnis = manager.authorizationStatus
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    func anfragen() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else {
            manager.startUpdatingLocation()
        }
    }

    var abgelehnt: Bool { erlaubnis == .denied || erlaubnis == .restricted }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        DispatchQueue.main.async { self.erlaubnis = status }
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let l = locations.last else { return }
        let p = Punkt(l.coordinate)
        DispatchQueue.main.async { self.punkt = p }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}

/// Vorschläge beim Tippen, über Apples Ortssuche — ohne Schlüssel und mit
/// Adressen UND Orten (Campingplatz, Rastplatz, Bahnhof).
final class Ortssuche: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var eingabe = "" { didSet { vervollstaendiger.queryFragment = eingabe } }
    @Published private(set) var vorschlaege: [MKLocalSearchCompletion] = []
    @Published private(set) var fehler: String?

    private let vervollstaendiger = MKLocalSearchCompleter()

    override init() {
        super.init()
        vervollstaendiger.delegate = self
        vervollstaendiger.resultTypes = [.address, .pointOfInterest]
    }

    func naehe(_ p: Punkt?) {
        guard let p else { return }
        vervollstaendiger.region = MKCoordinateRegion(center: p.koordinate,
                                                      latitudinalMeters: 200_000, longitudinalMeters: 200_000)
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let liste = completer.results
        DispatchQueue.main.async {
            self.vorschlaege = liste
            self.fehler = nil
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        let text = error.localizedDescription
        DispatchQueue.main.async { self.fehler = text }
    }

    /// Aus einem Vorschlag einen Ort mit Koordinate machen.
    static func aufloesen(_ vorschlag: MKLocalSearchCompletion) async throws -> Ort {
        let antwort = try await MKLocalSearch(request: MKLocalSearch.Request(completion: vorschlag)).start()
        guard let treffer = antwort.mapItems.first else {
            throw Routenfehler.keinAnschluss("Zu diesem Vorschlag fand sich kein Ort.")
        }
        let name = vorschlag.subtitle.isEmpty ? vorschlag.title : "\(vorschlag.title), \(vorschlag.subtitle)"
        return Ort(name: name, punkt: Punkt(treffer.placemark.coordinate))
    }
}
