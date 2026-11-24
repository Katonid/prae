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

    // WIRD GERADE GEZOOMT? (ab 1.0.53) Seit zwei Finger immer die Seite
    // zoomen, kann der erste Finger zugleich auf einem gewählten Block
    // liegen und ihn ziehen. `SeitenflaecheView.ziehen` fragt diese Zahl:
    // Hat seit dem Aufsetzen ein Zoom begonnen, wird die Ziehbewegung
    // verworfen statt geschrieben.
    static var zoomzaehler = 0
    static var zoomLaeuft = false

    /// Ob gezoomt werden darf (über einem gewählten Foto gehören zwei Finger
    /// dem Bildausschnitt).
    var erlaubt: Bool
    /// Phase, Faktor seit dem Aufsetzen, Aufsetzpunkt in den Koordinaten
    /// DIESER Ansicht (= des Bühneninhalts, ungezoomt).
    var bewegung: (Phase, Double, CGPoint) -> Void
    var angebracht: (Bool) -> Void
    /// Über diesen Griff rollt `ReiseView` nach dem Zoomen DIREKT
    /// (ab 1.0.53) — siehe `Lupengriff`.
    var griff: Lupengriff

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
        griff.lenker = context.coordinator
    }

    static func dismantleUIView(_ ansicht: Traeger, coordinator: Lenker) {
        coordinator.abnehmen()
    }

    final class Traeger: UIView {
        weak var lenker: Lenker?
        // Hier und nicht später: `layoutSubviews` läuft im SELBEN
        // Durchgang, in dem SwiftUI den Inhalt auf den neuen Maßstab
        // bringt, also bevor das Bild auf den Schirm kommt. Wird die
        // Rollfläche erst danach gestellt, steht für einen Augenblick die
        // falsche Seite da.
        override func layoutSubviews() {
            super.layoutSubviews()
            lenker?.ausstehendAnwenden(nurBeiNeuerGroesse: true)
        }
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
        // Wohin nach dem Zoom gerollt werden soll: der Ursprung des Inhalts
        // im Sichtfeld (`Zoomanker.sollversatz`). Gilt eine kurze Weile,
        // weil der `LazyVStack` seine Höhe nach dem ersten Durchgang noch
        // einmal nachrechnen kann.
        private var ausstehend: CGPoint?
        private var groesseBeimWunsch: CGSize = .zero
        private var wunschnummer = 0

        func rollen(soll: CGPoint) {
            guard rolle != nil, let traeger else { return }
            wunschnummer += 1
            let nummer = wunschnummer
            ausstehend = soll
            groesseBeimWunsch = traeger.bounds.size
            for verzug in [0.0, 0.05, 0.15, 0.3] {
                DispatchQueue.main.asyncAfter(deadline: .now() + verzug) { [weak self] in
                    guard let self, self.wunschnummer == nummer else { return }
                    self.ausstehendAnwenden(nurBeiNeuerGroesse: false)
                    if verzug >= 0.3 { self.ausstehend = nil }
                }
            }
        }

        func ausstehendAnwenden(nurBeiNeuerGroesse: Bool) {
            guard let soll = ausstehend, let rolle, let traeger else { return }
            if nurBeiNeuerGroesse, traeger.bounds.size == groesseBeimWunsch { return }
            // Wer inzwischen selbst schiebt, hat das letzte Wort.
            if rolle.isDragging || rolle.isDecelerating { ausstehend = nil; return }
            let lage = traeger.convert(CGPoint.zero, to: rolle)
            let rand = rolle.adjustedContentInset
            let breite = max(rolle.contentSize.width, lage.x + traeger.bounds.width)
            let hoehe = max(rolle.contentSize.height, lage.y + traeger.bounds.height)
            let maxX = max(-rand.left, breite - rolle.bounds.width + rand.right)
            let maxY = max(-rand.top, hoehe - rolle.bounds.height + rand.bottom)
            let ziel = CGPoint(x: min(max(lage.x - soll.x, -rand.left), maxX),
                               y: min(max(lage.y - soll.y, -rand.top), maxY))
            if abs(rolle.contentOffset.x - ziel.x) > 0.5 || abs(rolle.contentOffset.y - ziel.y) > 0.5 {
                rolle.setContentOffset(ziel, animated: false)
            }
        }

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
                Zweifingerlupe.zoomzaehler += 1
                Zweifingerlupe.zoomLaeuft = true
                start = g.location(in: traeger)
                // Das Schieben ruht, solange gezoomt wird: Sonst wanderte
                // der Inhalt unter den Fingern weg, und der Brennpunkt,
                // um den skaliert wird, stimmte nicht mehr.
                rolle?.panGestureRecognizer.isEnabled = false
                bewegung(.beginnt, Double(g.scale), start)
            case .changed:
                bewegung(.laeuft, Double(g.scale), start)
            case .ended, .cancelled, .failed:
                Zweifingerlupe.zoomLaeuft = false
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

/// Ein Griff, über den `ReiseView` die Rollfläche stellen kann (ab 1.0.53).
///
/// Bis 1.0.52 rollte die Bühne nach dem Zoomen über `scrollTo` auf eine
/// SEITE mit Anker. Ein `LazyVStack` kennt die Lage einer Seite, die er noch
/// nicht gebaut hat, aber nur geschätzt — gemeldet 11/2026: „beim Zoomen
/// [verspringt] die Seite und zunächst [wird] eine andere angezeigt".
/// Jetzt wird der Versatz der Rollfläche direkt gesetzt, aus derselben
/// Rechnung (`Zoomanker.sollversatz`); `scrollTo` bleibt nur als Rückfall.
final class Lupengriff {
    weak var lenker: Zweifingerlupe.Lenker?

    /// `false`, wenn keine Rollfläche greifbar ist — dann rollt der Aufrufer
    /// selbst.
    func rollen(soll: CGPoint) -> Bool {
        guard let lenker else { return false }
        lenker.rollen(soll: soll)
        return true
    }
}
