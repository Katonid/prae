import Testing
import PhotoSpotCore
@testable import PhotoSpotRadar

@MainActor
struct PersistenceTests {
    @Test func mergePreservesFavoriteState() throws {
        let store = try PersistenceManager(inMemory: true)
        let source = SpotSource(provider: "Test", externalID: "42")
        var candidate = PhotoSpotCandidate(id: "spot", name: "Old", location: .init(latitude: 1, longitude: 2), category: .viewpoint, source: source)
        try store.merge([candidate], scorer: .init())
        let spot = try #require(store.allSpots().first)
        spot.isFavorite = true
        candidate.name = "New"
        try store.merge([candidate], scorer: .init())
        #expect(try store.allSpots().first?.name == "New")
        #expect(try store.allSpots().first?.isFavorite == true)
    }

    @Test func photographicPolicyRejectsStolpersteineAndUntypedEntries() {
        let source = SpotSource(provider: "Test", externalID: "1")
        let stolperstein = PhotoSpotCandidate(
            id: "stone", name: "Stolperstein für Max Mustermann",
            location: .init(latitude: 1, longitude: 2), category: .streetArt, source: source
        )
        let untyped = PhotoSpotCandidate(
            id: "other", name: "Beliebiger Lexikoneintrag",
            location: .init(latitude: 1, longitude: 2), category: .other, source: source
        )
        let waterfall = PhotoSpotCandidate(
            id: "falls", name: "Wasserfall",
            location: .init(latitude: 1, longitude: 2), category: .waterfall, source: source
        )

        #expect(!PhotographicRelevancePolicy.accepts(stolperstein))
        #expect(!PhotographicRelevancePolicy.accepts(untyped))
        #expect(PhotographicRelevancePolicy.accepts(waterfall))
    }
}
