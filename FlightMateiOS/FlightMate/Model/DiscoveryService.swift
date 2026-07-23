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

struct SpotCandidate: Identifiable, Hashable, Codable {
    enum Kind: String, CaseIterable, Identifiable, Codable {
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
    /// OSM-Bildverweise, falls am Knoten gepflegt (image=…-URL bzw.
    /// wikimedia_commons=File:…) — Grundlage für die Foto-Galerie.
    var imageTag: String? = nil
    var commonsFile: String? = nil

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

    /// Öffentliche Overpass-Instanzen; die Hauptinstanz ist zu Stoßzeiten
    /// oft überlastet (504) — deshalb werden die Spiegel der Reihe nach
    /// probiert, bis einer antwortet.
    private static let endpoints = [
        "https://overpass-api.de/api/interpreter",
        "https://overpass.private.coffee/api/interpreter",
        "https://maps.mail.ru/osm/tools/overpass/api/interpreter",
        "https://overpass.kumi.systems/api/interpreter",
    ]

    /// Jede Kategorie läuft als eigene kleine Abfrage parallel — eine
    /// große kombinierte Abfrage scheitert auf den ausgelasteten
    /// öffentlichen Servern deutlich öfter (vom Nutzer beobachtet:
    /// weniger Kategorien → Suche klappt). Was durchkommt, wird
    /// angezeigt; Fehler nur, wenn ALLE Kategorien scheitern.
    static func candidates(around center: CLLocationCoordinate2D, radiusM: Int,
                           kinds: Set<SpotCandidate.Kind>) async throws -> [SpotCandidate] {
        guard !kinds.isEmpty else { return [] }

        var all: [SpotCandidate] = []
        var successes = 0
        await withTaskGroup(of: [SpotCandidate]?.self) { group in
            for kind in kinds {
                group.addTask {
                    try? await fetch(kind: kind, center: center, radiusM: radiusM)
                }
            }
            for await result in group {
                if let result {
                    successes += 1
                    all.append(contentsOf: result)
                }
            }
        }
        guard successes > 0 else { throw GeoQueryError.badResponse }
        return all.sorted { $0.distanceM < $1.distanceM }
    }

    // MARK: Ergebnis-Gedächtnis über App-Starts hinweg

    /// Die letzte erfolgreiche Suche wird auf dem Gerät gesichert.
    /// Beim nächsten App-Start erscheint sie sofort wieder, solange
    /// das Suchzentrum höchstens ~100 m entfernt liegt und Umkreis
    /// und Kategorien unverändert sind (Nutzerwunsch: kein ständiges
    /// Neu-Aufbauen; Aktualisieren jederzeit per Knopf/Ziehen).
    private struct StoredSearch: Codable {
        let centerLat: Double
        let centerLon: Double
        let radiusM: Int
        let kinds: [String]
        let savedAt: Date
        let candidates: [SpotCandidate]
    }

    private static var resultsFile: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("discovery-results.json")
    }

    static func storeResults(_ candidates: [SpotCandidate],
                             center: CLLocationCoordinate2D, radiusM: Int,
                             kinds: Set<SpotCandidate.Kind>) {
        let stored = StoredSearch(
            centerLat: center.latitude, centerLon: center.longitude,
            radiusM: radiusM, kinds: kinds.map(\.rawValue).sorted(),
            savedAt: Date(), candidates: candidates)
        if let data = try? JSONEncoder().encode(stored) {
            try? data.write(to: resultsFile)
        }
    }

    static func storedResults(center: CLLocationCoordinate2D, radiusM: Int,
                              kinds: Set<SpotCandidate.Kind>,
                              toleranceM: Double = 100,
                              maxAge: TimeInterval = 7 * 86_400) -> [SpotCandidate]? {
        guard let data = try? Data(contentsOf: resultsFile),
              let stored = try? JSONDecoder().decode(StoredSearch.self, from: data),
              Date().timeIntervalSince(stored.savedAt) < maxAge,
              stored.radiusM == radiusM,
              stored.kinds == kinds.map(\.rawValue).sorted() else { return nil }
        let storedCenter = CLLocation(latitude: stored.centerLat, longitude: stored.centerLon)
        let requested = CLLocation(latitude: center.latitude, longitude: center.longitude)
        guard requested.distance(from: storedCenter) <= toleranceM else { return nil }
        return stored.candidates
    }

    private static func fetch(kind: SpotCandidate.Kind, center: CLLocationCoordinate2D,
                              radiusM: Int) async throws -> [SpotCandidate] {
        let query = "[out:json][timeout:10];node\(kind.osmFilter)(around:\(radiusM),\(center.latitude),\(center.longitude));out body 40;"
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? query
        let body = "data=\(encoded)".data(using: .utf8)

        var data: Data?
        for endpoint in endpoints {
            var request = URLRequest(url: URL(string: endpoint)!)
            request.httpMethod = "POST"
            request.timeoutInterval = 15
            request.setValue("FlightMateAI/1.0 (private Drohnen-Foto-App)", forHTTPHeaderField: "User-Agent")
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = body

            if let (received, response) = try? await URLSession.shared.data(for: request),
               (response as? HTTPURLResponse)?.statusCode == 200 {
                data = received
                break
            }
            // Nicht erreichbar oder überlastet (429/504) → nächster Spiegel.
        }
        guard let data else { throw GeoQueryError.badResponse }

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

        return result.elements.map { element in
            let tags = element.tags ?? [:]
            let distance = CLLocation(latitude: element.lat, longitude: element.lon)
                .distance(from: centerLocation)
            return SpotCandidate(
                id: "osm-\(element.id)",
                name: tags["name"] ?? kind.title,
                kind: kind,
                latitude: element.lat,
                longitude: element.lon,
                distanceM: distance,
                imageTag: tags["image"],
                commonsFile: tags["wikimedia_commons"]
            )
        }
    }
}
