import CoreGraphics
import CoreText
import Foundation
import UIKit

// Was einem Druckdienst an diesem Buch auffallen würde — bevor er es
// auffällt.
//
// Das ist dieselbe Bauweise wie „Zustellung prüfen" bei Schulalarm: Wo sich
// etwas nicht versprechen lässt, muss eine Probe entscheiden. Ein Buch geht
// einmal in den Druck und kommt eine Woche später als Stapel Papier zurück;
// bis dahin ist jeder Fehler bezahlt.
enum Druckpruefung {
    enum Stufe: String {
        case gut
        case hinweis
        case warnung

        var symbol: String {
            switch self {
            case .gut: return "checkmark.circle.fill"
            case .hinweis: return "info.circle"
            case .warnung: return "exclamationmark.triangle.fill"
            }
        }
    }

    struct Zeile: Identifiable {
        var id = UUID()
        var stufe: Stufe
        var titel: String
        var text: String
    }

    // Ein Kasten, aus dem unten Text herausfällt, ist der eine Fehler, den
    // ein Tagebuch nicht machen darf: Auf dem Bildschirm sieht er aus wie
    // ein Kasten, der zu Ende ist, und im gedruckten Buch fehlt ein Satz.
    // Auf der Seite steht dafür die orange Marke — die sieht aber nur, wer
    // gerade auf dieser Seite ist. Das ganze Buch zählt diese Prüfung.
    static func abgeschnittenerText(_ reise: Reise) -> [Zeile] {
        var betroffen: [String] = []
        for tag in reise.tage {
            for seite in tag.seiten {
                for block in seite.bloecke where block.inhalt.istText {
                    let text = Seitensatz.inhaltstext(block, tag: tag, reise: reise)
                    guard !text.isEmpty, block.rahmen.breite > 1 else { continue }
                    let bild = Seitensatz.schriftbild(block, reise: reise)
                    // Dieselbe Rechnung wie in `Reisewerk.fehlendeHöhe` —
                    // samt Innenabstand. Zwei Fassungen ergaben eine Seite,
                    // auf der die Marke schweigt und die Prüfung anschlägt.
                    let rand = block.textrand(reise.gestaltung)
                    let noetig = Textmass.hoehe(text, bild: bild,
                                                breite: block.textbreite(rand: rand))
                        + 2 * rand
                    guard noetig > block.rahmen.hoehe + 0.5 else { continue }
                    betroffen.append("\(tag.datum.mittel): \(block.inhalt.name), es fehlen \(Druckmass.mmText(noetig - block.rahmen.hoehe))")
                }
            }
        }
        guard !betroffen.isEmpty else {
            return [Zeile(stufe: .gut, titel: "Kein abgeschnittener Text",
                          text: "In jeden Textkasten passt, was darin steht.")]
        }
        return [Zeile(
            stufe: .warnung,
            titel: "\(betroffen.count) Textkästen sind zu klein",
            text: "Unten fällt Text heraus und steht so auch nicht im PDF. Auf der Seite ist der Kasten mit einer orangen Marke versehen; \u{201E}Rahmen an Text anpassen\u{201C} löst es auf.\n" + betroffen.prefix(12).joined(separator: "\n")
        )]
    }

