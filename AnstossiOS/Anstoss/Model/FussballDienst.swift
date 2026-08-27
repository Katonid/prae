import Foundation

/// Fehler, die die App dem Nutzer im Klartext zeigen kann.
enum DienstFehler: LocalizedError, Equatable {
    case keinSchluessel
    case schluesselAbgelehnt
    case limitErreicht
    case nichtGefunden
    case serverfehler(Int)
    case netz(String)
    case antwortUnleserlich

    var errorDescription: String? {
        switch self {
        case .keinSchluessel:
            return "Es ist noch kein Zugangsschlüssel hinterlegt."
        case .schluesselAbgelehnt:
            return "Der Zugangsschlüssel wurde abgelehnt. Bitte in den Einstellungen prüfen."
        case .limitErreicht:
            return "Der freie Zugang erlaubt nur zehn Abfragen je Minute. Gleich geht es weiter."
        case .nichtGefunden:
            return "Zu dieser Anfrage liegen keine Daten vor."
        case .serverfehler(let code):
            return "Der Dienst antwortet mit Fehler \(code)."
        case .netz(let text):
            return "Keine Verbindung: \(text)"
        case .antwortUnleserlich:
            return "Die Antwort des Dienstes war nicht lesbar."
        }
    }
}

/// Der freie Zugang von football-data.org erlaubt zehn Anfragen je Minute.
/// Diese Bremse hält das ein, statt sich auf Fehler 429 zu verlassen.
actor Anfragenbremse {
    private let grenze: Int
    private let fenster: TimeInterval = 60
    private var zeitpunkte: [Date] = []

    init(grenze: Int = 9) {
        self.grenze = grenze
    }

    func anstellen() async {
        while true {
            let jetzt = Date()
            zeitpunkte.removeAll { jetzt.timeIntervalSince($0) > fenster }
            if zeitpunkte.count < grenze {
                zeitpunkte.append(jetzt)
                return
            }
            let aeltester = zeitpunkte[0]
            let warten = fenster - jetzt.timeIntervalSince(aeltester) + 0.25
            try? await Task.sleep(nanoseconds: UInt64(max(warten, 0.25) * 1_000_000_000))
        }
    }
}

/// Zugriff auf football-data.org (Fassung v4). Der Dienst ist im freien
/// Zugang auf die fünf großen Ligen zugeschnitten — genau das, was diese
/// App braucht.
struct FussballDienst {
    let schluessel: String
    private static let bremse = Anfragenbremse()
    private static let basis = URL(string: "https://api.football-data.org/v4/")!

    // MARK: Abfragen

    /// Alle Spiele eines Spieltags. Ohne Spieltag liefert der Dienst den
    /// laufenden.
    func spiele(liga: Liga, spieltag: Int?) async throws -> [Spiel] {
        var teile = URLComponents(url: Self.basis.appendingPathComponent("competitions/\(liga.rawValue)/matches"),
                                  resolvingAgainstBaseURL: false)!
        if let spieltag {
            teile.queryItems = [URLQueryItem(name: "matchday", value: String(spieltag))]
        }
        let antwort: SpieleAntwort = try await holen(teile.url!)
        return antwort.matches.compactMap { $0.spiel(fallback: liga) }
    }

    /// Die Tabelle samt aktuellem Spieltag.
    func tabelle(liga: Liga) async throws -> Tabelle {
        let url = Self.basis.appendingPathComponent("competitions/\(liga.rawValue)/standings")
        let antwort: TabellenAntwort = try await holen(url)
        let gesamt = antwort.standings.first { $0.type == "TOTAL" } ?? antwort.standings.first
        let zeilen = (gesamt?.table ?? []).map { $0.zeile() }
        // Dieselbe Antwort trägt meist noch eine Heim- und eine
        // Auswärtstabelle. Kostenlos mitgenommen, was da ist.
        let daheim = (antwort.standings.first { $0.type == "HOME" }?.table ?? []).map { $0.zeile() }
        let auswaerts = (antwort.standings.first { $0.type == "AWAY" }?.table ?? []).map { $0.zeile() }
        return Tabelle(liga: liga,
                       spieltag: antwort.season?.currentMatchday ?? 1,
                       zeilen: zeilen,
                       stand: Date(),
                       heimzeilen: daheim,
                       auswaertszeilen: auswaerts)
    }

