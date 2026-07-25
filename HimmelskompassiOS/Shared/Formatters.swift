//
//  Formatters.swift
//  Himmelskompass
//
//  Zeit- und Textformatierung in der Zeitzone des gewählten Ortes.
//

import Foundation

struct HKFormatters {
    var timeZone: TimeZone

    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.timeZone = timeZone
        f.dateFormat = "HH:mm"
        return f
    }

    private var dayMonthFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.timeZone = timeZone
        f.dateFormat = "dd.MM."
        return f
    }

    func time(_ d: Date?) -> String {
        guard let d else { return "–" }
        return timeFormatter.string(from: d)
    }

    func range(_ a: Date?, _ b: Date?) -> String {
        guard let a, let b else { return "–" }
        return time(a) + " – " + time(b)
    }

    func dateTime(_ d: Date?) -> String {
        guard let d else { return "–" }
        return dayMonthFormatter.string(from: d) + " " + time(d)
    }

    static func duration(_ interval: TimeInterval?) -> String {
        guard let interval, interval >= 0, interval.isFinite else { return "–" }
        let min = Int((interval / 60).rounded())
        return "\(min / 60) h " + String(format: "%02d", min % 60) + " min"
    }

    static let directions = ["N", "NNO", "NO", "ONO", "O", "OSO", "SO", "SSO",
                             "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]

    static func dirName(azDeg: Double) -> String {
        let idx = Int((azDeg / 22.5).rounded()) % 16
        return directions[(idx + 16) % 16]
    }

    /// Zeitzonen-Beschriftung wie "Europe/Berlin, GMT+2"
    func tzLabel(reference: Date) -> String {
        let seconds = timeZone.secondsFromGMT(for: reference)
        let hours = seconds / 3600
        let minutes = abs(seconds / 60 % 60)
        var offset = "GMT" + (seconds >= 0 ? "+" : "−") + String(abs(hours))
        if minutes != 0 { offset += ":" + String(format: "%02d", minutes) }
        return timeZone.identifier.replacingOccurrences(of: "_", with: " ") + ", " + offset
    }

    /// Helligkeit wie "−4,2 mag"
    static func magnitude(_ mag: Double) -> String {
        let sign = mag < 0 ? "−" : "+"
        return sign + String(format: "%.1f", abs(mag)).replacingOccurrences(of: ".", with: ",") + " mag"
    }

    static func degValue(_ radians: Double) -> Double { radians * 180 / .pi }
}
