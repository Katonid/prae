//  AlarmApp.swift
//  Entry point, app delegate, and the external display.

import BackgroundTasks
import SwiftUI
import UIKit

@main
struct AlarmApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(delegate.model)
                .environmentObject(delegate.model.notifications)
        }
    }
}

/// Why there is a delegate at all in a SwiftUI app: remote notifications.
///
/// Registering for them, receiving the silent ones, and handing the parsed
/// event to the model all happen through `UIApplicationDelegate`. SwiftUI has
/// no equivalent, and the alarm path is not the place to be clever.
final class AppDelegate: NSObject, UIApplicationDelegate {

    let model: AppModel = {
        // A build that cannot construct its backend has nothing to show, so
        // this failure is deliberately loud rather than a blank screen.
        let backend = try! BackendConfiguration.standard.makeBackend()
        return AppModel(backend: backend)
    }()

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions options:
                     [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Must happen before launch finishes; `BGTaskScheduler` traps on a
        // late registration.
        BackgroundRefresh.register { [model] in
            await model.reportDeviceStatus()
        }
        BackgroundRefresh.schedule()

        // Every launch, not only after the permission dialog: the device token
        // can change (restore from backup, iOS update), and a stale token is a
        // device that quietly stops receiving.
        application.registerForRemoteNotifications()
        return true
    }

    /// The silent ping, and any alarm push that arrives while the app runs.
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completion:
                     @escaping (UIBackgroundFetchResult) -> Void) {
        guard case .success(let event) = PushPayloadParser.event(from: userInfo) else {
            completion(.noData)
            return
        }
        Task { @MainActor in
            await model.handle(event: event)
            completion(.newData)
        }
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Task { @MainActor in
            // Worth saying out loud: without a registration nothing is
            // delivered, and the checklist would otherwise show all green.
            model.problem = "Dieses Gerät konnte sich nicht für Mitteilungen "
                + "anmelden: \(error.localizedDescription)"
        }
    }
}
