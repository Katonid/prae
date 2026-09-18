import CoreLocation

/// Der Name zu einer Koordinate — die eine Stelle dafür.
///
/// Gebraucht wird er an zwei Enden: in der Ortswahl unter dem Fadenkreuz und
/// seit 1.1.13 beim Versetzen des Suchpunkts auf der Netzkarte (dort seit
/// 1.1.15 ebenfalls unter einem Fadenkreuz). Zwei Fassungen benannten
/// denselben Punkt irgendwann verschieden, und der Nutzer sähe zwei Namen für
/// dieselbe Stelle.
enum Ortsname {

    /// Was dort steht, wenn sich kein Name finden lässt. Ein leeres Feld wäre
    /// schlimmer: Der Punkt IST gewählt, er hat nur keinen Namen.
    static let unbekannt = "Punkt auf der Karte"

    /// Sucht den Namen zu einer Koordinate.
    ///
    /// **`nil` heißt „konnte nicht nachsehen" und NICHT „heißt nicht".** Der
    /// Unterschied zählt: Die Ortswahl behält bei `nil` den Namen von vorhin,
    /// statt ihn während des Schiebens durch einen Platzhalter zu ersetzen.
    /// Dieselbe Trennung wie zwischen „kein Mitglied gefunden" und „konnte
    /// nicht nachsehen" in Schulalarm.
    static func fuer(_ punkt: CLLocationCoordinate2D) async -> String? {
        let ort = CLLocation(latitude: punkt.latitude, longitude: punkt.longitude)
        guard let marke = try? await CLGeocoder().reverseGeocodeLocation(ort).first else { return nil }
        let teile = [marke.thoroughfare, marke.locality ?? marke.subAdministrativeArea]
            .compactMap { $0 }
        return teile.isEmpty ? unbekannt : teile.joined(separator: ", ")
    }
}
