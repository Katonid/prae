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

            // Die Griffe liegen als EIGENE Ebene über allen Blöcken.
            //
            // Bis 1.0.1 hingen sie als `.overlay` im Block und ragten mit
            // ihrer halben Breite über dessen Rahmen hinaus — und was
            // außerhalb eines Frames liegt, nimmt in SwiftUI keinen Finger
            // an. Gemeldet 09/2026: „Ich kann ein Textfeld nicht in der
            // Größe skalieren." Der Knopf war da und ließ sich nicht
            // treffen; das ist für den Menschen davor dasselbe wie keiner.
            if bearbeitbar, let block = gewaehlterBlock, werk.ausschnittsmodus != block.id,
               werk.textBearbeitung != block.id
            {
                Griffe(werk: werk, block: block, massstab: massstab,
                       nachbarn: buchseite.seite.bloecke.filter { $0.id != block.id })
            }

            if bearbeitbar, let id = werk.textBearbeitung,
               let block = buchseite.seite.bloecke.first(where: { $0.id == id })
            {
                InlineText(werk: werk, block: block, tag: buchseite.tag, massstab: massstab)
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

    @ViewBuilder
    private func blockAnsicht(_ block: Block) -> some View {
        let gewaehlt = werk.gewaehlterBlock == block.id
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
            .overlay {
                if gewaehlt, bearbeitbar {
                    Rectangle()
                        .strokeBorder(Color.accentColor, lineWidth: 1.5 / massstab)
                        .allowsHitTesting(false)
                }
            }
            .offset(x: rahmen.x + versatz.width, y: rahmen.y + versatz.height)
            .contentShape(Rectangle())
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
            .gesture(bearbeitbar && werk.textBearbeitung != block.id ? schiebegeste(block) : nil)
    }

    // Geschoben wird in Bildschirmpunkten, gespeichert in Seitenpunkten —
    // die Division durch den Maßstab ist der ganze Unterschied.
    private func schiebegeste(_ block: Block) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { wert in
                if werk.ausschnittsmodus == block.id {
                    ausschnittSchieben(block, wert: wert, endgueltig: false)
                    return
                }
                if schiebt != block.id {
                    schiebt = block.id
                    werk.gewaehlterBlock = block.id
                    // Einmal merken, wenn die Bewegung ANFÄNGT. Bei jedem
                    // Bildpunkt zu merken füllte den Rückgängig-Stapel mit
                    // sechzig Zwischenständen einer einzigen Geste.
                    werk.merken()
                }
                zieht = CGSize(width: wert.translation.width / massstab,
                               height: wert.translation.height / massstab)
            }
            .onEnded { wert in
                if werk.ausschnittsmodus == block.id {
                    ausschnittSchieben(block, wert: wert, endgueltig: true)
                    return
                }
                let dx = wert.translation.width / massstab
                let dy = wert.translation.height / massstab
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
    }

    private func ausschnittSchieben(_ block: Block, wert: DragGesture.Value, endgueltig: Bool) {
        guard let id = block.fotoID, let foto = werk.reise.foto(id) else { return }
        let rahmen = block.rahmen.rect
        let bildgroesse = CGSize(width: foto.breite, height: foto.hoehe)
        let dx = wert.translation.width / massstab / max(rahmen.width, 1)
        let dy = wert.translation.height / massstab / max(rahmen.height, 1)
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

    var body: some View {
        GeometryReader { raum in
            ZStack {
                Rectangle().fill(Color(.systemGray6))
                if let bild {
                    Image(uiImage: bild).resizable().scaledToFill()
                } else {
                    VStack(spacing: 5) {
                        Image(systemName: "map").foregroundStyle(.tertiary)
                        if (tag?.spur.isEmpty ?? true) {
                            Text("Noch keine Reisepunkte")
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
        let stil = tag?.kartenstil ?? werk.reise.kartenstil
        return "\(punkte.count)|\(Int(groesse.width))x\(Int(groesse.height))|\(stil.rawValue)|\(tag?.kartenausschnitt?.spanne ?? -1)|\(werk.reise.akzent.rot)"
    }

    private func laden(_ groesse: CGSize) async {
        guard let tag, !tag.spur.isEmpty, groesse.width > 8 else { return }
        let ergebnis = await Kartenwerk.shared.bild(
            punkte: tag.spur.map(\.koordinate),
            groesse: CGSize(width: groesse.width * 2, height: groesse.height * 2),
            stil: tag.kartenstil ?? werk.reise.kartenstil,
            linienfarbe: werk.reise.akzent,
            ausschnitt: tag.kartenausschnitt
        )
        await MainActor.run { bild = ergebnis }
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
