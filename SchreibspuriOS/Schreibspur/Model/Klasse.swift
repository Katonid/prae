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
    /// Klassencode, mit dem sich das Kind angemeldet hat (seit 1.0.12);
    /// nil auf einem Gerät ohne Klasse.
    var klasse: String? = nil

    static let tiere = ["🦊", "🐻", "🐸", "🦁", "🐧", "🐢", "🐰", "🐱", "🐶", "🐼", "🦉", "🐝",
                        "🐞", "🦄", "🐙", "🐬", "🐯", "🐨", "🐷", "🐮", "🐵", "🦒", "🐘", "🦔"]

    static func schluessel(_ zeichen: Zeichen, _ stufe: Stufe) -> String {
        "\(zeichen.id)#\(stufe.rawValue)"
    }
}

/// Wofür dieses Gerät da ist (seit 1.0.11, Ansage des Nutzers 09/2026:
/// „Die Kinder haben jeweils eigene Geräte und ich als Lehrer habe mein
/// eigenes Gerät“).
enum Geraeterolle: String {
    /// Ohne Klasse: ein Gerät, ein oder mehrere Kinder, alles bleibt hier
    /// (so war die App bis 1.0.10).
    case allein
    /// Gerät der Lehrkraft: Klassen mit Code, Übersicht aus iCloud.
    case lehrer
    /// Gerät eines Kindes (auf dem geteilten iPad: die Sitzung des Kindes),
    /// mit dem Klassencode angemeldet.
    case kind
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
    var lehrgangAn: Bool { didSet { speichern(); wolke?.klasseGeaendert() } }
    /// Letzter freigeschalteter Schritt (Index in `Zeichenvorrat.schritte`).
    var freiBis: Int { didSet { speichern(); wolke?.klasseGeaendert() } }

    private static let rollenSchluessel = "geraet.rolle"

    /// nil: noch nicht gewählt (erster Start) — dann fragt die App.
    var rolle: Geraeterolle? = nil {
        didSet { UserDefaults.standard.set(rolle?.rawValue, forKey: Klasse.rollenSchluessel) }
    }

    /// Die Lehrkraft probiert auf ihrem Gerät selbst aus: alle Stufen
    /// offen, nichts wird gezählt oder gespeichert.
    var probe = false

    /// Abgleich über iCloud (Lehrer- und Kindergerät), sonst nil.
    var wolke: Wolke? = nil

