import SwiftUI
import Charts

// Statistiken: Tageskennzahlen, Kategorien-Donut, Trend, Länder, CSV-Export.

struct StatsView: View {
    @EnvironmentObject var store: AppStore

    @State private var filterCategory: ExpenseCategory?
    @State private var filterCountry: String?
    @State private var filterMonth: Date?
    @State private var showRefunds = false
    @State private var showFriends = false
    @State private var shareItems: [Any]?

    var body: some View {
        VStack(spacing: 0) {
            header
            if let trip = store.activeTrip {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        dayMetrics(trip)
                        if !store.friendsBannerDismissed {
                            friendsBanner
                        }
                        chartsSection(trip)
                        participantsSection(trip)
                        trendSection(trip)
                        countriesSection(trip)
                        exportRow(trip)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 120)
                }
            } else {
                Spacer()
            }
        }
        .sheet(isPresented: $showFriends) { FriendsSheet() }
        .sheet(isPresented: Binding(
            get: { shareItems != nil },
            set: { if !$0 { shareItems = nil } }
        )) {
            if let items = shareItems {
                ActivityView(items: items)
            }
        }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 8) {
                Text(store.activeTrip?.name ?? "Kassenbuch")
                    .font(.system(size: 30, weight: .bold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.textDim)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    // MARK: - Tageskennzahlen

    private func dayMetrics(_ trip: Trip) -> some View {
        let today = store.spent(on: Date(), trip: trip)
        let daily = store.dailyBudget(trip)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Tageskennzahlen")
                    .font(.title.bold())
                Spacer()
                Image(systemName: "info.circle")
                    .foregroundStyle(Theme.textDim)
            }
            HStack(spacing: 12) {
                metricCard(
                    title: "Verbleibendes Tagesbudget",
                    value: daily.map { $0 - today },
                    currency: trip.homeCurrency
                )
                metricCard(
                    title: "Bisherige Ausgaben",
                    value: today,
                    currency: trip.homeCurrency
                )
            }
        }
    }

    private func metricCard(title: String, value: Double?, currency: String) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Theme.textDim)
                .lineLimit(1)
            if let value {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(Formatters.currencySymbol(currency))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.textDim)
                    Text(Formatters.plain(value))
                        .font(.system(size: 26, weight: .bold))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
            } else {
                Text("—")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Theme.textDim)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .cardStyle()
    }

    // MARK: - Freunde-Hinweis

    private var friendsBanner: some View {
        Button {
            showFriends = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Theme.blue)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Freunde hinzufügen")
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Text("Verwaltet eure Reisekosten gemeinsam — Zahlungen aller Mitreisenden landen automatisch in dieser Reise.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textDim)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Button {
                    store.friendsBannerDismissed = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.textDim)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Theme.cardSoft))
                }
            }
            .padding(14)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Diagramme (Kategorien-Donut)

    private func filteredExpenses(_ trip: Trip) -> [Expense] {
        store.expenses(for: trip.id).filter { expense in
            if let filterCategory, expense.category != filterCategory { return false }
            if let filterCountry, expense.countryName != filterCountry { return false }
            if let filterMonth {
                let calendar = Calendar.current
                if !calendar.isDate(expense.date, equalTo: filterMonth, toGranularity: .month) { return false }
            }
            if expense.refunded != showRefunds { return false }
            return true
        }
    }

    private func chartsSection(_ trip: Trip) -> some View {
        let list = filteredExpenses(trip)
        let totals = store.categoryTotals(for: list, trip: trip)
        let sum = totals.reduce(0) { $0 + abs($1.value) }
        let countries = Set(store.expenses(for: trip.id).compactMap { $0.countryName.nonEmpty }).sorted()
        let months = store.monthTotals(for: store.expenses(for: trip.id), trip: trip).map { $0.month }

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Diagramme")
                    .font(.title.bold())
                Spacer()
                Button {
                    if let url = store.exportCSV(trip: trip) { shareItems = [url] }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(Theme.textPrimary)
                }
            }

            // Filterzeile
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    filterChip(label: filterCategory?.label ?? "Kategorien") {
                        Button("Alle Kategorien") { filterCategory = nil }
                        ForEach(ExpenseCategory.allCases) { choice in
                            Button(choice.label) { filterCategory = choice }
                        }
                    }
                    filterChip(label: showRefunds ? "Erstattungen" : "Ausgaben") {
                        Button("Ausgaben") { showRefunds = false }
                        Button("Erstattungen") { showRefunds = true }
                    }
                }
                HStack(spacing: 8) {
                    filterChip(label: filterCountry ?? "Alle Länder") {
                        Button("Alle Länder") { filterCountry = nil }
                        ForEach(countries, id: \.self) { country in
                            Button(country) { filterCountry = country }
                        }
                    }
                    filterChip(label: filterMonth.map { Formatters.monthLong($0) } ?? "Alle Monate") {
                        Button("Alle Monate") { filterMonth = nil }
                        ForEach(months, id: \.self) { month in
                            Button(Formatters.monthLong(month)) { filterMonth = month }
                        }
                    }
                }
            }

            if totals.isEmpty {
                Text("Keine Einträge für diese Auswahl.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textDim)
                    .padding(.vertical, 30)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(totals) { entry in
                    SectorMark(
                        angle: .value("Betrag", abs(entry.value)),
                        innerRadius: .ratio(0.58),
                        angularInset: 2
                    )
                    .foregroundStyle(entry.category.color)
                    .cornerRadius(4)
                }
                .frame(height: 260)
                .padding(.vertical, 8)

                VStack(spacing: 0) {
                    ForEach(totals.indices, id: \.self) { index in
                        let entry = totals[index]
                        HStack(spacing: 12) {
                            CategoryBadge(category: entry.category, size: 40)
                            Text(entry.category.label)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(Formatters.plain(abs(entry.value)))
                                    .font(.system(size: 17, weight: .semibold))
                                if sum > 0 {
                                    Text("\(Int((abs(entry.value) / sum * 100).rounded())) %")
                                        .font(.footnote)
                                        .foregroundStyle(Theme.textDim)
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        if index < totals.count - 1 {
                            Divider().overlay(Theme.separator).padding(.leading, 60)
                        }
                    }
                }
                .cardStyle()
            }
        }
    }

    private func filterChip<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        Menu {
            content()
        } label: {
            HStack(spacing: 6) {
                Text(label)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Capsule().fill(Theme.card))
            .overlay(Capsule().stroke(Theme.separator, lineWidth: 1))
        }
    }

    // MARK: - Personen (Ausgaben je Teilnehmer)

    private func personColor(_ index: Int) -> Color {
        let palette: [Color] = [
            Theme.blue,
            Theme.accent,
            Color(red: 0.30, green: 0.75, blue: 0.45),
            Color(red: 0.95, green: 0.75, blue: 0.20),
            Color(red: 0.55, green: 0.40, blue: 0.95),
            Color(red: 0.25, green: 0.75, blue: 0.85),
            Color(red: 0.95, green: 0.55, blue: 0.15),
            Color(red: 0.90, green: 0.45, blue: 0.75),
        ]
        return palette[index % palette.count]
    }

    private func participantsSection(_ trip: Trip) -> some View {
        let persons = store.participantTotals(for: store.expenses(for: trip.id), trip: trip)
        let sum = persons.reduce(0) { $0 + abs($1.value) }

        return VStack(alignment: .leading, spacing: 12) {
            Text("Personen")
                .font(.title.bold())

            if persons.count <= 1 {
                Text(persons.isEmpty
                     ? "Noch keine Daten."
                     : "Bisher hat nur \(persons[0].name) Einträge — mit mehreren Teilnehmern zeigt das Diagramm die Aufteilung.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textDim)
            } else {
                VStack(spacing: 14) {
                    Chart {
                        ForEach(persons.indices, id: \.self) { index in
                            SectorMark(
                                angle: .value("Betrag", abs(persons[index].value)),
                                innerRadius: .ratio(0.58),
                                angularInset: 2
                            )
                            .foregroundStyle(personColor(index))
                            .cornerRadius(4)
                        }
                    }
                    .frame(height: 200)

                    VStack(spacing: 0) {
                        ForEach(persons.indices, id: \.self) { index in
                            let person = persons[index]
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(personColor(index))
                                    .frame(width: 14, height: 14)
                                Text(person.name)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(Formatters.plain(person.value))
                                        .font(.system(size: 17, weight: .semibold))
                                    if sum > 0 {
                                        Text("\(Int((abs(person.value) / sum * 100).rounded())) %")
                                            .font(.footnote)
                                            .foregroundStyle(Theme.textDim)
                                    }
                                }
                            }
                            .padding(.vertical, 10)
                            if index < persons.count - 1 {
                                Divider().overlay(Theme.separator)
                            }
                        }
                    }
                }
                .padding(14)
                .cardStyle()
            }
        }
    }

    // MARK: - Trend

    private func trendSection(_ trip: Trip) -> some View {
        let months = store.monthTotals(for: store.expenses(for: trip.id), trip: trip)

        return VStack(alignment: .leading, spacing: 12) {
            Text("Trend")
                .font(.title.bold())

            if months.isEmpty {
                Text("Noch keine Daten.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textDim)
            } else {
                VStack(spacing: 14) {
                    Chart(months) { entry in
                        BarMark(
                            x: .value("Monat", entry.month, unit: .month),
                            y: .value("Betrag", max(0, entry.value)),
                            width: .fixed(14)
                        )
                        .foregroundStyle(Theme.accent)
                        .cornerRadius(6)
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .month)) { value in
                            AxisValueLabel {
                                if let date = value.as(Date.self) {
                                    Text(Formatters.monthShort(date))
                                        .foregroundStyle(Theme.textDim)
                                }
                            }
                        }
                    }
                    .chartYAxis(.hidden)
                    .frame(height: 150)

                    VStack(spacing: 0) {
                        ForEach(months.indices, id: \.self) { index in
                            let entry = months[index]
                            HStack {
                                Text(Formatters.monthLong(entry.month))
                                Spacer()
                                Text(Formatters.plain(entry.value))
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .padding(.vertical, 10)
                            if index < months.count - 1 {
                                Divider().overlay(Theme.separator)
                            }
                        }
                    }
                }
                .padding(14)
                .cardStyle()
            }
        }
    }

    // MARK: - Länder

    private func countriesSection(_ trip: Trip) -> some View {
        let countries = store.countryTotals(for: store.expenses(for: trip.id), trip: trip)
        let maxValue = countries.map { abs($0.value) }.max() ?? 1

        return VStack(alignment: .leading, spacing: 12) {
            Text("Länder")
                .font(.title.bold())

            if countries.isEmpty {
                Text("Noch keine Daten.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textDim)
            } else {
                VStack(spacing: 0) {
                    ForEach(countries.indices, id: \.self) { index in
                        let entry = countries[index]
                        VStack(spacing: 6) {
                            HStack {
                                Text("\(flagEmoji(countryCode: entry.code)) \(entry.name)")
                                Spacer()
                                Text(Formatters.plain(entry.value))
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            ProgressBar(fraction: maxValue > 0 ? abs(entry.value) / maxValue : 0)
                        }
                        .padding(.vertical, 10)
                        if index < countries.count - 1 {
                            Divider().overlay(Theme.separator)
                        }
                    }
                }
                .padding(14)
                .cardStyle()
            }
        }
    }

    // MARK: - Export

    private func exportRow(_ trip: Trip) -> some View {
        Button {
            if let url = store.exportCSV(trip: trip) { shareItems = [url] }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "doc.badge.arrow.up")
                    .foregroundStyle(Theme.textPrimary)
                Text("Daten als CSV exportieren")
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(Theme.textDim)
            }
            .padding(16)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }
}
