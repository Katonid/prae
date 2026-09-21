import Foundation
import UIKit
import UniformTypeIdentifiers

// Eine Datei hereinholen — gleich welcher Art — und reinen Text daraus
// machen.
//
// Der Wunsch (09/2026): „Ich möchte Texte im Word-Format, PDF oder reinen
// Text eingeben können." Bis 1.0.12 nahm der Textimport nur eine
// Textdatei entgegen; wer sein Tagebuch in Word geschrieben hatte, musste
// es erst irgendwo hindurch kopieren.
//
// Alles, was eine Datei in Text verwandelt, steht an DIESER Stelle. Der
// Bildschirm ruft eine Funktion und bekommt einen Befund; er weiß nicht,
// ob dahinter PDFKit, ein ZIP-Leser oder eine Kodierungsleiter steckt.
enum Textquelle {
    enum Art {
        case text, rtf, word, pdf

        var name: String {
            switch self {
            case .text: return "Textdatei"
            case .rtf: return "RTF-Datei"
            case .word: return "Word-Datei"
            case .pdf: return "PDF"
            }
        }
    }

    enum Fehler: LocalizedError {
        case leer
        case unbekanntesArchiv
        case kodierung
        case rtfUnlesbar

        var errorDescription: String? {
            switch self {
            case .leer:
                return "Die Datei ist leer angekommen. Liegt sie in iCloud, öffne sie einmal in der Dateien-App, damit sie wirklich auf dem Gerät ist."
            case .unbekanntesArchiv:
                return "Das ist ein Archiv, aber keine Word-Datei — vielleicht Pages oder OpenDocument. Exportiere es als .docx, als PDF oder als reinen Text."
            case .kodierung:
                return "Die Textkodierung der Datei ließ sich nicht bestimmen."
            case .rtfUnlesbar:
                return "Die RTF-Datei ließ sich nicht lesen."
            }
        }
    }

    struct Befund {
        var text: String
        var art: Art
        var dateiname: String
        var seiten: Int?
        var absaetze: Int?
        var entfernt: [String] = []
        var kodierung: String? = nil

        // Was angekommen ist, in einem Satz. Der Einfuhrbericht dieser App
        // sagt immer, was sie bekommen hat — ein stummer Import ließe die
        // Frage offen, ob die richtige Datei gewählt wurde.
        var beschreibung: String {
            var teile = ["\(art.name) „\(dateiname)\u{201C}"]
            if let seiten { teile.append("\(seiten) \(seiten == 1 ? "Seite" : "Seiten")") }
            if let absaetze { teile.append("\(absaetze) Absätze") }
            if let kodierung { teile.append(kodierung) }
            let zeichen = text.count
            teile.append("\(zeichen) Zeichen")
            return teile.joined(separator: " · ")
        }
    }

    // Was der Dateiwähler annehmen soll. `UTType.text` deckt jede Datei
    // ab, die sich als Text ausgibt; die drei anderen stehen einzeln da,
    // weil keine davon Text IST.
    static var typen: [UTType] {
        var liste: [UTType] = [.plainText, .utf8PlainText, .text, .rtf, .pdf]
        // Das Wort-Format über seine Kennung nachschlagen und nicht
        // hineinschreiben: Steht es fest im Quelltext und ändert Apple die
        // Zuordnung, wählt der Wähler eine Datei aus, die es nicht gibt.
        if let word = UTType(filenameExtension: "docx") { liste.append(word) }
        if let alt = UTType(filenameExtension: "doc") { liste.append(alt) }
        return liste
    }

    static func lesen(_ adresse: URL) throws -> Befund {
        let offen = adresse.startAccessingSecurityScopedResource()
        defer { if offen { adresse.stopAccessingSecurityScopedResource() } }
        let daten = try Data(contentsOf: adresse)
        guard !daten.isEmpty else { throw Fehler.leer }
        return try lesen(daten, name: adresse.lastPathComponent)
    }

