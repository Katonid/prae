import SwiftUI
import SwiftData
import CoreLocation

/// Heute: Hero-Karte mit Live-Zahlen, Karte des bisherigen Tages,
/// Medienleiste und Tages-Replay.
struct TodayView: View {
    @EnvironmentObject private var tracker: LocationTracker
    @Environment(\.modelContext) private var context

    @State private var tracks: [TrackMapView.DeviceTrack] = []
    @State private var visits: [PlaceVisit] = []
    @State private var media: [MediaItem] = []
    @State private var distance: Double = 0
    @State private var showReplay = false
    @State private var showViewer = false
    @State private var viewerIndex = 0

    private var todayKey: String { DayKey.key(for: Date()) }

    private var allPoints: [TrackPoint] {
        tracks.flatMap(\.points).sorted { $0.t < $1.t }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                heroCard
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                TrackMapView(tracks: tracks, visits: visits, media: media, followsUser: true, onMediaTap: openViewer)
            }
            .navigationTitle("Heute")
            .navigationBarTitleDisplayMode(.inline)
            .task(id: tracker.pointsVersion) { reload() }
            .refreshable { reload() }
            .fullScreenCover(isPresented: $showReplay) {
                TrackReplayView(title: "Heute", points: allPoints)
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

    private var heroCard: some View {
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(distanceText)
                        .font(.system(.largeTitle, design: .rounded).bold())
                        .contentTransition(.numericText())
                        .animation(.snappy, value: distance)
                    Text(statusLine)
                        .font(.caption)
                        .opacity(0.85)
                }
                Spacer()
                VStack(spacing: 6) {
                    Toggle("", isOn: $tracker.trackingEnabled)
                        .labelsHidden()
                        .tint(.orange)
                    Text(tracker.trackingEnabled ? "Aufzeichnung" : "Pausiert")
                        .font(.caption2)
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
                if allPoints.count > 1 {
                    Button {
                        showReplay = true
                    } label: {
                        Label("Abspielen", systemImage: "play.fill")
                            .font(.footnote.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(.white.opacity(0.22), in: Capsule())
                    }
                    .buttonStyle(.plain)
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
        .padding(16)
        .background(
            LinearGradient(colors: [Color(red: 0.06, green: 0.16, blue: 0.29),
                                    Color(red: 0.17, green: 0.55, blue: 0.70)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 18)
        )
    }

    private func statBadge(_ symbol: String, _ value: String) -> some View {
        Label(value, systemImage: symbol)
            .font(.footnote.monospacedDigit())
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
        return tracker.isResting ? "Ruhemodus — spart Akku" : "GPS aktiv"
    }

    private func reload() {
        let key = todayKey
        let dayPredicate = #Predicate<TrackDay> { $0.dayKey == key }
        let days = (try? context.fetch(FetchDescriptor(predicate: dayPredicate))) ?? []
        tracks = days.map {
            TrackMapView.DeviceTrack(deviceId: $0.deviceId, deviceName: $0.deviceName, points: $0.points())
        }
        distance = days.reduce(0) { $0 + $1.distanceMeters }

        let visitPredicate = #Predicate<PlaceVisit> { $0.dayKey == key }
        visits = (try? context.fetch(FetchDescriptor(predicate: visitPredicate))) ?? []

        media = PhotoMatcher.items(forDayKey: key)
    }
}
