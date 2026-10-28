# Projekt Galerie 360 (Web-App, 360°-Galerie-Generator)

> Die übergreifenden Regeln (PR-Rhythmus, Bau in GitHub Actions) stehen in
> der `CLAUDE.md` im Wurzelverzeichnis und gelten hier genauso.

- Code: `galerie360/`. Statische Web-App ohne Bauschritt, **klassische
  Skripte statt ES-Module** (Module lädt kein Browser über `file://`, und
  die Einzeldatei soll per Doppelklick laufen). Keine fremde Bibliothek,
  kein CDN. Ausgeliefert vom Pages-Arbeitsablauf:
  https://katonid.github.io/prae/galerie360/
- Auftrag des Nutzers (10/2026): aus Insta360-X4-Air-Aufnahmen (schon in
  Insta360 Studio als equirektangulare JPG/MP4 exportiert) eigenständige
  Webgalerien für den EIGENEN Webspace bauen, für Freunde und Familie,
  ohne App, Konto oder Cloud. Die Aufgabe kam als langer Prompt, der
  zuerst in claude.ai gestellt worden war; Ausgangspunkt war dieser Text,
  kein Chatverlauf.
- Ausführlich: `README.md`, Bedienung: `anleitung.html`.

## Versionierung

Bei jeder neuen Fassung, ohne Nachfrage:
- `FASSUNG` in `galerie/galerie.js` UND in `js/app.js`, Patch +1 (beide gleich).
- `FASSUNG` in `sw.js` hochzählen (`v1` → `v2` …), neue Dateien in `DATEIEN`
  eintragen — sonst behält das iPad (App vom Home-Bildschirm) die alte Fassung.
- `python3 scripts/einzeldatei.py` laufen lassen und
  `galerie360-generator.html` mit einchecken, sonst bleibt die Einzeldatei alt.

## Entscheidungen und Fallen

- **Das Projekt IST der Ordner, und der Ordner IST die Website.** Kein
  getrennter Export: Jede Änderung wird sofort in `gallery.json` und
  `index.html` geschrieben; „Website fertigstellen“ schreibt zusätzlich
  `assets/` neu und prüft. Spätere Erweiterung = Ordner öffnen, ergänzen,
  erneut hochladen. Die Galeriedaten stehen IN `index.html` (kein
  `fetch` von `gallery.json`: Hoster liefern sonst alte Fassungen aus dem
  Zwischenspeicher, und eine Anfrage fällt weg).
- **Chrome/Edge schreiben per File System Access direkt in den Ordner.**
  Safari/Firefox bekommen den Browser-Speicher (OPFS) und ein ZIP. Beides
  ist dieselbe Schnittstelle (`FileSystemDirectoryHandle`), deshalb
  ersetzt der Test den Ordnerdialog durch OPFS.
- **iPad (Wunsch des Nutzers, 10/2026: „auch auf dem iPad erstellen“).**
  Safari schreibt nicht in die Dateien-App und kannte lange kein
  `createWritable`: Ohne `createWritable` schreibt `dateiSchreiben` über
  einen Worker mit `createSyncAccessHandle` (Pfad per `resolve()` aus dem
  OPFS-Wurzelordner; Aufträge im Worker hintereinander, sonst Sperrfehler).
  Testmodus `safari` löscht `createWritable` und prüft genau diesen Weg.
  Weitere iPad-Regeln: keine Zeichenfläche über 16,7 Megapixel (die
  8192er-Fassung entfällt, iOS liefert sonst stumm ein leeres Bild);
  ZIP per `navigator.share` in die Dateien-App; **als Webseite darf
  Safari den Speicher nach Wochen ohne Besuch löschen, als App vom
  Home-Bildschirm nicht** — deshalb Manifest, PNG-Symbole
  (`scripts/generate-icons.py`), `sw.js` und der Hinweis auf der
  Startseite. Das ZIP ist zugleich Sicherung: „Galerie aus ZIP-Archiv
  übernehmen“ liest Verzeichnis und Köpfe (`zipLesen`, auch ZIP64) und
  reicht die Inhalte als `slice` weiter; nur ungepackte Archive (Methode 0),
  also die vom Generator selbst.
