//
//  CalendarExport.swift
//  FlightMate
//
//  „Fenster in Kalender eintragen" ohne Kalender-Berechtigung:
//  Die App erzeugt eine .ics-Datei und übergibt sie ans Teilen-Blatt —
//  ein Tipp auf „Kalender" importiert den Termin. Datenminimierung:
//  keine EventKit-Berechtigung, kein Zugriff auf bestehende Termine.
//

import Foundation

enum CalendarExport {

    /// Schreibt ein Flugfenster als .ics-Termin ins Temp-Verzeichnis.
    static func icsFile(spotName: String, latitude: Double, longitude: Double,
                        window: BestWindow) -> URL? {
        let utc = DateFormatter()
        utc.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        utc.timeZone = TimeZone(identifier: "UTC")
        utc.locale = Locale(identifier: "en_US_POSIX")

        let ics = """
        BEGIN:VCALENDAR
        VERSION:2.0
        PRODID:-//FlightMate AI//DE
        BEGIN:VEVENT
        UID:\(UUID().uuidString)@flightmate
        DTSTAMP:\(utc.string(from: Date()))
        DTSTART:\(utc.string(from: window.start))
        DTEND:\(utc.string(from: window.end))
        SUMMARY:Drohnenflug: \(escape(spotName)) (Score \(window.score)/10)
        DESCRIPTION:Bestes Flugfenster laut FlightMate AI. Vor dem Start Legal-Check und Wetter aktualisieren.
        GEO:\(String(format: "%.5f;%.5f", latitude, longitude))
        BEGIN:VALARM
        TRIGGER:-PT1H
        ACTION:DISPLAY
        DESCRIPTION:Akkus laden — Flugfenster in einer Stunde
        END:VALARM
        END:VEVENT
        END:VCALENDAR
        """

        let filename = "Flugfenster-\(spotName.replacingOccurrences(of: "/", with: "-")).ics"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try ics.data(using: .utf8)?.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: ";", with: "\\;")
    }
}
