import Foundation
import Observation

/// Was die Fotos-App nicht speichern kann: eigener Titel, Beschreibung und Startansicht
/// je Aufnahme sowie das Albumbild je Album. Ein paar Kilobyte Text im App-Speicher —
/// die Fotos und Videos selbst liegen ausschließlich in der Fotos-Mediathek (Wunsch des
/// Nutzers, 11/2026: „keine weitere Speicherung an einem anderen Ort").
/// Schlüssel sind die localIdentifier von PhotoKit.
@Observable
final class Notizen {
    struct Notiz: Codable, Equatable {
        var titel: String?
        var beschreibung: String?
        var blick: Blick?
    }

    private struct Inhalt: Codable {
        var medien: [String: Notiz] = [:]
        var albumbilder: [String: String] = [:]
    }

    private var inhalt = Inhalt()
    @ObservationIgnored private let datei: URL

    static var standardDatei: URL {
        let ordner = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return ordner.appendingPathComponent("notizen.json")
    }

    init(datei: URL = Notizen.standardDatei) {
        self.datei = datei
        if let d = try? Data(contentsOf: datei), let i = try? JSONDecoder().decode(Inhalt.self, from: d) {
            inhalt = i
        }
    }

    func notiz(_ id: String) -> Notiz { inhalt.medien[id] ?? Notiz() }

    func titel(_ id: String) -> String? {
        let t = inhalt.medien[id]?.titel ?? ""
        return t.isEmpty ? nil : t
    }

    func blick(_ id: String) -> Blick { inhalt.medien[id]?.blick ?? .start }

    func albumbild(_ albumId: String) -> String? { inhalt.albumbilder[albumId] }

    func setzeTitel(_ id: String, _ t: String) { aendern(id) { $0.titel = t } }
    func setzeBeschreibung(_ id: String, _ t: String) { aendern(id) { $0.beschreibung = t } }
    func setzeBlick(_ id: String, _ b: Blick?) { aendern(id) { $0.blick = b } }

    func setzeAlbumbild(_ albumId: String, _ assetId: String?) {
        inhalt.albumbilder[albumId] = assetId
        speichern()
    }

    private func aendern(_ id: String, _ f: (inout Notiz) -> Void) {
        var n = inhalt.medien[id] ?? Notiz()
        f(&n)
        inhalt.medien[id] = n == Notiz() ? nil : n
        speichern()
    }

    private func speichern() {
        do {
            try FileManager.default.createDirectory(at: datei.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(inhalt).write(to: datei, options: .atomic)
        } catch {
            // Nur Titel und Startansichten — ein Fehler hier darf die App nicht aufhalten.
        }
    }
}
