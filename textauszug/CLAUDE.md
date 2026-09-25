# Projekt Textauszug (Web-App, PDF → Text)

> Ausgelagert aus der `CLAUDE.md` im Wurzelverzeichnis (09/2026). Die
> übergreifenden Regeln (PR-Rhythmus, iOS-Pflichten, Bau in GitHub
> Actions) stehen weiterhin dort und gelten hier genauso.


- Code: `textauszug/` — statische Web-App ohne Bauschritt (ES-Module, kein
  Framework, keine fremde Bibliothek), wird vom Pages-Arbeitsablauf mit
  ausgeliefert: https://katonid.github.io/prae/textauszug/
  Holt den reinen Text aus einer PDF und schickt ihn in die Notizen.
  Ausführlich: `textauszug/README.md`. Gebaut nach demselben Muster wie der
  Terminkonverter (Manifest, `sw.js` mit `FASSUNG`, `scripts/generate-icons.py`,
  `scripts/einzeldatei.py` — alle vier Punkte gelten hier genauso).
- **Der PDF-Leser ist selbst geschrieben** (`js/pdf.js`, `js/schrift.js`,
  `js/inhalt.js`), der PDF-SETZER ebenfalls (`js/pdfbauen.js`). Keine Bibliothek nachladen: Das bräche Offlinebetrieb und
  Datensparsamkeit — und pdf.js allein wiegt mehr als diese ganze App.
- **Das Querverweis-Verzeichnis am Ende der PDF wird ABSICHTLICH nicht
  gelesen.** Es ist die Stelle, die in freier Wildbahn am häufigsten kaputt ist
  (abgeschnittene Downloads, Werkzeuge, die falsche Stellen schreiben), und
  eine PDF mit falschem Verzeichnis öffnet jeder Betrachter trotzdem. Gesucht
  wird die ganze Datei nach „N G obj" ab; die HINTERSTE Fassung eines Objekts
  gewinnt (PDFs werden fortgeschrieben). Objektströme (`/ObjStm`, seit PDF 1.5
  der Regelfall) werden zusätzlich ausgepackt — ohne sie fehlen Katalog,
  Seiten und Schriften.
- **Ein PDF kennt keine Zeilen und keine Wörter**, nur „setze diese Zeichen an
  diese Stelle". Beides wird aus den STELLEN zurückgerechnet
  (`zeilenBauen` in `js/inhalt.js`): gleiche Höhe = eine Zeile, Lücke > ein
  Fünftel der Schrifthöhe = Leerzeichen. Dafür werden die Zeichenbreiten
  (`/Widths`, `/W`, `/DW`) gelesen — ohne sie käme der Text ohne Leerzeichen
  an. Eine große Vorrückung in einem `TJ`-Feld IST ein Leerzeichen: Viele
  Erzeuger schreiben nie eines.
- **Welcher Buchstabe hinter einer Zeichennummer steckt, sagt `/ToUnicode`** —
  sonst die Kodierung samt `/Differences`, zuletzt WinAnsi. Ohne diesen Schritt
  wird aus „für" Buchstabensalat. Bei einer Type0-Schrift ohne `/ToUnicode`
  wird NICHTS geraten (`zuText` gibt leer zurück): Zwei-Byte-Codes ohne Tabelle
  ergeben zufällige Zeichen, und ein falscher Text ist schlimmer als ein
  fehlender.
