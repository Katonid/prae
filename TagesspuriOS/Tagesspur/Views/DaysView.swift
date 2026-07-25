import SwiftUI
import SwiftData
import Charts

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
                if !groups.isEmpty {
                    Section {
                        summaryCard
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                }
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
            .toolbar {
                NavigationLink {
                    StatsView()
                } label: {
                    Image(systemName: "chart.bar.fill")
                }
            }
        }
    }

    /// Kopfkarte: Gesamtstrecke, Serie und Mini-Diagramm der letzten 14 Tage.
    private var summaryCard: some View {
        let totalKm = groups.reduce(0) { $0 + $1.distance } / 1000
        let streak = Statistics.streak(dayKeys: Set(groups.map(\.dayKey)))
        let cutoff = Calendar.current.date(byAdding: .day, value: -13, to: Calendar.current.startOfDay(for: Date()))
        let recent = groups.compactMap { group -> StatsView.DayTotal? in
            guard let date = DayKey.date(for: group.dayKey), let cutoff, date >= cutoff else { return nil }
            return StatsView.DayTotal(dayKey: group.dayKey, date: date, meters: group.distance)
        }

        return NavigationLink {
            StatsView()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(format: "%.0f km", totalKm))
                            .font(.system(.largeTitle, design: .rounded).bold())
                        Text("insgesamt · \(groups.count) Tage")
                            .font(.caption)
                            .opacity(0.85)
                    }
                    Spacer()
                    if streak > 1 {
                        Label("\(streak) Tage in Folge", systemImage: "flame.fill")
                            .font(.footnote.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.white.opacity(0.2), in: Capsule())
                    }
                }
                if recent.count > 1 {
                    Chart(recent) { item in
                        BarMark(x: .value("Tag", item.date, unit: .day), y: .value("km", item.meters / 1000))
                            .foregroundStyle(.white.opacity(0.9))
                            .cornerRadius(2)
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .frame(height: 56)
                }
            }
            .foregroundStyle(.white)
            .padding(16)
            .background(HeroCardBackground())
        }
        .buttonStyle(.plain)
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
    @State private var showReplay = false
    @State private var showViewer = false
    @State private var viewerIndex = 0

    private var allPoints: [TrackPoint] {
        tracks.flatMap(\.points).sorted { $0.t < $1.t }
    }

    private var moments: [Moment] {
        MomentBuilder.moments(from: media, visits: visits)
    }

    var body: some View {
        VStack(spacing: 0) {
            TrackMapView(tracks: tracks, visits: visits, media: media, onMediaTap: openViewer)
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
                if !moments.isEmpty {
                    Section("Momente") {
                        ForEach(moments) { moment in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(moment.title)
                                        .font(.subheadline.bold())
                                    Spacer()
                                    Text("\(moment.items.count)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal)
                                MediaStripView(media: moment.items, onTap: openViewer)
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .frame(maxHeight: 320)
        }
        .navigationTitle(DayKey.displayName(for: dayKey))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if allPoints.count > 1 {
                Button {
                    showReplay = true
                } label: {
                    Label("Abspielen", systemImage: "play.circle.fill")
                }
            }
        }
        .fullScreenCover(isPresented: $showReplay) {
            TrackReplayView(title: DayKey.displayName(for: dayKey), points: allPoints)
        }
        .fullScreenCover(isPresented: $showViewer) {
            MediaViewerView(items: media, index: viewerIndex)
        }
        .task { reload() }
        .task {
            await PhotoAnalyzer.analyzeDay(dayKey: dayKey, container: context.container)
        }
    }

    private func openViewer(_ item: MediaItem) {
        viewerIndex = media.firstIndex { $0.id == item.id } ?? 0
        showViewer = true
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
