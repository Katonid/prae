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
  1.0.9 (10) Fotoanteil am Monatsblatt einstellbar, Seite prüfen (Lupe),
  ganzes Foto mit weichem oder farbigem Hintergrund, Zoomen mit zwei Fingern.
  1.0.10 (11) Ferienbalken oben im Kästchen, Ferien nur auf Wunsch benannt,
  Wochentage mit eigener Schriftgröße, Sicherungsdatei, Startseite auf dem
  iPhone, Beschnitt beim Anlegen, **Abgleich überschrieb neuere Arbeit
  (behoben)**.
  1.0.11 (12) Oster- und Pfingstsonntag überall als Feiertag, Heiligabend
  in jedem Kalender.
  1.0.12 (13) Jahresaufbau „Halbmonat (beidseitig)“ für das Druckhaus Bochum.
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

- **Fotoanteil am Monatsblatt** (ab 1.0.9, Ansage des Nutzers: „50 zu 50
  ist mir zu viel Datum, das Bild möchte ich größer“): `photoShare` im
  Kalender, 0 = automatisch (`MonthGridLayout.defaultPhotoShare`: hoch
  0,56, quer 0,5, Zeitleiste 0,7/0,64), sonst 0,4…0,85 vom Endformat
  (Aufbau › „Foto und Kalender“, nur Jahreskalender mit Monatsblättern).
  Quer ist es die Breite des Fotos links. Die Kopfzeile ist auf 4…9 `unit`
  begrenzt, damit dem Raster bei großem Foto Platz bleibt. **Wird ein Raster
  zu flach, schaltet `MonthGridView.effective` auf die Zeitleiste** — im
  Simulator brach „Große Ziffern“ bei 85 % sonst unlesbar zusammen.

- **Seite prüfen (Lupe, ab 1.0.9,** Ansage des Nutzers: „heranzoomen“):
  `Views/PageZoomView.swift`. Die Arbeitsfläche blättert per Wischen
  (`TabView .page`) und wird deshalb NICHT zoombar gemacht — Zoomen und
  Blättern stritten sich um dieselbe Geste. Stattdessen rechnet die Lupe
  die Seite über `Exporter.pageView` (Druckmodus, Originalfotos) mit rund
  4000 px an der langen Seite (höchstens 300 dpi) und zeigt sie in einer
  `UIScrollView` (zwei Finger, Doppeltippen). Ein vergrößertes
  Vorschaubild wäre nur unscharf hochgezogen und sagte über den Druck
  nichts. Ohne Hilfslinien wird aufs Endformat beschnitten.
- **Ganzes Foto (`PhotoFit`, ab 1.0.9,** Ansage des Nutzers: Bilder, die
  nicht in den Rahmen passen, „wie bei einem WhatsApp-Status“): In
  `PhotoPlacement.fit` — „Füllen“ (wie bisher, schneidet ab), „Ganz +
  weich“ (dasselbe Foto weichgezeichnet dahinter) und „Ganz + Farbe“
  (`dominantColor` als Verlauf). Zoom dort 0,4…3 statt 1…4. Ein anderes
  Foto in derselben Fläche behält die Darstellung. `PhotoPlacement` hat
  seitdem ein eigenes `init(from:)` — der synthetisierte Decoder hätte
  alte Kalender ohne `fit` nicht mehr geöffnet.
- **Zwei-Finger-Zoom im Foto-Bearbeiten** (`MagnifyGesture`, gleichzeitig
  mit dem Ziehen).

- **Ferien (ab 1.0.10,** Ansage des Nutzers): Der Balken liegt am
  OBEREN Rand des Datumskästchens (Raster, Große Ziffern: über der Zahl,
  Zeitleiste: oben). Legende unten auf der Seite, Name am ersten Tag und
  Ferien in der Terminliste nur mit „Ferien benennen“
  (`DateSettings.nameSchoolHolidays`, Vorgabe AUS — „es reicht, wenn der
  Balken da ist“).
