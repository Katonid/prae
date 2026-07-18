# Theater-Soundboard (PWA)

Ein Soundboard für Theateraufführungen: 16 frei belegbare Felder für
Soundeffekte und Lieder – gedacht für iPad und iPhone, funktioniert aber in
jedem modernen Browser.

## Bedienung

**Matrix**
- iPad / breite Bildschirme: 4 × 4 Felder
- iPhone (hochkant): 2 × 8 Felder

**Abspielen**
- **Kurzer Tipp** auf ein Feld: Tondatei abspielen. Erneuter Tipp: Pause.
  Nochmals tippen: an derselben Stelle weiterspielen.
- **Langer Tipp** (ca. eine halbe Sekunde gedrückt halten): Tondatei wird auf
  Anfang gesetzt (das Feld blitzt kurz auf). Der nächste Tipp startet wieder
  von vorn.
- **„⏮ Alle auf Anfang“** (ganz unten): stoppt alle Tondateien und setzt sie
  auf Anfang – z. B. vor Beginn der Vorstellung.
- Mehrere Felder können gleichzeitig spielen (z. B. Musik + Effekt).
- Ein dünner Fortschrittsbalken am unteren Rand jedes Feldes zeigt die
  aktuelle Position; daneben stehen Spielzeit und Gesamtlänge.

**Felder belegen und gestalten**
1. Unten auf **„✎ Bearbeiten“** tippen (die Felder erhalten ein Stift-Symbol).
2. Ein Feld antippen. Im Dialog lassen sich einstellen:
   - **Beschriftung** des Feldes
   - **Farbe** (16 Vorschläge oder freie Farbwahl)
   - **Tondatei** („Datei wählen …“ öffnet die Dateiauswahl, auf dem iPad/iPhone
     z. B. die Dateien-App; „Entfernen“ löscht die Datei vom Feld)
3. Mit **„Fertig“** schließen und den Bearbeiten-Modus wieder ausschalten.

Alle Einstellungen und die Tondateien selbst werden lokal auf dem Gerät
gespeichert (IndexedDB) und stehen auch offline zur Verfügung – die App
braucht nach der Installation kein Internet.

## Installation auf iPad / iPhone

1. Die Seite in **Safari** öffnen.
2. **Teilen-Symbol** → **„Zum Home-Bildschirm“**.
3. Die App vom Home-Bildschirm starten (läuft dann im Vollbild).

## Hinweise

- Der Bildschirm wird während der Nutzung wach gehalten (Wake Lock), damit
  das Gerät in der Vorstellung nicht in den Ruhezustand geht.
- Unterstützte Audioformate richten sich nach dem Gerät; MP3, M4A/AAC und WAV
  funktionieren überall.
- Die Tondateien liegen nur im Browser-Speicher dieses Geräts. Beim Löschen
  der Website-Daten in Safari gehen sie verloren – Originaldateien also
  zusätzlich aufbewahren.

## Technik

- Reines HTML/CSS/JavaScript ohne Abhängigkeiten
- `manifest.webmanifest` + Service Worker (`sw.js`) → offlinefähige PWA
- Tondateien und Feld-Konfiguration in IndexedDB (`theater-soundboard`)
