//  NotificationCenterService.swift
//  Permissions, categories, and what happens when a notification arrives.
//
//  The delegate methods are the second half of the delivery path; the first
//  half is the notification service extension. Between them they have to make
//  three situations work, and they are genuinely different:
//
//  * App in the foreground — iOS asks us whether to show anything. We say yes
//    (a banner AND a sound), and open the alarm screen at the same time. In
//    Split View or Stage Manager the app may be visible but not the thing the
//    user is looking at; a silent screen change would be missed.
//  * App in the background or the device locked — iOS shows the notification
//    itself. Tapping it lands in `didReceive(response:)`.
//  * Silent ping — no interface at all, just a line written about this device.

import UIKit
import UserNotifications

@MainActor
final class NotificationCenterService: NSObject, ObservableObject {

    /// What iOS currently allows. Re-read at every launch and every return to
    /// the foreground: a colleague can revoke any of it in Settings, and a
    /// revoked permission is a device that stays quiet.
    struct Permissions: Equatable {
        var authorization: UNAuthorizationStatus = .notDetermined
        var alertsEnabled = false
        var soundEnabled = false
        var lockScreenEnabled = false
        var timeSensitiveAllowed = false
        var criticalAllowed = false

        static let unknown = Permissions()
    }

    @Published private(set) var permissions = Permissions.unknown

    /// Set when a push wants the alarm screen open. The root view watches it.
    @Published var pendingEvent: AlarmEvent?

    /// An acknowledgement chosen from the notification itself.
    @Published var pendingAck: (alarmId: String, state: AckState)?

    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        center.delegate = self
    }

    // MARK: - Setting up

    /// Asks for exactly the permissions this app needs, and nothing else.
    ///
    /// `.criticalAlert` is behind a compilation condition because the matching
    /// entitlement is granted by Apple on written request only. Asking for it
    /// without the entitlement does not fail loudly — it simply never
    /// succeeds, which is the kind of quiet defect this app cannot afford.
    @discardableResult
    func requestAuthorization() async -> Bool {
        var options: UNAuthorizationOptions = [.alert, .sound, .badge]
        #if CRITICAL_ALERTS
        options.insert(.criticalAlert)
        #endif
        let granted = (try? await center.requestAuthorization(options: options)) ?? false
        registerCategories()
        await refreshPermissions()
        if granted {
            UIApplication.shared.registerForRemoteNotifications()
        }
        return granted
    }

    /// Registers the two buttons that appear on the notification itself.
    ///
    /// They matter more than they look: a teacher standing in a locked
    /// classroom can answer without unlocking the iPad, and every second
    /// between "heard it" and "answered it" is a second the head teacher spends
    /// not knowing.
    func registerCategories() {
        let secured = UNNotificationAction(
            identifier: AckState.secured.rawValue,
            title: "Gesehen – Klasse gesichert",
            options: [.authenticationRequired])
        let help = UNNotificationAction(
            identifier: AckState.needsHelp.rawValue,
            title: "Gesehen – Hilfe nötig",
            options: [.authenticationRequired, .destructive])

        let alarm = UNNotificationCategory(identifier: PushAsset.alarmCategory,
                                           actions: [secured, help],
                                           intentIdentifiers: [],
                                           options: [.customDismissAction])
        let allClear = UNNotificationCategory(identifier: PushAsset.allClearCategory,
                                              actions: [],
                                              intentIdentifiers: [],
                                              options: [])
        center.setNotificationCategories([alarm, allClear])
    }

    func refreshPermissions() async {
        let settings = await center.notificationSettings()
        permissions = Permissions(
            authorization: settings.authorizationStatus,
            alertsEnabled: settings.alertSetting == .enabled,
            soundEnabled: settings.soundSetting == .enabled,
            lockScreenEnabled: settings.lockScreenSetting == .enabled,
            timeSensitiveAllowed: settings.timeSensitiveSetting == .enabled,
            criticalAllowed: settings.criticalAlertSetting == .enabled)
    }
}

extension NotificationCenterService: UNUserNotificationCenterDelegate {

    /// The app is in the foreground and a push arrives.
    ///
    /// Showing the banner as well as opening the screen is deliberate
    /// duplication. On an iPad the app may be one of two windows, or a small
    /// pane beside a browser; the screen change alone can happen outside the
    /// user's field of view.
    ///
    /// **Bewusst die Fassung mit Rückruf, nicht die mit `async`.** Siehe
    /// unten — es ist derselbe Grund, und er hat einen Absturz gekostet.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler:
            @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let ergebnis = PushPayloadParser.event(from: notification.request.content.userInfo)
        Task { @MainActor in
            var optionen: UNNotificationPresentationOptions = [.banner, .sound, .list]
            if case .success(let event) = ergebnis {
                self.pendingEvent = event
                if event.isSilent { optionen = [] }
            }
            completionHandler(optionen)
        }
    }

    /// Somebody tapped the notification, or one of its buttons.
    ///
    /// **Der Rückruf gehört auf den Hauptfaden — hier hing der Absturz.**
    ///
    /// Mit ihm endet für iOS ein Hintergrundereignis; UIKit schreibt daraufhin
    /// den Wiederherstellungsstand fort und macht ein Bildschirmfoto. Beides
    /// prüft den Hauptfaden und bricht sonst ab (`SIGABRT` aus
    /// `_performBlockAfterCATransactionCommitSynchronizes:`).
    ///
    /// Bis 1.0.21 stand hier die `async`-Fassung dieser Methode. Die sieht
    /// harmlos aus, ist aber die Falle: Swift baut daraus die Fassung mit
    /// Rückruf, und der Rückruf wird auf dem Faden aufgerufen, auf dem die
    /// async-Funktion ENDET — nach einem `await MainActor.run` also im
    /// Nebenläufigkeits-Pool. Genau deshalb stürzte die App **nur beim Tippen
    /// auf die Mitteilung** ab und nie beim Öffnen über das Symbol (gemeldet
    /// 09/2026). Der Rückruf steht jetzt am Ende eines `@MainActor`-Tasks, und
    /// damit ist der Faden garantiert der richtige.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let ergebnis = PushPayloadParser.event(from: response.notification.request.content.userInfo)
        let aktion = response.actionIdentifier
        Task { @MainActor in
            if case .success(let event) = ergebnis {
                self.pendingEvent = event
                if let alarmId = event.alarmPayload?.alarmId,
                   let state = AckState(rawValue: aktion) {
                    self.pendingAck = (alarmId, state)
                }
            }
            completionHandler()
        }
    }
}
