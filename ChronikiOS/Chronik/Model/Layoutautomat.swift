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
    // Der Umschlag hat seine eigene Gestaltung (ab 1.0.50). Was darin
    // `nil` ist, folgt weiter dem Buch — Abweichung, keine Kopie.
    var umschlag: Umschlag = Umschlag()

    // Der Text unter der Karte DIESES Tages — `nil` heißt: keine Zeile.
    // Gesetzt von `seiten(fuer:)` und sonst nirgends: Der Automat wird je
    // Aufruf neu gebaut und kennt keinen Tag; die fünf Stellen, die eine
    // Karte setzen, sollen ihn trotzdem nicht einzeln durchreichen müssen.
    var kartenzeile: String?

    // KAPITELWEISE (ab 1.0.8): die Texteinträge je Kapitel (Schlüssel: Beginn
    // des Kapitels), gesetzt von `Reise.automat`. Im Lebensbuch stehen sie
    // nach ihrem Datum zwischen den Fotos.
    var kapiteltexte: [Tagesdatum: [Texteintrag]] = [:]

    private var satz: CGRect { gestaltung.satzspiegel(format) }

    // Der Satzspiegel des UMSCHLAGS. Er nimmt dessen eigenen Rand, wenn
    // einer gesetzt ist, und nie den Bundsteg: Ein Umschlag wird nicht
    // gebunden, er wird umgelegt.
    private var umschlagsatz: CGRect {
        Umschlagmass.satzspiegel(format, gestaltung: gestaltung, umschlag: umschlag)
    }

    // Die randabfallende Fläche EINER Umschlaghälfte (ab 1.0.91). Seit der
    // Umschlag ein eigenes Maß und einen eigenen Anschnitt tragen darf,
    // ist sie nicht mehr dieselbe wie die des Buchblocks — ein
    // randabfallendes Titelfoto mit `bogen` liefe sonst an drei Kanten zu
    // kurz.
    private var umschlagbogen: CGRect {
        Umschlagmass.randabfallend(format, gestaltung: gestaltung, umschlag: umschlag)
    }

    // Die Schrift des Umschlags — die des Buchtitels, solange nichts
    // anderes gesetzt ist.
    private var umschlagtitel: Schriftbild {
        var bild = typografie.titel
        if let familie = umschlag.schriftfamilie { bild.familie = familie }
        return bild
    }

    private var umschlagtext: Schriftbild {
        var bild = typografie.flieText
        if let familie = umschlag.schriftfamilie { bild.familie = familie }
        return bild
    }
    private var fuge: Double { gestaltung.fugePt }
    private var bogen: CGRect { gestaltung.randabfallend(format) }

    // EINE REIHE IST EIN STAPEL, KEIN RASTER (ab 1.0.36).
    //
    // Befund des Nutzers 09/2026 zu 1.0.35: „Allerdings ist die Anordnung
    // der Fotos jetzt schon wieder sehr, sehr nüchtern. Alle sind
    // rechtwinklig ausgerichtet, keins davon leicht gedreht oder gar so,
    // dass sich eine Ecke überlappt."
    //
    // Er hat recht, und es war ein Rückschritt von mir: 1.0.34 hatte das
    // Staffeln und Drehen in `reihenIn` eingebaut, und 1.0.35 hat genau
    // diese Funktion durch das Mosaik ersetzt — samt der Mechanik darin.
    //
    // `querfuge` ist der Abstand INNERHALB einer Reihe und darf negativ
    // sein; dann greifen benachbarte Kacheln übereinander. Weil `Mosaik`
    // damit rechnet, werden die Bilder dabei BREITER und die Reihe höher —
    // die Satzbreite bleibt gefüllt. `staffelhub` versetzt jede zweite
    // Kachel nach oben, `neigung` dreht sie.
    //
    // Nur in Stilen, die das vertragen (`Buchstil.lebendig`): In einem
    // Magazin wäre ein schiefes Bild ein Fehler, in einem Album fehlte es.
    private var querfuge: Double { stil.lebendig ? -fuge * 1.1 : fuge }
    private var staffelhub: Double { stil.lebendig ? fuge * 0.9 : 0 }

    // WIE BREIT EINE TEXTSPALTE HÖCHSTENS WIRD (ab 1.0.37).
    //
    // Eine Zahl, EINE Stelle. Gefragt wird sie an jedem Ort, an dem bisher
    // `satz.width` für einen Textblock stand — beim Messen für den Plan,
    // beim Teilen und beim Setzen. Liefen die drei auseinander, würde an
    // einer Breite geteilt und in einer anderen gesetzt: Der Text wäre auf
    // der Seite höher, als der Plan gerechnet hat, und liefe unten heraus.
    //
    // Die Begründung steht an `Gestaltung.textspaltenanteil`.
    // Gemessen wird gegen die SATZBREITE und nicht gegen den Raum, der
    // gerade übrig ist. Sonst käme ein Deckel auf den anderen: Bei „Karte
    // neben dem Text" ist die Spalte schon auf gut die halbe Satzbreite
    // eingeengt, und zwei Drittel DAVON wären ein Streifen. Wer ohnehin
    // weniger bekommt, behält, was er hat — die Zahl ist eine Obergrenze
    // und keine Vorschrift.
    private var satzTextbreite: Double {
        let anteil = min(max(gestaltung.textspaltenanteil, 0.3), 1)
        return satz.width * anteil
    }

    // Wo eine schmale Textspalte in ihrem Raum liegt. Links oder rechts,
    // und der Wechsel geht seitenpaarweise — dieselbe Zählung wie beim
    // Text neben einem Foto, damit auf einer Seite nicht beides
    // gegeneinander steht. Ein Text, der auf jeder Seite an derselben
    // Kante klebt, macht aus dem freien Drittel einen toten Streifen.
    private func textLinks(_ nummer: Int) -> Bool { nummer % 4 < 2 }

    // Gedreht wird nur, wo auch überlappt wird, und immer um denselben
    // Winkel für dasselbe Bild. Eine Karte wird NICHT gedreht: Sie ist eine
    // Auskunft und kein Erinnerungsstück.
    private func neigung(_ kachel: Kachel) -> Double {
        guard stil.lebendig, kachel.kennung != nil else { return 0 }
        return drehwinkel(kachel.kennung)
    }

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
        let satz = umschlagsatz
        var bloecke: [Block] = []
        bloecke.append(Block(
            inhalt: .foto(foto),
            rahmen: Rahmen(umschlagbogen),
            randabfallend: true
        ))

        // Der Titel steht auf einem hellen Feld und nicht frei auf dem Bild.
        // Weiße Schrift auf einem Foto ist genau so lange lesbar, bis
        // jemand ein Bild mit hellem Himmel wählt — und dann ist es der
        // Titel des Buches, der verschwindet.
        let breite = satz.width * 0.72
        let x = satz.minX
        var gross = umschlagtitel
        gross.groesse = gross.groesse * 1.35 * umschlag.titelfaktor
        let titelHoehe = Textmass.hoehe(titel, bild: gross, breite: breite - 40)

        var unter = umschlagtext
        unter.groesse = unter.groesse * 1.15
        let untertext = [untertitel, zeitraum].filter { !$0.isEmpty }.joined(separator: "\n")
        let unterHoehe = untertext.isEmpty ? 0
            : Textmass.hoehe(untertext, bild: unter, breite: breite - 40)

        let feldHoehe = titelHoehe + (unterHoehe > 0 ? unterHoehe + 16 : 0) + 44
        // Wo das Feld senkrecht liegt, sagt seit 1.0.67 der Umschlag. Ohne
        // eigene Angabe ist das 1, also `satz.maxY - feldHoehe` — genau die
        // Zeile, die bis dahin hier stand.
        let luft = Double(satz.height) - feldHoehe
        let anteil = umschlag.geltendeTitellage(mitTitelfoto: true)
        let feldY = Double(satz.minY) + luft * anteil

        bloecke.append(Block(
            inhalt: .flaeche,
            rahmen: Rahmen(x: x, y: feldY, breite: breite, hoehe: feldHoehe),
            grund: Farbwert(rot: stil.papier.rot, gruen: stil.papier.gruen,
                            blau: stil.papier.blau, deckung: 0.93)
        ))
        bloecke.append(Block(
            inhalt: .titel,
            rahmen: Rahmen(x: x + 22, y: feldY + 20, breite: breite - 44, hoehe: titelHoehe),
            abweichung: Schriftabweichung(familie: umschlag.schriftfamilie,
                                          groesse: gross.groesse, farbe: umschlag.titelfarbe,
                                          schatten: umschlag.titelschatten)
        ))
        if unterHoehe > 0 {
            bloecke.append(Block(
                inhalt: .text(untertext),
                rahmen: Rahmen(x: x + 22, y: feldY + 20 + titelHoehe + 12,
                               breite: breite - 44, hoehe: unterHoehe),
                abweichung: Schriftabweichung(familie: umschlag.schriftfamilie,
                                              groesse: unter.groesse, farbe: umschlag.titelfarbe,
                                              schatten: umschlag.titelschatten)
            ))
        }
        return Seite(id: Layoutautomat.titelseitenKennung, bloecke: bloecke,
                     hintergrund: umschlag.hintergrund, ohneSeitenzahl: true)
    }

    private func titelseiteSchlicht(titel: String, untertitel: String,
                                    zeitraum: String) -> Seite
    {
        let satz = umschlagsatz
        var bloecke: [Block] = []
        let breite = satz.width
        var gross = umschlagtitel
        gross.groesse = gross.groesse * 1.9 * umschlag.titelfaktor
        gross.ausrichtung = .mitte
        let titelHoehe = Textmass.hoehe(titel, bild: gross, breite: breite)

        var unter = umschlagtext
        unter.ausrichtung = .mitte
        unter.groesse = unter.groesse * 1.25
        let untertext = [untertitel, zeitraum].filter { !$0.isEmpty }.joined(separator: "\n")
        let unterHoehe = untertext.isEmpty ? 0 : Textmass.hoehe(untertext, bild: unter, breite: breite)

        let gesamt = titelHoehe + (unterHoehe > 0 ? 26 + unterHoehe : 0)
        // Ohne eigene Angabe ist der Anteil 0,5 — und das ist auf den Punkt
        // `satz.midY - gesamt / 2`, die Zeile, die bis 1.0.66 hier stand.
        let luft = Double(satz.height) - gesamt
        let anteil = umschlag.geltendeTitellage(mitTitelfoto: false)
        var y = Double(satz.minY) + luft * anteil

        bloecke.append(Block(
            inhalt: .titel,
            rahmen: Rahmen(x: satz.minX, y: y, breite: breite, hoehe: titelHoehe),
            abweichung: Schriftabweichung(familie: umschlag.schriftfamilie,
                                          groesse: gross.groesse, ausrichtung: .mitte,
                                          farbe: umschlag.titelfarbe,
                                          schatten: umschlag.titelschatten)
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
                abweichung: Schriftabweichung(familie: umschlag.schriftfamilie,
                                              groesse: unter.groesse, ausrichtung: .mitte,
                                              farbe: umschlag.titelfarbe,
                                              schatten: umschlag.titelschatten)
            ))
        }
        return Seite(id: Layoutautomat.titelseitenKennung, bloecke: bloecke,
                     hintergrund: umschlag.hintergrund, ohneSeitenzahl: true)
    }

    // MARK: - Schmutztitel und Schlussseite

    // ZWEI SEITEN, DIE DEN UMFANG AUFFÜLLEN (ab 1.0.98).
    //
    // Ansage des Nutzers, 09/2026: „Der Druckdienst, bei dem ich jetzt
    // hochladen möchte, nimmt die Datei mit 62 Innenseiten nicht an, wenn
    // das nächste Raster bei ihm 64 Seiten ist. Das heißt, er fügt nicht
    // selbst Seiten hinzu, sondern möchte, dass ich das mache."
    //
    // Ein Buchblock wird in BOGEN gedruckt, und ein Bogen trägt vier,
    // acht oder sechzehn Seiten. Manche Dienste füllen selbst auf, andere
    // weisen die Datei ab — und dann fehlen genau zwei oder vier Seiten,
    // die niemand gestalten wollte.
    //
    // **Der SCHMUTZTITEL ist die traditionelle Antwort darauf.** Er steht
    // seit jeher vorn im Buch: der Titel noch einmal, klein, auf weißem
    // Papier, ohne Bild. Er füllt nicht nur, er gehört dorthin — anders
    // als eine leere Seite, die man an den Anfang setzt, weil eine Zahl
    // nicht aufgeht.
    //
    // Gesetzt wird er im SATZSPIEGEL DES BUCHES und mit dessen Schriften,
    // nicht mit denen des Umschlags: Er ist eine Seite des Buchblocks und
    // wird auf dasselbe Papier gedruckt wie der Text.
    func schmutztitel(titel: String, untertitel: String, zeitraum: String) -> Seite {
        var bloecke: [Block] = []
        let breite = Double(satz.width)

        var gross = typografie.titel
        gross.ausrichtung = .mitte
        let titelHoehe = Textmass.hoehe(titel, bild: gross, breite: breite)

        var unter = typografie.flieText
        unter.ausrichtung = .mitte
        let untertext = [untertitel, zeitraum].filter { !$0.isEmpty }.joined(separator: "\n")
        let unterHoehe = untertext.isEmpty ? 0
            : Textmass.hoehe(untertext, bild: unter, breite: breite)

        // Er steht im oberen Drittel und nicht in der Mitte — so steht ein
        // Schmutztitel im Buch, und er unterscheidet sich damit auch von
        // der Titelseite, die er wiederholt.
        let gesamt = titelHoehe + (unterHoehe > 0 ? 18 + unterHoehe : 0)
        var y = Double(satz.minY) + max(0, Double(satz.height) - gesamt) * 0.28

        bloecke.append(Block(
            inhalt: .titel,
            rahmen: Rahmen(x: Double(satz.minX), y: y, breite: breite, hoehe: titelHoehe),
            abweichung: Schriftabweichung(groesse: gross.groesse, ausrichtung: .mitte)
        ))
        y += titelHoehe + 18
        if !untertext.isEmpty {
            bloecke.append(Block(
                inhalt: .text(untertext),
                rahmen: Rahmen(x: Double(satz.minX), y: y, breite: breite, hoehe: unterHoehe),
                abweichung: Schriftabweichung(groesse: unter.groesse, ausrichtung: .mitte)
            ))
        }
        // Kennung, Hintergrund und „keine Seitenzahl" stehen an EINER
        // Stelle (`Reise.leererSchmutztitel`, ab 1.0.99) — hier kommen nur
        // die Blöcke hinein. Sonst sähe die Seite, die eine Prüfung
        // ansieht, anders aus als die, die gedruckt wird.
        var seite = Reise.leererSchmutztitel
        seite.bloecke = bloecke
        return seite
    }

    /// Die letzte Seite: leer und weiß. Sie trägt keinen einzigen
    /// gerechneten Block — was dort steht, hat jemand selbst hingelegt.
    func schlussseite() -> Seite { Reise.leereSchlussseite }

    // MARK: - Die Rückseite des Buches

    // Sie ist die LINKE Hälfte des Umschlagbogens (ab 1.0.50).
    //
    // Gebaut wird sie nach denselben zwei Regeln wie die Titelseite: Mit
    // Foto ist sie ein Plakat, ohne ein ruhiges Textblatt. Was dort steht,
    // ist Sache des Nutzers — eine Rückseite, die sich ihren Text ausdenkt
    // (ein Klappentext aus dem Tagebuch etwa), wäre genau die Art
    // Behauptung, die diese App nicht aufstellt.
    //
    // Sie trägt `ohneSeitenzahl` und in `seitenfolge` den `Buchteil`
    // `.rueckseite` — sie liegt damit links auf dem Umschlagbogen, und der
    // ist seit 1.0.52 ein eigener Bogen außerhalb der Zählung. Bis dahin
    // hing die Paarung an der Nummer 0, und genau das schob die erste
    // Seite des Buchblocks auf die linke Hälfte.
    func rueckseite(text: String, foto: UUID?) -> Seite {
        let satz = umschlagsatz
        var bloecke: [Block] = []

        if let foto, fotoIndex[foto] != nil {
            bloecke.append(Block(
                inhalt: .foto(foto),
                rahmen: Rahmen(umschlagbogen),
                randabfallend: true
            ))
        }

        let inhalt = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !inhalt.isEmpty {
            var bild = umschlagtext
            bild.ausrichtung = .mitte
            let hoehe = Textmass.hoehe(inhalt, bild: bild, breite: satz.width)
            // Unten, nicht mittig: Oben liegt bei einem Foto das Motiv,
            // und im Buchhandel steht der Text einer Rückseite unten.
            let y = min(satz.maxY - hoehe, satz.midY)
            bloecke.append(Block(
                inhalt: .text(inhalt),
                rahmen: Rahmen(x: satz.minX, y: y, breite: satz.width, hoehe: hoehe),
                abweichung: Schriftabweichung(familie: umschlag.schriftfamilie,
                                              ausrichtung: .mitte)
            ))
        }

        return Seite(id: Layoutautomat.rueckseitenKennung, bloecke: bloecke,
                     hintergrund: umschlag.hintergrund, ohneSeitenzahl: true)
    }

    // Die Rückseite hat eine FESTE Kennung — wie die Titelseite. Woran das
    // hängt: `Seite.id.saat` bestimmt Papierkorn und Wasserzeichenlage, und
    // eine Kennung, die bei jedem Neuzeichnen eine andere wäre, ließe den
    // Grund der Rückseite bei jedem Durchgang anders aussehen.
    static let rueckseitenKennung = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    static let titelseitenKennung = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!

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
        // Die Kartenzeile dieses Tages einhängen, bevor gesetzt wird
        // (ab 1.0.87). Eine Kopie mit gesetztem Feld statt einer
        // Durchreichung durch fünf Aufrufstellen — und `seiten(fuer:)` ist
        // die einzige Stelle, die den Tag überhaupt kennt.
        var ich = self
        ich.kartenzeile = tag.kartentextZeigen
            ? (tag.kartentext.isEmpty ? "Kartenunterschrift" : tag.kartentext)
            : nil
        // KAPITELWEISE: Im Lebensbuch setzt das Kapitel seine Seiten selbst
        // (Zeitung, Meldungen, Fotos, Text) — außer es trägt ein eigenes
        // Muster. In jedem anderen Stil kommen Zeitung und Meldungen vor
        // die gewohnten Seiten.
        if ich.istLebensbuch, tag.muster == nil { return ich.lebensseiten(tag) }
        let vorn = ich.sonderseiten(tag)
        let fotos = tag.fotos.compactMap { fotoIndex[$0] }.filter { !$0.abgelegt }
        if !vorn.isEmpty, fotos.isEmpty, tag.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return vorn
        }
        return vorn + ich.seitenBauen(tag)
    }

    private func seitenBauen(_ tag: Reisetag) -> [Seite] {
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
                // Alles, was `kopfzeile` legt — auch die zweite Überschrift
                // und das Wetter; sonst stünden sie doppelt da.
                bloecke.removeAll {
                    $0.inhalt == .datum || $0.inhalt == .titel || $0.inhalt == .linie
                        || $0.inhalt == .unterueberschrift || $0.inhalt == .wetter
                }
                bloecke.append(contentsOf: kopfzeile(tag: tag, y: &textY, knapp: false,
                                                     x: textX, breite: textBreite))
                var neu = bloecke
                (neu, textY, restText) = textSpalte(neu, y: textY, x: textX,
                                                    breite: textBreite, text: restText)
                bloecke = neu
                if karteOffen, textY + textBreite / 1.4 < satz.maxY {
                    let hoehe = textBreite / 1.4
                    bloecke.append(contentsOf: karteBloecke(x: textX, y: textY,
                                                           breite: textBreite, hoehe: hoehe))
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
                // DIE DRITTE STELLE, und sie hat `angelegt` bis 1.0.89
                // nicht gefragt. Sie fällt nur auf, wenn das Bild hier
                // gedreht IST — der Automat dreht an dieser Stelle nichts,
                // von Hand gedreht wird es trotzdem. Seit 1.0.90 legt die
                // Reparatur beim Öffnen jede Zeile ohne Handarbeit an ihr
                // Bild an; hier steht es zusätzlich, damit es gar nicht
                // erst schief entsteht.
                let band = fotoblock(aufmacher, x: links, y: y, breite: breite, hoehe: hoehe)
                bloecke.append(band)
                if let zeile = unterschriftBlock(aufmacher, x: links, y: y + hoehe,
                                                 breite: breite)
                {
                    bloecke.append(angelegt(zeile, an: band))
                }
                y += hoehe + unterschriftHoehe(aufmacher, breite: breite) + fuge + 4
            }
            (bloecke, y, restText) = textSpalte(bloecke, y: y, x: satz.minX,
                                                breite: satz.width, text: restText)

        case .karteOben:
            if karteOffen {
                let hoehe = min(satz.width / 2.9, satz.height * 0.3)
                bloecke.append(contentsOf: karteBloecke(x: satz.minX, y: y,
                                                       breite: satz.width, hoehe: hoehe))
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
                bloecke.append(contentsOf: karteBloecke(x: satz.maxX - karteBreite, y: y,
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
            : Textmass.hoehe(text, bild: typografie.flieText, breite: satzTextbreite)
        // Gemessen mit einer Reihenhöhe von einem Drittel der Seite — also
        // so, wie `Mosaik` die Seite wirklich füllt. `zielhoehe` stand hier
        // bis 1.0.34 und rechnet aus der ZAHL der Kacheln; seit die Reihen
        // die Seite füllen, schätzte das die Bilder zu klein und den Tag
        // damit zu kurz.
        let bilderHoehe = offen.isEmpty ? 0
            : stapelhoehe(offen, breite: satz.width,
                          ziel: Double(satz.height) / 3, hub: 0)
        // Die Verhältnissumme trägt die Zielreihenhöhe des Tages (siehe
        // `Tagesplan.zielreihenhoehe`): Aus ihr und der Fläche, die den
        // Bildern bleibt, folgt genau eine Höhe — und damit sind die Fotos
        // eines Tages auf allen seinen Seiten ungefähr gleich groß.
        let verhaeltnissumme = offen.reduce(0.0) { $0 + $1.verhaeltnis }
        let plan = Tagesplan.bauen(textHoehe: textHoehe, bilderHoehe: bilderHoehe,
                                   kacheln: offen.count,
                                   verhaeltnissumme: verhaeltnissumme,
                                   satzbreite: Double(satz.width),
                                   kopf: kopfhoehe,
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
            // IN EINER BILDERREICHEN GANGART BLEIBT DER TEXT BEISAMMEN.
            //
            // Ansage des Nutzers 09/2026: „Dann habe ich vielleicht 25 Fotos
            // und nur 5 Sätze Text. Dann bietet es sich vielleicht doch an,
            // eine reine Bilderseite zu machen, und den Text nicht noch
            // weiter auseinanderzuziehen." Fünf Sätze über sechs Seiten
            // verteilt sind auf jeder Seite ein Rest.
            let textZiel: Double = restSeiten > 1 && plan.gangart != .bilderreich
                ? min(restTextHoehe / Double(restSeiten) * 1.25, Double(platz.height))
                : Double(platz.height)
            let vorher = (offen.count, text.count)
            let neue = seiteFuellen(platz: platz, nummer: nummer,
                                    plan: plan, textZiel: textZiel,
                                    offen: &offen, text: &text)
            bloecke.append(contentsOf: neue)
            restTextHoehe = text.isEmpty ? 0
                : Textmass.hoehe(text, bild: typografie.flieText, breite: satzTextbreite)
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
            let restbreite = satzTextbreite
            let hoehe = Textmass.hoehe(text, bild: typografie.flieText, breite: restbreite)
            bloecke.append(Block(
                inhalt: .text(text),
                rahmen: Rahmen(x: satz.minX, y: satz.minY, breite: restbreite, hoehe: hoehe)
            ))
        }
        if !bloecke.isEmpty || seiten.isEmpty { seiten.append(Seite(bloecke: bloecke)) }
        return seiten
    }

    // EINE Seite — und zwar eine GEFÜLLTE.
    //
    // Was auf die Seite gehört, sagt der Plan; wie es liegt, rechnet
    // `Mosaik`. Es gibt hier keine Seitenformen mehr: Ob der Text neben
    // einem Foto steht, über einer Reihe oder allein, ist kein Fall aus
    // einer Liste, sondern das Ergebnis aus Textmenge, Bildformaten und
    // Platz.
    private func seiteFuellen(platz: CGRect, nummer: Int,
                              plan: Tagesplan, textZiel: Double,
                              offen: inout [Kachel], text: inout String) -> [Block]
    {
        let zeilenhoehe = max(typografie.flieText.zeilenhoehe, 1)

        // Der Textanteil DIESER Seite. Geteilt wird an der vollen
        // Satzbreite: Steht der Text später in einer schmaleren Spalte,
        // wird er höher und schmaler — die FLÄCHE bleibt ungefähr dieselbe,
        // und um die geht es beim Verteilen.
        var kopf = ""
        if !text.isEmpty, textZiel > zeilenhoehe * 2.5 {
            // Geteilt wird an der SPALTENbreite und nicht an der Satzbreite
            // (ab 1.0.37). Wer an der vollen Breite teilt und in zwei
            // Dritteln setzt, gibt der Seite anderthalbmal so viel Text, wie
            // gemessen wurde — und der läuft unten heraus.
            let (vorn, hinten) = Textmass.teilen(
                text, bild: typografie.flieText,
                groesse: CGSize(width: min(platz.width, satzTextbreite),
                                height: min(textZiel, platz.height))
            )
            if !vorn.isEmpty {
                kopf = vorn
                text = hinten
            }
        }

        // WIE VIELE BILDER FÜLLEN DIESE SEITE?
        //
        // Gerechnet wird aus der ZIELHÖHE des Tages und dem Platz, der
        // nach dem Text bleibt — nicht mehr aus „offene Kacheln geteilt
        // durch restliche Seiten" (bis 1.0.41). Eine Zählung sagt nichts
        // über die Größe: Zwei randbündige Hochformate untereinander
        // füllen eine Seite genauso gut wie sechs kleine Kacheln, und
        // genau daran hingen die riesigen Einzelbilder.
        //
        // Der Plan macht damit einen Vorschlag; ob er aufgeht, weiß erst
        // die Seite. Bleibt zu viel Luft, kommt ein Bild dazu; wird es zu
        // eng, geht eines zurück.
        let verhaeltnisse = offen.map(\.verhaeltnis)
        // Wie viel Höhe der Text dieser Seite ungefähr nimmt. Eine
        // Schätzung an der Spaltenbreite — wo er wirklich steht (über die
        // Breite oder neben einem Foto), entscheidet `mosaik`; hier geht
        // es nur um den Startwert, den die Schleife danach korrigiert.
        let textstreifen = kopf.isEmpty ? 0
            : min(Double(platz.height),
                  Textmass.hoehe(kopf, bild: typografie.flieText,
                                 breite: min(Double(platz.width), satzTextbreite)) + fuge)
        let fuerBilder = max(Double(platz.height) - textstreifen, 1)
        var anzahl = offen.isEmpty ? 0
            : max(1, plan.kachelnFuer(verhaeltnisse: verhaeltnisse,
                                      hoehe: fuerBilder, breite: Double(platz.width)))

        // KEINE HUNGERNDE LETZTE SEITE (ab 1.0.42).
        //
        // Gemeldet 09/2026: „so ungeschickt über vier Seiten, dass
        // tatsächlich am Ende die Fotos alleine auf der Seite stehen."
        // Genau das entsteht, wenn nach dieser Seite noch ein oder zwei
        // Kacheln übrig bleiben: Die nächste Seite kann sie nicht füllen,
        // und dehnen darf sie sie nicht.
        //
        // Passt ALLES Offene noch auf diese Seite — gemessen an der
        // Zielhöhe und der Stauchung, die ohnehin erlaubt ist —, kommt es
        // mit. Die Bilder werden dann etwas kleiner als das Tagesziel;
        // das ist der geringere Schaden als eine Seite zu einem Viertel.
        // Der Grenzwert ist die Dehnungsgrenze selbst und keine zweite
        // Zahl: Bei mehr als dieser Stauchung ginge die Spalte über den
        // Kasten hinaus, und die letzte Reihe fiele wieder heraus.
        //
        // `mindestens` ist die Untergrenze für die Schrumpfschleife. Sie steht auf 1 und
        // nicht auf dem Startwert: Überfüllt die geschätzte Zahl die
        // Seite, muss die Schleife sie senken dürfen. Nur der Fall unten
        // hebt sie an — was der Seite ausdrücklich mitgegeben wurde, darf
        // sie nicht gleich wieder abgeben.
        var mindestens = 1
        if !offen.isEmpty, text.isEmpty,
           plan.spaltenhoehe(verhaeltnisse: verhaeltnisse[...],
                             breite: Double(platz.width)) <= fuerBilder * Self.dehnungsgrenze
        {
            anzahl = offen.count
            mindestens = offen.count
        }

        // GEHALTEN WIRD DER BESTE VERSUCH, NICHT DER LETZTE (ab 1.0.42).
        //
        // Zwischen zwei Kachelzahlen kann die Seite springen: Mit drei
        // Bildern bleibt die Spalte zu hoch, mit zweien zu niedrig, und
        // keine der beiden liegt im erlaubten Band. Bis 1.0.41 nahm die
        // Schleife dann, was im zehnten Durchgang zufällig dastand.
        // Gewertet wird jetzt wie in `Mosaik.beste`: am wenigsten gedehnt
        // oder gestaucht gewinnt. Und wer eine Zahl schon versucht hat,
        // versucht sie nicht wieder — sonst drehte sich die Schleife nur.

        // Wie gut eine Kachelzahl sitzt: je näher die Dehnung an 1, desto
        // besser. Eine Dehnung von null oder darunter gibt es, wenn
        // Unterschriften und Fugen den Kasten schon allein füllen — die
        // zählt nie als bester Versuch.
        func guete(_ versuch: Mosaikbau) -> Double {
            versuch.dehnung > 0 ? abs(log(versuch.dehnung)) : .infinity
        }
        var bau: Mosaikbau?
        var versucht = Set<Int>()
        for _ in 0..<10 {
            guard !versucht.contains(anzahl) else { break }
            versucht.insert(anzahl)
            guard let versuch = mosaik(platz: platz, nummer: nummer, text: kopf,
                                       gruppe: Array(offen.prefix(anzahl)),
                                       ziel: plan.zielhoehe)
            else { break }
            if let bisher = bau {
                if guete(versuch) < guete(bisher) { bau = versuch }
            } else {
                bau = versuch
            }
            if versuch.dehnung > Self.dehnungsgrenze, anzahl < offen.count {
                anzahl += 1
                continue
            }
            if versuch.dehnung < 1 / Self.dehnungsgrenze, anzahl > mindestens {
                anzahl -= 1
                continue
            }
            break
        }

        guard let fertig = bau else {
            // Weder Text noch Bild — dann bleibt die Seite, wie sie ist.
            return []
        }
        if fertig.kacheln > 0 { offen.removeFirst(min(fertig.kacheln, offen.count)) }
        return fertig.bloecke
    }

    // Wie weit eine Reihe über ihre natürliche Höhe hinaus gedehnt werden
    // darf. Gedehnt heißt: Das Bild wird höher, als sein Verhältnis vorgibt,
    // und verliert dafür seitlich etwas — der Rahmen wird GEFÜLLT, nicht
    // eingepasst. Bei 1,22 sind das gut 18 Prozent der Breite. Mehr wäre
    // genau der Ausschnitt, den 1.0.34 am Aufmacherband abgestellt hat.
    private static let dehnungsgrenze: Double = 1.22

    // Wie weit eine einzelne Reihe über die Zielhöhe des Tages hinausgehen
    // darf. Eine Zahl, die GEWÄHLT und nicht gemessen ist: Ein Drittel
    // lässt Platz für einen Akzent, ohne dass ein Foto zum Fünffachen
    // seiner Nachbarn wird — und das war der Befund.
    private static let reihendeckel: Double = 1.3

    private struct Mosaikbau {
        var bloecke: [Block]
        var dehnung: Double
        var kacheln: Int
    }

    // Die Rechnung für eine Seite: erst die Textreihe, dann die Fotoreihen
    // in dem, was übrig bleibt.
    private func mosaik(platz: CGRect, nummer: Int, text: String,
                        gruppe: [Kachel], ziel: Double) -> Mosaikbau?
    {
        guard !text.isEmpty || !gruppe.isEmpty else { return nil }
        // Ausdrücklich `Double` und nicht `CGFloat`: Aus der Breite werden
        // hier Reihenhöhen und Kachelbreiten gerechnet, und die Regel
        // dieses Repos gilt an jeder Stelle, an der ein Maß aus einem
        // `CGRect` in eine Rechnung geht.
        let breite = Double(platz.width)
        var fotos = gruppe
        // WIE HOCH EINE REIHE HÖCHSTENS WIRD (ab 1.0.42).
        //
        // Die Zielhöhe des Tages, plus die Toleranz, die eine einzelne
        // Reihe darüber hinausgehen darf. Ohne diesen Deckel folgte die
        // Höhe einer Reihe zwingend aus der Satzbreite — und ein
        // Hochformat allein in einer Reihe nahm damit gut 85 Prozent der
        // Seite. Was über dem Deckel läge, wird nicht höher, sondern
        // SCHMALER: Die Kacheln behalten ihr Verhältnis und die Reihe
        // steht mittig.
        let deckel = ziel * Self.reihendeckel

        // ---- Die Textreihe
        //
        // Drei Fälle, und keiner davon ist eine Vorlage: Ohne Bilder steht
        // der Text in seiner HÖCHSTBREITE, also in zwei Dritteln der
        // Satzbreite (ab 1.0.37, siehe `Gestaltung.textspaltenanteil`) —
        // was daneben frei bleibt, ist Rand. Braucht er dort schon mehr als
        // die halbe Seite, bekommt er diese Breite ebenfalls ganz; ein Foto
        // in dem schmalen Rest wäre eine Briefmarke. Sonst sucht
        // `Mosaik.mischreihe` die Breite, bei der Text und Bilder
        // NEBENEINANDER aufgehen, und die ist nochmals schmaler.
        let hoechstbreite = min(breite, satzTextbreite)
        var textbreite = hoechstbreite
        var texthoehe: Double = 0
        var textreihe: [Kachel] = []
        var textreihenhoehe: Double = 0
        if !text.isEmpty {
            let voll = Textmass.hoehe(text, bild: typografie.flieText, breite: hoechstbreite)
            texthoehe = voll
            textreihenhoehe = voll
            if !fotos.isEmpty, voll <= platz.height * 0.56 {
                let daneben = min(fotos.count, voll > platz.height * 0.32 ? 1 : 2)
                let neben = Array(fotos.prefix(daneben))
                if let mischung = Mosaik.mischreihe(
                    fotos: neben.map(\.verhaeltnis), breite: breite, quer: querfuge,
                    fuge: fuge,
                    kleinste: breite * 0.30, groesste: hoechstbreite, stufen: 12,
                    hoechstens: deckel,
                    texthoehe: { Textmass.hoehe(text, bild: typografie.flieText, breite: $0) }
                ) {
                    fotos.removeFirst(daneben)
                    textreihe = neben
                    textbreite = mischung.textbreite
                    texthoehe = mischung.texthoehe
                    textreihenhoehe = mischung.hoehe + (neben.map(\.unterschrift).max() ?? 0)
                }
            }
        }

        // ---- Die Fotoreihen in dem, was übrig bleibt
        let luft: Double = textreihenhoehe > 0 && !fotos.isEmpty ? fuge + 4 : 0
        let uebrig = Double(platz.height) - textreihenhoehe - luft
        var spalte: Mosaik.Spalte?
        if !fotos.isEmpty, uebrig > 40 {
            // Die Bildunterschriften gehen in die Rechnung ein und nicht
            // als Zuschlag hinterher: `Mosaik.spalte` zieht sie von der
            // freien Höhe ab, bevor es die Dehnung bildet. Sonst hielten
            // die Reihen ihre Höhe nicht, sobald Unterschriften
            // eingeschaltet sind.
            //
            // Bis fünf Reihen statt vier: Mit dem Deckel passen mehr
            // Kacheln auf eine Seite, und ohne die fünfte Reihe müsste
            // `beste` sie in vier zu breite Reihen zwängen.
            spalte = Mosaik.beste(fotos.map(\.verhaeltnis), breite: breite,
                                  quer: querfuge, fuge: fuge,
                                  hoehe: uebrig, reihen: 1...5,
                                  staffel: staffelhub * 2, hoechstens: deckel,
                                  unterschrift: { fotos[$0].unterschrift })
        }

        // ---- Setzen
        var bloecke: [Block] = []
        var y = Double(platz.minY)
        var gesetzteKacheln = textreihe.count
        var dehnung = spalte?.dehnung ?? 1
        // Bricht eine Reihe ab, weil sie nicht mehr passt, darf danach
        // KEINE weitere gesetzt werden: Die Kacheln liegen in einer Folge,
        // und `seiteFuellen` nimmt hinterher die ersten `gesetzteKacheln`
        // aus dem Vorrat. Würde Reihe 2 übersprungen und Reihe 3 gesetzt,
        // wären zwei Bilder vertauscht — still und unauffindbar.
        var abgebrochen = false

        // WO DER TEXT IN DER SPALTE STEHT (ab 1.0.37).
        //
        // Ansage des Nutzers, 09/2026: „Auch hier wäre es dann gut,
        // vielleicht verschiedene Textblöcke zu haben, die sich mit den
        // Bildern abwechseln."
        //
        // Bis 1.0.36 gab es genau zwei Lagen — ganz oben oder ganz unten
        // (`textOben = nummer % 2 == 0`). Damit stand auf jeder Seite ein
        // Block Text und darunter (oder darüber) ein Block Bilder; einen
        // Wechsel gab es nur von Seite zu Seite, nicht auf der Seite.
        //
        // Die Textreihe ist jetzt eine Reihe unter den anderen und darf an
        // jeder Stelle der Spalte stehen: 0 heißt oben, `reihen.count`
        // unten, alles dazwischen ZWISCHEN zwei Fotoreihen. Gewählt wird
        // aus der Seitennummer und nicht gewürfelt — derselbe Inhalt ergibt
        // denselben Satz (dieselbe Regel wie beim Drehwinkel und beim
        // Papierkorn).
        let reihenzahl = spalte?.reihen.count ?? 0
        let stellen = reihenzahl + 1
        let textStelle = stellen > 1 ? nummer % stellen : 0

        func setzeTextreihe() {
            guard !text.isEmpty else { return }
            let links = textLinks(nummer)
            let luecken = Double(max(textreihe.count - 1, 0))
            // Zwischen Text und Fotos steht immer eine ganze Fuge, zwischen
            // zwei Fotos die `querfuge` — die darf überlappen, der Text
            // nicht (siehe `Mosaik.mischreihe`).
            let fotobreite = breite - textbreite - fuge - querfuge * luecken
            let fotospanne = fotobreite + querfuge * luecken
            let bildhoehe = textreihenhoehe - (textreihe.map(\.unterschrift).max() ?? 0)
            var x = Double(platz.minX) + (links ? 0 : fotospanne + fuge)
            bloecke.append(Block(
                inhalt: .text(text),
                rahmen: Rahmen(x: x, y: y, breite: textbreite, hoehe: max(texthoehe, 1))
            ))
            x = links
                ? Double(platz.minX) + textbreite + fuge
                : Double(platz.minX)
            let summe = textreihe.reduce(0.0) { $0 + $1.verhaeltnis }
            for (stelle, kachel) in textreihe.enumerated() {
                let kachelbreite = summe > 0.01 ? fotobreite * (kachel.verhaeltnis / summe) : 0
                let (neue, _) = kachelbloecke(kachel, x: x, y: y,
                                              breite: kachelbreite, hoehe: bildhoehe,
                                              gedreht: neigung(kachel), ebene: stelle % 2)
                bloecke.append(contentsOf: neue)
                x += kachelbreite + querfuge
            }
            y += textreihenhoehe + fuge + 4
        }

        // Der gedeckelte Dehnungsfaktor — einmal gerechnet, von beiden
        // Abschnitten benutzt. Zwei Fassungen ergäben oberhalb und
        // unterhalb des Textes verschieden hohe Reihen.
        //
        // NACH UNTEN GIBT ES KEINE GRENZE MEHR (ab 1.0.42). Sie stand da,
        // solange eine Reihe die Satzbreite füllen MUSSTE: Stauchen hieß
        // dann, das Bild seitlich zu beschneiden. Seit eine Reihe schmaler
        // werden darf, heißt Stauchen „kleiner und mittig" und kostet
        // nichts. Und es rettet die Seite: Mit der alten Grenze wurde die
        // Spalte höher als der Kasten, die letzte Reihe fiel heraus
        // (`abgebrochen`) und ihr Bild landete allein auf der nächsten
        // Seite — genau der gemeldete Fehler. Nach OBEN bleibt die Grenze,
        // denn Dehnen beschneidet weiterhin.
        let faktor = spalte.map { min(max($0.dehnung, 0.05), Self.dehnungsgrenze) } ?? 1

        // Wie hoch die Reihen eines Abschnitts zusammen werden — samt
        // Staffelhub, Unterschriften und Fugen. Gebraucht, um zu wissen, wo
        // der Text hinkommt, wenn er MITTEN in der Spalte steht.
        func abschnittshoehe(_ bereich: Range<Int>) -> Double {
            guard let spalte else { return 0 }
            var summe: Double = 0
            for i in bereich where spalte.reihen.indices.contains(i) {
                let reihe = spalte.reihen[i]
                let hub = reihe.count > 1 ? staffelhub : 0
                let unten = reihe.map { fotos[$0].unterschrift }.max() ?? 0
                summe += min(spalte.hoehen[i] * faktor, deckel) + hub * 2 + unten + fuge
            }
            return summe
        }

        func setzeFotoreihen(_ bereich: Range<Int>, bis grenze: Double, verteilen: Bool) {
            guard let spalte, !fotos.isEmpty, !abgebrochen else { return }
            dehnung = spalte.dehnung
            var gezeichnet: [[UUID]] = []
            for nummerReihe in bereich where spalte.reihen.indices.contains(nummerReihe) {
                let reihe = spalte.reihen[nummerReihe]
                // Der Deckel gilt auch NACH der Dehnung. Sonst holte der
                // Faktor genau das zurück, was er verhindern soll: eine
                // Reihe, die schon an der Obergrenze steht, würde noch
                // einmal um ein Fünftel höher.
                let hoehe = min(spalte.hoehen[nummerReihe] * faktor, deckel)
                let unten = reihe.map { fotos[$0].unterschrift }.max() ?? 0
                // Gestaffelt wird erst ab zwei Kacheln — ein einzelnes Bild
                // steht schief da und sonst nichts, und daneben fehlte der
                // Vergleich, an dem man die Absicht erkennt. Dieselbe
                // Bedingung wie in `Mosaik.spalte`, sonst hielte die Spalte
                // ihre Höhe nicht.
                let hub = reihe.count > 1 ? staffelhub : 0
                if y + hoehe + hub * 2 + unten > grenze + 0.5 {
                    abgebrochen = true
                    break
                }
                let summe = reihe.reduce(0.0) { $0 + fotos[$1].verhaeltnis }
                // Wie breit die Reihe bei DIESER Höhe wird. Steht sie unter
                // ihrer natürlichen Höhe (weil der Deckel gegriffen hat),
                // füllt sie die Satzbreite nicht mehr — dann bleibt links
                // und rechts Rand, und die Reihe steht mittig. Reicht die
                // Höhe dagegen aus, ergibt `min` genau die alte Rechnung:
                // randbündig, und die Dehnung beschneidet das Bild.
                let luecken = querfuge * Double(reihe.count - 1)
                let spanne = min(breite, hoehe * summe + luecken)
                let nutzbreite = spanne - luecken
                var x = Double(platz.minX) + (breite - spanne) / 2
                var kennungen: [UUID] = []
                for (stelle, nummerKachel) in reihe.enumerated() {
                    let kachel = fotos[nummerKachel]
                    let kachelbreite = summe > 0.01
                        ? nutzbreite * (kachel.verhaeltnis / summe)
                        : nutzbreite
                    // Jede zweite Kachel sitzt oben statt unten und liegt
                    // dabei über ihren Nachbarn — so sieht die Überlappung
                    // gelegt aus und nicht verrutscht.
                    let versatz = stelle % 2 == 1 ? 0.0 : hub * 2
                    let (neue, _) = kachelbloecke(kachel, x: x, y: y + versatz,
                                                  breite: kachelbreite, hoehe: hoehe,
                                                  gedreht: neigung(kachel),
                                                  ebene: stelle % 2)
                    bloecke.append(contentsOf: neue)
                    kennungen.append(contentsOf: neue.map(\.id))
                    x += kachelbreite + querfuge
                }
                if !kennungen.isEmpty { gezeichnet.append(kennungen) }
                gesetzteKacheln += reihe.count
                y += hoehe + hub * 2 + unten + fuge
            }
            // Verteilt wird nur im LETZTEN Abschnitt und nur nach unten.
            // Im oberen liefe die gewonnene Luft in den Textblock hinein,
            // und `restplatzVerteilen` kennt ihn nicht — es verschiebt nur
            // die Reihen, die es bekommt.
            if verteilen, gezeichnet.count > 1 {
                bloecke = restplatzVerteilen(bloecke, reihen: gezeichnet,
                                             unten: CGFloat(y - fuge), bis: CGFloat(grenze))
            }
        }

        if text.isEmpty {
            setzeFotoreihen(0..<reihenzahl, bis: Double(platz.maxY), verteilen: true)
        } else if textStelle == 0 {
            setzeTextreihe()
            setzeFotoreihen(0..<reihenzahl, bis: Double(platz.maxY), verteilen: true)
        } else if textStelle >= reihenzahl {
            // Steht der Text unten, gehört ihm sein Streifen schon jetzt —
            // sonst füllten die Reihen die Seite und er fiele heraus.
            setzeFotoreihen(0..<reihenzahl, bis: Double(platz.maxY) - textreihenhoehe - luft,
                            verteilen: true)
            y = max(y, Double(platz.maxY) - textreihenhoehe)
            setzeTextreihe()
        } else {
            // MITTENDRIN. Der obere Abschnitt bekommt genau die Höhe, die
            // seine Reihen brauchen; der Text schließt an, und der Rest
            // gehört dem unteren Abschnitt.
            let oben = abschnittshoehe(0..<textStelle)
            setzeFotoreihen(0..<textStelle, bis: Double(platz.minY) + oben + 0.5,
                            verteilen: false)
            setzeTextreihe()
            setzeFotoreihen(textStelle..<reihenzahl, bis: Double(platz.maxY), verteilen: true)
        }

        return Mosaikbau(bloecke: bloecke, dehnung: dehnung, kacheln: gesetzteKacheln)
    }


    // Eine Kachel als Blöcke — Bild samt Unterschrift, oder die Karte.
    // Zurück kommt auch, wie hoch beides zusammen wird: Die Unterschrift
    // gehört zum Bild, und wer sie beim Weiterrücken vergisst, setzt den
    // nächsten Block darüber.
    private func kachelbloecke(_ kachel: Kachel, x: Double, y: Double, breite: Double,
                               hoehe: Double, gedreht: Double = 0,
                               ebene: Int = 0) -> ([Block], Double)
    {
        var bloecke: [Block] = []
        var unten = hoehe
        switch kachel.inhalt {
        case let .foto(id):
            guard let foto = fotoIndex[id] else { return ([], 0) }
            var block = fotoblock(foto, x: x, y: y, breite: breite, hoehe: hoehe)
            block.drehung = gedreht
            // Die Ebene entscheidet, welches von zwei überlappenden Bildern
            // oben liegt (`Seite.sortiert`).
            block.ebene = ebene
            bloecke.append(block)
            // DIE BILDUNTERSCHRIFT DREHT MIT (ab 1.0.86).
            //
            // Bis 1.0.85 stand hier das Gegenteil, mit dieser Begründung:
            // „Mitgedreht würde sie um ihre EIGENE Mitte gedreht und rückte
            // damit vom Bild ab." Richtig — für eine Drehung, die nur den
            // Winkel setzt. `angelegt(an:)` dreht auch die LAGE, um die
            // Mitte des Bildes, und damit bleibt die Gruppe starr.
            if let zeile = unterschriftBlock(foto, x: x, y: y + hoehe, breite: breite) {
                bloecke.append(angelegt(zeile, an: block))
                unten += unterschriftHoehe(foto, breite: breite)
            }
        case .karte:
            bloecke.append(contentsOf: karteBloecke(x: x, y: y, breite: breite, hoehe: hoehe))
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
        // Die zweite Überschrift steht auch hier, in Weiß wie der Titel
        // (ab 1.0.48). Ihre Höhe geht in die Rechnung ein, bevor `y` gesetzt
        // wird — der Block wird von UNTEN aufgebaut, und eine nachträglich
        // eingeschobene Zeile schiebe sonst den Titel aus dem Satzspiegel.
        let zweite = zweiteUeberschrift(tag)
        var zweitbild = typografie[.unterueberschrift]
        zweitbild.farbe = Farbwert(rot: 1, gruen: 1, blau: 1)
        let zweitHoehe = zweite.isEmpty ? 0
            : Textmass.hoehe(zweite, bild: zweitbild, breite: satz.width * 0.8)
        let zweitLuft = zweite.isEmpty ? 0 : zweitHoehe + 4
        // Das Wetter steht auch hier (ab 1.0.108), in derselben hellen
        // Farbe wie das Datum — und geht wie die zweite Überschrift VOR dem
        // Setzen von `y` in die Rechnung ein.
        let wetterHoehe = wetterhoehe(tag, breite: Double(satz.width * 0.8))
        let wetterLuft = wetterHoehe == 0 ? 0 : wetterHoehe + 4
        var y = satz.maxY - titelHoehe - datumHoehe - zweitLuft - wetterLuft - 6

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
            y += titelHoehe + 4
        }
        if !zweite.isEmpty {
            // Nur die FARBE wird abgewichen. Schrift und Größe holt der
            // Satz über die Rolle des Blocks — sie hier zu kopieren machte
            // aus der Ableitung eine Kopie und hängte die Seite vom Titel ab.
            bloecke.append(Block(
                inhalt: .unterueberschrift,
                rahmen: Rahmen(x: satz.minX, y: y, breite: satz.width * 0.8, hoehe: zweitHoehe),
                abweichung: hell
            ))
            y += zweitHoehe + 4
        }
        if wetterHoehe > 0 {
            bloecke.append(Block(
                inhalt: .wetter,
                rahmen: Rahmen(x: satz.minX, y: y, breite: satz.width * 0.8, hoehe: wetterHoehe),
                abweichung: datumhell
            ))
        }
        return Seite(bloecke: bloecke, ohneSeitenzahl: true)
    }

    // Die zweite Überschrift — leer, wenn das Buch sie nicht zeigt (ab
    // 1.0.116). An EINER Stelle, gefragt von Aufmacher und Kopfzeile.
    private func zweiteUeberschrift(_ tag: Reisetag) -> String {
        guard gestaltung.unterueberschriftZeigen else { return "" }
        return tag.unterueberschrift.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Die Höhe des Wetterblocks: die Tabelle (ab 1.0.116) in ihrer festen
    // Höhe, sonst die Zeile, gemessen wie jeder Text. 0: kein Wetter.
    // In `Double`, wie `Textmass.hoehe`, dessen Platz es einnimmt — die
    // Aufrufer rechnen damit weiter wie zuvor mit der gemessenen Zeile.
    private func wetterhoehe(_ tag: Reisetag, breite: Double) -> Double {
        if let tabelle = tag.geltendeWettertabelle {
            return tabelle.hoehe(bild: typografie.datum, anteil: gestaltung.wettergroesse)
        }
        let wetter = tag.wetter.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !wetter.isEmpty else { return 0 }
        return Textmass.hoehe(wetter, bild: typografie.datum, breite: breite)
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
        // Die ZWEITE Überschrift — der Ort oder das Schlagwort (ab 1.0.48).
        // Sie steht unter der Überschrift und über der Trennlinie, also da,
        // wo sie in der Vorlage steht: nach dem Datum, vor dem Fließtext.
        // Wie der Titel nur auf dem Aufmacher — auf der Fortsetzungsseite
        // wäre sie dieselbe Angabe ein zweites Mal.
        let zweite = zweiteUeberschrift(tag)
        if !zweite.isEmpty, !knapp {
            let bild = typografie[.unterueberschrift]
            let hoehe = Textmass.hoehe(zweite, bild: bild, breite: spaltenbreite)
            bloecke.append(Block(
                inhalt: .unterueberschrift,
                rahmen: Rahmen(x: linksX, y: y, breite: spaltenbreite, hoehe: hoehe)
            ))
            y += hoehe + 5
        }
        // Das WETTER (ab 1.0.108) — unter den Überschriften, in der Schrift
        // der Datumszeile. Auch nur auf dem Aufmacher: Es gilt für den Tag
        // und nicht für die Seite.
        let hoehe = knapp ? 0 : wetterhoehe(tag, breite: Double(spaltenbreite))
        if hoehe > 0 {
            bloecke.append(Block(
                inhalt: .wetter,
                rahmen: Rahmen(x: linksX, y: y, breite: spaltenbreite, hoehe: hoehe)
            ))
            y += hoehe + 5
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
        let textBreite = satzTextbreite
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
                                     platz: satz.maxY - y, hub: staffelhub,
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
            // Auch hier wird gestaffelt und gedreht (wieder ab 1.0.36): Ein
            // Tag ganz ohne Text kommt nicht durch das Mosaik, und drei
            // Bilder in einer Flucht sind dort so nüchtern wie überall
            // sonst. Überlappt wird auf diesem Weg NICHT — die Breiten
            // rechnet `naechsteReihe` mit der ganzen Fuge, und zwei
            // Rechnungen nebeneinander liefen auseinander.
            let hub = reihe.count > 1 ? staffelhub : 0
            if y + hoehe + hub * 2 > satz.maxY, !bloecke.isEmpty {
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
            for (stelle, kachel) in reihe.enumerated() {
                let breite = gestreckt * kachel.verhaeltnis
                let versatz = stelle % 2 == 1 ? 0.0 : hub * 2
                switch kachel.inhalt {
                case let .foto(id):
                    if let foto = fotoIndex[id] {
                        var block = fotoblock(foto, x: x, y: y + versatz,
                                              breite: breite, hoehe: gestreckt)
                        block.drehung = neigung(kachel)
                        block.ebene = stelle % 2
                        bloecke.append(block)
                        reihenbloecke.append(block.id)
                        // Die Unterschrift steht UNTER dem Bild und in
                        // dessen Breite. Die Reihenhöhe hält den Platz
                        // dafür schon frei (`naechsteReihe`); hier wird er
                        // nur noch gefüllt.
                        if let zeile = unterschriftBlock(foto, x: x, y: y + versatz + gestreckt,
                                                         breite: breite)
                        {
                            // Mit derselben Neigung wie das Bild darüber
                            // (ab 1.0.86) — und um dessen Mitte gedreht.
                            let zeile = angelegt(zeile, an: block)
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
                    // Beide Blöcke gehören zur Reihe: `restplatzVerteilen`
                    // schiebt sie auseinander, und eine Zeile, die dabei
                    // liegen bliebe, stünde in der Karte darüber.
                    for block in karteBloecke(x: x, y: y + versatz,
                                              breite: breite, hoehe: gestreckt)
                    {
                        bloecke.append(block)
                        reihenbloecke.append(block.id)
                    }
                default:
                    break
                }
                x += breite + fuge
            }
            if !reihenbloecke.isEmpty { reihenaufSeite.append(reihenbloecke) }
            y += hoehe + hub * 2 + fuge
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

    // DIE KARTE MIT IHRER ZEILE (ab 1.0.87).
    //
    // Zurück kommen ein oder zwei Blöcke, und die Karte wird um die Höhe
    // der Zeile KÜRZER — sie braucht also keinen zusätzlichen Platz.
    //
    // Das ist der Grund, warum diese Fassung an keiner der fünf
    // Aufrufstellen etwas an den Höhen ändern muss: Beim Foto hält
    // `unterschriftHoehe` den Streifen eigens frei und geht in jede
    // Reihenrechnung ein; die Karte hat keine Größe, an der etwas hängt,
    // und ein paar Punkte weniger Karte sieht niemand. Wer das umdreht,
    // rechnet fünf Stellen nach.
    private func karteBloecke(x: Double, y: Double, breite: Double,
                              hoehe: Double) -> [Block]
    {
        let zeile = kartenzeileHoehe(breite: breite)
        // Eine Karte unter 24 Punkten wäre keine mehr — dann bleibt die
        // Zeile weg, statt die Karte zu einem Streifen zu machen.
        let kartenhoehe = hoehe - zeile
        guard zeile > 0, kartenhoehe >= 24 else {
            return [Block(inhalt: .karte,
                          rahmen: Rahmen(x: x, y: y, breite: breite, hoehe: hoehe))]
        }
        // Ohne Schatten (ab 1.0.119): Er steht am BUCH
        // (`Gestaltung.kartenschatten`, sonst der der Fotos) — dieselbe
        // Regel wie beim `fotoblock` darüber.
        let karte = Block(inhalt: .karte,
                          rahmen: Rahmen(x: x, y: y, breite: breite, hoehe: kartenhoehe))
        let unten = Block(inhalt: .kartenunterschrift,
                          rahmen: Rahmen(x: x, y: y + kartenhoehe + kartenfuge,
                                         breite: breite, hoehe: zeile - kartenfuge))
        return [karte, unten]
    }

    // Die Höhe der Kartenzeile — null, solange sie nicht eingeschaltet ist.
    // Der Text kommt aus `kartenzeile`, das `seiten(fuer:)` für DIESEN Tag
    // setzt; der Automat selbst kennt keinen Tag.
    private func kartenzeileHoehe(breite: Double) -> Double {
        guard let text = kartenzeile else { return 0 }
        return Textmass.hoehe(text, bild: typografie.bildunterschrift, breite: breite)
            + kartenfuge
    }

    // Nur wo sie eingeschaltet IST, kostet sie Platz. Bis 1.0.4 rechnete
    // der Automat den Streifen für jeden Text mit und setzte trotzdem nie
    // eine Unterschrift — die Lücke unter dem Bild war da, der Satz nicht.
    private func unterschriftHoehe(_ foto: Foto, breite: Double) -> Double {
        guard foto.unterschriftZeigen else { return 0 }
        let text = foto.unterschrift.isEmpty ? "Bildunterschrift" : foto.unterschrift
        return Textmass.hoehe(text, bild: typografie.bildunterschrift, breite: breite)
            + unterschriftfuge
    }

    // DER WEISSE FOTORAND LIEGT AUSSERHALB DES RAHMENS (ab 1.0.86).
    //
    // Er wird beim Zeichnen über `padding` ergänzt und zählt im Layout
    // nicht mit — die Lehre dazu steht seit 1.0.83 an `Block.umriss`. Die
    // Unterschrift stand deshalb drei Punkte unter dem RAHMEN und damit
    // mitten im weißen Rand: Im Stil „Fotoalbum" sind das 2,6 mm, also gut
    // sieben Punkte, und die Zeile verschwand darunter. Gemeldet 09/2026
    // („sie ist sogar zum großen Teil vom Bild verdeckt") — zusammen mit
    // der Drehung, die den Rest verdeckte.
    // Gerechnet wird sie seit 1.0.92 in `Gestaltung.unterschriftfugePt` —
    // dieselbe Stelle, die auch `Reisewerk.zeilenAnsBildLegen` fragt, wenn
    // es eine schon gesetzte Zeile ausrichtet. Bis 1.0.91 standen hier
    // feste drei Punkte hinter dem weißen Rand; das ist gut ein Millimeter
    // und sieht im Druck aus, als klebte die Zeile am Bild.
    private var unterschriftfuge: Double {
        gestaltung.unterschriftfugePt(fotorand: gestaltung.fotorand)
    }

    // EINE KARTE HAT KEINEN WEISSEN RAND. Ihn mitzurechnen war ein alter
    // blinder Fleck: Die Kartenzeile bekam den Abstand eines Fotos, und
    // die Karte darüber wurde um genau diesen Betrag kürzer, ohne dass
    // irgendwo Weiß gewesen wäre. Gefragt wird deshalb mit `fotorand: 0`.
    private var kartenfuge: Double {
        gestaltung.unterschriftfugePt(fotorand: 0)
    }

    // EINE ZEILE, DIE ZU IHREM BILD GEHÖRT (ab 1.0.86).
    //
    // Sie bekommt dessen Winkel und wird um dessen MITTE gedreht — die
    // beiden bewegen sich damit starr, und die Zeile steht weiter unter dem
    // Bild statt schief daneben oder halb darunter. Dieselbe Rechnung wie
    // beim Drehen von Hand (`Reisewerk.drehe`); zwei Fassungen ergäben
    // einen Satz, der nach dem ersten Anfassen anders aussieht.
    private func angelegt(_ zeile: Block, an bild: Block) -> Block {
        var neu = zeile
        // Dieselbe Ebene wie das Bild: Bei zwei gestaffelten Kacheln liegt
        // die eine oben (`Seite.sortiert`), und eine Zeile auf Ebene 0
        // verschwände unter ihrem eigenen Bild.
        neu.ebene = bild.ebene
        guard abs(bild.drehung) > 0.01 else { return neu }
        neu.rahmen = zeile.rahmen.gedreht(um: bild.rahmen.mitte, grad: bild.drehung)
        neu.drehung = bild.drehung
        return neu
    }

    // Der Block dazu — leer heißt kein Block: Ein Kasten ohne Text wäre auf
    // der Seite unsichtbar und ließe sich doch anfassen.
    private func unterschriftBlock(_ foto: Foto, x: Double, y: Double,
                                   breite: Double) -> Block?
    {
        let hoehe = unterschriftHoehe(foto, breite: breite)
        guard hoehe > 0 else { return nil }
        let fuge = unterschriftfuge
        return Block(inhalt: .bildunterschrift(foto.id),
                     rahmen: Rahmen(x: x, y: y + fuge, breite: breite, hoehe: hoehe - fuge))
    }

    // `hoechstens` deckelt die Höhe des Textes auf dieser Seite. Ohne
    // Deckel füllt er bis zum Satzspiegelende — richtig für ein Muster,
    // das den Text trägt, falsch für eines, das ihn mit Bildern abwechseln
    // soll (`.wechsel`, ab 1.0.29).
    private func textSpalte(_ bloecke: [Block], y: CGFloat, x: CGFloat, breite roh: Double,
                            text: String, hoechstens: Double? = nil)
        -> ([Block], CGFloat, String)
    {
        guard !text.isEmpty else { return (bloecke, y, text) }
        var neue = bloecke
        // DER DECKEL GILT AUCH HIER (ab 1.0.37). Die acht übrigen Muster
        // setzen ihren Text über diese eine Funktion; ihn nur im
        // Mosaik-Weg zu begrenzen hieße, dass „Text zuerst" und „Karte
        // oben" weiter Zeilen von neunzig Zeichen ergäben. Linksbündig,
        // der Rest bleibt Rand: Eine wechselnde Kante ist die Sache des
        // Mosaiks, das seine Seiten zählt — hier gibt es dafür keine
        // Seitennummer, und eine geratene wäre Unruhe statt Rhythmus.
        let breite = min(roh, satzTextbreite)
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
    // nicht mehr, also neue Seite" und „die Reihe wird eben kleiner".
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

// MARK: - KAPITELWEISE: Lebensbuch (ab 1.0.4)
//
// Vorlage des Nutzers 11/2026 (ein Buch „Simon 18" zum 18. Geburtstag):
// Jedes Kapitel ist ein Lebensjahr und beginnt mit der ZEITUNG vom
// Geburtstag (groß, leicht gedreht, daneben ein kurzer Text), dann
// „Was an deinem Geburtstag geschah" (vier Meldungen mit Bild), dann die
// Fotos des Jahres — „relativ groß, aber doch leicht überlappend" —, und am
// Ende der Text des Kapitels neben vier Bildern.
//
// Alles hier sind gewöhnliche Blöcke: Titel, zweite Überschrift,
// Datumszeile, Text mit eigener Schrift (`Schriftabweichung`), Fotos mit
// Drehung und Ebene. Damit gilt für diese Seiten alles, was das Reisebuch
// kann — anfassen, verschieben, drehen, Schrift ändern, Druckprüfung, PDF.
// Steht in einem Kapitel ein eigenes Seitenmuster, gilt das Reisebuch-Satz
// wie bisher; die Zeitungs- und Meldungsseiten kommen in jedem Stil davor.
extension Layoutautomat {
    var istLebensbuch: Bool { stil.id == Buchstil.lebensbuch.id }

    /// Zeitungs- und Meldungsseiten eines Kapitels.
    func sonderseiten(_ tag: Reisetag) -> [Seite] {
        var seiten: [Seite] = []
        if let id = tag.zeitung, let zeitung = fotoIndex[id] {
            seiten.append(zeitungsseite(tag, zeitung: zeitung))
        }
        let meldungen = tag.meldungen.filter {
            !$0.titel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || $0.foto != nil
        }
        if !meldungen.isEmpty { seiten.append(contentsOf: meldungsseiten(tag, meldungen)) }
        return seiten
    }

    /// Das ganze Kapitel im Lebensbuch: Zeitung und Meldungen, dann EIN
    /// Fluss aus Fotos und Texten in ihrer Zeitfolge.
    func lebensseiten(_ tag: Reisetag) -> [Seite] {
        let fotos = tag.fotos.compactMap { fotoIndex[$0] }.filter { !$0.abgelegt }
        let eintraege = kapiteltexte[tag.datum] ?? []
        var fluss: [Fluss]
        if eintraege.isEmpty {
            fluss = fotos.map { .foto($0) }
            let frei = tag.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !frei.isEmpty { fluss.append(.text(kopf: "", rumpf: frei)) }
        } else {
            fluss = Self.zeitfolge(fotos: fotos, eintraege: eintraege)
        }
        var seiten = sonderseiten(tag)
        seiten.append(contentsOf: flussseiten(tag, fluss, mitKopf: seiten.isEmpty))
        if seiten.isEmpty {
            var y = satz.minY
            seiten.append(Seite(bloecke: lebenskopf(tag, y: &y, gross: true)))
        }
        return seiten
    }

    // MARK: Ein Fluss aus Fotos und Texten (ab 1.0.9)
    //
    // Ansage des Nutzers 11/2026 zu 1.0.8 (dort bekam jeder Text eine eigene
    // Textseite): „Nein! Nur der Text! Als Textfeld. Dessen Größe hängt vom
    // Inhalt ab: Kurze Kommentare passen neben/unter ein Bild; längere Texte
    // beanspruchen mehr Platz (z. B. den Platz eines Bildes). Hier muss die
    // App flexibel handeln und immer berücksichtigen, möglichst wenig Platz
    // auf der Seite zu verschenken. Ich möchte möglichst wenig leere Flächen!"
    //
    // Deshalb gibt es keine Textseiten und keine festen Bildfelder mehr. Die
    // Seite ist in Spalten geteilt (zwei im Hochformat, drei im Querformat).
    // Fotos und Texte laufen in ihrer ZEITFOLGE nacheinander in die jeweils
    // kürzeste Spalte: Ein Foto ist so hoch, wie sein Seitenverhältnis bei
    // der Spaltenbreite verlangt; ein Text so hoch, wie er GEMESSEN ist
    // (`Textmass`, derselbe Satz wie beim Zeichnen). Ein kurzer Kommentar
    // steht damit als schmales Feld unter dem Foto davor, ein langer Text
    // nimmt den Platz eines Bildes ein; passt er nicht mehr, wird er an der
    // Spaltenkante geteilt und läuft in der nächsten Spalte weiter.
    //
    // Am Ende jeder Seite wird die Lücke unten geschlossen: Die Fotos einer
    // Spalte wachsen (bis 35 %, sie werden dabei etwas stärker beschnitten),
    // bis die Spalte voll ist. Fotos sind leicht gedreht und ein wenig
    // breiter als ihre Spalte, damit sie über die Fuge greifen.
    enum Fluss {
        case foto(Foto)
        case text(kopf: String, rumpf: String)
    }

    static func zeitfolge(fotos: [Foto], eintraege: [Texteintrag]) -> [Fluss] {
        var liste: [(zeit: Date, text: Bool, nr: Int, element: Fluss)] = []
        for (n, f) in fotos.enumerated() {
            liste.append((f.aufnahme ?? .distantFuture, false, n, .foto(f)))
        }
        for (n, e) in eintraege.enumerated() {
            liste.append((e.zeit, true, n, .text(kopf: e.kopfzeile,
                                                 rumpf: e.text.trimmingCharacters(in: .whitespacesAndNewlines))))
        }
        liste.sort { a, b in
            if a.zeit != b.zeit { return a.zeit < b.zeit }
            if a.text != b.text { return a.text }
            return a.nr < b.nr
        }
        return liste.map(\.element)
    }

    private struct Platz {
        var element: Fluss
        var hoehe: Double
        var istFoto: Bool
    }

    private func flussseiten(_ tag: Reisetag, _ eingang: [Fluss], mitKopf: Bool) -> [Seite] {
        var offen = eingang
        var seiten: [Seite] = []
        let spalten = satz.width > satz.height * 1.1 ? 3 : 2
        let luft = fuge * 2.2
        let breite = (Double(satz.width) - luft * Double(spalten - 1)) / Double(spalten)
        var kopfbild = typografie[.unterueberschrift]
        kopfbild.groesse = 12.5
        kopfbild.ausrichtung = .links
        kopfbild.fett = true
        kopfbild.zeilenabstand = 1.15
        var textbild = typografie.flieText
        textbild.ausrichtung = .links
        let textzugabe = 9.0  // Goldstrich und Luft über dem Text
        var ersteSeite = true
        var schutz = 0

        while !offen.isEmpty, schutz < 400 {
            schutz += 1
            var y = satz.minY
            var bloecke: [Block] = []
            if ersteSeite && mitKopf { bloecke = lebenskopf(tag, y: &y, gross: true) }
            ersteSeite = false
            let oben = Double(y)
            let hoehe = Double(satz.maxY) - oben
            var saeulen: [[Platz]] = Array(repeating: [], count: spalten)

            func belegt(_ s: Int) -> Double {
                saeulen[s].reduce(0) { $0 + $1.hoehe } + luft * Double(max(0, saeulen[s].count - 1))
            }

            var voll = false
            while let naechstes = offen.first, !voll {
                var kuerzeste = 0
                for s in 1..<spalten where belegt(s) < belegt(kuerzeste) { kuerzeste = s }
                let frei = hoehe - belegt(kuerzeste) - (saeulen[kuerzeste].isEmpty ? 0 : luft)
                switch naechstes {
                case .foto(let f):
                    let v = min(max(f.seitenverhaeltnis, 0.62), 2.2)
                    let zeile = unterschriftHoehe(f, breite: breite)
                    let gewuenscht = breite / v + zeile
                    let mindestens = breite / v * 0.72 + zeile
                    if frei >= mindestens {
                        saeulen[kuerzeste].append(Platz(element: naechstes, hoehe: min(gewuenscht, frei), istFoto: true))
                        offen.removeFirst()
                    } else {
                        voll = true
                    }
                case .text(let kopf, let rumpf):
                    let kh = kopf.isEmpty ? 0 : Textmass.hoehe(kopf, bild: kopfbild, breite: breite) + 3
                    let rh = rumpf.isEmpty ? 0 : Textmass.hoehe(rumpf, bild: textbild, breite: breite)
                    let ganz = textzugabe + kh + rh
                    if frei >= ganz {
                        saeulen[kuerzeste].append(Platz(element: naechstes, hoehe: ganz, istFoto: false))
                        offen.removeFirst()
                    } else if frei >= textzugabe + kh + textbild.zeilenhoehe * 3, !rumpf.isEmpty {
                        let raum = CGSize(width: breite, height: frei - textzugabe - kh)
                        let (teil, rest) = Textmass.teilen(rumpf, bild: textbild, groesse: raum)
                        if teil.isEmpty {
                            voll = true
                        } else {
                            let th = Textmass.hoehe(teil, bild: textbild, breite: breite)
                            saeulen[kuerzeste].append(Platz(element: .text(kopf: kopf, rumpf: teil),
                                                            hoehe: textzugabe + kh + th, istFoto: false))
                            let weiter = rest.trimmingCharacters(in: .whitespacesAndNewlines)
                            if weiter.isEmpty {
                                offen.removeFirst()
                            } else {
                                offen[0] = .text(kopf: "", rumpf: weiter)
                            }
                        }
                    } else {
                        voll = true
                    }
                }
                // Eine Seite ohne jeden Platz für das Nächste wäre eine
                // Endlosschleife — dann muss es auf die nächste.
                if voll, saeulen.allSatisfy({ $0.isEmpty }) {
                    var istFoto = false
                    if case .foto = naechstes { istFoto = true }
                    saeulen[0].append(Platz(element: naechstes, hoehe: hoehe, istFoto: istFoto))
                    offen.removeFirst()
                }
            }

            // Die Lücke unten schließen: Fotos der Spalte wachsen.
            for s in 0..<spalten {
                let frei = hoehe - belegt(s)
                guard frei > 1 else { continue }
                let fotohoehe = saeulen[s].filter(\.istFoto).reduce(0) { $0 + $1.hoehe }
                guard fotohoehe > 0 else { continue }
                let faktor = min(1 + frei / fotohoehe, 1.35)
                for i in saeulen[s].indices where saeulen[s][i].istFoto {
                    saeulen[s][i].hoehe *= faktor
                }
            }

            for s in 0..<spalten {
                var yy = oben
                let x = Double(satz.minX) + Double(s) * (breite + luft)
                for (n, platz) in saeulen[s].enumerated() {
                    switch platz.element {
                    case .foto(let f):
                        let zeile = unterschriftHoehe(f, breite: breite)
                        let bildhoehe = max(platz.hoehe - zeile, 20)
                        let bild = Block(inhalt: .foto(f.id),
                                         rahmen: Rahmen(x: x - breite * 0.025, y: yy,
                                                        breite: breite * 1.05, hoehe: bildhoehe),
                                         drehung: drehwinkel(f.id) * 0.6,
                                         ebene: s + n % 2)
                        bloecke.append(bild)
                        if let unterschrift = unterschriftBlock(f, x: x, y: yy + bildhoehe, breite: breite) {
                            bloecke.append(angelegt(unterschrift, an: bild))
                        }
                    case .text(let kopf, let rumpf):
                        bloecke.append(Block(inhalt: .linie,
                                             rahmen: Rahmen(x: x, y: yy + 1, breite: 24, hoehe: 1.2),
                                             rand: stil.akzent))
                        var ty = yy + textzugabe
                        if !kopf.isEmpty {
                            let k = textblock(kopf, bild: kopfbild, x: x, y: ty, breite: breite)
                            bloecke.append(k)
                            ty += k.rahmen.hoehe + 3
                        }
                        if !rumpf.isEmpty {
                            bloecke.append(textblock(rumpf, bild: textbild, x: x, y: ty, breite: breite))
                        }
                    }
                    yy += platz.hoehe + luft
                }
            }
            seiten.append(Seite(bloecke: bloecke))
        }
        return seiten
    }

    // MARK: Bausteine

    private func abweichung(_ bild: Schriftbild) -> Schriftabweichung {
        var a = Schriftabweichung()
        a.familie = bild.familie
        a.groesse = bild.groesse
        a.zeilenabstand = bild.zeilenabstand
        a.absatzabstand = bild.absatzabstand
        a.ausrichtung = bild.ausrichtung
        a.farbe = bild.farbe
        a.fett = bild.fett
        a.kursiv = bild.kursiv
        a.versalien = bild.versalien
        a.sperrung = bild.sperrung
        a.trennung = bild.trennung
        return a
    }

    /// Ein Text in eigener Schrift, gemessen mit genau dieser Schrift.
    private func textblock(_ text: String, bild: Schriftbild, x: Double, y: Double,
                           breite: Double, hoechstens: Double? = nil) -> Block {
        var hoehe = Textmass.hoehe(text, bild: bild, breite: breite)
        if let hoechstens { hoehe = min(hoehe, max(hoechstens, bild.zeilenhoehe)) }
        return Block(inhalt: .text(text),
                     rahmen: Rahmen(x: x, y: y, breite: breite, hoehe: hoehe),
                     abweichung: abweichung(bild))
    }

    private var navy: Farbwert { typografie.titel.farbe }

    /// Der Kopf: großer Titel („2019"), eine Goldlinie, die zweite
    /// Überschrift (oder `zusatz`), die Datumszeile — alles mittig.
    private func lebenskopf(_ tag: Reisetag, y: inout CGFloat, gross: Bool,
                            zusatz: String? = nil, datum: Bool = true) -> [Block] {
        var bloecke: [Block] = []
        let x = Double(satz.minX)
        let breite = Double(satz.width)
        var titelbild = typografie.titel
        var titelabweichung = Schriftabweichung()
        if !gross {
            titelbild.groesse = (typografie.titel.groesse * 0.74).rounded()
            titelabweichung.groesse = titelbild.groesse
        }
        let titel = tag.ueberschrift.isEmpty ? tag.datum.mittel : tag.ueberschrift
        let titelhoehe = Textmass.hoehe(titel, bild: titelbild, breite: breite)
        bloecke.append(Block(inhalt: .titel,
                             rahmen: Rahmen(x: x, y: Double(y), breite: breite, hoehe: titelhoehe),
                             abweichung: titelabweichung))
        y += CGFloat(titelhoehe) + 1
        bloecke.append(Block(inhalt: .linie,
                             rahmen: Rahmen(x: x + breite * 0.34, y: Double(y), breite: breite * 0.32, hoehe: 1.4),
                             rand: stil.akzent))
        y += 7
        let zweiteBild = typografie[.unterueberschrift]
        if let zusatz {
            if !zusatz.isEmpty {
                let block = textblock(zusatz, bild: zweiteBild, x: x, y: Double(y), breite: breite)
                bloecke.append(block)
                y += CGFloat(block.rahmen.hoehe) + 3
            }
        } else if !tag.unterueberschrift.isEmpty {
            let hoehe = Textmass.hoehe(tag.unterueberschrift, bild: zweiteBild, breite: breite)
            bloecke.append(Block(inhalt: .unterueberschrift,
                                 rahmen: Rahmen(x: x, y: Double(y), breite: breite, hoehe: hoehe)))
            y += CGFloat(hoehe) + 3
        }
        if datum {
            let hoehe = typografie.datum.zeilenhoehe + 2
            bloecke.append(Block(inhalt: .datum,
                                 rahmen: Rahmen(x: x, y: Double(y), breite: breite, hoehe: hoehe)))
            y += CGFloat(hoehe)
        }
        y += 14
        return bloecke
    }

    /// Eine Überschrift OHNE Jahreszahl (ab 1.0.6, Ansage des Nutzers:
    /// „Die große Jahreszahl muss nicht auf jeder Seite stehen. Dort steht ja
    /// bereits kleiner ‚Kapitel [Jahreszahl]'. Auf der Geburtstagsseite soll
    /// sie natürlich stehen.") — mittig, mit Goldlinie darunter.
    private func seitenueberschrift(_ text: String, y: inout CGFloat) -> [Block] {
        var bild = typografie.titel
        bild.groesse = 24
        bild.fett = false
        let x = Double(satz.minX)
        let breite = Double(satz.width)
        let block = textblock(text, bild: bild, x: x, y: Double(y), breite: breite)
        y += CGFloat(block.rahmen.hoehe) + 2
        let linie = Block(inhalt: .linie,
                          rahmen: Rahmen(x: x + breite * 0.38, y: Double(y), breite: breite * 0.24, hoehe: 1.2),
                          rand: stil.akzent)
        y += 14
        return [block, linie]
    }

    // MARK: Zeitungsseite

    private func zeitungsseite(_ tag: Reisetag, zeitung: Foto) -> Seite {
        var y = satz.minY
        var bloecke = lebenskopf(tag, y: &y, gross: true)
        let spalte = Double(satz.width) * 0.29
        let zeitungX = Double(satz.minX) + spalte + fuge * 2.5
        let platzBreite = Double(satz.maxX) - zeitungX
        let platzHoehe = Double(satz.maxY - y)
        let v = max(zeitung.seitenverhaeltnis, 0.3)
        var breite = platzBreite
        var hoehe = breite / v
        if hoehe > platzHoehe {
            hoehe = platzHoehe
            breite = hoehe * v
        }
        bloecke.append(Block(inhalt: .foto(zeitung.id),
                             rahmen: Rahmen(x: Double(satz.maxX) - breite, y: Double(y), breite: breite, hoehe: hoehe),
                             drehung: -1.2, ebene: 1, fotorand: 0))

        // Die Spalte links: Goldstrich, Überschrift, Text.
        var sy = Double(y) + platzHoehe * 0.08
        let sx = Double(satz.minX)
        bloecke.append(Block(inhalt: .linie, rahmen: Rahmen(x: sx, y: sy, breite: 26, hoehe: 1.4),
                             rand: stil.akzent))
        sy += 10
        let titel = tag.zeitungstitel.trimmingCharacters(in: .whitespacesAndNewlines)
        if !titel.isEmpty {
            var bild = typografie[.unterueberschrift]
            bild.groesse = 15
            bild.ausrichtung = .links
            bild.fett = true
            let block = textblock(titel, bild: bild, x: sx, y: sy, breite: spalte)
            bloecke.append(block)
            sy += block.rahmen.hoehe + 8
        }
        let text = tag.zeitungstext.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            var bild = typografie.flieText
            bild.ausrichtung = .links
            bloecke.append(textblock(text, bild: bild, x: sx, y: sy, breite: spalte,
                                     hoechstens: Double(satz.maxY) - sy))
        }
        return Seite(bloecke: bloecke)
    }

    // MARK: Meldungen

    private func meldungsseiten(_ tag: Reisetag, _ meldungen: [Meldung]) -> [Seite] {
        var seiten: [Seite] = []
        var rest = meldungen[...]
        var erste = true
        while !rest.isEmpty {
            let gruppe = Array(rest.prefix(4))
            rest = rest.dropFirst(4)
            var y = satz.minY
            var bloecke: [Block] = []
            if erste {
                bloecke = seitenueberschrift("Was an diesem Tag geschah", y: &y)
            }
            erste = false
            let spalten = gruppe.count == 1 ? 1 : 2
            let zeilen = (gruppe.count + spalten - 1) / spalten
            let luft = fuge * 4
            let zelleB = (Double(satz.width) - luft * Double(spalten - 1)) / Double(spalten)
            let zelleH = (Double(satz.maxY - y) - luft * Double(zeilen - 1)) / Double(zeilen)
            var titelbild = typografie.titel
            titelbild.groesse = 14
            titelbild.ausrichtung = .links
            titelbild.zeilenabstand = 1.1
            var textbild = typografie.flieText
            textbild.kursiv = false
            textbild.groesse = 9.2
            textbild.ausrichtung = .links
            for (n, meldung) in gruppe.enumerated() {
                let x = Double(satz.minX) + Double(n % spalten) * (zelleB + luft)
                var zy = Double(y) + Double(n / spalten) * (zelleH + luft)
                let unten = zy + zelleH
                if let id = meldung.foto, let foto = fotoIndex[id] {
                    let h = min(zelleB / max(foto.seitenverhaeltnis, 0.6), zelleH * 0.52)
                    bloecke.append(Block(inhalt: .foto(foto.id),
                                         rahmen: Rahmen(x: x, y: zy, breite: zelleB, hoehe: h),
                                         fotorand: 0))
                    zy += h + 8
                }
                let titel = meldung.titel.trimmingCharacters(in: .whitespacesAndNewlines)
                if !titel.isEmpty {
                    bloecke.append(Block(inhalt: .linie, rahmen: Rahmen(x: x, y: zy, breite: 2.2, hoehe: 15),
                                         rand: stil.akzent, grund: stil.akzent))
                    let block = textblock(titel, bild: titelbild, x: x + 8, y: zy, breite: zelleB - 8)
                    bloecke.append(block)
                    zy += block.rahmen.hoehe + 5
                }
                let text = meldung.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    bloecke.append(textblock(text, bild: textbild, x: x, y: zy, breite: zelleB,
                                             hoechstens: unten - zy))
                }
            }
            seiten.append(Seite(bloecke: bloecke))
        }
        return seiten
    }

    // MARK: Fotos — groß, gedreht, überlappend

    /// Felder für n Fotos als Anteile der Fläche (x, y, Breite, Höhe). Sie
    /// überlappen mit Absicht; jedes Foto wird in sein Feld eingepasst und
    /// ein wenig größer gesetzt, damit die Ecken übereinandergreifen.
    private static func albumfelder(_ n: Int) -> [(Double, Double, Double, Double)] {
        switch n {
        case 1: return [(0.04, 0.02, 0.92, 0.96)]
        case 2: return [(0.0, 0.0, 0.64, 0.6), (0.36, 0.42, 0.64, 0.58)]
        case 3: return [(0.0, 0.0, 0.62, 0.56), (0.58, 0.06, 0.42, 0.46), (0.16, 0.52, 0.68, 0.48)]
        case 4: return [(0.0, 0.0, 0.6, 0.52), (0.56, 0.02, 0.44, 0.46),
                        (0.0, 0.5, 0.46, 0.5), (0.44, 0.46, 0.56, 0.54)]
        default: return [(0.0, 0.0, 0.6, 0.5), (0.57, 0.0, 0.43, 0.34), (0.57, 0.32, 0.43, 0.34),
                         (0.0, 0.5, 0.5, 0.5), (0.47, 0.64, 0.53, 0.36)]
        }
    }

    private func albumbloecke(_ fotos: [Foto], in flaeche: CGRect) -> [Block] {
        var bloecke: [Block] = []
        let felder = Self.albumfelder(fotos.count)
        for (n, foto) in fotos.enumerated() where n < felder.count {
            let f = felder[n]
            var feld = CGRect(x: Double(flaeche.minX) + f.0 * Double(flaeche.width),
                              y: Double(flaeche.minY) + f.1 * Double(flaeche.height),
                              width: f.2 * Double(flaeche.width), height: f.3 * Double(flaeche.height))
            // Platz für die Bildunterschrift.
            let zeile = unterschriftHoehe(foto, breite: Double(feld.width) * 0.8)
            feld.size.height -= CGFloat(zeile)
            let v = max(foto.seitenverhaeltnis, 0.3)
            var breite = Double(feld.width) * 1.06
            var hoehe = breite / v
            if hoehe > Double(feld.height) * 1.06 {
                hoehe = Double(feld.height) * 1.06
                breite = hoehe * v
            }
            let x = Double(feld.midX) - breite / 2
            let y = Double(feld.midY) - hoehe / 2
            let bild = Block(inhalt: .foto(foto.id),
                             rahmen: Rahmen(x: x, y: y, breite: breite, hoehe: hoehe),
                             drehung: drehwinkel(foto.id) * 0.8,
                             ebene: n)
            bloecke.append(bild)
            if let unterschrift = unterschriftBlock(foto, x: x + breite * 0.1, y: y + hoehe, breite: breite * 0.8) {
                bloecke.append(angelegt(unterschrift, an: bild))
            }
        }
        return bloecke
    }

}
