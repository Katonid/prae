# Galerie 360

Generator für 360°-Webgalerien: 360°-Fotos und -Videos (equirektangular, z. B.
aus Insta360 Studio) hineinziehen, beschriften, sortieren — heraus kommt ein
Ordner mit einer vollständig eigenständigen Website, die auf jedem
gewöhnlichen Webspace läuft (Apache, nginx, Shared Hosting), ohne Backend,
Datenbank, CDN oder Konto.

- Generator: https://katonid.github.io/prae/galerie360/ (Chrome/Edge: direkt in einen Ordner;
  Safari auf iPad/iPhone/Mac und Firefox: Browser-Speicher + ZIP; als App zum Home-Bildschirm)
- Ohne Netz: `galerie360-generator.html` herunterladen und öffnen
- Anleitung: [`anleitung.html`](anleitung.html)

## Aufbau

| Datei | Zweck |
|---|---|
| `galerie/galerie.js`, `galerie/galerie.css` | Die veröffentlichte Galerie: 360°-Betrachter (WebGL, selbst geschrieben) und Oberfläche. Wird unverändert als `assets/` in jede Galerie kopiert. |
| `js/medien.js` | EXIF-Datum, MP4-Analyse (Codec, Auflösung, Dauer), Fotofassungen, Video-Standbilder, Vorschaubilder |
| `js/speicher.js` | Dateien im Projektordner (File System Access / OPFS), zuletzt benutzte Projekte, ZIP (mit ZIP64) |
| `js/export.js` | `index.html` der Galerie, Prüfung vor dem Hochladen, Adressen für die Vorschau |
| `js/app.js` | Oberfläche des Generators |
| `js/hotspots.js` | Hotspot-Editor: setzen, ziehen, Formular, Zeitleiste, Symbolwahl, Rückgängig, Vorlagen |
| `vendor/lucide.js`, `vendor/emoji.js` | Symbolbibliothek (erzeugt von `scripts/symbolbibliothek.py`), nur im Generator |
| `scripts/einzeldatei.py` | baut `galerie360-generator.html` |
| `scripts/webspace-zip.py` | baut das ZIP für den eigenen Webspace (Generator + LIESMICH.txt) |
| `sw.js`, `manifest.webmanifest` | offline und „Zum Home-Bildschirm“ (iPad) |
| `scripts/test-e2e.js` | Ende-zu-Ende-Test mit Playwright |
| `scripts/test-hotspots.js` | Hotspots: Editor, Rundgang, Zeitfenster, Touch, XSS, Export |
| `scripts/test-schutz.js` | Passwort (verschlüsselte gallery.json) und geheime Album-Links |

## Prüfen

```sh
python3 scripts/testmedien.py 4000:/tmp/m/foto-a.jpg 9000:/tmp/m/foto-gross.jpg:120
ffmpeg -loop 1 -i /tmp/m/foto-a.jpg -t 6 -vf "scale=1920:960,format=yuv420p" -c:v libx264 /tmp/m/video-a.mp4
for m in ordner einzeldatei browser safari; do node scripts/test-e2e.js /tmp/m /tmp/aus-$m $m; done
node scripts/test-hotspots.js /tmp/m /tmp/aus-hs
node scripts/test-schutz.js /tmp/m /tmp/aus-schutz
node scripts/test-zip64.js /tmp/aus && python3 -c "import zipfile; zipfile.ZipFile('/tmp/aus/z64-true.zip').testzip()"
```

## Datenmodell (gallery.json, Datenfassung 3)

Mit Passwort steht in gallery.json nur die verschlüsselte Hülle:
`{"format":"galerie360","verschluesselt":{"v":1,"kdf":"PBKDF2-SHA256","iterationen":600000,"salz":…,"iv":…,"daten":…}}`
(AES-256-GCM). Fassung 3 ergänzt je Album `"freigabe": {"art": "oeffentlich" | "entwurf"}` bzw.
`{"art": "link", "name": "<26 Zeichen a–z, 2–7>"}` und `einstellungen.webadresse`.

Fassung 1 (ohne Hotspots) wird beim Öffnen ergänzt (`ergaenzen` in `js/app.js`,
`G360.hsErgaenzen` in `js/hotspots.js`); nichts wird verworfen.

```jsonc
{
  "format": "galerie360", "version": 2,
  "einstellungen": {
    "hotspotStil": { "groesse": 44, "farbe": "#ffffff", "form": "kreis", "hintergrund": true, "hgFarbe": "#1d4ed8",
                     "rahmen": true, "rahmenFarbe": "#ffffff", "deckkraft": 1, "schatten": true, "beschriftung": false },
    "hotspotTooltip": true, "hotspotUmschalter": true, "hotspotAnimation": true
  },
  "hotspotVorlagen": [{ "id": "e-…", "name": "…", "symbol": {…}, "stil": {…} | null, "typ": "info", "medium": "foto" }],
  "alben": [{ "medien": [{ "id": "…", "typ": "foto",
    "hotspots": [{
      "id": "…", "yaw": 21.5, "pitch": 8.1,            // Grad; yaw 0 = Bildmitte, positiv = rechts
      "titel": "Hochkalter", "sichtbar": true,
      "symbol": { "art": "icon", "name": "mountain", "knoten": [["path", {"d": "…"}]] }
              // oder { "art": "zeichen", "text": "🏔️" } oder { "art": "bild", "src": "media/symbole/x.png" }
      "stil": null,                                     // null = Galerie-Standard
      "aktion": { "typ": "info",                        // info | medium | link | keine
                  "text": "**fett** …", "bild": "media/infobilder/x.jpg", "bildText": "…",
                  "transparent": false, "linie": true,
                  "knoepfe": [{ "text": "…", "typ": "medium", "ziel": { "medium": "<id>", "blick": null } },
                              { "text": "…", "typ": "link", "url": "https://…", "neuerTab": true }],
                  "ziel": { "medium": "<id>", "blick": { "yaw": 0, "pitch": 0, "fov": 75 } },   // bei typ medium
                  "url": "https://…", "neuerTab": true },                                        // bei typ link
      "zeit": { "von": 10, "bis": 25 },                 // nur Videos; null = immer sichtbar
      "pausieren": true                                 // Video anhalten, solange das Fenster offen ist
    }]
  }]}]
}
```

In die exportierte `index.html` kommen nur sichtbare Hotspots und nur die Felder,
die die Galerie braucht; Icons reisen als Knotenliste mit, die Bibliothek nicht.
