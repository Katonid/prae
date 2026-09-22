import CoreText
import Foundation
import UIKit

// SILBENTRENNUNG — mit Apples Wörterbuch, aber von Hand eingesetzt
// (ab 1.0.40).
//
// Gemeldet 09/2026, mit Bildschirmfoto: „Trotz aktivierter Silbentrennung
// sieht es dann so aus" — Blocksatz mit handbreiten Lücken zwischen den
// Wörtern und keinem einzigen Trennstrich.
//
// DIE URSACHE IST AM QUELLTEXT ABZUZÄHLEN und keine Vermutung:
// `Schriftbild.attribute` setzt `NSMutableParagraphStyle.hyphenationFactor`,
// und gesetzt wird mit CoreText (`CTFramesetterCreateWithAttributedString`,
// `CTFrameDraw`). **`hyphenationFactor` ist eine Sache von TextKit, nicht
// von CoreText.** Reicht man CoreText eine `NSAttributedString` mit einem
// `NSParagraphStyle`, übersetzt es den in einen `CTParagraphStyle` — und
// dessen Aufzählung `CTParagraphStyleSpecifier` kennt Ausrichtung,
// Einzüge, Zeilenhöhen, Absatzabstände und den Zeilenumbruchmodus. Eine
// Silbentrennung steht nicht darin, also fällt das Feld beim Übersetzen
// weg.
//
// Damit hat der Schalter „Silben trennen" seit 1.0.0 NICHTS getan — weder
// auf dem Bildschirm noch im PDF, denn beide gehen durch dieselbe
// Funktion (`Seitensatz.zeichneText`). Und schlimmer als die fehlende
// Wirkung war die Auskunft: `TypografieView` zeigte „Blocksatz ohne
// Silbentrennung reißt Löcher in die Zeilen" nur, SOLANGE der Schalter aus
// war. Wer ihn umlegte, sah die Warnung verschwinden und die Löcher
// bleiben — die App behauptete das Gegenteil dessen, was sie tat.
//
// **Merke: Ein Attribut, das im Modell steht, ist noch nicht gesetzt.**
// TextKit und CoreText nehmen dieselbe `NSAttributedString` entgegen und
// werten NICHT dieselben Schlüssel aus. Genau deshalb fiel es nie auf: Im
// Textfeld beim Bearbeiten (`TextflaecheBruecke`, ein `UITextView`, also
// TextKit) wirkte die Einstellung sehr wohl.
//
// GETRENNT WIRD WEITERHIN NICHT VON UNS. Die Stellen kommen aus
// `CFStringGetHyphenationLocationBeforeIndex`, also aus demselben
// deutschen Wörterbuch des Systems, das auch TextKit benutzt hätte. Die
// Regel dieses Repos — „eine selbst gebaute Trennung ist verboten, die
// deutsche ist nicht ableitbar, und eine falsche stünde für immer im
// gedruckten Buch" — bleibt damit unangetastet. Neu ist nur, dass wir das
// Wörterbuch selbst fragen und den Strich selbst setzen.
enum Silbentrennung {
    /// Der Strich, der ins Buch kommt. U+002D und nicht U+2010: Das
    /// Viertelgeviert gibt es nicht in jeder Schrift, und eine fehlende
    /// Glyphe wäre ein Kästchen mitten im Wort.
    static let strich: Character = "-"
    private static let stricheinheit: UInt16 = 0x2D

    /// Mindestens zwei Zeichen vor dem Strich und drei danach. Das ist
    /// Handwerk des Satzes und keine Entscheidung über die Sprache: Ein
    /// einzelner Buchstabe am Zeilenende liest sich wie ein Druckfehler.
    /// **Gewählt und nicht gemessen.**
    private static let mindestensDavor = 2
    private static let mindestensDanach = 3
    private static var mindestwortlaenge: Int { mindestensDavor + mindestensDanach }

    /// Höchstens drei getrennte Zeilen hintereinander („Trennungsleiter").
    /// Ebenfalls Handwerk und ebenfalls **gewählt und nicht gemessen**.
    private static let hoechstensHintereinander = 3

    // MARK: - Was das Gerät hergibt

    // Gebaut wird der Behälter mit CoreFoundation und nicht über eine
    // Brücke von `Locale`: `CFStringGetHyphenationLocationBeforeIndex` will
    // ein `CFLocale`, und eine Überbrückung, die vielleicht geht, ist an
    // dieser Stelle eine Zeile, die vielleicht übersetzt.
    static let woerterbuch: CFLocale = CFLocaleCreate(kCFAllocatorDefault, "de_DE" as CFString)

