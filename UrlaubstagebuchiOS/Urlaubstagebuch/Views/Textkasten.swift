import SwiftUI
import UIKit

// Der Text auf der Seite — gezeichnet von demselben Setzer, der ihn
// hinterher ins PDF schreibt.
//
// Ein `Text` aus SwiftUI wäre naheliegend und falsch: Er kann keinen
// Blocksatz, keine feste Zeilenhöhe und keine Silbentrennung, und er
// umbricht nach eigenen Regeln. Die Seite auf dem Bildschirm sähe dann
// anders aus als die gedruckte — und zwar unauffällig anders, ein paar
// Zeilen hier, ein Umbruch dort, bis unten etwas fehlt.
struct Textkasten: UIViewRepresentable {
    var text: String
    var bild: Schriftbild
    // Der Abstand vom Rand des Kastens bis zum Text — gebraucht, sobald
    // ein farbiger Grund darunterliegt. Er kommt vom Block und wird hier
    // nur durchgereicht; gerechnet wird er an EINER Stelle
    // (`Block.textrechteck`), die auch das PDF fragt.
    var rand: Double = 0
    // DER MASSSTAB DER BÜHNE, und er gehört hier herein.
    //
    // Die Seite wird in Seitenpunkten gesetzt und mit `scaleEffect`
    // vergrößert; das ist eine Abbildung und keine neue Zeichnung. Wie
    // fein diese Ansicht rastert, muss sie deshalb selbst wissen —
    // `Bildschaerfe` rechnet die Zahl, `schaerfeSetzen` setzt sie.
    var massstab: Double = 1

    func makeUIView(context: Context) -> TextkastenView {
        let ansicht = TextkastenView()
        ansicht.backgroundColor = .clear
        ansicht.isOpaque = false
        // Eine UIKit-Ansicht nimmt sich den Finger und gibt ihn nicht
        // weiter — auch eine, die nichts tut als zeichnen. Damit wäre jeder
        // Textblock auf der Seite unverschiebbar, und zwar nur der Text;
        // ein Fehler, den man am Quelltext der Seite nicht sieht.
        ansicht.isUserInteractionEnabled = false
        // ENTSCHEIDEND, und der Grund für den verzerrten Text nach jeder
        // Größenänderung: Eine `UIView` steht von Haus aus auf
        // `.scaleToFill`. Ändert sich ihr Rahmen, zeichnet UIKit nicht neu,
        // sondern ZIEHT das zuletzt gezeichnete Bild auf die neue Größe —
        // aus dem gesetzten Text wird eine gestauchte oder gestreckte
        // Grafik. Erst irgendein späteres `draw(_:)` rückte das gerade,
        // und genau das ist der Seitenwechsel, der es bisher brauchte.
        // Mit `.redraw` fordert UIKit bei jeder Rahmenänderung eine neue
        // Zeichnung an. **Merke: Wer in einer UIView selbst zeichnet,
        // setzt `contentMode = .redraw` — sonst wird das Bild skaliert
        // statt neu gesetzt.**
        ansicht.contentMode = .redraw
        return ansicht
    }

    // Neu gezeichnet wird nur, wenn sich WIRKLICH etwas geändert hat.
    //
    // Bis 1.0.15 stand hier ein `setNeedsDisplay()` ohne Bedingung, und
    // die drei Zuweisungen darüber lösten je eines aus. Diese Methode läuft
    // aber bei JEDEM Durchgang des SwiftUI-Körpers — beim Schieben also
    // sechzigmal in der Sekunde —, und dahinter steckt ein voller
    // CoreText-Satz je Textkasten. Ein Buch hat drei bis fünf davon auf
    // einer Seite. Die `didSet`-Beobachter melden die Änderung ohnehin;
    // gebraucht wird hier nur der Vergleich, und `Schriftbild` ist
    // `Hashable`.
    func updateUIView(_ ansicht: TextkastenView, context: Context) {
        if ansicht.text != text { ansicht.text = text }
        if ansicht.bild != bild { ansicht.bild = bild }
        if ansicht.rand != rand { ansicht.rand = rand }
        if ansicht.massstab != massstab { ansicht.massstab = massstab }
    }
}

final class TextkastenView: UIView {
    var text: String = "" { didSet { setNeedsDisplay() } }
    var bild = Schriftbild() { didSet { setNeedsDisplay() } }
    var rand: Double = 0 { didSet { setNeedsDisplay() } }
    var massstab: Double = 1 { didSet { schaerfeSetzen() } }

    // WARUM DER TEXT BEIM HINEINZOOMEN UNSCHARF WURDE (behoben in 1.0.53).
    //
    // Core Animation rastert eine Ebene EINMAL, mit `layer.contentsScale`
    // Bildpunkten je Punkt, und der Vorgabewert ist der Maßstab des
    // Bildschirms. Der `scaleEffect` über dieser Ansicht zieht dieses
    // fertige Bild danach auf — bei 400 % also auf das Vierfache. Gesetzt
    // wurde der Text damit weiterhin mit zwei Bildpunkten je Seitenpunkt,
    // gezeigt aber auf acht: ein halber gerasterter Punkt je
    // Bildschirmpunkt. Nichts daran war falsch gezeichnet, es war zu grob
    // gezeichnet. **Merke: Wer in einer UIView selbst zeichnet und sie
    // vergrößern lässt, setzt `contentsScale` — sonst wird das Bild
    // gedehnt statt neu gesetzt.** Dieselbe Wurzel wie `contentMode`
    // darüber, eine Ebene tiefer.
    //
    // Der Gerätemaßstab kommt aus der eigenen `traitCollection` und nie
    // aus `UIScreen.main`: Hängt ein zweiter Bildschirm am iPad, wäre das
    // die falsche Auskunft.
    private func schaerfeSetzen() {
        let gemeldet = Double(traitCollection.displayScale)
        let geraet = gemeldet > 0.5 ? gemeldet : 2
        let fein = Bildschaerfe.punkteJeSeitenpunkt(geraet: geraet, massstab: massstab,
                                                    flaeche: bounds.size)
        Schaerfeprobe.shared.melde(fein: fein, flaeche: bounds.size,
                                   geraet: geraet, massstab: massstab)
        guard abs(Double(layer.contentsScale) - fein) > 0.01 else { return }
        layer.contentsScale = CGFloat(fein)
        setNeedsDisplay()
    }

    // Die Fläche geht in das Budget ein, also wird die Schärfe bei jeder
    // Größenänderung nachgeführt. `contentMode = .redraw` fordert die
    // Zeichnung ohnehin an; hier kommt nur die Auflösung dazu.
    override func layoutSubviews() {
        super.layoutSubviews()
        schaerfeSetzen()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        schaerfeSetzen()
    }

    override func draw(_ rect: CGRect) {
        guard let zusammenhang = UIGraphicsGetCurrentContext(), !text.isEmpty else { return }
        let ganz = CGRect(origin: .zero, size: bounds.size)
        let luft = min(max(rand, 0), min(ganz.width, ganz.height) / 2 - 2)
        Seitensatz.zeichneText(
            text,
            bild: bild,
            rechteck: luft > 0 ? ganz.insetBy(dx: luft, dy: luft) : ganz,
            in: zusammenhang,
            seitenhoehe: bounds.height
        )
    }
}
