# Textauszug

Holt den reinen Text aus einer PDF-Datei und schickt ihn weiter — bevorzugt in
die **Notizen** auf iPhone und iPad, sonst in die Zwischenablage oder in eine
`.txt`-Datei.

Adresse: https://katonid.github.io/prae/textauszug/

## Was hineingeht und was herauskommt

PDF auswählen oder hineinziehen, Text ansehen, gegebenenfalls ändern, und dann:

| Knopf | Was passiert |
| --- | --- |
| **An Notizen senden** | Teilen-Blatt → *Notizen* → *Sichern*. Der Text steht als **Notiz** da, nicht als Anhang. |
| **Text kopieren** | In der Zwischenablage; in einer neuen Notiz einfügen. |
| **Als .txt sichern** | Textdatei bei den Downloads. |

Geteilt wird **Text, keine Datei** — eine geteilte Datei landet in den Notizen
als Anhang, den man erst antippen muss. Die erste Zeile wird in den Notizen zur
Überschrift; deshalb setzt die App auf Wunsch den Dateinamen davor.

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
| `js/app.js` | Oberfläche: Datei annehmen, Text zeigen, weitergeben. |
| `sw.js` | Service Worker fürs Offline-Starten (`FASSUNG` hochzählen!). |
| `scripts/generate-icons.py` | erzeugt `icons/` — gerechnet, ohne fremde Bibliothek. |
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
