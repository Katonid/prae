//
//  MoonCardView.swift
//  Himmelskompass
//
//  Mond-Karte: Phasengrafik, Beleuchtungsgrad, Auf-/Untergang, Entfernung
//  sowie nächster Voll- und Neumond.
//

import SwiftUI

struct MoonCardView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🌙 Mond")
                .font(.headline)
                .foregroundStyle(HKColor.fg)

            if let data = state.dayData {
                let f = state.formatters
                let times = data.moonTimes

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 20) {
                        moonVisual(data)
                        moonTable(data, times, f)
                    }
                    VStack(spacing: 12) {
                        moonVisual(data)
                        moonTable(data, times, f)
                    }
                }
            }
        }
        .hkCard()
    }

    private func moonVisual(_ data: DayData) -> some View {
        VStack(spacing: 4) {
            MoonPhaseView(phase: data.moonIllum.phase)
                .frame(width: 130, height: 130)
            Text(Astro.moonPhaseName(data.moonIllum.phase))
                .font(.subheadline.bold())
                .foregroundStyle(HKColor.fg)
            Text("\(Int((data.moonIllum.fraction * 100).rounded())) % beleuchtet")
                .font(.caption)
                .foregroundStyle(HKColor.fgDim)
        }
        .frame(maxWidth: .infinity)
    }

    private func moonTable(_ data: DayData, _ times: MoonTimes, _ f: HKFormatters) -> some View {
        let riseText = times.alwaysUp ? "ganztägig sichtbar"
            : times.alwaysDown ? "nicht sichtbar"
            : (times.rise != nil ? f.time(times.rise) : "– (kein Aufgang)")
        let setText = (times.alwaysUp || times.alwaysDown) ? "–"
            : (times.set != nil ? f.time(times.set) : "– (kein Untergang)")
        let distText = Self.kmFormatter.string(from: NSNumber(value: Int(data.moonDistanceKm.rounded()))) ?? "–"

        return VStack(alignment: .leading, spacing: 0) {
            TimesRow(label: "Mondaufgang", value: riseText)
            TimesRow(label: "Monduntergang", value: setText)
            TimesRow(label: "Entfernung", value: distText + " km")
            TimesRow(label: "Nächster Vollmond", value: f.dateTime(data.nextFullMoon))
            TimesRow(label: "Nächster Neumond", value: f.dateTime(data.nextNewMoon))
        }
        .frame(maxWidth: .infinity)
    }

    private static let kmFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "de_DE")
        return f
    }()
}

/// Mondphasen-Grafik: dunkle Scheibe, beleuchtete Hälfte und Terminator-Ellipse
/// (0 = Neumond, 0.5 = Vollmond); rechts hell bei zunehmendem Mond.
struct MoonPhaseView: View {
    var phase: Double

    private let darkColor = Color(red: 0x23 / 255, green: 0x2b / 255, blue: 0x3a / 255)
    private let lightColor = Color(red: 0xf5 / 255, green: 0xf0 / 255, blue: 0xdc / 255)
    private let rimColor = Color(red: 0x3a / 255, green: 0x4a / 255, blue: 0x63 / 255)
    private let craterColor = Color(red: 0x8d / 255, green: 0x84 / 255, blue: 0x68 / 255)

    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height
            let cx = w / 2
            let cy = h / 2
            let r = min(w, h) / 2 - 4

            // dunkle Mondscheibe
            let disc = Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r))
            ctx.fill(disc, with: .color(darkColor))
            ctx.stroke(disc, with: .color(rimColor), lineWidth: 1.5)

            let waxing = phase <= 0.5
            let semiX = r * cos(2 * .pi * phase) // Terminator-Halbachse

            ctx.drawLayer { layer in
                layer.clip(to: disc)

                // beleuchtete Hälfte (rechts bei zunehmendem, links bei abnehmendem Mond)
                var half = Path()
                half.addArc(center: CGPoint(x: cx, y: cy), radius: r,
                            startAngle: .degrees(-90), endAngle: .degrees(90),
                            clockwise: !waxing)
                half.closeSubpath()
                layer.fill(half, with: .color(lightColor))

                // Terminator-Ellipse: hell bei "gibbous", dunkel bei Sichel
                let ellipse = Path(ellipseIn: CGRect(x: cx - abs(semiX), y: cy - r,
                                                     width: 2 * abs(semiX), height: 2 * r))
                layer.fill(ellipse, with: .color(semiX < 0 ? lightColor : darkColor))

                // dezente "Krater" andeuten
                let craters: [(Double, Double, Double)] = [
                    (-0.3, -0.25, 0.16), (0.25, 0.1, 0.11), (-0.05, 0.35, 0.09), (0.4, -0.35, 0.07)
                ]
                for (dx, dy, dr) in craters {
                    let crater = Path(ellipseIn: CGRect(
                        x: cx + dx * r - dr * r, y: cy + dy * r - dr * r,
                        width: 2 * dr * r, height: 2 * dr * r))
                    layer.fill(crater, with: .color(craterColor.opacity(0.12)))
                }
            }
        }
    }
}
