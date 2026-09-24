import CoreGraphics
import CoreText
import Foundation
import UIKit

// Der eine Setzer.
//
// Eine Buchseite wird in dieser App zweimal gezeichnet: auf dem Bildschirm,
// damit man sie anfassen kann, und ins PDF, damit man sie drucken kann.
// Zwei Zeichenwege bedeuten früher oder später zwei Ergebnisse — und der
// Unterschied fällt genau dann auf, wenn das Buch schon beim Drucker liegt.
//
// Deshalb steht hier, was BEIDE benutzen: der Textsatz, die Trennlinie und
// das Bild in seinem Rahmen. Die Ansicht hängt eine UIView davor, die
// nichts weiter tut, als diese Funktionen aufzurufen; der PDF-Ausgeber ruft
// sie unmittelbar.
enum Seitensatz {
    // WER MIT UIKIT ZEICHNET, MUSS UIKIT SAGEN, WOHIN (ab 1.0.68).
    //
    // `UIImage.draw(in:)`, `UIBezierPath.fill()`, `.stroke()` und
    // `.addClip()` fragen NICHT den `CGContext`, den man ihnen daneben
    // hinstellt — sie zeichnen in den Kontext, der gerade oben auf UIKits
    // eigenem Stapel liegt (`UIGraphicsGetCurrentContext`). Liegt dort
    // keiner, tun sie schlicht NICHTS: kein Fehler, keine Warnung, kein
    // Absturz — die Farbflächen und der Text stehen da, und die Bilder
    // fehlen.
    //
    // Genau das hat der Umschlagbogen zwei Fassungen lang getan (gemeldet
    // 09/2026, zweimal): `umschlagPdf` schiebt seinen eigenen Zeichenblock
    // und hatte als einziger der drei Ausgabewege kein
    // `UIGraphicsPushContext`. Heraus kam ein Bogen mit Titel, Rückentext
    // und weißem Papier — 53 kB für ein Panorama.
    //
    // **Das Pushen gehört deshalb DORTHIN, wo UIKit zeichnet**, und nicht
    // an die Aufrufstelle: Eine vergessene Aufrufstelle fällt erst an der
    // ausgegebenen Datei auf, und dann sucht man an der falschen Stelle.
    // Der Stapel ist schachtelbar, doppeltes Pushen desselben Kontexts ist
    // also harmlos. **Wer eine siebte Zeichenfunktion mit UIKit baut,
    // legt ihren Körper hier hinein.**
    static func mitUIKit(_ zusammenhang: CGContext, _ arbeit: () -> Void) {
        UIGraphicsPushContext(zusammenhang)
        defer { UIGraphicsPopContext() }
        arbeit()
    }

