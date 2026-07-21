import Foundation
import CoreData
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

enum Appearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "Automatisch"
        case .light: return "Hell"
        case .dark: return "Dunkel"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
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
    @Published var appearance: Appearance {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: "appearance") }
    }

    init() {
        tankerkoenigApiKey = UserDefaults.standard.string(forKey: "tankerkoenigApiKey") ?? ""
        selectedVehicleId = UserDefaults.standard.string(forKey: "selectedVehicleId") ?? ""
        appearance = Appearance(rawValue: UserDefaults.standard.string(forKey: "appearance") ?? "") ?? .system
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

        let wo = searchCenterLabel.isEmpty ? "" : " bei „\(searchCenterLabel)“"
        if let error = result.error {
            stationStatus = error
        } else if stations.isEmpty {
            stationStatus = "Keine Tankstelle\(wo) gefunden."
        } else {
            let live = stations.first?.source == "tankerkoenig" ? "mit Livepreisen" : "ohne Livepreise"
            stationStatus = "\(stations.count) Tankstellen\(wo), \(live)."
        }
    }

    /// Station aus dem Tankstellen-Tab ins Formular übernehmen.
    func useStationForEntry(_ station: NearbyStation) {
        prefillStation = station
        selectedTab = .entry
    }

    /// Frisches Formular öffnen (Plus-Button auf der Startseite).
    func startNewEntry() {
        entryFormResetToken = UUID()
        selectedTab = .entry
    }
}

// MARK: - iCloud-Sync-Überwachung

/// Beobachtet die CloudKit-Sync-Ereignisse des NSPersistentCloudKitContainer
/// und stellt das letzte Ergebnis dar.
@MainActor
final class SyncMonitor: ObservableObject {
    @Published var lastEventText = "Noch keine Synchronisierung beobachtet."
    @Published var lastEventWasError = false

    private var observer: NSObjectProtocol?

    init() {
        observer = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event,
                  let endDate = event.endDate else { return }

            let kind: String
            switch event.type {
            case .setup: kind = "Einrichtung"
            case .import: kind = "Empfangen"
            case .export: kind = "Senden"
            @unknown default: kind = "Synchronisierung"
            }

            let text: String
            if event.succeeded {
                text = "\(kind) erfolgreich – \(Format.date(endDate))"
            } else {
                text = "\(kind) fehlgeschlagen – \(Format.date(endDate))"
            }

            Task { @MainActor in
                self?.lastEventText = text
                self?.lastEventWasError = !event.succeeded
            }
        }
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
