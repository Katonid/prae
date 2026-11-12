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
        // Der Sicherheitsabstand (ab 1.0.73): der Streifen INNERHALB des
        // Endformats, in dem nichts stehen soll, was gelesen werden muss.
        // Er ist die Gegenrichtung zur Schnittkante und gehört deshalb in
        // dieselbe Liste — wer einen Block von Hand an die Kante schiebt,
        // soll dort fangen und nicht daneben.
        case sicherheit
        case nachbar

        var name: String { linie.name }

        // OB AN DIESER KANTE DER GEZEICHNETE UMRISS GILT (ab 1.0.87).
        //
        // Gemeldet 09/2026: „Wenn ich die Bilder verschiebe, rasten sie
        // erst ein, wenn der rote Rand sich schon bildet. Natürlich wäre es
        // wünschenswert, dass sie vorher einrasten, quasi am letztmöglichen
        // Punkt, bevor sie in den Sicherheitsbereich reisen."
        //
        // **Er hat recht, und es ist auszurechnen.** Seit 1.0.83 misst die
        // rote Marke den gezeichneten UMRISS: Der weiße Fotorand liegt
        // außerhalb des Rahmens, und ein gedrehter Block steht mit seiner
        // Ecke weiter draußen als mit seiner Kante. Gefangen wurde aber
        // weiter der RAHMEN — ein Bild, das sauber an der blauen Linie
        // einrastete, ragte mit seinem weißen Rand längst darüber hinaus.
        // Die Marke und das Einrasten maßen zwei verschiedene Dinge.
        //
        // An GRENZEN gilt deshalb der Umriss: Schnittkante und
        // Sicherheitsabstand sagen, wie weit etwas SICHTBAR reichen darf.
        // Am Satzspiegel und an den Nachbarn bleibt es beim Rahmen — so
        // setzt der Automat, und ein von Hand geschobenes Bild soll neben
        // einem gesetzten bündig stehen und nicht um seinen Rand versetzt.
        var misstUmriss: Bool {
            switch self {
            case .sicherheit, .anschnitt: return true
            case .satz, .nachbar: return false
            }
        }

        /// Welche der Linien auf der Seite gemeint ist. Farbe und Name
        /// stehen seit 1.0.80 dort und nicht hier: Die Fanglinie ist
        /// dieselbe Auskunft wie der stehende Rahmen, nur flüchtig.
        var linie: Seitenlinie {
            switch self {
            case .satz: return .satz
            case .anschnitt: return .schnitt
            case .sicherheit: return .sicherheit
            case .nachbar: return .nachbar
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

    static func kanten(satz: CGRect, bogen: CGRect?, schutz: CGRect? = nil,
                       nachbarn: [Block])
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
        if let schutz {
            x.append(contentsOf: [Kante(wert: schutz.minX, herkunft: .sicherheit),
                                  Kante(wert: schutz.maxX, herkunft: .sicherheit)])
            y.append(contentsOf: [Kante(wert: schutz.minY, herkunft: .sicherheit),
                                  Kante(wert: schutz.maxY, herkunft: .sicherheit)])
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

    /// `ueberstand` ist, wie weit der gezeichnete Umriss je Achse über den
    /// Rahmen hinausragt (`Block.ueberstand(_:)`). An den Grenzkanten wird
    /// damit gefangen, an den übrigen weiter der Rahmen — siehe
    /// `Herkunft.misstUmriss`.
    static func gefangen(block: Block, dx: Double, dy: Double, nachbarn: [Block],
                         satz: CGRect, bogen: CGRect? = nil, schutz: CGRect? = nil,
                         ueberstand: CGSize = .zero, toleranz: Double) -> Fang
    {
        let neu = block.rahmen.verschoben(dx: dx, dy: dy).rect
        let weit = neu.insetBy(dx: -ueberstand.width, dy: -ueberstand.height)
        let alle = kanten(satz: satz, bogen: bogen, schutz: schutz, nachbarn: nachbarn)

        let x = naechste(kanten: alle.x, eigene: [neu.minX, neu.midX, neu.maxX],
                         umriss: [weit.minX, weit.midX, weit.maxX], toleranz: toleranz)
        let y = naechste(kanten: alle.y, eigene: [neu.minY, neu.midY, neu.maxY],
                         umriss: [weit.minY, weit.midY, weit.maxY], toleranz: toleranz)
        return Fang(dx: dx + x.korrektur, dy: dy + y.korrektur,
                    senkrecht: x.linie, waagerecht: y.linie)
    }

    private static func naechste(kanten: [Kante], eigene: [Double], umriss: [Double],
                                 toleranz: Double)
        -> (korrektur: Double, linie: Linie?)
    {
        var beste: Double = 0
        var linie: Linie?
        var abstand = toleranz
        for kante in kanten {
            // Welche der beiden Messungen gilt, entscheidet die HERKUNFT
            // der Kante und nicht der Block: An einer Grenze zählt, was man
            // sieht, am Satzspiegel, was der Automat gesetzt hätte.
            for meine in kante.herkunft.misstUmriss ? umriss : eigene {
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
    ///
    /// `versatz` rückt eine GRENZkante um den Überstand nach innen — mit
    /// Vorzeichen, denn beim Ziehen an der linken Kante liegt „innen"
    /// rechts und umgekehrt. Nur der Aufrufer weiß, welche Kante er zieht.
    static func kanteGefangen(_ wert: Double, kanten: [Kante], toleranz: Double,
                              versatz: Double = 0)
        -> (wert: Double, linie: Linie?)
    {
        var beste = wert
        var linie: Linie?
        var abstand = toleranz
        for kante in kanten {
            let ziel = kante.herkunft.misstUmriss ? kante.wert + versatz : kante.wert
            guard abs(ziel - wert) < abstand else { continue }
            abstand = abs(ziel - wert)
            beste = ziel
            // Gezeichnet wird die Linie da, wo die Kante WIRKLICH liegt —
            // der Block hält seinen Abstand davon, die Linie rückt nicht
            // mit. Eine Fanglinie, die ein Stück neben ihrer Kante läge,
            // wäre eine falsche Auskunft.
            linie = Linie(wert: kante.wert, herkunft: kante.herkunft)
        }
        return (beste, linie)
    }
}
