import SwiftUI
import SwiftData

/// Kalender-Tab: alle aufgezeichneten Tage, geräteübergreifend.
struct DaysView: View {
    @Query(sort: \TrackDay.dayKey, order: .reverse) private var days: [TrackDay]

    private struct DayGroup: Identifiable {
        var dayKey: String
        var days: [TrackDay]
        var id: String { dayKey }
        var distance: Double { days.reduce(0) { $0 + $1.distanceMeters } }
        var deviceNames: String {
            Set(days.map { $0.deviceName.isEmpty ? "Gerät" : $0.deviceName })
                .sorted().joined(separator: ", ")
        }
    }

    private var groups: [DayGroup] {
        Dictionary(grouping: days, by: \.dayKey)
            .map { DayGroup(dayKey: $0.key, days: $0.value) }
            .sorted { $0.dayKey > $1.dayKey }
    }

    var body: some View {
        NavigationStack {
            List {
                if groups.isEmpty {
                    ContentUnavailableView(
                        "Noch keine Tage",
                        systemImage: "map",
                        description: Text("Starte die Aufzeichnung im Tab „Heute“. Über iCloud erscheinen hier auch die Tage deiner anderen Geräte.")
                    )
                }
                ForEach(groups) { group in
                    NavigationLink(value: group.dayKey) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(DayKey.displayName(for: group.dayKey))
                                .font(.headline)
                            HStack {
                                Text(distanceText(group.distance))
                                Text("·")
                                Text(group.deviceNames)
                            }
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Tage")
            .navigationDestination(for: String.self) { dayKey in
                DayDetailView(dayKey: dayKey)
            }
        }
    }

    private func distanceText(_ meters: Double) -> String {
        meters >= 1000
            ? String(format: "%.1f km", meters / 1000)
            : String(format: "%.0f m", meters)
    }
}

/// Detailansicht eines Tages: Karte, Aufenthalte, Medien — alle Geräte.
struct DayDetailView: View {
    let dayKey: String

    @Environment(\.modelContext) private var context
    @State private var tracks: [TrackMapView.DeviceTrack] = []
    @State private var visits: [PlaceVisit] = []
    @State private var media: [MediaItem] = []

    var body: some View {
        VStack(spacing: 0) {
            TrackMapView(tracks: tracks, visits: visits, media: media)
            List {
                if !tracks.isEmpty {
                    Section("Geräte") {
                        ForEach(tracks) { track in
                            HStack {
                                Text(track.deviceName.isEmpty ? "Gerät" : track.deviceName)
                                Spacer()
                                Text("\(track.points.count) Punkte")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.subheadline)
                        }
                    }
                }
                if !visits.isEmpty {
                    Section("Aufenthalte") {
                        ForEach(visits) { visit in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(visit.title).font(.subheadline)
                                HStack {
                                    Text("\(visit.arrival.formatted(date: .omitted, time: .shortened)) – \(visit.departure.formatted(date: .omitted, time: .shortened))")
                                    if !visit.subtitle.isEmpty {
                                        Text("· \(visit.subtitle)")
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                if !media.isEmpty {
                    Section("Fotos & Videos (\(media.count))") {
                        MediaStripView(media: media)
                            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    }
                }
            }
            .listStyle(.insetGrouped)
            .frame(maxHeight: 320)
        }
        .navigationTitle(DayKey.displayName(for: dayKey))
        .navigationBarTitleDisplayMode(.inline)
        .task { reload() }
    }

    private func reload() {
        let key = dayKey
        let dayPredicate = #Predicate<TrackDay> { $0.dayKey == key }
        let days = (try? context.fetch(FetchDescriptor(predicate: dayPredicate))) ?? []
        tracks = days.map {
            TrackMapView.DeviceTrack(deviceId: $0.deviceId, deviceName: $0.deviceName, points: $0.points())
        }
        let visitPredicate = #Predicate<PlaceVisit> { $0.dayKey == key }
        visits = ((try? context.fetch(FetchDescriptor(predicate: visitPredicate))) ?? [])
            .sorted { $0.arrival < $1.arrival }
        media = PhotoMatcher.items(forDayKey: key)
    }
}