- **Vergleich mit dem Entwurf aus claude.ai (10/2026, als ZIP vom Nutzer
  gezeigt):** Node.js-Server + TypeScript, läuft nur auf Rechnern, nie auf
  dem iPad — deshalb bleibt es bei dieser Browserlösung. Brauchbare Ideen
  daraus für später: WebGL 2 mit Mipmaps und nahtkorrigiertem
  `textureGrad` (schärfer beim Herauszoomen), H.264-Webfassung per ffmpeg
  (geht nur am Rechner).
- **Hotspots (Wunsch des Nutzers, 10/2026; Vorbild: Panorama vom Berggasthof
  Gerstreit — der dort erwähnte Screenshot lag dem Auftrag nicht bei).**
  Darstellung in `galerie/galerie.js` (`HotspotEbene`, `InfoFenster`),
  gemeinsam für Galerie UND Editor — nie zweimal bauen. Position in
  Kugelkoordinaten; `Panorama.projiziere`/`richtung` rechnen mit
  derselben Matrix wie der Shader (Test: Hin- und Rückweg < 1 px).
  Ein Ziehen, das auf einem Symbol beginnt, übergibt die Galerie per
  `uebernimm()` ans Panorama — sonst löste Wischen am Handy Hotspots aus.
  **Sicherheit:** Texte nur per `textContent`, Auszeichnung (`formatiere`)
  baut Elemente selbst, Adressen nur über `sichereUrl`, Icons nur aus
  erlaubten SVG-Grundformen, eigene Bilder (auch SVG) werden als PNG/JPEG
  NEU gerechnet. Nie `innerHTML` mit Inhalt aus der Galerie-Datei.
  **Videos: keine Objektverfolgung** — feste Richtung, so dokumentiert.
  Symbolbibliothek (`vendor/`, Lucide ISC + emojibase MIT) erzeugt
  `scripts/symbolbibliothek.py`; sie lädt erst beim Öffnen des Editors
  und kommt NIE in die Galerie (nur die benutzten Icon-Knoten). Deutsche
  Suchwörter: `DEUTSCH` in `js/hotspots.js`; Suche nach Wortanfängen
  („berg" fand sonst „übergeben").
- **Ein OPFS-Handle in IndexedDB ließ Chromium beim Verlassen der Seite
  abstürzen** (gefunden 10/2026 im Test, `trap int3`). Deshalb wird der
  Handle nur für echte Ordner gemerkt; den Browser-Speicher liest die
  Startseite ohnehin selbst. `test-hotspots.js` läuft deshalb im
  Browser-Speicher (= iPad-Weg); den Ordner-Weg deckt `test-e2e.js`.
