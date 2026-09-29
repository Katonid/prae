import CoreGraphics
import Foundation

/// Ein einzelner Strich eines Zeichens: der Weg, den der Stift ohne
/// Absetzen nimmt — als dicht abgetastete Punktfolge in Einheiten des
/// Vierliniensystems (siehe `Zeichensatz`).
struct Strich {
    let punkte: [CGPoint]
    /// Bis zum jeweiligen Punkt zurückgelegte Weglänge; `laengen[0] == 0`.
    let laengen: [CGFloat]

    init(punkte: [CGPoint]) {
        self.punkte = punkte
        var summe: CGFloat = 0
        var liste: [CGFloat] = [0]
        for i in punkte.indices.dropFirst() {
            summe += punkte[i - 1].abstand(zu: punkte[i])
            liste.append(summe)
        }
        laengen = liste
    }

    var gesamt: CGFloat { laengen.last ?? 0 }
    /// i-Punkt oder Umlautpunkt: nur antippen, nicht ziehen.
    var istPunkt: Bool { gesamt < 0.001 }
    var anfang: CGPoint { punkte[0] }
    var ende: CGPoint { punkte[punkte.count - 1] }

    /// Der Punkt nach der Weglänge `s`.
    func punkt(bei s: CGFloat) -> CGPoint {
        guard punkte.count > 1 else { return anfang }
        let s = min(max(s, 0), gesamt)
        let i = segment(bei: s)
        let l = laengen[i + 1] - laengen[i]
        let t = l > 0 ? (s - laengen[i]) / l : 0
        return punkte[i].mitte(zu: punkte[i + 1], anteil: t)
    }

    /// Schreibrichtung bei der Weglänge `s` als Winkel (Bogenmaß, y nach unten).
    func winkel(bei s: CGFloat) -> CGFloat {
        guard punkte.count > 1 else { return -.pi / 2 }
        // Über ein kurzes Stück mitteln — einzelne Abtastpunkte zittern.
        let a = punkt(bei: s)
        let b = punkt(bei: min(s + 0.06, gesamt))
        if a.abstand(zu: b) > 0.0001 {
            return atan2(b.y - a.y, b.x - a.x)
        }
        let c = punkt(bei: max(s - 0.06, 0))
        return atan2(a.y - c.y, a.x - c.x)
    }

    /// Die Punkte vom Anfang bis zur Weglänge `s` — für die schon
    /// geschriebene Spur.
    func teil(bis s: CGFloat) -> [CGPoint] {
        guard punkte.count > 1, s > 0 else { return [anfang] }
        if s >= gesamt { return punkte }
        let i = segment(bei: s)
        return Array(punkte[0...i]) + [punkt(bei: s)]
    }

    /// Nächstgelegene Stelle des Wegs zu `p`, gesucht nur zwischen den
    /// Weglängen `von` und `bis`.
    ///
    /// Liegen mehrere Stellen praktisch gleich nah (bis auf `gleichstand`),
    /// gewinnt die, die am dichtesten beim bisherigen Fortschritt `bezug`
    /// liegt — vorwärts zählt dabei nur 0,4-fach. Das braucht es für Striche,
    /// die auf sich selbst zurücklaufen (b, d, h, n): Am Wendepunkt liegen
    /// Hin- und Rückweg übereinander, und nur so bleibt der Fortschritt
    /// weder hängen noch springt er über die Schleife.
    func naechsteStelle(zu p: CGPoint, von: CGFloat, bis: CGFloat,
                        bezug: CGFloat, gleichstand: CGFloat) -> (s: CGFloat, abstand: CGFloat) {
        guard punkte.count > 1 else { return (0, p.abstand(zu: anfang)) }
        var kandidaten: [(s: CGFloat, abstand: CGFloat)] = []
        for i in 0..<(punkte.count - 1) {
            let s0 = laengen[i], s1 = laengen[i + 1]
            guard s1 >= von, s0 <= bis else { continue }
            let a = punkte[i], b = punkte[i + 1]
            let l = s1 - s0
            var t: CGFloat = 0
            if l > 0 {
                let dx = b.x - a.x, dy = b.y - a.y
                t = ((p.x - a.x) * dx + (p.y - a.y) * dy) / (l * l)
            }
            // Nur den Teil des Segments, der im Suchfenster liegt.
            let tMin = l > 0 ? max(0, (von - s0) / l) : 0
            let tMax = l > 0 ? min(1, (bis - s0) / l) : 0
            t = min(max(t, tMin), tMax)
            let q = a.mitte(zu: b, anteil: t)
            kandidaten.append((s0 + t * l, p.abstand(zu: q)))
        }
        guard let bester = kandidaten.min(by: { $0.abstand < $1.abstand }) else {
            return (von, .greatestFiniteMagnitude)
        }
        func entfernung(_ s: CGFloat) -> CGFloat {
            s >= bezug ? (s - bezug) * 0.4 : bezug - s
        }
        let gleichNah = kandidaten.filter { $0.abstand <= bester.abstand + gleichstand }
        return gleichNah.min(by: { entfernung($0.s) < entfernung($1.s) }) ?? bester
    }

