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

    // EINE EINGESCHALTETE UNTERSCHRIFT OHNE TEXT (ab 1.0.36).
    //
    // Gemeldet 09/2026: „an manchen Stellen steht Text, der wie eine
    // Regieanweisung wirkt. Ich weiß nicht, wo das herkommt." Bis 1.0.35
    // stand unter einem solchen Foto das Wort „Bildunterschrift …" — und
    // dorthin kommt es durch einen DOPPELTIPP auf das Bild, also durch
    // denselben Griff, mit dem man Text bearbeitet.
    //
    // Das Wort ist weg (`SeitenflaecheView`), der Block ist es nicht: Er
    // hält weiterhin eine Zeile Platz unter dem Foto frei, und im Druck ist
    // das eine leere Zeile, die niemand bestellt hat. Also wird gezählt,
    // gesagt, wo es steht, und ein Weg genannt, es loszuwerden — ein
    // Hinweis ohne Ausweg ist die Frage von vorhin noch einmal.
    static func leereUnterschriften(_ reise: Reise) -> [Zeile] {
        var treffer: [String] = []
        for tag in reise.tage {
            for (nummer, seite) in tag.seiten.enumerated() {
                for block in seite.bloecke {
                    guard case let .bildunterschrift(id) = block.inhalt,
                          let foto = reise.foto(id),
                          foto.unterschrift.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    else { continue }
                    treffer.append("\(tag.datum.mittel), Seite \(nummer + 1)")
                }
            }
        }
        guard !treffer.isEmpty else { return [] }
        return [Zeile(
            stufe: .hinweis,
            titel: "\(treffer.count)\u{00D7} Bildunterschrift eingeschaltet, aber leer",
            text: "Unter diesen Fotos bleibt eine Zeile frei, in der nichts steht. So etwas entsteht durch einen Doppeltipp auf ein Foto \u{2014} der schaltet die Unterschrift ein. Entweder etwas hineinschreiben, oder alle auf einmal abschalten: \u{201E}\u{2026}\u{201C} oben rechts \u{2192} \u{201E}Leere Bildunterschriften abschalten\u{201C}.\n"
                + treffer.prefix(12).joined(separator: "\n")
        )]
    }

    // WIE UNTERSCHIEDLICH GROSS DIE FOTOS EINES TAGES SIND (ab 1.0.42).
    //
    // Der Befund des Nutzers, 09/2026: Einige Fotos stünden riesengroß auf
    // der Seite, während andere dort, wo der Text noch mit im Spiel ist, ein
    // Bruchteil dieser Größe hätten; das sei nicht ausgewogen.
    //
    // Nachgerechnet an der Geometrie: Die Höhe einer randbündigen Reihe ist
    // Satzbreite geteilt durch die Summe der Seitenverhältnisse. Auf A4 mit
    // den Vorgaberändern (Satz 178 x 261 mm) wird ein Hochformat ALLEIN in
    // seiner Reihe 237 mm hoch, also 91 Prozent der Satzhöhe; dasselbe Foto
    // zu dritt misst 45 mm. Der Faktor zwischen beiden ist 5,3 — und welcher
    // der beiden Fälle eintrat, hing bis 1.0.41 allein daran, wie viele
    // Kacheln zufällig auf der Seite gelandet waren.
    //
    // Seit 1.0.42 gibt es eine Zielhöhe je Tag und einen Deckel darüber. Ob
    // das reicht, sagt nicht der Quelltext, sondern diese Zeile: Sie misst am
    // fertigen Satz, wie weit größtes und kleinstes Foto eines Tages
    // auseinanderliegen. Eine Zusage ist sie nicht — sie ist die Messung, an
    // der sich der nächste Befund prüfen lässt.
    static func bildgroessen(_ reise: Reise) -> [Zeile] {
        let satzhoehe = Double(reise.gestaltung.satzspiegel(reise.format).height)
        var schlimmster: (tag: String, klein: Double, gross: Double)?
        var hoechstes: (tag: String, hoehe: Double)?
        for tag in reise.tage {
            var hoehen: [Double] = []
            for seite in tag.seiten {
                for block in seite.bloecke {
                    guard case .foto = block.inhalt else { continue }
                    hoehen.append(block.rahmen.hoehe)
                }
            }
            guard let klein = hoehen.min(), let gross = hoehen.max(), klein > 1 else { continue }
            if hoechstes == nil || gross > hoechstes!.hoehe {
                hoechstes = (tag.datum.mittel, gross)
            }
            if let bisher = schlimmster {
                if gross / klein > bisher.gross / bisher.klein {
                    schlimmster = (tag.datum.mittel, klein, gross)
                }
            } else {
                schlimmster = (tag.datum.mittel, klein, gross)
            }
        }
        guard let schlimmster, let hoechstes else { return [] }
        let faktor = schlimmster.gross / schlimmster.klein
        let anteil = hoechstes.hoehe / max(satzhoehe, 1) * 100
        // Stückweise zusammengesetzt und nicht in einer langen Plus-Kette:
        // Die Mischung aus Literalen, Interpolation und Format-Aufrufen ist
        // genau der Ausdruck, an dem der Typprüfer in 1.0.38 aufgegeben hat.
        var text = "Gemessen am fertigen Satz. "
        text += "Größter Unterschied an einem Tag: \(schlimmster.tag) \u{2014} "
        text += "kleinstes Foto \(Druckmass.mmText(schlimmster.klein)), "
        text += "größtes \(Druckmass.mmText(schlimmster.gross)).\n"
        let prozent = String(format: "%.0f", anteil)
        text += "Das höchste Foto des Buches steht am \(hoechstes.tag) und nimmt "
        text += "\(prozent) Prozent der Satzhöhe.\n"
        text += "Ein Faktor bis etwa 2,5 ist gewollt \u{2014} ein Akzent neben kleineren "
        text += "Bildern. Darüber wirkt eine Doppelseite unausgewogen; dann hilft ein "
        text += "anderes Seitenmuster für diesen Tag."
        let stufe: Stufe = faktor > 3.2 ? .warnung : (faktor > 2.5 ? .hinweis : .gut)
        let zahl = String(format: "%.1f", faktor).replacingOccurrences(of: ".", with: ",")
        return [Zeile(stufe: stufe, titel: "Fotogrößen: Faktor \(zahl)", text: text)]
    }

    // WO MITTEN IM SATZ GETRENNT WURDE (ab 1.0.41).
    //
    // Der Befund, der diese Fassung ausgelöst hat (Nutzer, 09/2026): „Ich
    // hatte aber gesagt, dass die Trennstellen dabei nach den Absätzen sein
    // sollen. Ich finde aber Trennstellen, die quasi mitten im Text
    // passieren."
    //
    // `Textmass.teilen` schneidet seither IMMER an einem Absatz, solange es
    // einen gibt. Übrig bleibt genau ein Fall, in dem es keinen geben KANN:
    // ein einzelner Absatz, der für sich schon länger ist als der Platz auf
    // der Seite. Dann muss an der Wortgrenze getrennt werden.
    //
    // Diese Stellen werden GEZÄHLT und nicht stillschweigend hingenommen —
    // sonst wäre „der Absatz gewinnt" eine Zusage, die sich niemand ansehen
    // kann. Gemessen wird am ERGEBNIS und nicht an der Absicht: Ein
    // Textblock, der nicht mit einem Satzzeichen aufhört und dem ein
    // weiterer folgt, endet mitten im Satz. Das ist unabhängig davon, was
    // die Teilung gemeint hat — und damit die ehrlichere Zahl.
    static func mittenImSatz(_ reise: Reise) -> [Zeile] {
        // Schlusszeichen, nach denen ein Absatz zu Ende sein darf. Das
        // Anführungszeichen und die Klammer stehen dabei, weil ein Satz auf
        // „\u{2026} sagte sie.\u{201C}" endet.
        let schluss: Set<Character> = [".", "!", "?", ":", ";",
                                       "\u{201C}", "\u{2019}", "\u{00BB}", ")", "\u{2026}"]
        var treffer: [String] = []
        for tag in reise.tage {
            var stuecke: [String] = []
            for seite in tag.seiten {
                for block in seite.bloecke {
                    guard case let .text(inhalt) = block.inhalt else { continue }
                    let sauber = inhalt.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !sauber.isEmpty { stuecke.append(sauber) }
                }
            }
            guard stuecke.count > 1 else { continue }
            for stueck in stuecke.dropLast() {
                guard let letztes = stueck.last, !schluss.contains(letztes) else { continue }
                let ende = stueck.suffix(34)
                treffer.append("\(tag.datum.mittel): \u{2026}\(ende)")
            }
        }
        guard !treffer.isEmpty else {
            return [Zeile(stufe: .gut, titel: "Alle Trennstellen liegen an einem Absatz",
                          text: "Kein Textkasten endet mitten im Satz.")]
        }
        return [Zeile(
            stufe: .hinweis,
            titel: "\(treffer.count)\u{00D7} mitten im Satz getrennt",
            text: "An diesen Stellen gab es im Kasten keine Absatzgrenze \u{2014} der Absatz "
                + "ist f\u{00FC}r sich schon l\u{00E4}nger als der Platz auf der Seite. "
                + "Eine kleinere Schrift, eine breitere Textspalte oder ein zus\u{00E4}tzlicher "
                + "Absatz im Tagebuchtext l\u{00F6}st es auf.\n"
                + treffer.prefix(12).joined(separator: "\n")
        )]
    }

    // WIE LANG DIE ZEILEN SIND — gemessen (ab 1.0.41).
    //
    // Die Zeilenlänge ist die Zahl, auf die sich
    // `Gestaltung.textspaltenanteil` stützt, und eine Einstellung, die sich
    // auf eine Behauptung stützt, wäre in diesem Buch die falsche. Gezählt
    // wird mit demselben CoreText-Umbruch, der die Seiten setzt
    // (`Textmass.zeichenJeZeile`).
    //
    // **Die Spanne ist typografisches Handwerk und keine Messung an diesem
    // Buch**: 45 bis 75 Zeichen gelten als bequem zu lesen, weil das Auge
    // am Zeilenende den Anfang der nächsten noch sicher findet. Das steht
    // so in jedem Satzlehrbuch; hier ist es nicht nachgeprüft worden, und
    // deshalb sagt die Zeile es als Faustregel und nicht als Befund.
    //
    // Gemessen wird der LÄNGSTE Fließtextblock des Buches: Ein kurzer sagt
    // über die Zeilenlänge nichts, weil er nur aus einer Zeile bestehen
    // kann. Überschriften, Datumszeilen und Bildunterschriften bleiben
    // draußen — für die gilt die Faustregel nicht.
    static func zeilenlaenge(_ reise: Reise) -> [Zeile] {
        var breiteste: (block: Block, laenge: Int)?
        for tag in reise.tage {
            for seite in tag.seiten {
                for block in seite.bloecke {
                    guard case let .text(inhalt) = block.inhalt,
                          inhalt.count > 80, block.rahmen.breite > 1
                    else { continue }
                    if breiteste == nil || inhalt.count > breiteste!.laenge {
                        breiteste = (block, inhalt.count)
                    }
                }
            }
        }
        guard let breiteste, case let .text(inhalt) = breiteste.block.inhalt else { return [] }
        let bild = Seitensatz.schriftbild(breiteste.block, reise: reise)
        let rand = breiteste.block.textrand(reise.gestaltung)
        let breite = breiteste.block.textbreite(rand: rand)
        let zeichen = Textmass.zeichenJeZeile(inhalt, bild: bild, breite: breite)
        guard zeichen > 0 else { return [] }

        let anteil = Int((reise.gestaltung.textspaltenanteil * 100).rounded())
        let grund = "Gemessen am l\u{00E4}ngsten Textblock des Buches: rund \(zeichen) Zeichen "
            + "je Zeile bei \(Druckmass.mmText(breite)) Spaltenbreite \u{2014} das sind "
            + "\(anteil)\u{00A0}% der Satzbreite (Gestalten \u{2192} R\u{00E4}nder, Karte, "
            + "Seitenzahlen). Als bequem zu lesen gelten 45 bis 75 Zeichen; das ist eine "
            + "Faustregel des Schriftsatzes und keine Messung an diesem Buch."
        if zeichen > 85 {
            return [Zeile(stufe: .warnung,
                          titel: "\(zeichen) Zeichen je Zeile \u{2014} sehr lang",
                          text: grund + " Eine schmalere Textspalte oder eine gr\u{00F6}\u{00DF}ere "
                              + "Schrift bringt die Zahl herunter.")]
        }
        if zeichen < 32 {
            return [Zeile(stufe: .hinweis,
                          titel: "\(zeichen) Zeichen je Zeile \u{2014} sehr kurz",
                          text: grund + " Bei so schmalen Spalten rei\u{00DF}t der Satz auf; eine "
                              + "kleinere Schrift oder eine breitere Spalte hilft.")]
        }
        return [Zeile(stufe: .gut, titel: "\(zeichen) Zeichen je Zeile", text: grund)]
    }

    // WIE OFT WIRKLICH GETRENNT WURDE — gezählt, nicht zugesagt (ab 1.0.40).
    //
    // Der Schalter „Silben trennen" hat von 1.0.0 bis 1.0.39 nichts getan
    // (`Model/Silbentrennung.swift`), und die Oberfläche behauptete das
    // Gegenteil. Deshalb steht hier keine Zusage, sondern eine Zahl: Wie
    // viele Trennstriche stehen im gesetzten Buch? Ist sie null, obwohl der
    // Schalter an ist, sieht man das, statt es zu vermuten.
    //
    // Gerechnet wird mit denselben Breiten, mit denen die Seiten gesetzt
    // sind — die Antwort kommt deshalb fast immer aus dem Zwischenspeicher
    // der Trennung und kostet nichts.
    static func trennungsbefund(_ reise: Reise) -> [Zeile] {
        var bloecke = 0
        var striche = 0
        for tag in reise.tage {
            for seite in tag.seiten {
                for block in seite.bloecke {
                    guard case let .text(inhalt) = block.inhalt, !inhalt.isEmpty else { continue }
                    let bild = Seitensatz.schriftbild(block, reise: reise)
                    guard bild.trennung else { continue }
                    bloecke += 1
                    let rand = block.textrand(reise.gestaltung)
                    let breite = block.textbreite(rand: rand)
                    striche += Silbentrennung.getrennt(inhalt, bild: bild, breite: breite)
                        .stellen.count
                }
            }
        }
        guard bloecke > 0 else { return [] }

        // Die Texte werden Stück für Stück gebaut und nicht als `+`-Kette in
        // die Argumentliste geschrieben: Die Mischung aus `+`, Bedingung und
        // Interpolation ist genau die, an der in 1.0.38 der Typprüfer
        // aufgegeben hat.
        var quelle = "Die Trennstellen kommen aus dem deutschen W\u{00F6}rterbuch des "
        quelle += "Ger\u{00E4}ts, nicht aus dieser App."

        if !Silbentrennung.verfuegbar {
            var text = "In \(bloecke) Textbl\u{00F6}cken ist die Trennung eingeschaltet. "
            text += "Dieses Ger\u{00E4}t gibt f\u{00FC}r Deutsch kein Trennw\u{00F6}rterbuch "
            text += "heraus, also wird nichts getrennt. "
            text += quelle
            let titel = "Silbentrennung eingeschaltet, aber kein W\u{00F6}rterbuch"
            return [Zeile(stufe: .warnung, titel: titel, text: text)]
        }
        if striche == 0 {
            var text = "In \(bloecke) Textbl\u{00F6}cken ist die Trennung eingeschaltet, "
            text += "gesetzt wurde aber kein einziger Strich. Bei schmalen Spalten und "
            text += "langen W\u{00F6}rtern w\u{00E4}re das ungew\u{00F6}hnlich. "
            text += quelle
            return [Zeile(stufe: .hinweis, titel: "Keine Trennstelle im ganzen Buch", text: text)]
        }
        var text = "Gez\u{00E4}hlt am gesetzten Buch, nicht an der Einstellung. "
        text += quelle
        let titel = "\(striche) Trennstriche in \(bloecke) Textbl\u{00F6}cken"
        return [Zeile(stufe: .gut, titel: titel, text: text)]
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
        zeilen.append(contentsOf: leereUnterschriften(reise))
        zeilen.append(contentsOf: bildgroessen(reise))
        zeilen.append(contentsOf: zeilenlaenge(reise))
        zeilen.append(contentsOf: trennungsbefund(reise))
        zeilen.append(contentsOf: mittenImSatz(reise))

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

        // EINE SCHRIFT, DIE ES HIER NICHT GIBT, IST DER STILLE FEHLER (ab 1.0.41).
        //
        // `Schriftbild.uiFont` fällt auf die Systemschrift zurück, wenn ein
        // Name nicht auflöst — richtig, denn eine Seite ohne Schrift gibt es
        // nicht. Nur sieht man es der Seite nicht an: Sie ist gesetzt, sie
        // ist lesbar, und sie ist in einer anderen Schrift als der, die oben
        // steht. Das trifft vor allem selbst installierte Schriften und
        // Bücher, die von einem anderen Gerät kommen.
        let fehlend = benutzt
            .filter { $0.familienname != nil && !$0.vorhanden }
            .map(\.name)
            .sorted()

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
        if !fehlend.isEmpty {
            zeilen.append(Zeile(
                stufe: .warnung,
                titel: "\(fehlend.count) Schrift\(fehlend.count == 1 ? "" : "en") gibt es auf diesem Gerät nicht",
                text: "\(fehlend.joined(separator: ", ")) \u{2014} gesetzt und gedruckt wird stattdessen die Systemschrift. Entweder die Schrift auf diesem Gerät installieren (dann in der Schriftwahl einmal \u{201E}Schrift vom Gerät wählen\u{2026}\u{201C} antippen) oder im Buch eine andere wählen."
            ))
        }
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
