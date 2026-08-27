import Foundation

/// Macht aus zwei Ständen eine Liste von Meldungen.
///
/// Bewusst ohne eigenen Zustand: Dieselbe Rechnung läuft im Vordergrund (wenn
/// die Ticker-Ansicht offen ist) und im Hintergrund (wenn iOS der App eine
/// Auffrischung gewährt). Beide vergleichen gegen denselben gesicherten Stand
/// und kommen deshalb auf dieselben Meldungen — mit denselben Kennungen, was
/// doppelte Mitteilungen verhindert.
enum Tickerwerk {

    static func meldungen(frisch: [Spiel], vorher: [Int: Spiel]) -> [Tickermeldung] {
        var neue: [Tickermeldung] = []

        for spiel in frisch {
            let alt = vorher[spiel.id]
            let paarung = "\(spiel.heim.anzeige) – \(spiel.gast.anzeige)"

            neue.append(contentsOf: zustandswechsel(spiel, alt: alt, paarung: paarung))
            neue.append(contentsOf: tore(spiel, alt: alt, paarung: paarung))
            neue.append(contentsOf: platzverweise(spiel, alt: alt, paarung: paarung))
        }
        return neue
    }

    /// Meldungen bekommen die Spielzeit als Zeitstempel, nicht den Augenblick
    /// des Abrufs — so stehen sie auch dann in der richtigen Reihenfolge, wenn
    /// mehrere auf einmal hereinkommen.
    private static func zeitpunkt(_ spiel: Spiel, _ minute: Int?) -> Date {
        guard let minute else { return Date() }
        return spiel.anstoss.addingTimeInterval(TimeInterval(minute * 60))
    }

    // MARK: Anpfiff, Halbzeit, Abpfiff

    private static func zustandswechsel(_ spiel: Spiel, alt: Spiel?, paarung: String) -> [Tickermeldung] {
        guard alt?.status != spiel.status else { return [] }

        switch spiel.status {
        case .laeuft where alt == nil || alt?.status == .geplant:
            return [Tickermeldung(id: "\(spiel.id)-anpfiff",
                                  zeitpunkt: spiel.anstoss,
                                  liga: spiel.liga,
                                  spielID: spiel.id,
                                  art: .anpfiff,
                                  paarung: paarung,
                                  stand: spiel.standtext,
                                  zusatz: "Anpfiff",
                                  minute: nil)]
        case .pause:
            return [Tickermeldung(id: "\(spiel.id)-halbzeit",
                                  zeitpunkt: zeitpunkt(spiel, 45),
                                  liga: spiel.liga,
                                  spielID: spiel.id,
                                  art: .halbzeit,
                                  paarung: paarung,
                                  stand: spiel.standtext,
                                  zusatz: "Halbzeit",
                                  minute: 45)]
        case .beendet:
            return [Tickermeldung(id: "\(spiel.id)-abpfiff",
                                  zeitpunkt: zeitpunkt(spiel, 105),
                                  liga: spiel.liga,
                                  spielID: spiel.id,
                                  art: .abpfiff,
                                  paarung: paarung,
                                  stand: spiel.standtext,
                                  zusatz: "Abpfiff",
                                  minute: nil)]
        default:
            return []
        }
    }

    // MARK: Tore

    /// Bevorzugt aus der Torliste des Dienstes, sonst aus dem Sprung im
    /// Spielstand. Der freie Zugang liefert nicht zu jedem Spiel Schützen —
    /// dieser Rückfall ist deshalb der Regelfall, nicht die Ausnahme.
    private static func tore(_ spiel: Spiel, alt: Spiel?, paarung: String) -> [Tickermeldung] {
        if !spiel.tore.isEmpty {
            return spiel.tore.map { tor in
                let stand = tor.standHeim != nil && tor.standGast != nil
                    ? "\(tor.standHeim ?? 0):\(tor.standGast ?? 0)"
                    : spiel.standtext
                let elf = tor.fuerHeim ? spiel.heim.anzeige : spiel.gast.anzeige
                return Tickermeldung(id: "\(spiel.id)-tor-\(tor.id)",
                                     zeitpunkt: zeitpunkt(spiel, tor.minute),
                                     liga: spiel.liga,
                                     spielID: spiel.id,
                                     art: .tor,
                                     paarung: paarung,
                                     stand: stand,
                                     zusatz: "\(tor.schuetze) (\(elf))",
                                     minute: tor.minute)
            }
        }

        guard let alt, alt.hatStand, spiel.hatStand else { return [] }
        var liste: [Tickermeldung] = []
        let alteHeim = alt.toreHeim ?? 0
        let alteGast = alt.toreGast ?? 0
        let neueHeim = spiel.toreHeim ?? 0
        let neueGast = spiel.toreGast ?? 0
        if neueHeim > alteHeim {
            liste.append(standmeldung(spiel, paarung: paarung, fuerHeim: true, nummer: neueHeim))
        }
        if neueGast > alteGast {
            liste.append(standmeldung(spiel, paarung: paarung, fuerHeim: false, nummer: neueGast))
        }
        return liste
    }

