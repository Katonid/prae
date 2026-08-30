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
