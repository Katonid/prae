import SwiftUI

// Die Seite, wie sie gedruckt wird — und auf der man arbeiten kann.
//
// Gerechnet wird durchweg in SEITENPUNKTEN. Der Maßstab liegt als eine
// einzige Skalierung über dem Ganzen; jede Geste wird durch ihn geteilt,
// bevor sie ins Modell geht. Der Bildschirm ist damit nur ein Fenster auf
// die Seite und nie ihr Maß.
//
// Gezeigt wird der ganze BOGEN, also Endformat plus Anschnitt. Wer nur das
// Endformat sähe, könnte nicht beurteilen, ob ein Bild weit genug übersteht.
struct SeitenflaecheView: View {
    @ObservedObject var werk: Reisewerk
    let buchseite: Buchseite
    var bearbeitbar: Bool = true
    var massstab: Double

    // `schiebt`/`zieht` gab es bis 1.0.7: Beim Verschieben bewegte sich nur
    // ein Versatz beim ZEICHNEN, der Rahmen im Modell blieb stehen und
    // wurde erst am Ende der Geste gesetzt. Damit lief der Block dem
    // Finger nach, die Griffe blieben zurück (die lesen den Rahmen), und
    // brach die Geste ab, ohne dass `onEnded` kam, stand das Bild für
    // immer neben seinem eigenen Rahmen. Gemeldet 09/2026: „Warum wandert
    // der nicht einfach mit?" **Merke: Was der Finger bewegt, wird SOFORT
    // ins Modell geschrieben — eine zweite Wahrheit fürs Zeichnen läuft
    // früher oder später auseinander.** Die Größenänderung machte das von
    // Anfang an so, und genau die ging.
    //
    // Was der Finger beim Aufsetzen gegriffen hat. Entschieden wird EINMAL,
    // beim ersten Bildpunkt der Bewegung — sonst wechselte mitten im Ziehen
    // die Bedeutung, sobald der Finger über einen anderen Griff wandert.
    @State private var gegriffen: Griffart?
    @State private var ausgangsrahmen: Rahmen?
    // Woran eine neue Ziehbewegung zu erkennen ist: am Aufsetzpunkt.
    @State private var gestenstart: CGPoint?
    // Der Ausschnitt beim Aufsetzen — für Zweifinger-Zoom und Schieben im
    // Rahmen. Beide rechnen vom Anfangswert aus, nicht vom letzten:
    // `translation` und `magnification` sind die GESAMTE Bewegung seit dem
    // Aufsetzen, und wer sie aufaddiert, beschleunigt mit jedem Bildpunkt.
    @State private var ausgangsausschnitt: Bildausschnitt?
    // Woran der Block gerade einrastet. Gezeichnet wird das als Linie quer
    // über die Seite — solange die Geste läuft und keinen Takt länger.
    @State private var fangSenkrecht: Einrasten.Linie?
    @State private var fangWaagerecht: Einrasten.Linie?
    // Einrasten lässt sich abschalten. Das ist die zweite Hälfte des
    // Wunsches („im Einzelfall auch veränderbar"): Eine Hilfe, aus der
    // sich nicht aussteigen lässt, ist eine Bevormundung — und es gibt
    // Lagen, in denen ein Block bewusst einen halben Millimeter neben der
    // Kante stehen soll. Der genaue Wert steht daneben im Inspektor.
    // `@AppStorage` gehört in eine VIEW und nie ins `Reisewerk`.
    @AppStorage("einrasten") private var einrastenAn = true

    private var format: CGSize { werk.reise.format.groesse }
    private var anschnitt: Double { werk.reise.gestaltung.anschnittPt }
    private var bogen: CGSize { werk.reise.gestaltung.bogen(werk.reise.format) }
    private var satz: CGRect { werk.reise.gestaltung.satzspiegel(werk.reise.format) }

    private var hintergrund: Seitenhintergrund {
        buchseite.seite.hintergrund ?? werk.reise.gestaltung.hintergrund
    }