- **Passwort und geheime Links (Wunsch des Nutzers, 10/2026: „meinen
  Bereich als Autor mit Passwort schützen", Album-Links „so lang, dass sie
  nicht durch Zufall aufgerufen werden").** Der Generator ist nie online —
  die Schwachstelle war `gallery.json` auf dem Webspace (alle Alben, auch
  Entwürfe und Links). Deshalb: mit Passwort ist sie VERSCHLÜSSELT
  (AES-256-GCM, PBKDF2-SHA256 600 000, frischer IV je Speichern; Hülle
  `{format, verschluesselt:{…}}`), Öffnen nur mit Passwort, „Schließen"
  vergisst den Schlüssel. Passwort wird nie gespeichert; ändern verlangt
  das alte. Freigabe je Album (`a.freigabe.art`: oeffentlich / link /
  entwurf, Datenfassung 3): geheime Alben bekommen `<26 Zeichen a–z2–7>/index.html`
  (130 Bit, `G.geheimerName`) mit `basis: '../'`; die Startseite enthält
  nur öffentliche Alben, Hotspots über Seitengrenzen werden weggelassen
  (sonst stünden Ids geheimer Aufnahmen darin), `referrer: no-referrer`
  auf jeder Seite, Ordner alter Links löscht `seitenSchreiben`. **Geheime
  Links gibt es nur mit Passwort** — sonst verriete sie gallery.json.
  Neue Dateien bekommen 8 Zufallszeichen im Namen. Test: `test-schutz.js`.
- **`file://` ist in Chrome ein sicherer Kontext**: `showDirectoryPicker`
  geht auch in der Einzeldatei (geprüft 10/2026). Den Betrachter-Quelltext
  kann sie dort aber nicht per `fetch` holen, deshalb liegt er als
  `window.G360_QUELLTEXT` darin.
- **Der Betrachter zeichnet keine Kugel**, sondern ein Rechteck; der
  Fragment-Shader rechnet je Pixel die Richtung aus. **Keine Mipmaps**:
  An der Naht links=rechts springt die Texturkoordinate, mit Mipmaps
  entstünde dort ein Strich.
- **Fotofassungen**: Ab 4096 Pixeln Breite entstehen `-4096.jpg` (Handys:
  iOS bricht bei großen Texturen ab) und ab 8192 `-8192.jpg` (Grafikkarten
  mit kleiner Texturgrenze). Am Computer zeigt die Galerie erst 4096, dann
  die größte passende Fassung, meist das Original. Originale werden NIE
  verändert.
- **Videos**: kein Umwandeln im Browser. Stattdessen mehrere „Fassungen“
  je Video (z. B. 5,7K H.265 + 4K H.264); der Betrachter nimmt die erste,
  die `canPlayType` bejaht, am Handy zuerst ≤ 4096, und probiert bei
  `error` die nächste. Codec-Kennung kommt aus der `stsd`-Box der MP4
  (`js/medien.js`), nicht aus der Dateiendung.
- **iOS**: Video nur nach Tippen starten (`play()` im selben Klick), es
  muss im DOM stehen (sonst keine Bilder für WebGL), `playsinline`.
  Lautstärke lässt iOS nicht zu (Regler ausgeblendet). Kein
  Element-Vollbild auf dem iPhone: Ersatz blendet die Bedienung aus.
- **Beim Schließen/Wechseln `src` entfernen und `load()`**, sonst behält
  der Browser Decoder und Puffer. Der Test prüft das.
- **`<dialog>`: das `close`-Ereignis kommt verspätet.** Folgt sofort die
  nächste Frage, schloss es diese mit (gefunden im ersten Testlauf). Darum
  wird es nur beachtet, wenn der Dialog wirklich zu ist.
- **ZIP**: ohne Kompression, ZIP64 ab 4 GB. Mit Zieldatei ein Durchgang,
  die Prüfsumme wird per `seek` nachgetragen; ohne Zieldatei wird ein Blob
  aus Kopfdaten und den Dateien selbst gebaut (nichts doppelt im
  Speicher). `VOLL` (Platzhalter 0xFFFFFFFF) und `GRENZE` (ab wann ZIP64)
  sind absichtlich zwei Konstanten: `scripts/test-zip64.js` senkt die
  Grenze, um den Weg mit kleinen Dateien zu prüfen.

## Prüfen

`scripts/test-e2e.js` (Modi `ordner`, `einzeldatei`, `browser`, `safari`),
`scripts/test-hotspots.js`, `scripts/test-schutz.js` und `scripts/test-zip64.js`;
Aufrufe im README. Chromium und ffmpeg sind im
Container vorhanden. Ein grüner Lauf heißt: anlegen, importieren
(inkl. 9000-Pixel-Foto und H.264-Video), Blick festlegen, Alben,
Vorschau, fertigstellen, ZIP prüfen, ZIP in frischem Browser wieder
übernehmen, entpacken, über HTTP mit
Range-Anfragen ausliefern, am Desktop und am Handy Foto zeichnen, Video
abspielen und pausieren, Freigabe beim Schließen. Safari und echte
iPhones testet das NICHT.
