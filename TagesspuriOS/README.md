# Tagesspur (iOS)

Tagesspur zeichnet ressourcenschonend im Hintergrund den genauen Standort
auf und speichert den Tagesverlauf als Track. Fotos und Videos aus der
Mediathek werden anhand ihrer Zeit- und GPS-Daten eingeblendet.

Native SwiftUI-App, iOS 17+, keine externen Abhängigkeiten.

## Funktionen

- **Hintergrund-Tracking, akkuschonend**
  - Besuchs- (CLVisit) und Signifikanz-Monitoring laufen dauerhaft mit
    minimalem Verbrauch und wecken die App auch nach Beendigung wieder.
  - Präzises GPS (10 m Genauigkeit, 25 m Distanzfilter) nur bei Bewegung;
    nach 5 Minuten Stillstand automatischer Ruhemodus.
  - Punkte werden gepuffert (20 Punkte / 90 s) und pro Tag als kompakter
    Blob gespeichert — wenig I/O, wenig Sync-Volumen.
- **iCloud-Sync (SwiftData + CloudKit, privater Container)**
  - Jedes Gerät schreibt ausschließlich Datensätze mit seiner eigenen
    Geräte-ID → keine Konflikte.
  - Alle Geräte sehen den gemeinsamen Bestand (geräteübergreifende
    Ansicht in „Tage“, Karten mit einer Farbe pro Gerät).
  - Ohne iCloud-Anmeldung arbeitet die App lokal weiter.
- **Fotos & Videos**
  - Werden zur Laufzeit per Aufnahmezeit (und GPS, falls vorhanden) dem
    Tag zugeordnet und im Tagesdetail zu „Momenten“ gruppiert
    (deterministisch: > 45 min Pause oder > 500 m Abstand = neue Gruppe),
    wenn möglich mit dem passenden Aufenthalt beschriftet.
  - Antippbar: Vollbild-Betrachter mit Wischen, Video-Wiedergabe und
    Teilen; Thumbnails auf der Karte öffnen denselben Betrachter.
  - Datenminimierung: nur Lesezugriff, keine Kopien in der App.
- **Fotoanalyse (opt-in, komplett auf dem Gerät)**
  - Apples Vision-Framework klassifiziert Aufnahmen lokal; gespeichert
    werden nur Stichwörter pro Aufnahme (MediaTag), nie Bilddaten.
  - Die Suche versteht damit auch Motive: „Picknick“, „Lagerfeuer“,
    „Hund“ … — Treffer sind als „Fotoanalyse“ gekennzeichnet, kuratierte
    Deutsch→Vision-Synonymtabelle in `SearchEngine.photoSynonyms`.
  - Ein Tag trifft, wenn jedes Suchwort belegt ist — durch Ort **oder**
    Foto („Picknick am See“).
- **Tages-Replay**
  - Jeder Tag lässt sich wie ein Film abspielen: animierter Punkt mit
    geneigter 3D-Kamera entlang des Tracks, Live-Uhrzeit, Zeitstrahl,
    Play/Pause und Tempo (1×/2×/4×).
- **Statistik (Swift Charts, ohne externe Abhängigkeiten)**
  - Kopfkarte im Tab „Tage“: Gesamtkilometer, Tage-Serie, Mini-Diagramm.
  - Statistikseite: Balkendiagramm der letzten 30 Tage, Summen,
    Aufenthalte, längster Tag.
- **Kartenstile & Darstellung**
  - Umschalter auf jeder Karte: Standard / Hybrid / Satellit, jeweils
    mit realistischem 3D-Gelände.
  - Hell/Dunkel getrennt für App und Karte einstellbar (Einstellungen →
    Darstellung), z. B. dunkle App mit heller Karte.
  - Designsprache in `Views/Theme.swift`: Markenverlauf, Hero-Karten mit
    wanderndem Licht-Schimmer, Tracks mit weißer Kontur, gebrandete
    Aufenthalts- und Start/Ziel-Marker.
- **Export & Import**
  - Umfang: einzelner Tag, Zeitraum oder alles.
  - GPX 1.1 (breit kompatibel: Tracks als `<trk>`, Aufenthalte als
    `<wpt>`) und JSON (verlustfreies Tagesspur-Backup).
  - Import: GPX-Dateien und Tagesspur-Backups; Punkte werden
    zusammengeführt, nichts doppelt.
- **Suche („Zeige mir die Tage, an denen ich an einem See war“)**
  - Deterministisch, offline, kein LLM: Stoppwörter entfernen, Synonyme
    aufklappen, Abgleich gegen die per Reverse-Geocoding angereicherten
    Aufenthalte (inkl. `inlandWater`/`ocean` der Placemarks — „See“
    trifft damit direkt erkannte Binnengewässer).
  - Ehrliche Grenze: Die Suche kennt nur Orte, an denen ein Aufenthalt
    erkannt wurde — kein Vorbeifahren, keine externe POI-Datenbank.

## Projektstruktur

```
TagesspuriOS/
├── Tagesspur.xcodeproj
├── Config/               Info.plist, Entitlements (CloudKit, Push)
└── Tagesspur/
    ├── TagesspurApp.swift
    ├── Model/            Models, LocationTracker, Geocoder,
    │                     PhotoMatcher, SearchEngine, Exporter
    └── Views/            Heute, Tage, Suche, Export, Einstellungen
```

## Einrichtung in Xcode

1. `Tagesspur.xcodeproj` öffnen, unter *Signing & Capabilities* das
   eigene Team wählen (Bundle-ID `de.familie.tagesspur`).
2. Der iCloud-Container `iCloud.de.familie.tagesspur` wird über die
   Entitlements automatisch angelegt.
3. Auf dem Gerät: Standort „Immer“ erlauben (für Hintergrund-Tracking)
   und Mediathek-Zugriff gewähren.
