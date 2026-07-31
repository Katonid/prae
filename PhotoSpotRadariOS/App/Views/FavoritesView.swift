import SwiftUI

struct FavoritesView: View {
    @Bindable var viewModel: RadarViewModel
    let imageService: ImageService
    @State private var selectedSpot: PersistedPhotoSpot?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: Theme.cardGridColumns, spacing: 18) {
                    ForEach(viewModel.spots.filter(\.isFavorite)) { spot in
                        Button {
                            selectedSpot = spot
                        } label: {
                            SpotCard(spot: spot, distance: viewModel.distance(to: spot),
                                     imageService: imageService)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .overlay {
                if !viewModel.spots.contains(where: \.isFavorite) {
                    ContentUnavailableView {
                        Label {
                            Text("Keine Favoriten")
                        } icon: {
                            Image(systemName: "heart")
                                .foregroundStyle(Theme.gradient)
                        }
                    } description: {
                        Text("Speichere besondere Orte für später.")
                    }
                }
            }
            .navigationTitle("Favoriten")
            .sheet(item: $selectedSpot) { spot in
                NavigationStack {
                    SpotDetailView(spot: spot, viewModel: viewModel, imageService: imageService)
                }
            }
        }
    }
}
