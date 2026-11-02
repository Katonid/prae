# Projekt PhotoLocator (Fotostandorte ergänzen und bearbeiten)

> Die übergreifenden Regeln (PR-Rhythmus, iOS-Pflichten, Bau in GitHub
> Actions) stehen in der `CLAUDE.md` im Wurzelverzeichnis und gelten hier
> genauso.

- Ein App-Target plus Testziel, iPhone + iPad, iOS 17, SwiftUI (+ ein
  `MKMapView` per `UIViewRepresentable`), Swift 5. Keine Pakete, keine
  externen Dienste. Bundle-Id `de.familie.photolocator` — nach dem ersten
  Signieren nicht mehr ändern. Oberfläche vollständig Deutsch.
- **Versionierung:** Patch + Build je +1 bei jeder neuen Fassung
  (`MARKETING_VERSION` und `CURRENT_PROJECT_VERSION`, Debug und Release,
  in App- UND Testziel). Erste Fassung: 1.0.0 (1).
- Team `F4989GSTWS`, `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO`
  als Build-Einstellung, zusätzlich in `Config/Info.plist`.
  `NSPhotoLibraryUsageDescription` als Build-Einstellung;
  `PHPhotoLibraryPreventAutomaticLimitedAccessAlert` in `Config/Info.plist`.
  Keine Entitlements, kein Mac Catalyst.
- Ordner unter `PhotoLocator/` sind ein synchronisierter Ordner — neue
  Swift-Dateien werden ohne pbxproj-Eintrag übernommen.

## Aufbau

| Ordner | Inhalt |
|---|---|
| `Mediathek/` | Berechtigung + Änderungsbeobachter (`MediathekZugriff`), Laden/Filtern (`FotoSuche`, `Zeitraum`, `Schnellwahl`, `Standortfilter`), Miniaturen/Vorschau (`Bildlader`) |
| `Standort/` | Schreiben + Nachlesen (`StandortSpeicher`), `GespeicherterOrt`, `Nachbarsuche`, `Koordinaten` (Parser/Darstellung, rein, getestet) |
| `Karte/` | `KartenAnsicht` (MKMapView), `KartenSteuerung`, `KartenGedaechtnis`, `OrtsSuche`, `Adressaufloesung` |
| `Fortschritt/` | `Sitzungsspeicher` (JSON in Application Support), `Fortschritt` (rein, getestet), `Formate` |
| `Modelle/` | `Arbeitsliste`, `ErgaenzenModell` (Modus A), `BearbeitenModell` (Modus B), `BearbeitungsModell` (Editor) |
| `Ansichten/` | SwiftUI-Oberfläche |

## Unverrückbare Regeln

- **Gespeichert wird nur über `PHAssetChangeRequest.location`.** Keine
  `PHContentEditingOutput`, kein Neuschreiben der Datei, keine Kopie — das
  würde neu codieren bzw. eine bearbeitete Fassung anlegen.
- **Ein Foto gilt erst als erledigt, wenn `StandortSpeicher.schreiben`
  das Foto neu gelesen und die Koordinate verglichen hat** (Toleranz
  `Koordinaten.toleranz`). Fehlschlag → Fehlermeldung, nichts markiert.
- Vor dem Schreiben `canPerform(.properties)` prüfen; gesperrte Fotos
  (geteilte Alben, vom Computer synchronisiert) klar melden.
- Rückgängig braucht den **vollständigen** vorherigen Ort
  (`GespeicherterOrt`: Höhe, Genauigkeit, Zeitstempel) — und „vorher kein
  Ort“ muss als `nil` erhalten bleiben.
- Eine von Hand gesetzte Nadel hat Genauigkeit 5 m (nie negativ = „ungültig“),
  Höhe unbekannt (`verticalAccuracy` -1), Zeitstempel = Aufnahmezeit.
- Karte flach (`MKStandardMapConfiguration()` ohne Relief) — sonst trifft
  ein Tipp im Gebirge nicht exakt die Koordinate darunter.
- Der Kartenausschnitt wird nie durch SwiftUI-Zustand gesteuert, sondern
  über `KartenSteuerung` — sonst springt er beim Blättern zurück.

## Grenzen von iOS (bewusst so)

- Der Ort steht in der Fotos-Datenbank, nicht in den EXIF-Daten der
  Originaldatei. Die Fotos-App zeigt ihn an, iCloud gleicht ihn ab, und
  beim Teilen/Exportieren schreibt Fotos ihn in die Kopie. Das ist der
  einzige Weg ohne Neucodierung und ohne zweite Fassung.
- Für das Speichern muss das Original NICHT aus iCloud geladen werden;
  geladen wird nur eine Vorschau.
- PhotoKit kann nicht nach Standort filtern; `FotoSuche` prüft jedes Foto
  im Zeitraum selbst (außerhalb des Hauptthreads).

## Tests

- `PhotoLocatorTests/` (XCTest, App als Host): Koordinatenparser,
  Fortschrittslogik, Tagesabschnitte, Zeitraum, Sitzung übersteht
  Neustart, `GespeicherterOrt`.
- Läuft in `.github/workflows/photolocator-test.yml` bei jedem Push unter
  `PhotoLocatoriOS/`. Der Bau steht zusätzlich in `ios-apps-build.yml`.
- Anleitung für den Nutzer (Installieren, Abnahmetests): `README.md`.
