import SwiftUI
import UIKit

// Die Wettertabelle auf der Seite (ab 1.0.116) — gezeichnet von demselben
// Setzer, der sie ins PDF schreibt (`Seitensatz.zeichneWettertabelle`).
// Dieselbe Bauweise wie `Textkasten`, samt den beiden Lehren von dort:
// `contentMode = .redraw` (sonst wird das Bild beim Größenändern gedehnt
// statt neu gezeichnet) und `contentsScale` nach dem Maßstab der Bühne
// (sonst bleibt die Tabelle beim Hineinzoomen unscharf).
struct Wetterkasten: UIViewRepresentable {
    var tabelle: Wettertabelle
    var bild: Schriftbild
    var rand: Double = 0
    var massstab: Double = 1

    func makeUIView(context: Context) -> WetterkastenView {
        let ansicht = WetterkastenView()
        ansicht.backgroundColor = .clear
        ansicht.isOpaque = false
        // Eine Zeichnung und kein Bedienelement — den Finger nimmt die
        // Seite entgegen (die Regel seit 1.0.5).
        ansicht.isUserInteractionEnabled = false
        ansicht.contentMode = .redraw
        return ansicht
    }

    // Neu gezeichnet wird nur bei echter Änderung — `updateUIView` läuft
    // bei jedem Durchgang (die Lehre aus 1.0.16).
    func updateUIView(_ ansicht: WetterkastenView, context: Context) {
        if ansicht.tabelle != tabelle { ansicht.tabelle = tabelle }
        if ansicht.bild != bild { ansicht.bild = bild }
        if ansicht.rand != rand { ansicht.rand = rand }
        if ansicht.massstab != massstab { ansicht.massstab = massstab }
    }
}

final class WetterkastenView: UIView {
    var tabelle = Wettertabelle(ort: "", vorhersage: false, spalten: []) { didSet { setNeedsDisplay() } }
    var bild = Schriftbild() { didSet { setNeedsDisplay() } }
    var rand: Double = 0 { didSet { setNeedsDisplay() } }
    var massstab: Double = 1 { didSet { schaerfeSetzen() } }

    private func schaerfeSetzen() {
        let gemeldet = Double(traitCollection.displayScale)
        let geraet = gemeldet > 0.5 ? gemeldet : 2
        let fein = Bildschaerfe.punkteJeSeitenpunkt(geraet: geraet, massstab: massstab,
                                                    flaeche: bounds.size)
        guard abs(Double(layer.contentsScale) - fein) > 0.01 else { return }
        layer.contentsScale = CGFloat(fein)
        setNeedsDisplay()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        schaerfeSetzen()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        schaerfeSetzen()
    }

    override func draw(_ rect: CGRect) {
        guard let zusammenhang = UIGraphicsGetCurrentContext(), !tabelle.leer else { return }
        let ganz = CGRect(origin: .zero, size: bounds.size)
        let luft = CGFloat(min(max(rand, 0), Double(min(ganz.width, ganz.height)) / 2 - 2))
        Seitensatz.zeichneWettertabelle(
            tabelle, bild: bild,
            rechteck: luft > 0 ? ganz.insetBy(dx: luft, dy: luft) : ganz,
            in: zusammenhang, seitenhoehe: bounds.height)
    }
}
