//  Meldungsstufe.swift
//  Dringlichkeitsstufe und Ton — entschieden an dem, was iOS GERADE erlaubt.
//
//  Dies ist die Lehre aus der ersten Ablehnung durch Apple (Guideline 2.1(a),
//  17.09.2026, iPad Air 11" / iPadOS 27): „We were unable to use the core
//  feature … the Tontest starten button was unresponsive, even when we put the
//  device in standby it was not woken up."
//
//  Der Knopf war nicht kaputt. Er tat genau das, was dasteht — und iOS nahm
//  die Mitteilung nicht an:
//
//  `interruptionLevel = .critical` und `criticalSoundNamed(…)` brauchen ZWEI
//  Dinge. Das Entitlement (von Apple bewilligt, im Bau vorhanden) UND die
//  Erlaubnis auf dem Gerät, die die Lehrkraft erteilen muss. Fehlt die zweite,
//  weist `add(_:)` die Anfrage ab. `Tontest` und `AlarmReminder` fragten aber
//  nur `#if CRITICAL_ALERTS` — eine Bedingung des ÜBERSETZENS, die über die
//  Erlaubnis auf dem Gerät nichts weiß. Der Prüfer hatte kritische Hinweise
//  nicht erlaubt; damit war jede dieser Mitteilungen von vornherein abgewiesen.
//
//  Das Bittere daran: In `NotificationCenterService.requestAuthorization`
//  stand die Falle wörtlich beschrieben — „it simply never succeeds, which is
//  the kind of quiet defect this app cannot afford" — und die beiden Stellen,
//  die davon lebten, prüften es trotzdem nicht.
//
//  **Schlimmer als die Ablehnung ist der Feldfehler dahinter:** Auf jedem
//  Gerät, dessen Lehrkraft kritische Hinweise abgelehnt hat, entstand keine
//  einzige der zehn Erinnerungen. Der Push kam noch an, die Reihe danach nicht
//  — also genau das Netz, das jemanden auffängt, der die erste Meldung
//  verpasst hat. Still, und niemandem wäre es aufgefallen.
//
//  Deshalb steht die Entscheidung jetzt an EINER Stelle, liegt in `Shared/`
//  (App UND Erweiterung) und liest die Erlaubnis zur Laufzeit. Wer eine neue
//  Mitteilung baut, setzt Stufe und Ton über `setze` und nirgends von Hand.

import UserNotifications

enum Meldungsstufe {

    /// Darf diese App auf DIESEM Gerät kritische Hinweise spielen?
    ///
    /// Beides muss zusammenkommen: die Compilerbedingung (ohne sie steht das
    /// Entitlement nicht im Bündel) und die Erlaubnis des Menschen. Nur wenn
    /// beide gelten, ist `.critical` erlaubt.
    static func kritischErlaubt(_ einstellungen: UNNotificationSettings) -> Bool {
        #if CRITICAL_ALERTS
        return einstellungen.criticalAlertSetting == .enabled
        #else
        return false
        #endif
    }

    static func kritischErlaubt() async -> Bool {
        let einstellungen = await UNUserNotificationCenter.current().notificationSettings()
        return kritischErlaubt(einstellungen)
    }

    /// Setzt Dringlichkeitsstufe und Ton.
    ///
    /// Der Rückfall ist `.timeSensitive` mit demselben Ton: Das braucht keine
    /// zusätzliche Erlaubnis, durchbricht einen Fokus und bleibt nur bei
    /// stummgeschaltetem Gerät still. Leiser als gewollt — aber angenommen,
    /// und eine angenommene Mitteilung ist unendlich viel mehr wert als eine
    /// abgewiesene.
    static func setze(auf inhalt: UNMutableNotificationContent,
                      ton: String,
                      kritischErlaubt: Bool) {
        let name = UNNotificationSoundName(ton)
        if kritischErlaubt {
            inhalt.interruptionLevel = .critical
            inhalt.sound = UNNotificationSound.criticalSoundNamed(
                name, withAudioVolume: 1.0)
        } else {
            inhalt.interruptionLevel = .timeSensitive
            inhalt.sound = UNNotificationSound(named: name)
        }
    }
}
