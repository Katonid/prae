import Foundation
import CoreLocation

// Einmal-Standort mit Reverse-Geocoding.
//
// Beim automatischen Erfassen einer Apple-Pay-Zahlung (Kurzbefehl-Intent)
// läuft die App im Hintergrund — dafür braucht es die Berechtigung
// „Immer" (sonst klappt nur die Erfassung mit geöffneter App, der Eintrag
// wird dann ohne Ort gespeichert und kann nachträglich ergänzt werden).

struct PlaceFix {
    var latitude: Double
    var longitude: Double
    var placeName: String
    var countryName: String
    var countryCode: String
}

final class LocationService: NSObject, CLLocationManagerDelegate {
    static let shared = LocationService()

    private let manager = CLLocationManager()
    private var continuations: [CheckedContinuation<CLLocation?, Never>] = []
    private let lock = NSLock()

    override private init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var authorizationStatus: CLAuthorizationStatus { manager.authorizationStatus }

    func requestPermission() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            // Zweite Stufe für die Hintergrund-Erfassung per Kurzbefehl.
            manager.requestAlwaysAuthorization()
        default:
            break
        }
    }

    /// Aktueller Standort mit Timeout; fällt auf den letzten bekannten Standort zurück.
    func currentLocation(timeout: TimeInterval = 6) async -> CLLocation? {
        let status = manager.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            return manager.location
        }

        let location = await withCheckedContinuation { (continuation: CheckedContinuation<CLLocation?, Never>) in
            lock.lock()
            continuations.append(continuation)
            lock.unlock()
            manager.requestLocation()
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { [weak self] in
                self?.resolve(with: nil)
            }
        }
        return location ?? manager.location
    }

    /// Standort samt Ortsname und Land ("Dortmund, Deutschland").
    func currentPlace(timeout: TimeInterval = 6) async -> PlaceFix? {
        guard let location = await currentLocation(timeout: timeout) else { return nil }
        var fix = PlaceFix(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            placeName: "",
            countryName: "",
            countryCode: ""
        )
        if let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first {
            let city = placemark.locality ?? placemark.subAdministrativeArea ?? placemark.administrativeArea ?? ""
            let country = placemark.country ?? ""
            fix.countryName = country
            fix.countryCode = placemark.isoCountryCode ?? ""
            fix.placeName = [city, country].filter { !$0.isEmpty }.joined(separator: ", ")
        }
        return fix
    }

    private func resolve(with location: CLLocation?) {
        lock.lock()
        let waiting = continuations
        continuations.removeAll()
        lock.unlock()
        for continuation in waiting {
            continuation.resume(returning: location)
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        resolve(with: locations.last)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        resolve(with: nil)
    }
}
