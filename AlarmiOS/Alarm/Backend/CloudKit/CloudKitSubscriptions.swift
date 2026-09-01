//  CloudKitSubscriptions.swift
//  Without these four subscriptions the app is a silent icon on a home screen.
//
//  There is no server in this design. Nobody sends a push; CloudKit sends it,
//  because a device asked to be told when a record appears. That request is a
//  `CKQuerySubscription`, and it lives in the public database under the
//  signed-in account.
//
//  Two things follow from that, and both are load-bearing:
//
//  * No iCloud account, no subscription, no alarm. Not a degraded alarm — none
//    at all. This is why the onboarding checklist refuses to finish without a
//    delivered self-test.
//  * A subscription's predicate cannot be edited afterwards. Changing one
//    means a new identifier and deleting the old one, which is what the
//    version suffix in `SubscriptionID` is for.

import CloudKit
import Foundation

enum CloudKitSubscriptions {

    /// Creates whatever is missing, removes what belongs to an older version,
    /// and leaves everything else alone.
    ///
    /// Deliberately not "delete all, then create all": that would be simpler
    /// to write and would leave the device deaf for the seconds in between —
    /// and permanently deaf if the create half fails on a bad connection.
    static func reconcile(in database: CKDatabase,
                          groupRecordID: CKRecord.ID,
                          userId: String) async throws {
        let existing = try await database.allSubscriptions()
        let known = Set(existing.map(\.subscriptionID))

        let wanted = [
            alarmCreated(groupRecordID: groupRecordID),
            alarmCleared(groupRecordID: groupRecordID),
            selfTest(groupRecordID: groupRecordID, userId: userId),
            pingCreated(groupRecordID: groupRecordID, userId: userId)
        ]

        // Subscriptions of a previous app version, whose predicate no longer
        // matches what we send. Left in place they would deliver duplicates.
        let obsolete = known.subtracting(SubscriptionID.all)
            .filter { $0.hasPrefix("alarm-") || $0.hasPrefix("ping-") || $0.hasPrefix("selftest-") }

        let missing = wanted.filter { !known.contains($0.subscriptionID) }
        guard !missing.isEmpty || !obsolete.isEmpty else { return }

        _ = try await database.modifySubscriptions(saving: missing,
                                                   deleting: Array(obsolete))
    }

    /// A real alarm, for everybody in the group.
    static func alarmCreated(groupRecordID: CKRecord.ID) -> CKQuerySubscription {
        let predicate = NSPredicate(format: "%K == %@ AND %K == %@",
                                    CloudField.groupRef,
                                    CKRecord.Reference(recordID: groupRecordID, action: .none),
                                    CloudField.targetUser,
                                    CloudConstant.everyone)
        let subscription = CKQuerySubscription(recordType: CloudRecordType.alarm,
                                               predicate: predicate,
                                               subscriptionID: SubscriptionID.alarmCreated,
                                               options: [.firesOnRecordCreation])
        subscription.notificationInfo = alarmNotificationInfo()
        return subscription
    }

    /// The same record, updated to `cleared`.
    static func alarmCleared(groupRecordID: CKRecord.ID) -> CKQuerySubscription {
        let predicate = NSPredicate(format: "%K == %@ AND %K == %@ AND %K == %@",
                                    CloudField.groupRef,
                                    CKRecord.Reference(recordID: groupRecordID, action: .none),
                                    CloudField.targetUser,
                                    CloudConstant.everyone,
                                    CloudField.status,
                                    AlarmStatus.cleared.rawValue)
        let subscription = CKQuerySubscription(recordType: CloudRecordType.alarm,
                                               predicate: predicate,
                                               subscriptionID: SubscriptionID.alarmCleared,
                                               options: [.firesOnRecordUpdate])
        subscription.notificationInfo = allClearNotificationInfo()
        return subscription
    }

