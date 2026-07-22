//
//  DiscoveryService.swift
//  FlightMate
//
//  Spot-Entdeckung (PRD F9), erste Ausbaustufe — datengetrieben statt
//  erfunden: Foto-Orte (Aussichtspunkte, Gipfel, Wasserfälle, Burgen,
//  Leuchttürme) kommen aus OpenStreetMap (Overpass API, ODbL);
//  die Drohnentauglichkeit prüft FlightMate selbst — jeder Kandidat
//  läuft durch den echten Legal-Check und den Flight Score. Das ist
//  der PRD-Unterschied zum „Instagram-Klon": geprüft, nicht nur schön.
//  Keine Likes, keine Feeds (PRD N2) — nur Orte.
//

import Foundation
import CoreLocation

struct SpotCandidate: Identifiable, Hashable {
    enum Kind: String, CaseIterable, Identifiable {
        case viewpoint
        case peak
        case waterfall
        case castle
        case lighthouse

        var id: String { rawValue }

        var title: String {
            switch self {
            case .viewpoint: return "Aussichtspunkt"
            case .peak: return "Gipfel"
            case .waterfall: return "Wasserfall"
            case .castle: return "Burg & Schloss"
            case .lighthouse: return "Leuchtturm"
            }
        }

        var symbol: String {
            switch self {
            case .viewpoint: return "binoculars"
            case .peak: return "mountain.2"
            case .waterfall: return "water.waves"
            case .castle: return "building.columns"
            case .lighthouse: return "light.beacon.max"
            }
        }

        /// Overpass-Tag-Filter. Gipfel/Burgen nur mit Namen, sonst
        /// verrauschen tausende unbenannte Knoten die Liste.
        var osmFilter: String {
            switch self {
            case .viewpoint: return "[\"tourism\"=\"viewpoint\"]"
            case .peak: return "[\"natural\"=\"peak\"][\"name\"]"
            case .waterfall: return "[\"waterway\"=\"waterfall\"]"
            case .castle: return "[\"historic\"=\"castle\"][\"name\"]"
            case .lighthouse: return "[\"man_made\"=\"lighthouse\"]"
            }
        }
    }

    let id: String
    let name: String
    let kind: Kind
    let latitude: Double
    let longitude: Double
    let distanceM: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var distanceText: String {
        distanceM < 1000
            ? "\(Int(distanceM)) m"
            : String(format: "%.1f km", distanceM / 1000)
    }
}

enum DiscoveryService {

    static func candidates(around center: CLLocationCoordinate2D, radiusM: Int,
                           kinds: Set<SpotCandidate.Kind>) async throws -> [SpotCandidate] {
        guard !kinds.isEmpty else { return [] }

        let nodeQueries = kinds
            .map { "node\($0.osmFilter)(around:\(radiusM),\(center.latitude),\(center.longitude));" }
            .joined()
        let query = "[out:json][timeout:20];(\(nodeQueries));out body 80;"

        var request = URLRequest(url: URL(string: "https://overpass-api.de/api/interpreter")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.setValue("FlightMateAI/1.0 (private Drohnen-Foto-App)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? query
        request.httpBody = "data=\(encoded)".data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw GeoQueryError.badResponse
        }

        struct OverpassResult: Decodable {
            struct Element: Decodable {
                let id: Int64
                let lat: Double
                let lon: Double
                let tags: [String: String]?
            }
            let elements: [Element]
        }
        let result = try JSONDecoder().decode(OverpassResult.self, from: data)
        let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)

        return result.elements.compactMap { element -> SpotCandidate? in
            let tags = element.tags ?? [:]
            guard let kind = kind(for: tags), kinds.contains(kind) else { return nil }
            let distance = CLLocation(latitude: element.lat, longitude: element.lon)
                .distance(from: centerLocation)
            return SpotCandidate(
                id: "osm-\(element.id)",
                name: tags["name"] ?? kind.title,
                kind: kind,
                latitude: element.lat,
                longitude: element.lon,
                distanceM: distance
            )
        }
        .sorted { $0.distanceM < $1.distanceM }
    }

    private static func kind(for tags: [String: String]) -> SpotCandidate.Kind? {
        if tags["tourism"] == "viewpoint" { return .viewpoint }
        if tags["natural"] == "peak" { return .peak }
        if tags["waterway"] == "waterfall" { return .waterfall }
        if tags["historic"] == "castle" { return .castle }
        if tags["man_made"] == "lighthouse" { return .lighthouse }
        return nil
    }
}
