# Container-Finder

Progressive Web App, die Altglas- und Altpapiercontainer und öffentliche
Toiletten auf einer Karte zeigt — mit amtlichen Daten für Bochum, Dortmund,
München und Salzburg, einem festen OpenStreetMap-Stand für das Ruhrgebiet
(mit Witten und Castrop-Rauxel), München mit dem Fünfseenland (Pilsensee) sowie
Salzburg mit dem Berchtesgadener Land, und live aus OpenStreetMap überall sonst.

**Adresse:** https://katonid.github.io/prae/container-finder/

## Funktionen

- Karte (Leaflet, OpenStreetMap-Kacheln), Start auf dem eigenen Standort
- „Nächster Container": die zehn nächsten Standorte mit Entfernung (Luftlinie)
- Umschalter Altglas / Altpapier / WC (einzeln an und aus)
- Toiletten mit Gebühr, Barrierefreiheit, Euroschlüssel, Wickeltisch, Öffnungszeiten
- Hell/Dunkel unabhängig vom Gerät (Knopf oben rechts)
- Detailblatt: Adresse, Containerarten, Datenquelle, „Route in Apple Karten",
  „Standort falsch oder fehlt?" (OSM-Hinweis an der Stelle)
- Ortssuche (Nominatim)
- Offline: App, amtliche Daten, zuletzt geladene OSM-Standorte und angesehene
  Kartenkacheln; heller und dunkler Modus

## Auf dem iPhone/iPad installieren

1. Die Adresse oben in **Safari** öffnen.
2. Teilen-Knopf (Quadrat mit Pfeil) → **„Zum Home-Bildschirm"** → „Hinzufügen".
3. Beim ersten Start die Frage nach dem Standort mit „Erlauben" beantworten.
   Falls versehentlich abgelehnt: Einstellungen → Datenschutz & Sicherheit →
   Ortungsdienste → Safari-Websites → „Beim Verwenden der App".

## Daten aktualisieren

```
cd container-finder
python3 scripts/daten-aktualisieren.py
```

Holt alle amtlichen Datensätze neu (Bochum, Dortmund, München, Stadt und Land
Salzburg) und schreibt je eine Datei nach `daten/`. Den OpenStreetMap-Stand der
festen Gebiete (`daten/osm-regionen.json`) holt der Arbeitsablauf
„Container-Finder – Daten aktualisieren" (Overpass). Fehlende Bochumer Adressen werden
per Nominatim nachgeschlagen (1 Anfrage/s); bereits bekannte stehen in
`scripts/adressen-cache.json` und werden nicht erneut abgefragt. Danach
`FASSUNG` in `sw.js` hochzählen, damit die Geräte die neuen Daten laden.

## Quellen und Lizenzen

- Kartendaten und Container außerhalb Bochum/Dortmund: © OpenStreetMap-Mitwirkende, ODbL 1.0
- Bochum: Umweltservice Bochum (USB), Open Data Bochum, CC0 1.0
- Dortmund: EDG und Stadt Dortmund, Open Data Dortmund, Datenlizenz Deutschland – Zero – 2.0
- München: Landeshauptstadt München, Open Data München, Datenlizenz Deutschland – Namensnennung – 2.0
- Salzburg: Stadt Salzburg, data.stadt-salzburg.at, CC BY 3.0 AT
- Land Salzburg: Recyclinghöfe, Open Government Data (data.gv.at)
- Leaflet: BSD-2-Clause (`vendor/leaflet/LICENSE`)
