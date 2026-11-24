import Foundation

// Die Reisen liegen als JSON im Dokumentenordner, eine Datei je Reise.
//
// Gesichert wird über eine TEMPORÄRE Datei, die danach getauscht wird: Eine
// halb geschriebene Reise wäre der Verlust eines ganzen Buches, und die
// Wahrscheinlichkeit dafür ist genau dann am höchsten, wenn viel darin
// steht — ein Schreibvorgang, den iOS mitten im Vorgang beendet, weil der
// Nutzer die App weglegt.
enum Ablage {
    // WO die Reisen liegen, entscheidet `Wolke` — auf dem Gerät oder in
    // iCloud. Hier steht es nicht noch einmal: Zwei Meinungen darüber, wo
    // ein Buch liegt, wären zwei Ablagen.
    static var wurzel: URL { Wolke.wurzel }

    static func datei(_ id: UUID) -> URL {
        wurzel.appendingPathComponent("\(id.uuidString).json")
    }

    static func kodierer() -> JSONEncoder {
        let k = JSONEncoder()
        // OHNE Einrückung (ab 1.0.54, gemeldet 11/2026: „Die App wird vom
        // Gefühl her immer träger … erst im 6. Jahr von insgesamt 18").
        // Die Einrückung machte die Datei um gut ein Drittel größer und
        // das Schreiben entsprechend länger — gelesen wird sie von
        // niemandem. Ältere, eingerückte Dateien liest `leser()` weiter.
        k.outputFormatting = [.sortedKeys]
        k.dateEncodingStrategy = .iso8601
        return k
    }

    static func leser() -> JSONDecoder {
        let l = JSONDecoder()
        l.dateDecodingStrategy = .iso8601
        return l
    }

    // EINE REIHE FÜR ALLES SCHREIBEN (ab 1.0.54). Das selbsttätige Sichern
    // nach jeder Änderung läuft seither abseits des Hauptfadens
    // (`imHintergrundSichern`); ausdrückliches Sichern (`sichern`) wartet
    // auf dieselbe Reihe. So kann ein älterer Stand, der noch unterwegs
    // ist, nie einen jüngeren überschreiben — die Reihe hält die
    // Reihenfolge.
    private static let schreibreihe = DispatchQueue(label: "de.familie.kapitelweise.ablage",
                                                    qos: .utility)

    static func sichern(_ reise: Reise) throws {
        try schreibreihe.sync { try schreiben(reise) }
    }

    /// Das ganze Buch als JSON — gerechnet und geschrieben in der Reihe,
    /// nicht auf dem Hauptfaden. Bei einem Buch mit Hunderten Seiten ist
    /// das die teuerste Arbeit nach jeder Änderung, und sie lag bis 1.0.53
    /// mitten in der Bedienung.
    static func imHintergrundSichern(_ reise: Reise, fehler: @escaping (Error) -> Void) {
        schreibreihe.async {
            do {
                try schreiben(reise)
            } catch {
                DispatchQueue.main.async { fehler(error) }
            }
        }
    }

    private static func schreiben(_ reise: Reise) throws {
        // WER GESCHRIEBEN HAT, STEHT IM BUCH (ab 1.0.102). Hier und
        // nirgends sonst: Das ist die eine Stelle, an der ein Buch auf die
        // Platte geht, und damit die einzige, an der die Angabe gar nicht
        // falsch sein kann. Gebraucht wird sie beim Abgleich — zwei
        // Fassungen desselben Buches lassen sich ohne sie nicht
        // auseinanderhalten.
        let anfang = Date()
        var kopie = reise
        kopie.geaendertAuf = Geraetename.eigener
        let daten = try kodierer().encode(kopie)
        Tempomesser.melde("Buch sichern", dauer: Date().timeIntervalSince(anfang),
                          zusatz: "\(daten.count / 1024) KB JSON")
        let ziel = datei(reise.id)
        let zwischen = ziel.appendingPathExtension("neu")
        try daten.write(to: zwischen, options: .atomic)
        if FileManager.default.fileExists(atPath: ziel.path) {
            _ = try FileManager.default.replaceItemAt(ziel, withItemAt: zwischen)
        } else {
            try FileManager.default.moveItem(at: zwischen, to: ziel)
        }
    }

    static func laden(_ id: UUID) throws -> Reise {
        let ort = datei(id)
        Wolke.konflikteLoesen(ort)
        let daten = try Data(contentsOf: ort)
        return try leser().decode(Reise.self, from: daten)
    }

    // Eine Reise, die sich nicht lesen lässt, wird ÜBERSPRUNGEN und nicht
    // verschwiegen: Die Übersicht zählt hinterher, wie viele es waren. Eine
    // Liste, die stillschweigend kürzer ist, sieht aus wie Datenverlust —
    // und ohne die Zahl wüsste niemand, ob sie einer ist.
    static func alle() -> (reisen: [Reise], unlesbar: Int) {
        // Was in iCloud liegt, liegt nicht unbedingt auf dem Gerät. Ohne
        // diesen Anstoß stünde ein Buch im Regal, das sich nicht öffnen
        // lässt, und niemand wüsste warum.
        Wolke.herunterladenAnstossen()
        guard let inhalt = try? FileManager.default.contentsOfDirectory(
            at: wurzel, includingPropertiesForKeys: nil)
        else { return ([], 0) }
        var gefunden: [Reise] = []
        var kaputt = 0
        for ort in inhalt where ort.pathExtension == "json" {
            // Eine beiseitegelegte Konfliktfassung ist kein Buch im Regal —
            // sie steht in den Einstellungen und wartet dort auf eine
            // Entscheidung. Zwei gleich heißende Bücher nebeneinander wären
            // die schlechtere Art, dasselbe zu sagen.
            guard !ort.lastPathComponent.contains(Wolke.konfliktmarke) else { continue }
            Wolke.konflikteLoesen(ort)
            guard let daten = try? Data(contentsOf: ort),
                  let reise = try? leser().decode(Reise.self, from: daten)
            else {
                kaputt += 1
                continue
            }
            gefunden.append(reise)
        }
        return (gefunden.sorted { $0.geaendert > $1.geaendert }, kaputt)
    }

    static func loeschen(_ id: UUID) {
        try? FileManager.default.removeItem(at: datei(id))
        try? FileManager.default.removeItem(
            at: wurzel.appendingPathComponent(id.uuidString, isDirectory: true))
    }
}
