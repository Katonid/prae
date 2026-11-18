import CoreText
import Foundation
import UIKit

// EINZELNE WÖRTER ANDERS SETZEN (KAPITELWEISE, ab 1.0.20).
//
// Ansage des Nutzers 11/2026: „Ich möchte in allen Bereichen die Möglichkeit
// haben, einzelne Wörter oder Abschnitte anders zu formatieren. Also
// Schriftgröße, Schriftart, fett oder unterstrichen eigenständig festlegen
// können."
//
// **Gespeichert wird weiter ein TEXT** — mit Marken darin:
//
//     [b]fett[/b]  [i]kursiv[/i]  [u]unterstrichen[/u]
//     [gr=14]größer[/gr]  [schrift=Hoefler+Text]andere Schrift[/schrift]
//
// Warum keine `AttributedString` im Modell: Jeder Weg dieser App rechnet mit
// Text — Einträge, Kapiteltext, Vorwort, Teilen an der Seitengrenze,
// Wiederfinden am Wortlaut (`restseiten`, `imVorwortfluss`), Buchdatei,
// iCloud. Ein zweites Format daneben hieße, jeden dieser Wege zu verdoppeln.
// Die Marken sind lesbar, falls sie irgendwo roh auftauchen, und überleben
// jede Kopie.
//
// Im Schriftnamen steht `+` für das Leerzeichen: Das Teilen an der
// Seitengrenze sucht rückwärts das letzte Leerzeichen, und das darf nie
// mitten in einer Marke liegen.
//
// Gesetzt wird an EINER Stelle (`gesetzt`), und die geht durch `Textmass` —
// also messen, teilen und zeichnen (Seite UND PDF) mit denselben Läufen.
// Ein Text mit Marken wird NICHT getrennt: Die Silbentrennung rechnet mit
// einer Schrift je Absatz; mit fetten oder größeren Wörtern darin stünden
// ihre Striche mitten in der Zeile.
enum Auszeichnung {
    /// Was an einer Stelle gilt — zusätzlich zur Schrift des Blocks.
    struct Format: Equatable {
        var fett = 0
        var kursiv = 0
        var unterstrichen = 0
        var groessen: [Double] = []
        var schriften: [String] = []

        var istLeer: Bool {
            fett == 0 && kursiv == 0 && unterstrichen == 0 && groessen.isEmpty && schriften.isEmpty
        }
    }

    struct Zerlegt {
        /// Der Text ohne Marken.
        var text: String
        /// Je Zeichen (UTF-16) das, was dort gilt.
        var formate: [Format]
        /// Je Zeichen (UTF-16) die Stelle im Urtext; ein Eintrag mehr für
        /// das Ende.
        var quelle: [Int]
        /// Was am Ende noch offen ist.
        var ende: Format
    }

    private static let muster = try! NSRegularExpression(
        pattern: "\\[(/?)(b|i|u|gr|schrift)(?:=([^\\[\\]\\n ]{1,80}))?\\]")

    /// Schnell: Trägt der Text überhaupt Marken?
    static func hat(_ text: String) -> Bool {
        guard text.contains("[") else { return false }
        return muster.firstMatch(in: text, range: NSRange(location: 0, length: (text as NSString).length)) != nil
    }