    /// Alle heutigen Spiele der fünf Ligen in einer einzigen Anfrage —
    /// das ist die Grundlage des Livetickers.
    func spieleHeute() async throws -> [Spiel] {
        // Der Dienst rechnet in UTC, die App im Kalender des Nutzers. Ein
        // Fenster von gestern bis morgen deckt beides ab; ausgesiebt wird
        // danach hier.
        let kalender = Calendar.current
        let gestern = kalender.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let morgen = kalender.date(byAdding: .day, value: 1, to: Date()) ?? Date()

        var teile = URLComponents(url: Self.basis.appendingPathComponent("matches"),
                                  resolvingAgainstBaseURL: false)!
        teile.queryItems = [
            URLQueryItem(name: "competitions", value: Liga.allCases.map(\.rawValue).joined(separator: ",")),
            URLQueryItem(name: "dateFrom", value: Zeitformate.tagesschluessel.string(from: gestern)),
            URLQueryItem(name: "dateTo", value: Zeitformate.tagesschluessel.string(from: morgen)),
        ]
        let antwort: SpieleAntwort = try await holen(teile.url!)
        return antwort.matches
            .compactMap { $0.spiel(fallback: nil) }
            .filter { $0.istHeute || $0.status.laeuftGerade }
    }

    /// Ein einzelnes Spiel mit Torschützen, soweit der Zugang sie hergibt.
    /// Der Dienst liefert das Spiel je nach Fassung entweder unmittelbar
    /// oder in eine Hülle gepackt — beides wird versucht.
    func spiel(id: Int) async throws -> Spiel? {
        let url = Self.basis.appendingPathComponent("matches/\(id)")
        let daten = try await rohdaten(url)
        if let roh = try? JSONDecoder().decode(RohSpiel.self, from: daten), roh.id != nil {
            return roh.spiel(fallback: nil)
        }
        if let huelle = try? JSONDecoder().decode(EinzelspielAntwort.self, from: daten) {
            return huelle.match?.spiel(fallback: nil)
        }
        throw DienstFehler.antwortUnleserlich
    }

    /// Der direkte Vergleich zweier Mannschaften.
    ///
    /// Eine **eigene** Unterabfrage: `head2head` liegt nicht in der Antwort
    /// zum Spiel. Sie wird nur beim Öffnen einer einzelnen Begegnung
    /// gestellt. Antwortet der Dienst nicht oder deckt der freie Zugang sie
    /// nicht, gibt es eben keinen Vergleich — deshalb wirft sie nicht.
    func vergleich(spielID: Int, heimID: Int) async -> Vergleich? {
        var teile = URLComponents(url: Self.basis.appendingPathComponent("matches/\(spielID)/head2head"),
                                  resolvingAgainstBaseURL: false)!
        teile.queryItems = [URLQueryItem(name: "limit", value: "10")]
        guard let url = teile.url,
              let daten = try? await rohdaten(url),
              let antwort = try? JSONDecoder().decode(VergleichsAntwort.self, from: daten) else {
            return nil
        }
        return antwort.vergleich(heimID: heimID)
    }

    /// Die Torjägerliste einer Liga. Der freie Zugang gibt sie her — und
    /// sie ist das Einzige an Spielerdaten, das er hergibt.
    func torjaeger(liga: Liga, anzahl: Int = 25) async throws -> [Torjaeger] {
        var teile = URLComponents(url: Self.basis.appendingPathComponent("competitions/\(liga.rawValue)/scorers"),
                                  resolvingAgainstBaseURL: false)!
        teile.queryItems = [URLQueryItem(name: "limit", value: String(anzahl))]
        let antwort: TorjaegerAntwort = try await holen(teile.url!)
        return antwort.scorers.enumerated().compactMap { platz, roh in roh.torjaeger(platz: platz + 1) }
    }

