//  OnboardingChecklist.swift
//  Everything that has to be true before this iPad can be relied on.
//
//  The list is split in two on purpose:
//
//  * Items the app can CHECK. They get a state and a button that jumps to the
//    right place in Settings.
//  * Items the app cannot check — whether the app is allowed through every
//    Focus mode, whether notifications show on the lock screen at all, what
//    the silent switch does. iOS exposes none of these. They are listed as
//    plain instructions rather than faked as green ticks, because a green tick
//    that means "we did not look" is the most expensive kind of lie an app
//    like this can tell.

import Foundation
import UIKit

struct ChecklistItem: Identifiable, Equatable {
    enum State: Equatable {
        case ok
        case missing
        case unknown

        var symbol: String {
            switch self {
            case .ok: return "checkmark.circle.fill"
            case .missing: return "exclamationmark.triangle.fill"
            case .unknown: return "questionmark.circle"
            }
        }
    }

    var id: String
    var title: String
    var detail: String
    var state: State
    /// Where in the system settings this is fixed, when it can be jumped to.
    var settingsURL: URL?

    /// Ein offener Punkt hält den Abschluss der Einrichtung NICHT auf.
    ///
    /// Bis 1.1.0 (Build 42) gab es dafür ein Feld, und „Einrichtung
    /// abschließen" war grau, solange eine der Mitteilungszeilen rot stand.
    /// **Das hat die zweite Ablehnung durch Apple gekostet** (Guideline 4.5.4,
    /// 19.09.2026, iPad Air 11": „The app requires push notifications in order
    /// to function. Push notifications must be optional and must obtain the
    /// user's consent to be used within the app.") — und der Prüfer hatte
    /// recht: Wer die Mitteilungsfrage mit „Nicht erlauben" beantwortete, kam
    /// aus der Einrichtung nie wieder heraus. Kein Auslösen, keine Verwaltung,
    /// keine Prüfliste, nichts.
    ///
    /// Es ist dieselbe Sackgasse wie 1.0.10 beim Zustellnachweis, nur eine
    /// Etage tiefer, und diesmal war sie vollständig. **Die Regel daraus ist
    /// allgemein: Diese App sperrt niemanden aus — sie SAGT, was fehlt.**
    /// Ohne Mitteilungen ist das Gerät schlechter dran, aber nicht wertlos:
    /// Auslösen, Rückmelden, Nachrichten, Entwarnen und die Abfrage alle fünf
    /// Sekunden laufen weiter; was fehlt, ist der Ton, wenn die App hinten
    /// liegt. Das steht so auf dem Bildschirm, in der Prüfliste und im
    /// Warnband — und es hält niemanden auf.
    var isBlocking: Bool { state == .missing }
}

enum OnboardingChecklist {

    /// Die Zeilen, die an der Mitteilungserlaubnis hängen.
    ///
    /// Eine Liste und keine verstreute Abfrage: Wer eine Zeile dazunimmt, die
    /// ohne die Erlaubnis nie grün werden kann, trägt sie hier ein — sonst
    /// erklärt das Warnband auf dem Startbildschirm die Hälfte des Problems.
    static let mitteilungsPunkte: Set<String> = [
        "notifications", "sound", "lockscreen", "timesensitive", "critical",
        "tontest"
    ]

