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

    // DIE HÖHE, DIE HILFT — mit DERSELBEN Messung gesucht, die auch prüft
    // (ab 1.0.96).
    //
    // Bis 1.0.95 nannte sie `Textmass.hoehe`, also
    // `CTFramesetterSuggestFrameSizeWithConstraints` samt Zuschlag —
    // geprüft wird aber mit `Textmass.passtBis`, also mit einem echten
    // `CTFrame`. **Zwei Messungen für eine Frage, und genau davor warnt
    // dieses Haus an jeder anderen Stelle.** Wo sie auseinandergehen,
    // blieb `max(gemessen, mindestens + 1)` übrig: „Rahmen an Text
    // anpassen" machte den Kasten um einen Punkt höher, die Prüfung
    // meldete ihn weiter — und der Mensch davor hatte keinen Weg mehr
    // (Ansage des Nutzers 09/2026: „Ich weiß tatsächlich nicht, wie ich
    // das ändern kann, so dass kein Fehler gemeldet wird.").
    //
    // Gesucht wird deshalb aufwärts, bis `passtBis` den GANZEN Text setzt:
    // Erst die gemessene Satzhöhe als Anfang, dann je eine Zeile mehr.
    // Damit ist die genannte Millimeterzahl die, die wirklich hilft — und
    // ein Knopf, der sie einsetzt, löst den Befund garantiert auf.
    private static func noetigeHoehe(_ text: String, bild: Schriftbild, breite: Double,
                                     rand: Double, mindestens: Double) -> Double
    {
        let start = max(Textmass.hoehe(text, bild: bild, breite: breite),
                        mindestens - 2 * rand + 1)
        var innen = start
        let schritt = max(bild.zeilenhoehe, 4)
        // Zwölf Zeilen sind die Grenze, nicht die Erwartung: Ohne sie
        // liefe die Schleife bei einem Text, den CoreText in dieser Breite
        // gar nicht setzen kann, für immer.
        for _ in 0..<12 {
            if passtGanz(text, bild: bild, breite: breite, hoehe: innen) { break }
            innen += schritt
        }
        // Nur WACHSEN: Ein Kasten, der beim Anpassen kleiner würde, nähme
        // eine Größe weg, die jemand mit der Hand eingestellt hat.
        return max(innen + 2 * rand, mindestens + 1)
    }

    private static func passtGanz(_ text: String, bild: Schriftbild,
                                  breite: Double, hoehe: Double) -> Bool
    {
        guard hoehe > 1 else { return false }
        let passt = Textmass.passtBis(text, bild: bild,
                                      groesse: CGSize(width: breite, height: hoehe))
        let einheiten = Array(text.utf16)
        guard passt < einheiten.count else { return true }
        // Bleibt nur Leerraum übrig, gilt es als gesetzt — dieselbe Regel
        // wie in `pruefe`, sonst wüchse ein Kasten wegen eines
        // abschließenden Zeilenwechsels ins Leere.
        return String(utf16: Array(einheiten[max(0, passt)...]))
            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
