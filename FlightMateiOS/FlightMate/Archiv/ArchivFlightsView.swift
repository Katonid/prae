//
//  ArchivFlightsView.swift
//  FlightMate
//
//  Flug-Übersicht im Archiv (Nutzermeldung: importierte Flüge waren
//  bislang nur indirekt sichtbar — als Route auf der Medien-Karte und
//  im Detail zugeordneter Aufnahmen). Hier bekommen sie ein eigenes
//  Zuhause: Liste aller importierten Flüge mit Dauer, Höhe und
//  zugeordneten Medien; das Detail zeigt die Route auf einer Karte.
//

import SwiftUI
import SwiftData
import MapKit
import CoreLocation

struct ArchivFlightsView: View {
    @State private var flights: [Flight] = []

    var body: some View {
        Group {
            if flights.isEmpty {
                ContentUnavailableView(
                    "Noch keine Flüge importiert",
                    systemImage: "point.topleft.down.to.point.bottomright.curvepath",
                    description: Text("Importiere Flugrouten (DJI-SRT oder AirData-CSV) über „Flugrouten importieren“ auf der Archiv-Startseite. Aufnahmen aus dem Zeitfenster eines Flugs werden ihm automatisch zugeordnet.")
                )
            } else {
                List {
                    ForEach(flights) { flight in
                        NavigationLink {
                            ArchivFlightDetailView(flight: flight)
                        } label: {
                            row(flight)
                        }
                    }
                    .onDelete(perform: delete)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Flüge")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { reload() }
    }

    private func row(_ flight: Flight) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(Theme.shortDayFormatter.string(from: flight.start)) · \(Theme.time(flight.start)) Uhr")
                .font(.body)
            HStack(spacing: 6) {
                Text(durationText(flight.durationS))
                if let maxAlt = flight.maxAltitudeM {
                    Text("· max. \(Int(maxAlt.rounded())) m")
                }
                Text("· \((flight.assets ?? []).count) Medien")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func durationText(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        return total >= 60 ? "\(total / 60) min \(total % 60) s" : "\(total) s"
    }

    private func reload() {
        guard let container = ArchivStore.shared.container else { return }
        flights = (try? container.mainContext.fetch(FetchDescriptor<Flight>(
            sortBy: [SortDescriptor(\.start, order: .reverse)]))) ?? []
    }

    private func delete(at offsets: IndexSet) {
        guard let container = ArchivStore.shared.container else { return }
        for index in offsets {
            container.mainContext.delete(flights[index])
        }
        try? container.mainContext.save()
        reload()
    }
}

// MARK: Flug-Detail mit Routen-Karte

struct ArchivFlightDetailView: View {
    let flight: Flight
    @State private var confirmDelete = false
    @State private var showFullMap = false
    @Environment(\.dismiss) private var dismiss

    // Der Track wird EINMAL im Hintergrund dekodiert und vermessen —
    // vorher lief die JSON-Dekodierung bei jedem Body-Durchlauf
    // mehrfach auf dem Haupt-Thread (Nutzermeldung: „Flüge" lädt eine
    // halbe Ewigkeit, wirkt wie abgestürzt).
    @State private var coordinates: [CLLocationCoordinate2D] = []
    @State private var trackRegion: MKCoordinateRegion?
    @State private var trackLengthM: Double = 0
    @State private var trackLoaded = false

    private var sortedAssets: [MediaAsset] {
        (flight.assets ?? []).sorted { $0.capturedAt < $1.capturedAt }
    }

    /// Track dekodieren, Region und Strecke berechnen — abseits des
    /// Haupt-Threads, Ergebnis landet in den States oben.
    private func loadTrack() async {
        guard !trackLoaded else { return }
        let json = flight.trackJSON
        let result = await Task.detached(priority: .userInitiated)
            { () -> ([CLLocationCoordinate2D], MKCoordinateRegion?, Double) in
            guard let json,
                  let points = try? JSONDecoder().decode([[Double]].self, from: json) else {
                return ([], nil, 0)
            }
            let coords = points.compactMap { point in
                point.count >= 3
                    ? CLLocationCoordinate2D(latitude: point[1], longitude: point[2])
                    : nil
            }
            guard let first = coords.first else { return ([], nil, 0) }
            var minLat = first.latitude, maxLat = first.latitude
            var minLon = first.longitude, maxLon = first.longitude
            var length = 0.0
            for index in coords.indices {
                let c = coords[index]
                minLat = min(minLat, c.latitude); maxLat = max(maxLat, c.latitude)
                minLon = min(minLon, c.longitude); maxLon = max(maxLon, c.longitude)
                if index > 0 {
                    length += CLLocation(latitude: c.latitude, longitude: c.longitude)
                        .distance(from: CLLocation(latitude: coords[index - 1].latitude,
                                                   longitude: coords[index - 1].longitude))
                }
            }
            let region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2,
                                               longitude: (minLon + maxLon) / 2),
                span: MKCoordinateSpan(latitudeDelta: max(0.003, (maxLat - minLat) * 1.4),
                                       longitudeDelta: max(0.003, (maxLon - minLon) * 1.4)))
            return (coords, region, length)
        }.value
        coordinates = result.0
        trackRegion = result.1
        trackLengthM = result.2
        trackLoaded = true
    }

    var body: some View {
        List {
            if !trackLoaded {
                Section {
                    HStack {
                        Spacer()
                        ProgressView("Route wird geladen …")
                        Spacer()
                    }
                    .frame(height: 240)
                    .listRowInsets(EdgeInsets())
                }
            } else if coordinates.count >= 2, let region = trackRegion {
                Section {
                    // Wie die Logbuch-Mini-Karte: feste Region, keine
                    // Interaktion, Antippen öffnet das Vollbild — eine
                    // frei bewegliche Karte in einer List-Zelle war der
                    // gemeldete Absturz beim Öffnen des Flug-Details.
                    routeMap(initialRegion: region, interactive: false)
                        .frame(height: 240)
                        .contentShape(Rectangle())
                        .onTapGesture { showFullMap = true }
                        .id("flightmap-\(flight.id.uuidString)")
                        .listRowInsets(EdgeInsets())
                } footer: {
                    Text("Antippen zeigt die Route im Vollbild.")
                }
            }
            Section("Flug") {
                LabeledContent("Start", value: "\(Theme.dayFormatter.string(from: flight.start)) · \(Theme.time(flight.start)) Uhr")
                LabeledContent("Dauer", value: durationText(flight.durationS))
                if let maxAlt = flight.maxAltitudeM {
                    LabeledContent("Max. Höhe", value: "\(Int(maxAlt.rounded())) m über Start")
                }
                if trackLengthM > 0 {
                    LabeledContent("Strecke", value: trackLengthM >= 1_000
                        ? String(format: "%.1f km", trackLengthM / 1_000)
                        : "\(Int(trackLengthM.rounded())) m")
                }
                LabeledContent("Quelle", value: flight.sourceFileName)
            }
            Section("Aufnahmen aus diesem Flug") {
                if sortedAssets.isEmpty {
                    Text("Keine Aufnahmen zugeordnet. Die Zuordnung läuft über das Zeitfenster des Flugs (±2 Minuten) — sie greift automatisch beim nächsten Medien-Import.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ArchivAssetGrid(assets: sortedAssets)
                        .listRowInsets(EdgeInsets())
                }
            }
            Section {
                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    Label("Flug löschen", systemImage: "trash")
                }
            } footer: {
                Text("Zugeordnete Aufnahmen bleiben erhalten — nur die Flugroute und die Verknüpfung werden entfernt.")
            }
        }
        .navigationTitle("Flug")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Diesen Flug löschen?", isPresented: $confirmDelete,
                            titleVisibility: .visible) {
            Button("Flug löschen", role: .destructive) { deleteFlight() }
            Button("Abbrechen", role: .cancel) {}
        }
        .navigationDestination(isPresented: $showFullMap) {
            fullRouteMap
        }
        .task { await loadTrack() }
    }

    private var fullRouteMap: some View {
        Group {
            if let region = trackRegion {
                routeMap(initialRegion: region, interactive: true)
                    .ignoresSafeArea(edges: .bottom)
            }
        }
        .navigationTitle("Flugroute")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func routeMap(initialRegion: MKCoordinateRegion,
                          interactive: Bool) -> some View {
        Map(initialPosition: .region(initialRegion),
            interactionModes: interactive ? .all : []) {
            MapPolyline(coordinates: coordinates)
                .stroke(.purple.opacity(0.8), lineWidth: 3)
            if let first = coordinates.first {
                Annotation("Start", coordinate: first) {
                    Image(systemName: "airplane.departure")
                        .font(.caption)
                        .padding(5)
                        .background(.green, in: Circle())
                        .foregroundStyle(.white)
                }
            }
            if let last = coordinates.last {
                Annotation("Landung", coordinate: last) {
                    Image(systemName: "airplane.arrival")
                        .font(.caption)
                        .padding(5)
                        .background(.red, in: Circle())
                        .foregroundStyle(.white)
                }
            }
        }
        .mapStyle(.hybrid)
    }

    private func durationText(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        return total >= 60 ? "\(total / 60) min \(total % 60) s" : "\(total) s"
    }

    private func deleteFlight() {
        guard let container = ArchivStore.shared.container else { return }
        container.mainContext.delete(flight)
        try? container.mainContext.save()
        dismiss()
    }
}
