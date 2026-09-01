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

import AVFoundation
import UserNotifications

@MainActor
enum Tontest {

    static let kennung = "tontest"
    /// Genug Zeit, das iPad wegzulegen und zu sperren — darum geht es ja
    /// gerade: Ein Ton, den man nur bei wachem Bildschirm hört, sagt nichts
    /// über den Ernstfall.
    static let vorlauf: TimeInterval = 8

    /// - Parameter mitStandardton: Spielt den System-Mitteilungston statt des
    ///   eigenen. Damit lässt sich die letzte offene Frage beantworten, wenn
    ///   die Mitteilung ankommt und stumm bleibt, die Datei sich aber direkt
    ///   abspielen lässt:
    ///
    ///   * Standardton **hörbar**, Alarmton nicht → es liegt doch an der
    ///     Datei; iOS mag sie als Mitteilungston nicht.
    ///   * **Beide stumm** → es liegt am Gerät. Dann ist es die
    ///     Klingeltonlautstärke, der Lautlos-Schalter oder eine getragene
    ///     Apple Watch, die die Mitteilung abfängt.
    ///
    ///   Ohne diesen Vergleich stehen beide Erklärungen nebeneinander, und
    ///   raten lässt sich das aus der Ferne nicht.
    static func starten(mitStandardton: Bool = false) async {
        await abbrechen()

        let inhalt = UNMutableNotificationContent()
        inhalt.title = mitStandardton ? "Tontest (Standardton)" : "Tontest"
        inhalt.body = mitStandardton
            ? "Das ist der System-Mitteilungston. Hörst du DIESEN, aber nicht "
            + "den Alarmton, liegt es an der Tondatei."
            : "Wenn du das hörst, kann dieses iPad laut werden. Die Zustellung "
            + "von einem anderen Gerät prüft der Zustelltest."
        inhalt.categoryIdentifier = PushAsset.allClearCategory

        if mitStandardton {
            inhalt.interruptionLevel = .timeSensitive
            inhalt.sound = .default
        } else {
            #if CRITICAL_ALERTS
            inhalt.interruptionLevel = .critical
            inhalt.sound = UNNotificationSound.criticalSoundNamed(
                UNNotificationSoundName(PushAsset.alarmSound), withAudioVolume: 1.0)
            #else
            inhalt.interruptionLevel = .timeSensitive
            inhalt.sound = UNNotificationSound(named:
                UNNotificationSoundName(PushAsset.alarmSound))
            #endif
        }

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


/// Die Tondatei direkt abspielen — an den Mitteilungen vorbei.
///
/// Warum das nötig wurde: Der Tontest kam an, blieb aber stumm, obwohl die
/// Datei nachweislich im App-Bündel lag. Damit standen drei Erklärungen
/// nebeneinander, und keine ließ sich von den anderen trennen:
///
/// 1. iOS kann die Datei nicht lesen und ersetzt sie stillschweigend.
/// 2. Das Gerät ist stumm (Schalter, Lautstärke) — dann macht auch eine
///    zeitkritische Mitteilung keinen Ton.
/// 3. Eine gekoppelte Apple Watch fängt die Mitteilung ab. iOS leitet sie
///    ans Handgelenk, das iPhone bleibt still — und die Uhr spielt NIE den
///    eigenen Ton einer App, sondern ihren Systemton.
///
/// Dieser Knopf schaltet Fall 1 aus. Er spielt die Datei über AVFoundation
/// in der Kategorie `playback` — die klingt auch bei stumm geschaltetem
/// Gerät. Hört man ihn, ist die Datei in Ordnung und das Problem liegt bei
/// 2 oder 3. Hört man ihn nicht, ist es die Datei.
@MainActor
enum Tonprobe {

    private static var spieler: AVAudioPlayer?

    /// Gibt zurück, was passiert ist — im Klartext, für die Anzeige.
    @discardableResult
    static func abspielen() -> String {
        let teile = PushAsset.alarmSound.split(separator: ".")
        guard teile.count == 2,
              let pfad = Bundle.main.url(forResource: String(teile[0]),
                                         withExtension: String(teile[1])) else {
            return "\(PushAsset.alarmSound) liegt nicht im App-Bündel."
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback,
                                                            options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            let neuer = try AVAudioPlayer(contentsOf: pfad)
            neuer.volume = 1
            spieler = neuer
            neuer.play()
            return "Spielt … Hörst du den Alarmton, ist die Datei in Ordnung."
        } catch {
            // Der rohe Fehler: Genau hier stünde „unsupported file type",
            // wenn das Format doch nicht taugt.
            return "Ließ sich nicht abspielen: \(error.localizedDescription)"
        }
    }

    static func anhalten() {
        spieler?.stop()
        spieler = nil
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}
