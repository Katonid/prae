import SwiftUI
import SwiftData
import MapKit
import CoreLocation

/// Rückblick-Gesamtkarte: alle aufgezeichneten Tracks (eigene Geräte
/// und Familie), mit wählbarem Zeitraum und Geräteauswahl.
///
/// Zwei Ansichten:
/// - „Spuren“: alle Tracks als Linien; Antippen wählt einen Track aus
///   (Infokarte, isolieren, Tagesdetail).
/// - „Heatmap“: Besuchshäufigkeit als eingefärbte Streckenlinien —
///   dieselben Spuren wie in der Tagesansicht, aber jeder Abschnitt
///   trägt die Farbe seiner Besuchszahl. Gezählt werden DURCHFAHRTEN
///   pro Rasterfeld (~120 m): Ein neuer Besuch beginnt, wenn zwischen
///   zwei Vorbeikommen > 15 min liegen — Hin- und Rückweg am selben
///   Tag zählen damit doppelt (Ottawa-Befund), ein langer Aufenthalt
///   bläht dagegen nichts auf. Farbskala: Regenbogen von Lila
///   (seltenste Besuche) bis Rot (häufigste), logarithmisch skaliert —
///   linear wäre neben dem Zuhause alles andere einfarbig lila.
struct AllTracksMapView: View {
    struct TrackItem: Identifiable {
        let id: String
        let dayKey: String
        let deviceId: String
        let ownerName: String
        let points: [TrackPoint]
        let pointCount: Int
        let distanceMeters: Double
        let start: Date
        let end: Date
    }

    private enum ViewMode: String, CaseIterable, Identifiable {
        case tracks = "Spuren"
        case heat = "Heatmap"
        var id: String { rawValue }
    }

    @Environment(\.modelContext) private var context
    @AppStorage(AppearanceMode.mapKey) private var mapAppearance = AppearanceMode.system.rawValue
    @Environment(\.colorScheme) private var systemScheme

    @State private var items: [TrackItem] = []
    @State private var selectedId: String?
    @State private var isolate = false
    @State private var position: MapCameraPosition = .automatic
    @State private var mode: ViewMode = .tracks
    @State private var showFilter = false
    @State private var hiddenDeviceIds: Set<String> = []
    @State private var rangeStart: Date?
    @State private var rangeEnd: Date?

    // Heatmap-Segmente werden nur bei Filter-/Moduswechsel neu
    // berechnet, nicht bei jedem Karten-Rendern (Binning + Episoden-
    // Zählung über zigtausend Punkte ist spürbar).
    @State private var heatSegments: [HeatSegment] = []
    @State private var heatMax = 1

    private static let heatGridMeters = 120.0
    private static let heatLevels = 12

    /// Zusammenhängender Streckenabschnitt gleicher Farbstufe.
    private struct HeatSegment: Identifiable {
        let id: Int
        let coordinates: [CLLocationCoordinate2D]
        let level: Int
    }

    private struct DeviceEntry: Identifiable {
        let id: String
        let name: String
    }

    private var selected: TrackItem? {
        filteredItems.first { $0.id == selectedId }
    }

    /// Geräte in stabiler Reihenfolge (eigene zuerst, dann Familie).
    private var devices: [DeviceEntry] {
        var seen = Set<String>()
        var out: [DeviceEntry] = []
        for item in items where !seen.contains(item.deviceId) {
            seen.insert(item.deviceId)
            out.append(DeviceEntry(id: item.deviceId, name: item.ownerName))
        }
        return out
    }

    private var deviceIndex: [String: Int] {
        Dictionary(uniqueKeysWithValues: devices.enumerated().map { ($0.element.id, $0.offset) })
    }

    /// Datengrenzen für die Zeitraum-Wähler.
    private var dataRange: ClosedRange<Date> {
        let dates = items.compactMap { DayKey.date(for: $0.dayKey) }
        let lower = dates.min() ?? Date()
        let upper = dates.max() ?? Date()
        return lower...max(lower, upper)
    }

    private var filteredItems: [TrackItem] {
        items.filter { item in
            guard !hiddenDeviceIds.contains(item.deviceId) else { return false }
            guard let date = DayKey.date(for: item.dayKey) else { return true }
            if let rangeStart, date < Calendar.current.startOfDay(for: rangeStart) { return false }
            if let rangeEnd, date > rangeEnd { return false }
            return true
        }
    }

    /// Ausgewählter Track zuletzt gezeichnet = obenauf.
    private var displayed: [TrackItem] {
        let base = filteredItems
        if isolate, let selected { return [selected] }
        guard let selectedId else { return base }
        return base.filter { $0.id != selectedId } + base.filter { $0.id == selectedId }
    }

