import SwiftUI
import UniformTypeIdentifiers

// Hauptansicht „Einträge": Budget-Karten, Tagesliste, Schnelleingabe.

struct EntriesView: View {
    @EnvironmentObject var store: AppStore

    @State private var quickText = ""
    @State private var editorExpense: Expense?
    @State private var showNewEditor = false
    @State private var showTripEditor = false
    @State private var showNewTrip = false
    @State private var showFriends = false
    @State private var showSettings = false
    @State private var shareItems: [Any]?
    @State private var showImporter = false
    @State private var importMessage: String?
    @FocusState private var quickFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            if let trip = store.activeTrip {
                ScrollView {
                    VStack(spacing: 16) {
                        budgetCards(trip)
                        if !store.pendingAutoExpenses.isEmpty {
                            pendingAutoBanner(trip)
                        }
                        entriesList(trip)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 170)
                }
                .scrollDismissesKeyboard(.interactively)
            } else {
                noTripView
            }
        }
        .safeAreaInset(edge: .bottom) { quickAddBar }
        .sheet(item: $editorExpense) { expense in
            EntryEditorView(existing: expense)
        }
        .sheet(isPresented: $showNewEditor) {
            EntryEditorView(existing: nil)
        }
        .sheet(isPresented: $showTripEditor) {
            if let trip = store.activeTrip {
                TripEditorSheet(trip: trip, isNew: false)
            }
        }
        .sheet(isPresented: $showNewTrip) {
            TripEditorSheet(trip: nil, isNew: true)
        }
        .sheet(isPresented: $showFriends) { FriendsSheet() }
        .sheet(isPresented: $showSettings) { SettingsSheet() }
        .sheet(isPresented: Binding(
            get: { shareItems != nil },
            set: { if !$0 { shareItems = nil } }
        )) {
            if let items = shareItems {
                ActivityView(items: items)
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.commaSeparatedText, .text, .plainText],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            if let data = try? Data(contentsOf: url) {
                importMessage = store.importCSV(data: data)
            } else {
                importMessage = "Die Datei konnte nicht gelesen werden."
            }
        }
        .alert("CSV-Import", isPresented: Binding(
            get: { importMessage != nil },
            set: { if !$0 { importMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importMessage ?? "")
        }
    }

    // MARK: - Kopfzeile

    private var header: some View {
        HStack {
            Menu {
                ForEach(store.visibleTrips) { trip in
                    Button {
                        store.activeTripId = trip.id
                    } label: {
                        if trip.id == store.activeTrip?.id {
                            Label(trip.name, systemImage: "checkmark")
                        } else {
                            Text(trip.name)
                        }
                    }
                }
                Divider()
                Button {
                    showNewTrip = true
                } label: {
                    Label("Neue Reise ...", systemImage: "plus")
                }
            } label: {
                HStack(spacing: 8) {
                    Text(store.activeTrip?.name ?? "Kassenbuch")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.textDim)
                }
            }

            Spacer()

            Menu {
                Button { showFriends = true } label: {
                    Label("Freunde hinzufügen", systemImage: "person.badge.plus")
                }
                Button { showTripEditor = true } label: {
                    Label("Reise bearbeiten", systemImage: "pencil")
                }
                Button {
                    if let trip = store.activeTrip, let url = store.exportCSV(trip: trip) {
                        shareItems = [url]
                    }
                } label: {
                    Label("CSV-Export", systemImage: "doc.badge.arrow.up")
                }
                Button {
                    showImporter = true
                } label: {
                    Label("CSV importieren", systemImage: "square.and.arrow.down")
                }
                Button {
                    if let trip = store.activeTrip {
                        shareItems = [store.shareSummary(trip: trip)]
                    }
                } label: {
                    Label("Teilen", systemImage: "square.and.arrow.up")
                }
                Divider()
                Button { showSettings = true } label: {
                    Label("Einstellungen", systemImage: "gearshape")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Theme.card))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    // MARK: - Ohne Reise (neu anlegen oder per Code beitreten)

    private var noTripView: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "suitcase.rolling.fill")
                .font(.system(size: 44))
                .foregroundStyle(Theme.blue)
            Text("Willkommen bei Kassenbuch")
                .font(.title3.bold())
            Text("Lege eine eigene Reise an — oder tritt mit dem Einladungscode einer Reise deiner Familie bei.")
                .font(.subheadline)
                .foregroundStyle(Theme.textDim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            Button {
                showNewTrip = true
            } label: {
                Label("Neue Reise anlegen", systemImage: "plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Capsule().fill(Theme.accent))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 40)
            Button {
                showFriends = true
            } label: {
                Label("Mit Code beitreten", systemImage: "person.badge.key")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Capsule().fill(Theme.card))
                    .foregroundStyle(Theme.textPrimary)
            }
            .padding(.horizontal, 40)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Budget-Karten (Kennzahl pro Karte wählbar)

    private func budgetCards(_ trip: Trip) -> some View {
        HStack(spacing: 12) {
            metricCard(trip: trip, selection: $store.leftCardMetric)
            metricCard(trip: trip, selection: $store.rightCardMetric)
        }
    }

    private func metricCard(trip: Trip, selection: Binding<CardMetric>) -> some View {
        Menu {
            ForEach(CardMetric.allCases) { metric in
                Button {
                    selection.wrappedValue = metric
                } label: {
                    if metric == selection.wrappedValue {
                        Label(metric.menuTitle, systemImage: "checkmark")
                    } else {
                        Text(metric.menuTitle)
                    }
                    if let subtitle = metric.menuSubtitle {
                        Text(subtitle)
                    }
                }
            }
        } label: {
            BudgetCard(
                display: store.metricDisplay(selection.wrappedValue, trip: trip),
                currency: trip.homeCurrency
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Wartende automatische Zahlungen

    private func pendingAutoBanner(_ trip: Trip) -> some View {
        let pending = store.pendingAutoExpenses
        let sum = pending.reduce(0) { $0 + $1.signedAmount * trip.rate(for: $1.currency) }
        return VStack(alignment: .leading, spacing: 10) {
            Label("\(pending.count) automatisch erfasste Zahlung\(pending.count == 1 ? "" : "en") wartet auf Zuordnung", systemImage: "tray.full.fill")
                .font(.subheadline.weight(.semibold))
            Text("Erfasst, während auf diesem Gerät keine Reise sichtbar war — zusammen \(Formatters.money(sum, trip.homeCurrency)).")
                .font(.footnote)
                .foregroundStyle(Theme.textDim)
            HStack {
                Button {
                    store.adoptPendingAutoExpenses(into: trip.id)
                } label: {
                    Text("In „\(trip.name)“ übernehmen")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Theme.accent))
                        .foregroundStyle(.white)
                }
                Button("Verwerfen", role: .destructive) {
                    store.discardPendingAutoExpenses()
                }
                .font(.subheadline)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(Theme.cardSoft)
    }

    // MARK: - Tagesliste

    private func entriesList(_ trip: Trip) -> some View {
        let groups = store.dayGroups(for: store.expenses(for: trip.id), trip: trip)
        return VStack(spacing: 0) {
            if groups.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 34))
                        .foregroundStyle(Theme.textDim)
                    Text("Noch keine Einträge")
                        .font(.headline)
                    Text("Tippe unten etwas ein wie „pizza 13,5 bar“, nutze den Plus-Knopf — oder richte den automatischen Apple-Pay-Import ein (Einstellungen).")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textDim)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 60)
                .frame(maxWidth: .infinity)
            } else {
                ForEach(groups) { group in
                    daySection(group, trip: trip)
                }
            }
        }
    }

    private func daySection(_ group: AppStore.DayGroup, trip: Trip) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(Formatters.dayHeading(group.day))
                    .font(.subheadline)
                    .foregroundStyle(Theme.textDim)
                Spacer()
                Text(Formatters.money(group.sum, trip.homeCurrency))
                    .font(.subheadline)
                    .foregroundStyle(Theme.textDim)
            }
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

    // MARK: - Schnelleingabe

    private var quickAddBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Theme.accent)
                    TextField("z. B. \"pizza 13,5 bar\"", text: $quickText)
                        .focused($quickFocused)
                        .submitLabel(.done)
                        .onSubmit(submitQuickAdd)
                    Button {
                        // Diktat übernimmt die Mikrofontaste der iOS-Tastatur.
                        quickFocused = true
                    } label: {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Theme.accent))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(Theme.card.opacity(0.96)))
                .overlay(Capsule().stroke(Theme.blue.opacity(0.5), lineWidth: 1))

                Button {
                    showNewEditor = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 58, height: 58)
                        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.card.opacity(0.96)))
                        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.separator, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 76)
        }
    }

    private func submitQuickAdd() {
        guard let _ = store.quickAdd(quickText) else { return }
        quickText = ""
    }
}

