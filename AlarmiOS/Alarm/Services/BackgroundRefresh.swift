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
    ///
    /// **`setTaskCompleted` gehört auf den Hauptfaden, und zwar zwingend.**
    /// Damit endet für iOS ein Hintergrundereignis; UIKit schreibt daraufhin
    /// den Wiederherstellungsstand fort und macht ein Bildschirmfoto der App.
    /// Beides ist Oberfläche, beides prüft den Hauptfaden — und wenn er es
    /// nicht ist, bricht die App ab: `SIGABRT` aus
    /// `_performBlockAfterCATransactionCommitSynchronizes:`.
    ///
    /// Genau das ist passiert (Absturzprotokoll von einem iPad, 09/2026). Ein
    /// nacktes `Task { }` erbt keinen Actor; es lief im Nebenläufigkeits-Pool
    /// (`com.apple.root.user-initiated-qos.cooperative`, so stand es im
    /// Protokoll) und meldete von dort die Aufgabe fertig. Der Absturz sah nach
    /// dem Alarm aus, weil es danach am meisten Hintergrundarbeit gibt — kam
    /// aber von der Auffrischung und war seit der ersten Fassung drin.
    static func register(handler: @escaping () async -> Void) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier,
                                        using: .main) { task in
            schedule()
            let fertig = Fertigmelder(task: task)
            let work = Task { @MainActor in
                await handler()
                fertig.melde(erfolg: true)
            }
            task.expirationHandler = {
                work.cancel()
                fertig.melde(erfolg: false)
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

/// Meldet eine Hintergrundaufgabe fertig — auf dem Hauptfaden und genau
/// einmal.
///
/// Beides ist nötig. Der Hauptfaden, weil UIKit daran hängt (siehe oben). Und
/// genau einmal, weil der Abschluss und der Ablauf-Rückruf sonst beide melden
/// könnten: Ein zweites `setTaskCompleted` beantwortet iOS ebenfalls mit einem
/// Abbruch. Der Ablauf-Rückruf kommt nicht zwingend auf dem Hauptfaden,
/// deshalb der Umweg über `DispatchQueue.main` statt `MainActor.assumeIsolated`
/// — das gibt es erst ab iOS 17, und diese App läuft ab iOS 16.
private final class Fertigmelder {

    private let task: BGTask
    private let sperre = NSLock()
    private var schonGemeldet = false

    init(task: BGTask) { self.task = task }

    func melde(erfolg: Bool) {
        let zuerst: Bool = sperre.around {
            guard !schonGemeldet else { return false }
            schonGemeldet = true
            return true
        }
        guard zuerst else { return }

        if Thread.isMainThread {
            task.setTaskCompleted(success: erfolg)
        } else {
            let aufgabe = task
            DispatchQueue.main.async { aufgabe.setTaskCompleted(success: erfolg) }
        }
    }
}
