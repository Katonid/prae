import CoreGraphics
import Foundation

// Fängt einen geschobenen Block an den Kanten, an denen er hingehört.
//
// Ohne Einrasten steht ein Foto nach dem Schieben zwei Punkte neben dem
// Satzspiegel oder drei neben seinem Nachbarn. Das sieht man auf dem
// Bildschirm nicht und im gedruckten Buch sofort — es ist genau die Art
// Unsauberkeit, die ein Buch billig aussehen lässt, und sie von Hand zu
// vermeiden ist unmöglich.
//
// Gefangen wird an ECHTEN Kanten: am Satzspiegel, an den Kanten der
// Nachbarblöcke und an deren Mittelachsen. Ein festes Raster wäre die
// einfachere Lösung und die schlechtere — die Fotoreihen des Automaten
// liegen nicht auf einem Raster, sondern auf ihren eigenen Höhen.
enum Einrasten {
    static func gefangen(block: Block, dx: Double, dy: Double, nachbarn: [Block],
                         satz: CGRect, toleranz: Double) -> (dx: Double, dy: Double)
    {
        let neu = block.rahmen.verschoben(dx: dx, dy: dy).rect

        var kantenX: [Double] = [satz.minX, satz.maxX, satz.midX]
        var kantenY: [Double] = [satz.minY, satz.maxY, satz.midY]
        for nachbar in nachbarn {
            let r = nachbar.rahmen.rect
            kantenX.append(contentsOf: [r.minX, r.maxX, r.midX])
            kantenY.append(contentsOf: [r.minY, r.maxY, r.midY])
        }

        let korrekturX = naechste(kanten: kantenX,
                                  eigene: [neu.minX, neu.midX, neu.maxX],
                                  toleranz: toleranz)
        let korrekturY = naechste(kanten: kantenY,
                                  eigene: [neu.minY, neu.midY, neu.maxY],
                                  toleranz: toleranz)
        return (dx + korrekturX, dy + korrekturY)
    }

    private static func naechste(kanten: [Double], eigene: [Double], toleranz: Double) -> Double {
        var beste: Double = 0
        var abstand = toleranz
        for meine in eigene {
            for kante in kanten {
                let differenz = kante - meine
                if abs(differenz) < abstand {
                    abstand = abs(differenz)
                    beste = differenz
                }
            }
        }
        return beste
    }

    // Beim Ändern der Größe wird nur die bewegte Kante gefangen, nicht der
    // ganze Block — sonst spränge beim Ziehen an der rechten Kante auch die
    // linke.
    static func kanteGefangen(_ wert: Double, kanten: [Double], toleranz: Double) -> Double {
        var beste = wert
        var abstand = toleranz
        for kante in kanten where abs(kante - wert) < abstand {
            abstand = abs(kante - wert)
            beste = kante
        }
        return beste
    }
}
