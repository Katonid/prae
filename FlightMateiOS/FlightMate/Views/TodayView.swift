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
    @State private var nowcast: [WeatherService.QuarterForecast] = []
    @State private var current: WeatherService.CurrentConditions?
    @State private var kpIndex: Double?
    @State private var showChecklist = false
    @State private var ringProgress: Double = 0

    private var isWide: Bool { horizontalSizeClass == .regular }

    /// Tageszeit-Gruß für den Kopfbereich über dem Himmelsverlauf.
    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<11: return "Guten Morgen"
        case 11..<18: return "Guten Tag"
        case 18..<23: return "Guten Abend"
        default: return "Gute Nacht"
        }
    }

    /// Die Referenzstunde des Tages (Beginn des besten Fensters).
    private func referenceHour(_ day: DayScore) -> HourScore? {
        if let window = day.bestWindow,
           let hour = day.hours.first(where: { $0.hour.date == window.start }) {
            return hour
        }
        return day.hours.max { $0.score < $1.score }
    }

    /// Die Stunde, in der wir JETZT sind (nur wenn der Tag sie enthält).
    private func currentHour(_ day: DayScore) -> HourScore? {
        let now = Date()
        return day.hours.first(where: {
            now >= $0.hour.date && now < $0.hour.date.addingTimeInterval(3_600)
        })
    }

    /// Kurzname eines Blockier-Grunds fürs „Jetzt"-Etikett.
    private func shortBlockerName(_ symbol: String) -> String {
        switch symbol {
        case "cloud.rain": return "Regen"
        case "wind", "tornado": return "Wind/Böen"
        case "thermometer", "thermometer.snowflake": return "Temperatur"
        case "eye.slash": return "Sicht"
        default: return "blockiert"
        }
    }

    /// Für den Tipp auf den Score: die Stunde, in der wir JETZT sind —
    /// der Nutzer fragt „warum jetzt nur 6?", nicht nach der besten
    /// Stunde des Tages. Außerhalb des Tages: Referenzstunde.
    private func currentOrReferenceHour(_ day: DayScore) -> HourScore? {
        let now = Date()
        if let current = day.hours.first(where: {
            now >= $0.hour.date && now < $0.hour.date.addingTimeInterval(3_600)
        }) {
            return current
        }
        return referenceHour(day)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    if state.plannedLocation != nil {
                        plannedLocationBanner
                    }
                    if let error = state.loadError {
                        errorCard(error)
                    } else if let today = state.today {
                        if isWide {
                            // iPad-Planungslayout: zwei Spalten (PRD F12)
                            HStack(alignment: .top, spacing: 16) {
                                VStack(spacing: 16) {
                                    scoreCard(today)
                                    if nowcast.count >= 4 { nowcastCard }
                                    hourStrip(today)
                                }
                                VStack(spacing: 16) {
                                    if let current { currentCard(current) }
                                    lightCard(today)
                                    windProfileLink
                                    sevenDayLink
                                }
                            }
                        } else {
                            scoreCard(today)
                            if nowcast.count >= 4 { nowcastCard }
                            if let current { currentCard(current) }
                            hourStrip(today)
                            lightCard(today)
                            windProfileLink
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
            // Der Himmel folgt dem echten Sonnenstand am Standort —
            // die Sonnenzeiten sind ohnehin berechnet (SunCalculator).
            .background(SkyBackdrop(sunrise: state.today?.sunDay.sunrise,
                                    sunset: state.today?.sunDay.sunset))
            .navigationTitle("Heute")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            // Der obere Verlauf ist in jeder Phase kräftig gefärbt —
            // helle Titel und Symbole bleiben darauf lesbar.
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showChecklist = true } label: {
                        Image(systemName: "checklist")
                    }
                    .accessibilityLabel("Vorflug-Checkliste")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showChecklist) {
                ChecklistView(extraItems: checklistExtras)
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(item: $factorsHour) { hourScore in
                HourFactorsView(hourScore: hourScore)
                    .presentationDetents([.medium])
            }
            .refreshable {
                await state.refresh()
                await loadNowcast()
            }
            .task { await loadNowcast() }
            .onAppear { state.requestLocation() }
        }
    }

    // MARK: Kopfbereich über dem Himmelsverlauf

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(greeting)
                .font(.system(.largeTitle, design: .rounded).bold())
                .foregroundStyle(.white)
            Text(Theme.dayFormatter.string(from: Date()))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .shadow(color: .black.opacity(0.25), radius: 4, y: 1)
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
    }

    // MARK: Kurzfrist-Blick („Jetzt starten oder kurz warten?")

    private func loadNowcast() async {
        async let quartersTask = try? WeatherService.shared.nowcast(for: state.effectiveLocation)
        async let currentTask = try? WeatherService.shared.current(for: state.effectiveLocation)
        async let kpTask = WeatherService.shared.kpIndex()
        nowcast = (await quartersTask) ?? []
        current = await currentTask
        kpIndex = await kpTask
    }

    /// Dynamische Checklisten-Punkte aus den Live-Daten von heute.
    private var checklistExtras: [ChecklistItem] {
        var extras: [ChecklistItem] = []
        if let kpIndex, kpIndex >= 4 {
            extras.append(ChecklistItem(
                id: "kp", title: "Kompass kalibrieren (KP \(String(format: "%.1f", kpIndex)))",
                subtitle: "Erhöhte Geomagnetik — GPS kann ungenauer sein"))
        }
        if let current, current.temperatureC < 5 {
            extras.append(ChecklistItem(
                id: "cold", title: "Akkus warm halten (aktuell \(String(format: "%.0f", current.temperatureC)) °C)",
                subtitle: "Innentasche statt Rucksack — Kälte kostet Kapazität"))
        }
        return extras
    }

    // MARK: „Aktuell"-Kachelraster (Nutzerwunsch nach App-Vorbild)

    private func currentCard(_ now: WeatherService.CurrentConditions) -> some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        let limit = state.profile?.maxWindKmh ?? 38
        return VStack(alignment: .leading, spacing: 8) {
            Label("Aktuell", systemImage: "gauge.with.needle")
                .font(.subheadline.bold())
            LazyVGrid(columns: columns, spacing: 8) {
                tile(String(format: "%.0f %%", now.cloudCoverPercent), "Wolkendecke")
                tile(String(format: "%.1f km", now.visibilityM / 1000), "Sicht")
                tile(String(format: "%.1f °C", now.temperatureC), "Temperatur")
                tile("\(Int(now.windKmh.rounded())) km/h", "Wind",
                     color: now.windKmh >= limit ? Theme.scoreColor(1) : nil)
                tile("\(Int(now.gustsKmh.rounded())) km/h", "Böen",
                     color: now.gustsKmh >= limit ? Theme.scoreColor(1)
                        : now.gustsKmh >= limit * 0.8 ? Theme.scoreColor(5) : nil)
                windDirectionTile(now.windDirectionDeg)
                tile(String(format: "%.1f mm", now.precipitationMm), "Niederschlag",
                     color: now.precipitationMm > 0 ? Theme.scoreColor(5) : nil)
                tile(String(format: "%.1f °C", now.apparentC), "Gefühlt")
                tile(String(format: "%.0f %%", now.humidityPercent), "Luftfeuchte")
                tile(String(format: "%.1f", now.uvIndex), "UV-Index")
                if let kpIndex {
                    tile(String(format: "%.1f", kpIndex), "KP-Index",
                         color: kpIndex >= 5 ? Theme.scoreColor(1)
                            : kpIndex >= 4 ? Theme.scoreColor(5) : nil)
                }
                if let profile = state.profile {
                    let estimate = BatteryEstimator.estimate(
                        profile: profile, temperatureC: now.temperatureC,
                        windKmh: max(now.windKmh, now.gustsKmh * 0.8))
                    tile(estimate.minutesText, "Akku-Schätzung",
                         color: estimate.minutes < profile.nominalFlightMinutes * 0.75
                            ? Theme.scoreColor(5) : nil)
                }
            }
            if let kpIndex, kpIndex >= 4 {
                Text("Erhöhte Geomagnetik (KP \(String(format: "%.1f", kpIndex))) — GPS kann ungenauer sein; Kompass vor dem Start kalibrieren.")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .flightCard(cornerRadius: 14)
    }

    private func tile(_ value: String, _ label: String, color: Color? = nil) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(color ?? .primary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }

    private func windDirectionTile(_ degrees: Double) -> some View {
        VStack(spacing: 2) {
            // Kompass-Rose (Nutzerwunsch nach App-Vorbild).
            WindCompassView(directionDeg: degrees, size: 38)
            Text("Wind aus \(Theme.compassDirection(degrees))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: Winde-nach-Höhe-Link

    private var windProfileLink: some View {
        NavigationLink {
            WindProfileView()
        } label: {
            HStack {
                Label("Winde nach Höhe", systemImage: "wind")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .flightCard(cornerRadius: 14)
        }
        .buttonStyle(.plain)
    }

    private enum QuarterState {
        case good, caution, blocked

        var color: Color {
            switch self {
            case .good: return Theme.scoreColor(9)
            case .caution: return Theme.scoreColor(5)
            case .blocked: return Theme.scoreColor(1)
            }
        }
    }

    /// Stundenprognose zur Viertelstunde — die 15-Minuten-Daten kennen
    /// nur Bodenwerte, der Höhenwind (120 m) kommt aus der Stunde.
    /// Ohne diesen Blick nach oben sagte der Streifen „beruhigt sich",
    /// während der Score wegen Höhenwind tiefrot blieb (Nutzermeldung).
    private func hourlyForecast(at date: Date) -> HourForecast? {
        for day in state.days {
            if let hour = day.hours.first(where: {
                date >= $0.hour.date && date < $0.hour.date.addingTimeInterval(3_600)
            }) {
                return hour.hour
            }
        }
        return nil
    }

    /// Sieht das 15-Minuten-Radar Regenpausen, wo die Stundenprognose
    /// Regen über die volle Stunde schmiert? Dann erklärt der Streifen
    /// den Unterschied ehrlich, statt dem Verlauf zu „widersprechen"
    /// (Nutzermeldung: Streifen grün, Verlauf rot).
    private var nowcastSeesRainBreaks: Bool {
        nowcast.contains { quarter in
            quarter.precipitationMm < 0.2
                && (hourlyForecast(at: quarter.date)?.precipitationMm ?? 0) >= 0.2
        }
    }

    private func quarterState(_ quarter: WeatherService.QuarterForecast) -> QuarterState {
        guard let profile = state.profile else { return .good }
        let highWind = hourlyForecast(at: quarter.date)?.windSpeed120Kmh ?? 0
        if quarter.gustsKmh >= profile.maxWindKmh || highWind >= profile.maxWindKmh
            || quarter.precipitationMm >= 0.2 {
            return .blocked
        }
        if quarter.gustsKmh >= profile.maxWindKmh * 0.8
            || highWind >= profile.maxWindKmh * 0.8
            || quarter.precipitationMm > 0 {
            return .caution
        }
        return .good
    }

    /// Deterministische Kernaussage — beantwortet die häufigste
    /// Vor-Ort-Frage: jetzt starten oder kurz warten?
    private var nowcastSummary: String {
        let states = nowcast.map(quarterState)
        guard let first = states.first else { return "" }
        if !states.contains(.blocked) {
            if states.allSatisfy({ $0 == .good }) {
                return "Die nächsten 2 Stunden bleiben stabil — freie Fensterwahl."
            }
            return "Flugtauglich, zeitweise böig — Wind-Reserven einplanen."
        }
        if first != .blocked, let firstBlocked = states.firstIndex(of: .blocked) {
            return "Jetzt ist das bessere Fenster — ab \(Theme.time(nowcast[firstBlocked].date)) Uhr wird es kritisch."
        }
        if let firstOpen = states.firstIndex(where: { $0 != .blocked }) {
            return "Kurz warten: ab \(Theme.time(nowcast[firstOpen].date)) Uhr beruhigt es sich."
        }
        return "In den nächsten 2 Stunden keine Beruhigung in Sicht — Böen, Höhenwind oder Regen über der Toleranz."
    }

    private var nowcastCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Nächste 2 Stunden", systemImage: "clock.arrow.2.circlepath")
                .font(.subheadline.bold())
            HStack(spacing: 3) {
                ForEach(Array(nowcast.enumerated()), id: \.offset) { _, quarter in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(quarterState(quarter).color.opacity(0.85))
                        .frame(height: 22)
                        .frame(maxWidth: .infinity)
                }
            }
            HStack {
                Text(Theme.time(nowcast.first?.date ?? Date()))
                Spacer()
                Text(Theme.time(nowcast.last?.date ?? Date()))
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            Text(nowcastSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
            if nowcastSeesRainBreaks {
                Text("Streifen und Tagesverlauf dürfen sich hier unterscheiden: Der Streifen nutzt das 15-Minuten-Radar (sieht Regenpausen scharf), der Verlauf die Stundenprognose (verteilt Regen über die volle Stunde). Für „jetzt gleich“ ist der Streifen die schärfere Quelle.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .flightCard(cornerRadius: 14)
    }

    // MARK: 7-Tage-Link

    private var sevenDayLink: some View {
        NavigationLink {
            ScoreDetailView()
        } label: {
            HStack {
                Label("14-Tage-Ausblick", systemImage: "calendar")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .flightCard(cornerRadius: 14)
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
        .flightCard(cornerRadius: 14)
    }

    // MARK: Kartenort-Banner (Nutzerwunsch)

    /// Deutlicher Hinweis, dass sich ALLE Werte gerade auf einen auf
    /// der Karte gewählten Ort beziehen — mit Rückkehr-Knopf.
    private var plannedLocationBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.and.ellipse")
                .font(.title3)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Werte für: \(plannedLocationLabel)")
                    .font(.subheadline.bold())
                Text("Auf der Karte gewählt — nicht dein Standort.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                state.clearPlannedLocation()
            } label: {
                Label("Mein Standort", systemImage: "location.fill")
                    .font(.caption.bold())
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.16), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.orange.opacity(0.45), lineWidth: 1)
        )
    }

    private var plannedLocationLabel: String {
        if let name = state.plannedLocationName { return name }
        if let planned = state.plannedLocation {
            return String(format: "%.3f, %.3f", planned.latitude, planned.longitude)
        }
        return ""
    }

    // MARK: Score-Karte

    private func scoreCard(_ day: DayScore) -> some View {
        VStack(spacing: 12) {
            if state.plannedLocation != nil {
                Label(plannedLocationLabel, systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if let name = state.locationName {
                Label(name, systemImage: "location")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ZStack {
                Circle()
                    .stroke(Theme.scoreColor(day.score).opacity(0.15), lineWidth: 14)
                Circle()
                    .trim(from: 0, to: ringProgress)
                    .stroke(Theme.scoreColor(day.score), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    // Weicher Schein in der Score-Farbe — der Ring
                    // „leuchtet", ohne die Farbe allein sprechen zu
                    // lassen (Zahl + Text bleiben die Aussage).
                    .shadow(color: Theme.scoreColor(day.score).opacity(0.45), radius: 12)
                VStack(spacing: 0) {
                    Text("\(day.score)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                    Text("von 10")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 160, height: 160)
            .contentShape(Circle())
            .onTapGesture {
                factorsHour = currentOrReferenceHour(day)
            }
            // Der Ring baut sich beim Öffnen federnd bis zum Score auf.
            .onAppear {
                ringProgress = 0
                withAnimation(.spring(response: 1.1, dampingFraction: 0.85).delay(0.15)) {
                    ringProgress = Double(day.score) / 10
                }
            }
            .onChange(of: day.score) { _, newScore in
                withAnimation(.spring(response: 0.7, dampingFraction: 0.85)) {
                    ringProgress = Double(newScore) / 10
                }
            }
            .accessibilityLabel("Flight Score \(day.score) von 10 — antippen für die Begründung")

            Text("Tippe auf den Ring für die Begründung")
                .font(.caption2)
                .foregroundStyle(.secondary)

            // „Jetzt"-Zeile (Nutzermeldung: Ring 6 bei Regen wirkte
            // widersprüchlich — die 6 ist der TAGES-Score der besten
            // Stunde; was JETZT gilt, steht ab sofort direkt hier).
            if let nowHour = currentHour(day) {
                HStack(spacing: 6) {
                    Text("Jetzt: \(nowHour.score)/10")
                        .font(.subheadline.bold())
                        .foregroundStyle(Theme.scoreColor(nowHour.score))
                    if let blocking = nowHour.factors.first(where: \.isBlocking) {
                        Label(shortBlockerName(blocking.symbol), systemImage: blocking.symbol)
                            .font(.caption)
                            .foregroundStyle(Theme.scoreColor(1))
                    }
                }
            }
            if let window = day.bestWindow {
                Text("Bestes Fenster: \(Theme.time(window.start, in: day.timeZone))–\(Theme.time(window.end, in: day.timeZone)) Uhr")
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
        .flightCard(cornerRadius: 20)
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
                        Text(Theme.time(hourScore.hour.date, in: day.timeZone).prefix(2))
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 70, alignment: .bottom)
        }
        .padding()
        .flightCard(cornerRadius: 14)
    }

    // MARK: Licht-Karte

    private func lightCard(_ day: DayScore) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Licht")
                .font(.headline)
            if let sunrise = day.sunDay.sunrise, let sunset = day.sunDay.sunset {
                HStack {
                    Label(Theme.time(sunrise, in: day.timeZone), systemImage: "sunrise")
                    Spacer()
                    Label(Theme.time(sunset, in: day.timeZone), systemImage: "sunset")
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
                    Text("\(Theme.time(window.start, in: day.timeZone))–\(Theme.time(window.end, in: day.timeZone))")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .flightCard(cornerRadius: 14)
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
