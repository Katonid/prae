import CoreGraphics
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
        /// Seit 1.0.4 zählt `freiBis` die Schritte des Merkblatts (mit Au,
        /// Sch …), vorher die Buchstaben-Lektionen. nil = alter Stand.
        var freiBisInSchritten: Bool?
    }

    private static let schluessel = "klasse.v1"
    /// Sterne aus Fassung 1.0.x, bevor es Profile gab.
    private static let alterSchluessel = "fortschritt.sterne"

    private(set) var kinder: [Kind]
    /// Nur Buchstaben bis zur freigeschalteten Lektion sind offen.
    var lehrgangAn: Bool { didSet { speichern() } }
    /// Letzter freigeschalteter Schritt (Index in `Zeichenvorrat.schritte`).
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
            if stand.freiBisInSchritten == true {
                freiBis = min(stand.freiBis, Zeichenvorrat.schritte.count - 1)
            } else {
                let lektionen = Zeichenvorrat.lehrgang
                freiBis = lektionen[min(max(stand.freiBis, 0), lektionen.count - 1)].schritt
            }
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
        guard let i = kinder.firstIndex(where: { $0.id == aktivID }),
              zeichen.id != Klasse.mischungID else { return }  // jede Mischung ist anders
        let s = Kind.schluessel(zeichen, stufe)
        guard anzahl > kinder[i].sterne[s] ?? 0 else { return }
        kinder[i].sterne[s] = anzahl
        speichern()
    }

    var genauigkeit: Genauigkeit { aktiv?.genauigkeit ?? .normal }

    // MARK: Lehrgang

    /// Bis zu welchem Schritt des Merkblatts gelernt wurde — ohne Lehrgang
    /// alles.
    var bekannterSchritt: Int {
        lehrgangAn ? freiBis : Zeichenvorrat.schritte.count - 1
    }

    /// Ob ein Zeichen im Unterricht schon dran war. Schwünge, Ziffern und
    /// Wörter (die ohnehin nur aus Bekanntem bestehen) sind immer offen.
    func istOffen(_ zeichen: Zeichen) -> Bool {
        guard lehrgangAn, let schritt = Zeichenvorrat.schritt(von: zeichen) else { return true }
        return schritt <= freiBis
    }

    /// Was im Bereich zu sehen ist. Wörter: nur solche aus schon gelernten
    /// Buchstaben und Verbindungen, die neuesten zuerst.
    func zeichen(in bereich: Bereich) -> [Zeichen] {
        guard bereich == .woerter else { return bereich.zeichen }
        let grenze = bekannterSchritt
        return Zeichenvorrat.woerter
            .filter { $0.schritt <= grenze }
            .sorted { $0.schritt > $1.schritt }
            .map { $0.wort }
    }

    /// Eine Reihe aus sechs schon gelernten Buchstaben zum Wiederholen.
    /// Buchstaben mit wenig Sternen kommen häufiger dran; derselbe nie
    /// zweimal hintereinander.
    func mischung() -> Zeichen {
        let bekannt = Zeichenvorrat.lehrgang
            .filter { $0.schritt <= bekannterSchritt }
            .flatMap { $0.zeichen }
        guard !bekannt.isEmpty else { return Zeichenvorrat.folge(id: Klasse.mischungID, [], abstand: 0.5) }
        let gewichte = bekannt.map { CGFloat(1 + Stufe.allCases.count - gemeistert($0)) }
        var reihe: [Zeichen] = []
        while reihe.count < 6 {
            var zufall = CGFloat.random(in: 0..<gewichte.reduce(0, +))
            var wahl = bekannt[0]
            for (z, g) in zip(bekannt, gewichte) {
                if zufall < g { wahl = z; break }
                zufall -= g
            }
            if bekannt.count > 1, reihe.last?.id == wahl.id { continue }
            reihe.append(wahl)
        }
        return Zeichenvorrat.folge(id: Klasse.mischungID, reihe, abstand: 0.5)
    }

    static let mischungID = "Gemischt"

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
        let stand = Stand(kinder: kinder, lehrgangAn: lehrgangAn, freiBis: freiBis, freiBisInSchritten: true)
        if let daten = try? JSONEncoder().encode(stand) {
            UserDefaults.standard.set(daten, forKey: Klasse.schluessel)
        }
    }
}
