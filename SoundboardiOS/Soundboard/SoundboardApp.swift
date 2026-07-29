import SwiftUI

@main
struct SoundboardApp: App {
    @StateObject private var store: BoardStore
    @StateObject private var engine: AudioEngine
    @StateObject private var cloud: CloudSync
    @StateObject private var watchLink: WatchLink
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let store = BoardStore()
        let engine = AudioEngine()
        let cloud = CloudSync()
        let watchLink = WatchLink()
        engine.store = store
        cloud.store = store
        cloud.engine = engine
        watchLink.store = store
        watchLink.engine = engine
        store.onUserSave = { [weak cloud, weak watchLink] in
            cloud?.pushSoon()
            watchLink?.pushStateSoon()
        }
        _store = StateObject(wrappedValue: store)
        _engine = StateObject(wrappedValue: engine)
        _cloud = StateObject(wrappedValue: cloud)
        _watchLink = StateObject(wrappedValue: watchLink)
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
                    watchLink.start()
                }
                .onChange(of: scenePhase) {
                    if scenePhase == .active { cloud.appBecameActive() }
                }
        }
    }
}
