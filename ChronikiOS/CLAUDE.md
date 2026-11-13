# Projekt Kapitelweise – Das Buch (Ordner/Ziel „Chronik", native iOS-App)

> Die übergreifenden Regeln (PR-Rhythmus, iOS-Pflichten, Bau in GitHub
> Actions) stehen in der `CLAUDE.md` im Wurzelverzeichnis und gelten hier
> genauso.

## Was diese App ist: eine Abwandlung des Reisebuchs

**Ab 1.0.2 ist Kapitelweise eine KOPIE des Reisebuchs** (`UrlaubstagebuchiOS/`,
Stand Reisebuch 1.0.128). Ansage des Nutzers 11/2026: „Die Reisebuch-App ist
mittlerweile perfekt für die Gestaltung von Urlaubstagebüchern. Aber diese App
hier soll ja eigentlich gar nicht so viel anders sein. Die Quelle der Daten ist
halt eine andere und es soll nicht nach Tagen, sondern nach anderen Zeiträumen
sortiert werden. … Hier habe ich das Gefühl, als ob wir wieder bei Null
anfangen würden. … Modifiziere die Reisebuch-App nur dahingehend, dass der
Import von Daten so stattfinden kann, wie ich es dir anfangs beschrieben habe."

1.0.0–1.0.1 waren ein Neubau von Grund auf (eigener Seitensatz, eigene
Vorschau). Er ist verworfen: In der Seitenübersicht ließ sich nichts machen,
eine Seite öffnete sich nicht groß, Blöcke ließen sich nicht anfassen — alles,
was das Reisebuch in 128 Fassungen gelernt hat. **Nicht wieder neu bauen.**

**Deshalb gilt `UrlaubstagebuchiOS/CLAUDE.md` hier vollständig** — jede Lehre,
jede Falle, jede Regel (Tagesdatum aus drei Zahlen, Seite und PDF aus einem
Setzer, wortlautSichern, Handarbeit, Druck …). Vor jeder Änderung dort lesen.
Wo ein Name „Tag" sagt, ist hier ein Kapitel gemeint.

**Was das Reisebuch später lernt, wird NICHT automatisch übernommen.** Die
beiden Apps sind getrennte Ordner. Eine Verbesserung dort hierher zu holen
heißt, die betreffenden Dateien zu vergleichen — die Abweichungen unten sind
klein und stehen alle mit „KAPITELWEISE" im Quelltext.

## Die Abweichungen vom Reisebuch (alle mit „KAPITELWEISE" markiert)

- **Ein „Tag" ist ein KAPITEL** (`Reisetag`, Feld `datum` = Beginn des
  Abschnitts). Das Zeitraster steht in `Reise.zeitraster`
  (`Model/Zeitraster.swift`): Einheit × Anzahl ab einem Beginn, Vorgaben
  Kalenderjahr (**Grundeinstellung**), Schuljahr (1. August), Halbjahr,
  Quartal, Monat, Woche, eigenes Raster. Gerechnet mit dem Kalender, jeder
  Kapitelbeginn vom Beginn aus (nicht vom Vorgänger).