    // Zwei Textkästen auf derselben Seite mit demselben Wortlaut — das
    // druckt denselben Absatz zweimal. Auf dem Bildschirm liegen sie leicht
    // übereinander und sehen aus wie ein Darstellungsfehler; im Buch sind
    // es zwei Absätze. Gemeldet 09/2026 als „das Textfeld erscheint
    // dupliziert"; woher der zweite Kasten kam, ist damit noch nicht
    // beantwortet — aber er ist ab jetzt nicht mehr zu übersehen.
    static func doppelterText(_ reise: Reise) -> [Zeile] {
        var treffer: [String] = []
        for tag in reise.tage {
            for (nummer, seite) in tag.seiten.enumerated() {
                var gesehen: [String: Int] = [:]
                for block in seite.bloecke where block.inhalt.istText {
                    let text = Seitensatz.inhaltstext(block, tag: tag, reise: reise)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    guard text.count > 20 else { continue }
                    gesehen[text, default: 0] += 1
                }
                for (text, anzahl) in gesehen where anzahl > 1 {
                    let anfang = text.prefix(40)
                    treffer.append("\(tag.datum.mittel), Seite \(nummer + 1): \(anzahl)× \u{201E}\(anfang)…\u{201C}")
                }
            }
        }
        guard !treffer.isEmpty else { return [] }
        return [Zeile(
            stufe: .warnung,
            titel: "\(treffer.count)× derselbe Text mehrfach auf einer Seite",
            text: "Derselbe Wortlaut steht in mehreren Textkästen und würde doppelt gedruckt. Den überzähligen Kasten antippen und im Inspektor mit \u{201E}Block entfernen\u{201C} wegnehmen.\n" + treffer.prefix(12).joined(separator: "\n")
        )]
    }

    // MARK: - Vor dem Ausgeben

    static func vorab(_ reise: Reise) -> [Zeile] {
        var zeilen: [Zeile] = []
        let format = reise.format
        let gestaltung = reise.gestaltung
        let bogen = gestaltung.bogen(format)

        zeilen.append(Zeile(
            stufe: .gut,
            titel: "Endformat \(format.masstext)",
            text: "Die PDF-Seite misst \(Druckmass.mmText(bogen.width)) x \(Druckmass.mmText(bogen.height)) — Endformat plus \(Int(gestaltung.anschnitt)) mm Anschnitt an jeder Kante. Endformat und Anschnitt stehen als TrimBox und BleedBox in der Datei."
        ))

        if gestaltung.anschnitt < 2.5 {
            zeilen.append(Zeile(
                stufe: .warnung,
                titel: "Kein oder zu wenig Anschnitt",
                text: "Die meisten Druckdienste verlangen 3 mm, manche Buchdienste 5 mm. Ohne Zugabe kann kein Bild bis an die Papierkante laufen: Jede Schneidemaschine hat ein Spiel, und dort bliebe ein weißer Faden stehen."
            ))
        }

        zeilen.append(contentsOf: bildaufloesung(reise))
        zeilen.append(contentsOf: schriften(reise))
        zeilen.append(contentsOf: abgeschnittenerText(reise))
        zeilen.append(contentsOf: doppelterText(reise))

        // Randabfallendes
        let randab = reise.seitenfolge.reduce(0) { summe, seite in
            summe + seite.seite.bloecke.filter(\.randabfallend).count
        }
        if randab > 0 {
            zeilen.append(Zeile(
                stufe: gestaltung.anschnitt >= 2.5 ? .gut : .warnung,
                titel: "\(randab) randabfallende Bilder",
                text: gestaltung.anschnitt >= 2.5
                    ? "Sie reichen bis in den Anschnitt und werden sauber beschnitten."
                    : "Sie reichen über das Endformat hinaus, aber es gibt keinen Anschnitt. Stelle ihn auf mindestens 3 mm."
            ))
        }

        // Transparenz
        let mitSchatten = reise.seitenfolge.contains { seite in
            seite.seite.bloecke.contains {
                $0.wirkung(reise.gestaltung).schatten != .keiner || $0.inhalt == .verlauf
            }
        }
        if mitSchatten {
            zeilen.append(Zeile(
                stufe: .hinweis,
                titel: "Das Buch enthält Transparenz",
                text: "Schatten und Verläufe brauchen sie. Fotobuchdienste nehmen das ohne Weiteres. Verlangt eine Druckerei ausdrücklich PDF/X-1a oder PDF/X-3, dürfen sie nicht vorkommen — dann beim Ausgeben „Ohne Transparenz“ wählen."
            ))
        }

        // Farbraum
        zeilen.append(Zeile(
            stufe: .hinweis,
            titel: "Die Bilder bleiben in RGB",
            text: "Für Fotobücher ist das richtig — die Dienste rechnen selbst in ihren Druckfarbraum um und verlangen ausdrücklich RGB. Wer bei einer klassischen Offsetdruckerei bestellt, die CMYK mit ISO Coated v2 will, muss die Datei vorher umwandeln lassen; diese App kann das nicht."
        ))

        let bund = gestaltung.bundsteg
        if bund < 3, reise.seitenzahl > 40 {
            zeilen.append(Zeile(
                stufe: .hinweis,
                titel: "Bundsteg prüfen",
                text: "Bei \(reise.seitenzahl) Seiten und Klebebindung verschwindet ein Teil des inneren Randes im Falz. Fünf Millimeter Bundsteg sind dort üblich."
            ))
        }
        return zeilen
    }

