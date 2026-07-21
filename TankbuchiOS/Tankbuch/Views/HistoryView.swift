import SwiftUI
import SwiftData
import MapKit

// Verlauf: alle Tankvorgänge (neueste zuerst). Auf dem iPhone als Liste mit
// Karten-Sheet, auf dem iPad wie in der PWA als übersichtliche Tabelle mit
// darüberliegender Karte. Tippen öffnet die Bearbeitung.

struct HistoryView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]
    @Query(sort: \FuelEntry.date, order: .reverse) private var entries: [FuelEntry]

    @State private var entryToEdit: FuelEntry?
    @State private var entryToDelete: FuelEntry?
    @State private var showMap = false
    @State private var tableSelection: String?

    private var computedById: [String: ComputedEntry] {
        TripMath.computedByEntryId(vehicles: vehicles, entries: entries)
    }

    private var mappableEntries: [FuelEntry] {
        entries.filter { $0.hasCoordinates }
    }

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "Noch keine Einträge",
                        systemImage: "fuelpump",
                        description: Text("Gespeicherte Tankvorgänge erscheinen hier.")
                    )
                } else if horizontalSizeClass == .regular {
                    regularLayout
                } else {
                    compactList
                }
            }
            .navigationTitle("Verlauf")
            .toolbar {
                if horizontalSizeClass != .regular && !mappableEntries.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showMap = true
                        } label: {
                            Label("Karte", systemImage: "map")
                        }
                    }
                }
            }
            .sheet(item: $entryToEdit) { entry in
                NavigationStack {
                    EntryFormView(entryToEdit: entry) {
                        entryToEdit = nil
                    }
                    .navigationTitle("Eintrag bearbeiten")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Abbrechen") { entryToEdit = nil }
                        }
                    }
                }
            }
            .sheet(isPresented: $showMap) {
                NavigationStack {
                    EntryMapContent(entries: mappableEntries) { entry in
                        openEntryFromMapSheet(entry)
                    }
                    .navigationTitle("Tankstellen-Karte")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Fertig") { showMap = false }
                        }
                    }
                }
            }
            .alert("Eintrag löschen?", isPresented: Binding(
                get: { entryToDelete != nil },
                set: { if !$0 { entryToDelete = nil } }
            )) {
                Button("Endgültig löschen", role: .destructive) {
                    if let entry = entryToDelete {
                        modelContext.delete(entry)
                        try? modelContext.save()
                    }
                    entryToDelete = nil
                }
                Button("Abbrechen", role: .cancel) { entryToDelete = nil }
            } message: {
                Text("Dieser Vorgang kann nicht rückgängig gemacht werden.")
            }
        }
    }

    // MARK: iPhone: Liste

    private var compactList: some View {
        let computed = computedById
        return List {
            ForEach(entries) { entry in
                Button {
                    entryToEdit = entry
                } label: {
                    HistoryRow(entry: entry, computed: computed[entry.externalId], vehicle: vehicles.first { $0.externalId == entry.vehicleId })
                }
                .buttonStyle(.plain)
                .swipeActions {
                    Button("Löschen", systemImage: "trash", role: .destructive) {
                        entryToDelete = entry
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: iPad: Karte + Tabelle (wie die PWA)

    private struct TableRow: Identifiable {
        let id: String
        let entry: FuelEntry
        let number: String
        let dateText: String
        let vehicleText: String
        let stationText: String
        let litersText: String
        let flagsText: String
        let totalText: String
        let pricePerLiterText: String
        let distanceText: String
        let odometerText: String
        let intervalText: String
        let consumptionText: String
    }

    private var tableRows: [TableRow] {
        let computed = computedById
        return entries.map { entry in
            let item = computed[entry.externalId]
            let vehicle = vehicles.first { $0.externalId == entry.vehicleId }

            var flags: [String] = [entry.fullTank ? "Vollgetankt" : "Teiltankung"]
            if entry.adBlue { flags.append("AdBlue") }
            if entry.trailer { flags.append("Anhänger") }
            flags.append(TireSeason.from(entry.tireSeason).label)

            return TableRow(
                id: entry.externalId,
                entry: entry,
                number: item.map { String($0.number) } ?? "-",
                dateText: Format.date(entry.date),
                vehicleText: vehicle?.name ?? entry.vehicleName,
                stationText: [entry.stationName, entry.stationPlace].filter { !$0.isEmpty }.joined(separator: "\n"),
                litersText: "\(Format.number(entry.liters, digits: 2)) l",
                flagsText: flags.joined(separator: " · "),
                totalText: Format.currency(entry.totalPrice),
                pricePerLiterText: "\(Format.number(entry.pricePerLiter, digits: 3)) €/l",
                distanceText: item?.trip.distance.map { "\(Format.number($0, digits: 0)) km" } ?? "-",
                odometerText: "\(Format.number(entry.odometer, digits: 0)) km",
                intervalText: item?.intervalConsumption.map { "\(Format.number($0, digits: 1))" } ?? "-",
                consumptionText: item?.trip.consumption.map { "\(Format.number($0, digits: 1))" } ?? "-"
            )
        }
    }

    /// Erst das Karten-Sheet schließen, dann das Bearbeiten-Sheet öffnen –
    /// zwei gleichzeitige Sheet-Übergänge verschluckt SwiftUI sonst.
    private func openEntryFromMapSheet(_ entry: FuelEntry) {
        showMap = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            entryToEdit = entry
        }
    }

    private var regularLayout: some View {
        VStack(spacing: 0) {
            if !mappableEntries.isEmpty {
                EntryMapContent(entries: mappableEntries) { entry in
                    entryToEdit = entry
                }
                .frame(height: 300)
            }

            Table(tableRows, selection: $tableSelection) {
                TableColumn("Nr.") { row in
                    Text(row.number)
                        .monospacedDigit()
                }
                .width(40)

                TableColumn("Datum") { row in
                    Text(row.dateText)
                }
                .width(min: 110, ideal: 130)

                TableColumn("Fahrzeug") { row in
                    Text(row.vehicleText)
                }
                .width(min: 90, ideal: 120)

                TableColumn("Tankstelle") { row in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.entry.stationName)
                        if !row.entry.stationPlace.isEmpty {
                            Text(row.entry.stationPlace)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .width(min: 140, ideal: 200)

                TableColumn("Menge") { row in
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(row.litersText)
                            .monospacedDigit()
                        Text(row.flagsText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .width(min: 110, ideal: 150)

                TableColumn("Preis") { row in
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(row.totalText)
                            .monospacedDigit()
                        Text(row.pricePerLiterText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .width(min: 90, ideal: 110)

                TableColumn("Strecke") { row in
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(row.distanceText)
                            .monospacedDigit()
                        Text(row.odometerText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .width(min: 90, ideal: 110)

                TableColumn("l/100 seit Tanken") { row in
                    Text(row.intervalText)
                        .monospacedDigit()
                }
                .width(min: 70, ideal: 90)

                TableColumn("Verbrauch l/100") { row in
                    Text(row.consumptionText)
                        .monospacedDigit()
                }
                .width(min: 70, ideal: 90)
            }
            .onChange(of: tableSelection) { _, newValue in
                guard let id = newValue,
                      let entry = entries.first(where: { $0.externalId == id }) else { return }
                tableSelection = nil
                entryToEdit = entry
            }
        }
    }
}

private struct HistoryRow: View {
    let entry: FuelEntry
    let computed: ComputedEntry?
    let vehicle: Vehicle?

    private var flagText: String {
        var parts: [String] = [entry.fullTank ? "Vollgetankt" : "Teiltankung"]
        if entry.adBlue {
            if let liters = entry.adBlueLiters {
                parts.append("AdBlue \(Format.number(liters, digits: 2)) l")
            } else {
                parts.append("AdBlue")
            }
        }
        if entry.trailer { parts.append("Anhänger") }
        parts.append(TireSeason.from(entry.tireSeason).label)
        return parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.stationName)
                        .font(.headline)
                    Text("\(Format.date(entry.date)) · \(vehicle?.name ?? entry.vehicleName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let number = computed?.number {
                    Text("#\(number)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 16) {
                metric("\(Format.number(entry.liters, digits: 2)) l", caption: FuelType.label(for: entry.fuelType))
                metric(Format.currency(entry.totalPrice), caption: "\(Format.number(entry.pricePerLiter, digits: 3)) €/l")
                if let distance = computed?.trip.distance {
                    metric("\(Format.number(distance, digits: 0)) km", caption: "\(Format.number(entry.odometer, digits: 0)) km Stand")
                }
                if let consumption = computed?.trip.consumption {
                    metric("\(Format.number(consumption, digits: 1)) l/100", caption: "Verbrauch")
                }
            }

            Text(flagText)
                .font(.caption)
                .foregroundStyle(.secondary)

            if !entry.notes.isEmpty {
                Text(entry.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func metric(_ value: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.subheadline.weight(.medium).monospacedDigit())
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Karte aller Tankvorgänge (Sheet auf iPhone, eingebettet auf iPad)

struct EntryMapContent: View {
    let entries: [FuelEntry]
    /// Antippen der Detailanzeige öffnet den vollständigen Eintrag.
    var onOpenEntry: ((FuelEntry) -> Void)?

    @State private var selectedEntryId: String?

    private var selectedEntry: FuelEntry? {
        entries.first { $0.externalId == selectedEntryId }
    }

    var body: some View {
        Map(initialPosition: initialPosition, selection: $selectedEntryId) {
            ForEach(entries) { entry in
                if let lat = entry.stationLat, let lng = entry.stationLng {
                    Marker(entry.stationName, systemImage: "fuelpump.fill",
                           coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng))
                        .tint(.blue)
                        .tag(entry.externalId)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let entry = selectedEntry {
                Button {
                    onOpenEntry?(entry)
                } label: {
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.stationName)
                                .font(.headline)
                            Text("\(Format.date(entry.date)) · \(Format.number(entry.liters, digits: 2)) l · \(Format.currency(entry.totalPrice))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if onOpenEntry != nil {
                                Text("Antippen für den vollständigen Eintrag")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        Spacer()
                        if onOpenEntry != nil {
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(onOpenEntry == nil)
                .background(.thinMaterial)
            }
        }
    }

    private var initialPosition: MapCameraPosition {
        let coordinates = entries.compactMap { entry -> CLLocationCoordinate2D? in
            guard let lat = entry.stationLat, let lng = entry.stationLng else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
        guard !coordinates.isEmpty else {
            return .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 51.1657, longitude: 10.4515),
                span: MKCoordinateSpan(latitudeDelta: 8, longitudeDelta: 8)
            ))
        }

        let lats = coordinates.map(\.latitude)
        let lngs = coordinates.map(\.longitude)
        let center = CLLocationCoordinate2D(
            latitude: (lats.min()! + lats.max()!) / 2,
            longitude: (lngs.min()! + lngs.max()!) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.02, (lats.max()! - lats.min()!) * 1.4),
            longitudeDelta: max(0.02, (lngs.max()! - lngs.min()!) * 1.4)
        )
        return .region(MKCoordinateRegion(center: center, span: span))
    }
}