    private var gewaehlterBlock: Block? {
        guard let id = werk.gewaehlterBlock else { return nil }
        return buchseite.seite.bloecke.first { $0.id == id }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Die Probe meldet sich im KÖRPER an — der läuft bei jedem
            // Neuzeichnen, und genau das ist die Zahl, die hier niemand
            // nachmessen kann.
            let _ = werk.messer.melde("Seite")
            HintergrundFlaeche(werk: werk, hintergrund: hintergrund, seite: buchseite.seite,
                               format: format, anschnitt: anschnitt,
                               bogen: bogen, seitennummer: buchseite.nummer)
                .offset(x: -anschnitt, y: -anschnitt)
                .allowsHitTesting(false)

            // Das Wasserzeichen: über dem Hintergrund, unter allem
            // anderen. Wo es liegt, rechnet dieselbe Funktion, die auch
            // das PDF fragt — zwei Fassungen ergäben eine Vorschau, die
            // anders aussieht als der Druck.
            if let zeichen = werk.reise.wasserzeichen(fuer: buchseite),
               let bild = Bildarchiv.shared.vorschau(zeichen.datei, reise: werk.reise.id,
                                                     kante: 900)
            {
                let ort = Wasserzeichenlage.rechteck(zeichen, satz: satz,
                                                     seite: buchseite.seite)
                Image(uiImage: bild)
                    .resizable()
                    .scaledToFit()
                    .frame(width: ort.width, height: ort.height)
                    .opacity(zeichen.deckung)
                    .offset(x: ort.minX, y: ort.minY)
                    .allowsHitTesting(false)
            }

            if bearbeitbar, werk.zeigeSatzspiegel {
                Rectangle()
                    .strokeBorder(style: StrokeStyle(lineWidth: 0.7, dash: [4, 4]))
                    .foregroundStyle(Color.accentColor.opacity(0.35))
                    .frame(width: satz.width, height: satz.height)
                    .offset(x: satz.minX, y: satz.minY)
                    .allowsHitTesting(false)
            }

            ForEach(buchseite.seite.sortiert) { block in
                // Der Block, der gerade im Textfeld steht, wird hier NICHT
                // gezeichnet. Sonst liegen zwei Fassungen desselben Textes
                // übereinander — eine von CoreText gesetzte und eine von
                // TextKit —, und die brechen nie an derselben Stelle um.
                // Gemeldet 09/2026: „erscheint das Textfeld dupliziert,
                // übereinander liegend". **Merke: Zwei Zeichner für
                // denselben Inhalt zeigen nie dasselbe.**
                if werk.textBearbeitung != block.id {
                    blockAnsicht(block)
                }
            }

            // SEITENZAHL UND KOPFZEILE — dieselben Rechtecke, die auch das
            // PDF bekommt (`Seitenbeiwerk`). Bis 1.0.49 wurden sie hier
            // GAR NICHT gezeichnet; der Schalter im Menü blieb auf dem
            // Bildschirm ohne jede Wirkung (gemeldet 09/2026). Sie liegen
            // über den Blöcken, weil sie es im PDF auch tun — dort werden
            // sie zuletzt gezeichnet.
            ForEach(Seitenbeiwerk.zeilen(buchseite, reise: werk.reise)) { zeile in
                Textkasten(text: zeile.text, bild: zeile.bild)
                    .frame(width: zeile.rechteck.width, height: zeile.rechteck.height)
                    .offset(x: zeile.rechteck.minX, y: zeile.rechteck.minY)
                    .allowsHitTesting(false)
            }

            // WORAN der Block gerade einrastet, steht als Linie da.
            //
            // Sie liegt über den Blöcken und unter der Schnittkante, geht
            // über den ganzen Bogen und trägt ihre Herkunft als Farbe: Der
            // Satzspiegel und die Schnittkante sind die Ordnung der Seite,
            // ein Nachbar ist eine Ausrichtung an etwas, das man sieht.
            // Ohne diese Linie war das Einrasten ein Zucken ohne Auskunft.
            if bearbeitbar, gegriffen != nil {
                if let linie = fangSenkrecht {
                    Fanglinie(linie: linie, senkrecht: true, laenge: bogen.height,
                              massstab: massstab)
                        .offset(x: linie.wert, y: -anschnitt)
                }
                if let linie = fangWaagerecht {
                    Fanglinie(linie: linie, senkrecht: false, laenge: bogen.width,
                              massstab: massstab)
                        .offset(x: -anschnitt, y: linie.wert)
                }
            }

            // Die Schnittkante liegt ÜBER allem. Sie ist die Linie, an der
            // das Buch beschnitten wird; unter den randabfallenden Bildern
            // gezeichnet wäre sie genau dort versteckt, wo sie gebraucht wird.
            if bearbeitbar, anschnitt > 0.5, werk.zeigeSatzspiegel {
                Rectangle()
                    .strokeBorder(style: StrokeStyle(lineWidth: 0.8, dash: [7, 4]))
                    .foregroundStyle(Color.red.opacity(0.55))
                    .frame(width: format.width, height: format.height)
                    .allowsHitTesting(false)
            }

            // Die Griffe sind eine ZEICHNUNG und nehmen keinen Finger an —
            // wie alles andere auf dieser Seite. Angefasst wird die SEITE.
            if bearbeitbar, let block = gewaehlterBlock, werk.ausschnittsmodus != block.id,
               werk.textBearbeitung != block.id
            {
                Griffzeichnung(block: block, massstab: massstab, abstand: griffabstand)
            }

            // Die Ziehfläche liegt NUR über dem gewählten Block, und das ist
            // kein Detail: Die Seite steckt in einem `ScrollView`, und eine
            // Ziehgeste über der ganzen Fläche nähme ihm das Blättern ab.
            // Ein Tipp tut das nicht — deshalb wählt man mit einem Tipp und
            // fasst danach an. Der Rahmen ist um den Griffsaum größer, damit
            // die Griffe darin liegen; wo keine Auswahl ist, scrollt die
            // Seite wie zuvor.
            if bearbeitbar, let block = gewaehlterBlock, werk.textBearbeitung != block.id {
                let saum = ziehsaum(block)
                // WÄHREND einer Geste bleibt diese Fläche stehen, wo sie war
                // (`ausgangsrahmen`). Seit 1.0.8 schreiben Verschieben,
                // Größe und Drehung bei JEDEM Bildpunkt ins Modell — die
                // Fläche hinge sonst an einem Rahmen, der unter dem eigenen
                // Finger wandert, und eine Geste, deren Ansicht sich
                // darunter verändert, bricht ab. **Merke: Eine Fläche, die
                // eine Geste trägt, darf sich während dieser Geste nicht
                // bewegen.** Wo der Finger aufgesetzt hat, hängt davon seit
                // 1.0.7 nicht mehr ab — das misst der Seitenraum.
                let bezug = ausgangsrahmen ?? block.rahmen
                Color.clear
                    .frame(width: bezug.breite + 2 * saum,
                           height: bezug.hoehe + 2 * saum)
                    .contentShape(Rectangle())
                    .offset(x: bezug.x - saum, y: bezug.y - saum)
                    // Die Tipps gehören mit auf diese Fläche: Sie liegt über
                    // dem Block, und ohne sie käme über dem gewählten Block
                    // kein Tipp mehr an — also weder das Abwählen noch der
                    // Doppeltipp, der den Text öffnet.
                    //
                    // GEMESSEN wird im Raum der SEITE und nicht im eigenen.
                    // Siehe `Seitenraum` — diese Fläche ist verschoben und
                    // ändert während einer Geste ihre Größe; was „lokal"
                    // dann heißt, ist genau die Frage, an der es hing.
                    .onTapGesture(count: 2, coordinateSpace: .named(Seitenraum.name)) { punkt in
                        doppeltipp(punkt)
                    }
                    .onTapGesture(count: 1, coordinateSpace: .named(Seitenraum.name)) { punkt in
                        einfachtipp(punkt)
                    }
                    .gesture(ziehgeste(block))
                    // Zwei Finger über dem gewählten FOTO vergrößern den
                    // Ausschnitt im Rahmen. `simultaneousGesture`, damit
                    // sie sich mit dem Ziehen nicht ausschließt: Das eine
                    // ist ein Finger, das andere zwei.
                    .simultaneousGesture(zoomgeste(block), including: block.fotoID == nil ? .subviews : .all)
            }

            // Ein Textkasten, aus dem unten etwas herausfällt, sagt das.
            // Dieselbe Marke wie in Pages: ein kleines Kästchen mit einem
            // Pluszeichen an der Unterkante. Gezeichnet wird sie nur beim
            // Bearbeiten und nie im PDF — sie ist ein Hinweis, kein Inhalt.
            if bearbeitbar, let block = gewaehlterBlock, werk.textUeberlauf != nil,
               werk.textBearbeitung != block.id
            {
                Ueberlaufmarke(block: block, massstab: massstab)
            }

            if bearbeitbar, let id = werk.textBearbeitung,
               let block = buchseite.seite.bloecke.first(where: { $0.id == id })
            {
                // Ein Tipp NEBEN das Textfeld schließt es — und sonst
                // nichts. Bis 1.0.8 kam so ein Tipp bei der Seite an, und
                // traf er dabei einen anderen Textblock, ging gleich das
                // nächste Feld auf: Für den Menschen davor ein Textfeld,
                // das sich nicht schließen lässt.
                Color.clear
                    .frame(width: bogen.width, height: bogen.height)
                    .offset(x: -anschnitt, y: -anschnitt)
                    .contentShape(Rectangle())
                    .onTapGesture { werk.textBearbeitung = nil }
                InlineText(werk: werk, block: block, tag: buchseite.tag, massstab: massstab)
            }

            // Die Probe: Was hat die Seite zuletzt entgegengenommen? Sie
            // steht nur da, wenn jemand sie eingeschaltet hat, und sie sagt
            // nichts als das Gemessene.
            if bearbeitbar, werk.zeigeGriffprobe {
                Text((werk.letzterGriff ?? "noch nichts gegriffen")
                     + "\n" + (werk.letzteBuehne ?? "noch nicht gezoomt")
                     + "\n" + werk.messer.befund)
                    .font(.system(size: 9 / massstab, design: .monospaced))
                    .multilineTextAlignment(.leading)
                    .fixedSize()
                    .padding(.horizontal, 5 / massstab)
                    .padding(.vertical, 3 / massstab)
                    .background(Color.black.opacity(0.72),
                                in: RoundedRectangle(cornerRadius: 6 / massstab))
                    .foregroundStyle(.white)
                    .offset(x: satz.minX, y: satz.minY - 16 / massstab)
                    .allowsHitTesting(false)
            }
        }
        // DER SEITENRAUM. Alles, was hier gemessen wird — jeder Tipp, jeder
        // Aufsetzpunkt einer Ziehbewegung —, wird gegen DIESEN Ursprung
        // gerechnet, und der ist die linke obere Ecke des Endformats. Damit
        // ist „wo hat der Finger aufgesetzt" nicht mehr davon abhängig, an
        // welcher Ansicht die Geste zufällig hängt.
        // `coordinateSpace(name:)` ist seit iOS 17 abgekündigt — hier steht
        // die Fassung mit `NamedCoordinateSpace`, sonst meldete der Bau eine
        // Warnung, und Warnungen sind in diesem Repo keine Nebensache.
        .coordinateSpace(.named(Seitenraum.name))
        .frame(width: bogen.width, height: bogen.height, alignment: .topLeading)
        // ALLE Gesten hängen an der SEITE, nicht an den Blöcken.
        //
        // Gemeldet 09/2026, nachdem schon das Verschieben zweimal nicht ging:
        // „Ich habe mitunter auch Schwierigkeiten, Textblöcke auswählen zu
        // können." Damit ist es nicht mehr die Geste, sondern schon der
        // TIPP — und das erklärt beides auf einmal. Zwei Gründe, und beide
        // sind am Quelltext nachzurechnen:
        //
        // 1. Ein Textblock ist FLACH. Eine Datumszeile misst rund 14
        //    Seitenpunkte; bei einer A4-Seite auf einem iPhone (Maßstab
        //    gut 0,5) sind das sieben Bildschirmpunkte. Apple nennt 44 als
        //    Mindestmaß für ein Fingerziel. Ein Rahmen, der genau so groß
        //    ist wie das Gezeichnete, ist bei Text also grundsätzlich zu
        //    klein — unabhängig von jeder Gestenfrage.
        // 2. Jeder Block trug seine eigenen Gesten, dazu lag in den
        //    Textblöcken eine UIKit-Ansicht. Wer mehrere Gesten
        //    übereinanderlegt, muss wissen, welche gewinnt.
        //
        // Deshalb dieselbe Bauweise wie bei der Netzkarte der Abfahrtstafel
        // (1.1.18): Eine Geste gehört der FLÄCHE; was darauf liegt, ist ein
        // Bild. Die Seite nimmt den Finger entgegen und sucht HINTERHER,
        // was gemeint war — erst genau, dann im Umkreis einer Fingerbreite.
        // Gerechnet wird also erst, wenn klar ist, dass ein Tipp gemeint
        // war, und die Fangweite kostet keine Fläche.
        //
        // Hier bleibt es bei `.local`: Diese Ansicht ist nicht verschoben und
        // ändert ihre Größe nicht, ihr Raum IST der Seitenraum — und das
        // Auswählen über sie hat im Feld nachweislich funktioniert. Der
        // benannte Raum steht eine Ebene tiefer und wäre von hier aus der
        // Raum eines Nachkommen; darauf wird nicht gezeigt.
        .contentShape(Rectangle())
        .onTapGesture(count: 2, coordinateSpace: .local) { punkt in doppeltipp(punkt) }
        .onTapGesture(count: 1, coordinateSpace: .local) { punkt in einfachtipp(punkt) }
        .offset(x: anschnitt, y: anschnitt)
        .frame(width: bogen.width, height: bogen.height, alignment: .topLeading)
        .clipped()
        .background(Color.white)
        .compositingGroup()
        .scaleEffect(massstab, anchor: .topLeading)
        // `alignment: .topLeading` IST DER GANZE PUNKT (ab 1.0.26).
        //
        // `scaleEffect` ändert nur die ZEICHNUNG, nie die Layoutgröße: Das
        // Kind darüber meldet weiterhin `bogen`, also die UNSKALIERTE
        // Größe. Der Rahmen hier ist die skalierte — und ein `.frame` ohne
        // Ausrichtung stellt ein kleineres Kind MITTIG hinein. Der Zoom
        // rechnete danach ab der Ecke DIESES Kindes, und die lag um
        // `bogen · (Maßstab − 1) / 2` in der Mitte des Rahmens.
        //
        // Damit hing die gezeichnete Seite bei jedem Maßstab über 100 % aus
        // ihrem eigenen Rahmen heraus — nach rechts und unten —, und oben
        // links blieb genau so viel leer. **Alle drei Beschwerden des
        // Nutzers sind dasselbe** (09/2026): „am oberen Rand bleibt
        // grundsätzlich Abstand bis zur eigentlichen Buchseite" (die Lücke),
        // „die untere rechte Ecke erreiche ich nie" (der Überhang; gerollt
        // wird der Rahmen, nicht die Zeichnung), und „mit einer
        // Zwei-Finger-Geste nicht wieder herauszoomen" — denn was außerhalb
        // eines Frames liegt, nimmt in SwiftUI keinen Finger an, und der
        // Zoom hängt an der Fläche der Bühne. Dieselbe Regel wie bei den
        // Griffen in 1.0.2, eine Ebene höher.
        //
        // NACHGEMESSEN an zwei Bildschirmfotos desselben Buches, in beide
        // Richtungen: bei 94 % steht die Blattkante 93 pt vom Bühnenrand,
        // wo `Zoomanker` 121,5 erwartet (−28,5; gerechnet −28,0), bei 187 %
        // liegt der Inhalt um +387/+272 daneben (gerechnet +373,5/+266,1).
        // Deshalb stimmte die Probe (`Soll = Ist`) und das Bild trotzdem
        // nicht: Gerollt wurde richtig, nur stand die Seite woanders, als
        // die Rechnung annahm.
        .frame(width: bogen.width * massstab, height: bogen.height * massstab,
               alignment: .topLeading)
        // DER SCHATTEN LIEGT AUSSERHALB DES MASSSTABS (ab 1.0.20).
        //
        // Bis 1.0.19 stand er davor und wurde mitskaliert: Bei eingepasster
        // Ansicht (rund 0,4) blieben von neun Punkten dreieinhalb übrig —
        // die Seite lag flach auf dem Grund, statt als Blatt darauf zu
        // liegen. Hier gerechnet ist er in BILDSCHIRMpunkten und damit auf
        // jedem Maßstab derselbe. Dieselbe Überlegung wie bei den Säumen
        // der Werkzeugleiste in Tafelbild.
        .shadow(color: .black.opacity(0.30), radius: 16, y: 7)
        // EINMAL je Änderung, nicht bei jedem Neuzeichnen: Dahinter steckt
        // ein voller CoreText-Satz. Der Schlüssel nennt nur, was den
        // Befund ändern kann — Block, Rahmenmaße, Textlänge.
        .task(id: ueberlaufschluessel) { werk.textUeberlauf = ueberlaufMessen() }
    }

    private var ueberlaufschluessel: String {
        guard bearbeitbar, let block = gewaehlterBlock, let tag = buchseite.tag,
              block.inhalt.istText
        else { return "-" }
        let text = Seitensatz.inhaltstext(block, tag: tag, reise: werk.reise)
        // Der Innenabstand gehört in den Schlüssel: Er nimmt dem Text
        // Breite UND Höhe weg. Ohne ihn bliebe die Marke stehen, wo sie
        // stand, obwohl der Kasten gerade enger geworden ist — ein Hinweis,
        // der hinterherhinkt, ist schlimmer als keiner.
        return "\(block.id)|\(Int(block.rahmen.breite))|\(Int(block.rahmen.hoehe))"
            + "|\(Int(block.textrand(werk.reise.gestaltung)))|\(text.count)"
    }

    private func ueberlaufMessen() -> Double? {
        guard bearbeitbar, let block = gewaehlterBlock, let tag = buchseite.tag else { return nil }
        return werk.fehlendeHoehe(block, tag: tag)
    }

    // Der Abstand des Drehgriffs über dem Block — an einer Stelle, weil
    // Zeichnung und Treffprüfung denselben Wert brauchen.
    private var griffabstand: Double { 32 / massstab }
    private var grundgreifweite: Double { 24 / massstab }

    // Die Greifweite eines EINZELNEN Blocks. Eine Fingerkuppe ist das Maß,
    // aber sie darf einen kleinen Block nicht ganz ausfüllen: Läge jeder
    // Punkt eines 60 x 40 grossen Blocks im Umkreis einer Ecke, liesse er
    // sich nur noch in der Größe ziehen und nie mehr verschieben. Deshalb
    // gedeckelt auf gut ein Drittel der kürzeren Seite — mit einem Boden,
    // unter den es nicht geht, sonst wäre der Griff nicht zu treffen.
    private func greifweite(_ block: Block) -> Double {
        let kurz = min(block.rahmen.breite, block.rahmen.hoehe)
        return min(grundgreifweite, max(10 / massstab, kurz * 0.35))
    }

    @ViewBuilder
    private func blockAnsicht(_ block: Block) -> some View {
        let rahmen = block.rahmen
        let wirkung = block.wirkung(werk.reise.gestaltung)
        let randPt = Druckmass.pt(wirkung.fotorand)

        BlockInhaltView(werk: werk, block: block, tag: buchseite.tag)
            .frame(width: rahmen.breite, height: rahmen.hoehe)
            .padding(randPt)
            .background {
                if wirkung.fotorand > 0 {
                    RoundedRectangle(cornerRadius: werk.reise.gestaltung.eckenradiusPt)
                        .fill(Color.white)
                }
            }
            .schattenwurf(wirkung.schatten, massstab: format.width / 600)
            .padding(-randPt)
            .frame(width: rahmen.breite, height: rahmen.hoehe)
            .rotationEffect(.degrees(block.drehung))
            .offset(x: rahmen.x, y: rahmen.y)
            // Ein Block ist eine ZEICHNUNG. Er trägt keine Geste mehr, und
            // was in ihm liegt — Textkasten, Foto, Karte — nimmt erst recht
            // keinen Finger an.
            .allowsHitTesting(false)
    }

    // MARK: - Was liegt unter dem Finger?

    // Die Fangweite für einen Block: eine knappe Fingerbreite, in
    // Bildschirmpunkten gedacht und in Seitenpunkte umgerechnet. Sie ist
    // kleiner als die der Griffe — ein Griff ist ein Punkt, ein Block hat
    // eine Fläche, und ein zu großzügiger Fang schnappte über einen
    // benachbarten Block hinweg.
    private var fangweite: Double { 20 / massstab }

    // Erst genau, dann im Umkreis — jeweils von OBEN nach unten, damit bei
    // zwei übereinanderliegenden Blöcken der gewinnt, den man sieht.
    private func blockUnter(_ punkt: CGPoint) -> Block? {
        let oben = buchseite.seite.sortiert.reversed()
        if let treffer = oben.first(where: { trifft($0, punkt: punkt, luft: 0) }) {
            return treffer
        }
        return oben.first { trifft($0, punkt: punkt, luft: fangweite) }
    }

    // Liegt der Punkt im Rahmen (zuzüglich Luft)? Bei einem gedrehten Block
    // wird er vorher um dessen Mitte zurückgedreht — der Rahmen dreht ja mit.
    private func trifft(_ block: Block, punkt: CGPoint, luft: Double) -> Bool {
        let feld = block.rahmen.rect.insetBy(dx: -luft, dy: -luft)
        return feld.contains(imBlock(punkt, block: block, absolut: true))
    }

    // Rechnet einen Punkt der SEITE in die Koordinaten eines Blocks um.
    // `absolut` behält den Ursprung der Seite (für die Rahmenprüfung),
    // sonst liegt (0,0) in der linken oberen Ecke des Blocks (für die
    // Griffe).
    private func imBlock(_ punkt: CGPoint, block: Block, absolut: Bool) -> CGPoint {
        var stelle = punkt
        if abs(block.drehung) > 0.01 {
            let mitte = block.rahmen.mitte
            let winkel = -block.drehung * .pi / 180
            let dx = punkt.x - mitte.x
            let dy = punkt.y - mitte.y
            stelle = CGPoint(x: mitte.x + dx * cos(winkel) - dy * sin(winkel),
                             y: mitte.y + dx * sin(winkel) + dy * cos(winkel))
        }
        if absolut { return stelle }
        return CGPoint(x: stelle.x - block.rahmen.x, y: stelle.y - block.rahmen.y)
    }

    // MARK: - Tippen

    private func einfachtipp(_ punkt: CGPoint) {
        guard bearbeitbar else { return }
        werk.textBearbeitung = nil
        let treffer = blockUnter(punkt)
        werk.letzterGriff = treffer.map { "Tipp auf \($0.inhalt.name)" } ?? "Tipp ins Leere"
        guard let treffer else {
            werk.gewaehlterBlock = nil
            return
        }
        werk.gewaehlterBlock = werk.gewaehlterBlock == treffer.id ? nil : treffer.id
    }

    private func doppeltipp(_ punkt: CGPoint) {
        guard bearbeitbar, let treffer = blockUnter(punkt) else { return }
        werk.letzterGriff = "Doppeltipp auf \(treffer.inhalt.name)"
        werk.gewaehlterBlock = treffer.id
        if treffer.inhalt.istText {
            werk.textBearbeitung = treffer.id
            return
        }
        // Ein Doppeltipp auf ein FOTO schreibt seine Unterschrift. Das ist
        // derselbe Griff wie beim Text — man tippt zweimal auf das, was man
        // beschriften will — und der einzige Weg dorthin, den man nicht
        // vorher gelesen haben muss.
        if let id = treffer.fotoID { werk.unterschriftOeffnen(id) }
    }

    // MARK: - Ziehen

    // Wie weit die Ziehfläche über den Block hinausreicht: so weit, dass
    // die Griffe samt Drehgriff darin liegen. Im Ausschnittsmodus gibt es
    // keine Griffe — dort bleibt die Fläche beim Bild.
    private func ziehsaum(_ block: Block) -> Double {
        werk.ausschnittsmodus == block.id ? 0 : griffabstand + grundgreifweite
    }

    // Die Geste misst im SEITENRAUM, nicht im eigenen. Damit ist der
    // Aufsetzpunkt dieselbe Zahl, die auch ein Tipp auf die Seite liefert —
    // und die Umrechnung, an der es hing, gibt es gar nicht mehr.
    private func ziehgeste(_ block: Block) -> some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .named(Seitenraum.name))
            .onChanged { wert in ziehen(block, wert: wert, endgueltig: false) }
            .onEnded { wert in ziehen(block, wert: wert, endgueltig: true) }
    }

    private func ziehen(_ block: Block, wert: DragGesture.Value, endgueltig: Bool) {
        // Eine NEUE Geste erkennt man am Aufsetzpunkt. Ohne diese Prüfung
        // bliebe nach einer abgebrochenen Geste der alte Griff stehen, und
        // die nächste Bewegung täte etwas, das niemand angefasst hat.
        if gegriffen == nil || gestenstart != wert.startLocation {
            gestenstart = wert.startLocation
            griffFestlegen(wert.startLocation, block: block)
        }
        guard let art = gegriffen else {
            if endgueltig { gestenendeAufraeumen(wert) }
            return
        }
        if werk.ausschnittsmodus == block.id {
            ausschnittSchieben(block, wert: wert, endgueltig: endgueltig)
            if endgueltig { gestenendeAufraeumen(wert) }
            return
        }
        switch art {
        case .verschieben:
            verschieben(block, wert: wert)
        case .drehen:
            // UNGEDREHT: `drehen` setzt den Winkel absolut, gemessen im
            // ruhenden Koordinatensystem der Seite. Mit dem
            // zurückgedrehten Punkt wäre er relativ zur schon gesetzten
            // Drehung, und der Block liefe dem Finger davon.
            drehen(block, zeigt: CGPoint(x: wert.location.x - block.rahmen.x,
                                         y: wert.location.y - block.rahmen.y))
        default:
            groesseAendern(block, wert: wert)
        }
        if endgueltig { gestenendeAufraeumen(wert) }
    }

    // Einmal beim Aufsetzen, und dann gilt es für die ganze Bewegung: Sonst
    // wechselte die Bedeutung mitten im Ziehen, sobald der Finger über
    // einen anderen Griff wandert.
    private func griffFestlegen(_ punkt: CGPoint, block: Block) {
        // Im Ausschnittsmodus gibt es keine Griffe, und gemerkt wird dort
        // erst am Ende der Geste (`ausschnittSchieben`) — ein zweites
        // Merken hier legte einen leeren Stand auf den Rückgängig-Stapel.
        guard werk.ausschnittsmodus != block.id else {
            gegriffen = .verschieben
            werk.letzterGriff = "Ausschnitt an \(block.inhalt.name)"
            return
        }
        let weite = greifweite(block)
        let imEigenen = imBlock(punkt, block: block, absolut: false)
        let art = Grifflage.getroffen(imEigenen,
                                      breite: block.rahmen.breite,
                                      hoehe: block.rahmen.hoehe,
                                      abstand: griffabstand,
                                      greifweite: weite) ?? .verschieben
        gegriffen = art
        ausgangsrahmen = block.rahmen
        // Die Probe nennt ZAHLEN und keine Deutung: wo der Finger im Block
        // aufgesetzt hat, wie groß der Block ist und wie weit ein Griff
        // greift. Damit ist beim nächsten Mal nachzurechnen, ob der Punkt
        // stimmt — und nicht wieder zu raten.
        werk.letzterGriff = String(
            format: "%@ an %@ \u{00B7} Punkt %.0f/%.0f in 0…%.0f/0…%.0f \u{00B7} greift %.0f",
            art.name, block.inhalt.name,
            imEigenen.x, imEigenen.y,
            block.rahmen.breite, block.rahmen.hoehe, weite)
        werk.merken()
    }

    private func gestenendeAufraeumen(_ wert: DragGesture.Value) {
        if gegriffen != nil {
            werk.letzterGriff = (werk.letzterGriff ?? "") + String(
                format: " \u{00B7} %.1f / %.1f mm \u{00B7} Maßstab %.2f",
                Druckmass.mm(wert.translation.width),
                Druckmass.mm(wert.translation.height), massstab)
        }
        gegriffen = nil
        ausgangsrahmen = nil
        gestenstart = nil
        ausgangsausschnitt = nil
        fangSenkrecht = nil
        fangWaagerecht = nil
    }

    // MARK: - Schieben

    private func verschieben(_ block: Block, wert: DragGesture.Value) {
        // OHNE Teilung durch den Maßstab. Eine Geste wird im SEITENRAUM
        // gemeldet, und der liegt innerhalb des `scaleEffect` — die
        // Strecke ist also schon in Seitenpunkten. Bis 1.0.4 wurde hier
        // zusätzlich geteilt; bei halb gezeigter Seite lief der Block
        // damit doppelt so weit wie der Finger.
        //
        // Gerechnet wird vom AUSGANGSRAHMEN aus, nicht vom jetzigen:
        // `translation` ist die ganze Bewegung seit dem Aufsetzen, und auf
        // den mitgewanderten Rahmen addiert liefe der Block davon.
        // Geschrieben wird bei jedem Bildpunkt — dieselbe Bauweise wie
        // beim Ändern der Größe, und deshalb wandern die Griffe mit.
        guard let ausgang = ausgangsrahmen else { return }
        var probe = block
        probe.rahmen = ausgang
        // Ohne Einrasten wird schlicht die Strecke genommen. Der Schalter
        // sitzt unter „…" → Hilfen beim Anordnen; wer ihn ausmacht, bekommt auch keine
        // Linien — eine Linie ohne Wirkung wäre eine Behauptung.
        let gefangen: Einrasten.Fang
        if einrastenAn {
            gefangen = Einrasten.gefangen(
                block: probe,
                dx: wert.translation.width, dy: wert.translation.height,
                nachbarn: buchseite.seite.bloecke.filter { $0.id != block.id },
                satz: satz,
                bogen: werk.reise.gestaltung.anschnitt > 0.5
                    ? werk.reise.gestaltung.randabfallend(werk.reise.format) : nil,
                toleranz: 6 / massstab
            )
        } else {
            gefangen = Einrasten.Fang(dx: wert.translation.width,
                                      dy: wert.translation.height,
                                      senkrecht: nil, waagerecht: nil)
        }
        fangSenkrecht = gefangen.senkrecht
        fangWaagerecht = gefangen.waagerecht
        let neu = ausgang.verschoben(dx: gefangen.dx, dy: gefangen.dy)
            .begrenzt(auf: werk.reise.format.groesse)
        werk.aendere(block.id, merken: false) { $0.rahmen = neu }
    }

    // MARK: - Drehen

    // Gedreht wird um die MITTE, und der Winkel kommt aus dem Zeiger von der
    // Mitte zum Finger — nicht aus der Wegstrecke. Eine Drehung aus der
    // Verschiebung dreht am Rand schneller als in der Mitte.
    private func drehen(_ block: Block, zeigt: CGPoint) {
        let mitte = CGPoint(x: block.rahmen.breite / 2, y: block.rahmen.hoehe / 2)
        let zeiger = CGPoint(x: zeigt.x - mitte.x, y: zeigt.y - mitte.y)
        var grad = atan2(zeiger.x, -zeiger.y) * 180 / .pi
        // Bei Vielfachen von 45 Grad rastet sie ein: Ein Bild, das um 0,4
        // Grad schief steht, sieht nicht gewollt aus, sondern nach einem
        // Versehen.
        for rast in stride(from: -180.0, through: 180.0, by: 45) where abs(grad - rast) < 3 {
            grad = rast
        }
        werk.aendere(block.id, merken: false) { $0.drehung = grad }
    }

    // MARK: - Größe

    private func groesseAendern(_ block: Block, wert: DragGesture.Value) {
        guard let ausgang = ausgangsrahmen, let art = gegriffen else { return }
        let richtung = art.zieht
        let dx = wert.translation.width
        let dy = wert.translation.height

        var neu = ausgang
        if richtung.waagerecht < 0 {
            neu.x = ausgang.x + dx
            neu.breite = ausgang.breite - dx
        } else if richtung.waagerecht > 0 {
            neu.breite = ausgang.breite + dx
        }
        if richtung.senkrecht < 0 {
            neu.y = ausgang.y + dy
            neu.hoehe = ausgang.hoehe - dy
        } else if richtung.senkrecht > 0 {
            neu.hoehe = ausgang.hoehe + dy
        }
        // Unter dieser Größe ist ein Block nicht mehr zu treffen — und ein
        // Block, den man nicht mehr anfassen kann, ist verloren.
        neu.breite = max(neu.breite, 24)
        neu.hoehe = max(neu.hoehe, 14)

        // Dieselben Kanten wie beim Schieben, aus derselben Quelle
        // (`Einrasten.kanten`) — zwei Listen liefen auseinander, und dann
        // finge eine Ecke an etwas, woran die Kante daneben nicht fängt.
        let alle = Einrasten.kanten(
            satz: satz,
            bogen: werk.reise.gestaltung.anschnitt > 0.5
                ? werk.reise.gestaltung.randabfallend(werk.reise.format) : nil,
            nachbarn: buchseite.seite.bloecke.filter { $0.id != block.id }
        )
        let toleranz = einrastenAn ? 7 / massstab : 0
        var senkrecht: Einrasten.Linie?
        var waagerecht: Einrasten.Linie?
        if richtung.waagerecht < 0 {
            let gefangen = Einrasten.kanteGefangen(neu.x, kanten: alle.x, toleranz: toleranz)
            neu.breite += neu.x - gefangen.wert
            neu.x = gefangen.wert
            senkrecht = gefangen.linie
        } else if richtung.waagerecht > 0 {
            let rechts = Einrasten.kanteGefangen(neu.x + neu.breite, kanten: alle.x,
                                                 toleranz: toleranz)
            neu.breite = rechts.wert - neu.x
            senkrecht = rechts.linie
        }
        if richtung.senkrecht < 0 {
            let gefangen = Einrasten.kanteGefangen(neu.y, kanten: alle.y, toleranz: toleranz)
            neu.hoehe += neu.y - gefangen.wert
            neu.y = gefangen.wert
            waagerecht = gefangen.linie
        } else if richtung.senkrecht > 0 {
            let unten = Einrasten.kanteGefangen(neu.y + neu.hoehe, kanten: alle.y,
                                                toleranz: toleranz)
            neu.hoehe = unten.wert - neu.y
            waagerecht = unten.linie
        }
        fangSenkrecht = senkrecht
        fangWaagerecht = waagerecht

        werk.aendere(block.id, merken: false) { b in
            b.rahmen = neu
            // Wird ein Foto größer gezogen, bleibt sein Ausschnitt gültig —
            // aber nur, wenn er den neuen Rahmen noch füllt.
            if let id = b.fotoID, let foto = werk.reise.foto(id) {
                b.ausschnitt = b.ausschnitt.begrenzt(
                    bildgroesse: CGSize(width: foto.breite, height: foto.hoehe),
                    rahmen: neu.rect)
            }
        }
    }

    private func ausschnittSchieben(_ block: Block, wert: DragGesture.Value, endgueltig: Bool) {
        guard let id = block.fotoID, let foto = werk.reise.foto(id) else { return }
        if ausgangsausschnitt == nil { ausgangsausschnitt = block.ausschnitt }
        guard let ausgang = ausgangsausschnitt else { return }
        let rahmen = block.rahmen.rect
        let bildgroesse = CGSize(width: foto.breite, height: foto.hoehe)
        // Vom AUSGANGSWERT aus. Bis 1.0.7 wurde die Gesamtstrecke bei jedem
        // Bildpunkt aufaddiert — das Bild schoss unter dem Finger weg, und
        // zwar immer schneller.
        var neu = ausgang
        neu.versatzX += wert.translation.width / max(rahmen.width, 1)
        neu.versatzY += wert.translation.height / max(rahmen.height, 1)
        werk.aendere(block.id, merken: false) {
            $0.ausschnitt = neu.begrenzt(bildgroesse: bildgroesse, rahmen: rahmen)
        }
        if endgueltig { ausgangsausschnitt = nil }
    }

    // MARK: - Zwei Finger vergrößern das Bild IM Rahmen

    // Gewünscht 09/2026: „Wäre schön, wenn man ein Foto einfach mit einer
    // Zweifinger-Geste in den inneren Bereich ziehen könnte. Also die
    // Vergrößerung des Fotos innerhalb des Rahmens."
    //
    // Der Rahmen ist der Platz auf der Seite, der Ausschnitt der sichtbare
    // Teil des Bildes — zwei Dinge, und beide müssen zu machen sein. Die
    // Kanten und Ecken ziehen den RAHMEN, zwei Finger den AUSSCHNITT. Die
    // Seite selbst wird nicht mit zwei Fingern gezoomt (dafür stehen die
    // Maßstab-Knopf unten), es gibt hier also nichts, womit sich diese Geste
    // streiten könnte.
    private func zoomgeste(_ block: Block) -> some Gesture {
        MagnifyGesture(minimumScaleDelta: 0.01)
            .onChanged { wert in bildZoomen(block, faktor: wert.magnification, endgueltig: false) }
            .onEnded { wert in bildZoomen(block, faktor: wert.magnification, endgueltig: true) }
    }

    private func bildZoomen(_ block: Block, faktor: Double, endgueltig: Bool) {
        guard let id = block.fotoID, let foto = werk.reise.foto(id) else { return }
        if ausgangsausschnitt == nil {
            ausgangsausschnitt = block.ausschnitt
            // Einmal je Geste gemerkt, nicht je Bildpunkt — sonst wäre der
            // Rückgängig-Stapel nach einem Zoom voll. Und nicht noch
            // einmal, wenn daneben schon eine Ziehbewegung läuft: Die hat
            // beim Aufsetzen gemerkt, und zwei Stände für eine Handbewegung
            // wären zwei Schritte zurück.
            if gegriffen == nil { werk.merken() }
        }
        guard let ausgang = ausgangsausschnitt else { return }
        let rahmen = block.rahmen.rect
        let bildgroesse = CGSize(width: foto.breite, height: foto.hoehe)
        var neu = ausgang
        neu.zoom = ausgang.zoom * faktor
        let begrenzt = neu.begrenzt(bildgroesse: bildgroesse, rahmen: rahmen)
        werk.aendere(block.id, merken: false) { $0.ausschnitt = begrenzt }
        werk.letzterGriff = String(format: "Bild im Rahmen \u{00B7} Zoom %.2f", begrenzt.zoom)
        if endgueltig { ausgangsausschnitt = nil }
    }
}

