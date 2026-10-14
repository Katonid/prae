# Projekt Kontaktwandler (Web-App, Excel → LDIF)

> Die übergreifenden Regeln (PR-Rhythmus, iOS-Pflichten, Bau in GitHub
> Actions) stehen in der `CLAUDE.md` im Wurzelverzeichnis und gelten hier
> genauso.

- Code: `kontaktwandler/` — statische Web-App ohne Bauschritt (ES-Module,
  kein Framework, keine fremde Bibliothek), wird vom Pages-Arbeitsablauf mit
  ausgeliefert: https://katonid.github.io/prae/kontaktwandler/
  Nimmt eine Tabelle mit Namen und E-Mail-Adressen und gibt eine `.ldif` aus
  (angelegt 10/2026). Ausführlich: `kontaktwandler/README.md`.
- **Gebaut nach dem Muster des Terminkonverters** — dessen Regeln gelten
  hier genauso: `FASSUNG` in `sw.js` bei jeder neuen Fassung hochzählen;
  `einzeldatei.html` ist ERZEUGT (`python3 scripts/einzeldatei.py`) und nach
  jeder Änderung an HTML, CSS oder JavaScript neu zu bauen; Icons per
  `scripts/generate-icons.py`, PNG ohne Alphakanal; Ausgabe als
  `application/octet-stream`.
- **`js/zip.js`, `js/xml.js`, `js/xlsx.js` sind Kopien aus dem
  Terminkonverter** (jede App bleibt für sich lauffähig). `xlsx.js` ist
  erweitert: Alle Blätter sind wählbar (`xlsxLesen(puffer, nummer)` gibt
  `{ zeilen, blaetter }` zurück), und lange Zahlen kommen ohne Exponent
  heraus — eine Handynummer als Zahl steht im XML gern als
  `4.917612345678E+12`. Den Inflate-Rückfall in `zip.js` nicht entfernen.
- **Nicht-ASCII-Werte MÜSSEN Base64 sein** (`attribut` in `js/ldif.js`,
  RFC 2849). „Müller" roh hingeschrieben wird je nach Programm zu „MÃ¼ller"
  oder zu gar keinem Eintrag. Base64 auch bei Leerzeichen, „:" oder „<" am
  Anfang und Leerzeichen am Ende. Das gilt für den DN genauso (`dn:: …`).
- **Im DN wird nach RFC 4514 maskiert** (`dnWert`): „Smith, Jr." wird zu
  `cn=Smith\, Jr.` — sonst zerfällt der Name am Komma. Die Verteilerliste
  nennt ihre Mitglieder über GENAU diesen DN; wer die DN-Bildung ändert,
  ändert sie an einer Stelle (`kontaktDn`), sonst findet Thunderbird die
  Mitglieder nicht. Die Liste steht HINTER den Kontakten.
- Gefaltet wird nach 76 Zeichen. Nach der Base64-Regel ist jede Zeile reines
  ASCII — anders als bei der `.ics` muss hier nicht nach Oktetten gezählt
  werden. Kein `version: 1` am Anfang: Thunderbirds eigene Ausgabe hat es
  auch nicht.
- **Nichts wird still verschluckt** (`kontakteBauen` in `js/kontakte.js`):
  Zeilen ohne gültige Adresse, doppelte Adressen (ohne Rücksicht auf Groß-
  und Kleinschreibung) und eine dritte Adresse ohne Platz stehen unter
  „Nicht übernommen". Eine fehlende Adresse fällt sonst erst auf, wenn
  jemand die Rundmail nicht bekommen hat.
- **Namen werden nur zerlegt, wenn es eindeutig ist**: „Müller, Anna" in
  einer einzigen Namensspalte ergibt Vor- und Nachname, „Anna Lena Müller"
  nicht (wo endet der Vorname? „Hans von Bergen"?). Dann bleibt es beim
  Anzeigenamen.
- **Abgewählt wird nach Adresse, nicht nach Listenplatz** (`abgewaehlt` in
  `js/app.js`): Wer danach eine Spalte umstellt, verschiebt die Liste — die
  Abwahl bleibt trotzdem an der richtigen Person.
- **Eine CSV aus dem deutschen Excel ist meist Windows-1252**, nicht UTF-8.
  `textLesen` versucht UTF-8 streng und fällt sonst zurück.
