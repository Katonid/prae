import Foundation
import CoreData
import CoreLocation

// AUTOFAHRTEN AUS GPX-DATEIEN, AUF EINMAL (ab 1.0.21, Ansage des Nutzers
// 09/2026: „Von meinen Autofahrten der jeweiligen Tage habe ich GPX-Dateien
// für jede einzelne Fahrt. Ich möchte sie en bloc importieren können, sodass
// die App sie dann den einzelnen Tagen zuweist.")
//
// - **Viele Dateien auf einmal — und mehrere Fahrten in einer Datei** (ab
//   1.0.22, Ansage des Nutzers 09/2026: „Ich habe zum Teil GPX-Dateien, in
//   denen mehrere Fahrten aufgelistet sind."). Getrennt wird an jeder Spur
//   (`trk`) und innerhalb einer Spur an jeder Pause ab 15 Minuten
//   (einstellbar im Blatt, `GPXLeser.fahrten`). 1.0.21 machte aus jeder
//   Datei EINE Linie und verband damit die Fahrten quer über die Karte.
// - **Der Tag einer Fahrt ist der Tag ihres STARTS am Ort** (Zone aus Apples
//   Ortsdienst, eine Anfrage je halbem Grad — wie bei den Fotos). Eine Fahrt
//   über Mitternacht bleibt ganz beim Tag, an dem sie begann; geteilt wird
//   sie nicht, sonst stünde der Rest als eigene Fahrt ohne Anfang da.
// - **Nur Dateien MIT Uhrzeiten.** Ohne Zeit (eine geplante Route) gibt es
//   keinen Tag; solche Dateien werden gezählt und genannt, nicht geraten.
// - Gespeichert als `Spur` der Reise mit `geraet` = „fahrt:<Start in
//   Sekunden>|<Zeitzone>|<Name>" — eine Fahrt gehört zu keinem Gerät, sondern zu einer
//   Datei. Kein neues Attribut, kein Schema-Deploy. `Aufzeichner` schreibt
//   nur Spuren mit SEINER Gerätekennung und löscht keine fremden; die Fahrten
//   bleiben also unangetastet. Derselbe Start zweimal eingelesen wird
//   übersprungen.
// - Die Punkte werden auf 20 m gedünnt (eine Sportuhr schreibt jede
//   Sekunde); die Kilometer kommen aus der UNGEDÜNNTEN Datei.
// - Kilometer des Tages: das Größere aus der längsten Gerätespur und der
//   Summe aus Fahrten und Wanderungen (`Reise.meter(am:)`) — wer mitschrieb,
//   hat die Fahrt ohnehin in der Spur.

@MainActor
enum Fahrtenimport {
    nonisolated static let praefix = "fahrt:"

    struct Fahrt: Identifiable {
        /// „fahrt:<Start in Sekunden>" — erkennt eine schon eingelesene.
        let kennung: String
        let name: String
        let punkte: [Spurpunkt]
        let meter: Double
        let zone: TimeZone
        let tag: String
        var id: String { kennung }
        var beginn: Date { punkte.first?.datum ?? Date() }
        var ende: Date { punkte.last?.datum ?? beginn }
        var zeitspanne: String {
            Tag.text(beginn, "HH:mm", zone: zone) + "–" + Tag.text(ende, "HH:mm", zone: zone)
        }
    }

    struct Fund {
        var fahrten: [Fahrt] = []
        /// Dateien ohne Uhrzeiten (geplante Routen) — kein Tag bestimmbar.
        var ohneZeit: [String] = []
        /// Dateien, die sich nicht lesen ließen.
        var unlesbar: [String] = []
        /// Stücke unter 200 m, die weggefallen sind.
        var zuKurz = 0
        /// Aus wie vielen Dateien die Fahrten stammen.
        var dateien = 0
    }

