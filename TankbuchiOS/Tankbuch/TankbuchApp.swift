import SwiftUI
import SwiftData

@main
struct TankbuchApp: App {
    let container: ModelContainer
    @StateObject private var appModel = AppModel()

    init() {
        let schema = Schema([Vehicle.self, FuelEntry.self, SyncPing.self])
        do {
            // Mit iCloud-Capability synchronisiert SwiftData automatisch über
            // CloudKit; ohne Capability läuft die App rein lokal weiter.
            let config = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            do {
                let localConfig = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
                container = try ModelContainer(for: schema, configurations: [localConfig])
            } catch {
                let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                container = try! ModelContainer(for: schema, configurations: [memoryConfig])
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appModel)
        }
        .modelContainer(container)
    }
}
