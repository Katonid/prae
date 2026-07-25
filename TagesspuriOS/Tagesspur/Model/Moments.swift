import Foundation
import CoreLocation

/// Ein „Moment“: zeitlich und räumlich zusammenhängende Aufnahmen eines
/// Tages, wenn möglich einem Aufenthalt zugeordnet.
struct Moment: Identifiable {
    let items: [MediaItem]
    let start: Date
    let end: Date
    let coordinate: CLLocationCoordinate2D?
    let placeName: String

    var id: String { items.first?.id ?? "\(start.timeIntervalSince1970)" }

    var timeText: String {
        let s = start.formatted(date: .omitted, time: .shortened)
        let e = end.formatted(date: .omitted, time: .shortened)
        return s == e ? s : "\(s) – \(e)"
    }

    var title: String {
        placeName.isEmpty ? timeText : "\(timeText) · \(placeName)"
    }
}

/// Deterministische Gruppierung: neue Gruppe bei mehr als 45 Minuten
/// Pause oder mehr als 500 m Abstand zwischen zwei Aufnahmen.
enum MomentBuilder {
    private static let maxGap: TimeInterval = 45 * 60
    private static let maxDistance: CLLocationDistance = 500

    static func moments(from items: [MediaItem], visits: [PlaceVisit]) -> [Moment] {
        let sorted = items.sorted { $0.date < $1.date }
        guard !sorted.isEmpty else { return [] }

        var groups: [[MediaItem]] = []
        var current: [MediaItem] = []
        var lastDate: Date?
        var lastCoordinate: CLLocationCoordinate2D?

        for item in sorted {
            var isBreak = false
            if let lastDate, item.date.timeIntervalSince(lastDate) > maxGap {
                isBreak = true
            }
            if let a = lastCoordinate, let b = item.coordinate {
                let d = CLLocation(latitude: a.latitude, longitude: a.longitude)
                    .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
                if d > maxDistance { isBreak = true }
            }
            if isBreak, !current.isEmpty {
                groups.append(current)
                current = []
            }
            current.append(item)
            lastDate = item.date
            if let c = item.coordinate { lastCoordinate = c }
        }
        if !current.isEmpty { groups.append(current) }

        return groups.map { group in
            let coords = group.compactMap(\.coordinate)
            let center: CLLocationCoordinate2D? = coords.isEmpty ? nil : CLLocationCoordinate2D(
                latitude: coords.map(\.latitude).reduce(0, +) / Double(coords.count),
                longitude: coords.map(\.longitude).reduce(0, +) / Double(coords.count)
            )
            return Moment(
                items: group,
                start: group.first?.date ?? Date(),
                end: group.last?.date ?? Date(),
                coordinate: center,
                placeName: placeName(for: group, center: center, visits: visits)
            )
        }
    }

    /// Passender Aufenthalt: zeitliche Überlappung gewinnt, sonst der
    /// nächstgelegene Aufenthalt innerhalb von 300 m.
    private static func placeName(for group: [MediaItem], center: CLLocationCoordinate2D?, visits: [PlaceVisit]) -> String {
        guard let first = group.first?.date, let last = group.last?.date else { return "" }
        if let overlap = visits.first(where: { $0.arrival <= last && $0.departure >= first && !$0.title.isEmpty }) {
            return overlap.title
        }
        guard let center else { return "" }
        let location = CLLocation(latitude: center.latitude, longitude: center.longitude)
        let nearest = visits
            .map { (visit: $0, distance: location.distance(from: CLLocation(latitude: $0.latitude, longitude: $0.longitude))) }
            .min { $0.distance < $1.distance }
        if let nearest, nearest.distance <= 300, !nearest.visit.title.isEmpty {
            return nearest.visit.title
        }
        return ""
    }
}
