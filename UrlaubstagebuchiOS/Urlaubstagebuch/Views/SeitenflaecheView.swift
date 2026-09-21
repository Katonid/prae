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

    @State private var schiebt: UUID?
    @State private var zieht: CGSize = .zero
    // Was der Finger beim Aufsetzen gegriffen hat. Entschieden wird EINMAL,
    // beim ersten Bildpunkt der Bewegung — sonst wechselte mitten im Ziehen
    // die Bedeutung, sobald der Finger über einen anderen Griff wandert.
    @State private var gegriffen: Griffart?
    @State private var ausgangsrahmen: Rahmen?

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
            HintergrundFlaeche(werk: werk, hintergrund: hintergrund, seite: buchseite.seite)
                .frame(width: bogen.width, height: bogen.height)
                .offset(x: -anschnitt, y: -anschnitt)
                .allowsHitTesting(false)

            if bearbeitbar, werk.zeigeSatzspiegel {
                Rectangle()
                    .strokeBorder(style: StrokeStyle(lineWidth: 0.7, dash: [4, 4]))
                    .foregroundStyle(Color.accentColor.opacity(0.35))
                    .frame(width: satz.width, height: satz.height)
                    .offset(x: satz.minX, y: satz.minY)
                    .allowsHitTesting(false)
            }

            ForEach(buchseite.seite.sortiert) { block in
                blockAnsicht(block)
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
                Color.clear
                    .frame(width: block.rahmen.breite + 2 * saum,
                           height: block.rahmen.hoehe + 2 * saum)
                    .contentShape(Rectangle())
                    .offset(x: block.rahmen.x - saum, y: block.rahmen.y - saum)
                    // Die Tipps gehören mit auf diese Fläche: Sie liegt über
                    // dem Block, und ohne sie käme über dem gewählten Block
                    // kein Tipp mehr an — also weder das Abwählen noch der
                    // Doppeltipp, der den Text öffnet.
                    .onTapGesture(count: 2, coordinateSpace: .local) { punkt in
                        doppeltipp(aufSeite(punkt, block: block, saum: saum))
                    }
                    .onTapGesture(count: 1, coordinateSpace: .local) { punkt in
                        einfachtipp(aufSeite(punkt, block: block, saum: saum))
                    }
                    .gesture(ziehgeste(block, saum: saum))
            }

            if bearbeitbar, let id = werk.textBearbeitung,
               let block = buchseite.seite.bloecke.first(where: { $0.id == id })
            {
                InlineText(werk: werk, block: block, tag: buchseite.tag, massstab: massstab)
            }

            // Die Probe: Was hat die Seite zuletzt entgegengenommen? Sie
            // steht nur da, wenn jemand sie eingeschaltet hat, und sie sagt
            // nichts als das Gemessene.
            if bearbeitbar, werk.zeigeGriffprobe {
                Text(werk.letzterGriff ?? "noch nichts gegriffen")
                    .font(.system(size: 9 / massstab, design: .monospaced))
                    .padding(.horizontal, 5 / massstab)
                    .padding(.vertical, 3 / massstab)
                    .background(Color.black.opacity(0.72), in: Capsule())
                    .foregroundStyle(.white)
                    .offset(x: satz.minX, y: satz.minY - 16 / massstab)
                    .allowsHitTesting(false)
            }
        }
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
        .contentShape(Rectangle())
        .onTapGesture(count: 2, coordinateSpace: .local) { punkt in doppeltipp(punkt) }
        .onTapGesture(count: 1, coordinateSpace: .local) { punkt in einfachtipp(punkt) }
        .offset(x: anschnitt, y: anschnitt)
        .frame(width: bogen.width, height: bogen.height, alignment: .topLeading)
        .clipped()
        .background(Color.white)
        .compositingGroup()
        .shadow(color: .black.opacity(0.18), radius: 9, y: 3)
        .scaleEffect(massstab, anchor: .topLeading)
        .frame(width: bogen.width * massstab, height: bogen.height * massstab)
    }

    // Der Abstand des Drehgriffs über dem Block — an einer Stelle, weil
    // Zeichnung und Treffprüfung denselben Wert brauchen.
    private var griffabstand: Double { 32 / massstab }
    private var greifweite: Double { 24 / massstab }

    @ViewBuilder
    private func blockAnsicht(_ block: Block) -> some View {
        let versatz = schiebt == block.id ? zieht : .zero
        let rahmen = block.rahmen
        let randPt = Druckmass.pt(block.fotorand)

        BlockInhaltView(werk: werk, block: block, tag: buchseite.tag)
            .frame(width: rahmen.breite, height: rahmen.hoehe)
            .padding(randPt)
            .background {
                if block.fotorand > 0 {
                    RoundedRectangle(cornerRadius: werk.reise.gestaltung.eckenradiusPt)
                        .fill(Color.white)
                }
            }
            .schattenwurf(block.schatten, massstab: format.width / 600)
            .padding(-randPt)
            .frame(width: rahmen.breite, height: rahmen.hoehe)
            .rotationEffect(.degrees(block.drehung))
            .offset(x: rahmen.x + versatz.width, y: rahmen.y + versatz.height)
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
        guard treffer.inhalt.istText else { return }
        werk.textBearbeitung = treffer.id
    }

    // MARK: - Ziehen

    // Wie weit die Ziehfläche über den Block hinausreicht: so weit, dass
    // die Griffe samt Drehgriff darin liegen. Im Ausschnittsmodus gibt es
    // keine Griffe — dort bleibt die Fläche beim Bild.
    private func ziehsaum(_ block: Block) -> Double {
        werk.ausschnittsmodus == block.id ? 0 : max(greifweite, griffabstand + greifweite)
    }

    private func ziehgeste(_ block: Block, saum: Double) -> some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { wert in ziehen(block, saum: saum, wert: wert, endgueltig: false) }
            .onEnded { wert in ziehen(block, saum: saum, wert: wert, endgueltig: true) }
    }

    // Die Geste meldet in den Koordinaten IHRER Fläche, und die beginnt um
    // den Saum vor dem Block. Umgerechnet wird einmal, hier.
    private func aufSeite(_ punkt: CGPoint, block: Block, saum: Double) -> CGPoint {
        CGPoint(x: punkt.x + block.rahmen.x - saum, y: punkt.y + block.rahmen.y - saum)
    }

    private func ziehen(_ block: Block, saum: Double, wert: DragGesture.Value,
                        endgueltig: Bool)
    {
        if gegriffen == nil {
            griffFestlegen(aufSeite(wert.startLocation, block: block, saum: saum), block: block)
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
            verschieben(block, wert: wert, endgueltig: endgueltig)
        case .drehen:
            // UNGEDREHT: `drehen` setzt den Winkel absolut, gemessen im
            // ruhenden Koordinatensystem der Seite. Mit dem
            // zurückgedrehten Punkt wäre er relativ zur schon gesetzten
            // Drehung, und der Block liefe dem Finger davon.
            let jetzt = aufSeite(wert.location, block: block, saum: saum)
            drehen(block, zeigt: CGPoint(x: jetzt.x - block.rahmen.x,
                                         y: jetzt.y - block.rahmen.y))
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
        let art = Grifflage.getroffen(imBlock(punkt, block: block, absolut: false),
                                      breite: block.rahmen.breite,
                                      hoehe: block.rahmen.hoehe,
                                      abstand: griffabstand,
                                      greifweite: greifweite) ?? .verschieben
        gegriffen = art
        ausgangsrahmen = block.rahmen
        werk.letzterGriff = "\(art.name) an \(block.inhalt.name)"
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
    }

    // MARK: - Schieben

    private func verschieben(_ block: Block, wert: DragGesture.Value, endgueltig: Bool) {
        // OHNE Teilung durch den Maßstab. Eine Geste wird in den eigenen
        // Koordinaten der Ansicht gemeldet, an der sie hängt — und die
        // liegen INNERHALB des `scaleEffect`, also schon in Seitenpunkten.
        // Bis 1.0.4 wurde hier zusätzlich geteilt; bei halb gezeigter Seite
        // lief der Block damit doppelt so weit wie der Finger. Gemessen ist
        // das nicht, deshalb nennt die Probe die Strecke und den Maßstab:
        // Wandert der Block genau mit dem Finger, stimmt es.
        let dx = wert.translation.width
        let dy = wert.translation.height
        if !endgueltig {
            schiebt = block.id
            zieht = CGSize(width: dx, height: dy)
            return
        }
        let gefangen = Einrasten.gefangen(
            block: block, dx: dx, dy: dy,
            nachbarn: buchseite.seite.bloecke.filter { $0.id != block.id },
            satz: satz,
            toleranz: 6 / massstab
        )
        werk.schiebe(block.id, dx: gefangen.dx, dy: gefangen.dy, merken: false)
        schiebt = nil
        zieht = .zero
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

        var kantenX: [Double] = [satz.minX, satz.maxX, satz.midX]
        var kantenY: [Double] = [satz.minY, satz.maxY, satz.midY]
        if werk.reise.gestaltung.anschnitt > 0.5 {
            let bogen = werk.reise.gestaltung.randabfallend(werk.reise.format)
            kantenX.append(contentsOf: [bogen.minX, bogen.maxX])
            kantenY.append(contentsOf: [bogen.minY, bogen.maxY])
        }
        for nachbar in buchseite.seite.bloecke where nachbar.id != block.id {
            let r = nachbar.rahmen.rect
            kantenX.append(contentsOf: [r.minX, r.maxX])
            kantenY.append(contentsOf: [r.minY, r.maxY])
        }
        let toleranz = 7 / massstab
        if richtung.waagerecht < 0 {
            let gefangen = Einrasten.kanteGefangen(neu.x, kanten: kantenX, toleranz: toleranz)
            neu.breite += neu.x - gefangen
            neu.x = gefangen
        } else if richtung.waagerecht > 0 {
            let rechts = Einrasten.kanteGefangen(neu.x + neu.breite, kanten: kantenX,
                                                 toleranz: toleranz)
            neu.breite = rechts - neu.x
        }
        if richtung.senkrecht < 0 {
            let gefangen = Einrasten.kanteGefangen(neu.y, kanten: kantenY, toleranz: toleranz)
            neu.hoehe += neu.y - gefangen
            neu.y = gefangen
        } else if richtung.senkrecht > 0 {
            let unten = Einrasten.kanteGefangen(neu.y + neu.hoehe, kanten: kantenY,
                                                toleranz: toleranz)
            neu.hoehe = unten - neu.y
        }

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
        let rahmen = block.rahmen.rect
        let bildgroesse = CGSize(width: foto.breite, height: foto.hoehe)
        let dx = wert.translation.width / max(rahmen.width, 1)
        let dy = wert.translation.height / max(rahmen.height, 1)
        werk.aendere(block.id, merken: endgueltig) { block in
            var neu = block.ausschnitt
            neu.versatzX += dx
            neu.versatzY += dy
            block.ausschnitt = neu.begrenzt(bildgroesse: bildgroesse, rahmen: rahmen)
        }
    }
}