    /// Der Spieltag, der gerade läuft.
    func laufenderSpieltag(liga: Liga) async throws -> Int {
        let url = Self.basis.appendingPathComponent("competitions/\(liga.rawValue)")
        let antwort: WettbewerbAntwort = try await holen(url)
        return antwort.currentSeason?.currentMatchday ?? 1
    }

    // MARK: Transport

    private func holen<T: Decodable>(_ url: URL) async throws -> T {
        let daten = try await rohdaten(url)
        do {
            return try JSONDecoder().decode(T.self, from: daten)
        } catch {
            throw DienstFehler.antwortUnleserlich
        }
    }

    private func rohdaten(_ url: URL) async throws -> Data {
        guard !schluessel.isEmpty else { throw DienstFehler.keinSchluessel }
        await Self.bremse.anstellen()

        var anfrage = URLRequest(url: url)
        anfrage.setValue(schluessel, forHTTPHeaderField: "X-Auth-Token")
        anfrage.timeoutInterval = 20
        anfrage.cachePolicy = .reloadIgnoringLocalCacheData

        let daten: Data
        let antwort: URLResponse
        do {
            (daten, antwort) = try await URLSession.shared.data(for: anfrage)
        } catch {
            throw DienstFehler.netz(error.localizedDescription)
        }

        if let http = antwort as? HTTPURLResponse {
            switch http.statusCode {
            case 200 ..< 300: break
            case 400, 403: throw DienstFehler.schluesselAbgelehnt
            case 401: throw DienstFehler.schluesselAbgelehnt
            case 404: throw DienstFehler.nichtGefunden
            case 429: throw DienstFehler.limitErreicht
            default: throw DienstFehler.serverfehler(http.statusCode)
            }
        }
        return daten
    }
}

// MARK: - Rohgestalt der Antworten

private struct SpieleAntwort: Decodable {
    let matches: [RohSpiel]
}

private struct EinzelspielAntwort: Decodable {
    let match: RohSpiel?
}

private struct WettbewerbAntwort: Decodable {
    struct Saison: Decodable { let currentMatchday: Int? }
    let currentSeason: Saison?
}

private struct TabellenAntwort: Decodable {
    struct Saison: Decodable { let currentMatchday: Int? }
    struct Gruppe: Decodable {
        let type: String?
        let table: [RohTabellenzeile]?
    }
    let season: Saison?
    let standings: [Gruppe]
}

/// Antwort auf `/matches/{id}/head2head`. Der Dienst legt die Zahlen unter
/// `aggregates` ab, die Einzelspiele daneben — gebraucht werden hier nur die
/// Zahlen.
private struct VergleichsAntwort: Decodable {
    struct Zahlen: Decodable {
        struct Seite: Decodable {
            let id: Int?
            let wins: Int?
            let draws: Int?
            let losses: Int?
        }
        let numberOfMatches: Int?
        let totalGoals: Int?
        let homeTeam: Seite?
        let awayTeam: Seite?
    }
    let aggregates: Zahlen?
    let matches: [RohSpiel]?