- **Die Zuordnung geschieht an EINER Stelle: `Reise.tagIndex(fuer:)`.** Darüber
  laufen Fotoeinfuhr, Texteinfuhr, Spureinfuhr, Fernweh und „Kapitel anlegen".
  Ein neues Kapitel bekommt die Überschrift aus dem Raster („2009",
  „1. Quartal 2024"), den Zeitraum als Datumszeile (`datumstext`) und
  `karteZeigen = false` (ein Jahr mit Fotos von überall ergäbe ein Knäuel).
- **Texte sind EINTRÄGE mit Zeitstempel** (`Model/Texteintrag.swift`,
  `Reise.eintraege`). Der Kapiteltext wird daraus zusammengesetzt
  (`Reise.kapiteltext`: je Eintrag eine Kopfzeile „Überschrift – Datum", dann
  der Text). **`wortlautSichern` holt bei einem Kapitel mit Einträgen nichts
  von der Seite zurück**, sondern setzt den Text aus den Einträgen neu —
  sonst überschriebe der alte Wortlaut der Seite jeden geänderten Eintrag.
  Folge: Text wird über die Einträge bearbeitet, nicht im Textblock.
- Die Texteinfuhr aus einer Datei (`textVerteilen`) macht aus jedem
  Datumsabschnitt einen Eintrag (früher: Text eines Tages).
- `Dienste/Kapitelwerk.swift`: `eintragSichern`/`eintragLoeschen` (setzen das
  Kapitel neu, außer bei Handarbeit — dann eine Meldung), `rasterSetzen` und
  `kapitelNeuEinteilen` (Fotos nach Aufnahmetag, Einträge nach Zeitstempel;
  alle Seiten neu, Handarbeit fällt weg — steht vorher in der Oberfläche,
  „Widerrufen" holt zurück), `pdfEinfuegen`.
- **PDF-Dateien** gehen über „Bild oder PDF aus Dateien": jede PDF-Seite wird
  eine eigene, von Hand angelegte Buchseite mit der Seite als Bild (2400 px,
  ~300 dpi auf A4) im Satzspiegel. Freie Seiten an beliebiger Stelle gibt es
  über die Seitenliste des Reisebuchs (`seiteEinfuegen`).
- **Sprachliche Überarbeitung** (`Dienste/Sprachhilfe.swift`,
  `Views/EintragView.swift`): vier Arten; Apple Intelligence auf dem Gerät
  (`FoundationModels`, iOS 26, hinter `#if canImport` + `#available`, Texte in
  Stücken ≤ 1800 Zeichen) oder über einen KI-Chat per Zwischenablage. Erst
  Vorschlag, dann „Übernehmen"; die vorige Fassung bleibt (`vorfassung`).
- **Fotos aus einem ALBUM der Galerie** (ab 1.0.5, Ansage des Nutzers 11/2026):
  „Fotos aus der Mediathek…" hat neben dem Zeitraum einen Abschnitt „Alle
  Fotos eines Albums" (`Albumeinfuhr` in `Dienste/Zeitraumeinfuhr.swift`):
  eigene Alben und Favoriten, leere nicht; eingelesen über denselben Weg wie
  der Zeitraum (`Zeitraumeinfuhr.rohbild` → `fotosAufnehmen`), also mit
  Kapitel nach Aufnahmedatum. Braucht den Mediathekszugriff. Doppelt
  eingelesene Fotos findet „Doppelte Fotos" (aus dem Reisebuch).
- Oberfläche: „Kapitel" statt „Tage" in Kapitelliste und Kapitelinhalt,
  Plusmenü „Neuer Text… / Alle Texte… / Texte aus einer Datei…", „Ganzes
  Buch → Kapitel und Zeitraster…". Handbuch und Aufbau-Assistent sprechen
  noch vom Reisebuch (nicht angepasst).

## Das Lebensbuch (ab 1.0.4)

Vorlage des Nutzers 11/2026 (PDF „Simon 18", sechs Seiten, ein Buch zum 18.
Geburtstag des Sohnes): „Für jeden seiner Geburtstage die Titelseite einer
lokalen Tageszeitung … einzelne Meldungen zur Weltgeschichte an diesem Tag …
dann Fotos aus diesem Lebensjahr … relativ groß, aber doch leicht
überlappend angeordnet." Umgesetzt — alles über gewöhnliche Blöcke, also mit
allem, was das Reisebuch an Bearbeitung, Prüfung und PDF kann:

- **Zeitraster „Lebensjahr (ab Geburtstag)"** (`Zeitraster.Vorgabe.lebensjahr`,
  Beginn = Geburtsdatum, dazu `Reise.person`). Ein Kapitel heißt nach dem Jahr
  des Geburtstags („2019", nicht „2019/20"), die zweite Überschrift sagt
  „Simon wird 10 Jahre alt" (`Reise.alterszeile`), die Datumszeile ist der
  Geburtstag, die Zeitungsüberschrift „Der Tag deines 10. Geburtstags".
- **Stil „Lebensbuch"** (`Buchstil.lebensbuch`, erster in der Liste und
  Vorgabe neuer Bücher, dazu Kopfzeile an und A4 hoch): Cremepapier, Didot
  fett in Nachtblau, Gold als Akzent, Iowan kursiv, Unterschriften in
  Handschrift, Fotos mit weißem Rand, Schatten, gedreht.
- **Kopfzeile „KAPITEL 2019"** mittig, gesperrt, in der Akzentfarbe
  (`Seitenbeiwerk`) — für jeden Stil, sobald die Kopfzeile an ist.
- **Je Kapitel** (`Reisetag.zeitung`, `.zeitungstitel`, `.zeitungstext`,
  `.meldungen`, Oberfläche `KapitelseitenView`, erreichbar im Kapitelinhalt):
  die Zeitungsseite (Titelseite groß rechts, −1,2° gedreht; links Goldstrich,
  Überschrift, Text) und „Was an diesem Tag geschah" (2×2 je Seite: Bild,
  Goldbalken, Überschrift, Text). Die Bilder sind GRAFIKEN (`Foto.grafik`), aus
  Mediathek oder Dateien; aus einer PDF zählt die erste Seite.
