import Foundation

// MARK: - Art einer Nachricht

/// Wonach der Nutzer die Ligameldungen sortieren und filtern kann.
///
/// football-data.org kennt nur Spielstände — Transfers und Gerüchte stehen
/// dort nirgends. Die Einteilung entsteht deshalb hier: aus den Worten in
/// Überschrift und Anriss. Das ist eine Schätzung, keine Wissenschaft, und
/// die App sagt das an der entsprechenden Stelle auch.
enum Nachrichtenart: String, Codable, Hashable, CaseIterable, Identifiable {
    case aufstellung
    case transfer
    case geruecht
    case verletzung
    case spielbericht
    case verein
    case sonstiges

    var id: String { rawValue }

    var name: String {
        switch self {
        case .aufstellung: return "Aufstellung & Vorbericht"
        case .transfer: return "Transfer"
        case .geruecht: return "Gerücht"
        case .verletzung: return "Verletzung & Sperre"
        case .spielbericht: return "Spielbericht & Analyse"
        case .verein: return "Rund um den Verein"
        case .sonstiges: return "Sonstiges"
        }
    }

    var beschreibung: String {
        switch self {
        case .aufstellung: return "Startelf, Personal und Vorschau auf die Partie."
        case .transfer: return "Wechsel, Unterschriften, Leihen, Abgänge."
        case .geruecht: return "Was angeblich, offenbar oder womöglich ansteht."
        case .verletzung: return "Ausfälle, Sperren, Rückkehr nach Verletzung."
        case .spielbericht: return "Nachbericht, Analyse, Noten, Stimmen — hier stehen auch Platzverweise."
        case .verein: return "Trainer, Vorstand, Vertrag, Stadion."
        case .sonstiges: return "Alles Übrige aus den Quellen."
        }
    }

    var symbol: String {
        switch self {
        case .aufstellung: return "person.3.fill"
        case .transfer: return "arrow.left.arrow.right.circle.fill"
        case .geruecht: return "questionmark.bubble.fill"
        case .verletzung: return "cross.case.fill"
        case .spielbericht: return "text.magnifyingglass"
        case .verein: return "building.columns.fill"
        case .sonstiges: return "newspaper.fill"
        }
    }
}

// MARK: - Quellen

/// Die Nachrichtenquellen. Beides frei zugängliche RSS-Ausgaben — kein
/// Schlüssel, keine Anmeldung. Die App zeigt Überschrift und Anriss und
/// verweist zum Lesen auf die Quelle; die vollen Texte holt sie nicht.
enum Nachrichtenquelle: String, Codable, Hashable, CaseIterable, Identifiable {
    case kicker
    case kickerBundesliga
    case kickerChampionsLeague
    case transfermarkt

    var id: String { rawValue }

    var name: String {
        switch self {
        case .kicker: return "kicker — Fußball"
        case .kickerBundesliga: return "kicker — Bundesliga"
        case .kickerChampionsLeague: return "kicker — Champions League"
        case .transfermarkt: return "Transfermarkt"
        }
    }

    var beschreibung: String {
        switch self {
        case .kicker: return "Alle Fußballmeldungen des kicker."
        case .kickerBundesliga: return "Nur die Bundesliga, dafür dichter."
        case .kickerChampionsLeague: return "Europapokal — dort spielen dieselben Vereine."
        case .transfermarkt: return "Schwerpunkt Wechsel und Gerüchte."
        }
    }

    var adresse: URL? {
        switch self {
        case .kicker: return URL(string: "https://newsfeed.kicker.de/news/fussball")
        case .kickerBundesliga: return URL(string: "https://newsfeed.kicker.de/news/bundesliga")
        case .kickerChampionsLeague: return URL(string: "https://newsfeed.kicker.de/news/champions-league")
        case .transfermarkt: return URL(string: "https://www.transfermarkt.de/rss/news")
        }
    }

    /// Quellen, die ohne Zutun des Nutzers gelesen werden.
    static let voreinstellung: Set<Nachrichtenquelle> = [.kicker, .transfermarkt]
}

// MARK: - Nachricht