    /// Eine gewählte Datei, schon gelesen — damit sich die Pause im Blatt
    /// ändern lässt, ohne die Dateien erneut öffnen zu müssen (der Zugriff
    /// auf sie gilt nur kurz).
    struct Datei {
        let name: String
        let daten: Data
    }

    /// Liest die gewählten Dateien sofort ein.
    static func dateien(_ urls: [URL]) -> (dateien: [Datei], unlesbar: [String]) {
        var gelesen: [Datei] = []
        var unlesbar: [String] = []
        for url in urls {
            let zugriff = url.startAccessingSecurityScopedResource()
            defer { if zugriff { url.stopAccessingSecurityScopedResource() } }
            if let daten = try? Data(contentsOf: url) {
                gelesen.append(Datei(name: url.lastPathComponent, daten: daten))
            } else {
                unlesbar.append(url.lastPathComponent)
            }
        }
        return (gelesen, unlesbar)
    }

    /// Zerlegt die Dateien in Fahrten. `pause`: ab so vielen Sekunden ohne
    /// Punkt beginnt eine neue Fahrt; `nil` trennt nur an den Spuren.
    static func auswerten(_ dateien: [Datei], pause: TimeInterval?) async -> Fund {
        var fund = Fund()
        var gelesen: [Wanderung] = []
        for datei in dateien {
            guard let ergebnis = try? GPXLeser.fahrten(datei.daten, dateiname: datei.name, pause: pause) else {
                fund.unlesbar.append(datei.name)
                continue
            }
            if ergebnis.ohneZeit { fund.ohneZeit.append(datei.name); continue }
            fund.zuKurz += ergebnis.zuKurz
            if !ergebnis.fahrten.isEmpty { fund.dateien += 1 }
            gelesen += ergebnis.fahrten
        }
        var jeZelle: [String: TimeZone] = [:]
        for w in gelesen {
            guard let start = w.punkte.first else { continue }
            let k = start.koordinate
            let zelle = "\(Int((k.latitude * 2).rounded(.down)))|\(Int((k.longitude * 2).rounded(.down)))"
            if jeZelle[zelle] == nil {
                let name = await Ortsnamen.shared.name(fuer: k)
                jeZelle[zelle] = name.flatMap { TimeZone(identifier: $0.zeitzone) } ?? .current
            }
            let zone = jeZelle[zelle] ?? .current
            let kennung = praefix + "\(Int(start.zeit))"
            // Dieselbe Fahrt in zwei Dateien: nur die erste.
            guard !fund.fahrten.contains(where: { $0.kennung == kennung }) else { continue }
            fund.fahrten.append(Fahrt(kennung: kennung, name: w.name, punkte: w.punkte, meter: w.meter,
                                      zone: zone, tag: Tag.schluessel(start.datum, zone: zone)))
        }
        fund.fahrten.sort { $0.beginn < $1.beginn }
        return fund
    }

    /// Was an Fahrten schon in der Reise liegt: Kennungen und Zeiträume.
    struct Belegt {
        let kennungen: Set<String>
        let zeiten: [ClosedRange<Double>]
    }

    static func belegt(in reise: Reise) -> Belegt {
        let fahrten = reise.spurListe.filter(\.istFahrt)
        return Belegt(kennungen: Set(fahrten.map { kennung($0) }),
                      zeiten: fahrten.compactMap { s in
                          let p = s.punktListe
                          guard let a = p.first?.zeit, let b = p.last?.zeit, a <= b else { return nil }
                          return a...b
                      })
    }

    /// Liegt diese Fahrt schon in der Reise — mit demselben Start ODER
    /// zeitlich innerhalb einer eingelesenen (etwa aus 1.0.21, als eine
    /// Datei mit mehreren Fahrten noch eine einzige Linie wurde)?
    static func schonDa(_ f: Fahrt, _ belegt: Belegt) -> Bool {
        if belegt.kennungen.contains(f.kennung) { return true }
        let von = f.beginn.timeIntervalSince1970, bis = f.ende.timeIntervalSince1970
        return belegt.zeiten.contains { $0.contains(von) && $0.contains(bis) }
    }

