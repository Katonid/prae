import Foundation
import SwiftUI

/// Hält alles zusammen: Zugangsschlüssel, Zwischenspeicher der
/// Spieltage und Tabellen sowie den Liveticker.
@MainActor
final class Datenhaltung: ObservableObject {

    // MARK: Zustand

    @Published private(set) var schluessel: String
    @Published var beispielmodus: Bool {
        didSet {
            UserDefaults.standard.set(beispielmodus, forKey: Self.beispielSchluessel)
            if beispielmodus != oldValue {
                leeren()
            }
        }
    }

    @Published private(set) var ticker: [Tickermeldung] = []
    @Published private(set) var liveSpiele: [Spiel] = []
    @Published private(set) var tickerLaeuft = false
    @Published private(set) var tickerFehler: String?
    @Published private(set) var letzterAbruf: Date?

    @Published private(set) var spieltage: [Liga: [Int: [Spiel]]] = [:]
    @Published private(set) var tabellen: [Liga: Tabelle] = [:]
    @Published private(set) var laufenderSpieltag: [Liga: Int] = [:]
    @Published private(set) var ligaFehler: [Liga: String] = [:]
    @Published private(set) var ligaLaedt: Set<Liga> = []

    private var letzterStand: [Int: Spiel] = [:]
    private var abrufzeit: [String: Date] = [:]
    /// Was gerade schon unterwegs ist. Ohne das laufen zwei gleiche
    /// Abfragen nebeneinander — bei zehn Abfragen je Minute zählt jede.
    private var imFlug: Set<String> = []
    private static let beispielSchluessel = "beispielmodus"
    private static let tickerGrenze = 250

    var schluesselVorhanden: Bool { !schluessel.isEmpty }
    /// Ob die App gerade echte Daten holen kann.
    var einsatzbereit: Bool { schluesselVorhanden || beispielmodus }

    private var dienst: FussballDienst { FussballDienst(schluessel: schluessel) }

    // MARK: Aufbau

    init() {
        schluessel = Schluesselbund.lesen()
        beispielmodus = UserDefaults.standard.bool(forKey: Self.beispielSchluessel)
        ticker = Tickerspeicher.laden()
    }

    func schluesselSetzen(_ neu: String) {
        let sauber = neu.trimmingCharacters(in: .whitespacesAndNewlines)
        Schluesselbund.schreiben(sauber)
        schluessel = sauber
        if !sauber.isEmpty { beispielmodus = false }
        leeren()
    }

    func schluesselLoeschen() {
        Schluesselbund.loeschen()
        schluessel = ""
        leeren()
    }

    private func leeren() {
        spieltage = [:]
        tabellen = [:]
        laufenderSpieltag = [:]
        ligaFehler = [:]
        abrufzeit = [:]
        imFlug = []
        letzterStand = [:]
        liveSpiele = []
        ticker = []
        Tickerspeicher.sichern([])
        letzterAbruf = nil
        tickerFehler = nil
    }

    // MARK: Liveticker

    /// Läuft, solange die Ticker-Ansicht sichtbar ist. Wartet länger,
    /// wenn gerade kein Spiel läuft — der freie Zugang ist knapp bemessen.
    func tickerBeobachten() async {
        while !Task.isCancelled {
            await tickerAktualisieren()
            let pause: UInt64 = liveSpiele.contains { $0.status.laeuftGerade } ? 45 : 300
            try? await Task.sleep(nanoseconds: pause * 1_000_000_000)
        }
    }

    func tickerAktualisieren() async {
        guard einsatzbereit else { return }
        tickerLaeuft = true
        defer { tickerLaeuft = false }

        do {
            let frisch: [Spiel]
            if beispielmodus {
                frisch = Beispieldaten.spieleHeute()
            } else {
                frisch = try await dienst.spieleHeute()
            }
            meldungenAblegen(frisch)
            liveSpiele = frisch.sorted(by: Self.reihenfolge)
            letzterAbruf = Date()
            tickerFehler = nil
        } catch {
            tickerFehler = (error as? DienstFehler)?.errorDescription ?? error.localizedDescription
        }
    }

