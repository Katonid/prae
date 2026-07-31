import SwiftData
import SwiftUI
import PhotoSpotCore

@main
struct PhotoSpotRadarApp: App {
    private let persistence: PersistenceManager
    private let locationManager: LocationManager
    private let notificationManager: NotificationManager
    private let imageService: ImageService
    private let engine: PhotoSpotEngine
    private let backgroundManager: BackgroundTaskManager
    @State private var settings: SettingsManager
    @State private var viewModel: RadarViewModel
    @State private var coordinator: NavigationCoordinator

    @MainActor init() {
        let persistence: PersistenceManager
        do { persistence = try PersistenceManager() }
        catch { fatalError("SwiftData store could not be opened: \(error)") }
        let location = LocationManager(), notifications = NotificationManager()
        let settings = SettingsManager()
        let images = ImageService(maxMegabytes: settings.cacheSizeMB, wifiOnly: settings.wifiOnlyImages)
        let client = HTTPClient()
        let provider = CompositeSpotProvider(
            primary: OverpassService(client: client),
            wikipedia: WikipediaService(client: client),
            wikimedia: WikimediaSpotService(client: client),
            flickr: FlickrService(client: client)
        )
        let engine = PhotoSpotEngine(locationManager: location, notificationManager: notifications,
                                     persistence: persistence, settings: settings, provider: provider)
        self.persistence = persistence; locationManager = location; notificationManager = notifications
        let coordinator = NavigationCoordinator(), background = BackgroundTaskManager()
        imageService = images; self.engine = engine; backgroundManager = background
        _settings = State(initialValue: settings)
        _viewModel = State(initialValue: RadarViewModel(persistence: persistence, locationManager: location, engine: engine, settings: settings))
        _coordinator = State(initialValue: coordinator)

        background.register { await engine.refresh() }
        background.schedule()
        notifications.onOpenSpot = { id in coordinator.selectedSpotID = id }
    }

    var body: some Scene {
        WindowGroup {
            RootView(viewModel: viewModel, settings: settings, coordinator: coordinator,
                     locationManager: locationManager, notificationManager: notificationManager,
                     imageService: imageService)
                .task {
                    // Let SwiftUI present its first frame before Core Location can trigger
                    // provider requests and persistence merges on a freshly installed build.
                    await Task.yield()
                    engine.start()
                }
        }
        .modelContainer(persistence.container)
    }
}
