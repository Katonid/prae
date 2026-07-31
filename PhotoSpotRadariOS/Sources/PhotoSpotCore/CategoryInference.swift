import Foundation

/// Infers a spot category from free text (article titles, descriptions, photo tags).
///
/// Matching is deliberately word-based, not substring-based: "Hamburg" must not become a castle
/// via "burg", "Bergstraße" must not become a mountain and "Museumssee" must not become a lake.
/// Single-word keywords only match complete words; multi-word keywords match as whole phrases.
public enum CategoryInference {
    /// Returns the first matching category, or `nil` when the text carries no photographic signal.
    public static func category(from raw: String) -> SpotCategory? {
        let padded = " \(normalize(raw)) "
        return rules.first { _, keywords in
            keywords.contains { padded.contains(" \($0) ") }
        }?.0
    }

    /// `true` when the text describes something that is notable and photographed, yet not a
    /// photo spot: administrative areas and settlements ("Greater Toronto Area", "Stadtteil von
    /// Berlin") as well as pure infrastructure and institutions (transit systems, airports,
    /// hospitals, companies). Used to reject uncategorised records at ingestion.
    public static func describesNonSpotSubject(_ raw: String) -> Bool {
        let normalized = normalize(raw)
        let padded = " \(normalized) "
        if nonSpotTerms.contains(where: { padded.contains(" \($0) ") }) { return true }
        // German class names are compounds ("Fußballstadion", "Forschungsuniversität"), so the
        // decisive class word is a suffix rather than a standalone word.
        return normalized.split(separator: " ").contains { word in
            nonSpotSuffixes.contains { word.hasSuffix($0) }
        }
    }

    private static let nonSpotSuffixes = [
        "stadion", "stadium", "arena", "universitat", "hochschule",
        "krankenhaus", "flughafen", "einkaufszentrum", "kongresszentrum"
    ]

    private static let nonSpotTerms = [
        // Settlements and administrative areas.
        "city", "town", "village", "hamlet", "municipality", "metropolitan area", "urban area",
        "metropolitan region", "conurbation", "neighbourhood", "neighborhood", "suburb",
        "borough", "county", "district", "administrative", "settlement", "census",
        "stadt", "grossstadt", "kleinstadt", "stadtteil", "stadtbezirk", "ortsteil", "gemeinde",
        "dorf", "bezirk", "landkreis", "regierungsbezirk", "bundesland", "metropolregion",
        "ballungsraum", "vorort", "siedlung",
        // Infrastructure and institutions.
        "airport", "airfield", "flughafen", "flugplatz", "rapid transit", "transit system",
        "subway system", "metro system", "u bahn", "railway line", "railway system", "bus route",
        "highway", "expressway", "autobahn", "hospital", "krankenhaus", "school",
        "schule", "university", "universitat", "hochschule", "company", "enterprise", "business",
        "unternehmen", "organisation", "organization", "shopping mall", "shopping centre",
        "shopping center", "einkaufszentrum",
        // Venues and media that are famous yet not photo subjects.
        "convention centre", "convention center", "kongresszentrum", "messegelande",
        "exhibition centre", "exhibition center", "stadium", "stadion", "arena",
        "television", "fernsehsender", "fernsehnetzwerk", "broadcaster", "rundfunkanstalt",
        "radio station", "radiosender"
    ]

    /// Lowercases, strips diacritics and reduces everything that is not a letter or digit to a
    /// single space, so keyword matching can rely on word boundaries.
    private static func normalize(_ text: String) -> String {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil).lowercased()
        return folded
            .map { $0.isLetter || $0.isNumber ? String($0) : " " }
            .joined()
            .split(separator: " ")
            .joined(separator: " ")
    }

    /// Order encodes priority: the most specific, most photogenic categories win. Keywords are
    /// stored pre-normalized (lowercase, no diacritics).
    private static let rules: [(SpotCategory, [String])] = [
        (.waterfall, ["waterfall", "wasserfall", "falls", "cascade", "kaskade"]),
        (.viewpoint, ["viewpoint", "lookout", "belvedere", "aussicht", "aussichtspunkt",
                      "aussichtsplattform", "aussichtsturm", "observation deck", "skywalk", "panorama"]),
        (.nationalPark, ["national park", "nationalpark", "provincial park", "nature reserve",
                         "naturreservat", "naturschutzgebiet", "biospharenreservat"]),
        (.canyon, ["canyon", "gorge", "schlucht", "klamm"]),
        (.cliff, ["cliff", "cliffs", "klippe", "klippen", "felswand"]),
        (.cave, ["cave", "cavern", "hohle", "grotte", "grotto", "tropfsteinhohle"]),
        (.peak, ["peak", "summit", "gipfel"]),
        (.mountain, ["mountain", "mount", "berg", "massif", "massiv", "volcano", "vulkan"]),
        (.beach, ["beach", "strand", "playa"]),
        (.coast, ["coast", "coastline", "kuste", "steilkuste"]),
        (.lake, ["lake", "see", "stausee", "lac", "lago"]),
        (.river, ["river", "fluss", "riviere"]),
        (.forest, ["forest", "wald", "urwald"]),
        (.lighthouse, ["lighthouse", "leuchtturm", "phare"]),
        (.castle, ["castle", "schloss", "burg", "burgruine", "chateau", "fortress", "festung"]),
        (.ruin, ["ruin", "ruins", "ruine", "ruinen"]),
        (.bridge, ["bridge", "brucke", "viaduct", "viadukt"]),
        (.church, ["church", "cathedral", "kirche", "dom", "kathedrale", "basilica", "basilika",
                   "abbey", "abtei", "kloster", "monastery", "munster"]),
        (.oldTown, ["altstadt", "old town", "historic district", "historic quarter", "old quarter"]),
        (.windmill, ["windmill", "windmuhle"]),
        (.botanicalGarden, ["botanical garden", "botanischer garten"]),
        (.harbour, ["harbour", "harbor", "hafen", "marina"]),
        (.pier, ["pier", "jetty", "seebrucke"]),
        (.streetArt, ["mural", "street art", "streetart", "wandbild"]),
        (.museum, ["museum"]),
        (.historicBuilding, ["historic building", "heritage building", "historic site", "tower",
                             "turm", "monument", "denkmal", "palace", "palast", "rathaus", "town hall"])
    ]
}
