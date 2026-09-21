import CoreLocation
import Foundation

// Der eigene Standort — nur, wenn danach gefragt wird.
//
// Die App braucht ihn für genau einen Knopf: „Hier bin ich gerade“ beim
// Setzen eines Reisepunktes. Deshalb wird die Erlaubnis auch erst bei
// diesem Knopf erfragt und nicht beim Start. Wer ablehnt, verliert eine
// Abkürzung und nichts weiter — die Karte bleibt vollständig bedienbar.
@MainActor
final class Standortdienst: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var ort: Koordinate?
    @Published var abgelehnt = false
    @Published var laeuft = false

    private let verwalter = CLLocationManager()

    override init() {
        super.init()
        verwalter.delegate = self
        verwalter.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func holen() {
        switch verwalter.authorizationStatus {
        case .notDetermined:
            laeuft = true
            verwalter.requestWhenInUseAuthorization()
        case .denied, .restricted:
            abgelehnt = true
        default:
            laeuft = true
            verwalter.requestLocation()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ verwalter: CLLocationManager) {
        Task { @MainActor in
            switch verwalter.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                abgelehnt = false
                verwalter.requestLocation()
            case .denied, .restricted:
                abgelehnt = true
                laeuft = false
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ verwalter: CLLocationManager,
                                     didUpdateLocations orte: [CLLocation]) {
        guard let letzter = orte.last else { return }
        Task { @MainActor in
            ort = Koordinate(letzter.coordinate)
            laeuft = false
        }
    }

    nonisolated func locationManager(_ verwalter: CLLocationManager, didFailWithError fehler: Error) {
        Task { @MainActor in laeuft = false }
    }
}

// Der Name zu einer Koordinate — an EINER Stelle, damit derselbe Punkt
// nicht an zwei Stellen verschieden heißt.
//
// `nil` heißt „konnte nicht nachsehen“ und nicht „heißt nicht“: Wer den
// Namen bei einem Netzaussetzer durch einen Platzhalter ersetzte, machte
// aus einer fehlenden Auskunft eine falsche.
enum Ortsname {
    static func suchen(_ ort: Koordinate) async -> String? {
        let sucher = CLGeocoder()
        let stelle = CLLocation(latitude: ort.breite, longitude: ort.laenge)
        guard let treffer = try? await sucher.reverseGeocodeLocation(stelle, preferredLocale:
            Locale(identifier: "de_DE")).first
        else { return nil }
        let teile = [treffer.locality ?? treffer.subAdministrativeArea, treffer.country]
            .compactMap { $0 }
        let name = treffer.name
        if let name, !teile.contains(name) {
            return ([name] + teile.prefix(1)).joined(separator: ", ")
        }
        return teile.isEmpty ? nil : teile.joined(separator: ", ")
    }
}
