import SwiftUI

@main
struct SoundboardApp: App {
    @StateObject private var store: BoardStore
    @StateObject private var engine: AudioEngine

    init() {
        let store = BoardStore()
        let engine = AudioEngine()
        engine.store = store
        _store = StateObject(wrappedValue: store)
        _engine = StateObject(wrappedValue: engine)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(engine)
                .onAppear {
                    // Bildschirm während der Vorstellung wach halten.
                    UIApplication.shared.isIdleTimerDisabled = true
                }
        }
    }
}