    /// A test alarm addressed to this device only, so that one person can
    /// check delivery without waking a staff room.
    static func selfTest(groupRecordID: CKRecord.ID, userId: String) -> CKQuerySubscription {
        let predicate = NSPredicate(format: "%K == %@ AND %K == %@",
                                    CloudField.groupRef,
                                    CKRecord.Reference(recordID: groupRecordID, action: .none),
                                    CloudField.targetUser,
                                    userId)
        let subscription = CKQuerySubscription(recordType: CloudRecordType.alarm,
                                               predicate: predicate,
                                               subscriptionID: SubscriptionID.selfTest,
                                               options: [.firesOnRecordCreation])
        subscription.notificationInfo = alarmNotificationInfo()
        return subscription
    }

    /// "Report your status." The only silent push this app has.
    static func pingCreated(groupRecordID: CKRecord.ID, userId: String) -> CKQuerySubscription {
        let predicate = NSPredicate(format: "%K == %@ AND (%K == %@ OR %K == %@)",
                                    CloudField.groupRef,
                                    CKRecord.Reference(recordID: groupRecordID, action: .none),
                                    CloudField.targetUser, CloudConstant.everyone,
                                    CloudField.targetUser, userId)
        let subscription = CKQuerySubscription(recordType: CloudRecordType.ping,
                                               predicate: predicate,
                                               subscriptionID: SubscriptionID.pingCreated,
                                               options: [.firesOnRecordCreation])
        let info = CKSubscription.NotificationInfo()
        // Silent, and silent only. A ping asks a device to write a line about
        // itself; nobody needs to see that happen.
        info.shouldSendContentAvailable = true
        subscription.notificationInfo = info
        return subscription
    }

    // MARK: - What APNs carries

    /// The notification payload for an alarm.
    ///
    /// `shouldSendMutableContent` is the important line: it is what makes iOS
    /// run the notification service extension, and the extension is the only
    /// place where `interruptionLevel` can be raised to `.timeSensitive`. A
    /// CloudKit subscription cannot set that level itself — which is why this
    /// app cannot work without the extension.
    ///
    /// The title text set here is the FALLBACK, for the case where the
    /// extension does not get to run. It uses `alertLocalizationKey`, resolved
    /// by iOS against the app bundle's `Localizable.strings`, with the record
    /// fields as arguments. Note that `headline` is used rather than `type`:
    /// the arguments are raw field values, and "amok" on a lock screen tells
    /// nobody anything.
    private static func alarmNotificationInfo() -> CKSubscription.NotificationInfo {
        let info = CKSubscription.NotificationInfo()
        info.alertLocalizationKey = PushString.alarmFallback
        info.alertLocalizationArgs = [CloudField.headline,
                                      CloudField.location,
                                      CloudField.triggeredByName]
        info.soundName = PushAsset.alarmSound
        info.shouldSendMutableContent = true
        info.category = PushAsset.alarmCategory
        // One alarm, one banner — however often CloudKit decides to deliver.
        info.collapseIDKey = CloudField.alarmId
        info.desiredKeys = desiredAlarmKeys
        return info
    }

    private static func allClearNotificationInfo() -> CKSubscription.NotificationInfo {
        let info = CKSubscription.NotificationInfo()
        info.alertLocalizationKey = PushString.allClearFallback
        info.alertLocalizationArgs = [CloudField.clearedByName]
        info.soundName = PushAsset.allClearSound
        info.shouldSendMutableContent = true
        info.category = PushAsset.allClearCategory
        info.collapseIDKey = CloudField.alarmId
        info.desiredKeys = desiredAlarmKeys
        return info
    }

    /// The fields that ride along in the payload.
    ///
    /// Everything the alarm screen needs to be complete BEFORE any network
    /// call — because on a locked iPad with a dead Wi-Fi uplink there may not
    /// be a network call. `instruction` is deliberately absent: its short form
    /// is here instead, so one long text cannot burst the 4 KB APNs budget and
    /// take the whole notification with it.
    static let desiredAlarmKeys = [
        CloudField.type,
        CloudField.status,
        CloudField.location,
        CloudField.triggeredByName,
        CloudField.createdAt,
        CloudField.instructionShort,
        CloudField.headline,
        CloudField.targetUser,
        CloudField.groupRef
    ]
}
