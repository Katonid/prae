//  CloudKitBackend.swift
//  The only implementation of `AlarmBackend` that talks to a real service.
//
//  Design notes that are not obvious from the code:
//
//  * PUBLIC database. A private database is per-account and a shared database
//    needs an explicit invitation per record — neither reaches 30 colleagues
//    within seconds. The price is honest and documented in the README: the
//    public database can only distinguish "any signed-in iCloud user" from
//    "the record's creator". It cannot enforce "only members of this group".
//  * Delivery runs on subscriptions (see `CloudKitSubscriptions`). Polling is
//    the safety net, not the mechanism: five seconds while an alarm is
//    running, half a minute otherwise. A missed push must not mean a missed
//    alarm, and a device that polls every five seconds all day would be a
//    battery complaint by Friday.
//  * Every record carries `groupRef`. Every query filters on it. A school that
//    shares the container with another school must never see its records.

import CloudKit
import Foundation
import UIKit

final class CloudKitBackend: AlarmBackend {

    private let container: CKContainer
    private var database: CKDatabase { container.publicCloudDatabase }
    private let store: MembershipStore

    /// Cached account identifier. Fetching it costs a round trip, and it is
    /// needed on nearly every call.
    private var cachedUserId: String?

    // Watchers and their poll loop.
    private let lock = NSLock()
    private var alarmWatchers: [UUID: AsyncStream<Alarm?>.Continuation] = [:]
    private var ackWatchers: [UUID: (alarmId: String, sink: AsyncStream<[Ack]>.Continuation)] = [:]
    private var messageWatchers: [UUID: (alarmId: String,
                                         sink: AsyncStream<[Message]>.Continuation)] = [:]
    private var pollTask: Task<Void, Never>?
    private var lastKnownAlarm: Alarm?

    init(containerIdentifier: String, store: MembershipStore = MembershipStore()) {
        self.container = CKContainer(identifier: containerIdentifier)
        self.store = store
    }

    deinit { pollTask?.cancel() }

    // MARK: - Account and device

    func currentUserId() async -> String? {
        if let cachedUserId { return cachedUserId }
        do {
            let id = try await container.userRecordID().recordName
            cachedUserId = id
            return id
        } catch {
            return nil
        }
    }

    func availability() async -> BackendAvailability {
        do {
            switch try await container.accountStatus() {
            case .available: return .ready
            case .noAccount: return .noAccount
            case .restricted: return .restricted
            case .couldNotDetermine: return .networkUnavailable
            case .temporarilyUnavailable: return .networkUnavailable
            @unknown default: return .unknown("unbekannter Kontostatus")
            }
        } catch {
            return .unknown(error.localizedDescription)
        }
    }

    func registerDevice(_ draft: DeviceStatusDraft) async throws {
        let groupID = try requireGroupID()
        guard let userId = await currentUserId() else {
            throw BackendError.accountUnavailable(await availability())
        }
        let name = CloudKitMapping.deviceRecordName(groupId: groupID.recordName, userId: userId)
        try await upsert(recordID: CKRecord.ID(recordName: name),
                         type: CloudRecordType.deviceStatus) { record in
            record[CloudField.groupRef] = CKRecord.Reference(recordID: groupID, action: .none)
            record[CloudField.userId] = userId
            record[CloudField.displayName] = self.store.displayName ?? "?"
            record[CloudField.deviceModel] = draft.deviceModel
            record[CloudField.appVersion] = draft.appVersion
            record.setBool(draft.notificationsAuthorized,
                           forKey: CloudField.notificationsAuthorized)
            record.setBool(draft.timeSensitiveAllowed, forKey: CloudField.timeSensitiveAllowed)
            record.setBool(draft.criticalAllowed, forKey: CloudField.criticalAllowed)
            record.setBool(draft.iCloudAvailable, forKey: CloudField.iCloudAvailable)
            record.setDate(Date(), forKey: CloudField.lastSeen)
            if record[CloudField.createdAt] == nil {
                record.setDate(Date(), forKey: CloudField.createdAt)
            }
        }
    }

    // MARK: - Membership

    func createGroup(name: String, displayName: String) async throws -> Membership {
        guard let userId = await currentUserId() else {
            throw BackendError.accountUnavailable(await availability())
        }
        let handle = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let schoolName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        // Order matters and is not interchangeable: the member record holds a
        // reference to the group, and CloudKit rejects a reference to a record
        // that does not exist yet.
        let groupRecord = CKRecord(recordType: CloudRecordType.group,
                                   recordID: CKRecord.ID(recordName: UUID().uuidString))
        groupRecord[CloudField.name] = schoolName.isEmpty ? "Schule" : schoolName
        groupRecord[CloudField.locations] = DefaultInstructions.locations
        groupRecord[CloudField.instructionsJSON] =
            CloudKitMapping.instructionsJSON(DefaultInstructions.byType)
        groupRecord.setDate(Date(), forKey: CloudField.createdAt)
        do {
            _ = try await database.save(groupRecord)
        } catch {
            throw mapped(error)
        }

        let groupID = groupRecord.recordID
        let memberName = CloudKitMapping.memberRecordName(groupId: groupID.recordName,
                                                          userId: userId)
        try await upsert(recordID: CKRecord.ID(recordName: memberName),
                         type: CloudRecordType.member) { record in
            record[CloudField.groupRef] = CKRecord.Reference(recordID: groupID, action: .none)
            record[CloudField.userId] = userId
            record[CloudField.displayName] = handle.isEmpty ? "?" : handle
            record[CloudField.role] = MemberRole.admin.rawValue
            record.setDate(Date(), forKey: CloudField.createdAt)
        }

        // Written to the store BEFORE the first invite code is made:
        // `createInviteCode` asks `requireAdmin()`, and that reads the role
        // from exactly here.
        store.groupId = groupID.recordName
        store.memberId = memberName
        store.displayName = handle
        store.role = .admin

        // A group without a code is a group nobody else can reach, so the
        // first one comes with it rather than as a step to remember.
        _ = try? await createInviteCode(note: "Kollegium")

        try await refreshSubscriptions()

        let group = CloudKitMapping.group(from: groupRecord)
        let member = Member(id: memberName, groupId: group.id, userId: userId,
                            displayName: handle, role: .admin)
        return Membership(group: group, member: member)
    }