// MARK: - Die Marke für abgeschnittenen Text

// Ein kleines Kästchen mit einem Pluszeichen an der Unterkante des Blocks
// — dieselbe Zeichensprache wie in Pages, und aus demselben Grund: Ein
// Kasten, aus dem unten zwei Sätze herausfallen, sieht aus wie ein Kasten,
// der zu Ende ist. In einem Tagebuch ist das der teuerste denkbare Fehler,
// denn es gibt keine zweite Ausfertigung des Satzes.
//
// Sie ist eine ZEICHNUNG wie alles auf dieser Seite und nimmt keinen
// Finger an; angefasst wird über den Knopf „Rahmen an Text anpassen".
struct Ueberlaufmarke: View {
    let block: Block
    let massstab: Double

    private var groesse: Double { 16 / massstab }

    var body: some View {
        let rahmen = block.rahmen.rect
        ZStack {
            RoundedRectangle(cornerRadius: 2 / massstab)
                .fill(Color.orange)
            Image(systemName: "plus")
                .font(.system(size: groesse * 0.6, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: groesse, height: groesse)
        .position(x: rahmen.width / 2, y: rahmen.height)
        .frame(width: rahmen.width, height: rahmen.height, alignment: .topLeading)
        .rotationEffect(.degrees(block.drehung))
        .offset(x: rahmen.minX, y: rahmen.minY)
        .allowsHitTesting(false)
    }
}

// MARK: - Hintergrund

struct HintergrundFlaeche: View {
    @ObservedObject var werk: Reisewerk
    let hintergrund: Seitenhintergrund
    let seite: Seite
    let format: CGSize
    let anschnitt: Double
    // Der Bogen, auf den beschnitten wird — `nil` heißt „nimm, was der
    // Platz hergibt" (die Probe im Hintergrund-Blatt).
    var bogen: CGSize?
    // Die Nummer im Buch. Daran hängt, ob diese Seite links oder rechts
    // liegt; `nil` heißt „außerhalb des Buches", und dann gibt es keine
    // Doppelseite, über die etwas gehen könnte.
    var seitennummer: Int?

    // Wie groß das Hintergrundfoto gezeichnet wird und wie weit gegen die
    // Bogenmitte verschoben — oder `nil`, wenn es schlicht diese eine
    // Seite füllt. Über die Doppelseite ist es zwei Seitenbreiten breit
    // und um eine halbe versetzt: nach rechts auf einer linken Seite, nach
    // links auf einer rechten.
    private var doppelflaeche: (breite: Double, hoehe: Double, versatz: Double)? {
        guard hintergrund.ueberDoppelseite, let seitennummer, let bogen else { return nil }
        return (Double(bogen.width) + Double(format.width),
                Double(bogen.height),
                Bogenlage.versatz(nummer: seitennummer, format: format, anschnitt: anschnitt))
    }

    var body: some View {
        ZStack {
            switch hintergrund.art {
            case .einfarbig:
                hintergrund.farbe.farbe
            case .verlauf:
                hintergrund.swiftUIVerlauf
            case .papierstruktur:
                hintergrund.farbe.farbe
                Papierkorn(staerke: hintergrund.koernung, saat: seite.id.saat)
            case .foto:
                hintergrund.farbe.farbe
                if let id = hintergrund.fotoID, let foto = werk.reise.foto(id),
                   // Über die Doppelseite deckt dasselbe Bild die
                   // doppelte Breite ab — mit derselben Kante wäre es auf
                   // dem Bildschirm halb so fein. Das PDF holt ohnehin die
                   // volle Auflösung (`auftrag.bildkante`).
                   let bild = Bildarchiv.shared.vorschau(foto.datei, reise: werk.reise.id,
                                                         kante: doppelflaeche == nil ? 1400 : 2400)
                {
                    fotoflaeche(bild)
                }
                hintergrund.farbe.farbe.opacity(hintergrund.schleier)
            }
        }
        // Die Größe steht FEST am Bogen und richtet sich nicht nach dem
        // größten Kind: Ein Bild über die Doppelseite ist breiter als diese
        // Seite, und ohne diesen Rahmen wüchse der Stapel mit und zöge das
        // Blatt auseinander. Beschnitten wird danach am Bogen — die
        // Nachbarseite ist ein eigenes Blatt Papier.
        .frame(width: bogen?.width, height: bogen?.height)
        .clipped()
    }

    @ViewBuilder
    private func fotoflaeche(_ bild: UIImage) -> some View {
        if let flaeche = doppelflaeche {
            Image(uiImage: bild)
                .resizable()
                .scaledToFill()
                .frame(width: CGFloat(flaeche.breite), height: CGFloat(flaeche.hoehe))
                .offset(x: CGFloat(flaeche.versatz))
        } else {
            Image(uiImage: bild)
                .resizable()
                .scaledToFill()
        }
    }
}

// Ein feines Korn, damit eine einfarbige Fläche nicht wie ein Bildschirm
// aussieht. Gerechnet statt geladen — eine Bilddatei dafür wäre ein
// Megabyte für etwas, das man kaum sieht und trotzdem vermisst.
struct Papierkorn: View {
    let staerke: Double
    // An der SEITE festgemacht. Ohne diese Zahl würfelte jede Neuzeichnung
    // ein neues Korn — auf dem Bildschirm ein Flimmern, und gedruckt eine
    // andere Seite als die angesehene. Gerechnet wird es von derselben
    // Funktion, die auch das PDF fragt.
    let saat: UInt64

    var body: some View {
        Canvas { zusammenhang, groesse in
            for punkt in Seitensatz.kornpunkte(groesse: groesse, koernung: staerke, saat: saat) {
                zusammenhang.fill(
                    Path(ellipseIn: CGRect(x: punkt.ort.x, y: punkt.ort.y,
                                           width: 1.2, height: 1.2)),
                    with: .color(.black.opacity(punkt.deckung))
                )
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Blockinhalt

struct BlockInhaltView: View {
    @ObservedObject var werk: Reisewerk
    let block: Block
    let tag: Reisetag?

    private var wirkung: Blockwirkung { block.wirkung(werk.reise.gestaltung) }

    var body: some View {
        ZStack {
            // Der Grund kommt aus der WIRKUNG und nicht mehr vom Block
            // allein: Seit 1.0.12 darf ihn auch das Buch vorgeben.
            if let grund = wirkung.grund {
                RoundedRectangle(cornerRadius: werk.reise.gestaltung.eckenradiusPt)
                    .fill(grund.farbe)
            }
            inhalt
            if let rand = wirkung.randfarbe, wirkung.randbreite > 0, block.inhalt != .linie {
                RoundedRectangle(cornerRadius: werk.reise.gestaltung.eckenradiusPt)
                    .strokeBorder(rand.farbe, lineWidth: wirkung.randbreite)
            }
        }
    }

    @ViewBuilder
    private var inhalt: some View {
        switch block.inhalt {
        case .titel, .unterueberschrift, .datum, .text:
            Textkasten(
                text: Seitensatz.inhaltstext(block, tag: tag, reise: werk.reise),
                bild: Seitensatz.schriftbild(block, reise: werk.reise),
                rand: wirkung.textrand
            )
        case .bildunterschrift:
            let text = Seitensatz.inhaltstext(block, tag: tag, reise: werk.reise)
            if text.isEmpty {
                // KEIN WORT, SONDERN EINE MARKE (ab 1.0.36).
                //
                // Hier stand bis 1.0.35 das Wort „Bildunterschrift …".
                // Gemeldet 09/2026: „an manchen Stellen steht Text, der wie
                // eine Regieanweisung wirkt. Ich weiß nicht, wo das
                // herkommt." Genau das war es — und wie es dorthin kam,
                // ist am Quelltext abzulesen: Ein DOPPELTIPP auf ein Foto
                // schaltet die Unterschrift ein (`unterschriftOeffnen`),
                // und wer danach nichts schreibt, hat von da an dieses
                // Wort unter dem Bild stehen. Ein Doppeltipp ist aber auch
                // der Griff, mit dem man Text bearbeitet; man landet also
                // versehentlich dort.
                //
                // Der Grund für die Anzeige bleibt trotzdem richtig: Eine
                // eingeschaltete Unterschrift ohne Text wäre sonst eine
                // unsichtbare Fläche, die sich nicht antippen lässt, weil
                // niemand weiß, wo sie liegt. Also bleibt eine MARKE — eine
                // dünne Linie, so lang wie ein paar Wörter — und kein Wort:
                // Die sieht man als leeres Feld und liest sie nicht als Satz.
                // Ins PDF geht sie so wenig wie das Wort vorher.
                //
                // Wie viele solcher leeren Unterschriften im Buch stehen und
                // wie man sie in einem Zug wieder los wird, sagt
                // `Druckpruefung.leereUnterschriften`.
                let hoehe = max(werk.reise.typografie.bildunterschrift.groesse, 5)
                Rectangle()
                    .fill(.tertiary)
                    .opacity(0.45)
                    .frame(width: hoehe * 6, height: max(hoehe * 0.09, 0.5))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                Textkasten(text: text,
                           bild: Seitensatz.schriftbild(block, reise: werk.reise),
                           rand: wirkung.textrand)
            }
        case .linie:
            Rectangle()
                .fill((block.rand ?? werk.reise.akzent).farbe.opacity(0.55))
                .frame(height: max(block.rahmen.hoehe, 0.6))
        case .flaeche:
            Color.clear
        case .verlauf:
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0), location: 0),
                    .init(color: .black.opacity(0.30), location: 0.45),
                    .init(color: .black.opacity(0.72), location: 1),
                ],
                startPoint: .top, endPoint: .bottom
            )
        case let .foto(id):
            FotoKachel(werk: werk, block: block, fotoID: id)
        case .karte:
            KartenKachel(werk: werk, block: block, tag: tag)
        }
    }
}

struct FotoKachel: View {
    @ObservedObject var werk: Reisewerk
    let block: Block
    let fotoID: UUID

    var body: some View {
        GeometryReader { raum in
            let rahmen = CGRect(origin: .zero, size: raum.size)
            // GEMESSEN, weil es hier nicht zu rechnen ist: Ein
            // Vorschaubild kommt beim ersten Mal von der Platte und wird
            // entpackt — das läuft auf dem Hauptfaden, und wie lange es
            // dauert, hängt am Gerät und an der Bildgröße. Gezählt werden
            // ALLE Aufrufe samt Gesamtdauer; ein Treffer im Zwischenspeicher
            // kostet nichts und fällt in der Summe nicht auf. Steht im
            // Befund „Fotos 12× 900 ms", ist die Frage beantwortet.
            if let foto = werk.reise.foto(fotoID),
               let bild = werk.messer.sammelt("Fotos", {
                   Bildarchiv.shared.vorschau(foto.datei, reise: werk.reise.id,
                                              kante: vorschaukante(raum.size))
               })
            {
                // Dieselbe Rechnung wie im PDF — `zielrechteck` steht an
                // einer Stelle und wird hier nur angewandt.
                let ziel = block.ausschnitt.zielrechteck(bildgroesse: bild.size, rahmen: rahmen)
                Image(uiImage: bild)
                    .resizable()
                    .frame(width: ziel.width, height: ziel.height)
                    .offset(x: ziel.minX, y: ziel.minY)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color(.systemGray6))
                    .overlay { Image(systemName: "photo").foregroundStyle(.tertiary) }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: werk.reise.gestaltung.eckenradiusPt))
    }

    // Kein Original auf der Seite: Ein Dutzend 12-Megapixel-Bilder machen
    // aus dem Blättern eine Geduldsprobe.
    private func vorschaukante(_ groesse: CGSize) -> Int {
        let kante = max(groesse.width, groesse.height) * 2.2
        return min(max(Int(kante), 240), 1600)
    }
}

struct KartenKachel: View {
    @ObservedObject var werk: Reisewerk
    let block: Block
    let tag: Reisetag?
    @State private var bild: UIImage?
    // Ein leeres Feld hat zwei Gründe, und sie verlangen verschiedene
    // Handgriffe: Entweder gibt es noch keine Punkte, oder die Karte ließ
    // sich nicht holen (kein Netz, ein Kachelserver, der nicht antwortet,
    // eine eigene Adresse ohne Lizenzhinweis). Beides gleich auszusehen
    // wäre genau die Art stummer Befund, die diese App nicht abgibt.
    @State private var gescheitert = false

