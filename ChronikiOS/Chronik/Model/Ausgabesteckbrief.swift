import CoreGraphics
import Foundation

// DER STECKBRIEF DES AUSGABEFORMATS — alle Zahlen an EINER Stelle
// (ab 1.0.75).
//
// Ansage des Nutzers, 09/2026: „Bei einer anderen Druckerei wird bei den
// Tagebuchseiten auf der Innenseite kein Bundsteg gelassen. Das gipfelt
// jetzt in einer Fülle von Formaten. Vielleicht wäre es gut, sich
// innerhalb der App irgendwo anzeigen lassen zu können, wie denn jetzt das
// Ausgabeformat aussieht und wie die einzelnen Werte sind. Also zum
// Beispiel 3 mm Beschnitt ringsherum und Bundsteg ja oder nein. Wenn ja,
// wie viel und so weiter."
//
// **Das ist der Befund aus 1.0.72, eine Ebene breiter.** Damals ging es um
// EINE Zahl (das Bogenmaß), und sie war nie falsch — sie stand nur
// nirgends so da, dass man sie gegen eine Bestellung halten konnte. Jetzt
// sind es alle: Anschnitt, Sicherheitsabstand, Ränder, Bundsteg,
// Rückenbreite, Umschlagbogen, Bildgüte. Jede einzelne ist irgendwo
// einstellbar, und genau deshalb weiß nach der dritten Druckerei niemand
// mehr, was gerade gilt.
//
// **Gerechnet wird hier NICHTS neu.** Jede Zahl kommt aus der Stelle, die
// sie auch beim Ausgeben liefert — `Gestaltung`, `Druckvorgabe`,
// `Umschlagmass`, `Bildguete`. Eine zweite Fassung nennte zwei Zahlen, und
// die Druckerei prüft eine; das ist dieselbe Regel, aus der `Bogenlage`
// und `Umschlagmass` entstanden sind.
//
// **Und jede Zeile sagt, WOHER sie kommt.** Eine Einstellung ist etwas
// anderes als eine Folge daraus: Das Endformat hat jemand gewählt, das
// Bogenmaß folgt. Wer das verwechselt, tippt das Bogenmaß als Format ein —
// genau die Falle, die `Druckvorgabe.bogenverdacht` abfängt.
enum Ausgabesteckbrief {
    struct Zeile: Identifiable {
        var id = UUID()
        var name: String
        var wert: String
        /// Ein Satz dazu, wenn die Zahl allein missverstanden werden kann.
        var erklaerung: String = ""
        /// Eingestellt oder gerechnet. Das ist keine Kosmetik: Nur eine
        /// Einstellung lässt sich ändern, und nur bei ihr ist der Weg
        /// dorthin eine Auskunft.
        var eingestellt: Bool = false
        /// Wo man sie umstellt — leer, wo es nichts umzustellen gibt.
        var wo: String = ""
    }

    struct Abschnitt: Identifiable {
        var id = UUID()
        var titel: String
        var zeilen: [Zeile]
        var fuss: String = ""
    }

    // MARK: - Der ganze Steckbrief

    /// `bildbefund` kommt von außen, weil `Ausgabeguete.satz` über jedes
    /// Bild des Buches läuft. Diese Funktion hier muss billig bleiben: Sie
    /// wird im Körper einer Ansicht gebraucht, und der läuft bei jedem
    /// Neuzeichnen (dieselbe Falle wie bei der Druckprüfung in 1.0.0).
    static func abschnitte(_ reise: Reise, guete: Bildguete = .vorgabe,
                           bildbefund: String = "") -> [Abschnitt]
    {
        [datei(reise), zugaben(reise), satzspiegel(reise),
         umschlag(reise), bilder(reise, guete: guete, befund: bildbefund)]
            .filter { !$0.zeilen.isEmpty }
    }

    // MARK: - Die Datei

