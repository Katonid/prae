# Projekt Galerie 360 (iOS-App)

> Die übergreifenden Regeln (PR-Rhythmus, iOS-Pflichten, Bau in GitHub
> Actions) stehen in der `CLAUDE.md` im Wurzelverzeichnis und gelten hier
> genauso. Die Web-App gleichen Namens liegt in `galerie360/` (eigene
> `CLAUDE.md`) — ihre Lehren gelten für das Galerie-Format auch hier.

- Wunsch des Nutzers (10/2026): die 360°-Galerien „für die Zukunft für mich
  sichern", lokal bzw. in der eigenen Cloud, mit Betrachter — Apples Fotos
  kann das nicht. Gewählt: **ansehen und bearbeiten in der App, gespeichert
  in iCloud Drive**. Auf die Bedingung „nur wenn es flüssig läuft, sonst
  lieber neu entwickeln" hin: **nativer Neubau** (SwiftUI + SceneKit +
  AVFoundation), keine Hülle um die Web-App — die hätte Safaris Grenzen
  geerbt (Videobilder je Bild in WebGL kopieren, Gigabyte-Videos über eine
  JS-Brücke). Garantiert ist damit nichts: Flüssigkeit zeigt nur ein Gerät
  (TestFlight); hier läuft nur der Bau und die Tests im Simulator.
- iPhone + iPad, iOS 17, SwiftUI, Swift 5, keine Pakete. Bundle-Id
  `de.familie.galerie360` — nach dem ersten Signieren nicht mehr ändern.
  **Keine Entitlements** (kein iCloud-Container): iCloud Drive wählt der
  Nutzer als Ordner über die Dateien-App (`fileImporter` mit `.folder`,
  Lesezeichen in `UserDefaults`, Sicherheitszugriff dauerhaft offen). So
  braucht die App-Id keine iCloud-Fähigkeit — vgl. die Entitlements-Lehre
  in der Wurzel-`CLAUDE.md`. Alternativ „Auf diesem Gerät" (Dokumente,
  in der Dateien-App sichtbar: `UIFileSharingEnabled`,
  `LSSupportsOpeningDocumentsInPlace` in `Config/Info.plist`).
- **Versionierung:** Patch + Build je +1 bei jeder neuen Fassung
  (`MARKETING_VERSION` und `CURRENT_PROJECT_VERSION`, Debug und Release, in
  App- UND Testziel). Erste Fassung: 1.0.0 (1).
- Team `F4989GSTWS`, `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` als
  Build-Einstellung, zusätzlich in `Config/Info.plist`. PhotosPicker braucht
  keine Fotos-Berechtigung (läuft außerhalb der App).

## Galerie-Format = das der Web-App

- Eine Galerie ist ein Ordner mit `gallery.json`, `media/fotos`,
  `media/fotos/web` (4096er-Fassung), `media/videos`, `media/poster`,
  `thumbnails` — genau wie ein Projektordner der Web-App. Beide Programme
  öffnen dieselben Galerien; eine in der Dateien-App entpackte
  „Sicherung (ZIP)" der Web-App erscheint in der Liste (Suche eine Ebene
  tiefer, `Bibliothek.suchen`).
- **gallery.json wird als freies JSON gehalten** (`Galerie.daten`,
  `JSONObjekt`), nie in Structs umgegossen und zurückgeschrieben: Hotspots,
  Einstellungen, Freigaben, Rundgänge, `galerieOrdner` … kennt nur die
  Web-App und müssen beim Speichern unverändert bleiben (Test:
  `ModellTests.testAendernBehaeltUnbekannteFelder`). `Album`/`Medium` sind
  nur Lese-Ansichten.
- Namen wie in der Web-App: `Kennung.neu` (= G.neueId), `Kennung.lesbar`
  (= G.sauberName), Albumordner `<titel>-<26 a–z2–7>`; der Ordner folgt dem
  Titel, bis `ordnerFest` (veröffentlicht) — sonst bräche der Link.
- Import (`Import.swift`) erzeugt dieselben Einträge wie fotoImport/
  videoImport: Original (JPEG/PNG unverändert, HEIC → JPEG, damit es in
  jedem Browser geht), 4096er-Fassung ab 4096 px, Vorschaubild 800 × 500
  (Mitte des Rundumbilds — die Web-App rechnet eine Perspektive; reicht
  fürs Raster), Standbild `media/poster`, Codec-Kennung aus `avcC`/`hvcC`
  wie G.mp4Info (`Import.codecKennung`). Videos werden NICHT fürs Netz
  umgeordnet — das holt „Website fertigstellen" der Web-App nach (`q.netz`
  fehlt).
- Passwort: dasselbe Verfahren wie die Web-App (AES-256-GCM, PBKDF2-SHA256,
  Tag hinten an den Geheimtext angehängt wie WebCrypto). Test gegen einen
  echten WebCrypto-Vektor (`KryptoTests`). „Auf diesem Gerät angemeldet
  bleiben" = abgeleiteter Schlüssel im Schlüsselbund
  (`AfterFirstUnlockThisDeviceOnly`, Konto = Ordnername), nie das Passwort.
  Passwort festlegen/ändern gibt es (noch) nur in der Web-App.

## Betrachter

- SceneKit, Kugel mit EIGENER Geometrie (`PanoramaSzene.kugel`): Bild-
  koordinaten exakt wie der Fragment-Shader der Web-App (u = Länge/2π + 0,5,
  v = 0,5 − Breite/π), Kamera R = Ry(−yaw)·Rx(pitch), Bildwinkel senkrecht
  und im Hochformat aufgeweitet wie `_vfov()`. Dadurch zeigt ein gespeicherter
  Blick in App und Web dieselbe Stelle. Tests: `PanoramaTests` (Rechnung UND
  ein im Simulator gerendertes Prüfbild).
- Video: `AVPlayer` direkt als `material.diffuse.contents` — Hardware-
  Dekodierung, kein Kopieren je Bild wie in WebGL. Fassung: breiteste bis
  5760 (wie `MOBIL_VIDEO` im Web). iCloud-Dateien vorher per
  `NSFileCoordinator` ganz herunterladen (`Datei.bereitstellen`).
- Fotos bis 8192 px Breite als Textur (ImageIO-Verkleinerung).
- Start ohne Bedienung, Tippen zeigt sie (wie `vollbildStart` im Web);
  „← Album" oben links; Bewegungssteuerung über CoreMotion
  (`Steuerung.szenenLage`, Bezug `.xArbitraryZVertical`, Versatz so, dass der
  Sensor beim aktuellen Blick einsetzt). **Die Drehrichtungen im Querformat
  sind am Gerät NICHT geprüft** — erste Stelle, falls es dort falsch dreht.

## Noch nicht in der App (Web-App benutzen)

Hotspots anzeigen/bearbeiten, „ZIP für den Webspace", Galerie-Link,
Passwort festlegen/ändern, Freigaben ändern, Videos fürs Netz umordnen.

## Tests

`Galerie360Tests/` (XCTest, App als Host): `KryptoTests`, `ModellTests`,
`PanoramaTests`. Läuft in `.github/workflows/galerie360app-test.yml` bei
jedem Push unter `Galerie360iOS/`; der Bau zusätzlich in `ios-apps-build.yml`.
