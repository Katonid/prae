//  Tontest.swift
//  Der Test, der ohne Netz auskommt.
//
//  Warum es ihn neben dem Selbsttest gibt: Wenn nichts ankommt, gibt es zwei
//  völlig verschiedene Ursachen, und sie brauchen völlig verschiedene
//  Handgriffe.
//
//  1. Das Gerät WILL nicht laut werden — Mitteilungen nicht erlaubt, Ton aus,
//     Fokus davor, Lautlos-Schalter, Sperrbildschirm-Einstellung.
//  2. Das Gerät BEKOMMT nichts — Apple-ID, Subscription, CloudKit-Schema,
//     Netz.
//
//  Der Selbsttest geht durch die ganze Kette und kann deshalb nicht sagen, an
//  welcher Stelle sie reißt. Dieser hier lässt das Gerät sich selbst wecken:
//  dieselbe Datei, dieselbe Lautstärke, dieselbe Dringlichkeitsstufe, aber
//  ohne einen einzigen Meter Netz. Klingt er, ist Fall 1 ausgeschlossen.
//
//  Er beweist ausdrücklich NICHT, dass ein Alarm von einem anderen iPad
//  ankommt. Das kann nur der Selbsttest, und ganz sicher nur ein zweites
//  Gerät.

import UserNotifications

@MainActor
enum Tontest {

    static let kennung = "tontest"
    /// Genug Zeit, das iPad wegzulegen und zu sperren — darum geht es ja
    /// gerade: Ein Ton, den man nur bei wachem Bildschirm hört, sagt nichts
    /// über den Ernstfall.
    static let vorlauf: TimeInterval = 8

    static func starten() async {
        await abbrechen()

        let inhalt = UNMutableNotificationContent()
        inhalt.title = "Tontest"
        inhalt.body = "Wenn du das hörst, kann dieses iPad laut werden. "
            + "Die Zustellung von einem anderen Gerät prüft der Selbsttest."
        inhalt.categoryIdentifier = PushAsset.allClearCategory

        #if CRITICAL_ALERTS
        inhalt.interruptionLevel = .critical
        inhalt.sound = UNNotificationSound.criticalSoundNamed(
            UNNotificationSoundName(PushAsset.alarmSound), withAudioVolume: 1.0)
        #else
        inhalt.interruptionLevel = .timeSensitive
        inhalt.sound = UNNotificationSound(named:
            UNNotificationSoundName(PushAsset.alarmSound))
        #endif

        let ausloeser = UNTimeIntervalNotificationTrigger(timeInterval: vorlauf,
                                                          repeats: false)
        try? await UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: kennung, content: inhalt,
                                  trigger: ausloeser))
    }

    static func abbrechen() async {
        let zentrale = UNUserNotificationCenter.current()
        zentrale.removePendingNotificationRequests(withIdentifiers: [kennung])
        zentrale.removeDeliveredNotifications(withIdentifiers: [kennung])
    }
}
