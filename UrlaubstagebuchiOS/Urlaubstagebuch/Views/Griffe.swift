import SwiftUI
import UIKit

// Der Raum, in dem auf dieser Seite GEMESSEN wird.
//
// Sein Ursprung ist die linke obere Ecke des Endformats — dieselbe Ecke,
// gegen die jede Blockkoordinate im Modell steht. Der Name liegt hier und
// nicht als Zeichenkette an drei Stellen: Ein Tippfehler darin ergäbe
// keinen Übersetzungsfehler, sondern stillschweigend falsche Zahlen.
//
// Warum es ihn überhaupt gibt: Eine Geste meldet ihren Punkt im Raum
// DERJENIGEN Ansicht, an der sie hängt. Die Ziehfläche des gewählten
// Blocks ist aber verschoben, um einen Saum vergrößert und ändert während
// des Ziehens ihre Größe — „lokal" heißt dort also etwas, das sich unter
// dem Finger bewegt, und ob der Ursprung vor oder hinter dem Versatz
// liegt, ist ohne Gerät nicht zu entscheiden. Mit einem benannten Raum
// stellt sich die Frage nicht mehr.
enum Seitenraum {
    static let name = "seite"
}

// Welcher Griff angefasst wurde — und damit, was eine Ziehbewegung bedeutet.
//
// Die Aufzählung liegt hier und nicht in der Ansicht, weil zwei Stellen sie
// brauchen: die ZEICHNUNG (wo sitzt welcher Griff) und die GESTE (welcher
// wurde getroffen). Zwei Fassungen davon liefen auseinander, und dann läge
// der sichtbare Griff woanders als der, den der Finger trifft — genau der
// Fehler, der hier zweimal gemeldet wurde.
enum Griffart: String, Equatable {
    case verschieben
    case obenLinks, obenRechts, untenLinks, untenRechts
    case links, rechts, oben, unten
    case drehen

    var name: String {
        switch self {
        case .verschieben: return "Fläche"
        case .obenLinks: return "Ecke oben links"
        case .obenRechts: return "Ecke oben rechts"
        case .untenLinks: return "Ecke unten links"
        case .untenRechts: return "Ecke unten rechts"
        case .links: return "Kante links"
        case .rechts: return "Kante rechts"
        case .oben: return "Kante oben"
        case .unten: return "Kante unten"
        case .drehen: return "Drehgriff"
        }
    }

    var zieht: (waagerecht: Double, senkrecht: Double) {
        switch self {
        case .obenLinks: return (-1, -1)
        case .obenRechts: return (1, -1)
        case .untenLinks: return (-1, 1)
        case .untenRechts: return (1, 1)
        case .links: return (-1, 0)
        case .rechts: return (1, 0)
        case .oben: return (0, -1)
        case .unten: return (0, 1)
        default: return (0, 0)
        }
    }
}

// Wo die Griffe eines Blocks liegen — in seinen EIGENEN Koordinaten, also
// mit (0,0) in seiner linken oberen Ecke.
//
// Das ist die eine Stelle, an der das steht. Gezeichnet wird danach, und
// getroffen wird danach; deshalb kann der sichtbare Griff nicht mehr
// woanders liegen als der wirksame.
struct Griffpunkt: Identifiable {
    let art: Griffart
    let stelle: CGPoint
    var id: String { art.rawValue }
}

enum Grifflage {
    static func punkte(breite: Double, hoehe: Double, abstand: Double) -> [Griffpunkt] {
        [
            Griffpunkt(art: .obenLinks, stelle: CGPoint(x: 0, y: 0)),
            Griffpunkt(art: .obenRechts, stelle: CGPoint(x: breite, y: 0)),
            Griffpunkt(art: .untenLinks, stelle: CGPoint(x: 0, y: hoehe)),
            Griffpunkt(art: .untenRechts, stelle: CGPoint(x: breite, y: hoehe)),
            Griffpunkt(art: .oben, stelle: CGPoint(x: breite / 2, y: 0)),
            Griffpunkt(art: .unten, stelle: CGPoint(x: breite / 2, y: hoehe)),
            Griffpunkt(art: .links, stelle: CGPoint(x: 0, y: hoehe / 2)),
            Griffpunkt(art: .rechts, stelle: CGPoint(x: breite, y: hoehe / 2)),
            Griffpunkt(art: .drehen, stelle: CGPoint(x: breite / 2, y: -abstand)),
        ]
    }

