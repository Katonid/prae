import CoreGraphics
import Foundation
import PDFKit
import UIKit

// Eine Seite des fertigen Buches samt ihrem Zusammenhang. Die Titelseite
// gehört zu keinem Tag — deshalb ist `tag` freiwillig und nicht etwa ein
// erfundener leerer Tag, den dann jede Auswertung wieder aussortieren muss.
struct Buchseite: Identifiable {
    var id: UUID { seite.id }
    var seite: Seite
    var tag: Reisetag?
    var nummer: Int
}

extension Reise {
    // Ob auf DIESER Seite ein Wasserzeichen liegt — gefragt von der
    // Ansicht und vom PDF. Eine zweite Fassung dieser Prüfung ergäbe eine
    // Vorschau, die etwas anderes zeigt als der Druck.
    func wasserzeichen(fuer buchseite: Buchseite) -> Wasserzeichen? {
        guard let zeichen = gestaltung.wasserzeichen, zeichen.gueltig else { return nil }
        // Kein Tag heißt Titelblatt.
        if buchseite.tag == nil, !zeichen.aufTitelblatt { return nil }
        return zeichen
    }

    var automat: Layoutautomat {
        Layoutautomat(format: format, gestaltung: gestaltung, typografie: typografie,
                      stil: buchstil, fotoIndex: fotoIndex)
    }

    var seitenfolge: [Buchseite] {
        var folge: [Buchseite] = []
        var nummer = 1
        if titelseite {
            folge.append(Buchseite(
                seite: automat.titelseite(titel: titel, untertitel: untertitel,
                                          zeitraum: zeitraum, titelfoto: titelfoto),
                tag: nil,
                nummer: nummer
            ))
            nummer += 1
        }
        for tag in tage where !tag.ausgeblendet {
            for seite in tag.seiten {
                folge.append(Buchseite(seite: seite, tag: tag, nummer: nummer))
                nummer += 1
            }
        }
        return folge
    }
}

// Schreibt das Buch als PDF — druckfertig.
//
// Nicht über `UIGraphicsPDFRenderer`, sondern über einen `CGContext`
// unmittelbar. Der Unterschied ist genau eine Sache, und die entscheidet
// beim Druckdienst: Nur so lassen sich **TrimBox und BleedBox** setzen.
// Daran erkennt die Druckerei, wo das Endformat aufhört und wo der
// Anschnitt beginnt; ohne sie nimmt sie die Seite für das Endformat und
// schneidet drei Millimeter Bild weg.
enum Buchausgabe {
    enum Fehler: LocalizedError {
        case keineSeiten
        case schreibfehler(String)

        var errorDescription: String? {
            switch self {
            case .keineSeiten: return "Diese Reise hat noch keine Seiten."
            case let .schreibfehler(grund): return "Das PDF ließ sich nicht schreiben: \(grund)"
            }
        }
    }

    struct Auftrag {
        var bildkante: Int = 3600
        // Für Druckereien, die PDF/X-1a oder X-3 verlangen: Beide erlauben
        // keine Transparenz. Dann fallen Schatten weg, und der Verlauf
        // unter einer Überschrift wird zu einem geschlossenen Feld.
        var ohneTransparenz: Bool = false
        var nurUmschlag: Bool = false
        var ohneUmschlag: Bool = false
        // Nur für die Broschüre: Manche Drucker wenden über die kurze
        // Kante, dann steht die Rückseite auf dem Kopf. Welche Einstellung
        // gilt, weiß nur der Mensch davor.
        var rueckseitenDrehen: Bool = false
    }

