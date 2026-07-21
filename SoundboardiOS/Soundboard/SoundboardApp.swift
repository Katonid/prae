import SwiftUI

@main
struct SoundboardApp: App {
    @StateObject private var store: BoardStore
    @StateObject private var engine: AudioEngine
    @StateObject private var cloud: CloudSync
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let store = BoardStore()
        let engine = AudioEngine()
        let cloud = CloudSync()
        engine.store = store
        cloud.store = store
        cloud.engine = engine
        store.onUserSave = { [weak cloud] in cloud?.pushSoon() }
        _store = StateObject(wrappedValue: store)
        _engine = StateObject(wrappedValue: engine)
        _cloud = StateObject(wrappedValue: cloud)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(engine)
                .environmentObject(cloud)
                .onAppear {
                    // Bildschirm während der Vorstellung wach halten.
                    UIApplication.shared.isIdleTimerDisabled = true
                    cloud.start()
                }
                .onChange(of: scenePhase) {
                    if scenePhase == .active { cloud.appBecameActive() }
                }
        }
    }
}