// MARK: - Hintergrund

struct HintergrundFlaeche: View {
    @ObservedObject var werk: Reisewerk
    let hintergrund: Seitenhintergrund
    let seite: Seite

    var body: some View {
        ZStack {
            switch hintergrund.art {
            case .einfarbig:
                hintergrund.farbe.farbe
            case .verlauf:
                hintergrund.swiftUIVerlauf
            case .papierstruktur:
                hintergrund.farbe.farbe
                Papierkorn(staerke: hintergrund.koernung)
            case .foto:
                hintergrund.farbe.farbe
                if let id = hintergrund.fotoID, let foto = werk.reise.foto(id),
                   let bild = Bildarchiv.shared.vorschau(foto.datei, reise: werk.reise.id,
                                                         kante: 1400)
                {
                    Image(uiImage: bild)
                        .resizable()
                        .scaledToFill()
                }
                hintergrund.farbe.farbe.opacity(hintergrund.schleier)
            }
        }
        .clipped()
    }
}

// Ein feines Korn, damit eine einfarbige Fläche nicht wie ein Bildschirm
// aussieht. Gerechnet statt geladen — eine Bilddatei dafür wäre ein
// Megabyte für etwas, das man kaum sieht und trotzdem vermisst.
struct Papierkorn: View {
    let staerke: Double

