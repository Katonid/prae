# Schulalarm

Notfall- und Amokalarm für das Kollegium einer Grundschule. Eine Lehrkraft
löst aus, alle Dienst-iPads werden binnen Sekunden laut, jede meldet mit
einem Fingertipp zurück, ob ihre Klasse gesichert ist oder Hilfe braucht.

Native iOS-/iPadOS-App, SwiftUI, iOS 16 aufwärts, **keine fremden
Abhängigkeiten** — nur CloudKit, UserNotifications, AVFoundation und
BackgroundTasks. Verteilt als Custom App über Apple School Manager und Jamf
School.

> **Diese App ersetzt keinen Notruf.** 110 und 112 bleiben der Weg nach
> draußen. Sie verständigt ausschließlich das Kollegium im eigenen Haus.

---

## Was schon steht und was noch offen ist

**Gebaut und übersetzt:** die vollständige App — Beitritt, Auslösen mit
Countdown, Alarm-Bildschirm, Rückmeldungen, Chat, Entwarnung, Erinnerungen,
Prüfliste, Selbsttest, Geräteübersicht, Verwaltung, Aufräumen, zweiter
Bildschirm.

**Noch offen: der Zustellnachweis.** Ob der Alarm auf einem gesperrten iPad
mit aktivem Fokus binnen zehn Sekunden hörbar ankommt, lässt sich nur auf
zwei echten Geräten mit angemeldeter Apple-ID messen — nicht im Simulator
und nicht in GitHub Actions. Das Messprotokoll steht in
`docs/ZUSTELLTEST.md`, samt der Frage, wann der Ansatz zu verwerfen wäre und
was dann an seine Stelle tritt.

Das ist der wichtigste offene Punkt des Projekts. Alles andere hängt daran.

---

## Der erste Start

Eine Person richtet die Schule ein, alle anderen treten bei.

1. **Eine Person** öffnet die App, wählt oben „Schule einrichten", trägt
   Schulnamen und ihr Kürzel ein und tippt auf „Schule einrichten und Leitung
   werden". Sie ist damit die Leitung.
2. Der **Beitrittscode** erscheint sofort danach als Zahl und als QR-Code.
   Wiederzufinden unter Verwaltung → Beitrittscodes.
3. **Alle anderen** öffnen die App, bleiben auf „Beitreten", tragen ihr
   Kürzel ein und tippen oder scannen den Code.
4. Jedes Gerät geht die Prüfliste durch und macht den **Tontest** (ohne
   Netz). Danach lässt sich die Einrichtung abschließen.
5. Den **Zustellnachweis** erbringt ein zweites Gerät: Die Leitung schickt
   aus Verwaltung → Mitglieder einen Testalarm an das iPad; dort setzt sich
   der Haken von selbst. Bis dahin steht auf dem Startbildschirm ein
   Warnband — das iPad läuft, gilt aber nicht als geprüft.

**Für das iPad der Leitung selbst braucht es eine zweite Leitung.** Unter
Verwaltung → Mitglieder eine zweite Person dazu machen; sie schickt den
Testalarm zurück.

**Was ein zweites Gerät braucht, hält den ersten Start nicht auf.** Der
Zustellnachweis war bis 1.0.9 Bedingung für „Einrichtung abschließen" — und
damit zirkulär: Der Nachweis braucht einen Push von einem anderen Gerät, den
schickt die Leitung aus der Verwaltung, die Verwaltung liegt hinter dem
Startbildschirm. Niemand kam mehr hinein.

Kommt der Code über Jamf School mit der App mit
(`docs/MDM_APPCONFIG.md`), entfällt Schritt 3 bis auf das Kürzel.

**Nur eine Person darf einrichten.** Richtet eine zweite noch einmal ein,
entsteht ein zweiter, getrennter Alarmkreis — die beiden sehen einander
nicht, und im Ernstfall wird nur die halbe Schule laut.

