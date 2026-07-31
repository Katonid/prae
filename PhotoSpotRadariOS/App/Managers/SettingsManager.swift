import Foundation
import Observation
import PhotoSpotCore

@MainActor @Observable
final class SettingsManager {
    private enum Key {
        static let radius = "notificationRadius"
        static let notifications = "notificationsEnabled"
        static let images = "imageQuality"
        static let cache = "cacheSizeMB"
        static let minimumScore = "minimumScore"
        static let minimumRating = "minimumRating"
        static let unvisited = "unvisitedOnly"
        static let imagesOnly = "imagesOnly"
        static let natureOnly = "natureOnly"
        static let architectureOnly = "architectureOnly"
        static let autoVisited = "autoMarkVisited"
        static let travelMode = "travelModeEnabled"
        static let liveTravelRefresh = "liveTravelRefreshEnabled"
        static let wifiOnlyImages = "wifiOnlyImages"
        static let tripStart = "tripStart"
        static let tripDestination = "tripDestination"
        static let tripPreparedAt = "tripPreparedAt"
        static let tripRoutes = "tripRoutes"
        static let flickrDiscovery = "flickrDiscoveryEnabled"
        static let flickrOnly = "flickrOnlyResults"
        static let themeFilter = "spotThemeFilter"
        static let relevanceLevel = "spotRelevanceLevel"
        static let appearance = "appAppearance"
        static let mapColorScheme = "mapColorScheme"
        static let famousOnlyNotifications = "famousOnlyNotifications"
    }
    private let defaults: UserDefaults
    static let supportedRadii = [500, 1_000, 2_000, 5_000, 10_000, 20_000, 50_000, 100_000]

