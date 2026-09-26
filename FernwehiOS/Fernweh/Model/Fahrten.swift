import Foundation
import CoreData
import CoreLocation

// AUTOFAHRTEN AUS GPX-DATEIEN, AUF EINMAL (ab 1.0.21, Ansage des Nutzers
// 09/2026: „Von meinen Autofahrten der jeweiligen Tage habe ich GPX-Dateien
// für jede einzelne Fahrt. Ich möchte sie en bloc importieren können, sodass
// die App sie dann den einzelnen Tagen zuweist.")
//
// - **Viele Dateien auf einmal**, eine Fahrt je Datei (mehrere Spuren in
//   einer Datei werden zu einer Linie — so schreibt sie der `GPXLeser`).
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
    }

    /// Liest die Dateien. Muss vor dem Ende des Zugriffs auf die URLs
    /// aufgerufen werden — die Daten werden sofort gelesen.
    static func lesen(_ urls: [URL]) async -> Fund {
        var fund = Fund()
        var gelesen: [(String, Wanderung)] = []
        for url in urls {
            let zugriff = url.startAccessingSecurityScopedResource()
            defer { if zugriff { url.stopAccessingSecurityScopedResource() } }
            let dateiname = url.lastPathComponent
            guard let daten = try? Data(contentsOf: url),
                  let w = try? GPXLeser.lesen(daten, dateiname: dateiname) else {
                fund.unlesbar.append(dateiname)
                continue
            }
            if w.geplant { fund.ohneZeit.append(dateiname); continue }
            gelesen.append((dateiname, w))
        }
        var jeZelle: [String: TimeZone] = [:]
        for (_, w) in gelesen {
            guard let start = w.punkte.first else { continue }
            let k = start.koordinate
            let zelle = "\(Int((k.latitude * 2).rounded(.down)))|\(Int((k.longitude * 2).rounded(.down)))"
            if jeZelle[zelle] == nil {
                let name = await Ortsnamen.shared.name(fuer: k)
                jeZelle[zelle] = name.flatMap { TimeZone(identifier: $0.zeitzone) } ?? .current
            }
            let zone = jeZelle[zelle] ?? .current
            let kennung = praefix + "\(Int(start.zeit))"
            // Zwei Dateien derselben Fahrt: nur die erste.
            guard !fund.fahrten.contains(where: { $0.kennung == kennung }) else { continue }
            fund.fahrten.append(Fahrt(kennung: kennung, name: w.name, punkte: w.punkte, meter: w.meter,
                                      zone: zone, tag: Tag.schluessel(start.datum, zone: zone)))
        }
        fund.fahrten.sort { $0.beginn < $1.beginn }
        return fund
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
        let schon = vorhanden(in: reise)
        var neu = 0
        for f in fahrten where !schon.contains(f.kennung) {
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
