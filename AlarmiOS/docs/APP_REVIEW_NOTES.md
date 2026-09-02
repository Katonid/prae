# App Review Notes

Zum Einfügen in App Store Connect → App-Prüfungsinformationen → Anmerkungen.
Gilt genauso für die **Beta App Review** vor einer externen TestFlight-Gruppe
(TestFlight → Testinformationen). Der Text ist bewusst englisch: Apples
Prüfung liest englisch.

---

## Purpose

This is an internal emergency notification app for the staff of a single
German primary school (about 30 teachers). It is distributed as a **Custom
App** through Apple School Manager and Jamf School and is not intended for
the public App Store.

One teacher raises an alarm (intruder, fire, medical emergency, or a drill).
Every colleague's school-issued iPad receives a time-sensitive notification
with a sound, shows what happened and where, and offers two one-tap replies:
"class secured" or "help needed". An administrator and the person who
raised the alarm see who has answered; everybody else sees only the count.

## This app does not replace the emergency services

The alarm screen says so, and so do the app's settings: **110 and 112 remain
the way to reach the police and the fire brigade.** This app only notifies
colleagues inside one building. It makes no claim of reaching any emergency
service, and it is not a medical or life-safety device in the regulatory
sense.

## Backend

There is no server. The app uses CloudKit's public database in the
developer's own container. Notifications are delivered by CloudKit
subscriptions; a notification service extension raises them to
`.timeSensitive` so they break through Focus modes.

## Permissions requested, and why

| Permission | Why |
|---|---|
| Notifications (alert, sound, badge) | the entire purpose of the app |
| Time-sensitive notifications | an alarm must pass a Focus mode |
| Background modes: remote notifications | a silent "report your status" push |
| Background modes: fetch | `BGAppRefreshTask` refreshes the device's own status entry |
| Camera | reading the six-character join code from a QR code, once, at setup |
| iCloud / CloudKit | data storage and delivery |

No location, no contacts, no microphone, no advertising identifier, no
analytics, no third-party SDK of any kind.

## Data collected

Short handle (e.g. "MÜ" — not a full name), the CloudKit user record ID,
device model, app version, notification permission state, the alarms
themselves, acknowledgements and the messages typed during an alarm. Records
older than 90 days are deleted. See `PrivacyInfo.xcprivacy`.

## How to test

**No test account or join code is needed.** The reviewer sets up their own
school in the app; it is completely separate from any real school's data.

1. Open the app. Sign in to iCloud on the device first — the app stores
   everything in CloudKit and says so on its first screen if no account is
   present.
2. Choose **"Schule einrichten"** (set up a school) at the top, not "Beitreten"
   (join). Enter any school name and any short handle, e.g. "TEST", and tap
   **"Schule einrichten und Admin werden"**.
   *This is the important step: whoever sets up a school becomes its
   administrator, and only an administrator may raise a drill. Somebody who
   joins an existing school with a code is an ordinary member and will not see
   the drill option.*
3. A six-character join code is shown. Nothing needs to be done with it.
4. Work through the setup checklist and allow notifications. The item
   **"Zustellung geprüft"** (delivery verified) will stay red — see the next
   section; it does not block anything. Tap "Einrichtung abschließen".
5. To see the alarm screen: tap the large button **"Alarm auslösen"** (raise an
   alarm), choose **"PROBEALARM"** (drill), pick a location, and let the
   five-second countdown run. The drill alarm appears full-screen, marked as a
   drill in grey and yellow and labelled PROBEALARM in three places.
6. Acknowledge with "Gesehen – Klasse gesichert", then end it with
   **"Entwarnung geben"** (all clear).
7. Optional, and entirely local: Einstellungen → **"Tontest"** plays the alarm
   as a real notification on this device, without any network, to verify that
   the device is allowed to make a sound.

**Please use the drill type (PROBEALARM).** The three real types exist for
genuine emergencies. In a school of the reviewer's own making they would reach
nobody, but the drill type is unmistakable either way.

## What a single device cannot show

CloudKit does not deliver a subscription notification to the device that wrote
the record. **One device therefore cannot prove push delivery to itself**, and
the app deliberately no longer offers a button that pretends otherwise. That is
why the checklist item "Zustellung geprüft" stays red on a review device: it
sets itself only when a push actually arrives, which requires a second device.

Everything else — permissions, sound, the alarm screen, acknowledgements, the
all-clear, administration — is fully testable on one device.

## Note on critical alerts

This build does **not** request the critical alerts entitlement. Should it be
granted later, the relevant code is behind the `CRITICAL_ALERTS` compilation
condition and is inactive in this build.
