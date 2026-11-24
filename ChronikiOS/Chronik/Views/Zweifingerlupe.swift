import SwiftUI
import UIKit

// DIE SEITENLUPE MIT DEM ZWEIFINGER-ERKENNER VON UIKIT (ab 1.0.52).
//
// Gemeldet 11/2026: „Auch das Zoomen der Seiten ist jedes Mal eine müßige
// Aufgabe, weil ich mehrfach anfassen muss, bevor etwas passiert." Bis
// 1.0.51 hing ein SwiftUI-`MagnifyGesture` als `simultaneousGesture` am
// Inhalt des `ScrollView` (seit dem Reisebuch 1.0.28). Ob er beginnt,
// entscheidet SwiftUI im Wettstreit mit dem Schiebeerkenner der Rollfläche,
// und den verliert er in den ersten Millisekunden immer wieder.
//
// Hier hängt ein `UIPinchGestureRecognizer` DIREKT an der `UIScrollView`,
// die SwiftUI unter dem `ScrollView` baut, mit der ausdrücklichen Erlaubnis,
// gleichzeitig mit ihren eigenen Erkennern zu laufen. Ein UIKit-Pinch
// beginnt, sobald zwei Finger liegen und sich der Abstand ändert — kein
// Wettstreit. Während er läuft, ruht das Schieben der Rollfläche, damit
// der Punkt unter den Fingern stehen bleibt (`Zoomanker`).
//
// Die Ansicht selbst ist unsichtbar und nimmt keinen Finger an. Sie sucht
// beim Einhängen ihre Rollfläche in der Kette der Oberansichten. Findet sie
// keine (ein künftiges iOS baut den `ScrollView` anders), meldet sie das
// über `angebracht(false)` — dann bleibt die SwiftUI-Geste die Lupe.
struct Zweifingerlupe: UIViewRepresentable {
    enum Phase { case beginnt, laeuft, endet }

    /// Ob gezoomt werden darf (über einem gewählten Foto gehören zwei Finger
    /// dem Bildausschnitt).
    var erlaubt: Bool
    /// Phase, Faktor seit dem Aufsetzen, Aufsetzpunkt in den Koordinaten
    /// DIESER Ansicht (= des Bühneninhalts, ungezoomt).
    var bewegung: (Phase, Double, CGPoint) -> Void
    var angebracht: (Bool) -> Void

    func makeCoordinator() -> Lenker { Lenker() }

    func makeUIView(context: Context) -> Traeger {
        let ansicht = Traeger()
        ansicht.isUserInteractionEnabled = false
        ansicht.backgroundColor = .clear
        ansicht.lenker = context.coordinator
        context.coordinator.traeger = ansicht
        return ansicht
    }

    func updateUIView(_ ansicht: Traeger, context: Context) {
        context.coordinator.erlaubt = erlaubt
        context.coordinator.bewegung = bewegung
        context.coordinator.angebracht = angebracht
    }

    static func dismantleUIView(_ ansicht: Traeger, coordinator: Lenker) {
        coordinator.abnehmen()
    }

    final class Traeger: UIView {
        weak var lenker: Lenker?
        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window != nil { lenker?.anbringen() } else { lenker?.abnehmen() }
        }
    }

    final class Lenker: NSObject, UIGestureRecognizerDelegate {
        weak var traeger: UIView?
        var erlaubt = true
        var bewegung: (Phase, Double, CGPoint) -> Void = { _, _, _ in }
        var angebracht: (Bool) -> Void = { _ in }
        private var erkenner: UIPinchGestureRecognizer?
        private weak var rolle: UIScrollView?
        private var start: CGPoint = .zero

        func anbringen() {
            guard erkenner == nil, let traeger else { return }
            var weiter = traeger.superview
            while let ansicht = weiter, !(ansicht is UIScrollView) { weiter = ansicht.superview }
            guard let gefunden = weiter as? UIScrollView else {
                DispatchQueue.main.async { self.angebracht(false) }
                return
            }
            let neu = UIPinchGestureRecognizer(target: self, action: #selector(gekniffen(_:)))
            neu.delegate = self
            neu.cancelsTouchesInView = false
            neu.delaysTouchesBegan = false
            gefunden.addGestureRecognizer(neu)
            erkenner = neu
            rolle = gefunden
            DispatchQueue.main.async { self.angebracht(true) }
        }

        func abnehmen() {
            if let erkenner { erkenner.view?.removeGestureRecognizer(erkenner) }
            erkenner = nil
            rolle?.panGestureRecognizer.isEnabled = true
            rolle = nil
        }

        @objc private func gekniffen(_ g: UIPinchGestureRecognizer) {
            guard let traeger else { return }
            switch g.state {
            case .began:
                start = g.location(in: traeger)
                // Das Schieben ruht, solange gezoomt wird: Sonst wanderte
                // der Inhalt unter den Fingern weg, und der Brennpunkt,
                // um den skaliert wird, stimmte nicht mehr.
                rolle?.panGestureRecognizer.isEnabled = false
                bewegung(.beginnt, Double(g.scale), start)
            case .changed:
                bewegung(.laeuft, Double(g.scale), start)
            case .ended, .cancelled, .failed:
                rolle?.panGestureRecognizer.isEnabled = true
                bewegung(.endet, Double(g.scale), start)
            default:
                break
            }
        }

        func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool { erlaubt }

        func gestureRecognizer(_ g: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith anderer: UIGestureRecognizer) -> Bool {
            true
        }
    }
}
