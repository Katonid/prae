# 🌗 Himmelskompass – Sonne & Mond PWA

Eine installierbare Progressive Web App, die für einen frei wählbaren Ort und ein frei wählbares Datum anzeigt:

- **Sonne:** Auf- und Untergang, bürgerliche/nautische/astronomische Dämmerung, goldene Stunde, blaue Stunde, Sonnenhöchststand, Tageslänge und ein farbiger Tagesverlaufs-Balken
- **Mond:** Mondphase (mit Grafik), Beleuchtungsgrad, Auf- und Untergang, Entfernung sowie nächster Voll- und Neumond
- **3D-Kompass:** Aktuelle Position von Sonne und Mond am Himmel (Azimut und Höhe, auch unter dem Horizont), mit Zeit-Schieberegler, frei dreh-/kippbar per Fingergeste und optional am echten Gerätekompass ausrichtbar

## Bedienung

- **Datum:** oben wählen – das aktuelle Datum ist vorausgewählt („Heute“-Knopf setzt zurück)
- **Ort:** wird beim Start automatisch per Geolocation bestimmt; alternativ auf die Karte tippen oder den Marker ziehen („📍 Mein Standort“ bestimmt den Standort erneut)
- **Kompass:** Der Schieberegler stellt die Uhrzeit ein („Jetzt“ springt zur aktuellen Zeit und folgt ihr dann minütlich)

Alle Zeiten werden in der Zeitzone des Geräts angezeigt.

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
