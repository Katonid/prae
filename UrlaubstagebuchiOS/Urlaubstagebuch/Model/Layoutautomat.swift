import CoreGraphics
import Foundation

// Wie eine Tagesseite grundsätzlich aufgebaut ist. Die App wählt das
// Muster selbst (nach Textlänge, Zahl der Fotos, Format der Bilder und der
// Vorliebe des gewählten Stils); der Nutzer kann es je Tag überschreiben.
// Ein Automat ohne Handbremse ist in einem Buch, das jemandem GEFALLEN
// soll, kein Angebot.
enum Seitenmuster: String, Codable, CaseIterable, Identifiable {
    case vollbildAufmacher
    case halbseitig
    case album
    case karteOben
    case karteSeitlich
    case bildZuerst
    case textZuerst
    case bilderbogen

    var id: String { rawValue }

    var name: String {
        switch self {
        case .vollbildAufmacher: return "Bild über die ganze Seite"
        case .halbseitig: return "Bild über die halbe Seite"
        case .album: return "Eingeklebt"
        case .karteOben: return "Karte als Band oben"
        case .karteSeitlich: return "Karte neben dem Text"
        case .bildZuerst: return "Großes Aufmacherfoto"
        case .textZuerst: return "Text zuerst"
        case .bilderbogen: return "Bilderbogen"
        }
    }

    var beschreibung: String {
        switch self {
        case .vollbildAufmacher:
            return "Das erste Foto füllt die Seite bis über den Rand, Datum und Überschrift liegen darauf. Text und Bilder folgen auf der nächsten Seite."
        case .halbseitig:
            return "Ein Foto läuft über die halbe Seite bis an drei Kanten, daneben stehen Text und Karte."
        case .album:
            return "Bilder mit weißem Rand, leicht gedreht und einander überlappend — wie in ein Album geklebt."
        case .karteOben:
            return "Die Tagesstrecke liegt breit unter der Überschrift, darunter Text und Fotos."
        case .karteSeitlich:
            return "Text und Karte nebeneinander, die Fotos darunter."
        case .bildZuerst:
            return "Ein Foto über die volle Satzbreite, danach Text und Karte."
        case .textZuerst:
            return "Der Text trägt die Seite, Karte und Fotos folgen."
        case .bilderbogen:
            return "Fast nur Bilder, der Text bleibt kurz."
        }
    }

