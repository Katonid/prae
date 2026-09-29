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
| EDG + Stadt Dortmund (open-data.dortmund.de) | `daten/dortmund.json` | dl-de/zero-2.0 | Glas, Papier, Recyclinghöfe, Toiletten |
| Landeshauptstadt München (opendata.muenchen.de, WFS geoportal.muenchen.de) | `daten/muenchen.json` | **dl-de/by-2.0 (Namensnennung Pflicht)** | Altglas, städtische Toiletten |
| Stadt Salzburg (data.stadt-salzburg.at, WFS) | `daten/salzburg.json` | CC BY 3.0 AT | Glas, Papier, WC-Anlagen |
| Land Salzburg (ArcGIS-REST, Ebene 8) | `daten/land-salzburg.json` | OGD Österreich | Recyclinghöfe im ganzen Land |
| OpenStreetMap, feste Gebiete | `daten/osm-regionen.json` | ODbL | Container + Toiletten |
| OpenStreetMap (Overpass) live | IndexedDB | ODbL | überall sonst |

Aktualisieren: `python3 scripts/daten-aktualisieren.py` (nur Standardbibliothek).
Flags: `--ohne-osm`, `--nur-osm`, `--ohne-adressen`. Eine fehlgeschlagene
Quelle lässt ihre alte Datei stehen.

**Feste OSM-Gebiete** (`REGIONEN` im Skript, auf 0,1° ausgerichtet = das
Zellraster der App): Ruhrgebiet (Bochum, Dortmund, Witten, Castrop-Rauxel),
München + Fünfseenland (Pilsensee), Salzburg + Berchtesgadener Land. Wunsch
des Nutzers 09/2026 — „für ganz Deutschland live ist schwierig". Zellen darin
fragt die App NIE bei Overpass an (`osm.gebieteSetzen`). Ein neues Gebiet: in
`REGIONEN` eintragen, pushen — mehr nicht.

**Overpass ist aus der Claude-Umgebung nicht erreichbar.** Den OSM-Teil holt
`.github/workflows/container-finder-daten.yml`: Er läuft bei jedem Push auf
einen `claude/`-Zweig, der das Skript oder den Ablauf ändert, und legt das
Ergebnis als Commit auf DENSELBEN Zweig. Also: nach so einem Push auf diesen
Commit WARTEN und `git pull`, bevor der PR-Link rausgeht. Von Hand auf `main`
gestartet, pusht er auf einen neuen Zweig `claude/container-finder-daten-<Lauf>`
(nie direkt auf main) — daraus dann einen PR machen.

Fallen und Entscheidungen:
- **Die Bochumer CSV hat Koordinaten, aber fast keine Adressen** (262 von 284
  Containerinseln: `Adresse` = `NULL`). Das Skript schlägt sie per Nominatim
  RÜCKWÄRTS nach (1 Anfrage/s, eigener User-Agent, bei 429 Pause) und merkt
  sie sich in `scripts/adressen-cache.json` — dieser Cache gehört ins Repo.
  Solche Adressen tragen `ungefaehr: true` und werden als „bei …" angezeigt.
- **Bochum und München führen kein Altpapier** (dort blaue Tonne). Papier-
  container kommen dort allein aus OSM.
- In der Bochumer CSV stehen auch Lager, Verwerter, Deponien, Gewerbekunden —
  verworfen. Übernommen: Containerinseln mit `Glascontainer > 0` und
  Wertstoffhöfe (Kürzel `WEH ` UND `WSH `); Insel < 80 m vom Hof = derselbe Platz.
- Dortmund und Salzburg führen Glas und Papier als GETRENNTE Einträge;
  zusammengefasst werden Einträge < 25 m (Salzburg zusätzlich über
  `STANDPLATZNUMMER`).
- Das Münchner WC-Verzeichnis hat eine Zeile JE KABINE (Damen/Herren/
  barrierefrei) — zusammengefasst < 25 m. Die Beschreibungen enthalten
  „Bild: http://badsyip001.srv.muenchen.de/…" — Intranet, wird entfernt.
- „Nette Toilette" (Dortmund, Salzburg) = Toilette in Geschäft/Lokal, ohne
  Verzehr nutzbar — mit Hinweis angezeigt. In OSM gelten `access=customers`
  und `permit` als NICHT öffentlich.
- Der Datenstand je Datei heißt in der App „abgerufen am" — es ist das Datum
  des Skriptlaufs, nicht das Änderungsdatum der Quelle.

## Zusammenführen (js/daten.js)

Amtlich hat Vorrang. Ein OSM-Standort < 30 m (`DOPPELT_M`) von einem
amtlichen Standort DERSELBEN Art (Toilette nur mit Toilette, Container nur
mit Container) verschwindet; hat ein OSM-Container eine Art, die dem
amtlichen fehlt, wird sie angehängt (`ergaenzt`, Hinweis im Detailblatt).
Fester OSM-Stand und live Geladenes werden vorher über die OSM-Nummer
entdoppelt (live gewinnt).

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

- Filter unten sind drei UMSCHALTER (Altglas, Altpapier, WC), einzeln an und
  aus, gespeichert als JSON in `cf-filter`; der letzte bleibt an. Der
  Hauptknopf heißt je nach Auswahl „Nächster Container" / „Nächste
  Toilette" / „Was ist in der Nähe?".
- Hell/Dunkel unabhängig vom Gerät (Wunsch 09/2026): Knopf oben rechts
  schaltet automatisch → hell → dunkel, `data-thema` am `<html>`, Schlüssel
  `cf-thema`. Ein Inline-Skript im `<head>` setzt es VOR dem ersten Zeichnen.
  Die dunklen Farbwerte stehen in `css/app.css` ZWEIMAL (Geräteeinstellung
  und feste Wahl) — beide ändern.
- Ortssuche: `countrycodes=de,at` (Salzburg).

Bedienung unten in Daumenreichweite (Filter, Suche, „Nächster Container",
Standort); Blatt für Details/Listen fährt darüber auf. `zentrieren()` setzt
einen Punkt in die Mitte des FREIEN Kartenteils über dem Blatt. Leaflets
untere Ecke (Quellenangabe) wird per ResizeObserver über die Leiste gehoben.
