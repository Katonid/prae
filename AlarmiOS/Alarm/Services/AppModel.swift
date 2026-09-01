//  AppModel.swift
//  One object the whole interface reads from.
//
//  It holds an `any AlarmBackend` and never anything more specific. That is
//  the rule that keeps the backend swap in `docs/BACKEND_MIGRATION.md` a
//  matter of writing one file rather than rewriting the app: every screen in
//  `Views/` talks to this model, this model talks to the protocol, and the
//  protocol knows nothing about CloudKit.

import Foundation
import SwiftUI
import UIKit

@MainActor
final class AppModel: ObservableObject {

    // MARK: Published state

    @Published private(set) var group: AlarmGroup?
    @Published private(set) var member: Member?
    @Published private(set) var activeAlarm: Alarm?
    @Published private(set) var acks: [Ack] = []
    @Published private(set) var messages: [Message] = []
    @Published private(set) var deviceStatuses: [DeviceStatus] = []
    @Published private(set) var availability: BackendAvailability = .ready
    @Published private(set) var checklist: [ChecklistItem] = []
    @Published private(set) var isWorking = false

    /// The last thing that went wrong, in words a teacher can act on. Shown as
    /// a banner and cleared by hand — an error that fades out after four
    /// seconds is an error nobody read.
    @Published var problem: String?

    /// Whether the alarm screen is on top of everything.
    @Published var showsAlarmScreen = false

    /// Set once the whole checklist is green and a self-test has arrived.
    @Published private(set) var onboardingDone = false

    let backend: any AlarmBackend
    let notifications: NotificationCenterService
    let store: MembershipStore
    let managedConfiguration: ManagedAppConfiguration

    private var alarmTask: Task<Void, Never>?
    private var ackTask: Task<Void, Never>?
    private var messageTask: Task<Void, Never>?
    /// The alarm the reminder series currently belongs to.
    private var remindingAbout: String?

    var isJoined: Bool { store.groupId != nil }
    var isAdmin: Bool { member?.role == .admin || store.role == .admin }
    var displayName: String { store.displayName ?? "" }

    var criticalAlertsBuilt: Bool {
        #if CRITICAL_ALERTS
        true
        #else
        false
        #endif
    }

    init(backend: any AlarmBackend,
         notifications: NotificationCenterService = NotificationCenterService(),
         store: MembershipStore = MembershipStore(),
         managedConfiguration: ManagedAppConfiguration = .current()) {
        self.backend = backend
        self.notifications = notifications
        self.store = store
        self.managedConfiguration = managedConfiguration
        self.onboardingDone = store.onboardingDone
    }

    // MARK: - Lifecycle

    /// Everything that has to happen at every start, in the order that matters.
    func start() async {
        notifications.registerCategories()
        await notifications.refreshPermissions()
        availability = await backend.availability()

        guard isJoined else {
            await rebuildChecklist()
            return
        }

        group = try? await backend.fetchGroup()
        member = try? await backend.currentMember()
        if let member { store.role = member.role }

        // Subscriptions can go missing — an account switch, a container reset,
        // a restore from a backup. A device without them is deaf and does not
        // know it, so they are checked at every launch rather than once.
        do { try await backend.refreshSubscriptions() }
        catch { report(error) }

        await reportDeviceStatus()
        observeAlarm()
        await rebuildChecklist()

        // Admins tidy up on the way in, so that nobody has to remember to.
        if isAdmin {
            Task { try? await self.backend.cleanUp(olderThanDays: 90) }
        }
    }

    /// Called on every return to the foreground.
    func refresh() async {
        await notifications.refreshPermissions()
        availability = await backend.availability()
        if isJoined {
            group = try? await backend.fetchGroup()
            await reportDeviceStatus()
        }
        await rebuildChecklist()
    }

    // MARK: - Joining

    func join(code: String, displayName: String) async -> Bool {
        isWorking = true
        defer { isWorking = false }
        do {
            let membership = try await backend.joinGroup(code: code, displayName: displayName)
            group = membership.group
            member = membership.member
            await reportDeviceStatus()
            observeAlarm()
            await rebuildChecklist()
            return true
        } catch {
            report(error)
            return false
        }
    }

    /// The MDM path: a code was delivered with the app, so only the handle is
    /// still missing.
    var suggestedCode: String? { managedConfiguration.groupInviteCode }
    var suggestedName: String? { managedConfiguration.displayNameHint }

    // MARK: - Raising and clearing

    func trigger(type: AlarmType, location: String?) async -> Alarm? {
        isWorking = true
        defer { isWorking = false }
        do {
            let alarm = try await backend.triggerAlarm(type: type, location: location)
            activeAlarm = alarm
            showsAlarmScreen = true
            return alarm
        } catch {
            report(error)
            return nil
        }
    }

    /// Who may call the all-clear: an admin, or whoever raised this alarm.
    ///
    /// The second half matters. The person at the scene knows first that it is
    /// over, and making them wait for the head teacher's iPad would keep 30
    /// classrooms locked down for no reason.
    func mayClear(_ alarm: Alarm) -> Bool {
        if isAdmin { return true }
        return alarm.triggeredByUserId == member?.userId
    }

    func clear(_ alarm: Alarm) async {
        do {
            try await backend.clearAlarm(alarmId: alarm.id)
            await AlarmReminder.cancel(alarmId: alarm.id)
        } catch {
            report(error)
        }
    }

    func acknowledge(_ alarm: Alarm, state: AckState, location: String?) async {
        store.markAcknowledged(alarm.id)
        await AlarmReminder.cancel(alarmId: alarm.id)
        do {
            try await backend.sendAck(alarmId: alarm.id, state: state, location: location)
        } catch {
            report(error)
        }
    }

