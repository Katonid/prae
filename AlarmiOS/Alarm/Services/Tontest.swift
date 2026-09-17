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
    /// Gibt zurück, was passiert ist — im Klartext, für die Anzeige.
    ///
    /// Bis 1.1.0 (Build 39) gab dieser Aufruf nichts zurück und schluckte
    /// seinen Fehler mit `try?`. Genau daran ist die erste Einreichung
    /// gescheitert: Der Prüfer tippte, iOS wies die Mitteilung ab, und der
    /// Knopf schwieg. „Ein Knopf, der schweigt, ist für den Menschen davor ein
    /// kaputter Knopf" stand seit 1.0.26 im Papier — für diesen Knopf galt es
    /// nicht. Jetzt sagt er in jedem Fall etwas.
    @discardableResult
    static func starten(mitStandardton: Bool = false) async -> String {
        await abbrechen()

        let zentrale = UNUserNotificationCenter.current()
        var erlaubnis = await zentrale.notificationSettings()

        // Noch nie gefragt? Dann hier fragen, statt an einer Erlaubnis zu
        // scheitern, die niemand verweigert hat. Wer die Prüfliste übersprungen
        // hat — oder sie nie gesehen hat —, landete sonst in einer Sackgasse,
        // und genau so hat der Prüfer von Apple die App erlebt.
        if erlaubnis.authorizationStatus == .notDetermined {
            var optionen: UNAuthorizationOptions = [.alert, .sound, .badge]
            #if CRITICAL_ALERTS
            optionen.insert(.criticalAlert)
            #endif
            _ = try? await zentrale.requestAuthorization(options: optionen)
            erlaubnis = await zentrale.notificationSettings()
        }

        // Ohne Mitteilungserlaubnis kann sich das Gerät nicht selbst wecken —
        // und dieser Test IST eine Mitteilung. Das muss dastehen, nicht
        // stillschweigend ins Leere laufen.
        guard erlaubnis.authorizationStatus == .authorized else {
            return "Mitteilungen sind für diese App nicht erlaubt. Ohne sie "
                + "kann sich dieses \(Geraetename.wort) nicht selbst wecken — "
                + "und im Ernstfall auch nicht von einer Kollegin geweckt "
                + "werden. Einstellungen → Mitteilungen → Schulalarm → "
                + "„Mitteilungen erlauben“, danach hier noch einmal tippen."
        }

        let inhalt = UNMutableNotificationContent()
        inhalt.title = mitStandardton ? "Tontest (Standardton)" : "Tontest"
        inhalt.body = mitStandardton
            ? "Das ist der System-Mitteilungston. Hörst du DIESEN, aber nicht "
            + "den Alarmton, liegt es an der Tondatei."
            : "Wenn du das hörst, kann dieses \(Geraetename.wort) laut werden. Die Zustellung "
            + "von einem anderen Gerät prüft der Zustelltest."
        inhalt.categoryIdentifier = PushAsset.allClearCategory

        let kritisch = Meldungsstufe.kritischErlaubt(erlaubnis)
        if mitStandardton {
            inhalt.interruptionLevel = .timeSensitive
            inhalt.sound = .default
        } else {
            Meldungsstufe.setze(auf: inhalt, ton: PushAsset.signalSound,
                                kritischErlaubt: kritisch)
        }

        let ausloeser = UNTimeIntervalNotificationTrigger(timeInterval: vorlauf,
                                                          repeats: false)
        do {
            try await zentrale.add(
                UNNotificationRequest(identifier: kennung, content: inhalt,
                                      trigger: ausloeser))
        } catch {
            // Der rohe Fehlertext. Hier stand bei der Ablehnung durch Apple
            // die Ursache — und niemand bekam sie zu sehen.
            return "iOS hat die Mitteilung nicht angenommen: "
                + "\(error.localizedDescription)"
        }

        let stufe = kritisch
            ? "als kritischer Hinweis — der Ton kommt auch bei stummem Gerät."
            : "zeitkritisch. Kritische Hinweise sind auf diesem Gerät nicht "
            + "erlaubt; bei stummgeschaltetem Gerät bleibt es deshalb still."
        return "Der Ton kommt in \(Int(vorlauf)) Sekunden, \(stufe) "
            + "Sperre das \(Geraetename.wort) jetzt und lege es hin."
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
    static func abspielen(_ klang: Alarmklang) -> String {
        guard let pfad = klang.quelle else {
            return klang == .eigen
                ? "Es ist kein eigener Ton hinterlegt."
                : "\(klang.datei ?? klang.rawValue) liegt nicht im App-Bündel."
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback,
                                                            options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            let neuer = try AVAudioPlayer(contentsOf: pfad)
            neuer.volume = 1
            spieler = neuer
            neuer.play()
            return "Spielt „\(klang.titel)“ … Das ist die Datei, nicht die "
                 + "Mitteilung: Sie klingt auch bei stummem \(Geraetename.wort)."
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