    static func pdf(_ reise: Reise, auftrag: Auftrag = Auftrag(),
                    fortschritt: @escaping @MainActor (Double) -> Void) async throws -> URL
    {
        var gefiltert = reise.seitenfolge
        if auftrag.nurUmschlag { gefiltert = gefiltert.filter { $0.tag == nil } }
        if auftrag.ohneUmschlag { gefiltert = gefiltert.filter { $0.tag != nil } }
        guard !gefiltert.isEmpty else { throw Fehler.keineSeiten }
        // Ab hier unveränderlich: Eine `var`, die aus einem nebenläufigen
        // Abschluss gelesen wird, ist unter Swift 6 ein Fehler — und der
        // Grund dafür ist echt, nicht formal: Beim Fortschritt dürfte sich
        // die Liste zwischen zwei Meldungen nicht ändern.
        let seiten = gefiltert
        let anzahl = Double(seiten.count)

        let endformat = reise.format.groesse
        let anschnitt = reise.gestaltung.anschnittPt
        let bogen = reise.gestaltung.bogen(reise.format)

        // Die Kartenbilder werden VOR dem Zeichnen geholt. Der Schnappschuss
        // ist asynchron; mitten im PDF-Lauf darauf zu warten hieße, den
        // Zeichenkontext offen zu halten, während das Netz antwortet.
        // Dieselbe Schleife benutzt die Broschüre — zwei Fassungen liefen
        // auseinander, und dann hätte sie andere Karten als das Buch.
        let karten = await kartenbilder(seiten, reise: reise) { anteil in
            fortschritt(anteil * 0.45)
        }

        let ziel = FileManager.default.temporaryDirectory
            .appendingPathComponent(dateiname(reise, auftrag: auftrag))
        try? FileManager.default.removeItem(at: ziel)

        var medienbox = CGRect(origin: .zero, size: bogen)
        let angaben: [String: Any] = [
            kCGPDFContextTitle as String: reise.titel,
            kCGPDFContextCreator as String: "Urlaubstagebuch",
            kCGPDFContextSubject as String: reise.zeitraum,
        ]
        guard let abnehmer = CGDataConsumer(url: ziel as CFURL),
              let zusammenhang = CGContext(consumer: abnehmer, mediaBox: &medienbox,
                                           angaben as CFDictionary)
        else {
            throw Fehler.schreibfehler("Die Datei ließ sich nicht anlegen.")
        }

        // Die drei Boxen. Die TrimBox ist das Endformat, die BleedBox der
        // bedruckte Bogen. Beide werden als rohe `CGRect`-Bytes übergeben —
        // so verlangt es CoreGraphics, ein `NSValue` nimmt es nicht an.
        var trimbox = CGRect(x: anschnitt, y: anschnitt,
                             width: endformat.width, height: endformat.height)
        var bleedbox = medienbox
        let seiteninfo: [String: Any] = [
            kCGPDFContextMediaBox as String: Data(bytes: &medienbox,
                                                  count: MemoryLayout<CGRect>.size),
            kCGPDFContextTrimBox as String: Data(bytes: &trimbox,
                                                 count: MemoryLayout<CGRect>.size),
            kCGPDFContextBleedBox as String: Data(bytes: &bleedbox,
                                                  count: MemoryLayout<CGRect>.size),
        ]

        for (stelle, buchseite) in seiten.enumerated() {
            zusammenhang.beginPDFPage(seiteninfo as CFDictionary)
            zusammenhang.saveGState()
            // CoreGraphics zeichnet ein PDF von unten links, UIKit von oben
            // links. Einmal umdrehen, und danach gilt überall dieselbe
            // Rechnung wie auf dem Bildschirm.
            zusammenhang.translateBy(x: 0, y: bogen.height)
            zusammenhang.scaleBy(x: 1, y: -1)
            // Und dann in die Ecke des ENDFORMATS: Ab hier sind die
            // Koordinaten genau die, die im Modell stehen, und der
            // Anschnitt ist negativer Raum.
            zusammenhang.translateBy(x: anschnitt, y: anschnitt)

            UIGraphicsPushContext(zusammenhang)
            zeichneSeite(buchseite, reise: reise, karten: karten, auftrag: auftrag,
                         in: zusammenhang)
            UIGraphicsPopContext()

            zusammenhang.restoreGState()
            zusammenhang.endPDFPage()

            let anteil = 0.45 + Double(stelle + 1) / anzahl * 0.55
            await MainActor.run { fortschritt(anteil) }
        }
        zusammenhang.closePDF()
        await MainActor.run { fortschritt(1) }
        return ziel
    }

    // MARK: - Broschüre für den eigenen Drucker

