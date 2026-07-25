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

    /// Marker für „Wo war ich um …?“.
    struct TimeCursor {
        var coordinate: CLLocationCoordinate2D
        var label: String
    }

    var tracks: [DeviceTrack]
    var visits: [VisitInfo] = []
    var media: [MediaItem] = []
    var followsUser = false
    var timeCursor: TimeCursor? = nil
    var onMediaTap: ((MediaItem) -> Void)? = nil

    @State private var position: MapCameraPosition = .automatic
    @AppStorage("tagesspur.mapStyleIndex") private var styleIndex = 0
    @AppStorage(AppearanceMode.mapKey) private var mapAppearance = AppearanceMode.system.rawValue
    @Environment(\.colorScheme) private var systemScheme

    /// Stil-Rotation: Apple Standard/Hybrid/Satellit + Outdoor (OpenTopoMap).
    private static let styleIcons = ["map.fill", "globe.europe.africa.fill", "mountain.2.fill", "figure.hiking"]
    private static let appleStyles: [MapStyle] = [
        .standard(elevation: .realistic),
        .hybrid(elevation: .realistic),
        .imagery(elevation: .realistic),
    ]
    private var isOutdoor: Bool { styleIndex % Self.styleIcons.count == 3 }

    private var allPointsSorted: [TrackPoint] {
        tracks.flatMap(\.points).sorted { $0.t < $1.t }
    }

    var body: some View {
        Group {
            if isOutdoor {
                OutdoorMapView(
                    tracks: tracks,
                    visits: visits,
                    media: media,
                    followsUser: followsUser,
                    timeCursor: timeCursor,
                    onMediaTap: onMediaTap
                )
            } else {
                appleMap
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                styleIndex = (styleIndex + 1) % Self.styleIcons.count
            } label: {
                Image(systemName: Self.styleIcons[(styleIndex + 1) % Self.styleIcons.count])
                    .font(.title3)
                    .padding(10)
                    .background(.thinMaterial, in: Circle())
            }
            .padding(10)
        }
        .overlay(alignment: .bottomLeading) {
            if isOutdoor {
                // Pflicht-Attribution der jeweiligen Kachelquelle.
                Text(outdoorAttribution)
                    .font(.system(size: 9))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.thinMaterial, in: Capsule())
                    .padding(6)
            }
        }
    }

    private var outdoorAttribution: String {
        let key = UserDefaults.standard.string(forKey: OutdoorMapView.OutdoorTileOverlay.thunderforestKeyDefault)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return key.isEmpty
            ? "© OpenStreetMap-Mitwirkende · OpenTopoMap (CC-BY-SA)"
            : "Karten © Thunderforest · Daten © OpenStreetMap-Mitwirkende"
    }

    private var appleMap: some View {
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
            if let timeCursor {
                Annotation(timeCursor.label, coordinate: timeCursor.coordinate) {
                    ZStack {
                        Circle()
                            .fill(.white)
                            .frame(width: 30, height: 30)
                            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                        Circle()
                            .fill(.orange)
                            .frame(width: 22, height: 22)
                        Image(systemName: "clock.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            if followsUser {
                UserAnnotation()
            }
        }
        .mapStyle(Self.appleStyles[min(styleIndex, Self.appleStyles.count - 1)])
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .environment(\.colorScheme, AppearanceMode.mode(for: mapAppearance).colorScheme ?? systemScheme)
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
