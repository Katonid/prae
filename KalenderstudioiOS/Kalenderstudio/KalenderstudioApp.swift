import SwiftUI

@main
struct KalenderstudioApp: App {
    @StateObject private var store = ProjectStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(store)
                .onAppear {
                    PhotoInfo.register(store.projects.flatMap(\.photos))
                    FontStore.shared.activate()
                }
                .task { store.startCloud() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { store.saveNow() }
        }
    }
}
