# Heute in der Nähe 📍

Eine installierbare Progressive Web App, die Reisenden und Einheimischen
interessante, nützliche und sehenswerte Orte in der unmittelbaren Umgebung
zeigt – **weltweit**, auf Basis offener Daten und komplett **ohne API-Schlüssel
oder Benutzerkonto** nutzbar.

## Features (MVP / Phase 1)

- **Standortbestimmung** mit verständlicher Zustimmung, plus vollständiger
  Fallback: Ortssuche (Nominatim), Punkt auf der Karte wählen, zuletzt
  verwendete Orte
- **8 Kategorien** (Natur, Fotospots, Essen & Trinken, Familie, Sport,
  Shopping, Kultur, Praktisches) mit ~70 konfigurierbaren Unterkategorien
- **Umgebungssuche** über die Overpass API (OpenStreetMap), sortiert nach
  Entfernung, Beliebtheit, Öffnungsstatus, kostenlos, beste Empfehlung,
  beste Fotospots
- **Schnellfilter**: Nur geöffnet, Kostenlos, Für Familien, Schlechtes
  Wetter, Draußen, Fotospots, Geheimtipps, Max. 15 Minuten entfernt
- **Suchradius** 1–100 km oder nach Fahrzeit (5–60 Minuten)
- **Listen- und Kartenansicht** (Leaflet + Marker-Clustering, OSM- und
  Satelliten-Layer, „Diesen Bereich durchsuchen“, Suchradius-Anzeige)
- **Detailansicht** mit Öffnungszeiten (inkl. „jetzt geöffnet“-Auswertung),
  Preisinfo, Barrierefreiheit, Hunde-/Familienfreundlichkeit, Website,
  Telefon, Adresse, Vorschaubild (Wikimedia/Wikidata)
- **Fotospot-Infos**: beste Tageszeit, Sonnenauf-/-untergang (eigene
  astronomische Berechnung), Blickrichtung (sofern in OSM erfasst), Fototipps
- **Externe Navigation**: Google Maps, Apple Karten, Waze, OpenStreetMap –
  wahlweise Auto, zu Fuß, Fahrrad, ÖPNV
- **Favoriten + eigene Listen**, offline verfügbar (IndexedDB)
- **Intelligente Empfehlungen** („Für dich empfohlen“) nach Wetter,
  Tageszeit, Entfernung, Öffnungsstatus und Familienmodus
- **Wetter** über Open-Meteo (ohne Schlüssel)
- **Länder-/Markenlogik**: konfigurierbare Ketten-Erkennung (z. B. Tim
  Hortons in Kanada, EDEKA in Deutschland) und regionale Zusatzkategorien
  (Biergärten, State Parks, Gelaterie …) – siehe `src/config/brands.ts`
- **Offline-fähige, installierbare PWA**: Precaching der App, Runtime-Caching
  für Kartenkacheln/Bilder/Wetter, Such-Cache, Offline-Banner,
  Update-Hinweis bei neuer Version
- **i18n**: Deutsch, Englisch, Französisch (automatische Erkennung),
  km/Meilen und °C/°F automatisch nach Land oder manuell
- Hell-/Dunkelmodus, Mobile-first, Safe-Area-Unterstützung (Notch),
  barrierearme Bedienung mit großen Zielen

## Tech-Stack

React 18 · TypeScript (strict) · Vite 6 · vite-plugin-pwa (Workbox) ·
Leaflet + leaflet.markercluster · idb (IndexedDB) – bewusst ohne schwere
Zusatzframeworks.

## Installation & Start

```bash
cd heute-in-der-naehe
npm install          # Abhängigkeiten installieren
npm run dev          # Entwicklungsserver: http://localhost:5173
```

> Hinweis: Die Geolocation-API funktioniert nur über HTTPS oder localhost.

## Build & Vorschau

```bash
npm run build        # Typprüfung + Produktions-Build nach dist/
npm run preview      # Build lokal testen: http://localhost:4173
npm run icons        # PWA-Icons neu generieren (scripts/generate-icons.mjs)
```

## Konfiguration (.env)

Kopiere `.env.example` nach `.env.local`. **Es sind keine Schlüssel
erforderlich** – alle Standardquellen sind offen:

| Variable | Zweck | Standard |
|---|---|---|
| `VITE_OVERPASS_URL` | POI-Suche (OpenStreetMap) | `https://overpass-api.de/api/interpreter` |
| `VITE_NOMINATIM_URL` | Geokodierung / Ortssuche | `https://nominatim.openstreetmap.org` |
| `VITE_WEATHER_URL` | Wetter | `https://api.open-meteo.com/v1/forecast` |

Kommerzielle Dienste (Google Places, Mapbox, Foursquare) sind **nicht**
eingebunden. Falls später gewünscht, gehören deren Schlüssel ausschließlich
in einen serverseitigen Proxy – niemals ins Client-Bundle. Die
Provider-Abstraktion (`src/services/providers/types.ts`) ist dafür
vorbereitet: `PlaceProvider` implementieren, in
`src/services/providers/index.ts` registrieren – Zusammenführung und
Duplikat-Erkennung übernimmt die App.

