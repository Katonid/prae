//
//  DJILogImport.swift
//  FlightMate
//
//  DJI-Fluglog-Import fürs Logbuch (Nutzerwunsch): Aus den Telemetrie-
//  Dateien, die ohne Zusatzdienste lesbar sind, werden automatisch
//  Logbuch-Einträge — Datum, Ort (Reverse-Geocoding), Flugdauer und
//  maximale Höhe in der Notiz. Unterstützt:
//    - .SRT-Untertitel der DJI-Videos (liegen neben jedem Video,
//      wenn „Video-Untertitel" in DJI Fly aktiviert ist)
//    - AirData-CSV-Exporte (verbreiteter Sync-Dienst für Flug-Logs)
//  Die verschlüsselten DJI-Fly-TXT-Logs sind bewusst außen vor —
//  die kann keine App ohne DJI-Schlüssel lesen (ehrliche Grenze).
//

import Foundation
import CoreLocation

enum DJILogImport {

    /// Importiert die gewählten Dateien; liefert eine Klartext-Bilanz.
    static func importFiles(_ urls: [URL]) async -> String {
        var imported = 0
        var skipped = 0
        var failed = 0

        for url in urls {
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }

            guard let data = try? Data(contentsOf: url),
                  let text = String(data: data, encoding: .utf8)
                    ?? String(data: data, encoding: .utf16) else {
                failed += 1
                continue
            }

            let flight: ParsedFlight?
            if text.contains("-->") {
                flight = parseSRT(text)
            } else if text.lowercased().contains("latitude") && text.contains(",") {
                flight = parseAirDataCSV(text)
            } else {
                flight = nil
            }
            guard let flight else {
                failed += 1
                continue
            }

            // Doppelte Importe vermeiden: gleicher Start (Minute) = gleicher Flug.
            let existing = FlightLog.all()
            if existing.contains(where: { abs($0.date.timeIntervalSince(flight.start)) < 60 }) {
                skipped += 1
                continue
            }

            var entry = FlightLogEntry()
            entry.date = flight.start
            entry.spotName = await placeName(for: flight.coordinate) ?? "DJI-Import"
            entry.latitude = flight.coordinate.latitude
            entry.longitude = flight.coordinate.longitude
            var noteParts = ["Import aus DJI-Log (\(url.lastPathComponent))"]
            if let duration = flight.durationS, duration > 0 {
                noteParts.append(String(format: "Dauer ≈ %.0f min", duration / 60))
            }
            if let alt = flight.maxAltitudeM, alt > 0 {
                noteParts.append(String(format: "max. Höhe ≈ %.0f m", alt))
            }
            entry.notes = noteParts.joined(separator: " · ")
            FlightLog.save(entry)
            imported += 1
        }

        var parts: [String] = []
        if imported > 0 { parts.append("\(imported) Flug\(imported == 1 ? "" : "e") importiert") }
        if skipped > 0 { parts.append("\(skipped) schon vorhanden (übersprungen)") }
        if failed > 0 { parts.append("\(failed) Datei\(failed == 1 ? "" : "en") nicht lesbar — unterstützt sind DJI-.SRT und AirData-CSV; die verschlüsselten DJI-Fly-TXT-Logs kann keine App ohne DJI-Schlüssel öffnen") }
        return parts.isEmpty ? "Nichts importiert." : parts.joined(separator: " · ") + "."
    }

    // MARK: Geparste Rohdaten

    private struct ParsedFlight {
        let start: Date
        let durationS: TimeInterval?
        let coordinate: CLLocationCoordinate2D?
        let maxAltitudeM: Double?
    }

    // MARK: DJI-.SRT (Video-Untertitel mit Telemetrie)

    private static func parseSRT(_ text: String) -> ParsedFlight? {
        // Zeitstempel wie "2026-07-20 18:32:01" (Ortszeit des Flugs).
        let stampPattern = /(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})/
        let stamps = text.matches(of: stampPattern).map { String($0.1) }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        guard let firstStamp = stamps.first, let start = formatter.date(from: firstStamp) else {
            return nil
        }
        let end = stamps.last.flatMap { formatter.date(from: $0) }

        // Neuere SRTs: [latitude: 44.1] [longitude: -77.1] [rel_alt: 12.3 …]
        var coordinate: CLLocationCoordinate2D?
        if let lat = firstMatch(text, /\[\s*latitude\s*:\s*([-0-9.]+)/),
           let lon = firstMatch(text, /\[\s*longitude\s*:\s*([-0-9.]+)/) {
            coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        } else if let match = text.firstMatch(of: /GPS\s*\(([-0-9.]+),\s*([-0-9.]+)/),
                  let lon = Double(match.1), let lat = Double(match.2) {
            // Ältere SRTs: GPS(Longitude, Latitude, …)
            coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }

        let maxAltitude = text.matches(of: /rel_alt\s*:\s*([-0-9.]+)/)
            .compactMap { Double($0.1) }
            .max()

        return ParsedFlight(
            start: start,
            durationS: end.map { $0.timeIntervalSince(start) },
            coordinate: coordinate,
            maxAltitudeM: maxAltitude
        )
    }

    // MARK: AirData-CSV

    private static func parseAirDataCSV(_ text: String) -> ParsedFlight? {
        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
        guard lines.count > 1 else { return nil }
        let header = lines[0].lowercased().split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        func column(containing key: String) -> Int? {
            header.firstIndex { $0.contains(key) }
        }
        guard let latCol = column(containing: "latitude"),
              let lonCol = column(containing: "longitude") else { return nil }
        let timeCol = column(containing: "datetime")
        let msCol = column(containing: "time(millisecond)")
        let altCol = column(containing: "height_above_takeoff") ?? column(containing: "altitude")

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")

        var start: Date?
        var coordinate: CLLocationCoordinate2D?
        var lastMs: Double = 0
        var maxAltFt: Double = 0

        for line in lines.dropFirst() {
            let cells = line.split(separator: ",", omittingEmptySubsequences: false).map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            guard cells.count > max(latCol, lonCol) else { continue }
            if coordinate == nil, let lat = Double(cells[latCol]), let lon = Double(cells[lonCol]),
               abs(lat) > 0.01 || abs(lon) > 0.01 {
                coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
            if start == nil, let timeCol, cells.count > timeCol {
                start = formatter.date(from: cells[timeCol])
            }
            if let msCol, cells.count > msCol, let ms = Double(cells[msCol]) {
                lastMs = max(lastMs, ms)
            }
            if let altCol, cells.count > altCol, let alt = Double(cells[altCol]) {
                maxAltFt = max(maxAltFt, alt)
            }
        }
        guard let flightStart = start ?? coordinate.map({ _ in Date() }) else { return nil }
        return ParsedFlight(
            start: flightStart,
            durationS: lastMs > 0 ? lastMs / 1000 : nil,
            coordinate: coordinate,
            maxAltitudeM: maxAltFt > 0 ? maxAltFt * 0.3048 : nil
        )
    }

    // MARK: Helfer

    private static func firstMatch(_ text: String, _ pattern: Regex<(Substring, Substring)>) -> Double? {
        text.firstMatch(of: pattern).flatMap { Double($0.1) }
    }

    private static func placeName(for coordinate: CLLocationCoordinate2D?) async -> String? {
        guard let coordinate else { return nil }
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first
        return placemark?.locality ?? placemark?.name
    }
}
