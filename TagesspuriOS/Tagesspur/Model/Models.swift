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

// MARK: - Sync-Diagnose

/// Merkt sich, ob der Datenbank-Container mit CloudKit-Sync oder nur
/// lokal gestartet ist — die Einstellungen zeigen das an, statt dass
/// ein stiller Rückfall auf „nur lokal“ unbemerkt bleibt.
enum SyncDiagnose {
    static var cloudKitAktiv = false
}

// MARK: - Tages-Track

/// Der Track eines Tages auf einem Gerät. Jedes Gerät schreibt ausschließlich
/// Datensätze mit seiner eigenen deviceId; über CloudKit sehen alle Geräte alles.
@Model
final class TrackDay {
    var deviceId: String = ""
    var deviceName: String = ""
    var dayKey: String = ""          // "2026-07-25", lokale Zeitzone bei Aufzeichnung
    // .externalStorage bleibt UNVERÄNDERT (ein Entfernen erzwang am
    // 30.7. eine Store-Migration und ließ 1.4.17 beim Start
    // abstürzen). Entscheidend ist etwas anderes: Das CloudKit-Feld
    // CD_pointsData ist historisch BYTES (Dev UND Produktion, per
    // Console verifiziert) und CloudKit kann Feldtypen nie ändern.
    // Große Blobs würde CoreData als CKAsset in ein nirgends
    // existierendes Anhang-Feld exportieren → Server lehnte jeden
    // großen Tag fatal ab, der GESAMTE Sync stand (ab 4:59). Deshalb:
    // Blob zlib-komprimieren und per Notbremse klein halten — dann
    // exportiert CoreData immer Bytes und alles passt ins Feld.
    @Attribute(.externalStorage) var pointsData: Data = Data()    // zlib-komprimiertes JSON [TrackPoint]; Altbestand: pures JSON
    var pointCount: Int = 0
    var distanceMeters: Double = 0
    var startDate: Date = Date()
    var endDate: Date = Date()
    var summary: String = ""         // „Ort – Ort – Ort“ (DaySummarizer)
    /// Punktebestand, aus dem die Beschreibung berechnet wurde — weicht
    /// er vom aktuellen pointCount ab, wird die Beschreibung neu erzeugt
    /// (statt für immer auf veralteten Daten sitzen zu bleiben).
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

    /// Blob lesen — versteht beide Formate: zlib-komprimiert (neu)
    /// und pures JSON (Altbestand, beginnt mit „[“).
    static func decodePoints(_ data: Data) -> [TrackPoint] {
        if data.first == 0x5B {   // „[“ → unkomprimiertes Alt-JSON
            return (try? JSONDecoder.tagesspur.decode([TrackPoint].self, from: data)) ?? []
        }
        guard let json = try? (data as NSData).decompressed(using: .zlib) as Data else { return [] }
        return (try? JSONDecoder.tagesspur.decode([TrackPoint].self, from: json)) ?? []
    }

    static func encodePoints(_ pts: [TrackPoint]) -> Data {
        let json = (try? JSONEncoder.tagesspur.encode(pts)) ?? Data()
        return (try? (json as NSData).compressed(using: .zlib) as Data) ?? json
    }

    /// Obergrenze für den gespeicherten Blob: Das CloudKit-Bytes-Feld
    /// lebt im Datensatz (Limit ~1 MB), und CoreData darf den Blob
    /// nie für den Anhang-Export „groß genug“ finden — konservative
    /// 400 kB komprimiert entsprechen immer noch zigtausenden Punkten.
    static let maxPointsDataBytes = 400_000

