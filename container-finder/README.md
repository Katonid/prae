# Container-Finder

Progressive Web App, die Altglas- und Altpapiercontainer auf einer Karte zeigt —
mit amtlichen Daten für Bochum und Dortmund und OpenStreetMap für den Rest
Deutschlands.

**Adresse:** https://katonid.github.io/prae/container-finder/

## Funktionen

- Karte (Leaflet, OpenStreetMap-Kacheln), Start auf dem eigenen Standort
- „Nächster Container": die zehn nächsten Standorte mit Entfernung (Luftlinie)
- Filter Altglas / Altpapier / Beides
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

Holt die Bochumer CSV und den Dortmunder EDG-Datensatz neu und schreibt
`daten/bochum.json` und `daten/dortmund.json`. Fehlende Bochumer Adressen werden
per Nominatim nachgeschlagen (1 Anfrage/s); bereits bekannte stehen in
`scripts/adressen-cache.json` und werden nicht erneut abgefragt. Danach
`FASSUNG` in `sw.js` hochzählen, damit die Geräte die neuen Daten laden.

## Quellen und Lizenzen

- Kartendaten und Container außerhalb Bochum/Dortmund: © OpenStreetMap-Mitwirkende, ODbL 1.0
- Bochum: Umweltservice Bochum (USB), Open Data Bochum, CC0 1.0
- Dortmund: EDG, Open Data Dortmund, Datenlizenz Deutschland – Zero – 2.0
- Leaflet: BSD-2-Clause (`vendor/leaflet/LICENSE`)
