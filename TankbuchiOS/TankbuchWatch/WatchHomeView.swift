import SwiftUI
import CoreData

// Übersicht: Fahrzeug wählen, letzter Verbrauch und letzte Tankfüllung,
// großer Tanken-Knopf für die Schnellerfassung.

struct WatchHomeView: View {
    @FetchRequest(sortDescriptors: [SortDescriptor(\Vehicle.createdAt)]) private var vehicles: FetchedResults<Vehicle>
    @FetchRequest(sortDescriptors: [SortDescriptor(\FuelEntry.date, order: .reverse)]) private var entries: FetchedResults<FuelEntry>
    @AppStorage("watchSelectedVehicleId") private var selectedVehicleId = ""
    @State private var showQuickEntry = false

    private var vehicle: Vehicle? {
        vehicles.selected(id: selectedVehicleId)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let vehicle {
                    content(for: vehicle)
                } else {
                    Text("Lege zuerst am iPhone ein Fahrzeug an – die Daten kommen automatisch über iCloud.")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }
            .navigationTitle("Tankbuch")
            .sheet(isPresented: $showQuickEntry) {
                if let vehicle {
                    QuickEntryView(vehicle: vehicle)
                }
            }
        }
    }

    private func content(for vehicle: Vehicle) -> some View {
        let vehicleEntries = entries.filter { $0.vehicleId == vehicle.externalId }
        let lastEntry = vehicleEntries.first
        let consumption = TripMath.lastConsumption(for: vehicle, entries: Array(entries))

        return ScrollView {
            VStack(spacing: 10) {
                if vehicles.count > 1 {
                    Picker("Fahrzeug", selection: Binding(
                        get: { vehicle.externalId },
                        set: { selectedVehicleId = $0 }
                    )) {
                        ForEach(vehicles) { item in
                            Text(item.name).tag(item.externalId)
                        }
                    }
                    .pickerStyle(.navigationLink)
                } else {
                    Text(vehicle.displayName)
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                statRow(
                    title: "Letzter Verbrauch",
                    value: consumption.map { "\(Format.number($0, digits: 1)) l/100 km" } ?? "–"
                )

                if let lastEntry {
                    statRow(
                        title: "Zuletzt getankt",
                        value: "\(Format.number(lastEntry.liters, digits: 1)) l · \(Format.currency(lastEntry.totalPrice))",
                        detail: Format.date(lastEntry.date)
                    )
                } else {
                    statRow(title: "Zuletzt getankt", value: "Noch kein Eintrag")
                }

                Button {
                    showQuickEntry = true
                } label: {
                    Label("Tanken", systemImage: "fuelpump.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }

    private func statRow(title: String, value: String, detail: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.footnote.weight(.semibold))
            if let detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }
}
