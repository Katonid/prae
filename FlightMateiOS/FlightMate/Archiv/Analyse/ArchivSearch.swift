//
//  ArchivSearch.swift
//  FlightMate
//
//  Drone Media Explorer, M5 (Architektur Kap. 8): die intelligente
//  Suche — ehrlich als Facettensuche mit Sprachzucker, kein Chat-LLM.
//  Ein deterministischer Parser zerlegt Freitext in Facetten
//  (Szene, Jahr/Monat, Medienart, Favoriten, Ortsnamen) und erklärt
//  seine Deutung sichtbar. Gesucht wird im Katalog: Vision-Tags,
//  Schlagworte, Notizen, Dateinamen, Spot-/Reise-Namen und die
//  geokodierten Länder/Orte der Foto-Spots.
//

import Foundation

enum ArchivSearch {

    // MARK: Vokabular (Deutsch → Vision-Taxonomie)

    static let sceneDE2EN: [String: [String]] = [
        "wasserfall": ["waterfall"], "wasserfälle": ["waterfall"],
        "sonnenuntergang": ["sunset"], "sonnenuntergänge": ["sunset"],
        "sonnenaufgang": ["sunrise"], "sonnenaufgänge": ["sunrise"],
        "see": ["lake"], "seen": ["lake"],
        "strand": ["beach"], "strände": ["beach"],
        "meer": ["sea", "ocean", "coast"], "küste": ["coast", "shoreline"],
        "berg": ["mountain"], "berge": ["mountain"], "gebirge": ["mountain"],
        "wald": ["forest", "tree"], "wälder": ["forest"],
        "schnee": ["snow"], "winter": ["snow", "winter"],
        "stadt": ["city", "cityscape"], "städte": ["city"],
        "brücke": ["bridge"], "brücken": ["bridge"],
        "burg": ["castle"], "schloss": ["castle"], "burgen": ["castle"],
        "leuchtturm": ["lighthouse"], "leuchttürme": ["lighthouse"],
        "fluss": ["river"], "flüsse": ["river"],
        "himmel": ["sky"], "wolken": ["cloud"],
        "nacht": ["night"], "feld": ["field"], "felder": ["field"],
        "insel": ["island"], "inseln": ["island"],
        "hafen": ["harbor", "marina"], "boot": ["boat"], "boote": ["boat"],
    ]

    /// Anzeige-Übersetzung der wichtigsten Vision-Bezeichner.
    static let sceneEN2DE: [String: String] = [
        "waterfall": "Wasserfall", "sunset": "Sonnenuntergang",
        "sunrise": "Sonnenaufgang", "lake": "See", "beach": "Strand",
        "sea": "Meer", "ocean": "Ozean", "coast": "Küste",
        "shoreline": "Uferlinie", "mountain": "Berg", "forest": "Wald",
        "tree": "Bäume", "snow": "Schnee", "winter": "Winter",
        "city": "Stadt", "cityscape": "Stadtansicht", "bridge": "Brücke",
        "castle": "Burg/Schloss", "lighthouse": "Leuchtturm",
        "river": "Fluss", "sky": "Himmel", "cloud": "Wolken",
        "night": "Nacht", "field": "Feld", "island": "Insel",
        "harbor": "Hafen", "marina": "Yachthafen", "boat": "Boot",
        "outdoor": "Draußen", "landscape": "Landschaft",
        "aerial": "Luftaufnahme", "water": "Wasser", "sun": "Sonne",
    ]

    static func germanLabel(for identifier: String) -> String {
        sceneEN2DE[identifier] ?? identifier
    }

    private static let months: [String: Int] = [
        "januar": 1, "februar": 2, "märz": 3, "april": 4, "mai": 5,
        "juni": 6, "juli": 7, "august": 8, "september": 9,
        "oktober": 10, "november": 11, "dezember": 12,
    ]

    private static let stopwords: Set<String> = [
        "zeige", "zeig", "alle", "mir", "in", "an", "am", "auf", "mit",
        "von", "im", "aus", "meine", "bitte", "wo", "wann", "war",
        "ich", "zuletzt", "den", "die", "das", "der", "und", "bin",
        "schon", "über", "bei", "nach", "einem", "einer",
    ]

    // MARK: Parser

    struct ParsedQuery {
        var sceneTags: [String] = []
        var year: Int?
        var month: Int?
        var kind: MediaKind?
        var favoritesOnly = false
        var textTerms: [String] = []
        var interpretation = ""
    }

    static func parse(_ query: String) -> ParsedQuery {
        var result = ParsedQuery()
        var explanations: [String] = []
        let words = query.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }

        for word in words {
            if stopwords.contains(word) { continue }
            if let tags = sceneDE2EN[word] {
                result.sceneTags.append(contentsOf: tags)
                explanations.append("Szene „\(word.capitalized)“")
                continue
            }
            if let month = months[word] {
                result.month = month
                explanations.append("Monat \(word.capitalized)")
                continue
            }
            if word.count == 4, let year = Int(word), (2000...2100).contains(year) {
                result.year = year
                explanations.append("Jahr \(year)")
                continue
            }
            if ["video", "videos"].contains(word) {
                result.kind = .video
                explanations.append("nur Videos")
                continue
            }
            if ["foto", "fotos", "bild", "bilder"].contains(word) {
                result.kind = .photo
                explanations.append("nur Fotos")
                continue
            }
            if ["favorit", "favoriten"].contains(word) {
                result.favoritesOnly = true
                explanations.append("nur Favoriten")
                continue
            }
            result.textTerms.append(word)
        }
        if !result.textTerms.isEmpty {
            explanations.append("Text/Ort: \(result.textTerms.joined(separator: ", "))")
        }
        result.interpretation = explanations.isEmpty
            ? "Alle Medien" : "Gedeutet als: " + explanations.joined(separator: " · ")
        return result
    }

    // MARK: Treffer-Logik

    static func matches(_ asset: MediaAsset, query: ParsedQuery,
                        calendar: Calendar = .current) -> Bool {
        if let kind = query.kind, asset.kind != kind { return false }
        if query.favoritesOnly && !asset.favorite { return false }
        if let year = query.year,
           calendar.component(.year, from: asset.capturedAt) != year { return false }
        if let month = query.month,
           calendar.component(.month, from: asset.capturedAt) != month { return false }

        if !query.sceneTags.isEmpty {
            let haystack = (asset.aiTagsRaw + "\n" + asset.userTagsRaw).lowercased()
            guard query.sceneTags.contains(where: { haystack.contains($0) }) else {
                return false
            }
        }

        if !query.textTerms.isEmpty {
            let haystack = [
                asset.fileName, asset.notes, asset.userTagsRaw,
                asset.spot?.name ?? "", asset.spot?.locality ?? "",
                asset.spot?.country ?? "", asset.trip?.name ?? "",
            ].joined(separator: " ").lowercased()
            for term in query.textTerms where !haystack.contains(term) {
                return false
            }
        }
        return true
    }
}
