# Projekt Galerie 360 (iOS-App)

> Die übergreifenden Regeln (PR-Rhythmus, iOS-Pflichten, Bau in GitHub
> Actions) stehen in der `CLAUDE.md` im Wurzelverzeichnis und gelten hier
> genauso. Die Web-App gleichen Namens liegt in `galerie360/` (eigene
> `CLAUDE.md`); zum Teilen mit der Familie bleibt sie das Werkzeug.

- Wunsch des Nutzers (10/2026): die 360°-Galerien „für die Zukunft für mich
  sichern", mit Betrachter — Apples Fotos kann das nicht. Auf „nur wenn es
  flüssig läuft, sonst lieber neu entwickeln" hin: **nativer Neubau**
  (SwiftUI + SceneKit + AVFoundation + PhotoKit), keine Hülle um die Web-App
  (die hätte Safaris Grenzen geerbt). Flüssigkeit zeigt nur ein Gerät
  (TestFlight); hier laufen nur Bau und Tests im Simulator.
- iPhone + iPad, iOS 17, SwiftUI, Swift 5, keine Pakete. Bundle-Id
  `de.familie.galerie360` — nach dem ersten Signieren nicht mehr ändern.
  **Keine Entitlements.**
- **Versionierung:** Patch + Build je +1 bei jeder neuen Fassung
  (`MARKETING_VERSION` und `CURRENT_PROJECT_VERSION`, Debug und Release, in
  App- UND Testziel). 1.0.0 (1) Ordner-Fassung, 1.0.1 (2) Fotos-Mediathek.
- Team `F4989GSTWS`, `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` als
  Build-Einstellung, zusätzlich in `Config/Info.plist`.
  `NSPhotoLibraryUsageDescription` als Build-Einstellung (Vollzugriff nötig:
  die App liest Aufnahmen und legt Alben an).

## Speicher: ausschließlich die Fotos-Mediathek (seit 1.0.1)

Ansage des Nutzers (11/2026): die Foto- und Videodateien sollen „in der
Fotogalerie in der Cloud liegen und die App nur darauf zugreifen … keine
weitere Speicherung an einem anderen Ort". 1.0.0 kopierte in einen Ordner
(iCloud Drive) im Format der Web-App — **ersatzlos entfernt.**

- Aufbau in Fotos: Ordner **„Galerie 360"** → je Galerie ein Ordner → darin
  Alben (= Alben der Galerie) und Ordner (= Gruppen von Unteralben, Fotos
  kennt keine Alben in Alben). `FotoBibliothek` (Fotos.swift) liest das per
  `PHCollection.fetchCollections(in:)` und ändert es nur über
  `PHPhotoLibrary.performChanges` — Alben anlegen, umbenennen, löschen
  (nur das Album, iOS fragt selbst nach), Aufnahmen hinzufügen (Verweise
  aus dem PhotosPicker per `itemIdentifier`, NIE Kopien), entfernen,
  verschieben, ordnen (`moveAssets`/`replaceAssets` — dieselbe Reihenfolge
  wie in der Fotos-App). Struktur und Reihenfolge synchronisiert iCloud
  Fotos selbst auf alle Geräte. Änderungen (auch von anderen Geräten)
  kommen über `PHPhotoLibraryChangeObserver` → `stand` → Ansichten laden neu.
- Laden: Fotos per `requestImageDataAndOrientation` (Original, aus iCloud
  wenn nötig) und ImageIO auf höchstens 8192 px; Videos per
  `requestPlayerItem` (gestreamt, nicht vorher ganz geladen). Nichts wird
  dauerhaft abgelegt.
- **Was Fotos nicht speichern kann** (eigener Titel, Beschreibung,
  Startansicht je Aufnahme, Albumbild): `Notizen` — ein paar KB JSON in
  Application Support, Schlüssel = `localIdentifier`. Nicht über iCloud
  synchronisiert (das bräuchte CloudKit/KVS und damit Entitlements); bleibt
  über Geräte-Backup erhalten. `localIdentifier` ist je Gerät verschieden —
  für einen späteren Abgleich die `PHCloudIdentifier` nehmen.
- Fehlercode 3072 (`PHPhotosError.userCancelled`) = Nutzer hat die
  Rückfrage von iOS abgebrochen — keine Fehlermeldung zeigen.

## Betrachter

- SceneKit, Kugel mit EIGENER Geometrie (`PanoramaSzene.kugel`): Bild-
  koordinaten exakt wie der Fragment-Shader der Web-App (u = Länge/2π + 0,5,
  v = 0,5 − Breite/π), Kamera R = Ry(−yaw)·Rx(pitch), Bildwinkel senkrecht
  und im Hochformat aufgeweitet wie `_vfov()`. Tests: `PanoramaTests`
  (Rechnung UND ein im Simulator gerendertes Prüfbild).
- Video: `AVPlayer` direkt als `material.diffuse.contents` — Hardware-
  Dekodierung, kein Kopieren je Bild wie in WebGL.
- Start ohne Bedienung, Tippen zeigt sie; „← Album" oben links; Stecknadel
  = aktuellen Blick als Startansicht merken; Bewegungssteuerung über
  CoreMotion (`Steuerung.szenenLage`). **Drehrichtungen im Querformat am
  Gerät NICHT geprüft** — erste Stelle, falls es dort falsch dreht.

## Noch nicht in der App

Hotspots, Export zur Web-Galerie (ZIP für den Webspace), Übernahme einer
Web-Galerie (Sicherung) in Fotos-Alben.

## Tests

`Galerie360Tests/` (XCTest, App als Host): `PanoramaTests`, `NotizenTests`,
`SortierungTests`. PhotoKit selbst ist im Simulator ohne Berechtigung nicht
prüfbar. Läuft in `.github/workflows/galerie360app-test.yml` bei jedem Push
unter `Galerie360iOS/`; der Bau zusätzlich in `ios-apps-build.yml`.
