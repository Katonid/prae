import Foundation
import SwiftData

/// Export & Import.
/// - GPX 1.1: maximal kompatibel (Karten-Apps, Garmin, Komoot, …) —
///   Tracks als <trk>, Aufenthalte als <wpt>.
/// - JSON: verlustfreies Tagesspur-Backup inklusive Geräteinfos,
///   für Umzug/Wiederherstellung.
enum Exporter {

    enum Format: String, CaseIterable, Identifiable {
        case gpx = "GPX"
        case json = "JSON"
        var id: String { rawValue }
        var fileExtension: String { rawValue.lowercased() }
    }

    enum Scope {
        case day(String)
        case range(String, String)   // dayKey von...bis (einschließlich)
        case all

        func contains(_ dayKey: String) -> Bool {
            switch self {
            case .day(let d): return dayKey == d
            case .range(let from, let to): return dayKey >= from && dayKey <= to
            case .all: return true
            }
        }

        var label: String {
            switch self {
            case .day(let d): return d
            case .range(let from, let to): return "\(from)_bis_\(to)"
            case .all: return "alles"
            }
        }
    }

    // MARK: - Backup-Schema (JSON)

    struct BackupFile: Codable {
        var schema = "tagesspur-backup-1"
        var exportedAt = Date()
        var days: [BackupDay] = []
        var visits: [BackupVisit] = []
    }

    struct BackupDay: Codable {
        var deviceId: String
        var deviceName: String
        var dayKey: String
        var points: [TrackPoint]
    }

    struct BackupVisit: Codable {
        var deviceId: String
        var deviceName: String
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
        var geocoded: Bool
    }

    // MARK: - Export