    /// Gerechnet wird aus den mitgelieferten Einzelspielen, nicht aus
    /// `aggregates`: Dessen Sieg- und Remiszahlen gingen in 1.0.8 nicht auf
    /// (10 Begegnungen, aber 0 + 2 + 0). Die Einzelspiele stimmen immer,
    /// weil sie den Spielstand mitbringen. Nur wenn sie fehlen, wird auf
    /// `aggregates` zurückgefallen — und dann geprüft, ob es aufgeht.
    func vergleich(heimID: Int) -> Vergleich? {
        if let gerechnet = ausSpielen(heimID: heimID) { return gerechnet }
        guard let zahlen = aggregates, let anzahl = zahlen.numberOfMatches, anzahl > 0 else { return nil }
        let siegeHeim = zahlen.homeTeam?.wins ?? 0
        let siegeGast = zahlen.awayTeam?.wins ?? 0
        let remis = zahlen.homeTeam?.draws ?? 0
        guard siegeHeim + siegeGast + remis == anzahl else { return nil }
        return Vergleich(spiele: anzahl,
                         siegeHeim: siegeHeim,
                         siegeGast: siegeGast,
                         unentschieden: remis,
                         toreGesamt: zahlen.totalGoals ?? 0)
    }

    private func ausSpielen(heimID: Int) -> Vergleich? {
        let gespielt = (matches ?? []).filter { $0.hatEndstand }
        guard !gespielt.isEmpty else { return nil }

        var siegeHeim = 0, siegeGast = 0, remis = 0, tore = 0
        for partie in gespielt {
            guard let daheim = partie.toreDaheim, let auswaerts = partie.toreAuswaerts else { continue }
            tore += daheim + auswaerts
            // Wer damals daheim spielte, wechselt von Begegnung zu Begegnung —
            // gezaehlt wird deshalb je Mannschaft, nicht je Platz.
            let heimSpielteDaheim = partie.homeTeamID == heimID
            if daheim == auswaerts {
                remis += 1
            } else if (daheim > auswaerts) == heimSpielteDaheim {
                siegeHeim += 1
            } else {
                siegeGast += 1
            }
        }
        guard siegeHeim + siegeGast + remis > 0 else { return nil }
        return Vergleich(spiele: siegeHeim + siegeGast + remis,
                         siegeHeim: siegeHeim,
                         siegeGast: siegeGast,
                         unentschieden: remis,
                         toreGesamt: tore)
    }
}

private struct TorjaegerAntwort: Decodable {
    struct Eintrag: Decodable {
        struct Person: Decodable {
            let id: Int?
            let name: String?
            let nationality: String?
            let position: String?
        }
        let player: Person?
        let team: RohMannschaft?
        let goals: Int?
        let assists: Int?
        let penalties: Int?
        let playedMatches: Int?

        func torjaeger(platz: Int) -> Torjaeger? {
            guard let name = player?.name, let tore = goals else { return nil }
            return Torjaeger(id: player?.id ?? platz,
                             platz: platz,
                             name: name,
                             mannschaft: team?.mannschaft(),
                             tore: tore,
                             vorlagen: assists,
                             elfmeter: penalties,
                             spiele: playedMatches)
        }
    }
    let scorers: [Eintrag]
}

private struct RohMannschaft: Decodable {
    let id: Int?
    let name: String?
    let shortName: String?
    let tla: String?
    let crest: String?

    func mannschaft() -> Mannschaft {
        Mannschaft(id: id ?? 0,
                   name: name ?? "Unbekannt",
                   kurzname: shortName ?? name ?? "Unbekannt",
                   kuerzel: tla ?? "",
                   wappen: crest.flatMap { URL(string: $0) })
    }
}

private struct RohTabellenzeile: Decodable {
    let position: Int?
    let team: RohMannschaft?
    let playedGames: Int?
    let form: String?
    let won: Int?
    let draw: Int?
    let lost: Int?
    let points: Int?
    let goalsFor: Int?
    let goalsAgainst: Int?
    let goalDifference: Int?

