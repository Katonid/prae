# 🌗 Himmelskompass – Sonne & Mond PWA

Eine installierbare Progressive Web App, die für einen frei wählbaren Ort und ein frei wählbares Datum anzeigt:

- **Sonne:** Auf- und Untergang, bürgerliche/nautische/astronomische Dämmerung, goldene Stunde, blaue Stunde, Sonnenhöchststand, Tageslänge und ein farbiger Tagesverlaufs-Balken
- **Mond:** Mondphase (mit Grafik), Beleuchtungsgrad, Auf- und Untergang, Entfernung sowie nächster Voll- und Neumond
- **3D-Kompass:** Aktuelle Position von Sonne, Mond und Milchstraßenzentrum (🌌) am Himmel (Azimut und Höhe, auch unter dem Horizont) samt Tagesbahnen mit Uhrzeiten und dem Milchstraßen-Band (galaktische Ebene) als leuchtendem Bogen; Zeit-Schieberegler mit ▶-Zeitraffer-Animation, frei dreh-/kippbar per Fingergeste und an die Gerätesensoren koppelbar (Drehung und Neigung)
- **Milchstraße:** Sichtbarkeit des galaktischen Zentrums für die gewählte Nacht – Zeitfenster, beste Zeit, Richtung/Höhe und Mondstörung
- **Karten-Overlay:** Sonnen-/Mondbahn, Auf- und Untergangsrichtungen mit Uhrzeiten um den gewählten Ort; Vollbild per Tipp auf die Karte
- **Zeitzonen:** Alle Zeiten werden in der Zeitzone des gewählten Ortes angezeigt (Offline-Bestimmung aus den Koordinaten via tz-lookup)
- **ISS-Überflüge:** Sichtbare Überflüge der Raumstation für die gewählte Nacht (SGP4-Bahnberechnung mit satellite.js, Bahndaten von CelesTrak mit localStorage-Cache)
- **AR-Himmelsansicht:** Kamera auf den Himmel richten – die App blendet live ein, wo die ISS gerade steht (mit Bahnspur, Richtungspfeil und nächstem sichtbaren Überflug), dazu Sonne, Mond und Milchstraßen-Band; ohne Sensoren per Wischen bedienbar
- **Polarlicht-Chance:** Abschätzung aus der NOAA-Kp-Prognose und der geomagnetischen Breite des Ortes
- **Kompakte Bedienung:** Tab-Navigation (Zeiten / Kompass / Nacht) mit kleiner Kartenvorschau, die sich per Tipp zum Vollbild öffnet

## Bedienung

- **Datum:** oben wählen – das aktuelle Datum ist vorausgewählt („Heute“-Knopf setzt zurück)
- **Ort:** wird beim Start automatisch per Geolocation bestimmt; alternativ auf die Karte tippen oder den Marker ziehen („📍 Mein Standort“ bestimmt den Standort erneut)
- **Kompass:** Der Schieberegler stellt die Uhrzeit ein („Jetzt“ springt zur aktuellen Zeit und folgt ihr dann minütlich)

Alle Zeiten werden in der Ortszeit des gewählten Ortes angezeigt (die Zeitzone wird offline aus den Koordinaten bestimmt und in der App angezeigt).

## Technik

- Reines HTML/CSS/JavaScript ohne Build-Schritt
- Astronomische Berechnungen in `astro.js` (Formeln nach Jean Meeus / SunCalc-Algorithmen, Genauigkeit ca. ±1 Minute für Sonnenzeiten)
- Karte: [Leaflet](https://leafletjs.com/) (lokal in `vendor/` eingebunden) mit OpenStreetMap-Kacheln
- 3D-Kompass mit reinen CSS-3D-Transformationen (keine WebGL-Abhängigkeit)
- Service Worker (`sw.js`): App-Shell wird vorgecacht, Kartenkacheln landen in einem Laufzeit-Cache → die App funktioniert offline (bereits besuchte Kartenausschnitte eingeschlossen)

### Definitionen der Fotografen-Zeiten

| Phase | Sonnenhöhe |
|---|---|
| Blaue Stunde | −8° bis −4° |
| Goldene Stunde | −4° bis +6° |
| Bürgerliche Dämmerung | −6° bis Sonnenauf-/-untergang |
| Nautische Dämmerung | −12° bis −6° |
| Astronomische Dämmerung | −18° bis −12° |

## Hosting

Die App braucht nur einen statischen Webserver mit HTTPS (Voraussetzung für Service Worker und Geolocation), z. B. GitHub Pages. Lokal testen:

```bash
cd himmelskompass
python3 -m http.server 8000
# → http://localhost:8000
```

Auf `localhost` funktionieren Service Worker und Geolocation auch ohne HTTPS.
