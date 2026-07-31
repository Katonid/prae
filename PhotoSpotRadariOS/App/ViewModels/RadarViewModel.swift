import CoreLocation
import Foundation
import Observation
import PhotoSpotCore
import SwiftUI

@MainActor @Observable
final class RadarViewModel {
    private let persistence: PersistenceManager
    private let locationManager: LocationManager
    private let engine: PhotoSpotEngine
    private let settings: SettingsManager
    private(set) var spots: [PersistedPhotoSpot] = []
    private(set) var isRefreshing = false
    private(set) var selectedSearchPoint: GeoPoint?
    private(set) var preparingTripID: UUID?
    private(set) var tripPreparationProgress: String?
    var isPreparingTrip: Bool { preparingTripID != nil }
    var errorMessage: String?
    var query = ""
    var filters = SpotFilters()
    var sort: SpotSort = .distance

    init(persistence: PersistenceManager, locationManager: LocationManager, engine: PhotoSpotEngine, settings: SettingsManager) {
        self.persistence = persistence; self.locationManager = locationManager; self.engine = engine; self.settings = settings
        engine.onDataChanged = { [weak self] in
            self?.errorMessage = nil
            self?.loadCached()
        }
        engine.onError = { [weak self] message in self?.errorMessage = message }
        loadCached()
    }

    var visibleSpots: [PersistedPhotoSpot] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let relevant = SpotVisibilityPolicy.visibleSpots(spots, level: settings.relevanceLevel,
                                                         flickrOnly: settings.flickrOnlyResults)
        let filtered = relevant.filter { spot in
            (needle.isEmpty || spot.name.lowercased().contains(needle)
                || spot.summaryText?.lowercased().contains(needle) == true
                || spot.locality?.lowercased().contains(needle) == true
                || spot.country?.lowercased().contains(needle) == true
                || spot.category.label.lowercased().contains(needle))
            && (filters.categories.isEmpty || filters.categories.contains(spot.category))
            && (!filters.requiresImage || spot.imageURL != nil)
            && (!filters.freeOnly || spot.isFree == true)
            && (!filters.accessibleOnly || spot.isAccessible == true)
            && (!filters.familyOnly || spot.isFamilyFriendly == true)
            && (!settings.unvisitedOnly || spot.visitedAt == nil)
            && (!settings.imagesOnly || spot.imageURL != nil)
            && matchesTheme(spot)
            && (settings.minimumRating == 0 || (spot.rating ?? 0) >= settings.minimumRating)
        }
        return filtered.sorted { lhs, rhs in
            switch sort {
            case .distance: distance(to: lhs) < distance(to: rhs)
            case .rating: (lhs.rating ?? 0) > (rhs.rating ?? 0)
            case .popularity: lhs.score > rhs.score
            case .name: lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
        }
    }

    private func matchesTheme(_ spot: PersistedPhotoSpot) -> Bool {
        switch settings.themeFilter {
        case .all: true
        case .nature: Self.natureCategories.contains(spot.category)
        case .architecture: Self.architectureCategories.contains(spot.category)
        }
    }

    func distance(to spot: PersistedPhotoSpot) -> Double {
        guard let point = referencePoint else { return .greatestFiniteMagnitude }
        return GeoMath.distance(from: point, to: spot.location)
    }

    /// Map-only light/dark override for views that have no direct settings access (detail map).
    var mapDisplayScheme: ColorScheme? { settings.mapColorScheme.colorScheme }

