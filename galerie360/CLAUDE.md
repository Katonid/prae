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

## Webspace-ZIP — zu JEDER Arbeitseinheit, ohne Nachfrage

Ansage des Nutzers (10/2026): **„Gib immer ein ZIP mit an, in dem die
Dateien für den Webspace sind!"** Am Ende jeder Arbeitseinheit an
Galerie 360, zusammen mit dem PR-Link:

1. `python3 scripts/webspace-zip.py <scratchpad> <stand>` — `<stand>` ist
   der gepushte Zweig des PRs (oder `origin/main`, wenn nichts offen ist).
   Das Skript baut aus Git, nicht aus dem Arbeitsordner, prüft FASSUNG und
   die Dateiliste von `sw.js` und legt `LIESMICH.txt` bei.
2. Das ZIP entpacken und `test-e2e.js` (mindestens `ordner` und
   `browser`) gegen die ENTPACKTEN Dateien laufen lassen: Testskript nach
   `<entpackt>/galerie360/scripts/` kopieren und von dort starten.
3. Mit `SendUserFile` übergeben (`display: attach`) und in einem Satz
   sagen, was es ist: der Generator für den eigenen Webspace. Die
   Galerien selbst (Fotos, Alben) baut der Generator; die stecken nie in
   diesem ZIP.

Das ZIP wird NICHT ins Repo eingecheckt.

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
  Links gab es bis 1.0.4 nur mit Passwort** — gallery.json lag damals mit
  auf dem Webspace; seit 1.0.5 nicht mehr (siehe Albumordner). Neue Dateien bekommen 8 Zufallszeichen im Namen. Test: `test-schutz.js`.
- **Webspace-Aufbau mit Albumordnern (Wunsch des Nutzers, 10/2026):**
  Alben liegen in `apps/galerie360/360Grad/<albumtitel>-<26 Zeichen>/`,
  Link automatisch `https://jerosch.net/apps/galerie360/360Grad/…`
  (`G.WEBADRESSE_STANDARD`; eigene Adresse in `einstellungen.webadresse`).
  `G.webspaceEintraege` baut das „ZIP für den Webspace" OHNE Kopie auf der
  Platte: `360Grad/index.html` (nur Karten mit `adresse`, keine Aufnahmen),
  `360Grad/assets/`, je veröffentlichtem Album `index.html` (Medien
  relativ, eigener Betrachter in `assets/`) und genau seine Dateien. **Keine gallery.json
  im Webspace-ZIP** — damit braucht ein geheimer Link kein Passwort mehr
  (früher Pflicht). Die „Sicherung" ist das ganze Projekt (für
  ZIP-Übernahme), nicht zum Hochladen. Der Projektordner selbst behält den
  klassischen Aufbau (Vorschau, Sicherung). Ordnername `a.ordner` folgt dem
  Titel, bis `a.ordnerFest` (nach Webspace-ZIP oder Kopieren). Hotspots über
  Albumgrenzen werden Links `../<ordner>/#a/<album>/<aufnahme>` — nie von
  öffentlich nach „nur mit Link", nie in Entwürfe. `sw.js` lässt `/360Grad/`
  in Ruhe (liegt im Geltungsbereich des Generators). Test: `test-albumordner.js`.
- **Große ZIPs am iPhone/iPad (gefunden 10/2026: Absturz beim Teilen eines
  1-GB-Album-ZIPs).** Früher entstand das ZIP ohne Speichern-Dialog als Blob
  aus vielen Teilen, und `navigator.share` liest Dateien in Safari ganz in
  den Arbeitsspeicher. Jetzt: `G.zipInDatei` schreibt das ZIP als EINE
  Datei in den Browser-Speicher (`export/`), ohne `createWritable` über den
  ZIP-Worker (kopiert und rechnet CRC selbst, trägt sie per Position nach).
  Am iPhone/iPad danach „Herunterladen (in Dateien)" — streamt von der
  Platte; „Teilen" nur bis `TEILEN_BIS` (200 MB). Notlösung „Je Album ein
  ZIP": `360Grad.zip` + `<albumordner>.zip` (Ordner obenauf, kommt IN
  360Grad/). Test: `test-grosses-zip.js` (JS-Speicher wächst nicht mit der
  Dateigröße, Python-CRC stimmt), iPad-Teil in `test-albumordner.js`.