    /// Was jedes Kind bearbeitet hat, mit den Spuren (Klassenübersicht).
    let protokoll = Protokoll()

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
        if let wert = UserDefaults.standard.string(forKey: Klasse.rollenSchluessel) {
            rolle = Geraeterolle(rawValue: wert)
        } else if d.data(forKey: Klasse.schluessel) != nil {
            // Schon vor 1.0.11 benutzt: so weiter wie bisher.
            rolle = .allein
        }
        if kinder.count == 1, rolle != .lehrer { aktivID = kinder[0].id }
        protokoll.gespeichert = { [weak self] b, kind in self?.wolke?.bearbeitungGespeichert(b, kind: kind) }
    }

    var aktiv: Kind? { kinder.first { $0.id == aktivID } }

    // MARK: Fortschritt des aktiven Kindes

    func sterne(_ zeichen: Zeichen, _ stufe: Stufe) -> Int {
        aktiv?.sterne[Kind.schluessel(zeichen, stufe)] ?? 0
    }

    /// Höchste offene Stufe: die erste, die noch keine drei Sterne hat.
    func offeneStufe(_ zeichen: Zeichen) -> Stufe {
        let stufen = Stufe.stufen(fuer: zeichen)
        if probe { return stufen.last ?? .spur }
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
        wolke?.sterneGeaendert()
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

    /// Buchstaben für „Gemischt üben“: `anzahl` verschiedene schon
    /// gelernte, die mit wenig Sternen öfter. Jeder bekommt auf der
    /// Heftseite eine eigene Reihe.
    func mischungsBuchstaben(_ anzahl: Int) -> [Zeichen] {
        var bekannt = Zeichenvorrat.lehrgang
            .filter { $0.schritt <= bekannterSchritt }
            .flatMap { $0.zeichen }
        var wahl: [Zeichen] = []
        while wahl.count < anzahl, !bekannt.isEmpty {
            let gewichte = bekannt.map { CGFloat(1 + Stufe.allCases.count - gemeistert($0)) }
            var zufall = CGFloat.random(in: 0..<gewichte.reduce(0, +))
            var i = 0
            for (k, g) in gewichte.enumerated() {
                if zufall < g { i = k; break }
                zufall -= g
            }
            wahl.append(bekannt.remove(at: i))
        }
        return wahl
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
        wolke?.kindGeaendert(kind)
        return kind
    }

    func aendern(_ kind: Kind) {
        guard let i = kinder.firstIndex(where: { $0.id == kind.id }) else { return }
        kinder[i] = kind
        speichern()
        wolke?.kindGeaendert(kind)
    }

    func entfernen(_ id: UUID) {
        kinder.removeAll { $0.id == id }
        protokoll.loeschen(kind: id)
        wolke?.kindEntfernt(id)
        if kinder.isEmpty, rolle != .lehrer { kinder = [Kind(name: "Kind 1", tier: "🦊")] }
        if aktiv == nil { aktivID = kinder.count == 1 && rolle != .lehrer ? kinder[0].id : nil }
        speichern()
    }

    // MARK: Aus iCloud (ohne erneut hochzuladen)

    /// Ein Kind, wie es in iCloud steht. Sterne werden zusammengeführt
    /// (das Bessere gewinnt) — Sterne gehen nie verloren.
    func ausWolke(_ neu: Kind) {
        if let i = kinder.firstIndex(where: { $0.id == neu.id }) {
            var kind = neu
            kind.sterne = kinder[i].sterne.merging(neu.sterne) { max($0, $1) }
            kinder[i] = kind
        } else {
            kinder.append(neu)
        }
        speichern()
    }

    /// Sterne aus iCloud dazunehmen.
    func sterneAusWolke(_ sterne: [String: Int], kind id: UUID) {
        guard let i = kinder.firstIndex(where: { $0.id == id }) else { return }
        let neu = kinder[i].sterne.merging(sterne) { max($0, $1) }
        guard neu != kinder[i].sterne else { return }
        kinder[i].sterne = neu
        speichern()
    }

    func entferntInWolke(_ id: UUID) {
        kinder.removeAll { $0.id == id }
        protokoll.loeschen(kind: id)
        if aktivID == id { aktivID = nil }
        speichern()
    }

    /// Lehrgang, wie ihn die Lehrkraft eingestellt hat (Kindergerät).
    func lehrgangAusWolke(an: Bool, bis: Int) {
        let w = wolke
        wolke = nil   // nicht zurückmelden
        if lehrgangAn != an { lehrgangAn = an }
        let b = min(max(bis, 0), Zeichenvorrat.schritte.count - 1)
        if freiBis != b { freiBis = b }
        wolke = w
    }

    /// Kindergerät: dieses eine Kind schreibt hier.
    func alsKindGeraet(_ kind: Kind) {
        ausWolke(kind)
        aktivID = kind.id
    }

    /// Die geteilte Klasse beim Start (für die Annahme von Einladungen,
    /// die am Szenen-Delegaten ankommen).
    static let geteilt = Klasse()

    /// Abgleich starten, wenn dieses Gerät zu einer Klasse gehört.
    func wolkeStarten() {
        guard wolke == nil, let r = rolle, r != .allein else { return }
        wolke = Wolke(rolle: r, klasse: self)
    }

    /// Dieses Gerät wird das Gerät der Lehrkraft. Kinder, die hier schon
    /// angelegt sind, bleiben mit ihren Seiten sichtbar („ohne Klasse“);
    /// die Klasse meldet sich mit dem Klassencode selbst an.
    func alsLehrergeraet() {
        // Das unbenutzte „Kind 1“ vom ersten Start gehört nicht in die Klasse.
        kinder.removeAll { $0.name == "Kind 1" && $0.sterne.isEmpty && protokoll.bearbeitungen(von: $0.id).isEmpty }
        speichern()
        rolle = .lehrer
        aktivID = nil
        probe = false
        wolkeStarten()
    }

    /// Zurück zur Wahl beim ersten Start (Lehrergerät umstellen). Die
    /// Klasse in iCloud bleibt stehen.
    func rolleZuruecksetzen() {
        wolke = nil
        Wolke.vergessen()
        probe = false
        aktivID = nil
        rolle = nil
    }

    /// Kindergerät ohne Klasse (Lehrkraft hat das Kind entfernt): zurück
    /// zum Anfang.
    func klasseVerlassen() {
        kinder = [Kind(name: "Kind 1", tier: "🦊")]
        aktivID = nil
        rolle = nil
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
