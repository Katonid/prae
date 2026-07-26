import SwiftUI
import SwiftData
import MapKit
import CoreLocation

/// Gesamtkarte: alle jemals aufgezeichneten Tracks (eigene Geräte und
/// Familie). Antippen wählt einen Track aus — er wird hervorgehoben,
/// eine Infokarte zeigt die Details, optional lässt er sich isoliert
/// darstellen oder das Tagesdetail öffnen.
struct AllTracksMapView: View {
    struct TrackItem: Identifiable {
        let id: String
        let dayKey: String
        let ownerName: String
        let points: [TrackPoint]
        let pointCount: Int
        let distanceMeters: Double
        let start: Date
        let end: Date
    }

    @Environment(\.modelContext) private var context
    @AppStorage(AppearanceMode.mapKey) private var mapAppearance = AppearanceMode.system.rawValue
    @Environment(\.colorScheme) private var systemScheme

    @State private var items: [TrackItem] = []
    @State private var selectedId: String?
    @State private var isolate = false
    @State private var position: MapCameraPosition = .automatic

    private var selected: TrackItem? {
        items.first { $0.id == selectedId }
    }

    /// Ausgewählter Track zuletzt gezeichnet = obenauf.
    private var displayed: [TrackItem] {
        if isolate, let selected { return [selected] }
        guard let selectedId else { return items }
        return items.filter { $0.id != selectedId } + items.filter { $0.id == selectedId }
    }

    var body: some View {
        MapReader { proxy in
            Map(position: $position) {
                ForEach(displayed) { item in
                    ForEach(Array(TrackMath.segments(item.points).enumerated()), id: \.offset) { _, segment in
                        MapPolyline(coordinates: segment.map(\.coordinate))
                            .stroke(
                                item.id == selectedId ? Color.orange : Theme.petrol.opacity(0.7),
                                style: StrokeStyle(lineWidth: item.id == selectedId ? 4.5 : 2.5,
                                                   lineCap: .round, lineJoin: .round)
                            )
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat))
            .environment(\.colorScheme, AppearanceMode.mode(for: mapAppearance).colorScheme ?? systemScheme)
            .onTapGesture { screenPoint in
                handleTap(at: screenPoint, proxy: proxy)
            }
        }
        .overlay(alignment: .bottom) {
            if let selected {
                infoCard(selected)
            }
        }
        .navigationTitle("Alle Tracks")
        .navigationBarTitleDisplayMode(.inline)
        .task { load() }
    }

    // MARK: - Auswahl per Tipp

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
        for item in items {
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
            if let item = items.first(where: { $0.id == bestId }) {
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

        var list: [TrackItem] = own.map { day in
            TrackItem(
                id: "own-\(day.deviceId)-\(day.dayKey)",
                dayKey: day.dayKey,
                ownerName: day.deviceName.isEmpty ? "Gerät" : day.deviceName,
                points: TrackMath.downsample(day.points(), maxCount: 150),
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
                ownerName: day.displayName,
                points: TrackMath.downsample(day.points(), maxCount: 150),
                pointCount: day.pointCount,
                distanceMeters: day.distanceMeters,
                start: day.startDate,
                end: day.endDate
            )
        }
        items = list.filter { $0.points.count > 1 }
    }
}
