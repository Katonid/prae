import CoreGraphics
import Foundation

// WIE FOTOS AUF EINER FLÄCHE LIEGEN — IM BLOCKSATZ (ab 1.0.2).
//
// Bis 1.0.1 bekam jedes Foto eine gleich große Kachel und wurde darauf
// beschnitten: Ein Querformat in einer Hochformat-Kachel verlor die Hälfte,
// und jede Seite sah gleich aus. Jetzt bestimmt das SEITENVERHÄLTNIS jedes
// Bildes seine Breite: Fotos einer Reihe sind gleich hoch, jede Reihe läuft
// genau über die ganze Breite (wie Blocksatz bei Wörtern). Welche Fotos in
// welche Reihe kommen, wird durchprobiert (alle Aufteilungen in
// zusammenhängende Reihen, bei bis zu acht Fotos höchstens 128), und es
// gewinnt die, deren Gesamthöhe der Fläche am nächsten kommt.
//
// Passt die Höhe nicht genau, wird erst BESCHNITTEN (bis etwa ein Fünftel —
// fällt kaum auf) und erst dann verkleinert und mittig gestellt. Lieber ein
// wenig Rand als ein halbes Gesicht.
enum Fotolage {
    static func reihen(_ verhaeltnisse: [CGFloat], in r: CGRect, abstand a: CGFloat) -> [CGRect] {
        let v = verhaeltnisse.map { max(0.2, min(5, $0)) }
        let n = v.count
        guard n > 0, r.width > 0, r.height > 0 else { return [] }
        if n == 1 { return [r] }

        var beste: [Int] = [n]
        var besterWert = CGFloat.greatestFiniteMagnitude
        for aufteilung in aufteilungen(n) {
            let h = hoehe(v, aufteilung, breite: r.width, abstand: a)
            guard h > 0 else { continue }
            var wert = abs(log(h / r.height))
            // Eine Reihe aus einem einzigen Foto, das höher wäre als die
            // halbe Fläche, frisst die Seite — nur nehmen, wenn nichts
            // anderes passt.
            for (zahl, reihenhoehe) in zip(aufteilung, reihenhoehen(v, aufteilung, breite: r.width, abstand: a))
                where zahl == 1 && reihenhoehe > r.height * 0.62 {
                wert += 0.4
            }
            if wert < besterWert {
                besterWert = wert
                beste = aufteilung
            }
        }

        var hoehen = reihenhoehen(v, beste, breite: r.width, abstand: a)
        let summe = hoehen.reduce(0, +) + a * CGFloat(beste.count - 1)
        let platz = r.height - a * CGFloat(beste.count - 1)
        let faktor = platz / max(1, summe - a * CGFloat(beste.count - 1))
        var breitenfaktor: CGFloat = 1
        if faktor >= 0.8 && faktor <= 1.3 {
            // Füllen: Höhe angleichen, Bilder werden leicht beschnitten.
            hoehen = hoehen.map { $0 * faktor }
        } else if faktor > 1.3 {
            hoehen = hoehen.map { $0 * 1.3 }
        } else {
            // Zu hoch: alles kleiner, mittig.
            hoehen = hoehen.map { $0 * faktor }
            breitenfaktor = faktor
        }
        let gesamt = hoehen.reduce(0, +) + a * CGFloat(beste.count - 1)
        var y = r.minY + max(0, (r.height - gesamt) / 2)
        var ergebnis: [CGRect] = []
        var i = 0
        for (k, zahl) in beste.enumerated() {
            let teil = Array(v[i..<(i + zahl)])
            let nutzbreite = (r.width - a * CGFloat(zahl - 1)) * breitenfaktor
            let reihenbreite = nutzbreite + a * CGFloat(zahl - 1)
            var x = r.minX + (r.width - reihenbreite) / 2
            let s = teil.reduce(0, +)
            for (j, verh) in teil.enumerated() {
                var b = nutzbreite * verh / s
                if j == zahl - 1 { b = r.minX + (r.width + reihenbreite) / 2 - x }
                ergebnis.append(CGRect(x: x, y: y, width: b, height: hoehen[k]).integral)
                x += b + a
            }
            y += hoehen[k] + a
            i += zahl
        }
        return ergebnis
    }

    /// Ein großes Foto und die übrigen in Reihen daneben bzw. darunter.
    static func grossUndKlein(_ v: [CGFloat], in r: CGRect, abstand a: CGFloat) -> [CGRect] {
        guard v.count > 1 else { return reihen(v, in: r, abstand: a) }
        let quer = r.width > r.height * 1.05
        let teile = quer
            ? Seitengeometrie.nebeneinander(r, abstand: a, anteil: 0.6)
            : Seitengeometrie.untereinander(r, abstand: a, anteil: 0.6)
        return [teile[0]] + reihen(Array(v.dropFirst()), in: teile[1], abstand: a)
    }

    // MARK: - Rechnen

    private static func aufteilungen(_ n: Int) -> [[Int]] {
        if n > 8 {
            // Gleichmäßig: etwa die Wurzel aus n Reihen.
            let zeilen = max(1, Int((Double(n)).squareRoot().rounded()))
            var liste: [Int] = []
            var rest = n
            for z in 0..<zeilen {
                let zahl = rest / (zeilen - z)
                liste.append(zahl)
                rest -= zahl
            }
            return [liste]
        }
        var alle: [[Int]] = []
        for maske in 0..<(1 << (n - 1)) {
            var liste: [Int] = []
            var zahl = 1
            for i in 0..<(n - 1) {
                if maske & (1 << i) != 0 {
                    liste.append(zahl)
                    zahl = 1
                } else {
                    zahl += 1
                }
            }
            liste.append(zahl)
            if liste.allSatisfy({ $0 <= 4 }) { alle.append(liste) }
        }
        return alle
    }

    private static func reihenhoehen(_ v: [CGFloat], _ aufteilung: [Int], breite: CGFloat, abstand a: CGFloat) -> [CGFloat] {
        var i = 0
        var hoehen: [CGFloat] = []
        for zahl in aufteilung {
            let s = v[i..<(i + zahl)].reduce(0, +)
            hoehen.append((breite - a * CGFloat(zahl - 1)) / s)
            i += zahl
        }
        return hoehen
    }

    private static func hoehe(_ v: [CGFloat], _ aufteilung: [Int], breite: CGFloat, abstand a: CGFloat) -> CGFloat {
        reihenhoehen(v, aufteilung, breite: breite, abstand: a).reduce(0, +) + a * CGFloat(aufteilung.count - 1)
    }

    /// Eine stabile Zahl aus einer Kennung — für Drehwinkel und Abwechslung,
    /// die bei jedem Start und in Vorschau wie PDF gleich ausfallen.
    /// (`hashValue` ändert sich mit jedem Start.)
    static func zahl(_ id: UUID) -> Int {
        let u = id.uuid
        return Int(u.0) &+ Int(u.3) &* 7 &+ Int(u.7) &* 13 &+ Int(u.11) &* 31 &+ Int(u.15) &* 57
    }
}
