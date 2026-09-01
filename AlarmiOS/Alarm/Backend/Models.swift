//  Models.swift
//  Backend-neutral data model.
//
//  Plain `struct`s, `Codable`, no framework types. Nothing here knows that
//  CloudKit exists; a Firebase or REST implementation would produce exactly
//  these values from a completely different wire format. That is the whole
//  point of the exercise — see `docs/BACKEND_MIGRATION.md`.

import Foundation

/// A school (or, more precisely: one alarm circle).
///
/// Named `AlarmGroup` rather than `Group`: SwiftUI ships a `Group` view, and a
/// model type of the same name turns every `Group { … }` in the view layer
/// into a compiler error that reads like a puzzle.
struct AlarmGroup: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    /// Rooms and places offered when raising an alarm, in the order the admin
    /// arranged them.
    var locations: [String]
    /// What to do, per alarm type. Keyed by `AlarmType.rawValue` so the type
    /// stays `Codable` without a custom coder.
    var instructions: [String: String]
    var createdAt: Date

    init(id: String,
         name: String,
         locations: [String] = [],
         instructions: [String: String] = [:],
         createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.locations = locations
        self.instructions = instructions
        self.createdAt = createdAt
    }

    func instruction(for type: AlarmType) -> String? {
        let text = instructions[type.rawValue]?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (text?.isEmpty ?? true) ? nil : text
    }
}

enum MemberRole: String, Codable, CaseIterable {
    case admin
    case member

    var label: String { self == .admin ? "Leitung" : "Kollegium" }
}

/// One person in the group.
///
/// `displayName` is a short handle ("MÜ", "Kl. 3b"), not a full name — see the
/// data-protection section of the README. `userId` is the backend's own
/// account identifier (with CloudKit: the user record name), which is what
/// makes "this device belongs to that person" work across app reinstalls.
struct Member: Codable, Identifiable, Equatable {
    var id: String
    var groupId: String
    var userId: String
    var displayName: String
    var role: MemberRole
    var joinedAt: Date

    init(id: String,
         groupId: String,
         userId: String,
         displayName: String,
         role: MemberRole = .member,
         joinedAt: Date = Date()) {
        self.id = id
        self.groupId = groupId
        self.userId = userId
        self.displayName = displayName
        self.role = role
        self.joinedAt = joinedAt
    }
}

/// A raised alarm. The central record: creating it is what makes 30 iPads
/// scream, updating it to `cleared` is what makes them stop.
struct Alarm: Codable, Identifiable, Equatable {
    var id: String
    var groupId: String
    var type: AlarmType
    var status: AlarmStatus
    var location: String?
    var triggeredByUserId: String
    var triggeredByName: String
    var createdAt: Date
    var clearedAt: Date?
    var clearedByName: String?
    /// A copy of the group's instruction text at the moment of triggering.
    ///
    /// Copied, not referenced: the notification has to carry it (the extension
    /// cannot query anything), and an instruction that was edited afterwards
    /// must not rewrite what people were told during the incident.
    var instruction: String?
    /// Set only for a self-test, so that exactly one device sees it.
    var targetUserId: String?

    init(id: String,
         groupId: String,
         type: AlarmType,
         status: AlarmStatus = .active,
         location: String? = nil,
         triggeredByUserId: String,
         triggeredByName: String,
         createdAt: Date = Date(),
         clearedAt: Date? = nil,
         clearedByName: String? = nil,
         instruction: String? = nil,
         targetUserId: String? = nil) {
        self.id = id
        self.groupId = groupId
        self.type = type
        self.status = status
        self.location = location
        self.triggeredByUserId = triggeredByUserId
        self.triggeredByName = triggeredByName
        self.createdAt = createdAt
        self.clearedAt = clearedAt
        self.clearedByName = clearedByName
        self.instruction = instruction
        self.targetUserId = targetUserId
    }

    var isActive: Bool { status == .active }

    /// Ein Probealarm an genau ein Gerät — der Zustelltest.
    var istGezielterProbealarm: Bool { type == .test && targetUserId != nil }

