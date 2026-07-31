import Foundation
import SwiftData
import PhotoSpotCore

@MainActor
final class PersistenceManager {
    let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    init(inMemory: Bool = false) throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        container = try ModelContainer(for: PersistedPhotoSpot.self, configurations: configuration)
    }

    func allSpots() throws -> [PersistedPhotoSpot] {
        try context.fetch(FetchDescriptor(sortBy: [SortDescriptor(\.name)]))
    }

    func merge(_ candidates: [PhotoSpotCandidate], scorer: SpotScorer, now: Date = .now) throws {
        let existing = try allSpots().reduce(into: [String: PersistedPhotoSpot]()) { $0[$1.id] = $1 }
        for candidate in candidates {
            let score = scorer.score(candidate)
            if let spot = existing[candidate.id] {
                // Preserve user state while refreshing provider-owned fields.
                spot.name = candidate.name; spot.summaryText = candidate.summary
                spot.locality = candidate.locality; spot.country = candidate.country
                spot.imageURL = candidate.imageURL; spot.rating = candidate.rating
                spot.notabilityRaw = candidate.notability.rawValue
                spot.categoryRaw = candidate.category.rawValue
                spot.categoryIsCurated = candidate.categoryIsCurated
                spot.score = score; spot.lastUpdatedAt = now
            } else { context.insert(PersistedPhotoSpot(candidate: candidate, score: score, now: now)) }
        }
        try context.save()
    }

    /// A new search *replaces* the results in the searched area instead of accumulating forever:
    /// spots the providers no longer confirm are removed. User-owned places (favorites and
    /// visited spots) always survive.
    func pruneStale(around center: GeoPoint, radius: Int, confirmedIDs: Set<String>) throws {
        for spot in try allSpots() {
            guard !confirmedIDs.contains(spot.id),
                  !spot.isFavorite, spot.visitedAt == nil,
                  GeoMath.distance(from: center, to: spot.location) <= Double(radius) else { continue }
            context.delete(spot)
        }
        try context.save()
    }

    /// Clears every stored search result the user has not marked as favorite or visited.
    func removeAllSearchResults() throws {
        for spot in try allSpots() where !spot.isFavorite && spot.visitedAt == nil {
            context.delete(spot)
        }
        try context.save()
    }

    func save() throws { try context.save() }
}
