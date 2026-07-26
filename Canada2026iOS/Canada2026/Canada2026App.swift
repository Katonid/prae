import SwiftUI
import CloudKit
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    static weak var store: AppStore?

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
            AppDelegate.store?.syncNow()
        }
        completionHandler(isCloudKitNotification ? .newData : .noData)
    }
}

@main
struct Canada2026App: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(Theme.canadaRed)
                .onAppear {
                    AppDelegate.store = store
                    store.ensureDefaultBucketList()
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.syncNow()
            }
        }
    }
}