    // ZWEI SEITEN AUF EINEN BOGEN, IN HEFTFOLGE (ab 1.0.27).
    //
    // Ansage des Nutzers, 09/2026: „Wenn dann noch die Möglichkeit besteht,
    // automatisch einen Buchdruck auswählen zu können, so dass die Seiten
    // des Dokumentes automatisch umsortiert werden, so dass ich eine
    // doppelseitige Broschüre drucken kann."
    //
    // Der Bogen ist doppelt so breit wie eine Seite: Zwei A5-Seiten
    // nebeneinander ergeben A4 quer. Gefaltet und in der Mitte geheftet
    // liegt daraus ein Heft in der Hand.
    //
    // **Die Reihenfolge ist keine Geschmacksfrage, sondern Buchbinderei.**
    // Bei `n` Seiten (auf ein Vielfaches von vier aufgefüllt) trägt der
    // Bogen `i` vorn `[n−1−2i | 2i]` und hinten `[2i+1 | n−2−2i]`. Bei vier
    // Seiten heißt das vorn `4|1` und hinten `2|3` — einmal gefaltet steht
    // die 1 vorn, dann 2, 3, 4. Wer das nachrechnen will, faltet ein Blatt.
    //
    // **Kein Anschnitt.** Ein Heimdrucker druckt nicht bis an die Kante,
    // und ein Anschnitt, den niemand wegschneidet, wäre ein Rand aus
    // abgeschnittenem Bild. Gezeichnet wird das Endformat; was darüber
    // hinausragt, wird beschnitten — sonst liefe ein randabfallendes Foto
    // in die Nachbarseite.
    //
    // **Leere Seiten sind echte leere Seiten.** Ein Heft hat immer ein
    // Vielfaches von vier; die fehlenden bleiben weiß, statt dass die
    // Reihenfolge verrutscht.
    static func broschuere(_ reise: Reise, auftrag: Auftrag = Auftrag(),
                           fortschritt: @escaping @MainActor (Double) -> Void)
        async throws -> URL
    {
        let alle = reise.seitenfolge
        guard !alle.isEmpty else { throw Fehler.keineSeiten }

        // Auf ein Vielfaches von vier auffüllen. `nil` heißt: leere Seite.
        var folge: [Buchseite?] = alle.map { $0 }
        while folge.count % 4 != 0 { folge.append(nil) }
        let n = folge.count

        var bogenfolge: [(links: Buchseite?, rechts: Buchseite?, rueckseite: Bool)] = []
        for i in 0 ..< (n / 4) {
            bogenfolge.append((folge[n - 1 - 2 * i], folge[2 * i], false))
            bogenfolge.append((folge[2 * i + 1], folge[n - 2 - 2 * i], true))
        }

        let end = reise.format.groesse
        let bogen = CGSize(width: end.width * 2, height: end.height)
        let anzahl = Double(bogenfolge.count)

        let karten = await kartenbilder(alle, reise: reise) { anteil in
            fortschritt(anteil * 0.45)
        }

        let ziel = FileManager.default.temporaryDirectory
            .appendingPathComponent(dateiname(reise, auftrag: auftrag, broschuere: true))
        try? FileManager.default.removeItem(at: ziel)

        var medienbox = CGRect(origin: .zero, size: bogen)
        let angaben: [String: Any] = [
            kCGPDFContextTitle as String: reise.titel + " \u{2014} Brosch\u{00FC}re",
            kCGPDFContextCreator as String: "Urlaubstagebuch",
            kCGPDFContextSubject as String: reise.zeitraum,
        ]
        guard let abnehmer = CGDataConsumer(url: ziel as CFURL),
              let zusammenhang = CGContext(consumer: abnehmer, mediaBox: &medienbox,
                                           angaben as CFDictionary)
        else {
            throw Fehler.schreibfehler("Die Datei ließ sich nicht anlegen.")
        }
        let seiteninfo: [String: Any] = [
            kCGPDFContextMediaBox as String: Data(bytes: &medienbox,
                                                  count: MemoryLayout<CGRect>.size),
        ]

        for (stelle, bogenseite) in bogenfolge.enumerated() {
            zusammenhang.beginPDFPage(seiteninfo as CFDictionary)
            zusammenhang.saveGState()
            zusammenhang.translateBy(x: 0, y: bogen.height)
            zusammenhang.scaleBy(x: 1, y: -1)

            // WENDEN ÜBER DIE KURZE KANTE dreht die Rückseite um 180 Grad.
            // Welche der beiden Einstellungen ein Drucker benutzt, weiß nur
            // der Mensch davor — deshalb ein Schalter und keine Annahme.
            if bogenseite.rueckseite, auftrag.rueckseitenDrehen {
                zusammenhang.translateBy(x: bogen.width, y: bogen.height)
                zusammenhang.rotate(by: .pi)
            }

            for (spalte, seite) in [bogenseite.links, bogenseite.rechts].enumerated() {
                guard let seite else { continue }
                zusammenhang.saveGState()
                zusammenhang.translateBy(x: Double(spalte) * end.width, y: 0)
                zusammenhang.clip(to: CGRect(origin: .zero, size: end))
                UIGraphicsPushContext(zusammenhang)
                zeichneSeite(seite, reise: reise, karten: karten, auftrag: auftrag,
                             in: zusammenhang)
                UIGraphicsPopContext()
                zusammenhang.restoreGState()
            }

            zusammenhang.restoreGState()
            zusammenhang.endPDFPage()
            let anteil = 0.45 + Double(stelle + 1) / anzahl * 0.55
            await MainActor.run { fortschritt(anteil) }
        }
        zusammenhang.closePDF()
        await MainActor.run { fortschritt(1) }
        return ziel
    }

