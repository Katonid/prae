//
//  FlightRouteImporter.swift
//  FlightMate
//
//  Drone Media Explorer, M3 (Architektur Kap. 7): Flugrouten aus
//  DJI-SRT-Untertiteln (Telemetrie neben jedem Video, ~1 Datenpunkt
//  pro Sekunde) und AirData-CSV-Exporten — als Flight-Datensätze mit
//  komplettem Track. Danach läuft der Abgleich: Medien werden per
//  Zeitfenster ihrem Flug zugeordnet, und Videos ohne GPS bekommen
//  ihren Ort aus der Kaskade (Flight Log → Nachbar-Foto → manuell) —
//  immer mit Quelle und Vertrauensgrad, nie geraten.
//  Ehrliche Grenze bleibt: Die verschlüsselten DJI-Fly-TXT-Logs kann
//  keine App ohne DJI-Schlüssel lesen.
//

import Foundation
import CoreLocation
import SwiftData

@MainActor
enum FlightRouteImporter {

    // MARK: Import (SRT / AirData-CSV)

    static func importFiles(_ urls: [URL]) async -> String {
        guard let container = ArchivStore.shared.container else {
            return "Katalog nicht verfügbar."
        }
        var imported = 0, duplicates = 0, failed = 0

        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let text = try? String(contentsOf: url, encoding: .utf8) else {
                failed += 1
                continue
            }
            let parsed = url.pathExtension.lowercased() == "csv"
                ? parseAirData(text)
                : parseSRT(text)
            guard let parsed, parsed.points.count >= 2 else {
                failed += 1
                continue
            }

            // Dedupe: Flug mit gleichem Start (±60 s) existiert schon.
            let windowStart = parsed.start.addingTimeInterval(-60)
            let windowEnd = parsed.start.addingTimeInterval(60)
            let descriptor = FetchDescriptor<Flight>(predicate: #Predicate {
                $0.start >= windowStart && $0.start <= windowEnd
            })
            if let count = try? container.mainContext.fetchCount(descriptor), count > 0 {
                duplicates += 1
                continue
            }

