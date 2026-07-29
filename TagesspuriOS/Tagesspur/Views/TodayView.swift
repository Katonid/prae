import SwiftUI
import SwiftData
import CoreLocation

/// Heute: Hero-Karte mit Live-Zahlen, Karte des bisherigen Tages,
/// Medienleiste und Tages-Replay.
struct TodayView: View {
    @EnvironmentObject private var tracker: LocationTracker
    @Environment(\.modelContext) private var context

    @State private var tracks: [TrackMapView.DeviceTrack] = []
    @State private var ownTrackCount = 0
    @State private var visits: [VisitInfo] = []
    @State private var media: [MediaItem] = []
    @State private var distance: Double = 0
    @State private var replayTarget: ReplayTarget?
    @State private var showViewer = false
    @State private var viewerIndex = 0

    private var todayKey: String { DayKey.key(for: Date()) }

    /// Fürs Replay nur die eigenen Tracks — Familien-Punkte würden die
    /// Kamera zwischen Personen springen lassen.
    private var allPoints: [TrackPoint] {
        tracks.prefix(ownTrackCount).flatMap(\.points).sorted { $0.t < $1.t }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                heroCard
                TrackMapView(tracks: tracks, visits: visits, media: media, followsUser: true, onMediaTap: openViewer)
            }
            .toolbar(.hidden, for: .navigationBar)
            .task(id: tracker.pointsVersion) { reload() }
            .fullScreenCover(item: $replayTarget) { target in
                TrackReplayView(title: target.title, points: target.points)
            }
            .fullScreenCover(isPresented: $showViewer) {
                MediaViewerView(items: media, index: viewerIndex)
            }
        }
    }

    private func openViewer(_ item: MediaItem) {
        viewerIndex = media.firstIndex { $0.id == item.id } ?? 0
        showViewer = true
    }

    // MARK: - Hero-Karte

    /// Randloser Header: volle Breite, hinter die Statusleiste gezogen —
    /// bildet mit der randlosen Karte eine durchgehende Fläche.
    private var heroCard: some View {
        VStack(spacing: 10) {
            Text("Heute")
                .font(.headline)
                .frame(maxWidth: .infinity)
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(distanceText)
                        .font(.system(.largeTitle, design: .rounded).bold())
                        .contentTransition(.numericText())
                        .animation(.snappy, value: distance)
                    Text(statusLine)
                        .font(.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .opacity(0.85)
                }
                Spacer()
                VStack(spacing: 6) {
                    Toggle("", isOn: $tracker.trackingEnabled)
                        .labelsHidden()
                        .tint(.orange)
                    Text(tracker.trackingEnabled ? "Aufzeichnung" : "Pausiert")
                        .font(.caption2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .opacity(0.85)
                }
            }

            HStack(spacing: 14) {
                statBadge("clock.fill", durationText)
                statBadge("mappin.and.ellipse", "\(visits.count)")
                Button {
                    if !media.isEmpty {
                        viewerIndex = 0
                        showViewer = true
                    }
                } label: {
                    statBadge("photo.on.rectangle", "\(media.count)")
                }
                .buttonStyle(.plain)
                Spacer()
                Button {
                    tracker.highAccuracy.toggle()
                } label: {
                    Image(systemName: "scope")
                        .font(.system(size: 15, weight: .bold))
                        .padding(11)
                        .background(tracker.highAccuracy ? Color.orange : Color.white.opacity(0.22), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tracker.highAccuracy ? "Hohe Genauigkeit ausschalten" : "Hohe Genauigkeit einschalten")
                if tracks.contains(where: { $0.points.count > 1 }) {
                    Menu {
                        replayMenuItems
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.system(size: 15, weight: .bold))
                            .padding(11)
                            .background(.white.opacity(0.22), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Tag abspielen — Gerät wählen")
                }
            }

            if tracker.trackingEnabled && !tracker.hasAlwaysPermission {
                Button {
                    tracker.requestPermission()
                } label: {
                    Label("Für Hintergrund-Aufzeichnung: Standort „Immer“ erlauben",
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.yellow)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 14)
        .background(HeroCardBackground(cornerRadius: 0).ignoresSafeArea(edges: .top))
    }

    /// Abspiel-Auswahl: alle eigenen Geräte zusammen oder ein einzelnes
    /// Gerät / Familienmitglied.
    @ViewBuilder
    private var replayMenuItems: some View {
        if ownTrackCount > 1, allPoints.count > 1 {
            Button("Alle eigenen Geräte") {
                replayTarget = ReplayTarget(id: "eigene", title: "Heute", points: allPoints)
            }
        }
        ForEach(tracks) { track in
            if track.points.count > 1 {
                let name = track.deviceName.isEmpty ? "Gerät" : track.deviceName
                Button(name) {
                    replayTarget = ReplayTarget(id: track.id, title: name, points: track.points)
                }
            }
        }
    }

    private func statBadge(_ symbol: String, _ value: String) -> some View {
        Label(value, systemImage: symbol)
            .font(.footnote.monospacedDigit())
            .lineLimit(1)
            .fixedSize()
            .opacity(0.95)
    }

    private var distanceText: String {
        distance >= 1000
            ? String(format: "%.1f km", distance / 1000)
            : String(format: "%.0f m", distance)
    }

    private var durationText: String {
        guard let first = allPoints.first, let last = allPoints.last, allPoints.count > 1 else {
            return "–"
        }
        let minutes = Int(last.t.timeIntervalSince(first.t) / 60)
        return minutes >= 60 ? "\(minutes / 60) h \(minutes % 60) min" : "\(minutes) min"
    }

    private var statusLine: String {
        guard tracker.trackingEnabled else { return "Aufzeichnung pausiert" }
        if tracker.isResting { return "Ruhemodus — spart Akku" }
        return tracker.highAccuracy ? "GPS aktiv · hohe Genauigkeit" : "GPS aktiv"
    }

    private func reload() {
        let key = todayKey
        let dayPredicate = #Predicate<TrackDay> { $0.dayKey == key }
        let days = (try? context.fetch(FetchDescriptor(predicate: dayPredicate))) ?? []
        var built = days.map {
            TrackMapView.DeviceTrack(deviceId: $0.deviceId, deviceName: $0.deviceName, points: $0.points())
        }
        ownTrackCount = built.count
        distance = days.reduce(0) { $0 + $1.distanceMeters }

        let familyPredicate = #Predicate<FamilyDay> { $0.dayKey == key }
        let familyDays = (try? context.fetch(FetchDescriptor(predicate: familyPredicate))) ?? []
        built.append(contentsOf: familyDays.map {
            TrackMapView.DeviceTrack(
                deviceId: $0.deviceId.isEmpty ? $0.recordName : $0.deviceId,
                deviceName: $0.displayName,
                points: $0.points()
            )
        })
        tracks = built

        let visitPredicate = #Predicate<PlaceVisit> { $0.dayKey == key }
        let own = ((try? context.fetch(FetchDescriptor(predicate: visitPredicate))) ?? []).map(VisitInfo.init)
        let familyVisitPredicate = #Predicate<FamilyVisit> { $0.dayKey == key }
        let family = ((try? context.fetch(FetchDescriptor(predicate: familyVisitPredicate))) ?? []).map(VisitInfo.init)
        visits = (own + family).sorted { $0.arrival < $1.arrival }

        media = PhotoMatcher.items(forDayKey: key)
    }
}
