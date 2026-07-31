import PhotoSpotCore
import SwiftUI

struct SpotListView: View {
    @Bindable var viewModel: RadarViewModel
    let imageService: ImageService
    let radius: Int
    @State private var selectedSpot: PersistedPhotoSpot?
    /// nil shows the surroundings; a trip ID shows that route's corridor spots.
    @State private var selectedTripID: UUID?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: Theme.cardGridColumns, spacing: 18) {
                    ForEach(groups) { group in
                        if group.spots.count == 1, let spot = group.spots.first {
                            Button {
                                selectedSpot = spot
                            } label: {
                                SpotCard(spot: spot, distance: viewModel.distance(to: spot),
                                         imageService: imageService)
                            }
                            .buttonStyle(.plain)
                        } else {
                            PhotoGroupCard(group: group, viewModel: viewModel,
                                           imageService: imageService) { selectedSpot = $0 }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .overlay {
                if baseSpots.isEmpty {
                    ContentUnavailableView {
                        Label {
                            Text("Keine Fotospots geladen")
                        } icon: {
                            Image(systemName: "camera.badge.ellipsis")
                                .foregroundStyle(Theme.gradient)
                        }
                    } description: {
                        if activeTrip != nil {
                            Text("Für diese Route sind keine Spots geladen. Lade sie unter Einstellungen → Reisemodus → Reiserouten.")
                        } else {
                            Text(viewModel.errorMessage ?? "Aktualisiere die Liste oder suche auf der Karte an einer ausgewählten Stelle.")
                        }
                    }
                }
            }
            .navigationTitle(navigationTitle)
            .toolbar {
                if viewModel.trips.contains(where: { !$0.path.isEmpty }) {
                    ToolbarItem(placement: .topBarLeading) { scopeMenu }
                }
                ToolbarItem(placement: .topBarTrailing) { sortMenu }
            }
            .refreshable { await viewModel.refresh() }
            // Same interaction as tapping a pin on the map: the detail opens as a sheet.
            .sheet(item: $selectedSpot) { spot in
                NavigationStack {
                    SpotDetailView(spot: spot, viewModel: viewModel, imageService: imageService)
                }
            }
        }
    }

    private var activeTrip: TripRoute? {
        selectedTripID.flatMap { id in viewModel.trips.first { $0.id == id } }
    }

    /// Surroundings by default, a route's corridor spots when one is selected.
    private var baseSpots: [PersistedPhotoSpot] {
        if let activeTrip { return viewModel.spots(alongTrip: activeTrip) }
        return viewModel.spots(within: radius)
    }

    private var navigationTitle: String {
        if let activeTrip { return activeTrip.title }
        return viewModel.selectedSearchPoint == nil ? "In deiner Nähe" : "Am Suchpunkt"
    }

    /// Switches the list between the surroundings and a prepared travel route.
    private var scopeMenu: some View {
        Menu("Bereich", systemImage: activeTrip == nil
             ? "location.circle" : "point.topleft.down.to.point.bottomright.curvepath") {
            Picker("Bereich", selection: $selectedTripID) {
                Text("Umgebung").tag(UUID?.none)
                ForEach(viewModel.trips.filter { !$0.path.isEmpty }) { trip in
                    Text(trip.title).tag(UUID?.some(trip.id))
                }
            }
        }
    }

    private var groups: [SpotLocationGroup] {
        var result: [SpotLocationGroup] = []
        for spot in baseSpots {
            if spot.sourceName.hasPrefix("Flickr"),
               let index = result.firstIndex(where: { group in
                   group.spots.first.map {
                       $0.sourceName.hasPrefix("Flickr") &&
                       GeoMath.distance(from: $0.location, to: spot.location) <= 250
                   } ?? false
               }) {
                result[index].spots.append(spot)
            } else {
                result.append(.init(id: spot.id, spots: [spot]))
            }
        }
        return result
    }

    private var sortMenu: some View {
        Menu("Sortieren", systemImage: "arrow.up.arrow.down") {
            Picker("Sortierung", selection: $viewModel.sort) {
                ForEach(SpotSort.allCases) { Text($0.rawValue).tag($0) }
            }
        }
    }
}

/// Several Flickr photos at one place: a headline plus a horizontally scrolling photo strip.
private struct PhotoGroupCard: View {
    let group: SpotLocationGroup
    @Bindable var viewModel: RadarViewModel
    let imageService: ImageService
    let onSelect: (PersistedPhotoSpot) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "photo.stack")
                    .foregroundStyle(Theme.gradient)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(group.spots.count) Fotos an diesem Ort")
                        .font(.headline).fontDesign(.rounded)
                    Text(categorySummary)
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(group.spots) { spot in
                        Button {
                            onSelect(spot)
                        } label: {
                            MiniPhotoCard(spot: spot, imageService: imageService)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(14)
        .background(.background.secondary, in: .rect(cornerRadius: 24))
    }

    private var categorySummary: String {
        Set(group.spots.map { $0.category.label }).sorted().prefix(3).joined(separator: ", ")
    }
}

private struct MiniPhotoCard: View {
    let spot: PersistedPhotoSpot
    let imageService: ImageService

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            CachedSpotImage(url: spot.imageURL, service: imageService,
                            placeholderSymbol: spot.category.symbol)
                .frame(width: 150, height: 190)
            Theme.photoScrim.allowsHitTesting(false)
            Text(spot.name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .padding(10)
        }
        .frame(width: 150, height: 190)
        .clipShape(.rect(cornerRadius: 18))
        // Same as SpotCard: keep the overflowing fill photo from hit-testing outside the tile.
        .contentShape(.rect(cornerRadius: 18))
        .accessibilityLabel(spot.name)
    }
}

private struct SpotLocationGroup: Identifiable {
    let id: String
    var spots: [PersistedPhotoSpot]
}
