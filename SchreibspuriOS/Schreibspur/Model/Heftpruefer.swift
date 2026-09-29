import CoreGraphics
import Foundation
import Observation

/// Prüft Stufe 5: Das Kind schreibt in eine Zeile in normaler Heftgröße —
/// ohne Spur, an beliebiger Stelle der Zeile. Geschrieben wird eine Folge
/// von Buchstaben: derselbe viermal, ein Wort oder eine gemischte Reihe.
/// Jeder Buchstabe wird für sich geprüft und legt die Vorlage neu an; der
/// nächste muss rechts vom vorigen beginnen.
///
/// Geprüft wird jeder Strich, sobald der Stift abhebt:
///
/// * **Lesbar:** Kind und Vorlage werden nach Weglänge gleich fein
///   abgetastet und Punkt für Punkt verglichen (Mittel und Spitze).
/// * **Schreibhaus:** Anfang und Ende jedes Strichs müssen auf der
///   richtigen Höhe liegen. Senkrecht wird die Vorlage nie angepasst.
/// * **Bewegungsrichtig:** Weil Punkt für Punkt in Schreibrichtung
///   verglichen wird, fällt ein andersherum geschriebenes O auf, obwohl es
///   fertig genauso aussieht. Die Strichfolge ist durch die Reihenfolge
///   der Vergleiche festgelegt.
///
/// Waagerecht legt sich die Vorlage an den ersten Ansatz und passt ihre
/// Breite an (Kinder schreiben schmaler oder breiter). Alle Maße in
/// Einheiten des Vierliniensystems (Oberlinie bis Grundlinie = 1) und
/// abgestimmt mit `scripts/heft-simulation.py` — dort stehen auch die
/// bekannten Grenzen (kurze Querstriche).
@Observable
final class Heftpruefer {

    enum Hinweis: Equatable {
        case andersherum
        case abgesetzt
        /// Der Strich beginnt auf der falschen Höhe; y der Vorlage.
        case anfang(CGFloat)
        /// Der Strich endet auf der falschen Höhe oder zu früh; y der Vorlage.
        case ende(CGFloat)
        case form
        case punkt
        case rechtsDaneben

        var text: String {
            switch self {
            case .andersherum: "Andersherum! Tipp auf ▶ und schau genau hin."
            case .abgesetzt: "Nicht absetzen – schreib den Strich in einem Zug."
            case .anfang(let y): "Dieser Strich beginnt \(Heftpruefer.ort(y))."
            case .ende(let y): "Dieser Strich endet \(Heftpruefer.ort(y))."
            case .form: "Das ist schwer zu lesen – schreib es noch einmal genau."
            case .punkt: "Setz den Punkt genau an seinen Platz."
            case .rechtsDaneben: "Schreib den nächsten Buchstaben rechts daneben."
            }
        }
    }

    /// Wo im Schreibhaus eine Höhe liegt — für die Hinweise.
    static func ort(_ y: CGFloat) -> String {
        switch y {
        case ..<0.12: "ganz oben unter dem Dach"
        case ..<0.36: "im Dachgeschoss"
        case ..<0.55: "an der Mittellinie"
        case ..<0.9: "im Erdgeschoss"
        case ..<1.12: "unten auf der Grundlinie"
        default: "unten im Keller"
        }
    }

    // Wie in scripts/heft-simulation.py
    static let n = 40
    private static let mittel: CGFloat = 0.1
    private static let spitze: CGFloat = 0.25
    private static let etage: CGFloat = 0.14
    private static let endeMax: CGFloat = 0.2
    /// Ab dieser Summe Σu² gilt die Breite als gesichert — kleiner, und das
    /// kurze erste Stück des y wurde zum Maßstab für das lange zweite.
    private static let fest: CGFloat = 1.5

    /// Die Buchstaben der Zeile in Schreibreihenfolge.
    let folge: [Zeichen]
    private let f: CGFloat
    /// Ansatz des ersten Strichs des zuletzt geschafften Buchstabens.
    private var letzterAnsatz: CGFloat?

    private(set) var strichNummer = 0
    private var ax: CGFloat?
    private var suv: CGFloat = 0
    private var suu: CGFloat = 0

    /// Geschaffte Buchstaben der Zeile (je Buchstabe die Striche).
    private(set) var fertige: [[[CGPoint]]] = []
    /// Angenommene Striche des Zeichens, an dem das Kind gerade schreibt.
    private(set) var tinte: [[CGPoint]] = []
    private(set) var aktuelleTinte: [CGPoint] = []
    private(set) var schreibtGerade = false

