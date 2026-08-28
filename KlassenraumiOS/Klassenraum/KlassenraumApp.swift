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

// EINLADUNGEN ANNEHMEN — vorerst ausgebaut.
//
// In 0.1.6 hing hier ein eigener Szenen-Delegat: Nur an ihm gibt es
// `windowScene(_:userDidAcceptCloudKitShareWith:)`, den Rückruf für einen
// angetippten Freigabe-Link.
//
// **Er hat den Dateiwähler lahmgelegt.** Gemeldet für Tondateien, betroffen
// war jeder `.fileImporter` der App — auch Bild, Video, Tafelhintergrund und
// „Sicherung einlesen". Der Grund: Wer aus
// `application(_:configurationForConnecting:options:)` eine eigene
// `UISceneConfiguration` mit eigenem `delegateClass` zurückgibt, setzt damit
// den Szenen-Delegaten von SwiftUI ab. Das Fenster entsteht trotzdem, die App
// läuft — aber `.fileImporter` findet über die Szene keinen Halter mehr, von
// dem aus es den Dateiwähler zeigen könnte, und tut still gar nichts.
//
// Ein täglich gebrauchter Weg wiegt schwerer als ein neuer, den noch niemand
// gegangen ist. Deshalb ist der Delegat wieder draußen und die App hat genau
// den Aufbau, mit dem der Wähler zuletzt lief (0.1.4).
//
// Was das kostet: Ein Freigabe-Link öffnet die App, aber die Einladung kommt
// nirgends an. **Teilen, Widerrufen und „Als eigene Tafel übernehmen"
// funktionieren weiter** — nur das Annehmen auf dem anderen Gerät nicht.
//
// Der Rückbau kommt wieder, sobald bestätigt ist, dass der Wähler wieder
// geht: derselbe Delegat, aber mit `var window: UIWindow?`, damit die Szene
// ihr Fenster behält (so wie `BeamerSceneDelegate` es hat). Gegenprobe dann
// zuerst am Dateiwähler, nicht am Teilen.
//
// `BoardStore.nimmFreigabeAn(_:)` bleibt stehen — es fehlt nur der Anruf.

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
