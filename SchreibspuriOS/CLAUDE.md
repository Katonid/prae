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
  Merkblatt „Flex und Flora“ um; 1.0.2 (3) bringt Kinderprofile,
  Lehrgang, vier Stufen und Schwungübungen; 1.0.3 (4) Stufe 5
  (Heftzeile), Bilderleiste und die ruhigere Gestaltung.
- `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` steht als
  Build-Einstellung im Target (es gibt keine eigene Info.plist,
  `GENERATE_INFOPLIST_FILE = YES`). Nie entfernen.

## Aufbau

| Datei | Inhalt |
|---|---|
| `Model/Zeichensatz.swift` | Alle Zeichen als Striche in der Wegsprache (M, L, A, Q, C, P) |
| `Model/Strich.swift` | Abtasten der Wege, Weglänge, nächste Stelle zu einem Punkt |
| `Model/Spurpruefer.swift` | Die Regeln des Nachspurens (Start, Richtung, Spur, Absetzen) |
| `Model/Zeichen.swift` | Zeichen, Lineatur, Bereiche (Schwünge, Buchstaben im Lehrgang, Ziffern) |
| `Model/Stufe.swift` | Die vier Stufen vom Nachspuren zum freien Schreiben |
| `Model/Heftpruefer.swift` | Prüfung der Heftzeile (Stufe 5): Vergleich nach Abschluss jedes Strichs |
| `Model/Anlautbilder.swift` | Bilder (Emoji) mit Wörtern je Buchstabe, nach dem Anlaut ausgewählt |
| `Model/Klasse.swift` | Kinderprofile, Sterne je Kind/Zeichen/Stufe, Lehrgangsfreigabe |
| `Views/UebenAnsicht.swift` | Vorführung, Nachspuren, Stufenwahl, Rückmeldung, Blättern |
| `Views/KindWahl.swift` | „Wer schreibt?" — Tierkarten |
| `Views/EinstellungenAnsicht.swift` | Kinder, Lehrgang, Stift — hinter der Malaufgabe (`ErwachsenenTor`) |
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
  halb geschrieben (darf nie klappen), für alle drei Genauigkeiten und
  die Stufen 1, 3 und 4 (Stufe 2 prüft wie Stufe 1). Wer
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

## Kinder, Lehrgang, Stufen (seit 1.0.2, Ansage des Nutzers 09/2026)

- **Kinderprofile** (`Klasse`): Name, Tier (Emoji, damit Nichtleser
  sich finden), Genauigkeit und Sterne je Kind; gespeichert als JSON
  unter `klasse.v1`. Wer schreibt, wird absichtlich **nicht**
  gespeichert — am Klassen-iPad wählt jedes Kind sich beim Öffnen; bei
  nur einem Kind entfällt die Wahl. Beim ersten Start mit 1.0.2 werden
  die alten Sterne (`fortschritt.sterne`) als Stufe 1 eines „Kind 1“
  übernommen.
- **Lehrgang:** `Zeichensatz.lehrgang` — Buchstabenpaare in der
  Reihenfolge des Merkblatts (zeilenweise, Vorder- vor Rückseite;
  Verbindungen wie Au, Sch, ck weggelassen, Qu → Q q). Der Bereich
  „Buchstaben“ zeigt sie in dieser Reihenfolge. Mit „Freischalten“ sind
  nur Lektionen bis `freiBis` offen; Blättern überspringt Gesperrtes.
  Schwünge und Ziffern sind immer offen.
- **Stufen** (`Stufe`): 1 weiße Spur mit Pfeil/Punkten/Ziel · 2 nur
  Punktlinie mit Start/Ziel · 3 nur Start und Ziel · 4 frei im
  aufgehellten Schreibfeld. Die nächste Stufe öffnet sich mit **drei
  Sternen**. Ab Stufe 3 zeigt die Tinte die echte Schrift des Kindes
  (`Spurpruefer.tinte`), vorher läuft sie sauber auf dem Weg. Auf Stufe 4
  erscheint der Startpunkt erst nach einem falschen Ansatz (`starthilfe`).
  Vorgeführt wird von selbst nur auf Stufe 1.
- Auf Stufe 3/4 wird das Band breiter (Faktor 1,25/1,6), die Regeln
  bleiben. Damit das nicht die Prüfung aushöhlt: **Fang höchstens 0,32
  und höchstens halbe Strichlänge, Zielrest höchstens 0,2 und höchstens
  ein Viertel der Strichlänge, Suchfenster aus höchstens 0,14** — sonst
  (gemessen) ging der t-Querstrich verkehrt herum durch und das n sprang
  über den Rückweg.
