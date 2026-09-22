# Stand des Repos `prae`

Stand: 22.09.2026. Diese Seite ist eine Übersicht, kein Ersatz für
`CLAUDE.md` — dort steht, WARUM etwas so gebaut ist, und das ist die
eigentliche Arbeitsgrundlage. Hier steht, WO alles steht und WIE weit es ist.

**Was hier nicht drinsteht, ist ausdrücklich nicht drin.** Wo eine Angabe
fehlt oder ungemessen ist, sagt diese Seite das, statt sie zu erfinden —
dieselbe Regel wie in den Apps selbst.

---

## 1. Ziel

Ein einzelnes Repo für eine Reihe von Anwendungen einer Familie und einer
Grundschule. Sie haben kein gemeinsames Produktziel, wohl aber eine
gemeinsame Bauweise:

* **Native Apps statt Web-Hüllen**, wo es auf Verlässlichkeit ankommt
  (Alarm, Fahrplan, Tafel, Reisebuch).
* **Keine fremden Abhängigkeiten.** Kein SDK, keine Bibliothek, kein
  Paketmanager — weder in den iOS-Apps noch in den Web-Apps. Was gebraucht
  wird (ZIP-Leser, PDF-Leser, PDF-Setzer, QR-Rechner, Töne, App-Symbole),
  ist selbst geschrieben oder selbst gerechnet.
* **Kein Schlüssel in einer App.** Was in einem Bündel steckt, ist kein
  Geheimnis. Wo ein Dienst einen Schlüssel verlangt, trägt ihn der Nutzer
  selbst ein (Schlüsselbund), oder der Dienst wird nicht benutzt.
* **Ehrlichkeit vor Bequemlichkeit.** Keine Zusage, die nicht gemessen ist;
  kein grünes Häkchen für „nicht nachgesehen"; jede Lücke wird benannt.
  Dieser Satz ist in diesem Repo mehrfach teuer bezahlt worden und steht
  deshalb in fast jedem Projektabschnitt von `CLAUDE.md` wieder.

## 2. Architektur

### Ordner

| Ordner | Art | Kurz |
| --- | --- | --- |
| `AlarmiOS/` | iOS | Schulalarm — Notfall- und Amokalarm, CloudKit |
| `AbfahrtstafeliOS/` | iOS | Abfahrtstafel + Verbindungsauskunft (ÖPNV) |
| `UrlaubstagebuchiOS/` | iOS | Reisebuch — Fotos + Text → gesetztes PDF |
| `TafelbildiOS/` | iOS | Klassenraum-Tafel, iCloud-Abgleich, Sitzplan |
| `TagesspuriOS/` | iOS | Standortaufzeichnung, Widgets, Watch |
| `ReisekasseiOS/` | iOS | Kassenbuch (App-Store-Name), App + Watch |
| `AnstossiOS/` | iOS | Fußball-Liveticker |
| `FlightMateiOS/` | iOS | Flugbegleiter, PRD in `docs/flightmate-ai/` |
| `SoundboardiOS/` | iOS | Theater-Soundboard |
| `PhotoSpotRadariOS/` | iOS | Foto-Spots aus OSM/Overpass + Wikipedia |
| `KartenwalletiOS/` | iOS | Eigene Karten in die Apple Wallet |
| `HimmelskompassiOS/` | iOS | Sonne/Mond-Kompass |
| `TankbuchiOS/` | iOS | Tankbuch |
| `CadUsdEuriOS/` | iOS | Währungsrechner CAD/USD → EUR |
| `NotfallalarmAndroid/` | Android | Alarm-App, Firebase-Backend |
| `klassenraum/` | Web | Tafel-Web-App (Vorläufer von Tafelbild) |
| `woerterwerkstatt/` | Web | Rechtschreibübungen, Firebase |
| `terminkonverter/` | Web | Tabelle/Word → `.ics` |
| `textauszug/` | Web | PDF → Text, Text → PDF/EPUB |
| `himmelskompass/`, `soundboard/`, `heute-in-der-naehe/` | Web | ältere Web-Fassungen |
| `docs/` | Pages | veröffentlichte Seiten (Datenschutz, Support, PRD) |
| `scripts/`, `.github/` | Werkzeug | Quelltextprüfung, Bau-Abläufe |

### Bauen

* **iOS:** `.github/workflows/ios-apps-build.yml` auf macOS-Läufern. Welche
  App gebaut wird, entscheidet `.github/scripts/welche-apps.py` in einem
  vorgeschalteten **Linux**-Auftrag — nicht mehr alle Apps bei jedem Push.
  Die App-Liste steht dort und **nur** dort.
