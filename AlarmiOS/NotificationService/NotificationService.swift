//  NotificationService.swift
//  The one piece of code that decides whether a locked iPad makes a noise.
//
//  Every push this app sends carries `mutable-content`, so iOS hands it to
//  this extension before showing anything. Three jobs, in this order of
//  importance:
//
//  1. Raise the interruption level. A `.timeSensitive` notification breaks
//     through Focus modes; a normal one does not. This is the single reason
//     the extension is mandatory rather than nice to have — a CloudKit
//     subscription cannot set the level itself.
//  2. Write a title and body a person can act on, from the fields that rode
//     along in the payload.
//  3. Normalize `userInfo` into the neutral format, so the app gets the same
//     dictionary shape no matter which backend sent the push.
//
//  What it must never do: drop a notification. If anything here fails, the
//  notification still goes out — with the reason in its text. A swallowed
//  alarm is the worst outcome this app has.

import UserNotifications

final class NotificationService: UNNotificationServiceExtension {

    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var mutableContent: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest,
                             withContentHandler contentHandler:
                             @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        let content = (request.content.mutableCopy() as? UNMutableNotificationContent)
            ?? UNMutableNotificationContent()
        self.mutableContent = content

        switch PushPayloadParser.event(from: request.content.userInfo) {
        case .success(let event):
            apply(event, to: content)
        case .failure(.notOurs):
            // Somebody else's push, or a CloudKit database-change ping. Pass it
            // through untouched rather than dressing it up as an alarm.
            break
        case .failure(let failure):
            describe(failure, in: content)
        }

        contentHandler(content)
    }

    /// iOS is about to give up on us. Deliver whatever we have — an
    /// unmodified alarm still beats no alarm.
    override func serviceExtensionTimeWillExpire() {
        if let handler = contentHandler, let content = mutableContent {
            handler(content)
        }
    }

    // MARK: - Building the notification

    private func apply(_ event: AlarmEvent, to content: UNMutableNotificationContent) {
        var info = PushPayloadParser.normalized(event, merging: content.userInfo)

        switch event {
        case .ping:
            // A ping is silent by contract. It should not have reached an
            // extension at all (its subscription sends content-available
            // only), but if it did, it stays invisible.
            content.userInfo = info
            content.sound = nil
            content.interruptionLevel = .passive
            return

        case .alarm(let push):
            let stale = isStale(push)
            content.title = title(for: push, stale: stale)
            content.body = body(triggeredBy: push.triggeredByName, at: push.createdAt)
            content.subtitle = push.instruction.map(firstLine) ?? ""
            content.categoryIdentifier = PushAsset.alarmCategory
            configureUrgency(content, sound: PushAsset.alarmSound, stale: stale)
            if stale { info[PushKey.stale] = true }

        case .selfTest(let push):
            content.title = localized(PushString.selfTestTitle)
            content.body = localized(PushString.selfTestBody)
            content.categoryIdentifier = PushAsset.alarmCategory
            configureUrgency(content, sound: PushAsset.alarmSound, stale: isStale(push))

        case .allClear(let push):
            content.title = localized(PushString.allClearTitle)
            content.body = String(format: localized(PushString.allClearBodyFormat),
                                  push.triggeredByName ?? localized(PushString.unknownPerson),
                                  timeText(push.createdAt))
            content.subtitle = ""
            content.categoryIdentifier = PushAsset.allClearCategory
            content.interruptionLevel = .active
            content.sound = UNNotificationSound(named:
                UNNotificationSoundName(PushAsset.allClearSound))
        }

        // One alarm, one notification on the lock screen — however many pushes
        // CloudKit decides to send for it.
        if let alarmId = event.alarmPayload?.alarmId {
            content.threadIdentifier = alarmId
        }
        content.userInfo = info
    }

    /// Interruption level and sound — the part that has to be right.
    ///
    /// `.critical` needs the `com.apple.developer.usernotifications.critical-alerts`
    /// entitlement, and Apple grants that on written request only. Without it a
    /// build that asks for critical alerts is rejected at signing time, so the
    /// whole branch hangs on the `CRITICAL_ALERTS` compilation condition and is
    /// off by default. `.timeSensitive` needs no permission beyond the
    /// `time-sensitive-notifications` capability and already breaks through
    /// every Focus mode the user has not explicitly denied us.
    private func configureUrgency(_ content: UNMutableNotificationContent,
                                  sound: String,
                                  stale: Bool) {
        guard !stale else {
            // An alarm nobody heard for three minutes is history, not an
            // emergency. It still gets shown — quietly.
            content.interruptionLevel = .passive
            content.sound = nil
            return
        }

        let name = UNNotificationSoundName(sound)
        #if CRITICAL_ALERTS
        content.interruptionLevel = .critical
        content.sound = UNNotificationSound.criticalSoundNamed(name, withAudioVolume: 1.0)
        #else
        content.interruptionLevel = .timeSensitive
        content.sound = UNNotificationSound(named: name)
        #endif
    }

    /// Older than three minutes counts as stale.
    ///
    /// A push can arrive late for honest reasons — the iPad was off, the
    /// network was gone, APNs held it back. Waking a whole staff room for an
    /// incident that ended half an hour ago costs the app its credibility, and
    /// the next real alarm pays for it. A payload without a timestamp is never
    /// treated as stale: not knowing is not the same as knowing it is old.
    private func isStale(_ push: AlarmPush) -> Bool {
        guard let age = push.age() else { return false }
        return age > PushAsset.staleAfter
    }

    private func title(for push: AlarmPush, stale: Bool) -> String {
        let headline = localized(push.type.titleKey)
        let place = push.location ?? localized(PushString.unknownLocation)
        let text = String(format: localized(PushString.alarmTitleFormat), headline, place)
        return stale ? text + " " + localized(PushString.staleSuffix) : text
    }

    private func body(triggeredBy name: String?, at date: Date?) -> String {
        String(format: localized(PushString.alarmBodyFormat),
               name ?? localized(PushString.unknownPerson),
               timeText(date))
    }

    private func describe(_ failure: PushPayloadParser.Failure,
                          in content: UNMutableNotificationContent) {
        content.title = localized("push.unreadable.title")
        content.body = String(format: localized("push.unreadable.body"), failure.reason)
        content.interruptionLevel = .active
        content.sound = .default
    }

    // MARK: - Small helpers

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    private func firstLine(_ text: String) -> String {
        text.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? text
    }

    private func timeText(_ date: Date?) -> String {
        guard let date else { return "" }
        return Self.clock.string(from: date)
    }

    /// Built once: a `DateFormatter` costs milliseconds, and this extension is
    /// on a stopwatch.
    private static let clock: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}
