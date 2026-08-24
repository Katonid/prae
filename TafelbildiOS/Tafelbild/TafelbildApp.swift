import SwiftUI
import CloudKit
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Stille CloudKit-Pushes (Änderungen anderer Geräte) abonnieren.
        application.registerForRemoteNotifications()
        // Eine Tafel steht oft eine ganze Stunde am Beamer: Der Bildschirm
        // darf sich dabei nicht abschalten.
        application.isIdleTimerDisabled = true
        return true
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        let isCloudKitNotification = CKNotification(fromRemoteNotificationDictionary: userInfo) != nil
        Task { @MainActor in
            BoardStore.shared.syncNow()
        }
        completionHandler(isCloudKitNotification ? .newData : .noData)
    }
}

@main
struct TafelbildApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var store = BoardStore.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(Theme.accent)
                .preferredColorScheme(.dark)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                UIApplication.shared.isIdleTimerDisabled = true
                store.appBecameActive()
            default:
                UIApplication.shared.isIdleTimerDisabled = false
                store.stopAutoRefresh()
                store.saveNow()
            }
        }
    }
}
