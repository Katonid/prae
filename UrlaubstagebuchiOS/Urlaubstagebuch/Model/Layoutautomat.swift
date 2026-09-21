import CoreGraphics
import Foundation

// Wie eine Tagesseite grundsätzlich aufgebaut ist. Die App wählt das
// Muster selbst (nach Textlänge, Zahl der Fotos und dem Format der Bilder);
// der Nutzer kann es je Tag überschreiben. Ein Automat ohne Handbremse ist
// in einem Buch, das jemandem GEFALLEN soll, kein Angebot.
enum Seitenmuster: String, Codable, CaseIterable, Identifiable {
    case karteOben
    case karteSeitlich
    case bildZuerst
    case textZuerst
    case bilderbogen

    var id: String { rawValue }

    var name: String {
        switch self {
        case .karteOben: return "Karte als Band oben"
        case .karteSeitlich: return "Karte neben dem Text"
        case .bildZuerst: return "Großes Aufmacherfoto"
        case .textZuerst: return "Text zuerst"
        case .bilderbogen: return "Bilderbogen"
        }
    }

    var beschreibung: String {
        switch self {
        case .karteOben: return "Die Tagesstrecke liegt breit unter der Überschrift, darunter Text und Fotos."
        case .karteSeitlich: return "Text und Karte nebeneinander, die Fotos darunter."
        case .bildZuerst: return "Ein Foto über die volle Breite, danach Text und Karte."
        case .textZuerst: return "Der Text trägt die Seite, Karte und Fotos folgen."
        case .bilderbogen: return "Fast nur Bilder, der Text bleibt kurz."
        }
    }
}

// Eine Kachel ist alles, was in einer Fotoreihe stehen kann — ein Bild oder
// die Karte. Dass die Karte hier mitläuft statt einen Sonderweg zu haben,
// ist Absicht: Sonst müsste jede Reihenrechnung zweimal geschrieben werden,
// und die zweite Fassung wäre irgendwann die falsche.
private struct Kachel {
    var inhalt: Blockinhalt
    var verhaeltnis: Double
    var unterschrift: Double
}

struct Layoutautomat {
    var format: Seitenformat
    var gestaltung: Gestaltung
    var typografie: Typografie
    var fotoIndex: [UUID: Foto]

    private var satz: CGRect { gestaltung.satzspiegel(format) }
    private var fuge: Double { gestaltung.fuge }

    // MARK: - Titelseite

    func titelseite(titel: String, untertitel: String, zeitraum: String) -> Seite {
        var bloecke: [Block] = []
        let breite = satz.width
        var gross = typografie.titel
        gross.groesse = typografie.titel.groesse * 1.9
        gross.ausrichtung = .mitte
        let titelHoehe = Textmass.hoehe(titel, bild: gross, breite: breite)

        var unter = typografie.flieText
        unter.ausrichtung = .mitte
        unter.groesse = typografie.flieText.groesse * 1.25
        let untertext = [untertitel, zeitraum].filter { !$0.isEmpty }.joined(separator: "\n")
        let unterHoehe = untertext.isEmpty ? 0 : Textmass.hoehe(untertext, bild: unter, breite: breite)

        let gesamt = titelHoehe + (unterHoehe > 0 ? 26 + unterHoehe : 0)
        var y = satz.midY - gesamt / 2

        bloecke.append(Block(
            inhalt: .titel,
            rahmen: Rahmen(x: satz.minX, y: y, breite: breite, hoehe: titelHoehe),
            abweichung: Schriftabweichung(groesse: gross.groesse, ausrichtung: .mitte)
        ))
        y += titelHoehe + 14

        bloecke.append(Block(
            inhalt: .linie,
            rahmen: Rahmen(x: satz.midX - 60, y: y, breite: 120, hoehe: 1)
        ))
        y += 12

        if !untertext.isEmpty {
            bloecke.append(Block(
                inhalt: .text(untertext),
                rahmen: Rahmen(x: satz.minX, y: y, breite: breite, hoehe: unterHoehe),
                abweichung: Schriftabweichung(groesse: unter.groesse, ausrichtung: .mitte)
            ))
        }
        return Seite(bloecke: bloecke)
    }

    // MARK: - Musterwahl

