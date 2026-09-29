import SwiftUI
import UIKit

/// Nimmt Finger und Apple Pencil entgegen.
///
/// UIKit statt `DragGesture`, weil nur hier drei Dinge gehen, auf die es
/// beim Schreiben ankommt:
/// * **Zusammengefasste Berührungen** (`coalescedTouches`): Der Stift
///   meldet bis zu 240 Punkte je Sekunde, der Bildschirm zeichnet 60 oder
///   120 — ohne sie gingen Zwischenpunkte verloren.
/// * **Nur die erste Berührung zählt.** Legt das Kind den Handballen ab,
///   während es schreibt, wird der zweite Kontakt übergangen statt den
///   Strich abzubrechen.
/// * **Nur Stift**, auf Wunsch: Finger werden dann ganz ignoriert.
struct SpurEingabe: UIViewRepresentable {
    var nurStift: Bool
    var beginn: (CGPoint) -> Void
    var bewegung: ([CGPoint]) -> Void
    var ende: (CGPoint) -> Void
    var abbruch: () -> Void

    func makeUIView(context: Context) -> EingabeFlaeche {
        let flaeche = EingabeFlaeche()
        flaeche.backgroundColor = .clear
        flaeche.isMultipleTouchEnabled = true
        return flaeche
    }

    func updateUIView(_ flaeche: EingabeFlaeche, context: Context) {
        flaeche.nurStift = nurStift
        flaeche.beginn = beginn
        flaeche.bewegung = bewegung
        flaeche.ende = ende
        flaeche.abbruch = abbruch
    }
}

final class EingabeFlaeche: UIView {
    var nurStift = false
    var beginn: (CGPoint) -> Void = { _ in }
    var bewegung: ([CGPoint]) -> Void = { _ in }
    var ende: (CGPoint) -> Void = { _ in }
    var abbruch: () -> Void = {}

    private var aktiv: UITouch?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard aktiv == nil,
              let beruehrung = touches.first(where: { !nurStift || $0.type == .pencil })
        else { return }
        aktiv = beruehrung
        beginn(beruehrung.location(in: self))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let aktiv, touches.contains(aktiv) else { return }
        let alle = event?.coalescedTouches(for: aktiv) ?? [aktiv]
        bewegung(alle.map { $0.location(in: self) })
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let aktiv, touches.contains(aktiv) else { return }
        self.aktiv = nil
        ende(aktiv.location(in: self))
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let aktiv, touches.contains(aktiv) else { return }
        self.aktiv = nil
        abbruch()
    }
}