    private static func standmeldung(_ spiel: Spiel, paarung: String, fuerHeim: Bool, nummer: Int) -> Tickermeldung {
        let elf = fuerHeim ? spiel.heim : spiel.gast
        return Tickermeldung(id: "\(spiel.id)-stand-\(spiel.standtext)-\(fuerHeim ? "h" : "g")-\(nummer)",
                             zeitpunkt: Date(),
                             liga: spiel.liga,
                             spielID: spiel.id,
                             art: .tor,
                             paarung: paarung,
                             stand: spiel.standtext,
                             zusatz: "Tor für \(elf.anzeige)",
                             minute: spiel.minute)
    }

    // MARK: Platzverweise

    private static func platzverweise(_ spiel: Spiel, alt: Spiel?, paarung: String) -> [Tickermeldung] {
        let bekannt = Set((alt?.karten ?? []).map(\.id))
        return spiel.karten
            .filter { $0.farbe.istPlatzverweis && !bekannt.contains($0.id) }
            .map { karte in
                let elf = karte.fuerHeim ? spiel.heim.anzeige : spiel.gast.anzeige
                return Tickermeldung(id: "\(spiel.id)-karte-\(karte.id)",
                                     zeitpunkt: zeitpunkt(spiel, karte.minute),
                                     liga: spiel.liga,
                                     spielID: spiel.id,
                                     art: .roteKarte,
                                     paarung: paarung,
                                     stand: spiel.standtext,
                                     zusatz: "\(karte.farbe.name): \(karte.spieler) (\(elf))",
                                     minute: karte.minute)
            }
    }
}

/// Der zuletzt gesehene Stand jedes Spiels, auf der Platte.
///
/// Muss die App überleben: Der Hintergrundlauf und der Vordergrund vergleichen
/// beide dagegen. Läge er nur im Arbeitsspeicher, meldete jeder Neustart alle
/// Tore des Tages noch einmal.
enum Standspeicher {
    private static var ort: URL? {
        let ordner = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        return ordner?.appendingPathComponent("spielstaende.json")
    }

    static func laden() -> [Int: Spiel] {
        guard let ort, let daten = try? Data(contentsOf: ort) else { return [:] }
        let liste = (try? JSONDecoder().decode([Spiel].self, from: daten)) ?? []
        var stand: [Int: Spiel] = [:]
        for spiel in liste { stand[spiel.id] = spiel }
        return stand
    }

    static func sichern(_ stand: [Int: Spiel]) {
        guard let ort else { return }
        // Nur die letzten Tage behalten — alte Begegnungen sind für den
        // Vergleich wertlos.
        let grenze = Date().addingTimeInterval(-60 * 60 * 24 * 3)
        let liste = stand.values.filter { $0.anstoss > grenze }
        let ordner = ort.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        guard let daten = try? JSONEncoder().encode(Array(liste)) else { return }
        try? daten.write(to: ort, options: .atomic)
    }

    /// Ein einzelnes Spiel festhalten — damit die Einstellungen und die
    /// Anpfiff-Wecker auch dann einen Namen zur Kennung haben, wenn die App
    /// den Spieltag später nicht mehr geladen hat.
    static func merken(_ spiel: Spiel) {
        var stand = laden()
        stand[spiel.id] = spiel
        sichern(stand)
    }

    static func leeren() {
        guard let ort else { return }
        try? FileManager.default.removeItem(at: ort)
    }
}
