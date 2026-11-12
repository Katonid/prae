# Projekt Kapitelweise – Das Buch (Ordner/Ziel „Chronik", Fotobuch mit Kapiteln nach der Zeit, native iOS-App)

> Die übergreifenden Regeln (PR-Rhythmus, iOS-Pflichten, Bau in GitHub
> Actions) stehen in der `CLAUDE.md` im Wurzelverzeichnis und gelten hier
> genauso.

- **Anlass** (Ansage des Nutzers, 11/2026): „eine Mischung aus der
  Urlaubstagebuch- und der Urlaubsfotobuch-App: ein Fotobuch, das anhand von
  Bildern und Texten automatisch Kapitel erstellt und die Inhalte darauf
  verteilt. Das Zeitraster möchte ich frei einstellen können, die
  Grundeinstellung soll jedoch Kalenderjahre sein. Texte in der App erstellen
  (mit einstellbarem Zeitstempel) und sprachlich überarbeiten lassen. Fotos
  laden. Freie Seiten an beliebiger Stelle einfügen und frei mit Text, Foto,
  PDF-Datei belegen."
- App-Code: `ChronikiOS/` (ein Target, iPhone + iPad, iOS 17, keine fremden
  Abhängigkeiten, kein iCloud). Bundle-Id `de.familie.chronik`.
- **Name: „Kapitelweise – Das Buch"** (Ansage des Nutzers, 11/2026, ab
  1.0.1; vorher Arbeitsname „Chronik"). Das ist der **Store-Name** (23
  Zeichen, Grenze 30) und der Name im Titel der Bücherliste und im PDF.
  **Homescreen-Name ist „Kapitelweise"** (`CFBundleDisplayName`): Unter einem
  Symbol stehen nur gut zwölf Zeichen, der volle Name würde zu
  „Kapitelweise – D…" abgeschnitten. Store-Name und Anzeigename sind getrennte
  Felder; den App-Eintrag von Hand in App Store Connect anlegen, nie über
  Xcodes „Create App Record" (Lehre aus Anstoß). **Ordner `ChronikiOS/`,
  Ziel/Schema „Chronik" und Bundle-Id `de.familie.chronik` bleiben** — sie
  sieht niemand, und die Bundle-Id ist nach dem ersten Signieren ohnehin
  nicht mehr änderbar.
- **Versionierung:** `MARKETING_VERSION` und `CURRENT_PROJECT_VERSION` je
  zweimal im pbxproj (Debug + Release), keine Skript-Bauphase. Jede
  Arbeitseinheit hebt Patch- UND Build-Nummer um je +1. Start: 1.0.0 (Build 1), dann 1.0.1 (Build 2), 1.0.2 (Build 3).
  `DEVELOPMENT_TEAM = F4989GSTWS`, `ITSAppUsesNonExemptEncryption = NO` in
  `Config/Info.plist` UND als Build-Einstellung — nicht entfernen.