    static func zerlegen(_ urtext: String) -> Zerlegt {
        let ns = urtext as NSString
        let einheiten = Array(urtext.utf16)
        var text: [UInt16] = []
        var formate: [Format] = []
        var quelle: [Int] = []
        var jetzt = Format()
        var stelle = 0
        func kopiere(bis ende: Int) {
            while stelle < ende {
                text.append(einheiten[stelle])
                formate.append(jetzt)
                quelle.append(stelle)
                stelle += 1
            }
        }
        for treffer in muster.matches(in: urtext, range: NSRange(location: 0, length: ns.length)) {
            kopiere(bis: treffer.range.location)
            let zu = treffer.range(at: 1).length > 0
            let art = ns.substring(with: treffer.range(at: 2))
            let wert = treffer.range(at: 3).location == NSNotFound ? nil : ns.substring(with: treffer.range(at: 3))
            switch (art, zu) {
            case ("b", false): jetzt.fett += 1
            case ("b", true): jetzt.fett = max(0, jetzt.fett - 1)
            case ("i", false): jetzt.kursiv += 1
            case ("i", true): jetzt.kursiv = max(0, jetzt.kursiv - 1)
            case ("u", false): jetzt.unterstrichen += 1
            case ("u", true): jetzt.unterstrichen = max(0, jetzt.unterstrichen - 1)
            case ("gr", false):
                if let wert, let zahl = Double(wert.replacingOccurrences(of: ",", with: ".")), zahl >= 3, zahl <= 200 {
                    jetzt.groessen.append(zahl)
                } else {
                    jetzt.groessen.append(jetzt.groessen.last ?? 0)
                }
            case ("gr", true): if !jetzt.groessen.isEmpty { jetzt.groessen.removeLast() }
            case ("schrift", false):
                jetzt.schriften.append((wert ?? "").replacingOccurrences(of: "+", with: " "))
            case ("schrift", true): if !jetzt.schriften.isEmpty { jetzt.schriften.removeLast() }
            default: break
            }
            stelle = treffer.range.location + treffer.range.length
        }
        kopiere(bis: einheiten.count)
        quelle.append(einheiten.count)
        return Zerlegt(text: String(utf16: text), formate: formate, quelle: quelle, ende: jetzt)
    }

    /// Der Text ohne Marken — für Listen, Vorschauen und Vergleiche.
    static func ohne(_ text: String) -> String {
        hat(text) ? zerlegen(text).text : text
    }

    // MARK: - Setzen

    /// `massstab` (ab 1.0.25): Das Eingabefeld zeigt größer, als gedruckt
    /// wird; Größenmarken werden dann mit vergrößert.
    static func gesetzt(_ urtext: String, bild: Schriftbild, massstab: Double = 1) -> NSAttributedString {
        let zerlegt = zerlegen(urtext)
        let grund = bild.attribute()
        let sichtbar = bild.versalien ? zerlegt.text.uppercased() : zerlegt.text
        let ergebnis = NSMutableAttributedString(string: sichtbar, attributes: grund)
        // `uppercased` kann die Länge ändern (ß → SS); dann gelten die
        // Läufe nur bis zur kürzeren Länge — lieber ein Wort ohne Fett als
        // ein Absturz.
        let laenge = min(ergebnis.length, zerlegt.formate.count)
        var anfang = 0
        while anfang < laenge {
            let format = zerlegt.formate[anfang]
            var ende = anfang + 1
            while ende < laenge, zerlegt.formate[ende] == format { ende += 1 }
            if !format.istLeer {
                let bereich = NSRange(location: anfang, length: ende - anfang)
                ergebnis.addAttribute(.font, value: schrift(format, bild: bild, massstab: massstab), range: bereich)
                if format.unterstrichen > 0 {
                    ergebnis.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: bereich)
                }
                // Die feste Zeilenhöhe des Blocks gilt für die Grundschrift.
                // Ein größeres Wort braucht mehr — sonst ragte es in die
                // Zeile darüber.
                if let roh = format.groessen.last, case let g = roh * massstab, g > bild.groesse,
                   let absatz = (grund[.paragraphStyle] as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle
                {
                    let zeile = g * bild.zeilenabstand
                    absatz.minimumLineHeight = zeile
                    absatz.maximumLineHeight = zeile
                    ergebnis.addAttribute(.paragraphStyle, value: absatz,
                                          range: (sichtbar as NSString).paragraphRange(for: bereich))
                }
            }
            anfang = ende
        }
        return ergebnis
    }

    static func schrift(_ format: Format, bild: Schriftbild, massstab: Double = 1) -> UIFont {
        let familie = format.schriften.last.map { $0.isEmpty ? bild.familie : Schriftfamilie(familienname: $0) }
            ?? bild.familie
        let groesse = format.groessen.last.flatMap { $0 > 0 ? $0 * massstab : nil } ?? bild.groesse
        return familie.uiFont(groesse: groesse, fett: bild.fett || format.fett > 0,
                              kursiv: bild.kursiv || format.kursiv > 0)
    }

    // MARK: - Teilen an der Seitengrenze

    /// Liegt `stelle` (UTF-16) in einer Marke, die Stelle davor.
    static func ausserhalbMarke(_ einheiten: [UInt16], _ stelle: Int) -> Int {
        var i = min(stelle, einheiten.count)
        var j = i - 1
        while j >= 0 {
            if einheiten[j] == 93 { return i }          // ]
            if einheiten[j] == 91 { return j }          // [ — wir stehen in einer Marke
            if einheiten[j] == 10 || i - j > 90 { return i }
            j -= 1
        }
        i = max(0, i)
        return i
    }

