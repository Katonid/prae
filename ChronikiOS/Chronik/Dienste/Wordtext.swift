import Foundation

// Den Text aus einer Word-Datei holen (`.docx`).
//
// Eine `.docx` ist ein ZIP mit `word/document.xml` darin; gelesen wird sie
// deshalb über `Zipleser` und dann über `XMLParser` — beides gehört zum
// System, eine fremde Bibliothek kommt nicht ins Haus.
//
// **`NSAttributedString` wäre der kurze Weg und kann es auf iOS nicht.**
// Sein `officeOpenXML`-Dokumenttyp gibt es nur auf dem Mac; der Weg über
// `.html` startet intern WebKit, muss auf den Hauptfaden und liest eine
// `.docx` ohnehin nicht. Also von Hand.
//
// Die alte `.doc` (das binäre Format vor 2007) wird NICHT gelesen. Sie ist
// kein ZIP, sondern ein zusammengesetztes Dokument von 1997, und sie zu
// lesen wäre ein eigenes Vorhaben. Wer eine hat, speichert sie in Word
// einmal als `.docx` — das sagt die Meldung auch.
enum Wordtext {
    enum Fehler: LocalizedError {
        case altesFormat
        case unlesbar

        var errorDescription: String? {
            switch self {
            case .altesFormat:
                return "Das ist eine alte .doc-Datei (Word bis 2003). Öffne sie in Word und sichere sie als .docx — dann liest die App sie."
            case .unlesbar:
                return "Die Word-Datei ließ sich nicht auseinandernehmen."
            }
        }
    }

    struct Ergebnis {
        var absaetze: [String]
        var text: String { absaetze.joined(separator: "\n") }
    }

    static func lesen(_ daten: Data) throws -> Ergebnis {
        // Ein zusammengesetztes Dokument von 1997 fängt mit dieser Kennung
        // an. Ohne diese Prüfung meldete der Zipleser „kein ZIP-Archiv" —
        // wörtlich richtig und für den Menschen davor wertlos.
        if daten.count >= 8, daten.prefix(8).elementsEqual([0xD0, 0xCF, 0x11, 0xE0,
                                                            0xA1, 0xB1, 0x1A, 0xE1]) {
            throw Fehler.altesFormat
        }
        let xml = try Zipleser.eintrag("word/document.xml", aus: daten)
        let leser = Leser()
        let parser = XMLParser(data: xml)
        parser.shouldProcessNamespaces = true
        parser.delegate = leser
        guard parser.parse() else { throw Fehler.unlesbar }
        return Ergebnis(absaetze: leser.fertig())
    }

    // MARK: - Der Leser

    private final class Leser: NSObject, XMLParserDelegate {
        // Nur Absätze aus DIESEM Namensraum zählen. „p" und „t" gibt es in
        // einer .docx auch in den Zeichnungsteilen (DrawingML); deren Text
        // gehört zu einem Schaubild und nicht in den Fließtext.
        private static let wort = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"

        private var zeilen: [String] = []
        private var puffer = ""
        private var imLauf = 0
        private var nimmtText = false

        func fertig() -> [String] {
            absatzSchliessen()
            return zeilen
        }

        private func absatzSchliessen() {
            let sauber = puffer.trimmingCharacters(in: .whitespaces)
            puffer = ""
            zeilen.append(sauber)
        }

        func parser(_ parser: XMLParser, didStartElement elementName: String,
                    namespaceURI: String?, qualifiedName qName: String?,
                    attributes: [String: String] = [:])
        {
            guard namespaceURI == Self.wort else { return }
            switch elementName {
            case "p":
                // Ein Absatz KANN in einem anderen stecken (Textfeld in
                // einem Lauf). Dann wird der angefangene erst geschlossen —
                // lieber eine Zeile zu viel als zwei Absätze ineinander.
                if !puffer.isEmpty { absatzSchliessen() }
            case "r":
                imLauf += 1
            case "t":
                // NUR `w:t`. `w:instrText` trägt Feldbefehle („HYPERLINK
                // \\l …"), `w:delText` gelöschten Text aus der
                // Nachverfolgung — beides stünde sonst im Tagebuch.
                if imLauf > 0 { nimmtText = true }
            case "br":
                // Ein weicher Zeilenumbruch. Er bleibt als Zeile stehen:
                // Genau das ist der hart umbrochene Text, den
                // `Textaufbereitung` hinterher wieder zusammenführt.
                if imLauf > 0 { absatzSchliessen() }
            case "tab":
                // `w:tab` gibt es zweimal — im Lauf als Tabulatorzeichen
                // und in den Absatzeigenschaften als Definition eines
                // Tabstopps. Nur das erste ist Text.
                if imLauf > 0 { puffer += " " }
            default:
                break
            }
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String,
                    namespaceURI: String?, qualifiedName qName: String?)
        {
            guard namespaceURI == Self.wort else { return }
            switch elementName {
            case "p": absatzSchliessen()
            case "r": imLauf = max(0, imLauf - 1)
            case "t": nimmtText = false
            default: break
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            guard nimmtText else { return }
            puffer += string
        }
    }
}
