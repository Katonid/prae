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
  **Kostenlos im öffentlichen App Store** (Ansage des Nutzers, 09/2026; bis
  1.0.34 war die Custom App über Apple School Manager und Jamf School der
  einzige Weg — der bleibt daneben bestehen). Bundle-Id `de.dboschule.alarm`.
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
  schreiben. **Seit 1.0.35 trägt der Beitrittscode das ALLEIN**: Bis dahin
  stand daneben, dass es die App nur auf verwalteten Schul-iPads gab, und im
  öffentlichen Laden gilt das nicht mehr. Was bleibt, ist Sichtbarkeit statt
  Türsteher (Beitrittsdatum in der Mitgliederliste, doppelte Kürzel markiert,
  Entfernen und Zurückziehen des Codes) und Datensparsamkeit (Kürzel statt
  Namen). Das steht so im README, in den Review-Notizen, auf der
  Datenschutzseite und in BACKEND_MIGRATION — **wer den Satz „nur an
  Schul-iPads" irgendwo wiederfindet, streicht ihn**; er ist seit dem
  öffentlichen Vertrieb schlicht falsch.
- **Indizes und Sicherheitsrolle sind hier NÖTIG** (anders als bei
  Tafelbild, das privat abgleicht): Ohne Queryable-Index scheitert jede
  Abfrage, ohne `_icloud`-Schreibrecht kann ein zweiter Admin nichts
  pflegen. Die Tabelle steht im README unter „CloudKit einrichten", dazu
  einmalig „Deploy Schema Changes to Production".
- **Sortiert wird nach dem Systemzeitstempel, aber IN DER APP** (ab 1.0.11).
  Nach `creationDate` und nicht nach dem eigenen `createdAt`, weil den der
  Server setzt und ein Gerät mit falscher Uhr ihn nicht verbiegen kann. Aber
  ohne `NSSortDescriptor`: Der verlangt einen SORTABLE-Index auf
  `___createTime`, und fehlt der, lehnt CloudKit die Abfrage ab — getroffen
  hätte es `activeAlarm`, also das AUSLÖSEN und den Nachfasslauf (gemeldet
  09/2026: „Field '___createTime' is not marked sortable"). Damit war der
  Alarm nicht auslösbar und das Netz unter den Subscriptions gerissen: Der
  Nachfasslauf hätte den Testalarm auch ohne Push gefunden. Die wichtigste
  Abfrage dieser App darf an keinem Häkchen in einer Web-Oberfläche hängen.
  `query()` nimmt deshalb gar keine Sortierung mehr entgegen.
- **Irgendwer muss anfangen: `createGroup`.** Bis 1.0.1 gab es nur
  `joinGroup` — das sucht einen Beitrittscode-Datensatz, der einen
  Group-Datensatz braucht, den nichts in der App je anlegte. Die App war
  damit gar nicht zu betreten (gemeldet 09/2026). Wer die Schule
  einrichtet, IST der erste Admin; der erste Beitrittscode entsteht gleich mit
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
- **`ensureSchema` läuft NUR als Rückfall, nicht bei jedem Start** (ab 1.0.27).
  Bis 1.0.26 schrieb `refreshSubscriptions` bei jedem Start vier Platzhalter —
  darunter einen vom Typ `Message`. Seit 1.0.21 gibt es das Abonnement
  `message-created-v1`, dessen Prädikat nur nach der Gruppe fragt: Jeder
  Platzhalter löste also auf ALLEN anderen Geräten eine Mitteilung aus,
  „Nachricht von Schema: Schema" (gemeldet 09/2026). Wer die App nur einmal
  öffnete, ließ dreißig iPads piepen. Die anderen drei Platzhalter waren von
  Anfang an harmlos, weil sie `targetUser = "schema"` tragen und die Alarm- und
  Ping-Prädikate `"*"` oder die eigene Kennung verlangen — beim
  Nachrichten-Abonnement gab es diesen Schutz nicht, und ein Prädikat lässt sich
  nachträglich nicht ändern. **Merke: Wer ein Abonnement hinzufügt, prüft, ob
  `ensureSchema` dessen Prädikat trifft.** Jetzt versucht `reconcile` es zuerst;
  `reconcile` kehrt von selbst um, wenn nichts fehlt, und die Platzhalter werden
  nur nach einem gescheiterten Anlegen geschrieben — also genau in dem Fall, für
  den sie gedacht waren.
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
- **CloudKit stellt dem SCHREIBENDEN Gerät nichts zu** (gefunden 09/2026).
  Alle fünf Abonnements angelegt, alle Prädikate abfragbar, APNs angemeldet —
  und der Selbsttest kam trotzdem nie an. Ein Gerät kann sich die Zustellung
  nicht selbst beweisen. Der Testalarm geht deshalb an ein ANDERES Mitglied
  (Verwaltung → Mitglieder → „Testalarm senden"), und der Haken „Zustellung
  geprüft" setzt sich auf dem EMPFANGENDEN iPad von selbst, sobald dort ein
  Push eintrifft (`store.letzterPush`). Einen Knopf, der auf einem einzelnen
  Gerät nie funktionieren kann, darf diese App nicht anbieten.
- **Eine gekoppelte Apple Watch fängt den Ton ab** (gefunden 09/2026). Wird
  sie getragen, leitet iOS die Mitteilung ans Handgelenk und das iPhone
  bleibt STILL — und die Uhr spielt nie den eigenen Ton einer App, sondern
  ihren Systemton. **Abstellen lässt sich das pro App** (ab 1.0.24 in der
  Prüfliste): App „Watch“ → Mitteilungen → „Mitteilungen von iPhone spiegeln“
  → Schulalarm aus. Es ist eine Einstellung des GERÄTS: Eine App kann die
  Spiegelung nicht selbst abschalten und auch nicht auslesen, ob sie aus ist.
  Deshalb steht die Zeile auf iPhones als Anleitung mit `.unknown` da und
  nicht als Häkchen — und auf einem iPad gar nicht, dort gibt es keine
  Spiegelung. Die Dienst-iPads haben keine Uhr; für den Test gilt es
  trotzdem. Zweite Falle daneben: der Lautlos-Schalter — ohne kritische
  Hinweise bleibt auch eine zeitkritische Meldung stumm.
- **Klingeltonlautstärke ist NICHT Medienlautstärke** (gefunden 09/2026).
  Ein Mitteilungston hängt an der Klingeltonlautstärke; die
  Lautstärketasten regeln die Medien, solange etwas spielt — also auch
  während der Tonprobe. „Ton direkt abspielen geht, die Mitteilung bleibt
  stumm" ist damit kein Widerspruch, sondern der Normalfall bei
  heruntergeregeltem Klingelton. Auslesen lässt sich der Wert nicht (keine
  öffentliche API), deshalb steht er als erster Punkt in der Anleitung und
  nicht als Häkchen.
- **Der Tontest kann auch mit dem Standardton** (ab 1.0.9). Das ist der
  Vergleich, der die letzte Zweideutigkeit auflöst: Standardton hörbar und
  Alarmton nicht heißt, iOS mag die Datei als Mitteilungston nicht; beide
  stumm heißt, es liegt am Gerät. Ohne diesen Vergleich stehen beide
  Erklärungen nebeneinander und keine lässt sich aus der Ferne ausschließen.
- **Die Tonprobe spielt an den Mitteilungen vorbei** (`Tonprobe`, ab 1.0.8).
  Sie spielt dieselbe Datei über AVFoundation in der Kategorie `playback` —
  das klingt auch bei stummem Gerät. Damit trennt sich „iOS kann die Datei
  nicht lesen" von „das Gerät darf gerade nicht laut werden"; ohne sie standen
  drei Erklärungen nebeneinander und keine ließ sich ausschließen. Die
  Berechtigungen stehen aus demselben Grund im kopierbaren Befund und nicht
  nur in der Prüfliste.
- **Töne sind WAV, nicht CAF.** Der von Hand geschriebene CAF-Container war
  formal in Ordnung (`file` erkannte ihn, `desc`- und `data`-Block stimmten)
  — iOS spielte trotzdem den Standardton. Was es nicht laden kann, ersetzt
  es stillschweigend, ohne Fehler. Geschrieben wird jetzt mit Pythons
  `wave`-Modul: kein fremdes Paket, aber auch nichts Selbstgebasteltes.
  Und die Diagnose schlägt die Datei im Bündel nach und nennt ihre Größe —
  „kommt an, aber leise" sieht sonst genauso aus wie ein falscher Dateiname.
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
- **`aps-environment` MUSS zur Umgebung passen — zwei Entitlements-Dateien**
  (ab 1.0.18). `Config/Alarm.entitlements` (Debug) sagt `development`,
  `Config/Alarm-Release.entitlements` (Release) sagt `production`; im pbxproj
  zeigt jede Konfiguration auf ihre. Bis 1.0.17 stand `development` für beide,
  und das kostete einen Abend: Über TestFlight ist der Container Production,
  der Push-Client war Development, und CloudKit wies daraufhin JEDES Abonnement
  ab — auch eines ohne Prädikat und ohne Meldung — mit „attempting to create a
  subscription in a production container". **Die Meldung zeigt auf den
  Container und meint das Profil.** Alle Abfragen waren grün, alle Prädikate
  abfragbar; es sah nach einem Fehler bei Apple aus und war einer von uns.
  Die Diagnose nennt deshalb seit 1.0.18 die APNs-Umgebung und meldet ROT, wenn
  sie nicht zur Umgebung passt. **Über TestFlight und aus dem Laden liegt aber
  gar kein Profil im Bündel** — Apple signiert dort neu und entfernt es (ab
  1.0.19 abgefangen). Dann bleibt die Bau-Konfiguration als Quelle, und die
  Zeile sagt dazu, woher ihr Wert stammt: gelesen oder erschlossen. Eine
  Auskunft über den Bau als Messung auszugeben wäre genau die Art Lüge, die
  diese Diagnose nicht erzählen darf. Keine der beiden
  Dateien darf die andere ersetzen: Ein Debug-Bau mit `production` meldet sich
  bei der falschen APNs-Umgebung an.
- **Wo eine Fehlermeldung nur auf die Umgebung zeigt, muss eine PROBE
  entscheiden** (`stufenprobe`, `CloudKitSubscriptions.stufen`, ab 1.0.17).
  Scheitert das Anlegen, legt die Diagnose drei Abonnements an, die sich um je
  EINE Sache unterscheiden — schlicht (nur `groupRef`, nackte Meldung), mit
  vollem Prädikat, mit Meldung —, und löscht jedes sofort wieder. Die erste rote Zeile
  sagt, wovon der Fehler abhängt: von Abonnements überhaupt (dann ist es Apples
  Sache), vom Prädikat (Index) oder von der Meldung (dann ist es unsere).
  Dasselbe Muster wie bei den Prädikatsproben in 1.0.4: Eine Diagnose, die den
  Fehler bloß wiedergibt, ist die Frage von vorhin noch einmal.
- **`ensureSchema` verschluckte seine Fehler** (bis 1.0.16 `await` ohne `try`).
  Es gibt sie jetzt zurück, und die Diagnose zeigt sie — ein blinder Fleck
  genau dort, wo die Zustellung hängt: Ein Record-Typ, den es in Production
  nicht gibt, lässt sich dort auch nicht durch Schreiben anlegen.
- **Ein NEUES FELD braucht einen Deploy — in Production entsteht keines durch
  Schreiben** (getroffen 09/2026 mit `alarmId` auf `Message`, eingeführt in
  1.0.21). Der Befund war eindeutig, seit `ensureSchema` seine Fehler zurückgibt:
  „Cannot create or modify field 'alarmId' in record 'Message' in production
  schema", und daraufhin lehnte CloudKit das Abonnement ab, weil seine
  `desiredKeys` ein Feld nennen, das Production nicht kennt („could not find
  requested additional field"). **Nach jeder Fassung, die ein Feld oder einen
  Record-Typ hinzufügt, gehört „Deploy Schema Changes to Production" dazu** —
  in der Konsole, von Hand, und die App kann es nicht für einen erledigen. Die
  Diagnose sagt diesen Satz seit 1.0.23 im Klartext unter dem Rohtext.
- **`NSPredicate(value: true)` ist in Production verboten — und die Meldung
  dazu lügt.** Ein Abonnement ohne Prädikat wird abgelehnt mit „attempting to
  create a subscription in a production container", also mit demselben Satz,
  der 1.0.18 einen Abend gekostet hat. Nachgewiesen 09/2026: Stufe 1 der
  Stufenprobe rot, Stufen 2 und 3 im selben Durchgang angenommen. Damit war die
  Probe selbst die Irreführung — sie war in Production IMMER rot. Stufe 1 fragt
  seit 1.0.23 mit dem einfachsten GÜLTIGEN Prädikat (nur `groupRef`).
  **Merke: Dieser eine Fehlertext hat mindestens zwei Ursachen** — ein
  `aps-environment`, das nicht zur Umgebung passt, und ein Abonnement ohne
  Prädikat. Er zeigt auf den Container und meint beide Male etwas anderes.
- **Development und Production trennen auch die DATEN, nicht nur die Indizes.**
  Über Xcode installiert läuft die App gegen Development, über TestFlight gegen
  Production. Eine über Xcode eingerichtete Schule gibt es in der
  TestFlight-Fassung nicht — die App merkt sich Gruppe und Rolle aber ÖRTLICH
  und übersteht damit die Neuinstallation: Sie sieht eingerichtet aus, während
  in Production nichts steht. Prüfstein ist die Mitgliederliste. Deshalb nennt
  die Diagnose seit 1.0.16 als zweite Zeile die vermutete Umgebung
  (`umgebungsvermutung` — geraten am Beleg im Bündel, denn `CKContainer` gibt
  sie nicht her).
- **„Diesen Beitrittscode gibt es nicht" heißt oft: nicht in DIESER Umgebung**
  (`Umgebung.swift`, ab 1.0.31). Gemeldet 09/2026: Schule über TestFlight
  eingerichtet, Kollegium beigetreten, alles lief — und auf einem per Xcode
  angeschlossenen iPad wurde derselbe Code abgewiesen. Der Beitrittscode IST
  der Name seines Datensatzes, und in Development gibt es diesen Datensatz
  nicht; `joinGroup` bekommt `.unknownItem` und meldet wörtlich richtig, dass
  es den Code nicht gibt. Als Auskunft war das irreführend — der Nutzer suchte
  den Fehler im Update. Die Meldung nennt den Riss deshalb jetzt selbst, samt
  der Umgebung, in der diese Fassung läuft, und derselbe Satz steht unter dem
  Codefeld. **Der Riss geht in BEIDE Richtungen**, deshalb kein `#if DEBUG` um
  den Hinweis: Welche Seite gerade fehlt, weiß die App nicht.
- **`Umgebung.beschreibung` ist die eine Quelle** für „Development oder
  Production". Vorher stand die Logik nur in `CloudKitBackend.umgebungsvermutung`
  für die Diagnose; die Fehlermeldung braucht sie genauso, und zwei Fassungen
  wären zwei Wahrheiten. `umgebungsvermutung` reicht seither nur noch durch.
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
- **Wer beitritt, wird MITGLIED — nie Admin** (ab 1.0.13). Bis dahin
  wurde die erste Person einer noch leeren Gruppe automatisch zum Admin.
  Gedacht als Notausgang, tatsächlich eine Rechtevergabe, die niemand
  angeordnet hat (gemeldet 09/2026: „das andere Gerät wurde automatisch zu
  einem Leitungs-Gerät, das will ich gar nicht"). Admin wird man auf genau
  zwei Wegen: die Schule einrichten, oder von einem Admin ernannt werden.
  Die Zahl der Admins ist unbegrenzt. Eine Ausnahme, die keine ist: Hat
  das Konto hier schon ein Mitglied, behält es seine Rolle — sonst verlöre
  ein Admin seine Rechte beim Neuinstallieren.
- **Ein Kürzel darf der Admin berichtigen** (`setDisplayName`, ab 1.0.25).
  Getippt wird es beim Beitreten, und dabei passiert alles. Die Kennung des
  Mitglieds bleibt dabei UNVERÄNDERT — sie ist abgeleitet
  (`member-<Gruppe>-<Nutzer>`), und daran hängen Rückmeldungen und Geräte.
  Alte Rückmeldungen behalten das Kürzel von damals: Sie sind ein Nachweis,
  kein Zustand. Damit die Änderung auf dem betroffenen Gerät ankommt, übernimmt
  `AppModel.uebernimmEigenesMitglied()` bei jedem Start und jeder Rückkehr in
  den Vordergrund, was der Server über das eigene Konto sagt — Rolle UND
  Kürzel. Ohne das schriebe das Gerät seine nächste Rückmeldung weiter unter
  dem alten, und die Änderung wäre nur in der Mitgliederliste zu sehen.
- **Ein Kürzel gehört einer Person — abgewiesen wird das KÜRZEL, nicht der
  Beitritt** (ab 1.0.28). Wer ein schon vergebenes Kürzel tippt, wird beim
  Beitreten abgelehnt (`Member.vergleichbaresKuerzel`: Groß/Klein und
  Leerzeichen zählen nicht, **Umlaute werden NICHT eingeebnet** — „MU“ und „MÜ“
  sind zwei Personen), dieselbe Prüfung noch einmal in `setDisplayName`. Das
  eigene Mitglied ist ausgenommen, sonst käme niemand nach einer Neuinstallation
  zurück. **Die naheliegende Bestätigung durch das schon angemeldete Gerät ist
  bewusst NICHT gebaut** (Vorschlag des Nutzers, 09/2026): Steht dieses iPad im
  Schrank, bliebe eine Lehrkraft im Ernstfall stumm — in einer Alarm-App ist
  Aussperren der größere Schaden als ein doppeltes Kürzel. Und sie hielte
  niemanden auf, der ein freies Kürzel nimmt. Die Kontrolle ist deshalb
  **Sichtbarkeit**: Die Mitgliederliste nennt seit 1.0.28 das Beitrittsdatum und
  markiert noch vorhandene Doppel; ein unerwarteter Eintrag wird entfernt und der
  Beitrittscode zurückgezogen.
- **Das Gerät heißt, wie es heißt** (`Services/Geraetename.swift`, ab 1.0.36,
  gemeldet 09/2026). Auf einem iPhone stand „Dieses iPad ist nicht
  einsatzbereit" — die App war für dreißig Dienst-iPads gebaut, und die Texte
  sagten das wörtlich. Ein Warnband, das vom falschen Gerät redet, liest sich
  wie ein Fehler in der App. **Die Regel für JEDEN neuen Text:** Geht es um
  DIESES Gerät, steht dort `Geraetename.wort` („iPad", „iPhone", sonst
  „Gerät"); geht es um IRGENDEIN Gerät (eine Aussage über die Schule, ein
  anderes Mitglied, zwei Geräte an einer Apple-ID), steht dort schlicht
  „Gerät" — ein „iPad" wäre da nicht bloß unpassend, sondern falsch, denn der
  Satz gilt für jedes Gerät. Grammatisch geht das auf, weil iPad, iPhone und
  Gerät alle sächlich sind. Kein `default`-Zweig mit Rateversuch: Läuft die App
  eines Tages auf einem Mac, ist „Gerät" richtig und „iPad" gelogen.
- **Die Kamera folgt der Lage des GERÄTS, nicht der des Sensors**
  (`QRCodeView.richteVorschauAus`, ab 1.0.36, gemeldet 09/2026). Auf einem quer
  gehaltenen iPad stand das Kamerabild hochkant, und ein fremder Beitrittscode
  ließ sich kaum treffen. Eine `AVCaptureVideoPreviewLayer` beginnt immer im
  Hochformat — die Verbindung übernimmt die Lage der Oberfläche NICHT von
  selbst. **Erkannt hätte die Kamera den Code trotzdem**: Gesucht wird im
  Sensorbild, und das ist von der Anzeige unabhängig. Genau das macht den
  Fehler zäh — nichts ist kaputt, es lässt sich nur nicht zielen; für den
  Menschen davor ist das dasselbe. Gesetzt wird der Winkel bei jedem Layout,
  also auch beim Drehen. Zwei Dinge dabei: **Gefragt wird die Szene DIESER
  Ansicht** (`view.window?.windowScene`), nie `connectedScenes` — das ist eine
  ungeordnete Menge, und hängt ein Beamer am iPad, greift `first { … }` mal die
  eine und mal die andere (derselbe Fehler wie bei Tafelbilds
  Dokumentenkamera). Und **die Winkel sind Apples eigene Entsprechungen** aus
  der Abkündigung von `videoOrientation` (portrait 90, portraitUpsideDown 270,
  landscapeLeft 180, landscapeRight 0), nicht selbst nachgerechnet: Die
  Bezugslage der Kamera ist Querformat, und 180 Grad daneben fällt nur auf
  einem echten Gerät auf. Der iOS-16-Weg steht in einer eigenen, als veraltet
  markierten Funktion — `#available` schaltet eine Abkündigungswarnung nicht
  ab, die hängt an der Übersetzung.
- **Der eigene Alarm bleibt auf dem eigenen iPad stumm** (`istEigenerAlarm`, ab
  1.0.34, gemeldet 09/2026). Der örtliche Nachfasslauf `AlarmReminder` fragt
  nicht, wessen Alarm er anschreit — das auslösende Gerät schlug 30 Sekunden
  später selbst an und dann noch neunmal. Wer auslöst, steht am Ort; in einer
  Gefahrenlage ist ein Ton aus der eigenen Tasche das Letzte, was gebraucht
  wird. Verglichen wird `alarm.triggeredByUserId` mit der eigenen Kennung
  (`member?.userId ?? store.userId` — persistiert, weil beim Start der Alarm
  schon dasteht, bevor die Mitgliedsabfrage zurück ist). **Beide müssen gefüllt
  sein:** leer heißt „weiß ich nicht", und dann wird laut — ein Ton zu viel ist
  der kleinere Schaden. Angezeigt wird unverändert ALLES, samt einer Zeile auf
  dem Alarm-Bildschirm, die die Stille erklärt; ein iPad, das ohne Grund
  schweigt, hält man für kaputt. **Ein zweites Gerät desselben Kontos schlägt
  einmal an**: CloudKit stellt nur dem SCHREIBENDEN Gerät nichts zu, und die
  Erweiterung kann den Auslöser nicht kennen (eigener Behälter, keine
  App-Gruppe, `desiredKeys` mit drei Feldern voll). Das über das Prädikat zu
  lösen (`triggeredByUserId != …`) ist bewusst NICHT gebaut — dann hinge die
  Zustellung an einem weiteren Queryable-Index, und fehlt der, entsteht kein
  Abonnement und das Gerät ist für immer stumm. Die wichtigste Kette dieser App
  wird nicht für einen einzelnen Ton verlängert.
- **Austreten gibt es, Mehrfachmitgliedschaft nicht** (`leaveGroup`, ab 1.0.33,
  Ansage des Nutzers 09/2026). Einstellungen → „Verbindung zur Schule lösen".
  Ein Gerät gehört zu genau EINER Schule; ein Wähler „an welche Schule geht
  dieser Alarm?" wurde ausdrücklich verworfen — im Ernstfall ist jede
  Zusatzfrage eine zu viel. Der Musikschullehrer an drei Schulen ist ein
  Sonderfall, den diese App bewusst nicht bedient.
- **Die TESTSTRECKE ist kein eigener Modus, sondern der Austritt** (Wunsch des
  Nutzers 09/2026: „einen zweiten Kanal … an anderen Geräten, die nicht an der
  Schule registriert sind"). Ein Mitglied ist die Apple-ID, die aktive Schule
  steht ÖRTLICH je Gerät (`store.groupId`), und `member-<Gruppe>-<Nutzer>`
  trägt die Gruppe im Namen — dasselbe Konto kann also in zwei Gruppen ein
  Mitglied haben, ohne dass sich etwas überschreibt. Ein zweites Gerät tritt
  aus und richtet eine eigene Testschule ein; das Haupt-iPad bleibt unberührt.
  **Dafür braucht es keinen Umschalter und keine zweite Datenhaltung** — wer
  einen baut, holt sich genau die Auswahlfrage zurück, die hier nicht sein soll.
- **Beim Austritt muss BEIDES weg, sonst gar nichts** (`CloudKitBackend.leaveGroup`).
  Bleibt das Mitglied stehen, zählt der Admin im Ernstfall jemanden mit, der
  nichts mehr bekommt — die gefährlichere Hälfte. Bleiben die Abonnements
  stehen, klingelt das Gerät weiter für eine fremde Schule, und `reconcile`
  räumt sie NIE wieder ab, weil es dafür eine Gruppe bräuchte
  (`CloudKitSubscriptions.entferneAlle`). Scheitert ein Schritt, bleibt alles
  wie es war: Ein Austritt ist nie eilig, und auf eine Verbindung zu bestehen
  ist billiger als ein halb gelöster Zustand, den niemand mehr sieht.
- **Der letzte Admin darf weder entfernt werden noch austreten**
  (`pruefeLetztenAdmin`, in BEIDEN Backends). Ohne Admin ist eine Schule tot —
  `createInviteCode`, `setRole`, `updateLocations` und die Entwarnung fragen
  alle `requireAdmin()`, und aus der App heraus gibt es keinen Weg zurück. Ist
  er das EINZIGE Mitglied, ist es kein Ausfall, sondern das Ende der Schule;
  dann geht es.
- **„Kein Mitglied gefunden" und „konnte nicht nachsehen" sind NICHT dasselbe**
  (`AppModel.Mitgliedschaftsstand`, ab 1.0.33). Ein `try?` wirft den
  Unterschied weg, und ein Netzaussetzer sähe dann aus wie ein Rauswurf. Nur
  eine GELUNGENE Abfrage, die nichts fand, setzt `.fehlt` — dieselbe Regel wie
  beim Alarm-Bildschirm. **Und auch dann meldet sich die App nur**: Die
  Prüfliste zeigt die Zeile rot, gelöst wird von Hand. Ein Gerät, das sich
  selbst abmeldet, wäre im Ernstfall stumm, ohne dass es jemand gemerkt hat.
- **Ein Admin entfernt ein Mitglied über einen KNOPF**, nicht nur über die
  Wischgeste (ab 1.0.33) — dieselbe Lehre wie beim Gruppenchat. Sich selbst
  entfernt man dort nicht: Nur der Austritt in den Einstellungen räumt auch die
  Abonnements DIESES Geräts ab, und die erreicht kein fremdes iPad.
- **Ein Mitglied ist eine APPLE-ID, kein iPad.** Zwei iPads mit derselben
  Apple-ID sind EIN Mitglied mit EINER Rolle, und eine Rückmeldung lässt
  sich ihnen nicht einzeln zuordnen (`ack-<Alarm>-<Nutzer>`). Jede Lehrkraft
  braucht eine eigene Apple-ID. Sichtbar wird der Fall in der
  Geräteübersicht: `DeviceStatus` heißt seit 1.0.13
  `device-<Gruppe>-<Nutzer>-<Gerät>` und zählt die Geräte je Kürzel — vorher
  überschrieben sich zwei iPads gegenseitig, und der Admin erfuhr nie,
  dass es zwei sind.
- **Ein Fehlerband unter einem Blatt sieht niemand** (behoben in 1.0.26). Die
  drei Bänder (Hinweis, Problem, Wiederholung) hingen ausschließlich an
  `RootView`; Verwaltung, Einstellungen und Auslösen sind aber BLÄTTER und
  liegen darüber. Aufgefallen beim Ernennen eines zweiten Admins: „Das Drücken
  des Textes zeigt keine Funktion" — der Knopf meldete sehr wohl einen Fehler,
  nur erschien der hinter dem Blatt. Die Bänder liegen jetzt in
  `Views/Meldungen.swift` und werden über `.meldungen(model)` an die Wurzel UND
  an jedes Blatt gehängt. **Wer ein neues Blatt baut, hängt sie mit dran.**
  Dazu meldet sich seit 1.0.26 auch der Erfolgsfall: Ein Knopf, der schweigt,
  ist für den Menschen davor ein kaputter Knopf.
- **Es ist NIE nur ein Record-Typ** (`mappedFremderDatensatz`, ab 1.0.37).
  1.0.26 rückte `.permissionFailure` für `Member` gerade, weil es dort zuerst
  auffiel. 09/2026 kam derselbe Satz beim **Entwarnen des Alarms einer
  Kollegin**: „Nur ein Admin darf das" — gemeldet von einem Admin. Ein Alarm
  gehört dem, der ihn ausgelöst hat, und `Alarm` war derselbe blinde Fleck.
  Betroffen sind ALLE Wege, die auf fremde Datensätze schreiben: `clearAlarm`
  (`Alarm`), `updateGroup` (`Group`, also Standorte und Handlungstexte eines
  ZWEITEN Admins), `revokeInviteCode` (`InviteCode`) und das Aufräumen
  (`Alarm`, `Ack`, `Message`). Die Erklärung steht deshalb einmal in
  `mappedFremderDatensatz` und nennt den Typ, um den es gerade geht, dazu einen
  Satz, was ohne das Häkchen NICHT geht. **Wer einen neuen Schreibweg auf einen
  fremden Datensatz baut, hängt ihn dort ein und nicht an `mapped`.** Und:
  `clearAlarm` ruft bewusst kein `requireAdmin()` — wer entwarnen darf,
  entscheidet `mayClear`; jedes `.notPermitted` von dort kommt also von
  CloudKit und nie von uns.
- **Das Aufräumen zählte die ABSICHT, nicht das Ergebnis** (bis 1.0.36).
  `modifyRecords` wirft nur, wenn der ganze Aufruf scheitert; einzelne
  Ablehnungen stehen in `deleteResults`, und die warf `cleanUp` mit `_ =` weg.
  Gemeldet hätte es „12 Alarme gelöscht", während keiner gelöscht war — und der
  wahrscheinlichste Grund ist genau der Punkt darüber: ohne WRITE räumt ein
  Admin nur das Eigene weg. Dasselbe Muster wie bei `modifySubscriptions` in
  1.0.4. **Wo CloudKit ein Ergebnis je Element zurückgibt, IST das Ergebnis die
  Fehlermeldung** — gezählt wird seither, was wirklich weg ist, und bleibt alles
  liegen, sagt die App es.
- **`.permissionFailure` beim Schreiben auf einen FREMDEN Datensatz heißt etwas
  anderes** (`mappedMitgliedsschreiben`, ab 1.0.26). In der öffentlichen
  Datenbank gehört ein Datensatz dem, der ihn angelegt hat; der Mitgliedseintrag
  einer Kollegin gehört ihr. Ohne WRITE für die Rolle `_icloud` auf `Member`
  kann kein Admin einen zweiten ernennen, ein Kürzel berichtigen oder jemanden
  entfernen. `mapped` machte daraus „Nur ein Admin darf das" — den einen Satz,
  der hier garantiert falsch ist. Jetzt nennt die Meldung den Weg durch die
  Konsole.
- **Zwei Admins, nicht einer** (`setRole`). Ein einziger Admin ist ein
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
- **Was ein Hintergrundereignis beendet, gehört auf den HAUPTFADEN**
  (`BackgroundRefresh`, behoben in 1.0.20). `BGTask.setTaskCompleted` und der
  Rückruf von `didReceiveRemoteNotification` schließen für iOS ein
  Hintergrundereignis ab; UIKit schreibt daraufhin den
  Wiederherstellungsstand fort und macht ein Bildschirmfoto. Beides prüft den
  Hauptfaden — und bricht sonst ab: `SIGABRT` aus
  `_performBlockAfterCATransactionCommitSynchronizes:`. Ein nacktes `Task { }`
  in einem nicht isolierten Rückruf erbt KEINEN Actor und landet im
  Nebenläufigkeits-Pool; im Absturzprotokoll steht dann
  `com.apple.root.user-initiated-qos.cooperative` statt `com.apple.main-thread`
  (gemeldet 09/2026). Also: `using: .main` beim Anmelden, `Task { @MainActor in }`,
  und ein Wächter, der genau EINMAL fertigmeldet — ein zweites
  `setTaskCompleted` quittiert iOS ebenfalls mit einem Abbruch. Der Absturz
  sah nach dem Alarm-Bildschirm aus und kam von der Auffrischung; die Zeile
  mit der Warteschlange im Protokoll ist die, die es entscheidet.
- **Ein `async`-Delegat von UserNotifications ist eine FALLE** (behoben in
  1.0.22). `userNotificationCenter(_:didReceive:)` in der `async`-Fassung sieht
  harmlos aus; Swift baut daraus die Fassung mit Rückruf, und der Rückruf läuft
  auf dem Faden, auf dem die async-Funktion ENDET — nach einem
  `await MainActor.run` also im Nebenläufigkeits-Pool. Mit dem Rückruf endet
  für iOS ein Hintergrundereignis, UIKit macht Bildschirmfoto und
  Wiederherstellungsstand, und beides bricht abseits des Hauptfadens ab.
  Kennzeichen im Feld: **Absturz nur beim Tippen auf die Mitteilung, nie beim
  Öffnen über das Symbol** (gemeldet 09/2026). Also immer die Fassung MIT
  Rückruf schreiben und ihn am Ende eines `Task { @MainActor in }` aufrufen.
  Dieselbe Wurzel wie `BackgroundRefresh` in 1.0.20 — wo ein Rückruf ein
  Hintergrundereignis abschließt, gehört er auf den Hauptfaden.
- **Ein Knopf, der „Fertig" heißt, verschluckt Nachrichten** (1.0.22). Im
  Nachrichtenblatt stand oben „Fertig" und unten ein Papierflieger-Symbol; der
  Nutzer tippte zweimal „Fertig" und hielt die Nachricht für gesendet. Jetzt
  heißt der Knopf oben „Schließen", das Senden ist ein breiter Knopf mit dem
  Wort **Senden**, die Eingabetaste sendet ebenfalls, ein Hinweis unter dem
  Feld sagt „noch nicht gesendet", und beim Schließen mit Text im Feld fragt
  die App nach. **Im Ernstfall wäre das dreißigmal passiert.**
- **Die Nachrichten stehen OFFEN auf dem Alarm-Bildschirm** (ab 1.0.22), in
  einer Karte wie die Rückmeldungen — nicht hinter einem Tipp. Wer diesen
  Bildschirm liest, liest ihn unter Druck und tippt nicht auf Verdacht. Die
  Zahl „ungelesen" gibt es deshalb nur noch auf der Karte „Alarm läuft" auf
  dem Startbildschirm, also genau dann, wenn der Alarm-Bildschirm zur Seite
  gelegt ist.
- **`DefaultInstructions.locations` ist eine VORLAGE, kein Bestand.** Was eine
  Schule benutzt, steht auf ihrem Group-Datensatz; eine neue Fassung der App
  ändert das nie von selbst. Deshalb gibt es seit 1.0.22 unter Verwaltung →
  Standorte den Knopf „Vorlage einsetzen" — sonst müsste jemand sechzehn
  Einträge am iPad abtippen.
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
- **Der Zustellnachweis darf die Einrichtung NICHT sperren** (ab 1.0.10).
  Er war Bedingung für „Einrichtung abschließen" — und damit zirkulär: Der
  Nachweis braucht einen Push von einem anderen Gerät, den schickt die
  ein Admin aus der Verwaltung, die Verwaltung liegt hinter dem
  Startbildschirm, der lag hinter „Einrichtung abschließen". Niemand kam
  mehr hinein, auch der Admin nicht, der die Schule gerade angelegt hatte
  (gemeldet 09/2026). Gesperrt wird nur noch, was dieses eine Gerät selbst
  lösen kann (`ChecklistItem.blocksCompletion`); der Punkt bleibt rot, das
  Warnband bleibt stehen, und das iPad gilt weiter als ungeprüft.
  **Allgemein: Was ein zweites Gerät braucht, darf nie Bedingung für den
  ersten Start sein.**
- **Angekommen ist angekommen.** Der Haken „Zustellung geprüft" hängt an
  `store.letzterPush` und setzt sich auf dem EMPFANGENDEN Gerät von selbst.
  Bestätigen muss ihn niemand — ein Knopf „ist angekommen" wäre eine
  Behauptung, der Zeitstempel ist eine Tatsache.
- **Die Rolle heißt „Admin", nicht „Leitung"** (ab 1.0.14, Ansage des Nutzers,
  09/2026). Nur das Wort in der Oberfläche; der Rohwert der Aufzählung war
  immer schon `admin` und bleibt es — an ihm hängen Datensätze, die auf den
  Geräten liegen.
- **Die Namen der Rückmeldungen sehen Admin UND auslösende Person** (ab
  1.0.14, `AppModel.darfRueckmeldungenSehen`). Dieselbe Regel wie bei
  `mayClear` und aus demselben Grund: Wer ausgelöst hat, steht am Ort und
  muss wissen, wer sich noch nicht gemeldet hat — auf ein fremdes iPad zu
  warten hilft dort niemandem. Für alle anderen bleibt es bei der blanken
  Zahl; wer sich wann gemeldet hat, geht das Kollegium untereinander nichts
  an. **Unter der Liste steht, was sie NICHT ist:** Sie zeigt, wer
  geantwortet hat, nicht, wer den Alarm bekommen hat. Eine
  Zustellbestätigung gibt CloudKit nicht her, und ein Kürzel, das fehlt,
  darf nie als „hat es nicht bekommen" gelesen werden.
- **Keine iOS-App holt sich selbst in den Vordergrund** (Wunsch des Nutzers,
  09/2026: „Im Alarmfall soll die App sichtbar im Vordergrund sein."). Es gibt
  dafür keine Schnittstelle — nicht über kritische Hinweise, nicht über die
  Custom-App-Verteilung, nicht über Jamf School; ein Push kann eine App weder
  starten noch nach vorn bringen. Nach vorn kommt die MITTEILUNG, und ein Tipp
  darauf öffnet die App direkt auf dem Alarm-Bildschirm. Das nie anders
  darstellen. Was ein Gerät dauerhaft auf diese App festnagelt, ist der
  Einzel-App-Modus des MDM — sinnvoll für ein festes Gerät, unsinnig für das
  Arbeits-iPad einer Lehrkraft.
- **Ab dem Augenblick, in dem die App vorne IST, liegt der Alarm oben** (ab
  1.0.15). Drei Dinge dafür, und alle drei waren vorher falsch:
  - **Ein offenes Blatt macht sich zu** (`AppModel.offenesBlatt`,
    `zeigeAlarmBildschirm`). Ein Sheet und der `fullScreenCover` des
    Alarm-Bildschirms sind beide modal, und iOS zeigt davon zuverlässig nur
    das erste: Wer die Verwaltung offen hatte, sah beim Alarm weiter die
    Mitgliederliste. Deshalb liegt der Zustand der drei Blätter im Modell und
    nicht als `@State` in `HomeView` — im Alarmfall muss ihn jemand anderes
    zumachen können. Die 300 ms danach sind die Umdrehung, die SwiftUI zum
    Zumachen braucht; ohne sie verschluckt UIKit die zweite Darstellung.
  - **Der Bildschirm bleibt an, solange ein Alarm läuft**
    (`isIdleTimerDisabled` im `didSet` von `activeAlarm`). Ein iPad, das sich
    nach zwei Minuten sperrt, nimmt den Alarm-Bildschirm mit.
  - **„Zur Seite legen" bleibt liegen** (`zurueckgestellt`). Bis 1.0.14 setzte
    jeder Nachfasslauf `showsAlarmScreen` wieder auf `true` — der Knopf hielt
    also fünf Sekunden. Und er geht erst auf, NACHDEM jemand geantwortet hat:
    vorher wäre er eine Abkürzung an der einen Handlung vorbei, um die diese
    App gebaut ist. Ein neuer Alarm holt den Bildschirm immer zurück.
- **Den Gruppenchat gab es seit der ersten Fassung — gefunden hat ihn niemand**
  (Bitte des Nutzers 09/2026 um genau das, was schon da war). Der Knopf hieß
  „Nachrichten zum Alarm", stand UNTER der Rückmeldeliste und war auf einem
  vollen, scrollenden Alarm-Bildschirm unsichtbar. Seit 1.0.21 steht er direkt
  unter Rückmeldung und Notruf, heißt „Nachricht an das Kollegium", ist gefüllt
  gezeichnet und zählt ungelesene mit. Dieselbe Lehre wie beim Zurücksetzen in
  Tafelbild: **Ein Knopf, den niemand findet, ist kein Knopf** — und eine Bitte
  um etwas Vorhandenes ist ein Befund über die Oberfläche, keine Verwechslung.
- **Nachrichten kommen jetzt auch an, wenn die App hinten liegt**
  (`message-created-v1`, ab 1.0.21). Vorher holte sie nur der Nachfasslauf, und
  der läuft nur, solange die App vorn ist: Wer das iPad weggelegt hatte, erfuhr
  nichts. Das Abonnement ist bewusst ein eigenes und bewusst leiser — `.active`
  statt `.timeSensitive`, Standardton statt Alarmton, KEIN `collapseID` (jede
  Nachricht ist eine eigene und darf die vorherige nicht ersetzen; gruppiert
  wird über `threadIdentifier`). Und es holt den Alarm-Bildschirm NICHT zurück:
  Wer ihn zur Seite gelegt hat, hat das gemeint. Die drei `desiredKeys` sind
  `senderName`, `text`, `alarmId` — Letzteres als NAME, weil eine Referenz im
  Push als Wörterbuch ankommt und gegen die Dreiergrenze zählt.
- **Eine Rückmeldung beendet KEINEN Alarm** — das tut nur die Entwarnung.
  „Gesehen" heißt „ich weiß Bescheid", nicht „es ist vorbei". Genau eine
  Ausnahme: der gezielte Probealarm (Zustelltest). Der räumt sich mit der
  Rückmeldung selbst weg, sonst bliebe jeder Test für immer „aktiv" — und
  ein Stapel alter Tests wurde der Reihe nach zum laufenden Alarm, das iPad
  klingelte immer wieder (gemeldet 09/2026). Zusätzlich verfällt ein
  gezielter Probealarm nach zehn Minuten (`Alarm.giltNoch`): Er ist in
  Sekunden zu sehen oder gar nicht. **Echte Alarme verfallen nie** — ein
  Amokalarm, den seit zwei Stunden niemand entwarnt hat, ist gültig; die
  Entwarnung beendet ihn, nicht die Uhr.
- **„Alle laufenden Alarme beenden"** (Verwaltung → Nachbereitung) ist der
  Ausweg, wenn sich doch etwas aufstaut. Nur Admins, nur ausdrücklich
  getippt.
- **Der Countdown vor dem Auslösen ist fünf Sekunden und bleibt.** Ein
  Fehlalarm kostet eine Schule mehr als die fünf Sekunden — beim nächsten
  echten Alarm zuckt niemand mehr.
- **Der zweite Bildschirm zeigt NIE den Alarm** (eigene Szene in
  `Config/Info.plist`, `ExternalDisplaySceneDelegate`). Sonst erführe die
  Klasse die Bedrohungslage vor der Kollegin nebenan. Was die App nicht
  kontrollieren kann, ist das System-Banner davor — das spiegelt iOS. Ob
  die Sperrbildschirm-Vorschau den Alarmtext zeigt, entscheidet das
  Krisenteam im Konfigurationsprofil, nicht die App.
- **Vier Alarmtöne, und die Lautstärke steckt in der DATEI** (ab 1.0.30, Ansage
  des Nutzers 09/2026: Probealarme sollen vor den Kindern verborgen bleiben).
  `alarm.wav` (laut) plus `dezent.wav`, `holz.wav`, `tropfen.wav` — auf 0,22 bis
  0,32 Spitze gerechnet statt 0,92. Ein Lautstärkeregler wäre wirkungslos:
  Kritische Hinweise spielen seit 1.0.29 mit `withAudioVolume: 1.0`, unabhängig
  vom Gerät. Alle Töne rechnet `scripts/make-sounds.py`.
- **Der Name ist fest, die Datei wechselt** (`Alarmklang.swift`,
  `PushAsset.signalSound`). Die Erweiterung setzt den Ton und kann die Wahl der
  Lehrkraft NICHT kennen — eigener Prozess, eigener Behälter. Eine gemeinsame
  Einstellung bräuchte eine **App-Gruppe** und damit eine Entitlements-Datei an
  der Erweiterung; das ist die eine Sache, die dieses Projekt unsignierbar
  macht. Also nennt die Erweiterung immer `signal.wav`, und die App legt den
  gewählten Ton unter diesem Namen in `Library/Sounds` ab —
  `Klanginstallation.sicherstellen` bei jedem Start und sofort beim Wechseln.
  **`signal.wav` darf nie ins Bündel**, sonst ist nicht entschieden, welche
  Fassung `UNNotificationSound(named:)` nimmt. Fehlt die Datei, spielt iOS den
  Standardton — nicht den gewählten, aber auch nie gar nichts.
- **Ein eigener Ton wird umgerechnet UND leise gemacht** (`Eigenklang.swift`,
  ab 1.0.32). Drei Fallen, jede davon still: (1) iOS nimmt als Mitteilungston
  nur PCM/MA4/µ-law/a-law in WAV, AIFF oder CAF — eine MP3 wird nicht
  abgelehnt, sondern durch den STANDARDTON ersetzt, ohne Fehler; also wird
  alles, was AVFoundation lesen kann, in 16-Bit-PCM-WAV umgerechnet. (2) Über
  30 Sekunden spielt iOS gar nichts — lieber beim Übernehmen mit einem klaren
  Satz abweisen. (3) Eine mitgebrachte Datei ist meist bis Vollausschlag
  ausgesteuert, und kritische Hinweise spielen mit `withAudioVolume: 1.0`:
  ungebremst wäre der erste eigene Ton auf dreißig iPads unerwartet laut,
  ausgerechnet in der Lage, für die die leisen Töne gebaut wurden. Normiert
  wird deshalb auf dieselbe Spitze wie „Holzton" — **nach oben wie nach
  unten**, denn eine sehr leise Aufnahme wäre im Ernstfall wertlos.
  Geschrieben wird neben das Ziel und dann getauscht; ein halb geschriebener
  Alarmton wäre schlimmer als der alte.
- **`Alarmklang.quelle` ist die eine Stelle, an der Bündel und eigener Ton
  zusammenlaufen.** Die vier eingebauten liegen im App-Bündel, der eigene in
  Application Support. Wer die Unterscheidung woanders noch einmal trifft
  (Tonprobe, Installation), baut den zweiten Weg ein zweites Mal. Und ein
  gewählter eigener Ton, dessen Datei fehlt, gilt NICHT: `store.alarmklang`
  fällt auf `.alarm` zurück, sonst käme der Alarm mit dem iOS-Standardton.
- **Der Rückfall-Ton eines Abonnements lässt sich nachträglich nicht ändern.**
  `info.soundName` nennt seit 1.0.30 `signal.wav`, aber `reconcile` legt nur an,
  was FEHLT — schon eingerichtete Geräte behalten `alarm.wav` als Rückfall bis
  zum Neuaufsetzen. Ein Abonnement dafür zu löschen und neu anzulegen wäre der
  empfindlichste Weg dieser App für einen Ton, der nur bei ausgefallener
  Erweiterung spielt. Nicht nachrüsten.
- **Kritische Hinweise sind AN — seit 1.0.29** (von Apple bewilligt am
  08.09.2026 für die App-Id `de.dboschule.alarm`). Bis dahin durfte das
  Entitlement nirgends stehen: Eine Entitlements-Datei, die es ohne Bewilligung
  nennt, lässt jedes Signieren scheitern. Jetzt steht
  `com.apple.developer.usernotifications.critical-alerts` in BEIDEN
  Entitlements-Dateien, und `CRITICAL_ALERTS` steht in
  `SWIFT_ACTIVE_COMPILATION_CONDITIONS` an den **Projekt**-Konfigurationen
  Debug und Release — beide Ziele erben es, die Erweiterung braucht es genauso,
  denn sie setzt `interruptionLevel`. **Drei Dinge müssen zusammenkommen, und
  jedes kann einzeln fehlen:** Entitlement (Apple), Compilerbedingung (Repo),
  Erlaubnis auf dem Gerät (die Lehrkraft). Fehlt das dritte, ist die App nicht
  kaputt — der Quelltext fällt in jedem Zweig auf `.timeSensitive` zurück, und
  die Prüfliste zeigt die Zeile rot.
- **Eine Compilerbedingung weiß nichts über die ERLAUBNIS auf dem Gerät**
  (`Shared/Meldungsstufe.swift`, ab 1.1.0/Build 42). **Das war die erste
  Ablehnung durch Apple** (Guideline 2.1(a), 17.09.2026, iPad Air 11" /
  iPadOS 27): „the Tontest starten button was unresponsive, even when we put
  the device in standby it was not woken up". Der Knopf war nicht kaputt —
  `interruptionLevel = .critical` und `criticalSoundNamed(…)` brauchen ZWEI
  Dinge, das Entitlement UND die Erlaubnis des Menschen, und ohne die zweite
  weist `add(_:)` die Anfrage ab. `Tontest` und `AlarmReminder` fragten aber nur
  `#if CRITICAL_ALERTS`. Der Prüfer hatte kritische Hinweise nicht erlaubt;
  damit war jede dieser Mitteilungen von vornherein abgewiesen. **Schlimmer als
  die Ablehnung ist der Feldfehler dahinter:** Auf jedem Gerät, dessen Lehrkraft
  kritische Hinweise abgelehnt hat, entstand keine einzige der zehn
  Erinnerungen — der Push kam, das Netz danach fehlte, still. Die Entscheidung
  steht jetzt an EINER Stelle, liegt in `Shared/` (App UND Erweiterung, also
  sechs Einträge im pbxproj) und liest `criticalAlertSetting` zur Laufzeit; der
  Rückfall ist `.timeSensitive` mit demselben Ton. **Wer eine neue Mitteilung
  baut, setzt Stufe und Ton über `Meldungsstufe.setze` und nirgends von Hand.**
  Und: Die Falle stand in `requestAuthorization` wörtlich beschrieben („it
  simply never succeeds, which is the kind of quiet defect this app cannot
  afford") — ein Kommentar ersetzt keine Prüfung.
- **Diese App sperrt niemanden aus — sie SAGT, was fehlt** (ab 1.1.0/Build 43).
  **Das war die zweite Ablehnung durch Apple** (Guideline 4.5.4, 19.09.2026,
  iPad Air 11"): „The app requires push notifications in order to function.
  Push notifications must be optional and must obtain the user's consent to be
  used within the app." Der Prüfer hatte recht. „Einrichtung abschließen" war
  grau, solange eine Mitteilungszeile rot stand (`ChecklistItem.blocksCompletion`,
  `AppModel.finishBlockers`) — wer die Systemfrage mit „Nicht erlauben"
  beantwortete, kam aus der Einrichtung nie wieder heraus: kein Auslösen, keine
  Verwaltung, keine Prüfliste. Dieselbe Sackgasse wie 1.0.10 beim
  Zustellnachweis, nur eine Etage tiefer und diesmal vollständig — und 1.0.10
  hatte die Lehre schon aufgeschrieben („Was ein zweites Gerät braucht, darf
  nie Bedingung für den ersten Start sein"), nur nicht zu Ende gezogen. Der
  Sperrmechanismus ist deshalb **ersatzlos aus dem Quelltext entfernt**, nicht
  auf „false" gestellt: Ein Feld, das nur noch falsch sein darf, wird
  irgendwann wieder wahr. **Wer einen Knopf ausgraut, solange etwas fehlt,
  holt diese Ablehnung zurück.**
- **Ohne Mitteilungen bleibt die App benutzbar, und das steht auch da**
  (`Views/OhneMitteilungenView.swift`, ab 1.1.0/Build 43). Auslösen,
  Rückmelden, Nachrichten, Entwarnen, Verwaltung und Diagnose hängen an keiner
  Erlaubnis, und die Abfrage (fünf Sekunden bei laufendem Alarm, sonst
  dreißig) läuft unabhängig davon — eine offene App zeigt einen Alarm also
  binnen Sekunden von selbst. Was fehlt, ist der Ton bei hinten liegender App,
  der Nachfasslauf und der Tontest. Die Seite zählt beides Punkt für Punkt auf
  und redet nichts schön; der Satz „dieses Gerät ist dann kein Alarmgerät,
  sondern eine Ansicht" steht ausdrücklich darin.
- **Die Einwilligung wird IN der App eingeholt, erklärt, und nie von selbst.**
  Ein eigener Abschnitt „Mitteilungen — freiwillig" steht in der Einrichtung
  UND dauerhaft in den Einstellungen (wer beim ersten Start ablehnt, käme sonst
  nie wieder daran vorbei); daneben immer der Weg zu „Was ohne Mitteilungen
  geht". Den Systemdialog löst ausschließlich ein Tipp aus — beim Start fragt
  die App nichts (`kritischeHinweiseNachfragen` ist an `.authorized` gebunden
  und kommt damit erst nach einer Zusage zum Zug). Und `melde(abgewiesen:)`
  meldet einen Ausfall nur als FEHLER, wenn die Erlaubnis da ist: Wer sie
  bewusst verneint hat, bekommt einen Hinweis statt eines roten Bandes — eine
  App, die eine getroffene Entscheidung als Störung ausgibt, drängt.
- **Eine verweigerte Kamera ist kein schwarzer Bildschirm** (`QRCodeView`, ab
  1.1.0/Build 44, im eigenen Durchgang gefunden). `configure()` bestand aus drei
  `guard … else { return }`: Ohne Erlaubnis — oder im Simulator, oder auf einem
  Gerät ohne Kamera — wurde nichts eingerichtet, und stehen blieb eine schwarze
  Fläche ohne ein Wort. **Das ist genau die Form der ersten Ablehnung** („the
  button was unresponsive"), nur an einem anderen Knopf; getroffen hätte es auch
  jede Lehrkraft, die die Kamerafrage einmal verneint hat. Jetzt entscheidet
  `AVCaptureDevice.authorizationStatus` vorher: noch nie gefragt → fragen,
  verweigert → ein Satz, ein Knopf in die Einstellungen und der Hinweis auf den
  Weg daneben. **Der Weg daneben ist der wichtigere** — den sechsstelligen Code
  kann man abtippen. Die Kamera ist eine Abkürzung, nie eine Bedingung; dieselbe
  Regel wie bei den Mitteilungen, und beide Male hat Apple sie uns beigebracht.
  **Merke: Jeder `guard … else { return }` in einem Einrichtungsweg ist ein
  stummer Knopf, bis das Gegenteil bewiesen ist.**
- **Das Wort „Platzhalter" gehört nicht in die Oberfläche** (ab 1.1.0/Build 44).
  Die Handlungstexte begannen mit „Platzhalter — bitte mit Schulleitung und
  Polizei abstimmen". Gemeint war die SCHULE, gelesen wird es über die APP:
  Guideline 2.1 nennt „placeholder text" ausdrücklich als Ablehnungsgrund, und
  ein Prüfer sieht diesen Bildschirm, sobald er einen Alarm auslöst. Der Satz
  sagt jetzt dasselbe von der Schule her („Diese Schule hat noch keinen eigenen
  Text hinterlegt … verbindlich wird der Wortlaut erst, wenn …"). **An der Sache
  ändert sich nichts** — die Texte bleiben erkennbar unfertig, und genau das ist
  ihr Sinn: Ein Text, der bloß amtlich klingt, ist gefährlicher als ein sichtbar
  unfertiger. Geändert hat sich nur, worüber der Satz spricht.
- **Kein Name eines MDM-Anbieters in einem Oberflächentext** (ab 1.1.0/Build 44).
  `BackendAvailability.restricted` sagte „bitte an die Jamf-Administration
  wenden". Für eine Schule, die Jamf benutzt, ist das hilfreich; für einen
  Prüfer bei Apple ist es das Kennzeichen einer Firmen-App, die in den
  öffentlichen Laden nicht gehört (Guideline 4.3, dieselbe Ecke wie „nur an
  Schul-iPads"). Es heißt jetzt „Das gibt die Geräteverwaltung vor" — richtig
  für jedes MDM und ohne Firmenschild. Die Anleitung für Jamf bleibt im Papier,
  wo sie hingehört.
- **Der Meldeweg gehört AN den Inhalt** (`AlarmChatView`, `Hilfeadressen.meldung(zu:)`,
  ab 1.1.0/Build 44). Es gab ihn (Einstellungen → Hilfe), aber dort findet ihn
  niemand, der gerade etwas liest, das dort nicht stehen sollte — dieselbe Lehre
  wie beim Gruppenchat selbst, den bis 1.0.21 niemand fand. Apples Regel zu von
  Nutzern eingestelltem Inhalt verlangt genau das. Jede Nachricht trägt jetzt ein
  „…"-Menü mit „Diese Nachricht melden"; die Mail ist mit Kürzel, Uhrzeit,
  Kennung und Wortlaut vorbelegt, **abgeschickt wird sie vom Menschen** — eine
  Mail, die die App still hinausschickt, wäre keine Meldung, sondern eine
  Übermittlung.
- **Wer nur die Dateigröße braucht, fragt nach der Größe** (`Alarmklang.befund`,
  ab 1.1.0/Build 44). `attributesOfItem` holt das ganze Attributbündel und damit
  die Datei-ZEITSTEMPEL — die stehen auf Apples Liste der
  begründungspflichtigen Schnittstellen, und ein Prüflauf streicht sie an
  (ITMS-91053). `resourceValues(forKeys: [.fileSizeKey])` steht auf keiner
  Liste. Eine Begründung in `PrivacyInfo.xcprivacy` einzutragen wäre der andere
  Weg gewesen und der schlechtere: Sie wäre unwahr, denn gelesen wird kein
  Zeitstempel.
- **Kontolöschung: Es gibt kein Konto** (Guideline 5.1.1(v), festgehalten
  09/2026). Die App legt keines an — sie benutzt die Apple-ID, die auf dem Gerät
  schon angemeldet ist, und fragt weder E-Mail noch Kennwort. Was sie anlegt,
  ist eine MITGLIEDSCHAFT, und die löscht „Verbindung zur Schule lösen" samt der
  Abonnements dieses Geräts. Rückmeldungen und Nachrichten bleiben bewusst
  stehen: Sie sind ein Nachweis, der der Schule gehört, und nach 90 Tagen räumt
  sie das Aufräumen ohnehin weg. **Das gehört in die Prüfhinweise**, auch wenn
  niemand danach fragt — die Frage kommt sonst als Ablehnung.
- **`try?` an einer Mitteilung ist verboten.** Dasselbe `try?`, das den
  Ablehnungsgrund verschluckte, hat die App die erste Einreichung gekostet: Der
  Prüfer tippte, iOS wies ab, der Knopf schwieg. `Tontest.starten` gibt seither
  einen Befund zurück (geplant, oder der ROHE Fehlertext), `AlarmReminder`
  zählt die abgewiesenen und meldet den vollständigen Ausfall, und
  `AppModel.runTontest` zeigt beides. „Ein Knopf, der schweigt, ist für den
  Menschen davor ein kaputter Knopf" stand seit 1.0.26 im Papier — für diesen
  Knopf galt es nicht. **Bei jedem neuen Knopf prüfen, ob er im Fehlerfall
  etwas sagt.**
- **Ein Prüfer von Apple geht die Prüfliste nicht durch.** Er tippt auf den
  größten Knopf. Deshalb fragt der Tontest die Mitteilungserlaubnis selbst
  nach, wenn sie noch nie erfragt wurde, statt an ihr zu scheitern — und die
  Prüfhinweise bitten seit der Ablehnung ausdrücklich darum, beide
  Erlaubnisdialoge mit „Erlauben" zu beantworten. **Was ein Mensch übersehen
  kann, darf keine Sackgasse sein.**
- **Wer die Erlaubnis erst nachträglich braucht, muss NACHGEFRAGT werden**
  (`NotificationCenterService.kritischeHinweiseNachfragen()`, ab 1.0.29).
  `requestAuthorization` läuft nur beim Einrichten; die dreißig iPads, die vor
  der Bewilligung eingerichtet wurden, hätten die Frage nie gesehen und wären
  bei stummem Gerät still geblieben — obwohl die Fassung dafür gebaut ist.
  Gefragt wird bei jedem Start, solange die Erlaubnis fehlt; hat iOS die Frage
  einmal beantwortet, zeigt es sie nicht wieder und der Aufruf kehrt still
  zurück. **Allgemein: Eine Berechtigung, die eine neue Fassung zusätzlich
  braucht, erreicht die schon eingerichteten Geräte nur, wenn jemand sie dort
  ausdrücklich nachfragt.**
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
  (Build 2), 1.0.2 (Build 3), 1.0.3 (Build 4), 1.0.4 (Build 5) usw. Dazu gesetzt (Ansage des Nutzers,
  09/2026): `DEVELOPMENT_TEAM = F4989GSTWS` — dieselbe Id wie Schulalarm und
  Tafelbild — und `INFOPLIST_KEY_LSApplicationCategoryType =
  public.app-category.navigation`. Beides steht als Build-Einstellung, weil
  das Ziel `GENERATE_INFOPLIST_FILE = YES` benutzt.
- **1.1.0 (Build 39) ist die Fassung, die in den App Store geht** (Ansage des
  Nutzers, 09/2026: „Ich möchte gerne ein einigermaßen rundes Bild
  einreichen."). Der Sprung von 1.0.37 ist bewusst und derselbe Gedanke wie bei
  Tafelbild 1.4.0: Was hier eingereicht wird, ist keine achtunddreißigste
  Nachbesserung, sondern die erste öffentliche Fassung. Die siebenunddreißig
  Stände davor gab es nur im Repo und über TestFlight; niemand außerhalb hat
  sie je gesehen. **Die Marken „ab 1.0.x" in diesem Papier bleiben stehen** —
  sie sagen, wann etwas in den Quelltext kam, und das ändert sich durch eine
  Umbenennung nicht. Danach zählt es wie gewohnt weiter: 1.1.1, 1.1.2 …
  **Solange 1.1.0 noch nicht hochgeladen ist, hebt eine Arbeitseinheit nur die
  BUILD-Nummer** (39 → 40 → …) und lässt die 1.1.0 stehen. Die Patch-Nummer zu
  heben verschöbe genau den runden Stand, um den der Nutzer gebeten hat; die
  Build-Nummer ist davon unabhängig und muss ohnehin nur steigen. Ab dem ersten
  angenommenen Upload gilt wieder die normale Regel: beides um je +1.
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
- **Für den öffentlichen Laden muss die App JEDER Schule gehören** (ab 1.0.35).
  Apple weist Apps zurück, die erkennbar nur einer einzelnen Einrichtung nützen
  — dafür gibt es die Custom Apps. Die Review-Notizen begannen bis 1.0.34
  wörtlich mit „internal … app for the staff of a single German primary school
  … not intended for the public App Store": derselbe Text, der bei Apple
  eingereicht wird. Die Sache stimmt ja auch gar nicht — wer die App
  installiert, richtet sich seine eigene Schule ein, und die Schulen wissen
  nichts voneinander. Der Text sagt das jetzt zuerst.
- **Nachrichten im Alarm sind von Nutzern eingestellter Inhalt** (ab 1.0.35).
  Damit gilt Apples Regel dazu: ein Weg zu melden, ein Weg, jemanden
  loszuwerden, und eine erreichbare Adresse. Das Entfernen gab es schon
  (Verwaltung → Mitglieder, dazu den Code zurückziehen); dazugekommen sind der
  Abschnitt „Hilfe" in den Einstellungen und `Services/Hilfeadressen.swift` —
  die drei Adressen an EINER Stelle, sonst lauten sie irgendwann verschieden.
- **Der Prüfer richtet seine EIGENE Schule ein, er tritt keiner bei**
  (`docs/APP_REVIEW_NOTES.md`, ab 09/2026). Wer über einen Code beitritt, ist
  seit 1.0.13 Mitglied und kein Admin — und ein Mitglied sieht die Auswahl
  „PROBEALARM" gar nicht, weil Probealarme Admins vorbehalten sind. Die
  Prüfhinweise verlangten aber genau das: mit Code beitreten und einen
  Probealarm auslösen. Sie nannten obendrein einen Knopf („Testalarm an dieses
  Gerät senden"), den es seit 1.0.12 nicht mehr gibt. Beides sind vermeidbare
  Ablehnungsgründe: Findet ein Prüfer nicht, was die Notizen versprechen,
  lehnt er ab. Mit „Schule einrichten" ist der Prüfer Admin seiner eigenen,
  getrennten Gruppe — kein Beitrittscode, keine Berührung mit echten Daten.
  **Nach jeder Änderung an Rollen, Knöpfen oder Einrichtungsablauf gehören die
  Prüfhinweise mitgezogen.**
- **iCloud-Konto und App-Store-Konto sind zwei Paar Schuhe** (festgehalten
  09/2026 in `docs/VERTEILUNG_JAMF_SCHOOL.md`, Abschnitt 3b). Schulalarm hängt
  am **iCloud**-Konto (Einstellungen → ganz oben) — daran erkennt CloudKit die
  Lehrkraft, daran hängen Mitgliedschaft, Rolle und Rückmeldungen. TestFlight
  hängt an **Medien & Käufe** (Einstellungen → App Store). Beide dürfen
  verschieden sein, und oft ist das die einzige Aufteilung, die geht: schulische
  Apple-ID für iCloud, eine andere für die Installation. **Ohne iCloud-Konto
  läuft die App gar nicht** — auch nicht bei gerätebasierter Zuweisung über
  Jamf, die sonst ganz ohne Apple-ID installiert. Beim Vorbereiten eines Geräts
  ist das die erste Frage, nicht die letzte.
- **Die Nutzungsbedingungen stehen auf einer SEITE, nicht in der App**
  (`docs/schulalarm/nutzungsbedingungen.html`, ab 1.1.0/Build 40). Ein Text, der
  sich ändern muss — ein Satz nach einer Rückfrage —, darf nicht an einer
  Fassung hängen, die erst durch Apples Prüfung muss; und die dreißig schon
  eingerichteten iPads läsen dann die alte. Verlinkt ist er im Abschnitt
  „Hilfe" der Einstellungen (`Hilfeadressen`), auf der Support-Seite und in App
  Store Connect. **Die Klausel ist bewusst ENG**: Haftung nur für Vorsatz und
  grobe Fahrlässigkeit (§ 521 BGB entsprechend, weil kostenlos), aber
  ausdrücklich NICHT ausgeschlossen für Leben, Körper, Gesundheit, wesentliche
  Vertragspflichten und das Produkthaftungsgesetz. Ein Rundum-Ausschluss wäre
  nach § 309 Nr. 7 BGB unwirksam — und zwar GANZ, es gibt keine erhaltende
  Reduktion. Eine zu weite Klausel schützt also schlechter als eine enge. **Wer
  hier etwas hinzufügt, prüft zuerst, ob es diese Ausnahmen antastet.**
- **Kein Gewerbe, keine Anschrift — Punkt** (Ansage des Nutzers, 09/2026, nach
  einer früheren Überlegung in die andere Richtung). Die App wird als PRIVATE
  Person unentgeltlich angeboten: keine Einnahmen, keine Werbung, keine Käufe in
  der App. Unter „Anbieter" stehen deshalb Name und E-Mail und sonst nichts; die
  Impressumspflicht des § 5 DDG trifft geschäftsmäßige Dienste, nicht ein rein
  privates, kostenloses Angebot. **Wer hier je wieder eine Adresse einbaut,
  fragt vorher.**
- **Die eine Stelle, an der eine Anschrift trotzdem öffentlich würde, ist der
  HÄNDLERSTATUS** in App Store Connect (Digital Services Act). Wer dort
  „Händler" angibt, dessen Name, Anschrift und Telefonnummer zeigt Apple auf der
  Produktseite an. Für dieses Angebot ist „kein Händler" die zutreffende Angabe.
  Steht in der Einreichungsliste; nicht nebenbei wegklicken.
- **Was wirklich schützt, ist die Ehrlichkeit der App selbst.** Keine Zusage
  über die Zustellung, kein grünes Häkchen für „nicht nachgesehen", die
  Rückmeldeliste, die sagt, was sie NICHT ist. Diese Linie ist deshalb nicht nur
  eine Frage des Anstands, sondern das, was einer Zusicherung am ehesten den
  Boden entzieht. **In der Store-Beschreibung nie „zuverlässig", „sicher",
  „garantiert" oder „in Sekunden" versprechen** — genau daraus wird sonst eine
  Beschaffenheitsvereinbarung.
- **Datenschutz- und Hilfeseite liegen in `docs/schulalarm/`** und werden vom
  Pages-Ablauf mitgeliefert:
  `https://katonid.github.io/prae/schulalarm/datenschutz.html` und
  `.../support.html`. Die Datenschutz-URL ist **Pflichtfeld schon für eine
  externe TestFlight-Gruppe**, nicht erst für den Laden. Die Seite benennt die
  Grenzen der öffentlichen CloudKit-Datenbank ausdrücklich (der Entwickler kann
  die Datensätze einsehen; wer den Beitrittscode hat, kommt in die Gruppe) —
  dieselbe Ehrlichkeit wie im README, nicht schönreden.
- **Für den Probelauf: externe TestFlight-Gruppe mit öffentlichem Link.** Die
  acht Zeichen hinter `testflight.apple.com/join/` sind ein Code, der sich in
  der TestFlight-App unter „Code einlösen" eintippen lässt — es braucht also
  KEINE Einladungsmail, was schulische Apple-IDs ohne Postfach sonst
  ausschlösse. Den Link gibt es nur für externe Gruppen und erst nach
  bestandener Beta App Review; einen Termin im Kollegium also danach ansetzen.
  Ob eine Managed Apple ID TestFlight überhaupt darf, hängt an Rolle und
  ASM-Einstellungen — an EINEM Gerät ausprobieren, bevor dreißig Leute
  eingeladen werden. **Ein TestFlight-Bau läuft nach 90 Tagen ab**; für den
  Dauerbetrieb einer Alarm-App taugt er deshalb nicht.
- **Der App-Eintrag wird VON HAND in App Store Connect angelegt**, nie über
  Xcodes „Create App Record" im Distribute-Ablauf (gemeldet 09/2026:
  „App Record Creation failed due to request containing an attribute already
  in use"). Xcode schlägt dort den Anzeigenamen vor, und `Schulalarm` ist
  vergeben — App-Namen sind bei Apple weltweit eindeutig, **auch für Custom
  Apps**, die nie im öffentlichen Laden auftauchen. Derselbe Fehler wie bei
  Anstoß, dieselbe Lösung: freier Store-Name, Eintrag von Hand, dann lädt
  Distribute über die Bundle-Id hinein. Vergeben ist seit 09/2026
  **„Schulalarm - Der Warnmelder"** (Ansage des Nutzers). **Store-Name und Homescreen-Name sind getrennte Felder**
  und dürfen auseinandergehen; `INFOPLIST_KEY_CFBundleDisplayName` bleibt
  „Schulalarm", Ordner, Ziel, Bundle-Id und iCloud-Container bleiben ebenfalls.
  Das Archiv muss dafür nicht neu gebaut werden.
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

## Projekt Abfahrtstafel (ÖPNV-Abfahrten, native iOS-App)

- App-Code: `AbfahrtstafeliOS/` (ein Target: App, iPhone + iPad, iOS 17,
  keine fremden Abhängigkeiten). Zeigt, was um einen Punkt herum gerade
  wegfährt — Abfahrtszeit, Verspätung, Minutenziffer, alle Zwischenhalte
  und die Strecke auf der Karte. Der Punkt ist der eigene Standort ODER
  ein frei gewählter. Ausführlich: `AbfahrtstafeliOS/README.md`.
- **Homescreen-Name „Abfahrt"**, Ordner/Ziel/Bundle-Id bleiben
  „Abfahrtstafel" / `de.familie.abfahrtstafel` — nach dem ersten
  Signieren nicht mehr ändern.
- **Alles Fahrplan-Nahe liegt hinter EINEM Protokoll** (`Fahrplandienst`).
  Die Schnittstelle kennt ausschließlich `Fahrplan/Transitous/`; Ansichten
  und Modelle sehen sie nie. Das ist kein Stilwunsch: Öffentliche
  Fahrplanschnittstellen werden abgeschaltet (HAFAS bei der Bahn),
  verlangen plötzlich einen Schlüssel oder decken eine Gegend nicht ab.
  `Musterdienst` ist der laufende Beweis — steckte in einer Ansicht ein
  JSON-Feld von Transitous, ließe er sich nicht übersetzen.
- **Datenquelle ist Transitous (MOTIS v1), ohne Schlüssel und ohne Konto.**
  Es führt die DELFI-Daten (alle deutschen Verbünde) und große Teile
  Europas zusammen. `v6.db.transport.rest` wäre die naheliegende
  Alternative und antwortete beim Bau (09/2026) über Stunden mit 503.
  Ein Schlüssel in der App wäre keiner — was in einer App steckt, ist
  kein Geheimnis.
- **Drei Abfragen, mehr nicht:** `/reverse-geocode` (nächste Haltestelle
  zum Punkt), `/stoptimes` (Abfahrten), `/trip` (Lauf samt Geometrie).
  **`radius` an `/stoptimes` ist der Grund, warum die Tafel mit EINER
  Abfrage fertig ist** — der Dienst liefert die Abfahrten aller
  Haltestellen im Umkreis mit. Eine Abfrage je Haltestelle wären zehn
  Anfragen, und die Liste baute sich ruckweise auf. `/reverse-geocode`
  gibt immer genau FÜNF Treffer zurück (nachgemessen mit `n`, `limit`,
  `count`) — die Liste der Haltestellen baut die App deshalb aus den
  ABFAHRTEN, denn nur die wissen, ob dort heute noch etwas fährt.
- **`/reverse-geocode` sucht nur rund einen Kilometer weit und gibt sonst
  eine LEERE Liste zurück** (nachgemessen 09/2026: Bayerischer Wald und
  Allgäu leer, Eppenschlag 305 m gefunden, Frankfurt 84 m). Ein Punkt
  mitten im Feld hat also keine Ankerhaltestelle, und der Umkreis der App
  ändert daran nichts — was der Dienst nicht liefert, lässt sich nicht
  filtern. Dafür gibt es `Fahrplanfehler.keineHaltestelleInDerNaehe` als
  EIGENEN Fall: Die Antwort darauf ist ein anderer Punkt, nicht ein
  zweiter Versuch, und `Ladestand.fehler` trägt deshalb `ortswahlHilft`
  bis zum Knopf durch. „Noch einmal versuchen" über einem Waldstück wäre
  eine Sackgasse mit Bedienelement.
- **„Plan" ist nicht „pünktlich".** Liegt keine Echtzeitmeldung vor
  (`realTime == false`), steht neben der Zeit das Wort „Plan" und sonst
  nichts. Ein grüner Haken für „nicht nachgesehen" wäre die teuerste Lüge,
  die diese App erzählen kann — dieselbe Regel wie bei Schulalarms
  Prüfliste. Weicht die Echtzeit ab, steht die PLANZEIT durchgestrichen
  da, daneben `+3` und die neue Zeit: Nur die neue zu zeigen verschwiege,
  dass es eine Verspätung gibt, und wer den Fahrplan im Kopf hat, hielte
  die App für falsch. **Ein Zufrüh (`-1`) wird ebenfalls gezeigt** — ein
  Bus, der zwei Minuten zu früh fährt, ist für den Wartenden weg.
- **Die GELTENDE Zeit ist nie die kleinere** (`Haltzeit` in `FahrtView`, ab
  1.0.10, gemeldet 09/2026: „Wenn mich die Abfahrtszeit auch nicht mehr ändert,
  dann ist ja die neue korrigierte Zeit die richtige … sie soll bitte nicht
  kleiner sein als die ursprünglich geplante Zeit."). Bis 1.0.9 stand im
  Fahrtlauf die Planzeit groß und durchgestrichen da und die wirkliche darunter
  in Kleinschrift — also die ungültige Angabe als Hauptangabe. Jetzt steht die
  geltende Zeit oben und groß, die durchgestrichene Planzeit klein darunter.
  **Stehen bleibt sie trotzdem**: Ohne sie verschwiege die App die Verspätung,
  und wer den Fahrplan im Kopf hat, hielte sie für falsch — sie ist nur die
  Erklärung und nicht mehr die Auskunft. In der TAFEL (`Zeitangabe`) stehen
  beide in EINER Zeile und bleiben gleich groß; dort trägt die geltende Zeit
  das Halbfett, denn ein Größenunterschied nebeneinander wäre Unruhe und kein
  Hinweis.
- **Es gibt GENAU EINE Uhr** (`Dienste/Uhrwerk.swift`), und jede
  Minutenziffer rechnet aus ihr. Holte sich jede Zeile selbst `Date()`,
  stünden zwei Abfahrten derselben Minute mit verschiedenen Ziffern
  nebeneinander, und die Liste zählte nur dort weiter, wo SwiftUI zufällig
  neu zeichnet. Sekundentakt, und der Timer hängt in `.common` — in der
  Vorgabeschleife stünde er still, solange gescrollt wird, also genau
  dann, wenn jemand die Tafel durchsieht.
- **Haltestellen werden über den NAMEN gruppiert, nicht über Kennungen**
  (`Haltestellengruppe.bauen`). Der Dienst führt Haltestellen auf
  Steig-Ebene: „Marienplatz" sind mindestens drei Einträge (`…:09162:2`,
  `…:09162:2_G`, `…:09162:2:51:51`), und die Elternkennung ist nicht
  überall gepflegt — ungruppiert stünde dieselbe Haltestelle dreimal
  untereinander, jedes Mal mit einem Teil der Abfahrten. Dazu eine
  Abstandsprüfung (400 m), weil es „Bahnhof" und „Kirche" in einem
  Landkreis dutzendfach gibt. **Umlaute werden beim Vergleich NICHT
  eingeebnet** — dieselbe Regel wie bei Schulalarms Kürzeln.
- **Eine fehlende Streckengeometrie wird nicht erfunden.** Schickt der
  Dienst keinen Linienzug mit, zeichnet `StreckenKarte` die Verbindung der
  Halte GESTRICHELT und schreibt darunter, dass es die Luftlinie ist. Eine
  durchgezogene Linie quer über einen Berg, wo ein Tunnel liegt, sieht aus
  wie eine Auskunft und ist keine.
- **Die Genauigkeit der Polylinie ist ein Parameter, keine Konstante**
  (`Polylinie.auspacken`). Google schreibt mit fünf Nachkommastellen,
  MOTIS mit sieben, und die Antwort sagt es selbst (`precision`). Wer rät,
  legt die Strecke um den Faktor 100 daneben.
- **`METRO` ist die S-BAHN, nicht die U-Bahn.** MOTIS benutzt es für
  GTFS-Typ 109 („suburban railway"). Wer das verwechselt, färbt jede
  S-Bahn blau und jede U-Bahn grün — und ein Fahrgast liest diese Farben,
  ohne hinzusehen. Linienfarben kommen aus den GTFS-Daten
  (`route_color`); fehlen sie, gilt die gewohnte deutsche Rückfallfarbe je
  Verkehrsmittel. Ist keine Schriftfarbe angegeben, wird sie aus der
  HELLIGKEIT entschieden und nicht auf Weiß gesetzt: Die S8 in München ist
  hellgrün, und weiße Schrift darauf ist im Sonnenlicht nicht zu lesen.
- **Entfernungen sind Luftlinien, und das steht dabei.** Ein Fußweg
  bräuchte je Haltestelle eine Routing-Abfrage und wäre trotzdem geraten,
  solange niemand weiß, wo der Zugang liegt. Wer die Zahl für eine
  Gehstrecke hält, verpasst den Bus.
- **Ein AUSDRÜCKLICH erfragter Fußweg ist etwas anderes** (`Fusswegquelle`,
  `Fusswegmesser`, ab 1.1.26, Ansage des Nutzers 09/2026: „Ich möchte eine
  Möglichkeit der Entfernungsmessung zu Fuß einbauen … sowohl vor Ort … als
  auch von einem anderen Ort … Dies alles unkompliziert auf der Karte."). Der
  Punkt darüber bleibt gültig und gilt für die LISTE: Ein Dutzend Abfragen
  für Zahlen, die niemand angefordert hat, wäre falsch. Hier fragt jemand
  nach EINER Strecke — eine Abfrage für eine Auskunft, um die gebeten wurde.
  Auf der Netzkarte, über einen sichtbaren Knopf unten links; Start und Ziel
  mit demselben Fadenkreuz wie der Suchpunkt, wahlweise „Mein Standort", und
  ein Tipp auf eine Haltestelle nimmt sie als Punkt.
- **Der Fußweg steht in `direct`, nicht in `itineraries`** (gemessen
  20.09.2026, Karl-Preis-Platz → Ostbahnhof). Ein Weg ganz ohne
  Verkehrsmittel ist für MOTIS keine Verbindung, sondern eine „direkte" —
  `itineraries` blieb in derselben Antwort leer. Wer ihn dort sucht, hält
  die Quelle für stumm.
- **Ohne `maxDirectTime` hört der Fußweg bei 30 Minuten auf — still.**
  Nachgemessen am selben Tag, Marienplatz nach Norden: ein Kilometer
  Luftlinie kam mit 1075 s durch, **zwei Kilometer und alles darüber
  lieferten eine LEERE Antwort mit HTTP 200**. Das sah aus wie „es gibt
  keinen Weg" und war eine Voreinstellung. Dass der Parameter wirkt, ist am
  INHALT geprüft und nicht am Status — dieselben fünf Kilometer ohne ihn
  nichts, mit `maxDirectTime=7200` 4769 s über 5583 m; ein falsch
  geschriebener Parametername wird von `/plan` stillschweigend ignoriert.
  Gesetzt sind vier Stunden (rund 17 km). Teuer ist es nicht: auch eine
  Abfrage über 150 km war in gut einer Sekunde beantwortet.
- **„Kein Fußweg" gibt es wirklich, und dann steht die Luftlinie da.**
  Helgoland vom Festland aus und München → Nürnberg antworteten auch mit
  hohem Deckel mit nichts — richtig, denn über Wasser und über 150 km führt
  keiner. `Fahrplanfehler.keinFussweg` ist deshalb ein eigener Fall: Hier
  hilft weder ein zweiter Versuch noch eine andere Zeit. Gezeichnet wird
  dann die GESTRICHELTE Gerade, und darunter steht, dass es die Luftlinie
  ist — dieselbe Regel wie beim Fahrtlauf ohne Streckengeometrie.
- **Die Luftlinie steht IMMER daneben, auch bei gefundenem Weg.** Der
  Unterschied zwischen beiden ist die eigentliche Auskunft: 1,7 km Weg über
  1,1 km Luftlinie heißt, dass ein Fluss, ein Gleis oder eine Schnellstraße
  dazwischenliegt. Und sie ist die einzige Zahl, die auch bei einem
  Netzaussetzer dasteht.
- **Die Gehzeit ist die Annahme der QUELLE, keine Messung an einem
  Menschen** (rund 1,19 m/s, also gut 4,3 km/h — gemessen). Die Leiste
  schreibt das Tempo hin und dazu, dass langsamer geht, wer Treppen meidet
  oder ein Kind an der Hand hat. Eine nackte Minutenzahl wäre eine Zusage —
  dieselbe Regel wie beim Wort „Plan" an einer Abfahrt ohne Echtzeit.
- **`Fusswegquelle` ist das VIERTE Protokoll, und `VolleQuelle` hält die
  Kette bei EINER Liste.** Eigenes Protokoll aus demselben Grund wie
  `Abfahrtsquelle` und `Verbindungsquelle`: Die Verbünde geben Fußwege nur
  INNERHALB einer Reiseauskunft heraus, nicht zu zwei frei gewählten
  Punkten. `VolleQuelle = Fahrplandienst & Fusswegquelle` ist der Typ der
  ersten Stufe und des Spiegels — so gibt es weiterhin eine einzige Liste
  von Adressen und keinen `as?`-Versuch zur Laufzeit, der den Fehler vom
  Übersetzer auf das Gerät verschöbe.
- **Der `Fusswegmesser` liegt in der UMGEBUNG, nicht in der Karte.** Die
  Netzkarte gibt es zweimal — eingebettet neben der Liste und im Vollbild —,
  und das sind zwei Ansichten mit eigenem `@State`. Eine gerade gemessene
  Strecke, die beim Aufziehen der Karte verschwindet, sähe wie ein Fehler
  aus.
- **Im Messbetrieb heißt derselbe Tipp etwas anderes.** Ein Tipp auf eine
  Haltestelle nimmt sie als Messpunkt, statt ihre Tafel zu öffnen; ein Tipp
  ins Leere zieht die Karte NICHT auf. Beides ist erlaubt, weil der Modus
  sichtbar ist: Der Knopf steht auf „Abbrechen", das Fadenkreuz liegt in der
  Mitte, und die Leiste sagt, was gerade dran ist. **Ein Modus, den man
  nicht sieht, darf die Bedeutung eines Tipps nicht ändern.**
- **Der Name wird NACHGETRAGEN, nicht abgewartet** (`Fusswegmesser.nameNachtragen`).
  Der Geocoder braucht eine Sekunde; wer auf ihn wartet, bevor der Punkt
  dasteht, baut einen Knopf, der eine Sekunde lang nichts tut. Die Messung
  selbst hängt an der Koordinate. Eine späte Antwort schreibt nur, wenn noch
  DERSELBE Punkt gemeint ist — sonst benannte sie den längst ersetzten.
- **Ein Fehler beim Nachladen räumt die stehende Tafel NICHT weg**
  (`AppModel.melden`). Ist noch nichts da, füllt der Fehler den
  Bildschirm; stehen schon Zeiten, bleiben sie und der Fehler wird ein
  Band darüber — zusammen mit „zuletzt geholt um …", das dann ehrlich
  sagt, wie alt die Zahlen sind.
- **Kein `@AppStorage` in `AppModel`.** Der Wrapper ist eine
  `DynamicProperty` und gehört in eine View; in einer
  `ObservableObject`-Klasse schreibt er zwar in die Voreinstellungen, löst
  aber kein `objectWillChange` aus — die Tafel bliebe nach dem Umstellen
  des Umkreises stehen, und niemand sähe, woran es liegt.
- **Die Ortung ist `WhenInUse` und sonst nichts.** Kein Hintergrundmodus:
  Die App zeigt Abfahrten, während jemand auf sie schaut. Wird die Ortung
  abgelehnt, ist das KEIN Fehlerzustand — der Weg über die Ortswahl steht
  gleich daneben. Eine App, die dort nur „Zugriff verweigert" sagt, ist
  für jemanden ohne Ortung zu Ende.
- **Der Punkt auf der Karte wird über ein festes Fadenkreuz gewählt**, die
  Karte bewegt sich darunter. Ein Tippen auf die Karte wäre naheliegend
  und schlechter: Der Finger verdeckt genau die Stelle, die er trifft, und
  ein Tipp löst beim Verschieben leicht aus.
- **Die Kartenwahl beginnt beim ZULETZT GEWÄHLTEN Ort, nicht beim Bezugspunkt**
  (`AppModel.letzterOrt`, `OrtswahlView.kartenstart`, ab 1.0.7, Ansage des
  Nutzers 09/2026: „nicht immer München als Startort, sondern den zuletzt
  gewählten Ort, unabhängig davon, wann das war und wo ich mich momentan
  befinde"). Bis 1.0.6 stand dort `model.punkt?.koordinate` — und `punkt` ist
  im gewöhnlichen Gebrauch der eigene Standort. Die Kartenwahl fiel damit auf
  ihn zurück und ohne Ortung auf einen fest eingebauten Punkt in München. **Wer
  die Karte öffnet, sucht aber gerade NICHT die Stelle, auf der er steht** —
  dafür ist die Zeile darüber da.
  Drei Dinge dabei: Gemerkt wird in `ortWaehlen`, wo Suche, Merkliste und Karte
  zusammenlaufen (ein „zuletzt gewählter Ort", der nur die Karte zählte, wäre
  nach einer Suche wieder der Punkt von vorgestern). **`letzterOrt` ist NICHT
  der Bezugspunkt** — die Tafel startet weiterhin beim eigenen Standort; sie
  mit dem Ort von letzter Woche aufzuschlagen wäre das genaue Gegenteil dessen,
  wofür diese App an einer Haltestelle geöffnet wird. Und die Koordinate liegt
  als DREI Schlüssel in den Voreinstellungen, samt Prüfung auf 0/0: `0,0` ist
  der fehlende Schlüssel und liegt im Golf von Guinea.
- **Die Quellen sind eine KETTE, und die Reihenfolge ist gemessen**
  (`Kettendienst`, ab 1.0.1): Transitous → Verbund vor Ort →
  Zwischenspeicher. Eine Abfahrtstafel wird an einer Haltestelle
  aufgeschlagen, oft mit einem Balken Empfang — genau dort ist eine einzelne
  Quelle ein einzelner Ausfallpunkt. Der Gedanke stammt aus der München-App
  dieses Nutzers (PWA, eigene Sitzung); deren Kette lautet
  Transitous → DB → Cache.
- **Die Kette hat seit 1.1.2 eine Stufe 1b: DIESELBE Schnittstelle auf einer
  ANDEREN Maschine** (`Kettendienst.spiegel`, `TransitousDienst.spiegel` →
  `europe.motis-project.de`, TU Darmstadt). Nachgemessen 18.09.2026 in
  Dortmund, München, Amsterdam, Prag, Kopenhagen, Paris, Zürich und Wien:
  dieselben Abfahrten, dieselbe Echtzeitquote, dieselben Verbindungen mit
  Geometrie — und **austauschbare Fahrtkennungen**, eine Kennung aus der einen
  Instanz öffnet den Lauf in der anderen. Verschieden sind IP, Netz und
  Webserver (`MOTIS v2.11.3` hinter einem eigenen Proxy gegen `Caddy`).
  **Es ist ein zweiter WEG, keine zweite MEINUNG**: dieselben Daten, also
  dieselbe Lücke im Fahrplan. Das hilft gegen einen Ausfall und gegen nichts
  sonst, und genau so steht es im Quelltext.
- **Das größte Loch der Kette war der ANKER** (behoben in 1.1.2). Die Tafel
  holt über `AppModel.ankerHaltestelle` erst die nächste Haltestelle und dann
  die Abfahrten. `haltestellen(um:)` ging aber ausschließlich an Stufe 1 —
  fiel die aus, warf schon dieser Schritt, und `abfahrten(ab:)` wurde nie
  aufgerufen. **Damit waren die Verbünde, die Schweizer Quelle UND der
  Zwischenspeicher unerreichbar, genau in dem Fall, für den es sie gibt.**
  Ein Netz, das nur hält, solange nichts passiert, ist keines. Zwei Griffe:
  `haltestellen`, `haltestellenSuchen`, `orteSuchen` und `fahrt` gehen jetzt
  der Reihe nach an alle VOLLEN Quellen (`Kettendienst.beiEiner`), und
  scheitern die alle, baut `ankerHaltestelle` einen **Behelfsanker** aus dem
  Punkt selbst. Den brauchen die Verbünde auch gar nicht anders: EFA fragt mit
  einer Koordinate, der Schweizer Dienst sucht seine Stationen selbst, der
  Zwischenspeicher schlägt unter Punkt und Umkreis nach. Der Behelfsanker
  trägt **keinen erfundenen Haltestellennamen**, sondern den des Bezugspunkts.
- **„Nichts gefunden" wird in `beiEiner` NICHT weitergereicht.** Beide
  Instanzen führen dieselben Daten; die zweite zu fragen brächte dieselbe
  Antwort und nur eine Wartezeit. Weitergereicht wird nur ein AUSFALL.
- **Niederlande, Tschechien, Dänemark und Frankreich trägt Stufe 1 — gemessen
  18.09.2026** (Ansage des Nutzers, 09/2026: „Braucht bitte die Niederlande,
  Tschechien und Dänemark auch mit ein. Und Frankreich"). Abfahrten mit
  Echtzeit an Amsterdam CS (12 von 30), Utrecht (21 von 24), Rotterdam
  (18 von 28), Praha hl.n. (22 von 28), Brno (1 von 30), København H
  (20 von 31), Aarhus (24 von 25), Odense (21 von 25), Paris Gare de Lyon
  (24 von 26), Lyon Part-Dieu, Toulouse, Strasbourg; Verbindungen mit
  Geometrie in allen vier Ländern, auch über Land (Praha → Brno, København →
  Aarhus, Paris → Lyon). **Diese Länder waren also nie ohne Auskunft** — was
  ihnen fehlte, war das Netz darunter, und das ist seit 1.1.2 der Spiegel.
- **Was es an eigenen Quellen für diese vier Länder gibt — gemessen
  18.09.2026, und das Ergebnis ist mager:**
  - **Niederlande, OVapi** (`v0.ovapi.nl`): antwortet ohne Schlüssel und mit
    Echtzeit (90 Abfahrten an drei Bereichen um Amsterdam CS). **Trotzdem
    nicht gebaut**, und der Grund ist die Geo-Suche: OVapi kennt keine Abfrage
    um einen Punkt, es bräuchte sein Haltestellenverzeichnis
    (`/stopareacode/`, 660 KB, 4574 Bereiche) — und darin tragen **1522
    Einträge, also ein Drittel, dieselbe erfundene Koordinate** 47,974766 /
    3,3135424 (das liegt in Frankreich). Ein Verzeichnis, das ein Drittel des
    Landes still verliert und obendrein bei Lyon 1522 niederländische
    Haltestellen meldet, ist als Rückfall schlimmer als keiner. Wer es doch
    baut, filtert diese Koordinate und schreibt hin, was fehlt.
  - **Dänemark, Rejseplanen**: Die alte offene Schnittstelle
    (`xmlopen.rejseplanen.dk`) ist ABGESCHALTET — sie antwortet mit HTTP 299
    und einem Abkündigungshinweis. Die Nachfolgerin (`www.rejseplanen.dk/api`,
    HAFAS 2.53) ist erreichbar und verlangt `accessId`. Also nein.
  - **Tschechien, Golemio** (`api.golemio.cz`): HTTP 401, Schlüssel nötig.
  - **Frankreich, Navitia und PRIM Île-de-France**: beide HTTP 401, Schlüssel
    nötig. `transport.data.gouv.fr` ist ein Datenkatalog und keine Auskunft.
  Ein Schlüssel in einer App ist keiner — dieselbe Regel wie bei der ersten
  Quelle. Deshalb ist der Spiegel für diese vier Länder der einzige Rückfall,
  den es gibt, und das steht so da, statt mehr zu versprechen.
- **Ein EIGENER Schlüssel lässt sich eintragen** (`Dienste/Schluesselbund.swift`,
  `Fahrplan/Zugang.swift`, `Views/ZugaengeView.swift`, ab 1.1.3; Ansage des
  Nutzers, 09/2026: „In erster Linie möchte ich diese App für mich und meinen
  eigenen Gebrauch haben. Insofern ist doch die Frage, ob man nicht einen
  Schlüssel einlesen kann, wenn denn schon keiner fest verbaut wird."). Der
  Satz „ein Schlüssel in einer App ist keiner" gilt für einen MITGELIEFERTEN
  Schlüssel — der stünde in jedem Bündel. Einer, den der Nutzer selbst holt und
  der in SEINEM Schlüsselbund liegt, ist etwas ganz anderes. **Nicht in den
  Voreinstellungen**: Was dort steht, wandert im Klartext in jedes Backup;
  dieselbe Bauweise wie bei Anstoß.
- **Wo der Schlüssel in die Anfrage gehört, ist GEMESSEN** (18.09.2026, mit
  einem Platzhalter): Wechselt die Fehlermeldung von „kein Schlüssel" zu
  „falscher Schlüssel", liest der Dienst an dieser Stelle. Ergebnis:
  **Navitia** HTTP-Basic (Schlüssel als Benutzername — über `?key=` sieht der
  Dienst gar nichts, „no token"), **NS** Kopfzeile
  `Ocp-Apim-Subscription-Key` („missing" → „invalid"), **Rejseplanen**
  Abfrageparameter `accessId`, **DB API Marketplace** die zwei Kopfzeilen
  `DB-Client-Id` und `DB-Api-Key`. **Golemio als Einziges NICHT bestätigt** —
  es antwortete mit und ohne Kopfzeile wortgleich; `Zugang.gemessen` steht
  dort auf `false`, und die Oberfläche sagt das auch.
- **Der Schlüssel wird ÜBERALL geschwärzt** (`Zugangsprobe.geschwaerzt`), und
  das ist keine Vorsichtsmaßnahme, sondern ein Befund: **Rejseplanen schickt
  einen falschen Schlüssel im Klartext zurück** („access denied for <Schlüssel>
  on location.name"). Ein kopierbarer Befund hätte ihn mitgenommen.
  Geschwärzt wird in der Adresse, im Rohtext und in jeder Fehlermeldung, auch
  in der prozentkodierten Form, und die längsten Geheimnisse zuerst — sonst
  zerlegt ein kurzes Teilstück das lange und der Rest bliebe stehen.
- **Die Probe fragt den ECHTEN Datenweg ab, nicht eine Statusseite.** Das ist
  ihr ganzer Sinn: Was zurückkommt, ist die Antwort, aus der die Quelle gebaut
  wird. Jede Quelle dieser App ist an einer echten Antwort entstanden und
  keine an einer Beschreibung — für einen Zugang, den es ohne Konto nicht zu
  sehen gibt, ist das der einzige ehrliche Weg. Gezeigt werden Status, Deutung
  und die ersten 4000 Zeichen, kopierbar; dieselbe Bauweise wie Schulalarms
  „Zustellung prüfen".
- **Wo der Schlüssel HERKOMMT, steht über dem Eingabefeld** (`Zugang.anmeldung`,
  `Zugang.schritte`, ab 1.1.4, Ansage des Nutzers 09/2026: „Gib mir bitte an, wo
  ich die einzelnen Schlüssel für die einzelnen Länder herunterladen kann. Am
  besten direkt in der App."). Bis 1.1.3 stand dort nur die Startseite des
  Anbieters — und ein Link allein hilft nicht, wenn dahinter ein Portal mit
  zwanzig Produkten liegt. Jetzt: die **Anmeldeseite** als Knopf und zwei bis
  vier Schritte in der Reihenfolge, in der sie zu tun sind. Jede Adresse ist am
  18.09.2026 abgerufen worden:
  - **Navitia (FR)**: `navitia.io/inscription/` — leitet auf `hove.com`, den
    Betreiber. Der Wechsel der Adresse ist richtig so und steht als Schritt da,
    sonst hält man ihn für eine Fehlleitung.
  - **NS (NL)**: `apiportal.ns.nl/signin`. **Das Konto allein genügt nicht** —
    ohne das Abonnement auf das Reisinformatie-API gilt der Schlüssel nicht.
  - **Rejseplanen (DK)**: `labs.rejseplanen.dk/hc/da` — **die einzige Seite,
    die sich aus der Bauumgebung NICHT abrufen ließ** (403, Bot-Schutz). Sie
    steht so in der offiziellen Hilfe; `seiteGeprueft = false`, und die
    Oberfläche sagt es. Damit sind auch die Bedingungen ungeprüft.
  - **Golemio (CZ)**: `api.golemio.cz/api-keys` (braucht JavaScript).
  - **DB (DE)**: `developers.deutschebahn.com/db-api-marketplace/apis/` — hier
    entstehen ZWEI Angaben, Client-Id und Api-Key, und das Produkt Timetables
    muss der Anwendung zugeordnet werden, sonst kommt 401.
- **Ein eingetragener Schlüssel schaltet NOCH KEINE Abfahrten frei**, und die
  Oberfläche sagt das in ihrem ersten Absatz. Die Decoder fehlen, weil sich
  ohne Konto keine einzige Antwort messen ließ; sie zu erraten wäre genau das,
  was dieses Papier sonst verbietet. **Der nächste Schritt ist deshalb: Der
  Nutzer holt einen Schlüssel, tippt auf „Zugang prüfen" und schickt den
  kopierten Befund — daran wird die Quelle gebaut.** Wer das abkürzt und einen
  Decoder nach der Beschreibung schreibt, hat eine Quelle, die aussieht wie
  eine Auskunft und keine ist.
- **Stufe 1 TRÄGT die App, Stufe 2 ist ein Netz darunter** (Ansage des
  Nutzers, 09/2026: „Ich möchte natürlich, dass die App an jeder anderen
  Stelle in Deutschland auch zuverlässig funktioniert."). Transitous deckt
  Deutschland, Österreich, die Schweiz und große Teile Europas ab und
  liefert als Einziges Zwischenhalte und Strecke. **Wo in Stufe 2 nichts
  steht, fehlt also nichts** — das ist kein Loch, sondern der Normalfall.
  Wer das umdreht und die App auf die Verbünde stellt, baut eine App, die
  nur in sieben Gegenden geht.
- **EFA ist KEIN Münchner Sonderweg** (ab 1.0.2). Dieselbe Abfrage, die in
  München antwortet, antwortet Wort für Wort auch in Essen, Stuttgart,
  Karlsruhe, Mannheim, Dresden und Ulm. `MvvDienst` ist deshalb zu
  `EfaDienst` + `EfaStelle` geworden, und München ist eine Zeile in
  `EfaDienst.alle`. **Jede Zeile dieser Tabelle ist am 18.09.2026 mit einer
  echten Koordinatenabfrage geprüft worden und gab Abfahrten MIT Echtzeit
  zurück.** Was sich nicht prüfen ließ, steht dort nicht — auch dann nicht,
  wenn die Adresse plausibel aussieht: Eine ungemessene Quelle ist in einer
  Kette kein Rückfall, sondern nur eine zusätzliche Wartezeit davor.
  Reihenfolge: **erst örtlich, dann weiträumig** (VVS und DING vor `efa-bw`,
  MVV vor `Bayern-Fahrplan` — der örtliche Verbund kennt seine Stadtbusse
  besser). **Ein landesweiter Zugang schlägt einen städtischen**, wo es ihn
  gibt: `Bayern-Fahrplan` (DEFAS) deckt Nürnberg, Würzburg, Augsburg,
  Regensburg und München ab und füllt damit die Lücke, die `VGN` hinterließ
  — dessen Schnittstelle antwortete zwar mit HTTP 200, gab in Nürnberg aber
  null Abfahrten zurück und steht deshalb nicht in der Tabelle.
- **Die Schweiz hängt an `transport.opendata.ch`** (ab 1.0.2), ohne
  Schlüssel, mit Echtzeit (Zürich, Bern, Basel, Genf geprüft). Zwei Fallen:
  **`x` ist die BREITE und `y` die LÄNGE** — die Namen legen das Gegenteil
  nahe, und wer sie nach Gefühl belegt, fragt im Indischen Ozean und bekommt
  eine leere Liste statt einer Fehlermeldung. Und **`delay: nil` heißt
  „keine Echtzeit", `delay: 0` heißt „gemeldet und pünktlich"** — genau der
  Unterschied, den diese App nie verwischen darf. Der Dienst kennt keine
  Tafel um einen Punkt, nur um eine Station: also erst `/v1/locations`, dann
  bis zu drei `/v1/stationboard` nebenläufig. Für eine erste Quelle wäre das
  zu umständlich, für einen Rückfall ist es der richtige Preis.
- **Österreich: Stufe 1 ja, Stufe 2 nein — und das ist gemessen.** Die
  EFA-Stellen von VVT, OÖVV, SVV und VOR waren aus der Bauumgebung nicht
  erreichbar (Verbindungsabbruch bzw. 502 am Proxy), also stehen sie nicht
  in der Tabelle. Die Echtzeit über Stufe 1 ist dort regional verschieden
  (18.09.2026: Graz 11 von 12, Wien/Linz/Innsbruck null, Salzburg eine von
  zehn). **Nicht als erledigt darstellen** — wer die Adressen aus einer
  Umgebung mit freierem Netz prüfen kann, trägt sie nach.
- **Eine API-Abfrage, die einen ALTEN Stand liefert, lügt genauso**
  (Selbstfund 09/2026, beim Bau von 1.1.6). Die Auftragsliste von GitHub
  Actions meldete minutenlang unverändert „Übersetzen — in_progress", während
  der Lauf längst grün durch war. Daraus wurde erst die Diagnose „der
  Typprüfer hängt", dann ein Abbruch des Laufs, dann ein Umbau des Quelltexts
  samt Kommentaren, die diese Messung behaupteten — und nichts davon hatte je
  stattgefunden: Der abgebrochene Lauf war 113 Sekunden alt, der zweite
  übersetzte in 84. **Ein Zustand, der sich nicht ändert, ist zuerst ein
  Verdacht gegen die Abfrage und dann erst einer gegen die Sache.** Dieselbe
  Wurzel wie beim Testskript darunter, nur eine Ebene höher — und dieselbe
  Lehre: **Wer misst, prüft zuerst, dass er wirklich eine frische Antwort in
  der Hand hält.**
- **Es gibt KEINEN frischen Endpunkt — nur Geduld** (Nachtrag beim Bau von
  1.1.7). Oben stand nach dem ersten Fund, beim Warten entscheide `updated_at`
  des LAUFES statt der Schrittliste. Auch das war zu früh geschlossen: Beim
  nächsten Bau stand `updated_at` fünfundzwanzig Minuten lang auf der
  Startminute, die Schrittliste auf „in_progress" und die Protokollabfrage auf
  404 — während der Auftrag in Wahrheit nach 38 Sekunden grün durch war. Alle
  drei Abfragen lagen gleichzeitig daneben. **Aus Unveränderlichkeit lässt
  sich also gar nichts schließen**, weder auf ein Hängen noch auf ein Laufen;
  gezählt hat am Ende allein, dass das Protokoll irgendwann INHALT hatte, und
  darin stehen die wirklichen Zeitstempel. Also: warten, mehrfach fragen, und
  eine Diagnose erst stellen, wenn eine Antwort etwas SAGT — nie, weil eine
  nichts sagt. Und: Was hier nach dem ersten Treffer als Regel notiert wird,
  ist selbst eine Vermutung, solange es nur einmal gesehen wurde.
- **Ein Testskript, das seine Antwortdatei wiederverwendet, lügt**
  (Selbstfund 09/2026). Beim Vermessen der Verbünde schrieb `curl` in eine
  feste Datei; schlug der Aufruf fehl, las das Skript die Antwort des
  VORIGEN Verbundes und meldete für Innsbruck und Linz „6 Abfahrten, 5
  Echtzeit" — in Wahrheit Stuttgarter Daten. Seither: je Messung eine eigene
  Datei, und der HTTP-Code wird mitgedruckt. **Wer eine Quelle misst, prüft
  zuerst, dass er wirklich ihre Antwort in der Hand hält.**
- **`Fahrplandienst` und `Abfahrtsquelle` sind ZWEI Protokolle, mit Absicht.**
  Nicht jede Quelle kann alles: EFA liefert eine vorzügliche Abfahrtstafel,
  aber keine Streckengeometrie — und eine Fahrt ohne Strecke hat in dieser
  App keinen Bildschirm. Sie als `Fahrplandienst` auszugeben hieße, vier
  Methoden zu versprechen und zwei mit „geht nicht" zu beantworten; das ist
  keine Trennung, sondern eine Lüge mit Protokoll. Die Ansichten sehen
  weiterhin NUR `Fahrplandienst` — `Kettendienst` fügt beides zusammen.
- **EFA: was sie kann, ist nachgemessen und nicht angenommen** (09/2026).
  Über eine KOORDINATE (`type_dm=coord`) liefert sie die Abfahrten aller
  Haltestellen im Umkreis samt Echtzeit — aber **nur im Verbundgebiet**
  (Hamburg, Berlin, Frankfurt: null Abfahrten). Über eine KENNUNG
  (`type_dm=any` mit `de:09162:2`) antwortet sie bundesweit, dort aber
  **ohne Echtzeit** (null von vier). Gebaut ist deshalb nur der erste Weg,
  und `zustaendig(fuer:)` hält die Anfrage auf, wo sie nichts brächte.
  Drei Fallen dabei (sie gelten für JEDE EFA-Stelle): In der ANFRAGE steht
  die **Länge zuerst**
  (`11.575:48.137`), in der Antwort die **Breite** — vertauscht kommt keine
  Fehlermeldung, sondern eine leere Liste. Ohne `coordOutputFormat=WGS84`
  kommen Koordinaten in einem fremden Gitter (gemessen: 5870282, 1288570).
  Und ein Kennungs-Suffix `_G` lässt die Abfrage still ins Leere laufen.
- **Echtzeit gilt bei EFA nur mit `isRealtimeControlled`.** Eine geschätzte
  Zeit, die zufällig der Planzeit gleicht, sähe sonst aus wie „pünktlich" —
  und das ist etwas völlig anderes als „niemand hat nachgesehen".
- **Der Zwischenspeicher ist KEIN Beschleuniger** (`Abfahrtsspeicher`, ab
  1.0.1). Er wird nur gelesen, wenn ALLE Quellen ausgefallen sind, und was
  er herausgibt, trägt seinen Zeitstempel bis in die Oberfläche
  (`Fahrplanfehler.veralteterStand` — ein Fehler, der Daten MITBRINGT).
  Dann steht ein Band darüber, die Fußzeile nennt die Uhrzeit, und **die
  Minutenziffern werden abgeschaltet**: Sie sind die einzige Angabe, die
  fortlaufend etwas behauptet, und eine weiterzählende Ziffer über alten
  Daten ist eine Lüge, die wie eine Auskunft aussieht. Höchstalter zwei
  Stunden, höchstens zwölf Haltestellen, und er liegt in den **Caches** —
  was der Nutzer selbst angelegt hat (die Merkliste), liegt woanders.
- **Nicht jede Zeile lässt sich öffnen** (`Abfahrt.hatFahrtlauf`). Die
  Verbünde geben keine Fahrtkennung heraus; solche Zeilen stehen ohne Pfeil da, und die
  Fußzeile sagt warum. Eine Zeile, die aussieht wie ein Knopf und beim
  Tippen nichts tut, ist für den Menschen davor ein kaputter Knopf.
- **`Abfahrt.id` trägt Linie und Richtung mit.** Ohne Fahrtkennung (Stufe 2)
  bildete eine Tafel sonst zwei Abfahrten derselben Minute an derselben
  Haltestelle auf einen Schlüssel ab — eine davon verschwände
  stillschweigend aus der Liste.
- **Auf dem iPad stehen Liste und Karte NEBENEINANDER** (ab 1.0.3, gemeldet
  09/2026: „Die Darstellung auf dem iPad ist doch sehr in die Breite
  gezogen."). Eine `List` füllt, was da ist; im Querformat sind das gut
  zweitausend Punkte, und die Zeile wird von der Breite auseinandergezogen,
  statt sie zu benutzen. Dagegen zwei Dinge: das zweispaltige Layout bei
  Breitenklasse `regular`, und `Views/Lesebreite.swift` (760 Punkte, mittig)
  auf jeder Zeile. **Die Lesebreite liegt auf der GANZEN Zeile und nicht auf
  ihrem Inhalt** — bei einem `NavigationLink` stünde der Pfeil sonst weiter
  ganz außen und die Zeile sähe genauso zerrissen aus wie vorher.
- **Das Liniennetz wird NACHGELADEN und gedeckelt** (`Model/Liniennetz.swift`,
  ab 1.0.3). Eine Abfahrt weiß, WANN etwas fährt, nicht WO es langfährt; der
  Verlauf steht am Fahrtlauf, und den gibt es nur einzeln. Für zwölf Linien
  sind das zwölf Abfragen — deshalb nebenläufig, auf zwölf gedeckelt und erst,
  wenn jemand die Karte ansieht. Zusammengefasst wird über Linie UND
  Verkehrsmittel, nicht über die Richtung: Die Gegenrichtung fährt denselben
  Weg zurück und verdoppelte nur die Abfragen. `gebautAus` verhindert, dass
  jeder Takt des `Uhrwerks` das ganze Netz neu holt — **ohne diese Prüfung
  lüde die Karte im Sekundentakt zwölfmal nach.**
- **Gewählt werden die NÄCHSTEN zwölf Linien, nicht die zuerst abfahrenden**
  (`Liniennetz.wuenscheBauen`, ab 1.1.24; gemeldet 09/2026: „Am Karl-Preis-Platz
  hält die U2. Warum ist die bei den Linien nicht aufgeführt?“). Sie stand sehr
  wohl in den Daten — sie fiel aus der ZWÖLFER-GRENZE. Bis 1.1.23 nahm
  `wuenscheBauen` die ersten zwölf Linien in der Reihenfolge der ABFAHRTEN, und
  die ist nach Zeit sortiert. **Nachgemessen am 19.09.2026 am Karl-Preis-Platz**,
  200 Abfahrten im Umkreis von 3 km: Sie deckten **drei Minuten** ab und
  enthielten **43 verschiedene Linien**; die ersten zwölf waren die, deren
  Fahrzeug in den ersten Sekunden zufällig losfuhr — S5, S6, 100, 132, 139, 145,
  155, 17, 185, 187, 18, 190, größtenteils vom zwei Kilometer entfernten
  Ostbahnhof. **Die U2, die direkt unter dem Bezugspunkt hält, stand auf Platz
  18.** Dieselbe Messung nach Nähe sortiert: 59 (0 m), 155 (85 m), **U2
  (118 m)**, 55, 145, 54, U5, U8, 191 — also die Linien, die dort halten, wo der
  Mensch steht. Bei gleichem Abstand gilt weiter die Zeit. Dasselbe Muster wie
  1.1.10: **Wenn etwas fehlt, ist die Zuordnung der zweite Verdacht und das
  Fenster der erste** — nur ist es hier nicht das Zeitfenster, sondern die
  Auswahl daraus.
- **Der gezeichnete Lauf bleibt der FRÜHESTE** dieser Linie, nicht der
  nächstgelegene. Die Nähe entscheidet, WELCHE Linien gezeichnet werden, nicht
  WELCHER Lauf — geändert wird eine Sache auf einmal, sonst sagt der nächste
  Befund nichts mehr.
- **Was die Grenze weglässt, wird GEZÄHLT** (`Liniennetz.nichtGezeichnet`, ab
  1.1.24). Das ist die schlimmere Hälfte desselben Befundes: `ohneVerlauf` zählt
  nur Linien, deren Quelle gar keinen Lauf herausgibt. Eine Linie MIT
  Fahrtkennung, die bloß nicht mehr in die Zwölf passte, galt als „zeichenbar“
  und tauchte in keiner Zahl auf — die Karte zeichnete zwölf Linien und sagte
  mit keinem Wort, dass einunddreißig fehlten. **Die Regel stand seit 1.0.3
  daneben und galt für diesen Fall nicht**: „Eine Karte, in der stillschweigend
  Linien fehlen, ist eine Karte, der man ihre Unvollständigkeit nicht ansieht.“
  Die Fußzeile nennt jetzt die Zahl und sagt, was hilft (kleinerer Umkreis oder
  ein Filter) — dieselbe Bauweise wie „Hineinzoomen zeigt sie“ bei den Halten.
  **Wer eine neue Grenze einzieht, zählt, was sie wegnimmt.**
- **Die beiden Zählungen werden IMMER nachgeführt, die Abfrage nicht.** Sie
  hängen an ALLEN Abfahrten und nicht an den gewählten zwölf: Kommt eine
  dreizehnte Linie dazu, ohne die Auswahl zu ändern, stimmte die Zahl darunter
  sonst nicht mehr, und `netz.stand` bliebe gleich. Deshalb stehen sie vor dem
  `guard` — und deshalb stehen `nichtGezeichnet` und `ohneVerlauf` seit 1.1.24
  auch in den Auslösern von `neuRechnen`. Zugewiesen wird nur bei echter
  Änderung: Ein `@Published`, das denselben Wert noch einmal bekommt, lässt die
  Karte trotzdem neu zeichnen (die Lehre aus 1.1.16), und `aufbauen` läuft im
  Sekundentakt.
- **Was sich nicht zeichnen lässt, wird GEZÄHLT und hingeschrieben**
  (`Liniennetz.ohneVerlauf`). Linien aus Stufe 2 haben keine Fahrtkennung und
  damit keinen Verlauf. Eine Karte, in der stillschweigend Linien fehlen, ist
  eine Karte, der man ihre Unvollständigkeit nicht ansieht.
- **Die Karte benutzt DENSELBEN Filter wie die Liste** (`AppModel.filter`).
  Zwei Filter für dieselbe Frage wären zwei Antworten.
- **Eine Umleitung steht in den DATEN — als Merkmal am einzelnen HALT**
  (ab 1.0.8, nachgemessen 18.09.2026 an der Linie 448 in Dortmund: „Hombruch
  Friedhof" kam als entfallen zurück, 1 von 23 Halten). Zwei Felder, und beide
  werden gebraucht: `cancelled` am Ort, und — wo die Quelle das nicht setzt —
  `pickupType` UND `dropoffType` auf `NOT_ALLOWED`. **Nur beides zusammen**,
  denn am ersten Halt ist der Ausstieg planmäßig verboten und am letzten der
  Einstieg; eine Oder-Prüfung kappte jede Fahrt an beiden Enden
  (`TransitousDienst.haltEntfaellt`). An der ABFAHRT heißt dasselbe
  `pickupDropoffType` — steht es dort auf `NOT_ALLOWED`, hält das Fahrzeug an
  DIESER Haltestelle nicht, und ohne diese Zeile stünde die Abfahrt unverändert
  in der Tafel: Jemand wartete auf einen Bus, der vorbeifährt.
- **Der UMLEITUNGSWEG steht in KEINER Quelle — er wird nicht erfunden.**
  Dieselbe Messung: Der Halt entfiel, die Streckengeometrie kam unverändert
  planmäßig zurück (457 Punkte). Gezeichnet wird deshalb weiter der Planweg,
  und beide Karten schreiben ausdrücklich hin, dass er es ist
  (`StreckenKarte.entfalltext`, `LiniennetzView`-Fußzeile). Ein Linienzug, der
  sich eine Umleitung ausdenkt, sieht aus wie eine Auskunft und ist keine —
  dieselbe Regel wie bei der gestrichelten Luftlinie.
- **Ein entfallender Halt wird auf der Karte NIE weggelassen.** Über der
  Grenze von 260 Punkten zeichnet `sichtbareHalte` keine gewöhnlichen Halte
  mehr, die entfallenden aber schon: Sie sind der Grund, aus dem jemand die
  Karte aufschlägt. Aus demselben Grund tragen sie ihren Namen auch dann,
  wenn keine Linie hervorgehoben ist. Gezeichnet wird rot UND mit Kreuz —
  Farbe allein sieht ein farbfehlsichtiger Mensch nicht.
- **`Linienzug.halte` sind `Zwischenhalt`e, keine Haltestellen** (ab 1.0.8).
  Nur der Zwischenhalt weiß, ob er heute angefahren wird; mit blossen
  Haltestellen ist eine Umleitung auf der Netzkarte unsichtbar.
- **Ein entfallender Halt steht in den MUSTERDATEN** (`Musterdienst`,
  Fasangarten). Der Fall lässt sich nicht herbeiführen, wenn man ihn ansehen
  will — ohne ihn in den Beispieldaten wäre jede Anzeige dafür nur dann zu
  prüfen, wenn gerade irgendwo eine Straße gesperrt ist.
- **Was Transitous NICHT hat: geplante Sperrungen in der Zukunft.** Gemessen
  18.09.2026 an sieben S8-Stationen (Ismaning, Hallbergmoos, Unterföhring,
  Herrsching, Weßling, Gilching-Argelsried, Daglfing, Johanneskirchen), jeweils
  Sa 17.10. gegen Sa 24.10.: gleiche Zahl S8-Fahrten, kein Ersatzverkehr, keine
  Meldung. Eine Sperrung, die andere Apps für den 24.10. anzeigen, steht in den
  DELFI-Daten also nicht — sie kommt dort aus DBs eigener Auskunft. **Das nicht
  als Fehler der App darstellen und nicht als lösbar versprechen**, solange
  keine Quelle dafür gemessen ist. `/stoptimes` nimmt übrigens `time` entgegen
  und antwortet für künftige Tage; die App fragt bisher immer „jetzt".
- **Züge fielen aus dem FENSTER, nicht aus der Zuordnung** (zweite Abfrage in
  `TransitousDienst.abfahrten`, ab 1.1.10; Ansage des Nutzers 09/2026: „In
  München fahren garantiert noch andere Züge ab … Bitte nimm noch weitere
  Verkehrsverbindungen in die App auf"). `REGIONAL_RAIL` und `HIGHSPEED_RAIL`
  standen seit der ersten Fassung in `verkehrsmittel(_:)` — es kam nur fast nie
  eines an. `/stoptimes` gibt die nächsten `n` Abfahrten ALLER Haltestellen im
  Umkreis zurück, nach Zeit sortiert, und in einer Innenstadt sind das Busse
  und Trams. **Nachgemessen 18.09.2026 an der Arnulfstraße in München:** Die 40
  Abfahrten der App deckten **drei Minuten** ab (16:42–16:45), darin zwei
  Regionalzüge. Ein Zug fährt seltener als eine Tram und verliert dieses Rennen
  immer — je besser die Stadt mit Bussen bedient ist, desto sicherer.
  **Merke: Wenn eine Art Fahrt fehlt, ist die Zuordnung der zweite Verdacht und
  das Zeitfenster der erste.**
- **Die seltenen Verkehrsmittel bekommen eine EIGENE Abfrage.** Dieselben 40
  Zeilen mit `mode=REGIONAL_RAIL,HIGHSPEED_RAIL,LONG_DISTANCE,NIGHT_RAIL,COACH,FERRY`
  deckten **54 Minuten** ab: RE5 nach Salzburg (über Freilassing), RE25, RB16,
  RB6, ICE 500 nach Berlin, dazu Fernbusse. Es ist keine zweite Quelle, sondern
  dieselbe mit einem zweiten Fenster; beide laufen nebenläufig und werden über
  `Abfahrt.id` entdoppelt und neu sortiert. **`FERRY` steht bewusst mit drin**,
  obwohl in München keine fährt — eine Fähre ist genauso selten und verlöre
  dasselbe Rennen. **Die Zusatzabfrage darf die Tafel nie mitreißen**: Scheitert
  sie, fehlen Züge, aber die Busse stehen da; andersherum wäre der Schaden
  größer.
- **`mode` ist der einzige Parametername, der wirkt — und ein falscher fällt
  NICHT auf.** Gemessen 18.09.2026: `modes=` und `transitModes=` werden mit
  HTTP 200 angenommen und **stillschweigend ignoriert**, die Antwort kommt
  ungefiltert zurück und sieht tadellos aus. Ein falscher WERT dagegen wird
  abgewiesen („invalid value … for enum ModeEnum"). Wer hier etwas ändert,
  prüft am ZEITFENSTER der Antwort, ob der Filter gegriffen hat, nicht am
  Status. Und **`RAIL` ist eine Obergruppe**: Damit kamen U-Bahn und S-Bahn mit
  zurück, und das Fenster war wieder zu.
- **`COACH` ist ein FERNBUS, kein Stadtbus** (neunter Fall `fernbus`, ab
  1.1.10). Bis dahin lief er als `.bus` mit und stand zwischen den Stadtbussen;
  ein FlixBus nach Zagreb ist aber weder das eine noch das andere. Eigene
  Rückfallfarbe (Olivbraun — gemessen kleinster Abstand dE 37,8 zu allen
  anderen, Schriftkontrast 7,0:1), eigenes Symbol, eigene Filterzeile. Die
  Filterleiste baut sich aus `AppModel.vorhandeneMittel` und zeigt die neuen
  Zeilen von selbst, sobald so etwas abfährt.
- **Die Zugnummer in Klammern wird abgeschnitten, alles andere nicht**
  (`ohneZugnummer`). Transitous schreibt „RE5 (79039)" und „RB16 (59162)" —
  auf einem Liniensymbol ist das unlesbar. Gemessen an 151 Zugnamen aus
  München, Dortmund, Hamburg, Berlin, Freilassing und Wien: 68 enden auf eine
  Klammer, und in **jedem einzelnen Fall** stehen darin nur Ziffern. Kein
  Gegenbeispiel — also wird genau dieser Fall abgeschnitten. **Ohne Klammern
  wird NICHTS abgeschnitten**: In Österreich hängt die Nummer ohne sie dran
  („REX 7757", „R 2578", „RRR 7757"), und dort ist nicht zu entscheiden, wo die
  Linie aufhört und die Nummer anfängt. Ein langes Schild ist besser als ein
  falsches.
- **Ein Bahnhof stand unter ZWEI Namen in der Liste — behoben in 1.1.23.** Der
  Punkt stand seit 1.1.10 als offener im Papier, mit der Auflage, zuerst an
  echten Daten zu messen. **Nachgemessen am 19.09.2026 an 22 deutschen
  Städten** (je rund 150 Abfahrten im Umkreis von 500 Metern um den
  Hauptbahnhof, 170 verschiedene Haltestellennamen): Der Fall kommt in ACHT von
  22 Städten vor — Augsburg, Bremen, Erfurt, Kiel, Leipzig, Mannheim, München,
  Nürnberg. **Und es sind ZWEI Risse, nicht einer:** „Hbf“ gegen
  „Hauptbahnhof“ (Nürnberg 75 zu 1, Augsburg 111 zu 3, Bremen 53 zu 12) und
  das Komma, mit dem viele Verbünde den Ort vom Halt trennen („Erfurt,
  Hauptbahnhof“ gegen „Erfurt Hbf“; ebenso Leipzig und Mannheim, und in Prag
  „Praha,Hlavní nádraží“ gegen „Praha hlavní nádraží“). Wer nur die
  Abkürzung ausschreibt, lässt drei der acht Städte doppelt stehen.
- **Ausgeschrieben wird Wort für Wort, verglichen wird auf GLEICHHEIT**
  (`Haltestellengruppe.vergleichsname`). Der gefährliche Griff wäre, „Hbf“ und
  „Hauptbahnhof“ irgendwo im Namen zusammenzuziehen — und dieselbe Messung
  zeigt an derselben Stelle, was das kostet: Um den Münchner Hauptbahnhof
  liegen „Hauptbahnhof Nord“, „Hauptbahnhof Süd“ und „Hauptbahnhof (U, Tram)“
  innerhalb von 270 Metern, in Dresden steht „Dresden Hauptbahnhof“ neben
  „Dresden Hauptbahnhof Nord“ und „Dresden Hbf (Strehlener Str.)“, in Kassel
  „Kassel Hauptbahnhof“ neben „Kassel Hauptbahnhof Nord“. Das sind
  verschiedene Haltestellen, und ihr Unterschied ist genau der, den ein
  Wartender braucht. Ergebnis der Messung: acht Zusammenlegungen, **keine
  falsche**. **Umlaute werden weiterhin nicht eingeebnet**, und wer die Liste
  der Abkürzungen erweitert, misst wieder nach.
- **Welche Schreibweise dasteht, entscheidet die MEHRHEIT**
  (`Haltestellengruppe.anzeigename`), nicht die erste und nicht die längere.
  Auch das ist gemessen und geht in beide Richtungen: In Nürnberg und Augsburg
  ist die Kurzform die übliche, in Bremen und Kiel die lange, in Erfurt und
  Mannheim die mit Komma. Eine feste Vorliebe schriebe an jedem zweiten Ort
  etwas hin, was dort niemand sagt. Bei Gleichstand die längere. **Gebaut wird
  kein Name** — was dasteht, hat eine Quelle so geschrieben.
- **Die Tafel hat einen wählbaren ZEITPUNKT** (`AppModel.bezugszeit`, ab
  1.1.11, Ansage des Nutzers 09/2026). „Jetzt" oder ein Datum, umgeschaltet
  über dieselbe `Zeitleiste`-Bauweise wie in der Verbindungsauskunft — es ist
  dieselbe Frage, und zwei Bedienungen dafür wären zwei Dinge zu lernen.
  **Drei Stellen hängen daran, und alle drei behaupteten vorher „jetzt":**
  - `gefiltert` schneidet Abfahrten ab, die länger als eine Minute vorbei
    sind — gemessen gegen die BEZUGSZEIT und nicht gegen die Uhr. Sonst läge
    bei einer Tafel für morgen früh jede Abfahrt vor der Grenze und die Liste
    wäre leer.
  - **Die Minutenziffer wird abgeschaltet** (`AbfahrtsZeile.fuerGewaehlteZeit`).
    „In 3 Minuten" über einer Tafel für morgen früh ist falsch, und zwar auf
    dieselbe Art wie eine weiterzählende Ziffer über altem Stand aus dem
    Zwischenspeicher. Dieselbe Regel, zweiter Anlass.
  - **Der Nachladelauf ruht** (`RootView`): Dieselbe Abfrage alle dreißig
    Sekunden brächte dieselbe Antwort.
  **Der gewählte Zeitpunkt steht NICHT in den Voreinstellungen**, anders als
  Umkreis und Anzahl. Er ist eine einmalige Frage; wer die App am nächsten Tag
  an einer Haltestelle aufschlägt, will die Tafel von jetzt. Eine gespeicherte
  Zeit sähe aus wie eine ganz gewöhnliche Tafel und wäre eine.
- **`anzahl` geht bis 200** (ab 1.1.11, Ansage des Nutzers). Dabei gehört der
  gemessene Zusammenhang aus 1.1.10 in die Fußzeile der Einstellungen: In einer
  Innenstadt kauft eine höhere Zahl vor allem mehr Busse — vierzig Abfahrten
  decken dort rund drei Minuten ab. Züge, Fernbusse und Fähren werden davon
  nicht knapper, sie haben ihr eigenes Fenster.
- **Die Karte lässt sich auf den ganzen Bildschirm ziehen** (`Vollbildkarte`,
  ab 1.1.11, Ansage des Nutzers 09/2026). Auf dem iPad liegt neben der Liste
  nur ein Ausschnitt, und was jemand sucht, liegt oft genau daneben.
  **Zwei Wege mit Absicht**: ein Tipp auf die freie Kartenfläche und ein Knopf
  unten links. Die Halte und die Liniennummern bleiben Knöpfe und behalten ihre
  eigene Aufgabe — ein Tipp auf einen Halt öffnet weiterhin dessen
  Abfahrtstafel (1.1.7). Eine Geste, die niemand kennt, ist so wenig wert wie
  ein Knopf, den niemand findet; deshalb beides.
- **Ein eigener Stapel braucht ALLE Ziele, nicht eines** (`Views/Fahrplanziele.swift`,
  ab 1.1.25; gemeldet 09/2026: „Ein Tipp auf eine Linie bewirkt leider gar
  nichts"). Die Vollbildkarte macht seit 1.1.11 einen eigenen
  `NavigationStack` auf und trug darin `Haltestelle` ein, aber **nicht**
  `Fahrtwunsch`. Wer dort einen Halt antippte, kam in dessen Abfahrtstafel —
  und von da an ging es nicht weiter: Jede Zeile ist ein
  `NavigationLink(value: Fahrtwunsch(…))`, und ein Verweis, dessen Wertetyp im
  Stapel kein Ziel hat, tut NICHTS. Kein Absturz, keine Meldung, keine
  Bewegung; für den Menschen davor ein kaputter Knopf.
- **Die Lehre stand schon da und war trotzdem nicht gezogen.** Über genau
  dieser Zeile stand seit 1.1.11 der Kommentar „Ein eigener Stapel braucht sein
  eigenes Ziel. Dieselbe Falle wie in 1.1.7" — und darunter wurde EINES der
  zwei Ziele eingetragen. Dasselbe Muster wie bei Schulalarms
  `requestAuthorization`, wo die Falle im Kommentar beschrieben stand und die
  Prüfung fehlte: **Ein Kommentar ersetzt keine Prüfung.** Deshalb ist es jetzt
  kein Merksatz mehr, sondern ein Modifikator: `.fahrplanziele()` hängt an
  allen vier Stapeln (Tafel, Vollbildkarte, Merkliste, Verbindung) und trägt
  beide Ziele. **Wer einen neuen Stapel baut, hängt ihn dran; wer ein drittes
  Ziel braucht, trägt es DORT ein.** `Verbindung` steht bewusst nicht darin —
  die gibt es nur in der Auskunft, und ein Ziel für einen Wert anzumelden, der
  in diesem Stapel nie vorkommt, verspräche einen Weg, den es nicht gibt.
- **Erst die LAGE prüfen, dann die Arbeit machen** (`berechneHalte`, ab
  1.1.25). Bis 1.1.24 wurde für JEDEN Halt JEDER Linie ein Punkt gebaut —
  samt `gemeldet(…)`, also einem Textvergleich gegen die Meldungsliste — und
  ERST DANACH auf den Ausschnitt gefiltert. `hoechstzahlHalte` deckelte damit,
  was GEZEICHNET wird, nicht, was durchgegangen wird. **Gemessen am
  19.09.2026 am Karl-Preis-Platz**, 3 km Umkreis: zwölf Linien haben dort 292
  Halte, dreiundvierzig **2.125** — und das lief bei jedem Neurechnen durch,
  also bei jeder Schiebebewegung. Dieselbe Falle wie 1.1.16, nur eine Ebene
  tiefer und mit der Zahl der Linien wachsend. Das Ergebnis ändert sich durch
  das Vorziehen nicht: Eine Haltestelle hat genau eine Koordinate, also fällt
  `imSichtfeld` für alle ihre Vorkommen gleich aus — Filtern und Entdoppeln
  sind vertauschbar.
- **Die Grenze steht auf ZWANZIG (ab 1.1.25), und der Engpass ist nicht der,
  der bis 1.1.24 dabeistand** (Frage des Nutzers 09/2026: „Würde die App
  zusammenbrechen, wenn die Anzahl erhöht würde?"). Nachgemessen am
  19.09.2026 am Karl-Preis-Platz, 3 km Umkreis, 43 verfügbare Linien:
  - **Die Abfragen kosten nichts.** Nebenläufig, also entscheidet die
    langsamste: 12 Linien 1,39 s, 24 Linien 1,39 s, 43 Linien 1,40 s; keine
    Drosselung, kein Fehler, 205 KB gegen 1,4 MB. „Das sind zwölf
    Netzabfragen" stand hier bis 1.1.24 als Begründung und war keine.
  - **Beim Öffnen ist auch das Zeichnen harmlos** — die Vereinfachung aus
    1.1.17 greift sogar besser, je mehr Linien es sind (3,7 % bei zwölf,
    2,1 % bei 43), weil das Netz weiter reicht und ein Bildpunkt mehr Meter
    bedeutet.
  - **Beim Hineinzoomen kippt es.** Gezeichnete Koordinaten am Straßenzug:
    12 Linien 4.530, 20 Linien 20.026, 43 Linien 29.320. Zwanzig erreichen
    damit ungefähr die Größe, die 1.1.17 als das Gewicht gemessen hat (rund
    25.000) — der Unterschied ist, wie OFT sie anfällt: damals bei jeder
    Zeichnung im Sekundentakt, seit 1.1.16/1.1.17 nur auf einen echten
    Auslöser. **Das ist die ehrliche Hälfte der Antwort und kein Freibrief.**
  - **Nicht gemessen ist die Wirkung auf dem Gerät** — gezählt sind
    Koordinaten, nicht Bildwiederholungen. Fühlt sich die Karte hineingezoomt
    zäh an, ist `hoechstzahl` die Zahl, die man senkt; „Karte prüfen" nennt
    die Stützpunkte roh und gezeichnet.
- **Zwei getrennte Hell-Dunkel-Umschalter** (`Views/Darstellung.swift`, ab
  1.1.12, Ansage des Nutzers 09/2026). Einer für die App
  (`preferredColorScheme` an der WURZEL — weiter unten gesetzt erwischte es
  Blätter und Vollbilder nicht), einer für die KARTEN
  (`.kartendarstellung()`, ein `environment(\.colorScheme, …)` über den
  Kartenausschnitt). Getrennt, weil es zwei Fragen sind: Eine dunkle Karte ist
  abends am Bahnsteig angenehm und bei Sonne unlesbar — die Liste daneben hat
  damit nichts zu tun.
  - **Die Kartenwahl gilt für ALLE VIER Karten** — Liniennetz, Fahrtlauf,
    Verbindung und Ortswahl. Eine Einstellung, die nur eine davon trifft, ist
    für den Menschen davor ein Fehler.
  - **Die Haut gehört HINTER die Überlagerungen.** Eine Überlagerung wird von
    außen an das fertige Bild gehängt und erbt die Umgebung des ÄUSSEREN
    Zusammenhangs; davor gesetzt bliebe die Legende hell auf einer dunklen
    Karte. Die Fußzeile unter der Netzkarte bleibt dagegen außen vor: Sie
    erklärt die Zeichenweise und gehört zur App.
  - **„Wie die App" wird an EINER Stelle aufgelöst** (`Kartendarstellung.geltend`).
    Gebraucht wird der Wert an zwei Enden — der Modifikator legt ihn über die
    Karte, und `LiniennetzView` braucht ihn noch einmal als Zahl, weil die
    Kontur unter einem Linienzug die Gegenfarbe zur Karte sein muss. Zwei
    Fassungen liefen auseinander, und dann läge auf einer dunklen Karte eine
    weiße Kontur.
  - **`system` bzw. „wie die App" bleibt die Vorgabe.** Wer nichts einstellt,
    bekommt weiterhin die geplante Umschaltung zur Dämmerung, die iOS von
    selbst macht.
  - **Nicht gemessen:** Ob MapKits SwiftUI-`Map` die überschriebene
    `colorScheme` wirklich annimmt, lässt sich nur auf einem Gerät sehen. Es
    ist der dokumentierte Weg für einen Teilbaum, aber eine Erwartung und
    keine Messung — wer es prüft, trägt das Ergebnis hier nach.
- **Es war nie ein Umkreis, es war eine ZÄHL-GRENZE** (`sichtbareHalte`, ab
  1.1.13; gemeldet 09/2026: „Haltestellen gibt es offenbar nur in einem
  bestimmten Umkreis vom Suchpunkt … bei den S-Bahn-Linien werden weiter
  entfernte Haltestellen nicht angezeigt."). Über 260 Punkten zeichnete die
  Karte GAR KEINE gewöhnlichen Halte mehr, nur noch die entfallenden — und
  zwölf Linien in München haben zusammen weit über dreihundert. Die Grenze riss
  also immer, und was übrig blieb, sah aus wie ein Umkreis um den Suchpunkt:
  Die weißen Kreise in der Mitte sind die Haltestellen aus der LISTE, nicht die
  der Linien. **Wer einen Befund liest, prüft zuerst, ob das beschriebene
  Muster überhaupt das gebaute ist.**
- **Gezählt wird jetzt, was im AUSSCHNITT liegt** (`imSichtfeld`, `sichtfeld`
  über `onMapCameraChange(frequency: .onEnd)`). Die Grenze bleibt, denn ihr
  Grund bleibt — jeder Punkt ist eine eigene SwiftUI-Ansicht, und dreihundert
  davon machen die Karte zäh. Sie zählt aber nur noch das Sichtbare, und damit
  gibt es die Halte überall: Wer zur S-Bahn-Strecke schiebt oder hineinzoomt,
  bekommt dort ALLE. Das ist der Unterschied zwischen „fehlt" und „steht
  gerade nicht im Bild", und die Fußzeile sagt ihn jetzt auch
  („Hineinzoomen zeigt sie"). Rand von einem Zehntel, damit beim Schieben
  nicht an jeder Kante eine Reihe Punkte aufpoppt; `nil` (Kamera hat sich noch
  nicht gemeldet) heißt „alles", sonst wäre die Karte beim ersten Zeichnen
  leer. **`.onEnd` und nicht `.continuous`** — sonst würde die Haltliste
  während jeder Schiebebewegung neu gerechnet.
- **Ein LANGER Tipp auf die Netzkarte setzt den Suchpunkt** (`punktSetzen`, ab
  1.1.13, Ansage des Nutzers 09/2026: „Ich mag nicht immer erst wieder in
  dieses Menü gehen müssen."). Der kurze Tipp zieht die Karte auf (1.1.11),
  der lange versetzt den Punkt.
  - **`LongPressGesture` allein meldet nur, DASS gehalten wurde, nicht WO.**
    Deshalb `.sequenced(before: DragGesture(minimumDistance: 0))` — und
    genommen wird `startLocation`, nicht `location`: Der Finger wandert beim
    Halten ein paar Punkte, gemeint ist die Stelle, auf die gezeigt wurde.
    Umgerechnet wird über `MapProxy.convert` aus einem `MapReader`; welche
    Koordinate unter einem Bildschirmpunkt liegt, weiß allein die Karte.
  - **Erst den Namen holen, dann setzen.** Ein nachträgliches Umbenennen
    änderte `model.punkt` ein zweites Mal, und daran hängt
    `onChange(of: model.punkt)`: Die Karte stellte sich mitten in der Bewegung
    neu ein. Eine Karte, die springt, nachdem man gerade einen Punkt gesetzt
    hat, sieht kaputt aus. Damit die Wartezeit nicht wie ein toter Knopf
    wirkt, meldet sich das Gerät sofort spürbar.
- **Der Name zu einer Koordinate steht an EINER Stelle** (`Dienste/Ortsname.swift`,
  ab 1.1.13). Gebraucht wird er unter dem Fadenkreuz der Ortswahl und beim
  langen Tipp; zwei Fassungen benannten denselben Punkt irgendwann verschieden.
  **`nil` heißt „konnte nicht nachsehen" und nicht „heißt nicht"** — die
  Ortswahl behält dann den Namen von vorhin, statt ihn beim Schieben durch
  einen Platzhalter zu ersetzen.
- **Eine Geste, die „nichts bewirkt", ist zuerst ein Verdacht gegen die
  KAMERA** (ab 1.1.14; gemeldet 09/2026: „Das Zoomen auf der Karte fällt
  manchmal schwer, gerade wenn sie neu geöffnet ist … bewirkt die Geste mit
  zwei Fingern nichts."). Es war keine Geste, die nicht ankam, sondern eine,
  die weggeräumt wurde: `Liniennetz` ersetzt `zuege` in EINEM Zug, sobald alle
  Fahrtläufe da sind — ein bis drei Sekunden nach dem Öffnen —, und genau
  darauf saß ein `onChange`, das den Ausschnitt neu setzte. Wer in dieser
  Zeitspanne zoomte, sah seine Geste wirken und sofort wieder verschwinden.
  Dasselbe noch einmal alle dreißig Sekunden, wenn der Nachladelauf die
  Linienliste ändert; daher das „manchmal". **Der Zeitpunkt in der Meldung war
  die halbe Diagnose** — „gerade wenn sie neu geöffnet ist" ist genau das
  Fenster, in dem die Fahrtläufe eintreffen.
- **Wer die Karte angefasst hat, führt sie.** Ab der ersten eigenen Bewegung
  stellt sie sich nicht mehr selbst ein; zurück gibt der Nutzer sie mit einem
  neuen Bezugspunkt, denn das ist eine neue Lage. In 1.1.14 wurde die
  Berührung über zwei **`simultaneousGesture`** erkannt (Ziehen und Zoomen),
  mit der Begründung, `simultaneousGesture` sehe nur zu. **Beides ist in
  1.1.15 wieder ausgebaut** — siehe unten.
- **Zweimal eine Vermutung als Diagnose ausgegeben — und der Nutzer hat beide
  Male widersprochen.** 1.1.14 nannte die Kamera als Ursache, 1.1.15 die
  Gesten. Die zweite Begründung stützte sich darauf, dass die Beschwerde erst
  nach 1.1.13 kam, also nach dem Einbau des langen Tipps. **Das war schlicht
  falsch** (Ansage des Nutzers 09/2026: „Das Problem ist vorher bereits
  aufgetreten und es tut es jetzt auch wieder."). Eine zeitliche Korrelation,
  die der Nutzer nicht bestätigt hat, ist keine Messung — und wer auf ihr eine
  Fassung baut, baut eine Funktion ab, die jemand ausdrücklich wollte.
  **Die Gesten sind seit 1.1.16 wieder da**, der Nadelknopf mit dem Fadenkreuz
  aus 1.1.15 steht daneben: zwei Wege, wie beim Vollbild.
  Was daneben bestehen bleibt, weil es unabhängig davon richtig ist:
  - **`.automatic` als Kamerastand.** `MapCameraPosition.automatic` heißt
    „rahme, was drinsteht" — und was drinsteht, hängt seit 1.1.13 über
    `sichtbareHalte` am gezeigten Ausschnitt. Das ist eine Rückkopplung: Jede
    Kamerabewegung ändert die Zahl der Halte, die geänderte Zahl rahmt die
    Kamera neu. `.automatic` stand beim Öffnen und nach jedem Wechsel des
    Bezugspunkts — und der `nutzerFuehrt`-Wächter aus 1.1.14 hielt die Karte
    ausgerechnet dann für immer darin fest, wenn der Nutzer früh zoomte.
    Gesetzt wird jetzt ausschließlich ein ausgerechneter `MKMapRect`, und nur
    über `rahmen(_:)`.
  - **Erkannt wird die eigene Bewegung an der Kamera selbst**
    (`eigeneBewegung`): `rahmen(_:)` setzt eine Marke, `onMapCameraChange`
    nimmt sie weg — jede Meldung ohne Marke kam vom Nutzer. Dieselbe Auskunft
    wie die beiden Gesten, ohne eine einzige Geste.
- **Die Karte zeichnete sich JEDE SEKUNDE neu — und rechnete dabei zehnmal
  alles durch** (`neuRechnen`, `Karteninhalt`, ab 1.1.16). Das ist der erste
  Befund in dieser Sache, der am Quelltext nachzuzählen ist statt zu
  plausibeln, und er ist alt genug, um zu passen: Er besteht, seit es Halte
  auf der Karte gibt (1.0.5) und Meldungstexte dazu (1.1.6) — also lange vor
  1.1.13.
  - **Woher die Sekunde kommt:** `AbfahrtstafelView` beobachtet das `Uhrwerk`
    für die Minutenziffern, sein Körper läuft also im Sekundentakt. Er reicht
    an `LiniennetzView` einen frischen Abschluss weiter (`umschalten`), und
    **ein Abschluss ist nicht vergleichbar** — SwiftUI kann nicht sehen, dass
    sich nichts geändert hat, und zeichnet die Karte mit.
  - **Woher der Aufwand kommt:** `sichtbareHalte` und `hinweise` waren
    BERECHNETE EIGENSCHAFTEN. `hinweise` wird an vier Stellen der Fußzeile
    ausgewertet und rechnete je Durchgang dreimal `sichtbareHalte`, dazu
    einmal die Karte selbst: zehn bis dreizehn volle Durchgänge je Zeichnung,
    jeder über bis zu 720 Halte, jeder Halt mit Textvergleich gegen die
    Meldungsliste (`Haltsperrung.passt`, mit Kleinschreibung und
    ausgeschriebenen Abkürzungen). Auf dem Hauptfaden — also genau dort, wo
    auch die Gesten der Karte bedient werden.
  - **Eine berechnete Eigenschaft sieht billig aus.** Genau das ist die Falle:
    `sichtbareHalte` las sich wie ein Feld und war ein Suchlauf. Sie heißt
    deshalb jetzt `berechneHalte()` — ein Name mit Klammern erinnert an jeder
    Aufrufstelle daran, dass dort gerechnet wird. Dieselbe Falle wie bei
    `Liniennetz.gebautAus` und `LiniennetzView.gesperrtJeLinie`, nur eine
    Ebene höher.
  - **Gerechnet wird an EINER Stelle** (`neuRechnen`) und nur auf einen
    Auslöser: neuer Linienstand, andere hervorgehobene Linie, neue
    Betriebsmeldungen, neuer Kartenausschnitt, Legende auf oder zu, neuer
    Bezugspunkt. **Wer etwas hinzufügt, das den Karteninhalt beeinflusst,
    trägt den Auslöser dort ein** — ein alter Stand auf der Karte ist der
    gefährlichere Fehler als ein Durchgang zu viel.
  - **`Liniennetz.stand` ist ein ZÄHLER, nicht `zuege.count`.** Nach einem
    Nachladelauf können dieselben zwölf Linien zurückkommen, bei denen ein
    Halt entfällt: Die Zahl bliebe gleich, der Inhalt nicht.
- **Und weil sich das hier nicht nachmessen lässt, misst es die App**
  (`Dienste/Kartenmesser.swift`, Einstellungen → „Karte prüfen", ab 1.1.16).
  Neuzeichnungen je Sekunde, Dauer eines Aufbaus, Zahl der gezeichneten Halte
  — kopierbar, ohne Deutung, mit der Zeitspanne dabei (eine Rate ohne ihren
  Zeitraum ist keine Messung). Dasselbe Muster wie Schulalarms Stufenprobe:
  **Wo sich eine Ursache nicht erschließen lässt, muss eine Probe
  entscheiden** — und nach zwei falschen Vermutungen ist das keine Zugabe
  mehr, sondern die Arbeit selbst.
  **Der Messfühler hat bewusst KEIN `@Published`**: Die Karte meldet an ihn,
  und wäre er beobachtbar, löste jede Meldung ein Neuzeichnen aus, das
  seinerseits gemeldet würde — ein Messgerät, das seinen eigenen Messwert
  erzeugt. Gelesen wird auf Knopfdruck.
- **Die Zwischenablage aus 1.1.16 reichte nicht** (gemeldet 09/2026). Sie war
  richtig und behandelte die falsche Hälfte: Gerechnet wurde seltener, gezeichnet
  weiterhin jede Sekunde — und der Aufwand steckte im GEZEICHNETEN.
- **Die Linienzüge sind das Gewicht, und das ist jetzt gemessen**
  (`Model/Linienvereinfachung.swift`, ab 1.1.17). **Der Befund kam vom
  Nutzer und war der erste belastbare in dieser Sache:** „Je mehr Linien im
  Spiel sind, desto länger dauert's." Nachgemessen am 18.09.2026 an genau den
  zwölf Linien, die die App am Münchner Hauptbahnhof zeichnet:
  **12.446 Stützpunkte**, davon allein **4.973 auf der Buslinie 68** (195
  Halte) — und jede Linie wird ZWEIMAL gezeichnet (erst alle Konturen, dann
  alle Linien), also rund 25.000 Koordinaten je Aufbau des Karteninhalts.
  - **Gedünnt wird auf den MASSSTAB** (Douglas-Peucker, Toleranz = was EIN
    Bildpunkt gerade bedeutet). Ein weggelassener Stützpunkt läge ohnehin auf
    demselben Pixel wie die Gerade, die ihn ersetzt. Gemessen an denselben
    Linien: 1 m → 3.281 Punkte (26 %), 3 m → 1.894 (15 %), 8 m → 1.055 (8 %),
    20 m → 647 (5 %), 50 m → 402 (3 %). **Beim Öffnen rahmt die Karte das
    ganze Netz** — dort gilt die letzte Zeile, aus 25.000 Koordinaten werden
    rund 800. Wer weit hineinzoomt, bekommt den vollen Verlauf zurück.
  - **Das ist KEINE erfundene Geometrie.** Der gezeichnete Weg bleibt der Weg
    aus den Daten; es fallen nur Punkte weg, die auf ihm liegen. Etwas anderes
    als eine geratene Umleitung oder eine durchgezogene Luftlinie — beides tut
    diese App weiterhin nicht, und die Grenze ist genau hier zu ziehen.
  - **Die Breite der Karte wird GEMESSEN** (`GeometryReader`), nicht
    angenommen: Eine feste Zahl wäre zwischen iPhone und iPad um das
    Zweieinhalbfache daneben. Lässt sich der Maßstab nicht feststellen, wird
    NICHT vereinfacht — eine geratene Toleranz wäre die eine Art Fehler, die
    man der Karte nicht ansieht.
  - **Die Toleranz ist auf Zweierpotenzen gestuft.** Ohne das rechnete jede
    Schiebebewegung alle zwölf Züge neu, weil sich die Breite um ein
    Tausendstel geändert hat.
  - **Douglas-Peucker ohne Rekursion**, mit eigenem Stapel: Fünftausend Punkte
    können tief schachteln, und ein Stapelüberlauf wäre ein Absturz für eine
    Linie, die nur etwas gröber gezeichnet werden sollte.
- **Eine Ansicht, die einen ABSCHLUSS bekommt, zeichnet immer mit**
  (`LiniennetzView: Equatable`, `.equatable()`, ab 1.1.17). `AbfahrtstafelView`
  beobachtet das `Uhrwerk` für die Minutenziffern, sein Körper läuft im
  Sekundentakt — und er reicht `umschalten` weiter. **Ein Abschluss lässt sich
  nicht vergleichen**, also musste SwiftUI von einer Änderung ausgehen und
  baute die Karte samt aller Linienzüge neu auf. Verglichen wird jetzt nur, was
  das Aussehen wirklich bestimmt (`imVollbild`); der Abschluss tut bei jedem
  Durchgang dasselbe. **Das schaltet nichts ab** — was die Ansicht selbst
  beobachtet, löst weiterhin ein Neuzeichnen aus. **Wer eine vierte
  Aufrufstelle anlegt, hängt `.equatable()` mit dran**, sonst zeichnet dort
  wieder die Uhr mit.
- **Ob damit das Zoomproblem erledigt ist, steht noch nicht fest.** Drei
  Erklärungen sind bisher gefallen und zwei davon waren Vermutungen; diese hier
  ist gemessen, aber gemessen ist die DATENMENGE und nicht die Wirkung auf dem
  Gerät. Nicht als erledigt darstellen — der Messfühler nennt seit 1.1.17 auch
  die Stützpunkte roh und gezeichnet.
- **Auf einer Karte darf kein Bedienelement liegen** (ab 1.1.18, Befund des
  Nutzers 09/2026: „wenn ich zoome und Haltestellen in der Nähe sind,
  funktioniert der Zoom nicht. Auch wenn es ein dicht besiedeltes Gebiet mit
  vielen Pins ist, schlägt der Zoom deshalb fehl."). Das ist der erste Befund
  in dieser Sache, der sagt, WANN es fehlschlägt — und er zeigt nicht auf die
  Linien, sondern auf die Punkte. **Nachgezählt am Quelltext:** Bis 1.1.17 war
  jeder der bis zu 260 Halte ein `NavigationLink`, jede Haltestelle aus der
  Liste ebenso und jedes Liniensymbol ein `Button`, und jedes davon trug über
  `trefferflaeche()` einen unsichtbaren Kreis von 32 Punkten. Bei 34 Punkten
  Abstand deckt ein Raster solcher Kreise rund 70 % der Fläche ab; in einer
  Innenstadt landen also beide Finger einer Zoomgeste mit hoher
  Wahrscheinlichkeit auf einem Bedienelement statt auf der Karte. **Merke:
  Eine Geste gehört der Karte; was auf ihr liegt, ist ein BILD.**
  - Die Punkte sind seit 1.1.18 `.allowsHitTesting(false)` — auch der
    Bezugspunkt und die Umstiegspunkte in `VerbindungDetailView`, die gar
    nichts tun: Was keine Aufgabe hat, darf erst recht keinen Finger
    schlucken.
  - Den Tipp nimmt die KARTE an (`LiniennetzView.tippen(_:_:)`) und sucht
    hinterher den nächsten Punkt in **Bildpunkten** (`MapProxy.convert`),
    Griffweite 26. Gerechnet wird also erst, NACHDEM klar ist, dass ein Tipp
    gemeint war — damit kostet die Griffweite keine Kartenfläche mehr und darf
    sogar großzügiger sein als der gezeichnete Punkt. Durchgegangen wird von
    unten nach oben, damit bei gleichem Abstand das gewinnt, was obenauf
    liegt; liegt nichts in Griffweite, zieht der Tipp wie bisher die Karte
    auf.
  - **Dafür braucht die Karte den Navigationsstapel selbst**
    (`LiniennetzView.pfad`, ein `@Binding` an `NavigationPath`). Das Ziel
    bleibt das eine, das in jedem Stapel eingetragen ist
    (`navigationDestination(for: Haltestelle.self)`) — ein eigenes Blatt wäre
    ein zweiter Weg zu derselben Ansicht und liefe irgendwann auseinander.
  - **Der Fahrtlauf (`StreckenKarte`) trägt die alte Bauweise noch.** Das ist
    Absicht: Es wird eine Sache auf einmal geändert, sonst sagt der nächste
    Befund nichts mehr. Hält die Erklärung, gehört sie mitgezogen.
  - **Nicht als erledigt darstellen.** Gemessen ist der AUFBAU (wie viele
    Bedienelemente auf der Karte lagen, jetzt null — der Messfühler nennt die
    Zahl der antippbaren Punkte seit 1.1.18 mit), nicht die Wirkung auf dem
    Gerät. Es ist die vierte Erklärung in dieser Sache; die ersten beiden
    waren Vermutungen, die dritte eine Datenmessung ohne Wirkungsnachweis.
- **Betriebsmeldungen sind eine EIGENE Sache neben der Abfahrtskette**
  (`Betriebsmeldung`, `Meldungsquelle`, `Dienste/Meldungsdienst.swift`, ab
  1.0.4; gemeldet 09/2026: „Ich weiß, dass bei mir vor Ort eine Buslinie
  gerade eine Umleitung fahren muss … Dieser aktuelle Stand ist in der App
  aber leider nicht zu sehen."). **Nachgemessen 18.09.2026: Transitous führt
  überhaupt keine Betriebsmeldungen** — weder an `/stoptimes` noch am
  `/trip`. Es kennt `cancelled` und `tripCancelled`, also Verspätung und
  Ausfall, aber nicht den GRUND und nicht die FOLGEN. Eine Umleitung ist für
  die erste Quelle unsichtbar. Die Verbünde führen sie sehr wohl (EFA:
  `infos[].infoLinks[]` mit Titel, Untertitel und Volltext; VRR Dortmund
  lieferte sechs, VVS Stuttgart hundert).
  **Daraus folgt die Bauweise:** Meldungen werden vom Verbund geholt, AUCH
  WENN die Abfahrten von Transitous kamen. Wer sie an die Abfahrtskette
  hängt, bekommt in ganz Deutschland keine — dort antwortet fast immer die
  erste Quelle. Deshalb ein drittes Protokoll und keine Kette: Antwortet der
  Verbund nicht, gibt es eben keine Meldungen, und die App sagt nichts,
  statt etwas zu behaupten.
- **Welche LINIEN eine Meldung betrifft, steht in den DATEN.** EFA hängt jede
  Meldung an die Abfahrten, für die sie gilt; gesammelt wird also über die
  Linien der Abfahrten, an denen sie hing. Den Titel nach „Linie 453" zu
  durchsuchen wäre die naheliegende Alternative — sie wackelt schon bei
  „Linien 400, 401" und gibt bei „Airport Express // Airport Shuttle" ganz
  auf. Genau diese Zuordnung trägt die Marke an der einzelnen Zeile, und die
  ist der Punkt: Eine Liste von acht Meldungen über der Tafel liest niemand,
  ein Dreieck neben der EIGENEN Linie sieht jeder.
- **Meldungen werden höchstens alle fünf Minuten geholt**, Abfahrten alle
  dreißig Sekunden. Eine Sperrung gilt bis Oktober; sie im Sekundentakt
  nachzuladen wäre eine Abfrage je halbe Minute für eine Auskunft, die sich
  nie ändert. Ein Fehlschlag LEERT die Liste nicht — eine Sperrung, die
  vorhin galt, gilt nach einem Netzaussetzer immer noch.
- **„Keine Meldung" und „keine Quelle" sind NICHT dasselbe.** Wo kein Verbund
  zuständig ist, sagt die App genau das: „Das heißt NICHT, dass alles
  planmäßig fährt — es heißt, dass niemand nachgesehen hat." Dieselbe Regel
  wie beim Wort „Plan" an einer Abfahrt ohne Echtzeit.
- **Eine Meldung sagt SELBST, ob ihre Änderung im Fahrplan steht**
  (`Betriebsmeldung.fahrplanhinweis`, `additionalText` bei EFA, ab 1.1.5;
  gemeldet 09/2026: „Bei der Linie 470 in Dortmund ist zwar die
  Störungsmeldung aufgeführt, die gesperrten Haltestellen sind aber als
  befahrbar aufgeführt."). Nachgemessen am 18.09.2026 an genau dieser Linie:
  Die Meldung des VRR nennt zwei gesperrte Haltestellen
  (Heinrich-Munsbeck-Straße, Hedwigstraße); in den Fahrplandaten entfällt eine
  dritte, ganz andere (Haus Dellwig) — und nur in Richtung Oespel, die
  Gegenrichtung hat gar keinen entfallenden Halt. Transitous und der Spiegel
  antworteten Wort für Wort gleich; es lag also weder an der Kette noch an
  `haltEntfaellt`. **Beides war richtig und wirkte zusammen falsch:** oben
  „Straße gesperrt", unten jeder Halt als angefahren. Die Auflösung stand die
  ganze Zeit in der Meldung — der Herausgeber schreibt dazu „Die beschriebenen
  Änderungen sind in der elektronischen Fahrplanauskunft (EFA) **nicht**
  berücksichtigt", und die App warf diesen Satz weg. Jetzt steht er wörtlich
  in der Meldungsliste, und über der Halteliste wie auf der Netzkarte steht
  das Band „Diese Änderungen stehen NICHT im Fahrplan". **Den Umleitungsweg
  zeigen kann die App weiterhin nicht** — er steht in keiner Quelle; was sie
  kann, ist es sagen.
- **Der Satz wird wörtlich gezeigt UND gedeutet** (`aenderungenImFahrplan`).
  Gedeutet wird an einem einzelnen Wort („nicht"), und das ist sonst genau
  die Art Raten, die dieses Papier verbietet (`linien` kommt ausdrücklich aus
  den Daten und nicht aus dem Titel). Der Unterschied: Dort geht es um eine
  Aufzählung in freier Formulierung, hier um EINEN feststehenden Satz eines
  Herausgebers, in beiden Ausprägungen gemessen — und der Wortlaut steht
  daneben, wer ihn liest, sieht sofort, ob die Deutung stimmt. Gemessen
  18.09.2026: VRR füllt das Feld (in beiden Richtungen), VVS, VRN und MVV
  lassen es leer. Es ist eine Zugabe, keine Zusicherung; `nil` heißt „der
  Verbund sagt nichts dazu" und ist der Regelfall.
- **Welche Haltestellen gesperrt sind, steht im TEXT — und wird daraus
  gelesen** (`Model/Haltsperrung.swift`, ab 1.1.6; Ansage des Nutzers 09/2026
  nach 1.1.5: „In dem Text steht ja, welche Haltestellen gesperrt sind."). Er
  hatte recht, und es ist die einzige Stelle, an der diese Auskunft existiert:
  Bei der Sperrung der Westricher Straße nannte die Meldung SECHS
  Haltestellen, die Fahrplandaten führten genau EINE davon (Haus Dellwig —
  die stand auf dem Kartenbild des Nutzers schon mit rotem Kreuz da, aus dem
  Weg von 1.0.8).
- **Gelesen wird die AUFZÄHLUNG, nicht der Satz — und das ist gemessen.** Am
  18.09.2026 wurden 104 echte Meldungen von zehn EFA-Abfragen (VRR, VVS, VRN,
  VVO, DING, MVV) eingesammelt und beide Schreibweisen ausgewertet:
  - **Überschrift + Liste** („Folgende Haltestellen entfallen:", auch „…der
    Linie 423…", auch „…in Richtung Feuersee:") ergab **29 Namen, jeder
    einzelne ein echter Haltestellenname**. Gebaut.
  - **Der Satz** („Die Haltestellen X und Y … entfallen.") ergab 21 Namen,
    davon mehrere falsch — und zwar auf die gefährlichste Art: In
    „Stadtauswärts fahren die Busse ab der Haltestelle ‚Heinrich-Heine-Allee,
    Steig 7‘ … Die Haltestelle ‚Benrather Straße‘ entfällt" wurde die
    ABFAHRTSHALTESTELLE eingesammelt, anderswo die Starthaltestelle einer
    Umleitungsfahrt. **Eine angefahrene Haltestelle als gesperrt zu markieren
    schickt den Menschen davor zur falschen Haltestelle** — schlimmer als gar
    keine Markierung. Bewusst NICHT gebaut; die Ewald-Görshop-Meldung wird
    deshalb nicht ausgewertet, und das ist kein Versehen.
  Wer die Satzform nachrüstet, misst zuerst wieder gegen echte Meldungen.
- **Der wichtigste Abbruch heißt „Nächste Haltestellen:".** Dahinter stehen
  die ERSATZhaltestellen, also genau die, die angefahren werden. Wer die
  mitliest, dreht die Auskunft um. Abgebrochen wird an jeder Zeile mit
  Doppelpunkt und an einer kurzen Liste von Anfangsworten.
- **Zugeordnet wird über EIN führendes Wort, nicht über das Zeilenende**
  (`Haltsperrung.passt`). Die Meldung schreibt „Haus Dellwig", die Daten
  „Dortmund Haus Dellwig" — der naheliegende Weg wäre eine Endprüfung
  gewesen, dann hätte aber „Dellwig" ebenfalls gepasst und ein zu kurzer Name
  markierte eine fremde Haltestelle. Dazu werden Abkürzungen auf `str`
  ausgeschrieben (VRR schreibt in derselben Meldung „Moltkestr." und
  „Düsseldorfer Str."). 16 von 16 Proben gehen auf, darunter sechs
  Gegenproben, die NICHT treffen dürfen. **Umlaute werden nicht eingeebnet.**
  Trägt ein Verbund einen zweiteiligen Ortsnamen, wird schlicht nicht
  markiert — eine Lücke ist besser als eine falsche Auskunft.
- **Die Richtung wird abgeschnitten und nicht ausgewertet.** Ein Halt, der nur
  in einer Richtung entfällt, wird damit in beiden markiert. Das ist die
  gewollte Richtung des Fehlers — ein Hinweis zu viel schickt jemanden in die
  Meldung, ein fehlender an eine Haltestelle, an der nichts hält. Die
  Oberfläche schreibt hin, dass manche Meldungen nur für eine Richtung gelten.
- **Zwei Herkünfte, zwei Zeichen.** Ein entfallender Halt aus den
  FAHRPLANDATEN bleibt rot durchgestrichen mit Kreuz; ein aus dem TEXT
  gelesener ist orange mit Ausrufezeichen und heißt „laut Meldung gesperrt".
  Sie werden nie vermischt: Der eine ist gemessen, der andere aus Fließtext
  gelesen — wer beides gleich zeichnet, macht aus einer Lesart eine Tatsache.
  Deckt die Datenlage den Halt schon ab, gewinnt Rot. Markiert wird in der
  Halteliste, auf der Streckenkarte und auf der Netzkarte, und unter jeder
  steht, woher die Auskunft kommt.
- **Die Nachschlagetabelle wird EINMAL gebaut** (`LiniennetzView.gesperrtJeLinie`).
  Der erste Entwurf fragte je Halt und baute sie dabei jedes Mal neu — zwölf
  Linien mit je sechzig Halten wären siebenhundert Durchgänge durch die
  Meldungsliste bei jedem Neuzeichnen. Dieselbe Falle wie bei
  `Liniennetz.gebautAus`, eine Ebene tiefer.
- **Einzelne EFA-Felder kommen DOPPELT KODIERT** (`Klartext.geradegerueckt`,
  ab 1.1.5). In derselben VRR-Meldung stand `subtitle` als tadelloses UTF-8
  („Verspätungen") und `additionalText` daneben als „Ã„nderungen" — die
  UTF-8-Bytes ein zweites Mal als UTF-8 geschrieben. Es ist ein Fehler des
  Herausgebers und keiner der Übertragung; `JSONDecoder` liefert dieselben
  Zeichen. Gerichtet wird nur, wenn BEIDES zutrifft: ein verräterisches
  Zeichen ist da, und das Zurückdrehen geht verlustfrei auf. Sonst bleibt der
  Text stehen — ein französischer Ortsname mit Ã ist kein Fehler, und ein
  geratener Fix träfe die Texte, die in Ordnung sind.
- **HTML wird von Hand entpackt** (`Fahrplan/Efa/Klartext.swift`). Die Texte
  der Verbünde kommen mit Markierungen und benannten Zeichen (`&szlig;`,
  `&uuml;`, `&ndash;`, `&nbsp;`) — ohne Rückübersetzung wäre jeder deutsche
  Text unlesbar. `NSAttributedString` könnte es und startet dafür intern
  WebKit, muss auf den Hauptfaden und braucht Zehntelsekunden je Absatz; für
  zwanzig Meldungen beim Laden der Tafel ist das genau die Arbeit, die eine
  scrollende Liste ruckeln lässt. Die Zeichenliste ist bewusst KURZ: Was
  fehlt, bleibt als `&name;` stehen und ist sichtbar falsch statt still
  falsch. **Die Anführungszeichen stehen dort als `\u{201E}` und nicht als
  Zeichen** — sonst schlägt `scripts/swift-quelltext-pruefen.py` an, und zwar
  zu Recht: Ein deutsches Anführungszeichen mitten in einem Swift-Text ist
  die eine Stelle, an der sich Inhalt und verunglücktes Ende nicht
  unterscheiden lassen.
- **`http://noHost` ist KEINE Adresse.** EFA setzt den Platzhalter ein, wenn
  nichts hinterlegt ist; als Verweis angeboten führte er ins Leere.
- **Die Fußzeile nennt die Quellen, die WIRKLICH beigetragen haben**
  (`AppModel.beteiligteQuellen`), nicht die eingebauten. „Transitous, VRR"
  unter einer Tafel, die ganz von Transitous stammt, wäre eine Angabe über
  die App und nicht über die Daten.
- **Der Sichtumschalter steht IM INHALT, nicht in der Werkzeugleiste**
  (`Sichtwahl` in `AbfahrtstafelView`, ab 1.0.5, gemeldet 09/2026: „Ich kann
  die Karte bei der Darstellung auf dem iPhone nirgends finden."). Bis 1.0.4
  war er ein `.pickerStyle(.menu)` in `ToolbarItem(placement: .topBarLeading)`
  — ein Symbol, das niemand aufklappt. **Auf dem iPad fiel das nicht auf**,
  weil die Karte dort von Haus aus neben der Liste steht; der Fehler war damit
  nur auf dem Gerät zu sehen, auf dem er zählt. Jetzt eine Segmentleiste
  „Haltestellen | Zeit | Karte" unter der Ortsleiste. Dieselbe Lehre wie beim
  Gruppenchat in Schulalarm und beim Zurücksetzen in Tafelbild: **Ein Knopf,
  den niemand findet, ist kein Knopf.** Nicht zurück in die Werkzeugleiste.
- **Die Halte der gezeichneten Linien stehen auf der Karte** (`Linienzug.halte`,
  `sichtbareHalte`, ab 1.0.5). Ein Linienzug ohne Punkte ist ein Strich über
  der Karte, an dem sich nicht ablesen lässt, ob er dort hält, wo jemand
  hinwill. Beschriftet wird aber NUR, wenn eine Linie hervorgehoben ist —
  sonst lägen dreihundert Haltestellennamen übereinander. **Über 260 Punkten
  werden GAR KEINE gezeichnet** und die Fußzeile sagt, wie man doch an sie
  kommt (eine Linie antippen): Jeder Punkt ist eine eigene SwiftUI-Ansicht,
  und ein paar willkürlich ausgewählte wären schlechter als keine — man hielte
  die Lücken für Wirklichkeit.
- **Ein Tipp auf einen Halt öffnet seine Abfahrtstafel** (ab 1.1.7, Ansage des
  Nutzers 09/2026: „Wenn ich in der Kartendarstellung bei einer Linie auf eine
  Haltestelle tippe, dann möchte ich Informationen zu dieser angezeigt
  bekommen."). Das Ziel gab es schon: `HaltestelleView`, dieselbe Ansicht wie
  aus der Liste und aus der Merkliste, samt Merken-Stern und eigenem
  Nachladen. Gebaut wurde deshalb KEIN neues Blatt, sondern ein
  `NavigationLink(value: halt.haltestelle)` — der
  `navigationDestination(for: Haltestelle.self)` steht in `AbfahrtstafelView`,
  in deren Stapel die Karte liegt. Ein eigenes Blatt wäre ein zweiter Weg zu
  derselben Ansicht und liefe irgendwann auseinander.
- **Antippbar sind BEIDE Sorten Punkte.** Auf der Netzkarte liegen die Halte
  der gezeichneten Linien (`sichtbareHalte`) UND die Haltestellen um den
  Bezugspunkt (`model.gruppen`) — wer nur die einen verlinkt, baut eine Karte,
  auf der die Hälfte der Punkte tot ist. Dazu die Halte des Fahrtlaufs in
  `StreckenKarte`.
- **Wer einen neuen Verweis auf eine Haltestelle baut, prüft den STAPEL.**
  `navigationDestination(for: Haltestelle.self)` stand in `AbfahrtstafelView`
  und `MerklisteView`, aber NICHT in `VerbindungView` — ein Fahrtlauf, der von
  einer Verbindung aus geöffnet wird, hätte dort einen Verweis gehabt, der
  nichts tut. Ein Verweis, der nichts tut, ist für den Menschen davor ein
  kaputter Knopf; das Ziel ist seit 1.1.7 in allen drei Stapeln eingetragen.
- **Der gezeichnete Punkt bleibt klein, die TREFFERFLÄCHE wird größer**
  (`Views/Trefferflaeche.swift`). 13 bis 17 Punkte sind als Zeichnung richtig
  — eine Buslinie hat sechzig Halte, größere Punkte wären eine Perlenkette
  statt einer Karte — und als Fingerziel zu klein; wer danebentippt,
  verschiebt die Karte und hält den Verweis für kaputt. Gelegt wird deshalb
  ein unsichtbarer Kreis darum, **32 Punkte und nicht die von Apple genannten
  44**: Bei 260 Halten überlappten sich die Flächen sonst so weit, dass
  regelmäßig der Nachbar aufginge. Trifft man doch den falschen, steht sein
  Name in der Überschrift der Tafel — der Irrtum ist sichtbar und nicht still.
- **Ein Weg, den niemand sieht, ist keiner.** Ein Kartenpunkt sieht nicht aus
  wie ein Knopf, deshalb steht der Satz „Ein Tipp auf einen Halt öffnet seine
  Abfahrtstafel" in den Hinweisen unter der Karte — vor den Erklärungen zur
  Zeichenweise, denn er sagt, was man TUN kann, und die anderen nur, was man
  sieht. Dieselbe Lehre wie beim Gruppenchat in Schulalarm und beim
  Sichtumschalter in 1.0.5.
- **Die Liniennummer liegt auf dem Zug**, nicht nur in der Legende
  (`beschriftungen`). Gesetzt an einem Anteil des Verlaufs, der sich mit der
  Stelle der Linie in der Liste verschiebt (0,22 bis 0,78) — zwölf Linien, die
  im Stadtzentrum übereinanderliegen, hätten sonst zwölf Schilder auf
  demselben Fleck.
- **Die Legende lässt sich ausblenden** (`legendeOffen`, ab 1.0.6, gemeldet
  09/2026). Auf einem iPhone deckt sie gut ein Viertel der Karte ab — also
  genau die Fläche, für die jemand die Kartensicht öffnet. Zwei Dinge gehören
  dazu, und beide sind die Lehre aus anderen Apps dieses Repos: **Zugeklappt
  bleibt ein sichtbarer Knopf stehen** (wie das Schloss des Sitzplans in
  Tafelbild — ein Bedienelement darf nicht mit der Beschriftung verschwinden),
  und **die Liniennummern auf der Karte sind KNÖPFE** und heben dieselbe Linie
  hervor wie die Zeile in der Legende. Ohne das wäre die zugeklappte Legende
  eine Sackgasse: Die Haltestellennamen hingen daran, sie wieder aufzuklappen.
  Die Wahl liegt in den Voreinstellungen (`@AppStorage` — in einer VIEW, nie
  in `AppModel`).
- **Unter der Karte steht EINE Hinweiszeile, nicht sechs** (`hinweise`,
  `fusszeileOffen`, ab 1.0.9, gemeldet 09/2026: „Der Text verdeckt einen großen
  Teil der Darstellung."). Bis 1.0.8 standen dort bis zu sechs Absätze
  untereinander und nahmen auf einem iPhone die halbe Karte. Das Missverhältnis
  ist der Punkt: Die Erklärungen sind wichtig, aber EINMAL — die Karte ist das,
  wofür jemand diesen Bildschirm öffnet. **Die Reihenfolge in `hinweise` ist
  die ganze Sache**: Zugeklappt steht nur der erste da, und das muss der sein,
  der etwas über die HEUTIGE Lage sagt (entfallender Halt, fehlende Linie) —
  die Erklärungen zur Zeichenweise gelten immer und stehen zuletzt. Wer einen
  neuen Hinweis anlegt, trägt ihn nach Wichtigkeit ein und nicht ans Ende.
- **Der WUNSCH trägt die Kartenmitte, kein Schalter daneben** (`Kartenwunsch`,
  `.sheet(item:)` in `OrtswahlView`, ab 1.0.9, gemeldet 09/2026: „kommt nach
  wie vor München als erster Vorschlag" — trotz 1.0.7). Bis 1.0.8 standen ein
  `Bool` und eine Koordinate nebeneinander, und das Blatt hing an
  `.sheet(isPresented:)`. **SwiftUI baut den Inhalt eines solchen Blattes aus
  dem Stand des LETZTEN Durchgangs**: Beide Werte in derselben Tat zu setzen
  half nicht — die Koordinate war beim Aufbauen noch `nil` und lief in den
  Rückfall, also nach München. Damit war 1.0.7 zwar richtig gebaut und trotzdem
  wirkungslos. **Dieselbe Regel steht seit Tafelbild 1.0.60 im Papier**
  („Der Wunsch trägt das Ziel, kein Schalter daneben"); hier ist sie ein
  zweites Mal bezahlt worden. Wer ein Blatt mit einem Wert öffnet, nimmt
  `.sheet(item:)`.
- **Der Bezugspunkt der Tafel ist der DRITTE Rückfall der Kartenmitte** (ab
  1.0.9). Zwischen zwei Ortungen ist `standort.stand` kurz nicht `.da`, die
  Tafel zeigt aber längst Abfahrten — ohne ihn fiele die Karte in genau diesem
  Augenblick auf die letzte Rettung zurück.
- **„Alles lila" hatte ZWEI Ursachen, und nur eine war unsere** (gemeldet
  09/2026 aus Berchtesgaden). Nachgemessen am 18.09.2026 an genau diesem Ort:
  Die **S4 ist wirklich violett** — `route_color = 9764ac`, von der
  Bayerischen Regiobahn selbst geführt. Daran wird nichts geändert; eine
  eigene Farbe daneben zu stellen wäre eine Verschlimmbesserung. Die **acht
  Buslinien** (837 bis 848, alle Bus RV Oberbayern) führen dagegen **gar keine
  Farbe** — sie fallen auf das Bus-Violett zurück, und die Abwandlung je Linie
  griff nicht. Wer so einen Befund liest, trennt also zuerst, was aus den
  Daten kommt und was aus dem Rückfall.
- **Der Streuwert stand an den SCHWÄCHSTEN Bits** (`Liniensymbol.streuwert`,
  behoben in 1.1.8). Bis 1.1.7 lief EIN FNV-1a-Durchgang, und die beiden
  Zahlen wurden als zwei Bitfenster daraus geschnitten — die erste aus den
  Bits 8 bis 23. Genau die sind bei FNV-1a die schwächsten: Der letzte Schritt
  ist eine Multiplikation, und deren niedrige Bits hängen nur von den
  niedrigen Bits der Eingabe ab. Namen, die sich bloß im letzten Zeichen
  unterscheiden — also die acht Buslinien einer Gegend —, bekamen damit fast
  denselben Wert. **Gemessen:** Der Farbton aller acht Linien lag in einem
  Fenster von 0,004, obwohl ±0,055 erlaubt sind; 838 und 839 bekamen dieselbe
  Farbe auf den Punkt. Jetzt zwei Durchgänge mit verschiedenem Startwert, je
  mit dem Schlussmischer von splitmix64; der kleinste Farbabstand
  verzehnfacht sich (schlechtester Fall über Berchtesgaden, Dortmund, München
  und einen gemischten Satz: 0,0018 → 0,0178).
- **Die Spanne war zu eng — und die erste Antwort darauf war falsch** (ab
  1.1.9, Ansage des Nutzers 09/2026 nach 1.1.8: „Am Ende des Tages ist immer
  noch alles lila. Selbst wenn man jetzt ein paar leichte Farbnuancen
  unterscheiden kann. Ich möchte es aber deutlicher haben."). In 1.1.8 stand
  hier, ±0,055 im Farbton seien richtig gewählt und nur nie ausgeschöpft
  worden. Das war eine Aussage über HSB-Einheiten, ausgegeben als Aussage über
  das, was ein Mensch sieht. Nachgemessen am 18.09.2026 in CIE Lab, also in
  dem Maß, das für die Wahrnehmung gebaut ist: Der kleinste Abstand zwischen
  zwei der acht Berchtesgadener Linien lag nach 1.1.8 bei **dE 1,6** — die
  Unterscheidungsschwelle liegt bei etwa 2,3. Die „Verzehnfachung" von 1.1.8
  war real und trotzdem unsichtbar. **Wer eine Farbdifferenz beurteilt, misst
  sie in dE und nicht in Farbtonanteilen.**
- **Zwölf Töne in drei Helligkeiten, zugeordnet über die LINIENNUMMER**
  (`Model/Linienfarben.swift`, ab 1.1.9). 36 Plätze, kleinster Abstand
  untereinander dE 15,5. Zugeordnet wird über die Ziffern des Liniennamens,
  NICHT über einen Streuwert: Ein Streuwert verteilt zufällig, und vierzehn
  Linien auf zwölf Farben ergaben in Salzburg nur acht belegte Farben und
  sieben Doppel (Geburtstagsproblem). Benachbarte Buslinien einer Gegend sind
  aber fortlaufend nummeriert — 837, 838, 839 —, und `zahl % 36` gibt genau
  denen garantiert verschiedene Plätze. Gemessen an vier echten Sätzen:
  Berchtesgaden 7/7, Salzburg 14/14, München 10/10, Dortmund 9/10 (448 und
  412 liegen genau 36 auseinander). Eine Linie ganz ohne Ziffern bekommt ihren
  Platz aus dem Streuwert — **nie aus `hashValue`**, den streut Swift je
  Programmlauf zufällig.
- **Die Farbfamilie des Verkehrsmittels ist dafür aufgegeben — beim RÜCKFALL.**
  Das klingt teurer, als es ist: Eine Linie MIT eigener Farbe hielt sich nie
  an die Familie, und genau das stand auf dem Bildschirmfoto des Nutzers — die
  S4 führt `route_color 9764ac` und war damit so violett wie jeder Bus daneben.
  Die Farbe des Schildes hat das Verkehrsmittel also nie verlässlich genannt.
  Wo es wirklich um das Verkehrsmittel geht, steht die Farbe unverändert: in
  der Filterleiste („Busse", „S-Bahnen" — `Verkehrsmittel.rueckfallfarbe`).
  Dazu steht seit 1.1.9 in der Legende der Netzkarte das SYMBOL des
  Verkehrsmittels neben dem Schild, und die Fußzeile sagt ausdrücklich, dass
  eine selbst vergebene Farbe nur unterscheidet.
- **Drei Helligkeiten gehen nur als dunkel / Grundton / hell.** Der erste
  Entwurf hellte in zwei Schritten auf (30 % und 55 %) — und die mittlere
  Stufe trägt WEDER schwarze noch weiße Schrift: gemessen 2,6:1 bis 3,7:1, und
  4,5:1 wären nötig. Gebaut ist jetzt Grundton (weiße Schrift, 4,6:1), mal
  0,60 und 40 % in Richtung Weiß; schlechtester Schriftkontrast über alle 36
  Plätze 4,6:1. **Die beiden Bedingungen ziehen gegeneinander**: Je heller die
  helle Stufe, desto besser trägt schwarze Schrift und desto blasser und
  ähnlicher werden die Töne untereinander (bei 62 % fiel der kleinste Abstand
  von dE 15,5 auf 10,0). Gesucht war nicht das Maximum von einem, sondern das
  beste Paar.
- **Die Schriftfarbe entscheidet ein VERGLEICH, keine Schwelle** (ab 1.1.9).
  Bis 1.1.8 galt `wahrgenommeneHelligkeit > 0,6` → schwarz, sonst weiß. Ein
  mittelheller Ton liegt darunter, bekam weiße Schrift und trug sie nicht.
  Jetzt gewinnt schlicht die Farbe mit dem größeren Kontrastverhältnis.
- **Ein Linienzug bekommt eine KONTUR** (`LiniennetzView.konturfarbe`, ab
  1.1.9). Gemessen 18.09.2026 gegen die Kartenhintergründe: Ein dunkler Ton
  auf der dunklen Karte kommt auf 1,8:1, ein heller auf der hellen Karte auf
  2,0:1 — zu wenig, um einen Strich über die Karte zu verfolgen. **Das galt
  schon vorher und gilt auch für jede Farbe, die ein Verbund selbst führt**;
  es ist also kein Preis der neuen Palette, sondern ein alter blinder Fleck,
  der beim Messen auffiel. Gezeichnet wird deshalb erst die Kontur (drei
  Punkte breiter, Gegenfarbe zur Darstellungsart) und dann die Linie —
  **erst ALLE Konturen, dann ALLE Linien**, sonst deckt die Kontur der einen
  die schon gezeichnete andere zu. Nicht `Color.primary`: Das ist die Farbe
  für Schrift und wäre auf der dunklen Karte ein reines Weiß.
- **Eine Farbe aus den Daten darf doppelt vorkommen.** Gemessen in München:
  Die Buslinien 100, 132, 153 und 154 tragen alle `325868`, die 52, 58, 62 und
  68 alle `d3762b` — das ist die Hausfarbe des Betreibers und keine Panne. Die
  eigene Farbvergabe greift deshalb ausdrücklich NUR beim Rückfall: Wo der
  Verbund eine Farbe führt, gilt seine, auch wenn zwei Linien gleich aussehen.
- **Das Liniensymbol nennt seit 1.1.29 das VERKEHRSMITTEL** (`Liniensymbol.mitMittel`;
  gemeldet 09/2026: „Nur Busse sind ausgewählt" — und in jedem der vier
  Vorschläge stand ein Schild „RE1"). **Der Filter hatte recht.** Nachgemessen
  am 21.09.2026 an derselben Strecke (Duisburg Großenbaum, nachts,
  `transitModes=BUS`): Die Abschnitte kommen als `mode = BUS`, `routeType = 3`
  zurück, `routeLongName = "SEV RE 1"`, Betrieb National Express — ein
  **Schienenersatzverkehr**. Er behält den NAMEN der Bahnlinie und deren Farbe
  (`route_color 9b1b60`). Auf dem Schild stand damit alles, was nach
  Regionalzug aussieht, und nichts, was ihn als Bus ausweist.
  - **Der Name hat das Verkehrsmittel nie genannt, und die Farbe seit 1.1.9
    auch nicht mehr** — dort steht es schon: „eine selbst vergebene Farbe
    unterscheidet nur", und die Legende der Netzkarte bekam deshalb das Symbol
    daneben. Was fehlte, war dieselbe Auskunft überall sonst. **Merke: Wer eine
    Auskunft an EINER Stelle nachrüstet, prüft, wo sie sonst noch fehlt.**
  - **Gezeigt wird das gemessene `mode`, nicht eine Lesart des Namens.** Aus
    „RE1" zu schließen, dass etwas ein Zug ist, wäre genau das Raten, das
    diesen Fehler erzeugt hat. Und ein Textmerkmal für Ersatzverkehr gibt es
    nicht: Derselbe Durchgang gab eine Linie „S1" als Bus zurück, dort aber mit
    **leerem** `routeLongName`. Das `mode` gibt es immer.
  - **Gesetzt ist es, wo Schilder in einer LISTE stehen** (Ergebniszeile der
    Auskunft, Abschnitte einer Verbindung, Abfahrtszeile, Kopf des Fahrtlaufs).
    Bewusst NICHT auf der Netzkarte — dort ist das Schild eine Marke auf einem
    Linienzug, und breitere Marken decken die Fläche zu, für die die Karte
    geöffnet wird (dieselbe Rechnung wie 1.1.18) —, nicht in deren Legende
    (dort steht das Symbol seit 1.1.9 links daneben, es wäre dasselbe zweimal)
    und nicht in der schmalen Leiste der Vergleichskarte (die Kette ist auf
    sechs Schilder gedeckelt, und jedes Schild breiter zu machen nähme genau
    den Platz wieder weg).
  - Dazu ein Satz in der Fußzeile der Auskunft, der den Fall benennt. Eine
    Anzeige, die stimmt, aber missverstanden wird, ist für den Menschen davor
    ein Fehler — dieselbe Regel wie bei „Plan" gegen „pünktlich".
- **Das Symbol sagt WAS, nicht WARUM — und das reichte nicht** (`Ersatzverkehr`,
  `Views/Linienzusatz.swift`, ab 1.1.30; Ansage des Nutzers 09/2026 zu 1.1.29:
  „RE 1 und S1 sind Züge. Definitiv."). **Er hat recht, und 1.1.29 hatte auch
  recht** — es sind zwei verschiedene Sätze: RE1 und S1 SIND Bahnlinien; was
  nachts auf ihnen fährt, ist ein Bus. Nachgemessen am 21.09.2026 auf BEIDEN
  Seiten, und das ist der Teil, der 1.1.29 fehlte:
  - **Duisburg Hbf → Großenbaum**: die S1 als `mode = METRO` in **7 Minuten**
    (mittags), dieselbe Strecke als „S1" mit `mode = BUS` nachts in **20** —
    über „Duisburg Schlenk Bf" und „Duisburg Buchholz Bf", Betrieb
    „Nahreisezug" statt „DB Regio AG NRW", ohne Linienfarbe.
  - **Essen Hbf → Duisburg Hbf** gab es an dem Tag als Bahn GAR NICHT; der
    „RE1" von National Express braucht 41 Minuten und trägt
    `routeLongName = "SEV RE 1"`.
  - Eine „S6" hält als Bus an „Essen Stadtwaldplatz", eine „U76" an
    „Meerbusch Büderich,Landsknecht" — Straßenhaltestellen.
  **Merke: Ein Widerspruch des Nutzers ist nicht automatisch ein Fehler im
  Befund — er kann auch heißen, dass der Befund die falsche Frage beantwortet
  hat.** Hier war die Messung richtig und die ANZEIGE unvollständig: Ein
  Bussymbol auf einem RE1-Schild sagt, was fährt, aber nicht warum, und wer
  weiß, dass der RE1 ein Zug ist, hält das Symbol für einen Fehler der App.
  - **Das Wort stand die ganze Zeit in den Daten** (`routeLongName`), und die
    App warf es weg. **Dieselbe Lehre wie beim `additionalText` in 1.1.5** —
    wo die Quelle ihre eigene Lage erklärt, wird die Erklärung nicht
    weggeworfen. `Linienkennung.langname` trägt sie jetzt mit; gezeigt wird
    sie an EINER Stelle (`Linienzusatz`) und von allen vieren benutzt.
  - **Gedeutet wird ein feststehender Ausdruck, der Wortlaut steht daneben** —
    dieselbe Bauweise wie `Betriebsmeldung.fahrplanhinweis`. **Verglichen wird
    WORTWEISE**: „SEV" steckt auch in „Sevenum" (Grenzort, in dieser App über
    `Grenzfall` längst ein Thema) und in „Sevilla"; eine Teilstringsuche machte
    aus einer Bahn nach Sevenum einen Ersatzverkehr. Dieselbe Lehre wie 1.1.22.
  - **Ein Feld dafür gibt es NICHT.** GTFS kennt den Typ 714 („Rail Replacement
    Bus Service") — gemessen an 194 Busabschnitten über sechs Strecken
    (Düsseldorf, Berlin, Hamburg, Köln, Stuttgart, München, je zwei Zeiten) kam
    er **kein einziges Mal** vor; es gab nur 3 und 700. Und 3 gegen 700 trennt
    nichts: Ein gewöhnlicher Rheinbahn-Stadtbus trägt 3, ein Essener Nachtbus
    700. Auch `alerts` gibt es an `/plan` nicht.
  - **Hingeschrieben hat es genau EINER** (National Express, „SEV RE 1");
    S1, S6, S28 und U76 kamen mit LEEREM Langnamen. Wo der Satz fehlt, sagt die
    App nichts dazu — eine Lücke ist besser als eine erfundene Erklärung, und
    das Verkehrsmittelsymbol bleibt der gemessene Teil der Auskunft.
  - **Ein Ersatzverkehr steht in den MUSTERDATEN** — sonst ließe sich die
    Anzeige nur ansehen, wenn gerade irgendwo eine Strecke gesperrt ist;
    dieselbe Überlegung wie beim entfallenden Halt in Fasangarten.
- **Ersatzverkehr lässt sich HERAUSFILTERN** (`Verbindungsfilter.ohneErsatzverkehr`,
  ab 1.1.31, Ansage des Nutzers 09/2026). Erkannt wird er auf ZWEI Stufen, und
  die werden nie vermischt — dieselbe Bauweise wie bei den entfallenden Halten
  seit 1.1.6.
  - **Stufe 1, die Quelle sagt es selbst — und zwar an ZWEI Stellen.**
    National Express schreibt es in den LANGnamen (`routeLongName = "SEV RE 1"`,
    „SEV RE 5X"), die Albtal-Verkehrs-Gesellschaft in den KURZnamen: Dort heißt
    die Linie schlicht „SEV S7/S71". **Wer nur eines der beiden Felder liest,
    verliert die Hälfte** — 1.1.30 las nur den Langnamen.
  - **Stufe 2, ein BUS trägt den Namen einer Bahnlinie** (RE, RB, S, U, IC,
    ICE, EC, RS, MEX mit Ziffer). Das ist **die eine Stelle, an der diese App
    einen Liniennamen auswertet**, und sie ist gemessen (21.09.2026):
    1434 Busabschnitte an zwölf deutschen Strecken zu vier Tageszeiten, 360
    verschiedene Buslinien; die Buchstabenvorsätze echter Busse waren `M`, `N`,
    `NE`, `SB`, `X` und `BER` — **keiner stößt mit der Liste zusammen**.
    Getroffen wurden 130 Abschnitte, jeder einzelne von einem Bahnbetrieb.
  - **Die 18 gefundenen Linien wurden EINZELN nachgefragt**, auf ihrer eigenen
    Strecke: elf gibt es dort nachweislich als Schiene. Bei den übrigen gab die
    Schienenabfrage **gar nichts** zurück — genau das, wonach eine gesperrte
    Strecke aussieht. **Kein einziger Treffer war eine gewöhnliche Buslinie.**
    Dazu 125 Busabschnitte im Ausland (Amsterdam bis Salzburg): kein
    Fehltreffer. Dänische S-Busse heißen `300S`, die Ziffer steht vorn; `T`
    steht bewusst NICHT in der Liste, weil `T1` in Frankreich eine Straßenbahn
    ist und der Buchstabe ungemessen blieb.
  - **Gesiebt werden BEIDE Stufen.** Von den 130 Abschnitten schrieben nur 39
    es auch hin — ein Filter allein auf das Wort griffe nicht einmal in jedem
    dritten Fall. Der Preis steht in der Fußzeile: Eine Buslinie, die wirklich
    „S5" hieße, fiele mit heraus; in 1559 gemessenen Abschnitten gab es keine,
    ausschließen lässt es sich nicht.
  - **Zwei Hypothesen sind dabei gefallen, und beide stehen hier als
    widerlegt.** Die Form der `routeId` trennt nichts (994 gewöhnliche Busse
    tragen strukturierte Kennungen `de:…`, 310 anonyme; bei den bahnartigen
    42 gegen 88) — sie sah bestechend aus, weil die echte S1
    `de-DELFI_de:nrw:s1:_109` heißt und der Ersatz `de-DELFI_3958503_3`. Und
    `routeType` 3 gegen 700 trennt ebenfalls nichts: Ein Rheinbahn-Stadtbus
    trägt 3, ein Essener Nachtbus 700.
  - **Der Filter kann NICHT in die Anfrage** — anders als Verkehrsmittel und
    Deutschland-Ticket. Der GTFS-Typ **714** („Rail Replacement Bus Service")
    kam in 1559 Abschnitten **kein einziges Mal** vor, `alerts` gibt es an
    `/plan` gar nicht, und einen Parameter dafür kennt MOTIS nicht. Gesiebt
    wird hinterher, und bleibt nichts übrig, sagt die Meldung, dass das eine
    Aussage über den FILTER ist und nicht über den Fahrplan.
  - **Was er nicht findet, steht auch da:** ein Ersatzverkehr unter
    gewöhnlicher Busnummer, und Kürzel, die sich nicht nachprüfen ließen —
    ÖBB „SV190" (Braunau/Inn Bf → Friedburg Bf, 62 min) und DB „EBU" (DB
    Fernverkehr, 115 min). Beide sehen sehr danach aus; **was sich nicht
    nachschlagen lässt, wird nicht geraten.**
  - **Offen und nicht als erledigt darstellen:** Auf der TAFEL gibt es diesen
    Filter nicht. Ein Ersatzverkehr ist dort ein Bus und fällt damit aus dem
    Filter „S-Bahnen" heraus — wer wissen will, ob seine S1 ersetzt wird, sieht
    sie unter „Busse". Markiert ist sie (Symbol und `Linienzusatz`), gefiltert
    nicht.
- **31 Punkte lagen brach, und trotzdem wurde abgeschnitten** (`AbfahrtsZeile`,
  ab 1.1.32; gemeldet 09/2026: „Das ist nicht gut lesbar. Da wird vieles
  abgeschnitten." — in jeder Zeile stand „Dortmund…" und dahinter drei Punkte).
  **Am Bildschirmfoto nachgemessen** (iPhone, 1206 px = 402 pt, 3×), und der
  erste Befund war der überraschende:
  - **Die Titelzeile brach bei 135,3 pt ab — auf den Punkt dort, wo die
    Detailzeile darunter endet** („01 · 07:42 +7 07:49"), während bis zur
    Minutenspalte 166,7 pt zur Verfügung standen. **Eine `VStack` in einer
    `HStack` mit `Spacer` bekommt ihre IDEALBREITE**, und die ist das Maximum
    dessen, was die Kinder für sich verlangen — hier also die schmale Zeile
    darunter. Der `Spacer` nahm den Rest. Abhilfe:
    `.frame(maxWidth: .infinity, alignment: .leading)` an der Spalte, und der
    `Spacer` fällt ersatzlos weg. **Merke: Wenn Text abgeschnitten wird und
    daneben Platz frei ist, ist nicht der Text zu lang — die Spalte ist zu
    schmal.**
  - **Eine Zeile reicht für ein Fahrtziel nicht.** Jetzt zwei; abgeschnitten
    wird erst, wo auch zwei nicht reichen.
  - **Das Liniensymbol ist seit 1.1.29 breiter** (gemessen 70,7 pt statt der
    52 pt Mindestbreite von vorher) — das Verkehrsmittelsymbol kostet knapp
    19 pt. Es bleibt: Es ist die Antwort auf den Befund von 1.1.29. Aber es
    gehört in die Rechnung, wenn wieder einmal etwas nicht passt.
  - **Die Minutenspalte bleibt bei 62 pt.** Gemessen braucht „8 min" nur 38 pt
    — der Wert ist aber für „jetzt" in 24 pt gesetzt, und ohne feste Breite
    wandert die Ziffernspalte, sobald irgendwo „jetzt" auftaucht.
- **Der Ortsname stand ZWEIMAL da** (`Views/Richtungsname.swift`, ab 1.1.32).
  Die Haltestelle hieß „Dortmund Neu-Crengeldanz-Str.", das Ziel „Dortmund …"
  — das zweite „Dortmund" fraß genau den Platz, an dem das Ziel steht.
  **Nachgemessen am 23.09.2026 an 1680 Abfahrten in zwanzig deutschen
  Städten: 33 % aller Ziele beginnen mit demselben Wort wie ihre
  Haltestelle.** Das ist eine Eigenart der Verbünde und verteilt sich
  entsprechend: Essen 86 %, Frankfurt 84 %, Dortmund 76 %, Bochum 74 %,
  Wuppertal 69 %, Hannover 67 %, Köln 66 %, Duisburg 60 %, Augsburg 42 %,
  Berlin 13 %, Kiel 9 %, Dresden 6 %, Hamburg 3 %, Leipzig/Bremen/Mainz 1 % —
  und **München, Stuttgart, Nürnberg, Düsseldorf 0 %**. Wo die
  Haltestellennamen den Ort gar nicht tragen, ändert die Regel also nichts.
  - **Gestrichen wird nur das ERSTE Wort und nur bei Wort-für-Wort-Gleichheit**
    (Groß/Klein egal, **Umlaute nicht eingeebnet**). An den Gegenproben
    derselben Messung geprüft: „Dortmund Hbf → **München Hbf**" bleibt stehen —
    dort ist der Ort die ganze Auskunft —, ebenso „→ Oberhausen Hbf",
    „→ Enschede", „→ Bochum-Langendreer" (ein Bindestrichname ist EIN Wort)
    und „→ DO-Walbertstraße/Schulmuseum" (eine Abkürzung ist nicht der
    Ortsname; sie zu erraten wäre genau das, was diese App nicht tut). Ein
    Ziel, das NUR aus dem Ort besteht, bleibt ebenfalls stehen.
  - **Gekürzt wird in der ANSICHT, nicht in den Daten.** `Abfahrt.richtung`
    trägt weiter den vollen Namen; er steht im Fahrtlauf über der Karte und in
    der Überschrift der Haltestelle. Gekürzt wird nur die Zeile, in der der
    Ort ohnehin direkt daneben steht.
  - **Die Regel lässt sich ansehen** — in der Vorschau von `Richtungsname`, an
    den gemessenen Paaren samt Gegenproben. NICHT in den Musterdaten: Die
    Beispieltafel spielt in München, und dort gibt es den Fall nachweislich
    nicht (0 %).

### Verbindungsauskunft (ab 1.1.0)

- **Zweiter Reiter, nicht Untermenü der Tafel** (Ansage des Nutzers, 09/2026:
  „Ich möchte die App zu einem echten Verbindungsplaner ausbauen."). Das sind
  die zwei Fragen, mit denen man eine ÖPNV-App öffnet — „was fährt hier weg"
  und „wie komme ich dorthin". Eine Auskunft im Untermenü einer Tafel fände
  niemand; eine Tafel, die plötzlich eine Reise plant, wäre zwei Dinge auf
  einmal.
- **`/plan` ist die Auskunft, und die Orte reisen als KOORDINATEN.** Mit einer
  Haltestellenkennung antwortet sie mit 404 (nachgemessen 19.09.2026). Die
  Vorschlagsliste liefert ohnehin zu jedem Treffer Breite und Länge.
- **Eine leere Ergebnisliste ist kein Fehler, sondern eine Auskunft.** `/plan`
  antwortet mit HTTP 200 und null Verbindungen, wenn nichts fährt (gemessen mit
  Dortmund → New York). Dafür gibt es `Fahrplanfehler.keineVerbindung` als
  eigenen Fall, und `zeitHilft` trägt bis zum Knopf durch: „Noch einmal
  versuchen" hilft nicht, wenn nachts nichts fährt — eine andere Zeit schon.
  Dieselbe Bauweise wie `keineHaltestelleInDerNaehe`.
- **Die Vorschlagsliste braucht ZWEI Abfragen** (`TransitousDienst.orteSuchen`).
  `/geocode` kennt `placeBias`, und der wirkt kräftig — mit ihm gibt „kle" bei
  Dortmund lauter Dortmunder Treffer, ohne ihn Zürich, Paris und Cleveland.
  Zwei Fallen, und jede für sich macht die Liste unbrauchbar:
  **`type=STOP` schaltet den Ortsbezug AUS** (mit beiden zusammen kamen für
  „kle" wieder Paris und Tschechien — gefragt wird deshalb ohne `type`, und die
  Haltestellen werden in der App herausgesucht), und **mit Ortsbezug ist die
  Ferne unerreichbar** („Köln Hbf" gab bei Dortmund den Dortmunder
  Hauptbahnhof, „Hamburg Hbf" ebenso). Eine Auskunft, die Köln nicht findet,
  ist keine. Also beides nebenläufig und zusammengeführt: das Nahe zuerst, das
  Ferne dahinter. **Wer hier auf eine Abfrage zurückbaut, bricht eine der
  beiden Hälften.**
- **Bis 1.0.10 war die Haltestellensuche NIE örtlich.** Sie schickte `type=STOP`
  UND `place` — also genau die Kombination, die den Ortsbezug abschaltet — und
  darüber stand ein Kommentar, der das Gegenteil behauptete. Ein Kommentar ist
  keine Messung.
- **Unter drei Zeichen antwortet die Quelle mit einer LEEREN Liste**, nicht mit
  einem Fehler („k" und „kl" null Treffer, „kle" zehn). Die Zahl steht deshalb
  am Protokoll (`Fahrplandienst.kuerzesteSuche`) und nicht in der Ansicht: Wie
  kurz eine Eingabe sein darf, weiß nur die Quelle. Die Oberfläche schreibt
  hin, wie viele Zeichen noch fehlen — eine leere Liste sähe aus wie „nichts
  gefunden".
- **Der Bezugspunkt der Vorschläge ist erst der gewählte Start, dann der eigene
  Standort** (`bezugFuerVorschlaege`). Wer als Start „Dortmund Hbf" eingetippt
  hat, sucht sein Ziel in Dortmund und nicht dort, wo das Telefon gerade liegt.
- **Die Verbindungsauskunft hat seit 1.1.1 eine ZWEITE REIHE**
  (`Verbindungsquelle`, `EfaVerbindungen.swift`, `SchweizVerbindungen.swift`).
  In 1.0.11 stand hier, die Verbünde gäben eine Abfahrtstafel heraus und sonst
  nichts. **Das war falsch**, nachgemessen am 19.09.2026: `XSLT_TRIP_REQUEST2`
  antwortete an ALLEN ACHT Stellen aus `EfaDienst.alle` mit vollständigen
  Verbindungen — Fußwege, Umstiege, Zwischenhalte (`stopSequence`),
  Streckengeometrie (`coords`) und Echtzeit (`isRealtimeControlled`); die
  Schweizer `/v1/connections` ebenso, ohne Geometrie. Der Satz beschrieb also,
  was DIESE App gebaut hatte, und gab sich als Auskunft über die Schnittstelle
  aus. Jetzt ist der Rückfall gebaut.
- **`Verbindungsquelle` ist das DRITTE Protokoll — aus demselben Grund wie das
  zweite.** `Abfahrtsquelle` gibt es, weil EFA keine Streckengeometrie zu einer
  einzelnen Fahrt kennt; `Verbindungsquelle` gibt es, weil dieselben Stellen
  eine Reiseauskunft können, aber weder die Ortssuche für die Vorschlagsliste
  noch einen Fahrtlauf. Sie als `Fahrplandienst` auszugeben hieße, sechs
  Methoden zu versprechen und vier mit „geht nicht" zu beantworten.
- **Zuständig ist eine Quelle nur, wenn BEIDE Punkte in ihrem Gebiet liegen.**
  Das ist der Unterschied zur Tafel: Eine Tafel gilt für einen Punkt, eine
  Verbindung für zwei. Dortmund → Köln kann nur Transitous, und eine Anfrage,
  die garantiert nichts bringt, ist in einer Kette nur Wartezeit. Die
  Gebietsprüfung steht deshalb an EINER Stelle je Quelle
  (`EfaStelle.enthaelt`, `SchweizDienst.imGebiet`) und wird von Tafel und
  Auskunft gemeinsam benutzt.
- **„Nichts gefunden" und „nicht geantwortet" werden in der Kette GETRENNT
  gezählt** (`Kettendienst.Versuch`). Antwortet eine Quelle sauber mit
  `.keineVerbindung`, wird die nächste trotzdem gefragt — am Ende aber genau
  das gemeldet und nicht „keine Quelle antwortet". Die beiden verlangen
  verschiedene Knöpfe: gegen „es fährt nichts" hilft eine andere Zeit, gegen
  „niemand hat geantwortet" ein zweiter Versuch. Derselbe Unterschied wie
  zwischen „Plan" und „pünktlich".
- **Die Verbindungsauskunft hat KEINEN Zwischenspeicher**, die Tafel schon.
  Eine Abfahrtstafel von vorhin ist mit Altersangabe noch etwas wert; eine
  Verbindungssuche gilt für zwei Punkte und eine Uhrzeit, und die sind beim
  nächsten Mal andere. Ein Treffer von gestern wäre kein alter Stand, sondern
  die Antwort auf eine andere Frage.
- **Die Fußzeile nennt die Quelle, die WIRKLICH geantwortet hat**
  (`Verbindung.quelle`, `Verbindungsmodell.beteiligteQuellen`). Bis 1.1.0 stand
  dort fest `dienst.quellenname`, also „Transitous" — auch unter einer
  Auskunft, die vom VRR kam. Dieselbe Regel wie bei `AppModel.beteiligteQuellen`
  an der Tafel.
- **Eine Fahrt OHNE Streckenführung wird GESTRICHELT gezeichnet**
  (`VerbindungsKarte.strichelt`, ab 1.1.1). Der Schweizer Dienst liefert gar
  keine Geometrie; bis 1.1.0 lag daraufhin eine durchgezogene Gerade quer über
  der Karte und sah aus wie ein Fahrweg. Verbunden werden jetzt die HALTE (nicht
  nur Anfang und Ende — die Lage jedes Haltes ist ja bekannt), gestrichelt, und
  unter der Karte steht, was das heißt. Dieselbe Regel wie bei der
  gestrichelten Luftlinie im Fahrtlauf.
- **In der EFA-REISEAUSKUNFT steht in `realtimeStatus` ein WORT, im
  Abfahrtsmonitor eine ZIFFER.** Gemessen 19.09.2026 an allen acht Stellen:
  durchweg `MONITORED`. Die Ziffer `5` („entfällt") des Monitors kommt hier
  nie vor — wer die Prüfung von dort herüberkopiert, prüft auf etwas, das es
  in dieser Antwort nicht gibt.
- **EFA-Produktklasse 13 ist der REGIONALZUG** (gefunden 19.09.2026 bei VRR,
  VVS und VVO: „R-Bahn", „Regionalzug"). Sie fehlte in `verkehrsmittel`, und
  ohne sie fiel jeder RE und jede RB in den Vorgabefall und stand grau als
  „Sonstiges" da — während dieselbe Fahrt über Transitous ein Regionalzug war.
  Der Fehler betraf auch die Tafel, nicht nur die neue Auskunft.
- **Die EFA-Reiseauskunft liegt neben der Tafel, unter demselben Pfad**
  (`XSLT_TRIP_REQUEST2` statt `XML_DM_REQUEST`) — abgeleitet aus
  `EfaStelle.adresse` und nicht als zweites Feld gepflegt. Datum und Uhrzeit
  reisen in der ÖRTLICHEN Zeit (`itdDate=20260919`, `itdTime=1300`), und
  **die Länge steht in der Anfrage zuerst**, wie bei der Tafel.
- **Beim Schweizer Dienst steht bei `from`/`to` die BREITE zuerst**, bei der
  Stationssuche dagegen ist `x` die Breite und `y` die Länge. Zwei
  Schreibweisen in einer Schnittstelle; wer sie verwechselt, fragt im Meer und
  bekommt eine leere Liste statt einer Fehlermeldung. Und `journey == nil`
  heißt Fußweg — das `walk`-Feld taugt dafür nicht, denn es trägt an manchen
  Fußwegen `duration: null`.
- **Der Reiseplaner der DEUTSCHEN BAHN ist kein Weg** (gemessen 18.09.2026,
  Frage des Nutzers). Vier Zugänge, vier Ergebnisse:
  - `www.bahn.de/web/api/reiseloesung/orte` und dasselbe unter `int.bahn.de`:
    **HTTP 403 mit `{"status":"ERROR","code":"OPS_BLOCKED"}`** — mit
    Browser-Kopfzeilen, mit Referer, gleich geblieben. Die Startseite derselben
    Adresse antwortet mit 200, es ist also DB, das die Schnittstelle abweist,
    und kein Netzproblem. Diese Schnittstelle ist nicht veröffentlicht; sie
    bedient die eigene Webseite und darf das.
  - **DB API Marketplace** (`apis.deutschebahn.com`): antwortet, verlangt aber
    Schlüssel und Konto (HTTP 401). Ein Schlüssel in einer App ist keiner.
  - `*.transport.rest` (HAFAS): **weiterhin 503**, bei v5 und v6, für DB, VBB
    und BVG — durchgehend seit dem Bau der App.
  - `app.vendo.noncd.db.de` und `reiseauskunft.bahn.de`: aus DIESER
    Bauumgebung nicht erreichbar (kein DNS-Eintrag, 502 am Proxy). **Nicht
    gemessen heißt nicht „geht nicht"** — es heißt, dass hier niemand
    nachsehen konnte, und ungemessen gehört keine Quelle in die Kette.
- **Was es an Alternativen zu Transitous gibt — gemessen 19.09.2026** (Frage
  des Nutzers): 
  - **EFA-Reiseplanung** bei den acht Stellen aus `EfaDienst.alle` — **seit
    1.1.1 gebaut**. Grenze: Sie gilt nur IM Verbundgebiet, deckt also keine
    Fahrt von Dortmund nach Köln ab.
  - **`transport.opendata.ch/v1/connections`** für die Schweiz — **seit 1.1.1
    gebaut**; ohne Streckengeometrie.
  - **`*.transport.rest` (HAFAS der Bahn)** wäre die einzige bundesweite
    Alternative und antwortete auch am 19.09.2026 mit **503** — bei `v5` und
    `v6`, für DB, VBB und BVG. Seit dem Bau der App durchgehend nicht
    erreichbar; als Rückfall taugt sie erst, wenn sie wieder antwortet.
  - **MOTIS ist quelloffen**, Transitous ist nur EINE öffentliche Instanz.
    Eine zweite Adresse hinter demselben `TransitousDienst` wäre der billigste
    Rückfall überhaupt — es gibt derzeit aber keine gemessene zweite Instanz
    mit DACH-Daten; ungemessen gehört keine in die Kette.
- **Die Ergebnisliste lädt sich NICHT von selbst nach**, anders als die Tafel.
  Eine Liste, die sich unter den Fingern neu sortiert, während jemand sie
  liest, ist keine Hilfe. Aufgefrischt wird durch Ziehen, und die Fußzeile
  nennt die Uhrzeit der Suche.
- **Die Linienschilder SIND die Ergebniszeile.** Wer zwischen fünf Vorschlägen
  wählt, entscheidet nach „S1 oder zweimal umsteigen" und nicht nach Minuten.
  Die Fußwege stehen als Gehsymbol dazwischen — ohne sie sähe ein Vorschlag mit
  zwanzig Minuten Fußweg aus wie einer, bei dem man am Bahnsteig gegenüber
  umsteigt.
- **Eine Verbindung mit ausfallendem Abschnitt wird GEZEIGT**, nicht
  weggelassen — mit rotem Band. Wer sie im Kopf hat, sucht sie sonst und hält
  die App für unvollständig. Dieselbe Regel wie beim entfallenden Halt.
- **Zwischenhalte stehen zugeklappt da.** Bei einer Fahrt über zwanzig
  Stationen wären sie der ganze Bildschirm; gesucht wird hier zuerst, wo man
  ein-, um- und aussteigt.
- **Fußwege sind gerechnet, nicht gemessen**, und das steht unter der Liste:
  Wie lange jemand wirklich braucht, hängt vom Gehtempo ab und davon, wo der
  Zugang zum Bahnsteig liegt. Ein Umstieg mit drei Minuten auf dem Papier kann
  in einem großen Bahnhof knapp werden.
- **`Verbindung` vergleicht sich über die KENNUNG.** Der erzeugte
  `Hashable`-Leser käme nicht durch — in den Abschnitten stecken
  `CLLocationCoordinate2D`, und die sind nicht `Hashable`. Gebraucht wird
  beides nur für `navigationDestination(for:)`.
- **Eine Kette für beide Bildschirme** (`AbfahrtstafelApp.dienst`). Zwei Ketten
  nebeneinander hieße zwei Zwischenspeicher und zwei Meinungen darüber, welcher
  Verbund gerade antwortet.
- **Mehrere Vorschläge auf EINER Karte** (`Views/VergleichsKarte.swift`, ab
  1.1.20, Ansage des Nutzers 09/2026: „Ich suche nach einer Möglichkeit, diese
  gemeinsam auf einer Karte anzeigen zu lassen, sodass man die Verläufe
  vergleichen kann … Auf jeden Fall möchte ich in einem Menü die einzelnen
  Verbindungen auf der Karte ein- und ausblenden können."). Die Liste sagt, wie
  lange etwas dauert und wie oft man umsteigt; sie sagt nicht, WO es langgeht.
  - **Drei Dinge sind auseinanderzuhalten, und jedes bekommt ein EIGENES
    Mittel**: das VERKEHRSMITTEL die Linienfarbe (wie überall in dieser App),
    die VERBINDUNG eine Nummer am Zug samt derselben Nummer in der Liste, und
    was gerade gemeint ist das Hervorheben. **Die Farbe kann die Verbindung
    nicht tragen** — sie ist schon für das Verkehrsmittel vergeben, und genau
    das wollte der Nutzer sehen („ob die Verbindung eine reine ICE-Verbindung
    ist oder fünfmal umsteigen bei Regionalbahnen bedeutet"). Dazu kommt: Zwei
    Vorschläge über dieselbe Strecke liegen ohnehin übereinander, eine zweite
    Farbe daneben verspräche eine Trennung, die es nicht gibt.
  - **Das Menü ist die Liste oben rechts** — aufklappbar wie die Legende der
    Netzkarte, und aus demselben Grund: Auf einem iPhone deckt sie sonst die
    Fläche zu, für die man sie öffnet. **Zwei Aufgaben, zwei Knöpfe**: Das
    Häkchen blendet ein und aus, ein Tipp auf die Zeile hebt hervor. Ein Tipp,
    der mal dies und mal jenes tut, ist für den Menschen davor kaputt.
  - **Die Schilderkette steht in der LISTE, nicht auf der Karte.** Auf der
    Karte wäre dafür kein Platz; gedeckelt auf sechs Schilder, der Rest wird
    gezählt. Kleiner gezeichnet wären sie genau dort unlesbar, wo sie
    gebraucht werden — dieselbe Rechnung wie beim Dauerbalken in 1.1.19.
  - **Umstiegspunkte nur bei der hervorgehobenen Verbindung.** Alle auf einmal
    wären dreißig Punkte, und die Frage „wo steige ich um" hat immer eine
    bestimmte Verbindung im Sinn.
  - **Gerahmt wird, was SICHTBAR ist**, und neu gerahmt beim Ein- und
    Ausblenden. Das widerspricht der Regel der Netzkarte nur scheinbar: Dort
    stellte sich die Karte über den Nutzer hinweg ein, weil eine Antwort aus
    dem Netz eintraf; hier ist der Auslöser sein eigener Tipp.
  - **Auf der Karte liegt kein Bedienelement** (Lehre aus 1.1.18) — alle
    Punkte `.allowsHitTesting(false)`.
  - **`linienzug` und `gestrichelt` sind ans MODELL gewandert**
    (`Verbindungsabschnitt`). Es gibt jetzt zwei Karten, die Verbindungen
    zeichnen; zwei Fassungen zeichneten irgendwann verschiedene Wege für
    dieselbe Fahrt.
- **Der Deutschland-Ticket-Filter gehört in die ANFRAGE, nicht in die Liste**
  (ab 1.1.20, Ansage des Nutzers 09/2026: „Es soll möglich sein, nur
  Verbindungen anzeigen zu lassen, die mit dem Deutschland-Ticket befahrbar
  sind."). **Gemessen 19.09.2026, Dortmund → München:** Ohne Einschränkung
  kamen fünf Vorschläge zurück, und in ALLEN fünf steckte ein ICE oder IC. Wer
  erst hinterher aussiebt, bekommt eine leere Liste und schließt daraus, es
  gebe keine Nahverkehrsverbindung — mit `transitModes` liefert dieselbe
  Strecke sechs Vorschläge aus lauter Regionalzügen (fünf bis sieben Umstiege,
  gut zehn Stunden statt knapp sechs).
  - **`transitModes` wirkt an `/plan` — an `/stoptimes` heißt derselbe Filter
    `mode`.** Gemessen am selben Tag: `mode=` und `modes=` werden von `/plan`
    mit HTTP 200 angenommen und **stillschweigend ignoriert** (die Antwort war
    Byte für Byte die ungefilterte, 457 412 B). Umgekehrt wirkt an
    `/stoptimes` nur `mode`. **Der Parametername ist je Endpunkt ein anderer,
    und ein falscher fällt nicht auf** — geprüft wird am INHALT der Antwort,
    nie am Status. Ein falscher WERT dagegen meldet sich: HTTP 400 samt
    Aufzählung aller gültigen (`ModeEnum`).
  - **`RAIL` steht bewusst NICHT dabei.** Es ist eine Obergruppe und holt
    Fern- und Hochgeschwindigkeitszüge zurück — nachgemessen an Dortmund →
    Köln, Hamburg → Berlin und München → Zürich: mit `RAIL` standen in jeder
    wieder ICE und IC in der Liste, ohne `RAIL` keine, bei gleicher Zahl an
    Vorschlägen. Dieselbe Falle wie an der Tafel, nur an der anderen
    Schnittstelle.
  - **Die Regel steht an EINER Stelle** (`Verkehrsmittel.imDeutschlandTicket`)
    und wird an zwei Enden gebraucht: für die Modi der Anfrage und für die
    Prüfung jeder Antwort. **Im Zweifel NICHT abgedeckt** — `sonstiges` und
    `faehre` fallen heraus. Die beiden Fehler sind nicht gleich schwer: Eine
    Verbindung zu viel wegzulassen kostet eine Auskunft, eine zu viel zu
    zeigen ein erhöhtes Beförderungsentgelt. (Manche Fähren SIND Nahverkehr —
    die HADAG gehört zum HVV —, aber welche, steht in keinem Feld.)
  - **`NIGHT_RAIL` lief bis 1.1.19 als Regionalzug mit** und ist jetzt
    Fernzug. Falsch war das schon auf dem Schild; mit dem Filter wäre es die
    teure Sorte falsch gewesen.
  - **Fragen kann nur Transitous.** Die Verbünde und der Schweizer Dienst
    kennen keinen gemessenen Parameter dafür, und eine geratene Einschränkung
    gehört in keine Anfrage — ihre Antworten siebt `Kettendienst.gesiebt`.
    Damit gilt die Zusage „in dieser Liste steht kein Fernverkehr" für JEDE
    Quelle. Bleibt nach dem Sieben nichts übrig, wird die nächste Quelle
    gefragt: Eine Quelle, die hier nur Fernverkehr kennt, ist für diese Frage
    dasselbe wie eine, die nichts gefunden hat.
  - **Was der Filter NICHT kann, steht unter der Liste.** Er kennt das
    VERKEHRSMITTEL, nicht das LAND: München → Zürich kommt mit
    Nahverkehrsmodi als vollständige Regionalzugverbindung zurück und ist ab
    der Grenze nicht im Deutschland-Ticket. Ausnahmen einzelner Linien stehen
    ebenfalls in keiner Quelle. Dieselbe Ehrlichkeit wie beim Wort „Plan".
  - **Nicht in den Voreinstellungen.** Wer ein Deutschland-Ticket hat, hat es
    dauerhaft — aber eine App, die beim nächsten Öffnen still die schnellen
    Verbindungen weglässt, sieht aus wie eine App, die sie nicht findet. Der
    Schalter steht sichtbar in der Leiste, und steht er an, nennt ihn auch die
    Meldung „nichts gefunden": Sonst liest sich die wie eine Aussage über den
    Fahrplan.
- **Nach VERKEHRSMITTELN filtern — und was dabei nicht geht** (`Verbindungsfilter`,
  ab 1.1.27, Ansage des Nutzers 09/2026: „Beim Verbindungsplaner möchte ich
  Verkehrsmittel filtern können: Bus, Tram, U, S, RE, RB, usw. Ich möchte z. B.
  einstellen können, dass eine Verbindung nur per Bus geschehen soll.").
  - **Der Filter wirkt je Modus und genau — gemessen 20.09.2026.** `BUS` gab in
    München nur Buslinien zurück, `SUBWAY` nur U-Bahnen, `TRAM` nur Trams,
    `BUS,TRAM` beides. München Hbf → Freising ohne Filter S-Bahn und
    Regionalzug, mit `BUS` eine vollständige Busverbindung über die Linie 635.
    **Die wäre durch nachträgliches Aussieben nie erschienen** — dieselbe
    Lehre wie beim Deutschland-Ticket in 1.1.20, und derselbe Grund, warum der
    Filter in die ANFRAGE gehört.
  - **RE und RB lassen sich NICHT trennen, und das steht in der App.**
    Nachgemessen an acht Strecken: Beide kommen als `mode = REGIONAL_RAIL` mit
    `routeType = 106` zurück, und MEX und DRF ebenso.
    `transitModes=REGIONAL_FAST_RAIL` und `REGIONAL_RAIL` gaben an Dortmund →
    Hamm Antworten von **gleicher Bytezahl** (107 340 B), und München →
    Nürnberg lieferte unter beiden auch RB16. Es gibt in diesen Daten kein
    Feld, an dem die Unterscheidung hinge. Der Unterschied existiert nur im
    LINIENNAMEN — und ihn dort auszulesen wäre nicht bloß Raten, sondern
    schädlich: Der Dienst sucht die schnellste Regionalverbindung, und wer
    davon die RB wegsiebt, bekommt eine leere Liste und schließt daraus, es
    führe keine. **Nicht nachrüsten, ohne zuerst an echten Antworten zu
    messen**, ob eine Quelle die Unterscheidung überhaupt herausgibt.
  - **`nil` und „alle acht" sind nicht dasselbe.** Ohne Einschränkung geht gar
    kein `transitModes` mit; wer stattdessen die volle Liste schickte, siebte
    still alle Fahrten aus, deren Art die App nicht kennt (`sonstiges`). Aus
    demselben Grund steht `sonstiges` nicht in `Verbindungsfilter.waehlbare` —
    „nur Sonstiges" ist kein Wunsch, den jemand hat.
  - **Die Abbildung für die ANFRAGE ist NICHT die Umkehrung der fürs Lesen.**
    In `verkehrsmittel(_:)` steht `RAIL` beim Regionalzug, weil eine Antwort so
    zurückkommen kann; in `motisModi` darf es nicht stehen, denn `RAIL` ist eine
    Obergruppe und holt ICE und IC zurück (gemessen 19.09.2026). Wer die beiden
    Listen zusammenzieht, macht aus „nur Regionalzug" eine Anfrage mit
    Fernverkehr.
  - **Ein Wert statt zweier Schalter.** Bis 1.1.26 reiste ein nacktes
    `nurNahverkehr: Bool` durch alle drei Protokolle; ein zweites Feld daneben
    hätte an sechs Stellen einzeln beachtet werden müssen. Die beiden
    Einschränkungen UNDen sich (`geltendeMittel`), und ein Widerspruch („nur
    Fernzug" plus Deutschland-Ticket) wird als SATZ beantwortet, bevor
    irgendjemand gefragt wird — eine Anfrage ohne ein einziges erlaubtes
    Verkehrsmittel brächte eine leere Liste, die wie eine Aussage über den
    Fahrplan aussähe.
  - **Fragen kann weiterhin nur Transitous**; die Verbünde und der Schweizer
    Dienst kennen keinen gemessenen Parameter dafür, ihre Antworten siebt
    `Kettendienst.gesiebt`. Damit gilt die Zusage für JEDE Quelle.
  - **Die Kapsel wird an EINER Stelle gezeichnet** (`Views/Mittelkapsel.swift`),
    von Tafel und Auskunft gemeinsam. Es sind zwei verschiedene Fragen mit
    derselben Bedienung — und genau so soll es sein; zwei Fassungen desselben
    Aussehens liefen auseinander. **Der Unterschied gehört trotzdem
    dazugesagt:** Auf der Tafel filtert die Leiste, was schon geladen ist, in
    der Auskunft löst sie eine neue Suche aus. Und sie bietet dort ALLE acht an
    und nicht nur die vorkommenden — vor der Suche gibt es keine Antwort, aus
    der sich ablesen ließe, was hier fährt.
- **Wie weit höchstens zu Fuß** (`Verbindungsfilter.hoechsterFussweg`, ab
  1.1.28, Ansage des Nutzers 09/2026: „Vielleicht ist es manchmal nötig, eine
  Strecke zu Fuß zu gehen, damit eine Verbindung zustandekommt. Ich möchte die
  maximale Länge dieser Strecke festlegen können.").
  - **Zwei Parameter wirken, fünf tun nichts — gemessen 21.09.2026 am INHALT
    der Antwort.** An Starnberg (Ortsrand) → München Hbf, einer Strecke mit
    Zugangswegen zwischen 334 und 796 m: `maxPreTransitTime` begrenzt den
    ERSTEN Weg (300 s ließ nur noch 334 m zu, 120 s gar keine Verbindung
    mehr), `maxPostTransitTime` den LETZTEN (120 s → jede Verbindung endete
    mit 136 m). **`maxWalkDistance`, `maxTransferTime`, `walkReluctance`,
    `maxMatchingDistance` und `maxTravelTime` lieferten alle fünf eine
    Antwort, die Byte für Byte der ungefilterten glich — mit HTTP 200.** Ein
    unbekannter Parametername fällt an dieser Schnittstelle nicht auf;
    dieselbe Falle wie bei `mode`/`transitModes`, und schon das dritte Mal.
  - **Von Haus aus gilt 900 Sekunden.** `maxPreTransitTime=900` war Byte für
    Byte die ungefilterte Antwort, 1800 gab andere Wege (1561 m statt 796 m).
    Wer nichts einstellt, hat also schon eine Grenze von gut einem Kilometer —
    das gehört gesagt, sonst hält man das Fehlen weiter Zugangswege für einen
    Fehler.
  - **Eine ZEITgrenze hält keine METERgrenze**, und das ist der Befund, der
    die Bauweise bestimmt: 888 s (aus 800 m gerechnet) gaben am Dortmunder
    Stadtrand Zugangswege von 983 m zurück, 555 s (aus 500 m) solche von
    626 m. Der Dienst rundet jede Gehdauer auf **volle Minuten** (gemessen:
    alle Dauern Vielfache von 60), und sein Tempo schwankt je Weg zwischen
    **0,93 und 1,48 m/s** (Mittelwert 1,17). **Deshalb beides:** Die Anfrage
    fragt großzügig (0,9 m/s, auf Minuten aufgerundet), und
    `Verbindungsfilter.passt` hält hinterher die Zahl, die auf dem Knopf
    steht. Wer nur die Zeit schickte, verspräche eine Zahl, die nicht gilt;
    wer nur siebte, verlöre Verbindungen, die gepasst hätten.
  - **Die Grenze gilt für die RÄNDER, nicht für Umstiegswege**
    (`Verbindung.randfusswege`). Ein Fußweg mitten in der Verbindung steht als
    Fußpfad im Fahrplan, lässt sich beim Dienst nicht begrenzen, und ihn
    wegzusieben nähme Verbindungen weg, ohne dass es eine Anfrage gäbe, die
    sie vermeidet. Die Fußzeile schreibt das hin — dieselbe Ehrlichkeit wie
    bei „Plan".
  - **Feste Stufen, kein Schieberegler.** Eine Grenze auf den Meter genau
    täuschte eine Genauigkeit vor, die es nicht gibt: Die gezeigte Länge ist
    der Weg, den der Dienst gerechnet hat, nicht der, den jemand wirklich
    geht.
  - **Sie ist die EINZIGE der drei Einschränkungen, die gemerkt wird.**
    Verkehrsmittel und Ticket gehören zur FAHRT, die Gehstrecke zur PERSON —
    wie weit jemand laufen kann, ändert sich nicht über Nacht. Die Sorge aus
    1.1.20 („eine App, die beim nächsten Öffnen still etwas weglässt") bleibt
    trotzdem beantwortet: Der Wert steht auf dem Knopf.
  - **Ein `didSet` läuft beim Initialisieren nicht mit** — nur deshalb kann
    `Verbindungsmodell.init` den gemerkten Wert setzen, ohne eine Suche
    auszulösen, bevor überhaupt ein Ziel dasteht. Dafür hat `filter` keinen
    Vorgabewert mehr und wird vollständig im `init` belegt.
- **Das LAND steht in der Haltestellenkennung — und nur dort**
  (`Model/Landkennung.swift`, ab 1.1.21, Ansage des Nutzers 09/2026: „Ich
  hätte gedacht, dass es irgendwo ein Verzeichnis gibt. So ist zum Beispiel
  komplett klar, dass eine Fahrt … von München nach Salzburg … auch auf
  österreichischem Gebiet vom Deutschlandticket abgedeckt wird.").
  - **Ein Tarifverzeichnis gibt es in den Daten NICHT** (nachgemessen
    19.09.2026): MOTIS kann GTFS-Fares, der DELFI-Datensatz trägt aber keine —
    `debugOutput.fares` steht auf 0, `agencyFareUrl` ist an jedem Abschnitt
    leer. **Das nicht als lösbar versprechen**, solange keine Quelle dafür
    gemessen ist.
  - **Gelesen wird der Landesvorsatz der Kennung**: `de-DELFI_de:09162:…`,
    `de-DELFI_at:45:50002` (Salzburg), `de-DELFI_NL:S:vl` (Venlo — GROSS
    geschrieben, also ohne Rücksicht auf Schreibweise vergleichen),
    `de-DELFI_nl:…` (Enschede), `ch:` (Basel).
  - **Zwei naheliegende Wege sind gemessen falsch, und beide in BEIDE
    Richtungen.** Erstens sagt der Datensatz vorn nicht das Land:
    `nl-OpenOV_2860697` ist „Aachen Hbf" und `be-sncb_8015345` ist „Aachen Hbf
    (DE)" — deutsche Bahnhöfe in fremden Datensätzen —, während
    `de-DELFI_000008101912` „Reutte in Tirol" ist, also Österreich im
    deutschen. Zweitens sind rein numerische Kennungen KEINE UIC-Nummern: Das
    sieht bestechend aus (Ehrwald `…008100089`, und 81 ist Österreich), aber
    „Finkenwerder" in Hamburg steht als `…015198010` und „Hannover
    Hauptbahnhof" als `…090031022`. **Wer hier eine Systematik erkennt, prüft
    sie an einem Gegenbeispiel, bevor er sie baut.**
  - **Unbekannt heißt unbekannt und nie „Deutschland".** Die Halte der
    Außerfernbahn (Ehrwald, Reutte) tragen im deutschen Datensatz numerische
    Kennungen; daraus „bleibt in Deutschland" zu machen, behauptete genau das
    Falsche. Die Zeile sagt in diesem Fall, dass das Land nicht feststellbar
    ist.
- **Die Grenzabschnitte sind eine LISTE mit Datum und Herkunft**
  (`Model/Grenzfall.swift`, ab 1.1.21). Weil es kein Verzeichnis zu holen
  gibt, steht sie von Hand da — kurz mit Absicht, denn jeder Eintrag ist eine
  Behauptung über einen Fahrschein.
  - **Die App sagt nie „gilt", sondern „steht in dieser Liste".** Tarife
    ändern sich zum Fahrplanwechsel, die Liste nicht von selbst. Dieselbe
    Regel wie beim Wort „Plan" an einer Abfahrt.
  - **`gesichert` trennt Bestätigtes von allgemein Bekanntem** — dieselbe
    Bauweise wie `Zugang.seiteGeprueft`. Bestätigt sind Freilassing –
    Salzburg Hbf und Emmerich – Arnhem Centraal (beides Ansagen des Nutzers,
    Arnheim aus eigener Fahrt); Kufstein, Venlo und Enschede stehen als
    ungeprüft drin und sagen das auch.
  - **Verglichen wird der GANZE Haltename, nicht ein Bruchstück** (ab
    1.1.22). Der erste Entwurf suchte Bruchstücke — und daran wäre genau der
    Fall gescheitert, um den es geht: „venlo" steckt auch in „Venlo,
    Koninginnesingel" und „arnhem" in „Arnhem Velperpoort", also in
    Stadtverkehr, der sicher nicht enthalten ist. Der Preis ist eine
    Schreibweise, die nicht greift; das ist die Richtung, in der ein Fehler
    nichts kostet.
  - **Die Halte eines Eintrags werden ABGEFRAGT, nicht geraten.**
    Nachgemessen 19.09.2026 an Düsseldorf → Arnheim: Die RE19 hält jenseits
    der Grenze zweimal — in Zevenaar und in Arnhem Centraal. Ohne den
    Zwischenhalt fiele jede Fahrt, die dort hält, in den vorsichtigen Zweig.
  - **Alle oder keiner**: Ein Eintrag zählt nur, wenn er JEDEN ausländischen
    Halt der Verbindung abdeckt. Eine Fahrt, die hinter Salzburg weiter nach
    Linz geht, ist keine Salzburgfahrt mehr.
  - **Ein Treffer neben unbekannten Halten ist kein glatter Treffer.**
    Gemessen an Mönchengladbach → Venlo: Der Zug endet in Venlo (Treffer),
    danach geht es mit einem niederländischen Stadtbus weiter, dessen Halte
    keinen Landesvorsatz tragen — und der Bus ist sicher nicht enthalten. Die
    Zeile hängt deshalb den Nachsatz an, statt „steht in der Liste" zu sagen.
  - **Basel steht bewusst NICHT drin.** „Basel Bad Bf" liegt im deutschen
    Tarifgebiet, „Basel SBB" nicht — beide tragen `ch:` und beide heißen
    „Basel". Ein Stichwort „basel" deckte also genau den Fall mit ab, der
    nicht gilt.
- **Die Dauer wird als BALKEN vergleichbar, nicht durch Stauchen der Schilder**
  (`Views/Dauerbalken.swift`, ab 1.1.19, Ansage des Nutzers 09/2026: „Es wäre
  schön, wenn man die angezeigten Verbindungen schnell hinsichtlich ihrer Dauer
  vergleichen könnte … die längste Verbindung geht vom Bildschirmrand zu
  Bildschirmrand, die anderen entsprechend kürzer."). Die Zahl rechts an der
  Zeile ist die Auskunft, aber kein Vergleich: Sechs Angaben untereinander muss
  man lesen und im Kopf voneinander abziehen.
  - **Die vorgeschlagene Form geht nicht auf — nachgezählt am Bildschirmfoto
    des Nutzers** (Duisburg Großenbaum, 19.09.2026): Die LÄNGSTE Verbindung
    (2 h 3 min) trug DREI Schilder, die KÜRZESTE (1 h 20 min) VIER. Auf 65 %
    der Breite gestaucht müsste die kürzeste schmaler sein als die längste und
    dabei ein Schild mehr tragen; es bliebe nur, die Schilder zu verkleinern
    oder abzuschneiden — und „die Linienschilder SIND die Ergebniszeile".
    **Merke: Bevor eine Länge etwas codiert, prüfen, ob der Inhalt in diese
    Länge passt.**
  - **Der Balken ist die Zeitachse DIESER Verbindung.** Jeder Abschnitt liegt
    an seiner echten Stelle (`start`/`ende`), die Lücken dazwischen sind die
    Wartezeit. Nur die Abschnitte zu zeichnen wäre falsch: Sie summieren sich
    NICHT zur Gesamtdauer — zwischen zwei Fahrten steht man am Bahnsteig, und
    in der gemeldeten Liste ist das ein gutes Viertel der Reise.
  - **Verglichen wird die LÄNGE, nicht die Uhrzeit.** Jeder Balken beginnt bei
    seiner eigenen Abfahrt. Eine gemeinsame Achse sagte zusätzlich, wer zuerst
    ankommt, schöbe aber jede spätere Verbindung nach rechts; bei anderthalb
    Stunden Spanne bliebe von den Balken wenig übrig. Die Fußzeile schreibt
    hin, welcher Vergleich gemeint ist.
  - **Maßstab ist die gezeigte LISTE** (`Verbindungsmodell.laengsteDauer`),
    keine feste Obergrenze: Mit „drei Stunden" als Maß wären sechs Vorschläge
    zwischen 80 und 123 Minuten sechs fast gleich lange Balken.
  - **Ein ausfallender Abschnitt wird blass, nicht rot.** Rot IST hier eine
    Linienfarbe (RE1); eine zweite Bedeutung daneben wäre nicht zu trennen.
    Gesagt wird der Ausfall ohnehin zweimal — als Band über der Zeile und als
    Kreuz am Schild.
  - **Für VoiceOver ausgeblendet.** Die Zeile nennt die Dauer bereits in
    Worten; „Balken, 65 Prozent" wäre eine zweite Ansage derselben Sache.
  - **Die Sorge um schmale Geräte erledigt sich damit von selbst**: Der Balken
    trägt keine Schrift und wird beliebig kurz, die Schilderkette liegt seit
    jeher in einer waagerecht scrollbaren Zeile. Ein senkrechtes Layout oder
    eine zweite Schiebefläche braucht es nicht.
  - **Die Musterdaten liefern seit 1.1.19 drei verschieden lange
    Verbindungen.** Vorher waren sie auf die Minute gleich und unterschieden
    sich nur in der Abfahrt — an ihnen ließ sich der Balken gar nicht ansehen.
    **Wer eine Anzeige baut, die Werte VERGLEICHT, prüft, ob die Musterdaten
    überhaupt etwas zu vergleichen hergeben.**

- `MARKETING_VERSION` und `CURRENT_PROJECT_VERSION` stehen an je zwei
  Stellen im pbxproj (Debug + Release) — KEINE Skript-Bauphase. **Jede
  Arbeitseinheit hebt Patch- UND Build-Nummer um je +1**, ohne Nachfrage,
  als Teil des PRs. Zählung ab 09/2026: 1.0.0 (Build 1), dann 1.0.1
  (Build 2), 1.0.2 (Build 3), 1.0.3 (Build 4), 1.0.4 (Build 5), 1.0.5 (Build 6),
  1.0.6 (Build 7), 1.0.7 (Build 8),
  1.0.8 (Build 9), 1.0.9 (Build 10), 1.0.10 (Build 11), 1.0.11 (Build 12) usw.
  **1.1.0 (Build 13) ist ein bewusster Sprung** (Ansage des Nutzers,
  09/2026): Die Verbindungsauskunft ist eine Funktionsfassung und keine
  zwölfte Nachbesserung — derselbe Gedanke wie bei Tafelbild 1.4.0 und
  Schulalarm 1.1.0. Die Marken ab 1.0.x in diesem Papier bleiben stehen;
  sie sagen, wann etwas in den Quelltext kam. Danach zählt es weiter:
  1.1.1 (Build 14), 1.1.2 (Build 15), 1.1.3 (Build 16), 1.1.4 (Build 17), 1.1.5 (Build 18), 1.1.6 (Build 19), 1.1.7 (Build 20), 1.1.8 (Build 21), 1.1.9 (Build 22), 1.1.10 (Build 23), 1.1.11 (Build 24), 1.1.12 (Build 25), 1.1.13 (Build 26), 1.1.14 (Build 27), 1.1.15 (Build 28), 1.1.16 (Build 29), 1.1.17 (Build 30), 1.1.18 (Build 31), 1.1.19 (Build 32), 1.1.20 (Build 33), 1.1.21 (Build 34), 1.1.22 (Build 35), 1.1.23 (Build 36), 1.1.24 (Build 37), 1.1.25 (Build 38), 1.1.26 (Build 39), 1.1.27 (Build 40), 1.1.28 (Build 41), 1.1.29 (Build 42), 1.1.30 (Build 43), 1.1.31 (Build 44), 1.1.32 (Build 45) … Dazu gesetzt (Ansage des Nutzers,
  09/2026): `DEVELOPMENT_TEAM = F4989GSTWS` — dieselbe Id wie Schulalarm und
  Tafelbild — und `INFOPLIST_KEY_LSApplicationCategoryType =
  public.app-category.navigation`. Beides steht als Build-Einstellung, weil
  das Ziel `GENERATE_INFOPLIST_FILE = YES` benutzt.
- `ITSAppUsesNonExemptEncryption = NO` steht in `Config/Info.plist` UND
  als Build-Einstellung — nicht entfernen.
- Das App-Symbol rechnet `AbfahrtstafeliOS/scripts/make-icon.py` (reines
  Python, ohne fremde Bibliotheken) — nicht von Hand bearbeiten.
- Übersetzt wird in GitHub Actions
  (`.github/workflows/ios-apps-build.yml`, Eintrag
  `("AbfahrtstafeliOS", "Abfahrtstafel")` in `welche-apps.py`). **Erst
  pushen, Bau abwarten, Fehler beheben — den PR-Link erst herausgeben,
  wenn der Bau grün ist.**

## Projekt Routenplaner (Auto/Gespann, Fahrrad, zu Fuß — native iOS-App)

- App-Code: `RoutenplaneriOS/` (ein Target: App, iPhone + iPad, iOS 17, keine
  fremden Abhängigkeiten), Bundle-Id `de.familie.routenplaner`, Homescreen-Name
  „Routenplaner". Ausführlich: `RoutenplaneriOS/README.md`. Anlass (Ansage des
  Nutzers, 09/2026): Keine Routen-App plant für ein Gespann mit 2,50 m Breite
  und 3,20 m Höhe, rechnet Anhängertempo ein oder findet den kürzesten
  ERLAUBTEN Radweg.
- **Drei Dienste, alle ohne Schlüssel, jeder an echten Antworten gemessen
  (23.09.2026):** Valhalla (FOSSGIS) für Auto und zu Fuß, BRouter für das
  Rad, Autobahn GmbH für Verkehrsmeldungen. Ein Schlüssel in einer App ist
  keiner — dieselbe Regel wie in der Abfahrtstafel.
- **Gespann = Valhallas PKW-Profil mit `height`/`width`, NICHT das
  Lkw-Profil.** Gemessen: `auto` mit 9 m × 6 m wählt einen anderen Weg (49,9
  statt 48,1 km), die Maße wirken also. Das Lkw-Profil meidet zusätzlich
  Lkw-Verbote, die für Pkw mit Wohnwagen gar nicht gelten.
- **Die Fahrzeit rechnet die App selbst**, aus `trace_attributes` (Klasse,
  Tempo, Tempolimit, Bebauungsdichte je Stück): Anhänger außerorts 80,
  Autobahn 80/100, dazu Innerorts- und Abbiegeaufschlag aus dem Profil. Sie
  steht in POSTEN da, jede Zeile mit Grund; die Zeit des Dienstes daneben zum
  Vergleich. Die Aufschläge und die Innerorts-Schwelle (Dichte ≥ 11) sind
  gewählt, nicht gemessen — und stehen deshalb im Profil, nicht im Quelltext.
- **Mit dem Rad fährt Valhalla NIE über einen Gehweg ohne Radfreigabe**
  (gemessen in der Dortmunder Fußgängerzone — es fährt drumherum). Schieben
  kennt es nicht; es ist deshalb nur Rückfall, und das steht dann in der App.
- **BRouters „shortest" reichte NICHT:** Es hält `highway=pedestrian` für
  befahrbar. Das eigene Regelwerk (`BRouter.regelwerk`) sperrt Gehweg,
  Fußgängerzone, Treppe und Reitweg für Räder, solange nichts anderes
  eingetragen ist, und schaltet Schieben über `profile:schieben` ein und aus.
  Gemessen: 895 m mit, 1345 m ohne Schieben. Hochgeladen wird es über
  `POST /brouter/profile`; die Kennung verfällt, dann wird neu hochgeladen.
- **`BRouter.einordnen` ist dieselbe Regel noch einmal auf App-Seite** und
  entscheidet, was „Schieben" heißt. Wer das Regelwerk ändert, ändert beides —
  liefen sie auseinander, stünde eine Schiebestrecke als Fahrstrecke da.
  Geprüft: Ohne Schieben ordnet die App 0 m als Schieben ein.
- **BRouters eigene Zeit taugt nicht** (641 s für 895 m bei „shortest").
- **`WayTags` nennt nur Merkmale, die das Regelwerk benutzt.** `name=` und
  `ref=` kennt BRouter nicht einmal als Suchbegriff (Hochladefehler „unknown
  lookup name").
- **Verkehrsmeldungen nur für Autobahnen, und das steht in der App.**
  `isBlocked` kommt als TEXT, `future` als Wahrheitswert; `CLOSURE` sperrt,
  `CLOSURE_ENTRY_EXIT` ist nur eine Auf-/Abfahrt. Baustellen nennen
  „Maximale Durchfahrtsbreite" — ist das Fahrzeug breiter, wird umfahren wie
  bei einer Sperrung. Zugeordnet wird eine Meldung über Anfang, Mitte und
  Ende (je höchstens 60 m von der Route) und die RICHTUNG über die Reihenfolge,
  in der die Route an Anfang und Ende vorbeikommt. Umfahren wird über
  `exclude_polygons` (gemessen: wirkt), ein Kästchen von rund 250 m — es
  sperrt beide Richtungen, und die Detailansicht sagt das. Ein Stau
  verlängert die Zeit, verlegt die Route aber nicht.
- **Der Bildschirm bleibt an, solange die App vorn ist** (ab 1.0.1, Ansage
  des Nutzers 09/2026). `isIdleTimerDisabled` hängt an `scenePhase` in
  `RoutenplanerApp`: nur `.active`, im Hintergrund gilt wieder das Gerät.
  **Im Hintergrund arbeitet die App nur, solange eine AUFZEICHNUNG läuft**
  (ab 1.0.5) — Planen, Meldungen und Kacheln nie.
- **Streckenaufzeichnung** (`Dienste/Aufzeichner.swift`, `Model/Fahrt.swift`,
  ab 1.0.5, Ansage des Nutzers 09/2026: „möglichst genau, egal wie viel Akku
  es kostet"). `BestForNavigation`, `distanceFilter = None`,
  `pausesLocationUpdatesAutomatically = false`, `activityType` je
  Fortbewegung. Hintergrund über `UIBackgroundModes = location` plus
  `CLBackgroundActivitySession` — mit „Beim Verwenden", NICHT „Immer".
  **Ohne den Plist-Eintrag stürzt `allowsBackgroundLocationUpdates = true`
  ab — nie entfernen.** Bei ungefährer Ortung wird einmalig die genaue
  erbeten (Schlüssel „Aufzeichnung" in
  `NSLocationTemporaryUsageDescriptionDictionary`).
- **Jede Messung wird SOFORT angehängt** (`<Kennung>.spur`, eine Zeile je
  Messung, in Application Support), der Kopf (`.json`) alle 30 Messungen.
  Wird die App beendet, bleibt eine Fahrt ohne `ende` liegen; beim nächsten
  Start steht „Fortsetzen / So abschließen" im Bedienfeld. Fortgesetzt wird
  als neuer ABSCHNITT — dazwischen hat niemand gemessen, die Linie wird dort
  nicht durchgezogen; Pausen ebenso. **Neu STARTEN kann iOS eine beendete
  App nur mit „Immer"** — nicht als „zeichnet immer auf" darstellen.
- **`Spurrechner` ist die EINE Rechnung** für Live-Anzeige und gesicherte
  Fahrt. Zwei Regeln, gewählt und nicht gemessen: nur Messungen bis ±30 m,
  und gezählt wird erst, wenn der Abstand zum letzten gezählten Punkt die
  Unsicherheit beider übersteigt (sonst wächst die Strecke an jeder Ampel).
  Die Datei behält JEDE Messung, damit sich die Regeln später ändern lassen.
  Die GPX-Ausgabe enthält alle Messungen bis ±30 m mit Zeit und Höhe,
  ungeglättet, ein `trkseg` je Abschnitt.
- **Auf der Karte in Stücken zu 300 Punkten** (`Routenkarte.spurSetzen`):
  Nur das letzte, wachsende Stück wird jede Sekunde ersetzt. Eine Linie aus
  zehntausend Punkten jede Sekunde neu zu bauen wäre der teure Weg.
- **„Ohne Schieben" ist ein Schalter im Bedienfeld** (ab 1.0.1), nicht nur im
  Profil-Editor — ob geschoben werden darf, entscheidet man je Fahrt.
  Gespeichert wird er am gewählten Profil (`Planer.schiebenSetzen`) und
  schickt `profile:schieben=0` an BRouter; gemessen: dann 0 m Schieben.
- **Start und Ziel durch Antippen der Karte** (`Routenkarte` mit `MapReader`,
  `PlanerView.antippen`, ab 1.0.2, Ansage des Nutzers 09/2026). Den Tipp nimmt
  die KARTE entgegen (`onTapGesture` + `MapProxy.convert`); Schieben und
  Zoomen bleiben unberührt, und auf der Karte liegt weiter kein Bedienelement.
  Gefragt wird in einem Dialog: „Route hierhin – von meinem Standort", „Als
  Ziel", „Als Start". **Erst die Frage, dann der Name** — der Geocoder
  braucht eine Sekunde und wird nachgetragen, nur wenn noch derselbe Punkt
  gemeint ist (Lehre aus Abfahrtstafel 1.1.26). **Ohne bekannten Standort
  wird NICHT von einem alten Start gerechnet**: Das Ziel wird gesetzt, der
  Start geleert, und die App sagt, was fehlt.
- **Verkehrslage auf der Karte ist Apples Anzeige** (`.mapStyle(.standard(
  showsTraffic:))`, Autosymbol unten, ab 1.0.2). Sie geht NICHT in die
  Berechnung ein — MapKit gibt diese Daten nicht heraus. In die Route gehen
  nur die Autobahn-Meldungen; ihr Schalter heißt seither „Meldungen" statt
  „Verkehr", sonst hießen zwei verschiedene Dinge gleich. Wahl in
  `@AppStorage` (in der VIEW).
- **CarPlay: nein, und das bleibt so, bis Apple es bewilligt** (Frage des
  Nutzers 09/2026). Eine Karten-App braucht das Entitlement
  `com.apple.developer.carplay-maps`, das Apple nur auf Antrag vergibt, und
  zwar für Apps mit Zielführung Schritt für Schritt — die hat diese App
  nicht. **Ohne Bewilligung nie in eine Entitlements-Datei eintragen**: Das
  Projekt wäre unsignierbar (dieselbe Lehre wie Reisebuch 1.0.45). Weg, falls
  gewünscht: erst eine Zielführung bauen, dann den Antrag unter
  developer.apple.com/carplay stellen, erst danach die CarPlay-Szene.
- **Die Karte ist seit 1.0.3 eine `MKMapView` aus UIKit** (`Routenkarte`,
  Ansage des Nutzers 09/2026: Hell/Dunkel, andere Kartenmodelle, Radwege und
  Belag ein- und ausblenden, „über einen Menüschalter an der Karte"). Die
  SwiftUI-`Map` kann unter iOS 17 keine Kachelschicht zeigen. Auf der Karte
  liegt weiterhin kein Bedienelement: Zeichen sind `isEnabled = false`, den
  Tipp nimmt ein eigener Erkenner, der auf den Doppeltipp-Zoom wartet.
  Ortung, Kompass und Maßstab stehen am Rand, der Ebenen-Knopf oben links.
- **Kachelquellen, alle am 23.09.2026 gemessen** (HTTP 200, PNG 256 px, ohne
  Schlüssel): OSM, CyclOSM, CyclOSM-lite (durchsichtige Radweg-Schicht),
  OpenTopoMap, Waymarked Trails cycling. `Kacheln.sitzung` hält die
  OSM-Richtlinie ein (User-Agent, `URLCache` 256 MB, zwei Verbindungen je
  Server, kein Vorausladen); über der höchsten Stufe eines Dienstes wird die
  letzte Kachel vergrößert statt neu angefragt. Der Lizenzhinweis steht auf
  der Karte und ist nicht abschaltbar. **Thunderforest (OpenCycleMap)
  antwortete ohne Schlüssel, verlangt laut Bedingungen aber einen — nicht
  schlüssellos einbauen**; nur mit einem EIGENEN Schlüssel des Nutzers im
  Schlüsselbund.
- **Dunkel gibt es nur für Apples Karte** (`overrideUserInterfaceStyle`);
  die freien Kacheln liegen nur hell vor, und nachträglich umgefärbte
  Kacheln hätten Farben, die nichts mehr bedeuten. Die Verkehrslage ebenso
  nur auf Apples Karte; ihr Schalter wohnt seit 1.0.3 im Kartenmenü und
  nicht mehr im Bedienfeld (keine doppelten Schalter).
- **Der Belag der Radroute kommt aus `surface` in BRouters WayTags**
  (`Belag.aus`, fünf Klassen, „nicht eingetragen" wird nicht geraten). Eine
  EIGENE Liste (`Route.belaege`) neben den Abschnitten — als Feld am
  Abschnitt zerfiele jede Schiebestrecke in der Detailansicht an jedem
  Belagwechsel. Die Zuordnung der Stellen (`BRouter.stellen`) teilen sich
  beide Listen. Farbe UND Strichbild, und die Legende nennt die Kilometer.
- **Jede Planung liefert Alternativen** (ab 1.0.4, Ansage des Nutzers
  09/2026). Gemessen 23.09.2026: Valhalla `alternates: 2` gibt bei Auto, Rad
  und zu Fuß je zwei echte andere Wege zurück (Dortmund → Köln 94,3 / 99,7 /
  106,3 km); BRouter rechnet `alternativeidx` 0 bis 3 als EINZELNE Anfragen
  (3573 / 4350 / 4964 / 4246 m — nicht nach Länge geordnet, sortiert wird in
  der App). Gefragt werden 0 bis 2; scheitert eine Alternative, zählt nur die
  erste als Fehler. Fast gleich lange Vorschläge (unter 0,5 %) fallen weg.
  Ausgewählt wird in der Leiste unter der Karte, NICHT auf der Karte — dort
  setzt ein Tipp Start oder Ziel. Gerahmt wird nur bei einer neuen Rechnung.
- **Staus zählen in die REIHENFOLGE, nicht nur in die Zeit** (ab 1.0.4,
  gemeldet 09/2026: „dass ein Stau zwar auf der Karte angezeigt wird, aber
  nicht bei der Berechnung … berücksichtigt wird"). Die Autobahn GmbH meldet
  `delayTimeValue` in Minuten als TEXT (gemessen: 1 bis 55 min an A1–A9);
  jede Alternative bekommt ihren eigenen Stauverlust, und die schnellste MIT
  Stau steht vorn. Ab `Planer.stauSchwelleMin` (10 min, gewählt) wird eigens
  eine Umfahrung angefragt: Sperrfläche um die MITTE des Staus. Gemessen, dass
  das wirkt: Dortmund → Wuppertal mit der Mitte des Staus Gevelsberg–Eichenkamp
  gesperrt, erste Route 48,1 → 49,9 km. Die Umfahrung wird mit derselben
  Rechnung bewertet wie alle — gerät sie selbst in einen Stau, zählt der mit.
  Apples Verkehrslage bleibt reine Anzeige; TomTom und HERE hätten Daten für
  alle Straßen, verlangen aber einen Schlüssel. Staus abseits der Autobahn
  kennt die App deshalb NICHT — das steht in jedem Auto-Ergebnis.
- **Meldungen ohne Zeitangabe zählen nicht** — und das wird GESAGT. Nicht
  schätzen: eine erfundene Minutenzahl stünde als Posten in der Rechnung.
- **Overpass war aus der Bauumgebung nicht erreichbar**, die OSM-API schon —
  die ist aber zum Bearbeiten da und kein Datendienst für Apps. Die App fragt
  sie deshalb nicht. Offen: Unterführungen OHNE eingetragene Höhe erkennen.
- `MARKETING_VERSION` und `CURRENT_PROJECT_VERSION` stehen an je zwei Stellen
  im pbxproj (Debug + Release), KEINE Skript-Bauphase. **Jede Arbeitseinheit
  hebt Patch- UND Build-Nummer um je +1.** Start: 1.0.0 (Build 1),
  dann 1.0.1 (Build 2), 1.0.2 (Build 3), 1.0.3 (Build 4), 1.0.4 (Build 5),
  1.0.5 (Build 6).
  `DEVELOPMENT_TEAM = F4989GSTWS`, Kategorie Navigation,
  `ITSAppUsesNonExemptEncryption = NO` in `Config/Info.plist` UND als
  Build-Einstellung — nicht entfernen.
- Das App-Symbol rechnet `RoutenplaneriOS/scripts/make-icon.py`.
- Übersetzt wird in GitHub Actions (Eintrag
  `("RoutenplaneriOS", "Routenplaner")` in `welche-apps.py`). **Erst pushen,
  Bau abwarten, Fehler beheben — den PR-Link erst herausgeben, wenn der Bau
  grün ist.**

## Projekt Urlaubstagebuch (Reisebuch aus Fotos und Text, native iOS-App)

- App-Code: `UrlaubstagebuchiOS/` (ein Target: App, iPhone + iPad, iOS 17,
  keine fremden Abhängigkeiten). Aus Fotos und einem Tagebuchtext entsteht
  ein gesetztes Buch: je Tag Seiten mit Text, Bildern und einer Karte der
  Tagesstrecke, als PDF ausgebbar. Ausführlich:
  `UrlaubstagebuchiOS/README.md`.
- **Homescreen-Name „Reisebuch"**, Ordner/Ziel/Bundle-Id bleiben
  „Urlaubstagebuch" / `de.familie.urlaubstagebuch` — nach dem ersten
  Signieren nicht mehr ändern.
- **Der Tag kommt aus DREI ZAHLEN, nie aus einer Umrechnung**
  (`Model/Tagesdatum.swift`). Ein EXIF-Aufnahmedatum hat KEINE Zeitzone:
  „2026:08:12 19:33:21" ist die Uhr am Ort der Aufnahme. Wer daraus ein
  `Date` macht, muss eine Zone annehmen, und jede Annahme ist irgendwo
  falsch — ein Foto vom 12. August, 23:40 Ortszeit in Bangkok wäre in
  Deutschland der 13. und rutschte in den falschen Tagebucheintrag, ohne
  dass etwas auffiele; die Uhrzeit stimmt ja. Der Tagesschlüssel wird
  deshalb unmittelbar aus den ZIFFERN gebaut (EXIF-Zeichenkette,
  Datumszeile im Text). Das `Date` daneben sortiert nur INNERHALB eines
  Tages, trägt eine feste Zone und ist kein Augenblick auf der Weltuhr.
  **Die einzige Stelle, an der ein Tag doch aus einer Umrechnung entsteht,
  ist der Zeitpunkt aus der Fotomediathek** — die gibt nichts anderes her,
  und das steht so im Quelltext.
- **Ohne Mediathekserlaubnis gibt iOS keine Aufnahmeorte heraus.** Das ist
  die Falle, an der ein Reisetagebuch ohne Vorwarnung scheitert: Der
  Fotowähler braucht KEINE Berechtigung, und genau deshalb hält man ihn für
  den ganzen Weg. Hat die App keinen Zugriff auf die Mediathek, entfernt
  iOS die Standortdaten aus den herausgegebenen Bilddaten — die Fotos
  kommen an, die Karte bleibt leer, und es sieht aus, als könne die App
  kein EXIF lesen. Deshalb ist der Fotowähler der von UIKit
  (`Views/Waehler.swift`): Nur ein `PHPickerViewController` mit
  `PHPickerConfiguration(photoLibrary: .shared())` gibt den
  `assetIdentifier` heraus, über den sich der Ort am Mediathekseintrag
  nachschlagen lässt. SwiftUIs `PhotosPicker` kann das nicht, sein
  `itemIdentifier` bleibt leer. **Nicht auf `PhotosPicker` zurückbauen.**
- **Geladen werden DATEN, nie ein `UIImage`.** Ein Bild ist schon entpackt
  — seine Metadaten sind dann weg, und damit Datum und Ort. Daran
  scheitern die meisten Versuche, EXIF aus einem Fotowähler zu bekommen.
  Der Weg über **Dateien** ist von alldem nicht betroffen: Dort kommt die
  Datei unangetastet an. Er ist der verlässlichere und deshalb kein
  Notbehelf.
- **Wer die Erlaubnis verweigert, wird nicht ausgesperrt** (dieselbe Lehre
  wie Schulalarm 1.1.0/Build 43). Alles außer dem automatischen
  Aufnahmeort läuft weiter, die Punkte lassen sich von Hand setzen, und
  die App sagt in einem Satz, was fehlt und warum.
- **Breite und Höhe stehen so in der Datei, wie der Sensor sie gelesen
  hat.** Ein hochkant gehaltenes Telefon liefert 4032 × 3024 plus eine
  Orientierung (5 bis 8 = gedreht). Ohne das Tauschen wäre jedes
  Hochformat im Layout ein Querformat, und die Fotoreihen gingen nicht
  auf. Beim Vorschaubild macht das
  `kCGImageSourceCreateThumbnailWithTransform` — ohne diese Zeile liegt
  jedes Hochformat quer, und zwar NUR in der Vorschau.
- **Der GPS-Betrag ist immer positiv**; ob Süd oder West, steht in einem
  eigenen Feld. Wer es überliest, verlegt jede Reise auf die Nordhalbkugel
  und nach Osten.
- **Seite und PDF zeichnet DERSELBE Setzer** (`Dienste/Seitensatz.swift`,
  CoreText). Eine Buchseite wird zweimal gezeichnet — auf dem Bildschirm,
  damit man sie anfassen kann, und ins PDF, damit man sie drucken kann.
  Zwei Zeichenwege bedeuten früher oder später zwei Ergebnisse, und der
  Unterschied fällt auf, wenn das Buch beim Drucker liegt. Die Ansicht
  hängt eine UIView davor (`Views/Textkasten.swift`), die nichts weiter
  tut, als diese Funktionen aufzurufen. **Wer eine neue Blockart baut,
  zeichnet sie dort und nicht zweimal.**
- **Ein `Text` aus SwiftUI taugt hier nicht:** kein Blocksatz, keine feste
  Zeilenhöhe, keine Silbentrennung, eigener Umbruch. Und `draw(with:)` aus
  UIKit setzt über TextKit, also über einen ANDEREN Umbruch als den, mit
  dem `Textmass` (CoreText) gerechnet hat — ein Text, der beim Messen
  sechs Zeilen hatte und beim Zeichnen sieben, läuft unten aus seinem
  Block.
- **Gemessen wird der Umbruch, nicht geschätzt** (`Model/Textmass.swift`).
  Eine Schätzung aus Zeichenzahl mal Schriftgröße ist bei einer
  Proportionalschrift regelmäßig um ein Drittel daneben.
- **Silbentrennung ist hier ERLAUBT**, anders als in Textauszug und
  Wörterwerkstatt. Getrennt wird nicht von uns, sondern von Apples
  deutschem Wörterbuch (`hyphenationFactor` mit `languageIdentifier`).
  Eine selbst gebaute Trennung bleibt verboten: Die deutsche ist nicht
  ableitbar, und eine falsche stünde für immer im gedruckten Buch.
- **Wo das Bild im Rahmen liegt, rechnet EINE Funktion**
  (`Bildausschnitt.zielrechteck`), benutzt von der Ansicht und vom PDF.
  Grundlage ist FÜLLEN, nicht Einpassen; was überragt, wird beschnitten.
  Rahmen und Ausschnitt sind zwei Dinge: Der Rahmen ist der Platz auf der
  Seite, der Ausschnitt der sichtbare Teil des Bildes. Beides muss gehen.
- **Gerechnet wird in SEITENPUNKTEN, nicht in Bildschirmpunkten.** Der
  Maßstab liegt als eine einzige Skalierung über der Seite, und jede Geste
  wird durch ihn geteilt, bevor sie ins Modell geht. Ohne diese Division
  wanderte ein Block auf einer klein gezoomten Seite dreimal so weit wie
  der Finger — und ein Buch, das auf dem iPhone gestaltet wurde, sähe auf
  dem iPad anders aus.
- **Die Karte auf der Seite ist ein BILD** (`MKMapSnapshotter`,
  `Dienste/Kartenwerk.swift`), mit drei Wirkungen auf einmal: Das PDF
  sieht aus wie die Ansicht; die Karte schluckt keine Geste, die den Block
  bewegen wollte (Lehre aus Abfahrtstafel 1.1.18, deshalb
  `.allowsHitTesting(false)`); und ohne Netz bleibt das Bild stehen. Der
  Punkt wird dagegen auf einer ECHTEN Karte gewählt, in einem eigenen
  Bildschirm, über ein festes Fadenkreuz — ein Tippen wäre naheliegend und
  schlechter, der Finger verdeckt genau die Stelle, die er trifft.
- **Gezeichnet wird die Verbindung der Punkte, nicht der gefahrene Weg**,
  und das steht unter der Karte. Welche Straße es war, steht in keinem
  Foto. Dieselbe Ehrlichkeit wie bei der gestrichelten Luftlinie in der
  Abfahrtstafel.
- **Die Spur wird AUSGEDÜNNT und dabei gezählt** (`Dienste/Spurbau.swift`,
  Vorgabe 150 m). Wer an einem Tag zweihundert Fotos macht, macht
  hundertachtzig davon an fünf Orten; ungefiltert wäre die Spur ein Knäuel.
  Zusammengefasst wird nach ENTFERNUNG und nicht nach Zeit: eine Stunde im
  Museum ist ein Punkt, eine Stunde im Zug sind viele. Was
  zusammengefasst wurde, zählt `zusammengefasst` mit — stillschweigend
  wegzulassen wäre eine Lücke, die niemand bemerkt.
- **Ein Handpunkt OHNE Uhrzeit kommt ans Ende und wird nicht einsortiert.**
  Wohin er in der Tagesfolge gehört, weiß niemand — auch die App nicht.
  Eine Reihenfolge, die sie sich ausdenkt, sähe aus wie eine, die aus den
  Daten kommt. Verschieben geht in der Punktliste, und das steht dabei.
- **Der Textimport behauptet nichts, er ZEIGT** (`Dienste/Textimport.swift`,
  `Views/TextimportView.swift`). Die Regel hat zwei Hälften, beide an 18
  echten Sätzen gemessen (sechs davon dürfen NICHT treffen): Vor dem Datum
  darf nur Beiwerk stehen (Wochentag, „am", „Tag 5", Satzzeichen); nach dem
  Datum steht die Überschrift, höchstens 60 Zeichen und **groß
  anfangend**. Damit fallen „Heute, am 12.08., war es heiß." und „Am 12.08.
  begann alles mit einem verspäteten Flug" heraus, und „12.08.2026 –
  Ankunft in Lissabon" ergibt Datum und Überschrift auf einmal.
- **Vorn wird NUR ein Wochentag oder eine Zahl abgeschnitten, nie ein
  Artikel** (gefunden beim Messen). Ein früherer Entwurf strich „der" und
  „den" überall, und aus „Der Weg nach oben" wurde „Weg nach oben" — ein
  Artikel steht am Anfang jeder zweiten Überschrift.
- **Ein Monatsname muss ein echter sein.** Ohne diese Prüfung würde aus
  „3. Tag in Porto" ein Datum, und der Monat wäre geraten.
- **Fehlt die Jahreszahl, gilt die des vorigen Tages** — rutscht das Datum
  dabei in die Vergangenheit, ist es der Jahreswechsel. Eine Reise über
  Silvester ist nichts Besonderes, ein Tagebuch, das dabei elf Monate
  zurückspringt, schon.
- **Was von Hand geändert wurde, bleibt.** Jeder angefasste Block trägt
  `vonHand` und wird vom Neuanordnen in Ruhe gelassen; vor dem
  Überschreiben eines bearbeiteten Tages fragt die App ausdrücklich nach,
  und die Tagesliste zeigt an jedem solchen Tag ein Zeichen. Eine
  Automatik, die eine Stunde Handarbeit ohne Rückfrage überschreibt,
  benutzt man genau einmal. Dazu ein flacher Rückgängig-Stapel (25 Stände)
  — ohne ihn traut sich niemand, etwas auszuprobieren.
- **Gemerkt wird beim ANFANG einer Geste, nicht bei jedem Bildpunkt.** Bei
  sechzig Zwischenständen je Fingerbewegung wäre der Stapel nach einer
  Geste voll und der Zustand davor unerreichbar.
- **Örtlich heißt ABWEICHUNG, nicht Kopie** (`Schriftabweichung`). Alle
  Felder sind freiwillig; was `nil` ist, folgt weiter der globalen
  Einstellung. Würde eine örtliche Änderung stillschweigend alle Werte
  kopieren, wäre jede spätere Änderung am Buchganzen an allen schon einmal
  angefassten Stellen wirkungslos — genau das, was man beim Umstellen
  einer Schrift nicht will.
- **Nur Schriftfamilien anbieten, die das Gerät wirklich hat**
  (`Schriftfamilie.alleDesGeraets`, geprüft mit `.vorhanden`). Eine, die dann doch die Systemschrift
  zeichnet, wäre eine Auskunft, die nicht stimmt. Mitgeliefert wird keine:
  Ein Buch wird weitergegeben, und dafür bräuchte jede Schrift eine Lizenz.
- **Ein Modus, den man nicht sieht, darf die Bedeutung einer Geste nicht
  ändern.** Im Ausschnittsmodus verschiebt das Ziehen das Bild IM Rahmen
  statt den Rahmen auf der Seite — und ein Band über der Seite sagt das.
  Dieselbe Regel wie beim Fußwegmesser der Abfahrtstafel.
- **Nichts geht stillschweigend verloren:** Fotos ohne Datum landen in der
  Ablage und werden gezählt, Fotos ohne Ort werden gezählt, ein Wisch
  nimmt ein Foto vom Tag und nicht von der Platte, eine unlesbare Reise
  wird in der Übersicht gezählt, und der Einfuhrbericht sagt in einem Satz,
  was ankam.
- **Gesichert wird über eine temporäre Datei, die getauscht wird.** Eine
  halb geschriebene Reise wäre der Verlust eines ganzen Buches — und die
  Wahrscheinlichkeit dafür ist am höchsten, wenn viel darin steht.
- **Kein `@AppStorage` in `Reisewerk`** — dieselbe Falle wie in der
  Abfahrtstafel: Der Wrapper ist eine `DynamicProperty`, schreibt zwar in
  die Voreinstellungen, löst aber kein `objectWillChange` aus.
- **Der Layoutautomat rechnet in `CGFloat`, wo ein `CGRect` im Spiel ist**
  (getroffen beim ersten Bau): Bei einer TUPEL-Zuweisung rechnet Swift
  `Double` und `CGFloat` NICHT ineinander um, obwohl beide auf diesen
  Geräten dasselbe sind. Bei gewöhnlichen Zuweisungen und Argumenten tut
  er es — der Fehler zeigt sich also nur an dieser einen Stelle.
  **Zum zweiten Mal getroffen in 1.0.37** (`PunktwahlView.punktBei`):
  `hypot` über zwei `CGFloat` gibt `CGFloat` zurück, und das Tupel war als
  `(punkt: Reisepunkt, abstand: Double)` deklariert. Der Bau hat es
  gemeldet, nicht die Quelltextprüfung — die sieht String-Literale an.
  **Merke: Überall, wo ein Wert aus einem `CGPoint`, `CGRect` oder
  `CGSize` in ein Tupel, einen Rückgabetyp oder eine Eigenschaft vom Typ
  `Double` geht, gehört ein `Double(…)` darum.**
- **Das Ergebnis ist eine DRUCKVORLAGE, kein Bildschirmdokument** (ab
  1.0.1). Gemessen an dem, was deutsche Druckdienste verlangen (BoD,
  epubli, Saal Digital, 09/2026): PDF, Endformat exakt aus Millimetern,
  3 mm Anschnitt (BoD 5), 300 dpi, Schriften eingebettet, **RGB** — und
  damit ausdrücklich NICHT CMYK: Fotobuchdienste verlangen RGB und wandeln
  selbst um. Wer bei einer Offsetdruckerei mit ISO Coated v2 bestellt,
  braucht eine umgewandelte Datei; iOS kann kein CMYK-PDF schreiben. **Das
  nicht als lösbar versprechen.**
- **Kein Word oder Pages als Zwischenstufe** (Frage des Nutzers, 09/2026).
  Eine Textverarbeitung kennt keinen Anschnitt, bricht Bilder um, wenn sich
  eine Zeile ändert, und setzt auf jedem Rechner leicht anders. Genau das,
  worauf es bei einer Druckvorlage ankommt, ist dort nicht zu haben.
- **Das PDF entsteht über einen `CGContext`, nicht über
  `UIGraphicsPDFRenderer`** (ab 1.0.1). Der Unterschied ist genau eine
  Sache, und die entscheidet beim Druckdienst: Nur so lassen sich **TrimBox
  und BleedBox** setzen. Daran erkennt die Druckerei, wo das Endformat
  aufhört; ohne sie nimmt sie den Bogen für das Endformat und schneidet den
  Anschnitt ins Bild. Die Boxen werden als rohe `CGRect`-Bytes übergeben —
  ein `NSValue` nimmt CoreGraphics dort nicht an.
- **Der Anschnitt ist NEGATIVER Raum.** Alle Blockkoordinaten liegen im
  Endformat, dessen linke obere Ecke bei (0,0) sitzt; ein randabfallender
  Block beginnt bei `-anschnitt`. Beim Zeichnen wird der Kontext einmal um
  den Anschnitt verschoben. Das hält jede Zahl im Modell bei dem Wert, der
  auf dem Lineal steht — die Alternative (Ursprung in der Bogenecke) hätte
  jeden Rand um drei Millimeter verschoben.
- **Gerechnet wird in MILLIMETERN, gesetzt in Punkten** (`Druckmass`). Ein
  Buch wird in Millimetern bestellt; niemand kann einschätzen, ob 184
  Punkte viel sind. Die Umrechnung steht an einer Stelle und nicht als
  gerundete 2,83 verstreut — bei A4 liegt man damit schon um einen halben
  Millimeter daneben.
- **Der Bundsteg wird auf BEIDE Seitenränder gerechnet**, nicht nur auf den
  inneren. Welche Seite innen liegt, hängt an der laufenden Seitenzahl, und
  die verschiebt sich, sobald ein Tag eine Seite mehr braucht. Ein Bundsteg
  auf der falschen Seite fällt erst im gebundenen Buch auf; ein paar
  Millimeter Verschwendung sind der billigere Fehler.
- **Die Druckprüfung misst, sie behauptet nicht** (`Dienste/Druckpruefung.swift`,
  dieselbe Bauweise wie „Zustellung prüfen" bei Schulalarm). Vorab: dpi je
  Fotoblock samt Seitenzahl des schwächsten, Anschnitt, randabfallende
  Blöcke, Transparenz, Schrifteinbettung. Danach an der fertigen Datei:
  Seitenzahl, MediaBox und TrimBox, gelesen aus dem PDF und nicht aus dem
  Modell, das es geschrieben hat. Ein Buch geht einmal in den Druck und
  kommt eine Woche später als Stapel Papier zurück.
- **Ob eine Schrift eingebettet werden DARF, steht in ihr selbst** — im
  Feld `fsType` der OS/2-Tabelle. Eine Schrift mit „Restricted License
  Embedding" landet nicht im PDF, und die Druckerei ersetzt sie
  stillschweigend. Gelesen wird die Tabelle über `CTFontCopyTable`; gibt
  eine Schrift sie nicht heraus (die drei Systemschnitte tun das), sagt die
  Prüfung genau das und rät nicht. **Ob CoreGraphics die erlaubte Schrift
  dann wirklich einbettet, ist damit NICHT gemessen** — das zeigt erst ein
  Blick in die fertige Datei.
- **Die dpi-Rechnung nimmt den ZOOM des Ausschnitts mit.** Wer in ein Bild
  hineinzoomt, benutzt weniger Pixel für dieselbe Fläche; ohne diesen
  Faktor meldete die Prüfung 300 dpi für ein Bild, das mit 120 gedruckt
  wird.
- **Ein Stil setzt alles auf einmal** (`Model/Buchstil.swift`, fünf Stück).
  Schrift, Farbe, Ränder, Fugen, Schatten und die Vorliebe für bestimmte
  Seitenmuster ziehen gegeneinander: Eine schmale Didot mit engen Fugen und
  randabfallenden Bildern ergibt ein Magazin, eine runde Groteske mit
  breiten Rändern und Sofortbild-Rahmen ein Album — jede Mischung daraus
  sieht aus wie ein Versehen. Der Stil ist ein Anfang und keine Schranke;
  danach lässt sich jede Einzelheit weiter ändern.
- **Die Akzentfarbe gehört der REISE, nicht dem Stil.** Wer sie ändert,
  will sie behalten; wer den Stil wechselt, will dessen Farbe. Der Stil
  trägt sie deshalb nur als Vorschlag. Und es gibt sie **nur einmal** — ein
  zweites Feld „Linienfarbe" für die Karte gab es in 1.0.0 und lief
  unweigerlich auseinander.
- **Der Drehwinkel im Album-Muster kommt aus der KENNUNG des Fotos**, nicht
  aus dem Zufall. Ein Satz, der sich bei jedem Neuanordnen anders neigt,
  ist kein Satz, sondern ein Würfel. Die Grenze von gut vier Grad ist der
  Unterschied zwischen „mit der Hand eingeklebt" und „schief".
- **Die Schnittkante liegt ÜBER allem** (`SeitenflaecheView`). Sie ist die
  Linie, an der beschnitten wird; unter den randabfallenden Bildern
  gezeichnet wäre sie genau dort versteckt, wo man sie braucht.
- **Weiße Schrift auf einem Foto braucht einen Verlauf darunter**
  (`Blockinhalt.verlauf`). Sie ist genau so lange lesbar, bis jemand ein
  Bild mit hellem Himmel wählt — und dann verschwindet die Überschrift des
  Tages. Beim Ausgeben ohne Transparenz wird der Verlauf zu einem
  geschlossenen Feld: weniger elegant, aber lesbar, und das ist hier das
  Wichtigere.
- **Seitenzahl und Kopfzeile sind KEINE Blöcke.** Sie gehören zum Buch und
  nicht zum Tag; als Blöcke im Satz verschöbe sie irgendwann jemand. Sie
  werden beim Zeichnen jeder Seite ergänzt, und eine ganzseitig bebilderte
  Seite bekommt keine (`Seite.ohneSeitenzahl`) — die Zahl stünde auf dem
  Foto und sähe aus wie ein Versehen.
- **Eine berechnete Eigenschaft sieht billig aus** (dieselbe Falle wie bei
  der Netzkarte der Abfahrtstafel, hier zweimal getroffen): Die
  Druckprüfung läuft über alle Seiten und alle Fotos, die Datumserkennung
  über jede Zeile des Textes. Beide standen zuerst als berechnete
  Eigenschaft in einer `Form` und liefen damit bei JEDEM Neuzeichnen. Jetzt
  hängen sie an `.task` und `.onChange`.
### Was der erste gedruckte Stand zeigte (1.0.2)

Der Nutzer hat 1.0.1 als PDF ausgegeben und die Seiten geschickt. Sechs
Befunde, und keiner davon war Geschmack:

- **Jede Zeile stand als eigener Absatz** (`Dienste/Textaufbereitung.swift`).
  Der eingelesene Text war bei rund hundert Zeichen hart umbrochen und die
  Zeilen zusätzlich durch LEERZEILEN getrennt; der Setzer machte daraus
  getreulich sechs Absätze mit Absatzabstand, und ein Satz lief über zwei
  davon („… Nissan Kicks gegen Jeep" / „Grand Cherokee. Leider …").
  **Erkannt wird das an der LÄNGE der Zeilen, nicht an den Leerzeilen:**
  Hart umbrochener Text hat eine enge Verteilung — viele Zeilen enden dicht
  unter derselben Grenze. Gemessen an den Texten des Nutzers (50 % und 60 %
  lange Zeilen) gegen frei geschriebenen Text (33 %); die Schwelle liegt bei
  35 %, und wo sie nicht greift, bleibt der Text unangetastet. Eine Zeile
  setzt den Absatz fort, wenn die vorige bis an die Grenze reichte UND nicht
  mit einem Satzzeichen endete (oder die nächste klein anfängt).
- **Text ging beim Seitenumbruch verloren.** Auf Seite 5 endete ein Tag
  mitten im Satz („mussten von Passagieren, die"), der Rest war weg:
  `if kopf.isEmpty { text = "" }` — der „Notausgang" gegen eine
  Endlosschleife warf den Rest fort. Jetzt wird eine neue Seite begonnen,
  und passt der Text selbst auf einer leeren Seite nicht (zu große Schrift),
  läuft er SICHTBAR über. **Ein Tagebuch darf keinen Satz verlieren** — ein
  überlaufender Block fällt auf, ein fehlender Satz nicht.
- **Die Griffe waren da und nicht zu treffen** (`Views/Griffe.swift`).
  Gemeldet als „Ich kann ein Textfeld nicht in der Größe skalieren." Sie
  hingen als `.overlay` IM Block und ragten mit ihrer halben Breite über
  dessen Rahmen hinaus — **was außerhalb eines Frames liegt, nimmt in
  SwiftUI keinen Finger an**, und das nachgestellte
  `.contentShape(Rectangle())` beschnitt den Rest. Daraufhin lagen sie als
  eigene Ebene über der Seite. **Merke: Ein Bedienelement, das über seinen
  Elternrahmen hinausragt, gehört eine Ebene höher.** Der Satz gilt
  weiterhin — die DIAGNOSE war trotzdem nicht die Ursache, siehe der
  nächste Punkt.
- **Dieselbe Meldung ein zweites Mal — und die Erklärung von 1.0.2 war
  widerlegt** (ab 1.0.5, gemeldet 09/2026: „Leider kann ich die Bilder immer
  noch nicht verschieben oder skalieren. Und den Text kann ich zwar
  bearbeiten und drehen, aber die Anfasser an den Seiten lassen auch hier
  keine Änderung des Textfensters zu."). **Widerlegt durch die Meldung
  selbst:** Der DREHGRIFF liegt als einziger ganz außerhalb des
  Blockrahmens — und er ist der, der geht. Läge es am Hinausragen, wäre es
  genau andersherum. Eine Erklärung, die einmal geholfen hat, ist damit noch
  keine Ursache; das gehört gesagt, statt eine dritte Vermutung
  danebenzustellen (dieselbe Lehre wie beim Zoomen der Abfahrtstafel, wo
  zweimal eine Vermutung als Diagnose ausgegeben wurde).
- **Messen ging nicht, also wurden ALLE Verdächtigen auf einmal
  ausgeräumt** (ab 1.0.5). Es lagen mehrere übereinander, und keiner ließ
  sich ohne Gerät von den anderen trennen: der `Textkasten` (eine
  UIKit-Ansicht mitten im Block — die nimmt sich den Finger und gibt ihn
  nicht weiter), die Foto- und Kartenkachel, zwei Tipp-Gesten neben einer
  Ziehgeste an derselben Ansicht, und neun Griffe mit je eigener Geste, die
  einander überlappen. Jetzt gilt:
  - **Was in einem Block liegt, ist ein BILD** (`allowsHitTesting(false)`,
    am Textkasten zusätzlich `isUserInteractionEnabled = false`). Dieselbe
    Lehre wie bei der Netzkarte der Abfahrtstafel.
  - **Ein Block hat GENAU EINE Geste.** Sie entscheidet an der Stelle, an
    der der Finger aufsetzt, EINMAL, was gemeint war — sonst wechselte die
    Bedeutung mitten im Ziehen, sobald der Finger über einen anderen Griff
    wandert.
  - **Wo ein Griff liegt, steht an EINER Stelle** (`Grifflage.punkte`) und
    wird von Zeichnung UND Treffprüfung gelesen. Zwei Fassungen liefen
    auseinander, und dann läge der sichtbare Griff woanders als der
    wirksame — genau der Fehler, um den es hier geht.
  - **Die Trefferfläche ist ein eigener, größerer Rahmen und kein negativer
    Saum.** `padding(-saum)` liefe der Lehre von 1.0.2 genau entgegen.
  - **Eine Geste wird NICHT durch den Maßstab geteilt.** Sie wird in den
    eigenen Koordinaten der Ansicht gemeldet, an der sie hängt, und die
    liegen innerhalb des `scaleEffect` — also schon in Seitenpunkten. Bis
    1.0.4 wurde zusätzlich geteilt. Das ist die Lesart der Dokumentation und
    **keine Messung**; deshalb nennt die Probe Strecke und Maßstab.
- **Der Befund, der die Sache erklärt: auch das AUSWÄHLEN geht nicht**
  (gemeldet 09/2026, noch im selben Durchgang: „Es scheint wohl ein größeres
  Problem zu sein, denn ich habe mitunter auch Schwierigkeiten, Textblöcke
  auswählen zu können."). Damit ist es nicht die Geste, sondern schon der
  TIPP. Zwei Gründe, beide am Quelltext nachzurechnen:
  - **Ein Textblock ist FLACH.** Eine Datumszeile misst rund 14
    Seitenpunkte; eine A4-Seite wird auf einem iPhone mit gut halbem Maßstab
    gezeigt, also sieben Bildschirmpunkte. Apple nennt 44 als Mindestmaß für
    ein Fingerziel. **Eine Trefferfläche in Größe des Gezeichneten ist bei
    Text grundsätzlich zu klein** — unabhängig von jeder Gestenfrage, und
    das trifft die Textblöcke und sonst kaum etwas.
  - Die Gesten lagen übereinander (Punkt darüber).
- **Also: Ein Block ist eine ZEICHNUNG, die SEITE nimmt den Finger
  entgegen** (ab 1.0.5) — dieselbe Trennung wie bei der Netzkarte der
  Abfahrtstafel. Die Seite sucht HINTERHER, was gemeint war: erst genau,
  dann im Umkreis einer knappen Fingerbreite (`fangweite`, 20 Punkte),
  jeweils von oben nach unten, damit bei zwei übereinanderliegenden Blöcken
  der gewinnt, den man sieht. Damit kostet die Fangweite keine Fläche.
- **Die Ziehgeste liegt NUR über dem gewählten Block** samt Griffsaum, und
  das ist kein Detail: Die Seite steckt in einem `ScrollView`, und eine
  Ziehgeste über der ganzen Fläche nähme ihm das Blättern. Ein Tipp tut das
  nicht — deshalb **erst antippen, dann anfassen**; wo keine Auswahl ist,
  scrollt die Seite wie zuvor. **Die Tipps hängen mit auf dieser Fläche**,
  sonst käme über dem gewählten Block keiner mehr an (kein Abwählen, kein
  Doppeltipp für den Text). **Wer eine Geste über eine ganze Fläche legt,
  prüft, was diese Fläche sonst noch tut.**
- **Und weil sich das hier nicht messen lässt, misst es die App**
  (`Reisewerk.letzterGriff`, Buch → Satz → „Bedienung prüfen", ab 1.0.5).
  Eine Zeile über der Seite sagt nach jeder Ziehbewegung, was angekommen
  ist: welcher Griff, an welcher Blockart, wie weit in Millimetern, bei
  welchem Maßstab — und nach jedem Tipp, ob er einen Block getroffen hat
  oder ins Leere ging. Dasselbe Muster wie Schulalarms Stufenprobe und der
  Kartenmesser der Abfahrtstafel. **Nicht als erledigt darstellen**, bevor
  diese Zeile es sagt.
- **Verschieben ging, Größe ändern nicht — und der Unterschied IST die
  Erklärung** (ab 1.0.6, gemeldet 09/2026: „Bei Fotos und Textfeldern wird nun
  ein Verschieben zugelassen. Die Anpasser bewirken aber leider noch keine
  Größen- oder Formatänderung."). Verschoben wird erst am ENDE der Geste — bis
  dahin bewegt sich nur ein Versatz beim Zeichnen, der Rahmen bleibt. Die
  GRÖSSE ändert sich bei jedem Bildpunkt. Und an diesem Rahmen hing seit 1.0.5
  die Ziehfläche: Sie wuchs unter dem eigenen Finger mit, ihre lokalen
  Koordinaten wanderten mit, die gemeldete Strecke bezog sich auf einen
  anderen Ursprung als eben noch — und die Geste brach ab. Das Drehen war
  nicht betroffen, weil die Fläche nicht am Winkel hängt; auch das passt zum
  Befund. **Merke: Eine Fläche, die eine Geste TRÄGT, darf sich während dieser
  Geste nicht bewegen** — sie steht jetzt still (`ausgangsrahmen`), solange
  gezogen wird. Dazu erkennt die Geste am AUFSETZPUNKT, ob sie neu ist: Nach
  einem Abbruch bliebe sonst der alte Griff stehen, und die nächste Bewegung
  täte etwas, das niemand angefasst hat.
- **Die Erklärung von 1.0.6 war die fünfte und wieder daneben** (ab 1.0.7,
  gemeldet 09/2026: „Jetzt geht nicht mal mehr drehen. Die Anfasser sind zu
  sehen, aber egal, ob ich auf einen Anfasser tippe und halte oder auf das
  Foto selbst oder den Text, es wird immer nur verschoben."). Das ist der
  Befund, der sich RECHNEN lässt, statt ihn zu deuten: Die Geste kommt an
  (es wird ja verschoben), nur liefert `Grifflage.getroffen` nie einen Griff
  — also ist der PUNKT falsch, den sie bekommt, und nichts sonst. Und es galt
  auch schon in 1.0.5; dass das Drehen „jetzt auch nicht mehr" geht, heißt,
  dass es seit dem Umbau nie ging und erst jetzt ausprobiert wurde.
- **Eine Geste meldet ihren Punkt im Raum DERJENIGEN Ansicht, an der sie
  hängt** — und das war hier die Ziehfläche des gewählten Blocks: verschoben
  (`offset`), um einen Saum vergrößert, und seit 1.0.6 zusätzlich eine, die
  ihre Größe während des Ziehens ändert. Der Quelltext rechnete den
  gemeldeten Punkt deshalb auf die Seite um (`aufSeite`). Liegt der Ursprung
  dieses Raumes aber VOR dem Versatz, ist der Punkt schon ein Seitenpunkt und
  die Umrechnung addiert den Blockursprung ein zweites Mal — der Griffpunkt
  landet dann um den halben Block daneben, `getroffen` gibt `nil` zurück und
  `?? .verschieben` macht daraus stillschweigend ein Verschieben. Genau das
  Bild, das gemeldet wurde.
- **Welche der beiden Lesarten stimmt, lässt sich hier nicht messen — also
  wird die Frage abgeschafft.** Gemessen wird seit 1.0.7 in einem BENANNTEN
  Raum (`Seitenraum.name`, deklariert an der Seite selbst), und `DragGesture`
  wie Tipp bekommen ihn mit: `coordinateSpace: .named(…)`. Damit ist der
  Aufsetzpunkt dieselbe Zahl wie bei einem Tipp auf die Seite, unabhängig
  davon, an welcher Ansicht die Geste hängt und wie die verschoben ist.
  `aufSeite` ist ersatzlos gestrichen. **Merke: Wer einen Punkt aus einer
  Geste braucht, nennt den Raum, in dem er gilt — „lokal" ist eine Auskunft
  über den Ansichtsbaum und keine über die Seite.** Die Tipps an der Seite
  selbst bleiben bei `.local`: Diese Ansicht ist nicht verschoben, und das
  Auswählen über sie hat nachweislich funktioniert — es wird eine Sache auf
  einmal geändert.
- **Die Greifweite darf einen kleinen Block nicht ganz ausfüllen** (ab
  1.0.7, beim Nachrechnen gefunden). Sie war fest eine Fingerkuppe (24
  Bildschirmpunkte); bei einem Block von 60 x 40 Seitenpunkten liegt damit
  JEDER Punkt im Umkreis einer Ecke — er ließe sich nur noch in der Größe
  ziehen und nie mehr verschieben. Gedeckelt auf gut ein Drittel der
  kürzeren Seite, mit einem Boden, unter den es nicht geht. Bei einer
  flachen Datumszeile fallen obere und untere Kante trotzdem zusammen; dort
  gewinnt die Ecke, und die zieht beide Maße — bei vierzehn Punkten Höhe
  gibt es keine vier unterscheidbaren Kanten, und das ist Geometrie und
  keine Einstellung.
- **Die Probe nennt jetzt ZAHLEN** (`letzterGriff`, Buch → Satz → „Bedienung
  prüfen"): wo der Finger IM Block aufgesetzt hat, wie groß der Block ist,
  wie weit ein Griff greift. Bis 1.0.6 stand dort nur der gedeutete Name des
  Griffs — und der lautete in jedem Fall „Fläche", also genau das, was die
  Frage offenließ. **Eine Probe, die nur ihr Ergebnis nennt, ist die Frage
  von vorhin noch einmal.**
- **Was der Finger bewegt, wird SOFORT ins Modell geschrieben** (ab 1.0.8,
  gemeldet 09/2026: „Beim Verschieben bleibt grundsätzlich die Erfahrung
  bestehen. Warum wandert der nicht einfach mit?"). Bis 1.0.7 bewegte das
  Verschieben nur einen Versatz beim ZEICHNEN (`schiebt`/`zieht`); der Rahmen
  im Modell blieb stehen und wurde erst am Ende der Geste gesetzt. Drei
  Folgen, und alle drei waren zu sehen: Der Block lief dem Finger nach, die
  GRIFFE blieben zurück (die lesen den Rahmen), und brach die Geste ab, ohne
  dass `onEnded` kam, stand das Bild für immer neben seinem eigenen Rahmen —
  genau das zeigte das Bildschirmfoto des Nutzers. Die GRÖSSENÄNDERUNG machte
  es von Anfang an richtig, und genau die ging. **Eine zweite Wahrheit fürs
  Zeichnen läuft früher oder später auseinander.** Gerechnet wird dabei vom
  `ausgangsrahmen` aus und nie vom jetzigen: `translation` ist die ganze
  Bewegung seit dem Aufsetzen, und auf einen mitgewanderten Rahmen addiert
  liefe der Block davon.
- **`contentMode` einer selbst zeichnenden `UIView` MUSS `.redraw` sein**
  (`Textkasten`, ab 1.0.8, gemeldet 09/2026: „ein Textfeld, das in der Größe
  verändert wurde, [stellt] den Text verzerrt dar. Man muss erst auf eine
  andere Seite … wechseln"). Die Vorgabe ist `.scaleToFill`: Ändert sich der
  Rahmen, zeichnet UIKit NICHT neu, sondern zieht das zuletzt gezeichnete
  Bild auf die neue Größe — aus gesetztem Text wird eine gestauchte Grafik.
  Der Seitenwechsel half, weil er die Ansicht neu aufbaute. Das ist
  dokumentiertes UIKit-Verhalten und keine Vermutung; es trifft JEDE Ansicht
  dieses Repos, die in `draw(_:)` selbst zeichnet.
- **Zwei Finger vergrößern das BILD, die Griffe den RAHMEN** (`zoomgeste`, ab
  1.0.8, Wunsch des Nutzers 09/2026). Der Unterschied stand seit 1.0.0 im
  Papier (`Bildausschnitt`: „Wer ein Foto größer haben will, ändert den
  Rahmen; wer ein Gesicht in die Mitte rücken will, den Ausschnitt") — es
  fehlte der Griff dafür. Die Seite selbst wird nicht mit zwei Fingern
  gezoomt (dafür stehen die Lupen unten links), es gibt also nichts, womit
  sich die Geste streiten könnte.
- **`translation` und `magnification` sind die GESAMTE Bewegung seit dem
  Aufsetzen** (behoben in 1.0.8). `ausschnittSchieben` addierte sie bei jedem
  Bildpunkt auf den laufenden Wert — das Bild schoss unter dem Finger weg,
  und zwar immer schneller. Gerechnet wird vom Wert beim Aufsetzen
  (`ausgangsausschnitt`), wie überall sonst in dieser Ansicht.
- **Ein Textkasten sagt, wenn etwas herausfällt** (ab 1.0.8, gemeldet
  09/2026: „Leider kann es aber passieren, dass Text abgeschnitten wird …
  Das fällt zunächst nicht unbedingt auf."). Drei Dinge zusammen, und keines
  reicht allein:
  - **Er WÄCHST beim Tippen mit**, wie ein Textfeld in Pages
    (`hoeheAnTextAnpassen` am Ende von `textSchreiben`). Nur wachsen, nie
    schrumpfen — ein Kasten, der von selbst kleiner wird, nähme eine Größe
    weg, die jemand mit der Hand eingestellt hat.
  - **Wer ihn von Hand zu klein zieht, sieht eine MARKE** an der Unterkante
    (`Ueberlaufmarke`, orange, mit Pluszeichen — dieselbe Zeichensprache wie
    in Pages), dazu den Knopf „Rahmen an Text anpassen" in der Fußleiste und
    im Inspektor. Ein Hinweis ohne Weg, ihn aufzulösen, ist die Frage von
    vorhin noch einmal.
  - **Die Druckprüfung zählt das GANZE Buch** (`abgeschnittenerText`). Die
    Marke sieht nur, wer gerade auf dieser Seite ist; ein fehlender Satz
    fällt sonst erst auf, wenn das Buch gedruckt ist.
  **Der Befund ist GESPEICHERT, nicht gerechnet** (`Reisewerk.textUeberlauf`):
  Dahinter steckt ein voller CoreText-Satz, und als berechnete Eigenschaft
  liefe der bei jedem Neuzeichnen der Seite mit — dieselbe Falle wie bei der
  Netzkarte der Abfahrtstafel. Gemessen wird an EINER Stelle, wenn sich
  Auswahl, Rahmenmaße oder Textlänge ändern.
- **Zwei Zeichner für denselben Inhalt zeigen nie dasselbe** (ab 1.0.9,
  gemeldet 09/2026: „Sobald ich einen Doppeltipp auf den Text ausübe,
  erscheint das Textfeld dupliziert, übereinander liegend"). Beim Bearbeiten
  lag das `InlineText`-Feld (UIKit/TextKit) ÜBER dem weiter gezeichneten
  Block (CoreText). Dieselben Wörter, zwei Umbruchmaschinen — die brechen
  nie an derselben Stelle. Der bearbeitete Block wird deshalb nicht mehr
  zusätzlich gezeichnet.
- **Ein Zustand ohne sichtbaren Ausgang ist ein hängengebliebenes Programm**
  (ab 1.0.9). Das Textfeld ließ sich nur schließen, indem man DANEBEN tippte
  — und traf man dabei einen anderen Textblock, ging sofort das nächste Feld
  auf. Jetzt liegt eine unsichtbare Fläche hinter dem Feld, die es schließt
  und den Tipp nicht weiterreicht, dazu der Knopf „Text fertig" in der
  Fußleiste. **Wer einen Modus baut, baut den Ausgang mit — und zwar
  sichtbar.**
- **Wie sich Fotos abheben, gehört dem BUCH** (`Gestaltung.fotoschatten`,
  `.fotorand`, `.fotorandbreite`, `.fotorandfarbe`, ab 1.0.9, Ansage des
  Nutzers 09/2026: „Ich möchte die Einstellung, wie die einzelnen Fotos sich
  abheben sollen … global einstellen können."). Bis 1.0.8 schrieb der
  Layoutautomat Schatten und weißen Rand in JEDEN Fotoblock — danach war die
  Einstellung nicht mehr zu ändern, ohne zweihundert Fotos einzeln
  anzufassen. Am Block stehen sie seither als **Abweichung** (`nil` = wie im
  Buch), genau wie `Schriftabweichung`; aufgelöst wird an EINER Stelle
  (`Block.wirkung`), die Bildschirm UND PDF gemeinsam fragen. Der Stil setzt
  das Buch, nicht die Blöcke. Ein Knopf in der Gestaltung nimmt alle
  Abweichungen zurück.
- **Eine Eigenschaft, die als Wert gedacht war, wird durch `nil` zur
  Abweichung — ohne dass alte Dateien brechen.** Der erzeugte
  `Codable`-Leser verlangt einen Schlüssel nur für NICHT-optionale
  Eigenschaften; ein vorhandener Wert wird gelesen, ein fehlender wird
  `nil`. Deshalb war der Umbau von `schatten`/`fotorand`/`randbreite` auf
  optional gefahrlos — im Gegensatz zum umgekehrten Weg.
- **Derselbe Text zweimal auf einer Seite ist ein DRUCKFEHLER**
  (`Druckpruefung.doppelterText`, ab 1.0.9). Auf dem Bildschirm sieht das
  aus wie eine Unsauberkeit der Anzeige; gedruckt sind es zwei Absätze.
  **Woher ein zweiter Kasten kommt, ist damit nicht beantwortet** — die
  Prüfung macht ihn nur unübersehbar und nennt den Weg, ihn zu entfernen.
  Nicht als geklärt darstellen.
- **Viermal derselbe Befund: „Es war da, man fand es nicht"** (ab 1.0.10,
  gemeldet 09/2026: „Kann ich das jetzt für alle Fotos global einstellen und
  wenn ja, wo? Irgendwie ist die App nicht intuitiv zu bedienen."). Die
  Foto-Einstellung war in 1.0.9 gebaut — sie lag hinter **Buch → „Format,
  Ränder, Karte…"**, also hinter einem Menüpunkt, der nach Papiermaßen
  klingt. Derselbe Befund wie bei der Bildunterschrift (1.0.6), beim
  Zurücksetzen in Tafelbild und beim Gruppenchat in Schulalarm. **Ein
  Menüpunkt, der nicht sagt, was dahinter liegt, ist so wenig wert wie ein
  Knopf, den niemand findet.** Deshalb heißt der Eintrag jetzt schlicht
  **„Fotos…"** und steht eigenständig im Buch-Menü, gleich unter Stil und
  Schrift — dort, wo die Frage gestellt wird.
- **Die Felder stehen EINMAL da und werden an zwei Stellen gezeigt**
  (`Views/Fotostil.swift`, `Fotostilfelder`). Das eigene Blatt (Buch →
  Fotos) und die Unterseite der Gestaltung, wo sie bisher lagen, zeigen
  dieselbe Ansicht. Zwei Fassungen desselben Formulars liefen auseinander —
  dieselbe Regel wie bei `Block.wirkung`, die Bildschirm und PDF gemeinsam
  fragen.
- **Der Weg vom Einzelfall zum Ganzen steht im Inspektor** (ab 1.0.10). Wer
  ein Foto gewählt hat und dessen Wirkung ändern will, ist genau die Person,
  die die Frage „und für alle?" stellt. Im Abschnitt „Wirkung" führt deshalb
  ein Knopf ins Buch-Blatt; seine Beschriftung sagt, wo man steht („Für alle
  Fotos einstellen" oder „Dieses Foto weicht ab — für alle einstellen"),
  und „Wieder wie im Buch" nimmt die Abweichung zurück. Dafür reicht
  `ReiseView` sein `blatt` als `@Binding` in den Inspektor durch: Ein
  zweites Blatt über dem Inspektor wäre eine zweite Ebene für dieselbe
  Einstellung.
- **Gesten sind unsichtbar — also stehen sie aufgeschrieben**
  (`Views/BedienungView.swift`, ab 1.0.10). Eine Buchseite ist seit 1.0.5
  eine ZEICHNUNG, und jeder Griff daran ist eine Geste: Tipp, Doppeltipp,
  Ziehen am Punkt, zwei Finger. Nichts davon sieht man. Die Karte hinter dem
  **„?" unten in der Leiste** zählt auf, was geht und wo was eingestellt
  wird; sie erklärt nichts, denn wer sie öffnet, sucht etwas Bestimmtes.
  **Wer eine neue Geste einbaut, trägt sie dort ein** — eine Geste, die dort
  fehlt, gibt es für den Menschen davor nicht.
- **„Satz" heißt jetzt „Anordnen"** (ab 1.0.10). „Satz" ist das Fachwort für
  das, was der Layoutautomat tut; gesucht wird es von jemandem, der eine
  Seite neu verteilt haben will. Ein Menü, das die Aufgabe nennt statt des
  Handwerks, findet man ohne Vorwissen.
- **Nicht gemessen: ob die App sich jetzt anders anfühlt.** Was gemessen ist,
  sind Wege — die Einstellung liegt eine Ebene höher und heißt nach ihrer
  Sache, die Gesten stehen an einer Stelle. Ob das reicht, sagt erst der
  nächste Befund des Nutzers. **Eine Oberflächenänderung als gelöstes
  Bedienproblem auszugeben wäre genau die Art Behauptung, die dieses Papier
  sonst verbietet.**
- **Ein Knopf, der etwas ZURÜCKNIMMT, setzt voraus, dass es einen Weg hin
  gibt** (`Views/KartenausschnittView.swift`, ab 1.0.11, gemeldet 09/2026:
  „Auf der Karte wird ja quasi nichts dargestellt. Der Ort könnte sonst wo
  sein."). `Reisetag.kartenausschnitt` gibt es seit 1.0.0 — und bis 1.0.10
  konnte ihn NIEMAND setzen: Im Inspektor stand einzig „Wieder automatisch
  rahmen". Gerahmt wurde deshalb immer selbsttätig um die Spur, und für die
  rechnet `Kartenwerk.region` bei einem einzigen Punkt eine Spanne von
  0,008 Grad — rund 900 Meter. Die Karte war also nicht falsch, sie war zu
  nah, und zwar ohne jeden Ausweg. **Ein Feld, das nur gelesen und nie
  geschrieben wird, ist ein halb gebautes Vorhaben** — dieselbe Art Befund
  wie bei der Bildunterschrift in 1.0.5.
- **Gewählt wird auf einer ECHTEN Karte, und übernommen wird das FENSTER.**
  Kein Fadenkreuz wie bei der Ortswahl: Dort wird eine Stelle gewählt, hier
  ein Ausschnitt. Dazu „näher" und „weiter" unmittelbar im Inspektor — wer
  nur etwas herauszoomen will, soll dafür keinen Bildschirm öffnen müssen.
  Beide rechnen vom GELTENDEN Ausschnitt aus, also auch vom automatischen;
  sonst spränge der erste Tipp auf einen Wert, der mit dem Bild auf der
  Seite nichts zu tun hat. Die Spanne steht in Kilometern da (ein Grad
  Breite ≈ 111 km) — eine Gradzahl sagt niemandem etwas.
- **Beschriftungsdichte gibt es bei MapKit NICHT — es gibt einen POI-Filter**
  (`Kartenbeschriftung`, ab 1.0.11). Gewünscht war, „wie dicht die
  Beschriftungen sein sollen". Was sich wirklich einstellen lässt, ist
  `pointOfInterestFilter`: Geschäfte, Museen, Haltestellen. Straßen- und
  Ortsnamen setzt Apple selbst nach Maßstab, und dafür gibt es keine
  Schraube — wer weniger davon will, nimmt die Karte näher heran. **Genau
  das steht in der Oberfläche**, statt einen Regler anzubieten, der nichts
  tut. Beim SATELLITENBILD entscheidet die Wahl sogar über die Art des
  Aufbaus: `MKImageryMapConfiguration` zeigt überhaupt keine Namen, die
  gibt es nur über `MKHybridMapConfiguration`. Bei den Kachelquellen ist die
  Beschriftung fertig IM BILD — das sagt die App dort auch.
  Geändert gegenüber 1.0.10: „Gelände" schaltete die Orte fest ab; das war
  als Stilfrage gebaut und ist jetzt eine eigene Einstellung.
- **`.castle` und `.landmark` gibt es erst ab iOS 18.** Sie wären für eine
  Reisekarte die naheliegenden Kategorien und kosteten einen Bau: Diese App
  baut gegen iOS 17, und ein `@available` für eine Zierde wäre der falsche
  Preis.
- **Ein neues NICHT-optionales Feld macht jede gesicherte Datei unlesbar —
  auch in einem kleinen Typ.** `Kartenbild` bekam `beschriftung` und braucht
  deshalb seit 1.0.11 einen Leser von Hand (`Model/Nachsicht.swift`). Beim
  Gegenlesen gefunden, nicht im Bau: `Reisetag` liest sein `kartenbild` über
  `wahlweise`, und das schluckt den Fehler — die Karteneinstellung wäre
  STILL auf die Vorgabe zurückgefallen. **Die Regel steht seit 1.0.3 im
  Papier und galt bis dahin nur für `Reise` und `Reisetag`; sie gilt für
  jeden Typ, der wächst.**
- **Einrasten sagt jetzt, WORAN** (`Einrasten.Fang`, `Fanglinie`, ab 1.0.11,
  Ansage des Nutzers 09/2026: „Der Randindikator soll sich an den Rand und
  die Fotos orientieren, aber im Einzelfall auch veränderbar sein."). Bis
  1.0.10 rastete der Block stumm ein: Er sprang um zwei Punkte, und ob das
  der Satzspiegel war, die Schnittkante, das Foto darüber oder gar nichts,
  stand nirgends. **Eine Hilfe, die man nicht sieht, ist für den Menschen
  davor ein Zucken.** Gezeichnet wird eine Linie über den ganzen Bogen, mit
  der Herkunft als Wort und als Farbe — „Rand" und „Nachbar" sind zwei
  verschiedene Auskünfte.
- **Die Kanten kommen aus EINER Quelle** (`Einrasten.kanten`). Bis 1.0.10
  baute das Verschieben seine Liste selbst und das Größenändern eine zweite,
  und nur die zweite kannte die Schnittkante: Ein randabfallendes Foto rastete
  beim Ziehen an der Ecke am Anschnitt ein und beim Verschieben nicht.
- **„Im Einzelfall veränderbar" sind zwei Dinge**: der Schalter „An Rand und
  Nachbarn einrasten" unter „Anordnen" (wer ihn ausmacht, bekommt auch keine
  Linien — eine Linie ohne Wirkung wäre eine Behauptung) und die Zahl in
  Millimetern im Inspektor unter „Lage auf der Seite". Der Schalter liegt in
  `@AppStorage` und damit in einer VIEW, nie im `Reisewerk`.
- **Der Absatzabstand war da, die ERKLÄRUNG fehlte** (ab 1.0.11, gemeldet
  09/2026: „Nach wie vor weiß ich nicht, warum bei dem Text nach jedem Absatz
  so viel Platz gelassen wird."). Buchweit steht er seit 1.0.0 unter Buch →
  Schrift. Was fehlte, war zweierlei: die Ausnahme an der einzelnen Stelle
  (`Schriftabweichung.absatzabstand`) und der Grund. Der Grund steht im Text
  selbst: In einem hart umbrochenen Tagebuchtext ist JEDE ZEILE ein eigener
  Absatz, und dann steht der Abstand eben nach jeder Zeile. **Der Inspektor
  zählt die Absätze deshalb und bietet das Zusammenführen an der Stelle an,
  an der die Frage entsteht** (`Textaufbereitung.erzwingen`). Eine Zahl, die
  den Befund erklärt, ist mehr wert als ein Regler, der ihn verdeckt.
  **Offen bleibt, warum die Erkennung aus 1.0.2 bei diesem Text nicht
  gegriffen hat** — gemessen ist sie an zwei Texten des Nutzers, und der
  gemeldete ist ein dritter. Nicht als geklärt darstellen.
- **Ein Textkasten darf einen Grund haben, und der darf durchscheinen**
  (`Block.grund`, `Block.innenabstand`, ab 1.0.11, Ansage des Nutzers
  09/2026: „So könnte beispielsweise auch Text auf einem Hintergrundbild
  gemacht werden."). Den farbigen Grund gab es; was fehlte, waren die zwei
  Dinge, die ihn brauchbar machen:
  - **Die Deckkraft als eigener Schieber.** `Farbwert` trägt sie seit 1.0.0,
    und der Farbwähler von iOS kann sie — aber hinter einem Tipp auf das
    Farbfeld, und wer sie sucht, findet sie nicht. Sie ist hier kein Schmuck,
    sondern der Zweck: Ein halbdurchsichtiges Feld lässt ein Foto durch und
    die Schrift trotzdem lesbar bleiben.
  - **Ein Innenabstand.** Schrift, die unmittelbar an der Kante einer Fläche
    anfängt, sieht aus wie ein Satzfehler. Er wird beim Einschalten des
    Grundes gesetzt und beim Ausschalten NICHT zurückgenommen — wer ihn von
    Hand geändert hat, soll ihn behalten.
- **Ein Innenabstand muss an ALLEN VIER Textstellen mitgerechnet werden**:
  auf dem Bildschirm (`Textkasten`), im PDF (`Buchausgabe`), bei der
  Überlaufmessung (`Reisewerk.fehlendeHoehe`) und in der Druckprüfung.
  Gerechnet wird er an einer Stelle (`Block.textrechteck` / `textbreite`);
  vergäße man eine der vier, sagte die Marke „passt", während im Druck eine
  Zeile fehlt. Das Textfeld beim Bearbeiten bekommt denselben Wert als
  `textContainerInset` — sonst spränge der Text beim Doppeltipp an die Kante
  und beim Schließen wieder zurück.
- **Nicht gemessen:** wie sich das alles auf einem Gerät anfühlt. Gemessen
  sind Wege und Rechnungen; ob die Fanglinie beim Schieben hilft oder stört
  und ob der gewählte Kartenausschnitt im Druck das Erwartete zeigt, sagt
  erst der nächste Befund.
- **Ein `UIViewRepresentable` ohne `sizeThatFits` bestimmt seine Größe SELBST**
  (`TextflaecheBruecke`, ab 1.0.12; gemeldet 09/2026, zum zweiten Mal: „Das
  Bearbeiten des Textes im Kasten funktioniert noch nicht richtig. Wieder wird
  beim Doppeltipp der Text außerhalb des Rahmens dargestellt."). 1.0.9 hatte
  die DOPPELUNG behoben (der Block wird nicht mehr zusätzlich gezeichnet) und
  den Überstand stehen lassen — zwei Befunde in einem Bild, und nur einer war
  gelesen. Die Rechnung dahinter ist am Quelltext nachzuzählen und keine
  Vermutung: Das Feld ist ein `UITextView` mit `isScrollEnabled = false`, und
  so eines meldet die Größe, die sein Text BRAUCHT, nicht die, die es bekommt.
  Ohne `sizeThatFits` nimmt SwiftUI genau diese Zahl — und **`.frame()`
  beschneidet nicht, es stellt ein zu großes Kind MITTIG hin**. Genau so sah
  das Bildschirmfoto aus: der Text über die halbe Seite, mittig auf dem
  orangen Rechteck, die Absätze zu drei sehr langen Zeilen geworden.
  Zurückgegeben wird jetzt die angebotene BREITE (nie mehr) und die HÖHE, die
  der Text darin braucht; ausgerichtet wird oben links, und die Höhe hängt an
  `.frame(minHeight:)` statt an einer festen — so wächst der Kasten beim
  Tippen nach unten, wie in Pages, statt Zeilen zu verschlucken. **Merke: Wer
  eine UIKit-Ansicht in SwiftUI einhängt, sagt ihr, wie groß sie sein darf.**
- **Textfelder lassen sich buchweit einstellen** (`Gestaltung.textgrund`,
  `.textinnenabstand`, `.textrandbreite`, `.textrandfarbe`, `.textschatten`,
  Blatt „Buch → Textfelder…", ab 1.0.12, Ansage des Nutzers 09/2026: „Kann ich
  global einstellen, wie die Einstellungen für die Textfelder sein sollen? Ich
  möchte das können."). Dieselbe Bauweise wie bei den Fotos in 1.0.9/1.0.10 und
  aus demselben Grund: **Abweichung, keine Kopie** — `nil` am Block heißt „wie
  im Buch", aufgelöst an der einen Stelle (`Block.wirkung`), die Bildschirm UND
  PDF fragen. Zwei getrennte Sätze für Foto und Text, nicht einer: Ein
  Textkasten mit dem Schatten aller Fotos wäre eine Überraschung, und wer den
  weißen Sofortbild-Rand seiner Bilder hochzieht, meint nicht die Schrift.
- **„Nichts gesetzt" und „hier ausdrücklich keiner" sind NICHT dasselbe**
  (`Block.ohneGrund`, ab 1.0.12). Solange es nur den Block gab, hieß
  `grund == nil` beides auf einmal. Sobald das Buch einen Grund vorgibt, fällt
  das auseinander: Der Schalter „Farbiger Grund" ginge aus, der Grund käme vom
  Buch zurück, und für den Menschen davor wäre der Schalter kaputt — dieselbe
  Lehre wie bei „Ein Knopf, der schweigt". **Wer eine buchweite Vorgabe
  nachrüstet, prüft, ob sich das Abschalten noch sagen lässt.**
- **`Gestaltung`, `Block` und `Seite` lesen sich seit 1.0.12 von Hand**
  (`Model/Nachsicht.swift`). Die Regel stand seit 1.0.3 im Papier und galt für
  `Reise` und `Reisetag`; die Typen DARUNTER hatten sie nicht, und genau in
  ihnen wuchs diese Fassung. Was das gekostet hätte, ist auszurechnen:
  `Reise` holt die Gestaltung über `b.wert(.gestaltung, Gestaltung())` — ein
  neues Feld dort hätte in jedem vorhandenen Buch **Format, Ränder, Bundsteg,
  Anschnitt und Fotowirkung** auf die Vorgaben zurückgesetzt, still, denn das
  Buch öffnet sich ja. Und ein neues Feld in `Block` hätte über
  `seiten = b.wert(.seiten, [])` die ganze Seitenliste eines Tages
  mitgenommen, also die Handarbeit eines Abends. **Jeder Typ, der wächst,
  bekommt seinen Leser, bevor er wächst.**
- **Der Umbruch ist eine Eigenschaft der DATEI, nicht des Tages**
  (`Textaufbereitung.vermessen`, ab 1.0.12; gemeldet 09/2026: „Der Textimport
  hat offenbar am Ende jeder Zeile einen Absatz erzeugt. Ich frage mich, ob das
  an meiner Vorlage lag … oder ob der Textinterpreter nicht richtig
  funktioniert."). Er hat nicht richtig funktioniert, und die Rechnung sagt
  auch, warum. **Nachgerechnet am gemeldeten Tag** (4. Juni 2026, sieben Zeilen
  von 46, 102, 104, 56, 43, 31 und 16 Zeichen): `laengste` = 104, `grenze` = 88,
  und nur zwei der sieben Zeilen erreichen sie — 29 % gegen eine Schwelle von
  35 %. Die Erkennung stand also still, obwohl die Vorlage hart umbrochen war.
  Gemessen wurde bis 1.0.11 je Tag (`Textimport.lesen` ruft `pruefen` in
  `abschliessen()`, also einmal je Abschnitt), und ein kurzer Tag endet nun
  einmal mit einer kurzen Zeile — je kürzer der Tag, desto schwerer wiegt sie.
  Wo die Umbruchspalte lag, hat der Schreiber aber EINMAL für die ganze Datei
  entschieden. Gemessen wird deshalb einmal über den gesamten Text und das
  Ergebnis an jeden Tag weitergereicht. **Merke: Bevor eine Schwelle als zu
  streng gilt, prüfen, ob sie am richtigen Gegenstand gemessen wird.**
- **Zwei Zeichen entscheiden unabhängig von der Länge** (`Textaufbereitung.fortsetzt`).
  Beide stehen im gemeldeten Text: ein **Bindestrich am Ende** der vorigen Zeile
  („Boeing 747-" / „400") ist ein zerrissenes Wort, und ein **Komma am Anfang**
  dieser Zeile („, zurück nach Frankfurt") kann kein Absatzanfang sein. Eng
  gefasst mit Absicht — „fängt klein an" allein reicht NICHT: In einem frei
  geschriebenen Text gibt es kleingeschriebene Absatzanfänge, und ein zu
  Unrecht zusammengezogener Absatz ist der teurere Fehler, weil er im
  gedruckten Buch nicht mehr zu sehen ist.
- **Die Zahlen stehen im Einlesen-Blatt, und auch der Fall „nichts getan" sagt
  es** (ab 1.0.12). Längste Zeile, Anteil, Zeilenzahl, Schwelle und das
  Ergebnis — und je Tag steht die Zeile jetzt auch dann da, wenn NICHT
  zusammengeführt wurde. Das ist die Antwort auf die Frage, mit der dieser
  Durchgang anfing: „lag das an meiner Vorlage oder am Textinterpreter?" Eine
  Erkennung, die schweigt, wenn sie nichts tut, lässt einen raten. Gemerkt wird
  das Maß in `@State` und nicht als berechnete Eigenschaft — der Lauf geht über
  jede Zeile, und das Blatt zeichnet sich bei jedem Tastendruck neu (dieselbe
  Falle wie bei der Netzkarte der Abfahrtstafel).
- **`Farbwert(_:deckung:)` hält die Deckkraft fest** (ab 1.0.12, beim
  Gegenlesen gefunden). Der Farbwähler steht auf `supportsOpacity: false` und
  gibt deshalb IMMER volle Deckung zurück; seit 1.0.11 steht daneben ein
  eigener Deckkraft-Schieber — jeder Griff an die Grundfarbe setzte ihn also
  stillschweigend auf 100 % zurück. Genau das, wofür der Schieber gebaut wurde
  (Text auf einem Hintergrundbild), war damit nach einem Farbwechsel weg.
- **Nicht gemessen:** ob das Textfeld beim Doppeltipp jetzt wirklich im Rahmen
  steht. Gerechnet ist, WARUM es überstand (ein Kind ohne Maßangabe, ein
  `.frame`, das nicht beschneidet); gesehen hat es niemand. Ebenso ungemessen
  bleibt, ob die Umbruch-Erkennung an der Vorlage des Nutzers jetzt greift —
  sie ist an seinen Zahlen nachgerechnet, und die Datei selbst liegt hier
  nicht. **Beides nicht als erledigt darstellen**, bevor der nächste Befund es
  sagt.
- **Was eine Datei IST, sagen die ersten Bytes — nicht die Endung**
  (`Dienste/Textquelle.swift`, ab 1.0.13, Wunsch des Nutzers 09/2026: „Ich
  möchte Texte im Word-Format, PDF oder reinen Text eingeben können."). Bis
  1.0.12 nahm der Textimport nur eine Textdatei; wer sein Tagebuch in Word
  geschrieben hatte, musste es erst irgendwo hindurchkopieren. Alles, was eine
  Datei in Text verwandelt, steht jetzt an EINER Stelle — der Bildschirm ruft
  eine Funktion und bekommt einen Befund; ob dahinter PDFKit, ein ZIP-Leser
  oder eine Kodierungsleiter steckt, weiß er nicht. **Dieselbe Lehre wie in
  Textauszug**, wo sechs Kilobyte HTML mit `.pdf` im Namen ankamen: Eine
  Endung ist eine Behauptung, die ersten Bytes sind eine Tatsache. Die Endung
  entscheidet nur da, wo die Bytes nichts sagen — bei reinem Text.
- **PDF liest PDFKit, und was es NICHT hergibt, ist die Lage der Zeilen**
  (`Dienste/Pdftext.swift`, ab 1.0.13). Textauszug muss seinen PDF-Leser
  selbst schreiben, weil im Browser keiner mitgeliefert wird; auf iOS gehört
  einer zum System, und ihn nachzubauen wäre dieselbe Arbeit noch einmal samt
  einer zweiten Fehlerquelle. Der Preis ist die Kopfzeilenerkennung: Dort
  misst der ABSTAND zum Satzspiegel, hier bleibt nur der Text je Seite.
  Erkannt wird deshalb die **Wiederholung** — eine Zeile, die auf den meisten
  Seiten ganz oben oder ganz unten steht und sich nur in ihren Ziffern
  unterscheidet (`marke` ebnet Zifferngruppen zu `#` ein, sonst käme „Seite 3
  von 30" nie zweimal vor). **Das ist ein anderes Merkmal und wird auch anders
  falsch**: Ein Buch mit wiederkehrendem Refrain als erster Zeile verlöre ihn.
  Deshalb steht hinterher WÖRTLICH da, was entfernt wurde — eine Zahl („2
  Zeilen entfernt") wäre keine Auskunft, sondern eine Behauptung. Unter drei
  Seiten wird gar nichts entfernt, und eine Zeile über 90 Zeichen gilt als
  Fließtext.
- **Ein Scan und eine kennwortgeschützte PDF sagen je EINEN Satz**, der den
  Weg drumherum nennt — dieselbe Regel wie in Textauszug. Die Scan-Grenze ist
  gemessen und nicht gefühlt: unter zwanzig Nicht-Leerzeichen je Seite ist
  kein Text mehr da, sondern nur noch Versprengtes aus einer Textebene.
- **Eine `.docx` ist ein ZIP, und auf iOS gibt es keinen Entpacker**
  (`Dienste/Zipleser.swift`, `Dienste/Wordtext.swift`, ab 1.0.13). Dieselbe
  Lücke, wegen der `Buchdatei` ein eigenes Format schreibt. Ausgepackt wird
  über Apples `Compression`: **`COMPRESSION_ZLIB` ist dort das ROHE DEFLATE
  nach RFC 1951**, und genau das steht in einem ZIP — ohne zlib-Kopf und ohne
  Prüfsumme davor; dieselbe Überlegung wie `DecompressionStream('deflate-raw')`
  in Textauszug. Gelesen wird über das **zentrale Verzeichnis** am Ende und
  nicht durch Vorwärtssuche nach lokalen Köpfen: `PK\u{03}\u{04}` kann auch
  mitten in gepackten Daten stehen. Und die Namens- und Extralängen kommen aus
  dem **lokalen** Kopf, nicht aus dem Verzeichnis — Word schreibt dort andere
  Extrafelder, und wer die Zahlen von der falschen Stelle nimmt, landet ein
  paar Bytes neben den Daten.
- **`NSAttributedString` kann `.docx` auf iOS NICHT.** Sein
  `officeOpenXML`-Dokumenttyp gibt es nur auf dem Mac; der Weg über `.html`
  startet intern WebKit, muss auf den Hauptfaden und liest eine `.docx`
  ohnehin nicht. RTF dagegen kann es wirklich und ohne WebKit — deshalb bleibt
  genau dieser eine Weg bei Apple.
- **Aus `word/document.xml` wird NUR `w:t` in einem `w:r` gelesen.**
  `w:instrText` trägt Feldbefehle („HYPERLINK \\l …"), `w:delText` den
  gelöschten Text aus der Nachverfolgung — beides stünde sonst im Tagebuch.
  Dazu zwei Fallen: **`w:tab` gibt es zweimal** (im Lauf als Zeichen, in den
  Absatzeigenschaften als Definition eines Tabstopps — nur das erste ist
  Text), und **„p" und „t" gibt es auch in DrawingML**, also in Schaubildern;
  gezählt wird deshalb der Namensraum und nicht der nackte Name. Ein `w:br`
  wird zur ZEILE und nicht zum Absatz: Das ist genau der hart umbrochene Text,
  den `Textaufbereitung` seit 1.0.12 wieder zusammenführt.
- **Die alte `.doc` wird an ihrer Kennung erkannt und abgewiesen.** Sie ist
  kein ZIP, sondern ein zusammengesetztes Dokument von 1997
  (`D0 CF 11 E0 A1 B1 1A E1`); ohne diese Prüfung meldete der Zipleser „kein
  ZIP-Archiv" — wörtlich richtig und für den Menschen davor wertlos. Der Satz
  nennt jetzt den Weg: in Word öffnen, als `.docx` sichern.
- **Die Reihenfolge der Kodierungen IST die Sache** (`Textquelle.reinerText`,
  ab 1.0.13). `isoLatin1` nimmt JEDES Byte an und scheitert nie — bis 1.0.12
  stand es vor `windowsCP1252`, und damit war der CP1252-Zweig unerreichbarer
  Quelltext: Die Bytes 0x80 bis 0x9F einer Windows-Datei (also „ “ – …) wurden
  zu unsichtbaren Steuerzeichen, ohne eine einzige Fehlermeldung. Gelesen wird
  jetzt: Byte-Vorzeichen zuerst (eine UTF-16-Datei kam vorher als Salat mit
  Nullbytes an), dann UTF-8, dann Windows-1252, dann ISO 8859-1 als letzte
  Rettung. **Merke: Ein Decoder, der nie scheitert, darf nie vor einem stehen,
  der scheitern kann.**
- **Der Bildschirm sagt, was angekommen ist** — Art, Dateiname, Seiten,
  Absätze, Kodierung, Zeichenzahl, dazu die entfernten Randzeilen. Dieselbe
  Regel wie beim Einfuhrbericht der Fotos: Ein stummer Import lässt die Frage
  offen, ob überhaupt die richtige Datei gewählt wurde.
- **Nicht gemessen:** Keine der vier Wege ist an einer echten Datei des
  Nutzers gelaufen — hier gibt es weder Word noch PDFKit. Gerechnet ist der
  Aufbau (ZIP-Verzeichnis, DEFLATE-Sorte, welche Word-Elemente Text tragen,
  welche Kodierung wann scheitert); ob eine bestimmte `.docx` oder PDF
  durchgeht, sagt erst der nächste Befund. **Nicht als erledigt darstellen.**
- **Der Umbruch sucht ZUERST einen Absatz** (`Textmass.teilenMitArt`, ab 1.0.14,
  Ansage des Nutzers 09/2026: „Sodass Texte, die in der angegebenen Schriftgröße
  zu groß für eine Seite sind, automatisch auf einer weiteren Seite fortgesetzt
  werden. Dabei wäre es schön, wenn an einem bestehenden Absatz umgebrochen
  wird."). Fortgesetzt wurde schon vorher — geteilt wurde aber an der
  WORTgrenze, also mitten im Gedanken. Jetzt wird vor der Wortgrenze die letzte
  Absatzgrenze gesucht, die noch auf die Seite passt.
  - **Der Absatz gewinnt nicht um jeden Preis.** Steht die letzte Grenze weit
    oben — ein einziger langer Absatz füllt den Rest —, bliebe unten eine große
    weiße Fläche stehen, und die sieht nach Abbruch aus. Gemessen wird deshalb,
    wie hoch der Kopf bis zu dieser Grenze WIRD (`Textmass.hoehe`, also
    CoreText, nicht die Zeichenzahl), und verglichen mit dem Platz, den es gibt.
    Unter 62 Prozent Füllung bleibt es bei der Wortgrenze. **Die Zahl ist
    gewählt und nicht gemessen** — sie lässt höchstens gut ein Drittel Seite
    frei.
  - **Ein Absatz ist der ZEILENWECHSEL**, nicht die Leerzeile. `Schriftbild`
    setzt den Absatzabstand als `paragraphSpacing`, und CoreText zählt dafür
    genau dieselbe Grenze; zwei Meinungen darüber, wo ein Absatz aufhört, wären
    zwei verschiedene Umbrüche. Mitgelesen werden U+2028 und U+2029 — die
    stehen in Texten aus Word und aus PDFs und wären sonst unsichtbar.
- **Fotos warten nicht mehr, bis der Text fertig ist** (`Layoutautomat.reihenSetzen`,
  ab 1.0.14). Bis 1.0.13 füllte der Text auf jeder Folgeseite die ganze Höhe;
  ein Tag mit langem Text und vielen Bildern ergab erst mehrere reine
  Textseiten und danach reine Fotoseiten — das Bild zum Erzählten stand drei
  Seiten weiter. **Freigehalten wird die GEMESSENE Höhe der nächsten Fotoreihe**
  (`naechsteReihe` rechnet sie ohnehin aus) und kein geschätzter Anteil: Ein
  Anteil, der zu klein ist, lässt die Reihe doch nicht hinein, und dann bliebe
  unten weißer Platz, den niemand bestellt hat. Passen nach der Reihe keine
  sechs Zeilen Text mehr auf die Seite, wird gar nichts freigehalten — eine
  Seite mit vier Zeilen über einem Bild ist kein Satz, sondern ein Rest. Ist
  kein Foto mehr offen, gilt wieder die ganze Seite.
- **Einen Textkasten von Hand teilen** (`Reisewerk.textTeilen`, ab 1.0.14,
  Ansage des Nutzers 09/2026: „Im Nachhinein möchte ich eine Textbox
  gegebenenfalls teilen können und sie manuell auf einer weiteren Seite
  fortführen können."). Zwei Wege, weil es zwei Fragen sind: „Rest auf die
  nächste Seite" lässt stehen, was in den Kasten passt, und schiebt den
  Überhang weiter — die Stelle sagt der Satz, man muss sie nicht suchen;
  „Nach einem Absatz teilen" trennt an einer selbst gewählten Stelle und gilt
  auch dann, wenn gar nichts herausfällt. Ausgesucht wird nach dem ANFANG des
  Absatzes: „Absatz 4" sagt niemandem etwas, „Am Morgen zogen wir …" schon.
  - **Der erste Kasten behält seinen Rahmen.** Ihn auf den verbliebenen Text zu
    schrumpfen wäre der naheliegende Griff und der falsche — dieselbe Regel wie
    bei `hoeheAnTextAnpassen`: Ein Kasten, der von selbst kleiner wird, nimmt
    eine Größe weg, die jemand mit der Hand eingestellt hat.
  - **Die Fortsetzung ist eine KOPIE mit neuer Kennung** — Schrift, Grund,
    Innenabstand, Linie und Breite bleiben, nur Inhalt, Lage und Höhe sind neu.
    Sie soll aussehen wie ihr Anfang.
  - **Auf eine schon gefüllte Folgeseite kommt sie nicht**, sonst läge sie über
    dem, was dort steht; dann bekommt sie eine eigene, und die steht
    unmittelbar hinter dem Anfang — eine Fortsetzung drei Seiten später findet
    niemand. Beide Kästen tragen danach `vonHand`, der Tag gilt also als
    Handarbeit und wird nicht ohne Rückfrage neu angeordnet.
  - **Geteilt wird nur der Tagebuchtext.** Überschrift, Datumszeile und
    Bildunterschrift stehen am Tag bzw. am Foto; von ihnen eine zweite Hälfte
    anzulegen hieße, eine Kopie zu bauen, die beim nächsten Neuanordnen
    auseinanderläuft.
  - **Drei Wege dorthin**, und keiner davon ist eine Geste: Block → Teilen, der
    Knopf unten in der Leiste (er steht neben „Rahmen an Text anpassen", sobald
    die orange Marke zu sehen ist — auf einer vollen Seite ist er der einzige
    Ausweg, der bleibt) und die Zeile in der Bedienungskarte. **Wer einen neuen
    Griff einbaut, trägt ihn dort ein.**
- **Nicht gemessen (1.0.14):** Kein Buch ist damit gesetzt worden. Gerechnet
  sind die Regeln — wo ein Absatz aufhört, wie hoch der Kopf wird, wie hoch die
  nächste Fotoreihe ist; wie eine Doppelseite damit AUSSIEHT, sagt erst der
  nächste Befund des Nutzers. Die beiden Zahlen (62 Prozent Füllung, sechs
  Zeilen neben einer Fotoreihe) sind gewählt und nicht gemessen. **Nicht als
  erledigt darstellen.**
- **Der Inspektor ist eine SPALTE und läuft bei jedem Bildpunkt mit** (ab
  1.0.15; gemeldet 09/2026: „Nach kurzer Zeit ist die App nun eingefroren.").
  **Nicht gemessen, sondern am Quelltext abgezählt** — ein Gerät gibt es hier
  nicht. `BlockInspektor` hängt an `.inspector(isPresented:)`, steht also offen,
  während gearbeitet wird, und sein Körper läuft bei JEDER Meldung des
  `Reisewerk`s noch einmal. Seit 1.0.8 wandert ein geschobener Rahmen sofort
  ins Modell — beim Schieben meldet sich das Werk damit bei jedem Bildpunkt.
  In 1.0.14 baute der Inspektor dabei drei Dinge, die keine sind:
  - **Ein `Menu` mit einem Knopf je Absatz.** Der Inhalt eines `Menu`
    entsteht beim Zeichnen des Formulars, nicht beim Aufklappen; und ein
    eingelesener Tagebuchtext ist hart umbrochen, also ist JEDE ZEILE ein
    Absatz. Bei einem Tag mit zweihundert Zeilen sind das zweihundert Knöpfe
    samt zweihundert Textausschnitten — sechzigmal in der Sekunde. Die
    Auswahl steht seit 1.0.15 in einem Blatt mit einer `List`: Die baut nur,
    was zu sehen ist, und erst beim Öffnen.
  - **Zweimal die Absatzliste** über den ganzen Text (einmal für die Zahl,
    einmal für das Menü). Sie wird jetzt EINMAL je Änderung gerechnet
    (`.task(id:)`, Schlüssel ist der Text selbst) und liegt in `@State` —
    dieselbe Bauweise wie `textUeberlauf` seit 1.0.8.
  - **Zwei Suchläufe in der Werkzeugleiste.** `werk.block(_:)` geht durch
    alle Tage, Seiten und Blöcke; 1.0.14 stellte `teilbarerText` neben
    `gewaehltesFoto`. Es ist jetzt ein Lauf (`ReiseView.gewaehlterBlock`).
  **Die Lehre ist alt und stand für die Karte schon da** („Eine berechnete
  Eigenschaft sieht billig aus"): **Was im Körper einer Ansicht steht, läuft
  so oft, wie gezeichnet wird — und wer das nicht weiß, misst es.**
- **Und weil sich das hier nicht nachmessen lässt, misst es die App**
  (`Dienste/Zeichenmesser.swift`, sichtbar unter Anordnen → „Bedienung
  prüfen", ab 1.0.15). Neuzeichnungen je Sekunde von Seite und Inspektor,
  dazu die Dauer des Absatzlaufs — **immer mit der Zeitspanne dabei**, denn
  eine Rate ohne ihren Zeitraum ist keine Messung. Dasselbe Muster wie der
  Kartenmesser der Abfahrtstafel und die Stufenprobe bei Schulalarm.
  **Kein `@Published` und kein `ObservableObject`**: Die Ansichten melden
  sich dort an, und wäre der Messfühler beobachtbar, löste jede Meldung ein
  Neuzeichnen aus, das seinerseits gemeldet würde — ein Messgerät, das seinen
  eigenen Messwert erzeugt. Gemeldet wird im KÖRPER und nicht in `onAppear`:
  Nur der Körper läuft bei jedem Neuzeichnen.
- **Die Notbremse des Layoutautomaten verlor den Rest des Textes** (gefunden
  beim Nachrechnen 09/2026, behoben in 1.0.15). `reihenSetzen` bricht nach
  200 Durchgängen ab — gedacht gegen eine Endlosschleife. Das nackte `break`
  gab den Resttext aber nur zurück, und der Aufrufer setzt ihn danach
  nirgends mehr: Genau der Fehler aus dem ersten gedruckten Stand („mussten
  von Passagieren, die"), nur in einem Zweig, den bis dahin niemand betrat.
  Seit 1.0.14 laufen Text und Fotoreihen abwechselnd, die Zahl der Durchgänge
  ist also gestiegen. Was beim Abbruch übrig ist, wird jetzt gesetzt und
  läuft notfalls sichtbar über. **Ein Tagebuch darf keinen Satz verlieren —
  auch nicht in einem Notausgang.**
- **Nicht gemessen (1.0.15) — und die Gegenprobe steht dabei:** Ob das
  Einfrieren wirklich daher kam, weiß niemand. Die Rechnung gilt nur, wenn
  der Block-Inspektor offen WAR; war er zu, ist sie widerlegt, und dann sagt
  der Messfühler beim nächsten Mal, wo es hakt. **Nicht als erledigt
  darstellen** — es ist die erste Erklärung für diesen Befund, und in diesem
  Papier stehen genug Fälle, in denen die erste eine Vermutung war.
- **Die Gegenprobe kam sofort, und sie ging gegen 1.0.15** (gemeldet 09/2026:
  „Erst ging es. Als ich auf eine andere Seite wollte, fror es ein.", dazu das
  Bild des Messfühlers: `Inspektor 18/s (48 in 2,7 s) · Seite 36/s (98 in
  2,7 s) · Absätze 0,0 ms`). Drei Dinge stehen darin, und sie widerlegen die
  Erklärung von 1.0.15 für DIESEN Fall: Der Absatzlauf kostet **null**
  Millisekunden, die Raten sind mäßig, und der Inspektor war auf dem Bild
  **zu** — er zählte trotzdem mit, weil eine `.inspector`-Spalte auch
  zugeklappt einen Körper hat. Was 1.0.15 abgestellt hat, war richtig
  abgestellt; es war nicht das hier. **Genau dafür war die Probe da** — und
  dass sie die eigene Erklärung umwirft, ist ihr Sinn und kein Rückschlag.
- **Ein `VStack` ist nicht lazy — und baute damit das GANZE Buch** (behoben in
  1.0.16). Das ist der erste Befund in dieser Sache, der zum Zeitpunkt passt:
  Die Bühne ist ein `ScrollView` mit einem `VStack` und einem `ForEach` über
  die sichtbaren Seiten, und ein gewöhnlicher `VStack` baut JEDES Kind sofort
  auf, auch das zwanzig Seiten tiefer. Je Seite hängen daran alle Textkästen
  (je ein voller CoreText-Satz) und alle Fotos (je ein Vorschaubild, von der
  Platte gelesen und auf dem HAUPTFADEN entpackt). Ist kein Tag gewählt, sind
  das sämtliche Seiten des Buches. **Und genau das geschieht beim Wechsel**:
  Die Liste wird eine andere, und alles darin entsteht neu. Jetzt ein
  `LazyVStack` — gebaut wird, was in Sichtweite kommt.
- **`Reise.seitenfolge` sah billig aus und setzte das Titelblatt neu** (ab
  1.0.16). Es ist eine berechnete Eigenschaft, und darin steckt zweierlei:
  `reise.automat` baut `fotoIndex`, also ein Wörterbuch über ALLE Fotos des
  Buches, und `automat.titelseite(…)` setzt das Titelblatt samt zwei
  CoreText-Messungen. Gelesen wurde sie im Körper von `ReiseView`, und dort
  **zweimal** je Durchgang — einmal für die Liste, einmal für die Prüfung auf
  leer. Dritte Auflage derselben Falle (Netzkarte der Abfahrtstafel,
  Druckprüfung und Datumserkennung in 1.0.0): **Eine berechnete Eigenschaft
  sieht billig aus.**
- **Gemerkt wird NUR das Titelblatt** (`Reisewerk.titelblatt`). Es ist die
  einzige Seite, die es nicht GIBT, sondern die gerechnet wird; alle anderen
  stehen als `Seite` am Tag und werden nur aufgereiht. Die Blöcke eines Tages
  zu merken hieße, beim Schieben einen alten Stand zu zeichnen — die Lehre aus
  1.0.8, und sie gilt hier genauso. **Der Schlüssel nennt alles, was in das
  Titelblatt eingeht** (Titel, Untertitel, Zeitraum, Titelfoto samt der Frage,
  ob es das noch gibt, Format, Gestaltung, Typografie, Stil); fehlte ein Feld,
  bliebe ein alter Titel stehen, ohne dass etwas darauf hinwiese. Wer
  `Layoutautomat.titelseite` ändert, ändert den Schlüssel mit.
- **`updateUIView` läuft bei JEDEM Durchgang, nicht bei jeder Änderung**
  (`Textkasten`, ab 1.0.16). Dort stand ein `setNeedsDisplay()` ohne
  Bedingung, und die drei Zuweisungen darüber lösten über ihre
  `didSet`-Beobachter je eines aus. Dahinter steckt ein voller CoreText-Satz
  je Textkasten, und eine Seite hat drei bis fünf davon. Verglichen wird
  jetzt vorher — `Schriftbild` ist `Hashable`. **Merke: Eine
  `UIViewRepresentable` bekommt ihr `update` bei jedem Neuzeichnen; was darin
  teuer ist, gehört hinter einen Vergleich.**
- **Das Papierkorn flimmerte, und der Kommentar daneben behauptete das
  Gegenteil** (`Saatstrom`, `Seitensatz.kornpunkte`, ab 1.0.16, beim
  Nachrechnen gefunden). Bildschirm und PDF würfelten es getrennt, jeder mit
  einem `SystemRandomNumberGenerator` — der lässt sich nicht wiederholen. Zwei
  Folgen: Auf dem Bildschirm war das Korn bei jeder Neuzeichnung ein anderes,
  also ein Flimmern statt einer Struktur; und die gedruckte Seite sah nie aus
  wie die angesehene — in einer App, deren erste Regel lautet, dass Seite und
  PDF derselbe Setzer zeichnet. Im Quelltext stand dazu, der Zufallsstrom sei
  „AN DER SEITE festgemacht"; er war es nie. **Ein Kommentar ersetzt keine
  Prüfung** — dieselbe Lehre wie bei Schulalarms `requestAuthorization` und
  den Navigationszielen der Abfahrtstafel. Gerechnet wird es jetzt an EINER
  Stelle, mit einer Saat aus der Seitenkennung.
- **Die Saat kommt aus den BYTES der Kennung, nie aus `hashValue`**
  (`UUID.saat`). Den streut Swift bei jedem Programmlauf neu; dieselbe Seite
  sähe nach jedem Start der App anders aus. Dieselbe Falle wie bei den
  Linienfarben der Abfahrtstafel.
- **Der Messfühler nennt seit 1.0.16 auch SUMMEN** (`Zeichenmesser.sammelt`):
  wie oft etwas im Zeitfenster gelaufen ist und wie viel Zeit dabei
  zusammenkam — Fotos, Seitenliste, Titelblatt. Die LETZTE Dauer sagt darüber
  nichts; sie ist gerade dann klein, wenn der Zwischenspeicher zufällig traf.
  Dazu ein Knopf „Befund kopieren" unter Anordnen: Eine Messung, die man
  abschreiben oder abfotografieren muss, kommt verkürzt an.
- **Nicht gemessen (1.0.16), und das ist die zweite Erklärung für dasselbe
  Einfrieren.** Abgezählt ist, WAS je Neuzeichnung und je Seitenwechsel
  anfiel; ob das Gerät danach flüssig ist, sagt erst der nächste Befund. Die
  Zahl der gezeichneten Korn-Punkte ist unverändert — nur der Zufall daran ist
  weg. **Nicht als erledigt darstellen.**
- **Zwei Finger zoomen die SEITE — außer über einem gewählten Foto** (`seitenzoom`,
  ab 1.0.17, Ansage des Nutzers 09/2026: „Ich weiß, dass es links einen Regler
  gibt, aber der ist mir zu umständlich zu bedienen. Eine Zwei-Finger-Geste auf
  die Seite wäre mir lieber."). Die Geste hängt am INHALT der Bühne, nicht an
  einer einzelnen Seite: Gezoomt wird das Blatt und nicht, was darauf liegt.
  **Damit gibt es erstmals zwei Bedeutungen für dieselbe Geste** — seit 1.0.8
  vergrößern zwei Finger über dem gewählten Foto den Bildausschnitt IM Rahmen,
  und der Satz „die Seite selbst wird nicht mit zwei Fingern gezoomt, es gibt
  also nichts, womit sich die Geste streiten könnte" stand genau deshalb im
  Papier. Aufgelöst wird das an EINER Stelle (`seitenzoomErlaubt`): Ist ein Foto
  gewählt oder der Ausschnittsmodus an, gehört die Geste dem Bild, sonst der
  Seite. **Das ist erlaubt, weil der Unterschied SICHTBAR ist** (die Anfasser
  stehen da, ein Tipp daneben hebt die Auswahl auf) und weil es daneben immer
  einen Weg gibt, der nicht von der Auswahl abhängt: die Lupen unten links.
  Dieselbe Regel wie beim Fußwegmesser der Abfahrtstafel — **ein Modus, den man
  nicht sieht, darf die Bedeutung einer Geste nicht ändern.**
- **`magnification` ist die GESAMTE Bewegung seit dem Aufsetzen** — gerechnet
  wird vom Maßstab beim Aufsetzen (`zoomAnfang`) und nie vom laufenden Wert,
  sonst beschleunigt der Zoom mit jedem Bildpunkt. Dieselbe Falle wie beim
  Bildausschnitt in 1.0.8, jetzt zum zweiten Mal.
- **Der eingepasste Maßstab wird GEMESSEN, nicht geschätzt** (`passenderMassstab`,
  `buehnenbreite`, ab 1.0.17, beim Bau der Geste gefunden). `massstabJetzt` gab
  bei eingepasster Ansicht eine feste **0,7** zurück — eine Zahl, die mit dem
  Bild auf dem Schirm nichts zu tun hat. Die Lupen sprangen damit beim ersten
  Tipp aus der eingepassten Ansicht auf 0,56 bzw. 0,875, egal wie groß die
  Seite gerade stand, und die neue Geste hätte denselben Sprung gemacht.
  Gemessen wird die Bühnenbreite über `onChange(of: raum.size.width)` und
  gemerkt in `@State` — **nicht im Körper geschrieben**: Ein `@State`, das
  während des Zeichnens gesetzt wird, löst das nächste Zeichnen aus.
- **Seite 1 ist eine RECHTE Seite** (`Reisewerk.Doppelseite`,
  `Views/DoppelseiteView.swift`, ab 1.0.17, Ansage des Nutzers 09/2026: „Ein
  Buch hat ja Seiten mit Vorder- und Rückseite. Und auf das Titelblatt kommt ja
  zunächst einmal die Innenseite des Hardcovers, bevor die erste wirkliche
  Buchseite anfängt."). Das ist Buchbinderei und keine Geschmacksfrage: Ein
  Recto trägt eine ungerade Nummer. Der erste Bogen zeigt also rechts die
  Seite 1 und links die **Innenseite des Umschlags** — beim Hardcover das
  Vorsatzpapier. Die kommt von der Druckerei, steht in KEINEM PDF und zählt in
  keiner Seitenzahl; gezeigt wird sie trotzdem, denn sonst läge die Seite 1
  links und damit falsch. **Und sie steht mit ihrem Namen da** („Kommt von der
  Druckerei – nicht im PDF"): Eine leere graue Fläche ohne ein Wort hielte man
  für einen Fehler. Am anderen Ende gilt dasselbe — eine fehlende rechte Seite
  kann es nur am Buchende geben, dort liegt die Innenseite des Rückens.
- **Gepaart wird über das GANZE Buch und erst danach nach Tag gefiltert**
  (`sichtbareDoppelseiten`). Andernfalls verschöbe eine Auswahl die Paarung:
  Fängt ein Tag auf einer linken Seite an, stünde er bei einer Paarung
  innerhalb der Auswahl plötzlich rechts — die Doppelseite zeigte dann etwas,
  das im gedruckten Buch nie so aussieht. Gezeigt wird jeder Bogen, auf dem
  eine Seite der Auswahl liegt, **samt der Nachbarseite, auch wenn die zu
  einem anderen Tag gehört**. Genau so liegt das Buch auf dem Tisch.
- **Zwischen zwei gegenüberliegenden Seiten liegt KEIN Abstand** (`spacing: 0`).
  Im gebundenen Buch stoßen sie am Bund aneinander; was dazwischen hell stehen
  bleibt, ist der ANSCHNITT beider Seiten, und wo der endet, zeigt die rote
  Schnittkante (Anordnen → „Satzspiegel zeigen"). Eine Lücke zu zeichnen wäre
  bequemer und behauptete einen Falz, den es nicht gibt.
- **Der Umschalter steht UNTEN neben den Lupen**, nicht in einem Menü: Er
  gehört zur Ansicht, und wer ihn sucht, sucht ihn dort, wo der Maßstab liegt.
  Dieselbe Lehre wie beim Sichtumschalter der Abfahrtstafel (1.0.5) — **ein
  Knopf, den niemand findet, ist kein Knopf.** Die Wahl liegt in
  `@AppStorage` und damit in einer VIEW, nie im `Reisewerk`.
- **Eine ungerade Seitenzahl wird GEZÄHLT und hingeschrieben, nicht geprüft**
  (ab 1.0.17). In der Doppelseitenansicht sieht man, dass der letzte Bogen
  keine Rückseite hat; darunter steht dann, dass viele Druckdienste eine gerade
  Seitenzahl verlangen und dass die Angabe des jeweiligen Anbieters gilt. Was
  ein bestimmter Dienst annimmt, ist hier NICHT gemessen — die Zeile sagt
  deshalb, was sie weiß, und verspricht nichts.
- **Die Automatik läuft — aber die Reisespur setzte keine Seite neu** (behoben
  in 1.0.17, beim Nachrechnen der Frage des Nutzers gefunden: „Was das Programm
  auszeichnen würde, wäre ja, dass automatisch Texte, Bilder und Koordinaten
  bestimmten Tagen zugeordnet werden und diese Seiten automatisch erstellt
  werden. Ich hoffe, dass das so funktioniert."). Zwei der drei Wege riefen
  `alleNeuAnordnen(nurUnberuehrte: true)` — `textVerteilen` und die
  Fotoeinfuhr. `spurUebernehmen` rief dagegen nur `fehlendeSeitenNachholen()`,
  **und das überspringt jeden Tag, dessen Seitenliste schon gefüllt ist.** Der
  Kartenblock entsteht aber erst, wenn der Tag eine Spur HAT
  (`Layoutautomat.seiten`: `tag.karteZeigen && tag.hatSpur`). In der
  Reihenfolge, die der Nutzer beschreibt — erst der Text, dann die Reisespur —
  kam damit auf keiner Seite eine Karte, und zwar STUMM: Die Tage standen da,
  die Punkte standen in der Liste, gesetzt wurde nichts. Dass es beim
  anschließenden Einlesen der FOTOS doch noch aufgefallen wäre, war Zufall.
  **Merke: Wer einen Einleseweg baut, prüft, ob die Seiten danach neu gesetzt
  werden — `fehlendeSeitenNachholen` ist dafür nie die Antwort**, es ist der
  Notnagel für eine leere Liste.
- **Der erste Punkt von Hand bringt die Karte, der letzte nimmt sie weg**
  (`spurGeaendert`, ab 1.0.17). Dieselbe Wurzel, eine Ebene tiefer:
  `punktHinzufuegen` und `punkteLoeschen` änderten die Spur, ohne die Seite neu
  zu setzen. Neu gesetzt wird nur, wenn `hatSpur` UMKIPPT — ein Punkt mehr in
  einer vorhandenen Spur soll die Seite nicht durcheinanderwerfen —, und mit
  `erzwingen: false`, damit die Handarbeit stehen bleibt.
- **Nicht gemessen (1.0.17):** Ob die Zweifingergeste auf einem Gerät flüssig
  ist, ob sie sich mit dem Blättern des `ScrollView` verträgt und ob sie mit
  dem Bildausschnitt wirklich nie kollidiert, ist am Quelltext entschieden und
  nicht auf einem iPad gesehen. **Der Zoom verfolgt den Mittelpunkt der Geste
  NICHT** — der `ScrollView` behält seinen Versatz, es wird also um die obere
  linke Ecke gezoomt; das nicht anders darstellen. Und die Doppelseitenansicht
  ändert am PDF nichts: Der Bundsteg wird seit 1.0.1 ohnehin auf beide Ränder
  gerechnet, die Ansicht zeigt nur, was daraus wird.
- **Buch aufbauen: die Reihenfolge war da, sie stand nur nirgends**
  (`Views/AufbauView.swift`, `Dienste/Aufbaubericht.swift`, ab 1.0.18;
  Befund des Nutzers 09/2026: „Bislang ist die App auf jeder einzelnen Seite
  ja eher ein noch etwas sperrig zu bedienender Bild- und Texteditor … Was
  das Programm auszeichnen würde, wäre ja, dass automatisch Texte, Bilder und
  Koordinaten bestimmten Tagen zugeordnet werden."). Das TUT die App seit
  1.0.0 — der Text legt die Tage an, die Spur hängt je eine Karte daran, die
  Fotos verteilen sich über ihr Aufnahmedatum. Gestanden hat davon nirgends
  etwas: Die drei Wege lagen als drei gleichrangige Punkte in einem Menü,
  und in welcher Reihenfolge sie zusammengehören, wusste nur, wer es gebaut
  hat. **Fünfte Auflage desselben Befundes** („es war da, man fand es
  nicht") — die vier davor waren die Bildunterschrift, das Zurücksetzen, der
  Zweifinger-Zoom und die Foto-Einstellung.
  - **Kein neuer Einleseweg.** Die Arbeit machen unverändert
    `TextimportView`, `SpurimportView` und `FotoeinfuhrView`; dieser
    Bildschirm ist die Reihenfolge, der Stand und der Bericht. Ein zweiter
    Weg zu derselben Sache liefe irgendwann auseinander — dieselbe Regel wie
    bei `Block.wirkung` und bei den Fotostilfeldern aus 1.0.10.
  - **Die Blätter werden NICHT gestapelt.** Jede der drei Einleseansichten
    bringt einen eigenen `NavigationStack` mit, und ein Blatt über einem
    Blatt ist auf dem iPad ein Kärtchen auf einem Kärtchen. Stattdessen macht
    der Aufbau zu, die WURZEL öffnet das nächste Blatt im `onDismiss`, und
    wenn das zugeht, kommt der Aufbau zurück — dort steht dann, was daraus
    geworden ist. Dieselbe Regel wie bei den Dateiwählern in Tafelbild: Der
    Wunsch trägt das Ziel (`alsNaechstes`), kein Schalter daneben.
  - **Der Bericht zählt, er behauptet nicht.** Je Tag Zeichen, Fotos, Orte
    (davon aus der Tagesspur) und Seiten, dazu, was fehlt; darunter die
    Fotos in der Ablage, ohne Datum und ohne Ort. Kopierbar — dieselbe
    Bauweise wie „Zustellung prüfen" bei Schulalarm. **Ein Tag ohne Foto ist
    kein Fehler**, deshalb steht das Fehlende orange und nicht rot; es steht
    aber da, sonst bemerkt es niemand.
  - **Gerechnet wird beim Öffnen, nicht im Körper** (`.task`). Der Bericht
    geht über alle Tage und alle Fotos — dieselbe Falle wie bei der
    Druckprüfung in 1.0.0.
  - **Die drei Einzelwege bleiben stehen.** Wer weiß, was er will, soll nicht
    durch einen Ablauf laufen müssen.
- **Der Zoom geschieht um den Mittelpunkt der Geste** (`Model/Zoomanker.swift`,
  ab 1.0.18, Ansage des Nutzers 09/2026). 1.0.17 hatte es als offenen Punkt
  aufgeschrieben: Der `ScrollView` behält seinen Versatz, während der Inhalt
  wächst — gezoomt wurde also um die obere linke Ecke.
  - **Ein SwiftUI-`ScrollView` hat unter iOS 17 keinen Versatz zum SETZEN.**
    `scrollPosition(id:)` zeigt auf eine Ansicht, `scrollTo(point:)` gibt es
    erst ab iOS 18. Der einzige Hebel ist
    `ScrollViewProxy.scrollTo(_:anchor:)` — und der legt den Punkt `a` eines
    ELEMENTS auf den Punkt `a` des Sichtfelds. `Zoomanker` löst diese
    Gleichung nach `a` auf. **Den `ScrollView` durch eine eigene Schiebe- und
    Zoomfläche zu ersetzen wäre der naheliegende Weg und der teurere**: Daran
    hängen das Blättern, die Faulheit des `LazyVStack` aus 1.0.16 und die
    Ziehgesten der Blöcke, für die 1.0.5 bis 1.0.8 gebraucht wurden.
  - **Zwei Hälften, und nur eine rechnet.** Solange die Finger auf dem Glas
    sind, skaliert ein `scaleEffect` mit Anker — das ist eine Abbildung und
    kann gar nicht danebenliegen, und die Seiten werden dabei nicht bei jedem
    Bildpunkt neu gesetzt. Erst am Ende wird der Maßstab gesetzt und EINMAL
    gerollt.
  - **Der Anteil gilt für das BLATT, nicht für das Element.** Die
    Beschriftungszeile darunter wächst beim Zoomen nicht mit; ein Anteil über
    beides zusammen ginge daneben. Damit die Rechnung nicht schätzt, hat die
    Zeile eine FESTE Höhe (`Buehnenmasse`), und Fuge, Rand und
    Beschriftungshöhe stehen an EINER Stelle — wer sie in der Ansicht ändert
    und dort nicht, zoomt wieder auf einen Punkt, auf den niemand gezeigt hat.
  - **Wo der Inhalt steht, wird in eine KLASSE geschrieben** (`Inhaltslage`),
    nicht in `@State` und nicht über eine Preference. Der Wert ändert sich bei
    jedem Bildpunkt des Scrollens; ein Zustand an dieser Stelle zeichnete die
    Bühne sechzigmal in der Sekunde neu — genau das, was 1.0.16 abgestellt
    hat. Dieselbe Bauweise wie beim `Zeichenmesser`, der aus demselben Grund
    kein `@Published` hat. Gelesen wird nur im Augenblick einer Geste.
  - **Die Lupen zoomen auf die MITTE des Sichtfelds**, über denselben Weg.
    Ihr Wunsch reist über `lupenwunsch` durch den Zustand, weil der
    `ScrollViewProxy` nur innerhalb des `ScrollViewReader`s gilt und die
    Knöpfe in der Werkzeugleiste stehen; ihn außerhalb zu merken wäre der
    naheliegende Weg und einer, den SwiftUI nicht zusagt.
  - **Am Rand hält der Brennpunkt nicht** — weiter als bis zum Anfang und
    zum Ende rollt kein `ScrollView`. Das ist richtig so und kein Fehler.
  - **Nicht gemessen:** Ob der Punkt auf einem Gerät wirklich stehen bleibt,
    hat niemand gesehen. Gerechnet ist die Geometrie; ungeprüft sind die
    beiden Annahmen darunter — dass `MagnifyGesture.Value.startLocation` im
    Raum des Inhalts gemeldet wird und dass `scrollTo` mit einem Anker
    außerhalb der Mitte tut, was die Dokumentation sagt. Und beim Übergang
    von der Skalierung auf den gesetzten Maßstab kann ein Bild lang ein
    Sprung stehen: Gerollt wird einen Durchgang später, weil `scrollTo` die
    Größe braucht, die das Element dann erst hat. **Nicht als erledigt
    darstellen.**
- **Eine Uhrzeit ist die WANDUHR am Ort, nie ein Augenblick auf der Weltuhr**
  (`Dienste/Ortszeit.swift`, ab 1.0.19, Ansage des Nutzers 09/2026: Die Zeiten
  „müssten dann angepasst werden gemäß der Zeitzone des Ortes, also in
  Deutschland der mitteleuropäischen Sommerzeit und für Kanada die Sommerzeit
  in Toronto."). Das ist dieselbe Regel wie beim TAG, der aus drei Zahlen
  kommt — sie galt bisher nur für die eine Hälfte der Daten.
  - **Ein Foto hält sich von selbst daran.** Im EXIF steht „19:33:21" ohne
    jede Zone; `Bildbefund` legt genau diese Ziffern mit einer FESTEN Zone ab,
    und `SpurView` wie `BlockInspektor` zeichnen mit derselben. Auf dem
    Bildschirm steht damit, was die Kamera angezeigt hat.
  - **Die Reisespur hielt sich NICHT daran.** Tagesspur-Sicherung und GPX
    schreiben echte Augenblicke (`2026-07-25T18:14:03Z`), und die landeten
    unverändert in demselben Feld. Gezeichnet mit derselben festen Zone hieß
    das: UTC. In einer Liste standen damit Fotopunkte richtig und Spurpunkte
    falsch — in Toronto um vier Stunden, in Deutschland um zwei. **Ein Feld
    mit zwei Bedeutungen läuft auseinander**, und hier war es schon
    auseinandergelaufen, nebeneinander in derselben Zeile.
  - **Umgerechnet wird beim EINLESEN, nicht beim Zeichnen**
    (`Spureinfuhr.ortszeitenSetzen`). Danach bedeutet `Reisepunkt.zeit`
    überall dasselbe. Der Versatz wird für den jeweiligen Augenblick erfragt
    (`zone.secondsFromGMT(for:)`) und nicht als fester Wert der Zone: Eine
    Reise über den Oktober hinweg läge sonst an einem Ende falsch.
  - **Welche Zone gilt, wird je TAG nachgeschlagen** (`Zonensucher`,
    `CLPlacemark.timeZone` am ersten Ort des Tages). Je Punkt wären es
    Tausende Anfragen, je Datei wäre es falsch — der Nutzer nennt Deutschland
    und Toronto in einem Satz. **Eine eigene Tabelle wäre geraten**: iOS
    bringt keine mit, und Zonengrenzen folgen Staats- und Provinzgrenzen,
    nicht Längengraden. Gemerkt wird auf einem Viertelgrad-Gitter, und ein
    `actor` hält die Anfragen auseinander — `CLGeocoder` nimmt immer nur eine
    gleichzeitig und weist die zweite ab.
  - **Ohne Netz wird nichts behauptet.** Dann gilt die im Blatt eingestellte
    Zone, und die Vorschau sagt je Tag, welche es war — nachgeschlagen steht
    grau da, angenommen orange und mit dem Wort „angenommen". Dieselbe Regel
    wie beim Wort „Plan" an einer Abfahrt ohne Echtzeit.
  - **Der TAG wird dabei NICHT neu gerechnet.** Wo ein `dayKey` in der Datei
    stand, ist er der Tag, den der Mensch erlebt hat; dass eine umgerechnete
    Uhrzeit über Mitternacht rutscht, ändert daran nichts. Wo der Tag
    gerechnet werden muss (fremdes GPX), gilt weiter die eingestellte Zone —
    sonst müsste erst gruppiert werden, um die Zone zu finden, und die Zone
    bestimmte die Gruppierung.
  - **`Reisetag.zeitzone` ist eine AUSKUNFT, keine Rechenvorschrift.** Die
    Uhrzeiten sind schon umgerechnet; das Feld sagt nur, worauf sie sich
    beziehen, und steht unter den Reisepunkten und im Aufbaubericht. Wer damit
    noch einmal umrechnet, rechnet zweimal.
  - **Schon eingelesene Tage bleiben, wie sie sind.** Aus welcher Zone sie
    kamen, weiß die App nicht mehr; eine Wanderung um vier Stunden zu
    verschieben, weil es plausibel aussieht, wäre geraten. Wer sie berichtigen
    will, liest die Datei noch einmal ein — das ersetzt die Spurpunkte des
    Tages (die Regel steht seit 1.0.4 dort).
  - **Nicht gemessen:** Ob `CLPlacemark.timeZone` für die Orte dieser Reise
    etwas hergibt, hat niemand gesehen — hier gibt es weder Netz zu Apples
    Geocoder noch eine echte Sicherung. Gerechnet ist die Umrechnung und der
    Weg drumherum; ob die Zonen ankommen, sagt die Zeile „Nachgeschlagen: n
    von m Tagen" im Einlesen-Blatt. **Nicht als erledigt darstellen.**
- **Ein Reisepunkt lässt sich ÄNDERN, nicht nur setzen und wegwischen**
  (`PunktwahlView` mit `punktID`, `Reisewerk.punktAendern`, ab 1.0.20, Ansage
  des Nutzers 09/2026: „Ich möchte sie löschen, örtlich und zeitlich verändern
  können.").
  - **Ein Bildschirm für beides.** Ein eigener Editor neben der Punktwahl wäre
    ein zweiter Weg zu derselben Sache — dieselbe Regel wie bei den
    Fotostilfeldern (1.0.10) und bei `Block.wirkung`.
  - **Der TIPP auf die Karte setzt die Stelle** (ausdrücklich gewünscht). Bis
    1.0.19 stand hier die Regel, ein Tipp sei schlechter als ein Fadenkreuz,
    weil der Finger die Stelle verdeckt. Beides gilt: Der Tipp rückt die
    Stelle unter das FADENKREUZ, statt sie blind zu übernehmen — man sieht
    hinterher, wo sie gelandet ist, und schiebt die Karte nach. Der Maßstab
    bleibt dabei (`spanne`), sonst spränge er bei jedem Tipp zurück.
  - **Die Uhrzeit wird GETIPPT, nicht gedreht** (ebenfalls ausdrücklich).
    Angenommen wird alles Eindeutige — „9:05", „0905", „9.05", „9" —, und was
    keine Uhrzeit ist, sperrt den Knopf mit einem Satz daneben. Der
    `DatePicker` ist damit weg; zwei Wege wären einer zu viel.
  - **Eine geänderte Uhrzeit sortiert den Punkt NEU ein.** Die Reihenfolge der
    Liste ist die Reihenfolge der gezeichneten Linie; ein Punkt von 8 Uhr
    hinter einem von 17 Uhr ergäbe einen Weg, den niemand gefahren ist. Punkte
    OHNE Uhrzeit bleiben, wo sie sind — wohin sie gehören, weiß auch die App
    nicht (die Regel steht seit 1.0.0 dort).
  - **`starten()` läuft nur EINMAL** (`geladen`). `.task` läuft nach einer
    Rückkehr aus dem Hintergrund noch einmal, und dann stünde die gerade
    verschobene Karte wieder am Anfang.
- **Das App-Symbol ist eine FARBE und eine FORM** (`scripts/make-icon.py`, ab
  1.0.20, Befund des Nutzers 09/2026: „Das Programm-Icon sieht von Weitem aus
  wie eine weiße Fläche mit einem Rand drumherum."). Er hat recht, und der
  Grund ist am alten Entwurf abzulesen: ein aufgeschlagenes Buch in
  Papierweiß über drei Vierteln der Fläche, auf dunklem Grund. Aus zehn
  Zentimetern sah man ein Buch; auf einem Homescreen misst ein Symbol vierzig
  Bildpunkte, und dann bleiben von Papier, Falz und Lineatur eine helle
  Fläche und ein dunkler Saum. **Bei dieser Größe trägt ein Symbol eine Farbe
  und eine Form** — so machen es die Apps mit derselben Aufgabe (Polarsteps
  eine Route, Karten eine Nadel, Books ein weißes Zeichen auf kräftigem
  Verlauf). Jetzt: ein Weg mit Anfang und Ziel, weiß auf einem diagonalen
  Verlauf von Abendsonne nach Tiefrot. **Die Kontur unter dem Weiß ist keine
  Zierde** — der Verlauf ist oben links deutlich heller, und ohne sie verlöre
  die Linie dort ihren Halt (dieselbe Überlegung wie bei den Linienzügen der
  Abfahrtstafel). Der Verlauf läuft DIAGONAL: ein senkrechter sieht wie ein
  Farbfeld aus, ein diagonaler hat eine Richtung. Alles bleibt zwischen 140
  und 884 — was näher an der Ecke liegt, schneidet iOS mit seiner Maske weg.
- **Vier Orte, vier Fragen — die Menüs** (ab 1.0.20, Befund des Nutzers
  09/2026: „Ich finde, dass viele Funktionen nicht selbsterklärend in
  verschachtelten Menüs abgelegt wurden."). Bis 1.0.19 standen oben drei
  gleich aussehende Menüs („Einlesen", „Anordnen", „Buch"), und wo etwas lag,
  ergab sich aus der Geschichte und nicht aus der Sache: der Satzspiegel (eine
  Ansichtssache) unter „Anordnen", das PDF (eine Ausgabe) unter „Buch" neben
  der Stilwahl, und die Sachen DIESES Tages verteilt auf zwei Menüs und die
  Fußleiste.
  - `+` — **was ins Buch hineinkommt** (Buch aufbauen, Text, Fotos, Dateien,
    Spur, Ablage samt Zahl).
  - Pinsel — **wie das Buch aussieht** (Stil, Schrift, Fotos, Textfelder,
    Hintergrund, Format).
  - `…` — **alles Seltene**: ausgeben, alle Tage neu anordnen, Hilfen beim
    Anordnen (Satzspiegel, Einrasten), Prüfen.
  - Unten rechts, mit dem DATUM beschriftet — **alles zu diesem Tag**: Text
    und Fotos, Reisepunkte, neu anordnen, Seitenmuster, Seite anfügen.
  - **Nichts steht an zwei Stellen.** Wer eine Funktion hinzufügt, sucht
    zuerst die Frage, die sie beantwortet.
  - „Zurück" heißt jetzt **„Widerrufen"**: Es stand direkt neben einem
    Zurück-Pfeil, der das Buch schließt (jetzt „Bücher"). Zwei Dinge mit
    demselben Wort sind eines zu viel.
  - **Die Plus-Minus-Lupen sind ersatzlos weg** (Ansage des Nutzers: keine
    doppelten Funktionen). Stufenweises Zoomen können zwei Finger besser; was
    sie NICHT können, ist ein bestimmter Maßstab. Geblieben ist EIN Knopf, der
    den Maßstab **nennt** („68 %") und „Einpassen" bzw. 100 % setzt — die
    Beschriftung ist zugleich die Auskunft.
  - **Die Fußleiste steht INLINE in der `ToolbarItemGroup`.** Eine Gruppe
    verteilt ihre Kinder auf eigene Plätze; ein einzelner weitergereichter
    Ausdruck ist für sie EIN Kind.
- **Das Blatt braucht einen Schatten, der nicht mitschrumpft** (ab 1.0.20).
  Er stand vor dem `scaleEffect` und wurde mitskaliert: Bei eingepasster
  Ansicht (rund 0,4) blieben von neun Punkten dreieinhalb — die Seite lag
  flach auf dem Grund, statt als Blatt darauf zu liegen. Jetzt liegt er
  außerhalb und ist in BILDSCHIRMpunkten gerechnet, also auf jedem Maßstab
  derselbe (dieselbe Überlegung wie bei den Säumen der Werkzeugleiste in
  Tafelbild).
- **Die Leinwand ist ein Mittelton, kein Fast-Weiß** (`ReiseView.leinwand`, ab
  1.0.20). `systemGroupedBackground` ist sehr hell, und darauf ist ein weißes
  Blatt kaum ein Blatt. So macht es keine App, die Seiten zeigt: Pages und
  Keynote stellen das Papier auf einen deutlich dunkleren Grund, Books auf
  einen ganz dunklen. Das ist kein Geschmack — **nur vor einem neutralen
  Mittelton lässt sich beurteilen, wie hell ein Foto auf dem Papier wirklich
  steht.**
- **Ein Bild sagt, welcher Tag das war** (`TagListeView`, ab 1.0.20). Ein
  Datum in einer Liste sagt nichts; das erste Foto des Tages sofort. Dieselbe
  Bauweise wie in Fotos und Books. Gibt es keines, bleibt der Platz stehen,
  damit die Zeilen nicht unterschiedlich weit eingerückt sind. Im Regal steht
  seither das **Titelfoto** und nicht mehr das erste Foto der Reise (zwei
  Bücher mit demselben Anreisetag sahen sonst gleich aus), hochkant wie ein
  Buchrücken.
- **Nicht gemessen (1.0.20):** Ob die neue Aufteilung sich besser bedienen
  lässt, sagt erst der nächste Befund — geändert sind Wege und Namen, und das
  ist keine Messung (dieselbe Einschränkung wie bei 1.0.10). Ebenso ungesehen:
  wie das Symbol auf einem Homescreen wirkt, ob der Tipp auf die Karte den
  richtigen Punkt trifft und ob der Schatten auf einem Gerät nicht zu schwer
  ist. **Nicht als erledigt darstellen.**
- **Mehrere Zeitstempel auf einmal verschieben** (`Views/Zeitverschiebung.swift`,
  `Reisewerk.zeitenVerschieben`, ab 1.0.21, Ansage des Nutzers 09/2026:
  „mehrere von ihnen auswählen zu können und ihren Zeitstempel gemeinsam
  verschieben zu können, beispielsweise um drei Stunden nach hinten."). Der
  Fall dahinter ist der Regelfall auf einer Reise: eine Kamera, deren Uhr auf
  der Zeit von zu Hause stand, oder eine Spur aus einer fremden App ohne
  Zonenangabe.
  - **Der Auswahlmodus ist SICHTBAR**: Die Überschrift zählt mit („4 von 37
    gewählt"), der Knopf heißt „Fertig", und vor jeder Zeile steht ein Kreis
    statt eines Pfeils. Ein Modus, den man nicht sieht, darf die Bedeutung
    eines Tipps nicht ändern — dieselbe Regel wie beim Fußwegmesser der
    Abfahrtstafel.
  - **Ordnen und Auswählen gibt es nicht gleichzeitig.** Der `EditButton`
    verschwindet im Auswahlmodus; sonst hätte ein Tipp auf eine Zeile drei
    Bedeutungen (öffnen, auswählen, anfassen).
  - **Das Blatt rechnet VOR, statt zu versprechen**: Zahl der Gewählten, Zahl
    der Punkte ohne Uhrzeit (an denen sich nichts verschieben lässt) und der
    erste Punkt mit alter und neuer Zeit. Wer „drei Stunden nach hinten" liest,
    hat noch nicht geprüft, ob es die richtige Richtung ist. Dieselbe Bauweise
    wie bei jeder Einfuhr dieser App: erst zeigen, dann übernehmen.
  - **Verschoben wird die WANDUHR am Ort** — dieselbe, die in der Liste steht
    (siehe `Dienste/Ortszeit.swift`); addiert werden schlicht Sekunden. Punkte,
    die dabei über Mitternacht rutschen, **bleiben an diesem Tag**: Der Tag ist
    der, den der Mensch erlebt hat, und nicht das Ergebnis einer Rechnung.
  - **Danach wird STABIL neu nach Zeit geordnet** (`nachZeitGeordnet`). `sorted`
    ist in Swift nicht als stabil zugesichert; ohne den Index als zweites
    Merkmal stünden zwei Punkte derselben Minute nach jedem Verschieben anders.
    Punkte ohne Uhrzeit behalten ihre Reihenfolge am Ende.
  - **Was nicht verschoben wurde, steht in der Meldung.** Eine stillschweigend
    übergangene Auswahl sieht aus wie ein Fehler.
- **Ein HÖCHSTMASS macht einen Inhalt nie breiter** (`ReiseView.inhaltsbreite`,
  ab 1.0.22; gemeldet 09/2026: „Die Seite kann leider nicht verschoben werden.
  Wenn ich sie zoome, dann springt sie immer in irgendeine offenbar
  vorgerasterte Position. Diese ist aber selten die, mit der ich dann an der
  Stelle gerne weiterarbeiten würde."). Der Inhalt der Bühne trug
  `.frame(maxWidth: .infinity)`. In einem SENKRECHTEN `ScrollView` ist das der
  übliche Griff — dort bietet die Rolle ihre eigene Breite an, das Höchstmaß
  setzt sie ein, und der Inhalt steht mittig. Diese Bühne rollt aber in BEIDE
  Richtungen, und dort ist es der falsche Griff: **Ein Höchstmaß kann einen
  Inhalt niemals BREITER machen als das, was ihm angeboten wird**, und wie
  breit ein `ScrollView` seinen Inhalt auf einer ROLLACHSE anbietet, steht
  nirgends verbindlich. Genau daran hing, ob sich eine herangezoomte Seite
  quer schieben lässt. Gesetzt wird jetzt eine AUSGERECHNETE Breite:
  mindestens das Sichtfeld (sonst ließe sich ein schmales Blatt nicht
  zentrieren) und mindestens das Blatt samt seinen beiden Rändern (sonst gäbe
  es nichts zu schieben, wo es etwas zu schieben gibt). Beide Zahlen sind
  bekannt — die eine gemessen, die andere Bogenbreite mal Maßstab. **Damit
  hängt das Schieben an keiner Zusage mehr, die niemand nachlesen kann.**
- **Und der Kommentar daneben behauptete das Gegenteil.** Über
  `Zoomanker.griff` stand seit 1.0.18: „Der Inhalt ist mindestens so breit wie
  das Sichtfeld (`maxWidth: .infinity`)" — ein Höchstmaß als Beleg für ein
  Mindestmaß, in einer Klammer, in der die Prüfung hätte stehen müssen.
  Dieselbe Wurzel wie bei Schulalarms `requestAuthorization` und den
  Navigationszielen der Abfahrtstafel: **Ein Kommentar ersetzt keine Prüfung.**
  Die Zeile nennt jetzt `ReiseView.inhaltsbreite`, also die Stelle, an der das
  Mindestmaß wirklich gesetzt wird.
- **Ein `DispatchQueue.main.async` aus einem Gestenrückruf ist NICHT „nach dem
  nächsten Durchgang"** (behoben in 1.0.22). `zoomAuf` setzte `zoom = neu` und
  rollte im selben Atemzug asynchron hinterher, mit dem Kommentar „erst stehen
  lassen, dann rollen". Eine Zustandsänderung löst aber einen Durchgang von
  SwiftUI aus, und ein Block in der Hauptschlange kann davor laufen: Dann
  rechnet `scrollTo` mit der ALTEN Größe des Elements und rollt an eine
  Stelle, die mit dem neuen Maßstab nichts zu tun hat. Genau so sieht
  „springt in irgendeine Position" aus. Der Wunsch reist deshalb durch den
  Zustand (`rollwunsch`) und wird in `onChange` eingelöst — das läuft
  garantiert nach dem Durchgang, der ihn gesetzt hat. **Die laufende Nummer im
  Wunsch gehört dazu**: `onChange` meldet sich nur bei einer Änderung, und
  zweimal derselbe Anker hintereinander wäre keine.
- **Geklemmt heißt „geht hier nicht", nicht „ist falsch gerechnet"**
  (`Zoomanker.Ankerbefund`, ab 1.0.22). `teil` klemmte den Anker stumm auf 0
  bis 1. Ein roher Wert außerhalb davon heißt aber etwas Bestimmtes: Der
  Brennpunkt ist an dieser Stelle GAR NICHT zu halten — weiter als bis zum
  Rand rollt kein `ScrollView`, und am Anfang und Ende der Liste ist das der
  Normalfall. Geklemmt sieht genau das aus wie eine Handvoll fester
  Stellungen, in die die Seite nach jedem Zoomen springt. Geklemmt wird jetzt
  erst beim Bauen des `UnitPoint`, und der Befund trägt beide Zahlen.
- **Die Probe nennt seither den FREIEN WEG** („Bedienung prüfen", darunter
  „Befund kopieren"). Sichtfeld, Inhalt, Versatz, Maßstab, Blattbreite, Griff,
  Brennpunkt, Anker roh und geklemmt — und `frei ⇄`/`↕`, also Inhalt minus
  Sichtfeld. **Ist diese Zahl waagerecht null, gibt es nichts zu schieben, und
  jede weitere Erklärung erübrigt sich.** Die jetzige Lage wird erst beim
  Tippen auf „Befund kopieren" gelesen und nirgends laufend mitgeschrieben —
  `Inhaltslage` ist aus demselben Grund eine schlichte Klasse und kein
  `@State` (die Lehre aus 1.0.16).
- **Nicht gemessen (1.0.22), und es ist die dritte Erklärung für diese Bühne.**
  Abgezählt ist die Geometrie: dass ein Höchstmaß die Breite nicht wachsen
  lässt, und dass der asynchrone Block vor dem Durchgang liegen kann.
  **Gesehen hat es niemand** — ob sich die Seite auf dem iPad jetzt schieben
  lässt und ob der Brennpunkt beim Zoomen steht, sagt erst der nächste Befund.
  1.0.18 hatte beides schon als offen aufgeschrieben („dass `scrollTo` mit
  einem Anker außerhalb der Mitte tut, was die Dokumentation sagt"), und diese
  Fassung prüft davon nichts nach; sie stellt zwei Dinge ab, die unabhängig
  davon falsch waren, und gibt der nächsten Meldung Zahlen mit. **Nicht als
  erledigt darstellen.**
- **Die Geste braucht FLÄCHE — und der Befund hat es gesagt** (ab 1.0.23;
  gemeldet 09/2026: „Beim Zoomen springt die Seite irgendwo hin. Da hat sich
  nichts geändert. Ich habe sie jetzt klein gezoomt und kann sie nicht wieder
  größer bekommen.", dazu der kopierte Befund). **Zum ersten Mal in dieser
  Sache entscheidet eine Messung und keine Überlegung**, und sie steht in zwei
  Zahlen derselben Zeile: `Inhalt 1046×429 · Bühne 1046×864`. Die
  Zweifingergeste hängt am INHALT. Bei 25 % deckte der die oberen 429 von 864
  Punkten ab; darunter lag nackte Leinwand OHNE Geste. Wer in der Mitte des
  Bildschirms aufzieht, greift also ins Leere — **und die Falle zieht sich zu,
  je kleiner man zoomt**: genau der gemeldete Zustand. Der Inhalt ist seither
  mindestens so hoch wie das Sichtfeld. **Oben ausgerichtet, nicht mittig** —
  die Lagen der Elemente gehen in `Zoomanker` ein, und eine senkrechte
  Zentrierung verschöbe jede davon. Die Breite konnte 1.0.22 exakt setzen
  (`.frame(width:)`); die Höhe wird als MINDESTMASS gesetzt, denn unter der
  Bogenliste kann noch ein Hinweis stehen, und eine feste Höhe schnitte ihn ab.
- **Eine glatte 1,00 in einem Anteil heißt „geklemmt", nicht „unten"**
  (`Zoomanker.Griff.imBlatt`, ab 1.0.23). Derselbe Befund nannte
  `Griff #1 quer 0.50 hoch 1.00` — der Finger lag an der Unterkante des
  Inhalts, also NEBEN dem Blatt. Daraus wurde trotzdem ein Anker gerechnet,
  und der legte die Blattunterkante unter den Finger: der Sprung „irgendwo
  hin". Wo kein Blatt unter dem Finger ist, gibt es keinen Brennpunkt zu
  halten — dann wird gar nicht mehr gerollt, und die Rolle bleibt stehen, wo
  sie steht. **Es ist dieselbe Ursache wie beim Punkt darüber**, von der
  anderen Seite gesehen: Beide Symptome kommen daher, dass die Geste dort
  ankam, wo kein Inhalt war.
- **Eine Probe, die ihre eigene Zahl verzerrt, ist schlimmer als keine**
  (ab 1.0.23, zwei Berichtigungen, beide am ersten echten Befund aufgefallen):
  - `Inhalt 570×423` stand über einem Rahmen, der 1046 breit gesetzt war.
    `Inhaltslage` wird durch den `scaleEffect` HINDURCH gemessen, und am ENDE
    einer Geste steht dort die skalierte Größe (570/1046 ist ungefähr der
    Zoomfaktor jener Geste). Beim AUFSETZEN ist `lupe` noch 1, also stimmt sie
    dort — seither wird sie dort gemerkt.
  - `Blatt 990 pt` war `inhaltsbreite` minus Ränder, bei einer kleinen Seite
    also die BÜHNE und nicht das Blatt. Gerechnet wird jetzt Bogenbreite mal
    Maßstab (`blattbreite(bei:)`).
  **Wer eine Probe baut, prüft, ob sie misst, was ihre Beschriftung sagt.**
- **Was der Befund AUSGESCHLOSSEN hat, zählt auch.** Die Breite stimmte
  („Inhalt 1046", genau die gesetzte `inhaltsbreite`) — der Umbau von 1.0.22
  wirkt also. Und `frei ⇄0 ↕-435` sagt, dass bei kleiner Seite gar nichts zu
  schieben ist; das ist richtig so und war nie der Fehler. **Erst diese
  Zahlen haben die Frage von „warum springt es" auf „wo kommt die Geste
  überhaupt an" gedreht** — nach drei Erklärungen, die alle am Quelltext
  abgezählt und keine gemessen waren.
- **Nicht gemessen (1.0.23):** Ob sich die Seite jetzt überall aufziehen lässt
  und ob der Brennpunkt steht, sagt erst der nächste Befund. Gemessen ist,
  WARUM die Geste nicht ankam; dass sie es jetzt tut, folgt aus der Geometrie
  und ist nicht gesehen. **Nicht als erledigt darstellen.** Der Weg zurück aus
  einer zu kleinen Seite liegt daneben und hängt an keiner Geste: der Knopf
  mit der Prozentzahl unten links → „Einpassen".
- **Wer nicht rollt, springt in die linke obere Ecke** (ab 1.0.24, gemeldet
  09/2026: „Wenn ich das tue, dann wird die Zoom-Geste korrekt ausgeführt.
  Lasse ich allerdings die beiden Finger los, dann springt das Bild wieder auf
  die linke obere Ecke."). **Der Befund sagt selbst, wo es liegt:** Während der
  Geste skaliert ein `scaleEffect` um den Punkt zwischen den Fingern — das ist
  eine Abbildung und kann gar nicht danebenliegen; erst beim Loslassen wird
  gerechnet. Also liegt es am Loslassen. Und dort stand seit 1.0.23 ein
  `guard griff.imBlatt`: Lag der Mittelpunkt der Finger nicht auf dem Blatt,
  wurde GAR NICHT gerollt — dann behält die Rolle ihren Versatz, während der
  Inhalt um den Faktor der Geste WÄCHST, und man sieht einen Punkt, der um
  genau diesen Faktor näher am Ursprung liegt. Das IST der Sprung in die Ecke,
  also der Zustand von vor 1.0.18. Gerollt wird jetzt immer; `imBlatt` ist nur
  noch eine Auskunft für die Probe.
- **Der Brennpunkt ist ein Punkt IM INHALT, das Blatt nur das Maß dafür**
  (ab 1.0.24). Aus demselben Grund werden die beiden Griffanteile nicht mehr
  auf 0 bis 1 geklemmt: `hoch = 1,05` heißt „eine Blatthöhe und fünf Prozent
  unter der Oberkante" und rechnet sich genauso wie 0,5. Geklemmt werden darf
  erst der fertige `UnitPoint`, denn DER kann nichts anderes ausdrücken.
- **Ein geklemmter Anker wird über den NACHBARN ausgedrückt**
  (`Zoomanker.rollziel`, ab 1.0.24). Ein Anker trägt nur Werte von 0 bis 1 und
  damit nur Elementkanten zwischen 0 und `Sichtfeld − Element`; im Befund des
  Nutzers stand `Anker … 0.76 (geklemmt)`. Die Reichweite lässt sich aber ohne
  jede Annahme vergrößern, **weil alle Elemente gleich hoch sind und im selben
  Abstand stehen**: Die Kante von Element `k` liegt um `(k − Index) · Schritt`
  unter der des gegriffenen, also rollt man das Nachbarelement an den
  passenden Anker und das gegriffene steht, wo es stehen soll. Gesucht wird
  das Element mit dem geringsten Überstand; passt der eigene Anker schon,
  ändert sich nichts. Reine Geometrie, keine Vermutung.
- **Seit 1.0.24 wird die WIRKUNG gemessen und nicht gefolgert** (`sollversatz`,
  Zeile `Soll … Ist … Abweichung`). Seit 1.0.18 steht hier, dass ungeprüft
  ist, ob `scrollTo` einen Anker außerhalb der Mitte einlöst — drei Fassungen
  lang wurde gerechnet und die Wirkung nicht nachgesehen. `Soll` ist der
  Versatz, den der Inhalt danach haben MÜSSTE, `Ist` der, den er 0,4 s später
  WIRKLICH hat. Stimmen sie überein, liegt ein verbleibender Fehler nicht an
  dieser Rechnung. **Wer eine Geometrie baut, baut die Gegenprobe mit.**
- **„Lässt sich nicht schieben" wird GEZÄHLT, nicht erklärt**
  (`Inhaltslage.spanne`, ab 1.0.24, zum zweiten Mal gemeldet). Ein `ScrollView`
  rollt oder rollt nicht, und am Quelltext sieht man es nicht. Gezählt wird
  deshalb, wie weit der Ursprung des Inhalts seit dem Öffnen überhaupt
  gewandert ist — bleibt die Spanne null, während jemand schiebt, rollt die
  Bühne nicht; wächst sie, ist die Frage eine andere. Gezählt wird in einer
  schlichten Klasse OHNE `@Published`, aus demselben Grund wie beim
  `Zeichenmesser`: Ein Zustand, der bei jedem Bildpunkt geschrieben wird,
  zeichnet die Bühne sechzigmal in der Sekunde neu.
- **Die Vermutung zum Schieben ist AUFGESCHRIEBEN und nicht ausprobiert**
  (1.0.24). Naheliegend ist, dass die Zweifingergeste einen Zweifinger-Wisch
  verschluckt — also genau die Bewegung, die nach einem Aufziehen am nächsten
  liegt; zu ändern wäre das mit `simultaneousGesture`, wie es
  `SeitenflaecheView` beim Bildausschnitt tut. Bewusst NICHT in derselben
  Fassung: Hier ändert sich gerade, wohin nach dem Zoomen gerollt wird, und
  wer zwei Dinge auf einmal ändert, kann den nächsten Befund nicht mehr
  zuordnen.
- **Nicht gemessen (1.0.24):** Ob der Brennpunkt jetzt steht, hat niemand
  gesehen; gerechnet ist nur, warum er in 1.0.23 nicht stand. Ob sich die
  Arbeitsfläche schieben lässt, ist weiterhin ungeklärt — neu ist allein,
  dass es sich ablesen lässt. **Nicht als erledigt darstellen.**
- **Die Rechnung stimmte — und wurde HINTERHER überschrieben** (ab 1.0.25,
  zum wiederholten Mal gemeldet 09/2026: „Sobald ich aber loslasse, ist wieder
  die linke obere Ecke im Fokus."). **Die Probe aus 1.0.24 hat entschieden, und
  sie entlastet die Geometrie vollständig:** `Soll −588/−1411 ·
  Ist −588/−1411 · Abweichung 0/−0`. `scrollTo` löst einen Anker außerhalb der
  Mitte also ein, auf den Punkt — die Frage, die seit 1.0.18 offen stand, ist
  damit beantwortet. **Nachgerechnet am Bildschirmfoto desselben Augenblicks**
  (Ballonfoto bei 69 % der Blattbreite, auf dem Schirm bei 937 pt, Blattbreite
  1606 pt am Bild nachgemessen) stand der Inhalt dort aber bei rund
  −201/−1139. **Der Versatz wird nach der Messung wieder zurechtgerückt**, in
  Richtung Ursprung. Damit heißt die Frage nicht mehr „wie rechnet man den
  Anker", sondern „wer verstellt ihn hinterher".
- **Wo etwas den Versatz später verstellt, hilft eine REGELUNG und keine
  bessere Formel** (`ReiseView.nachfuehren`, ab 1.0.25): rollen, nachsehen,
  und wenn es nicht steht, noch einmal rollen — nach 0,05 / 0,12 / 0,25 / 0,4 /
  0,7 Sekunden. Abbruch, sobald der Versatz auf einen Bildpunkt sitzt, und
  sofort beim Aufsetzen der nächsten Geste: **Wer die Finger auf dem Glas hat,
  führt** — eine laufende Nachführung zöge ihm die Seite weg. Die Zahl der
  Korrekturen steht in der Probe; geschrieben wird sie EINMAL am Ende und nicht
  bei jedem Takt, denn jede Zuweisung an `werk.letzteBuehne` zeichnet die Bühne
  neu (die Lehre aus 1.0.16) — mitten in einer Regelung wäre das genau die
  Unruhe, gegen die sie gebaut ist.
- **Ein `LazyVStack` weiß nur, wie hoch die Elemente sind, die er GEBAUT hat**
  (`ReiseView.faulAb = 12`, ab 1.0.25). 1.0.16 hat ihn eingebaut, und der Grund
  gilt weiter: Ist kein Tag gewählt, stehen dort alle Seiten des Buches. Sein
  Preis trifft aber genau diese Stelle — während nach einem Zoom Seiten gesetzt
  und Fotos geladen werden, ändert sich die Gesamthöhe, und ein `ScrollView`
  rückt seinen Versatz dann nach. Ein gewählter Tag hat zwei bis sechs Seiten;
  dort ist die Faulheit kein Gewinn und kostet die Verlässlichkeit. Gezählt
  werden ELEMENTE, nicht Seiten — eine Doppelseite trägt zwei.
- **Zwei Griffe auf einmal sind hier erlaubt, WEIL die Probe sie trennt.** Die
  Regel „eine Sache auf einmal" gilt, damit der nächste Befund zuzuordnen ist;
  hier tut das die Zeile selbst: „ohne Nachführung" heißt, die Rolle war von
  selbst still und es lag am Stapel, „n× nachgeführt" heißt, die Regelung hat
  es geradegezogen. **Wer zwei Dinge zugleich ändert, baut vorher die Messung
  ein, die sie auseinanderhält** — sonst gilt die Regel unverändert.
- **Nicht gemessen (1.0.25):** Ob es auf dem Gerät jetzt steht, hat niemand
  gesehen. Und **welcher Mechanismus den Versatz verstellt, ist nicht
  bewiesen** — die Höhenschätzung des `LazyVStack` ist die Erklärung, die zu
  den Zahlen passt, und mehr nicht. Die Nachführung wirkt unabhängig davon,
  aber sie ist ein Netz und kein Beweis. **Nicht als erledigt darstellen.**
- **`scaleEffect` ändert die ZEICHNUNG, nie die LAYOUTGRÖSSE — und ein `.frame`
  ohne Ausrichtung stellt ein kleineres Kind MITTIG hinein** (behoben in
  1.0.26, gemeldet 09/2026 zum wiederholten Mal). Zwei Zeilen in
  `SeitenflaecheView`:
  `.scaleEffect(massstab, anchor: .topLeading)` und darunter
  `.frame(width: bogen.width * massstab, height: bogen.height * massstab)`.
  Das Kind meldet weiterhin die UNSKALIERTE Bogengröße, der Rahmen ist die
  skalierte — also stand das Kind mittig darin, und gezeichnet wurde ab SEINER
  Ecke, um `bogen · (Maßstab − 1) / 2` versetzt. Der Griff ist ein Wort:
  `alignment: .topLeading`.
- **Drei Beschwerden, eine Ursache — und der Nutzer hatte sie genauer benannt
  als jede Vermutung davor.** „Es ist nicht die Seite, sondern irgendein oberer
  linker Punkt der Arbeitsfläche, den du willkürlich festgelegt hast": genau
  so, und der Punkt lag um den halben Zuwachs daneben. Dazu „am oberen Rand
  bleibt grundsätzlich Abstand bis zur eigentlichen Buchseite" (die leere
  Lücke oben links), „die untere rechte Ecke erreiche ich nie" (der Überhang
  unten rechts — gerollt wird der RAHMEN, nicht die Zeichnung) und „nicht
  wieder herauszoomen" (**was außerhalb eines Frames liegt, nimmt in SwiftUI
  keinen Finger an** — dieselbe Regel wie bei den Griffen in 1.0.2, eine Ebene
  höher; der Zoom hängt an der Fläche der Bühne). **Merke: Drei Beschwerden,
  die sich widersprechen, haben oft eine Ursache — und die Beschwerde, die eine
  GEOMETRIE beschreibt, ist die, an der man rechnen kann.**
- **Nachgemessen an zwei Bildschirmfotos, in BEIDE Richtungen.** Bei 94 % steht
  die Blattkante 93 pt vom Bühnenrand, wo `Zoomanker` 121,5 erwartet (−28,5
  gegen gerechnet −28,0); bei 187 % liegt der Inhalt um +387/+272 daneben
  (gerechnet +373,5/+266,1). Unter 100 % zeichnet es weiter oben links als der
  Rahmen, darüber weiter unten rechts — beide Vorzeichen stimmen, beide
  Beträge auch. **Eine Ursache, die nur in einer Richtung passt, ist keine.**
- **Eine Probe, die „alles in Ordnung" meldet, ist nicht gescheitert.** Die
  Zeile aus 1.0.24 nannte `Soll −588/−1411 · Ist −588/−1411 · Abweichung 0/−0`
  — und das war RICHTIG: Gerollt wurde genau dorthin, wo die Rechnung es
  wollte. Falsch war, wo die Rechnung die Seite VERMUTETE. Ohne diese Zeile
  wäre 1.0.26 die fünfte Vermutung geworden; sie hat die Geometrie entlastet
  und den Blick auf das gelenkt, was sie nicht misst. **Wer eine Probe baut,
  schreibt dazu, was sie NICHT misst** — hier: wo das Gezeichnete innerhalb
  seines Rahmens liegt.
- **1.0.25 war falsch und ist zurückgenommen.** Die Nachführung (rollen,
  nachsehen, noch einmal rollen) und der Deckel für den `LazyVStack` waren die
  Antwort auf eine Frage, die es nicht gab: Der Versatz wurde nie nachträglich
  verstellt, er war von Anfang an ein anderer, als die Rechnung annahm.
  `ReiseView` steht wieder auf dem Stand von 1.0.24. **Ein Mechanismus, dessen
  Grund widerlegt ist, bleibt nicht liegen** — sonst steht beim nächsten Befund
  eine Regelung im Weg, die niemand mehr begründen kann.
- **Nicht gemessen (1.0.26):** Gesehen hat es niemand. Gerechnet und an zwei
  Bildern nachgemessen ist die URSACHE; dass die drei Beschwerden damit weg
  sind, folgt aus der Geometrie. **Nicht als erledigt darstellen.**
- **Das Format ist kein Wort mehr, sondern zwei Zahlen** (`Seitenformat`, ab
  1.0.27, Ansage des Nutzers 09/2026: „Ich möchte verschiedene Maßvorlagen für
  die Seiten haben. DIN A4 Hochkant, DIN A4 Breit, DIN A5 dasselbe und
  quadratisch 28 x 28 cm. Ansonsten möchte ich aber auch die Möglichkeit
  haben, eine Seite frei skalieren zu können."). Bis 1.0.26 war es eine
  Aufzählung mit vier festen Fällen; ein freies Maß lässt sich darin gar nicht
  ausdrücken. Jetzt ein Wertetyp aus `breite`, `hoehe` und einem **optionalen**
  Vorlagennamen — `nil` heißt „selbst eingetippt". Sieben Vorlagen (A4 und A5
  je hoch und quer, 21, 28 und 30 cm im Quadrat), Grenzen 70 bis 500 mm je
  Kante: Darunter wären die Ränder breiter als die Seite, darüber nimmt kein
  Druckdienst dieser Größenordnung an.
- **Der Leser nimmt weiterhin den alten TEXT entgegen.** In jeder gesicherten
  Reise steht an dieser Stelle `"a4quer"`, also eine Zeichenkette und kein
  Objekt. Ohne den Einzelwert-Zweig in `init(from:)` wäre `format` beim Lesen
  auf die Vorgabe gefallen — und weil `Reise` das Feld über `wert(.format, …)`
  holt, **still**: Das Buch ginge auf, und die Seiten hätten das falsche Maß.
  Dieselbe Regel wie seit 1.0.3, nur diesmal nicht für ein neues Feld, sondern
  für ein Feld, das seine GESTALT gewechselt hat. **Wer einen Typ von einer
  Aufzählung auf eine Struktur umbaut, schreibt den Leser für beide Formen.**
- **A4 nach A5 ist EINE Multiplikation** (`Model/Formatwechsel.swift`, ab
  1.0.27, Ansage des Nutzers 09/2026: „ich hoffe, dass es eine Möglichkeit
  gibt, ohne viel Aufwand aus dem DIN A4 Projekt ein A5 Projekt zu machen").
  Die ganze A-Reihe hat dasselbe Seitenverhältnis — das ist ihre Bauvorschrift
  —, also trifft ein einziger Faktor (1/√2 ≈ 0,707) beide Kanten. Gerechnet
  wird er auf **alles, was eine Länge ist**: Blockrahmen, Ränder, Fuge,
  Bundsteg, Eckenradius, Schriftgrößen, Innenabstände, Linienbreiten. Danach
  steht jeder Block relativ an derselben Stelle und wirkt in derselben Größe;
  nur das Papier ist kleiner. Die Sorge des Nutzers („problematisch, die Größe
  der Schriften herunterzurechnen") ist damit beantwortet, solange das
  Verhältnis stimmt.
- **Der Anschnitt wird NICHT mitgerechnet.** Er ist keine Gestaltung, sondern
  eine Angabe der Druckerei: Drei Millimeter sind drei Millimeter, egal wie
  groß die Seite ist. Wer ihn mitschrumpfte, lieferte eine Datei, die formal
  stimmt und beim Schneiden den weißen Faden bekommt, wegen dem es den
  Anschnitt gibt. Ebenso bleiben **`kartenanteil`** (ein Anteil), der
  **Bildausschnitt** (`zoom` und die beiden Versätze sind Anteile am Bild —
  mitgerechnet verschöben sie jedes Foto in seinem Rahmen) und die
  **Drehung** (ein Winkel).
- **Bei UNÄHNLICHEN Formaten gilt der kleinere Faktor, und das steht dabei.**
  Von A4 hoch auf 28 × 28 cm gibt es keinen, der beides trifft; genommen wird
  `min(neu.breite/alt.breite, neu.hoehe/alt.hoehe)`, denn das ist der einzige,
  bei dem kein Block aus der Seite fällt. An einer Kante bleibt dann mehr Luft
  als vorher — der Satz wird davon nicht falsch, sieht aber danach aus, wenn
  niemand es sagt. Das Blatt sagt es.
- **Erst zeigen, dann übernehmen** (`Formatwechsel.vorschau`, `Wechselblatt`).
  Ein Formatwechsel fasst JEDEN Block des Buches an. Vorher stehen da: beide
  Formate mit Maß, der Faktor in Prozent, die Zahl der betroffenen Blöcke und
  die Fließtextgröße vorher und nachher. Dieselbe Bauweise wie bei jeder
  Einfuhr dieser App. **Zwei Wege**, weil es zwei Fragen sind: „mitrechnen"
  für ein fertiges Buch, „nur das Format wechseln" für eines, das danach
  ohnehin neu angeordnet wird. Beides hängt an `werk.merken()` und ist mit
  „Widerrufen" zurückzunehmen.
- **Das Format bekommt einen EIGENEN Bildschirm** (Gestalten → Seitenformat).
  Bis 1.0.26 war es eine Auswahlzeile im Gestaltungsblatt, zwischen Anschnitt
  und Bundsteg. Das Format ist aber die eine Entscheidung, an der alles
  andere hängt, und seit 1.0.27 rechnet sie das Buch um — das gehört nicht
  hinter einen Auswahlknopf in einer Liste. In der Gestaltung steht die
  Zeile weiterhin, jetzt aber als Auskunft mit dem Weg dorthin: **Ein
  Bildschirm, der einen Wert nur noch anzeigt, muss sagen, wo er geändert
  wird** — sonst ist er für den Menschen davor kaputt.
- **Die Broschüre ist ein BOGEN und keine Druckvorlage**
  (`Buchausgabe.broschuere`, ab 1.0.27, Ansage des Nutzers 09/2026: „Wenn dann
  noch die Möglichkeit besteht, automatisch einen Buchdruck auswählen zu
  können, so dass die Seiten des Dokumentes automatisch umsortiert werden, so
  dass ich eine doppelseitige Broschüre drucken kann."). Gesetzt wird der
  Rückenstich: Die Seitenfolge wird mit Leerseiten auf ein Vielfaches von VIER
  aufgefüllt (anders geht ein gefalteter Bogen nicht auf), dann trägt Bogen `i`
  vorn `[n−1−2i | 2i]` und hinten `[2i+1 | n−2−2i]`. Der Bogen ist doppelt so
  breit wie das Endformat.
- **Ohne TrimBox und BleedBox, mit Absicht.** Beide sagen einer Druckerei, wo
  geschnitten wird — auf einem Bogen mit zwei Seiten nebeneinander gäbe es
  dafür keine einzige richtige Stelle, und eine Schnittmarke am falschen Ort
  ist schlimmer als keine. Aus demselben Grund läuft an der Broschüre **keine
  Druckprüfung**: Sie misst genau diese beiden Kästen und meldete hier
  garantiert Falsches. Was stattdessen dasteht, ist die Rechnung selbst —
  Seiten, Leerseiten, Bogen, Bogenmaß.
- **Die Rückseiten lassen sich um 180 Grad drehen, und das ist eine Frage an
  den DRUCKER.** Ob er beim beidseitigen Druck über die lange oder die kurze
  Kante wendet, steht in keiner Datei; es ist eine Einstellung des Treibers
  und je Gerät anders. Deshalb ein Schalter mit einem Satz daneben und keine
  Automatik: Eine App, die das errät, druckt bei der Hälfte aller Geräte jede
  zweite Seite auf dem Kopf. **Das nicht als gelöst darstellen** — geprüft ist
  es erst am eigenen Drucker, mit vier Seiten Probe.
- **„Der Zoom reagiert erst beim dritten Versuch" ist ein VERDACHT mit
  Zähler, kein Befund** (ab 1.0.27, gemeldet 09/2026 neben der Rückmeldung,
  dass es jetzt funktioniere). Die naheliegende Erklärung steht im Quelltext:
  `seitenzoomErlaubt` schaltet die Zweifingergeste der Seite ab, solange ein
  Foto gewählt ist oder der Ausschnittsmodus läuft — dann gehört sie dem Bild.
  Eine zu kurze Aufziehbewegung kommt als TIPP an, der Tipp hebt die Auswahl
  auf, und der nächste Versuch geht. Das wäre genau das gemeldete Muster.
  **Gemessen ist es nicht**, deshalb steht es nicht als Ursache da, sondern
  als Zeile im Befund: „Seitenzoom: erlaubt" bzw. „gesperrt (ein Foto ist
  gewählt)" / „gesperrt (Ausschnittsmodus)", dazu zählt der `Zeichenmesser`
  Beginn und Ende jeder Geste. Sagt der Befund beim nächsten Mal „gesperrt",
  ist es das; sagt er „erlaubt" und die Geste zählt trotzdem nicht hoch, kommt
  sie gar nicht an, und das ist etwas anderes. Dasselbe Muster wie bei
  Schulalarms Stufenprobe — **nach sechs Fassungen an dieser Bühne wird hier
  nicht mehr geraten.**
- **Nicht gemessen (1.0.27):** Keine Broschüre ist gedruckt worden, und welche
  Wendeeinstellung ein bestimmter Drucker benutzt, lässt sich aus einer Datei
  nicht wissen. Die Umrechnung von A4 auf A5 ist gerechnet und nicht auf einem
  Gerät gesehen — ob ein Fließtext von 11 pt bei 7,8 pt noch angenehm zu lesen
  ist, sagt erst der Ausdruck. Und die Ursache des „dritten Versuchs" ist ein
  Verdacht, siehe oben. **Nichts davon als erledigt darstellen.**
- **Das ganze Buch steht untereinander — die Tagesliste ist eine SPRUNGMARKE**
  (ab 1.0.28, Ansage des Nutzers 09/2026: „Lieb, wenn alle Seiten fortlaufend
  untereinander stehen würden, beziehungsweise in dieser Ansicht die
  Doppelseiten, sodass man mühelos von einem Seitenpaar zum nächsten wischen
  kann, ohne dass man links die Liste der Seiten [braucht]."). Bis 1.0.27
  filterten `sichtbareSeiten` und `sichtbareDoppelseiten` nach dem gewählten
  Tag. Damit war die Liste links keine Übersicht, sondern der EINZIGE Weg
  durch das Buch: Wer die letzte Seite eines Tages sah, musste zur Liste
  greifen, um weiterzublättern. **Ein Buch blättert man, man schlägt es nicht
  neu auf.** Der Filter ist ersatzlos weg; ein Tipp in der Liste rollt jetzt
  dorthin.
- **Damit heißt „gewählter Tag" etwas anderes — und muss dem folgen, was man
  SIEHT.** Vorher hieß es „was wird gezeigt", jetzt „worauf zielt das
  Tagesmenü unten rechts, der Titel und das Neuanordnen". Wer zum 6. August
  scrollt und dann „Seiten neu anordnen" tippt, meint den 6. August und nicht
  den Tag, den er vor zehn Minuten angetippt hat — eine stillschweigend am
  falschen Tag ausgeführte Handlung ist genau die Art Fehler, die diese App
  sonst überall vermeidet. Gemeldet wird über `onAppear`/`onDisappear` der
  Reihen (`ReiseView.imBlick`, Reihennummer auf Tageskennung, die kleinste
  ist die oberste): Das fällt EINMAL je Reihe an und nicht bei jedem
  Bildpunkt — dieselbe Überlegung, aus der `Inhaltslage` kein `@State` ist.
  Aus dem Rollversatz zu rechnen wäre der naheliegende Weg und schriebe einen
  Zustand sechzigmal in der Sekunde (die Lehre aus 1.0.16).
- **Den Kreis hält auf BEIDEN Seiten dieselbe Prüfung, kein zweiter
  Schalter.** Liste → Bühne und Bühne → Liste setzen denselben Wert; ohne
  Bremse sprängen sie einander hinterher. Gebremst wird mit der Frage, ob der
  Tag schon oben im Bild steht — steht er, ist nichts zu tun, und genau daran
  erkennt die Stelle auch, dass die Änderung vom Rollen kam. Ein Merker „das
  war ich" wäre der übliche Griff und liegt bei jeder Änderung der
  Reihenfolge wieder daneben; dieselbe Überlegung wie bei
  `Liniennetz.eigeneBewegung` in der Abfahrtstafel.
- **Einzelseiten und Doppelseiten zählen ihre Reihen VERSCHIEDEN** (Seitenzahl
  gegen Bogennummer). Beim Umschalten wird `imBlick` deshalb geleert — eine
  alte Meldung wäre dort nicht bloß veraltet, sondern falsch.
- **Der Zoom hängt als `simultaneousGesture` an der Bühne** (ab 1.0.28;
  gemeldet 09/2026: „Die Geste müsste eigentlich allein der Seite gehören,
  aber trotzdem muss ich mehrere Male anfassen."). Über dem Inhalt liegt der
  `ScrollView` und damit dessen Schiebeerkenner, und der beginnt schon bei
  EINEM Finger. Zwei Finger auf einer Rollfläche sind für ihn ein Wisch; ohne
  ausdrückliche Erlaubnis zur GLEICHZEITIGEN Erkennung muss einer der beiden
  verlieren, und welcher, entscheiden die ersten Millisekunden der Bewegung.
  Das IST „mal beim ersten, mal beim dritten Versuch".
- **Das ist keine Vermutung, sondern ein Vergleich IN DIESER App.**
  `SeitenflaecheView` hängt den Zoom des Bildausschnitts seit 1.0.8 mit
  `simultaneousGesture` in denselben `ScrollView` — dieselbe Gestenart,
  dieselbe Rollfläche, derselbe Bildschirm —, und der greift; die Bühne hing
  mit `.gesture` daran, und die greift nicht verlässlich. Der Unterschied
  zwischen beiden ist dieses eine Wort. **Wo zwei gleichartige Stellen sich
  verschieden verhalten, ist ihr Unterschied die erste Spur** — und eine, die
  sich am Quelltext nachlesen lässt, statt an der Erinnerung des Nutzers.
- **Der Verdacht aus 1.0.27 ist WIDERLEGT** (Nutzer 09/2026: „ich kann dir
  versichern, dass ich kein Bild ausgewählt habe"). 1.0.27 schrieb als
  naheliegenden Grund auf, ein gewähltes Foto sperre den Seitenzoom und ein
  zu kurzes Aufziehen komme als Tipp an. Die Zeile im Befund BLEIBT trotzdem
  stehen: Sie war nie eine Erklärung, sondern eine Messung, und sie hat genau
  das getan, wofür sie gebaut war — einen Zweig ausgeschlossen. **Eine Probe,
  die eine Vermutung umwirft, ist nicht gescheitert; das ist ihr Sinn.**
  Dieselbe Bauweise wie die Zeile „Soll/Ist" aus 1.0.24, die 1.0.26 die
  Geometrie entlastet hat.
- **Nicht gemessen (1.0.28):** Gesehen hat niemand etwas davon. Dass die
  Geste jetzt verlässlich ankommt, folgt aus der Art, wie UIKit zwei Erkenner
  gegeneinander abwägt, und aus dem Vergleich mit dem Bildausschnitt —
  gemessen wird es erst durch den Zähler „Zoomgeste" im Befund. **Ein
  Nebeneffekt steht offen:** Mit `simultaneousGesture` ROLLT die Bühne
  während des Aufziehens mit; am Ende der Geste rückt sie der Brennpunkt
  wieder zurecht (so seit 1.0.18), aber ob das ruhig aussieht oder wie ein
  Ruck, sagt erst der nächste Befund. Und die Bühne trägt jetzt wieder das
  GANZE Buch: Der `LazyVStack` aus 1.0.16 ist genau dafür da, aber wie sich
  ein Buch mit zweihundert Fotos dabei anfühlt, ist weiterhin ungemessen.
- **Welche Schriften ein Gerät hat, misst die App — sie schreibt es nicht
  auf** (`Schriftfamilie` ab 1.0.29 ein Wertetyp, `Model/Buchstabenform.swift`,
  `Views/SchriftwahlView.swift`; Ansage des Nutzers 09/2026: „Ich möchte noch
  weitere Schriftarten verwenden. Standardmäßig möchte ich eine serifenlose
  Schrift verwenden, bei der das kleine A so aussieht wie bei der Systemschrift
  Futura. Futura selbst ist mir etwas zu dick gedruckt. Bitte finde dort
  Alternativen."). Bis 1.0.28 war die Auswahl eine Aufzählung mit sechzehn
  Namen, die jemand einmal aufgeschrieben hatte. Welche Schriften ein iPad
  wirklich mitbringt, entscheidet aber das Gerät und ändert sich mit jeder
  iOS-Fassung. Jetzt steht dort der FAMILIENNAME, und gezeigt wird, was da ist.
  Dieselbe Umstellung wie beim `Seitenformat` in 1.0.27 — samt demselben
  Leser: Alte Dateien tragen `"futura"` als Text, und ohne den Einzelwert-Zweig
  fiele die Schrift beim Lesen STILL auf die Vorgabe zurück.
- **Der SCHNITT ist der eigentliche Grund für den Umbau.** Bis 1.0.28 baute
  `uiFont` den Deskriptor allein aus dem Familiennamen — damit kam immer der
  Regelschnitt und nie ein leichterer, den eine Familie vielleicht hat. „Futura
  ist mir etwas zu dick gedruckt" ist genau diese Lücke. Sie ist jetzt
  geschlossen, soweit sie sich schließen lässt: **Futura liefert iOS nur ab
  Medium aufwärts** — einen Buch- oder Light-Schnitt gibt es dort nicht, und
  wo keiner ist, steht auch keiner in der Liste. Das sagt die Oberfläche
  ausdrücklich, statt eine Einstellung anzubieten, die nichts ändert.
- **Ob ein kleines a rund ist, wird an der GLYPHE gemessen**
  (`Buchstabenform`). Der Unterschied zwischen einem einstöckigen a (Futura:
  ein Kreis mit Stamm) und einem zweistöckigen (Helvetica: eine Schale unten
  mit einem Bogen darüber) steckt in der GEGENFORM, also im Loch: Beim
  einstöckigen füllt sie fast die ganze Buchstabenhöhe, beim zweistöckigen gut
  ein Drittel. **Nachgemessen an elf Schriftdateien** (22.09.2026, dieselbe
  Rechnung in Python nachgezogen): zweistöckig 0,362 bis 0,468 (Liberation
  Sans/Serif/Mono, DejaVu Sans/Serif, FreeSans, FreeSerif, Loma), einstöckig
  0,719 bis 0,913 (Poppins, Questrial, Josefin Sans). Zwischen 0,468 und 0,719
  liegt eine breite Lücke; die Schwelle steht mittig darin.
- **Welche Kontur die äußere ist, entscheidet das UMFASSEN und nicht die
  Fläche — und wo keine alle anderen umfasst, gibt es KEINE Antwort.** Das ist
  an einer echten Schrift gelernt: **Jost zeichnet sein a aus zwei einander
  überlappenden Formen** statt aus Umriss und Loch. Nach der Fläche gerechnet
  gewann dort die falsche Kontur, und heraus kam „zweistöckig" für eine
  Schrift, die einstöckig ist. Jetzt schweigt die Messung in diesem Fall und
  sagt das auch. **Eine Messung, die im Zweifel etwas behauptet, ist schlechter
  als eine, die schweigt** — dieselbe Regel wie bei „Plan" gegen „pünktlich".
- **Jede Zeile der Schriftwahl ist in ihrer eigenen Schrift gesetzt**, mit
  einem Wort, das drei kleine a trägt. Das ist mehr wert als jede Messung: Wer
  die Form des a sucht, sieht sie. Die Messung ordnet nur die Liste und nennt
  ihre Zahlen unter der Probe — nachlesbar, nicht geglaubt.
- **Mitgeliefert wird weiterhin keine Schriftdatei.** Ein Buch wird
  weitergegeben, und dafür bräuchte jede Schrift eine Lizenz. Was zur Wahl
  steht, bringt das Gerät mit; ob es sich einbetten lässt, sagt seit 1.0.1 die
  Druckprüfung aus der OS/2-Tabelle.
- **Ein `NavigationLink` im Inspektor ist ein Knopf, der nichts tut** (ab
  1.0.29, beim Bau bemerkt). `BlockInspektor` ist eine `.inspector`-Spalte und
  bringt keinen eigenen Navigationsstapel mit — dieselbe Falle wie bei den
  Fahrplanzielen der Abfahrtstafel. Die Schriftwahl liegt dort deshalb als
  BLATT mit eigenem Stapel, und der Block wird darin neu nachgeschlagen statt
  hineingereicht: Ein mitgegebener Block wäre der Stand von dem Augenblick, in
  dem das Blatt aufging.
- **Einen Block auf eine andere Seite schieben — als BEFEHL und nicht als
  Geste** (`Reisewerk.blockVerschieben`, `blockAufNeueSeite`, Abschnitt „Auf
  welcher Seite" im Inspektor, ab 1.0.29; Ansage des Nutzers 09/2026: „ich
  möchte ein Bild problemlos von einer Seite auf eine andere schieben können
  beziehungsweise auch andere Elemente wie zum Beispiel Textfelder."). Eine
  Ziehgeste, die ein Blatt verlässt, müsste MITTEN im Ziehen entscheiden, zu
  welcher Seite der Finger gerade gehört — in einer Bühne, die sich dabei rollt
  und zoomt. Das ist die Art Ziehgeste, die dieses Projekt von 1.0.5 bis 1.0.8
  gekostet hat und deren Zoom bis 1.0.28 nicht stand. **Ein Knopf, der immer
  tut, was draufsteht, ist hier mehr wert als eine Geste, die meistens tut, was
  gemeint war.**
- **Die Lage auf dem Blatt bleibt beim Verschieben, wie sie ist.** Den Block
  auf der neuen Seite zu zentrieren wäre bequemer und verschöbe etwas, das
  niemand angefasst hat. Danach trägt er `vonHand` — ein Neuanordnen, das ihn
  stillschweigend zurückholte, nähme genau die Entscheidung zurück, die jemand
  gerade getroffen hat. **Verschoben wird innerhalb EINES Tages:** Über
  Tagesgrenzen hinweg ist es keine Frage der Seite mehr, sondern der Zuordnung
  (`tag.fotos`), und die wird dort beantwortet, wo sie gestellt wird — in der
  Fotoliste des Tages.
- **„Text und Bilder im Wechsel" ist ein eigenes Muster, kein neuer Name**
  (`Seitenmuster.wechsel`, ab 1.0.29; Ansage des Nutzers 09/2026: „Bei den
  Vorlagen vermisse ich etwas … Ich möchte ein Reisetagebuch mit sehr viel Text
  mit ebenfalls sehr vielen Bildern verknüpfen."). `reihenSetzen` wechselt seit
  1.0.14 auf den FOLGESEITEN zwischen Text und Fotoreihen — die ERSTE Seite war
  davon ausgenommen: Dort füllte der Text bis zum Satzspiegelende, und das
  erste Bild stand eine Seite weiter. Bei einem Tag mit viel von beidem ergibt
  das genau den gemeldeten Eindruck: erst ein Kapitel Text, dann eines mit
  Bildern. Das neue Muster hält auf der ersten Seite die ZIELHÖHE der nächsten
  Fotoreihe frei — dieselbe Zahl, mit der `reihenSetzen` weiterrechnet, und
  kein geschätzter Anteil. Bleiben daneben keine sechs Zeilen Text mehr, wird
  gar nichts freigehalten; eine Seite mit vier Zeilen über einem Bild ist kein
  Satz, sondern ein Rest.
- **Die Schwelle ist hoch mit Absicht** (über 1200 Zeichen UND mindestens vier
  Fotos). Ein Tag mit drei Sätzen und zwei Bildern ist damit nicht gemeint und
  bekommt weiter, was er vorher bekam. Das Muster steht in allen fünf
  Buchstilen an erster Stelle — es greift also überall, aber nur für die Tage,
  um die es geht.
- **Nicht gemessen (1.0.29):** Welche Schriften auf dem iPad des Nutzers ein
  rundes a haben, weiß hier niemand — die Messung läuft auf dem Gerät, und
  erst die Liste dort sagt, ob Futura Gesellschaft bekommt. Gut möglich, dass
  die Gruppe dünn ausfällt: Unter den Schriften, die iOS mitbringt, ist ein
  einstöckiges a selten. **Sollte dort nichts Brauchbares stehen, ist der
  nächste Schritt eine mitgelieferte Schrift unter der SIL Open Font License**
  (die erlaubt Einbettung und Weitergabe ausdrücklich, und dieses Repo führt in
  `woerterwerkstatt/fonts/` bereits solche Dateien) — das wäre aber eine
  Abkehr von der Regel oben und gehört ausdrücklich abgesprochen, nicht
  nebenbei gemacht. Ebenso ungesehen: ob das Verschieben auf eine andere Seite
  sich richtig anfühlt und wie eine Doppelseite im neuen Muster aussieht.
- **„Alle auswählen" kann Apples Fotowähler nicht — ein ZEITRAUM kann es**
  (`Dienste/Zeitraumeinfuhr.swift`, ab 1.0.30, gemeldet 09/2026: „Beim Foto-Import
  muss ich bislang die Fotos einzeln auswählen. Ich möchte, dass sie alle
  ausgewählt werden können."). Die Mehrfachauswahl war nie beschränkt
  (`selectionLimit = 0` steht seit 1.0.0 dort); was fehlt, ist der eine Knopf, und
  der gehört nicht uns: `PHPickerViewController` läuft in einem EIGENEN Prozess —
  genau deshalb darf er ohne Mediathekserlaubnis arbeiten, und genau deshalb kann
  ihm keine App etwas hinzufügen. Gefragt wird deshalb nicht nach Bildern, sondern
  nach einem Zeitraum: **Eine Reise IST ein Zeitraum**, und die Mediathek gibt ihn
  über ein Prädikat auf `creationDate` her, sobald die Erlaubnis da ist, die diese
  App ohnehin für die Aufnahmeorte braucht.
  - **Gezählt wird, bevor etwas geladen wird** („Gefunden: 1284 Fotos"). Ein Knopf,
    der ungefragt tausend Dateien holt, ist ein Sprung ins Dunkle.
  - **Geholt wird Foto für Foto**, und zwar auf BEIDEN Wegen. Tausend Rohbilder
    sind mehrere Gigabyte; der Fotowähler sammelte sie bis 1.0.29 erst alle in
    einer Liste, was tragbar war, solange man einzeln antippt. `fotosAufnehmen`
    gibt es seit 1.0.30 zweimal — als Liste und als Strom —, und die Liste ruft
    den Strom: **Es gibt nur EINE Stelle, an der ein Rohbild zu einem `Foto`
    wird.**
  - **`isNetworkAccessAllowed = true`, ausdrücklich.** Ein Foto kann in iCloud
    liegen; ohne diese Zeile käme gar nichts zurück, ohne Fehler — der Zeitraum
    sähe halb leer aus.
  - **`requestImageDataAndOrientation` darf seinen Rückruf MEHRMALS aufrufen.** Ein
    zweites `resume` an einer `CheckedContinuation` ist kein Fehler, sondern ein
    Absturz; daher der Wächter `Einmal`.
  - Die Grenzen des Zeitraums entstehen in der GERÄTEZONE — dieselbe ausdrückliche
    Ausnahme wie beim Datum aus der Mediathek. Bei `.limited` liefert die Abfrage
    nur die freigegebenen Fotos, und die Fußzeile sagt das.
- **„Wenn das Datum fehlt" war ZWEIERLEI** (ab 1.0.30, gemeldet 09/2026: „wenn das
  Datum fehlt, dann liegen sie in der Ablage. Das möchte ich nicht. Ich möchte,
  dass bei einem fehlenden Datum der Tag einfach automatisch angelegt wird."). Der
  TAG wurde immer schon angelegt — `Reise.tagIndex(fuer:)` hängt einen Reisetag an,
  sobald ein Foto ein Datum trägt, das es im Buch noch nicht gibt. In die Ablage kam
  nur, was GAR KEIN Datum trägt. Die Fußzeile des Einlesen-Blattes sagte das so
  verkürzt, dass es wie das Gegenteil klang. **Merke: Ein Befund über eine Funktion
  kann ein Befund über ihren Beschreibungstext sein** — erst prüfen, was die App
  wirklich tut, bevor man sie umbaut.
- **Die dritte Datumsquelle ist der DATEINAME** (`Dienste/Namensdatum.swift`, ab
  1.0.30). Der häufigste Grund für ein fehlendes EXIF-Datum ist kein fehlendes
  Datum, sondern eine Datei, die durch einen Messenger oder eine Bildbearbeitung
  gelaufen ist: Die Metadaten sind weg, der NAME steht noch da
  (`IMG_20260812_193321.jpg`, `PXL_20260812_173321123.jpg`, `2026-08-12 19.33.21.jpg`,
  `Foto 12.08.2026.jpg`). Es gilt dieselbe Regel wie überall: **Der Tag kommt aus
  drei Zahlen** — ein Dateiname trägt Ziffern und keine Zeitzone, hier wird nichts
  umgerechnet; der Zeitpunkt daneben ist wie beim EXIF-Datum ein Sortierschlüssel in
  fester Zone.
  - **Geraten wird NICHT.** Drei Schreibweisen, und eine Ziffernfolge anderer Länge
    wird nicht beschnitten; das Jahr muss zwischen 1990 und 2100 liegen — enger als
    `Tagesdatum.gueltig`, weil ein Dateiname die schwächere Quelle ist. Aus
    `IMG_1234.jpg` wird kein Datum. Irgendeine Ziffernfolge als Datum zu lesen legte
    ein Foto still auf einen erfundenen Tag, und das ist der Fehler, den man dem
    gedruckten Buch nicht ansieht.
  - **`deletingPathExtension` schneidet stur hinter dem letzten Punkt ab.** Bei
    „2026.08.12" ohne Endung nähme es den Tag mit — gelesen wird erst ohne Endung,
    dann mit.
- **Wo gar kein Datum übrig bleibt, entscheidet der MENSCH, und zwar vorher**
  (`Fotoziel`, Zeile „Fotos ohne Datum" im Einlesen-Blatt, ab 1.0.30). Ein Foto ohne
  jede Datumsangabe trägt keine Auskunft darüber, wann es aufgenommen wurde — an
  WELCHEN Tag es geht, ist eine Entscheidung und keine Messung. Vorbelegt mit dem
  ersten Reisetag, Ablage nur, solange es gar keinen Tag gibt; der Bericht nennt den
  Tag hinterher beim Namen. Einen Tag mit erfundenem Datum anzulegen wäre der
  naheliegende Griff und der falsche: `Reisetag` ist über sein `Tagesdatum`
  geschlüsselt, und ein erfundenes stünde für immer im Buch. Der Weg über „Dateien"
  hat keinen eigenen Bildschirm und nimmt dieselbe Vorgabe.
- **Was keine Aufnahmezeit hat, kommt ans ENDE des Tages** (ab 1.0.30). Bis dahin
  stand in der Sortierung `.distantPast`, und das war folgenlos, solange ein Tag gar
  kein undatiertes Foto tragen konnte. Jetzt wäre es die falsche Richtung: Es schöbe
  sich vor den Morgen eines Tages, über den es nichts aussagt. Dieselbe Regel wie
  beim Handpunkt ohne Uhrzeit in der Reisespur.
- **Ein Feld, das nie gelesen wird, ist ein halb gebautes Vorhaben** (beim
  Gegenlesen von 1.0.30 wieder ausgebaut). Der erste Entwurf trug eine Aufzählung
  `Datumsquelle` am `Bildbefund` — geschrieben an drei Stellen, gelesen an keiner.
  Gezählt wird ohnehin dort, wo die Quelle greift, und der Einfuhrbericht nennt die
  Zahlen. Dieselbe Lehre wie beim Kartenausschnitt in 1.0.11, nur diesmal vor dem
  Ausliefern bemerkt.
- **Nicht gemessen (1.0.30):** Nichts davon ist auf einem Gerät gesehen. Gerechnet
  ist, wie ein Name zerlegt wird und was die Mediathek auf eine Zeitraumabfrage
  herausgibt; ob eine bestimmte Kamera so benennt, sagt erst der Einfuhrbericht des
  Nutzers. Ebenso ungemessen, **wie sich ein Zeitraum mit tausend Fotos anfühlt** —
  das Einlesen läuft auf dem Hauptfaden und gibt zwischen zwei Fotos ab. Und ob
  `PHPickerResult.itemProvider.suggestedName` wirklich den ursprünglichen Dateinamen
  trägt, ist die Lesart der Dokumentation und keine Messung. **Nicht als erledigt
  darstellen.**
- **Der freigehaltene Streifen gehört der REIHE, nicht dem Text** (ab 1.0.31,
  gemeldet 09/2026: „Es gibt einen riesigen Textblock und danach werden die Bilder
  auf die Seite geknallt."). Das ist am Quelltext nachzurechnen und passt zum
  Bildschirmfoto: `.wechsel` hält auf der ersten Seite die gemessene Höhe der
  nächsten Fotoreihe frei (seit 1.0.29) — und `reihenSetzen` prüft zu Beginn jeder
  Seite NOCH EINMAL selbst, ob neben einer Reihe sechs Zeilen Text Platz haben.
  Auf genau diesem Streifen haben sie das nicht, also gab die Prüfung null zurück
  und der ganze Rest ging an den Text. Ging dem Text dabei die Luft aus, blieb
  unten Weiß stehen und die Reihe passte nicht mehr: neue Seite, nur Bilder.
  **Wer Platz für ein Bild freihält, stellt das Bild auch hinein** — reicht die
  Resthöhe für eine Reihe, aber nicht für Reihe UND sechs Zeilen, bekommt sie die
  Reihe. **Merke: Wenn zwei Stellen dieselbe Frage stellen, muss die zweite die
  Antwort der ersten kennen.**
- **Jede Seite bekommt ein eigenes Seitenbild** (`Model/Seitenrhythmus.swift`, ab
  1.0.31, Ansage des Nutzers 09/2026: „Dabei soll nicht jede Seite gleich aussehen
  … Mal soll der Textblock oben links sein, mal in der Mitte, mal leicht
  verschoben, vielleicht auch sogar einmal gedreht."). Verteilt wurde seit 1.0.14;
  was fehlte, war das Zweite — Textspalte über die volle Satzbreite, darunter
  randbündige Fotoreihen, Seite für Seite dasselbe. **Ein Buch, dessen Seiten sich
  nur im Inhalt unterscheiden, ist gesetzt wie eine Tabelle.**
  - **Sechs Seitenbilder in FESTER Folge**, der Einstieg aus `UUID.saat` des
    Tages — sonst begänne jeder Tag mit demselben Bild, also derselbe Befund eine
    Ebene höher. **Nie aus `hashValue`**: Den streut Swift je Programmlauf neu,
    und dasselbe Buch sähe nach jedem Start anders aus (dieselbe Falle wie bei
    den Linienfarben der Abfahrtstafel und beim Papierkorn in 1.0.16).
  - **Die Liste ist eine FOLGE, keine Menge.** Auf eine volle Breite folgt eine
    schmale, auf einen linken Block ein rechter. Wer etwas einfügt, ordnet ein.
  - **Die Spanne ist eng mit Absicht** (58 bis 100 Prozent Spaltenbreite, linke
    oder rechte Kante). Einen frei im Blatt schwebenden Kasten gibt es NICHT: Ein
    Buch, dessen Ränder von Seite zu Seite springen, wirkt nicht lebendig,
    sondern unfertig.
  - **Gedreht und gestaffelt wird nur, wo es hingehört** (`Buchstil.lebendig` —
    Fotoalbum und Postkarte ja, Magazin, Journal und Klar nein). In einem Magazin
    wäre ein schiefes Bild ein Fehler, in einem Album fehlte es.
  - **Die Drehung des Textblocks ist auf 0,6 Grad gedeckelt, und die gehobene
    Ecke wird MITGERECHNET.** Ein halbes Grad auf 400 Punkt Breite sind gut
    dreieinhalb Punkt — weniger als die Fuge, aber nicht nichts; wer es nicht
    dazurechnet, verlässt sich darauf, dass es schon passen wird. Mehr als ein
    Grad liest sich nicht als Absicht, sondern als Druckfehler.
  - **Den Rhythmus bekommt NUR `.wechsel`.** Die übrigen Muster sind je eine
    eigene Bildidee; wandernde Spalten würden dort mit der Idee des Musters
    streiten. Es wird eine Sache auf einmal geändert.
- **Ein Menü, das seinen eigenen Stand verschweigt, lässt einen raten** (ab
  1.0.31, gemeldet 09/2026: „Die angekündigte Option Tagebuch, Text und Bilder im
  Wechsel finde ich nicht."). Fünfte Auflage von „es war da, man fand es nicht",
  diesmal doppelt: Der Menüpunkt hieß **„Seitenmuster"** — ein Fachwort statt
  einer Frage — und lag hinter einem Knopf, der nur ein KALENDERSYMBOL trug, also
  einer von vier gleich aussehenden Kreisen in der Werkzeugleiste war. Jetzt
  trägt der Knopf das DATUM sichtbar, der Menüpunkt heißt „Seiten setzen: …" und
  nennt, was gerade gilt (ausdrücklich gewählt oder „automatisch (…)").
- **„Für ALLE Tage übernehmen" steht dort, wo die Frage entsteht**
  (`Reisewerk.musterFuerAlle`, ab 1.0.31) — im Menü des einzelnen Tages. Wer für
  einen Tag einstellt, wie seine Seiten gesetzt werden, ist genau die Person, die
  als Nächstes „und für alle?" fragt; dieselbe Lehre wie beim Fotostil in 1.0.10.
  **Tage mit Handarbeit bleiben dabei stehen und werden gezählt**: Ein
  Musterwechsel, der eine Stunde Handarbeit stillschweigend wegräumt, wird genau
  einmal benutzt.
- **Nicht gemessen (1.0.31):** Wie eine Doppelseite im neuen Rhythmus AUSSIEHT,
  hat niemand gesehen. Gerechnet ist die Ursache des vollen Textblocks; die sechs
  Seitenbilder und ihre Zahlen sind gewählt und nicht gemessen — ob die Folge
  abwechslungsreich wirkt oder unruhig, sagt erst der nächste Befund. Ebenso
  ungeprüft, ob ein leicht gedrehter Textblock im PDF sauber steht. **Nicht als
  erledigt darstellen.**
- **„Tagebuch" ist ein STIL, kein Seitenmuster** (`Buchstil.tagebuch`, ab
  1.0.32; Ansage des Nutzers 09/2026: „Die Option Tagebuch finde ich nach wie
  vor nicht. Ich möchte, dass sie dort eingefügt wird, wo die anderen Optionen
  sind. Nämlich da, wo ich Fotobuch und Magazin auswählen kann."). Es gab
  „Text und Bilder im Wechsel" seit 1.0.29 — als `Seitenmuster`, also hinter
  dem Tagesmenü, dort, wo man einen EINZELNEN Tag anders setzen lässt. 1.0.31
  hat dieses Menü findbar gemacht, und der Nutzer hat es trotzdem nicht
  gefunden: **Er hat nicht an der falschen Stelle gesucht, es lag an der
  falschen.** Ein durchgehend erzählendes Buch ist eine Handschrift und kein
  Sonderfall eines Tages. Fünfte Auflage von „es war da, man fand es nicht" —
  und die erste, bei der nicht der Weg zu kurz war, sondern die Sache am
  falschen Ort stand. **Merke: Wird etwas zum zweiten Mal nicht gefunden, ist
  nicht der Weg dorthin zu prüfen, sondern die Zuordnung.**
- **Ein sechster Stil ist EINE Zeile** (`Buchstil.alle`). `StilView` läuft über
  diese Liste; wer einen Stil anlegt und dort nicht einträgt, hat ihn gebaut
  und nicht ausgeliefert. Das Muster `.wechsel` steht in `tagebuch` an erster
  Stelle der `musterVorliebe` — es steht das auch in allen fünf anderen Stilen,
  greift dort aber erst ab 1200 Zeichen und vier Fotos; der Unterschied ist
  nicht das Muster, sondern Schrift, Papier, Fugen und `lebendig`. Und
  `Seitenmuster.wechsel` heißt seither nicht mehr „Tagebuch: …": Zwei Dinge
  mit demselben Namen sind eines zu viel.
- **Ein Tag fängt mit einem Bild an** (Aufmacherband, ab 1.0.32). Befund des
  Nutzers zu 1.0.31: „Ich finde sie nach wie vor sehr nüchtern." Die Seiten
  waren richtig gesetzt und sahen aus wie ein Bericht — Kopfzeile, Textspalte,
  darunter eine Reihe gleich hoher Bilder. Im Muster `.wechsel` steht jetzt
  unter der Kopfzeile ein Bild über die **ganze Satzbreite**, auch wenn die
  Textspalte darunter schmaler ist: Genau dieser Unterschied macht es zum
  Aufmacher. Es kostet ein Foto aus dem Vorrat, deshalb erst ab dreien — bei
  zweien wäre die Reihe darunter leer, und der Tag sähe ärmer aus statt
  reicher. Höhe ein Drittel der Satzhöhe; die Zahl ist **gewählt und nicht
  gemessen**.
- **Die letzte Seite eines Tages war die verschenkte**
  (`ausfuellendesZiel`, `stapelhoehe`, ab 1.0.32). Zweiter Teil desselben
  Befundes: „es wird häufig Platz verschenkt." Am Quelltext nachzurechnen und
  keine Vermutung: `zielhoehe(fuer:)` leitet die Reihenhöhe allein aus der
  ZAHL der Kacheln ab und sieht die Seite nie an. Solange viele Bilder warten,
  ist das richtig — die nächste Reihe füllt ohnehin nach. Auf der letzten Seite
  warten aber oft nur noch zwei oder drei: Eine Reihe steht oben, darunter
  bleibt die halbe Seite weiß. Und `restplatzVerteilen` hilft dort **prinzipiell
  nicht** — es verteilt die Lücken ZWISCHEN den Reihen, und bei einer einzigen
  Reihe gibt es keine.
  - **Vergrößert wird nur, wenn ALLES Offene auf diese eine Seite passt und
    kein Text mehr wartet.** Sonst gehört der Platz dem Text bzw. füllt die
    nächste Reihe die Seite ohnehin. Damit ist die Änderung eng auf den
    gemeldeten Fall begrenzt und lässt jede andere Seite, wie sie war.
  - **Gesucht wird in Schritten, nicht gerechnet.** Eine größere Zielhöhe nimmt
    Kacheln aus den Reihen heraus und kann damit eine Reihe MEHR ergeben — der
    Zusammenhang ist nicht monoton, eine geschlossene Formel gäbe es nicht.
    Gehalten wird der letzte Wert, der nachweislich passte.
  - **Gemessen wird mit derselben Funktion, die auch setzt** (`naechsteReihe`,
    samt Staffelhub). Eine zweite Schätzung daneben liefe auseinander, und dann
    hielte die Seite nicht, was die Probe sagt.
- **Wer entscheidet, ob Handarbeit stehen bleibt, ist der Nutzer** (ab 1.0.32,
  Ansage 09/2026: „Ich möchte außerdem die Option haben, wenn ich eine
  Gestaltungsansicht ändere, dass auch bereits bearbeitete Seiten wieder
  zurückgesetzt werden. Ich möchte das frei entscheiden können."). Bis 1.0.31
  wurden von Hand bearbeitete Tage beim Stilwechsel IMMER verschont. Die
  Vorsicht ist richtig — eine Automatik, die eine Stunde Handarbeit ohne
  Rückfrage überschreibt, benutzt man genau einmal. Falsch war, daraus eine
  Regel zu machen: Wer den Stil wechselt, will das ganze Buch anders haben, und
  dann stehen ein paar Seiten im alten Satz mitten darin. Gefragt wird
  weiterhin, nur ist die Antwort jetzt eine **Wahl** („Bearbeitete Seiten
  behalten" / „Alles neu setzen") und keine Ansage. **Merke: Eine Rückfrage,
  die nur eine Antwort zulässt, ist keine Rückfrage.** Die Zahl der betroffenen
  Tage steht in der Meldung — „an einigen Tagen" lässt einen raten, ob es um
  einen geht oder um zwanzig; gezählt wird beim TIPP und nicht im Körper der
  Ansicht (dieselbe Falle wie bei der Druckprüfung in 1.0.0).
- **Eine pauschale Ersetzung trifft auch BEZEICHNER** (Selbstfund beim Bau von
  1.0.32). Beim Geradeziehen von Umlauten in Kommentaren wurde aus `gehoert`
  ein `gehört` — auch im Funktionsnamen; `ReiseView` rief danach etwas, das es
  nicht mehr gab. Gemeldet hat es der Bau, nicht
  `scripts/swift-quelltext-pruefen.py`: Der sieht String-Literale an und keine
  Bezeichner. **Wer Umlaute in Kommentaren richtet, prüft vorher, ob dieselbe
  Zeichenfolge auch in einem Bezeichner vorkommt** — deutsche Namen im
  Quelltext sind in diesem Repo die Regel, also ist es nicht der Sonderfall,
  sondern der Normalfall.
- **Nicht gemessen (1.0.32):** Keine Seite ist damit gesehen worden. Gerechnet
  ist, WARUM unten Platz blieb; dass die Seite jetzt gefüllt aussieht, folgt
  aus der Geometrie. Die Zahlen sind **gewählt und nicht gemessen**: ein
  Drittel der Satzhöhe fürs Band, Deckel 2,2 und Schrittweite 1,05 beim
  Füllen, die Schwellen 600 Zeichen und drei Fotos. Ob der neue Stil auf einem
  Gerät nach Tagebuch aussieht, sagt erst der nächste Befund. **Zwei Dinge auf
  einmal geändert** (Aufmacher und Füllung) — das ist hier vertretbar, weil sie
  sich auf der Seite nicht verwechseln lassen: ein breites Bild oben ist der
  eine, größere Reihen unten der andere.
- **Eine LEERE Seite war keine Handarbeit — und verschwand deshalb**
  (`Seite.vonHandAngelegt`, ab 1.0.33). `Seite.vonHand` war ausschließlich
  GERECHNET: „irgendein Block auf dieser Seite wurde angefasst". Eine von
  Hand eingefügte leere Seite trägt aber keinen Block; sie galt damit als
  unberührt, und das nächste Neuanordnen des Tages räumte sie weg, ohne ein
  Wort. Damit war „Seite anfügen" seit 1.0.0 eine Zusage, die beim nächsten
  Handgriff daneben zurückgenommen wurde. Daneben steht jetzt ein
  GESPEICHERTER Vermerk.
  - **Er steht an der SEITE und nicht am Tag.** `Seite.vonHand` ist die eine
    Stelle, durch die alles fragt — `hatHandarbeit`, `alleNeuAnordnen`,
    `handarbeitstage`, die Marke in der Tagesliste, die Rückfrage beim
    Stilwechsel. Ein zweites Feld am Tag müsste an jeder davon einzeln
    beachtet werden, und die eine vergessene Stelle wäre wieder ein stiller
    Verlust.
  - **Auch das ENTFERNEN und das VERSCHIEBEN einer Seite setzen ihn**
    (`Reisewerk.seitenfolgeGemerkt`). Wer an der Seitenfolge arbeitet, hat
    von Hand gearbeitet; ohne den Vermerk holte das nächste Neuanordnen die
    Seite zurück, als wäre nichts gewesen. Welche Seite ihn trägt, ist
    gleichgültig — gefragt wird überall nur, OB der Tag Handarbeit enthält.
  - Das Feld ist neu und NICHT optional, `Seite` liest sich aber seit 1.0.12
    von Hand (`b.wert(.vonHandAngelegt, false)`) — ein Buch von gestern
    öffnet sich unverändert.
- **Seiten an bestimmten Stellen** (`Views/SeitenView.swift`,
  `Reisewerk.seiteEinfuegen`, ab 1.0.33; Ansage des Nutzers 09/2026: „Für die
  manuelle Bearbeitung brauche ich die Option Seiten an bestimmten Stellen
  hinzufügen zu können oder eben auch löschen zu können."). Bis 1.0.32 gab es
  dafür zwei halbe Wege: „Seite anfügen" im Tagesmenü hängte immer HINTEN an,
  und „Diese Seite entfernen" stand im Block-Inspektor — also dort, wo man
  einen Block bearbeitet, und nur für die Seite, auf der der gewählte Block
  gerade liegt. Eine bestimmte Stelle ließ sich damit gar nicht ansprechen.
  - **Eine LISTE mit Nummern, keine Miniaturbilder.** Eine Nummer ist die
    einzige Angabe, mit der sich eine Stelle benennen lässt; daneben steht,
    was auf der Seite steht („2 Texte · 3 Fotos"), sonst wäre es eine Folge
    von Zahlen, von denen sich keine wiedererkennen lässt.
  - **`seiteHinzufuegen` ist seither der Sonderfall „einfügen ganz hinten"**
    und keine zweite Funktion daneben — zwei Fassungen desselben Anfügens
    liefen auseinander.
  - **Die letzte Seite eines Tages bleibt stehen.** Ein Tag ohne Seite wäre
    ein Loch im Buch, und `fehlendeSeitenNachholen` setzte ihn beim nächsten
    Öffnen ohnehin neu.
  - **Unter der Liste steht, was die Handarbeit KOSTET:** Der Tag wird danach
    beim automatischen Neuanordnen übersprungen. Wer das nicht weiß, hält den
    Automaten für kaputt.
- **Ein Buch duplizieren heißt ZWEI Hälften kopieren** (`Regal.duplizieren`,
  `Bildarchiv.ordnerKopieren`, ab 1.0.33; Ansage des Nutzers 09/2026: „Ich
  möchte ein Projekt duplizieren können."). Ein Buch ist eine JSON-Datei UND
  ein Ordner voller Bilder. **Ein Buch mit fremdem Bilderordner wäre eine
  Zeitbombe**: `Ablage.loeschen` räumt den Ordner der Reise mit weg — wer die
  Kopie löscht, nähme dem Urbuch alle Fotos mit, und zwar still, denn das
  Buch öffnet sich ja weiterhin.
  - **Die INNEREN Kennungen bleiben, wie sie sind**, und das ist kein
    Versehen: Tage, Seiten, Blöcke und Fotos gelten innerhalb eines Buches,
    und zwei Bücher sehen einander nie. Mehr noch — sie MÜSSEN bleiben, denn
    Papierkorn und Seitenrhythmus rechnen aus `UUID.saat`; mit neuen
    Kennungen sähe die Kopie anders aus als das Urbuch. **Tafelbild hat
    1.4.5 das Gegenteil gelernt** („Eine Kopie erbt keine Kennungen") — dort
    lagen die Kopien in DERSELBEN Tafel, und dann ist eine doppelte Kennung
    wirklich eine. Neu ist genau eine Zahl: die der Reise, denn die ist der
    Dateiname.
  - **Die Dateinamen der Bilder bleiben ebenfalls.** Sie gelten innerhalb
    eines Ordners; sie umzubenennen hieße, jede Fotoangabe im kopierten Buch
    mitzuziehen, ohne dass irgendetwas besser würde.
  - **Halb kopiert wird zurückgenommen.** Scheitert das Sichern, wird der
    schon angelegte Bilderordner wieder weggeräumt — ein Buch ohne seine
    Bilder sieht aus wie eines, dem die Fotos abhandengekommen sind.
  - **Die Bilder gehen ABSEITS des Hauptfadens** (`Task.detached`), und
    `duplizieren` ist `@MainActor`, weil `neuLesen()` am Ende `@Published`
    schreibt: Eine nicht isolierte `async`-Funktion läuft im
    Nebenläufigkeits-Pool und nicht beim Aufrufer.
  - **Zwei Wege, eine Stelle:** Wischgeste und Kontextmenü im Regal, dazu
    „Dieses Buch duplizieren" im `…`-Menü des offenen Buches — dort mit
    `sofortSichern()` davor, sonst fehlte der Kopie, was in den letzten
    Minuten getan wurde.
- **Nicht gemessen (1.0.33):** Nichts davon ist auf einem Gerät gesehen.
  Gerechnet ist, WARUM eine leere Seite verschwand (`vonHand` ist eine
  berechnete Eigenschaft über die Blöcke, und eine leere Seite hat keine) —
  dass sie jetzt stehen bleibt, folgt daraus. **Wie lange das Kopieren eines
  Buches mit zweihundert Fotos dauert, ist nicht gemessen**: Es läuft abseits
  des Hauptfadens und sperrt die Liste so lange, aber ob dabei eine
  Fortschrittsanzeige fehlt, sagt erst der nächste Befund. Ebenso ungeprüft,
  ob `FileManager.copyItem` auf diesem Gerät eine APFS-Kopie anlegt oder die
  Bytes wirklich verdoppelt — die Platzfrage ist damit offen.
- **Die Seite entsteht aus dem INHALT des Tages** (`Model/Tagesplan.swift`, ab
  1.0.34; Befund des Nutzers 09/2026 zu zwei Bildschirmfotos eines
  ausgegebenen Buches: „Es hat tatsächlich den Eindruck, als ob hier nur ein
  vorgegebenes Design mit sechs unterschiedlichen Seiten der Reihe nach
  abgespult wird, ohne darauf zu achten, wie der konkrete Inhalt eines Tages
  wirklich ist."). **Er hatte recht, und es stand wortwörtlich so im
  Quelltext**: `Seitenrhythmus` war eine Liste von sechs Seitenbildern,
  durchlaufen mit `(seite + versatz) % 6`; wie viel Text der Tag hat, wie
  viele Bilder und ob sie hoch oder quer stehen, ging in diese Wahl mit keinem
  einzigen Wert ein. Die Datei ist **ersatzlos entfernt** und nicht auf einen
  Sonderfall zurückgestellt — dieselbe Regel wie beim Rückbau von 1.0.25:
  Ein Mechanismus, dessen Grund widerlegt ist, bleibt nicht liegen.
  - **Gemessen werden zwei Höhen** — der Text über die volle Satzbreite
    (`Textmass.hoehe`) und alle Bilder zusammen in Reihen
    (`Layoutautomat.stapelhoehe`), beide mit den Funktionen, die hinterher
    auch SETZEN. Eine zweite Schätzung daneben liefe auseinander, und dann
    hielte die Seite nicht, was der Plan sagt.
  - **Aus dem Verhältnis folgt die GANGART, aus der Summe die Zahl der
    Seiten** — und das sind genau die drei Fälle, die der Nutzer genannt hat:
    `bilderreich` (unter einem Fünftel Text: der Text bleibt beisammen, danach
    dürfen reine Bilderseiten stehen), `ausgewogen` (auf jeder Seite beides),
    `textreich` (über sieben Zehnteln: Bilder neben dem Text).
  - **Die Seitenzahl ist eine Schätzung mit Absicht.** Sie steuert die
    Verteilung und ist keine Zusage; was am Ende übrig ist, kommt auf eine
    zusätzliche Seite. Wie viele Kacheln auf die Seite gehören, wird bei JEDER
    Seite neu aus dem Offenen gerechnet und nicht beim Start festgelegt —
    sonst stimmte die Verteilung nicht mehr, sobald eine Seite mehr aufnimmt
    als geplant.
  - **Nichts daran ist gewürfelt und nichts hängt an der Kennung des Tages.**
    Derselbe Inhalt ergibt denselben Satz; die Abwechslung kommt aus dem
    Inhalt und aus dem Wechsel der Seitenstellung.
- **Eine Reihe SCHRUMPFT, bevor sie umbricht** (`Layoutautomat.reihenIn`, ab
  1.0.34). Gemeldet: „Das einzige Foto … erscheint nun super groß auf einer
  leeren Seite 4. Dabei wäre auf Seite 3 noch Platz gewesen." Zwei Ursachen,
  beide nachzurechnen: Der Text bekam die ganze Seite, obwohl noch ein Bild
  für sie vorgesehen war (freigehalten wurde nur, wenn Reihe UND sechs Zeilen
  danebenpassten, sonst gar nichts) — und die Seite brach um, sobald die
  nächste Reihe in ihrer ZIELHÖHE nicht mehr hineinpasste, worauf dieselbe
  Reihe auf der neuen, leeren Seite wachsen durfte (`ausfuellendesZiel` aus
  1.0.32). Eine Reihe ist aber kein festes Maß: Ihre Höhe folgt aus der
  Zielhöhe, und die lässt sich für diese eine Reihe senken. **Erst wenn auch
  das nichts mehr hergibt, bleibt der Umbruch.**
- **Ein Band folgt dem SEITENVERHÄLTNIS, sonst ist es ein Ausschnitt** (ab
  1.0.34, gemeldet: „Auf der Seite 5 ist ein Ausschnitt eines Fotos auf die
  ganze Seitenbreite gezogen. Das macht keinen Sinn."). Das Aufmacherband aus
  1.0.32 stand fest auf gut einem Drittel der Satzhöhe bei voller Satzbreite —
  und weil ein Rahmen GEFÜLLT und nicht eingepasst wird (`Bildausschnitt`),
  wurde aus einem Hochformat ein Streifen quer durch das Bild. Gedeckelt wird
  jetzt die HÖHE, was an Breite fehlt, bleibt Rand, und ein Band bekommt nur
  ein Querformat. **Wer einen Rahmen setzt, dessen Verhältnis vom Bild
  abweicht, hat einen Ausschnitt gewählt — absichtlich beim Vollbild, versehentlich
  überall sonst.**
- **Ein Bild NEBEN dem Text, und der Text läuft darunter weiter**
  (`Seitenform.seitlich`, ab 1.0.34). Antwort auf zwei Punkte zugleich: auf
  Seite 6 („könnte zumindest eins der Fotos noch neben den Text gezogen
  werden und die anderen Fotos entsprechend verteilt") und auf den dritten
  der drei Fälle („bei sehr viel Text und wenig Bildern … dass der Text sie
  umfließt"). Umflossen wird in einem **L**: eine schmale Spalte neben dem
  Bild, darunter die volle Breite — zwei Blöcke, kein neuer Satz.
  **Ein Bild, das auf BEIDEN Seiten Text hat, ist bewusst nicht gebaut:**
  CoreText legt einen Rahmen in ein Rechteck; alles andere verlangte, jede
  Zeile einzeln zu setzen, also einen zweiten Umbruch neben dem, mit dem
  `Textmass` misst — und der Textblock wäre danach nicht mehr das, was man in
  dieser App anfassen, verschieben und teilen kann.
- **Drei Fotos in einer Flucht sind ein Raster, kein Satz** (ab 1.0.34,
  gemeldet zu Seite 7). In Stilen mit `Buchstil.lebendig` liegen die Kacheln
  einer Reihe wieder gegeneinander versetzt und leicht gedreht — mit dem
  Winkel aus der Kennung des Fotos, also bei jedem Neuanordnen demselben. Und
  eine Reihe, die ihre Zielhöhe nicht erreicht, steht **mittig** statt
  linksbündig: Ein einzelnes Bild an der linken Kante sieht aus wie der Rest
  einer Reihe.
- **`Seitenmuster.wechsel` heißt „Nach Inhalt gesetzt" und ist der REGELFALL**
  (ab 1.0.34). Bis 1.0.33 verlangte es über 1200 Zeichen und mindestens vier
  Fotos. Genau daran scheiterte der 3. August im gemeldeten Buch: Ein Tag mit
  Text und EINEM Foto fiel durch die Schwelle und landete bei einem Muster
  ohne Planer. Jetzt greift es, sobald ein Tag Text UND Bild hat; ohne eines
  von beidem gibt es nichts zu verteilen, und die eigenen Bildideen der
  übrigen acht Muster sind die bessere Antwort. Dieses eine Muster geht weder
  durch den Musterschalter noch durch `reihenSetzen` — ein Satz, der sich nach
  dem Inhalt richtet, lässt sich nicht als Sonderfall in eine Kette einbauen,
  die Text und Bilder nacheinander abarbeitet; er muss beide zugleich vor sich
  haben.
- **Nicht gemessen (1.0.34):** Keine Seite ist damit gesehen worden. Gerechnet
  ist, WARUM das Foto auf der leeren Seite landete, warum das Band ein
  Ausschnitt wurde und was der Rhythmus mit dem Inhalt zu tun hatte (nichts).
  **Gewählt und nicht gemessen sind alle Zahlen im Planer** — die beiden
  Gangart-Schwellen (0,20 und 0,72), die Spaltenbreite des seitlichen Bildes
  (0,40 der Satzbreite) und seine Höhe (höchstens 0,46), die Bandhöhe (0,40),
  der Zuschlag von einem Viertel auf den Textanteil je Seite und die zwölf
  Zeilen, ab denen ein Bild neben den Text darf. **Und es sind mehrere Dinge
  auf einmal geändert**: Die Regel „eine Sache auf einmal" ist hier bewusst
  gebrochen, weil die fünf gemeldeten Seiten EINE gemeinsame Ursache haben —
  fünf Fassungen nacheinander hätten sie einzeln kuriert, ohne sie zu beheben.
- **TEXT IST EIN FELD WIE EIN FOTO — und die Seite wird GEFÜLLT**
  (`Model/Mosaik.swift`, ab 1.0.35; Diagnose des Nutzers 09/2026 im Vergleich
  mit einer fremden Foto-App: „ob ein grundlegendes Problem vielleicht ist,
  dass du Text auf der einen Seite und Bilder auf der anderen Seite als
  streng getrennte Formate betrachtest. Ich glaube, ich hätte gedacht, dass
  Text ein gleichberechtigtes Gestaltungselement einer Seite ist, wie auch
  ein Foto." — dazu der Befund: dort seien „die Bilder wesentlich größer und
  verschenken wesentlich weniger Platz auf der Seite"). **Er hat recht, und
  es stand so im Quelltext**: Eine Seite bestand aus einer TEXTSPALTE und
  darunter aus FOTOREIHEN, und die sechs Seitenformen aus 1.0.34 waren
  allesamt Antworten auf die Frage, in welcher REIHENFOLGE beide kommen —
  eine Frage, die es nur unter dieser Annahme gibt. `Seitenform` ist deshalb
  **ersatzlos entfernt**, wie `Seitenrhythmus` eine Fassung zuvor.
  - **Eine Seite ist eine SPALTE aus Reihen, die zusammen die volle Satzhöhe
    ergeben.** Bis 1.0.34 rechnete `zielhoehe` die Reihenhöhe allein aus der
    ZAHL der Kacheln und sah die Seite nie an; was unten übrig blieb, schob
    `restplatzVerteilen` in die Lücken. **Damit war weißer Platz der
    Normalfall und ein großes Bild der Ausnahmefall.**
  - **Gesucht wird über die ZAHL der Reihen, nicht über eine Formel**
    (`Mosaik.beste`, eins bis vier): Eine größere Zielhöhe nimmt Kacheln aus
    den Reihen heraus und kann eine Reihe MEHR ergeben — derselbe nicht
    monotone Zusammenhang wie bei `ausfuellendesZiel` seit 1.0.32. Gewertet
    wird die Dehnung.
  - **Ein Text hat kein Seitenverhältnis, sondern zu jeder Breite eine
    gemessene Höhe** (`Mosaik.mischreihe`). Probiert werden zwölf Breiten
    zwischen 30 und 70 Prozent der Satzbreite; genommen wird die, bei der die
    Fotohöhe gerade noch über der Texthöhe liegt. Eine Umkehrfunktion gibt es
    nicht — die Texthöhe springt von Zeile zu Zeile. Gemessen wird vom
    AUFRUFER (`Textmass`, also derselbe Satz, der zeichnet) und als Abschluss
    hereingereicht; `Mosaik` selbst enthält nur Arithmetik.
  - **Wie viele Bilder auf eine Seite gehören, entscheidet der PLATZ.**
    `Tagesplan` schlägt eine Zahl vor, die Seite prüft sie: Bleibt Luft,
    kommt ein Bild dazu; wird es eng, geht eines zurück (bis zu zehn
    Anläufe). **Nicht die Zahl der Bilder bestimmt den Satz, sondern der
    Platz bestimmt die Zahl der Bilder.**
  - **Die Dehnung ist auf 1,22 gedeckelt.** Gedehnt heißt: Das Bild wird
    höher, als sein Verhältnis vorgibt, und verliert seitlich gut 18
    Prozent — der Rahmen wird GEFÜLLT, nicht eingepasst. Mehr wäre genau der
    Ausschnitt, den 1.0.34 am Aufmacherband abgestellt hat. Reicht der Deckel
    nicht, bleibt der Rest als Luft zwischen den Reihen stehen: Lieber etwas
    Weiß als ein Bild, dem ein Fünftel fehlt.
  - **Was daraus von selbst folgt**, ohne einen einzigen Sonderfall: Text
    neben einem Foto, wo der Text kurz ist; Text über die volle Breite, wo er
    mehr als die halbe Seite braucht; eine reine Bilderseite, wo kein Text
    mehr wartet. In der Gangart `bilderreich` bleibt der Text ganz auf der
    ersten Seite (Ansage des Nutzers: „den Text nicht noch weiter
    auseinanderzuziehen").
  - **Die Seitenschätzung des Plans rechnet jetzt mit einer Reihenhöhe von
    einem Drittel der Seite** statt mit `zielhoehe`. Seit die Reihen die
    Seite füllen, schätzte die alte Zahl die Bilder zu klein und damit den
    Tag zu kurz.
- **Nicht gemessen (1.0.35):** Keine Seite ist damit gesehen worden.
  Gerechnet ist die Geometrie; **gewählt und nicht gemessen** sind die
  Dehnungsgrenze 1,22, die Spanne der Textbreite (30 bis 70 Prozent), die
  zwölf Stufen, die Schwelle von 56 Prozent Seitenhöhe für die volle Breite
  und die Reihenzahl eins bis vier. **Ungemessen ist auch der Preis der
  Rechnung**: bis zu zwölf CoreText-Messungen je Seite für die Textbreite,
  dazu je Anlauf der Bildzahl eine neue Aufteilung. Das läuft beim
  Neuanordnen und nicht beim Zeichnen — gesehen hat es trotzdem niemand.
- **EINE REIHE IST EIN STAPEL, KEIN RASTER** (`Layoutautomat.querfuge`,
  `.staffelhub`, `.neigung`, ab 1.0.36; Befund des Nutzers 09/2026 zu 1.0.35:
  „Allerdings ist die Anordnung der Fotos jetzt schon wieder sehr, sehr
  nüchtern. Alle sind rechtwinklig ausgerichtet, keins davon leicht gedreht
  oder gar so, dass sich eine Ecke überlappt."). **Er hat recht, und es war
  ein Rückschritt von mir**: 1.0.34 hatte das Staffeln und Drehen in
  `reihenIn` eingebaut — und 1.0.35 hat genau diese Funktion durch das Mosaik
  ersetzt, samt der Mechanik darin. **Wer eine Funktion ablöst, zählt vorher
  auf, was in ihr steckte** — sonst löst man mit dem Fehler auch das mit, was
  schon richtig war.
  - **`Mosaik` hat seit 1.0.36 ZWEI Fugen**: `quer` innerhalb einer Reihe,
    `fuge` zwischen den Reihen. Bis dahin war es ein einziger Wert, und damit
    ließ sich „zwei Bilder überlappen einander" gar nicht ausdrücken — ein
    negativer Wert hätte auch die Reihen ineinandergeschoben.
  - **Überlappt wird in der RECHNUNG, nicht erst beim Setzen.** `quer` darf
    negativ sein; `reihenhoehe` rechnet dann mit `breite - quer * (n-1)`, die
    Kacheln werden BREITER und die Reihe höher, und die Satzbreite bleibt
    gefüllt. Wer die Kacheln bloß beim Zeichnen enger rückte, ließe rechts
    einen Streifen stehen — also genau das, was 1.0.35 abgestellt hat.
  - **Der Staffelhub gehört ebenfalls in die Rechnung** (`staffel` je Reihe,
    nur ab zwei Kacheln — dieselbe Bedingung in `Mosaik.spalte` und beim
    Setzen). Sonst hielte die Spalte ihre Höhe nicht, sobald versetzt wird.
  - **Nur in Stilen mit `Buchstil.lebendig`** (Tagebuch, Album, Postkarte).
    In einem Magazin wäre ein schiefes Bild ein Fehler, in einem Album fehlte
    es.
  - **Der Winkel kommt aus der KENNUNG des Fotos** (`drehwinkel`, ±2,1°),
    nie aus dem Zufall: Ein Satz, der sich bei jedem Neuanordnen anders
    neigt, ist kein Satz, sondern ein Würfel. **Die Karte wird nicht
    gedreht** (sie ist eine Auskunft, kein Erinnerungsstück), **die
    Bildunterschrift auch nicht** — sie würde um ihre EIGENE Mitte gedreht
    und rückte damit vom Bild ab.
  - **`Block.ebene` entscheidet, wer obenauf liegt** (`Seite.sortiert`). Jede
    zweite Kachel sitzt höher UND liegt oben; so sieht die Überlappung gelegt
    aus und nicht verrutscht.
  - **Der alte Weg staffelt und dreht wieder mit** (`reihenSetzen`, die acht
    übrigen Muster) — ein Tag ganz ohne Text kommt nicht durch das Mosaik.
    **Überlappt wird dort NICHT**: Die Breiten rechnet `naechsteReihe` mit der
    ganzen Fuge, und zwei Rechnungen nebeneinander liefen auseinander.
- **Das Wort „Bildunterschrift …" war die „Regieanweisung"** (ab 1.0.36,
  gemeldet 09/2026: „an manchen Stellen steht Text, der wie eine
  Regieanweisung wirkt. Ich weiß nicht, wo das herkommt."). **Woher es kommt,
  ist am Quelltext abzulesen und nicht geraten:** Auf eine Seite schreibt die
  App von sich aus nur vier Texte — die Seitenzahl, die Kopfzeile, „Kartenbild
  fehlt" (nur wo eine Karte fehlt) und, auf dem Bildschirm, den Platzhalter
  einer leeren Bildunterschrift. Nur der letzte wiederholt sich. Und
  `SeitenflaecheView.unterschriftOeffnen` schaltet die Unterschrift bei einem
  **Doppeltipp auf das Foto** ein — also mit demselben Griff, mit dem man Text
  bearbeitet. Wer danach nichts schreibt, hat das Wort von da an unter dem
  Bild stehen.
  - **Statt des Wortes steht dort eine MARKE** — eine dünne Linie. Der Grund
    für die Anzeige bleibt richtig (eine eingeschaltete Unterschrift ohne Text
    wäre sonst eine unsichtbare Fläche, die sich nicht antippen lässt); was
    falsch war, ist das WORT. Ins PDF geht beides nicht.
  - **Gezählt wird trotzdem** (`Druckpruefung.leereUnterschriften`): Der Block
    hält weiterhin eine Zeile unter dem Foto frei, und im Druck ist das eine
    leere Zeile, die niemand bestellt hat. Die Zeile nennt Tag und Seite.
  - **Und es gibt einen Ausweg** (`Reisewerk.leereUnterschriftenAbschalten`,
    „…" oben rechts): Ein Hinweis ohne Weg, ihn aufzulösen, ist die Frage von
    vorhin noch einmal. Gemerkt wird dabei EINMAL und nicht je Foto — der
    Rückgängig-Stapel ist flach (25 Stände), und zwanzig Einzelschritte hätten
    ihn geleert.
- **Text um ein Foto herum ist weiterhin nicht gebaut**, und der Nutzer hat
  das ausdrücklich hingenommen („wird wahrscheinlich nicht möglich sein").
  Der Grund steht seit 1.0.34 da: CoreText legt einen Rahmen in ein Rechteck;
  alles andere verlangte, jede Zeile einzeln zu setzen — also einen zweiten
  Umbruch neben dem, mit dem `Textmass` misst.
- **Nicht gemessen (1.0.36):** Keine Seite ist damit gesehen worden.
  Gerechnet ist die Geometrie (dass die Satzbreite bei negativer `quer` gefüllt
  bleibt, dass der Staffelhub in die Spaltenhöhe eingeht). **Gewählt und nicht
  gemessen** sind alle drei Zahlen: die Überlappung (`-fuge * 1,1`), der
  Staffelhub (`fuge * 0,9`) und der Winkel (±2,1° aus 1.0.34). Ob das auf
  einer gedruckten Doppelseite nach „hingelegt" aussieht oder nach
  „verrutscht", sagt erst der nächste Befund — und wie weit die gedrehten
  Ecken am Satzspiegel überstehen, ist ebenfalls nur gerechnet. **Und der
  Befund zur „Regieanweisung" ist am Quelltext hergeleitet, nicht an seinem
  Buch nachgesehen**: Sollte er etwas anderes gemeint haben, steht es in
  seinem eingelesenen Text und nicht in der App. **Nichts davon als erledigt
  darstellen.**
- **DER ABSATZ GEWINNT — immer** (`Textmass.teilen`, ab 1.0.37; Ansage des
  Nutzers 09/2026, zum zweiten Mal: „Ich hatte aber gesagt, dass die
  Trennstellen dabei nach den Absätzen sein sollen. Ich finde aber
  Trennstellen, die quasi mitten im Text passieren."). Er hat recht, und die
  Stelle ist auszurechnen: Bis 1.0.36 stand dort ein `mindestfuellung` von
  0,62 — die Absatzgrenze galt nur, wenn der Kopf danach noch 62 Prozent des
  Kastens füllte, sonst wurde an der WORTgrenze geteilt.
  **Die Abwägung war seit 1.0.35 hinfällig, und das ist der ganze Befund.**
  Gebaut wurde sie in 1.0.14 gegen eine große weiße Fläche am Seitenfuß —
  damals bestand eine Seite aus einer Textspalte und darunter aus
  Fotoreihen, und was der Text nicht brauchte, blieb Papier. Seither füllt
  `Mosaik` die Seite: Was der Text nicht braucht, bekommen die Bilder, und
  `seiteFuellen` nimmt so lange ein Bild dazu, bis der Platz aufgeht. Die
  Lücke, gegen die die Regel gebaut war, gibt es nicht mehr — sie stand nur
  noch da und hat geschadet. **Merke: Wer eine Regel stehen lässt, deren
  Grund eine spätere Fassung beseitigt hat, baut einen Fehler ein, den
  niemand mehr begründen kann** (dieselbe Lehre wie beim Rückbau von 1.0.25
  und beim Wegfall von `Seitenrhythmus` und `Seitenform`).
  Ersatzlos entfernt und NICHT auf 0 gestellt: Ein Parameter, der nur noch
  einen Wert haben darf, wird irgendwann wieder ein anderer (dieselbe Regel
  wie beim Sperrmechanismus in Schulalarm 1.1.0). An der Wortgrenze wird nur
  noch geteilt, wo es im Kasten ÜBERHAUPT keine Absatzgrenze gibt — ein
  einzelner Absatz, der für sich schon länger ist als der Platz.
- **Und diese Stellen werden GEZÄHLT** (`Druckpruefung.mittenImSatz`, ab
  1.0.37). Sonst wäre „der Absatz gewinnt" eine Zusage, die sich niemand
  ansehen kann. Gemessen wird am ERGEBNIS und nicht an der Absicht: Ein
  Textblock, der nicht mit einem Satzzeichen aufhört und dem ein weiterer
  folgt, endet mitten im Satz — unabhängig davon, was die Teilung gemeint
  hat, und damit die ehrlichere Zahl.
- **DIE TEXTSPALTE HAT EINE HÖCHSTBREITE** (`Gestaltung.textspaltenanteil`,
  Vorgabe 0,66, ab 1.0.37; Ansage des Nutzers 09/2026: „Mir fällt auf, dass
  der Text des Tagebuches in der Regel über die gesamte Breite einer Seite
  geht. Das finde ich nicht gut, denn ich denke, er ist besser lesbar, wenn
  er maximal über zwei Drittel der Seite geht.").
  - **Gemessen wird gegen die SATZBREITE, nicht gegen den freien Raum.**
    Sonst käme ein Deckel auf den anderen: Bei „Karte neben dem Text" ist
    die Spalte schon auf gut die halbe Satzbreite eingeengt, und zwei
    Drittel DAVON wären ein Streifen. Es ist eine Obergrenze und keine
    Vorschrift — wer ohnehin weniger bekommt, behält, was er hat.
  - **Eine Zahl, EINE Stelle** (`Layoutautomat.satzTextbreite`). Gefragt
    wird sie überall, wo bisher `satz.width` für einen Textblock stand:
    beim Messen für den Plan, beim TEILEN und beim Setzen. Liefen die drei
    auseinander, würde an einer Breite geteilt und in einer anderen
    gesetzt — der Text wäre auf der Seite anderthalbmal so hoch wie
    gerechnet und liefe unten heraus.
  - **Der Deckel gilt auch im alten Weg** (`textSpalte`, also die acht
    übrigen Muster). Ihn nur im Mosaik zu ziehen hieße, dass „Text zuerst"
    und „Karte oben" weiter Zeilen von neunzig Zeichen ergäben.
  - **Wie viele Zeichen wirklich auf einer Zeile stehen, MISST die App**
    (`Textmass.zeichenJeZeile`, Zeile in der Druckprüfung). Eine
    Einstellung, die sich auf eine Behauptung stützt, wäre in diesem Buch
    die falsche. Gezählt wird mit demselben CoreText-Umbruch, der zeichnet;
    die letzte Zeile bleibt draußen, weil sie dort endet, wo der Text
    aufhört. **Die Spanne 45 bis 75 Zeichen ist Handwerk des Schriftsatzes
    und an diesem Buch NICHT nachgeprüft** — die Zeile sagt das auch.
- **Die Textreihe steht an jeder Stelle der Spalte** (ab 1.0.37, Ansage des
  Nutzers: „Auch hier wäre es dann gut, vielleicht verschiedene Textblöcke
  zu haben, die sich mit den Bildern abwechseln."). Bis 1.0.36 gab es zwei
  Lagen — ganz oben oder ganz unten (`textOben = nummer % 2 == 0`); einen
  Wechsel gab es damit nur von Seite zu Seite, nicht auf der Seite. Die
  Textreihe ist jetzt eine Reihe unter den anderen: 0 heißt oben,
  `reihen.count` unten, alles dazwischen ZWISCHEN zwei Fotoreihen. Gewählt
  aus der Seitennummer und nicht gewürfelt — derselbe Inhalt ergibt
  denselben Satz.
  - **Bricht eine Reihe ab, bricht ALLES ab** (`abgebrochen`). Die Kacheln
    liegen in einer Folge, und `seiteFuellen` nimmt hinterher die ersten
    `gesetzteKacheln` aus dem Vorrat. Würde Reihe 2 übersprungen und Reihe 3
    gesetzt, wären zwei Bilder vertauscht — still und unauffindbar.
  - **`restplatzVerteilen` läuft nur im LETZTEN Abschnitt.** Im oberen liefe
    die gewonnene Luft in den Textblock hinein, und die Funktion kennt ihn
    nicht: Sie verschiebt nur die Reihen, die sie bekommt.
- **Die Reisepunkte auf der Buchkarte waren eine Perlenkette**
  (`Spurpunktstil`, ab 1.0.37; Befund des Nutzers 09/2026: „Diese Punkte
  haben eine bestimmte Farbe und einen Kreis um sich herum. Das sieht etwas
  merkwürdig aus. Ich habe noch keine richtige Lösung dafür."). Am Quelltext
  abzulesen und kein Eindruck: Je Punkt wurde ein VOLLER weißer Kreis
  gezeichnet und darauf ein farbiger Kern von 58 Prozent des Radius — der
  Rest war ein weißer Ring von fast einem Viertel des Durchmessers. Bei
  dreißig Fotopunkten an einem Tag übernimmt der die Karte. Gedacht war er
  als KONTRAST (dieselbe Rechnung wie unter der Linie); als Zeichnung war er
  zu laut. **Weil der Nutzer ausdrücklich sagt, er habe noch keine Lösung,
  ist keiner seiner drei Auswege weggelassen**: `ohne` (nur die Linie),
  `dezent` (volle Punkte in der Linienfarbe mit haardünner Kontur — die
  Vorgabe), `enden` (nur Anfang und Ziel) und `ring` (der alte, dünner).
  **Eine Kontur ist kein Ring**: Sie liegt AUF der Kante und nimmt dem Punkt
  nichts weg. Und `punktstil` steht im `merkmal` des Zwischenspeichers —
  eine vergessene Stelle im Schlüssel zeigt nach dem Umstellen das Bild von
  vorhin, und das sieht aus, als tue der Schalter nichts.
- **Einen Punkt findet man auf der KARTE, nicht in der Liste**
  (`PunktwahlView`, ab 1.0.37; Befund des Nutzers 09/2026: „Ich möchte die
  Reisepunkte auf einer Karte, die möglichst bildschirmfüllend ist,
  auswählen können und verschieben können bzw. löschen können. Innerhalb der
  Liste ist es schwierig, einen bestimmten Punkt wiederzufinden."). Die
  Karte gab es seit 1.0.20, bildschirmfüllend, samt Verschieben und
  Löschen — nur der WEG hinein führte über die Liste: `punktID` war ein
  `let` von außen, und die Punkte auf der Karte waren `Marker`, also
  unantastbar. Siebte Auflage von „es war da, man fand es nicht", und
  diesmal fehlte nicht der Knopf, sondern der Weg zu ihm.
  - **`punktID` ist ein ZUSTAND.** Ein Tipp auf einen Punkt wählt ihn, die
    Leiste nennt ihn beim Namen und sagt, der wievielte er ist; „Neuer
    Punkt" führt zurück. Ohne diesen Rückweg käme man, einmal auf einem
    Punkt gelandet, nie wieder zum Anlegen.
  - **Auf der Karte liegt kein Bedienelement** (`.allowsHitTesting(false)`,
    Lehre aus Abfahrtstafel 1.1.18). Den Tipp nimmt die Karte entgegen und
    sucht HINTERHER den nächsten Punkt — in BILDPUNKTEN und nicht in Grad,
    denn was „nah" heißt, hängt am Maßstab. Gerechnet wird erst, wenn klar
    ist, dass ein Tipp gemeint war; die Griffweite kostet damit keine
    Kartenfläche.
  - **Verschoben wird über das FADENKREUZ, nicht durch Ziehen des Punktes.**
    Eine Ziehgeste auf einer Karte streitet mit dem Schieben der Karte — und
    genau diese Art Geste hat dieses Projekt von 1.0.5 bis 1.0.8 gekostet.
  - **Löschen schließt das Blatt nicht mehr.** Wer Punkte auf der Karte
    durchsieht, löscht oft mehrere; ein Blatt, das nach jedem Löschen
    zugeht, macht aus drei Handgriffen dreimal denselben Weg.
- **Die Broschüre lag drei Ebenen tief** (ab 1.0.37, gemeldet 09/2026: „Noch
  nicht gefunden habe ich die gewünschte Option, das Reisetagebuch auf dem
  heimischen Drucker doppelseitig als Broschüre drucken zu können"). Es gibt
  sie seit 1.0.27 und sie ist vollständig gebaut. Gefunden hat sie niemand,
  und daran waren drei Dinge auf einmal schuld: das falsche Menü („…" →
  „Als PDF sichern…" klingt nach einer Datei und nicht nach einem Drucker),
  ein zugeklappter Picker darüber, und dessen Name „Umfang" — ein Wort, das
  nach Seitenzahl klingt. Jetzt ein eigener Menüpunkt **„Broschüre
  drucken…"**, sprechende Namen im Picker („Broschüre zum Selberfalten"),
  und je ein Satz darunter, was dahintersteht. **Kein zweiter Bildschirm:**
  derselbe, nur mit Vorwahl — ein zweiter Weg zu derselben Sache liefe
  irgendwann auseinander.
- **Und sie stand mit dem RICHTIGEN Weg in der Bedienungskarte.** Seit
  1.0.27, wörtlich. Gefunden wurde sie trotzdem nicht. **Merke: Eine
  Bedienungskarte ist ein Nachschlagewerk für jemanden, der etwas Bestimmtes
  sucht — sie ersetzt keinen auffindbaren Menüpunkt.** Wer eine Funktion für
  auffindbar hält, weil sie dort steht, hat die Frage nicht beantwortet,
  sondern verschoben.
- **Gedruckt wird aus der App heraus** (`Druckauftrag`, ab 1.0.37). Bis
  1.0.36 gab es nur eine Datei zum Teilen; sie erst zu sichern, dann in
  „Dateien" zu suchen und von dort zu drucken, ist der Umweg um genau den
  Knopf herum, um den gebeten wurde. `UIPrintInteractionController` zeigt
  sich SELBST — eingebettet in ein SwiftUI-`.sheet` bliebe das Blatt
  schwarz; dieselbe Lehre wie beim Teilen-Blatt und beim Dateiwähler in
  Tafelbild. **`duplex` ist ein WUNSCH, keine Einstellung:** Was der Drucker
  tut und über welche Kante er wendet, entscheidet der Mensch im Dialog, und
  die App kann es weder setzen noch auslesen — deshalb steht daneben
  weiterhin der Schalter „Rückseiten um 180° drehen" und keine Automatik.
  Das Fenster für den Anker kommt aus der Szene DIESER App und nie aus
  `connectedScenes.first` (ungeordnete Menge — dieselbe Falle wie bei
  Tafelbilds Dokumentenkamera).
- **EIN GESETZTES BUCH ÄNDERT SICH NICHT VON SELBST** (`Neuverteilung`,
  „…" → „Alles neu verteilen…", ab 1.0.38; Frage des Nutzers 09/2026: „Ich
  frage mich, wie die nun geschaffene Funktion auf dem bereits eingegebenen
  Text angewendet werden kann. Vielleicht wäre eine Funktion sinnvoll, das
  Ganze einmal so weit zurückzusetzen, dass der Bild- und Textverteiler in
  Aktion treten kann.").
  Die Antwort auf die erste Hälfte lautet NEIN, und das ist kein Mangel: Was
  in `Gestaltung` und im `Layoutautomat` steht, wirkt beim SETZEN einer
  Seite; ein fertiges Buch trägt seine Blöcke als Rahmen im Modell. Würde
  eine neue Fassung das von selbst umstellen, bekäme jemand nach einem
  Update sein Buch neu gesetzt, ohne es gewollt zu haben. **Angestoßen wird
  es ausdrücklich** — und vorher steht Tag für Tag da, was dabei wegfällt.
  `alleNeuAnordnen(nurUnberuehrte: true)` gab es schon, es überspringt aber
  jeden Tag mit Handarbeit, und Handarbeit ist bereits ein verschobener
  Block; für jeden angefassten Tag hätte man einzeln ins Tagesmenü gemusst.
- **UND BEIM NACHSEHEN KAM DER EIGENTLICHE BEFUND HERAUS: Das Neusetzen
  verlor den auf der Seite geschriebenen Text** (`Reisewerk.wortlautSichern`,
  ab 1.0.38). `textSchreiben` legt einen bearbeiteten Fließtext in den BLOCK
  (Zweig `.text`), `Layoutautomat.seiten(fuer:)` setzt aber aus `tag.text` —
  und der weiß davon nichts. Wer also einen Tag mit bearbeitetem Text neu
  anordnen ließ, verlor seinen Wortlaut, STILL, denn die Seite steht ja
  danach da. **Das gab es schon lange vor dieser Fassung**: an „Seiten neu
  anordnen" im Tagesmenü und an beiden Muster-Wegen; „Alle unberührten Tage"
  war nur deshalb ungefährlich, weil es solche Tage übersprang. Der Wortlaut
  wandert jetzt VOR dem Setzen an den Tag zurück. **Der Aufruf gehört an
  JEDE Stelle, die Seiten setzt** — wer einen neuen Weg dorthin baut und ihn
  vergisst, baut denselben stillen Verlust wieder ein.
- **Eine Ansicht setzt keine Seiten** (`Reisewerk.musterSetzen`, ab 1.0.38).
  Zwei der vier Stellen, die den Automaten aufriefen, standen in ANSICHTEN
  (`TagInhaltView`-Picker und `ReiseView.musterSetzen`) und hatten dieselbe
  Folge zweimal gebaut — keine von beiden wusste vom Wortlaut in den
  Blöcken. Die Ansicht sagt, was gewollt ist; wie daraus Seiten werden,
  weiß das Werk. **Dass der Befund genau dort saß, wo der neue Kommentar
  davor warnt, ist kein Zufall: Er war schon da, bevor der Kommentar
  geschrieben war.**
- **Beim Zusammenfügen wird zuerst NACHGESEHEN, nicht geraten**
  (`Neuverteilung.zusammenfuegen`). Das Teilen hat die Ränder abgeschnitten
  (`trimmingCharacters`), also steht nirgends mehr, ob zwischen zwei Stücken
  ein Absatzwechsel lag oder ein Leerzeichen mitten im Satz. Beides falsch
  zu machen kostet: ein Leerzeichen statt eines Absatzes zieht zwei Absätze
  zusammen, ein Absatz statt eines Leerzeichens reißt einen Satz
  auseinander — und genau diesen Riss hat 1.0.37 gerade abgestellt. Kommen
  beide Stücke UNVERÄNDERT im Tagebuchtext vor, steht dort auch, was
  dazwischen lag; das deckt den häufigsten Fall ab (von zehn Kästen ist
  einer bearbeitet). Geraten wird nur an einer bearbeiteten Naht — Satzzeichen
  davor heißt Absatz —, und **wie oft, wird gezählt und hingeschrieben**.
  Gesucht wird das zweite Stück HINTER dem ersten: Stünde derselbe Wortlaut
  zweimal im Text, nähme eine Suche von vorn die falsche Stelle.
- **Zwei Fehler im eigenen Entwurf, beim Gegenlesen gefunden** (1.0.38) —
  beide hätten Text im Tagebuch beschädigt, und keiner wäre aufgefallen:
  - **`Seite.sortiert` ist die ZEICHEN-Reihenfolge** (nach `ebene`) und sagt
    über die LESE-Reihenfolge nichts. Der Automat setzt je Seite nur einen
    Textkasten, aber „Nach einem Absatz teilen" (1.0.14) kann zwei auf
    derselben Seite hinterlassen — dann stünde der zweite Absatz vor dem
    ersten im Tagebuchtext. Sortiert wird nach der LAGE (y, dann x).
  - **Zwei gleiche Stücke hintereinander zählen einmal.** Es gibt sie:
    `Druckpruefung.doppelterText` kennt seit 1.0.9 „derselbe Wortlaut in
    zwei Kästen auf einer Seite", und woher der zweite Kasten kommt, ist bis
    heute nicht geklärt. Ungeprüft stünde der Absatz hinterher DOPPELT im
    Tagebuchtext — ein Schaden, den die Rettungsfunktion selbst anrichtet.
    Eng gefasst auf das unmittelbare Nacheinander: Ein Tagebuch darf
    denselben kurzen Satz zweimal enthalten, nur nicht zweimal an derselben
    Stelle.
- **Was beim Neuverteilen BLEIBT und was WEGFÄLLT, steht vorher da.** Bleibt:
  Tagebuchtext, Überschrift, Datumszeile, Bildunterschriften (die stehen am
  Tag bzw. am Foto), die Fotos und die Reisepunkte. Fällt weg: Lage, Größe,
  Drehung und eigene Schrift der Blöcke, von Hand angelegte oder entfernte
  Seiten, geteilte Textkästen. Die harte Fassung fragt zusätzlich nach,
  bevor sie Handarbeit wegnimmt — dieselbe Regel wie beim Stilwechsel seit
  1.0.32, und eine Rückfrage, die nur eine Antwort zulässt, ist keine.
- **Eine `+`-KETTE MIT `?:` UND INTERPOLATION SPRENGT DEN TYPPRÜFER**
  (getroffen beim Bau von 1.0.38). `NeuverteilenView` trug einen `Text(…)`
  aus fünf per `+` verketteten Teilen, darin ein ternärer Ausdruck und ein
  `\(geratene)`. Der Übersetzer gab auf: „the compiler is unable to
  type-check this expression in reasonable time". **Lange `+`-Ketten aus
  reinen LITERALEN gehen in diesem Repo an hundert Stellen gut** — was sie
  sprengt, ist die MISCHUNG: `+`, `?:` und `\(…)` im selben Ausdruck. Jeder
  Teil für sich ist mehrdeutig (`+` gibt es für String und Zahl, `?:`
  verzweigt die Typen, Interpolation nimmt alles), und der Prüfer muss die
  Kreuzung aller Möglichkeiten durchgehen.
  **Gebaut wird so etwas außerhalb des Körpers**, Stück für Stück in eine
  `String`-Variable — dann ist jeder Schritt eindeutig. Die Meldung nennt
  übrigens nur die ERSTE solche Stelle einer Datei; wer sie behebt, sieht
  sich die anderen gleich mit an, statt einen zweiten roten Bau zu
  riskieren (in 1.0.38 standen noch drei daneben).
- **VERSCHIEBEN GAB ES, KOPIEREN NICHT — und beides war zu versteckt**
  (Blockmenü in der Fußleiste, `Reisewerk.blockKopieren`, ab 1.0.39; Befund
  des Nutzers 09/2026: „Ich suche noch nach der Funktion, Elemente auf eine
  andere Seite zu kopieren oder zu verschieben. Sie ist zu versteckt.").
  Achte Auflage von „es war da, man fand es nicht" — und diesmal mit einem
  Beleg dafür, dass es nie fertig gebaut wurde: **Über `seitenlage` stand
  seit 1.0.29 der Kommentar „Gebraucht an zwei Stellen (Inspektor und
  Blockmenü)", und das Blockmenü gab es nicht.** Ein Kommentar, der eine
  zweite Aufrufstelle behauptet, ist kein Beleg dafür, dass es sie gibt;
  dieselbe Wurzel wie bei jedem anderen Fall in diesem Papier, in dem ein
  Kommentar eine Prüfung ersetzen sollte.
  Verschieben lag im Block-Inspektor GANZ UNTEN, hinter Schrift, Wirkung,
  Lage und Ausschnitt — und der Inspektor selbst hinter dem Schieberegler
  in der Werkzeugleiste. **Der Inspektor ist der Ort für EINSTELLUNGEN; was
  man mit einem Block TUT, gehört dorthin, wo man ihn gerade anfasst.**
  Das Menü steht jetzt unten in der Leiste neben dem Tagesmenü, beschriftet
  mit der Art des Blocks, und erscheint nur bei gewähltem Block. Der
  Abschnitt im Inspektor bleibt: zwei Zugänge, dieselben Funktionen im Werk
  (die Regel aus 1.0.10).
- **Kopiert werden kann, was sich SELBST gehört** (`Reisewerk.kopierbar`,
  ab 1.0.39). Fotos, Karten, Linien und Flächen ja; Fließtext,
  Überschrift, Datumszeile und Bildunterschrift nein. Das ist keine
  Bequemlichkeit, sondern folgt aus dem Modell: Ein Tagebuchtext gehört dem
  TAG und steht einmal darin. Eine Kopie wäre im Druck derselbe Absatz
  zweimal — `Druckpruefung.doppelterText` meldet genau das seit 1.0.9 als
  Fehler —, und `Neuverteilung.fliesstexte` schriebe ihn beim nächsten
  Neuverteilen DOPPELT in den Tagebuchtext zurück. Der Grund steht im
  Fußtext des Inspektors; im Menü fehlt der Eintrag ganz, statt ausgegraut
  dazustehen: **Ein Knopf ohne Wirkung ist für den Menschen davor ein
  kaputter Knopf, ein fehlender wird nicht gesucht.** Wer einen Textkasten
  aufteilen will, teilt ihn — das ist die Sache, die dahinter gemeint ist.
- **Eine Kopie erbt keine Kennung** (dieselbe Lehre wie Tafelbild 1.4.5).
  Zwei Blöcke mit derselben `id` sind für jede Suche EIN Block:
  `Reisewerk.block(_:)` fände immer nur den ersten, und der zweite ließe
  sich nie wieder anfassen. Auf derselben Seite liegt die Kopie zudem
  VERSETZT und auf den Satzspiegel geklemmt — deckungsgleich sähe sie aus,
  als wäre nichts geschehen, und der nächste Griff verschöbe das Original.
- **Zwei eigene Fallen beim Gegenlesen von 1.0.39 gefunden**, beide
  namentlich in diesem Papier: ein `min` über eine `CGRect`-Kante und einen
  `Double` (die CGFloat-Falle aus 1.0.37 — jetzt mit `Double(…)` darum),
  und ein Menükörper aus verschachtelten Sections, Bedingungen und
  `ForEach` (die Typprüfer-Falle aus 1.0.38 — jetzt drei Funktionen). **Die
  Regeln zu kennen genügt nicht; sie müssen am eigenen Diff angewandt
  werden, bevor der Bau es tut.**
- **`hyphenationFactor` IST EIN FELD VON TEXTKIT — CoreText wirft es weg**
  (`Model/Silbentrennung.swift`, ab 1.0.40; gemeldet 09/2026 mit
  Bildschirmfoto: „Trotz aktivierter Silbentrennung sieht es dann so aus"
  — Blocksatz mit handbreiten Lücken und keinem einzigen Trennstrich).
  **Die Ursache ist am Quelltext abzuzählen und keine Vermutung:**
  `Schriftbild.attribute` setzt `NSMutableParagraphStyle.hyphenationFactor`,
  gesetzt wird die Seite aber mit CoreText. Reicht man CoreText eine
  `NSAttributedString`, übersetzt es den `NSParagraphStyle` in einen
  `CTParagraphStyle` — und dessen Aufzählung `CTParagraphStyleSpecifier`
  kennt Ausrichtung, Einzüge, Zeilenhöhen, Absatzabstände und den
  Umbruchmodus. Eine Silbentrennung steht nicht darin, also fällt das Feld
  beim Übersetzen weg.
  **Damit hat der Schalter „Silben trennen" von 1.0.0 bis 1.0.39 NICHTS
  getan** — weder auf dem Bildschirm noch im PDF, denn beide gehen durch
  `Seitensatz.zeichneText`. **Merke: Ein Attribut, das im Modell steht, ist
  noch nicht gesetzt.** TextKit und CoreText nehmen dieselbe
  `NSAttributedString` entgegen und werten NICHT dieselben Schlüssel aus.
- **Warum es nie auffiel: im Textfeld wirkte es.** `TextflaecheBruecke` ist
  ein `UITextView`, setzt also über TextKit und liest `hyphenationFactor`
  sehr wohl. Beim Doppeltipp war der Text getrennt, auf der Seite darunter
  nicht — dieselbe Einstellung, zwei Satzmaschinen. Wer eine Einstellung an
  zwei Wege reicht, prüft sie an BEIDEN.
- **Und die App behauptete das Gegenteil.** `TypografieView` zeigte
  „Blocksatz ohne Silbentrennung reißt Löcher in die Zeilen" nur, SOLANGE
  der Schalter aus war. Wer ihn umlegte, sah die Warnung verschwinden und
  die Löcher bleiben. Ein Hinweis, der mit dem Schalter verschwindet, sagt
  aus: „erledigt" — und das war hier falsch. Seit 1.0.40 sagen die Zeilen
  darunter, woher die Trennstellen kommen, ob das Gerät überhaupt ein
  deutsches Wörterbuch hat und dass in Großbuchstaben nicht getrennt wird.
- **Getrennt wird weiterhin NICHT von uns.** Die Stellen kommen aus
  `CFStringGetHyphenationLocationBeforeIndex`, also aus demselben deutschen
  Wörterbuch des Systems, das TextKit benutzt hätte. Die Regel dieses Repos
  („eine selbst gebaute Trennung ist verboten, die deutsche ist nicht
  ableitbar, und eine falsche stünde für immer im gedruckten Buch") bleibt
  unangetastet — neu ist nur, dass die App das Wörterbuch selbst fragt und
  den Strich selbst einfügt.
- **Ein WEICHES Trennzeichen (U+00AD) wäre der naheliegende Weg und ist
  bewusst NICHT gebaut.** Ob CoreText es als Umbruchstelle nimmt und dabei
  einen sichtbaren Strich zeichnet, lässt sich hier nicht messen — und der
  Fehlerfall wäre der teuerste denkbare: ein Strich mitten im Wort auf jeder
  Seite des gedruckten Buches. Eingefügt wird deshalb ein ECHTER Strich
  (U+002D, nicht U+2010 — das Viertelgeviert fehlt in mancher Schrift, und
  eine fehlende Glyphe wäre ein Kästchen im Wort), und zwar nur dort, wo die
  Zeile ohnehin umbricht. Damit hängt nichts an einer Annahme über CoreText.
- **EIN Setzer je Absatz, nicht einer je Trennstelle.** Ein eingefügter
  Strich gehört zur ABLAUFENDEN Zeile; die nächste beginnt an einer Stelle,
  die es im Urtext gibt. `CTTypesetterSuggestLineBreak` lässt sich also
  weiter mit demselben Setzer fragen, und die Striche werden erst am Ende in
  den Text geschrieben. Ein Setzer je Trennstelle wäre der naheliegende Weg
  und quadratisch — bei einem `Mosaik`, das zwölf Spaltenbreiten
  durchprobiert, ist das der Unterschied zwischen Millisekunden und
  Sekunden.
- **Gemessen wird die Zeile MIT dem Strich, nicht die Zeile plus einen
  einzeln gemessenen Strich.** Der Unterschied ist die Unterschneidung
  zwischen letztem Buchstaben und Strich, und er entscheidet: Rechnete man
  zu knapp, passte die Zeile beim Setzen nicht mehr, CoreText bräche an der
  Lücke davor um — und der Strich stünde am ANFANG der nächsten Zeile mitten
  im Wort. Vorgeschaltet ist eine grobe Prüfung über denselben Setzer (die
  kostet nichts Zusätzliches); genau gemessen wird nur der eine Kandidat,
  der sie überstanden hat.
- **DIE BREITE GEHÖRT AN JEDE AUFRUFSTELLE VON `Textmass`** (ab 1.0.40).
  Seit die Trennung von Hand gesetzt wird, hängt der gesetzte Text an der
  Breite: Wo die Zeile umbricht, entscheidet, welches Wort getrennt wird.
  Messen und Zeichnen müssen deshalb dieselbe Breite nennen — sonst hätte
  der Setzer, der die Höhe ausrechnet, andere Striche als der, der die Seite
  zeichnet, und der Text liefe unten aus seinem Block. Genau die Regel, aus
  der `Textmass` überhaupt entstanden ist, eine Ebene tiefer.
- **`passtBis` rechnet auf den URTEXT zurück** (`Ergebnis.imUrtext`). Es
  sagt, wie viel Text auf eine Seite passt, und `teilen` schneidet danach
  den TAGEBUCHTEXT. Käme dort eine Länge aus dem gesetzten Text zurück,
  wanderten die eingefügten Striche über `Neuverteilung.fliesstexte` in
  `tag.text` — mitten in die Wörter, und zwar dauerhaft. **Wer einen Text
  für die Anzeige verändert, braucht den Weg zurück, bevor er ihn misst.**
- **Versalien bleiben ungetrennt, und das ist Absicht.**
  `Schriftbild.gesetzt` schreibt den Text dann groß, und `uppercased()` kann
  die Länge ändern (aus „ß" wird „SS"). Die Rückrechnung auf den Urtext
  ginge damit um ein Zeichen daneben, und ein Tagebuchtext verlöre beim
  nächsten Neuverteilen einen Buchstaben. Versalien stehen in Überschriften,
  und die sind kurz; die Oberfläche sagt es dazu.
- **Was das Wörterbuch vorschlägt, wird MITGELESEN.**
  `CFStringGetHyphenationLocationBeforeIndex` gibt auch das Zeichen zurück,
  das an die Stelle gehört. Für Deutsch ist das seit 1996 ein gewöhnlicher
  Trennstrich; schlägt es etwas anderes vor, könnte sich die Schreibung
  ändern (die alte „Zuk-ker"-Regel), und das wäre eine Entscheidung über den
  Text, die uns nicht zusteht — solche Stellen werden übersprungen.
- **Wie oft wirklich getrennt wurde, ZÄHLT die Druckprüfung**
  (`Druckpruefung.trennungsbefund`). Nach einem Schalter, der zehn Fassungen
  lang nichts tat, steht dort keine Zusage, sondern eine Zahl: so viele
  Trennstriche in so vielen Textblöcken, gezählt am gesetzten Buch. Ist sie
  null, obwohl der Schalter an ist, sieht man das, statt es zu vermuten.
- **Zwei Zahlen sind gewählt und nicht gemessen:** mindestens zwei Zeichen
  vor dem Strich und drei danach, und höchstens drei getrennte Zeilen
  hintereinander. Beides ist Handwerk des Schriftsatzes, an diesem Buch
  nicht nachgeprüft.
- **Nicht gemessen (1.0.40):** Keine Seite ist damit gesehen worden.
  Gerechnet und am Quelltext abgezählt ist die URSACHE — dass
  `hyphenationFactor` bei CoreText wegfällt — und die Geometrie der
  Einfügung. **Ungemessen bleibt der PREIS:** Die Trennung läuft bei jeder
  Messung mit, und `Mosaik` misst denselben Text in zwölf Breiten; der
  Zwischenspeicher fängt die Wiederholungen ab, aber wie sich ein Buch mit
  zwanzig Tagen beim Neuanordnen anfühlt, sagt erst der nächste Befund. Der
  Zeichenmesser unter „Bedienung prüfen" zählt die Dauer mit. **Nicht als
  erledigt darstellen.**
- **Nicht gemessen (1.0.39):** Nichts davon ist auf einem Gerät gesehen
  worden. Dass das Blockmenü auffindbar IST, folgt daraus, dass es unten in
  der Leiste steht und den Namen des Blocks trägt — gesehen hat es niemand,
  und eine Oberflächenänderung als gelöstes Bedienproblem auszugeben wäre
  genau die Behauptung, die dieses Papier sonst verbietet.
- **Nicht gemessen (1.0.38):** Nichts davon ist auf einem Gerät gesehen
  worden. Gerechnet ist, WARUM der Wortlaut verlorenging und wie er sich
  zurückholen lässt; **ungeprüft an echten Daten** ist, wie oft die Naht
  geraten werden muss — das sagt erst die Zahl in der Vorschau an einem
  wirklichen Buch. **Nicht als erledigt darstellen.**
- **Nicht gemessen (1.0.37):** Keine Seite ist damit gesehen worden.
  Gerechnet sind die Geometrie und die Ursachen; **gewählt und nicht
  gemessen** sind die Vorgabe 0,66 für die Textspalte (sie ist die Zahl aus
  der Ansage) und die Maße der Punkte (Radius `breite/130`, Kontur
  `breite/900`). Ob eine Doppelseite mit wandernder Textspalte ruhig wirkt
  oder unruhig, ob ein dezenter Punkt auf einer bunten Karte noch zu sehen
  ist und ob der Systemdruckdialog die Broschüre richtig auf das Papier
  bringt, sagt erst der nächste Befund. **Nichts davon als erledigt
  darstellen.**
- **DIE GRÖSSE EINES FOTOS WAR KEINE ENTSCHEIDUNG, SONDERN EINE
  NEBENWIRKUNG** (`Tagesplan.zielreihenhoehe`, `Mosaik`-Deckel, ab 1.0.42;
  Befund des Nutzers 09/2026: „Mir ist nicht klar, wie das zustande kommt,
  dass einige Fotos riesengroß auf der Seite platziert werden, während andere
  dort, wo der Text noch mit im Spiel ist, ein Bruchteil dieser Größe haben.
  Das ist nicht ausgewogen." — dazu ein Tag mit fünf Fotos, der über vier
  Seiten lief und am Ende Bilder allein auf der Seite stehen ließ).
  **Nachgerechnet an der Geometrie, nicht geraten:** Die Höhe einer
  randbündigen Reihe ist `Satzbreite / Σ Seitenverhältnisse`. Auf A4 mit den
  Vorgaberändern (Satz 178 × 261 mm) wird ein HOCHFORMAT allein in seiner
  Reihe 237 mm hoch — 91 Prozent der Satzhöhe; dasselbe Foto zu dritt misst
  45 mm. Faktor **5,3**, und welcher der beiden Fälle eintrat, hing allein
  daran, wie viele Kacheln zufällig auf dieser Seite gelandet waren.
  - **Und die Kachelzahl kam aus einer ZÄHLUNG**: `kachelnAufSeite` teilte
    die offenen Kacheln durch die geschätzten Restseiten. Korrigiert wurde
    danach allein über die DEHNUNG — und die sagt nur, ob die Spalte den
    Kasten füllt. Zwei randbündige Hochformate untereinander füllen ihn
    genauso gut wie sechs kleine Kacheln. Über die GRÖSSE sagt sie nichts,
    und deshalb konnte niemand sie steuern.
  - **Die Zielreihenhöhe ist gerechnet, nicht gewählt.** Eine Reihe der Höhe
    h trägt Kacheln mit der Verhältnissumme B/h; für alle Kacheln eines
    Tages (Summe S) sind das S·h/B Reihen, und die Spalte wird S·h²/B hoch.
    Die Spaltenhöhe wächst also mit dem QUADRAT der Reihenhöhe — und aus der
    Fläche A, die den Bildern an diesem Tag bleibt, folgt genau eine Höhe:
    **h = √(A·B/S)**. Mehr Bilder werden kleiner, weniger größer, stetig
    statt in Sprüngen. Gedeckelt auf 0,16 bis 0,42 der Satzhöhe.
  - **Eine Reihe darf SCHMALER sein als der Satz.** Was über dem Deckel
    (Zielhöhe × 1,3) läge, wird nicht höher, sondern schmaler: Die Kacheln
    behalten ihr Verhältnis, die Reihe steht mittig, und rechts und links
    bleibt Rand. **Genau das konnte der alte Weg immer schon**
    (`naechsteReihe`: „sie wird gedeckelt und steht dann linksbündig, statt
    als Riese die Seite zu sprengen") — 1.0.35 hat diese Funktion durch das
    Mosaik ersetzt und den Deckel dabei verloren. **Dasselbe Muster wie beim
    Staffeln in 1.0.36: Wer eine Funktion ablöst, zählt vorher auf, was in
    ihr steckte.** Zum zweiten Mal an derselben Ablösung.
  - **Die Kachelzahl je Seite folgt jetzt aus der FLÄCHE** (`kachelnFuer`,
    dieselbe Rechnung rückwärts): so viele Kacheln, wie bei der Zielhöhe auf
    den Platz nach dem Text gehen. `kachelnAufSeite` ist ersatzlos entfernt —
    ein Mechanismus, dessen Grund widerlegt ist, bleibt nicht liegen.
  - **Nach unten gibt es keine Dehnungsgrenze mehr.** Sie stand da, solange
    eine Reihe die Satzbreite füllen MUSSTE: Stauchen hieß dann, das Bild
    seitlich zu beschneiden. Seit eine Reihe schmaler werden darf, heißt
    Stauchen „kleiner und mittig" und kostet nichts — und es rettet die
    Seite: Mit der alten Grenze wurde die Spalte höher als der Kasten, die
    letzte Reihe fiel heraus (`abgebrochen`), und ihr Bild landete allein auf
    der nächsten Seite. **Das war die zweite Hälfte des gemeldeten Fehlers.**
    Nach OBEN bleibt die Grenze, denn Dehnen beschneidet weiterhin.
  - **Keine hungernde letzte Seite.** Passt alles Offene noch auf diese
    Seite — gemessen an der Zielhöhe und der Stauchung, die ohnehin erlaubt
    ist —, kommt es mit. Der Grenzwert ist die Dehnungsgrenze selbst und
    keine zweite Zahl: Bei mehr Stauchung ginge die Spalte über den Kasten
    hinaus und die letzte Reihe fiele wieder heraus.
  - **Gehalten wird der BESTE Versuch, nicht der letzte.** Zwischen zwei
    Kachelzahlen kann eine Seite springen (mit drei Bildern zu hoch, mit
    zweien zu niedrig, keine im Band); bis 1.0.41 nahm die Schleife, was im
    zehnten Durchgang zufällig dastand. Gewertet wird jetzt wie in
    `Mosaik.beste`, und eine schon versuchte Zahl wird nicht wiederholt.
- **Und weil sich das hier nicht ansehen lässt, misst es die App**
  (`Druckpruefung.bildgroessen`, ab 1.0.42). Eine Zeile im Befund nennt den
  größten Größenunterschied innerhalb EINES Tages, samt Datum und beiden
  Maßen in Millimetern, und wie viel Prozent der Satzhöhe das höchste Foto
  des Buches nimmt. Gemessen am fertigen Satz und nicht an der Absicht —
  dasselbe Muster wie die Stufenprobe bei Schulalarm. Ein Faktor bis etwa
  2,5 gilt als Akzent, darüber steht die Zeile orange.
- **Nicht gemessen (1.0.42):** Keine Seite ist damit gesehen worden.
  Gerechnet und an den Vorgabemaßen nachgerechnet ist die URSACHE (91 gegen
  17 Prozent der Satzhöhe für dasselbe Foto) und die Geometrie der Abhilfe.
  **Gewählt und nicht gemessen** sind die Grenzen der Zielhöhe (0,16 bis 0,42
  der Satzhöhe), der Deckel darüber (1,3) und die Schwellen der neuen
  Befundzeile (2,5 und 3,2). Ob eine Doppelseite damit ausgewogen AUSSIEHT,
  sagt erst der nächste Befund — und seit 1.0.42 sagt er es mit Zahlen.
- **SELBST INSTALLIERTE SCHRIFTEN ZÄHLT `UIFont.familyNames` NICHT MIT**
  (`Model/Geraeteschriften.swift`, `Schriftwahl` in `Views/Waehler.swift`, ab
  1.0.41; gemeldet 09/2026: „Quicksand und … sind auf dem iPad installiert
  und können beispielsweise in Pages auch genutzt werden. In der App werden
  sie allerdings nicht einmal angezeigt."). **Die App war nicht kaputt, sie
  hat an der falschen Stelle gefragt:** `Schriftfamilie.alleDesGeraets` baut
  die Liste aus `UIFont.familyNames`, und das ist das Verzeichnis DIESES
  PROZESSES — die Schriften des Systems und die, die eine App in ihrem Bündel
  mitbringt. Was jemand über eine Schriftverwaltung auf das iPad legt, liegt
  woanders; dafür gibt es seit iOS 13 den `UIFontPickerViewController`, und
  genau den zeigt Pages. **Merke: Eine Aufzählung ist keine Frage an das
  Gerät, sondern eine an den eigenen Prozess.**
  - **„Der Wähler ist der einzige Weg" stand hier und war falsch**
    (berichtigt in 1.0.43). Es gibt sehr wohl eine Abfrage —
    `CTFontManagerCopyRegisteredFontDescriptors(.persistent, true)` —, und
    sie steht seit 1.0.43 davor; siehe den Absatz darunter. Der Satz war
    eine Annahme über Apples Absicht, ausgegeben als Auskunft über die
    Schnittstelle. Der Knopf bleibt daneben: Was die Abfrage nicht hergibt,
    holt der Wähler.
  - **Gewählt wird ein DESKRIPTOR, gesichert wird ein NAME.** Nur ein Name
    passt in ein Buch, das auf einem zweiten Gerät wieder aufgehen soll.
    Also wird die Schrift für den Prozess angemeldet
    (`CTFontManagerRegisterFontDescriptors`, Umfang `.process` — installiert
    hat sie der Nutzer längst) und danach NACHGESEHEN, ob sie unter ihrem
    Namen auffindbar ist. Das Ergebnis steht als Satz in der Schriftwahl.
    **Angenommen wird nichts**; dieselbe Bauweise wie die Stufenprobe bei
    Schulalarm.
  - **Eine Anmeldung auf `.process` endet mit dem Prozess.** Deshalb meldet
    `beimStartAnmelden()` bei jedem Start alles wieder an, was einmal
    gewählt wurde — und zählt, wie viel davon trägt. Die Namensliste liegt
    in den Voreinstellungen und NICHT im Buch: Welche Schriften auf einem
    Gerät liegen, ist eine Eigenschaft des Geräts.
  - **Kein `@AppStorage`** dafür — das ist eine `DynamicProperty` und gehört
    in eine View (die Regel steht seit 1.0.0 im Papier).
  - **Erst anmelden, dann nach dem Familiennamen fragen.** `UIFont(descriptor:)`
    gibt für eine dem Prozess unbekannte Schrift eine ERSATZSCHRIFT zurück —
    und deren Familienname stünde dann im Buch.
- **Eine fehlende Schrift ist der teuerste stille Fehler einer Druckvorlage**
  (`Druckpruefung`, ab 1.0.41). `Schriftbild.uiFont` fällt auf die
  Systemschrift zurück, wenn ein Name nicht auflöst — richtig, denn eine
  Seite ohne Schrift gibt es nicht. Nur sieht man es der Seite nicht an: Sie
  ist gesetzt, sie ist lesbar, und sie ist in einer anderen Schrift als der,
  die in der Schriftwahl steht. Getroffen wird das vor allem von selbst
  installierten Schriften und von einem Buch, das von einem anderen Gerät
  kommt. Gezählt und benannt wird es jetzt an zwei Stellen: in der
  Druckprüfung für das ganze Buch und als Zeile in der Schriftwahl für die
  gerade gewählte. **Wer einen stillen Rückfall baut, baut die Zeile dazu,
  die ihn sichtbar macht.**
- **Nicht gemessen (1.0.41):** Auf einem Gerät gesehen hat das niemand — hier
  gibt es keine selbst installierte Schrift. Gerechnet ist, WARUM sie in der
  Liste fehlten (`UIFont.familyNames` ist die Aufzählung des Prozesses);
  **ungeprüft ist alles danach**: ob `UIFontPickerViewController` die
  Schriften des Nutzers zeigt, ob die Anmeldung auf `.process` greift, ob der
  Name nach einem Neustart noch trägt und ob eine so gewählte Schrift ins PDF
  eingebettet wird. Genau deshalb sagt die App nach jeder Wahl selbst, was
  sie vorfindet, statt es zu behaupten. **Nichts davon als erledigt
  darstellen** — der nächste Befund des Nutzers ist hier die Messung.
- **EINE AUFZÄHLUNG IST KEINE FRAGE AN DAS GERÄT — ABER ES GIBT EINE**
  (`Geraeteschriften.systemfund`, ab 1.0.43; gemeldet 09/2026, nachdem
  1.0.41 ausgeliefert war: „Die Schriftarten tauchen immer noch nicht
  auf."). 1.0.41 hat die Ursache richtig benannt und die falsche Antwort
  gegeben: Die LISTE blieb dieselbe, daneben stand ein Knopf, der EINE
  Schrift nach der anderen holt — und er stand unter zwei Abschnitten, von
  denen der erste („Rundes a") auf einem iPad schon eine Bildschirmhöhe
  füllt. Wer die Liste ansieht, sieht also genau das, was vorher dastand.
  **Neunte Auflage von „es war da, man fand es nicht"** — und diesmal war
  zusätzlich zu wenig da.
  - **Das System lässt sich fragen.**
    `CTFontManagerCopyRegisteredFontDescriptors(.persistent, true)` gibt die
    Schriften zurück, die auf diesem Gerät dauerhaft angemeldet sind — also
    auch, was eine Schriftverwaltung dort abgelegt hat. `beimStartAnmelden`
    meldet sie für DIESEN Prozess an (`.process`); danach stehen sie in
    `UIFont.familyNames` und damit in der gewohnten Liste, ohne dass jemand
    einen Wähler öffnen muss. **Ob die Abfrage auf dem iPad des Nutzers
    etwas hergibt, ist NICHT gemessen** — deshalb zählt die App das
    Ergebnis, statt es zu behaupten.
  - **`CTFontManagerRegisterFontDescriptors` arbeitet ASYNCHRON.** Bis
    1.0.42 wurde ohne Rückrufblock angemeldet und unmittelbar danach
    gefragt, ob die Schrift unter ihrem Namen auffindbar sei — eine Frage,
    die zu diesem Zeitpunkt noch gar nicht beantwortet sein kann. Der
    Befund konnte also „NICHT auffindbar" sagen, während alles in Ordnung
    war, und `beimStartAnmelden` zählte beim ersten Start garantiert null.
    Gemeldet wird jetzt aus dem Block, und zwar erst, wenn er sich als
    abgeschlossen meldet. **Merke: Wo eine Schnittstelle einen
    Rückrufblock anbietet, ist die Frage davor zu früh.**
  - **Ein Deskriptor, der nur einen NAMEN trägt, ist der schwächste Weg.**
    Genau das blieb von einer über den Wähler gewählten Schrift übrig, und
    ob sich damit eine dem Prozess unbekannte Schrift wiederfinden lässt,
    ist offen. Die Systemabfrage steht deshalb DAVOR; der Namensweg bleibt
    als zweiter stehen, und beides wird getrennt gezählt.
  - **Der Abschnitt steht ganz oben**, gleich unter der Probe, und die
    Familien, die das Gerät meldet, stehen als Zeilen darin — in ihrer
    eigenen Schrift gesetzt wie jede andere. Dazu ein zweiter Zugang im
    Schrift-Blatt („Selbst installierte Schriften…"), denn hinter
    „Schriftart überall" steht der Name der gerade gewählten Schrift, und
    das liest sich wie eine Auswahlliste. Der irreführende Fußtext dort
    („Nur die Schriftfamilien, die dieses Gerät wirklich mitbringt, stehen
    zur Wahl") ist berichtigt — er beschrieb den Prozess und klang wie eine
    Aussage über das Gerät.
  - **„Schriften prüfen" ist eine PROBE, keine Erklärung**
    (`Views/Schriftenprobe.swift`). Nach einer Erklärung, die nicht
    geholfen hat, wird nicht ein zweites Mal geraten: kopierbar stehen dort
    die Zahl der vom System gemeldeten Einträge, wie viele davon lesbar
    waren, wie viele Familien der Prozess danach kennt, jede über den
    Wähler gewählte Schrift samt Auffindbarkeit — und ein PROTOKOLL der
    letzten Starts, das den Neustart überlebt. Nur so lässt sich „geht gar
    nicht" von „geht, hält aber den Neustart nicht" unterscheiden.
    Dasselbe Muster wie Schulalarms Stufenprobe und der Kartenmesser der
    Abfahrtstafel.
- **Nicht gemessen (1.0.43):** Auf einem Gerät gesehen hat das niemand —
  hier gibt es kein iPad und keine selbst installierte Schrift. Gerechnet
  ist, warum die Frage in 1.0.41 zu früh kam (der Aufruf ist asynchron) und
  warum der Weg nicht gefunden wurde (er lag unter zwei Abschnitten).
  **Ungeprüft bleibt das Entscheidende**: ob
  `CTFontManagerCopyRegisteredFontDescriptors(.persistent, true)` auf
  diesem iPad überhaupt etwas zurückgibt, ob sich die Einträge als
  `UIFontDescriptor` lesen lassen, ob die Anmeldung greift und ob eine so
  erreichte Schrift ins PDF eingebettet wird. Genau deshalb nennt die Probe
  zwei Zahlen (gemeldet und lesbar) statt einer. **Nichts davon als
  erledigt darstellen** — der Befund aus „Schriften prüfen" ist hier die
  Messung.
- **OHNE EIN RECHT GIBT iOS DIE SCHRIFTEN GAR NICHT HERAUS**
  (`com.apple.developer.user-fonts` = `system-installed-fonts`, ab 1.0.44;
  gemeldet 09/2026 zum dritten Mal, diesmal mit drei Bildschirmfotos).
  **Die Bilder sind die Messung, und sie zeigen auf etwas anderes als 1.0.41
  und 1.0.43:** In Pages stehen Poppins, Proxima Nova, Publico Text und
  Quicksand in der Schriftliste; im Wähler von iOS — demselben Wähler, den
  diese App seit 1.0.41 zeigt — springt dieselbe Liste von „PingFang TC"
  unmittelbar auf „Rockwell". Es fehlte also weder die Liste dieser App noch
  der Weg zum Wähler: **Es fehlte, was iOS der App überhaupt herausgibt.**
  - **Das Recht deckt beide Wege ab.** Ohne es sieht eine App ausschließlich
    die Schriften des Systems und die aus dem eigenen Bündel — der
    `UIFontPickerViewController` zeigt dann genau dieselbe Auswahl, und
    `CTFontManagerCopyRegisteredFontDescriptors(.persistent, true)` gibt
    nichts her. Damit ist auch gesagt, warum 1.0.43 nichts ändern konnte:
    Die Abfrage war richtig und fragte in einen leeren Raum.
  - **Eine Bewilligung braucht es nicht** (anders als bei Schulalarms
    kritischen Hinweisen, wo eine Entitlements-Datei ohne Bewilligung jedes
    Signieren scheitern lässt). In Xcode ist es die Fähigkeit „Fonts" mit
    dem Haken „Use Installed Fonts"; bei automatischer Signierung trägt
    Xcode es an der App-Id nach.
  - **Wirksam wird es erst SIGNIERT.** GitHub Actions baut mit
    `CODE_SIGNING_ALLOWED=NO` und sieht Entitlements nie an — ein grüner Bau
    sagt hier also nichts, und das ist dieselbe Regel wie beim iCloud-Recht
    seit 1.0.4. Gesehen wird es auf dem Gerät des Nutzers oder gar nicht.
  - **Zweimal an der falschen Stelle gesucht, und beide Male ohne Not.**
    1.0.41 baute den Wähler, 1.0.43 die Systemabfrage; beides war für sich
    richtig und beides konnte nichts ausrichten. **Was gefehlt hat, war eine
    Gegenprobe, die zwischen „diese App findet sie nicht" und „iOS gibt sie
    nicht heraus" trennt** — und die stand die ganze Zeit zur Verfügung: Der
    Wähler ist Apples eigener, also zeigt er, was das System der App zeigt.
    Die Probe nennt sie seit 1.0.44 im Klartext („Stehen deine Schriften im
    Wähler? Wenn nein, liegt es nicht an dieser Liste."), und die Fußzeile
    der Schriftwahl unterscheidet „keine da" von „diese App darf sie nicht
    sehen". **Merke: Wo zwei Erklärungen nebeneinander stehen und eine
    fremde App dieselbe Frage sichtbar beantwortet, ist der Vergleich mit
    ihr die billigste Messung.**
- **Nicht gemessen (1.0.44):** Dass das Recht fehlt, ist am Unterschied
  zwischen Pages und dem Wähler dieser App abgelesen und passt zu dem, was
  Apple dafür verlangt. **Dass es mit dem Recht geht, ist NICHT gemessen** —
  es braucht einen signierten Bau, und der entsteht auf dem Mac des Nutzers.
  Ebenso offen bleibt alles, was 1.0.43 offen gelassen hat (ob die
  Systemabfrage dann Einträge zurückgibt, ob sie sich als `UIFontDescriptor`
  lesen lassen, ob die Anmeldung greift, ob eine so erreichte Schrift ins
  PDF eingebettet wird). **Nichts davon als erledigt darstellen** — der
  Befund aus „Schriften prüfen" ist hier weiterhin die Messung.
- **EIN RECHT, DAS DIE APP-ID NICHT TRÄGT, MACHT DAS PROJEKT UNSIGNIERBAR**
  (Schriftenrecht wieder heraus in 1.0.45; gemeldet 09/2026 mit einem
  Bildschirmfoto aus Xcode: „Automatic signing failed — Provisioning profile
  ‚iOS Team Provisioning Profile: de.familie.urlaubstagebuch' doesn't match
  the entitlements file's value for the com.apple.developer.user-fonts
  entitlement."). 1.0.44 trug `com.apple.developer.user-fonts` in
  `Config/Urlaubstagebuch.entitlements` ein, damit die selbst installierten
  Schriften auftauchen. Die Absicht war richtig; der Preis war, dass sich die
  App **gar nicht mehr signieren ließ** — und damit war nicht nur die
  Schriftwahl weg, sondern jede Fassung, auch die davor gebauten.
  Ein Profil kann nur bewilligen, was die App-Id in der Entwicklerkonsole
  kann; steht in der Datei mehr, findet die automatische Signierung gar kein
  Profil mehr. **Genau diese Lehre steht seit dem ersten Signieren bei
  Schulalarm im Papier** („Wer der Erweiterung wieder eine Entitlements-Datei
  gibt, macht das Projekt unsignierbar") — sie galt hier genauso und wurde
  nicht gezogen. Das Recht ist deshalb **ersatzlos heraus** und nicht auf
  einen anderen Wert gestellt: Erst muss die App-Id es tragen, dann darf es
  in die Datei.
- **Ein grüner Bau in GitHub Actions kann das NICHT melden.** Er übersetzt
  mit `CODE_SIGNING_ALLOWED=NO` gegen den Simulator und sieht Entitlements
  nie an. Der Bau zu 1.0.44 war grün, „Fehler" leer, „Warnungen" leer — und
  die App war trotzdem auf kein iPad mehr zu bringen. Der Satz „Einen grünen
  Bau nie als signierbar ausgeben" stand für Schulalarm schon da; **er gilt
  für jede App dieses Repos, und eine Änderung an einer Entitlements-Datei
  ist genau der Fall, für den er gemacht ist.**
- **Der WERT war der zweite Fehler, und er war geraten.**
  `system-installed-fonts` steht in keinem nachschlagbaren Papier; belegt ist
  allein `system-installation` — und das ist das Recht, Schriften systemweit
  zu INSTALLIEREN, was diese App nicht tut. In Xcode heißt der gemeinte Haken
  „Use Installed Fonts"; welche Zeichenkette er schreibt, war von hier aus
  nicht zu messen. **Wer eine Zeichenkette in eine Entitlements-Datei
  schreibt, die er nicht nachschlagen kann, rät — und ein geratenes Recht
  kostet nicht eine Funktion, sondern den ganzen Bau.**
  **Nachtrag 1.0.66: `system-installed-fonts` gibt es nicht.** Die Probe aus
  1.0.45 hat am 23.09.2026 geantwortet — das Profil bewilligt
  `["app-usage", "system-installation"]`. **`app-usage` ist der Wert hinter
  „Use Installed Fonts"**, also der, um den es die ganze Zeit ging; er stand
  hier nie, weil er von hier aus nicht nachzuschlagen war. Der Absatz bleibt
  trotzdem stehen: Er ist der Beleg dafür, dass die Regel greift — die
  richtige Zeichenkette kam aus einer Messung auf dem Gerät und aus keiner
  Überlegung hier.
- **Was ein Bau DARF, wird seit 1.0.45 GELESEN** (`Model/Profilrechte.swift`,
  im Befund unter „Schriften prüfen" als erster Abschnitt). Gelesen wird die
  Rechteliste aus dem eingebetteten `embedded.mobileprovision` — also das,
  was das Profil bewilligt. Bis dahin stand in Quelltext und Oberfläche, das
  Recht sei „seit 1.0.44 in Kraft": eine Auskunft über das REPO, ausgegeben
  als Auskunft über das GERÄT. Dieselbe Art Lüge wie bei Schulalarms
  APNs-Umgebung, und dieselbe Antwort — **wo sich eine Frage nicht
  erschließen lässt, muss eine Probe entscheiden.** Zwei Dinge hält der
  Befund dabei auseinander: Die Entitlements-Datei sagt, was die App
  VERLANGT, das Profil sagt, was ihr BEWILLIGT ist; nur das Zweite ist von
  innen zu sehen. **Über TestFlight und aus dem Laden liegt gar kein Profil
  im Bündel** (dieselbe Beobachtung wie Schulalarm 1.0.19) — dann sagt die
  Zeile, dass sich hier nichts messen lässt, statt etwas zu behaupten.
- **Und die Fußzeile der Schriftwahl hört auf zu raten.** „Das kann zweierlei
  heißen: keine da — oder diese App darf sie nicht sehen" stand auch dann da,
  wenn sich die Frage beantworten ließ. Liegt ein Profil im Bündel und nennt
  es das Schriftenrecht nicht, ist es keine von zwei Möglichkeiten mehr,
  sondern der Befund, und die Zeile sagt ihn.
- **Der Weg zurück ist aufgeschrieben und wird nicht geraten:** in der
  Entwicklerkonsole bekommt die App-Id `de.familie.urlaubstagebuch` die
  Fähigkeit „Fonts", danach in Xcode die Fähigkeit „Fonts" mit dem Haken
  „Use Installed Fonts" — EINMAL, nicht zweimal (auf dem Bildschirmfoto
  standen zwei solche Abschnitte). Xcode schreibt dann selbst in die
  Entitlements-Datei, was richtig ist. Lässt es sich danach signieren, nennt
  „Schriften prüfen" die bewilligte Zeichenkette aus dem Profil, und **erst
  die gehört ins Repo.** Vorher nicht.
- **Nicht gemessen (1.0.45):** Dass die App sich jetzt wieder signieren
  lässt, hat niemand gesehen — hier gibt es keinen Mac. Gemessen ist die
  URSACHE: Das Recht kam in 1.0.44 hinein, vorher ließ sich signieren,
  nachher nicht, und die Fehlermeldung nennt genau diesen Schlüssel.
  Ungemessen bleibt auch, ob `Profilrechte` auf dem Gerät wirklich eine
  Liste findet — der Aufbau eines Profils ist nachgelesen, nicht an einer
  Datei geprüft; der Befund sagt es selbst, wenn nichts zu lesen war.
  **Nicht als erledigt darstellen.**
- **EIN WASSERZEICHEN IST KEIN BLOCK** (`Model/Wasserzeichen.swift`,
  `Gestaltung.wasserzeichen`, ab 1.0.46; Ansage des Nutzers 09/2026: „Ich
  lege einmal eine Bilddatei fest, für die das gelten soll. Und diese
  erscheint dann auf jeder Seite halbtransparent, möglichst an Stellen, an
  denen sonst noch kein Text oder Bild zu sehen ist."). Es steht deshalb am
  BUCH und wird beim Zeichnen jeder Seite ergänzt — dieselbe Regel wie bei
  Seitenzahl und Kopfzeile seit 1.0.0: Als Block läge es im Satz herum, ließe
  sich verschieben, löschen, und der Layoutautomat räumte es beim nächsten
  Neuanordnen weg. „Einmal festlegen" verträgt sich mit einem Block nicht.
- **Es liegt ÜBER dem Hintergrund und UNTER allen Blöcken.** Der Nutzer sagt
  selbst, dass Text darüber hinweggehen darf; obenauf läge dagegen ein
  Schleier über jedem Foto, und dann wäre die Deckkraft gar nicht mehr zu
  beurteilen. Gezeichnet wird es an beiden Stellen, an denen diese App eine
  Seite zeichnet (`SeitenflaecheView` und `Buchausgabe.zeichneSeite`) — die
  LAGE aber rechnet nur EINE Funktion (`Wasserzeichenlage.rechteck`): Zwei
  Fassungen ergäben eine Vorschau, die anders aussieht als der Druck.
- **„Wo gerade Platz ist" wird GEMESSEN, nicht geraten**
  (`Wasserzeichenlage`). Ein Raster von sieben mal sieben Lagen im
  Satzspiegel, gewertet wird die gewichtete Fläche, die schon belegt ist.
  **Die Gewichte sind der Kern:** Ein Foto (8) oder eine Karte DECKT das
  Zeichen zu — dort ist es weg; Text (1) läuft nur darüber hinweg, und
  genau das hat der Nutzer ausdrücklich erlaubt. Gleiche Gewichte legten
  das Zeichen lieber unter ein Foto als unter drei Zeilen Text. Die
  Gewichte sind **gewählt und nicht gemessen**.
- **Der Suchanfang hängt an der SEITE** (`seite.id.saat`, nie `hashValue`
  — den streut Swift je Programmlauf neu; dieselbe Falle wie beim
  Papierkorn in 1.0.16 und bei den Linienfarben der Abfahrtstafel). Damit
  landet das Zeichen auf zwei gleich leeren Seiten an verschiedenen Stellen,
  und dieselbe Seite bekommt beim nächsten Öffnen dieselbe.
- **Die Größe ist ein ANTEIL der Satzbreite, keine Millimeterzahl.** So
  übersteht sie den Formatwechsel von A4 auf A5 ohne eigene Zeile in
  `Formatwechsel` — dieselbe Überlegung wie bei `kartenanteil` und
  `textspaltenanteil`.
- **Das Seitenverhältnis wird EINMAL beim Einlesen gemessen** und steht in
  der Einstellung. Ohne diese Zahl müsste die Lagerechnung das Bild von der
  Platte holen, nur um seine Proportion zu erfahren — je Seite, bei jedem
  Neuzeichnen. Dieselbe Falle wie bei den berechneten Eigenschaften der
  Netzkarte in der Abfahrtstafel.
- **Eingepasst, nie gefüllt** (`Wasserzeichenlage.eingepasst`). Beim Foto
  ist das Füllen richtig, weil dort der Rahmen der Platz auf der Seite ist;
  hier wäre es ein Ausschnitt — und ein beschnittenes Ahornblatt ist kein
  Zeichen mehr, sondern ein Fleck (dieselbe Lehre wie beim Aufmacherband in
  1.0.34).
- **Der Weg führt in die DATEIEN, nicht in die Fotos**, und der Grund steht
  in der Oberfläche: Ein Wasserzeichen braucht einen durchsichtigen Grund,
  das kann PNG — die Mediathek gibt fast nur JPEG und HEIC heraus, und
  deren weißer Grund legte sich als helles Rechteck über die Seite. Die
  Datei wandert mit ihrer ECHTEN Endung ins Bildarchiv der Reise; ein
  `Foto`-Eintrag entsteht dabei nicht (es ist kein Reisefoto und gehört in
  keine Tagesliste).
- **Und genau deshalb muss sie in `Buchdatei.schreiben` ausdrücklich mit.**
  Dort läuft die Schleife über `reise.fotos`; das Wasserzeichen steht da
  nicht drin. Ohne die Zeile verlöre ein ausgetauschtes Buch sein Zeichen,
  und zwar STILL: Die Einstellung stünde weiter in der Datei, die Bilddatei
  fehlte. **Wer eine neue Bildart anlegt, trägt sie dort ein.**
- **Mit „Ohne Transparenz" fällt es WEG, statt deckend gezeichnet zu
  werden.** Beim Verlauf unter einer Überschrift ist das anders (dort wird
  ein geschlossenes Feld daraus), und der Unterschied hat einen Grund: Der
  Verlauf muss etwas LESBAR machen, das Zeichen muss gar nichts. Ein
  undurchsichtiges Ahornblatt mitten auf der Seite wäre keine abgeschwächte
  Fassung, sondern ein Fehler im Buch.
- **Was die Automatik nicht kann, ZÄHLT die Druckprüfung**
  (`Druckpruefung.wasserzeichen`). „Möglichst an Stellen, an denen sonst
  nichts steht" ist eine Zusage, die sich nur am fertigen Satz einlösen
  lässt: Auf einer Seite mit randabfallendem Foto gibt es keine freie
  Stelle, und dann liegt das Zeichen unter dem Bild. Die Zeile sagt, auf
  wie vielen Seiten das so ist — statt dass es jemand im gedruckten Buch
  sucht.
- **Nicht gemessen (1.0.46):** Keine Seite ist damit gesehen worden.
  Gerechnet ist die Geometrie; **gewählt und nicht gemessen** sind alle
  Zahlen — die Gewichte (Foto 8, Fläche 4, Überschrift 1,5, Text 1, Linie
  0,5), das Raster (7 × 7), die Vorgaben für Deckkraft (10 %) und Breite
  (34 % der Satzbreite) und die Schwelle der Befundzeile (gewichtete
  Belegung 4). Ob ein Zeichen bei 10 % im Druck noch zu sehen ist oder
  schon stört, sagt erst der erste Ausdruck — auf dem Bildschirm wirkt es
  kräftiger als auf Papier. **Nicht als erledigt darstellen.**
- **EIN HINTERGRUNDBILD ÜBER DIE DOPPELSEITE** (`Model/Bogenlage.swift`,
  `Seitenhintergrund.ueberDoppelseite`, ab 1.0.47; Ansage des Nutzers
  09/2026: „ich möchte einstellen können, dass ein Hintergrundbild über eine
  Doppelseite geht"). Bis 1.0.46 füllte ein Hintergrundfoto immer genau eine
  Seite; im aufgeschlagenen Buch standen damit zwei Ausschnitte desselben
  Bildes nebeneinander, jeder für sich vollständig.
  - **Ein SCHALTER und keine Automatik**, wörtlich erbeten: „Da ich nicht
    absehen kann, ob es vielleicht andere Konstellationen gibt, wo es
    sinnvoll ist, das Bild auf jeder Seite zu haben." Beides ist richtig, nur
    für verschiedene Bilder — ein Muster, ein Himmel oder eine Struktur
    gehört auf jede Seite, eine Landschaft über den Bund. Aus als Vorgabe:
    Was bisher gesetzt wurde, sieht danach unverändert aus.
  - **Welche Hälfte auf diese Seite fällt, ist BUCHBINDEREI und keine
    Einstellung.** Seite 1 ist ein Recto, also rechts; jede rechte Seite
    trägt eine ungerade Nummer. Die Regel stand seit 1.0.17 in
    `Reisewerk.doppelseiten` („Links die gerade, rechts die ungerade Nummer
    — nie umgekehrt") und steht jetzt als Funktion in `Bogenlage`; die
    Doppelseitenansicht holt sie von dort. Zwei Fassungen ergäben eine
    Ansicht, die anders paart als der Satz — und das sähe man erst im
    gedruckten Buch.
  - **Die Fläche ist 2 × Endformat breit, mit Anschnitt nur AUSSEN.** Am Bund
    stoßen die Endformate aneinander (deshalb zeichnet die
    Doppelseitenansicht sie ohne Abstand); innen deckt die Nachbarseite ab,
    dort gibt es nichts zu beschneiden. **Beschnitten wird trotzdem am
    Bogen** — die Nachbarseite ist ein eigenes Blatt Papier.
  - **Gerechnet wird an EINER Stelle** (`Bogenlage.bildflaeche` für das PDF,
    `Bogenlage.versatz` für SwiftUI — dieselbe Zahl, einmal als Rechteck in
    Seitenkoordinaten, einmal als Versatz gegen die Bogenmitte, weil ein
    `ZStack` mittig ausrichtet). Zwei Fassungen ergäben eine Vorschau, in der
    das Bild anders steht als im Druck.
  - **`HintergrundFlaeche` bekommt eine FESTE Größe.** Ein `ZStack` ist so
    groß wie sein größtes Kind; ein Bild über die Doppelseite ist breiter
    als diese Seite und zöge das Blatt auseinander. Der Rahmen steht deshalb
    VOR dem `.clipped()`. `bogen` und `seitennummer` sind wahlweise — die
    Probe im Hintergrund-Blatt steht nicht im Buch und hat keine
    Nachbarseite; dort gibt es keine Doppelseite, über die etwas gehen
    könnte.
  - **`Seitenhintergrund` liest sich seit 1.0.47 von Hand.** Er hatte keinen
    eigenen Leser, und das wäre hier still teuer geworden: `Gestaltung` holt
    ihn über `b.wert(.hintergrund, .weiss)`, eine einzelne Seite über
    `b.wahlweise(.hintergrund)` — ein neues Feld hätte in jedem vorhandenen
    Buch den Buchhintergrund auf Weiß zurückgesetzt und jeden eigenen
    Seitengrund verschwinden lassen, ohne eine Meldung. **Die Regel gilt für
    jeden Typ, der wächst**, und sie galt für diesen noch nicht.
  - **Was der Schalter NICHT kann, steht darunter.** Setzt jemand den
    Hintergrund je SEITE, braucht die Nachbarseite dasselbe Bild mit
    demselben Schalter — sonst steht im Buch die Hälfte des einen neben der
    Hälfte des anderen, und auf dem Bildschirm sieht jede Seite für sich
    tadellos aus. Deshalb zählt `Druckpruefung.doppelseitenhintergrund` die
    Bögen, die nicht aufgehen. Die Hälfte, die auf die Innenseite des
    Umschlags fällt (erster und letzter Bogen), wird eigens genannt und
    nicht als Fehler gezählt: Sie wird nie gedruckt, und das ist das Buch
    und kein Versehen.
- **DIE ZWEITE ÜBERSCHRIFT KOMMT AUS DER ZEILE NACH DEM DATUM**
  (`Textimport.zweiteUeberschrift`, `Reisetag.unterueberschrift`,
  `Blockinhalt.unterueberschrift`, `Schriftrolle.unterueberschrift`, ab
  1.0.48; Ansage des Nutzers 09/2026: „In dem zu importierenden Text … ist
  es so, dass nach dem Datum eine zweite Überschrift kommt, in der der Ort
  des Geschehens aufgeführt wird oder ein bestimmtes Schlagwort. Erst dann
  beginnt der Fließtext … Diese soll nicht genauso aussehen wie die
  Datumsüberschrift, sondern es soll erkennbar sein, dass es eine zweite
  Ebene … sein soll.“). Bis 1.0.47 wurde diese Zeile Fließtext — sie ging
  also nicht verloren, sie stand nur als erster Absatz im Tagebuchtext.
  - **Erkannt wird die KÜRZE, und das ist in BEIDEN Textsorten ein
    Merkmal.** In einem hart umbrochenen Text reicht eine gewöhnliche Zeile
    bis nahe an die Umbruchspalte (gemessen in 1.0.12: rund 88 Zeichen), in
    einem frei geschriebenen ist ein ganzer Absatz EINE sehr lange Zeile.
    Eine kurze Zeile unmittelbar nach dem Datum ist damit in keinem der
    beiden Fälle Fließtext. Dazu vier Bedingungen: höchstens 42 Zeichen
    und sechs Wörter, groß oder mit einer Ziffer anfangend, kein
    Satzzeichen am Ende (der Doppelpunkt ausgenommen und abgeschnitten),
    und kein Datum darin.
  - **Die wichtigste Bedingung ist, dass DANACH noch Text kommt.** Ein Tag,
    der nur aus dieser einen Zeile besteht, hat keine Überschrift — er hat
    einen sehr kurzen Text, und den als Überschrift zu setzen hieße, ihn
    aus dem Tagebuch zu nehmen. **Der Fehler in diese Richtung ist der
    teure**: Was als Überschrift gesetzt wird, fehlt danach im Fließtext.
  - **Behauptet wird nichts, gezeigt wird** — dieselbe Bauweise wie bei der
    Absatzerkennung seit 1.0.12: Die Vorschau nennt die gefundene Zeile je
    Tag eigens (und anders aussehend als die erste Überschrift, denn sie
    wird dem Fließtext WEGGENOMMEN), die Fußzeile zählt „an n von m Tagen
    gefunden“, **und auch der Fall „nirgends“ steht da** samt der Regel im
    Klartext. Ein Schalter stellt die Erkennung ab.
  - **Das Feld steht am TAG, nicht im Block** (`Reisetag.unterueberschrift`),
    wie Überschrift und Datumszeile: Der Block ist ein Vorschlag über dem
    Inhalt und wird beim Neuanordnen neu gerechnet. Eintippen lässt es sich
    deshalb auch ohne Einlesen — im Tagesmenü unter „Überschriften und
    Datumszeile“ — und auf der Seite mit dem Doppeltipp wie jeder Textkasten.
  - **`Typografie.unterueberschrift` ist OPTIONAL, und `nil` heißt
    „abgeleitet“ — nicht „leer“.** Abgeleitet wird aus der Überschrift:
    dieselbe Familie, 58 % der Größe, kursiv, nicht fett, in der
    Akzentfarbe. Der Grund ist derselbe wie bei `Schriftabweichung` — die
    sechs Buchstile setzen `titel` je einzeln, und ein fest eingetragener
    Vorgabewert stünde in jedem davon in einer fremden Schrift; ein siebter
    Stil vergäße ihn obendrein. Der erste Griff an einen Regler löst sie
    aus der Ableitung, und ein Knopf nimmt das zurück; das Schrift-Blatt
    sagt beides.
  - **`groessenSkalieren` und `familieUeberall` überspringen eine
    abgeleitete zweite Überschrift** (`Typografie.gesetzteRollen`). Beide
    rechnen über das SCHREIBEN des Wertes, und ein Schreiben macht aus der
    Ableitung eine Kopie. Am Ergebnis änderte das nichts (beide wirken
    gleichmäßig, und die Ableitung nimmt Größe und Familie aus dem Titel)
    — aber ab da folgte sie dem Titel nicht mehr, und das fällt erst beim
    nächsten Stilwechsel auf.
  - **`Typografie` liest sich seit 1.0.48 von Hand.** Die Regel steht seit
    1.0.3 im Papier und galt für diesen Typ noch nicht: `Reise` holt ihn
    über `b.wert(.typografie, Typografie())` — ein Feld, das der erzeugte
    Leser vermisst, hätte in jedem vorhandenen Buch ALLE vier Schriften auf
    die Vorgaben zurückgesetzt, und zwar still.
  - **Gesetzt wird sie nur auf dem AUFMACHER** (`Layoutautomat.kopfzeile`
    unter `!knapp`, und auf der ganzseitigen Aufmacherseite in Weiß). Auf
    der Fortsetzungsseite wäre sie dieselbe Angabe ein zweites Mal —
    dieselbe Regel wie beim Titel. Auf der ganzseitigen Aufmacherseite geht
    ihre Höhe in die Rechnung ein, BEVOR `y` gesetzt wird: Der Kopf wird
    dort von unten aufgebaut, und eine nachträglich eingeschobene Zeile
    schöbe den Titel aus dem Satzspiegel. Abgewichen wird dort nur die
    FARBE — Schrift und Größe holt der Satz über die Rolle des Blocks; sie
    zu kopieren machte aus der Ableitung wieder eine Kopie.
  - **Ein leerer Fund überschreibt nichts** (`Fotoeinfuhr.textVerteilen`),
    auch beim Ersetzen: Wer die zweite Überschrift von Hand eingetippt hat
    und denselben Text noch einmal einliest, verlöre sie sonst.
- **SEITENZAHLEN GAB ES NUR IM PDF** (`Model/Seitenbeiwerk.swift`, ab 1.0.50;
  gemeldet 09/2026: „Im Menü kann ich Seitenzahlen aktivieren. Diese kommen auf
  dem Dokument aber niemals zum Vorschein."). **Am Quelltext abzuzählen und
  keine Vermutung:** `Buchausgabe.zeichneFusszeile` war die EINZIGE Stelle im
  ganzen Quelltext, die `gestaltung.seitenzahlen` überhaupt las, und sie läuft
  nur beim Schreiben des PDF. Auf dem Bildschirm wurde nichts davon gezeichnet
  — der Schalter im Menü war dort seit 1.0.0 ohne jede Wirkung. Dasselbe galt
  für die Kopfzeile.
  - **Das verstieß gegen die erste Regel dieser App** („Seite und PDF zeichnet
    DERSELBE Setzer"), und zwar an der einen Stelle, an der eine Seite nicht
    aus Blöcken besteht. Blöcke sind Seitenzahl und Kopfzeile bewusst nicht:
    Sie gehören dem BUCH und nicht dem Tag; als Block lägen sie im Satz herum,
    wo sie jemand verschöbe und der Layoutautomat sie beim nächsten
    Neuanordnen wegräumte. Gerechnet wird jetzt in `Seitenbeiwerk`, und beide
    Zeichner holen sich dieselben Rechtecke — auf dem Bildschirm über denselben
    `Textkasten`, mit dem auch jeder andere Text gesetzt wird.
  - **Merke: Wer etwas beim Zeichnen einer Seite ergänzt, ergänzt es an BEIDEN
    Zeichnern.** Sonst steht es entweder nur auf dem Bildschirm oder nur im
    Druck, und beides sieht für den Menschen davor nach einem Fehler aus.
  - Die Fußzeile der Einstellung sagt seither auch, wo sie NICHT stehen:
    Titelseite, Rückseite und jede Seite, die ein Bild ganz ausfüllt
    (`ohneSeitenzahl`). Ein Schalter, der an drei Stellen wirkungslos ist,
    ohne dass es dabeisteht, führt wieder auf dieselbe Frage.
- **DER UMSCHLAG IST EIN BOGEN, KEINE SEITE** (`Model/Umschlag.swift`,
  `Model/Umschlagmass.swift`, ab 1.0.50; Ansage des Nutzers 09/2026: „Die
  Gestaltung der Titelseite. Diese soll völlig unabhängig von der Gestaltung
  der restlichen Seiten sein. … In meiner Erinnerung ist es bei Saal Digital
  beispielsweise so, dass die Titelseite bzw. der Umschlag des Buches so
  dargestellt wird, dass die rechte Hälfte einer Doppelseite die tatsächliche
  Titelseite ist und die linke Seite die Rückseite des Buches.").
  - **Er hat recht, und es stand so im Quelltext:** Die Titelseite nahm den
    Satzspiegel des Buches, seine Schrift, seinen Hintergrund und seinen Stil.
    Wer den Innenteil umgestaltete, gestaltete den Umschlag mit — bei einem
    gebundenen Buch schlicht falsch: Der Umschlag ist ein eigenes Stück Papier
    und läuft an der Druckerei durch eine eigene Maschine.
  - **Die Rückseite trägt die NUMMER 0, und damit paart sich der Bogen von
    selbst.** `Bogenlage` sagt seit 1.0.47: gerade Nummer links, ungerade
    rechts. 0 ist gerade, 1 ist die Titelseite — also liegt links die
    Rückseite und rechts der Titel, ohne eine einzige zusätzliche Regel.
    **Das ist der ganze Trick**, und er ist der Grund, warum die
    Doppelseitenansicht, die Hintergrundhälften und der Umschlag dieselbe
    Rechnung benutzen. Gezählt wird der Innenteil trotzdem ab 1: Der Umschlag
    gehört nicht zum Buchblock.
  - **Im vollständigen PDF fällt die Rückseite WEG** (`nummer > 0`). Sie
    stünde sonst als erste Seite vor dem Titel — eine Reihenfolge, die es im
    gebundenen Buch nirgends gibt. „Umschlag als eigene Datei" gibt dafür
    genau EINEN breiten Bogen aus.
  - **Keine TrimBox in der Mitte.** Sie sagt einer Druckerei, wo geschnitten
    wird; auf einem Bogen mit zwei Seiten und einem Rücken gäbe es dafür keine
    einzige richtige Stelle — geschnitten wird außen, gefalzt wird am Rücken.
    Dieselbe Überlegung wie bei der Broschüre seit 1.0.27.
  - **Jede Hälfte wird BESCHNITTEN gezeichnet** (`clip` auf ihre Fläche plus
    den außen liegenden Anschnitt). Ohne das liefe ein randabfallendes
    Titelfoto über den Rücken — also genau über die Beschriftung, die dort
    stehen soll.
- **DER RÜCKEN: gerechnet, nicht gemessen** (`Umschlagmass.rueckenbreite`, ab
  1.0.50; Ansage des Nutzers: „was an die Seite des Buches, also den Bereich,
  der die Dicke des Buches ausmacht, drauf gedruckt werden kann. Bislang habe
  ich dort immer den Titel des Buches untergebracht."). Blätter mal
  Papierstärke, beim Hardcover plus die beiden Deckel. **Beide Zahlen sind
  einstellbar, und daneben steht der Satz, dass die Angabe des Druckdienstes
  gilt** — wie dick ein Blatt aufträgt, weiß diese App nicht. Leer heißt: der
  Titel des Buches; ein Feld, das man erst füllen muss, um das Naheliegende zu
  bekommen, ist eine Hürde ohne Gewinn.
  - **Die Schrift läuft von OBEN nach UNTEN**, wie es hierzulande üblich ist:
    Ein Buch, das flach auf dem Tisch liegt, soll sich mit dem Titel nach oben
    lesen lassen. Im schon umgedrehten Zeichensystem ist das eine Drehung um
    +90 Grad.
  - **Der Rücken macht den Bogen BREITER**, und das gehört in jede Rechnung,
    die die Bühne einpasst (`ReiseView.breitesterBogen`). Ohne ihn wäre der
    Inhalt schmaler als das, was darin steht, und das letzte Stück des
    Umschlags ließe sich nicht heranschieben — dieselbe Falle wie 1.0.22.
- **Was am Umschlag `nil` ist, folgt weiter dem BUCH** (ab 1.0.50). Hintergrund,
  Rand, Schrift und Titelgröße sind Abweichungen und keine Kopien — dieselbe
  Regel wie bei `Schriftabweichung` seit 1.0.0 und bei `Block.wirkung` seit
  1.0.9, und aus demselben Grund: Kopierte der Umschlag beim ersten Antippen
  alle Werte des Buches, wäre jede spätere Änderung am Buchganzen an ihm
  wirkungslos, und zwar unsichtbar. Der Hintergrund läuft über denselben
  Bildschirm wie der des Buches und der einer Seite (`HintergrundView`,
  drittes Ziel) — drei Bildschirme für dieselbe Entscheidung liefen
  auseinander.
- **Was 1.0.50 NICHT baut: der Umschlag lässt sich nicht von Hand
  umbauen.** Titelseite und Rückseite werden gerechnet und bei jeder Änderung
  neu gesetzt; ein verschobener Block darauf wäre beim nächsten Durchgang
  weg. Das war bei der Titelseite seit 1.0.0 so und bleibt es. **Nicht als
  gelöst darstellen** — wer es baut, legt beide Seiten als echte `Seite` in
  der Reise ab und nimmt sie aus `alleNeuAnordnen` heraus.
- **EINE EINSTELLUNG, DIE ES NUR GLOBAL GIBT, IST HALB GEBAUT**
  (`Model/Kartenwahl.swift`, `Block.kartenbild`, `.kartenausschnitt`, ab
  1.0.51; Befund des Nutzers 09/2026: „Hier wollte ich gerade speziell nur
  für diese Karte Änderungen in den Einstellungen treffen. Zum Beispiel,
  dass Standortpunkte doch angezeigt werden und nicht nur die Linien.
  Offenbar kann ich das aber nicht für einzelne Karten, sondern nur
  global."). Er hat recht, und es war seit 1.0.0 so: Das Buch trug eine
  Karteneinstellung, ein TAG durfte sie überschreiben — die einzelne Karte
  auf der Seite nicht. Seit 1.0.39 lässt sich eine Karte auf eine zweite
  Seite KOPIEREN; damit gab es zwei Karten, die sich nicht auseinanderhalten
  ließen.
  - **Drei Ebenen, aufgelöst an EINER Stelle** (`Kartenwahl.geltend`):
    Block vor Tag vor Buch. Bildschirm (`KartenKachel`) und PDF
    (`Buchausgabe.kartenbilder`) fragen dieselbe Funktion — zwei Fassungen
    ergäben ein gedrucktes Buch, das anders aussieht als die Vorschau, und
    zwar erst dann anders, wenn es gedruckt ist. Dieselbe Regel wie bei
    `Block.wirkung` und `Bildausschnitt.zielrechteck`.
  - **Abweichung, keine Kopie.** `nil` heißt „wie der Tag", und wo der Tag
    nichts sagt, „wie das Buch". Kopierte der Block beim Anlegen die Werte,
    wäre jede spätere Änderung am Buchganzen an jeder schon einmal
    angefassten Karte wirkungslos — dieselbe Bauweise wie
    `Schriftabweichung` und der Fotostil seit 1.0.9.
  - **Der Abschnitt fragte den FALSCHEN Tag** (behoben in 1.0.51,
    `BlockInspektor.kartenstelle`). Er hing an `werk.tag`, also am gerade
    gewählten Tag — und der folgt seit 1.0.28 dem, was oben im Bild steht,
    nicht dem angetippten Block. Wer eine Karte antippte, während über ihr
    noch die letzte Seite des Vortags stand, stellte am VORTAG etwas um.
    Und zeigte `gewaehlterTag` auf einen Tag, den es nicht mehr gibt, fiel
    der ganze Abschnitt weg — dann war von der Karte aus GAR KEINE
    Karteneinstellung erreichbar. **Wer einen Abschnitt zu einem BLOCK
    baut, fragt den Tag des Blocks und nie den gewählten.**
  - **Die Kennung der `KartenKachel` nannte nur die SPANNE** (behoben in
    1.0.51). Wer die Karte verschob, ohne den Maßstab zu ändern, sah auf
    dem Bildschirm weiter den alten Ausschnitt; im PDF stand der neue. Der
    Schlüssel kommt jetzt aus `Kartenwahl.Geltend.merkmal` und nennt Mitte,
    Spanne und alles aus `Kartenbild.merkmal`. **Ein Zwischenspeicher-
    Schlüssel muss ALLES nennen, was das Bild verändert** — die Regel steht
    seit 1.0.37 an `Kartenbild.merkmal` und galt für die Ansicht daneben
    nicht.
  - **Die Einstellung überlebt das Neuanordnen** (`Reisewerk.seitenNeuSetzen`).
    Der Layoutautomat baut den Kartenblock frisch und weiß von der
    Abweichung nichts; ohne diese Stelle wäre sie nach jedem Neuanordnen
    weg, und zwar STILL — die Seite steht ja danach da. Es gibt seither
    genau EINEN Weg, der Seiten setzt (vorher sechs gleichlautende Zeilen);
    **wer einen zweiten baut, ruft diesen hier**, sonst ist derselbe stille
    Verlust wieder eingebaut. Dasselbe Muster wie `wortlautSichern` seit
    1.0.38.
  - **Eine Karteneinstellung ist keine Handarbeit am Satz**
    (`Reisewerk.karteAendern`). `aendere` setzt `vonHand`, und das ist
    richtig, wo jemand einen Block schiebt, dreht oder zieht. Wer die
    Reisepunkte einer Karte umstellt, hat an der ANORDNUNG nichts getan —
    der Tag fiele sonst wegen einer Farbe für immer aus dem automatischen
    Neuanordnen heraus.
- **DER UMSCHLAG ZÄHLTE IM BUCHBLOCK MIT — und schob damit jede Seite auf
  die falsche Hälfte** (`Buchteil`, ab 1.0.52; gemeldet 09/2026: „die erste
  wirkliche Seite im Fotobuch ist ja eine rechte Seite, also eine ungerade
  Seite. Bislang hast du es so dargestellt, dass die Seite 1 eine linke Seite
  ist. Denn links von der Seite 1 wäre ja praktisch die Innenseite des
  Umschlags, die nicht bearbeitet bzw. bedruckt wird."). **Er hat recht, und
  es ist am Quelltext abzuzählen:** `seitenfolge` vergab Rückseite 0,
  Titelseite 1 und der Buchblock begann bei 2 — und `Bogenlage.rechts` sagt
  seit 1.0.47, dass eine gerade Nummer LINKS liegt.
  - **Die Regel von 1.0.47 war richtig, die ZÄHLUNG darunter war falsch.**
    Der Umschlag ist ein eigenes Stück Papier und läuft an der Druckerei
    durch eine eigene Maschine (das steht seit 1.0.50 im Papier) — er kann
    also gar nicht in derselben Folge liegen wie der gebundene Block.
    **Merke: Wenn eine Paarung an der falschen Stelle beginnt, ist zuerst
    zu prüfen, was überhaupt mitgezählt wird, und erst danach die
    Paarungsregel.**
  - **`Buchteil` trennt die beiden Angaben**, die bis 1.0.51 eine waren:
    WO eine Seite liegt (`.rueckseite`, `.titel`, `.innen`) und WELCHE Zahl
    auf ihr steht (`nummer`, ab 1, nur im Block). Gilt der Umschlag als
    Bogen, tragen seine beiden Seiten die 0 und erscheinen in keiner
    Seitenzahl; ohne Bogen ist die Titelseite die gewöhnliche Seite 1 und
    liegt als ungerade Nummer ebenfalls rechts.
  - **Die Nummer taugt seither nicht mehr als Schlüssel** — Rückseite und
    Titelseite tragen beide 0. Dafür gibt es `Buchseite.rang` (die Stelle
    in der Folge, ab 0): Die Bühne bildet damit ab, welcher Tag oben im
    Bild steht (`imBlick`), und ohne den Rang löschte die eine
    Umschlagseite beim Verschwinden den Eintrag der anderen. **Wer aus
    einer Seite einen Schlüssel bildet, nimmt den Rang und nie die Nummer.**
  - **Die Seitenfolge stand ZWEIMAL da** — in `Reise.seitenfolge` und in
    `Reisewerk.seitenfolge`, die sich die gesetzten Umschlagseiten merkt,
    weil ihr Satz zwei CoreText-Messungen kostet. Genau so etwas läuft
    auseinander, und hier wäre es ein Buch gewesen, dessen Vorschau anders
    paart als die Datei. Gezählt wird jetzt in
    `Reise.seitenfolge(titelblatt:rueckblatt:)`; wer die Seiten SETZT,
    entscheidet der Aufrufer. Dasselbe gilt für `Buchseite.liegtRechts`,
    `.bogennummer` und `.kurzname` — drei Fragen, je eine Stelle.
  - **Die Druckprüfung baute die Nummerierung EBENFALLS selbst nach** (der
    Befund zum Hintergrund über die Doppelseite). Sie hätte nach diesem
    Umbau lauter Bogen gemeldet, die „nicht aufgehen". **Wer eine Zählung
    ändert, sucht nach jeder Stelle, die sie nachbaut** — hier waren es
    drei.
- **Ein Wasserzeichen darf SCHRÄG stehen** (`Wasserzeichen.drehspanne`, ab
  1.0.52, Ansage des Nutzers 09/2026: „ob diese Bilddatei so wie sie ist
  erscheint oder in einem einzustellenden Toleranzbereich gedreht ist,
  beispielsweise von minus 30 Grad bis plus 30 Grad").
  - **Der Winkel wird NICHT gewürfelt**, sondern aus `seite.id.saat`
    gezogen — nie aus `hashValue`, den streut Swift je Programmlauf neu.
    Dieselbe Seite steht damit beim nächsten Öffnen wieder gleich schief,
    und das PDF zeigt, was auf dem Bildschirm steht. Dritte Auflage
    derselben Regel nach dem Papierkorn (1.0.16) und dem Seitenrhythmus
    (1.0.31).
  - **Gezogen wird eine ZWEITE Zahl aus derselben Kennung**, nicht
    dieselbe: Die Lage nimmt den Rest zur Feldzahl, und wer denselben Rest
    auch für den Winkel nähme, koppelte beide — jedes Zeichen in derselben
    Ecke stünde gleich schief.
  - **Der PLATZ wird für den gedrehten Umriss gesucht** (`umschliessend`,
    `Wasserzeichenlage.Ort`). Ein um 30 Grad gedrehtes Bild braucht mehr
    Fläche als ein gerades; wer den Winkel erst beim Zeichnen draufsetzt,
    lässt es über den Satzspiegel ragen. Beide Zeichner drehen um dieselbe
    Mitte und passen das Bild in denselben inneren Rahmen ein — zwei
    Fassungen ergäben ein PDF, das anders aussieht als die Vorschau.
- **WER AUS EINEM VOLLBILD HERAUS MELDET, MELDET IN DIESEM VOLLBILD**
  (`PunktwahlView.quittung`, ab 1.0.52; gemeldet 09/2026: „Es wäre schön,
  wenn hier doch noch eine genauere Bestätigung durch die App erfolgen
  könnte. Ich bekomme zumindest keine Rückmeldung … Normalerweise kann ja
  dann dieses Fenster im unteren Bereich auch wieder schließen. Das tut es
  bislang nicht."). Gemeldet hat die App sehr wohl — über `werk.meldung`,
  und das Band wird in `ReiseView` gezeigt, während die Punktwahl seit
  1.0.49 als VOLLBILD darüberliegt. Es erschien also hinter der Karte.
  Dieselbe Lehre wie bei Schulalarm 1.0.26 („Ein Fehlerband unter einem
  Blatt sieht niemand"), und sie galt für diese Ansicht nicht.
  - **Die Quittung nennt, was übernommen wurde** — Ort, Name UND Uhrzeit.
    Wer eine Uhrzeit tippt, will genau diese zurückgelesen bekommen;
    „Gespeichert" allein ist keine Bestätigung, sondern eine Behauptung.
    Gelesen wird sie in derselben festen Zone, in der sie geschrieben
    wurde — mit der Zone des Geräts stünde dort eine andere Zahl als die
    getippte.
  - **Sie blendet NICHT von selbst weg.** Ein Band, das während des
    Nachlesens verschwindet, ist wieder keine Bestätigung. Weggeräumt wird
    sie durch eine Handlung: einen der beiden Knöpfe oder einen Tipp auf
    die Karte. Solange sie steht, ist die Eingabe zu und die Karte frei —
    das ist die zweite Hälfte des Befundes.
- **DIE TABELLE DES DRUCKDIENSTES SCHLÄGT DIE RECHNUNG**
  (`Umschlag.rueckentabelle`, ab 1.0.52, Ansage des Nutzers 09/2026: „Bei
  Saal Digital werden in einer Tabelle Breiten für den Buchrücken
  angegeben, die in Abhängigkeit der Seitenzahl des Buches zu erwarten
  sind."). Abhängig von der Seitenzahl war die Breite schon immer —
  gerechnet aus Blattzahl, Papierstärke und Einband. Was fehlte, ist der
  Weg, die Zahlen des Anbieters zu NEHMEN statt sie zu rechnen.
  - **Mitgeliefert wird keine Tabelle.** Versucht am 23.09.2026 (Saals
    Profi-Bereich und Preisseite) — beide geben die Zahlen nicht als Text
    heraus, sie stehen hinter einer Oberfläche. Eine nach Gefühl
    hingeschriebene Tabelle sähe aus wie eine Auskunft des Anbieters und
    wäre geraten; dieselbe Regel wie bei den Fahrplanquellen der
    Abfahrtstafel. Eingetragen wird sie unter Umschlag, Zeile für Zeile.
  - **Gilt die Zeile mit dem größten `abSeiten`, das das Buch erreicht** —
    und sagt die Tabelle über ein Buch nichts (leer, oder dünner als ihre
    erste Zeile), wird gerechnet. Die kleinste Zeile zu nehmen wäre
    falsch: Eine Tabelle, die bei 20 Seiten anfängt, hat über ein Buch mit
    12 Seiten keine Aussage getroffen.
  - **Woher die Zahl stammt, steht überall dabei**
    (`Umschlagmass.rueckenherkunft`). Eine gerechnete Zahl als Angabe des
    Druckdienstes auszugeben wäre genau die Art Lüge, die diese App nicht
    erzählt — dieselbe Regel wie bei „Plan" gegen „pünktlich".
- **Ein eigenes Seitenformat wird GEMERKT, nicht geraten**
  (`Model/Formatvorlagen.swift`, ab 1.0.52, Ansage des Nutzers 09/2026:
  „Speichere bitte auch die drei von mir gewählten Formate von Saal Digital
  als Formate für das Fotobuch."). Welche drei das sind, weiß diese App
  nicht, und eine Anbieterliste im Quelltext veraltet mit dem nächsten
  Angebot. Wer ein Maß eintippt, sichert es mit einem Tipp als Vorlage;
  sie liegt in den VOREINSTELLUNGEN und nicht im Buch — welche Formate ein
  Druckdienst anbietet, ist keine Eigenschaft dieser einen Reise (dieselbe
  Überlegung wie bei den selbst installierten Schriften seit 1.0.41).
  - **Angewandt ergibt eine eigene Vorlage ein FREIES Maß**, keinen neuen
    Vorlagennamen. `Seitenformat.init(from:)` löst einen alten
    Textschlüssel über `Seitenformat.vorlagen` auf; ein selbst vergebener
    Name stünde dort nie, und ein Buch mit einem Namen, den es beim
    nächsten Öffnen nicht mehr gibt, fiele still auf A4 quer zurück.
  - **21 × 28 cm und 28 × 21 cm sind dazugekommen**, weil sie zu den
    gängigsten Fotobuchformaten gehören und bisher fehlten. **Die Maße
    folgen der Formatangabe des Anbieters und sind nicht gemessen**; das
    steht so in der Oberfläche.
  - **Ein Beleg dafür, dass es SEINE Formate sind, gibt es nicht — und der,
    den ich zu haben glaubte, war keiner.** Das am 23.09.2026 geschickte
    PDF misst 595 × 793,72 Punkte (also 210 × 280 mm), und genau daraus
    stand hier kurzzeitig, 21 × 28 sei nachweislich sein Format. Beim
    Nachsehen enthielt die Datei aber ausschließlich Bilddaten und keinen
    einzigen Textzug: Es ist eine Zusammenführung von Bildschirmfotos, und
    ihr Seitenmaß gehört dem Werkzeug, das sie zusammengefügt hat.
    **Merke: Bevor ein Dateimaß als Beleg für den Inhalt gilt, ist zu
    prüfen, was in der Datei überhaupt steht.**
- **Zwei Dateien gab es seit 1.0.50 — gefunden hat sie niemand** (eigener
  Menüpunkt ab 1.0.52; gemeldet 09/2026: „Ich möchte bei der Exportfunktion
  Einbauen, dass automatisch ein Export von zwei PDF-Dateien vorgenommen
  werden soll."). Der Weg lag als eine von drei Zeilen in einem
  zugeklappten Picker hinter „Als PDF sichern…". **Zehnte Auflage von „es
  war da, man fand es nicht"**, und dieselbe Antwort wie bei der Broschüre
  in 1.0.37: derselbe Bildschirm, nur mit Vorwahl — und ein Name, der die
  Sache nennt („Umschlag und Innenteil getrennt…") statt des Werkzeugs.
  Kein zweiter Bildschirm; zwei Wege zu derselben Sache liefen auseinander.
  **Und bei einem Umschlagbogen sind zwei Dateien seither die VORWAHL** —
  das ist das „automatisch" aus der Ansage und nicht bloß Bequemlichkeit:
  Ein Bogen ist doppelt so breit wie eine Seite und hat mitten in einer
  Datei mit Buchseiten nichts zu suchen. Weggelassen wird dabei nichts;
  ausgegeben wird alles, nur eben zweimal.
- **Die Broschüre setzte die RÜCKSEITE nach vorn** (behoben in 1.0.52, beim
  Gegenlesen gefunden). In der Seitenfolge steht sie vorn, weil sie dort die
  linke Hälfte des Umschlagbogens ist — ein gefaltetes Heft hat aber weder
  Bogen noch Rücken: Dort ist die Titelseite die erste Seite und die
  Rückseite die letzte. Bis 1.0.51 lief sie als Heftseite 1 mit, also noch
  vor dem Titel. **Das war schon damals falsch und fiel erst auf, als die
  Zählung selbst zum Thema wurde** — dieselbe Wurzel, eine Ansicht weiter.
- **EIN `scaleEffect` IST EINE ABBILDUNG, KEINE ZEICHNUNG**
  (`Model/Bildschaerfe.swift`, ab 1.0.53; gemeldet 09/2026 mit einem
  Bildschirmfoto bei 400 %: „Wie wird der Text eigentlich gerendert? Er wirkt
  unscharf."). **Am Quelltext abzuzählen und keine Vermutung:** Core Animation
  rastert eine Ebene GENAU EINMAL, mit `layer.contentsScale` Bildpunkten je
  Punkt, und der Vorgabewert ist der Maßstab des Bildschirms. Der
  `scaleEffect` über der Seite zieht dieses fertige Bild danach auf. Der Text
  wurde also weiterhin mit zwei Bildpunkten je Seitenpunkt GESETZT und bei
  400 % auf acht GEZEIGT — ein halber gerasterter Punkt je Bildschirmpunkt.
  Nichts daran war falsch gezeichnet, es war zu grob gezeichnet.
  **Merke: Wer in einer UIView selbst zeichnet und sie vergrößern lässt, setzt
  `contentsScale` — sonst wird das Bild gedehnt statt neu gesetzt.** Dieselbe
  Wurzel wie `contentMode = .redraw` aus 1.0.8, eine Ebene tiefer: Dort wurde
  das Bild bei einer Größenänderung gedehnt, hier bei einer Vergrößerung.
  - **Dasselbe eine Ebene weiter bei den FOTOS.** `vorschaukante` stand auf
    festen 2,2 Bildpunkten je Seitenpunkt — richtig für die unvergrößerte
    Seite auf einem gewöhnlichen Gerät und sonst nirgends; bei 400 % blieb ein
    halber. Es war also nie ein Fehler des Textsatzes, sondern einer, den
    jedes gerasterte Element auf dieser Seite hatte.
  - **Die Zahl steht an EINER Stelle** (`Bildschaerfe`) und gilt für Text,
    Fotos, Wasserzeichen und Hintergrundfoto. Liefen sie auseinander, wäre auf
    derselben Seite das eine scharf und das andere weich.
  - **Der GERÄTEMASSSTAB kommt aus der eigenen Ansicht** —
    `traitCollection.displayScale` bzw. `\.displayScale` —, nie aus
    `UIScreen.main`: Hängt ein Beamer am iPad, wäre das die falsche Auskunft
    (dieselbe Lehre wie bei Tafelbilds Dokumentenkamera).
  - **Gestuft und gedeckelt.** Gestuft, weil jede Zwischengröße sonst ihre
    eigene Rasterung bekäme — und im `Bildarchiv` einen eigenen Eintrag, denn
    dessen Schlüssel nennt die Kante. Gedeckelt durch ein Pixelbudget je
    Fläche, weil ein Textkasten von 430 × 700 Punkten bei achtfacher
    Rasterung 77 MB wöge und mehrere davon in der Bühne liegen.
  - **`traitCollectionDidChange` ist seit iOS 17 abgekündigt** und wird
    deshalb NICHT überschrieben; ein Wechsel des Bildschirms läuft ohnehin
    durch `didMoveToWindow` und `layoutSubviews`.
  - **Die KARTE bleibt, wie sie ist**, und das ist kein Vergessen: Sie wird
    seit jeher mit vier Bildpunkten je Seitenpunkt aufgenommen
    (`Kartenwerk.massstab` = 2 auf eine doppelt so große Fläche). Weiter
    hinauf hilft es nicht — `Kachelkarte` ist auf 48 Kacheln gedeckelt (so
    will es die Nutzungsrichtlinie der OSM Foundation), und eine größere
    Anforderung zöge nur eine tiefere Zoomstufe nach sich, die an derselben
    Grenze wieder gröber wird. Bei starker Vergrößerung ist sie damit das
    gröbste Element auf der Seite; das gehört gesagt und nicht verschwiegen.
  - **Das Textfeld beim Bearbeiten ist NICHT mitgezogen.** `InlineText` ist
    ein `UITextView`, und der setzt über TextKit in eigene Unterebenen; ein
    `contentsScale` an der äußeren Ansicht erreicht sie nicht verlässlich.
    Wer bei starker Vergrößerung doppeltippt, sieht also weiter weichen Text.
    Nicht als erledigt darstellen.
- **Und weil sich das hier nicht nachmessen lässt, sagt es die App**
  (`Schaerfeprobe`, im Befund unter „Bedienung prüfen", ab 1.0.53). Gemeldet
  wird, was WIRKLICH gesetzt wurde: Bildpunkte je Seitenpunkt gegen die, die
  gebraucht würden, dazu Gerätemaßstab, Bühnenmaßstab, die Größe des Kastens
  und ob das Budget gedeckelt hat. Nach einer Fassung, deren Ursache gerechnet
  und nicht gesehen ist, ist das der einzige Weg, die nächste Frage mit Zahlen
  statt mit Vermutungen zu beantworten — dasselbe Muster wie Schulalarms
  Stufenprobe und der Kartenmesser der Abfahrtstafel. **Ein schlichtes
  `final class` ohne `@Published`**, aus demselben Grund wie beim
  `Zeichenmesser`: Wäre es beobachtbar, löste jede Rasterung ein Neuzeichnen
  aus, das seinerseits gemeldet würde.
- **DIE TABELLE LAG SCHON HIER — im PDF, das der Nutzer mitgeschickt hatte**
  (`Model/Rueckentabellen.swift`, ab 1.0.54; Ansage des Nutzers 09/2026:
  „Ich habe dir bereits eine Tabelle von Saal Digital hochgeladen. Das war
  das PDF-Dokument mit den eingescannten Bildern. Schau dort bitte rein und
  übernimm diese Werte."). In 1.0.52 stand an dieser Stelle das Gegenteil:
  Die Tabelle werde „EINGETRAGEN und nicht mitgeliefert", weil sie sich von
  hier aus nicht abrufen lasse. Für die Webseite stimmte das; die Zahlen
  lagen trotzdem längst hier. Dieselbe Datei war in 1.0.52 schon einmal
  untersucht worden — aber nur auf die Frage, ob ihr Seitenmaß als Beleg für
  ein Buchformat taugt, und die Antwort („sie enthält nur Bilddaten") wurde
  zur Auskunft über ihren INHALT verallgemeinert. **Merke: Bevor etwas als
  unerreichbar gilt, wird nachgesehen, was schon dasteht — und ein Befund
  über eine Datei beantwortet nur die Frage, die ihm gestellt wurde.**
- **Gelesen wurde aus den BILDDATEN, nicht aus Textzügen** (23.09.2026). Das
  PDF trägt neun Bildschirmfotos zu je 2048 × 2732 Bildpunkten, flate-gepackt
  in einem ICC-RGB-Raum und ohne einen einzigen Textzug. Entpackt und
  angesehen ergeben sie drei vollständige Tabellen: „Fotobuch 21 × 28
  (ca. A4)", „Fotobuch 28 × 28" und „Fotobuch 28 × 19 (ca. A4 quer)", jeweils
  Hardcover, jeweils von 26 bis 160 Innenseiten. **Damit ist auch die Frage
  aus 1.0.52 beantwortet, welche drei Formate der Nutzer meint.**
- **Was dort steht, sind PIXEL.** Saal gibt den Buchrücken als Bildbreite
  samt Auflösung an — 142 px bei 300 dpi, beim Querformat 143 px bei 302 dpi;
  das sind 12,02 bzw. 12,03 mm. Alle drei Tabellen ergeben dieselbe Leiter
  aus ganzen Millimetern, und die größte Abweichung dabei ist 0,05 mm. Im
  Quelltext stehen deshalb die ganzen Millimeter, die Pixelwerte daneben im
  Kommentar: Das ist eine Rundung und keine Erfindung.
- **Zwei Eigenarten der Leiter sind übernommen, nicht geglättet.** Sie
  überspringt 17 und 23 mm (189 → 213 px, 260 → 283 px), und die Formate
  unterscheiden sich NICHT in den Millimetern, sondern nur darin, bei welcher
  Seitenzahl eine Stufe anfängt: 21 × 28 ist den beiden anderen um genau eine
  Stufe voraus (26–28 → 12 mm, dann 30–34 → 13 mm; sonst 26–30 → 12 mm).
  Warum, sagt die Tabelle nicht, also steht auch keine Erklärung da. Eine
  Zeile ist nicht unmittelbar abgelesen: 72 fiel in die Lücke zwischen zwei
  Bildschirmfotos und folgt aus ihrer Dreiergruppe — das steht so im
  Quelltext.
- **Über ihrer letzten Zeile schweigt eine Tabelle genauso wie unter ihrer
  ersten** (`Vorlage.bisSeiten`, 160). Einem Buch mit 200 Seiten die 36 mm
  der Zeile 158 zu geben wäre kein Nachschlagen mehr, sondern eine
  Hochrechnung — dort wird wieder gerechnet. Die EIGENE, eingetippte Tabelle
  hat diese Grenze nicht: Sie gehört dem Nutzer, und was er einträgt, gilt.
- **Eigene Zeilen gehen jeder mitgelieferten Tabelle vor** (`Umschlag.tabellenbreite`).
  Was jemand selbst einträgt, hat er von seinem Druckdienst; was hier
  beiliegt, ist von einem Bildschirmfoto abgelesen. Die Reihenfolge ist
  damit: eigene Tabelle, eingebaute Tabelle, Rechnung aus Papierstärke und
  Einband — und `rueckenherkunft` nennt bei jeder Zahl, welche der drei es
  war. Eine abgelesene Zahl als Rechnung auszugeben (oder umgekehrt) wäre
  genau die Art Lüge, die diese App nicht erzählt.
- **Welche Tabelle gilt, entscheidet das SEITENFORMAT — mit großzügiger
  Toleranz, und die ist gemessen.** Der Produktname und das Maß der
  mitgelieferten Vorlage gehen bei Saal auseinander: Die Innenseiten-Vorlage
  des „21 × 28" misst 5031 × 3260 px bei 300 dpi, abzüglich der angegebenen
  35 px Beschnitt also 420,0 × 270,1 mm — zwei Seiten von **210 × 270**.
  Beim „28 × 28" sind es 270 × 270, beim „28 × 19" 280 × 188. Eine Toleranz
  unter einem Zentimeter verfehlte damit genau das Format, für das die
  Tabelle gedacht ist; sie steht auf 12 mm. **Die Maße der Vorlagen folgen
  trotzdem dem PRODUKTNAMEN**, und die abweichende Messung steht als Messung
  daneben: Welches von beidem die Druckerei schneidet, sagt der Anbieter und
  nicht diese App.
- **Verglichen wird das ungeordnete PAAR der Kanten.** Ob ein Buch hoch oder
  quer steht, ändert am Papier nichts, und die Dicke hängt am Papier — Saals
  eigene Zahlen belegen das, denn 28 × 19 quer trägt dieselbe Millimeterleiter
  wie 28 × 28.
- **Der Nutzer kann die Zuordnung übergehen** (`Umschlag.tabellenvorlage`,
  `.ohneVorlage`). „Nichts gewählt" und „ausdrücklich keine" sind zwei
  verschiedene Aussagen und stehen deshalb in zwei Feldern — dieselbe Lehre
  wie bei `Block.ohneGrund` seit 1.0.12. Dazu ein Knopf, der die Zeilen in
  die eigene Tabelle übernimmt: Wer die Zahlen ändern will, will sie danach
  auch vor sich sehen.
- **DIE AUTOMATIK GAB ES, DIE KORREKTUR NICHT** (`Wasserzeichenabweichung`,
  `Views/WasserzeichenSeiteView.swift`, ab 1.0.54; Ansage des Nutzers
  09/2026: „Ich habe mich unpräzise ausgedrückt. Bei dem Wasserzeichen hätte
  ich gerne eine automatische Ausrichtung durch dich im einstellbaren
  Toleranzbereich … Dennoch soll es mir möglich sein, einzelne Seiten
  bezüglich des Wasserzeichens noch anzupassen und die Drehung oder eine
  Verschiebung zu korrigieren. Offenbar hast du mich falsch verstanden.").
  Die automatische Hälfte war gebaut: Die LAGE wird seit 1.0.46 auf jeder
  Seite neu gesucht, der WINKEL seit 1.0.52 je Seite aus ihrer Kennung
  gezogen. Was fehlte, ist die zweite Hälfte — und im Quelltext stand sogar
  wörtlich das Gegenteil davon („die Seite selbst kann nichts davon
  abweichen — genau das ist der Sinn eines Wasserzeichens"). **Merke: Wo ein
  Nutzer sagt, er sei missverstanden worden, ist zuerst zu prüfen, welche
  Hälfte seiner Bitte schon dasteht — und dann die andere zu bauen, nicht
  die erste noch einmal.**
- **Abweichung, keine Kopie.** `Seite.wasserzeichen` ist wahlweise; `nil`
  heißt „ganz automatisch", ein eigener Winkel `nil` heißt „der gezogene".
  Würde eine angefasste Seite alle Werte kopieren, wäre jede spätere Änderung
  an Größe, Deckkraft oder Drehspanne an ihr wirkungslos — und zwar
  unsichtbar. Dieselbe Regel wie bei `Schriftabweichung`, `Block.wirkung` und
  `Kartenwahl`. Eine Abweichung, die nichts mehr sagt, wird wieder `nil`:
  Sonst zählte die Druckprüfung eine Korrektur, die keine ist.
- **Aufgelöst wird an EINER Stelle** (`Wasserzeichenlage.ort`), gefragt von
  der Ansicht UND vom PDF. Der eigene Winkel gilt auch dann, wenn die
  Drehung im Buch ausgeschaltet ist — wer eine einzelne Seite schräg haben
  will, sagt das dort. Und die Verschiebung bleibt IM SATZSPIEGEL: Dieselbe
  Grenze gilt für die Automatik, und was darüber hinausginge, wäre im Druck
  angeschnitten. Die Oberfläche schreibt das hin, statt den Regler ins Leere
  laufen zu lassen.
- **Der Versatz ist eine LÄNGE und wird beim Formatwechsel mitgerechnet**,
  der Winkel nicht — dieselbe Trennung wie zwischen Blockrahmen und
  Blockdrehung seit 1.0.27.
- **Ohne Rettung wäre die Korrektur nach dem nächsten Neuanordnen weg**
  (`Reisewerk.seitenNeuSetzen`). Der Layoutautomat baut die Seiten frisch;
  übernommen wird die Korrektur nach der STELLE im Tag und nicht nach der
  Kennung, denn die neuen Seiten haben neue — und damit zieht die Automatik
  ohnehin einen anderen Winkel. Das ist eine Entscheidung und keine Messung,
  und die Oberfläche sagt sie auch. Dasselbe Muster wie die Karteneinstellung
  seit 1.0.51: **Es gibt genau EINEN Weg, der Seiten setzt, und wer einen
  zweiten baut, ruft diesen hier.**
- **Eine Wasserzeichen-Korrektur ist KEINE Handarbeit am Satz.** Sie setzt
  `vonHand` nicht — sonst fiele ein Tag wegen eines halben Grads für immer
  aus dem automatischen Neuanordnen heraus; dieselbe Überlegung wie bei
  `karteAendern` seit 1.0.51. Genau deshalb muss die Rettung darüber
  existieren.
- **Die Oberfläche zeigt die Automatik, statt sie zu behaupten.** Das Blatt
  nennt den Winkel, den diese Seite automatisch bekommt, und zeichnet eine
  SKIZZE: Satzspiegel, die Blöcke als graue Flächen, das Zeichen an seiner
  gerechneten Stelle und in seinem gerechneten Winkel — gezeichnet aus
  demselben `ort`, den auch das PDF fragt. Dass Winkel und Lage von Seite zu
  Seite wechseln, lässt sich hinschreiben; hier steht es als Zahl und als
  Bild. Das ist die halbe Antwort auf „offenbar hast du mich falsch
  verstanden".
- **EIN SCHLEIER NIMMT DEN FARBEN IHREN ABSTAND — UND DAS IST AUSZURECHNEN**
  (`Model/Farbkraft.swift`, `Seitenhintergrund.farbkraft`, ab 1.0.55;
  Befund des Nutzers 09/2026: „Beim Seitenhintergrund stelle ich fest, dass
  eine Einstellung von Transparenz dazu führt, dass die Farben sich eher
  Richtung Grau in Grau verschieben. … ich könnte mir vorstellen, dass man
  gleichzeitig beim Zurücknehmen der Deckungskraft auch die Kräftigkeit der
  Farben erhöht."). Er hat recht, und es ist kein Eindruck: Über dem
  Hintergrundfoto liegt eine Fläche in der Papierfarbe mit der Deckkraft a,
  herauskommt `(1 − a) · foto + a · papier`. Der ABSTAND zwischen größtem
  und kleinstem Kanal eines Bildpunktes — also genau das, was eine Farbe
  von einem Grau unterscheidet — wird damit mit `(1 − a)` multipliziert.
  Beim Vorgabeschleier von 72 % bleibt gut ein Viertel übrig, und weil das
  JEDE Farbe des Bildes trifft, rücken sie alle zusammen.
- **Dagegen hilft genau EIN Faktor.** Wird das Foto VOR dem Schleier
  gesättigt (`neu = licht + k · (kanal − licht)`), wächst derselbe Abstand
  um k; mit `k = 1 / (1 − a)` steht er nach dem Schleier wieder dort, wo er
  war. Das Bild bleibt blass und wird trotzdem bunt — pastell statt grau,
  also genau das Erbetene.
- **Was der Faktor NICHT kann, steht in derselben Zeile.** Zurückgeholt wird
  der ABSTAND der Kanäle, nicht die Sättigung im engeren Sinn: Sättigung ist
  Abstand geteilt durch Helligkeit, und die Helligkeit hebt der Schleier
  mit. Rechnerisch kommt der bunteste denkbare Bildpunkt hinter einem
  Schleier von a auf `1 − a` Sättigung heraus — bei 72 % also 28 %, und
  mehr ist dort überhaupt nicht möglich, ganz gleich, was das Foto zeigt.
  Der Regler führt bis an diese Decke und keinen Schritt weiter; die
  Oberfläche nennt die Zahl. **Eine Grenze, die man verschweigt, wird für
  einen kaputten Regler gehalten.**
- **Was er kostet, wird GEMESSEN und nicht geschätzt** (`Farbkraft.randanteil`).
  Was über 1 oder unter 0 gestreckt wird, klemmt ab, und dort verliert das
  Bild seine Zeichnung. Gezählt wird an einer 48 Bildpunkte großen Fassung,
  einmal vorher und einmal nachher — gemessen ist damit das SIEB selbst und
  keine Annahme darüber, mit welchen Gewichten `CIColorControls` rechnet.
  Ein Foto mit weißem Himmel liegt schon ohne Faktor am Rand; das dem
  Schieber anzulasten wäre eine falsche Auskunft, deshalb die Differenz.
- **Gesättigt wird an EINER Stelle.** `Farbkraft.verstaerkt` ruft der
  Bildschirm (über `Bildarchiv.vorschau(…farbkraft:)`) und das PDF
  (`Seitensatz.zeichneHintergrund`); den Faktor nennt beiden
  `Seitenhintergrund.farbkraftfaktor`. Zwei Wege ergäben zwei Bilder, und
  der Unterschied fiele erst auf, wenn das Buch beim Drucker liegt — die
  erste Regel dieser App. Gerundet wird auf Zwanzigstel (`Farbkraft.stufe`),
  weil der Faktor im Schlüssel des Bildvorrats steht: **Ohne ihn im
  Schlüssel stünde nach dem Umstellen das Bild von vorhin da, und der
  Schieber sähe aus, als täte er nichts** — dieselbe Falle wie beim
  `merkmal` des Kartenbildes in 1.0.51.
- **Nur beim FOTO, und der Grund gehört dazu.** Eine einfarbige Fläche mit
  halber Deckung über weißem Papier IST eine hellere Farbe — dort ist
  nichts auszugleichen, dort wählt man gleich die hellere. Grau in Grau
  wird nur ein Bild, weil darin viele Farben zugleich zusammenrücken. Das
  steht so in der Fußzeile, statt einen Regler anzubieten, der dort nichts
  tut.
- **Dieselbe Arithmetik gilt für das Wasserzeichen und für einen farbigen
  Textgrund — dort wird sie bewusst NICHT ausgeglichen.** Ein Wasserzeichen
  SOLL zurücktreten, und ein Grund unter Schrift soll die Schrift tragen
  und nicht mit ihr konkurrieren. Wer es dort nachrüstet, sagt vorher, was
  dadurch besser wird.
- **Vorgabe 0.** Jedes vorhandene Buch sieht nach dem Update unverändert
  aus — dieselbe Überlegung wie bei `ueberDoppelseite` in 1.0.47.
- **ZEHN WASSERZEICHEN STATT EINEM — und die Kennung der Seite zieht**
  (`Zeichenbild`, `Wasserzeichen.bilder`, `Wasserzeichenlage.automatischesBild`,
  ab 1.0.56; Ansage des Nutzers 09/2026: „Ich möchte die Möglichkeit haben,
  noch mehr Bilder für ein Wasserzeichen hochzuladen. Möglich sein sollen
  insgesamt bis zu zehn verschiedene. Diese sollen dann nach dem
  Zufallsprinzip auf den einzelnen Seiten abgelegt werden. Auch hier möchte
  ich im Nachhinein entscheiden können, welches Symbol auf einer Seite zu
  liegen kommt.").
- **Das Seitenverhältnis gehört dem BILD, nicht dem Wasserzeichen.** Bis
  1.0.55 stand die Zahl an `Wasserzeichen`, weil es nur ein Bild gab; bei
  zehn gilt sie je Bild — und die Lagerechnung braucht genau die des
  Bildes, das auf DIESER Seite liegt. Deshalb der eigene Typ `Zeichenbild`.
  Alles andere (Deckkraft, Größe, Lage, Drehspanne, Titelblatt) bleibt am
  Wasserzeichen: Das ist eine Entscheidung über das Buch und nicht über
  ein einzelnes Symbol.
- **`Ort` sagt seit 1.0.56 auch, WELCHES Bild hier liegt.** Es steht in
  derselben Antwort wie der Rahmen, weil beides zusammenhängt: Die Höhe
  folgt dem Seitenverhältnis dieses Bildes. Wer es getrennt ermittelte,
  zeichnete irgendwann ein Bild in den Rahmen eines anderen — und das
  fiele erst im gedruckten Buch auf. **Buchausgabe holt deshalb erst die
  LAGE und dann die Datei**, nicht mehr umgekehrt: Vorher lässt sich gar
  nicht wissen, welche Datei zu holen ist.
- **Gezogen wird aus der KENNUNG der Seite, nie aus dem Zufall.** Dritte
  Auflage derselben Regel nach Papierkorn (1.0.16), Seitenrhythmus (1.0.31)
  und Zeichenwinkel (1.0.52): Dasselbe Buch muss beim nächsten Öffnen
  gleich aussehen, und das PDF muss zeigen, was auf dem Bildschirm steht.
  Es ist die DRITTE Zahl aus derselben Kennung und wird eigens gemischt —
  die Lage nimmt den Rest zur Feldzahl, der Winkel einen anderen Rest.
  Nähme das Bild denselben, hinge es an der Ecke, und jedes Zeichen oben
  links wäre dasselbe.
- **Eine laufende Nummer wäre gleichmäßiger und ist bewusst NICHT gebaut.**
  Die Kennung der Seite ist das Einzige, worüber sich alle vier
  Aufrufstellen einig sind (Bildschirm, PDF, Druckprüfung, das Blatt für
  eine Seite). `Buchseite.rang` gibt es in zweien davon, in den anderen
  nicht in derselben Zählung — und zwei Zählungen ergäben ein PDF, das
  anders aussieht als die Vorschau. **Der Preis steht dafür im Befund:**
  Gleichverteilt ist das Ziehen im ERWARTUNGSWERT und nicht gleich oft; bei
  zehn Bildern auf vierzig Seiten bleibt rechnerisch mit rund einem Siebtel
  Wahrscheinlichkeit eines ganz ungenutzt. Die Druckprüfung zählt deshalb
  seit 1.0.56, wie oft jedes Bild wirklich vorkommt, und sagt es, wenn
  eines gar nicht vorkommt. Dieselbe Lehre wie bei den Linienfarben der
  Abfahrtstafel: **Ein Streuwert verteilt zufällig, nicht gleichmäßig.**
- **Die Korrektur nennt den DATEINAMEN, nicht die Nummer**
  (`Wasserzeichenabweichung.bild`). Wer ein anderes Bild entfernt,
  verschöbe sonst alle Nummern dahinter, und die Seite zeigte plötzlich ein
  fremdes Zeichen. **Ein Name, den es nicht mehr gibt, zählt als nicht
  gesetzt** — die Seite fällt auf die Automatik zurück, statt eine leere
  Fläche zu versprechen; dieselbe Regel gilt im Wähler, sonst stünde dort
  eine Auswahl, die es nirgends gibt.
- **Ein alter Schlüssel wird weiter GELESEN** (`AlteZeichenschluessel`,
  dieselbe Bauweise wie in `Model/Reise.swift`). Jede Datei von vor 1.0.56
  trägt `datei` und `seitenverhaeltnis` statt der Liste; ohne diesen Weg
  verlöre jedes vorhandene Buch sein Wasserzeichen, und zwar STILL — die
  Einstellung stünde weiter in der Datei, das Bild fehlte. Gelesen wird der
  alte Schlüssel nur, wenn die Liste LEER ist, sonst stünde ein längst
  entferntes Bild wieder darin.
- **Hinzugefügt, nicht ersetzt** — und mehrere Dateien auf einmal
  (`Dateiwahl(mehrere: true)`): Wer zehn Symbole hat, soll nicht zehnmal
  denselben Weg gehen. Was über die Zehn hinausgeht, wird GEZÄHLT und
  gemeldet; stillschweigend die Hälfte zu verschlucken wäre der schlimmere
  Fehler.
- **Und wer eine neue Bildart anlegt, trägt sie in `Buchdatei.schreiben`
  ein.** Die Zeichenbilder sind keine Reisefotos und stehen in keiner
  Fotoliste; seit 1.0.56 ist es eine Schleife über `gueltigeBilder` statt
  einer einzelnen Datei. Vergäße man sie, verlöre ein ausgetauschtes Buch
  seine Zeichen.
- **VIER GIGABYTE WAREN DREI FEHLER AUF EINMAL** (ab 1.0.70; gemeldet
  09/2026: „muss auch einen Link geben, dass die Exportdatei bei 62 Seiten
  nicht 4 Gigabyte groß wird. Denn das wird von den Druckdiensten leider
  nicht angenommen.“). Jeder für sich ist unauffällig; zusammen ergeben sie
  eine Datei, die niemand hochladen kann.
  - **Jedes Bild bekam dieselbe Höchstkante.** `fuerAusgabe` rechnete alles
    auf `bildkante` herunter — ein Briefmarkenfoto auf dieselben 3600
    Bildpunkte wie ein randabfallendes. Gedruckt wird aber eine FLÄCHE, und
    was mehr Bildpunkte je Zoll trägt, als das Papier auflöst, ist Platz
    ohne Bild. Gerechnet wird die Kante seit 1.0.70 je Bild aus dem Rahmen,
    in den es gezeichnet wird (`Ausgabeguete.ausgabekante`): `ziel / 72 *
    dpi`, gedeckelt durch die Güte. **Wer diese Rechnung ändert, ändert die
    Prüfung mit** — `Ausgabeguete.dpi` kennt den neuen Deckel, sonst nennt
    sie wieder eine Zahl, die die Datei nicht hält (die Lehre aus 1.0.59).
  - **Das Wasserzeichen wurde JE SEITE frisch geladen** — mit voller
    Höchstkante, auf jeder der 62 Seiten. Das allein sind Dutzende
    Megabyte für ein Zeichen, das auf dem Papier eine Handbreit misst. Es
    kommt jetzt einmal je Datei aus `wasserzeichenbilder`, in der Größe,
    die es wirklich einnimmt. Dass CoreGraphics dasselbe `UIImage` zu
    einem einzigen Bild in der Datei zusammenfasst, ist die Erwartung und
    **nicht gemessen**; die kleinere Kante wirkt unabhängig davon.
  - **`UIImage.draw(in:)` schreibt UNKOMPRIMIERT.** Drei Byte je
    Bildpunkt — ein seitenfüllendes Foto bei 300 dpi sind rund 25 MB.
    Stammt ein `CGImage` dagegen aus einem JPEG-Datenstrom, übernimmt
    CoreGraphics diesen Strom unverändert (DCTDecode), statt ihn zu
    entpacken (`Seitensatz.jpegEingebettet`). **Erwartung, keine Messung**:
    Greift es nicht, ist die Datei so groß wie vorher, kaputt ist nichts.
  - **Ein Bild MIT Alphakanal wird NIE als JPEG geschrieben.** JPEG kennt
    keine Durchsichtigkeit; eine eingesetzte Grafik mit freigestelltem
    Grund bekäme einen weißen Kasten. Das ist die eine Stelle, an der
    diese Abkürzung sichtbar falsch wäre — deshalb wird sie geprüft und
    nicht angenommen. **Das Wasserzeichen bleibt aus demselben Grund
    unkomprimiert** und wird gar nicht erst gefragt.
  - **Gezeichnet wird dann mit `CGContext.draw`, und das rechnet von UNTEN
    links.** Der Zeichenkontext dieser App ist längst umgedreht, also wird
    um die Mittellinie des Zielrechtecks noch einmal gespiegelt. Wer das
    vergisst, bekommt jedes Foto auf dem Kopf — und zwar nur im PDF.
  - **Die Güte trägt seither DREI Zahlen** (Höchstkante, Ziel-dpi,
    JPEG-Güte), und der Auftrag wird an EINER Stelle gebaut
    (`AusgabeView.auftrag(…)`). Sechsmal derselbe Aufruf mit drei Feldern
    wäre sechsmal die Gelegenheit, eines zu vergessen — und ein vergessenes
    `jpegGuete` fällt erst an der Dateigröße auf.
  - **Die Größe steht VOR dem Ausgeben da** (`Ausgabeguete.groessenschaetzung`,
    Zeile unter der Gütewahl). Bis 1.0.69 stand sie erst danach — nach
    zwanzig Minuten Rechnen und mit einer Datei, die kein Dienst annimmt.
    **Es ist eine SCHÄTZUNG und sagt das auch**: Gezählt werden die
    Bildpunkte, die wirklich geschrieben werden; wie dicht ein JPEG die
    packt, hängt am Motiv. Danebengestellt wird, was dieselben Bilder
    unkomprimiert wögen — das ist die Zahl, die der Nutzer gesehen hat.
  - **Nicht gemessen (1.0.70):** Keine Datei ist damit ausgegeben worden.
    Gerechnet ist die Geometrie; **die beiden großen Hebel — JPEG-Strom
    und Zusammenfassen gleicher Bilder — sind Erwartungen an CoreGraphics
    und keine Messungen**. Was sicher wirkt, ist die kleinere Kante. Ob aus
    vier Gigabyte ein paar hundert Megabyte werden, sagt erst die nächste
    Ausgabe des Nutzers — und seit 1.0.70 sagt die Schätzung vorher eine
    Zahl, die sich daran messen lässt. **Nicht als erledigt darstellen.**
- **EIN VORSCHAUBILD HIELT DEN HAUPTFADEN AN — seit 1.0.59 als offen
  notiert** (`Views/Vorschaubild.swift`, `Bildarchiv.ausVorrat`/`.holen`, ab
  1.0.81; gemeldet 09/2026, zum wiederholten Mal: „Das Scrollen über mehrere
  Seiten hinweg gestaltet sich auf dem iPad echt schwierig. Offenbar muss da
  doch noch sehr viel im Hintergrund nachgeladen und aufgebaut werden.").
  - **Am Quelltext abzuzählen, und der Punkt stand dort seit 1.0.59:**
    `Bildarchiv.vorschau` liest bei einem Fehlschlag im Vorrat SYNCHRON von
    der Platte und entpackt das Bild sofort
    (`kCGImageSourceShouldCacheImmediately`) — aufgerufen wurde sie im
    KÖRPER der Seitenansicht, also auf dem Hauptfaden. Beim Scrollen baut
    der `LazyVStack` laufend neue Blätter, und jedes zog seine drei bis
    sechs Bilder nach; das Hintergrundfoto ist dabei das größte, es füllt
    Seite oder Doppelseite ganz aus. **Merke: Ein offener Punkt, der
    zweimal als „nicht gemessen" dasteht, ist beim dritten Befund der erste
    Verdacht.**
  - **`ausVorrat` fragt nur den Vorrat und kostet nichts**; ist dort nichts,
    holt `Vorschaubild` es über `holen` abseits des Hauptfadens.
    `Task.detached` und nicht bloß `Task`: Ein nacktes `Task` in einer
    `@MainActor`-Ansicht erbt den Hauptfaden — dann wäre nichts gewonnen
    (dieselbe Falle wie bei Schulalarms `BackgroundRefresh`, nur
    andersherum).
  - **Kein Platzhalter mit Symbol.** Eine Seite, auf der für einen
    Augenblick graue Kästen mit Bildzeichen stehen, sieht kaputter aus als
    eine, auf der das Bild eine Wimper später erscheint.
  - **Der Schlüssel nennt Datei, Kante UND Farbkraft.** Eine vergessene
    Stelle zeigte nach dem Umstellen das Bild von vorhin — dieselbe Falle
    wie beim `merkmal` des Kartenbildes in 1.0.51.
  - **Die Zähler im `Bildarchiv` sind GESPERRT.** `vorschau` läuft seit
    1.0.81 auch aus einem Hintergrundfaden; zwei Fäden, die auf dieselbe
    Zahl addieren, sind ein Datenrennen — auch wenn die Zahl nur eine
    Auskunft ist.
  - **Und weil sich das hier nicht nachmessen lässt, misst es die App:** Der
    Befund unter „Bedienung prüfen" nennt seither „Bilder: n× aus dem
    Vorrat, m× von Platte". Bleibt m beim Blättern klein, liegt es nicht
    mehr an den Bildern — dann ist der nächste Verdacht der CoreText-Satz je
    Textkasten. Dasselbe Muster wie Schulalarms Stufenprobe.
  - **Offen und nicht als erledigt darstellen:** Umgestellt sind die drei
    Stellen der BÜHNE (Fotokachel, Hintergrundfoto, Wasserzeichen). Die
    Listen und Blätter (Regal, Tagesliste, Hintergrundwahl, Stilwahl) holen
    ihre kleinen Bilder weiterhin synchron; sie scrollen auch, sind aber
    nicht der gemeldete Fall, und eine Sache wird auf einmal geändert.
- **WAS IN DEN ANSCHNITT ODER IN DEN SICHERHEITSABSTAND RAGT, BEKOMMT EINEN
  DICKEN ROTEN RAHMEN** (`Reise.ueberDerSchnittkante`, `.amRandGefaehrdet`,
  `Randmarke`, ab 1.0.81; Ansage des Nutzers 09/2026: „Ich möchte ab jetzt,
  dass ein Element, was in den Beschnittbereich oder den Sicherheitsbereich
  hineinragt, mit einem noch besser zu sehenden Rand versehen wird. Gerne
  ein dicker roter Rand.").
  - **Der ANSCHNITT wurde gar nicht geprüft.** Markiert war seit 1.0.76 nur
    der Sicherheitsabstand — dabei ist der andere Fall der teurere: Ein
    Block, der über die Schnittkante ragt und nicht randabfallend ist, wird
    im gedruckten Buch ANGESCHNITTEN, und das fiel erst am Papier auf. Die
    Druckprüfung zählt ihn seither als eigene Zeile.
  - **Die Marke hängt NICHT mehr an „Linien zeigen".** Sie tat es seit
    1.0.76, und das war falsch: Die Linien sind eine Hilfe beim Anordnen,
    die Marke ist eine WARNUNG. **Eine Warnung, die sich mit den
    Hilfslinien abschalten lässt, ist keine.**
  - **Rot, obwohl die Schnittkante auch rot ist** — das ist die Ansage des
    Nutzers, und sie geht auf: Die Marke ist dreimal so dick, durchgezogen
    statt gestrichelt, läuft um einen BLOCK und nicht am Blattrand und
    trägt eine Kontur. Zu verwechseln sind die beiden nicht.
  - **Randabfallende Blöcke bleiben ausgenommen, ohne Ausnahme** — sie
    SOLLEN über die Kante laufen; nach der dritten falschen Marke sieht
    niemand mehr hin.
- **Nicht gemessen (1.0.81):** Nichts davon ist auf einem Gerät gesehen
  worden. **Am Quelltext ABGEZÄHLT ist die Ursache des zähen Scrollens** (ein
  synchroner Griff auf die Platte samt sofortigem Entpacken, im Körper jeder
  Seite, bei jedem neuen Blatt) — **dass es danach flüssig ist, folgt daraus
  NICHT**: Es kann eine zweite Ursache darüberliegen, und der
  wahrscheinlichste nächste Verdacht ist der CoreText-Satz je Textkasten.
  Genau dafür nennt der Befund jetzt zwei Zahlen statt einer Zusage. Ebenso
  ungesehen: ob die leere Fläche vor dem Eintreffen des Bildes stört und ob
  ein dicker roter Rahmen neben der roten Schnittkante wirklich zu
  unterscheiden ist. **Nichts davon als erledigt darstellen.**
- **DREI LINIEN, DREI FARBEN — UND EINE KONTUR, DAMIT MAN SIE AUF JEDEM
  GRUND SIEHT** (`Model/Seitenlinien.swift`, ab 1.0.80; gemeldet 09/2026 mit
  Bildschirmfoto: „Die dünn gestrichelte rote Linie für den Mindestabstand
  kann ich nur schwer erkennen. Ich hätte hier gerne eine ebenso dicke Linie
  wie für den Beschnitt, nur in einer anderen Farbe, zum Beispiel hier blau.
  Ich frage mich, ob man diese Linien auch sieht, wenn der Seitenhintergrund
  dunkel gewählt wird. … Auf dem Beispielbild sind noch weitere Linien zu
  sehen. Welche sind das denn eigentlich?").
  - **Drei Befunde in einer Frage, und alle drei treffen.**
  - **Die Abwägung von 1.0.73 war falsch herum.** Dort stand, der
    Sicherheitsabstand sei orange und „**nicht blau**: Das ist beim
    Einrasten seit jeher der NACHBAR, und dieselbe Farbe für zwei Auskünfte
    ist eine Auskunft weniger." Der Satz stimmt — nur trägt die Fanglinie
    des Nachbarn ihren NAMEN am Strich und steht nur, solange ein Finger
    zieht; die Schutzzone steht dauernd da und trägt nichts. **Wer von zwei
    Auskünften eine benennen kann, gibt der anderen die klarere Farbe.** Der
    Sicherheitsabstand ist seither blau und ebenso dick wie die
    Schnittkante, der Nachbar violett.
  - **Farbe allein trägt nicht**: Die beiden dicken Linien unterscheiden
    sich zusätzlich im Strichbild (lang gegen kurz), sonst wären sie für
    einen farbfehlsichtigen Menschen dieselbe Linie — dieselbe Regel wie
    beim entfallenden Halt in der Abfahrtstafel.
  - **Die dritte Linie war der SATZSPIEGEL, und niemand hatte sie je
    benannt.** Sie lief in `Color.accentColor`, also in einem Ton, den die
    App setzt; auf einem Buch mit warmer Akzentfarbe stand sie neben zwei
    rötlichen Linien. Sie ist jetzt neutral grau und fein gepunktet: Sie ist
    die schwächste der drei Auskünfte — eine Hilfe für den Satz und keine
    Angabe der Druckerei.
  - **Auf dunklem Grund verschwanden alle drei.** `Seitenhintergrund.dunkel`
    gibt es seit 1.0.0, und gefragt hat sie nur der Textsatz. Jede Linie
    bekommt deshalb eine KONTUR in der Gegenfarbe und auf dunklem Grund
    einen helleren Ton. **Die Kontur ist der wichtigere Teil**: Bei einem
    FOTO als Hintergrund hilft keine Farbwahl, weil der Untergrund
    stellenweise hell und stellenweise dunkel ist — dieselbe Bauweise wie
    bei den Linienzügen der Abfahrtstafel (1.1.9).
  - **Die Farben standen DOPPELT da** — in `SeitenflaecheView` und in
    `Fanglinie` — und waren schon auseinandergelaufen (verschiedene
    Strichstärken für dieselbe Sache). Sie stehen jetzt in `Seitenlinie`,
    gefragt von der Seite, der Fanglinie, der Skizze und der Legende. **Wer
    eine vierte Stelle baut, fragt dort.**
  - **„Welche sind das denn eigentlich?" ist ein Befund über die
    OBERFLÄCHE.** Die Legende gab es — in der Skizze unter „Ränder und
    Druckzugaben", also dort, wo man die Zahlen einstellt, und nicht dort,
    wo man die Linien sieht. Sie steht seit 1.0.80 zusätzlich als Band über
    der Bühne, solange die Linien eingeschaltet sind, und verschwindet mit
    dem Schalter. Als ÜBERLAGERUNG und nicht als Zeile im Stapel: Eine Zeile
    nähme der Bühne Höhe, und `buehnenhoehe` geht in die Zoomrechnung ein.
    `allowsHitTesting(false)`, damit sie keine Geste schluckt (1.1.18).
  - **Die orange Warnfarbe in der Beschriftungszeile BLEIBT** („⚠ 2 Blöcke
    im Sicherheitsabstand"). Sie sagt „hier stimmt etwas nicht" und nicht
    „das ist diese Linie"; der Bezug steht im Wort. Die MARKE um den Block
    auf der Seite folgt dagegen der Linie und ist jetzt blau — sie hat kein
    Wort daneben.
- **Nicht gemessen (1.0.80):** Keine Seite ist damit gesehen worden. Die
  Farben und Strichbilder sind **gewählt und nicht gemessen** — ob Rot und
  Blau in diesen Tönen auf einem hellblauen Seitenhintergrund wie dem des
  Nutzers deutlich auseinandertreten, sagt erst der nächste Befund. Ebenso
  ungeprüft, ob die Kontur bei 0,28 Deckung auf einem Foto reicht und ob die
  Legende über der Bühne an der richtigen Stelle sitzt. **Und der Befund zum
  dunklen Hintergrund ist am Quelltext hergeleitet, nicht gesehen:** Dass
  die Linien dort verschwanden, folgt aus den festen Farben — angesehen hat
  es niemand. **Nichts davon als erledigt darstellen.**
- **GEZÄHLT WURDE ANWESENHEIT, GEMEINT IST SICHTBARKEIT**
  (`ReiseView.reiheInDerMitte`, ab 1.0.79; gemeldet 09/2026 mit
  Bildschirmfoto: „Das Datumsfeld hängt immer mindestens einen Tag
  hinterher. Im Blickfeld sind eigentlich schon die Seiten des 4. Augustes
  und auswählbar ist der 3. Das stört.").
  - **Am Quelltext abzuzählen:** `tagImBlick` nahm seit 1.0.28 die KLEINSTE
    anwesende Reihennummer. Ein Bogen, der nur noch mit einem Streifen oben
    am Bildschirmrand hängt, zählt damit genauso wie der, der den ganzen
    Schirm füllt — und gewinnt, weil seine Nummer kleiner ist. Auf dem
    Bildschirmfoto ist genau das zu sehen: oben der letzte Zentimeter von
    „Seiten 0 und 1", darunter vollflächig „Seiten 2 und 3", und im
    Datumsfeld der Tag des ersten.
  - **Dazu feuert `onAppear` in einem `LazyVStack` nicht am Sichtrand**,
    sondern am Rand des Vorbereitungsbereichs — SwiftUI baut ein Stück im
    Voraus. Die „oberste anwesende" Reihe ist also oft eine, die gar nicht
    zu sehen ist. **Merke: `onAppear` meldet Anwesenheit, nicht
    Sichtbarkeit; wer aus mehreren Meldungen EINE auswählt, braucht ein
    Maß dafür, welche gemeint ist.**
  - **Gewählt wird die Reihe, welche die MITTE des Sichtfelds überdeckt** —
    gerechnet aus derselben Geometrie, an der auch der Zoom hängt
    (`Zoomanker.griff`), und mit derselben Umrechnung wie `massstabSetzen`.
    Der AUSLÖSER bleibt `onAppear`/`onDisappear`: Gerechnet wird damit nur,
    wenn eine Reihe kommt oder geht, und nicht bei jedem Bildpunkt —
    `Inhaltslage` hat aus gutem Grund kein `@Published` (die Lehre aus
    1.0.16). Findet sich für die Mitte keine Meldung, gilt wie bisher die
    oberste: ein Rückfall und keine Behauptung.
  - **Die Seitenvorwahl hing an derselben Zeile** (`seitenvorwahl`, seit
    1.0.61) und ist mitgezogen. Wer eine Auswahl aus „was man sieht"
    ableitet, hat sie meist an mehr als einer Stelle.
- **WER EINEN SAMMELBILDSCHIRM NACH EINEM TEIL SEINES INHALTS BENENNT, MACHT
  DEN ANDEREN TEIL UNSICHTBAR** (`Views/KartenstilView.swift`, ab 1.0.79;
  Frage des Nutzers 09/2026: „Gibt es eigentlich irgendwo eine Möglichkeit,
  eine globale Einstellung für die Reisepunkte zu treffen? Im vorliegenden
  Fall möchte ich beispielsweise einstellen können, dass überall nur die
  Spur angezeigt wird und nicht die Punkte.").
  - **Es gab sie — und 1.0.77 hat sie versteckt.** Die buchweite
    `KartenbildWahl` lag in `GestaltungView`, und deren Menüpunkt hieß
    „Ränder, Karte, Seitenzahlen…". In 1.0.77 wurde er zu „Ränder und
    Druckzugaben…", weil er nach seinem Inhalt heißen sollte — dahinter
    liegen tatsächlich Anschnitt, Sicherheitsabstand und Bundsteg. Mit dem
    Wort „Karte" ist aber der einzige Hinweis darauf verschwunden, dass
    auch die Karteneinstellung dort wohnt. **Dreizehnte Auflage von „es war
    da, man fand es nicht" — und die erste, die aus einer Verbesserung
    entstanden ist.** Merke: Wer einen Menüpunkt umbenennt, zählt vorher
    auf, was alles dahinterliegt.
  - Die Karten bekommen deshalb einen EIGENEN Menüpunkt („Ganzes Buch →
    Karten…"), wie „Fotos…" (1.0.10) und „Textfelder…" (1.0.12) und aus
    demselben Grund: Es ist eine Wirkung, die für alle gilt, und sie wird
    dort gesucht, wo die Frage entsteht. Gezeigt wird dieselbe
    `KartenbildWahl`, die auch Tag und einzelne Karte benutzen — zwei
    Fassungen desselben Formulars liefen auseinander.
  - **In der Gestaltung bleibt eine AUSKUNFT mit dem Weg** (Reisepunkte und
    Kartenbreite als Zeile, dazu wo es eingestellt wird). Ein Bildschirm,
    der einen Wert nicht mehr führt, muss sagen, wo er jetzt steht —
    dieselbe Regel wie beim Seitenformat seit 1.0.27. Und der Knopf „Für
    alle Karten im Buch einstellen" im Inspektor zeigt seither dorthin; ein
    Weg, der auf einen Bildschirm zeigt, der die Sache nicht mehr führt,
    ist schlimmer als kein Weg (Lehre aus 1.0.49).
- **Nicht gemessen (1.0.79):** Nichts davon ist auf einem Gerät gesehen
  worden. **Am Quelltext ABGEZÄHLT ist die Ursache des hinterherhängenden
  Datums** (die kleinste anwesende Nummer gewinnt, und `onAppear` meldet
  früher als das Auge sieht) — und sie passt Punkt für Punkt zum
  Bildschirmfoto. **Ungeprüft ist die Abhilfe:** Ob `Inhaltslage.ursprung`
  im Augenblick des `onAppear` schon den neuen Stand trägt, ist die Lesart
  der Reihenfolge und keine Messung; hinkt sie um einen Durchgang, steht
  das Datum weiterhin eine Reihe daneben — dann ist der nächste Griff, die
  Rechnung an `onChange(of: lage.meldungen)` zu hängen. Ebenso ungesehen,
  ob der neue Menüpunkt gefunden wird: Geändert sind Wege und Namen, und
  das ist keine Messung (dieselbe Einschränkung wie bei den Menüs in
  1.0.20 und 1.0.49). **Nichts davon als erledigt darstellen.**
- **AM BUND WIRD NICHT GESCHNITTEN — und die Ansicht behauptete es doch**
  (`Bogenkante`, `Schnittlinien`, ab 1.0.78; gemeldet 09/2026: „In der
  Gestaltungsansicht sehe ich an der Falz innen immer noch zwei gestrichelte
  Linien. Eine für den Beschnitt und eine für den Sicherheitsabstand. Laut
  Druckerei wird aber doch dort kein Beschnitt ausgeführt. Und in den
  Seitenmaßen sieht man ja auch, dass drei Millimeter von einer Doppelseite
  ringsherum abgezogen werden, aber nicht innen.").
  - **Er hat recht, und die Stelle steht seit 1.0.58 im Papier — als
    „richtig so".** Dort hieß es: „Am Bund liegen ZWEI Anschnitte, und die
    stehen doppelt da … Das ist keine Panne der Ansicht." Für die
    EINZELSEITEN-Ausgabe stimmte das: Dort trägt jede Seite ringsum
    Anschnitt. Seit 1.0.69 gibt es die DOPPELSEITEN-Ausgabe, und die
    schreibt den Bogen so, wie er gedruckt wird — „der Anschnitt liegt
    ringsum AUSSEN, am Bund keiner"; seit 1.0.50 gilt dasselbe für den
    Umschlagbogen. **Damit war aus einer hingeschriebenen Ungenauigkeit eine
    Abweichung zwischen Ansicht und Datei geworden** — und die verbietet die
    erste Regel dieser App. **Merke: Eine Ungenauigkeit, die man
    hinschreibt, bleibt nur so lange vertretbar, wie keine zweite Stelle es
    besser macht. Wer eine Ausgabe hinzufügt, prüft, welche Erklärung sie
    widerlegt.**
  - **`Bogenkante` sagt, an welcher Kante die Nachbarhälfte anstößt** —
    `.links`, `.rechts`, `.keine`. Dort fällt der Anschnittstreifen weg und
    mit ihm die rote Schnittkante; die Endformate stoßen aneinander, genau
    wie in `doppelseitenPdf`. `.keine` ist die Einzelseitenansicht, und dort
    bleibt alles, wie es war: Die Einzelseiten-PDF trägt ringsum Anschnitt.
  - **Die ORANGE Linie bleibt am Bund, und das ist kein Versehen.** Dort
    wird nicht geschnitten, aber es verschwindet etwas im Falz — genau
    dafür gibt es seit 1.0.76 den eigenen Innenwert. Zwei Linien an einer
    Kante waren zu viel, eine ist die Auskunft.
  - **`Rectangle().strokeBorder` kann nur alle vier Kanten**, gebraucht
    werden drei. `Schnittlinien` ist deshalb ein `Shape`. **Wer eine neue
    Aufrufstelle anlegt, gibt ihr die Kante mit** — auch `Schutzzonenskizze`
    zeichnet seither dasselbe.
  - **Die Bühne wird schmaler, und das musste mitgezogen werden**
    (`ReiseView.breitesterBogen`, `massstaebe`). Bis 1.0.77 wurde die Breite
    eines Einzelbogens verdoppelt, also zwei Anschnitte zu viel. Das war
    folgenlos, solange die Ansicht sie auch zeichnete; jetzt stünde rechts
    ein leerer Streifen, und der Zoom rechnete auf einer falschen Zahl (die
    Lehre aus 1.0.22). Gerechnet wird an EINER Stelle
    (`Bogenlage.doppelbogen`).
  - **`HintergrundFlaeche` baute die Doppelseitenfläche NACH** (`bogen.width
    + format.width`). Das ging nur auf, solange der Bogen an beiden Seiten
    einen Anschnitt trug. Sie fragt jetzt `Bogenlage.bildflaeche`, also die
    Funktion, die auch das PDF bekommt. **Wer eine Rechnung nachbaut,
    bezahlt sie beim nächsten Mal, wenn sich ihre Voraussetzung ändert.**
    `Bogenlage.versatz` wird damit nirgends mehr gebraucht und ist
    ersatzlos entfernt — ein Feld, das niemand liest, ist ein halb gebautes
    Vorhaben.
- **EIN SCHALTER, DER NACH DER BESCHRIFTUNG HEISST, DARF NICHT DIE GEOMETRIE
  ÄNDERN** (`Umschlagmass.rueckenbreite`, ab 1.0.78; gemeldet 09/2026: „Auf
  der anderen Seite bekomme ich in das Format des Umschlages offenbar nicht
  die 2 mm Rückenbreite hineingesetzt. Ich kann sie zwar eingeben und
  bestätigen lassen … aber nach wie vor steht dort als Gesamtbreite 426 mm
  und nicht 428, wie es sein müsste.").
  - **Die Zahl IST der Befund, und sie ist nachzurechnen:** 426 =
    2 × 210 + 2 × 3. Der Rücken zählte also mit null — und die einzige
    Stelle im ganzen Quelltext, die null zurückgeben konnte, war
    `guard umschlag.rueckenZeigen else { return 0 }`. Gerechnet wäre die
    Breite bei einem Hardcover nie null (allein die Deckel tragen auf), eine
    Tabelle sagt entweder etwas oder gar nichts, und eine von Hand
    eingetragene Zahl schlägt seit 1.0.72 beides. **Wo eine Zahl um genau
    einen Summanden danebenliegt, wird nicht geraten, sondern der Summand
    gesucht.**
  - Der Schalter heißt „Rücken bedrucken" und nahm die ganze RÜCKENBREITE
    aus dem Bogenmaß. Wer keinen Titel auf dem Rücken wollte, bekam damit
    stillschweigend einen Umschlag ohne Rücken, und der Knopf „Rückenstärke
    übernehmen" nahm die Zahl an, ohne dass sie irgendwo ankam — ein Knopf,
    der schweigt. **Ein Buch hat einen Rücken, auch wenn nichts darauf
    steht.** Er heißt jetzt „Text auf dem Rücken" und steuert nur noch die
    Schrift; die Prüfung steht in `rueckenbeschriftung`, also an der einen
    Stelle, die Bildschirm UND PDF fragen. Wer wirklich keinen Rücken hat,
    trägt 0 mm ein (das geht ausdrücklich) oder gibt den Umschlag ohne Bogen
    aus. Dieselbe Trennung wie bei `Block.ohneGrund` und
    `sicherheitsabstandInnen`: zwei Fragen, zwei Felder.
  - **Einband, Papierstärke und die Tabellen lagen hinter demselben
    Schalter** und waren damit unerreichbar, sobald er aus war — obwohl sie
    allesamt die BREITE bestimmen. Sie stehen jetzt davor.
  - **Ein Knopf unter einem Zahlenfeld braucht immer zwei Tipps** („wobei
    auch diese Bestätigung etwas hakelig ist. Ich muss mehrmals drücken.").
    Das ist kein Gefühl, sondern iOS: Solange ein Textfeld den Fokus hat,
    beendet der erste Tipp daneben die Eingabe, erst der zweite erreicht den
    Knopf. `.onSubmit` hilft nicht — ein `.decimalPad` hat keine
    Eingabetaste. Übernommen wird deshalb beim Verlassen des Feldes
    (`@FocusState`), der Knopf bleibt für den daneben, der ihn sucht.
    **Gemerkt wird nur bei echter Änderung:** Der Rückgängig-Stapel ist
    flach (25 Stände), und ein zweimal angesehenes Feld darf ihn nicht
    leeren.
  - **Das Feld zeigt, WAS GILT.** Ohne Vorbelegung ließ sich beim Öffnen
    nicht unterscheiden, ob nichts eingetragen ist oder nur nichts dasteht.
    Und unter dem Bogenmaß steht seither „Davon Rücken" samt Herkunft —
    ohne diese Zeile war gar nicht zu sehen, ob eine eingetippte Zahl
    ankommt. Eine gerechnete Zahl als Angabe des Druckdienstes auszugeben
    wäre die Art Lüge, die diese App nicht erzählt.
- **Nicht gemessen (1.0.78):** Keine Seite ist damit gesehen und keine Datei
  ausgegeben worden. **Gerechnet und am Quelltext abgezählt sind BEIDE
  Ursachen** — dass die Doppelseitenansicht zwei Anschnitte und zwei
  Schnittkanten an den Bund legte (sie stand dort seit 1.0.17 und war seit
  1.0.69 im Widerspruch zur Ausgabe), und dass `rueckenZeigen` die einzige
  Stelle war, die die Rückenbreite auf null ziehen konnte (426 = 2 × 210 +
  2 × 3 geht auf den Millimeter auf). **Ungeprüft bleibt, ob der zweite
  Befund WIRKLICH daher kam:** Dass die Rechnung stimmt, heißt nicht, dass
  dieser Schalter in seinem Buch aus war — seit 1.0.78 nennt der Abschnitt
  deshalb Breite und Herkunft, und die nächste Rückmeldung sagt es mit
  Zahlen statt mit einer Vermutung. Ebenso ungesehen: ob die
  Doppelseitenansicht nach dem Wegfall der Bundanschnitte auf dem Gerät
  ruhig aussieht, ob der Zoom über die schmalere Bühne noch stimmt und ob
  die Übernahme beim Fokuswechsel wirklich einen Tipp spart. **Und ein
  vorhandenes Buch, in dem der Rücken abgeschaltet war, bekommt nach dem
  Update einen breiteren Umschlagbogen** — das ist die gewollte Richtung,
  aber es ist eine Änderung an einem fertigen Buch. **Nichts davon als
  erledigt darstellen.**
- **DER SATZSPIEGEL DARF BIS AN DEN SICHERHEITSABSTAND** (ab 1.0.82; gefragt
  09/2026: „Okay, den Satzspiegel hatte ich vergessen. Warum ist denn der so
  weit vom Rand entfernt? Der Satzspiegel könnte doch tatsächlich innerhalb
  des Sicherheitsabstandes ausgeführt werden."). **Er könnte, und er konnte
  nicht** — die drei Regler gingen nur bis 5 mm hinunter, der
  Sicherheitsabstand liegt bei 3. Die Untergrenze war eine gewählte Zahl ohne
  Grund; die technische Grenze ist der Sicherheitsabstand, und der steht seit
  1.0.80 als eigene blaue Linie daneben. Die Spanne ist jetzt `0...45`, dazu
  ein Knopf, der alle drei auf einmal darauf setzt (außen auf den größeren der
  beiden Werte, denn dort kann der Bund einen eigenen tragen).
  - **Die Vorgaben 16 / 17 / 19 sind GEWÄHLT und nicht gemessen** — übliche
    Buchränder, unten mehr als oben, weil der optische Mittelpunkt über dem
    geometrischen liegt. Das stand nirgends, und deshalb sah die Zahl aus wie
    eine Vorschrift. Der Fußtext des Abschnitts trennt jetzt beides: Der
    Sicherheitsabstand ist die technische Untergrenze, der Rand eine
    Entscheidung über das Aussehen.
  - **Wer eine Grenze freigibt, sucht alles, was sich bisher auf sie verlassen
    hat.** `Seitenbeiwerk` setzt Seitenzahl und Kopfzeile als ANTEIL der
    Ränder (0,6 bzw. 0,42). Solange die Ränder 16 bis 19 mm maßen, lag das von
    selbst weit genug innen; bei 3 mm Rand unten stünde die Seitenzahl 1,8 mm
    vom Papierrand und würde ANGESCHNITTEN. **Und es fiele niemandem auf:**
    Die rote Marke aus 1.0.81 greift dort nicht, denn Seitenzahl und Kopfzeile
    sind keine Blöcke — sie gehören dem Buch und werden beim Zeichnen ergänzt
    (Regel seit 1.0.0). Geklemmt wird deshalb in `Seitenbeiwerk` selbst, in die
    Schutzzone hinein und nicht über den Satzspiegel hinaus.
  - **Wird der Rand so knapp, dass zwischen Satzspiegel und Sicherheitslinie
    nichts mehr bleibt, SAGT es die Druckprüfung** (`beiwerkplatz`). Gemessen
    wird am ERGEBNIS: Überschneidet sich das gesetzte Rechteck mit dem
    Satzspiegel, steht die Zahl im Text. Angeschnitten wird sie nicht — aber
    sie liegt dann dort, wo der Fließtext anfängt, und das hat niemand
    eingestellt. Als Hinweis und nicht als Warnung: Es ist eine Folge der
    eigenen Einstellung und kein Druckfehler.
  - **Was der Rand sonst noch tut, steht dabei:** Beim Lesen liegt dort der
    Daumen, und am Bund verschwindet in der Bindung ohnehin ein Streifen —
    dafür gibt es seit 1.0.76 den eigenen Innenwert.
- **GEMESSEN WURDE DER RAHMEN, GESEHEN WIRD DER UMRISS** (`Block.umriss`,
  ab 1.0.83; gemeldet 09/2026: „Wenn ich jetzt ein Element in den
  Sicherheitsbereich hineinschiebe, erscheint noch kein roter Rand. Auch
  nicht, wenn ich ihn in den Beschnittbereich schiebe. Erst wenn er
  definitiv über den weißen Rand hinausragt, wird es rot. … Der Rahmen soll
  bereits rot erscheinen, wenn eine Ecke des Elementes in den
  Sicherheitsbereich hineinragt.").
  - **Die Prüfung stand seit 1.0.76 auf `block.rahmen.rect` — und der ist
    kleiner als das, was auf der Seite steht.** Zwei Gründe, beide am
    Quelltext abzuzählen und beide in die Richtung, um die es geht:
    **Der weiße Fotorand liegt AUSSERHALB des Rahmens** (`blockAnsicht`
    zeichnet ihn über `padding(randPt)`, dann `padding(-randPt)` — das
    Layoutmaß geht zurück, die Zeichnung bleibt groß); im Stil „Fotoalbum"
    sind das 2,6 mm ringsum. Und **die Drehung wurde gar nicht gerechnet**:
    In den lebhaften Stilen (Tagebuch, Fotoalbum, Postkarte) ist jede
    Kachel seit 1.0.36 um bis zu 2,1 Grad gedreht, und bei einem Block von
    300 Punkt Höhe steht seine ECKE gut 5 Punkt weiter draußen als seine
    Kante. Zusammen sind das mehrere Millimeter — genau der Betrag, um den
    die Marke zu spät kam. **Und die Ecke ist wörtlich das, wonach gefragt
    wurde.**
  - **Der SCHATTEN bleibt draußen.** Er liegt ebenfalls außerhalb des
    Rahmens, ist aber weich, hat keine Kante und ist kein Inhalt; ihn
    mitzumessen hieße, jeden Block mit Schatten zu markieren — und nach der
    dritten falschen Marke sieht niemand mehr hin. Dieselbe Abwägung wie
    bei den randabfallenden Blöcken, die ohne Ausnahme ausgenommen bleiben.
  - **Die Nachsicht von einem halben Punkt ist weg** (`Reise.randnachsicht`,
    ein Zehntelpunkt). Sie klingt nach nichts und ist an dieser Stelle zu
    viel: Gefangen wird beim Schieben mit `6 / massstab` Toleranz, und damit
    parkt ein Block regelmäßig GENAU auf einer Linie. Was dahinter noch als
    „nicht drin" galt, war ein Stück Sicherheitsabstand.
  - **Gemessen wird an EINER Stelle** (`Reise.ragtHinaus`), gefragt von der
    Schnittkanten- und der Sicherheitsprüfung, und damit von der Marke auf
    der Seite, der Zeile unter dem Blatt und der Druckprüfung. **Die Marke
    liegt seit 1.0.83 um denselben Umriss**, den sie prüft — eine Marke, die
    den weißen Fotorand ausließe, säße innerhalb dessen, was man sieht.
  - **Und weil sich das hier nicht nachmessen lässt, sagt es die App**
    (`SeitenflaecheView.randbefund`, in „Bedienung prüfen"): Für den
    gewählten Block stehen dort Rahmen, gerechneter Umriss, Drehung,
    Fotorand, Endformat, Schutzzone und das Urteil samt Grund —
    „randabfallend, wird nie markiert" ist eines davon. Dasselbe Muster wie
    Schulalarms Stufenprobe: **Wo sich eine Ursache nicht erschließen
    lässt, muss eine Probe entscheiden.**
- **AM BUND BRAUCHT NICHT JEDE DRUCKEREI EINEN ANSCHNITT**
  (`Gestaltung.anschnittAmBund`, `offeneKante(_:)`, ab 1.0.85; Ansage des
  Nutzers 09/2026 mit der Vorgabe seines Druckdienstes vor Augen: „Auch hier
  stimmt es wieder nicht, weil die App in der Mitte auch die 3 mm abzieht.
  Hier soll es aber nicht der Fall sein. Ich möchte also noch die
  Einstellmöglichkeit auf den Beschnitt an der Falz verzichten zu können.").
  - **Die Vorgabe rechnet es vor, und damit ist es keine Auslegung:**
    Bruttomaß 208 × 276 mm, Beschnittzugabe oben | unten | außen | innen =
    3 | 3 | 3 | 0, Nettomaß 205 × 270 mm. Waagerecht wird der Anschnitt genau
    EINMAL abgezogen (208 − 3 = 205), senkrecht zweimal. Die App zog ihn
    immer zweimal ab und zeigte 202 × 270 — drei Millimeter zu schmal.
  - **Die Sache war schon halb gebaut, und genau das ist der Befund.** Für
    die DOPPELSEITEN-Ausgabe gilt seit 1.0.69 „der Anschnitt liegt ringsum
    AUSSEN, am Bund keiner", für den Umschlagbogen seit 1.0.50, und die
    Doppelseitenansicht lässt ihn seit 1.0.78 über `Bogenkante` weg. Was
    fehlte, war der Fall, den dieser Dienst verlangt: EINZELSEITEN, die
    trotzdem am Bund nichts zuzugeben haben, weil die Druckerei sie selbst
    zusammenlegt. **Merke: Eine Regel, die für die eine Ausgabeart gilt, ist
    damit noch keine Einstellung — wer sie fest einbaut, kann sie für die
    andere nicht mehr abschalten.**
  - **Die Breite hängt nicht an der Seite, die LAGE schon.**
    `Gestaltung.bogen` rechnet waagerecht eine Zugabe statt zweier —
    dieselbe Zahl für jede Seite; WO das Endformat darin liegt, sagt
    `anschnittLinksPt(_:)`, und das wechselt mit `Buchseite.bundlage`.
    Deshalb wandern TrimBox und Verschiebung seit 1.0.85 IN die
    Seitenschleife: Eine feste TrimBox verschöbe die Hälfte aller Seiten um
    drei Millimeter, und zwar still — die Datei sieht tadellos aus, und erst
    das geschnittene Buch zeigt es.
  - **Aufgelöst wird an EINER Stelle** (`Gestaltung.offeneKante(_:)`),
    gefragt von der Ansicht, vom PDF und von der Druckprüfung. In der
    DOPPELSEITENansicht ist die Kante trotzdem immer offen, ganz gleich was
    eingestellt ist: Dort stoßen zwei Endformate aneinander, und das ist die
    Sache selbst und keine Einstellung. Die Entscheidung trifft deshalb der
    Aufrufer und nicht die Seitenfläche.
  - **Das Anschnittrechteck bleibt RINGSUM** (`Gestaltung.randabfallend`).
    Ein Bild darf am Bund über das Endformat hinauslaufen; die MediaBox
    beschneidet es. Ein Streifen zu viel deckt die Kante sicher ab, ein
    fehlender wäre der weiße Faden. **Was die Ansicht daran FÄNGT, ist eine
    andere Frage** — `SeitenflaecheView.fangbogen` lässt die offene Kante
    weg: Eine Kante, an der etwas einrastet, ohne dass man sie sieht, ist
    dieselbe Art stiller Widerspruch wie eine Linie ohne Wirkung (1.0.11).
  - **Der Schalter steht an ZWEI Stellen** — bei den Druckzugaben, wo der
    Anschnitt eingestellt wird, und unter „Maß der Druckerei", wo er die
    Umrechnung entscheidet. Dieselbe Einstellung, eine Quelle; wer die Zahl
    der Druckerei vor sich hat, soll die Regel daneben umlegen können, ohne
    den Bildschirm zu wechseln. Vorgabe bleibt AN: Jedes vorhandene Buch
    gibt danach dieselbe Datei aus wie vorher.
- **Nicht gemessen (1.0.85):** Keine Datei ist damit ausgegeben worden.
  **GERECHNET und an der Vorgabe des Druckdienstes nachgerechnet** ist die
  Umrechnung — 208 − 3 = 205 und 276 − 6 = 270 gehen auf das Nettomaß auf,
  das der Dienst selbst nennt. **Ungeprüft bleibt alles danach:** ob dieser
  Dienst die Datei so annimmt, ob eine TrimBox, die von Seite zu Seite die
  Kante wechselt, bei ihm durchgeht, und wie das Blatt auf dem Gerät
  aussieht, wenn die rote Schnittkante am Bund aufhört. **Nicht als erledigt
  darstellen.**
- **DER TITEL GEHÖRT AUF DIE TITELSEITE, DER NAME IN DIE ÜBERSICHT — UND DAS
  SIND ZWEI DINGE** (`Reise.regalname`, `Reise.anzeigename`, ab 1.0.84;
  Ansage des Nutzers 09/2026: „Da ich dieses Projekt noch bei einem anderen
  Druckdienst mit anderen Maßen in Auftrag geben möchte, habe ich jetzt eine
  Kopie des Fotobuches erstellen lassen. Dabei ist mir aufgefallen, dass der
  Titel des Buches versteckt in den Einstellungen zu den Rändern und der
  Druckausgabe steckt. … Was ich aber definitiv möchte, ist eine Trennung
  zwischen dem, was auf der Titelseite steht, und dem, wie ich das Projekt in
  der Übersichtsleiste der anderen Projekte benennen möchte.").
  - **Sein Fall lässt sich mit EINEM Feld gar nicht ausdrücken.** Zwei Bücher
    mit demselben Inhalt für zwei Druckdienste müssen im Regal zu
    unterscheiden sein — auf der Titelseite aber gerade nicht. **Und die App
    hat den Unterschied schon bezahlt, ohne ihn zu kennen:** `duplizieren`
    schrieb „ (Kopie)" in den gedruckten TITEL, ebenso das Einlesen einer
    Buchdatei als Kopie. Wer die Kopie nicht von Hand umbenannte, hatte das
    Wort auf der Titelseite stehen. **Merke: Wenn ein Name an zwei Orten
    auftaucht und einer davon gedruckt wird, sind es zwei Felder.**
  - **`nil` heißt „wie der Titel" — Abweichung, keine Kopie**, dieselbe Regel
    wie bei `Schriftabweichung`, `Block.wirkung` und `Kartenwahl`: Wer den
    Titel ändert, ändert den Namen im Regal mit, solange er nichts anderes
    gesagt hat, und jedes vorhandene Buch sieht nach dem Update unverändert
    aus. Ein LEERES Feld setzt `nil` und nicht einen leeren Namen — sonst
    hieße das Buch „nichts" und wäre nicht mehr davon loszukommen (dieselbe
    Trennung wie `Block.ohneGrund`).
  - **Aufgelöst wird an EINER Stelle** (`Reise.anzeigename`). Gefragt wird
    sie von allem, was eine DATEI benennt oder in einer Liste der App steht:
    Regal, Buchdatei, PDF-Dateiname und -Titel, Druckauftrag, die Befunde und
    die Überschrift der Bühne. `titel` bleibt, wo GESETZT wird: Titelseite,
    Buchrücken, Kopfzeile. Zwei Auflösungen nebeneinander liefen auseinander,
    und dann hieße dasselbe Buch im Regal anders als in seiner Datei.
  - **Der Dateiname und der PDF-Titel folgen dem PROJEKT, nicht dem Buch.**
    Beides ist dazu da, die Datei im Ordner und im Fenster des Betrachters
    wiederzufinden — zwei PDFs, die beide „Kanada 2026" heißen, sind genau
    der Fehler, um den es hier geht.
  - **Der Titel steht jetzt dort, wo er gedruckt wird** (Ganzes Buch → Titel,
    Umschlag und Rücken). Er lag unter „Ränder und Druckzugaben…", weil
    dieser Bildschirm bis 1.0.77 „Ränder, Karte, Seitenzahlen" hieß und der
    Ort für alles war, was sonst nirgends hinpasste. **Vierzehnte Auflage von
    „es war da, man fand es nicht"** — und die zweite, bei der nicht der Weg
    zu kurz, sondern die Zuordnung falsch war (nach dem Tagebuch-Stil in
    1.0.32). In der Gestaltung bleibt eine **Auskunft mit dem Weg** (Regel
    seit 1.0.27), und der Menüpunkt NENNT den Titel jetzt: Ein Menüpunkt, der
    nicht sagt, was dahinterliegt, kostete 1.0.79 schon einmal eine Funktion.
  - **Umbenannt wird auch im Regal** — lange tippen oder wischen. Wer vor der
    Liste steht, meint die Liste; der Alert sagt ausdrücklich, dass auf der
    Titelseite weiter der Titel steht. Ein offenes Buch wird dabei über sein
    `Reisewerk` geändert und nicht an ihm vorbei auf die Platte geschrieben —
    sonst überschriebe der nächste Sicherungslauf den neuen Namen gleich
    wieder.
- **Nicht gemessen (1.0.84):** Nichts davon ist auf einem Gerät gesehen
  worden. Am Quelltext ABGEZÄHLT ist, wo der Name gedruckt wird und wo er nur
  benennt — jede der Stellen ist einzeln durchgegangen. **Ob der Titel jetzt
  gefunden wird, sagt erst der nächste Befund:** Geändert sind Wege und Namen,
  und das ist keine Messung (dieselbe Einschränkung wie bei den Menüs in
  1.0.20, 1.0.49 und 1.0.77). **Nicht als erledigt darstellen.**
- **Nicht gemessen (1.0.83):** Keine Seite ist damit gesehen worden. **Am
  Quelltext ABGEZÄHLT sind die beiden blinden Flecken** (Fotorand außerhalb
  des Rahmens, Drehung ungerechnet) und die Größenordnung, um die sie die
  Marke nach außen schieben — sie passt zu dem, was gemeldet wurde.
  **Bewiesen ist damit nicht, dass es DIE Ursache war:** Es kann eine zweite
  darüberliegen, und in diesem Papier stehen genug Fälle, in denen die erste
  Erklärung eine Vermutung war. Genau deshalb nennt die Probe seit 1.0.83
  Zahlen statt einer Zusage — beim nächsten Mal sagt der Befund, ob die App
  den Block überhaupt für gefährdet hält oder ob es an der Zeichnung liegt.
  **Nicht als erledigt darstellen.**
- **Nicht gemessen (1.0.82):** Keine Seite ist damit gedruckt worden.
  Gerechnet ist die Geometrie (dass die Seitenzahl bei 3 mm Rand auf 1,8 mm an
  die Kante käme und dass das Klemmen sie in die Schutzzone holt). **Ob ein
  Buch mit 3 mm Rändern gut aussieht, ist keine Frage, die diese App
  beantwortet** — sie gibt die Einstellung frei und schreibt hin, was dabei zu
  bedenken ist. Ungeprüft bleibt auch, wie eng ein Druckdienst das nimmt:
  3 mm sind sein Mindestabstand für INHALT, und ob er einen Fließtext meint,
  der dort anfängt, sagt seine Vorgabe nicht. **Nicht als erledigt
  darstellen.**
- **EIN HANDBUCH IN DER APP — UND JEDER EINTRAG TRÄGT SEINEN WEG**
  (`Views/Handbuch.swift`, `Views/HandbuchView.swift`, ab 1.0.77; Ansage des
  Nutzers 09/2026: „Die Funktionen sind sehr mannigfaltig und zum Teil auch
  versteckt, so dass ich finde, dass das sinnvoll wäre.").
  - **Zwei Listen, zwei Fragen.** Die Bedienungskarte (seit 1.0.10) zählt
    die GESTEN auf — was man mit dem Finger tut, und das sieht man einer
    Seite nicht an. Das Handbuch zählt die FUNKTIONEN auf und sagt, WO sie
    stehen. Sie ersetzen einander nicht; das Fragezeichen unten führt
    seither ins Handbuch, und die Gestenkarte steht dort als erster
    Eintrag.
  - **Ein Handbuch ohne Weg ist die Frage von vorhin noch einmal.** Jeder
    Eintrag nennt den Menüpfad, und wo es ein Blatt dafür gibt, springt ein
    Knopf dorthin. Wo es keins gibt (Gesten, Knöpfe in der Leiste), steht
    nur der Weg — ein Knopf, der woanders landet, wäre schlechter als
    keiner.
  - **Der Sprung geht über den BLATTWUNSCH**, nicht über ein zweites Blatt:
    Das Handbuch macht sich zu, die Wurzel öffnet das Ziel im `onDismiss`
    (dieselbe Bauweise wie der geführte Weg seit 1.0.18). Dafür trägt
    `alsNaechstes` jetzt Ziel UND Rückkehr. Bis 1.0.76 wurde die Rückkehr
    ERSCHLOSSEN („alles außer dem Aufbau führt dorthin zurück"), und das
    trug nur, solange ein einziger Weg sprang. **Der Wunsch trägt das Ziel,
    kein Schalter daneben** (Regel seit 1.0.9).
  - **Die Suche ebnet Umlaute EIN — ausdrücklich gegen die Hausregel.**
    Die gilt dem Vergleich von NAMEN, wo eine falsche Gleichsetzung Schaden
    anrichtet (Kürzel in Schulalarm, Haltestellen in der Abfahrtstafel). In
    einer Volltextsuche ist es der umgekehrte Fall: Wer „Ruecken" tippt,
    sucht den Rücken, und ein Treffer zu viel kostet nichts. **Wer eine
    Regel umkehrt, schreibt den Grund dazu.**
  - **Ein eigenes Kapitel „Was die App nicht kann".** Kein CMYK, kein
    Textfluss um eine Form, keine eigenen Felder auf dem Buchrücken, die
    Karte zeichnet die Verbindung und nicht den Weg. Lieber eine Lücke als
    eine Zusage, die nicht hält — und was dort steht, ist nicht vergessen
    worden, sondern bewusst nicht gebaut.
- **EIN MENÜ MIT SECHZEHN EINTRÄGEN IST EIN VERSTECK** (ab 1.0.77). Das
  „…"-Menü ist der Ort, an dem dreimal etwas lag, das niemand fand
  (Broschüre 1.0.37, zwei Dateien 1.0.52, Druckprüfung 1.0.76) — und es trug
  seine Einträge ungegliedert hintereinander. Jetzt fünf Abschnitte, benannt
  nach dem, was man VORHAT: Vor dem Druck, Ausgeben, Das ganze Buch, Hilfen
  beim Anordnen, Hilfe und Prüfen.
- **WER EINEN MENÜPUNKT UMBENENNT, ZIEHT JEDEN VERWEIS MIT** (ab 1.0.77).
  „Ränder, Karte, Seitenzahlen…" heißt jetzt „Ränder und Druckzugaben…" —
  dahinter liegen Anschnitt, Sicherheitsabstand und Bundsteg, also alles,
  was eine Druckerei verlangt, und der Name nannte nichts davon. Der alte
  Name stand an ZWÖLF Stellen (Ausgabesteckbrief, Bedienungskarte,
  Handbuch), teils als Klartext und teils in `\u{00E4}`-Schreibweise — wer
  nur nach der einen Form sucht, lässt die andere stehen. Dabei fiel ein
  Weg auf, den es seit mehreren Fassungen nicht mehr gab („Buch → Format,
  Ränder, Karte" im Block-Inspektor). **Ein Weg, der auf einen Namen zeigt,
  den es nicht mehr gibt, ist schlimmer als kein Weg** (Lehre aus 1.0.49).
- **Nicht gemessen (1.0.77):** Nichts davon ist auf einem Gerät gesehen
  worden. **Und das Wichtigste lässt sich hier grundsätzlich nicht
  messen: Ob die Funktionen damit auffindbar SIND, sagt kein Handbuch,
  sondern der nächste Mensch, der die App zum ersten Mal öffnet.** Geändert
  sind Wege und Namen — dieselbe Einschränkung wie bei den Menüs in 1.0.20
  und 1.0.49. Die Wege im Handbuch sind gegen den Quelltext geprüft, nicht
  in der laufenden App abgeklickt.
- **AM BUND GILT EIN ANDERER SICHERHEITSABSTAND — UND WELCHE SEITE INNEN
  LIEGT, WECHSELT** (`Gestaltung.sicherheitsabstandInnen`, `Bundlage`,
  `Buchseite.bundlage`, ab 1.0.76; Ansage des Nutzers 09/2026: „Im
  vorliegenden Fall soll der 3 mm vom Rand betragen und 5 mm an der
  Innenseite dort, wo die Seite verklebt wird.").
  - **Es sind zwei Ursachen, also zwei Zahlen.** Außen entscheidet das
    Spiel der Schneidemaschine (so steht es seit 1.0.73 hier), innen
    verschwindet ein Streifen im Falz — bei einer Klebebindung mehr als bei
    einer Fadenheftung. **Oben und unten gilt immer der äußere Wert**: Dort
    wird geschnitten und nicht gebunden.
  - **`nil` heißt „wie außen" und ist keine Kopie** — dieselbe Regel wie bei
    `Schriftabweichung`, `Block.wirkung` und `Kartenwahl`. Jedes vorhandene
    Buch sieht nach dem Update unverändert aus, und wer später den äußeren
    Wert ändert, ändert den inneren mit.
  - **Die Bundseite wird HEREINGEREICHT, nicht geraten.** `Gestaltung` weiß
    nicht, welche Seite innen liegt — das hängt an der laufenden
    Seitenzahl. `Buchseite.bundlage` fragt dafür `liegtRechts`, also die
    eine Stelle, die es seit 1.0.47 ohnehin weiß; der AUSSENbogen des
    Umschlags hat keinen Bund (er wird umgelegt, nicht gebunden — dieselbe
    Überlegung, aus der `Umschlagmass.satzspiegel` den Bundsteg wieder
    herausrechnet).
  - **Der Unterschied zum BUNDSTEG ist kein Widerspruch.** Der geht seit
    1.0.1 auf BEIDE Seitenränder, gerade WEIL eine Seite beim Umbruch die
    Buchhälfte wechselt — er verschiebt den Satzspiegel, und ein Satz, der
    je nach Seitenzahl anders steht, wäre nicht zu setzen. Der
    Sicherheitsabstand verschiebt nichts, er PRÜFT nur — er darf die Seiten
    also unterscheiden.
  - **Beim Formatwechsel bleibt er draußen, beide Werte.** Was im Falz
    verschwindet, hängt an der Bindung und nicht am Papierformat.
- **DIE ZWEI GESTRICHELTEN LINIEN GAB ES — DER SCHALTER HIESS NACH EINER VON
  DREIEN** (ab 1.0.76). Rot gestrichelt ist die Schnittkante, orange der
  Sicherheitsabstand, blau der Satzspiegel; alle drei hängen an EINEM
  Schalter, und der hieß „Satzspiegel zeigen". Wer nach der Schnittlinie
  sucht, sucht nicht unter „Satzspiegel" — er heißt jetzt „Linien zeigen:
  Satzspiegel, Schnitt, Sicherheit". Dazu zeigt `Schutzzonenskizze` dort,
  wo die Zahlen eingestellt werden, **zwei gegenüberliegende Seiten** mit
  dem Bund in der Mitte — gezeichnet mit derselben Rechnung wie das Blatt
  daneben, denn eine zweite Fassung zeigte hier etwas anderes als dort.
- **EINE WARNUNG, DIE NUR IN EINEM BLATT STEHT, SIEHT NIEMAND**
  (`Reise.imSicherheitsabstand(_:)`, ab 1.0.76; Ansage des Nutzers 09/2026:
  „Dann möchte ich, dass die App sich bemerkbar macht, falls an irgendeiner
  Stelle einer dieser Sicherheitsabstände nicht berücksichtigt wurde.").
  Zwei Wege, und beide sind nötig: Auf der SEITE bekommt jeder betroffene
  Block einen orange gestrichelten Rahmen (in der Farbe der Linie, an der er
  zu nah steht) — das sieht aber nur, wer die Linien eingeschaltet hat;
  UNTER dem Blatt steht es in Worten und unabhängig davon. Die
  Beschriftungszeile war ohnehin da und behält ihre feste Höhe, denn
  `Zoomanker` rechnet mit ihr.
  **Geprüft wird an EINER Stelle**, gefragt von der Seite, der Bühne und der
  Druckprüfung: Drei Fassungen derselben Prüfung fänden irgendwann
  Verschiedenes, und dann meldete die eine, was die andere nicht zeigt.
  **Randabfallende Blöcke bleiben ausgenommen, ohne Ausnahme** — nach der
  dritten falschen Marke sieht niemand mehr hin.
- **DIE DRUCKPRÜFUNG LAG IM AUSGABEBLATT — ALSO HINTER DER ABSICHT,
  AUSZUGEBEN** (`Views/DruckpruefungView.swift`, ab 1.0.76; Ansage des
  Nutzers 09/2026: „Zu diesem Punkt meine ich mich zu erinnern, dass mir die
  App an irgendeiner Stelle bereits rückgemeldet hat, dass beispielsweise
  Text nicht ganz in ein Textfeld gepasst hat. Ich finde diesen Menüpunkt
  leider nicht mehr wieder.").
  **Er hat sie gesehen.** `Druckpruefung.vorab` läuft seit 1.0.1 und zählt
  `abgeschnittenerText` mit — sie stand aber ausschließlich im Ausgabeblatt,
  unter der halben Seite Einstellungen. **Zwölfte Auflage von „es war da,
  man fand es nicht"**, dieselbe Lehre wie bei der Broschüre (1.0.37), den
  zwei Dateien (1.0.52) und dem Ausgabeformat (1.0.75), und dieselbe
  Antwort: eigener Menüpunkt, nach der SACHE benannt, ganz oben.
  **Kein zweiter Prüfer** — dieselbe Funktion und dieselbe Zeile
  (`BefundZeile`), nur sortiert nach Dringlichkeit und kopierbar; das
  Ausgabeblatt behält seinen Abschnitt und nennt den zweiten Weg.
  **Merke: Eine Prüfung gehört nicht hinter die Handlung, für die sie
  prüft.**
- **`.inspector` IST EINE SPALTE UND NIMMT DER BÜHNE IHRE BREITE** (ab
  1.0.76; Befund des Nutzers 09/2026: „Sobald ich auf den Pinsel tippe,
  klappt rechts eine ganze Seite auf, die bewirkt, dass der
  Bearbeitungsbereich verkleinert wird. Das möchte ich nicht."). Auf einem
  iPad im Hochformat ist das ein knappes Drittel — und genau dort steht das
  Blatt, an dem gearbeitet wird. Der Inspektor hängt seither als **Popover**
  am Pinselknopf: Er deckt nur einen Teil ab und geht bei einem Tipp daneben
  wieder zu; auf dem iPhone macht SwiftUI daraus von selbst ein Blatt, wo
  ein Popover eine Briefmarke wäre. Zwei Dinge gehören dazu: ein Stapel
  darum, damit das Blatt einen sichtbaren Ausgang hat (Regel seit 1.0.9),
  und ein `onChange` auf das geöffnete Blatt — wer aus dem Inspektor heraus
  eines öffnet, bekommt sonst ein Blatt über einem Popover.
  **Der Grund, aus dem der Inspektor Blätter statt `NavigationLink`s
  benutzt, bleibt gültig** (1.0.29): Er bringt weiterhin keinen eigenen
  Stapel mit, den seine Unterseiten benutzen könnten.
- **Nicht gemessen (1.0.76):** Nichts davon ist auf einem Gerät gesehen
  worden. Gerechnet ist die Geometrie — dass die orange Linie auf einer
  rechten Seite links weiter innen läuft und auf einer linken rechts.
  **Ungeprüft bleibt, ob das Popover auf dem iPad an der gewünschten Stelle
  aufgeht** und ob sich die Blätter, die der Inspektor öffnet, darin
  verhalten wie in der Spalte; das ist die Lesart der Dokumentation und
  keine Messung. Die Zahlen 3 mm außen und 5 mm am Bund sind die der
  Druckerei — eingetragen, nicht nachgeprüft. **Nicht als erledigt
  darstellen.**
- **NACH DER DRITTEN DRUCKEREI WEISS NIEMAND MEHR, WAS GILT**
  (`Model/Ausgabesteckbrief.swift`, `Views/AusgabeformatView.swift`, ab
  1.0.75; Ansage des Nutzers 09/2026: „Bei einer anderen Druckerei wird bei
  den Tagebuchseiten auf der Innenseite kein Bundsteg gelassen. Das gipfelt
  jetzt in einer Fülle von Formaten. Vielleicht wäre es gut, sich innerhalb
  der App irgendwo anzeigen lassen zu können, wie denn jetzt das
  Ausgabeformat aussieht und wie die einzelnen Werte sind.").
  **Das ist der Befund aus 1.0.72, eine Ebene breiter.** Damals ging es um
  EINE Zahl, und sie war nie falsch — sie stand nur nirgends so da, dass man
  sie gegen eine Bestellung halten konnte. Jetzt sind es alle: Anschnitt,
  Sicherheitsabstand, Ränder, Bundsteg, Rückenbreite, Umschlagbogen,
  Bildgüte. Jede einzelne ist woanders einstellbar.
  - **Gerechnet wird NICHTS neu.** Jede Zahl kommt aus der Stelle, die sie
    auch beim Ausgeben liefert (`Gestaltung`, `Druckvorgabe`,
    `Umschlagmass`, `Bildguete`), und der Kopiertext entsteht aus DENSELBEN
    Abschnitten wie der Bildschirm. Zwei Fassungen nennten zwei Zahlen, und
    die Druckerei prüft eine — dieselbe Regel, aus der `Bogenlage` und
    `Umschlagmass` entstanden sind.
  - **Jede Zeile sagt, ob sie EINSTELLUNG oder FOLGE ist**, und wo man sie
    umstellt. Das ist kein Zierat: Das Endformat hat jemand gewählt, das
    Bogenmaß folgt. Wer das verwechselt, trägt das Bogenmaß als Format ein —
    genau die Falle, die `Druckvorgabe.bogenverdacht` abfängt.
  - **Der Bundsteg ist die Antwort auf die Frage, die die Fassung ausgelöst
    hat, und es war NICHTS zu ändern:** Die Vorgabe ist seit 1.0.1 null, und
    „innen kein Bundsteg" ist damit der stehende Zustand. Was fehlte, war der
    Satz, der es sagt. Steht doch einer, nennt die Zeile die zweite Hälfte
    dazu (auf BEIDE Seitenränder gerechnet, samt der Zahl, die der äußere
    Rand dann misst).
  - **Ein eigener Menüpunkt, keine Zeile in einem Picker** — die Lehre aus
    1.0.37 und 1.0.52, wo zweimal etwas vollständig Gebautes hinter einem
    zugeklappten Picker lag. Daneben führt ein Weg aus dem Ausgabeblatt
    hinein, mit der DORT gewählten Bildgüte; ohne Übergabe gilt
    `Bildguete.vorgabe`, und die Fußzeile schreibt hin, dass sie es tut.
  - **Gemeldet wird IM Blatt, nicht über `werk.meldung`.** Das Band hängt an
    `ReiseView`, und diese Ansicht liegt als Blatt darüber — die Quittung
    erschiene dahinter (dieselbe Lehre wie bei der Punktwahl in 1.0.52).
  - **`Ausgabeguete.satz` läuft über jedes Bild des Buches** und gehört
    deshalb in eine Aufgabe und nicht in den Körper; hereingereicht wird er
    als fertiger Text, damit `Ausgabesteckbrief.abschnitte` billig bleibt.
  - **Kein `uppercased()` auf einer deutschen Überschrift** im Kopiertext:
    Die Großschreibregel für ß ist SS, und daraus wird ein falsch
    geschriebenes Wort (die Lehre aus Wörterwerkstatt 1.7.1).
- **Nicht gemessen (1.0.75):** Diese Seite sagt, WAS ausgegeben wird, und
  nicht, was in der fertigen Datei steht — das misst weiterhin
  `Druckpruefung.amPDF`. Ob die Übersicht die Fülle der Formate
  beherrschbar macht, sagt erst der nächste Befund: Geändert sind Wege und
  Namen, und das ist keine Messung (dieselbe Einschränkung wie bei den Menüs
  in 1.0.20). **Nicht als erledigt darstellen.**
- **DIE INNENSEITEN DES UMSCHLAGS DÜRFEN INHALT TRAGEN — UND DANN WECHSELT
  JEDE SEITE DIE BUCHHÄLFTE** (`Umschlag.innenseitenInhalt`,
  `Buchteil.innenVorn`/`.innenHinten`, ab 1.0.74; Ansage des Nutzers
  09/2026: „Die von mir beauftragte Druckerei schafft es offenbar auch, die
  Innenseiten des Umschlages bereits zu bedrucken. Das heißt, ich könnte zwei
  Seiten insgesamt am Dokument sparen … Dadurch würden sich aber alle Seiten
  innerhalb des Dokumentes verschieben. Eine linke Seite würde zur rechten
  bzw. umgekehrt.").
  **Er hat die Folge selbst mitgenannt, und sie stimmt** — sie folgt aus der
  Buchbinderei: Die erste Inhaltsseite lag rechts (Seite 1 ist ein Recto),
  links davon die leere Innenseite des Deckels. Wandert sie auf U2, das
  LINKS liegt, rückt alles Folgende um eine Stelle vor; was gegenüberlag,
  liegt es nicht mehr.
  - **Nichts davon muss eigens gebaut werden.** Es fällt aus `seitenfolge`
    heraus, weil `nummer` erst bei der dritten Inhaltsseite bei 1 anfängt —
    und Paarung wie Hintergrundhälfte hängen seit 1.0.47 an
    `Buchseite.liegtRechts`, also an genau einer Stelle. **Das ist der
    Lohn dafür, dass die Seitenfolge gerechnet wird und nicht gespeichert:**
    Umlegen und Zurücknehmen kostet keinen Umbau am Satz, und die
    Doppelseitenansicht zeigt die neue Paarung sofort.
  - **Dass der Satzspiegel dabei stimmt, liegt am Bundsteg.** Er wird seit
    1.0.1 auf BEIDE Ränder gerechnet, mit genau dieser Begründung: „Welche
    Seite innen liegt, hängt an der laufenden Seitenzahl, und die
    verschiebt sich." Eine Fassung, die ihn nur innen rechnete, bräuchte
    hier einen Neusatz des ganzen Buches.
  - **`Buchseite.bogen` ist seit 1.0.74 GESPEICHERT, nicht gerechnet.** Bis
    1.0.73 folgte der Bogen allein aus der Seitennummer; eine
    Umschlaginnenseite trägt aber die Nummer 0 und liegt trotzdem auf einem
    Bogen des Buches (U2 neben Seite 1, U3 neben der letzten). Vergeben wird
    er dort, wo auch die Nummer vergeben wird — in `seitenfolge`, der einen
    Stelle für beides. Ohne das läge U2 auf Bogen 0 und damit neben der
    TITELSEITE.
  - **`blockseiten` zieht die zwei ab**, und das ist nicht Kosmetik: An
    dieser Zahl hängt die RÜCKENBREITE. Ein Rücken, der zwei Seiten zu dick
    gerechnet ist, passt nicht auf das gebundene Buch.
  - **`tag == nil` reicht als Umschlagprüfung NICHT mehr.** U2 und U3 tragen
    Inhalt und damit einen Tag — und gehören trotzdem auf den Umschlagbogen.
    Die Ausgabefilter fragen seither zusätzlich `amUmschlag`; ohne das
    stünden sie mitten im Innenteil, in einem Maß, das dort nicht gilt.
  - **Auf dem Innenbogen zeichnet jede Hälfte ihren EIGENEN Grund**
    (`ohneGrund: false`), anders als auf dem Außenbogen. Dort liegt ein
    Grund über den ganzen Bogen samt Rücken; hier trägt jede Hälfte eine
    Tagebuchseite, und die soll aussehen wie eine. Die Farbe für U2+U3 gilt
    damit nur noch, wenn die Innenseiten LEER bleiben — sie bleibt als Grund
    darunter stehen und trägt den Rücken.
  - **Erst ab vier Inhaltsseiten** (`Reise.umschlagTraegtInhalt`). Zwei
    abzuziehen ließe sonst kein Buch übrig, das sich binden lässt.
  - **Die Druckprüfung FRAGT die Folge, statt sie nachzubauen** (ab 1.0.74).
    `doppelseitenhintergrund` zählte die Seiten bis 1.0.73 selbst durch —
    eine zweite Zählung, und genau davor warnt der Fall von 1.0.52. Sie
    hätte hier jede Seite auf die falsche Hälfte gelegt und daraufhin lauter
    Bogen gemeldet, die „nicht aufgehen". Das Titelblatt muss dafür nicht
    gesetzt werden: Gebraucht werden Nummer, Lage und Hintergrund, und einen
    eigenen Hintergrund hat es nicht — eine leere `Seite()` genügt und kostet
    keine CoreText-Messung.
- **Nicht gemessen (1.0.74):** Keine Datei ist damit gedruckt worden.
  **Gerechnet und am Quelltext durchgezählt** ist die Paarung (U2 links neben
  Seite 1, U3 rechts neben der letzten; bei vier Blockseiten Bogen 1 = U2|1,
  Bogen 2 = 2|3, Bogen 3 = 4|U3). **Wie die Druckerei die beiden Bogen
  erwartet, ist seit 09/2026 BEANTWORTET: „Sie erwartet die Umschlagbogen in
  einer Datei."** Genau so gibt die App sie aus — eine Datei mit zwei Seiten,
  außen zuerst. **Die REIHENFOLGE darin ist damit nicht bestätigt**; sie folgt
  der Anschauung (umgeschlagen liegt außen zuerst) und keiner Ansage. Ebenso
  ungesehen: ob ein Hintergrundbild über die Doppelseite an der neuen
  Paarung aufgeht. **Ein Wasserzeichen über die Doppelseite gibt es nicht
  und gab es nie** — über die Doppelseite kann der HINTERGRUND laufen
  (`Seitenhintergrund.ueberDoppelseite`, seit 1.0.47); das Wasserzeichen
  liegt je Seite einzeln. **Nichts davon als erledigt darstellen.**
- **ANSCHNITT UND SICHERHEITSABSTAND SIND ZWEI STREIFEN IN ENTGEGENGESETZTE
  RICHTUNGEN** (`Gestaltung.sicherheitsabstand`, `.schutzzone`, ab 1.0.73;
  Befund des Nutzers 09/2026 an seinem ersten Druckauftrag: „wenn ich die von
  der Druckerei geforderten Werte mit dem Standardformat DIN A4 vergleiche,
  dann sind die Maße ja größer. Das heißt, die Druckerei erwartet von mir
  eine größere Seite, spricht aber auch von Beschnitt. Ich denke daher, dass
  es sinnvoll sein dürfte, einen Sicherheitsabstand zum Rand zu halten.").
  **Der Schluss ist richtig, die Begründung trifft daneben — und beides
  gehört gesagt.** Die SEITE wird nicht größer; sie bleibt A4. Größer ist die
  DATEI, weil der Anschnitt außen dranhängt und weggeschnitten wird. Wer den
  Satz „die erwarten eine größere Seite" zu Ende denkt, trägt 216 × 303 als
  Seitenformat ein — und genau das ist die Falle aus 1.0.72.
  - **Was den Abstand nötig macht, ist etwas anderes als der Anschnitt, und
    zwar dieselbe Ursache aus der anderen Richtung**: Jede Schneidemaschine
    hat ein Spiel von einem knappen Millimeter, und ein Stapel Bücher wird
    nie auf den Punkt genau getroffen. Der Anschnitt sorgt dafür, dass bei
    einem Schnitt NACH INNEN kein weißer Faden stehen bleibt; der
    Sicherheitsabstand dafür, dass bei einem Schnitt NACH AUSSEN nichts
    Gelesenes abgeschnitten wird. **Der Anschnitt liegt AUSSERHALB des
    Endformats, der Sicherheitsabstand INNERHALB.**
  - **Die App kannte ihn bis 1.0.72 gar nicht.** Die Ränder (16/17/19 mm)
    halten den Satzspiegel weit genug innen, und auch Seitenzahl und
    Kopfzeile sitzen sicher (`Seitenbeiwerk` rechnet mit Anteilen der
    Ränder). Ungeschützt war alles, was jemand VON HAND an die Kante
    geschoben hat — und seit 1.0.61 lassen sich Blöcke frei setzen.
  - **Gezeichnet wird ORANGE und feiner gestrichelt**, gleich neben der
    roten Schnittkante. Zwei rote Linien nebeneinander wären zwei Namen für
    dasselbe, und genau diese Verwechslung ist der Anlass der Fassung.
    **Nicht blau**: Das ist beim Einrasten seit jeher der NACHBAR, und
    dieselbe Farbe für zwei Auskünfte ist eine Auskunft weniger. Aufgefallen
    ist das erst am roten Bau — **wer eine Aufzählung erweitert, sucht jeden
    `switch` darüber** (`Views/Griffe.swift` war der einzige, und er hat
    zugleich die Farbkollision gezeigt).
    Abgeschaltet (0 mm) wird auch keine Linie gezeichnet und an nichts
    gefangen — eine Linie ohne Wirkung wäre eine Behauptung (die Regel steht
    seit 1.0.11 da).
  - **Er ist eine Fangkante wie die anderen** (`Einrasten.Herkunft.sicherheit`).
    Wer einen Block an die Kante schiebt, soll dort fangen und nicht daneben;
    die Linie beim Schieben nennt ihn beim Namen.
  - **Gezählt wird am ERGEBNIS, nicht an der Absicht**
    (`Druckpruefung.schutzzone`): jeder Block, der wirklich hineinragt, mit
    Tag und Seite, und Textblöcke eigens — Text ist der Fall, um den es geht.
    **Randabfallende Blöcke sind ohne Ausnahme ausgenommen.** Sie SOLLEN über
    die Kante laufen; sie zu melden hieße, das als Fehler auszugeben, was
    richtig ist — und nach dem dritten solchen Hinweis liest niemand mehr
    eine Zeile dieser Prüfung. Wer einen Block wirklich bis an die Kante
    will, schaltet ihn auf randabfallend; die Meldung sagt das auch.
  - **Beim Formatwechsel wird er NICHT mitgerechnet** — aus demselben Grund
    wie der Anschnitt: Das Spiel der Schneidemaschine ist dasselbe, ob eine
    Seite A4 misst oder A5. Wer ihn mitschrumpfte, bekäme auf der kleineren
    Seite genau dort weniger Schutz, wo der Rand ohnehin knapper wird.
    `Formatwechsel` zählt die Längen einzeln auf, also ist er von selbst
    draußen — der Kommentar dort sagt seit 1.0.73, dass das eine Entscheidung
    ist und kein Vergessen.
- **Nicht gemessen (1.0.73):** Keine Seite ist damit gedruckt worden.
  **Gewählt und nicht gemessen** sind die Vorgabe von 5 mm und die Spanne des
  Reglers (0 bis 12 mm); 3 bis 5 mm sind das, was Druckdienste üblicherweise
  nennen, und diese App hat es an keinem nachgeprüft. Ob der orange Strich auf
  einem Gerät neben dem roten zu unterscheiden ist, hat ebenfalls niemand
  gesehen. **Nicht als erledigt darstellen.**
- **WAS EINE DRUCKEREI NENNT, IST DER BOGEN — NICHT DIE SEITE**
  (`Model/Druckvorgabe.swift`, ab 1.0.72; gemeldet 09/2026 aus dem ERSTEN
  echten Druckauftrag: „Das Format der erhaltenen Daten stimmt nicht mit der
  Bestellung überein. Bitte legen Sie Ihre Daten im Format 216 mm x 303 mm
  an. Dieses beinhaltet das bestellte Endformat und die benötigte
  Beschnittzugabe.").
  **Nachgerechnet, und die App hatte recht:** 216 − 2 × 3 = 210,
  303 − 2 × 3 = 297. Verlangt wird **A4 hoch mit 3 mm Anschnitt**, und genau
  das gibt `Gestaltung.bogen` seit 1.0.1 aus. Ebenso der Umschlag:
  2 × 210 + 2 (Rücken) + 2 × 3 = **428 × 303**, Wort für Wort die zweite
  Forderung derselben Mail. **Die Zahlen waren nie falsch — sie standen nur
  nirgends so da, dass man sie gegen eine Bestellung halten konnte.**
  - **Die Falle, um die es geht:** Seit 1.0.52 lässt sich ein eigenes Maß
    als Format eintragen. Wer die Zahl der Druckerei DORT einträgt, bekommt
    eine PDF-Seite von 222 × 309 mm — Endformat plus ein zweites Mal
    Anschnitt —, und die Datei kommt wieder zurück. Schlimmer:
    `Formatwechsel` rechnet dabei jeden Block, jeden Rand und jede
    Schriftgröße des Buches um. **Ein Fehler, der wie eine Lösung aussieht.**
  - **Gefragt wird deshalb nach dem Maß der DRUCKEREI, nicht nach dem
    Endformat** (eigener Abschnitt im Formatblatt). Zwei Felder, darunter
    live das Endformat, das daraus folgt. Und wer doch unten tippt, bekommt
    den Hinweis: `Druckvorgabe.bogenverdacht` prüft, ob das eingetippte Maß
    nach Abzug des Anschnitts auf eine bekannte Vorlage fällt. **Eng gefasst
    mit Absicht** — ein Hinweis, der bei jedem zweiten Maß erscheint, wird
    nach dem dritten Mal überlesen —, und **ein Hinweis und keine Sperre**:
    Wer wirklich 216 × 303 als Endformat bestellt hat, soll es eintragen
    können.
  - **Das Bogenmaß steht jetzt dort, wo die Datei entsteht** (Ausgabeblatt,
    Zeile „Bogen im PDF"). Bis 1.0.71 stand dort nur das Endformat, also die
    Seite, wie sie geschnitten in der Hand liegt — geprüft wird aber die
    DATEI. Es folgt der gewählten Anordnung: Einzelseiten, Doppelseiten und
    Umschlag sind drei verschiedene Maße, und gerechnet wird über dieselben
    Stellen wie die Ausgabe. Zwei Fassungen nennten zwei Zahlen, und die
    Druckerei prüft eine.
  - **Die Rückenstärke lässt sich eintragen** (`Umschlag.rueckenbreiteVonHand`).
    Dieselbe Mail: „Dieses Format beinhaltet 2 mm Rückenstärke". Zwei
    Millimeter — eine Zahl, fertig; eintragen ließ sie sich bis 1.0.71 nur
    als Tabellenzeile („ab 0 Seiten: 2 mm"), also über einen Umweg, den
    niemand findet, wenn er eine einzelne Zahl vor sich hat. Sie schlägt
    Tabelle UND Rechnung, und `rueckenherkunft` sagt „von Hand eingetragen".
    Daneben die Gegenrichtung: Nennt die Druckerei nur die Bogenbreite,
    folgt die Rückenstärke daraus (`Druckvorgabe.rueckenAusBogen`) — Format
    und Anschnitt stehen ja fest.
  - **Passt die Bogenbreite gar nicht, ist das der wichtigere Befund.**
    Bleibt nach Abzug zweier Seiten und des Anschnitts nichts übrig, wird
    keine Rückenstärke geraten, sondern gesagt, dass das SEITENFORMAT nicht
    zu der Angabe passt.
  - **Die bestellte Seitenzahl ist eine Zahl, die nur der Mensch kennt**
    (`Reise.bestellteSeiten`, ab 1.0.72). Zweiter Punkt derselben Mail: „Sie
    haben ein Produkt mit 60 Innenseiten bestellt, uns allerdings zu viele
    Seiten für den Innenteil zugeschickt." Die App zählt die Seiten längst;
    was fehlte, ist die Zahl daneben. Eingetragen wird sie im Ausgabeblatt,
    geprüft wird sie dort und in der Druckprüfung — **vor dem Hochladen
    statt in der Antwortmail zwei Tage später**. Ohne eingetragene
    Bestellung wird NICHTS behauptet: Eine Warnung über eine Seitenzahl, die
    niemand bestellt hat, ist keine Auskunft.
  - **Die Innenseiten des Umschlags, U2 und U3** (`Umschlag.innenseitenBogen`,
    ab 1.0.72). Dritter Punkt derselben Mail: „Bitte legen Sie für die
    Aussenseiten (U4+U1) und die Innenseiten (U2+U3) des Umschlags jeweils
    eine Doppelseite im Format 428 mm x 303 mm an." Bis 1.0.71 gab es davon
    nur die Außenseite — die Doppelseitenansicht schreibt an die
    Innenseiten sogar „Kommt von der Druckerei — nicht im PDF", und für ein
    gebundenes Hardcover mit Vorsatzpapier stimmt das auch. **Diese
    Druckerei will sie geliefert bekommen**, und ohne sie nimmt sie den
    Auftrag nicht an. Die Umschlagdatei bekommt deshalb auf Wunsch eine
    ZWEITE Seite in denselben Maßen und mit denselben Boxen, NACH der
    Außenseite: Umgeschlagen liegt außen zuerst, und eine Datei, deren
    Reihenfolge man erklären muss, ist eine Fehlerquelle.
  - **Geliefert wird eine FLÄCHE, kein Satz** — eine Farbe, `nil` heißt
    Papier. Kein Rücken (der Rückentext gehört auf die Außenseite; ihn hier
    noch einmal zu setzen hieße, ihn im fertigen Buch zweimal zu haben,
    einmal davon unsichtbar zwischen Deckel und erster Seite) und **keine
    Blöcke**: Etwas anzubieten, das nach Gestaltung aussieht und keine
    trägt, wäre der schlechtere Anfang. Und bewusst nicht der Hintergrund
    des Umschlags — der ist meist ein Foto, und dasselbe Foto auf der
    Innenseite noch einmal ist keine Gestaltung, sondern ein Versehen, das
    erst im gebundenen Buch auffällt.
- **Nicht gemessen (1.0.72):** Keine Datei ist damit hochgeladen worden.
  **GERECHNET und an der Mail der Druckerei nachgerechnet** sind beide
  Maße — 216 × 303 für die Innenseiten, 428 × 303 für den Umschlag —, und
  sie gehen auf den Millimeter auf. **Ungeprüft bleibt, WARUM die erste
  Lieferung abgewiesen wurde**: Dass die Rechnung stimmt, heißt nicht, dass
  die Einstellungen dieses Buches stimmten; die wahrscheinlichsten
  Kandidaten sind A4 **quer** statt hoch (das war bis 1.0.26 die Vorgabe
  dieser App und steht in `init(from:)` bis heute als Rückfall), ein anderer
  Anschnitt und eine gerechnete Rückenstärke von rund 8 mm statt der
  verlangten 2. **Genau deshalb schreibt die App die Zahlen jetzt hin,
  statt sie zu behaupten** — die Zeile „Bogen im PDF" ist die, die sich
  gegen die Bestellung halten lässt. Ebenso ungeprüft: ob diese Druckerei
  die U2/U3-Fläche so annimmt und ob sie die beiden Umschlagbogen in EINER
  Datei erwartet oder in zweien — die Mail sagt dazu nichts. **Nichts davon
  als erledigt darstellen.**
- **EIN BUCH KOMMT ÜBER iCLOUD AN, BEVOR SEINE BILDER DA SIND**
  (`Dienste/Wolkenbilder.swift`, ab 1.0.71; gemeldet 09/2026: „Auf dem iPad
  ist kein Arbeiten möglich. Vielleicht liegt es daran, dass ich das Projekt
  insgesamt auf einem anderen Gerät erstellt und verarbeitet habe."). **Der
  Verdacht des Nutzers trifft, und die Stelle lässt sich am Quelltext
  abzählen — es sind zwei Fehler übereinander:**
  - **`Wolke.herunterladenAnstossen` sah nur die OBERSTE Ebene.** Es lief
    über `Reisen/` und stieß dort an, was nicht `.current` war — also die
    JSON-Dateien und die Ordner. Die Bilder liegen zwei Ebenen tiefer, in
    `Reisen/<Kennung>/Bilder/`; **nach keiner einzigen Bilddatei wurde je
    gefragt.** Ein Buch vom anderen Gerät ist damit binnen Sekunden lesbar
    (die JSON-Datei ist klein) und hat trotzdem keines seiner zweihundert
    Bilder. Angestoßen wird jetzt für das OFFENE Buch, nicht für alle: Fünf
    Bücher zu je zweihundert Bildern auf einmal sind genau der Schwall, dem
    iCloud Drive aus dem Weg gehen soll — und genau deshalb steht es dort
    und nicht im alten Lauf.
  - **Ein Bild, das nicht da war, wurde bei JEDEM Bildpunkt neu gesucht.**
    `Bildarchiv.vorschau` gab `nil` zurück, und ein `nil` wurde nirgends
    gemerkt — der Vorrat hält nur Treffer. Aufgerufen wird es aber im KÖRPER
    einer SwiftUI-Ansicht, also bei jeder Neuzeichnung der Bühne, und die
    läuft beim Schieben und Zoomen im Sekundentakt und öfter. Bei einem
    Buch, dessen Bilder in der Wolke liegen, war das je Seite und Bildpunkt
    ein vergeblicher Griff auf das Dateisystem, auf dem HAUPTFADEN. **Das
    ist die Form, in der sich „kein Arbeiten möglich" erklärt: Nicht eine
    Rechnung ist zu teuer, sondern dieselbe vergebliche Suche läuft
    hundertfach.**
  - **Der Fehlgriff wird mit seiner ZEIT gemerkt, nicht bloß weggeworfen**
    (`Bildarchiv.fehlgriffe`, `wartezeit` 3 s). Ein Merker ohne Ablauf wäre
    der bequemere Weg und der falsche — er zeigte ein heruntergeladenes Bild
    erst nach einem Neustart. So steht ein ankommendes Bild von selbst
    binnen drei Sekunden auf der Seite, und „Jetzt holen" räumt den Merker
    sofort weg: Ein Knopf, der nichts tut, weil eine Sperre noch läuft, ist
    für den Menschen davor ein kaputter Knopf.
  - **„Liegt noch in iCloud" und „ist weg" sind NICHT dasselbe.** Das eine
    löst sich von selbst, das andere nie; beides als graue Fläche zu zeigen
    lässt den Menschen davor raten — dieselbe Regel wie beim Wort „Plan" in
    der Abfahrtstafel. Das Band über der Bühne zählt beides getrennt, rot
    nur für das, was wirklich fehlt.
  - **Wie ein nicht heruntergeladenes Bild AUSSIEHT, ist von hier aus nicht
    zu messen** — geprüft werden deshalb BEIDE bekannten Gestalten: der
    Platzhalter `.<Name>.icloud` und `isUbiquitousItem` am Namen selbst. Nur
    eine zu fragen hieße, sich auf eine Darstellung zu verlassen, die Apple
    zwischen zwei Fassungen ändern darf; der Preis wäre, dass ein Bild, das
    gleich ankommt, als „fehlt ganz" gemeldet würde.
  - **Das Nachsehen läuft abseits des Hauptfadens und hört von selbst auf.**
    Zweihundert Abfragen an das Dateisystem, über iCloud jede mit Wartezeit;
    zurück kommt nur die Zahl. Wiederholt wird, solange etwas LÄDT — ein
    Band, dessen Zahl nicht kleiner wird, sieht aus wie ein Fehler, und ein
    Lauf, der ewig weiterzählt, ist einer.
  - **Die WASSERZEICHEN gehören dazu** (`Wolkenbilder.dateien`). Sie stehen
    in keiner Fotoliste und liegen im selben Ordner — wer sie vergisst,
    stößt sie nie an, und eines liegt auf JEDER Seite. Dieselbe Überlegung
    wie in `Buchdatei.schreiben`. **Wer eine neue Bildart anlegt, trägt sie
    dort ein.**
- **Nicht gemessen (1.0.71):** Auf einem Gerät gesehen hat das niemand.
  **Am Quelltext ABGEZÄHLT ist die Ursache**, und sie passt zu dem, was der
  Nutzer beschreibt. **Dass das iPad danach flüssig ist, folgt daraus
  NICHT**: Es kann eine zweite Ursache darüberliegen — bei der fehlenden
  Umschlagabbildung in 1.0.67/1.0.68 war genau das der Fall, und die
  sichtbare war die harmlosere. Weiterhin ungemessen sind die beiden
  offenen Punkte, die schon dastanden: dass `Bildarchiv.vorschau` auch bei
  vorhandenen Bildern SYNCHRON auf dem Hauptfaden liest (offen seit 1.0.59)
  und dass die Bühne seit 1.0.28 das GANZE Buch trägt. **Genau deshalb nennt
  der Befund unter „Bedienung prüfen" seit 1.0.71 vier Zahlen statt einer
  Zusage** — gesamt, auf dem Gerät, in iCloud, fehlen, dazu wie viele Namen
  gerade als nicht lesbar gemerkt sind. **Nicht als erledigt darstellen** —
  der nächste Befund des Nutzers ist hier die Messung.
- **ZWEI BUCHSEITEN AUF EINE PDF-SEITE, LINKS DIE GERADE**
  (`Buchausgabe.doppelseitenPdf`, ab 1.0.69; Ansage des Nutzers 09/2026:
  „Offenbar will Saal Digital ein Upload eines PDF mit fertig gestalteten
  Doppelseiten. … dass nun immer zwei Seiten, angefangen mit einer geraden
  Seite, zusammen auf ein PDF-Seite gebracht werden, die dann die doppelte
  Breite hat. Also wenn eine Seite hochkant 21 mal 28 cm wäre, müsste die
  Doppelseite 42 x 28 cm sein.“).
  - **Die Paarung wird NICHT nachgebaut.** Links die gerade Nummer, rechts die
    ungerade — das ist dieselbe Buchbinderei, die seit 1.0.47 in `Bogenlage`
    steht und nach der die Doppelseitenansicht auf dem Bildschirm paart.
    Gefragt werden genau die beiden Angaben, die je eine Stelle haben:
    `Buchseite.bogennummer` und `Buchseite.liegtRechts`. Eine zweite Zählung
    daneben ergäbe eine Datei, die anders paart als die Vorschau — und das
    sähe man erst im gebundenen Buch (dieselbe Lehre wie 1.0.52, wo drei
    Stellen die Nummerierung nachbauten).
  - **Der erste und der letzte Bogen sind HALB, und das ist richtig so.**
    Seite 1 ist ein Recto und hat links von sich die Innenseite des Umschlags;
    die kommt von der Druckerei und steht in keinem PDF. Ausgegeben werden sie
    trotzdem, sonst fehlten Seite 1 und die letzte. **Die leere Hälfte wird
    GEZÄHLT und hingeschrieben** (`doppelseitenbefund`): Ein halber Bogen sieht
    wie ein Fehler aus, wenn niemand ihn benennt.
  - **Der Anschnitt liegt ringsum AUSSEN, am Bund keiner.** Dort stoßen die
    beiden Hälften aneinander; ein randabfallendes Bild liefe sonst über die
    Nachbarseite. Dieselbe Rechnung wie beim Umschlagbogen — und deshalb
    dieselbe Funktion: `zeichneUmschlagseite` heißt seit 1.0.69
    `zeichneBogenhaelfte` und nimmt `ohneGrund` entgegen. Der Unterschied ist
    keine Einstellung, sondern die Sache: Der UMSCHLAG hat EINEN Grund über den
    ganzen Bogen (samt Rücken), eine DOPPELSEITE besteht aus zwei Buchseiten mit
    je eigenem Hintergrund — und läuft eines über beide, rechnet
    `Bogenlage.bildflaeche` in jeder Hälfte ihre Portion aus.
  - **TrimBox über den GANZEN Bogen**, nicht je Hälfte: Geschnitten wird außen,
    in der Mitte wird gebunden. Eine Schnittmarke am Bund wäre die Anweisung,
    das Buch in der Mitte zu zerteilen — dieselbe Überlegung wie beim Umschlag
    (1.0.50) und bei der Broschüre (1.0.27).
  - **Nur der Buchblock** (`teil == .innen`). Der Umschlag ist ein eigenes Stück
    Papier mit eigener Breite und eigenem Rücken und wird mit „Nur den
    Umschlag“ einzeln ausgegeben. Gibt es keinen Umschlagbogen, ist die
    Titelseite die gewöhnliche Seite 1 und damit von selbst dabei.
  - **Eigener Menüpunkt „Doppelseiten ausgeben…“**, nicht nur eine Zeile im
    Picker — der Picker im Ausgabeblatt ist der Ort, an dem in 1.0.52 zehn
    Fassungen lang etwas stand, das niemand fand.
  - **Nicht gemessen (1.0.69):** Keine Datei ist damit hochgeladen worden.
    Gerechnet ist die Geometrie (zwei Endformate nebeneinander, Anschnitt nur
    außen) und die Paarung; **ob Saal Digital genau diese Anordnung erwartet,
    ist NICHT geprüft** — gebaut ist, was der Nutzer beschrieben hat (links die
    gerade Zahl), und die Befundzeile nennt Zahl und Maß der Bogen, damit sich
    das gegen die Vorgabe des Dienstes halten lässt. **Nicht als erledigt
    darstellen.**
- **OHNE `UIGraphicsPushContext` ZEICHNET `UIImage.draw` IN NICHTS — STILL**
  (`Seitensatz.mitUIKit`, ab 1.0.68; derselbe Befund zum zweiten Mal gemeldet,
  09/2026: „Das Bild ist leider wieder nicht mitgekommen.“, dazu ein
  Bildschirmfoto mit weißem Bogen, Titel und Rückentext). **Das ist die
  wirkliche Ursache, und 1.0.67 hat sie nicht berührt.**
  - **`UIImage.draw(in:)`, `UIBezierPath.fill()`, `.stroke()` und `.addClip()`
    fragen NICHT den `CGContext`, den man ihnen daneben hinstellt.** Sie
    zeichnen in den Kontext, der oben auf UIKits eigenem Stapel liegt
    (`UIGraphicsGetCurrentContext`). Liegt dort keiner, tun sie schlicht
    NICHTS — kein Fehler, keine Warnung, kein Absturz.
  - **`umschlagPdf` war der einzige der drei Ausgabewege ohne
    `UIGraphicsPushContext`.** Die Seiten-PDF hatte es seit jeher, die
    Broschüre auch; der Umschlagbogen schiebt seinen eigenen Zeichenblock und
    bekam es beim Bau in 1.0.50 nie. Damit fehlten dort ALLE Bilder:
    Hintergrundfoto, Fotoblöcke, Karten, Wasserzeichen — und zusätzlich jede
    gerundete Fläche und jeder Schatten (`UIBezierPath.fill`). Was ankam, waren
    Text (CoreText zeichnet direkt in den `CGContext`) und Farbflächen
    (`CGContext.fill`). Genau dieses Muster zeigt das Bildschirmfoto.
  - **Das Pushen gehört DORTHIN, wo UIKit zeichnet, nicht an die
    Aufrufstelle.** An drei Aufrufstellen gepflegt, fehlte es an der vierten,
    und aufgefallen ist es erst an der ausgegebenen Datei. Seit 1.0.68 steht es
    in `Seitensatz.mitUIKit`, und die sechs betroffenen Funktionen legen ihren
    Zeichenteil hinein (`zeichneBild`, `zeichneSchatten`, `zeichneFlaeche`,
    `zeichneHintergrund`, `zeichneWasserzeichen`, `zeichneRahmen`). Die beiden
    Paare in `Buchausgabe` sind dafür ersatzlos raus — zwei Stellen für
    dieselbe Sache wären wieder eine, die jemand vergisst. Der Stapel ist
    schachtelbar; dass der Bildschirm (in `draw(_:)` einer `UIView`) denselben
    Kontext ein zweites Mal pusht, ist harmlos.
  - **Eine Ursache, die sich am Quelltext abzählen lässt, ist damit noch nicht
    DIE Ursache.** 1.0.67 hat das Übermalen des Bogengrundes durch die beiden
    Hälften abgestellt — richtig, nachgerechnet und wirkungslos: Das Bild wurde
    nie gezeichnet. **Hier lagen zwei Fehler übereinander, und der sichtbare war
    der harmlosere.** Wer den ersten findet, prüft, ob er den BEFUND erklärt,
    und nicht nur, ob er ein Fehler ist.
- **Was in der Datei steht, wird GEZÄHLT** (`Druckpruefung.bilderImPdf`, ab
  1.0.68). Seitenzahl und Maße konnten „ein Panorama“ und „weißes Papier mit
  einer Zeile Text“ nicht unterscheiden — beide Meldungen betrafen eine Datei,
  die von außen tadellos aussah, und die Prüfung sagte zweimal „geschrieben und
  lesbar“. Gezählt werden jetzt die Bild-XObjects der Seiten; null davon steht
  als Warnung da, mit dem Zusatz, dass es bei einem reinen Textbogen richtig
  ist. **Ein Bild in einem Form-XObject sähe die Zählung nicht** — diese App
  legt keines an, und das steht dort, statt es zu verschweigen.
- **Nicht gemessen (1.0.68):** Keine Datei ist damit ausgegeben worden.
  Am Quelltext ABGEZÄHLT ist die Ursache (der eine fehlende Push, und dass
  genau die UIKit-Aufrufe betroffen sind, deren Ausfall das Bildschirmfoto
  zeigt) — gesehen hat es niemand. **Ungeprüft ist auch die neue Zählung
  selbst**: ob `CGPDFDictionaryApplyFunction` in diesem Aufbau die XObjects
  wirklich findet, sagt erst die Zeile am Gerät. **Nicht als erledigt
  darstellen** — nach zwei Fassungen an derselben Meldung ist der nächste
  Befund des Nutzers hier die Messung, und seit 1.0.68 nennt er eine Zahl.
- **DER UMSCHLAGGRUND WURDE GEZEICHNET UND DANACH ZWEIMAL ÜBERMALT**
  (`Buchausgabe.zeichneSeite(…ohneGrund:)`, ab 1.0.67; gemeldet 09/2026:
  „Der Export hat leider beim Umschlag PDF nicht das Bild mitgenommen.").
  **Am Quelltext abzuzählen und keine Vermutung:** `umschlagPdf` legt seit
  1.0.50 den Grund über den GANZEN Bogen — und rief danach für jede Hälfte
  `zeichneSeite`, die ihren Seitengrund BEDINGUNGSLOS noch einmal zeichnete,
  diesmal in die halbe Fläche. Ein einfarbiger Seitengrund übermalte das
  Bogenbild damit vollständig (stehen blieb nur der Streifen im Rücken, der
  danach gezeichnet wird), ein Fotogrund wurde ZWEIMAL eingepasst — mit
  einem Zoom und einem Versatz, die für den Bogen gerechnet wurden und auf
  einer halben Fläche etwas ganz anderes treffen.
  - **1.0.63 hat den Bildschirm gerichtet und das PDF stehen lassen.** Dort
    heißt es seither „Der Umschlag hatte zwei Fassungen, und sie zeigten
    Verschiedenes"; die Hälften lassen ihren Grund über
    `SeitenflaecheView.ohneGrund` weg. Dieselbe Zeile fehlte im PDF.
    **Wer eine Doppelung auflöst, sucht nach jeder Stelle, die sie hat** —
    hier waren es zwei, und nur eine wurde behoben.
  - **Geprüft wird VOR dem Laden.** Ein Hintergrundfoto wird in voller
    Ausgabegüte von der Platte geholt; für eine Umschlaghälfte wäre das ein
    ganzes Bild umsonst.
  - **Und weil die Ursache gerechnet und nicht gesehen ist, MISST die App**
    (`Druckpruefung.umschlaggrund`, Zeile „Grund des Umschlags" vor dem
    Ausgeben): welcher Grund gilt (Umschlag oder Buch), welche Datei
    dahintersteht, ob sie sich überhaupt öffnen lässt, dazu Ausschnitt und
    Schleier. Eine zweite Ursache lässt sich von hier aus nicht
    ausschließen — dasselbe Muster wie Schulalarms Stufenprobe.
- **NUR DER UMSCHLAG, NUR DER INNENTEIL** (`Umfang.nurUmschlag`,
  `.nurInnenteil`, ab 1.0.67; Ansage des Nutzers 09/2026: „damit ich jetzt
  nicht wieder beide Teile exportieren muss, denn das PDF für das
  eigentliche Buch ist mittlerweile knapp 4 GB groß"). Ein Umschlagbogen ist
  in Sekunden gesetzt, der Innenteil eines vollen Buches wiegt Gigabyte und
  braucht seine Zeit. **Gebaut wird dafür KEIN zweiter Weg:** Es sind
  dieselben zwei Aufträge, die `getrennt` nacheinander stellt — hier einzeln.
  Dazu ein eigener Menüpunkt „Nur den Umschlag…" neben „Umschlag und
  Innenteil getrennt…": Der Picker im Blatt ist genau der Ort, an dem in
  1.0.52 zehn Fassungen lang etwas stand, das niemand fand.
- **DER TITEL LÄSST SICH VERSCHIEBEN — mit einem Regler und nicht mit dem
  Finger** (`Umschlag.titellage`, ab 1.0.67; gemeldet 09/2026: „Die Schrift
  auf der Titelseite ragt ziemlich tief in den dunklen Bereich des Bildes …
  Ich würde sie gerne auf der Seite verschieben, erkenne aber nicht, wie das
  gehen könnte."). Er hat es nicht gefunden, weil es das nicht gab:
  Titelseite und Rückseite werden bei jedem Durchgang GERECHNET, und ein
  dort hineingeschobener Block wäre beim nächsten Durchgang weg — das steht
  seit 1.0.50 hier. Verschoben wird deshalb nicht der Block, sondern die
  RECHNUNG: ein Anteil in der Höhe des Satzspiegels (0 = oben, 1 = unten),
  Regler unter Umschlag → „Gestaltung des Umschlags".
  - **`nil` heißt „wie gerechnet" und ist etwas anderes als 0,5.** Die
    schlichte Titelseite setzt den Titel in die MITTE, die mit Titelfoto ein
    Feld UNTEN; ein fester Vorgabewert hätte eine der beiden beim Update
    still verschoben. Dieselbe Regel wie bei `Schriftabweichung` und
    `Block.wirkung` — eine Abweichung ist keine Kopie. Aufgelöst wird sie an
    EINER Stelle (`geltendeTitellage(mitTitelfoto:)`), gefragt vom
    Layoutautomaten UND vom Regler: Zwei Fassungen ergäben einen Regler, der
    etwas anderes anzeigt, als die Seite tut.
  - **Nur senkrecht.** Waagerecht nimmt der Titel ohnehin die ganze
    Satzbreite ein (schlicht) bzw. steht in einem Feld am linken Rand — dort
    gibt es nichts zu verschieben, was nicht die Breite wäre. Das sagt die
    Fußzeile auch, statt einen Regler anzubieten, der nichts tut.
- **Nicht gemessen (1.0.67):** Kein Umschlag ist damit ausgegeben worden.
  Gerechnet und am Quelltext abgezählt ist die URSACHE des fehlenden
  Bildes — dass die Hälften den Bogengrund übermalten — und die Geometrie
  der Titellage (bei Anteil 0,5 bzw. 1 steht auf den Punkt dieselbe Zeile
  wie bis 1.0.66). **Ungeprüft bleibt, ob das der gemeldete Fehler WAR:**
  Eine zweite Ursache lässt sich von hier aus nicht ausschließen, und genau
  deshalb nennt die neue Befundzeile Zahlen statt einer Zusage. **Nicht als
  erledigt darstellen** — der nächste Umschlag-Export des Nutzers ist hier
  die Messung.
- **DAS SCHRIFTENRECHT STEHT WIEDER IN DER ENTITLEMENTS-DATEI — DIESMAL
  GEMESSEN** (`Config/Urlaubstagebuch.entitlements`, ab 1.0.66; Befund des
  Nutzers aus „Schriften prüfen", 23.09.2026). Die Probe aus 1.0.45 hat
  geliefert, wofür sie gebaut war: Profil „iOS Team Provisioning Profile:
  de.familie.urlaubstagebuch", elf bewilligte Rechte, darunter
  **`com.apple.developer.user-fonts` als `["app-usage",
  "system-installation"]`**. Genau diese Zeichenkette steht jetzt dort, Wort
  für Wort.
  - **`app-usage` ist der Wert hinter Xcodes Haken „Use Installed Fonts"** —
    also der, den 1.0.44 mit `system-installed-fonts` zu erraten versuchte
    und an dem das ganze Projekt unsignierbar wurde. Die Regel von damals
    („wer eine Zeichenkette in eine Entitlements-Datei schreibt, die er nicht
    nachschlagen kann, rät") hat also nicht bloß Schaden verhütet, sie hat
    die richtige Antwort geliefert — nur eben von einem Gerät und nicht von
    hier.
  - **`system-installation` steht mit drin, obwohl die App es nicht
    braucht.** Sie installiert keine Schriften. Eine TEILMENGE der
    bewilligten Werte ist aber nicht gemessen, und der Fehlertext von 1.0.44
    sprach ausdrücklich vom „value" des Rechts. Hier wird nicht zum zweiten
    Mal geraten, auch nicht in die vorsichtige Richtung. **Wer es enger
    haben will, nimmt in Xcode die Fähigkeit weg und meldet, was das Profil
    danach sagt.**
  - **NUR in die iOS-Datei.** `Config/Urlaubstagebuch-Mac.entitlements` ist
    unangetastet: Der Mac-Bau hat ein eigenes Profil, und ein Recht, das
    dieses nicht trägt, macht genau dort dasselbe kaputt wie 1.0.44 auf iOS.
  - **NICHT GEMESSEN — und das ist die wichtigere Hälfte des Befundes.** Im
    selben Bericht meldete `CTFontManagerCopyRegisteredFontDescriptors`
    **null** Einträge, und jede Anmeldung endete mit „Die
    Schriftregistrierung ist fehlgeschlagen." Der Eintrag ins Repo ist der
    belegte erste Schritt, kein Beweis; ob die Abfrage danach etwas hergibt,
    sagt erst der nächste Befund. Und ein grüner Bau in GitHub Actions sagt
    dazu gar nichts (`CODE_SIGNING_ALLOWED=NO`).
- **DER WÄHLER IST EIN EIGENER PROZESS — deshalb geht er, während die
  Abfrage leer bleibt** (ab 1.0.66). Derselbe Befund enthielt einen
  scheinbaren Widerspruch: null gemeldete Einträge, aber drei über den
  Wähler gewählte Schriften (Quicksand Regular, Quicksand Medium, Poppins
  Regular), alle drei **auffindbar**. `UIFontPickerViewController` läuft
  außerhalb der App — wie der Fotowähler, und aus demselben Grund darf er
  ohne Erlaubnis arbeiten. Was er zeigt, sagt über das, was DIESER Prozess
  aufzählen darf, nichts. **Merke: Ein Befund über den einen Weg ist kein
  Befund über den anderen** — 1.0.44 hatte genau daraus („im Wähler fehlen
  sie") auf das Recht geschlossen, und das war damals richtig; als Regel
  wäre es falsch.
- **WAS EIN FEHLER HEISST, STEHT IN SEINER ZAHL** (`Geraeteschriften.fehlernamen`,
  ab 1.0.66). Neunmal derselbe Satz im Protokoll — „Die Schriftregistrierung
  ist fehlgeschlagen" —, und dieselben Schriften danach auffindbar. Das ist
  der allgemeine Text von CoreText und sagt über die Ursache nichts;
  wahrscheinlich heißt er „steht schon" (Code 105). Gemeldet werden seither
  Domäne, Code und, wo die Zahl bekannt ist, ihr Name; was nicht in der
  Tabelle steht, bleibt eine nackte Zahl und wird nicht gedeutet. Dieselbe
  Regel wie bei Schulalarms `rohAbfrage`: **Ein aufgeräumter Satz ist für
  die Person, die es richten muss, weniger wert als der rohe Befund.** Die
  Tabelle nennt Zahlen und keine `CTFontManagerError`-Fälle — die Zahlen
  stehen in Apples Papier, die Swift-Namen sind schon gewandert.
- **Eine Probe, die nach dem Messen dieselbe Vermutung wiederholt, ist die
  Frage von vorhin noch einmal** (ab 1.0.66). Bis 1.0.65 sagte der Befund
  bei leerer Liste immer „Erster Verdacht: das Recht" — auch dann, wenn die
  Zeile zwei Absätze darüber es als bewilligt auswies. Jetzt hängt der Satz
  davon ab: bewilligt → der nächste Verdacht ist, ob diese FASSUNG es
  verlangt; nicht bewilligt → es liegt an der App-Id; kein Profil lesbar →
  es lässt sich nichts sagen. Dasselbe in der Schriftwahl (drei Fälle statt
  zwei) und im Protokoll, wo „Nichts anzumelden" jetzt dazusagt, ob es der
  gute Fall war (alles schon auffindbar) oder der leere.
- **AUSSCHNEIDEN, KOPIEREN, EINFÜGEN — WEIL DAS MENÜ DIE ZIELSEITE NICHT
  AUFZÄHLEN KANN** (`Reisewerk.Ablageinhalt`, `blockAusschneiden`,
  `blockInDieAblage`, `einfuegenGrund`, `blockEinfuegen`, ab 1.0.65; Befund
  des Nutzers 09/2026: „Im Moment ist es so, dass ich zum Beispiel ein Foto
  nur auf eine Seite verschieben kann, die nach der aktuellen Seite neu
  angelegt wird. Etwas anderes steht mir offenbar nicht zur Verfügung. Ich
  würde es begrüßen, wenn ich dort einen ganz normalen Dialog bekommen
  würde, so wie er in jeder App gültig ist. Ausschneiden, kopieren,
  einfügen.").
  **Er hat recht, und es ist am Quelltext abzuzählen:** `verschiebenAbschnitt`
  und `kopierenAbschnitt` rechnen beide mit `seitenlage`, also mit den Seiten
  DIESES Tages. Ein Tag mit EINER Seite lässt davon „eine Seite zurück"
  (ausgegraut, `jetzt == 0`), „eine Seite vor" (fehlt, `jetzt+1 == anzahl`)
  und „auf Seite …" (fehlt, `anzahl <= 2`) wegfallen — übrig bleibt genau
  der eine Eintrag, den er beschreibt. Auf seinem Bildschirmfoto ist das
  Punkt für Punkt zu sehen.
  - **Die Ablage nimmt die Zielseite aus dem Menü heraus.** Eingefügt wird
    auf die GEWÄHLTE Seite (`einsetzbareSeite`), und die wählt man auf der
    Bühne mit einem Tipp — seit 1.0.61 ist sie dort sichtbar umrandet.
    Damit geht es über Seiten-, Tages- und Umschlagsgrenzen hinweg, ohne
    dass ein Menü jede mögliche Zielseite aufzählen müsste. Die beiden
    alten Abschnitte bleiben: Sie sind die Abkürzung für den Nachbarn.
  - **Die Ablage hält eine KOPIE, keinen Verweis**, und jedes Einfügen
    vergibt eine NEUE Kennung — auch beim ausgeschnittenen Block. Zwei
    Blöcke mit derselben Kennung sind für jede Suche einer (`block(_:)`
    fände immer nur den ersten); dieselbe Lehre wie bei `blockKopieren` und
    bei Tafelbild 1.4.5. Nebenwirkung mit Absicht: Zweimal einfügen ergibt
    zwei Blöcke.
  - **Ein FOTO wechselt beim Einfügen den Tag** (`fotoDemTagZuordnen`).
    `tag.fotos` sagt, wem ein Foto gehört; ohne diesen Schritt stünde es
    weiter in der Fotoliste des alten Tages und käme beim nächsten
    Neuanordnen dort wieder auf eine Seite. Aus dem alten Tag genommen wird
    es nur, wenn es dort in KEINEM Block mehr steht — seit `blockKopieren`
    darf dasselbe Foto zweimal im Buch stehen. Eine GRAFIK (seit 1.0.61)
    bleibt außen vor: Sie gehört keinem Tag.
  - **Ein TAGEBUCHTEXT verlässt seinen Tag NICHT** (`einfuegenGrund`).
    `Neuverteilung.fliesstexte` schreibt ihn beim Neuverteilen dorthin
    zurück, wo sein Block liegt; in einem fremden Tag stünde er danach im
    falschen Tagebuchtext, und zwar still. Dasselbe gilt für Überschrift,
    Datumszeile und Bildunterschrift — deren Text steht am Tag bzw. am
    Foto. Und eine KARTE kommt nicht auf den Umschlag; dort gibt es keinen
    Tag. Beides steht als SATZ da und nicht als fehlender Eintrag: Hier
    weiß man, warum es nicht geht, und ein weggelassener Knopf ließe einen
    raten, ob die Ablage leer ist oder das Ziel nicht passt.
  - **Der Rahmen wird auf den Satzspiegel der ZIELfläche geklemmt**
    (`inSatz`). Ein Block vom Umschlag ist breiter als eine Buchseite; ohne
    das Klemmen läge er dort halb im Anschnitt.
  - **Der Einfügeknopf steht in der FUSSLEISTE**, nicht nur im Menü. Wer
    gerade ausgeschnitten hat, hat keinen Block mehr gewählt — dann ist das
    Blockmenü weg, und im Plus-Menü müsste man den Eintrag erst suchen.
    Dieselbe Lehre wie beim Gruppenchat in Schulalarm und beim
    Sichtumschalter der Abfahrtstafel.
- **EIN BILD AUS DER MEDIATHEK GEHT AUCH OHNE DATUM** (`BildAusFotosView`,
  ab 1.0.65; Ansage des Nutzers 09/2026: „Nachdem dies geschehen ist, möchte
  ich über das Plusmenü aber auch Fotos auswählen können, egal ob von
  Dateien oder aus der Fotomediathek, die dann einfach auf der Seite
  eingefügt werden, egal welchen Zeitstempel sie haben."). Den Weg über
  DATEIEN gibt es seit 1.0.61 (`GrafikEinfuehrView`); aus der MEDIATHEK
  führte bis 1.0.64 jeder Weg durch die Fotoeinfuhr — also durch Datum, Ort,
  Tageszuordnung und einen Bericht darüber, was fehlt. Für ein Bild, das
  einfach auf einer Seite liegen soll, ist das alles keine Auskunft, sondern
  Lärm; genau dieser Befund hat 1.0.61 ausgelöst („1 Fotos tragen keinen Ort
  … 1 Fotos tragen kein Datum"), und er galt für die Mediathek weiter.
  **Es ist derselbe Wähler wie in der Fotoeinfuhr und dieselbe Funktion
  dahinter** (`grafikEinfuegen`) — zwei Fassungen desselben Einsetzens
  liefen auseinander. Das Bild gilt danach als `grafik`: keine Fotoliste,
  kein Punkt auf der Karte, kein Eintrag in „Fotos ohne Tag". Der Eintrag
  „Bild oder Grafik…" heißt seither „Bild aus Dateien…", damit die beiden
  Wege nebeneinander sagen, woher sie holen.
- **`loadDataRepresentation` DARF SEINEN RÜCKRUF MEHRMALS AUFRUFEN.** Ein
  zweites `resume` an einer `CheckedContinuation` ist kein Fehler, sondern
  ein Absturz — deshalb auch hier der Wächter `Einmal`, wie in der
  Zeitraumeinfuhr seit 1.0.30. **Wer eine zweite Stelle baut, die ein
  `itemProvider`-Ergebnis in `async` überführt, baut ihn mit.**
- **EIN INSPEKTOR MUSS LESBAR SEIN** (ab 1.0.65, gemeldet 09/2026 mit
  Bildschirmfoto: „Bei der Menüleiste, die sich herausschiebt, wenn ich den
  Pinsel drücke, ist die Transparenz zu groß eingestellt. Dort kann ich kaum
  etwas erkennen."). Eine `.inspector`-Spalte liegt auf iPadOS über dem
  Inhalt und bekommt von SwiftUI ein durchscheinendes Material. Über einer
  weißen Buchseite fällt das nicht auf; über einem randabfallenden Foto
  steht die Schrift im Bild — und genau dort steht sie IMMER, denn der
  Inspektor ist offen, WÄHREND man an einem Foto arbeitet. Zwei Zeilen
  zusammen, und keine reicht allein: `.scrollContentBackground(.hidden)` an
  JEDER `Form` darin (es sind zwei — die gefüllte und die leere) und
  darunter `.background(Color(uiColor: .systemGroupedBackground),
  ignoresSafeAreaEdges: .all)`. Ohne `ignoresSafeAreaEdges` bliebe oben und
  unten ein durchscheinender Streifen stehen.
- **Das Schriftenrecht trägt die App-Id inzwischen** (Ansage des Nutzers,
  09/2026, mit Bildschirmfoto aus Xcode: Capability „Fonts" bzw. „Font
  Enumeration", Haken bei „Use Installed Fonts" — „Es funktioniert nämlich
  mit dem Bild."). Damit ist der Grund weg, aus dem 1.0.45 das Recht wieder
  ausgebaut hat: Es fehlte an der App-Id, und ein Profil kann nur
  bewilligen, was die App-Id kann. **Ins Repo gehört es trotzdem erst,
  wenn die Zeichenkette NACHGESCHLAGEN ist und nicht geraten** — genau
  daran ist 1.0.44 gescheitert, und der Preis war nicht eine Funktion,
  sondern der ganze Bau. Nachzulesen ist sie an zwei Stellen auf dem Mac
  des Nutzers: in `Config/Urlaubstagebuch.entitlements`, die Xcode selbst
  geschrieben hat, und im Befund unter „Schriften prüfen", der seit 1.0.45
  die Rechte aus dem eingebetteten Profil liest. **Erst diese Zeichenkette
  wird eingetragen, nicht vorher.** — **Erledigt in 1.0.66**, siehe dort.
- **EIGENE FELDER AUF TITELSEITE UND RÜCKSEITE — SIE LIEGEN NEBEN DER
  GERECHNETEN SEITE, NICHT DARIN** (`Umschlag.titelbloecke`, `.rueckbloecke`,
  ab 1.0.64; Ansage des Nutzers 09/2026: „Es soll mir zum Beispiel auch
  möglich sein, dort eigene Felder oder Bilder zu positionieren."). Seit
  1.0.50 stand hier, ein Block auf dem Umschlag wäre beim nächsten
  Durchgang weg — und das stimmte: Titel- und Rückseite werden bei JEDEM
  Durchgang von `Layoutautomat.titelseite`/`.rueckseite` neu gesetzt, ein
  hineingeschriebener Block wäre beim nächsten Neuzeichnen verschwunden.
  Der Ausweg, den 1.0.50 nannte (beide Seiten zu echten `Seite`n in der
  Reise einzufrieren), ist bewusst NICHT gegangen worden: Dann hinge der
  Umschlag für immer an dem Stand, den er beim Einfrieren hatte — ein neuer
  Titel, ein anderes Titelfoto, ein anderer Stil schlügen nie mehr durch.
  - **Die eigenen Blöcke liegen deshalb DANEBEN**, als zwei Listen am
    `Umschlag`, und `Reise.seitenfolge(titelblatt:rueckblatt:)` hängt sie
    der gerechneten Seite an (`mitEigenen`). Der gerechnete Teil bleibt
    lebendig, die eigenen Felder überstehen jedes Neuanordnen, jeden
    Stilwechsel und jedes Neuverteilen — sie stehen ja in keinem Tag.
  - **Angehängt heißt OBEN.** Ein eigenes Feld auf einem randabfallenden
    Titelfoto wäre darunter unsichtbar. „Nach vorn holen" ist auf dem
    Umschlag deshalb schlicht das Ende der eigenen Liste.
  - **An EINER Stelle angehängt**, gefragt vom Bildschirm und vom PDF —
    beide holen ihre Seiten aus `seitenfolge`. Zwei Fassungen ergäben eine
    Vorschau, die anders aussieht als die Datei, und der Unterschied fiele
    erst beim Drucker auf.
  - **Der Merker des gemerkten Titelblatts darf sie NICHT kennen**
    (`Umschlag.satzmerkmal`). `Reisewerk` merkt sich die gesetzte Titel-
    und Rückseite, weil ihr Satz zwei CoreText-Messungen kostet; bis 1.0.63
    stand dafür der ganze Umschlag im Schlüssel. Ständen die Blöcke darin,
    setzte jeder Bildpunkt einer Ziehbewegung die Titelseite neu. Gerechnet
    wird das Merkmal über eine KOPIE ohne die beiden Listen und nicht über
    eine Aufzählung der übrigen Felder: Ein Feld, das jemand morgen
    hinzufügt, ist damit von selbst dabei.
  - **`block(_:)` findet sie weiterhin nicht — und das ist richtig.** Es
    gibt Tag, Seite und Stelle zurück; wer einen TAG braucht (Text teilen,
    auf eine andere Seite schieben, kopieren), kann mit einem Umschlagblock
    nichts anfangen. Genau diese Knöpfe erscheinen dort von selbst nicht.
    Alles, was nur den Block selbst betrifft — auswählen, schieben, ziehen,
    drehen, Text schreiben, nach vorn holen, entfernen —, geht seit 1.0.64
    zusätzlich durch `umschlagblock(_:)`; gelesen wird über `blockWert(_:)`,
    sonst bliebe der Inspektor bei einem angetippten Block leer.
  - **Eine KARTE wird dort nicht angeboten.** Sie zeichnet die Spur EINES
    Tages, und auf dem Umschlag gibt es keinen; was dort stünde, wäre ein
    leerer Rahmen mit dem Satz „Kartenbild fehlt". Dasselbe gilt für
    „Rest auf die nächste Seite": Die Fortsetzung bräuchte eine nächste
    Seite, und der Umschlag hat keine — deshalb sagt `teilbar` dort nein,
    und zwar im Werk und nicht in der Ansicht (gefragt wird an zwei
    Stellen).
  - **Mitgezogen an vier weiteren Stellen**, und jede davon wäre ein
    stiller Fehler gewesen: `Formatwechsel` rechnet die Rahmen mit (sonst
    säße nach A4 → A5 jedes Feld halb außerhalb), `fotoEntfernen` räumt
    Blöcke weg, deren Bild es nicht mehr gibt, `Druckpruefung`
    zählt abgeschnittenen Text auch dort, und `Buchdatei` nimmt die Bilder
    ohnehin mit, weil eine eingesetzte Grafik ein gewöhnliches `Foto` der
    Reise ist.
  - **Die AUSGLEICHSSEITE bleibt draußen.** Sie wird gerechnet, gehört
    keinem und hat keinen Ort, an dem etwas liegen bleiben könnte — dort
    wäre ein Block wirklich beim nächsten Durchgang weg.
  - **Nicht gemessen (1.0.65):** Nichts davon ist auf einem Gerät gesehen
  worden. Am Quelltext ABGEZÄHLT ist die Ursache des gemeldeten
  Verschiebe-Engpasses (beide Abschnitte rechnen mit `seitenlage`, und ein
  Tag mit einer Seite lässt davon einen Eintrag übrig) — und sie passt Punkt
  für Punkt zum Bildschirmfoto. **Ungeprüft ist die Abhilfe beim
  Inspektor**: Dass eine `.inspector`-Spalte ihr Material freigibt, sobald
  die `Form` ihren Hintergrund abgibt, ist die Lesart der Dokumentation und
  keine Messung; hilft es nicht, ist der nächste Griff `.presentationBackground`
  bzw. ein eigener `ZStack` um die Spalte. Ebenso ungesehen: ob die Mediathek
  die ECHTE Endung hergibt (bei einem bearbeiteten Foto liefert sie oft JPEG,
  auch wenn das Original ein PNG war) und wie sich das Umhängen eines Fotos
  in einen anderen Tag auf dessen Satz auswirkt — neu angeordnet wird dabei
  NICHTS, der Block bleibt, wo er eingefügt wurde. **Nicht als erledigt
  darstellen.**
- **Nicht gemessen (1.0.64):** Keine Seite ist damit gesehen worden.
    Gerechnet ist, WARUM ein Block in der gerechneten Seite verschwindet
    und warum er daneben stehen bleibt. **Gewählt und nicht gemessen** sind
    die Startmaße eines neuen Umschlagfeldes (60 % der Satzbreite,
    höchstens 280 pt, 90 pt hoch). **Und eigene Felder oder Bilder AUF DEM
    RÜCKEN gibt es weiterhin NICHT** — der Rücken ist ein rund zwölf
    Millimeter breiter Streifen mit eigener Geometrie und eigenem Weg ins
    PDF (`Rueckensatz`, `umschlagPdf`); ein Blockrahmen würde dort auf das
    Buchformat geklemmt und nicht auf die Rückenbreite. Er behält seine
    eine einstellbare Textzeile. **Nicht als erledigt darstellen.**
- **DER UMSCHLAG HATTE ZWEI FASSUNGEN, UND SIE ZEIGTEN VERSCHIEDENES**
  (`Model/Rueckensatz.swift`, ab 1.0.63; Befund des Nutzers 09/2026: „Im
  vorliegenden Beispiel hat es den Eindruck, dass der Buchrücken in einem
  dunklen Grau gestaltet ist … oder ganz einfach das Hintergrundbild von
  Deckblatt und Rückseite durchlaufen zu lassen."). Im PDF lief der Grund
  schon immer über den GANZEN Bogen samt Rücken (`umschlagPdf`); auf dem
  Bildschirm zeichnete jede Hälfte ihren eigenen, und dazwischen lag der
  Rücken als graue Fläche mit einer festen Bildschirmschrift. **Das ist die
  Trennung, die die erste Regel dieser App verbietet** — und sie war kein
  Wunsch des Nutzers, sondern ein Fehler.
  - **Ein Bild über den ganzen Bogen.** Die beiden Hälften lassen ihren
    Grund weg (`SeitenflaecheView.ohneGrund`) — und zwar auch das WEISSE
    Papier darunter, sonst deckte es genau das Bild ab, um das es geht.
  - **Eine Ungenauigkeit bleibt und steht dabei:** Die Ansicht zeigt beide
    Hälften mit eigenem Anschnitt, der gedruckte Umschlag ist innen um zwei
    Anschnitte schmaler (dieselbe Sache wie am Bund seit 1.0.58). Das Bild
    steht auf dem Bildschirm gut ein Prozent breiter als im Druck — eine
    Ungenauigkeit der ANSICHT, nicht der Datei.
  - **Lage und Leserichtung des Rückentextes sind einstellbar.** Die Lage
    ist ein ANTEIL (0 = Kopf, 1 = Fuß) und keine Millimeterzahl, damit sie
    einen Formatwechsel übersteht; in der Oberfläche steht sie in Worten.
  - **Verschieben geht nur mit einem Kasten, der SCHMALER ist als sein
    Platz.** Ein Kasten über die ganze Rückenlänge sähe mittig zentriert
    immer gleich aus, wie weit man den Regler auch schöbe — deshalb misst
    `Textmass.breite` seither die natürliche Breite eines Textes.
  - **Nicht gemessen:** Kein Umschlag ist gedruckt worden. Und die eigenen
    Felder oder Bilder AUF dem Rücken, um die ebenfalls gebeten wurde, gibt
    es noch NICHT: Der Umschlag wird gerechnet und nicht gesetzt, ein Block
    darauf wäre beim nächsten Durchgang weg (der Weg dahin steht seit 1.0.50
    hier). **Nicht als erledigt darstellen.** — Nachtrag: Für Titel- und
    Rückseite ist das seit 1.0.64 gelöst, und zwar anders als hier
    vermutet (die Blöcke liegen NEBEN der gerechneten Seite, nicht darin).
    Für den RÜCKEN gilt der Satz unverändert weiter.
- **DIE APP LÄUFT AUCH AUF DEM MAC — ALS MAC CATALYST** (ab 1.0.62, Ansage
  des Nutzers 09/2026: „Jetzt möchte ich tatsächlich doch noch die Option
  haben, das Ganze auf dem Mac nutzen zu können, und zwar als eigenständige
  Mac-App."). Ein Quelltext, ein Bundle, ein iCloud-Behälter — ein Buch vom
  iPad ist auf dem Mac dasselbe Buch.
  - **„Optimiert für Mac", nicht „auf iPad-Maß skaliert"**
    (`SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD = NO`). Die skalierte Fassung
    zeigt alles um knapp ein Viertel verkleinert; in einer App, in der man
    Millimeter setzt, ist das die falsche Wahl.
  - **ZWEI Rechte-Dateien, und das ist keine Formsache**
    (`CODE_SIGN_ENTITLEMENTS[sdk=macosx*]`). macOS verlangt den Sandkasten
    samt `files.user-selected.read-write`, `network.client`,
    `personal-information.photos-library` und `print`; iOS kennt diese
    Schlüssel gar nicht. Wer sie in die vorhandene Datei schreibt, macht die
    iOS-Fassung unsignierbar — **genau der Fehler aus 1.0.44**. Dieselbe
    Bauweise wie bei Schulalarm seit 1.0.18.
  - **Keines dieser Rechte ist eine Fähigkeit der App-Id.** Sandkasten-Rechte
    wertet das System aus, nicht das Profil; die Ausnahme ist iCloud, und das
    ist dasselbe Recht wie auf iOS.
  - **Ohne `files.user-selected.read-write` kommt aus dem Dateiwähler NICHTS
    an** — und zwar ohne Fehlermeldung. Das trifft „Bilder aus Dateien", die
    Grafik-Einfuhr und das Einlesen einer `.reisebuch`-Datei.
  - **Der Bau prüft es mit.** `ios-apps-build.yml` übersetzt seither jede App,
    deren Projekt `SUPPORTS_MACCATALYST = YES` trägt, zusätzlich gegen das
    Catalyst-SDK; welche das sind, steht im Projekt und nicht in einer zweiten
    Liste (die liefe auseinander). Eine Schnittstelle, die es dort nicht gibt,
    fiele sonst erst auf dem Mac des Nutzers auf.
  - **`userInterfaceIdiom` ist dort `.mac`**, nicht `.pad`. Wer auf `.pad`
    prüft, um einen Anker für einen Dialog zu setzen, verliert ihn auf dem Mac
    (getroffen beim Druckdialog).
  - **Auf dem iPhone bleibt alles, wie es ist** (Ansage des Nutzers): Die App
    startet dort und zeigt die Seiten; für die Bedienung umgebaut wird sie
    nicht.
  - **`LSSupportsOpeningDocumentsInPlace = NO` lehnt macOS AB** — „Either
    remove the entry or set it to YES". **Gefunden hat das der neue Mac-Bau,
    im ersten Lauf, in dem es ihn gab**; der iOS-Bau war dabei grün. Genau
    dafür ist er da. Weggelassen genügt aber nicht: Dann WARNT der Bau, die
    App unterstütze das Öffnen von Dateien, sage aber nicht, ob an Ort und
    Stelle. Der Schlüssel steht deshalb auf `YES` — für diese App keine
    Zusage, die sie nicht hält: Sie liest die Datei und schreibt ihren Inhalt
    in die eigene Ablage. **Dazu gehört zwingend
    `startAccessingSecurityScopedResource` beim Einlesen** (an Ort und Stelle
    kommt die Datei aus einem fremden Ordner und ließe sich sonst nicht
    lesen, ohne Fehlermeldung) — und `aufraeumen` löscht weiterhin NUR im
    Posteingang, ein Buch des Nutzers wird nicht angefasst.
  - **Nicht gemessen:** Auf einem Mac hat das niemand gesehen. Der Bau beweist,
    dass sich der Quelltext übersetzen lässt — **nicht, dass sich signieren
    lässt** (`CODE_SIGNING_ALLOWED=NO`); dafür muss die App-Id iCloud auch für
    macOS können. Und wie sich die Bühne mit Maus und Trackpad anfühlt, ist
    offen: Zoomen mit zwei Fingern, das Ziehen der Blöcke und die Griffe sind
    für Finger gebaut.
- **EIN KNOPF, DER AUF „IRGENDEINE" SEITE WIRKT** (`Reisewerk.gewaehlteSeite`,
  ab 1.0.61; Befund des Nutzers 09/2026: „schwer zu erkennen, ob eine Seite
  ausgewählt wird bzw. auf welcher Seite die Änderungen, die ich vornehmen
  möchte, greifen werden"). „Auf die Seite legen" gab es seit 1.0.0 — im
  Block-Inspektor, und nur, wenn gerade KEIN Block gewählt ist; gefunden hat
  es niemand (elfter Fall von „es war da, man fand es nicht"). Schlimmer war,
  worauf es wirkte: auf `werk.seitenzeiger`, einen Zähler, den Einfügen,
  Löschen und Verschieben setzen und der mit dem, was im Bild steht, NICHTS
  zu tun hat.
  - **Gewählt wird jetzt eine SEITE, und man sieht es**: ein Rahmen in der
    Akzentfarbe um das Blatt, dazu „· ausgewählt" unter der Seite. Gezeichnet
    AUSSERHALB des Maßstabs, wie der Schatten seit 1.0.20 — eine Linie, die
    beim Herauszoomen dünner wird, ist genau dann weg, wenn man die Übersicht
    braucht.
  - **Ein Tipp wählt, sonst folgt die Wahl dem Bild** (dieselbe Regel wie beim
    gewählten Tag seit 1.0.28) — aber nur, wenn das gewählte Blatt gar nicht
    mehr zu sehen ist. Sonst nähme das Scrollen innerhalb einer Doppelseite
    dem Nutzer das Blatt weg, das er eben angetippt hat.
  - **Umschlag und Ausgleichsseite werden nicht angeboten.** Sie werden
    gerechnet und stehen in keinem Tag; ein Block darauf wäre beim nächsten
    Durchgang weg.
  - **Das Menü nennt die Seite beim Namen.** Ein Menü, das nicht sagt, worauf
    es wirkt, ist die Frage von vorhin noch einmal. Inspektor und Plus-Menü
    zeigen dieselbe Seite und rufen dieselbe Stelle.
- **EINE GRAFIK IST KEIN REISEFOTO** (`Foto.grafik`, `Reisewerk.grafikEinfuegen`,
  ab 1.0.61; Ansage des Nutzers 09/2026: „Diese Bilder sollen dann nicht in
  der Reisespur auftauchen und es ist völlig unerheblich, ob sie einen
  Zeitstempel haben oder einen Ort."). Sie geht NICHT durch die Fotoeinfuhr:
  Die ordnet einem Tag zu, liest Datum und Ort, baut daraus Reisepunkte und
  meldet hinterher, was gefehlt hat — für eine Grafik ist jede dieser
  Auskünfte Lärm, und genau das wurde gemeldet („1 Fotos tragen keinen Ort …
  1 Fotos tragen kein Datum und stehen jetzt bei 4. Juni 2026"). Gelesen
  werden nur die MASSE.
  - **Sie ist nicht heimatlos**, sondern liegt da, wo jemand sie hingelegt
    hat: `Reise.heimatlose` lässt sie aus, sonst stünde sie in der Fotoablage
    als Aufgabe, die es nicht gibt. In die Reisespur kommt sie ohnehin nicht —
    die wird aus `tag.fotos` gebaut, und dort steht sie nicht.
  - **Der Weg führt in die DATEIEN, nicht in die Mediathek**, und die ECHTE
    Endung bleibt erhalten: Eine Grafik ist meist ein PNG mit durchsichtigem
    Grund, und den gibt die Mediathek nicht zuverlässig her — dieselbe
    Überlegung wie beim Wasserzeichen.
  - **Der Rahmen folgt dem Seitenverhältnis des Bildes.** Ein fester Rahmen
    schnitte jedes Hochformat an, denn gefüllt wird, nicht eingepasst.
  - **Nicht gemessen:** Ob die Seitenwahl sich richtig anfühlt, sagt erst der
    nächste Befund; geändert sind Wege und Namen, und das ist keine Messung.
- **DIE LETZTE SEITE EINES BUCHES IST EINE LINKE** (`Reise.brauchtAusgleich`,
  `blockseiten`, ab 1.0.60; Ansage des Nutzers 09/2026: „Natürlich muss die
  letzte Seite des Buches eine linke Seite sein, also eine gerade Seitenzahl
  haben. Ist das bei den erstellten Seiten nicht der Fall, dann musst du
  bitte noch eine zusätzliche Seite anlegen."). Ein Blatt hat zwei Seiten,
  also hat ein gebundener Block eine gerade Zahl davon. Bis 1.0.59 hat die
  App den Fall nur GEMELDET — und das war die falsche Art Antwort:
  **Gemeldet wird ein Zustand, den man ändern kann; dieser lässt sich nicht
  ändern, das Papier ist ja da.** Die Frage war allein, ob die letzte Seite
  im PDF steht oder ob der Druckdienst sie stillschweigend anhängt, und das
  Zweite ist eine Seite, die niemand gesehen hat.
  - **Ergänzt wird in `Reise.seitenfolge`**, also dort, wo auch das
    Titelblatt entsteht — NICHT als Seite in einem Tag. Damit fasst sie kein
    Neuanordnen an, kein Muster und kein Stilwechsel, und sie verschwindet
    von selbst, sobald eine echte Seite dazukommt. Bearbeiten lässt sie sich
    nicht; sie steht in keiner Seitenliste.
  - **Ihre Kennung ist FEST** (`Reise.ausgleichsseitenKennung`) und wird
    nicht bei jedem Durchgang gewürfelt: An der Kennung hängen `ForEach`,
    `scrollTo` und der Vergleich aus 1.0.59 — dieselbe Überlegung wie beim
    gemerkten Titelblatt.
  - **Sie gehört dem LETZTEN Tag.** Ohne Tag hielte `wasserzeichen(fuer:)`
    sie für eine Umschlagseite (dort heißt „kein Tag" genau das) und
    `kurzname` nennte sie „Titelseite".
  - **Leer heißt nicht nackt:** Sie trägt den Hintergrund des Buches und
    damit die zweite Hälfte eines Bildes, das über die Doppelseite läuft —
    der letzte Bogen geht dadurch auf. Eine Seitenzahl bekommt sie nicht.
  - **Zwei Zahlen daneben waren falsch.** `innenseiten` (daraus folgt die
    RÜCKENBREITE) ließ die Titelseite aus, wenn sie kein eigener
    Umschlagbogen ist — der Rücken war um ein halbes Blatt zu dünn
    gerechnet. Und `seitenzahl` zählte ausgeblendete Tage mit, nannte also
    im Ausgabeblatt eine andere Zahl, als die Datei hinterher Seiten hatte.
    Beide kommen seither aus `blockseiten`.
  - **Wer eine Zählung ändert, sucht nach jeder Stelle, die sie nachbaut.**
    `Druckpruefung.doppelseitenhintergrund` baut die Nummerierung selbst
    nach; ohne die Ausgleichsseite hätte es genau dort eine halbe
    Doppelseite gemeldet. (Dieselbe Lehre wie bei der Umstellung in 1.0.52,
    dort waren es drei Stellen.)
- **DIE AUFLÖSUNG IM PDF HÄNGT AN ZWEI ZAHLEN, UND DIE PRÜFUNG KANNTE NUR
  EINE** (`Model/Ausgabeguete.swift`, ab 1.0.59; Frage des Nutzers 09/2026:
  „ist eigentlich gewährleistet, dass die PDF-Datei die für den Druck
  erforderliche Auflösung beinhaltet. Ich lasse ja bei einem sehr guten
  Fotodienst entwickeln."). Die Aufnahme liegt unverändert im Bildarchiv —
  beim AUSGEBEN rechnet `Bildarchiv.fuerAusgabe` sie aber auf eine
  Höchstkante herunter (`auftrag.bildkante`, Vorwahl 3600). Die Druckprüfung
  rechnete bis 1.0.58 mit `foto.breite`, also mit den Bildpunkten der
  Originaldatei, und nannte damit eine Zahl, die die Datei gar nicht hält:
  Bei „Zum Ansehen" (1600) war das das Doppelte bis Dreifache, und die
  Meldung „Alle Bilder über 250 dpi" stand über einem PDF, in dem kein
  einziges Bild so fein war. **Eine Prüfung, die eine Zahl nennt, die die
  Datei nicht hält, ist schlimmer als keine** — dieselbe Regel wie bei
  „Plan" gegen „pünktlich".
  - **Die Kante steht an EINER Stelle.** `Bildguete` ist deshalb aus
    `AusgabeView` ins Modell gewandert: Eine Ansicht kann die Druckprüfung
    nicht fragen, und zwei Fassungen derselben Zahl liefen auseinander.
    Gerechnet wird in der Prüfung mit `Bildguete.vorgabe`, weil das der
    Regelfall beim Ausgeben ist — **und die Zeile schreibt hin, dass sie es
    tut**, statt es vorauszusetzen. Wer eine andere Güte wählt, bekommt
    seine Zahl im Ausgabeblatt, dort mit dem gewählten Deckel.
  - **Das HINTERGRUNDFOTO wird mitgezählt.** Es füllt Seite oder
    Doppelseite ganz aus und ist damit fast immer das schwächste Bild eines
    Buches; gezählt wurden bis 1.0.58 nur Fotoblöcke. Die Fläche dafür
    rechnet `Bogenlage.bildflaeche` — dieselbe Funktion, die auch zeichnet.
  - **„Gedeckelt" und „das Foto gibt nicht mehr her" sind zwei Befunde.**
    Nur der erste lässt sich im Ausgabeblatt beheben, und nur dann nennt
    die App die höhere Güte als Antwort. Gerechnet wird beides in einem
    Durchgang (`dpi` gibt zwei Werte zurück).
  - **Gerechnet wird in einer AUFGABE, nicht im Körper.** Der Lauf geht
    über jede Seite und jedes Bild des Buches — dieselbe Falle wie bei der
    Druckprüfung in 1.0.0.
  - **Nicht gemessen:** Keine Datei ist damit gedruckt worden. Gerechnet
    ist, was die Kante mit der Auflösung macht; ob ein Druckdienst sie
    annimmt und wie das Papier aussieht, sagt erst der erste Abzug.
- **EINE ZOOMGESTE DARF NICHT JEDE SEITE NEU BAUEN** (`SeitenflaecheView:
  Equatable`, `.equatable()`, ab 1.0.59; Wunsch des Nutzers 09/2026: „wenn
  Verschiebe- oder Zoom-Aktionen auf dem Bildschirm etwas flüssiger
  ablaufen könnten"). Der Zoom WÄHREND der Geste ist seit 1.0.18 eine reine
  Skalierung, und das ist richtig — gerechnet wird erst am Ende. Nur: `lupe`
  ist ein Zustand im Körper der Bühne und wird bei jedem Bildpunkt gesetzt.
  Damit bekommt jede sichtbare `SeitenflaecheView` einen neuen Wert, und
  ohne Vergleich muss SwiftUI von einer Änderung ausgehen: Hintergrund,
  Wasserzeichenlage (ein Suchlauf über 49 Felder), jeder Textkasten, jedes
  Vorschaubild. Verglichen wird jetzt, was das Aussehen bestimmt — das
  `werk` über die IDENTITÄT, denn was sich in ihm ändert, meldet es selbst
  und geht am Vergleich vorbei. **Es wird nichts abgeschaltet**, es fällt
  nur der Durchgang weg, bei dem sich nichts geändert hat. Dieselbe Bauweise
  wie bei der Netzkarte der Abfahrtstafel (1.1.17). **Wer eine gespeicherte
  Eigenschaft hinzufügt, trägt sie in `==` ein; wer eine dritte Aufrufstelle
  anlegt, hängt `.equatable()` mit dran.**
- **„Zoomgeste" stand im Befund und wurde NIE gezählt** (behoben in 1.0.59).
  In `ReiseView` stand seit 1.0.28 der Satz, die Zeile zähle, wie viele
  Gesten überhaupt angekommen sind — und im ganzen Quelltext gab es keinen
  einzigen `melde("Zoomgeste")`; die Zeile konnte gar nicht erscheinen.
  **Ein Kommentar ersetzt keine Prüfung**, zum wiederholten Mal, und
  diesmal an der Probe selbst. Gezählt wird seither je Bildpunkt der
  Bewegung, dazu die Bühne (`Bühne`). Damit ist die Gegenprobe zum Punkt
  darüber da: „Zoomgeste" hoch und „Seite" bei null heißt, die Geste kommt
  an und die Seiten zeichnen sich nicht mit; laufen beide gleich hoch, ist
  es umgekehrt. Mitgezählt in „Fotos" werden seither auch Hintergrundfoto
  und Wasserzeichen — Letzteres liegt auf JEDER Seite und war damit die
  Art Bild, die sich am ehesten summiert.
- **Offen und nicht als erledigt darstellen:** Am ENDE einer Geste ändert
  sich der Maßstab, und dann holt jede Seite ihre Vorschaubilder eine Stufe
  feiner neu von der Platte — auf dem HAUPTFADEN (`Bildarchiv.vorschau` ist
  synchron). Was das kostet, steht als „Fotos" im Befund; geändert ist
  daran in 1.0.59 nichts.
- **DER BUNDSTEG RÜHRT DEN HINTERGRUND NICHT AN — UND KEINE SCHON GESETZTE
  SEITE** (ab 1.0.58; gemeldet 09/2026 mit einem Bild der Doppelseitenansicht:
  „Der Bund soll offenbar tatsächlich bei 0 mm liegen. Das habe ich jetzt so
  eingestellt. Dennoch sieht es nicht so aus, als ob die App das akzeptiert
  hätte."). **Sie hat es akzeptiert:** 0 ist der Vorgabewert
  (`Gestaltung.bundsteg`) und der Anfang des Reglers, und `satzspiegel` addiert
  ihn schlicht auf `randAussen` — beidseitig, seit 1.0.1. Nicht zu sehen war es
  aus zwei Gründen, und beide gehören gesagt, statt den Regler zu ändern:
  - Er verschiebt den **Satzspiegel**, also den Platz, in den NEUE Seiten
    gesetzt werden. Blöcke stehen als Rechtecke im Buch; eine schon gesetzte
    Seite rückt kein Randwert nach. Wer sie mitziehen will, ordnet sie neu an.
  - Ein **Hintergrund** richtet sich gar nicht nach ihm. Er läuft immer bis in
    den Anschnitt — das ist seit 1.0.1 seine Definition, und eine Fläche, die
    am Endformat aufhörte, hätte nach dem Schneiden den weißen Faden.
  **Der Satz steht jetzt unter dem Regler** (`GestaltungView.zugabenhinweis`),
  also dort, wo die Frage entsteht.
- **Am Bund liegen ZWEI Anschnitte, und die stehen doppelt da.** Die
  Doppelseitenansicht zeichnet zwei Bogen ohne Abstand nebeneinander (Regel seit
  1.0.17), und jeder trägt an seiner Innenkante 3 mm Anschnitt. Bei einem Bild
  über die Doppelseite ist dieser Streifen deshalb **zweimal** im Bild — einmal
  von jeder Seite —, und im gebundenen Buch ist er weg. Genau darauf saß die
  gemeldete Sonne. **Das ist keine Panne der Ansicht**: Der Anschnitt gehört
  dorthin, und wo er endet, zeigt die rote Schnittkante. Was fehlte, war, dass
  es irgendwo steht.
- **EIN HINTERGRUNDFOTO LÄSST SICH ZOOMEN UND VERSCHIEBEN**
  (`Seitenhintergrund.ausschnitt`, ab 1.0.58, Ansage des Nutzers 09/2026: „mir
  würde auch die Funktion helfen, das Bild des Seitenhintergrundes etwas zoomen
  bzw. verschieben zu können. Dann würde ich in diesem Fall die Sonne … etwas
  verschieben."). Es ist derselbe `Bildausschnitt` wie am Fotoblock und dieselbe
  Rechnung — kein zweiter Typ für dieselbe Sache. `.voll` ist die Vorgabe und
  heißt „mittig und ohne Zoom", also genau der Stand von vorher.
  - **Der Bildschirm rechnete bis 1.0.57 ANDERS als das PDF.** Dort stand
    `scaledToFill`, hier `Bildausschnitt.voll.zielrechteck` — bei `.voll`
    dasselbe Ergebnis, mit einem eigenen Ausschnitt nicht mehr. Beide fragen
    seither `Bildausschnitt.gefuelltesZiel`, und das BEGRENZT vorher: Ein
    Versatz, der nach einem Formatwechsel oder nach dem Umlegen von „über die
    Doppelseite" nicht mehr im Bild läge, ließe sonst einen weißen Keil stehen.
    **Merke: Zwei Zeichner, die zufällig dasselbe tun, sind erst dann eine
    Rechnung, wenn sie dieselbe Funktion fragen.**
  - **Der Rahmen ist auf beiden Seiten derselbe**, nur anders ausgedrückt: Das
    PDF bekommt ihn in Seitenkoordinaten (`Bogenlage.bildflaeche`, Ursprung am
    Anschnitt), der Bildschirm rechnet ihn am Bogen aus (`bildrahmen(raum:)`).
    Nachgerechnet geht das auf — die Fläche über die Doppelseite misst
    2 × Endformat + 2 × Anschnitt, und ihre Mitte liegt genau auf dem Bund.
  - **REGLER und keine Geste.** Die Einstellung steht in einem `Form`, also in
    einer scrollenden Liste; eine Ziehgeste über der Probe stritte mit dem
    Scrollen — dieselbe Lehre wie 1.0.5 („Wer eine Geste über eine ganze Fläche
    legt, prüft, was diese Fläche sonst noch tut"). Ein Regler trifft dazu auf
    ein Prozent genau, und nach sieben Fassungen Gestenarbeit an der Bühne ist
    das hier der billigere Weg.
  - **Wo kein Spielraum ist, steht kein Regler.** Bei Zoom 100 % füllt das Bild
    den Rahmen in einer Richtung auf den Punkt; dort steht „kein Spielraum"
    statt eines Schiebers, der nichts bewirkt — ein Bedienelement ohne Wirkung
    ist für den Menschen davor ein kaputtes.
  - **Die Probe ist MASSSTÄBLICH** und zeigt die Fläche, die ins PDF geht, samt
    roter Schnittkante und — beim Bild über die Doppelseite — dem Band am Bund.
    `zielrechteck` misst den Versatz in Anteilen der Rahmenbreite und ist damit
    vom Maßstab unabhängig: Was dort steht, steht im Druck an derselben Stelle.
    Die Leiste ganz oben im Blatt hat dagegen NICHT das Maß einer Seite; das
    sagt die Fußzeile auch.
  - **`Seitenhintergrund` hat seinen Leser seit 1.0.47** — ein neues Feld war
    deshalb gefahrlos. Beide Initialisierer gehören mitgezogen, der eigene
    `init(from:)` UND der ausgeschriebene: Wer in einer Struktur einen
    Initialisierer schreibt, hat danach keinen mitgelieferten mehr.
- **Nicht gemessen (1.0.58):** Keine Seite ist damit gesehen worden. Gerechnet
  ist die Geometrie (dass beide Zeichner denselben Rahmen bekommen und die Probe
  maßstäblich dasselbe zeigt). **Und die Deutung des gemeldeten Bildes ist am
  Quelltext hergeleitet, nicht an seinem Buch nachgesehen** — dass die doppelte
  Sonne die beiden Anschnitte sind, folgt aus der Bauweise der
  Doppelseitenansicht; beweisen würde es erst ein Blick in die ausgegebene
  Datei. Ungeprüft ist außerdem, ob der Umschlag mit einem eigenen Ausschnitt
  zusammengeht: Auf dem Bildschirm wird sein Hintergrund je HÄLFTE gezeichnet,
  im PDF über den ganzen Bogen — die Probe im Blatt nimmt den ganzen Bogen, also
  die Fassung, die gedruckt wird. **Nichts davon als erledigt darstellen.**
- **`.frame` BESCHNEIDET NICHT — es stellt ein zu großes Kind MITTIG hinein**
  (`RegalView.Vorschaubild`, ab 1.0.57; gemeldet 09/2026 mit Bildschirmfoto:
  „Die Beschriftung des Projektes ragt in das Bild mit rein. Das sieht nicht
  gut aus.“). **Nachgerechnet und keine Vermutung:** Das Titelfoto im Regal
  steht in einem `ZStack` mit `.frame(width: 52, height: 68)`. `scaledToFill`
  füllt den vorgeschlagenen Rahmen und wird dabei in einer Richtung GRÖSSER
  als er — ein Querformat-Foto (4:3) misst bei 68 Punkt Höhe gut 90 Punkt in
  der Breite und steht links und rechts um je 19 Punkte über. Der Rahmen
  begrenzt nur das LAYOUT, nicht die Zeichnung; in der `HStack` daneben beginnt
  die Beschriftung genau dort. Weil die Texte NACH dem Bild gezeichnet werden,
  liegen sie obenauf — für den Menschen davor ragt also die Beschriftung ins
  Bild, und genau so ist es gemeldet worden.
  - **Ein `clipShape` am BILD hilft nicht**, und genau eines stand dort seit
    1.0.19: Es beschneidet den Rahmen des Bildes, und der ist ja der zu große.
    Beschnitten wird jetzt der Behälter, also NACH dem `.frame` — dieselbe
    Reihenfolge, die `TagListeView`, `TagInhaltView` und die Hintergrundfläche
    der Seite seit jeher benutzen. Der Schatten liegt dahinter und folgt damit
    der beschnittenen Form.
  - **Dritte Auflage derselben Falle.** 1.0.2 lernte sie an den Griffen („was
    außerhalb eines Frames liegt, nimmt keinen Finger an“), 1.0.12 am
    `TextflaecheBruecke` („`.frame()` beschneidet nicht, es stellt ein zu
    großes Kind MITTIG hin“) — beide Male beim Bearbeiten einer Seite, und
    beide Male stand die Lehre danach im Papier. Sie galt für das Regal nicht,
    weil dort niemand ein zu großes Kind vermutet hat. **Wer `scaledToFill`
    schreibt, schreibt das Beschneiden in derselben Zeile mit.**
  - **Die Textspalte nimmt jetzt, was übrig ist** (`.frame(maxWidth: .infinity,
    alignment: .leading)` statt eines `Spacer` daneben) — die Lehre aus
    Abfahrtstafel 1.1.32. Das ist eine Vorsichtsmaßnahme und NICHT die
    gemeldete Ursache: Mit drei Textzeilen in der Spalte ist die Idealbreite
    die der längsten Zeile, und die geht auf. Es steht trotzdem da, weil eine
    vierte Zeile es morgen nicht mehr täte.
- **Nicht gemessen (1.0.57):** Das Regal ist damit auf keinem Gerät gesehen
  worden. Gerechnet ist der Überstand (90,7 statt 52 Punkte bei einem
  Titelfoto im Verhältnis 4:3, also 19,3 Punkte je Seite) und die Wirkung des
  Beschneidens. **Ungeprüft bleibt**, ob das Bildschirmfoto des Nutzers wirklich
  ein Querformat-Titelfoto zeigt — ein Hochformat (3:4) steht in diesem Rahmen
  nur um gut einen Punkt über und fällt kaum auf; die Ursache wäre dieselbe,
  der Betrag ein anderer. **Nicht als erledigt darstellen.**
- **Nicht gemessen (1.0.56):** Keine Seite ist damit gesehen worden.
  Gerechnet ist die Auswahl und ihre Geometrie; **die Verteilung ist eine
  Wahrscheinlichkeitsaussage und keine Zusage** — wie sie in einem
  wirklichen Buch ausfällt, sagt erst die neue Zeile im Befund. **Gewählt
  und nicht gemessen** sind die Höchstzahl zehn (sie ist die Zahl aus der
  Ansage), der Mischfaktor des Ziehens und die Schwellen von `formtext`
  (1,08 und 0,93). Ungeprüft ist, ob ein Buch mit zehn Zeichenbildern beim
  Ausgeben spürbar langsamer wird — je Seite wird weiterhin genau EIN Bild
  geladen, aber aus zehn verschiedenen Dateien statt aus einer, und der
  Bildvorrat hält nur 120 Einträge. **Nicht als erledigt darstellen.**
- **Nicht gemessen (1.0.55):** Keine Seite ist damit gesehen worden.
  Gerechnet und am Quelltext abgezählt ist die URSACHE (der Schleier
  skaliert den Kanalabstand mit `1 − a`) und die Wirkung des Faktors;
  gemessen wird auf dem Gerät allein der Randanteil. **Gewählt und nicht
  gemessen** sind der Deckel von 3,5 auf den Faktor, die 48er-Messkante,
  die Zwanzigstel-Stufen und die Schwellen der Warnzeile (0,5 % und 8 %).
  **Ungeprüft ist vor allem, ob das gedruckte Blatt so aussieht wie der
  Bildschirm**: Ein gesättigtes Bild hinter einem Schleier wirkt auf einem
  leuchtenden Schirm kräftiger als auf Papier, und wie weit `CIColorControls`
  im PDF dasselbe tut wie in der Vorschau, ist zwar dieselbe Funktion, aber
  auf zwei verschiedenen Bildgrößen. **Nicht als erledigt darstellen.**
- **Nicht gemessen (1.0.54):** Keine Seite ist damit gesehen und keine
  Umschlagdatei gedruckt worden. **Gemessen ist das Ablesen** — die Pixel-
  und dpi-Werte, die Millimeterleiter, die Vorlagenmaße der Innenseiten —,
  und es ist an Bildschirmfotos abgelesen und nicht an einer Datei des
  Anbieters. Ändert Saal sein Papier, ändert sich die Tabelle, und diese App
  merkt davon nichts; verbindlich bleibt die Angabe des Druckdienstes.
  **Gewählt und nicht gemessen** sind die Toleranz der Formatzuordnung
  (12 mm) und die Reglerweite der Verschiebung (halbe Satzbreite bzw.
  -höhe). Ungeprüft ist, ob eine per Hand gedrehte Seite im PDF so steht wie
  auf dem Bildschirm — gerechnet wird es aus derselben Funktion, gesehen hat
  es niemand. **Nichts davon als erledigt darstellen.**
- **Nicht gemessen (1.0.53):** Keine Seite ist damit gesehen worden.
  Gerechnet und am Quelltext abgezählt ist die URSACHE — dass eine Ebene mit
  ihrem `contentsScale` rastert und ein `scaleEffect` das Ergebnis dehnt.
  **Gewählt und nicht gemessen** sind alle Zahlen: das Pixelbudget
  (6 Millionen), die Stufenliste, die obere Grenze der Vorschaubilder (Fotos
  2000, Wasserzeichen 1600, Hintergrund 2000 bzw. 2800 über die Doppelseite)
  und die 200er-Rundung der Kanten. **Ungemessen bleibt der PREIS**: Eine
  feinere Rasterung kostet Speicher und Zeichenzeit, und wie sich ein Buch
  mit zweihundert Fotos bei 400 % anfühlt, sagt erst der nächste Befund —
  seit 1.0.53 sagt er es mit Zahlen. **Nicht als erledigt darstellen.**
- **Nicht gemessen (1.0.52):** Keine Seite ist damit gesehen worden. Am
  Quelltext abgezählt sind die URSACHEN (der Umschlag in der Zählung, das
  Meldeband hinter dem Vollbild) und die Geometrie der Drehung. **Gewählt
  und nicht gemessen** sind die Höchstdrehung (45 Grad) und die Vorgabe
  beim Einschalten (12 Grad). **Ungeprüft bleibt**, ob ein Druckdienst den
  Umschlagbogen annimmt (das stand schon zu 1.0.50 offen), ob die
  Rückentabelle eines Anbieters mit dieser Lesart zusammenpasst — sie ist
  hier an keiner echten Tabelle geprüft — und ob ein gedrehtes Zeichen im
  Druck so steht wie auf dem Bildschirm. **Nichts davon als erledigt
  darstellen.**
- **Nicht gemessen (1.0.51):** Keine Karte ist damit gesehen worden.
  Gerechnet und am Quelltext abgezählt ist die URSACHE (es gab schlicht kein
  Feld am Block, und der Abschnitt fragte den falschen Tag). **Ungeprüft
  bleibt, ob der Befund des Nutzers denselben Grund hatte** — auf seinem
  Bildschirmfoto fehlte der Kartenabschnitt ganz, und das passt zum zweiten
  Fall („`gewaehlterTag` zeigt ins Leere"), ist aber nicht nachgewiesen.
  **Nicht als erledigt darstellen.**
- **Nicht gemessen (1.0.50):** Kein Umschlag ist damit gedruckt worden.
  Gerechnet und am Quelltext abgezählt ist die URSACHE der fehlenden
  Seitenzahlen; die Geometrie des Bogens ist gerechnet und nicht gesehen.
  **Gewählt und nicht gemessen** sind die Vorgaben 0,13 mm je Blatt und 4 mm
  Deckelstärke, die Warnschwelle von 4 mm Rückenbreite und der Anteil 0,62,
  auf den die Rückenschrift gedeckelt wird. **Ungeprüft ist vor allem, ob ein
  Druckdienst diesen Bogen annimmt** — die Boxen sind gesetzt, die Falze
  stehen nur als Rückenbreite darin, und das ist die Stelle, an der Anbieter
  auseinandergehen. Und ein Hintergrundfoto mit „über die Doppelseite" rechnet
  auf dem Umschlag die Rückenbreite nicht mit; über den Umschlag läuft es
  ohnehin als EIN Bild. **Nichts davon als erledigt darstellen.**
- **DER PINSEL GEHÖRT DEM EINZELNEN ELEMENT, DAS BUCH DEM GANZEN BUCH** (ab
  1.0.49; gemeldet 09/2026: „Bei der Bedienung der App komme ich immer
  durcheinander mit dem Pinsel-Symbol und dem Symbol für die
  Einstellungsmöglichkeiten. Irgendwie habe ich fast sogar das Gefühl, dass
  die beiden Symbole vertauscht sind."). **Sie waren es.** In Pages öffnet
  der Pinsel die Einstellungen des GEWÄHLTEN Elements; hier tat das der
  Schieberegler, und der Pinsel führte in die buchweite Gestaltung. Der Nutzer
  hat also nicht eine fremde Gewohnheit mitgebracht, sondern eine verbreitete
  benannt — und in einer App, die Seiten setzt, ist Pages der Vergleich, den
  jeder im Kopf hat.
  - **Der Tausch allein hätte es nicht gerichtet.** „Ausgewähltes" und
    „Gestalten" sagen beide etwas über die TÄTIGKEIT — und der Unterschied
    zwischen diesen beiden Knöpfen ist nicht die Tätigkeit, sondern der
    GELTUNGSBEREICH. Sie heißen seither **„Auswahl"** (Pinsel) und **„Ganzes
    Buch"** (Buchsymbol), und im Menü steht der Abschnittstitel „Gilt für das
    ganze Buch" darüber. **Merke: Wo zwei Wege dasselbe TUN und sich nur
    darin unterscheiden, WORAUF sie wirken, gehört der Geltungsbereich in
    die Beschriftung und nicht die Tätigkeit.**
  - **Wer eine Beschriftung ändert, zieht die Bedienungskarte mit.** In
    `BedienungView` stand siebenmal „Gestalten (Pinsel)" und „Der Pinsel →" —
    eine Karte, die einen Knopf bei einem Namen nennt, den es nicht mehr
    gibt, ist schlimmer als gar keine. Dasselbe gilt für die Querverweise in
    `GestaltungView`, `BlockInspektor` und der Druckprüfung.
  - **Nicht gemessen:** Ob die Verwechslung damit aufhört, sagt erst der
    nächste Befund. Geändert sind Symbole und Namen, und das ist keine
    Messung — dieselbe Einschränkung wie bei den Menüs in 1.0.20.
- **Die Punktekarte war nicht klein gebaut, sie war ein BLATT IN EINEM
  BLATT** (ab 1.0.49; gemeldet 09/2026: „Zum einen möchte ich die Punkte auf
  der Karte auswählen und merke, dass diese viel zu klein öffnet. Diese Karte
  könnte sich ja tatsächlich über einen großen Teil des Bildschirms
  erstrecken."). `SpurView` ist selbst ein `.sheet`, und auf dem iPad ist ein
  Sheet ein Kärtchen in der Bildschirmmitte; `PunktwahlView` hing als zweites
  daran und konnte damit nie größer werden als das erste. **Dieselbe Lehre
  wie beim Platz-Editor in Tafelbild**, wo der Grundriss aus genau diesem
  Grund ein Drittel der Höhe bekam — dort war sie aufgeschrieben und hier
  nicht gezogen. Ein `fullScreenCover` hängt sich nicht in das Kärtchen,
  sondern über alles.
  - **Die Vorschau oben ist seither ein BILD** (`interactionModes: []`) und
    zugleich der Weg zur Karte: Ein Tipp darauf öffnet die volle. Sie war
    schieb- und zoombar — auf 240 Punkten Höhe in einem Kärtchen ist das
    eine Karte, an der sich nichts machen lässt, und sie schluckte
    ausgerechnet den Tipp, mit dem man die richtige öffnen wollte. Dieselbe
    Regel wie überall: **Was auf einer Karte liegt, ist ein Bild; was etwas
    tut, ist ein Knopf.**
- **PUNKTE, DIE AUS DER LINIE SPRINGEN** (`Dienste/Ausreisser.swift`, ab
  1.0.49; gemeldet 09/2026: „Mein Gerät hat den Standort zuweilen sehr
  ungenau aufgezeichnet und somit sind Punkte mit einer Linie verbunden
  worden, die sehr weit auseinander sind. In diesem Fall sticht die Linie
  sehr hervor, obwohl sie gar nicht dem Reiseverlauf entspricht."). Gegen die
  MESSUNG lässt sich nichts tun — ein GPS-Empfänger zwischen zwei Häuserwänden
  meldet zuweilen eine Stelle einige Kilometer daneben. Gegen die LINIE schon.
  - **Gemessen wird der UMWEG, nicht die Entfernung zum Nachbarn.**
    `hin + zurück − direkt` ist genau das, was der Punkt an zusätzlicher
    Linie KOSTET, also genau der Schaden, um den es geht: Bei einem Sprung
    hin und gleich zurück ist er das Doppelte der Abweichung, bei einer
    Kurve unterwegs fast null. Eine senkrechte Entfernung zur Verbindungslinie
    wäre die naheliegende Alternative, bräuchte eine Projektion in eine Ebene
    (über hundert Kilometer hinweg schief) und brächte im einzigen Fall, um
    den es geht, dasselbe Ergebnis.
  - **Die Schwelle hängt an der SPUR selbst.** Zwei Kilometer sind in einer
    Stadtbesichtigung ein Ausreißer und auf einer Fahrt durch Kanada nichts.
    Verglichen wird gegen den MEDIAN der Schrittweiten dieser Spur — nicht
    gegen den Mittelwert, denn den verderben genau die Ausreißer, die gesucht
    werden. Dazu ein absoluter Boden (1,5 km): Was darunter liegt, sticht auf
    einer Buchseite nicht heraus.
  - **Ein unmögliches TEMPO zählt nur in BEIDE Richtungen.** Über 1200 km/h
    fährt und fliegt nichts; ein echter Linienflug ist aber auch schnell, und
    er unterscheidet sich vom Messfehler genau darin, dass er nicht in
    derselben Minute zurückkommt. Fehlt eine der beiden Uhrzeiten, heißt das
    „weiß ich nicht" und nicht „ja" — ein Handpunkt ohne Zeit darf nicht
    auffällig werden, bloß weil er keine trägt.
  - **Der erste und der letzte Punkt werden nicht geprüft**, und das steht
    auch da: Ein Ausreißer wird an seinen NACHBARN erkannt, und die beiden
    haben nur einen. Geraten wird nichts.
  - **GELÖSCHT WIRD NICHTS VON SELBST.** Ein Abstecher zum Aussichtspunkt und
    zurück sieht von außen genauso aus wie ein Messfehler, und welcher von
    beidem es war, weiß nur, wer dabei war. Der Abschnitt über der Punkteliste
    nennt Stelle, Namen und die zusätzliche Linie in Kilometern und bietet
    zweierlei an: alle auf einmal entfernen (mit Rückfrage) oder nur
    auswählen und einzeln ansehen — Letzteres über den Auswahlmodus, den es
    seit 1.0.21 gibt. **Kein zweiter Weg zu derselben Sache.**
  - **Markiert wird an DREI Stellen** — in der Punkteliste, auf der kleinen
    Vorschau und auf der großen Karte —, und immer mit Zeichen UND Farbe: Ein
    farbfehlsichtiger Mensch sieht Orange allein nicht. Auf der großen Karte
    steht unter dem gewählten Punkt im Klartext, warum er auffällt; ein
    Zeichen ohne Erklärung ist ein Rätsel.
  - **Gerechnet wird in `.task(id:)`, nicht als berechnete Eigenschaft.** Der
    Lauf geht über jeden Punkt und misst je drei Entfernungen; der Körper
    dieser Ansichten läuft bei jeder Meldung des Werks und bei jeder
    Kamerabewegung noch einmal. Vierte Auflage derselben Falle — **eine
    berechnete Eigenschaft sieht billig aus.**
- **Nicht gemessen (1.0.49):** Keine Spur ist damit angesehen worden. **Alle
  drei Zahlen der Ausreißererkennung sind GEWÄHLT und nicht gemessen** (Boden
  1,5 km, Faktor 8 auf den Median, 1200 km/h) — ob sie an der Spur des Nutzers
  das Richtige treffen, sagt erst sein nächster Befund, und weil die App die
  Zahlen hinschreibt, sagt er es mit Zahlen. Gerechnet ist, warum die Karte
  nicht größer werden konnte (ein Sheet in einem Sheet); gesehen hat es
  niemand. **Zwei aufeinanderfolgende Ausreißer kann diese Erkennung nicht
  trennen** — der zweite ist der Nachbar des ersten, und dann ist der Umweg
  klein; das nicht als gelöst darstellen. **Nicht als erledigt darstellen.**
- **Nicht gemessen (1.0.48):** Keine Seite ist damit gesetzt worden, und
  **an der Vorlage des Nutzers ist die Erkennung nicht gelaufen** — die
  Datei liegt hier nicht. Gerechnet ist, warum Kürze in beiden Textsorten
  ein Merkmal ist; **gewählt und nicht gemessen** sind alle vier Zahlen (42
  Zeichen, sechs Wörter, 58 % der Titelgröße, Zeilenabstand 1,18). Ob die
  zweite Ebene auf der gedruckten Seite als solche zu lesen ist und ob die
  Erkennung an seinem Tagebuch trifft, sagt erst der nächste Befund — und
  seit 1.0.48 sagt er es mit einer Zahl in der Vorschau. **Nicht als
  erledigt darstellen.**
- **Nicht gemessen (1.0.47):** Keine Doppelseite ist damit gesehen worden.
  Gerechnet ist die Geometrie — dass die Fläche zwei Endformate plus zwei
  Anschnitte misst und der Versatz eine halbe Seitenbreite beträgt.
  **Ungeprüft ist, ob der Bund im gedruckten Buch etwas verschluckt**: Ein
  Hardcover verschwindet in der Bindung, und wie viel, sagt der Druckdienst
  und nicht diese App — wer ein Gesicht genau in den Bund legt, verliert es
  möglicherweise. Der Bundsteg (seit 1.0.1) schiebt den SATZ davon weg, das
  Bild nicht. **Nicht als erledigt darstellen.**
- **Die Bildunterschrift war halb gebaut** (ab 1.0.5, Wunsch des Nutzers
  09/2026: „zu jedem Foto einen Beschreibungstext … Dies soll jedoch eine
  Option für jedes Foto sein. Kein muss."). Der Layoutautomat hielt Platz
  für sie frei, das PDF zeichnete sie — auf dem Bildschirm erschien sie nie,
  und anfassen ließ sie sich gar nicht. Sie ist jetzt ein eigener Block
  (`Blockinhalt.bildunterschrift`), also verschiebbar, drehbar und in der
  Größe zu ziehen; der TEXT steht weiter am Foto und reist mit ihm mit —
  dieselbe Überlegung wie bei Überschrift und Datumszeile, die am Tag
  stehen. **Der Kommentar über `Blockinhalt` behauptete das Gegenteil und
  ist gestrichen.** Eingeschaltet wird je Foto (`Foto.unterschriftZeigen`),
  im Inspektor oder mit dem Sprechblasen-Knopf in der Fotoliste; was aus
  ist, kostet auch keinen Platz im Satz. **Der Text bleibt beim Abschalten
  stehen**, und beim Einlesen eines älteren Buches gilt eine nicht leere
  Unterschrift als eingeschaltet — sonst nähme eine neue Fassung
  stillschweigend Arbeit weg, die jemand gemacht hat. Schrift, Größe und
  Farbe stehen einmal für alle unter der Rolle „Bildunterschrift".
  **Gefunden hat den Weg dorthin aber niemand** (gemeldet 09/2026: „Ich habe
  noch nicht gefunden, wie ich eine Unterschrift unter ein Bild setzen
  kann."): Der Schalter stand im Inspektor hinter dem Abschnitt „Foto" und in
  der Fotoliste des Tages — beides Wege, die man kennen muss. Seit 1.0.6 gibt
  es zwei, die man nicht kennen muss: ein **Doppeltipp auf das Foto**
  (`unterschriftOeffnen` — derselbe Griff wie beim Text, man tippt zweimal auf
  das, was man beschriften will) und bei gewähltem Foto der Knopf
  **„Bildunterschrift"** unten in der Leiste. Eine Geste, die niemand kennt,
  ist so wenig wert wie ein Knopf, den niemand findet — deshalb beides.
  **Ein Knopf, den niemand findet, ist kein Knopf — und das gilt auch für
  einen Schalter in einem Formular.**
  **Sie gehört zur Reihe wie das Bild selbst**: `restplatzVerteilen` schiebt
  die Reihen auseinander, und eine Unterschrift, die dabei liegen bliebe,
  stünde plötzlich im Bild darüber.
- **Text wird auf der SEITE geändert, nicht im Inspektor** (`InlineText`,
  Doppeltipp). Ein `UITextView` mit denselben Attributen an derselben
  Stelle — getippt wird in der Schrift, in der gedruckt wird. Wohin der Text
  zurückgeschrieben wird, hängt an der Blockart: Fließtext in den Block,
  Überschrift und Datumszeile an den TAG. In den Block geschrieben wäre die
  Änderung beim nächsten Neuanordnen weg.
- **Die Datumszeile ist einstellbar** (`Datumsstil`, sieben Fassungen, plus
  `Reisetag.datumstext` je Tag). Sie stand fest auf „Donnerstag, 4. Juni
  2026".
- **Seitenhintergründe global UND je Seite** (`Model/Seitenhintergrund.swift`):
  einfarbig, Verlauf, Foto mit Schleier, Papierkorn. Genau diese Reihenfolge
  — das Buch hat einen Hintergrund, eine einzelne Seite darf einen anderen
  haben. Ein Hintergrund läuft IMMER bis in den Anschnitt; eine Fläche, die
  am Endformat aufhört, hätte nach dem Beschneiden den weißen Faden, wegen
  dem es den Anschnitt gibt. Ob die Schrift hell werden muss, wird über die
  wahrgenommene Helligkeit GERECHNET.
- **Der Restplatz wird verteilt, nicht unten liegen gelassen**
  (`restplatzVerteilen`). Eine Seite trug drei Fotos in einer Reihe und
  darunter die halbe Seite Weiß. Höher kann eine randbündige Reihe nicht
  werden — ihre Höhe ist die Satzbreite geteilt durch die Summe der
  Seitenverhältnisse, das ist Geometrie und keine Einstellung. Was geht, ist
  die Lücken zwischen den Reihen zu strecken, gedeckelt auf das Dreifache
  der Fuge: Luft zwischen den Reihen sieht nach Absicht aus, Luft am Fuß
  nach Abbruch. **Die eigentliche Antwort darauf sind Seitenvorlagen mit
  Platzhaltern** (drei Fotos als eines groß plus zwei gestapelt) — die
  stehen noch aus.
- **Gedreht wird um die MITTE, und der Winkel kommt aus dem Zeiger** von der
  Mitte zum Finger, nicht aus der Wegstrecke. Eine Drehung aus der
  Verschiebung dreht am Rand schneller als in der Mitte und fühlt sich
  sofort falsch an. Bei Vielfachen von 45 Grad rastet sie ein: Ein Bild, das
  um 0,4 Grad schief steht, sieht nicht gewollt aus, sondern nach einem
  Versehen.

### Karten: Quelle, Helligkeit und Lizenz (ab 1.0.3)

- **Hell oder dunkel entscheidet das BUCH, nicht das iPad** (gemeldet
  09/2026: „Die Landkarten sind von Apple Karten in der dunklen Ansicht.").
  Bis 1.0.2 stand über der Helligkeit gar nichts, und damit nahm
  `MKMapSnapshotter` die Erscheinung des Systems an: Wer abends am dunkel
  geschalteten iPad arbeitete, bekam eine schwarze Karte ins gedruckte Buch.
  Das ist kein Geschmack, sondern ein Fehler — eine Druckvorlage darf nicht
  davon abhängen, wie hell es im Zimmer war. Gesetzt wird
  `MKMapSnapshotter.Options.traitCollection`; die Vorgabe ist **hell** und
  nicht `wieApp`. Wer `wieApp` wählt, bekommt einen Warnhinweis daneben.
  **Nicht gemessen**: ob `traitCollection` auf einem echten Gerät wirklich
  greift — das zeigt erst ein Ausdruck. Der Weg daneben ist eine
  Kachelquelle, die ohnehin immer hell ist.
- **Vier Quellen** (`Model/Kartenbild.swift`, `Dienste/Kachelkarte.swift`,
  ab 1.0.3, Ansage des Nutzers 09/2026: „auf andere Kartenanbieter wie
  OpenStreetMap oder andere zurückgreifen"). Apple Karten, OpenStreetMap,
  OpenTopoMap und ein eigener Kachelserver. Alles am 21.09.2026 gemessen:
  `tile.openstreetmap.org` und `tile.opentopomap.org` antworten ohne
  Schlüssel mit 256-px-PNG (`max-age=16144` bzw. `604800`); OpenTopoMap
  rendert bis Zoomstufe 17.
- **Carto ist NICHT gebaut, und der Grund steht hier.**
  `basemaps.cartocdn.com` antwortete zwar ohne Schlüssel (auch mit `@2x`,
  also 512 px — das wäre für den Druck das Beste gewesen), aber Carto
  verlangt seit 2026 einen API-Schlüssel und deckelt bei fünf Millionen
  Kacheln im Monat. **Ein Schlüssel in einer App ist keiner** — dieselbe
  Regel wie in der Abfahrtstafel. Wer einen eigenen holt, trägt ihn über
  „Eigener Kachelserver" ein; dafür ist der Weg da.
  `maps.wikimedia.org` antwortete mit 403.
- **Die Nutzungsrichtlinie der OSM Foundation ist gelesen, nicht vermutet**
  (abgerufen 21.09.2026). Drei Dinge sind daraus Pflicht: ein eigener
  User-Agent (Anfragen mit der Vorgabe einer Bibliothek werden ausdrücklich
  gesperrt — es steht der Name der App darin und eine Adresse, **nie die
  E-Mail des Nutzers**), ein Zwischenspeicher, der die Verfallszeiten des
  Servers achtet (`URLCache`, 256 MB), und ein Deckel (48 Kacheln je Karte;
  darüber sinkt die Auflösung). **Verboten ist das Vorausladen** („bulk
  downloading", „offline use") — einen Knopf, der eine Gegend im Voraus
  holt, gibt es deshalb nicht und darf es nicht geben.
- **Der Lizenzhinweis wird IN das Bild gezeichnet** und ist nirgends
  abschaltbar. Ein Hinweis als eigener Textblock ließe sich verschieben,
  überdecken oder löschen — und stünde dann nicht mehr da, wenn das Buch
  beim Drucker liegt. OpenTopoMap nennt den Wortlaut ausdrücklich
  („Kartendaten: © OpenStreetMap-Mitwirkende, SRTM | Kartendarstellung:
  © OpenTopoMap (CC-BY-SA)"), OSM verlangt ihn sichtbar und nicht hinter
  einem Schalter.
- **CC-BY-SA heißt auch Share-alike, und das gehört gesagt.** Der
  Herausgeber von OpenTopoMap beantwortet die Frage nach dem gedruckten
  Wanderführer mit Ja und ohne Gebühren — verlangt aber, dass die
  abgedruckte Karte unter denselben Bedingungen weitergegeben werden darf.
  Für ein Familienbuch im Schrank folgenlos, für eine Auflage nicht.
- **Entschieden wird an der QUELLE, nicht an der Adresse.** Eine eigene
  Quelle ohne Adresse fiele sonst stillschweigend auf Apple zurück, und der
  Nutzer hielte seinen Kachelserver für einen, der genau so aussieht. Ohne
  Adresse UND ohne Lizenzhinweis gilt die Quelle als unvollständig und die
  Karte bleibt leer — mit einer Zeile, die das sagt.
- **Erst das Mosaik, dann verkleinern** (`Kachelkarte`). Jede Kachel einzeln
  in das verkleinerte Bild zu zeichnen wäre der naheliegende Weg und
  hinterließe an jeder Kachelgrenze einen hellen Haarstrich: Die Ränder
  lägen auf gebrochenen Bildpunkten, und die Glättung rechnet dort mit dem
  weißen Grund.
- **Der Maßstab des Kartenbildes steht FEST auf 2.**
  `UIGraphicsImageRenderer` nähme sonst `UIScreen.main.scale` — und dann
  hinge die Auflösung der gedruckten Karte daran, auf welchem Gerät das Buch
  gerade offen war.
- **Eine leere Kartenfläche hat zwei Gründe, und sie verlangen verschiedene
  Handgriffe**: noch keine Punkte, oder die Karte ließ sich nicht holen.
  Beides gleich aussehen zu lassen wäre ein stummer Befund.
- **Die Karten in Ortswahl und Spurliste bleiben Apples Live-Karten** in der
  Erscheinung der App. Sie sind Werkzeug, nicht Erzeugnis; die Einstellung
  gilt dem gedruckten Bild. Wer das ändert, ändert es für beide.

### Abgleich, Austausch und Tagesspur (ab 1.0.4)

- **Der Abgleich läuft über iCloud DRIVE, nicht über CloudKit** (`Dienste/Wolke.swift`,
  Ansage des Nutzers 09/2026: „über iCloud mit anderen Geräten synchronisieren
  und dies bitte automatisch"). Ein Buch ist eine kleine JSON-Datei und
  zweihundert große Bilder — genau dafür ist ein Dateiabgleich gebaut: Er lädt
  eine Datei erst herunter, wenn sie gebraucht wird, und überträgt ein Bild
  nicht noch einmal, weil im Text ein Komma anders steht. Eine eigene
  Synchronisierung müsste all das nachbauen; wie viel das ist, steht in diesem
  Papier unter Tafelbild, wo sie GEBAUT ist. **Nicht auf CloudKit umstellen,
  ohne diesen Absatz zu widerlegen.**
- **`url(forUbiquityContainerIdentifier:)` BLOCKIERT** und beim ersten Aufruf
  spürbar lange — Apple sagt das ausdrücklich. Es läuft deshalb einmal beim
  Start abseits des Hauptfadens (`Wolke.vorbereiten`), und bis die Antwort da
  ist, arbeitet die App örtlich weiter. Es darf NICHT in einen `init`.
- **`Wolke.wurzel` ist die einzige Stelle, die weiß, wo ein Buch liegt.**
  `Ablage` und `Bildarchiv` fragen dort; zwei Meinungen darüber wären zwei
  Ablagen, und die Bilder lägen auf dem Gerät, während das Buch in der Wolke
  steht.
- **Das Regal HORCHT, statt zu fragen** (`NSMetadataQuery` in `Regal.beobachten`).
  Das ist der Unterschied zwischen „abgeglichen" und „abgeglichen, sobald
  jemand die App neu startet". Zwei Sekunden Ruhe zwischen den Meldungen, sonst
  baut sich das Regal während einer Übertragung zwanzigmal neu auf. **Wer den
  Abgleich in den Einstellungen einschaltet, startet den Beobachter mit**
  (`Regal.wolkeGewechselt`) — sonst liefe er erst nach dem nächsten Start, und
  das sieht aus wie ein Abgleich, der nicht läuft.
- **Konflikte werden nach dem `geaendert` IM BUCH entschieden**, nicht nach dem
  Zeitstempel der Datei. Zwei Gründe: Beim Kopieren bekommt eine Datei ohnehin
  einen neuen, und die Dateizeit steht auf Apples Liste der
  begründungspflichtigen Schnittstellen (dieselbe Lehre wie bei Schulalarms
  Tonbefund). **Die unterlegene Fassung wird NICHT überschrieben**, sondern
  bleibt als `<Kennung>-konflikt-<Zeit>.json` liegen und steht in den
  Einstellungen mit „Diese Fassung nehmen" und „Verwerfen". Ein Abgleich, der
  stillschweigend einen Abend Arbeit wegnimmt, ist schlimmer als zwei Bücher,
  die man vergleichen muss. `Ablage.alle()` überspringt diese Dateien — im
  Regal wären zwei gleich heißende Bücher die schlechtere Art, dasselbe zu
  sagen.
- **Umschalten KOPIERT und löscht nichts**, in beiden Richtungen. Wer
  zurückschaltet, findet seine Bücher auf dem Gerät vor; wer sich vertan hat,
  hat nichts verloren. Ein Buch doppelt ist besser als eines weniger.
- **Ohne iCloud-Recht bleibt die App örtlich und SAGT es.** Fehlt das
  Entitlement oder ist niemand angemeldet, gibt iOS keinen Behälter heraus;
  dann wird der Wunsch zurückgenommen und der Grund genannt. Kein Absperren —
  dieselbe Regel wie bei Schulalarms Mitteilungen.
- **`NSUbiquitousContainers` macht den Ordner SICHTBAR** (Info.plist). Ohne die
  drei Schlüssel läge er versteckt im Behälter, und niemand käme an seine
  Bücher heran, wenn die App einmal nicht mehr da ist. Eine Ablage, die man nur
  mit der App wieder aufbekommt, ist bei einem Tagebuch die falsche.
- **Das Entitlement kann diesen Bau nicht prüfen.** `CODE_SIGN_ENTITLEMENTS`
  steht seit 1.0.4 im pbxproj; GitHub Actions baut mit
  `CODE_SIGNING_ALLOWED=NO` und sieht es nie an. Ob sich signieren lässt,
  entscheidet sich auf dem Mac — und dafür muss die App-Id in der
  Entwicklerkonsole iCloud können und der Behälter
  `iCloud.de.familie.urlaubstagebuch` existieren (in Xcode: Signing &
  Capabilities → + iCloud → iCloud Documents). **Einen grünen Bau nie als
  „signierbar" ausgeben** — dieselbe Regel wie bei Schulalarm.
- **Das Austauschformat ist SELBST geschrieben** (`Dienste/Buchdatei.swift`,
  Endung `.reisebuch`). Zum PACKEN eines ZIP gibt es auf iOS einen
  halböffentlichen Weg (`NSFileCoordinator` mit `.forUploading`), zum
  ENTPACKEN gar keinen. Ein Format, das sich schreiben, aber nicht lesen lässt,
  ist kein Austauschformat, und eine fremde Bibliothek wäre die erste
  Abhängigkeit dieser App. Aufbau: 11 Bytes Kennung, 4 Bytes Kopflänge,
  JSON-Kopf (die Reise plus die Bilderliste mit Längen), dann die Bilddateien
  unverändert hintereinander.
- **Geschrieben wird stückweise, gelesen speicherabgebildet.** Ein Buch mit
  zweihundert Fotos wiegt ein Gigabyte und gehört nicht am Stück in den
  Arbeitsspeicher. Und nach der Dateigröße wird über `resourceValues(forKeys:
  [.fileSizeKey])` gefragt und nicht über `attributesOfItem` — Letzteres liest
  die Zeitstempel mit (ITMS-91053).
- **Erst nachsehen, dann übernehmen.** `Buchdatei.pruefen` sagt, was in der
  Datei steht und ob sie ein vorhandenes Buch überschreiben würde; erst danach
  fragt die App „Ersetzen oder als Kopie". Ein Einlesen, das gleich losschreibt,
  hat keinen Rückweg.
- **Die Tagesspur-Einfuhr liest beide Formate** (`Dienste/Spureinfuhr.swift`,
  Ansage des Nutzers 09/2026: „Ich sehe bislang noch keine Importfunktion für
  Daten aus der Tagesspur-App"). Fotos bringen den Ort mit, an dem jemand stand
  und abgedrückt hat; die Tagesspur kennt den Weg dazwischen.
- **Auch hier kommt der Tag aus DREI ZAHLEN.** Die JSON-Sicherung trägt je Tag
  einen `dayKey` (`2026-07-25`) in der Zeitzone der Aufzeichnung — der Tag, den
  der Mensch erlebt hat, und damit die beste Angabe, die es gibt. Im GPX steht
  derselbe Schlüssel vorn im Spurnamen (`2026-07-25 – iPhone`), und genau
  deshalb wird er dort ABGELESEN und nicht gerechnet. Nur bei einer fremden
  GPX-Datei bleibt die Umrechnung; dann ist die Zeitzone wählbar, und der
  Befund nennt die Zahl der betroffenen Tage. Gesucht wird der Schlüssel nur am
  ANFANG des Namens — „Wanderung am 12.08." ist keiner (dieselbe Falle wie beim
  Textimport).
- **Ein Aufenthalt wird NIE ausgedünnt.** Er trägt einen Namen, und einen
  benannten Ort wegzurechnen, weil er nah am vorigen liegt, nähme genau die
  Angabe weg, für die es ihn gibt. Ausgedünnt wird nur die Strecke, mit
  derselben Regel wie bei den Fotos (`Spurbau.ausgeduennt` — seit 1.0.4 eine
  eigene Funktion, die auch `punkteAusFotos` benutzt; zwei Fassungen desselben
  Ausdünnens liefen auseinander).
- **`Ortsquelle.tagesspur` zählt NICHT als Fotopunkt.** „Aus den Fotos neu
  bauen" lässt solche Punkte stehen — sie sind ausdrücklich eingelesen worden
  und kämen aus keinem Bild zurück. Ein erneutes Einlesen desselben Tages
  ERSETZT sie dagegen: Wer eine Sicherung zweimal wählt, soll nicht die
  doppelte Spur bekommen.

### Ein Tagebuch muss eine neue Fassung überleben (ab 1.0.3)

- Swift baut den Leser einer `Codable`-Struktur selbst — und der verlangt
  JEDEN Schlüssel, **auch wenn die Eigenschaft einen Vorgabewert hat**. Ein
  neues Feld macht damit jede vorher gesicherte Datei unlesbar. Bei einem
  Reisetagebuch ist das der teuerste denkbare Fehler: Es gibt keine zweite
  Ausfertigung. `Reise` und `Reisetag` lesen sich deshalb seit 1.0.3 von
  Hand über `Model/Nachsicht.swift`. Dieselbe Lehre wie bei Anstoß
  („Ablagen müssen Modelländerungen überleben") — dort war sie
  aufgeschrieben und hier nicht gezogen.
- **Die Nachsicht ist GESTAFFELT und deckt damit auch die Typen darunter
  ab.** Ändert sich `Block`, `Seite`, `Gestaltung` oder `Typografie`, fällt
  in `Reisetag` bzw. `Reise` nur das eine Feld auf seinen Vorgabewert
  zurück: Die Seiten eines Tages sind dann leer, und
  `fehlendeSeitenNachholen()` setzt sie beim Öffnen neu. Die Gestaltung
  kostet eine Einstellung, der Inhalt bleibt. **Was NICHT abgedeckt ist**:
  ein Tag ohne `datum` — der reißt die ganze Tagesliste mit. Der Schlüssel
  steht seit 1.0.0 in jeder Datei; wer ihn antastet, baut vorher eine
  nachsichtige Liste.
- **Ein alter Schlüssel wird weiter GELESEN, auch wenn es die Eigenschaft
  nicht mehr gibt** (`AlteSchluessel` in `Model/Reise.swift`). Bis 1.0.2
  hieß die Karteneinstellung `kartenstil` und kannte nur Apples vier Stile;
  sie wird beim Lesen ins neue `kartenbild` gehoben und danach nicht mehr
  geschrieben. Ohne das verlöre jedes Buch von damals seine Einstellung.

- `MARKETING_VERSION` und `CURRENT_PROJECT_VERSION` stehen an je zwei
  Stellen im pbxproj (Debug + Release) — es gibt KEINE Skript-Bauphase.
  **Jede Arbeitseinheit hebt Patch- UND Build-Nummer um je +1**, ohne
  Nachfrage, als Teil des PRs. Zählung ab 09/2026: 1.0.0 (Build 1), dann
  1.0.1 (Build 2) usw. — Stand 09/2026: 1.0.85 (Build 86). Dazu gesetzt:
  `DEVELOPMENT_TEAM = F4989GSTWS` und
  `INFOPLIST_KEY_LSApplicationCategoryType = public.app-category.travel`.
  Seit 1.0.4 steht dort auch `CODE_SIGN_ENTITLEMENTS = Config/Urlaubstagebuch.entitlements`
  (iCloud Documents, seit 1.0.66 wieder `com.apple.developer.user-fonts`
  mit den vom Profil bewilligten Werten)
  — nicht entfernen, sonst liegt der Abgleich still und die selbst
  installierten Schriften bleiben unsichtbar.
- `ITSAppUsesNonExemptEncryption = NO` steht in `Config/Info.plist` UND als
  Build-Einstellung — nicht entfernen.
- Das App-Symbol rechnet `UrlaubstagebuchiOS/scripts/make-icon.py` (reines
  Python, ohne fremde Bibliotheken) — nicht von Hand bearbeiten.
- **Offen: Ob die Schriften im PDF ankommen, ist nicht gemessen.** Der Text
  wird als Text gesetzt; ob iOS eine Systemschrift einbettet oder nur
  benennt, lässt sich erst an einem echten Ausdruck sehen. **Nicht als
  erledigt darstellen.** Ebenso ungemessen: wie sich ein Buch mit
  zweihundert Fotos anfühlt.
- Übersetzt wird in GitHub Actions (`.github/workflows/ios-apps-build.yml`,
  Eintrag `("UrlaubstagebuchiOS", "Urlaubstagebuch")` in `welche-apps.py`).
  **Erst pushen, Bau abwarten, Fehler beheben — den PR-Link erst
  herausgeben, wenn der Bau grün ist.**

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
- **Termine lassen sich vor dem Sichern ändern** (Blatt `#blatt` in
  `index.html`, `blattOeffnen` in `js/app.js`): Text, Datum, Enddatum,
  Uhrzeiten; dazu „+ Termin hinzufügen" und je übergangener Zeile „Als Termin
  übernehmen" — Letzteres ist der Ausweg für Zeilen, in denen im Dokument nur
  der Tag fehlt (`.03.2027 Personalversammlung`, echter Fall 09/2026).
  **Die Beschreibung ist ein KNOPF** (`.zeilenknopf`, gepunktet unterstrichen,
  mit Stift dahinter) — dieselbe Lehre wie beim Gruppenchat in Schulalarm: Ein
  Knopf, den niemand findet, ist kein Knopf.
- **Die App ist installierbar** (`manifest.webmanifest`, `sw.js`, `icons/`).
  Der Service Worker fragt IMMER erst beim Server nach und greift nur ohne
  Netz auf den Zwischenspeicher zurück; **`FASSUNG` in `sw.js` bei jeder neuen
  Fassung hochzählen**. Die Icons rechnet `scripts/generate-icons.py` (reines
  Python, ohne fremde Bibliothek) — PNG ohne Alphakanal, sonst legt iOS das
  Homescreen-Icon auf Schwarz, und für den Homescreen liest iOS das Manifest
  nicht zuverlässig, sondern `apple-touch-icon`.
- **`einzeldatei.html` ist ERZEUGT** (`scripts/einzeldatei.py`) und muss nach
  jeder Änderung an HTML, CSS oder JavaScript neu gebaut werden — sonst hängt
  die Fassung für den Doppelklick hinterher. Sie ist der Weg auf einen
  Windows-Rechner ohne Webserver: ES-Module weist jeder Browser bei `file://`
  ab, deshalb liegt dort alles in EINER Datei. Jedes Modul bekommt einen
  eigenen Geltungsbereich; ein blosses Aneinanderhängen scheitert, weil `zwei`
  sowohl in `ics.js` als auch in `app.js` steht. **Eine `.exe` gibt es mit
  Absicht nicht** (150 MB Electron um 60 KB App, SmartScreen-Warnung ohne
  Signatur, zweiter Aktualisierungsweg) — Edge und Chrome installieren die
  Seite selbst als Programm mit Startmenü-Eintrag.
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
- **Aus einer `.docx` werden nur die TABELLEN gelesen** (`js/docx.js`), nicht
  der Fließtext: Wer Termine in Tabellen notiert, hat davor und dazwischen
  Anrede, Erklärungen und Grußformel — die alle als „übergangene Zeile" zu
  melden, wäre lauter Lärm. Erst ein Dokument ganz ohne Tabelle lässt seine
  Absätze durchsehen. Die Vorsilbe `w:` wird beim Vergleichen abgeschnitten,
  und eine verschachtelte Tabelle wird zu eigenen Zeilen — ihr Text landet
  nicht zusätzlich in der Zelle, die sie enthält.
- **Kopfzeilen werden an jeder Stelle erkannt, nicht nur ganz oben**
  (`istKopfzeile`): Ein Word-Dokument bringt mehrere Tabellen mit, und jede
  hat ihre eigene Überschrift. Eine echte Terminzeile trägt ein Datum und
  kommt an dieser Prüfung nie an.
- **Gesucht wird die Datumszelle, nicht die erste Spalte.** Welche Spalte
  links steht, ist dadurch gleich. Zeilen ohne erkennbares Datum werden
  nicht still verschluckt, sondern als „Übergangene Zeilen" angezeigt — eine
  stillschweigend fehlende Zeile im Kalender fällt erst auf, wenn der Termin
  vorbei ist.
- Eine Uhrzeit in der Beschreibung wird nur mit Doppelpunkt oder dem Wort
  „Uhr" (bzw. „h") übernommen. „3.45" in einem Text ist meist eine Zahl und
  keine Viertel vor vier. **Die Zeitspanne wird VOR den Einzelzeiten
  geprüft** (`ZEITSPANNE` vor `EINZELZEIT`): „9-15.30 Uhr" ist eine Angabe,
  keine zwei — und „11.00 Uhr" ergab ohne die Punktform in der Einzelsuche
  einmal 00:00 Uhr, weil nur „00 Uhr" passte (gefunden 09/2026 an einer
  echten Jahresplanung).
- **Zeiträume in Kurzform sind der Regelfall in Schulplänen**: `12.-14.10.2026`,
  `10./11.07.2027`, `17.10.- 31.10.2026`, `14.09.-25.09.2026`. Sie werden VOR
  `TT.MM.JJJJ` geprüft, sonst frisst die einfache Regel das zweite Datum und
  der Anfangstag geht verloren. Fehlt beim ersten Datum das Jahr, gilt das des
  zweiten — bei größerem Monat um eins zurück (`28.12.-04.01.2027` beginnt
  2026). Gefundene Daten werden am Ende chronologisch sortiert: „Ab 07.09. bis
  zum 18.09.2026" nennt das vollständige Datum hinten.

## Projekt Textauszug (Web-App, PDF → Text)

- Code: `textauszug/` — statische Web-App ohne Bauschritt (ES-Module, kein
  Framework, keine fremde Bibliothek), wird vom Pages-Arbeitsablauf mit
  ausgeliefert: https://katonid.github.io/prae/textauszug/
  Holt den reinen Text aus einer PDF und schickt ihn in die Notizen.
  Ausführlich: `textauszug/README.md`. Gebaut nach demselben Muster wie der
  Terminkonverter (Manifest, `sw.js` mit `FASSUNG`, `scripts/generate-icons.py`,
  `scripts/einzeldatei.py` — alle vier Punkte gelten hier genauso).
- **Der PDF-Leser ist selbst geschrieben** (`js/pdf.js`, `js/schrift.js`,
  `js/inhalt.js`), der PDF-SETZER ebenfalls (`js/pdfbauen.js`). Keine Bibliothek nachladen: Das bräche Offlinebetrieb und
  Datensparsamkeit — und pdf.js allein wiegt mehr als diese ganze App.
- **Das Querverweis-Verzeichnis am Ende der PDF wird ABSICHTLICH nicht
  gelesen.** Es ist die Stelle, die in freier Wildbahn am häufigsten kaputt ist
  (abgeschnittene Downloads, Werkzeuge, die falsche Stellen schreiben), und
  eine PDF mit falschem Verzeichnis öffnet jeder Betrachter trotzdem. Gesucht
  wird die ganze Datei nach „N G obj" ab; die HINTERSTE Fassung eines Objekts
  gewinnt (PDFs werden fortgeschrieben). Objektströme (`/ObjStm`, seit PDF 1.5
  der Regelfall) werden zusätzlich ausgepackt — ohne sie fehlen Katalog,
  Seiten und Schriften.
- **Ein PDF kennt keine Zeilen und keine Wörter**, nur „setze diese Zeichen an
  diese Stelle". Beides wird aus den STELLEN zurückgerechnet
  (`zeilenBauen` in `js/inhalt.js`): gleiche Höhe = eine Zeile, Lücke > ein
  Fünftel der Schrifthöhe = Leerzeichen. Dafür werden die Zeichenbreiten
  (`/Widths`, `/W`, `/DW`) gelesen — ohne sie käme der Text ohne Leerzeichen
  an. Eine große Vorrückung in einem `TJ`-Feld IST ein Leerzeichen: Viele
  Erzeuger schreiben nie eines.
- **Welcher Buchstabe hinter einer Zeichennummer steckt, sagt `/ToUnicode`** —
  sonst die Kodierung samt `/Differences`, zuletzt WinAnsi. Ohne diesen Schritt
  wird aus „für" Buchstabensalat. Bei einer Type0-Schrift ohne `/ToUnicode`
  wird NICHTS geraten (`zuText` gibt leer zurück): Zwei-Byte-Codes ohne Tabelle
  ergeben zufällige Zeichen, und ein falscher Text ist schlimmer als ein
  fehlender.
- **Der senkrechte Abstand wird am ZEILENABSTAND DER SEITE gemessen, nicht an
  der Schriftgröße** (`zeilenabstand` in `js/aufbereiten.js`, gefunden 09/2026
  an „Caesar und Zombie"). Ein Kinderbuch setzt 16 Punkt Schrift mit 37 Punkt
  Zeilenabstand; an der Schrift gemessen war dort JEDE Zeile ein eigener
  Absatz, und aus einem Kapitel wurden 300 Einzeiler. Dieselbe Schätzung
  (unteres Viertel der Abstände) dient der Kopfzeilenerkennung — zwei
  Fassungen liefen garantiert auseinander.
- **Sechs Kilobyte, die mit „<!DOCTYP" anfangen, sind eine WEBSEITE**
  (`webseitenbefund` in `js/pdf.js`, gemeldet 09/2026). Der häufigste Fall hinter
  einem misslungenen Download: Hinter dem Link steht eine Anmeldung, eine
  Fehlerseite oder eine Vorschau, und gesichert wird deren HTML — mit `.pdf` im
  Dateinamen. „Der Kopf '%PDF-' fehlt" ist dann wörtlich richtig und als Auskunft
  wertlos. Genannt wird deshalb der `<title>` der Seite („Anmeldung erforderlich",
  „404") — er sagt in fünf Wörtern, was los ist — und der Weg drumherum: die PDF
  im Browser wirklich öffnen, dann Teilen → „In Dateien sichern". Der Titel wird
  als UTF-8 entziffert, nicht als latin1; und unter einem Kilobyte zählt die
  Meldung Bytes statt „0 KB".
- **Die Gegenrichtung: aus Text wird eine PDF** (`js/pdfbauen.js`,
  `js/schriftmasse.js`, `js/winansi.js`, ab 09/2026 auf Wunsch des Nutzers).
  „Eigenen Text einsetzen" öffnet ein leeres Feld; alles dahinter ist dasselbe
  wie beim Lesen einer PDF — dieselben Blöcke, dieselbe EPUB, derselbe Satz.
  Eine `.txt` darf man auch ins Fenster ziehen.
- **Es gibt genau DREI Schriften, und das ist eine Entscheidung** (Helvetica,
  Times, Courier — je vier Schnitte). Nur diese Familien bringt jedes
  PDF-Programm mit; damit muss **keine Schrift eingebettet** werden: Die Datei
  bleibt bei ein paar Kilobyte statt einem halben Megabyte, öffnet überall
  gleich und braucht keine Lizenz für die Weitergabe. Wer eine vierte Schrift
  anbietet, trägt eine Schriftdatei ins Repo und in jede erzeugte PDF. **In der
  EPUB ist die Schrift ohnehin nur ein Vorschlag** — dort entscheidet das
  Lesegerät, und das ist der Sinn des Formats, keine Lücke.
- **Ein PDF bricht keine Zeile um — wer setzt, muss messen.**
  `js/schriftmasse.js` ist ERZEUGT (`scripts/schriftmasse.py`) und hält die
  Vorschubbreiten aller zwölf Schnitte. Gewonnen werden sie aus den
  Liberation-Schriften des Bau-Rechners, die maßgleich mit Arial, Times New
  Roman und Courier New sind — und die wiederum mit den Standardschriften. Das
  Skript prüft jeden Schnitt gegen Adobes Originalwerte (Helvetica: Leerzeichen
  278, A 667, a 556, m 833) und bricht bei Abweichung ab: Eine falsche Breite
  sähe man dem Quelltext nie an, wohl aber der siebten Seite.
- **Getrennt wird NICHT, deshalb ist der Satz linksbündig.** Die deutsche
  Silbentrennung ist nicht ableitbar (dieselbe Regel wie in der
  Wörterwerkstatt), und eine falsche Trennung stünde für immer im Dokument.
  Ohne Trennung reißt Blocksatz Löcher in die Zeilen — ein flatternder rechter
  Rand ist der kleinere Schaden. Nur ein Wort, das allein schon breiter ist als
  die Zeile (eine lange Adresse), wird hart zerlegt: Dort gibt es keine
  Alternative außer Wegschneiden.
- **Was WinAnsi nicht hergibt, wird GEZÄHLT** (`js/winansi.js`). Die
  Standardschriften kennen 224 Zeichen; deutscher Text passt vollständig hinein,
  ein Emoji nicht. Es wird zum Fragezeichen, und die App sagt hinterher, wie
  viele es waren und welche. Weiches Trennzeichen und geschütztes Leerzeichen
  werden VOR der Zuordnung ersetzt — das weiche Trennzeichen hat in WinAnsi eine
  sichtbare Gestalt, unverändert stünde mitten im Wort ein Bindestrich.
- **Der LESER kennt die Standardbreiten jetzt auch** (`standardbreiten` in
  `schriftmasse.js`, benutzt von `js/schrift.js`). Eine der 14 Standardschriften
  MUSS kein `/Widths` mitbringen; vorher nahm der Leser dafür 500/1000 je
  Zeichen an — das „i" so breit wie das „m", und damit standen Leerzeichen,
  Zeilenenden und Absatzgrenzen schief. Gefunden beim Rücklesen der selbst
  gesetzten PDF: Der Leser meldete Zeilen von 620 Punkt auf einer Seite von 595.
- **Eine Stufe, die nur EINMAL vorkommt, ist ein Titel und keine
  Kapiteleinteilung** (`kapitelSchneiden`). Sonst ergibt „Titel / Kapitel 1 /
  Kapitel 2" ein einziges EPUB-Kapitel, das das ganze Buch enthält, und ein
  Inhaltsverzeichnis mit einem Eintrag. Dazu erkennt `bloeckeAusText` die erste
  Zeile als Titel, wenn darunter eine weitere Überschrift steht — aber NUR die
  erste: Sonst würde aus einem „Mit freundlichen Grüßen" über einem Namen eine
  Überschrift.
- **Wer eine Datei nicht lesen kann, sagt WAS ankam — und schiebt die Schuld
  nicht auf die Datei** (gemeldet 09/2026: „Das ist keine PDF-Datei" über einer
  tadellosen PDF). Auf iPhone und iPad liegt eine Datei aus iCloud oft nur in
  der Wolke; der Dateiwähler meldet sie mit voller Größe, `arrayBuffer()`
  liefert aber nichts. Deshalb vergleicht `verarbeiten` `datei.size` mit dem,
  was wirklich ankam, und `pdfLesen` nennt bei fehlendem Kopf die Dateigröße
  und die ersten Zeichen. Gesucht wird der Kopf zudem in der GANZEN Datei:
  Manche Werkzeuge stellen einer PDF etwas voran.
- **Eine Kopfzeile erkennt man am ABSTAND und an der GRÖSSE**, nicht an der
  Position in der Zeilenliste (`randzeilen` in `js/aufbereiten.js`). Beide
  Merkmale sind je einmal teuer gelernt worden: Nach Position allein fraß die
  Prüfung in einem Text, der sich inhaltlich wiederholt, echten Inhalt; ohne
  die Größenregel verlor ein Dokument, dessen Seiten je mit einer
  Kapitelüberschrift beginnen, genau diese Überschriften. Der Zeilenabstand
  wird als UNTERES VIERTEL der Abstände geschätzt, nicht als Mittelwert — auf
  einer kurzen Seite zieht der Mittelwert die Schwelle so hoch, dass die
  Kopfzeile darunter durchrutscht.
- **Ein Absatz endet dort, wo eine Zeile VOR dem rechten Rand aufhört.** Das
  ist das verlässlichste Merkmal für einen Umbruch, der keine Fortsetzung ist;
  ohne es wachsen Aufzählungen und Grußformeln zu einem Klumpen zusammen. Die
  Schwelle liegt bei einem halben Wort (`groesse * 3.4`) — enger gefasst
  zerfiel ein Absatz in seine Zeilen.
- **Geteilt wird TEXT, keine Datei** (`anNotizen` in `js/app.js`). Eine
  geteilte Datei landet in den Notizen als Anhang, den man erst antippen muss;
  geteilter Text steht als Notiz da. Genau darum geht es dem Nutzer (Ansage
  09/2026). Kennt der Browser kein `navigator.share`, wird kopiert und das
  gesagt — der Knopf darf nie stumm bleiben.
- **Die EPUB wird aus den BLÖCKEN gebaut, nicht aus dem Text** (`js/epub.js`).
  Nur die Blöcke wissen, was eine Überschrift war — nämlich das, was in der PDF
  GRÖSSER gesetzt war als der Fließtext und kurz genug ist —, und daraus werden
  die Kapitel samt Inhaltsverzeichnis. Ist der Text im Feld von Hand geändert,
  sind die Blöcke hinfällig; dann liest `bloeckeAusText` die Gliederung aus dem
  geänderten Text zurück.
- **Im EPUB MUSS „mimetype" der erste Eintrag des ZIP sein und UNGEPACKT
  abgelegt werden.** Daran erkennen Lesegeräte das Format, ohne das Archiv zu
  öffnen; gepackt oder an zweiter Stelle gilt die Datei als beschädigt. Der
  ZIP-Schreiber steht deshalb mit im Haus (`zipSchreiben`) — gepackt wird mit
  `CompressionStream`, ohne das ungepackt, was erlaubt ist. Mitgeliefert wird
  neben `nav.xhtml` auch das alte `toc.ncx`: Lesegeräte ohne EPUB 3 finden
  sonst gar keine Gliederung.
- **Escape-Folgen für Steuerzeichen (\u0000 und Geschwister) gehören als ZEICHENFOLGE
  in den Quelltext, nie als echtes Steuerzeichen** (gefunden 09/2026 in
  `maskiere`). In der Modulfassung lief der reguläre Ausdruck; in
  `einzeldatei.html` machte der HTML-Parser aus dem echten NUL ein
  Ersatzzeichen, die Zeichenklasse wurde ungültig, und die ganze App blieb
  stumm. Wer eine Datei über ein Werkzeug schreibt, das JSON-Escapes auflöst,
  prüft danach auf echte Steuerzeichen.
- **Der Eintrag im Teilen-Blatt gibt es nur auf Android** (`share_target` im
  Manifest, POST-Zweig in `sw.js`). Apple unterstützt Web Share Target NICHT —
  eine Web-App kann auf iPhone und iPad nicht im Teilen-Blatt stehen, egal wie
  sie installiert ist. Das nie anders darstellen; der Weg dort ist der
  Dateiwähler (er öffnet iCloud Drive und Mail-Anhänge ohne Kopie) und auf dem
  iPad das Ziehen. Die geteilte Datei kann nur der Service Worker annehmen,
  eine Seite nicht: Er legt sie in einen EIGENEN Zwischenspeicher
  (`textauszug-geteilt`, beim Aufräumen ausgenommen) und leitet mit 303 auf
  `./?geteilt=1` um — ohne Umleitung stünde der Nutzer vor einer Antwortseite,
  die es nicht gibt. Die App holt sie dort ab und LÖSCHT sie sofort, sonst
  erschiene beim nächsten Öffnen das Dokument von vorgestern.
- **Ein Scan enthält keinen Text**, sondern ein Bild davon. Die App sagt das
  deutlich, statt eine leere Seite auszugeben; eine Texterkennung hat sie
  nicht. Dasselbe gilt für kennwortgeschützte PDFs — dort steht der Weg
  drumherum in der Meldung.
- Die `.txt` wird wie beim Terminkonverter als `application/octet-stream`
  ausgegeben (mit BOM, damit Windows-Editoren die Umlaute richtig lesen).

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
- **1.1.0 war die erste Fassung im App Store** (eingereicht 08/2026,
  freigegeben 09/2026): Freigabe per Einladungslink und privater
  iCloud-Abgleich.
- **1.4.0 ist die erste Aktualisierung** (Ansage des Nutzers, 09/2026).
  Zwischen 1.1.0 und 1.4.0 liegen der Sitzplan als neue Elementart, die
  Geburtstage samt Ritual und Fragenkatalogen, das Zurücksetzen auf
  „unbenutzt“, das Ausblenden von Seiten und die Reparaturen am Abgleich.
  Der Sprung auf 1.4 statt 1.3.32 war eine bewusste Entscheidung: Das ist
  eine Funktionsfassung, keine Reihe von Nachbesserungen. Danach zählt es
  wie gewohnt weiter — 1.4.1, 1.4.2 …
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

### Dokumentenkamera — die Lage kommt vom iPad, nicht vom Beamer

- **Die Szene des Beamers zählt nicht mit** (`Videolage.jetzt`, behoben in
  1.4.1). Hängt ein zweiter Bildschirm am iPad, gibt es zwei
  `UIWindowScene`, und beide sind `.foregroundActive`. `connectedScenes`
  ist ein **Set** und damit ungeordnet — `first { … }` griff mal die eine,
  mal die andere.
- Ein externer Bildschirm hat **keine Lage**: `interfaceOrientation` ist
  `.unknown` und läuft in `winkel(fuer:)` in den Vorgabefall, also 90 Grad
  = Hochformat. Ein Heft im Querformat stand damit hochkant und
  beschnitten auf der Tafel, sobald der Beamer dranhing (gemeldet 09/2026).
- Gezählt werden deshalb nur Szenen der App selbst
  (`session.role == .windowApplication`) und nur solche mit gültiger Lage.
  Die Absicht stand schon vorher im Kommentar über `layoutSubviews` — sie
  war nur nicht umgesetzt.

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
- **Die Herkunftszeile wird nachgesehen, nicht erschlossen** (ab 1.4.2).
  Bis 1.4.1 gab jeder Release-Bau „Production (über TestFlight installiert)“
  aus — auch die Fassung aus dem App Store (gemeldet 09/2026). Das war eine
  Auskunft über die Bau-Konfiguration, ausgegeben als Messung; dieselbe Art
  Lüge, die bei Schulalarm die APNs-Umgebung betraf. Gelesen wird jetzt der
  Kaufbeleg: `sandboxReceipt` = TestFlight, `receipt` = App Store, sonst
  „nicht feststellbar“. **An der CloudKit-Umgebung ändert das nichts** —
  beide Wege sind Production; genau deshalb darf die Zeile es nicht behaupten.
- **Eine Freigabe ohne Link: NICHT raten, messen** (`pruefeTeilen`, ab 1.0.63).
  Die Freigabe wird gesichert und bleibt ohne Adresse — CloudKit meldet keinen
  Fehler, die App fängt es ab (`legeFreigabeAn` prüft `url != nil`). Bis 1.4.2
  nannte die Meldung dazu einen Grund: meist fehle `cloudkit.share` in dieser
  Umgebung. Das war meine Vermutung aus 1.0.60, ausgegeben wie ein Befund —
  und im Fall, der 09/2026 wirklich auftrat, stand der Typ in Production. Die
  Meldung schickte also auf eine falsche Fährte, und zwar mich selbst zuerst.
  Seit 1.4.3 nennt sie keinen Grund mehr, sondern führt zu „Teilen prüfen“ in
  „Abgleich prüfen“: Das legt einen EIGENEN Probe-Datensatz an (nichts, was dem
  Nutzer gehört), teilt ihn einmal MIT und einmal OHNE öffentlichen Link, lädt
  nach zwei Sekunden nach und räumt alles wieder weg. Gelingt nur die zweite,
  hängt es am öffentlichen Link — nicht am Teilen. Dasselbe Muster wie die
  Stufenprobe bei Schulalarm: **Wo eine Meldung nur auf die Umgebung zeigt,
  muss eine Probe entscheiden.**
- **Der öffentliche Link ist nicht überall erlaubt — also gibt es einen
  Rückfall** (ab 1.4.4). Gemessen 09/2026 mit „Teilen prüfen“: Auf einem
  Konto kam JEDE Freigabe mit `publicPermission = .readWrite` ohne Adresse
  zurück, dieselbe Freigabe ohne öffentlichen Link bekam sofort eine. CloudKit
  meldet dazu keinen Fehler; es liefert nur die Adresse nicht. Damit war das
  Teilen ganz tot, obwohl der Weg daneben offenstand. `legeFreigabeAn`
  versucht deshalb erst den öffentlichen Link (Ansage des Nutzers, 08/2026:
  Einladungslink, Schreibrecht sofort, keine Rechteabfrage) und weicht nur
  aus, wenn keine Adresse kommt. Zwei Dinge gehören dazu: Der Rest ohne
  Adresse muss WEG, sonst hält ihn `bereiteFreigabeVor` beim nächsten Mal für
  die gültige Freigabe — und die Wurzel muss frisch geholt werden, denn das
  Sichern hat ihr Etag verändert. Dazu richtet sich `availablePermissions` im
  Teilen-Blatt nach der Freigabe, die WIRKLICH entstanden ist: Ein fest
  eingetragenes `.allowPublic` böte sonst als einzige Möglichkeit genau die
  an, die auf diesem Konto scheitert.
- **Eine Kopie erbt keine Kennungen** (`Kopie.swift`, ab 1.4.5). Beim
  Duplizieren bekam das Element eine neue Kennung, was IN ihm steckt aber
  nicht. Bei den Klangfeldern fiel es auf: Der Abspieler führt das Laufende je
  Feld, und zwei Felder gleicher Kennung sind für ihn eines — ein Tipp auf das
  eine ließ auch das andere leuchten und seinen Balken ablaufen (gemeldet
  09/2026). Zwei Stellen, mit Absicht beide: `mitNeuenKennungen()` stellt die
  Ursache ab (Klangfelder UND Checklistenpunkte, in `duplicateWidget` und
  `duplicateBoard`), und `SoundPlayer.feld` nimmt zusätzlich das Element mit
  in den Schlüssel — das heilt die Kopien, die schon auf der Platte liegen und
  die kein Umbenennen mehr erreicht. **Wer eine neue Inhaltsart mit eigenen
  Kennungen baut, trägt sie in `mitNeuenKennungen()` ein.**
- **Das Aussehen eines Elements ist keine Anordnung** (ab 1.4.6).
  `mitFremdemInhalt` behält bewusst die eigene Anordnung (x, y, Größe, z,
  Seite, Sperre) und übernahm vom Gegenüber nur `content`. Damit blieben
  `labels`, `labelSize`, `karte` und `schriftfarbe` liegen: Wer auf einem
  Gerät die Überschrift einer Kachel abschaltete, sah sie auf dem anderen
  weiter — und sobald DIESES Gerät das nächste Mal schrieb, schickte es
  seinen alten Stand zurück und die Einstellung sprang um (gemeldet 09/2026:
  „bleibt eine Zeit lang so, irgendwann ist es wieder auf Standard“). Wo ein
  Element steht, ist die Entscheidung dieses Geräts; wie es aussieht, sehen
  alle, die auf die Tafel schauen. Die vier Felder kommen deshalb mit.
  Per Gerät bleiben nur `versteckt` und die Anordnung.
- **Welchen Weg der Abgleich nimmt, steht in der Bestandsaufnahme**
  (`nurInhaltZaehlt`, ab 1.4.6). Ob ein ankommender Stand ganz gilt oder nur
  mit Inhalt und Aussehen, hängt an `zuletztVon`, `memberUserIDs` und
  `ownerUserID` — von außen unsichtbar, und genau daran hängt jede Frage der
  Art „warum kommt diese Einstellung nicht an?“. Die Entscheidung steht
  jetzt an EINER Stelle, und „Abgleich prüfen“ liest dieselbe: Steht in der
  Zeile „Abgleich: nur Inhalt“, gilt der Zusammenführungsweg.
- **Übersetzt wird in GitHub Actions**, nicht erst auf dem Mac: Der
  Arbeitsablauf `.github/workflows/tafelbild-build.yml` baut die App bei
  jedem Push auf `TafelbildiOS/` auf einem macOS-Läufer (xcodebuild,
  iOS-Simulator-SDK, ohne Signierung) und listet am Ende alle
  `error:`- und `warning:`-Zeilen auf.
- **Verbindlich für Claude: erst pushen, Bau abwarten, Fehler beheben —
  und den PR-Link erst herausgeben, wenn der Bau grün ist.** Nie wieder
  einen ungebauten Stand als fertig melden.
