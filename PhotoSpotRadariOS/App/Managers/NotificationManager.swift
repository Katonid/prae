@preconcurrency import UserNotifications
import Foundation
import PhotoSpotCore

@MainActor
final class NotificationManager: NSObject, @preconcurrency UNUserNotificationCenterDelegate {
    private let center: UNUserNotificationCenter
    var onOpenSpot: ((String) -> Void)?

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
        super.init()
        center.delegate = self
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    func schedule(for spot: PersistedPhotoSpot, distance: Double) async throws {
        let content = UNMutableNotificationContent()
        content.title = spot.category.notificationTitle
        let formatted = Measurement(value: distance, unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road))
        content.body = "\(spot.name) liegt nur noch \(formatted) voraus."
        content.sound = .default
        content.userInfo = ["spotID": spot.id]
        // Stable identifier replaces a still-pending duplicate atomically.
        try await center.add(.init(identifier: "spot-\(spot.id)", content: content, trigger: nil))
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        if let id = response.notification.request.content.userInfo["spotID"] as? String { onOpenSpot?(id) }
    }
}
