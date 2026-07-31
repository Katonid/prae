import Foundation
import PhotoSpotCore

struct FlickrService: Sendable {
    private let client: HTTPClient
    init(client: HTTPClient = HTTPClient()) { self.client = client }

    func connectionStatus() async -> String {
        guard let apiKey = FlickrAPIKeyStore.load(), !apiKey.isEmpty else {
            return "Kein API-Schlüssel gespeichert."
        }
        var components = URLComponents(string: "https://www.flickr.com/services/rest/")!
        components.queryItems = [
            .init(name: "method", value: "flickr.test.echo"), .init(name: "api_key", value: apiKey),
            .init(name: "format", value: "json"), .init(name: "nojsoncallback", value: "1")
        ]
        guard let url = components.url else { return "Flickr-Adresse konnte nicht erzeugt werden." }
        do {
            let data = try await client.data(for: URLRequest(url: url), timeout: 10)
            let response = try JSONDecoder().decode(StatusResponse.self, from: data)
            return response.stat == "ok" ? "Verbindung erfolgreich – der API-Schlüssel wurde von Flickr akzeptiert."
                : "Flickr lehnt die Anfrage ab: \(response.message ?? "unbekannter API-Fehler")"
        } catch { return "Flickr ist nicht erreichbar: \(error.localizedDescription)" }
    }

    func spots(near center: GeoPoint, radius: Int, imagePixelLimit _: Int) async -> [PhotoSpotCandidate] {
        guard UserDefaults.standard.bool(forKey: "flickrDiscoveryEnabled"),
              let apiKey = FlickrAPIKeyStore.load(), !apiKey.isEmpty else { return [] }
        guard let photos = try? await searchPhotos(near: center, radius: radius, apiKey: apiKey) else { return [] }
        return photos.compactMap(Self.map)
    }

    func searchDiagnosis(near center: GeoPoint?, radius: Int) async -> String {
        guard let center else { return "Für den Suchtest fehlt ein Standort oder Karten-Suchpunkt." }
        guard let apiKey = FlickrAPIKeyStore.load(), !apiKey.isEmpty else { return "Kein API-Schlüssel gespeichert." }
        do {
            let raw = try await searchPhotos(near: center, radius: radius, apiKey: apiKey)
            let accepted = raw.compactMap(Self.map)
            return "Flickr liefert \(raw.count) georeferenzierte Fotos; \(accepted.count) bestehen den Natur-/Architekturfilter."
        } catch { return "Flickr-Suche fehlgeschlagen: \(error.localizedDescription)" }
    }

    private func searchPhotos(near center: GeoPoint, radius: Int, apiKey: String) async throws -> [Photo] {
        let batches = try await withThrowingTaskGroup(of: [Photo].self, returning: [[Photo]].self) { group in
            for tags in Self.discoveryTagGroups {
                group.addTask { try await searchBatch(near: center, radius: radius, apiKey: apiKey, tags: tags) }
            }
            var results: [[Photo]] = []
            for try await batch in group { results.append(batch) }
            return results
        }
        var unique: [String: Photo] = [:]
        for photo in batches.joined() { unique[photo.id] = photo }
        return Array(unique.values)
    }

    private func searchBatch(near center: GeoPoint, radius: Int, apiKey: String,
                             tags: [String]) async throws -> [Photo] {
        var components = URLComponents(string: "https://api.flickr.com/services/rest/")!
        components.queryItems = [
            .init(name: "method", value: "flickr.photos.search"), .init(name: "api_key", value: apiKey),
            .init(name: "format", value: "json"), .init(name: "nojsoncallback", value: "1"),
            .init(name: "lat", value: String(center.latitude)), .init(name: "lon", value: String(center.longitude)),
            .init(name: "radius", value: String(min(32, max(1, Double(radius) / 1_000)))),
            .init(name: "radius_units", value: "km"), .init(name: "has_geo", value: "1"),
            .init(name: "accuracy", value: "6"), .init(name: "safe_search", value: "1"),
            .init(name: "media", value: "photos"), .init(name: "content_types", value: "0"),
            .init(name: "sort", value: "interestingness-desc"), .init(name: "per_page", value: "60"),
            .init(name: "tags", value: tags.joined(separator: ",")),
            .init(name: "tag_mode", value: "any"),
            .init(name: "extras", value: "description,license,owner_name,geo,tags,views,url_z,url_c,url_l")
        ]
        guard let url = components.url else { throw FlickrSearchError.invalidURL }
        let data = try await client.data(for: URLRequest(url: url), timeout: 12)
        let response = try JSONDecoder().decode(Response.self, from: data)
        guard response.stat == "ok" else { throw FlickrSearchError.api(response.message ?? "Unbekannter Fehler") }
        return response.photos?.photo ?? []
    }

    private static func map(_ photo: Photo) -> PhotoSpotCandidate? {
        let title = photo.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = photo.description?.content ?? ""
        guard !title.isEmpty, let latitude = Double(photo.latitude ?? ""), let longitude = Double(photo.longitude ?? ""),
              let category = category(for: "\(title) \(photo.tags ?? "") \(description)") else { return nil }
        let candidate = PhotoSpotCandidate(
            id: "flickr:\(photo.id)", name: title, summary: description.nilIfEmpty,
            location: .init(latitude: latitude, longitude: longitude), category: category,
            source: .init(provider: "Flickr · \(photo.ownername ?? "Fotograf/in")", externalID: photo.id,
                          url: URL(string: "https://www.flickr.com/photos/\(photo.owner)/\(photo.id)")),
            imageURL: photo.urlL ?? photo.urlC ?? photo.urlZ, photoCount: min(Int(photo.views ?? "") ?? 1, 10_000),
            mentionCount: min(Int(photo.views ?? "") ?? 0, 10_000),
            notability: .soft
        )
        return PhotographicRelevancePolicy.accepts(candidate) ? candidate : nil
    }

    /// Word-boundary keyword inference shared with the Wikipedia discovery. Photos whose text
    /// carries no nature/architecture signal stay excluded; the guessed category is never curated.
    private static func category(for raw: String) -> SpotCategory? {
        CategoryInference.category(from: raw)
    }

    private static let discoveryTagGroups = [
        ["waterfall", "viewpoint", "lookout", "nationalpark", "mountain", "canyon", "cliff",
         "cave", "beach", "coast", "lake", "river", "forest", "landscape"],
        ["lighthouse", "castle", "ruins", "bridge", "cathedral", "architecture", "heritage",
         "botanicalgarden", "mural", "historicbuilding"]
    ]
    private struct StatusResponse: Decodable { let stat: String; let message: String? }
    private struct Response: Decodable { let stat: String; let photos: Photos?; let message: String? }
    private struct Photos: Decodable { let photo: [Photo] }
    private struct Description: Decodable { let content: String; enum CodingKeys: String, CodingKey { case content = "_content" } }
    private struct Photo: Decodable {
        let id, owner, title: String
        let latitude, longitude, tags, views, ownername: String?
        let description: Description?
        let urlZ, urlC, urlL: URL?
        enum CodingKeys: String, CodingKey {
            case id, owner, title, latitude, longitude, tags, views, ownername, description
            case urlZ = "url_z"; case urlC = "url_c"; case urlL = "url_l"
        }
    }
}

private enum FlickrSearchError: LocalizedError {
    case invalidURL, api(String)
    var errorDescription: String? {
        switch self {
        case .invalidURL: "Die Flickr-Suchadresse ist ungültig."
        case .api(let message): message
        }
    }
}

private extension String {
    var nilIfEmpty: String? { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self }
}
