import SwiftUI
import SwiftData
import MapKit

// Verlauf: alle Tankvorgänge (neueste zuerst) mit den PWA-Spalten, Tippen
// öffnet die Bearbeitung, dazu die Karte aller Tankstellen-Positionen.

struct HistoryView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]
    @Query(sort: \FuelEntry.date, order: .reverse) private var entries: [FuelEntry]

    @State private var entryToEdit: FuelEntry?
    @State private var entryToDelete: FuelEntry?
    @State private var showMap = false

    private var computedById: [String: ComputedEntry] {
        TripMath.computedByEntryId(vehicles: vehicles, entries: entries)
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
                } else {
                    list
                }
            }
            .navigationTitle("Verlauf")
            .toolbar {
                if entries.contains(where: { $0.hasCoordinates }) {
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
                EntryMapSheet(entries: entries.filter { $0.hasCoordinates })
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

    private var list: some View {
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

// MARK: - Karte aller Tankvorgänge

struct EntryMapSheet: View {
    let entries: [FuelEntry]
    @Environment(\.dismiss) private var dismiss

    @State private var selectedEntryId: String?

    private var selectedEntry: FuelEntry? {
        entries.first { $0.externalId == selectedEntryId }
    }

    var body: some View {
        NavigationStack {
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
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.stationName)
                            .font(.headline)
                        Text("\(Format.date(entry.date)) · \(Format.number(entry.liters, digits: 2)) l · \(Format.currency(entry.totalPrice))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.thinMaterial)
                }
            }
            .navigationTitle("Tankstellen-Karte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                }
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
