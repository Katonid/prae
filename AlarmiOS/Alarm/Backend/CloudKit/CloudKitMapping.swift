//  CloudKitMapping.swift
//  CKRecord in, model out — and back.
//
//  Two rules run through this file:
//
//  * Reading is forgiving. A record with a field this version does not know,
//    or missing a field it expected, still becomes a usable model. A schema
//    grows over years; an app that refuses to read yesterday's record is an
//    app that stops working after the first update.
//  * Dates are written as ISO-8601 TEXT, not as CloudKit `Date` fields.
//    Reason: alarm fields ride along in the push payload, and CloudKit encodes
//    a `Date` there as a bare number whose epoch is not documented. Getting it
//    wrong would mark every alarm as decades old — and this app mutes old
//    alarms. Text has one reading. Ordering still uses the server's own
//    `creationDate`, which no client can fake.

import CloudKit
import Foundation

enum CloudKitMapping {

    static let iso: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    // MARK: - Group

    static func group(from record: CKRecord) -> AlarmGroup {
        AlarmGroup(id: record.recordID.recordName,
                   name: record.string(CloudField.name) ?? "Schule",
                   locations: (record[CloudField.locations] as? [String]) ?? [],
                   instructions: instructions(from: record.string(CloudField.instructionsJSON)),
                   createdAt: record.date(CloudField.createdAt) ?? record.creationDate ?? Date())
    }

    /// Instructions are stored as one JSON string, not as a CloudKit
    /// dictionary — CloudKit has no dictionary field type, and a pair of
    /// parallel string lists would drift apart the first time somebody edits
    /// one of them.
    static func instructions(from json: String?) -> [String: String] {
        guard let json, let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return decoded
    }

    static func instructionsJSON(_ instructions: [String: String]) -> String {
        guard let data = try? JSONEncoder().encode(instructions),
              let text = String(data: data, encoding: .utf8)
        else { return "{}" }
        return text
    }

    // MARK: - Member

    static func member(from record: CKRecord) -> Member? {
        guard let groupId = record.reference(CloudField.groupRef),
              let userId = record.string(CloudField.userId)
        else { return nil }
        return Member(id: record.recordID.recordName,
                      groupId: groupId,
                      userId: userId,
                      displayName: record.string(CloudField.displayName) ?? "?",
                      role: record.string(CloudField.role)
                          .flatMap(MemberRole.init(rawValue:)) ?? .member,
                      joinedAt: record.date(CloudField.createdAt)
                          ?? record.creationDate ?? Date())
    }

    /// A member record has a derived name (`member-<group>-<user>`).
    ///
    /// So that rejoining the same group overwrites instead of adding a second
    /// row. Duplicate members would quietly break the acknowledgement count —
    /// the one number the head teacher looks at during an incident.
    static func memberRecordName(groupId: String, userId: String) -> String {
        "member-\(groupId)-\(userId)"
    }

    // MARK: - Alarm

    static func alarm(from record: CKRecord) -> Alarm? {
        guard let groupId = record.reference(CloudField.groupRef),
              let rawType = record.string(CloudField.type),
              let type = AlarmType(rawValue: rawType)
        else { return nil }

        let target = record.string(CloudField.targetUser)
        return Alarm(id: record.recordID.recordName,
                     groupId: groupId,
                     type: type,
                     status: record.string(CloudField.status)
                         .flatMap(AlarmStatus.init(rawValue:)) ?? .active,
                     location: record.string(CloudField.location),
                     triggeredByUserId: record.string(CloudField.triggeredByUserId) ?? "",
                     triggeredByName: record.string(CloudField.triggeredByName) ?? "?",
                     createdAt: record.date(CloudField.createdAt)
                         ?? record.creationDate ?? Date(),
                     clearedAt: record.date(CloudField.clearedAt),
                     clearedByName: record.string(CloudField.clearedByName),
                     instruction: record.string(CloudField.instruction),
                     targetUserId: target == CloudConstant.everyone ? nil : target)
    }

    static func apply(_ alarm: Alarm, to record: CKRecord, groupRecordID: CKRecord.ID) {
        record[CloudField.groupRef] = CKRecord.Reference(recordID: groupRecordID, action: .none)
        record[CloudField.alarmId] = record.recordID.recordName
        record[CloudField.type] = alarm.type.rawValue
        record[CloudField.status] = alarm.status.rawValue
        // Never nil: the fallback banner substitutes this field into a
        // localized format string, and a missing argument makes iOS drop the
        // whole alert.
        record[CloudField.location] = alarm.location
            ?? NSLocalizedString(PushString.unknownLocation, comment: "")
        record[CloudField.triggeredByUserId] = alarm.triggeredByUserId
        record[CloudField.triggeredByName] = alarm.triggeredByName
        record[CloudField.headline] = alarm.headline
        record[CloudField.targetUser] =
            (alarm.targetUserId ?? CloudConstant.everyone)
        record[CloudField.instruction] = alarm.instruction
        record[CloudField.instructionShort] =
            alarm.instruction.map(shortened)
        record.setDate(alarm.createdAt, forKey: CloudField.createdAt)
        record.setDate(alarm.clearedAt, forKey: CloudField.clearedAt)
        record[CloudField.clearedByName] = alarm.clearedByName
    }

