# Textauszug

Holt den reinen Text aus einer PDF-Datei und schickt ihn weiter — bevorzugt in
die **Notizen** auf iPhone und iPad, sonst in die Zwischenablage oder in eine
`.txt`-Datei. Und in die Gegenrichtung: aus eingesetztem Text wird eine
gesetzte **PDF** oder eine **EPUB**.

Adresse: https://katonid.github.io/prae/textauszug/

## Was hineingeht und was herauskommt

Zwei Wege hinein: **PDF** auswählen, hineinziehen oder einfügen — oder
**„Eigenen Text einsetzen"** und schreiben (eine `.txt` darf man auch ins
Fenster ziehen). Danach steht der Text im Feld, lässt sich ändern, und dann:

| Knopf | Was passiert |
| --- | --- |
| **An Notizen senden** | Teilen-Blatt → *Notizen* → *Sichern*. Der Text steht als **Notiz** da, nicht als Anhang. |
| **Text kopieren** | In der Zwischenablage; in einer neuen Notiz einfügen. |
| **Als .txt sichern** | Textdatei bei den Downloads. |
| **Als EPUB sichern** | E-Book für Bücher (Apple Books), Kobo und jedes andere Lesegerät. |
| **Als PDF sichern** | Gesetzte Seiten mit Seitenzahlen und Lesezeichen — zum Drucken und Verschicken. |

Geteilt wird **Text, keine Datei** — eine geteilte Datei landet in den Notizen
als Anhang, den man erst antippen muss. Die erste Zeile wird in den Notizen zur
Überschrift; deshalb setzt die App auf Wunsch den Dateinamen davor.

## Eine PDF direkt aus einer anderen App schicken

- **Android:** Die installierte App steht im *Teilen*-Menü (`share_target` im
  Manifest). Das Betriebssystem schickt die Datei als POST an `./teilen`; eine
  Seite kann so etwas nicht entgegennehmen, der Service Worker schon. Er legt
  sie in einen eigenen Zwischenspeicher und leitet auf `./?geteilt=1` um, wo die
  App sie abholt und sofort wieder löscht.
- **iPhone und iPad:** Nicht möglich — Apple lässt Web-Apps nicht ins
  Teilen-Blatt (Web Share Target wird in Safari nicht unterstützt). Der kurze
  Weg dort ist der Dateiwähler der App: Er öffnet iCloud Drive, Mail-Anhänge
  und alle Ordner der Dateien-App, ohne dass etwas kopiert werden muss. Auf dem
  iPad geht zusätzlich Ziehen aus der Dateien-App.
- **Rechner:** Ziehen ins Fenster, oder Datei kopieren und mit Strg/Cmd + V
  einfügen.

## Die PDF-Datei — und die Schrift

Aus denselben Absätzen wie die EPUB, nur gesetzt statt fließend: Überschriften
größer und fett, Seitenzahlen unten mittig, Lesezeichen zum Springen. Wählbar
sind Schrift, Schriftgröße, Zeilenabstand, Papierformat (A4, A5, Letter) und
Seitenrand.

**Drei Schriften stehen zur Wahl** — serifenlos (Helvetica/Arial), mit Serifen
(Times) und Schreibmaschine (Courier). Das ist keine Sparsamkeit, sondern eine
Entscheidung: Genau diese drei Familien bringt **jedes** PDF-Programm mit. Damit
muss in die Datei keine Schrift eingebettet werden — sie bleibt ein paar
Kilobyte groß, öffnet überall gleich und braucht keine Lizenz für die
Weitergabe. Eine eingebettete Schrift macht aus 30 KB schnell 500 KB.

Die Zeichenbreiten dazu stehen in `js/schriftmasse.js` (erzeugt von
`scripts/schriftmasse.py`): Ein PDF bricht keine Zeile selbst um, wer setzt,
muss messen.

**Getrennt wird nicht, deshalb ist der Satz linksbündig.** Die deutsche
Silbentrennung lässt sich nicht errechnen — dieselbe Regel wie in der
Wörterwerkstatt —, und eine falsche Trennung stünde für immer im Dokument. Ohne
Trennung aber reißt Blocksatz Löcher in die Zeilen. Ein flatternder rechter Rand
ist der kleinere Schaden.

