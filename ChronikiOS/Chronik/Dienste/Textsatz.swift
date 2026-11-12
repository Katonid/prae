import UIKit

// DER TEXTSATZ.
//
// Gemessen UND gezeichnet wird über TextKit (`NSLayoutManager` beim
// Messen, `NSAttributedString.draw` beim Zeichnen — beide derselbe
// Umbruch). Wer hier eine zweite Satzmaschine dazunimmt (SwiftUIs `Text`,
// CoreText), bekommt zwei Ergebnisse: Ein Stück, das beim Messen auf die
// Seite passte, liefe beim Zeichnen unten hinaus.
//
// Ein Folgestück beginnt immer an einem Zeilenanfang. Darum bricht es beim
// Zeichnen genauso um wie beim Messen.
enum Textsatz {
    static func schrift(_ name: String, _ groesse: CGFloat) -> UIFont {
        UIFont(name: name, size: groesse) ?? .systemFont(ofSize: groesse)
    }

    static let grund = "Georgia"
    static let fett = "Georgia-Bold"
    static let kursiv = "Georgia-Italic"

    static func absatz(_ ausrichtung: NSTextAlignment, danach: CGFloat = 0, trennen: Bool = true) -> NSParagraphStyle {
        let p = NSMutableParagraphStyle()
        p.alignment = ausrichtung
        p.lineHeightMultiple = 1.15
        p.paragraphSpacing = danach
        // Getrennt wird von Apples Wörterbuch, nicht von uns.
        p.hyphenationFactor = trennen ? 0.8 : 0
        return p
    }

    static func datumszeile(_ d: Date) -> String {
        Zeitraster.text(d, "EEEE, d. MMMM yyyy · HH:mm")
    }

