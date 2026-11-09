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
  1.0.2 (3) Apple-TV-App, 1.0.3 (4) iCloud-Abgleich, 1.0.4 (5) unverzerrte Vorschauen, 1.0.5 (6) Lautstärke am Apple TV, 1.0.6 (7) kein AirPlay vom iPhone, 1.0.7 (8) Apple TV meldet sich im Hintergrund ab, 1.0.8 (9) Reihenfolge des Antippens, 1.0.9 (10) Galeriebild und Albenübersicht, 1.0.10 (11) Absturz bei Videos am Apple TV behoben, 1.0.11 (12) Videos am Apple TV wie in der Fotos-App, 1.0.12 (13) danach volle Qualität, 1.0.13 (14) Mediathek-Modus, 1.0.14 (15) Zoom in Videos und Raster, Sortierung, 1.0.15 (16) Galerie-Ersatz, 1.0.16 (17) flüssiges Raster, 1.0.17 (18) Raster in UIKit, 1.0.18 (19) Raster merkt sich die Stelle, 1.0.19 (20) Alben ordnen, 1.0.20 (21) Kachelmarken wieder da, 1.0.21 (22) Im Web teilen, 1.0.22 (23) Symbole für den Home-Bildschirm, 1.0.23 (24) Ladeanzeige am Apple TV abschaltbar, Videotextur am Apple TV selbst geholt, 1.0.24 (25) Aufnahmen ohne Ort.
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
- **Alben ordnen** (seit 1.0.19, Frage des Nutzers 11/2026: „kann ich die
  Alben in einer Galerie nicht manuell sortieren?"): in der Galerie „…" →
  „Alben ordnen …" (`AlbenOrdnen`, GalerieAnsicht.swift). Je Ebene (Galerie
  und jeder Ordner mit mehr als einem Eintrag) am Griff ziehen, oder je
  Ebene „Nach Name" / „Nach Aufnahmedatum". Gespeichert in der Mediathek:
  `PHCollectionListChangeRequest.moveChildCollections` bzw.
  `replaceChildCollections` (`FotoBibliothek.verschiebeKinder`,
  `ordneKinder`) — dieselbe Reihenfolge in der Fotos-App, auf allen
  Geräten und auf dem Apple TV (das liest `baum` in Ordnerreihenfolge).
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
- **Mediathek-Modus und normale Aufnahmen** (seit 1.0.13, Wunsch 11/2026:
  „ganz normal auf die Galerie zugreifen, Fotos und Videos als Kachel und in
  der Vollansicht, 360-Grad-Aufnahmen direkt richtig"). Gemeinsam/
  `Mediathekmodus.swift`:
  - `PHAsset.ist360` = Seitenverhältnis 2 : 1 (`Ausschnitt.istPanorama`).
    Alles andere — normale Fotos, Videos, iPhone-Panoramen — zeigt der
    Betrachter FLACH: iOS `ZoomFlaeche` (UIScrollView, Kneifen/Doppeltippen,
    seitlich wischen blättert) — für Fotos (UIImageView) UND seit 1.0.14 für
    Videos (AVPlayerLayer-Ansicht, eigene Bedienleiste wie bei 360°); Stecknadel und Bewegungssteuerung nur bei
    360°. tvOS: flache Ebene ÜBER der Kugel mit `allowsHitTesting(false)` —
    die `PanoramaFlaeche` darunter bleibt fokussiert und nimmt weiter die
    Tasten an (blättern, Play/Pause, Hilfe). Gilt auch in Galerie-Alben.
  - `MediathekQuelle` (.alle, .nur360, .videos, .album): Startseite
    Abschnitt „Fotos-Mediathek" (iOS `MediathekAbschnitt` mit „Meine Alben"
    ohne den Ordner „Galerie 360"; tvOS Karten). Raster: iOS
    `MediathekRaster`, tvOS `MediathekRasterTV`.
  - **Seit 1.0.14** (Wunsch 11/2026 „wie in der Apple-Galerie"): neueste
    UNTEN als Vorgabe, umstellbar (`@AppStorage("mediathekNeuesteUnten")`,
    iOS Menü ⇅, tvOS Knopf oben); `defaultScrollAnchor(.bottom)` + einmal
    `scrollTo` beim Öffnen/Umstellen — NICHT bei jeder Mediathek-Änderung
    (sonst springt das Raster bei jedem iCloud-Abgleich). Kacheln je Zeile
    per Kneifen (`MagnifyGesture`, 1–15, `@AppStorage("mediathekSpalten")`,
    Vorgabe iPhone 4, iPad 7; Rechnung `MediathekRaster.spalten`, Test
    `RasterSpaltenTests`). Pixel je Kachel folgen der Spaltenzahl;
    `AssetBild` lädt bei geänderter Größe neu.
  - `KachelMarke`: Video mit Länge (und „360° ·"), 360°-Foto „360°",
    normales Foto ohne Marke.
  - Start-Prüfung öffnet zusätzlich ein normales 4 : 3-Foto (`flach`).
- **Galerie-Ersatz** (seit 1.0.15, Wunsch 11/2026: „alle Auswahlelemente aus
  der Apple-Fotogalerie … Ort und Datum verändern … beim Ort an der anderen
  App bedienen"):
  - Startseite wie Fotos: Mediathek (Alle, 360°, Videos, **Orte** =
    `OrteKarte`, MKMapView mit Gruppierung), **Sammlungen**
    (`FotoBibliothek.sammlungen()`: Favoriten, Zuletzt hinzugefügt, Selfies,
    Live Photos, Porträt, Panoramen, Zeitraffer, Slo-Mo, Serien,
    Bildschirmfotos, RAW, Animiert, Langzeitbelichtung — nur mit Inhalt;
    Namen liefert iOS), Meine Alben, **Geteilte Alben**. Nicht möglich, weil
    iOS es fremden Apps nicht gibt: Personen, Erinnerungen, Ausgeblendet,
    Zuletzt gelöscht (steht so im Fuß). tvOS zeigt Sammlungen und geteilte
    Alben als Karten (nur ansehen).
  - Betrachter (iOS) unten wie Fotos: Teilen, Favorit, ⓘ Info, … (Zu Album
    hinzufügen, Ausblenden), Löschen (iOS fragt selbst; „Zuletzt
    gelöscht"). Die Beschreibung aus den Notizen hat jetzt das Symbol
    „text.bubble". Raster: „Auswählen" mit Teilen, Favoriten, Zu Album,
    Ausblenden, Löschen.
  - **Info** (`InfoAnsicht`): Datum/Uhrzeit ändern, Ort festlegen/ändern/
    entfernen (`OrtWahlAnsicht`), Datei, Art, Format, Dauer, Favorit.
    Geschrieben NUR per `PHAssetChangeRequest` (`creationDate`, `location`,
    `isFavorite`, `isHidden`) in `Aenderungen` (Galerie360/Aktionen.swift),
    danach neu lesen und vergleichen — erst dann gilt es als gespeichert.
    `canPerform(.properties)` vorher; gesperrt bei geteilten Alben.
  - **Ort aus PhotoLocator übernommen** (Galerie360/Ort/): `Koordinaten`,
    `OrtsSuche` + `Adressaufloesung`, `KartenAnsicht` (MKMapView, Nadel
    tippen/ziehen, flache Karte), `KartenGedaechtnis` (eigene Schlüssel
    `galerie360.karte.*`) — Kopf jeder Datei sagt das; Fehlerbehebungen in
    BEIDEN Apps nachziehen. Regeln wie dort: Genauigkeit 5 m, Höhe
    unbekannt, Zeitstempel = Aufnahmezeit. `KoordinatenTests` mitkopiert.
  - **Teilen** (`Teilen.swift`): Dateien in `tmp/Teilen-…`, gelöscht, sobald
    das Teilen-Fenster zu ist. Ort und Datum aus der Fotos-Datenbank werden
    hineingeschrieben — Fotos verlustfrei (`CGImageDestinationCopyImageSource`,
    Test `TeilenAngabenTests`), Videos per Passthrough-Export mit ISO-6709-Ort.
- **Ohne Ort** (seit 1.0.24, Wunsch 11/2026: „gezielt Bilder ohne Ortsangabe
  suchen, damit ich den Ort festlegen kann"): Startseite → Fotos-Mediathek →
  „Ohne Ort“ (`MediathekQuelle.ohneOrt`). PhotoKit hat kein Prädikat für den
  Ort — gefiltert wird in `FotoBibliothek.aufnahmen(aus:quelle:)`
  (`location == nil`), Abfrage wie „Alle“. Ort geben: im Raster „Auswählen“ →
  Stecknadel → EIN Ort für alle gewählten (`Aenderungen.ort([PHAsset], _)`,
  ein `performChanges`, danach neu gelesen; nicht änderbare werden gezählt
  und gemeldet), oder einzeln im Betrachter über ⓘ. Während der Betrachter
  offen ist, lädt „Ohne Ort“ NICHT neu (sonst verschwände die Aufnahme unter
  dem Finger und der Betrachter spränge weiter); beim Schließen schon
  (`betrachterZu`). Nur iOS — das Apple TV ändert nichts.
- **Raster flüssig** (seit 1.0.16; gemeldet 11/2026: „Kachelansicht sehr träge
  … beim Scrollen bleibt es stocken"). Drei Ursachen, alle behoben:
  1. `photoLibraryDidChange` erhöhte `stand` bei JEDER Meldung — beim
     iCloud-Abgleich mehrmals je Sekunde —, und jede Ansicht lud alles neu
     (20 000 Aufnahmen, alle Sammlungen gezählt). Jetzt höchstens ein `stand`
     je 0,8 s mit den gesammelten Änderungen (`aenderungen`); das Raster lädt
     nur, wenn `bibliothek.betrifft(ergebnis)` (PHChange.changeDetails) —
     also wenn SEINE Aufnahmen betroffen sind.
  2. Die Startseite darunter zählte bei jedem `stand` alle Sammlungen auf dem
     Hauptthread. Jetzt erst nach 3 s Ruhe, im Hintergrund
     (`…Lesen()`-Funktionen ohne Zustand).
  3. Kacheln nahmen `AssetBild` (höchste Qualität in einem Rückruf, für 360°
     die genaue Umrechnung je Kachel). Jetzt `RasterBild`: Miniatur aus dem
     `PHCachingImageManager`, `.opportunistic` (erst grob, dann scharf),
     Anfrage beim Hinausscrollen abgebrochen; 360° als Bildmitte
     (`scaleEffect(2)` = 90° × 90° geradeaus). `AssetBild` mit der genauen
     Umrechnung bleibt für die großen Vorschauen (Galerie-Alben, Karten).
- **Raster in UIKit** (seit 1.0.17; Nutzer zu 1.0.16: „ein bisschen besser …
  nicht wirklich viel"). Das Mediathek-Raster auf iOS ist jetzt
  `RasterSammlung` (Galerie360/RasterSammlung.swift): `UICollectionView`
  mit wiederverwendeten `KachelZelle`n, Vorladen per
  `UICollectionViewDataSourcePrefetching` + `startCachingImages`, Abbruch in
  `didEndDisplaying`, Kneifen per `UIPinchGestureRecognizer` (Rechnung
  weiter `MediathekRaster.spalten`). Grund: Ein SwiftUI-`LazyVGrid` über
  zehntausende Aufnahmen vergleicht bei jeder Änderung die ganze Liste, und
  jede Kachel trug eigenen Zustand — das bekommt man nicht flüssig. Neu
  geladen wird nur bei `stand`-Wechsel des Rasters (`datenStand`); Auswahl
  und Marken aktualisieren nur die sichtbaren Zellen. Ans Ende springen
  erst, wenn die Kachelgröße feststeht (`endeWartet`). tvOS bleibt beim
  SwiftUI-Raster mit `RasterBild` (Fokus-Engine). **NICHT zurück auf
  LazyVGrid.**
- **Stelle merken** (seit 1.0.18; gemeldet zu 1.0.17: „springt beim Öffnen
  nicht mehr zu den neuesten … lieber die letzte Ansicht speichern"). Der
  Sprung in 1.0.17 kam vor dem fertigen Layout und landete oben. Jetzt:
  `Koordinator.ausstehend` (.neueste / .stelle) wird in
  `RasterAnsicht.layoutSubviews` NACH `super` angewandt, sobald
  Kachelgröße und Inhaltshöhe feststehen. Gemerkt wird je Quelle
  (`MediathekQuelle.positionsSchluessel`, UserDefaults
  `galerie360.raster.<schlüssel>`) die oberste sichtbare Aufnahme — oder
  „NEUESTE", wenn man am Rand mit den neuesten steht (dann sieht man beim
  nächsten Öffnen auch Neues). Gespeichert am Ende jedes Scrollens und beim
  Schließen. Nicht gefunden (gelöscht) → zu den neuesten; Reihenfolge
  umgestellt → zu den neuesten. `.auswahl` (Orte) merkt nichts.
  **Nachtrag 1.0.19** (gemeldet: „springt nicht nach unten … zeigt erst die
  ältesten … lieber dunkel bleiben, bis die aktuellen Bilder erscheinen"):
  `scrollToItem` mitten in `layoutSubviews` ging oft ins Leere. Jetzt
  `zielPlanen` → `versuchen` (bis 40 Takte à 16 ms, bis Kachelgröße und
  `collectionViewContentSize` feststehen) → `anwenden` berechnet den
  Versatz selbst (Ende bzw. `layoutAttributesForItem`) und setzt
  `contentOffset`. Bis dahin `alpha = 0` — beim Öffnen sieht man nichts,
  dann gleich die richtige Stelle. Ablage-Schlüssel neu `galerie360.raster2.`
  (was 1.0.18 gemerkt hatte, konnte wegen des gescheiterten Sprungs „ganz
  oben" sein).
- **Kachelmarken** (seit 1.0.20; gemeldet: „360-Grad-Fotos und -Videos werden in
  der Kachelansicht nicht mehr markiert"). Das UIKit-Raster blendete die
  Marke ab acht Kacheln je Zeile ganz aus (`marken: aktSpalten <= 7`) und
  legte sie von Hand aus. Jetzt `KachelZelle.Etikett` per Auto Layout unten
  links, IMMER gezeigt; bei kleinen Kacheln knapp („360°", „360° ▶︎", „▶︎"),
  sonst mit Länge. Test `KachelMarkeTests` (sichtbar, in der Kachel, über
  dem Bild — für 40, 100 und 300 pt).
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
  geladen: x %" — **seit 1.0.23 nur, wenn eingeschaltet** (Startseite →
  „Einstellungen“ → „Ladeanzeige bei Videos“, `@AppStorage("tvQualitaetsAnzeige")`,
  Vorgabe AUS; gemeldet 11/2026: „scheint nicht wegzugehen … stört … ausblenden
  können"). In der Hilfe (Mitte drücken) steht der Stand immer. Liefert `requestAVAsset` keine Datei (`url.isFileURL`),
  bleibt es bei `.automatic`. Am Gerät NICHT geprüft: ob tvOS das Original
  wirklich vorab ganz lädt und wie lange das dauert.
- **Videotextur selbst geholt** (seit 1.0.23; gemeldet 11/2026: „ruckelt
  manchmal auch voll geladen … bei schon geladenen Videos statt des Videos
  ein weißer Bildschirm, der Ton funktioniert"). Bis 1.0.22 bekam SceneKit
  den AVPlayer als `diffuse.contents` — SceneKit zeichnet ihn über eine
  SpriteKit-Zwischenszene (teuer), und nach `replaceCurrentItem` (Wechsel
  aufs Original; bei schon geladenen Videos sofort) blieb die Textur mitunter
  weiß. Jetzt auf tvOS `VideoTextur` (Gemeinsam/Panorama.swift):
  `AVPlayerItemVideoOutput` (BGRA, je Item eine eigene, folgt `currentItem`
  per KVO) → `CVMetalTextureCache` → `MTLTexture` (`.bgra8Unorm_srgb`, sonst
  blass) als `diffuse.contents`, je Bild im `SCNSceneRendererDelegate`
  (`renderer(_:updateAtTime:)`). iOS bleibt beim AVPlayer als Inhalt.
- **Absicherung beim Original** (`originalLaeuft`): nach dem Wechsel ein
  4-s-Fenster, in dem das Video spielt; kommen weniger als 60 % der Bilder
  (`nominalFrameRate`) auf der Kugel an oder ist das Item `.failed`, zurück
  auf die flüssige Fassung (`.automatic`, gleiche Stelle) und für dieses
  Video in der Sitzung kein Original mehr (`nurFluessig`). Hinweis
  „Flüssige Fassung — das Original lief … nicht sauber“ (in der Hilfe; im Bild
  nur mit eingeschalteter Ladeanzeige). Grund für Ruckeln mit Original
  vermutlich die Dekodierleistung (Insta360-Originale 5,7K/8K) — am Gerät
  NICHT gemessen.
- Job „Apple-TV-Betrachter starten" (Video jetzt 30 s): Die App meldet im
  Prüfmodus nach 6, 12, 18 s `PRUEFUNG: Videobilder n`; rot, wenn die Zahl
  nicht wächst. Im Simulator ist das Original sofort da — genau der Fall
  „schon geladen → weiß“.
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

## Im Web teilen (seit 1.0.21)

Wunsch des Nutzers (11/2026): „360-Grad-Alben von Urlauben … mit anderen
Menschen teilen, die z. T. kein iPhone haben … die iOS-App als Grundlage, die
Webapp möglichst komfortabel synchronisieren". Antworten: Strato, genug
Speicher, „nur mit laaaaangem Link", „Ansehen".

- **Die App ist die EINZIGE Quelle, das Web ihr Spiegel.** Kein Abgleich in
  beide Richtungen (Konflikte). Bearbeitet wird nur in der App; die
  Web-App `galerie360/` bleibt der Betrachter für Gäste (ihr Editor ist für
  diese Galerien nicht nötig).
- Galerie → „…" → „Im Web teilen …" (`Web/WebAnsicht.swift`): einmal
  einrichten (Adresse, Empfangsdatei, Verbindung prüfen), dann
  „Im Web veröffentlichen" / „Aktualisieren", Link + QR-Code, „Aus dem Web
  entfernen".
- **Format = das der Web-App** (`Web/WebFormat.swift`, nachgebaut nach
  `galerie360/js/export.js`): je Galerie und je Album ein Ordner
  `<lesbar>-<26 Zeichen>` direkt unter der Basis (Vorgabe
  `https://jerosch.net/apps/galerie360/360Grad/`), Daten in `index.html`,
  Betrachter in JEDEM Ordner (`assets/`), leere `index.html` in jedem
  Unterordner. Alle Seiten geheim, `noindex`, `no-referrer`,
  `downloads: false`. Ordner für Unteralben = Album ohne Aufnahmen mit
  Karten. Kennungen ohne „/" (`webId`). **Nur 360°-Aufnahmen** (der
  Web-Betrachter zieht alles auf die Kugel); die Zahl der übersprungenen
  steht als Hinweis da.
- **Betrachter-Kopie:** `Web/Betrachter/galerie.js.txt` und `.css.txt` =
  `galerie360/galerie/galerie.js`/`.css` Byte für Byte (als .txt, damit Xcode
  sie als Ressource kopiert und nicht zu kompilieren versucht). Der Job
  „Web-Galerie im Browser" prüft das per `cmp` — **nach jeder Änderung am
  Web-Betrachter dorthin kopieren.**
- **Aufbereitung** (`Web/WebAufbereitung.swift`, Arbeitsordner unter `tmp/`,
  nach dem Hochladen gelöscht): Fotos JPEG 0,9 in voller Größe + 8192 +
  4096 (wie die Web-App), neu gerechnet OHNE Metadaten (kein GPS für
  Gäste). Videos: H.264 3840 × 1920 mit 50 Mbit/s (AVAssetReader/Writer,
  Ton auf Stereo-AAC gemischt) — spielt überall; wahlweise dazu das
  Original per Passthrough (`metadataItemFilter = .forSharing()`).
  Codec-Kennung aus avcC/hvcC wie `medien.js`. Vorschau 800 × 500 aus
  PhotoKits Bild in der Startansicht (`Ausschnitt`), Name mit Zufallsteil —
  bei neuer Startansicht neu, ohne das Original zu laden.
- **Hochladen** (`Web/WebEmpfang.swift`): Empfangsdatei
  `galerie360-empfang.php` (Vorlage `Web/galerie360-empfang-vorlage.txt`)
  einmal per Strato-Dateimanager/FTP in die Basis. Sie kennt nur die
  SHA-256 des Schlüssels (64 Zufallszeichen im Schlüsselbund,
  `WebSchluessel`); schreibt/löscht NUR in Ordnern mit 26 Zufallszeichen,
  nur html/js/css/json/jpg/png/mp4/mov, nie PHP/.htaccess. Teil-Upload mit
  Versatz (Stück = halbe `post_max_size`, höchstens 8 MB), Größenprüfung am
  Ende. Geprüft mit `scripts/test-empfang.sh` (24 Fälle, `php -S`).
- **Nur Änderungen** (`Web/WebVeroeffentlichung.swift`, `WebStand` in
  Application Support): je Galerie die Ordnernamen (Link bleibt gleich)
  und je Aufnahme `fassung` (Änderungsdatum + Videowahl), Dateien,
  Vorschau. Vor dem Lauf `liste` vom Server: Fehlt eine Datei, wird die
  Aufnahme neu gemacht. Nach jeder Aufnahme gespeichert (Abbruch verliert
  nichts). Seiten immer neu; am Ende alles löschen, was nicht mehr
  gebraucht wird (auch ganze Albumordner). `WebStand` liegt nur auf DIESEM
  Gerät — vom zweiten Gerät aus entstünde eine neue Web-Galerie.
- Tests: `WebFormatTests` (Ordnernamen, Codec-Kennungen, Adresse, Bündel,
  Seiten) schreibt zusätzlich eine Beispiel-Galerie; der Linux-Job „Web-
  Galerie im Browser" öffnet sie mit `scripts/web-probe.js` in Chromium
  (Rechner + Handy: Karten, Vorschauen, Albumseite, Foto im Betrachter,
  Unteralbum, Sonderzeichen, keine Skriptfehler). Echte Videos und Strato
  selbst prüft CI NICHT.

## Home-Bildschirm-Symbole der Web-Galerie (seit 1.0.22)

Wunsch des Nutzers (11/2026): Ein Gast wollte die Galerie „auf dem
Homescreen ablegen, als Web-App … damit sie nicht unter den Lesezeichen im
Nirvana verschwindet" — „für jedes Album bzw. für jede Galerie ein
passendes Icon".

- Jede Seite (Galerie und jedes Album, auch Ordner) bekommt beim
  Veröffentlichen eigene Symbole `icons/symbol-<6 Zufallszeichen>-180/192/512.png`
  und eine `manifest.json` (NICHT `.webmanifest` — die Empfangsdatei nimmt nur
  html/js/css/json/jpg/png/mp4/mov). `index.html` verweist darauf
  (`apple-touch-icon` 180, `manifest`, `apple-mobile-web-app-capable`,
  `-title` = Titel der Seite). `WebFormat.homeBildschirm`, `.manifest`.
- Manifest: `display: standalone`, `start_url`/`id` `./`, **`scope: ../`**
  (= die Basis mit allen Ordnern der Galerie) — sonst öffnete ein Antippen
  einer Albumkarte in der Home-Bildschirm-App ein Browserfenster.
- Bild: Titelbild der Seite in seiner Startansicht, quadratisch 512 × 512
  (`WebAufbereitung.symbolBild`, dieselbe Rechnung wie die Vorschau), unten
  mittig eine kleine „360°“-Marke, undurchsichtig (iOS rundet selbst).
  Titelbild: Albumbild aus den Notizen, sonst erste 360°-Aufnahme; Ordner →
  das des ersten Unteralbums; Galerie → Galeriebild, sonst das des ersten
  Albums.
- Neu gezeichnet nur, wenn sich Aufnahme, ihr Änderungsdatum oder die
  Startansicht ändern (`WebStand.Galerie.symbole`, optional — alte Stände
  laden weiter). Neuer Name mit Zufallsteil, damit kein Browser ein altes
  Symbol zeigt; das alte räumt der Abgleich weg. Lässt sich das Bild nicht
  laden, bleibt das alte Symbol (kein Abbruch).
- Was schon auf einem Home-Bildschirm liegt, ändert sich NICHT von selbst —
  iOS übernimmt Symbol und Namen nur beim Hinzufügen.
- Tests: `testHomeBildschirm`, `testSymbolDateien`; `web-probe.js` prüft
  Verweise, Manifest (Start, Bereich) und dass die Symbole als PNG laden.

## Noch nicht in der App

Hotspots, Übernahme einer Web-Galerie (Sicherung) in Fotos-Alben.

## Tests

`Galerie360Tests/` (XCTest, App als Host): `PanoramaTests`, `NotizenTests`,
`SortierungTests`, `AusschnittTests`, `KoordinatenTests`, `TeilenAngabenTests`, `WebFormatTests`. PhotoKit selbst ist im Simulator ohne Berechtigung nicht
prüfbar. Läuft in `.github/workflows/galerie360app-test.yml` bei jedem Push
unter `Galerie360iOS/`; der Bau zusätzlich in `ios-apps-build.yml`.
