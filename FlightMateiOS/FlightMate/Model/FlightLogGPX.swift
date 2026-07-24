//
//  FlightLogGPX.swift
//  FlightMate
//
//  Logbuch-Sicherung als GPX (Nutzerwunsch „sinnvolles Dateiformat"):
//  GPX ist der offene Standard für Geo-Wegpunkte — die Datei öffnet
//  in Karten-, Foto- und Outdoor-Apps (Apple Karten via Dateien,
//  Lightroom, Garmin, Komoot …) und bleibt als XML auch in zehn
//  Jahren noch lesbar. Jeder Flug wird ein Wegpunkt mit Name, Zeit
//  und Beschreibung (Score, Bewertung, Notiz). Einträge ohne Ort
//  werden mit gezählt, aber ohne Koordinate ausgelassen — GPX
//  verlangt lat/lon je Wegpunkt.
//  (Die vollständige JSON-Sicherung inkl. Spots gibt es weiterhin in
//  den Einstellungen; Fotos bleiben bewusst lokal.)
//

import Foundation

enum FlightLogGPX {

    /// Schreibt die Einträge als GPX-Datei ins Temp-Verzeichnis und
    /// liefert die URL fürs Teilen-Blatt (nil, wenn kein Eintrag
    /// eine Koordinate hat).
    static func export(_ entries: [FlightLogEntry]) -> URL? {
        let located = entries.filter { $0.coordinate != nil }
        guard !located.isEmpty else { return nil }

        let timestamp = ISO8601DateFormatter()
        var lines: [String] = [
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
            "<gpx version=\"1.1\" creator=\"FlightMate AI\" xmlns=\"http://www.topografix.com/GPX/1/1\">",
            "<metadata><name>FlightMate Flug-Logbuch</name><time>\(timestamp.string(from: Date()))</time></metadata>",
        ]
        for entry in located.sorted(by: { $0.date < $1.date }) {
            guard let coordinate = entry.coordinate else { continue }
            var description: [String] = []
            if let score = entry.score { description.append("Flight Score \(score)/10") }
            if let rating = entry.rating { description.append("Bewertung: \(rating.title)") }
            if !entry.notes.isEmpty { description.append(entry.notes) }
            lines.append(String(format: "<wpt lat=\"%.6f\" lon=\"%.6f\">", coordinate.latitude, coordinate.longitude))
            lines.append("<time>\(timestamp.string(from: entry.date))</time>")
            lines.append("<name>\(escape(entry.spotName.isEmpty ? "Flug" : entry.spotName))</name>")
            if !description.isEmpty {
                lines.append("<desc>\(escape(description.joined(separator: " · ")))</desc>")
            }
            lines.append("<sym>Airport</sym></wpt>")
        }
        lines.append("</gpx>")

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlightMate-Logbuch-\(formatter.string(from: Date())).gpx")
        guard (try? lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)) != nil else {
            return nil
        }
        return url
    }

    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