## Projektstruktur

```
heute-in-der-naehe/
├── index.html                  # App-Shell (Meta, Manifest-Link via Plugin)
├── vite.config.ts              # Vite + PWA-Manifest + Workbox-Caching
├── scripts/generate-icons.mjs  # PWA-Icons ohne Abhängigkeiten erzeugen
├── public/icons/               # App-Icons (192/512/maskable) + Favicon
└── src/
    ├── main.tsx / App.tsx      # Einstieg, Hash-Routing, Bottom-Navigation
    ├── styles.css              # Mobile-first, Dark Mode, Safe-Areas
    ├── types.ts                # zentrale TypeScript-Typen
    ├── i18n/                   # de / en / fr + Spracherkennung
    ├── config/
    │   ├── categories.ts       # Kategorien ↔ OSM-Selektoren (erweiterbar)
    │   └── brands.ts           # Länder-/Marken-Konfiguration + Einheiten
    ├── services/
    │   ├── providers/          # Datenanbieter-Abstraktion
    │   │   ├── types.ts        #   PlaceProvider / GeocodeProvider Interface
    │   │   ├── overpass.ts     #   OpenStreetMap/Overpass-Anbindung
    │   │   ├── nominatim.ts    #   Geokodierung
    │   │   └── index.ts        #   Registry, Merge + Dedup, Cache-Fallback
    │   ├── geo.ts              # Haversine, Einheiten, Fahrzeit-Schätzung
    │   ├── sun.ts              # Sonnenauf-/-untergang, Sonnenstand (NOAA)
    │   ├── openingHours.ts     # opening_hours-Auswertung (konservativ)
    │   ├── weather.ts          # Open-Meteo + Wetterlogik
    │   ├── images.ts           # Wikimedia/Wikidata-Vorschaubilder (lazy)
    │   ├── logic.ts            # Filter, Sortierung, Empfehlungen
    │   ├── cache.ts            # Suchergebnis-Cache (Memory + IndexedDB)
    │   ├── db.ts               # IndexedDB: Favoriten, Verlauf, Cache
    │   └── navigation.ts       # Übergabe an Google/Apple/Waze/OSM
    ├── state/store.tsx         # App-Zustand (Settings, Standort, Wetter …)
    └── components/             # UI-Komponenten (Header, Karten, Sheets …)
```

## Deployment

Statisches Hosting genügt (GitHub Pages, Netlify, Cloudflare Pages …):

1. `npm run build`
2. Inhalt von `dist/` ausliefern – **über HTTPS** (Pflicht für Geolocation
   und Service Worker). Die App nutzt relative Pfade (`base: './'`) und
   Hash-Routing und läuft daher auch in Unterverzeichnissen.

In diesem Repository übernimmt `.github/workflows/pages.yml` den Build und
das Deployment nach GitHub Pages automatisch (App erscheint unter
`/heute-in-der-naehe/`).

## Datenschutz

- Standort nur nach ausdrücklicher Zustimmung; Verarbeitung ausschließlich
  lokal. An die Datenquellen gehen nur Koordinaten, nie Identitätsdaten.
- Favoriten, Listen, Verlauf und Einstellungen bleiben auf dem Gerät
  (IndexedDB/localStorage). Kein Konto, kein Tracking, keine Analytics.
- „Alle lokalen Daten löschen“ in den Einstellungen leert IndexedDB,
  localStorage und alle Service-Worker-Caches.

## Datenquellen & Lizenzen

| Quelle | Nutzung | Lizenz / Bedingungen |
|---|---|---|
| OpenStreetMap via Overpass API | POI-Daten | ODbL – Namensnennung „© OpenStreetMap contributors“ (in der App enthalten) |
| Nominatim | Geokodierung | [Usage Policy](https://operations.osmfoundation.org/policies/nominatim/): max. 1 req/s, sinnvoller Referer – die App debounced Eingaben |
| OSM-Kartenkacheln | Kartenansicht | [Tile Usage Policy](https://operations.osmfoundation.org/policies/tiles/) – für höhere Last eigenen Tile-Server/Anbieter konfigurieren |
| Esri World Imagery | Satellitenansicht | Namensnennung „Imagery © Esri“ (in der App enthalten) |
| Open-Meteo | Wetter | Frei für nicht-kommerzielle Nutzung, kein Schlüssel |
| Wikidata / Wikipedia / Wikimedia Commons | Vorschaubilder | CC-Lizenzen der jeweiligen Medien |

Bei kommerzieller oder hochfrequenter Nutzung: eigene Overpass-/Tile-
Instanzen oder kommerzielle Anbieter über die Provider-Abstraktion einbinden.

## Roadmap (Phase 2)

Besuchshistorie mit Notizen/Fotos, eigene Orte, Sammlungen teilen,
Reisegruppen & Synchronisation (optionales Konto), automatische Tagesrouten,
Community-Fotospots, weitere Sprachen.
