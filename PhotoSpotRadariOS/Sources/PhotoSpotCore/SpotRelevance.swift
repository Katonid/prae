import Foundation

/// How strict the discovery results should be. This is the single most effective control the
/// product has over "too many unimportant hits": precision comes from *choosing* what to show,
/// not from re-sorting everything by a fuzzy score.
public enum SpotRelevanceLevel: String, Codable, CaseIterable, Sendable {
    /// Only genuine highlights: panoramas, natural spectacles and places a guidebook would list.
    case highlightsOnly
    /// Highlights plus other pretty, clearly-named nature and architecture destinations.
    case balanced
    /// No relevance filter at all — every discovered place (previous behaviour).
    case everything
}

/// Photographic desirability of a category, independent of the individual object.
public enum ScenicTier: Sendable {
    /// Postcard categories that are worth a photo essentially whenever they carry a name.
    case iconic
    /// Attractive, but common enough that a bare name is not proof of a worthwhile spot.
    case scenic
    /// Categories with thousands of unremarkable instances; only notable ones are interesting.
    case common
    /// Not a photo subject on its own.
    case none
}

/// Decides whether a normalized spot is "really interesting / exceptional" for the user:
/// panoramas, natural spectacles, beautiful nature and guidebook landmarks — while dropping the
/// generic churches, small bridges, ponds, local museums and unnamed clutter.
///
/// The decision uses only the category (what kind of place it is) and its notability (how strongly
/// curated sources vouch for it). This keeps it pure and unit-testable.
public enum SpotRelevance {
    public static func scenicTier(for category: SpotCategory) -> ScenicTier {
        switch category {
        case .viewpoint, .waterfall, .canyon, .peak, .cliff, .coast, .cave, .nationalPark, .castle, .lighthouse:
            return .iconic
        case .mountain, .beach, .ruin, .oldTown, .windmill, .viaduct, .streetArt, .botanicalGarden, .harbour, .pier:
            return .scenic
        case .lake, .river, .forest, .church, .historicBuilding, .bridge, .museum:
            return .common
        case .other:
            return .none
        }
    }

    /// Returns `true` when the spot should be shown at the given strictness.
    ///
    /// `curatedCategory` distinguishes categories read from exact, human-maintained tags (an OSM
    /// `tourism=viewpoint` really is a viewpoint) from categories *guessed* out of free text
    /// (a keyword match on an article title or photo caption). A guessed "castle" is far more
    /// often a mislabeled town or street than a real castle, so guessed categories never grant a
    /// free pass at the strict level — they additionally need hard external notability.
    public static func isInteresting(category: SpotCategory,
                                     notability: SpotNotability,
                                     hasImage: Bool,
                                     curatedCategory: Bool,
                                     level: SpotRelevanceLevel) -> Bool {
        switch level {
        case .everything:
            return true
        case .balanced:
            switch scenicTier(for: category) {
            case .iconic, .scenic: return curatedCategory || notability != .none
            case .common: return notability != .none
            case .none: return notability == .hard && hasImage
            }
        case .highlightsOnly:
            switch scenicTier(for: category) {
            case .iconic: return curatedCategory || notability == .hard
            case .scenic: return curatedCategory ? notability != .none : notability == .hard
            case .common: return notability == .hard
            case .none: return notability == .hard && hasImage
            }
        }
    }
}
