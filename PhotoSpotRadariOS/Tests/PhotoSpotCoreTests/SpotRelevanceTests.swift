import Testing
@testable import PhotoSpotCore

struct SpotRelevanceTests {
    // Panoramas and natural spectacles are the top priority: a curated OSM tag
    // (tourism=viewpoint, waterway=waterfall, …) passes even without extra notability.
    @Test func curatedIconicNatureAlwaysPassesAtHighlights() {
        #expect(SpotRelevance.isInteresting(category: .viewpoint, notability: .none, hasImage: false, curatedCategory: true, level: .highlightsOnly))
        #expect(SpotRelevance.isInteresting(category: .waterfall, notability: .none, hasImage: false, curatedCategory: true, level: .highlightsOnly))
        #expect(SpotRelevance.isInteresting(category: .canyon, notability: .none, hasImage: false, curatedCategory: true, level: .highlightsOnly))
        #expect(SpotRelevance.isInteresting(category: .lighthouse, notability: .none, hasImage: false, curatedCategory: true, level: .highlightsOnly))
    }

    // A category *guessed* from free text (article title, photo caption) is no proof: "Hamburg"
    // keyword-matching to a castle must not surface as a highlight. Only hard external
    // notability (a well-known landmark such as the CN Tower) redeems a guessed category.
    @Test func guessedCategoryNeedsHardNotabilityAtHighlights() {
        #expect(!SpotRelevance.isInteresting(category: .castle, notability: .none, hasImage: true, curatedCategory: false, level: .highlightsOnly))
        #expect(!SpotRelevance.isInteresting(category: .castle, notability: .soft, hasImage: true, curatedCategory: false, level: .highlightsOnly))
        #expect(SpotRelevance.isInteresting(category: .viewpoint, notability: .hard, hasImage: true, curatedCategory: false, level: .highlightsOnly))
        // At "balanced" a real article (soft) is enough again.
        #expect(SpotRelevance.isInteresting(category: .castle, notability: .soft, hasImage: true, curatedCategory: false, level: .balanced))
    }

    // Generic categories (a village church, a small bridge, a local museum, a pond) only pass when
    // a strong external source vouches for them — curated tag or not.
    @Test func commonCategoryNeedsHardNotabilityAtHighlights() {
        #expect(!SpotRelevance.isInteresting(category: .church, notability: .none, hasImage: true, curatedCategory: true, level: .highlightsOnly))
        #expect(!SpotRelevance.isInteresting(category: .church, notability: .soft, hasImage: true, curatedCategory: true, level: .highlightsOnly))
        #expect(SpotRelevance.isInteresting(category: .church, notability: .hard, hasImage: true, curatedCategory: true, level: .highlightsOnly))
        // A soft signal (single Wikipedia article) is enough once the user relaxes to "balanced".
        #expect(SpotRelevance.isInteresting(category: .church, notability: .soft, hasImage: true, curatedCategory: true, level: .balanced))
    }

    // Scenic-but-common nature needs some notability at the strict level, but not at balanced.
    @Test func scenicNeedsNotabilityAtHighlightsButNotBalanced() {
        #expect(!SpotRelevance.isInteresting(category: .mountain, notability: .none, hasImage: true, curatedCategory: true, level: .highlightsOnly))
        #expect(SpotRelevance.isInteresting(category: .mountain, notability: .soft, hasImage: true, curatedCategory: true, level: .highlightsOnly))
        // A guessed "mountain" (any "…berg" text) needs the hard signal instead.
        #expect(!SpotRelevance.isInteresting(category: .mountain, notability: .soft, hasImage: true, curatedCategory: false, level: .highlightsOnly))
        #expect(SpotRelevance.isInteresting(category: .beach, notability: .none, hasImage: true, curatedCategory: true, level: .balanced))
    }

    // An iconic man-made landmark that the app cannot categorise (e.g. the "Tiger & Turtle" walkable
    // sculpture) still shows up when a strong source (many Wikidata language editions) vouches for it.
    @Test func uncategorisedButStronglyNotableLandmarkPasses() {
        #expect(SpotRelevance.isInteresting(category: .other, notability: .hard, hasImage: true, curatedCategory: false, level: .highlightsOnly))
        #expect(!SpotRelevance.isInteresting(category: .other, notability: .soft, hasImage: true, curatedCategory: false, level: .highlightsOnly))
        #expect(!SpotRelevance.isInteresting(category: .other, notability: .hard, hasImage: false, curatedCategory: false, level: .highlightsOnly))
    }

    @Test func everythingKeepsAll() {
        #expect(SpotRelevance.isInteresting(category: .other, notability: .none, hasImage: false, curatedCategory: false, level: .everything))
        #expect(SpotRelevance.isInteresting(category: .river, notability: .none, hasImage: false, curatedCategory: false, level: .everything))
    }
}
