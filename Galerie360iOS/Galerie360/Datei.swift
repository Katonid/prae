import Foundation

/// Dateizugriff mit NSFileCoordinator — nötig für Ordner in iCloud Drive (und
/// anderen Dateianbietern): Erst die Koordination lädt eine Datei herunter,
/// die iCloud nur als Platzhalter auf dem Gerät hält, und sie verhindert, dass
/// der Abgleich mitten in einen Schreibvorgang fährt.
enum Datei {
    static func lesen(_ url: URL) throws -> Data {
        var ergebnis: Result<Data, Error> = .failure(CocoaError(.fileReadUnknown))
        var fehler: NSError?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &fehler) { u in
            ergebnis = Result { try Data(contentsOf: u) }
        }
        if let fehler { throw fehler }
        return try ergebnis.get()
    }

    /// Sorgt dafür, dass die Datei vollständig auf dem Gerät liegt (iCloud lädt sie
    /// sonst erst herunter), und liefert ihre Adresse. Kann bei großen Videos dauern.
    static func bereitstellen(_ url: URL) throws -> URL {
        var fehler: NSError?
        var da = false
        NSFileCoordinator().coordinate(readingItemAt: url, options: [.withoutChanges], error: &fehler) { u in
            da = FileManager.default.isReadableFile(atPath: u.path)
        }
        if let fehler { throw fehler }
        guard da else { throw CocoaError(.fileReadNoSuchFile) }
        return url
    }

    static func schreiben(_ daten: Data, nach url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var innen: Error?
        var fehler: NSError?
        NSFileCoordinator().coordinate(writingItemAt: url, options: [.forReplacing], error: &fehler) { u in
            do { try daten.write(to: u, options: .atomic) } catch { innen = error }
        }
        if let fehler { throw fehler }
        if let innen { throw innen }
    }

    static func kopieren(von quelle: URL, nach ziel: URL) throws {
        try FileManager.default.createDirectory(at: ziel.deletingLastPathComponent(), withIntermediateDirectories: true)
        var innen: Error?
        var fehler: NSError?
        NSFileCoordinator().coordinate(readingItemAt: quelle, options: [], writingItemAt: ziel, options: [.forReplacing], error: &fehler) { q, z in
            do {
                if FileManager.default.fileExists(atPath: z.path) { try FileManager.default.removeItem(at: z) }
                try FileManager.default.copyItem(at: q, to: z)
            } catch { innen = error }
        }
        if let fehler { throw fehler }
        if let innen { throw innen }
    }

    static func loeschen(_ url: URL) {
        var fehler: NSError?
        NSFileCoordinator().coordinate(writingItemAt: url, options: [.forDeleting], error: &fehler) { u in
            try? FileManager.default.removeItem(at: u)
        }
    }

    static func existiert(_ url: URL) -> Bool {
        if FileManager.default.fileExists(atPath: url.path) { return true }
        // iCloud-Platzhalter einer noch nicht geladenen Datei: „.name.icloud"
        let platzhalter = url.deletingLastPathComponent().appendingPathComponent("." + url.lastPathComponent + ".icloud")
        return FileManager.default.fileExists(atPath: platzhalter.path)
    }

    /// Ein freier Dateiname im Ordner, mit 8 Zufallszeichen wie in der Web-App
    /// (wer den Kameranamen kennt, soll die Adresse trotzdem nicht erraten).
    static func freierName(in ordner: URL, name: String, endung: String) -> String {
        let basis = Kennung.lesbar(name).isEmpty ? "datei" : Kennung.lesbar(name)
        while true {
            let kandidat = basis + "-" + Kennung.zufall(8) + "." + endung
            if !existiert(ordner.appendingPathComponent(kandidat)) { return kandidat }
        }
    }
}