    func setPoints(_ pts: [TrackPoint]) {
        var sorted = TrackMath.removeSpikes(pts.sorted { $0.t < $1.t })
        var data = Self.encodePoints(sorted)
        // Notbremse für Extremtage: schrittweise ausdünnen, bis der
        // Blob passt — ein leicht ausgedünnter Track ist ehrlicher
        // als ein Tag, der den gesamten Sync blockiert (4:59-Lehre).
        while data.count > Self.maxPointsDataBytes, sorted.count > 1000 {
            sorted = TrackMath.downsample(sorted, maxCount: sorted.count * 3 / 4)
            data = Self.encodePoints(sorted)
            LocationTracker.logEvent("Track-Blob ausgedünnt auf \(sorted.count) Punkte (Sync-Größengrenze)")
        }
        pointsData = data
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

// MARK: - Familie (lokaler Spiegel der geteilten CloudKit-Zone)

/// Tages-Track eines Familienmitglieds (andere Apple-ID), aus der
/// geteilten Zone geladen. Lokal-only (kein CloudKit-Sync dieses Typs),
/// damit keine Kopier-Schleifen entstehen — Quelle bleibt die Freigabe.
@Model
final class FamilyDay {
    @Attribute(.unique) var recordName: String = ""
    var memberName: String = ""
    /// CloudKit-Eigentümer der Freigabe-Zone — nötig, um eine einzelne
    /// Freigabe gezielt verlassen/aufräumen zu können.
    var ownerName: String = ""
    var deviceId: String = ""
    var deviceName: String = ""
    var dayKey: String = ""
    @Attribute(.externalStorage) var pointsData: Data = Data()
    var pointCount: Int = 0
    var distanceMeters: Double = 0
    var startDate: Date = Date()
    var endDate: Date = Date()
    var summary: String = ""
    var updatedAt: Date = Date()

    init(recordName: String) {
        self.recordName = recordName
    }

    /// Person + Gerät, damit mehrere Geräte eines Familienmitglieds
    /// unterscheidbar bleiben („Anna · iPhone“, „Anna · iPad“).
    var displayName: String {
        let member = memberName.isEmpty ? "Familie" : memberName
        guard !deviceName.isEmpty, deviceName != member else { return member }
        return "\(member) · \(deviceName)"
    }

    func points() -> [TrackPoint] {
        guard !pointsData.isEmpty else { return [] }
        return (try? JSONDecoder.tagesspur.decode([TrackPoint].self, from: pointsData)) ?? []
    }
}

/// Aufenthalt eines Familienmitglieds aus der geteilten Zone.
@Model
final class FamilyVisit {
    @Attribute(.unique) var recordName: String = ""
    var memberName: String = ""
    var ownerName: String = ""
    var dayKey: String = ""
    var arrival: Date = Date()
    var departure: Date = Date()
    var latitude: Double = 0
    var longitude: Double = 0
    var name: String = ""
    var locality: String = ""
    var thoroughfare: String = ""
    var inlandWater: String = ""
    var ocean: String = ""
    var areas: String = ""

    init(recordName: String) {
        self.recordName = recordName
    }
}

// MARK: - Gemeinsame Anzeige-Struktur für eigene und Familien-Aufenthalte

/// Wertkopie eines Aufenthalts — eigene und Familien-Besuche in einer
/// Form, damit Karte, Tagesdetail, Momente und Suche einheitlich arbeiten.
struct VisitInfo: Identifiable {
    var dayKey: String
    var arrival: Date
    var departure: Date
    var latitude: Double
    var longitude: Double
    var name: String
    var locality: String
    var thoroughfare: String
    var inlandWater: String
    var ocean: String
    var areas: String
    var owner: String    // "" = eigene Daten, sonst Name des Familienmitglieds

    var id: String {
        "\(dayKey)-\(arrival.timeIntervalSince1970)-\(latitude)-\(longitude)-\(owner)"
    }

    init(_ visit: PlaceVisit) {
        dayKey = visit.dayKey
        arrival = visit.arrival
        departure = visit.departure
        latitude = visit.latitude
        longitude = visit.longitude
        name = visit.name
        locality = visit.locality
        thoroughfare = visit.thoroughfare
        inlandWater = visit.inlandWater
        ocean = visit.ocean
        areas = visit.areas
        owner = ""
    }

    init(_ visit: FamilyVisit) {
        dayKey = visit.dayKey
        arrival = visit.arrival
        departure = visit.departure
        latitude = visit.latitude
        longitude = visit.longitude
        name = visit.name
        locality = visit.locality
        thoroughfare = visit.thoroughfare
        inlandWater = visit.inlandWater
        ocean = visit.ocean
        areas = visit.areas
        owner = visit.memberName.isEmpty ? "Familie" : visit.memberName
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
        if !owner.isEmpty { parts.append(owner) }
        if !locality.isEmpty && locality != title { parts.append(locality) }
        if !inlandWater.isEmpty { parts.append(inlandWater) }
        if !ocean.isEmpty { parts.append(ocean) }
        return parts.joined(separator: " · ")
    }

    var searchText: String {
        [name, locality, thoroughfare, inlandWater, ocean, areas]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .lowercased()
    }
}

// MARK: - Track-Mathematik

enum TrackMath {
    /// Zacken-Radierer: Entfernt Einzelpunkt-Ausreißer. Ein Punkt, der
    /// von BEIDEN Nachbarn > 500 m entfernt liegt, während die
    /// Nachbarn nahe beieinander sind, ist keine Bewegung — niemand
    /// fährt kilometerweit raus und ist beim nächsten Messpunkt wieder
    /// am Ausgangspunkt. Sichtbar als kilometerlange „Strahlen“ vom
    /// Aufenthaltsort (Kanada, 1.8.): Funkzellen-Streu-Fixe, die durch
    /// die > 2-min-Lücke des Geschwindigkeits-Filters rutschten.
    /// Verworfen wird nur, wenn zusätzlich die Sprunggeschwindigkeit
    /// unmöglich (> 250 km/h) ODER der Fix grob (±250 m+) war —
    /// echte Strecken bleiben unangetastet.
    static func removeSpikes(_ points: [TrackPoint]) -> [TrackPoint] {
        guard points.count >= 3 else { return points }
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
                continue   // b ist eine Zacke — verwerfen
            }
            kept.append(b)
        }
        kept.append(points[points.count - 1])
        return kept
    }

