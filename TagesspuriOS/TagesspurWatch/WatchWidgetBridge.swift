import Foundation
import SwiftData
import WidgetKit

/// Schreibt den Tages-Schnappschuss für die Zifferblatt-Komplikationen
/// in die App-Gruppe (Pendant zum WidgetBridge auf dem iPhone).
enum WatchWidgetBridge {
    static let appGroup = "group.de.familie.tagesspur"

    /// Muss strukturell zum Snapshot im Watch-Widget-Target passen.
    private struct Snapshot: Codable {
        var dayKey = ""
        var distanceMeters: Double = 0
        var isRecording = false
        var updatedAt = Date()
    }

    static func update(container: ModelContainer, isRecording: Bool) {
        guard let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent("watch-snapshot.json") else { return }

        let context = ModelContext(container)
        let key = DayKey.key(for: Date())
        let predicate = #Predicate<TrackDay> { $0.dayKey == key }
        let days = (try? context.fetch(FetchDescriptor(predicate: predicate))) ?? []

        var snapshot = Snapshot()
        snapshot.dayKey = key
        snapshot.distanceMeters = days.reduce(0) { $0 + $1.distanceMeters }
        snapshot.isRecording = isRecording

        guard let data = try? JSONEncoder.tagesspur.encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
