//
//  SpotBriefingView.swift
//  FlightMate
//
//  Pre-Flight-Briefing (PRD Phase 2): eine Karte, 10 Sekunden
//  Lesezeit — bestes Fenster, Legal-Status mit Maximalhöhe, Licht
//  und Wind für genau diesen Spot. Danach verabschiedet die App den
//  Piloten bewusst: Während des Flugs gehört die Aufmerksamkeit dem
//  Luftraum, nicht dem Telefon.
//

import SwiftUI

struct SpotBriefingView: View {
    @EnvironmentObject private var state: AppState
    let spot: Spot

    @State private var days: [DayScore] = []
    @State private var legal: LegalAssessment?
    @State private var isLoading = true

    private var today: DayScore? { days.first }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if isLoading {
                    ProgressView("Briefing wird erstellt …")
                        .padding(.top, 60)
                } else {
                    if let today {
                        windowCard(today)
                    }
                    if let legal {
                        legalCard(legal)
                    }
                    if let today {
                        conditionsCard(today)
                        lightCard(today)
                    }
                    Text("Guten Flug! Während des Flugs gilt: Augen an den Luftraum, nicht ans Telefon.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
            }
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
            .padding()
        }
        .navigationTitle(spot.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        days = (try? await state.days(for: spot.coordinate)) ?? []
        if let profile = state.profile {
            legal = await LegalService.shared.assess(coordinate: spot.coordinate, profile: profile)
        }
    }

    // MARK: Bestes Fenster

    private func windowCard(_ day: DayScore) -> some View {
        VStack(spacing: 8) {
            Text("Heute")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 16) {
                Text("\(day.score)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.scoreColor(day.score))
                VStack(alignment: .leading, spacing: 2) {
                    if let window = day.bestWindow {
                        Text("Bestes Fenster: \(Theme.time(window.start))–\(Theme.time(window.end)) Uhr")
                            .font(.headline)
                        if let hour = day.hours.first(where: { $0.hour.date == window.start }) {
                            Text(hour.verdict.rawValue)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Heute kein lohnendes Flugfenster")
                            .font(.headline)
                    }
                }
            }

            // Bester Tag der Woche, falls heute schwach ist.
            if (day.bestWindow?.score ?? 0) < 7,
               let bestDay = days.max(by: { $0.score < $1.score }),
               bestDay.score >= 7,
               !Calendar.current.isDate(bestDay.date, inSameDayAs: day.date),
               let window = bestDay.bestWindow {
                Label(
                    "Besser: \(Theme.shortDayFormatter.string(from: bestDay.date)), \(Theme.time(window.start))–\(Theme.time(window.end)) Uhr (Score \(bestDay.score))",
                    systemImage: "sparkles"
                )
                .font(.subheadline)
                .foregroundStyle(Theme.scoreColor(bestDay.score))
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: Legal

    private func legalCard(_ legal: LegalAssessment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: legal.verdict == .allowed ? "checkmark.shield.fill"
                      : legal.verdict == .forbidden ? "xmark.shield.fill"
                      : legal.verdict == .conditional ? "exclamationmark.shield.fill" : "questionmark.circle")
                    .foregroundStyle(Theme.verdictColor(legal.verdict))
                Text(legal.verdict.title)
                    .font(.headline)
                Spacer()
                if legal.verdict != .unknown {
                    Text("max. \(legal.maxAltitudeM) m")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            if let first = legal.zones.first {
                Text(first.featureName.map { "\(first.rule.title): \($0)" } ?? first.rule.title)
                    .font(.subheadline)
                if legal.zones.count > 1 {
                    Text("und \(legal.zones.count - 1) weitere Zone(n) — Details im Legal-Check auf der Karte.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if legal.verdict == .unknown {
                Text(legal.sourceNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: Bedingungen im Fenster

    private func conditionsCard(_ day: DayScore) -> some View {
        let referenceHour = day.bestWindow.flatMap { window in
            day.hours.first { $0.hour.date == window.start }
        } ?? day.hours.max { $0.score < $1.score }

        return VStack(alignment: .leading, spacing: 8) {
            Text("Bedingungen im Fenster")
                .font(.headline)
            if let hour = referenceHour {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                    GridRow {
                        Label("Wind in Flughöhe", systemImage: "wind")
                        Text("\(Int(max(hour.hour.windSpeed10Kmh, hour.hour.windSpeed120Kmh))) km/h")
                    }
                    GridRow {
                        Label("Böen", systemImage: "tornado")
                        Text("\(Int(hour.hour.windGusts10Kmh)) km/h")
                    }
                    GridRow {
                        Label("Regenrisiko", systemImage: "cloud.rain")
                        Text("\(Int(hour.hour.precipitationProbability)) %")
                    }
                    GridRow {
                        Label("Temperatur", systemImage: "thermometer.medium")
                        Text("\(Int(hour.hour.temperatureC)) °C")
                    }
                }
                .font(.subheadline)

                if let hint = hour.factors.first(where: { !$0.isPositive }) {
                    Label(hint.text, systemImage: hint.symbol)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: Licht

    private func lightCard(_ day: DayScore) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Licht")
                .font(.headline)
            ForEach(day.sunDay.lightWindows, id: \.self) { window in
                HStack {
                    Image(systemName: window.kind.rawValue.hasPrefix("Blaue") ? "moon.stars" : "sun.horizon")
                        .foregroundStyle(.secondary)
                        .frame(width: 22)
                    Text(window.kind.rawValue)
                        .font(.subheadline)
                    Spacer()
                    Text("\(Theme.time(window.start))–\(Theme.time(window.end))")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
    }
}
