import SwiftUI
import CloudKit
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Stille CloudKit-Pushes (Record-Änderungen) abonnieren.
        application.registerForRemoteNotifications()
        return true
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        let isCloudKitNotification = CKNotification(fromRemoteNotificationDictionary: userInfo) != nil
        Task { @MainActor in
            AppStore.shared.syncNow()
        }
        completionHandler(isCloudKitNotification ? .newData : .noData)
    }
}

@main
struct ReisekasseApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    // Singleton, damit auch der Kurzbefehl-Intent (Hintergrundstart ohne
    // gerenderte Szene) denselben Store verwendet.
    @ObservedObject private var store = AppStore.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(Theme.accent)
                .preferredColorScheme(.dark)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.syncNow()
            }
        }
    }
}
