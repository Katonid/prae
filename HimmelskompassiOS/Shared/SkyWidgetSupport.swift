//
//  SkyWidgetSupport.swift
//  Himmelskompass
//
//  Gemeinsame Bausteine für die iOS-Widgets, die Watch-Komplikationen und
//  die Watch-App: Farbwelt, berechnete Tageswerte für einen Zeitpunkt sowie
//  Tagesverlaufs-Balken und Mondphasen-Grafik.
//

import SwiftUI

// MARK: - Farbwelt (kompakte Fassung der App-Farben)

enum WColor {
    static let bg = Color(red: 0x0d / 255, green: 0x1b / 255, blue: 0x2a / 255)
    static let card2 = Color(red: 0x16 / 255, green: 0x23 / 255, blue: 0x35 / 255)
    static let fg = Color(red: 0xe8 / 255, green: 0xee / 255, blue: 0xf7 / 255)
    static let fgDim = Color(red: 0x9f / 255, green: 0xb0 / 255, blue: 0xc7 / 255)
    static let accent = Color(red: 0xff / 255, green: 0xb7 / 255, blue: 0x03 / 255)
    static let moonLight = Color(red: 0x8e / 255, green: 0xc9 / 255, blue: 0xff / 255)
    static let good = Color(red: 0x7c / 255, green: 0xff / 255, blue: 0x9b / 255)

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

// MARK: - Berechnete Tageswerte für einen Zeitpunkt und Ort

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

        // Tagesverlaufs-Balken (20-Minuten-Raster reicht für kleine Flächen)
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
