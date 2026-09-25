# Projekt Terminkonverter (Web-App, Excel → iCal)

> Ausgelagert aus der `CLAUDE.md` im Wurzelverzeichnis (09/2026). Die
> übergreifenden Regeln (PR-Rhythmus, iOS-Pflichten, Bau in GitHub
> Actions) stehen weiterhin dort und gelten hier genauso.


- Code: `terminkonverter/` — statische Web-App ohne Bauschritt (ES-Module,
  kein Framework, keine fremde Bibliothek), wird vom Pages-Arbeitsablauf mit
  ausgeliefert: https://katonid.github.io/prae/terminkonverter/
  Nimmt eine Tabelle mit Datum und Beschreibung und gibt eine `.ics` aus.
  Ausführlich: `terminkonverter/README.md`.
- **Termine lassen sich vor dem Sichern ändern** (Blatt `#blatt` in
  `index.html`, `blattOeffnen` in `js/app.js`): Text, Datum, Enddatum,
  Uhrzeiten; dazu „+ Termin hinzufügen" und je übergangener Zeile „Als Termin
  übernehmen" — Letzteres ist der Ausweg für Zeilen, in denen im Dokument nur
  der Tag fehlt (`.03.2027 Personalversammlung`, echter Fall 09/2026).
  **Die Beschreibung ist ein KNOPF** (`.zeilenknopf`, gepunktet unterstrichen,
  mit Stift dahinter) — dieselbe Lehre wie beim Gruppenchat in Schulalarm: Ein
  Knopf, den niemand findet, ist kein Knopf.
- **Die App ist installierbar** (`manifest.webmanifest`, `sw.js`, `icons/`).
  Der Service Worker fragt IMMER erst beim Server nach und greift nur ohne
  Netz auf den Zwischenspeicher zurück; **`FASSUNG` in `sw.js` bei jeder neuen
  Fassung hochzählen**. Die Icons rechnet `scripts/generate-icons.py` (reines
  Python, ohne fremde Bibliothek) — PNG ohne Alphakanal, sonst legt iOS das
  Homescreen-Icon auf Schwarz, und für den Homescreen liest iOS das Manifest
  nicht zuverlässig, sondern `apple-touch-icon`.
- **`einzeldatei.html` ist ERZEUGT** (`scripts/einzeldatei.py`) und muss nach
  jeder Änderung an HTML, CSS oder JavaScript neu gebaut werden — sonst hängt
  die Fassung für den Doppelklick hinterher. Sie ist der Weg auf einen
  Windows-Rechner ohne Webserver: ES-Module weist jeder Browser bei `file://`
  ab, deshalb liegt dort alles in EINER Datei. Jedes Modul bekommt einen
  eigenen Geltungsbereich; ein blosses Aneinanderhängen scheitert, weil `zwei`
  sowohl in `ics.js` als auch in `app.js` steht. **Eine `.exe` gibt es mit
  Absicht nicht** (150 MB Electron um 60 KB App, SmartScreen-Warnung ohne
  Signatur, zweiter Aktualisierungsweg) — Edge und Chrome installieren die
  Seite selbst als Programm mit Startmenü-Eintrag.
- **Der xlsx-Leser ist selbst geschrieben** (`js/zip.js`, `js/xlsx.js`).
  Entpackt wird mit `DecompressionStream('deflate-raw')`, wo der Browser es
  mitbringt, sonst mit dem eigenen Inflate daneben — den Rückfall nicht
  entfernen, sonst bleibt die App auf älteren Geräten stumm. Keine
  Bibliothek nachladen: Das bräche Offlinebetrieb und Datensparsamkeit.
- **Ob eine Zahl ein Datum meint, steht in .xlsx am ZAHLENFORMAT, nicht am
  Wert.** Deshalb wird `styles.xml` mitgelesen (`DATUM_FORMATE` plus eigene
  Formate mit d/m/y). Ohne das ist der 31.08.2026 einfach 46265.
- **Die .ics wird nach OKTETTEN gefaltet, nicht nach Zeichen** (`falte` in
  `js/ics.js`). Ein Umlaut zählt zwei; eine mitten im Zeichen geteilte Zeile
  macht aus „für" Buchstabensalat.
