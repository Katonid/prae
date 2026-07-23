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
    @ObservedObject private var claude = ClaudeService.shared
    let spot: Spot

    @State private var days: [DayScore] = []
    @State private var legal: LegalAssessment?
    @State private var isLoading = true
    @State private var shotIdeas: [ShotIdea] = []
    @State private var isLoadingIdeas = false
    @State private var ideasError: String?
    @State private var learnings: [ReviewLearning] = []
    @State private var legalFromCache = false
    @State private var selectedDayIndex = 0
    @State private var icsURL: URL?

    /// Der geplante Tag — standardmäßig heute, per Tages-Chips wählbar.
    private var selectedDay: DayScore? {
        days.indices.contains(selectedDayIndex) ? days[selectedDayIndex] : days.first
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if isLoading {
                    ProgressView("Briefing wird erstellt …")
                        .padding(.top, 60)
                } else {
                    if days.count > 1 {
                        dayPicker
                    }
                    if let selectedDay {
                        windowCard(selectedDay)
                    }
                    if let legal {
                        legalCard(legal)
                    }
                    if !learnings.isEmpty {
                        learningCard
                    }
                    if let selectedDay {
                        conditionsCard(selectedDay)
                        lightCard(selectedDay)
                    }
                    if claude.hasKey {
                        ideasCard
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: briefingText) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Briefing teilen")
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    /// Zeitzone des Spots — alle Zeiten im Briefing sind Ortszeit.
    private var briefingTimeZone: TimeZone {
        selectedDay?.timeZone ?? days.first?.timeZone ?? .current
    }

    /// Weicht die Spot-Zeitzone von der Gerätezeit ab? (Reiseplanung)
    private var showsForeignTimeZone: Bool {
        briefingTimeZone.secondsFromGMT() != TimeZone.current.secondsFromGMT()
    }

    private func isToday(_ day: DayScore) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = day.timeZone
        return calendar.isDateInToday(day.date)
    }

    /// Teilbarer Kurztext des Briefings (Teilen-Knopf in der Toolbar).
    private var briefingText: String {
        var lines = ["Drohnen-Briefing: \(spot.name) (FlightMate AI)"]
        if let day = selectedDay {
            lines.append(Theme.fullDay(day.date, in: day.timeZone) + " (Ortszeit des Spots)")
            if let window = day.bestWindow {
                lines.append("Bestes Fenster: \(Theme.time(window.start, in: briefingTimeZone))–\(Theme.time(window.end, in: briefingTimeZone)) Uhr (Ortszeit), Flight Score \(window.score)/10")
            } else {
                lines.append("Kein lohnendes Flugfenster")
            }
        }
        if let legal {
            lines.append("Legal-Check: \(legal.verdict.title), max. \(legal.maxAltitudeM) m")
        }
        return lines.joined(separator: "\n")
    }

    private func updateICS() {
        if let window = selectedDay?.bestWindow {
            icsURL = CalendarExport.icsFile(spotName: spot.name,
                                            latitude: spot.latitude,
                                            longitude: spot.longitude,
                                            window: window)
        } else {
            icsURL = nil
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        days = (try? await state.days(for: spot.coordinate)) ?? []
        learnings = ReviewMemory.recent(2)
        updateICS()
        if let profile = state.profile {
            let live = await LegalService.shared.assess(coordinate: spot.coordinate, profile: profile)
            // Offline-first (PRD Kap. 10): Wenn der Geodienst nicht
            // antwortet, den letzten erfolgreichen Check mit sichtbarem
            // Datenstand zeigen statt „keine Daten".
            if live.verdict == .unknown,
               let cached = LegalCache.assessment(for: spot.id, coordinate: spot.coordinate) {
                legal = cached
                legalFromCache = true
            } else {
                legal = live
                legalFromCache = false
                LegalCache.save(live, spotID: spot.id)
            }
        }
    }

    // MARK: Tages-Auswahl

    private var dayPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                    Button {
                        selectedDayIndex = index
                        shotIdeas = []
                        ideasError = nil
                        updateICS()
                    } label: {
                        VStack(spacing: 2) {
                            Text(isToday(day) ? "Heute" : Theme.shortDay(day.date, in: day.timeZone))
                                .font(.caption)
                            Text("\(day.score)")
                                .font(.headline)
                                .foregroundStyle(Theme.scoreColor(day.score))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            index == selectedDayIndex ? Color.accentColor.opacity(0.18) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Bestes Fenster

    private func windowCard(_ day: DayScore) -> some View {
        VStack(spacing: 8) {
            Text(isToday(day) ? "Heute" : Theme.fullDay(day.date, in: day.timeZone))
                .font(.caption)
                .foregroundStyle(.secondary)
            if showsForeignTimeZone {
                Label("Alle Zeiten in Ortszeit des Spots", systemImage: "clock.badge.exclamationmark")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 16) {
                Text("\(day.score)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.scoreColor(day.score))
                VStack(alignment: .leading, spacing: 2) {
                    if let window = day.bestWindow {
                        Text("Bestes Fenster: \(Theme.time(window.start, in: briefingTimeZone))–\(Theme.time(window.end, in: briefingTimeZone)) Uhr")
                            .font(.headline)
                        if let hour = day.hours.first(where: { $0.hour.date == window.start }) {
                            Text(hour.verdict.rawValue)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("An diesem Tag kein lohnendes Flugfenster")
                            .font(.headline)
                    }
                }
            }

            if let icsURL {
                ShareLink(item: icsURL) {
                    Label("Fenster in Kalender eintragen", systemImage: "calendar.badge.plus")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
            }

            // Bester Tag der Woche, falls heute schwach ist.
            if (day.bestWindow?.score ?? 0) < 7,
               let bestDay = days.max(by: { $0.score < $1.score }),
               bestDay.score >= 7,
               !{ var c = Calendar(identifier: .gregorian); c.timeZone = day.timeZone
                  return c.isDate(bestDay.date, inSameDayAs: day.date) }(),
               let window = bestDay.bestWindow {
                Label(
                    "Besser: \(Theme.shortDay(bestDay.date, in: bestDay.timeZone)), \(Theme.time(window.start, in: bestDay.timeZone))–\(Theme.time(window.end, in: bestDay.timeZone)) Uhr (Score \(bestDay.score))",
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
            // Alle vermuteten Einschränkungen direkt im Briefing
            // (Nutzerwunsch) — mit Klartext, nicht nur die erste Zone.
            ForEach(legal.zones) { hit in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Theme.verdictColor(hit.rule.severity))
                            .frame(width: 8, height: 8)
                        Text(hit.featureName.map { "\(hit.rule.title): \($0)" } ?? hit.rule.title)
                            .font(.subheadline.weight(.medium))
                    }
                    Text(hit.rule.plainText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
            if !legal.uncheckedLayers.isEmpty && legal.verdict != .unknown {
                VStack(alignment: .leading, spacing: 2) {
                    Label("Nicht geprüft: \(legal.uncheckedLayers.joined(separator: ", ")).",
                          systemImage: "exclamationmark.triangle")
                    if let hint = legal.uncheckedHint {
                        Text(hint)
                    }
                }
                .font(.caption)
                .foregroundStyle(.orange)
            }
            if legal.verdict == .unknown {
                Text(legal.sourceNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if legalFromCache {
                Label("Offline — letzter Check vom \(Theme.shortDayFormatter.string(from: legal.checkedAt)), \(Theme.time(legal.checkedAt)) Uhr. Vor dem Start aktualisieren.", systemImage: "wifi.slash")
                    .font(.caption)
                    .foregroundStyle(.orange)
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
                        Text("\(Int(max(hour.hour.windSpeed10Kmh, hour.hour.windSpeed120Kmh))) km/h aus \(Theme.compassDirection(hour.hour.windDirectionDeg))")
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

    // MARK: Lern-Erinnerung (PRD Phase 3 — der Loop schließt sich)

    private var learningCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Aus deinem letzten Flight Review", systemImage: "graduationcap")
                .font(.headline)
            ForEach(learnings) { learning in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb")
                        .foregroundStyle(.orange)
                    Text(learning.text)
                        .font(.subheadline)
                }
            }
            Text("Denk heute beim Fliegen dran.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: Bildideen (PRD F6, KI)

    private var ideasCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Bildideen", systemImage: "sparkles")
                    .font(.headline)
                Spacer()
                if isLoadingIdeas { ProgressView() }
            }
            if shotIdeas.isEmpty && !isLoadingIdeas {
                Button("Bildideen für dieses Licht holen") {
                    Task { await loadShotIdeas() }
                }
                .buttonStyle(.bordered)
            }
            if let ideasError {
                Text(ideasError)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            ForEach(shotIdeas) { idea in
                VStack(alignment: .leading, spacing: 2) {
                    Text(idea.titel)
                        .font(.subheadline.weight(.semibold))
                    Text(idea.idee)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
    }

    private func loadShotIdeas() async {
        isLoadingIdeas = true
        ideasError = nil
        defer { isLoadingIdeas = false }

        var context: [String] = [
            String(format: "Koordinaten: %.4f, %.4f", spot.latitude, spot.longitude),
        ]
        if let selectedDay, let window = selectedDay.bestWindow {
            context.append("Geplanter Tag: \(Theme.dayFormatter.string(from: selectedDay.date))")
            context.append("Bestes Flugfenster: \(Theme.time(window.start, in: briefingTimeZone))–\(Theme.time(window.end, in: briefingTimeZone)) Uhr Ortszeit (Flight Score \(window.score)/10)")
            if let hour = selectedDay.hours.first(where: { $0.hour.date == window.start }) {
                context.append("Licht im Fenster: \(SunCalculator.lightLabel(at: hour.hour.date, latitude: spot.latitude, longitude: spot.longitude))")
                context.append("Wind: \(Int(max(hour.hour.windSpeed10Kmh, hour.hour.windSpeed120Kmh))) km/h aus \(Theme.compassDirection(hour.hour.windDirectionDeg))")
            }
        }
        if let sunset = selectedDay?.sunDay.sunset {
            context.append("Sonnenuntergang: \(Theme.time(sunset, in: briefingTimeZone)) Uhr Ortszeit")
        }
        if let profile = state.profile {
            context.append("Drohne: \(profile.name)")
        }
        // Lern-Loop (PRD F6): frühere Kritikpunkte fließen in die Ideen ein
        // („Du fliegst oft zu hoch — versuch heute 30 m mit Vordergrund").
        let pastLearnings = ReviewMemory.recent(3)
        if !pastLearnings.isEmpty {
            context.append("Frühere Verbesserungsvorschläge aus der Bildkritik des Piloten (beziehe sie ein, wo passend): "
                + pastLearnings.map(\.text).joined(separator: " | "))
        }

        do {
            shotIdeas = try await ClaudeService.shared.shotIdeas(
                spotName: spot.name,
                contextLines: context,
                maxAltitudeM: legal?.maxAltitudeM ?? state.profile?.maxLegalAltitudeM ?? 120
            )
        } catch {
            ideasError = error.localizedDescription
        }
    }

    // MARK: Licht

    private func lightCard(_ day: DayScore) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Licht")
                .font(.headline)
            // Sonnenrichtungen — wichtig für Gegenlicht-/Silhouetten-Planung
            if let sunrise = day.sunDay.sunrise {
                sunDirectionRow(label: "Aufgang", symbol: "sunrise", date: sunrise)
            }
            if let sunset = day.sunDay.sunset {
                sunDirectionRow(label: "Untergang", symbol: "sunset", date: sunset)
            }
            ForEach(day.sunDay.lightWindows, id: \.self) { window in
                HStack {
                    Image(systemName: window.kind.rawValue.hasPrefix("Blaue") ? "moon.stars" : "sun.horizon")
                        .foregroundStyle(.secondary)
                        .frame(width: 22)
                    Text(window.kind.rawValue)
                        .font(.subheadline)
                    Spacer()
                    Text("\(Theme.time(window.start, in: briefingTimeZone))–\(Theme.time(window.end, in: briefingTimeZone))")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
    }

    /// Zeile mit Uhrzeit, Himmelsrichtung und Richtungspfeil der Sonne.
    private func sunDirectionRow(label: String, symbol: String, date: Date) -> some View {
        let azimuth = SunCalculator.position(at: date, latitude: spot.latitude, longitude: spot.longitude).azimuth
        return HStack {
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
                .frame(width: 22)
            Text("\(label) \(Theme.time(date, in: briefingTimeZone)) Uhr aus \(Theme.compassDirection(azimuth))")
                .font(.subheadline)
            Spacer()
            Image(systemName: "location.north.fill")
                .font(.caption)
                .foregroundStyle(.orange)
                .rotationEffect(.degrees(azimuth))
                .accessibilityLabel("Richtung \(Int(azimuth)) Grad")
        }
    }
}
