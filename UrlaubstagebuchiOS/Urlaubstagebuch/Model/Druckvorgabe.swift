import CoreGraphics
import Foundation

// WAS EINE DRUCKEREI NENNT, IST DER BOGEN — NICHT DIE SEITE (ab 1.0.72).
//
// Gemeldet 09/2026 aus einem echten Auftrag: „Das Format der erhaltenen
// Daten stimmt nicht mit der Bestellung überein. Bitte legen Sie Ihre Daten
// im Format 216 mm x 303 mm an. Dieses beinhaltet das bestellte Endformat
// und die benötigte Beschnittzugabe."
//
// Nachgerechnet: 216 − 2 × 3 = 210, 303 − 2 × 3 = 297. Die Druckerei
// verlangt also **A4 hoch mit 3 mm Anschnitt** — und genau das gibt diese
// App seit jeher aus (`Gestaltung.bogen`). Die Zahl war nie falsch; sie
// stand nur nirgends so da, dass man sie gegen die Bestellung halten
// konnte, und der Weg, sie einzutippen, führte in die Irre.
//
// **DAS IST DIE FALLE, UM DIE ES HIER GEHT.** Seit 1.0.52 lässt sich ein
// eigenes Maß als Format eintragen. Wer die Zahl der Druckerei dort
// einträgt, bekommt eine PDF-Seite von 222 × 309 mm — Endformat plus ein
// zweites Mal Anschnitt —, und die Datei wird wieder abgewiesen. Schlimmer:
// `Formatwechsel` rechnet dabei jeden Block, jeden Rand und jede
// Schriftgröße des Buches um. Ein Fehler, der wie eine Lösung aussieht.
//
// Gerechnet wird deshalb HIER, an einer Stelle, und die Oberfläche fragt
// nach dem Maß der DRUCKEREI statt nach dem Endformat.
enum Druckvorgabe {
    // MARK: - Die Innenseiten

    /// Das Endformat, das zu einem geforderten Bogenmaß gehört.
    /// `nil`, wenn dabei nichts Gültiges herauskommt — das ist der Fall,
    /// wenn jemand versehentlich ein Endformat in diese Felder tippt und
    /// der Anschnitt es unter die Untergrenze zieht.
    static func endformat(bogenBreite: Double, bogenHoehe: Double,
                          anschnitt: Double) -> Seitenformat?
    {
        let b = bogenBreite - 2 * anschnitt
        let h = bogenHoehe - 2 * anschnitt
        guard Seitenformat.gueltig(b), Seitenformat.gueltig(h) else { return nil }
        return Seitenformat(breite: runden(b), hoehe: runden(h))
    }

    /// Das Bogenmaß in Millimetern, das aus einem Format folgt — die Zahl,
    /// die im PDF steht und die eine Druckerei prüft.
    static func bogen(_ format: Seitenformat, anschnitt: Double) -> CGSize {
        CGSize(width: format.breite + 2 * anschnitt,
               height: format.hoehe + 2 * anschnitt)
    }

    // MARK: - Der Umschlagbogen

    /// Die Breite des Umschlagbogens: zwei Seiten, der Rücken und außen
    /// zweimal Anschnitt. Am Bund gibt es keinen — der Umschlag ist EIN
    /// Stück Papier und wird dort gefalzt, nicht geschnitten.
    static func umschlagbogen(_ format: Seitenformat, anschnitt: Double,
                              ruecken: Double) -> CGSize
    {
        CGSize(width: 2 * format.breite + max(0, ruecken) + 2 * anschnitt,
               height: format.hoehe + 2 * anschnitt)
    }

    /// Welche Rückenstärke zu einer geforderten Umschlagbreite gehört.
    /// `nil`, wenn dabei etwas Negatives herauskäme — dann passt das
    /// Seitenformat nicht zu der Angabe, und das ist der wichtigere Befund.
    static func rueckenAusBogen(_ breite: Double, format: Seitenformat,
                                anschnitt: Double) -> Double?
    {
        let rest = breite - 2 * format.breite - 2 * anschnitt
        guard rest >= -0.05 else { return nil }
        return runden(max(0, rest))
    }

    // MARK: - Der Verdacht

    /// Sieht ein eingetipptes ENDFORMAT in Wahrheit nach einem BOGENMASS
    /// aus? Wenn ja, das Format, das wahrscheinlich gemeint war.
    ///
    /// Eng gefasst mit Absicht: Erkannt wird nur, was nach Abzug des
    /// Anschnitts auf eine bekannte Vorlage fällt. Ein frei gewähltes Maß,
    /// das zufällig sechs Millimeter über irgendetwas liegt, wird NICHT
    /// angesprochen — ein Hinweis, der bei jedem zweiten Maß erscheint,
    /// wird nach dem dritten Mal überlesen.
    ///
    /// Es ist ein HINWEIS und keine Sperre. Wer wirklich 216 × 303 als
    /// Endformat bestellt hat, soll es eintragen können.
    static func bogenverdacht(breite: Double, hoehe: Double,
                              anschnitt: Double) -> Seitenformat?
    {
        guard anschnitt > 0.05 else { return nil }
        let b = breite - 2 * anschnitt
        let h = hoehe - 2 * anschnitt
        guard Seitenformat.gueltig(b), Seitenformat.gueltig(h) else { return nil }
        return Seitenformat.vorlagen.first {
            abs($0.breite - b) < 0.5 && abs($0.hoehe - h) < 0.5
        }
    }

    // MARK: - Hinschreiben

    /// Ein Maß in Millimetern, wie es in einer Bestellung steht.
    static func masstext(_ groesse: CGSize) -> String {
        "\(zahl(groesse.width)) \u{00D7} \(zahl(groesse.height)) mm"
    }

    static func zahl(_ wert: Double) -> String {
        let gerundet = (wert * 10).rounded() / 10
        if abs(gerundet - gerundet.rounded()) < 0.05 {
            return String(Int(gerundet.rounded()))
        }
        return String(format: "%.1f", gerundet).replacingOccurrences(of: ".", with: ",")
    }

    // Auf ein Zehntel Millimeter. Feiner ist keine Bestellung, und eine
    // Zahl wie 209,99999 sähe aus wie ein Fehler der App.
    private static func runden(_ wert: Double) -> Double {
        (wert * 10).rounded() / 10
    }
}
