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
import Charts

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
                    Text("Antippen öffnet die Abspiel-Ansicht mit Route und Höhenprofil.")
                }
            }
            Section("Flug") {
                Button {
                    showFullMap = true
                } label: {
                    Label("Flug abspielen", systemImage: "play.circle.fill")
                }
                .disabled(!trackLoaded || coordinates.count < 2)
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
            ArchivFlightPlayerView(flight: flight)
        }
        .task { await loadTrack() }
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

// MARK: Flug abspielen — Route nachfliegen + Höhenprofil

/// Abspiel-Ansicht (Nutzerwunsch): Ein Marker fliegt die Route in
/// wählbarem Tempo nach, ein Zeitstrahl erlaubt Spulen, und das
/// Höhenprofil (Höhe über Startpunkt, direkt aus dem Log) läuft als
/// Diagramm mit Cursor mit. Fehlen Höhendaten im Log, wird das
/// Profil ehrlich ausgeblendet statt Nullen zu zeichnen.
struct ArchivFlightPlayerView: View {
    let flight: Flight

    // Track: [[Sekunden-Offset, Lat, Lon, Höhe m], …]
    @State private var points: [[Double]] = []
    @State private var coordinates: [CLLocationCoordinate2D] = []
    @State private var region: MKCoordinateRegion?
    @State private var hasAltitude = false
    @State private var profile: [ProfileSample] = []

    @State private var offset: Double = 0
    @State private var playing = false
    @State private var speed: Double = 10
    @State private var playbackTask: Task<Void, Never>?

    struct ProfileSample: Identifiable {
        let id = UUID()
        let offsetS: Double
        let altitudeM: Double
    }

    private var duration: Double { points.last?.first ?? 0 }

    /// Start-Kamera: geneigte 3D-Perspektive über dem Track
    /// (Nutzerwunsch: dreh- und schwenkbare 3D-Ansicht). Drehen =
    /// Zwei-Finger-Drehung, Neigen = Zwei-Finger-Schieben oder der
    /// Neigungs-Knopf. Ehrliche Grenze: Die Routenlinie liegt in
    /// Apples Karten immer auf dem Gelände auf — die Flughöhe zeigt
    /// das Höhenprofil, nicht die Linie im Raum.
    private var initialCamera: MapCameraPosition? {
        guard let region else { return nil }
        let spanM = max(region.span.latitudeDelta, region.span.longitudeDelta) * 111_000
        return .camera(MapCamera(centerCoordinate: region.center,
                                 distance: max(500, spanM * 1.8),
                                 heading: 0,
                                 pitch: 55))
    }