    // Die Kartenbilder werden VOR dem Zeichnen geholt — für beide Ausgaben
    // dieselbe Schleife. Zwei Fassungen desselben Vorlaufs liefen
    // auseinander, und dann hätte die Broschüre andere Karten als das Buch.
    private static func kartenbilder(_ seiten: [Buchseite], reise: Reise,
                                     fortschritt: @escaping @MainActor (Double) -> Void)
        async -> [UUID: UIImage]
    {
        var karten: [UUID: UIImage] = [:]
        let anzahl = Double(max(seiten.count, 1))
        for (stelle, buchseite) in seiten.enumerated() {
            guard let tag = buchseite.tag else { continue }
            for block in buchseite.seite.bloecke where block.inhalt == .karte {
                let groesse = CGSize(width: max(block.rahmen.breite * 3, 60),
                                     height: max(block.rahmen.hoehe * 3, 60))
                let bild = await Kartenwerk.shared.bild(
                    punkte: tag.spur.map(\.koordinate),
                    groesse: groesse,
                    kartenbild: tag.kartenbild ?? reise.kartenbild,
                    linienfarbe: reise.akzent,
                    ausschnitt: tag.kartenausschnitt
                )
                if let bild { karten[block.id] = bild }
            }
            await MainActor.run { fortschritt(Double(stelle) / anzahl) }
        }
        return karten
    }

    static func dateiname(_ reise: Reise, auftrag: Auftrag,
                          broschuere: Bool = false) -> String {
        let roh = reise.titel.isEmpty ? "Reisetagebuch" : reise.titel
        let erlaubt = roh.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        let grund = erlaubt.isEmpty ? "Reisetagebuch" : erlaubt
        if broschuere { return grund + "-Broschuere.pdf" }
        if auftrag.nurUmschlag { return grund + "-Umschlag.pdf" }
        if auftrag.ohneUmschlag { return grund + "-Innenteil.pdf" }
        return grund + ".pdf"
    }

    // MARK: - Eine Seite

