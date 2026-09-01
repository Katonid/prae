# Notfallalarm (Android)

Notfall- und Amokalarm für das Kollegium einer Grundschule. Native Android-App
(Kotlin, Jetpack Compose, Material 3) mit einem kleinen Firebase-Backend
(Firestore, Cloud Functions, Anonymous Auth). Verteilt wird als signierte APK
per Sideload, nicht über den Play Store.

Der Backend-Vertrag ist plattformneutral gehalten (`backend/functions/src/model.ts`,
`app/src/main/java/de/dbo/alarm/alarm/AlarmPayload.kt`), damit ein späteres
iOS-Pendant dasselbe Backend benutzen kann.

---

## Was die App kann

- **Alarm auslösen** — jedes Mitglied, mit Alarmart, Standort und fünf Sekunden
  Countdown zum Abbrechen. Probealarme nur die Verwaltung.
- **Alarm empfangen**, auch wenn das Handy lautlos ist, „Nicht stören" an ist,
  der Bildschirm aus ist und die App seit Stunden geschlossen war.
- **Rückmelden** — „Klasse gesichert", „Hilfe nötig", Notruf wählen; dazu ein
  einfacher Textchat zum Alarm.
- **Entwarnung** durch die Verwaltung oder die auslösende Person.
- **Bereitschaft prüfen** — eine Checkliste, die jede nötige Freigabe zeigt und
  direkt an die richtige Systemeinstellung führt, mit Selbsttest zum Schluss.
- **Verwaltung** — Geräteübersicht mit letzter Meldung und Freigabestand,
  Einladungscodes (auch als QR), Standorte, Handlungstexte, Alarm-Historie.

---

## 1. Firebase einrichten

Einmalig, dauert etwa zwanzig Minuten.

1. **Projekt anlegen** auf <https://console.firebase.google.com> (ohne Analytics).
2. **Firestore anlegen**: Build → Firestore Database → Create database →
   **Standort `eur3` oder `europe-west3`** → im Produktionsmodus starten.
   Der Standort lässt sich später nicht mehr ändern.
3. **Anonyme Anmeldung einschalten**: Build → Authentication → Sign-in method →
   „Anonymous" aktivieren. Ohne diesen Schritt kommt niemand in die App.
4. **Android-App registrieren**: Projektübersicht → Symbol Android.
   - Paketname: `de.dbo.alarm` (genau so, ohne Zusatz)
   - `google-services.json` herunterladen und nach
     **`app/google-services.json`** legen. Die Datei liegt nicht im Git; ohne
     sie kopiert der Build die Platzhalter-Vorlage hinein und die App zeigt
     beim Start einen roten Kasten „Firebase ist nicht eingerichtet".
5. **Blaze-Tarif** aktivieren. Cloud Functions gibt es nur dort. Für dreißig
   Geräte und ein paar Alarme im Jahr bleibt die Rechnung im Rahmen des
   kostenlosen Kontingents; ein Ausgabenlimit lässt sich in der Google-Cloud-
   Konsole hinterlegen.

### Regeln und Functions ausrollen

```bash
cd backend
cp .firebaserc.example .firebaserc      # und die Projekt-ID eintragen
npm --prefix functions install
npx firebase-tools login
npx firebase-tools deploy --only firestore:rules,firestore:indexes,functions
```

Alle Functions laufen in **`europe-west3`** (Frankfurt), zusammen mit Firestore.

### `config/android` anlegen (für die Update-Meldung)

Von Hand in der Firestore-Konsole, Sammlung `config`, Dokument-ID `android`:

| Feld                | Typ    | Beispiel                                        |
|---------------------|--------|-------------------------------------------------|
| `latestVersionCode` | number | `2`                                             |
| `latestVersionName` | string | `1.0.1`                                         |
| `apkUrl`            | string | `https://…/notfallalarm-1.0.1.apk`              |
| `releaseNotes`      | string | `Alarmton lauter, Checkliste erweitert`         |

Steht dort eine höhere `latestVersionCode` als die installierte, zeigt die App
beim Start ein Banner mit den Release-Notes und einem Knopf zum Herunterladen.
Die Verwaltung sieht in der Geräteübersicht, wer noch eine alte Fassung hat.

---

## 2. Erste Gruppe anlegen

In der App: **„Gruppe anlegen"** → Name der Schule und eigener Anzeigename.
Wer die Gruppe anlegt, wird ihr Admin und bekommt sofort einen Einladungscode.
Weitere Codes und weitere Admins gibt es danach unter **Verwaltung**.

Gruppen sind über den Einladungscode voneinander getrennt — eine fremd
angelegte Gruppe sieht von Ihrer nichts. Ein Admin kann jedes Mitglied zum
Admin machen; die letzte Adminrolle lässt sich nicht entziehen.