    func joinGroup(code: String, displayName: String) async throws -> Membership {
        let normalized = InviteCode.normalize(code)
        guard !normalized.isEmpty else { throw BackendError.codeUnknown }
        guard let userId = await currentUserId() else {
            throw BackendError.accountUnavailable(await availability())
        }

        // The invite code IS the record name. No query, no index, no race: a
        // code either exists or it does not.
        let codeRecord: CKRecord
        do {
            codeRecord = try await database.record(for: CKRecord.ID(recordName: normalized))
        } catch let error as CKError where error.code == .unknownItem {
            throw BackendError.codeUnknown
        } catch {
            throw mapped(error)
        }
        guard let invite = CloudKitMapping.inviteCode(from: codeRecord) else {
            throw BackendError.codeUnknown
        }
        guard !invite.revoked else { throw BackendError.codeRevoked }

        let groupID = CKRecord.ID(recordName: invite.groupId)
        let groupRecord: CKRecord
        do {
            groupRecord = try await database.record(for: groupID)
        } catch {
            throw mapped(error)
        }
        let group = CloudKitMapping.group(from: groupRecord)

        let handle = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let memberName = CloudKitMapping.memberRecordName(groupId: group.id, userId: userId)
        // The first person to join a fresh group becomes its admin — somebody
        // has to be able to hand out codes, and a group whose only admin left
        // the school would otherwise be unmanageable.
        let existingMembers = try await members(of: groupID)
        let role: MemberRole = existingMembers.isEmpty ? .admin
            : (existingMembers.first { $0.userId == userId }?.role ?? .member)

        try await upsert(recordID: CKRecord.ID(recordName: memberName),
                         type: CloudRecordType.member) { record in
            record[CloudField.groupRef] = CKRecord.Reference(recordID: groupID, action: .none)
            record[CloudField.userId] = userId
            record[CloudField.displayName] = handle.isEmpty ? "?" : handle
            record[CloudField.role] = role.rawValue
            if record[CloudField.createdAt] == nil {
                record.setDate(Date(), forKey: CloudField.createdAt)
            }
        }

        store.groupId = group.id
        store.memberId = memberName
        store.displayName = handle
        store.role = role

        try await refreshSubscriptions()

        let member = Member(id: memberName, groupId: group.id, userId: userId,
                            displayName: handle, role: role)
        return Membership(group: group, member: member)
    }

    func fetchGroup() async throws -> AlarmGroup? {
        guard let groupId = store.groupId else { return nil }
        do {
            let record = try await database.record(for: CKRecord.ID(recordName: groupId))
            return CloudKitMapping.group(from: record)
        } catch let error as CKError where error.code == .unknownItem {
            // The group was deleted out from under this device. Better to
            // forget it than to keep pointing at a hole.
            store.clearMembership()
            return nil
        } catch {
            throw mapped(error)
        }
    }

    func fetchMembers() async throws -> [Member] {
        try await members(of: try requireGroupID())
    }

    func currentMember() async throws -> Member? {
        guard let userId = await currentUserId() else { return nil }
        return try await fetchMembers().first { $0.userId == userId }
    }