    func musterVorschlag(text: String, fotos: [Foto], hatSpur: Bool) -> Seitenmuster {
        let zeichen = text.count
        if !hatSpur {
            return fotos.count >= 5 && zeichen < 400 ? .bilderbogen : .textZuerst
        }
        if fotos.isEmpty { return .karteOben }
        if zeichen > 1400 { return .karteSeitlich }
        if fotos.count >= 6 && zeichen < 500 { return .bilderbogen }
        // Ein querformatiges erstes Foto trägt eine Seite als Aufmacher; ein
        // hochkantes über die volle Breite wäre ein Turm und schöbe alles
        // andere auf die zweite Seite.
        if let erstes = fotos.first, erstes.seitenverhaeltnis > 1.2, zeichen < 1100 {
            return .bildZuerst
        }
        return .karteSeitlich
    }

    // MARK: - Tagesseiten

    func seiten(fuer tag: Reisetag) -> [Seite] {
        let fotos = tag.fotos.compactMap { fotoIndex[$0] }.filter { !$0.abgelegt }
        let karte = tag.karteZeigen && tag.hatSpur
        let muster = tag.muster ?? musterVorschlag(text: tag.text, fotos: fotos, hatSpur: karte)

        var seiten: [Seite] = []
        var bloecke: [Block] = []
        var y = satz.minY
        var offeneFotos = fotos
        var restText = tag.text.trimmingCharacters(in: .whitespacesAndNewlines)
        var karteOffen = karte

        // Kopf: Datumszeile, darunter die Überschrift. Beides zusammen, weil
        // ein Datum ohne seinen Titel eine verwaiste Zeile ist.
        let datumHoehe = typografie.datum.zeilenhoehe + 2
        bloecke.append(Block(
            inhalt: .datum,
            rahmen: Rahmen(x: satz.minX, y: y, breite: satz.width, hoehe: datumHoehe)
        ))
        y += datumHoehe + 3

        let titel = tag.ueberschrift.trimmingCharacters(in: .whitespacesAndNewlines)
        if !titel.isEmpty {
            let hoehe = Textmass.hoehe(titel, bild: typografie.titel, breite: satz.width)
            bloecke.append(Block(
                inhalt: .titel,
                rahmen: Rahmen(x: satz.minX, y: y, breite: satz.width, hoehe: hoehe)
            ))
            y += hoehe + 6
        }
        bloecke.append(Block(
            inhalt: .linie,
            rahmen: Rahmen(x: satz.minX, y: y, breite: satz.width, hoehe: 0.8)
        ))
        y += 14

        switch muster {
        case .bildZuerst:
            if let aufmacher = offeneFotos.first {
                offeneFotos.removeFirst()
                let hoehe = min(satz.width / aufmacher.seitenverhaeltnis, satz.height * 0.45)
                let breite = min(satz.width, hoehe * aufmacher.seitenverhaeltnis)
                bloecke.append(fotoblock(aufmacher, x: satz.minX + (satz.width - breite) / 2,
                                         y: y, breite: breite, hoehe: hoehe))
                y += hoehe + unterschriftHoehe(aufmacher, breite: breite) + fuge + 4
            }
            (bloecke, y, restText) = textSpalte(bloecke, y: y, breite: satz.width, text: restText)

        case .karteOben:
            if karteOffen {
                let hoehe = min(satz.width / 2.9, satz.height * 0.3)
                bloecke.append(karteBlock(x: satz.minX, y: y, breite: satz.width, hoehe: hoehe))
                y += hoehe + fuge + 4
                karteOffen = false
            }
            (bloecke, y, restText) = textSpalte(bloecke, y: y, breite: satz.width, text: restText)

        case .karteSeitlich:
            let karteBreite = karteOffen ? (satz.width * gestaltung.kartenanteil).rounded() : 0
            let textBreite = karteOffen ? satz.width - karteBreite - fuge * 1.6 : satz.width
            var karteUnten = y
            if karteOffen {
                let hoehe = karteBreite / 1.3
                bloecke.append(karteBlock(x: satz.maxX - karteBreite, y: y,
                                          breite: karteBreite, hoehe: hoehe))
                karteUnten = y + hoehe + fuge
                karteOffen = false
            }
            var textUnten = y
            (bloecke, textUnten, restText) = textSpalte(bloecke, y: y, breite: textBreite, text: restText)
            y = max(textUnten, karteUnten) + 4

        case .textZuerst:
            (bloecke, y, restText) = textSpalte(bloecke, y: y, breite: satz.width, text: restText)

        case .bilderbogen:
            // Beim Bilderbogen kommt der Text nur, wenn er kurz ist — sonst
            // stünde er als Mauer über den Bildern, und genau das soll dieses
            // Muster ja nicht.
            if !restText.isEmpty {
                let hoehe = Textmass.hoehe(restText, bild: typografie.flieText, breite: satz.width)
                if hoehe < satz.height * 0.22 {
                    bloecke.append(Block(
                        inhalt: .text(restText),
                        rahmen: Rahmen(x: satz.minX, y: y, breite: satz.width, hoehe: hoehe)
                    ))
                    y += hoehe + fuge + 4
                    restText = ""
                }
            }
        }

        // Karte und Fotos als Kacheln in Reihen. Eine noch offene Karte
        // läuft vorn mit, damit sie nicht allein auf der letzten Seite
        // landet, wo sie niemand mit dem Tag in Verbindung bringt.
        var kacheln: [Kachel] = []
        if karteOffen {
            kacheln.append(Kachel(inhalt: .karte, verhaeltnis: 1.3, unterschrift: 0))
        }
        for foto in offeneFotos {
            kacheln.append(Kachel(
                inhalt: .foto(foto.id),
                verhaeltnis: foto.seitenverhaeltnis,
                unterschrift: unterschriftHoehe(foto, breite: satz.width / 3)
            ))
        }

        let ziel = zielhoehe(fuer: kacheln.count)
        var offen = kacheln
        // Die Notbremse ist kein Schmuck: Kommt aus der Textteilung einmal
        // nichts zurück (ein einzelnes Wort, das breiter ist als die Seite),
        // liefe die Schleife ewig — und eine App, die beim Einlesen eines
        // Tagebuchs hängt, ist schlimmer als eine, die einen Absatz
        // abschneidet. Was übrig bleibt, meldet sie hinterher.
        var durchgaenge = 0
        while !offen.isEmpty || !restText.isEmpty {
            durchgaenge += 1
            if durchgaenge > 200 { break }
            if !restText.isEmpty {
                let platz = CGSize(width: satz.width, height: satz.maxY - y)
                if platz.height > typografie.flieText.zeilenhoehe * 3 {
                    let (kopf, rest) = Textmass.teilen(restText, bild: typografie.flieText, groesse: platz)
                    if kopf.isEmpty {
                        // Auf einer frischen Seite passt nichts hinein — dann
                        // hilft auch die nächste nicht.
                        restText = ""
                    } else {
                        let hoehe = Textmass.hoehe(kopf, bild: typografie.flieText, breite: satz.width)
                        bloecke.append(Block(
                            inhalt: .text(kopf),
                            rahmen: Rahmen(x: satz.minX, y: y, breite: satz.width, hoehe: hoehe)
                        ))
                        y += hoehe + fuge + 4
                        restText = rest
                    }
                }
                if !restText.isEmpty {
                    seiten.append(Seite(bloecke: bloecke))
                    bloecke = []
                    y = satz.minY
                    continue
                }
            }
            guard !offen.isEmpty else { break }
            let (reihe, hoehe, gestreckt) = naechsteReihe(offen, breite: satz.width, ziel: ziel)
            if y + hoehe > satz.maxY, !bloecke.isEmpty {
                seiten.append(Seite(bloecke: bloecke))
                bloecke = []
                y = satz.minY
                continue
            }
            var x = satz.minX
            for kachel in reihe {
                let breite = gestreckt * kachel.verhaeltnis
                switch kachel.inhalt {
                case let .foto(id):
                    if let foto = fotoIndex[id] {
                        bloecke.append(fotoblock(foto, x: x, y: y, breite: breite, hoehe: gestreckt))
                    }
                case .karte:
                    bloecke.append(karteBlock(x: x, y: y, breite: breite, hoehe: gestreckt))
                default:
                    break
                }
                x += breite + fuge
            }
            y += hoehe + fuge
            offen.removeFirst(reihe.count)
        }

        if !bloecke.isEmpty || seiten.isEmpty { seiten.append(Seite(bloecke: bloecke)) }
        return seiten
    }

