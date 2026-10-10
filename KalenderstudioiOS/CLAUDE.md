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
  (Ozean & Abendrot: Petrol-Türkis, Abendhimmel, Gold), Bindungsrand vom
  Endformatrand gemessen, Vorlage „A3 hoch, Wire-O oben“, PDF-Effekte in
  Druckauflösung; 1.0.3 (4) eigene Schriften (auf dem Gerät installierte
  und geladene Schriftdateien); 1.0.4 (5) iCloud-Abgleich (vorbereitet, Recht
  noch nicht eingehängt), richtiger Schriftschnitt, Einbettungsprüfung.
  1.0.5 (6) iCloud-Recht eingehängt (ohne Schriftenrecht).
  1.0.6 (7) Schriftenrecht eingetragen (gemessen).
  1.0.7 (8) selbst installierte Schriften wie im Reisebuch (Systemabfrage,
  Wähler mit Schnitten, Schriftenprobe, Fassung in den Einstellungen).
  1.0.8 (9) Gestaltung nach Anregungen anderer Anbieter (siehe unten
  „Gestaltungsideen“).
- Team `F4989GSTWS`, `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO`
  als Build-Einstellung, zusätzlich `ITSAppUsesNonExemptEncryption` in
  `Config/Info.plist`. `Config/` liegt absichtlich außerhalb des
  synchronisierten Ordners. **Entitlements: `Config/Kalenderstudio.entitlements`
  ist seit 1.0.5 eingehängt** (iCloud Documents), seit 1.0.6 mit dem
  Schriftenrecht (siehe „iCloud-Abgleich“ unten).

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

## Gestaltungsideen (ab 1.0.8)

Auf Wunsch des Nutzers (10/2026, „noch nicht ganz zufrieden mit dem
Datumsbereich und dem Hintergrund“) im Netz gesammelt und eingebaut.
Quellen: fotobuchexpress24 (Kalendarien „Kreis“, „Geteilt“, „Markant“),
fotokalender.org (Kunstkalender mit „Zeitleiste“), Stendig/Vignelli
(große, eng gesetzte Ziffern, Monate im Wechsel hell/dunkel), CEWE und
my moments (Hintergrundfarbe aus dem Foto, auslaufende Fotos, riesiger
blasser Buchstabe als Hintergrund), meinbildkalender (für Papier mehr
Kontrast als am Bildschirm), design-milk/Chilli Printing (Risographie,
„Farbe des Monats“).

- **Kalendarien** (`MonthGridLayout`, `Render/Grids.swift`): neu
  „Zeitleiste“ (`MonthStripView`, ein oder zwei Leisten, Termine darunter;
  `isSlim` → das Monatsfoto bekommt 70 % der Höhe, quer ebenfalls Foto
  oben), „Kreis“ (`MonthRingView`/`RingDial`, Schulferien als Bögen,
  Strich vor jedem Montag), „Große Ziffern“ (`BoldDayCell`, keine Linien)
  und „Geteilt“ (Terminliste links, kompaktes Raster rechts). Die
  Terminliste (`MonthEvents`/`MonthEventsView`) teilen sich die drei.
- **Monatsseiten** (`Design`, Schalter im Stil-Panel): „Farbe des Monats“
  (`ImageStore.dominantColor` — Farbtonfächer nach Sättigung, nicht der
  Mittelwert; `Design.tinted`), „Foto läuft aus“ (`fadeOut`, Maske NUR
  wenn eingeschaltet, sonst bleibt das JPEG im PDF unangetastet), „Große
  Monatszahl“, „Monat als Zahl“, „im Wechsel hell und dunkel“
  (`Design.inverted`, jeder zweite Monat). Akzentfarben werden mit
  `RGBA.readable` auf Kontrast 3 gezogen.
- **Hintergründe:** „Risographie“ (Farbflächen + Korn) und „Leinen“.
  **Vorlagen:** „Schweizer Raster“, „Risographie“, „Leinen & Foto“.
- Wochenende im Raster etwas kräftiger getönt (0,055 statt 0,035).
- Simulator-Probe: `-probe=<Art>:<Kalendarium>:<Vorlage>` ohne Titelblatt
  ab Mai; der Arbeitsablauf fotografiert die neuen Kalendarien mit.

## iCloud-Abgleich (ab 1.0.4)

