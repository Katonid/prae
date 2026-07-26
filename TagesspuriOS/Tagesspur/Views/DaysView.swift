import SwiftUI
import SwiftData
import Charts
import CoreLocation

/// Kalender-Tab: alle aufgezeichneten Tage, geräteübergreifend.
struct DaysView: View {
    @Query(sort: \TrackDay.dayKey, order: .reverse) private var days: [TrackDay]
    @Query private var familyDays: [FamilyDay]
    @Environment(\.modelContext) private var context

    private struct DayGroup: Identifiable {
        var dayKey: String
        var days: [TrackDay]
        var family: [FamilyDay]
        var id: String { dayKey }
        var ownDistance: Double { days.reduce(0) { $0 + $1.distanceMeters } }
        var distance: Double { ownDistance + family.reduce(0) { $0 + $1.distanceMeters } }
        var deviceNames: String {
            let own = days.map { $0.deviceName.isEmpty ? "Gerät" : $0.deviceName }
            let others = family.map(\.displayName)
            return Set(own + others).sorted().joined(separator: ", ")
        }
        /// Kurzbeschreibung „Ort – Ort – Ort“ (eigene vor Familien-Daten).
        var summary: String {
            let candidates = days.map(\.summary) + family.map(\.summary)
            return candidates.first { !$0.isEmpty && $0 != DaySummarizer.noResult } ?? ""
        }
    }

