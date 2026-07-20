import SwiftUI

// Reise-Hub: Reiseplan, Karte, Flüge, Kosten, Checklisten, Infos, Fotoalbum.

struct TravelHubView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        NavigationStack {
            List {
                Section("Unterwegs") {
                    NavigationLink { PlanView() } label: {
                        Label("Reiseplan & Stationen", systemImage: "list.bullet.rectangle")
                    }
                    NavigationLink { TripMapView() } label: {
                        Label("Karte, Route & Reise-Spur", systemImage: "map")
                    }
                    NavigationLink { PhotoAlbumView() } label: {
                        Label("Fotoalbum", systemImage: "photo.on.rectangle.angled")
                    }
                }
                Section("Organisation") {
                    NavigationLink { FlightsView() } label: {
                        Label("Flüge", systemImage: "airplane")
                    }
                    if store.isCrew {
                        NavigationLink { CostsView() } label: {
                            Label("Kosten", systemImage: "dollarsign.circle")
                        }
                        NavigationLink { ChecksView() } label: {
                            Label("Checklisten", systemImage: "checklist")
                        }
                    }
                    NavigationLink { TravelInfosView() } label: {
                        Label("Reise-Infos", systemImage: "info.circle")
                    }
                }
            }
            .navigationTitle("Reise")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { SyncStatusDot() }
            }
        }
    }
}

// MARK: - Reiseplan

