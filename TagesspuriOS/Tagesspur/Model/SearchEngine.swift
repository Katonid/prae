import Foundation
import SwiftData

/// Deterministische Suche über Aufenthalte und (optionale) Foto-Stichwörter.
/// Kein LLM: Stoppwörter raus, Synonyme aufklappen, Textfelder, Gewässer-
/// Attribute und Vision-Begriffe abgleichen — nachvollziehbar und offline.
///
/// Ein Tag trifft, wenn **jedes** Suchwort belegt ist — entweder durch
/// einen Aufenthaltsort oder durch die Fotoanalyse („Picknick am See“:
/// „See“ vom Ort, „Picknick“ vom Foto).
enum SearchEngine {

    struct PhotoMatch: Identifiable {
        var token: String
        var count: Int
        var id: String { token }
    }

    struct DayResult: Identifiable {
        var dayKey: String
        var visits: [PlaceVisit]
        var photoMatches: [PhotoMatch]
        var id: String { dayKey }
    }

    private static let stopwords: Set<String> = [
        "zeige", "zeig", "mir", "die", "der", "das", "den", "dem", "des",
        "tage", "tagen", "tag", "orte", "ort", "an", "denen", "ich",
        "einem", "einer", "eine", "ein", "war", "waren", "bin", "gewesen",
        "bei", "wo", "am", "im", "in", "auf", "mit", "nach", "und", "oder",
        "alle", "welche", "welchen", "habe", "hab", "mal", "wann", "als",
        "gemacht", "hatte", "hatten", "es", "gab"
    ]

    /// Synonymgruppen für Orte: Trefferbedingung ist ein Placemark-Attribut
    /// (Binnengewässer/Meer) oder ein Textstichwort.
    private static let waterInland = ["see", "badesee", "weiher", "teich", "stausee", "fluss", "bach", "kanal", "gewässer", "wasser"]
    private static let waterOcean = ["meer", "ozean", "strand", "küste", "kueste", "nordsee", "ostsee"]

    /// Deutsche Suchwörter → englische Vision-Begriffe der Fotoanalyse.
    /// Bewusst kuratiert und erweiterbar — keine Blackbox.
    static let photoSynonyms: [String: [String]] = [
        "picknick": ["picnic"],
        "see": ["lake"],
        "meer": ["sea", "ocean"],
        "strand": ["beach", "seashore", "coast"],
        "berg": ["mountain", "summit"],
        "berge": ["mountain", "summit"],
        "wald": ["forest", "woodland"],
        "hund": ["dog"],
        "katze": ["cat"],
        "pferd": ["horse"],
        "fahrrad": ["bicycle", "bike", "cycling"],
        "boot": ["boat", "sailboat"],
        "schnee": ["snow", "ski"],
        "sonnenuntergang": ["sunset"],
        "lagerfeuer": ["campfire", "bonfire"],
        "feuer": ["fire", "campfire"],
        "essen": ["food", "meal", "dish"],
        "cafe": ["cafe", "coffee"],
        "café": ["cafe", "coffee"],
        "restaurant": ["restaurant"],
        "wandern": ["hiking", "trail"],
        "wanderung": ["hiking", "trail"],
        "spielplatz": ["playground"],
        "zoo": ["zoo"],
        "museum": ["museum"],
        "konzert": ["concert", "stage", "music"],
        "fußball": ["soccer", "football"],
        "schwimmen": ["swimming", "pool"],
        "pool": ["pool"],
        "garten": ["garden"],
        "blumen": ["flower"],
        "blume": ["flower"],
        "regen": ["rain"],
        "auto": ["car"],
        "zug": ["train", "railway"],
        "flugzeug": ["airplane", "aircraft"],
        "brücke": ["bridge"],
        "burg": ["castle"],
        "schloss": ["castle", "palace"],
        "kirche": ["church", "cathedral"],
        "markt": ["market"],
        "grillen": ["barbecue", "grill"],
        "camping": ["camping", "tent"],
        "zelt": ["tent"],
        "baby": ["baby"],
        "geburtstag": ["birthday", "cake"],
        "kuchen": ["cake"],
        "eis": ["ice cream"],
    ]

    static func search(query: String, visits: [PlaceVisit], tags: [MediaTag]) -> [DayResult] {
        let tokens = tokenize(query)
        guard !tokens.isEmpty else { return [] }

        let visitsByDay = Dictionary(grouping: visits, by: \.dayKey)
        let tagsByDay = Dictionary(grouping: tags, by: \.dayKey)
        let allDays = Set(visitsByDay.keys).union(tagsByDay.keys)

        var results: [DayResult] = []
        for dayKey in allDays {
            let dayVisits = visitsByDay[dayKey] ?? []
            let dayTags = tagsByDay[dayKey] ?? []

            var matchedVisits: Set<PersistentIdentifier> = []
            var photoMatches: [PhotoMatch] = []
            var allTokensSatisfied = true

            for token in tokens {
                let visitHits = dayVisits.filter { matches(token: token, visit: $0) }
                let photoHits = dayTags.filter { matchesPhoto(token: token, labels: $0.labels) }
                if visitHits.isEmpty && photoHits.isEmpty {
                    allTokensSatisfied = false
                    break
                }
                for hit in visitHits { matchedVisits.insert(hit.persistentModelID) }
                if !photoHits.isEmpty {
                    photoMatches.append(PhotoMatch(token: token, count: photoHits.count))
                }
            }
            guard allTokensSatisfied else { continue }

            results.append(DayResult(
                dayKey: dayKey,
                visits: dayVisits
                    .filter { matchedVisits.contains($0.persistentModelID) }
                    .sorted { $0.arrival < $1.arrival },
                photoMatches: photoMatches
            ))
        }
        return results.sorted { $0.dayKey > $1.dayKey }
    }

    static func tokenize(_ query: String) -> [String] {
        query.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 1 && !stopwords.contains($0) }
    }

    // MARK: - Ort-Abgleich

    private static func matches(token: String, visit: PlaceVisit) -> Bool {
        for candidate in variants(of: token) {
            if waterInland.contains(candidate), !visit.inlandWater.isEmpty { return true }
            if waterOcean.contains(candidate), !visit.ocean.isEmpty { return true }
            if visit.searchText.contains(candidate) { return true }
        }
        return false
    }

    // MARK: - Foto-Abgleich

    private static func matchesPhoto(token: String, labels: String) -> Bool {
        guard !labels.isEmpty else { return false }
        for candidate in variants(of: token) {
            if let english = photoSynonyms[candidate] {
                if english.contains(where: { labels.contains($0) }) { return true }
            }
            // Direkttreffer, falls jemand den englischen Begriff eingibt.
            if labels.contains(candidate) { return true }
        }
        return false
    }

    /// Einfache Pluralbehandlung: „Seen“ → „See“, „Parks“ → „Park“.
    private static func variants(of token: String) -> [String] {
        var list = [token]
        for suffix in ["en", "n", "s", "e"] where token.hasSuffix(suffix) && token.count > suffix.count + 2 {
            list.append(String(token.dropLast(suffix.count)))
        }
        return list
    }
}
