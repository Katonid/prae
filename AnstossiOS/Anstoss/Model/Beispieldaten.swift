import Foundation

/// Erfundene, aber in sich stimmige Daten. Damit lässt sich die App
/// ansehen und bedienen, bevor ein Zugangsschlüssel eingetragen ist —
/// klar gekennzeichnet, damit niemand sie für echte Ergebnisse hält.
enum Beispieldaten {

    // MARK: Mannschaften

    static func mannschaften(_ liga: Liga) -> [Mannschaft] {
        namen(liga).enumerated().map { platz, name in
            Mannschaft(id: liga.kennzahl * 1000 + platz,
                       name: name,
                       kurzname: kurz(name),
                       kuerzel: kuerzel(name),
                       wappen: nil)
        }
    }

    private static func namen(_ liga: Liga) -> [String] {
        switch liga {
        case .bundesliga:
            return ["Bayern München", "Bayer Leverkusen", "VfB Stuttgart", "RB Leipzig",
                    "Borussia Dortmund", "Eintracht Frankfurt", "TSG Hoffenheim", "1. FC Heidenheim",
                    "SV Werder Bremen", "SC Freiburg", "FC Augsburg", "VfL Wolfsburg",
                    "1. FSV Mainz 05", "Bor. Mönchengladbach", "1. FC Union Berlin", "VfL Bochum",
                    "FC St. Pauli", "Holstein Kiel"]
        case .premierLeague:
            return ["Manchester City", "Arsenal", "Liverpool", "Aston Villa",
                    "Tottenham Hotspur", "Chelsea", "Newcastle United", "Manchester United",
                    "West Ham United", "Crystal Palace", "Brighton", "Bournemouth",
                    "Fulham", "Wolverhampton", "Everton", "Brentford",
                    "Nottingham Forest", "Leicester City", "Ipswich Town", "Southampton"]
        case .laLiga:
            return ["Real Madrid", "FC Barcelona", "Girona FC", "Atlético Madrid",
                    "Athletic Bilbao", "Real Sociedad", "Real Betis", "FC Villarreal",
                    "FC Valencia", "Deportivo Alavés", "CA Osasuna", "FC Getafe",
                    "Celta Vigo", "FC Sevilla", "RCD Mallorca", "UD Las Palmas",
                    "Rayo Vallecano", "Espanyol Barcelona", "CD Leganés", "Real Valladolid"]
        case .serieA:
            return ["Inter Mailand", "AC Mailand", "Juventus Turin", "Atalanta Bergamo",
                    "AS Rom", "Lazio Rom", "SSC Neapel", "AC Florenz",
                    "FC Turin", "FC Bologna", "Udinese Calcio", "CFC Genua",
                    "US Lecce", "Hellas Verona", "Cagliari Calcio", "FC Empoli",
                    "Parma Calcio", "Como 1907", "AC Venedig", "AC Monza"]
        case .ligue1:
            return ["Paris Saint-Germain", "AS Monaco", "Stade Brest", "LOSC Lille",
                    "OGC Nizza", "Olympique Lyon", "RC Lens", "Olympique Marseille",
                    "Stade Reims", "Stade Rennes", "FC Toulouse", "HSC Montpellier",
                    "RC Straßburg", "FC Nantes", "AJ Auxerre", "Le Havre AC",
                    "AS Saint-Étienne", "Angers SCO"]
        }
    }

    private static func kurz(_ name: String) -> String {
        name.count <= 16 ? name : String(name.prefix(15)) + "."
    }

    private static func kuerzel(_ name: String) -> String {
        let woerter = name.split(separator: " ").filter { $0.count > 2 && !$0.hasPrefix("1.") }
        if let letztes = woerter.last, letztes.count >= 3 {
            return String(letztes.prefix(3)).uppercased()
        }
        return String(name.prefix(3)).uppercased()
    }

    // MARK: Zufall mit fester Folge

    /// Immer dieselbe Zahl für dieselbe Frage — die Beispieldaten sollen
    /// sich beim Blättern nicht verändern.
    private static func wuerfel(_ teile: Int...) -> Int {
        var wert = 2166136261
        for teil in teile {
            wert = (wert ^ teil) &* 16777619
            wert &= 0x7FFF_FFFF
        }
        return wert
    }

