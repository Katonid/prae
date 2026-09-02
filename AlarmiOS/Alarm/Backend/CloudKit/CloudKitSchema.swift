//  CloudKitSchema.swift
//  Record types and field names of the public CloudKit database.
//
//  Everything CloudKit-shaped lives under `Backend/CloudKit/`. Nothing outside
//  this folder may import CloudKit — that rule is what keeps the app portable,
//  and it is worth defending in review.

import CloudKit
import Foundation

enum CloudRecordType {
    static let group = "Group"
    static let inviteCode = "InviteCode"
    static let member = "Member"
    static let alarm = "Alarm"
    static let ack = "Ack"
    static let message = "Message"
    static let deviceStatus = "DeviceStatus"
    static let ping = "Ping"
}

/// Field names. The handful that also ride along in a push payload are
/// declared in `Shared/PushPayloadParser.swift` (`CloudFieldName`), because
/// the notification extension needs them and must not import CloudKit.
enum CloudField {
    // Shared with every record type
    static let groupRef = CloudFieldName.groupRef
    static let createdAt = CloudFieldName.createdAt

    // Group
    static let name = "name"
    static let locations = "locations"
    static let instructionsJSON = "instructionsJSON"

    // InviteCode
    static let note = "note"
    static let revoked = "revoked"

    // Member / DeviceStatus
    static let userId = "userId"
    static let displayName = "displayName"
    static let role = "role"
    static let deviceId = "deviceId"
    static let deviceModel = "deviceModel"
    static let appVersion = "appVersion"
    static let notificationsAuthorized = "notificationsAuthorized"
    static let timeSensitiveAllowed = "timeSensitiveAllowed"
    static let criticalAllowed = "criticalAllowed"
    static let iCloudAvailable = "iCloudAvailable"
    static let lastSeen = "lastSeen"

    // Alarm
    static let type = CloudFieldName.type
    static let status = CloudFieldName.status
    static let location = CloudFieldName.location
    static let triggeredByUserId = "triggeredByUserId"
    static let triggeredByName = CloudFieldName.triggeredByName
    static let clearedAt = CloudFieldName.clearedAt
    static let clearedByName = CloudFieldName.clearedByName
    static let instruction = CloudFieldName.instruction
    static let instructionShort = CloudFieldName.instructionShort
    static let headline = "headline"
    /// The record's own name, stored again as a plain field.
    ///
    /// Redundant on purpose: `collapseIDKey` names a FIELD whose value becomes
    /// the APNs collapse id, and the record name is not a field. Without it,
    /// two pushes for the same alarm stack up as two banners.
    static let alarmId = "alarmId"
    static let targetUser = CloudFieldName.targetUser

    // Ack / Message
    static let alarmRef = "alarmRef"
    static let state = "state"
    static let senderUserId = "senderUserId"
    static let senderName = "senderName"
    static let text = "text"
}

enum CloudConstant {
    /// `targetUser` of a record meant for the whole group.
    ///
    /// A sentinel rather than an absent field, because CloudKit predicates
    /// cannot compare against `nil` reliably — and a subscription whose
    /// predicate silently matches nothing is a device that never rings.
    static let everyone = "*"

    /// How much instruction text rides along in the push.
    ///
    /// An APNs payload is capped at 4 KB, and a `desiredKeys` field that blows
    /// the budget takes the whole notification down with it. The full text is
    /// on the record; the notification only needs the first sentence, and the
    /// alarm screen shows the rest a second later.
    static let instructionPushLimit = 180
}

/// Der Wortlaut des Dienstes, nicht unserer.
///
/// Liegt hier und nicht im Backend, weil `CloudKitSubscriptions` ihn ebenso
/// braucht: Ein abgelehntes Anlegen ist genau die Stelle, an der ein
/// aufgeräumter Satz die Spur vernichtet.
enum CloudKitFehler {
    static func rohtext(_ error: Error) -> String {
        guard let ck = error as? CKError else { return error.localizedDescription }
        var teile = ["[\(ck.code.rawValue)] \(ck.localizedDescription)"]
        if let grund = ck.userInfo[NSLocalizedFailureReasonErrorKey] as? String {
            teile.append(grund)
        }
        // Teilfehler: Bei `modifySubscriptions` steht ausschließlich hier,
        // welche Subscription woran gescheitert ist.
        if let teilfehler = ck.partialErrorsByItemID {
            for (kennung, unterfehler) in teilfehler {
                teile.append("→ \(kennung): \(rohtext(unterfehler))")
            }
        }
        if let unten = ck.userInfo[NSUnderlyingErrorKey] as? Error {
            teile.append("(\(rohtext(unten)))")
        }
        return teile.joined(separator: " ")
    }
}

/// Was `modifySubscriptions` NICHT wirft.
///
/// Die Methode wirft nur, wenn der ganze Aufruf scheitert. Lehnt CloudKit
/// einzelne Subscriptions ab, steht das in `saveResults` — und wer das
/// Ergebnis mit `_ =` wegwirft, liest „ohne Fehler durchgelaufen", während
/// kein einziges Abonnement entstanden ist. Genau so war es.
struct SubscriptionAbgelehnt: LocalizedError {
    let zeilen: [String]

    var errorDescription: String? {
        "CloudKit hat Subscriptions abgelehnt: " + zeilen.joined(separator: " | ")
    }
}

extension CKRecord {
    /// Reads a field as a trimmed, non-empty string.
    func string(_ key: String) -> String? {
        guard let value = self[key] as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// CloudKit has no boolean field type; a flag is an `Int64` of 0 or 1.
    /// Which numeric class it comes back as depends on how it was written, so
    /// all three readings are tried before giving up.
    func bool(_ key: String) -> Bool {
        if let value = self[key] as? Int64 { return value != 0 }
        if let value = self[key] as? Int { return value != 0 }
        if let value = self[key] as? NSNumber { return value.boolValue }
        return false
    }

    func date(_ key: String) -> Date? {
        guard let text = string(key) else { return nil }
        return CloudKitMapping.iso.date(from: text)
    }

    func reference(_ key: String) -> String? {
        (self[key] as? CKRecord.Reference)?.recordID.recordName
    }

    func setDate(_ date: Date?, forKey key: String) {
        self[key] = date.map { CloudKitMapping.iso.string(from: $0) }
    }

    func setBool(_ value: Bool, forKey key: String) {
        self[key] = Int64(value ? 1 : 0)
    }
}