- **Wochentage haben eine eigene Größe** (`Design.weekdayScale`,
  `fontWeekday`). Vorher hingen Wochentagsnamen und Einträge zusammen an
  `bodyScale` („Text“); der Regler heißt jetzt „Einträge in den Kästchen“.
  Neue Wochentagsanzeigen immer mit `fontWeekday`, nie mit `fontBody`.

- **Sicherungsdatei „.kalenderstudio“ (ab 1.0.10,** Ansage des Nutzers:
  „eine Exportdatei, die ich auf einem anderen Gerät oder nach einem Umzug
  neu einladen kann“): `Model/Backup.swift`. Kennzeile, 8 Byte Länge,
  JSON-Verzeichnis (Kalender vollständig + Dateiliste), dann die Dateien
  roh hintereinander — kein ZIP (iOS packt keins aus), kein Base64 (bläht
  große Originale auf). Enthalten: Kalender, Fotos (Original + Vorschau),
  geladene Schriftdateien; selbst installierte Schriften gehören dem Gerät
  und fehlen. Laden überschreibt NIE: gleicher Kalender mit anderem Stand
  kommt als „(aus Sicherung)“ dazu, gleicher Stand wird übersprungen.
  Fotos, die nur in iCloud liegen, fehlen in der Sicherung und werden
  gezählt. Bedienung: Einstellungen › Sicherung (alle; laden) und langes
  Drücken auf einen Kalender (einzeln). Probe: `…:sicherung` schreibt und
  lädt im Simulator und meldet „Sicherungsprobe“ im Protokoll.
- **Startseite auf dem iPhone** (Bildschirmfoto des Nutzers, 1.0.9): Das
  Muster im Kopfband ist 900 pt breit gezeichnet und machte als Inhalt des
  `ZStack` das ganze Band so breit — Text abgeschnitten, Karten links aus
  dem Bild. Es liegt jetzt als `.background`. **Regel: Fest gezeichnete
  Muster nie als bestimmenden Inhalt, immer als Hintergrund.** Der
  Arbeitsablauf „Kalenderstudio ansehen“ kann seitdem auch den
  iPhone-Simulator (Eingabe `geraet`) und eine Auswahl von Proben.
- **Beschnitt** war immer unter Format › „Beschnitt je Seite“ einstellbar,
  wurde dort aber nicht gefunden; seit 1.0.10 auch beim Anlegen.

## Halbmonat, beidseitig (ab 1.0.12)

Ansage des Nutzers (11.10.2026): Monatskalender vom **Druckhaus Bochum**
(druckhaus-shop.de, Datenblatt „Monatskalender DIN A3 Hoch, 12 Monate + 1
Deckblatt, 4/4-farbig“), nach einem halben Monat umblättern, damit es ein
neues Bild gibt. Auf beiden Seiten der ganze Monat, die „richtige“ Hälfte
erkennbar.

- **Datenblatt:** Datenformat 303 × 426 mm, Endformat 297 × 420, 3 mm
  Beschnitt, 3 mm Sicherheitsabstand, Spiralbindung 20 mm oben, **26
  Seiten chronologisch in EINER PDF** (1 Deckblatt vorn, 2 Deckblatt
  Rückseite … 26). Vorlage „A3 hoch, Druckhaus Bochum“ in `PageFormat.presets`.
- **Seitenfolge** (`YearLayout.halfMonth`, `PageContent.halfMonth(i, h)`):
  Deckblatt, dann je Monat 1. und 2. Hälfte (die Rückseite des Deckblatts
  ist die 1. Januarhälfte, Ansage des Nutzers), zuletzt
  `.yearOverview` (Jahresübersicht) als Rückseite des 13. Blatts — 26 Seiten.
  Ohne Deckblatt 24 Seiten, keine Übersicht.
- **Teilung nach ganzen Wochen** (Ansage des Nutzers):
  `CalendarMath.halfSplit` = der Montag, der der Monatsmitte am nächsten
  liegt; zweite Hälfte ab diesem Montag. Keine Wochenzeile wird zerschnitten.
