//
//  NotificationPlanner.swift
//  FlightMate
//
//  Proaktive Benachrichtigung (PRD F4): „Der magische Moment ist
//  nicht, wenn der Nutzer die App öffnet — sondern wenn die App ihn
//  anspricht." Maximal EINE Benachrichtigung pro Tag, nur bei
//  außergewöhnlich guten Fenstern (Score ≥ 8) an gespeicherten Spots.
//
//  Umsetzung ohne Server: Bei jedem App-Start/Refresh werden die
//  nächsten 7 Tage der Spots bewertet und lokale Benachrichtigungen
//  vorausgeplant (UNCalendarNotificationTrigger). Es verlassen keine
//  Spot-Daten das Gerät (PRD Kap. 11).
//

import Foundation
import UserNotifications

enum NotificationPlanner {
    static let idPrefix = "flightwindow-"
    /// Nur außergewöhnliche Fenster melden — Vertrauen in die Relevanz
    /// ist wichtiger als Engagement (PRD F4).
    static let minScore = 8

    static func requestPermission() async -> Bool {
        let granted = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])
        return granted ?? false
    }

    static func cancelAll() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter { $0.hasPrefix(idPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ours)
    }

    /// Plant alle Benachrichtigungen neu: pro Kalendertag das beste
    /// Fenster über alle Spots, gemeldet 2 Stunden vor Fensterbeginn.
    static func reschedule(entries: [(spot: Spot, days: [DayScore])]) async {
        await cancelAll()
        let center = UNUserNotificationCenter.current()
        let calendar = Calendar.current

        var bestPerDay: [Date: (spot: Spot, window: BestWindow, timeZone: TimeZone)] = [:]
        for entry in entries {
            for day in entry.days {
                guard let window = day.bestWindow, window.score >= minScore else { continue }
                // Trend-Tage (8+) sind zu unsicher für „Score ≥ 8"-Meldungen.
                guard day.date < Date().addingTimeInterval(7 * 86_400) else { continue }
                let key = calendar.startOfDay(for: day.date)
                if let existing = bestPerDay[key], existing.window.score >= window.score { continue }
                bestPerDay[key] = (entry.spot, window, day.timeZone)
            }
        }

        let idFormatter = DateFormatter()
        idFormatter.dateFormat = "yyyyMMdd"

        for (dayKey, pick) in bestPerDay {
            let fireDate = pick.window.start.addingTimeInterval(-2 * 3600)
            guard fireDate > Date().addingTimeInterval(15 * 60) else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Flight Score \(pick.window.score) an „\(pick.spot.name)\u{201C}"
            content.body = "Bestes Fenster: \(Theme.time(pick.window.start, in: pick.timeZone))–\(Theme.time(pick.window.end, in: pick.timeZone)) Uhr Ortszeit. Akkus laden!"
            content.sound = .default

            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let request = UNNotificationRequest(
                identifier: idPrefix + idFormatter.string(from: dayKey),
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )
            try? await center.add(request)
        }
    }
}