struct Nachricht: Identifiable, Hashable, Codable {
    let id: String
    let titel: String
    let anriss: String
    let adresse: URL?
    let zeitpunkt: Date
    let quelle: Nachrichtenquelle
    let art: Nachrichtenart
    /// Liga, wenn sie sich aus Text oder Schlagworten ablesen ließ.
    let liga: Liga?
    /// Schlagworte der Quelle — beim kicker sind das Vereine und Wettbewerbe.
    let schlagworte: [String]

    var quellenname: String { quelle.name }
}

// MARK: - Einteilung

/// Ordnet einer Meldung ihre Art und, wenn möglich, ihre Liga zu.
enum Nachrichtensieb {

    // Reihenfolge zählt: Ein Gerücht ist auch ein Transfer, soll aber als
    // Gerücht durchgehen. Deshalb wird zuerst auf Unsicherheit geprüft.
    private static let unsicher = [
        "gerücht", "geruecht", "angeblich", "offenbar", "soll wechseln",
        "spekulation", "spekuliert", "interesse an", "buhlt", "wirbt um",
        "steht vor einem wechsel", "poker", "kandidat", "auf dem zettel",
        "im visier", "liebäugelt", "denkt über", "könnte wechseln",
        "wohl vor", "beschäftigt sich mit", "erwägt"
    ]

    private static let elf = [
        "aufstellung", "startelf", "startformation", "voraussichtlich",
        "so könnte", "so koennte", "so spielt", "vorbericht", "vorschau",
        "personalsorgen", "personallage", "wer spielt", "diese elf",
        "rückt in die", "rueckt in die", "ansetzung", "angesetzt",
        "das spiel im überblick", "vor dem spiel", "in den kader", "kader nominiert",
        "kader zurück", "kader zurueck"
    ]

    private static let bericht = [
        "spielbericht", "nachbericht", "einzelkritik", "die noten",
        "pressestimmen", "stimmen zum spiel", "die stimmen", "so lief",
        "analyse", "fazit", "statistik zum spiel", "zusammenfassung",
        "rote karte", "platzverweis", "gelb-rot", "glatt rot",
        "des tages", "spieler des spiels"
    ]

    private static let wechsel = [
        "transfer", "wechsel", "wechselt", "unterschreibt", "unterschrieben",
        "verpflichtet", "verpflichtung", "leihe", "ausgeliehen", "leiht",
        "abgang", "abgäng", "abgaeng", "zugang", "zugäng", "zugaeng", "neuzugang",
        "ablöse", "abloese", "ablösesumme", "vertrag unterschrieben", "kaderplanung",
        "holt", "kommt von", "verlässt", "verlaesst", "deal", "medizincheck",
        "transferfenster", "wechselbörse", "wechselboerse"
    ]

    private static let blessur = [
        "verletzt", "verletzung", "ausfall", "fällt aus", "faellt aus",
        "operation", "operiert", "kreuzband", "muskelbündelriss", "muskelfaserriss",
        "sperre", "gesperrt", "rotsperre", "reha", "rückkehr nach",
        "comeback nach", "verletzungscomeback", "wieder im training",
        "angeschlagen", "bänderriss", "baenderriss", "adduktoren", "trainingsrückkehr"
    ]

    private static let vereinssache = [
        "trainer", "cheftrainer", "entlassen", "beurlaubt", "nachfolger",
        "vorstand", "geschäftsführer", "geschaeftsfuehrer", "sportdirektor",
        "vertragsverlängerung", "vertragsverlaengerung", "verlängert",
        "verlaengert", "präsident", "praesident", "stadion", "mitgliederversammlung",
        "kapitän", "kapitaen", "kader", "aufsichtsrat", "lizenz"
    ]

    static func art(titel: String, anriss: String) -> Nachrichtenart {
        let text = (titel + " " + anriss).lowercased()
        // Die Reihenfolge ist die Aussage: Ein Gerücht ist auch ein Transfer,
        // soll aber als Gerücht durchgehen; ein Spielbericht nennt fast immer
        // den Trainer, ist deshalb aber keine Vereinsmeldung.
        if unsicher.contains(where: { text.contains($0) }) { return .geruecht }
        if elf.contains(where: { text.contains($0) }) { return .aufstellung }
        if wechsel.contains(where: { text.contains($0) }) { return .transfer }
        if blessur.contains(where: { text.contains($0) }) { return .verletzung }
        if bericht.contains(where: { text.contains($0) }) { return .spielbericht }
        if vereinssache.contains(where: { text.contains($0) }) { return .verein }
        return .sonstiges
    }