    private(set) var fehler = 0
    private(set) var hinweis: Hinweis?
    /// Bei welchem Buchstaben der letzte Fehler war.
    private(set) var hinweisBuchstabe: String?
    private(set) var fehlerZaehler = 0
    private(set) var strichZaehler = 0

    init(folge: [Zeichen], genauigkeit: Genauigkeit) {
        self.folge = folge
        f = genauigkeit.heftFaktor
    }

    var anzahl: Int { folge.count }
    var fertig: Bool { fertige.count >= anzahl }
    private var buchstabe: Zeichen { folge[min(fertige.count, folge.count - 1)] }
    private var vorlagen: [[CGPoint]] { buchstabe.striche.map(\.punkte) }
    private var x0: CGFloat { buchstabe.striche.first?.anfang.x ?? 0 }

    /// Hinweis mit dem Buchstaben davor, wenn die Zeile verschiedene hat
    /// („m: Dieser Strich beginnt …“).
    var hinweisText: String? {
        guard let hinweis else { return nil }
        let verschieden = Set(folge.map(\.id)).count > 1
        if verschieden, let b = hinweisBuchstabe { return "\(b): \(hinweis.text)" }
        return hinweis.text
    }

    var sterne: Int {
        switch fehler {
        case 0: 3
        case 1...2: 2
        default: 1
        }
    }

    // MARK: Eingabe

    func beginnen(bei p: CGPoint) {
        guard !fertig else { return }
        schreibtGerade = true
        aktuelleTinte = [p]
    }

    func bewegen(nach p: CGPoint) {
        guard schreibtGerade else { return }
        aktuelleTinte.append(p)
    }

    func beenden(bei p: CGPoint) {
        guard schreibtGerade else { return }
        aktuelleTinte.append(p)
        schreibtGerade = false
        let roh = aktuelleTinte
        aktuelleTinte = []
        if let fehlerArt = pruefen(roh) {
            fehler += 1
            hinweis = fehlerArt
            hinweisBuchstabe = buchstabe.text
            fehlerZaehler += 1
            // Das angefangene Zeichen beginnt neu; fertige bleiben stehen.
            tinte = []
            zeichenZuruecksetzen()
        } else {
            hinweis = nil
            tinte.append(roh)
            strichNummer += 1
            strichZaehler += 1
            if strichNummer >= vorlagen.count {
                letzterAnsatz = tinte.first?.first?.x
                fertige.append(tinte)
                tinte = []
                zeichenZuruecksetzen()
            }
        }
    }

    func abbrechen() {
        schreibtGerade = false
        aktuelleTinte = []
    }

    // MARK: Prüfung

    /// nil, wenn der Strich stimmt — sonst die Art des Fehlers.
    private func pruefen(_ roh: [CGPoint]) -> Hinweis? {
        let vorlage = vorlagen[strichNummer]

        if vorlage.count == 1 {  // i-Punkt, Umlautpunkte
            guard let ax else { return .form }
            let ziel = abbilden(vorlage, ax, breite())[0]
            let mitte = CGPoint(x: roh.map(\.x).reduce(0, +) / CGFloat(roh.count),
                                y: roh.map(\.y).reduce(0, +) / CGFloat(roh.count))
            if Self.laenge(roh) < 0.15 && mitte.abstand(zu: ziel) <= Self.etage * 1.4 * f { return nil }
            return .punkt
        }

        let p = Self.abtasten(roh)
        let t = Self.abtasten(vorlage)
        let erster = ax == nil
        // Ein neuer Buchstabe gehört rechts neben den vorigen.
        if erster, strichNummer == 0, let links = letzterAnsatz, roh[0].x < links + 0.15 {
            return .rechtsDaneben
        }
        let anker = erster ? p[0].x - (t[0].x - x0) : ax!

        // Breite: aus den schon angenommenen Strichen; nur wenn die noch
        // nichts sagen, aus diesem Strich — eng begrenzt, sonst schluckte
        // die Breite einen halb geschriebenen Querstrich.
        var neuUV = suv, neuUU = suu
        for (a, b) in zip(p, t) {
            let u = b.x - x0
            neuUV += u * (a.x - anker)
            neuUU += u * u
        }
        let sx: CGFloat
        if suu > Self.fest {
            sx = breite()
        } else {
            sx = neuUU > 0.02 ? min(1.25, max(0.8, neuUV / neuUU)) : 1
        }

        let tt = abbilden(t, anker, sx)
        let (mittel, spitze) = Self.vergleich(p, tt)
        let l = Self.laenge(vorlage)
        let endeRest = max(0.12, min(Self.endeMax, 0.25 * l) * sqrt(f))
        let etageEnde = min(Self.etage, max(0.08, 0.3 * l)) * f
        let anfangOK = abs(p[0].y - tt[0].y) <= Self.etage * f
            && (erster || abs(p[0].x - tt[0].x) <= Self.endeMax * f * 1.25)
        // Das Ende gemessen vom eigenen Anfang aus: zählt, ob der Strich lang
        // genug ist und in die richtige Richtung geht.
        let wegKind = CGPoint(x: p[p.count - 1].x - p[0].x, y: p[p.count - 1].y - p[0].y)
        let wegVorlage = CGPoint(x: tt[tt.count - 1].x - tt[0].x, y: tt[tt.count - 1].y - tt[0].y)
        let endeOK = abs(p[p.count - 1].y - tt[tt.count - 1].y) <= etageEnde
            && wegKind.abstand(zu: wegVorlage) <= endeRest

        if anfangOK && endeOK && mittel <= Self.mittel * f && spitze <= Self.spitze * f {
            ax = anker
            suv = neuUV
            suu = neuUU
            return nil
        }

        // Andersherum? Dann liegt das Ende des Kindes am Anfang der Vorlage.
        let ankerR = erster ? p[p.count - 1].x - (t[0].x - x0) : anker
        let tr = Array(abbilden(t, ankerR, sx).reversed())
        let mittelR = Self.vergleich(p, tr).mittel
        if mittelR <= Self.mittel * f * 1.3 && mittelR < mittel * 0.7 { return .andersherum }

        // Zu früh abgesetzt? Dann passt ein Anfangsstück der Vorlage.
        if anfangOK {
            for zehntel in 2...9 {
                let stueck = abbilden(Self.abtasten(Self.teil(vorlage, CGFloat(zehntel) / 10)), anker, sx)
                if Self.vergleich(p, stueck).mittel <= Self.mittel * f { return .abgesetzt }
            }
        }
        if !anfangOK { return .anfang(t[0].y) }
        if !endeOK { return .ende(t[t.count - 1].y) }
        return .form
    }

