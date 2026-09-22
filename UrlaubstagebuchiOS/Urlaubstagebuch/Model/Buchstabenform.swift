import CoreGraphics
import CoreText
import UIKit

// WIE DAS KLEINE a AUSSIEHT — gemessen an der Glyphe, nicht geraten
// (ab 1.0.29, Ansage des Nutzers 09/2026: „standardmäßig möchte ich eine
// serifenlose Schrift verwenden, bei der das kleine A so aussieht wie bei
// der Systemschrift Futura. Futura selbst ist mir etwas zu dick gedruckt.
// Bitte finde dort Alternativen.").
//
// Welche Schriften ein bestimmtes iPad mitbringt, steht nirgends: Apple
// liefert je nach Fassung andere, und was installiert ist, entscheidet das
// Gerät. Eine Liste in den Quelltext zu schreiben, wäre deshalb genau die
// Art Behauptung, die dieses Papier sonst verbietet — sie stimmte bei der
// nächsten iOS-Fassung nicht mehr, und niemand sähe es.
//
// Also misst die App selbst. Der Unterschied zwischen einem EINSTÖCKIGEN a
// (Futura: ein Kreis mit Stamm) und einem ZWEISTÖCKIGEN (Helvetica: eine
// kleine Schale unten mit einem Bogen darüber) steckt in der GEGENFORM,
// also im Loch: Beim einstöckigen füllt sie fast die ganze Höhe des
// Buchstabens, beim zweistöckigen gut ein Drittel.
//
// NACHGEMESSEN an elf Schriftdateien (22.09.2026, mit denselben Schritten
// in Python nachgerechnet):
//
//     zweistöckig   Liberation Sans 0,373 · Liberation Serif 0,397
//                   DejaVu Sans 0,372 · DejaVu Serif 0,429
//                   Liberation Mono 0,372 · FreeSans 0,372
//                   FreeSerif 0,468 · Loma 0,362
//     einstöckig    Poppins 0,719 · Questrial 0,736 · Josefin Sans 0,913
//
// Zwischen 0,468 und 0,719 liegt eine breite Lücke; die Schwelle steht
// mittig darin. Die LAGE der Gegenform (0,31 gegen 0,50) trennt genauso
// sauber und wird mitgenannt — entschieden wird an der Höhe, weil die auch
// dann noch stimmt, wenn ein Stamm unten einen Sporn hat.
enum Buchstabenform {
    struct Befund {
        // Höhe der Gegenform, bezogen auf die Tintenhöhe der Glyphe.
        var anteil: Double
        // Lage ihrer Mitte, dieselbe Bezugsgröße.
        var mitte: Double
        var rund: Bool { anteil >= Buchstabenform.schwelle }
    }

    static let schwelle = 0.55

    // Gemerkt, weil die Wahl der Schrift eine LISTE ist: Ohne das liefe die
    // Messung für achtzig Familien bei jedem Neuzeichnen — dieselbe Falle
    // wie bei der Netzkarte der Abfahrtstafel.
    private static var gemerkt: [String: Befund?] = [:]

    static func befund(_ schrift: UIFont) -> Befund? {
        let schluessel = schrift.fontName
        if let fertig = gemerkt[schluessel] { return fertig }
        let neu = gemessen(schrift)
        gemerkt[schluessel] = neu
        return neu
    }

    static func rundesA(_ familie: Schriftfamilie) -> Bool {
        befund(familie.uiFont(groesse: 100, fett: false, kursiv: false))?.rund ?? false
    }

    private static func gemessen(_ schrift: UIFont) -> Befund? {
        let ct = schrift as CTFont
        var zeichen: [UniChar] = Array("a".utf16)
        var glyphen = [CGGlyph](repeating: 0, count: zeichen.count)
        guard CTFontGetGlyphsForCharacters(ct, &zeichen, &glyphen, zeichen.count),
              let glyphe = glyphen.first,
              let pfad = CTFontCreatePathForGlyph(ct, glyphe, nil)
        else { return nil }

        let konturen = teilrechtecke(pfad)
        guard konturen.count >= 2 else { return nil }

        // WELCHE KONTUR DIE ÄUSSERE IST, wird nicht über die Fläche
        // entschieden, sondern über das UMFASSEN — und wo keine alle
        // anderen umfasst, gibt es KEINE Antwort.
        //
        // Das ist an einer echten Schrift gelernt: Jost zeichnet sein a aus
        // zwei einander überlappenden Formen statt aus Umriss und Loch.
        // Nach der Fläche gerechnet gewann dort die falsche, und heraus kam
        // „zweistöckig" für eine Schrift, die einstöckig ist. Eine Messung,
        // die im Zweifel etwas behauptet, ist schlechter als eine, die
        // schweigt — dieselbe Regel wie bei „Plan" gegen „pünktlich".
        let spanne = konturen.map { $0.height }.max() ?? 0
        let saum = spanne * 0.02
        func umfasst(_ a: CGRect, _ b: CGRect) -> Bool {
            a.minX <= b.minX + saum && a.minY <= b.minY + saum
                && a.maxX >= b.maxX - saum && a.maxY >= b.maxY - saum
        }
        guard let aussen = konturen.first(where: { kandidat in
            konturen.allSatisfy { $0 == kandidat || umfasst(kandidat, $0) }
        }) else { return nil }

        let innen = konturen.filter { $0 != aussen }
        guard let gegen = innen.max(by: { $0.width * $0.height < $1.width * $1.height }),
              aussen.height > 0
        else { return nil }

        return Befund(anteil: gegen.height / aussen.height,
                      mitte: (gegen.midY - aussen.minY) / aussen.height)
    }

    // Je Teilpfad ein Rechteck. Genommen werden auch die Steuerpunkte: Sie
    // treiben ein Rechteck ein wenig auf, aber symmetrisch — und beide
    // Seiten des Vergleichs sind gleich betroffen.
    private static func teilrechtecke(_ pfad: CGPath) -> [CGRect] {
        var rechtecke: [CGRect] = []
        var punkte: [CGPoint] = []

        func abschliessen() {
            guard !punkte.isEmpty else { return }
            let xs = punkte.map(\.x)
            let ys = punkte.map(\.y)
            if let minX = xs.min(), let maxX = xs.max(),
               let minY = ys.min(), let maxY = ys.max()
            {
                rechtecke.append(CGRect(x: minX, y: minY,
                                        width: maxX - minX, height: maxY - minY))
            }
            punkte.removeAll()
        }

        pfad.applyWithBlock { zeiger in
            let element = zeiger.pointee
            switch element.type {
            case .moveToPoint:
                abschliessen()
                punkte.append(element.points[0])
            case .addLineToPoint:
                punkte.append(element.points[0])
            case .addQuadCurveToPoint:
                punkte.append(element.points[0])
                punkte.append(element.points[1])
            case .addCurveToPoint:
                punkte.append(element.points[0])
                punkte.append(element.points[1])
                punkte.append(element.points[2])
            case .closeSubpath:
                abschliessen()
            @unknown default:
                break
            }
        }
        abschliessen()
        return rechtecke
    }
}