    // Die wichtigste Zahl, und die einzige, die man einem Foto nicht
    // ansieht: Ein Bild ist scharf, solange es klein steht, und matschig,
    // sobald es über eine halbe Seite läuft.
    private static func bildaufloesung(_ reise: Reise) -> [Zeile] {
        var schlechteste: (dpi: Double, seite: Int)?
        var unterGrenze = 0
        var unterGut = 0
        var gezaehlt = 0

        for buchseite in reise.seitenfolge {
            for block in buchseite.seite.bloecke {
                guard let id = block.fotoID, let foto = reise.foto(id) else { continue }
                gezaehlt += 1
                // Gerechnet wird mit der langen Kante des Rahmens gegen die
                // entsprechende Pixelzahl — und mit dem Zoom des
                // Ausschnitts, denn wer in ein Bild hineinzoomt, benutzt
                // weniger Pixel für dieselbe Fläche.
                let zoom = max(block.ausschnitt.zoom, 1)
                let breiteDpi = Druckmass.dpi(pixel: foto.breite / zoom,
                                              punkte: block.rahmen.breite)
                let hoeheDpi = Druckmass.dpi(pixel: foto.hoehe / zoom,
                                             punkte: block.rahmen.hoehe)
                let wert = min(breiteDpi, hoeheDpi)
                if wert < Druckmass.dpiGrenze { unterGrenze += 1 }
                else if wert < Druckmass.dpiGut { unterGut += 1 }
                if schlechteste == nil || wert < schlechteste!.dpi {
                    schlechteste = (wert, buchseite.nummer)
                }
            }
        }

        guard gezaehlt > 0, let schlechteste else { return [] }
        if unterGrenze > 0 {
            return [Zeile(
                stufe: .warnung,
                titel: "\(unterGrenze) Bilder unter 150 dpi",
                text: "Sie werden im Druck sichtbar weich. Das schwächste liegt bei \(Int(schlechteste.dpi)) dpi auf Seite \(schlechteste.seite). Kleiner setzen oder das Bild in höherer Auflösung einlesen."
            )]
        }
        if unterGut > 0 {
            return [Zeile(
                stufe: .hinweis,
                titel: "\(unterGut) Bilder unter 250 dpi",
                text: "Das reicht für ein Fotobuch meistens noch. Das schwächste liegt bei \(Int(schlechteste.dpi)) dpi auf Seite \(schlechteste.seite)."
            )]
        }
        return [Zeile(
            stufe: .gut,
            titel: "Alle Bilder über 250 dpi",
            text: "Das schwächste liegt bei \(Int(schlechteste.dpi)) dpi. 300 dpi sind der Anspruch jeder Druckerei."
        )]
    }

    // MARK: - Schriften

    // Ob eine Schrift überhaupt eingebettet werden DARF, steht in ihr
    // selbst: im Feld `fsType` der OS/2-Tabelle. Eine Schrift mit
    // „Restricted License Embedding" landet nicht im PDF, und die Druckerei
    // ersetzt sie stillschweigend durch eine andere — das ist genau die Art
    // Fehler, die man erst am gedruckten Buch sieht.
    //
    // Gelesen wird die Tabelle, nicht geraten. Gibt eine Schrift sie nicht
    // heraus, sagt die Prüfung das und behauptet nichts.
    static func einbettung(_ familie: Schriftfamilie) -> String? {
        let schrift = familie.uiFont(groesse: 12, fett: false, kursiv: false) as CTFont
        guard let tabelle = CTFontCopyTable(schrift, CTFontTableTag(kCTFontTableOS2), []) else {
            return nil
        }
        let daten = tabelle as Data
        guard daten.count >= 10 else { return nil }
        let wert = (UInt16(daten[8]) << 8) | UInt16(daten[9])
        // Die unteren vier Bit tragen die Erlaubnis; alles darüber sind
        // eigene Flaggen (kein Subsetting, nur Bitmap).
        switch wert & 0x000F {
        case 0: return "frei einbettbar"
        case 2: return "EINBETTUNG VERBOTEN"
        case 4: return "einbettbar zum Ansehen und Drucken"
        case 8: return "frei einbettbar und bearbeitbar"
        default: return "einbettbar"
        }
    }