    private static func datei(_ reise: Reise) -> Abschnitt {
        let g = reise.gestaltung
        let format = reise.format
        var zeilen: [Zeile] = []

        zeilen.append(Zeile(
            name: "Endformat",
            wert: format.masstext + " (" + format.name + ")",
            erklaerung: "Die Seite, wie sie nach dem Schneiden in der Hand liegt.",
            eingestellt: true,
            wo: "Ganzes Buch \u{2192} Seitenformat\u{2026}"))

        zeilen.append(Zeile(
            name: "Bogen im PDF \u{00B7} Buchseiten",
            wert: Druckvorgabe.masstext(Druckvorgabe.bogen(format, anschnitt: g.anschnitt,
                                                           amBund: g.anschnittAmBund)),
            erklaerung: bogensatz(g),
            eingestellt: false))

        let doppelt = CGSize(width: 2 * format.breite + 2 * g.anschnitt,
                             height: format.hoehe + 2 * g.anschnitt)
        zeilen.append(Zeile(
            name: "Bogen im PDF \u{00B7} Doppelseiten",
            wert: Druckvorgabe.masstext(doppelt),
            erklaerung: "Zwei Buchseiten nebeneinander. Am Bund liegt KEIN "
                + "Anschnitt \u{2014} dort stoßen die beiden Endformate aneinander. "
                + "Der RÜCKEN zählt hier nicht mit: Der gehört zum Umschlagbogen, "
                + "und dessen Maß steht in der Zeile darunter.",
            eingestellt: false))

        if reise.hatRueckseite {
            let pt = Umschlagmass.bogen(format, gestaltung: g, umschlag: reise.umschlag,
                                        innenseiten: reise.innenseiten)
            let mm = CGSize(width: Druckmass.mm(pt.width), height: Druckmass.mm(pt.height))
            zeilen.append(Zeile(
                name: "Bogen im PDF \u{00B7} Umschlag",
                wert: Druckvorgabe.masstext(mm),
                erklaerung: "Rückseite, Rücken und Titelseite auf einem Stück "
                    + "Papier. Am Rücken wird gefalzt und nicht geschnitten, "
                    + "also liegt auch dort kein Anschnitt.",
                eingestellt: false))

            // WAS EINE HÄLFTE MISST UND WAS AUSSEN ZUGEGEBEN WIRD (ab
            // 1.0.91). Beides darf vom Buchblock abweichen — der Umschlag
            // eines gebundenen Buches ist größer, und die Druckerei nennt
            // für ihn oft eine andere Beschnittzugabe. Ohne diese beiden
            // Zeilen ließe sich nicht sehen, WORAUS das Bogenmaß darüber
            // entsteht.
            let halb = Umschlagmass.seitenformat(format, umschlag: reise.umschlag)
            zeilen.append(Zeile(
                name: "Umschlag \u{00B7} eine Hälfte",
                wert: Druckvorgabe.masstext(CGSize(width: halb.breite, height: halb.hoehe)),
                erklaerung: reise.umschlag.format == nil
                    ? "Nettomaß nach dem Schneiden. Nicht eingestellt \u{2014} es gilt "
                        + "das Seitenformat des Buches. Ein Hardcover ist in Wahrheit "
                        + "größer als sein Block; was die Druckerei nennt, wird unter "
                        + "Umschlag \u{2192} Maß der Druckerei eingetragen."
                    : "Nettomaß nach dem Schneiden, eigens für den Umschlag "
                        + "eingetragen. Der Buchblock misst daneben unverändert "
                        + Druckvorgabe.masstext(CGSize(width: format.breite,
                                                       height: format.hoehe)) + ".",
                eingestellt: reise.umschlag.format != nil))
            zeilen.append(Zeile(
                name: "Umschlag \u{00B7} Anschnitt",
                wert: Druckvorgabe.zahl(Umschlagmass.anschnitt(g, umschlag: reise.umschlag))
                    + " mm",
                erklaerung: reise.umschlag.anschnitt == nil
                    ? "Ringsum, am Rücken keiner. Nicht eingestellt \u{2014} es gilt die "
                        + "Zugabe des Buches."
                    : "Ringsum, am Rücken keiner. Eigens für den Umschlag eingetragen; "
                        + "der Innenteil behält seine "
                        + Druckvorgabe.zahl(g.anschnitt) + " mm.",
                eingestellt: reise.umschlag.anschnitt != nil))
        }

        zeilen.append(Zeile(
            name: "Im PDF vermerkt",
            wert: "TrimBox = Endformat, BleedBox = Bogen",
            erklaerung: "Daran erkennt die Druckerei, wo geschnitten wird. "
                + "Die Broschüre trägt beides bewusst nicht \u{2014} ein "
                + "Heimdrucker schneidet nichts ab.",
            eingestellt: false))

        zeilen.append(seitenzeile(reise))

        return Abschnitt(titel: "Die Datei", zeilen: zeilen, fuss: farbsatz)
    }