---

## 3. Keystore anlegen und Release bauen

Der Signaturschlüssel gehört **nicht** ins Git. Geht er verloren, lässt sich
keine Aktualisierung mehr über die alte Installation legen — bewahren Sie ihn
und das Kennwort getrennt auf.

```bash
keytool -genkeypair -v -keystore notfallalarm.jks -alias notfallalarm \
        -keyalg RSA -keysize 4096 -validity 10000

cp keystore.properties.example keystore.properties   # und ausfüllen
./gradlew assembleRelease
```

Ergebnis: `app/build/outputs/apk/release/app-release.apk` — installierbar und
signiert. Ohne `keystore.properties` baut der Release-Zweig unsigniert; das ist
Absicht, damit ein frischer Klon trotzdem übersetzt.

Vor jeder neuen Fassung `versionCode` **und** `versionName` in
`app/build.gradle.kts` hochsetzen. Android nimmt keine Aktualisierung an, deren
`versionCode` nicht höher ist.

### Debug-Bau und Prüfungen

```bash
./gradlew assembleDebug
./gradlew testDebugUnitTest        # unter anderem der QR-Rechner
python3 scripts/alarmtoene.py      # Alarmtöne neu erzeugen
python3 scripts/toene-pruefen.py   # Töne gegen das Skript prüfen
python3 scripts/qr-pruefen.py      # QR gegen segno und OpenCV gegenprüfen
```

`scripts/qr-pruefen.py` braucht `pip install segno opencv-python-headless numpy`
— beides nur zum Prüfen, nichts davon steckt in der App. **Nach jeder Änderung
an `util/QrCode.kt` laufen lassen:** Ein QR-Code, bei dem ein einziges Modul
falsch sitzt, sieht tadellos aus und wird von keiner Kamera gelesen.

---

## 4. Warum der Alarm ankommt (und was ihn aufhält)

Der Zustellweg ist der Kern dieser App, deshalb hier in einem Absatz:

Die Cloud Function schickt eine **reine Datennachricht** mit hoher Priorität —
niemals ein `notification`-Feld. Mit einem `notification`-Feld würde Android die
Meldung selbst zeichnen und die App gar nicht erst wecken; kein Ton, kein
Weckschloss, kein Bildschirm. Die hohe Priorität setzt die App kurzzeitig auf
die Ausnahmeliste des Energiesparers, und nur deshalb darf sie aus dem
Hintergrund heraus ihren **Foreground Service** starten. Der spielt den Ton über
`USAGE_ALARM` — der Alarm-Kanal ist der einzige, den „Lautlos" nicht
stummschaltet —, hebt bei erteiltem Zugriff kurz „Nicht stören" an und zeigt
eine **Full-Screen-Intent-Meldung**, die den Bildschirm einschaltet.

Was das kaputt macht, in dieser Reihenfolge:

1. **Akku-Optimierung an** — Android legt die App schlafen, der Alarm kommt
   verspätet oder gar nicht.
2. **Vollbild-Benachrichtigung nicht erlaubt** (Android 14+) — es gibt nur noch
   eine Zeile oben statt eines Alarmbildschirms. Ton und Meldung kommen
   trotzdem.
3. **Herstellereigene Ruhezustände** (Samsung, Xiaomi, Huawei, Oppo, Vivo …) —
   die schlimmste Sorte, weil kein API sie meldet. Die Checkliste erklärt sie
   und öffnet, wo möglich, die richtige Einstellung.

Genau deshalb endet das Onboarding mit einem **Selbsttest**: Er nimmt denselben
Weg wie ein echter Alarm. Kommt er nicht an, wäre auch der echte nicht
angekommen.

---

## 5. Datenschutz

Gespeichert wird nur, was für Zustellung und Rückmeldung nötig ist:
Anzeigename, FCM-Token, Gerätemodell, App-Fassung, Freigabestand sowie Alarme
und Rückmeldungen. **Kein Standort-Tracking, keine Kontakte, keine
Telefonnummern, keine E-Mail-Adressen.** Angemeldet wird anonym.

Alarme, Rückmeldungen und Chatnachrichten löscht eine geplante Function
**90 Tage nach der Entwarnung** (`cleanupOldAlarms`). Das sind Leistungsdaten
namentlich genannter Kolleginnen und Kollegen — die Frist nicht stillschweigend
verlängern.

---

## 6. Aufbau des Quelltextes

