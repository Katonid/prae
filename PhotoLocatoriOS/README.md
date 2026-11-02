# PhotoLocator

Ergänzt und korrigiert die GPS-Standorte deiner Fotos — direkt in der
Apple-Fotomediathek, ohne Kopien, ohne Konto, ohne Cloud-Dienst.

## Öffnen und auf das iPhone bringen

1. Am Mac das Repository holen (oder nach dem Merge `main` aktualisieren)
   und `PhotoLocatoriOS/PhotoLocator.xcodeproj` in Xcode öffnen.
2. Oben das Schema **PhotoLocator** und dein iPhone als Ziel wählen
   (iPhone per Kabel oder im selben WLAN; beim ersten Mal am iPhone
   „Entwicklermodus“ einschalten: Einstellungen › Datenschutz & Sicherheit).
3. Das Team `F4989GSTWS` ist bereits eingetragen, Signieren läuft
   automatisch. **Run** (▶) drücken.
4. Für TestFlight: *Product › Archive* → *Distribute App* → *App Store
   Connect*. Die Export-Compliance-Frage entfällt (keine eigene
   Verschlüsselung angegeben).

Voraussetzung: iOS 17 oder neuer.

## Erster Start

Die App erklärt, wozu sie den Fotozugriff braucht, und fragt danach.
Wähle **„Vollen Zugriff erlauben“**. Mit „Zugriff beschränken“ sieht sie
nur die ausgewählten Fotos und sagt das auf dem Startbildschirm
(„Auswahl ändern“ / „Vollen Zugriff erlauben“).

## Bedienung in Kürze

- **Fehlende Standorte ergänzen:** Zeitraum wählen (Schnellauswahl oder
  Von/Bis) → „Fotos ohne Standort suchen“ → Übersicht mit Zahlen
  (untersucht / ohne Standort / noch offen) → „Bearbeiten“.
- **Standorte bearbeiten:** alle Fotos, Filter *Alle / Mit Ort / Ohne Ort /
  Bearbeitet* und Zeitraum; Pfeil oben dreht die Sortierung.
- **Bearbeitung:** Foto oben, Karte unten. Die graue Leiste dazwischen
  ziehen (Doppeltipp: Foto groß ↔ Karte groß).
  - Auf die Karte **tippen** setzt die Nadel genau dort.
  - Nadel **gedrückt halten und ziehen** verschiebt sie.
  - Suchfeld: Orte, Adressen, Hotels, Sehenswürdigkeiten oder Koordinaten
    (`47.6302, 13.0045`, `47°37'48.7"N 13°0'16.2"E` …).
  - Knöpfe unter den Koordinaten: *Letzten Standort übernehmen*,
    *Nachbarfoto · 12 Min. früher* (Ort einer Aufnahme kurz davor/danach),
    *Zurücksetzen*.
  - Kartentyp (Karte / Satellit / Satellit mit Straßen) und
    „Nadel in die Kartenmitte“ über die Knöpfe neben dem Suchfeld.
  - Unten: ◀ · Überspringen · **Speichern & Weiter** · ▶. Wischen über das
    Foto blättert ebenfalls.
  - Oben rechts: ↶ macht die letzte Änderung rückgängig; im Menü „…“:
    Ursprünglichen Standort wiederherstellen, Koordinaten kopieren,
    Standort entfernen (Modus „bearbeiten“, mit Rückfrage).

## Abnahmetests

| Test | So prüfen |
|---|---|
| A | Zeitraum mit 200 Fotos, 30 ohne Ort wählen → Übersicht zeigt „200 untersucht · 30 ohne Standort · 30 noch offen“ und genau diese 30 Bilder. |
| B | Foto öffnen, „Berchtesgaden“ suchen, Treffer wählen, Nadel halten und auf den Wanderweg ziehen (Satellit hilft), „Speichern & Weiter“. In Fotos: Foto öffnen, nach oben wischen → Karte zeigt den Punkt. |
| C | Zehn Fotos nacheinander: Nadel setzen → „Speichern & Weiter“. Nach jedem Speichern erscheint das nächste offene Foto, die Karte bleibt im selben Ausschnitt. |
| D | „Standorte bearbeiten“ → Filter „Mit Ort“ → Foto öffnen. Karte steht auf dem Ort; Nadel ziehen → „Speichern“. Fotos zeigt den neuen Ort. |
| E | Nach dem Speichern oben rechts ↶ tippen → das Foto hat wieder seinen vorherigen Ort (oder keinen). |
| F | Mitten in der Bearbeitung die App ganz schließen. Neu öffnen → „Bearbeitung fortsetzen“ → es geht beim nächsten offenen Foto weiter, erledigte kommen nicht wieder. |

## Was iOS vorgibt

- Der Standort wird in der **Fotos-Mediathek** gespeichert
  (`PHAssetChangeRequest.location`), nicht durch Umschreiben der
  Bilddatei. So bleiben Bildqualität, Aufnahmedatum und alle anderen
  Angaben unangetastet, und es entsteht keine Kopie. Fotos zeigt den Ort
  sofort, iCloud gleicht ihn auf deine anderen Geräte ab, und beim Teilen
  oder Exportieren schreibt Fotos ihn in die weitergegebene Datei.
- **Live Photos:** Der Ort gilt für Foto und Video gemeinsam.
- **iCloud-Fotos** (Original nicht auf dem Gerät): Die Vorschau wird bei
  Bedarf geladen (Prozentanzeige); zum Speichern des Orts muss das
  Original nicht geladen werden.
- Fotos aus **geteilten Alben** oder **vom Computer synchronisierte** Fotos
  lassen sich von keiner App ändern. PhotoLocator erkennt das, nimmt sie
  in der Ergänzen-Suche nicht auf (zählt sie aber) und zeigt im Editor
  einen Hinweis.
- Kartenbilder, Suche und Adressanzeige brauchen eine Internetverbindung
  (Apple Karten, kostenlos). Die Adresse ist nur Anzeige — gespeichert
  wird immer genau die Koordinate der Nadel.
- Die Höhe kennt eine gesetzte Nadel nicht; sie wird darum nicht
  angegeben. „Rückgängig“ stellt dagegen den vorherigen Ort vollständig
  wieder her (inkl. Höhe).
