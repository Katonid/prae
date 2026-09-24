import CoreGraphics
import CoreText
import ImageIO
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
        // WO IM BUCH DAS STEHT (ab 1.0.93). Leer heißt: Dieser Befund
        // hängt an keinem einzelnen Block — an der Seitenzahl, am
        // Farbraum, am Umschlagmaß. Wo die Liste gefüllt ist, bietet die
        // Prüfung einen Knopf an, der die Stellen im Buch rot umrandet und
        // zur ersten springt.
        var stellen: [Befundstelle] = []
    }

    // Ein Kasten, aus dem unten Text herausfällt, ist der eine Fehler, den
    // ein Tagebuch nicht machen darf: Auf dem Bildschirm sieht er aus wie
    // ein Kasten, der zu Ende ist, und im gedruckten Buch fehlt ein Satz.
    // Auf der Seite steht dafür die orange Marke — die sieht aber nur, wer
    // gerade auf dieser Seite ist. Das ganze Buch zählt diese Prüfung.
    static func abgeschnittenerText(_ alleStellen: [Befundstelle]) -> [Zeile] {
        let stellen = alleStellen.filter { $0.art == .textUeberlauf }
        guard !stellen.isEmpty else {
            return [Zeile(stufe: .gut, titel: "Kein abgeschnittener Text",
                          text: "In jeden Textkasten passt, was darin steht.")]
        }
        let liste = stellen.map { "\($0.ort): \($0.text)" }
        return [Zeile(
            stufe: .warnung,
            titel: "\(stellen.count) Textkästen sind zu klein",
            text: "Unten fällt Text heraus und steht so auch nicht im PDF \u{2014} was genau, steht hinter jeder Zeile. \u{201E}Im Buch zeigen\u{201C} umrandet die Kästen rot und springt zum ersten; \u{201E}Rahmen an Text anpassen\u{201C} löst es auf.\n" + liste.prefix(12).joined(separator: "\n"),
            stellen: stellen
        )]
    }

    // Zwei Textkästen auf derselben Seite mit demselben Wortlaut — das
    // druckt denselben Absatz zweimal. Auf dem Bildschirm liegen sie leicht
    // übereinander und sehen aus wie ein Darstellungsfehler; im Buch sind
    // es zwei Absätze. Gemeldet 09/2026 als „das Textfeld erscheint
    // dupliziert"; woher der zweite Kasten kam, ist damit noch nicht
    // beantwortet — aber er ist ab jetzt nicht mehr zu übersehen.
    static func doppelterText(_ alleStellen: [Befundstelle]) -> [Zeile] {
        let stellen = alleStellen.filter { $0.art == .doppelterText }
        guard !stellen.isEmpty else { return [] }
        let liste = stellen.map { "\($0.ort): \($0.text)" }
        return [Zeile(
            stufe: .warnung,
            titel: "\(stellen.count) Textkästen mit doppeltem Wortlaut",
            text: "Derselbe Wortlaut steht in mehreren Textkästen einer Seite und würde doppelt gedruckt. \u{201E}Im Buch zeigen\u{201C} umrandet sie rot; den überzähligen Kasten antippen und im Inspektor mit \u{201E}Block entfernen\u{201C} wegnehmen.\n" + liste.prefix(12).joined(separator: "\n"),
            stellen: stellen
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
    static func leereUnterschriften(_ alleStellen: [Befundstelle]) -> [Zeile] {
        let stellen = alleStellen.filter { $0.art == .leereUnterschrift }
        guard !stellen.isEmpty else { return [] }
        let liste = stellen.map { "\($0.ort) \u{2014} \($0.text)" }
        return [Zeile(
            stufe: .hinweis,
            titel: "\(stellen.count)\u{00D7} Unterschrift eingeschaltet, aber leer",
            text: "Unter diesen Fotos und Karten bleibt eine Zeile frei, in der nichts steht. So etwas entsteht durch einen Doppeltipp \u{2014} der schaltet die Unterschrift ein. Entweder etwas hineinschreiben, oder alle auf einmal abschalten: \u{201E}\u{2026}\u{201C} oben rechts \u{2192} \u{201E}Leere Bildunterschriften abschalten\u{201C}.\n"
                + liste.prefix(12).joined(separator: "\n"),
            stellen: stellen
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
            + "\(anteil)\u{00A0}% der Satzbreite (Ganzes Buch \u{2192} R\u{00E4}nder, Karte, "
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

    // Das Wasserzeichen — und zwar gemessen, nicht versprochen.
    //
    // „Möglichst an Stellen, an denen sonst noch kein Text oder Bild zu
    // sehen ist“ ist eine Zusage, die sich nur am fertigen Satz einlösen
    // lässt: Auf einer Seite mit einem randabfallenden Foto gibt es keine
    // freie Stelle, und dann liegt das Zeichen unter dem Bild und ist dort
    // schlicht weg. Das steht hier als Zahl, statt dass es jemand im
    // gedruckten Buch sucht.
    //
    // Gezählt werden die Seiten der TAGE. Das Titelblatt bleibt draußen:
    // Es wird beim Ausgeben erst gerechnet, und für eine Zahl, die eine
    // Größenordnung nennen soll, wäre das der teuerste Nachschlag.
    static func wasserzeichen(_ reise: Reise) -> [Zeile] {
        guard let zeichen = reise.gestaltung.wasserzeichen, zeichen.gueltig else { return [] }
        let satz = reise.gestaltung.satzspiegel(reise.format)
        var seiten = 0
        var verdeckt = 0
        var korrigiert = 0
        // WIE OFT JEDES BILD WIRKLICH VORKOMMT (ab 1.0.56).
        //
        // Gezogen wird aus der Kennung der Seite, also gleichverteilt im
        // ERWARTUNGSWERT und nicht gleich oft. Bei zehn Bildern auf
        // vierzig Seiten bleibt rechnerisch mit rund einem Siebtel
        // Wahrscheinlichkeit eines ganz ungenutzt — das gehört gezählt und
        // nicht behauptet. Dieselbe Lehre wie bei den Linienfarben der
        // Abfahrtstafel: Ein Streuwert verteilt zufällig, nicht gleichmäßig.
        var jeBild: [String: Int] = [:]
        for tag in reise.tage {
            for seite in tag.seiten {
                seiten += 1
                if seite.wasserzeichen?.gesetzt == true { korrigiert += 1 }
                if let gewaehlt = Wasserzeichenlage.bild(zeichen, seite: seite) {
                    jeBild[gewaehlt.datei, default: 0] += 1
                }
                // Gefragt wird `ort` und nicht `rechteck`: Seit 1.0.54
                // kann eine Seite das Zeichen verschieben, und gezählt
                // werden soll, wo es WIRKLICH liegt — sonst meldete die
                // Prüfung eine Verdeckung, die der Nutzer gerade behoben
                // hat.
                let platz = Wasserzeichenlage.ort(zeichen, satz: satz, seite: seite).rahmen
                // Ab einer gewichteten Belegung von 4 liegt mindestens die
                // halbe Fläche unter einem Foto oder einer Karte. Text
                // allein käme nie so weit — der wiegt 1.
                if Wasserzeichenlage.belegung(platz, seite: seite) >= 4 { verdeckt += 1 }
            }
        }
        guard seiten > 0 else { return [] }
        var text = "Sichtbarkeit \(Int(zeichen.deckung * 100)) %, Breite "
        text += "\(Int(zeichen.anteil * 100)) % der Satzbreite. "
        if verdeckt == 0 {
            text += "Auf allen \(seiten) Tagesseiten liegt es auf freiem Grund."
        } else {
            text += "Auf \(verdeckt) von \(seiten) Tagesseiten liegt es unter einem Foto "
            text += "oder einer Karte und ist dort kaum zu sehen \u{2014} dort war keine freie "
            text += "Stelle mehr."
        }
        if korrigiert > 0 {
            text += " Auf \(korrigiert) Seite"
            text += korrigiert == 1 ? "" : "n"
            text += " ist es von Hand nachgestellt."
        }
        text += " Mit „Ohne Transparenz“ fällt es ganz weg."
        var zeilen = [Zeile(stufe: verdeckt > seiten / 2 ? .hinweis : .gut,
                            titel: "Wasserzeichen", text: text)]
        if let verteilung = bildverteilung(zeichen, jeBild: jeBild, seiten: seiten) {
            zeilen.append(verteilung)
        }
        return zeilen
    }

    // Wie oft jedes der Bilder vorkommt. Nur, wenn es mehrere sind — bei
    // einem einzigen wäre die Zeile eine Zahl, die man schon kennt.
    private static func bildverteilung(_ zeichen: Wasserzeichen,
                                       jeBild: [String: Int], seiten: Int) -> Zeile?
    {
        let vorrat = zeichen.gueltigeBilder
        guard vorrat.count > 1, seiten > 0 else { return nil }
        var teile: [String] = []
        var ungenutzt = 0
        for (stelle, eintrag) in vorrat.enumerated() {
            let zahl = jeBild[eintrag.datei] ?? 0
            if zahl == 0 { ungenutzt += 1 }
            teile.append("Bild \(stelle + 1): \(zahl)")
        }
        var text = "Auf \(seiten) Tagesseiten \u{2014} " + teile.joined(separator: ", ") + ". "
        if ungenutzt > 0 {
            text += "\(ungenutzt) Bild"
            text += ungenutzt == 1 ? " kommt" : "er kommen"
            text += " gar nicht vor. Das ist kein Fehler: Gezogen wird aus der Kennung "
            text += "der Seite, und das ist gleichverteilt im Erwartungswert, nicht gleich "
            text += "oft. Wer es genau haben will, stellt einzelne Seiten von Hand um."
        } else {
            text += "Jedes Bild kommt mindestens einmal vor."
        }
        return Zeile(stufe: ungenutzt > 0 ? .hinweis : .gut,
                     titel: "Wasserzeichen \u{2014} Verteilung", text: text)
    }

    // EINE LINIE, DIE WEIT DANEBENZIEHT, STEHT IM GEDRUCKTEN BUCH (ab
    // 1.0.49). Die Punkteliste eines Tages zeigt den Befund schon — sie
    // sieht aber nur, wer diesen einen Tag gerade offen hat. Wer ein Buch
    // ausgibt, geht nicht zwanzig Tagesspuren durch; also zählt es diese
    // Prüfung, wie sie auch den abgeschnittenen Text und die leeren
    // Bildunterschriften zählt.
    //
    // Gezählt werden NUR Tage, auf deren Seiten wirklich eine Karte liegt.
    // Ein Ausreißer in einer Spur, die nirgends gezeichnet wird, kostet
    // nichts und wäre hier eine Warnung ohne Gegenstand.
    static func spurausreisser(_ reise: Reise) -> [Zeile] {
        var betroffen: [String] = []
        var punkte = 0
        for tag in reise.tage {
            let hatKarte = tag.seiten.contains { seite in
                seite.bloecke.contains { block in
                    if case .karte = block.inhalt { return true }
                    return false
                }
            }
            guard hatKarte else { continue }
            let befunde = Ausreisser.finden(tag.spur)
            guard !befunde.isEmpty else { continue }
            punkte += befunde.count
            let groesster = befunde.map(\.umweg).max() ?? 0
            // Stück für Stück in eine Variable und nicht als eine
            // `+`-Kette mit `?:` und Interpolation darin: Genau diese
            // Mischung hat in 1.0.38 den Typprüfer gesprengt.
            let wort = befunde.count == 1 ? "Punkt" : "Punkte"
            var zeile = "\(tag.datum.mittel): \(befunde.count) \(wort), "
            zeile += "größter Umweg \(Ausreisser.strecke(groesster))"
            betroffen.append(zeile)
        }
        guard !betroffen.isEmpty else { return [] }
        var text = "Gemessen wird der Umweg, den ein Punkt an zusätzlicher Linie kostet. "
        text += "Meist steht dahinter eine ungenaue Standortmessung; es kann aber auch "
        text += "ein Abstecher hin und zurück sein, und welcher von beidem es war, weiß "
        text += "nur, wer dabei war \u{2014} deshalb wird nichts von selbst entfernt. "
        text += "Nachsehen und aufräumen: das Tagesmenü \u{2192} Reisepunkte.\n\n"
        text += betroffen.joined(separator: "\n")
        return [Zeile(stufe: .hinweis,
                      titel: "\(punkte) Punkte springen aus der Reiselinie",
                      text: text)]
    }

    // Ein Hintergrundbild über die Doppelseite geht nur auf, wenn BEIDE
    // Seiten des Bogens dasselbe Bild mit demselben Schalter tragen. Auf
    // dem Bildschirm sieht die einzelne Seite dabei völlig in Ordnung aus
    // — sie zeigt ja ihre Hälfte; dass die andere Hälfte woanders steht,
    // fällt erst im aufgeschlagenen Buch auf. Also wird es gezählt.
    static func doppelseitenhintergrund(_ reise: Reise) -> [Zeile] {
        // DIE FOLGE WIRD GEFRAGT, NICHT NACHGEBAUT (ab 1.0.74).
        //
        // Bis 1.0.73 zählte diese Prüfung die Seiten selbst durch — eine
        // zweite Zählung neben `Reise.seitenfolge`, und genau davor warnt
        // der Fall von 1.0.52 („wer eine Zählung ändert, sucht nach jeder
        // Stelle, die sie nachbaut"). Seit U2 und U3 Inhalt tragen dürfen,
        // hätte der Nachbau jede Seite auf die falsche Buchhälfte gelegt
        // und daraufhin lauter Bogen gemeldet, die „nicht aufgehen".
        //
        // Das Titelblatt muss dafür nicht GESETZT werden: Gebraucht werden
        // Nummer, Lage und Hintergrund, und einen eigenen Hintergrund hat
        // es nicht — eine leere Seite genügt und kostet keine
        // CoreText-Messung.
        let folge = reise.seitenfolge(
            titelblatt: reise.titelseite ? Seite() : nil,
            rueckblatt: reise.hatRueckseite ? Seite() : nil)

        func grundVon(_ buchseite: Buchseite) -> Seitenhintergrund {
            // Der Außenbogen folgt dem Umschlag, alles andere dem Buch.
            if buchseite.teil == .rueckseite || buchseite.teil == .titel {
                return reise.umschlag.hintergrund ?? reise.gestaltung.hintergrund
            }
            return buchseite.seite.hintergrund ?? reise.gestaltung.hintergrund
        }
        func spannt(_ grund: Seitenhintergrund) -> UUID? {
            guard grund.art == .foto, grund.ueberDoppelseite else { return nil }
            return grund.fotoID
        }
        func wo(_ buchseite: Buchseite) -> String {
            buchseite.tag?.datum.mittel ?? buchseite.kurzname
        }

        // Der Außenbogen bleibt draußen: Dort ist ein Bild über beide
        // Hälften der Regelfall und kein Befund (`Umschlag`), und die
        // Rückenbreite dazwischen macht die Rechnung ohnehin zu einer
        // anderen.
        let bogen = Dictionary(grouping: folge.filter { $0.bogennummer > 0 },
                               by: \.bogennummer)
        guard folge.contains(where: { spannt(grundVon($0)) != nil }) else { return [] }

        var ganz = 0
        var halb: [String] = []
        var amUmschlag = 0
        for nummer in bogen.keys.sorted() {
            let seiten = bogen[nummer] ?? []
            let links = seiten.first { !$0.liegtRechts }
            let rechts = seiten.first { $0.liegtRechts }
            let bildLinks = links.flatMap { spannt(grundVon($0)) }
            let bildRechts = rechts.flatMap { spannt(grundVon($0)) }
            if bildLinks == nil, bildRechts == nil { continue }
            if bildLinks != nil, bildLinks == bildRechts { ganz += 1; continue }
            // Eine fehlende Nachbarseite ist kein Versehen, sondern das
            // Buch: Vor der ersten Seite und hinter der letzten liegt die
            // Innenseite des Umschlags. Trägt die seit 1.0.74 Inhalt, gibt
            // es diesen Fall am ersten und letzten Bogen gar nicht mehr —
            // dann stehen dort zwei echte Seiten, und ein halber Bogen ist
            // wieder ein Befund.
            if links == nil || rechts == nil { amUmschlag += 1; continue }
            halb.append("Bogen \(nummer): \(wo(links!)) / \(wo(rechts!))")
        }

        var text = "\(ganz) Doppelseiten zeigen ein durchgehendes Bild."
        if amUmschlag > 0 {
            text += " Bei \(amUmschlag) fällt die andere Hälfte auf die Innenseite des "
            text += "Umschlags und wird nie gedruckt — das ist der erste oder der letzte Bogen."
        }
        if reise.umschlagTraegtInhalt {
            text += " Die Innenseiten des Umschlags tragen Inhalt, also gibt es diesen Fall "
            text += "hier nicht: U2 liegt links neben der ersten Seite, U3 rechts neben der "
            text += "letzten."
        }
        if halb.isEmpty {
            text += " Kein Bogen zeigt zwei verschiedene Hälften."
            return [Zeile(stufe: .gut, titel: "Hintergrund über die Doppelseite", text: text)]
        }
        text += " Auf \(halb.count) Bogen tragen die beiden Seiten NICHT dasselbe Bild — "
        text += "dort steht im Buch die Hälfte des einen neben der Hälfte des anderen. "
        text += "Beide Seiten brauchen dasselbe Foto mit demselben Schalter.\n"
        text += halb.prefix(12).joined(separator: "\n")
        return [Zeile(stufe: .warnung,
                      titel: "\(halb.count) Doppelseiten gehen nicht auf", text: text)]
    }

    // DER UMSCHLAGBOGEN (ab 1.0.50) — Maße und Rückenbreite.
    //
    // Die Rückenbreite ist die eine Zahl des ganzen Buches, die diese App
    // NICHT messen kann: Sie hängt am Papier der Druckerei. Gerechnet wird
    // sie aus Seitenzahl, Papierstärke und Einband; hingeschrieben wird
    // beides — die Zahl und woher sie kommt. Eine gerechnete Zahl als
    // Messung auszugeben wäre genau die Art Lüge, die diese Prüfung nicht
    // erzählen darf.
    // WAS AUF DEM UMSCHLAGBOGEN ALS GRUND LIEGT — nachgesehen, nicht
    // behauptet (ab 1.0.67).
    //
    // Gemeldet 09/2026: „Der Export hat leider beim Umschlag PDF nicht das
    // Bild mitgenommen." Eine Ursache ist am Quelltext abgezählt und
    // behoben (die beiden Hälften übermalten den Bogengrund, siehe
    // `Buchausgabe.zeichneSeite`) — GESEHEN hat das niemand, und eine
    // zweite Ursache lässt sich von hier aus nicht ausschließen. Deshalb
    // sagt diese Zeile vor dem Ausgeben, was sie vorfindet: welcher Grund
    // gilt, welche Datei dahintersteht und ob sie sich überhaupt lesen
    // lässt. Dasselbe Muster wie die Stufenprobe bei Schulalarm — wo sich
    // eine Ursache nicht erschließen lässt, muss eine Probe entscheiden.
    static func umschlaggrund(_ reise: Reise) -> [Zeile] {
        guard reise.hatRueckseite else { return [] }
        let eigen = reise.umschlag.hintergrund != nil
        let grund = reise.umschlag.hintergrund ?? reise.gestaltung.hintergrund
        var woher = eigen
            ? "Der Umschlag hat einen eigenen Hintergrund: "
            : "Der Umschlag folgt dem Hintergrund des Buches: "

        switch grund.art {
        case .einfarbig:
            woher += "eine Farbe."
        case .verlauf:
            woher += "ein Verlauf."
        case .papierstruktur:
            woher += "Papierkorn."
        case .foto:
            return [fotogrundzeile(reise, grund: grund, woher: woher)]
        }
        woher += " Er liegt als EIN Stück über den ganzen Bogen, samt Rücken."
        return [Zeile(stufe: .hinweis, titel: "Grund des Umschlags", text: woher)]
    }

    private static func fotogrundzeile(_ reise: Reise, grund: Seitenhintergrund,
                                       woher: String) -> Zeile
    {
        guard let id = grund.fotoID, let foto = reise.foto(id) else {
            return Zeile(
                stufe: .warnung,
                titel: "Umschlag: Hintergrundfoto fehlt",
                text: woher + "ein Foto — nur gehört es zu keinem Bild dieses Buches mehr. Gedruckt bliebe die Farbe darunter. Wähle es unter Umschlag → Hintergrund des Umschlags neu."
            )
        }
        // Nachgesehen wird mit einer kleinen Kante: Es geht darum, OB sich
        // die Datei lesen lässt, nicht darum, sie schon zu setzen.
        guard Bildarchiv.shared.fuerAusgabe(foto.datei, reise: reise.id, kante: 256) != nil
        else {
            return Zeile(
                stufe: .warnung,
                titel: "Umschlag: Bilddatei nicht lesbar",
                text: woher + "das Foto \u{201E}\(foto.datei)\u{201C} \u{2014} die Datei ließ sich aber nicht öffnen. Im PDF bliebe dort nur die Farbe stehen."
            )
        }
        let bogen = Umschlagmass.bogen(reise.format, gestaltung: reise.gestaltung,
                                       umschlag: reise.umschlag,
                                       innenseiten: reise.innenseiten)
        var text = woher + "das Foto \u{201E}\(foto.datei)\u{201C}, gelesen."
        text += " Es füllt den ganzen Bogen von "
        text += "\(Druckmass.mmText(bogen.width)) x \(Druckmass.mmText(bogen.height))"
        text += " als EIN Bild, über den Rücken hinweg."
        let zoom = Int((grund.ausschnitt.zoom * 100).rounded())
        if zoom != 100 {
            text += " Ausschnitt: \(zoom) %."
        }
        if grund.schleier > 0.01 {
            let schleier = Int((grund.schleier * 100).rounded())
            text += " Darüber ein Schleier von \(schleier) %."
        }
        return Zeile(stufe: .gut, titel: "Grund des Umschlags", text: text)
    }

    static func umschlag(_ reise: Reise) -> [Zeile] {
        guard reise.hatRueckseite else { return [] }
        let innen = reise.innenseiten
        let blaetter = Umschlagmass.blaetter(innenseiten: innen)
        let mm = Umschlagmass.rueckenbreite(reise.umschlag, format: reise.format,
                                            innenseiten: innen)
        let bogen = Umschlagmass.bogen(reise.format, gestaltung: reise.gestaltung,
                                       umschlag: reise.umschlag, innenseiten: innen)

        var text = "Der Umschlag ist EIN Bogen von "
        text += "\(Druckmass.mmText(bogen.width)) x \(Druckmass.mmText(bogen.height)) "
        text += "— links die Rückseite, in der Mitte der Rücken, rechts die Titelseite. "
        if mm > 0.05 {
            let zahl = String(format: "%.1f", mm).replacingOccurrences(of: ".", with: ",")
            // Woher die Zahl kommt, entscheidet seit 1.0.52 die Tabelle des
            // Druckdienstes — steht eine da, wird nicht mehr gerechnet, und
            // dann wäre „gerechnet aus n Innenseiten" schlicht falsch.
            if let ausTabelle = reise.umschlag.tabellenbreite(innenseiten: innen,
                                                              format: reise.format)
            {
                let tab = String(format: "%.1f", ausTabelle)
                    .replacingOccurrences(of: ".", with: ",")
                text += "Rückenbreite \(tab) mm bei \(innen) Innenseiten, "
                text += Umschlagmass.rueckenherkunft(reise.umschlag, format: reise.format,
                                                     innenseiten: innen)
                text += ". Die Rechnung aus Papierstärke und Einband ruht."
            } else {
                text += "Rückenbreite \(zahl) mm, gerechnet aus \(innen) Innenseiten "
                text += "(\(blaetter) Blätter)"
                if reise.umschlag.einband == .hardcover {
                    let decke = String(format: "%.1f", reise.umschlag.deckenstaerke)
                        .replacingOccurrences(of: ".", with: ",")
                    text += " plus \(decke) mm Deckel"
                }
                text += ". Das ist GERECHNET und nicht gemessen — verbindlich ist die Angabe "
                text += "des Druckdienstes. Wer seine Tabelle hat, trägt sie unter "
                text += "Umschlag ein."
            }
        } else {
            text += "Ohne Rücken."
        }
        text += " Eine TrimBox in der Mitte gibt es bewusst nicht: Geschnitten wird außen, "
        text += "gefalzt wird am Rücken."

        var stufe = Stufe.gut
        var titel = "Umschlag als Bogen"
        if mm > 0.05, mm < 4 {
            stufe = .warnung
            titel = "Sehr schmaler Rücken"
            text += " Unter 4 mm bedrucken viele Buchdienste den Rücken gar nicht."
        }
        var zeilen = [Zeile(stufe: stufe, titel: titel, text: text)]

        // DER UMSCHLAG HAT SEIT 1.0.91 SEIN EIGENES MASS — und wer es
        // einträgt, soll am fertigen Buch nachlesen können, was daraus
        // geworden ist. Ohne eigenes Maß wird NICHTS behauptet: Dass der
        // Umschlag so groß ist wie der Block, ist bei vielen Bindungen
        // richtig, und eine Warnung darüber wäre keine Auskunft.
        let halb = Umschlagmass.seitenformat(reise.format, umschlag: reise.umschlag)
        if reise.umschlag.format != nil || reise.umschlag.anschnitt != nil {
            var eigen = "Eine Hälfte misst netto "
            eigen += "\(Druckvorgabe.zahl(halb.breite)) x \(Druckvorgabe.zahl(halb.hoehe)) mm"
            eigen += ", der Buchblock daneben "
            eigen += "\(Druckvorgabe.zahl(reise.format.breite)) x "
            eigen += "\(Druckvorgabe.zahl(reise.format.hoehe)) mm. "
            let a = Umschlagmass.anschnitt(reise.gestaltung, umschlag: reise.umschlag)
            eigen += "Beschnittzugabe des Umschlags: \(Druckvorgabe.zahl(a)) mm"
            if abs(a - reise.gestaltung.anschnitt) > 0.05 {
                eigen += " statt der \(Druckvorgabe.zahl(reise.gestaltung.anschnitt)) mm "
                eigen += "des Innenteils"
            }
            eigen += ". Beides ist EINGETRAGEN und nicht gerechnet \u{2014} was die "
            eigen += "Druckerei nennt, gilt."
            zeilen.append(Zeile(stufe: .gut, titel: "Eigenes Maß für den Umschlag",
                                text: eigen))
        }

        // WAS AUF U2 UND U3 STEHT, IST FÜR DEN BLOCK GESETZT. Trägt der
        // Umschlag ein eigenes Format, passt der Satz dieser beiden Seiten
        // nicht dazu — sie füllen die größere Hälfte nicht aus. Das wird
        // gesagt und nicht stillschweigend hingenommen; verschieben lässt
        // es sich nur von Hand.
        if reise.umschlag.format != nil, reise.umschlagTraegtInhalt {
            var wort = "Die erste und die letzte Tagebuchseite stehen auf den Innenseiten "
            wort += "des Umschlags. Gesetzt wurden sie für das Format des Buchblocks "
            wort += "(\(Druckvorgabe.zahl(reise.format.breite)) x "
            wort += "\(Druckvorgabe.zahl(reise.format.hoehe)) mm); die Umschlaghälfte misst "
            wort += "\(Druckvorgabe.zahl(halb.breite)) x \(Druckvorgabe.zahl(halb.hoehe)) mm. "
            wort += "Rechts und unten bleibt dort also mehr Rand stehen als auf einer "
            wort += "gewöhnlichen Seite."
            zeilen.append(Zeile(stufe: .hinweis, titel: "Innenseiten im Umschlagmaß",
                                text: wort))
        }
        return zeilen
    }

    // WIE VIELE INNENSEITEN BESTELLT SIND — und wie viele es sind
    // (ab 1.0.72).
    //
    // Gemeldet 09/2026 aus einem echten Auftrag: „Sie haben ein Produkt
    // mit 60 Innenseiten bestellt, uns allerdings zu viele Seiten für den
    // Innenteil zugeschickt."
    //
    // Die App zählt die Seiten längst; was fehlte, ist die Zahl daneben,
    // gegen die sie sich halten lässt. Ohne eingetragene Bestellung wird
    // NICHTS behauptet — eine Warnung über eine Seitenzahl, die niemand
    // bestellt hat, ist keine Auskunft.
    static func bestellung(_ reise: Reise) -> [Zeile] {
        let hat = reise.innenseiten
        guard let bestellt = reise.bestellteSeiten, bestellt > 0 else {
            return [Zeile(
                stufe: .hinweis,
                titel: "Innenteil: \(hat) Seiten",
                text: "Wie viele Seiten bestellt sind, weiß nur der Mensch \u{2014} unter \u{201E}Ausgeben\u{201C} lässt sich die Zahl eintragen. Dann steht hier, ob es passt, und zwar VOR dem Hochladen statt in der Antwortmail zwei Tage später."
            )]
        }
        if hat == bestellt {
            return [Zeile(
                stufe: .gut,
                titel: "Innenteil: \(hat) von \(bestellt) Seiten",
                text: "Der Innenteil hat genau so viele Seiten, wie bestellt sind. Der Umschlag zählt dabei nicht mit \u{2014} er ist ein eigenes Stück Papier."
            )]
        }
        let zuviel = hat > bestellt
        let wort = zuviel ? "zu viele" : "zu wenige"
        var text = "Bestellt sind \(bestellt), der Innenteil hat \(hat) \u{2014} \(abs(hat - bestellt)) \(wort). "
        if zuviel {
            text += "Eine Druckerei nimmt das nicht an. Seiten lassen sich über \u{201E}Seiten\u{201C} im Tagesmenü entfernen, ein ganzer Tag über \u{201E}ausblenden\u{201C} \u{2014} ausgeblendet bleibt er vollständig erhalten und kommt nur nicht ins Buch. "
        } else {
            text += "Die fehlenden Seiten füllt die Druckerei meist mit leeren auf, und die hat niemand gesehen. Wer sie gestalten will, legt sie über \u{201E}Seiten\u{201C} an. "
        }
        text += "Gezählt wird der BUCHBLOCK samt Ausgleichsseite; der Umschlag zählt nicht mit. "
        // WO DIE ZAHL STEHT, GEHÖRT IN DIE MELDUNG (ab 1.0.97).
        //
        // Gemeldet 09/2026: „Ich weiß nicht mehr, an welcher Stelle ich
        // überhaupt eine Seitenzahl eingegeben habe." Der Fall „noch
        // nichts eingetragen" nannte den Weg seit 1.0.72 — ausgerechnet
        // der Fall, in dem man die Zahl ÄNDERN will, nannte ihn nicht.
        text += "Eingetragen hast du sie unter \u{201E}\u{2026}\u{201C} \u{2192} "
        text += "\u{201E}Als PDF sichern\u{2026}\u{201C}, im Abschnitt \u{201E}Was "
        text += "ausgegeben wird\u{201C} als Zeile \u{201E}Bestellt \u{2026} "
        text += "Innenseiten\u{201C}. Ein leeres Feld heißt: nichts bestellt, dann "
        text += "wird hier nichts verglichen."
        return [Zeile(stufe: .warnung,
                      titel: "Innenteil: \(hat) statt \(bestellt) Seiten",
                      text: text)]
    }

    // WAS ZU NAH AN DER SCHNITTKANTE STEHT (ab 1.0.73).
    //
    // Befund des Nutzers, 09/2026, an seinem ersten Druckauftrag: „Ich
    // denke daher, dass es sinnvoll sein dürfte, einen Sicherheitsabstand
    // zum Rand zu halten."
    //
    // Der Satzspiegel liegt normalerweise weit innerhalb der Schutzzone —
    // gefährlich wird es bei Blöcken, die jemand von Hand an die Kante
    // geschoben hat, und bei kleinen Rändern. Gezählt wird deshalb am
    // ERGEBNIS und nicht an der Absicht: Jeder Block, der wirklich
    // hineinragt.
    //
    // **Randabfallende Blöcke sind ausgenommen, und zwar ohne Ausnahme.**
    // Sie SOLLEN über die Kante laufen; sie hier zu melden hieße, genau
    // das als Fehler auszugeben, was richtig ist — und nach dem dritten
    // solchen Hinweis liest niemand mehr eine Zeile dieser Prüfung.
    static func schutzzone(_ reise: Reise) -> [Zeile] {
        var zeilen = roteMarken(reise)
        zeilen.append(contentsOf: anschnittkante(reise))
        zeilen.append(contentsOf: sicherheitssaum(reise))
        return zeilen
    }

    // WAS AUF DER SEITE ROT UMRANDET IST (ab 1.0.87).
    //
    // Ansage des Nutzers, 09/2026: „Und natürlich soll dann auch die
    // Druckprüfung anschlagen, wenn irgendwo ein roter Rahmen ist."
    //
    // Gezählt wird dieselbe Liste, die auch die Marke auf der Seite setzt
    // (`Reise.amRandGefaehrdet`) — die VEREINIGUNG aus „über die
    // Schnittkante" und „im Sicherheitsabstand", jeder Block einmal. Die
    // beiden Zeilen darunter sagen dann, welcher Fall es ist; diese hier
    // beantwortet die Frage, mit der man die Prüfung öffnet.
    private static func roteMarken(_ reise: Reise) -> [Zeile] {
        var betroffen = 0
        var stellen: [String] = []
        for buchseite in reise.seitenfolge {
            let liste = reise.amRandGefaehrdet(buchseite)
            betroffen += liste.count
            if !liste.isEmpty, stellen.count < 6 { stellen.append(buchseite.kurzname) }
        }
        guard betroffen > 0 else {
            return [Zeile(
                stufe: .gut,
                titel: "Kein Block ist rot umrandet",
                text: "Nichts ragt \u{00FC}ber die Schnittkante oder in den Sicherheitsabstand. Gemessen wird der GEZEICHNETE Umriss \u{2014} der wei\u{00DF}e Fotorand und die Drehung z\u{00E4}hlen mit."
            )]
        }
        var text = "So viele Bl\u{00F6}cke tragen auf der Seite den dicken roten Rahmen. "
        text += "Was genau daran nicht stimmt, steht in den beiden Zeilen darunter: "
        text += "\u{00FC}ber der Schnittkante hei\u{00DF}t angeschnitten, im "
        text += "Sicherheitsabstand hei\u{00DF}t zu dicht am Rand. "
        if !stellen.isEmpty {
            text += "Betroffen sind: " + stellen.joined(separator: ", ") + ". "
        }
        text += "Beim Schieben rasten die Bl\u{00F6}cke seit 1.0.87 am letzten Punkt "
        text += "DAVOR ein \u{2014} gefangen wird derselbe Umriss, der auch markiert wird."
        return [Zeile(stufe: .warnung,
                      titel: "\(betroffen) Bl\u{00F6}cke sind rot umrandet",
                      text: text)]
    }

    // ÜBER DIE SCHNITTKANTE HINAUS (ab 1.0.81).
    //
    // Der schlimmere der beiden Fälle, und bis 1.0.80 wurde er gar nicht
    // geprüft: Ein Block, der über die Schnittkante ragt und nicht
    // randabfallend ist, wird im gedruckten Buch ANGESCHNITTEN. Das fiel
    // erst am Papier auf.
    private static func anschnittkante(_ reise: Reise) -> [Zeile] {
        var betroffen = 0
        var stellen: [String] = []
        for buchseite in reise.seitenfolge {
            let liste = reise.ueberDerSchnittkante(buchseite)
            betroffen += liste.count
            if !liste.isEmpty, stellen.count < 4 { stellen.append(buchseite.kurzname) }
        }
        guard betroffen > 0 else { return [] }
        var text = "Diese Bl\u{00F6}cke werden beim Beschneiden ANGESCHNITTEN \u{2014} "
        text += "sie ragen \u{00FC}ber das Endformat hinaus, ohne auf randabfallend "
        text += "gestellt zu sein. "
        if !stellen.isEmpty {
            text += "Zum Beispiel: " + stellen.joined(separator: ", ") + ". "
        }
        text += "Soll ein Block wirklich bis an die Kante laufen, geh\u{00F6}rt er auf "
        text += "RANDABFALLEND (Block \u{2192} Lage auf der Seite); dann l\u{00E4}uft er "
        text += "bis \u{00FC}ber den Anschnitt und ist hier nicht mehr gemeint. Auf der "
        text += "Seite ist jeder betroffene Block dick rot umrandet."
        return [Zeile(stufe: .warnung,
                      titel: "\(betroffen) Bl\u{00F6}cke ragen \u{00FC}ber die Schnittkante",
                      text: text)]
    }

    private static func sicherheitssaum(_ reise: Reise) -> [Zeile] {
        let saum = reise.gestaltung.sicherheitsabstand
        guard reise.gestaltung.hatSicherheitsabstand else {
            return [Zeile(
                stufe: .hinweis,
                titel: "Kein Sicherheitsabstand eingestellt",
                text: "Jede Schneidemaschine hat ein Spiel von einem knappen Millimeter, und ein Stapel B\u{00FC}cher wird nie auf den Punkt genau getroffen. Ohne Abstand kann eine Seitenzahl im einen Buch mittig stehen und im n\u{00E4}chsten halb angeschnitten. Eingestellt wird er unter \u{201E}Gestalten\u{201C}; 3 bis 5 mm sind \u{00FC}blich."
            )]
        }
        // JE SEITE EINE EIGENE ZONE (ab 1.0.76): Innen gilt oft ein
        // anderer Wert als außen, und welche Seite innen liegt, wechselt
        // von Seite zu Seite. Eine Zone für das ganze Buch prüfte auf
        // jeder zweiten Seite die falsche Kante.
        var betroffen = 0
        var textbloecke = 0
        var stellen: [String] = []
        for buchseite in reise.seitenfolge {
            // Dieselbe Stelle, die auch die Marke auf der Seite setzt —
            // sonst meldete die eine, was die andere nicht zeigt.
            for block in reise.imSicherheitsabstand(buchseite) {
                betroffen += 1
                if block.inhalt.istText { textbloecke += 1 }
                if stellen.count < 4 { stellen.append(buchseite.kurzname) }
            }
        }
        var masstext = Druckvorgabe.zahl(saum) + " mm"
        if reise.gestaltung.sicherheitAsymmetrisch {
            masstext += " außen, "
            masstext += Druckvorgabe.zahl(reise.gestaltung.innensicherheit)
            masstext += " mm am Bund"
        }
        guard betroffen > 0 else {
            return [Zeile(
                stufe: .gut,
                titel: "Sicherheitsabstand \(masstext) eingehalten",
                text: "Kein Block ragt in den Streifen am Rand, in dem nichts stehen soll, was gelesen werden muss. Randabfallende Bl\u{00F6}cke sind dabei ausgenommen \u{2014} die sollen \u{00FC}ber die Kante laufen."
            )]
        }
        var text = "\(betroffen) Bl\u{00F6}cke stehen n\u{00E4}her als \(masstext) an der Schnittkante"
        if textbloecke > 0 {
            text += ", davon \(textbloecke) mit Text \u{2014} und Text ist der Fall, um den es geht: "
            text += "Ein angeschnittenes Wort sieht man dem PDF nicht an, dem gedruckten Buch sofort. "
        } else {
            text += ". "
        }
        if !stellen.isEmpty {
            text += "Zum Beispiel: " + stellen.joined(separator: ", ") + ". "
        }
        text += "Soll ein Block wirklich bis an die Kante laufen, geh\u{00F6}rt er auf RANDABFALLEND "
        text += "(Block \u{2192} Lage auf der Seite) \u{2014} dann wird er bis \u{00FC}ber den Anschnitt "
        text += "gezogen und ist hier nicht mehr gemeint. Auf der Seite selbst ist jeder "
        text += "betroffene Block dick rot umrandet \u{2014} seit 1.0.81 auch dann, wenn "
        text += "die Hilfslinien ausgeschaltet sind: Die Linien sind eine Hilfe beim "
        text += "Anordnen, die Marke ist eine Warnung. Gemessen wird seit 1.0.83 der "
        text += "GEZEICHNETE Umriss: Der wei\u{00DF}e Fotorand liegt au\u{00DF}erhalb des "
        text += "Rahmens, und ein gedrehter Block steht mit seiner ECKE weiter drau\u{00DF}en "
        text += "als mit seiner Kante \u{2014} beides z\u{00E4}hlt jetzt mit."
        return [Zeile(stufe: textbloecke > 0 ? .warnung : .hinweis,
                      titel: "\(betroffen) Bl\u{00F6}cke im Sicherheitsabstand",
                      text: text)]
    }

    // WELCHEN FARBRAUM DIE DATEI TRÄGT (ab 1.0.89).
    //
    // Gefragt 09/2026: „ist der Farbraum eigentlich sRGB?" Die ehrliche
    // Antwort war damals nein — die Farben der App gingen als `/DeviceRGB`
    // ins PDF, also ohne Profil, und die Fotos behielten ihr eigenes.
    // Seither wandelt die Ausgabe (`Farbraum`), und diese Zeile sagt, was
    // dabei ANFÄLLT: wie viele Bilder schon sRGB sind und wie viele
    // umgerechnet werden.
    //
    // Gemessen wird an den ORIGINALEN auf der Platte, nicht an der
    // fertigen Datei — was wirklich darin steht, sagt erst ein Blick
    // hinein. Gedeckelt auf 40 Bilder: Jede Prüfung öffnet eine Datei, und
    // bei zweihundert Fotos wäre das ein Lauf über das ganze Archiv für
    // eine Zahl, die nach vierzig feststeht.
    private static func farbraum(_ reise: Reise) -> [Zeile] {
        var gezaehlt = 0
        var gewandelt = 0
        var namen: [String: Int] = [:]
        for foto in reise.fotos.prefix(40) {
            let ort = Bildarchiv.shared.pfad(reise.id, datei: foto.datei)
            guard let quelle = CGImageSourceCreateWithURL(ort as CFURL, nil),
                  let bild = CGImageSourceCreateImageAtIndex(quelle, 0,
                                                             [kCGImageSourceShouldCache: false] as CFDictionary)
            else { continue }
            gezaehlt += 1
            let name = Farbraum.name(bild.colorSpace)
            namen[name, default: 0] += 1
            if !Farbraum.istSRGB(bild.colorSpace) { gewandelt += 1 }
        }
        var text = "Alles, was diese App zeichnet \u{2014} Flächen, Schrift, Linien, "
        text += "Verläufe \u{2014} steht seit 1.0.89 ausdrücklich im sRGB-Raum in der "
        text += "Datei; vorher stand dort `DeviceRGB`, also gar kein Profil. "
        text += "Fotos und Karten werden beim Ausgeben nach sRGB umgerechnet, soweit "
        text += "sie nicht schon dort sind. "
        if gezaehlt > 0 {
            let liste = namen.sorted { $0.value > $1.value }
                .prefix(3)
                .map { "\($0.key): \($0.value)" }
                .joined(separator: ", ")
            text += "Nachgesehen in \(gezaehlt) Bilddateien \u{2014} \(liste). "
            if gewandelt > 0 {
                text += "\(gewandelt) davon werden umgerechnet. "
            } else {
                text += "Keines muss umgerechnet werden. "
            }
        }
        text += "CMYK kann iOS nicht schreiben; Fotobuchdienste verlangen ohnehin RGB "
        text += "und rechnen selbst in ihren Druckfarbraum um. Wer bei einer "
        text += "Offsetdruckerei mit ISO Coated v2 bestellt, muss die Datei vorher "
        text += "umwandeln lassen. **Was wirklich in der fertigen Datei steht, sagt "
        text += "erst ein Blick hinein** \u{2014} gemessen ist hier, was auf der Platte liegt."
        return [Zeile(stufe: .hinweis, titel: "Farbraum: sRGB", text: text)]
    }

    // HAT DAS BEIWERK NOCH PLATZ? (ab 1.0.82)
    //
    // Seitenzahl und Kopfzeile sitzen in den RÄNDERN — zwischen
    // Satzspiegel und Sicherheitslinie. Seit die Ränder bis auf den
    // Sicherheitsabstand hinuntergehen dürfen (gefragt 09/2026: „Der
    // Satzspiegel könnte doch tatsächlich innerhalb des
    // Sicherheitsabstandes ausgeführt werden."), kann dieser Streifen
    // verschwinden. `Seitenbeiwerk` klemmt beides dann in die Schutzzone —
    // also steht die Zahl im Text statt im Rand, und das ist kein
    // Druckfehler, aber auch nicht das, was jemand eingestellt hat.
    //
    // Gemessen wird am ERGEBNIS: Überschneidet sich das gesetzte Rechteck
    // mit dem Satzspiegel, ist der Rand zu knapp. Die Marke auf der Seite
    // greift hier nicht — Seitenzahl und Kopfzeile sind keine Blöcke.
    private static func beiwerkplatz(_ reise: Reise) -> [Zeile] {
        guard reise.gestaltung.seitenzahlen || reise.gestaltung.kopfzeile else { return [] }
        let satz = reise.gestaltung.satzspiegel(reise.format)
        var eng: Set<String> = []
        for buchseite in reise.seitenfolge {
            for zeile in Seitenbeiwerk.zeilen(buchseite, reise: reise)
            where zeile.rechteck.intersects(satz) {
                eng.insert(zeile.id)
            }
        }
        guard !eng.isEmpty else { return [] }
        var was: [String] = []
        if eng.contains("zahl") { was.append("Die Seitenzahl") }
        if eng.contains("kopf") { was.append("Die Kopfzeile") }
        var text = was.joined(separator: " und ") + " "
        text += eng.count > 1 ? "haben " : "hat "
        text += "zwischen Satzspiegel und Sicherheitslinie keinen Platz mehr und steht "
        text += "deshalb im Textbereich. Angeschnitten wird nichts \u{2014} weiter als bis "
        text += "an den Sicherheitsabstand r\u{00FC}ckt beides nie \u{2014}, aber es liegt "
        text += "jetzt dort, wo der Flie\u{00DF}text anf\u{00E4}ngt. Abhilfe: den Rand oben "
        text += "bzw. unten um ein paar Millimeter vergr\u{00F6}\u{00DF}ern (Gestalten "
        text += "\u{2192} Satzspiegel) oder Seitenzahl und Kopfzeile abschalten."
        return [Zeile(stufe: .hinweis,
                      titel: "Seitenzahl oder Kopfzeile ohne eigenen Rand",
                      text: text)]
    }

    // WIE GROSS DIE PDF-SEITE IST — und warum.
    //
    // Seit 1.0.85 h\u{00E4}ngt die Breite an `anschnittAmBund`: Liegt am Bund
    // keiner, wird waagerecht nur EINE Zugabe gerechnet. Der Satz nennt
    // beides, denn genau diese Zahl h\u{00E4}lt der Nutzer gegen seine
    // Bestellung.
    private static func bogensatz(_ gestaltung: Gestaltung, bogen: CGSize) -> String {
        let mass = "\(Druckmass.mmText(bogen.width)) x \(Druckmass.mmText(bogen.height))"
        let zugabe = Druckvorgabe.zahl(gestaltung.anschnitt)
        var text = "Die PDF-Seite misst \(mass) \u{2014} Endformat plus \(zugabe) mm "
        if gestaltung.anschnittAmBund {
            text += "Anschnitt an jeder Kante. "
        } else {
            text += "Anschnitt oben, unten und au\u{00DF}en; am Bund keiner. Welche "
            text += "der beiden Kanten die Zugabe tr\u{00E4}gt, wechselt von Seite zu "
            text += "Seite \u{2014} die TrimBox sagt es je Seite. "
        }
        text += "Endformat und Anschnitt stehen als TrimBox und BleedBox in der Datei."
        return text
    }

    static func vorab(_ reise: Reise) -> [Zeile] {
        var zeilen: [Zeile] = []
        let format = reise.format
        let gestaltung = reise.gestaltung
        let bogen = gestaltung.bogen(format)

        zeilen.append(Zeile(
            stufe: .gut,
            titel: "Endformat \(format.masstext)",
            text: bogensatz(gestaltung, bogen: bogen)
        ))

        if gestaltung.anschnitt < 2.5 {
            zeilen.append(Zeile(
                stufe: .warnung,
                titel: "Kein oder zu wenig Anschnitt",
                text: "Die meisten Druckdienste verlangen 3 mm, manche Buchdienste 5 mm. Ohne Zugabe kann kein Bild bis an die Papierkante laufen: Jede Schneidemaschine hat ein Spiel, und dort bliebe ein weißer Faden stehen."
            ))
        }

        zeilen.append(contentsOf: schutzzone(reise))
        zeilen.append(contentsOf: beiwerkplatz(reise))
        zeilen.append(contentsOf: bestellung(reise))
        zeilen.append(contentsOf: bildaufloesung(reise))
        zeilen.append(contentsOf: schriften(reise))
        // EINMAL gesammelt, dreimal gelesen (ab 1.0.93). Der Lauf geht
        // über jeden Textblock des Buches und misst ihn mit CoreText;
        // dreimal gerufen wäre er dreimal bezahlt — dieselbe Falle wie bei
        // jeder berechneten Eigenschaft in diesem Haus.
        let stellen = Befundstellen.alle(reise)
        zeilen.append(contentsOf: abgeschnittenerText(stellen))
        zeilen.append(contentsOf: doppelterText(stellen))
        zeilen.append(contentsOf: leereUnterschriften(stellen))
        zeilen.append(contentsOf: bildgroessen(reise))
        zeilen.append(contentsOf: zeilenlaenge(reise))
        zeilen.append(contentsOf: trennungsbefund(reise))
        zeilen.append(contentsOf: mittenImSatz(reise))
        zeilen.append(contentsOf: wasserzeichen(reise))
        zeilen.append(contentsOf: doppelseitenhintergrund(reise))
        zeilen.append(contentsOf: umschlag(reise))
        zeilen.append(contentsOf: umschlaggrund(reise))
        zeilen.append(contentsOf: spurausreisser(reise))

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

        zeilen.append(contentsOf: farbraum(reise))

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
    //
    // GERECHNET WIRD MIT DER KANTE, MIT DER AUCH AUSGEGEBEN WIRD (ab
    // 1.0.59). Bis 1.0.58 stand hier `foto.breite`, also die Bildpunkte
    // der Originaldatei — und die kommen so gar nicht ins PDF:
    // `Bildarchiv.fuerAusgabe` rechnet jedes Bild auf die Höchstkante der
    // gewählten Bildgüte herunter. Die Prüfung nannte damit eine Zahl, die
    // die Datei nicht hält. Gerechnet wird mit `Bildguete.vorgabe`, also
    // mit dem Regelfall — und die Zeile schreibt das auch hin, statt es
    // vorauszusetzen. Wer eine andere Güte wählt, bekommt seine Zahl im
    // Ausgabeblatt, dort mit dem gewählten Deckel.
    //
    // Mitgezählt wird seither auch das HINTERGRUNDFOTO. Es füllt Seite
    // oder Doppelseite ganz aus und ist damit fast immer das schwächste
    // Bild eines Buches; bis 1.0.58 wurde es überhaupt nicht angesehen.
    private static func bildaufloesung(_ reise: Reise) -> [Zeile] {
        let kante = Bildguete.vorgabe.kante
        let alle = Ausgabeguete.bilder(reise, guete: Bildguete.vorgabe)
        guard let schwaechste = alle.min(by: { $0.dpi < $1.dpi }) else { return [] }
        let unterGrenze = alle.filter { $0.dpi < Druckmass.dpiGrenze }.count
        let unterGut = alle.filter { $0.dpi >= Druckmass.dpiGrenze && $0.dpi < Druckmass.dpiGut }.count
        let wo = schwaechste.hintergrund
            ? "das Hintergrundfoto auf \(schwaechste.seite)"
            : "ein Bild auf \(schwaechste.seite)"
        let wert = Int(schwaechste.dpi.rounded())
        // Ob der Deckel drückt oder die Aufnahme selbst nicht mehr
        // hergibt, sind zwei verschiedene Befunde mit zwei verschiedenen
        // Handgriffen — und nur der erste lässt sich im Ausgabeblatt
        // beheben.
        let gedeckelt = alle.filter { $0.ohneDeckel > $0.dpi + 1 && $0.dpi < Druckmass.dpiGut }.count
        var nachsatz = " Gerechnet mit der Bildgüte \u{201E}\(Bildguete.vorgabe.name)\u{201C} "
        nachsatz += "(\(Int(Bildguete.vorgabe.zieldpi)) dpi, höchstens \(kante) Bildpunkte "
        nachsatz += "je Kante) — das ist die Vorwahl beim Ausgeben. Seit 1.0.70 bekommt "
        nachsatz += "jedes Bild genau so viele Bildpunkte, wie sein Platz auf dem Papier "
        nachsatz += "trägt; mehr davon wäre Dateigröße ohne Bild."
        if gedeckelt > 0 {
            nachsatz += " Bei \(gedeckelt) Bildern ist diese Grenze der Grund und nicht die "
            nachsatz += "Aufnahme; mit \u{201E}Volle Auflösung\u{201C} werden sie feiner."
        }

        // Zusammengesetzt wird über `+=` und nicht als eine Kette aus
        // Literal, Interpolation und `+` — die sprengt den Typprüfer
        // (die Lehre aus 1.0.38).
        var schwachtext = "Das schwächste ist \(wo) mit \(wert) dpi."
        if unterGrenze > 0 {
            var text = "Sie werden im Druck sichtbar weich. "
            text += schwachtext
            text += " Kleiner setzen oder das Bild in höherer Auflösung einlesen."
            text += nachsatz
            return [Zeile(stufe: .warnung,
                          titel: "\(unterGrenze) Bilder unter 150 dpi",
                          text: text)]
        }
        if unterGut > 0 {
            var text = "Das reicht für ein Fotobuch meistens noch. "
            text += schwachtext
            text += nachsatz
            return [Zeile(stufe: .hinweis,
                          titel: "\(unterGut) Bilder unter 250 dpi",
                          text: text)]
        }
        schwachtext += " 300 dpi sind der Anspruch jeder Druckerei."
        schwachtext += nachsatz
        return [Zeile(stufe: .gut,
                      titel: "Alle \(alle.count) Bilder über 250 dpi",
                      text: schwachtext)]
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
        zeilen.append(bildzeile(papier))
        return zeilen
    }

    // WIE VIELE BILDER WIRKLICH IN DER DATEI STEHEN (ab 1.0.68).
    //
    // Seitenzahl und Maße sagen nichts darüber, ob ein Panorama darin
    // steht oder weißes Papier mit einer Zeile Text — und genau dieser
    // Unterschied ist 09/2026 zweimal gemeldet worden, beide Male an einer
    // Datei, die von außen tadellos aussah. Gezählt werden deshalb die
    // Bild-XObjects der Seiten: das, was CoreGraphics beim Zeichnen
    // wirklich angelegt hat. Null davon in einem Buch mit Fotos ist ein
    // Befund und keine Auslegungssache.
    //
    // Was die Zählung NICHT sieht: ein Bild, das in einem Form-XObject
    // steckt. Diese App legt keines an — sollte eine spätere Fassung es
    // tun, zählt die Zeile zu niedrig, und das steht hier, statt es zu
    // verschweigen.
    static func bildzeile(_ papier: CGPDFDocument) -> Zeile {
        let anzahl = bilderImPdf(papier)
        var titel = "\(anzahl) Bilder in der Datei"
        if anzahl == 1 { titel = "1 Bild in der Datei" }
        var text = "Gezählt ist, was wirklich in der Datei steht, nicht, "
        text += "was im Buch angelegt ist."
        var stufe = Stufe.gut
        if anzahl == 0 {
            stufe = .warnung
            text = "In dieser Datei steht kein einziges Bild. Das ist richtig, "
            text += "wenn hier nur Text und Farbflächen stehen sollen — und ein "
            text += "Befund, wenn ein Foto darauf gehört."
        }
        return Zeile(stufe: stufe, titel: titel, text: text)
    }

    static func bilderImPdf(_ papier: CGPDFDocument) -> Int {
        guard papier.numberOfPages > 0 else { return 0 }
        var gesamt = 0
        for nummer in 1...papier.numberOfPages {
            guard let seite = papier.page(at: nummer),
                  let blatt = seite.dictionary else { continue }
            var mittel: CGPDFDictionaryRef?
            guard CGPDFDictionaryGetDictionary(blatt, "Resources", &mittel),
                  let mittel else { continue }
            var xobjekte: CGPDFDictionaryRef?
            guard CGPDFDictionaryGetDictionary(mittel, "XObject", &xobjekte),
                  let xobjekte else { continue }
            // Der Applier von CoreGraphics ist eine C-Funktion und darf
            // nichts einfangen — gezählt wird deshalb über einen Zeiger
            // auf eine Zahl daneben.
            var aufSeite = 0
            withUnsafeMutablePointer(to: &aufSeite) { merker in
                CGPDFDictionaryApplyFunction(xobjekte, { _, wert, zeiger in
                    var strom: CGPDFStreamRef?
                    guard CGPDFObjectGetValue(wert, .stream, &strom), let strom,
                          let beschreibung = CGPDFStreamGetDictionary(strom) else { return }
                    var art: UnsafePointer<CChar>?
                    guard CGPDFDictionaryGetName(beschreibung, "Subtype", &art),
                          let art, String(cString: art) == "Image" else { return }
                    zeiger?.assumingMemoryBound(to: Int.self).pointee += 1
                }, merker)
            }
            gesamt += aufSeite
        }
        return gesamt
    }
}
