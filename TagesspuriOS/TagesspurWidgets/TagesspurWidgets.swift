import WidgetKit
import SwiftUI

// MARK: - Datenaustausch mit der App (App-Gruppe)

/// Von der App geschriebener Tages-Schnappschuss (WidgetBridge).
/// Struktur hier bewusst dupliziert — das Widget-Target ist eigenständig.
struct WidgetSnapshot: Codable {
    var dayKey: String = ""
    var distanceMeters: Double = 0
    var startDate: Date?
    var endDate: Date?
    var visitCount: Int = 0
    var trackingEnabled: Bool = false
    var highAccuracy: Bool = false
    var isResting: Bool = false
    var points: [[Double]] = []      // [lat, lon], ausgedünnt
    var updatedAt: Date = .distantPast

    static let appGroup = "group.de.familie.tagesspur"

    static func load() -> WidgetSnapshot? {
        guard let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent("widget-snapshot.json"),
            let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }

    static var preview: WidgetSnapshot {
        var snapshot = WidgetSnapshot()
        snapshot.distanceMeters = 12_400
        snapshot.trackingEnabled = true
        snapshot.points = [[51.49, 7.41], [51.494, 7.418], [51.5, 7.415], [51.503, 7.425], [51.507, 7.421]]
        return snapshot
    }

    /// Gilt der Schnappschuss für den heutigen Tag?
    var isToday: Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return dayKey == formatter.string(from: Date())
    }

    var distanceText: String {
        guard isToday else { return "0 m" }
        return distanceMeters >= 1000
            ? String(format: "%.1f km", distanceMeters / 1000)
            : String(format: "%.0f m", distanceMeters)
    }

    var durationText: String {
        guard isToday, let startDate, let endDate, endDate > startDate else { return "–" }
        let minutes = Int(endDate.timeIntervalSince(startDate) / 60)
        return minutes >= 60 ? "\(minutes / 60) h \(minutes % 60) min" : "\(minutes) min"
    }

    var statusText: String {
        guard trackingEnabled else { return "Pausiert" }
        if isResting { return "Ruhemodus" }
        return highAccuracy ? "GPS · präzise" : "GPS aktiv"
    }

    var statusSymbol: String {
        guard trackingEnabled else { return "pause.circle" }
        return isResting ? "moon.zzz.fill" : "antenna.radiowaves.left.and.right"
    }

    var todayPoints: [[Double]] {
        isToday ? points : []
    }
}

// MARK: - Timeline

struct TodayEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry {
        TodayEntry(date: Date(), snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        completion(TodayEntry(date: Date(), snapshot: WidgetSnapshot.load() ?? .preview))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let entry = TodayEntry(date: Date(), snapshot: WidgetSnapshot.load() ?? WidgetSnapshot())
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15 * 60))))
    }
}

// MARK: - Track als Vektorpfad

struct TrackShape: Shape {
    let points: [[Double]]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let valid = points.filter { $0.count >= 2 }
        guard valid.count > 1,
              let minLat = valid.map({ $0[0] }).min(), let maxLat = valid.map({ $0[0] }).max(),
              let minLon = valid.map({ $0[1] }).min(), let maxLon = valid.map({ $0[1] }).max() else {
            return path
        }
        let midLat = (minLat + maxLat) / 2
        let midLon = (minLon + maxLon) / 2
        let cosLat = max(cos(midLat * .pi / 180), 0.01)
        let spanX = max((maxLon - minLon) * cosLat, 1e-6)
        let spanY = max(maxLat - minLat, 1e-6)
        let scale = min(rect.width / spanX, rect.height / spanY) * 0.85

        for (index, point) in valid.enumerated() {
            let x = rect.midX + CGFloat((point[1] - midLon) * cosLat * scale)
            let y = rect.midY - CGFloat((point[0] - midLat) * scale)
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return path
    }
}

// MARK: - Ansichten

struct TodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodayEntry

    private var snapshot: WidgetSnapshot { entry.snapshot }

    private static let gradient = LinearGradient(
        colors: [Color(red: 0.06, green: 0.16, blue: 0.29),
                 Color(red: 0.17, green: 0.55, blue: 0.70)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    var body: some View {
        switch family {
        case .systemMedium:
            medium
        case .accessoryCircular:
            circular
        case .accessoryRectangular:
            rectangular
        default:
            small
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Tagesspur", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                .font(.caption2.bold())
                .opacity(0.85)
            Spacer()
            Text(snapshot.distanceText)
                .font(.system(.title, design: .rounded).bold())
                .minimumScaleFactor(0.6)
            Text(snapshot.durationText)
                .font(.caption)
                .opacity(0.85)
            Label(snapshot.statusText, systemImage: snapshot.statusSymbol)
                .font(.caption2)
                .opacity(0.85)
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { Self.gradient }
    }

    private var medium: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Label("Tagesspur", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                    .font(.caption2.bold())
                    .opacity(0.85)
                Spacer()
                Text(snapshot.distanceText)
                    .font(.system(.largeTitle, design: .rounded).bold())
                    .minimumScaleFactor(0.6)
                Text(snapshot.durationText)
                    .font(.caption)
                    .opacity(0.85)
                Label(snapshot.statusText, systemImage: snapshot.statusSymbol)
                    .font(.caption2)
                    .opacity(0.85)
                    .lineLimit(1)
            }
            if snapshot.todayPoints.count > 1 {
                ZStack {
                    TrackShape(points: snapshot.todayPoints)
                        .stroke(.white.opacity(0.35), style: StrokeStyle(lineWidth: 5.5, lineCap: .round, lineJoin: .round))
                    TrackShape(points: snapshot.todayPoints)
                        .stroke(.white, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "map")
                        .font(.title2)
                    Text("Noch kein Track heute")
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(.white.opacity(0.7))
                .frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(.white)
        .containerBackground(for: .widget) { Self.gradient }
    }

    private var circular: some View {
        VStack(spacing: 1) {
            Image(systemName: snapshot.statusSymbol)
                .font(.caption2)
            Text(snapshot.distanceText)
                .font(.system(.caption, design: .rounded).bold())
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
        .widgetAccentable()
        .containerBackground(for: .widget) { Color.clear }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            Label("Tagesspur", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                .font(.caption2.bold())
            Text("\(snapshot.distanceText) · \(snapshot.statusText)")
                .font(.caption)
            Text(snapshot.durationText)
                .font(.caption2)
                .opacity(0.8)
        }
        .widgetAccentable()
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { Color.clear }
    }
}

// MARK: - Widget-Definition

struct TodayWidget: Widget {
    let kind = "TagesspurToday"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayProvider()) { entry in
            TodayWidgetView(entry: entry)
        }
        .configurationDisplayName("Tagesspur heute")
        .description("Strecke, Status und Mini-Track des heutigen Tages.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

@main
struct TagesspurWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TodayWidget()
    }
}
