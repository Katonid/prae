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

    // Teilt an einer WORTGRENZE, nicht mitten im Wort. CoreText gibt die
    // Zahl der gesetzten Zeichen zurück; die letzte Zeile endet aber oft
    // mitten in einem Wort, wenn sie nur halb hineinpasste.
    static func teilen(_ text: String, bild: Schriftbild, groesse: CGSize) -> (kopf: String, rest: String) {
        let laenge = passtBis(text, bild: bild, groesse: groesse)
        guard laenge > 0 else { return ("", text) }
        let utf16 = Array(text.utf16)
        guard laenge < utf16.count else { return (text, "") }
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
                rest.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

extension String {
    init(utf16 einheiten: [UInt16]) {
        self = String(decoding: einheiten, as: UTF16.self)
    }
}