- **Der senkrechte Abstand wird am ZEILENABSTAND DER SEITE gemessen, nicht an
  der Schriftgröße** (`zeilenabstand` in `js/aufbereiten.js`, gefunden 09/2026
  an „Caesar und Zombie"). Ein Kinderbuch setzt 16 Punkt Schrift mit 37 Punkt
  Zeilenabstand; an der Schrift gemessen war dort JEDE Zeile ein eigener
  Absatz, und aus einem Kapitel wurden 300 Einzeiler. Dieselbe Schätzung
  (unteres Viertel der Abstände) dient der Kopfzeilenerkennung — zwei
  Fassungen liefen garantiert auseinander.
- **Sechs Kilobyte, die mit „<!DOCTYP" anfangen, sind eine WEBSEITE**
  (`webseitenbefund` in `js/pdf.js`, gemeldet 09/2026). Der häufigste Fall hinter
  einem misslungenen Download: Hinter dem Link steht eine Anmeldung, eine
  Fehlerseite oder eine Vorschau, und gesichert wird deren HTML — mit `.pdf` im
  Dateinamen. „Der Kopf '%PDF-' fehlt" ist dann wörtlich richtig und als Auskunft
  wertlos. Genannt wird deshalb der `<title>` der Seite („Anmeldung erforderlich",
  „404") — er sagt in fünf Wörtern, was los ist — und der Weg drumherum: die PDF
  im Browser wirklich öffnen, dann Teilen → „In Dateien sichern". Der Titel wird
  als UTF-8 entziffert, nicht als latin1; und unter einem Kilobyte zählt die
  Meldung Bytes statt „0 KB".
- **Die Gegenrichtung: aus Text wird eine PDF** (`js/pdfbauen.js`,
  `js/schriftmasse.js`, `js/winansi.js`, ab 09/2026 auf Wunsch des Nutzers).
  „Eigenen Text einsetzen" öffnet ein leeres Feld; alles dahinter ist dasselbe
  wie beim Lesen einer PDF — dieselben Blöcke, dieselbe EPUB, derselbe Satz.
  Eine `.txt` darf man auch ins Fenster ziehen.
- **Es gibt genau DREI Schriften, und das ist eine Entscheidung** (Helvetica,
  Times, Courier — je vier Schnitte). Nur diese Familien bringt jedes
  PDF-Programm mit; damit muss **keine Schrift eingebettet** werden: Die Datei
  bleibt bei ein paar Kilobyte statt einem halben Megabyte, öffnet überall
  gleich und braucht keine Lizenz für die Weitergabe. Wer eine vierte Schrift
  anbietet, trägt eine Schriftdatei ins Repo und in jede erzeugte PDF. **In der
  EPUB ist die Schrift ohnehin nur ein Vorschlag** — dort entscheidet das
  Lesegerät, und das ist der Sinn des Formats, keine Lücke.
- **Ein PDF bricht keine Zeile um — wer setzt, muss messen.**
  `js/schriftmasse.js` ist ERZEUGT (`scripts/schriftmasse.py`) und hält die
  Vorschubbreiten aller zwölf Schnitte. Gewonnen werden sie aus den
  Liberation-Schriften des Bau-Rechners, die maßgleich mit Arial, Times New
  Roman und Courier New sind — und die wiederum mit den Standardschriften. Das
  Skript prüft jeden Schnitt gegen Adobes Originalwerte (Helvetica: Leerzeichen
  278, A 667, a 556, m 833) und bricht bei Abweichung ab: Eine falsche Breite
  sähe man dem Quelltext nie an, wohl aber der siebten Seite.
- **Getrennt wird NICHT, deshalb ist der Satz linksbündig.** Die deutsche
  Silbentrennung ist nicht ableitbar (dieselbe Regel wie in der
  Wörterwerkstatt), und eine falsche Trennung stünde für immer im Dokument.
  Ohne Trennung reißt Blocksatz Löcher in die Zeilen — ein flatternder rechter
  Rand ist der kleinere Schaden. Nur ein Wort, das allein schon breiter ist als
  die Zeile (eine lange Adresse), wird hart zerlegt: Dort gibt es keine
  Alternative außer Wegschneiden.
- **Was WinAnsi nicht hergibt, wird GEZÄHLT** (`js/winansi.js`). Die
  Standardschriften kennen 224 Zeichen; deutscher Text passt vollständig hinein,
  ein Emoji nicht. Es wird zum Fragezeichen, und die App sagt hinterher, wie
  viele es waren und welche. Weiches Trennzeichen und geschütztes Leerzeichen
  werden VOR der Zuordnung ersetzt — das weiche Trennzeichen hat in WinAnsi eine
  sichtbare Gestalt, unverändert stünde mitten im Wort ein Bindestrich.
- **Der LESER kennt die Standardbreiten jetzt auch** (`standardbreiten` in
  `schriftmasse.js`, benutzt von `js/schrift.js`). Eine der 14 Standardschriften
  MUSS kein `/Widths` mitbringen; vorher nahm der Leser dafür 500/1000 je
  Zeichen an — das „i" so breit wie das „m", und damit standen Leerzeichen,
  Zeilenenden und Absatzgrenzen schief. Gefunden beim Rücklesen der selbst
  gesetzten PDF: Der Leser meldete Zeilen von 620 Punkt auf einer Seite von 595.
- **Eine Stufe, die nur EINMAL vorkommt, ist ein Titel und keine
  Kapiteleinteilung** (`kapitelSchneiden`). Sonst ergibt „Titel / Kapitel 1 /
  Kapitel 2" ein einziges EPUB-Kapitel, das das ganze Buch enthält, und ein
  Inhaltsverzeichnis mit einem Eintrag. Dazu erkennt `bloeckeAusText` die erste
  Zeile als Titel, wenn darunter eine weitere Überschrift steht — aber NUR die
  erste: Sonst würde aus einem „Mit freundlichen Grüßen" über einem Namen eine
  Überschrift.
- **Wer eine Datei nicht lesen kann, sagt WAS ankam — und schiebt die Schuld
  nicht auf die Datei** (gemeldet 09/2026: „Das ist keine PDF-Datei" über einer
  tadellosen PDF). Auf iPhone und iPad liegt eine Datei aus iCloud oft nur in
  der Wolke; der Dateiwähler meldet sie mit voller Größe, `arrayBuffer()`
  liefert aber nichts. Deshalb vergleicht `verarbeiten` `datei.size` mit dem,
  was wirklich ankam, und `pdfLesen` nennt bei fehlendem Kopf die Dateigröße
  und die ersten Zeichen. Gesucht wird der Kopf zudem in der GANZEN Datei:
  Manche Werkzeuge stellen einer PDF etwas voran.
- **Eine Kopfzeile erkennt man am ABSTAND und an der GRÖSSE**, nicht an der
  Position in der Zeilenliste (`randzeilen` in `js/aufbereiten.js`). Beide
  Merkmale sind je einmal teuer gelernt worden: Nach Position allein fraß die
  Prüfung in einem Text, der sich inhaltlich wiederholt, echten Inhalt; ohne
  die Größenregel verlor ein Dokument, dessen Seiten je mit einer
  Kapitelüberschrift beginnen, genau diese Überschriften. Der Zeilenabstand
  wird als UNTERES VIERTEL der Abstände geschätzt, nicht als Mittelwert — auf
  einer kurzen Seite zieht der Mittelwert die Schwelle so hoch, dass die
  Kopfzeile darunter durchrutscht.
- **Ein Absatz endet dort, wo eine Zeile VOR dem rechten Rand aufhört.** Das
  ist das verlässlichste Merkmal für einen Umbruch, der keine Fortsetzung ist;
  ohne es wachsen Aufzählungen und Grußformeln zu einem Klumpen zusammen. Die
  Schwelle liegt bei einem halben Wort (`groesse * 3.4`) — enger gefasst
  zerfiel ein Absatz in seine Zeilen.
- **Geteilt wird TEXT, keine Datei** (`anNotizen` in `js/app.js`). Eine
  geteilte Datei landet in den Notizen als Anhang, den man erst antippen muss;
  geteilter Text steht als Notiz da. Genau darum geht es dem Nutzer (Ansage
  09/2026). Kennt der Browser kein `navigator.share`, wird kopiert und das
  gesagt — der Knopf darf nie stumm bleiben.
- **Die EPUB wird aus den BLÖCKEN gebaut, nicht aus dem Text** (`js/epub.js`).
  Nur die Blöcke wissen, was eine Überschrift war — nämlich das, was in der PDF
  GRÖSSER gesetzt war als der Fließtext und kurz genug ist —, und daraus werden
  die Kapitel samt Inhaltsverzeichnis. Ist der Text im Feld von Hand geändert,
  sind die Blöcke hinfällig; dann liest `bloeckeAusText` die Gliederung aus dem
  geänderten Text zurück.
- **Im EPUB MUSS „mimetype" der erste Eintrag des ZIP sein und UNGEPACKT
  abgelegt werden.** Daran erkennen Lesegeräte das Format, ohne das Archiv zu
  öffnen; gepackt oder an zweiter Stelle gilt die Datei als beschädigt. Der
  ZIP-Schreiber steht deshalb mit im Haus (`zipSchreiben`) — gepackt wird mit
  `CompressionStream`, ohne das ungepackt, was erlaubt ist. Mitgeliefert wird
  neben `nav.xhtml` auch das alte `toc.ncx`: Lesegeräte ohne EPUB 3 finden
  sonst gar keine Gliederung.
- **Escape-Folgen für Steuerzeichen (\u0000 und Geschwister) gehören als ZEICHENFOLGE
  in den Quelltext, nie als echtes Steuerzeichen** (gefunden 09/2026 in
  `maskiere`). In der Modulfassung lief der reguläre Ausdruck; in
  `einzeldatei.html` machte der HTML-Parser aus dem echten NUL ein
  Ersatzzeichen, die Zeichenklasse wurde ungültig, und die ganze App blieb
  stumm. Wer eine Datei über ein Werkzeug schreibt, das JSON-Escapes auflöst,
  prüft danach auf echte Steuerzeichen.
- **Der Eintrag im Teilen-Blatt gibt es nur auf Android** (`share_target` im
  Manifest, POST-Zweig in `sw.js`). Apple unterstützt Web Share Target NICHT —
  eine Web-App kann auf iPhone und iPad nicht im Teilen-Blatt stehen, egal wie
  sie installiert ist. Das nie anders darstellen; der Weg dort ist der
  Dateiwähler (er öffnet iCloud Drive und Mail-Anhänge ohne Kopie) und auf dem
  iPad das Ziehen. Die geteilte Datei kann nur der Service Worker annehmen,
  eine Seite nicht: Er legt sie in einen EIGENEN Zwischenspeicher
  (`textauszug-geteilt`, beim Aufräumen ausgenommen) und leitet mit 303 auf
  `./?geteilt=1` um — ohne Umleitung stünde der Nutzer vor einer Antwortseite,
  die es nicht gibt. Die App holt sie dort ab und LÖSCHT sie sofort, sonst
  erschiene beim nächsten Öffnen das Dokument von vorgestern.
- **Ein Scan enthält keinen Text**, sondern ein Bild davon. Die App sagt das
  deutlich, statt eine leere Seite auszugeben; eine Texterkennung hat sie
  nicht. Dasselbe gilt für kennwortgeschützte PDFs — dort steht der Weg
  drumherum in der Meldung.
- Die `.txt` wird wie beim Terminkonverter als `application/octet-stream`
  ausgegeben (mit BOM, damit Windows-Editoren die Umlaute richtig lesen).
