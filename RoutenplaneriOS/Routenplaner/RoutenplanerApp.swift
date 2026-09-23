import SwiftUI

@main
struct RoutenplanerApp: App {
    @StateObject private var planer = Planer()
    @StateObject private var standort = Standort()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            PlanerView()
                .environmentObject(planer)
                .environmentObject(standort)
                .onAppear {
                    standort.anfragen()
                    wachHalten(phase == .active)
                }
                .onChange(of: phase) { _, neu in wachHalten(neu == .active) }
        }
    }

    /// Solange die App vorn ist, sperrt sich der Bildschirm nicht — wer im
    /// Auto oder am Lenker auf die Karte schaut, soll nicht erst entsperren
    /// müssen. Sobald sie in den Hintergrund geht, gilt wieder die
    /// Einstellung des Geräts; ein vergessenes Telefon in der Tasche soll
    /// nicht bis zum leeren Akku leuchten.
    private func wachHalten(_ an: Bool) {
        UIApplication.shared.isIdleTimerDisabled = an
    }
}
