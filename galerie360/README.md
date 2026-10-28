# Galerie 360

Generator für 360°-Webgalerien: 360°-Fotos und -Videos (equirektangular, z. B.
aus Insta360 Studio) hineinziehen, beschriften, sortieren — heraus kommt ein
Ordner mit einer vollständig eigenständigen Website, die auf jedem
gewöhnlichen Webspace läuft (Apache, nginx, Shared Hosting), ohne Backend,
Datenbank, CDN oder Konto.

- Generator: https://katonid.github.io/prae/galerie360/ (Chrome oder Edge)
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
| `scripts/einzeldatei.py` | baut `galerie360-generator.html` |
| `scripts/test-e2e.js` | Ende-zu-Ende-Test mit Playwright |

## Prüfen

```sh
python3 scripts/testmedien.py 4000:/tmp/m/foto-a.jpg 9000:/tmp/m/foto-gross.jpg:120
ffmpeg -loop 1 -i /tmp/m/foto-a.jpg -t 6 -vf "scale=1920:960,format=yuv420p" -c:v libx264 /tmp/m/video-a.mp4
for m in ordner einzeldatei browser; do node scripts/test-e2e.js /tmp/m /tmp/aus-$m $m; done
node scripts/test-zip64.js /tmp/aus && python3 -c "import zipfile; zipfile.ZipFile('/tmp/aus/z64-true.zip').testzip()"
```