    private func breite() -> CGFloat {
        suu > Self.fest ? min(1.4, max(0.7, suv / suu)) : 1
    }

    private func abbilden(_ t: [CGPoint], _ anker: CGFloat, _ sx: CGFloat) -> [CGPoint] {
        t.map { CGPoint(x: anker + sx * ($0.x - x0), y: $0.y) }
    }

    private func zeichenZuruecksetzen() {
        strichNummer = 0
        ax = nil
        suv = 0
        suu = 0
    }

    // MARK: Geometrie

    private static func vergleich(_ a: [CGPoint], _ b: [CGPoint]) -> (mittel: CGFloat, spitze: CGFloat) {
        let d = zip(a, b).map { $0.abstand(zu: $1) }
        return (d.reduce(0, +) / CGFloat(max(d.count, 1)), d.max() ?? 0)
    }

    static func laenge(_ p: [CGPoint]) -> CGFloat {
        zip(p, p.dropFirst()).reduce(0) { $0 + $1.0.abstand(zu: $1.1) }
    }

    /// `n` Punkte in gleichen Weglängen-Abständen.
    static func abtasten(_ p: [CGPoint], _ anzahl: Int = n) -> [CGPoint] {
        guard p.count > 1 else { return Array(repeating: p.first ?? .zero, count: anzahl) }
        var l: [CGFloat] = [0]
        for i in 1..<p.count { l.append(l[i - 1] + p[i - 1].abstand(zu: p[i])) }
        let g = l[l.count - 1]
        guard g > 0 else { return Array(repeating: p[0], count: anzahl) }
        var aus: [CGPoint] = []
        var j = 0
        for i in 0..<anzahl {
            let s = g * CGFloat(i) / CGFloat(anzahl - 1)
            while j < l.count - 2 && l[j + 1] < s { j += 1 }
            let d = l[j + 1] - l[j]
            aus.append(p[j].mitte(zu: p[j + 1], anteil: d > 0 ? (s - l[j]) / d : 0))
        }
        return aus
    }

    /// Die ersten `anteil` der Weglänge.
    static func teil(_ p: [CGPoint], _ anteil: CGFloat) -> [CGPoint] {
        let g = laenge(p) * anteil
        var aus = [p[0]]
        var s: CGFloat = 0
        for (a, b) in zip(p, p.dropFirst()) {
            let d = a.abstand(zu: b)
            if s + d >= g {
                aus.append(a.mitte(zu: b, anteil: d > 0 ? (g - s) / d : 0))
                return aus
            }
            aus.append(b)
            s += d
        }
        return aus
    }
}
