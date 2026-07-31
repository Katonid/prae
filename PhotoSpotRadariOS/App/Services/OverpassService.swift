import Foundation
import PhotoSpotCore

struct OverpassService: SpotProvider {
    private let client: HTTPClient
    private let endpoints = [
        URL(string: "https://maps.mail.ru/osm/tools/overpass/api/interpreter")!,
        URL(string: "https://overpass.private.coffee/api/interpreter")!,
        URL(string: "https://overpass-api.de/api/interpreter")!
    ]

    init(client: HTTPClient = HTTPClient()) { self.client = client }

    func spots(near center: GeoPoint, radius: Int, imagePixelLimit _: Int) async throws -> [PhotoSpotCandidate] {
        // Public Overpass instances become unreliable for broad nwr searches. Larger product
        // radii still affect local filtering and notifications, while each network query stays bounded.
        let safeRadius = min(radius, 20_000)
        // Narrow, photo-relevant tags only. Broad collectors (tourism=attraction), generic city
        // parks/gardens/marinas, plain woods and unnamed lakes/rivers are deliberately omitted:
        // they are the main source of unremarkable hits. Notable water bodies and mountains are
        // still discovered through Wikipedia/Wikidata.
        let queryBodies = [
            """
          nwr(around:\(safeRadius),\(center.latitude),\(center.longitude))[name][tourism~"^(viewpoint|museum)$"];
          nwr(around:\(safeRadius),\(center.latitude),\(center.longitude))[name][tourism="artwork"][artwork_type~"^(mural|sculpture|statue|installation)$"];
          nwr(around:\(safeRadius),\(center.latitude),\(center.longitude))[name][historic~"^(castle|ruins|building|monument|memorial|city_gate|tower)$"];
          nwr(around:\(safeRadius),\(center.latitude),\(center.longitude))[name][man_made~"^(lighthouse|pier|bridge|tower|obelisk)$"];
          """,
            """
          nwr(around:\(safeRadius),\(center.latitude),\(center.longitude))[name][natural~"^(waterfall|peak|volcano|beach|cliff|cave_entrance|arch|glacier)$"];
          nwr(around:\(safeRadius),\(center.latitude),\(center.longitude))[name][waterway="waterfall"];
          nwr(around:\(safeRadius),\(center.latitude),\(center.longitude))[name][leisure="nature_reserve"];
          nwr(around:\(safeRadius),\(center.latitude),\(center.longitude))[name][boundary="national_park"];
          """,
            """
          nwr(around:\(safeRadius),\(center.latitude),\(center.longitude))[name][amenity="place_of_worship"][heritage];
          nwr(around:\(safeRadius),\(center.latitude),\(center.longitude))[name][tourism="attraction"][wikidata];
          """
        ]
        let queries = queryBodies.map {
            "[out:json][timeout:20];(\($0));out center tags 200;"
        }
        let batches = await withTaskGroup(of: [Element]?.self, returning: [[Element]].self) { group in
            for query in queries {
                group.addTask { try? await fetchElements(query: query) }
            }
            var successful: [[Element]] = []
            for await elements in group {
                if let elements { successful.append(elements) }
            }
            return successful
        }
        guard !batches.isEmpty else { throw ServiceError.invalidResponse }
        var unique: [String: Element] = [:]
        for element in batches.joined() {
            unique["\(element.type):\(element.id)"] = element
        }
        return unique.values.compactMap(Self.map)
    }