- **Jeder Albumordner bringt seinen Betrachter mit** (10/2026: weiße Seite
  am iPad — hochgeladen war nur `360Grad/<albumordner>/`, die Seite suchte
  `../assets/galerie.js`). Seitdem `<albumordner>/assets/` im Webspace-ZIP
  (knapp 100 KB je Album), `360Grad/assets/` nur noch für die Startseite.
  Fehlt der Betrachter trotzdem, ersetzt `onerror` am Skript den Text
  „Galerie wird geladen …" durch eine Erklärung. Test: Teil „Nur ein
  Albumordner" in `test-albumordner.js`.
- **Unteralben, Reihenfolge, Löschen (Wunsch des Nutzers, 10/2026: „keine
  Funktion gefunden, wie man Alben löschen kann", „Reihenfolge der Bilder
  wählen", „Unterordner erstellen").** Löschen und ↑/↓ gab es schon, aber
  ganz unten bzw. blass — deshalb „Album löschen …" oben im Album und
  „Reihenfolge → Sortieren …" (Datum, Titel, umkehren). **Ziehen am Griff
  mit Zeiger-Ereignissen am FENSTER**, nicht HTML-Drag-and-Drop (startet
  am iPad nicht verlässlich) und nicht mit `setPointerCapture` am Griff:
  Sobald die Karte im DOM wandert, ist die Bindung weg (gefunden im Test).
  Unteralben: `a.eltern` (flache Liste, `G.elternVon` mit Kreisschutz,
  `ergaenzen` räumt Kreise/fehlende Eltern ab). **Auf dem Webspace bleibt
  jedes Album ein eigener Ordner direkt unter `360Grad/`** — Umhängen ändert
  keinen Link. Die Seiten verlinken einander (`G.seitenRegeln`: `hatSeite`,
  `darf` — nie von öffentlich auf „nur mit Link"): Elternseite zeigt Karten
  `../<kind>/`, Unteralbum bekommt `zurueck: {adresse: '../<eltern>/'}`;
  Startseite nur Alben ohne öffentliches Elternalbum. Löschen lässt
  Unteralben eine Ebene höher rücken. Test: `test-unteralben.js`.
- **Umbenennen (Wunsch des Nutzers, 10/2026: „Namen der Galerie und des
  Albums ändern").** Ging schon (Feld „Titel" links, Albumtitel als Feld),
  war aber nicht zu erkennen — links eingeklappt am iPad hochkant, der
  Albumtitel sah aus wie eine Überschrift. Jetzt: Kopfzeile zeigt den
  GALERIENAMEN (nicht mehr „Browser-Speicher › ordner") als Knopf mit ✎,
  `galerieTitelSetzen` zieht Feld, Kopfzeile und „Zuletzt geöffnet" mit
  (nicht bei Passwort: Titel bliebe sonst unverschlüsselt in IndexedDB);
  neben dem Albumtitel „✎ Umbenennen". Der Speicherordner behält seinen
  Namen (OPFS kann Ordner nicht verlässlich umbenennen). Test: Teil
  „Umbenennen" in `test-unteralben.js`.
- **Link zur ganzen Galerie (Wunsch des Nutzers, 10/2026).** Eigene,
  IMMER geheime Seite `360Grad/<galerietitel>-<26 Zeichen>/` (`p.galerieOrdner`,
  folgt dem Titel bis `p.galerieOrdnerFest` — nach Webspace-ZIP, Kopieren,
  Teilen). Inhalt: Karten `../<album>/` für `G.galerieAlben` = alle Alben mit
  Seite, die nicht schon auf der Seite ihres Elternalbums stehen (also auch
  ein geheimes Unteralbum unter öffentlichem Elternalbum). Von keiner
  anderen Seite verlinkt, `noindex`; Albumseiten führen NICHT zurück zur
  Galerieseite (sonst bekäme jeder Album-Link die ganze Galerie). „Teilen …"
  (`navigator.share` mit `url`, keine Datei) bei Galerie- und Album-Link.
  Bekannt, nicht gelöst: Mehrere Galerien teilen sich `360Grad/index.html`
  — die zuletzt hochgeladene gewinnt. Tests: `test-unteralben.js`,
  `test-albumordner.js` (iPad-Teilen).
- **Galerie ist die oberste Ebene (10/2026, Nutzer: „grundlegendes Problem
  zwischen Galerie und Album … beim geteilten Album erscheint der Titel der
  Galerie").** Betrachter-Daten `version: 2` (`galerieDaten`): Die Startseite
  zeigt Alben IMMER als Karten, auch ein einziges (vorher sprang sie hinein
  und zeigte Galerietitel + Albumbeschreibung); ein Album trägt seinen
  Titel, `daten.galerie` steht als Oberzeile darüber. Seiten mit
  `version: 1` (alte Albumseiten auf dem Webspace mit neuem gemeinsamem
  `assets/`) verhalten sich wie früher — nicht entfernen.
- **Neue Fassung erreicht das iPad (10/2026: Home-Bildschirm-App Stunden
  nach dem Hochladen noch auf 1.0.9, obwohl der Server 1.0.11 hatte).**
  Ursache nachgestellt: Der neue Service Worker installierte, holte aber
  per `addAll` die ALTE app.js aus dem Browser-Zwischenspeicher (jerosch.net
  schickt keine Cache-Angaben → Safari schätzt). Jetzt `new Request(d,
  {cache: 'reload'})`, `reg.update()` bei `visibilitychange`, bei
  `controllerchange` Startseite neu laden bzw. Leiste „Jetzt neu laden";
  Fassung unten auf der Startseite. Test: `test-neufassung.js` (schlägt mit
  dem alten sw.js fehl — so geprüft).
- **Kamera-Rohdateien (INSP/INSV/LRV/DNG) werden ERKANNT, nicht verarbeitet**
  (10/2026: Der Nutzer wählte am iPhone den Kameraordner `Camera01`, alles
  grau). `G.kameraDatei` + `kameraHinweis` erklären, was die Dateien sind
  und wie man in der Insta360-App bzw. Studio als 360° exportiert. Eigenes
  Stitchen bewusst nicht: Objektivdaten, Nahtausgleich, FlowState-
  Stabilisierung und Horizont kann nur Insta360 gut. Auf iOS wird das
  `accept` des Dateifelds entfernt — iOS graut sonst alles Unbekannte aus,
  und der Hinweis käme nie.
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
  `error` die nächste. **Am iPhone/iPad gilt `MOBIL_VIDEO` = 5760** (für
  Sortierung UND Texturgrenze `maxBreiteVideo`), sonst am Handy 4096: Bis
  1.0.7 wurde jedes Videobild am iPad per Zeichenfläche auf 4096
  verkleinert — Nutzer (10/2026): „Qualität schlechter als in der
  Insta360-App". Fotos bleiben am Handy bei 4096.
  Test: `test-videoaufloesung.js`. Codec-Kennung kommt aus der `stsd`-Box der MP4
  (`js/medien.js`), nicht aus der Dateiendung.
- **iOS**: Video nur nach Tippen starten (`play()` im selben Klick), es
  muss im DOM stehen (sonst keine Bilder für WebGL), `playsinline`.
  Lautstärke lässt iOS nicht zu (Regler ausgeblendet). Kein
  Element-Vollbild auf dem iPhone: Ersatz blendet die Bedienung aus.
- **Bild und Ton synchron (10/2026: Nutzer „in der Vorschau nicht
  synchron"; Vorschau = derselbe Betrachter wie online).** Zwei Ursachen
  behoben: (1) Das Video-Element war 2 × 2 px und `opacity: 0.01` — Safari
  behandelt so ein Video als unsichtbar und liefert seltener Bilder. Jetzt
  liegt es in voller Größe HINTER der Leinwand (`alpha: false`, deckt
  vollständig; DOM-Reihenfolge video, canvas). (2) Neue Bilder nur bei
  geändertem `currentTime` geholt — Safari rückt das nicht je Bild weiter.
  Jetzt `requestVideoFrameCallback` (setzt `_neuesBild`, die rAF-Schleife
  lädt), Rückfall ohne rVFC: bei jedem Durchlauf, solange das Video läuft.
  Test: `test-videoaufloesung.js` (Lage des Videos, Übertragungen je
  gezeigtem Bild bzw. Durchlauf). Echte Synchronität misst der Container
  NICHT (Software-Grafik, kein Safari).
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
`scripts/test-hotspots.js`, `scripts/test-schutz.js`, `scripts/test-albumordner.js`,
`scripts/test-grosses-zip.js`, `scripts/test-videoaufloesung.js`,
`scripts/test-unteralben.js`, `scripts/test-neufassung.js` und
`scripts/test-zip64.js`;
Aufrufe im README. Chromium und ffmpeg sind im
Container vorhanden. Ein grüner Lauf heißt: anlegen, importieren
(inkl. 9000-Pixel-Foto und H.264-Video), Blick festlegen, Alben,
Vorschau, fertigstellen, ZIP prüfen, ZIP in frischem Browser wieder
übernehmen, entpacken, über HTTP mit
Range-Anfragen ausliefern, am Desktop und am Handy Foto zeichnen, Video
abspielen und pausieren, Freigabe beim Schließen. Safari und echte
iPhones testet das NICHT.
