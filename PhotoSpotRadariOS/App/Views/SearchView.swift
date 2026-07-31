import PhotoSpotCore
import SwiftUI

struct SearchView: View {
    @Bindable var viewModel: RadarViewModel
    let imageService: ImageService
    @State private var showingFilters = false
    @State private var selectedSpot: PersistedPhotoSpot?

    var body: some View {
        NavigationStack {
            List(viewModel.visibleSpots) { spot in
                Button {
                    selectedSpot = spot
                } label: {
                    SpotRow(spot: spot, distance: viewModel.distance(to: spot), imageService: imageService)
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Entdecken")
            .searchable(text: $viewModel.query, prompt: "Name, Ort, Land oder Kategorie")
            .toolbar {
                Button("Filter", systemImage: "line.3.horizontal.decrease.circle") { showingFilters = true }
            }
            // Same interaction as tapping a pin on the map: the detail opens as a sheet.
            .sheet(item: $selectedSpot) { spot in
                NavigationStack {
                    SpotDetailView(spot: spot, viewModel: viewModel, imageService: imageService)
                }
            }
            .sheet(isPresented: $showingFilters) { FilterView(filters: $viewModel.filters) }
        }
    }
}

private struct FilterView: View {
    @Binding var filters: SpotFilters
    @Environment(\.dismiss) private var dismiss
    private let featured: [SpotCategory] = SpotCategory.allCases.sorted {
        $0.label.localizedStandardCompare($1.label) == .orderedAscending
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Eigenschaften") {
                    Toggle("Nur mit Bildern", isOn: $filters.requiresImage)
                    Toggle("Nur kostenlos", isOn: $filters.freeOnly)
                    Toggle("Nur barrierefrei", isOn: $filters.accessibleOnly)
                    Toggle("Nur familiengeeignet", isOn: $filters.familyOnly)
                }
                Section("Kategorien") {
                    ForEach(featured, id: \.self) { category in
                        Button { toggle(category) } label: {
                            Label(category.label, systemImage: filters.categories.contains(category) ? "checkmark.circle.fill" : category.symbol)
                        }.foregroundStyle(.primary)
                    }
                }
                Button("Filter zurücksetzen", role: .destructive) { filters = SpotFilters() }
            }
            .navigationTitle("Filter")
            .toolbar { Button("Fertig") { dismiss() } }
        }
    }
    private func toggle(_ category: SpotCategory) {
        if filters.categories.contains(category) { filters.categories.remove(category) }
        else { filters.categories.insert(category) }
    }
}
