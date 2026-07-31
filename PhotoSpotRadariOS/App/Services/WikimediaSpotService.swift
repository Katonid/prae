import Foundation
import PhotoSpotCore

/// Discovers geocoded articles and photos directly instead of trying to attach a nearby
/// article to an arbitrary OpenStreetMap object after the fact.
///
/// Wikimedia Commons is intentionally *not* used as a discovery source: a geotagged Commons file
/// is just a photo, not a place, so treating every nearby photo as its own "spot" produced large
/// numbers of mislabeled, unremarkable hits. Commons is still valuable for illustrating a known
/// spot, which happens through the OSM `wikimedia_commons` tag and the Wikipedia enrichment step.
struct WikimediaSpotService: Sendable {
    private let client: HTTPClient

    init(client: HTTPClient = HTTPClient()) { self.client = client }

    func spots(near center: GeoPoint, radius: Int, imagePixelLimit: Int) async -> [PhotoSpotCandidate] {
        let safeRadius = min(radius, 10_000)
        async let german = wikipedia(language: "de", center: center, radius: safeRadius,
                                     imagePixelLimit: imagePixelLimit, limit: 30)
        async let english = wikipedia(language: "en", center: center, radius: safeRadius,
                                      imagePixelLimit: imagePixelLimit, limit: 15)
        async let wikidata = wikidata(center: center, radius: safeRadius,
                                      imagePixelLimit: imagePixelLimit, limit: 30)
        let discovered = await (german + english + wikidata)
        var unique: [String: PhotoSpotCandidate] = [:]
        for spot in discovered { unique[spot.id] = spot }
        return Array(unique.values)
    }

    private func wikidata(center: GeoPoint, radius: Int, imagePixelLimit: Int,
                          limit: Int) async -> [PhotoSpotCandidate] {
        let radiusKilometers = Double(radius) / 1_000
        // Require an image *and* several language editions (sitelinks). The sitelink count is a
        // strong, language-neutral proxy for "notable enough to be in a guidebook" and filters out
        // the many obscure Wikidata items (schools, offices, small administrative objects).
        // Administrative territorial entities and settlements (Q56061/Q486972 subclasses) are
        // excluded outright: a metropolitan region is notable and photographed, but not a spot.
        let query = """
        SELECT ?item ?itemLabel ?coord ?image ?sitelinks ?typeLabel ?distance WHERE {
          SERVICE wikibase:around {
            ?item wdt:P625 ?coord.
            bd:serviceParam wikibase:center "Point(\(center.longitude) \(center.latitude))"^^geo:wktLiteral;
              wikibase:radius "\(radiusKilometers)";
              wikibase:distance ?distance.
          }
          ?item wdt:P18 ?image.
          ?item wikibase:sitelinks ?sitelinks.
          FILTER(?sitelinks >= 3)
          FILTER NOT EXISTS { ?item wdt:P31/wdt:P279* wd:Q56061. }
          FILTER NOT EXISTS { ?item wdt:P31/wdt:P279* wd:Q486972. }
          OPTIONAL { ?item wdt:P31 ?type. }
          SERVICE wikibase:label {
            bd:serviceParam wikibase:language "de,en".
            ?item rdfs:label ?itemLabel.
            ?type rdfs:label ?typeLabel.
          }
        }
        ORDER BY DESC(?sitelinks)
        LIMIT \(limit * 3)
        """
        var components = URLComponents(string: "https://query.wikidata.org/sparql")!
        components.queryItems = [.init(name: "format", value: "json"), .init(name: "query", value: query)]
        guard let url = components.url else { return [] }
        var request = URLRequest(url: url)
        request.setValue("application/sparql-results+json", forHTTPHeaderField: "Accept")
        request.setValue("PhotoSpotRadar/1.0", forHTTPHeaderField: "Api-User-Agent")
        guard let data = try? await client.data(for: request, timeout: 9),
              let response = try? JSONDecoder().decode(WikidataResponse.self, from: data) else { return [] }
        // One result row per (item, instance-of) pair — regroup into items with their type labels.
        var typesByItem: [String: [String]] = [:]
        var rowByItem: [String: WikidataBinding] = [:]
        var order: [String] = []
        for binding in response.results.bindings {
            guard let itemURL = URL(string: binding.item.value) else { continue }
            let itemID = itemURL.lastPathComponent
            if rowByItem[itemID] == nil { rowByItem[itemID] = binding; order.append(itemID) }
            if let type = binding.typeLabel?.value, !type.isEmpty {
                typesByItem[itemID, default: []].append(type)
            }
        }
        return order.compactMap { itemID in
            guard let binding = rowByItem[itemID],
                  let point = Self.parseWikidataPoint(binding.coord.value),
                  let itemURL = URL(string: binding.item.value),
                  let imageURL = Self.wikimediaImageURL(binding.image.value, width: imagePixelLimit) else { return nil }
            let types = typesByItem[itemID] ?? []
            let category = CategoryInference.category(
                from: ([binding.itemLabel.value] + types).joined(separator: " ")
            ) ?? .other
            // The instance-of labels say precisely what an object is. When no photo category was
            // recognised and a type marks the object as a transit system, airport, organisation …
            // it is notable and photographed, yet not a photo spot. A recognised category wins,
            // so a museum is never rejected for its secondary "charitable organisation" type.
            if category == .other, types.contains(where: CategoryInference.describesNonSpotSubject) {
                return nil
            }
            let sitelinks = Int(binding.sitelinks?.value ?? "") ?? 0
            // Many editions → a well-known landmark (hard); a few → still a real article (soft).
            let notability: SpotNotability = sitelinks >= 5 ? .hard : .soft
            let candidate = PhotoSpotCandidate(
                id: "wikidata:\(itemID)", name: binding.itemLabel.value,
                summary: types.first.map { $0.prefix(1).uppercased() + $0.dropFirst() },
                location: point,
                category: category,
                source: .init(provider: "Wikidata", externalID: itemID, url: itemURL),
                imageURL: imageURL, photoCount: 1,
                mentionCount: max(sitelinks, 1), hasWikipediaArticle: true,
                notability: notability
            )
            return PhotographicRelevancePolicy.accepts(candidate) ? candidate : nil
        }
    }

