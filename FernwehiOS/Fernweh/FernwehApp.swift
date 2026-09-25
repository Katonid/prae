import SwiftUI
import CloudKit
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Stille Pushes: So erfährt die App von den Einträgen der Miturlauber.
        application.registerForRemoteNotifications()
        // Der Aufzeichner MUSS beim Start stehen — auch wenn iOS die App
        // wegen eines Ortswechsels im Hintergrund neu gestartet hat. Nur dann
        // läuft die Spur nach einem Beenden nahtlos weiter.
        _ = Persistenz.shared
        Task { @MainActor in
            Aufzeichner.shared.starten()
            Fotodienst.shared.beobachten()
        }
        return true
    }

    /// Hängt an die App-Szene einen eigenen Delegaten — nur für die
    /// Einladungen: `windowScene(_:userDidAcceptCloudKitShareWith:)` gibt es
    /// ausschließlich am Szenen-Delegaten.
    func application(
        _ application: UIApplication,
        configurationForConnecting verbindung: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let konfiguration = UISceneConfiguration(name: nil, sessionRole: verbindung.role)
        if verbindung.role == .windowApplication {
            konfiguration.delegateClass = EinladungsSzene.self
        }
        return konfiguration
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        // Den Import erledigt der Container selbst; hier nur bestätigen.
        completionHandler(.newData)
    }
}

/// Nimmt Einladungen zu geteilten Reisen entgegen.
///
/// `window` gehört dazu, und `scene(_:willConnectTo:options:)` bleibt
/// unbeantwortet — wer es beantwortet, verdrängt die `WindowGroup` von
/// SwiftUI (Lehre aus Tafelbild).
final class EinladungsSzene: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func windowScene(_ windowScene: UIWindowScene,
                     userDidAcceptCloudKitShareWith metadaten: CKShare.Metadata) {
        Persistenz.shared.einladungAnnehmen(metadaten)
    }
}

@main
struct FernwehApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var phase
    @AppStorage("fernweh.eingefuehrt") private var eingefuehrt = false
    @StateObject private var aufzeichner = Aufzeichner.shared
    @StateObject private var fotodienst = Fotodienst.shared
    @StateObject private var meldungen = Meldungen.shared

    var body: some Scene {
        WindowGroup {
            ZStack(alignment: .bottom) {
                if eingefuehrt {
                    // Zwei Fragen, zwei Reiter (ab 1.0.5): Was habe ich
                    // erlebt — und was war auf dieser einen Reise?
                    TabView {
                        TagebuchView()
                            .tabItem { Label("Tagebuch", systemImage: "book.pages.fill") }
                        ReisenView()
                            .tabItem { Label("Reisen", systemImage: "suitcase.fill") }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 1.04)))
                } else {
                    WillkommenView { withAnimation(.easeInOut(duration: 0.8)) { eingefuehrt = true } }
                        .transition(.opacity)
                }
                if let text = meldungen.text {
                    Text(text)
                        .font(.callout.weight(.medium))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.bottom, 70)
                        .padding(.horizontal, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onTapGesture { meldungen.text = nil }
                }
            }
            .animation(.spring(duration: 0.4), value: meldungen.text)
            .environment(\.managedObjectContext, Persistenz.shared.kontext)
            .environmentObject(aufzeichner)
            .environmentObject(fotodienst)
            .tint(Stil.akzent)
        }
        .onChange(of: phase) { _, neu in
            switch neu {
            case .active:
                aufzeichner.wurdeAktiv()
                Task { await fotodienst.abgleichen() }
            case .background:
                aufzeichner.uebertragen()
                Persistenz.shared.sichern()
            default:
                break
            }
        }
    }
}
