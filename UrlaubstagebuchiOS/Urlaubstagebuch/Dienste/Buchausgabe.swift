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
    var seitenfolge: [Buchseite] {
        var folge: [Buchseite] = []
        var nummer = 1
        if titelseite {
            let automat = Layoutautomat(format: format, gestaltung: gestaltung,
                                        typografie: typografie, fotoIndex: fotoIndex)
            folge.append(Buchseite(
                seite: automat.titelseite(titel: titel, untertitel: untertitel, zeitraum: zeitraum),
                tag: nil,
                nummer: nummer
            ))
            nummer += 1
        }
        for tag in tage {
            for seite in tag.seiten {
                folge.append(Buchseite(seite: seite, tag: tag, nummer: nummer))
                nummer += 1
            }
        }
        return folge
    }
}

// Schreibt das Buch als PDF.
//
// Der Text wird als TEXT gesetzt und nicht als Bild: Ein PDF, dessen Seiten
// abfotografiert sind, lässt sich nicht durchsuchen, nicht kopieren und
// wiegt das Zehnfache. Die Bilder werden auf eine Kante von 2400 Punkten
// gerechnet — das reicht für den Druck einer A4-Seite und lässt ein Buch
// mit zweihundert Fotos noch durch eine Mail passen.
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

    static func pdf(_ reise: Reise, bildkante: Int = 2400,
                    fortschritt: @escaping @MainActor (Double) -> Void) async throws -> URL
    {
        let seiten = reise.seitenfolge
        guard !seiten.isEmpty else { throw Fehler.keineSeiten }
        let format = reise.format.groesse

        // Die Kartenbilder werden VOR dem Zeichnen geholt. Der Schnappschuss
        // ist asynchron; mitten im PDF-Lauf darauf zu warten hieße, den
        // Zeichenkontext offen zu halten, während das Netz antwortet.
        var karten: [UUID: UIImage] = [:]
        for (stelle, buchseite) in seiten.enumerated() {
            guard let tag = buchseite.tag else { continue }
            for block in buchseite.seite.bloecke where block.inhalt == .karte {
                let groesse = CGSize(width: block.rahmen.breite * 2, height: block.rahmen.hoehe * 2)
                let bild = await Kartenwerk.shared.bild(
                    punkte: tag.spur.map(\.koordinate),
                    groesse: groesse,
                    stil: tag.kartenstil ?? reise.kartenstil,
                    linienfarbe: reise.linienfarbe,
                    ausschnitt: tag.kartenausschnitt
                )
                if let bild { karten[block.id] = bild }
            }
            await MainActor.run { fortschritt(Double(stelle) / Double(seiten.count) * 0.45) }
        }

        let ziel = FileManager.default.temporaryDirectory
            .appendingPathComponent(dateiname(reise))
        let zeichner = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: format))

        do {
            try zeichner.writePDF(to: ziel) { zusammenhang in
                for (stelle, buchseite) in seiten.enumerated() {
                    zusammenhang.beginPage()
                    zeichneSeite(buchseite, reise: reise, karten: karten,
                                 bildkante: bildkante, in: zusammenhang.cgContext)
                    let anteil = 0.45 + Double(stelle) / Double(seiten.count) * 0.55
                    Task { @MainActor in fortschritt(anteil) }
                }
            }
        } catch {
            throw Fehler.schreibfehler(error.localizedDescription)
        }
        await MainActor.run { fortschritt(1) }
        return ziel
    }

    static func dateiname(_ reise: Reise) -> String {
        let roh = reise.titel.isEmpty ? "Reisetagebuch" : reise.titel
        let erlaubt = roh.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        return (erlaubt.isEmpty ? "Reisetagebuch" : erlaubt) + ".pdf"
    }

    static func zeichneSeite(_ buchseite: Buchseite, reise: Reise, karten: [UUID: UIImage],
                             bildkante: Int, in zusammenhang: CGContext)
    {
        let format = reise.format.groesse
        let papier = (buchseite.seite.papier ?? reise.gestaltung.papier).uiFarbe
        zusammenhang.setFillColor(papier.cgColor)
        zusammenhang.fill(CGRect(origin: .zero, size: format))

        for block in buchseite.seite.sortiert {
            let rechteck = block.rahmen.rect
            zusammenhang.saveGState()
            if block.drehung != 0 {
                zusammenhang.translateBy(x: rechteck.midX, y: rechteck.midY)
                zusammenhang.rotate(by: block.drehung * .pi / 180)
                zusammenhang.translateBy(x: -rechteck.midX, y: -rechteck.midY)
            }
            if let grund = block.grund {
                zusammenhang.setFillColor(grund.uiFarbe.cgColor)
                UIBezierPath(roundedRect: rechteck,
                             cornerRadius: reise.gestaltung.eckenradius).fill()
            }

            switch block.inhalt {
            case .titel, .datum, .text:
                let bild = Seitensatz.schriftbild(block, reise: reise)
                let text = Seitensatz.inhaltstext(block, tag: buchseite.tag, reise: reise)
                Seitensatz.zeichneText(text, bild: bild, rechteck: rechteck,
                                       in: zusammenhang, seitenhoehe: format.height)

            case .linie:
                let farbe = (block.rand ?? Farbwert.leise).uiFarbe.withAlphaComponent(0.45)
                Seitensatz.zeichneLinie(rechteck, farbe: farbe, in: zusammenhang)

            case let .foto(id):
                if let foto = reise.foto(id),
                   let bild = Bildarchiv.shared.fuerAusgabe(foto.datei, reise: reise.id,
                                                            kante: bildkante)
                {
                    Seitensatz.zeichneBild(bild, ausschnitt: block.ausschnitt, rechteck: rechteck,
                                           in: zusammenhang,
                                           eckenradius: reise.gestaltung.eckenradius)
                    if !foto.unterschrift.isEmpty {
                        let bildschrift = block.abweichung
                            .angewendet(auf: reise.typografie.bildunterschrift)
                        let unten = CGRect(x: rechteck.minX, y: rechteck.maxY + 2,
                                           width: rechteck.width, height: bildschrift.zeilenhoehe * 3)
                        Seitensatz.zeichneText(foto.unterschrift, bild: bildschrift,
                                               rechteck: unten, in: zusammenhang,
                                               seitenhoehe: format.height)
                    }
                }

            case .karte:
                if let bild = karten[block.id] {
                    Seitensatz.zeichneBild(bild, ausschnitt: .voll, rechteck: rechteck,
                                           in: zusammenhang,
                                           eckenradius: reise.gestaltung.eckenradius)
                } else {
                    // Keine Karte ist etwas anderes als eine leere Fläche.
                    // Wer das PDF ohne Netz erzeugt, soll im Buch sehen,
                    // wo sie hingehört hätte, statt zu rätseln.
                    zusammenhang.setFillColor(UIColor.systemGray6.cgColor)
                    UIBezierPath(roundedRect: rechteck,
                                 cornerRadius: reise.gestaltung.eckenradius).fill()
                    var hinweis = reise.typografie.bildunterschrift
                    hinweis.ausrichtung = .mitte
                    Seitensatz.zeichneText(
                        "Kartenbild fehlt", bild: hinweis,
                        rechteck: CGRect(x: rechteck.minX, y: rechteck.midY - 8,
                                         width: rechteck.width, height: 20),
                        in: zusammenhang, seitenhoehe: format.height)
                }
            }

            if let rand = block.rand, block.randbreite > 0 {
                Seitensatz.zeichneRahmen(rechteck, farbe: rand.uiFarbe,
                                         breite: block.randbreite,
                                         eckenradius: reise.gestaltung.eckenradius,
                                         in: zusammenhang)
            }
            zusammenhang.restoreGState()
        }
    }
}
