import CoreGraphics
import Foundation

// EIN BUCH IN EIN ANDERES FORMAT UMRECHNEN (ab 1.0.27).
//
// Ansage des Nutzers, 09/2026: „Ich denke, dass ich mein erstes Projekt im
// DIN A4 Format hochkant drucken lassen möchte. Allerdings möchte ich
// zusätzlich eine Version auf dem heimischen Drucker ausdrucken können …
// würde das Format dann auf ein DIN A5 Buch schrumpfen. Ich weiß, dass es
// problematisch sein könnte, die Größe der Schriften im Dokument
// herunterzurechnen, aber ich hoffe, dass es eine Möglichkeit gibt, ohne
// viel Aufwand aus dem DIN A4 Projekt ein A5 Projekt zu machen."
//
// Es gibt sie, und sie ist bei genau diesem Paar sogar verlustfrei: **A4
// und A5 haben dasselbe Seitenverhältnis** (die ganze A-Reihe hat es, das
// ist ihre Bauvorschrift). Ein Buch von A4 auf A5 zu bringen ist deshalb
// eine einzige Multiplikation mit 1/√2 ≈ 0,707 — auf ALLES, was eine Länge
// ist: Blockrahmen, Ränder, Schriftgrößen, Innenabstände, Linienbreiten.
// Danach steht jeder Block relativ an derselben Stelle und wirkt in
// derselben Größe; nur das Papier ist kleiner.
//
// **Was NICHT mitskaliert wird, ist der Anschnitt.** Er ist keine
// Gestaltung, sondern eine Angabe der Druckerei: Drei Millimeter sind drei
// Millimeter, egal wie groß die Seite ist. Wer ihn mitschrumpfte, lieferte
// eine Datei, die formal stimmt und beim Schneiden einen weißen Faden
// bekommt.
//
// **Und was bei UNÄHNLICHEN Formaten passiert, steht dabei.** Von A4 hoch
// auf 28 × 28 cm gibt es keinen Faktor, der beides trifft; genommen wird
// der KLEINERE der beiden (`min`), damit nichts über die Seite hinausläuft.
// Der Satz steht auch in der Oberfläche — eine Umrechnung, die das
// verschweigt, sieht aus wie ein Fehler im Satz.
enum Formatwechsel {
    // Der Faktor, mit dem gerechnet wird.
    //
    // Der KLEINERE der beiden Verhältnisse: Bei ähnlichen Formaten sind
    // beide gleich und die Wahl ist ohne Folgen; bei unähnlichen ist er
    // die einzige, bei der kein Block aus der Seite fällt.
    static func faktor(von alt: Seitenformat, auf neu: Seitenformat) -> Double {
        guard alt.breite > 0, alt.hoehe > 0 else { return 1 }
        return min(neu.breite / alt.breite, neu.hoehe / alt.hoehe)
    }

    // Was die Umrechnung anfassen wird — als Satz, vor dem Tippen.
    //
    // Dieselbe Regel wie bei jeder Einfuhr dieser App: erst zeigen, dann
    // übernehmen. Ein Buch umzurechnen fasst jeden Block an; wer das
    // auslöst, soll vorher wissen, was passiert.
    static func vorschau(reise: Reise, auf neu: Seitenformat) -> Vorschau {
        let alt = reise.format
        let f = faktor(von: alt, auf: neu)
        var bloecke = reise.umschlag.titelbloecke.count + reise.umschlag.rueckbloecke.count
        for tag in reise.tage {
            for seite in tag.seiten { bloecke += seite.bloecke.count }
        }
        return Vorschau(
            alt: alt, neu: neu, faktor: f,
            bloecke: bloecke,
            aehnlich: alt.aehnlichZu(neu),
            fliesstextAlt: reise.typografie.flieText.groesse,
            fliesstextNeu: ((reise.typografie.flieText.groesse * f) * 10).rounded() / 10
        )
    }

    struct Vorschau {
        var alt: Seitenformat
        var neu: Seitenformat
        var faktor: Double
        var bloecke: Int
        var aehnlich: Bool
        var fliesstextAlt: Double
        var fliesstextNeu: Double

        var prozent: String {
            String(format: "%.1f", faktor * 100).replacingOccurrences(of: ".", with: ",")
        }
    }

