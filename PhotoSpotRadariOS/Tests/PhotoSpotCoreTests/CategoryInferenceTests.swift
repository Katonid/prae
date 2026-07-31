import Testing
@testable import PhotoSpotCore

struct CategoryInferenceTests {
    // The classic false positives of substring matching: city and street names that merely
    // *contain* a keyword must not become photo categories.
    @Test func compoundNamesDoNotMatch() {
        #expect(CategoryInference.category(from: "Hamburg") == nil)
        #expect(CategoryInference.category(from: "Magdeburger Allee") == nil)
        #expect(CategoryInference.category(from: "Bergstraße 12") == nil)
        #expect(CategoryInference.category(from: "Museumsdorf") == nil)
        #expect(CategoryInference.category(from: "Sundowner at the lakeside cafe") == nil)
    }

    @Test func wholeWordsMatch() {
        #expect(CategoryInference.category(from: "Burg Eltz") == .castle)
        #expect(CategoryInference.category(from: "Wartburg, Burg in Thüringen") == .castle)
        #expect(CategoryInference.category(from: "Kakabeka Falls") == .waterfall)
        #expect(CategoryInference.category(from: "Niagara waterfall panorama") == .waterfall)
        #expect(CategoryInference.category(from: "Mount Royal Lookout") == .viewpoint)
        #expect(CategoryInference.category(from: "Lake Louise") == .lake)
        #expect(CategoryInference.category(from: "Kölner Dom") == .church)
    }

    // Diacritics and case are folded before matching.
    @Test func diacriticsAreFolded() {
        #expect(CategoryInference.category(from: "Höhle von Lascaux") == .cave)
        #expect(CategoryInference.category(from: "Steile KLIPPE an der Küste") == .cliff)
    }

    // Iconic nature keywords outrank the generic building keywords when both occur.
    @Test func iconicKeywordsWin() {
        #expect(CategoryInference.category(from: "Aussichtsturm am Wald") == .viewpoint)
    }

    // Cities, districts and metro regions are notable and photographed — but not photo spots.
    @Test func settlementsAreDetected() {
        #expect(CategoryInference.describesNonSpotSubject("Greater Toronto Area metropolitan area in Ontario"))
        #expect(CategoryInference.describesNonSpotSubject("Bochum Stadt in Nordrhein-Westfalen"))
        #expect(CategoryInference.describesNonSpotSubject("Kreuzberg Stadtteil von Berlin"))
        #expect(!CategoryInference.describesNonSpotSubject("Tiger & Turtle begehbare Skulptur"))
        #expect(!CategoryInference.describesNonSpotSubject("Himmelsleiter auf der Halde Rheinelbe"))
    }

    // Stadiums, universities, airports and broadcasters are famous but not photo subjects —
    // including German compound class names.
    @Test func infrastructureIsDetected() {
        #expect(CategoryInference.describesNonSpotSubject("Rogers Centre Baseballstadion Mehrzweckstadion"))
        #expect(CategoryInference.describesNonSpotSubject("Staatliche Forschungsuniversität"))
        #expect(CategoryInference.describesNonSpotSubject("Billy Bishop Toronto City Airport Flughafen"))
        #expect(CategoryInference.describesNonSpotSubject("CBC Television kanadischer Fernsehsender"))
        #expect(CategoryInference.describesNonSpotSubject("Metro Toronto Convention Centre convention centre"))
        #expect(!CategoryInference.describesNonSpotSubject("Schiefer Turm von Pisa"))
    }
}
