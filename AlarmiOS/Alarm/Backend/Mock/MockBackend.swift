//  MockBackend.swift
//  A backend that lives entirely in memory.
//
//  Two jobs. It drives SwiftUI previews — an alarm screen you cannot look at
//  without a school, an iCloud account and a colleague willing to press the
//  button is an alarm screen nobody polishes. And it is the second
//  implementation of `AlarmBackend`, which is the only proof that the protocol
//  really is free of CloudKit: if a signature had leaked a `CKRecord`, this
//  file would not compile.

import Foundation

final class MockBackend: AlarmBackend {

    private let lock = NSLock()
    private var group: AlarmGroup
    private var members: [Member]
    private var alarms: [Alarm] = []
    private var acks: [Ack] = []
    private var messages: [Message] = []
    private var devices: [DeviceStatus] = []
    private var codes: [InviteCode] = []

    private var alarmWatchers: [UUID: AsyncStream<Alarm?>.Continuation] = [:]
    private var ackWatchers: [UUID: (alarmId: String, sink: AsyncStream<[Ack]>.Continuation)] = [:]
    private var messageWatchers: [UUID: (alarmId: String,
                                         sink: AsyncStream<[Message]>.Continuation)] = [:]

    let userId = "_mock-user"
    var role: MemberRole = .admin
    /// Set by previews that want to show the failure paths.
    var forcedAvailability: BackendAvailability = .ready

    init(withRunningAlarm running: Bool = false) {
        group = AlarmGroup(id: "group-mock",
                           name: "Grundschule Musterstadt",
                           locations: DefaultInstructions.locations,
                           instructions: DefaultInstructions.byType)
        members = [
            Member(id: "m1", groupId: "group-mock", userId: "_mock-user",
                   displayName: "MÜ", role: .admin),
            Member(id: "m2", groupId: "group-mock", userId: "_u2", displayName: "KL"),
            Member(id: "m3", groupId: "group-mock", userId: "_u3", displayName: "BR")
        ]
        devices = members.map { member in
            DeviceStatus(id: "d-\(member.id)", groupId: group.id, userId: member.userId,
                         displayName: member.displayName,
                         deviceId: "mock-\(member.id)",
                         deviceModel: "iPad (iOS 17.5)", appVersion: "1.0.0 (1)",
                         notificationsAuthorized: true, timeSensitiveAllowed: true,
                         criticalAllowed: false, iCloudAvailable: true,
                         lastSeen: member.displayName == "BR"
                             ? Date().addingTimeInterval(-72 * 3600) : Date())
        }
        codes = [InviteCode(id: "K7QX2M", groupId: group.id, note: "Kollegium 2026")]
        if running {
            let alarm = Alarm(id: "alarm-mock", groupId: group.id, type: .amok,
                              location: "Aula", triggeredByUserId: "_u2",
                              triggeredByName: "KL",
                              createdAt: Date().addingTimeInterval(-45),
                              instruction: DefaultInstructions.byType[AlarmType.amok.rawValue])
            alarms = [alarm]
            acks = [Ack(id: "a1", alarmId: alarm.id, groupId: group.id, userId: "_u3",
                        displayName: "BR", state: .secured, location: "Raum 12"),
                    Ack(id: "a2", alarmId: alarm.id, groupId: group.id, userId: "_u2",
                        displayName: "KL", state: .needsHelp, location: "Aula")]
            messages = [Message(id: "msg1", alarmId: alarm.id, groupId: group.id,
                                senderUserId: "_u2", senderName: "KL",
                                text: "Aula ist geräumt.")]
        }
    }

    // MARK: - Account

    func currentUserId() async -> String? { userId }
    func availability() async -> BackendAvailability { forcedAvailability }
    func registerDevice(_ draft: DeviceStatusDraft) async throws {}

    // MARK: - Membership

    func createGroup(name: String, displayName: String) async throws -> Membership {
        lock.around {
            group = AlarmGroup(id: "group-mock",
                               name: name.isEmpty ? "Schule" : name,
                               locations: DefaultInstructions.locations,
                               instructions: DefaultInstructions.byType)
        }
        role = .admin
        let member = Member(id: "m1", groupId: group.id, userId: userId,
                            displayName: displayName, role: .admin)
        lock.around { members = [member] }
        return Membership(group: group, member: member)
    }

    func joinGroup(code: String, displayName: String) async throws -> Membership {
        guard InviteCode.normalize(code) == "K7QX2M" else { throw BackendError.codeUnknown }
        // Wer beitritt, wird Mitglied — wie in der Wirklichkeit.
        let member = Member(id: "m1", groupId: group.id, userId: userId,
                            displayName: displayName, role: .member)
        return Membership(group: group, member: member)
    }

    func fetchGroup() async throws -> AlarmGroup? { group }
    func fetchMembers() async throws -> [Member] { members }
    func currentMember() async throws -> Member? { members.first { $0.userId == userId } }

    // MARK: - Alarms

    func triggerAlarm(type: AlarmType, location: String?) async throws -> Alarm {
        if let running = activeAlarm(), running.type == type {
            throw BackendError.alarmAlreadyRunning(type)
        }
        let alarm = Alarm(id: UUID().uuidString, groupId: group.id, type: type,
                          location: location, triggeredByUserId: userId,
                          triggeredByName: "MÜ",
                          instruction: group.instruction(for: type))
        lock.around { alarms.insert(alarm, at: 0) }
        publishAlarm()
        return alarm
    }

