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

    // Der weiße Rand eines Sofortbildes. Er gehört NACH AUSSEN, nicht nach
    // innen: Ein Rand, der vom Bild abgeht, machte jede Reihe des
    // Layoutautomaten um zwei Ränder zu schmal, und die Reihen gingen nicht
    // mehr auf.
    static func fotorandRechteck(_ rechteck: CGRect, rand: CGFloat) -> CGRect {
        rechteck.insetBy(dx: -rand, dy: -rand)
    }

    // Schatten und Papierrand in einem: Erst der Schatten unter dem
    // weißen Feld, dann das Feld, dann das Bild darin. Andersherum läge der
    // Schatten über dem Bild.
    static func zeichneSchatten(_ rechteck: CGRect, art: Schattenart, massstab: CGFloat,
                                eckenradius: CGFloat, in zusammenhang: CGContext)
    {
        guard art != .keiner else { return }
        let werte = art.werte
        zusammenhang.saveGState()
        zusammenhang.setShadow(
            offset: CGSize(width: 0, height: werte.versatz * massstab),
            blur: werte.unschaerfe * massstab,
            color: UIColor.black.withAlphaComponent(werte.deckung).cgColor
        )
        zusammenhang.setFillColor(UIColor.white.cgColor)
        UIBezierPath(roundedRect: rechteck, cornerRadius: eckenradius).fill()
        zusammenhang.restoreGState()
    }

    static func zeichneFlaeche(_ rechteck: CGRect, farbe: UIColor, eckenradius: CGFloat,
                               in zusammenhang: CGContext)
    {
        zusammenhang.saveGState()
        zusammenhang.setFillColor(farbe.cgColor)
        UIBezierPath(roundedRect: rechteck, cornerRadius: eckenradius).fill()
        zusammenhang.restoreGState()
    }

    // Der Verlauf unter einer Überschrift auf einem Foto: unten dunkel,
    // oben durchsichtig.
    //
    // `opak` ist der Weg für Druckereien, die kein PDF mit Transparenz
    // annehmen (PDF/X-1a und X-3 erlauben keine). Dann steht statt des
    // Verlaufs ein geschlossenes Feld — weniger elegant, aber lesbar, und
    // das ist hier das Wichtigere.
    static func zeichneVerlauf(_ rechteck: CGRect, opak: Bool, in zusammenhang: CGContext) {
        zusammenhang.saveGState()
        if opak {
            zusammenhang.setFillColor(UIColor(white: 0.08, alpha: 1).cgColor)
            zusammenhang.fill(rechteck)
            zusammenhang.restoreGState()
            return
        }
        let farben = [
            UIColor(white: 0, alpha: 0).cgColor,
            UIColor(white: 0, alpha: 0.30).cgColor,
            UIColor(white: 0, alpha: 0.72).cgColor,
        ] as CFArray
        let stellen: [CGFloat] = [0, 0.45, 1]
        guard let verlauf = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                       colors: farben, locations: stellen)
        else {
            zusammenhang.restoreGState()
            return
        }
        zusammenhang.clip(to: rechteck)
        zusammenhang.drawLinearGradient(
            verlauf,
            start: CGPoint(x: rechteck.midX, y: rechteck.minY),
            end: CGPoint(x: rechteck.midX, y: rechteck.maxY),
            options: []
        )
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
