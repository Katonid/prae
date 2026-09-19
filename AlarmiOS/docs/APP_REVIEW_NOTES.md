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
| Notifications (alert, sound, badge) | so an alarm is audible while the app is in the background — **optional**, see "Notifications are optional" below |
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
4. The setup screen has a section **"Mitteilungen — freiwillig"**
   (notifications — optional) with two entries: a button that asks for the
   permission, and **"Was ohne Mitteilungen geht"** (what works without
   notifications), which lists feature by feature what is available and what is
   not. **Either choice continues the review.** Declining costs the sound when
   the app is in the background; nothing is locked or hidden. If you would like
   to hear an alarm, please allow notifications — iOS then asks a second time
   for *critical alerts*, which is optional again and only decides whether the
   alarm is audible on a silenced device.
5. Work through the setup checklist. **No item blocks anything**; red rows are
   information, and the button "Einrichtung abschließen" (finish setup) is
   always enabled. "Zustellung geprüft" (delivery verified) in particular stays
   red on a single device — see the next section but one. Tap "Einrichtung
   abschließen".
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

## Notifications are optional (Guideline 4.5.4)

This was the finding on build 42, and it was correct. That build greyed out
the "finish setup" button while the notification permission was missing, so a
reviewer who declined the system dialog could not leave the setup screen. It
is fixed, and the fix goes further than the button:

* **Nothing in the app is gated on the notification permission any more.** The
  checklist is a report, not a gate; the concept of a blocking item has been
  removed from the code entirely.
* **Consent is asked for inside the app**, in its own section headed
  "Mitteilungen — freiwillig" (notifications — optional), with a sentence
  explaining what they are for and a sentence stating that the app stays usable
  without them. The system dialog is only ever raised by an explicit tap — the
  app never prompts on its own at launch.
* **The same section is in Settings**, permanently, so somebody who declined at
  first setup can change their mind without reinstalling.
* **"Was ohne Mitteilungen geht"** is a screen that lists, item by item, what
  works and what does not.

Without notifications the app remains fully functional: raising an alarm,
seeing a running alarm, acknowledging it, the group chat during an alarm,
calling the all clear, member administration, join codes, the checklist and the
diagnostics all work. The app polls its backend every five seconds while an
alarm is running and every thirty seconds otherwise, independently of any
permission, so an open app shows an alarm within seconds either way. What is
lost is sound while the app is in the background, the ten follow-up reminders
and the local sound test — and each of those is named on that screen.

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

## What was fixed since submission 1.1.0 (42)

**Guideline 4.5.4.** Notifications are no longer required for the app to
function — see the section "Notifications are optional" above. Concretely: the
blocking mechanism behind the setup button is gone from the source, consent is
requested in a dedicated, explained section in both the setup screen and
Settings, and a screen lists what the app can and cannot do without the
permission. The app never raises the system dialog by itself.

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
