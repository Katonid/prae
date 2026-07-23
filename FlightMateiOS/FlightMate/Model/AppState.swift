//
//  AppState.swift
//  FlightMate
//
//  Zentraler App-Zustand. Persistenz bewusst minimal (UserDefaults):
//  Drohnenmodell, Spots und Wetter-Cache — mehr Daten braucht das MVP
//  nicht (PRD Kap. 11, Datenminimierung). Kein Account, kein Server-
//  Nutzerprofil.
//

import Foundation
import CoreLocation
import SwiftUI

@MainActor
final class AppState: NSObject, ObservableObject {

    // MARK: Onboarding & Profil

    @Published var droneProfileID: String? {
        didSet { UserDefaults.standard.set(droneProfileID, forKey: "droneProfileID") }
    }

    var profile: DroneProfile? { DroneProfile.profile(for: droneProfileID) }
    var isOnboarded: Bool { profile != nil }

    // MARK: Tab-Steuerung & Entdecken-Ziel

    enum Tab: Hashable { case today, map, discover, spots, review }
    @Published var selectedTab: Tab = .today

    /// Entdecken sucht standardmäßig am eigenen Standort; die Karte
    /// (oder die Ortssuche) kann einen beliebigen Punkt vorgeben —
    /// „Foto-Orte hier entdecken" für die Reiseplanung.
    @Published var discoveryCenter: CLLocationCoordinate2D?
    @Published var discoveryCenterName: String?
    /// Zähler statt Equatable-Koordinate: Jede Änderung stößt im
    /// Entdecken-Tab eine neue Suche an.
    @Published var discoveryRequestID = 0

    func exploreSpots(around coordinate: CLLocationCoordinate2D, name: String? = nil) {
        discoveryCenter = coordinate
        discoveryCenterName = name
        discoveryRequestID += 1
        selectedTab = .discover
        if name == nil {
            Task {
                let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first
                discoveryCenterName = placemark?.locality ?? placemark?.name
            }
        }
    }

    func clearDiscoveryCenter() {
        discoveryCenter = nil
        discoveryCenterName = nil
        discoveryRequestID += 1
    }

    // MARK: Spots

    @Published var spots: [Spot] = [] {
        didSet {
            if let data = try? JSONEncoder().encode(spots) {
                UserDefaults.standard.set(data, forKey: "spots")
            }
        }
    }

    var canAddSpot: Bool { spots.count < Spot.freeTierLimit }

    func addSpot(name: String, coordinate: CLLocationCoordinate2D) {
        guard canAddSpot else { return }
        spots.append(Spot(name: name, coordinate: coordinate))
        Task { await updateSpotNotifications() }
    }

    func removeSpot(_ spot: Spot) {
        spots.removeAll { $0.id == spot.id }
        Task { await updateSpotNotifications() }
    }

    func renameSpot(_ spot: Spot, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let index = spots.firstIndex(where: { $0.id == spot.id }) else { return }
        spots[index].name = trimmed
        Task { await updateSpotNotifications() }
    }

    // MARK: Benachrichtigungen (PRD F4: max. eine pro Tag, Score ≥ 8)

    @Published var notificationsEnabled: Bool = UserDefaults.standard.bool(forKey: "notificationsEnabled") {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled") }
    }
    @Published var notificationsDenied = false

    func setNotifications(_ enabled: Bool) async {
        if enabled {
            let granted = await NotificationPlanner.requestPermission()
            notificationsEnabled = granted
            notificationsDenied = !granted
            if granted { await updateSpotNotifications() }
        } else {
            notificationsEnabled = false
            await NotificationPlanner.cancelAll()
        }
    }

    /// Plant die Spot-Benachrichtigungen anhand frischer 7-Tage-Scores neu.
    func updateSpotNotifications() async {
        guard notificationsEnabled else { return }
        guard !spots.isEmpty else {
            await NotificationPlanner.cancelAll()
            return
        }
        var entries: [(spot: Spot, days: [DayScore])] = []
        for spot in spots {
            if let days = try? await days(for: spot.coordinate) {
                entries.append((spot, days))
            }
        }
        await NotificationPlanner.reschedule(entries: entries)
    }

    // MARK: Standort

    private let locationManager = CLLocationManager()
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var locationDenied = false
    /// Ortsname zum aktuellen Standort (z. B. „Dortmund"), nur Anzeige.
    @Published var locationName: String?

    /// Fallback, solange kein Standort vorliegt (wie Himmelskompass: Berlin).
    var effectiveLocation: CLLocationCoordinate2D {
        currentLocation ?? CLLocationCoordinate2D(latitude: 52.52, longitude: 13.405)
    }

    func requestLocation() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            locationDenied = true
        default:
            locationManager.requestLocation()
        }
    }

    // MARK: Score-Daten

    @Published var days: [DayScore] = []
    @Published var forecastFromCache = false
    @Published var forecastFetchedAt: Date?
    @Published var loadError: String?
    @Published var isLoading = false

    var today: DayScore? {
        days.first { Calendar.current.isDateInToday($0.date) } ?? days.first
    }

    func refresh() async {
        guard let profile else { return }
        isLoading = true
        loadError = nil
        defer { isLoading = false }

        let location = effectiveLocation
        do {
            let (forecast, fromCache) = try await WeatherService.shared.forecast(for: location)
            days = FlightScoreEngine.days(
                forecast: forecast, profile: profile,
                latitude: location.latitude, longitude: location.longitude
            ).filter { $0.date >= Calendar.current.startOfDay(for: Date()) }
            forecastFromCache = fromCache
            forecastFetchedAt = forecast.fetchedAt
            await updateSpotNotifications()
        } catch {
            loadError = "Keine Wetterdaten verfügbar — bitte später erneut versuchen. Ohne verlässliche Daten zeigt FlightMate keinen Score an."
        }
    }

    /// Score-Tage für einen beliebigen Ort (Spots, Kartenpunkte).
    func days(for coordinate: CLLocationCoordinate2D) async throws -> [DayScore] {
        guard let profile else { return [] }
        let (forecast, _) = try await WeatherService.shared.forecast(for: coordinate)
        return FlightScoreEngine.days(
            forecast: forecast, profile: profile,
            latitude: coordinate.latitude, longitude: coordinate.longitude
        ).filter { $0.date >= Calendar.current.startOfDay(for: Date()) }
    }

    // MARK: Init

    override init() {
        super.init()
        droneProfileID = UserDefaults.standard.string(forKey: "droneProfileID")
        if let data = UserDefaults.standard.data(forKey: "spots"),
           let stored = try? JSONDecoder().decode([Spot].self, from: data) {
            spots = stored
        }
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }
}

// MARK: CLLocationManagerDelegate

extension AppState: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                self.locationDenied = false
                manager.requestLocation()
            case .denied, .restricted:
                self.locationDenied = true
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let coordinate = location.coordinate
        Task { @MainActor in
            let previous = self.currentLocation
            self.currentLocation = coordinate
            // Neu laden, wenn sich der Ort erstmalig oder deutlich ändert.
            if previous == nil ||
                abs(previous!.latitude - coordinate.latitude) > 0.05 ||
                abs(previous!.longitude - coordinate.longitude) > 0.05 {
                self.updateLocationName(for: location)
                await self.refresh()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Fallback-Ort übernimmt; kein harter Fehler für die UI.
    }
}

extension AppState {
    fileprivate func updateLocationName(for location: CLLocation) {
        Task { @MainActor in
            let placemarks = try? await CLGeocoder().reverseGeocodeLocation(location)
            self.locationName = placemarks?.first?.locality ?? placemarks?.first?.name
        }
    }
}
