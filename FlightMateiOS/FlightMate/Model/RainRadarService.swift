//
//  RainRadarService.swift
//  FlightMate
//
//  Regenradar (Nutzerwunsch): RainViewer liefert ein weltweites
//  Radar-Komposit als Kartenkacheln — kostenlos, ohne Schlüssel.
//  Der Katalog (weather-maps.json) nennt die verfügbaren Zeitschritte:
//  ~2 h Vergangenheit plus ~30 min Kurzprognose. Ehrliche Grenzen:
//  Die Abdeckung hängt vom regionalen Radarnetz ab (Mitteleuropa und
//  Nordamerika gut, offenes Meer/entlegene Gebiete lückenhaft), und
//  die Prognose-Frames sind eine kurze Extrapolation, kein Modell.
//

import Foundation

enum RainRadarService {

    struct Frame: Identifiable, Equatable {
        let time: Date
        let path: String
        var id: String { path }
    }

    struct Catalog {
        let host: String
        let past: [Frame]
        let nowcast: [Frame]

        var all: [Frame] { past + nowcast }

        /// Kachel-Vorlage für MKTileOverlay ({z}/{x}/{y} ersetzt MapKit).
        /// Farbschema 4 = „Universal Blue", 1_1 = weichgezeichnet + Schnee.
        func tileTemplate(for frame: Frame) -> String {
            "\(host)\(frame.path)/256/{z}/{x}/{y}/4/1_1.png"
        }
    }

    private struct APIResponse: Decodable {
        struct Radar: Decodable {
            struct Item: Decodable {
                let time: Int
                let path: String
            }
            let past: [Item]
            let nowcast: [Item]?
        }
        let host: String
        let radar: Radar
    }

    static func fetchCatalog() async throws -> Catalog {
        let url = URL(string: "https://api.rainviewer.com/public/weather-maps.json")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let api = try JSONDecoder().decode(APIResponse.self, from: data)
        func frames(_ items: [APIResponse.Radar.Item]) -> [Frame] {
            items.map { Frame(time: Date(timeIntervalSince1970: TimeInterval($0.time)),
                              path: $0.path) }
        }
        return Catalog(host: api.host,
                       past: frames(api.radar.past),
                       nowcast: frames(api.radar.nowcast ?? []))
    }
}