    // MARK: Spielplan

    /// Kreisverfahren: Mannschaft 0 bleibt stehen, die übrigen rotieren.
    /// So entsteht ein vollständiger, doppelfreier Spielplan.
    static func paarungen(_ liga: Liga, spieltag: Int) -> [(heim: Int, gast: Int)] {
        let anzahl = namen(liga).count
        let runden = anzahl - 1
        let runde = (max(spieltag, 1) - 1) % runden
        let rueckrunde = ((max(spieltag, 1) - 1) / runden) % 2 == 1

        var reihe = Array(1 ..< anzahl)
        for _ in 0 ..< runde { reihe.insert(reihe.removeLast(), at: 0) }
        let voll = [0] + reihe

        var liste: [(heim: Int, gast: Int)] = []
        for i in 0 ..< anzahl / 2 {
            let a = voll[i]
            let b = voll[anzahl - 1 - i]
            let heimZuerst = (i + runde) % 2 == 0
            var heim = heimZuerst ? a : b
            var gast = heimZuerst ? b : a
            if rueckrunde { swap(&heim, &gast) }
            liste.append((heim: heim, gast: gast))
        }
        return liste
    }

    static func spiele(liga: Liga, spieltag: Int) -> [Spiel] {
        let elf = mannschaften(liga)
        let heutigerSpieltag = laufenderSpieltag(liga)
        var start = anstosszeiten(liga: liga, spieltag: spieltag, gegenwart: heutigerSpieltag)
        if start.isEmpty { start = [Date()] }

        return paarungen(liga, spieltag: spieltag).enumerated().map { platz, paar in
            let heim = elf[paar.heim]
            let gast = elf[paar.gast]
            let staerkeHeim = max(0, elf.count - paar.heim)
            let staerkeGast = max(0, elf.count - paar.gast)
            let toreHeim = tore(wuerfel(liga.kennzahl, spieltag, platz, 1), staerke: staerkeHeim + 3, gegner: staerkeGast)
            let toreGast = tore(wuerfel(liga.kennzahl, spieltag, platz, 2), staerke: staerkeGast, gegner: staerkeHeim + 3)

            let zustand: Spielstatus
            var minute: Int?
            if spieltag < heutigerSpieltag {
                zustand = .beendet
            } else if spieltag > heutigerSpieltag {
                zustand = .geplant
            } else {
                switch platz % 4 {
                case 0: zustand = .beendet
                case 1: zustand = .laeuft; minute = 20 + (platz * 7) % 55
                case 2: zustand = .pause
                default: zustand = .geplant
                }
            }

            let sichtbarHeim = zustand == .geplant ? nil : toreHeim
            let sichtbarGast = zustand == .geplant ? nil : toreGast
            let torliste = zustand == .geplant ? [] : torfolge(spielID: platz,
                                                              liga: liga,
                                                              spieltag: spieltag,
                                                              heim: heim,
                                                              gast: gast,
                                                              toreHeim: toreHeim,
                                                              toreGast: toreGast)

            return Spiel(id: wuerfel(liga.kennzahl, spieltag, platz, 9),
                         liga: liga,
                         spieltag: spieltag,
                         anstoss: start[platz % start.count],
                         status: zustand,
                         minute: minute,
                         heim: heim,
                         gast: gast,
                         toreHeim: sichtbarHeim,
                         toreGast: sichtbarGast,
                         halbzeitHeim: zustand == .geplant ? nil : max(0, toreHeim - toreHeim / 2),
                         halbzeitGast: zustand == .geplant ? nil : toreGast / 2,
                         tore: torliste)
        }
    }

    private static func tore(_ zufall: Int, staerke: Int, gegner: Int) -> Int {
        let unterschied = staerke - gegner
        let grund = zufall % 100
        let bonus = max(-25, min(25, unterschied * 2))
        let wert = grund + bonus
        switch wert {
        case ..<28: return 0
        case ..<62: return 1
        case ..<85: return 2
        case ..<96: return 3
        default: return 4
        }
    }