```
app/src/main/java/de/dbo/alarm/
  alarm/        Zustellweg: FCM-Dienst, Foreground Service, Ton/Vibration, Meldungen
  data/         Firestore- und Functions-Zugriff, DataStore
  permissions/  Freigaben lesen, Herstellerhinweise
  ui/           Compose-Oberfläche (Setup, Home, Auslösen, Alarm, Checkliste, Verwaltung)
  util/         QR-Rechner, Zeitformate
backend/
  firestore.rules       Zugriffsregeln
  functions/src/        createGroup, joinGroup, triggerAlarm, clearAlarm, ping,
                        selfTest, nightlyPing, cleanupOldAlarms
scripts/
  alarmtoene.py         erzeugt die WAV-Dateien in res/raw
  toene-pruefen.py      prüft, ob die WAV-Dateien noch zum Skript passen
  qr-pruefen.py         prüft den QR-Rechner gegen segno und OpenCV
```

Die Oberfläche ist deutsch (alles in `res/values/strings.xml`), Quelltext und
Kommentare sind englisch.

Bewusst nicht benutzt: Hilt (der Graph ist sechs Objekte groß und wird zum Teil
in einem `FirebaseMessagingService` gebraucht — manuelle DI in
`di/ServiceLocator.kt` ist dort schlicht einfacher), WorkManager und Polling für
die Zustellung (beides zu langsam und zu unzuverlässig für einen Alarm), sowie
jede Bibliothek über Firebase, AndroidX und Compose hinaus.

---

## Anleitung für das Kollegium

*Diese Seite ausdrucken und mit der APK weitergeben.*

### Installieren

1. Die Datei **`notfallalarm.apk`** über den Link herunterladen, den Sie von der
   Schulleitung bekommen haben.
2. Auf die heruntergeladene Datei tippen. Android fragt: *„Aus dieser Quelle
   dürfen keine unbekannten Apps installiert werden."* → **Einstellungen** →
   Schalter für Ihren Browser (oder die Dateien-App) **einschalten** → zurück.
3. **Installieren** antippen.
4. Kommt der Hinweis *„Play Protect kennt diese App nicht"* oder *„Unsichere
   App blockiert"*: **Trotzdem installieren** wählen. Das ist normal — die App
   wird nicht über den Play Store verteilt, weil sie nur für unsere Schule
   gedacht ist.

### Einrichten

5. App öffnen → **Beitreten** → Ihren Namen (oder Ihr Kürzel) eintragen und den
   **sechsstelligen Code** von der Schulleitung eingeben.
6. Danach kommt die **Checkliste**. Bitte jeden roten Punkt antippen und die
   Freigabe erteilen — die App springt jeweils direkt an die richtige Stelle:
   - **Benachrichtigungen** — ohne die sehen Sie gar nichts.
   - **Vollbild-Benachrichtigungen** — dafür geht der Bildschirm bei einem Alarm
     von selbst an.
   - **Akku-Optimierung ausschalten** — sonst legt Android die App nach ein paar
     Stunden schlafen und der Alarm kommt zu spät.
   - **„Nicht stören"-Zugriff** — empfohlen, damit der Ton auch nachts kommt.
   - Steht dort ein Hinweis zu **Ihrem Gerätehersteller** (Samsung, Xiaomi,
     Huawei, Oppo, Vivo): bitte auch den erledigen. Diese Hersteller legen Apps
     eigenmächtig schlafen.
7. Zum Schluss **„Selbsttest starten"**. Ihr Handy muss daraufhin selbst einen
   Probealarm auslösen — mit Ton und Bildschirm. **Erst dann sind Sie
   erreichbar.** Passiert nichts, gehen Sie die Punkte oben noch einmal durch.

### Im Alarmfall

- **Alarm auslösen:** App öffnen → großer roter Knopf → Alarmart → Standort →
  fünf Sekunden Countdown. Bis dahin können Sie jederzeit **abbrechen**.
- **Alarm empfangen:** Der Bildschirm geht an, es klingelt und vibriert. Auf dem
  Bildschirm stehen Alarmart, wer ausgelöst hat, wo, und was zu tun ist.
- **Bitte zurückmelden** — ein Tipp auf **„Gesehen – Klasse gesichert"** oder
  **„Gesehen – Hilfe nötig"**. Die Schulleitung sieht sofort, wer noch fehlt.
- **Notruf 110** liegt als Knopf darunter; die Nummer ist vorgewählt, gewählt
  wird von Hand.
- Der Ton hört nach zwanzig Sekunden von selbst auf, die Vibration wiederholt
  sich, bis Sie bestätigen. **„Ton aus"** schaltet ihn sofort ab, der Alarm läuft
  weiter.

### Gut zu wissen

- Die App braucht **keinen Standort und keine Telefonnummer** und sieht Ihre
  Kontakte nicht.
- Ein **Probealarm** ist grau und deutlich als „PROBEALARM" beschriftet.
- Wenn Sie ein neues Handy haben: App installieren, neuen Einladungscode bei der
  Schulleitung holen, Checkliste noch einmal durchgehen.
