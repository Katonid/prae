//  PushContract.swift
//  The wire format between "something happened" and "a device makes noise".
//
//  This file is the single source of truth for the neutral push format that
//  `docs/PUSH_CONTRACT.md` describes. A second backend (Firebase, an own APNs
//  server, an Android FCM sender) has to produce exactly these keys — and then
//  the whole delivery path of this app works unchanged.

import Foundation

/// Keys of the backend-neutral push payload.
///
/// They sit at the top level of `userInfo`, next to `aps`. Custom keys next to
/// `aps` are the one place every push provider agrees on: APNs, FCM and any
/// hand-written sender can put them there.
public enum PushKey {
    public static let event = "event"
    public static let alarmId = "alarmId"
    public static let type = "type"
    public static let status = "status"
    public static let location = "location"
    public static let triggeredByName = "triggeredByName"
    public static let createdAt = "createdAt"
    public static let instruction = "instruction"
    public static let clearedByName = "clearedByName"
    public static let groupId = "groupId"
    public static let targetUserId = "targetUserId"
    public static let pingId = "pingId"
    /// Set by the notification service extension once it has rewritten a
    /// CloudKit payload into the neutral format, so the app never has to look
    /// at `ck` again.
    public static let normalized = "normalized"
    /// Set by the extension when the alarm arrived too late to be urgent.
    public static let stale = "stale"
}

/// Values of `PushKey.event`.
public enum PushEventName {
    public static let alarm = "alarm"
    public static let allClear = "allClear"
    public static let ping = "ping"
    public static let selfTest = "selfTest"
}

/// Identifiers of the CloudKit subscriptions.
///
/// They are part of the contract, not an implementation detail: the parser
/// reads them out of `ck.qry.sid` to tell an alarm push from a ping push. They
/// carry a version suffix because a subscription's predicate cannot be edited
/// after the fact — a changed predicate means a new identifier and a one-time
/// cleanup of the old one (`CloudKitSubscriptions.reconcile`).
public enum SubscriptionID {
    public static let alarmCreated = "alarm-created-v2"
    public static let alarmCleared = "alarm-cleared-v2"
    public static let selfTest = "selftest-created-v2"
    /// Der Ping braucht ZWEI Abonnements, nicht eines.
    ///
    /// „an alle ODER an mich" wäre ein Prädikat mit `OR` — und **CloudKit
    /// kennt kein `OR`**. Es lehnt so ein Prädikat mit „Invalid predicate:
    /// Unexpected expression" ab, und zwar erst beim Anlegen, nicht beim
    /// Übersetzen. Zwei Abonnements mit je einem `==` tun dasselbe und
    /// benutzen nur, was CloudKit nachweislich versteht.
    public static let pingAll = "ping-all-v2"
    public static let pingMe = "ping-me-v2"

    public static let all = [alarmCreated, alarmCleared, selfTest, pingAll, pingMe]

    /// Ob eine Kennung zu einem Ping gehört — egal zu welchem der beiden.
    public static func istPing(_ kennung: String?) -> Bool {
        guard let kennung else { return false }
        return kennung == pingAll || kennung == pingMe || kennung.hasPrefix("ping-")
    }
}

/// Notification categories and sound file names.
public enum PushAsset {
    public static let alarmCategory = "ALARM"
    public static let allClearCategory = "ALLCLEAR"
    public static let alarmSound = "alarm.caf"
    public static let allClearSound = "allclear.caf"
    /// Notifications older than this are no longer interruptive; see
    /// `NotificationService`.
    public static let staleAfter: TimeInterval = 180
}

/// Localization keys used from both targets.
///
/// The extension has no access to the app's `Bundle.main` strings — it has its
/// own bundle — so `de.lproj/Localizable.strings` is a resource of BOTH
/// targets. Keeping the keys here stops the two copies from drifting apart.
public enum PushString {
    /// The text APNs brings along for the case where the extension never runs.
    /// Resolved by iOS against the APP bundle, with raw record fields as
    /// arguments — which is why `headline` exists as a field.
    public static let alarmFallback = "push.alarm.fallback"
    public static let allClearFallback = "push.allclear.fallback"
    public static let alarmTitleFormat = "push.alarm.title"        // "%@ – %@"
    public static let alarmBodyFormat = "push.alarm.body"          // "Ort: %@ · ausgelöst von %@"
    public static let alarmBodyShort = "push.alarm.body.short"
    public static let allClearTitle = "push.allclear.title"
    public static let allClearBodyFormat = "push.allclear.body"
    public static let selfTestTitle = "push.selftest.title"
    public static let selfTestBody = "push.selftest.body"
    public static let staleSuffix = "push.stale.suffix"
    public static let unknownPerson = "push.unknown.person"
    public static let unknownLocation = "push.unknown.location"
}