    private static func torfolge(spielID: Int, liga: Liga, spieltag: Int,
                                 heim: Mannschaft, gast: Mannschaft,
                                 toreHeim: Int, toreGast: Int) -> [Tor] {
        var roh: [(minute: Int, heim: Bool)] = []
        for i in 0 ..< toreHeim {
            roh.append((minute: 3 + wuerfel(liga.kennzahl, spieltag, spielID, i, 11) % 88, heim: true))
        }
        for i in 0 ..< toreGast {
            roh.append((minute: 3 + wuerfel(liga.kennzahl, spieltag, spielID, i, 22) % 88, heim: false))
        }
        roh.sort { $0.minute < $1.minute }

        var standHeim = 0
        var standGast = 0
        return roh.enumerated().map { platz, eintrag in
            if eintrag.heim { standHeim += 1 } else { standGast += 1 }
            let elf = eintrag.heim ? heim : gast
            return Tor(id: "\(spielID)-\(platz)",
                       minute: eintrag.minute,
                       nachspielzeit: nil,
                       schuetze: "\(elf.zeichen)-Spieler \(platz + 7)",
                       fuerHeim: eintrag.heim,
                       standHeim: standHeim,
                       standGast: standGast)
        }
    }

    private static func anstosszeiten(liga: Liga, spieltag: Int, gegenwart: Int) -> [Date] {
        let kalender = Calendar.current
        let versatz = (spieltag - gegenwart) * 7
        let tag = kalender.date(byAdding: .day, value: versatz, to: Date()) ?? Date()
        return [13, 15, 17, 19].compactMap {
            kalender.date(bySettingHour: $0, minute: 30, second: 0, of: tag)
        }
    }

    // MARK: Spieltag und Tabelle

    /// Ein fester, plausibler Spieltag — die Beispieldaten hängen nicht am
    /// echten Kalender.
    static func laufenderSpieltag(_ liga: Liga) -> Int {
        switch liga {
        case .bundesliga: return 12
        case .premierLeague: return 14
        case .laLiga: return 13
        case .serieA: return 13
        case .ligue1: return 12
        }
    }

    static func tabelle(_ liga: Liga) -> Tabelle {
        let elf = mannschaften(liga)
        var punkte = [Int: Int]()
        var spiele = [Int: Int]()
        var siege = [Int: Int]()
        var remis = [Int: Int]()
        var pleiten = [Int: Int]()
        var fuer = [Int: Int]()
        var gegen = [Int: Int]()
        var form = [Int: [String]]()

        let bisher = laufenderSpieltag(liga)
        for tag in 1 ... max(bisher - 1, 1) {
            for spiel in Beispieldaten.spiele(liga: liga, spieltag: tag) {
                guard let toreHeim = spiel.toreHeim, let toreGast = spiel.toreGast else { continue }
                let h = spiel.heim.id
                let g = spiel.gast.id
                spiele[h, default: 0] += 1
                spiele[g, default: 0] += 1
                fuer[h, default: 0] += toreHeim
                fuer[g, default: 0] += toreGast
                gegen[h, default: 0] += toreGast
                gegen[g, default: 0] += toreHeim
                if toreHeim > toreGast {
                    punkte[h, default: 0] += 3
                    siege[h, default: 0] += 1
                    pleiten[g, default: 0] += 1
                    form[h, default: []].append("S")
                    form[g, default: []].append("N")
                } else if toreHeim < toreGast {
                    punkte[g, default: 0] += 3
                    siege[g, default: 0] += 1
                    pleiten[h, default: 0] += 1
                    form[h, default: []].append("N")
                    form[g, default: []].append("S")
                } else {
                    punkte[h, default: 0] += 1
                    punkte[g, default: 0] += 1
                    remis[h, default: 0] += 1
                    remis[g, default: 0] += 1
                    form[h, default: []].append("U")
                    form[g, default: []].append("U")
                }
            }
        }

        let sortiert = elf.sorted { a, b in
            let pa = punkte[a.id, default: 0]
            let pb = punkte[b.id, default: 0]
            if pa != pb { return pa > pb }
            let da = fuer[a.id, default: 0] - gegen[a.id, default: 0]
            let db = fuer[b.id, default: 0] - gegen[b.id, default: 0]
            if da != db { return da > db }
            return fuer[a.id, default: 0] > fuer[b.id, default: 0]
        }

        let zeilen = sortiert.enumerated().map { platz, elfer in
            Tabellenzeile(platz: platz + 1,
                          mannschaft: elfer,
                          spiele: spiele[elfer.id, default: 0],
                          siege: siege[elfer.id, default: 0],
                          unentschieden: remis[elfer.id, default: 0],
                          niederlagen: pleiten[elfer.id, default: 0],
                          toreFuer: fuer[elfer.id, default: 0],
                          toreGegen: gegen[elfer.id, default: 0],
                          tordifferenz: fuer[elfer.id, default: 0] - gegen[elfer.id, default: 0],
                          punkte: punkte[elfer.id, default: 0],
                          form: Array(form[elfer.id, default: []].suffix(5)))
        }

        return Tabelle(liga: liga, spieltag: bisher, zeilen: zeilen, stand: Date())
    }