    // Was der Finger getroffen hat. Geprüft wird in der Reihenfolge, in der
    // die Griffe übereinanderliegen: erst der Dreher, dann die Ecken, dann
    // die Kanten — an einem kleinen Block überlappen sie einander, und dann
    // soll die Ecke gewinnen und nicht die Kante daneben.
    static func getroffen(_ punkt: CGPoint, breite: Double, hoehe: Double,
                          abstand: Double, greifweite: Double) -> Griffart?
    {
        let alle = punkte(breite: breite, hoehe: hoehe, abstand: abstand)
        for art in [Griffart.drehen, .obenLinks, .obenRechts, .untenLinks, .untenRechts,
                    .oben, .unten, .links, .rechts]
        {
            guard let stelle = alle.first(where: { $0.art == art })?.stelle else { continue }
            if hypot(punkt.x - stelle.x, punkt.y - stelle.y) <= greifweite { return art }
        }
        if punkt.x >= 0, punkt.y >= 0, punkt.x <= breite, punkt.y <= hoehe {
            return .verschieben
        }
        return nil
    }
}

// Die Anfasser am gewählten Block — eine ZEICHNUNG und sonst nichts.
//
// Bis 1.0.3 trug jeder Griff seine eigene Ziehgeste, und die Griffe lagen
// als eigene Ebene über der Seite. Beides ist ausgebaut. Gemeldet wurde
// zweimal, dass sich weder Bilder verschieben noch Rahmen ziehen lassen,
// während der Drehgriff ging — und der Unterschied zwischen beiden war
// genau, dass der Dreher als einziger NICHT über dem Block lag.
//
// Woran es lag, ließ sich hier nicht messen; es gab mehrere Verdächtige auf
// einmal (eine UIKit-Ansicht im Block, die Tipp-Gesten neben der Ziehgeste,
// Ebenen übereinander, die einander den Finger wegnehmen). Deshalb sind
// jetzt ALLE weg: Ein Block hat genau EINE Geste, und die entscheidet an
// der Stelle, an der der Finger aufsetzt, was gemeint war. Was auf dem
// Block liegt, ist ein Bild und nimmt keinen Finger an — dieselbe Lehre wie
// bei der Netzkarte der Abfahrtstafel („Eine Geste gehört der Karte").
struct Griffzeichnung: View {
    let block: Block
    let massstab: Double
    let abstand: Double

    private var groesse: Double { 15 / massstab }