    var body: some View {
        Group {
            if let camera = initialCamera {
                Map(initialPosition: camera) {
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
                    if let sample = sample(at: offset) {
                        Annotation("", coordinate: sample.coordinate) {
                            Image(systemName: "location.north.fill")
                                .font(.system(size: 14, weight: .bold))
                                .rotationEffect(.degrees(sample.courseDeg))
                                .padding(7)
                                .background(.purple, in: Circle())
                                .foregroundStyle(.white)
                                .shadow(radius: 3)
                        }
                    }
                }
                // Realistisches 3D-Gelände; frei dreh- und schwenkbar.
                .mapStyle(.hybrid(elevation: .realistic))
                .mapControls {
                    MapCompass()
                    MapPitchToggle()
                    MapScaleView()
                }
            } else {
                ProgressView("Route wird geladen …")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .safeAreaInset(edge: .bottom) { controls }
        .navigationTitle("Flug abspielen")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadTrack() }
        .onDisappear {
            playing = false
            playbackTask?.cancel()
        }
    }

    private var controls: some View {
        VStack(spacing: 8) {
            if hasAltitude {
                Chart {
                    ForEach(profile) { sample in
                        AreaMark(x: .value("Zeit", sample.offsetS),
                                 y: .value("Höhe", sample.altitudeM))
                            .foregroundStyle(.purple.opacity(0.25))
                        LineMark(x: .value("Zeit", sample.offsetS),
                                 y: .value("Höhe", sample.altitudeM))
                            .foregroundStyle(.purple)
                    }
                    RuleMark(x: .value("Position", min(offset, duration)))
                        .foregroundStyle(.orange)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let seconds = value.as(Double.self) {
                                Text(timeText(seconds))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let meters = value.as(Double.self) {
                                Text("\(Int(meters)) m")
                            }
                        }
                    }
                }
                .frame(height: 96)
            }
            HStack(spacing: 12) {
                Button {
                    playing ? stopPlayback() : startPlayback()
                } label: {
                    Image(systemName: playing ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .frame(width: 32)
                }
                Slider(value: $offset, in: 0...max(duration, 1))
                Menu {
                    ForEach([1.0, 5.0, 10.0, 30.0], id: \.self) { option in
                        Button {
                            speed = option
                        } label: {
                            if speed == option {
                                Label("\(Int(option))×", systemImage: "checkmark")
                            } else {
                                Text("\(Int(option))×")
                            }
                        }
                    }
                } label: {
                    Text("\(Int(speed))×")
                        .font(.subheadline.monospacedDigit().bold())
                        .frame(width: 44)
                }
            }
            HStack {
                Text("\(timeText(offset)) / \(timeText(duration))")
                Spacer()
                if hasAltitude, let sample = sample(at: offset) {
                    Text("Höhe über Start: \(Int(sample.altitudeM.rounded())) m")
                }
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(.regularMaterial)
    }

    // MARK: Abspiel-Logik

    private func startPlayback() {
        if offset >= duration { offset = 0 }
        playing = true
        playbackTask?.cancel()
        playbackTask = Task {
            while !Task.isCancelled && playing {
                try? await Task.sleep(nanoseconds: 100_000_000)
                guard playing else { break }
                offset = min(offset + 0.1 * speed, duration)
                if offset >= duration {
                    playing = false
                }
            }
        }
    }

    private func stopPlayback() {
        playing = false
        playbackTask?.cancel()
    }

    /// Position, Höhe und Kurs zum Zeit-Offset (linear interpoliert).
    private func sample(at offset: Double)
        -> (coordinate: CLLocationCoordinate2D, altitudeM: Double, courseDeg: Double)? {
        guard let firstPoint = points.first, firstPoint.count >= 3 else { return nil }
        var previous = firstPoint
        for point in points where point.count >= 3 {
            if point[0] >= offset {
                let span = point[0] - previous[0]
                let t = span > 0 ? (offset - previous[0]) / span : 0
                let coordinate = CLLocationCoordinate2D(
                    latitude: previous[1] + (point[1] - previous[1]) * t,
                    longitude: previous[2] + (point[2] - previous[2]) * t)
                let altPrevious = previous.count >= 4 ? previous[3] : 0
                let altNext = point.count >= 4 ? point[3] : 0
                let course = bearing(
                    from: CLLocationCoordinate2D(latitude: previous[1], longitude: previous[2]),
                    to: CLLocationCoordinate2D(latitude: point[1], longitude: point[2]))
                return (coordinate, altPrevious + (altNext - altPrevious) * t, course)
            }
            previous = point
        }
        return (CLLocationCoordinate2D(latitude: previous[1], longitude: previous[2]),
                previous.count >= 4 ? previous[3] : 0, 0)
    }

    private func bearing(from a: CLLocationCoordinate2D,
                         to b: CLLocationCoordinate2D) -> Double {
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return atan2(y, x) * 180 / .pi
    }

    private func timeText(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// Track einmal im Hintergrund dekodieren (gleiche Regel wie im
    /// Flug-Detail: nie auf dem Haupt-Thread, nie mehrfach).
    private func loadTrack() async {
        guard points.isEmpty else { return }
        let json = flight.trackJSON
        let result = await Task.detached(priority: .userInitiated)
            { () -> ([[Double]], [CLLocationCoordinate2D], MKCoordinateRegion?, Bool, [ProfileSample]) in
            guard let json,
                  let decoded = try? JSONDecoder().decode([[Double]].self, from: json),
                  decoded.count >= 2 else {
                return ([], [], nil, false, [])
            }
            let coords = decoded.compactMap { point in
                point.count >= 3
                    ? CLLocationCoordinate2D(latitude: point[1], longitude: point[2])
                    : nil
            }
            guard let first = coords.first else { return ([], [], nil, false, []) }
            var minLat = first.latitude, maxLat = first.latitude
            var minLon = first.longitude, maxLon = first.longitude
            for c in coords {
                minLat = min(minLat, c.latitude); maxLat = max(maxLat, c.latitude)
                minLon = min(minLon, c.longitude); maxLon = max(maxLon, c.longitude)
            }
            let region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2,
                                               longitude: (minLon + maxLon) / 2),
                span: MKCoordinateSpan(latitudeDelta: max(0.003, (maxLat - minLat) * 1.4),
                                       longitudeDelta: max(0.003, (maxLon - minLon) * 1.4)))
            let altitude = decoded.contains { $0.count >= 4 && $0[3] > 0.5 }
            // Profil auf höchstens ~240 Stützpunkte ausdünnen — mehr
            // löst kein Bildschirm auf, und das Diagramm bleibt leicht.
            let step = max(1, decoded.count / 240)
            let samples: [ProfileSample] = altitude
                ? stride(from: 0, to: decoded.count, by: step).compactMap { index in
                    let point = decoded[index]
                    guard point.count >= 4 else { return nil }
                    return ProfileSample(offsetS: point[0], altitudeM: point[3])
                }
                : []
            return (decoded, coords, region, altitude, samples)
        }.value
        points = result.0
        coordinates = result.1
        region = result.2
        hasAltitude = result.3
        profile = result.4
    }
}