    /// Ein Tagebuchtext mit Überschrift und Datumszeile, im Stil des Buches.
    ///
    /// Modern: Überschrift in Didot, Datumszeile in Versalien mit
    /// Sperrung in der Akzentfarbe, die ersten Wörter des Textes als
    /// Versal-Einstieg. Album: Überschrift in Handschrift. Klassisch:
    /// Georgia. Gemessen und gezeichnet wird DIESER Text — darum steckt der
    /// Stil hier und nicht erst im Zeichner.
    static func eintrag(_ e: Texteintrag, stil: Buchstil) -> NSAttributedString {
        let a = NSMutableAttributedString()
        let titel = e.titel.trimmingCharacters(in: .whitespacesAndNewlines)
        let titelgroesse: CGFloat = stil == .modern ? 21 : (stil == .album ? 18 : 15)
        if !titel.isEmpty {
            a.append(NSAttributedString(string: titel + "\n", attributes: [
                .font: schrift(stil.titelschrift, titelgroesse),
                .foregroundColor: UIColor.black,
                .paragraphStyle: absatz(.left, danach: 3, trennen: false),
            ]))
        }
        var datum = datumszeile(e.zeit)
        var datumsart: [NSAttributedString.Key: Any] = [
            .font: schrift(stil.kleinschrift, stil == .album ? 10 : 9),
            .foregroundColor: stil == .klassisch ? UIColor.darkGray : stil.akzent,
            .paragraphStyle: absatz(.left, danach: stil == .modern ? 12 : 9, trennen: false),
        ]
        if stil == .modern {
            datum = datum.uppercased()
            datumsart[.font] = schrift(stil.kleinschrift, 7.5)
            datumsart[.kern] = 1.4
        }
        a.append(NSAttributedString(string: datum + "\n", attributes: datumsart))

        let text = e.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return a }
        let grund: [NSAttributedString.Key: Any] = [
            .font: schrift(stil.grundschrift, 10.5),
            .foregroundColor: UIColor(white: 0.1, alpha: 1),
            .paragraphStyle: absatz(.justified, danach: 5),
        ]
        if stil == .modern {
            // Versal-Einstieg: die ersten drei Wörter.
            let woerter = text.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: false)
            if woerter.count > 3, !woerter[0...2].contains(where: { $0.contains("\n") }) {
                let einstieg = woerter[0...2].joined(separator: " ")
                var art = grund
                art[.font] = schrift("AvenirNext-DemiBold", 9)
                art[.kern] = 0.9
                art[.foregroundColor] = UIColor.black
                a.append(NSAttributedString(string: einstieg.uppercased() + " ", attributes: art))
                a.append(NSAttributedString(string: String(woerter[3]), attributes: grund))
                return a
            }
        }
        a.append(NSAttributedString(string: text, attributes: grund))
        return a
    }

    /// Text einer freien Seite. Eine Zeile, die mit „# " beginnt, wird
    /// als Überschrift gesetzt.
    static func frei(_ roh: String, stil: Buchstil) -> NSAttributedString {
        let a = NSMutableAttributedString()
        let zeilen = roh.components(separatedBy: "\n")
        for (n, zeile) in zeilen.enumerated() {
            let ende = n < zeilen.count - 1 ? "\n" : ""
            if zeile.hasPrefix("# ") {
                a.append(NSAttributedString(string: String(zeile.dropFirst(2)) + ende, attributes: [
                    .font: schrift(stil.titelschrift, stil == .modern ? 22 : 17),
                    .foregroundColor: UIColor.black,
                    .paragraphStyle: absatz(.left, danach: 6, trennen: false),
                ]))
            } else {
                a.append(NSAttributedString(string: zeile + ende, attributes: [
                    .font: schrift(stil.grundschrift, 11.5),
                    .foregroundColor: UIColor(white: 0.1, alpha: 1),
                    .paragraphStyle: absatz(.left, danach: 4),
                ]))
            }
        }
        return a
    }

    /// Zerlegt einen Text in Stücke: das erste für ein Feld der Größe
    /// `erste`, alle weiteren für `folge`. Ist das erste Feld zu klein für
    /// auch nur eine Zeile, bleibt sein Stück leer.
    static func aufteilen(_ text: NSAttributedString, erste: CGSize, folge: CGSize) -> [NSAttributedString] {
        guard text.length > 0 else { return [text] }
        let speicher = NSTextStorage(attributedString: text)
        let ordner = NSLayoutManager()
        speicher.addLayoutManager(ordner)
        var teile: [NSAttributedString] = []
        var groesse = erste
        var gesetzt = 0
        while teile.count < 400 {
            let behaelter = NSTextContainer(size: groesse)
            behaelter.lineFragmentPadding = 0
            ordner.addTextContainer(behaelter)
            let glyphen = ordner.glyphRange(for: behaelter)
            let zeichen = ordner.characterRange(forGlyphRange: glyphen, actualGlyphRange: nil)
            if zeichen.length == 0 {
                if teile.isEmpty, groesse != folge {
                    teile.append(NSAttributedString())
                    groesse = folge
                    continue
                }
                break
            }
            teile.append(ohneLeerzeilenVorn(text.attributedSubstring(from: zeichen)))
            gesetzt = NSMaxRange(zeichen)
            if gesetzt >= text.length { break }
            groesse = folge
        }
        // Sollte je etwas übrig bleiben (ein Wort breiter als die Seite),
        // wird es angehängt statt verschluckt.
        if gesetzt < text.length, gesetzt > 0 {
            let rest = text.attributedSubstring(from: NSRange(location: gesetzt, length: text.length - gesetzt))
            teile.append(rest)
        }
        return teile.isEmpty ? [text] : teile
    }

    private static func ohneLeerzeilenVorn(_ s: NSAttributedString) -> NSAttributedString {
        var anfang = 0
        let zeichen = s.string as NSString
        while anfang < zeichen.length, zeichen.character(at: anfang) == 10 { anfang += 1 }
        if anfang == 0 { return s }
        return s.attributedSubstring(from: NSRange(location: anfang, length: zeichen.length - anfang))
    }

    /// Zeichnet ein gemessenes Stück. Die Zugabe unten ist kein Platz für
    /// mehr Text — das Stück ist schon zugeschnitten —, sondern verhindert,
    /// dass Rundung die letzte Zeile abschneidet.
    static func zeichnen(_ s: NSAttributedString, in r: CGRect) {
        let feld = CGRect(x: r.minX, y: r.minY, width: r.width, height: r.height + 40)
        s.draw(with: feld, options: [.usesLineFragmentOrigin], context: nil)
    }

    /// Zeichnet und schneidet ab, was nicht passt (Felder freier Seiten).
    static func zeichnenBegrenzt(_ s: NSAttributedString, in r: CGRect) {
        s.draw(with: r, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], context: nil)
    }

    /// Passt der Text ganz in das Feld?
    static func passt(_ s: NSAttributedString, in groesse: CGSize) -> Bool {
        let noetig = s.boundingRect(with: CGSize(width: groesse.width, height: .greatestFiniteMagnitude),
                                    options: [.usesLineFragmentOrigin], context: nil)
        return noetig.height <= groesse.height + 0.5
    }
}
