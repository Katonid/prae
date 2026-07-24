//
//  ArchivClusterer.swift
//  FlightMate
//
//  Drone Media Explorer, M4 (Architektur Kap. 7): Reisen und
//  Foto-Spots automatisch erkennen — deterministisch und immer
//  korrigierbar. Reisen: Aufnahmen weiter als 50 km vom „Zuhause"
//  (häufigster Aufnahmeort), getrennt durch Zeitlücken über 48 h;
//  Auto-Name per Reverse-Geocoding („Ontario, Juli 2026").
//  Spots: Radius-Clustering (250 m) über allen verorteten Medien;
//  liegt ein FlightMate-Planungs-Spot in der Nähe, übernimmt der
//  Foto-Spot dessen Namen (Brücke Planung ↔ Archiv). Manuell
//  bearbeitete Namen/Notizen überschreibt die Automatik nie.
//

import Foundation
import CoreLocation
import SwiftData

@MainActor
enum ArchivClusterer {

    /// Kompletter Neuaufbau — läuft nach jedem Import. Bestehende
    /// Reisen/Spots werden wiederverwendet (Zuordnung über Zeitraum
    /// bzw. Nähe), damit manuelle Änderungen erhalten bleiben.
    static func rebuild() async -> String {
        guard let container = ArchivStore.shared.container else { return "" }
        let context = container.mainContext
        guard let assets = try? context.fetch(FetchDescriptor<MediaAsset>(
            sortBy: [SortDescriptor(\.capturedAt)])) else { return "" }
        let located = assets.filter { $0.coordinate != nil }
        guard located.count >= 2 else { return "" }

        // MARK: Zuhause = häufigster Aufnahmeort (0,05°-Raster ≈ 5 km)
        var buckets: [String: (count: Int, lat: Double, lon: Double)] = [:]
        for asset in located {
            guard let lat = asset.latitude, let lon = asset.longitude else { continue }
            let key = String(format: "%.0f_%.0f", lat / 0.05, lon / 0.05)
            var bucket = buckets[key] ?? (0, lat, lon)
            bucket.count += 1
            buckets[key] = bucket
        }
        let home = buckets.values.max { $0.count < $1.count }
        let homeLocation = home.map { CLLocation(latitude: $0.lat, longitude: $0.lon) }

        // MARK: Spots — Radius-Clustering mit stabilen Zentren
        var spots = (try? context.fetch(FetchDescriptor<MediaSpot>())) ?? []
        let planningSpots = loadPlanningSpots()
        var newSpots: [MediaSpot] = []

        for asset in located {
            guard let coordinate = asset.coordinate else { continue }
            let location = CLLocation(latitude: coordinate.latitude,
                                      longitude: coordinate.longitude)
            if let existing = spots.first(where: {
                location.distance(from: CLLocation(latitude: $0.latitude,
                                                   longitude: $0.longitude)) <= $0.radiusM
            }) {
                if asset.spot !== existing { asset.spot = existing }
            } else {
                let spot = MediaSpot()
                spot.latitude = coordinate.latitude
                spot.longitude = coordinate.longitude
                // Brücke zur Planung: naher FlightMate-Spot gibt Namen.
                if let planning = planningSpots
                    .map({ (spot: $0, distance: location.distance(
                        from: CLLocation(latitude: $0.latitude, longitude: $0.longitude))) })
                    .filter({ $0.distance <= 300 })
                    .min(by: { $0.distance < $1.distance }) {
                    spot.name = planning.spot.name
                    spot.linkedPlanningSpotID = planning.spot.id
                }
                context.insert(spot)
                spots.append(spot)
                newSpots.append(spot)
                asset.spot = spot
            }
        }

        // Reverse-Geocoding für neue Spots (begrenzt auf 10 pro Lauf —
        // Apple drosselt sonst): Name (falls kein Planungs-Pate) plus
        // Land/Ort für die Suche („alle Aufnahmen in Kanada").
        var geocoded = 0
        for spot in newSpots where geocoded < 10 {
            geocoded += 1
            let location = CLLocation(latitude: spot.latitude, longitude: spot.longitude)
            let placemark = try? await CLGeocoder()
                .reverseGeocodeLocation(location).first
            spot.country = placemark?.country
            spot.locality = placemark?.locality
            if spot.name.isEmpty {
                spot.name = placemark.flatMap { $0.name ?? $0.locality }
                    ?? String(format: "Spot %.3f, %.3f", spot.latitude, spot.longitude)
            }
        }
        for spot in newSpots where spot.name.isEmpty {
            spot.name = String(format: "Spot %.3f, %.3f", spot.latitude, spot.longitude)
        }

        // MARK: Reisen — Zeitlücken über 48 h, weiter als 50 km weg
        var trips = (try? context.fetch(FetchDescriptor<Trip>())) ?? []
        if let homeLocation {
            let travel = located.filter { asset in
                guard let coordinate = asset.coordinate else { return false }
                return CLLocation(latitude: coordinate.latitude,
                                  longitude: coordinate.longitude)
                    .distance(from: homeLocation) > 50_000
            }
            var groups: [[MediaAsset]] = []
            for asset in travel {
                if var current = groups.last, let last = current.last,
                   asset.capturedAt.timeIntervalSince(last.capturedAt) <= 48 * 3_600 {
                    current.append(asset)
                    groups[groups.count - 1] = current
                } else {
                    groups.append([asset])
                }
            }

            for group in groups where group.count >= 2 {
                guard let first = group.first?.capturedAt,
                      let last = group.last?.capturedAt else { continue }
                let trip: Trip
                if let existing = trips.first(where: {
                    $0.start <= last.addingTimeInterval(86_400)
                        && $0.end >= first.addingTimeInterval(-86_400)
                }) {
                    trip = existing
                    trip.start = min(trip.start, first)
                    trip.end = max(trip.end, last)
                } else {
                    trip = Trip()
                    trip.start = first
                    trip.end = last
                    context.insert(trip)
                    trips.append(trip)
                }

                // Auto-Name („Region, Monat Jahr") — nur solange der
                // Nutzer nicht selbst umbenannt hat.
                if !trip.isManuallyEdited {
                    let center = group[group.count / 2]
                    if let coordinate = center.coordinate {
                        let placemark = try? await CLGeocoder().reverseGeocodeLocation(
                            CLLocation(latitude: coordinate.latitude,
                                       longitude: coordinate.longitude)).first
                        let region = placemark.flatMap {
                            $0.administrativeArea ?? $0.locality ?? $0.country
                        } ?? "Reise"
                        let formatter = DateFormatter()
                        formatter.dateFormat = "LLLL yyyy"
                        formatter.locale = Locale(identifier: "de_DE")
                        trip.name = "\(region), \(formatter.string(from: first))"
                    }
                }
                // ALLE Medien im Zeitraum gehören zur Reise — auch
                // (noch) unverortete Videos.
                for asset in assets
                where asset.capturedAt >= first.addingTimeInterval(-6 * 3_600)
                    && asset.capturedAt <= last.addingTimeInterval(6 * 3_600) {
                    if asset.trip !== trip { asset.trip = trip }
                }
            }
        }

        // MARK: Aufräumen — leere Automatik-Reste (nie manuell Bearbeitetes)
        for spot in spots where (spot.assets ?? []).isEmpty
            && !spot.isManuallyEdited && spot.notes.isEmpty && spot.rating == nil {
            context.delete(spot)
        }
        for trip in trips where (trip.assets ?? []).isEmpty && !trip.isManuallyEdited {
            context.delete(trip)
        }

        try? context.save()
        let spotTotal = (try? context.fetchCount(FetchDescriptor<MediaSpot>())) ?? 0
        let tripTotal = (try? context.fetchCount(FetchDescriptor<Trip>())) ?? 0
        return "\(tripTotal) Reise\(tripTotal == 1 ? "" : "n") · \(spotTotal) Foto-Spot\(spotTotal == 1 ? "" : "s") erkannt"
    }

    /// Die Planungs-Spots der App (UserDefaults, Codable) — Brücke
    /// zwischen Planung und Archiv.
    private static func loadPlanningSpots() -> [Spot] {
        guard let data = UserDefaults.standard.data(forKey: "spots"),
              let spots = try? JSONDecoder().decode([Spot].self, from: data) else {
            return []
        }
        return spots
    }
}
