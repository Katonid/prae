import SwiftUI
import MapKit

/// Wiederverwendbare Karte: Tracks (weiße Kontur + Gerätefarbe),
/// Aufenthalte, Start/Ziel und Medien. Der Hell/Dunkel-Modus der Karte
/// ist unabhängig von der App einstellbar.
struct TrackMapView: View {
    struct DeviceTrack: Identifiable {
        var id: String { deviceId + deviceName }
        var deviceId: String
        var deviceName: String
        var points: [TrackPoint]
    }

    var tracks: [DeviceTrack]
    var visits: [PlaceVisit] = []
    var media: [MediaItem] = []
    var followsUser = false
    var onMediaTap: ((MediaItem) -> Void)? = nil

    @State private var position: MapCameraPosition = .automatic
    @State private var styleIndex = 0
    @AppStorage(AppearanceMode.mapKey) private var mapAppearance = AppearanceMode.system.rawValue
    @Environment(\.colorScheme) private var systemScheme

    private static let styles: [(MapStyle, String)] = [
        (.standard(elevation: .realistic), "map.fill"),
        (.hybrid(elevation: .realistic), "globe.europe.africa.fill"),
        (.imagery(elevation: .realistic), "mountain.2.fill"),
    ]

    private var allPointsSorted: [TrackPoint] {
        tracks.flatMap(\.points).sorted { $0.t < $1.t }
    }

    var body: some View {
        Map(position: $position) {
            // Weiße Kontur unter allen Tracks — hebt die Route auf jedem
            // Kartenstil sauber ab.
            ForEach(tracks) { track in
                if track.points.count > 1 {
                    MapPolyline(coordinates: track.points.map(\.coordinate))
                        .stroke(.white, style: StrokeStyle(lineWidth: 6.5, lineCap: .round, lineJoin: .round))
                }
            }
            ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                if track.points.count > 1 {
                    MapPolyline(coordinates: track.points.map(\.coordinate))
                        .stroke(Theme.trackColors[index % Theme.trackColors.count],
                                style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
                }
            }

            if let start = allPointsSorted.first {
                Annotation("", coordinate: start.coordinate) {
                    TrackEndpointMarker(isStart: true)
                }
            }
            if !followsUser, allPointsSorted.count > 1, let end = allPointsSorted.last {
                Annotation("", coordinate: end.coordinate) {
                    TrackEndpointMarker(isStart: false)
                }
            }

            ForEach(visits) { visit in
                Annotation(visit.title, coordinate: visit.coordinate) {
                    VisitMarkerView()
                }
            }
            ForEach(media.filter { $0.coordinate != nil }) { item in
                Annotation("", coordinate: item.coordinate!) {
                    MediaThumbView(item: item, side: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.white, lineWidth: 1.5))
                        .shadow(radius: 2)
                        .onTapGesture {
                            onMediaTap?(item)
                        }
                }
            }
            if followsUser {
                UserAnnotation()
            }
        }
        .mapStyle(Self.styles[styleIndex].0)
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .environment(\.colorScheme, AppearanceMode.mode(for: mapAppearance).colorScheme ?? systemScheme)
        .overlay(alignment: .topTrailing) {
            Button {
                styleIndex = (styleIndex + 1) % Self.styles.count
            } label: {
                Image(systemName: Self.styles[(styleIndex + 1) % Self.styles.count].1)
                    .font(.title3)
                    .padding(10)
                    .background(.thinMaterial, in: Circle())
            }
            .padding(10)
        }
    }
}

/// Thumbnail eines Fotos/Videos aus der Mediathek.
struct MediaThumbView: View {
    let item: MediaItem
    var side: CGFloat = 72

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle().fill(.quaternary)
                ProgressView()
            }
            if item.isVideo {
                Image(systemName: "play.circle.fill")
                    .foregroundStyle(.white)
                    .shadow(radius: 2)
            }
        }
        .frame(width: side, height: side)
        .clipped()
        .task(id: item.id) {
            let scale = UIScreen.main.scale
            PhotoMatcher.thumbnail(for: item.asset, size: CGSize(width: side * scale, height: side * scale)) { loaded in
                if let loaded {
                    Task { @MainActor in image = loaded }
                }
            }
        }
    }
}

/// Horizontale Leiste mit Aufnahmen; jedes Thumbnail ist antippbar.
struct MediaStripView: View {
    let media: [MediaItem]
    var onTap: ((MediaItem) -> Void)? = nil

    var body: some View {
        if media.isEmpty {
            EmptyView()
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(media) { item in
                        VStack(spacing: 2) {
                            MediaThumbView(item: item)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            Text(item.date.formatted(date: .omitted, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .onTapGesture {
                            onTap?(item)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}