    var radius: Int { didSet { defaults.set(radius, forKey: Key.radius) } }
    var notificationsEnabled: Bool { didSet { defaults.set(notificationsEnabled, forKey: Key.notifications) } }
    var imageQuality: ImageQuality { didSet { defaults.set(imageQuality.rawValue, forKey: Key.images) } }
    var cacheSizeMB: Int { didSet { defaults.set(cacheSizeMB, forKey: Key.cache) } }
    var minimumScore: Int { didSet { defaults.set(minimumScore, forKey: Key.minimumScore) } }
    var minimumRating: Double { didSet { defaults.set(minimumRating, forKey: Key.minimumRating) } }
    var unvisitedOnly: Bool { didSet { defaults.set(unvisitedOnly, forKey: Key.unvisited) } }
    var imagesOnly: Bool { didSet { defaults.set(imagesOnly, forKey: Key.imagesOnly) } }
    var natureOnly: Bool { didSet { defaults.set(natureOnly, forKey: Key.natureOnly) } }
    var architectureOnly: Bool { didSet { defaults.set(architectureOnly, forKey: Key.architectureOnly) } }
    var autoMarkVisited: Bool { didSet { defaults.set(autoMarkVisited, forKey: Key.autoVisited) } }
    var travelModeEnabled: Bool { didSet { defaults.set(travelModeEnabled, forKey: Key.travelMode) } }
    var liveTravelRefreshEnabled: Bool { didSet { defaults.set(liveTravelRefreshEnabled, forKey: Key.liveTravelRefresh) } }
    var wifiOnlyImages: Bool { didSet { defaults.set(wifiOnlyImages, forKey: Key.wifiOnlyImages) } }
    /// All prepared (or preparable) travel routes, stored as JSON in the defaults.
    var trips: [TripRoute] { didSet { persistTrips() } }
    var flickrDiscoveryEnabled: Bool { didSet { defaults.set(flickrDiscoveryEnabled, forKey: Key.flickrDiscovery) } }
    var flickrOnlyResults: Bool { didSet { defaults.set(flickrOnlyResults, forKey: Key.flickrOnly) } }
    var themeFilter: SpotThemeFilter { didSet { defaults.set(themeFilter.rawValue, forKey: Key.themeFilter) } }
    var relevanceLevel: SpotRelevanceLevel { didSet { defaults.set(relevanceLevel.rawValue, forKey: Key.relevanceLevel) } }
    var appearance: AppAppearance { didSet { defaults.set(appearance.rawValue, forKey: Key.appearance) } }
    /// Map-only light/dark override, independent of the app appearance (.system = follow the app).
    var mapColorScheme: AppAppearance { didSet { defaults.set(mapColorScheme.rawValue, forKey: Key.mapColorScheme) } }
    /// Notify only about famous, well-documented sights instead of every nearby viewpoint.
    var famousOnlyNotifications: Bool { didSet { defaults.set(famousOnlyNotifications, forKey: Key.famousOnlyNotifications) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let legacyNatureOnly = defaults.object(forKey: Key.natureOnly) as? Bool ?? false
        let legacyArchitectureOnly = defaults.object(forKey: Key.architectureOnly) as? Bool ?? false
        radius = defaults.object(forKey: Key.radius) as? Int ?? 5_000
        notificationsEnabled = defaults.object(forKey: Key.notifications) as? Bool ?? true
        imageQuality = ImageQuality(rawValue: defaults.string(forKey: Key.images) ?? "") ?? .balanced
        cacheSizeMB = defaults.object(forKey: Key.cache) as? Int ?? 256
        minimumScore = defaults.object(forKey: Key.minimumScore) as? Int ?? 55
        minimumRating = defaults.object(forKey: Key.minimumRating) as? Double ?? 0
        unvisitedOnly = defaults.object(forKey: Key.unvisited) as? Bool ?? true
        imagesOnly = defaults.object(forKey: Key.imagesOnly) as? Bool ?? false
        natureOnly = legacyNatureOnly
        architectureOnly = legacyArchitectureOnly
        autoMarkVisited = defaults.object(forKey: Key.autoVisited) as? Bool ?? true
        travelModeEnabled = defaults.object(forKey: Key.travelMode) as? Bool ?? false
        liveTravelRefreshEnabled = defaults.object(forKey: Key.liveTravelRefresh) as? Bool ?? false
        wifiOnlyImages = defaults.object(forKey: Key.wifiOnlyImages) as? Bool ?? true
        if let data = defaults.data(forKey: Key.tripRoutes),
           let saved = try? JSONDecoder().decode([TripRoute].self, from: data) {
            trips = saved
        } else {
            // One-time migration of the former single-trip fields into the route list.
            let legacyStart = defaults.string(forKey: Key.tripStart) ?? ""
            let legacyDestination = defaults.string(forKey: Key.tripDestination) ?? ""
            if legacyStart.isEmpty && legacyDestination.isEmpty {
                trips = []
            } else {
                var legacy = TripRoute()
                legacy.start = legacyStart
                legacy.destination = legacyDestination
                legacy.preparedAt = defaults.object(forKey: Key.tripPreparedAt) as? Date
                trips = [legacy]
            }
        }
        flickrDiscoveryEnabled = defaults.object(forKey: Key.flickrDiscovery) as? Bool ?? false
        flickrOnlyResults = defaults.object(forKey: Key.flickrOnly) as? Bool ?? false
        if let raw = defaults.string(forKey: Key.themeFilter), let saved = SpotThemeFilter(rawValue: raw) {
            themeFilter = saved
        } else if legacyNatureOnly && !legacyArchitectureOnly {
            themeFilter = .nature
        } else if legacyArchitectureOnly && !legacyNatureOnly {
            themeFilter = .architecture
        } else {
            themeFilter = .all
        }
        if let raw = defaults.string(forKey: Key.relevanceLevel), let saved = SpotRelevanceLevel(rawValue: raw) {
            relevanceLevel = saved
        } else {
            // Default to a curated experience: only truly interesting / exceptional places.
            relevanceLevel = .highlightsOnly
        }
        appearance = AppAppearance(rawValue: defaults.string(forKey: Key.appearance) ?? "") ?? .system
        mapColorScheme = AppAppearance(rawValue: defaults.string(forKey: Key.mapColorScheme) ?? "") ?? .system
        // Default to calm notifications: only famous, well-documented sights.
        famousOnlyNotifications = defaults.object(forKey: Key.famousOnlyNotifications) as? Bool ?? true
        // didSet does not run during init, so a fresh migration must persist itself once.
        if defaults.data(forKey: Key.tripRoutes) == nil && !trips.isEmpty { persistTrips() }
    }

    private func persistTrips() {
        if let data = try? JSONEncoder().encode(trips) {
            defaults.set(data, forKey: Key.tripRoutes)
        }
    }
}