    /// Die Kennungen der Fahrten, die schon in der Reise stehen.
    static func vorhanden(in reise: Reise) -> Set<String> {
        Set(reise.spurListe.filter(\.istFahrt).map { kennung($0) })
    }

    nonisolated static func kennung(_ spur: Spur) -> String {
        let g = spur.geraet ?? ""
        return g.split(separator: "|", maxSplits: 1).first.map(String.init) ?? g
    }

    /// Der Name der Fahrt (Titel der GPX-Datei, sonst ihr Dateiname).
    nonisolated static func name(_ spur: Spur) -> String {
        let teile = (spur.geraet ?? "").split(separator: "|", maxSplits: 2, omittingEmptySubsequences: false)
        let n = teile.count > 2 ? String(teile[2]) : ""
        return n.isEmpty ? "Autofahrt" : n
    }

    /// Die Ortszeit am Start der Fahrt — für die Uhrzeiten.
    nonisolated static func zone(_ spur: Spur) -> TimeZone {
        let teile = (spur.geraet ?? "").split(separator: "|", maxSplits: 2, omittingEmptySubsequences: false)
        return teile.count > 1 ? TimeZone(identifier: String(teile[1])) ?? .current : .current
    }

    /// Legt die Fahrten in der Reise an. Gibt die Zahl der neuen zurück.
    @discardableResult
    static func uebernehmen(_ fahrten: [Fahrt], in reise: Reise) -> Int {
        let persistenz = Persistenz.shared
        let schon = belegt(in: reise)
        var neu = 0
        for f in fahrten where !schonDa(f, schon) {
            let s = persistenz.anlegen(Spur.self, bei: reise)
            s.kennung = UUID()
            s.tag = f.tag
            // Zone und Name stehen mit an der Kennung: Eigene Felder hätten
            // einen Schema-Deploy gekostet. Ein „|" im Namen stört nicht —
            // getrennt wird nur an den ersten beiden.
            s.geraet = f.kennung + "|" + f.zone.identifier + "|" + f.name.replacingOccurrences(of: "\n", with: " ")
            s.reisender = Geraet.name
            s.punkte = Spurpunkt.packen(Spurpunkt.ausgeduennt(f.punkte, abstand: 20))
            s.distanz = f.meter
            s.geaendert = Date()
            s.reise = reise
            neu += 1
        }
        persistenz.sichern()
        return neu
    }

    static func loeschen(_ spur: Spur) {
        let persistenz = Persistenz.shared
        persistenz.kontext.delete(spur)
        persistenz.sichern()
    }
}

extension Reise {
    /// Die Fahrten eines Tages, nach Start.
    func fahrten(am schluessel: String) -> [Spur] {
        spurListe.filter { $0.tag == schluessel && $0.istFahrt }
            .sorted { ($0.punktListe.first?.zeit ?? 0) < ($1.punktListe.first?.zeit ?? 0) }
    }

    /// Meter eines Tages: das Größere aus der längsten Gerätespur und der
    /// Summe aus Fahrten und Wanderungen. Zwei Mitreisende zählen nicht
    /// doppelt, und wer mitschrieb, hat Fahrt und Wanderung in der Spur.
    func meter(am schluessel: String) -> Double {
        let spuren = spurListe.filter { $0.tag == schluessel }
        let geraete = spuren.filter { !$0.istFahrt }.map(\.distanz).max() ?? 0
        let fahrten = spuren.filter(\.istFahrt).reduce(0) { $0 + $1.distanz }
        let wanderungen = eintragListe
            .filter { $0.eintragsart == .wanderung && $0.tagSchluessel == schluessel }
            .reduce(0) { $0 + $1.streckeMeter }
        return max(geraete, fahrten + wanderungen)
    }
}
