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
    // DIE BREITE GEHÖRT DAZU (ab 1.0.40) — und zwar an JEDER Aufrufstelle.
    //
    // Seit die Silbentrennung von Hand gesetzt wird, hängt der gesetzte
    // Text an der Breite: Wo die Zeile umbricht, entscheidet, welches Wort
    // getrennt wird. Messen und Zeichnen müssen deshalb dieselbe Breite
    // nennen — sonst hätte der Setzer, der die Höhe ausrechnet, andere
    // Striche als der, der die Seite zeichnet, und der Text liefe unten aus
    // seinem Block. Genau die Regel, aus der diese Datei überhaupt
    // entstanden ist, nur eine Ebene tiefer.
    static func rahmensetzer(_ text: String, bild: Schriftbild, breite: Double) -> CTFramesetter {
        getrennt(text, bild: bild, breite: breite).setzer
    }

    private static func getrennt(_ text: String, bild: Schriftbild, breite: Double)
        -> (setzer: CTFramesetter, trennung: Silbentrennung.Ergebnis)
    {
        let trennung = Silbentrennung.getrennt(text, bild: bild, breite: breite)
        let setzer = CTFramesetterCreateWithAttributedString(
            bild.gesetzt(trennung.text) as CFAttributedString
        )
        return (setzer, trennung)
    }

    static func hoehe(_ text: String, bild: Schriftbild, breite: Double) -> Double {
        guard !text.isEmpty, breite > 1 else { return 0 }
        let setzer = rahmensetzer(text, bild: bild, breite: breite)
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

    // Wie BREIT ein Text von sich aus wird — höchstens `hoechstens`.
    //
    // Gebraucht für den Buchrücken (ab 1.0.63): Dort soll sich die Schrift
    // verschieben lassen, und verschieben kann man nur einen Kasten, der
    // schmaler ist als sein Platz. Ein Kasten über die ganze Länge sähe
    // mittig zentriert immer gleich aus, wie weit man den Regler auch
    // schöbe.
    static func breite(_ text: String, bild: Schriftbild, hoechstens: Double) -> Double {
        guard !text.isEmpty, hoechstens > 1 else { return 0 }
        let setzer = rahmensetzer(text, bild: bild, breite: hoechstens)
        var gebraucht = CFRange()
        let groesse = CTFramesetterSuggestFrameSizeWithConstraints(
            setzer,
            CFRange(location: 0, length: 0),
            nil,
            CGSize(width: hoechstens, height: .greatestFiniteMagnitude),
            &gebraucht
        )
        // Derselbe Punkt Zuschlag wie bei der Höhe, aus demselben Grund.
        return min(ceil(groesse.width) + 1, hoechstens)
    }

    // Wie viele Zeichen in den Kasten passen. Gebraucht für den Textfluss
    // über mehrere Seiten: Was hier nicht mehr hineingeht, beginnt die
    // nächste Seite.
    static func passtBis(_ text: String, bild: Schriftbild, groesse: CGSize) -> Int {
        guard !text.isEmpty, groesse.width > 1, groesse.height > 1 else { return 0 }
        let (setzer, trennung) = getrennt(text, bild: bild, breite: Double(groesse.width))
        let pfad = CGPath(rect: CGRect(origin: .zero, size: groesse), transform: nil)
        let rahmen = CTFramesetterCreateFrame(setzer, CFRange(location: 0, length: 0), pfad, nil)
        let sichtbar = CTFrameGetVisibleStringRange(rahmen)
        // ZURÜCK IN DEN URTEXT. `sichtbar.length` zählt Zeichen des
        // GESETZTEN Textes, also samt der eingefügten Trennstriche —
        // `teilen` schneidet damit aber den Tagebuchtext. Ohne diese
        // Umrechnung wanderten die Striche über `Neuverteilung` mitten in
        // die Wörter von `tag.text`, und zwar dauerhaft.
        return trennung.imUrtext(sichtbar.length)
    }

    // WIE VIELE ZEICHEN AUF EINER ZEILE STEHEN — gemessen, nicht geschätzt
    // (ab 1.0.37).
    //
    // Die Zeilenlänge ist die eine Zahl, an der sich Lesbarkeit festmachen
    // lässt, und sie ist der Grund für die Höchstbreite der Textspalte
    // (`Gestaltung.textspaltenanteil`). Eine Zahl, die eine Einstellung
    // rechtfertigt, darf keine Behauptung sein: Gezählt wird mit demselben
    // CoreText-Umbruch, der hinterher zeichnet.
    //
    // Die LETZTE Zeile bleibt draußen. Sie endet dort, wo der Text aufhört,
    // und wäre bei einem kurzen Absatz die halbe Messung — bei einem Text
    // aus lauter Einzeilern gäbe es dann gar nichts zu messen, und genau der
    // kommt hier vor (ein hart umbrochenes Tagebuch). Bleibt danach nichts
    // übrig, wird die einzige Zeile gezählt, statt null zurückzugeben.
    static func zeichenJeZeile(_ text: String, bild: Schriftbild, breite: Double) -> Int {
        guard !text.isEmpty, breite > 1 else { return 0 }
        let setzer = rahmensetzer(text, bild: bild, breite: breite)
        let hoch = max(hoehe(text, bild: bild, breite: breite), 1) + bild.zeilenhoehe * 2
        let pfad = CGPath(rect: CGRect(x: 0, y: 0, width: breite, height: hoch), transform: nil)
        let rahmen = CTFramesetterCreateFrame(setzer, CFRange(location: 0, length: 0), pfad, nil)
        guard let zeilen = CTFrameGetLines(rahmen) as? [CTLine], !zeilen.isEmpty else { return 0 }
        // Eine Zeile, die mit einem Zeilenwechsel endet, ist ein
        // Absatzschluss und damit genauso ein Sonderfall wie die letzte.
        let laengen = zeilen.map { CTLineGetStringRange($0).length }
        let voll = laengen.count > 1 ? Array(laengen.dropLast()) : laengen
        guard !voll.isEmpty else { return 0 }
        return Int((Double(voll.reduce(0, +)) / Double(voll.count)).rounded())
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
    // DER ABSATZ GEWINNT. Immer (ab 1.0.37).
    //
    // Ansage des Nutzers, 09/2026, zum zweiten Mal: „Ich hatte aber gesagt,
    // dass die Trennstellen dabei nach den Absätzen sein sollen. Ich finde
    // aber Trennstellen, die quasi mitten im Text passieren. Das möchte ich
    // nicht."
    //
    // Er hat recht, und die Stelle, an der es schiefging, ist auszurechnen:
    // Bis 1.0.36 stand hier ein `mindestfuellung` von 0,62 — die Absatzgrenze
    // galt nur, wenn der Kopf danach noch mindestens 62 Prozent des Kastens
    // füllte, sonst wurde an der WORTgrenze geteilt. Gebaut wurde das in
    // 1.0.14 gegen eine große weiße Fläche am Fuß der Seite.
    //
    // DIESE ABWÄGUNG IST SEIT 1.0.35 HINFÄLLIG. Damals bestand eine Seite aus
    // einer Textspalte und darunter aus Fotoreihen; blieb der Text kurz, blieb
    // unten Papier. Seither füllt `Mosaik` die Seite: Was der Text nicht
    // braucht, bekommen die Bilder, und `seiteFuellen` nimmt so lange ein Bild
    // dazu, bis der Platz aufgeht. Die weiße Fläche, gegen die
    // `mindestfuellung` gebaut war, gibt es also gar nicht mehr — die Regel
    // stand noch da und hat nur noch geschadet.
    //
    // Sie ist deshalb ERSATZLOS entfernt und nicht auf 0 gestellt: Ein
    // Parameter, der nur noch einen Wert haben darf, wird irgendwann wieder
    // ein anderer (dieselbe Regel wie beim Sperrmechanismus in Schulalarm
    // 1.1.0).
    //
    // An der Wortgrenze wird nur noch geteilt, wenn im Kasten ÜBERHAUPT keine
    // Absatzgrenze liegt — ein einziger Absatz, der für sich schon länger ist
    // als der Platz. Dann gibt es keine Wahl; die Druckprüfung zählt diese
    // Stellen und nennt Tag und Seite, statt sie stillschweigend hinzunehmen.
    static func teilen(_ text: String, bild: Schriftbild, groesse: CGSize,
                       anAbsatz: Bool = true)
        -> (kopf: String, rest: String)
    {
        let geteilt = teilenMitArt(text, bild: bild, groesse: groesse, anAbsatz: anAbsatz)
        return (geteilt.kopf, geteilt.rest)
    }

    static func teilenMitArt(_ text: String, bild: Schriftbild, groesse: CGSize,
                             anAbsatz: Bool = true)
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
                let rest = String(utf16: Array(utf16[grenze...]))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !rest.isEmpty { return (kopf, rest, .absatz) }
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