    /// Ob dieses Gerät überhaupt ein deutsches Trennwörterbuch hat.
    ///
    /// Gefragt wird, statt es anzunehmen: Fehlt es, trennt die App nichts,
    /// und dann muss die Oberfläche das SAGEN — ein Schalter, der nichts
    /// tut, ist genau der Fehler, der diese Fassung ausgelöst hat.
    static let verfuegbar: Bool = CFStringIsHyphenationAvailableForLocale(woerterbuch)

    // MARK: - Ergebnis

    struct Ergebnis {
        /// Der Text, wie er gesetzt wird — mit den eingefügten Strichen.
        var text: String
        /// Aufsteigend, UTF-16-Stellen IM GESETZTEN Text, an denen ein
        /// Strich steht.
        var stellen: [Int]

        /// Rechnet eine Stelle im gesetzten Text auf den URTEXT zurück.
        ///
        /// Gebraucht wird das an genau einer Stelle und dort zwingend:
        /// `Textmass.passtBis` sagt, wie viel Text auf eine Seite passt,
        /// und `teilen` schneidet danach den TAGEBUCHTEXT. Käme dort eine
        /// Länge aus dem gesetzten Text zurück, wanderten die eingefügten
        /// Striche über `Neuverteilung.fliesstexte` in `tag.text` —
        /// mitten in die Wörter, und zwar dauerhaft.
        func imUrtext(_ stelle: Int) -> Int {
            guard !stellen.isEmpty else { return stelle }
            var davor = 0
            for s in stellen {
                if s < stelle { davor += 1 } else { break }
            }
            return stelle - davor
        }
    }

    // MARK: - Der Weg

    static func getrennt(_ text: String, bild: Schriftbild, breite: Double) -> Ergebnis {
        // `versalien` bleibt AUSSEN VOR, und das ist Absicht:
        // `Schriftbild.gesetzt` schreibt den Text dann groß, und
        // `uppercased()` kann die Länge ändern (aus „ß" wird „SS"). Die
        // Rückrechnung auf den Urtext ginge damit um ein Zeichen daneben,
        // und ein Tagebuchtext verlöre beim nächsten Neuverteilen einen
        // Buchstaben. Versalien stehen ohnehin in Überschriften, und die
        // sind kurz.
        guard bild.trennung, !bild.versalien, verfuegbar,
              breite > 1, text.utf16.count > mindestwortlaenge
        else {
            return Ergebnis(text: text, stellen: [])
        }
        let schluessel = Speicher.Schluessel(text: text, bild: bild, breite: breite)
        if let fertig = speicher.hole(schluessel) { return fertig }
        let ergebnis = rechne(text, bild: bild, breite: breite)
        speicher.lege(ergebnis, unter: schluessel)
        return ergebnis
    }

    private static func rechne(_ text: String, bild: Schriftbild, breite: Double) -> Ergebnis {
        let attribute = bild.attribute()
        let strichbreite = breiteDesStrichs(attribute)
        var gesetzt: [UInt16] = []
        var stellen: [Int] = []
        for absatz in absaetze(Array(text.utf16)) {
            let (teil, punkte) = getrennterAbsatz(absatz.inhalt, attribute: attribute,
                                                  breite: breite, strichbreite: strichbreite)
            for p in punkte { stellen.append(gesetzt.count + p) }
            gesetzt.append(contentsOf: teil)
            gesetzt.append(contentsOf: absatz.schluss)
        }
        return Ergebnis(text: String(utf16: gesetzt), stellen: stellen)
    }

    // MARK: - Ein Absatz

