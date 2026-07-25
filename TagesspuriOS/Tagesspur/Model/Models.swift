import Foundation
import SwiftData
import CoreLocation
#if os(iOS)
import UIKit
#endif

// MARK: - Trackpunkt (als kompakter Blob im TrackDay gespeichert)

/// Ein einzelner Messpunkt. Wird nicht als eigener Datensatz gespeichert,
/// sondern gebündelt pro Tag — das hält den CloudKit-Sync klein.
struct TrackPoint: Codable, Hashable {
    var t: Date
    var lat: Double
    var lon: Double
    var alt: Double
    var hAcc: Double
    var speed: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    init(location: CLLocation) {
        t = location.timestamp
        lat = location.coordinate.latitude
        lon = location.coordinate.longitude
        alt = location.altitude
        hAcc = location.horizontalAccuracy
        speed = max(location.speed, 0)
    }

    init(t: Date, lat: Double, lon: Double, alt: Double = 0, hAcc: Double = 0, speed: Double = 0) {
        self.t = t
        self.lat = lat
        self.lon = lon
        self.alt = alt
        self.hAcc = hAcc
        self.speed = speed
    }
}

// MARK: - Tages-Track

/// Der Track eines Tages auf einem Gerät. Jedes Gerät schreibt ausschließlich
/// Datensätze mit seiner eigenen deviceId; über CloudKit sehen alle Geräte alles.
@Model
final class TrackDay {
    var deviceId: String = ""
    var deviceName: String = ""
    var dayKey: String = ""          // "2026-07-25", lokale Zeitzone bei Aufzeichnung
    var pointsData: Data = Data()    // JSON-kodiertes [TrackPoint]
    var pointCount: Int = 0
    var distanceMeters: Double = 0
    var startDate: Date = Date()
    var endDate: Date = Date()
    var updatedAt: Date = Date()

    init(deviceId: String, deviceName: String, dayKey: String) {
        self.deviceId = deviceId
        self.deviceName = deviceName
        self.dayKey = dayKey
    }

    func points() -> [TrackPoint] {
        guard !pointsData.isEmpty else { return [] }
        return (try? JSONDecoder.tagesspur.decode([TrackPoint].self, from: pointsData)) ?? []
    }

    func setPoints(_ pts: [TrackPoint]) {
        let sorted = pts.sorted { $0.t < $1.t }
        pointsData = (try? JSONEncoder.tagesspur.encode(sorted)) ?? Data()
        pointCount = sorted.count
        distanceMeters = Self.distance(of: sorted)
        if let first = sorted.first { startDate = first.t }
        if let last = sorted.last { endDate = last.t }
        updatedAt = Date()
    }

    func appendPoints(_ new: [TrackPoint]) {
        guard !new.isEmpty else { return }
        var pts = points()
        let known = Set(pts.map(\.t))
        pts.append(contentsOf: new.filter { !known.contains($0.t) })
        setPoints(pts)
    }

    static func distance(of pts: [TrackPoint]) -> Double {
        guard pts.count > 1 else { return 0 }
        var total: Double = 0
        for i in 1..<pts.count {
            let a = CLLocation(latitude: pts[i - 1].lat, longitude: pts[i - 1].lon)
            let b = CLLocation(latitude: pts[i].lat, longitude: pts[i].lon)
            total += b.distance(from: a)
        }
        return total
    }
}

// MARK: - Aufenthalt

/// Ein erkannter Aufenthalt (CLVisit), angereichert per Reverse-Geocoding.
/// Grundlage für die Ort-Suche („an einem See").
@Model
final class PlaceVisit {
    var deviceId: String = ""
    var deviceName: String = ""
    var dayKey: String = ""
    var arrival: Date = Date()
    var departure: Date = Date()
    var latitude: Double = 0
    var longitude: Double = 0
    var name: String = ""            // Placemark-Name bzw. Sehenswürdigkeit
    var locality: String = ""        // Ort/Stadt
    var thoroughfare: String = ""    // Straße
    var inlandWater: String = ""     // Binnengewässer (See, Fluss …)
    var ocean: String = ""           // Meer
    var areas: String = ""           // areasOfInterest, kommagetrennt
    var geocoded: Bool = false
    var updatedAt: Date = Date()

    init(deviceId: String, deviceName: String, dayKey: String, arrival: Date, departure: Date, latitude: Double, longitude: Double) {
        self.deviceId = deviceId
        self.deviceName = deviceName
        self.dayKey = dayKey
        self.arrival = arrival
        self.departure = departure
        self.latitude = latitude
        self.longitude = longitude
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var title: String {
        if !name.isEmpty { return name }
        if !thoroughfare.isEmpty { return thoroughfare }
        if !locality.isEmpty { return locality }
        return String(format: "%.4f, %.4f", latitude, longitude)
    }

    var subtitle: String {
        var parts: [String] = []
        if !locality.isEmpty && locality != title { parts.append(locality) }
        if !inlandWater.isEmpty { parts.append(inlandWater) }
        if !ocean.isEmpty { parts.append(ocean) }
        return parts.joined(separator: " · ")
    }

    /// Alle Textfelder, über die die Suche läuft.
    var searchText: String {
        [name, locality, thoroughfare, inlandWater, ocean, areas]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .lowercased()
    }
}

// MARK: - Tages-Schlüssel & Kodierung

enum DayKey {
    static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func key(for date: Date) -> String {
        formatter.string(from: date)
    }

    static func date(for key: String) -> Date? {
        formatter.date(from: key)
    }

    /// Anzeigename, z. B. „Fr., 25. Juli 2026".
    static func displayName(for key: String) -> String {
        guard let date = date(for: key) else { return key }
        return date.formatted(.dateTime.weekday(.abbreviated).day().month(.wide).year())
    }

    static func dayRange(for key: String) -> ClosedRange<Date>? {
        guard let start = date(for: key) else { return nil }
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        return start...end.addingTimeInterval(-1)
    }
}

extension JSONEncoder {
    static let tagesspur: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
}

extension JSONDecoder {
    static let tagesspur: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}

// MARK: - Geräteidentität

enum DeviceInfo {
    private static let idKey = "tagesspur.deviceId"
    private static let nameKey = "tagesspur.deviceName"

    /// Stabile, zufällige Geräte-ID (kein Hardware-Identifier — Datenminimierung).
    static var deviceId: String {
        if let id = UserDefaults.standard.string(forKey: idKey) { return id }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: idKey)
        return id
    }

    static var deviceName: String {
        get {
            UserDefaults.standard.string(forKey: nameKey) ?? defaultName
        }
        set {
            UserDefaults.standard.set(newValue, forKey: nameKey)
        }
    }

    static var defaultName: String {
        #if os(iOS)
        return UIDevice.current.model
        #else
        return "Gerät"
        #endif
    }
}
