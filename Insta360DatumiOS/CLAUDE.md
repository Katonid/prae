# Projekt Insta360Datum (Aufnahmedatum von Insta360-Videos in Fotos korrigieren)

> Die übergreifenden Regeln (PR-Rhythmus, iOS-Pflichten, Bau in GitHub
> Actions) stehen in der `CLAUDE.md` im Wurzelverzeichnis und gelten hier
> genauso.

- App-Code: `Insta360DatumiOS/Insta360Datum/Insta360DatumApp.swift` —
  **bewusst eine einzige Swift-Datei** (Ansage des Nutzers, 10/2026; er
  hat sie selbst geschrieben). Keine weiteren Dateien in die App legen,
  keine Pakete. Ein Target plus Testziel, iPhone + iPad, iOS 17, SwiftUI,
  Swift 5. Bundle-Id `de.familie.insta360datum` — nach dem ersten
  Signieren nicht mehr ändern.
- **Versionierung:** Patch + Build je +1 bei jeder neuen Fassung
  (`MARKETING_VERSION` und `CURRENT_PROJECT_VERSION`, Debug und Release,
  in App- UND Testziel). Erste Fassung: 1.0.0 (1).
- Team `F4989GSTWS`, `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO`
  als Build-Einstellung, zusätzlich in `Config/Info.plist`.
  `NSPhotoLibraryUsageDescription` als Build-Einstellung. Keine
  Entitlements, kein Mac Catalyst.

## Worum es geht

- Die Insta360 X4 Air exportiert über die Insta360-App Videos als
  `temp_video_<Zahl>.MP4` in die Mediathek; Fotos setzt als Datum den
  Exportzeitpunkt. Die echte Aufnahmezeit steht im MP4-Kommentar
  (`©cmt` in `moov/udta/meta/ilst`), z. B. `2026-10-28 12:38:37 +0000`.
- **Das „+0000“ ist falsch — es ist die Ortszeit der Kamera.** Am echten
  Video geprüft (12:38 Uhr deutscher Zeit). `Leser.datum(aus:)` liest
  darum nur Datum und Uhrzeit und legt die Gerätezeitzone an. Der
  Parameter `zeitzone:` ist nur für die Tests da.
- **Grenzen (Ansage des Nutzers):** Videos werden weder neu codiert noch
  kopiert noch verändert — nur `PHAssetChangeRequest.creationDate`.
  **Keine Fotos** bearbeiten: Insta360-Fotoexporte haben keine
  Aufnahmezeit (geprüft). Oberfläche Deutsch.
- Bereits korrigierte Videos: `UserDefaults` `erledigteAssets`
  (localIdentifier).

## moov-Leser

- `Leser.moovLesen` geht die Blöcke der obersten Ebene durch und liest nur
  `moov` (höchstens 64 MB, nie über das Dateiende). Kaputte Längen
  (kleiner als der Kopf, länger als die Datei, 64-Bit-Länge ohne Platz)
  liefern `nil` — in der Vorlage führten sie zu einem Unterlauf-Absturz.

## Tests

- `Insta360DatumTests/LeserTests.swift` (XCTest, mit App als Host).
  Pflichtfall: `"2026-10-28 12:38:37 +0000"` → 28.10.2026 12:38:37
  Europe/Berlin (= 11:38:37 UTC), **nicht 13:38**.
- Läuft in `.github/workflows/insta360datum-test.yml` bei jedem Push unter
  `Insta360DatumiOS/`. Der Bau steht zusätzlich in `ios-apps-build.yml`.
