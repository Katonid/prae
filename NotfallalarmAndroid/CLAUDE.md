# Projekt Notfallalarm (Amok-/Notfallalarm, native Android-App)

> Ausgelagert aus der `CLAUDE.md` im Wurzelverzeichnis (09/2026). Die
> übergreifenden Regeln (PR-Rhythmus, iOS-Pflichten, Bau in GitHub
> Actions) stehen weiterhin dort und gelten hier genauso.


- App-Code: `NotfallalarmAndroid/` (Kotlin, Jetpack Compose, Material 3, ein
  Modul, `de.dbo.alarm`, minSdk 26). Dazu ein kleines Firebase-Backend in
  `NotfallalarmAndroid/backend/` (Firestore, Cloud Functions in TypeScript,
  anonyme Anmeldung, alles in `europe-west3`). Verteilt wird als signierte
  APK per Sideload, **nicht** über den Play Store.
- **Die erste Android-App dieses Repos.** Sie gehört NICHT in
  `.github/scripts/welche-apps.py` und nicht in `ios-apps-build.yml` — sie
  hat einen eigenen Arbeitsablauf `notfallalarm-build.yml`, der auf einem
  **Linux**-Läufer baut und damit keinen der knappen macOS-Läufer belegt.
- **Das Backend ist plattformneutral gehalten**, weil ein iOS-Pendant
  dasselbe benutzen soll. Der Vertrag steht an zwei Stellen und nur dort:
  `backend/functions/src/model.ts` und `alarm/AlarmPayload.kt`.
- **Niemals ein `notification`-Feld in einer Push-Nachricht.** Das ist die
  wichtigste Zeile des ganzen Projekts: Mit `notification` zeichnet Android
  die Meldung selbst und weckt die App gar nicht — kein Ton, kein
  Weckschloss, kein Bildschirm. Gesendet wird ausschließlich eine
  Datennachricht mit `priority: high` (das setzt die App kurz auf die
  Ausnahmeliste des Energiesparers und erlaubt erst dadurch den Start des
  Foreground Service aus dem Hintergrund) und `ttl: 120s`.
- **Der Ton läuft über `USAGE_ALARM`.** Der Alarm-Kanal ist der einzige, den
  „Lautlos" nicht stummschaltet. Derselbe Ton mit `USAGE_NOTIFICATION` wäre
  auf genau den Geräten stumm, für die die App gebaut ist. Der
  Benachrichtigungskanal selbst hat deshalb **keinen** eigenen Ton
  (`setSound(null, null)`) — sonst klänge es doppelt.
- **`foregroundServiceType="specialUse"`**, nicht `mediaPlayback`: Ab
  Android 14 braucht jeder Foreground Service einen Typ, und keiner der
  gelisteten passt. Die Begründung steht als
  `PROPERTY_SPECIAL_USE_FGS_SUBTYPE` im Manifest daneben.
- **Kein `applicationIdSuffix` für den Debug-Zweig.** `google-services.json`
  gilt für genau einen Paketnamen; mit `.debug` scheitert jeder frische Klon
  an „No matching client found", bevor jemand eine Zeile geschrieben hat.
  Fehlt die Datei ganz, kopiert der Bau `google-services.json.template`
  hinein und die App zeigt zur Laufzeit einen roten Kasten — sie übersetzt
  also immer, meldet sich aber unüberhörbar.
- **Die Alarmtöne rechnet `scripts/alarmtoene.py` aus** (reines Python, wie
  die Endklänge von Tafelbild): eigene Tonfolge je Alarmart, damit man am
  Klang hört, worum es geht. Nicht von Hand bearbeiten; der Arbeitsablauf
  prüft, dass die Dateien im Repo zum Skript passen.
