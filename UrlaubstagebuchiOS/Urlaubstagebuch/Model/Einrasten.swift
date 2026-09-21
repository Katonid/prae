import CoreGraphics
import Foundation

// Fängt einen geschobenen Block an den Kanten, an denen er hingehört — und
// SAGT, an welcher.
//
// Ohne Einrasten steht ein Foto nach dem Schieben zwei Punkte neben dem
// Satzspiegel oder drei neben seinem Nachbarn. Das sieht man auf dem
// Bildschirm nicht und im gedruckten Buch sofort — es ist genau die Art
// Unsauberkeit, die ein Buch billig aussehen lässt, und sie von Hand zu
// vermeiden ist unmöglich.
//
// Gefangen wird an ECHTEN Kanten: am Satzspiegel, an der Schnittkante, an
// den Kanten der Nachbarblöcke und an deren Mittelachsen. Ein festes Raster
// wäre die einfachere Lösung und die schlechtere — die Fotoreihen des
// Automaten liegen nicht auf einem Raster, sondern auf ihren eigenen Höhen.
//
// **Seit 1.0.11 gibt `gefangen` zurück, WORAN es gefangen hat** (Ansage des
// Nutzers, 09/2026: „Der Randindikator soll sich an den Rand und die Fotos
// orientieren, aber im Einzelfall auch veränderbar sein."). Bis 1.0.10 rastete
// der Block stumm ein: Er sprang um zwei Punkte, und ob das der Rand war, der
// Nachbar oder gar nichts, stand nirgends. Eine Hilfe, die man nicht sieht,
// ist für den Menschen davor ein Zucken. Gezeichnet wird die Linie in
// `SeitenflaecheView`; hier steht nur, welche es ist.
enum Einrasten {
    // Woher eine Kante kommt. Das ist kein Schmuck: „am Satzspiegel" und
    // „am Foto darüber" sind zwei verschiedene Auskünfte, und welche von
    // beiden gilt, ist genau das, was man beim Schieben wissen will.
    enum Herkunft {
        case satz
        case anschnitt
        case nachbar

        var name: String {
            switch self {
            case .satz: return "Rand"
            case .anschnitt: return "Schnittkante"
            case .nachbar: return "Nachbar"
            }
        }
    }

    struct Linie: Equatable {
        var wert: Double
        var herkunft: Herkunft
    }

    struct Fang {
        var dx: Double
        var dy: Double
        var senkrecht: Linie?
        var waagerecht: Linie?
    }

    // Eine Kante mit ihrer Herkunft. Beides zusammen, weil sich sonst
    // hinterher nicht mehr sagen ließe, welche Liste die Zahl hergegeben
    // hat — und dann stünde an der Linie eine geratene Beschriftung.
    struct Kante {
        var wert: Double
        var herkunft: Herkunft
    }

    static func kanten(satz: CGRect, bogen: CGRect?, nachbarn: [Block])
        -> (x: [Kante], y: [Kante])
    {
        var x: [Kante] = [
            Kante(wert: satz.minX, herkunft: .satz),
            Kante(wert: satz.maxX, herkunft: .satz),
            Kante(wert: satz.midX, herkunft: .satz),
        ]
        var y: [Kante] = [
            Kante(wert: satz.minY, herkunft: .satz),
            Kante(wert: satz.maxY, herkunft: .satz),
            Kante(wert: satz.midY, herkunft: .satz),
        ]
        // Die Schnittkante gehört dazu, sobald es einen Anschnitt gibt:
        // Ein randabfallendes Bild muss BIS DORT reichen und keinen halben
        // Punkt weniger, sonst steht nach dem Beschneiden ein weißer Faden.
        if let bogen {
            x.append(contentsOf: [Kante(wert: bogen.minX, herkunft: .anschnitt),
                                  Kante(wert: bogen.maxX, herkunft: .anschnitt)])
            y.append(contentsOf: [Kante(wert: bogen.minY, herkunft: .anschnitt),
                                  Kante(wert: bogen.maxY, herkunft: .anschnitt)])
        }
        for nachbar in nachbarn {
            let r = nachbar.rahmen.rect
            x.append(contentsOf: [Kante(wert: r.minX, herkunft: .nachbar),
                                  Kante(wert: r.maxX, herkunft: .nachbar),
                                  Kante(wert: r.midX, herkunft: .nachbar)])
            y.append(contentsOf: [Kante(wert: r.minY, herkunft: .nachbar),
                                  Kante(wert: r.maxY, herkunft: .nachbar),
                                  Kante(wert: r.midY, herkunft: .nachbar)])
        }
        return (x, y)
    }

    static func gefangen(block: Block, dx: Double, dy: Double, nachbarn: [Block],
                         satz: CGRect, bogen: CGRect? = nil, toleranz: Double) -> Fang
    {
        let neu = block.rahmen.verschoben(dx: dx, dy: dy).rect
        let alle = kanten(satz: satz, bogen: bogen, nachbarn: nachbarn)

        let x = naechste(kanten: alle.x, eigene: [neu.minX, neu.midX, neu.maxX],
                         toleranz: toleranz)
        let y = naechste(kanten: alle.y, eigene: [neu.minY, neu.midY, neu.maxY],
                         toleranz: toleranz)
        return Fang(dx: dx + x.korrektur, dy: dy + y.korrektur,
                    senkrecht: x.linie, waagerecht: y.linie)
    }

    private static func naechste(kanten: [Kante], eigene: [Double], toleranz: Double)
        -> (korrektur: Double, linie: Linie?)
    {
        var beste: Double = 0
        var linie: Linie?
        var abstand = toleranz
        for meine in eigene {
            for kante in kanten {
                let differenz = kante.wert - meine
                if abs(differenz) < abstand {
                    abstand = abs(differenz)
                    beste = differenz
                    linie = Linie(wert: kante.wert, herkunft: kante.herkunft)
                }
            }
        }
        return (beste, linie)
    }

    // Beim Ändern der Größe wird nur die bewegte Kante gefangen, nicht der
    // ganze Block — sonst spränge beim Ziehen an der rechten Kante auch die
    // linke.
    static func kanteGefangen(_ wert: Double, kanten: [Kante], toleranz: Double)
        -> (wert: Double, linie: Linie?)
    {
        var beste = wert
        var linie: Linie?
        var abstand = toleranz
        for kante in kanten where abs(kante.wert - wert) < abstand {
            abstand = abs(kante.wert - wert)
            beste = kante.wert
            linie = Linie(wert: kante.wert, herkunft: kante.herkunft)
        }
        return (beste, linie)
    }
}
