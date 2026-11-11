import SwiftUI

@main
struct ChronikApp: App {
    @StateObject private var bibliothek = Bibliothek()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            BuecherView()
                .environmentObject(bibliothek)
                .onChange(of: phase) { _, neu in
                    if neu != .active { bibliothek.sichernJetzt() }
                }
        }
    }
}
