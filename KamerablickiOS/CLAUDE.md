# Projekt Kamerablick (RTSP-IP-Kameras ansehen, native iOS-App)

> Die übergreifenden Regeln (PR-Rhythmus, iOS-Pflichten, Bau in GitHub
> Actions) stehen in der `CLAUDE.md` im Wurzelverzeichnis und gelten hier
> genauso.

- App-Code: `KamerablickiOS/` (ein Target, iPhone + iPad, iOS 17,
  SwiftUI). Bundle-Id `de.familie.kamerablick` — nach dem ersten Signieren
  nicht mehr ändern.
- Zweck (Ansage des Nutzers, 10/2026): Ersatz für eine Kamera-App, die
  35 € im Jahr kostet. Mehrere IP-Kameras (Tapo u. a.) per RTSP ansehen,
  **Bild bildschirmfüllend**, **Handy bleibt wach**, Bild **waagerecht und
  senkrecht spiegeln**. Ausgangspunkt war ein ZIP („Kamerablick“, mit
  XcodeGen), das der Nutzer in einem Chat hatte erzeugen lassen; daraus
  wurde ein echtes Xcode-Projekt nach Repo-Muster.
- **Versionierung:** Patch + Build je +1 bei jeder neuen Fassung
  (`MARKETING_VERSION` und `CURRENT_PROJECT_VERSION`, Debug und Release).
  Erste Fassung: 1.0.0 (1).
- Team `F4989GSTWS`, `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO`
  als Build-Einstellung, zusätzlich `ITSAppUsesNonExemptEncryption` in
  `Config/Info.plist`. Keine Entitlements.

## Wiedergabe: VLCKit

- iOS spielt RTSP nicht selbst ab (AVPlayer kann nur HLS/Dateien). Darum
  **MobileVLCKit** über das Swift-Paket `https://github.com/koombea/vlckit-spm`
  (Produkt `VLCKitSPM`, ab 3.6.0, Stand in
  `project.xcworkspace/xcshareddata/swiftpm/Package.resolved`). Der Nutzer
  hat der Fremdbibliothek zugestimmt (LGPL 2.1). Das einzige Paket im
  ganzen Repo — der erste Bau lädt einige hundert MB.
- **Kein Mac Catalyst:** Das Paket bringt für Catalyst kein Framework mit
  (`VLCKit.swift` importiert dort nichts). `SUPPORTS_MACCATALYST` nicht
  einschalten.
- `StreamPlayer.stop()` ruft VLCs `stop()` im Hintergrund — es blockiert
  bei hängenden Strömen den Hauptfaden. Nach Abriss neuer Versuch alle 5 s.
- `p.audio` wird mit `as VLCAudio?` angesprochen, damit es unabhängig
  davon übersetzt, ob die Eigenschaft im Header optional ist.
- **Füllen:** VLC passt das Bild mit Balken ein; `PlayerView.baseScale`
  rechnet aus `videoSize` die Vergrößerung, bei der die Balken
  verschwinden. Pinch-Zoom wirkt zusätzlich darauf.
- Rückkehr in den Vordergrund verbindet nur neu, wenn der Player zuvor
  gestoppt wurde (`status == .idle`) — sonst riss schon das Aufziehen des
  Kontrollzentrums die Verbindung ab.

## Daten

- Kameras als JSON in `UserDefaults` (`cameras.v1`), **Passwörter im
  Schlüsselbund** (`de.familie.kamerablick.camera`, je Kamera-UUID).
  `Camera.init(from:)` liest jedes Feld mit Vorgabe — neue Felder immer
  dort mit `decodeIfPresent` ergänzen.
- Vorschaubilder: VLC-Schnappschuss 1,5 s nach dem ersten Bild,
  `Caches/Thumbnails/<UUID>.png`.
- `NSLocalNetworkUsageDescription` ist Pflicht — ohne die Freigabe
  „Lokales Netzwerk“ erreicht die App keine Kamera.