    // Läuft dieses Muster bis an die Papierkante? Ohne Anschnitt ist es
    // nicht zu haben — und in einem Stil, der keine randabfallenden Bilder
    // will, hat es nichts verloren.
    var brauchtAnschnitt: Bool {
        self == .vollbildAufmacher || self == .halbseitig
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
    var stil: Buchstil
    var fotoIndex: [UUID: Foto]

    private var satz: CGRect { gestaltung.satzspiegel(format) }
    private var fuge: Double { gestaltung.fugePt }
    private var bogen: CGRect { gestaltung.randabfallend(format) }

    // MARK: - Titelseite

    // Mit Titelfoto ist sie ein Plakat, ohne ein ruhiges Textblatt. Beides
    // ist richtig; was nicht geht, ist ein halbherziges Dazwischen — ein
    // kleines Bildchen über einem großen Titel sieht aus wie ein Entwurf.
    func titelseite(titel: String, untertitel: String, zeitraum: String,
                    titelfoto: UUID?) -> Seite
    {
        if let titelfoto, fotoIndex[titelfoto] != nil {
            return titelseiteMitBild(titel: titel, untertitel: untertitel,
                                     zeitraum: zeitraum, foto: titelfoto)
        }
        return titelseiteSchlicht(titel: titel, untertitel: untertitel, zeitraum: zeitraum)
    }

    private func titelseiteMitBild(titel: String, untertitel: String, zeitraum: String,
                                   foto: UUID) -> Seite
    {
        var bloecke: [Block] = []
        bloecke.append(Block(
            inhalt: .foto(foto),
            rahmen: Rahmen(bogen),
            randabfallend: true
        ))

        // Der Titel steht auf einem hellen Feld und nicht frei auf dem Bild.
        // Weiße Schrift auf einem Foto ist genau so lange lesbar, bis
        // jemand ein Bild mit hellem Himmel wählt — und dann ist es der
        // Titel des Buches, der verschwindet.
        let breite = satz.width * 0.72
        let x = satz.minX
        var gross = typografie.titel
        gross.groesse = typografie.titel.groesse * 1.35
        let titelHoehe = Textmass.hoehe(titel, bild: gross, breite: breite - 40)

        var unter = typografie.flieText
        unter.groesse = typografie.flieText.groesse * 1.15
        let untertext = [untertitel, zeitraum].filter { !$0.isEmpty }.joined(separator: "\n")
        let unterHoehe = untertext.isEmpty ? 0
            : Textmass.hoehe(untertext, bild: unter, breite: breite - 40)

        let feldHoehe = titelHoehe + (unterHoehe > 0 ? unterHoehe + 16 : 0) + 44
        let feldY = satz.maxY - feldHoehe

        bloecke.append(Block(
            inhalt: .flaeche,
            rahmen: Rahmen(x: x, y: feldY, breite: breite, hoehe: feldHoehe),
            grund: Farbwert(rot: stil.papier.rot, gruen: stil.papier.gruen,
                            blau: stil.papier.blau, deckung: 0.93)
        ))
        bloecke.append(Block(
            inhalt: .titel,
            rahmen: Rahmen(x: x + 22, y: feldY + 20, breite: breite - 44, hoehe: titelHoehe),
            abweichung: Schriftabweichung(groesse: gross.groesse)
        ))
        if unterHoehe > 0 {
            bloecke.append(Block(
                inhalt: .text(untertext),
                rahmen: Rahmen(x: x + 22, y: feldY + 20 + titelHoehe + 12,
                               breite: breite - 44, hoehe: unterHoehe),
                abweichung: Schriftabweichung(groesse: unter.groesse)
            ))
        }
        return Seite(bloecke: bloecke, ohneSeitenzahl: true)
    }

    private func titelseiteSchlicht(titel: String, untertitel: String,
                                    zeitraum: String) -> Seite
    {
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
            rahmen: Rahmen(x: satz.midX - 60, y: y, breite: 120, hoehe: 1),
            rand: stil.akzent
        ))
        y += 12
        if !untertext.isEmpty {
            bloecke.append(Block(
                inhalt: .text(untertext),
                rahmen: Rahmen(x: satz.minX, y: y, breite: breite, hoehe: unterHoehe),
                abweichung: Schriftabweichung(groesse: unter.groesse, ausrichtung: .mitte)
            ))
        }
        return Seite(bloecke: bloecke, ohneSeitenzahl: true)
    }

    // MARK: - Musterwahl

    // Gewählt wird aus der VORLIEBE des Stils, und zwar das erste Muster,
    // das zum Inhalt dieses Tages passt. Damit sieht ein Buch durchgehend
    // nach einer Handschrift aus, ohne dass alle Seiten gleich wären —
    // eine Liste erlaubter Muster je Stil ist der Unterschied zwischen
    // Abwechslung und Unruhe.
    func musterVorschlag(text: String, fotos: [Foto], hatSpur: Bool) -> Seitenmuster {
        let zeichen = text.count
        let anschnittGeht = gestaltung.anschnitt > 0.5 && stil.randabfallendErlaubt
        let quer = fotos.first.map { $0.seitenverhaeltnis > 1.15 } ?? false

        for muster in stil.musterVorliebe {
            if muster.brauchtAnschnitt, !anschnittGeht { continue }
            switch muster {
            case .vollbildAufmacher:
                // Ein Vollbild lohnt sich nur, wenn danach noch etwas kommt
                // und das Bild die Seite auch trägt.
                if fotos.count >= 3, zeichen > 200, quer { return muster }
            case .halbseitig:
                if fotos.count >= 2, zeichen > 150 { return muster }
            case .album:
                if fotos.count >= 3 { return muster }
            case .karteOben:
                if hatSpur, fotos.count <= 2 { return muster }
            case .karteSeitlich:
                if hatSpur, zeichen > 200 { return muster }
            case .bildZuerst:
                if quer, zeichen < 1400, !fotos.isEmpty { return muster }
            case .textZuerst:
                if zeichen > 600 || fotos.isEmpty { return muster }
            case .bilderbogen:
                if fotos.count >= 4 { return muster }
            }
        }
        if fotos.isEmpty { return .textZuerst }
        if hatSpur, zeichen > 200 { return .karteSeitlich }
        return .bilderbogen
    }

    // MARK: - Tagesseiten

    func seiten(fuer tag: Reisetag) -> [Seite] {
        let fotos = tag.fotos.compactMap { fotoIndex[$0] }.filter { !$0.abgelegt }
        let karte = tag.karteZeigen && tag.hatSpur
        let muster = tag.muster ?? musterVorschlag(text: tag.text, fotos: fotos, hatSpur: karte)

        var seiten: [Seite] = []
        var bloecke: [Block] = []
        var offeneFotos = fotos
        var restText = tag.text.trimmingCharacters(in: .whitespacesAndNewlines)
        var karteOffen = karte
        var y = satz.minY

        // Der Vollbild-Aufmacher bekommt eine EIGENE Seite. Text darauf zu
        // quetschen wäre der schlechtere Handel: Das Bild verlöre seine
        // Wirkung, und der Text läge auf einem unruhigen Grund.
        if muster == .vollbildAufmacher, let aufmacher = offeneFotos.first {
            offeneFotos.removeFirst()
            seiten.append(vollbildseite(aufmacher, tag: tag))
            bloecke = []
            y = satz.minY
            let kopf = kopfzeile(tag: tag, y: &y, knapp: true)
            bloecke.append(contentsOf: kopf)
        } else {
            bloecke.append(contentsOf: kopfzeile(tag: tag, y: &y, knapp: false))
        }

        switch muster {
        case .halbseitig:
            if let gross = offeneFotos.first {
                offeneFotos.removeFirst()
                // Das Bild läuft nach links, oben und unten bis über die
                // Kante; nur zur Textseite hin hat es einen Rand.
                let breite = format.groesse.width * 0.46
                bloecke.append(Block(
                    inhalt: .foto(gross.id),
                    rahmen: Rahmen(x: bogen.minX, y: bogen.minY,
                                   breite: breite - bogen.minX, hoehe: bogen.height),
                    randabfallend: true
                ))
                let textX = breite + Druckmass.pt(gestaltung.fuge * 2)
                let textBreite = satz.maxX - textX
                var textY = satz.minY
                // Auf dieser Seite steht der Kopf rechts neben dem Bild.
                bloecke.removeAll { $0.inhalt == .datum || $0.inhalt == .titel || $0.inhalt == .linie }
                bloecke.append(contentsOf: kopfzeile(tag: tag, y: &textY, knapp: false,
                                                     x: textX, breite: textBreite))
                var neu = bloecke
                (neu, textY, restText) = textSpalte(neu, y: textY, x: textX,
                                                    breite: textBreite, text: restText)
                bloecke = neu
                if karteOffen, textY + textBreite / 1.4 < satz.maxY {
                    let hoehe = textBreite / 1.4
                    bloecke.append(karteBlock(x: textX, y: textY, breite: textBreite, hoehe: hoehe))
                    textY += hoehe + fuge
                    karteOffen = false
                }
                y = textY
                // Was hier nicht mehr hinpasst, beginnt eine neue Seite.
                if !offeneFotos.isEmpty || !restText.isEmpty || karteOffen {
                    seiten.append(Seite(bloecke: bloecke))
                    bloecke = []
                    y = satz.minY
                }
            }

        case .album:
            (bloecke, y, restText) = textSpalte(bloecke, y: y, x: satz.minX,
                                                breite: satz.width, text: restText)
            let (albumbloecke, unten) = albumreihen(&offeneFotos, ab: y, karte: &karteOffen)
            bloecke.append(contentsOf: albumbloecke)
            y = unten

        case .bildZuerst:
            if let aufmacher = offeneFotos.first {
                offeneFotos.removeFirst()
                let hoehe = min(satz.width / aufmacher.seitenverhaeltnis, satz.height * 0.45)
                let breite = min(satz.width, hoehe * aufmacher.seitenverhaeltnis)
                bloecke.append(fotoblock(aufmacher, x: satz.minX + (satz.width - breite) / 2,
                                         y: y, breite: breite, hoehe: hoehe))
                y += hoehe + unterschriftHoehe(aufmacher, breite: breite) + fuge + 4
            }
            (bloecke, y, restText) = textSpalte(bloecke, y: y, x: satz.minX,
                                                breite: satz.width, text: restText)

        case .karteOben:
            if karteOffen {
                let hoehe = min(satz.width / 2.9, satz.height * 0.3)
                bloecke.append(karteBlock(x: satz.minX, y: y, breite: satz.width, hoehe: hoehe))
                y += hoehe + fuge + 4
                karteOffen = false
            }
            (bloecke, y, restText) = textSpalte(bloecke, y: y, x: satz.minX,
                                                breite: satz.width, text: restText)

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
            (bloecke, textUnten, restText) = textSpalte(bloecke, y: y, x: satz.minX,
                                                        breite: textBreite, text: restText)
            y = max(textUnten, karteUnten) + 4

        case .textZuerst, .vollbildAufmacher:
            (bloecke, y, restText) = textSpalte(bloecke, y: y, x: satz.minX,
                                                breite: satz.width, text: restText)

        case .bilderbogen:
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
        if muster != .album {
            let (weitere, gefuellt, uebrig) = reihenSetzen(
                offeneFotos, karte: karteOffen, bloecke: bloecke, ab: y, restText: restText)
            seiten.append(contentsOf: weitere)
            bloecke = gefuellt
            restText = uebrig
        }

        if !bloecke.isEmpty || seiten.isEmpty { seiten.append(Seite(bloecke: bloecke)) }
        return seiten
    }

    // MARK: - Bausteine

    private func vollbildseite(_ foto: Foto, tag: Reisetag) -> Seite {
        var bloecke: [Block] = []
        bloecke.append(Block(
            inhalt: .foto(foto.id),
            rahmen: Rahmen(bogen),
            randabfallend: true
        ))
        // Ein dunkler Verlauf am unteren Rand trägt die Schrift auch über
        // einem hellen Bild. Er ist kein Schmuck, sondern die Bedingung
        // dafür, dass die Überschrift überhaupt lesbar ist.
        let bandHoehe = satz.height * 0.42
        bloecke.append(Block(
            inhalt: .verlauf,
            rahmen: Rahmen(x: bogen.minX, y: bogen.maxY - bandHoehe,
                           breite: bogen.width, hoehe: bandHoehe),
            randabfallend: true
        ))
        var hell = Schriftabweichung()
        hell.farbe = Farbwert(rot: 1, gruen: 1, blau: 1)

        let titel = tag.ueberschrift.trimmingCharacters(in: .whitespacesAndNewlines)
        var titelbild = typografie.titel
        titelbild.farbe = Farbwert(rot: 1, gruen: 1, blau: 1)
        let titelHoehe = titel.isEmpty ? 0
            : Textmass.hoehe(titel, bild: titelbild, breite: satz.width * 0.8)
        let datumHoehe = typografie.datum.zeilenhoehe + 2
        var y = satz.maxY - titelHoehe - datumHoehe - 6

        var datumhell = hell
        datumhell.farbe = Farbwert(rot: 1, gruen: 0.93, blau: 0.86)
        bloecke.append(Block(
            inhalt: .datum,
            rahmen: Rahmen(x: satz.minX, y: y, breite: satz.width, hoehe: datumHoehe),
            abweichung: datumhell
        ))
        y += datumHoehe + 3
        if !titel.isEmpty {
            bloecke.append(Block(
                inhalt: .titel,
                rahmen: Rahmen(x: satz.minX, y: y, breite: satz.width * 0.8, hoehe: titelHoehe),
                abweichung: hell
            ))
        }
        return Seite(bloecke: bloecke, ohneSeitenzahl: true)
    }

    private func kopfzeile(tag: Reisetag, y: inout CGFloat, knapp: Bool,
                           x: CGFloat? = nil, breite: CGFloat? = nil) -> [Block]
    {
        var bloecke: [Block] = []
        let linksX = x ?? satz.minX
        let spaltenbreite = breite ?? satz.width

        let datumHoehe = typografie.datum.zeilenhoehe + 2
        bloecke.append(Block(
            inhalt: .datum,
            rahmen: Rahmen(x: linksX, y: y, breite: spaltenbreite, hoehe: datumHoehe)
        ))
        y += datumHoehe + 3

        // Auf der Fortsetzungsseite steht der Titel nicht noch einmal — er
        // stand schon groß auf dem Aufmacher, und zweimal gelesen wirkt er
        // wie ein Fehler im Satz.
        let titel = tag.ueberschrift.trimmingCharacters(in: .whitespacesAndNewlines)
        if !titel.isEmpty, !knapp {
            let hoehe = Textmass.hoehe(titel, bild: typografie.titel, breite: spaltenbreite)
            bloecke.append(Block(
                inhalt: .titel,
                rahmen: Rahmen(x: linksX, y: y, breite: spaltenbreite, hoehe: hoehe)
            ))
            y += hoehe + 6
        }
        bloecke.append(Block(
            inhalt: .linie,
            rahmen: Rahmen(x: linksX, y: y, breite: spaltenbreite, hoehe: 0.8),
            rand: stil.akzent
        ))
        y += 14
        return bloecke
    }

    // Eingeklebt: Bilder mit weißem Rand, jedes ein wenig anders gedreht,
    // einander überlappend.
    //
    // Der Dreh ist AUS DER KENNUNG gerechnet und nicht zufällig — sonst
    // stünde dasselbe Bild nach jedem Neuanordnen woanders, und der Satz
    // wäre nie zweimal derselbe. Die Grenze von vier Grad ist der
    // Unterschied zwischen „mit der Hand eingeklebt" und „schief".
    private func albumreihen(_ fotos: inout [Foto], ab: CGFloat,
                             karte: inout Bool) -> ([Block], CGFloat)
    {
        var bloecke: [Block] = []
        var y = ab
        let spalten = fotos.count >= 5 ? 3 : 2
        let breite = (satz.width - fuge * Double(spalten - 1)) / Double(spalten)
        var spalte = 0
        var reihenhoehe: CGFloat = 0

        var kacheln: [(inhalt: Blockinhalt, verhaeltnis: Double, foto: Foto?)] = []
        if karte {
            kacheln.append((.karte, 1.3, nil))
            karte = false
        }
        for foto in fotos { kacheln.append((.foto(foto.id), foto.seitenverhaeltnis, foto)) }
        fotos = []

        for kachel in kacheln {
            let hoehe = breite / max(kachel.verhaeltnis, 0.35)
            if y + hoehe > satz.maxY, spalte == 0 { break }
            let x = satz.minX + Double(spalte) * (breite + fuge)
            // Die Überlappung: Jede zweite Kachel rückt ein Stück nach oben
            // und über den Nachbarn. Die Drehung kommt aus der Kennung.
            let versatz = spalte % 2 == 1 ? -fuge * 1.6 : 0
            var block = Block(
                inhalt: kachel.inhalt,
                rahmen: Rahmen(x: x - (spalte > 0 ? fuge * 0.5 : 0), y: y + versatz,
                               breite: breite, hoehe: hoehe),
                drehung: drehwinkel(kachel.foto?.id),
                ebene: spalte,
                schatten: stil.schatten,
                fotorand: kachel.inhalt.istFoto ? stil.fotorand : 0
            )
            if !kachel.inhalt.istFoto { block.fotorand = 0 }
            bloecke.append(block)
            reihenhoehe = max(reihenhoehe, hoehe + abs(versatz))
            spalte += 1
            if spalte == spalten {
                spalte = 0
                y += reihenhoehe + fuge * 1.4
                reihenhoehe = 0
            }
        }
        if spalte > 0 { y += reihenhoehe + fuge }
        return (bloecke, y)
    }

    // Immer derselbe Winkel für dasselbe Bild — ein Satz, der sich bei
    // jedem Neuanordnen anders neigt, ist kein Satz, sondern ein Würfel.
    private func drehwinkel(_ id: UUID?) -> Double {
        guard let id else { return 0 }
        var wert: UInt64 = 0xcbf2_9ce4_8422_2325
        for teil in id.uuidString.utf8 {
            wert = (wert ^ UInt64(teil)) &* 0x1000_0000_01b3
        }
        let anteil = Double(wert % 1000) / 1000
        return (anteil - 0.5) * 4.2
    }

    private func reihenSetzen(_ fotos: [Foto], karte: Bool, bloecke eingang: [Block],
                              ab: CGFloat, restText: String)
        -> (fertig: [Seite], offen: [Block], rest: String)
    {
        var seiten: [Seite] = []
        var bloecke = eingang
        var y = ab
        var text = restText

        var kacheln: [Kachel] = []
        if karte {
            kacheln.append(Kachel(inhalt: .karte, verhaeltnis: 1.3, unterschrift: 0))
        }
        for foto in fotos {
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
        // liefe die Schleife ewig.
        var durchgaenge = 0
        while !offen.isEmpty || !text.isEmpty {
            durchgaenge += 1
            if durchgaenge > 200 { break }
            if !text.isEmpty {
                let platz = CGSize(width: satz.width, height: satz.maxY - y)
                if platz.height > typografie.flieText.zeilenhoehe * 3 {
                    let (kopf, rest) = Textmass.teilen(text, bild: typografie.flieText,
                                                       groesse: platz)
                    if kopf.isEmpty {
                        text = ""
                    } else {
                        let hoehe = Textmass.hoehe(kopf, bild: typografie.flieText,
                                                   breite: satz.width)
                        bloecke.append(Block(
                            inhalt: .text(kopf),
                            rahmen: Rahmen(x: satz.minX, y: y, breite: satz.width, hoehe: hoehe)
                        ))
                        y += hoehe + fuge + 4
                        text = rest
                    }
                }
                if !text.isEmpty {
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
        return (seiten, bloecke, text)
    }

    private func fotoblock(_ foto: Foto, x: Double, y: Double, breite: Double,
                           hoehe: Double) -> Block
    {
        Block(
            inhalt: .foto(foto.id),
            rahmen: Rahmen(x: x, y: y, breite: breite, hoehe: hoehe),
            schatten: stil.schatten,
            fotorand: stil.fotorand
        )
    }

    private func karteBlock(x: Double, y: Double, breite: Double, hoehe: Double) -> Block {
        Block(inhalt: .karte, rahmen: Rahmen(x: x, y: y, breite: breite, hoehe: hoehe),
              schatten: stil.schatten)
    }

    private func unterschriftHoehe(_ foto: Foto, breite: Double) -> Double {
        guard !foto.unterschrift.isEmpty else { return 0 }
        return Textmass.hoehe(foto.unterschrift, bild: typografie.bildunterschrift,
                              breite: breite) + 3
    }

    private func textSpalte(_ bloecke: [Block], y: CGFloat, x: CGFloat, breite: Double,
                            text: String) -> ([Block], CGFloat, String)
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
            rahmen: Rahmen(x: x, y: y, breite: breite, hoehe: hoehe)
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
    // dem Fotobücher arbeiten: Alle Bilder einer Reihe sind gleich hoch, die
    // Reihe steht randbündig, und kein Bild wird beschnitten, um in ein
    // Raster zu passen.
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
