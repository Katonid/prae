# Antrag auf „Critical Alerts" bei Apple

Fertiger Text zum Einreichen. Formular:
<https://developer.apple.com/contact/request/notifications-critical-alerts-entitlement/>

## Vorweg: Wofür das ist — und wofür nicht

**Fokus ist damit nicht gemeint.** Ein aktiver Fokus („Nicht stören",
„Unterricht") wird bereits von `.timeSensitive` durchbrochen, und diese
Fähigkeit hat die App längst. Dafür ist kein Antrag nötig.

**Gemeint ist das stummgeschaltete iPad.** Steht der Schalter auf lautlos
oder die Lautstärke auf null, spielt auch eine zeitkritische Mitteilung
keinen Ton — es bleibt bei Anzeige und Vibration. Nur ein kritischer Hinweis
klingt trotzdem, und in einer selbst gewählten Lautstärke. Das ist die eine
Lücke, die sich ohne Apple nicht schließen lässt: Den Hardware-Schalter kann
kein Konfigurationsprofil übersteuern.

## Wann einreichen

**Jetzt, unabhängig von der App-Prüfung.** Beides sind getrennte Verfahren:

* Das Entitlement hängt am Entwickler-Konto und an der App-Id. Es wird über
  das Formular beantragt, nicht über App Review.
* Die App-Prüfung (auch bei einer Custom App über Apple School Manager) ist
  ein eigener Vorgang und sagt über dieses Entitlement nichts.

Der Antrag ist der lange Weg — rechne mit mehreren Wochen, manchmal ohne
Antwort, dann nachfassen. Und er muss **vor** dem Bau erledigt sein, der ihn
nutzt: Eine Entitlements-Datei, die `critical-alerts` ohne Bewilligung nennt,
lässt jedes Signieren scheitern. Nachträglich in einen bereits hochgeladenen
Bau lässt es sich also ohnehin nicht einfügen; es braucht dann einen neuen.

Bis zur Bewilligung gilt: **Lautlos-Schalter auf den Dienst-iPads auf laut.**

## Angaben zur App

| Feld | Wert |
|---|---|
| App Name | Schulalarm (im Store: `Schulalarm - Der Warnmelder`) |
| Bundle ID | `de.dboschule.alarm` |
| Team ID | `F4989GSTWS` |
| Distribution | Custom App über Apple School Manager, nicht im öffentlichen App Store |

## Der Text (englisch, zum Einfügen)

Apple liest englisch. Das Formular hat ein Freitextfeld für die Begründung —
dort gehört das Folgende hinein.

```
Schulalarm is an internal emergency notification app for the staff of a
German primary school. It is distributed as a Custom App through Apple
School Manager to roughly 30 school-owned iPads carried by teachers. It is
not, and will not be, available on the public App Store.

When a teacher raises an alarm - an intruder in the building, a fire, or a
medical emergency - every colleague's iPad must become audible within
seconds, wherever it happens to be: in a bag, on a desk in another
classroom, or lying locked on a windowsill. These teachers are responsible
for classes of six- to ten-year-old children who cannot act on their own.
The difference between hearing the alarm immediately and hearing it a minute
later is the difference between a locked classroom door and an open one.

We already use Time Sensitive notifications, and they carry the alarm
through Focus modes. They do not solve the remaining case: a school iPad
whose ring switch is set to silent or whose volume is turned down. Teachers
mute their devices during lessons as a matter of course - it is the
professionally correct thing to do - and no configuration profile can
override the hardware switch. Today that leaves a device which receives the
alarm and displays it, but makes no sound, in a room where nobody is looking
at a screen. Critical Alerts are the only mechanism that closes this gap.

Scope and restraint:

- Critical Alerts are used exclusively for a raised emergency alarm and for
  its all-clear. Nothing else in the app uses them: not the chat messages
  written during an incident, not the silent status pings, not any
  administrative notice. The app contains no marketing, engagement or
  promotional content of any kind.
- The alarm sound is 25 seconds long and does not repeat beyond that.
- Practice drills are rendered in grey and yellow and are labelled
  "PROBEALARM" (drill) in three separate places on screen, so a drill can
  never be mistaken for the real thing.
- The app does not replace the emergency services. It notifies colleagues
  inside one building; the app's own screens and its settings say so
  explicitly.
- Data minimisation: the app stores a short handle chosen by the teacher
  (for example "MU"), never a full name, and no location data, contacts or
  telephone numbers.
- Recipients grant the notification permission themselves during setup and
  can revoke it at any time in iOS Settings, exactly as with any other
  notification permission.

We are requesting the entitlement for this one app and this one closed
distribution channel.
```

## Was der Text auf Deutsch sagt

Damit klar ist, was da eingereicht wird:

1. **Was die App ist:** interne Alarm-App für das Kollegium einer deutschen
   Grundschule, rund 30 Schul-iPads, Custom App über Apple School Manager,
   nicht im öffentlichen App Store.
2. **Warum es dringend ist:** Lehrkräfte sind für Klassen von Sechs- bis
   Zehnjährigen verantwortlich, die nicht selbst handeln können. Zwischen
   „sofort gehört" und „eine Minute später gehört" liegt eine verschlossene
   und eine offene Klassentür.
3. **Warum zeitkritisch nicht reicht:** Fokus ist damit gelöst, das stumme
   iPad nicht. Lehrkräfte schalten im Unterricht stumm — zu Recht —, und
   den Hardware-Schalter kann kein Profil übersteuern.
4. **Wie zurückhaltend es eingesetzt wird:** nur für Alarm und Entwarnung,
   nicht für Chat, nicht für Pings, keine Werbung; Ton 25 Sekunden;
   Probealarme dreifach als solche gekennzeichnet; ersetzt keinen Notruf;
   nur Kürzel, keine Namen, kein Standort; jederzeit widerrufbar.

## Woran man die Bewilligung merkt

**Nicht an einer Mail.** Sie kommt oft, aber verlässlich ist sie nicht — und
eine Empfangsbestätigung schickt Apple für dieses Formular gar nicht erst
(nachgeprüft 09/2026: Vorgangsnummer auf dem Bildschirm, danach nie eine Mail,
auch nicht im Spam).

**Nachsehen lässt es sich selbst, und das ist der zuverlässige Weg:**

1. developer.apple.com → **Certificates, Identifiers & Profiles**
2. **Identifiers** → die App-Id `de.dboschule.alarm`
3. In der Liste der Capabilities nach **„Critical Alerts"** suchen.

**Steht der Eintrag dort, ist der Antrag bewilligt** — vorher taucht er gar
nicht erst auf. Das ist der Mechanismus für alle Entitlements, die Apple
einzeln freischaltet: Sie erscheinen als anhakbare Fähigkeit an der App-Id,
sobald sie dem Konto zugeteilt sind.

Derselbe Blick geht auch in Xcode: Ziel → **Signing & Capabilities** →
**+ Capability** → nach „Critical Alerts" suchen. Wird sie nicht angeboten,
ist sie nicht bewilligt.

**Kein Eintrag heißt nicht abgelehnt**, sondern nur: noch nicht bewilligt. Für
diese Anträge gibt es keine Statusseite, auf der „in Bearbeitung" stünde.

### Wenn nach sechs Wochen nichts passiert ist

* Prüfen, welche **E-Mail-Adresse am Entwickler-Konto** hinterlegt ist
  (developer.apple.com → Account → Membership). Antworten gehen dorthin und
  nicht zwangsläufig an die Adresse, die man täglich liest.
* Über dasselbe Formular noch einmal schreiben, diesmal mit der
  **Vorgangsnummer** aus dem Bildschirmfoto und dem Hinweis, dass es eine
  Nachfrage zum bestehenden Antrag ist — nicht als neuer Antrag formuliert.
* Alternativ Apple Developer Support über die Kontaktseite; dort lässt sich
  eine Vorgangsnummer nachschlagen.

**Warten blockiert nichts.** Ohne kritische Hinweise durchbricht der Alarm
weiterhin jeden Fokus, erscheint auf dem Sperrbildschirm und klingt — auf einem
Gerät, dessen Lautlos-Schalter auf laut steht. Die App geht auch so in die
Verteilung; das Entitlement kommt später mit einem neuen Bau dazu.

## Nach der Bewilligung

Drei Handgriffe, sonst nichts:

1. `com.apple.developer.usernotifications.critical-alerts` in
   `Config/Alarm.entitlements` eintragen — **nur dort**, nicht in die
   Erweiterung (die hat keine Entitlements-Datei, und das muss so bleiben).
2. `SWIFT_ACTIVE_COMPILATION_CONDITIONS` in beiden Zielen und beiden
   Konfigurationen um `CRITICAL_ALERTS` erweitern.
3. Neu bauen. Die App fragt die Berechtigung dann von selbst mit ab, die
   Prüfliste zeigt den Punkt, und Alarm, Erinnerung und Tontest schalten auf
   `.critical` um.

Der Code dafür steht fertig hinter der Compilerbedingung — drei Stellen:
`NotificationService.swift`, `AlarmReminder.swift`, `Tontest.swift` (und die
Anfrage in `NotificationCenterService.swift`).

## Falls Apple ablehnt

Dann bleibt es beim heutigen Stand, und der ist nicht schlecht: Der Alarm
durchbricht jeden Fokus, erscheint auf dem Sperrbildschirm und klingt — auf
einem iPad, das nicht stummgeschaltet ist. Die Lücke ist dann eine Frage der
Dienstanweisung („Lautlos-Schalter auf laut"), und die Geräteübersicht in der
App zeigt, welches iPad sich seit 48 Stunden nicht gemeldet hat.