* **Tafelbild** hat einen eigenen Ablauf (`tafelbild-build.yml`), dazu
  Bildschirmfoto- und Schriften-Abläufe, die nur auf Knopfdruck laufen.
* **Android:** `notfallalarm-build.yml`, Linux-Läufer.
* **Web:** `pages.yml` liefert `docs/` und die Web-Apps aus;
  `https://katonid.github.io/prae/…`.
* **Ein grüner Bau beweist NICHT, dass sich signieren lässt.** Gebaut wird
  gegen den Simulator mit `CODE_SIGNING_ALLOWED=NO`; Entitlements, Profile
  und App-Ids fallen erst auf dem Mac des Nutzers auf.

### Arbeitsweise

* Jede Arbeitseinheit endet mit einem **eigenen PR nach `main`**; gemergt
  wird vom Nutzer, nie von Claude.
* **Ein herausgegebener PR-Link friert diesen PR ein.** Alles Weitere
  beginnt mit `git fetch origin main` + Rebase und endet in einem NEUEN PR.
* Jede Arbeitseinheit mit App-Änderung hebt **Patch- und Build-Nummer**
  um je +1 (Ausnahmen: Tagesspur und Tafelbild vergeben die Build-Nummer
  über eine Skript-Bauphase).
* Vor jedem Push läuft `scripts/swift-quelltext-pruefen.py`; die Web-Apps
  haben ihre eigenen Prüfskripte (`module-pruefen.mjs`, `regeln-pruefen.py`,
  `qr-pruefen.py`).

---

## 3. Stand je Projekt

| Projekt | Fassung | Vertrieb | Stand |
| --- | --- | --- | --- |
| Schulalarm | 1.1.0 (Build 44) | App Store, Einreichung | zwei Ablehnungen beantwortet, Wiedervorlage |
| Abfahrtstafel | 1.1.30 (Build 43) | in Arbeit | läuft, laufende Befunde des Nutzers |
| Reisebuch | 1.0.36 (Build 37) | in Arbeit | Satzmaschine im Umbau, **aktive Baustelle** |
| Tafelbild | 1.4.6 | App Store, freigegeben | in Pflege |
| Kassenbuch | 1.0.17 (Build 18) | TestFlight/Store | in Pflege |
| Tagesspur | 1.4.27 | Store | in Pflege |
| Anstoß | 1.0.9 (Build 7) | Store-Eintrag angelegt | in Pflege |
| FlightMate | 1.3.1 (Build 4) | in Arbeit | PRD-gebunden |
| Notfallalarm (Android) | — | Sideload | Backend + App stehen |
| Wörterwerkstatt | 1.8.2 | Pages | in Betrieb |
| Terminkonverter / Textauszug | — | Pages | in Betrieb |
| Klassenraum (Web) | — | Pages | lebt neben Tafelbild weiter |
| Soundboard, Himmelskompass, Tankbuch, Währungsrechner, Kartenwallet, PhotoSpot Radar | siehe pbxproj | gemischt | **in `CLAUDE.md` nicht beschrieben** — Stand steht nur im jeweiligen README |

Die letzte Zeile ist kein Versehen: Für diese Apps gibt es keine
Entscheidungsgeschichte im Hauptpapier. Wer dort etwas ändert, liest zuerst
das README des Ordners und schreibt die Begründung nach.

---

## 4. Was fertig ist