    private static func bogensatz(_ g: Gestaltung) -> String {
        var text = "Das ist die Zahl, die eine Druckerei prüft: Endformat "
        if g.anschnittAmBund {
            text += "plus zweimal Anschnitt. "
        } else {
            // AM BUND KEINER (ab 1.0.85) — waagerecht also nur eine Zugabe.
            text += "plus Anschnitt: senkrecht zweimal, waagerecht nur EINMAL, "
            text += "denn am Bund liegt keiner. Welche Kante ihn trägt, wechselt "
            text += "von Seite zu Seite. "
        }
        text += "Sie gehört in KEIN Formatfeld \u{2014} "
        text += "wer sie dort einträgt, bekommt den Anschnitt ein zweites Mal."
        return text
    }

    private static var farbsatz: String {
        var text = "Geschrieben wird in sRGB (ab 1.0.89): Was die App zeichnet, trägt "
        text += "den Raum ausdrücklich, Fotos und Karten werden beim Ausgeben "
        text += "dorthin umgerechnet \u{2014} ein iPhone-Foto ist sonst häufig "
        text += "Display P3. Fotobuchdienste verlangen RGB und rechnen selbst in "
        text += "ihren Druckfarbraum um; CMYK kann iOS nicht schreiben. "
        text += "Der Text steht als Text in der Datei, nicht als Bild."
        return text
    }

    private static func seitenzeile(_ reise: Reise) -> Zeile {
        let hat = reise.innenseiten
        var wert = "\(hat) Buchseiten"
        if reise.hatRueckseite {
            // Stehen U2 und U3 im Innenteil (ab 1.0.112), sind sie in `hat`
            // schon gezählt; auf dem Umschlag bleiben zwei.
            let vier = reise.umschlag.innenseitenBogen && !reise.umschlag.innenseitenImBlock
            wert += vier ? " + 4 Umschlagseiten" : " + 2 Umschlagseiten"
        }
        var satz = "Der Umschlag zählt nicht zum Innenteil \u{2014} er ist ein "
        satz += "eigenes Stück Papier."
        if let bestellt = reise.bestellteSeiten {
            if bestellt == hat {
                satz += " Bestellt sind \(bestellt) \u{2014} das passt."
            } else if hat > bestellt {
                satz += " Bestellt sind \(bestellt): \(hat - bestellt) zu viele."
            } else {
                satz += " Bestellt sind \(bestellt): \(bestellt - hat) zu wenige."
            }
        }
        return Zeile(name: "Seiten", wert: wert, erklaerung: satz, eingestellt: false)
    }

    // MARK: - Die Zugaben

    // ZWEI STREIFEN IN ENTGEGENGESETZTE RICHTUNGEN, und sie werden gern
    // verwechselt (siehe `Gestaltung.sicherheitsabstand`). Deshalb stehen
    // sie hier nebeneinander in EINEM Abschnitt.
    private static func zugaben(_ reise: Reise) -> Abschnitt {
        let g = reise.gestaltung
        var zeilen: [Zeile] = []

        var anschnittwert = "keiner"
        if g.anschnitt > 0.05 {
            anschnittwert = Druckvorgabe.zahl(g.anschnitt)
                + (g.anschnittAmBund ? " mm ringsum" : " mm \u{2014} am Bund keiner")
        }
        zeilen.append(Zeile(
            name: "Anschnitt",
            wert: anschnittwert,
            erklaerung: "Liegt AUSSERHALB des Endformats und wird nach dem Druck "
                + "weggeschnitten. Alles, was randabfallend sein soll, muss bis "
                + "dorthin laufen \u{2014} sonst bleibt nach dem Schneiden ein "
                + "weißer Faden stehen. Auf einer Doppelseite und am Umschlagbogen "
                + "liegt er nur AUSSEN: Am Bund wird gefalzt oder gebunden. So "
                + "zeigt es auch die Doppelseitenansicht, und dort fehlt am Bund "
                + "deshalb die rote Schnittkante. Verlangt die Druckerei das auch "
                + "für EINZELNE Seiten (\u{201E}innen 0 mm\u{201C}), wird er mit "
                + "dem Schalter daneben abgeschaltet.",
            eingestellt: true,
            wo: "Ganzes Buch \u{2192} Ränder und Druckzugaben\u{2026}"))

        var schutzwert = "keiner"
        if g.hatSicherheitsabstand {
            if g.sicherheitAsymmetrisch {
                schutzwert = Druckvorgabe.zahl(g.sicherheitsabstand) + " mm außen, "
                schutzwert += Druckvorgabe.zahl(g.innensicherheit) + " mm am Bund"
            } else {
                schutzwert = Druckvorgabe.zahl(g.sicherheitsabstand) + " mm ringsum"
            }
        }
        var schutzsatz = "Liegt INNERHALB des Endformats. Dort soll nichts stehen, "
        schutzsatz += "was gelesen werden muss: Jede Schneidemaschine hat ein Spiel "
        schutzsatz += "von einem knappen Millimeter."
        if g.sicherheitAsymmetrisch {
            schutzsatz += " Am Bund gilt ein eigener Wert \u{2014} dort verschwindet "
            schutzsatz += "bei der Bindung ein Streifen im Falz. Oben und unten gilt "
            schutzsatz += "der äußere: Dort wird geschnitten und nicht gebunden. "
            schutzsatz += "Welche Seite innen liegt, wechselt von Seite zu Seite."
        }
        zeilen.append(Zeile(
            name: "Sicherheitsabstand",
            wert: schutzwert,
            erklaerung: schutzsatz,
            eingestellt: true,
            wo: "Ganzes Buch \u{2192} Ränder und Druckzugaben\u{2026}"))

        return Abschnitt(titel: "Die Zugaben", zeilen: zeilen,
                         fuss: "Der Anschnitt geht nach außen, der "
                             + "Sicherheitsabstand nach innen. Beide haben "
                             + "dieselbe Ursache und sind nicht dasselbe.")
    }