    // EIN BILD ALS JPEG IN DIE DATEI (ab 1.0.70).
    //
    // Gemeldet 09/2026: „Die Exportdatei [wird] bei 62 Seiten … 4 Gigabyte
    // groß. Denn das wird von den Druckdiensten leider nicht angenommen.“
    //
    // `UIImage.draw(in:)` schreibt in ein PDF eine UNKOMPRIMIERTE Fläche:
    // drei Byte je Bildpunkt. Ein seitenfüllendes Foto bei 300 dpi sind so
    // rund 25 MB, und ein Buch hat Hunderte davon. Stammt ein `CGImage`
    // dagegen aus einem JPEG-Datenstrom, übernimmt CoreGraphics diesen
    // Strom unverändert in die Datei, statt ihn zu entpacken.
    //
    // **Das ist die Erwartung und keine Messung** — gesehen hat es hier
    // niemand. Greift es nicht, ist die Datei so groß wie vorher; kaputt
    // ist nichts, und die kleinere Bildkante (siehe
    // `Ausgabeguete.ausgabekante`) wirkt unabhängig davon.
    //
    // **Ein Bild MIT Alphakanal wird nie so geschrieben.** JPEG kennt keine
    // Durchsichtigkeit; eine eingesetzte Grafik mit freigestelltem Grund
    // bekäme einen weißen Kasten. Das ist die eine Stelle, an der diese
    // Abkürzung sichtbar falsch wäre — deshalb wird sie geprüft und nicht
    // angenommen.
    //
    // Gezeichnet wird mit `CGContext.draw`, und das rechnet von UNTEN
    // links. Der Zeichenkontext dieser App ist längst umgedreht, also wird
    // um die Mittellinie des Zielrechtecks noch einmal gespiegelt.
    private static func jpegEingebettet(_ bild: UIImage, in ziel: CGRect, guete: Double,
                                        zusammenhang: CGContext) -> Bool
    {
        guard guete > 0, let roh = bild.cgImage else { return false }
        // Ausgeschrieben, weil `.none` sonst mit `Optional.none` streiten
        // kann. Und: Ob ein Bild aus der Mediathek hier ohne Alphakanal
        // ankommt, hängt daran, was ImageIO beim Verkleinern baut — das
        // ist NICHT gemessen. Kommt es mit Alphakanal, bleibt es
        // unkomprimiert, und die Datei ist größer als geschätzt; falsch
        // aussehen kann dadurch nichts.
        switch roh.alphaInfo {
        case CGImageAlphaInfo.none, CGImageAlphaInfo.noneSkipFirst,
             CGImageAlphaInfo.noneSkipLast:
            break
        default:
            return false
        }
        guard let daten = bild.jpegData(compressionQuality: CGFloat(guete)),
              let quelle = CGDataProvider(data: daten as CFData),
              let eingebettet = CGImage(jpegDataProviderSource: quelle, decode: nil,
                                        shouldInterpolate: true, intent: .defaultIntent)
        else { return false }
        zusammenhang.saveGState()
        zusammenhang.translateBy(x: 0, y: ziel.midY)
        zusammenhang.scaleBy(x: 1, y: -1)
        zusammenhang.translateBy(x: 0, y: -ziel.midY)
        zusammenhang.draw(eingebettet, in: ziel)
        zusammenhang.restoreGState()
        return true
    }

    // Text mit CoreText. `draw(with:)` aus UIKit wäre kürzer und setzte
    // über TextKit — also über einen anderen Zeilenumbruch als den, mit dem
    // `Textmass` gerechnet hat. Ein Text, der beim Messen sechs Zeilen hatte
    // und beim Zeichnen sieben, läuft unten aus seinem Block.
    static func zeichneText(_ text: String, bild: Schriftbild, rechteck: CGRect,
                            in zusammenhang: CGContext, seitenhoehe: CGFloat)
    {
        guard !text.isEmpty, rechteck.width > 1, rechteck.height > 1 else { return }
        zusammenhang.saveGState()
        zusammenhang.textMatrix = .identity
        zusammenhang.translateBy(x: 0, y: seitenhoehe)
        zusammenhang.scaleBy(x: 1, y: -1)

        let gedreht = CGRect(
            x: rechteck.minX,
            y: seitenhoehe - rechteck.maxY,
            width: rechteck.width,
            height: rechteck.height
        )
        // Dieselbe Breite, mit der auch gemessen wurde — an ihr hängt seit
        // 1.0.40 die Silbentrennung.
        // `Double(…)` ausdrücklich: Überall, wo ein Wert aus einem `CGRect`
        // in ein `Double` geht, steht in diesem Repo die Umwandlung dabei
        // (die Falle aus 1.0.37, dort ein zweites Mal bezahlt).
        let setzer = Textmass.rahmensetzer(text, bild: bild, breite: Double(rechteck.width))
        let pfad = CGPath(rect: gedreht, transform: nil)
        let rahmen = CTFramesetterCreateFrame(setzer, CFRange(location: 0, length: 0), pfad, nil)
        CTFrameDraw(rahmen, zusammenhang)
        zusammenhang.restoreGState()
    }

