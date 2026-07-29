//
//  WatchViews.swift
//  HimmelskompassWatch
//
//  Drei vertikal blätterbare Seiten: Sonne, Mond und Nacht (ISS/Milchstraße).
//

import SwiftUI

struct WatchRootView: View {
    @EnvironmentObject private var state: WatchState

    var body: some View {
        TabView {
            SunPage()
            MoonPage()
            NightPage()
        }
        .tabViewStyle(.verticalPage)
        .onAppear { state.start() }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
            // minütlich neu rechnen, damit der Jetzt-Strich mitwandert
            state.objectWillChange.send()
        }
    }
}

// MARK: - Sonne

struct SunPage: View {
    @EnvironmentObject private var state: WatchState

    var body: some View {
        let info = SkyInfo(date: Date(), place: state.place)
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Aufgang").font(.system(size: 11)).foregroundStyle(WColor.fgDim)
                        Text(info.f.time(info.sunTimes.sunrise))
                            .font(.system(size: 22, weight: .bold)).monospacedDigit()
                            .foregroundStyle(WColor.accent)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("Untergang").font(.system(size: 11)).foregroundStyle(WColor.fgDim)
                        Text(info.f.time(info.sunTimes.sunset))
                            .font(.system(size: 22, weight: .bold)).monospacedDigit()
                            .foregroundStyle(WColor.accent)
                    }
                }

                WTimelineBar(info: info)
                    .frame(height: 10)

                row("Tageslänge", info.dayLength, WColor.fg)
                row("Goldene Std.", info.goldenEvening, WColor.golden)
                row("Blaue Std.", info.blueEvening, WColor.blue)
                if let noonDate = info.sunTimes.solarNoon {
                    row("Höchststand", info.f.time(noonDate), WColor.fgDim)
                }

                if let name = state.place.name {
                    Text("📍 " + name)
                        .font(.system(size: 11))
                        .foregroundStyle(WColor.fgDim)
                        .padding(.top, 2)
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("☀️ Sonne")
    }

    private func row(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack {
            Text(label).font(.system(size: 12)).foregroundStyle(WColor.fgDim)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold)).monospacedDigit()
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

// MARK: - Mond

struct MoonPage: View {
    @EnvironmentObject private var state: WatchState

    var body: some View {
        let info = SkyInfo(date: Date(), place: state.place)
        ScrollView {
            VStack(spacing: 5) {
                WMoonPhase(phase: info.illum.phase)
                    .frame(width: 70, height: 70)
                Text(Astro.moonPhaseName(info.illum.phase))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(WColor.fg)
                Text("\(info.moonPercent) % beleuchtet")
                    .font(.system(size: 12))
                    .foregroundStyle(WColor.fgDim)
                Text(info.moonRiseSet)
                    .font(.system(size: 13)).monospacedDigit()
                    .foregroundStyle(WColor.moonLight)
                if let full = nextFullMoon(info: info) {
                    Text("Vollmond: " + info.f.dateTime(full))
                        .font(.system(size: 11))
                        .foregroundStyle(WColor.fgDim)
                }
            }
        }
        .navigationTitle("🌙 Mond")
    }

    /// Nächster Vollmond (stundenweise gesucht, wie in der App)
    private func nextFullMoon(info: SkyInfo) -> Date? {
        var prev = info.illum.phase
        let from = Date()
        for h in 1...(31 * 24) {
            let d = from.addingTimeInterval(Double(h) * 3600)
            let p = Astro.moonIllumination(date: d).phase
            if prev < 0.5 && p >= 0.5 { return d }
            prev = p
        }
        return nil
    }
}

// MARK: - Nacht (ISS und Milchstraße)

struct NightPage: View {
    @EnvironmentObject private var state: WatchState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("🛰️ ISS heute Nacht")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(WColor.fg)
                    Text(state.issLine1)
                        .font(.system(size: 12))
                        .foregroundStyle(state.issGood ? WColor.good : WColor.fgDim)
                    if !state.issLine2.isEmpty {
                        Text(state.issLine2)
                            .font(.system(size: 11))
                            .foregroundStyle(WColor.fgDim)
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(WColor.card2)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text("🌌 Milchstraße")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(WColor.fg)
                    Text(state.mwLine1)
                        .font(.system(size: 12))
                        .foregroundStyle(WColor.fg)
                    if !state.mwLine2.isEmpty {
                        Text(state.mwLine2)
                            .font(.system(size: 11))
                            .foregroundStyle(WColor.fgDim)
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(WColor.card2)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Button {
                    state.locate()
                    state.recomputeNight()
                } label: {
                    Text(state.locating ? "Standort wird ermittelt …" : "📍 Standort aktualisieren")
                        .font(.system(size: 12))
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("🌌 Nacht")
    }
}