    private func wikipedia(language: String, center: GeoPoint, radius: Int,
                           imagePixelLimit: Int, limit: Int) async -> [PhotoSpotCandidate] {
        var components = URLComponents(string: "https://\(language).wikipedia.org/w/api.php")!
        components.queryItems = [
            .init(name: "action", value: "query"), .init(name: "format", value: "json"),
            .init(name: "formatversion", value: "2"), .init(name: "generator", value: "geosearch"),
            .init(name: "ggscoord", value: "\(center.latitude)|\(center.longitude)"),
            .init(name: "ggsradius", value: String(radius)), .init(name: "ggslimit", value: String(limit)),
            .init(name: "prop", value: "coordinates|pageimages|description|info|langlinks"),
            .init(name: "lllimit", value: "max"),
            .init(name: "piprop", value: "thumbnail|original"),
            .init(name: "pithumbsize", value: String(min(max(imagePixelLimit, 400), 1_600))),
            .init(name: "inprop", value: "url")
        ]
        guard let url = components.url,
              let data = try? await client.data(for: URLRequest(url: url), timeout: 9),
              let response = try? JSONDecoder().decode(WikipediaResponse.self, from: data) else { return [] }
        return (response.query?.pages ?? []).compactMap { page in
            guard let coordinate = page.coordinates?.first else { return nil }
            // Wikipedia page images are frequently logos, coats of arms or maps (SVG). Those are
            // worse than no image at all, so they are dropped here.
            let image = [page.thumbnail, page.original]
                .compactMap { $0 }
                .first { Self.isPhotographic($0.source) }
            // Several language editions are the same guidebook signal as Wikidata sitelinks:
            // a local pond gets one article, a real sight gets translated.
            let languageEditions = page.langlinks?.count ?? 0
            let candidate = PhotoSpotCandidate(
                id: "wikipedia:\(language):\(page.pageid)", name: page.title,
                summary: page.description, location: .init(latitude: coordinate.lat, longitude: coordinate.lon),
                category: Self.inferredCategory(name: page.title, summary: page.description),
                source: .init(provider: "\(language.uppercased()) Wikipedia", externalID: String(page.pageid), url: page.fullurl),
                imageURL: image?.source, imagePixelCount: (image?.width ?? 0) * (image?.height ?? 0),
                photoCount: image == nil ? 0 : 1, mentionCount: 1 + languageEditions, hasWikipediaArticle: true,
                notability: languageEditions >= 4 ? .hard : .soft
            )
            return PhotographicRelevancePolicy.accepts(candidate) ? candidate : nil
        }
    }

    /// Word-boundary keyword inference shared with the other free-text sources. The result is a
    /// *guess*, so candidates built from it are never marked as curated.
    private static func inferredCategory(name: String, summary: String?) -> SpotCategory {
        CategoryInference.category(from: "\(name) \(summary ?? "")") ?? .other
    }

    private static func isPhotographic(_ url: URL?) -> Bool {
        guard let url else { return false }
        let value = url.absoluteString.lowercased()
        return !value.contains(".svg") && !value.contains("logo")
    }

    private static func parseWikidataPoint(_ value: String) -> GeoPoint? {
        guard value.hasPrefix("Point("), value.hasSuffix(")") else { return nil }
        let values = value.dropFirst(6).dropLast().split(separator: " ").compactMap { Double($0) }
        guard values.count == 2 else { return nil }
        return .init(latitude: values[1], longitude: values[0])
    }

    private static func wikimediaImageURL(_ value: String, width: Int) -> URL? {
        guard let source = URL(string: value) else { return nil }
        let filename = source.lastPathComponent.removingPercentEncoding ?? source.lastPathComponent
        var components = URLComponents()
        components.scheme = "https"
        components.host = "commons.wikimedia.org"
        components.path = "/wiki/Special:FilePath/\(filename)"
        components.queryItems = [.init(name: "width", value: String(min(max(width, 400), 1_600)))]
        return components.url
    }

    private struct Coordinate: Decodable { let lat: Double; let lon: Double }
    private struct ImageInfo: Decodable {
        let source: URL?; let url: URL?; let thumburl: URL?; let width: Int?; let height: Int?
    }
    private struct WikipediaResponse: Decodable { let query: WikipediaQuery? }
    private struct WikipediaQuery: Decodable { let pages: [WikipediaPage] }
    private struct WikipediaPage: Decodable {
        let pageid: Int; let title: String; let description: String?; let fullurl: URL?
        let coordinates: [Coordinate]?; let thumbnail: ImageInfo?; let original: ImageInfo?
        let langlinks: [Langlink]?
    }
    private struct Langlink: Decodable { let lang: String? }
    private struct WikidataResponse: Decodable { let results: WikidataResults }
    private struct WikidataResults: Decodable { let bindings: [WikidataBinding] }
    private struct WikidataValue: Decodable { let value: String }
    private struct WikidataBinding: Decodable {
        let item: WikidataValue; let itemLabel: WikidataValue
        let coord: WikidataValue; let image: WikidataValue
        let sitelinks: WikidataValue?; let distance: WikidataValue?
        let typeLabel: WikidataValue?
    }
}