    // `jpegGuete` ist NUR für die Ausgabe: `nil` heißt „wie bisher“, und so
    // ruft der Bildschirm. An der LAGE ändert der Wert nichts — dasselbe
    // Zielrechteck, derselbe Beschnitt; unterschiedlich ist allein, wie die
    // Bildpunkte in die Datei kommen. Die erste Regel dieser App (ein
    // Setzer für Seite und PDF) bleibt damit unangetastet.
    static func zeichneBild(_ bild: UIImage, ausschnitt: Bildausschnitt, rechteck: CGRect,
                            in zusammenhang: CGContext, eckenradius: CGFloat,
                            jpegGuete: Double? = nil)
    {
        zusammenhang.saveGState()
        if eckenradius > 0.5 {
            mitUIKit(zusammenhang) {
                UIBezierPath(roundedRect: rechteck, cornerRadius: eckenradius).addClip()
            }
        } else {
            zusammenhang.clip(to: rechteck)
        }
        let ziel = ausschnitt.zielrechteck(bildgroesse: bild.size, rahmen: rechteck)
        var geschrieben = false
        if let jpegGuete {
            geschrieben = jpegEingebettet(bild, in: ziel, guete: jpegGuete,
                                          zusammenhang: zusammenhang)
        }
        if !geschrieben {
            mitUIKit(zusammenhang) { bild.draw(in: ziel) }
        }
        zusammenhang.restoreGState()
    }

    // Der weiße Rand eines Sofortbildes. Er gehört NACH AUSSEN, nicht nach
    // innen: Ein Rand, der vom Bild abgeht, machte jede Reihe des
    // Layoutautomaten um zwei Ränder zu schmal, und die Reihen gingen nicht
    // mehr auf.
    static func fotorandRechteck(_ rechteck: CGRect, rand: CGFloat) -> CGRect {
        rechteck.insetBy(dx: -rand, dy: -rand)
    }

    // Schatten und Papierrand in einem: Erst der Schatten unter dem
    // weißen Feld, dann das Feld, dann das Bild darin. Andersherum läge der
    // Schatten über dem Bild.
    static func zeichneSchatten(_ rechteck: CGRect, art: Schattenart, massstab: CGFloat,
                                eckenradius: CGFloat, in zusammenhang: CGContext)
    {
        guard art != .keiner else { return }
        let werte = art.werte
        zusammenhang.saveGState()
        zusammenhang.setShadow(
            offset: CGSize(width: 0, height: werte.versatz * massstab),
            blur: werte.unschaerfe * massstab,
            color: UIColor.black.withAlphaComponent(werte.deckung).cgColor
        )
        zusammenhang.setFillColor(UIColor.white.cgColor)
        mitUIKit(zusammenhang) {
            UIBezierPath(roundedRect: rechteck, cornerRadius: eckenradius).fill()
        }
        zusammenhang.restoreGState()
    }

    static func zeichneFlaeche(_ rechteck: CGRect, farbe: UIColor, eckenradius: CGFloat,
                               in zusammenhang: CGContext)
    {
        zusammenhang.saveGState()
        zusammenhang.setFillColor(farbe.cgColor)
        mitUIKit(zusammenhang) {
            UIBezierPath(roundedRect: rechteck, cornerRadius: eckenradius).fill()
        }
        zusammenhang.restoreGState()
    }

