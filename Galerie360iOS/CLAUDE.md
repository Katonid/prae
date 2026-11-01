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
  **Keine Entitlements** (bis die App-Id iCloud trägt, siehe Abgleich).
- **Versionierung:** Patch + Build je +1 bei jeder neuen Fassung
  (`MARKETING_VERSION` und `CURRENT_PROJECT_VERSION`, Debug und Release, in
  App- UND Testziel — und im Apple-TV-Projekt `Galerie360TV.xcodeproj`
  gleich mitziehen). 1.0.0 (1) Ordner-Fassung, 1.0.1 (2) Fotos-Mediathek,
  1.0.2 (3) Apple-TV-App, 1.0.3 (4) iCloud-Abgleich, 1.0.4 (5) unverzerrte Vorschauen, 1.0.5 (6) Lautstärke am Apple TV.
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
  Application Support, Schlüssel = `localIdentifier` (je Gerät verschieden).
- **Abgleich über iCloud (seit 1.0.3, Wunsch des Nutzers 11/2026: „Alben,
  die ich auf einem Gerät anlege, sollen sich auf ein anderes
  übertragen").** Zwei Teile:
  - *Alben und Ordner* überträgt iCloud Fotos selbst. Falle: Legen zwei
    Geräte den Ordner „Galerie 360" an, bevor der erste übertragen ist,
    stehen danach ZWEI gleichnamige Ordner oben in der Mediathek. Bis 1.0.2
    las die App nur einen (Kennung in `UserDefaults`) — die Galerien des
    anderen Geräts blieben unsichtbar. Seit 1.0.3 liest
    `FotoBibliothek.wurzeln()` ALLE gleichnamigen; neue Galerien entstehen
    im zuletzt benutzten.
  - *Notizen*: `ICloudNotizen` (Gemeinsam/NotizenWolke.swift) legt sie im
    iCloud-Schlüsselwertspeicher (`NSUbiquitousKeyValueStore`, Schlüssel
    `notizen-v1`) ab, geschlüsselt nach `PHCloudIdentifier` (übersetzt per
    `cloudIdentifierMappings`/`localIdentifierMappings`). Je Eintrag gewinnt
    der jüngere Zeitstempel (`geaendert`); Leeren bleibt als leerer Eintrag
    mit Zeitstempel stehen, damit es sich überträgt. Nicht zuordenbare
    Kennungen (Aufnahme noch nicht angekommen) bleiben unberührt und kommen
    beim nächsten Abgleich dran (Start, Fotozugriff, `bibliothek.stand`,
    Vordergrund, iCloud-Meldung). Die Rechnung ist rein
    (`Notizen.zusammenfuehren`) und in `NotizenTests` geprüft.
  - **Entitlement steht NOCH NICHT im Projekt** (Stand 1.0.3). Ohne
    `com.apple.developer.ubiquity-kvstore-identifier` verhält sich der
    Speicher rein lokal — kein Fehler, nur kein Abgleich der Notizen. Erst
    muss die App-Id `de.familie.galerie360` in der Entwicklerkonsole die
    Fähigkeit „iCloud" tragen (Lehre Urlaubstagebuch 1.0.44/1.0.45: ein
    Recht, das die App-Id nicht trägt, macht das Projekt unsignierbar).
    Wenn der Nutzer das bestätigt: `Config/Galerie360.entitlements` mit
    `com.apple.developer.ubiquity-kvstore-identifier` =
    `$(TeamIdentifierPrefix)$(CFBundleIdentifier)` und
    `CODE_SIGN_ENTITLEMENTS` in BEIDEN Projekten (iOS- und TV-Ziel, Debug
    und Release) — gleicher Wert = gemeinsamer Speicher.