    /// Wie lange ein gezielter Probealarm überhaupt gelten kann.
    ///
    /// Er ist in Sekunden zu sehen oder gar nicht. Ein iPad, das erst eine
    /// Stunde später aus dem Schrank kommt, soll deswegen nicht losgehen —
    /// und vor allem sollen sich nicht mehrere Tests stapeln, von denen jeder
    /// der Reihe nach zum „laufenden Alarm" wird. Genau das ist passiert
    /// (gemeldet 09/2026: „schaltet sich nach ein paar Sekunden wieder an").
    static let probealarmGiltFuer: TimeInterval = 10 * 60

    /// Ist dieser Alarm einer, der jetzt noch jemanden angehen sollte?
    ///
    /// Für echte Alarme immer ja, solange sie laufen: Ein Amokalarm, den seit
    /// zwei Stunden niemand entwarnt hat, ist zwei Stunden alt und trotzdem
    /// gültig. Die Entwarnung beendet ihn, nicht die Uhr.
    func giltNoch(now: Date = Date()) -> Bool {
        guard istGezielterProbealarm else { return true }
        return now.timeIntervalSince(createdAt) < Self.probealarmGiltFuer
    }

    /// The German headline, stored on the record so that a fallback banner —
    /// one that iOS builds without the extension — can name the emergency.
    /// APNs localization arguments are raw field values; `"amok"` on a lock
    /// screen helps nobody.
    var headline: String { NSLocalizedString(type.titleKey, comment: "") }
}

enum AckState: String, Codable, CaseIterable {
    case secured
    case needsHelp

    var label: String {
        switch self {
        case .secured: return "Klasse gesichert"
        case .needsHelp: return "Hilfe nötig"
        }
    }
}

/// "I have seen the alarm, and this is my situation."
struct Ack: Codable, Identifiable, Equatable {
    var id: String
    var alarmId: String
    var groupId: String
    var userId: String
    var displayName: String
    var state: AckState
    var location: String?
    var createdAt: Date

    init(id: String,
         alarmId: String,
         groupId: String,
         userId: String,
         displayName: String,
         state: AckState,
         location: String? = nil,
         createdAt: Date = Date()) {
        self.id = id
        self.alarmId = alarmId
        self.groupId = groupId
        self.userId = userId
        self.displayName = displayName
        self.state = state
        self.location = location
        self.createdAt = createdAt
    }
}

/// A line of text written during an alarm.
struct Message: Codable, Identifiable, Equatable {
    var id: String
    var alarmId: String
    var groupId: String
    var senderUserId: String
    var senderName: String
    var text: String
    var createdAt: Date

    init(id: String,
         alarmId: String,
         groupId: String,
         senderUserId: String,
         senderName: String,
         text: String,
         createdAt: Date = Date()) {
        self.id = id
        self.alarmId = alarmId
        self.groupId = groupId
        self.senderUserId = senderUserId
        self.senderName = senderName
        self.text = text
        self.createdAt = createdAt
    }
}

/// What one device last reported about itself.
///
/// This is the closest thing to a health check an app without a server can
/// have: not "is the device reachable right now", but "when did it last say
/// anything, and did it have permission to make noise at that moment".
struct DeviceStatus: Codable, Identifiable, Equatable {
    var id: String
    var groupId: String
    var userId: String
    var displayName: String
    var deviceModel: String
    var appVersion: String
    var notificationsAuthorized: Bool
    var timeSensitiveAllowed: Bool
    var criticalAllowed: Bool
    var iCloudAvailable: Bool
    var lastSeen: Date

    /// Red in the device list. Two days, because a school week has weekends
    /// and an iPad in a cupboard over a Sunday is not a fault.
    static let silentAfter: TimeInterval = 48 * 60 * 60

    func isSilent(now: Date = Date()) -> Bool {
        now.timeIntervalSince(lastSeen) > Self.silentAfter
    }

    /// Everything that has to be true for this device to actually ring.
    var isFit: Bool {
        notificationsAuthorized && timeSensitiveAllowed && iCloudAvailable
    }
}

/// A six-character code that lets a device join.
struct InviteCode: Codable, Identifiable, Equatable {
    var id: String
    var groupId: String
    var note: String?
    var revoked: Bool
    var createdAt: Date

