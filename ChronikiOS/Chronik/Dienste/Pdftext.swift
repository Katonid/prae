import Foundation
import PDFKit

// Den Text aus einer PDF holen.
//
// Gelesen wird mit PDFKit — anders als in der Web-App Textauszug, die
// ihren PDF-Leser selbst schreiben MUSS, weil im Browser keiner
// mitgeliefert wird. Auf iOS gehört einer zum System; ihn nachzubauen
// wäre dieselbe Arbeit noch einmal und eine zweite Fehlerquelle dazu.
//
// **Was PDFKit nicht hergibt, ist die LAGE der Zeilen.** Textauszug
// erkennt Kopf- und Fußzeilen am Abstand zum Satzspiegel; hier steht nur
// der Text je Seite zur Verfügung. Erkannt wird deshalb die WIEDERHOLUNG:
// Eine Zeile, die auf den meisten Seiten an derselben Stelle steht — ganz
// oben oder ganz unten — und sich nur in ihren Ziffern unterscheidet, ist
// eine Kopf- oder Fußzeile. Das ist ein anderes Merkmal als dort, und es
// wird auch anders falsch: Ein Buch mit einem wiederkehrenden Refrain als
// erster Zeile verlöre ihn. Deshalb steht hinterher da, WAS entfernt
// wurde — und zwar wörtlich.
enum Pdftext {
    enum Fehler: LocalizedError {
        case keinPdf
        case verschluesselt
        case keinText(seiten: Int)

        var errorDescription: String? {
            switch self {
            case .keinPdf:
                return "Die Datei ließ sich nicht als PDF öffnen."
            case .verschluesselt:
                return "Die PDF ist mit einem Kennwort geschützt. Öffne sie einmal mit dem Kennwort und sichere sie ohne — dann liest die App sie."
            case let .keinText(seiten):
                return "In dieser PDF steht auf \(seiten) Seiten kein Text, sondern ein Bild davon (ein Scan). Eine Texterkennung hat die App nicht."
            }
        }
    }

    struct Ergebnis {
        var text: String
        var seiten: Int
        // Wörtlich, wie sie dastanden — eine Auskunft und keine Zahl:
        // „Seite 12 von 30" sagt einem Menschen sofort, ob das Entfernen
        // richtig war, „2 Zeilen entfernt" nicht.
        var entfernt: [String]
    }

    static func lesen(_ daten: Data) throws -> Ergebnis {
        guard let papier = PDFDocument(data: daten) else { throw Fehler.keinPdf }
        if papier.isLocked { throw Fehler.verschluesselt }
        let anzahl = papier.pageCount
        guard anzahl > 0 else { throw Fehler.keinPdf }

        var seiten: [[String]] = []
        for nummer in 0 ..< anzahl {
            let roh = papier.page(at: nummer)?.string ?? ""
            seiten.append(zeilen(roh))
        }

        let zeichen = seiten.flatMap { $0 }.joined().filter { !$0.isWhitespace }.count
        // Ein Scan bringt je Seite höchstens ein paar versprengte Zeichen
        // mit (eine Seitenzahl aus einer Textebene). Zwanzig je Seite ist
        // die Grenze, unter der ein Text keiner mehr ist.
        guard zeichen >= anzahl * 20 else { throw Fehler.keinText(seiten: anzahl) }

        let raender = wiederkehrend(seiten)
        var gesaeubert: [String] = []
        for var seite in seiten {
            if let erste = seite.first, raender.contains(marke(erste)) { seite.removeFirst() }
            if let letzte = seite.last, raender.contains(marke(letzte)) { seite.removeLast() }
            gesaeubert.append(contentsOf: seite)
        }

        // Was entfernt wurde, wird als BEISPIEL gezeigt — die Zeile, wie
        // sie auf der ersten betroffenen Seite stand.
        var beispiele: [String] = []
        for seite in seiten {
            for kante in [seite.first, seite.last] {
                guard let kante, raender.contains(marke(kante)),
                      !beispiele.contains(kante) else { continue }
                beispiele.append(kante)
            }
        }

        return Ergebnis(text: gesaeubert.joined(separator: "\n"),
                        seiten: anzahl,
                        entfernt: beispiele)
    }

    // MARK: - Zeilen und Kanten

    private static func zeilen(_ roh: String) -> [String] {
        roh.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            // Das weiche Trennzeichen ist im PDF unsichtbar und stünde im
            // Tagebuch mitten im Wort als Bindestrich — dieselbe Falle wie
            // beim Setzen einer PDF in Textauszug.
            .replacingOccurrences(of: "\u{00AD}", with: "")
            .replacingOccurrences(of: "\u{FFFC}", with: "")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    // Die Zeile auf ihr Muster gebracht: Ziffern werden zu `#`, damit
    // „Seite 3 von 30" und „Seite 4 von 30" dasselbe sind. Genau daran
    // hängt die ganze Erkennung — ohne diesen Schritt käme eine
    // durchlaufende Seitenzahl nie zweimal vor.
    private static func marke(_ zeile: String) -> String {
        var gebaut = ""
        var zifferOffen = false
        for zeichen in zeile.lowercased() {
            if zeichen.isNumber {
                if !zifferOffen { gebaut.append("#"); zifferOffen = true }
            } else {
                zifferOffen = false
                gebaut.append(zeichen)
            }
        }
        return gebaut.trimmingCharacters(in: .whitespaces)
    }

    private static func wiederkehrend(_ seiten: [[String]]) -> Set<String> {
        // Unter drei Seiten wird gar nichts entfernt: Zwei gleiche erste
        // Zeilen auf zwei Seiten sind ein Zufall, keine Kopfzeile.
        guard seiten.count >= 3 else { return [] }
        var zaehler: [String: Int] = [:]
        for seite in seiten {
            var gesehen = Set<String>()
            for kante in [seite.first, seite.last] {
                guard let kante else { continue }
                let schluessel = marke(kante)
                // Eine sehr lange Zeile ist Fließtext, keine Kopfzeile;
                // eine leere Marke (nur Ziffern) wäre die nackte
                // Seitenzahl und soll gerade WEG.
                guard kante.count <= 90, gesehen.insert(schluessel).inserted else { continue }
                zaehler[schluessel, default: 0] += 1
            }
        }
        let noetig = max(3, Int((Double(seiten.count) * 0.6).rounded(.up)))
        return Set(zaehler.filter { $0.value >= noetig }.keys)
    }
}
