import Foundation
import CoreLocation

/// Wegesrand-Suche in OpenStreetMap (Overpass API): findet benannte Orte
/// und typisierte Objekte (z. B. Industriebrachen) im Umkreis der eigenen
/// Tracks. Bewusst als explizite Aktion (Knopf) — jede Anfrage geht ins
/// Netz an den freien Overpass-Server.
enum POISearch {
    struct Hit: Identifiable {
        let id: String
        let name: String
        let dayKey: String
        let distance: CLLocationDistance
        let latitude: Double
        let longitude: Double
    }

    struct DayTrack {
        let dayKey: String
        let points: [TrackPoint]
    }

    static let attribution = "Daten © OpenStreetMap-Mitwirkende (ODbL)"

    /// Kuratierte deutsche Begriffe → OSM-Tag-Filter. Zusätzlich läuft
    /// immer eine Namenssuche — die Tabelle findet auch namenlose
    /// Objekte („Industriebrache“ heißt in OSM landuse=brownfield).
    private static let tagFilters: [String: [String]] = [
        "industriebrache": ["[\"landuse\"=\"brownfield\"]"],
        "brache": ["[\"landuse\"=\"brownfield\"]"],
        "windrad": ["[\"generator:source\"=\"wind\"]"],
        "aussichtsturm": ["[\"tower:type\"=\"observation\"]"],
        "aussichtspunkt": ["[\"tourism\"=\"viewpoint\"]"],
        "spielplatz": ["[\"leisure\"=\"playground\"]"],
        "friedhof": ["[\"landuse\"=\"cemetery\"]"],
        "burg": ["[\"historic\"=\"castle\"]"],
        "schloss": ["[\"historic\"=\"castle\"]"],
        "ruine": ["[\"historic\"=\"ruins\"]"],
        "denkmal": ["[\"historic\"=\"memorial\"]", "[\"historic\"=\"monument\"]"],
        "kirche": ["[\"amenity\"=\"place_of_worship\"]"],
        "bahnhof": ["[\"railway\"=\"station\"]"],
        "bunker": ["[\"military\"=\"bunker\"]"],
        "zeche": ["[\"man_made\"=\"mineshaft\"]"],
        "halde": ["[\"man_made\"=\"spoil_heap\"]"],
        "wasserfall": ["[\"waterway\"=\"waterfall\"]"],
        "leuchtturm": ["[\"man_made\"=\"lighthouse\"]"],
        "windmühle": ["[\"man_made\"=\"windmill\"]"],
        "biergarten": ["[\"amenity\"=\"biergarten\"]"],
        "wildpark": ["[\"tourism\"=\"zoo\"]"],
    ]

    /// Namen für namenlose Treffer aus der Tag-Tabelle.
    private static func fallbackName(tags: [String: String]) -> String {
        if tags["landuse"] == "brownfield" { return "Industriebrache" }
        if tags["generator:source"] == "wind" { return "Windrad" }
        if tags["tourism"] == "viewpoint" { return "Aussichtspunkt" }
        if tags["historic"] == "ruins" { return "Ruine" }
        if tags["military"] == "bunker" { return "Bunker" }
        if tags["man_made"] == "spoil_heap" { return "Halde" }
        if tags["landuse"] == "cemetery" { return "Friedhof" }
        if tags["leisure"] == "playground" { return "Spielplatz" }
        return ""
    }

    static func search(term rawTerm: String, days: [DayTrack], maxDistance: CLLocationDistance = 300) async throws -> [Hit] {
        let term = rawTerm.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard term.count >= 3 else { return [] }

        // Kompakte Tages-Boxen (Fernreise-Tage > 60 km Ausdehnung würden
        // die Abfrage sprengen und werden übersprungen).
        struct DayBox {
            let dayKey: String
            let points: [TrackPoint]
            let south: Double, west: Double, north: Double, east: Double
        }
        var boxes: [DayBox] = []
        for day in days {
            guard day.points.count > 1,
                  let minLat = day.points.map(\.lat).min(),
                  let maxLat = day.points.map(\.lat).max(),
                  let minLon = day.points.map(\.lon).min(),
                  let maxLon = day.points.map(\.lon).max() else { continue }
            let diagonal = CLLocation(latitude: minLat, longitude: minLon)
                .distance(from: CLLocation(latitude: maxLat, longitude: maxLon))
            guard diagonal < 60_000 else { continue }
            let pad = 0.004   // ≈ 400 m Polster
            boxes.append(DayBox(
                dayKey: day.dayKey,
                points: TrackMath.downsample(day.points, maxCount: 150),
                south: minLat - pad, west: minLon - pad,
                north: maxLat + pad, east: maxLon + pad
            ))
        }
        guard !boxes.isEmpty else { return [] }

        // Overpass-Abfrage: Namenssuche + ggf. Tag-Filter je Tages-Box.
        let escaped = NSRegularExpression.escapedPattern(for: term)
        let filters = tagFilters[term] ?? []
        var statements: [String] = []
        for box in boxes.prefix(45) {
            let bbox = "(\(box.south),\(box.west),\(box.north),\(box.east))"
            statements.append("nwr[\"name\"~\"\(escaped)\",i]\(bbox);")
            for filter in filters {
                statements.append("nwr\(filter)\(bbox);")
            }
        }
        let query = "[out:json][timeout:25];(\(statements.joined()));out center 200;"

        var request = URLRequest(url: URL(string: "https://overpass-api.de/api/interpreter")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("Tagesspur/1.0 (private iOS-App)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? query
        request.httpBody = Data("data=\(encoded)".utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(OverpassResponse.self, from: data)

        // Treffer den Tagen zuordnen: nur ≤ maxDistance vom Track.
        var hits: [Hit] = []
        var seen = Set<String>()
        for element in decoded.elements {
            guard let (lat, lon) = element.coordinate else { continue }
            let tags = element.tags ?? [:]
            let name = tags["name"] ?? fallbackName(tags: tags)
            guard !name.isEmpty else { continue }
            let location = CLLocation(latitude: lat, longitude: lon)
            for box in boxes {
                guard lat >= box.south, lat <= box.north, lon >= box.west, lon <= box.east else { continue }
                let distance = box.points
                    .map { location.distance(from: CLLocation(latitude: $0.lat, longitude: $0.lon)) }
                    .min() ?? .infinity
                guard distance <= maxDistance else { continue }
                let key = "\(element.type)-\(element.id)-\(box.dayKey)"
                guard seen.insert(key).inserted else { continue }
                hits.append(Hit(id: key, name: name, dayKey: box.dayKey, distance: distance, latitude: lat, longitude: lon))
            }
        }
        return hits.sorted {
            $0.dayKey == $1.dayKey ? $0.distance < $1.distance : $0.dayKey > $1.dayKey
        }
    }

    // MARK: - Overpass-Antwort

    private struct OverpassResponse: Codable {
        let elements: [Element]

        struct Element: Codable {
            let type: String
            let id: Int
            let lat: Double?
            let lon: Double?
            let center: Center?
            let tags: [String: String]?

            struct Center: Codable {
                let lat: Double
                let lon: Double
            }

            var coordinate: (Double, Double)? {
                if let lat, let lon { return (lat, lon) }
                if let center { return (center.lat, center.lon) }
                return nil
            }
        }
    }
}