    var body: some View {
        let rahmen = block.rahmen.rect
        ZStack(alignment: .topLeading) {
            Rectangle()
                .strokeBorder(Color.accentColor, lineWidth: 1.5 / massstab)
                .frame(width: rahmen.width, height: rahmen.height)

            ForEach(Grifflage.punkte(breite: rahmen.width, hoehe: rahmen.height,
                                     abstand: abstand)) { griff in
                marke(griff.art)
                    .position(x: griff.stelle.x, y: griff.stelle.y)
            }
        }
        .frame(width: rahmen.width, height: rahmen.height, alignment: .topLeading)
        .rotationEffect(.degrees(block.drehung))
        .offset(x: rahmen.minX, y: rahmen.minY)
        // Die Griffe sind gezeichnet und nicht angefasst: Der Finger geht an
        // den Block darunter, der als einziger eine Geste hat.
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func marke(_ art: Griffart) -> some View {
        if art == .drehen {
            Image(systemName: "arrow.trianglehead.clockwise")
                .font(.system(size: groesse * 0.62, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: groesse * 1.25, height: groesse * 1.25)
                .background(Circle().fill(Color.accentColor))
        } else {
            Circle()
                .fill(Color.white)
                .overlay(Circle().strokeBorder(Color.accentColor, lineWidth: 2 / massstab))
                .frame(width: groesse, height: groesse)
        }
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
        // Die BREITE ist fest, die HÖHE wächst mit dem Text — wie ein
        // Textfeld in Pages. Beides steht in zwei Lagen übereinander, und
        // das ist kein Umweg: `.frame(width:)` bietet dem Feld genau diese
        // Breite an, `.frame(minHeight:)` hält den Kasten auf der Höhe des
        // Blocks, solange der Text weniger braucht.
        //
        // **Ausgerichtet wird oben links.** Ein `.frame` beschneidet nicht:
        // Ist das Kind größer als der angebotene Platz, steht es MITTIG
        // über — genau das Bild aus der Meldung (09/2026: „Wieder wird beim
        // Doppeltipp der Text außerhalb des Rahmens dargestellt"). Mit
        // `topLeading` und der Maßangabe in `sizeThatFits` kann das nicht
        // mehr passieren.
        TextflaecheBruecke(text: $text, bild: bild,
                           rand: block.textrand(werk.reise.gestaltung)) {
            fertig()
        }
        .frame(width: rahmen.width, alignment: .topLeading)
        .frame(minHeight: max(rahmen.height, bild.zeilenhoehe * 1.6), alignment: .topLeading)
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
    // Derselbe Innenabstand, mit dem der Block gezeichnet wird. Ohne ihn
    // spränge der Text beim Doppeltipp an die Kante und beim Schließen
    // wieder zurück — dieselbe Art Unterschied wie zwischen zwei Setzern.
    var rand: Double = 0
    var fertig: () -> Void

    func makeUIView(context: Context) -> UITextView {
        let feld = UITextView()
        feld.delegate = context.coordinator
        feld.backgroundColor = .clear
        feld.textContainerInset = .zero
        feld.textContainer.lineFragmentPadding = 0
        feld.textContainerInset = UIEdgeInsets(top: rand, left: rand, bottom: rand, right: rand)
        feld.isScrollEnabled = false
        feld.autocorrectionType = .default
        feld.spellCheckingType = .default
        DispatchQueue.main.async { feld.becomeFirstResponder() }
        return feld
    }

    // OHNE diese Funktion nimmt SwiftUI die Größe, die sich die
    // UIKit-Ansicht selbst ausrechnet — und ein `UITextView` mit
    // abgeschaltetem Scrollen meldet die Größe, die sein Text BRAUCHT,
    // nicht die, die er bekommt. War sie breiter als der Block, lief der
    // Text über die halbe Seite: `.frame()` beschneidet nicht, es stellt
    // ein zu großes Kind mittig hin.
    //
    // Zurückgegeben wird deshalb die angebotene BREITE (nie mehr) und die
    // HÖHE, die der Text darin wirklich braucht — so wächst der Kasten
    // beim Tippen nach unten, statt Zeilen zu verschlucken. Gemessen wird
    // mit `sizeThatFits` des Feldes selbst, also mit demselben Umbruch, mit
    // dem es gleich zeichnet.
    //
    // **Merke: Ein `UIViewRepresentable` ohne `sizeThatFits` bestimmt seine
    // Größe selbst.**
    func sizeThatFits(_ vorschlag: ProposedViewSize, uiView feld: UITextView,
                      context: Context) -> CGSize?
    {
        guard let breite = vorschlag.width, breite > 1, breite < .infinity else {
            return nil
        }
        let gemessen = feld.sizeThatFits(
            CGSize(width: breite, height: .greatestFiniteMagnitude)
        )
        return CGSize(width: breite, height: max(gemessen.height, 1))
    }

    func updateUIView(_ feld: UITextView, context: Context) {
        feld.textContainerInset = UIEdgeInsets(top: rand, left: rand, bottom: rand, right: rand)
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

// MARK: - Die Fanglinie

// Woran der Block gerade einrastet — als Linie quer über den Bogen.
//
// Bis 1.0.10 rastete er stumm ein: Er sprang um zwei Punkte, und ob das der
// Satzspiegel war, die Schnittkante, das Foto darüber oder gar nichts, stand
// nirgends. Für den Menschen davor war das ein Zucken (Ansage des Nutzers,
// 09/2026: „Der Randindikator soll sich an den Rand und die Fotos
// orientieren"). Die Linie sagt es jetzt, und sie sagt auch, WELCHE Kante es
// ist — „Rand" und „Nachbar" sind zwei verschiedene Auskünfte.
//
// Alle Maße werden durch den Maßstab geteilt: Die Linie ist eine Hilfe für
// das Auge und keine Zeichnung auf dem Papier — sie soll auf einer klein
// gezoomten Seite genauso dünn sein wie auf einer großen. Sie wird nie
// gedruckt.
struct Fanglinie: View {
    let linie: Einrasten.Linie
    let senkrecht: Bool
    let laenge: Double
    let massstab: Double

    private var farbe: Color {
        switch linie.herkunft {
        case .satz: return .accentColor
        case .anschnitt: return .red
        case .nachbar: return .blue
        }
    }

    var body: some View {
        // Die Beschriftung hängt als ÜBERLAGERUNG an der Linie und liegt
        // nicht neben ihr in einem Stapel: Ein `ZStack` würde so breit wie
        // sein breitestes Kind, und das ist die Schrift — die Linie läge
        // dann nicht mehr auf der Kante, an der gefangen wurde.
        Rectangle()
            .fill(farbe.opacity(0.85))
            .frame(width: senkrecht ? 1 / massstab : laenge,
                   height: senkrecht ? laenge : 1 / massstab)
            .overlay(alignment: senkrecht ? .top : .leading) {
                Text(linie.herkunft.name)
                    .font(.system(size: 7 / massstab, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4 / massstab)
                    .padding(.vertical, 1.5 / massstab)
                    .background(farbe.opacity(0.9), in: Capsule())
                    .fixedSize()
                    .offset(x: senkrecht ? 0 : 8 / massstab,
                            y: senkrecht ? 8 / massstab : 0)
            }
            .allowsHitTesting(false)
    }
}
