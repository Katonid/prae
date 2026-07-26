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
        var visits: [VisitInfo]
        var photoMatches: [PhotoMatch]
        var routeSummary: String     // Wegesrand-Treffer: Drei-Orte-Beschreibung
        var id: String { dayKey }
    }

    /// Erkannte Zeitfrage („wo war ich gestern um 17 Uhr“).
    struct TimeQuestion {
        var dayKey: String
        var time: Date
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

    /// Ein Tag trifft, wenn jedes Suchwort belegt ist — durch einen
    /// Aufenthalt, ein Foto-Stichwort oder die Wegesrand-Beschreibung
    /// (Drei-Orte-Text aus Streckenstichproben).
    static func search(query: String, visits: [VisitInfo], tags: [MediaTag], daySummaries: [String: String] = [:]) -> [DayResult] {
        let tokens = tokenize(query)
        guard !tokens.isEmpty else { return [] }

        let visitsByDay = Dictionary(grouping: visits, by: \.dayKey)
        let tagsByDay = Dictionary(grouping: tags, by: \.dayKey)
        let allDays = Set(visitsByDay.keys)
            .union(tagsByDay.keys)
            .union(daySummaries.keys)

        var results: [DayResult] = []
        for dayKey in allDays {
            let dayVisits = visitsByDay[dayKey] ?? []
            let dayTags = tagsByDay[dayKey] ?? []
            let routeText = (daySummaries[dayKey] ?? "").lowercased()

            var matchedVisits: Set<String> = []
            var photoMatches: [PhotoMatch] = []
            var routeMatched = false
            var allTokensSatisfied = true

            for token in tokens {
                let visitHits = dayVisits.filter { matches(token: token, visit: $0) }
                let photoHits = dayTags.filter { matchesPhoto(token: token, labels: $0.labels) }
                let routeHit = matchesText(token: token, in: routeText)
                if visitHits.isEmpty && photoHits.isEmpty && !routeHit {
                    allTokensSatisfied = false
                    break
                }
                for hit in visitHits { matchedVisits.insert(hit.id) }
                if !photoHits.isEmpty {
                    photoMatches.append(PhotoMatch(token: token, count: photoHits.count))
                }
                if routeHit { routeMatched = true }
            }
            guard allTokensSatisfied else { continue }

            results.append(DayResult(
                dayKey: dayKey,
                visits: dayVisits
                    .filter { matchedVisits.contains($0.id) }
                    .sorted { $0.arrival < $1.arrival },
                photoMatches: photoMatches,
                routeSummary: routeMatched ? (daySummaries[dayKey] ?? "") : ""
            ))
        }
        return results.sorted { $0.dayKey > $1.dayKey }
    }

    // MARK: - Zeitfragen („wo war ich gestern um 17 Uhr“)

    /// Deterministischer Parser: erkennt Tag (heute/gestern/vorgestern
    /// oder Datum „12.07.“/„12.07.2026“) plus Uhrzeit („17 Uhr“, „17:30“).
    /// Nur Uhrzeit ohne Tag = heute.
    static func parseTimeQuestion(_ query: String, now: Date = Date()) -> TimeQuestion? {
        let lower = query.lowercased()
        let calendar = Calendar.current

        var hour: Int?
        var minute = 0
        if let match = firstMatch(pattern: "(\\d{1,2}):(\\d{2})", in: lower) {
            hour = Int(match[1])
            minute = Int(match[2]) ?? 0
        } else if let match = firstMatch(pattern: "(\\d{1,2})\\s*uhr", in: lower) {
            hour = Int(match[1])
        }
        guard let h = hour, (0...23).contains(h), (0...59).contains(minute) else { return nil }

        var baseDay: Date? = nil
        if lower.contains("vorgestern") {
            baseDay = calendar.date(byAdding: .day, value: -2, to: now)
        } else if lower.contains("gestern") {
            baseDay = calendar.date(byAdding: .day, value: -1, to: now)
        } else if lower.contains("heute") {
            baseDay = now
        } else if let match = firstMatch(pattern: "(\\d{1,2})\\.(\\d{1,2})\\.(\\d{4})", in: lower),
                  let day = Int(match[1]), let month = Int(match[2]), let year = Int(match[3]) {
            baseDay = calendar.date(from: DateComponents(year: year, month: month, day: day))
        } else if let match = firstMatch(pattern: "(\\d{1,2})\\.(\\d{1,2})\\.", in: lower),
                  let day = Int(match[1]), let month = Int(match[2]) {
            let year = calendar.component(.year, from: now)
            baseDay = calendar.date(from: DateComponents(year: year, month: month, day: day))
        } else {
            baseDay = now
        }
        guard let base = baseDay,
              let time = calendar.date(bySettingHour: h, minute: minute, second: 0, of: base) else {
            return nil
        }
        return TimeQuestion(dayKey: DayKey.key(for: time), time: time)
    }

    private static func firstMatch(pattern: String, in text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
            return nil
        }
        return (0..<match.numberOfRanges).map { index in
            guard let range = Range(match.range(at: index), in: text) else { return "" }
            return String(text[range])
        }
    }

    static func tokenize(_ query: String) -> [String] {
        query.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 1 && !stopwords.contains($0) }
    }

    // MARK: - Ort-Abgleich

    private static func matches(token: String, visit: VisitInfo) -> Bool {
        for candidate in variants(of: token) {
            if waterInland.contains(candidate), !visit.inlandWater.isEmpty { return true }
            if waterOcean.contains(candidate), !visit.ocean.isEmpty { return true }
            if visit.searchText.contains(candidate) { return true }
        }
        return false
    }

    // MARK: - Wegesrand-Abgleich (Drei-Orte-Beschreibung)

    private static func matchesText(token: String, in text: String) -> Bool {
        guard !text.isEmpty else { return false }
        return variants(of: token).contains { text.contains($0) }
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
