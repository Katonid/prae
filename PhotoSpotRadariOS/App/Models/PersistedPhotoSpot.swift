import Foundation
import SwiftData
import PhotoSpotCore

@Model
final class PersistedPhotoSpot {
    @Attribute(.unique) var id: String
    var name: String
    var summaryText: String?
    var latitude: Double
    var longitude: Double
    var categoryRaw: String
    var locality: String?
    var country: String?
    var sourceName: String
    var sourceURL: URL?
    var imageURL: URL?
    var rating: Double?
    var score: Int
    var photoCount: Int
    // Persisted with defaults so existing SwiftData stores migrate without a manual step.
    var notabilityRaw: String = SpotNotability.none.rawValue
    var categoryIsCurated: Bool = false
    var openingHours: String?
    var admission: String?
    var isFree: Bool?
    var isAccessible: Bool?
    var isFamilyFriendly: Bool?
    var isFavorite = false
    var visitedAt: Date?
    var lastNotifiedAt: Date?
    var lastUpdatedAt: Date

    init(candidate: PhotoSpotCandidate, score: Int, now: Date = .now) {
        id = candidate.id; name = candidate.name; summaryText = candidate.summary
        latitude = candidate.location.latitude; longitude = candidate.location.longitude
        categoryRaw = candidate.category.rawValue; locality = candidate.locality; country = candidate.country
        sourceName = candidate.source.provider
        sourceURL = candidate.source.url; imageURL = candidate.imageURL; rating = candidate.rating
        self.score = score; photoCount = candidate.photoCount
        notabilityRaw = candidate.notability.rawValue
        categoryIsCurated = candidate.categoryIsCurated
        openingHours = candidate.openingHours; admission = candidate.admission
        isFree = candidate.isFree; isAccessible = candidate.isAccessible
        isFamilyFriendly = candidate.isFamilyFriendly; lastUpdatedAt = now
    }

    var location: GeoPoint { .init(latitude: latitude, longitude: longitude) }
    var category: SpotCategory { SpotCategory(rawValue: categoryRaw) ?? .other }
    var notability: SpotNotability { SpotNotability(rawValue: notabilityRaw) ?? .none }
}