- **Berechtigungstexte nur als Build-Einstellung**
  (`INFOPLIST_KEY_NSPhotoLibraryUsageDescription`), nie in der Info.plist —
  Lehre aus Fernweh 1.0.2 (Xcode stürzt beim Öffnen des Reiters „General" ab).

## Aufbau

- `Model/Buch.swift` — Datenmodell (Codable, eine JSON-Datei
  `Buecher.json` unter Application Support; Fotos/PDFs als Kopien in
  `Dokumente/Medien`). **Neue Felder nur mit Vorgabe anhängen** und in
  `init(from:)` mit `c.wert(.feld, vorgabe)` lesen.
- `Model/Zeitraster.swift` — Kapitel aus Zeitstempeln. Ein Raster ist
  Einheit × Anzahl ab einem Beginn; Kapitel k beginnt bei
  `beginn + k·anzahl·einheit`, für jedes ganze k. Vorgaben: Kalenderjahr
  (Grundeinstellung), Schuljahr (1. August), Halbjahr, Quartal, Monat, Woche,
  eigenes Raster. **Gerechnet wird mit dem Kalender, nie mit Sekunden**, und
  jeder Kapitelbeginn vom Beginn aus (nicht vom Vorgänger) — sonst wandert ein
  Raster ab dem 31. Januar dauerhaft auf den 28. Eigene Kapitelüberschriften
  hängen am Datum des Kapitelbeginns (`schluessel`), bleiben also beim
  Wechsel des Rasters nur, wo das Kapitel gleich beginnt.
- `Model/Seitenbau.swift` — der Layoutautomat: Titelseite, je Kapitel eine
  Kapitelseite und die Inhalte nach der Zeit. Ein Text nimmt bis zu zwei
  unmittelbar folgende Fotos auf seine erste Seite und läuft bei Bedarf auf
  Folgeseiten weiter; weitere Fotos füllen Seiten bis „Fotos je Seite".
- **Freie Seiten hängen an einer `Einfuegestelle`, nicht an einer
  Seitenzahl**: hinter einem Inhalt (`nachInhalt`), am Kapitelanfang, am
  Buchanfang oder -ende. Seitenzahlen verschieben sich bei jedem neuen Foto,
  der Inhalt dahinter nicht. Eine Seite hinter einem mehrseitigen Text steht
  hinter dessen LETZTER Seite. Verschwindet der Anker (Inhalt gelöscht,
  Kapitel weg), rückt die freie Seite ans Buchende — sie verschwindet nie
  still. Mehrere freie Seiten an derselben Stelle stehen in der Reihenfolge
  der Liste `freieSeiten`.
- **GESTALTUNG MIT WOW STATT FORMULAR** (ab 1.0.2; Befund des Nutzers 11/2026
  mit Bildschirmfoto zu 1.0.1: „diese nüchterne Aufteilung ist meilenweit von
  einem Wow-Effekt entfernt. Da waren wir in den anderen Apps doch schon
  weiter."). Jede Fotoseite war ein 2×2-Raster, jedes Bild auf dieselbe
  Kachel beschnitten, die Kapitelseite eine Jahreszahl auf leerem Papier.
  Dieselbe Lehre wie Reisebuch 1.0.35/1.0.36 — **nie wieder zurückbauen**:
  - `Model/Buchstil.swift`: drei Stile, Vorgabe **Modern** (auch für
    bestehende Bücher). Modern: Titel und Kapitel als ganzseitiges Foto mit
    großer Didot darauf (Größe passend zur Breite), Aufmacher randlos,
    Text-Erstseite mit Fotoband bis an drei Kanten, Fuge 4 pt, Datum in
    gesperrten Versalien, Versal-Einstieg. Album: Cremepapier, Abzüge mit
    weißem Rand, gedreht (±2,4°), Schatten, Handschrift (Noteworthy).
    Klassisch: Satzspiegel, Georgia. Umschalter im Reiter „Buch" oben und in
    „Buch einrichten".
  - `Model/Fotolage.swift`: **Blocksatz nach Seitenverhältnis** — alle
    Aufteilungen in Reihen durchprobiert, die der Fläche nächste gewinnt;
    höchstens etwa 20 % beschnitten, sonst verkleinert. Kein festes Raster.
  - Rhythmus im Seitenbau: Seitengrößen im Wechsel 3, 1, 4, 2, 5, 3, 1, 4
    (begrenzt durch „Fotos je Seite"; klassisch gleichmäßig), eine Seite mit
    einem Foto ist ein Aufmacher, jede zweite volle Seite „groß und klein".
    Fotos eines TAGES bleiben auf ihren Seiten unter sich (Tage mit einem
    Foto werden zusammengelegt).
  - Jedes Kapitel öffnet mit seinem ersten Querformat (sonst erstem Foto);
    das Bild steht dann nicht noch einmal auf einer Inhaltsseite. Die
    Titelseite nimmt das gewählte Titelbild, sonst das erste Querformat.
  - Drehwinkel und Abwechslung aus `Fotolage.zahl(id)` (UUID-Bytes), nie aus
    `hashValue` oder dem Zufall — Vorschau und PDF müssen gleich sein.
- `Dienste/Textsatz.swift` — **gemessen und gezeichnet wird über TextKit**
  (`NSLayoutManager` / `NSAttributedString.draw`). Keine zweite
  Satzmaschine dazunehmen (SwiftUI-`Text`, CoreText) — sonst passt ein Stück
  beim Messen und läuft beim Zeichnen aus dem Feld (Lehre aus dem Reisebuch).
- `Dienste/Seitenzeichner.swift` — **Vorschau und PDF zeichnet DERSELBE
  Zeichner.** Die Vorschau ist ein Bild aus genau diesen Funktionen. Neue
  Seitenarten werden dort gezeichnet und nirgends sonst.
- `Dienste/Medien.swift` — Ablage. Geladen werden DATEN, nie ein `UIImage`
  (sonst ist das EXIF-Datum weg); Bilder verkleinert über
  `CGImageSourceCreateThumbnailAtIndex` mit `…WithTransform` (sonst liegt
  jedes Hochformat quer). Das EXIF-Datum wird aus den Ziffern gelesen (keine
  Zeitzone, Uhr am Aufnahmeort). PDF-Seiten werden als VEKTOR gezeichnet
  (`CGPDFPage.getDrawingTransform` — das verkleinert nur, darum erst auf
  Zielgröße skalieren). Aufräumen löscht nur Dateien, auf die kein Buch
  zeigt und die älter als eine Stunde sind, und **unterbleibt, wenn die
  Bücherdatei nicht lesbar war** (sonst wären nach einem Lesefehler alle Fotos
  weg). Eine unlesbare `Buecher.json` wird vor allem anderen beiseitegelegt.
- `Dienste/Fotoeinfuhr.swift` — Fotowähler von UIKit
  (`PHPickerConfiguration(photoLibrary: .shared())`, Lehre aus dem
  Reisebuch); Datum: EXIF → Mediathek (nur mit Zugriff) → Dateidatum → jetzt.
  Der Wähler schließt sich nicht selbst, sondern über den SwiftUI-Zustand.
- `Dienste/Sprachhilfe.swift` — sprachliche Überarbeitung, vier Arten
  (korrigieren, glätten, lebendiger, kürzen). Weg 1: Apple Intelligence auf
  dem Gerät (`FoundationModels`, ab iOS 26, hinter `#if canImport` und
  `#available`); lange Texte absatzweise in Stücken von ≤ 1800 Zeichen, je
  eine frische Sitzung (kleines Kontextfenster). Weg 2: Auftrag in die
  Zwischenablage → KI-Chat → Antwort zurück einsetzen. Immer erst Vorschlag,
  dann „Übernehmen"; die alte Fassung bleibt als `vorfassung` und lässt sich
  zurückholen.
- `Dienste/Buchausgabe.swift` — PDF im Seitenformat, Fotos auf 300 dpi,
  JPEG-verpackt (sonst landen Rohdaten im PDF). Kein Beschnitt, keine
  Doppelseiten — für Fotobuchdienste mit eigenen Maßen ist das Reisebuch da.

## Stand

- **1.0.0 (Build 1)**, 11/2026: erste Fassung. Unter Linux geprüft: Syntax
  aller Dateien (`swiftc -parse`) und die Logik von Zeitraster, Datenmodell
  (Speichern/Laden, alte Datei ohne Felder), Stückelung für die
  Überarbeitung. CI-Bau grün. **Nicht gemessen:** auf keinem Gerät gesehen.
- **1.0.1 (Build 2)**, 11/2026: umbenannt in „Kapitelweise – Das Buch"
  (Homescreen „Kapitelweise").
- **1.0.2 (Build 3)**, 11/2026: Gestaltung neu (Stile, Blocksatz, Rhythmus,
  Kapitel- und Titelfoto). Blocksatz unter Linux nachgerechnet. **Nicht
  gemessen:** wie die Seiten auf dem Gerät aussehen.