    var body: some View {
        GeometryReader { raum in
            ZStack {
                Rectangle().fill(Color(.systemGray6))
                if let bild {
                    Image(uiImage: bild).resizable().scaledToFill()
                } else {
                    VStack(spacing: 5) {
                        Image(systemName: gescheitert ? "map.trianglebadge.exclamationmark" : "map")
                            .foregroundStyle(.tertiary)
                        if (tag?.spur.isEmpty ?? true) {
                            Text("Noch keine Reisepunkte")
                                .font(.system(size: 8))
                                .foregroundStyle(.tertiary)
                        } else if gescheitert {
                            Text("Karte nicht geladen")
                                .font(.system(size: 8))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            .task(id: kennung(raum.size)) { await laden(raum.size) }
        }
        .clipShape(RoundedRectangle(cornerRadius: werk.reise.gestaltung.eckenradiusPt))
        // Auf der Seite ist die Karte ein Bild und nimmt keinen Finger an —
        // sonst schluckte sie jede Geste, die den Block bewegen wollte.
        .allowsHitTesting(false)
    }

    // Was für DIESE Karte gilt — eigene Einstellung, sonst die des Tages,
    // sonst die des Buches. Aufgelöst wird das in `Kartenwahl` und nur
    // dort; das PDF fragt dieselbe Stelle.
    private var geltend: Kartenwahl.Geltend {
        Kartenwahl.geltend(block: block, tag: tag, reise: werk.reise)
    }

    private func kennung(_ groesse: CGSize) -> String {
        let punkte = tag?.spur.map(\.koordinate) ?? []
        return "\(punkte.count)|\(Int(groesse.width))x\(Int(groesse.height))|\(geltend.merkmal)|\(werk.reise.akzent.rot)"
    }

    private func laden(_ groesse: CGSize) async {
        guard let tag, !tag.spur.isEmpty, groesse.width > 8 else { return }
        let gilt = geltend
        let ergebnis = await Kartenwerk.shared.bild(
            punkte: tag.spur.map(\.koordinate),
            groesse: CGSize(width: groesse.width * 2, height: groesse.height * 2),
            kartenbild: gilt.bild,
            linienfarbe: werk.reise.akzent,
            ausschnitt: gilt.ausschnitt
        )
        await MainActor.run {
            bild = ergebnis
            gescheitert = ergebnis == nil
        }
    }
}

// Derselbe Schatten wie im PDF — die Werte stehen in `Schattenart` und
// nicht zweimal.
extension View {
    @ViewBuilder
    func schattenwurf(_ art: Schattenart, massstab: Double) -> some View {
        if art == .keiner {
            self
        } else {
            let werte = art.werte
            shadow(color: .black.opacity(werte.deckung),
                   radius: werte.unschaerfe * massstab / 2,
                   y: werte.versatz * massstab)
        }
    }
}
