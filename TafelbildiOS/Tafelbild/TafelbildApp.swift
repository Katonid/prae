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
        // Der Weckdienst muss früh stehen: Er ist der Delegat des
        // Mitteilungsdienstes, und den setzt iOS nur einmal beim Start
        // zuverlässig aus.
        Task { @MainActor in Weckdienst.shared.pruefeErlaubnis() }
        return true
    }

    /// Hängt an die gewöhnliche App-Szene einen eigenen Delegaten.
    ///
    /// Nur dafür: `windowScene(_:userDidAcceptCloudKitShareWith:)` gibt es
    /// ausschließlich am Szenen-Delegaten. Ohne ihn öffnete ein Freigabe-Link
    /// zwar die App, käme aber nirgends an.
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
/// Zwei Dinge sind hier wichtig:
///
/// 1. **`window` gehört dazu.** `UIWindowSceneDelegate` erklärt die
///    Eigenschaft; UIKit legt das Fenster der Szene dort ab. Ein Delegat
///    ohne sie ist eine Sackgasse für jeden, der über die Szene an das
///    Fenster will. `BeamerSceneDelegate` hat sie aus demselben Grund.
/// 2. **`scene(_:willConnectTo:options:)` bleibt unbeantwortet.** Wer es
///    beantwortet, verdrängt die `WindowGroup` von SwiftUI, und die App
///    startet ins Schwarze.
///
/// In 0.1.8 war dieser Delegat einmal ausgebaut — ich hatte ihn für den
/// stummen Dateiwähler verantwortlich gemacht. Das war falsch: Bild und
/// Video ließen sich die ganze Zeit auswählen, nur der Ton nicht. Die
/// Ursache lag im Klang-Abschnitt selbst (siehe `WidgetSettingsSheet`).
final class FreigabeSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func windowScene(_ windowScene: UIWindowScene,
                     userDidAcceptCloudKitShareWith metadaten: CKShare.Metadata) {
        BoardStore.shared.nimmFreigabeAn(metadaten)
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
                // Merken, ab wann die App wieder vorn ist: Alles, was
                // vorher ablief, hat iOS schon gemeldet und darf nicht
                // gleich noch einmal klingen.
                Weckdienst.shared.wurdeAktiv()
                // Feiert heute jemand? Die Seiten entstehen beim Aktivwerden,
                // nicht auf Vorrat — siehe Geburtstagsdienst.
                store.pruefeGeburtstage()
            default:
                UIApplication.shared.isIdleTimerDisabled = false
                store.stopAutoRefresh()
                store.saveNow()
            }
        }
    }
}
