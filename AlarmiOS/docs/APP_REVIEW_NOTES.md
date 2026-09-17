# App Review Notes

Zum Einfügen in App Store Connect → App-Prüfungsinformationen → Anmerkungen.
Gilt genauso für die **Beta App Review** vor einer externen TestFlight-Gruppe
(TestFlight → Testinformationen). Der Text ist bewusst englisch: Apples
Prüfung liest englisch.

---

## Purpose

Schulalarm is a **free** in-house alert app for the staff of a school. It is
offered on the App Store to **any** school that wants it — nothing in the app
is tied to one school, one country or one customer. Whoever installs it sets
up their own school inside the app in about a minute and invites colleagues
with a six-character code. Schools are completely separate from one another;
there is no shared directory, no central account, nothing to buy and no
subscription.

(An earlier build of this app was tested as a Custom App at one school. It is
submitted here for ordinary public distribution because the need is the same
in every school, and a Custom App would reach only one of them.)

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
4. **Please tap "Erlauben" (Allow) on the notification permission dialog.**
   iOS asks twice: once for notifications, once for *critical alerts*. The
   first one is required — the app is an alarm app, and without notifications
   nothing can make a sound. The second is optional; if you decline it, alarms
   fall back to time-sensitive notifications and the in-app checklist shows
   that row as missing. Both cases are fine to review.
5. Work through the setup checklist. The item **"Zustellung geprüft"**
   (delivery verified) will stay red — see the next section; it does not block
   anything. Tap "Einrichtung abschließen".
6. To see the alarm screen: tap the large button **"Alarm auslösen"** (raise an
   alarm), choose **"PROBEALARM"** (drill), pick a location, and let the
   five-second countdown run. The drill alarm appears full-screen, marked as a
   drill in grey and yellow and labelled PROBEALARM in three places.
7. Acknowledge with "Gesehen – Klasse gesichert", then end it with
   **"Entwarnung geben"** (all clear).
8. Optional, and entirely local: Einstellungen → **"Tontest"** plays the alarm
   as a real notification on this device about 8 seconds later, without any
   network, to verify that the device is allowed to make a sound. **Lock the
   device after tapping** — that is the point of the test. The button now
   always reports what happened in a banner: that it was scheduled, or exactly
   why iOS refused it.

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

## User-generated content, and how it is moderated

There is content typed by users: a short handle, the school's name, the names
of the locations, and the messages colleagues send each other **while an alarm
is running**. It is worth saying how narrow that is:

* Nothing is public. A message is visible only inside one school, only to
  people who joined it with that school's code, and only for the duration of
  that alarm's record.
* **Blocking exists and is in the app:** an administrator removes a member
  under Verwaltung → Mitglieder → „Entfernen", and revokes the join code so
  the person cannot come back. The member list shows each member's join date
  and flags duplicate handles, so an unexpected entry is easy to spot.
* **Reporting exists:** Einstellungen → „Unangemessene Inhalte melden" opens a
  mail to schulalarm@apps.dblern.de. The same address is on the support page,
  which is linked from the same screen.
* Alarms, acknowledgements and messages are deleted after 90 days.

## Why the app asks for an iCloud account

There is no server and no account system of our own. The app stores everything
in CloudKit, which means a signed-in iCloud account is what identifies a
colleague. The first screen says so if no account is present. We ask for no
e-mail address, no password and no personal data of our own.

## What was fixed since submission 1.1.0 (39)

The first submission was rejected under Guideline 2.1(a): the reviewer found
the "Tontest starten" button unresponsive and the device was never woken up.

The cause was ours and is fixed. The test notification was built with
`interruptionLevel = .critical` and a critical sound whenever the app was
*compiled* with the critical-alerts entitlement — without checking whether the
permission had actually been **granted on the device**. When it has not,
`UNUserNotificationCenter.add(_:)` rejects the request, and the old code threw
that error away with `try?`. The button did nothing and said nothing.

Three changes:

* The interruption level and sound are now decided from the **live permission
  state** (`Shared/Meldungsstufe.swift`), in the app and in the notification
  service extension. Without the critical-alerts permission, everything falls
  back to `.timeSensitive` — quieter, but accepted and audible.
* The Tontest **reports its result** in every case: scheduled, or the raw
  reason iOS refused.
* If notification permission has never been requested, the Tontest asks for it
  instead of failing.

The same defect also silenced the local reminder series on any device whose
user had declined critical alerts, so this was a real bug and not only a
review blocker.

## Note on critical alerts

This build **does** use the critical alerts entitlement
(`com.apple.developer.usernotifications.critical-alerts`). Apple assigned it to
the developer account for the App ID `de.dboschule.alarm` on 8 September 2026.

It is what makes an intruder alarm audible on a muted iPad in a classroom. The
app asks for the permission during setup and does not fail without it: when the
user declines, notifications fall back to `.timeSensitive`, and the in-app
checklist shows the row as missing rather than pretending otherwise.

Critical alerts are used for one thing only — an alarm raised by a colleague,
and the reminder series that follows it until someone acknowledges. Messages
during an alarm deliberately stay at `.active` with the default sound.