- **iCloud DRIVE, nicht CloudKit** (`Model/CloudStore.swift`) — dieselbe
  Entscheidung und Begründung wie beim Reisebuch: kleine JSON-Datei, viele
  große Fotos. Je Kalender eine Datei `Kalender/<Kennung>.json`, Fotos in
  `Fotos/`, geladene Schriftdateien in `Schriften/`. `CloudStore` ist die
  EINZIGE Stelle, die weiß, wo etwas liegt.
- **Die Datei auf dem Gerät bleibt die Arbeitskopie** (`kalender.json`). Die
  Wolke wird beim Start, auf Meldung von `NSMetadataQuery` (2 s Ruhe) und
  mit „Jetzt abgleichen“ eingelesen und zusammengeführt; geschrieben wird
  nach jedem Speichern, nur was sich geändert hat (`lastWritten`).
- **Wer geändert hat, entscheidet `modified` IM Kalender** gegen den Stand
  beim letzten Abgleich (`syncedStamps`, UserDefaults „abgleichStaende“) —
  nicht die Dateizeit. Beide geändert: die neuere gewinnt, die ältere
  bleibt als eigener Kalender „(ältere Fassung, …)“. Gelöscht wird über
  einen Grabstein `<Kennung>.geloescht`, sonst käme der Kalender vom
  anderen Gerät zurück.
- **Umschalten und Einschalten KOPIEREN, löschen nichts** (Fotos und
  Schriften vom Gerät in die Wolke).
- **Ein Foto kann vor seinen Bildern ankommen** (Reisebuch 1.0.71): Geprüft
  werden beide Gestalten eines nicht geladenen Elements (Platzhalter
  `.<Name>.icloud` und Ladestatus), das Laden wird angestoßen, und ein
  vergeblicher Zugriff wird 3 s gemerkt (`ImageStore.misses`) — sonst sucht
  jede Neuzeichnung erneut auf dem Hauptfaden. Die Vorschau zeigt „Lädt aus
  iCloud …“; der Export WARTET auf alle Originale und meldet getrennt, was
  noch kommt und was ganz fehlt.
- **`url(forUbiquityContainerIdentifier:)` blockiert** — nur in
  `CloudStore.prepare()` abseits des Hauptfadens, nie in einem `init`.
- **Ohne Recht oder Anmeldung bleibt die App örtlich und sagt es**
  (Einstellungen › iCloud). „Einrichtung prüfen“ liest aus
  `embedded.mobileprovision`, was das Profil bewilligt (`ProfileRights`).
- **Das Platzhalterprofil kann nichts messen** (Befund des Nutzers,
  10.10.2026, Fassung 1.0.4): Solange die App kein Recht verlangt,
  signiert Xcode mit „iOS Team Provisioning Profile: *“ — und das trägt nie
  iCloud. „Einrichtung prüfen“ sagte deshalb „nicht bewilligt“, obwohl die
  App-Id inzwischen iCloud und Fonts hatte (vom Nutzer in der
  Entwicklerkonsole angelegt, samt Behälter). Das EIGENE Profil holt Xcode
  erst, wenn ein Recht in der Datei steht. Deshalb 1.0.5: iCloud
  eingehängt (bewährte Zeichenketten aus dem Reisebuch); das Schriftenrecht
  wird aus dem dann echten Profil abgelesen und erst danach eingetragen.
- **Gemessen am 10.10.2026 (Fassung 1.0.5, iPad):** Profil „iOS Team
  Provisioning Profile: de.familie.kalenderstudio“; iCloud-Dienste „*“,
  beide Behälter `iCloud.de.familie.kalenderstudio`, Schriftenrecht
  `["app-usage", "system-installation"]`; Abgleich „1 Kalender in iCloud“.
  Das Schriftenrecht steht seit 1.0.6 wortgetreu so in der Datei.
- **Installation auf dem iPhone scheiterte an Xcode, nicht an der App**
  (`dyld_shared_cache_extract_dylibs failed`, Code 908): Xcode kopiert vor
  dem ersten Debuggen die Systembibliotheken des Geräts und braucht dafür
  viel freien Speicher und eine Xcode-Fassung, die das iOS des Geräts kennt.
  Umgehung: im Schema „Debug executable“ abwählen, dann braucht Xcode die
  Symbole nicht.
