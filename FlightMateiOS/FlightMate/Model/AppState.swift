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
    }

    func removeSpot(_ spot: Spot) {
        spots.removeAll { $0.id == spot.id }
    }

    // MARK: Standort

    private let locationManager = CLLocationManager()
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var locationDenied = false

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
                await self.refresh()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Fallback-Ort übernimmt; kein harter Fehler für die UI.
    }
}
