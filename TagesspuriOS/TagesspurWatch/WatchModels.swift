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
    // .externalStorage unverändert (wie iPhone-Modell — ein Entfernen
    // erzwingt eine Store-Migration, siehe 1.4.17-Absturz). Der Blob
    // wird zlib-komprimiert und klein gehalten, damit CoreData ihn
    // immer als Bytes ins vorhandene CloudKit-Feld exportiert.
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
        return Self.decodePoints(pointsData)
    }

    /// Beide Formate lesbar: zlib-komprimiert (neu) und pures
    /// Alt-JSON (beginnt mit „[“) — identisch zum iPhone-Modell.
    static func decodePoints(_ data: Data) -> [TrackPoint] {
        if data.first == 0x5B {
            return (try? JSONDecoder.tagesspur.decode([TrackPoint].self, from: data)) ?? []
        }
        guard let json = try? (data as NSData).decompressed(using: .zlib) as Data else { return [] }
        return (try? JSONDecoder.tagesspur.decode([TrackPoint].self, from: json)) ?? []
    }

    static func encodePoints(_ pts: [TrackPoint]) -> Data {
        let json = (try? JSONEncoder.tagesspur.encode(pts)) ?? Data()
        return (try? (json as NSData).compressed(using: .zlib) as Data) ?? json
    }

    static let maxPointsDataBytes = 400_000

    func setPoints(_ pts: [TrackPoint]) {
        var sorted = Self.removeSpikes(pts.sorted { $0.t < $1.t })
        var data = Self.encodePoints(sorted)
        // Notbremse wie auf dem iPhone: Blob muss ins Bytes-Feld passen.
        while data.count > Self.maxPointsDataBytes, sorted.count > 1000 {
            sorted = Self.downsample(sorted, maxCount: sorted.count * 3 / 4)
            data = Self.encodePoints(sorted)
        }
        pointsData = data
        pointCount = sorted.count
        distanceMeters = Self.distance(of: sorted)
        if let first = sorted.first { startDate = first.t }
        if let last = sorted.last { endDate = last.t }
        updatedAt = Date()
    }

    static func downsample(_ points: [TrackPoint], maxCount: Int) -> [TrackPoint] {
        guard points.count > maxCount, maxCount > 2 else { return points }
        let step = Double(points.count - 1) / Double(maxCount - 1)
        return (0..<maxCount).map { points[Int(Double($0) * step)] }
    }

    /// Zacken-Radierer — identisch zum iPhone-Modell (TrackMath).
    static func removeSpikes(_ points: [TrackPoint]) -> [TrackPoint] {
        guard points.count >= 3 else { return points }
        func meters(_ a: TrackPoint, _ b: TrackPoint) -> Double {
            CLLocation(latitude: a.lat, longitude: a.lon)
                .distance(from: CLLocation(latitude: b.lat, longitude: b.lon))
        }
        var kept: [TrackPoint] = [points[0]]
        for i in 1..<(points.count - 1) {
            let a = kept[kept.count - 1]
            let b = points[i]
            let c = points[i + 1]
            let ab = meters(a, b)
            let bc = meters(b, c)
            guard ab > 500, bc > 500 else { kept.append(b); continue }
            let ac = meters(a, c)
            guard ac < 0.2 * min(ab, bc) else { kept.append(b); continue }
            let dtAB = b.t.timeIntervalSince(a.t)
            let dtBC = c.t.timeIntervalSince(b.t)
            let impossiblyFast = (dtAB > 0 && ab / dtAB > 70) || (dtBC > 0 && bc / dtBC > 70)
            if impossiblyFast || b.hAcc > 250 {
                continue
            }
            kept.append(b)
        }
        kept.append(points[points.count - 1])
        return kept
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
