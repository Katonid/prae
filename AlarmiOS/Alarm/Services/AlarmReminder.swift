//  AlarmReminder.swift
//  Local reminders until somebody answers.
//
//  A push arrives once. If the iPad was in a bag, in another room, or the
//  colleague was mid-sentence with a class, that one chance is gone. So the
//  device nags itself: every 30 seconds, up to ten times, with the same sound
//  and the same urgency — and it stops the moment an acknowledgement is sent
//  or the all-clear arrives.
//
//  Ten times is five minutes. Beyond that the notification is no longer
//  information, it is noise, and noise during an incident is its own hazard.

import UserNotifications

@MainActor
enum AlarmReminder {

    private static let prefix = "reminder-"
    static let count = 10
    static let interval: TimeInterval = 30

    /// Schedules the whole series at once.
    ///
    /// Ten separate requests rather than one repeating trigger, because
    /// `UNTimeIntervalNotificationTrigger` only repeats at 60 seconds or more,
    /// and half a minute is the interval that matters here.
    /// Gibt zurück, wie viele der Erinnerungen iOS ABGEWIESEN hat.
    ///
    /// Bis 1.1.0 (Build 39) hing die Dringlichkeitsstufe allein an
    /// `#if CRITICAL_ALERTS` — einer Bedingung des Übersetzens, die über die
    /// Erlaubnis auf dem Gerät nichts weiß. Auf jedem Gerät, dessen Lehrkraft
    /// kritische Hinweise abgelehnt hat, wies iOS deshalb JEDE der zehn
    /// Erinnerungen ab, und `try?` warf den Fehler weg: Der Push kam noch an,
    /// die Reihe danach nicht. Genau das Netz, das jemanden auffängt, der die
    /// erste Meldung verpasst hat — still weg.
    @discardableResult
    static func schedule(for alarm: Alarm) async -> Int {
        await cancel(alarmId: alarm.id)
        let center = UNUserNotificationCenter.current()
        let kritisch = await Meldungsstufe.kritischErlaubt()
        var abgewiesen = 0

        for step in 1...count {
            let content = UNMutableNotificationContent()
            content.title = NSLocalizedString("reminder.title", comment: "")
            content.body = NSLocalizedString("reminder.body", comment: "")
            content.categoryIdentifier = PushAsset.alarmCategory
            content.threadIdentifier = alarm.id
            content.userInfo = [PushKey.event: PushEventName.alarm,
                                PushKey.alarmId: alarm.id,
                                PushKey.type: alarm.type.rawValue]
            Meldungsstufe.setze(auf: content, ton: PushAsset.signalSound,
                                kritischErlaubt: kritisch)

            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: interval * Double(step), repeats: false)
            let request = UNNotificationRequest(identifier: identifier(alarm.id, step),
                                                content: content,
                                                trigger: trigger)
            do {
                try await center.add(request)
            } catch {
                abgewiesen += 1
            }
        }
        return abgewiesen
    }

    /// Stops the series. Called from three places — acknowledgement, all-clear,
    /// and app start with an alarm already answered — because missing any one
    /// of them means an iPad that keeps howling after the incident is over.
    static func cancel(alarmId: String) async {
        let ids = (1...count).map { identifier(alarmId, $0) }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids)
    }

    /// Clears every reminder, whichever alarm it belonged to.
    static func cancelAll() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let mine = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: mine)
        center.removeDeliveredNotifications(withIdentifiers: mine)
    }

    private static func identifier(_ alarmId: String, _ step: Int) -> String {
        "\(prefix)\(alarmId)-\(step)"
    }
}