    // Entschieden wird an den ERSTEN BYTES, nicht an der Endung.
    //
    // Dieselbe Lehre wie in Textauszug, wo sechs Kilobyte HTML mit `.pdf`
    // im Namen ankamen: Eine Endung ist eine Behauptung, die ersten Bytes
    // sind eine Tatsache. Die Endung entscheidet nur da, wo die Bytes
    // nichts sagen — bei reinem Text.
    static func lesen(_ daten: Data, name: String) throws -> Befund {
        if beginntMit(daten, "%PDF-") || daten.prefix(1024).range(of: Data("%PDF-".utf8)) != nil {
            let ergebnis = try Pdftext.lesen(daten)
            return Befund(text: ergebnis.text, art: .pdf, dateiname: name,
                          seiten: ergebnis.seiten, absaetze: nil,
                          entfernt: ergebnis.entfernt)
        }
        if beginntMit(daten, "PK") {
            do {
                let ergebnis = try Wordtext.lesen(daten)
                return Befund(text: ergebnis.text, art: .word, dateiname: name,
                              seiten: nil, absaetze: ergebnis.absaetze.count)
            } catch let zip as Zipleser.Fehler {
                // Ein ZIP ohne `word/document.xml` ist irgendein anderes
                // Archiv — Pages, OpenDocument, ein Ordner. Der Rohtext
                // des Zipleser wäre hier eine Auskunft über sein Inneres
                // und keine über die Datei.
                if case .eintragFehlt = zip { throw Fehler.unbekanntesArchiv }
                throw zip
            }
        }
        if beginntMit(daten, "{\\rtf") {
            return try rtf(daten, name: name)
        }
        // Die alte `.doc` fängt mit derselben Kennung an wie jedes
        // zusammengesetzte Dokument von 1997; `Wordtext` sagt dazu den
        // einen Satz, der weiterhilft.
        if daten.count >= 8,
           daten.prefix(8).elementsEqual([0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1])
        {
            throw Wordtext.Fehler.altesFormat
        }
        return try reinerText(daten, name: name)
    }

    // MARK: - Die einzelnen Wege

    private static func rtf(_ daten: Data, name: String) throws -> Befund {
        // RTF kann `NSAttributedString` auf iOS wirklich — anders als
        // `.docx`, das dort nur der Mac beherrscht. Und anders als beim
        // HTML-Weg startet dafür kein WebKit.
        guard let reich = try? NSAttributedString(
            data: daten,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        ) else { throw Fehler.rtfUnlesbar }
        return Befund(text: reich.string, art: .rtf, dateiname: name,
                      seiten: nil, absaetze: nil)
    }

    private static func reinerText(_ daten: Data, name: String) throws -> Befund {
        // **Die Reihenfolge ist der ganze Punkt.** `isoLatin1` nimmt JEDES
        // Byte an und scheitert nie — steht es vor `windowsCP1252`, wird
        // Letzteres nie erreicht, und die Bytes 0x80 bis 0x9F einer
        // Windows-Datei (also „ \u{201C} – …) werden zu unsichtbaren
        // Steuerzeichen. Bis 1.0.12 stand es genau so herum da.
        if let inhalt = mitVorzeichen(daten) {
            return Befund(text: inhalt.text, art: .text, dateiname: name,
                          seiten: nil, absaetze: nil, kodierung: inhalt.name)
        }
        if let inhalt = String(data: daten, encoding: .utf8) {
            return Befund(text: inhalt, art: .text, dateiname: name,
                          seiten: nil, absaetze: nil, kodierung: "UTF-8")
        }
        if let inhalt = String(data: daten, encoding: .windowsCP1252) {
            return Befund(text: inhalt, art: .text, dateiname: name,
                          seiten: nil, absaetze: nil, kodierung: "Windows-1252")
        }
        if let inhalt = String(data: daten, encoding: .isoLatin1) {
            return Befund(text: inhalt, art: .text, dateiname: name,
                          seiten: nil, absaetze: nil, kodierung: "ISO 8859-1")
        }
        throw Fehler.kodierung
    }

    // Ein Byte-Vorzeichen am Anfang sagt die Kodierung SELBST. Ohne diese
    // Prüfung käme eine UTF-16-Datei aus Windows als Buchstabensalat mit
    // Nullbytes dazwischen an — und zwar ohne Fehlermeldung, denn
    // `isoLatin1` nimmt auch die.
    private static func mitVorzeichen(_ daten: Data) -> (text: String, name: String)? {
        let kopf = [UInt8](daten.prefix(3))
        if kopf.count >= 3, kopf[0] == 0xEF, kopf[1] == 0xBB, kopf[2] == 0xBF {
            let rest = daten.dropFirst(3)
            if let text = String(data: rest, encoding: .utf8) { return (text, "UTF-8") }
        }
        if kopf.count >= 2, kopf[0] == 0xFF, kopf[1] == 0xFE {
            if let text = String(data: daten, encoding: .utf16LittleEndian) {
                return (String(text.dropFirst()), "UTF-16")
            }
        }
        if kopf.count >= 2, kopf[0] == 0xFE, kopf[1] == 0xFF {
            if let text = String(data: daten, encoding: .utf16BigEndian) {
                return (String(text.dropFirst()), "UTF-16")
            }
        }
        return nil
    }

    private static func beginntMit(_ daten: Data, _ kennung: String) -> Bool {
        let bytes = Array(kennung.utf8)
        guard daten.count >= bytes.count else { return false }
        return daten.prefix(bytes.count).elementsEqual(bytes)
    }
}