    /// The checkable half.
    static func items(permissions: NotificationCenterService.Permissions,
                      availability: BackendAvailability,
                      tontestPassed: Bool,
                      zustellungGeprueft: Bool,
                      criticalAlertsBuilt: Bool,
                      mitgliedschaftFehlt: Bool = false) -> [ChecklistItem] {
        let settings = URL(string: UIApplication.openSettingsURLString)

        var items: [ChecklistItem] = [
            ChecklistItem(
                id: "notifications",
                title: "Mitteilungen erlaubt",
                detail: permissions.authorization == .authorized
                    ? "Die App darf Mitteilungen zeigen."
                    : "Ohne Erlaubnis bleibt dieses \(Geraetename.wort) im Alarmfall "
                    + "stumm, solange die App nicht offen ist. Auslösen, "
                    + "Rückmelden, Nachrichten und Entwarnen gehen weiter, und "
                    + "bei offener App erscheint ein Alarm binnen Sekunden von "
                    + "selbst. Erlauben lässt sich das jederzeit — hier in der "
                    + "Prüfliste oder in den Einstellungen des Geräts.",
                state: permissions.authorization == .authorized ? .ok : .missing,
                settingsURL: settings),

            ChecklistItem(
                id: "sound",
                title: "Ton erlaubt",
                detail: permissions.soundEnabled
                    ? "Mitteilungen dieser App dürfen einen Ton spielen."
                    : "Die Mitteilung käme an, aber lautlos. Für einen Alarm ist "
                    + "das dasselbe wie gar nicht.",
                state: permissions.soundEnabled ? .ok : .missing,
                settingsURL: settings),

            ChecklistItem(
                id: "lockscreen",
                title: "Auf dem Sperrbildschirm sichtbar",
                detail: permissions.lockScreenEnabled
                    ? "Der Alarm erscheint auch bei gesperrtem \(Geraetename.wort)."
                    : "Bei gesperrtem \(Geraetename.wort) wäre nichts zu sehen — und das ist der "
                    + "Normalfall im Unterricht.",
                state: permissions.lockScreenEnabled ? .ok : .missing,
                settingsURL: settings),

            ChecklistItem(
                id: "timesensitive",
                title: "Zeitkritische Mitteilungen erlaubt",
                detail: permissions.timeSensitiveAllowed
                    ? "Der Alarm durchbricht einen aktiven Fokus."
                    : "Ohne diese Einstellung hält ein Fokus („Nicht stören“, "
                    + "„Unterricht“) den Alarm zurück.",
                state: permissions.timeSensitiveAllowed ? .ok : .missing,
                settingsURL: settings)
        ]

        if criticalAlertsBuilt {
            items.append(ChecklistItem(
                id: "critical",
                title: "Kritische Hinweise erlaubt",
                detail: permissions.criticalAllowed
                    ? "Der Alarm klingt auch bei stummgeschaltetem \(Geraetename.wort) und "
                    + "durch jeden Fokus."
                    : "Diese Fassung ist für kritische Hinweise gebaut, dieses "
                    + "\(Geraetename.wort) erlaubt sie aber nicht. Die App fragt beim nächsten "
                    + "Start noch einmal; kommt keine Frage, steht der Schalter "
                    + "in den Einstellungen unter „Mitteilungen“ → Schulalarm "
                    + "→ „Kritische Hinweise“.",
                state: permissions.criticalAllowed ? .ok : .missing,
                settingsURL: settings))
        }

        // Nur wenn der Server das WIRKLICH gesagt hat — ein Netzaussetzer
        // setzt diese Zeile nie. Lösen lässt sich der Fall ohnehin nur durch
        // Austreten, und dazu zwingt die App niemanden.
        if mitgliedschaftFehlt {
            items.append(ChecklistItem(
                id: "mitgliedschaft",
                title: "Mitglied dieser Schule",
                detail: "Dieses Konto steht nicht mehr in der Mitgliederliste — "
                    + "vermutlich hat ein Admin es entfernt, oder der Austritt "
                    + "ist auf einem anderen Gerät erfolgt. Der Alarm kommt "
                    + "hier noch an, die Rückmeldung zählt aber bei niemandem "
                    + "mehr. Einstellungen → „Verbindung zur Schule lösen“ "
                    + "räumt dieses Gerät auf.",
                state: .missing,
                settingsURL: nil))
        }

        items.append(ChecklistItem(
            id: "icloud",
            title: "Apple-ID angemeldet",
            detail: availability.explanation,
            state: availability.isReady ? .ok : .missing,
            settingsURL: settings))

        // Zwei Zeilen, weil es zwei verschiedene Behauptungen sind. „Das iPad
        // darf laut werden" und „von einem anderen Gerät kommt etwas an" sind
        // nicht dasselbe, und wenn nichts klingelt, ist die erste Frage, welche
        // der beiden gerade nicht stimmt.
        items.append(ChecklistItem(
            id: "tontest",
            title: "Ton auf diesem Gerät gehört",
            detail: tontestPassed
                ? "Das \(Geraetename.wort) wird laut — gesperrt, mit Ton, in der richtigen "
                + "Dringlichkeitsstufe."
                : "Noch nicht geprüft. Der Tontest weckt das \(Geraetename.wort) selbst, ohne "
                + "Netz. Klingt er nicht, liegt es am Gerät und nicht an der "
                + "Zustellung.",
            state: tontestPassed ? .ok : .missing,
            settingsURL: nil))

        // Nur auf dem iPhone, und bewusst OHNE Häkchen.
        //
        // Ob eine Uhr gekoppelt ist und ob die Spiegelung für diese App aus
        // steht, verrät iOS einer App nicht — das Zweite gibt es als
        // Schnittstelle überhaupt nicht. Ein grüner Haken wäre hier also
        // geraten, und geraten wird in dieser Liste nichts. Auf einem iPad
        // erscheint die Zeile gar nicht erst: Dort gibt es keine Spiegelung.
        if UIDevice.current.userInterfaceIdiom == .phone {
            items.append(ChecklistItem(
                id: "watch",
                title: "Apple Watch: Spiegelung aus",
                detail: "Ist dieses iPhone mit einer Apple Watch gekoppelt und "
                    + "wird sie getragen, leitet iOS die Meldung ans Handgelenk "
                    + "und das iPhone bleibt STILL — und die Uhr spielt nie den "
                    + "Alarmton dieser App, sondern ihren Systemton.\n\n"
                    + "Abschalten: App „Watch“ → Mitteilungen → ganz unten "
                    + "„Mitteilungen von iPhone spiegeln“ → Schulalarm aus. "
                    + "Danach bleibt der Alarm auf dem iPhone, mit dem eigenen "
                    + "Ton.\n\nOhne gekoppelte Uhr ist hier nichts zu tun.",
                state: .unknown,
                settingsURL: nil))
        }

        items.append(ChecklistItem(
            id: "zustellung",
            title: "Zustellung geprüft",
            detail: zustellungGeprueft
                ? "Auf diesem \(Geraetename.wort) ist mindestens eine Meldung über iCloud "
                + "eingetroffen."
                : "Noch nie ist hier eine Meldung eingetroffen. Der Haken setzt "
                + "sich von selbst, sobald ein Admin einen Testalarm an dieses "
                + "Gerät schickt — von einem ANDEREN Gerät aus. Ein Gerät kann "
                + "sich die Zustellung nicht selbst beweisen.",
            state: zustellungGeprueft ? .ok : .missing,
            settingsURL: nil))

        return items
    }

    /// The half iOS keeps to itself. Instructions, not claims.
    static let manualHints: [(title: String, detail: String)] = [
        ("App in jedem Fokus zulassen",
         "Einstellungen → Fokus → jeden eingerichteten Fokus öffnen → „Apps“ → "
         + "diese App erlauben. iOS verrät einer App nicht, ob das geschehen ist — "
         + "diese Zeile lässt sich deshalb nicht abhaken, sondern nur tun."),
        ("Lautlos-Schalter und Lautstärke",
         "Ohne die Berechtigung „kritische Hinweise“ spielt auch ein "
         + "zeitkritischer Alarm bei stummgeschaltetem Gerät keinen Ton — es "
         + "bleibt bei Vibration und Anzeige. Auf einem Dienstgerät gehört der "
         + "Schalter deshalb auf „laut“."),
        ("Mitteilungen dauerhaft anzeigen",
         "Einstellungen → Mitteilungen → diese App → „Banner-Stil: Dauerhaft“. "
         + "Ein temporäres Banner verschwindet nach Sekunden; wer gerade zur "
         + "Tafel schaut, hat es dann verpasst.")
    ]
}