    /// Namen, unter denen die Ligen selbst in Meldungen auftauchen.
    private static let ligaworte: [(Liga, [String])] = [
        (.bundesliga, ["bundesliga"]),
        (.premierLeague, ["premier league", "premier-league"]),
        (.laLiga, ["laliga", "la liga", "primera división", "primera division"]),
        (.serieA, ["serie a"]),
        (.ligue1, ["ligue 1", "ligue1"])
    ]

    /// Erst die Schlagworte der Quelle, dann der Text, zuletzt das
    /// Vereinsverzeichnis. Findet sich nichts, bleibt die Liga offen —
    /// das ist ehrlicher, als zu raten.
    static func liga(titel: String, anriss: String, schlagworte: [String]) -> Liga? {
        let schlagtext = schlagworte.joined(separator: " ").lowercased()
        for (liga, worte) in ligaworte where worte.contains(where: { schlagtext.contains($0) }) {
            // "2. Bundesliga" ist nicht die Bundesliga.
            if liga == .bundesliga, schlagtext.contains("2. bundesliga") || schlagtext.contains("3. liga") {
                continue
            }
            return liga
        }

        let text = (titel + " " + anriss).lowercased()
        for (liga, worte) in ligaworte where worte.contains(where: { text.contains($0) }) {
            if liga == .bundesliga, text.contains("2. bundesliga") { continue }
            return liga
        }

        if let ausSchlagwort = Vereinsverzeichnis.liga(zuNamen: schlagworte) { return ausSchlagwort }
        return Vereinsverzeichnis.liga(imText: titel + " " + anriss)
    }
}

// MARK: - Vereinsverzeichnis

/// Merkt sich, welcher Verein zu welcher Liga gehört — gefüllt aus den
/// Tabellen und Spieltagen, die die App ohnehin lädt. Dadurch braucht es
/// keine gepflegte Namensliste im Quelltext, die jeden Sommer veraltet.
enum Vereinsverzeichnis {
    private static let ablageSchluessel = "vereinsverzeichnis"

