//  BackgroundRefresh.swift
//  A heartbeat, as far as iOS allows one.
//
//  There is no server that could ask "are you still there". What there is:
//  `BGAppRefreshTask`, which iOS grants when it feels like it — often once or
//  twice a day, sometimes not for days on an iPad that lives in a cupboard.
//
//  That is why this is explicitly a best effort and why the device list judges
//  by "last heard from", not by "reachable now". Promising more would be a
//  promise the platform does not keep.

import BackgroundTasks
import Foundation

enum BackgroundRefresh {

    static let identifier = "de.dboschule.alarm.refresh"

    /// Must be called before the app finishes launching — `BGTaskScheduler`
    /// rejects a registration afterwards, with a crash rather than an error.
    static func register(handler: @escaping () async -> Void) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier,
                                        using: nil) { task in
            schedule()
            let work = Task {
                await handler()
                task.setTaskCompleted(success: true)
            }
            task.expirationHandler = {
                work.cancel()
                task.setTaskCompleted(success: false)
            }
        }
    }

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        // Six hours is a wish, not a schedule. Asking for less does not make
        // iOS grant more; it only makes the request look impatient.
        request.earliestBeginDate = Date(timeIntervalSinceNow: 6 * 60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}