    /// Ein geteilter Text darf keine offene Marke über die Grenze tragen: Der
    /// zweite Kasten wüsste nichts davon. Offenes wird im ersten geschlossen
    /// und im zweiten wieder geöffnet.
    static func ausgleichen(_ kopf: String, _ rest: String) -> (String, String) {
        guard hat(kopf) else { return (kopf, rest) }
        let offen = zerlegen(kopf).ende
        guard !offen.istLeer else { return (kopf, rest) }
        let auf = oeffnen(offen)
        let zu = schliessen(offen)
        return (kopf + zu, rest.isEmpty ? rest : auf + rest)
    }

    private static func oeffnen(_ f: Format) -> String {
        var s = ""
        for name in f.schriften { s += "[schrift=" + name.replacingOccurrences(of: " ", with: "+") + "]" }
        for g in f.groessen { s += "[gr=" + zahl(g) + "]" }
        s += String(repeating: "[b]", count: f.fett)
        s += String(repeating: "[i]", count: f.kursiv)
        s += String(repeating: "[u]", count: f.unterstrichen)
        return s
    }

    private static func schliessen(_ f: Format) -> String {
        var s = String(repeating: "[/u]", count: f.unterstrichen)
        s += String(repeating: "[/i]", count: f.kursiv)
        s += String(repeating: "[/b]", count: f.fett)
        s += String(repeating: "[/gr]", count: f.groessen.count)
        s += String(repeating: "[/schrift]", count: f.schriften.count)
        return s
    }

    private static func zahl(_ g: Double) -> String {
        g == g.rounded() ? String(Int(g)) : String(format: "%.1f", g)
    }

    // MARK: - Aus dem Textfeld zurück in Marken

    /// Was im Textfeld anders aussieht als die Schrift des Blocks, wird zu
    /// Marken. Verglichen wird mit der Grundschrift: Was ihr gleicht, bleibt
    /// unmarkiert — sonst trüge jeder Text nach dem ersten Öffnen Marken.
    static func auszeichnen(_ text: NSAttributedString, bild: Schriftbild, massstab: Double = 1) -> String {
        let grund = bild.uiFont
        let grundFett = bild.fett
        let grundKursiv = bild.kursiv
        var ergebnis = ""
        let ns = text.string as NSString
        text.enumerateAttributes(in: NSRange(location: 0, length: text.length)) { werte, bereich, _ in
            let stueck = ns.substring(with: bereich)
            var f = Format()
            if let schrift = werte[.font] as? UIFont {
                let merkmale = schrift.fontDescriptor.symbolicTraits
                if merkmale.contains(.traitBold) && !grundFett { f.fett = 1 }
                if merkmale.contains(.traitItalic) && !grundKursiv { f.kursiv = 1 }
                if abs(Double(schrift.pointSize) - bild.groesse) > 0.25 * massstab {
                    f.groessen = [(Double(schrift.pointSize) / massstab * 2).rounded() / 2]
                }
                if schrift.familyName != grund.familyName {
                    f.schriften = [schrift.familyName]
                }
            }
            if let linie = werte[.underlineStyle] as? Int, linie != 0 { f.unterstrichen = 1 }
            if f.istLeer {
                ergebnis += stueck
            } else {
                // Zeilenwechsel gehören nicht in eine Marke: Ein Absatz, der
                // mit `[b]` beginnt und im nächsten endet, wäre beim Teilen
                // an der Absatzgrenze die schwierigste Stelle.
                let teile = stueck.components(separatedBy: "\n")
                for (n, teil) in teile.enumerated() {
                    if n > 0 { ergebnis += "\n" }
                    if !teil.isEmpty { ergebnis += oeffnen(f) + teil + schliessen(f) }
                }
            }
        }
        return zusammenziehen(ergebnis)
    }

    /// `[/b][b]` zwischen zwei gleich formatierten Läufen fällt weg.
    private static func zusammenziehen(_ s: String) -> String {
        var t = s
        for art in ["u", "i", "b", "gr", "schrift"] {
            t = t.replacingOccurrences(of: "[/\(art)][\(art)]", with: "")
        }
        return t
    }
}
