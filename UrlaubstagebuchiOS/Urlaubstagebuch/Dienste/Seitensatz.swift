import CoreGraphics
import CoreText
import Foundation
import UIKit

// Der eine Setzer.
//
// Eine Buchseite wird in dieser App zweimal gezeichnet: auf dem Bildschirm,
// damit man sie anfassen kann, und ins PDF, damit man sie drucken kann.
// Zwei Zeichenwege bedeuten früher oder später zwei Ergebnisse — und der
// Unterschied fällt genau dann auf, wenn das Buch schon beim Drucker liegt.
//
// Deshalb steht hier, was BEIDE benutzen: der Textsatz, die Trennlinie und
// das Bild in seinem Rahmen. Die Ansicht hängt eine UIView davor, die
// nichts weiter tut, als diese Funktionen aufzurufen; der PDF-Ausgeber ruft
// sie unmittelbar.
enum Seitensatz {
    // Text mit CoreText. `draw(with:)` aus UIKit wäre kürzer und setzte
    // über TextKit — also über einen anderen Zeilenumbruch als den, mit dem
    // `Textmass` gerechnet hat. Ein Text, der beim Messen sechs Zeilen hatte
    // und beim Zeichnen sieben, läuft unten aus seinem Block.
    static func zeichneText(_ text: String, bild: Schriftbild, rechteck: CGRect,
                            in zusammenhang: CGContext, seitenhoehe: CGFloat)
    {
        guard !text.isEmpty, rechteck.width > 1, rechteck.height > 1 else { return }
        zusammenhang.saveGState()
        zusammenhang.textMatrix = .identity
        zusammenhang.translateBy(x: 0, y: seitenhoehe)
        zusammenhang.scaleBy(x: 1, y: -1)

        let gedreht = CGRect(
            x: rechteck.minX,
            y: seitenhoehe - rechteck.maxY,
            width: rechteck.width,
            height: rechteck.height
        )
        let setzer = Textmass.rahmensetzer(text, bild: bild)
        let pfad = CGPath(rect: gedreht, transform: nil)
        let rahmen = CTFramesetterCreateFrame(setzer, CFRange(location: 0, length: 0), pfad, nil)
        CTFrameDraw(rahmen, zusammenhang)
        zusammenhang.restoreGState()
    }

    static func zeichneBild(_ bild: UIImage, ausschnitt: Bildausschnitt, rechteck: CGRect,
                            in zusammenhang: CGContext, eckenradius: CGFloat)
    {
        zusammenhang.saveGState()
        if eckenradius > 0.5 {
            let weg = UIBezierPath(roundedRect: rechteck, cornerRadius: eckenradius)
            weg.addClip()
        } else {
            zusammenhang.clip(to: rechteck)
        }
        let ziel = ausschnitt.zielrechteck(bildgroesse: bild.size, rahmen: rechteck)
        bild.draw(in: ziel)
        zusammenhang.restoreGState()
    }

    static func zeichneLinie(_ rechteck: CGRect, farbe: UIColor, in zusammenhang: CGContext) {
        zusammenhang.saveGState()
        zusammenhang.setFillColor(farbe.cgColor)
        zusammenhang.fill(CGRect(x: rechteck.minX, y: rechteck.minY,
                                 width: rechteck.width, height: max(rechteck.height, 0.6)))
        zusammenhang.restoreGState()
    }

    static func zeichneRahmen(_ rechteck: CGRect, farbe: UIColor, breite: CGFloat,
                              eckenradius: CGFloat, in zusammenhang: CGContext)
    {
        guard breite > 0 else { return }
        zusammenhang.saveGState()
        let weg = UIBezierPath(roundedRect: rechteck.insetBy(dx: breite / 2, dy: breite / 2),
                               cornerRadius: max(eckenradius - breite / 2, 0))
        zusammenhang.setStrokeColor(farbe.cgColor)
        weg.lineWidth = breite
        weg.stroke()
        zusammenhang.restoreGState()
    }

    // Der Text eines Blocks, wie er an dieser Stelle wirklich lautet.
    // Datum und Überschrift stehen nicht im Block, sondern am Tag — sonst
    // müsste man sie an zwei Stellen ändern und hätte irgendwann zwei
    // verschiedene.
    static func inhaltstext(_ block: Block, tag: Reisetag?, reise: Reise) -> String {
        switch block.inhalt {
        case .titel:
            if let tag { return tag.ueberschrift }
            return reise.titel
        case .datum:
            return tag?.datum.lang ?? reise.zeitraum
        case let .text(wert):
            return wert
        default:
            return ""
        }
    }

    static func schriftbild(_ block: Block, reise: Reise) -> Schriftbild {
        block.abweichung.angewendet(auf: reise.typografie[block.inhalt.rolle])
    }
}
