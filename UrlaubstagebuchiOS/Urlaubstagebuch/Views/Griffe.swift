import SwiftUI
import UIKit

// Die Anfasser am gewählten Block: vier Ecken zum Skalieren, ein Griff zum
// Drehen.
//
// Sie liegen als EIGENE Ebene über der Seite und nicht als `.overlay` im
// Block. Der Unterschied ist kein Stilfrage: Ein Griff ragt mit seiner
// halben Breite über den Rahmen hinaus, und was außerhalb eines Frames
// liegt, nimmt in SwiftUI keinen Finger an. Bis 1.0.1 waren die Griffe
// deshalb sichtbar und nicht zu treffen — gemeldet 09/2026: „Ich kann ein
// Textfeld nicht in der Größe skalieren."
struct Griffe: View {
    @ObservedObject var werk: Reisewerk
    let block: Block
    let massstab: Double
    let nachbarn: [Block]

    @State private var start: Rahmen?
    @State private var startwinkel: Double?

    private var groesse: Double { 15 / massstab }
    private var rahmen: CGRect { block.rahmen.rect }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ecke(.topLeading)
            ecke(.topTrailing)
            ecke(.bottomLeading)
            ecke(.bottomTrailing)
            dreher
        }
        .frame(width: rahmen.width, height: rahmen.height, alignment: .topLeading)
        .rotationEffect(.degrees(block.drehung))
        .offset(x: rahmen.minX, y: rahmen.minY)
    }

    // MARK: - Ecken

    private func ecke(_ stelle: Alignment) -> some View {
        Circle()
            .fill(Color.white)
            .overlay(Circle().strokeBorder(Color.accentColor, lineWidth: 2 / massstab))
            .frame(width: groesse, height: groesse)
            .contentShape(Circle().inset(by: -groesse * 0.4))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: stelle)
            .offset(x: stelle.horizontal == .leading ? -groesse / 2 : groesse / 2,
                    y: stelle.vertical == .top ? -groesse / 2 : groesse / 2)
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { wert in groesseAendern(stelle, wert: wert, endgueltig: false) }
                    .onEnded { wert in groesseAendern(stelle, wert: wert, endgueltig: true) }
            )
    }

    // MARK: - Drehen

    private var dreher: some View {
        Image(systemName: "arrow.trianglehead.clockwise")
            .font(.system(size: groesse * 0.62, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: groesse * 1.25, height: groesse * 1.25)
            .background(Circle().fill(Color.accentColor))
            .contentShape(Circle().inset(by: -groesse * 0.4))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .offset(y: -groesse * 2.1)
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { wert in drehen(wert, endgueltig: false) }
                    .onEnded { wert in drehen(wert, endgueltig: true) }
            )
    }

    // Gedreht wird um die MITTE des Blocks, und der Winkel kommt aus dem
    // Zeiger von der Mitte zum Finger — nicht aus der Wegstrecke. Eine
    // Drehung, die sich aus der Verschiebung errechnet, dreht am Rand
    // schneller als in der Mitte und fühlt sich sofort falsch an.
    private func drehen(_ wert: DragGesture.Value, endgueltig: Bool) {
        if startwinkel == nil {
            startwinkel = block.drehung
            werk.merken()
        }
        let mitte = CGPoint(x: rahmen.width / 2, y: rahmen.height / 2)
        // Der Griff sitzt über der Mitte; der Zeiger geht von der Mitte zum
        // Finger, und oben ist null Grad.
        let zeiger = CGPoint(x: wert.location.x - mitte.x,
                             y: wert.location.y - mitte.y - rahmen.height / 2)
        var grad = atan2(zeiger.x, -zeiger.y) * 180 / .pi + (startwinkel ?? 0)
        // In Fünf-Grad-Schritten, solange man nicht genau zielt — und bei
        // null, waagerecht und senkrecht mit einer kleinen Rast: Ein Bild,
        // das um 0,4 Grad schief steht, sieht nicht gewollt aus, sondern
        // nach einem Versehen.
        for rast in stride(from: -180.0, through: 180.0, by: 45) where abs(grad - rast) < 3 {
            grad = rast
        }
        werk.aendere(block.id, merken: false) { $0.drehung = grad }
        if endgueltig { startwinkel = nil }
    }

    // MARK: - Größe

    private func groesseAendern(_ stelle: Alignment, wert: DragGesture.Value, endgueltig: Bool) {
        let ausgang = start ?? block.rahmen
        if start == nil {
            start = block.rahmen
            werk.merken()
        }
        let dx = wert.translation.width / massstab
        let dy = wert.translation.height / massstab

        var neu = ausgang
        if stelle.horizontal == .leading {
            neu.x = ausgang.x + dx
            neu.breite = ausgang.breite - dx
        } else {
            neu.breite = ausgang.breite + dx
        }
        if stelle.vertical == .top {
            neu.y = ausgang.y + dy
            neu.hoehe = ausgang.hoehe - dy
        } else {
            neu.hoehe = ausgang.hoehe + dy
        }
        // Unter dieser Größe ist ein Block nicht mehr zu treffen — und ein
        // Block, den man nicht mehr anfassen kann, ist verloren.
        neu.breite = max(neu.breite, 24)
        neu.hoehe = max(neu.hoehe, 14)

        let satz = werk.reise.gestaltung.satzspiegel(werk.reise.format)
        var kantenX: [Double] = [satz.minX, satz.maxX, satz.midX]
        var kantenY: [Double] = [satz.minY, satz.maxY, satz.midY]
        if werk.reise.gestaltung.anschnitt > 0.5 {
            let bogen = werk.reise.gestaltung.randabfallend(werk.reise.format)
            kantenX.append(contentsOf: [bogen.minX, bogen.maxX])
            kantenY.append(contentsOf: [bogen.minY, bogen.maxY])
        }
        for nachbar in nachbarn {
            let r = nachbar.rahmen.rect
            kantenX.append(contentsOf: [r.minX, r.maxX])
            kantenY.append(contentsOf: [r.minY, r.maxY])
        }
        let toleranz = 7 / massstab
        if stelle.horizontal == .leading {
            let gefangen = Einrasten.kanteGefangen(neu.x, kanten: kantenX, toleranz: toleranz)
            neu.breite += neu.x - gefangen
            neu.x = gefangen
        } else {
            let rechts = Einrasten.kanteGefangen(neu.x + neu.breite, kanten: kantenX,
                                                 toleranz: toleranz)
            neu.breite = rechts - neu.x
        }
        if stelle.vertical == .top {
            let gefangen = Einrasten.kanteGefangen(neu.y, kanten: kantenY, toleranz: toleranz)
            neu.hoehe += neu.y - gefangen
            neu.y = gefangen
        } else {
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
        if endgueltig { start = nil }
    }
}