    // EIN Setzer für den ganzen Absatz, nicht einer je Trennstelle.
    //
    // Das ist der Grund, warum die Rechnung bezahlbar bleibt: Ein
    // eingefügter Strich gehört zur ABLAUFENDEN Zeile; die nächste beginnt
    // an einer Stelle, die es im Urtext gibt. `CTTypesetterSuggestLineBreak`
    // lässt sich also weiter mit demselben Setzer fragen, und die Striche
    // werden erst ganz am Ende in den Text geschrieben. Ein Setzer je
    // Trennstelle wäre der naheliegende Weg und quadratisch — bei einem
    // Tagesplan, der zwölf Spaltenbreiten durchprobiert (`Mosaik`), ist das
    // der Unterschied zwischen Millisekunden und Sekunden.
    private static func getrennterAbsatz(_ roh: [UInt16],
                                         attribute: [NSAttributedString.Key: Any],
                                         breite: Double,
                                         strichbreite: Double) -> ([UInt16], [Int])
    {
        let laenge = roh.count
        guard laenge > mindestwortlaenge else { return (roh, []) }
        let text = String(utf16: roh)
        let setzer = CTTypesetterCreateWithAttributedString(
            NSAttributedString(string: text, attributes: attribute) as CFAttributedString
        )
        let cf = text as CFString

        var trennstellen: [Int] = []
        var start = 0
        var hintereinander = 0
        // Eine Notbremse, wie überall in dieser App: Eine Schleife, die auf
        // ein Maß wartet, das nicht kleiner wird, darf kein Buch aufhalten.
        var wache = 0
        while start < laenge, wache < 5000 {
            wache += 1
            let anzahl = CTTypesetterSuggestLineBreak(setzer, start, breite)
            guard anzahl > 0 else { break }
            let ende = start + anzahl
            guard ende < laenge else { break }
            if hintereinander < hoechstensHintereinander,
               let p = trennstelle(cf, roh: roh, hinter: ende, laenge: laenge,
                                   zeilenanfang: start, setzer: setzer, attribute: attribute,
                                   breite: breite, strichbreite: strichbreite)
            {
                trennstellen.append(p)
                hintereinander += 1
                start = p
            } else {
                hintereinander = 0
                start = ende
            }
        }

        guard !trennstellen.isEmpty else { return (roh, []) }
        var gesetzt: [UInt16] = []
        var punkte: [Int] = []
        var gelesen = 0
        for p in trennstellen {
            gesetzt.append(contentsOf: roh[gelesen..<p])
            punkte.append(gesetzt.count)
            gesetzt.append(stricheinheit)
            gelesen = p
        }
        gesetzt.append(contentsOf: roh[gelesen...])
        return (gesetzt, punkte)
    }

    // Die Stelle im Wort, das gerade in die nächste Zeile gerutscht ist.
    //
    // Gefragt wird von HINTEN: Gesucht ist die späteste Trennung, die noch
    // in die Zeile passt — eine frühere ließe mehr Loch stehen, als nötig
    // ist. Passt sie nicht, fragen wir vor dieser Stelle noch einmal.
    private static func trennstelle(_ cf: CFString, roh: [UInt16], hinter ende: Int,
                                    laenge: Int, zeilenanfang: Int, setzer: CTTypesetter,
                                    attribute: [NSAttributedString.Key: Any],
                                    breite: Double, strichbreite: Double) -> Int?
    {
        var wortStart = ende
        while wortStart < laenge, istLeerraum(roh[wortStart]) { wortStart += 1 }
        guard wortStart < laenge else { return nil }
        var wortEnde = wortStart
        while wortEnde < laenge, !istLeerraum(roh[wortEnde]) { wortEnde += 1 }
        guard wortEnde - wortStart >= mindestwortlaenge else { return nil }

        let bereich = CFRange(location: wortStart, length: wortEnde - wortStart)
        var vor = wortEnde
        var runden = 0
        while runden < 16 {
            runden += 1
            var vorschlag: UTF32Char = 0
            let p = CFStringGetHyphenationLocationBeforeIndex(
                cf, vor, bereich, 0, woerterbuch, &vorschlag
            )
            guard p != kCFNotFound, p > wortStart, p < wortEnde else { return nil }
            vor = p
            // Zu wenig vor dem Strich: Jede weitere Frage gäbe eine noch
            // frühere Stelle, also ist hier Schluss.
            guard p - wortStart >= mindestensDavor else { return nil }
            guard wortEnde - p >= mindestensDanach else { continue }
            // Das Wörterbuch sagt auch, WELCHES Zeichen an die Stelle
            // gehört. Für Deutsch ist das seit 1996 immer ein gewöhnlicher
            // Trennstrich; schlägt es etwas anderes vor, könnte sich die
            // Schreibung ändern (die alte „Zuk-ker"-Regel), und das wäre
            // eine Entscheidung über den Text, die uns nicht zusteht.
            guard strichtauglich(vorschlag) else { continue }
            // Erst grob, dann genau — und die genaue Messung nur noch für
            // den einen Kandidaten, der die grobe überstanden hat. Die
            // grobe kostet nichts Zusätzliches: Sie benutzt den Setzer, der
            // für diesen Absatz ohnehin schon steht.
            guard passtGrob(setzer, von: zeilenanfang, bis: p,
                            breite: breite, strichbreite: strichbreite)
            else { continue }
            if passtGenau(roh, von: zeilenanfang, bis: p,
                          attribute: attribute, breite: breite)
            {
                return p
            }
        }
        return nil
    }

    private static func passtGrob(_ setzer: CTTypesetter, von: Int, bis: Int,
                                  breite: Double, strichbreite: Double) -> Bool
    {
        guard bis > von else { return false }
        let linie = CTTypesetterCreateLine(setzer, CFRange(location: von, length: bis - von))
        return CTLineGetTypographicBounds(linie, nil, nil, nil) + strichbreite <= breite
    }

