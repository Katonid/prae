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

    /// Hängt an die gewöhnliche App-Szene einen eigenen Delegaten.
    ///
    /// Nur dafür: `windowScene(_:userDidAcceptCloudKitShareWith:)` gibt es
    /// ausschließlich am Szenen-Delegaten. Ohne ihn öffnete ein Freigabe-Link
    /// zwar die App, käme aber nirgends an. Das Fenster richtet weiterhin
    /// SwiftUI ein — der Delegat unten fasst es bewusst nicht an.
    func application(
        _ application: UIApplication,
        configurationForConnecting verbindung: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        guard verbindung.role == .windowApplication else {
            // Alles andere bleibt, wie es in Config/Info.plist steht — vor
            // allem die Beamer-Szene für den zweiten Bildschirm. Ohne diesen
            // Zweig verdrängte die Rückgabe hier ihren Delegaten, und der
            // Beamer bliebe schwarz.
            return UISceneConfiguration(name: "Beamer", sessionRole: verbindung.role)
        }
        let konfiguration = UISceneConfiguration(name: nil, sessionRole: verbindung.role)
        konfiguration.delegateClass = FreigabeSceneDelegate.self
        return konfiguration
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

/// Nimmt Einladungen zu geteilten Tafeln entgegen.
///
/// Wichtig: Dieser Delegat legt **kein** Fenster an und beantwortet
/// `scene(_:willConnectTo:options:)` nicht. Täte er es, verdrängte er die
/// `WindowGroup` von SwiftUI und die App startete ins Schwarze.
final class FreigabeSceneDelegate: UIResponder, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene,
                     userDidAcceptCloudKitShareWith metadaten: CKShare.Metadata) {
        BoardStore.shared.nimmFreigabeAn(metadaten)
    }
}

@main
struct KlassenraumApp: App {
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
