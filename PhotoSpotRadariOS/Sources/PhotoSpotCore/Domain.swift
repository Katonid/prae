import Foundation

/// Framework-neutral coordinate used by the testable core.
public struct GeoPoint: Codable, Hashable, Sendable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

public enum SpotCategory: String, Codable, CaseIterable, Sendable {
    case viewpoint, waterfall, lake, river, beach, coast, cliff, canyon
    case nationalPark, mountain, peak, forest, historicBuilding, castle, ruin
    case bridge, church, lighthouse, oldTown, streetArt, botanicalGarden
    case cave, harbour, pier, windmill, viaduct, museum, other

    public var notificationTitle: String {
        switch self {
        case .waterfall: "📷 Wasserfall voraus"
        case .viewpoint, .peak, .mountain: "📷 Aussichtspunkt voraus"
        default: "📷 Fotospot voraus"
        }
    }
}

/// How strongly external, curated sources vouch for a place being a real, guidebook-worthy sight.
/// `hard` means a strong signal (Wikidata/Wikipedia link in OSM, a heritage/UNESCO listing, or a
/// Wikidata item with several language editions). `soft` means a weaker but real signal such as a
/// single Wikipedia article or a highly rated photo. `none` means the object only carries a name.
public enum SpotNotability: String, Codable, Sendable {
    case none, soft, hard

    public var rank: Int {
        switch self { case .none: 0; case .soft: 1; case .hard: 2 }
    }
}

public struct SpotSource: Codable, Hashable, Sendable {
    public let provider: String
    public let externalID: String
    public let url: URL?

    public init(provider: String, externalID: String, url: URL? = nil) {
        self.provider = provider
        self.externalID = externalID
        self.url = url
    }
}

/// Normalized record exchanged between providers, scoring and persistence.
public struct PhotoSpotCandidate: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var summary: String?
    public var location: GeoPoint
    public var category: SpotCategory
    /// `true` when the category comes from an exact, human-maintained tag (OSM); `false` when it
    /// was guessed from free text and should therefore carry less weight in relevance decisions.
    public var categoryIsCurated: Bool
    public var locality: String?
    public var country: String?
    public var source: SpotSource
    public var imageURL: URL?
    public var imagePixelCount: Int
    public var photoCount: Int
    public var rating: Double?
    public var mentionCount: Int
    public var hasWikipediaArticle: Bool
    public var elevation: Double?
    public var isProtected: Bool
    public var isUNESCO: Bool
    public var nearbySimilarCount: Int
    public var openingHours: String?
    public var admission: String?
    public var isFree: Bool?
    public var isAccessible: Bool?
    public var isFamilyFriendly: Bool?
    public var notability: SpotNotability

    public init(
        id: String, name: String, summary: String? = nil, location: GeoPoint,
        category: SpotCategory, categoryIsCurated: Bool = false,
        locality: String? = nil, country: String? = nil,
        source: SpotSource, imageURL: URL? = nil,
        imagePixelCount: Int = 0, photoCount: Int = 0, rating: Double? = nil,
        mentionCount: Int = 0, hasWikipediaArticle: Bool = false,
        elevation: Double? = nil, isProtected: Bool = false, isUNESCO: Bool = false,
        nearbySimilarCount: Int = 0, openingHours: String? = nil,
        admission: String? = nil, isFree: Bool? = nil,
        isAccessible: Bool? = nil, isFamilyFriendly: Bool? = nil,
        notability: SpotNotability = .none
    ) {
        self.id = id; self.name = name; self.summary = summary; self.location = location
        self.category = category; self.categoryIsCurated = categoryIsCurated
        self.locality = locality; self.country = country
        self.source = source; self.imageURL = imageURL
        self.imagePixelCount = imagePixelCount; self.photoCount = photoCount
        self.rating = rating; self.mentionCount = mentionCount
        self.hasWikipediaArticle = hasWikipediaArticle; self.elevation = elevation
        self.isProtected = isProtected; self.isUNESCO = isUNESCO
        self.nearbySimilarCount = nearbySimilarCount; self.openingHours = openingHours
        self.admission = admission; self.isFree = isFree
        self.isAccessible = isAccessible; self.isFamilyFriendly = isFamilyFriendly
        self.notability = notability
    }
}

public enum GeoMath {
    private static let earthRadius = 6_371_000.0

    public static func distance(from a: GeoPoint, to b: GeoPoint) -> Double {
        let phi1 = a.latitude * .pi / 180, phi2 = b.latitude * .pi / 180
        let deltaPhi = (b.latitude - a.latitude) * .pi / 180
        let deltaLambda = (b.longitude - a.longitude) * .pi / 180
        let h = sin(deltaPhi / 2) * sin(deltaPhi / 2)
            + cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2)
        return earthRadius * 2 * atan2(sqrt(h), sqrt(1 - h))
    }

    public static func bearing(from a: GeoPoint, to b: GeoPoint) -> Double {
        let phi1 = a.latitude * .pi / 180, phi2 = b.latitude * .pi / 180
        let lambda = (b.longitude - a.longitude) * .pi / 180
        let y = sin(lambda) * cos(phi2)
        let x = cos(phi1) * sin(phi2) - sin(phi1) * cos(phi2) * cos(lambda)
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    public static func angularDifference(_ a: Double, _ b: Double) -> Double {
        abs((a - b + 540).truncatingRemainder(dividingBy: 360) - 180)
    }
}