**Mindestens zwei Personen sollten die Leitung haben.** Verwaltung →
Mitglieder → „Zur Leitung machen". Eine einzige Leitung ist ein
Ausfallpunkt: Wird dieses iPad zurückgesetzt, kann niemand mehr Codes
vergeben oder Entwarnung geben.

## Wenn nichts ankommt

Zwei Tests, und sie prüfen zwei verschiedene Dinge:

| Test | Beweist | Braucht |
|---|---|---|
| **Tontest** | Dieses iPad darf laut werden (Erlaubnis, Ton, Fokus, Lautlos-Schalter, Sperrbildschirm) | nichts |
| **Zustelltest** | Ein Alarm kommt über iCloud an | ein ZWEITES Gerät |

Zuerst der Tontest. Klingt er nicht, ist über die Zustellung noch gar nicht
nachzudenken — dann liegt es am Gerät, und die Prüfliste sagt woran.

Kommt die Mitteilung, bleibt aber stumm, grenzen zwei Knöpfe die Ursache ein:

* **„Ton direkt abspielen"** spielt die Datei an den Mitteilungen vorbei und
  auch bei stummem Gerät. Hörbar heißt: die Datei ist in Ordnung.
* **„Tontest mit Standardton"** schickt dieselbe Mitteilung mit dem
  System-Ton. Hörst du **diesen**, aber nicht den Alarmton, liegt es doch an
  der Datei. Sind **beide** stumm, liegt es am Gerät.

Am Gerät kommen dann drei Dinge in Frage, nach Häufigkeit:

1. **Klingeltonlautstärke** — und die ist **nicht** die Medienlautstärke.
   Die Lautstärketasten regeln die Medien, solange etwas spielt; genau das
   tut „Ton direkt abspielen". Drücke die Tasten, wenn nichts läuft, oder
   stelle sie unter Einstellungen → Töne & Haptik.
2. **Eine gekoppelte Apple Watch.** Wird sie getragen, leitet iOS die
   Mitteilung ans Handgelenk und das iPhone bleibt still — und die Uhr
   spielt nie den eigenen Ton einer App, sondern ihren Systemton. Auf einem
   iPhone mit Uhr lässt sich der Alarmton nicht prüfen. Nimm ein iPad.
3. **Lautlos-Schalter.** Ohne die Berechtigung für kritische Hinweise macht
   auch eine zeitkritische Meldung bei stummem Gerät keinen Ton.

