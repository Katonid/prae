import SwiftUI
import SwiftData

@main
struct TagesspurWatchApp: App {
    let container: ModelContainer
    @StateObject private var recorder: WatchRecorder
    @StateObject private var phone = PhoneLink.shared

    init() {
        // Gleicher CloudKit-Container wie iPhone/iPad — die Watch ist
        // ein weiteres Gerät im selben Datenbestand. Ohne iCloud lokal
        // weiterarbeiten (Punkte syncen dann später nicht).
        let schema = Schema([TrackDay.self])
        let resolved: ModelContainer
        do {
            let synced = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
            resolved = try ModelContainer(for: schema, configurations: [synced])
        } catch {
            let local = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            resolved = try! ModelContainer(for: schema, configurations: [local])
        }
        container = resolved
        _recorder = StateObject(wrappedValue: WatchRecorder(container: resolved))
        PhoneLink.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            WatchHomeView()
                .environmentObject(recorder)
                .environmentObject(phone)
        }
        .modelContainer(container)
    }
}