- **Galerie umbenennen/löschen** (seit 1.0.3, gemeldet 11/2026: „kann weder
  den Namen ändern noch die Galerie löschen" — Umbenennen stand bis dahin
  versteckt im „+"-Menü der Galerie, Löschen gab es nicht): in der
  Galerienliste nach links wischen oder lange drücken; in der Galerie das
  „…"-Menü oben rechts. Löschen entfernt nur Ordner und Alben, nie Aufnahmen.
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

- **Vorschaubilder unverzerrt** (seit 1.0.4, Nutzer 11/2026: „diese verzerrten
  360-Grad-Ansichten … mach eine schöne Vorschau daraus"). `AssetBild` zeigt
  bei 2 : 1-Aufnahmen nicht das Rundumbild, sondern rechnet per
  `Ausschnitt.ansicht` (Gemeinsam/Ausschnitt.swift, CPU, bilinear) den
  Ausschnitt der Startansicht — dieselbe Rechnung wie der Betrachter,
  Bildwinkel auf 55–90° begrenzt. Quelle nur so breit wie nötig
  (`quellbreite`, höchstens 4096; PhotoKit liefert mit `.fast` manchmal das
  Original, deshalb `hoechstens`). Ergebnisse im `NSCache`
  (`VorschauAnsicht`); andere Seitenverhältnisse wie bisher. Videos: das
  Standbild von PhotoKit, ebenso umgerechnet. Tests: `AusschnittTests`.

## Apple-TV-App (seit 1.0.2)

Wunsch des Nutzers (11/2026): auf dem Apple TV ansehen, mit Wischen auf der
Fernbedienung umsehen, Zoom „irgendwie einstellen".

- Eigenes Projekt `Galerie360TV.xcodeproj` (Ziel `Galerie360TV`, Ordner
  `Galerie360TV/`), **dieselbe Bundle-Id** `de.familie.galerie360` — ein
  App-Store-Eintrag für iPhone, iPad und Apple TV. tvOS 17, Team und
  `ITSAppUsesNonExemptEncryption = NO` wie oben (`Config/InfoTV.plist`).
  Symbol als tvOS-Ebenenbild (`App Icon & Top Shelf Image.brandassets`,
  Vorder- und Hinterebene + Top-Shelf-Bilder, gezeichnet nach
  `galerie360/scripts/generate-icons.py`).
- **Gemeinsamer Code in `Gemeinsam/`** (Betrachter, Fotos-Zugriff, Laden,
  Notizen, Modell) — beide Projekte binden den Ordner ein. Plattform-
  unterschiede per `#if os(iOS)` / `#if os(tvOS)`: Bewegungssensor, Kneifen,
  Tippen nur iOS; **Ändern der Mediathek nur iOS** (das Apple TV zeigt nur
  an).
- Siri Remote (`PanoramaFlaeche.pressesBegan`, `Steuerung.gedrueckt`):
  Wischen auf der Touch-Fläche = `UIPanGestureRecognizer` mit
  `.indirect`-Berührungen (1,6-fach empfindlicher, mit Schwung); Ring
  oben/unten = Zoom; links/rechts = blättern; Mitte = Hilfe ein/aus;
  Play/Pause = Video; „Zurück" geht an tvOS weiter (schließt). Nicht
  behandelte Tasten gehen mit Begin/Ende an `super` — sonst bleibt
  tvOS-Navigation hängen.
- **Lautstärke bei Videos** (gemeldet 11/2026: „Tasten auf der Fernbedienung
  ohne Funktion"; seit 1.0.5): `BetrachterTV.tonAn` aktiviert die
  Audio-Sitzung und meldet den Player per `MPNowPlayingSession`
  (`automaticallyPublishesNowPlayingInfo`, `becomeActiveIfPossible`) als
  „Now Playing" an; Titel über `externalMetadata`. Ohne das regelt die Siri
  Remote bei Ton über HomePod/AirPlay nichts — ein AVPlayer als
  SceneKit-Textur ist für tvOS sonst keine Wiedergabe. Ton über den
  Fernseher (HDMI-CEC/IR) ist davon unabhängig. **Am Gerät nicht geprüft.**
- **Am Gerät NICHT geprüft:** ob tvOS einer eigenen App Zugriff auf iCloud
  Fotos gibt (PhotoKit ist ab tvOS 14 da, die Praxis steht nirgends sicher);
  Empfindlichkeit des Wischens. Notizen (Titel, Startansicht) kommen erst
  mit dem iCloud-Entitlement aufs Apple TV (siehe Abgleich).
- Bau: Job „Apple-TV-App übersetzen" in `galerie360app-test.yml`
  (tvOS-Simulator). „iOS-Apps bauen" kennt nur iOS-Ziele.

## Noch nicht in der App

Hotspots, Export zur Web-Galerie (ZIP für den Webspace), Übernahme einer
Web-Galerie (Sicherung) in Fotos-Alben.

## Tests

`Galerie360Tests/` (XCTest, App als Host): `PanoramaTests`, `NotizenTests`,
`SortierungTests`, `AusschnittTests`. PhotoKit selbst ist im Simulator ohne Berechtigung nicht
prüfbar. Läuft in `.github/workflows/galerie360app-test.yml` bei jedem Push
unter `Galerie360iOS/`; der Bau zusätzlich in `ios-apps-build.yml`.
