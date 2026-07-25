import Foundation

/// Deterministische Ort-Suche über die gespeicherten Aufenthalte.
/// Kein LLM: Stoppwörter raus, Synonyme aufklappen, Textfelder und
/// Gewässer-Attribute der Placemarks abgleichen — nachvollziehbar
/// und offline.
enum SearchEngine {

    struct DayResult: Identifiable {
        var dayKey: String
        var visits: [PlaceVisit]
        var id: String { dayKey }
    }

    private static let stopwords: Set<String> = [
        "zeige", "zeig", "mir", "die", "der", "das", "den", "dem", "des",
        "tage", "tagen", "tag", "orte", "ort", "an", "denen", "dem", "ich",
        "einem", "einer", "eine", "ein", "war", "waren", "bin", "gewesen",
        "bei", "wo", "am", "im", "in", "auf", "mit", "nach", "und", "oder",
        "alle", "welche", "welchen", "habe", "hab", "mal", "wann", "als"
    ]

    /// Synonymgruppen: Trefferbedingung ist entweder ein Attribut
    /// (Binnengewässer/Meer) oder ein Textstichwort.
    private static let waterInland = ["see", "badesee", "weiher", "teich", "stausee", "fluss", "bach", "kanal", "gewässer", "wasser"]
    private static let waterOcean = ["meer", "ozean", "strand", "küste", "kueste", "nordsee", "ostsee"]

    static func search(query: String, in visits: [PlaceVisit]) -> [DayResult] {
        let tokens = tokenize(query)
        guard !tokens.isEmpty else { return [] }

        let matched = visits.filter { visit in
            tokens.allSatisfy { matches(token: $0, visit: visit) }
        }
        let grouped = Dictionary(grouping: matched, by: \.dayKey)
        return grouped
            .map { DayResult(dayKey: $0.key, visits: $0.value.sorted { $0.arrival < $1.arrival }) }
            .sorted { $0.dayKey > $1.dayKey }
    }

    static func tokenize(_ query: String) -> [String] {
        query.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 1 && !stopwords.contains($0) }
    }

    private static func matches(token: String, visit: PlaceVisit) -> Bool {
        let text = visit.searchText

        if waterInland.contains(token) {
            if !visit.inlandWater.isEmpty { return true }
        }
        if waterOcean.contains(token) {
            if !visit.ocean.isEmpty { return true }
        }
        if text.contains(token) { return true }

        // Einfache Pluralbehandlung: „Seen" → „See", „Parks" → „Park".
        for suffix in ["en", "n", "s", "e"] where token.hasSuffix(suffix) && token.count > suffix.count + 2 {
            let singular = String(token.dropLast(suffix.count))
            if waterInland.contains(singular), !visit.inlandWater.isEmpty { return true }
            if waterOcean.contains(singular), !visit.ocean.isEmpty { return true }
            if text.contains(singular) { return true }
        }
        return false
    }
}
