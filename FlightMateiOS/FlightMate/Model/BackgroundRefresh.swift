//
//  BackgroundRefresh.swift
//  FlightMate
//
//  Hintergrund-Aktualisierung (PRD F4, zweite Stufe): Bisher plante
//  die App die Flugfenster-Benachrichtigungen nur beim Öffnen. Mit
//  BGAppRefresh prüft sie auch ungeöffnet regelmäßig das Wetter an
//  den gespeicherten Spots und plant die Meldungen neu — der
//  „magische Moment" kommt damit auch, wenn die App tagelang zu war.
//
//  Bewusst unabhängig vom AppState: liest Spots, Profil und
//  Einstellungen direkt aus UserDefaults, damit der Task ohne
//  UI-Objekte laufen kann. iOS entscheidet selbst, wann (und ob) der
//  Task läuft — typisch 1–2× täglich bei regelmäßiger Nutzung.
//

import Foundation
import BackgroundTasks

enum BackgroundRefresh {
    /// Muss mit dem Eintrag in Support/Info.plist übereinstimmen
    /// (BGTaskSchedulerPermittedIdentifiers).
    static let taskID = "de.familie.flightmate.refresh"

    /// Einmal beim App-Start registrieren (vor Ende des Launches).
    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskID, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            handle(refreshTask)
        }
    }

    /// Nächsten Lauf anmelden — beim Start und bei jedem Wechsel in
    /// den Hintergrund. Doppelte Anmeldungen ersetzt iOS automatisch.
    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: taskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 6 * 3600)
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handle(_ task: BGAppRefreshTask) {
        // Direkt die nächste Runde anmelden — sonst bleibt es beim einen Lauf.
        schedule()

        let work = Task {
            await refreshNotifications()
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = {
            work.cancel()
            task.setTaskCompleted(success: false)
        }
    }

    /// Frische 7-Tage-Scores für alle Spots rechnen und die
    /// Benachrichtigungen neu planen — gleiche Logik wie beim
    /// App-Start, nur ohne AppState.
    static func refreshNotifications() async {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "notificationsEnabled"),
              let profile = DroneProfile.profile(for: defaults.string(forKey: "droneProfileID")),
              let data = defaults.data(forKey: "spots"),
              let spots = try? JSONDecoder().decode([Spot].self, from: data),
              !spots.isEmpty else { return }

        var entries: [(spot: Spot, days: [DayScore])] = []
        for spot in spots {
            guard !Task.isCancelled else { return }
            if let (forecast, _) = try? await WeatherService.shared.forecast(for: spot.coordinate) {
                let days = FlightScoreEngine.days(
                    forecast: forecast, profile: profile,
                    latitude: spot.latitude, longitude: spot.longitude
                ).filter { $0.date >= Calendar.current.startOfDay(for: Date()) }
                entries.append((spot, days))
            }
        }
        guard !entries.isEmpty else { return }
        await NotificationPlanner.reschedule(entries: entries)
    }
}
