# Projekt FlightMate AI

> Ausgelagert aus der `CLAUDE.md` im Wurzelverzeichnis (09/2026). Die
> übergreifenden Regeln (PR-Rhythmus, iOS-Pflichten, Bau in GitHub
> Actions) stehen weiterhin dort und gelten hier genauso.


- Produktgrundlage: `docs/flightmate-ai/PRD.md` — Änderungen am Umfang
  müssen zum PRD passen (bzw. das PRD wird mitgepflegt).
- App-Code: `FlightMateiOS/` (Swift/SwiftUI, iOS 17, keine externen
  Abhängigkeiten; zwei Targets: App + FlightMateWatch). Prinzipien:
  wenige Funktionen, erklärbare Logik (Score/Legal deterministisch,
  kein LLM), ehrliche Datenlücken, Datenminimierung.

## FlightMate — Versionierung (Ansage des Nutzers, 08/2026)

- `MARKETING_VERSION` und `CURRENT_PROJECT_VERSION` stehen in
  BEIDEN Targets identisch (vier Stellen im pbxproj:
  App Debug+Release, Watch Debug+Release) — es gibt KEINE
  Skript-Bauphase, beide Werte werden im Repo gepflegt.
- **Jede Arbeitseinheit (= jeder PR mit App-Änderungen) hebt die
  Patch-Nummer UND die Build-Nummer um je +1 an** — ohne
  Nachfrage, als Teil des PRs. Startpunkt: 1.3.1 (Build 4);
  es folgt 1.3.2 (Build 5) usw. Größere Sprünge (z. B. 1.4) nur
  auf ausdrückliche Ansage des Nutzers.
