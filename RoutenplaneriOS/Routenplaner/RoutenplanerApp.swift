import SwiftUI

@main
struct RoutenplanerApp: App {
    @StateObject private var planer = Planer()
    @StateObject private var standort = Standort()

    var body: some Scene {
        WindowGroup {
            PlanerView()
                .environmentObject(planer)
                .environmentObject(standort)
                .onAppear { standort.anfragen() }
        }
    }
}