    static func zeichneSeite(_ buchseite: Buchseite, reise: Reise, karten: [UUID: UIImage],
                             auftrag: Auftrag, in zusammenhang: CGContext)
    {
        let endformat = reise.format.groesse
        let anschnitt = reise.gestaltung.anschnittPt
        let ecken = reise.gestaltung.eckenradiusPt
        // Der Maßstab für Schatten: Auf einem 30er-Buch darf ein Schatten
        // größer sein als auf einer Postkarte, sonst verschwindet er.
        let massstab = endformat.width / 600

        // Der Hintergrund läuft IMMER bis in den Anschnitt — eine Fläche,
        // die am Endformat aufhört, hätte nach dem Beschneiden genau den
        // weißen Faden, wegen dem es den Anschnitt gibt.
        let bogenrechteck = CGRect(x: -anschnitt, y: -anschnitt,
                                   width: endformat.width + 2 * anschnitt,
                                   height: endformat.height + 2 * anschnitt)
        var grund = buchseite.seite.hintergrund ?? reise.gestaltung.hintergrund
        if let eigenes = buchseite.seite.papier {
            grund.farbe = eigenes
            grund.art = .einfarbig
        }
        var grundbild: UIImage?
        if grund.art == .foto, let id = grund.fotoID, let foto = reise.foto(id) {
            grundbild = Bildarchiv.shared.fuerAusgabe(foto.datei, reise: reise.id,
                                                      kante: auftrag.bildkante)
        }
        // Geht das Hintergrundfoto über die Doppelseite, wird es in die
        // Fläche BEIDER Seiten gerechnet und hier die Hälfte davon
        // gezeichnet. Gerechnet wird das von derselben Funktion, die auch
        // die Ansicht fragt — zwei Fassungen ergäben eine Vorschau, in
        // der das Bild anders steht als im Druck.
        var bildflaeche: CGRect?
        if grund.art == .foto, grund.ueberDoppelseite {
            bildflaeche = Bogenlage.bildflaeche(nummer: buchseite.nummer,
                                                format: endformat, anschnitt: anschnitt)
        }
        Seitensatz.zeichneHintergrund(grund, rechteck: bogenrechteck, bild: grundbild,
                                      saat: buchseite.seite.id.saat,
                                      bildflaeche: bildflaeche, in: zusammenhang)

        // Das Wasserzeichen liegt über dem Hintergrund und unter allem
        // anderen. Ohne Transparenz fällt es WEG und wird nicht etwa
        // deckend gezeichnet: Ein undurchsichtiges Ahornblatt mitten auf
        // der Seite wäre keine abgeschwächte Fassung, sondern ein Fehler
        // im Buch. Dieselbe Entscheidung wie beim Schatten daneben — nur
        // dass der Verlauf dort zu einem geschlossenen Feld wird, weil er
        // etwas lesbar machen muss und dieses Zeichen nichts.
        if !auftrag.ohneTransparenz, let zeichen = reise.wasserzeichen(fuer: buchseite),
           let bild = Bildarchiv.shared.fuerAusgabe(zeichen.datei, reise: reise.id,
                                                    kante: auftrag.bildkante)
        {
            let satz = reise.gestaltung.satzspiegel(reise.format)
            let rechteck = Wasserzeichenlage.rechteck(zeichen, satz: satz,
                                                      seite: buchseite.seite)
            Seitensatz.zeichneWasserzeichen(bild, rechteck: rechteck,
                                            deckung: zeichen.deckung, in: zusammenhang)
        }

        for block in buchseite.seite.sortiert {
            let rechteck = block.rahmen.rect
            zusammenhang.saveGState()
            if block.drehung != 0 {
                zusammenhang.translateBy(x: rechteck.midX, y: rechteck.midY)
                zusammenhang.rotate(by: block.drehung * .pi / 180)
                zusammenhang.translateBy(x: -rechteck.midX, y: -rechteck.midY)
            }

            let wirkung = block.wirkung(reise.gestaltung)
            let randPt = Druckmass.pt(wirkung.fotorand)
            let traeger = Seitensatz.fotorandRechteck(rechteck, rand: randPt)
            if block.istFoto, !auftrag.ohneTransparenz {
                Seitensatz.zeichneSchatten(traeger, art: wirkung.schatten, massstab: massstab,
                                           eckenradius: ecken, in: zusammenhang)
            }
            if randPt > 0 {
                Seitensatz.zeichneFlaeche(traeger, farbe: .white, eckenradius: ecken,
                                          in: zusammenhang)
            }
            // Der Grund kommt aus der WIRKUNG: Er darf seit 1.0.12 auch
            // vom Buch vorgegeben sein. Dieselbe Quelle wie auf dem
            // Bildschirm — zwei Fassungen ergäben ein PDF, das anders
            // aussieht als die Vorschau.
            if let grund = wirkung.grund {
                Seitensatz.zeichneFlaeche(rechteck, farbe: grund.uiFarbe,
                                          eckenradius: ecken, in: zusammenhang)
            }

            switch block.inhalt {
            case .titel, .datum, .text, .bildunterschrift:
                let bild = Seitensatz.schriftbild(block, reise: reise)
                let text = Seitensatz.inhaltstext(block, tag: buchseite.tag, reise: reise)
                Seitensatz.zeichneText(text, bild: bild,
                                       rechteck: block.textrechteck(rechteck,
                                                                     rand: wirkung.textrand),
                                       in: zusammenhang, seitenhoehe: endformat.height)

            case .linie:
                let farbe = (block.rand ?? reise.akzent).uiFarbe.withAlphaComponent(0.55)
                Seitensatz.zeichneLinie(rechteck, farbe: farbe, in: zusammenhang)

            case .flaeche:
                break

            case .verlauf:
                Seitensatz.zeichneVerlauf(rechteck, opak: auftrag.ohneTransparenz,
                                          in: zusammenhang)

            case let .foto(id):
                if let foto = reise.foto(id),
                   let bild = Bildarchiv.shared.fuerAusgabe(foto.datei, reise: reise.id,
                                                            kante: auftrag.bildkante)
                {
                    Seitensatz.zeichneBild(bild, ausschnitt: block.ausschnitt,
                                           rechteck: rechteck, in: zusammenhang,
                                           eckenradius: ecken)
                }

            case .karte:
                if let bild = karten[block.id] {
                    if !auftrag.ohneTransparenz {
                        Seitensatz.zeichneSchatten(rechteck, art: wirkung.schatten,
                                                   massstab: massstab, eckenradius: ecken,
                                                   in: zusammenhang)
                    }
                    Seitensatz.zeichneBild(bild, ausschnitt: .voll, rechteck: rechteck,
                                           in: zusammenhang, eckenradius: ecken)
                } else {
                    // Keine Karte ist etwas anderes als eine leere Fläche.
                    // Wer das PDF ohne Netz erzeugt, soll im Buch sehen,
                    // wo sie hingehört hätte, statt zu rätseln.
                    Seitensatz.zeichneFlaeche(rechteck, farbe: UIColor(white: 0.93, alpha: 1),
                                              eckenradius: ecken, in: zusammenhang)
                    var hinweis = reise.typografie.bildunterschrift
                    hinweis.ausrichtung = .mitte
                    Seitensatz.zeichneText(
                        "Kartenbild fehlt", bild: hinweis,
                        rechteck: CGRect(x: rechteck.minX, y: rechteck.midY - 8,
                                         width: rechteck.width, height: 20),
                        in: zusammenhang, seitenhoehe: endformat.height)
                }
            }

            if let rand = wirkung.randfarbe, wirkung.randbreite > 0, block.inhalt != .linie {
                Seitensatz.zeichneRahmen(rechteck, farbe: rand.uiFarbe,
                                         breite: wirkung.randbreite, eckenradius: ecken,
                                         in: zusammenhang)
            }
            zusammenhang.restoreGState()
        }

        zeichneFusszeile(buchseite, reise: reise, in: zusammenhang)
    }

