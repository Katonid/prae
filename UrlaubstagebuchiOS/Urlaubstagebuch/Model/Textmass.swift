import CoreText
import Foundation
import UIKit

// Wie hoch ein Text in einer gegebenen Breite wird, und wie viel davon in
// einen gegebenen Kasten passt.
//
// Beides wird GEMESSEN und nicht geschätzt. Eine Schätzung aus Zeichenzahl
// mal Schriftgröße ist bei einer Proportionalschrift regelmäßig um ein
// Drittel daneben — und das Ergebnis wäre ein Buch, in dem der Text unten
// aus der Seite läuft oder eine halbe Seite leer bleibt. Gerechnet wird
// mit CoreText, also mit demselben Satz, der hinterher auch zeichnet.
enum Textmass {
    static func rahmensetzer(_ text: String, bild: Schriftbild) -> CTFramesetter {
        CTFramesetterCreateWithAttributedString(bild.gesetzt(text) as CFAttributedString)
    }

    static func hoehe(_ text: String, bild: Schriftbild, breite: Double) -> Double {
        guard !text.isEmpty, breite > 1 else { return 0 }
        let setzer = rahmensetzer(text, bild: bild)
        var gebraucht = CFRange()
        let groesse = CTFramesetterSuggestFrameSizeWithConstraints(
            setzer,
            CFRange(location: 0, length: 0),
            nil,
            CGSize(width: breite, height: .greatestFiniteMagnitude),
            &gebraucht
        )
        // Ein Punkt Zuschlag: `SuggestFrameSize` rundet nach unten, und eine
        // abgeschnittene letzte Zeile sieht aus wie ein Fehler im Buch.
        return ceil(groesse.height) + 1
    }

    // Wie viele Zeichen in den Kasten passen. Gebraucht für den Textfluss
    // über mehrere Seiten: Was hier nicht mehr hineingeht, beginnt die
    // nächste Seite.
    static func passtBis(_ text: String, bild: Schriftbild, groesse: CGSize) -> Int {
        guard !text.isEmpty, groesse.width > 1, groesse.height > 1 else { return 0 }
        let setzer = rahmensetzer(text, bild: bild)
        let pfad = CGPath(rect: CGRect(origin: .zero, size: groesse), transform: nil)
        let rahmen = CTFramesetterCreateFrame(setzer, CFRange(location: 0, length: 0), pfad, nil)
        let sichtbar = CTFrameGetVisibleStringRange(rahmen)
        return sichtbar.length
    }

    // Wo geteilt wurde. Gebraucht wird das nicht zum Rechnen, sondern zum
    // Hinschreiben: Eine Seite, die an einer Wortgrenze aufhört, sieht
    // anders aus als eine, die an einem Absatz aufhört, und wer sich
    // wundert, soll nachlesen können, warum.
    enum Schnittart {
        case absatz
        case wort
        // Nichts zu teilen — der Text passte ganz hinein.
        case ganz
    }

    // Teilt einen Text an der Stelle, an der die Seite voll ist.
    //
    // ZUERST wird ein ABSATZ gesucht (Ansage des Nutzers, 09/2026: „Dabei
    // wäre es schön, wenn an einem bestehenden Absatz umgebrochen
    // wird."). Ein Absatz ist eine gedankliche Einheit; mitten in ihm
    // umzubrechen ist im Buch zu sehen, auch wenn kein Wort verloren geht.
    //
    // Der Absatz gewinnt aber NICHT um jeden Preis: Steht die letzte
    // Absatzgrenze weit oben auf der Seite — ein einziger langer Absatz
    // füllt den Rest —, bliebe unten eine große weiße Fläche stehen,
    // und die sieht nach Abbruch aus. Gemessen wird deshalb, wie hoch der
    // Kopf bis zu dieser Grenze WIRD, und verglichen mit dem Platz, den es
    // gibt. Bleibt weniger als `mindestfuellung` davon gefüllt, wird wie
    // bisher an der Wortgrenze geteilt. Die Zahl ist gewählt und nicht
    // gemessen: 0,62 lässt höchstens gut ein Drittel Seite frei.
    static func teilen(_ text: String, bild: Schriftbild, groesse: CGSize,
                       anAbsatz: Bool = true, mindestfuellung: Double = 0.62)
        -> (kopf: String, rest: String)
    {
        let geteilt = teilenMitArt(text, bild: bild, groesse: groesse,
                                   anAbsatz: anAbsatz, mindestfuellung: mindestfuellung)
        return (geteilt.kopf, geteilt.rest)
    }

    static func teilenMitArt(_ text: String, bild: Schriftbild, groesse: CGSize,
                             anAbsatz: Bool = true, mindestfuellung: Double = 0.62)
        -> (kopf: String, rest: String, art: Schnittart)
    {
        let laenge = passtBis(text, bild: bild, groesse: groesse)
        guard laenge > 0 else { return ("", text, .wort) }
        let utf16 = Array(text.utf16)
        guard laenge < utf16.count else { return (text, "", .ganz) }

        if anAbsatz, let grenze = absatzgrenze(utf16, bis: laenge) {
            let kopf = String(utf16: Array(utf16[0..<grenze]))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !kopf.isEmpty {
                let kopfhoehe = Self.hoehe(kopf, bild: bild, breite: groesse.width)
                if kopfhoehe >= groesse.height * mindestfuellung {
                    let rest = String(utf16: Array(utf16[grenze...]))
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !rest.isEmpty { return (kopf, rest, .absatz) }
                }
            }
        }

        var schnitt = laenge
        while schnitt > 0 {
            let zeichen = utf16[schnitt - 1]
            if zeichen == 32 || zeichen == 10 || zeichen == 9 { break }
            schnitt -= 1
        }
        if schnitt == 0 { schnitt = laenge }
        let kopf = String(utf16: Array(utf16[0..<schnitt]))
        let rest = String(utf16: Array(utf16[schnitt...]))
        return (kopf.trimmingCharacters(in: .whitespacesAndNewlines),
                rest.trimmingCharacters(in: .whitespacesAndNewlines),
                .wort)
    }

    // Die letzte Absatzgrenze vor `bis` — also hinter dem letzten
    // Zeilenwechsel, der noch auf die Seite passt.
    //
    // Gesucht wird nach dem Zeilenwechsel und nicht nach einer Leerzeile:
    // Was ein Absatz ist, entscheidet in diesem Buch der Zeilenwechsel —
    // `Schriftbild` setzt den Absatzabstand als `paragraphSpacing`, und
    // CoreText zählt dafür genau dieselbe Grenze. Zwei Meinungen darüber,
    // wo ein Absatz aufhört, wären zwei verschiedene Umbrüche.
    private static func absatzgrenze(_ utf16: [UInt16], bis: Int) -> Int? {
        var stelle = min(bis, utf16.count)
        while stelle > 0 {
            let zeichen = utf16[stelle - 1]
            // U+2028/U+2029 sind Zeilen- und Absatztrenner; sie stehen in
            // Texten aus Word und aus PDFs und wären sonst unsichtbar.
            if zeichen == 10 || zeichen == 13 || zeichen == 0x2028 || zeichen == 0x2029 {
                return stelle
            }
            stelle -= 1
        }
        return nil
    }
}

extension String {
    init(utf16 einheiten: [UInt16]) {
        self = String(decoding: einheiten, as: UTF16.self)
    }
}
