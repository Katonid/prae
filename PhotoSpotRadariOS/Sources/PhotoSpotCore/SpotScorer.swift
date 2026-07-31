import Foundation

/// All weights live here, making product tuning explicit and testable.
public struct SpotScoreWeights: Sendable {
    public var photos = 14.0
    public var imageQuality = 8.0
    public var rating = 16.0
    public var wikipedia = 10.0
    public var mentions = 8.0
    public var category = 18.0
    public var elevation = 6.0
    public var protection = 8.0
    public var uniqueness = 7.0
    public var photographerPopularity = 5.0

    public init() {}
}

public struct SpotScorer: Sendable {
    public let weights: SpotScoreWeights
    public init(weights: SpotScoreWeights = .init()) { self.weights = weights }

    public func score(_ spot: PhotoSpotCandidate) -> Int {
        let categoryFactor: Double = switch spot.category {
        case .waterfall, .canyon, .lighthouse, .castle, .peak: 1
        case .viewpoint, .coast, .cliff, .nationalPark, .ruin: 0.9
        case .lake, .beach, .mountain, .historicBuilding, .bridge: 0.75
        default: 0.55
        }
        let photoFactor = min(log10(Double(spot.photoCount) + 1) / 2, 1)
        let imageFactor = min(Double(spot.imagePixelCount) / 12_000_000, 1)
        let ratingFactor = min(max((spot.rating ?? 0) / 5, 0), 1)
        let mentionFactor = min(log10(Double(spot.mentionCount) + 1) / 3, 1)
        let elevationFactor = min(max((spot.elevation ?? 0) / 1_500, 0), 1)
        let protectionFactor = spot.isUNESCO ? 1 : (spot.isProtected ? 0.7 : 0)
        let uniquenessFactor = max(0, 1 - Double(spot.nearbySimilarCount) / 10)
        let popularityFactor = min(log10(Double(spot.photoCount + spot.mentionCount) + 1) / 4, 1)
        let result = photoFactor * weights.photos + imageFactor * weights.imageQuality
            + ratingFactor * weights.rating + (spot.hasWikipediaArticle ? weights.wikipedia : 0)
            + mentionFactor * weights.mentions + categoryFactor * weights.category
            + elevationFactor * weights.elevation + protectionFactor * weights.protection
            + uniquenessFactor * weights.uniqueness + popularityFactor * weights.photographerPopularity
        return min(100, max(0, Int(result.rounded())))
    }
}