    func zeile() -> Tabellenzeile {
        let fuer = goalsFor ?? 0
        let gegen = goalsAgainst ?? 0
        let zeichen = (form ?? "")
            .split(whereSeparator: { $0 == "," || $0 == " " })
            .map { teil -> String in
                switch teil.uppercased() {
                case "W": return "S"
                case "D": return "U"
                case "L": return "N"
                default: return String(teil)
                }
            }
        return Tabellenzeile(platz: position ?? 0,
                             mannschaft: (team ?? RohMannschaft(id: nil, name: nil, shortName: nil, tla: nil, crest: nil)).mannschaft(),
                             spiele: playedGames ?? 0,
                             siege: won ?? 0,
                             unentschieden: draw ?? 0,
                             niederlagen: lost ?? 0,
                             toreFuer: fuer,
                             toreGegen: gegen,
                             tordifferenz: goalDifference ?? (fuer - gegen),
                             punkte: points ?? 0,
                             form: zeichen)
    }
}

private struct RohSpiel: Decodable {
    struct Wettbewerb: Decodable { let code: String? }
    struct Ergebnis: Decodable {
        struct Stand: Decodable {
            let home: Int?
            let away: Int?
        }
        let fullTime: Stand?
        let halfTime: Stand?
    }
    struct RohSchiedsrichter: Decodable {
        let name: String?
        let type: String?
    }
    struct RohTor: Decodable {
        struct Spieler: Decodable { let name: String? }
        struct Stand: Decodable {
            let home: Int?
            let away: Int?
        }
        let minute: Int?
        let injuryTime: Int?
        let type: String?
        let team: RohMannschaft?
        let scorer: Spieler?
        let score: Stand?
    }

    let id: Int?
    let utcDate: String?
    let status: String?
    let matchday: Int?
    let minute: Int?
    let competition: Wettbewerb?
    let homeTeam: RohMannschaft?
    let awayTeam: RohMannschaft?
    let score: Ergebnis?
    let goals: [RohTor]?
    let venue: String?
    let referees: [RohSchiedsrichter]?

    var homeTeamID: Int? { homeTeam?.id }
    var toreDaheim: Int? { score?.fullTime?.home }
    var toreAuswaerts: Int? { score?.fullTime?.away }
    var hatEndstand: Bool { toreDaheim != nil && toreAuswaerts != nil }

    func spiel(fallback: Liga?) -> Spiel? {
        guard let id,
              let heim = homeTeam?.mannschaft(),
              let gast = awayTeam?.mannschaft() else { return nil }
        let code: String? = competition?.code
        let erkannt: Liga? = code.flatMap { Liga(rawValue: $0) }
        guard let liga: Liga = erkannt ?? fallback else { return nil }
        let datum = utcDate.flatMap { Zeitformate.datum(aus: $0) } ?? Date()

        let torliste: [Tor] = (goals ?? []).enumerated().map { platz, roh in
            let heimTor = roh.team?.id == heim.id
            return Tor(id: "\(id)-\(platz)",
                       minute: roh.minute,
                       nachspielzeit: roh.injuryTime,
                       schuetze: roh.scorer?.name ?? "unbekannt",
                       fuerHeim: heimTor,
                       standHeim: roh.score?.home,
                       standGast: roh.score?.away)
        }

        // Der Dienst schickt das ganze Gespann; auf dem Bildschirm steht nur
        // der Unparteiische selbst.
        let hauptschiedsrichter: String? = (referees ?? [])
            .first { ($0.type ?? "").uppercased().contains("REFEREE") && !($0.type ?? "").uppercased().contains("ASSISTANT") }?
            .name ?? (referees ?? []).first?.name

        return Spiel(id: id,
                     liga: liga,
                     spieltag: matchday ?? 0,
                     anstoss: datum,
                     status: Spielstatus(rohwert: status ?? ""),
                     minute: minute,
                     heim: heim,
                     gast: gast,
                     toreHeim: score?.fullTime?.home,
                     toreGast: score?.fullTime?.away,
                     halbzeitHeim: score?.halfTime?.home,
                     halbzeitGast: score?.halfTime?.away,
                     tore: torliste,
                     spielort: venue?.trimmingCharacters(in: .whitespacesAndNewlines),
                     schiedsrichter: hauptschiedsrichter)
    }
}
