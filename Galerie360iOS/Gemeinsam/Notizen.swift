import Foundation
import Observation

/// Was die Fotos-App nicht speichern kann: eigener Titel, Beschreibung und Startansicht
/// je Aufnahme sowie das Albumbild je Album. Ein paar Kilobyte Text im App-Speicher —
/// die Fotos und Videos selbst liegen ausschließlich in der Fotos-Mediathek (Wunsch des
/// Nutzers, 11/2026: „keine weitere Speicherung an einem anderen Ort").
/// Schlüssel sind die localIdentifier von PhotoKit (je Gerät verschieden).
///
/// Abgleich über iCloud (seit 1.0.3): Eine `NotizenWolke` hält dieselben Notizen unter den
/// geräteübergreifenden Cloud-Kennungen der Fotos-Mediathek. Je Eintrag gewinnt die jüngere
/// Änderung; Löschen bleibt als leerer Eintrag mit Zeitstempel stehen, damit es sich
/// ebenfalls überträgt.
@Observable
final class Notizen {
    struct Notiz: Codable, Equatable {
        var titel: String?
        var beschreibung: String?
        var blick: Blick?
        var geaendert: Date?

        var leer: Bool { (titel ?? "").isEmpty && (beschreibung ?? "").isEmpty && blick == nil }
    }

    struct Albumbild: Codable, Equatable {
        var asset: String?
        var geaendert: Date?
    }

    struct Inhalt: Codable, Equatable {
        var medien: [String: Notiz] = [:]
        var alben: [String: Albumbild] = [:]

        init() {}

