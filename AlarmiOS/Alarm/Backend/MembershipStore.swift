//  MembershipStore.swift
//  What this device remembers between launches.
//
//  Backend-neutral on purpose: which group a device joined and under which
//  handle is a fact about the device, not about CloudKit. A second backend
//  reuses this file unchanged.

import Foundation

/// The small, boring state that has to survive a restart.
///
/// `UserDefaults` and not the Keychain: none of this is a secret. The invite
/// code is read aloud in a staff meeting, and the handle is printed on a name
/// badge. Putting it in the Keychain would suggest a protection that is not
/// there.
final class MembershipStore {

    private enum Key {
        static let groupId = "alarm.groupId"
        static let memberId = "alarm.memberId"
        static let displayName = "alarm.displayName"
        static let role = "alarm.role"
        static let lastLocation = "alarm.lastLocation"
        static let onboardingDone = "alarm.onboardingDone"
        static let selfTestPassed = "alarm.selfTestPassed"
        static let acknowledgedAlarmIds = "alarm.acknowledgedAlarmIds"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var groupId: String? {
        get { defaults.string(forKey: Key.groupId) }
        set { defaults.set(newValue, forKey: Key.groupId) }
    }

    var memberId: String? {
        get { defaults.string(forKey: Key.memberId) }
        set { defaults.set(newValue, forKey: Key.memberId) }
    }

    var displayName: String? {
        get { defaults.string(forKey: Key.displayName) }
        set { defaults.set(newValue, forKey: Key.displayName) }
    }

    var role: MemberRole {
        get {
            defaults.string(forKey: Key.role).flatMap(MemberRole.init(rawValue:)) ?? .member
        }
        set { defaults.set(newValue.rawValue, forKey: Key.role) }
    }

    /// The location chosen last time, pre-selected next time. In an emergency
    /// the second tap is the expensive one.
    var lastLocation: String? {
        get { defaults.string(forKey: Key.lastLocation) }
        set { defaults.set(newValue, forKey: Key.lastLocation) }
    }

    var onboardingDone: Bool {
        get { defaults.bool(forKey: Key.onboardingDone) }
        set { defaults.set(newValue, forKey: Key.onboardingDone) }
    }

    /// Onboarding counts as finished only after a test alarm actually arrived.
    /// A checklist of green ticks proves nothing; a delivered notification
    /// does.
    var selfTestPassed: Bool {
        get { defaults.bool(forKey: Key.selfTestPassed) }
        set { defaults.set(newValue, forKey: Key.selfTestPassed) }
    }

    /// Alarms this device has already answered — the local reminder loop stops
    /// at that point, even if the server round trip is still in flight.
    var acknowledgedAlarmIds: [String] {
        get { defaults.stringArray(forKey: Key.acknowledgedAlarmIds) ?? [] }
        set { defaults.set(Array(newValue.suffix(50)), forKey: Key.acknowledgedAlarmIds) }
    }

    func markAcknowledged(_ alarmId: String) {
        guard !acknowledgedAlarmIds.contains(alarmId) else { return }
        acknowledgedAlarmIds = acknowledgedAlarmIds + [alarmId]
    }

    func hasAcknowledged(_ alarmId: String) -> Bool {
        acknowledgedAlarmIds.contains(alarmId)
    }

    func clearMembership() {
        groupId = nil
        memberId = nil
        role = .member
        onboardingDone = false
        selfTestPassed = false
    }
}
