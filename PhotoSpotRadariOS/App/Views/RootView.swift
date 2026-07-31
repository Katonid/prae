import Observation
import SwiftUI

@MainActor @Observable
final class NavigationCoordinator {
    var selectedSpotID: String?
}

struct RootView: View {
    @Bindable var viewModel: RadarViewModel
    @Bindable var settings: SettingsManager
    @Bindable var coordinator: NavigationCoordinator
    let locationManager: LocationManager
    let notificationManager: NotificationManager
    let imageService: ImageService
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Karte", systemImage: "map.fill", value: 0) {
                MapView(viewModel: viewModel, settings: settings, imageService: imageService,
                        locationManager: locationManager, radius: settings.radius)
            }
            Tab("Liste", systemImage: "list.bullet", value: 1) { SpotListView(viewModel: viewModel, imageService: imageService, radius: settings.radius) }
            Tab("Suche", systemImage: "magnifyingglass", value: 2) { SearchView(viewModel: viewModel, imageService: imageService) }
            Tab("Favoriten", systemImage: "heart.fill", value: 3) { FavoritesView(viewModel: viewModel, imageService: imageService) }
            Tab("Einstellungen", systemImage: "gearshape.fill", value: 4) {
                SettingsView(settings: settings, viewModel: viewModel, locationManager: locationManager,
                             notificationManager: notificationManager, imageService: imageService)
            }
        }
        .tint(Theme.accent)
        // nil follows the system; .light keeps the Apple map bright on dark-mode devices.
        .preferredColorScheme(settings.appearance.colorScheme)
        .sheet(isPresented: Binding(
            get: { coordinator.selectedSpotID != nil },
            set: { if !$0 { coordinator.selectedSpotID = nil } }
        )) {
            if let id = coordinator.selectedSpotID,
               let spot = viewModel.spots.first(where: { $0.id == id }) {
                NavigationStack { SpotDetailView(spot: spot, viewModel: viewModel, imageService: imageService) }
            } else {
                ContentUnavailableView("Spot nicht verfügbar", systemImage: "camera.badge.ellipsis")
            }
        }
    }
}