**Schulalarm** — Auslösen, Rückmelden, Gruppenchat, Entwarnung, Verwaltung,
Prüfliste, Diagnose („Zustellung prüfen"), vier Alarmtöne plus eigener Ton,
kritische Hinweise, Austritt, Nutzungsbedingungen und Datenschutzseite.
Zwei Ablehnungen von Apple sind beantwortet: die Mitteilungen sind
freiwillig, und niemand wird mehr ausgesperrt.

**Abfahrtstafel** — Tafel um einen Punkt, Fahrtlauf mit Karte, Netzkarte,
Merkliste, Betriebsmeldungen samt gelesener Haltestellensperrungen,
Verbindungsauskunft mit Vergleichskarte, Dauerbalken, Filtern nach
Verkehrsmittel, Deutschland-Ticket und Fußweglänge, Fußwegmessung,
Quellenkette Transitous → Spiegel → Verbund → Zwischenspeicher.

**Reisebuch** — Einlesen (Text aus TXT/DOCX/PDF, Fotos einzeln oder als
Zeitraum, Tagesspur/GPX), automatische Verteilung auf Tage, Satz als
Mosaik, Karten aus vier Quellen, Druckvorlage als PDF mit TrimBox und
BleedBox, Druckprüfung, Broschürensatz, Formatwechsel mit Umrechnung,
iCloud-Abgleich, eigenes Austauschformat `.reisebuch`.

**Tafelbild** — Elemente auf mehreren Tafeln, Sitzplan samt Archiv,
Geburtstage mit Ritual und Fragenkatalogen, Zurücksetzen auf „unbenutzt",
privater iCloud-Abgleich, Freigabe per Einladungslink samt Rückfall ohne
öffentlichen Link, Löschrecht, Dokumentenkamera.

**Wörterwerkstatt** — fünf Übungsstufen, 123 Bereiche mit 1844 Wörtern,
Klassen mit QR-Code/Code/PIN, Auftrag der Woche, Wortprotokoll,
Schulverwaltung.

**Notfallalarm (Android)** — Datennachricht mit Alarm-Kanal, Foreground
Service, Selbsttest über den echten Weg, Checkliste für
herstellereigene Ruhezustände.

---

## 5. Was offen ist

### Reisebuch (die aktive Baustelle)

Die Satzmaschine ist in vier Fassungen hintereinander umgebaut worden
(1.0.33 → 1.0.36), jede auf einen Befund des Nutzers hin:

* 1.0.34 — die Seite entsteht aus dem INHALT des Tages (`Tagesplan`);
  `Seitenrhythmus` entfernt.
* 1.0.35 — Text ist ein Feld wie ein Foto, die Seite wird GEFÜLLT
  (`Mosaik`); `Seitenform` entfernt.
* 1.0.36 — eine Reihe ist ein Stapel, kein Raster: Drehung, Staffelung und
  überlappende Ecken sind zurück; das Wort „Bildunterschrift …" auf der
  Seite ist durch eine Marke ersetzt.

**Offen und ausdrücklich ungemessen:**

* Keine der Fassungen ab 1.0.34 ist auf einem Gerät gesehen worden. Alle
  Zahlen in `Tagesplan`, `Mosaik` und den Staffelmaßen sind **gewählt und
  nicht gemessen**.
* Ob die Schriften im PDF wirklich eingebettet werden, zeigt erst ein
  Ausdruck.
* Wie sich ein Buch mit zweihundert Fotos anfühlt (Zeichnen, Kopieren,
  Zeitraum-Einlesen), ist nicht gemessen.
* Text, der ein Foto auf BEIDEN Seiten umfließt, ist nicht gebaut —
  CoreText legt einen Rahmen in ein Rechteck. Vom Nutzer hingenommen.
* Kein CMYK-PDF; iOS kann das nicht. Nicht als lösbar versprechen.
* Der Befund zur „Regieanweisung" (1.0.36) ist am Quelltext hergeleitet
  und nicht am Buch des Nutzers nachgesehen.

### Schulalarm

* **Der Zustellnachweis** — ob ein Alarm auf einem gesperrten iPad mit
  aktivem Fokus binnen zehn Sekunden hörbar ankommt, lässt sich nur auf
  zwei echten Geräten messen. Protokoll: `AlarmiOS/docs/ZUSTELLTEST.md`.
  Scheitert es, ist der Ersatz ein eigener kleiner APNs-Sender hinter
  demselben Protokoll — kein anderes Backend.
* Die Einreichung bei Apple ist nach zwei Ablehnungen offen.

### Abfahrtstafel

* Das Zoom- und Gestenverhalten der Netzkarte ist in mehreren Anläufen
  bearbeitet worden; gemessen ist jeweils die Datenmenge oder der Aufbau,
  **nicht die Wirkung auf dem Gerät**.
* Österreichische EFA-Stellen ließen sich aus der Bauumgebung nicht
  erreichen und stehen deshalb nicht in der Tabelle.
* Für Niederlande, Tschechien, Dänemark und Frankreich gibt es keinen
  eigenen Rückfall — nur den Spiegel derselben Quelle.
* Eingetragene fremde Schlüssel schalten noch keine Abfahrten frei: Die
  Decoder fehlen, weil sich ohne Konto keine Antwort messen ließ.
* Geplante Streckensperrungen in der Zukunft stehen nicht in den Daten.

### Tafelbild

* Ob die Broschüren- und Freigabewege auf jedem Konto tragen, ist nur
  teilweise gemessen; „Teilen prüfen" ist genau dafür da.

### Repoweit

* Für sechs iOS-Apps und drei Web-Apps gibt es keine Entscheidungsgeschichte
  in `CLAUDE.md` (siehe Tabelle oben).

---

## 6. Bekannte Probleme und Fallen

Die vollständige Liste steht in `CLAUDE.md`. Was am häufigsten zugeschlagen
hat:

1. **Ein Kommentar ersetzt keine Prüfung.** Mehrfach stand die Falle
   wörtlich im Quelltext beschrieben, und die Prüfung fehlte trotzdem
   (Schulalarm `requestAuthorization`, Abfahrtstafel-Navigationsziele,
   Reisebuch `Zoomanker`, Papierkorn).
2. **Eine berechnete Eigenschaft sieht billig aus.** In drei Projekten lief
   ein voller Suchlauf bei jedem Neuzeichnen.
3. **Wo eine Schnittstelle je Element ein Ergebnis zurückgibt, IST das
   Ergebnis die Fehlermeldung** (CloudKit `modifySubscriptions`,
   `modifyRecords`).
4. **Ein falscher Parametername fällt nicht auf.** MOTIS nimmt ihn mit
   HTTP 200 an und ignoriert ihn — geprüft wird am INHALT der Antwort, nie
   am Status. Dreimal getroffen.
5. **Ein neues nicht-optionales Feld macht jede gesicherte Datei unlesbar.**
   Deshalb Leser von Hand (`Nachsicht.swift`, `nachsichtigeListe`).
6. **Ein Knopf, den niemand findet, ist kein Knopf** — und ein Knopf, der
   im Fehlerfall schweigt, ist für den Menschen davor kaputt. Dieser Befund
   ist in Tafelbild, Schulalarm, Abfahrtstafel und Reisebuch je mehrfach
   gekommen.
7. **Eine Vermutung als Diagnose auszugeben.** Mehrfach passiert, mehrfach
   vom Nutzer widerlegt. Daraus folgt Punkt 8.
8. **Wo sich eine Ursache nicht erschließen lässt, muss eine PROBE
   entscheiden** — Schulalarms Stufenprobe, der Kartenmesser der
   Abfahrtstafel, der Zeichenmesser und die Bedienungsprobe des Reisebuchs.

---

## 7. Getroffene Entscheidungen

* **CloudKit für Schulalarm** (öffentliche Datenbank) hinter EINEM Protokoll
  — damit ein Wechsel eine Datei kostet, sobald Android dazukommt. Die
  Grenzen der öffentlichen Datenbank werden offen benannt.
* **Private CloudKit-Datenbank für Tafelbild** (seit 1.0.58); daran hängen
  Datenschutzangaben und `PrivacyInfo.xcprivacy`.
* **iCloud Drive statt CloudKit für das Reisebuch** — ein Buch ist eine
  kleine JSON-Datei plus zweihundert große Bilder, und genau dafür ist ein
  Dateiabgleich gebaut.
* **Firebase (RTDB, REST) für die Web-Apps**; kein SDK, damit der
  Offline-Betrieb hält. Die Regeln liegen gemeinsam in
  `firebase-rules.json` im Wurzelverzeichnis — wer nur einen Zweig
  einfügt, sperrt die andere App aus.
* **Transitous (MOTIS) als erste Fahrplanquelle**, mit gemessener Kette
  darunter. Keine Quelle in der Kette, die nicht an einer echten Antwort
  gemessen wurde.
* **Kein Word, kein Pages und kein CMYK im Reisebuch-Druckweg**; PDF über
  `CGContext`, weil nur so TrimBox und BleedBox gesetzt werden können.
* **Alles Selbstgerechnete statt Nachgeladenem:** Töne, App-Symbole,
  QR-Codes, ZIP, PDF, Schriftmaße.
* **Deutsche Oberfläche, deutscher Quelltext** (Ausnahme: Android — dort
  Quelltext englisch, Oberfläche deutsch).

---

## 8. Nächste Schritte

1. **Reisebuch:** Rückmeldung des Nutzers zu 1.0.36 abwarten — sieht eine
   Doppelseite mit gedrehten, überlappenden Bildern nach „hingelegt" aus
   oder nach „verrutscht"? Danach die Zahlen (Überlappung, Staffelhub,
   Winkel) nachziehen. Erst danach lohnt ein gedruckter Probebogen.
2. **Reisebuch:** Ein PDF auf einem Gerät erzeugen und auf
   Schrifteinbettung prüfen — der älteste offene Punkt dieses Projekts.
3. **Schulalarm:** Zustelltest auf zwei echten Geräten nach
   `AlarmiOS/docs/ZUSTELLTEST.md`; danach die Einreichung fortsetzen.
4. **Abfahrtstafel:** Die Zoom-Erklärungen auf einem Gerät gegenprüfen
   (`Karte prüfen` liefert die Zahlen); österreichische EFA-Stellen aus
   einer Umgebung mit freierem Netz nachmessen.
5. **Repoweit:** Für die sechs undokumentierten iOS-Apps je einen kurzen
   Abschnitt in `CLAUDE.md` anlegen, sobald dort das nächste Mal gearbeitet
   wird — die Begründung gehört ins Papier, bevor sie vergessen ist.
