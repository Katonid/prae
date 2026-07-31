import Foundation
import PhotoSpotCore

struct WikipediaService: Sendable {
    private let client: HTTPClient
    init(client: HTTPClient = HTTPClient()) { self.client = client }

    func enrich(_ spot: PhotoSpotCandidate, thumbnailWidth: Int) async -> PhotoSpotCandidate {
        var components = URLComponents(string: "https://en.wikipedia.org/w/api.php")!
        components.queryItems = [
            .init(name: "action", value: "query"), .init(name: "generator", value: "geosearch"),
            .init(name: "ggsprimary", value: "all"), .init(name: "ggsradius", value: "500"),
            .init(name: "ggscoord", value: "\(spot.location.latitude)|\(spot.location.longitude)"),
            .init(name: "prop", value: "extracts|pageimages|info"), .init(name: "exintro", value: "1"),
            .init(name: "explaintext", value: "1"), .init(name: "piprop", value: "thumbnail|original"),
            .init(name: "pithumbsize", value: String(min(max(thumbnailWidth, 400), 2_400))), .init(name: "inprop", value: "url"),
            .init(name: "format", value: "json"), .init(name: "formatversion", value: "2")
        ]
        guard let url = components.url,
              let data = try? await client.data(for: URLRequest(url: url), timeout: 8),
              let response = try? JSONDecoder().decode(Response.self, from: data),
              let page = response.query?.pages.min(by: { similarity($0.title, spot.name) > similarity($1.title, spot.name) }),
              similarity(page.title, spot.name) >= 0.45 else { return spot }
        var result = spot
        result.summary = page.extract ?? spot.summary
        // Prefer the server-sized thumbnail to avoid downloading a multi-megapixel original.
        result.imageURL = page.thumbnail?.source ?? page.original?.source ?? spot.imageURL
        result.hasWikipediaArticle = true
        result.mentionCount += 1
        if let width = page.original?.width, let height = page.original?.height { result.imagePixelCount = width * height }
        return result
    }

    private func similarity(_ lhs: String, _ rhs: String) -> Double {
        let a = Set(lhs.lowercased().split(separator: " ")), b = Set(rhs.lowercased().split(separator: " "))
        guard !a.union(b).isEmpty else { return 0 }
        return Double(a.intersection(b).count) / Double(a.union(b).count)
    }

    private struct Response: Decodable { let query: Query? }
    private struct Query: Decodable { let pages: [Page] }
    private struct Page: Decodable {
        let title: String; let extract: String?; let thumbnail: ImageInfo?; let original: ImageInfo?
    }
    private struct ImageInfo: Decodable { let source: URL; let width: Int?; let height: Int? }
}
