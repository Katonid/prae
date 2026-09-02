import Foundation

/// Holt **Aufstellungen** von api-football (API-Sports).
///
/// Warum ein zweiter Zugang? Aufstellungen stehen zwar auf jeder
/// Nachrichtenseite, aber die kaufen ihre Daten ein. Frei zugänglich sind
/// sie nirgends: football-data.org führt sie in den kostenpflichtigen
/// Stufen, OpenLigaDB hat sie gar nicht, TheSportsDB deckelt seine
/// Aufstellungsliste bei fünf Namen — geprüft, dabei kamen fünf Spieler
/// derselben Mannschaft zurück.
///
/// api-football gibt sie im **kostenlosen** Tarif heraus, dafür mit einem
/// eigenen Schlüssel und **100 Abfragen am Tag**. Deshalb ist dieser Dienst
/// durchweg sparsam: Er fragt nur, wenn eine Begegnung geöffnet wird, merkt
/// sich jede Antwort, und er zählt selbst mit, wie viel vom Tageskontingent
/// noch übrig ist.
///
/// Ohne Schlüssel passiert hier gar nichts — die App bleibt dann genau so,
/// wie sie ohne diesen Dienst wäre.
enum Aufstellungsdienst {

    static let quellenname = "api-football"
    private static let basis = URL(string: "https://v3.football.api-sports.io/")!

    /// Der kostenlose Tarif erlaubt 100 Abfragen am Tag. Die App hält sich
    /// selbst zurück, bevor der Dienst abweist.
    static let tagesgrenze = 100
    /// Etwas Luft lassen: Die letzten Abfragen bleiben ungenutzt, damit ein
    /// Zählfehler nicht zu einer Sperre führt.
    private static let sicherheitsabstand = 5

    private static let ablage = Aufstellungsspeicher()

    /// Die Ligakennungen bei api-football. Stimmt eine nicht, greift der
    /// Rückfall weiter unten, der den Tag ohne Ligafilter durchsieht.
    private static func kennung(_ liga: Liga) -> Int {
        switch liga {
        case .premierLeague: return 39
        case .ligue1: return 61
        case .serieA: return 135
        case .laLiga: return 140
        case .bundesliga: return 78
        }
    }

    static var schluesselVorhanden: Bool {
        !Schluesselbund.lesen(.aufstellungen).isEmpty
    }

    // MARK: Abfragen des Tages zählen

    private static let zaehlerSchluessel = "aufstellungenAbfragen"
    private static let zaehlerTagSchluessel = "aufstellungenAbfragenTag"

    /// Wie viele Abfragen heute schon gestellt wurden.
    static var heuteVerbraucht: Int {
        let heute = Zeitformate.tagesschluessel.string(from: Date())
        guard UserDefaults.standard.string(forKey: zaehlerTagSchluessel) == heute else { return 0 }
        return UserDefaults.standard.integer(forKey: zaehlerSchluessel)
    }

    static var heuteUebrig: Int {
        max(tagesgrenze - sicherheitsabstand - heuteVerbraucht, 0)
    }

    private static func mitzaehlen() {
        let heute = Zeitformate.tagesschluessel.string(from: Date())
        let stand = UserDefaults.standard.string(forKey: zaehlerTagSchluessel) == heute
            ? UserDefaults.standard.integer(forKey: zaehlerSchluessel) : 0
        UserDefaults.standard.set(stand + 1, forKey: zaehlerSchluessel)
        UserDefaults.standard.set(heute, forKey: zaehlerTagSchluessel)
    }

    // MARK: Aufstellung zu einer Begegnung

