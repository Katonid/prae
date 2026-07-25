//
//  HimmelskompassWidgets.swift
//  HimmelskompassWidgets
//
//  Home- und Sperrbildschirm-Widgets: "Heute am Himmel" (Sonne, goldene
//  Stunde, Tagesverlauf, Mond) und das Mond-Widget. Alle Werte werden
//  offline aus dem zuletzt in der App verwendeten Ort berechnet.
//

import WidgetKit
import SwiftUI

// MARK: - Farbwelt (kompakte Fassung der App-Farben)

enum WColor {
    static let bg = Color(red: 0x0d / 255, green: 0x1b / 255, blue: 0x2a / 255)
    static let card2 = Color(red: 0x16 / 255, green: 0x23 / 255, blue: 0x35 / 255)
    static let fg = Color(red: 0xe8 / 255, green: 0xee / 255, blue: 0xf7 / 255)
    static let fgDim = Color(red: 0x9f / 255, green: 0xb0 / 255, blue: 0xc7 / 255)
    static let accent = Color(red: 0xff / 255, green: 0xb7 / 255, blue: 0x03 / 255)
    static let moonLight = Color(red: 0x8e / 255, green: 0xc9 / 255, blue: 0xff / 255)

    static let night = Color(red: 0x0b / 255, green: 0x10 / 255, blue: 0x26 / 255)
    static let astro = Color(red: 0x1b / 255, green: 0x25 / 255, blue: 0x57 / 255)
    static let naut = Color(red: 0x2e / 255, green: 0x44 / 255, blue: 0x82 / 255)
    static let blue = Color(red: 0x4a / 255, green: 0x90 / 255, blue: 0xd9 / 255)
    static let golden = accent
    static let day = Color(red: 0xbf / 255, green: 0xe0 / 255, blue: 0xff / 255)

    /// Farbe des Tagesverlaufs-Balkens für eine Sonnenhöhe in Grad
    static func timeline(_ altDeg: Double) -> Color {
        altDeg < -18 ? night :
        altDeg < -12 ? astro :
        altDeg < -8 ? naut :
        altDeg < -4 ? blue :
        altDeg < 6 ? golden : day
    }
}

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

// MARK: - Berechnete Tageswerte für einen Eintrag

struct SkyInfo {
    let f: HKFormatters
    let sunTimes: SunTimes
    let moonTimes: MoonTimes
    let illum: MoonIllumination
    let dayLength: String
    let goldenEvening: String
    let blueEvening: String
    let segments: [(count: Int, color: Color)]
    let nowFraction: Double

    init(date: Date, place: SharedPlace) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = place.timeZone
        f = HKFormatters(timeZone: place.timeZone)

        let dayComps = cal.dateComponents([.year, .month, .day], from: date)
        func at(_ minutes: Int) -> Date {
            var c = DateComponents()
            c.year = dayComps.year
            c.month = dayComps.month
            c.day = dayComps.day
            c.hour = minutes / 60
            c.minute = minutes % 60
            return cal.date(from: c) ?? date
        }

        let noon = at(12 * 60)
        let t = Astro.sunTimes(date: noon, lat: place.lat, lng: place.lng)
        sunTimes = t
        moonTimes = Astro.moonTimes(date: at(0), lat: place.lat, lng: place.lng)
        illum = Astro.moonIllumination(date: noon)

        if let rise = t.sunrise, let set = t.sunset {
            dayLength = HKFormatters.duration(set.timeIntervalSince(rise))
        } else {
            let alt = Astro.sunPosition(date: noon, lat: place.lat, lng: place.lng).altitude
            dayLength = alt > 0 ? "Polartag" : "Polarnacht"
        }
        goldenEvening = f.range(t.goldenHourDuskStart, t.blueHourDuskStart)
        blueEvening = f.range(t.blueHourDuskStart, t.blueHourDuskEnd)

        // Tagesverlaufs-Balken (20-Minuten-Raster reicht für Widget-Größe)
        var segs: [(count: Int, color: Color)] = []
        for m in stride(from: 0, to: 1440, by: 20) {
            let alt = Astro.sunPosition(date: at(m + 10), lat: place.lat, lng: place.lng)
                .altitude * 180 / .pi
            let color = WColor.timeline(alt)
            if let last = segs.last, last.color == color {
                segs[segs.count - 1].count += 1
            } else {
                segs.append((count: 1, color: color))
            }
        }
        segments = segs

        let hm = cal.dateComponents([.hour, .minute], from: date)
        nowFraction = Double((hm.hour ?? 0) * 60 + (hm.minute ?? 0)) / 1440
    }

    var moonPercent: Int { Int((illum.fraction * 100).rounded()) }
    var moonRiseSet: String {
        if moonTimes.alwaysUp { return "ganztägig" }
        if moonTimes.alwaysDown { return "nicht sichtbar" }
        return "↑ " + f.time(moonTimes.rise) + "  ↓ " + f.time(moonTimes.set)
    }
}

// MARK: - Bausteine

/// Tagesverlaufs-Balken mit "Jetzt"-Markierung
struct WTimelineBar: View {
    var info: SkyInfo

    var body: some View {
        GeometryReader { geo in
            let total = max(1, info.segments.reduce(0) { $0 + $1.count })
            HStack(spacing: 0) {
                ForEach(Array(info.segments.enumerated()), id: \.offset) { _, seg in
                    seg.color
                        .frame(width: geo.size.width * CGFloat(seg.count) / CGFloat(total))
                }
            }
            .overlay(alignment: .topLeading) {
                Rectangle()
                    .fill(.white)
                    .frame(width: 2)
                    .offset(x: geo.size.width * info.nowFraction - 1)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

/// Mondphasen-Grafik (0 = Neumond, 0.5 = Vollmond)
struct WMoonPhase: View {
    var phase: Double
    var light: Color = Color(red: 0xf5 / 255, green: 0xf0 / 255, blue: 0xdc / 255)
    var dark: Color = Color(red: 0x23 / 255, green: 0x2b / 255, blue: 0x3a / 255)
    var rim: Color = Color(red: 0x3a / 255, green: 0x4a / 255, blue: 0x63 / 255)

    var body: some View {
        Canvas { ctx, size in
            let cx = size.width / 2
            let cy = size.height / 2
            let r = min(size.width, size.height) / 2 - 1

            let disc = Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r))
            ctx.fill(disc, with: .color(dark))
            ctx.stroke(disc, with: .color(rim), lineWidth: 1)

            let waxing = phase <= 0.5
            let semiX = r * cos(2 * .pi * phase)

            ctx.drawLayer { layer in
                layer.clip(to: disc)
                var half = Path()
                half.addArc(center: CGPoint(x: cx, y: cy), radius: r,
                            startAngle: .degrees(-90), endAngle: .degrees(90),
                            clockwise: !waxing)
                half.closeSubpath()
                layer.fill(half, with: .color(light))

                let ellipse = Path(ellipseIn: CGRect(x: cx - abs(semiX), y: cy - r,
                                                     width: 2 * abs(semiX), height: 2 * r))
                layer.fill(ellipse, with: .color(semiX < 0 ? light : dark))
            }
        }
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
