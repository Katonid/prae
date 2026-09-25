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

## Wo die Projektregeln stehen

Jedes Projekt hat seine eigene `CLAUDE.md` in seinem Ordner (aufgeteilt
09/2026 — die Datei im Wurzelverzeichnis war auf über 12.000 Zeilen
gewachsen und belegte bei jeder Sitzung fast die Hälfte des Kontexts).
Claude Code lädt eine solche Datei, sobald in dem Ordner gelesen oder
gearbeitet wird. **Verbindlich: Vor der ersten Änderung an einem Projekt
dessen `CLAUDE.md` vollständig lesen** — dort stehen Versionierung,
Fallen und die Lehren aus früheren Fassungen. Neue Projektregeln gehören
in die Datei des Projekts, nicht hierher; hier steht nur, was für alle
gilt.

| Projekt | Ordner | Versionierung (Kurzfassung) |
|---|---|---|
| Tagesspur | `TagesspuriOS/` | Patch +1, Build per Skript-Bauphase |
| Kassenbuch (Reisekasse) | `ReisekasseiOS/` | Patch + Build je +1 |
| FlightMate AI | `FlightMateiOS/` | Patch + Build je +1 |
| Schulalarm | `AlarmiOS/` | Patch + Build je +1 (Sonderregel um 1.1.0) |
| Abfahrtstafel | `AbfahrtstafeliOS/` | Patch + Build je +1 |
| Routenplaner | `RoutenplaneriOS/` | Patch + Build je +1 |
| Urlaubstagebuch (Reisebuch) | `UrlaubstagebuchiOS/` | Patch + Build je +1 |
| Fernweh | `FernwehiOS/` | Patch + Build je +1 |
| Anstoß | `AnstossiOS/` | Patch + Build je +1 |
| Tafelbild | `TafelbildiOS/` | Patch +1, Build per Skript-Bauphase |
| Notfallalarm (Android) | `NotfallalarmAndroid/` | eigener Linux-Bau `notfallalarm-build.yml` |
| Wörterwerkstatt (Web) | `woerterwerkstatt/` | `js/version.js` + `FASSUNG` in `sw.js` |
| Terminkonverter (Web) | `terminkonverter/` | `FASSUNG` in `sw.js`, `einzeldatei.html` neu bauen |
| Textauszug (Web) | `textauszug/` | `FASSUNG` in `sw.js`, `einzeldatei.html` neu bauen |
| Klassenraum (Web) | `klassenraum/` | — |

Bei Querverweisen („dieselbe Lehre wie bei Schulalarm", „Lehre aus
Tafelbild 1.4.5") steht die Stelle in der `CLAUDE.md` des genannten
Projekts.

## Was mehrere Projekte betrifft

- **GitHub Pages** läuft über „GitHub Actions" (`pages.yml`) und liefert
  alle Web-Apps und `docs/` aus; der Arbeitsablauf spiegelt `docs/`
  zusätzlich an die Wurzel, damit `/soundboard/` (App-Store-Links) und
  `/flightmate-ai/` gültig bleiben — nicht entfernen. Einzelheiten in
  `klassenraum/CLAUDE.md`.
- **Firebase-Datenbankregeln** stehen gemeinsam in `firebase-rules.json`
  im Wurzelverzeichnis (Klassenraum UND Wörterwerkstatt in einer Datei —
  die Konsole ersetzt beim Veröffentlichen alle Regeln). Wer die Regeln
  ändert, gibt sie dem Nutzer **immer als kopierbaren Text in der
  Antwort**, nie als Dateiverweis (er arbeitet am iPad). Einzelheiten und
  Prüfskript in `woerterwerkstatt/CLAUDE.md`.
- **Ein grüner Bau in GitHub Actions beweist nie, dass sich eine iOS-App
  signieren lässt** (`CODE_SIGNING_ALLOWED=NO`). Eine Entitlements-Datei
  nur mit Rechten ändern, die die App-Id nachweislich trägt — Einzelheiten
  in `UrlaubstagebuchiOS/CLAUDE.md` (1.0.44/1.0.45) und
  `AlarmiOS/CLAUDE.md`.

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

Was daraus bleibt, steht in `TafelbildiOS/CLAUDE.md`. Nicht verwechseln
mit `klassenraum/` (kleingeschrieben) — das ist die Web-App gleichen
Namens und lebt weiter.