- **Darstellung:** `RenderContext.focus` = Tage der Hälfte. Alles außerhalb
  tritt zurück (`RenderContext.dimmed` 0,3, Einträge nur als Punkt, keine
  Wochenendtönung); im Raster eine Akzentleiste vor den aktiven Wochen; in
  der Kopfzeile „1.–16.“ und ●○ (`halfBadge`). Gilt in allen Kalendarien
  (Raster, Große Ziffern, Zeitleiste, Kreis, Liste, Terminliste).
- **Fotos:** 1. Hälfte Schlüssel `m<i>`, 2. Hälfte `m<i>b`.
- **Rückseiten NICHT gedreht** (Datenblatt: chronologisch, aufrecht). Für
  andere Druckereien gibt es im Export „Rückseiten auf den Kopf stellen“
  (`ExportOptions.flipBacks`, dreht jede zweite PDF-Seite um 180°).
- Probe: `-probe=half:<Kalendarium>:<Vorlage>:<Anteil>:ganz`.

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
- **DER ABGLEICH ÜBERSCHRIEB NEUERE ARBEIT MIT EINEM ÄLTEREN STAND
  (bis 1.0.9, behoben in 1.0.10).** Gemeldet 10.10.2026: „jedes
  Kalenderbild eingepasst … nicht gespeichert, alles wieder auf Füllen“ —
  die Arbeit eines Abends war weg. Zwei Fehler zusammen:
  1. Jedes Speichern startete einen EIGENEN `Task.detached` zum Schreiben;
     mehrere liefen gleichzeitig, ein älterer Stand konnte nach einem
     neueren in der Wolke landen.
  2. `merge` hielt einen Wolkenstand, der vom letzten Abgleichstand
     abwich, für eine Änderung von außen — auch wenn er ÄLTER war als die
     Arbeitskopie und von diesem Gerät selbst stammte (Echo). Bei „nur die
     Wolke hat geändert“ ersetzte er die Arbeitskopie still, ohne Kopie.
  Seitdem: Alle Wolkenzugriffe laufen über EINE serielle Schlange
  (`cloudQueue`, Lesen eingeschlossen). Ein Wolkenstand, der älter ist als
  die Arbeitskopie, ersetzt sie nie, wenn er ein eigenes Echo ist
  (`ownStamps`) oder hier seit dem Abgleich nichts geändert wurde — dann
  geht die Arbeitskopie wieder hinauf. **Regel: Ein Abgleich darf eine
  Arbeitskopie nur durch etwas NEUERES ersetzen.** Verlorene Einstellungen
  ließen sich nicht zurückholen.
- **`formatVersion` im Kalender** (ab 1.0.10, aktuell 4): Eine ältere
  App kennt neue Felder nicht und würde sie beim Zurückschreiben löschen
  (z. B. ein iPhone mit 1.0.8 die Fotodarstellung „ganz“). Kalender mit
  höherer `formatVersion` als `CalendarProject.currentFormat` schreibt
  eine App deshalb nicht in die Wolke. **Bei jedem neuen Feld im Modell
  `currentFormat` um eins heben.** Ältere, schon installierte Fassungen
  schützt das nicht — beide Geräte auf denselben Stand bringen.
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
- **Oster- und Pfingstsonntag stehen in JEDEM Land als Feiertag**
  (ab 1.0.11, Ansage des Nutzers: „Ostermontag und Pfingstmontag sind
  eingetragen, aber nicht der Ostersonntag und der Pfingstsonntag“).
  Gesetzlich sind sie es nur in Brandenburg — der Hinweis steht in der
  Liste; sie fallen ohnehin auf einen Sonntag. Die doppelten besonderen
  Tage „ostern“/„pfingsten“ sind dafür entfallen. **Heiligabend** (besonderer
  Tag, kein Feiertag) wird in alten Kalendern einmalig eingeschaltet
  (`DateSettings.catalogRevision` 2) — so kommen neue Pflicht-Tage auch in
  bestehende Kalender; dafür die Revision heben.
- Feiertagslisten (Stand 2026) wurden mit der OpenHolidays API
  abgeglichen. Bei Gesetzesänderungen (neuer Landesfeiertag)
  `HolidayCatalog.publicHolidays` anpassen.
