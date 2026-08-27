import Foundation

/// Holt Torschützen aus **TheSportsDB** — für alle fünf Ligen.
///
/// Damit hat sich meine frühere Auskunft erledigt, es gebe für die vier
/// Ligen außerhalb Deutschlands keine freie Quelle. TheSportsDB führt eine
/// Ereignisliste je Spiel mit Schütze, Vorlage, Minute und Seite, und zwar
/// schon während das Spiel läuft.
///
/// **Die Einschränkung gehört dazu:** Die freie Stufe gibt je Spiel nur die
/// **ersten fünf Ereignisse** heraus — und Karten zählen mit. Fällt das
/// vierte Tor spät, kommt es nicht mehr mit. Deshalb ergänzt dieser Dienst
/// nur Namen zu dem, was der Ticker ohnehin am Spielstand ablesen kann; die
/// Torfolge selbst baut weiter die App.
///
/// Schlüssellos (die Testkennung `123` ist die freie Stufe), 30 Abfragen je
/// Minute — ein eigenes Kontingent, das **nicht** gegen die zehn Abfragen je
/// Minute von football-data.org zählt.
enum Spielereignisdienst {

    static let quellenname = "TheSportsDB"
    private static let basis = URL(string: "https://www.thesportsdb.com/api/v1/json/123/")!

    /// Wie lange ein Tagesplan und eine Zeitleiste gelten.
    private static let planGilt: TimeInterval = 30 * 60
    private static let leisteGilt: TimeInterval = 2 * 60

    private static let ablage = Ereignisspeicher()

    /// Die Kennungen der Ligen bei TheSportsDB.
    private static func kennung(_ liga: Liga) -> String {
        switch liga {
        case .premierLeague: return "4328"
        case .bundesliga: return "4331"
        case .serieA: return "4332"
        case .ligue1: return "4334"
        case .laLiga: return "4335"
        }
    }

    // MARK: Torfolge ergänzen

    /// Ergänzt die Torfolge der übergebenen Spiele, soweit sie fehlt.
    /// Spiele mit vorhandener Torfolge bleiben unberührt.
    static func torfolgeErgaenzen(_ spiele: [Spiel]) async -> [Spiel] {
        let luecken = spiele.filter { $0.tore.isEmpty && $0.hatStand && $0.status != .geplant }
        guard !luecken.isEmpty else { return spiele }

        // Erst die Tagespläne der betroffenen Liga-Tag-Paare holen, dann je
        // Spiel die Zeitleiste. Beides liegt im Zwischenspeicher.
        var kennungen: [Int: String] = [:]
        for spiel in luecken {
            let tag = Zeitformate.tagesschluessel.string(from: spiel.anstoss)
            let plan = await tagesplan(liga: spiel.liga, tag: tag)
            if let treffer = plan.first(where: { passt($0, zu: spiel) }) {
                kennungen[spiel.id] = treffer.idEvent
            }
        }
        guard !kennungen.isEmpty else { return spiele }

        var torfolgen: [Int: [Tor]] = [:]
        for (spielID, kennzeichen) in kennungen {
            guard let spiel = luecken.first(where: { $0.id == spielID }) else { continue }
            let tore = await zeitleiste(kennzeichen, spiel: spiel)
            if !tore.isEmpty { torfolgen[spielID] = tore }
        }
        guard !torfolgen.isEmpty else { return spiele }

        return spiele.map { spiel in
            guard let tore = torfolgen[spiel.id], spiel.tore.isEmpty else { return spiel }
            var ergaenzt = spiel
            ergaenzt.tore = tore
            ergaenzt.torfolgeQuelle = quellenname
            // Was der Deckel abgeschnitten hat, sagt die App auch.
            ergaenzt.torfolgeUnvollstaendig = tore.count < spiel.toreGesamt
            return ergaenzt
        }
    }

    // MARK: Tagesplan

    private static func tagesplan(liga: Liga, tag: String) async -> [Tagesspiel] {
        let marke = "\(liga.rawValue)-\(tag)"
        if let gemerkt = await ablage.plan(marke, gilt: planGilt) { return gemerkt }

        var teile = URLComponents(url: basis.appendingPathComponent("eventsday.php"),
                                  resolvingAgainstBaseURL: false)!
        teile.queryItems = [URLQueryItem(name: "d", value: tag),
                            URLQueryItem(name: "l", value: kennung(liga))]
        guard let url = teile.url,
              let daten = await abrufen(url),
              let antwort = try? JSONDecoder().decode(Tagesantwort.self, from: daten) else {
            return []
        }
        let liste = antwort.events ?? []
        await ablage.planAblegen(liste, marke: marke)
        return liste
    }

    /// Beide Mannschaften müssen passen — ein falsch zugeordneter Torschütze
    /// wäre schlimmer als gar keiner.
    private static func passt(_ eintrag: Tagesspiel, zu spiel: Spiel) -> Bool {
        trifft(eintrag.strHomeTeam, spiel.heim) && trifft(eintrag.strAwayTeam, spiel.gast)
    }

