import CoreData
import SwiftUI

// TAGEBÜCHER MIT FARBE (ab 1.0.8, Ansage des Nutzers 09/2026: „In Day One
// konnte ich sie einzeln anzeigen lassen und ihnen auch unterschiedliche
// Farben zuordnen. Dies möchte ich in dieser App auch tun können.“)
//
// Ein Tagebuch ist weiterhin der NAME am Eintrag (`Eintrag.tagebuch`, ab
// 1.0.7) — es existiert, solange ein Eintrag ihn trägt. Neu ist ein kleiner
// Datensatz `Buch` daneben, der nur sagt, welche Farbe dieser Name hat. Er
// liegt im PRIVATEN Speicher und reist über iCloud zu den eigenen Geräten;
// eine Farbe ist eine persönliche Einstellung und geht Miturlauber nichts an.
//
// Zugeordnet wird über den Namen, nicht über eine Beziehung: Die Einträge
// eines Tagebuchs liegen in zwei Speichern (privat und in geteilten Reisen),
// und eine Beziehung über zwei Speicher weist Core Data ab.
//
// Hat ein Tagebuch keinen `Buch`-Datensatz, bekommt es eine Farbe aus seinem
// Namen — aus den BYTES des Namens, nie aus `hashValue` (den streut Swift je
// Programmlauf neu; das Tagebuch hätte nach jedem Start eine andere Farbe).
// So stehen die aus Day One übernommenen Tagebücher sofort verschieden da.
//
// **Zwei Geräte können denselben Namen gleichzeitig einfärben** — CloudKit
// kennt keine Eindeutigkeit. Dann gilt der zuletzt geänderte Datensatz.

@objc(Buch)
final class Buch: NSManagedObject {
    @NSManaged var kennung: UUID?
    @NSManaged var name: String?
    @NSManaged var farbe: String?
    @NSManaged var geaendert: Date?
    /// ab 1.0.10 — `Kennwort.ableiten(…)`, leer heißt „kein Schloss“.
    @NSManaged var schloss: String?
    @NSManaged var schlossBiometrie: Bool

    static func alle() -> NSFetchRequest<Buch> {
        NSFetchRequest<Buch>(entityName: "Buch")
    }
}

extension Buch: Identifiable { var id: NSManagedObjectID { objectID } }

/// Die Farben, aus denen ein Tagebuch wählt. Zwölf, deutlich voneinander
/// verschieden — mehr lassen sich auf einer Karte nicht auseinanderhalten.
enum Buchfarbe: String, CaseIterable, Identifiable {
    case rot, orange, gelb, gruen, mint, tuerkis, blau, indigo, violett, rosa, braun, grau

    var id: String { rawValue }

    var name: String {
        switch self {
        case .rot: return "Rot"
        case .orange: return "Orange"
        case .gelb: return "Gelb"
        case .gruen: return "Grün"
        case .mint: return "Mint"
        case .tuerkis: return "Türkis"
        case .blau: return "Blau"
        case .indigo: return "Indigo"
        case .violett: return "Violett"
        case .rosa: return "Rosa"
        case .braun: return "Braun"
        case .grau: return "Grau"
        }
    }

    var farbe: Color {
        switch self {
        case .rot: return Color(hex: 0xE5484D)
        case .orange: return Color(hex: 0xF76B15)
        case .gelb: return Color(hex: 0xD6A000)
        case .gruen: return Color(hex: 0x30A46C)
        case .mint: return Color(hex: 0x12A594)
        case .tuerkis: return Color(hex: 0x0D9BC4)
        case .blau: return Color(hex: 0x0B6BCB)
        case .indigo: return Color(hex: 0x3E63DD)
        case .violett: return Color(hex: 0x8E4EC6)
        case .rosa: return Color(hex: 0xD6409F)
        case .braun: return Color(hex: 0x9E6C3A)
        case .grau: return Color(hex: 0x6F6E77)
        }
    }

    /// Die Farbe, die ein Name ohne eigene Wahl bekommt — stabil über
    /// Programmläufe und Geräte (FNV-1a über die UTF-8-Bytes, dazu ein
    /// Mischschritt, damit Namen, die sich nur im letzten Zeichen
    /// unterscheiden, nicht nebeneinander landen).
    static func vorschlag(fuer name: String) -> Buchfarbe {
        var h: UInt64 = 0xcbf2_9ce4_8422_2325
        for b in name.utf8 { h ^= UInt64(b); h = h &* 0x0000_0100_0000_01B3 }
        h ^= h >> 33; h = h &* 0xff51_afd7_ed55_8ccd; h ^= h >> 33
        return allCases[Int(h % UInt64(allCases.count))]
    }
}

/// Die Farben aller Tagebücher, an EINER Stelle nachgeschlagen — von der
/// Karte, der Leseansicht, dem Editor und der Übersicht.
final class Buecherei: ObservableObject {
    static let shared = Buecherei()

    /// Name → gewählte Farbe. Namen ohne Eintrag hier bekommen den Vorschlag.
    @Published private(set) var gewaehlt: [String: Buchfarbe] = [:]

