# Projekt Kalenderstudio (Foto-Kalender für den Druckdienst, native iOS-App)

> Die übergreifenden Regeln (PR-Rhythmus, iOS-Pflichten, Bau in GitHub
> Actions) stehen in der `CLAUDE.md` im Wurzelverzeichnis und gelten hier
> genauso.

- App-Code: `KalenderstudioiOS/` (ein Target, iPad + iPhone, iOS 17,
  SwiftUI, keine Fremdbibliotheken). Bundle-Id `de.familie.kalenderstudio`
  — nach dem ersten Signieren nicht mehr ändern.
- Zweck (Ansage des Nutzers, 10/2026): Kalender gestalten und als
  Druckdatei an einen Druckdienst geben. Drei Kalenderarten:
  **Jahreskalender** (Monatsblätter, Poster, Mosaik, Jahresplaner),
  **Wochenkalender** (Foto & Tageszeilen, Sieben Spalten, Tagebuch) und
  **Monat auf zwei Seiten** (Fotoseite + Kalendarium). Feiertage je
  Bundesland (einzeln abwählbar), besondere Tage, Schulferien aller
  Länder, persönliche Termine (auch aus den Kontakten). Seitenformat,
  Beschnitt, Sicherheitsabstand und Bindungsrand frei in mm.
- **Versionierung:** Patch + Build je +1 bei jeder neuen Fassung
  (`MARKETING_VERSION` und `CURRENT_PROJECT_VERSION`, Debug und Release).
  Erste Fassung: 1.0.0 (1); 1.0.1 (2) behebt das Zurückspringen und den
  Absturz beim Öffnen eines Kalenders; 1.0.2 (3) neue Symbolfarben
  (Ozean & Abendrot: Petrol-Türkis, Abendhimmel, Gold).
- Team `F4989GSTWS`, `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO`
  als Build-Einstellung, zusätzlich `ITSAppUsesNonExemptEncryption` in
  `Config/Info.plist`. `Config/` liegt absichtlich außerhalb des
  synchronisierten Ordners. Keine Entitlements.

## Aufbau

- `Model/` — Datenmodell (`Project.swift`, alles mit robustem
  `init(from:)`: neue Felder bekommen Vorgaben, alte Kalender lassen sich
  weiter öffnen), Feiertagsregeln (`Holidays.swift`), Schulferien
  (`SchoolHolidayData.swift` fest eingebaut, `SchoolHolidays.swift` lädt
  weitere Jahre von openholidaysapi.org nach und legt sie in
  `schulferien-online.json` ab), Seitenfolge und Fotozuordnung
  (`Pages.swift`), Fotos (`ImageStore.swift`).
- `Render/` — die Seiten. **Jede Seite wird in echter Druckgröße in Punkt
  aufgebaut** (`PageGeometry`, 1 mm = 72/25,4 pt, inkl. Beschnitt); die
  Vorschau verkleinert nur. Schrift und Abstände hängen an
  `unit` = 1/100 der kürzeren Endformatseite, damit jedes Format stimmig
  bleibt. Texte und Kalendarium liegen immer im `safeRect`; nur
  Hintergründe und randlose Fotos reichen in den Beschnitt.
- `Exporter.swift` — PDF über `ImageRenderer.render` in einen
  `CGContext` (MediaBox, BleedBox, TrimBox gesetzt; Schnittmarken
  wahlweise) oder JPG je Seite in 150/200/300 dpi.
- Fotos: Original bis 7000 px (Druck) und Vorschau 1600 px im Ordner
  `Documents/Fotos`. Hintergrund-Weichzeichnung per Core Image aus der
  Vorschau (nicht per SwiftUI-`.blur`, das im Export unzuverlässig ist).

## Fallen

- **Kein `NavigationStack` im Gestalten-Panel (`.inspector`).** Das
  Panel liegt im Stapel der Startseite; ein zweiter Stapel darin ließ
  den Editor auf dem iPad beim Öffnen sofort zur Startseite
  zurückspringen und beim zweiten Öffnen abstürzen (1.0.0, im Simulator
  nachgestellt). Unterseiten im Panel (z. B. die Schriftauswahl) als
  `.sheet` mit eigenem Stapel öffnen — Sheets sind eigene Darstellungen
  und dürfen das.
- **Prüfen im Simulator ohne Mac:** Arbeitsablauf „Kalenderstudio
  ansehen“ (nur auf Knopfdruck). Er startet die Debug-Fassung mit
  `-probe=year|doubleMonth|week`; dann legt `HomeView` einen
  Probekalender an und öffnet ihn sofort. Bildschirmfotos, Protokoll und
  Absturzberichte liegen danach unter „Artifacts“.
- Jahreszahlen nie als `Text("\(jahr)")` — das formatiert mit
  Tausenderpunkt („2.027“). Immer `Text(verbatim:)` oder `String(jahr)`.
- Schriften mit `Font.custom(_, fixedSize:)`, nicht `size:` — sonst
  skaliert Dynamic Type die Druckseite mit.
- Mecklenburg-Vorpommern führt bei den Schulferien allgemeinbildende und
  berufliche Schulen getrennt; übernommen werden nur `MV-ABS`.
- Feiertagslisten (Stand 2026) wurden mit der OpenHolidays API
  abgeglichen. Bei Gesetzesänderungen (neuer Landesfeiertag)
  `HolidayCatalog.publicHolidays` anpassen.