    /// Cuts the instruction down to what fits in a push, on a sentence border
    /// where possible. A text that stops mid-word reads like a transmission
    /// error, and this is the one screen where nobody may wonder whether the
    /// message arrived in one piece.
    static func shortened(_ text: String) -> String {
        let flat = text.replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard flat.count > CloudConstant.instructionPushLimit else { return flat }
        let cut = flat.prefix(CloudConstant.instructionPushLimit)
        if let stop = cut.lastIndex(where: { ".!?".contains($0) }) {
            return String(cut[...stop])
        }
        if let space = cut.lastIndex(of: " ") {
            return String(cut[..<space]) + " …"
        }
        return String(cut) + " …"
    }

    // MARK: - Ack

    static func ack(from record: CKRecord) -> Ack? {
        guard let alarmId = record.reference(CloudField.alarmRef),
              let groupId = record.reference(CloudField.groupRef),
              let userId = record.string(CloudField.userId)
        else { return nil }
        return Ack(id: record.recordID.recordName,
                   alarmId: alarmId,
                   groupId: groupId,
                   userId: userId,
                   displayName: record.string(CloudField.displayName) ?? "?",
                   state: record.string(CloudField.state)
                       .flatMap(AckState.init(rawValue:)) ?? .secured,
                   location: record.string(CloudField.location),
                   createdAt: record.date(CloudField.createdAt)
                       ?? record.creationDate ?? Date())
    }

    /// One acknowledgement per person per alarm, by construction.
    ///
    /// A derived record name makes a second tap an update instead of a second
    /// row. Counting acknowledgements is the whole purpose of the list, and a
    /// count that goes up when somebody taps twice is worse than no count.
    static func ackRecordName(alarmId: String, userId: String) -> String {
        "ack-\(alarmId)-\(userId)"
    }

    // MARK: - Message

    static func message(from record: CKRecord) -> Message? {
        guard let alarmId = record.reference(CloudField.alarmRef),
              let groupId = record.reference(CloudField.groupRef),
              let text = record.string(CloudField.text)
        else { return nil }
        return Message(id: record.recordID.recordName,
                       alarmId: alarmId,
                       groupId: groupId,
                       senderUserId: record.string(CloudField.senderUserId) ?? "",
                       senderName: record.string(CloudField.senderName) ?? "?",
                       text: text,
                       createdAt: record.date(CloudField.createdAt)
                           ?? record.creationDate ?? Date())
    }

    // MARK: - DeviceStatus

    static func deviceStatus(from record: CKRecord) -> DeviceStatus? {
        guard let groupId = record.reference(CloudField.groupRef),
              let userId = record.string(CloudField.userId)
        else { return nil }
        return DeviceStatus(id: record.recordID.recordName,
                            groupId: groupId,
                            userId: userId,
                            displayName: record.string(CloudField.displayName) ?? "?",
                            deviceModel: record.string(CloudField.deviceModel) ?? "?",
                            appVersion: record.string(CloudField.appVersion) ?? "?",
                            notificationsAuthorized:
                                record.bool(CloudField.notificationsAuthorized),
                            timeSensitiveAllowed: record.bool(CloudField.timeSensitiveAllowed),
                            criticalAllowed: record.bool(CloudField.criticalAllowed),
                            iCloudAvailable: record.bool(CloudField.iCloudAvailable),
                            lastSeen: record.date(CloudField.lastSeen)
                                ?? record.modificationDate ?? Date.distantPast)
    }

    static func deviceRecordName(groupId: String, userId: String) -> String {
        "device-\(groupId)-\(userId)"
    }

    // MARK: - InviteCode

    static func inviteCode(from record: CKRecord) -> InviteCode? {
        guard let groupId = record.reference(CloudField.groupRef) else { return nil }
        return InviteCode(id: record.recordID.recordName,
                          groupId: groupId,
                          note: record.string(CloudField.note),
                          revoked: record.bool(CloudField.revoked),
                          createdAt: record.date(CloudField.createdAt)
                              ?? record.creationDate ?? Date())
    }
}
