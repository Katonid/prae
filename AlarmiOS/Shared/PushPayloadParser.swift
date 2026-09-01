//  PushPayloadParser.swift
//  Turns a raw `userInfo` dictionary into an `AlarmEvent`.
//
//  Two input formats, one output type:
//
//  1. The CloudKit format, recognised by the `ck` key. CloudKit builds this
//     dictionary itself; we cannot influence its shape, only which record
//     fields ride along (the subscription's `desiredKeys`).
//  2. The neutral format described in `docs/PUSH_CONTRACT.md`. This is what a
//     later backend sends, and it is also what this parser writes back into
//     `userInfo` after reading a CloudKit push — so the rest of the app only
//     ever sees one format.
//
//  Deliberately no CloudKit import. The extension must not link CloudKit for
//  the sake of reading four strings, and the neutral format is supposed to
//  outlive the CloudKit backend.

import Foundation

public enum PushPayloadParser {

    /// Why a payload could not be turned into an event.
    ///
    /// There is no "ignore quietly" path. A push this app cannot read is
    /// either not ours (`notOurs` — fine, happens) or a bug we want to see
    /// (`malformed`). The extension puts the reason into the notification
    /// rather than letting it disappear.
    public enum Failure: Error, Equatable {
        case notOurs
        case malformed(String)

        public var reason: String {
            switch self {
            case .notOurs: return "kein Alarm-Push"
            case .malformed(let detail): return detail
            }
        }
    }

    // MARK: - Entry point

    public static func event(from userInfo: [AnyHashable: Any]) -> Result<AlarmEvent, Failure> {
        if userInfo[PushKey.event] != nil {
            return neutral(userInfo)
        }
        if let ck = userInfo["ck"] as? [String: Any] {
            return cloudKit(ck)
        }
        return .failure(.notOurs)
    }

    // MARK: - Neutral format

    private static func neutral(_ info: [AnyHashable: Any]) -> Result<AlarmEvent, Failure> {
        guard let name = info[PushKey.event] as? String else {
            return .failure(.malformed("Feld „event\u{201C} ist kein Text"))
        }

        if name == PushEventName.ping {
            return .success(.ping(PingPush(pingId: info[PushKey.pingId] as? String,
                                           groupId: info[PushKey.groupId] as? String,
                                           targetUserId: info[PushKey.targetUserId] as? String)))
        }

        guard let alarmId = info[PushKey.alarmId] as? String, !alarmId.isEmpty else {
            return .failure(.malformed("Feld „alarmId\u{201C} fehlt"))
        }
        guard let raw = info[PushKey.type] as? String, let type = AlarmType(rawValue: raw) else {
            return .failure(.malformed("Feld „type\u{201C} fehlt oder ist unbekannt"))
        }

        let push = AlarmPush(alarmId: alarmId,
                             type: type,
                             groupId: info[PushKey.groupId] as? String,
                             location: text(info[PushKey.location]),
                             triggeredByName: text(info[PushKey.triggeredByName]),
                             createdAt: date(info[PushKey.createdAt]),
                             instruction: text(info[PushKey.instruction]),
                             clearedByName: text(info[PushKey.clearedByName]))

        switch name {
        case PushEventName.alarm: return .success(.alarm(push))
        case PushEventName.allClear: return .success(.allClear(push))
        case PushEventName.selfTest: return .success(.selfTest(push))
        default: return .failure(.malformed("Unbekanntes Ereignis „\(name)\u{201C}"))
        }
    }

    // MARK: - CloudKit format

    /// The shape we rely on:
    ///
    ///     ck = { qry = { sid = "alarm-created-v1";
    ///                    fo  = 1;                    // 1 create, 2 update, 3 delete
    ///                    rid = "<record name>";
    ///                    af  = { type = amok; location = "Aula"; … } } }
    ///
    /// `af` holds the subscription's `desiredKeys`. Only the fields listed
    /// there arrive; everything else has to be fetched by the app later.
    private static func cloudKit(_ ck: [String: Any]) -> Result<AlarmEvent, Failure> {
        guard let query = ck["qry"] as? [String: Any] else {
            // A database-changed push (`ck.fet`) is legitimate but carries no
            // alarm — not ours to present.
            return .failure(.notOurs)
        }
        let subscription = query["sid"] as? String
        let fields = (query["af"] as? [String: Any]) ?? [:]
        let recordName = query["rid"] as? String

        if SubscriptionID.istPing(subscription) {
            return .success(.ping(PingPush(pingId: recordName,
                                           groupId: reference(fields[CloudFieldName.groupRef]),
                                           targetUserId: text(fields[CloudFieldName.targetUser]))))
        }

        guard let alarmId = recordName, !alarmId.isEmpty else {
            return .failure(.malformed("CloudKit-Push ohne Datensatzkennung"))
        }
        guard let raw = text(fields[CloudFieldName.type]),
              let type = AlarmType(rawValue: raw) else {
            // Without `desiredKeys` the payload has no type. Showing a
            // notification that cannot name the emergency is worse than
            // saying so plainly.
            return .failure(.malformed("CloudKit-Push ohne Feld „type\u{201C} — "
                                       + "desiredKeys der Subscription prüfen"))
        }

        let push = AlarmPush(alarmId: alarmId,
                             type: type,
                             groupId: reference(fields[CloudFieldName.groupRef]),
                             location: text(fields[CloudFieldName.location]),
                             triggeredByName: text(fields[CloudFieldName.triggeredByName]),
                             createdAt: date(fields[CloudFieldName.createdAt]),
                             instruction: text(fields[CloudFieldName.instructionShort])
                                 ?? text(fields[CloudFieldName.instruction]),
                             clearedByName: text(fields[CloudFieldName.clearedByName]))

        let status = text(fields[CloudFieldName.status]).flatMap(AlarmStatus.init(rawValue:))
        let hasTarget = text(fields[CloudFieldName.targetUser]) != nil

        if subscription == SubscriptionID.alarmCleared || status == .cleared {
            return .success(.allClear(push))
        }
        if subscription == SubscriptionID.selfTest || (type == .test && hasTarget) {
            return .success(.selfTest(push))
        }
        return .success(.alarm(push))
    }