    private static func meters(_ a: TrackPoint, _ b: TrackPoint) -> Double {
        CLLocation(latitude: a.lat, longitude: a.lon)
            .distance(from: CLLocation(latitude: b.lat, longitude: b.lon))
    }

    /// Gleichmäßiges Ausdünnen langer Punktlisten.
    static func downsample(_ points: [TrackPoint], maxCount: Int) -> [TrackPoint] {
        guard points.count > maxCount, maxCount > 2 else { return points }
        let step = Double(points.count - 1) / Double(maxCount - 1)
        return (0..<maxCount).map { points[Int(Double($0) * step)] }
    }

    /// Trennt einen Track an Datenlücken auf (großer Zeit- UND
    /// Ortssprung), damit Lücken nicht als falsche gerade Linien
    /// gezeichnet werden.
    static func segments(_ points: [TrackPoint],
                         maxGapSeconds: TimeInterval = 180,
                         maxJumpMeters: Double = 300) -> [[TrackPoint]] {
        guard points.count > 1 else { return points.isEmpty ? [] : [points] }
        var result: [[TrackPoint]] = []
        var current: [TrackPoint] = [points[0]]
        for i in 1..<points.count {
            let a = points[i - 1]
            let b = points[i]
            let dt = b.t.timeIntervalSince(a.t)
            let distance = CLLocation(latitude: a.lat, longitude: a.lon)
                .distance(from: CLLocation(latitude: b.lat, longitude: b.lon))
            if dt > maxGapSeconds && distance > maxJumpMeters {
                result.append(current)
                current = []
            }
            current.append(b)
        }
        result.append(current)
        return result.filter { $0.count > 1 }
    }

