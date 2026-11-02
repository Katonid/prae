import CoreLocation
import Foundation
import Observation

/// Die laufende Sitzung „Fehlende Standorte ergänzen“.
struct ErgaenzenSitzung: Codable, Equatable {
    /// `nil` = gesamter Bestand.
    var zeitraum: Zeitraum?
    /// Die gefundenen Fotos in Bearbeitungsreihenfolge.
    var ids: [String]
    var erledigt: Set<String> = []
    var uebersprungen: Set<String> = []
    /// Das zuletzt angezeigte Foto — dort geht es nach einem Neustart weiter.
    var zuletzt: String?
    var untersucht: Int
    var ohneStandort: Int
    var nichtAenderbar: Int
    var aufsteigend: Bool = true
    var erstellt: Date = Date()

    var offen: Int { max(ids.count - erledigt.count, 0) }

    var zeitraumText: String { zeitraum?.text ?? "Gesamter Bestand" }
}

/// Eine einzelne, erfolgreich gespeicherte Standortänderung.
struct Aenderung: Codable, Identifiable, Equatable {
    var id = UUID()
    var assetID: String
    var fotoDatum: Date?
    var vorher: GespeicherterOrt?
    var nachher: GespeicherterOrt?
    var zeitpunkt = Date()
}

/// Der Standort, den ein Foto hatte, bevor PhotoLocator es zum ersten Mal
/// geändert hat. `ort == nil` heißt: Es hatte ursprünglich keinen.
struct Ursprung: Codable, Equatable {
    var ort: GespeicherterOrt?
}

enum Bearbeitungsstatus {
    case offen, erledigt, uebersprungen, ausserhalb
}

/// Bewahrt Bearbeitungsfortschritt, Änderungsverlauf und letzten Standort
/// über Neustarts hinweg auf (JSON-Datei in „Application Support“).
///
/// Jede Änderung wird sofort gesichert. Wird die App mitten in der Arbeit
/// beendet, ist nichts verloren (Abnahmetest F).
@MainActor
@Observable
final class Sitzungsspeicher {
    private(set) var laufend: ErgaenzenSitzung?
    private(set) var verlauf: [Aenderung] = []
    private(set) var ursprung: [String: Ursprung] = [:]
    private(set) var letzterOrt: GespeicherterOrt?

    @ObservationIgnored private let datei: URL
    @ObservationIgnored private let schreiber = DispatchQueue(label: "photolocator.sitzung", qos: .utility)

    /// So viele Änderungen bleiben im Verlauf (und damit rückgängig machbar).
    static let verlaufGrenze = 2000

    private struct Stand: Codable {
        var laufend: ErgaenzenSitzung?
        var verlauf: [Aenderung]
        var ursprung: [String: Ursprung]
        var letzterOrt: GespeicherterOrt?
    }

    init(datei: URL? = nil) {
        self.datei = datei ?? Self.standardDatei()
        if let daten = try? Data(contentsOf: self.datei),
           let stand = try? JSONDecoder().decode(Stand.self, from: daten) {
            laufend = stand.laufend
            verlauf = stand.verlauf
            ursprung = stand.ursprung
            letzterOrt = stand.letzterOrt
        }
    }

    private static func standardDatei() -> URL {
        let basis = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let ordner = basis.appendingPathComponent("PhotoLocator", isDirectory: true)
        try? FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        return ordner.appendingPathComponent("sitzung.json")
    }

    private func sichern() {
        let stand = Stand(laufend: laufend, verlauf: verlauf, ursprung: ursprung, letzterOrt: letzterOrt)
        guard let daten = try? JSONEncoder().encode(stand) else { return }
        let ziel = datei
        schreiber.async {
            try? daten.write(to: ziel, options: .atomic)
        }
    }

    /// Wartet, bis alles geschrieben ist (für Tests).
    func warteAufSicherung() {
        schreiber.sync {}
    }

