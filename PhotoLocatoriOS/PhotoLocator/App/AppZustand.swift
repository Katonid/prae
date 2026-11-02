import Observation
import SwiftUI

/// Navigationsziele.
enum Ziel: Hashable {
    case ergaenzen
    case bearbeiten
    case editor(Arbeitsliste.Art, Int)
}

/// Hält alles, was über einzelne Bildschirme hinaus lebt.
@MainActor
@Observable
final class AppZustand {
    let zugriff = MediathekZugriff()
    let sitzung = Sitzungsspeicher()
    let karte = KartenGedaechtnis()
    let ergaenzen = ErgaenzenModell()
    let bearbeiten = BearbeitenModell()
    var pfad: [Ziel] = []

    func liste(fuer art: Arbeitsliste.Art) -> Arbeitsliste? {
        switch art {
        case .ergaenzen: return ergaenzen.liste
        case .bearbeiten: return bearbeiten.liste
        }
    }
}

@main
struct PhotoLocatorApp: App {
    @State private var app = AppZustand()

    var body: some Scene {
        WindowGroup {
            WurzelAnsicht()
                .environment(app)
        }
    }
}
