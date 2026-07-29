//
//  HimmelskompassWatchWidgets.swift
//  HimmelskompassWatchWidgets
//
//  Komplikationen fürs Zifferblatt: Sonnenzeiten, goldene Stunde und
//  Mondphase. Rechnen offline mit dem zuletzt in der Watch-App
//  verwendeten Ort (App Group).
//

import WidgetKit
import SwiftUI

// MARK: - Timeline-Provider

struct WatchSkyEntry: TimelineEntry {
    let date: Date
    let place: SharedPlace
}

struct WatchSkyProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchSkyEntry {
        WatchSkyEntry(date: Date(), place: .fallback)
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchSkyEntry) -> Void) {
        completion(WatchSkyEntry(date: Date(), place: SharedPlace.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchSkyEntry>) -> Void) {
        let place = SharedPlace.load()
        let now = Date()
        let entries = (0..<24).map { i in
            WatchSkyEntry(date: now.addingTimeInterval(Double(i) * 15 * 60), place: place)
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - Sonnenzeiten

struct WatchSunView: View {
    @Environment(\.widgetFamily) private var family
    var entry: WatchSkyEntry

    var body: some View {
        let info = SkyInfo(date: entry.date, place: entry.place)
        Group {
            switch family {
            case .accessoryCorner:
                Text("☀️")
                    .font(.system(size: 20))
                    .widgetLabel {
                        Text("↑ \(info.f.time(info.sunTimes.sunrise)) ↓ \(info.f.time(info.sunTimes.sunset))")
                    }
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 1) {
                    Text("☀️ \(info.f.time(info.sunTimes.sunrise)) → \(info.f.time(info.sunTimes.sunset))")
                        .font(.headline)
                    Text("Goldene Std. \(info.goldenEvening)")
                        .font(.caption2)
                    Text("🌙 \(info.moonPercent) % · \(Astro.moonPhaseName(info.illum.phase))")
                        .font(.caption2)
                }
            default: // accessoryInline
                Text("☀️ \(info.f.time(info.sunTimes.sunrise)) → \(info.f.time(info.sunTimes.sunset))")
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }
}

struct WatchSunWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WatchSun", provider: WatchSkyProvider()) { entry in
            WatchSunView(entry: entry)
        }
        .configurationDisplayName("Sonnenzeiten")
        .description("Sonnenauf- und -untergang für deinen Ort.")
        .supportedFamilies([.accessoryInline, .accessoryRectangular, .accessoryCorner])
    }
}

// MARK: - Goldene Stunde

struct WatchGoldenView: View {
    @Environment(\.widgetFamily) private var family
    var entry: WatchSkyEntry

    var body: some View {
        let info = SkyInfo(date: entry.date, place: entry.place)
        let start = info.sunTimes.goldenHourDuskStart
        Group {
            switch family {
            case .accessoryCircular:
                VStack(spacing: 0) {
                    Text("Gold. Std.")
                        .font(.system(size: 9))
                    Text(info.f.time(start))
                        .font(.system(size: 15, weight: .bold)).monospacedDigit()
                }
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 1) {
                    Text("Goldene Stunde")
                        .font(.headline)
                    Text(info.goldenEvening)
                        .font(.caption2).monospacedDigit()
                    if let start, start > entry.date {
                        Text(start, style: .relative)
                            .font(.caption2)
                    }
                }
            default: // accessoryInline
                Text("Goldene Std. \(info.goldenEvening)")
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }
}

struct WatchGoldenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WatchGolden", provider: WatchSkyProvider()) { entry in
            WatchGoldenView(entry: entry)
        }
        .configurationDisplayName("Goldene Stunde")
        .description("Beginn der goldenen Stunde am Abend, mit Countdown.")
        .supportedFamilies([.accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - Mondphase

struct WatchMoonView: View {
    @Environment(\.widgetFamily) private var family
    var entry: WatchSkyEntry

    var body: some View {
        let info = SkyInfo(date: entry.date, place: entry.place)
        Group {
            if family == .accessoryCorner {
                WMoonPhase(phase: info.illum.phase,
                           light: .white,
                           dark: .white.opacity(0.2),
                           rim: .white.opacity(0.4))
                    .widgetLabel {
                        Text("\(info.moonPercent) % · \(Astro.moonPhaseName(info.illum.phase))")
                    }
            } else { // accessoryCircular
                WMoonPhase(phase: info.illum.phase,
                           light: .white,
                           dark: .white.opacity(0.2),
                           rim: .white.opacity(0.4))
                    .padding(2)
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }
}

struct WatchMoonWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WatchMoon", provider: WatchSkyProvider()) { entry in
            WatchMoonView(entry: entry)
        }
        .configurationDisplayName("Mondphase")
        .description("Die aktuelle Mondphase als Grafik.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner])
    }
}

// MARK: - Bundle

@main
struct HimmelskompassWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        WatchSunWidget()
        WatchGoldenWidget()
        WatchMoonWidget()
    }
}
