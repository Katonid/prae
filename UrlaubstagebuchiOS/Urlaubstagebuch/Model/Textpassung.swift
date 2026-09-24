import CoreGraphics
import Foundation

// FÄLLT WIRKLICH ETWAS HERAUS? — gemessen am ERGEBNIS (ab 1.0.94).
//
// Gemeldet 09/2026, mit zwei Bildschirmfotos: Die Druckprüfung nannte 28
// zu kleine Textkästen, darunter „3. August 2026: Bildunterschrift, es
// fehlen 0,3 mm". Auf der Seite daneben stand die Zeile „All my bags are
// packed…" vollständig da. „Ich weiß nicht, wo da bei der Bildunterschrift
// Platz fehlt und wie man es beheben kann."
//
// **Er hat recht, und die Ursache steht in `Textmass.hoehe`:** Die gibt
// nicht die nötige Höhe zurück, sondern eine GROSSZÜGIGE — `ceil(...) + 1`,
// „ein Punkt Zuschlag, damit eine abgeschnittene letzte Zeile nicht wie ein
// Fehler im Buch aussieht". Als Maß beim SETZEN ist das richtig. Als
// PRÜFSCHWELLE war es falsch: Verglichen wurde diese großzügige Zahl mit
// der Rahmenhöhe, und jede Rundung dazwischen — zum Beispiel die aus einem
// Formatwechsel, der Rahmen und Schriftgrößen je für sich auf ein Zehntel
// rundet — meldete einen Fehlbetrag von Bruchteilen eines Millimeters.
// **Ein Befund über 0,3 mm, den man auf der Seite nicht sehen kann, ist
// kein Befund, sondern Lärm** — und er verdeckt die echten.
//
// Gemessen wird deshalb, was CoreGraphics beim Zeichnen wirklich tut:
// `Seitensatz.zeichneText` legt einen `CTFrame` über das Blockrechteck, und
// was darin keinen Platz hat, wird nicht gezeichnet. Genau das zählt
// `Textmass.passtBis` — dieselbe Maschine, dieselbe Silbentrennung,
// dieselbe Breite. Bleibt nichts übrig, ist nichts zu melden.
//
// **Und es ist EINE Stelle.** Bis 1.0.93 stand dieselbe Rechnung zweimal da
// — in `Reisewerk.fehlendeHoehe` für die orange Marke und in
// `Befundstellen.fehlendeHoehe` für die Druckprüfung —, mit dem Kommentar
// „zwei Fassungen ergaben eine Seite, auf der die Marke schweigt und die
// Prüfung anschlägt". Sie standen trotzdem getrennt; jetzt nicht mehr.
enum Textpassung {
    struct Befund {
        /// Wie hoch der BLOCK sein müsste, damit alles hineinpasst.
        var noetig: Double
        /// Was bei der jetzigen Höhe NICHT gesetzt wird — nie leer.
        var ueberhang: String
    }

    static func pruefe(_ block: Block, tag: Reisetag?, reise: Reise) -> Befund? {
        guard block.inhalt.istText else { return nil }
        let text = Seitensatz.inhaltstext(block, tag: tag, reise: reise)
        guard !text.isEmpty, block.rahmen.breite > 1 else { return nil }
        let bild = Seitensatz.schriftbild(block, reise: reise)
        // Gemessen wird in der TEXTbreite, nicht in der Blockbreite: Liegt
        // ein Innenabstand darum, steht dem Text weniger zur Verfügung —
        // und eine Messung ohne ihn meldete „passt", während im Druck eine
        // Zeile fehlt.
        let rand = block.textrand(reise.gestaltung)
        let breite = block.textbreite(rand: rand)
        let hoehe = block.rahmen.hoehe - 2 * rand
        guard breite > 1 else { return nil }

        let sauber = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Ein Rahmen, in den keine einzige Zeile passt, setzt gar nichts.
        // `passtBis` verlangt eine Höhe über 1 und gäbe hier 0 zurück; das
        // Ergebnis wäre dasselbe, der Weg dorthin aber ein Zufall.
        guard hoehe > 1 else {
            return Befund(noetig: noetigeHoehe(text, bild: bild, breite: breite, rand: rand,
                                               mindestens: block.rahmen.hoehe),
                          ueberhang: sauber)
        }

        let passt = Textmass.passtBis(text, bild: bild,
                                      groesse: CGSize(width: breite, height: hoehe))
        let einheiten = Array(text.utf16)
        guard passt < einheiten.count else { return nil }
        // Was übrig bleibt, wird GETRIMMT: Endet der Text auf einen
        // Zeilenwechsel, zählt `passtBis` ihn womöglich nicht mit — und ein
        // Befund über ein unsichtbares Leerzeichen wäre genau der Lärm,
        // gegen den diese Fassung gebaut ist.
        let rest = String(utf16: Array(einheiten[max(0, passt)...]))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rest.isEmpty else { return nil }
        return Befund(noetig: noetigeHoehe(text, bild: bild, breite: breite, rand: rand,
                                           mindestens: block.rahmen.hoehe),
                      ueberhang: rest)
    }

    /// Die Höhe, auf die „Rahmen an Text anpassen" den Block zieht. Hier
    /// ist der Zuschlag aus `Textmass.hoehe` RICHTIG: Der Rahmen soll
    /// großzügig sein, damit die letzte Zeile nicht an der Kante klebt.
    private static func noetigeHoehe(_ text: String, bild: Schriftbild, breite: Double,
                                     rand: Double, mindestens: Double) -> Double
    {
        let gemessen = Textmass.hoehe(text, bild: bild, breite: breite) + 2 * rand
        // Nur WACHSEN: Ein Kasten, der beim Anpassen kleiner würde, nähme
        // eine Größe weg, die jemand mit der Hand eingestellt hat.
        return max(gemessen, mindestens + 1)
    }

    /// Die ersten Wörter des Überhangs — für den Befund. Ohne sie steht
    /// dort eine Millimeterzahl, und der Mensch davor sucht (genau das war
    /// die Meldung).
    static func anriss(_ text: String, zeichen: Int = 42) -> String {
        let sauber = text.replacingOccurrences(of: "\n", with: " ")
        guard sauber.count > zeichen else { return sauber }
        return String(sauber.prefix(zeichen)) + "\u{2026}"
    }
}
