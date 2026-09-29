import Foundation
import Observation

/// Ein Kind mit eigenem Fortschritt. Kinder, die noch nicht lesen, finden
/// sich über ihr Tier.
struct Kind: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var tier: String
    var genauigkeit: Genauigkeit = .normal
    /// Beste Sternzahl je Zeichen und Stufe, Schlüssel „A#1“.
    var sterne: [String: Int] = [:]

    static let tiere = ["🦊", "🐻", "🐸", "🦁", "🐧", "🐢", "🐰", "🐱", "🐶", "🐼", "🦉", "🐝",
                        "🐞", "🦄", "🐙", "🐬", "🐯", "🐨", "🐷", "🐮", "🐵", "🦒", "🐘", "🦔"]

    static func schluessel(_ zeichen: Zeichen, _ stufe: Stufe) -> String {
        "\(zeichen.id)#\(stufe.rawValue)"
    }
}

/// Alle Kinder an diesem Gerät, wer gerade schreibt, und wie weit der
/// Lehrgang freigeschaltet ist.
///
/// Gespeichert als JSON in den Voreinstellungen — ein Klassen-iPad hat
/// kaum mehr als dreißig Kinder, dafür braucht es keine Datenbank.
@Observable
final class Klasse {
    private struct Stand: Codable {
        var kinder: [Kind]
        var lehrgangAn: Bool
        var freiBis: Int
    }

    private static let schluessel = "klasse.v1"
    /// Sterne aus Fassung 1.0.x, bevor es Profile gab.
    private static let alterSchluessel = "fortschritt.sterne"

    private(set) var kinder: [Kind]
    /// Nur Buchstaben bis zur freigeschalteten Lektion sind offen.
    var lehrgangAn: Bool { didSet { speichern() } }
    /// Letzte freigeschaltete Lektion (Index in `Zeichenvorrat.lehrgang`).
    var freiBis: Int { didSet { speichern() } }

    /// Wer gerade schreibt. Absichtlich nicht gespeichert: Am Klassen-iPad
    /// wählt jedes Kind sich beim Öffnen selbst.
    var aktivID: UUID?

    init() {
        let d = UserDefaults.standard
        if let daten = d.data(forKey: Klasse.schluessel),
           let stand = try? JSONDecoder().decode(Stand.self, from: daten) {
            kinder = stand.kinder
            lehrgangAn = stand.lehrgangAn
            freiBis = stand.freiBis
        } else {
            // Erster Start oder Umstieg von 1.0.x: ein Kind anlegen und die
            // alten Sterne als Sterne der ersten Stufe übernehmen.
            var kind = Kind(name: "Kind 1", tier: "🦊")
            if let alt = d.dictionary(forKey: Klasse.alterSchluessel) as? [String: Int] {
                for (zeichen, sterne) in alt { kind.sterne["\(zeichen)#1"] = sterne }
            }
            kinder = [kind]
            lehrgangAn = false
            freiBis = 0
        }
        if kinder.count == 1 { aktivID = kinder[0].id }
    }

    var aktiv: Kind? { kinder.first { $0.id == aktivID } }

    // MARK: Fortschritt des aktiven Kindes

    func sterne(_ zeichen: Zeichen, _ stufe: Stufe) -> Int {
        aktiv?.sterne[Kind.schluessel(zeichen, stufe)] ?? 0
    }

    /// Höchste offene Stufe: die erste, die noch keine drei Sterne hat.
    func offeneStufe(_ zeichen: Zeichen) -> Stufe {
        let stufen = Stufe.stufen(fuer: zeichen)
        for stufe in stufen where sterne(zeichen, stufe) < 3 { return stufe }
        return stufen.last ?? .spur
    }

    /// Stufen mit drei Sternen — für die Punkte unter den Kacheln.
    func gemeistert(_ zeichen: Zeichen) -> Int {
        Stufe.stufen(fuer: zeichen).filter { sterne(zeichen, $0) == 3 }.count
    }

    func geuebt(_ zeichen: Zeichen) -> Bool {
        Stufe.stufen(fuer: zeichen).contains { sterne(zeichen, $0) > 0 }
    }

    func eintragen(_ anzahl: Int, _ zeichen: Zeichen, _ stufe: Stufe) {
        guard let i = kinder.firstIndex(where: { $0.id == aktivID }) else { return }
        let s = Kind.schluessel(zeichen, stufe)
        guard anzahl > kinder[i].sterne[s] ?? 0 else { return }
        kinder[i].sterne[s] = anzahl
        speichern()
    }

    var genauigkeit: Genauigkeit { aktiv?.genauigkeit ?? .normal }

    // MARK: Lehrgang

    /// Ob ein Zeichen im Unterricht schon dran war. Schwünge und Ziffern
    /// sind immer offen.
    func istOffen(_ zeichen: Zeichen) -> Bool {
        guard lehrgangAn, let lektion = Zeichenvorrat.lektion(von: zeichen) else { return true }
        return lektion <= freiBis
    }

    // MARK: Kinder verwalten

    @discardableResult
    func hinzufuegen() -> Kind {
        let frei = Kind.tiere.first { t in !kinder.contains { $0.tier == t } } ?? Kind.tiere[0]
        let kind = Kind(name: "Kind \(kinder.count + 1)", tier: frei)
        kinder.append(kind)
        speichern()
        return kind
    }

    func aendern(_ kind: Kind) {
        guard let i = kinder.firstIndex(where: { $0.id == kind.id }) else { return }
        kinder[i] = kind
        speichern()
    }

    func entfernen(_ id: UUID) {
        kinder.removeAll { $0.id == id }
        if kinder.isEmpty { kinder = [Kind(name: "Kind 1", tier: "🦊")] }
        if aktiv == nil { aktivID = kinder.count == 1 ? kinder[0].id : nil }
        speichern()
    }

    func sterneLoeschen(_ id: UUID) {
        guard let i = kinder.firstIndex(where: { $0.id == id }) else { return }
        kinder[i].sterne = [:]
        speichern()
    }

    private func speichern() {
        let stand = Stand(kinder: kinder, lehrgangAn: lehrgangAn, freiBis: freiBis)
        if let daten = try? JSONEncoder().encode(stand) {
            UserDefaults.standard.set(daten, forKey: Klasse.schluessel)
        }
    }
}
