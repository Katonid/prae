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
    private(set) var isPreparingTrip = false
    private(set) var tripPreparationProgress: String?
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

    func prepareTrip() async {
        let start = settings.tripStart.trimmingCharacters(in: .whitespacesAndNewlines)
        let destination = settings.tripDestination.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !start.isEmpty, !destination.isEmpty else {
            errorMessage = "Bitte Start und Ziel der Reise eingeben."
            return
        }
        isPreparingTrip = true
        errorMessage = nil
        tripPreparationProgress = "Route wird berechnet …"
        defer { isPreparingTrip = false }
        do {
            let count = try await engine.prepareTrip(from: start, to: destination) { [weak self] current, total in
                self?.tripPreparationProgress = "Korridor \(current) von \(total) wird geladen …"
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
