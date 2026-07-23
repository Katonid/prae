//
//  TodayView.swift
//  FlightMate
//
//  Der Home-Screen (PRD Phase 1): EINE Kernaussage — der Flight Score
//  mit bestem Fenster. Verständlich in unter 5 Sekunden; Details eine
//  Ebene tiefer, nie aufgedrängt.
//

import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showSettings = false
    @State private var factorsHour: HourScore?
    @State private var todaysFeedback = ScoreValidation.todays()

    private var isWide: Bool { horizontalSizeClass == .regular }

    /// Die Referenzstunde des Tages (Beginn des besten Fensters).
    private func referenceHour(_ day: DayScore) -> HourScore? {
        if let window = day.bestWindow,
           let hour = day.hours.first(where: { $0.hour.date == window.start }) {
            return hour
        }
        return day.hours.max { $0.score < $1.score }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let error = state.loadError {
                        errorCard(error)
                    } else if let today = state.today {
                        if isWide {
                            // iPad-Planungslayout: zwei Spalten (PRD F12)
                            HStack(alignment: .top, spacing: 16) {
                                VStack(spacing: 16) {
                                    scoreCard(today)
                                    hourStrip(today)
                                }
                                VStack(spacing: 16) {
                                    lightCard(today)
                                    sevenDayLink
                                }
                            }
                        } else {
                            scoreCard(today)
                            hourStrip(today)
                            lightCard(today)
                            sevenDayLink
                        }
                        feedbackCard(today)
                    } else if state.isLoading {
                        ProgressView("Bedingungen werden geprüft …")
                            .padding(.top, 80)
                    } else {
                        ProgressView()
                            .padding(.top, 80)
                            .task { await state.refresh() }
                    }

                    if state.forecastFromCache, let fetchedAt = state.forecastFetchedAt {
                        Label("Offline — Datenstand \(Theme.time(fetchedAt)) Uhr", systemImage: "wifi.slash")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: isWide ? 1000 : 640)
                .frame(maxWidth: .infinity)
                .padding()
            }
            .navigationTitle("Heute")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(item: $factorsHour) { hourScore in
                HourFactorsView(hourScore: hourScore)
                    .presentationDetents([.medium])
            }
            .refreshable { await state.refresh() }
            .onAppear { state.requestLocation() }
        }
    }

    // MARK: 7-Tage-Link

    private var sevenDayLink: some View {
        NavigationLink {
            ScoreDetailView()
        } label: {
            HStack {
                Label("7-Tage-Ausblick", systemImage: "calendar")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    // MARK: Score-Feedback (PRD Phase 0: Kalibrierung mit echten Flugtagen)

    private func feedbackCard(_ day: DayScore) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Warst du heute draußen?", systemImage: "checkmark.seal")
                .font(.subheadline.bold())
            Text(todaysFeedback == nil
                 ? "Wie gut traf der Score \(day.score) die echten Bedingungen? Deine Ein-Tipp-Rückmeldung kalibriert das Regelwerk."
                 : "Danke — deine Rückmeldung für heute ist gespeichert. Tippen zum Ändern.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(ScoreFeedback.Rating.allCases, id: \.self) { rating in
                    let isSelected = todaysFeedback?.rating == rating
                    Button {
                        ScoreValidation.rate(score: day.score, rating: rating)
                        todaysFeedback = ScoreValidation.todays()
                    } label: {
                        Label(rating.title, systemImage: rating.symbol)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                isSelected ? Color.accentColor.opacity(0.25) : Color.gray.opacity(0.12),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            if let summary = ScoreValidation.summary {
                Text(summary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: Score-Karte

    private func scoreCard(_ day: DayScore) -> some View {
        VStack(spacing: 12) {
            if let name = state.locationName {
                Label(name, systemImage: "location")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ZStack {
                Circle()
                    .stroke(Theme.scoreColor(day.score).opacity(0.15), lineWidth: 14)
                Circle()
                    .trim(from: 0, to: Double(day.score) / 10)
                    .stroke(Theme.scoreColor(day.score), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(day.score)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                    Text("von 10")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 160, height: 160)
            .contentShape(Circle())
            .onTapGesture {
                factorsHour = referenceHour(day)
            }
            .accessibilityLabel("Flight Score \(day.score) von 10 — antippen für die Begründung")

            Text("Tippe auf den Ring für die Begründung")
                .font(.caption2)
                .foregroundStyle(.secondary)

            if let window = day.bestWindow {
                Text("Bestes Fenster: \(Theme.time(window.start))–\(Theme.time(window.end)) Uhr")
                    .font(.headline)
                if let bestHour = day.hours.first(where: { $0.hour.date == window.start }) {
                    Text(bestHour.verdict.rawValue)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Heute kein lohnendes Flugfenster")
                    .font(.headline)
                if let worst = day.hours.first(where: { !$0.factors.filter(\.isBlocking).isEmpty }),
                   let reason = worst.factors.first(where: \.isBlocking) {
                    Text(reason.text)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: Stunden-Übersicht

    private func hourStrip(_ day: DayScore) -> some View {
        let upcoming = day.hours.filter { $0.hour.date >= Date().addingTimeInterval(-3600) }
        return VStack(alignment: .leading, spacing: 8) {
            Text("Verlauf heute")
                .font(.headline)
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(upcoming) { hourScore in
                    VStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Theme.scoreColor(hourScore.score))
                            .frame(height: max(6, CGFloat(hourScore.score) * 5))
                        Text(Theme.timeFormatter.string(from: hourScore.hour.date).prefix(2))
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 70, alignment: .bottom)
        }
        .padding()
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: Licht-Karte

    private func lightCard(_ day: DayScore) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Licht")
                .font(.headline)
            if let sunrise = day.sunDay.sunrise, let sunset = day.sunDay.sunset {
                HStack {
                    Label(Theme.time(sunrise), systemImage: "sunrise")
                    Spacer()
                    Label(Theme.time(sunset), systemImage: "sunset")
                }
                .font(.subheadline)
            }
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
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: Fehler

    private func errorCard(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text(message)
                .font(.callout)
                .multilineTextAlignment(.center)
            Button("Erneut versuchen") {
                Task { await state.refresh() }
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }
}
