# Arbeitsweise in diesem Repo

## Pull Requests & Merges

Wenn eine Arbeitseinheit fertig und auf den Arbeitsbranch gepusht ist:

1. **Immer direkt einen Pull Request nach `main` anlegen** (nicht nur den
   „pull/new"-Vergleichslink nennen).
2. Dem Nutzer den **direkten PR-Link** geben und in einem Satz erklären:
   grüner Knopf „Merge pull request" → „Confirm merge".

Hintergrund: Der Nutzer möchte sich keine GitHub-Schritte merken müssen.
Der Merge selbst bleibt immer beim Nutzer — nie selbst mergen.

## Merge-Rhythmus (kein Nachschieben — Race-Vermeidung)

Es kam mehrfach vor, dass der Nutzer einen PR mergte, während danach
noch Commits auf denselben PR gepusht wurden — die hingen dann fest
(ein gemergter PR nimmt nichts mehr an). Deshalb verbindlich:

- **Sobald ein PR-Link an den Nutzer herausgegeben wurde, ist dieser PR
  eingefroren** — es werden keine weiteren Commits darauf gepusht.
- Jede weitere Arbeit (auch kleine Nachzügler/Fixes) beginnt mit
  `git fetch origin main` + Rebase und endet mit einem **neuen** PR
  samt neuem Link.
- Vor jedem Push den PR-Stand prüfen: Ist der letzte PR gemerged,
  zuerst auf `origin/main` rebasen (`--force-with-lease`), dann neuen
  PR anlegen.
- Für den Nutzer gilt einfach: **Link bekommen → mergen → nächste
  Antwort mit dem nächsten Link abwarten.** Ein bereits gemergter PR
  ist nie ein Problem; alles Weitere kommt automatisch als neuer PR.

## iOS-Apps — zwei Dinge bei JEDER App, ohne Nachfrage

Gilt für alle iOS-Projekte dieses Repos, auch für künftige neue Apps
(Ansage des Nutzers, 08/2026). Beides einmal beim Anlegen setzen und
danach bei jeder Arbeitseinheit mitziehen:

1. **Keine eigene Verschlüsselung angeben.** In jedes Target gehört
   `ITSAppUsesNonExemptEncryption = NO` — als Build-Einstellung
   `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption` (bei
   `GENERATE_INFOPLIST_FILE = YES`) oder als Schlüssel in der
   `Config/Info.plist`, je nachdem, wie das Projekt gebaut ist. Ohne
   das fragt App Store Connect bei **jedem** TestFlight-Build nach der
   Export-Compliance. Nie entfernen.
2. **Build-Nummer bei jeder neuen Fassung um eins hochsetzen.**
   Zusammen mit der Patch-Nummer, ohne Nachfrage, als Teil des PRs:
   `MARKETING_VERSION` +1 in der letzten Stelle und
   `CURRENT_PROJECT_VERSION` +1 — an allen Stellen im pbxproj (Debug
   und Release, und bei mehreren Targets in allen). Hintergrund: App
   Store Connect nimmt keinen Build an, dessen Nummer nicht höher ist
   als die des vorherigen.

   **Ausnahme:** Tagesspur und Tafelbild vergeben die Build-Nummer über
   die Skript-Bauphase „Build-Nummer setzen" (Anzahl der Git-Commits).
   Dort nur die Patch-Nummer heben und `CURRENT_PROJECT_VERSION` in
   Ruhe lassen.

## Bau in GitHub Actions — nur bauen, was sich geändert hat

`.github/workflows/ios-apps-build.yml` baut **nicht mehr alle Apps bei
jedem Push** (Ansage des Nutzers, 08/2026). Vorher horchte er auf
`**/*.swift` und ließ eine Tafelbild-Änderung zehn fertige Apps neu
übersetzen — jede auf einem eigenen macOS-Läufer, von denen nur wenige
gleichzeitig laufen dürfen. Gemessen: 2,7 bis 5,7 Minuten Wartezeit je
Auftrag, für Bauten, die niemand angefordert hatte.

- Die Auswahl trifft `.github/scripts/welche-apps.py` in einem
  **Linux**-Auftrag (Sekunden, belegt keinen macOS-Läufer). Die Liste
  der Apps steht dort und NUR dort — eine neue App wird in `APPS`
  eingetragen und in die `options` des Arbeitsablaufs.
- **Alles gebaut wird trotzdem**, wenn sich der Arbeitsablauf selbst,
  das Auswahlskript oder `scripts/swift-quelltext-pruefen.py` ändert —
  und immer dann, wenn sich nicht feststellen lässt, was sich geändert
  hat (gekürzte Historie). Ein Bau zu viel ist harmlos, ein Bau zu wenig
  nicht. Beim ersten Push eines neuen Zweiges gibt es keinen Vorgänger;
  dann wird gegen `main` verglichen — sonst wäre der Rundumbau der
  Regelfall, denn Arbeit beginnt hier fast immer auf einem frischen
  Zweig.
- Von Hand: Reiter „Actions" → „iOS-Apps bauen" → „Run workflow" → App
  auswählen (oder „alle").
- **`tafelbild-ansicht.yml` läuft nur auf Knopfdruck** (Ansage des
  Nutzers, 08/2026). Es macht Bildschirmfotos in zwei Simulatoren und
  kostete damit zwei weitere macOS-Aufträge bei jeder Änderung unter
  `Views/` — für Bilder, die niemand ansah. Ob der Quelltext übersetzt,
  sagt `tafelbild-build.yml`. Nicht wieder an `push` hängen.
- **Beim Warten auf einen Bau den richtigen AUFTRAG beobachten, nicht
  den ganzen Lauf.** In `tafelbild-build.yml` ist „Übersetzen
  (iOS-Simulator)" nach gut einer Minute fertig; „Starten (Simulator)"
  läuft danach noch fünf bis sieben Minuten und sagt über
  Compiler-Fehler nichts aus.

## Projekt Tagesspur — Versionierung

- App-Code: `TagesspuriOS/` (vier Targets: App, Widgets, Watch,
  Watch-Widgets). `MARKETING_VERSION` steht in allen vier Targets
  identisch (acht Stellen im pbxproj, Debug+Release).
- **Jede Arbeitseinheit (= jeder PR mit App-Änderungen) hebt die
  Patch-Nummer an**: 1.4.1 → 1.4.2 → 1.4.3 … — ohne Nachfrage, als
  Teil des PRs. Größere Sprünge (z. B. 1.5) nur auf ausdrückliche
  Ansage des Nutzers.
- Die Build-Nummer in Klammern vergibt die Skript-Bauphase
  „Build-Nummer setzen" automatisch — nie von Hand pflegen.

## Projekt Kassenbuch (intern: Reisekasse) — Versionierung

- Die App heißt für Nutzer **„Kassenbuch"** (App Store Connect,
  Homescreen, alle App-Texte — Ansage des Nutzers, 08/2026, weil
  „Reisekasse" im App Store vergeben ist). Projektordner, Target,
  Bundle-ID und iCloud-Container bleiben „Reisekasse"/`de.familie.
  reisekasse` — nach dem ersten Signieren nicht mehr ändern.
- App-Code: `ReisekasseiOS/` (zwei Targets: App + ReisekasseWatch).
  `MARKETING_VERSION` und `CURRENT_PROJECT_VERSION` stehen in BEIDEN
  Targets identisch (vier Stellen im pbxproj: App Debug+Release,
  Watch Debug+Release) — keine Skript-Bauphase, beide Werte werden
  im Repo gepflegt.
- **Jede Arbeitseinheit (= jeder PR mit App-Änderungen) hebt die
  Patch-Nummer UND die Build-Nummer um je +1 an** — ohne Nachfrage,
  als Teil des PRs (Ansage des Nutzers, 08/2026: konsequent bei jedem
  neuen Stand). Zählung: 1.0.1 (Build 2), dann 1.0.2 (Build 3) usw.
  Größere Sprünge nur auf ausdrückliche Ansage des Nutzers.
- `ITSAppUsesNonExemptEncryption = NO` ist im pbxproj gesetzt (App
  nutzt keine eigene Verschlüsselung) — nicht entfernen, erspart die
  Export-Compliance-Frage bei jedem TestFlight-Build.

## Projekt FlightMate AI

- Produktgrundlage: `docs/flightmate-ai/PRD.md` — Änderungen am Umfang
  müssen zum PRD passen (bzw. das PRD wird mitgepflegt).
- App-Code: `FlightMateiOS/` (Swift/SwiftUI, iOS 17, keine externen
  Abhängigkeiten; zwei Targets: App + FlightMateWatch). Prinzipien:
  wenige Funktionen, erklärbare Logik (Score/Legal deterministisch,
  kein LLM), ehrliche Datenlücken, Datenminimierung.

### FlightMate — Versionierung (Ansage des Nutzers, 08/2026)

- `MARKETING_VERSION` und `CURRENT_PROJECT_VERSION` stehen in
  BEIDEN Targets identisch (vier Stellen im pbxproj:
  App Debug+Release, Watch Debug+Release) — es gibt KEINE
  Skript-Bauphase, beide Werte werden im Repo gepflegt.
- **Jede Arbeitseinheit (= jeder PR mit App-Änderungen) hebt die
  Patch-Nummer UND die Build-Nummer um je +1 an** — ohne
  Nachfrage, als Teil des PRs. Startpunkt: 1.3.1 (Build 4);
  es folgt 1.3.2 (Build 5) usw. Größere Sprünge (z. B. 1.4) nur
  auf ausdrückliche Ansage des Nutzers.

## Projekt Schulalarm (Notfall- und Amokalarm, native iOS-App)

- App-Code: `AlarmiOS/` (zwei Targets: App + `AlarmNotificationService`,
  iPhone + iPad, iOS 16). Eine Lehrkraft löst aus, alle Dienst-iPads
  eines Kollegiums werden laut, jede meldet mit einem Tipp zurück.
  Verteilt als **Custom App** über Apple School Manager und Jamf School —
  nicht im öffentlichen App Store. Bundle-Id `de.dboschule.alarm`.
- **Diese App ersetzt keinen Notruf.** Der Satz steht auf dem
  Alarm-Bildschirm, in den Einstellungen und in den Review-Notizen —
  nicht wegrationalisieren.
- **Alles Backend-Nahe liegt hinter EINEM Protokoll** (`AlarmBackend`).
  CloudKit-Typen kommen ausschließlich in `Alarm/Backend/CloudKit/` vor;
  Views und Services importieren CloudKit nie. Das ist kein Stilwunsch:
  CloudKit stellt an Apple-Geräte zu und an sonst nichts, und sobald
  Android dazukommt, soll der Wechsel eine Datei kosten. `MockBackend`
  ist der laufende Beweis — steckte irgendwo ein `CKRecord`, ließe es
  sich nicht übersetzen. Ausführlich: `AlarmiOS/docs/BACKEND_MIGRATION.md`.
- **Die Notification Service Extension ist Pflicht, nicht Kür.** Eine
  CloudKit-Subscription kann `interruptionLevel` nicht setzen; ohne die
  Erweiterung bliebe jede Meldung auf `.active`, und ein aktiver Fokus
  hielte den Alarm zurück. Sie hebt auf `.timeSensitive`, baut Titel und
  Text und schreibt `userInfo` ins neutrale Format um. **Sie verwirft
  nie etwas** — ein unlesbares Paket wird angezeigt, mit dem Grund im
  Text. Ein stillschweigend verschluckter Alarm ist der schlimmste
  denkbare Fehler dieser App.
- **Der Push-Vertrag steht in `AlarmiOS/docs/PUSH_CONTRACT.md`** und wird
  an genau einer Stelle gelesen (`Shared/PushPayloadParser.swift`). Wer
  ihn ändert, ändert ihn dort und im Papier gleichzeitig.
- **`Shared/` liegt in BEIDEN Zielen** und ist als einziger Ordner über
  ausdrückliche Dateiverweise im pbxproj eingebunden, nicht über eine
  synchronisierte Gruppe (die gehört immer genau einem Ziel). Wer dort
  eine Datei anlegt, trägt sie in beide `Sources`-Phasen ein — sonst
  fehlt sie der Erweiterung, und das fällt erst beim Übersetzen auf.
- **Datum im Push ist ISO-8601-TEXT, keine Zahl.** CloudKit kodiert ein
  `Date`-Feld als nackte Zahl, und ob die ab 1970 oder ab Apples
  Bezugsdatum 2001 zählt, steht nirgends verlässlich. Ein falscher
  Nullpunkt machte jeden Alarm 31 Jahre alt — und die App schaltet alte
  Alarme (über drei Minuten) auf `.passive`. Der Fehler wäre nicht
  sichtbar falsch, sondern still stumm.
- **Das Feld `headline` ist Absicht.** Kommt die Erweiterung nicht zum
  Zug, zeigt iOS den Rückfalltext aus `alertLocalizationKey` mit den
  ROHEN Feldwerten als Argumenten — „amok" auf einem Sperrbildschirm
  hilft niemandem. Deshalb steht die deutsche Überschrift als eigenes
  Feld auf dem Datensatz. Aus demselben Grund wird `location` nie leer
  geschrieben: Ein fehlendes Argument lässt iOS die ganze Meldung fallen.
- **`instructionShort` statt `instruction` in den `desiredKeys`.** Ein
  APNs-Paket ist auf 4 KB gedeckelt, und ein einziges zu großes Feld
  nimmt die ganze Meldung mit. Der volle Text steht auf dem Datensatz und
  ist eine Sekunde später auf dem Alarm-Bildschirm.
- **`collapseIDKey` nennt ein FELD, nicht den Datensatznamen.** Darum
  trägt der Alarm seinen eigenen Namen zusätzlich im Feld `alarmId`.
  Ohne das stapeln sich mehrere Zustellungen desselben Alarms als
  mehrere Banner.
- **Öffentliche CloudKit-Datenbank — mit ehrlich benannten Grenzen.**
  Sie unterscheidet nur „irgendein angemeldeter iCloud-Nutzer" und
  „Ersteller". Sie kann NICHT „nur Mitglieder dieser Gruppe". Wer den
  sechsstelligen Code hat und eine Apple-ID besitzt, kann in der Gruppe
  schreiben. Die Schutzwirkung kommt aus der Verteilung nur an
  Schul-iPads und aus Datensparsamkeit (Kürzel statt Namen). Das steht so
  im README, in den Review-Notizen und in BACKEND_MIGRATION — nicht
  schönreden.
- **Indizes und Sicherheitsrolle sind hier NÖTIG** (anders als bei
  Tafelbild, das privat abgleicht): Ohne Queryable-Index scheitert jede
  Abfrage, ohne `_icloud`-Schreibrecht kann eine zweite Leitung nichts
  pflegen. Die Tabelle steht im README unter „CloudKit einrichten", dazu
  einmalig „Deploy Schema Changes to Production".
- **Sortiert wird nach dem Systemfeld `creationDate`**, nicht nach dem
  eigenen `createdAt`: Den Systemzeitstempel setzt der Server, ein Gerät
  mit falscher Uhr kann ihn nicht verbiegen.
- **Irgendwer muss anfangen: `createGroup`.** Bis 1.0.1 gab es nur
  `joinGroup` — das sucht einen Beitrittscode-Datensatz, der einen
  Group-Datensatz braucht, den nichts in der App je anlegte. Die App war
  damit gar nicht zu betreten (gemeldet 09/2026). Wer die Schule
  einrichtet, IST die Leitung; der erste Beitrittscode entsteht gleich mit
  und wird auf dem Einrichtungsbildschirm gezeigt. Reihenfolge beim
  Anlegen: Group, dann Member, dann Code — eine Referenz auf einen
  Datensatz, den es noch nicht gibt, weist CloudKit ab. Und `store.role`
  muss VOR `createInviteCode` stehen, denn das fragt `requireAdmin()`.
- **Eine Subscription braucht den Record-Typ VORHER** (`ensureSchema`, ab
  1.0.3). `CKQuerySubscription` nennt einen Record-Typ, und CloudKit lehnt
  eine für einen Typ ab, den es nie gesehen hat. Genau das war die Lage
  direkt nach dem Einrichten: `Group`, `Member` und `InviteCode` standen,
  `Alarm` und `Ping` nicht — der erste Alarm liegt ja noch in der Zukunft.
  Die Subscriptions wurden also abgewiesen, und ein Gerät ohne Subscription
  ist für immer stumm, ohne es zu sagen. `ensureSchema` schreibt je einen
  Datensatz und löscht ihn wieder; der Datensatz geht, der Typ bleibt. Der
  Alarm-Platzhalter ist NIE `active` und trägt `targetUser = "schema"` —
  scheitert das Löschen, darf daraus kein Alarmbildschirm auf 30 iPads
  werden.
- **Zwei Tests, weil es zwei Fehler sind** (ab 1.0.3). Der **Tontest**
  (`Services/Tontest.swift`) weckt das Gerät örtlich, ohne einen Meter Netz:
  Er beweist, dass das iPad laut werden DARF (Erlaubnis, Ton, Fokus,
  Lautlos-Schalter, Sperrbildschirm). Der **Selbsttest** geht über CloudKit
  und beweist die Zustellung. Der Selbsttest allein kann nicht sagen, an
  welcher Stelle die Kette reißt — deshalb sind es zwei Zeilen in der
  Prüfliste und nicht eine.
- **Ein Prädikat fragt mehr Felder ab als die Probeabfrage** (ab 1.0.4).
  Die Diagnose prüfte je Record-Typ nur `groupRef` — die Subscriptions
  fragen zusätzlich nach `targetUser` und `status`. Fehlt DORT der
  Queryable-Index, meldet die Probeabfrage „geht" und die Subscription
  entsteht trotzdem nicht (gemeldet 09/2026: alle vier fehlten, alle
  Abfragen grün). Die Prädikate stehen deshalb einmal in
  `CloudKitSubscriptions` und werden von Subscription UND Diagnose benutzt;
  zwei Fassungen prüften garantiert etwas anderes, als die Zustellung
  braucht.
- **Höchstens DREI `desiredKeys` je Subscription.** Mit zehn lehnte CloudKit
  jedes Alarm-Abonnement ab („notification additional fields limit
  exceeded"), und ein Gerät ohne Abonnement ist für immer stumm — die
  Ping-Abonnements kamen durch, weil sie gar keine Felder mitschicken.
  Es sind jetzt `type`, `location`, `triggeredByName` (bei der Entwarnung
  `type`, `clearedByName`). `alertLocalizationArgs` nennt ebenfalls Felder
  und bleibt deshalb leer; der Rückfalltext ist ein fester Satz. Damit
  fällt bei CloudKit auch die Altersprüfung der Erweiterung aus (`createdAt`
  reist nicht mehr mit) — ein zu laut gemeldeter alter Alarm ist der
  kleinere Schaden als gar keiner. Für ein eigenes Backend gilt die Grenze
  nicht; der Push-Vertrag bleibt vollständig.
- **CloudKit kennt kein `OR` im Prädikat** (gefunden 09/2026). „an alle ODER
  an mich" wurde mit „Invalid predicate: Unexpected expression" abgelehnt —
  und zwar erst beim Anlegen auf dem Gerät, nicht beim Übersetzen. Der Ping
  hat deshalb ZWEI Subscriptions mit je einem `==` (`ping-all-v2`,
  `ping-me-v2`). Nur `==`, `!=`, Vergleiche und `AND` sind hier belegt.
- **`modifySubscriptions` wirft bei Einzelfehlern NICHT.** Es wirft nur, wenn
  der ganze Aufruf scheitert; abgelehnte Abonnements stehen in
  `saveResults`. Bis 1.0.4 warf `reconcile` das Ergebnis mit `_ =` weg — die
  Diagnose meldete „ohne Fehler durchgelaufen", während kein einziges
  Abonnement entstanden war. Dasselbe Muster wie bei `partialErrorsByItemID`,
  eine Ebene höher: Wo CloudKit ein Ergebnis je Element zurückgibt, ist das
  Ergebnis die Fehlermeldung.
- **Teilfehler auspacken.** `modifySubscriptions` meldet ein Scheitern als
  EINEN Fehler mit `partialErrorsByItemID` darin. Ohne Auspacken liest man
  „Some items failed" und weiß nichts.
- **Die Diagnose legt fehlende Subscriptions gleich an** und schreibt das
  Ergebnis hin. Eine Diagnose, die „FEHLT" meldet und den Grund
  verschweigt, ist die Frage von vorhin noch einmal.
- **`mapped()` gehört nicht in eine Diagnose.** Es macht aus „unknown record
  type Ack" ein „Der Datensatz wurde nicht gefunden" — richtig für die
  Oberfläche, tödlich für die Fehlersuche. Dafür gibt es `rohAbfrage`.
- **„Zustellung prüfen" gibt den ROHEN Fehlertext aus** (`DiagnoseView`,
  `AlarmBackend.diagnose()`). Je Record-Typ eine Probeabfrage, dazu jede
  der vier Subscriptions einzeln, der Kontostatus, die APNs-Anmeldung und
  der Zeitpunkt des letzten angekommenen Pushes. „Field 'groupRef' is not
  marked queryable" ist für die Person, die es richten muss, mehr wert als
  ein aufgeräumtes „Verbindung fehlgeschlagen". Kopierbar, weil der Nutzer
  am iPad sitzt.
- **Zwei Leitungen, nicht eine** (`setRole`). Eine einzige Leitung ist ein
  Ausfallpunkt: Wird dieses iPad im Sommer zurückgesetzt, kann niemand mehr
  Codes vergeben oder Entwarnung geben. Der Hinweis steht unter der
  Mitgliederliste.
- **Abgeleitete Datensatznamen gegen Doppel:** `member-<Gruppe>-<Nutzer>`,
  `ack-<Alarm>-<Nutzer>`, `device-<Gruppe>-<Nutzer>`, und der
  Beitrittscode IST der Name seines Datensatzes (kein Index, keine
  Abfrage, kein Wettlauf). Ein zweiter Tipp auf „Gesehen" ist damit eine
  Änderung und keine zweite Zeile — und die Zahl der Rückmeldungen ist
  die eine Zahl, auf die im Ernstfall geschaut wird.
- **Subscriptions werden abgeglichen, nicht neu angelegt** (`reconcile`).
  Erst alles löschen und dann neu anlegen ließe das Gerät dazwischen taub
  zurück — und dauerhaft taub, wenn die zweite Hälfte an einer schlechten
  Verbindung scheitert. Das `-v1` in `SubscriptionID` ist dafür da, dass
  ein geändertes Prädikat eine neue Kennung bekommt: Ein Prädikat lässt
  sich nachträglich nicht ändern.
- **Polling ist das Netz unter den Subscriptions, nicht der Weg:** fünf
  Sekunden bei laufendem Alarm, dreißig sonst. Und: **Nur eine Abfrage,
  die GELUNGEN ist und nichts fand, räumt den Alarm-Bildschirm.** Eine
  abgerissene Verbindung darf nie wie eine Entwarnung aussehen.
- **`NSLock.lock()` ist `noasync`** — in einer async-Funktion heute eine
  Warnung, unter Swift 6 ein Fehler. Gesperrt wird deshalb ausschließlich
  über `NSLock.around` (`Backend/Locked.swift`), einen synchronen
  Abschluss: Darin kann nichts suspendieren.
- **Die Prüfliste ist keine Einrichtungshilfe, sie bleibt für immer.**
  Berechtigungen ändern sich hinter dem Rücken der App (Fokus-Ausnahme
  weg, iOS-Update, jemand meldet sich von iCloud ab). Sie wird bei jedem
  Start neu geprüft, und was fehlt, steht als Banner auf dem
  Startbildschirm. **Was iOS nicht herausgibt, wird als Anleitung gezeigt
  und nicht als Häkchen** — ein grünes Häkchen für „nicht nachgesehen"
  wäre die teuerste Lüge, die diese App erzählen kann.
- **Fertig eingerichtet ist erst, wenn ein Selbsttest ANGEKOMMEN ist.**
  Nicht wenn er gesendet wurde: Der Test beweist den Zustellweg, nicht
  den Sendeweg. Der Testalarm trägt `targetUser` und ist nur auf dem
  eigenen Gerät zu sehen.
- **Der Countdown vor dem Auslösen ist fünf Sekunden und bleibt.** Ein
  Fehlalarm kostet eine Schule mehr als die fünf Sekunden — beim nächsten
  echten Alarm zuckt niemand mehr.
- **Der zweite Bildschirm zeigt NIE den Alarm** (eigene Szene in
  `Config/Info.plist`, `ExternalDisplaySceneDelegate`). Sonst erführe die
  Klasse die Bedrohungslage vor der Kollegin nebenan. Was die App nicht
  kontrollieren kann, ist das System-Banner davor — das spiegelt iOS. Ob
  die Sperrbildschirm-Vorschau den Alarmtext zeigt, entscheidet das
  Krisenteam im Konfigurationsprofil, nicht die App.
- **Kritische Hinweise sind AUS.** Das Entitlement vergibt Apple nur auf
  schriftlichen Antrag, und eine Entitlements-Datei, die es ohne
  Bewilligung nennt, lässt jedes Signieren scheitern. Der Code steht
  fertig hinter der Compilerbedingung `CRITICAL_ALERTS` (drei Stellen).
  Nicht vorher eintragen.
- **Handlungstexte sind Platzhalter, die als solche zu erkennen sind.**
  Was im Ernstfall dort steht, gehört mit Schulleitung, Polizei und
  Feuerwehr abgestimmt; ein Text, der bloß amtlich klingt, ist schlimmer
  als ein sichtbares Leerfeld.
- **Töne und App-Symbol werden gerechnet, nicht geladen**
  (`scripts/make-sounds.py`, `scripts/make-icon.py`, reines Python ohne
  fremde Bibliotheken). Über 30 Sekunden spielt iOS einen Mitteilungston
  gar nicht ab — das Skript bricht vorher ab, damit der Fehler beim
  Erzeugen auffällt und nicht auf dem Gerät.
- `MARKETING_VERSION` und `CURRENT_PROJECT_VERSION` stehen an **vier**
  Stellen im pbxproj (App Debug+Release, Erweiterung Debug+Release) und
  müssen überall gleich sein — eine Erweiterung mit abweichender Nummer
  weist App Store Connect ab. Es gibt KEINE Skript-Bauphase. **Jede
  Arbeitseinheit hebt Patch- UND Build-Nummer um je +1**, ohne Nachfrage,
  als Teil des PRs. Zählung ab 09/2026: 1.0.0 (Build 1), dann 1.0.1
  (Build 2) usw.
- `ITSAppUsesNonExemptEncryption = NO` steht in beiden Info.plists und als
  Build-Einstellung — nicht entfernen.
- **Die Erweiterung hat KEINE Entitlements-Datei, und das bleibt so.**
  `com.apple.developer.usernotifications.time-sensitive` gehört
  ausschließlich an das App-Ziel. Beim ersten Signieren stand es auch in
  der Erweiterung — mit der Folge „Entitlement … not found and could not be
  included in profile": Für die App-Id einer Erweiterung gibt es diese
  Fähigkeit nicht, Xcode bietet sie dort nicht einmal an, und die
  automatische Signierung findet daraufhin gar kein Profil mehr. Gebraucht
  wird sie dort auch nicht — die Mitteilung gehört der App, und an deren
  Entitlement prüft iOS, ob `.timeSensitive` gilt. Wer der Erweiterung
  wieder eine Entitlements-Datei gibt, macht das Projekt unsignierbar.
- **Ein Bau in GitHub Actions beweist NICHT, dass sich signieren lässt.**
  Er läuft mit `CODE_SIGNING_ALLOWED=NO` gegen den Simulator; Entitlements
  werden dabei nie geprüft. Alles, was mit Profilen, App-Ids und
  Fähigkeiten zu tun hat, fällt erst auf dem Mac des Nutzers auf. Einen
  grünen Bau also nie als „signierbar" ausgeben.
- **Offen: der Zustellnachweis.** Ob der Alarm auf einem gesperrten iPad
  mit aktivem Fokus binnen zehn Sekunden hörbar ankommt, lässt sich nur
  auf zwei echten Geräten messen — nicht im Simulator, nicht in GitHub
  Actions. Das Messprotokoll samt Abbruchkriterium steht in
  `AlarmiOS/docs/ZUSTELLTEST.md`. Scheitert es, ist der Ersatz ein
  winziger eigener APNs-Sender hinter demselben Protokoll, nicht ein
  anderes Backend. **Diesen offenen Punkt nicht als erledigt darstellen.**
- Übersetzt wird in GitHub Actions (`.github/workflows/ios-apps-build.yml`,
  Eintrag `("AlarmiOS", "Alarm")` in `welche-apps.py`). **Erst pushen, Bau
  abwarten, Fehler beheben — den PR-Link erst herausgeben, wenn der Bau
  grün ist.**

## Projekt Anstoß (Fußball-Liveticker, native iOS-App)

- App-Code: `AnstossiOS/` (ein Target: App, iPhone + iPad, iOS 17).
  Spieltage, Tabellen und Liveticker der fünf großen Ligen
  (Bundesliga, Premier League, La Liga, Serie A, Ligue 1).
- **Namen im App Store** (Ansage des Nutzers, 08/2026, weil „Anstoß"
  allein schon vergeben ist — App Record Creation Error):
  - Name: `Anstoß – Liveticker` (19 Zeichen, Grenze ist 30)
  - Untertitel: `Top-Ligen unter Beobachtung` (27 Zeichen, Grenze 30)
  Auf dem **Homescreen** heißt die App weiterhin schlicht **Anstoß**
  (`INFOPLIST_KEY_CFBundleDisplayName`) — iOS schneidet dort nach rund
  zwölf Zeichen ab. Store-Name und Anzeigename sind getrennte Felder
  und dürfen auseinandergehen. Projektordner, Target, Bundle-Id
  (`de.familie.anstoss`) und der Schlüsselbund-Dienst bleiben
  „Anstoss" — nach dem ersten Signieren nicht mehr ändern.
- Der App-Eintrag wird in App Store Connect **von Hand** angelegt
  (Meine Apps → +), nicht über Xcodes „Create App Record": Xcode
  schlägt dort den Anzeigenamen vor und läuft damit erneut in den
  Namenskonflikt. Steht der Eintrag, lädt Distribute in ihn hinein.
- Daten von **football-data.org (v4)**. Der kostenlose Zugang deckt
  genau diese fünf Ligen ab; der Schlüssel gehört dem Nutzer und liegt
  im Schlüsselbund (`Schluesselbund.swift`) — nie im Repo, nie in den
  Voreinstellungen.
- **Zehn Abfragen je Minute** sind das Limit des freien Zugangs. Die
  `Anfragenbremse` in `FussballDienst.swift` hält es selbst ein — beim
  Erweitern nicht umgehen. Der Ticker holt alle fünf Ligen mit EINER
  Abfrage (`/v4/matches?competitions=…`).
- Der freie Zugang liefert nicht zu jedem Spiel Torschützen. Fehlen
  sie, baut `Datenhaltung.meldungenAblegen` die Tormeldungen aus dem
  Sprung im Spielstand — diesen Rückfall nicht entfernen.
- **Für die Bundesliga springt OpenLigaDB ein** (`Torschuetzendienst.swift`,
  schlüssellos, eigenes Kontingent — zählt NICHT gegen die zehn Abfragen
  je Minute). Es ergänzt nur, was football-data.org offenlässt, und
  ordnet über vereinfachte Vereinsnamen zu; beide Mannschaften müssen
  passen, sonst wird nichts ergänzt. Für die vier anderen Ligen gibt es
  keine vergleichbare freie Quelle.
- **Der direkte Vergleich wird aus den mitgelieferten Einzelspielen
  gerechnet**, nicht aus `aggregates` — dessen Zahlen gingen in 1.0.8
  nicht auf (10 Begegnungen, aber 0 + 2 + 0). Der Rückfall auf
  `aggregates` prüft, ob die Summe stimmt.
- **`head2head` ist eine eigene Unterabfrage** (`/v4/matches/{id}/head2head`),
  KEIN Feld der Spielantwort — in 1.0.7 stand es falsch im Code, deshalb
  erschien der direkte Vergleich nie. Sie kostet eine Abfrage und wird nur
  beim Öffnen einer einzelnen Begegnung gestellt.
- **Die Tabellenantwort trägt HOME und AWAY mit.** Heim- und
  Auswärtsbilanz kosten deshalb nichts extra — nicht als eigene Abfrage
  nachbauen.
- **Torjägerliste**: `/v4/competitions/{code}/scorers` gibt der freie
  Zugang her. Das ist das Einzige an Spielerdaten — Aufstellungen NICHT.
- **Zweite Torschützenquelle: TheSportsDB** (`Spielereignisdienst.swift`,
  schlüssellos über die freie Kennung `123`, 30 Abfragen je Minute,
  eigenes Kontingent). Deckt ALLE fünf Ligen ab und liefert schon
  während des Spiels. **Deckel beachten:** Die freie Stufe gibt je
  Spiel nur die ERSTEN FÜNF Ereignisse heraus (Karten zählen mit) —
  späte Tore fehlen. Deshalb ergänzt sie nur Namen; die Torfolge selbst
  baut weiter die App aus dem Sprung im Spielstand.
  Reihenfolge: OpenLigaDB zuerst (nur Bundesliga, dafür vollständig),
  dann TheSportsDB. Zugeordnet wird über Tagesplan + Vereinsnamen,
  beide Mannschaften müssen passen.
- **Aufstellungen gibt es nirgends frei** (Stand 08/2026, geprüft):
  football-data.org führt sie in den kostenpflichtigen Stufen,
  OpenLigaDB und TheSportsDB haben sie nicht. Nichts einbauen, was
  nicht ankommt — was dazu bekannt wird, läuft über die Ligameldungen
  (Art „Aufstellung & Vorbericht").
- **Karten sind bei TheSportsDB doch vorhanden** (Gelb und Rot, in der
  Zeitleiste). In 1.0.7 stand hier, es gebe sie nirgends frei — das war
  falsch. Wieder eingebaut wurden sie trotzdem nicht: Der Fünf-Ereignis-
  Deckel macht sie unzuverlässig, und der Nutzer hatte sie ausdrücklich
  ausbauen lassen. Vor einem Wiedereinbau nachfragen.
- `MARKETING_VERSION` und `CURRENT_PROJECT_VERSION` stehen an je zwei
  Stellen im pbxproj (Debug + Release) — es gibt KEINE Skript-Bauphase,
  beide Werte werden im Repo gepflegt. **Jede Arbeitseinheit (= jeder
  PR mit App-Änderungen) hebt die Patch-Nummer UND die Build-Nummer um
  je +1 an** — ohne Nachfrage, als Teil des PRs. Zählung ab 08/2026:
  1.0.9 (Build 7), dann 1.0.10 (Build 8) usw. Größere Sprünge nur auf
  ausdrückliche Ansage des Nutzers.
- `ITSAppUsesNonExemptEncryption = NO` steht in `Config/Info.plist` UND
  als Build-Einstellung `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption` —
  nicht entfernen, erspart die Export-Compliance-Frage bei jedem
  TestFlight-Build.
- **Mitteilungen sind örtlich, nicht Push.** Die App hat keinen Server.
  `Tickerwerk` vergleicht den Stand, `Benachrichtiger` schickt die
  Mitteilung, `Hintergrundpflege` holt den Stand nach, wenn iOS eine
  Auffrischung gewährt (Kennung `de.familie.anstoss.spielstand`, muss
  haargenau zu `Config/Info.plist` passen). Verlässlich auf die Minute
  ist nur die Erinnerung vor dem Anpfiff. Wer hier „echte"
  Push-Nachrichten verspricht, verspricht etwas, das ohne Server nicht
  geht.
- **Ligameldungen (Transfer, Gerüchte) kommen NICHT von
  football-data.org** — der Dienst kennt nur Spieldaten. Sie kommen aus
  freien RSS-Ausgaben (kicker, Transfermarkt) über
  `Nachrichtendienst.swift`; die Einteilung in Transfer/Gerücht/
  Verletzung schätzt `Nachrichtensieb` aus der Wortwahl, die Liga
  kommt aus den Schlagworten der Quelle oder dem
  `Vereinsverzeichnis`, das sich aus den geladenen Tabellen selbst
  füllt. Keine gepflegte Vereinsliste in den Quelltext schreiben — die
  veraltet jeden Sommer. Gelesen werden nur Überschrift und Anriss,
  nie ganze Texte; abgefragt höchstens alle zehn Minuten.
- **Ablagen müssen Modelländerungen überleben.** `Meldungswunsch` liest
  seine Aufzählungen über die Rohwerte (unbekannte werden überlesen),
  Ticker und Nachrichten über `JSONDecoder.nachsichtigeListe`. Fällt
  eine Aufzählung weg, verwirft der erzeugte Leser sonst stillschweigend
  die ganze gesicherte Ablage — samt aller Einstellungen des Nutzers.
- Das App-Symbol erzeugt `scripts/anstoss-icon.py` (reines Python,
  ohne fremde Bibliotheken) — nicht von Hand bearbeiten.
- Übersetzt wird in GitHub Actions: `.github/workflows/ios-apps-build.yml`
  baut die App bei jedem Push mit. **Erst pushen, Bau abwarten, Fehler
  beheben — den PR-Link erst herausgeben, wenn der Bau grün ist.**

## Projekt Canada 2026 — entfernt

Der Ordner `Canada2026iOS/` wurde vom Nutzer aus `main` gelöscht (08/2026).
Die App wird nicht weiterentwickelt. **Nicht wiederherstellen**, keine
Vorschläge dazu, und den Eintrag im Bau-Arbeitsablauf nicht zurückholen.

## Klassenraum (iOS-Versuchsfassung) — abgeschlossen und gelöscht

Der Ordner `KlassenraumiOS/` war eine Kopie von Tafelbild 1.0.57, allein
dafür da, den Abgleich von der öffentlichen auf die **private**
iCloud-Datenbank umzubauen, ohne die veröffentlichte App anzufassen. Der
Umbau ist durch und mit **Tafelbild 1.0.58** zurückgewandert; der Ordner
und sein Bau-Arbeitsablauf sind gelöscht. **Nicht wiederherstellen.**

Was daraus bleibt, steht unten beim Projekt Tafelbild. Nicht verwechseln
mit `klassenraum/` (kleingeschrieben) — das ist die Web-App gleichen
Namens und lebt weiter.

## Projekt Notfallalarm (Amok-/Notfallalarm, native Android-App)

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

## Projekt Wörterwerkstatt (Web-App, Rechtschreibung)

- Code: `woerterwerkstatt/` — statische Web-App ohne Bauschritt (ES-Module,
  kein Framework, keine fremde Bibliothek), wird vom Pages-Workflow mit
  ausgeliefert: https://katonid.github.io/prae/woerterwerkstatt/
  Nicht verwechseln mit `klassenraum/` (die Tafel) — das hier ist das
  Übungsheft. Ausführlich: `woerterwerkstatt/README.md`.
- **Fünf Stufen je Lernwort**, die immer weniger zeigen: Abschreiben →
  Buchstabensalat → Geheimschrift → Wortart samt Formen → Diktat. Eine sechste
  Übung wird in `js/uebungen/index.js` eingetragen — sonst nirgends.
- **Ein Bereich darf weniger als fünf Stufen üben** (Feld `stufen`, ab 1.4.0).
  Die Blöcke der 1. Klasse lassen die Wortart weg — Nomen, Verb und Adjektiv
  sind dort noch kein Stoff (Ansage des Nutzers, 08/2026). Gelesen wird das an
  EINER Stelle, `stufenFuer(bereich)` in `js/uebungen/index.js`; danach richten
  sich Kacheln, Sternhöchstzahl, Adressprüfung, der Weiterweg nach drei Sternen
  und die Stufenliste im Auftrag der Woche. Ein festes `STUFEN_IDS` gibt es
  nicht mehr — wer es wieder einführt, zeigt der 1. Klasse „0 von 15 Sternen"
  bei vollem Heft. Gezählt wird auf den Kacheln die Stelle IM BEREICH (1 2 3 4),
  nicht die feste Nummer der Übung (1 2 3 5).
- **Ein abgebrochener Durchgang geht weiter** (ab 1.7.0, Ansage des Nutzers,
  08/2026: „Im Unterricht ist es oft so, dass die Kinder einen ganzen
  Übungssatz nicht zu Ende bekommen."). Der Stand liegt in `store.laeufe`
  (höchstens acht, je Bereich+Päckchen+Stufe), gesichert nach JEDEM Wort und
  beim Abbrechen. Gemerkt werden nur Kennungen; passt der Stand nicht mehr
  zum Päckchen, wird er verworfen statt halb falsch fortgesetzt
  (`aufgenommen` in `lauf.js`). Er gehört zum Gerät und reist NICHT in die
  Wolke — in der Klassenansicht zählen Sterne, kein halber Durchgang.
- **Eine Notiz im Durchgang gehört ÜBER die Bühne, nicht hinein.**
  `naechstes()` räumt die Bühne für jede Karte leer. Bis 1.7.0 stand „Und
  jetzt noch einmal die Wörter, die schwer waren" mitten darin — und war im
  selben Augenblick wieder weg, in dem sie erschien. Dafür gibt es jetzt
  `laufhinweis` mit `hinweisSagen`/`hinweisWeg`.
- **Kein Fachwort ohne Erklärung.** Stufe 4 fragte nach der „2. Person
  Einzahl"; im 2. Schuljahr kennt das niemand (Ansage des Nutzers, 08/2026).
  Gefragt wird nach der „du-Form", der Fachbegriff steht im Hinweis dahinter —
  im 4. Schuljahr ist er Stoff und soll nicht verschwinden.
- **Trainingspäckchen zu 15 Wörtern.** Verteilt wird REIHUM über die Wortarten
  (`paket.js`), nicht der Reihe nach: Sonst bestünde Päckchen 1 aus lauter
  Nomen und die Wortart-Stufe wäre darin sinnlos. Die Verteilung ist gerechnet
  und nicht gespeichert — „Päckchen 2" ist auf jedem Gerät dasselbe.
- **Fünf Sorten Bereiche.** `woerter.js` = 20 Themenbereiche à 30 Wörter (nach
  Inhalt, von Haus aus sichtbar). Dazu vier Rechtschreiblisten nach
  Rechtschreibstelle, alle von Haus aus AUSGEBLENDET: `rechtschreibung1.js`
  (23 Blöcke à 8 Wörter, 1. Schuljahr, ohne Wortart-Stufe),
  `rechtschreibung2.js` (28 à 10, 2. Schuljahr), `rechtschreibung3.js`
  (25 à 15, 3. Schuljahr), `rechtschreibung.js` (27 à 15, 4. Schuljahr).
  Zusammen 1844 Wörter in 123 Bereichen. Eine neue Liste wird an vier Stellen
  eingetragen: `app.js` (`alleBereiche`, `bereicheZeigen`), `bereiche.js`
  (Wähler), `klasse.js` (Auftrag der Woche) und `sw.js`.
- **Ein Päckchen ist so groß wie sein Bereich**, höchstens aber
  `PAKETGROESSE` (15). Die Klasse-1-Blöcke haben acht Wörter, die der
  2. Klasse zehn — nirgends eine feste Zahl hineinschreiben, `pakete()`
  rechnet mit der tatsächlichen.
- **Dieselben Wörter in mehreren Klassenstufen sind Absicht**, kein Versehen:
  getrennte Sätze für getrennte Jahrgänge, freigeschaltet wird nur einer. Die
  Mehrzahl der Wochentage steht erst in Klasse 3; in Klasse 2 geht es um den
  Artikel. Sichtbarkeit steht in `store.sichtbareBereiche`;
  was dort fehlt, richtet sich nach `bereich.gruppe`. Ein ausgeblendeter
  Bereich bleibt über die Adresse erreichbar — ein Auftrag der Woche darf auf
  ihn zeigen. Die Auswahl der Lehrkraft reist über `klasse.bereicheAn` zu den
  Kindern (`klasseAuffrischen` beim Start).
  - In den Blöcken steht die **Grundform** als Lernwort, wo die
    Rechtschreibstelle erst in der abgeleiteten Form steckt (`Baum|n|der|Bäume`
    im Block „ä/äu ableiten"). Der Block heißt „ableiten"; abgeleitet wird in
    Stufe 4. Nicht auf die abgeleitete Form umstellen.
  - Nicht steigerbare Adjektive: leere Felder (`wahr|a||`), dann fragt Stufe 4
    sie nicht ab. Wortgruppen sind `x`.
- **Drei Wege hinein für Kinder**: QR-Code, Link, oder Code abtippen („👋
  Mitmachen" in der Kopfzeile). Der dritte ist der wichtigste — ohne ihn kommt
  ein Kind auf einem frischen Gerät gar nicht hinein. Die **Anmeldung ohne
  PIN** ist je Klasse zuschaltbar (`klasse.ohnePin`), aus als Vorgabe: Wer den
  Code hat, käme sonst als jedes Kind hinein. Ein NEUES Kind braucht immer eine
  PIN. Der Klassencode kennt kein I, O, 0 oder 1 — deshalb wird bei der Eingabe
  NICHT geraten und umgewandelt, sondern nur großgeschrieben.
- **Wortformen stehen in den Daten, sie werden NIE gerechnet** (`woerter.js`,
  600 Wörter in 20 Bereichen; `rechtschreibung.js`, 405 in 27 Blöcken). Die deutsche Mehrzahl ist nicht regelmäßig
  (Baum → Bäume, aber Wort → Wörter und Ort → Orte). Eine erfundene Form, die
  die App als richtig ausgibt, lehrt das Falsche, und niemand merkt es. Beim
  Anlegen eigener Bereiche schlägt `bereiche.js` deshalb nur Verbformen und
  Steigerungen vor — nie eine Mehrzahl.
- **Die Geheimschrift ist das Buchstabenhaus** (Dach: b d f h k l t ß und alle
  großen; Mitte: alle; Keller: g j p q y), gezeichnet als SVG in
  `js/wortbild.js`. Fertige Wortbildschriften der Schulbuchverlage gibt es,
  aber sie sind lizenzpflichtig und müssten nachgeladen werden — das bricht
  Offline-Betrieb und Datensparsamkeit. Nicht durch eine Schrift ersetzen.
- **Zur Geheimschrift gehört die Wortliste des Päckchens** (ab 1.6.0, Ansage
  des Nutzers 08/2026). Ohne sie prüft die Übung, ob ein Kind fünfzehn Wörter
  auswendig kann — nicht, ob es das Wortbild gespeichert hat. Im Heft steht
  die Liste daneben und man ordnet zu; das ist die Aufgabe. Die Liste zeigt
  nur die Wortkerne (wie das Bild), alphabetisch, und ist wegschaltbar
  (`einstellungen.geheimWortliste`). Dafür reicht `lauf.js` das ganze Päckchen
  an `aufbauen` durch — nicht wieder herausnehmen.
- **Ein Großbuchstabe hat im Wortbild links einen dicken Strich** (ab 1.8.0,
  Ansage des Nutzers, 08/2026: „Die Kinder in meiner Klasse sind darauf
  trainiert."). Das ist das einzige verlässliche Kennzeichen — b, d, f, h, k,
  l, t und ß ragen ebenfalls ins Dachgeschoss. Die zusätzliche Höhe bleibt
  daneben (ausdrücklich erlaubt), der gefüllte Kasten nicht: Auf einer vollen
  Fläche wäre der Strich nicht zu sehen. `grossrand()` in `wortbild.js`,
  gezeichnet in BEIDEN Darstellungen.
- **Was die Sprachausgabe hergibt: Text, Stimme, Tempo, Tonhöhe — mehr nicht.**
  Eine Betonung einzelner Silben verlangt SSML, und das nimmt keine
  Browser-Sprachausgabe entgegen (gefragt 08/2026). Nicht versprechen. Was
  hilft: langsameres Tempo (Vorgabe 0,7), Tonhöhe 1,0 statt 1,05, ein Punkt
  am Ende (ein nacktes Wort wird als Bruchstück genuschelt) und die WAHL der
  Stimme — welche deutschen Stimmen ein Gerät mitbringt und wie deutlich die
  sind, kann die App nicht wissen, also entscheidet die Lehrkraft
  (`einstellungen.diktatStimme`). Silben NICHT selbst trennen: Die deutsche
  Silbentrennung ist nicht ableitbar, und eine falsche lehrt das Falsche —
  dieselbe Regel wie bei den Wortformen.
- **Groß und klein wird beim Prüfen verglichen** (`uebungen/schreibfeld.js`).
  Das IST der halbe Rechtschreibstoff der Grundschule. Zwei Versuche, dann
  steht die Lösung da und wird abgeschrieben; für die Wertung zählt nur der
  erste Versuch. Nicht „großzügiger" machen.
- **Eine Rückmeldung muss den Fehler benennen, den das Kind gemacht hat**
  (`warumFalsch` in `schreibfeld.js`, ab 1.6.0). „baum" statt „der Baum" war
  bis dahin „Schon der erste Buchstabe stimmt nicht" — falsch beschrieben und
  entmutigend: Das Kind konnte das Wort. Vor der Stellenangabe stehen deshalb
  zwei Fälle mit **Vorrang** vor dem übungseigenen `zusatzhinweis`: nur groß
  oder klein (mit der Regel dazu) und der fehlende oder falsche Artikel. Wer
  eine neue Rückmeldung baut, prüft sie an genau diesen Eingaben.
- **Nach dem zweiten Fehlversuch wird die Stelle markiert**, nicht bloß die
  Lösung gezeigt. Abschreiben ohne Hinsehen lehrt niemanden etwas. Die Marke
  ist unterlegt UND unterstrichen — Farbe allein sieht ein farbfehlsichtiges
  Kind nicht.
- **Jede Stufe hilft mit dem, was sie weiß**: Der Salat vergleicht den
  Buchstabenvorrat („ein n kommt oben gar nicht vor"), die Geheimschrift das
  Häuschen, das Abschreiben zeigt im Blitzmodus das Wort nach einem
  Fehlversuch zwei Sekunden wieder (sonst wäre der zweite Versuch geraten —
  die Aufgabe heißt „schreib es ab"). Das zählt wie ein Spicken.
- **Der QR-Code wird selbst gerechnet** (`js/qr.js`, Byte-Modus, Stufe L/M,
  Fassungen 1–10). Geprüft wird mit `scripts/qr-pruefen.py` gegen OpenCV
  (Rücklesen) und segno (feste Muster) — beides nur zum Prüfen, nicht im Repo.
  **Nach jeder Änderung an qr.js laufen lassen:** Ein Code, bei dem ein
  einziges Modul falsch sitzt, sieht tadellos aus und wird von keiner Kamera
  gelesen. Genau das ist beim Bau zweimal passiert (Format-Information um
  90 Grad verdreht, beide Ausfertigungen einzeln).
- **Die PIN eines Kindes liegt nirgends lesbar.** Gespeichert wird ein
  SHA-256-Abdruck über Code, Name und PIN, in einem Zweig ohne Leserecht;
  angemeldet wird durch einen Schreibversuch, den die Datenbankregel nur bei
  Übereinstimmung annimmt (`cloud.js`).
- **Die Schulverwaltung steht in den REGELN, nicht in der App** (`admin.js`, ab
  1.5.0, Ansage des Nutzers 08/2026: „Ich möchte Admin-Befugnisse haben:
  Andere Accounts (Lehrer u. Schüler) erstellen, ändern und löschen."). Die App
  trägt weder eine Adresse noch eine Liste mit sich, sondern PROBIERT
  (`verwaltungPruefen`): Wer `woerterwerkstatt/users` auflisten darf, ist
  Verwaltung — nur dann erscheint „🏫 Schule". So braucht eine weitere
  Verwaltung keine neue Fassung der App. Berechtigt sind die in den Regeln
  genannte E-Mail (der Einstieg, sonst gäbe es ein Henne-Ei-Problem) und alle
  unter `admins/<uid>`.
- **`users/<uid>/klassen` ist nur ein VERZEICHNIS, keine Wahrheit** (ab 1.5.1).
  Die Klasse selbst steht unter `klassen/<CODE>`; das Anlegen schreibt beides,
  aber es sind ZWEI Schreibvorgänge. Bricht der zweite ab, ist die Klasse auf
  jedem anderen Gerät unsichtbar — obwohl der QR-Code gilt und die Kinder
  weiter üben (genau so gemeldet, 08/2026). „Meine Klassen" führt deshalb
  Wolke und Gerät ZUSAMMEN (vorher entweder/oder), trägt fehlende Einträge
  über `klasseWiederEintragen` nach und bietet „Klasse per Code holen" für den
  Fall, dass ein Gerät gar nichts mehr weiß. Angenommen wird nur, was
  `besitzer === konto.uid` trägt — den Code haben alle Kinder der Klasse.
- **Eine misslungene Netzabfrage darf nicht als leere Liste erscheinen.** Bis
  1.5.0 fiel „Meine Klassen" bei jedem Fehler stumm auf die Geräteliste
  zurück; wer nichts sah, konnte „es gibt keine" und „ich durfte nicht
  nachsehen" nicht unterscheiden.
- **Kinder verwaltet die Schulverwaltung NICHT selbst**, sie öffnet die
  gewohnte Klassenansicht. Zwei Oberflächen für dieselbe Aufgabe liefen mit
  Sicherheit auseinander.
- **Kennwort vergessen: Mail statt Setzen.** `zugangsmailSenden` schickt über
  `sendOobCode` (PASSWORD_RESET) einen Link an die hinterlegte Adresse; die
  Kollegin setzt selbst neu, das alte gilt bis dahin weiter. Ein Kennwort
  direkt zu setzen verlangt das Zeichen des betroffenen Kontos — und ein
  Kennwort, das die Verwaltung kennt, ist keines. Zwei Wege in der App: im
  Konto der Lehrkraft und, falls dort keine Adresse steht, „✉️ Kennwort-Mail"
  in der Übersicht an eine frei eingetippte Adresse.
- **Die E-Mail im Verzeichnis trägt sich beim ANMELDEN nach** (ab 1.8.1). Bis
  dahin schrieb nur `kontoAnlegen` ein Profil — wer sich vorher angemeldet
  hatte oder bei wem der Schreibvorgang durchfiel, stand ohne E-Mail da, und
  der Knopf zum Zurücksetzen war ausgerechnet für die Kolleginnen grau, um die
  es geht. `anmelden` schreibt deshalb `profil/email` per PATCH nach — den
  NAMEN aber nicht: Hat die Verwaltung ihn geändert, überschriebe ihn sonst
  die nächste Anmeldung der Lehrkraft.
- **Ein fremdes Firebase-Konto zu löschen geht vom Browser aus nicht** — das
  verlangt das Admin-SDK mit Dienstschlüssel, und der wäre in einer Web-App der
  Generalschlüssel zur Datenbank, mitgeliefert auf jedem Kindergerät. Die App
  löscht die DATEN einer Lehrkraft und führt für die Anmeldung in die
  Firebase-Konsole. Nicht „lösen" wollen. Anlegen (`signUp`) und die Mail zum
  Zurücksetzen (`sendOobCode`) gehen dagegen; beim Anlegen darf das
  zurückgegebene Zeichen NICHT gesichert werden, sonst ist die Verwaltung
  anschließend als die neue Lehrkraft unterwegs.
- **Ein Kind umbenennen heißt neue PIN.** Der Name ist der Schlüssel und steckt
  im Abdruck; lesen lässt der sich nirgends. `kindUmbenennen` legt deshalb erst
  alles Neue an (Abdruck, Kind, Protokoll) und nimmt dann das Alte weg — bricht
  es dazwischen ab, gibt es ein Kind zu viel, nie eines zu wenig.
- **Beim Löschen einer Klasse zählt die Reihenfolge.** `geheim/<CODE>` fragt
  nach `klassen/<CODE>/besitzer`; ist die Klasse zuerst weg, bleiben die
  PIN-Abdrücke für immer liegen — unlesbar und unlöschbar. Erst `geheim`,
  `anmeldung`, `protokoll`, dann die Klasse. Bis 1.4.0 blieben alle drei
  stehen, und „Protokoll der Klasse löschen" scheiterte stillschweigend, weil
  `.write` nur am `$kind` stand.
- **Die Datenbankregeln stehen im Wurzelverzeichnis: `firebase-rules.json`**,
  mit den Zweigen BEIDER Web-Apps in einer Datei. Die Firebase-Konsole ersetzt
  beim Veröffentlichen die kompletten Regeln — wer nur einen Zweig einfügt,
  sperrt die andere App aus. Genau das passierte 08/2026, als die
  Wörterwerkstatt dazukam: Ihr Zweig fehlte, die Datenbank wies dort alles ab,
  und es ließ sich keine Klasse anlegen. Die Dateien in `klassenraum/` und
  `woerterwerkstatt/` sind nur noch Einzelfassungen zum Nachschlagen.
- **In die Regeldateien gehört NICHTS außer Regeln.** Der Editor kennt oben nur
  `rules`, als Regelarten nur `.read`, `.write`, `.validate`, `.indexOn` und als
  deren Werte nur `true`/`false`/Text. Ein erklärender Schlüssel oder ein Array
  lässt das Einfügen mit einem Syntaxfehler scheitern — die Dateien trugen
  kurzzeitig `_hinweis`-Schlüssel und wären so nicht einzufügen gewesen. Die
  Erläuterung steht in `firebase-rules.md` daneben. Vor dem Einfügen prüft
  `woerterwerkstatt/scripts/regeln-pruefen.py` beides — Regelarten und
  Deckungsgleichheit mit den Einzelfassungen.
- **Die Regeln IMMER als Text in die Antwort schreiben, nie als Dateiverweis**
  (Ansage des Nutzers, 08/2026, wörtlich: „Bitte gib mir immer den verfluchten
  Text für die Regeln so an, dass ich ihn hier kopieren kann. Ich habe auf dem
  iPad keine große Möglichkeit, in eine dämliche JSON-Datei einzusehen."). Der
  Nutzer arbeitet am iPad; „steht in `firebase-rules.json`" ist dort keine
  Anweisung, sondern eine Sackgasse. Also: den vollständigen Inhalt in einen
  Codeblock, vorher frisch aus `main` lesen und mit `regeln-pruefen.py`
  prüfen. Das gilt bei JEDER Änderung an den Regeln und bei jeder Antwort, in
  der das Einspielen vorkommt — ohne Nachfrage. Dasselbe gilt sinngemäß für
  alles andere, was der Nutzer irgendwo einfügen soll.
- **Nach jeder Änderung am JavaScript `module-pruefen.mjs` laufen lassen**
  (`node --experimental-vm-modules woerterwerkstatt/scripts/module-pruefen.mjs`).
  Die App hat keinen Bauschritt: Eine fehlende Klammer in einer verschachtelten
  `h(...)`-Reihe und ein Import, den es nicht gibt, sehen beide gleich aus —
  die Seite bleibt weiß, und die Meldung steht nur in der Entwicklerkonsole.
  Beides ist beim Bau passiert (`meldung` aus `util.js` statt `ui.js`; eine
  Klammer zu wenig in `admin.js`).
- **Ein Einrichtungsfehler muss sich erklären.** Die App meldete den Fall oben
  als „NICHT_ERLAUBT" in einem Streifen, der nach vier Sekunden verschwand —
  das ist keine Meldung, das ist ein Rätsel. Seit 1.0.2 prüft
  `cloud.regelnPruefen()` beim Öffnen von „Meine Klassen" einmal nach und
  zeigt bei gesperrtem Zweig einen STEHENDEN Kasten mit den drei Schritten;
  „Neue Klasse" ist so lange ausgegraut. `cloud.klartext()` übersetzt die
  Rohfehler — nie wieder eine Konstante in Großbuchstaben in die Oberfläche
  durchreichen.
- **Der Wegweiser darf NIE aus einem Datenereignis heraus laufen.**
  `wegLesen()` (app.js) öffnet Blätter und stellt Netzanfragen. In 1.0.3 hing
  es an der Meldung „Bereiche geändert" — und ein Kind, das einer Klasse
  beitritt, sichert genau dabei die mitgegebenen Bereiche. Gemessen: 277
  Netzanfragen und 279 gestapelte Blätter in vier Sekunden; auf dem iPad war
  nichts einzutippen, auf dem Telefon starb der Tab. Seit 1.0.4 dreifach
  abgesichert: Ein Datenereignis zeichnet höchstens die Bühne neu; der
  Wegweiser merkt sich den offenen Beitrittscode und öffnet kein zweites
  Blatt; `bereichSichern` meldet nur bei echter Änderung. Wer einen neuen
  Horcher anlegt, ruft darin nie den Wegweiser.
- **Das Wortprotokoll ist die Ausnahme von der Datensparsamkeit** (ab 1.0.5,
  Ansage des Nutzers: „als Lehrer möchte ich nachsehen können, welche Wörter
  die Kinder bearbeitet haben und welche Fehler sie gemacht haben"). Gemeldet
  wird je Wort, wie oft es drankam, wie oft es beim ersten Versuch saß, in
  welchen Stufen — und WIE das Kind es geschrieben hat. Letzteres ist der
  Zweck: „Somer" sagt einer Lehrkraft, was falsch gemerkt wurde; eine
  Fehlerzahl sagt es nicht.
  - **Es liegt in `protokoll/<CODE>/<Kind>`, nicht unter `klassen/`.** Dort
    darf lesen, wer den Code hat — das sind alle Kinder der Klasse. Schreiben
    darf jedes Kind, lesen nur die angemeldete Besitzerin. Nicht verschieben.
  - **Die Leseerlaubnis gehört an den `$code`, nicht an das `$kind`** (ab
    1.5.0). Die Klassenansicht liest `protokoll/<CODE>` in einem Zug; eine
    Erlaubnis, die nur am einzelnen Kind steht, deckt das nicht — RTDB-Regeln
    reichen nach UNTEN durch, nicht nach oben. Von 1.0.5 bis 1.4.0 schrieben
    die Kinder deshalb brav mit, und die Lehrkraft bekam den Zweig nie zu
    sehen (gemeldet 08/2026 als „da wurde wohl nichts übertragen").
  - **Und die App schwieg dazu**: `protokollDerKlasse(...).catch(() => [])`
    machte aus „darf nicht" ein „noch nichts da". Seit 1.5.2 steht bei
    NICHT_ERLAUBT ein stehender Kasten mit den drei Schritten, und die
    Fälle „abgeschaltet" und „noch niemand hat geübt" sagen sich getrennt.
    Kein `catch`, der einen Rechtefehler in Leere verwandelt.
  - Gedeckelt auf sechs Falschschreibungen je Wort und 500 Wörter je Kind
    (`store.js`). Mehr sagt nichts Neues und lädt bei jedem Päckchen mit hoch.
  - **Abschaltbar je Klasse** (`klasse.protokoll === false`) und löschbar
    (Knopf in der Klassenansicht). Das sind Leistungsdaten namentlich
    genannter Kinder — beides nicht wegrationalisieren.
  - **Zwei Ansichten, und die zweite hängt am Namen des Kindes**: „Was der
    Klasse schwerfällt" (Knopf) fasst alle zusammen, ein Tipp auf den NAMEN
    zeigt das einzelne Kind. Der Name muss deshalb wie ein Knopf aussehen —
    📋, gepunktete Unterstreichung, dazu ein Satz über der Liste (ab 1.5.3).
    Bis dahin war er nur eingefärbt, und der Nutzer fragte, ob es die
    Einzelansicht überhaupt gibt (08/2026), obwohl sie seit 1.0.5 steht.
  - **Gezeigt werden nur die Wörter, die danebengingen** (ab 1.7.1). Die
    vollständige Liste „Saß auf Anhieb" darunter war gut gemeint und im Weg:
    Wer nachsieht, sucht Fehler (Ansage des Nutzers, 08/2026). Was gesessen
    hat, sagt eine Zeile. Dieselbe Regel gilt für die Klassenübersicht — und
    die Kopfzeile nennt die Zahl der GEZEIGTEN Wörter, nicht die aller.
  - Das Kind sieht seine eigene Liste unter „?" → „Deine schweren Wörter". Wer
    die Daten erzeugt, darf sie sehen.
- **Sterne gehen weiterhin an die Klasse**, und keine Rangliste zwischen
  Kindern, nirgends.
- **CSS schreibt keine deutschen Wörter groß** (ab 1.7.1). `text-transform:
  uppercase` macht aus „Saß auf Anhieb" ein „SASS AUF ANHIEB" — die
  Großschreibregel für ß ist SS, und der Browser wendet sie an. In einer
  Rechtschreib-App ist das ein Fehler wie jeder andere: Ein Kind liest dort
  ein falsch geschriebenes Wort (gemeldet 08/2026: „geht gar nicht!").
  `seite__abschnitt`, `abschnitt__titel` und `wortzeile__formfeld` zeichnen
  sich deshalb über Gewicht, Farbe und Sperrung aus. Die kleinen festen
  Marken („GESCHRIEBEN ALS") dürfen bleiben — dort steht nie ein ß, und wer
  eine neue anlegt, prüft genau das.
- **Kein `alert`, `confirm` oder `prompt`** — in einer späteren WKWebView-Hülle
  passiert dabei schlicht nichts. Für Ja/Nein gibt es `frage()`, für eine
  Eingabe `eingabe()`, beide in `js/ui.js`.
- **Alles Plattformnahe läuft über `js/plattform.js`** — Sprachausgabe, Haptik,
  Zwischenablage, Bildschirm wach halten, Vollbild. Das ist die einzige Datei,
  die eine native Hülle bedienen müsste; wer irgendwo direkt
  `speechSynthesis` aufruft, verschiebt die Portierungsarbeit von einer Datei
  auf alle. Der Weg zu einer iOS-App steht in `docs/woerterwerkstatt/ios.md`.
- **Blau, Orange, Gelb — kein Grün, kein Lila** (Ansage des Nutzers, 08/2026).
  Blau ist die Arbeitsfarbe (Knöpfe, Fokus, Wortbild), Orange und Gelb sind
  die Belohnung (Sterne, Fortschritt, Auftrag der Woche, Konfetti). Die fünf
  Stufen laufen kühl → warm mit; Nomen blau, Verben orange, Adjektive gelb.
  Zwei Fallen dabei:
  - **Nie einen Verlauf von Blau nach Orange.** Die liegen auf dem Farbkreis
    gegenüber und treffen sich in schmutzigem Grau. Deshalb trägt jedes Schema
    in `SCHEMATA` (`js/store.js`) seinen Verlauf ausgeschrieben, statt ihn aus
    `von/mitte/bis` zu rechnen: Die drei sind die Hintergrundwolken (dort
    dürfen Blau und Orange nebeneinander), `verlauf` und `warm` bleiben je in
    EINER Farbfamilie. `theme.js` reicht beide nur durch.
  - **„Richtig" ist blau statt grün** — deshalb steht vor jeder Rückmeldung ein
    Zeichen (✓ / ↻ / ✗). Die Farbe darf die Antwort begleiten, tragen muss sie
    das Zeichen und der Wortlaut. Nicht wieder entfernen.
- Schriften liegen als woff2 in `woerterwerkstatt/fonts/` (Andika, Lexend,
  Quicksand — alle mit einstöckigem a und g) und werden **nie** von fremden
  Servern geladen. Die App-Icons erzeugt `scripts/generate-icons.py`.
- **Das Homescreen-Icon braucht PNG ohne Alphakanal** (Farbtyp 2, ab 1.4.0).
  Mit Alphakanal legt iOS das Icon auf Schwarz, und mancher Android-Starter
  zeigt gar keins. Erzeugt werden sie von `scripts/generate-icons.py`
  (dreizehn Größen plus zwei maskierbare) — nie von Hand. Im Manifest stehen
  die PNGs VOR dem SVG: Ein SVG mit `"sizes": "any"` gewinnt sonst die Auswahl
  und wird beim Installieren nicht gerastert. iOS liest kein Manifest, es
  braucht `apple-touch-icon` im `index.html`, mit `sizes` je Größe.
- **Der vorgeschlagene Name steht an ZWEI Stellen** (ab 1.8.2): iOS nimmt
  `apple-mobile-web-app-title` aus dem `index.html`, Android `short_name` aus
  dem Manifest. Beide sagen „Wörterwerkstatt" — bis 1.8.1 stand dort „Wörter",
  und genau das schlug das iPad beim Ablegen vor (gemeldet 08/2026). Dass iOS
  unter dem Symbol nach rund zwölf Zeichen abschneidet, ist in Kauf genommen:
  Der Vorschlag soll die App benennen, nicht schon zurechtgestutzt sein —
  ändern kann man ihn beim Ablegen ohnehin. Fehlt das Meta ganz, nimmt iOS den
  `<title>`, und der trägt den Untertitel mit.
- Die Fassungsnummer steht in `js/version.js` UND in `sw.js` (`FASSUNG`) — der
  Service Worker lädt keine Module. Beide bei jeder neuen Fassung hochsetzen,
  sonst bleibt der alte Zwischenspeicher stehen.

## Projekt Terminkonverter (Web-App, Excel → iCal)

- Code: `terminkonverter/` — statische Web-App ohne Bauschritt (ES-Module,
  kein Framework, keine fremde Bibliothek), wird vom Pages-Arbeitsablauf mit
  ausgeliefert: https://katonid.github.io/prae/terminkonverter/
  Nimmt eine Tabelle mit Datum und Beschreibung und gibt eine `.ics` aus.
  Ausführlich: `terminkonverter/README.md`.
- **Der xlsx-Leser ist selbst geschrieben** (`js/zip.js`, `js/xlsx.js`).
  Entpackt wird mit `DecompressionStream('deflate-raw')`, wo der Browser es
  mitbringt, sonst mit dem eigenen Inflate daneben — den Rückfall nicht
  entfernen, sonst bleibt die App auf älteren Geräten stumm. Keine
  Bibliothek nachladen: Das bräche Offlinebetrieb und Datensparsamkeit.
- **Ob eine Zahl ein Datum meint, steht in .xlsx am ZAHLENFORMAT, nicht am
  Wert.** Deshalb wird `styles.xml` mitgelesen (`DATUM_FORMATE` plus eigene
  Formate mit d/m/y). Ohne das ist der 31.08.2026 einfach 46265.
- **Die .ics wird nach OKTETTEN gefaltet, nicht nach Zeichen** (`falte` in
  `js/ics.js`). Ein Umlaut zählt zwei; eine mitten im Zeichen geteilte Zeile
  macht aus „für" Buchstabensalat.
- **Die fertige Datei wird als `application/octet-stream` ausgegeben**, nicht
  als `text/calendar` (`herunterladen` in `js/app.js`). Bei `text/calendar`
  schiebt Safari die Termine sofort in die Kalender-App, und die Datei selbst
  liegt nirgends — genau das war die Beschwerde (08/2026). Was die Datei ist,
  sagt die Endung `.ics`; ein Doppelklick öffnet weiterhin den Kalender.
  Daneben stehen zwei Auswege: „Teilen / In Dateien sichern" über
  `navigator.share` (auf iPhone und iPad der einzige Weg zu „Sichern"; der
  Knopf zeigt sich nur, wenn `navigator.canShare` Dateien annimmt) und „Text
  anzeigen" zum Kopieren. **Kopiert wird der gemerkte Text, nicht der Inhalt
  des Textfeldes** — ein Textfeld gibt seinen Wert mit `\n` zurück, in eine
  `.ics` gehören `\r\n`.
- **Zeiten stehen ohne Zeitzone** („schwebend"). Eine mitgelieferte
  VTIMEZONE brächte hier nichts und müsste bei jeder Zeitumstellung stimmen.
  Ganztägige Termine enden am ERSTEN Tag danach (so will es RFC 5545).
- **Gesucht wird die Datumszelle, nicht die erste Spalte.** Welche Spalte
  links steht, ist dadurch gleich. Zeilen ohne erkennbares Datum werden
  nicht still verschluckt, sondern als „Übergangene Zeilen" angezeigt — eine
  stillschweigend fehlende Zeile im Kalender fällt erst auf, wenn der Termin
  vorbei ist.
- Eine Uhrzeit in der Beschreibung wird nur mit Doppelpunkt oder dem Wort
  „Uhr" übernommen. „3.45" in einem Text ist meist eine Zahl und keine
  Viertel vor vier.

## Projekt Klassenraum (Web-App)

- Code: `klassenraum/` — statische Web-App ohne Build-Schritt (ES-Module,
  kein Framework), wird vom bestehenden GitHub-Pages-Workflow mit
  ausgeliefert: https://katonid.github.io/prae/klassenraum/
- GitHub Pages läuft für dieses Repo über „GitHub Actions" (Workflow
  `pages.yml`). Der Workflow spiegelt `docs/` zusätzlich an die Wurzel,
  damit die alten Adressen `/soundboard/` (App-Store-Links) und
  `/flightmate-ai/` gültig bleiben — diese Zeile nicht entfernen.
- Ersetzt den kostenpflichtigen Dienst „Classroomscreen“: Zufallsnamen,
  Timer/Stoppuhr, Uhr, Ampel, Tagesablauf, Text, Bild, Lautstärkemesser,
  Arbeitssymbole — frei verschiebbar auf einer Tafelfläche.
- Alles liegt lokal (IndexedDB). Es geht nur dann etwas ins Netz, wenn ein
  Teilen-Code erstellt oder ein Konto genutzt wird.
- Cloud läuft über die REST-Schnittstellen von Firebase (Realtime Database
  + Identity Toolkit) mit `firebase-config.js` aus dem Wurzelverzeichnis —
  kein SDK laden, das bricht den Offline-Betrieb.
- Drei Cloud-Wege, die nicht vermischt werden dürfen: **Teilen** (ein Board
  unter `klassenraum/shares/<CODE>`), **Abgleich** (alle Boards und Listen als
  Einzeldatensätze unter `klassenraum/spaces/<Kennung>`, Klang-/Videodateien
  base64-kodiert unter `klassenraum/media/<Kennung>/<Datei-Id>` — bewusst
  NEBEN dem Bereich, damit der volle Bereichsabruf sie nicht mitlädt;
  `js/sync.js`) und **Konto/Sicherung** (`klassenraum/users/<uid>`). Der Abgleich führt pro
  Datensatz nach Zeitstempel zusammen („neuer gewinnt") und schickt
  Löschvermerke mit; die letzte verbliebene Tafel wird nie gelöscht.
- `klassenraum/firebase-rules.json` enthält die empfohlenen Datenbankregeln
  (kein Auflisten von `shares`/`spaces`/`links`). Sie müssen in der
  Firebase-Konsole eingefügt werden — Standard ist offen.
- Konten brauchen eine einmalige Freischaltung in der Firebase-Konsole
  (Authentication → E-Mail/Passwort). Ohne sie zeigt die App einen Hinweis;
  Teilen per Code funktioniert trotzdem.
- Die App-Icons erzeugt `klassenraum/scripts/generate-icons.py` — nicht von
  Hand bearbeiten.
- Schriften liegen als woff2 in `klassenraum/fonts/` und werden über
  `css/fonts.css` eingebunden — **nie** von Google-Servern nachladen (bricht
  Offline-Betrieb). Ausgewählt sind nur Schriften mit einstöckigem a/g
  (Grundschulform); Vorgabe ist Lexend, Auswahl in `js/fonts.js`.

## Projekt Tafelbild (Klassenraum-Tafel, native iOS-App)

- App-Code: `TafelbildiOS/` (ein Target: App, iPhone + iPad, iOS 17).
  Native Ersatz-App für „Classroomscreen": frei anzuordnende Elemente
  (Zufälliger Name, Timer, Uhr, Ampel, Lautstärke, Tagesablauf, Text,
  Bild, Klänge) auf mehreren Tafeln, teilbar per Einladungslink.
  (Nicht verwechseln mit der Web-App `klassenraum/` — beide existieren
  nebeneinander.)
- `MARKETING_VERSION` steht an zwei Stellen im pbxproj (Debug +
  Release). **Jede Arbeitseinheit (= jeder PR mit App-Änderungen) hebt
  die Patch-Nummer um +1 an** — ohne Nachfrage, als Teil des PRs
  (1.0.1 → 1.0.2 → 1.0.3 …). Größere Sprünge nur auf ausdrückliche
  Ansage des Nutzers.
- **1.1.0 ist die Fassung für den App Store** (Ansage des Nutzers,
  08/2026): erste Fassung mit Freigabe per Einladungslink und privatem
  iCloud-Abgleich. Danach zählt es wie gewohnt weiter — 1.1.1, 1.1.2 …
- **Klänge: zwei Wege, mit Absicht.** Die Ziehklänge sind echte
  Aufnahmen (`TafelbildiOS/scripts/fetch-sounds.py`, CC0) — Synthese klang dort
  synthetisch, weil Kartenmischen und Ratsche Vorgänge aus hundert
  Zufälligkeiten sind. Die **Endklänge des Timers** (`endklang-*.wav`)
  rechnet dagegen `TafelbildiOS/scripts/make-endklaenge.py` aus, ohne fremde Dateien
  und ohne Netz: Ein angeschlagenes Metall IST eine Summe abklingender
  Teiltöne auf seinen Eigenfrequenzen. Beide Ordner nicht von Hand
  bearbeiten.
- **`TimerContent` hat einen eigenen Leser** (`extension TimerContent`
  in `Models.swift`). Ein neues Feld muss dort in `TimerKeys` UND in
  `init(from:)` eingetragen werden, sonst wird es nie gelesen — der
  Schreiber wird erzeugt und merkt davon nichts. Der gewählte Endklang
  steht als **Rohwert** (Zeichenkette) darin, nicht als Aufzählung: So
  übersteht eine Tafel einen Klang, den diese Fassung noch nicht kennt.
- Die **Build-Nummer vergibt die Skript-Bauphase „Build-Nummer setzen"**
  automatisch (Anzahl der Git-Commits, sonst Datumsstempel) — wie in
  Tagesspur, nie von Hand pflegen. Damit ist jeder TestFlight-Upload
  garantiert neuer als der vorherige. Dafür steht im Target
  `ENABLE_USER_SCRIPT_SANDBOXING = NO` — nicht entfernen.
- `ITSAppUsesNonExemptEncryption = NO` steht doppelt: in
  `Config/Info.plist` und als Build-Einstellung
  `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption` — nicht entfernen,
  erspart die Export-Compliance-Frage bei jedem TestFlight-Build.
### Abgleich (seit 1.0.58 private Datenbank)

- Generische `Entity`-Records in der **privaten** CloudKit-Datenbank, in
  einer eigenen Zone `Tafeln`. Vorher war es die öffentliche — dort konnte
  der Entwickler jeden Datensatz einsehen. **Nicht zurückdrehen:** Daran
  hängen die Datenschutzangaben, `PrivacyInfo.xcprivacy` und
  `docs/tafelbild/datenschutz.html`.
- Gelesen wird über **Änderungsmarken** (`CKFetchDatabaseChangesOperation` +
  `CKFetchRecordZoneChangesOperation`) aus **beiden** Datenbanken, der
  privaten und der geteilten. Eine geteilte Tafel liegt im Bereich
  derjenigen, die sie geteilt hat — eine Abfrage auf den eigenen Bereich
  fände sie nie.
- **Kein Index und keine Sicherheitsrolle** in der CloudKit-Konsole nötig;
  beides galt nur für die öffentliche Datenbank. Nötig bleibt einmalig
  „Deploy Schema Changes to Production".
- **Herkunft:** Die Engine merkt sich je Datensatz den Bereich
  (`sync.herkunft`) und schickt Änderungen über die richtige Datenbank
  zurück. Ein Push-Paket geht immer in genau einen Bereich.
- **Dateien hängen an der Tafel** (`parent`), sonst reisen sie bei einer
  Freigabe nicht mit. Erst die Tafel hochladen, dann die Dateien — ein
  Verweis auf einen Datensatz, den es noch nicht gibt, wird abgewiesen.
- Geteilt wird über `CKShare` mit `publicPermission = .readWrite`:
  Einladungslink, Schreibrecht sofort, keine Rechteabfrage (Ansage des
  Nutzers, 08/2026). Dazu Widerrufen, Teilnahme beenden und „Als eigene
  Tafel übernehmen" — eine abgekoppelte Kopie samt KOPIEN der
  Namenslisten unter neuen Kennungen. Der Einladungscode ist ersatzlos
  entfallen.
- **Die App muss sich als deutsch ausweisen.** `DEVELOPMENT_LANGUAGE = de`
  im pbxproj sowie `CFBundleDevelopmentRegion` und `CFBundleLocalizations`
  in `Config/Info.plist`. `developmentRegion = de` allein genügt nicht —
  Xcode setzt sonst „en", und weil die App keine Sprachdateien mitbringt,
  zeigt iOS ALLES Systemeigene englisch: Teilen-Blatt, Dateiwähler,
  „Abbrechen"/„Fertig" (gefunden 1.0.59). Nicht entfernen.
- **Der Vorbereitungs-Rückruf des Teilen-Blattes muss schnell sein.**
  Nachrichten und Mail warten darauf und zeigen so lange eine Sanduhr; wer
  dort erst noch alles Wartende hochlädt, bekommt „Es konnte kein Link zum
  Teilen erstellt werden". Das Hochladen gehört vor das Öffnen des Blattes
  (`BoardStore.tafelHochladen`), der Rückruf legt nur noch die Freigabe an.
- **Die Freigabe steht, bevor Apples Blatt aufgeht** (seit 1.1.1): erst
  `bereiteFreigabeVor`, dann `UICloudSharingController(share:container:)`.
  Der Erzeuger mit Vorbereitungs-Rückruf, den 1.0.61 bis 1.1.0 nutzten,
  ist seit iOS 17 veraltet.
  Dass ein vorab angelegtes Objekt in 1.0.58/1.0.59 ohne Adresse blieb
  („Link kopieren" kopierte nichts), lag NICHT am Vorab-Anlegen, sondern
  an zwei anderen Dingen: Der Record-Typ `cloudkit.share` fehlte im
  Schema, und weitergereicht wurde das hingeschickte statt des
  zurückgemeldeten Objekts. Beides ist behoben; `legeFreigabeAn` gibt
  seither nichts mehr heraus, was keine `url` hat.
  Fehler werden **roh** durchgereicht: Das Blatt zeigt Apples Wortlaut,
  der die bessere Spur ist als eine eigene Übersetzung.
- **Kein „offen"-Merker für ein fremdes Blatt.** `UICloudSharingController`
  meldet das Sichern und das Beenden der Freigabe, aber nicht das
  Zumachen. Ein Flag bleibt danach hängen und der Knopf tut nichts mehr.
  Stattdessen schwach halten und `presentingViewController` prüfen.
- Einladungen nimmt `FreigabeSceneDelegate` entgegen
  (`windowScene(_:userDidAcceptCloudKitShareWith:)`) — den Rückruf gibt es
  nur an der Szene. Er trägt `var window: UIWindow?`, beantwortet aber
  `scene(_:willConnectTo:options:)` NICHT: Wer das tut, verdrängt die
  `WindowGroup` von SwiftUI. Für andere Szenen-Rollen gibt
  `configurationForConnecting` die Konfiguration aus der `Info.plist`
  zurück, sonst bliebe der Beamer schwarz. Dazu `CKSharingSupported`.
- **Teilnehmer kommen aus der Freigabe, nicht aus `Board.members`**
  (`CloudSyncEngine.teilnehmer`, ab 1.1.7). In `members` tragen sich die
  Beteiligten mit dem Namen aus ihren Einstellungen selbst ein — das ist
  eine Anzeige, keine Liste von Rechten. Wer wirklich Zugriff hat, weiß
  nur iCloud. Einzeln entziehen geht über `share.removeParticipant` und
  Sichern der Freigabe; die Besitzerin lässt sich nicht entfernen.
- **Löschrecht auf geteilten Tafeln** (`Loeschrecht`, ab 1.1.4): Vorgabe
  ist „jede löscht nur Eigenes". Dafür trägt jedes Element `erstelltVon`
  (iCloud-Kennung); **leer heißt „vor 1.1.4 angelegt" und zählt der
  Besitzerin** — die vorsichtige Richtung, es geht nichts verloren.
  Durchgesetzt wird es an DREI Stellen, und die dritte ist die
  entscheidende: in der Oberfläche (Knopf weg), in
  `BoardStore.removeWidget`/`seiteLoeschen` (Meldung statt Tat) und in
  `Board.mitFremdemInhalt` — dort bleiben Elemente stehen, die die
  schreibende Person nicht löschen durfte, und der Stand geht zurück.
  Nur so hält die Regel auch gegen ein Gerät mit älterem Stand, das sie
  gar nicht kennt. Die Regel selbst gehört der Besitzerin
  (`zusammengefuehrt` stellt sie auf deren Gerät wieder her).
- **Das Geburtstags-Hinweiskärtchen rechnet nicht mit `metrics.em`.** Das
  Maß kommt von der vorgesehenen Größe des Elementtyps, und die ist die der
  großen Feierseite (820 × 560); ein Kärtchen ist 280 × 110, also rechnete
  `em` mit einem Fünftel und machte Symbol und Schrift winzig. Gemessen
  wird die Karte selbst, damit sie gefüllt ist.
- **Mitteilungstöne nur aus `Library/Sounds`** (`Weckdienst`, ab 1.1.6).
  `UNNotificationSound(named:)` sucht an genau zwei Stellen: ganz oben im
  App-Bündel und in `Library/Sounds`. Wo eine Datei im Bündel landet,
  entscheidet bei einem synchronisierten Ordner aber Xcode — liegt sie in
  einem Unterordner, spielt iOS **gar nichts**, ohne Fehlermeldung (so
  war 1.1.5 stumm). Die App kopiert die Klänge deshalb selbst dorthin.
  Kein `interruptionLevel = .timeSensitive`: Das braucht eine eigene
  Berechtigung im Profil.
- **Ob die Tafel beim Zurückkommen noch klingt, entscheidet ein
  Zeitvergleich**, keine Liste zugestellter Meldungen: Was vor
  `Weckdienst.aktivSeit` ablief, hat iOS gemeldet. Die Liste kam über
  einen Rückruf und war langsamer als der Zeittakt der Tafel — der Klang
  lief doppelt.
- **Was aus der eigenen privaten Datenbank kommt, gehört mir** (ab 1.3.28).
  `applyRemote` trägt jede angekommene Tafel in `ownBoardIDs` ein — bei
  einer fremden, weil sie sonst unsichtbar bliebe; bei einer eigenen, weil
  die private Datenbank ausschließlich Eigenes enthält.
  Vorher entschied bei einer eigenen Tafel allein `ownerUserID`,
  `memberUserIDs` und der Anzeigename. Alle drei sind leer, wenn die Tafel
  angelegt wurde, bevor die iCloud-Kennung feststand oder ein Name
  eingetragen war — und dann blieb sie auf dem **zweiten Gerät für immer
  unsichtbar** (nachgewiesen 08/2026 an „Meine Klasse", 12 Elemente).
  Das ist zugleich die wahrscheinlichste Wurzel doppelter Tafeln: Was man
  auf dem zweiten Gerät nicht sieht, legt man dort noch einmal an.
- **Die Herkunft entscheidet, nicht die Besitzerkennung** (ab 1.3.31).
  1.3.29 fragte die Herkunft nur, wenn `ownerUserID` **leer** war. Trägt sie
  dagegen eine Kennung, die es auf diesem Gerät nicht mehr gibt — nach einem
  Wechsel der CloudKit-Umgebung —, galt die eigene Tafel weiter als fremde:
  Löschen beendete nur die Mitgliedschaft, und `nimmVerwaisteAn` nahm sie
  einen Augenblick später wieder an. Die Tafel kam also immer zurück
  (gemeldet 08/2026). `deleteBoard` prüft jetzt `istGast`.
- **`nimmVerwaisteAn` stellt `ownerUserID` gleich mit richtig.** Sichtbarkeit
  allein reicht nicht: An der Kennung hängen auch das Löschrecht der Tafel
  und das der einzelnen Elemente. Mit fremder Kennung ist eine Tafel zwar zu
  sehen, aber halb gelähmt. Der Vermerk reist über `mitFremdemInhalt` zum
  zweiten Gerät und heilt es mit.
- **Auch schon vorhandene Tafeln werden angenommen** (`nimmVerwaisteAn`, ab
  1.3.30). 1.3.28 trägt jede *ankommende* Tafel als eigene ein — eine, die
  längst auf der Platte liegt und nie mehr über den Abgleich hereinkommt,
  erreicht diese Stelle nie. „Meine Klasse" blieb deshalb auch nach 1.3.28
  unsichtbar. Beim Start gilt jetzt dieselbe Regel für den Bestand.
- **Der häufigste Grund für eine verwaiste Tafel ist der Umgebungswechsel.**
  Über Xcode installiert läuft die App gegen *Development*, über TestFlight
  gegen *Production* — und die Konto-Kennung ist in beiden eine andere. Was
  in der einen angelegt wurde, sieht in der anderen aus wie fremdes
  Eigentum. Deshalb darf `ownerUserID` allein nie über Sichtbarkeit oder
  Löschrecht entscheiden.
- **Löschen setzt eine Tafel ohne Besitzerkennung nicht mehr nur ab** (ab
  1.3.29). `deleteBoard` hielt eine Tafel ohne `ownerUserID` für fremd,
  sobald auch der Anzeigename nicht passte — und beendete dann nur die
  eigene Mitgliedschaft. Die Tafel verschwand aus der Liste, blieb aber auf
  allen Geräten und in iCloud stehen, und niemand kam je wieder an sie
  heran. Maßgeblich ist jetzt die Herkunft: Was in der eigenen privaten
  Datenbank liegt, gehört mir.
- **Bei gleichem Zeitstempel gewinnt Inhalt gegen Leere.** `applyRemote`
  verglich streng mit `>`; zwei Geräte auf derselben Millisekunde hingen
  damit für immer auseinander. Eng gefasst: Es wird nur Nichts durch Etwas
  ersetzt, nie umgekehrt — eine gelöschte Tafel kommt als Grabstein mit
  `deleted` und ist davon nicht betroffen.
- Die Bestandsaufnahme zeigt die Zeit **mit Sekunden**. Ohne sie sahen zwei
  Stände gleich alt aus, die es nicht waren — und genau daran hängt beim
  Abgleich die Entscheidung.
- **Sichtbarkeit** hängt an der iCloud-Kennung (`ownerUserID` /
  `memberUserIDs`) — nicht am Anzeigenamen. Eine empfangene Tafel trägt
  keine davon; sie wird beim Ankommen in `ownBoardIDs` eingetragen, sonst
  bliebe sie unsichtbar.

### Doppelte Tafeln — Bestandsaufnahme statt Vermutung (ab 1.3.27)

- Gemeldet 08/2026: Auf einem Gerät standen **zwei Tafeln desselben
  Namens** — eine mit Inhalt und wenigen Seiten, eine mit allen Seiten und
  ohne Inhalt, dazu eine dritte, leere. Am Quelltext allein war nicht zu
  entscheiden, welcher Weg die zweite angelegt hat: `applyRemote` legt eine
  Tafel nur an, wenn ihre **Kennung** unbekannt ist, und alle Wege, die
  eine Kopie anlegen (`duplicateBoard`, `alsEigeneUebernehmen`,
  Sicherung einlesen), vergeben neue Kennungen.
- Deshalb zeigt „Abgleich prüfen" jetzt **jede lokale Tafel mit Kennung,
  Elementen, Seiten, Herkunft und Zeitstempel** (`BoardStore.tafelbefunde`)
  samt „Liste kopieren". Ohne diese Angaben bleibt jede Erklärung eine
  Vermutung — und wer im Nebel die falsche Tafel löscht, löscht sie auf
  allen Geräten und in iCloud.
- `BoardStore.entdoppelt` legt beim Laden Tafeln mit **derselben** Kennung
  zusammen (neuerer Zeitstempel gewinnt, bei Gleichstand mehr Inhalt).
  Vorbeugend: Ein solcher Fall wurde nicht nachgewiesen, aber nur die erste
  Tafel einer Kennung bekäme je eine Änderung ab — jede Suche geht über
  `firstIndex`. Der Schaden wäre still und dauerhaft.

### Die Werkzeugleiste am gewählten Element (ab 1.3.25)

- Drei Lagen, in dieser Reihenfolge: **darüber** (Regelfall), **darunter**
  (wenn das Element oben klebt), **auf dem oberen Rand des Elements** (wenn
  beides nicht geht).
- Die dritte Lage ist neu. Ein hohes Element, das oben anfängt und unten
  aufhört — der Sitzplan also fast immer —, schob die Leiste nach unten,
  und dort standen die Seitenreiter (gemeldet 08/2026). Ein verdeckter
  Streifen des Elements ist der geringere Schaden als eine Leiste, die mit
  dem Seitenwechsler um dieselben Fingerbreiten ringt.
- `obererSaum` und `untererSaum` sind **Bildschirmpunkte durch den
  Maßstab**, keine Tafelpunkte: Kopfleiste und Seitenreiter schweben über
  der Tafel und werden beim Hineinzoomen nicht größer.

### Seiten ausblenden (ab 1.3.23)

- `BoardPage.versteckt`, **nur für dieses Gerät** — genau wie
  `BoardWidget.versteckt`. In `mitFremdemInhalt` wird der eigene Wert
  behalten, nicht der fremde übernommen; `seiteVerstecken` ruft **kein**
  `touch`, sondern nur `scheduleSave` (sonst beanspruchte die Tafel beim
  Abgleich einen Vorrang, den es nicht gibt, und lüde sich obendrein hoch).
- **`BoardPage` hat seit 1.3.23 einen eigenen Leser.** Der erzeugte
  verlangt jeden Schlüssel; ohne ihn scheiterte jede vorher gesicherte
  Tafel samt aller Seiten.
- Beim Bearbeiten stehen ausgeblendete Seiten blass im Reiter (sonst wären
  sie nicht zurückzuholen), im Unterricht sind sie weg — dieselbe Regel wie
  bei den Elementen. Die gerade gezeigte Seite bleibt immer im Reiter
  (`seiten(mitVersteckten:dazu:)`), auch wenn sie ausgeblendet ist.
- Die **letzte sichtbare** Seite lässt sich nicht ausblenden.

### Zurücksetzen auf „unbenutzt" (ab 1.3.21)

- Alles, was auf der Tafel abläuft, bleibt danach stehen — gezogener Name,
  Sitzordnung, gelaufene Feier, abgehakte Punkte. Im Unterricht ist das
  richtig; am nächsten Morgen nicht (Ansage des Nutzers, 08/2026).
- Die Regel steht **einmal** in `Model/Zuruecksetzen.swift`
  (`WidgetContent.benutzt` / `.unbenutzt`) und wird von beiden Menüs
  benutzt. Ein neuer Elementtyp mit Ablauf gehört dort eingetragen —
  sonst lässt er sich nie zurücksetzen.
- **Zwei Tiefen** (`Ruecksetztiefe`, ab 1.3.24). „Nur die Ergebnisse" ist
  die Vorgabe und lässt beim Zufälligen Namen `drawnIDs`, `zaehler` und
  `paare` stehen; „auch die gezogenen Namen" räumt sie mit weg. Ansage des
  Nutzers, 08/2026: „In der Regel möchte ich nur eine Grundansicht vor der
  Auslosung zeigen, aber trotzdem im Hinterkopf behalten, welche Namen
  bereits gezogen wurden." Für alle anderen Elementarten sind beide Tiefen
  dasselbe — dort gibt es kein Gedächtnis, nur einen Ablauf.
- Die tiefe Stufe steht im Tafelmenü **nur für die ganze Tafel** (sie ist
  der Neuanfang eines Halbjahres) und im Elementmenü nur beim Zufälligen
  Namen. Zwei gleichbedeutende Punkte im Menü sind schlimmer als einer.
- **Zurückgesetzt wird der Ablauf, nie die Einrichtung** (Namensliste,
  Grundriss, Dauer, Farben) und **nie ein Archiv**: `ziehungen` und
  `Sitzplan.archiv` sind ein Nachweis, kein Zustand.
- Das **Gedächtnis** des Zufälligen Namens (`zaehler`, `paare`) zählt zum
  Gebrauch und geht mit — es ist die Spur der letzten Wochen.
- **Drei Wege, und der Einstellungsweg ist der, den man findet** (ab
  1.3.26): Elementeinstellungen → Abschnitt „Zurücksetzen", das Menü des
  Elements, und ⋯ für Seite oder Tafel. 1.3.21 hatte nur die beiden Menüs
  — und der Nutzer fand es nicht (gemeldet 08/2026). Wer etwas an einem
  Element sucht, öffnet dessen Einstellungen.
- Zwei Wege: ⋯ → „Auf unbenutzt zurücksetzen" fragt nach dem Umfang
  (diese Seite / ganze Tafel), das Elementmenü setzt eines zurück. Beide
  sind ausgegraut, wenn nichts zu vergessen ist.
- Gefiltert wird über `Board.liegtAuf`, nicht über einen Vergleich der
  Kennung: Ein leeres `pageID` gehört zur ersten Seite.

### Wo die Geburtstage wohnen (ab 1.3.15)

- **Eigener Menüpunkt „Geburtstage"** (⋯ → Geburtstage), Blatt
  `Views/Sheets/Geburtstagsblatt.swift`. Bis 1.3.14 hing der Abschnitt
  hinten an „Tafel teilen" — historisch gewachsen, weil er zusammen mit
  dem Löschrecht entstand. Das Löschrecht gehört dorthin (es ist eine
  Frage des Zusammenarbeitens), die Geburtstage nicht: Der Nutzer fand
  den Fragenkatalog nicht (gemeldet 08/2026). Nicht zurückverlegen.
- Darunter liegt alles Geburtstägliche: Namensliste, Erinnerung samt
  Uhrzeit, **Fragenkatalog**, **Nachfeiern** und „Weggeräumte wieder
  anlegen".

### Geburtstagsritual (ab 1.3.11)

- Ein Tipp führt durch **drei Stationen**: Feier → drei Gratulanten →
  zwei Fragen; der vierte fängt von vorn an und zieht alles neu. Kein
  Knopf, kein Menü — die Lehrkraft steht vor der Klasse und hat eine Hand
  frei.
- **Jede Station braucht ihren eigenen Tipp** (ab 1.3.18). Bis 1.3.17
  traten die Gratulanten von selbst auf, sobald die Feier ausgelaufen war
  — sie gehörten dazu, war die Überlegung. In der Klasse ist das falsch
  herum: Nach der Torte wird geklatscht, gelacht und geredet, und mitten
  hinein schob sich die nächste Tafel (Ansage des Nutzers, 08/2026). Wann
  es weitergeht, entscheidet die Lehrkraft. `content.ritual` zählt
  seither 0 = noch nichts, 1 = Feier gelaufen, 2 = Gratulanten,
  3 = Fragen.
- **Die Feier bleibt stehen** (ab 1.3.20). Bis 1.3.19 verschwand sie am
  Ende und ließ eine leere Fläche zurück — die Seite sah aus, als wäre
  nichts gewesen. Gehalten wird aber **nicht das letzte Bild**
  (`Feierart.standbild`): Zum Schluss blendet fast alles aus, die Kerzen
  sind gelöscht und das Konfetti liegt am Boden. Je Art ein eigener Wert,
  abgelesen an den Zeitmarken in `Feierbild` — bei der Torte **vor** 0,58,
  sonst raucht es nur.
- **Oben der Name, in der Mitte die Feier, unten der Hinweis.** Der Hinweis
  „Antippen für die Gratulanten" steht unter dem stehen gebliebenen Bild
  (`hinweisUnten`), nicht auf einer eigenen leeren Seite. Solange ein
  Feierbild im Rahmen steht — laufend oder stehend —, rückt die
  Beschriftung nach oben (`zeigtFeier`, nicht `laeuft`).
- **Bei offener Ritualtafel wird die Beschriftung gar nicht gezeichnet.**
  Der Name steht in der Überschrift der Tafel selbst („Drei für …", „Such
  dir eine Frage aus, …"); die Beschriftung darunter schien sonst durch und
  legte sich quer über die Karten (gemeldet 08/2026). Der Grund der Tafel
  deckt zusätzlich mit 0,86 statt 0,55 ab.
- **Gezogen wird erst beim Tipp** auf die Station, nicht schon am Ende der
  Feier: Sonst stünde die Auslosung minutenlang fest, während die Klasse
  noch die Torte ansieht. Gibt die Liste niemanden her, wird die Station
  übersprungen — eine leere Tafel „Drei für dich" wäre schlimmer als
  keine.
- **Die Erinnerung verlangt nichts Schönes** (ab 1.3.17). „Erzähl von
  etwas Schönem, das ihr zusammen erlebt habt" war eine Hürde: Wer mit dem
  Geburtstagskind wenig zu tun hat, steht vor der Klasse und hat nichts zu
  sagen. Gefragt wird nur noch, was die beiden zusammen *gemacht* haben —
  und das hat man in einer Klasse immer. „Gemacht", nicht „erlebt": Ein
  Erlebnis ist ein Begriff, etwas gemacht zu haben ist eine Erinnerung.
- **Drei Kinder, drei Rollen** (Kompliment / Erinnerung / Wunsch) — die
  Rollen werden *gemischt*, nicht je Kind gewürfelt. Bei drei unabhängigen
  Würfen käme regelmäßig dreimal „Wunsch" heraus.
- Gezogen wird aus `activeEntries` **ohne das Geburtstagskind**; Pausierte
  bleiben draußen (wer krank ist, kann nichts sagen).
- Stand und Auslosung stehen im **Inhalt** (`ritual`, `gratulanten`,
  `rollen`, `fragen`), nicht in der Ansicht: Die Seite läuft auf dem
  Beamer, ein kurzes Verlassen darf nicht zurücksetzen, und ein zweites
  Gerät zeigt dasselbe. Namen und Fragen als **Text**, wie im
  Sitzplanarchiv.
- **Fragenkataloge liegen an der TAFEL** (`Board.fragenkataloge`), nicht
  in der App: Eine Klassenstufe gehört zur Klasse, und weil Tafeln ohnehin
  abgleichen, reisen sie zur Kollegin mit — ohne eigene Art von Datensatz.
  In `mitFremdemInhalt` mit übernommen (Inhalt gehört allen); der
  *gewählte* Katalog bleibt wie die übrigen Geburtstagseinstellungen
  örtlich. Vier Vorlagen (1. bis 4. Klasse) werden beim ersten Öffnen
  hineinkopiert — erst dann, damit eine Tafel ohne Ritual keine
  hundertvierzig Fragen mitschleppt.
- Der Fundus steht in `Model/Geburtstagsfragen.swift` (80 Fragen, vom
  Nutzer für die 4. Klasse zusammengestellt). **Zwei** zur Auswahl, nicht
  eine (das wäre eine Prüfungsfrage) und nicht drei (dann wird aus dem
  Aussuchen ein Abwägen).

### Nachfeiern (ab 1.3.9)

- Der Dienst sieht **immer nur den heutigen Tag** an — daran nichts ändern.
  Ein iPad, das sechs Wochen im Schrank stand, bekäme beim Einschalten
  sonst zwanzig Seiten auf einmal, darunter Kinder, die längst weg sind.
- Ferien-Geburtstage holt deshalb ein Mensch nach: `NachfeiernSheet`
  (Tafeleinstellungen → Geburtstage → „Nachfeiern"), Zeitraum vorbelegt
  mit sechs Wochen, Auswahl je Kind.
- **Der Wortlaut richtet sich nach dem Datum, nicht nach dem Anlegen** (ab
  1.3.32). Eine Seite entsteht am Geburtstag und bleibt danach stehen — das
  ist gewollt. „Heute Geburtstag" und „wird 8" stimmten dann aber nur an
  diesem einen Tag; am nächsten Morgen behauptete die Tafel etwas Falsches
  (gemeldet 09/2026: „Toni hatte gestern Geburtstag"). `istHeute` vergleicht
  Tag und Monat mit heute, `istVorbei` ist „nachgefeiert oder nicht heute".
- Drei Zeilen auf dem Kärtchen: **„Wir feiern nach"** (ausdrückliche
  Nachfeier), **„Heute Geburtstag"** (nur wirklich heute), **„Hatte
  Geburtstag"** (die Seite von gestern steht noch). Auf der Seite selbst
  wechselt „wird" zu „wurde", und der tatsächliche Tag wird eingeblendet —
  beides jetzt auch ohne `nachgefeiert`.
- **Das Hinweiskärtchen sagt „Wir feiern nach"** (ab 1.3.22). Bis 1.3.21
  trug es `nachgefeiert` gar nicht mit und behauptete „Heute Geburtstag"
  über einem Kind, dessen Tag im Juli war (gemeldet 08/2026). Schon
  stehende Kärtchen bessert `richteHinweiseAus` bei jedem Nachsehen aus —
  was gilt, weiß die zugehörige Feierseite. Ohne Datum auf dem Kärtchen:
  Neben Torte und Pfeil bleiben rund 160 Punkte, und zu kleine Schrift war
  dort schon einmal die Beschwerde.
- **Das Jahr kommt vom tatsächlichen Geburtstag**, nicht von heute
  (`Geburtstage.Vergangen.jahr`). Ein Kind, das im Dezember sieben wurde
  und im Januar nachfeiert, wäre sonst acht.
- Eine Nachfeier nimmt den Merker aus `geburtstagWeg` zurück — wer sie
  ausdrücklich noch einmal wählt, will sie auch sehen.
- `GeburtstagContent.nachgefeiert` schaltet auf der Seite „wird" auf
  „wurde" um und blendet den tatsächlichen Tag ein.

### Sitzplan (ab 1.3.0)

- Eigener Elementtyp, **nicht** ein Modus des Zufälligen Namens. Auslosen
  zieht aus einer Menge; der Sitzplan bildet eine Menge auf **Orte** ab,
  die zueinander in Beziehung stehen. Der Zufällige Name bleibt
  unangetastet (Ansage des Nutzers, 08/2026).
- Dateien: `Model/Sitzplan.swift` (Grundriss, Regeln, Content),
  `Model/Sitzverteilung.swift` (reine Rechnung, wie `Auslosung.swift`),
  `Views/Widgets/SitzplanWidgetView.swift`,
  `Views/Sheets/Sitzplanblatt.swift` (Einstellungen, Platz-Editor,
  Regelseite).
- **„Nah" ist der Abstand zweier Tischmitten in Tischbreiten** — die
  einzige Größe, die Nachbar (~1,0), gegenüber (1,0–1,5), schräg (~1,4),
  übernächster (2,0) und drei Plätze dazwischen (~4,0) ohne Sonderregeln
  abdeckt. Reihen und Spalten zu erkennen wäre die Alternative; das
  bräche, sobald die Tische nicht im Raster stehen — und genau das sollen
  sie dürfen. Ein Platz misst 8 × 6 Raumeinheiten (Vorgabe des Nutzers).
- **Die Rechnung wird sichtbar gemacht.** Ein Tipp auf einen Platz im
  Editor lässt alle Plätze aufleuchten, die als nah gelten. Nicht
  entfernen: Die ganze Verteilung hängt an dieser einen Zahl, und niemand
  soll ihr blind glauben müssen.
- **Regeln gehören der Namensliste** (`NameList.sitzregeln`), nicht dem
  Element: Dieselben Kinder sollen nicht nebeneinandersitzen, egal wie die
  Tische stehen. Je Kind stehen `sitzwunsch` und `alleine` am `NameEntry`.
- **Geschoben wird nur im Einstellungsblatt.** Auf der Tafel verschöbe
  dieselbe Ziehgeste das Element selbst.
- Verteilt wird durch **Suchen**, nicht Rechnen (Zuordnungsproblem mit
  Paarbedingungen, allgemein nicht exakt lösbar): mehrere zufällige
  Anfänge, von jedem aus tauschen, solange es besser wird. Erwünschter
  Nebeneffekt — es bleibt eine Auslosung. Gewichte: Trennen 1000,
  Alleinsitzen 700, Zusammensitzen 160, Richtungswunsch 150.
- **Die Tafel hängt an einer wählbaren Wand**, Vorgabe **unten** (Ansage
  des Nutzers, 08/2026). An ihr hängt, was „vorne" heißt: `Sitzverteilung`
  misst die Tiefe als Abstand zur Tafelwand, nicht an `y`. Sonst wären
  „möglichst vorne" und „hinten" bei einer Tafel unten verkehrt herum.
  `Sitzordnung.vorschlag` rechnet deshalb im Bezug zur Tafel („längs" /
  „weg") und dreht das erst zum Schluss auf x und y — vier Wände, eine
  Formel.
- **Zwei Blickwinkel, ein Raum** (`Blickwinkel`, ab 1.3.4). Umgeschaltet
  wird am **Bearbeitungsmodus**, nicht an einem Schalter (Ansage des
  Nutzers, 08/2026): Solange bearbeitet wird (`interactive == false`),
  liegt die Tafelwand dort, wo sie im Raum hängt — man steht an der Tafel
  und schaut in die Klasse. Ist es fertig, **dreht sich der Grundriss, bis
  die Tafelwand oben liegt**, denn dann schaut die Klasse darauf und für
  sie ist vorne oben. Dass links und rechts dabei tauschen, ist der Sinn der Sache: Wer
  nach Süden schaut, hat Osten zur Linken. Gedreht werden die
  **Koordinaten**, nicht die Ansicht — eine gedrehte Ansicht stellte auch
  die Namen auf den Kopf.
- **Der Grundriss-Stapel braucht `Color.clear` als erstes Kind.** Sonst
  ist der `ZStack` nur so groß wie sein größtes Kind (der Raum), und der
  liegt eingerückt. Was weiter rechts steht, wird gezeichnet, liegt aber
  ausserhalb der Grenzen — SwiftUI prüft beim Antippen erst den Elternteil,
  und was dort nicht hineinfällt, erreicht das Kind nie. In 1.3.5 waren
  dadurch alle Plätze rechts der Raumbreite unverschiebbar (gemeldet
  08/2026). Nicht entfernen.
- **Tische rasten ein, während sie gezogen werden** (`Sitzraster`, ab
  1.3.8), nicht erst beim Loslassen — sonst sieht es aus wie ein Sprung am
  Ende und man zielt doch von Hand. Abschaltbar
  (`@AppStorage("sitzplanRaster")`) — dann frei setzbar.
- **Die Kachel ist kleiner als der Tisch** (`Sitzmasse.fuge`, ab 1.3.19).
  Das Raster fängt Tische Kante an Kante; gezeichnet berührten sich zwei
  solche Kacheln dann auf den Punkt genau, und zwei helle Flächen mit
  gemeinsamer Kante liest das Auge als einen Stapel, nicht als zwei Tische
  (gemeldet 08/2026). Gezeichnet wird deshalb ringsum ein Viertel einer
  Raumeinheit kleiner — an allen drei Stellen gleich (Element, Editor,
  Archivansicht), sonst sähe der Editor anders aus als das Ergebnis. Der
  Mittelpunkt bleibt, wo er ist: Abstände, Nähe, Einrasten und
  Freiheitsprüfung rechnen unverändert mit dem ganzen Tisch. Wer zeichnet,
  nimmt `kachelmasse`; wer rechnet, `breite`/`hoehe`.
- **Fangpunkte sind die KANTEN der anderen Tische** (ab 1.3.12), nicht nur
  deren Mittelachsen. Die erste Fassung kannte nur Raster und Mittelachse
  und erzeugte damit genau die beiden gemeldeten Fehler: Die Mittelachse
  zog zwei Tische übereinander, und das Raster half nicht, weil
  `Sitzordnung.vorschlag` selbst nicht auf ihm liegt — dazwischen blieb
  eine krumme Lücke. Zusätzlich wird jede Lage auf **Freiheit** geprüft;
  was einen anderen Tisch überdeckte, wird nicht angeboten, und findet
  sich nichts, weicht der Tisch auf die nächste freie Kante aus.
- **`Sitzplatz.winkel` ist frei** (ab 1.3.8); `quer` bleibt als Altfeld
  daneben stehen und wird über `didSet` gespiegelt, sonst stünden auf
  älteren Geräten alle Tische wieder gerade. `breite`/`hoehe` sind immer
  8 × 6 — gedreht wird beim Zeichnen. Wer mit Fläche rechnet (Ausschnitt,
  freier Fleck), nimmt `umriss`; der Abstand zweier Plätze geht von Mitte
  zu Mitte und weiß vom Winkel nichts.
- **Der Raum ist seit 1.3.10 ein Viertel kleiner** (120×90 / 150×90 /
  90×120), der Tisch weiter 8 × 6 — so füllt er mehr Fläche und ist von
  Weitem zu lesen. Ältere Pläne rechnet der Leser um
  (`SitzplanContent.masstab`), **Plätze und `naehe` mit demselben Faktor**:
  Ohne das Mitziehen der Schwelle rückte jede Regel um ein Viertel enger.
- **Die Schrift auf einer Kachel dreht gegen** (`lesbar`). Die Kachel folgt
  Tischwinkel plus Blickwinkel; die Schrift nur so weit, wie sie lesbar
  bleibt (−90…+90 Grad). In 1.3.8 drehte sie voll mit — bei einer Tafel
  unten standen dadurch sämtliche Namen auf dem Kopf.
- **Gezeigt wird der Ausschnitt, nicht der ganze Raum** (ab 1.3.7):
  Plätze plus Tafel plus eine halbe Tischbreite Rand, auf den Raum
  begrenzt. Leere Ecken kosten sonst genau dort Platz, wo die Namen
  gebraucht werden — der Plan hängt an der Wand und wird aus zehn Metern
  gelesen.
- **Leere Plätze gehören nach hinten** (`gewichtLeer`). Das ist mehr als
  Kosmetik: „Platz daneben frei" heißt gemessen, also auch *gegenüber*.
  Ein solches Kind in einen Viererblock zu setzen legt dort drei Plätze
  still. Solange Leerstand nichts kostet, ist das dem Suchlauf egal; mit
  dem Gewicht hört der Viererblock vorne von selbst auf, eine gute Idee zu
  sein.
- **Gesichert wird von selbst** (ab 1.3.13, Ansage des Nutzers: „Ich habe
  Angst, dass ich bei manueller Speicherung diese häufiger vergessen
  werde."). Jede Auslosung legt sofort einen Eintrag an (`beginneArchiv`,
  Titel „KW 35 – 30.08.2026"), jeder Tausch schreibt ihn fort
  (`schreibeArchivFort`), erst die nächste Auslosung beginnt einen neuen.
  So entsteht je Sitzordnung genau ein Eintrag und nicht je Handgriff
  einer. Umbenennen geht in der Archivansicht.
- **Das Schloss gehört in die Ansicht** (ab 1.3.16). Es sitzt oben rechts
  in der Kopfzeile — und wenn die Beschriftung der Kachel abgeschaltet ist,
  als Überlagerung in der Ecke des Grundrisses. Bis 1.3.15 hing die ganze
  Kopfzeile an `style.showLabels`; wer die Beschriftung abschaltete, kam
  nur noch über die Einstellungen an das Schloss (gemeldet 08/2026). Titel
  und Zähler sind Beschriftung und dürfen verschwinden, ein Bedienelement
  nicht. Der Hinweis „Gesperrt" in der Fußzeile öffnet es ebenfalls.
- **Schloss und Archiv** (`gesperrt`, `archiv`): Eine fertige Sitzordnung
  steht wochenlang auf der Tafel; ohne Schloss wäre sie mit einem
  Fingerzeig neu ausgelost. Beim Sichern geht das Schloss von selbst zu.
  Gesichert werden **Namen als Text**, nicht Kennungen — wie bei
  `Ziehung`. Beim Zurückholen wird nur die Belegung gesetzt, nie der
  Grundriss.
- **Ein Archiv ohne Ansicht ist wertlos** (`SitzarchivAnsicht`, ab 1.3.12).
  Gesichert wird, um im November nachzusehen, wie die Klasse im September
  saß — dafür muss man es *sehen* können, nicht bloß zurückholen. Gezeigt
  wird der heutige Grundriss mit den Namen von damals; Namen, deren Platz
  es nicht mehr gibt, stehen unter dem Plan. Die Umrechnung auf die Fläche
  teilen sich Element und Ansicht (`Sitzflaeche`) — zwei Fassungen liefen
  mit Sicherheit auseinander.
- **Die Kerzen sind so viele, wie das Kind alt wird** (ab 1.3.14). Bis
  acht in einer Reihe, darüber zweireihig und nach hinten gestaffelt —
  sonst stehen sie Schulter an Schulter, und eine Klasse *zählt* sie.
  Gedeckelt bei 18.
- **„Namen tauschen" ist ein Knopf, keine graue Zeile.** In der ersten
  Fassung stand dort nur beschriftete Schrift und wurde übersehen
  (gemeldet 08/2026). Im Tauschmodus steht daneben, was zu tun ist.
- **Der Sitzplan feiert nicht.** Am Ende der Auslosung lief bis 1.3.5
  `Feierklang.spiele(.konfetti)` — Applaus und Geburtstagslied, aus dem
  Geburtstagsteil übernommen. Eine Sitzordnung ist kein Geburtstag; hier
  gehört ein betonter Kartenschlag hin und sonst nichts.
- **Der Platz-Editor liegt als Vollbild an der Wurzel**
  (`BoardStore.sitzplanWidgetID`, präsentiert in `RootView`), nicht als
  Unterseite des Einstellungsblattes. Ein Blatt ist auf dem iPad ein
  Kärtchen in der Bildschirmmitte; der Grundriss bekam darin ein Drittel
  der Höhe und ein Fünftel der Breite (gemeldet 08/2026). Nicht
  zurückverlegen.
- **Merkmale** (`merkmalID` + `merkmalsregel`) stehen am **Element**, nicht
  an der Liste — anders als die Paarregeln. Ob Jungen und Mädchen gemischt
  sitzen, ist eine Entscheidung für *diese* Sitzordnung; „Anna und Ben
  nicht nebeneinander" gilt überall. Dasselbe Muster wie
  `NamePickerContent.mischMerkmalID`. Das Merkmal wiegt als **Anteil**
  der unpassenden Nachbarschaften, nicht je Nachbarschaft: Sonst
  summierten sich vierzig kleine Verstöße zu mehr als eine harte Trennung.
- **Was nicht aufgeht, steht hinterher im Bericht**, im Klartext mit
  Namen und Zahlen. Diesen Rückweg nie stillschweigend entfernen: Ein
  Plan, der eine Trennung bricht, ohne es zu sagen, ist schlimmer als
  gar keiner.
- Der Sitzplan hängt wie der Zufällige Name an einer Liste. Deshalb steht
  er in `Board.referencedListIDs` **und** an den vier Stellen im
  `BoardStore`, die Listenkennungen mitführen (Vorbelegung beim Anlegen,
  Übernehmen einer fremden Tafel, Einlesen einer Sicherung,
  `fetchMissingNameLists`). Fehlt eine davon, reist die Liste beim Teilen
  nicht mit und die Kollegin sieht einen Plan ohne Namen.

### Ein Blatt, ein Dateiwähler — an der Wurzel, an SwiftUI vorbei

Vier Regeln, jede einmal teuer gelernt (`WidgetSettingsSheet`,
`Dateiwunsch`, `Dateiwahl`):

1. **Einer je Blatt.** Zwei streiten sich; einer gewinnt, der andere
   schweigt.
2. **An der Wurzel.** Ein `Form` ist eine `List` und baut ihre Zeilen erst
   auf, wenn sie in Sichtweite kommen — an einer Zeile mitten in der Liste
   ist der Wähler beim Tippen oft noch gar nicht da.
3. **Der Wunsch trägt das Ziel**, kein Schalter daneben. Zusammengezogen
   ist das Ziel beim Auswerten schon gelöscht; getrennt springt einer zu
   früh zurück.
4. **An SwiftUI vorbei zeigen** (`Dateiwahl`, `Freigabewahl`, `Oberflaeche`):
   UIKit präsentiert, UIKit schließt, das Ziel reist im Rückruf mit. **Das
   gilt für jedes Fenster eines fremden Dienstes** — den Dateiwähler UND
   Apples Teilen-Blatt (`UICloudSharingController`). Eingebettet in ein
   SwiftUI-`.sheet` bleibt das Teilen-Blatt schwarz (1.0.60, gemeldet);
   der Dateiwähler flackert. Jede Präsentation, die an
   einem Ansichtswert hängt (`.fileImporter`, `.sheet`), räumt SwiftUI
   beim Neuzeichnen des Formulars ab — der Schalter bleibt stehen, im
   nächsten Durchgang geht sie wieder auf: ein Flackern ohne Ende.
   `asCopy: true` spart zugleich den Zugriff auf fremde Ordner.

Wenn ein Wähler schweigt: **erst prüfen, ob die ANDEREN auch schweigen.**
Gehen sie, liegt es an der Stelle, an der dieser eine hängt — nicht an
etwas Großem, das zuletzt geändert wurde.
- Development (Xcode) und Production (TestFlight) sind getrennte
  CloudKit-Umgebungen — Geräte gleichen nur innerhalb derselben ab. Die
  Ansicht „Abgleich prüfen" in den Einstellungen zeigt, welche gilt.
- **Übersetzt wird in GitHub Actions**, nicht erst auf dem Mac: Der
  Arbeitsablauf `.github/workflows/tafelbild-build.yml` baut die App bei
  jedem Push auf `TafelbildiOS/` auf einem macOS-Läufer (xcodebuild,
  iOS-Simulator-SDK, ohne Signierung) und listet am Ende alle
  `error:`- und `warning:`-Zeilen auf.
- **Verbindlich für Claude: erst pushen, Bau abwarten, Fehler beheben —
  und den PR-Link erst herausgeben, wenn der Bau grün ist.** Nie wieder
  einen ungebauten Stand als fertig melden.
