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

- Bundle-Id `de.familie.chronik`, Homescreen „Kapitelweise", Store-Name
  „Kapitelweise – Das Buch" (getrennte Felder; App-Eintrag von Hand in App
  Store Connect anlegen). Ordner `ChronikiOS/`, Ziel/Schema „Chronik".
- **Keine iOS-Entitlements-Datei.** Das Reisebuch trägt iCloud und das
  Schriftenrecht — beides bewilligt für SEINE App-Id. Die App-Id dieser App
  trägt nichts davon (Regel im Wurzelverzeichnis: nur Rechte eintragen, die die
  App-Id nachweislich trägt; Lehre Reisebuch 1.0.44). Folge: kein
  iCloud-Abgleich (die App sagt „Nur auf diesem Gerät"), selbst installierte
  Schriften nicht lesbar. Soll das kommen: Fähigkeit in Xcode zufügen
  (Container `iCloud.de.familie.chronik`, steht schon in `Wolke.behaelter`).
  Die Mac-Datei `Config/Chronik-Mac.entitlements` trägt nur die
  Sandkasten-Rechte.
- Eigenes Dateiformat `.kapitelweise` (`de.familie.chronik.buch`) — nicht das
  des Reisebuchs, zwei Apps dürfen keinen Typ gemeinsam exportieren.
- Versionierung: `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION` je zweimal im
  pbxproj, je Arbeitseinheit Patch UND Build +1. Verlauf: 1.0.0 (1), 1.0.1 (2),
  1.0.2 (3). `DEVELOPMENT_TEAM = F4989GSTWS`, `ITSAppUsesNonExemptEncryption =
  NO` (Info.plist UND Build-Einstellung). Mac Catalyst wie im Reisebuch.

## Stand

- **1.0.2 (Build 3)**, 11/2026: Neuaufbau als Abwandlung des Reisebuchs.
  Bücher aus 1.0.0/1.0.1 (eigene Datei `Buecher.json`) werden NICHT übernommen
  — es waren Probebücher; Fotos neu einlesen. **Nicht gemessen:** auf keinem
  Gerät gesehen; ob die Kapitel-Einteilung bei tausenden Fotos je Jahr flüssig
  bleibt (das Reisebuch ist für Dutzende Fotos je Tag gebaut).
