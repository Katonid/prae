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
- Oberfläche: „Kapitel" statt „Tage" in Kapitelliste und Kapitelinhalt,
  Plusmenü „Neuer Text… / Alle Texte… / Texte aus einer Datei…", „Ganzes
  Buch → Kapitel und Zeitraster…". Handbuch und Aufbau-Assistent sprechen
  noch vom Reisebuch (nicht angepasst).

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
  1.0.2 (3), 1.0.3 (4). `DEVELOPMENT_TEAM = F4989GSTWS`,
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
