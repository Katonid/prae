import Foundation

// WELCHE KARTENEINSTELLUNG AN DIESER STELLE GILT (ab 1.0.51).
//
// Befund des Nutzers, 09/2026: „Hier wollte ich gerade speziell nur für
// diese Karte Änderungen in den Einstellungen treffen. Zum Beispiel, dass
// Standortpunkte doch angezeigt werden und nicht nur die Linien. Offenbar
// kann ich das aber nicht für einzelne Karten, sondern nur global."
//
// Er hat recht, und es war halb gebaut: Das Buch trug eine Einstellung
// (`Reise.kartenbild`), ein TAG durfte sie überschreiben (`Reisetag.
// kartenbild`, seit 1.0.0) — die einzelne Karte auf der Seite nicht. Wer
// seit 1.0.39 eine Karte auf eine zweite Seite KOPIERT, hatte damit zwei
// Karten, die sich nicht auseinanderhalten ließen.
//
// Drei Ebenen, und aufgelöst werden sie an GENAU DIESER Stelle: Der
// Bildschirm (`KartenKachel`) und das PDF (`Buchausgabe.kartenbilder`)
// fragen dieselbe Funktion. Zwei Fassungen liefen auseinander, und dann
// sähe das gedruckte Buch anders aus als die Vorschau — und zwar erst dann
// anders, wenn es gedruckt ist. Dieselbe Regel wie bei
// `Block.wirkung(_:)` und `Bildausschnitt.zielrechteck`.
enum Kartenwahl {
    // Woher der Wert kommt, der gerade gilt. Das ist keine Zierde: Die
    // Oberfläche muss sagen können, WEM eine Änderung hier gilt — sonst
    // stellt jemand die Punkte um und wundert sich, dass es auch die
    // Karte von gestern trifft.
    enum Herkunft: String {
        case buch
        case tag
        case block

        var name: String {
            switch self {
            case .buch: return "wie im ganzen Buch"
            case .tag: return "wie an diesem Tag"
            case .block: return "nur für diese Karte"
            }
        }
    }

    struct Geltend {
        var bild: Kartenbild
        var ausschnitt: Kartenausschnitt?
        var bildHerkunft: Herkunft
        var ausschnittHerkunft: Herkunft

        // Der Schlüssel für den Zwischenspeicher und für `.task(id:)`.
        //
        // Er muss ALLES nennen, was das Bild verändert — eine vergessene
        // Stelle zeigt nach dem Umstellen das Bild von vorhin, und das
        // sieht aus, als tue der Schalter nichts. Bis 1.0.50 stand in der
        // Kennung der `KartenKachel` nur die SPANNE des Ausschnitts: Wer
        // die Karte verschob, ohne den Maßstab zu ändern, sah auf dem
        // Bildschirm weiter den alten Ausschnitt.
        var merkmal: String {
            var text = bild.merkmal
            if let ausschnitt {
                text += String(format: "|%.5f,%.5f,%.5f",
                               ausschnitt.mitte.breite,
                               ausschnitt.mitte.laenge,
                               ausschnitt.spanne)
            } else {
                text += "|auto"
            }
            return text
        }
    }

    static func geltend(block: Block?, tag: Reisetag?, reise: Reise) -> Geltend {
        var bild = reise.kartenbild
        var bildHerkunft = Herkunft.buch
        if let eigenes = tag?.kartenbild {
            bild = eigenes
            bildHerkunft = .tag
        }
        if let eigenes = block?.kartenbild {
            bild = eigenes
            bildHerkunft = .block
        }

        var ausschnitt = tag?.kartenausschnitt
        // Ohne eigenen Ausschnitt rahmt die Karte die Spur selbst — das ist
        // der Normalfall und keine Abweichung. „Buch" heißt hier deshalb
        // „niemand hat etwas gesagt".
        var ausschnittHerkunft = ausschnitt == nil ? Herkunft.buch : Herkunft.tag
        if let eigener = block?.kartenausschnitt {
            ausschnitt = eigener
            ausschnittHerkunft = .block
        }

        return Geltend(bild: bild, ausschnitt: ausschnitt,
                       bildHerkunft: bildHerkunft,
                       ausschnittHerkunft: ausschnittHerkunft)
    }
}
