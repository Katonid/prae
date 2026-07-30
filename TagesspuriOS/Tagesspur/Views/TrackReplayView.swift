import SwiftUI
import MapKit
import CoreLocation
import Combine

/// Auswahl fürs Abspielen: welcher Track (Gerät oder Familienmitglied)
/// im Replay läuft — gewählt über das Menü hinter dem Play-Knopf.
struct ReplayTarget: Identifiable {
    let id: String
    let title: String
    let points: [TrackPoint]
}

/// Spielt einen Tag wie einen Film ab — wahlweise als 3D-Flug oder als
/// 2D-Draufsicht. Beide Ansichten sind zoombar (2D pausiert auch frei
/// verschiebbar), und die Zeitleiste lässt sich antippen und ziehen,
/// um jeden Zeitpunkt des Verlaufs per Hand anzusteuern.
struct TrackReplayView: View {
    let title: String

    @Environment(\.dismiss) private var dismiss
    @State private var progress: Double = 0
    @State private var isPlaying = true
    @State private var speed: Double = 1
    @State private var heading: Double = 0
    @State private var camera: MapCameraPosition
    /// Vom Nutzer per Pinch gewählte Flughöhe — bleibt beim Abspielen
    /// und Scrubben erhalten (die Kamera folgt nur der Position).
    @State private var cameraDistance: Double = 1400
    @State private var is3D = true
    @AppStorage(AppearanceMode.mapKey) private var mapAppearance = AppearanceMode.system.rawValue
    @Environment(\.colorScheme) private var systemScheme

    private let path: [TrackPoint]
    private let cumulative: [Double]
    private let totalDistance: Double
    private let baseDuration: TimeInterval = 45

    private let timer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    init(title: String, points: [TrackPoint]) {
        self.title = title
        let sorted = points.sorted { $0.t < $1.t }
        let sampled = Self.downsample(sorted, maxCount: 800)
        self.path = sampled

        var cum: [Double] = [0]
        cum.reserveCapacity(sampled.count)
        for i in 1..<max(sampled.count, 1) {
            let a = CLLocation(latitude: sampled[i - 1].lat, longitude: sampled[i - 1].lon)
            let b = CLLocation(latitude: sampled[i].lat, longitude: sampled[i].lon)
            cum.append(cum[i - 1] + b.distance(from: a))
        }
        self.cumulative = cum
        self.totalDistance = cum.last ?? 0

        let start = sampled.first?.coordinate ?? CLLocationCoordinate2D(latitude: 0, longitude: 0)
        _camera = State(initialValue: .camera(
            MapCamera(centerCoordinate: start, distance: 1400, heading: 0, pitch: 60)
        ))
    }

    /// Pausiert + 2D: freie Karte (zoomen UND verschieben). Sonst folgt
    /// die Kamera dem Punkt — zoomen bleibt immer möglich.
    private var interactionModes: MapInteractionModes {
        (!isPlaying && !is3D) ? [.zoom, .pan] : [.zoom]
    }

    var body: some View {
        ZStack {
            Map(position: $camera, interactionModes: interactionModes) {
                MapPolyline(coordinates: path.map(\.coordinate))
                    .stroke(.white.opacity(0.6), lineWidth: 4)
                MapPolyline(coordinates: traveledCoordinates)
                    .stroke(.blue, lineWidth: 5)
                Annotation("", coordinate: currentState.coordinate) {
                    ZStack {
                        Circle().fill(.blue.opacity(0.25)).frame(width: 44, height: 44)
                        Circle().fill(.white).frame(width: 22, height: 22)
                        Circle().fill(.blue).frame(width: 14, height: 14)
                    }
                }
            }
            .mapStyle(is3D ? .standard(elevation: .realistic) : .standard(elevation: .flat))
            .onMapCameraChange(frequency: .continuous) { context in
                // Pinch-Zoom des Nutzers übernehmen — die nächste
                // Kamerafahrt behält seine Flughöhe bei.
                cameraDistance = context.camera.distance
            }
            .environment(\.colorScheme, AppearanceMode.mode(for: mapAppearance).colorScheme ?? systemScheme)
            .ignoresSafeArea()

            VStack {
                header
                Spacer()
                controls
            }
        }
        .onReceive(timer) { _ in
            tick()
        }
    }

