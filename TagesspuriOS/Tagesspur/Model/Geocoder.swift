import Foundation
import CoreLocation

struct GeoInfo: Sendable {
    var name: String
    var locality: String
    var thoroughfare: String
    var inlandWater: String
    var ocean: String
    var areas: String
}

/// Serialisiertes, gedrosseltes Reverse-Geocoding mit Cache.
/// Apple erlaubt nur wenige Anfragen pro Minute — hier läuft maximal
/// eine Anfrage alle 2 Sekunden, identische Koordinaten kommen aus dem Cache.
actor Geocoder {
    static let shared = Geocoder()

    private let geocoder = CLGeocoder()
    private var cache: [String: GeoInfo] = [:]
    private var lastRequest = Date.distantPast

    func info(for coordinate: CLLocationCoordinate2D) async -> GeoInfo? {
        let key = String(format: "%.3f,%.3f", coordinate.latitude, coordinate.longitude)
        if let cached = cache[key] { return cached }

        let wait = 2.0 - Date().timeIntervalSince(lastRequest)
        if wait > 0 {
            try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
        }
        lastRequest = Date()

        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let placemark = try? await geocoder.reverseGeocodeLocation(location).first else {
            return nil
        }
        let info = GeoInfo(
            name: placemark.name ?? "",
            locality: placemark.locality ?? "",
            thoroughfare: placemark.thoroughfare ?? "",
            inlandWater: placemark.inlandWater ?? "",
            ocean: placemark.ocean ?? "",
            areas: (placemark.areasOfInterest ?? []).joined(separator: ", ")
        )
        cache[key] = info
        return info
    }
}
