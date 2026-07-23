//
//  SpotImageService.swift
//  FlightMate
//
//  Fotos zu entdeckten Spots (Nutzerwunsch): Was sieht man dort
//  eigentlich? Quellen — beide offen, ohne Schlüssel:
//    1. Bildverweise direkt am OSM-Knoten (image=…-URL bzw.
//       wikimedia_commons=File:…)
//    2. Wikimedia-Commons-GeoSearch: frei lizenzierte Fotos im
//       Umkreis der Koordinate (die Bildseite mit Lizenz ist aus der
//       App heraus verlinkt — Attribution liegt beim Betrachter einen
//       Tipp entfernt)
//  Ausgeliefert werden Special:FilePath-Thumbnails (kleine Breite),
//  keine Originale — schnell und datensparsam.
//

import Foundation

enum SpotImageService {

    struct SpotImage: Identifiable {
        let id: String
        /// Verkleinertes Bild (Special:FilePath, width=640).
        let thumbnailURL: URL
        /// Commons-Bildseite (Lizenz/Urheber) — Ziel beim Antippen.
        let pageURL: URL?
    }

    /// Bilder für einen Kandidaten: erst die am OSM-Knoten gepflegten
    /// Verweise, dann Commons-Fotos aus der direkten Umgebung — nach
    /// Relevanz sortiert (Titel passt zum Spot-Namen vor Entfernung),
    /// damit nicht das Nachbarmotiv die Galerie dominiert
    /// (Nutzer-Befund: „Lake on the Mountain" zeigte die Glenora-Fähre).
    static func images(for candidate: SpotCandidate, limit: Int = 6) async -> [SpotImage] {
        var result: [SpotImage] = []
        var seen = Set<String>()

        func add(_ image: SpotImage?) {
            guard let image, !seen.contains(image.id), result.count < limit else { return }
            seen.insert(image.id)
            result.append(image)
        }

        // 1. wikimedia_commons=File:… am Knoten
        if let file = candidate.commonsFile, file.hasPrefix("File:") {
            add(commonsImage(fileTitle: file))
        }
        // 2. image=…-Tag: direkte Bild-URL oder Commons-Seiten-Link
        if let tag = candidate.imageTag, tag.hasPrefix("http") {
            if let range = tag.range(of: "/wiki/File:") {
                add(commonsImage(fileTitle: String(tag[range.lowerBound...].dropFirst(6))))
            } else if let url = URL(string: tag),
                      ["jpg", "jpeg", "png"].contains(url.pathExtension.lowercased()) {
                add(SpotImage(id: tag, thumbnailURL: url, pageURL: url))
            }
        }

        // 3. Commons-GeoSearch: eng um den Spot (150 m), sortiert nach
        //    Namenstreffer im Dateititel, dann nach Entfernung.
        let nameWords = candidate.name.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 4 }
        let nearby = await nearbyFiles(latitude: candidate.latitude,
                                       longitude: candidate.longitude)
            .sorted { a, b in
                let aMatches = nameWords.contains { a.title.lowercased().contains($0) }
                let bMatches = nameWords.contains { b.title.lowercased().contains($0) }
                if aMatches != bMatches { return aMatches }
                return a.distanceM < b.distanceM
            }
        for file in nearby {
            add(commonsImage(fileTitle: file.title))
        }
        return result
    }

    /// „File:Name.jpg" → Thumbnail- und Seiten-URL auf Commons.
    private static func commonsImage(fileTitle: String) -> SpotImage? {
        let name = fileTitle.hasPrefix("File:") ? String(fileTitle.dropFirst(5)) : fileTitle
        guard ["jpg", "jpeg", "png"].contains((name as NSString).pathExtension.lowercased()),
              let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let thumbnail = URL(string: "https://commons.wikimedia.org/wiki/Special:FilePath/\(encodedName)?width=640"),
              let encodedTitle = fileTitle.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let page = URL(string: "https://commons.wikimedia.org/wiki/\(encodedTitle)") else {
            return nil
        }
        return SpotImage(id: fileTitle, thumbnailURL: thumbnail, pageURL: page)
    }

    struct NearbyFile {
        let title: String
        let distanceM: Double
    }

    /// Frei lizenzierte Fotos im Umkreis (Wikimedia-Commons-GeoSearch,
    /// eng gefasst: 150 m), mit Entfernung fürs Relevanz-Ranking.
    private static func nearbyFiles(latitude: Double, longitude: Double) async -> [NearbyFile] {
        var components = URLComponents(string: "https://commons.wikimedia.org/w/api.php")!
        components.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "list", value: "geosearch"),
            URLQueryItem(name: "gscoord", value: "\(latitude)|\(longitude)"),
            URLQueryItem(name: "gsradius", value: "150"),
            URLQueryItem(name: "gsnamespace", value: "6"),
            URLQueryItem(name: "gslimit", value: "20"),
            URLQueryItem(name: "format", value: "json"),
        ]
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 12
        request.setValue("FlightMateAI/1.0 (private Drohnen-Foto-App)", forHTTPHeaderField: "User-Agent")

        struct Response: Decodable {
            struct Query: Decodable {
                struct Item: Decodable {
                    let title: String
                    let dist: Double?
                }
                let geosearch: [Item]
            }
            let query: Query?
        }
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let decoded = try? JSONDecoder().decode(Response.self, from: data) else {
            return []
        }
        return (decoded.query?.geosearch ?? []).map {
            NearbyFile(title: $0.title, distanceM: $0.dist ?? 0)
        }
    }
}