    // Der Verlauf unter einer Überschrift auf einem Foto: unten dunkel,
    // oben durchsichtig.
    //
    // `opak` ist der Weg für Druckereien, die kein PDF mit Transparenz
    // annehmen (PDF/X-1a und X-3 erlauben keine). Dann steht statt des
    // Verlaufs ein geschlossenes Feld — weniger elegant, aber lesbar, und
    // das ist hier das Wichtigere.
    static func zeichneVerlauf(_ rechteck: CGRect, opak: Bool, in zusammenhang: CGContext) {
        zusammenhang.saveGState()
        if opak {
            zusammenhang.setFillColor(UIColor(white: 0.08, alpha: 1).cgColor)
            zusammenhang.fill(rechteck)
            zusammenhang.restoreGState()
            return
        }
        let farben = [
            UIColor(white: 0, alpha: 0).cgColor,
            UIColor(white: 0, alpha: 0.30).cgColor,
            UIColor(white: 0, alpha: 0.72).cgColor,
        ] as CFArray
        let stellen: [CGFloat] = [0, 0.45, 1]
        guard let verlauf = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                       colors: farben, locations: stellen)
        else {
            zusammenhang.restoreGState()
            return
        }
        zusammenhang.clip(to: rechteck)
        zusammenhang.drawLinearGradient(
            verlauf,
            start: CGPoint(x: rechteck.midX, y: rechteck.minY),
            end: CGPoint(x: rechteck.midX, y: rechteck.maxY),
            options: []
        )
        zusammenhang.restoreGState()
    }

    // Ein einzelnes Korn auf dem Papier: wo es liegt und wie dunkel es ist.
    struct Kornpunkt {
        var ort: CGPoint
        var deckung: Double
    }

    // Das Korn — gerechnet, und zwar WIEDERHOLBAR.
    //
    // Bis 1.0.15 würfelten Bildschirm und PDF es je für sich mit einem
    // `SystemRandomNumberGenerator` aus, und der lässt sich nicht
    // wiederholen. Zwei Folgen, und beide waren zu sehen: Auf dem
    // Bildschirm war das Korn bei jeder Neuzeichnung ein anderes, also ein
    // Flimmern statt einer Struktur — und die gedruckte Seite sah nie aus
    // wie die angesehene. Im Quelltext stand daneben, der Zufallsstrom sei
    // „an der Seite festgemacht"; er war es nie. **Ein Kommentar ersetzt
    // keine Prüfung** — dieselbe Lehre wie bei Schulalarms
    // `requestAuthorization` und bei den Navigationszielen der
    // Abfahrtstafel.
    //
    // Gerechnet wird an EINER Stelle, gefragt von Ansicht UND PDF; zwei
    // Fassungen desselben Korns wären wieder zwei Seiten.
    static func kornpunkte(groesse: CGSize, koernung: Double, saat: UInt64) -> [Kornpunkt] {
        guard koernung > 0.005, groesse.width > 1, groesse.height > 1 else { return [] }
        var streu = Saatstrom(saat)
        let anzahl = Int(groesse.width * groesse.height / 900)
        var punkte: [Kornpunkt] = []
        punkte.reserveCapacity(anzahl)
        for _ in 0..<anzahl {
            let x = Double.random(in: 0..<groesse.width, using: &streu)
            let y = Double.random(in: 0..<groesse.height, using: &streu)
            let deckung = Double.random(in: 0..<koernung, using: &streu)
            punkte.append(Kornpunkt(ort: CGPoint(x: x, y: y), deckung: deckung))
        }
        return punkte
    }

    // Der Seitenhintergrund — in Ansicht und PDF derselbe.
    //
    // `saat` macht das Papierkorn an der SEITE fest: dieselbe Seite bekommt
    // immer dasselbe Korn, zwei Seiten nebeneinander ein verschiedenes.
    // `bildflaeche` ist die Fläche, in die das HINTERGRUNDFOTO gerechnet
    // wird — sonst derselbe Bogen. Sie ist größer als er, wenn das Bild
    // über die Doppelseite geht: Dann füllt es zwei Seiten, und diese
    // eine zeigt ihre Hälfte davon. Beschnitten wird trotzdem am Bogen —
    // die Nachbarseite ist ein eigenes Blatt Papier.
    static func zeichneHintergrund(_ grund: Seitenhintergrund, rechteck: CGRect,
                                   bild: UIImage?, saat: UInt64 = 0,
                                   bildflaeche: CGRect? = nil,
                                   jpegGuete: Double? = nil,
                                   in zusammenhang: CGContext)
    {
        zusammenhang.saveGState()
        zusammenhang.setFillColor(grund.farbe.uiFarbe.cgColor)
        zusammenhang.fill(rechteck)

        switch grund.art {
        case .einfarbig:
            break
        case .verlauf:
            let farben = [grund.farbe.uiFarbe.cgColor, grund.zweitfarbe.uiFarbe.cgColor] as CFArray
            if let verlauf = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                        colors: farben, locations: [0, 1])
            {
                let bogen = grund.winkel * .pi / 180
                let halb = CGPoint(x: rechteck.midX, y: rechteck.midY)
                let weite = max(rechteck.width, rechteck.height)
                zusammenhang.clip(to: rechteck)
                zusammenhang.drawLinearGradient(
                    verlauf,
                    start: CGPoint(x: halb.x - cos(bogen) * weite / 2,
                                   y: halb.y - sin(bogen) * weite / 2),
                    end: CGPoint(x: halb.x + cos(bogen) * weite / 2,
                                 y: halb.y + sin(bogen) * weite / 2),
                    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
                )
            }
        case .papierstruktur:
            // Dasselbe Korn wie auf dem Bildschirm — buchstäblich dasselbe,
            // seit es aus `kornpunkte` kommt und nicht mehr aus zwei
            // getrennten Würfen.
            zusammenhang.clip(to: rechteck)
            for punkt in Self.kornpunkte(groesse: rechteck.size,
                                         koernung: grund.koernung, saat: saat)
            {
                zusammenhang.setFillColor(UIColor.black.withAlphaComponent(punkt.deckung).cgColor)
                zusammenhang.fill(CGRect(x: rechteck.minX + punkt.ort.x,
                                         y: rechteck.minY + punkt.ort.y,
                                         width: 1.2, height: 1.2))
            }
        case .foto:
            if let bild {
                zusammenhang.saveGState()
                zusammenhang.clip(to: rechteck)
                // Gesättigt wird VOR dem Schleier und mit derselben
                // Funktion, die auch der Bildschirm ruft (ab 1.0.55) —
                // zwei Wege ergäben zwei Bilder, und der Unterschied fiele
                // erst im gedruckten Buch auf.
                let kraeftig = Farbkraft.verstaerkt(bild, faktor: grund.farbkraftfaktor)
                // Wo im Bild die Fläche liegt, sagt seit 1.0.58 der
                // Ausschnitt des Hintergrunds — und zwar über dieselbe
                // Funktion, die auch der Bildschirm fragt. Vorher stand
                // hier `.voll`, also immer mittig.
                let ziel = grund.ausschnitt.gefuelltesZiel(bildgroesse: kraeftig.size,
                                                           rahmen: bildflaeche ?? rechteck)
                var geschrieben = false
                if let jpegGuete {
                    geschrieben = jpegEingebettet(kraeftig, in: ziel, guete: jpegGuete,
                                                  zusammenhang: zusammenhang)
                }
                if !geschrieben {
                    mitUIKit(zusammenhang) { kraeftig.draw(in: ziel) }
                }
                zusammenhang.restoreGState()
            }
            zusammenhang.setFillColor(
                grund.farbe.uiFarbe.withAlphaComponent(grund.schleier).cgColor)
            zusammenhang.fill(rechteck)
        }
        zusammenhang.restoreGState()
    }

    // Das Wasserzeichen. Gezeichnet wird es zwischen Hintergrund und
    // Blöcken — also unter allem, was auf der Seite steht.
    //
    // Die Deckkraft steckt im Zeichenbefehl (`alpha:`) und nicht in einer
    // zweiten Fläche darüber: Ein Schleier über dem Bild legte sich auch
    // über den Hintergrund und machte die Seite fleckig.
    static func zeichneWasserzeichen(_ bild: UIImage, ort: Wasserzeichenlage.Ort,
                                     deckung: Double, in zusammenhang: CGContext)
    {
        guard deckung > 0.001 else { return }
        zusammenhang.saveGState()
        // Gedreht wird um die MITTE des Platzes, den die Lagerechnung
        // dafür freigehalten hat — dieselbe Mitte, um die auch der
        // Bildschirm dreht. Rechnete einer der beiden um eine andere,
        // stünde das Zeichen im Druck woanders als in der Vorschau.
        if abs(ort.winkel) > 0.01 {
            zusammenhang.translateBy(x: ort.rahmen.midX, y: ort.rahmen.midY)
            zusammenhang.rotate(by: CGFloat(ort.winkel * .pi / 180))
            zusammenhang.translateBy(x: -ort.rahmen.midX, y: -ort.rahmen.midY)
        }
        let ziel = Wasserzeichenlage.eingepasst(bildgroesse: bild.size, rahmen: ort.bildrahmen)
        mitUIKit(zusammenhang) {
            bild.draw(in: ziel, blendMode: .normal, alpha: CGFloat(min(deckung, 1)))
        }
        zusammenhang.restoreGState()
    }

    static func zeichneLinie(_ rechteck: CGRect, farbe: UIColor, in zusammenhang: CGContext) {
        zusammenhang.saveGState()
        zusammenhang.setFillColor(farbe.cgColor)
        zusammenhang.fill(CGRect(x: rechteck.minX, y: rechteck.minY,
                                 width: rechteck.width, height: max(rechteck.height, 0.6)))
        zusammenhang.restoreGState()
    }

    static func zeichneRahmen(_ rechteck: CGRect, farbe: UIColor, breite: CGFloat,
                              eckenradius: CGFloat, in zusammenhang: CGContext)
    {
        guard breite > 0 else { return }
        zusammenhang.saveGState()
        let weg = UIBezierPath(roundedRect: rechteck.insetBy(dx: breite / 2, dy: breite / 2),
                               cornerRadius: max(eckenradius - breite / 2, 0))
        zusammenhang.setStrokeColor(farbe.cgColor)
        weg.lineWidth = breite
        mitUIKit(zusammenhang) { weg.stroke() }
        zusammenhang.restoreGState()
    }

    // Der Text eines Blocks, wie er an dieser Stelle wirklich lautet.
    // Datum und Überschrift stehen nicht im Block, sondern am Tag — sonst
    // müsste man sie an zwei Stellen ändern und hätte irgendwann zwei
    // verschiedene.
    static func inhaltstext(_ block: Block, tag: Reisetag?, reise: Reise) -> String {
        switch block.inhalt {
        case .titel:
            if let tag { return tag.ueberschrift }
            return reise.titel
        case .unterueberschrift:
            // Auf dem Titelblatt gibt es sie nicht — dort steht der
            // Untertitel des Buches an dieser Stelle.
            return tag?.unterueberschrift ?? ""
        case .datum:
            guard let tag else { return reise.zeitraum }
            return datumstext(tag, reise: reise)
        case let .text(wert):
            return wert
        case let .bildunterschrift(id):
            // Der Text steht am FOTO, nicht im Block: Sonst wäre er beim
            // nächsten Neuanordnen weg, und wer ein Bild auf eine andere
            // Seite zieht, ließe seine Unterschrift zurück.
            return reise.foto(id)?.unterschrift ?? ""
        case .kartenunterschrift:
            // Der Text steht am TAG: Eine Karte zeigt dessen Spur, und
            // einen Tag wechselt sie nie (ab 1.0.87).
            return tag?.kartentext ?? ""
        default:
            return ""
        }
    }

    // Die Datumszeile: erst eine eigene Beschriftung dieses Tages, sonst
    // der Stil des Buches. Bis 1.0.1 stand hier fest „Donnerstag, 4. Juni
    // 2026" — und war an keiner Stelle zu ändern.
    static func datumstext(_ tag: Reisetag, reise: Reise) -> String {
        if let eigener = tag.datumstext, !eigener.isEmpty { return eigener }
        let nummer = (reise.tage.firstIndex { $0.id == tag.id } ?? 0) + 1
        return reise.gestaltung.datumsstil.text(tag.datum, nummer: nummer)
    }

    static func schriftbild(_ block: Block, reise: Reise) -> Schriftbild {
        block.abweichung.angewendet(auf: reise.typografie[block.inhalt.rolle])
    }
}
