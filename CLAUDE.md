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
- **Die Vollbildkarte hat ihren EIGENEN Navigationsstapel — und damit ihr
  eigenes Ziel.** `navigationDestination(for: Haltestelle.self)` steht dort
  noch einmal. Ohne diese Zeile wäre jeder Halt auf der Vollbildkarte ein
  Verweis, der nichts tut; dieselbe Falle wie 1.1.7, nur eine Ebene höher.
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
  1.1.1 (Build 14), 1.1.2 (Build 15), 1.1.3 (Build 16), 1.1.4 (Build 17), 1.1.5 (Build 18), 1.1.6 (Build 19), 1.1.7 (Build 20), 1.1.8 (Build 21), 1.1.9 (Build 22), 1.1.10 (Build 23), 1.1.11 (Build 24), 1.1.12 (Build 25), 1.1.13 (Build 26), 1.1.14 (Build 27), 1.1.15 (Build 28), 1.1.16 (Build 29), 1.1.17 (Build 30), 1.1.18 (Build 31), 1.1.19 (Build 32), 1.1.20 (Build 33), 1.1.21 (Build 34), 1.1.22 (Build 35), 1.1.23 (Build 36), 1.1.24 (Build 37) … Dazu gesetzt (Ansage des Nutzers,
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
  `js/inhalt.js`). Keine Bibliothek nachladen: Das bräche Offlinebetrieb und
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
