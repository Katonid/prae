# Projekt Container-Finder (Web-App, Altglas & Altpapier)

> Die übergreifenden Regeln (PR-Rhythmus, Bau in GitHub Actions) stehen in
> der `CLAUDE.md` im Wurzelverzeichnis und gelten hier genauso.

- Code: `container-finder/` — statische PWA ohne Bauschritt (ES-Module, kein
  Framework). Einzige fremde Bibliothek: **Leaflet 1.9.4 als lokale Kopie**
  in `vendor/leaflet/` (kein CDN — sonst startet die App offline nicht).
  Wird vom Pages-Arbeitsablauf automatisch mit ausgeliefert:
  https://katonid.github.io/prae/container-finder/
- Zielgeräte: iPhone und iPad, Safari, „Zum Home-Bildschirm".

## Versionierung

Bei jeder neuen Fassung, ohne Nachfrage:
- `FASSUNG` in `sw.js` hochzählen (`v1` → `v2` …) — sonst bleibt auf den
  Geräten der alte Zwischenspeicher stehen.
- `FASSUNG` in `js/app.js` (Anzeige im Info-Blatt), Patch +1.
- Neue Dateien in `DATEIEN` in `sw.js` eintragen.

## Datenquellen

| Quelle | Datei | Lizenz | Inhalt |
|---|---|---|---|
| USB Bochum (Open Data Ruhr) | `daten/bochum.json` | CC0 1.0 | nur Altglas + Wertstoffhöfe |
| EDG Dortmund (open-data.dortmund.de, `edg-abfallentsorgung`) | `daten/dortmund.json` | dl-de/zero-2.0 | Altglas, Altpapier, Recyclinghöfe |
| OpenStreetMap (Overpass) | zur Laufzeit, IndexedDB | ODbL | ganz Deutschland |

Aktualisieren: `python3 scripts/daten-aktualisieren.py` (nur Standardbibliothek).

Fallen und Entscheidungen:
- **Die Bochumer CSV hat Koordinaten, aber fast keine Adressen** (262 von 284
  Containerinseln: `Adresse` = `NULL`). Das Skript schlägt sie per Nominatim
  RÜCKWÄRTS nach (1 Anfrage/s, eigener User-Agent) und merkt sie sich in
  `scripts/adressen-cache.json` — dieser Cache gehört ins Repo, sonst fragt
  jede Aktualisierung alle 260 Adressen neu. Solche Adressen tragen
  `ungefaehr: true` und werden als „bei …" angezeigt.
- **Bochum führt kein Altpapier** (Spalte fehlt; Papier geht dort über die
  blaue Tonne). Papiercontainer in Bochum kommen allein aus OSM.
- In der Bochumer CSV stehen auch Lager, Verwerter (bis Krefeld), Deponien,
  Gewerbekunden — die werden verworfen. Übernommen werden Containerinseln mit
  `Glascontainer > 0` und Wertstoffhöfe; eine Insel < 80 m vom Wertstoffhof
  gilt als derselbe Platz.
- Dortmund führt Glas und Papier als GETRENNTE Einträge am selben Platz; das
  Skript fasst Einträge < 25 m zu einem Standort zusammen.
- Beide Portale senden `Access-Control-Allow-Origin: *` — Live-Laden ginge.
  Entschieden (09/2026) für einen festen Stand im Repo: robuster, offline.

## Zusammenführen (js/daten.js)

Amtlich hat Vorrang. Ein OSM-Container < 30 m (`DOPPELT_M`) von einem
amtlichen Standort verschwindet; hat er eine Art, die dem amtlichen fehlt,
wird sie dem amtlichen angehängt (`ergaenzt`, mit Hinweis im Detailblatt).

## OSM / Overpass (js/osm.js)

- Abfrage in festen **Rasterzellen von 0,1°**, erst ab **Zoom 13**,
  entprellt (700 ms nach `moveend`), mehrere Zellen in EINER Abfrage
  (zeilenweise, höchstens 6). Zellen sind 7 Tage frisch; ohne Netz gelten
  auch ältere aus IndexedDB. Unter Zoom 13 wird nur vom Gerät gelesen.
- Server-Liste wie in `heute-in-der-naehe` (geprüft mit
  `.github/workflows/overpass-check.yml`). Aus der Claude-Umgebung ist
  Overpass NICHT erreichbar — testen im Browser oder per Arbeitsablauf.
- „Nächster Container" lädt Zellen im Umkreis von 3 km, bei weniger als drei
  Treffern 15 km — unabhängig vom Zoom.

## Nutzungsregeln der OSM-Dienste

- **Nominatim-Suche nur beim Abschicken**, nie beim Tippen (Autovervoll-
  ständigung ist laut Richtlinie verboten), höchstens 1/s.
- **Kacheln**: `crossOrigin: true` (sonst opake Antworten, die Safari mit
  mehreren MB je Stück auf das Speicherkontingent anrechnet). Der Service
  Worker merkt NUR angesehene Kacheln (max. 800, 30 Tage) — kein Vorab-Laden.
- Dunkelmodus: Kacheln per CSS-Filter umgekehrt (kein eigener Kachelserver).

## Oberfläche

Bedienung unten in Daumenreichweite (Filter, Suche, „Nächster Container",
Standort); Blatt für Details/Listen fährt darüber auf. `zentrieren()` setzt
einen Punkt in die Mitte des FREIEN Kartenteils über dem Blatt. Leaflets
untere Ecke (Quellenangabe) wird per ResizeObserver über die Leiste gehoben.