    // MARK: - Sitzung „Ergänzen“

    func sitzungBeginnen(_ sitzung: ErgaenzenSitzung) {
        laufend = sitzung
        sichern()
    }

    func sitzungBeenden() {
        laufend = nil
        sichern()
    }

    /// Gleicht die gespeicherte Sitzung mit der Mediathek ab: Gelöschte
    /// Fotos fallen heraus; erledigt ist, was jetzt einen Standort hat —
    /// auch wenn er in der Fotos-App gesetzt wurde.
    func abgleichen(ids: [String], mitOrt: Set<String>) {
        guard var s = laufend else { return }
        let menge = Set(ids)
        s.ids = ids
        s.erledigt = mitOrt.intersection(menge)
        s.uebersprungen = s.uebersprungen.intersection(menge).subtracting(s.erledigt)
        if let z = s.zuletzt, !menge.contains(z) { s.zuletzt = nil }
        laufend = s
        sichern()
    }

    func gehoertZurSitzung(_ id: String) -> Bool {
        laufend?.ids.contains(id) ?? false
    }

    func status(_ id: String) -> Bearbeitungsstatus {
        guard let s = laufend else { return .ausserhalb }
        if s.erledigt.contains(id) { return .erledigt }
        if s.uebersprungen.contains(id) { return .uebersprungen }
        return .offen
    }

    func alsErledigt(_ id: String) {
        guard var s = laufend, s.ids.contains(id) else { return }
        s.erledigt.insert(id)
        s.uebersprungen.remove(id)
        laufend = s
        sichern()
    }

    func alsOffen(_ id: String) {
        guard var s = laufend, s.erledigt.contains(id) else { return }
        s.erledigt.remove(id)
        laufend = s
        sichern()
    }

    func ueberspringen(_ id: String) {
        guard var s = laufend, s.ids.contains(id), !s.erledigt.contains(id) else { return }
        s.uebersprungen.insert(id)
        laufend = s
        sichern()
    }

    func aktuell(_ id: String) {
        guard var s = laufend, s.zuletzt != id else { return }
        s.zuletzt = id
        laufend = s
        sichern()
    }

    func sortierung(aufsteigend: Bool, ids: [String]) {
        guard var s = laufend else { return }
        s.aufsteigend = aufsteigend
        s.ids = ids
        laufend = s
        sichern()
    }

    // MARK: - Verlauf und Rückgängig

    /// Hält eine erfolgreich gespeicherte Änderung fest.
    func erfassen(assetID: String, fotoDatum: Date?, vorher: CLLocation?, nachher: CLLocation?) {
        let alt = vorher.map(GespeicherterOrt.init)
        if ursprung[assetID] == nil {
            ursprung[assetID] = Ursprung(ort: alt)
        }
        verlauf.append(Aenderung(
            assetID: assetID,
            fotoDatum: fotoDatum,
            vorher: alt,
            nachher: nachher.map(GespeicherterOrt.init)
        ))
        if verlauf.count > Self.verlaufGrenze {
            verlauf.removeFirst(verlauf.count - Self.verlaufGrenze)
        }
        if let nachher {
            letzterOrt = GespeicherterOrt(nachher)
        }
        sichern()
    }

    /// Entfernt eine Änderung aus dem Verlauf, nachdem sie erfolgreich
    /// zurückgenommen wurde.
    func rueckgaengigErfasst(_ aenderung: Aenderung) {
        verlauf.removeAll { $0.id == aenderung.id }
        sichern()
    }

    /// Alle in dieser Sitzung bearbeiteten Fotos, neueste Änderung zuerst.
    var bearbeiteteIDs: [String] {
        var gesehen = Set<String>()
        return verlauf.reversed().compactMap { gesehen.insert($0.assetID).inserted ? $0.assetID : nil }
    }

    func verlaufLoeschen() {
        verlauf = []
        ursprung = [:]
        letzterOrt = nil
        sichern()
    }
}
