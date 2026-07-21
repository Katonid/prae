import SwiftUI
import CoreData
import MapKit

// Tankstellen-Explorer wie in der PWA: Suche per Standort oder Ortsname,
// Karte und Liste mit Livepreisen (Tankerkönig) bzw. Apple-Karten-Treffern,
// sortierbar nach Entfernung oder Preis. Eine Station lässt sich direkt in
// das Eintragsformular übernehmen.

struct StationsView: View {
    @EnvironmentObject private var appModel: AppModel
    @FetchRequest(sortDescriptors: [SortDescriptor(\Vehicle.createdAt)]) private var vehicles: FetchedResults<Vehicle>

    @State private var searchText = ""
    @State private var sortByPrice = false
    @State private var mapPosition: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 51.1657, longitude: 10.4515),
        span: MKCoordinateSpan(latitudeDelta: 8, longitudeDelta: 8)
    ))
    @State private var selectedStationId: String?

    private var fuelType: String {
        vehicles.selected(id: appModel.selectedVehicleId)?.fuelType ?? FuelType.diesel.rawValue
    }

    private var sortedStations: [NearbyStation] {
        guard sortByPrice else {
            return appModel.stations.sorted { $0.distanceKm < $1.distanceKm }
        }
        let fuel = fuelType
        return appModel.stations.sorted {
            let a = $0.price(for: fuel) ?? .greatestFiniteMagnitude
            let b = $1.price(for: fuel) ?? .greatestFiniteMagnitude
            return a == b ? $0.distanceKm < $1.distanceKm : a < b
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                map
                stationList
            }
            .navigationTitle("Tankstellen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await refreshAroundLocation() }
                    } label: {
                        Label("Standort", systemImage: "location.fill")
                    }
                    .disabled(appModel.isLoadingStations)
                }
            }
        }
    }

    private var searchBar: some View {
        VStack(spacing: 8) {
            HStack {
                TextField("Ort oder Adresse suchen", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .onSubmit { Task { await search() } }
                Button("Suchen") {
                    Task { await search() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(appModel.isLoadingStations)
            }

            HStack(spacing: 10) {
                Text("Umkreis \(Format.number(appModel.searchRadiusKm, digits: 0)) km")
                    .font(.footnote.weight(.semibold))
                    .frame(width: 92, alignment: .leading)
                    .monospacedDigit()
                Slider(value: $appModel.searchRadiusKm, in: 1...20) { editing in
                    if !editing {
                        Task { await reloadForRadiusChange() }
                    }
                }
            }

            HStack {
                Text(appModel.stationStatus)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Spacer()
                Picker("Sortierung", selection: $sortByPrice) {
                    Text("Entfernung").tag(false)
                    Text("Preis").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    /// Nach dem Loslassen des Umkreis-Reglers die Suche mit dem neuen Radius
    /// wiederholen (sofern schon ein Suchort existiert).
    private func reloadForRadiusChange() async {
        guard let center = appModel.searchCenter else { return }
        await appModel.loadStations(around: center)
    }

    private var map: some View {
        Map(position: $mapPosition, selection: $selectedStationId) {
            UserAnnotation()
            ForEach(appModel.stations) { station in
                Marker(markerTitle(station), systemImage: "fuelpump.fill", coordinate: station.coordinate)
                    .tint(station.source == "tankerkoenig" ? .green : .blue)
                    .tag(station.id)
            }
        }
        .frame(minHeight: 240, maxHeight: 300)
        .onChange(of: appModel.stations) { _, stations in
            guard let first = stations.first else { return }
            let center = appModel.searchCenter ?? first.coordinate
            let diameter = appModel.searchRadiusKm * 1000 * 2.2
            mapPosition = .region(MKCoordinateRegion(
                center: center,
                latitudinalMeters: diameter,
                longitudinalMeters: diameter
            ))
        }
    }

    private func markerTitle(_ station: NearbyStation) -> String {
        if let price = station.price(for: fuelType) {
            return "\(station.name) \(Format.number(price, digits: 3)) €"
        }
        return station.name
    }

    private var stationList: some View {
        List(sortedStations) { station in
            StationRow(station: station, fuelType: fuelType, isSelected: station.id == selectedStationId) {
                appModel.useStationForEntry(station)
            }
        }
        .listStyle(.plain)
        .overlay {
            if appModel.stations.isEmpty && !appModel.isLoadingStations {
                ContentUnavailableView(
                    "Keine Tankstellen geladen",
                    systemImage: "fuelpump",
                    description: Text("Suche über den Standort-Knopf oder gib einen Ort ein. Mit Tankerkönig-API-Schlüssel (unter „Fahrzeuge“) gibt es Livepreise.")
                )
            }
        }
    }

    private func refreshAroundLocation() async {
        await appModel.refreshStationsAroundCurrentLocation()
        searchText = appModel.searchCenterLabel
    }

    private func search() async {
        await appModel.searchStations(place: searchText)
        if !appModel.searchCenterLabel.isEmpty {
            searchText = appModel.searchCenterLabel
        }
    }
}

private struct StationRow: View {
    let station: NearbyStation
    let fuelType: String
    let isSelected: Bool
    let onUse: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(station.name)
                    .font(.headline)
                if !station.place.isEmpty {
                    Text(station.place)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                HStack(spacing: 8) {
                    Text("\(Format.number(station.distanceKm, digits: 1)) km")
                    if let isOpen = station.isOpen {
                        Text(isOpen ? "geöffnet" : "geschlossen")
                            .foregroundStyle(isOpen ? .green : .red)
                    }
                    Text(station.sourceLabel)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                if let price = station.price(for: fuelType) {
                    Text("\(Format.number(price, digits: 3)) €")
                        .font(.title3.weight(.semibold).monospacedDigit())
                } else {
                    Text("kein Preis")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button("Übernehmen", action: onUse)
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 2)
        .listRowBackground(isSelected ? Color.accentColor.opacity(0.1) : nil)
    }
}
