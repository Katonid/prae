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
    @State private var hiddenTrackIds: Set<String> = []
    @State private var showFilterPanel = false
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

    /// Sichtbare Tracks mit stabiler Farbzuordnung (Index im
    /// Gesamtbestand — Ausblenden verschiebt keine Farben).
    private var visibleIndexedTracks: [(offset: Int, element: DeviceTrack)] {
        Array(tracks.enumerated()).filter { !hiddenTrackIds.contains($0.element.id) }
    }

    private var allPointsSorted: [TrackPoint] {
        visibleIndexedTracks.flatMap { $0.element.points }.sorted { $0.t < $1.t }
    }

    var body: some View {
        Group {
            if isOutdoor {
                OutdoorMapView(
                    tracks: visibleIndexedTracks.map { (track: $0.element, colorIndex: $0.offset) },
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
        .overlay(alignment: .topLeading) {
            if tracks.count > 1 {
                trackFilterButton
            }
        }
        .overlay {
            if showFilterPanel {
                ZStack(alignment: .topLeading) {
                    // Unsichtbarer Fänger: erst ein Tipp NEBEN das Panel
                    // schließt es.
                    Color.black.opacity(0.001)
                        .contentShape(Rectangle())
                        .onTapGesture { showFilterPanel = false }
                    trackFilterPanel
                        .padding(.leading, 10)
                        .padding(.top, 58)
                }
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

    /// Öffnet/schließt das Legende-Panel mit den Geräten/Personen.
    private var trackFilterButton: some View {
        Button {
            showFilterPanel.toggle()
        } label: {
            Image(systemName: "person.2.fill")
                .font(.title3)
                .foregroundStyle(hiddenTrackIds.isEmpty ? Color.primary : Color.orange)
                .padding(10)
                .background(.thinMaterial, in: Circle())
        }
        .padding(10)
        .accessibilityLabel("Geräte und Personen filtern")
    }

    /// Legende + Filter: Farbpunkt je Gerät/Person, Antippen blendet
    /// ein/aus — das Panel bleibt dabei offen.
    private var trackFilterPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                let hidden = hiddenTrackIds.contains(track.id)
                Button {
                    if hidden {
                        hiddenTrackIds.remove(track.id)
                    } else {
                        hiddenTrackIds.insert(track.id)
                    }
                } label: {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Theme.trackColors[index % Theme.trackColors.count])
                            .frame(width: 14, height: 14)
                            .opacity(hidden ? 0.35 : 1)
                        Text(track.deviceName.isEmpty ? "Gerät" : track.deviceName)
                            .font(.subheadline)
                            .foregroundStyle(hidden ? .secondary : .primary)
                            .lineLimit(1)
                        Spacer(minLength: 12)
                        Image(systemName: hidden ? "circle" : "checkmark.circle.fill")
                            .foregroundStyle(hidden ? Color.secondary : Color.accentColor)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if index < tracks.count - 1 {
                    Divider().padding(.leading, 36)
                }
            }
            if !hiddenTrackIds.isEmpty {
                Divider()
                Button("Alle anzeigen") {
                    hiddenTrackIds.removeAll()
                }
                .font(.subheadline.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
            }
        }
        .frame(maxWidth: 250)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.2), radius: 8, y: 3)
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
            ForEach(visibleIndexedTracks, id: \.element.id) { _, track in
                if track.points.count > 1 {
                    MapPolyline(coordinates: track.points.map(\.coordinate))
                        .stroke(.white, style: StrokeStyle(lineWidth: 6.5, lineCap: .round, lineJoin: .round))
                }
            }
            ForEach(visibleIndexedTracks, id: \.element.id) { index, track in
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
