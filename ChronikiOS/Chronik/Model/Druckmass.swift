import CoreGraphics
import Foundation

// Ein Buch wird in Millimetern bestellt und in Punkten gesetzt.
//
// Diese eine Umrechnung steht deshalb an genau einer Stelle. Ein PDF-Punkt
// ist ein Zweiundsiebzigstel Zoll — das ist kein Rundungswert, sondern die
// Festlegung des Formats, und wer sie mit 2,83 abkürzt, liegt bei einer
// A4-Seite schon um einen halben Millimeter daneben.
enum Druckmass {
    static let punkteJeZoll: Double = 72
    static let millimeterJeZoll: Double = 25.4

    static func pt(_ mm: Double) -> Double { mm * punkteJeZoll / millimeterJeZoll }
    static func mm(_ pt: Double) -> Double { pt * millimeterJeZoll / punkteJeZoll }

    static func mmText(_ pt: Double, stellen: Int = 1) -> String {
        String(format: "%.\(stellen)f mm", mm(pt))
            .replacingOccurrences(of: ".", with: ",")
    }

    // Wie fein ein Bild an dieser Stelle wirklich gedruckt wird.
    //
    // Das ist die Zahl, die über das Ergebnis entscheidet, und die einzige,
    // die man einem Foto nicht ansieht: Ein 12-Megapixel-Bild ist gestochen
    // scharf, solange es klein steht, und matschig, sobald es über eine
    // halbe A4-Seite läuft. 300 dpi sind der Anspruch jeder Druckerei, ab
    // etwa 150 dpi wird es sichtbar weich.
    static func dpi(pixel: Double, punkte: Double) -> Double {
        guard punkte > 0.5 else { return 0 }
        return pixel / (punkte / punkteJeZoll)
    }

    static let dpiGut: Double = 250
    static let dpiGrenze: Double = 150
}
