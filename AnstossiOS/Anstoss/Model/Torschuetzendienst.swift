import Foundation

/// Holt Torschützen aus **OpenLigaDB** — nur für die Bundesliga.
///
/// Hintergrund: Der freie Zugang von football-data.org liefert die Torfolge
/// oft nicht mit. Für die Bundesliga gibt es mit OpenLigaDB einen freien,
/// schlüssellosen Dienst, der Schütze, Minute, Elfmeter und Eigentor
/// mitschickt. Für die vier anderen Ligen kennt die App nichts
/// Vergleichbares — dort bleibt es beim Rückfall aus dem Sprung im
/// Spielstand.
///
/// Der Dienst zählt **nicht** gegen die zehn Abfragen je Minute von
/// football-data.org; er hat ein eigenes, großzügiges Kontingent. Trotzdem
/// wird je Spieltag nur einmal in fünf Minuten gefragt.
enum Torschuetzendienst {

    static let quellenname = "OpenLigaDB"
    private static let basis = URL(string: "https://api.openligadb.de/")!
    private static let mindestabstand: TimeInterval = 5 * 60

    /// Was zuletzt geholt wurde, je Spieltag — im Arbeitsspeicher, denn
    /// der Nutzen hält nur, solange die App offen ist.
    private static let zwischenspeicher = Spieltagsspeicher()

    /// Ergänzt die Torfolge der übergebenen Spiele, soweit sie fehlt.
    /// Spiele anderer Ligen und Spiele, die schon Torschützen haben,
    /// bleiben unberührt.
    static func torfolgeErgaenzen(_ spiele: [Spiel]) async -> [Spiel] {
        let luecken = spiele.filter { $0.liga == .bundesliga && $0.tore.isEmpty && $0.hatStand }
        guard !luecken.isEmpty else { return spiele }

        // Alle betroffenen Spieltage einmal holen, nicht je Spiel.
        var nachSpieltag: [Int: [Rohspiel]] = [:]
        let jahrgang = saison(zu: luecken)
        for nummer in Set(luecken.map(\.spieltag)).sorted() where nummer > 0 {
            nachSpieltag[nummer] = await spieltagHolen(nummer, saison: jahrgang)
        }
        guard !nachSpieltag.isEmpty else { return spiele }

        return spiele.map { spiel in
            guard spiel.liga == .bundesliga, spiel.tore.isEmpty, spiel.hatStand,
                  let rohspiele = nachSpieltag[spiel.spieltag],
                  let treffer = passendes(rohspiele, zu: spiel) else { return spiel }
            var ergaenzt = spiel
            ergaenzt.tore = treffer.tore(spielID: spiel.id)
            ergaenzt.torfolgeQuelle = ergaenzt.tore.isEmpty ? nil : quellenname
            ergaenzt.torfolgeUnvollstaendig = false
            return ergaenzt
        }
    }

    /// Die Saison, in der ein Spieltag liegt: OpenLigaDB zählt eine Saison
    /// nach dem Jahr ihres Beginns, die Rückrunde im Frühjahr gehört also
    /// noch zum Vorjahr.
    private static func saison(zu spiele: [Spiel]) -> Int {
        let bezug = spiele.first?.anstoss ?? Date()
        let teile = Calendar.current.dateComponents([.year, .month], from: bezug)
        let jahr = teile.year ?? 2026
        let monat = teile.month ?? 8
        return monat >= 7 ? jahr : jahr - 1
    }

    private static func spieltagHolen(_ nummer: Int, saison: Int) async -> [Rohspiel] {
        if let gemerkt = await zwischenspeicher.frisch(nummer, saison: saison, abstand: mindestabstand) {
            return gemerkt
        }
        let url = basis.appendingPathComponent("getmatchdata/bl1/\(saison)/\(nummer)")
        var anfrage = URLRequest(url: url)
        anfrage.timeoutInterval = 15
        anfrage.setValue("Anstoss/1.0 (iOS)", forHTTPHeaderField: "User-Agent")

        guard let (daten, antwort) = try? await URLSession.shared.data(for: anfrage),
              let http = antwort as? HTTPURLResponse, http.statusCode == 200,
              let gelesen = try? JSONDecoder().decode([Rohspiel].self, from: daten) else {
            return []
        }
        await zwischenspeicher.ablegen(gelesen, spieltag: nummer, saison: saison)
        return gelesen
    }

    /// Ordnet ein OpenLigaDB-Spiel der Begegnung zu. Verglichen werden die
    /// vereinfachten Vereinsnamen — die Kennungen der beiden Dienste haben
    /// nichts miteinander zu tun.
    private static func passendes(_ rohspiele: [Rohspiel], zu spiel: Spiel) -> Rohspiel? {
        rohspiele.first { roh in
            trifft(roh.team1, auf: spiel.heim) && trifft(roh.team2, auf: spiel.gast)
        }
    }