    private func fetchElements(query: String) async throws -> [Element] {
        var lastError: Error = ServiceError.invalidResponse
        for endpoint in endpoints {
            do {
                let data = try await client.data(for: Self.request(endpoint: endpoint, query: query), timeout: 25)
                let response = try JSONDecoder().decode(Response.self, from: data)
                return response.elements
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    private static func request(endpoint: URL, query: String) -> URLRequest {
        var components = URLComponents()
        components.queryItems = [.init(name: "data", value: query)]
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        return request
    }

    private static func map(_ element: Element) -> PhotoSpotCandidate? {
        guard let name = element.tags?["name"],
              let latitude = element.lat ?? element.center?.lat,
              let longitude = element.lon ?? element.center?.lon else { return nil }
        let tags = element.tags ?? [:]
        let category = category(for: tags)
        let notability = notability(for: tags)
        let image = imageURL(from: tags)
        guard PhotographicRelevancePolicy.accepts(.init(
            id: "check", name: name, summary: tags["description"],
            location: .init(latitude: latitude, longitude: longitude), category: category,
            source: .init(provider: "OpenStreetMap", externalID: String(element.id)),
            imageURL: image, hasWikipediaArticle: tags["wikipedia"] != nil,
            notability: notability
        )) else { return nil }
        let sourceURL = URL(string: "https://www.openstreetmap.org/\(element.type)/\(element.id)")
        return .init(
            id: "osm:\(element.type):\(element.id)", name: name,
            summary: tags["description"], location: .init(latitude: latitude, longitude: longitude),
            // OSM categories come from exact, human-maintained tags — a viewpoint really is one.
            category: category, categoryIsCurated: true,
            locality: tags["addr:city"] ?? tags["is_in:city"] ?? tags["is_in"],
            country: tags["addr:country"] ?? tags["is_in:country"],
            source: .init(provider: "OpenStreetMap", externalID: String(element.id), url: sourceURL),
            imageURL: image,
            hasWikipediaArticle: tags["wikipedia"] != nil,
            elevation: tags["ele"].flatMap(Double.init),
            isProtected: tags["boundary"] == "protected_area" || tags["leisure"] == "nature_reserve"
                || tags["boundary"] == "national_park",
            isUNESCO: tags["heritage:operator"]?.lowercased().contains("unesco") == true,
            openingHours: tags["opening_hours"], admission: tags["fee"],
            isFree: tags["fee"].map { ["no", "0"].contains($0.lowercased()) },
            isAccessible: tags["wheelchair"].map { $0 == "yes" },
            isFamilyFriendly: tags["family_friendly"].map { $0 == "yes" },
            notability: notability
        )
    }

    /// OSM cross-references to Wikidata/Wikipedia or an official heritage listing are strong,
    /// curated signals that an object is a genuine, guidebook-worthy sight.
    private static func notability(for tags: [String: String]) -> SpotNotability {
        if tags["heritage"] != nil || tags["heritage:operator"] != nil { return .hard }
        if tags["wikidata"] != nil || tags["wikipedia"] != nil || tags["wikimedia_commons"] != nil { return .hard }
        return .none
    }

    /// Photos maintained directly on the OSM object belong to the place by definition, so they are
    /// preferred over any later best-effort image lookup.
    private static func imageURL(from tags: [String: String]) -> URL? {
        if let direct = tags["image"], let url = URL(string: direct),
           url.scheme == "http" || url.scheme == "https" { return url }
        if let commons = tags["wikimedia_commons"], commons.hasPrefix("File:") {
            let file = commons.dropFirst("File:".count)
            let encoded = file.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String(file)
            return URL(string: "https://commons.wikimedia.org/wiki/Special:FilePath/\(encoded)?width=1024")
        }
        return nil
    }

    private static func category(for tags: [String: String]) -> SpotCategory {
        let value = [tags["tourism"], tags["natural"], tags["historic"], tags["man_made"], tags["leisure"], tags["water"], tags["waterway"], tags["amenity"], tags["artwork_type"], tags["boundary"]]
            .compactMap { $0 }.joined(separator: " ")
        if value.contains("viewpoint") { return .viewpoint }
        if value.contains("waterfall") { return .waterfall }
        if value.contains("peak") || value.contains("volcano") { return .peak }
        if value.contains("beach") { return .beach }
        if value.contains("cliff") || value.contains("arch") { return .cliff }
        if value.contains("cave") { return .cave }
        if value.contains("glacier") { return .mountain }
        if value.contains("castle") { return .castle }
        if value.contains("ruin") { return .ruin }
        if value.contains("bridge") { return .bridge }
        if value.contains("lighthouse") { return .lighthouse }
        if value.contains("museum") { return .museum }
        if value.contains("artwork") || value.contains("mural") || value.contains("statue")
            || value.contains("sculpture") || value.contains("installation") { return .streetArt }
        if value.contains("monument") || value.contains("memorial") || value.contains("obelisk")
            || value.contains("tower") || value.contains("city_gate") || value.contains("building") { return .historicBuilding }
        if value.contains("lake") { return .lake }
        if value.contains("river") { return .river }
        if value.contains("place_of_worship") { return .church }
        if value.contains("garden") { return .botanicalGarden }
        if value.contains("wood") { return .forest }
        if value.contains("marina") { return .harbour }
        if value.contains("pier") { return .pier }
        if value.contains("nature_reserve") || value.contains("national_park") || value.contains("park") { return .nationalPark }
        return .other
    }

    private struct Response: Decodable { let elements: [Element] }
    private struct Element: Decodable {
        let type: String; let id: Int64; let lat: Double?; let lon: Double?
        let center: Center?; let tags: [String: String]?
    }
    private struct Center: Decodable { let lat: Double; let lon: Double }
}
