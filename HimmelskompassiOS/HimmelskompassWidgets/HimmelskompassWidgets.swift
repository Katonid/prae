//
//  HimmelskompassWidgets.swift
//  HimmelskompassWidgets
//
//  Home- und Sperrbildschirm-Widgets: "Heute am Himmel" (Sonne, goldene
//  Stunde, Tagesverlauf, Mond) und das Mond-Widget. Alle Werte werden
//  offline aus dem zuletzt in der App verwendeten Ort berechnet.
//  Farben, Tageswerte und Grafik-Bausteine kommen aus Shared/SkyWidgetSupport.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline-Provider

struct SkyEntry: TimelineEntry {
    let date: Date
    let place: SharedPlace
}

struct SkyProvider: TimelineProvider {
    func placeholder(in context: Context) -> SkyEntry {
        SkyEntry(date: Date(), place: .fallback)
    }

    func getSnapshot(in context: Context, completion: @escaping (SkyEntry) -> Void) {
        completion(SkyEntry(date: Date(), place: SharedPlace.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SkyEntry>) -> Void) {
        // Einträge im Viertelstundentakt für die nächsten 8 Stunden,
        // danach wird die Timeline automatisch neu berechnet
        let place = SharedPlace.load()
        let now = Date()
        let entries = (0..<32).map { i in
            SkyEntry(date: now.addingTimeInterval(Double(i) * 15 * 60), place: place)
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - Widget "Heute am Himmel"

struct TodaySkyView: View {
    @Environment(\.widgetFamily) private var family
    var entry: SkyEntry

    var body: some View {
        let info = SkyInfo(date: entry.date, place: entry.place)
        Group {
            switch family {
            case .systemMedium:
                medium(info)
            case .accessoryInline:
                Text("☀️ \(info.f.time(info.sunTimes.sunrise)) → \(info.f.time(info.sunTimes.sunset))")
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 1) {
                    Text("☀️ \(info.f.time(info.sunTimes.sunrise)) → \(info.f.time(info.sunTimes.sunset))")
                        .font(.headline)
                    Text("Goldene Std. \(info.goldenEvening)")
                        .font(.caption2)
                    Text("🌙 \(info.moonPercent) % · \(Astro.moonPhaseName(info.illum.phase))")
                        .font(.caption2)
                }
            default:
                small(info)
            }
        }
        .containerBackground(for: .widget) {
            if family == .systemSmall || family == .systemMedium {
                WColor.bg
            } else {
                Color.clear
            }
        }
    }

    private func small(_ info: SkyInfo) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Aufgang").font(.system(size: 9)).foregroundStyle(WColor.fgDim)
                    Text(info.f.time(info.sunTimes.sunrise))
                        .font(.system(size: 17, weight: .bold)).monospacedDigit()
                        .foregroundStyle(WColor.accent)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text("Untergang").font(.system(size: 9)).foregroundStyle(WColor.fgDim)
                    Text(info.f.time(info.sunTimes.sunset))
                        .font(.system(size: 17, weight: .bold)).monospacedDigit()
                        .foregroundStyle(WColor.accent)
                }
            }
            WTimelineBar(info: info)
                .frame(height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text("Goldene Std. \(info.goldenEvening)")
                    .font(.system(size: 10)).foregroundStyle(WColor.fg)
                HStack(spacing: 4) {
                    WMoonPhase(phase: info.illum.phase)
                        .frame(width: 13, height: 13)
                    Text("\(info.moonPercent) % beleuchtet")
                        .font(.system(size: 10)).foregroundStyle(WColor.fgDim)
                }
            }
        }
    }

    private func medium(_ info: SkyInfo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 10) {
                        bigTime("Aufgang", info.f.time(info.sunTimes.sunrise))
                        bigTime("Untergang", info.f.time(info.sunTimes.sunset))
                        bigTime("Tageslänge", info.dayLength)
                    }
                    Text("Goldene Stunde \(info.goldenEvening)")
                        .font(.system(size: 11)).foregroundStyle(WColor.golden)
                    Text("Blaue Stunde \(info.blueEvening)")
                        .font(.system(size: 11)).foregroundStyle(WColor.blue)
                }
                Spacer()
                VStack(spacing: 2) {
                    WMoonPhase(phase: info.illum.phase)
                        .frame(width: 40, height: 40)
                    Text("\(info.moonPercent) %")
                        .font(.system(size: 10)).foregroundStyle(WColor.fgDim)
                }
            }
            Spacer(minLength: 0)
            WTimelineBar(info: info)
                .frame(height: 9)
        }
    }

    private func bigTime(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label).font(.system(size: 9)).foregroundStyle(WColor.fgDim)
            Text(value)
                .font(.system(size: 16, weight: .bold)).monospacedDigit()
                .foregroundStyle(WColor.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }
}

struct TodaySkyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodaySky", provider: SkyProvider()) { entry in
            TodaySkyView(entry: entry)
        }
        .configurationDisplayName("Heute am Himmel")
        .description("Sonnenauf- und -untergang, goldene und blaue Stunde, Tagesverlauf und Mondphase für deinen Ort.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryInline, .accessoryRectangular])
    }
}

// MARK: - Mond-Widget

struct MoonView: View {
    @Environment(\.widgetFamily) private var family
    var entry: SkyEntry

    var body: some View {
        let info = SkyInfo(date: entry.date, place: entry.place)
        Group {
            if family == .accessoryCircular {
                // Sperrbildschirm: Phase in Weiß auf Transparent
                WMoonPhase(phase: info.illum.phase,
                           light: .white,
                           dark: .white.opacity(0.2),
                           rim: .white.opacity(0.4))
                    .padding(2)
            } else {
                VStack(spacing: 3) {
                    WMoonPhase(phase: info.illum.phase)
                        .frame(width: 56, height: 56)
                    Text(Astro.moonPhaseName(info.illum.phase))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(WColor.fg)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("\(info.moonPercent) % beleuchtet")
                        .font(.system(size: 9)).foregroundStyle(WColor.fgDim)
                    Text(info.moonRiseSet)
                        .font(.system(size: 9)).monospacedDigit()
                        .foregroundStyle(WColor.moonLight)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
        .containerBackground(for: .widget) {
            if family == .accessoryCircular {
                Color.clear
            } else {
                WColor.bg
            }
        }
    }
}

struct MoonWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Moon", provider: SkyProvider()) { entry in
            MoonView(entry: entry)
        }
        .configurationDisplayName("Mond")
        .description("Mondphase, Beleuchtungsgrad und Auf-/Untergang für deinen Ort.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

// MARK: - Bundle

@main
struct HimmelskompassWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodaySkyWidget()
        MoonWidget()
    }
}
