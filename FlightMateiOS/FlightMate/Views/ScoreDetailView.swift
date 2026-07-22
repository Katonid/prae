//
//  ScoreDetailView.swift
//  FlightMate
//
//  7-Tage-Ausblick mit erklärbaren Stunden-Scores. Jede Zahl kann
//  ihre Begründung zeigen (PRD Kap. 12: der Score ist ein erklärbares
//  Regelwerk, kein Orakel).
//

import SwiftUI

struct ScoreDetailView: View {
    @EnvironmentObject private var state: AppState
    @State private var selectedHour: HourScore?

    var body: some View {
        List {
            ForEach(state.days) { day in
                Section {
                    if let window = day.bestWindow {
                        HStack {
                            Label("Bestes Fenster", systemImage: "star.fill")
                                .font(.subheadline)
                                .foregroundStyle(Theme.scoreColor(window.score))
                            Spacer()
                            Text("\(Theme.time(window.start))–\(Theme.time(window.end)) Uhr")
                                .font(.subheadline.monospacedDigit())
                        }
                    } else {
                        Label("Kein lohnendes Flugfenster", systemImage: "xmark.circle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(daylightHours(day)) { hourScore in
                        Button {
                            selectedHour = hourScore
                        } label: {
                            HStack {
                                Text("\(Theme.time(hourScore.hour.date))")
                                    .font(.subheadline.monospacedDigit())
                                    .frame(width: 48, alignment: .leading)
                                Text("\(hourScore.score)")
                                    .font(.subheadline.bold().monospacedDigit())
                                    .foregroundStyle(Theme.scoreColor(hourScore.score))
                                    .frame(width: 24)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Theme.scoreColor(hourScore.score))
                                    .frame(width: CGFloat(hourScore.score) * 10, height: 6)
                                Spacer()
                                Image(systemName: "info.circle")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    HStack {
                        Text(Theme.dayFormatter.string(from: day.date))
                        Spacer()
                        Text("Score \(day.score)")
                            .foregroundStyle(Theme.scoreColor(day.score))
                    }
                }
            }
        }
        .navigationTitle("7-Tage-Ausblick")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedHour) { hourScore in
            HourFactorsView(hourScore: hourScore)
                .presentationDetents([.medium])
        }
    }

    /// Nur fotografisch relevante Stunden zeigen (ab blauer Stunde
    /// morgens bis blauer Stunde abends) — die Nacht verrauscht die
    /// Liste ohne Mehrwert.
    private func daylightHours(_ day: DayScore) -> [HourScore] {
        let location = state.effectiveLocation
        return day.hours.filter {
            SunCalculator.position(at: $0.hour.date,
                                   latitude: location.latitude,
                                   longitude: location.longitude).altitude > -10
        }
    }
}

/// Faktoren-Blatt: WARUM ist der Score so?
struct HourFactorsView: View {
    let hourScore: HourScore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(hourScore.score)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.scoreColor(hourScore.score))
                VStack(alignment: .leading) {
                    Text(hourScore.verdict.rawValue)
                        .font(.headline)
                    Text("\(Theme.time(hourScore.hour.date)) Uhr")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if hourScore.factors.isEmpty {
                Label("Keine Einschränkungen — beste Voraussetzungen.", systemImage: "checkmark.circle")
                    .font(.subheadline)
            } else {
                ForEach(hourScore.factors) { factor in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: factor.symbol)
                            .foregroundStyle(factor.isBlocking ? .red : (factor.isPositive ? .green : .orange))
                            .frame(width: 24)
                        Text(factor.text)
                            .font(.subheadline)
                    }
                }
            }

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                GridRow {
                    Text("Wind (Boden)")
                    Text("\(Int(hourScore.hour.windSpeed10Kmh)) km/h")
                }
                GridRow {
                    Text("Wind (120 m)")
                    Text("\(Int(hourScore.hour.windSpeed120Kmh)) km/h")
                }
                GridRow {
                    Text("Böen")
                    Text("\(Int(hourScore.hour.windGusts10Kmh)) km/h")
                }
                GridRow {
                    Text("Regenrisiko")
                    Text("\(Int(hourScore.hour.precipitationProbability)) %")
                }
                GridRow {
                    Text("Temperatur")
                    Text("\(Int(hourScore.hour.temperatureC)) °C")
                }
                GridRow {
                    Text("Sicht")
                    Text("\(Int(hourScore.hour.visibilityM / 1000)) km")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(24)
    }
}
