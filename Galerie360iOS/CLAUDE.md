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
  1.0.2 (3) Apple-TV-App, 1.0.3 (4) iCloud-Abgleich, 1.0.4 (5) unverzerrte Vorschauen, 1.0.5 (6) Lautstärke am Apple TV, 1.0.6 (7) kein AirPlay vom iPhone, 1.0.7 (8) Apple TV meldet sich im Hintergrund ab, 1.0.8 (9) Reihenfolge des Antippens, 1.0.9 (10) Galeriebild und Albenübersicht, 1.0.10 (11) Absturz bei Videos am Apple TV behoben, 1.0.11 (12) Videos am Apple TV wie in der Fotos-App, 1.0.12 (13) danach volle Qualität.
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
- **Reihenfolge des Antippens** (seit 1.0.8, Wunsch 11/2026): `PhotosPicker`
  mit `selectionBehavior: .ordered` (nummeriert, liefert in Tipp-Reihenfolge);
  `hinzufuegen` ordnet nach den übergebenen Kennungen
  (`neueInReihenfolge`), weil `fetchAssets(withLocalIdentifiers:)` in
  Mediathek-Reihenfolge liefert, und setzt per `insertAssets(at:)` ans Ende.
- **Galeriebild und Albenübersicht** (seit 1.0.9, Wunsch 11/2026): Eine
  Galerie öffnet mit einer Übersicht aller Alben als Karten mit Vorschau
  (gruppiert nach Ordnern), NICHT mehr gleich im ersten Album. Auf dem iPad
  führt „Übersicht" oben in der Seitenleiste zurück; auf dem iPhone ist die
  Seitenleiste selbst die Übersicht. Galeriebild: im Album lange auf eine
  Aufnahme drücken → „Als Galeriebild", oder in der Übersicht auf ein Album
  → „Albumbild als Galeriebild". Gespeichert in `Notizen` wie das
  Albumbild, Schlüssel = Kennung des Galerie-Ordners; ohne Wahl die
  Vorschau des ersten Albums (`vorschauAsset(galerie:)`). `SammlungsBild`
  (Mediathek.swift) zeigt Galerie-/Albumvorschau auf iOS und tvOS.
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
- **Kein AirPlay** (seit 1.0.6; gemeldet 11/2026: „seit gestern geht das
  Apple TV immer an und schaltet den Fernseher mit ein"):
  `allowsExternalPlayback = false` am AVPlayer der iOS-App. Mit
  `.playback`/`.moviePlayback` und der iOS-Einstellung „Automatisch AirPlay"
  schickte jedes Video im Betrachter sich ans Apple TV — das wachte auf und
  weckte per HDMI-CEC den Fernseher. Sinnlos obendrein: übertragen würde die
  Textur (das verzerrte Rundumbild). Ursache am Gerät NICHT bestätigt.
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
  „Now Playing" an. **NIE `item.externalMetadata` setzen** (1.0.5 bis 1.0.9
  tat es für den Titel): Das `AVPlayerItem` aus `requestPlayerItem` kennt
  den Selektor auf tvOS nicht — „unrecognized selector", Absturz bei JEDEM
  Video (gemeldet 11/2026; nachgestellt im Job „Apple-TV-Betrachter
  starten"). Grün übersetzt hatte es trotzdem. Ohne das regelt die Siri
  Remote bei Ton über HomePod/AirPlay nichts — ein AVPlayer als
  SceneKit-Textur ist für tvOS sonst keine Wiedergabe. Ton über den
  Fernseher (HDMI-CEC/IR) ist davon unabhängig. **Am Gerät nicht geprüft.**
- **Videos stockten** (gemeldet 11/2026: „stockt, lädt nach, stockt wieder
  … dieselben Videos laufen in der Galerie des Apple TV ohne weiteres").
  Das Apple TV behält von iCloud Fotos keine Originale; mit
  `deliveryMode = .highQualityFormat` streamte `requestPlayerItem` das
  Original mit seiner hohen Datenrate. Seit 1.0.11 auf tvOS `.automatic` —
  Fotos wählt die Stufe wie in der eigenen App. iOS bleibt bei
  `.highQualityFormat`. Welche Auflösung `.automatic` auf dem Apple TV
  liefert, ist am Gerät NICHT gemessen.
  **Seit 1.0.12: erst flüssig, dann volle Qualität** (Nutzer 11/2026 zu
  1.0.11: „etwas flüssiger … Bildqualität nicht mehr ausreichend"). Der
  Betrachter startet mit `.automatic` und lädt gleichzeitig per
  `Mediathek.videoOriginal` (`requestAVAsset`, `.highQualityFormat`) das
  Original GANZ aufs Gerät (PhotoKits eigener Zwischenspeicher, nicht unser
  Ordner). Ist es da, `replaceCurrentItem` + `seek` auf dieselbe Stelle →
  volle Schärfe ohne Stocken. Anzeige unten rechts „Volle Qualität wird
  geladen: x %". Liefert `requestAVAsset` keine Datei (`url.isFileURL`),
  bleibt es bei `.automatic`. Am Gerät NICHT geprüft: ob tvOS das Original
  wirklich vorab ganz lädt und wie lange das dauert.
- **Ruhezustand** (seit 1.0.7; gemeldet 11/2026, einen Tag nach 1.0.5:
  „seit gestern erwacht das Apple TV regelmäßig und schaltet den Fernseher
  ein"). Eine tvOS-App läuft im Ruhezustand nicht und kann das Gerät nicht
  selbst wecken (keine Hintergrundmodi, keine Top-Shelf-Erweiterung). Aber
  die Now-Playing-Anmeldung aus 1.0.5 blieb stehen, wenn man die App mit
  offenem Video verließ (`onDisappear` kommt dann nicht) — das Apple TV galt
  weiter als Wiedergabegerät, und Play von iPhone-Sperrbildschirm,
  Kontrollzentrum, HomePod oder Siri konnte es wecken. Seither:
  `tonAus()` bei jedem Wechsel weg von `.active` (`scenePhase`), Befehle
  nur bei aktiver App; zurück im Vordergrund meldet `tonAn` wieder an
  (ohne Abspielen). Zusammenhang am Gerät NICHT bestätigt.
- **Am Gerät NICHT geprüft:** ob tvOS einer eigenen App Zugriff auf iCloud
  Fotos gibt (PhotoKit ist ab tvOS 14 da, die Praxis steht nirgends sicher);
  Empfindlichkeit des Wischens. Notizen (Titel, Startansicht) kommen erst
  mit dem iCloud-Entitlement aufs Apple TV (siehe Abgleich).
- Bau: Job „Apple-TV-App übersetzen" in `galerie360app-test.yml`
  (tvOS-Simulator). „iOS-Apps bauen" kennt nur iOS-Ziele.
- **Start-Prüfung (seit 1.0.10): Job „Apple-TV-Betrachter starten".** Legt
  ein 360°-Foto (5760 × 2880) und ein Video (per AVAssetWriter — ffmpeg
  fehlt auf dem Läufer) per `simctl addmedia` in den tvOS-Simulator, erlaubt
  den Fotozugriff (`simctl privacy grant photos`) und startet die App im
  Prüfmodus (`SIMCTL_CHILD_GALERIE360_PRUEFUNG=foto|video`, nur Debug,
  `PruefBetrachterTV`): Betrachter mit der ersten Aufnahme. Rot, wenn die
  App nach 30 s nicht mehr läuft; der Absturzbericht (Ausnahme,
  Aufrufkette) steht dann im Protokoll. **Bei jeder Änderung am Betrachter
  auf diesen Job schauen** — er hat den externalMetadata-Absturz in einem
  Lauf gefunden, nach dem fünf Fassungen grün übersetzt hatten.

## Noch nicht in der App

Hotspots, Export zur Web-Galerie (ZIP für den Webspace), Übernahme einer
Web-Galerie (Sicherung) in Fotos-Alben.

## Tests

`Galerie360Tests/` (XCTest, App als Host): `PanoramaTests`, `NotizenTests`,
`SortierungTests`, `AusschnittTests`. PhotoKit selbst ist im Simulator ohne Berechtigung nicht
prüfbar. Läuft in `.github/workflows/galerie360app-test.yml` bei jedem Push
unter `Galerie360iOS/`; der Bau zusätzlich in `ios-apps-build.yml`.