    /// Gibt die Aufstellungen zurück, sobald der Dienst sie führt. Vor dem
    /// Anpfiff ist das üblicherweise etwa eine Stunde vorher.
    static func aufstellung(zu spiel: Spiel) async -> Aufstellungen? {
        let schluessel = Schluesselbund.lesen(.aufstellungen)
        guard !schluessel.isEmpty else { return nil }

        if let gemerkt = await ablage.aufstellung(spiel.id) { return gemerkt }
        guard heuteUebrig > 1 else { return nil }

        guard let begegnung = await begegnungskennung(zu: spiel, schluessel: schluessel) else { return nil }
        guard let gefunden = await abrufen(begegnung, spiel: spiel, schluessel: schluessel) else { return nil }
        await ablage.ablegen(gefunden, spielID: spiel.id, laeuft: spiel.status != .beendet)
        return gefunden
    }

    // MARK: Die Begegnung bei api-football finden

    private static func begegnungskennung(zu spiel: Spiel, schluessel: String) async -> Int? {
        if let gemerkt = await ablage.kennung(spiel.id) { return gemerkt }

        let tag = Zeitformate.tagesschluessel.string(from: spiel.anstoss)
        let jahrgang = saison(zu: spiel.anstoss)

        // Erst mit Ligafilter — das ist die kleine Antwort.
        var gefunden = await suchen(tag: tag,
                                    liga: kennung(spiel.liga),
                                    saison: jahrgang,
                                    spiel: spiel,
                                    schluessel: schluessel)
        // Stimmt die Ligakennung nicht, den ganzen Tag durchsehen. Kostet
        // eine zweite Abfrage, heilt dafür einen falschen Wert von selbst.
        if gefunden == nil {
            gefunden = await suchen(tag: tag,
                                    liga: nil,
                                    saison: nil,
                                    spiel: spiel,
                                    schluessel: schluessel)
        }
        if let gefunden { await ablage.kennungAblegen(gefunden, spielID: spiel.id) }
        return gefunden
    }

    private static func suchen(tag: String,
                               liga: Int?,
                               saison: Int?,
                               spiel: Spiel,
                               schluessel: String) async -> Int? {
        var teile = URLComponents(url: basis.appendingPathComponent("fixtures"),
                                  resolvingAgainstBaseURL: false)!
        var abfrage = [URLQueryItem(name: "date", value: tag)]
        if let liga { abfrage.append(URLQueryItem(name: "league", value: String(liga))) }
        if let saison { abfrage.append(URLQueryItem(name: "season", value: String(saison))) }
        teile.queryItems = abfrage

        guard let url = teile.url,
              let daten = await holen(url, schluessel: schluessel),
              let antwort = try? JSONDecoder().decode(Begegnungsantwort.self, from: daten) else {
            return nil
        }
        return antwort.response
            .first { eintrag in
                trifft(eintrag.teams?.home?.name, spiel.heim) && trifft(eintrag.teams?.away?.name, spiel.gast)
            }?
            .fixture?.id
    }

    private static func trifft(_ name: String?, _ mannschaft: Mannschaft) -> Bool {
        let dort = Namensvergleich.schluessel(name ?? "")
        let hier = [Namensvergleich.schluessel(mannschaft.name),
                    Namensvergleich.schluessel(mannschaft.anzeige)]
        return hier.contains { Namensvergleich.gleich(dort, $0) }
    }

    /// Eine Saison zählt nach dem Jahr ihres Beginns; die Rückrunde im
    /// Frühjahr gehört noch zum Vorjahr.
    private static func saison(zu datum: Date) -> Int {
        let teile = Calendar.current.dateComponents([.year, .month], from: datum)
        let jahr = teile.year ?? 2026
        return (teile.month ?? 8) >= 7 ? jahr : jahr - 1
    }

    // MARK: Die Aufstellung selbst

    private static func abrufen(_ begegnung: Int, spiel: Spiel, schluessel: String) async -> Aufstellungen? {
        var teile = URLComponents(url: basis.appendingPathComponent("fixtures/lineups"),
                                  resolvingAgainstBaseURL: false)!
        teile.queryItems = [URLQueryItem(name: "fixture", value: String(begegnung))]

        guard let url = teile.url,
              let daten = await holen(url, schluessel: schluessel),
              let antwort = try? JSONDecoder().decode(Aufstellungsantwort.self, from: daten),
              !antwort.response.isEmpty else {
            return nil
        }

        let heim = antwort.response.first { trifft($0.team?.name, spiel.heim) } ?? antwort.response.first
        let gast = antwort.response.first { trifft($0.team?.name, spiel.gast) }
            ?? antwort.response.first { $0.team?.id != heim?.team?.id }

        guard let heim, let gast, heim.hatInhalt || gast.hatInhalt else { return nil }
        return Aufstellungen(heim: heim.aufstellung(), gast: gast.aufstellung())
    }

