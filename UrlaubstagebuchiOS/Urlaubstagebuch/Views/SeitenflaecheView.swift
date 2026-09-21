import SwiftUI

// Die Seite, wie sie gedruckt wird — und auf der man arbeiten kann.
//
// Gerechnet wird durchweg in SEITENPUNKTEN. Der Maßstab liegt als eine
// einzige Skalierung über dem Ganzen; jede Geste wird durch ihn geteilt,
// bevor sie ins Modell geht. Der Bildschirm ist damit nur ein Fenster auf
// die Seite und nie ihr Maß — sonst sähe ein Buch, das auf dem iPhone
// gestaltet wurde, auf dem iPad anders aus.
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

    var body: some View {
        // Gezeigt wird der ganze BOGEN, also Endformat plus Anschnitt. Wer
        // nur das Endformat sähe, könnte nicht beurteilen, ob ein Bild weit
        // genug übersteht — und genau dort entscheidet sich, ob im
        // gedruckten Buch ein weißer Faden stehen bleibt.
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill((buchseite.seite.papier ?? werk.reise.gestaltung.papier).farbe)
                .frame(width: bogen.width, height: bogen.height)
                .offset(x: -anschnitt, y: -anschnitt)
                .onTapGesture { werk.gewaehlterBlock = nil }

            if bearbeitbar, werk.zeigeSatzspiegel {
                let satz = werk.reise.gestaltung.satzspiegel(werk.reise.format)
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
            // das Buch beschnitten wird; was außerhalb liegt, sieht später
            // niemand mehr. Sie unter den Bildern zu zeichnen hieße, sie
            // genau dort zu verstecken, wo sie gebraucht wird.
            if bearbeitbar, anschnitt > 0.5, werk.zeigeSatzspiegel {
                Rectangle()
                    .strokeBorder(style: StrokeStyle(lineWidth: 0.8, dash: [7, 4]))
                    .foregroundStyle(Color.red.opacity(0.55))
                    .frame(width: format.width, height: format.height)
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

    @ViewBuilder
    private func blockAnsicht(_ block: Block) -> some View {
        let gewaehlt = werk.gewaehlterBlock == block.id
        let versatz = schiebt == block.id ? zieht : .zero
        let rahmen = block.rahmen

        BlockInhaltView(werk: werk, block: block, tag: buchseite.tag)
            .frame(width: rahmen.breite, height: rahmen.hoehe)
            .padding(Druckmass.pt(block.fotorand))
            .background {
                if block.fotorand > 0 {
                    RoundedRectangle(cornerRadius: werk.reise.gestaltung.eckenradiusPt)
                        .fill(Color.white)
                }
            }
            .schattenwurf(block.schatten, massstab: format.width / 600)
            .padding(-Druckmass.pt(block.fotorand))
            .frame(width: rahmen.breite, height: rahmen.hoehe)
            .rotationEffect(.degrees(block.drehung))
            .overlay {
                if gewaehlt, bearbeitbar {
                    Rectangle()
                        .strokeBorder(Color.accentColor, lineWidth: 1.5 / massstab)
                        .allowsHitTesting(false)
                }
            }
            .overlay {
                if gewaehlt, bearbeitbar, werk.ausschnittsmodus != block.id {
                    Griffe(block: block, massstab: massstab, werk: werk,
                           nachbarn: buchseite.seite.bloecke.filter { $0.id != block.id })
                }
            }
            .offset(x: rahmen.x + versatz.width, y: rahmen.y + versatz.height)
            .contentShape(Rectangle())
            .onTapGesture {
                guard bearbeitbar else { return }
                werk.gewaehlterBlock = gewaehlt ? nil : block.id
            }
            .gesture(bearbeitbar ? schiebegeste(block) : nil)
    }

    // Geschoben wird in Bildschirmpunkten, gespeichert in Seitenpunkten —
    // die Division durch den Maßstab ist der ganze Unterschied. Ohne sie
    // wanderte ein Block auf einer klein gezoomten Seite dreimal so weit
    // wie der Finger.
    private func schiebegeste(_ block: Block) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { wert in
                // Im Ausschnittsmodus wandert das Bild im Rahmen, nicht der
                // Rahmen auf der Seite.
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
                    satz: werk.reise.gestaltung.satzspiegel(werk.reise.format),
                    toleranz: 6 / massstab
                )
                werk.schiebe(block.id, dx: gefangen.dx, dy: gefangen.dy, merken: false)
                schiebt = nil
                zieht = .zero
            }
    }

    private func ausschnittSchieben(_ block: Block, wert: DragGesture.Value, endgueltig: Bool) {
        guard let foto = werk.reise.foto(block.fotoID ?? UUID()) else { return }
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

// Die vier Ecken, an denen sich die Größe ändern lässt.
//
// Sie liegen AUSSERHALB des Blocks (ein halber Griff ragt über die Kante),
// damit sie nicht die Fläche verdecken, die sie verändern sollen — und sie
// werden mit dem Maßstab gegengerechnet: Ein Griff, der auf einer klein
// gezoomten Seite auf zwei Bildpunkte schrumpft, ist keiner.
private struct Griffe: View {
    let block: Block
    let massstab: Double
    @ObservedObject var werk: Reisewerk
    let nachbarn: [Block]

    private var groesse: Double { 13 / massstab }

    var body: some View {
        ZStack {
            griff(.topLeading)
            griff(.topTrailing)
            griff(.bottomLeading)
            griff(.bottomTrailing)
        }
    }

    private func griff(_ ecke: Alignment) -> some View {
        Circle()
            .fill(Color.white)
            .overlay(Circle().strokeBorder(Color.accentColor, lineWidth: 2 / massstab))
            .frame(width: groesse, height: groesse)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: ecke)
            .offset(x: ecke.horizontal == .leading ? -groesse / 2 : groesse / 2,
                    y: ecke.vertical == .top ? -groesse / 2 : groesse / 2)
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { wert in groesseAendern(ecke, wert: wert, endgueltig: false) }
                    .onEnded { wert in groesseAendern(ecke, wert: wert, endgueltig: true) }
            )
    }

    @State private var start: Rahmen?

    private func groesseAendern(_ ecke: Alignment, wert: DragGesture.Value, endgueltig: Bool) {
        let ausgang = start ?? block.rahmen
        if start == nil { start = block.rahmen; werk.merken() }
        let dx = wert.translation.width / massstab
        let dy = wert.translation.height / massstab

        var neu = ausgang
        if ecke.horizontal == .leading {
            neu.x = ausgang.x + dx
            neu.breite = ausgang.breite - dx
        } else {
            neu.breite = ausgang.breite + dx
        }
        if ecke.vertical == .top {
            neu.y = ausgang.y + dy
            neu.hoehe = ausgang.hoehe - dy
        } else {
            neu.hoehe = ausgang.hoehe + dy
        }
        // Unter dieser Größe ist ein Block nicht mehr zu treffen — und ein
        // Block, den man nicht mehr anfassen kann, ist verloren.
        neu.breite = max(neu.breite, 28)
        neu.hoehe = max(neu.hoehe, 16)

        let satz = werk.reise.gestaltung.satzspiegel(werk.reise.format)
        var kantenX: [Double] = [satz.minX, satz.maxX, satz.midX]
        var kantenY: [Double] = [satz.minY, satz.maxY, satz.midY]
        for nachbar in nachbarn {
            let r = nachbar.rahmen.rect
            kantenX.append(contentsOf: [r.minX, r.maxX])
            kantenY.append(contentsOf: [r.minY, r.maxY])
        }
        let toleranz = 6 / massstab
        if ecke.horizontal == .leading {
            let gefangen = Einrasten.kanteGefangen(neu.x, kanten: kantenX, toleranz: toleranz)
            neu.breite += neu.x - gefangen
            neu.x = gefangen
        } else {
            let rechts = Einrasten.kanteGefangen(neu.x + neu.breite, kanten: kantenX, toleranz: toleranz)
            neu.breite = rechts - neu.x
        }
        if ecke.vertical == .top {
            let gefangen = Einrasten.kanteGefangen(neu.y, kanten: kantenY, toleranz: toleranz)
            neu.hoehe += neu.y - gefangen
            neu.y = gefangen
        } else {
            let unten = Einrasten.kanteGefangen(neu.y + neu.hoehe, kanten: kantenY, toleranz: toleranz)
            neu.hoehe = unten - neu.y
        }

        werk.aendere(block.id, merken: false) { $0.rahmen = neu }
        if endgueltig { start = nil }
    }
}