    private static func trifft(_ name: String?, _ mannschaft: Mannschaft) -> Bool {
        let dort = Namensvergleich.schluessel(name ?? "")
        let hier = [Namensvergleich.schluessel(mannschaft.name),
                    Namensvergleich.schluessel(mannschaft.anzeige)]
        return hier.contains { Namensvergleich.gleich(dort, $0) }
    }

    // MARK: Zeitleiste

    private static func zeitleiste(_ kennzeichen: String, spiel: Spiel) async -> [Tor] {
        if let gemerkt = await ablage.leiste(kennzeichen, gilt: leisteGilt) {
            return tore(aus: gemerkt, spiel: spiel)
        }

        var teile = URLComponents(url: basis.appendingPathComponent("lookuptimeline.php"),
                                  resolvingAgainstBaseURL: false)!
        teile.queryItems = [URLQueryItem(name: "id", value: kennzeichen)]
        guard let url = teile.url,
              let daten = await abrufen(url),
              let antwort = try? JSONDecoder().decode(Zeitleistenantwort.self, from: daten) else {
            return []
        }
        let eintraege = antwort.timeline ?? []
        await ablage.leisteAblegen(eintraege, marke: kennzeichen)
        return tore(aus: eintraege, spiel: spiel)
    }

    private static func tore(aus eintraege: [Ereignis], spiel: Spiel) -> [Tor] {
        var standHeim = 0
        var standGast = 0
        var ergebnis: [Tor] = []
        for eintrag in eintraege.sorted(by: { ($0.minute ?? 0) < ($1.minute ?? 0) })
        where (eintrag.strTimeline ?? "").caseInsensitiveCompare("Goal") == .orderedSame {
            let fuerHeim = (eintrag.strHome ?? "").caseInsensitiveCompare("Yes") == .orderedSame
            if fuerHeim { standHeim += 1 } else { standGast += 1 }

            var name = eintrag.strPlayer ?? "unbekannt"
            let art = (eintrag.strTimelineDetail ?? "").lowercased()
            if art.contains("own") { name += " (Eigentor)" }
            else if art.contains("penalty") { name += " (Elfmeter)" }

            ergebnis.append(Tor(id: "\(spiel.id)-tsdb-\(eintrag.idTimeline ?? String(ergebnis.count))",
                                minute: eintrag.minute,
                                nachspielzeit: nil,
                                schuetze: name,
                                fuerHeim: fuerHeim,
                                standHeim: standHeim,
                                standGast: standGast))
        }
        return ergebnis
    }

    // MARK: Transport

    private static func abrufen(_ url: URL) async -> Data? {
        var anfrage = URLRequest(url: url)
        anfrage.timeoutInterval = 15
        anfrage.setValue("Anstoss/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        guard let (daten, antwort) = try? await URLSession.shared.data(for: anfrage),
              let http = antwort as? HTTPURLResponse, http.statusCode == 200 else {
            return nil
        }
        return daten
    }

    // MARK: Rohdaten

    fileprivate struct Tagesantwort: Decodable {
        let events: [Tagesspiel]?
    }

    fileprivate struct Tagesspiel: Decodable {
        let idEvent: String?
        let strHomeTeam: String?
        let strAwayTeam: String?
    }

    fileprivate struct Zeitleistenantwort: Decodable {
        let timeline: [Ereignis]?
    }

    /// TheSportsDB schickt alle Zahlen als Zeichenkette — auch die Minute.
    fileprivate struct Ereignis: Decodable {
        let idTimeline: String?
        let strTimeline: String?
        let strTimelineDetail: String?
        let strHome: String?
        let strPlayer: String?
        let strAssist: String?
        let intTime: String?

        var minute: Int? { intTime.flatMap { Int($0) } }
    }
}

// MARK: - Zwischenspeicher

/// Tagespläne und Zeitleisten kurz festhalten, damit ein offener Ticker
/// nicht alle 45 Sekunden erneut fragt.
private actor Ereignisspeicher {
    private var plaene: [String: (zeit: Date, spiele: [Spielereignisdienst.Tagesspiel])] = [:]
    private var leisten: [String: (zeit: Date, eintraege: [Spielereignisdienst.Ereignis])] = [:]

    fileprivate func plan(_ marke: String, gilt: TimeInterval) -> [Spielereignisdienst.Tagesspiel]? {
        guard let eintrag = plaene[marke], Date().timeIntervalSince(eintrag.zeit) < gilt else { return nil }
        return eintrag.spiele
    }

    fileprivate func planAblegen(_ spiele: [Spielereignisdienst.Tagesspiel], marke: String) {
        plaene[marke] = (Date(), spiele)
    }

    fileprivate func leiste(_ marke: String, gilt: TimeInterval) -> [Spielereignisdienst.Ereignis]? {
        guard let eintrag = leisten[marke], Date().timeIntervalSince(eintrag.zeit) < gilt else { return nil }
        return eintrag.eintraege
    }

    fileprivate func leisteAblegen(_ eintraege: [Spielereignisdienst.Ereignis], marke: String) {
        leisten[marke] = (Date(), eintraege)
    }
}
