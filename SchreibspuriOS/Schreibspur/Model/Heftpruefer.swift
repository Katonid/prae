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
/// Waagerecht legt sich die Vorlage so über den ersten Strich, dass sie am
/// besten passt, und passt ihre Breite an (Kinder schreiben schmaler oder
/// breiter); weitere Striche dürfen etwas daneben liegen und etwas länger
/// oder kürzer sein. Senkrecht wird nichts angepasst. Alle Maße in
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
        case nebenMuster

        var text: String {
            switch self {
            case .andersherum: "Andersherum! Tipp auf ▶ und schau genau hin."
            case .abgesetzt: "Nicht absetzen – schreib den Strich in einem Zug."
            case .anfang(let y): "Dieser Strich beginnt \(Heftpruefer.ort(y))."
            case .ende(let y): "Dieser Strich endet \(Heftpruefer.ort(y))."
            case .form: "Das ist schwer zu lesen – schreib es noch einmal genau."
            case .punkt: "Setz den Punkt genau an seinen Platz."
            case .rechtsDaneben: "Schreib den nächsten Buchstaben rechts daneben."
            case .nebenMuster: "Schreib rechts neben das Muster."
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

    // Wie in scripts/heft-simulation.py — dort abgestimmt und begründet.
    static let n = 40
    // Eingestellt auf echte Anfängerschrift (schief, zu groß oder klein,
    // Striche treffen sich nicht, Anfang daneben) — Ansage des Nutzers:
    // „Lernanfänger schreiben nicht so ordentlich.“
    private static let mittel: CGFloat = 0.18
    private static let spitze: CGFloat = 0.42
    private static let etage: CGFloat = 0.25
    private static let endeMax: CGFloat = 0.3
    /// Ab dieser Summe Σu² gilt die Breite als gesichert — kleiner, und das
    /// kurze erste Stück des y wurde zum Maßstab für das lange zweite.
    private static let fest: CGFloat = 1.5
    /// Nur so breite Striche bestimmen die Schriftbreite (der Haken oben
    /// am f war sonst ein wackliger Maßstab für den Querstrich).
    private static let breit: CGFloat = 0.4
    /// So weit darf ein weiterer Strich waagerecht neben seinem Platz liegen.
    private static let versatz: CGFloat = 0.12
    /// Der Anfang sitzt oft etwas daneben: Längen erst ab 15 % des Wegs.
    private static let k0 = n * 3 / 20

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

    /// `rechtsVon`: rechter Rand des Musters in der Zeile — geschrieben
    /// wird rechts davon.
    init(folge: [Zeichen], genauigkeit: Genauigkeit, rechtsVon: CGFloat? = nil) {
        self.folge = folge
        f = genauigkeit.heftFaktor
        letzterAnsatz = rechtsVon
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
            return fertige.isEmpty ? .nebenMuster : .rechtsDaneben
        }

        // Lage: beim ersten Strich so, dass die Vorlage am besten passt.
        let anker = erster ? anpassen(p, t).anker : ax!
        var neuUV = suv, neuUU = suu
        for (a, b) in zip(p, t) {
            let u = b.x - x0
            neuUV += u * (a.x - anker)
            neuUU += u * u
        }
        // Breite: beim ersten Strich aus ihm selbst; danach aus den schon
        // angenommenen breiten Strichen; sonst aus diesem Strich, eng begrenzt.
        var sx: CGFloat
        if erster {
            sx = anpassen(p, t).breite
        } else if suu > Self.fest {
            sx = breite()
        } else {
            sx = neuUU > 0.02 ? min(1.25, max(0.8, neuUV / neuUU)) : 1
        }
        var tt = abbilden(t, anker, sx)
        if !erster {
            // Jeder weitere Strich darf waagerecht ein wenig neben seinem
            // Platz liegen und ±20 % länger oder kürzer sein — die
            // Querstriche eines E sind bei Kindern nie gleich lang.
            let u = t[Self.k0...].map { $0.x - x0 }
            let v = p[Self.k0...].map { $0.x - anker }
            if let uMin = u.min(), let uMax = u.max(), uMax - uMin >= 0.25 {
                let mu = u.reduce(0, +) / CGFloat(u.count), mv = v.reduce(0, +) / CGFloat(v.count)
                let varianz = u.reduce(CGFloat(0)) { $0 + ($1 - mu) * ($1 - mu) }
                let kovarianz = zip(u, v).reduce(CGFloat(0)) { $0 + ($1.0 - mu) * ($1.1 - mv) }
                sx = min(sx * 1.2, max(sx * 0.8, kovarianz / varianz))
                tt = abbilden(t, anker, sx)
            }
            let summe = zip(p[Self.k0...], tt[Self.k0...]).reduce(CGFloat(0)) { $0 + ($1.0.x - $1.1.x) }
            let d = max(-Self.versatz, min(Self.versatz, summe / CGFloat(Self.n - Self.k0)))
            tt = tt.map { CGPoint(x: $0.x + d, y: $0.y) }
        }

        let (mittel, spitze) = Self.vergleich(p, tt)
        let l = Self.laenge(vorlage)
        let endeRest = max(0.18, min(Self.endeMax, 0.3 * l) * sqrt(f))
        // Die Etage wächst mit der Genauigkeit nur wenig mit — auch bei
        // „Locker“ muss eine ganze Etage daneben (0,45) auffallen.
        let etage = Self.etage * min(f, 1.1)
        let etageEnde = min(etage, max(0.1, 0.35 * l))
        // Der Anfang: ein kleines Stück nach dem Ansatz (5 % des Wegs) —
        // Anfänger setzen den Stift oft daneben auf und finden dann erst in
        // den Strich.
        let a0 = Self.n / 20
        let anfangOK = abs(p[a0].y - tt[a0].y) <= etage
            && abs(p[a0].x - tt[a0].x) <= Self.endeMax * f * 1.25
        // Das Ende gemessen ab einem kleinen Stück nach dem Ansatz: zählt,
        // ob der Strich lang genug ist und in die richtige Richtung geht.
        let k = Self.k0
        let wegKind = CGPoint(x: p[p.count - 1].x - p[k].x, y: p[p.count - 1].y - p[k].y)
        let wegVorlage = CGPoint(x: tt[tt.count - 1].x - tt[k].x, y: tt[tt.count - 1].y - tt[k].y)
        let endeOK = abs(p[p.count - 1].y - tt[tt.count - 1].y) <= etageEnde
            && wegKind.abstand(zu: wegVorlage) <= endeRest

        if anfangOK && endeOK && mittel <= Self.mittel * f && spitze <= Self.spitze * f {
            ax = anker
            let xs = vorlage.map(\.x)
            if let a = xs.min(), let b = xs.max(), b - a >= Self.breit {
                suv = neuUV   // nur breite Striche sagen etwas über die Breite
                suu = neuUU
            }
            return nil
        }

        // Andersherum? Dann liegt das Ende des Kindes am Anfang der Vorlage.
        let umgekehrt = Array(t.reversed())
        var ankerR = anker, sxR = sx
        if erster {
            let passung = anpassen(p, umgekehrt)
            ankerR = passung.anker
            sxR = passung.breite
        }
        let tr = Array(abbilden(t, ankerR, sxR).reversed())
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

    /// Lage und Breite, bei denen die Vorlage waagerecht am besten auf dem
    /// Strich des Kindes liegt (kleinste Quadrate). So kostet ein etwas
    /// anders gesetzter Anfang nicht den ganzen Buchstaben.
    private func anpassen(_ p: [CGPoint], _ t: [CGPoint]) -> (anker: CGFloat, breite: CGFloat) {
        let u = t.map { $0.x - x0 }
        let v = p.map(\.x)
        let mu = u.reduce(0, +) / CGFloat(u.count), mv = v.reduce(0, +) / CGFloat(v.count)
        var sx: CGFloat = 1
        if let a = u.min(), let b = u.max(), b - a >= 0.25 {
            let varianz = u.reduce(CGFloat(0)) { $0 + ($1 - mu) * ($1 - mu) }
            let kovarianz = zip(u, v).reduce(CGFloat(0)) { $0 + ($1.0 - mu) * ($1.1 - mv) }
            sx = min(1.25, max(0.8, kovarianz / varianz))
        }
        return (mv - sx * mu, sx)
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
        zip(p, p.dropFirst()).reduce(CGFloat(0)) { $0 + $1.0.abstand(zu: $1.1) }
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