    private static func schriften(_ reise: Reise) -> [Zeile] {
        var benutzt = Set<Schriftfamilie>()
        for rolle in Schriftrolle.allCases { benutzt.insert(reise.typografie[rolle].familie) }
        for tag in reise.tage {
            for seite in tag.seiten {
                for block in seite.bloecke {
                    if let familie = block.abweichung.familie { benutzt.insert(familie) }
                }
            }
        }

        var verboten: [String] = []
        var unbekannt: [String] = []
        var erlaubt: [String] = []
        for familie in benutzt.sorted(by: { $0.name < $1.name }) {
            switch einbettung(familie) {
            case .none:
                unbekannt.append(familie.name)
            case .some(let auskunft) where auskunft.contains("VERBOTEN"):
                verboten.append(familie.name)
            default:
                erlaubt.append(familie.name)
            }
        }

        var zeilen: [Zeile] = []
        if !verboten.isEmpty {
            zeilen.append(Zeile(
                stufe: .warnung,
                titel: "Schrift darf nicht eingebettet werden",
                text: "\(verboten.joined(separator: ", ")) — die Druckerei ersetzt sie dann durch eine andere, ohne es zu sagen. Wähle eine andere Schrift."
            ))
        }
        if !unbekannt.isEmpty {
            zeilen.append(Zeile(
                stufe: .hinweis,
                titel: "Einbettung nicht feststellbar",
                text: "\(unbekannt.joined(separator: ", ")) gibt die Auskunft nicht heraus. Das sind meistens die Systemschriften. Wenn es sicher sein soll, nimm eine der benannten Familien."
            ))
        }
        if !erlaubt.isEmpty, verboten.isEmpty, unbekannt.isEmpty {
            zeilen.append(Zeile(
                stufe: .gut,
                titel: "Alle Schriften sind einbettbar",
                text: erlaubt.joined(separator: ", ") + "."
            ))
        }
        return zeilen
    }

    // MARK: - Am fertigen PDF

    // Die Gegenprobe an der Datei selbst. Was hier steht, ist gemessen und
    // nicht erschlossen — die Boxen kommen aus dem PDF, nicht aus dem
    // Modell, das es geschrieben hat.
    static func amPDF(_ adresse: URL) -> [Zeile] {
        guard let papier = CGPDFDocument(adresse as CFURL) else {
            return [Zeile(stufe: .warnung, titel: "Das PDF ließ sich nicht lesen",
                          text: "Die Datei ist beschädigt oder leer.")]
        }
        var zeilen: [Zeile] = []
        let groesse = (try? adresse.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        zeilen.append(Zeile(
            stufe: .gut,
            titel: "\(papier.numberOfPages) Seiten, \(String(format: "%.1f", Double(groesse) / 1_048_576)) MB",
            text: "Die Datei ist geschrieben und lesbar."
        ))
        if let erste = papier.page(at: 1) {
            let medien = erste.getBoxRect(.mediaBox)
            let trim = erste.getBoxRect(.trimBox)
            zeilen.append(Zeile(
                stufe: .gut,
                titel: "Bogen \(Druckmass.mmText(medien.width)) x \(Druckmass.mmText(medien.height))",
                text: "Endformat laut TrimBox: \(Druckmass.mmText(trim.width)) x \(Druckmass.mmText(trim.height)). Daran erkennt der Druckdienst, wo geschnitten wird."
            ))
        }
        return zeilen
    }
}
