import Foundation
import SwiftData
import CoreLocation

// Spiegel der iPhone-Modelle — nur das, was die Watch braucht.
// WICHTIG: Der @Model-Typ muss strukturell identisch zum
// iPhone-TrackDay sein (gleicher Entitätsname, gleiche Felder), damit
// beide Geräte dieselben CloudKit-Datensätze lesen und schreiben.

struct TrackPoint: Codable, Hashable {
    var t: Date
    var lat: Double
    var lon: Double
    var alt: Double
    var hAcc: Double
    var speed: Double

    init(location: CLLocation) {
        t = location.timestamp
        lat = location.coordinate.latitude
        lon = location.coordinate.longitude
        alt = location.altitude
        hAcc = location.horizontalAccuracy
        speed = max(location.speed, 0)
    }
}

@Model
final class TrackDay {
    var deviceId: String = ""
    var deviceName: String = ""
    var dayKey: String = ""
    @Attribute(.externalStorage) var pointsData: Data = Data()
    var pointCount: Int = 0
    var distanceMeters: Double = 0
    var startDate: Date = Date()
    var endDate: Date = Date()
    var summary: String = ""
    var summaryPointCount: Int = 0
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

/// Geräteidentität der Watch — eigene stabile Zufalls-ID, eigener Name.
/// Die Watch erscheint damit als eigenständiges Gerät neben iPhone/iPad.
enum WatchDeviceInfo {
    private static let idKey = "tagesspur.deviceId"
    private static let nameKey = "tagesspur.deviceName"

    static var deviceId: String {
        if let id = UserDefaults.standard.string(forKey: idKey) { return id }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: idKey)
        return id
    }

    static var deviceName: String {
        get { UserDefaults.standard.string(forKey: nameKey) ?? "Watch" }
        set { UserDefaults.standard.set(newValue, forKey: nameKey) }
    }
}