- **Stufe 4 verschiebt die Vorlage** mit dem ersten Ansatz
  (`verschiebbar`, `versatz`): Ohne Spur schreibt kein Kind genau an die
  gedachte Stelle; ohne das scheiterte eine ganz leicht versetzte, sonst
  richtige Schrift an spitzen Ecken (W).
- **Schwungübungen** (`Zeichensatz.schwuenge`): lange/kurze Striche,
  Querstriche, Zacken, Wendebögen, Brücken (n), Girlanden (u), Bögen (c),
  Kreise (o), Wellen (s) — Richtungen wie in den Buchstaben. Sie laufen
  durch dieselbe Prüfung und dieselben Stufen.
- **Einstellungen** liegen hinter einer Malaufgabe (6–9 × 4–9) — Kinder
  sollen weder Lehrgang noch Profile verstellen können.

## Gestaltung (Ansage des Nutzers, 09/2026)

- **Farbenfroh, aber ohne grafischen Ballast.** Nichts blinkt; Animation
  nur sparsam. Deshalb: kein Wackeln bei Fehlern (nur ein Satz und eine
  leichte Vibration), die Sterne im Lob erscheinen leise nacheinander
  (kein Hüpfen/Drehen), Übergänge nur als Überblendung. Die einzige
  echte Bewegung ist die Hand der Vorführung. Neue Effekte nur nach
  Rücksprache.
- **Bilderleiste** unter dem Schreibblatt jeder Buchstabenseite: zwei bis
  vier Bilder mit Wort, der Buchstabe im Wort rot. Emoji statt eigener
  Grafiken (farbig statt piktogrammhaft, überall vorhanden, keine
  Bildrechte — die Anlautbilder von „Flex und Flora“ dürfen nicht
  übernommen werden). Nach dem **Laut** gewählt (kein Eis beim E, kein
  Schaf beim S, kein Pferd beim P). Nicht antippbar, nicht bewegt; auf
  dem iPhone quer ausgeblendet.

## Stufe 5: Heftzeile (Ansage des Nutzers, 09/2026)

- Zweck: Buchstaben „in die normale Erstklässler-Lineatur“ schreiben und
  dabei prüfen, ob sie **lesbar** sind, an den richtigen **Etagen des
  Schreibhauses** beginnen und enden und **bewegungsrichtig**
  geschrieben sind — gerade weil Kinder im Heft anfangen, das O
  andersherum zu schreiben oder sich eigene Richtungen auszudenken.
- Das Kind schreibt das Zeichen viermal frei in eine Zeile in echter
  Größe (Einstellung Grundlinie–Oberlinie 12–24 mm, Standard 16 mm, auf
  dem iPad ≈ 5,2 pt/mm). Links steht der Musterbuchstabe; ▶ führt ihn
  vor. Nur Buchstaben und Ziffern, keine Schwünge.
- **Prüfung anders als auf Stufe 1–4** (`Heftpruefer`): nicht während
  des Schreibens entlang einer Spur, sondern bei jedem Abheben. Kind und
  Vorlage werden nach Weglänge in 40 Punkte geteilt und Punkt für Punkt
  verglichen — dadurch fällt ein andersherum geschriebenes O auf, obwohl
  es fertig genauso aussieht. Waagerecht wird die Vorlage an den ersten
  Ansatz gelegt und in der Breite angepasst; **senkrecht nie** (die
  Etagen sind Prüfgegenstand). Ein Fehler setzt nur das angefangene
  Zeichen zurück; die Hinweise nennen die Etage („Dieser Strich beginnt
  ganz oben unter dem Dach“).
- Abgestimmt mit `scripts/heft-simulation.py` (sauber in beliebiger Lage
  und Breite 0,8–1,25 → angenommen; verkehrt, eine Etage zu hoch/tief,
  nach 60 % abgesetzt → abgelehnt). Gemessene Lehren:
  - Breite nur aus schon angenommenen Strichen mit genug waagerechter
    Ausdehnung (Σu² > 1,5) — sonst schluckte die Breite einen halben
    Querstrich, und das kurze erste Stück des y wurde zum Maßstab.
  - Das Strichende wird **vom eigenen Anfang aus** gemessen, nicht
    absolut — sonst scheiterten saubere kurze Querstriche am Zittern.
  - **Bekannte Grenzen:** Querstriche unter 0,45 (t, f, A) dürfen
    kürzer sein; ein waagerechter Strich, bevor die Breite feststeht
    (oberer Querstrich des E), ebenso — die Buchstaben bleiben lesbar.
    Bei anderen Zufallsfolgen der Simulation fallen vereinzelt (≈ 1 von
    1000) saubere Striche unter „Streng“ durch.

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
