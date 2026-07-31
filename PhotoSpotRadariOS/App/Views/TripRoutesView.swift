import MapKit
import PhotoSpotCore
import SwiftUI

/// Manages the saved travel routes: add, delete and drill into a single route.
struct TripRoutesView: View {
    @Bindable var viewModel: RadarViewModel
    @Bindable var settings: SettingsManager

    var body: some View {
        List {
            Section {
                ForEach(settings.trips) { trip in
                    NavigationLink {
                        TripRouteDetailView(viewModel: viewModel, settings: settings, tripID: trip.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(trip.title).font(.headline)
                            if let preparedAt = trip.preparedAt {
                                Text("\(trip.spotCount) Spots, vorbereitet am \(preparedAt.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.footnote).foregroundStyle(.secondary)
                            } else if trip.path.isEmpty {
                                Text("Noch nicht berechnet")
                                    .font(.footnote).foregroundStyle(.secondary)
                            } else {
                                Text("Route berechnet, Spots noch nicht geladen")
                                    .font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onDelete { settings.trips.remove(atOffsets: $0) }
                Button("Neue Route", systemImage: "plus") {
                    settings.trips.append(TripRoute())
                }
            } footer: {
                Text("Jede Route lädt Fotospots entlang ihres Korridors für die Offline-Nutzung. Bereits geladene Spots bleiben beim Löschen einer Route erhalten (entfernbar über „Suchergebnisse leeren“).")
            }
        }
        .navigationTitle("Reiserouten")
    }
}

/// One travel route: corridor map, editable stops, corridor width and offline preparation.
struct TripRouteDetailView: View {
    @Bindable var viewModel: RadarViewModel
    @Bindable var settings: SettingsManager
    let tripID: UUID
    @State private var camera: MapCameraPosition = .automatic

    var body: some View {
        if let index = settings.trips.firstIndex(where: { $0.id == tripID }) {
            form(trip: $settings.trips[index])
        } else {
            ContentUnavailableView("Route nicht gefunden", systemImage: "map")
        }
    }

    private func form(trip: Binding<TripRoute>) -> some View {
        let value = trip.wrappedValue
        return Form {
            Section("Korridor") {
                corridorMap(for: value)
                    .frame(height: 300)
                    .listRowInsets(EdgeInsets())
                Picker("Korridorbreite", selection: trip.corridorRadius) {
                    ForEach(TripRoute.supportedCorridorRadii, id: \.self) { radius in
                        Text(Measurement(value: Double(radius), unit: UnitLength.meters)
                            .formatted(.measurement(width: .abbreviated, usage: .road))).tag(radius)
                    }
                }
                Text("Die Kreise zeigen genau die Bereiche, die beim Laden abgefragt werden (höchstens 20 Abschnitte – auf sehr langen Routen entstehen Lücken). Breite und Zwischenziel verschieben den Korridor.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Route") {
                TextField("Start, z. B. Toronto, Ontario", text: trip.start)
                TextField("Zwischenziel (optional)", text: trip.via)
                TextField("Ziel, z. B. Ottawa, Ontario", text: trip.destination)
                Button {
                    Task { await viewModel.calculateRoute(for: tripID) }
                } label: {
                    Label("Route berechnen", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                }
                .disabled(viewModel.isPreparingTrip)
                Text("Nach Änderungen an Start, Zwischenziel oder Ziel die Route neu berechnen; die Karte zeigt dann den neuen Verlauf.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Offline-Vorbereitung") {
                Button {
                    Task { await viewModel.prepare(tripID: tripID) }
                } label: {
                    if viewModel.preparingTripID == tripID {
                        Label("Wird geladen …", systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
                    } else {
                        Label("Spots entlang der Route laden", systemImage: "arrow.down.map")
                    }
                }
                .disabled(viewModel.isPreparingTrip)
                if let progress = viewModel.tripPreparationProgress {
                    Text(progress).font(.footnote)
                }
                if let preparedAt = value.preparedAt {
                    LabeledContent("Zuletzt vorbereitet",
                                   value: preparedAt.formatted(date: .abbreviated, time: .shortened))
                    LabeledContent("Geladene Spots", value: "\(value.spotCount)")
                }
                if let error = viewModel.errorMessage {
                    Text(error).font(.footnote).foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(value.title)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: value.path) { camera = .automatic }
    }

    @ViewBuilder
    private func corridorMap(for trip: TripRoute) -> some View {
        if trip.path.isEmpty {
            ContentUnavailableView {
                Label("Noch keine Route", systemImage: "map")
            } description: {
                Text("Start und Ziel eingeben und „Route berechnen“ antippen.")
            }
        } else {
            let coordinates = trip.path.map {
                CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
            }
            // The identical sampling the engine uses for loading, so the map is honest.
            let centers = TripCorridor.sampleCenters(along: trip.path,
                                                     spacing: Double(trip.corridorRadius) * 1.5,
                                                     maximumCount: 20)
            Map(position: $camera) {
                ForEach(Array(centers.enumerated()), id: \.offset) { _, center in
                    MapCircle(center: .init(latitude: center.latitude, longitude: center.longitude),
                              radius: CLLocationDistance(trip.corridorRadius))
                        .foregroundStyle(Theme.accent.opacity(0.14))
                        .stroke(Theme.accent.opacity(0.5), lineWidth: 1)
                }
                MapPolyline(coordinates: coordinates)
                    .stroke(Theme.accentViolet, lineWidth: 4)
                if let first = coordinates.first {
                    Marker("Start", systemImage: "flag.fill", coordinate: first)
                        .tint(.green)
                }
                if let last = coordinates.last, coordinates.count > 1 {
                    Marker("Ziel", systemImage: "flag.checkered", coordinate: last)
                        .tint(Theme.accent)
                }
            }
            .modifier(ForcedColorScheme(scheme: viewModel.mapDisplayScheme))
        }
    }
}
