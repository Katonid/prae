import Testing
@testable import PhotoSpotCore

struct SpotScorerTests {
    @Test func richProtectedWaterfallOutscoresGenericPlace() {
        let source = SpotSource(provider: "test", externalID: "1")
        let rich = PhotoSpotCandidate(
            id: "rich", name: "Falls", location: .init(latitude: 1, longitude: 1), category: .waterfall,
            source: source, imagePixelCount: 12_000_000, photoCount: 100, rating: 4.8,
            mentionCount: 500, hasWikipediaArticle: true, elevation: 500, isProtected: true
        )
        let plain = PhotoSpotCandidate(id: "plain", name: "Place", location: .init(latitude: 1, longitude: 1), category: .other, source: source)
        #expect(SpotScorer().score(rich) > SpotScorer().score(plain))
        #expect((0...100).contains(SpotScorer().score(rich)))
    }
}