struct PlanView: View {
    var body: some View {
        List {
            ForEach(Array(TravelData.stations.enumerated()), id: \.element.id) { index, station in
                NavigationLink {
                    StationDetailView(station: station)
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(spacing: 2) {
                            Text("\(index + 1)")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(width: 30, height: 30)
                                .background(Circle().fill(Theme.canadaRed))
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(station.name)
                                .font(.headline)
                            Text("ab \(HomeView.dayLabel(station.date)) · \(station.region)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 4) {
                                ForEach(station.tags.prefix(3), id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Theme.warmBeige)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("Reiseplan")
    }
}

struct StationDetailView: View {
    @EnvironmentObject private var store: AppStore
    let station: Station

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(station.region)
                        .font(.subheadline.weight(.semibold))
                    Text("Ankunft: \(HomeView.dayLabel(station.date))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(station.notes)
                        .font(.body)
                    HStack(spacing: 4) {
                        ForEach(station.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.warmBeige)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Aufgaben") {
                ForEach(Array(station.todos.enumerated()), id: \.offset) { index, todo in
                    let checkId = "todo-\(station.id)-\(index)"
                    Button {
                        if store.isCrew { store.toggleCheck(checkId) }
                    } label: {
                        HStack {
                            Image(systemName: store.isChecked(checkId) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(store.isChecked(checkId) ? Theme.forestGreen : .secondary)
                            Text(todo)
                                .foregroundStyle(.primary)
                                .strikethrough(store.isChecked(checkId))
                            Spacer()
                        }
                    }
                    .disabled(!store.isCrew)
                }
            }

            Section("Karten & Orte") {
                if let url = URL(string: station.mapsUrl) {
                    Link(destination: url) {
                        Label("\(station.name) in Google Maps", systemImage: "mappin.and.ellipse")
                    }
                }
                ForEach(station.relatedLinks) { entry in
                    if let url = URL(string: entry.url) {
                        Link(destination: url) {
                            Label(entry.title, systemImage: "arrow.up.right.square")
                        }
                    }
                }
            }
        }
        .navigationTitle(station.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Flüge

struct FlightsView: View {
    var body: some View {
        List {
            ForEach(TravelData.flights) { flight in
                Section(flight.direction) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(flight.fromCode)
                                    .font(.title.bold())
                                Text(flight.fromCity)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(spacing: 2) {
                                Image(systemName: "airplane")
                                    .foregroundStyle(Theme.canadaRed)
                                Text(flight.flightNumber)
                                    .font(.caption.weight(.semibold))
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text(flight.toCode)
                                    .font(.title.bold())
                                Text(flight.toCity)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Text("\(HomeView.dayLabel(flight.date)) · \(flight.airline)\(flight.operatedBy != flight.airline ? " · durchgeführt von \(flight.operatedBy)" : "")")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        if !flight.codeshareNote.isEmpty {
                            Text(flight.codeshareNote)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

                    ForEach(flight.linkItems) { link in
                        if let url = URL(string: link.url) {
                            Link(destination: url) {
                                Label(link.title, systemImage: "arrow.up.right.square")
                                    .font(.subheadline)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Flüge")
    }
}

// MARK: - Reise-Infos

struct TravelInfosView: View {
    var body: some View {
        List {
            ForEach(TravelData.infoSections) { info in
                Section(info.title) {
                    ForEach(info.items, id: \.self) { item in
                        Label(item, systemImage: "checkmark.seal")
                            .font(.subheadline)
                    }
                }
            }
        }
        .navigationTitle("Reise-Infos")
    }
}

// MARK: - Checklisten

struct ChecksView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        List {
            Section("Dokumente") {
                ForEach(Array(TravelData.documents.enumerated()), id: \.offset) { index, document in
                    checkRow(id: "doc-\(index)", title: document)
                }
            }
            ForEach(TravelData.stations) { station in
                Section("Aufgaben \(station.name)") {
                    ForEach(Array(station.todos.enumerated()), id: \.offset) { index, todo in
                        checkRow(id: "todo-\(station.id)-\(index)", title: todo)
                    }
                }
            }
        }
        .navigationTitle("Checklisten")
    }

    private func checkRow(id: String, title: String) -> some View {
        Button {
            store.toggleCheck(id)
        } label: {
            HStack {
                Image(systemName: store.isChecked(id) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(store.isChecked(id) ? Theme.forestGreen : .secondary)
                Text(title)
                    .foregroundStyle(.primary)
                    .strikethrough(store.isChecked(id))
                Spacer()
                if store.isChecked(id), let state = store.data.checks.first(where: { $0.id == id }), !state.doneBy.isEmpty {
                    Text(state.doneBy)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Kosten

struct CostsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showsNewExpense = false

    private var totalCad: Double {
        store.visibleExpenses.reduce(0) { $0 + $1.amountCad }
    }

    private func total(for member: String) -> Double {
        store.visibleExpenses.filter { $0.paidBy == member }.reduce(0) { $0 + $1.amountCad }
    }

    var body: some View {
        List {
            Section("Gesamt") {
                HStack {
                    Text("Ausgaben")
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text(Self.cad(totalCad)).font(.headline)
                        Text(Self.eur(totalCad * TravelData.exchangeRateCadToEur))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                ForEach(TravelData.crewNames, id: \.self) { member in
                    HStack {
                        MemberChip(name: member)
                        Spacer()
                        Text(Self.cad(total(for: member)))
                            .font(.subheadline)
                    }
                }
            }

            Section("Einträge") {
                if store.visibleExpenses.isEmpty {
                    Text("Noch keine Ausgaben erfasst.")
                        .foregroundStyle(.secondary)
                }
                ForEach(store.visibleExpenses) { expense in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(expense.title.isEmpty ? expense.category : expense.title)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(Self.cad(expense.amountCad))
                                .font(.subheadline)
                        }
                        HStack {
                            Text("\(expense.category) · \(expense.paidBy)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(Self.eur(expense.amountEur))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            store.deleteExpense(expense)
                        } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("Kosten")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showsNewExpense = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showsNewExpense) {
            NewExpenseSheet()
        }
    }

    static func cad(_ value: Double) -> String {
        String(format: "%.2f CAD", value)
    }

    static func eur(_ value: Double) -> String {
        String(format: "≈ %.2f €", value)
    }
}

struct NewExpenseSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var category = TravelData.expenseCategories.first ?? "Sonstiges"
    @State private var amountText = ""
    @State private var paidBy = TravelData.crewNames.first ?? "Andreas"

    var body: some View {
        NavigationStack {
            Form {
                TextField("Beschreibung", text: $title)
                Picker("Kategorie", selection: $category) {
                    ForEach(TravelData.expenseCategories, id: \.self) { Text($0) }
                }
                TextField("Betrag in CAD", text: $amountText)
                    .keyboardType(.decimalPad)
                Picker("Bezahlt von", selection: $paidBy) {
                    ForEach(TravelData.crewNames, id: \.self) { Text($0) }
                }
            }
            .navigationTitle("Neue Ausgabe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        var expense = Expense()
                        expense.title = title
                        expense.category = category
                        expense.amountCad = Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
                        expense.paidBy = paidBy
                        expense.day = TravelData.isoDay.string(from: Date())
                        expense.stationId = TravelData.currentStation()?.id ?? ""
                        store.saveExpense(expense)
                        dismiss()
                    }
                    .disabled(Double(amountText.replacingOccurrences(of: ",", with: ".")) == nil)
                }
            }
        }
        .onAppear {
            if TravelData.crewNames.contains(store.deviceUser.name) {
                paidBy = store.deviceUser.name
            }
        }
    }
}
