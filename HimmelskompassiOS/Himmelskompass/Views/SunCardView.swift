//
//  SunCardView.swift
//  Himmelskompass
//
//  Sonnen-Karte: Auf-/Untergang, Tageslänge, Tagesverlaufs-Balken und die
//  Fotografen-Zeiten (blaue/goldene Stunde, Dämmerungen).
//

import SwiftUI

struct SunCardView: View {
    @EnvironmentObject private var state: AppState
    var openAR: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("☀️ Sonne")
                .font(.headline)
                .foregroundStyle(HKColor.fg)

            if let data = state.dayData {
                let f = state.formatters
                let t = data.sunTimes

                HStack(spacing: 8) {
                    bigTime("Aufgang", f.time(t.sunrise))
                    bigTime("Untergang", f.time(t.sunset))
                    bigTime("Tageslänge", data.dayLengthText)
                }

                TimelineBarView(segments: data.timeline, nowFraction: data.nowMarkerFraction)

                timelineLegend

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 16) {
                        morningTable(t, f)
                        eveningTable(t, f)
                    }
                    VStack(spacing: 12) {
                        morningTable(t, f)
                        eveningTable(t, f)
                    }
                }

                Button("📡 AR-Ansicht: Sonne & Mond am Himmel finden", action: openAR)
                    .buttonStyle(HKButtonStyle())
                    .frame(maxWidth: .infinity)

                Text("Sonnenhöchststand: \(f.time(t.solarNoon)) · Alle Zeiten in der Ortszeit des gewählten Ortes (\(f.tzLabel(reference: state.dateAtMinutes(720)))).")
                    .font(.caption2)
                    .foregroundStyle(HKColor.fgDim)
            }
        }
        .hkCard()
    }

    private func bigTime(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(HKColor.fgDim)
            Text(value)
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(HKColor.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(HKColor.card2)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var timelineLegend: some View {
        HStack(spacing: 10) {
            legendItem(HKColor.night, "Nacht")
            legendItem(HKColor.astro, "Astron.")
            legendItem(HKColor.naut, "Nautisch")
            legendItem(HKColor.blue, "Blaue Std.")
            legendItem(HKColor.golden, "Goldene Std.")
            legendItem(HKColor.day, "Tag")
        }
        .frame(maxWidth: .infinity)
    }

    private func legendItem(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(HKColor.fgDim)
        }
    }

    private func morningTable(_ t: SunTimes, _ f: HKFormatters) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Morgens")
                .font(.caption.bold())
                .foregroundStyle(HKColor.fgDim)
                .padding(.bottom, 4)
            TimesRow(label: "Astronomische Dämmerung", value: f.time(t.nightEnd))
            TimesRow(label: "Nautische Dämmerung", value: f.time(t.nauticalDawn))
            TimesRow(label: "Bürgerliche Dämmerung", value: f.time(t.dawn))
            TimesRow(label: "Blaue Stunde", value: f.range(t.blueHourDawnStart, t.blueHourDawnEnd), highlight: HKColor.blue)
            TimesRow(label: "Goldene Stunde", value: f.range(t.blueHourDawnEnd, t.goldenHourDawnEnd), highlight: HKColor.golden)
            TimesRow(label: "Sonnenaufgang", value: f.time(t.sunrise), valueColor: HKColor.accent, highlight: HKColor.accent)
        }
        .frame(maxWidth: .infinity)
    }

    private func eveningTable(_ t: SunTimes, _ f: HKFormatters) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Abends")
                .font(.caption.bold())
                .foregroundStyle(HKColor.fgDim)
                .padding(.bottom, 4)
            TimesRow(label: "Sonnenuntergang", value: f.time(t.sunset), valueColor: HKColor.accent, highlight: HKColor.accent)
            TimesRow(label: "Goldene Stunde", value: f.range(t.goldenHourDuskStart, t.blueHourDuskStart), highlight: HKColor.golden)
            TimesRow(label: "Blaue Stunde", value: f.range(t.blueHourDuskStart, t.blueHourDuskEnd), highlight: HKColor.blue)
            TimesRow(label: "Bürgerliche Dämmerung", value: f.time(t.dusk))
            TimesRow(label: "Nautische Dämmerung", value: f.time(t.nauticalDusk))
            TimesRow(label: "Astronomische Dämmerung", value: f.time(t.night))
        }
        .frame(maxWidth: .infinity)
    }
}

/// Tagesverlaufs-Balken: farbige Segmente von Mitternacht bis Mitternacht
struct TimelineBarView: View {
    var segments: [TimelineSegment]
    var nowFraction: Double?

    var body: some View {
        GeometryReader { geo in
            let total = max(1, segments.reduce(0) { $0 + $1.count })
            HStack(spacing: 0) {
                ForEach(segments) { seg in
                    HKColor.timeline(seg.cls)
                        .frame(width: geo.size.width * CGFloat(seg.count) / CGFloat(total))
                }
            }
            .overlay(alignment: .topLeading) {
                if let frac = nowFraction {
                    Rectangle()
                        .fill(.white)
                        .frame(width: 2)
                        .offset(x: geo.size.width * frac - 1)
                }
            }
        }
        .frame(height: 18)
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}