    private func members(of groupID: CKRecord.ID) async throws -> [Member] {
        let records = try await query(CloudRecordType.member,
                                      predicate: groupPredicate(groupID))
        return records.compactMap(CloudKitMapping.member(from:))
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    // MARK: - The alarm path

    func triggerAlarm(type: AlarmType, location: String?) async throws -> Alarm {
        let groupID = try requireGroupID()
        guard let userId = await currentUserId() else {
            throw BackendError.accountUnavailable(await availability())
        }
        // Two alarms of the same kind at once would double every notification
        // and split the acknowledgement list in half. A different kind is
        // allowed: a fire during an intruder alarm is not a duplicate.
        if let running = try await activeAlarm(in: groupID, userId: userId),
           running.type == type {
            throw BackendError.alarmAlreadyRunning(type)
        }

        let group = try await fetchGroup()
        let alarm = Alarm(id: UUID().uuidString,
                          groupId: groupID.recordName,
                          type: type,
                          location: location,
                          triggeredByUserId: userId,
                          triggeredByName: store.displayName ?? "?",
                          instruction: group?.instruction(for: type))

        let record = CKRecord(recordType: CloudRecordType.alarm,
                              recordID: CKRecord.ID(recordName: alarm.id))
        CloudKitMapping.apply(alarm, to: record, groupRecordID: groupID)
        do {
            _ = try await database.save(record)
        } catch {
            throw mapped(error)
        }
        store.lastLocation = location
        nudge()
        return alarm
    }

    func clearAlarm(alarmId: String) async throws {
        do {
            let record = try await database.record(for: CKRecord.ID(recordName: alarmId))
            record[CloudField.status] = AlarmStatus.cleared.rawValue
            record.setDate(Date(), forKey: CloudField.clearedAt)
            record[CloudField.clearedByName] = store.displayName ?? "?"
            _ = try await database.save(record)
        } catch {
            throw mapped(error)
        }
        nudge()
    }

    func sendAck(alarmId: String, state: AckState, location: String?) async throws {
        let groupID = try requireGroupID()
        guard let userId = await currentUserId() else {
            throw BackendError.accountUnavailable(await availability())
        }
        let name = CloudKitMapping.ackRecordName(alarmId: alarmId, userId: userId)
        try await upsert(recordID: CKRecord.ID(recordName: name),
                         type: CloudRecordType.ack) { record in
            record[CloudField.alarmRef] = CKRecord.Reference(
                recordID: CKRecord.ID(recordName: alarmId), action: .none)
            record[CloudField.groupRef] = CKRecord.Reference(recordID: groupID, action: .none)
            record[CloudField.userId] = userId
            record[CloudField.displayName] = self.store.displayName ?? "?"
            record[CloudField.state] = state.rawValue
            record[CloudField.location] = location
            record.setDate(Date(), forKey: CloudField.createdAt)
        }
        store.markAcknowledged(alarmId)
        nudge()
    }

    func sendMessage(alarmId: String, text: String) async throws {
        let groupID = try requireGroupID()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let userId = await currentUserId() else {
            throw BackendError.accountUnavailable(await availability())
        }
        let record = CKRecord(recordType: CloudRecordType.message)
        record[CloudField.alarmRef] = CKRecord.Reference(
            recordID: CKRecord.ID(recordName: alarmId), action: .none)
        record[CloudField.groupRef] = CKRecord.Reference(recordID: groupID, action: .none)
        record[CloudField.senderUserId] = userId
        record[CloudField.senderName] = store.displayName ?? "?"
        record[CloudField.text] = String(trimmed.prefix(500))
        record.setDate(Date(), forKey: CloudField.createdAt)
        do {
            _ = try await database.save(record)
        } catch {
            throw mapped(error)
        }
        nudge()
    }

    // MARK: - Streams

    func observeActiveAlarm() -> AsyncStream<Alarm?> {
        AsyncStream { continuation in
            let id = UUID()
            let known = lock.around { () -> Alarm? in
                alarmWatchers[id] = continuation
                return lastKnownAlarm
            }
            continuation.yield(known)
            continuation.onTermination = { [weak self] _ in
                self?.removeWatcher(id)
            }
            startPolling()
        }
    }

    func observeAcks(alarmId: String) -> AsyncStream<[Ack]> {
        AsyncStream { continuation in
            let id = UUID()
            lock.around { ackWatchers[id] = (alarmId, continuation) }
            continuation.onTermination = { [weak self] _ in
                self?.removeWatcher(id)
            }
            startPolling()
            nudge()
        }
    }

    func observeMessages(alarmId: String) -> AsyncStream<[Message]> {
        AsyncStream { continuation in
            let id = UUID()
            lock.around { messageWatchers[id] = (alarmId, continuation) }
            continuation.onTermination = { [weak self] _ in
                self?.removeWatcher(id)
            }
            startPolling()
            nudge()
        }
    }

    private func removeWatcher(_ id: UUID) {
        let task: Task<Void, Never>? = lock.around {
            alarmWatchers[id] = nil
            ackWatchers[id] = nil
            messageWatchers[id] = nil
            let empty = alarmWatchers.isEmpty && ackWatchers.isEmpty && messageWatchers.isEmpty
            guard empty else { return nil }
            let running = pollTask
            pollTask = nil
            return running
        }
        task?.cancel()
    }

    /// The safety net under the subscriptions.
    ///
    /// Five seconds during a running alarm — that is the chat and the
    /// acknowledgement counter, and both are read while people are standing
    /// still and waiting. Thirty seconds otherwise, which is only there to
    /// catch a push that never arrived.
    private func startPolling() {
        lock.around {
            guard pollTask == nil else { return }
            pollTask = Task { [weak self] in
                while !Task.isCancelled {
                    await self?.refreshWatchers()
                    let seconds = (self?.hasRunningAlarm ?? false) ? 5.0 : 30.0
                    try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                }
            }
        }
    }

    /// Poll right now instead of waiting out the interval. Called after every
    /// local write and on every incoming push.
    private func nudge() {
        Task { [weak self] in await self?.refreshWatchers() }
    }

    private func refreshWatchers() async {
        guard let groupID = try? requireGroupID() else { return }
        let userId = await currentUserId()

        do {
            // Only a query that SUCCEEDED and found nothing clears the alarm
            // screen. A failed one keeps the last known value: a dropped
            // connection must never look like an all-clear.
            deliverAlarm(try await activeAlarm(in: groupID, userId: userId))
        } catch {
            // Keep what we had.
        }

        // `around` instead of lock/unlock: see `Locked.swift`. Inside an
        // `async` function a bare `NSLock.lock()` is a warning today and an
        // error under Swift 6.
        let ackTargets = lock.around { Set(ackWatchers.values.map(\.alarmId)) }
        let messageTargets = lock.around { Set(messageWatchers.values.map(\.alarmId)) }

        for alarmId in ackTargets {
            guard let acks = try? await fetchAcks(alarmId: alarmId) else { continue }
            ackSinks(for: alarmId).forEach { $0.yield(acks) }
        }
        for alarmId in messageTargets {
            guard let messages = try? await fetchMessages(alarmId: alarmId) else { continue }
            messageSinks(for: alarmId).forEach { $0.yield(messages) }
        }
    }

    private func ackSinks(for alarmId: String) -> [AsyncStream<[Ack]>.Continuation] {
        lock.around { ackWatchers.values.filter { $0.alarmId == alarmId }.map(\.sink) }
    }

    private func messageSinks(for alarmId: String) -> [AsyncStream<[Message]>.Continuation] {
        lock.around { messageWatchers.values.filter { $0.alarmId == alarmId }.map(\.sink) }
    }

    private var hasRunningAlarm: Bool {
        lock.around { lastKnownAlarm?.isActive ?? false }
    }

    private func deliverAlarm(_ alarm: Alarm?) {
        let sinks: [AsyncStream<Alarm?>.Continuation] = lock.around {
            guard alarm != lastKnownAlarm else { return [] }
            lastKnownAlarm = alarm
            return Array(alarmWatchers.values)
        }
        sinks.forEach { $0.yield(alarm) }
    }

    /// The alarm currently running for this device.
    ///
    /// "For this device" matters: a self-test carries a `targetUser`, and one
    /// colleague testing delivery must not put the whole staff room on an
    /// alarm screen.
    private func activeAlarm(in groupID: CKRecord.ID, userId: String?) async throws -> Alarm? {
        let predicate = NSPredicate(format: "%K == %@ AND %K == %@",
                                    CloudField.groupRef,
                                    CKRecord.Reference(recordID: groupID, action: .none),
                                    CloudField.status, AlarmStatus.active.rawValue)
        let records = try await query(CloudRecordType.alarm,
                                      predicate: predicate,
                                      limit: 50)
        let alarms = Self.nachAlterSortiert(records)
            .compactMap(CloudKitMapping.alarm(from:))
        return alarms.first { alarm in
            guard alarm.targetUserId == nil || alarm.targetUserId == userId else {
                return false
            }
            // Abgelaufene Probealarme übergehen — sonst wird ein Stapel alter
            // Zustelltests der Reihe nach zum laufenden Alarm.
            return alarm.giltNoch()
        }
    }

    // MARK: - Checking that it works

    func sendTestAlarm(toUserId zielUserId: String) async throws {
        let groupID = try requireGroupID()
        try requireAdmin()
        guard let userId = await currentUserId() else {
            throw BackendError.accountUnavailable(await availability())
        }
        let group = try await fetchGroup()
        let alarm = Alarm(id: UUID().uuidString,
                          groupId: groupID.recordName,
                          type: .test,
                          location: store.lastLocation,
                          triggeredByUserId: userId,
                          triggeredByName: store.displayName ?? "?",
                          instruction: group?.instruction(for: .test),
                          targetUserId: zielUserId)
        let record = CKRecord(recordType: CloudRecordType.alarm,
                              recordID: CKRecord.ID(recordName: alarm.id))
        CloudKitMapping.apply(alarm, to: record, groupRecordID: groupID)
        do {
            _ = try await database.save(record)
        } catch {
            throw mapped(error)
        }
    }

    func pingAllDevices() async throws {
        let groupID = try requireGroupID()
        let record = CKRecord(recordType: CloudRecordType.ping)
        record[CloudField.groupRef] = CKRecord.Reference(recordID: groupID, action: .none)
        record[CloudField.targetUser] = CloudConstant.everyone
        record.setDate(Date(), forKey: CloudField.createdAt)
        do {
            _ = try await database.save(record)
        } catch {
            throw mapped(error)
        }
    }

    func fetchDeviceStatuses() async throws -> [DeviceStatus] {
        let groupID = try requireGroupID()
        let records = try await query(CloudRecordType.deviceStatus,
                                      predicate: groupPredicate(groupID))
        return records.compactMap(CloudKitMapping.deviceStatus(from:))
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    func refreshSubscriptions() async throws {
        let groupID = try requireGroupID()
        guard let userId = await currentUserId() else {
            throw BackendError.accountUnavailable(await availability())
        }
        await ensureSchema(groupID: groupID)
        do {
            try await CloudKitSubscriptions.reconcile(in: database,
                                                      groupRecordID: groupID,
                                                      userId: userId)
        } catch {
            throw mapped(error)
        }
    }

    /// Makes sure the record types a subscription talks about actually exist.
    ///
    /// A `CKQuerySubscription` names a record type, and CloudKit refuses one
    /// for a type it has never seen. On a fresh container that is exactly the
    /// situation right after the school is set up: `Group`, `Member` and
    /// `InviteCode` have been written, `Alarm` and `Ping` have not — the first
    /// alarm is still in the future. The subscriptions were therefore rejected,
    /// and a device without subscriptions is silent for ever without saying so.
    ///
    /// One record of each type is written and deleted again. The record goes,
    /// the type stays — that is all the schema needs.
    private func ensureSchema(groupID: CKRecord.ID) async {
        let reference = CKRecord.Reference(recordID: groupID, action: .none)

        let alarm = CKRecord(recordType: CloudRecordType.alarm)
        alarm[CloudField.groupRef] = reference
        alarm[CloudField.type] = AlarmType.test.rawValue
        // Never `active`, and addressed to nobody: should the delete below
        // fail, this must not turn into an alarm screen on 30 iPads.
        alarm[CloudField.status] = AlarmStatus.cleared.rawValue
        alarm[CloudField.targetUser] = "schema"
        alarm[CloudField.headline] = "Schema"
        alarm[CloudField.location] = "Schema"
        alarm[CloudField.triggeredByName] = "Schema"
        alarm[CloudField.triggeredByUserId] = "schema"
        alarm[CloudField.instructionShort] = "Schema"
        alarm[CloudField.instruction] = "Schema"
        alarm[CloudField.alarmId] = alarm.recordID.recordName
        alarm.setDate(Date(), forKey: CloudField.createdAt)
        alarm.setDate(Date(), forKey: CloudField.clearedAt)
        alarm[CloudField.clearedByName] = "Schema"

        let ping = CKRecord(recordType: CloudRecordType.ping)
        ping[CloudField.groupRef] = reference
        ping[CloudField.targetUser] = "schema"
        ping.setDate(Date(), forKey: CloudField.createdAt)

        let alarmRef = CKRecord.Reference(recordID: alarm.recordID, action: .none)

        let ack = CKRecord(recordType: CloudRecordType.ack)
        ack[CloudField.alarmRef] = alarmRef
        ack[CloudField.groupRef] = reference
        ack[CloudField.userId] = "schema"
        ack[CloudField.displayName] = "Schema"
        ack[CloudField.state] = AckState.secured.rawValue
        ack[CloudField.location] = "Schema"
        ack.setDate(Date(), forKey: CloudField.createdAt)

        let message = CKRecord(recordType: CloudRecordType.message)
        message[CloudField.alarmRef] = alarmRef
        message[CloudField.groupRef] = reference
        message[CloudField.senderUserId] = "schema"
        message[CloudField.senderName] = "Schema"
        message[CloudField.text] = "Schema"
        message.setDate(Date(), forKey: CloudField.createdAt)

        // Der Alarm zuerst — Ack und Message verweisen auf ihn, und eine
        // Referenz auf einen Datensatz, den es noch nicht gibt, weist
        // CloudKit ab. Gelöscht wird danach in umgekehrter Reihenfolge.
        var geschrieben: [CKRecord] = []
        for record in [alarm, ping, ack, message] {
            guard (try? await database.save(record)) != nil else { continue }
            geschrieben.append(record)
        }
        for record in geschrieben.reversed() {
            _ = try? await database.deleteRecord(withID: record.recordID)
        }
    }

    // MARK: - Administration

    func createInviteCode(note: String?) async throws -> InviteCode {
        let groupID = try requireGroupID()
        try requireAdmin()
        // Retry on collision. Six characters out of a 32-symbol alphabet is
        // about a billion codes; a school will never see a second attempt.
        for _ in 0..<5 {
            let code = InviteCode.random()
            let record = CKRecord(recordType: CloudRecordType.inviteCode,
                                  recordID: CKRecord.ID(recordName: code))
            record[CloudField.groupRef] = CKRecord.Reference(recordID: groupID, action: .none)
            record[CloudField.note] = note
            record.setBool(false, forKey: CloudField.revoked)
            record.setDate(Date(), forKey: CloudField.createdAt)
            do {
                _ = try await database.save(record)
                return InviteCode(id: code, groupId: groupID.recordName, note: note)
            } catch let error as CKError where error.code == .serverRecordChanged {
                continue
            } catch {
                throw mapped(error)
            }
        }
        throw BackendError.server("Es ließ sich kein freier Code finden.")
    }

    func revokeInviteCode(_ code: String) async throws {
        try requireAdmin()
        do {
            let record = try await database.record(
                for: CKRecord.ID(recordName: InviteCode.normalize(code)))
            record.setBool(true, forKey: CloudField.revoked)
            _ = try await database.save(record)
        } catch let error as CKError where error.code == .unknownItem {
            throw BackendError.codeUnknown
        } catch {
            throw mapped(error)
        }
    }

    func fetchInviteCodes() async throws -> [InviteCode] {
        let groupID = try requireGroupID()
        let records = try await query(CloudRecordType.inviteCode,
                                      predicate: groupPredicate(groupID))
        return records.compactMap(CloudKitMapping.inviteCode(from:))
            .sorted { $0.createdAt > $1.createdAt }
    }

    func updateLocations(_ locations: [String]) async throws {
        try requireAdmin()
        try await updateGroup { record in
            record[CloudField.locations] = locations
        }
    }

    func updateInstructions(_ instructions: [String: String]) async throws {
        try requireAdmin()
        try await updateGroup { record in
            record[CloudField.instructionsJSON] =
                CloudKitMapping.instructionsJSON(instructions)
        }
    }

    func removeMember(memberId: String) async throws {
        try requireAdmin()
        do {
            _ = try await database.deleteRecord(withID: CKRecord.ID(recordName: memberId))
        } catch let error as CKError where error.code == .unknownItem {
            return
        } catch {
            throw mapped(error)
        }
    }

    func setRole(memberId: String, role: MemberRole) async throws {
        try requireAdmin()
        do {
            let record = try await database.record(for: CKRecord.ID(recordName: memberId))
            record[CloudField.role] = role.rawValue
            _ = try await database.save(record)
        } catch let error as CKError where error.code == .unknownItem {
            throw BackendError.server("Dieses Mitglied gibt es nicht mehr.")
        } catch {
            throw mapped(error)
        }
        // Changing one's own role has to reach the local store as well, or the
        // app keeps offering buttons the server will refuse.
        if memberId == store.memberId { store.role = role }
    }

    func fetchAlarmHistory(limit: Int) async throws -> [Alarm] {
        let groupID = try requireGroupID()
        // Großzügig holen, dann selbst sortieren und kürzen: Ohne
        // serverseitige Sortierung schnitte ein knappes Limit sonst
        // irgendwelche Datensätze ab statt der ältesten.
        let records = try await query(CloudRecordType.alarm,
                                      predicate: groupPredicate(groupID),
                                      limit: max(limit, 400))
        return Array(Self.nachAlterSortiert(records)
            .compactMap(CloudKitMapping.alarm(from:))
            .prefix(limit))
    }

    func fetchAcks(alarmId: String) async throws -> [Ack] {
        let predicate = NSPredicate(format: "%K == %@", CloudField.alarmRef,
                                    CKRecord.Reference(
                                        recordID: CKRecord.ID(recordName: alarmId),
                                        action: .none))
        let records = try await query(CloudRecordType.ack, predicate: predicate)
        return records.compactMap(CloudKitMapping.ack(from:))
            .sorted { $0.createdAt < $1.createdAt }
    }

    func fetchMessages(alarmId: String) async throws -> [Message] {
        let predicate = NSPredicate(format: "%K == %@", CloudField.alarmRef,
                                    CKRecord.Reference(
                                        recordID: CKRecord.ID(recordName: alarmId),
                                        action: .none))
        let records = try await query(CloudRecordType.message, predicate: predicate)
        return records.compactMap(CloudKitMapping.message(from:))
            .sorted { $0.createdAt < $1.createdAt }
    }

    @discardableResult
    func cleanUp(olderThanDays days: Int) async throws -> CleanupReport {
        let groupID = try requireGroupID()
        let cutoff = Date().addingTimeInterval(-Double(days) * 24 * 60 * 60)

        var report = CleanupReport(alarms: 0, acks: 0, messages: 0)
        var doomed: [CKRecord.ID] = []

        // Alarms first, so that a run interrupted halfway never leaves an
        // acknowledgement pointing at an alarm that is already gone. Sorting
        // in this direction costs nothing and saves a confusing history.
        for type in [CloudRecordType.message, CloudRecordType.ack, CloudRecordType.alarm] {
            let records = try await query(type, predicate: groupPredicate(groupID),
                                          limit: 2000)
            let old = records.filter { ($0.creationDate ?? Date()) < cutoff }
            doomed += old.map(\.recordID)
            switch type {
            case CloudRecordType.message: report.messages = old.count
            case CloudRecordType.ack: report.acks = old.count
            default: report.alarms = old.count
            }
        }

        guard !doomed.isEmpty else { return report }
        // CloudKit takes at most 400 changes per request.
        for chunk in stride(from: 0, to: doomed.count, by: 300).map({
            Array(doomed[$0..<min($0 + 300, doomed.count)])
        }) {
            do {
                _ = try await database.modifyRecords(saving: [], deleting: chunk)
            } catch {
                throw mapped(error)
            }
        }
        return report
    }

    // MARK: - Diagnosis

    func diagnose() async -> [Diagnose] {
        var zeilen: [Diagnose] = []

        zeilen.append(Diagnose(id: "container",
                               titel: "Container",
                               text: container.containerIdentifier ?? "unbekannt",
                               befund: .hinweis))

        let konto = await availability()
        zeilen.append(Diagnose(id: "konto",
                               titel: "Apple-ID",
                               text: konto.explanation,
                               befund: konto.isReady ? .gut : .schlecht))

        guard let userId = await currentUserId() else {
            zeilen.append(Diagnose(id: "user", titel: "Konto-Kennung",
                                   text: "Konnte nicht ermittelt werden. Ohne sie "
                                       + "wird an dieses Gerät nichts zugestellt.",
                                   befund: .schlecht))
            return zeilen
        }
        zeilen.append(Diagnose(id: "user", titel: "Konto-Kennung",
                               text: userId, befund: .gut))

        guard let groupID = try? requireGroupID() else {
            zeilen.append(Diagnose(id: "gruppe", titel: "Gruppe",
                                   text: "Dieses Gerät gehört zu keiner Gruppe.",
                                   befund: .schlecht))
            return zeilen
        }
        zeilen.append(Diagnose(id: "gruppe", titel: "Gruppe",
                               text: groupID.recordName, befund: .gut))
        zeilen.append(Diagnose(id: "rolle", titel: "Rolle",
                               text: store.role.label, befund: .hinweis))

        // Die Probeabfragen. Sie sind der eigentliche Zweck dieser Ansicht:
        // Auf einem frischen Container fehlen die Queryable-Indizes, und
        // CloudKit sagt das im Klartext — aber nur, wenn jemand fragt.
        for (typ, name) in [(CloudRecordType.alarm, "Alarm"),
                            (CloudRecordType.ping, "Ping"),
                            (CloudRecordType.member, "Member"),
                            (CloudRecordType.deviceStatus, "DeviceStatus"),
                            (CloudRecordType.ack, "Ack"),
                            (CloudRecordType.message, "Message")] {
            do {
                try await rohAbfrage(typ, groupPredicate(groupID))
                zeilen.append(Diagnose(id: "abfrage-\(typ)",
                                       titel: "Abfrage \(name)",
                                       text: "geht", befund: .gut))
            } catch let fehler as CKError where fehler.code == .unknownItem {
                // Kein Fehler: Den Record-Typ legt CloudKit an, sobald der
                // erste Datensatz geschrieben wird. `Ack` und `Message`
                // entstehen bei der ersten Rückmeldung.
                zeilen.append(Diagnose(id: "abfrage-\(typ)",
                                       titel: "Abfrage \(name)",
                                       text: "Typ noch nicht im Schema — entsteht "
                                           + "beim ersten Datensatz dieser Art",
                                       befund: .hinweis))
            } catch {
                zeilen.append(Diagnose(id: "abfrage-\(typ)",
                                       titel: "Abfrage \(name)",
                                       text: CloudKitFehler.rohtext(error), befund: .schlecht))
            }
        }

        // Die Prädikate der Subscriptions, einzeln als Abfrage gestellt.
        //
        // Der Punkt, an dem die bisherige Diagnose vorbeisah: Die Probeabfragen
        // oben benutzen nur `groupRef`. Ein Subscription-Prädikat fragt
        // zusätzlich nach `targetUser` und `status` — fehlt DORT der
        // Queryable-Index, geht die Abfrage oben und die Subscription trotzdem
        // nicht. Hier steht dann im Klartext, welches Feld gemeint ist.
        for probe in CloudKitSubscriptions.proben(groupRecordID: groupID,
                                                  userId: userId) {
            do {
                try await rohAbfrage(probe.typ, probe.predicate)
                zeilen.append(Diagnose(id: "praedikat-\(probe.kennung)",
                                       titel: "Prädikat \(probe.kennung)",
                                       text: "abfragbar", befund: .gut))
            } catch let fehler as CKError where fehler.code == .unknownItem {
                zeilen.append(Diagnose(id: "praedikat-\(probe.kennung)",
                                       titel: "Prädikat \(probe.kennung)",
                                       text: "Record-Typ noch nicht im Schema",
                                       befund: .hinweis))
            } catch {
                zeilen.append(Diagnose(id: "praedikat-\(probe.kennung)",
                                       titel: "Prädikat \(probe.kennung)",
                                       text: CloudKitFehler.rohtext(error), befund: .schlecht))
            }
        }

        // Ohne Subscription kommt kein Push. Punkt.
        var vorhanden: Set<String> = []
        do {
            vorhanden = Set(try await database.allSubscriptions().map(\.subscriptionID))
        } catch {
            zeilen.append(Diagnose(id: "subs", titel: "Subscriptions",
                                   text: "Nicht abfragbar: \(CloudKitFehler.rohtext(error))",
                                   befund: .schlecht))
            return zeilen
        }

        // Fehlt eine, wird sie GLEICH HIER angelegt und das Ergebnis
        // hingeschrieben. Eine Diagnose, die „FEHLT" meldet und nicht sagt,
        // woran es liegt, ist die Frage von vorhin noch einmal.
        if !Set(SubscriptionID.all).isSubset(of: vorhanden) {
            do {
                await ensureSchema(groupID: groupID)
                try await CloudKitSubscriptions.reconcile(in: database,
                                                          groupRecordID: groupID,
                                                          userId: userId)
                vorhanden = Set((try? await database.allSubscriptions())?
                    .map(\.subscriptionID) ?? [])
                zeilen.append(Diagnose(id: "anlegen", titel: "Anlegen versucht",
                                       text: "ohne Fehler durchgelaufen",
                                       befund: .gut))
            } catch {
                zeilen.append(Diagnose(id: "anlegen", titel: "Anlegen gescheitert",
                                       text: CloudKitFehler.rohtext(error), befund: .schlecht))
            }
        }

        for kennung in SubscriptionID.all {
            let da = vorhanden.contains(kennung)
            zeilen.append(Diagnose(id: "sub-\(kennung)",
                                   titel: "Subscription \(kennung)",
                                   text: da ? "angelegt"
                                            : "FEHLT — ohne sie kommt kein Push an",
                                   befund: da ? .gut : .schlecht))
        }

        return zeilen
    }

    /// Eine Abfrage, die den Fehler ROH durchreicht.
    ///
    /// `query(_:predicate:)` übersetzt jeden CloudKit-Fehler in eine
    /// vorzeigbare `BackendError` — richtig für die Oberfläche, falsch für
    /// eine Diagnose: „Der Datensatz wurde nicht gefunden" ist genau das,
    /// was aus „unknown record type Ack" wurde, und damit war die Spur weg.
    private func rohAbfrage(_ typ: String, _ predicate: NSPredicate) async throws {
        let abfrage = CKQuery(recordType: typ, predicate: predicate)
        _ = try await database.records(matching: abfrage, resultsLimit: 1)
    }

    // MARK: - Push

    func handle(event: AlarmEvent) async {
        switch event {
        case .ping:
            // The app model answers a ping by writing a fresh DeviceStatus;
            // nothing to fetch here.
            break
        case .alarm, .allClear, .selfTest:
            await refreshWatchers()
        }
    }

    // MARK: - Plumbing

    private func requireGroupID() throws -> CKRecord.ID {
        guard let groupId = store.groupId else { throw BackendError.notJoined }
        return CKRecord.ID(recordName: groupId)
    }

    private func requireAdmin() throws {
        guard store.role == .admin else { throw BackendError.notPermitted }
    }

    private func groupPredicate(_ groupID: CKRecord.ID) -> NSPredicate {
        NSPredicate(format: "%K == %@", CloudField.groupRef,
                    CKRecord.Reference(recordID: groupID, action: .none))
    }

    private func updateGroup(_ mutate: @escaping (CKRecord) -> Void) async throws {
        let groupID = try requireGroupID()
        do {
            let record = try await database.record(for: groupID)
            mutate(record)
            _ = try await database.save(record)
        } catch {
            throw mapped(error)
        }
    }

    /// Fetch-or-create, then mutate, then save.
    ///
    /// `save` on a freshly built record whose id already exists fails — which
    /// is exactly what happens when somebody rejoins a group or taps
    /// "acknowledge" a second time. Both are normal, so both have to work.
    private func upsert(recordID: CKRecord.ID,
                        type: String,
                        mutate: @escaping (CKRecord) -> Void) async throws {
        do {
            let record: CKRecord
            do {
                record = try await database.record(for: recordID)
            } catch let error as CKError where error.code == .unknownItem {
                record = CKRecord(recordType: type, recordID: recordID)
            }
            mutate(record)
            _ = try await database.save(record)
        } catch {
            throw mapped(error)
        }
    }

    /// Neueste zuerst — im App, nicht auf dem Server.
    ///
    /// **Warum nicht der Server sortiert:** Ein `NSSortDescriptor` auf
    /// `creationDate` verlangt in der CloudKit-Konsole einen SORTABLE-Index
    /// auf `___createTime`. Fehlt der, lehnt CloudKit die Abfrage ab — und
    /// getroffen hätte es ausgerechnet `activeAlarm`, also das Auslösen eines
    /// Alarms und das Nachfassen (gemeldet 09/2026: „Field '___createTime' is
    /// not marked sortable"). Die wichtigste Abfrage dieser App darf nicht an
    /// einem Häkchen in einer Web-Oberfläche hängen.
    ///
    /// Sortiert wird weiterhin nach dem **Systemzeitstempel** und nicht nach
    /// dem eigenen `createdAt`-Feld: Den setzt der Server, ein Gerät mit
    /// falscher Uhr kann ihn nicht verbiegen. Nur das Sortieren selbst
    /// passiert hier — bei einer Handvoll Alarmen einer Schule kostet das
    /// nichts.
    private static func nachAlterSortiert(_ records: [CKRecord]) -> [CKRecord] {
        records.sorted {
            ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast)
        }
    }

    /// A query with paging.
    ///
    /// CloudKit hands back one page and a cursor; forgetting the cursor is the
    /// classic way to build a device list that stops at 100 entries and never
    /// says so.
    /// Ohne `sortDescriptors` — mit Absicht. Sortiert wird in der App
    /// (`nachAlterSortiert`), damit keine Abfrage an einem SORTABLE-Index in
    /// der CloudKit-Konsole hängt. Wer hier wieder einen Sortierer einbaut,
    /// baut die Falle wieder ein.
    private func query(_ recordType: String,
                       predicate: NSPredicate,
                       limit: Int = 400) async throws -> [CKRecord] {
        let query = CKQuery(recordType: recordType, predicate: predicate)

        var collected: [CKRecord] = []
        do {
            var page = try await database.records(matching: query, resultsLimit: limit)
            while true {
                collected += page.matchResults.compactMap { try? $0.1.get() }
                guard collected.count < limit, let cursor = page.queryCursor else { break }
                page = try await database.records(continuingMatchFrom: cursor,
                                                  resultsLimit: limit - collected.count)
            }
        } catch {
            throw mapped(error)
        }
        return Array(collected.prefix(limit))
    }

    /// Turns a CloudKit failure into something that can be shown to a teacher.
    private func mapped(_ error: Error) -> BackendError {
        guard let ck = error as? CKError else {
            return .server(error.localizedDescription)
        }
        switch ck.code {
        case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited:
            return .network(ck.localizedDescription)
        case .notAuthenticated:
            return .accountUnavailable(.noAccount)
        case .permissionFailure:
            return .notPermitted
        case .unknownItem:
            return .server("Der Datensatz wurde nicht gefunden.")
        case .quotaExceeded:
            return .server("Das iCloud-Kontingent ist erschöpft.")
        default:
            return .server(ck.localizedDescription)
        }
    }
}

/// What this device is, in two strings.
enum DeviceFacts {
    static var model: String {
        UIDevice.current.model + " (" + UIDevice.current.systemName + " "
            + UIDevice.current.systemVersion + ")"
    }

    static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let marketing = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(marketing) (\(build))"
    }
}
