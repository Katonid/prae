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

`scripts/test-e2e.js` (Modi `ordner`, `einzeldatei`, `browser`) und
`scripts/test-zip64.js`; Aufrufe im README. Chromium und ffmpeg sind im
Container vorhanden. Ein grüner Lauf heißt: anlegen, importieren
(inkl. 9000-Pixel-Foto und H.264-Video), Blick festlegen, Alben,
Vorschau, fertigstellen, ZIP prüfen, entpacken, über HTTP mit
Range-Anfragen ausliefern, am Desktop und am Handy Foto zeichnen, Video
abspielen und pausieren, Freigabe beim Schließen. Safari und echte
iPhones testet das NICHT.
