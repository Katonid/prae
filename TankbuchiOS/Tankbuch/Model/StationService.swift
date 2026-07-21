import Foundation
import CoreLocation
import MapKit

// Tankstellensuche wie in der PWA: mit Tankerkönig-API-Schlüssel kommen
// Livepreise (MTS-K), ohne Schlüssel liefert die Apple-Kartensuche
// Tankstellen ohne Preise. Suchradius 1,8 km wie die PWA.

struct NearbyStation: Identifiable, Equatable {
    var id: String
    var name: String
    var place: String
    var lat: Double
    var lng: Double
    var distanceKm: Double
    var prices: [String: Double] = [:]
    var isOpen: Bool?
    var source: String
    var sourceLabel: String

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    func price(for fuelType: String) -> Double? {
        prices[fuelType]
    }

    static func == (lhs: NearbyStation, rhs: NearbyStation) -> Bool {
        lhs.id == rhs.id
    }
}

enum StationServiceError: LocalizedError {
    case tankerkoenig(String)
    case network

    var errorDescription: String? {
        switch self {
        case .tankerkoenig(let message): return message
        case .network: return "Tankstellen konnten nicht geladen werden."
        }
    }
}

enum StationService {
    static let searchRadiusMeters: Double = 1800
    static let maxStations = 12

    /// Erst Tankerkönig (falls API-Schlüssel vorhanden), sonst Apple-Kartensuche.
    static func fetchNearbyStations(lat: Double, lng: Double, apiKey: String) async -> (stations: [NearbyStation], error: String?) {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedKey.isEmpty {
            do {
                let stations = try await fetchTankerkoenig(lat: lat, lng: lng, apiKey: trimmedKey)
                if !stations.isEmpty {
                    return (stations, nil)
                }
            } catch {
                let fallback = (try? await fetchAppleMaps(lat: lat, lng: lng)) ?? []
                return (fallback, "Livepreise nicht geladen: \(error.localizedDescription)")
            }
        }

        let stations = (try? await fetchAppleMaps(lat: lat, lng: lng)) ?? []
        return (stations, nil)
    }

