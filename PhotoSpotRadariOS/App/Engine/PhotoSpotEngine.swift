import CoreLocation
import Foundation
import MapKit
import PhotoSpotCore

enum TripPreparationError: LocalizedError {
    case placeNotFound(String), routeNotFound, noData
    var errorDescription: String? {
        switch self {
        case .placeNotFound(let place): "Ort nicht gefunden: \(place)"
        case .routeNotFound: "Zwischen Start und Ziel wurde keine Fahrtroute gefunden."
        case .noData: "Entlang der Route konnten keine Fotospots geladen werden."
        }
    }
}

/// Orchestrates providers, persistence, route analysis and notifications.
/// The engine reacts to system wake-ups; it does not run a polling loop.
@MainActor
final class PhotoSpotEngine {
    private let locationManager: LocationManager
    private let notificationManager: NotificationManager
    private let persistence: PersistenceManager
    private let settings: SettingsManager
    private let provider: any SpotProvider
    private let scorer: SpotScorer
    private let routeAnalyzer = RouteAnalyzer()
    private let notificationPolicy = NotificationPolicy()
    private var samples: [MovementSample] = []
    private var lastFetchLocation: GeoPoint?
    private var systemCourse: Double?
    private var hasStarted = false
    var onDataChanged: (() -> Void)?
    var onError: ((String) -> Void)?

    init(locationManager: LocationManager, notificationManager: NotificationManager,
         persistence: PersistenceManager, settings: SettingsManager,
         provider: any SpotProvider, scorer: SpotScorer = .init()) {
        self.locationManager = locationManager; self.notificationManager = notificationManager
        self.persistence = persistence; self.settings = settings; self.provider = provider; self.scorer = scorer
        locationManager.onEvent = { [weak self] event in Task { await self?.handle(event) } }
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        locationManager.startLowPowerMonitoring()
        locationManager.requestOneShotLocation()
    }

    func refresh() async {
        if let location = locationManager.lastLocation { await process(location) }
        else { locationManager.requestOneShotLocation() }
    }

    func search(near point: GeoPoint) async throws {
        try await fetchSpots(near: point)
    }

    func prepareTrip(from startName: String, to destinationName: String,
                     progress: (Int, Int) -> Void) async throws -> Int {
        let start = try await resolve(startName)
        let destination = try await resolve(destinationName)
        let request = MKDirections.Request()
        request.source = start
        request.destination = destination
        request.transportType = .automobile
        guard let route = try await MKDirections(request: request).calculate().routes.first else {
            throw TripPreparationError.routeNotFound
        }
        let points = Self.sample(route.polyline, everyMeters: 30_000, maximumCount: 20)
        var loadedIDs: Set<String> = []
        for (index, point) in points.enumerated() {
            progress(index + 1, points.count)
            if let candidates = try? await provider.spots(
                near: point, radius: max(settings.radius, 20_000),
                imagePixelLimit: settings.imageQuality.pixelLimit
            ) {
                try persistence.merge(candidates, scorer: scorer)
                loadedIDs.formUnion(candidates.map(\.id))
                onDataChanged?()
            }
        }
        guard !loadedIDs.isEmpty else { throw TripPreparationError.noData }
        settings.tripPreparedAt = .now
        settings.travelModeEnabled = true
        return loadedIDs.count
    }

    private func handle(_ event: LocationEvent) async {
        switch event {
        case .significant(let location): await process(location)
        case .visit(let visit): await handleVisit(visit)
        case .region(let id): await handleRegionEntry(id)
        }
    }

