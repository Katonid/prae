import Foundation
import CoreLocation
import SwiftUI

// Gemeinsamer App-Zustand: Tabs, gefundene Tankstellen und die Übergabe einer
// gewählten Tankstelle aus dem Tankstellen-Tab in das Eintragsformular.

enum AppTab: Hashable {
    case start
    case entry
    case history
    case stations
    case settings
}

@MainActor
final class AppModel: ObservableObject {
    @Published var selectedTab: AppTab = .start

    let location = LocationProvider()

    @Published var stations: [NearbyStation] = []
    @Published var stationStatus = "Noch keine Tankstellen geladen."
    @Published var searchCenter: CLLocationCoordinate2D?
    @Published var searchCenterLabel = ""
    @Published var isLoadingStations = false

    /// Aus dem Tankstellen-Tab übernommene Station für das Formular.
    @Published var prefillStation: NearbyStation?

    /// Fordert das Eintragsformular zum Zurücksetzen auf (nach Speichern etc.).
    @Published var entryFormResetToken = UUID()

    // @AppStorage publiziert in ObservableObjects keine Änderungen,
    // deshalb @Published mit eigener UserDefaults-Persistenz.
    @Published var tankerkoenigApiKey: String {
        didSet { UserDefaults.standard.set(tankerkoenigApiKey, forKey: "tankerkoenigApiKey") }
    }
    @Published var selectedVehicleId: String {
        didSet { UserDefaults.standard.set(selectedVehicleId, forKey: "selectedVehicleId") }
    }

    init() {
        tankerkoenigApiKey = UserDefaults.standard.string(forKey: "tankerkoenigApiKey") ?? ""
        selectedVehicleId = UserDefaults.standard.string(forKey: "selectedVehicleId") ?? ""
    }

    func refreshStationsAroundCurrentLocation() async {
        guard let coordinate = await location.requestLocation() else {
            stationStatus = location.statusText
            return
        }
        searchCenter = coordinate
        searchCenterLabel = "Aktueller Standort"
        await loadStations(around: coordinate)
    }

    func searchStations(place: String) async {
        guard place.trimmingCharacters(in: .whitespaces).count >= 2 else {
            stationStatus = "Ort oder Adresse eingeben."
            return
        }
        stationStatus = "Suchort wird gesucht..."
        guard let result = await StationService.geocode(place: place) else {
            stationStatus = "Suchort nicht gefunden."
            return
        }
        searchCenter = result.coordinate
        searchCenterLabel = result.label
        await loadStations(around: result.coordinate)
    }

    func loadStations(around coordinate: CLLocationCoordinate2D) async {
        isLoadingStations = true
        stationStatus = "Tankstellen werden geladen..."
        defer { isLoadingStations = false }

        let result = await StationService.fetchNearbyStations(
            lat: coordinate.latitude,
            lng: coordinate.longitude,
            apiKey: tankerkoenigApiKey
        )
        stations = result.stations

        if let error = result.error {
            stationStatus = error
        } else if stations.isEmpty {
            stationStatus = "Keine Tankstelle in der Nähe gefunden."
        } else {
            let live = stations.first?.source == "tankerkoenig" ? "mit Livepreisen" : "ohne Livepreise"
            stationStatus = "\(stations.count) Tankstellen \(live)."
        }
    }

    /// Station aus dem Tankstellen-Tab ins Formular übernehmen.
    func useStationForEntry(_ station: NearbyStation) {
        prefillStation = station
        selectedTab = .entry
    }
}
