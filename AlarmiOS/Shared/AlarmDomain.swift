//  AlarmDomain.swift
//  Vocabulary shared by the app and the notification service extension.
//
//  Everything in `Shared/` is compiled into BOTH targets. It must therefore
//  stay free of any backend framework: no CloudKit, no networking, no SwiftUI.
//  A notification service extension gets roughly 30 seconds of wall clock and
//  a small memory budget — it cannot afford to link a database SDK just to
//  read four strings out of a payload.

import Foundation

/// What kind of emergency an alarm announces.
///
/// The raw values travel over the wire (CloudKit field, push payload, and any
/// future backend), so they are stable identifiers and never localized. The
/// German wording lives in `Localizable.strings`.
public enum AlarmType: String, Codable, CaseIterable, Sendable {
    case amok
    case fire
    case medical
    case test

    /// Key into `Localizable.strings` for the headline ("AMOKALARM").
    public var titleKey: String { "alarm.type.\(rawValue).title" }

    /// Key for the short description used in notification bodies.
    public var shortKey: String { "alarm.type.\(rawValue).short" }

    /// A drill must never look like the real thing, not even for a second.
    public var isDrill: Bool { self == .test }
}

/// Lifecycle of an alarm record.
public enum AlarmStatus: String, Codable, Sendable {
    case active
    case cleared
}

/// The payload of an alarm-shaped push, in backend-neutral form.
///
/// Every field is optional except `alarmId` and `type`: a push that lost a
/// field on the way is still worth showing. Dropping the whole notification
/// because the location string was missing would be the worst possible trade
/// this app could make.
public struct AlarmPush: Codable, Equatable, Sendable {
    public var alarmId: String
    public var type: AlarmType
    public var groupId: String?
    public var location: String?
    public var triggeredByName: String?
    public var createdAt: Date?
    public var instruction: String?
    /// Who called the all-clear. Only an `allClear` event carries it — and it
    /// is NOT the same person as `triggeredByName`, which is exactly why it
    /// needs a field of its own: the banner "Entwarnung durch …" naming the
    /// person who raised the alarm would be quietly wrong.
    public var clearedByName: String?

    public init(alarmId: String,
                type: AlarmType,
                groupId: String? = nil,
                location: String? = nil,
                triggeredByName: String? = nil,
                createdAt: Date? = nil,
                instruction: String? = nil,
                clearedByName: String? = nil) {
        self.alarmId = alarmId
        self.type = type
        self.groupId = groupId
        self.location = location
        self.triggeredByName = triggeredByName
        self.createdAt = createdAt
        self.instruction = instruction
        self.clearedByName = clearedByName
    }

    /// How long ago the alarm was raised, or `nil` when it carries no time.
    public func age(now: Date = Date()) -> TimeInterval? {
        createdAt.map { now.timeIntervalSince($0) }
    }
}

/// The payload of a silent "report your status" push.
public struct PingPush: Codable, Equatable, Sendable {
    public var pingId: String?
    public var groupId: String?
    /// `nil` means "every device in the group".
    public var targetUserId: String?

    public init(pingId: String? = nil, groupId: String? = nil, targetUserId: String? = nil) {
        self.pingId = pingId
        self.groupId = groupId
        self.targetUserId = targetUserId
    }
}

/// Everything a push can mean to this app.
///
/// The parser turns a raw `userInfo` dictionary into exactly one of these, or
/// reports why it could not. There is no "unknown" case on purpose: an
/// unrecognised push must not be presented as an alarm, and it must not be
/// swallowed in silence either — see `PushPayloadParser.Failure`.
public enum AlarmEvent: Equatable, Sendable {
    case alarm(AlarmPush)
    case allClear(AlarmPush)
    case ping(PingPush)
    case selfTest(AlarmPush)
    case message(MessagePush)

    /// The alarm payload, for the three cases that carry one.
    public var alarmPayload: AlarmPush? {
        switch self {
        case .alarm(let push), .allClear(let push), .selfTest(let push): return push
        case .ping, .message: return nil
        }
    }

    /// Zu welchem Alarm das Ereignis gehört — auch bei einer Nachricht.
    public var alarmId: String? {
        if case .message(let push) = self { return push.alarmId }
        return alarmPayload?.alarmId
    }

    /// A ping is the only event that may stay invisible.
    public var isSilent: Bool {
        if case .ping = self { return true }
        return false
    }
}

/// Eine Nachricht, die während eines Alarms geschrieben wurde.
///
/// Sie reist als eigenes Ereignis, nicht als Alarm: Der Ton ist ein anderer,
/// die Dringlichkeit ist eine andere, und eine Nachricht darf den
/// Alarm-Bildschirm nicht zurückholen, den jemand bewusst zur Seite gelegt
/// hat.
public struct MessagePush: Codable, Equatable, Sendable {
    public var messageId: String?
    public var alarmId: String?
    public var groupId: String?
    public var senderName: String?
    public var text: String?

    public init(messageId: String? = nil,
                alarmId: String? = nil,
                groupId: String? = nil,
                senderName: String? = nil,
                text: String? = nil) {
        self.messageId = messageId
        self.alarmId = alarmId
        self.groupId = groupId
        self.senderName = senderName
        self.text = text
    }
}