    // MARK: - Overlays

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white, .black.opacity(0.35))
            }
            Spacer()
            VStack(spacing: 2) {
                Text(title).font(.headline)
                Text(currentState.time.formatted(date: .omitted, time: .shortened))
                    .font(.system(.title2, design: .rounded).monospacedDigit())
                    .bold()
            }
            .foregroundStyle(.white)
            .shadow(radius: 3)
            Spacer()
            Button {
                is3D.toggle()
                moveCamera()
            } label: {
                Image(systemName: is3D ? "map.fill" : "view.3d")
                    .font(.headline)
                    .padding(9)
                    .background(.black.opacity(0.35), in: Circle())
                    .foregroundStyle(.white)
            }
            .accessibilityLabel(is3D ? "2D-Ansicht" : "3D-Ansicht")
            Menu {
                ForEach([1.0, 2.0, 4.0], id: \.self) { s in
                    Button("\(Int(s))×") { speed = s }
                }
            } label: {
                Text("\(Int(speed))×")
                    .font(.headline)
                    .padding(8)
                    .background(.black.opacity(0.35), in: Circle())
                    .foregroundStyle(.white)
            }
        }
        .padding()
    }

    private var controls: some View {
        VStack(spacing: 8) {
            HStack {
                Text(distanceText(totalDistance * progress))
                Spacer()
                Text(distanceText(totalDistance))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.white)

            HStack(spacing: 12) {
                Button {
                    if progress >= 1 { progress = 0 }
                    isPlaying.toggle()
                } label: {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.white)
                }
                scrubber
            }
        }
        .padding()
        .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 20))
        .padding()
    }

    /// Zeitleiste mit direkter Ansteuerung: Antippen springt zum
    /// Zeitpunkt, Ziehen scrubbt — die Kamera folgt dem Punkt.
    private var scrubber: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.35))
                    .frame(height: 6)
                Capsule()
                    .fill(.white)
                    .frame(width: max(0, geo.size.width * progress), height: 6)
                Circle()
                    .fill(.white)
                    .frame(width: 20, height: 20)
                    .shadow(radius: 2)
                    .offset(x: min(max(geo.size.width * progress - 10, -10), geo.size.width - 10))
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isPlaying = false
                        progress = min(max(value.location.x / geo.size.width, 0), 1)
                        moveCamera()
                    }
            )
        }
        .frame(height: 32)
    }

    // MARK: - Replay-Logik

    private struct ReplayState {
        var coordinate: CLLocationCoordinate2D
        var time: Date
        var segmentHeading: Double
    }

    private var currentState: ReplayState {
        guard path.count > 1, totalDistance > 0 else {
            let p = path.first ?? TrackPoint(t: Date(), lat: 0, lon: 0)
            return ReplayState(coordinate: p.coordinate, time: p.t, segmentHeading: 0)
        }
        let target = totalDistance * min(max(progress, 0), 1)
        var i = cumulative.firstIndex(where: { $0 >= target }) ?? cumulative.count - 1
        i = max(i, 1)
        let segLen = cumulative[i] - cumulative[i - 1]
        let f = segLen > 0 ? (target - cumulative[i - 1]) / segLen : 0
        let a = path[i - 1], b = path[i]
        let lat = a.lat + (b.lat - a.lat) * f
        let lon = a.lon + (b.lon - a.lon) * f
        let t = a.t.addingTimeInterval(b.t.timeIntervalSince(a.t) * f)
        return ReplayState(
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            time: t,
            segmentHeading: Self.bearing(from: a.coordinate, to: b.coordinate)
        )
    }

    private var traveledCoordinates: [CLLocationCoordinate2D] {
        guard path.count > 1, totalDistance > 0 else { return path.map(\.coordinate) }
        let target = totalDistance * min(max(progress, 0), 1)
        var coords: [CLLocationCoordinate2D] = []
        for i in 0..<path.count where cumulative[i] <= target {
            coords.append(path[i].coordinate)
        }
        coords.append(currentState.coordinate)
        return coords
    }

    /// Kamera zur aktuellen Position bewegen — 3D geneigt mit
    /// Blickrichtung, 2D senkrecht von oben; die Flughöhe bestimmt
    /// immer der Nutzer (Pinch).
    private func moveCamera() {
        let state = currentState
        camera = .camera(MapCamera(
            centerCoordinate: state.coordinate,
            distance: cameraDistance,
            heading: is3D ? heading : 0,
            pitch: is3D ? 60 : 0
        ))
    }

    private func tick() {
        guard isPlaying else { return }
        progress += (1.0 / 30.0) / baseDuration * speed
        if progress >= 1 {
            progress = 1
            isPlaying = false
        }
        let state = currentState
        // Blickrichtung weich nachführen (kein Ruckeln bei Kurven).
        var delta = state.segmentHeading - heading
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        heading += delta * 0.08
        moveCamera()
    }

    private func distanceText(_ meters: Double) -> String {
        meters >= 1000
            ? String(format: "%.1f km", meters / 1000)
            : String(format: "%.0f m", meters)
    }

    // MARK: - Helfer

    static func downsample(_ points: [TrackPoint], maxCount: Int) -> [TrackPoint] {
        guard points.count > maxCount, maxCount > 2 else { return points }
        let step = Double(points.count - 1) / Double(maxCount - 1)
        return (0..<maxCount).map { points[Int(Double($0) * step)] }
    }

    static func bearing(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> Double {
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let deg = atan2(y, x) * 180 / .pi
        return (deg + 360).truncatingRemainder(dividingBy: 360)
    }
}