    /// Beide Seiten müssen stimmen. Eine Zuordnung allein über die Heimelf
    /// ginge bei einem verlegten Spiel daneben, und ein falsch zugeordneter
    /// Torschütze wäre schlimmer als gar keiner.
    private static func trifft(_ elf: Rohspiel.Elf?, auf mannschaft: Mannschaft) -> Bool {
        let dort = [Namensvergleich.schluessel(elf?.teamName ?? ""),
                    Namensvergleich.schluessel(elf?.shortName ?? "")]
        let hier = [Namensvergleich.schluessel(mannschaft.name),
                    Namensvergleich.schluessel(mannschaft.anzeige)]
        return dort.contains { links in hier.contains { Namensvergleich.gleich(links, $0) } }
    }

    // MARK: Rohdaten

    fileprivate struct Rohspiel: Decodable {
        struct Elf: Decodable {
            let teamName: String?
            let shortName: String?
        }
        struct Treffer: Decodable {
            let goalID: Int?
            let scoreTeam1: Int?
            let scoreTeam2: Int?
            let matchMinute: Int?
            let goalGetterName: String?
            let isPenalty: Bool?
            let isOwnGoal: Bool?
        }
        let matchID: Int?
        let team1: Elf?
        let team2: Elf?
        let goals: [Treffer]?

        /// Rechnet die OpenLigaDB-Treffer in die Tore der App um. Ob ein Tor
        /// für die Heimelf fiel, verrät der Sprung im Spielstand.
        func tore(spielID: Int) -> [Tor] {
            var vorherHeim = 0
            var vorherGast = 0
            var ergebnis: [Tor] = []
            for (platz, treffer) in (goals ?? []).enumerated() {
                let stehtHeim = treffer.scoreTeam1 ?? vorherHeim
                let stehtGast = treffer.scoreTeam2 ?? vorherGast
                let fuerHeim = stehtHeim > vorherHeim
                vorherHeim = stehtHeim
                vorherGast = stehtGast

                var name = treffer.goalGetterName ?? "unbekannt"
                if treffer.isOwnGoal == true { name += " (Eigentor)" }
                else if treffer.isPenalty == true { name += " (Elfmeter)" }

                ergebnis.append(Tor(id: "\(spielID)-olb-\(treffer.goalID ?? platz)",
                                    minute: treffer.matchMinute,
                                    nachspielzeit: nil,
                                    schuetze: name,
                                    fuerHeim: fuerHeim,
                                    standHeim: stehtHeim,
                                    standGast: stehtGast))
            }
            return ergebnis
        }
    }
}

// MARK: - Zwischenspeicher

/// Hält geholte Spieltage kurz fest, damit ein offener Ticker nicht alle
/// 45 Sekunden erneut fragt.
private actor Spieltagsspeicher {
    fileprivate var ablage: [String: (zeit: Date, spiele: [Torschuetzendienst.Rohspiel])] = [:]

    fileprivate func frisch(_ spieltag: Int, saison: Int, abstand: TimeInterval) -> [Torschuetzendienst.Rohspiel]? {
        guard let eintrag = ablage["\(saison)-\(spieltag)"],
              Date().timeIntervalSince(eintrag.zeit) < abstand else { return nil }
        return eintrag.spiele
    }

    fileprivate func ablegen(_ spiele: [Torschuetzendienst.Rohspiel], spieltag: Int, saison: Int) {
        ablage["\(saison)-\(spieltag)"] = (Date(), spiele)
    }
}

// MARK: - Namen zweier Dienste zusammenbringen

/// Zwei Dienste, zwei Schreibweisen: „Borussia Mönchengladbach" hier,
/// „Bor. Mönchengladbach" dort. Verglichen wird deshalb ein vereinfachter
/// Schlüssel — klein, ohne Umlautbesonderheiten, ohne Satzzeichen und ohne
/// die üblichen Kürzel.
enum Namensvergleich {
    private static let beiwerk: Set<String> = [
        "fc", "sv", "sc", "vfb", "vfl", "tsg", "tsv", "bsc", "ssv", "fsv",
        "bor", "borussia", "eintracht", "1899", "1846", "1904", "05", "04", "96", "ii"
    ]

    static func schluessel(_ name: String) -> String {
        let flach = name.folding(options: [.diacriticInsensitive, .caseInsensitive],
                                 locale: Locale(identifier: "de_DE"))
        let zeichen = flach.map { $0.isLetter || $0.isNumber ? $0 : " " }
        return String(zeichen)
            .split(separator: " ")
            .map { $0.lowercased() }
            .filter { !beiwerk.contains($0) }
            .joined(separator: " ")
    }

    /// Gleich ist, was gleich heißt — oder was im anderen steckt. Damit
    /// findet „monchengladbach" auch „monchengladbach 1900" wieder.
    static func gleich(_ links: String, _ rechts: String) -> Bool {
        guard links.count >= 4, rechts.count >= 4 else { return false }
        return links == rechts || links.contains(rechts) || rechts.contains(links)
    }
}