- **Satz im Lebensbuch** (`Layoutautomat.lebensseiten`, Erweiterung am Ende von
  `Layoutautomat.swift`): Zeitung → Meldungen → Fotoseiten → Text. Fotoseiten:
  im Wechsel 4, 5, 3, 4, 5, 2 Fotos in festen, sich überlappenden Feldern
  (`albumfelder`), jedes Foto eingepasst und 6 % größer, gedreht
  (`drehwinkel` × 0,8), Ebene steigend. Der Kapiteltext kommt ans Ende: links
  eine Spalte (42 %), rechts die letzten vier Fotos. Trägt ein Kapitel ein
  eigenes Seitenmuster, setzt es wie im Reisebuch; Zeitung und Meldungen kommen
  in JEDEM Stil vor die Seiten.
- **Die große Jahreszahl steht NUR auf der Geburtstagsseite** (ab 1.0.6,
  Ansage des Nutzers zu Bildschirmfotos: „Die große Jahreszahl muss nicht auf
  jeder Seite stehen. Dort steht ja bereits kleiner ‚Kapitel [Jahreszahl]'.").
  Geburtstagsseite = die Zeitungsseite, sonst die erste Fotoseite. Meldungen
  und Kapiteltext tragen eine Überschrift ohne Jahr (`seitenueberschrift`),
  weitere Fotoseiten gar keine.
- **Doppelseiten-Ansicht folgt dem Produkt** (ab 1.0.6, Frage des Nutzers:
  „Das von mir eingestellte Format will eigentlich Doppelseiten. Warum werden
  trotzdem Einzelseiten angezeigt?"). Die Ansicht war eine eigene Einstellung
  (`@AppStorage("doppelseiten")`, Umschalter unten links). Verlangt
  `Druckprodukt.produkt(format.vorlage)` Doppelseiten, schaltet `ReiseView`
  beim Öffnen und beim Wechsel des Produkts auf Doppelseiten
  (`ansichtNachProdukt`); zurück geht es unten links.
- **Zeitung und Meldungen sind direkt erreichbar** (ab 1.0.7, Rückmeldung
  des Nutzers: „Ja, das ist zu versteckt."): oben im Kapitel-Menü (Knopf unten
  rechts) und im Plusmenü, je als `Blatt.kapitelseiten`. Der Kapitel-Knopf
  heißt „Kapitel 2026" statt eines Datums.
- **Texte stehen nach ihrem DATUM zwischen den Fotos** (ab 1.0.8, Ansage des
  Nutzers: „Ein Text zum 16.10. soll an der Stelle erscheinen, an der auch
  Fotos zum 16.10. sind."). `Reise.automat` reicht die Einträge je Kapitel
  durch (`Layoutautomat.kapiteltexte`); `chronologisch` legt Fotos (nach
  `aufnahme`) und Einträge (nach `zeit`) in eine Folge — bei gleicher Zeit
  zuerst der Text, Fotos ohne Zeit ans Ende. Fotos davor → Fotoseiten,
  Einträge (aufeinanderfolgende zusammen) → Textseite mit den bis zu drei
  Fotos, die unmittelbar folgen. Ein Kapitel ohne Einträge (nur freier Text)
  setzt wie bisher den Text ans Ende. Gilt im Lebensbuch; die anderen Stile
  setzen wie das Reisebuch (Text am Stück).
- **Nicht gebaut:** die Titelseite der Vorlage (Filmstreifen, Collage) — sie
  ist ein gemaltes Plakat; die Titelseite bleibt die des Reisebuchs (Titelbild
  plus Schrift). Ebenso der QR-Code-Kasten und die Stadtsilhouette.

## Konfiguration

- **Bundle-Id `de.familie.kapitelweise`** (ab 1.0.3; gemeldet 11/2026: der
  Upload zu TestFlight scheiterte, weil `de.familie.chronik` bereits vergeben
  war). Homescreen „Kapitelweise", Store-Name „Kapitelweise – Das Buch"
  (getrennte Felder; den App-Eintrag von Hand in App Store Connect anlegen,
  nie über Xcodes „Create App Record"). Ordner `ChronikiOS/`, Ziel/Schema
  „Chronik" bleiben. Ist auch diese Id vergeben, eine andere wählen und an
  ALLEN Stellen mitziehen: pbxproj (2×), beide Entitlements, `Info.plist`
  (Behälter und Dateityp), `Wolke.behaelter`.
- **iCloud-Abgleich und selbst installierte Schriften** (ab 1.0.3, Ansage
  des Nutzers 11/2026). `Config/Chronik.entitlements`: Behälter
  `iCloud.de.familie.kapitelweise` (CloudDocuments, wie das Reisebuch) und
  `com.apple.developer.user-fonts` = `app-usage`. **Nicht gemessen, dass die
  App-Id beides trägt** — der Nutzer bestätigt es einmal in Xcode (Signing &
  Capabilities: „iCloud" mit dem Behälter angehakt, „Fonts" mit „Use
  Installed Fonts"). Was das Profil danach wirklich bewilligt, nennt die App
  unter „Schriften prüfen" (`Profilrechte`); steht dort etwas anderes als in
  der Datei, gilt die Anzeige, und die Datei wird angeglichen (Lehre Reisebuch
  1.0.44/1.0.45/1.0.66). Der iCloud-Ordner heißt im Laufwerk „Kapitelweise",
  darin `Buecher` (`Wolke.ordnername`).
- Mac (`Config/Chronik-Mac.entitlements`): Sandkasten-Rechte des Reisebuchs,
  dazu `device.audio-input` (Mikrofon fürs Diktat) und derselbe Behälter.
- **Diktieren** (`Dienste/Diktat.swift`, unverändert aus Fernweh 1.0.40 bis auf
  den Text der Fehlermeldung; Knopf im Texteditor `EintragView`). Ab iOS 26
  `SpeechAnalyzer`, davor `SFSpeechRecognizer`, beides auf dem Gerät; als
  Hinweise gehen Buchtitel, Kapitel- und Textüberschriften mit.
  Berechtigungstexte (Mikrofon, Spracherkennung) als Build-Einstellung.
  Verbesserungen dort in Fernweh gehören auch hierher.
- Eigenes Dateiformat `.kapitelweise` (`de.familie.kapitelweise.buch`) — nicht
  das des Reisebuchs, zwei Apps dürfen keinen Typ gemeinsam exportieren.
- Versionierung: `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION` je zweimal im
  pbxproj, je Arbeitseinheit Patch UND Build +1. Verlauf: 1.0.0 (1), 1.0.1 (2),
  1.0.2 (3), 1.0.3 (4), 1.0.4 (5), 1.0.5 (6), 1.0.6 (7), 1.0.7 (8), 1.0.8 (9). `DEVELOPMENT_TEAM = F4989GSTWS`,
  `ITSAppUsesNonExemptEncryption = NO` (Info.plist UND Build-Einstellung).
  Mac Catalyst wie im Reisebuch.

## Stand

- **1.0.2 (Build 3)**, 11/2026: Neuaufbau als Abwandlung des Reisebuchs.
  Bücher aus 1.0.0/1.0.1 (eigene Datei `Buecher.json`) werden NICHT übernommen
  — es waren Probebücher; Fotos neu einlesen. **Nicht gemessen:** auf keinem
  Gerät gesehen; ob die Kapitel-Einteilung bei tausenden Fotos je Jahr flüssig
  bleibt (das Reisebuch ist für Dutzende Fotos je Tag gebaut).
- **1.0.3 (Build 4)**, 11/2026: Bundle-Id `de.familie.kapitelweise`,
  iCloud-Abgleich und Schriftenrecht eingetragen, Diktieren aus Fernweh.
  **Nicht gemessen:** Signieren mit den neuen Rechten, Abgleich, Diktat.
- **1.0.4 (Build 5)**, 11/2026: Lebensbuch (Stil, Lebensjahr-Raster, Zeitung,
  Meldungen, überlappende Fotoseiten). **Nicht gemessen:** wie die Seiten auf
  dem Gerät aussehen; die Felder der Fotoseiten sind gerechnet, nicht
  angesehen.
- **1.0.5 (Build 6)**, 11/2026: Fotos aus einem Album der Galerie einlesen.
  **Nicht gemessen:** auf einem Gerät.
- **1.0.6 (Build 7)**, 11/2026: große Jahreszahl nur auf der Geburtstagsseite,
  Doppelseitenansicht nach Produkt. **Nicht gemessen:** auf einem Gerät.
- **1.0.7 (Build 8)**, 11/2026: Zeitung und Meldungen im Kapitel- und
  Plusmenü, Kapitel-Knopf mit Kapitelname. **Nicht gemessen:** auf einem Gerät.
- **1.0.8 (Build 9)**, 11/2026: Texte nach Datum zwischen den Fotos.
  **Nicht gemessen:** auf einem Gerät.