    // MARK: - Bausteine

    private func fotoblock(_ foto: Foto, x: Double, y: Double, breite: Double, hoehe: Double) -> Block {
        Block(
            inhalt: .foto(foto.id),
            rahmen: Rahmen(x: x, y: y, breite: breite, hoehe: hoehe)
        )
    }

    private func karteBlock(x: Double, y: Double, breite: Double, hoehe: Double) -> Block {
        Block(inhalt: .karte, rahmen: Rahmen(x: x, y: y, breite: breite, hoehe: hoehe))
    }

    private func unterschriftHoehe(_ foto: Foto, breite: Double) -> Double {
        guard !foto.unterschrift.isEmpty else { return 0 }
        return Textmass.hoehe(foto.unterschrift, bild: typografie.bildunterschrift, breite: breite) + 3
    }

    // Der Rückgabetyp ist `CGFloat` und nicht `Double`, obwohl beide auf
    // diesen Geräten dasselbe sind: Bei einer TUPEL-Zuweisung rechnet Swift
    // die beiden nicht ineinander um, und `y` kommt aus einem `CGRect`.
    private func textSpalte(_ bloecke: [Block], y: CGFloat, breite: Double, text: String)
        -> ([Block], CGFloat, String)
    {
        guard !text.isEmpty else { return (bloecke, y, text) }
        var neue = bloecke
        let platz = CGSize(width: breite, height: satz.maxY - y)
        guard platz.height > typografie.flieText.zeilenhoehe * 2 else { return (bloecke, y, text) }
        let (kopf, rest) = Textmass.teilen(text, bild: typografie.flieText, groesse: platz)
        guard !kopf.isEmpty else { return (bloecke, y, text) }
        let hoehe = Textmass.hoehe(kopf, bild: typografie.flieText, breite: breite)
        neue.append(Block(
            inhalt: .text(kopf),
            rahmen: Rahmen(x: satz.minX, y: y, breite: breite, hoehe: hoehe)
        ))
        return (neue, y + hoehe + fuge + 4, rest)
    }