- **Die Entitlements-Datei wurde erst eingehängt, nachdem die App-Id iCloud
  UND das Schriftenrecht als bewilligt zeigt** — mit genau den dort
  gelesenen Zeichenketten. Vorher nicht: Ein Recht, das die App-Id nicht
  trägt, macht die App unsignierbar (Reisebuch 1.0.44).

## Fallen

- **Schriftschnitt über den PostScript-Namen** (`FontFaces`, ab 1.0.4):
  `Font.custom(Familie).weight(…)` lieferte nicht verlässlich den
  passenden Schnitt (Reisebuch 1.0.29). Gesucht wird der nicht kursive
  Schnitt mit der nächstliegenden Strichstärke; der Vorrat wird beim
  Anmelden neuer Schriften geleert.
- **Ob eine Schrift eingebettet werden darf, steht in ihr** (`FontLicense`,
  OS/2-Feld `fsType`, ab 1.0.4). Gesperrte und fehlende Schriften nennt der
  Export-Dialog. Ob CoreGraphics eine erlaubte Schrift dann wirklich
  einbettet, zeigt erst ein Blick in die fertige Datei.
- **Selbst installierte Schriften fehlten im Wähler (Befund des Nutzers,
  10.10.2026, Bildschirmfotos Kalenderstudio gegen Reisebuch):** Der Wähler
  von Kalenderstudio zeigte nur Systemschriften, der des Reisebuchs Poppins,
  Quicksand usw. Ohne `com.apple.developer.user-fonts` im Bau zeigt auch
  der Wähler von iOS nur Systemschriften (Reisebuch 1.0.44); das Recht kam
  erst mit 1.0.6. Welche Fassung lief, ließ sich nicht sagen — **deshalb
  steht die Fassung seit 1.0.7 in den Einstellungen.** Zusätzlich fehlten die
  Wege des Reisebuchs, seit 1.0.7 nachgezogen: Wähler mit `includeFaces =
  true` (Deskriptor statt Familienname, Schnitt per PostScript-Name gemerkt
  in „eigeneSchnitte“), beim Start `CTFontManagerCopyRegisteredFontDescriptors
  (.persistent, true)` und Anmeldung über `CTFontManagerRegisterFontDescriptors
  (.process)` mit Ergebnis aus dem Rückrufblock; Fehler nach Code gedeutet;
  Protokoll „schriftenProtokoll“ und „Schriftbefund kopieren“ unter
  Einstellungen › Schriften. **Nicht gemessen:** Ob die Systemabfrage etwas
  liefert, sagt erst der Befund vom Gerät (im Reisebuch blieb sie leer,
  während der Wähler ging).
- **Eigene Schriften (seit 1.0.3, `Model/CustomFonts.swift`).** Vom
  Nutzer installierte Schriften (Adobe Fonts, Schrift-Apps, Profile) gibt
  iOS einer App **nur über `UIFontPickerViewController`** frei — eine
  eigene Liste per `UIFont.familyNames` zeigt sie nicht. Gewählte
  Familien stehen in `UserDefaults` („eigeneSchriften“) und werden bei
  jedem Start mit `CTFontManagerRequestFonts` erneut angefordert, sonst
  fällt der Text still auf die Systemschrift zurück. Geladene Dateien
  liegen in `Documents/Schriften` und werden beim Start mit Bereich
  `.process` angemeldet. Fehlt eine Schrift, zeigt die Liste „derzeit
  nicht verfügbar“.

- **Bindungsrand zählt vom Endformatrand** (seit 1.0.2), so wie
  Druckdienste es angeben („Sicherheitsabstand zur Spiralbindung: 2 cm
  von oben“). Er ersetzt an der Bindekante den Sicherheitsabstand, wenn
  er größer ist — nicht addieren. Vorlage des Nutzers (viaprinto,
  Wandkalender A3 hoch, Wire-O): 297 × 420 mm, 3 mm Beschnitt, 4 mm
  Sicherheitsabstand, 20 mm oben, Daumenloch 1 cm oben mittig; ein
  mehrseitiges PDF, Deckblatt zuerst.
- **`ImageRenderer.render(rasterizationScale:)` immer setzen.** Ohne
  Angabe werden Schatten, Masken (Foto in der Jahreszahl) und
  Weichzeichner im PDF mit 72 dpi gerastert.

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