// Was ein Block zeigt.
struct BlockInhaltView: View {
    @ObservedObject var werk: Reisewerk
    let block: Block
    let tag: Reisetag?

    var body: some View {
        ZStack {
            if let grund = block.grund {
                RoundedRectangle(cornerRadius: werk.reise.gestaltung.eckenradius)
                    .fill(grund.farbe)
            }
            inhalt
            if let rand = block.rand, block.randbreite > 0 {
                RoundedRectangle(cornerRadius: werk.reise.gestaltung.eckenradius)
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
            // Derselbe Verlauf wie im PDF: unten dunkel, oben durchsichtig.
            // Ohne ihn stünde die Überschrift des Tages auf einem hellen
            // Himmel und wäre weg.
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
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.tertiary)
                    }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: werk.reise.gestaltung.eckenradius))
    }

    // Kein Original auf der Seite: Ein Dutzend 12-Megapixel-Bilder machen
    // aus dem Blättern eine Geduldsprobe. Gerechnet wird mit der Kante, die
    // wirklich gebraucht wird — mal zwei für scharfe Ränder.
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
                    Image(uiImage: bild)
                        .resizable()
                        .scaledToFill()
                } else {
                    VStack(spacing: 5) {
                        Image(systemName: "map")
                            .foregroundStyle(.tertiary)
                        if (tag?.spur.isEmpty ?? true) {
                            Text("Noch keine Reisepunkte")
                                .font(.system(size: 8))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            .task(id: kennung(raum.size)) {
                await laden(raum.size)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: werk.reise.gestaltung.eckenradius))
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
private extension View {
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