// MARK: - Bausteine

struct BudgetCard: View {
    let display: AppStore.MetricDisplay
    let currency: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(display.header)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textDim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(Theme.textDim)
            }

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(Formatters.currencySymbol(currency))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.textDim)
                Text(Formatters.plain(display.amount))
                    .font(.system(size: 27, weight: .bold))
                    .foregroundStyle(amountColor)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            if let detail = display.detail {
                Text("\(Formatters.plain(detail.left)) / \(Formatters.plainShort(detail.right))")
                    .font(.footnote)
                    .foregroundStyle(Theme.textDim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Text(display.note ?? " ")
                    .font(.footnote)
                    .foregroundStyle(Theme.textDim.opacity(0.7))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            ProgressBar(fraction: display.fraction ?? 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .cardStyle()
    }

    private var amountColor: Color {
        guard display.coloredAmount else { return Theme.textPrimary }
        return display.amount >= 0 ? Color.green : Theme.accent
    }
}

struct ProgressBar: View {
    /// Anteil 0...1; Werte darüber werden gekappt und rot voll angezeigt.
    let fraction: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.10))
                Capsule()
                    .fill(Theme.accent)
                    .frame(width: max(0, min(1, fraction)) * geo.size.width)
            }
        }
        .frame(height: 7)
    }
}

struct ExpenseRow: View {
    let expense: Expense
    let trip: Trip

    var body: some View {
        HStack(spacing: 12) {
            CategoryBadge(category: expense.category)
            VStack(alignment: .leading, spacing: 3) {
                Text(expense.title)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(expense.category.label)
                    Text("•")
                    Text(expense.payment.label)
                    if !expense.author.isEmpty && expense.author != trip.participants.first {
                        Text("•")
                        Text(expense.author)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(Theme.blue.opacity(0.85))
                .lineLimit(1)
            }
            Spacer(minLength: 8)
            AmountText(expense: expense, trip: trip)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}