    // Wie hoch eine Fotoreihe im Regelfall werden soll. Wenige Bilder dürfen
    // groß stehen, viele müssen sich die Seite teilen — eine feste Höhe
    // machte aus zwei Fotos zwei Briefmarken und aus zwölf eine Tapete.
    private func zielhoehe(fuer anzahl: Int) -> Double {
        let teiler: Double
        switch anzahl {
        case 0, 1: teiler = 1.55
        case 2: teiler = 2.15
        case 3, 4: teiler = 2.75
        case 5...8: teiler = 3.2
        default: teiler = 3.7
        }
        return min(satz.width / teiler, satz.height * 0.52)
    }

    // Eine Reihe wird gefüllt, bis sie bei der Zielhöhe angekommen ist, und
    // dann auf die volle Satzbreite gestreckt. Das ist das Verfahren, mit
    // dem Fotobücher und Bildergalerien arbeiten: Alle Bilder einer Reihe
    // sind gleich hoch, die Reihe steht randbündig, und kein Bild wird
    // beschnitten, um in ein Raster zu passen.
    private func naechsteReihe(_ kacheln: [Kachel], breite: Double, ziel: Double)
        -> (reihe: [Kachel], hoehe: Double, bildhoehe: Double)
    {
        var reihe: [Kachel] = []
        var bildhoehe = ziel
        for kachel in kacheln {
            reihe.append(kachel)
            let summe = reihe.reduce(0.0) { $0 + $1.verhaeltnis }
            let hoehe = (breite - fuge * Double(reihe.count - 1)) / max(summe, 0.01)
            bildhoehe = hoehe
            if hoehe <= ziel { break }
        }
        // Die letzte Reihe kann deutlich zu hoch werden, wenn nur noch ein
        // einzelnes Bild übrig ist. Sie wird deshalb gedeckelt und steht
        // dann linksbündig, statt als Riese die Seite zu sprengen.
        let deckel = ziel * 1.45
        if bildhoehe > deckel { bildhoehe = deckel }
        let unten = reihe.map(\.unterschrift).max() ?? 0
        return (reihe, bildhoehe + unten, bildhoehe)
    }
}