    /// Schreibt die Exportdatei ins Temp-Verzeichnis und liefert die URL.
    static func export(scope: Scope, format: Format, context: ModelContext) throws -> URL {
        let days = (try context.fetch(FetchDescriptor<TrackDay>(sortBy: [SortDescriptor(\.dayKey)])))
            .filter { scope.contains($0.dayKey) }
        let visits = (try context.fetch(FetchDescriptor<PlaceVisit>(sortBy: [SortDescriptor(\.arrival)])))
            .filter { scope.contains($0.dayKey) }

        let data: Data
        switch format {
        case .gpx:
            data = Data(gpx(days: days, visits: visits).utf8)
        case .json:
            var file = BackupFile()
            file.days = days.map {
                BackupDay(deviceId: $0.deviceId, deviceName: $0.deviceName, dayKey: $0.dayKey, points: $0.points())
            }
            file.visits = visits.map {
                BackupVisit(
                    deviceId: $0.deviceId, deviceName: $0.deviceName, dayKey: $0.dayKey,
                    arrival: $0.arrival, departure: $0.departure,
                    latitude: $0.latitude, longitude: $0.longitude,
                    name: $0.name, locality: $0.locality, thoroughfare: $0.thoroughfare,
                    inlandWater: $0.inlandWater, ocean: $0.ocean, areas: $0.areas,
                    geocoded: $0.geocoded
                )
            }
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            data = try encoder.encode(file)
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Tagesspur_\(scope.label).\(format.fileExtension)")
        try data.write(to: url, options: .atomic)
        return url
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static func xmlEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func gpx(days: [TrackDay], visits: [PlaceVisit]) -> String {
        var out = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="Tagesspur" xmlns="http://www.topografix.com/GPX/1/1">

        """
        for visit in visits {
            out += "  <wpt lat=\"\(visit.latitude)\" lon=\"\(visit.longitude)\">\n"
            out += "    <time>\(isoFormatter.string(from: visit.arrival))</time>\n"
            out += "    <name>\(xmlEscape(visit.title))</name>\n"
            if !visit.subtitle.isEmpty {
                out += "    <desc>\(xmlEscape(visit.subtitle))</desc>\n"
            }
            out += "  </wpt>\n"
        }
        for day in days {
            let points = day.points()
            guard !points.isEmpty else { continue }
            out += "  <trk>\n"
            out += "    <name>\(xmlEscape("\(day.dayKey) – \(day.deviceName)"))</name>\n"
            out += "    <trkseg>\n"
            for p in points {
                out += "      <trkpt lat=\"\(p.lat)\" lon=\"\(p.lon)\">"
                out += "<ele>\(p.alt)</ele>"
                out += "<time>\(isoFormatter.string(from: p.t))</time>"
                out += "</trkpt>\n"
            }
            out += "    </trkseg>\n"
            out += "  </trk>\n"
        }
        out += "</gpx>\n"
        return out
    }

    // MARK: - Import

    struct ImportResult {
        var importedDays = 0
        var importedPoints = 0
        var importedVisits = 0
    }

    static func importFile(at url: URL, context: ModelContext) throws -> ImportResult {
        let secured = url.startAccessingSecurityScopedResource()
        defer { if secured { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)

        if url.pathExtension.lowercased() == "json"
            || (data.first.map { $0 == UInt8(ascii: "{") } ?? false) {
            return try importBackup(data, context: context)
        }
        return try importGPX(data, context: context)
    }

    private static func importBackup(_ data: Data, context: ModelContext) throws -> ImportResult {
        let file = try JSONDecoder.tagesspur.decode(BackupFile.self, from: data)
        var result = ImportResult()

        for backupDay in file.days {
            let dayKey = backupDay.dayKey
            let deviceId = backupDay.deviceId
            let predicate = #Predicate<TrackDay> { $0.dayKey == dayKey && $0.deviceId == deviceId }
            let day: TrackDay
            if let existing = try context.fetch(FetchDescriptor(predicate: predicate)).first {
                day = existing
            } else {
                day = TrackDay(deviceId: deviceId, deviceName: backupDay.deviceName, dayKey: dayKey)
                context.insert(day)
                result.importedDays += 1
            }
            let before = day.pointCount
            day.appendPoints(backupDay.points)
            result.importedPoints += day.pointCount - before
        }

        for backupVisit in file.visits {
            let deviceId = backupVisit.deviceId
            let arrival = backupVisit.arrival
            let predicate = #Predicate<PlaceVisit> { $0.deviceId == deviceId && $0.arrival == arrival }
            guard try context.fetch(FetchDescriptor(predicate: predicate)).isEmpty else { continue }
            let visit = PlaceVisit(
                deviceId: deviceId, deviceName: backupVisit.deviceName, dayKey: backupVisit.dayKey,
                arrival: backupVisit.arrival, departure: backupVisit.departure,
                latitude: backupVisit.latitude, longitude: backupVisit.longitude
            )
            visit.name = backupVisit.name
            visit.locality = backupVisit.locality
            visit.thoroughfare = backupVisit.thoroughfare
            visit.inlandWater = backupVisit.inlandWater
            visit.ocean = backupVisit.ocean
            visit.areas = backupVisit.areas
            visit.geocoded = backupVisit.geocoded
            context.insert(visit)
            result.importedVisits += 1
        }

        try context.save()
        return result
    }

    private static func importGPX(_ data: Data, context: ModelContext) throws -> ImportResult {
        let parser = GPXParser()
        let points = try parser.parse(data)
        var result = ImportResult()
        guard !points.isEmpty else { return result }

        // GPX-Importe bekommen eine eigene „Geräte"-Kennung, damit sie
        // von den live aufgezeichneten Tracks unterscheidbar bleiben.
        let deviceId = "import-gpx"
        let grouped = Dictionary(grouping: points) { DayKey.key(for: $0.t) }
        for (dayKey, dayPoints) in grouped {
            let predicate = #Predicate<TrackDay> { $0.dayKey == dayKey && $0.deviceId == deviceId }
            let day: TrackDay
            if let existing = try context.fetch(FetchDescriptor(predicate: predicate)).first {
                day = existing
            } else {
                day = TrackDay(deviceId: deviceId, deviceName: "GPX-Import", dayKey: dayKey)
                context.insert(day)
                result.importedDays += 1
            }
            let before = day.pointCount
            day.appendPoints(dayPoints)
            result.importedPoints += day.pointCount - before
        }
        try context.save()
        return result
    }
}

// MARK: - Minimaler GPX-Parser (trkpt mit time)

final class GPXParser: NSObject, XMLParserDelegate {
    private var points: [TrackPoint] = []
    private var currentLat: Double?
    private var currentLon: Double?
    private var currentEle: Double = 0
    private var currentTime: Date?
    private var currentElement = ""
    private var textBuffer = ""
    private var inTrkpt = false
    private var parseError: Error?

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let isoFormatterFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    func parse(_ data: Data) throws -> [TrackPoint] {
        points = []
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        if let parseError { throw parseError }
        return points
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        textBuffer = ""
        if elementName == "trkpt" {
            inTrkpt = true
            currentLat = attributeDict["lat"].flatMap(Double.init)
            currentLon = attributeDict["lon"].flatMap(Double.init)
            currentEle = 0
            currentTime = nil
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        textBuffer += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let text = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        switch elementName {
        case "ele" where inTrkpt:
            currentEle = Double(text) ?? 0
        case "time" where inTrkpt:
            currentTime = Self.isoFormatter.date(from: text) ?? Self.isoFormatterFractional.date(from: text)
        case "trkpt":
            if let lat = currentLat, let lon = currentLon, let time = currentTime {
                points.append(TrackPoint(t: time, lat: lat, lon: lon, alt: currentEle))
            }
            inTrkpt = false
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, parseErrorOccurred error: Error) {
        parseError = error
    }
}
