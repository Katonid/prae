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
            pingAll(groupRecordID: groupRecordID),
            pingMe(groupRecordID: groupRecordID, userId: userId),
            messageCreated(groupRecordID: groupRecordID)
        ]

        // Subscriptions of a previous app version, whose predicate no longer
        // matches what we send. Left in place they would deliver duplicates.
        let obsolete = known.subtracting(SubscriptionID.all)
            .filter { $0.hasPrefix("alarm-") || $0.hasPrefix("ping-")
                || $0.hasPrefix("selftest-") || $0.hasPrefix("message-") }

        let missing = wanted.filter { !known.contains($0.subscriptionID) }
        guard !missing.isEmpty || !obsolete.isEmpty else { return }

        let ergebnis = try await database.modifySubscriptions(saving: missing,
                                                             deleting: Array(obsolete))

        // `modifySubscriptions` wirft NUR, wenn der ganze Aufruf scheitert.
        // Lehnt CloudKit einzelne Abonnements ab — ein ungültiges Prädikat,
        // ein fehlender Index —, steht das ausschließlich hier. Wer das
        // Ergebnis wegwirft, liest „ohne Fehler durchgelaufen", während kein
        // einziges Abonnement entstanden ist. Genau so war es bis 1.0.4.
        let abgelehnt: [String] = ergebnis.saveResults.compactMap { kennung, ergebnis in
            guard case .failure(let fehler) = ergebnis else { return nil }
            return "\(kennung): \(CloudKitFehler.rohtext(fehler))"
        }
        guard abgelehnt.isEmpty else {
            throw SubscriptionAbgelehnt(zeilen: abgelehnt.sorted())
        }
    }

    // MARK: - Die Prädikate

    /// Einmal geschrieben, zweimal gebraucht: von der Subscription und von der
    /// Probeabfrage der Diagnose. Zwei Fassungen liefen mit Sicherheit
    /// auseinander, und dann prüfte die Diagnose etwas anderes als das, woran
    /// die Zustellung hängt.
    static func alarmPredicate(groupRecordID: CKRecord.ID) -> NSPredicate {
        NSPredicate(format: "%K == %@ AND %K == %@",
                    CloudField.groupRef,
                    CKRecord.Reference(recordID: groupRecordID, action: .none),
                    CloudField.targetUser, CloudConstant.everyone)
    }

    static func allClearPredicate(groupRecordID: CKRecord.ID) -> NSPredicate {
        NSPredicate(format: "%K == %@ AND %K == %@ AND %K == %@",
                    CloudField.groupRef,
                    CKRecord.Reference(recordID: groupRecordID, action: .none),
                    CloudField.targetUser, CloudConstant.everyone,
                    CloudField.status, AlarmStatus.cleared.rawValue)
    }

    static func selfTestPredicate(groupRecordID: CKRecord.ID,
                                  userId: String) -> NSPredicate {
        NSPredicate(format: "%K == %@ AND %K == %@",
                    CloudField.groupRef,
                    CKRecord.Reference(recordID: groupRecordID, action: .none),
                    CloudField.targetUser, userId)
    }

    /// Ein Ping an alle.
    ///
    /// Es gibt zwei Ping-Prädikate statt eines mit `OR`, weil **CloudKit kein
    /// `OR` kennt**: „Invalid predicate: Unexpected expression". Das fällt
    /// erst beim Anlegen auf dem Gerät auf, nicht beim Übersetzen.
    static func pingAllPredicate(groupRecordID: CKRecord.ID) -> NSPredicate {
        NSPredicate(format: "%K == %@ AND %K == %@",
                    CloudField.groupRef,
                    CKRecord.Reference(recordID: groupRecordID, action: .none),
                    CloudField.targetUser, CloudConstant.everyone)
    }

    /// Ein Ping an genau dieses Gerät.
    static func pingMePredicate(groupRecordID: CKRecord.ID, userId: String) -> NSPredicate {
        NSPredicate(format: "%K == %@ AND %K == %@",
                    CloudField.groupRef,
                    CKRecord.Reference(recordID: groupRecordID, action: .none),
                    CloudField.targetUser, userId)
    }

    /// Jede Nachricht der eigenen Gruppe.
    ///
    /// Nicht auf den laufenden Alarm eingeschränkt: Ein Prädikat lässt sich
    /// nachträglich nicht ändern, ein Alarm wechselt aber ständig. Gefiltert
    /// wird beim Anzeigen, nicht beim Zustellen.
    static func messagePredicate(groupRecordID: CKRecord.ID) -> NSPredicate {
        NSPredicate(format: "%K == %@",
                    CloudField.groupRef,
                    CKRecord.Reference(recordID: groupRecordID, action: .none))
    }

    /// Was die Diagnose einzeln nachfragt: Kennung, Record-Typ, Prädikat.
    static func proben(groupRecordID: CKRecord.ID,
                       userId: String) -> [(kennung: String, typ: String,
                                            predicate: NSPredicate)] {
        [(SubscriptionID.alarmCreated, CloudRecordType.alarm,
          alarmPredicate(groupRecordID: groupRecordID)),
         (SubscriptionID.alarmCleared, CloudRecordType.alarm,
          allClearPredicate(groupRecordID: groupRecordID)),
         (SubscriptionID.selfTest, CloudRecordType.alarm,
          selfTestPredicate(groupRecordID: groupRecordID, userId: userId)),
         (SubscriptionID.pingAll, CloudRecordType.ping,
          pingAllPredicate(groupRecordID: groupRecordID)),
         (SubscriptionID.pingMe, CloudRecordType.ping,
          pingMePredicate(groupRecordID: groupRecordID, userId: userId)),
         (SubscriptionID.messageCreated, CloudRecordType.message,
          messagePredicate(groupRecordID: groupRecordID))]
    }

    // MARK: - Die Subscriptions

    /// A real alarm, for everybody in the group.
    static func alarmCreated(groupRecordID: CKRecord.ID) -> CKQuerySubscription {
        let predicate = alarmPredicate(groupRecordID: groupRecordID)
        let subscription = CKQuerySubscription(recordType: CloudRecordType.alarm,
                                               predicate: predicate,
                                               subscriptionID: SubscriptionID.alarmCreated,
                                               options: [.firesOnRecordCreation])
        subscription.notificationInfo = alarmNotificationInfo()
        return subscription
    }

    /// The same record, updated to `cleared`.
    static func alarmCleared(groupRecordID: CKRecord.ID) -> CKQuerySubscription {
        let predicate = allClearPredicate(groupRecordID: groupRecordID)
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
        let predicate = selfTestPredicate(groupRecordID: groupRecordID,
                                          userId: userId)
        let subscription = CKQuerySubscription(recordType: CloudRecordType.alarm,
                                               predicate: predicate,
                                               subscriptionID: SubscriptionID.selfTest,
                                               options: [.firesOnRecordCreation])
        subscription.notificationInfo = alarmNotificationInfo()
        return subscription
    }

    /// "Report your status." The only silent push this app has.
    static func pingAll(groupRecordID: CKRecord.ID) -> CKQuerySubscription {
        ping(SubscriptionID.pingAll, pingAllPredicate(groupRecordID: groupRecordID))
    }

    static func pingMe(groupRecordID: CKRecord.ID, userId: String) -> CKQuerySubscription {
        ping(SubscriptionID.pingMe,
             pingMePredicate(groupRecordID: groupRecordID, userId: userId))
    }

    /// Eine Nachricht, die jemand während eines Alarms geschrieben hat.
    ///
    /// Bewusst ein eigenes Abonnement mit eigener Meldung: Eine Nachricht ist
    /// kein zweiter Alarm. Den Ton und die Dringlichkeit setzt die Erweiterung
    /// (`.active`, Standardton); hier steht nur, was mitreisen muss.
    ///
    /// Drei `desiredKeys`, mehr sind nicht erlaubt — und alle drei werden
    /// gebraucht: `senderName` fürs Kürzel im Titel, `text` für die Nachricht
    /// selbst, `alarmId` damit ein Tipp im richtigen Alarm landet.
    static func messageCreated(groupRecordID: CKRecord.ID) -> CKQuerySubscription {
        let subscription = CKQuerySubscription(
            recordType: CloudRecordType.message,
            predicate: messagePredicate(groupRecordID: groupRecordID),
            subscriptionID: SubscriptionID.messageCreated,
            options: [.firesOnRecordCreation])
        let info = CKSubscription.NotificationInfo()
        info.alertLocalizationKey = PushString.messageFallback
        info.shouldSendMutableContent = true
        info.category = PushAsset.messageCategory
        info.desiredKeys = [CloudField.senderName, CloudField.text, CloudField.alarmId]
        subscription.notificationInfo = info
        return subscription
    }

    private static func ping(_ kennung: String,
                             _ predicate: NSPredicate) -> CKQuerySubscription {
        let subscription = CKQuerySubscription(recordType: CloudRecordType.ping,
                                               predicate: predicate,
                                               subscriptionID: kennung,
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
    /// Der Text hier ist der RÜCKFALL — für den Fall, dass die Erweiterung
    /// nicht zum Zug kommt. Er steht als `alertLocalizationKey` ohne
    /// Argumente, und das ist Absicht: `alertLocalizationArgs` nennt
    /// Record-Felder, und Felder sind hier streng gedeckelt. Lieber ein
    /// knapper fester Satz als ein Abonnement, das gar nicht erst entsteht.
    ///
    /// Ein `alert` muss gesetzt sein. Ohne ihn wäre die Meldung still, und
    /// stille Pushes drosselt iOS — für einen Alarm wäre das das Ende.
    // MARK: - Die Stufenprobe

    /// Drei Abonnements, die sich um je EINE Sache unterscheiden.
    ///
    /// Sie werden nur gebaut, wenn die echten fünf abgelehnt wurden, und in
    /// `CloudKitBackend.stufenprobe` einzeln angelegt und sofort wieder
    /// gelöscht. Der Zweck ist, aus einer Fehlermeldung, die auf die Umgebung
    /// zeigt, eine Aussage zu machen: Liegt es am Anlegen überhaupt, am
    /// Prädikat oder an der Meldung?
    ///
    /// Die Kennungen tragen einen Stempel, damit sie nie mit einem echten
    /// Abonnement zusammenfallen und ein liegen gebliebener Rest von gestern
    /// den Versuch von heute nicht verfälscht.
    static func stufen(groupRecordID: CKRecord.ID, stempel: String)
        -> [(name: String, titel: String, abo: CKQuerySubscription)] {

        func nackt() -> CKSubscription.NotificationInfo {
            let info = CKSubscription.NotificationInfo()
            info.shouldSendContentAvailable = true
            return info
        }

        let schlicht = CKQuerySubscription(
            recordType: CloudRecordType.alarm,
            predicate: NSPredicate(value: true),
            subscriptionID: "probe-schlicht-\(stempel)",
            options: [.firesOnRecordCreation])
        schlicht.notificationInfo = nackt()

        let mitPraedikat = CKQuerySubscription(
            recordType: CloudRecordType.alarm,
            predicate: alarmPredicate(groupRecordID: groupRecordID),
            subscriptionID: "probe-praedikat-\(stempel)",
            options: [.firesOnRecordCreation])
        mitPraedikat.notificationInfo = nackt()

        let mitMeldung = CKQuerySubscription(
            recordType: CloudRecordType.alarm,
            predicate: alarmPredicate(groupRecordID: groupRecordID),
            subscriptionID: "probe-meldung-\(stempel)",
            options: [.firesOnRecordCreation])
        mitMeldung.notificationInfo = alarmNotificationInfo()

        return [("schlicht", "1 schlicht (ohne Prädikat, ohne Meldung)", schlicht),
                ("praedikat", "2 mit Prädikat", mitPraedikat),
                ("meldung", "3 mit Meldung", mitMeldung)]
    }

    private static func alarmNotificationInfo() -> CKSubscription.NotificationInfo {
        let info = CKSubscription.NotificationInfo()
        info.alertLocalizationKey = PushString.alarmFallback
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
        info.soundName = PushAsset.allClearSound
        info.shouldSendMutableContent = true
        info.category = PushAsset.allClearCategory
        info.collapseIDKey = CloudField.alarmId
        info.desiredKeys = desiredAllClearKeys
        return info
    }

    /// **Höchstens DREI.** Das ist keine Stilfrage, sondern die Obergrenze von
    /// CloudKit: Mit zehn Feldern wurde jedes Alarm-Abonnement abgelehnt —
    /// „notification additional fields limit exceeded" —, und ein Gerät ohne
    /// Abonnement ist für immer stumm. Die beiden Ping-Abonnements kamen
    /// durch, weil sie gar keine Felder mitschicken.
    ///
    /// Die drei sind die, ohne die auf einem gesperrten iPad nichts Brauchbares
    /// stünde: WAS ist los, WO, und von WEM. Der Datensatzname (und damit die
    /// `alarmId`) reist ohnehin mit.
    ///
    /// Was nicht mehr mitkommt und warum das zu verschmerzen ist:
    ///
    /// * `status` und `targetUser` — die Kennung des Abonnements sagt schon,
    ///   ob es ein Alarm, eine Entwarnung oder ein Selbsttest ist.
    /// * `createdAt` — damit fällt die Altersprüfung der Erweiterung aus. Sie
    ///   bleibt im Quelltext für ein späteres Backend, das den Zeitstempel
    ///   mitschickt (siehe `docs/PUSH_CONTRACT.md`); bei CloudKit greift sie
    ///   nicht mehr. Ein zu laut gemeldeter alter Alarm ist der kleinere
    ///   Schaden als ein Alarm, der gar nicht kommt.
    /// * `instructionShort` — der Handlungstext steht eine Sekunde später auf
    ///   dem Alarm-Bildschirm.
    static let desiredAlarmKeys = [
        CloudField.type,
        CloudField.location,
        CloudField.triggeredByName
    ]

    /// Bei der Entwarnung zählt, WER sie gegeben hat — der Ort nicht.
    static let desiredAllClearKeys = [
        CloudField.type,
        CloudField.clearedByName
    ]
}