    /// Vergleicht den neuen Stand mit dem letzten und schreibt daraus die
    /// Tickermeldungen. So entsteht ein echter Ticker, auch wenn der Dienst
    /// selbst keine Ereignisse liefert.
    private func meldungenAblegen(_ frisch: [Spiel]) {
        var neue: [Tickermeldung] = []

        /// Meldungen bekommen die Spielzeit als Zeitstempel, nicht den
        /// Augenblick des Abrufs — so stehen sie auch dann in der richtigen
        /// Reihenfolge, wenn mehrere auf einmal hereinkommen.
        func zeitpunkt(_ spiel: Spiel, _ minute: Int?) -> Date {
            guard let minute else { return Date() }
            return spiel.anstoss.addingTimeInterval(TimeInterval(minute * 60))
        }

        for spiel in frisch {
            let vorher = letzterStand[spiel.id]
            let paarung = "\(spiel.heim.anzeige) – \(spiel.gast.anzeige)"

            // Zustandswechsel
            if vorher?.status != spiel.status {
                switch spiel.status {
                case .laeuft where vorher == nil || vorher?.status == .geplant:
                    neue.append(Tickermeldung(id: "\(spiel.id)-anpfiff",
                                              zeitpunkt: spiel.anstoss,
                                              liga: spiel.liga,
                                              spielID: spiel.id,
                                              art: .anpfiff,
                                              paarung: paarung,
                                              stand: spiel.standtext,
                                              zusatz: "Anpfiff",
                                              minute: nil))
                case .pause:
                    neue.append(Tickermeldung(id: "\(spiel.id)-halbzeit",
                                              zeitpunkt: zeitpunkt(spiel, 45),
                                              liga: spiel.liga,
                                              spielID: spiel.id,
                                              art: .halbzeit,
                                              paarung: paarung,
                                              stand: spiel.standtext,
                                              zusatz: "Halbzeit",
                                              minute: 45))
                case .beendet:
                    neue.append(Tickermeldung(id: "\(spiel.id)-abpfiff",
                                              zeitpunkt: zeitpunkt(spiel, 105),
                                              liga: spiel.liga,
                                              spielID: spiel.id,
                                              art: .abpfiff,
                                              paarung: paarung,
                                              stand: spiel.standtext,
                                              zusatz: "Abpfiff",
                                              minute: nil))
                default:
                    break
                }
            }

            // Tore: bevorzugt aus der Torliste des Dienstes, sonst aus dem
            // Sprung im Spielstand.
            if !spiel.tore.isEmpty {
                for tor in spiel.tore {
                    let stand = tor.standHeim != nil && tor.standGast != nil
                        ? "\(tor.standHeim ?? 0):\(tor.standGast ?? 0)"
                        : spiel.standtext
                    neue.append(Tickermeldung(id: "\(spiel.id)-tor-\(tor.id)",
                                              zeitpunkt: zeitpunkt(spiel, tor.minute),
                                              liga: spiel.liga,
                                              spielID: spiel.id,
                                              art: .tor,
                                              paarung: paarung,
                                              stand: stand,
                                              zusatz: "\(tor.schuetze) (\(tor.fuerHeim ? spiel.heim.anzeige : spiel.gast.anzeige))",
                                              minute: tor.minute))
                }
            } else if let vorher, vorher.hatStand, spiel.hatStand {
                let alteHeim = vorher.toreHeim ?? 0
                let alteGast = vorher.toreGast ?? 0
                let neueHeim = spiel.toreHeim ?? 0
                let neueGast = spiel.toreGast ?? 0
                if neueHeim > alteHeim {
                    neue.append(torMeldung(spiel: spiel, paarung: paarung, fuerHeim: true, nummer: neueHeim))
                }
                if neueGast > alteGast {
                    neue.append(torMeldung(spiel: spiel, paarung: paarung, fuerHeim: false, nummer: neueGast))
                }
            }

            letzterStand[spiel.id] = spiel
        }

        guard !neue.isEmpty else { return }
        var bekannt = Set(ticker.map(\.id))
        var zusammen = ticker
        for meldung in neue where !bekannt.contains(meldung.id) {
            bekannt.insert(meldung.id)
            zusammen.append(meldung)
        }
        zusammen.sort { links, rechts in
            if links.zeitpunkt != rechts.zeitpunkt { return links.zeitpunkt > rechts.zeitpunkt }
            return (links.minute ?? 0) > (rechts.minute ?? 0)
        }
        ticker = Array(zusammen.prefix(Self.tickerGrenze))
        Tickerspeicher.sichern(ticker)
    }

