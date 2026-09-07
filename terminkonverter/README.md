# Terminkonverter

Wandelt Termine (**Datum** und **Beschreibung**) aus einer Excel-Tabelle oder
aus den Tabellen eines Word-Dokuments in eine Kalenderdatei (`.ics`) um, die
sich in Apple Kalender, Outlook, Google Kalender und jeden anderen Kalender
importieren lässt.

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
  mehrtägigen Termin — auch in Kurzform: `12.-14.10.2026`, `10./11.07.2027`,
  `17.10.- 31.10.2026`. Fehlt beim ersten Datum die Jahreszahl, gilt die des
  zweiten; über den Jahreswechsel hinweg um eins versetzt (`28.12.-04.01.2027`
  beginnt 2026).
- Uhrzeiten in der Beschreibung werden mitgenommen, auch als Spanne:
  `19:30`, `8.30 Uhr`, `12.00 h`, `9-15.30 Uhr`, `von 8:00 – 11:30 Uhr`. Ohne
  „Uhr" oder Doppelpunkt zählt eine Zahl nicht als Zeit.
- Welche Spalte links steht, ist gleich: Gesucht wird die Zelle, die sich als
  Datum lesen lässt — alles Übrige wird zur Beschreibung.
- Eine Überschriftenzeile darf stehen bleiben. Zeilen ohne erkennbares Datum
  werden nicht still verschluckt, sondern unter „Übergangene Zeilen" gezeigt.
- Neben `.xlsx`/`.xlsm` gehen `.docx` und `.csv` (Semikolon, Komma oder
  Tabulator). Die alten Binärformate `.xls` und `.doc` nicht — die müssen
  einmal als `.xlsx` bzw. `.docx` gespeichert werden.

## Word-Dokumente

Aus einer `.docx` werden die **Tabellen** gelesen, auch mehrere in einem
Dokument. Der Fließtext drumherum — Anrede, Erklärungen, Grußformel — bleibt
liegen; ihn als „übergangene Zeilen" zu melden, wäre lauter Lärm.

In der Spalte „Herkunft" steht dann `2.3` für die dritte Zeile der zweiten
Tabelle. Verschachtelte Tabellen werden zu eigenen Zeilen; nummeriert wird in
der Reihenfolge, in der die Zeilen im Dokument fertig werden.

Hat ein Dokument gar keine Tabelle, werden ersatzweise die **Absätze**
durchgesehen: Jeder Absatz mit einem Datum wird ein Termin.

## Ändern vor dem Sichern

Ein Tipp auf die Beschreibung öffnet ein Blatt: **Text, Datum, Enddatum und
Uhrzeiten** lassen sich dort ändern, der Termin lässt sich aus der Liste
nehmen. Geänderte Zeilen sind als solche gekennzeichnet. „+ Termin
hinzufügen" legt einen von Hand an, und jede übergangene Zeile hat einen Knopf
„Als Termin übernehmen" — praktisch bei Zeilen, in denen im Dokument nur der
Tag fehlt (`.03.2027 Personalversammlung`).

Geändert wird immer nur, was in den Kalender geht; die eingelesene Datei
bleibt unangetastet.

## Auf dem Homescreen

Die App ist installierbar: Manifest, Icons in allen gebrauchten Größen und ein
Service Worker, der sie auch ohne Netz starten lässt.

* **iPhone/iPad:** in Safari öffnen → Teilen → „Zum Home-Bildschirm".
* **Android:** Chrome-Menü → „App installieren".
* **Rechner:** Chrome/Edge zeigen ein Installieren-Zeichen in der Adresszeile.

Die Icons erzeugt `scripts/generate-icons.py` (reines Python, ohne fremde
Bibliotheken) — nicht von Hand bearbeiten. PNG ohne Alphakanal, sonst legt iOS
das Icon auf Schwarz. **Nach jeder Änderung an den Dateien die Fassungsnummer
`FASSUNG` in `sw.js` hochzählen**, sonst bleibt der alte Zwischenspeicher
stehen.

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
| `js/docx.js` | Holt die Zeilen aus den Tabellen eines Word-Dokuments. |
| `js/xml.js` | Entitäten und Textzugriff, von beiden Lesern benutzt. |
| `js/termine.js` | Macht aus Zeilen Termine (Datums- und Zeiterkennung). |
| `js/ics.js` | Schreibt die `.ics` nach RFC 5545. |
| `js/app.js` | Oberfläche: Datei annehmen, Vorschau, Ändern, Herunterladen. |
| `sw.js` | Service Worker fürs Offline-Starten (`FASSUNG` hochzählen!). |
| `scripts/generate-icons.py` | erzeugt `icons/` — gerechnet, ohne fremde Bibliothek. |

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