    private func process(_ location: CLLocation) async {
        let point = GeoPoint(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        systemCourse = location.speed >= 1 && location.course >= 0 ? location.course : nil
        samples.append(.init(point: point, timestamp: location.timestamp, horizontalAccuracy: location.horizontalAccuracy))
        samples = Array(samples.suffix(8))
        let movedEnough = lastFetchLocation.map { GeoMath.distance(from: $0, to: point) > Double(settings.radius) * 0.4 } ?? true
        let permitsLiveFetch = !settings.travelModeEnabled || settings.liveTravelRefreshEnabled
        if movedEnough && permitsLiveFetch {
            do {
                try await fetchSpots(near: point)
                lastFetchLocation = point
            } catch {
                onError?(error.localizedDescription)
            }
        }
        await evaluateNotifications(at: point)
    }

    private func resolve(_ name: String) async throws -> MKMapItem {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = name
        guard let item = try await MKLocalSearch(request: request).start().mapItems.first else {
            throw TripPreparationError.placeNotFound(name)
        }
        return item
    }

    private static func sample(_ polyline: MKPolyline, everyMeters spacing: Double,
                               maximumCount: Int) -> [GeoPoint] {
        guard polyline.pointCount > 0 else { return [] }
        let mapPoints = polyline.points()
        var sampled: [GeoPoint] = []
        var previous = mapPoints[0]
        var accumulated = 0.0
        sampled.append(.init(latitude: previous.coordinate.latitude, longitude: previous.coordinate.longitude))
        for index in 1..<polyline.pointCount {
            let current = mapPoints[index]
            accumulated += current.distance(to: previous)
            if accumulated >= spacing {
                sampled.append(.init(latitude: current.coordinate.latitude, longitude: current.coordinate.longitude))
                accumulated = 0
            }
            previous = current
        }
        let end = mapPoints[polyline.pointCount - 1].coordinate
        let endpoint = GeoPoint(latitude: end.latitude, longitude: end.longitude)
        if sampled.last.map({ GeoMath.distance(from: $0, to: endpoint) > 5_000 }) ?? true {
            sampled.append(endpoint)
        }
        guard sampled.count > maximumCount else { return sampled }
        let scale = Double(sampled.count - 1) / Double(maximumCount - 1)
        return (0..<maximumCount).map { sampled[Int((Double($0) * scale).rounded())] }
    }

    private func fetchSpots(near point: GeoPoint) async throws {
        let candidates = try await provider.spots(
            near: point,
            radius: settings.radius,
            imagePixelLimit: settings.imageQuality.pixelLimit
        )
        try persistence.merge(candidates, scorer: scorer)
        // Replace instead of accumulate: nearby spots that were not re-confirmed are stale and
        // get removed. The prune radius stays within the smallest provider search cap (10 km),
        // because farther out "not re-found" would not prove "gone". The prepared travel
        // corridor is exempt so offline data survives the trip.
        if !settings.travelModeEnabled {
            try persistence.pruneStale(around: point, radius: min(settings.radius, 10_000),
                                       confirmedIDs: Set(candidates.map(\.id)))
        }
        onDataChanged?()
    }

    private func evaluateNotifications(at point: GeoPoint) async {
        guard let spots = try? persistence.allSpots() else { return }
        let course = routeAnalyzer.inferredCourse(samples: samples) ?? systemCourse
        let assessed: [(spot: PersistedPhotoSpot, assessment: RouteAssessment)] = spots.map { spot in
            (spot, routeAnalyzer.assess(current: point, course: course, spot: spot.location))
        }
        let visibleIDs = Set(SpotVisibilityPolicy.visibleSpots(
            spots, level: settings.relevanceLevel, flickrOnly: settings.flickrOnlyResults
        ).map(\.id))
        let ranked = assessed
            .filter { spot, assessment in
                visibleIDs.contains(spot.id)
                    // A pinging phone every few kilometers is worse than no radar: by default only
                    // famous, externally documented sights (hard notability + photo — the Statue
                    // of Liberty, not the next unremarkable viewpoint) may notify at all.
                    && (!settings.famousOnlyNotifications
                        || (spot.notability == .hard && spot.imageURL != nil))
                    && assessment.distance <= Double(settings.radius) && assessment.isAhead
                    && (!settings.imagesOnly || spot.imageURL != nil)
                    && matchesTheme(spot)
                    && (settings.minimumRating == 0 || (spot.rating ?? 0) >= settings.minimumRating)
            }
            .sorted { ($0.0.score, -$0.1.distance) > ($1.0.score, -$1.1.distance) }
        let distinctLocations = deduplicatedLocations(ranked)
        locationManager.monitorRegions(for: distinctLocations.map { $0.spot }, radius: settings.radius)
        for (spot, assessment) in distinctLocations.prefix(3) {
            let context = NotificationContext(
                visited: spot.visitedAt != nil, lastNotifiedAt: spot.lastNotifiedAt,
                score: spot.score, minimumScore: settings.minimumScore,
                radius: Double(settings.radius), assessment: assessment,
                notificationsEnabled: settings.notificationsEnabled
            )
            guard notificationPolicy.shouldNotify(context) else { continue }
            try? await notificationManager.schedule(for: spot, distance: assessment.distance)
            spot.lastNotifiedAt = Date.now
        }
        try? persistence.save()
    }

    private func matchesTheme(_ spot: PersistedPhotoSpot) -> Bool {
        switch settings.themeFilter {
        case .all: true
        case .nature: RadarViewModel.natureCategories.contains(spot.category)
        case .architecture: RadarViewModel.architectureCategories.contains(spot.category)
        }
    }

    private func deduplicatedLocations(
        _ ranked: [(spot: PersistedPhotoSpot, assessment: RouteAssessment)]
    ) -> [(spot: PersistedPhotoSpot, assessment: RouteAssessment)] {
        var result: [(spot: PersistedPhotoSpot, assessment: RouteAssessment)] = []
        for candidate in ranked {
            let alreadyRepresented = result.contains {
                GeoMath.distance(from: $0.spot.location, to: candidate.spot.location) <= 250
            }
            if !alreadyRepresented { result.append(candidate) }
        }
        return result
    }

    private func handleRegionEntry(_ id: String) async {
        guard let location = locationManager.lastLocation,
              let spot = try? persistence.allSpots().first(where: { $0.id == id }) else { return }
        let point = GeoPoint(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        let assessment = routeAnalyzer.assess(current: point, course: routeAnalyzer.inferredCourse(samples: samples) ?? systemCourse, spot: spot.location)
        let context = NotificationContext(visited: spot.visitedAt != nil, lastNotifiedAt: spot.lastNotifiedAt,
            score: spot.score, minimumScore: settings.minimumScore, radius: Double(settings.radius),
            assessment: assessment, notificationsEnabled: settings.notificationsEnabled)
        if notificationPolicy.shouldNotify(context) {
            try? await notificationManager.schedule(for: spot, distance: assessment.distance)
            spot.lastNotifiedAt = .now; try? persistence.save()
        }
    }

    private func handleVisit(_ visit: CLVisit) async {
        guard settings.autoMarkVisited, visit.departureDate != .distantFuture,
              visit.departureDate.timeIntervalSince(visit.arrivalDate) >= 300,
              let spots = try? persistence.allSpots() else { return }
        let point = GeoPoint(latitude: visit.coordinate.latitude, longitude: visit.coordinate.longitude)
        if let spot = spots.min(by: { GeoMath.distance(from: point, to: $0.location) < GeoMath.distance(from: point, to: $1.location) }),
           GeoMath.distance(from: point, to: spot.location) <= 100 {
            spot.visitedAt = visit.departureDate; try? persistence.save(); onDataChanged?()
        }
    }
}