    struct Schloss: Equatable {
        let wert: String
        let biometrie: Bool
    }

    /// Name → Schloss (ab 1.0.10). Reist mit dem `Buch` über iCloud.
    @Published private(set) var schloesser: [String: Schloss] = [:]

    /// Die Tagebücher, die auf DIESEM Gerät gerade offen sind. Nur im
    /// Speicher: Beim Wechsel in den Hintergrund geht alles wieder zu
    /// (`alleSperren`, aus `FernwehApp`), und nach einem Neustart ist ohnehin
    /// alles zu. Ein Schloss, das offen bleibt, weil das iPad auf dem
    /// Küchentisch liegt, ist keines.
    @Published private(set) var offen: Set<String> = []

    private init() {
        neuLesen()
        NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextObjectsDidChange,
            object: Persistenz.shared.kontext, queue: .main
        ) { [weak self] meldung in
            guard let self else { return }
            // Nur neu lesen, wenn wirklich ein Buch betroffen ist — die
            // Meldung kommt bei jeder Änderung an jedem Eintrag.
            let schluessel = [NSInsertedObjectsKey, NSUpdatedObjectsKey, NSDeletedObjectsKey, NSRefreshedObjectsKey]
            let betroffen = schluessel.contains { k in
                ((meldung.userInfo?[k] as? Set<NSManagedObject>) ?? []).contains { $0 is Buch }
            }
            if betroffen { self.neuLesen() }
        }
    }

    private func neuLesen() {
        let buecher = (try? Persistenz.shared.kontext.fetch(Buch.alle())) ?? []
        var neu: [String: (Buchfarbe, Date)] = [:]
        // Das Schloss kommt vom zuletzt geänderten Datensatz des Namens —
        // unabhängig davon, ob der eine gültige Farbe trägt.
        var schloss: [String: (Schloss?, Date)] = [:]
        for b in buecher where !b.isDeleted {
            let name = (b.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            let wann = b.geaendert ?? .distantPast
            if schloss[name].map({ $0.1 < wann }) ?? true {
                let wert = b.schloss ?? ""
                schloss[name] = (wert.isEmpty ? nil : Schloss(wert: wert, biometrie: b.schlossBiometrie), wann)
            }
            guard let f = Buchfarbe(rawValue: b.farbe ?? "") else { continue }
            if let alt = neu[name], alt.1 >= wann { continue }
            neu[name] = (f, wann)
        }
        let ergebnis = neu.mapValues(\.0)
        if ergebnis != gewaehlt { gewaehlt = ergebnis }
        let schlossNeu = schloss.compactMapValues(\.0)
        if schlossNeu != schloesser { schloesser = schlossNeu }
        // Ein Schloss, das es nicht mehr gibt, ist auch nicht mehr offen.
        let nochOffen = offen.intersection(schlossNeu.keys)
        if nochOffen != offen { offen = nochOffen }
    }

    // MARK: - Schloss (ab 1.0.10)

    /// Hat dieses Tagebuch ein Passwort — offen oder zu?
    func istGeschuetzt(_ name: String?) -> Bool {
        guard let name, !name.isEmpty else { return false }
        return schloesser[name] != nil
    }

    /// Ist es gerade ZU? Nur das entscheidet, ob ein Eintrag zu sehen ist.
    func istGesperrt(_ name: String?) -> Bool {
        guard let name, istGeschuetzt(name) else { return false }
        return !offen.contains(name)
    }

    func darfBiometrie(_ name: String) -> Bool { schloesser[name]?.biometrie ?? false }

    /// Prüft das Passwort und öffnet bei Erfolg. Die Ableitung kostet eine
    /// Zehntelsekunde und läuft deshalb abseits des Hauptfadens.
    @MainActor
    func oeffnen(_ name: String, passwort: String) async -> Bool {
        guard let wert = schloesser[name]?.wert else { return true }
        let richtig = await Task.detached(priority: .userInitiated) {
            Kennwort.pruefen(passwort, gegen: wert)
        }.value
        if richtig { oeffnen(name) }
        return richtig
    }

    /// Öffnen ohne Passwort — nur nach bestandener Biometrie aufrufen.
    func oeffnen(_ name: String) { offen.insert(name) }

    func sperren(_ name: String) { offen.remove(name) }

    func alleSperren() { if !offen.isEmpty { offen = [] } }

    /// Ein Schloss anlegen oder das Passwort ändern. Das Tagebuch ist danach
    /// offen — wer gerade ein Passwort vergeben hat, will weiterlesen.
    @MainActor
    func schuetzen(_ name: String, passwort: String, biometrie: Bool) async {
        let wert = await Task.detached(priority: .userInitiated) { Kennwort.ableiten(passwort) }.value
        let buch = datensatz(name)
        buch.schloss = wert
        buch.schlossBiometrie = biometrie
        buch.geaendert = Date()
        Persistenz.shared.sichern()
        offen.insert(name)
    }

    func biometrieSetzen(_ name: String, _ an: Bool) {
        guard istGeschuetzt(name) else { return }
        let buch = datensatz(name)
        buch.schlossBiometrie = an
        buch.geaendert = Date()
        Persistenz.shared.sichern()
    }

    func schutzEntfernen(_ name: String) {
        let buch = datensatz(name)
        buch.schloss = ""
        buch.schlossBiometrie = false
        buch.geaendert = Date()
        Persistenz.shared.sichern()
        offen.remove(name)
    }

    /// Der eine `Buch`-Datensatz zu einem Namen — angelegt, wenn es keinen
    /// gibt, samt der Farbe, die der Name gerade hat (sonst verlöre er sie:
    /// `neuLesen` nimmt die Farbe vom neuesten Datensatz). Doppel von zwei
    /// Geräten werden dabei aufgeräumt, wie in `setzen`.
    private func datensatz(_ name: String) -> Buch {
        let p = Persistenz.shared
        let vorhanden = datensaetze(name)
            .sorted { ($0.geaendert ?? .distantPast) > ($1.geaendert ?? .distantPast) }
        let buch = vorhanden.first ?? p.anlegen(Buch.self, bei: nil)
        if buch.kennung == nil { buch.kennung = UUID() }
        buch.name = name
        if Buchfarbe(rawValue: buch.farbe ?? "") == nil { buch.farbe = buchfarbe(name).rawValue }
        for doppel in vorhanden.dropFirst() { p.kontext.delete(doppel) }
        return buch
    }

    func buchfarbe(_ name: String) -> Buchfarbe {
        gewaehlt[name] ?? Buchfarbe.vorschlag(fuer: name)
    }

    /// Die Farbe eines Tagebuchs — `nil`, wenn der Eintrag in keinem steht.
    func farbe(_ name: String?) -> Color? {
        guard let name, !name.isEmpty else { return nil }
        return buchfarbe(name).farbe
    }

    /// Alle `Buch`-Datensätze zu einem Namen (Doppel von zwei Geräten mit).
    private func datensaetze(_ name: String) -> [Buch] {
        let anfrage = Buch.alle()
        anfrage.predicate = NSPredicate(format: "name == %@", name)
        return (try? Persistenz.shared.kontext.fetch(anfrage)) ?? []
    }

    func setzen(_ farbe: Buchfarbe, fuer name: String) {
        // Über `datensatz`: der neueste Datensatz bleibt, Doppel gehen —
        // sonst gewänne auf einem anderen Gerät vielleicht wieder die alte
        // Farbe, und seit 1.0.10 ginge dabei womöglich das Schloss verloren.
        let buch = datensatz(name)
        buch.farbe = farbe.rawValue
        buch.geaendert = Date()
        Persistenz.shared.sichern()
    }

    struct Umbenennung {
        let umbenannt: Int
        let gesperrt: Int
    }

    /// Ein Tagebuch umbenennen: jeder Eintrag, den ich bearbeiten darf,
    /// bekommt den neuen Namen. Heißt schon ein Tagebuch so, werden die
    /// beiden zusammengelegt — die Farbe des Ziels bleibt.
    func umbenennen(_ alt: String, zu neu: String) -> Umbenennung {
        let p = Persistenz.shared
        let anfrage = NSFetchRequest<Eintrag>(entityName: "Eintrag")
        anfrage.predicate = NSPredicate(format: "tagebuch == %@", alt)
        let betroffen = (try? p.kontext.fetch(anfrage)) ?? []
        var umbenannt = 0, gesperrt = 0
        for e in betroffen {
            if p.darfBearbeiten(e) { e.tagebuch = neu; e.geaendert = Date(); umbenannt += 1 } else { gesperrt += 1 }
        }
        let alteFarbe = gewaehlt[alt] ?? Buchfarbe.vorschlag(fuer: alt)
        let zielHatFarbe = !datensaetze(neu).isEmpty
        // Das Schloss zieht mit um (ab 1.0.10) — sonst stünden die Einträge
        // nach dem Umbenennen offen da. Hat das Ziel ein eigenes, gilt das.
        let altesSchloss = schloesser[alt]
        let zielHatSchloss = schloesser[neu] != nil
        let warOffen = offen.contains(alt)
        // Solange noch Einträge unter dem alten Namen stehen (in einer Reise,
        // in der ich nur lese), bleibt dessen Farbe ebenfalls stehen.
        if gesperrt == 0 { for b in datensaetze(alt) { p.kontext.delete(b) } }
        p.sichern()
        if !zielHatFarbe { setzen(alteFarbe, fuer: neu) }
        if let altesSchloss, !zielHatSchloss {
            let buch = datensatz(neu)
            buch.schloss = altesSchloss.wert
            buch.schlossBiometrie = altesSchloss.biometrie
            buch.geaendert = Date()
            p.sichern()
            if warOffen { offen.insert(neu) }
        }
        return Umbenennung(umbenannt: umbenannt, gesperrt: gesperrt)
    }
}