    // MARK: Transport

    private static func holen(_ url: URL, schluessel: String) async -> Data? {
        guard heuteUebrig > 0 else { return nil }
        var anfrage = URLRequest(url: url)
        anfrage.timeoutInterval = 20
        anfrage.setValue(schluessel, forHTTPHeaderField: "x-apisports-key")
        anfrage.setValue("Anstoss/1.0 (iOS)", forHTTPHeaderField: "User-Agent")

        mitzaehlen()
        guard let (daten, antwort) = try? await URLSession.shared.data(for: anfrage),
              let http = antwort as? HTTPURLResponse, http.statusCode == 200 else {
            return nil
        }
        return daten
    }

    // MARK: Rohdaten

    private struct Begegnungsantwort: Decodable {
        struct Eintrag: Decodable {
            struct Kennung: Decodable { let id: Int? }
            struct Seiten: Decodable {
                struct Elf: Decodable {
                    let id: Int?
                    let name: String?
                }
                let home: Elf?
                let away: Elf?
            }
            let fixture: Kennung?
            let teams: Seiten?
        }
        let response: [Eintrag]
    }

    private struct Aufstellungsantwort: Decodable {
        struct Eintrag: Decodable {
            struct Elf: Decodable {
                let id: Int?
                let name: String?
            }
            struct Verantwortlicher: Decodable { let name: String? }
            struct Posten: Decodable {
                struct Spieler: Decodable {
                    let name: String?
                    let number: Int?
                    let pos: String?
                }
                let player: Spieler?
            }
            let team: Elf?
            let formation: String?
            let coach: Verantwortlicher?
            let startXI: [Posten]?
            let substitutes: [Posten]?

            var hatInhalt: Bool { !(startXI ?? []).isEmpty }

            func aufstellung() -> Aufstellung {
                Aufstellung(mannschaft: team?.name ?? "",
                            formation: formation,
                            trainer: coach?.name,
                            startelf: (startXI ?? []).compactMap { posten($0) },
                            bank: (substitutes ?? []).compactMap { posten($0) })
            }

            private func posten(_ eintrag: Posten) -> Spielerposten? {
                guard let name = eintrag.player?.name, !name.isEmpty else { return nil }
                return Spielerposten(name: name,
                                     nummer: eintrag.player?.number,
                                     position: eintrag.player?.pos)
            }
        }
        let response: [Eintrag]
    }
}

// MARK: - Zwischenspeicher

/// Aufstellungen ändern sich vor dem Anpfiff noch, danach nicht mehr.
/// Deshalb gilt ein laufendes Spiel kürzer als ein abgeschlossenes.
private actor Aufstellungsspeicher {
    private var kennungen: [Int: Int] = [:]
    private var aufstellungen: [Int: (zeit: Date, gilt: TimeInterval, inhalt: Aufstellungen)] = [:]

    func kennung(_ spielID: Int) -> Int? { kennungen[spielID] }

    func kennungAblegen(_ kennung: Int, spielID: Int) { kennungen[spielID] = kennung }

    func aufstellung(_ spielID: Int) -> Aufstellungen? {
        guard let eintrag = aufstellungen[spielID],
              Date().timeIntervalSince(eintrag.zeit) < eintrag.gilt else { return nil }
        return eintrag.inhalt
    }

    func ablegen(_ inhalt: Aufstellungen, spielID: Int, laeuft: Bool) {
        aufstellungen[spielID] = (Date(), laeuft ? 15 * 60 : 24 * 60 * 60, inhalt)
    }
}
