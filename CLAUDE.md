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

## Projekt Klassenraum (iOS) — Versuchsfassung, NICHT die Store-App

- Code: `KlassenraumiOS/` — eine **Kopie** von `TafelbildiOS/` (Stand 1.0.57)
  mit eigener Bundle-ID `de.familie.klassenraum` und dem Anzeigenamen
  „Klassenraum". Einziger Zweck: den Abgleich von der **öffentlichen** auf
  die **private** iCloud-Datenbank umbauen (Weg A: private Datenbank plus
  `CKShare`), ohne die veröffentlichte App anzufassen.
- **Nicht verwechseln** mit `klassenraum/` (kleingeschrieben) — das ist die
  Web-App gleichen Namens und hat damit nichts zu tun.
- **Niemals zur Prüfung einreichen.** Zwei fast gleiche Apps desselben
  Entwicklers sind nach Apples Regel 4.3 eine Dublette. Diese Fassung lebt
  nur in TestFlight bei **internen** Testern; dafür findet keine Prüfung
  statt.
- **Der iCloud-Bereich ist mit Absicht derselbe** wie bei Tafelbild
  (`iCloud.de.familie.tafelbild`): Weg A schreibt nur in die private, die
  veröffentlichte App nur in die öffentliche Datenbank — sie stören einander
  nicht, und die Versuchsfassung kann den vorhandenen Bestand lesen, um den
  Umzug an echten Tafeln zu üben.
- **Hier passiert nur der Abgleichs-Umbau.** Alle sonstigen Verbesserungen
  gehen weiter allein nach `TafelbildiOS/`; diese Kopie bleibt bei den
  Funktionen bewusst zurück. Steht der Umbau, wandert nur die
  Abgleichsschicht zurück nach `TafelbildiOS/`, und der Ordner wird gelöscht.
- Version beginnt bei `0.1.0` (zwei Stellen im pbxproj); die Build-Nummer
  vergibt dieselbe Skript-Bauphase wie bei Tafelbild.
- Gebaut wird von `.github/workflows/klassenraum-ios-build.yml`.
- **Ein Dateiwähler gehört an einen Halter, den es immer gibt.** Der
  Wähler für Tondateien hing an dem Abschnitt mit „Feld hinzufügen" —
  also an einer Zeile mitten in der Liste. Ein `Form` ist eine `List`,
  und die baut ihre Zeilen erst auf, wenn sie in Sichtweite kommen: Stand
  über den Klangfeldern genug, war die Zeile beim Tippen noch gar nicht
  da, und mit ihr der Wähler nicht. Der Schalter sprang um, nichts
  passierte. Seit 0.1.9 hängt er an der Wurzel des Formulars
  (`WidgetSettingsSheet`), das Ziel wird als Bindung hinuntergereicht.
  Bild und Video waren nie betroffen — deren Wähler hängen an der Group
  bzw. an einem festen Abschnitt ohne `ForEach` darüber.
- **Nicht dem Szenen-Delegaten anlasten.** In 0.1.8 hatte ich ihn dafür
  verantwortlich gemacht und ausgebaut; das war falsch. Er ist seit
  0.1.9 wieder da (mit `var window: UIWindow?`, wie
  `BeamerSceneDelegate`) und nimmt Freigabe-Einladungen entgegen. Wenn
  ein Wähler schweigt: erst prüfen, ob ANDERE Wähler auch schweigen —
  gehen sie, liegt es an der Stelle, an der dieser eine hängt.
- **Der Umbau ist durch** (0.1.7): private Datenbank mit eigener Zone,
  Abgleich über Änderungsmarken aus privater UND geteilter Datenbank,
  Teilen/Widerrufen/Übernehmen über `CKShare`. Der Einladungscode ist
  ersatzlos entfallen. Einzelheiten in `KlassenraumiOS/README.md`.
- **Beim Rückbau nach Tafelbild sind vier Angaben nachzuziehen** —
  App-Datenschutz in App Store Connect, `PrivacyInfo.xcprivacy`,
  `docs/tafelbild/datenschutz.html` und der Werbetext. Sie stehen samt
  fertiger Formulierungen in `KlassenraumiOS/AppStore.md`. **Vorher
  nichts davon ändern:** Solange Tafelbild in die öffentliche Datenbank
  schreibt, ist der heutige Wortlaut dort der richtige.

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
  Bild, Klänge) auf mehreren Tafeln, teilbar per Einladungscode.
  (Nicht verwechseln mit der Web-App `klassenraum/` — beide existieren
  nebeneinander.)
- `MARKETING_VERSION` steht an zwei Stellen im pbxproj (Debug +
  Release). **Jede Arbeitseinheit (= jeder PR mit App-Änderungen) hebt
  die Patch-Nummer um +1 an** — ohne Nachfrage, als Teil des PRs
  (1.0.1 → 1.0.2 → 1.0.3 …). Größere Sprünge nur auf ausdrückliche
  Ansage des Nutzers.
- Die **Build-Nummer vergibt die Skript-Bauphase „Build-Nummer setzen"**
  automatisch (Anzahl der Git-Commits, sonst Datumsstempel) — wie in
  Tagesspur, nie von Hand pflegen. Damit ist jeder TestFlight-Upload
  garantiert neuer als der vorherige. Dafür steht im Target
  `ENABLE_USER_SCRIPT_SANDBOXING = NO` — nicht entfernen.
- `ITSAppUsesNonExemptEncryption = NO` steht doppelt: in
  `Config/Info.plist` und als Build-Einstellung
  `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption` — nicht entfernen,
  erspart die Export-Compliance-Frage bei jedem TestFlight-Build.
- Datenhaltung wie in der Reisekasse: generische `Entity`-Records in der
  öffentlichen CloudKit-Datenbank. **Sichtbarkeit hängt an der
  iCloud-Kennung** (`ownerUserID` / `memberUserIDs`, aus
  `CKContainer.fetchUserRecordID`) — nicht am Anzeigenamen; nur so
  erscheinen eigene Tafeln auf allen Geräten derselben Apple-ID.
- In der CloudKit-Konsole genügt **ein** Index: `Entity` → Feld
  `updatedAtMs` → QUERYABLE (die App sortiert selbst, SORTABLE entfällt).
  Fehlt er, fällt die Abfrage automatisch auf „alles holen" zurück, was
  einen Index auf `recordName` braucht.
  Pflicht ist dagegen die Sicherheitsrolle: `Entity` → `_icloud` braucht
  Read **und** Write, sonst dürfen Kolleginnen geteilte Tafeln nicht
  ändern.
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