    private func segment(bei s: CGFloat) -> Int {
        // Binäre Suche: letztes i mit laengen[i] <= s, höchstens count - 2.
        var lo = 0, hi = punkte.count - 2
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if laengen[mid] <= s { lo = mid } else { hi = mid - 1 }
        }
        return lo
    }
}

extension Strich {
    /// Liest einen Weg in der Wegsprache von `Zeichensatz`.
    init(weg: String) {
        let teile = weg.split(separator: " ")
        var i = 0
        var punkte: [CGPoint] = []
        func zahl(_ k: Int) -> CGFloat {
            guard i + k < teile.count, let d = Double(teile[i + k]) else {
                assertionFailure("Wegsprache: Zahl fehlt in \(weg)")
                return 0
            }
            return CGFloat(d)
        }
        while i < teile.count {
            switch teile[i] {
            case "M", "P", "L":
                punkte.append(CGPoint(x: zahl(1), y: zahl(2)))
                i += 3
            case "A":
                let cx = zahl(1), cy = zahl(2), rx = zahl(3), ry = zahl(4)
                let a0 = zahl(5), a1 = zahl(6)
                let n = max(12, Int(abs(a1 - a0) / 3))
                for k in 0...n {
                    let a = (a0 + (a1 - a0) * CGFloat(k) / CGFloat(n)) * .pi / 180
                    punkte.append(CGPoint(x: cx + rx * cos(a), y: cy + ry * sin(a)))
                }
                i += 7
            case "Q":
                let p0 = punkte.last ?? .zero
                let p1 = CGPoint(x: zahl(1), y: zahl(2)), p2 = CGPoint(x: zahl(3), y: zahl(4))
                for k in 1...20 {
                    let u = CGFloat(k) / 20, v = 1 - u
                    punkte.append(CGPoint(x: v * v * p0.x + 2 * v * u * p1.x + u * u * p2.x,
                                          y: v * v * p0.y + 2 * v * u * p1.y + u * u * p2.y))
                }
                i += 5
            case "C":
                let p0 = punkte.last ?? .zero
                let p1 = CGPoint(x: zahl(1), y: zahl(2)), p2 = CGPoint(x: zahl(3), y: zahl(4))
                let p3 = CGPoint(x: zahl(5), y: zahl(6))
                for k in 1...32 {
                    let u = CGFloat(k) / 32, v = 1 - u
                    let a = v * v * v, b = 3 * v * v * u, c = 3 * v * u * u, d = u * u * u
                    punkte.append(CGPoint(x: a * p0.x + b * p1.x + c * p2.x + d * p3.x,
                                          y: a * p0.y + b * p1.y + c * p2.y + d * p3.y))
                }
                i += 7
            default:
                assertionFailure("Wegsprache: unbekannter Befehl \(teile[i]) in \(weg)")
                i += 1
            }
        }
        // Doppelte Punkte (Bogen beginnt, wo die Linie endete) entfernen —
        // sie hätten die Länge null und stören nur die Richtungsberechnung.
        var bereinigt: [CGPoint] = []
        for p in punkte where bereinigt.last.map({ $0.abstand(zu: p) > 0.0005 }) ?? true {
            bereinigt.append(p)
        }
        self.init(punkte: bereinigt.isEmpty ? [.zero] : bereinigt)
    }
}

extension CGPoint {
    func abstand(zu p: CGPoint) -> CGFloat {
        hypot(p.x - x, p.y - y)
    }

    func mitte(zu p: CGPoint, anteil t: CGFloat) -> CGPoint {
        CGPoint(x: x + (p.x - x) * t, y: y + (p.y - y) * t)
    }
}
