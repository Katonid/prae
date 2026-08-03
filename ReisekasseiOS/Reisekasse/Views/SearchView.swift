import SwiftUI

// Suche & Filter: Kategorien / Länder / Zahlungsmittel plus Volltextsuche.

struct SearchView: View {
    @EnvironmentObject var store: AppStore

    @State private var searchText = ""
    @State private var filterCategory: ExpenseCategory?
    @State private var filterCountry: String?
    @State private var filterPayment: PaymentMethod?
    @State private var editorExpense: Expense?
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            if let trip = store.activeTrip {
                filterRow(trip)
                results(trip)
            } else {
                Spacer()
            }
        }
        .safeAreaInset(edge: .bottom) { searchBar }
        .sheet(item: $editorExpense) { expense in
            EntryEditorView(existing: expense)
        }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 8) {
                Text(store.activeTrip?.name ?? "Reisekasse")
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

    private func filterRow(_ trip: Trip) -> some View {
        let countries = Set(store.expenses(for: trip.id).compactMap { $0.countryName.nonEmpty }).sorted()

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Menu {
                    Button("Alle Kategorien") { filterCategory = nil }
                    ForEach(ExpenseCategory.allCases) { choice in
                        Button(choice.label) { filterCategory = choice }
                    }
                } label: {
                    chipLabel(filterCategory?.label ?? "Kategorien")
                }
                Menu {
                    Button("Alle Länder") { filterCountry = nil }
                    ForEach(countries, id: \.self) { country in
                        Button(country) { filterCountry = country }
                    }
                } label: {
                    chipLabel(filterCountry ?? "Länder")
                }
                Menu {
                    Button("Alle Zahlungsmittel") { filterPayment = nil }
                    ForEach(PaymentMethod.allCases) { method in
                        Button(method.label) { filterPayment = method }
                    }
                } label: {
                    chipLabel(filterPayment?.label ?? "Zahlungsmittel")
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 8)
    }

    private func chipLabel(_ text: String) -> some View {
        HStack(spacing: 6) {
            Text(text)
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

    private func filtered(_ trip: Trip) -> [Expense] {
        let query = searchText.lowercased().trimmed
        return store.expenses(for: trip.id).filter { expense in
            if let filterCategory, expense.category != filterCategory { return false }
            if let filterCountry, expense.countryName != filterCountry { return false }
            if let filterPayment, expense.payment != filterPayment { return false }
            guard !query.isEmpty else { return true }
            let haystack = [expense.title, expense.note, expense.placeName, expense.countryName, expense.author]
                .joined(separator: " ").lowercased()
            return haystack.contains(query)
        }
    }

    private func results(_ trip: Trip) -> some View {
        let groups = store.dayGroups(for: filtered(trip), trip: trip)
        return ScrollView {
            VStack(spacing: 4) {
                if groups.isEmpty {
                    Text("Keine Treffer")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textDim)
                        .padding(.top, 60)
                } else {
                    ForEach(groups) { group in
                        VStack(spacing: 0) {
                            HStack {
                                Text(Formatters.dayHeading(group.day))
                                Spacer()
                                Text(Formatters.money(group.sum, trip.homeCurrency))
                            }
                            .font(.subheadline)
                            .foregroundStyle(Theme.textDim)
                            .padding(.vertical, 10)

                            VStack(spacing: 0) {
                                ForEach(group.entries.indices, id: \.self) { index in
                                    let expense = group.entries[index]
                                    Button {
                                        editorExpense = expense
                                    } label: {
                                        ExpenseRow(expense: expense, trip: trip)
                                    }
                                    .buttonStyle(.plain)
                                    if index < group.entries.count - 1 {
                                        Divider().overlay(Theme.separator).padding(.leading, 60)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                            .cardStyle()
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 160)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.textDim)
            TextField("Suchen", text: $searchText)
                .focused($searchFocused)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Capsule().fill(Theme.card.opacity(0.96)))
        .overlay(Capsule().stroke(Theme.separator, lineWidth: 1))
        .padding(.horizontal, 14)
        .padding(.bottom, 76)
    }
}
