import CoreGraphics
import Foundation

// SEITENZAHL UND KOPFZEILE — an EINER Stelle gerechnet, an zwei
// gezeichnet.
//
// Bis 1.0.49 gab es sie ausschließlich im PDF: `Buchausgabe` war die
// einzige Stelle im ganzen Quelltext, die `gestaltung.seitenzahlen`
// überhaupt las, und der Bildschirm zeichnete davon nichts. Wer die
// Seitenzahlen im Menü einschaltete, sah also nie etwas davon — gemeldet
// 09/2026: „Im Menü kann ich Seitenzahlen aktivieren. Diese kommen auf dem
// Dokument aber niemals zum Vorschein."
//
// Das verstieß gegen die erste Regel dieser App — **Seite und PDF zeichnet
// DERSELBE Setzer** — und zwar an der einen Stelle, an der eine Seite
// nicht aus Blöcken besteht. Blöcke sind Seitenzahl und Kopfzeile nämlich
// bewusst nicht: Sie gehören dem BUCH und nicht dem Tag; als Block lägen
// sie im Satz herum, wo sie jemand verschöbe und der Layoutautomat sie
// beim nächsten Neuanordnen wegräumte (die Regel steht so seit 1.0.0 im
// Papier). Gerechnet wird deshalb hier, und beide Zeichner holen sich die
// fertigen Rechtecke.
//
// **Merke: Wer etwas beim Zeichnen einer Seite ergänzt, ergänzt es an
// BEIDEN Zeichnern** — sonst steht es entweder nur auf dem Bildschirm oder
// nur im Druck, und beides sieht für den Menschen davor nach einem Fehler
// aus.
enum Seitenbeiwerk {
    struct Zeile: Identifiable {
        let id: String
        let text: String
        let bild: Schriftbild
        let rechteck: CGRect
    }

    static func zeilen(_ buchseite: Buchseite, reise: Reise) -> [Zeile] {
        // Eine ganzseitig bebilderte Seite und die Umschlagseiten tragen
        // nichts davon: Die Zahl stünde auf dem Foto und sähe aus wie ein
        // Versehen. Der Umschlag wird zusätzlich an seinem `teil` erkannt
        // und nicht nur an `ohneSeitenzahl` — er trägt seit 1.0.52 gar
        // keine Seitenzahl mehr, weil er im Buchblock nicht mitzählt, und
        // eine 0 unter der Rückseite wäre schlicht falsch.
        guard !buchseite.amUmschlag, !buchseite.seite.ohneSeitenzahl else { return [] }

        let endformat = reise.format.groesse
        let satz = reise.gestaltung.satzspiegel(reise.format)
        var klein = reise.typografie.bildunterschrift
        klein.farbe = .leise

        var liste: [Zeile] = []

        if reise.gestaltung.seitenzahlen {
            var zahl = klein
            zahl.ausrichtung = .mitte
            let y = endformat.height - Druckmass.pt(reise.gestaltung.randUnten) * 0.6
            liste.append(Zeile(
                id: "zahl",
                text: "\(buchseite.nummer)",
                bild: zahl,
                rechteck: CGRect(x: satz.minX, y: y, width: satz.width,
                                 height: zahl.zeilenhoehe * 1.6)
            ))
        }

        if reise.gestaltung.kopfzeile {
            var kopf = klein
            kopf.ausrichtung = .rechts
            kopf.versalien = true
            kopf.sperrung = 1.2
            let text = buchseite.tag?.datum.mittel ?? reise.titel
            let y = Druckmass.pt(reise.gestaltung.randOben) * 0.42
            liste.append(Zeile(
                id: "kopf",
                text: text,
                bild: kopf,
                rechteck: CGRect(x: satz.minX, y: y, width: satz.width,
                                 height: kopf.zeilenhoehe * 1.6)
            ))
        }

        return liste
    }
}
