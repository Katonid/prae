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
                .onTapGesture {
                    werk.gewaehlterBlock = nil
                    werk.textBearbeitung = nil
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

            // Die Griffe sind eine ZEICHNUNG über dem gewählten Block und
            // nehmen keinen Finger an. Angefasst wird der Block selbst; er
            // trägt als einziger eine Geste und entscheidet an der Stelle,
            // an der der Finger aufsetzt, was gemeint war.
            if bearbeitbar, let block = gewaehlterBlock, werk.ausschnittsmodus != block.id,
               werk.textBearbeitung != block.id
            {
                Griffzeichnung(block: block, massstab: massstab, abstand: griffabstand)
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
        let gewaehlt = werk.gewaehlterBlock == block.id
        let versatz = schiebt == block.id ? zieht : .zero
        let rahmen = block.rahmen
        let randPt = Druckmass.pt(block.fotorand)
        // Ist der Block gewählt, reicht seine Trefferfläche über den Rahmen
        // hinaus — so weit, dass die Griffe darin liegen. Sie haben keine
        // eigene Geste mehr; getroffen wird der Block, und der rechnet
        // hinterher aus, welcher Griff gemeint war. Damit kann kein Griff
        // mehr „daneben" liegen.
        let saum = gewaehlt && bearbeitbar ? max(greifweite, griffabstand + greifweite) : 0

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
            // Was IM Block liegt, ist ein Bild und nimmt keinen Finger an.
            // Der Textkasten ist eine UIKit-Ansicht, und eine solche nimmt
            // sich den Finger, ohne ihn weiterzugeben — dieselbe Lehre wie
            // bei der Netzkarte der Abfahrtstafel.
            .allowsHitTesting(false)
            // Die Trefferfläche ist ein EIGENER, größerer Rahmen und kein
            // negativer Saum. Ein Kind, das über seinen Elternrahmen
            // hinausragt, nimmt in SwiftUI keinen Finger an — die Lehre von
            // 1.0.2 gilt hier genauso, und ein `padding(-saum)` liefe ihr
            // genau entgegen. Der Inhalt liegt mittig darin und damit
            // unverrückt an seiner Stelle.
            .frame(width: rahmen.breite + 2 * saum, height: rahmen.hoehe + 2 * saum)
            .contentShape(Rectangle())
            .offset(x: rahmen.x - saum + versatz.width, y: rahmen.y - saum + versatz.height)
            .onTapGesture(count: 2) {
                guard bearbeitbar, block.inhalt.istText else { return }
                werk.gewaehlterBlock = block.id
                werk.textBearbeitung = block.id
            }
            .onTapGesture {
                guard bearbeitbar else { return }
                werk.textBearbeitung = nil
                werk.gewaehlterBlock = gewaehlt ? nil : block.id
            }
            // Vorrang vor den Tipp-Gesten: Ein Tipp und eine Ziehbewegung
            // an derselben Ansicht streiten sich sonst, und der Tipp gewinnt.
            // Bei einer Mindeststrecke von drei Punkten kommt ein echter
            // Tipp trotzdem durch — er bewegt sich nicht.
            //
            // Abgeschaltet wird über die MASKE und nicht über ein `nil`:
            // `highPriorityGesture` nimmt keinen leeren Wert entgegen.
            .highPriorityGesture(
                blockgeste(block, saum: saum),
                including: bearbeitbar && werk.textBearbeitung != block.id ? .all : .subviews
            )
    }

    // EINE Geste je Block, und sie entscheidet an der Stelle, an der der
    // Finger aufsetzt, was gemeint war: schieben, an einem der acht Griffe
    // ziehen oder am Dreher drehen.
    //
    // Bis 1.0.3 hatte jeder Griff seine eigene Geste, und dazu trug der
    // Block zwei Tipp-Gesten. Gemeldet wurde zweimal, dass sich Bilder
    // nicht verschieben und Rahmen nicht ziehen lassen. Wer mehrere Gesten
    // übereinanderlegt, muss wissen, welche gewinnt — und genau das ließ
    // sich hier nicht messen. Also gibt es nur noch eine.
    private func blockgeste(_ block: Block, saum: Double) -> some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { wert in ziehen(block, wert: wert, saum: saum, endgueltig: false) }
            .onEnded { wert in ziehen(block, wert: wert, saum: saum, endgueltig: true) }
    }

    // `saum` ist der Unterschied zwischen der Trefferfläche und dem Block:
    // Die Geste hängt an der größeren Fläche, gerechnet wird in den
    // Koordinaten des Blocks.
    private func ziehen(_ block: Block, wert: DragGesture.Value, saum: Double,
                        endgueltig: Bool)
    {
        if werk.ausschnittsmodus == block.id {
            ausschnittSchieben(block, wert: wert, endgueltig: endgueltig)
            return
        }
        let beginn = CGPoint(x: wert.startLocation.x - saum, y: wert.startLocation.y - saum)
        let jetzt = CGPoint(x: wert.location.x - saum, y: wert.location.y - saum)
        if gegriffen == nil {
            let art = griffUnter(beginn, block: block)
            gegriffen = art
            werk.letzterGriff = "\(art.name) an \(block.inhalt.name)"
            werk.gewaehlterBlock = block.id
            werk.merken()
            ausgangsrahmen = block.rahmen
        }
        switch gegriffen ?? .verschieben {
        case .verschieben:
            verschieben(block, wert: wert, endgueltig: endgueltig)
        case .drehen:
            drehen(block, zeigt: jetzt)
        default:
            groesseAendern(block, wert: wert)
        }
        if endgueltig {
            werk.letzterGriff = (werk.letzterGriff ?? "") + String(
                format: " \u{00B7} %.1f / %.1f mm \u{00B7} Maßstab %.2f",
                Druckmass.mm(wert.translation.width),
                Druckmass.mm(wert.translation.height), massstab)
            gegriffen = nil
            ausgangsrahmen = nil
        }
    }

    // Welcher Griff liegt unter dem Finger? Gerechnet wird in den
    // Koordinaten des Blocks; bei einem gedrehten Block wird der Punkt
    // vorher um die Mitte zurückgedreht — die Griffe drehen ja mit.
    private func griffUnter(_ punkt: CGPoint, block: Block) -> Griffart {
        guard werk.gewaehlterBlock == block.id else { return .verschieben }
        let breite = block.rahmen.breite
        let hoehe = block.rahmen.hoehe
        var stelle = punkt
        if abs(block.drehung) > 0.01 {
            let mitte = CGPoint(x: breite / 2, y: hoehe / 2)
            let winkel = -block.drehung * .pi / 180
            let dx = punkt.x - mitte.x
            let dy = punkt.y - mitte.y
            stelle = CGPoint(x: mitte.x + dx * cos(winkel) - dy * sin(winkel),
                             y: mitte.y + dx * sin(winkel) + dy * cos(winkel))
        }
        return Grifflage.getroffen(stelle, breite: breite, hoehe: hoehe,
                                   abstand: griffabstand, greifweite: greifweite) ?? .verschieben
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