- **Die fertige Datei wird als `application/octet-stream` ausgegeben**, nicht
  als `text/calendar` (`herunterladen` in `js/app.js`). Bei `text/calendar`
  schiebt Safari die Termine sofort in die Kalender-App, und die Datei selbst
  liegt nirgends — genau das war die Beschwerde (08/2026). Was die Datei ist,
  sagt die Endung `.ics`; ein Doppelklick öffnet weiterhin den Kalender.
  Daneben stehen zwei Auswege: „Teilen / In Dateien sichern" über
  `navigator.share` (auf iPhone und iPad der einzige Weg zu „Sichern"; der
  Knopf zeigt sich nur, wenn `navigator.canShare` Dateien annimmt) und „Text
  anzeigen" zum Kopieren. **Kopiert wird der gemerkte Text, nicht der Inhalt
  des Textfeldes** — ein Textfeld gibt seinen Wert mit `\n` zurück, in eine
  `.ics` gehören `\r\n`.
- **Zeiten stehen ohne Zeitzone** („schwebend"). Eine mitgelieferte
  VTIMEZONE brächte hier nichts und müsste bei jeder Zeitumstellung stimmen.
  Ganztägige Termine enden am ERSTEN Tag danach (so will es RFC 5545).
- **Aus einer `.docx` werden nur die TABELLEN gelesen** (`js/docx.js`), nicht
  der Fließtext: Wer Termine in Tabellen notiert, hat davor und dazwischen
  Anrede, Erklärungen und Grußformel — die alle als „übergangene Zeile" zu
  melden, wäre lauter Lärm. Erst ein Dokument ganz ohne Tabelle lässt seine
  Absätze durchsehen. Die Vorsilbe `w:` wird beim Vergleichen abgeschnitten,
  und eine verschachtelte Tabelle wird zu eigenen Zeilen — ihr Text landet
  nicht zusätzlich in der Zelle, die sie enthält.
- **Kopfzeilen werden an jeder Stelle erkannt, nicht nur ganz oben**
  (`istKopfzeile`): Ein Word-Dokument bringt mehrere Tabellen mit, und jede
  hat ihre eigene Überschrift. Eine echte Terminzeile trägt ein Datum und
  kommt an dieser Prüfung nie an.
- **Gesucht wird die Datumszelle, nicht die erste Spalte.** Welche Spalte
  links steht, ist dadurch gleich. Zeilen ohne erkennbares Datum werden
  nicht still verschluckt, sondern als „Übergangene Zeilen" angezeigt — eine
  stillschweigend fehlende Zeile im Kalender fällt erst auf, wenn der Termin
  vorbei ist.
- Eine Uhrzeit in der Beschreibung wird nur mit Doppelpunkt oder dem Wort
  „Uhr" (bzw. „h") übernommen. „3.45" in einem Text ist meist eine Zahl und
  keine Viertel vor vier. **Die Zeitspanne wird VOR den Einzelzeiten
  geprüft** (`ZEITSPANNE` vor `EINZELZEIT`): „9-15.30 Uhr" ist eine Angabe,
  keine zwei — und „11.00 Uhr" ergab ohne die Punktform in der Einzelsuche
  einmal 00:00 Uhr, weil nur „00 Uhr" passte (gefunden 09/2026 an einer
  echten Jahresplanung).
- **Zeiträume in Kurzform sind der Regelfall in Schulplänen**: `12.-14.10.2026`,
  `10./11.07.2027`, `17.10.- 31.10.2026`, `14.09.-25.09.2026`. Sie werden VOR
  `TT.MM.JJJJ` geprüft, sonst frisst die einfache Regel das zweite Datum und
  der Anfangstag geht verloren. Fehlt beim ersten Datum das Jahr, gilt das des
  zweiten — bei größerem Monat um eins zurück (`28.12.-04.01.2027` beginnt
  2026). Gefundene Daten werden am Ende chronologisch sortiert: „Ab 07.09. bis
  zum 18.09.2026" nennt das vollständige Datum hinten.