    func clearAlarm(alarmId: String) async throws {
        lock.around {
            guard let index = alarms.firstIndex(where: { $0.id == alarmId }) else { return }
            alarms[index].status = .cleared
            alarms[index].clearedAt = Date()
            alarms[index].clearedByName = "MÜ"
        }
        publishAlarm()
    }

    func sendAck(alarmId: String, state: AckState, location: String?) async throws {
        let (snapshot, sinks) = lock.around { () -> ([Ack], [AsyncStream<[Ack]>.Continuation]) in
            acks.removeAll { $0.alarmId == alarmId && $0.userId == userId }
            acks.append(Ack(id: UUID().uuidString, alarmId: alarmId, groupId: group.id,
                            userId: userId, displayName: "MÜ",
                            state: state, location: location))
            return (acks.filter { $0.alarmId == alarmId },
                    ackWatchers.values.filter { $0.alarmId == alarmId }.map(\.sink))
        }
        sinks.forEach { $0.yield(snapshot) }
    }

    func sendMessage(alarmId: String, text: String) async throws {
        let (snapshot, sinks) = lock.around {
            () -> ([Message], [AsyncStream<[Message]>.Continuation]) in
            messages.append(Message(id: UUID().uuidString, alarmId: alarmId,
                                    groupId: group.id, senderUserId: userId,
                                    senderName: "MÜ", text: text))
            return (messages.filter { $0.alarmId == alarmId },
                    messageWatchers.values.filter { $0.alarmId == alarmId }.map(\.sink))
        }
        sinks.forEach { $0.yield(snapshot) }
    }

    func observeActiveAlarm() -> AsyncStream<Alarm?> {
        AsyncStream { continuation in
            let id = UUID()
            lock.around { alarmWatchers[id] = continuation }
            continuation.yield(activeAlarm())
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                self.lock.around { self.alarmWatchers[id] = nil }
            }
        }
    }

    func observeAcks(alarmId: String) -> AsyncStream<[Ack]> {
        AsyncStream { continuation in
            let id = UUID()
            let snapshot = lock.around { () -> [Ack] in
                ackWatchers[id] = (alarmId, continuation)
                return acks.filter { $0.alarmId == alarmId }
            }
            continuation.yield(snapshot)
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                self.lock.around { self.ackWatchers[id] = nil }
            }
        }
    }

    func observeMessages(alarmId: String) -> AsyncStream<[Message]> {
        AsyncStream { continuation in
            let id = UUID()
            let snapshot = lock.around { () -> [Message] in
                messageWatchers[id] = (alarmId, continuation)
                return messages.filter { $0.alarmId == alarmId }
            }
            continuation.yield(snapshot)
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                self.lock.around { self.messageWatchers[id] = nil }
            }
        }
    }

    // MARK: - Checks and administration

    func sendTestAlarm(toUserId zielUserId: String) async throws {
        let alarm = Alarm(id: UUID().uuidString, groupId: group.id, type: .test,
                          triggeredByUserId: userId, triggeredByName: "MÜ",
                          instruction: group.instruction(for: .test),
                          targetUserId: zielUserId)
        lock.around { alarms.insert(alarm, at: 0) }
        publishAlarm()
    }

    func pingAllDevices() async throws {
        lock.around {
            devices = devices.map { var copy = $0; copy.lastSeen = Date(); return copy }
        }
    }

    func fetchDeviceStatuses() async throws -> [DeviceStatus] { devices }

    func diagnose() async -> [Diagnose] {
        [Diagnose(id: "mock", titel: "Testdaten",
                  text: "Diese Fassung spricht mit keiner Gegenstelle.",
                  befund: .hinweis)]
    }
    func refreshSubscriptions() async throws {}

    func createInviteCode(note: String?) async throws -> InviteCode {
        let code = InviteCode(id: InviteCode.random(), groupId: group.id, note: note)
        lock.around { codes.append(code) }
        return code
    }

    func revokeInviteCode(_ code: String) async throws {
        lock.around {
            guard let index = codes.firstIndex(where: { $0.id == code }) else { return }
            codes[index].revoked = true
        }
    }

    func fetchInviteCodes() async throws -> [InviteCode] { codes }

    func updateLocations(_ locations: [String]) async throws { group.locations = locations }

    func updateInstructions(_ instructions: [String: String]) async throws {
        group.instructions = instructions
    }

    func removeMember(memberId: String) async throws {
        lock.around { members.removeAll { $0.id == memberId } }
    }

    func setRole(memberId: String, role newRole: MemberRole) async throws {
        lock.around {
            guard let index = members.firstIndex(where: { $0.id == memberId }) else { return }
            members[index].role = newRole
        }
    }

    func fetchAlarmHistory(limit: Int) async throws -> [Alarm] { Array(alarms.prefix(limit)) }
    func fetchAcks(alarmId: String) async throws -> [Ack] { acks.filter { $0.alarmId == alarmId } }

    func fetchMessages(alarmId: String) async throws -> [Message] {
        messages.filter { $0.alarmId == alarmId }
    }

    @discardableResult
    func cleanUp(olderThanDays days: Int) async throws -> CleanupReport {
        CleanupReport(alarms: 0, acks: 0, messages: 0)
    }

    func handle(event: AlarmEvent) async {}

    // MARK: - Helpers

    private func activeAlarm() -> Alarm? {
        lock.around {
            alarms.first {
                $0.isActive && ($0.targetUserId == nil || $0.targetUserId == userId)
                    && $0.giltNoch()
            }
        }
    }

    private func publishAlarm() {
        let alarm = activeAlarm()
        lock.around { Array(alarmWatchers.values) }.forEach { $0.yield(alarm) }
    }
}