    /// Position zu einer Uhrzeit („Wo war ich um 14:30?“) — zwischen den
    /// umliegenden Messpunkten linear interpoliert, mit ehrlicher Angabe
    /// zur Messlücke.
    struct TimePosition {
        var coordinate: CLLocationCoordinate2D
        var isEstimate: Bool     // große Messlücke oder außerhalb der Aufzeichnung
        var note: String
    }

    static func position(at time: Date, in sortedPoints: [TrackPoint]) -> TimePosition? {
        guard let first = sortedPoints.first, let last = sortedPoints.last else { return nil }
        func fmt(_ d: Date) -> String { d.formatted(date: .omitted, time: .shortened) }

        if time <= first.t {
            return TimePosition(
                coordinate: first.coordinate,
                isEstimate: true,
                note: "Vor dem ersten Messpunkt (\(fmt(first.t))) — gezeigt wird der Tagesbeginn."
            )
        }
        if time >= last.t {
            return TimePosition(
                coordinate: last.coordinate,
                isEstimate: true,
                note: "Nach dem letzten Messpunkt (\(fmt(last.t))) — gezeigt wird das Tagesende."
            )
        }
        guard let upper = sortedPoints.firstIndex(where: { $0.t >= time }), upper > 0 else {
            return TimePosition(coordinate: first.coordinate, isEstimate: true, note: "")
        }
        let a = sortedPoints[upper - 1]
        let b = sortedPoints[upper]
        let span = b.t.timeIntervalSince(a.t)
        let fraction = span > 0 ? time.timeIntervalSince(a.t) / span : 0
        let coordinate = CLLocationCoordinate2D(
            latitude: a.lat + (b.lat - a.lat) * fraction,
            longitude: a.lon + (b.lon - a.lon) * fraction
        )
        if span > 600 {
            return TimePosition(
                coordinate: coordinate,
                isEstimate: true,
                note: "Messlücke zwischen \(fmt(a.t)) und \(fmt(b.t)) (z. B. Ruhemodus) — Position geschätzt."
            )
        }
        return TimePosition(
            coordinate: coordinate,
            isEstimate: false,
            note: "Zwischen den Messpunkten \(fmt(a.t)) und \(fmt(b.t))."
        )
    }
}

// MARK: - Foto-Stichwörter (Fotoanalyse, opt-in)

/// Ergebnis der On-Device-Fotoanalyse (Vision): pro Aufnahme nur
/// Stichwörter und Zeitbezug — niemals Bilddaten. Synct über CloudKit,
/// damit die Suche geräteübergreifend funktioniert.
@Model
final class MediaTag {
    var assetId: String = ""
    var deviceId: String = ""
    var dayKey: String = ""
    var labels: String = ""      // kommagetrennte englische Vision-Begriffe
    var analyzedAt: Date = Date()

    init(assetId: String, deviceId: String, dayKey: String, labels: String) {
        self.assetId = assetId
        self.deviceId = deviceId
        self.dayKey = dayKey
        self.labels = labels
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

    /// Überträgt den aktuellen Gerätenamen auf alle Bestandsdaten dieses
    /// Geräts. Aufzeichnungen tragen sonst dauerhaft den Namen vom
    /// Aufnahmezeitpunkt — nach einer Umbenennung erschiene dasselbe
    /// Gerät doppelt („iPhone“ und „17 Pro“).
    static func normalizeStoredNames(container: ModelContainer) {
        let context = ModelContext(container)
        let id = deviceId
        let name = deviceName
        let dayPredicate = #Predicate<TrackDay> { $0.deviceId == id && $0.deviceName != name }
        if let days = try? context.fetch(FetchDescriptor(predicate: dayPredicate)), !days.isEmpty {
            for day in days {
                day.deviceName = name
                day.updatedAt = Date()
            }
        }
        let visitPredicate = #Predicate<PlaceVisit> { $0.deviceId == id && $0.deviceName != name }
        if let visits = try? context.fetch(FetchDescriptor(predicate: visitPredicate)), !visits.isEmpty {
            for visit in visits {
                visit.deviceName = name
                visit.updatedAt = Date()
            }
        }
        try? context.save()
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
