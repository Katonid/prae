import SwiftUI
import SwiftData
import CloudKit
import UIKit

@main
struct TagesspurApp: App {
    let container: ModelContainer
    @StateObject private var tracker: LocationTracker
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppearanceMode.appKey) private var appAppearance = AppearanceMode.system.rawValue
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        let syncedSchema = Schema([TrackDay.self, PlaceVisit.self, MediaTag.self])
        let familySchema = Schema([FamilyDay.self, FamilyVisit.self])
        let fullSchema = Schema([TrackDay.self, PlaceVisit.self, MediaTag.self, FamilyDay.self, FamilyVisit.self])
        // Vorgemerkter Sync-Neuaufbau (festgefahrenes CloudKit-Gedächtnis):
        // VOR dem Anlegen des Containers Daten sichern und die alte
        // Store-Datei entfernen — der frische Store synct von Null.
        let rebuildSnapshot = StoreRebuild.snapshotAndReset(syncedSchema: syncedSchema)
        let resolved: ModelContainer
        do {
            // Eigene Daten: privater CloudKit-Container (Sync der eigenen
            // Geräte) — Konfiguration bleibt unbenannt, damit der bisherige
            // Store weiterverwendet wird. Familien-Spiegel: bewusst
            // lokal-only — Quelle ist die geteilte CloudKit-Zone,
            // keine Kopier-Schleifen.
            let synced = ModelConfiguration(schema: syncedSchema, cloudKitDatabase: .automatic)
            let family = ModelConfiguration("familie", schema: familySchema, cloudKitDatabase: .none)
            resolved = try ModelContainer(for: fullSchema, configurations: [synced, family])
            SyncDiagnose.cloudKitAktiv = true
        } catch {
            // Ohne iCloud (z. B. nicht angemeldet) lokal weiterarbeiten.
            let local = ModelConfiguration(schema: fullSchema, cloudKitDatabase: .none)
            if let localContainer = try? ModelContainer(for: fullSchema, configurations: [local]) {
                resolved = localContainer
            } else {
                // Absolute Auffangebene (z. B. Migrationsfehler): Der
                // 1.4.17-Absturz entstand, weil dieser Pfad mit try!
                // erzwungen wurde — scheitert auch die lokale Variante,
                // startet die App jetzt mit flüchtigem Speicher statt
                // in einer Absturzschleife. Die Daten auf der Platte
                // bleiben unangetastet für den nächsten Start.
                LocationTracker.logEvent("NOTSTART: Datenbank nicht ladbar — flüchtiger Speicher aktiv, Daten bleiben auf der Platte")
                let memory = ModelConfiguration(schema: fullSchema, isStoredInMemoryOnly: true)
                resolved = try! ModelContainer(for: fullSchema, configurations: [memory])
            }
            SyncDiagnose.cloudKitAktiv = false
        }
        container = resolved
        if let rebuildSnapshot {
            StoreRebuild.reinsert(rebuildSnapshot, into: resolved)
        }
        let trackerInstance = LocationTracker(container: resolved)
        _tracker = StateObject(wrappedValue: trackerInstance)
        FamilySync.shared.modelContainer = resolved
        SyncMonitor.start()
        WatchLink.shared.tracker = trackerInstance
        WatchLink.shared.activate()
        // Umbenanntes Gerät: Bestandsdaten auf den aktuellen Namen ziehen.
        Task { @MainActor in
            DeviceInfo.normalizeStoredNames(container: resolved)
            DataMaintenance.recompressPoints(container: resolved)
            DataMaintenance.dedupe(container: resolved)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(tracker)
                .preferredColorScheme(AppearanceMode.mode(for: appAppearance).colorScheme)
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background, .inactive:
                tracker.flush()
                WidgetBridge.update(
                    container: container,
                    trackingEnabled: tracker.trackingEnabled,
                    highAccuracy: tracker.highAccuracy,
                    isResting: tracker.isResting,
                    force: true
                )
            case .active:
                Task { @MainActor in
                    await FamilySync.shared.autoSync()
                    DataMaintenance.dedupe(container: container)
                }
            @unknown default:
                break
            }
        }
    }
}

/// App-/Scene-Delegate für die Annahme von CloudKit-Einladungen und
/// stille CloudKit-Pushes (Familienfreigabe) — die UI bleibt SwiftUI.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Für stille CloudKit-Pushes (neue Familien-Daten) nötig; zeigt
        // keine Mitteilungen an und fragt nicht um Erlaubnis.
        application.registerForRemoteNotifications()
        return true
    }

    /// Stiller CloudKit-Push: Ein Familienmitglied hat neue Daten in
    /// seine geteilte Zone gespiegelt — sofort laden statt auf das
    /// nächste App-Öffnen zu warten.
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        let note = CKNotification(fromRemoteNotificationDictionary: userInfo)
        guard let databaseNote = note as? CKDatabaseNotification,
              databaseNote.databaseScope == .shared else {
            // Pushes des eigenen SwiftData-Syncs verarbeitet das Framework selbst.
            completionHandler(.noData)
            return
        }
        Task { @MainActor in
            await FamilySync.shared.fetchFamilyData()
            completionHandler(.newData)
        }
    }

    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}

final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        if let metadata = connectionOptions.cloudKitShareMetadata {
            FamilySync.shared.acceptShare(metadata: metadata)
        }
    }

    func windowScene(_ windowScene: UIWindowScene,
                     userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        FamilySync.shared.acceptShare(metadata: cloudKitShareMetadata)
    }
}
