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
  Erste Fassung: 1.0.0 (1); 1.0.1 (2) stellt die Buchstaben auf das
  Merkblatt „Flex und Flora“ um.
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

- **Vorlage ist das „Merkblatt Schreibrichtung" aus Flex und Flora 1**
  (Westermann, Ansage des Nutzers 09/2026: „GENAU so sollen die
  Buchstaben geschrieben werden"). Strichfolge, Ansatzpunkte,
  Richtungen und Absetzstellen kommen von dort — nicht aus eigenem
  Ermessen ändern. Lesart des Blatts: Pfeil mit Punkt = hier ansetzen
  (lila = erster Strich, türkis = weiterer Strich), Pfeil ohne Punkt =
  ohne Absetzen in diese Richtung weiter.
- Vierliniensystem in Einheiten, y nach unten: Oberlinie 0, Mittellinie
  0,45 (`Zeichensatz.mittellinie`), Grundlinie 1, Unterlinie 1,4 — aus
  dem Blatt gemessen. Groß- und Kleinbuchstaben zeigen alle vier Linien
  (das J reicht in die Unterlänge), Ziffern nur drei.
- **Reihenfolge und Richtung der Striche sind der Lehrinhalt.** Ein Bogen
  mit vertauschten Winkeln sieht gleich aus, läuft aber andersherum —
  der Compiler merkt das nie. Nach jeder Änderung an einem Weg:
  `python3 SchreibspuriOS/scripts/zeichen-vorschau.py vorschau.png`
  (Pillow nötig) und das Bild neben das Merkblatt legen.
- Was das Merkblatt festlegt (Auswahl, weil es von der üblichen
  Druckschrift abweicht):
  - A: hoch und ohne Absetzen wieder runter, dann Querstrich. M, N, W,
    V, Z, L, U in einem Zug; das M reicht in der Mitte bis zur Grundlinie.
  - E, F, T, H: senkrechter Strich zuerst; H: links, rechts, Querstrich.
    B, D, P, R: Strich runter, dann oben neu ansetzen. G: Bogen, dann
    ohne Absetzen waagerecht nach links. Q: O, dann Schwanz von innen.
    J geht in die Unterlänge.
  - a, d, g, q, c, o, s: oben rechts ansetzen, gegen den Uhrzeigersinn;
    a/d/g/q danach ohne Absetzen den Strich hinunter.
  - b, h, n, m, p, r: erst runter, dann ein Stück zurück hinauf und den
    Bogen. e: waagerecht nach rechts, dann herum.
  - **Wendebogen** (Haken nach rechts) am Ende von a, d, h, i, l, m, n,
    t, u (und ä, ü). Kein Wendebogen bei k, q, f.
  - f und ß reichen bis zur Unterlinie; ß beginnt **unten** an der
    Unterlinie und geht hinauf. g und j enden mit einem Bogen nach links.
  - i-, j- und Umlautpunkte kommen zuletzt, links vor rechts.
- Die Ziffern stehen nicht auf dem Merkblatt; sie folgen der üblichen
  Schreibweise (5 mit dem „Hut" zuletzt, 4 offen, 7 ohne Querstrich).

## Die Prüfung (Spurpruefer)

- Start innerhalb 1,5 × Toleranz um den roten Pfeil; wer am Zielkreis
  ansetzt, bekommt „Andersherum!".
- Der Fortschritt läuft nur vorwärts. Gesucht wird die nächste Stelle
  des Wegs in einem Fenster **1,5 × Toleranz zurück bis 3,5 × Toleranz
  voraus**; bei praktisch gleichem Abstand (5 % der Toleranz) gewinnt die
  Stelle nächst dem bisherigen Fortschritt, vorwärts nur 0,4-fach
  gewichtet (mit 0,5 brach beim d unter „Streng“ selten der Rückweg
  am oberen Wendepunkt ab).
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
