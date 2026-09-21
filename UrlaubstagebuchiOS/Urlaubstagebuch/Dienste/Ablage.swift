import Foundation

// Die Reisen liegen als JSON im Dokumentenordner, eine Datei je Reise.
//
// Gesichert wird über eine TEMPORÄRE Datei, die danach getauscht wird: Eine
// halb geschriebene Reise wäre der Verlust eines ganzen Buches, und die
// Wahrscheinlichkeit dafür ist genau dann am höchsten, wenn viel darin
// steht — ein Schreibvorgang, den iOS mitten im Vorgang beendet, weil der
// Nutzer die App weglegt.
enum Ablage {
    static let ordnername = "Reisen"

    static var wurzel: URL {
        let ort = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(ordnername, isDirectory: true)
        try? FileManager.default.createDirectory(at: ort, withIntermediateDirectories: true)
        return ort
    }

    static func datei(_ id: UUID) -> URL {
        wurzel.appendingPathComponent("\(id.uuidString).json")
    }

    static func kodierer() -> JSONEncoder {
        let k = JSONEncoder()
        k.outputFormatting = [.prettyPrinted, .sortedKeys]
        k.dateEncodingStrategy = .iso8601
        return k
    }

    static func leser() -> JSONDecoder {
        let l = JSONDecoder()
        l.dateDecodingStrategy = .iso8601
        return l
    }

    static func sichern(_ reise: Reise) throws {
        let daten = try kodierer().encode(reise)
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
        let daten = try Data(contentsOf: datei(id))
        return try leser().decode(Reise.self, from: daten)
    }

    // Eine Reise, die sich nicht lesen lässt, wird ÜBERSPRUNGEN und nicht
    // verschwiegen: Die Übersicht zählt hinterher, wie viele es waren. Eine
    // Liste, die stillschweigend kürzer ist, sieht aus wie Datenverlust —
    // und ohne die Zahl wüsste niemand, ob sie einer ist.
    static func alle() -> (reisen: [Reise], unlesbar: Int) {
        guard let inhalt = try? FileManager.default.contentsOfDirectory(
            at: wurzel, includingPropertiesForKeys: nil)
        else { return ([], 0) }
        var gefunden: [Reise] = []
        var kaputt = 0
        for ort in inhalt where ort.pathExtension == "json" {
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
        let bilder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Reisen", isDirectory: true)
            .appendingPathComponent(id.uuidString, isDirectory: true)
        try? FileManager.default.removeItem(at: bilder)
    }
}
