import Foundation
import SwiftData
import CoreLocation

/// Erzeugt pro Tag eine kurze Beschreibung aus bis zu drei Orten entlang
/// des Tracks („Neustadt – Bergdorf – Seeblick“).
///
/// Deterministische Granularität: Fernstrecken (> 30 km Strecke oder
/// > 15 km Ausdehnung) nennen die erreichten Städte, Runden in der
/// näheren Umgebung die Ortsteile bzw. markante Orte am Wegesrand.
/// Berechnet wird einmalig pro (vergangenem) Tag aus Stichproben entlang
/// des Tracks per Reverse-Geocoding; das Ergebnis wird im Tages-Datensatz
/// gespeichert und synct damit über iCloud und die Familienfreigabe.
enum DaySummarizer {
    /// Merker „berechnet, aber nichts gefunden“ — verhindert Dauerschleifen.
    static let noResult = "—"

    private static let samplesPerDay = 6
    private static let longTripDistance: Double = 30_000
    private static let longTripDiameter: Double = 15_000

    /// Ergänzt fehlende Beschreibungen der eigenen Tage (neueste zuerst,
    /// pro Aufruf begrenzt — Reverse-Geocoding ist gedrosselt).
    static func updateMissingSummaries(container: ModelContainer, maxDays: Int = 5) async {
        let context = ModelContext(container)
        let deviceId = DeviceInfo.deviceId
        let today = DayKey.key(for: Date())
        let predicate = #Predicate<TrackDay> {
            $0.deviceId == deviceId && $0.summary == "" && $0.dayKey < today && $0.pointCount > 1
        }
        var descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\TrackDay.dayKey, order: .reverse)])
        descriptor.fetchLimit = maxDays
        guard let days = try? context.fetch(descriptor), !days.isEmpty else { return }

        for day in days {
            let text = await summary(for: day.points(), distanceMeters: day.distanceMeters)
            day.summary = text.isEmpty ? noResult : text
            day.updatedAt = Date()
            try? context.save()
        }
    }

    static func summary(for points: [TrackPoint], distanceMeters: Double) async -> String {
        guard points.count > 1,
              let minLat = points.map(\.lat).min(), let maxLat = points.map(\.lat).max(),
              let minLon = points.map(\.lon).min(), let maxLon = points.map(\.lon).max() else {
            return ""
        }
        let diameter = CLLocation(latitude: minLat, longitude: minLon)
            .distance(from: CLLocation(latitude: maxLat, longitude: maxLon))
        let isLongTrip = distanceMeters > longTripDistance || diameter > longTripDiameter

        var names: [String] = []
        for point in sampleByDistance(points, count: samplesPerDay) {
            guard let info = await Geocoder.shared.info(for: point.coordinate) else { continue }
            let name: String
            if isLongTrip {
                name = info.locality
            } else {
                name = firstNonEmpty(
                    info.subLocality,
                    info.areas.components(separatedBy: ", ").first ?? "",
                    info.name,
                    info.locality
                )
            }
            if !name.isEmpty, names.last != name {
                names.append(name)
            }
        }

        var distinct: [String] = []
        for name in names where !distinct.contains(name) {
            distinct.append(name)
        }
        guard !distinct.isEmpty else { return "" }
        let picked = distinct.count <= 3
            ? distinct
            : [distinct[0], distinct[distinct.count / 2], distinct[distinct.count - 1]]
        return picked.joined(separator: " – ")
    }

    // MARK: - Helfer

    private static func firstNonEmpty(_ values: String...) -> String {
        values.first { !$0.isEmpty } ?? ""
    }

    /// Gleichmäßige Stichproben entlang der zurückgelegten Strecke
    /// (nicht der Zeit — lange Pausen verzerren sonst die Auswahl).
    private static func sampleByDistance(_ points: [TrackPoint], count: Int) -> [TrackPoint] {
        guard points.count > count else { return points }
        var cumulative: [Double] = [0]
        cumulative.reserveCapacity(points.count)
        for i in 1..<points.count {
            let a = CLLocation(latitude: points[i - 1].lat, longitude: points[i - 1].lon)
            let b = CLLocation(latitude: points[i].lat, longitude: points[i].lon)
            cumulative.append(cumulative[i - 1] + b.distance(from: a))
        }
        guard let total = cumulative.last, total > 0 else { return [points[0]] }
        return (0..<count).map { i in
            let target = total * Double(i) / Double(count - 1)
            let index = cumulative.firstIndex { $0 >= target } ?? points.count - 1
            return points[index]
        }
    }
}