**Was WinAnsi nicht hergibt, wird gezählt.** Die Standardschriften kennen 224
Zeichen; ein Emoji oder ein griechischer Buchstabe steht als Fragezeichen da,
und die App sagt hinterher, wie viele es waren. Verschluckt wird nichts.

## Die EPUB-Datei

Aus dem Text wird auf Wunsch ein E-Book. Das lohnt sich für lange Dokumente: Im
Lesegerät läuft der Text im Fließtext, mit einstellbarer Schriftgröße,
Nachtmodus und Lesezeichen — angenehmer als eine PDF auf einem kleinen
Bildschirm.

**Kapitel entstehen an den Überschriften.** Welche Zeile eine Überschrift ist,
verrät die Schriftgröße in der PDF: Was größer gesetzt war als der Fließtext und
kurz genug ist, wird zur Überschrift und landet im Inhaltsverzeichnis des
Buches. Hat ein Dokument gar keine Überschriften, wird nach Länge geteilt — ein
einziges XHTML mit tausend Absätzen öffnet auf älteren Lesegeräten quälend
langsam.

**Titel und Verfasser** stehen in den Einstellungen und landen in den Buchdaten,
nach denen die Bücher-App sortiert.

**Die Schrift ist in der EPUB nur ein Vorschlag.** Ein E-Book läuft im
Fließtext; welche Schrift dort steht, entscheidet das Lesegerät und sein
Besitzer — in *Bücher* der Schalter zwischen „Original" und einer eigenen
Schrift. Das ist keine Lücke des Formats, sondern sein Sinn. Eingebettet wird
auch hier nichts.

Wurde der Text im Feld von Hand geändert, sind die gemerkten Blöcke hinfällig;
die Gliederung wird dann aus dem geänderten Text zurückgelesen (kurze Zeile ohne
Satzzeichen, gefolgt von einem Absatz = Überschrift).

## Einstellungen

- **Absätze zusammenführen** — die Zeilenumbrüche der Seite fallen weg, Absätze
  bleiben. Am Zeilenende getrennte Wörter wachsen wieder zusammen.
- **Kopf- und Fußzeilen entfernen** — Seitenzahlen und wiederkehrende Zeilen am
  Rand.
- **Seitenzahlen einfügen** — eine Zeile `--- Seite 3 ---` vor jeder Seite.
- **Dateiname als erste Zeile** — die Überschrift der späteren Notiz.
- **Von/Bis Seite** — nur einen Ausschnitt mitnehmen.

Geändert wird immer nur, was weitergeht; die PDF bleibt unangetastet. Der Text
im Feld lässt sich vor dem Weitergeben von Hand kürzen.

## Grenzen, offen benannt

- **Ein Scan enthält keinen Text**, sondern ein Bild davon. Eine Texterkennung
  hat diese App nicht — sie sagt es aber deutlich, statt eine leere Seite
  auszugeben.
- **Kennwortgeschützte PDFs** lassen sich nicht lesen; die App meldet das mit
  dem Weg drumherum (einmal ohne Schutz sichern).
- **Eine Datei, die leer oder halb ankommt**, meldet die App als das, was sie
  ist — mit der Zahl der Bytes und dem Hinweis auf iCloud. Sie schiebt die
  Schuld nicht auf eine tadellose PDF.
- **Eine Webseite statt einer PDF** erkennt sie und sagt es im Klartext, samt
  dem Titel der Seite („Anmeldung erforderlich", „404"). Das ist der häufigste
  Fall hinter einem misslungenen Download: Hinter dem Link stand eine
  Anmeldung, eine Fehlermeldung oder eine Vorschau, und heruntergeladen wurden
  ein paar Kilobyte HTML mit `.pdf` im Namen. Der Weg drumherum steht in der
  Meldung.
- **Tabellen und Spalten** kommen als Text an, aber ohne ihre Form.

## Wie es gebaut ist

Statische Web-App, keine Abhängigkeit, kein Bauschritt, kein Server — wie der
Terminkonverter daneben. Der PDF-Leser ist selbst geschrieben.

