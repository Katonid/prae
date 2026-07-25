import SwiftUI
import SwiftData
import CoreLocation

/// Heute: Live-Status, Karte des bisherigen Tages, Medienleiste.
struct TodayView: View {
    @EnvironmentObject private var tracker: LocationTracker
    @Environment(\.modelContext) private var context

    @State private var tracks: [TrackMapView.DeviceTrack] = []
    @State private var visits: [PlaceVisit] = []
    @State private var media: [MediaItem] = []
    @State private var distance: Double = 0

    private var todayKey: String { DayKey.key(for: Date()) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                statusHeader
                TrackMapView(tracks: tracks, visits: visits, media: media, followsUser: true)
                MediaStripView(media: media)
                    .padding(.vertical, 8)
            }
            .navigationTitle("Heute")
            .navigationBarTitleDisplayMode(.inline)
            .task(id: tracker.pointsVersion) { reload() }
            .refreshable { reload() }
        }
    }

    private var statusHeader: some View {
        VStack(spacing: 6) {
            HStack {
                Toggle(isOn: $tracker.trackingEnabled) {
                    Label("Aufzeichnung", systemImage: tracker.trackingEnabled ? "record.circle.fill" : "record.circle")
                        .foregroundStyle(tracker.trackingEnabled ? .red : .primary)
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
                .buttonStyle(.borderless)
                .foregroundStyle(.orange)
            }
            HStack {
                Label(distanceText, systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                Spacer()
                if tracker.trackingEnabled {
                    Label(tracker.isResting ? "Ruhemodus (spart Akku)" : "GPS aktiv",
                          systemImage: tracker.isResting ? "moon.zzz.fill" : "antenna.radiowaves.left.and.right")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.footnote)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var distanceText: String {
        distance >= 1000
            ? String(format: "%.1f km", distance / 1000)
            : String(format: "%.0f m", distance)
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
