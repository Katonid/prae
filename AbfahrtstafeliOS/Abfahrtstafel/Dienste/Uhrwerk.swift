import Foundation
import SwiftUI

/// Der Takt, in dem die Minutenziffern weiterzählen.
///
/// **Warum das eine eigene Sache ist:** Jede Zeile der Tafel rechnet ihre
/// Minutenziffer aus einer Zeit aus. Holte sich jede Zeile dafür selbst
/// `Date()`, stünden zwei Abfahrten derselben Minute mit verschiedenen Ziffern
/// nebeneinander — und die Liste zählte nur dort weiter, wo SwiftUI zufällig
/// neu zeichnet. Es gibt deshalb GENAU EINE Uhr, sie tickt im Sekundentakt,
/// und alle Zeilen lesen dieselbe.
///
/// Eine Sekunde und nicht eine Minute: Der Wechsel von „2" auf „1" soll dann
/// kommen, wenn er ansteht, und nicht bis zu 59 Sekunden später.
@MainActor
final class Uhrwerk: ObservableObject {
    @Published private(set) var jetzt = Date()

    private var takt: Timer?

    func anfangen() {
        guard takt == nil else { return }
        jetzt = Date()
        let uhr = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.jetzt = Date() }
        }
        // `.common` und nicht die Vorgabe: In der Vorgabeschleife steht ein
        // Timer still, solange gescrollt wird. Die Tafel bliebe dann genau in
        // dem Augenblick stehen, in dem jemand sie durchsieht.
        RunLoop.main.add(uhr, forMode: .common)
        takt = uhr
    }

    func aufhoeren() {
        takt?.invalidate()
        takt = nil
    }
}