    init(id: String,
         groupId: String,
         note: String? = nil,
         revoked: Bool = false,
         createdAt: Date = Date()) {
        self.id = id
        self.groupId = groupId
        self.note = note
        self.revoked = revoked
        self.createdAt = createdAt
    }

    /// Ambiguous characters are left out on purpose: a code is read aloud
    /// across a staff room and typed on a glass keyboard. I/1 and O/0 are the
    /// two pairs that go wrong. Same rule as in the Wörterwerkstatt class code.
    static let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

    static func random() -> String {
        String((0..<6).map { _ in alphabet.randomElement()! })
    }

    /// Normalizes typed input. Upper-cases and drops spaces — but never
    /// *guesses*: turning a typed `0` into `O` would accept a code that does
    /// not exist and blame the user for it.
    static func normalize(_ input: String) -> String {
        input.uppercased().filter { !$0.isWhitespace && $0 != "-" }
    }
}

/// One line of the delivery diagnosis.
///
/// The app cannot fix a CloudKit schema, and it cannot see into APNs. What it
/// can do is stop the guessing: name every link of the chain, say which one
/// answered and which one did not, and print the service's own error text
/// rather than a tidy sentence of its own. „Field 'groupRef' is not marked
/// queryable" is worth more to whoever has to fix it than „Verbindung
/// fehlgeschlagen".
struct Diagnose: Identifiable, Equatable {
    enum Befund: Equatable {
        case gut
        case schlecht
        case hinweis
    }

    var id: String
    var titel: String
    var text: String
    var befund: Befund

    var symbol: String {
        switch befund {
        case .gut: return "checkmark.circle.fill"
        case .schlecht: return "xmark.octagon.fill"
        case .hinweis: return "info.circle"
        }
    }
}

/// What `joinGroup` gives back.
struct Membership: Equatable {
    var group: AlarmGroup
    var member: Member
}

/// What the clean-up actually removed.
struct CleanupReport: Equatable {
    var alarms: Int
    var acks: Int
    var messages: Int

    var isEmpty: Bool { alarms == 0 && acks == 0 && messages == 0 }

    var summary: String {
        isEmpty
            ? "Nichts zu löschen — alles jünger als die Aufbewahrungsfrist."
            : "Gelöscht: \(alarms) Alarme, \(acks) Rückmeldungen, \(messages) Nachrichten."
    }
}

/// What a device reports about itself when it registers or answers a ping.
struct DeviceStatusDraft: Equatable {
    var deviceModel: String
    var appVersion: String
    var notificationsAuthorized: Bool
    var timeSensitiveAllowed: Bool
    var criticalAllowed: Bool
    var iCloudAvailable: Bool
}

/// The default action texts.
///
/// Deliberately neutral placeholders. Real instructions for an intruder alarm
/// are agreed with the head teacher and the police — an app must not put words
/// into that document, and a text that merely sounds authoritative is worse
/// than an obvious blank.
enum DefaultInstructions {
    static let byType: [String: String] = [
        AlarmType.amok.rawValue: """
        Platzhalter — bitte mit Schulleitung und Polizei abstimmen.
        Beispielhafter Aufbau: Tür verschließen, Fenster und Sichtachsen \
        meiden, Ruhe bewahren, Handys stumm, auf Entwarnung warten.
        """,
        AlarmType.fire.rawValue: """
        Platzhalter — bitte mit Schulleitung und Feuerwehr abstimmen.
        Beispielhafter Aufbau: Klasse vollzählig zum Sammelplatz führen, \
        Klassenbuch mitnehmen, Fenster und Türen schließen.
        """,
        AlarmType.medical.rawValue: """
        Platzhalter — bitte mit Schulleitung abstimmen.
        Beispielhafter Aufbau: Ersthelfer verständigen, Weg für den \
        Rettungsdienst frei halten, Klasse ruhig im Raum behalten.
        """,
        AlarmType.test.rawValue: """
        Probealarm. Es besteht keine Gefahr. Bitte nur die Rückmeldung geben, \
        damit das Kollegium die Zustellung prüfen kann.
        """
    ]

    static let locations = ["Sekretariat", "Lehrerzimmer", "Aula", "Turnhalle",
                            "Schulhof", "Erdgeschoss", "1. Obergeschoss"]
}
