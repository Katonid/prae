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
        // U2 und U3 tragen auch dann keine, wenn sie im Innenteil stehen
        // (ab 1.0.112): Ihre Nummer ist 0, und dort wird verklebt.
        guard buchseite.teil == .innen, !buchseite.seite.ohneSeitenzahl else { return [] }

        let endformat = reise.format.groesse
        let satz = reise.gestaltung.satzspiegel(reise.format)
        // WO DER SICHERHEITSABSTAND LIEGT — und das ist hier kein Zierat
        // (ab 1.0.82).
        //
        // Seitenzahl und Kopfzeile sitzen in den RÄNDERN, als Anteil davon
        // (0,6 bzw. 0,42). Solange die Ränder 16 bis 19 mm maßen, lag das
        // von selbst weit genug innen. Seit die Ränder bis auf den
        // Sicherheitsabstand hinuntergehen dürfen — gefragt 09/2026: „Der
        // Satzspiegel könnte doch tatsächlich innerhalb des
        // Sicherheitsabstandes ausgeführt werden." — stimmt das nicht mehr:
        // Bei 3 mm Rand unten stünde die Seitenzahl 1,8 mm vom Papierrand
        // und würde angeschnitten.
        //
        // **Und es fiele niemandem auf**: Die Marke um einen gefährdeten
        // Block greift hier nicht, denn Seitenzahl und Kopfzeile sind keine
        // Blöcke — sie gehören dem Buch und werden beim Zeichnen ergänzt
        // (Regel seit 1.0.0). Geklemmt wird deshalb hier. **Merke: Wer eine
        // Grenze freigibt, sucht alles, was sich bisher auf sie verlassen
        // hat.**
        let zone = reise.gestaltung.hatSicherheitsabstand
            ? reise.gestaltung.schutzzone(reise.format, bund: buchseite.bundlage)
            : CGRect(origin: .zero, size: endformat)
        var klein = reise.typografie.bildunterschrift
        klein.farbe = .leise

        var liste: [Zeile] = []

        if reise.gestaltung.seitenzahlen {
            var zahl = klein
            zahl.ausrichtung = .mitte
            let hoehe = zahl.zeilenhoehe * 1.6
            // Nach unten bis zur Sicherheitslinie und keinen Punkt weiter;
            // nach oben nicht über den Satzspiegel, sonst stünde sie im Text.
            let gewuenscht = endformat.height - Druckmass.pt(reise.gestaltung.randUnten) * 0.6
            let y = max(min(gewuenscht, zone.maxY - hoehe), satz.maxY)
            liste.append(Zeile(
                id: "zahl",
                text: "\(buchseite.nummer)",
                bild: zahl,
                rechteck: CGRect(x: satz.minX, y: y, width: satz.width, height: hoehe)
            ))
        }

        if reise.gestaltung.kopfzeile {
            var kopf = klein
            kopf.ausrichtung = .rechts
            kopf.versalien = true
            kopf.sperrung = 1.2
            let text = buchseite.tag?.datum.mittel ?? reise.titel
            let hoehe = kopf.zeilenhoehe * 1.6
            let gewuenscht = Druckmass.pt(reise.gestaltung.randOben) * 0.42
            let y = min(max(gewuenscht, zone.minY), max(satz.minY - hoehe, zone.minY))
            liste.append(Zeile(
                id: "kopf",
                text: text,
                bild: kopf,
                rechteck: CGRect(x: satz.minX, y: y, width: satz.width, height: hoehe)
            ))
        }

        return liste
    }
}