    // MARK: - Der Satzspiegel

    private static func satzspiegel(_ reise: Reise) -> Abschnitt {
        let g = reise.gestaltung
        var zeilen: [Zeile] = []

        // Stück für Stück gebaut und nicht als Kette aus `+`, `?:` und
        // Interpolation in EINEN Ausdruck: Daran hat sich in 1.0.38 der
        // Typprüfer verschluckt.
        var raender = "oben " + Druckvorgabe.zahl(g.randOben)
        raender += " \u{00B7} außen " + Druckvorgabe.zahl(g.randAussen)
        raender += " \u{00B7} unten " + Druckvorgabe.zahl(g.randUnten) + " mm"
        zeilen.append(Zeile(
            name: "Ränder",
            wert: raender,
            eingestellt: true,
            wo: "Ganzes Buch \u{2192} Ränder und Druckzugaben\u{2026}"))

        zeilen.append(bundstegzeile(g))

        let satz = g.satzspiegel(reise.format)
        var satzmass = Druckmass.mmText(satz.width, stellen: 0)
        satzmass += " \u{00D7} " + Druckmass.mmText(satz.height, stellen: 0)
        zeilen.append(Zeile(
            name: "Satzspiegel",
            wert: satzmass,
            erklaerung: "Die Fläche, in die neue Seiten gesetzt werden. Ein "
                + "geänderter Rand verschiebt sie \u{2014} schon gesetzte "
                + "Blöcke bleiben, wo sie sind, und ein Hintergrund richtet "
                + "sich ohnehin nie nach ihr.",
            eingestellt: false))

        zeilen.append(Zeile(
            name: "Fuge zwischen Blöcken",
            wert: Druckvorgabe.zahl(g.fuge) + " mm",
            eingestellt: true,
            wo: "Ganzes Buch \u{2192} Ränder und Druckzugaben\u{2026}"))

        let spalte = satz.width * g.textspaltenanteil
        let anteil = Int((g.textspaltenanteil * 100).rounded())
        var spaltentext = "\(anteil) % der Satzbreite ("
        spaltentext += Druckmass.mmText(spalte, stellen: 0) + ")"
        zeilen.append(Zeile(
            name: "Textspalte höchstens",
            wert: spaltentext,
            eingestellt: true,
            wo: "Ganzes Buch \u{2192} Schrift und Ausrichtung\u{2026}"))

        return Abschnitt(titel: "Der Satzspiegel", zeilen: zeilen)
    }