            let flight = Flight()
            flight.start = parsed.start
            flight.end = parsed.start.addingTimeInterval(parsed.points.last?[0] ?? 0)
            flight.sourceFileName = url.lastPathComponent
            flight.maxAltitudeM = parsed.points.compactMap { $0.count >= 4 ? $0[3] : nil }.max()
            flight.trackJSON = try? JSONEncoder().encode(parsed.points)
            container.mainContext.insert(flight)
            imported += 1
        }
        try? container.mainContext.save()

        let resolved = resolveLocationsAndFlights()
        var parts = ["\(imported) Flug\(imported == 1 ? "" : "üge") importiert"]
        if duplicates > 0 { parts.append("\(duplicates) bereits bekannt") }
        if failed > 0 { parts.append("\(failed) nicht lesbar (DJI-TXT-Logs sind verschlüsselt — SRT/AirData-CSV verwenden)") }
        if resolved.linked > 0 { parts.append("\(resolved.linked) Medien einem Flug zugeordnet") }
        if resolved.located > 0 { parts.append("\(resolved.located) Orte ermittelt") }
        return parts.joined(separator: " · ")
    }

    /// SRT: Blöcke mit eingebettetem Datum + [latitude:]/[longitude:]
    /// (neues Format) bzw. GPS(lon,lat,…) (altes Format).
    private static func parseSRT(_ text: String)
        -> (start: Date, points: [[Double]])? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        var start: Date?
        var points: [[Double]] = []
        var lastOffset = -1.0

        for block in text.components(separatedBy: "\n\n") {
            guard let stampMatch = block.firstMatch(of: /(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})/),
                  let stamp = formatter.date(from: String(stampMatch.1)) else { continue }
            var latitude: Double?
            var longitude: Double?
            if let match = block.firstMatch(of: /\[\s*latitude\s*:\s*([-0-9.]+)/) {
                latitude = Double(match.1)
            }
            if let match = block.firstMatch(of: /\[\s*longitude\s*:\s*([-0-9.]+)/) {
                longitude = Double(match.1)
            }
            if latitude == nil,
               let match = block.firstMatch(of: /GPS\s*\(([-0-9.]+),\s*([-0-9.]+)/) {
                longitude = Double(match.1)
                latitude = Double(match.2)
            }
            let altitude = block.firstMatch(of: /rel_alt\s*:\s*([-0-9.]+)/)
                .flatMap { Double($0.1) }
            guard let latitude, let longitude,
                  abs(latitude) > 0.0001 || abs(longitude) > 0.0001 else { continue }

            if start == nil { start = stamp }
            let offset = stamp.timeIntervalSince(start!)
            // Auf 1 Punkt/Sekunde ausdünnen (SRT hat oft 30/s).
            guard offset > lastOffset + 0.5 else { continue }
            lastOffset = offset
            points.append([offset, latitude, longitude, altitude ?? 0])
        }
        guard let start else { return nil }
        return (start, points)
    }

    /// AirData-CSV: Spalten per Kopfzeile suchen (robust gegen
    /// unterschiedliche Export-Varianten).
    private static func parseAirData(_ text: String)
        -> (start: Date, points: [[Double]])? {
        let lines = text.components(separatedBy: .newlines)
        guard let header = lines.first?.lowercased() else { return nil }
        let columns = header.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        func column(_ needle: String) -> Int? {
            columns.firstIndex { $0.contains(needle) }
        }
        guard let latColumn = column("latitude"),
              let lonColumn = column("longitude") else { return nil }
        let timeColumn = column("time(millisecond")
        let dateColumn = column("datetime")
        let altColumn = column("height_above_takeoff") ?? column("altitude")

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")

        var start: Date?
        var points: [[Double]] = []
        var lastOffset = -1.0

        for line in lines.dropFirst() {
            let cells = line.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
            guard cells.count > max(latColumn, lonColumn),
                  let latitude = Double(cells[latColumn]),
                  let longitude = Double(cells[lonColumn]),
                  abs(latitude) > 0.0001 || abs(longitude) > 0.0001 else { continue }
            if start == nil, let dateColumn, cells.count > dateColumn {
                start = formatter.date(from: cells[dateColumn])
            }
            let offset: Double
            if let timeColumn, cells.count > timeColumn,
               let ms = Double(cells[timeColumn]) {
                offset = ms / 1000
            } else {
                offset = lastOffset + 1
            }
            guard offset > lastOffset + 0.5 else { continue }
            lastOffset = offset
            let altitudeM = altColumn.flatMap { index -> Double? in
                guard cells.count > index, let feet = Double(cells[index]) else { return nil }
                return feet * 0.3048
            }
            points.append([offset, latitude, longitude, altitudeM ?? 0])
        }
        guard let start, !points.isEmpty else { return nil }
        return (start, points)
    }

    // MARK: Kaskade: Flüge zuordnen + Orte ermitteln

    /// Läuft nach jedem Flug- und Medien-Import: (1) Medien per
    /// Zeitfenster (±2 min) ihrem Flug zuordnen, (2) Medien ohne Ort
    /// über die Kaskade verorten — Flight Log (hohe Sicherheit),
    /// sonst zeitnahes Foto (±10 min mittel, ±30 min gering).
    @discardableResult
    static func resolveLocationsAndFlights() -> (linked: Int, located: Int) {
        guard let container = ArchivStore.shared.container else { return (0, 0) }
        let context = container.mainContext
        guard let assets = try? context.fetch(FetchDescriptor<MediaAsset>()),
              let flights = try? context.fetch(FetchDescriptor<Flight>()) else {
            return (0, 0)
        }
        var linked = 0
        var located = 0

        // Fotos mit Datei-GPS als Nachbarschafts-Quelle.
        let anchors = assets.filter {
            $0.coordinate != nil && $0.locationSource == .exif && $0.kind == .photo
        }

        for asset in assets {
            // (1) Flug-Zuordnung über das Zeitfenster.
            if asset.flight == nil {
                if let match = flights.first(where: {
                    asset.capturedAt >= $0.start.addingTimeInterval(-120)
                        && asset.capturedAt <= $0.end.addingTimeInterval(120)
                }) {
                    asset.flight = match
                    linked += 1
                }
            }
            // (2) Orts-Kaskade — nur wo noch kein Ort steht; manuelle
            // Zuordnungen werden nie überschrieben.
            guard asset.coordinate == nil else { continue }
            if let flight = asset.flight,
               let position = flight.position(at: asset.capturedAt) {
                asset.latitude = position.coordinate.latitude
                asset.longitude = position.coordinate.longitude
                asset.altitudeM = position.altitudeM
                asset.locationSourceRaw = LocationSource.flightlog.rawValue
                asset.locationConfidenceRaw = LocationConfidence.high.rawValue
                located += 1
                continue
            }
            if let nearest = anchors
                .map({ (anchor: $0, gap: abs($0.capturedAt.timeIntervalSince(asset.capturedAt))) })
                .filter({ $0.gap <= 1_800 })
                .min(by: { $0.gap < $1.gap }) {
                asset.latitude = nearest.anchor.latitude
                asset.longitude = nearest.anchor.longitude
                asset.locationSourceRaw = LocationSource.neighborPhoto.rawValue
                asset.locationConfidenceRaw = (nearest.gap <= 600
                    ? LocationConfidence.medium : LocationConfidence.low).rawValue
                located += 1
            }
        }
        try? context.save()
        return (linked, located)
    }
}
