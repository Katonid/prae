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

## Projekt Klassenraum (Web-App)

- Code: `klassenraum/` — statische Web-App ohne Build-Schritt (ES-Module,
  kein Framework), wird vom bestehenden GitHub-Pages-Workflow mit
  ausgeliefert: https://katonid.github.io/prae/klassenraum/
- Ersetzt den kostenpflichtigen Dienst „Classroomscreen“: Zufallsnamen,
  Timer/Stoppuhr, Uhr, Ampel, Tagesablauf, Text, Bild, Lautstärkemesser,
  Arbeitssymbole — frei verschiebbar auf einer Tafelfläche.
- Alles liegt lokal (IndexedDB). Es geht nur dann etwas ins Netz, wenn ein
  Teilen-Code erstellt oder ein Konto genutzt wird.
- Cloud läuft über die REST-Schnittstellen von Firebase (Realtime Database
  + Identity Toolkit) mit `firebase-config.js` aus dem Wurzelverzeichnis —
  kein SDK laden, das bricht den Offline-Betrieb.
- Konten brauchen eine einmalige Freischaltung in der Firebase-Konsole
  (Authentication → E-Mail/Passwort). Ohne sie zeigt die App einen Hinweis;
  Teilen per Code funktioniert trotzdem.
- Die App-Icons erzeugt `klassenraum/scripts/generate-icons.py` — nicht von
  Hand bearbeiten.

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
- Indizes in der CloudKit-Konsole sind **optional**: Fehlt der Index auf
  `updatedAtMs`, fällt die Abfrage automatisch auf „alles holen" zurück.
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