    var body: some View {
        MapReader { proxy in
            Map(position: $position) {
                if mode == .heat {
                    // Vorgesortiert: kalte Stufen zuerst, heiße obenauf.
                    ForEach(heatSegments) { segment in
                        MapPolyline(coordinates: segment.coordinates)
                            .stroke(
                                Self.levelColor(segment.level),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                            )
                    }
                } else {
                    ForEach(displayed) { item in
                        MapPolyline(coordinates: item.points.map(\.coordinate))
                            .stroke(
                                item.id == selectedId
                                    ? Color.orange
                                    : TrackColorStore.shared
                                        .color(forId: item.deviceId, fallbackIndex: deviceIndex[item.deviceId] ?? 0)
                                        .opacity(0.7),
                                style: StrokeStyle(lineWidth: item.id == selectedId ? 4.5 : 2.5,
                                                   lineCap: .round, lineJoin: .round)
                            )
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat))
            .environment(\.colorScheme, AppearanceMode.mode(for: mapAppearance).colorScheme ?? systemScheme)
            .onTapGesture { screenPoint in
                guard mode == .tracks else { return }
                handleTap(at: screenPoint, proxy: proxy)
            }
        }
        .safeAreaInset(edge: .top) {
            Picker("Ansicht", selection: $mode) {
                ForEach(ViewMode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(.regularMaterial)
        }
        .overlay(alignment: .bottom) {
            if mode == .tracks, let selected {
                infoCard(selected)
            }
        }
        .overlay(alignment: .bottomLeading) {
            if mode == .heat {
                heatLegend
            }
        }
        .navigationTitle("Rückblick")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button {
                showFilter = true
            } label: {
                Image(systemName: hiddenDeviceIds.isEmpty && rangeStart == nil && rangeEnd == nil
                      ? "line.3.horizontal.decrease.circle"
                      : "line.3.horizontal.decrease.circle.fill")
            }
            .accessibilityLabel("Zeitraum und Geräte wählen")
        }
        .sheet(isPresented: $showFilter) { filterSheet }
        .onChange(of: mode) { _, _ in
            selectedId = nil
            isolate = false
            rebuildHeatmap()
        }
        .onChange(of: hiddenDeviceIds) { _, _ in rebuildHeatmap() }
        .onChange(of: rangeStart) { _, _ in rebuildHeatmap() }
        .onChange(of: rangeEnd) { _, _ in rebuildHeatmap() }
        .task { load() }
    }

    // MARK: - Filter (Zeitraum + Geräte)

    private var filterSheet: some View {
        NavigationStack {
            Form {
                Section("Zeitraum") {
                    DatePicker(
                        "Von",
                        selection: Binding(
                            get: { rangeStart ?? dataRange.lowerBound },
                            set: { rangeStart = $0 }
                        ),
                        in: dataRange,
                        displayedComponents: .date
                    )
                    DatePicker(
                        "Bis",
                        selection: Binding(
                            get: { rangeEnd ?? dataRange.upperBound },
                            set: { rangeEnd = $0 }
                        ),
                        in: dataRange,
                        displayedComponents: .date
                    )
                    Button("Gesamten Zeitraum zeigen") {
                        rangeStart = nil
                        rangeEnd = nil
                    }
                    .disabled(rangeStart == nil && rangeEnd == nil)
                }
                Section("Geräte") {
                    ForEach(devices) { device in
                        let hidden = hiddenDeviceIds.contains(device.id)
                        Button {
                            if hidden {
                                hiddenDeviceIds.remove(device.id)
                            } else {
                                hiddenDeviceIds.insert(device.id)
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(TrackColorStore.shared.color(forId: device.id, fallbackIndex: deviceIndex[device.id] ?? 0))
                                    .frame(width: 14, height: 14)
                                    .opacity(hidden ? 0.35 : 1)
                                Text(device.name)
                                    .foregroundStyle(hidden ? .secondary : .primary)
                                Spacer()
                                Image(systemName: hidden ? "circle" : "checkmark.circle.fill")
                                    .foregroundStyle(hidden ? Color.secondary : Color.accentColor)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                Section {
                    LabeledContent("Ausgewählte Tage", value: "\(Set(filteredItems.map(\.dayKey)).count)")
                }
            }
            .navigationTitle("Auswahl")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Fertig") { showFilter = false }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Heatmap

    /// Regenbogen-Skala: Lila (Farbwinkel 0,78) für die wenigsten
    /// Besuche, über Blau/Grün/Gelb/Orange bis Rot (0,0) für die
    /// meisten. Logarithmisch, damit nicht ein einziger oft besuchter
    /// Ort alle anderen in Lila drückt. Quantisiert in 12 Stufen —
    /// dadurch verschmelzen benachbarte Streckenabschnitte gleicher
    /// Stufe zu einem Linienzug (weniger Karten-Objekte).
    private static func level(count: Int, maxCount: Int) -> Int {
        guard maxCount > 1 else { return heatLevels - 1 }
        let t = log(Double(max(count, 1))) / log(Double(maxCount))
        return min(heatLevels - 1, Int(t * Double(heatLevels - 1) + 0.5))
    }

    private static func levelColor(_ level: Int) -> Color {
        let t = Double(level) / Double(heatLevels - 1)
        return Color(hue: 0.78 * (1 - t), saturation: 0.9, brightness: 0.95)
    }

    private var heatLegend: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Besuche (Durchfahrten pro Ort)")
                .font(.caption.bold())
            HStack(spacing: 8) {
                Text("1")
                LinearGradient(
                    colors: stride(from: 0.0, through: 1.0, by: 0.125).map {
                        Color(hue: 0.78 * (1 - $0), saturation: 0.9, brightness: 0.95)
                    },
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(width: 140, height: 10)
                .clipShape(Capsule())
                Text("\(heatMax)")
            }
            .font(.caption.monospacedDigit())
            Text("Zählraster ≈ \(Int(Self.heatGridMeters)) m · \(Set(filteredItems.map(\.dayKey)).count) Tage")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding()
    }

    private struct CellKey: Hashable {
        let x: Int
        let y: Int
    }

    /// Heatmap in zwei Schritten:
    /// 1. Zählen — Punkte in ein ~120-m-Raster binnen; pro Zelle
    ///    werden die Zeitstempel gesammelt und daraus DURCHFAHRTEN
    ///    gezählt: Ein neuer Besuch beginnt, wenn > 15 min zwischen
    ///    zwei Vorbeikommen liegen. Hin- und Rückweg am selben Tag
    ///    zählen so doppelt; zwei Geräte, die dieselbe Fahrt parallel
    ///    aufzeichnen, zählen nur einmal (Zeitstempel verschmelzen).
    /// 2. Zeichnen — jede Spur wird in Abschnitte gleicher Farbstufe
    ///    zerlegt und als Linie gezeichnet (wie die Tagesansicht),
    ///    kalte Stufen zuerst, heiße obenauf.
    private func rebuildHeatmap() {
        guard mode == .heat else { return }
        let filtered = filteredItems
        guard let anchor = filtered.first?.points.first else {
            heatSegments = []
            heatMax = 1
            return
        }
        let latMeters = 111_320.0
        let midLatCos = max(cos(anchor.lat * .pi / 180), 0.2)
        let dLat = Self.heatGridMeters / latMeters
        let dLon = Self.heatGridMeters / (latMeters * midLatCos)
        func cellKey(_ point: TrackPoint) -> CellKey {
            CellKey(x: Int(floor(point.lat / dLat)), y: Int(floor(point.lon / dLon)))
        }

        // Schritt 1: Zeitstempel je Zelle sammeln, Durchfahrten zählen.
        var stamps: [CellKey: [Date]] = [:]
        for item in filtered {
            for point in item.points {
                stamps[cellKey(point), default: []].append(point.t)
            }
        }
        var counts: [CellKey: Int] = [:]
        counts.reserveCapacity(stamps.count)
        for (key, times) in stamps {
            let sorted = times.sorted()
            var visits = 1
            var last = sorted[0]
            for time in sorted.dropFirst() {
                if time.timeIntervalSince(last) > 900 { visits += 1 }
                last = time
            }
            counts[key] = visits
        }
        heatMax = counts.values.max() ?? 1

        // Schritt 2: Spuren in Abschnitte gleicher Farbstufe zerlegen.
        var segments: [HeatSegment] = []
        var nextId = 0
        for item in filtered {
            var runCoordinates: [CLLocationCoordinate2D] = []
            var runLevel = -1
            func closeRun() {
                if runCoordinates.count > 1 {
                    segments.append(HeatSegment(id: nextId, coordinates: runCoordinates, level: runLevel))
                    nextId += 1
                }
            }
            for point in item.points {
                let level = Self.level(count: counts[cellKey(point)] ?? 1, maxCount: heatMax)
                if level != runLevel {
                    let bridge = runCoordinates.last
                    closeRun()
                    // Brückenpunkt: der Abschnittswechsel darf keine
                    // Lücke in der Linie reißen.
                    runCoordinates = bridge.map { [$0] } ?? []
                    runLevel = level
                }
                runCoordinates.append(point.coordinate)
            }
            closeRun()
        }
        heatSegments = segments.sorted { $0.level < $1.level }
    }

    // MARK: - Auswahl per Tipp (nur Spuren-Modus)

    private func handleTap(at screenPoint: CGPoint, proxy: MapProxy) {
        guard let tapCoordinate = proxy.convert(screenPoint, from: .local),
              let edgeCoordinate = proxy.convert(CGPoint(x: screenPoint.x + 30, y: screenPoint.y), from: .local) else {
            return
        }
        let tapLocation = CLLocation(latitude: tapCoordinate.latitude, longitude: tapCoordinate.longitude)
        // Toleranz: 30 Bildschirmpunkte, in Meter der aktuellen Zoomstufe.
        let tolerance = tapLocation.distance(from: CLLocation(latitude: edgeCoordinate.latitude, longitude: edgeCoordinate.longitude))

        var bestId: String?
        var bestDistance = Double.infinity
        for item in filteredItems {
            for point in item.points {
                let d = tapLocation.distance(from: CLLocation(latitude: point.lat, longitude: point.lon))
                if d < bestDistance {
                    bestDistance = d
                    bestId = item.id
                }
            }
        }

        if let bestId, bestDistance <= tolerance {
            selectedId = bestId
            if let item = filteredItems.first(where: { $0.id == bestId }) {
                withAnimation {
                    position = .rect(paddedRect(for: item))
                }
            }
        } else {
            selectedId = nil
            isolate = false
        }
    }

    private func paddedRect(for item: TrackItem) -> MKMapRect {
        var rect = MKMapRect.null
        for point in item.points {
            let mapPoint = MKMapPoint(point.coordinate)
            rect = rect.union(MKMapRect(x: mapPoint.x, y: mapPoint.y, width: 0, height: 0))
        }
        return rect.insetBy(dx: -rect.width * 0.25 - 2000, dy: -rect.height * 0.25 - 2000)
    }

    // MARK: - Infokarte

    private func infoCard(_ item: TrackItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(DayKey.displayName(for: item.dayKey))
                        .font(.headline)
                    Text(item.ownerName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    selectedId = nil
                    isolate = false
                    withAnimation { position = .automatic }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 14) {
                Label(distanceText(item.distanceMeters), systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                Label(durationText(from: item.start, to: item.end), systemImage: "clock")
                Label("\(item.pointCount) Punkte", systemImage: "smallcircle.filled.circle")
            }
            .font(.footnote.monospacedDigit())
            .foregroundStyle(.secondary)
            Toggle("Nur diesen Track zeigen", isOn: $isolate)
                .font(.subheadline)
            NavigationLink(value: item.dayKey) {
                Label("Tagesdetail öffnen (Aufenthalte, Fotos, Replay, Export)", systemImage: "chevron.right.circle.fill")
                    .font(.subheadline.bold())
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding()
    }

    private func distanceText(_ meters: Double) -> String {
        meters >= 1000
            ? String(format: "%.1f km", meters / 1000)
            : String(format: "%.0f m", meters)
    }

    private func durationText(from start: Date, to end: Date) -> String {
        let minutes = max(Int(end.timeIntervalSince(start) / 60), 0)
        return minutes >= 60 ? "\(minutes / 60) h \(minutes % 60) min" : "\(minutes) min"
    }

    // MARK: - Daten

    private func load() {
        guard items.isEmpty else { return }
        let own = (try? context.fetch(FetchDescriptor<TrackDay>())) ?? []
        let family = (try? context.fetch(FetchDescriptor<FamilyDay>())) ?? []

        // 1500 Punkte je Tag: Bei langen Fahrten (200 km) muss jede
        // Durchfahrt in jedem ~120-m-Rasterfeld noch einen Punkt
        // hinterlassen, sonst zählt die Heatmap Passagen doppelt
        // vorbeigefahrener Strecken nicht sauber.
        var list: [TrackItem] = own.map { day in
            TrackItem(
                id: "own-\(day.deviceId)-\(day.dayKey)",
                dayKey: day.dayKey,
                deviceId: day.deviceId,
                ownerName: day.deviceName.isEmpty ? "Gerät" : day.deviceName,
                points: TrackMath.downsample(day.points(), maxCount: 1500),
                pointCount: day.pointCount,
                distanceMeters: day.distanceMeters,
                start: day.startDate,
                end: day.endDate
            )
        }
        list += family.map { day in
            TrackItem(
                id: "fam-\(day.recordName)",
                dayKey: day.dayKey,
                deviceId: day.deviceId.isEmpty ? day.recordName : day.deviceId,
                ownerName: day.displayName,
                points: TrackMath.downsample(day.points(), maxCount: 1500),
                pointCount: day.pointCount,
                distanceMeters: day.distanceMeters,
                start: day.startDate,
                end: day.endDate
            )
        }
        items = list.filter { $0.points.count > 1 }
        rebuildHeatmap()
    }
}
