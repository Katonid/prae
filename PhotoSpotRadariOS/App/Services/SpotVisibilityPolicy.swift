import Foundation
import PhotoSpotCore

/// Applies the user's relevance level to the persisted store — the single place where list and
/// notifications agree on what counts as a visible spot.
///
/// Flickr photos are treated as *companions* of real highlights, not as spots in their own right:
/// their location and subject come from free-text photo metadata and are too fuzzy to prove a
/// place is worth visiting. At the strictest level a Flickr photo is therefore only shown when a
/// genuine highlight lies within the list-grouping distance, where it appears inside that place's
/// photo group. The dedicated "Flickr only" switch and the looser levels keep every Flickr hit.
enum SpotVisibilityPolicy {
    /// Matches the grouping distance used by the list and the notification deduplication.
    static let flickrCompanionRadius = 250.0

    static func visibleSpots(_ spots: [PersistedPhotoSpot],
                             level: SpotRelevanceLevel,
                             flickrOnly: Bool) -> [PersistedPhotoSpot] {
        let eligible = spots.filter(PhotographicRelevancePolicy.accepts)
        if flickrOnly { return eligible.filter(isFlickr) }
        let highlights = eligible.filter { !isFlickr($0) && isInteresting($0, level: level) }
        guard level == .highlightsOnly else {
            return eligible.filter { isFlickr($0) || isInteresting($0, level: level) }
        }
        return eligible.filter { spot in
            guard isFlickr(spot) else { return isInteresting(spot, level: level) }
            return highlights.contains {
                GeoMath.distance(from: $0.location, to: spot.location) <= flickrCompanionRadius
            }
        }
    }

    private static func isFlickr(_ spot: PersistedPhotoSpot) -> Bool {
        spot.sourceName.hasPrefix("Flickr")
    }

    private static func isInteresting(_ spot: PersistedPhotoSpot, level: SpotRelevanceLevel) -> Bool {
        SpotRelevance.isInteresting(category: spot.category, notability: spot.notability,
                                    hasImage: spot.imageURL != nil,
                                    curatedCategory: spot.categoryIsCurated, level: level)
    }
}
