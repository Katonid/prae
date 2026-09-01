//  PreviewModels.swift
//  Ready-made app models for SwiftUI previews.
//
//  Previews are built in Debug, so everything here is compiled by CI as well.
//  That is a feature: if the mock backend ever stops satisfying the protocol,
//  the build says so instead of a preview quietly going blank.
//
//  `PreviewProvider` rather than the `#Preview` macro on purpose — the macro's
//  generated type is only available from iOS 17, and this app builds for 16.

import SwiftUI

@MainActor
enum PreviewModels {

    /// A device that has joined and finished its onboarding.
    static func joined(runningAlarm: Bool = false) -> AppModel {
        let defaults = scratchDefaults()
        let store = MembershipStore(defaults: defaults)
        store.groupId = "group-mock"
        store.memberId = "m1"
        store.displayName = "MÜ"
        store.role = .admin
        store.onboardingDone = true
        store.selfTestPassed = true
        store.lastLocation = "Aula"
        return AppModel(backend: MockBackend(withRunningAlarm: runningAlarm),
                        store: store,
                        managedConfiguration: ManagedAppConfiguration())
    }

    /// A device straight out of the box.
    static func fresh() -> AppModel {
        AppModel(backend: MockBackend(),
                 store: MembershipStore(defaults: scratchDefaults()),
                 managedConfiguration: ManagedAppConfiguration())
    }

    static let sampleAlarm = Alarm(id: "alarm-mock",
                                   groupId: "group-mock",
                                   type: .amok,
                                   location: "Aula",
                                   triggeredByUserId: "_u2",
                                   triggeredByName: "KL",
                                   createdAt: Date().addingTimeInterval(-70),
                                   instruction: DefaultInstructions
                                       .byType[AlarmType.amok.rawValue])

    /// A throwaway defaults suite, so a preview never writes into the real one.
    private static func scratchDefaults() -> UserDefaults {
        UserDefaults(suiteName: "preview-\(UUID().uuidString)") ?? .standard
    }
}
