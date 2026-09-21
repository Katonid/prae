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

    func makeUIView(context: Context) -> TextkastenView {
        let ansicht = TextkastenView()
        ansicht.backgroundColor = .clear
        ansicht.isOpaque = false
        // Eine UIKit-Ansicht nimmt sich den Finger und gibt ihn nicht
        // weiter — auch eine, die nichts tut als zeichnen. Damit wäre jeder
        // Textblock auf der Seite unverschiebbar, und zwar nur der Text;
        // ein Fehler, den man am Quelltext der Seite nicht sieht.
        ansicht.isUserInteractionEnabled = false
        return ansicht
    }

    func updateUIView(_ ansicht: TextkastenView, context: Context) {
        ansicht.text = text
        ansicht.bild = bild
        ansicht.setNeedsDisplay()
    }
}

final class TextkastenView: UIView {
    var text: String = "" { didSet { setNeedsDisplay() } }
    var bild = Schriftbild() { didSet { setNeedsDisplay() } }

    override func draw(_ rect: CGRect) {
        guard let zusammenhang = UIGraphicsGetCurrentContext(), !text.isEmpty else { return }
        Seitensatz.zeichneText(
            text,
            bild: bild,
            rechteck: CGRect(origin: .zero, size: bounds.size),
            in: zusammenhang,
            seitenhoehe: bounds.height
        )
    }
}