- **Der QR-Rechner ist eine Portierung von `woerterwerkstatt/js/qr.js`**
  (`util/QrCode.kt`). **Nach jeder Änderung daran erst
  `./gradlew :app:testDebugUnitTest`, dann `python3 scripts/qr-pruefen.py`
  laufen lassen** — der Test schreibt die Matrizen, das Skript liest sie mit
  OpenCV zurück und vergleicht die festen Muster mit segno. Verglichen wird
  NICHT die Datenfläche: Welches Füllzeichen nach dem Abschluss steht, lässt
  der Standard offen, und daraus folgt eine andere beste Maske. Ein Code mit
  einem einzigen falsch gesetzten Modul sieht tadellos aus und wird von
  keiner Kamera gelesen.
- **Wer die Gruppe anlegt, ist ihr Admin** (`createGroup`, Ansage des
  Nutzers, 08/2026). Gruppen sind über den Einladungscode getrennt, eine
  fremd angelegte schadet also niemandem — und die Schule kann ohne
  Handgriff in der Firebase-Konsole loslegen.
- **Einladungscodes stehen doppelt im Gruppendokument**: als Objekte in
  `inviteCodes` für die Verwaltungsansicht und als reine Zeichenketten in
  `inviteCodeValues`. Firestores `array-contains` kann keine Map treffen,
  und `joinGroup` muss eine Gruppe allein am Code finden. Beide immer
  zusammen schreiben (`GroupRepository.setInviteCodes`).
- Das Codealphabet lässt I, O, 0 und 1 weg. Bei der Eingabe wird deshalb
  **nicht geraten und umgewandelt**, sondern nur großgeschrieben — dieselbe
  Regel wie beim Klassencode der Wörterwerkstatt.
- **Der Selbsttest ist echt**, keine Simulation: `selfTest` schickt eine
  Datennachricht denselben Weg wie ein echter Alarm. Ein Gerät, das hier
  stumm bleibt, wäre auch im Ernstfall stumm geblieben. Das Onboarding gilt
  erst danach als abgeschlossen.
- **Herstellereigene Ruhezustände sind nicht auslesbar** (Samsung, Xiaomi,
  Huawei, Oppo, Vivo). Die Checkliste kann sie nur erklären und, wo eine
  bekannte Activity existiert, öffnen. Diese Komponenten sind
  undokumentiert und verschwinden zwischen Firmware-Fassungen, deshalb jeder
  Sprung in `runCatching` und mit Rückfall auf die App-Detailseite. Die
  Paketnamen stehen im `<queries>`-Block des Manifests — ohne den liefert
  `resolveActivity` ab Android 11 immer `null` und jeder Knopf täte nichts.
- **Rückmeldung beendet das Signal.** „Gesehen – Klasse gesichert" und
  „Gesehen – Hilfe nötig" halten den Foreground Service an; die Vibration
  läuft sonst bis zum Deckel von zehn Minuten weiter.
- **Der Alarmbildschirm fällt auf die Push-Nutzlast zurück**, wenn das
  Firestore-Dokument (noch) nicht da ist — offline oder beim Selbsttest, der
  gar keines anlegt. Ohne diesen Rückfall zeigte er eine leere rote Fläche
  ohne Alarmart und ohne Ort.
- **Beim medizinischen Notfall steht 112 auf dem Knopf, sonst 110.** Gewählt
  wird nie selbst: `ACTION_DIAL` legt die Nummer nur ins Wählfeld, und
  `CALL_PHONE` wird bewusst nicht angefragt.
- Alarme, Rückmeldungen und Chatnachrichten löscht `cleanupOldAlarms`
  **90 Tage nach der Entwarnung**. Das sind Leistungsdaten namentlich
  genannter Kolleginnen — die Frist nicht stillschweigend verlängern.
- Oberfläche deutsch (alles in `res/values/strings.xml`), Quelltext und
  Kommentare englisch. Kein Hilt (manuelle DI in `di/ServiceLocator.kt` —
  der Graph wird zum Teil in einem `FirebaseMessagingService` gebraucht),
  kein WorkManager und kein Polling für die Zustellung.
- Ausführlich, samt Firebase-Einrichtung, Keystore und einer Seite Anleitung
  fürs Kollegium: `NotfallalarmAndroid/README.md`.