    var body: some View {
        Canvas { zusammenhang, groesse in
            guard staerke > 0.005 else { return }
            var zufall = SystemRandomNumberGenerator()
            let punkte = Int(groesse.width * groesse.height / 900)
            for _ in 0..<punkte {
                let x = Double.random(in: 0..<groesse.width, using: &zufall)
                let y = Double.random(in: 0..<groesse.height, using: &zufall)
                let deckung = Double.random(in: 0..<staerke, using: &zufall)
                zusammenhang.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: 1.2, height: 1.2)),
                    with: .color(.black.opacity(deckung))
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

    var body: some View {
        ZStack {
            if let grund = block.grund {
                RoundedRectangle(cornerRadius: werk.reise.gestaltung.eckenradiusPt)
                    .fill(grund.farbe)
            }
            inhalt
            if let rand = block.rand, block.randbreite > 0, block.inhalt != .linie {
                RoundedRectangle(cornerRadius: werk.reise.gestaltung.eckenradiusPt)
                    .strokeBorder(rand.farbe, lineWidth: block.randbreite)
            }
        }
    }

    @ViewBuilder
    private var inhalt: some View {
        switch block.inhalt {
        case .titel, .datum, .text:
            Textkasten(
                text: Seitensatz.inhaltstext(block, tag: tag, reise: werk.reise),
                bild: Seitensatz.schriftbild(block, reise: werk.reise)
            )
        case .bildunterschrift:
            let text = Seitensatz.inhaltstext(block, tag: tag, reise: werk.reise)
            if text.isEmpty {
                // Nur auf dem Bildschirm und nie im PDF: Eine eingeschaltete
                // Unterschrift ohne Text wäre sonst eine unsichtbare Fläche,
                // die sich nicht antippen lässt, weil niemand weiß, wo sie
                // liegt.
                Text("Bildunterschrift \u{2026}")
                    .font(.system(size: max(werk.reise.typografie.bildunterschrift.groesse, 5)))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Textkasten(text: text,
                           bild: Seitensatz.schriftbild(block, reise: werk.reise))
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
            if let foto = werk.reise.foto(fotoID),
               let bild = Bildarchiv.shared.vorschau(foto.datei, reise: werk.reise.id,
                                                     kante: vorschaukante(raum.size))
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

    private func kennung(_ groesse: CGSize) -> String {
        let punkte = tag?.spur.map(\.koordinate) ?? []
        let bild = tag?.kartenbild ?? werk.reise.kartenbild
        return "\(punkte.count)|\(Int(groesse.width))x\(Int(groesse.height))|\(bild.merkmal)|\(tag?.kartenausschnitt?.spanne ?? -1)|\(werk.reise.akzent.rot)"
    }

    private func laden(_ groesse: CGSize) async {
        guard let tag, !tag.spur.isEmpty, groesse.width > 8 else { return }
        let ergebnis = await Kartenwerk.shared.bild(
            punkte: tag.spur.map(\.koordinate),
            groesse: CGSize(width: groesse.width * 2, height: groesse.height * 2),
            kartenbild: tag.kartenbild ?? werk.reise.kartenbild,
            linienfarbe: werk.reise.akzent,
            ausschnitt: tag.kartenausschnitt
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