    static func fetchTankerkoenig(lat: Double, lng: Double, apiKey: String) async throws -> [NearbyStation] {
        var components = URLComponents(string: "https://creativecommons.tankerkoenig.de/json/list.php")!
        components.queryItems = [
            URLQueryItem(name: "lat", value: String(lat)),
            URLQueryItem(name: "lng", value: String(lng)),
            URLQueryItem(name: "rad", value: String(searchRadiusMeters / 1000)),
            URLQueryItem(name: "sort", value: "dist"),
            URLQueryItem(name: "type", value: "all"),
            URLQueryItem(name: "apikey", value: apiKey)
        ]

        let (data, response) = try await URLSession.shared.data(from: components.url!)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw StationServiceError.tankerkoenig("Tankerkönig nicht erreichbar")
        }

        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw StationServiceError.tankerkoenig("Tankerkönig-Antwort unlesbar")
        }
        guard root["ok"] as? Bool == true else {
            throw StationServiceError.tankerkoenig(root["message"] as? String ?? "Tankerkönig-Fehler")
        }

        let stations = (root["stations"] as? [[String: Any]] ?? []).compactMap { raw -> NearbyStation? in
            guard let id = raw["id"] as? String,
                  let lat = doubleValue(raw["lat"]),
                  let lng = doubleValue(raw["lng"]) else { return nil }

            let street = [raw["street"] as? String, (raw["houseNumber"] as? String)]
                .compactMap { cleanTag($0) }
                .joined(separator: " ")
            let city = [postCodeText(raw["postCode"]), cleanTag(raw["place"] as? String)]
                .compactMap { $0 }
                .joined(separator: " ")
            let place = [street, city].filter { !$0.isEmpty }.joined(separator: ", ")

            var prices: [String: Double] = [:]
            if let diesel = normalizedPrice(raw["diesel"]) { prices["diesel"] = diesel }
            if let e5 = normalizedPrice(raw["e5"]) { prices["e5"] = e5 }
            if let e10 = normalizedPrice(raw["e10"]) { prices["e10"] = e10 }

            let brand = cleanTag(raw["brand"] as? String)
            let name = brand ?? cleanTag(raw["name"] as? String) ?? "Tankstelle"

            return NearbyStation(
                id: id,
                name: name,
                place: place,
                lat: lat,
                lng: lng,
                distanceKm: doubleValue(raw["dist"]) ?? 0,
                prices: prices,
                isOpen: raw["isOpen"] as? Bool,
                source: "tankerkoenig",
                sourceLabel: "Tankerkönig / MTS-K"
            )
        }

        return Array(stations.sorted { $0.distanceKm < $1.distanceKm }.prefix(maxStations))
    }

    static func fetchAppleMaps(lat: Double, lng: Double) async throws -> [NearbyStation] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "Tankstelle"
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.gasStation])
        request.resultTypes = .pointOfInterest
        request.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: lat, longitude: lng),
            latitudinalMeters: searchRadiusMeters * 2,
            longitudinalMeters: searchRadiusMeters * 2
        )

        let response = try await MKLocalSearch(request: request).start()
        let origin = CLLocation(latitude: lat, longitude: lng)

        let stations = response.mapItems.compactMap { item -> NearbyStation? in
            let coordinate = item.placemark.coordinate
            let distance = origin.distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
            guard distance <= searchRadiusMeters * 1.5 else { return nil }

            let street = [item.placemark.thoroughfare, item.placemark.subThoroughfare]
                .compactMap { $0 }
                .joined(separator: " ")
            let city = [item.placemark.postalCode, item.placemark.locality]
                .compactMap { $0 }
                .joined(separator: " ")
            let place = [street, city].filter { !$0.isEmpty }.joined(separator: ", ")

            return NearbyStation(
                id: "apple-\(coordinate.latitude)-\(coordinate.longitude)",
                name: item.name ?? "Tankstelle",
                place: place,
                lat: coordinate.latitude,
                lng: coordinate.longitude,
                distanceKm: distance / 1000,
                source: "apple",
                sourceLabel: "Apple Karten"
            )
        }

        return Array(stations.sorted { $0.distanceKm < $1.distanceKm }.prefix(maxStations))
    }

    /// Ort/Adresse in Koordinaten auflösen (ersetzt Nominatim der PWA).
    /// Erst der Adress-Geocoder (zuverlässig für Orte und Adressen), bei
    /// Fehlschlag die Apple-Suche, die auch unscharfe Eingaben versteht.
    static func geocode(place: String) async -> (coordinate: CLLocationCoordinate2D, label: String)? {
        let geocoder = CLGeocoder()
        if let placemark = try? await geocoder.geocodeAddressString(place).first,
           let location = placemark.location {
            let label = [placemark.name, placemark.locality]
                .compactMap { $0 }
                .reduce(into: [String]()) { result, part in
                    if !result.contains(part) { result.append(part) }
                }
                .joined(separator: ", ")
            return (location.coordinate, label.isEmpty ? place : label)
        }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = place
        guard let response = try? await MKLocalSearch(request: request).start(),
              let item = response.mapItems.first else { return nil }
        let label = [item.name, item.placemark.locality]
            .compactMap { $0 }
            .reduce(into: [String]()) { result, part in
                if !result.contains(part) { result.append(part) }
            }
            .joined(separator: ", ")
        return (item.placemark.coordinate, label.isEmpty ? place : label)
    }

    // MARK: Hilfen

    private static func cleanTag(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }

    private static func postCodeText(_ value: Any?) -> String? {
        if let number = value as? NSNumber { return number.stringValue }
        return cleanTag(value as? String)
    }

    private static func doubleValue(_ value: Any?) -> Double? {
        if let number = value as? NSNumber {
            let result = number.doubleValue
            return result.isFinite ? result : nil
        }
        if let text = value as? String { return Double(text) }
        return nil
    }

    private static func normalizedPrice(_ value: Any?) -> Double? {
        guard let price = doubleValue(value), price > 0 else { return nil }
        return price
    }
}

// MARK: - Standort

@MainActor
final class LocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var lastCoordinate: CLLocationCoordinate2D?
    @Published var accuracy: Double?
    @Published var statusText = "Noch nicht abgefragt"
    @Published var isRequesting = false

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// Fragt einmalig die aktuelle Position ab (inkl. Berechtigung).
    func requestLocation() async -> CLLocationCoordinate2D? {
        if isRequesting { return lastCoordinate }
        isRequesting = true
        statusText = "Standort wird abgefragt..."
        defer { isRequesting = false }

        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
            // Auf die Entscheidung warten; locationManagerDidChangeAuthorization setzt fort.
            let granted = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
                authorizationContinuation = cont
            }
            if !granted {
                statusText = "Standortberechtigung abgelehnt"
                return nil
            }
        }

        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            break
        default:
            statusText = "Standortberechtigung abgelehnt"
            return nil
        }

        let coordinate = await withCheckedContinuation { (cont: CheckedContinuation<CLLocationCoordinate2D?, Never>) in
            continuation = cont
            manager.requestLocation()
        }

        if let coordinate {
            lastCoordinate = coordinate
            statusText = accuracy.map { "Position ± \(Int($0)) m" } ?? "Position gefunden"
        } else {
            statusText = "Standort nicht verfügbar"
        }
        return coordinate
    }

    private var authorizationContinuation: CheckedContinuation<Bool, Never>?

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            guard let cont = authorizationContinuation else { return }
            authorizationContinuation = nil
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                cont.resume(returning: true)
            case .notDetermined:
                authorizationContinuation = cont
            default:
                cont.resume(returning: false)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location = locations.last
        Task { @MainActor in
            accuracy = location.map { max(0, $0.horizontalAccuracy.rounded()) }
            continuation?.resume(returning: location?.coordinate)
            continuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            continuation?.resume(returning: nil)
            continuation = nil
        }
    }
}