    private func torMeldung(spiel: Spiel, paarung: String, fuerHeim: Bool, nummer: Int) -> Tickermeldung {
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

    func tickerLeeren() {
        ticker = []
        Tickerspeicher.sichern([])
    }

    // MARK: Spieltage und Tabellen

    func spieltag(_ liga: Liga, _ nummer: Int) -> [Spiel]? {
        spieltage[liga]?[nummer]
    }

    func spieltagLaden(liga: Liga, nummer: Int, erzwingen: Bool = false) async {
        let marke = "\(liga.rawValue)-\(nummer)"
        if !erzwingen, spieltag(liga, nummer) != nil, frisch(marke, sekunden: 60) { return }
        guard einsatzbereit, !imFlug.contains(marke) else { return }

        imFlug.insert(marke)
        ligaLaedt.insert(liga)
        defer {
            imFlug.remove(marke)
            ligaLaedt.remove(liga)
        }

        do {
            let liste: [Spiel]
            if beispielmodus {
                liste = Beispieldaten.spiele(liga: liga, spieltag: nummer)
            } else {
                liste = try await dienst.spiele(liga: liga, spieltag: nummer)
            }
            var tage = spieltage[liga] ?? [:]
            tage[nummer] = liste.sorted(by: Self.reihenfolge)
            spieltage[liga] = tage
            abrufzeit[marke] = Date()
            ligaFehler[liga] = nil
        } catch {
            ligaFehler[liga] = (error as? DienstFehler)?.errorDescription ?? error.localizedDescription
        }
    }

    func tabelleLaden(liga: Liga, erzwingen: Bool = false) async {
        let marke = "\(liga.rawValue)-tabelle"
        if !erzwingen, tabellen[liga] != nil, frisch(marke, sekunden: 120) { return }
        guard einsatzbereit, !imFlug.contains(marke) else { return }

        imFlug.insert(marke)
        ligaLaedt.insert(liga)
        defer {
            imFlug.remove(marke)
            ligaLaedt.remove(liga)
        }

        do {
            let tafel: Tabelle
            if beispielmodus {
                tafel = Beispieldaten.tabelle(liga)
            } else {
                tafel = try await dienst.tabelle(liga: liga)
            }
            tabellen[liga] = tafel
            if laufenderSpieltag[liga] == nil, tafel.spieltag > 0 {
                laufenderSpieltag[liga] = min(tafel.spieltag, liga.spieltage)
            }
            abrufzeit[marke] = Date()
            ligaFehler[liga] = nil
        } catch {
            ligaFehler[liga] = (error as? DienstFehler)?.errorDescription ?? error.localizedDescription
        }
    }

    /// Ermittelt den Spieltag, der gerade läuft. Die Tabelle liefert ihn
    /// mit; nur wenn die noch nicht geladen ist, wird eigens gefragt.
    @discardableResult
    func spieltagErmitteln(liga: Liga) async -> Int {
        if let bekannt = laufenderSpieltag[liga] { return bekannt }
        if beispielmodus {
            let tag = Beispieldaten.laufenderSpieltag(liga)
            laufenderSpieltag[liga] = tag
            return tag
        }
        if let tafel = tabellen[liga], tafel.spieltag > 0 {
            let tag = min(tafel.spieltag, liga.spieltage)
            laufenderSpieltag[liga] = tag
            return tag
        }
        guard schluesselVorhanden else { return 1 }
        do {
            let tag = min(max(try await dienst.laufenderSpieltag(liga: liga), 1), liga.spieltage)
            laufenderSpieltag[liga] = tag
            return tag
        } catch {
            ligaFehler[liga] = (error as? DienstFehler)?.errorDescription ?? error.localizedDescription
            return 1
        }
    }

    /// Holt Torschützen zu einem einzelnen Spiel nach.
    func spielNachladen(_ spiel: Spiel) async -> Spiel? {
        guard !beispielmodus else { return spiel }
        guard schluesselVorhanden else { return nil }
        return try? await dienst.spiel(id: spiel.id)
    }

    // MARK: Hilfen

    private func frisch(_ marke: String, sekunden: TimeInterval) -> Bool {
        guard let zeit = abrufzeit[marke] else { return false }
        return Date().timeIntervalSince(zeit) < sekunden
    }

    /// Laufende Spiele zuerst, danach nach Anstoß und Paarung.
    static func reihenfolge(_ a: Spiel, _ b: Spiel) -> Bool {
        if a.status.laeuftGerade != b.status.laeuftGerade { return a.status.laeuftGerade }
        if a.anstoss != b.anstoss { return a.anstoss < b.anstoss }
        return a.heim.anzeige < b.heim.anzeige
    }
}

// MARK: - Ticker auf der Platte

/// Der Ticker soll einen Programmstart überleben, aber nicht ewig
/// wachsen: gesichert werden die letzten Meldungen der vergangenen Tage.
enum Tickerspeicher {
    private static var ort: URL? {
        let ordner = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        return ordner?.appendingPathComponent("ticker.json")
    }

    static func laden() -> [Tickermeldung] {
        guard let ort, let daten = try? Data(contentsOf: ort) else { return [] }
        let alle = (try? JSONDecoder().decode([Tickermeldung].self, from: daten)) ?? []
        let grenze = Date().addingTimeInterval(-60 * 60 * 30)
        return alle.filter { $0.zeitpunkt > grenze }
    }

    static func sichern(_ meldungen: [Tickermeldung]) {
        guard let ort else { return }
        let ordner = ort.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        guard let daten = try? JSONEncoder().encode(meldungen) else { return }
        try? daten.write(to: ort, options: .atomic)
    }
}