    // DIE ANTWORT AUF DIE FRAGE, DIE DIESE FASSUNG AUSGELÖST HAT.
    //
    // „Bei einer anderen Druckerei wird auf der Innenseite kein Bundsteg
    // gelassen" — dann ist nichts umzustellen: Die Vorgabe dieser App ist
    // NULL, und das ist seit 1.0.1 so. Was fehlte, ist der Satz, der es
    // sagt. Steht doch einer, gehört die zweite Hälfte dazu: Er wird auf
    // BEIDE Seitenränder gerechnet, und das ist Absicht — welche Seite
    // innen liegt, hängt an der laufenden Seitenzahl, und die verschiebt
    // sich, sobald ein Tag eine Seite mehr braucht (seit 1.0.74 auch,
    // sobald zwei Seiten auf den Umschlag wandern).
    private static func bundstegzeile(_ g: Gestaltung) -> Zeile {
        guard g.bundsteg > 0.05 else {
            return Zeile(
                name: "Bundsteg",
                wert: "keiner",
                erklaerung: "Zur Heftung hin wird kein zusätzlicher Rand "
                    + "gelassen. Das ist die Vorgabe \u{2014} wer sie braucht, "
                    + "erfährt sie vom Druckdienst.",
                eingestellt: true,
                wo: "Ganzes Buch \u{2192} Ränder und Druckzugaben\u{2026}")
        }
        var satz = "Er wird auf BEIDE Seitenränder gerechnet, nicht nur auf "
        satz += "den inneren: Welche Seite innen liegt, hängt an der laufenden "
        satz += "Seitenzahl, und die verschiebt sich. Der äußere Rand misst "
        satz += "damit " + Druckvorgabe.zahl(g.randAussen + g.bundsteg) + " mm."
        return Zeile(name: "Bundsteg",
                     wert: Druckvorgabe.zahl(g.bundsteg) + " mm",
                     erklaerung: satz,
                     eingestellt: true,
                     wo: "Ganzes Buch \u{2192} Ränder und Druckzugaben\u{2026}")
    }

    // MARK: - Der Umschlag

    private static func umschlag(_ reise: Reise) -> Abschnitt {
        guard reise.titelseite else {
            return Abschnitt(titel: "Der Umschlag", zeilen: [])
        }
        let u = reise.umschlag
        var zeilen: [Zeile] = []

        zeilen.append(Zeile(
            name: "Umschlag",
            wert: reise.hatRueckseite ? "eigener Bogen" : "keiner",
            erklaerung: reise.hatRueckseite
                ? "Rückseite, Rücken und Titelseite werden zusammen ausgegeben."
                : "Die Titelseite ist die gewöhnliche Seite 1 und wird mitgebunden.",
            eingestellt: true,
            wo: "Ganzes Buch \u{2192} Titel, Umschlag und Rücken\u{2026}"))

        if reise.hatRueckseite {
            zeilen.append(rueckenzeile(reise))
            var innenwert = "nicht im PDF"
            var innensatz = "Sie kommen von der Druckerei \u{2014} beim Hardcover ist das "
            innensatz += "das Vorsatzpapier."
            if u.innenseitenBogen {
                innenwert = "werden mitgeliefert"
                innensatz = "Als zweite Seite derselben Umschlagdatei, in denselben Maßen."
            }
            if u.innenseitenBogen, reise.umschlagTraegtInhalt, u.innenseitenImBlock {
                innenwert = "im Innenteil"
                innensatz = "Als erste und letzte Seite der Innenteil-Datei, im Maß des "
                innensatz += "Buchblocks (ab 1.0.112, so verlangt es Saal Digital)."
            }
            zeilen.append(Zeile(
                name: "Innenseiten U2+U3",
                wert: innenwert,
                erklaerung: innensatz,
                eingestellt: true,
                wo: "Ganzes Buch \u{2192} Titel, Umschlag und Rücken\u{2026}"))
            if u.innenseitenBogen {
                zeilen.append(innenzeile(reise))
            }
        }

        return Abschnitt(titel: "Der Umschlag", zeilen: zeilen)
    }

    private static func rueckenzeile(_ reise: Reise) -> Zeile {
        let mm = Umschlagmass.rueckenbreite(reise.umschlag, format: reise.format,
                                            innenseiten: reise.innenseiten)
        let herkunft = Umschlagmass.rueckenherkunft(reise.umschlag, format: reise.format,
                                                    innenseiten: reise.innenseiten)
        var satz = "Die Zahl ist " + herkunft + "; verbindlich ist die Angabe "
        satz += "des Druckdienstes. Sie hängt an der Seitenzahl des Innenteils "
        satz += "(\(reise.innenseiten))."
        var breitentext = "ohne Rücken"
        if mm > 0.05 { breitentext = Druckvorgabe.zahl(mm) + " mm" }
        return Zeile(name: "Rückenbreite",
                     wert: breitentext,
                     erklaerung: satz,
                     eingestellt: true,
                     wo: "Ganzes Buch \u{2192} Titel, Umschlag und Rücken\u{2026}")
    }

