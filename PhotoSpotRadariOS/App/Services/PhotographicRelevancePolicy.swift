import Foundation
import PhotoSpotCore

/// Separates places that are historically notable from places that are useful photo subjects.
///
/// This is the *ingestion* gate that keeps obvious non-subjects (memorial plaques, stumbling
/// stones, information boards) out of the store entirely. The finer, user-adjustable "how
/// interesting" decision lives in `SpotRelevance` and is applied when results are shown.
enum PhotographicRelevancePolicy {
    private static let excludedTerms = [
        "stolperstein", "stolperschwelle", "stumbling stone", "memorial plaque",
        "gedenkplakette", "gedenktafel", "informationstafel"
    ]

    static func accepts(_ spot: PhotoSpotCandidate) -> Bool {
        guard acceptsText(name: spot.name, summary: spot.summary) else { return false }
        if spot.category != .other { return true }
        // Cities, districts and whole regions are notable and photographed, but not photo spots.
        guard !CategoryInference.describesNonSpotSubject("\(spot.name) \(spot.summary ?? "")") else { return false }
        // An uncategorised object is only kept when a strong source vouches for it and it has a photo,
        // e.g. an iconic sculpture referenced by Wikipedia/Wikidata.
        return (spot.hasWikipediaArticle || spot.notability == .hard) && spot.imageURL != nil
    }

    static func accepts(_ spot: PersistedPhotoSpot) -> Bool {
        guard acceptsText(name: spot.name, summary: spot.summaryText) else { return false }
        if spot.category != .other { return true }
        guard !CategoryInference.describesNonSpotSubject("\(spot.name) \(spot.summaryText ?? "")") else { return false }
        return (spot.sourceName.localizedCaseInsensitiveContains("Wikipedia") || spot.notability == .hard)
            && spot.imageURL != nil
    }

    private static func acceptsText(name: String, summary: String?) -> Bool {
        let text = "\(name) \(summary ?? "")".folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        return !excludedTerms.contains(where: text.contains)
    }
}