    // MARK: Ticker

    // MARK: Torjäger

    /// Erfundene Torjägerliste, aus denselben Würfeln wie alles andere —
    /// damit sie zu den Beispieltabellen passt und sich nicht bei jedem
    /// Aufruf ändert.
    static func torjaeger(_ liga: Liga) -> [Torjaeger] {
        let elf = mannschaften(liga)
        guard !elf.isEmpty else { return [] }
        let bisher = max(laufenderSpieltag(liga) - 1, 1)

        var liste: [Torjaeger] = []
        for platz in 0 ..< 20 {
            let mannschaft = elf[wuerfel(liga.kennzahl, platz, 71) % elf.count]
            let tore = max(bisher * 2 - platz - wuerfel(liga.kennzahl, platz, 13) % 3, 1)
            liste.append(Torjaeger(id: liga.kennzahl * 10_000 + platz,
                                   platz: 0,
                                   name: spielername(liga: liga, platz: platz),
                                   mannschaft: mannschaft,
                                   tore: tore,
                                   vorlagen: wuerfel(liga.kennzahl, platz, 29) % 6,
                                   elfmeter: wuerfel(liga.kennzahl, platz, 37) % 3,
                                   spiele: bisher))
        }
        return liste
            .sorted { $0.tore > $1.tore }
            .enumerated()
            .map { platz, eintrag in
                Torjaeger(id: eintrag.id,
                          platz: platz + 1,
                          name: eintrag.name,
                          mannschaft: eintrag.mannschaft,
                          tore: eintrag.tore,
                          vorlagen: eintrag.vorlagen,
                          elfmeter: eintrag.elfmeter,
                          spiele: eintrag.spiele)
            }
    }

    private static func spielername(liga: Liga, platz: Int) -> String {
        let vornamen = ["Jonas", "Luca", "Marco", "Erik", "Tobias", "Pablo", "Enzo",
                        "Rafael", "Milan", "Noah", "Elias", "Samuel", "Leon", "Nico",
                        "Adrian", "Fabio", "Kai", "Dennis", "Timo", "Robin"]
        let nachnamen = ["Wagner", "Brandt", "Keller", "Lindner", "Sanchez", "Moreau",
                         "Rossi", "Novak", "Berger", "Falk", "Hartmann", "Duarte",
                         "Petrov", "Larsen", "Vidal", "Kraus", "Mertens", "Olsen",
                         "Ferrari", "Baumann"]
        let v = vornamen[wuerfel(liga.kennzahl, platz, 5) % vornamen.count]
        let n = nachnamen[wuerfel(liga.kennzahl, platz, 91) % nachnamen.count]
        return v + " " + n
    }

    static func spieleHeute() -> [Spiel] {
        Liga.allCases.flatMap { liga in
            spiele(liga: liga, spieltag: laufenderSpieltag(liga))
                .filter { $0.status != .geplant || $0.istHeute }
                .prefix(4)
        }
    }
}
