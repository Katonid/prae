import CloudKit
import SwiftUI
import UIKit

/// Hängt an die App-Szene einen eigenen Delegaten — nur dafür, dass
/// Einladungen ankommen: `windowScene(_:userDidAcceptCloudKitShareWith:)`
/// gibt es ausschließlich am Szenen-Delegaten (dasselbe Muster wie
/// Tafelbild).
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Stille CloudKit-Pushes: Änderungen der anderen Geräte kommen dann
        // von selbst (CKSyncEngine hört darauf).
        application.registerForRemoteNotifications()
        return true
    }

    func application(_ application: UIApplication,
                     configurationForConnecting verbindung: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let konfiguration = UISceneConfiguration(name: nil, sessionRole: verbindung.role)
        konfiguration.delegateClass = FreigabeSceneDelegate.self
        return konfiguration
    }
}

/// Nimmt die Anmeldekarte eines Kindes entgegen (Freigabe-Link).
///
/// `scene(_:willConnectTo:options:)` bleibt absichtlich unbeantwortet —
/// wer es beantwortet, verdrängt die `WindowGroup` von SwiftUI (Lehre aus
/// Tafelbild). `window` gehört trotzdem dazu.
final class FreigabeSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func windowScene(_ windowScene: UIWindowScene,
                     userDidAcceptCloudKitShareWith metadaten: CKShare.Metadata) {
        Wolke.annehmen(metadaten, klasse: Klasse.geteilt)
    }
}

@main
struct SchreibspurApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var klasse = Klasse.geteilt
    @Environment(\.scenePhase) private var szene

    var body: some Scene {
        WindowGroup {
            Group {
                switch klasse.rolle {
                case nil:
                    Willkommen()
                case .allein?:
                    // Mehrere Kinder an einem Gerät: erst wählen, wer schreibt.
                    if klasse.aktiv == nil { KindWahl() } else { StartAnsicht() }
                case .lehrer?:
                    if klasse.probe { StartAnsicht() } else { LehrerStart() }
                case .kind?:
                    if klasse.aktiv == nil { KindWartet() } else { StartAnsicht() }
                }
            }
            .environment(klasse)
            // Die Gestaltung ist auf helles Papier abgestimmt.
            .preferredColorScheme(.light)
            .task { klasse.wolkeStarten() }
        }
        .onChange(of: szene) { _, neu in
            if neu == .active { Task { await klasse.wolke?.abgleichen() } }
        }
    }
}
