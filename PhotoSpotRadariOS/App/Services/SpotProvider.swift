import Foundation
import PhotoSpotCore

protocol SpotProvider: Sendable {
    func spots(near center: GeoPoint, radius: Int, imagePixelLimit: Int) async throws -> [PhotoSpotCandidate]
}

/// Combines sources by stable IDs. Additional providers can be injected without UI changes.
struct CompositeSpotProvider: SpotProvider {
    let primary: any SpotProvider
    let wikipedia: WikipediaService
    let wikimedia: WikimediaSpotService
    let flickr: FlickrService

    func spots(near center: GeoPoint, radius: Int, imagePixelLimit: Int) async throws -> [PhotoSpotCandidate] {
        async let osmResult = try? primary.spots(near: center, radius: radius, imagePixelLimit: imagePixelLimit)
        async let mediaResult = wikimedia.spots(near: center, radius: radius, imagePixelLimit: imagePixelLimit)
        async let flickrResult = flickr.spots(near: center, radius: radius, imagePixelLimit: imagePixelLimit)
        let (osm, media, flickr) = await (osmResult, mediaResult, flickrResult)
        guard osm != nil || !media.isEmpty || !flickr.isEmpty else { throw ServiceError.invalidResponse }
        var base = Self.dedupeAcrossProviders((osm ?? []) + media) + flickr
        // Local density is derived from the combined result instead of guessed by a provider.
        for index in base.indices {
            base[index].nearbySimilarCount = base.indices.filter {
                $0 != index && base[$0].category == base[index].category
                    && GeoMath.distance(from: base[$0].location, to: base[index].location) <= 10_000
            }.count
        }
        // Enrichment is capped to protect Wikipedia and conserve radio/battery usage.
        let prioritized = Array(base.filter { $0.imageURL == nil }.prefix(12))
        return await withTaskGroup(of: PhotoSpotCandidate.self, returning: [PhotoSpotCandidate].self) { group in
            for spot in prioritized {
                group.addTask { await wikipedia.enrich(spot, thumbnailWidth: imagePixelLimit) }
            }
            var enriched: [String: PhotoSpotCandidate] = [:]
            for await spot in group { enriched[spot.id] = spot }
            return base.map { enriched[$0.id] ?? $0 }.filter(PhotographicRelevancePolicy.accepts)
        }
    }

    /// The same landmark arrives from OSM, Wikipedia *and* Wikidata as three separate records
    /// (e.g. the CN Tower three times, once with a logo as its image). Collapse them into the
    /// best-documented one; Flickr photos are handled elsewhere as photo groups, not places.
    static func dedupeAcrossProviders(_ places: [PhotoSpotCandidate]) -> [PhotoSpotCandidate] {
        var kept: [PhotoSpotCandidate] = []
        for candidate in places.sorted(by: preferred) {
            if let index = kept.firstIndex(where: { sameLandmark(candidate, $0) }) {
                kept[index] = merged(kept[index], absorbing: candidate)
            } else {
                kept.append(candidate)
            }
        }
        return kept
    }

    private static func sameLandmark(_ a: PhotoSpotCandidate, _ b: PhotoSpotCandidate) -> Bool {
        guard GeoMath.distance(from: a.location, to: b.location) <= 250 else { return false }
        let nameA = normalized(a.name), nameB = normalized(b.name)
        if nameA == nameB { return true }
        // "Union Station" vs. "Toronto Union Station"; guarded by length so short generic
        // words cannot chain-merge different places.
        let (short, long) = nameA.count <= nameB.count ? (nameA, nameB) : (nameB, nameA)
        return short.count >= 8 && long.contains(short)
    }

    private static func normalized(_ name: String) -> String {
        name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Sort so that the record we keep is the best-documented one: curated category first,
    /// then stronger notability, then a real image, then the more trustworthy source. OSM tags
    /// are exact and Wikidata P18 images are curated photographs, while Wikipedia page images
    /// are frequently logos or maps — hence the provider ranking.
    private static func preferred(_ a: PhotoSpotCandidate, _ b: PhotoSpotCandidate) -> Bool {
        if a.categoryIsCurated != b.categoryIsCurated { return a.categoryIsCurated }
        if a.notability.rank != b.notability.rank { return a.notability.rank > b.notability.rank }
        if imageRank(a) != imageRank(b) { return imageRank(a) > imageRank(b) }
        return providerRank(a) < providerRank(b)
    }

    /// A real photograph beats a logo/diagram (SVG), which still beats no image at all.
    private static func imageRank(_ candidate: PhotoSpotCandidate) -> Int {
        guard let url = candidate.imageURL else { return 0 }
        let value = url.absoluteString.lowercased()
        return value.contains(".svg") || value.contains("logo") ? 1 : 2
    }

    private static func providerRank(_ candidate: PhotoSpotCandidate) -> Int {
        switch candidate.source.provider {
        case "OpenStreetMap": 0
        case "Wikidata": 1
        default: 2
        }
    }

    /// Keeps the preferred record but adopts anything the duplicate documents better.
    private static func merged(_ kept: PhotoSpotCandidate,
                               absorbing other: PhotoSpotCandidate) -> PhotoSpotCandidate {
        var result = kept
        result.summary = kept.summary ?? other.summary
        if imageRank(other) > imageRank(kept) { result.imageURL = other.imageURL }
        result.imagePixelCount = max(kept.imagePixelCount, other.imagePixelCount)
        result.hasWikipediaArticle = kept.hasWikipediaArticle || other.hasWikipediaArticle
        result.mentionCount = max(kept.mentionCount, other.mentionCount)
        result.elevation = kept.elevation ?? other.elevation
        if other.notability.rank > kept.notability.rank { result.notability = other.notability }
        return result
    }
}