    // GEMESSEN WIRD DIE ZEILE MIT DEM STRICH, nicht die Zeile plus die
    // Breite eines einzelnen Strichs.
    //
    // Der Unterschied ist klein und entscheidet trotzdem: Zwischen dem
    // letzten Buchstaben und dem Strich steht eine Unterschneidung, die es
    // bei einem allein gemessenen Strich nicht gibt. Rechneten wir zu
    // knapp, passte die Zeile beim Setzen NICHT mehr — und dann bricht
    // CoreText an der Lücke davor um, und der Strich stünde am ANFANG der
    // nächsten Zeile mitten im Wort. Ein solcher Fehler stünde für immer im
    // gedruckten Buch, und er kostet hier nur ein paar Zeichenketten mehr.
    private static func passtGenau(_ roh: [UInt16], von: Int, bis: Int,
                                   attribute: [NSAttributedString.Key: Any],
                                   breite: Double) -> Bool
    {
        guard bis > von else { return false }
        let zeile = String(utf16: Array(roh[von..<bis])) + String(strich)
        let linie = CTLineCreateWithAttributedString(
            NSAttributedString(string: zeile, attributes: attribute) as CFAttributedString
        )
        return CTLineGetTypographicBounds(linie, nil, nil, nil) <= breite
    }

    private static func breiteDesStrichs(_ attribute: [NSAttributedString.Key: Any]) -> Double {
        let linie = CTLineCreateWithAttributedString(
            NSAttributedString(string: String(strich), attributes: attribute) as CFAttributedString
        )
        return CTLineGetTypographicBounds(linie, nil, nil, nil)
    }

    private static func strichtauglich(_ zeichen: UTF32Char) -> Bool {
        // 0 heißt: das Wörterbuch hat nichts Besonderes zu melden.
        zeichen == 0 || zeichen == 0x00AD || zeichen == 0x2010 || zeichen == 0x002D
    }

    private static func istLeerraum(_ einheit: UInt16) -> Bool {
        einheit == 0x20 || einheit == 0x09
    }

    // MARK: - Absätze

    // Getrennt wird je Absatz, denn CoreText setzt je Absatz. Mitgelesen
    // werden U+2028 und U+2029 — die stehen in Texten aus Word und aus
    // PDFs und wären sonst unsichtbar (dieselbe Liste wie in
    // `Textmass.absatzgrenze`).
    private static func absaetze(_ roh: [UInt16]) -> [(inhalt: [UInt16], schluss: [UInt16])] {
        var teile: [(inhalt: [UInt16], schluss: [UInt16])] = []
        var anfang = 0
        var i = 0
        while i < roh.count {
            let einheit = roh[i]
            if einheit == 0x0A || einheit == 0x0D || einheit == 0x2028 || einheit == 0x2029 {
                var schlussEnde = i + 1
                // „\r\n" ist EIN Absatzende und nicht zwei.
                if einheit == 0x0D, schlussEnde < roh.count, roh[schlussEnde] == 0x0A {
                    schlussEnde += 1
                }
                teile.append((Array(roh[anfang..<i]), Array(roh[i..<schlussEnde])))
                anfang = schlussEnde
                i = schlussEnde
            } else {
                i += 1
            }
        }
        if anfang < roh.count { teile.append((Array(roh[anfang...]), [])) }
        return teile
    }

    // MARK: - Zwischenspeicher

    private static let speicher = Speicher()

    // Ohne ihn liefe die ganze Rechnung bei JEDER Messung noch einmal, und
    // `Mosaik.mischreihe` misst denselben Text in zwölf Breiten — mal die
    // Anläufe der Bildzahl, mal die Seiten des Tages. Gesperrt wird, weil
    // `Buchausgabe` nicht auf dem Hauptfaden laufen muss.
    private final class Speicher {
        struct Schluessel: Hashable {
            let text: String
            let bild: Schriftbild
            let breite: Double
        }

        private let sperre = NSLock()
        private var eintraege: [Schluessel: Ergebnis] = [:]
        private var folge: [Schluessel] = []
        private let hoechstzahl = 96

        func hole(_ schluessel: Schluessel) -> Ergebnis? {
            sperre.lock()
            defer { sperre.unlock() }
            return eintraege[schluessel]
        }

        func lege(_ ergebnis: Ergebnis, unter schluessel: Schluessel) {
            sperre.lock()
            defer { sperre.unlock() }
            if eintraege[schluessel] == nil { folge.append(schluessel) }
            eintraege[schluessel] = ergebnis
            while folge.count > hoechstzahl {
                eintraege.removeValue(forKey: folge.removeFirst())
            }
        }
    }
}