**Den Zustelltest kann ein Gerät nicht allein machen.** CloudKit stellt
einem Gerät keine Meldung zu einem Datensatz zu, den es selbst geschrieben
hat. Die Leitung schickt den Testalarm deshalb aus ihrer App an ein
bestimmtes Mitglied (Verwaltung → Mitglieder → „Testalarm senden"); auf
dessen iPad setzt sich der Haken „Zustellung geprüft" von selbst, sobald der
Push eintrifft. Ein Knopf, der auf einem einzelnen Gerät nie funktionieren
könnte, steht deshalb nicht mehr in der App.

Kommt nichts an, führt **Einstellungen → Zustellung prüfen** die Kette
einzeln vor: Konto, je eine Probeabfrage pro
Record-Typ, jede der vier Subscriptions, die APNs-Anmeldung, der letzte
angekommene Push — und ob der Alarmton überhaupt im App-Bündel liegt. Das
erste rote Kreuz ist die Ursache. Der Befund lässt sich kopieren.

Der häufigste Befund auf einem frischen Container ist „Field … is not marked
queryable" — dann fehlen die Indizes; siehe „CloudKit einrichten" weiter
unten. Die App kann das nicht selbst richten, ein Index ist keine Sache der
App.

## Rückmeldung und Entwarnung sind zweierlei

„Gesehen – Klasse gesichert" heißt **ich weiß Bescheid**, nicht **es ist
vorbei**. Ein Alarm läuft weiter, bis die Leitung (oder die auslösende
Person) Entwarnung gibt. Das ist Absicht: Wer im Klassenraum sitzt, kann
nicht beurteilen, ob die Lage im Haus vorbei ist.

Genau eine Ausnahme: der **gezielte Probealarm** des Zustelltests. Der räumt
sich mit der Rückmeldung selbst weg und verfällt ohnehin nach zehn Minuten.
Ohne das bliebe jeder Test für immer „aktiv", und ein Stapel alter Tests
würde der Reihe nach zum laufenden Alarm — das iPad klingelte dann immer
wieder.

Staut sich doch etwas auf: **Verwaltung → Nachbereitung → „Alle laufenden
Alarme beenden"**.

## Der Aufbau in einem Absatz

Alles, was mit einer Gegenstelle spricht, liegt hinter **einem** Protokoll:
`Alarm/Backend/AlarmBackend.swift`. Es gibt zwei Umsetzungen — `CloudKitBackend`
und `MockBackend` — und in keiner Signatur des Protokolls steht ein
CloudKit-Typ. Views und Services kennen nur `any AlarmBackend`.

Das ist keine Architektur-Kür, sondern Vorbereitung: **CloudKit stellt an
Apple-Geräte zu und an sonst nichts.** Sobald Android dazukommt, wird eine
zweite Umsetzung gebraucht, und dann soll das eine Datei kosten und nicht
den Umbau der Oberfläche. Wie das geht, steht in `docs/BACKEND_MIGRATION.md`.

```
AlarmiOS/
  Shared/            in BEIDEN Zielen: Domäne, Push-Vertrag, Parser, Töne
  Alarm/             die App
    Backend/         Protokoll, Modelle, CloudKit/, Mock/
    Services/        Mitteilungen, Erinnerungen, MDM-Konfiguration, Prüfliste
    Views/           Oberfläche — importiert NIE CloudKit
  NotificationService/  die Erweiterung, die den Alarm laut macht
  Config/            Info.plists und Entitlements
  docs/              siehe unten
  scripts/           Töne und App-Symbol, beide gerechnet statt geladen
```

**Die Regel, die das zusammenhält:** CloudKit-Typen kommen nur in
`Alarm/Backend/CloudKit/` vor. Wer sie aufweicht, macht aus einem Dateitausch
einen Umbau.

---

## Warum es die Notification Service Extension gibt

Sie ist nicht optional, und das ist der wichtigste technische Satz dieses
Papiers.

Eine CloudKit-Subscription kann vieles mitgeben — Titel, Ton, Kategorie,
Datenfelder —, aber sie kann `interruptionLevel` nicht setzen. Ohne dieses
Feld bleibt die Mitteilung auf `.active`, und ein aktiver Fokus („Nicht
stören", „Unterricht") hält sie zurück. Der Alarm käme also an und wäre
trotzdem nicht zu hören.

Die Erweiterung bekommt jede Mitteilung, weil in der Subscription
`shouldSendMutableContent` steht, und setzt `.timeSensitive`. Sie baut
außerdem Titel und Text aus den mitgelieferten Feldern und schreibt
`userInfo` ins neutrale Format um (`docs/PUSH_CONTRACT.md`).

**Sie verwirft nichts.** Kann sie ein Paket nicht lesen, geht die Mitteilung
trotzdem hinaus, mit dem Grund im Text. Ein stillschweigend verschluckter
Alarm ist der schlimmste denkbare Fehler dieser App.

---

## Ehrlich zur Absicherung

CloudKits öffentliche Datenbank kennt zwei Rechtestufen: „irgendein
angemeldeter iCloud-Nutzer" und „Ersteller dieses Datensatzes". Sie kann
**nicht** „nur Mitglieder dieser Gruppe".

Das heißt im Klartext: Wer den sechsstelligen Beitrittscode hat und eine
Apple-ID besitzt, kann in dieser Gruppe schreiben — auch einen Alarm
auslösen. Die Schutzwirkung kommt aus zwei anderen Richtungen:

* **Die App wird nur an Schul-iPads verteilt.** Custom App über Apple School
  Manager, nicht im öffentlichen App Store zu finden.
* **Datensparsamkeit.** Gespeichert wird ein Kürzel („MÜ", „Kl. 3b"), kein
  voller Name, keine Anschrift, keine Telefonnummer.

Auch die Rollen sind so zu lesen: Dass nur die Leitung einen Probealarm
auslöst oder Codes vergibt, prüft die App — nicht die Datenbank. Für ein
Kollegium von 30 Personen ist das angemessen. Wer eine echte Durchsetzung
braucht, braucht einen Server; siehe `docs/BACKEND_MIGRATION.md`.

---

## CloudKit einrichten

Container: `iCloud.de.dboschule.alarm`, **öffentliche** Datenbank.

### 1. Schema anlegen

Beim ersten Lauf gegen *Development* legt CloudKit die Record-Typen aus den
geschriebenen Datensätzen selbst an. Der schnellste Weg dorthin: App aus
Xcode auf ein Gerät, Gruppe anlegen, einen Probealarm auslösen, einmal
zurückmelden, eine Nachricht schreiben, „Alle pingen".

Record-Typen: `Group`, `InviteCode`, `Member`, `Alarm`, `Ack`, `Message`,
`DeviceStatus`, `Ping`. Alle tragen `groupRef`.

### 2. Indizes setzen (CloudKit-Konsole → Indexes)

Ohne sie scheitert jede Abfrage mit „Field … is not marked queryable". Das
ist der häufigste Stolperstein beim ersten Aufsetzen.

| Record-Typ | Feld | Index |
|---|---|---|
| alle acht | `recordName` | Queryable |
| `Group`, `InviteCode`, `Member`, `Alarm`, `Ack`, `Message`, `DeviceStatus`, `Ping` | `groupRef` | Queryable |
| `Alarm` | `status`, `targetUser` | Queryable |
| `Ack`, `Message` | `alarmRef` | Queryable |
| `Ping` | `targetUser` | Queryable |

**Kein SORTABLE-Index nötig.** Sortiert wird in der App, nicht auf dem
Server. Ein `NSSortDescriptor` auf `creationDate` verlangte einen
SORTABLE-Index auf `___createTime`, und fehlte der, lehnte CloudKit die
Abfrage ab — getroffen hätte es ausgerechnet die Suche nach dem laufenden
Alarm, also das Auslösen und das Nachfassen (gemeldet 09/2026). Die
wichtigste Abfrage dieser App darf nicht an einem Häkchen in einer
Web-Oberfläche hängen.

Sortiert wird trotzdem nach dem **Systemzeitstempel** und nicht nach dem
eigenen `createdAt`-Feld: Den setzt der Server, ein Gerät mit falscher Uhr
kann ihn nicht verbiegen. Nur das Sortieren selbst passiert in der App.

### 3. Sicherheitsrolle

`_icloud` (angemeldete Nutzer) braucht auf allen acht Record-Typen **Read,
Write und Create**. Ohne Write kann eine zweite Leitung die Standorte nicht
pflegen, die eine andere angelegt hat.

### 4. Ins Production-Environment übernehmen

CloudKit-Konsole → **Deploy Schema Changes to Production**. Ohne diesen
Schritt läuft die App aus TestFlight oder als Custom App gegen ein leeres
Schema und meldet lauter „unknown record type" — obwohl in Development alles
steht.

> **Development und Production sind getrennte Welten.** Über Xcode
> installiert läuft die App gegen *Development*, über TestFlight und Custom
> App gegen *Production* — mit getrennten Daten und getrennten
> Konto-Kennungen. Ein Testgerät aus Xcode sieht die Alarme der anderen nie.
> Die App zeigt unter Einstellungen → Dieses Gerät, welche gerade gilt.

---

## Capabilities im Xcode-Projekt

| Capability | Wozu |
|---|---|
| Push Notifications | die Zustellung überhaupt |
| Time Sensitive Notifications | durch den Fokus hindurch |
| Background Modes → Remote notifications | der stille Ping |
| Background Modes → Background fetch | `BGAppRefreshTask` frischt den eigenen Gerätestatus auf |
| iCloud → CloudKit | Daten und Zustellung |

**Alle fünf gehören an das APP-Ziel. Die Erweiterung bekommt gar keine
Entitlements-Datei.**

Das war zuerst anders und ließ das Signieren scheitern:

> Entitlement `com.apple.developer.usernotifications.time-sensitive` not
> found and could not be included in profile. This likely is not a valid
> entitlement and should be removed from your entitlements file.

„Time Sensitive Notifications" ist eine Fähigkeit, die es nur für eine App-Id
gibt, nicht für die einer Erweiterung — Xcode bietet sie dort auch gar nicht
zum Hinzufügen an. Steht sie trotzdem in der Entitlements-Datei der
Erweiterung, findet die automatische Signierung kein passendes Profil und
bricht ab.

Gebraucht wird sie dort auch nicht: Die Mitteilung gehört der App, und iOS
prüft die Berechtigung an ihr. Die Erweiterung setzt nur den Wert; dass er
gilt, entscheidet das Entitlement des App-Ziels.

## Kritische Hinweise (Critical Alerts)

`.critical` ist die einzige Stufe, die auch bei stummgeschaltetem iPad Ton
macht. Das Entitlement dafür vergibt Apple **nur auf schriftlichen Antrag**:
<https://developer.apple.com/contact/request/notifications-critical-alerts-entitlement/>

**Der fertige Antragstext steht in `docs/CRITICAL_ALERTS_ANTRAG.md`** — samt
den Angaben zur App, einer deutschen Zusammenfassung dessen, was da
eingereicht wird, und den drei Handgriffen nach der Bewilligung.

Der Antrag läuft **unabhängig von der App-Prüfung** und sollte früh raus: Er
hängt am Entwickler-Konto und an der App-Id, nicht an App Review, und er ist
der lange Weg.

Zu begründen ist, warum eine Verzögerung Menschen gefährdet — bei einem
Amokalarm in einer Grundschule ist das kein rhetorischer Satz. Rechne mit
mehreren Wochen.

Bis dahin ist der Zweig **aus**. Der Code steht schon da, hinter der
Compilerbedingung `CRITICAL_ALERTS`; er ist in
`NotificationService.swift`, `AlarmReminder.swift` und
`NotificationCenterService.swift` je einmal zu finden. Nach der Bewilligung:

1. `com.apple.developer.usernotifications.critical-alerts` in **beide**
   Entitlements-Dateien.
2. `SWIFT_ACTIVE_COMPILATION_CONDITIONS` um `CRITICAL_ALERTS` erweitern, in
   beiden Zielen und beiden Konfigurationen.
3. Die Prüfliste in der App zeigt den Punkt dann von selbst mit an.

**Nicht vorher eintragen.** Ein Entitlement ohne Bewilligung lässt jedes
Signieren scheitern.

---

## Bauen

```
xcodebuild build \
  -project AlarmiOS/Alarm.xcodeproj \
  -scheme Alarm \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO
```

Genau das macht auch `.github/workflows/ios-apps-build.yml` bei jedem Push
auf `AlarmiOS/`.

Töne und App-Symbol werden **gerechnet, nicht geladen** — reines Python,
ohne fremde Bibliotheken, ohne Netz:

```
python3 AlarmiOS/scripts/make-sounds.py    # alarm.wav (25 s), allclear.wav (3 s)
python3 AlarmiOS/scripts/make-icon.py      # AppIcon.png (1024 × 1024)
```

Beide Töne liegen in `Shared/Sounds/` und sind Ressource **beider** Ziele.
Über 30 Sekunden spielt iOS einen Mitteilungston gar nicht ab; das Skript
bricht vorher ab, damit der Fehler beim Erzeugen auffällt und nicht auf dem
Gerät.

## Versionierung

`MARKETING_VERSION` und `CURRENT_PROJECT_VERSION` stehen an **vier** Stellen
im pbxproj (App Debug+Release, Erweiterung Debug+Release) und müssen überall
gleich sein — eine Erweiterung mit abweichender Version lehnt App Store
Connect ab. Es gibt keine Skript-Bauphase; beide Werte werden im Repo
gepflegt.

Jede Arbeitseinheit hebt Patch- und Build-Nummer um je eins: 1.0.0 (Build 1),
dann 1.0.1 (Build 2), …

`ITSAppUsesNonExemptEncryption = NO` steht in beiden Info.plists und als
Build-Einstellung — nicht entfernen, es erspart die Export-Compliance-Frage
bei jedem TestFlight-Build.

---

## Datenschutz

Gespeichert werden: Kürzel/Anzeigename, CloudKit-Nutzerkennung, Gerätemodell,
App-Version, Berechtigungsstatus, iCloud-Status, die Alarme selbst, die
Rückmeldungen und die während eines Alarms geschriebenen Nachrichten.

**Nicht** gespeichert: Standort, Kontakte, Telefonnummern, Fotos, irgendeine
Art von Nutzungsstatistik. Es gibt kein Analytics, kein Tracking und kein
fremdes SDK — siehe `Alarm/PrivacyInfo.xcprivacy`.

Die Kamera wird an genau einer Stelle gebraucht: beim Scannen des
Beitrittscodes. Es wird nichts aufgenommen.

Alarme, Rückmeldungen und Nachrichten sind Leistungs- und Verhaltensdaten
benannter Personen. Sie werden nach **90 Tagen gelöscht** — von Hand über
Verwaltung → Aufräumen und automatisch bei jedem Start einer Leitungs-App.
Weil es keinen Servercode gibt, heißt das auch: Öffnet ein halbes Jahr lang
niemand aus der Leitung die App, wird nicht aufgeräumt.

---

## Der zweite Bildschirm

Hängt ein Beamer oder Apple TV am iPad, zeigt die App dort ein **neutrales
Bild** — nie den Alarm. Sonst erführe die Klasse die Bedrohungslage vor der
Kollegin nebenan.

Was die App nicht kontrollieren kann: das System-Banner, bevor jemand die App
öffnet. Das zeichnet iOS, und iOS spiegelt es mit. Ob die Vorschau auf dem
Sperrbildschirm den Alarmtext zeigen darf oder nur „Schulalarm", ist deshalb
eine Entscheidung des Krisenteams und wird im Konfigurationsprofil
eingestellt — siehe `docs/VERTEILUNG_JAMF_SCHOOL.md`.

---

## Die Papiere

| Datei | Wofür |
|---|---|
| `docs/ZUSTELLTEST.md` | **Das Messprotokoll für den offenen Nachweis.** Zuerst lesen. |
| `docs/PUSH_CONTRACT.md` | Das Push-Format, das jede künftige Gegenstelle erzeugen muss |
| `docs/BACKEND_MIGRATION.md` | Was ein zweites Backend liefern muss; was CloudKit prinzipbedingt nicht kann |
| `docs/MDM_APPCONFIG.md` | Die fertige plist für Jamf School |
| `docs/VERTEILUNG_JAMF_SCHOOL.md` | Für die Jamf-Administration, Schritt für Schritt |
| `docs/APP_REVIEW_NOTES.md` | Text für App Store Connect (englisch) |
| `docs/CRITICAL_ALERTS_ANTRAG.md` | Fertiger Antragstext für kritische Hinweise |