    func hasAcknowledged(_ alarm: Alarm) -> Bool {
        store.hasAcknowledged(alarm.id)
    }

    func send(message text: String, for alarm: Alarm) async {
        do {
            try await backend.sendMessage(alarmId: alarm.id, text: text)
        } catch {
            report(error)
        }
    }

    // MARK: - Streams

    private func observeAlarm() {
        alarmTask?.cancel()
        alarmTask = Task { [weak self] in
            guard let self else { return }
            for await alarm in self.backend.observeActiveAlarm() {
                await self.apply(alarm: alarm)
            }
        }
    }

    private func apply(alarm: Alarm?) async {
        let previous = activeAlarm
        activeAlarm = alarm

        guard let alarm, alarm.isActive else {
            observeDetails(for: nil)
            await AlarmReminder.cancelAll()
            remindingAbout = nil
            // The all-clear closes the screen — but only for an alarm that was
            // actually showing. Closing something that was never open would
            // yank the interface out from under whoever is using it.
            if previous != nil { showsAlarmScreen = false }
            return
        }

        showsAlarmScreen = true
        observeDetails(for: alarm)

        // Start nagging only once per alarm, and only while it is unanswered.
        if !store.hasAcknowledged(alarm.id), remindingAbout != alarm.id {
            remindingAbout = alarm.id
            await AlarmReminder.schedule(for: alarm)
        }
    }

    private func observeDetails(for alarm: Alarm?) {
        ackTask?.cancel()
        messageTask?.cancel()
        guard let alarm else {
            acks = []
            messages = []
            return
        }
        ackTask = Task { [weak self] in
            guard let self else { return }
            for await list in self.backend.observeAcks(alarmId: alarm.id) {
                await MainActor.run { self.acks = list }
            }
        }
        messageTask = Task { [weak self] in
            guard let self else { return }
            for await list in self.backend.observeMessages(alarmId: alarm.id) {
                await MainActor.run { self.messages = list }
            }
        }
    }

    // MARK: - Push

    /// A push landed. The event may already be on screen (the poll got there
    /// first) — everything here is written to survive that.
    func handle(event: AlarmEvent) async {
        await backend.handle(event: event)

        switch event {
        case .ping:
            await reportDeviceStatus()
        case .selfTest:
            // The self-test counts as passed the moment it ARRIVES, not when
            // it was requested. That distinction is the whole point of the
            // exercise: it proves the delivery path, not the send path.
            store.selfTestPassed = true
            await rebuildChecklist()
        case .alarm, .allClear:
            break
        }

        if let payload = event.alarmPayload, !event.isSilent {
            // Show what the push carried immediately, without waiting for a
            // round trip. On a locked iPad in a corridor there may not BE a
            // round trip.
            if case .alarm = event {
                showsAlarmScreen = true
                if activeAlarm?.id != payload.alarmId {
                    activeAlarm = Alarm(id: payload.alarmId,
                                        groupId: payload.groupId ?? store.groupId ?? "",
                                        type: payload.type,
                                        location: payload.location,
                                        triggeredByUserId: "",
                                        triggeredByName: payload.triggeredByName ?? "?",
                                        createdAt: payload.createdAt ?? Date(),
                                        instruction: payload.instruction)
                    observeDetails(for: activeAlarm)
                }
                if !store.hasAcknowledged(payload.alarmId),
                   remindingAbout != payload.alarmId,
                   let alarm = activeAlarm {
                    remindingAbout = payload.alarmId
                    await AlarmReminder.schedule(for: alarm)
                }
            }
        }
    }

    /// An acknowledgement chosen from the notification itself.
    func handlePendingAck() async {
        guard let pending = notifications.pendingAck else { return }
        notifications.pendingAck = nil
        store.markAcknowledged(pending.alarmId)
        await AlarmReminder.cancel(alarmId: pending.alarmId)
        do {
            try await backend.sendAck(alarmId: pending.alarmId,
                                      state: pending.state,
                                      location: store.lastLocation)
        } catch {
            report(error)
        }
    }

    // MARK: - Checks

    func requestPermissions() async {
        await notifications.requestAuthorization()
        await rebuildChecklist()
        await reportDeviceStatus()
    }

    func runSelfTest() async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await backend.requestSelfTest()
        } catch {
            report(error)
        }
    }

    func confirmSelfTest() {
        store.selfTestPassed = true
        Task { await rebuildChecklist() }
    }

    func finishOnboarding() {
        store.onboardingDone = true
        onboardingDone = true
    }

    func rebuildChecklist() async {
        checklist = OnboardingChecklist.items(permissions: notifications.permissions,
                                              availability: availability,
                                              selfTestPassed: store.selfTestPassed,
                                              criticalAlertsBuilt: criticalAlertsBuilt)
        onboardingDone = store.onboardingDone && checklist.allSatisfy { !$0.isBlocking }
    }

    var blockingItems: [ChecklistItem] { checklist.filter(\.isBlocking) }

    // MARK: - Devices

    func reportDeviceStatus() async {
        guard isJoined else { return }
        let permissions = notifications.permissions
        let draft = DeviceStatusDraft(
            deviceModel: DeviceFacts.model,
            appVersion: DeviceFacts.appVersion,
            notificationsAuthorized: permissions.authorization == .authorized,
            timeSensitiveAllowed: permissions.timeSensitiveAllowed,
            criticalAllowed: permissions.criticalAllowed,
            iCloudAvailable: availability.isReady)
        try? await backend.registerDevice(draft)
    }

    func loadDeviceStatuses() async {
        do { deviceStatuses = try await backend.fetchDeviceStatuses() }
        catch { report(error) }
    }

    func pingAll() async {
        do { try await backend.pingAllDevices() }
        catch { report(error) }
    }

    // MARK: - Problems

    func report(_ error: Error) {
        problem = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