| Datei | Aufgabe |
| --- | --- |
| `js/inflate.js` | Entpackt zlib- und roh-DEFLATE-Ströme (`DecompressionStream`, sonst eigenes Inflate). |
| `js/pdf.js` | Objekte, Ströme, Filter, Objektströme, Seitenbaum. |
| `js/schrift.js` | Von Byte zu Buchstabe: `/ToUnicode`, Kodierungen, `/Differences`, Zeichenbreiten. |
| `js/inhalt.js` | Führt den Inhaltsstrom aus und sammelt Text **mit Ort**. |
| `js/aufbereiten.js` | Aus Zeilen mit Ort werden Absätze; Kopf- und Fußzeilen fliegen raus. |
| `js/auszug.js` | Der Weg in zwei Schritten: einmal lesen, beliebig oft aufbereiten. |
| `js/epub.js` | ZIP-Schreiber und EPUB-Bauer (Kapitel, Inhaltsverzeichnis, Buchdaten). |
| `js/schriftmasse.js` | Zeichenbreiten der 14 Standardschriften — erzeugt, nicht von Hand. |
| `js/winansi.js` | Von Unicode in den Zeichensatz, den eine PDF ohne eingebettete Schrift versteht. |
| `js/pdfbauen.js` | Der Satz: Umbruch, Seiten, Lesezeichen, die fertige Datei. |
| `js/app.js` | Oberfläche: Datei annehmen, Text zeigen, weitergeben. |
| `sw.js` | Service Worker fürs Offline-Starten (`FASSUNG` hochzählen!). |
| `scripts/generate-icons.py` | erzeugt `icons/` — gerechnet, ohne fremde Bibliothek. |
| `scripts/schriftmasse.py` | erzeugt `js/schriftmasse.js` aus den Liberation-Schriften. |
| `scripts/einzeldatei.py` | baut `einzeldatei.html` (alles in einer Datei, für `file://`). |

Vier Stellen, an denen es leicht schiefgeht:

- **Das Verzeichnis am Ende der PDF wird absichtlich nicht gelesen.** Es ist die
  Stelle, die in freier Wildbahn am häufigsten kaputt ist; jeder Betrachter
  öffnet solche Dateien trotzdem. Gesucht wird statt dessen die ganze Datei nach
  `N G obj` ab.
- **Ein PDF kennt keine Zeilen und keine Wörter**, nur „setze diese Zeichen an
  diese Stelle". Zeilen und Leerzeichen werden aus den Stellen zurückgerechnet —
  dafür werden auch die Zeichenbreiten der Schrift gelesen.
- **Welcher Buchstabe hinter einer Zeichennummer steckt**, sagt `/ToUnicode`,
  sonst die Kodierung samt `/Differences`. Ohne diesen Schritt wird aus „für"
  Buchstabensalat.
- **Im EPUB muss „mimetype" der erste Eintrag des ZIP sein und ungepackt
  abgelegt werden.** Daran erkennen Lesegeräte das Format, ohne das Archiv zu
  öffnen. Gepackt oder an zweiter Stelle gilt die Datei als beschädigt.
- **Der senkrechte Abstand wird am Zeilenabstand DER SEITE gemessen, nicht an
  der Schriftgröße.** Ein Kinderbuch setzt 16 Punkt Schrift mit 37 Punkt
  Zeilenabstand; an der Schrift gemessen wäre dort jede Zeile ein eigener
  Absatz.
- **Eine Kopfzeile erkennt man am Abstand und an der Größe**, nicht an der
  Position in der Liste: über ihr klafft eine Lücke, und sie ist nie größer als
  der Fließtext. Ohne diese beiden Merkmale verliert ein Dokument mit
  Kapitelüberschriften genau diese Überschriften.

## Auf einem Rechner ohne Webserver

`einzeldatei.html` enthält die ganze App in einer Datei und läuft per
Doppelklick, ohne Netz. Gebaut mit `python3 scripts/einzeldatei.py`; **nach
jeder Änderung an HTML, CSS oder JavaScript neu bauen**, sonst hängt sie
hinterher.

Die Umwandlung läuft vollständig im Browser: Es wird nichts hochgeladen, nichts
gespeichert, nichts an Dritte geladen.
