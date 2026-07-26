//
//  WindProfileView.swift
//  FlightMate
//
//  „Winde nach Höhe" (Nutzerwunsch nach Vorbild klassischer
//  Drohnenwetter-Apps): stündliche Tabelle mit Windrichtung und
//  -geschwindigkeit auf 10 m, 80 m, 120 m und 180 m — aus den
//  Open-Meteo-Modellwinden, bewertet gegen die Windtoleranz des
//  Drohnenprofils (grün/orange/rot). Der Pfeil zeigt, WOHIN der
//  Wind weht.
//

import SwiftUI

struct WindProfileView: View {
    @EnvironmentObject private var state: AppState
    @State private var selectedDayIndex = 0

    private var selectedDay: DayScore? {
        state.days.indices.contains(selectedDayIndex) ? state.days[selectedDayIndex] : state.days.first
    }

    private let levels: [(label: String, speed: (HourForecast) -> Double?, direction: (HourForecast) -> Double?)] = [
        ("10 m", { $0.windSpeed10Kmh }, { $0.windDirectionDeg }),
        ("80 m", { $0.windSpeed80Kmh }, { $0.windDirection80Deg }),
        ("120 m", { $0.windSpeed120Kmh }, { $0.windDirection120Deg ?? $0.windDirectionDeg }),
        ("180 m", { $0.windSpeed180Kmh }, { $0.windDirection180Deg }),
    ]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 12) {
                    if state.days.count > 1 {
                        dayPicker
                    }
                    if let day = selectedDay {
                        // Kopfzeile bleibt beim Scrollen stehen
                        // (Nutzerwunsch): angepinnter Section-Header.
                        LazyVStack(spacing: 8, pinnedViews: [.sectionHeaders]) {
                            Section {
                                ForEach(day.hours, id: \.hour.date) { hourScore in
                                    row(hourScore.hour, timeZone: day.timeZone)
                                        .id(hourScore.hour.date)
                                }
                                Text("Pfeil = wohin der Wind weht · Farbe gegen die Windtoleranz deiner \(state.profile?.name ?? "Drohne") (\(Int(state.profile?.maxWindKmh ?? 38)) km/h): grün = frei, orange = grenzwertig (ab 80 %), rot = darüber. Modellwind Open-Meteo; Böen am Boden können höher liegen.")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 4)
                            } header: {
                                header
                                    .padding(.vertical, 8)
                                    .background(.bar)
                            }
                        }
                    } else {
                        ProgressView()
                            .padding(.top, 60)
                    }
                }
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
                .padding()
            }
            .navigationTitle("Winde nach Höhe")
            .navigationBarTitleDisplayMode(.inline)
            // Beim Öffnen zur aktuellen Stunde springen (Nutzerwunsch) —
            // auch wenn die Prognose erst kurz danach eintrifft.
            .onAppear { scrollToNow(proxy) }
            .onChange(of: state.days.count) { scrollToNow(proxy) }
            .onChange(of: selectedDayIndex) { _, newIndex in
                if newIndex == 0 { scrollToNow(proxy) }
            }
        }
    }

    /// Zur Zeile der laufenden Stunde scrollen (nur für heute sinnvoll).
    private func scrollToNow(_ proxy: ScrollViewProxy) {
        guard selectedDayIndex == 0, let day = selectedDay else { return }
        let now = Date()
        guard let current = day.hours.first(where: {
            now < $0.hour.date.addingTimeInterval(3_600)
        }) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation {
                proxy.scrollTo(current.hour.date, anchor: .top)
            }
        }
    }

    private var dayPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(state.days.enumerated()), id: \.offset) { index, day in
                    Button {
                        selectedDayIndex = index
                    } label: {
                        Text(Theme.shortDay(day.date, in: day.timeZone))
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                index == selectedDayIndex ? Color.accentColor.opacity(0.18) : Color.gray.opacity(0.12),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Zeit")
                .frame(width: 52, alignment: .leading)
            ForEach(levels, id: \.label) { level in
                Text(level.label)
                    .frame(maxWidth: .infinity)
            }
        }
        .font(.caption.bold())
        .foregroundStyle(.secondary)
    }

    private func row(_ hour: HourForecast, timeZone: TimeZone) -> some View {
        let now = Date()
        let isCurrentHour = now >= hour.date && now < hour.date.addingTimeInterval(3_600)
        return HStack {
            Text(Theme.time(hour.date, in: timeZone))
                .font(.caption.monospacedDigit())
                .frame(width: 52, alignment: .leading)
            ForEach(levels, id: \.label) { level in
                cell(speed: level.speed(hour), direction: level.direction(hour))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 6)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
        // Die laufende Stunde ist dezent markiert — sie ist auch das
        // Sprungziel beim Öffnen.
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.accentColor.opacity(isCurrentHour ? 0.7 : 0),
                              lineWidth: 1.5)
        )
    }

    private func cell(speed: Double?, direction: Double?) -> some View {
        VStack(spacing: 3) {
            if let speed {
                if let direction {
                    // Kompass-Rose (Nutzerwunsch nach App-Vorbild) —
                    // der Pfeil zeigt, wohin der Wind weht.
                    WindCompassView(directionDeg: direction, size: 46,
                                    arrowColor: color(for: speed))
                }
                Text("\(Int(speed.rounded()))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(color(for: speed))
            } else {
                Text("—")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func color(for speedKmh: Double) -> Color {
        let limit = state.profile?.maxWindKmh ?? 38
        if speedKmh >= limit { return Theme.scoreColor(1) }
        if speedKmh >= limit * 0.8 { return Theme.scoreColor(5) }
        return Theme.scoreColor(9)
    }
}