    private static func innenzeile(_ reise: Reise) -> Zeile {
        let traegt = reise.umschlagTraegtInhalt
        var satz = "Die Innenseiten bleiben leer bzw. tragen die eingestellte Farbe."
        if traegt {
            satz = "Die erste und die letzte Tagebuchseite stehen auf U2 und U3. "
            satz += "Dadurch liegt jede folgende Seite auf der anderen Buchhälfte: "
            satz += "Was rechts lag, liegt links. Der Innenteil wird um zwei Seiten "
            satz += "kürzer, und der Rücken entsprechend dünner."
            if reise.umschlag.innenseitenImBlock {
                satz = "Die erste und die letzte Tagebuchseite sind U2 und U3 und stehen "
                satz += "im INNENTEIL, wie Saal Digital es verlangt: Seite 1 der Datei ist "
                satz += "links und wird mit dem vorderen Deckel verklebt, die letzte rechts "
                satz += "mit dem hinteren. Beide zählen in der Seitenzahl mit; die "
                satz += "Umschlagdatei trägt nur die Außenseite."
            }
        }
        return Zeile(name: "Inhalt auf U2+U3",
                     wert: traegt ? "ja" : "nein",
                     erklaerung: satz,
                     eingestellt: true,
                     wo: "Ganzes Buch \u{2192} Titel, Umschlag und Rücken\u{2026}")
    }

    // MARK: - Die Bilder

    private static func bilder(_ reise: Reise, guete: Bildguete,
                               befund: String) -> Abschnitt
    {
        var zeilen: [Zeile] = []
        let dpi = Int(guete.zieldpi)
        let jpeg = Int((guete.jpegGuete * 100).rounded())
        var gueteSatz = "Höchstens \(guete.kante) Bildpunkte je Kante, "
        gueteSatz += "Ziel \(dpi) dpi, JPEG mit \(jpeg) %. "
        gueteSatz += "Jedes Bild bekommt so viele Bildpunkte, wie sein Platz "
        gueteSatz += "auf dem Papier trägt."
        zeilen.append(Zeile(
            name: "Bildgüte",
            wert: guete.name,
            erklaerung: gueteSatz,
            eingestellt: true,
            wo: "Mehr \u{2192} Als PDF sichern\u{2026}"))
        if !befund.isEmpty {
            zeilen.append(Zeile(name: "Für dieses Buch gerechnet", wert: "",
                                erklaerung: befund, eingestellt: false))
        }
        var fuss = "Gerechnet mit der Güte, mit der ausgegeben wird, wenn niemand "
        fuss += "etwas umstellt. Im Ausgabeblatt lässt sie sich je Ausgabe wählen; "
        fuss += "diese Zeilen folgen dann der Wahl."
        return Abschnitt(titel: "Die Bilder", zeilen: zeilen, fuss: fuss)
    }

    // MARK: - Zum Kopieren

    // Eine Zahl, die man abschreiben oder abfotografieren muss, kommt
    // verkürzt an — dieselbe Bauweise wie bei „Zustellung prüfen" in
    // Schulalarm und beim Kartenmesser der Abfahrtstafel. Gebaut wird der
    // Text aus DENSELBEN Abschnitten, die auf dem Bildschirm stehen; zwei
    // Fassungen nennten zwei Zahlen.
    static func text(_ reise: Reise, guete: Bildguete = .vorgabe,
                     bildbefund: String = "") -> String
    {
        var zeilen: [String] = []
        zeilen.append("Ausgabeformat \u{2014} " + reise.anzeigename)
        let datum = DateFormatter.localizedString(from: Date(), dateStyle: .medium,
                                                  timeStyle: .short)
        zeilen.append(datum)
        for abschnitt in abschnitte(reise, guete: guete, bildbefund: bildbefund) {
            zeilen.append("")
            zeilen.append("\u{2014} " + abschnitt.titel)
            for zeile in abschnitt.zeilen {
                var text = zeile.name
                if !zeile.wert.isEmpty { text += ": " + zeile.wert }
                if zeile.eingestellt { text += "  [Einstellung]" }
                zeilen.append(text)
                if !zeile.erklaerung.isEmpty {
                    zeilen.append("    " + zeile.erklaerung)
                }
            }
            if !abschnitt.fuss.isEmpty {
                zeilen.append("    " + abschnitt.fuss)
            }
        }
        return zeilen.joined(separator: "\n")
    }
}
