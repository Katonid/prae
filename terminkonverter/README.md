# Terminkonverter

Wandelt eine Excel-Tabelle mit Terminen (**Datum** und **Beschreibung**) in
eine Kalenderdatei (`.ics`) um, die sich in Apple Kalender, Outlook, Google
Kalender und jeden anderen Kalender importieren lässt.

Adresse: https://katonid.github.io/prae/terminkonverter/

## Was hineingeht

| Datum | Beschreibung |
| --- | --- |
| 01.09.2026 | Erster Schultag |
| 14.09.2026 19:30 | Elternabend |
| 05.01.2027 – 07.01.2027 | Skifreizeit |
| 3. März 2027 9:00-10:30 | Zeugniskonferenz |

- Erkannt werden echte Excel-Datumszellen, `01.09.2026`, `1.9.26`,
  `2026-09-01`, `01/09/2026` und `1. September 2026`; ein Wochentag davor
  („Mo, 01.09.2026") stört nicht.
- Mit Uhrzeit wird ein Termin mit Uhrzeit daraus, ohne Uhrzeit ein
  ganztägiger. Eine Uhrzeit in der Beschreibung („Elternabend 19:30") zählt
  auch — aber nur mit Doppelpunkt oder dem Wort „Uhr".
- Zwei Daten in einer Zelle (oder in einer dritten Spalte) ergeben einen
  mehrtägigen Termin.
- Welche Spalte links steht, ist gleich: Gesucht wird die Zelle, die sich als
  Datum lesen lässt — alles Übrige wird zur Beschreibung.
- Eine Überschriftenzeile darf stehen bleiben. Zeilen ohne erkennbares Datum
  werden nicht still verschluckt, sondern unter „Übergangene Zeilen" gezeigt.
- Neben `.xlsx`/`.xlsm` geht auch `.csv` (Semikolon, Komma oder Tabulator).
  Das alte Binärformat `.xls` nicht — das muss einmal als `.xlsx` gespeichert
  werden.

## Die fertige Datei

Der Knopf **„Kalenderdatei sichern (.ics)"** legt die Datei bei den Downloads
ab — sie wird nicht sofort in den Kalender geschoben. Erst ein Doppelklick
darauf fragt, in welchen Kalender die Termine sollen; vorher lässt sie sich
weitergeben, aufheben oder ansehen („Text anzeigen").

Auf iPhone und iPad steht daneben **„Teilen / In Dateien sichern"** — dort
heißt Sichern so, und von dort geht die Datei auch per Mail oder AirDrop
weiter.

## Wie es gebaut ist

Statische Web-App, keine Abhängigkeit, kein Bauschritt, kein Server. Sie wird
vom Pages-Arbeitsablauf des Repos mit ausgeliefert.

| Datei | Aufgabe |
| --- | --- |
| `js/zip.js` | Liest das ZIP-Archiv einer `.xlsx` — mit `DecompressionStream`, wo es das gibt, sonst mit eigenem Inflate. |
| `js/xlsx.js` | Zerlegt Blatt, Zeichenketten und Zahlenformate zu Zellen; liest auch CSV. |
| `js/termine.js` | Macht aus Zeilen Termine (Datums- und Zeiterkennung). |
| `js/ics.js` | Schreibt die `.ics` nach RFC 5545. |
| `js/app.js` | Oberfläche: Datei annehmen, Vorschau, Herunterladen. |

Zwei Stellen, an denen es leicht schiefgeht:

- **Ob eine Zahl ein Datum meint, steht in `.xlsx` nicht am Wert, sondern am
  Zahlenformat.** Ohne `styles.xml` wäre der 31.08.2026 einfach 46265.
- **Gefaltet wird die `.ics` nach Oktetten, nicht nach Zeichen.** Ein Umlaut
  zählt zwei; eine mitten im Zeichen geteilte Zeile macht aus „für"
  Buchstabensalat.
- **Der Blob heißt `application/octet-stream`, nicht `text/calendar`.** Bei
  `text/calendar` reicht Safari die Datei sofort an die Kalender-App weiter,
  statt sie zu sichern — und dann liegt sie nirgends. Was die Datei ist, sagt
  die Endung.

Zeiten stehen bewusst ohne Zeitzone („schwebend"): Ein Termin um 8 Uhr ist um
8 Uhr, egal wie das Gerät gerade eingestellt ist.

Die Datei bleibt auf dem Gerät — es wird nichts hochgeladen und nichts
gespeichert.