    // MARK: - Writing the neutral format back

    /// Rewrites `userInfo` into the neutral format.
    ///
    /// The extension calls this so that the app — which sees the payload again
    /// when the user taps the notification — never has to know CloudKit's
    /// dictionary shape. `ck` is kept: throwing away information we did not
    /// write is not the parser's call.
    public static func normalized(_ event: AlarmEvent,
                                  merging userInfo: [AnyHashable: Any]) -> [AnyHashable: Any] {
        var info = userInfo
        info[PushKey.normalized] = true

        switch event {
        case .ping(let ping):
            info[PushKey.event] = PushEventName.ping
            info[PushKey.pingId] = ping.pingId
            info[PushKey.groupId] = ping.groupId
            info[PushKey.targetUserId] = ping.targetUserId
            return info
        case .alarm(let push):
            info[PushKey.event] = PushEventName.alarm
            return merge(push, into: info)
        case .allClear(let push):
            info[PushKey.event] = PushEventName.allClear
            return merge(push, into: info)
        case .selfTest(let push):
            info[PushKey.event] = PushEventName.selfTest
            return merge(push, into: info)
        }
    }

    private static func merge(_ push: AlarmPush,
                              into userInfo: [AnyHashable: Any]) -> [AnyHashable: Any] {
        var info = userInfo
        info[PushKey.alarmId] = push.alarmId
        info[PushKey.type] = push.type.rawValue
        info[PushKey.groupId] = push.groupId
        info[PushKey.location] = push.location
        info[PushKey.triggeredByName] = push.triggeredByName
        info[PushKey.instruction] = push.instruction
        info[PushKey.clearedByName] = push.clearedByName
        info[PushKey.createdAt] = push.createdAt.map(iso.string(from:))
        return info
    }

    // MARK: - Value reading

    /// One formatter, created once. `ISO8601DateFormatter` is expensive to
    /// build, and the extension is on a stopwatch.
    static let iso: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static func text(_ value: Any?) -> String? {
        guard let string = value as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// A CloudKit reference arrives either as the plain record name or as a
    /// dictionary with a `recordName` key, depending on the field type.
    private static func reference(_ value: Any?) -> String? {
        if let string = text(value) { return string }
        if let dict = value as? [String: Any] { return text(dict["recordName"]) }
        return nil
    }

    /// Dates ride along as ISO-8601 text.
    ///
    /// That is a deliberate choice on the writing side (`CloudKitMapping`):
    /// CloudKit encodes a `Date` field into the push payload as a bare number,
    /// and whether that number counts from 1970 or from Apple's 2001 reference
    /// date is not documented anywhere we could rely on. A wrong epoch would
    /// silently mark every alarm as 31 years old — and this app throttles old
    /// alarms. Numbers are still accepted here, on both readings, so a future
    /// backend that sends epoch seconds is not locked out.
    private static func date(_ value: Any?) -> Date? {
        if let string = text(value) {
            if let parsed = iso.date(from: string) { return parsed }
            if let seconds = Double(string) { return date(fromNumber: seconds) }
            return nil
        }
        if let number = value as? Double { return date(fromNumber: number) }
        if let number = value as? Int { return date(fromNumber: Double(number)) }
        return nil
    }

    /// Below the 2001 reference date in Unix seconds, a number can only be an
    /// Apple reference-date interval; above it, only a Unix timestamp.
    private static func date(fromNumber seconds: Double) -> Date {
        let appleEpochInUnixSeconds = 978_307_200.0
        return seconds < appleEpochInUnixSeconds
            ? Date(timeIntervalSinceReferenceDate: seconds)
            : Date(timeIntervalSince1970: seconds)
    }
}

/// Names of the CloudKit record fields that ride along in a push.
///
/// They live here rather than in `Backend/CloudKit/` because the extension
/// needs them and must not import CloudKit. The record TYPES and everything
/// else about CloudKit stay where they belong.
public enum CloudFieldName {
    public static let groupRef = "groupRef"
    public static let type = "type"
    public static let status = "status"
    public static let location = "location"
    public static let triggeredByName = "triggeredByName"
    public static let createdAt = "createdAt"
    public static let instruction = "instruction"
    /// The first sentence of the instruction, and the only one that rides
    /// along in a push: an APNs payload is capped at 4 KB, and one oversized
    /// field takes the whole notification down with it.
    public static let instructionShort = "instructionShort"
    public static let targetUser = "targetUser"
    public static let clearedByName = "clearedByName"
    public static let clearedAt = "clearedAt"
}
