# Projekt Schreibspur (Grundschrift und Ziffern nachspuren, native iOS-App)

> Die übergreifenden Regeln (PR-Rhythmus, iOS-Pflichten, Bau in GitHub
> Actions) stehen in der `CLAUDE.md` im Wurzelverzeichnis und gelten hier
> genauso.

- App-Code: `SchreibspuriOS/` (ein Target: App, iPad + iPhone, iOS 17,
  SwiftUI, keine Fremdbibliotheken, kein Netz). Bundle-Id
  `de.familie.schreibspur` — nach dem ersten Signieren nicht mehr ändern.
- Zweck (Ansage des Nutzers, 09/2026): Lernanfängern die **Grundschrift**
  und die **Ziffern** beibringen, ähnlich der App „Ich schreibe". Erst
  wird jedes Zeichen **bewegungsrichtig vorgeführt**, dann spurt das Kind
  mit Finger oder Apple Pencil nach. Angenommen wird nur, was
  bewegungsrichtig und ordentlich geschrieben ist und nur an den
  vorgesehenen Stellen abgesetzt wird.
- **Versionierung:** Patch + Build je +1 bei jeder neuen Fassung
  (`MARKETING_VERSION` und `CURRENT_PROJECT_VERSION`, Debug und Release).
  Erste Fassung: 1.0.0 (1).
- `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` steht als
  Build-Einstellung im Target (es gibt keine eigene Info.plist,
  `GENERATE_INFOPLIST_FILE = YES`). Nie entfernen.

## Aufbau

| Datei | Inhalt |
|---|---|
| `Model/Zeichensatz.swift` | Alle Zeichen als Striche in der Wegsprache (M, L, A, Q, C, P) |
| `Model/Strich.swift` | Abtasten der Wege, Weglänge, nächste Stelle zu einem Punkt |
| `Model/Spurpruefer.swift` | Die Regeln des Nachspurens (Start, Richtung, Spur, Absetzen) |
| `Model/Zeichen.swift` | Zeichen und Gruppen (Groß-, Kleinbuchstaben, Ziffern), Lineatur |
| `Views/UebenAnsicht.swift` | Vorführung, Nachspuren, Rückmeldung, Blättern |
| `Views/Blatt.swift` | Zeichnen: Linienblatt, weiße Spur, Tinte, Start-/Zielpunkt, Hand |
| `Views/EingabeFlaeche.swift` | UIKit-Berührungen (Stift, zusammengefasste Punkte, Handballen) |

## Koordinaten und Zeichen

- Vierliniensystem in Einheiten, y nach unten: Oberlinie 0, Mittellinie
  0,5, Grundlinie 1, Unterlinie 1,5. Die Breite ergibt sich aus den
  Punkten, das Zeichen wird mittig gesetzt.
- **Reihenfolge und Richtung der Striche sind der Lehrinhalt.** Ein Bogen
  mit vertauschten Winkeln sieht gleich aus, läuft aber andersherum —
  der Compiler merkt das nie. Nach jeder Änderung an einem Weg:
  `python3 SchreibspuriOS/scripts/zeichen-vorschau.py vorschau.png`
  (Pillow nötig) und das Bild ansehen: Nummer am Strichanfang, Pfeile in
  Schreibrichtung.
- Getroffene Festlegungen (Grundschrift nach Grundschulverband, so wie in
  Anlauttabellen üblich): A in drei Strichen (hoch, runter, quer — wie in
  den Bildschirmfotos der Vorlage-App), E/F/T Stamm zuerst, 5 mit dem
  „Hut" zuletzt, 4 offen, 7 ohne Querstrich, a/d/g/q beginnen mit dem
  Bogen gegen den Uhrzeigersinn, b/h/n/m/p/r laufen den Stamm ein Stück
  zurück hinauf. i- und Umlautpunkte sind eigene Striche (nur antippen)
  und kommen zuletzt.

## Die Prüfung (Spurpruefer)

- Start innerhalb 1,5 × Toleranz um den roten Pfeil; wer am Zielkreis
  ansetzt, bekommt „Andersherum!".
- Der Fortschritt läuft nur vorwärts. Gesucht wird die nächste Stelle
  des Wegs in einem Fenster **1,5 × Toleranz zurück bis 3,5 × Toleranz
  voraus**; bei praktisch gleichem Abstand (5 % der Toleranz) gewinnt die
  Stelle nächst dem bisherigen Fortschritt, vorwärts halb gewichtet.
- **Diese Zahlen sind mit `scripts/spur-simulation.py` abgestimmt** —
  dort sauber nachspuren mit Zittern (muss klappen), verkehrt herum und
  halb geschrieben (darf nie klappen), für alle drei Genauigkeiten. Wer
  sie ändert, ändert sie in beiden Dateien und lässt die Simulation
  laufen (`Alles in Ordnung.` ist das Ziel). Gemessen: Ein kürzerer Blick
  nach vorn (2,5) lässt spitze Ecken wie beim W abbrechen, ein längerer
  (4,5) lässt den Fortschritt beim n über den Rückweg springen; ein
  großer Gleichstand (0,02 fest) lässt den Fortschritt hinterherhinken.
- Absetzen zählt nur, wenn höchstens 0,9 × Toleranz bis zum Ende fehlen.
- Genauigkeit: Locker 0,14 · Normal 0,1 · Streng 0,07 (halbe Bandbreite;
  die weiße Spur ist 0,085 breit).
- Sterne: 3 ohne Fehler, 2 bei ein oder zwei Fehlern, sonst 1. Jeder
  falsche Start, jedes Verlassen der Spur, jedes vorzeitige Absetzen ist
  ein Fehler; der Strich beginnt dann von vorn, schon geschaffte Striche
  bleiben stehen.

## Fallen

- Der `Canvas` liest den Spurprüfer beim Zeichnen, also außerhalb der
  Beobachtung durch SwiftUI. Deshalb liest `UebenAnsicht.body`
  `strichNummer`, `fortschritt` und `schreibtGerade` einmal ausdrücklich
  — ohne das zeichnet die Spur nicht mit.
- `onChange` auf `fehlerZaehler`/`strichZaehler` reagiert nur aufs
  Hochzählen: Ein neuer Spurprüfer (Blättern, Neu beginnen) setzt sie auf
  null zurück, und das wäre sonst ein Fehler-Rütteln bzw. ein Klick.
- Berührungen über UIKit (`EingabeFlaeche`), nicht `DragGesture`: nur so
  gibt es `coalescedTouches` (Stift bis 240 Hz), Handballen-Unterdrückung
  (nur die erste Berührung zählt) und die Einstellung „Nur Apple Pencil".
- App-Symbol: `scripts/app-symbol.py` erzeugt `AppIcon1024.png` neu.