    var referencePoint: GeoPoint? {
        if let selectedSearchPoint { return selectedSearchPoint }
        guard let coordinate = locationManager.lastLocation?.coordinate else { return nil }
        return .init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    func spots(within radius: Int) -> [PersistedPhotoSpot] {
        visibleSpots.filter { distance(to: $0) <= Double(radius) }
    }

    /// Spots inside a trip's corridor — the same coverage circles the preparation loads.
    /// With the default "Entfernung" sort they are ordered along the route (start → destination);
    /// every other sort of `visibleSpots` stays as chosen.
    func spots(alongTrip trip: TripRoute) -> [PersistedPhotoSpot] {
        guard !trip.path.isEmpty else { return [] }
        let centers = TripCorridor.sampleCenters(along: trip.path,
                                                 spacing: Double(trip.corridorRadius) * 1.5,
                                                 maximumCount: 20)
        let corridor = Double(trip.corridorRadius)
        let matching = visibleSpots.filter { spot in
            centers.contains { GeoMath.distance(from: $0, to: spot.location) <= corridor }
        }
        guard sort == .distance else { return matching }
        let order = matching.reduce(into: [String: Int]()) { result, spot in
            result[spot.id] = nearestPathIndex(to: spot.location, along: trip.path)
        }
        return matching.sorted { (order[$0.id] ?? 0, distance(to: $0)) < (order[$1.id] ?? 0, distance(to: $1)) }
    }

    private func nearestPathIndex(to location: GeoPoint, along path: [GeoPoint]) -> Int {
        var best = 0
        var bestDistance = Double.greatestFiniteMagnitude
        for (index, point) in path.enumerated() {
            let candidate = GeoMath.distance(from: point, to: location)
            if candidate < bestDistance { bestDistance = candidate; best = index }
        }
        return best
    }

    func refresh() async {
        isRefreshing = true; errorMessage = nil
        defer { isRefreshing = false }
        if let selectedSearchPoint {
            await search(at: selectedSearchPoint)
            return
        }
        guard locationManager.authorization == .authorizedAlways
                || locationManager.authorization == .authorizedWhenInUse else {
            if locationManager.authorization == .notDetermined {
                locationManager.requestAuthorization()
                errorMessage = "Erlaube den Standortzugriff und aktualisiere danach erneut."
            } else {
                errorMessage = "Standortzugriff fehlt. Du kannst die Karte verschieben und dort nach Spots suchen."
            }
            return
        }
        await engine.refresh(); loadCached()
    }

    func search(at point: GeoPoint) async {
        isRefreshing = true; errorMessage = nil
        selectedSearchPoint = point
        defer { isRefreshing = false }
        do {
            try await engine.search(near: point)
            loadCached()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func useCurrentLocation() {
        selectedSearchPoint = nil
        errorMessage = nil
    }

    /// All saved travel routes; the map draws them, the settings manage them.
    var trips: [TripRoute] { settings.trips }

    /// Asks MapKit for the driving route of a saved trip and stores the polyline, so the
    /// corridor becomes visible on the map. A changed route resets the prepared state.
    func calculateRoute(for tripID: UUID) async {
        guard let index = settings.trips.firstIndex(where: { $0.id == tripID }) else { return }
        let trip = settings.trips[index]
        let start = trip.start.trimmingCharacters(in: .whitespacesAndNewlines)
        let destination = trip.destination.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !start.isEmpty, !destination.isEmpty else {
            errorMessage = "Bitte Start und Ziel der Reise eingeben."
            return
        }
        preparingTripID = tripID
        errorMessage = nil
        tripPreparationProgress = "Route wird berechnet …"
        defer { preparingTripID = nil }
        do {
            let via = trip.via.trimmingCharacters(in: .whitespacesAndNewlines)
            let path = try await engine.calculateRoutePath(from: start, via: via.isEmpty ? nil : via,
                                                           to: destination)
            // Re-resolve the index: the list may have changed while awaiting.
            guard let index = settings.trips.firstIndex(where: { $0.id == tripID }) else { return }
            settings.trips[index].path = path
            settings.trips[index].preparedAt = nil
            settings.trips[index].spotCount = 0
            tripPreparationProgress = "Route berechnet. Prüfe den Korridor auf der Karte und lade dann die Spots."
        } catch {
            errorMessage = error.localizedDescription
            tripPreparationProgress = nil
        }
    }

    /// Loads the spots along a trip's corridor for offline use; calculates the route
    /// first when it has not been calculated yet.
    func prepare(tripID: UUID) async {
        if settings.trips.first(where: { $0.id == tripID })?.path.isEmpty ?? true {
            await calculateRoute(for: tripID)
        }
        guard let index = settings.trips.firstIndex(where: { $0.id == tripID }),
              !settings.trips[index].path.isEmpty else { return }
        let trip = settings.trips[index]
        preparingTripID = tripID
        errorMessage = nil
        defer { preparingTripID = nil }
        do {
            let count = try await engine.prepareTrip(along: trip.path,
                                                     corridorRadius: trip.corridorRadius) { [weak self] current, total in
                self?.tripPreparationProgress = "Korridor \(current) von \(total) wird geladen …"
            }
            // Re-resolve the index: the list may have changed while awaiting.
            if let index = settings.trips.firstIndex(where: { $0.id == tripID }) {
                settings.trips[index].preparedAt = .now
                settings.trips[index].spotCount = count
            }
            loadCached()
            tripPreparationProgress = "\(count) Fotospots wurden offline vorbereitet."
        } catch {
            errorMessage = error.localizedDescription
            tripPreparationProgress = nil
        }
    }

    /// Empties the stored search results; favorites and visited places are kept.
    func clearSearchResults() {
        do {
            try persistence.removeAllSearchResults()
            loadCached()
        } catch { errorMessage = error.localizedDescription }
    }

    func toggleFavorite(_ spot: PersistedPhotoSpot) { spot.isFavorite.toggle(); save() }
    func toggleVisited(_ spot: PersistedPhotoSpot) { spot.visitedAt = spot.visitedAt == nil ? .now : nil; save() }

    private func loadCached() {
        do { spots = try persistence.allSpots() } catch { errorMessage = error.localizedDescription }
    }
    private func save() { do { try persistence.save() } catch { errorMessage = error.localizedDescription } }

    static let natureCategories: Set<SpotCategory> = [.viewpoint, .waterfall, .lake, .river, .beach, .coast, .cliff, .canyon, .nationalPark, .mountain, .peak, .forest, .cave]
    static let architectureCategories: Set<SpotCategory> = [.historicBuilding, .castle, .ruin, .bridge, .church, .lighthouse, .oldTown, .windmill, .viaduct, .museum]
}

extension SpotCategory {
    var label: String {
        switch self {
        case .viewpoint: "Aussichtspunkt"; case .waterfall: "Wasserfall"; case .lake: "See"
        case .river: "Fluss"; case .beach: "Strand"; case .coast: "Küste"; case .cliff: "Klippe"
        case .canyon: "Canyon"; case .nationalPark: "Nationalpark"; case .mountain: "Berg"
        case .peak: "Gipfel"; case .forest: "Wald"; case .historicBuilding: "Historisches Gebäude"
        case .castle: "Schloss"; case .ruin: "Ruine"; case .bridge: "Brücke"; case .church: "Kirche"
        case .lighthouse: "Leuchtturm"; case .oldTown: "Altstadt"; case .streetArt: "Street Art"
        case .botanicalGarden: "Botanischer Garten"; case .cave: "Höhle"; case .harbour: "Hafen"
        case .pier: "Pier"; case .windmill: "Windmühle"; case .viaduct: "Viadukt"
        case .museum: "Museum"; case .other: "Fotospot"
        }
    }
    var symbol: String {
        switch self {
        case .waterfall, .river, .lake: "water.waves"; case .viewpoint, .mountain, .peak: "mountain.2.fill"
        case .beach, .coast, .cliff: "sun.horizon.fill"; case .castle, .historicBuilding, .ruin: "building.columns.fill"
        case .bridge, .viaduct: "bridge.fill"; case .church: "building.2.fill"; case .lighthouse: "light.beacon.max.fill"
        case .streetArt, .museum: "paintpalette.fill"; case .forest, .nationalPark: "tree.fill"
        default: "camera.fill"
        }
    }
}