    // Die Umrechnung selbst. Sie ändert das Format UND alles, was daran
    // hängt — in einem Zug, damit es keinen Zwischenstand gibt, in dem ein
    // A5-Papier A4-Blöcke trägt.
    static func umrechnen(_ reise: inout Reise, auf neu: Seitenformat) {
        let f = faktor(von: reise.format, auf: neu)
        reise.format = neu
        guard f > 0, abs(f - 1) > 0.0005 else { return }

        // Die Gestaltung: alles, was eine LÄNGE ist. `anschnitt` bleibt —
        // siehe oben. `kartenanteil` ist ein Anteil und bleibt ebenfalls.
        // Und `sicherheitsabstand` bleibt AUS DEMSELBEN GRUND wie der
        // Anschnitt (ab 1.0.73): Das Spiel der Schneidemaschine ist
        // dasselbe, ob eine Seite A4 misst oder A5. Wer ihn mitschrumpfte,
        // bekäme auf der kleineren Seite genau dort weniger Schutz, wo der
        // Rand ohnehin knapper wird.
        var g = reise.gestaltung
        g.randAussen = gerundet(g.randAussen * f)
        g.randOben = gerundet(g.randOben * f)
        g.randUnten = gerundet(g.randUnten * f)
        g.fuge = gerundet(g.fuge * f)
        g.bundsteg = gerundet(g.bundsteg * f)
        g.fotorand = gerundet(g.fotorand * f)
        g.fotorandbreite = gerundet(g.fotorandbreite * f)
        g.textinnenabstand = gerundet(g.textinnenabstand * f)
        g.textrandbreite = gerundet(g.textrandbreite * f)
        g.eckenradius = gerundet(g.eckenradius * f)
        reise.gestaltung = g

        reise.typografie.groessenSkalieren(f)

        for tagIndex in reise.tage.indices {
            for seiteIndex in reise.tage[tagIndex].seiten.indices {
                for blockIndex in reise.tage[tagIndex].seiten[seiteIndex].bloecke.indices {
                    skaliere(&reise.tage[tagIndex].seiten[seiteIndex].bloecke[blockIndex],
                             mal: f)
                }
                // Die Wasserzeichen-Korrektur einer Seite ist eine LÄNGE
                // in Millimetern und wird deshalb mitgerechnet (ab 1.0.54)
                // — der WINKEL daneben nicht, aus demselben Grund, aus dem
                // die Drehung eines Blocks stehen bleibt.
                if var eigen = reise.tage[tagIndex].seiten[seiteIndex].wasserzeichen {
                    eigen.versatzX = gerundet(eigen.versatzX * f)
                    eigen.versatzY = gerundet(eigen.versatzY * f)
                    reise.tage[tagIndex].seiten[seiteIndex].wasserzeichen = eigen
                }
            }
        }

        // Die eigenen Felder auf Titel- und Rückseite (ab 1.0.64). Sie
        // stehen nicht in einem Tag, sondern am Umschlag — mitgerechnet
        // werden sie trotzdem: Ein Rahmen ist eine LÄNGE, und ohne die
        // Umrechnung säße er nach einem Wechsel von A4 auf A5 halb außerhalb
        // der Seite.
        for stelle in reise.umschlag.titelbloecke.indices {
            skaliere(&reise.umschlag.titelbloecke[stelle], mal: f)
        }
        for stelle in reise.umschlag.rueckbloecke.indices {
            skaliere(&reise.umschlag.rueckbloecke[stelle], mal: f)
        }
    }

    // Ein einzelner Block. Der AUSSCHNITT eines Fotos bleibt unangetastet:
    // `zoom` und die beiden Versätze sind Anteile am Bild und keine
    // Längen — wer sie mitrechnete, verschöbe jedes Bild in seinem Rahmen.
    // `drehung` ist ein Winkel und bleibt aus demselben Grund stehen.
    private static func skaliere(_ block: inout Block, mal f: Double) {
        block.rahmen = Rahmen(x: block.rahmen.x * f,
                              y: block.rahmen.y * f,
                              breite: block.rahmen.breite * f,
                              hoehe: block.rahmen.hoehe * f)
        if let groesse = block.abweichung.groesse {
            block.abweichung.groesse = gerundet(groesse * f)
        }
        if let absatz = block.abweichung.absatzabstand {
            block.abweichung.absatzabstand = gerundet(absatz * f)
        }
        if let sperrung = block.abweichung.sperrung {
            block.abweichung.sperrung = gerundet(sperrung * f, stellen: 100)
        }
        if let breite = block.randbreite { block.randbreite = gerundet(breite * f) }
        if let rand = block.fotorand { block.fotorand = gerundet(rand * f) }
        if let innen = block.innenabstand { block.innenabstand = gerundet(innen * f) }
    }

    private static func gerundet(_ wert: Double, stellen: Double = 10) -> Double {
        (wert * stellen).rounded() / stellen
    }
}
