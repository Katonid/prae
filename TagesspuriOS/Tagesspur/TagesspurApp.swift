import SwiftUI
import SwiftData

@main
struct TagesspurApp: App {
    let container: ModelContainer
    @StateObject private var tracker: LocationTracker
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let schema = Schema([TrackDay.self, PlaceVisit.self, MediaTag.self])
        let resolved: ModelContainer
        do {
            // Privater CloudKit-Container: jedes Gerät schreibt nur eigene
            // Datensätze, alle Geräte sehen den gemeinsamen Bestand.
            let config = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
            resolved = try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Ohne iCloud (z. B. nicht angemeldet) lokal weiterarbeiten.
            let local = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            resolved = try! ModelContainer(for: schema, configurations: [local])
        }
        container = resolved
        _tracker = StateObject(wrappedValue: LocationTracker(container: resolved))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(tracker)
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, phase in
            if phase == .background || phase == .inactive {
                tracker.flush()
            }
        }
    }
}
