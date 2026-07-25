import Foundation
import SwiftData
import WidgetKit

/// Schreibt den Tages-Schnappschuss für die Widgets in die App-Gruppe
/// und stößt die Widget-Aktualisierung an. Gedrosselt (max. 1×/Minute),
/// damit häufige Flushs keine unnötige Arbeit erzeugen.
enum WidgetBridge {
    static let appGroup = "group.de.familie.tagesspur"
    private static var lastWrite = Date.distantPast

    /// Muss strukturell zum WidgetSnapshot im Widget-Target passen.
    private struct Snapshot: Codable {
        var dayKey = ""
        var distanceMeters: Double = 0
        var startDate: Date?
        var endDate: Date?
        var visitCount = 0
        var trackingEnabled = false
        var highAccuracy = false
        var isResting = false
        var points: [[Double]] = []
        var updatedAt = Date()
    }

    static func update(container: ModelContainer,
                       trackingEnabled: Bool,
                       highAccuracy: Bool,
                       isResting: Bool,
                       force: Bool = false) {
        guard force || Date().timeIntervalSince(lastWrite) > 60 else { return }
        guard let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent("widget-snapshot.json") else { return }
        lastWrite = Date()

        let context = ModelContext(container)
        let key = DayKey.key(for: Date())
        let dayPredicate = #Predicate<TrackDay> { $0.dayKey == key }
        let days = (try? context.fetch(FetchDescriptor(predicate: dayPredicate))) ?? []
        let visitPredicate = #Predicate<PlaceVisit> { $0.dayKey == key }
        let visitCount = (try? context.fetchCount(FetchDescriptor(predicate: visitPredicate))) ?? 0

        let merged = days.flatMap { $0.points() }.sorted { $0.t < $1.t }
        let sampled = TrackMath.downsample(merged, maxCount: 120)

        var snapshot = Snapshot()
        snapshot.dayKey = key
        snapshot.distanceMeters = days.reduce(0) { $0 + $1.distanceMeters }
        snapshot.startDate = merged.first?.t
        snapshot.endDate = merged.last?.t
        snapshot.visitCount = visitCount
        snapshot.trackingEnabled = trackingEnabled
        snapshot.highAccuracy = highAccuracy
        snapshot.isResting = isResting
        snapshot.points = sampled.map { [$0.lat, $0.lon] }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
