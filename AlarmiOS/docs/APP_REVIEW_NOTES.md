# App Review Notes

Zum Einfügen in App Store Connect → App-Prüfungsinformationen → Anmerkungen.
Der Text ist bewusst englisch: Apples Prüfung liest englisch.

---

## Purpose

This is an internal emergency notification app for the staff of a single
German primary school (about 30 teachers). It is distributed as a **Custom
App** through Apple School Manager and Jamf School and is not intended for
the public App Store.

One teacher raises an alarm (intruder, fire, medical emergency, or a drill).
Every colleague's school-issued iPad receives a time-sensitive notification
with a sound, shows what happened and where, and offers two one-tap replies:
"class secured" or "help needed". The head teacher sees who has answered.

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

1. Open the app. It asks for a handle and a six-character join code.
2. Join code for review: **`______`**
   *(Fill in before submitting: App → Verwaltung → Beitrittscodes → create a
   fresh code with the note "App Review", and revoke it after the review.)*
3. Enter any handle, e.g. "TEST".
4. Work through the setup checklist and allow notifications.
5. Tap "Testalarm an dieses Gerät senden". A drill alarm arrives on **this
   device only** — it is marked PROBEALARM (drill) in yellow and grey, and no
   other device sees it.
6. To see the full alarm screen: tap "Alarm auslösen", choose
   "PROBEALARM", choose a location, and let the five-second countdown run.
   The review account is an administrator, so it may raise and clear drills.

**Please use the drill type (PROBEALARM) for testing.** The other three
types would notify a real school's staff if the review device were joined to
the production group; the review code above points to a separate test group,
but the drill type is unmistakable either way.

## Note on critical alerts

This build does **not** request the critical alerts entitlement. Should it be
granted later, the relevant code is behind the `CRITICAL_ALERTS` compilation
condition and is inactive in this build.
