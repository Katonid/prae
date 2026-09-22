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
    case wechsel

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
        case .wechsel: return "Nach Inhalt gesetzt"
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
        case .wechsel:
            return "Die App misst Text und Bilder dieses Tages und entscheidet daraus: wie viele Seiten er bekommt, wie beides darauf verteilt wird und wie jede einzelne Seite aussieht. Viel Text und wenige Bilder ergibt Bilder neben dem Text, viele Bilder und wenig Text auch einmal eine reine Bilderseite."
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

    var kennung: UUID? {
        if case let .foto(id) = inhalt { return id }
        return nil
    }
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
            case .wechsel:
                // Bis 1.0.33 stand hier eine hohe Schwelle (1200 Zeichen,
                // vier Fotos): Das Muster war die Antwort auf den einen
                // Fall „sehr viel Text mit ebenfalls sehr vielen Bildern".
                //
                // Seit 1.0.34 ist es kein Sonderfall mehr, sondern der
                // REGELFALL für jeden Tag, der Text UND Bilder hat — der
                // Planer dahinter kann beide Enden (siehe `Tagesplan`).
                // Genau daran scheiterte der 3. August im gemeldeten Buch:
                // ein Tag mit Text und EINEM Foto fiel durch diese Schwelle
                // und landete bei einem Muster, das das Bild allein auf
                // eine sonst leere Seite stellte.
                //
                // Ohne Text oder ohne Bild greift es nicht: Dann gibt es
                // nichts zu verteilen, und die eigenen Bildideen der
                // übrigen Muster sind die bessere Antwort.
                if zeichen > 250, !fotos.isEmpty || hatSpur { return muster }
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

        // NACH INHALT GESETZT (ab 1.0.34).
        //
        // Dieses Muster baut seine Seiten vollständig selbst und geht
        // deshalb weder durch den Musterschalter darunter noch durch
        // `reihenSetzen`. Der Grund ist der Befund des Nutzers: Ein Satz,
        // der sich nach dem Inhalt richtet, kann nicht als Sonderfall in
        // einer Kette gebaut werden, die Text und Bilder nacheinander
        // abarbeitet — er muss beide zugleich vor sich haben.
        if muster == .wechsel {
            var kacheln: [Kachel] = []
            if karteOffen {
                kacheln.append(Kachel(inhalt: .karte, verhaeltnis: 1.3, unterschrift: 0))
                karteOffen = false
            }
            for foto in offeneFotos {
                kacheln.append(Kachel(
                    inhalt: .foto(foto.id),
                    verhaeltnis: foto.seitenverhaeltnis,
                    unterschrift: unterschriftHoehe(foto, breite: satz.width / 3)
                ))
            }
            seiten.append(contentsOf: inhaltsseiten(kopf: bloecke, ab: y,
                                                    text: restText, kacheln: kacheln))
            return seiten
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
                let links = satz.minX + (satz.width - breite) / 2
                bloecke.append(fotoblock(aufmacher, x: links, y: y, breite: breite, hoehe: hoehe))
                if let zeile = unterschriftBlock(aufmacher, x: links, y: y + hoehe,
                                                 breite: breite)
                {
                    bloecke.append(zeile)
                }
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

        case .wechsel:
            // Oben abgefangen: Dieses Muster setzt `inhaltsseiten`, und das
            // baut den ganzen Tag selbst. Hier kommt es nie an.
            break

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

    // MARK: - Nach Inhalt gesetzt (ab 1.0.34)

    // Der ganze Tag auf einmal: erst messen, dann planen, dann Seite für
    // Seite füllen.
    //
    // Der Unterschied zu `reihenSetzen` ist nicht die Technik, sondern die
    // Reihenfolge. Dort wird ein Strom aus Text und Kacheln abgearbeitet
    // und die Seite ist das, was dabei herauskommt. Hier steht zuerst
    // fest, wie viel es insgesamt ist und auf wie viele Seiten es gehört;
    // erst danach entsteht die einzelne Seite, und zwar aus dem, was ihr
    // zugeteilt wurde. Nur so lässt sich überhaupt sagen, dass auf JEDER
    // Seite Text und Bilder stehen sollen.
    private func inhaltsseiten(kopf: [Block], ab: CGFloat, text eingang: String,
                               kacheln eingangKacheln: [Kachel]) -> [Seite]
    {
        var seiten: [Seite] = []
        var offen = eingangKacheln
        var text = eingang.trimmingCharacters(in: .whitespacesAndNewlines)
        let kopfhoehe = max(ab - satz.minY, 0)
        let textHoehe = text.isEmpty ? 0
            : Textmass.hoehe(text, bild: typografie.flieText, breite: satz.width)
        let bilderHoehe = offen.isEmpty ? 0
            : stapelhoehe(offen, breite: satz.width,
                          ziel: zielhoehe(fuer: offen.count), hub: 0)
        let plan = Tagesplan.bauen(textHoehe: textHoehe, bilderHoehe: bilderHoehe,
                                   kacheln: offen.count, kopf: kopfhoehe,
                                   satzhoehe: satz.height, fuge: fuge)

        var bloecke = kopf
        var y = ab
        var nummer = 0
        var restTextHoehe = textHoehe
        var durchgaenge = 0

        while !offen.isEmpty || !text.isEmpty {
            durchgaenge += 1
            // Dieselbe Notbremse wie in `reihenSetzen`, und aus demselben
            // Grund: Kommt aus der Textteilung einmal nichts zurück, liefe
            // die Schleife ewig. Was dann übrig ist, wird unten gesetzt —
            // ein Tagebuch darf keinen Satz verlieren.
            if durchgaenge > 120 { break }

            let platz = CGRect(x: satz.minX, y: y, width: satz.width,
                               height: satz.maxY - y)
            guard platz.height > typografie.flieText.zeilenhoehe * 3 else {
                seiten.append(Seite(bloecke: bloecke))
                bloecke = []
                y = satz.minY
                nummer += 1
                continue
            }
            let restSeiten = max(1, plan.seiten - nummer)
            // Wie viel Höhe der Text auf DIESER Seite bekommt. Der
            // Zuschlag von einem Viertel ist Absicht: Die Zahl der Seiten
            // ist eine Schätzung, und ein Text, der knapp gehalten wird,
            // schöbe am Ende einen Rest auf eine zusätzliche Seite.
            let textZiel: Double = restSeiten > 1
                ? min(restTextHoehe / Double(restSeiten) * 1.25, Double(platz.height))
                : Double(platz.height)
            let vorher = (offen.count, text.count)
            let neue = seiteFuellen(platz: platz, nummer: nummer, restSeiten: restSeiten,
                                    plan: plan, textZiel: textZiel,
                                    offen: &offen, text: &text)
            bloecke.append(contentsOf: neue)
            restTextHoehe = text.isEmpty ? 0
                : Textmass.hoehe(text, bild: typografie.flieText, breite: satz.width)
            if offen.isEmpty, text.isEmpty { break }
            // Ging auf einer leeren Seite gar nichts, passt der Rest
            // nirgends hin. Weiterblättern brauchte man dann nicht.
            if (offen.count, text.count) == vorher, neue.isEmpty { break }
            seiten.append(Seite(bloecke: bloecke))
            bloecke = []
            y = satz.minY
            nummer += 1
        }

        if !text.isEmpty {
            if !bloecke.isEmpty {
                seiten.append(Seite(bloecke: bloecke))
                bloecke = []
            }
            let hoehe = Textmass.hoehe(text, bild: typografie.flieText, breite: satz.width)
            bloecke.append(Block(
                inhalt: .text(text),
                rahmen: Rahmen(x: satz.minX, y: satz.minY, breite: satz.width, hoehe: hoehe)
            ))
        }
        if !bloecke.isEmpty || seiten.isEmpty { seiten.append(Seite(bloecke: bloecke)) }
        return seiten
    }

    // EINE Seite. Was sie bekommt, steht im Plan; WIE sie aussieht,
    // entscheidet `Seitenform.waehlen` aus dem, was auf ihr liegt.
    private func seiteFuellen(platz: CGRect, nummer: Int, restSeiten: Int,
                              plan: Tagesplan, textZiel: Double,
                              offen: inout [Kachel], text: inout String) -> [Block]
    {
        var bloecke: [Block] = []
        var y = platz.minY
        let zeilenhoehe = max(typografie.flieText.zeilenhoehe, 1)
        let anzahl = plan.kachelnAufSeite(offen: offen.count, restSeiten: restSeiten)
        var gruppe = Array(offen.prefix(anzahl))
        let erste = gruppe.first
        let textZeilen = text.isEmpty ? 0 : min(textZiel, Double(platz.height)) / zeilenhoehe
        let form = Seitenform.waehlen(
            gangart: plan.gangart, kacheln: gruppe.count, textZeilen: textZeilen,
            hochkant: erste.map { $0.verhaeltnis <= 0.92 } ?? false,
            quer: erste.map { $0.verhaeltnis >= 1.12 } ?? false,
            seite: nummer
        )

        switch form {
        case .nurText:
            (bloecke, y, text) = textSpalte(bloecke, y: y, x: platz.minX,
                                            breite: platz.width, text: text)

        case .nurBilder:
            let ziel = ausfuellendesZiel(gruppe, breite: platz.width,
                                         grund: zielhoehe(fuer: gruppe.count),
                                         platz: platz.maxY - y, hub: 0, textOffen: false)
            let kasten = CGRect(x: platz.minX, y: y, width: platz.width,
                                height: platz.maxY - y)
            let (neue, unten, rest) = reihenIn(kasten, kacheln: gruppe, ziel: ziel,
                                               verteilen: true)
            bloecke.append(contentsOf: neue)
            y = unten
            gruppe = rest

        case .band:
            // EIN BAND FOLGT DEM BILD (Befund des Nutzers zu Seite 5,
            // 09/2026: „ist ein Ausschnitt eines Fotos auf die ganze
            // Seitenbreite gezogen. Das macht keinen Sinn.").
            //
            // Bis 1.0.33 stand die Höhe fest bei knapp einem Drittel der
            // Satzhöhe und die Breite bei voller Satzbreite — ein
            // Hochformat wurde damit zu einem Streifen quer durch das
            // Bild. Gerechnet wird jetzt aus dem Seitenverhältnis, und
            // gedeckelt wird die HOEHE; was dabei an Breite fehlt, bleibt
            // Rand. Ein Band bekommt deshalb nur ein Querformat.
            if let kachel = gruppe.first {
                let hoehe = min(platz.width / max(kachel.verhaeltnis, 0.35),
                                platz.height * 0.40)
                let breite = hoehe * kachel.verhaeltnis
                let x = platz.minX + (platz.width - breite) / 2
                let (neue, unten) = kachelbloecke(kachel, x: x, y: y,
                                                  breite: breite, hoehe: hoehe)
                bloecke.append(contentsOf: neue)
                y += unten + fuge + 4
                gruppe.removeFirst()
            }
            (bloecke, y, text) = textSpalte(bloecke, y: y, x: platz.minX,
                                            breite: platz.width, text: text)

        case .seitlich:
            // EIN BILD NEBEN DEM TEXT, UND DER TEXT LAEUFT DARUNTER WEITER.
            //
            // Das ist die Antwort auf zwei Punkte des Nutzers zugleich: auf
            // Seite 6 („könnte zumindest eins der Fotos noch neben den Text
            // gezogen werden") und auf den dritten seiner drei Fälle („bei
            // sehr viel Text und wenig Bildern … dass der Text sie
            // umfließt").
            //
            // Umflossen wird in einem L: eine schmale Spalte neben dem Bild,
            // darunter die volle Breite. Ein Bild, das AUF BEIDEN Seiten
            // Text hat, ist bewusst nicht gebaut — dafür müsste jede Zeile
            // einzeln gesetzt werden (CoreText legt einen Rahmen in ein
            // Rechteck), und der Textblock wäre danach nicht mehr das, was
            // man in dieser App anfassen und verschieben kann. Zwei Blöcke
            // sind hier das ehrlichere Mittel: Sie messen und zeichnen mit
            // demselben Satz wie jeder andere Text.
            if let kachel = gruppe.first {
                let spalte = (platz.width * 0.40).rounded()
                let hoehe = min(spalte / max(kachel.verhaeltnis, 0.35),
                                platz.height * 0.46)
                let breite = hoehe * kachel.verhaeltnis
                let rechts = nummer % 2 == 0
                let bildX = rechts ? platz.maxX - breite : platz.minX
                let (neue, bildUnten) = kachelbloecke(kachel, x: bildX, y: y,
                                                      breite: breite, hoehe: hoehe)
                bloecke.append(contentsOf: neue)
                gruppe.removeFirst()

                let schmal = platz.width - breite - fuge * 1.6
                let schmalX = rechts ? platz.minX : platz.maxX - schmal
                var spaltenUnten = y
                (bloecke, spaltenUnten, text) = textSpalte(bloecke, y: y, x: schmalX,
                                                           breite: schmal, text: text,
                                                           hoechstens: bildUnten)
                y = max(y + bildUnten, spaltenUnten - fuge - 4) + fuge + 4

                if !text.isEmpty {
                    let reserve: Double = gruppe.isEmpty ? 0
                        : min(stapelhoehe(gruppe, breite: platz.width,
                                          ziel: zielhoehe(fuer: gruppe.count), hub: 0),
                              Double(platz.height) * 0.42) + fuge + 4
                    let uebrig = Double(platz.maxY - y) - reserve
                    if uebrig > zeilenhoehe * 2 {
                        (bloecke, y, text) = textSpalte(bloecke, y: y, x: platz.minX,
                                                        breite: platz.width, text: text,
                                                        hoechstens: uebrig)
                    }
                }
            }

        case .reihenOben:
            let fuerText = min(textZiel, Double(platz.height))
            var hoehe = Double(platz.height) - fuerText - fuge - 4
            hoehe = min(max(hoehe, Double(platz.height) * 0.28), Double(platz.height) * 0.66)
            let kasten = CGRect(x: platz.minX, y: y, width: platz.width, height: hoehe)
            let (neue, unten, rest) = reihenIn(kasten, kacheln: gruppe,
                                               ziel: zielhoehe(fuer: gruppe.count),
                                               verteilen: false)
            bloecke.append(contentsOf: neue)
            gruppe = rest
            if !neue.isEmpty { y = unten + fuge + 4 }
            (bloecke, y, text) = textSpalte(bloecke, y: y, x: platz.minX,
                                            breite: platz.width, text: text)

        case .reihenUnten:
            // DER TEXT BEKOMMT NICHT DIE GANZE SEITE, solange Bilder für
            // sie vorgesehen sind. Genau daran hing der gemeldete Fall vom
            // 3. August: Der Text lief bis zum Satzspiegelende, das eine
            // Foto passte nicht mehr und stand danach allein und riesig auf
            // der nächsten Seite.
            let reserve = min(stapelhoehe(gruppe, breite: platz.width,
                                          ziel: zielhoehe(fuer: gruppe.count), hub: 0),
                              Double(platz.height) * 0.55)
            let fuerText = max(min(textZiel, Double(platz.height) - reserve - fuge - 4),
                               zeilenhoehe * 3)
            (bloecke, y, text) = textSpalte(bloecke, y: y, x: platz.minX,
                                            breite: platz.width, text: text,
                                            hoechstens: fuerText)
            let kasten = CGRect(x: platz.minX, y: y, width: platz.width,
                                height: platz.maxY - y)
            let (neue, unten, rest) = reihenIn(kasten, kacheln: gruppe,
                                               ziel: zielhoehe(fuer: gruppe.count),
                                               verteilen: true)
            bloecke.append(contentsOf: neue)
            y = unten
            gruppe = rest
        }

        // Was von der Gruppe übrig ist, kommt noch unter das Gesetzte —
        // sonst wäre es stillschweigend auf die nächste Seite geschoben,
        // obwohl hier noch Platz ist.
        if !gruppe.isEmpty, Double(platz.maxY - y) > zeilenhoehe * 3 {
            let kasten = CGRect(x: platz.minX, y: y, width: platz.width,
                                height: platz.maxY - y)
            let (neue, unten, rest) = reihenIn(kasten, kacheln: gruppe,
                                               ziel: zielhoehe(fuer: gruppe.count),
                                               verteilen: true)
            bloecke.append(contentsOf: neue)
            y = unten
            gruppe = rest
        }

        let verbraucht = anzahl - gruppe.count
        if verbraucht > 0 { offen.removeFirst(verbraucht) }
        return bloecke
    }

    // Kacheln in Reihen, in einen gegebenen Kasten. Zurück kommen die
    // Blöcke, die erreichte Unterkante und die Kacheln, die nicht mehr
    // hineingingen.
    private func reihenIn(_ kasten: CGRect, kacheln: [Kachel], ziel: Double,
                          verteilen: Bool)
        -> (bloecke: [Block], unten: CGFloat, rest: [Kachel])
    {
        guard kasten.height > 8 else { return ([], kasten.minY, kacheln) }
        var bloecke: [Block] = []
        var reihen: [[UUID]] = []
        var offen = kacheln
        var y = kasten.minY

        while !offen.isEmpty {
            // Eine gestaffelte Reihe braucht oben und unten etwas Luft: Jede
            // zweite Kachel sitzt ein Stück höher und ist leicht gedreht.
            // Der Hub wird der Reihenhöhe ZUGERECHNET — sonst schöbe sich
            // die erste Kachel in die Zeile darüber.
            //
            // Gestaffelt wird nur in Stilen, die das vertragen, und nur ab
            // zwei Kacheln. Es ist die Antwort auf den Befund zu Seite 7
            // („sind plötzlich drei Fotos schnurgerade nebeneinander"):
            // Drei gleich hohe Bilder in einer Flucht sind ein Raster, kein
            // Satz.
            let hub: Double = stil.lebendig && offen.count > 1 ? fuge * 0.9 : 0
            var (reihe, hoehe, gestreckt) = naechsteReihe(offen, breite: kasten.width,
                                                          ziel: ziel)
            if y + hoehe + hub * 2 > kasten.maxY {
                // EINE REIHE SCHRUMPFT, BEVOR SIE UMBRICHT (ab 1.0.34).
                //
                // Bis 1.0.33 brach hier die Seite um, sobald die nächste
                // Reihe in ihrer Zielhöhe nicht mehr hineinpasste. Das war
                // der gemeldete Fall: „Das einzige Foto … erscheint nun
                // super gross auf einer leeren Seite 4. Dabei wäre auf
                // Seite 3 noch Platz gewesen. Es hätte dort fast in
                // derselben Größe Platz gefunden."
                //
                // Eine Reihe ist aber kein festes Mass — ihre Höhe folgt
                // aus der Zielhöhe, und die lässt sich für diese eine
                // Reihe senken. Erst wenn auch das nichts mehr hergibt,
                // bleibt der Umbruch.
                let rest = Double(kasten.maxY - y) - hub * 2
                guard rest >= min(ziel * 0.5, Double(satz.height) * 0.16) else { break }
                (reihe, hoehe, gestreckt) = naechsteReihe(offen, breite: kasten.width,
                                                          ziel: rest, hoechstens: rest)
                guard !reihe.isEmpty, hoehe <= rest + 0.5 else { break }
            }

            // Eine Reihe, die ihre Zielhöhe nicht erreicht, ist schmaler
            // als der Kasten. Sie steht dann MITTIG und nicht linksbündig:
            // Ein einzelnes Bild, das an der linken Kante klebt, sieht aus
            // wie der Rest einer Reihe.
            let breiten = reihe.map { gestreckt * $0.verhaeltnis }
            let gesamt = breiten.reduce(0, +) + fuge * Double(max(reihe.count - 1, 0))
            var x = kasten.minX + max(0, (kasten.width - gesamt) / 2)
            var kennungen: [UUID] = []
            for (stelle, kachel) in reihe.enumerated() {
                let breite = breiten[stelle]
                let versatz: Double = hub > 0 && stelle % 2 == 1 ? -hub : hub
                let (neue, _) = kachelbloecke(
                    kachel, x: x, y: y + versatz, breite: breite, hoehe: gestreckt,
                    gedreht: hub > 0 ? drehwinkel(kachel.kennung) * 0.7 : 0
                )
                bloecke.append(contentsOf: neue)
                kennungen.append(contentsOf: neue.map(\.id))
                x += breite + fuge
            }
            if !kennungen.isEmpty { reihen.append(kennungen) }
            y += hoehe + hub * 2 + fuge
            offen.removeFirst(reihe.count)
        }

        let unten = max(y - fuge, kasten.minY)
        guard verteilen else { return (bloecke, unten, offen) }
        return (restplatzVerteilen(bloecke, reihen: reihen, unten: unten, bis: kasten.maxY),
                unten, offen)
    }

    // Eine Kachel als Blöcke — Bild samt Unterschrift, oder die Karte.
    // Zurück kommt auch, wie hoch beides zusammen wird: Die Unterschrift
    // gehört zum Bild, und wer sie beim Weiterrücken vergisst, setzt den
    // nächsten Block darüber.
    private func kachelbloecke(_ kachel: Kachel, x: Double, y: Double, breite: Double,
                               hoehe: Double, gedreht: Double = 0) -> ([Block], Double)
    {
        var bloecke: [Block] = []
        var unten = hoehe
        switch kachel.inhalt {
        case let .foto(id):
            guard let foto = fotoIndex[id] else { return ([], 0) }
            var block = fotoblock(foto, x: x, y: y, breite: breite, hoehe: hoehe)
            block.drehung = gedreht
            bloecke.append(block)
            if let zeile = unterschriftBlock(foto, x: x, y: y + hoehe, breite: breite) {
                bloecke.append(zeile)
                unten += unterschriftHoehe(foto, breite: breite)
            }
        case .karte:
            bloecke.append(karteBlock(x: x, y: y, breite: breite, hoehe: hoehe))
        default:
            break
        }
        return (bloecke, unten)
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
            let block = Block(
                inhalt: kachel.inhalt,
                rahmen: Rahmen(x: x - (spalte > 0 ? fuge * 0.5 : 0), y: y + versatz,
                               breite: breite, hoehe: hoehe),
                drehung: drehwinkel(kachel.foto?.id),
                ebene: spalte
            )
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

    // Wie viele Zeilen Text mindestens übrig bleiben müssen, damit für eine
    // Fotoreihe auf derselben Seite Platz freigehalten wird. Gewählt, nicht
    // gemessen — siehe `reihenSetzen`.
    private static let mindestzeilenNebenFoto: Double = 6

    // Die durchgehend randbündige Form: Text über die volle Satzbreite,
    // darunter Fotoreihen. Sie gilt für die acht Muster, die je eine eigene
    // Bildidee tragen — ein Vollbild, eine Karte neben dem Text, ein
    // Bilderbogen. Der nach Inhalt gesetzte Tag (`.wechsel`) kommt hier
    // nicht mehr an; er baut seine Seiten in `inhaltsseiten` selbst.
    private func reihenSetzen(_ fotos: [Foto], karte: Bool, bloecke eingang: [Block],
                              ab: CGFloat, restText: String)
        -> (fertig: [Seite], offen: [Block], rest: String)
    {
        var seiten: [Seite] = []
        var bloecke = eingang
        var y = ab
        var text = restText
        let textBreite = satz.width
        let textX = satz.minX
        let reihenBreite = satz.width
        let reihenX = satz.minX

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

        let grundziel = zielhoehe(fuer: kacheln.count)
        var ziel = grundziel
        var offen = kacheln
        // Zu Beginn JEDER Seite neu gefragt: Passt alles, was noch offen
        // ist, auf diese eine Seite, dann dürfen die Reihen so weit
        // wachsen, dass sie die Seite füllen (siehe `ausfuellendesZiel`).
        func zielNachlegen() {
            ziel = ausfuellendesZiel(offen, breite: reihenBreite, grund: grundziel,
                                     platz: satz.maxY - y, hub: 0,
                                     textOffen: !text.isEmpty)
        }
        zielNachlegen()
        var reihenaufSeite: [[UUID]] = []
        // Die Notbremse ist kein Schmuck: Kommt aus der Textteilung einmal
        // nichts zurück (ein einzelnes Wort, das breiter ist als die Seite),
        // liefe die Schleife ewig.
        //
        // **Sie verlor bis 1.0.14 den Rest des Textes** (gefunden beim
        // Nachrechnen 09/2026): Ein nacktes `break` gibt `text` zurück, und
        // der Aufrufer setzt ihn nur in `restText` — danach wird er nirgends
        // mehr gesetzt. Damit wäre genau der Fehler zurück, der im ersten
        // gedruckten Stand einen Tag mitten im Satz enden ließ. Ein
        // Tagebuch darf keinen Satz verlieren: Was beim Abbruch übrig ist,
        // wird gesetzt und läuft notfalls sichtbar über.
        var durchgaenge = 0
        while !offen.isEmpty || !text.isEmpty {
            durchgaenge += 1
            if durchgaenge > 200 {
                if !text.isEmpty {
                    if !bloecke.isEmpty {
                        seiten.append(Seite(bloecke: bloecke))
                        bloecke = []
                        reihenaufSeite = []
                        y = satz.minY
                    }
                    let hoehe = Textmass.hoehe(text, bild: typografie.flieText,
                                               breite: textBreite)
                    bloecke.append(Block(
                        inhalt: .text(text),
                        rahmen: Rahmen(x: textX, y: y, breite: textBreite, hoehe: hoehe)
                    ))
                    text = ""
                }
                break
            }
            if !text.isEmpty {
                // Warten noch Fotos, bekommt der Text NICHT die ganze
                // Seite.
                //
                // Bis 1.0.13 füllte er sie: Ein Tag mit langem Text und
                // vielen Bildern ergab erst mehrere reine Textseiten und
                // danach reine Fotoseiten — das Bild zum Erzählten stand
                // drei Seiten weiter. Gewollt ist das andere (Ansage des
                // Nutzers, 09/2026: „Die Fotos werden dann drumherum
                // verteilt bzw. auch auf einer weiteren Seite
                // untergebracht, wenn sie in hoher Stückzahl auftreten.").
                //
                // Freigehalten wird die GEMESSENE Höhe der nächsten
                // Fotoreihe und kein geschätzter Anteil: `naechsteReihe`
                // rechnet sie ohnehin aus, und ein Anteil, der zu klein
                // ist, lässt die Reihe doch nicht hinein — dann bliebe
                // unten weißer Platz, den niemand bestellt hat. Passt nach
                // der Reihe kein halber Absatz Text mehr auf die Seite,
                // wird gar nichts freigehalten: Eine Seite mit vier Zeilen
                // über einem Bild ist kein Satz, sondern ein Rest.
                //
                // Gerechnet wird durchgehend in `CGFloat`: Hier ist ein
                // `CGRect` im Spiel, und die Umrechnung steht ausdrücklich
                // da, statt sie dem Übersetzer zu überlassen.
                let verbleibend = satz.maxY - y
                var freigehalten: CGFloat = 0
                var reiheZuerst = false
                if !offen.isEmpty {
                    let (_, reihenhoehe, _) = naechsteReihe(offen, breite: reihenBreite, ziel: ziel)
                    let braucht = CGFloat(reihenhoehe + fuge)
                    let bleibt = CGFloat(typografie.flieText.zeilenhoehe
                                         * Self.mindestzeilenNebenFoto)
                    if verbleibend - braucht > bleibt {
                        freigehalten = braucht
                    } else if verbleibend >= braucht {
                        // DER FREIGEHALTENE STREIFEN GEHÖRT DER REIHE (ab 1.0.31).
                        //
                        // Reicht die Resthöhe für eine Fotoreihe, aber nicht
                        // für Reihe UND sechs Zeilen Text, dann hielt das
                        // Muster `.wechsel` oben genau diesen Streifen frei —
                        // und hier wurde er wieder mit Text gefüllt, weil
                        // `freigehalten` in diesem Fall null ist. Das Ergebnis
                        // war die Seite, die der Nutzer gemeldet hat: oben ein
                        // voller Textblock, die Bilder eine Seite weiter.
                        //
                        // Wer Platz für ein Bild freihält, stellt das Bild
                        // auch hinein.
                        reiheZuerst = true
                    }
                }
                let platz = CGSize(width: textBreite, height: verbleibend - freigehalten)
                if !reiheZuerst, platz.height > typografie.flieText.zeilenhoehe * 3 {
                    let (kopf, rest) = Textmass.teilen(text, bild: typografie.flieText,
                                                       groesse: platz)
                    if kopf.isEmpty {
                        // Auf einer vollen Seite passt nichts mehr hinein —
                        // dann kommt der Rest auf die nächste. Ihn hier zu
                        // verwerfen war ein Fehler: Im ersten gedruckten
                        // Stand endete ein Tag mitten im Satz („mussten von
                        // Passagieren, die"), und der Rest war weg. Ein
                        // Tagebuch darf keinen Satz verlieren.
                        if bloecke.isEmpty {
                            // Selbst auf einer leeren Seite geht nichts: Dann
                            // ist die Schrift zu groß für die Seite. Der Text
                            // wird gesetzt und läuft sichtbar über, statt
                            // still zu verschwinden.
                            let hoehe = Textmass.hoehe(text, bild: typografie.flieText,
                                                       breite: textBreite)
                            bloecke.append(Block(
                                inhalt: .text(text),
                                rahmen: Rahmen(x: textX, y: y, breite: textBreite,
                                               hoehe: hoehe)
                            ))
                            text = ""
                        }
                    } else {
                        let hoehe = Textmass.hoehe(kopf, bild: typografie.flieText,
                                                   breite: textBreite)
                        bloecke.append(Block(
                            inhalt: .text(kopf),
                            rahmen: Rahmen(x: textX, y: y, breite: textBreite, hoehe: hoehe)
                        ))
                        y += hoehe + fuge + 4
                        text = rest
                    }
                }
                // Umgebrochen wird erst, wenn auch kein Foto mehr wartet.
                // Sonst füllt eine Fotoreihe den Rest dieser Seite, und
                // der Text geht darunter oder auf der nächsten weiter.
                if !text.isEmpty, offen.isEmpty {
                    seiten.append(Seite(bloecke: bloecke))
                    bloecke = []
                    reihenaufSeite = []
                    y = satz.minY
                    zielNachlegen()
                    continue
                }
            }
            guard !offen.isEmpty else { break }
            let (reihe, hoehe, gestreckt) = naechsteReihe(offen, breite: reihenBreite, ziel: ziel)
            if y + hoehe > satz.maxY, !bloecke.isEmpty {
                seiten.append(Seite(
                    bloecke: restplatzVerteilen(bloecke, reihen: reihenaufSeite,
                                                unten: y - fuge)))
                bloecke = []
                reihenaufSeite = []
                y = satz.minY
                zielNachlegen()
                continue
            }
            var x = reihenX
            var reihenbloecke: [UUID] = []
            for kachel in reihe {
                let breite = gestreckt * kachel.verhaeltnis
                switch kachel.inhalt {
                case let .foto(id):
                    if let foto = fotoIndex[id] {
                        let block = fotoblock(foto, x: x, y: y,
                                              breite: breite, hoehe: gestreckt)
                        bloecke.append(block)
                        reihenbloecke.append(block.id)
                        // Die Unterschrift steht UNTER dem Bild und in
                        // dessen Breite. Die Reihenhöhe hält den Platz
                        // dafür schon frei (`naechsteReihe`); hier wird er
                        // nur noch gefüllt.
                        if let zeile = unterschriftBlock(foto, x: x, y: y + gestreckt,
                                                         breite: breite)
                        {
                            bloecke.append(zeile)
                            // Sie gehört zur Reihe wie das Bild selbst:
                            // `restplatzVerteilen` schiebt die Reihen
                            // auseinander, und eine Unterschrift, die dabei
                            // liegen bliebe, stünde plötzlich im Bild
                            // darüber.
                            reihenbloecke.append(zeile.id)
                        }
                    }
                case .karte:
                    let block = karteBlock(x: x, y: y, breite: breite, hoehe: gestreckt)
                    bloecke.append(block)
                    reihenbloecke.append(block.id)
                default:
                    break
                }
                x += breite + fuge
            }
            if !reihenbloecke.isEmpty { reihenaufSeite.append(reihenbloecke) }
            y += hoehe + fuge
            offen.removeFirst(reihe.count)
        }
        bloecke = restplatzVerteilen(bloecke, reihen: reihenaufSeite, unten: y - fuge)
        return (seiten, bloecke, text)
    }

    // Was unten übrig bleibt, wird zwischen die Reihen gelegt.
    //
    // Der Anlass steht im ersten gedruckten Stand: Eine Seite trug drei
    // Fotos in einer Reihe und darunter die halbe Seite Weiß. Höher kann
    // eine randbündige Reihe nicht werden — ihre Höhe ergibt sich aus der
    // Satzbreite geteilt durch die Summe der Seitenverhältnisse. Was geht,
    // ist den Rest zu VERTEILEN, statt ihn unten liegen zu lassen: Luft
    // zwischen den Reihen sieht nach Absicht aus, Luft am Fuß nach
    // Abbruch.
    //
    // Gedeckelt auf das Dreifache der Fuge. Ohne Deckel schwömmen zwei
    // Bilder mit zehn Zentimetern Abstand auf der Seite, und das ist kein
    // Satz mehr, sondern ein Versehen in die andere Richtung.
    private func restplatzVerteilen(_ bloecke: [Block], reihen: [[UUID]],
                                    unten: CGFloat, bis: CGFloat? = nil) -> [Block]
    {
        guard reihen.count >= 1, unten > satz.minY else { return bloecke }
        // `bis` ist die Unterkante des Kastens, in dem die Reihen stehen.
        // Ohne sie gälte immer der Satzspiegel — und eine Reihe ÜBER einem
        // Textblock schöbe sich beim Verteilen in den Text hinein.
        let rest = (bis ?? satz.maxY) - unten
        guard rest > fuge else { return bloecke }
        // Die Lücken: zwischen den Reihen, und eine halbe am Fuß, damit der
        // Block nicht an der Unterkante klebt.
        let lücken = Double(reihen.count - 1) + 0.5
        guard lücken > 0.4 else { return bloecke }
        let jeLücke = min(rest / lücken, fuge * 3)
        guard jeLücke > 1 else { return bloecke }

        var ergebnis = bloecke
        for (nummer, reihe) in reihen.enumerated() where nummer > 0 {
            let versatz = jeLücke * Double(nummer)
            for id in reihe {
                guard let stelle = ergebnis.firstIndex(where: { $0.id == id }) else { continue }
                ergebnis[stelle].rahmen.y += versatz
            }
        }
        return ergebnis
    }

    private func fotoblock(_ foto: Foto, x: Double, y: Double, breite: Double,
                           hoehe: Double) -> Block
    {
        // Ohne Schatten und ohne weißen Rand: Beides steht am BUCH
        // (`Gestaltung.fotoschatten`, `.fotorand`) und wird beim Zeichnen
        // aufgelöst. Schriebe der Automat sie hier hinein, wäre die
        // Einstellung des Buches für alle schon gesetzten Fotos wirkungslos.
        Block(
            inhalt: .foto(foto.id),
            rahmen: Rahmen(x: x, y: y, breite: breite, hoehe: hoehe)
        )
    }

    private func karteBlock(x: Double, y: Double, breite: Double, hoehe: Double) -> Block {
        Block(inhalt: .karte, rahmen: Rahmen(x: x, y: y, breite: breite, hoehe: hoehe),
              schatten: stil.schatten == .keiner ? nil : stil.schatten)
    }

    // Nur wo sie eingeschaltet IST, kostet sie Platz. Bis 1.0.4 rechnete
    // der Automat den Streifen für jeden Text mit und setzte trotzdem nie
    // eine Unterschrift — die Lücke unter dem Bild war da, der Satz nicht.
    private func unterschriftHoehe(_ foto: Foto, breite: Double) -> Double {
        guard foto.unterschriftZeigen else { return 0 }
        let text = foto.unterschrift.isEmpty ? "Bildunterschrift" : foto.unterschrift
        return Textmass.hoehe(text, bild: typografie.bildunterschrift, breite: breite) + 3
    }

    // Der Block dazu — leer heißt kein Block: Ein Kasten ohne Text wäre auf
    // der Seite unsichtbar und ließe sich doch anfassen.
    private func unterschriftBlock(_ foto: Foto, x: Double, y: Double,
                                   breite: Double) -> Block?
    {
        let hoehe = unterschriftHoehe(foto, breite: breite)
        guard hoehe > 0 else { return nil }
        return Block(inhalt: .bildunterschrift(foto.id),
                     rahmen: Rahmen(x: x, y: y + 3, breite: breite, hoehe: hoehe - 3))
    }

    // `hoechstens` deckelt die Höhe des Textes auf dieser Seite. Ohne
    // Deckel füllt er bis zum Satzspiegelende — richtig für ein Muster,
    // das den Text trägt, falsch für eines, das ihn mit Bildern abwechseln
    // soll (`.wechsel`, ab 1.0.29).
    private func textSpalte(_ bloecke: [Block], y: CGFloat, x: CGFloat, breite: Double,
                            text: String, hoechstens: Double? = nil)
        -> ([Block], CGFloat, String)
    {
        guard !text.isEmpty else { return (bloecke, y, text) }
        var neue = bloecke
        let raum = min(satz.maxY - y, hoechstens ?? .greatestFiniteMagnitude)
        let platz = CGSize(width: breite, height: raum)
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

    // Wie hoch alles Offene zusammen wird, wenn es in Reihen dieser
    // Zielhöhe gesetzt wird: die Reihenhöhen samt Staffelhub, dazu die
    // Fugen dazwischen. Gerechnet wird mit derselben Funktion, die auch
    // setzt (`naechsteReihe`) — eine zweite Schätzung daneben liefe
    // auseinander, und dann hielte die Seite nicht, was die Probe sagt.
    private func stapelhoehe(_ kacheln: [Kachel], breite: Double, ziel: Double,
                             hub: Double) -> Double
    {
        var offen = kacheln
        var summe: Double = 0
        var reihen = 0
        while !offen.isEmpty, reihen < 60 {
            let (reihe, hoehe, _) = naechsteReihe(offen, breite: breite, ziel: ziel)
            guard !reihe.isEmpty else { break }
            summe += hoehe + hub * 2
            reihen += 1
            offen.removeFirst(reihe.count)
        }
        return summe + fuge * Double(max(reihen - 1, 0))
    }

    // DIE LETZTE SEITE EINES TAGES WAR DIE VERSCHENKTE (ab 1.0.32).
    //
    // `zielhoehe` rechnet allein aus der ZAHL der Kacheln und sieht die
    // Seite nie an. Solange viele Bilder warten, ist das richtig — die
    // nächste Reihe füllt ohnehin nach. Auf der letzten Seite eines Tages
    // warten aber oft nur noch zwei oder drei: Eine Reihe steht oben, und
    // darunter bleibt die halbe Seite weiß. `restplatzVerteilen` hilft
    // dort nicht — es verteilt die Lücken ZWISCHEN den Reihen, und bei
    // einer einzigen Reihe gibt es keine.
    //
    // Vergrößert wird deshalb nur, wenn ALLES Offene auf diese eine Seite
    // passt und kein Text mehr wartet. Solange noch Text kommt, gehört der
    // Platz ihm; und passt nicht alles, füllt die nächste Reihe die Seite
    // ohnehin.
    //
    // Gesucht wird in Schritten und nicht gerechnet: Eine größere Zielhöhe
    // nimmt Kacheln aus den Reihen heraus und kann damit eine Reihe MEHR
    // ergeben — der Zusammenhang ist nicht monoton, eine geschlossene
    // Formel gäbe es dafür nicht. Gehalten wird der letzte Wert, der
    // nachweislich passte.
    private func ausfuellendesZiel(_ offen: [Kachel], breite: Double, grund: Double,
                                   platz: Double, hub: Double,
                                   textOffen: Bool) -> Double
    {
        guard !textOffen, !offen.isEmpty, platz > grund else { return grund }
        guard stapelhoehe(offen, breite: breite, ziel: grund, hub: hub) <= platz
        else { return grund }
        let deckel = min(grund * 2.2, satz.height * 0.52)
        var beste = grund
        var versuch = grund
        while versuch < deckel {
            versuch = min(versuch * 1.05, deckel)
            guard stapelhoehe(offen, breite: breite, ziel: versuch, hub: hub) <= platz
            else { break }
            beste = versuch
        }
        return beste
    }

    // Eine Reihe wird gefüllt, bis sie bei der Zielhöhe angekommen ist, und
    // dann auf die volle Satzbreite gestreckt. Das ist das Verfahren, mit
    // dem Fotobücher arbeiten: Alle Bilder einer Reihe sind gleich hoch, die
    // Reihe steht randbündig, und kein Bild wird beschnitten, um in ein
    // Raster zu passen.
    // `hoechstens` ist die HARTE Obergrenze für die ganze Reihe samt
    // Unterschrift. Sie ist der Unterschied zwischen „die Reihe passt
    // nicht mehr, also neue Seite" und „die Reihe wird eben kleiner" —
    // siehe `reihenIn`.
    private func naechsteReihe(_ kacheln: [Kachel], breite: Double, ziel: Double,
                               hoechstens: Double? = nil)
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
        let unten = reihe.map(\.unterschrift).max() ?? 0
        var deckel = ziel * 1.45
        if let hoechstens { deckel = min(deckel, hoechstens - unten) }
        if bildhoehe > deckel { bildhoehe = max(deckel, 1) }
        return (reihe, bildhoehe + unten, bildhoehe)
    }
}
