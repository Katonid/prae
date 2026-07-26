import Foundation
import CoreLocation

// "Heute in der Nähe" über die Overpass-API (OpenStreetMap) –
// portiert aus src/services/nearbyService.js der PWA: gleiche Abfrage
// (Parken, Essen, Café, Supermarkt, Shopping, Tanken im Umkreis).

struct NearbyPlace: Identifiable, Equatable {
    let id: String
    let name: String
    let lat: Double
    let lng: Double
    let category: String
    let categoryLabel: String
    let detail: String
    let distanceKm: Double

    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: lat, longitude: lng) }
    var mapsUrl: URL? {
        URL(string: "https://www.google.com/maps/search/?api=1&query=\(lat),\(lng)")
    }
}

enum NearbyCategory: String, CaseIterable, Identifiable {
    case all
    case parking
    case food
    case cafe
    case supermarket
    case shopping
    case fuel

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "Alles"
        case .parking: return "Parken"
        case .food: return "Essen"
        case .cafe: return "Café"
        case .supermarket: return "Supermarkt"
        case .shopping: return "Shopping"
        case .fuel: return "Tanken"
        }
    }
}

final class NearbyService {
    static let shared = NearbyService()
    private static let endpoint = URL(string: "https://overpass-api.de/api/interpreter")!

    private struct OverpassResponse: Decodable {
        struct Element: Decodable {
            struct Center: Decodable {
                let lat: Double
                let lon: Double
            }
            let type: String
            let id: Int64
            let lat: Double?
            let lon: Double?
            let center: Center?
            let tags: [String: String]?
        }
        let elements: [Element]
    }

    func fetchNearby(lat: Double, lng: Double, radius: Int = 3000) async throws -> [NearbyPlace] {
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("text/plain; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.query(lat: lat, lng: lng, radius: radius).data(using: .utf8)
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let parsed = try JSONDecoder().decode(OverpassResponse.self, from: data)

        var seen = Set<String>()
        return parsed.elements
            .compactMap { Self.normalize($0, centerLat: lat, centerLng: lng) }
            .filter { place in
                let key = "\(place.category)-\(place.name)-\(String(format: "%.5f", place.lat))-\(String(format: "%.5f", place.lng))"
                return seen.insert(key).inserted
            }
            .sorted { $0.distanceKm < $1.distanceKm }
    }

    private static func query(lat: Double, lng: Double, radius: Int) -> String {
        let around = "around:\(radius),\(lat),\(lng)"
        var lines: [String] = ["[out:json][timeout:25];", "("]
        let selectors = [
            "[\"amenity\"=\"parking\"]",
            "[\"amenity\"=\"parking_entrance\"]",
            "[\"amenity\"~\"^(restaurant|fast_food|cafe|food_court)$\"]",
            "[\"shop\"=\"supermarket\"]",
            "[\"shop\"=\"mall\"]",
            "[\"building\"=\"retail\"]",
            "[\"landuse\"=\"retail\"]",
            "[\"amenity\"=\"fuel\"]"
        ]
        for selector in selectors {
            for kind in ["node", "way", "relation"] {
                lines.append("  \(kind)(\(around))\(selector);")
            }
        }
        lines.append(");")
        lines.append("out center tags;")
        return lines.joined(separator: "\n")
    }

    private static func normalize(_ element: OverpassResponse.Element, centerLat: Double, centerLng: Double) -> NearbyPlace? {
        let tags = element.tags ?? [:]
        guard let lat = element.lat ?? element.center?.lat,
              let lng = element.lon ?? element.center?.lon,
              let category = detectCategory(tags)
        else { return nil }

        let name = tags["name"] ?? fallbackName(category)
        let from = CLLocation(latitude: centerLat, longitude: centerLng)
        let to = CLLocation(latitude: lat, longitude: lng)
        let distanceKm = from.distance(from: to) / 1000

        return NearbyPlace(
            id: "\(element.type)-\(element.id)",
            name: name,
            lat: lat,
            lng: lng,
            category: category.rawValue,
            categoryLabel: category.label,
            detail: detailText(category, tags),
            distanceKm: distanceKm
        )
    }

    private static func detectCategory(_ tags: [String: String]) -> NearbyCategory? {
        let amenity = tags["amenity"] ?? ""
        if amenity == "parking" || amenity == "parking_entrance" { return .parking }
        if amenity == "cafe" { return .cafe }
        if ["restaurant", "fast_food", "food_court"].contains(amenity) { return .food }
        if amenity == "fuel" { return .fuel }
        if tags["shop"] == "supermarket" { return .supermarket }
        if tags["shop"] == "mall" || tags["building"] == "retail" || tags["landuse"] == "retail" { return .shopping }
        return nil
    }

    private static func fallbackName(_ category: NearbyCategory) -> String {
        switch category {
        case .parking: return "Parkplatz"
        case .food: return "Restaurant"
        case .cafe: return "Café"
        case .supermarket: return "Supermarkt"
        case .shopping: return "Einkaufsmöglichkeit"
        case .fuel: return "Tankstelle"
        case .all: return "Ort"
        }
    }

    private static func detailText(_ category: NearbyCategory, _ tags: [String: String]) -> String {
        var parts: [String] = []
        if category == .parking {
            if let capacity = tags["capacity"], !capacity.isEmpty { parts.append("\(capacity) Plätze") }
            if tags["fee"] == "yes" { parts.append("gebührenpflichtig") }
            if tags["fee"] == "no" { parts.append("kostenlos") }
            if tags["access"] == "customers" { parts.append("für Kunden") }
            if let parking = tags["parking"], !parking.isEmpty { parts.append(parking == "surface" ? "ebenerdig" : parking) }
        }
        if let cuisine = tags["cuisine"], !cuisine.isEmpty {
            parts.append(cuisine.replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: ";", with: ", "))
        }
        if let opening = tags["opening_hours"], !opening.isEmpty, opening.count <= 40 {
            parts.append(opening)
        }
        return parts.joined(separator: " · ")
    }
}