    private var groups: [DayGroup] {
        let ownByDay = Dictionary(grouping: days, by: \.dayKey)
        let familyByDay = Dictionary(grouping: familyDays, by: \.dayKey)
        return Set(ownByDay.keys).union(familyByDay.keys)
            .map { DayGroup(dayKey: $0, days: ownByDay[$0] ?? [], family: familyByDay[$0] ?? []) }
            .sorted { $0.dayKey > $1.dayKey }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !groups.isEmpty {
                    summaryCard
                        .padding(.horizontal)
                        .padding(.bottom, 6)
                }
                daysList
            }
            .navigationTitle("Tage")
            .navigationDestination(for: String.self) { dayKey in
                DayDetailView(dayKey: dayKey)
            }
            .toolbar {
                NavigationLink {
                    AllTracksMapView()
                } label: {
                    Image(systemName: "map.fill")
                }
                NavigationLink {
                    StatsView()
                } label: {
                    Image(systemName: "chart.bar.fill")
                }
            }
            .task {
                await DaySummarizer.updateMissingSummaries(container: context.container)
            }
        }
    }

    private var daysList: some View {
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
                        if !group.summary.isEmpty {
                            Text(group.summary)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
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
    }

    /// Kopfkarte: eigene Gesamtstrecke, Serie und Mini-Diagramm der
    /// letzten 14 Tage (Familien-Daten zählen hier bewusst nicht mit).
    private var summaryCard: some View {
        let ownGroups = groups.filter { !$0.days.isEmpty }
        let totalKm = ownGroups.reduce(0) { $0 + $1.ownDistance } / 1000
        let streak = Statistics.streak(dayKeys: Set(ownGroups.map(\.dayKey)))
        let cutoff = Calendar.current.date(byAdding: .day, value: -13, to: Calendar.current.startOfDay(for: Date()))
        let recent = ownGroups.compactMap { group -> StatsView.DayTotal? in
            guard let date = DayKey.date(for: group.dayKey), let cutoff, date >= cutoff else { return nil }
            return StatsView.DayTotal(dayKey: group.dayKey, date: date, meters: group.ownDistance)
        }

        return NavigationLink {
            StatsView()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(format: "%.0f km", totalKm))
                            .font(.system(.largeTitle, design: .rounded).bold())
                        Text("insgesamt · \(ownGroups.count) Tage")
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
    /// Optional: Zeit-Cursor beim Öffnen vorbelegen (z. B. aus einer
    /// Zeitfrage in der Suche).
    var initialCursorTime: Date? = nil

    @Environment(\.modelContext) private var context
    @State private var tracks: [TrackMapView.DeviceTrack] = []
    @State private var ownTrackCount = 0
    @State private var visits: [VisitInfo] = []
    @State private var media: [MediaItem] = []
    @State private var showReplay = false
    @State private var showViewer = false
    @State private var viewerIndex = 0
    @State private var cursorTime: Date?
    @State private var cursorAddress = ""
    @State private var exportStart: Date?
    @State private var exportEnd: Date?
    @State private var exportURL: URL?
    @State private var exportMessage: String?
    @State private var hiddenTrackIds: Set<String> = []

    /// Nur eigene UND eingeblendete Tracks — die Geräteauswahl wirkt
    /// damit auf Replay, Zeit-Cursor und GPX-Export. (Familien-Punkte
    /// bleiben außen vor: fremde Daten gehören nicht in den Export,
    /// und Replay würde zwischen Personen springen.)
    private var allPoints: [TrackPoint] {
        tracks.prefix(ownTrackCount)
            .filter { !hiddenTrackIds.contains($0.id) }
            .flatMap(\.points)
            .sorted { $0.t < $1.t }
    }

    private var moments: [Moment] {
        MomentBuilder.moments(from: media, visits: visits)
    }

    private var cursorPosition: TrackMath.TimePosition? {
        guard let cursorTime else { return nil }
        return TrackMath.position(at: cursorTime, in: allPoints)
    }

    private var cursorPin: TrackMapView.TimeCursor? {
        guard let cursorTime, let position = cursorPosition else { return nil }
        return TrackMapView.TimeCursor(
            coordinate: position.coordinate,
            label: cursorTime.formatted(date: .omitted, time: .shortened)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            TrackMapView(tracks: tracks, visits: visits, media: media, timeCursor: cursorPin, externalHiddenTrackIds: $hiddenTrackIds, onMediaTap: openViewer)
            List {
                gapSection
                timeSection
                exportSection
                if !tracks.isEmpty {
                    Section("Geräte") {
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
                                        .foregroundStyle(hidden ? .secondary : .primary)
                                    Spacer()
                                    Text("\(track.points.count) Punkte")
                                        .foregroundStyle(.secondary)
                                    Image(systemName: hidden ? "circle" : "checkmark.circle.fill")
                                        .foregroundStyle(hidden ? Color.secondary : Color.accentColor)
                                }
                                .font(.subheadline)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        Text("Abwählen wirkt auf Karte, Replay, Zeit-Cursor und GPX-Export. Exportiert werden nur eigene Geräte.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
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
                    Image(systemName: "play.circle.fill")
                }
                .accessibilityLabel("Tag abspielen")
            }
        }
        .fullScreenCover(isPresented: $showReplay) {
            TrackReplayView(title: DayKey.displayName(for: dayKey), points: allPoints)
        }
        .fullScreenCover(isPresented: $showViewer) {
            MediaViewerView(items: media, index: viewerIndex)
        }
        .onChange(of: hiddenTrackIds) { _, _ in
            exportURL = nil
        }
        .task {
            reload()
            if cursorTime == nil, let initialCursorTime {
                cursorTime = initialCursorTime
            }
        }
        .task {
            await PhotoAnalyzer.analyzeDay(dayKey: dayKey, container: context.container)
        }
    }

    /// Lücken im Track samt protokollierten Tracker-Ereignissen —
    /// macht sichtbar, WARUM an einer Stelle Daten fehlen.
    private struct GapInfo: Identifiable {
        let start: Date
        let end: Date
        let distance: Double
        let events: [String]
        var id: String { "\(start.timeIntervalSince1970)" }
    }

    private var gaps: [GapInfo] {
        let points = allPoints
        guard points.count > 1 else { return [] }
        var result: [GapInfo] = []
        for i in 1..<points.count {
            let a = points[i - 1]
            let b = points[i]
            let dt = b.t.timeIntervalSince(a.t)
            let distance = CLLocation(latitude: a.lat, longitude: a.lon)
                .distance(from: CLLocation(latitude: b.lat, longitude: b.lon))
            guard dt > 180, distance > 300 else { continue }
            let events = LocationTracker.events(
                from: a.t.addingTimeInterval(-120),
                to: b.t.addingTimeInterval(120)
            ).map { "\($0.0.formatted(date: .omitted, time: .shortened)) – \($0.1)" }
            result.append(GapInfo(start: a.t, end: b.t, distance: distance, events: events))
        }
        return result
    }

    @ViewBuilder
    private var gapSection: some View {
        let dayGaps = gaps
        if !dayGaps.isEmpty {
            Section("Lücken-Diagnose") {
                ForEach(dayGaps) { gap in
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(gap.start.formatted(date: .omitted, time: .shortened)) – \(gap.end.formatted(date: .omitted, time: .shortened)) · \(Int(gap.end.timeIntervalSince(gap.start) / 60)) min, \(String(format: "%.1f km", gap.distance / 1000)) ohne Daten")
                            .font(.subheadline.bold())
                        if gap.events.isEmpty {
                            Text("Keine Ereignisse protokolliert — iOS hat in dieser Zeit keine (brauchbaren) Ortungen geliefert. Das Protokoll reicht nur einige Tage zurück.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(gap.events, id: \.self) { event in
                                Text(event)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    /// „Wo war ich um …?“ — Uhrzeit wählen, Marker erscheint auf der Karte.
    @ViewBuilder
    private var timeSection: some View {
        if let first = allPoints.first, let last = allPoints.last, allPoints.count > 1 {
            Section("Wo war ich um …?") {
                DatePicker(
                    "Uhrzeit",
                    selection: Binding(
                        get: { cursorTime ?? first.t },
                        set: { cursorTime = $0 }
                    ),
                    in: first.t...last.t,
                    displayedComponents: .hourAndMinute
                )
                Slider(
                    value: Binding(
                        get: { (cursorTime ?? first.t).timeIntervalSince1970 },
                        set: { cursorTime = Date(timeIntervalSince1970: $0) }
                    ),
                    in: first.t.timeIntervalSince1970...last.t.timeIntervalSince1970
                )
                if let position = cursorPosition, cursorTime != nil {
                    VStack(alignment: .leading, spacing: 2) {
                        if !cursorAddress.isEmpty {
                            Text(cursorAddress)
                                .font(.subheadline)
                        }
                        Text(position.note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let visit = visits.first(where: { $0.owner.isEmpty && $0.arrival <= (cursorTime ?? first.t) && $0.departure >= (cursorTime ?? first.t) }) {
                            Text("Aufenthalt: \(visit.title)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .task(id: cursorTime) {
                        guard let position = cursorPosition else { return }
                        if let info = await Geocoder.shared.info(for: position.coordinate) {
                            cursorAddress = [info.name, info.locality]
                                .filter { !$0.isEmpty }
                                .joined(separator: ", ")
                        }
                    }
                    Button("Marker ausblenden") {
                        cursorTime = nil
                        cursorAddress = ""
                    }
                    .font(.footnote)
                }
            }
        }
    }

    /// Zeitausschnitt des Tages-Tracks als GPX exportieren.
    @ViewBuilder
    private var exportSection: some View {
        if let first = allPoints.first, let last = allPoints.last, allPoints.count > 1 {
            Section("Zeitraum als GPX exportieren") {
                DatePicker(
                    "Von",
                    selection: Binding(
                        get: { exportStart ?? first.t },
                        set: { exportStart = $0; exportURL = nil }
                    ),
                    in: first.t...last.t,
                    displayedComponents: .hourAndMinute
                )
                DatePicker(
                    "Bis",
                    selection: Binding(
                        get: { exportEnd ?? last.t },
                        set: { exportEnd = $0; exportURL = nil }
                    ),
                    in: first.t...last.t,
                    displayedComponents: .hourAndMinute
                )
                LabeledContent("Punkte im Zeitraum", value: "\(slicedPoints.count)")
                Button {
                    exportSlice()
                } label: {
                    Label("GPX-Datei erstellen", systemImage: "square.and.arrow.up")
                }
                .disabled(slicedPoints.count < 2)
                if let exportURL {
                    ShareLink(item: exportURL) {
                        Label("„\(exportURL.lastPathComponent)“ teilen", systemImage: "shareplay")
                    }
                }
                if let exportMessage {
                    Text(exportMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var slicedPoints: [TrackPoint] {
        guard let first = allPoints.first, let last = allPoints.last else { return [] }
        let start = min(exportStart ?? first.t, exportEnd ?? last.t)
        let end = max(exportStart ?? first.t, exportEnd ?? last.t)
        return allPoints.filter { $0.t >= start && $0.t <= end }
    }

    private func exportSlice() {
        guard let firstPoint = slicedPoints.first, let lastPoint = slicedPoints.last else { return }
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH-mm"
        let label = "\(dayKey)_\(timeFormatter.string(from: firstPoint.t))_bis_\(timeFormatter.string(from: lastPoint.t))"
        let rangeText = "\(firstPoint.t.formatted(date: .omitted, time: .shortened)) – \(lastPoint.t.formatted(date: .omitted, time: .shortened))"
        do {
            exportURL = try Exporter.exportTimeSlice(
                points: slicedPoints,
                title: "\(DayKey.displayName(for: dayKey)) \(rangeText)",
                fileLabel: label
            )
            exportMessage = nil
        } catch {
            exportURL = nil
            exportMessage = "Export fehlgeschlagen: \(error.localizedDescription)"
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
        var built = days.map {
            TrackMapView.DeviceTrack(deviceId: $0.deviceId, deviceName: $0.deviceName, points: $0.points())
        }
        ownTrackCount = built.count

        let familyPredicate = #Predicate<FamilyDay> { $0.dayKey == key }
        let familyDays = (try? context.fetch(FetchDescriptor(predicate: familyPredicate))) ?? []
        built.append(contentsOf: familyDays.map {
            TrackMapView.DeviceTrack(deviceId: $0.recordName, deviceName: $0.displayName, points: $0.points())
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