    /// Kleingeschriebener Vereinsname → Ligakennung.
    private static func lesen() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: ablageSchluessel) as? [String: String] ?? [:]
    }

    static func merken(_ mannschaften: [Mannschaft], liga: Liga) {
        guard !mannschaften.isEmpty else { return }
        let vorher = lesen()
        var verzeichnis = vorher
        for mannschaft in mannschaften {
            for name in namen(mannschaft) {
                verzeichnis[name] = liga.rawValue
            }
        }
        // Der Ticker ruft das alle 45 Sekunden auf — geschrieben wird nur,
        // wenn wirklich ein Name dazugekommen oder umgezogen ist.
        guard verzeichnis != vorher else { return }
        UserDefaults.standard.set(verzeichnis, forKey: ablageSchluessel)
    }

    static func merken(spiele: [Spiel]) {
        var nachLiga: [Liga: [Mannschaft]] = [:]
        for spiel in spiele {
            nachLiga[spiel.liga, default: []].append(spiel.heim)
            nachLiga[spiel.liga, default: []].append(spiel.gast)
        }
        for (liga, mannschaften) in nachLiga {
            merken(mannschaften, liga: liga)
        }
    }

    static func liga(zuNamen schlagworte: [String]) -> Liga? {
        let verzeichnis = lesen()
        guard !verzeichnis.isEmpty else { return nil }
        for wort in schlagworte {
            let sauber = vereinfachen(wort)
            guard sauber.count >= 4, let kennung = verzeichnis[sauber] else { continue }
            if let liga = Liga(rawValue: kennung) { return liga }
        }
        return nil
    }

    static func liga(imText text: String) -> Liga? {
        let verzeichnis = lesen()
        guard !verzeichnis.isEmpty else { return nil }
        let gesucht = vereinfachen(text)
        // Der längste Treffer gewinnt: "Bayern München" schlägt "Bayern".
        var bester: (String, String)?
        for (name, kennung) in verzeichnis where name.count >= 5 && gesucht.contains(name) {
            if bester == nil || name.count > bester!.0.count { bester = (name, kennung) }
        }
        guard let bester else { return nil }
        return Liga(rawValue: bester.1)
    }

    /// Ein Verein heißt in jeder Quelle anders. Deshalb landen mehrere
    /// Schreibweisen im Verzeichnis: voller Name, Kurzname und der Name
    /// ohne Rechtsform-Beiwerk ("FC", "SV", "AC", "1899" …).
    private static func namen(_ mannschaft: Mannschaft) -> [String] {
        var liste = [mannschaft.name, mannschaft.kurzname]
        if let ausLang = kern(mannschaft.name) { liste.append(ausLang) }
        if let ausKurz = kern(mannschaft.kurzname) { liste.append(ausKurz) }
        return liste
            .map { vereinfachen($0) }
            .filter { $0.count >= 4 }
    }

    private static let beiwerk: Set<String> = [
        "fc", "sv", "sc", "vfb", "vfl", "tsg", "tsv", "bsc", "ssv", "fsv",
        "ac", "as", "ss", "us", "cf", "cd", "rc", "ca", "afc", "cfc",
        "club", "calcio", "united", "city", "real", "athletic", "atletico",
        "1899", "1846", "1904", "1900", "05", "04", "96"
    ]

    private static func kern(_ name: String) -> String? {
        let teile = name
            .split(whereSeparator: { $0 == " " || $0 == "." })
            .map { String($0).lowercased() }
            .filter { !beiwerk.contains($0) }
        guard teile.count >= 1 else { return nil }
        return teile.joined(separator: " ")
    }

    /// Klein, ohne Umlautbesonderheiten, ohne Satzzeichen — damit
    /// "Bor. Mönchengladbach" und "Borussia Monchengladbach" zueinander finden.
    private static func vereinfachen(_ text: String) -> String {
        let flach = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "de_DE"))
        let erlaubt = flach.map { zeichen -> Character in
            if zeichen.isLetter || zeichen.isNumber { return zeichen }
            return " "
        }
        return String(erlaubt)
            .split(separator: " ")
            .joined(separator: " ")
    }

    static func leeren() {
        UserDefaults.standard.removeObject(forKey: ablageSchluessel)
    }
}

// MARK: - Nachrichten auf der Platte

/// Wie beim Ticker: Der Bestand überlebt einen Programmstart, wächst aber
/// nicht ewig. Der Hintergrundlauf schreibt hier hinein, die Oberfläche liest.
enum Nachrichtenspeicher {
    private static let grenze = 120

    private static var ort: URL? {
        let ordner = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        return ordner?.appendingPathComponent("nachrichten.json")
    }

    static func laden() -> [Nachricht] {
        guard let ort, let daten = try? Data(contentsOf: ort) else { return [] }
        let alle = JSONDecoder().nachsichtigeListe(Nachricht.self, aus: daten)
        let grenze = Date().addingTimeInterval(-60 * 60 * 24 * 5)
        return alle.filter { $0.zeitpunkt > grenze }
    }

    /// Hängt an, wirft Doppelte weg, sortiert nach Zeit und kürzt.
    /// Gibt zusätzlich zurück, was davon wirklich neu war — nur darüber
    /// darf eine Mitteilung ausgelöst werden.
    static func anhaengen(_ frisch: [Nachricht]) -> (bestand: [Nachricht], neue: [Nachricht]) {
        let alt = laden()
        let bekannt = Set(alt.map(\.id))
        let neue = frisch.filter { !bekannt.contains($0.id) }

        var gesehen = Set<String>()
        var zusammen: [Nachricht] = []
        for nachricht in alt + neue where !gesehen.contains(nachricht.id) {
            gesehen.insert(nachricht.id)
            zusammen.append(nachricht)
        }
        zusammen.sort { $0.zeitpunkt > $1.zeitpunkt }
        let gekuerzt = Array(zusammen.prefix(grenze))
        sichern(gekuerzt)
        return (gekuerzt, neue)
    }

    static func sichern(_ nachrichten: [Nachricht]) {
        guard let ort else { return }
        let ordner = ort.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        guard let daten = try? JSONEncoder().encode(nachrichten) else { return }
        try? daten.write(to: ort, options: .atomic)
    }

    static func leeren() {
        sichern([])
    }
}