        private enum CodingKeys: String, CodingKey { case medien, alben, albumbilder }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            medien = try c.decodeIfPresent([String: Notiz].self, forKey: .medien) ?? [:]
            alben = try c.decodeIfPresent([String: Albumbild].self, forKey: .alben) ?? [:]
            // Bis 1.0.2: nur Albumkennung → Aufnahmekennung, ohne Zeitstempel.
            if let alt = try c.decodeIfPresent([String: String].self, forKey: .albumbilder) {
                for (album, asset) in alt where alben[album] == nil { alben[album] = Albumbild(asset: asset) }
            }
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(medien, forKey: .medien)
            try c.encode(alben, forKey: .alben)
        }
    }

    private(set) var inhalt = Inhalt()
    @ObservationIgnored private let datei: URL
    @ObservationIgnored private let wolke: NotizenWolke?
    @ObservationIgnored private let jetzt: () -> Date

    static var standardDatei: URL {
        let ordner = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return ordner.appendingPathComponent("notizen.json")
    }

    init(datei: URL = Notizen.standardDatei, wolke: NotizenWolke? = nil, jetzt: @escaping () -> Date = Date.init) {
        self.datei = datei
        self.wolke = wolke
        self.jetzt = jetzt
        if let d = try? Data(contentsOf: datei), let i = try? JSONDecoder().decode(Inhalt.self, from: d) {
            inhalt = i
        }
        wolke?.beiAenderung = { [weak self] in self?.abgleichen() }
    }

    func notiz(_ id: String) -> Notiz { inhalt.medien[id] ?? Notiz() }

    func titel(_ id: String) -> String? {
        let t = inhalt.medien[id]?.titel ?? ""
        return t.isEmpty ? nil : t
    }

    func blick(_ id: String) -> Blick { inhalt.medien[id]?.blick ?? .start }

    func albumbild(_ albumId: String) -> String? { inhalt.alben[albumId]?.asset }

    func setzeTitel(_ id: String, _ t: String) { aendern(id) { $0.titel = t.isEmpty ? nil : t } }
    func setzeBeschreibung(_ id: String, _ t: String) { aendern(id) { $0.beschreibung = t.isEmpty ? nil : t } }
    func setzeBlick(_ id: String, _ b: Blick?) { aendern(id) { $0.blick = b } }

    func setzeAlbumbild(_ albumId: String, _ assetId: String?) {
        inhalt.alben[albumId] = Albumbild(asset: assetId, geaendert: jetzt())
        speichern()
        abgleichen()
    }

    private func aendern(_ id: String, _ f: (inout Notiz) -> Void) {
        var n = inhalt.medien[id] ?? Notiz()
        f(&n)
        n.geaendert = jetzt()
        inhalt.medien[id] = n
        speichern()
        abgleichen()
    }

    private func speichern() {
        do {
            try FileManager.default.createDirectory(at: datei.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(inhalt).write(to: datei, options: .atomic)
        } catch {
            // Nur Titel und Startansichten — ein Fehler hier darf die App nicht aufhalten.
        }
    }

    // MARK: Abgleich

    /// Führt die Notizen dieses Geräts und die in iCloud zusammen (je Eintrag gewinnt die
    /// jüngere Änderung). Aufrufen beim Start, nach erteiltem Fotozugriff, wenn die App
    /// wieder in den Vordergrund kommt und wenn iCloud Neues meldet. Kennungen, die sich
    /// (noch) nicht zuordnen lassen — Aufnahme auf diesem Gerät noch nicht angekommen —,
    /// bleiben unberührt und kommen beim nächsten Abgleich dran.
    func abgleichen() {
        guard let wolke else { return }
        var entfernt = wolke.lesen()
        let (neuLokal, neuEntfernt) = Notizen.zusammenfuehren(lokal: inhalt, entfernt: entfernt,
                                                              zuCloud: wolke.zuCloud, zuLokal: wolke.zuLokal)
        if neuLokal != inhalt {
            inhalt = neuLokal
            speichern()
        }
        if neuEntfernt != entfernt {
            entfernt = neuEntfernt
            wolke.schreiben(entfernt)
        }
    }

    /// Reine Rechnung, damit sie ohne Fotos-Mediathek und iCloud prüfbar ist.
    /// `lokal` ist nach localIdentifier geschlüsselt, `entfernt` nach Cloud-Kennung.
    static func zusammenfuehren(lokal: Inhalt, entfernt: Inhalt,
                                zuCloud: ([String]) -> [String: String],
                                zuLokal: ([String]) -> [String: String]) -> (Inhalt, Inhalt) {
        var l = lokal
        var e = entfernt
        let frueh = Date.distantPast

        var lokaleIds = Set(l.medien.keys).union(l.alben.keys)
        for b in l.alben.values { if let a = b.asset { lokaleIds.insert(a) } }
        var cloudIds = Set(e.medien.keys).union(e.alben.keys)
        for b in e.alben.values { if let a = b.asset { cloudIds.insert(a) } }
        let l2c = lokaleIds.isEmpty ? [:] : zuCloud(Array(lokaleIds))
        let c2l = cloudIds.isEmpty ? [:] : zuLokal(Array(cloudIds))

        // Dieses Gerät → iCloud (nur wo hier jünger oder dort noch nichts steht).
        for (lid, n) in lokal.medien {
            guard let cid = l2c[lid] else { continue }
            if let d = e.medien[cid], (d.geaendert ?? frueh) >= (n.geaendert ?? frueh) { continue }
            e.medien[cid] = n
        }
        for (lid, b) in lokal.alben {
            guard let cid = l2c[lid] else { continue }
            // Ein Albumbild, dessen Aufnahme keine Cloud-Kennung hat, lässt sich nicht übertragen.
            if let a = b.asset, l2c[a] == nil { continue }
            if let d = e.alben[cid], (d.geaendert ?? frueh) >= (b.geaendert ?? frueh) { continue }
            e.alben[cid] = Albumbild(asset: b.asset.flatMap { l2c[$0] }, geaendert: b.geaendert)
        }

        // iCloud → dieses Gerät (nur wo dort jünger).
        for (cid, n) in entfernt.medien {
            guard let lid = c2l[cid] else { continue }
            if (n.geaendert ?? frueh) > (l.medien[lid]?.geaendert ?? frueh) { l.medien[lid] = n }
        }
        for (cid, b) in entfernt.alben {
            guard let lid = c2l[cid] else { continue }
            if let a = b.asset, c2l[a] == nil { continue }
            if (b.geaendert ?? frueh) > (l.alben[lid]?.geaendert ?? frueh) {
                l.alben[lid] = Albumbild(asset: b.asset.flatMap { c2l[$0] }, geaendert: b.geaendert)
            }
        }
        return (l, e)
    }
}