// MARK: - Text auf der Seite ändern

// Ein Textfeld an genau der Stelle, an der der Text steht — mit derselben
// Schrift, derselben Breite, demselben Zeilenabstand.
//
// Gemeldet 09/2026: „Wenn ich den eingegebenen Text korrigieren möchte, so
// muss ich auf ein kleines Menüfenster zurückgreifen. Ich würde den Text am
// liebsten direkt auf der Seite ändern können." Geöffnet wird mit einem
// Doppeltipp, geschlossen mit einem Tipp daneben oder „Fertig".
struct InlineText: View {
    @ObservedObject var werk: Reisewerk
    let block: Block
    let tag: Reisetag?
    let massstab: Double

    @State private var text: String = ""
    @State private var geladen = false

    private var bild: Schriftbild { Seitensatz.schriftbild(block, reise: werk.reise) }

    var body: some View {
        let rahmen = block.rahmen.rect
        TextflaecheBruecke(text: $text, bild: bild) {
            fertig()
        }
        .frame(width: rahmen.width, height: max(rahmen.height, bild.zeilenhoehe * 1.6))
        .background(Color.accentColor.opacity(0.07))
        .overlay(
            Rectangle().strokeBorder(Color.accentColor, lineWidth: 1.5 / massstab)
        )
        .offset(x: rahmen.minX, y: rahmen.minY)
        .onAppear {
            guard !geladen else { return }
            text = Seitensatz.inhaltstext(block, tag: tag, reise: werk.reise)
            geladen = true
        }
        .onDisappear { fertig() }
    }

    private func fertig() {
        guard geladen else { return }
        let vorher = Seitensatz.inhaltstext(block, tag: tag, reise: werk.reise)
        guard text != vorher else { return }
        werk.textSchreiben(block.id, text: text)
    }
}

// Die Brücke zu UIKit. Ein `TextEditor` aus SwiftUI wäre kürzer und kann
// die Attribute nicht, auf die es hier ankommt: feste Zeilenhöhe,
// Ausrichtung, Sperrung. Getippt werden soll in genau der Schrift, in der
// hinterher gedruckt wird.
struct TextflaecheBruecke: UIViewRepresentable {
    @Binding var text: String
    var bild: Schriftbild
    var fertig: () -> Void

    func makeUIView(context: Context) -> UITextView {
        let feld = UITextView()
        feld.delegate = context.coordinator
        feld.backgroundColor = .clear
        feld.textContainerInset = .zero
        feld.textContainer.lineFragmentPadding = 0
        feld.isScrollEnabled = false
        feld.autocorrectionType = .default
        feld.spellCheckingType = .default
        DispatchQueue.main.async { feld.becomeFirstResponder() }
        return feld
    }

    func updateUIView(_ feld: UITextView, context: Context) {
        let attribute = bild.attribute()
        feld.typingAttributes = attribute
        if feld.text != text {
            feld.attributedText = NSAttributedString(string: text, attributes: attribute)
        }
    }

    func makeCoordinator() -> Bote { Bote(text: $text, fertig: fertig) }

    final class Bote: NSObject, UITextViewDelegate {
        @Binding var text: String
        let fertig: () -> Void

        init(text: Binding<String>, fertig: @escaping () -> Void) {
            _text = text
            self.fertig = fertig
        }

        func textViewDidChange(_ feld: UITextView) {
            text = feld.text
        }

        func textViewDidEndEditing(_ feld: UITextView) {
            text = feld.text
            fertig()
        }
    }
}