    // Seitenzahl und Kopfzeile gehören zum BUCH und nicht zum Tag — deshalb
    // sind sie keine Blöcke im Satz, wo jemand sie versehentlich verschöbe,
    // sondern werden beim Zeichnen jeder Seite ergänzt.
    static func zeichneFusszeile(_ buchseite: Buchseite, reise: Reise,
                                 in zusammenhang: CGContext)
    {
        let endformat = reise.format.groesse
        let satz = reise.gestaltung.satzspiegel(reise.format)
        var klein = reise.typografie.bildunterschrift
        klein.farbe = .leise

        if reise.gestaltung.seitenzahlen, !buchseite.seite.ohneSeitenzahl {
            klein.ausrichtung = .mitte
            let y = endformat.height - Druckmass.pt(reise.gestaltung.randUnten) * 0.6
            Seitensatz.zeichneText(
                "\(buchseite.nummer)", bild: klein,
                rechteck: CGRect(x: satz.minX, y: y, width: satz.width,
                                 height: klein.zeilenhoehe * 1.6),
                in: zusammenhang, seitenhoehe: endformat.height)
        }
        if reise.gestaltung.kopfzeile, !buchseite.seite.ohneSeitenzahl {
            var kopf = klein
            kopf.ausrichtung = .rechts
            kopf.versalien = true
            kopf.sperrung = 1.2
            let text = buchseite.tag?.datum.mittel ?? reise.titel
            let y = Druckmass.pt(reise.gestaltung.randOben) * 0.42
            Seitensatz.zeichneText(
                text, bild: kopf,
                rechteck: CGRect(x: satz.minX, y: y, width: satz.width,
                                 height: kopf.zeilenhoehe * 1.6),
                in: zusammenhang, seitenhoehe: endformat.height)
        }
    }
}
