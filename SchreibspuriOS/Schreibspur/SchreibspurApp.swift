import SwiftUI
import UIKit

/// Stille CloudKit-Pushes: Änderungen der anderen Geräte kommen dann von
/// selbst (CKSyncEngine hört darauf).
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        application.registerForRemoteNotifications()
        return true
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
                    if klasse.aktiv == nil { KlassencodeEingabe() } else { StartAnsicht() }
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
