# Projekt Posterdruck (Poster-PDF für die Druckerei, native iOS-App)

> Die übergreifenden Regeln (PR-Rhythmus, iOS-Pflichten, Bau in GitHub
> Actions) stehen in der `CLAUDE.md` im Wurzelverzeichnis und gelten hier
> genauso.

- App-Code: `PosterdruckiOS/` (ein Target, iPad + iPhone, iOS 17, SwiftUI,
  keine Fremdbibliotheken). Bundle-Id `de.familie.posterdruck` — nach dem
  ersten Signieren nicht mehr ändern.
- Zweck (Ansage des Nutzers, 11/2026): Bilder laden und daraus eine
  PDF mit Seiten in frei wählbarer Größe für einen Posterdruck in der
  Druckerei erstellen. Beispiel des Nutzers: DIN A2 mit 3 mm Beschnitt,
  hochkant 426 × 600 mm. **Der Beschnitt wird als gestrichelte Linie
  angezeigt** (rot gestrichelte Schnittkante; Sicherheitsabstand, falls
  eingestellt, blau gestrichelt). Anleihen bei Kalenderstudio
  (Seitengeometrie in Punkt, Boxen in der PDF, Schnittmarken).
- **Versionierung:** Patch + Build je +1 bei jeder neuen Fassung
  (`MARKETING_VERSION` und `CURRENT_PROJECT_VERSION`, Debug und Release).
  Erste Fassung: 1.0.0 (1). 1.0.1 (2): weitere Bilder hinzufügen ging nicht
  (Plus reagierte nicht, siehe Fallen).
- Team `F4989GSTWS`, `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO`
  als Build-Einstellung, zusätzlich in `Config/Info.plist`. `Config/`
  liegt absichtlich außerhalb des synchronisierten Ordners. Keine
  Entitlements (kein iCloud) — Fotos kommen über `PhotosPicker`, der keine
  Berechtigung braucht.

## Aufbau

- `Model/Poster.swift` — `PosterProject` (Auftrag: Name, Format, Bilder),
  `PosterFormat` (kurze/lange Seite des **Endformats**, Beschnitt,
  Sicherheitsabstand, Ausrichtung hoch/quer/„wie das Bild“, Vorlagen),
  `PosterItem` (ein Bild = ein Poster = eine Seite: Füllen/ganzes Bild,
  Zoom, Verschiebung −1…1, Vierteldrehungen, Hintergrundfarbe). Alles mit
  robustem `init(from:)`.
- `Model/PhotoStore.swift` — Bilder in `Documents/Fotos/<UUID>.jpg`.
  **JPEG wird Byte für Byte übernommen**, alles andere (HEIC, PNG) einmal
  in JPEG 0,95 in voller Auflösung umgewandelt — ein HEIC läge in der PDF
  sonst entpackt (48 MP ≈ 140 MB). Gespeicherte Pixelmaße sind die
  aufrechten (EXIF 5–8 vertauscht). Vorschau 1600 px im `NSCache`.
- `Model/ProjectStore.swift` — `Documents/auftraege.json`, verzögert
  gespeichert. Neue Aufträge übernehmen das Format des zuletzt angelegten.
- `Render/Layout.swift` — `PageGeometry` (Datenformat = Endformat + 2 ×
  Beschnitt, in Punkt, Ursprung oben links) und `PosterLayout.imageRect`:
  Füllen deckt die ganze Seite **samt Beschnitt**, „Ganzes Bild“ liegt
  im Endformat. Vorschau und PDF rechnen mit DERSELBEN Funktion.
  Wirksame Auflösung = Bildpixel / (Bildbreite in Zoll); ab 150 dpi grün,
  ab 100 orange, darunter rot.
- `Render/PDFExporter.swift` — PDF direkt mit CoreGraphics (kein
  `ImageRenderer`): Bild als `CGImage` aus der Datei, EXIF-Drehung 3/6/8
  per Transformation (dann bleibt das JPEG unverändert in der PDF),
  gespiegelte Drehungen (2/4/5/7) werden neu gerechnet. MediaBox,
  BleedBox, TrimBox je Seite; wahlweise Schnittmarken (vergrößern die
  MediaBox). Eine PDF für alle oder eine je Poster. Bei „wie das Bild“
  können Seiten einer PDF verschieden liegen. Läuft in `Task.detached`.
- `Views/` — Startseite (Aufträge), Editor (Raster aller Poster mit
  dpi-Schild, Bilder aus Fotos oder Dateien), Format (Vorlagen, Eingabe
  als Endformat ODER Datenformat, Skizze), Poster bearbeiten (ziehen,
  zwei Finger zoomen, drehen, Hintergrund, Blättern), Export.

## Fallen

- **Die gestrichelte Linie ist nur Vorschau** — sie kommt nie in die
  Druckdatei.
- Ausrichtung: `PosterFormat.trimMM` sortiert kurze/lange Seite selbst;
  die Felder im Formatblatt schreiben Breite/Höhe je nach Ausrichtung in
  `shortMM`/`longMM`.
- Schriften mit `fixedSize` sind hier nicht nötig — die Seite enthält
  keinen Text.
- **Kein `PhotosPicker` in einem `Menu` der Symbolleiste** (Befund des
  Nutzers zu 1.0.0: „nachdem eine Datei erstellt wurde, lassen sich keine
  weiteren Bilder zufügen, das Plus zeigt keine Reaktion“). Seit 1.0.1:
  Plus = gewöhnlicher Knopf → Auswahldialog → `.photosPicker(isPresented:)`
  bzw. `.fileImporter`, mit 0,4 s Abstand (zwei Darstellungen kurz
  nacheinander verschluckt iOS). Zusätzlich steht am Ende des Rasters immer
  eine Kachel „Weitere Bilder“ (Aus Fotos / Aus Dateien) — der Weg geht
  also auch ohne die Symbolleiste.
