import MapKit
import PhotoSpotCore
import SwiftUI

private enum RadarMapAppearance: String, CaseIterable, Identifiable {
    case standard, satellite, hybrid

    var id: Self { self }
    var label: String {
        switch self {
        case .standard: "Standard"
        case .satellite: "Satellit"
        case .hybrid: "Hybrid"
        }
    }
    var symbol: String {
        switch self {
        case .standard: "map"
        case .satellite: "globe.americas.fill"
        case .hybrid: "square.3.layers.3d"
        }
    }
}

struct MapView: View {
    @Bindable var viewModel: RadarViewModel
    @Bindable var settings: SettingsManager
    let imageService: ImageService
    let locationManager: LocationManager
    let radius: Int
    @State private var selectedSpot: PersistedPhotoSpot?
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var cameraCenter: CLLocationCoordinate2D?
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var isMapPresented = false
    @AppStorage("mapAppearance") private var mapAppearance = RadarMapAppearance.standard

    var body: some View {
        Group {
            if isMapPresented {
                Map(position: $position) {
                    UserAnnotation()
                    tripRouteLines
                    ForEach(displayedSpots) { spot in
                        Annotation(spot.name, coordinate: .init(latitude: spot.latitude, longitude: spot.longitude)) {
                            Button { selectedSpot = spot } label: {
                                Image(systemName: spot.category.symbol)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(9)
                                    .background(Theme.gradient, in: .circle)
                                    .overlay(Circle().stroke(.white, lineWidth: 2))
                                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                            }
                            .accessibilityLabel("\(spot.name), \(spot.category.label)")
                        }
                    }
                }
                .modifier(RadarMapStyleModifier(appearance: mapAppearance))
                .modifier(ForcedColorScheme(scheme: settings.mapColorScheme.colorScheme))
                .mapControls { MapUserLocationButton(); MapCompass(); MapScaleView() }
                .onMapCameraChange(frequency: .onEnd) { context in
                    cameraCenter = context.region.center
                    visibleRegion = context.region
                }
            } else {
                ZStack {
                    Color(uiColor: .systemBackground)
                    ProgressView("Karte wird vorbereitet …")
                }
            }
        }
        .overlay {
            Image(systemName: "plus")
                .font(.title2.weight(.medium))
                .foregroundStyle(.primary)
                .padding(7)
                .background(.regularMaterial, in: .circle)
                .allowsHitTesting(false)
        }
        .safeAreaInset(edge: .top) {
            VStack(spacing: 8) {
                HStack {
                    Label {
                        Text("\(displayedSpots.count) Spots")
                    } icon: {
                        Image(systemName: "camera.fill").foregroundStyle(Theme.gradient)
                    }
                    Spacer()
                    Menu {
                        Picker("Kartendarstellung", selection: $mapAppearance) {
                            ForEach(RadarMapAppearance.allCases) { appearance in
                                Label(appearance.label, systemImage: appearance.symbol)
                                    .tag(appearance)
                            }
                        }
                        // Map-only brightness, independent of the app appearance.
                        Picker("Kartenhelligkeit", selection: $settings.mapColorScheme) {
                            Label("Wie App", systemImage: "circle.lefthalf.filled").tag(AppAppearance.system)
                            Label("Hell", systemImage: "sun.max.fill").tag(AppAppearance.light)
                            Label("Dunkel", systemImage: "moon.fill").tag(AppAppearance.dark)
                        }
                    } label: {
                        Label(mapAppearance.label, systemImage: "square.3.layers.3d")
                    }
                    .accessibilityLabel("Kartendarstellung: \(mapAppearance.label)")
                    if viewModel.selectedSearchPoint != nil {
                        Button("Mein Standort", systemImage: "location.fill") {
                            viewModel.useCurrentLocation()
                            position = .userLocation(fallback: .automatic)
                        }
                    }
                    if viewModel.isRefreshing { ProgressView() }
                }
                if let error = viewModel.errorMessage {
                    Text(error).font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .font(.subheadline.weight(.semibold)).padding().background(.regularMaterial)
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                guard let center = cameraCenter else { return }
                Task {
                    await viewModel.search(at: .init(latitude: center.latitude, longitude: center.longitude))
                }
            } label: {
                Label("Hier nach Fotospots suchen", systemImage: "camera.metering.center.weighted")
            }
            .buttonStyle(GradientButtonStyle())
            .disabled(cameraCenter == nil || viewModel.isRefreshing)
            .opacity(cameraCenter == nil || viewModel.isRefreshing ? 0.55 : 1)
            .padding()
            .background(.ultraThinMaterial)
        }
        .sheet(item: $selectedSpot) { spot in
            NavigationStack {
                SpotDetailView(spot: spot, viewModel: viewModel, imageService: imageService)
            }
        }
        .refreshable { await viewModel.refresh() }
        .task {
            // Construct MapKit after the surrounding tab has produced a valid layout.
            await Task.yield()
            isMapPresented = true
        }
    }

    /// Saved travel routes stay visible so the prepared corridor is findable.
    /// Extracted from the Map builder to keep its expression type-checkable.
    @MapContentBuilder
    private var tripRouteLines: some MapContent {
        ForEach(viewModel.trips.filter { !$0.path.isEmpty }) { trip in
            let coordinates = trip.path.map {
                CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
            }
            MapPolyline(coordinates: coordinates)
                .stroke(Theme.accentViolet.opacity(0.6),
                        style: StrokeStyle(lineWidth: 3, dash: [6, 5]))
        }
    }

    /// Stored spots inside the visible map area (with margin), not just around the user or
    /// search point — panning to a prepared corridor shows its spots without reloading.
    /// Capped to the highest-scored 300 so far-out zoom levels stay responsive.
    private var displayedSpots: [PersistedPhotoSpot] {
        guard let region = visibleRegion else { return viewModel.spots(within: radius) }
        let latitudePadding = region.span.latitudeDelta * 0.6
        let longitudePadding = region.span.longitudeDelta * 0.6
        let inView = viewModel.visibleSpots.filter { spot in
            abs(spot.latitude - region.center.latitude) <= latitudePadding
                && abs(spot.longitude - region.center.longitude) <= longitudePadding
        }
        guard inView.count > 300 else { return inView }
        return Array(inView.sorted { $0.score > $1.score }.prefix(300))
    }
}

private struct RadarMapStyleModifier: ViewModifier {
    let appearance: RadarMapAppearance

    @ViewBuilder
    func body(content: Content) -> some View {
        switch appearance {
        case .standard:
            content.mapStyle(.standard)
        case .satellite:
            content.mapStyle(.imagery)
        case .hybrid:
            content.mapStyle(.hybrid)
        }
    }
}
