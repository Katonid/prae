import WidgetKit
import SwiftUI

/// Zifferblatt-Komplikationen: heutige Kilometer + Aufzeichnungsstatus.
/// Daten kommen aus dem App-Gruppen-Schnappschuss der Watch-App.

struct WatchSnapshot: Codable {
    var dayKey = ""
    var distanceMeters: Double = 0
    var isRecording = false
    var updatedAt = Date()
}

struct TodayEntry: TimelineEntry {
    let date: Date
    let kilometers: Double
    let isRecording: Bool
}

struct TodayProvider: TimelineProvider {
    private func loadEntry() -> TodayEntry {
        guard let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.de.familie.tagesspur")?
            .appendingPathComponent("watch-snapshot.json"),
              let data = try? Data(contentsOf: url) else {
            return TodayEntry(date: Date(), kilometers: 0, isRecording: false)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let snapshot = try? decoder.decode(WatchSnapshot.self, from: data) else {
            return TodayEntry(date: Date(), kilometers: 0, isRecording: false)
        }
        // Schnappschuss von gestern? Dann heute bei 0 beginnen.
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let todayKey = formatter.string(from: Date())
        let km = snapshot.dayKey == todayKey ? snapshot.distanceMeters / 1000 : 0
        return TodayEntry(date: Date(), kilometers: km, isRecording: snapshot.isRecording)
    }

    func placeholder(in context: Context) -> TodayEntry {
        TodayEntry(date: Date(), kilometers: 12.3, isRecording: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let refresh = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        completion(Timeline(entries: [loadEntry()], policy: .after(refresh)))
    }
}

struct ComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodayEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            VStack(spacing: 0) {
                Text(String(format: "%.0f", entry.kilometers))
                    .font(.system(.title3, design: .rounded).bold())
                Text("km")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text("Tagesspur")
                    .font(.headline)
                Text(String(format: "%.1f km heute", entry.kilometers))
                if entry.isRecording {
                    Label("Aufzeichnung läuft", systemImage: "record.circle")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
            }
        default:
            Text(String(format: "%.1f km heute", entry.kilometers))
        }
    }
}

struct TagesspurComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TagesspurWatchToday", provider: TodayProvider()) { entry in
            ComplicationView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Tagesspur")
        .description("Heutige Kilometer und Aufzeichnungsstatus.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct TagesspurWatchWidgets: WidgetBundle {
    var body: some Widget {
        TagesspurComplication()
    }
}
