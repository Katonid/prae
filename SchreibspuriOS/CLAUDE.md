# Projekt Schreibspur (Grundschrift und Ziffern nachspuren, native iOS-App)

> Die übergreifenden Regeln (PR-Rhythmus, iOS-Pflichten, Bau in GitHub
> Actions) stehen in der `CLAUDE.md` im Wurzelverzeichnis und gelten hier
> genauso.

- App-Code: `SchreibspuriOS/` (ein Target: App, iPad + iPhone, iOS 17,
  SwiftUI, keine Fremdbibliotheken; Netz nur für den iCloud-Abgleich der
  Klasse seit 1.0.11). Bundle-Id
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
  Merkblatt des Nutzers um; 1.0.2 (3) bringt Kinderprofile,
  Lehrgang, vier Stufen und Schwungübungen; 1.0.3 (4) Stufe 5
  (Heftzeile), Bilderleiste und die ruhigere Gestaltung; 1.0.4 (5)
  Wörter und „Gemischt üben“ in der Heftzeile, Lehrgang mit allen
  Schritten des Merkblatts; 1.0.5 (6) Heftzeile wieder einzeilig (Muster
  links), großzügigere Heftprüfung, Team eingetragen; 1.0.6 (7) alle
  Prüfungen auf echte Anfängerschrift eingestellt; 1.0.7 (8) Heftseite
  mit mehreren Reihen, Abstandsprüfung, neue Farben ohne Türkis und
  Regenbogen, orange Warnfarbe beim Schreiben, rund 600 Wörter; 1.0.8
  (9) fünf Reihen je Buchstabenseite, „zu eng“, O darf anders ansetzen;
  1.0.9 (10) Klassenübersicht mit gespeicherten Seiten, kräftigeres
  App-Symbol; 1.0.10 (11) Hilfe-Treppe und Lehrerbereich mit Code;
  1.0.11 (12) Klasse über iCloud: Lehrergerät, Kindergeräte,
  Anmeldekarten; 1.0.12 (13) Klassencode statt Anmeldekarten — die Kinder
  melden sich selbst an; 1.0.13 (14) Briefkasten in der öffentlichen
  Datenbank + Funk im Klassenzimmer (Gäste, private Apple-ID); 1.0.14
  (15) „Neue Klasse“ als Eingabefenster, auch auf der Lehrer-Startseite;
  1.0.15 (16) Ziffern nach dem Ziffernschreibkurs in Rechenkästchen.
- Team: `DEVELOPMENT_TEAM = F4989GSTWS` (Regel im Wurzel-CLAUDE.md).
- `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` steht als
  Build-Einstellung im Target (`GENERATE_INFOPLIST_FILE = YES`). Nie
  entfernen. Seit 1.0.11 gibt es zusätzlich `Config/Info.plist`
  (`INFOPLIST_FILE`, wird mit der erzeugten zusammengeführt) — nur für
  Schlüssel ohne Build-Einstellung: `NSBonjourServices`
  (`_schreibspur._tcp/_udp`, für den Funk im Klassenzimmer — ohne den
  Eintrag findet MultipeerConnectivity nichts) und Deutsch als
  Entwicklungssprache. `NSLocalNetworkUsageDescription` steht als
  Build-Einstellung.
  Der Ordner `Config/` liegt absichtlich AUSSERHALB des synchronisierten
  Ordners `Schreibspur/`, sonst würde die Info.plist als Ressource
  kopiert.
- **iCloud-Rechte seit 1.0.11:** `Config/Schreibspur.entitlements`
  (Debug) und `Config/Schreibspur-Release.entitlements` (Release), nur
  noch CloudKit mit Container `iCloud.de.familie.schreibspur` (seit
  1.0.13 ohne `aps-environment`: Der Briefkasten wird im Minutentakt
  abgeholt, Pushes braucht es nicht). **Die App-Id muss iCloud (CloudKit,
  mit diesem Container) tragen, sonst lässt sich die App nicht mehr
  signieren** — einmalig in Xcode unter „Signing &
  Capabilities“ bestätigen (Lehre aus Urlaubstagebuch 1.0.44/1.0.45). Ein
  grüner Bau in GitHub Actions sagt darüber nichts.

## Aufbau

| Datei | Inhalt |
|---|---|
| `Model/Zeichensatz.swift` | Alle Zeichen als Striche in der Wegsprache (M, L, A, Q, C, P) |
| `Model/Strich.swift` | Abtasten der Wege, Weglänge, nächste Stelle zu einem Punkt |
| `Model/Spurpruefer.swift` | Die Regeln des Nachspurens (Start, Richtung, Spur, Absetzen) |
| `Model/Zeichen.swift` | Zeichen (auch Folgen = Wörter), Lineatur, Bereiche, Lehrgang, Wortzuordnung |
| `Model/Stufe.swift` | Die vier Stufen vom Nachspuren zum freien Schreiben |
| `Model/Heftseite.swift` | Stufe 5: mehrere Reihen, je Reihe Muster + `Heftpruefer`, Pflicht und Kür |
| `Model/Tinte.swift` | `Tintenpunkt`: Schrift des Kindes mit Warnwert je Punkt |
| `Model/Heftpruefer.swift` | Prüfung der Heftzeile (Stufe 5): Vergleich nach Abschluss jedes Strichs |
| `Model/Anlautbilder.swift` | Bilder (Emoji) mit Wörtern je Buchstabe, nach dem Anlaut ausgewählt |
| `Model/Klasse.swift` | Kinderprofile, Sterne je Kind/Zeichen/Stufe, Lehrgangsfreigabe |
| `Model/Protokoll.swift` | Bearbeitungen je Kind und ihre Spuren als Vektoren (Klassenübersicht) |
| `Model/Wolke.swift` | Datenaustausch: Briefkasten (öffentliche Datenbank) + Funk, Klassen, Beitreten, Abholen |
| `Model/Nahfunk.swift` | Funk im Klassenzimmer (MultipeerConnectivity): Lehrer kündigt an, Kind sucht |
| `Model/Post.swift` | Pakete, Anmeldung, Klasseninfo, Vorgaben, Funk-Nachrichten |
| `Model/Klassencode.swift` | Klassencode, Klassenzimmer, `Umschlag` (Verschlüsselung für die Lehrkraft), Schlüssel |
| `Views/Rollen.swift` | Erster Start (wer benutzt das Gerät?), Lehrer-Startseite |
| `Views/KlassencodeAnsichten.swift` | Code-Eingabe mit Name und Tier (Kind), Klassen und Codes, Code groß (Lehrkraft) |
| `Views/KlassenAnsicht.swift` | Klassenübersicht: Raster Kinder × Buchstaben, je Kind Stufen, Seiten nachsehen |
| `Views/UebenAnsicht.swift` | Vorführung, Nachspuren, Stufenwahl, Rückmeldung, Blättern |
| `Views/KindWahl.swift` | „Wer schreibt?" — Tierkarten |
| `Views/EinstellungenAnsicht.swift` | Kinder, Lehrgang, Stift, Code — im Lehrerbereich |
| `Views/LehrerTor.swift` | Tür zum Lehrerbereich: Code festlegen/eingeben, Face ID, Code ändern |
| `Model/Lehrerzugang.swift` | Code als gesalzener SHA-256 im Schlüsselbund, Sperre nach Fehlversuchen |
| `Views/Blatt.swift` | Zeichnen: Linienblatt, Spur, Tinte, Start-/Zielpunkt, Hand |
| `Views/EingabeFlaeche.swift` | UIKit-Berührungen (Stift, zusammengefasste Punkte, Handballen) |

## Koordinaten und Zeichen

- **Kein Verlags- oder Fibelname in der App** (Ansage des Nutzers
  09/2026: die Übungen sind nicht mit dem Verlag abgesprochen). Auch in
  Kommentaren und Doku nur „Merkblatt“ bzw. „Lehrgang“ schreiben.

- **Vorlage ist das Merkblatt zur Schreibrichtung, das der Nutzer vorgab**
  (Ansage des Nutzers 09/2026: „GENAU so sollen die
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
- **Ziffern seit 1.0.15 nach dem Ziffernschreibkurs des Nutzers**
  (Bildschirmfotos 10/2026: „Die Ziffern sollen so aussehen“): Reihenfolge
  1 … 9, 0, dann die 10 (zwei Kästchen, `Zeichenvorrat.zehn`). 1 mit
  Anstrich; 4 offen — erst links hinunter mit dem Querstrich, dann der
  rechte Strich von oben; 5 mit dem Hut zuletzt; **7 mit Querstrich**
  (zweiter Strich); 6, 8, 9, 0 oben rechts begonnen und gegen den
  Uhrzeigersinn, die 9 mit kleinem Bogen nach links. Vorher (bis 1.0.14)
  7 ohne Querstrich, 0/9 anders begonnen.

## Die Prüfung (Spurpruefer)

- Start innerhalb 1,5 × Toleranz um den grünen Pfeil; wer am Zielkreis
  ansetzt, bekommt „Andersherum!".
- Der Fortschritt läuft nur vorwärts. Gesucht wird die nächste Stelle
  des Wegs in einem Fenster **1,5 × Toleranz zurück bis 4 × Toleranz
  voraus** (Toleranz hier höchstens 0,14; 3,5 reichte mit den
  großzügigeren Maßen von 1.0.6 an spitzen Ecken wie beim M nicht mehr); bei praktisch gleichem Abstand (5 % der Toleranz) gewinnt die
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
- Genauigkeit: Locker 0,17 · Normal 0,12 · Streng 0,08 (seit 1.0.6,
  vorher 0,14 / 0,1 / 0,07 — „Lernanfänger schreiben nicht so
  ordentlich“) (halbe Bandbreite;
  die Spur ist 0,085 breit).
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
- **Lehrgang:** `Zeichensatz.lehrgangSchritte` — **genau die Reihenfolge
  des Merkblatts** (Ansage des Nutzers: „Es gilt die Seite, die mit dem A
  anfängt. Der nächste Buchstabe ist das M daneben, dann das O und dann
  wird es reihenweise so abgearbeitet“): A a, M m, O o, I i, L l, U u,
  E e, S s, F f, N n, W w, R r, T t, Au au, P p, Ei ei, D d, Sch sch …,
  danach die Rückseite. Die Verbindungen (Au, Ei, Sch, Eu, ch, ie, Sp,
  St, äu, Pf, ng, tz, ck, nk) sind eigene Schritte ohne Schreibübung;
  sie entscheiden, ab wann Wörter mit ihnen dran sind. Qu bringt das Q.
  `freiBis` zählt seit 1.0.4 diese Schritte (vorher Buchstaben-Lektionen;
  `Klasse.init` rechnet alte Stände um). Blättern überspringt Gesperrtes;
  Schwünge, Ziffern und Wörter sind immer offen.
- **Stufen** (`Stufe`): 1 Spur mit Pfeil/Punkten/Ziel · 2 nur
  Punktlinie mit Start/Ziel · 3 nur Start und Ziel · 4 frei im
  getönten Schreibfeld. Die nächste Stufe öffnet sich mit **drei
  Sternen**. Die Tinte zeigt seit 1.0.7 auf allen Stufen die echte
  Schrift des Kindes (`Spurpruefer.tinte`, mit Warnfarbe). Auf Stufe 4
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
- **Einstellungen** liegen seit 1.0.10 im Lehrerbereich hinter einem Code
  (vorher eine Malaufgabe 6–9 × 4–9, die nur Schulanfänger aufhielt —
  Nutzer: „theoretisch kann jeder sie erreichen“). Siehe unten.

## Gestaltung (Ansage des Nutzers, 09/2026)

- **Kein Türkis, kein Regenbogen** (seit 1.0.7): Beides ist das
  Kennzeichen der App, die als Beispiel diente — der Nutzer will keine
  Ansprüche riskieren, und der Regenbogen verwirrt die Kinder. Farben in
  `Farben` (Blatt.swift): warmes Papier (Creme), Erdgeschoss zart grün,
  Linien blaugrau, Spur hell stahlblau mit Rand, Start grün, Ziel
  violett, Tinte dunkelblau (Stift wählbar: Blau, Grün, Lila,
  Dunkelgrau — nie Orange/Rot), Hinweise korallrot, Hauptknöpfe orange.
  Übersicht auf warmem Verlauf, jeder Bereich hat eine eigene Farbe
  (Reiter, Kachelrand, Schriftzug). Karten und Bilder mit weichem
  Schatten. Die App erzwingt die helle Darstellung.
- **Farbrückmeldung beim Schreiben:** Die Tinte zeigt die echte Schrift
  des Kindes (auf allen Stufen) und färbt sich **orange, wo der Strich
  aus der Form zu laufen droht** — auf Stufe 1–4 ab der halben
  Bandbreite (`Spurpruefer`, Wert je Punkt in `Tintenpunkt.warnung`), auf
  der Heftseite, sobald der Stift die Höhe seines Strichs verlässt
  (`Heftpruefer.warnung`). Drei Stufen: Stiftfarbe, Hellorange, Orange.
- Das App-Symbol (`scripts/app-symbol.py`) folgt denselben Farben. Seit
  1.0.9 kräftig (Nutzer: „zu blass, vom A sieht man nur den ersten
  Strich“): satter Verlauf Orange → Korallrot, Heftblatt, das **ganze** A
  in dunkelblauer Tinte, grüner Start am Fuß (Merkblatt: hoch und ohne
  Absetzen wieder hinunter), violettes Ziel. Keine blassen Spurreste als
  Hauptmotiv — auf dem Homescreen sind sie nicht zu erkennen.

- **Farbenfroh, aber ohne grafischen Ballast.** Nichts blinkt; Animation
  nur sparsam. Deshalb: kein Wackeln bei Fehlern (nur ein Satz und eine
  leichte Vibration), die Sterne im Lob erscheinen leise nacheinander
  (kein Hüpfen/Drehen), Übergänge nur als Überblendung. Die einzige
  echte Bewegung ist die Hand der Vorführung. Neue Effekte nur nach
  Rücksprache.
- **Bilderleiste** unter dem Schreibblatt jeder Buchstabenseite: zwei bis
  vier Bilder mit Wort, der Buchstabe im Wort rot. Emoji statt eigener
  Grafiken (farbig statt piktogrammhaft, überall vorhanden, keine
  Bildrechte — Anlautbilder aus Verlagsfibeln dürfen nicht
  übernommen werden). Nach dem **Laut** gewählt (kein Eis beim E, kein
  Schaf beim S, kein Pferd beim P). Nicht antippbar, nicht bewegt; auf
  dem iPhone quer ausgeblendet.

## Stufe 5: Heftseite (Ansage des Nutzers, 09/2026)

- **Seit 1.0.7 mehrere Reihen untereinander** (`Heftseite`), seit 1.0.8
  nach dem Vorbild einer Fibelseite des Nutzers **fünf Reihen**
  (`Zeichenvorrat.heftreihen`, `Heftseite.Vorgabe`): Großbuchstabe,
  Kleinbuchstabe, Groß und klein im Wechsel („A a A a“, zählt als
  einzelne Buchstaben, nicht als Wort), dann zwei Reihen Verbindungen
  aus schon Gelerntem — eine Silbe („Ma“) und ein Wort mit dem
  Buchstaben („Mama“, kurze und mit ihm beginnende zuerst); solange es
  noch kein Wort gibt, zwei Silben. Das A hat nur drei Reihen (nichts zu
  verbinden), ß eine Reihe plus Silbe/Wort. Wörter: das gewählte Wort
  und die drei folgenden der Liste, je eine Reihe. „Gemischt üben“: vier
  gelernte Buchstaben, je eine Reihe. Ziffern: zwei Reihen. Passen die
  Reihen nicht in echter Größe, wird die Seite kleiner (`abbildung`).
- **Pflicht und Kür:** je Reihe drei Buchstaben, zweimal „A a“, zwei Silben
  oder kurze Wörter (bis drei Buchstaben), sonst ein
  Wort; danach erscheint oben ein Lob, das nichts versperrt — das Kind
  darf die Reihen voll schreiben (Ansage: „Manche wollen die ganze Reihe
  voll bekommen“). Sterne zählen die Fehler bis zur erfüllten Pflicht;
  eingetragen für alle Buchstaben bzw. Wörter der Seite.
- **Abstand** (`Heftpruefer`): geschätzt am Ansatz des neuen Buchstabens
  gegen den rechten Rand des vorigen (abzüglich des Stücks, das der
  Ansatz in der Vorlage vom linken Rand liegt). Höchstens 0,9 zwischen
  Wiederholungen, 0,5 im Wort/in der Silbe, 1,2 nach dem Muster (× √
  Genauigkeitsfaktor); darauf oder links davon: „Schreib rechts
  daneben“. Grund: sonst schreiben Kinder drei Buchstaben pro Reihe.
- **Zu eng** (seit 1.0.8, Nutzer: „beanstanden, wenn Buchstaben so eng
  zusammengeschrieben werden“ — „AA“ ineinander wurde angenommen):
  Gemessen am **fertigen** Buchstaben, nur **unterhalb der Mittellinie**
  (y ≥ 0,5), linker Rand gegen rechten Rand des vorigen. Zwischen
  Buchstaben, die kein Wort bilden, mindestens 0,15; im Wort −0,03
  (fast berühren ja, übereinander nein). Unterhalb der Mittellinie,
  damit das Dach des T und der Haken des f über den nächsten Buchstaben
  ragen dürfen („Tor“, „fe“). Der zu enge Buchstabe wird verworfen.
- **Lehre aus 1.0.7 → 1.0.8 (Nutzer: „Beim O ist die App wieder zu
  pingelig“):** Kinder setzen das O oft oben in der Mitte oder weiter
  links an statt oben rechts. Die Vorlage hing an einem festen Ansatz
  auf dem Kreis. Jetzt wird bei **geschlossenen** Strichen (Anfang ≈
  Ende, Länge > 0,5) die Vorlage um 3, 6 oder 9 von 40 Punkten
  weitergedreht (`zyklisch`) — gleiche Richtung, deshalb bleibt ein
  andersherum geschriebenes O abgelehnt. Genauso in
  `scripts/heft-simulation.py`.
- Welche Reihe gemeint ist: die, in deren Linien der Stift ansetzt —
  außer ein Buchstabe ist angefangen (i-Punkt, Unterlänge), dann bleibt
  es bei dessen Reihe, solange der Ansatz in ihrer Nähe liegt.

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
  es fertig genauso aussieht. Waagerecht wird die Vorlage so über den
  ersten Strich gelegt, dass sie am besten passt (kleinste Quadrate), und
  in der Breite angepasst; weitere Striche dürfen bis 0,12 daneben liegen
  und ±20 % länger/kürzer sein; **senkrecht nie** (die Etagen sind
  Prüfgegenstand). Ein Fehler setzt nur das angefangene
  Zeichen zurück; die Hinweise nennen die Etage („Dieser Strich beginnt
  ganz oben unter dem Dach“).
- **Lehre aus 1.0.4 → 1.0.5 (Nutzer: „noch nicht einmal geschafft“):**
  Das Muster stand in einer eigenen Zeile über der Schreibzeile. Beide
  sahen gleich aus; der Nutzer schrieb neben das Muster in die obere
  Zeile, die Prüfung las es als Schrift der unteren — eine ganze Zeile
  daneben, also immer „falsche Etage“. Jetzt wieder **eine** Zeile: Muster
  links, gestrichelte Trennlinie, rechts davon wird geschrieben (weiter
  links: „Schreib rechts neben das Muster“). Nie wieder zwei gleich
  aussehende Zeilen mit nur einer gültigen.
- **1.0.6: auf Anfängerschrift eingestellt** (Nutzer: „Du bist trotzdem
  zu streng. Lernanfänger schreiben nicht so ordentlich.“). Die
  Simulation schreibt seither je Genauigkeit unterschiedlich unordentlich
  (`SCHRIFT`: Zittern, schiefe Buchstaben ±15 %, Größe ±12 %, Lage ±0,06,
  Striche treffen sich nicht, Anfang daneben — bei „Normal“) und misst
  Anteile statt Einzelfälle: richtig geschriebene Buchstaben ≥ 98 %
  angenommen (Locker ≥ 97 %), verkehrt herum und eine Etage daneben
  **ausnahmslos** abgelehnt, halbe lange Striche ≥ 95 % (Locker ≥ 85 %).
  Maße: Mittel 0,18, Spitze 0,42, Etage 0,25 (wächst mit der Genauigkeit
  höchstens um 10 %), Ende 0,3; Anfang gemessen bei 5 % des Wegs. Vorher
  lehnte „Normal“ jeden siebten richtig geschriebenen Buchstaben ab.
- Zugleich war die Prüfung zu starr: Die Vorlage hing am Ansatzpunkt, und
  ein ungenau gesetzter Anfang verschob den ganzen Buchstaben. Die
  Simulation spielt seither einen solchen Anfang mit; die Maße wurden
  großzügiger (Mittel 0,12, Spitze 0,3, Etage 0,15, Ende 0,22).
- Abgestimmt mit `scripts/heft-simulation.py` (sauber mit Zittern,
  ungenauem Ansatz, beliebiger Lage und Breite 0,8–1,25 → angenommen;
  verkehrt, eine Etage zu hoch/tief, nach 60 % abgesetzt → abgelehnt;
  „Locker“ lässt vereinzelt verkürzte Striche durch). Gemessene Lehren:
  - Breite nur aus schon angenommenen Strichen mit genug waagerechter
    Ausdehnung (Σu² > 1,5) — sonst schluckte die Breite einen halben
    Querstrich, und das kurze erste Stück des y wurde zum Maßstab.
  - Das Strichende wird **ab 15 % des Wegs** gemessen, nicht absolut und
    nicht ab dem Ansatz — sonst scheiterten saubere kurze Querstriche am
    Zittern und am ungenauen Anfang.
  - Nur Striche mit mindestens 0,4 Breite bestimmen die Schriftbreite
    (der Haken oben am f war ein wackliger Maßstab für den Querstrich).
  - **Bekannte Grenzen:** Striche unter 0,6 (Querstriche von t, f, A, E,
    Hut der 5) dürfen kürzer sein — die Buchstaben bleiben lesbar.

## Ziffern in Rechenkästchen (seit 1.0.15, Ansage des Nutzers 10/2026)

- „Geübt werden sollen sie natürlich in Rechenkästchen. Auch diese sollen
  zu Beginn groß sein und in weiteren Übungen immer kleiner. Die Ziffern
  sollen bewegungsrichtig sein und im Kästchen Platz finden … Berühren
  ist erlaubt und eine gewisse Toleranz auch, aber sie sollen nicht über
  das Kästchen großartig hinauslaufen und auch nicht im Kästchen zu klein
  sein.“
- Maße (`Kaestchen`): Ziffer 1 hoch, um x = 0,3; Kästchen 1,3 groß, oben
  bei −0,15 — die Ziffer füllt es zu gut drei Vierteln wie auf dem Blatt.
  Stufe 1–4 zeigen Rechenpapier mit dem Kästchen der Ziffer
  (`Zeichner.rechenpapier`, `Lineatur.ziffern`).
- Heftseite einer Ziffer (`Zeichenvorrat.kaestchenreihen`): zwei Reihen
  große Kästchen (Faktor 1, Pflicht 3), zwei mittlere (0,75, Pflicht 4),
  eine kleine (0,55, Pflicht 5), zuletzt klein im Wechsel mit der Ziffer
  davor. Bei 16 mm Heftgröße: etwa 21, 16 und 11 mm Kästchen. Die Reihen
  verteilt `Heftseite.Lage` (verschiedene Größen, Seiten-y 0 = oberer
  Rand); `UebenAnsicht.abbildung` und `Seitenbild` rechnen mit derselben.
- Prüfung (`Heftpruefer`, `kaestchenStart`): dieselbe Formprüfung wie bei
  den Buchstaben (Richtung, Strichfolge, Höhe nie angepasst), dazu: jede
  Ziffer im nächsten freien Kästchen (Ansatz höchstens 0,25 daneben —
  „Schreib in das nächste freie Kästchen“), die fertige Ziffer höchstens
  `randToleranz` 0,14 (× √Genauigkeit) über den Rand („Bleib im
  Kästchen“), mindestens `mindestHoehe` 0,62 hoch („Schreib größer“).
  Die Tinte wird orange, sobald sie über den Rand läuft. Hinweise sagen
  „oben im Kästchen“ statt „unter dem Dach“.
- `Blattspuren.Reihe` trägt `kaestchen` und `faktor` (optional — ältere
  Seiten haben sie nicht), damit die Klassenübersicht Ziffernseiten mit
  Kästchen zeigt.
- **Nicht gemessen:** Die Grenzen 0,14 und 0,62 sind geschätzt, nicht mit
  der Simulation abgestimmt (die prüft nur die Form). Erst echte
  Kinderschrift zeigt, ob sie passen.

## Wörter und „Gemischt üben“ (seit 1.0.4, Ansage des Nutzers 09/2026)

- 1.0.7: rund 600 Wörter statt 260 (Ansage: „noch mehr Alternativen“),
  auch Tunwörter und Wiewörter (malen, rot, lila); schon ab L gibt es
  ein gutes Dutzend.

- Auf der Heftstufe sollen nicht nur einzelne Buchstaben geschrieben
  werden, sondern **Wörter aus bereits bekannten Buchstaben**, und
  bekannte Buchstaben sollen **weitergeübt** werden. Bereich „Wörter“:
  zuerst die Kachel „Gemischt üben“, dann die Wörter, die neuesten zuerst.
- Wortschatz: `Zeichensatz.woerter`. Ein Wort ist dran, wenn alle
  Buchstaben **und** alle Verbindungen darin gelernt sind
  (`Zeichenvorrat.wortSchritt`): „Eis“ erst nach Ei, „Tisch“ nach Sch,
  „Stern“ nach St (st/sp nur am Wortanfang), „Katze“ nach tz.
  `scripts/woerter-pruefen.py` listet, welches Wort ab welchem Schritt
  kommt — nach jeder Änderung an der Liste ansehen. Nicht aufnehmen:
  Wörter, in denen Buchstaben anders klingen als gelernt (Mais, Ferien,
  Clown, Computer).
- Geschrieben wird in die Heftzeile rechts neben das Musterwort
  (eine Zeile, siehe Lehre oben). Geprüft wird Buchstabe für
  Buchstabe mit dem `Heftpruefer` (Folge statt einzelnem Zeichen): jeder
  Buchstabe legt die Vorlage neu an, der nächste muss rechts vom vorigen
  beginnen. Fehler nennen den Buchstaben („m: Dieser Strich …“) und
  setzen nur den angefangenen Buchstaben zurück. i- und Umlautpunkte
  kommen direkt nach ihrem Buchstaben, nicht erst am Wortende.
- „Gemischt üben“ (`Klasse.mischung`): sechs gelernte Buchstaben, jedes
  Mal neu gewürfelt; wenig Sterne → öfter; nie derselbe zweimal
  hintereinander. Keine Sterne gespeichert (jede Mischung ist anders).

## Klassenübersicht (seit 1.0.9, Ansage des Nutzers 09/2026)

- Zweck: Die Lehrkraft sieht, **welche Buchstaben jedes Kind bearbeitet
  hat und wie viele Versuche es brauchte** — ohne die Versuche, die das
  Kind freiwillig zusätzlich macht — und kann **jede Seite nachträglich
  ansehen**: Die Spuren werden als Vektoren gespeichert und auf dem
  Hintergrund der Stufe neu gezeichnet.
- Zugang: Knopf „Klassenübersicht“ auf „Wer schreibt?“ und oben in den
  Einstellungen, beide im Lehrerbereich (`LehrerTor`).
- `Protokoll` (in `Klasse.protokoll`): Dateien unter Application
  Support/Protokoll/<Kind-Id>/ — `verzeichnis.json` mit allen
  `Bearbeitung`en (klein, beim ersten Zugriff geladen) und je Bearbeitung
  eine Datei mit den `Blattspuren` (nur beim Ansehen geladen). Punkte in
  Tausendsteln einer Einheit, Farbstufe je Punkt, Zeit je Strich (für
  das Nachspielen über alle Reihen). Kind entfernen löscht seine Dateien.
- **Was gezählt wird:**
  - Eine Bearbeitung = ein Anlauf auf einer Stufe (Seite geöffnet bis
    Blättern/Neu/Vorführen/Übersicht/App im Hintergrund). Ohne jeden
    Strich wird nichts gespeichert.
  - `fehler` nur bis zur erfüllten Pflicht (Heftseite:
    `geschafftBeiFehlern`); was danach freiwillig geschrieben wird, steht
    als `kuer` daneben und zählt nicht.
  - `freiwillig`: Die Stufe war beim Beginn schon mit drei Sternen
    gemeistert — erscheint in den Listen, zählt aber nicht in „Anläufe“
    und „F“ der Übersicht (`Auswertung.je`).
  - Stufe 5 eines Buchstabens zählt für Groß- und Kleinbuchstaben
    (`Zeichenvorrat.seitenpartner`) — beide öffnen dieselbe Seite.
- **Verworfenes wird mitgespeichert** (`protokoll` in `Spurpruefer` und
  `Heftpruefer`, `Protokollstrich`): falscher Ansatz als Punkt (roter
  Kreis), abgebrochener Strich bis zur Stelle des Fehlers, auf der
  Heftseite der ganze verworfene Buchstabe (auch seine schon
  angenommenen Striche). In der Seitenansicht rot gestrichelt,
  ausblendbar; Regler und ▶ spielen die Seite Strich für Strich nach.
- Gespeichert wird beim Schaffen **und** beim Verlassen (`sitzungSpeichern`
  mit derselben id ersetzt den Eintrag) — sonst fehlte auf der Heftseite,
  was das Kind nach dem Lob noch geschrieben hat. Vorführen setzt auf
  Stufe 1–4 das Zeichen zurück; was bis dahin geschrieben war, wird
  vorher als eigene Bearbeitung gespeichert.
- Muster und Hintergrund werden aus `Blattspuren.Reihe` (`teile`, `art`)
  mit `Heftseite.Vorgabe.aus` neu gebaut. Wer die Wegdaten eines
  Buchstabens ändert, ändert damit auch das Muster alter Seiten — die
  Schrift des Kindes bleibt, wie sie war.

## Hilfe-Treppe (seit 1.0.10, Ansage des Nutzers 09/2026)

- Wird ein Strich (Stufe 1–4) bzw. Buchstabe (Heftseite) wiederholt
  abgelehnt, braucht das Kind noch einmal eine Anleitung. Statt gleich
  alles zu zeigen, wächst die Hilfe mit jedem Fehlversuch **an derselben
  Stelle** (`hilfe` in `Spurpruefer` und `Heftpruefer`):
  1. erster Fehlversuch: nur der Hinweissatz (wie bisher);
  2. zweiter: **Startpunkt mit Pfeil** (und Ziel) des nächsten Strichs;
  3. dritter: dazu die **Punktlinie** — und die **Hand schreibt es einmal
     vor**, genau an der Stelle, wo das Kind schreiben soll (auf der
     Heftseite der ganze Buchstabe an seinem Platz, auf Stufe 1–4 nur der
     aktuelle Strich; das schon Geschriebene bleibt stehen);
  4. ab dem vierten: die **Spur** zum Nachfahren (auf Stufe 1–4 mit
     grüner Führungslinie).
  Die Idee dahinter: Die Hilfen der leichteren Stufen kommen zurück; auf
  Stufe 1 ist schon alles zu sehen, dort bleibt die Vorführung.
- **Hilfe-Knopf** (Glühbirne, oben rechts): Das Kind holt sich selbst die
  nächste Stufe, auch ohne Fehler.
- Die Hilfe gilt nur für den angefangenen Strich/Buchstaben; ist er
  geschafft, beginnt der nächste wieder ohne. Die Prüfung bleibt gleich
  — die Hilfe zeigt, wo und wie, schreiben muss das Kind selbst.
- Auf der Heftseite liegt die Hilfe dort, wo die Prüfung den Buchstaben
  erwartet (`hilfeZeichen`): Ist schon ein Strich angenommen, so wie
  dieser; sonst rechts neben dem vorigen Buchstaben mit dem üblichen
  Abstand. Auf Stufe 4 mit der Verschiebung des ersten Ansatzes.
- Sterne ändern sich durch Hilfe nicht (die Fehler zählen ohnehin). Die
  Klassenübersicht zeigt „Hilfe n×“ (`Bearbeitung.hilfen`, optional —
  Einträge aus 1.0.9 haben das Feld nicht; neue Felder in `Bearbeitung`
  immer optional anlegen, sonst lassen sich alte Verzeichnisse nicht mehr
  lesen).

## Lehrerbereich (seit 1.0.10, Ansage des Nutzers 09/2026)

- Klassenübersicht und Einstellungen liegen hinter `LehrerTor`. Beim
  ersten Öffnen legt die Lehrkraft einen **Code** fest (mindestens vier
  Ziffern); danach Code oder — wenn eingeschaltet — **Face ID/Touch ID**
  (`INFOPLIST_KEY_NSFaceIDUsageDescription` im Target, ohne sie stürzt
  die App beim Face-ID-Aufruf ab).
- `Lehrerzugang`: Gespeichert wird nur Salz + SHA-256 im Schlüsselbund
  (`AfterFirstUnlockThisDeviceOnly`). Dazu ein Merker in den
  Voreinstellungen: Nach Löschen und Neuladen der App bleibt der
  Schlüsselbund stehen, der Merker nicht — dann wird neu eingerichtet
  statt mit einem alten Code ausgesperrt.
- Nach drei falschen Codes 30 s gesperrt, danach jeweils doppelt so
  lange, höchstens 15 min.
- **Code vergessen:** Face ID oder Gerätecode des iPads legt einen neuen
  fest. Ohne Gerätecode geht das nicht (Hinweis im Tor).
- Geht die App in den Hintergrund, schließt sich der Bereich.
- Hashing und Schlüsselbund sind keine meldepflichtige Verschlüsselung —
  `ITSAppUsesNonExemptEncryption = NO` bleibt richtig.

## Klasse: Klassencode, Briefkasten und Funk (seit 1.0.13, Ansage des Nutzers 09/2026)

- Vorgeschichte: 1.0.11 Anmeldekarten mit iCloud-Freigabe je Kind,
  1.0.12 Klassencode mit Freigabe der Zone des Kindes. Dann die Ansage:
  **„Stelle sicher, dass der Datenaustausch in allen Fällen
  funktioniert“** — Kind mit verwalteter Apple-ID, **Kind als Gast auf
  dem geteilten iPad**, Lehrkraft mit dienstlichem iPad (Schul-Apple-ID),
  **Lehrkraft mit privatem iPad**. Dazu weiter: über iCloud, nicht
  Firebase (keine Kosten, auch für andere Klassen).
- **Lehre: Eine iCloud-Freigabe (`CKShare`) trägt das nicht.** Ein Gast
  hat kein iCloud-Konto und kann nirgends schreiben; verwaltete
  Apple-IDs dürfen in der Regel nicht mit privaten teilen. Deshalb keine
  Freigaben mehr, sondern zwei Wege ohne Freigabe:
- **Briefkasten** in der **öffentlichen** CloudKit-Datenbank (`Wolke`).
  Lesen geht auf jedem Gerät, auch ohne Apple-ID; schreiben mit jeder
  Apple-ID, ob verwaltet oder privat. Alles vom Kind ist mit dem
  öffentlichen Schlüssel der Lehrkraft verschlüsselt (`Umschlag`:
  Curve25519 + ChaChaPoly, vorher mit zlib gepackt).
  - `Klasse` (Name = Code): Name, `schluessel`, `offen`,
    `einstellungen` (JSON). Schreibt die Lehrkraft.
  - `Anmeldung` `<Code>-1…60`: `umschlag` mit Kind-Id, Name, Tier. Feste
    Plätze, per Id abgeholt — **kein Suchindex nötig**.
  - `Post` `p-<Kind>-<n>`: `umschlag` (oder `datei` als Asset ab 700 KB)
    mit einem `Paket` (Profil, Sterne oder Bearbeitung samt Spuren).
    Fortlaufend nummeriert; die Lehrkraft holt je Kind ab `naechster`, bis
    eine Nummer fehlt. Ist eine Nummer belegt (App neu geladen), nimmt das
    Kind die nächste. Bleibt liegen, damit auch ein zweites Lehrergerät
    alles bekommt.
  - `Quittung` `q-<Kind>`: `vorgaben` (Genauigkeit, entfernt). Schreibt
    die Lehrkraft; liest das Kind, danach löscht es seine Anmeldung.
  - `Ich` in der **privaten** Datenbank des Kindes: Kind-Id und Code —
    nach Neuladen der App bleibt es dasselbe Kind („Wer bist du?“).
- **Funk im Klassenzimmer** (`Nahfunk`, MultipeerConnectivity über
  Bluetooth und WLAN direkt, auch wenn das Schulnetz Geräte trennt):
  Das Lehrergerät kündigt die Codes seiner Klassen an; ein Kindergerät
  mit diesem Code verbindet sich, bekommt die Klasse (**mit der
  Namensliste** — so wählt sich der Gast jede Stunde wieder aus und
  bekommt seine Sterne zurück) und schickt dieselben Pakete. Das
  Lehrergerät quittiert jedes Paket. Die Namensliste geht **nur** über
  Funk, nie in die öffentliche Datenbank.
- **Wer wann was:** Mit Apple-ID geht alles in den Briefkasten (und über
  Funk, wenn verbunden); ein Paket bleibt auf dem Kindergerät, bis es
  hochgeladen ist. Ohne Apple-ID (Gast) nur über Funk; es bleibt, bis
  das Lehrergerät es quittiert. Das Kindergerät zeigt „Alles bei der
  Lehrkraft“ oder „n Seiten warten“ — **der Gast muss Schreibspur auf dem
  Lehrergerät offen haben und in der Nähe sein, bevor er sich abmeldet**,
  sonst ist Wartendes weg (geteiltes iPad löscht Gastdaten).
- Jedes Paket hat eine Id; das Lehrergerät nimmt es genau einmal
  (`KindAblage.pakete`), egal über welchen Weg. Eine wartende ältere
  Fassung derselben Seite bzw. der Sterne fällt beim Einreihen weg.
- **Zweites Lehrergerät** (dienstlich + privat): „Auf ein weiteres
  Lehrergerät übertragen“ zeigt eine sechsstellige Zahl; das andere Gerät
  gibt sie ein und bekommt über Funk Schlüssel, Klassen und Kinder. Danach
  holt es alles aus dem Briefkasten. Der geheime Schlüssel geht nie über
  iCloud.
- Abgleich im Minutentakt, solange die App vorn ist, dazu beim Öffnen der
  Übersicht und mit „Aktualisieren“. Keine Pushes (bräuchten einen
  Suchindex in der öffentlichen Datenbank).
- **Kosten:** keine. Die öffentliche Datenbank gehört zur App; ihr
  Freikontingent wächst mit der Zahl der Nutzer. Jede Lehrkraft,
  beliebig viele Klassen und Schulen, ohne eigenen Server.
- **Lehre aus 1.0.13 → 1.0.14 (Nutzer, mit Bildschirmfoto: „die Felder
  sind grau, ich kann nichts eintragen“):** Das Namensfeld für eine neue
  Klasse stand mitten in der `Form` von „Klassen und Codes“ und nahm keine
  Eingabe an. Die Ansicht liest den Stand von `Wolke`, und der Abgleich
  (Minutentakt, Funk) setzte `status`, `icloud` und `inDerNaehe` bei jedem
  Durchlauf neu — auch mit gleichem Wert, und `@Observable` meldet jede
  Zuweisung. Jetzt: „Neue Klasse“ ist ein Knopf mit eigenem
  Eingabefenster (`alert` mit Textfeld, `klasseAnlegen(isPresented:)`),
  auch groß auf der Lehrer-Startseite; und `Wolke` setzt diese Werte nur
  noch, wenn sie sich wirklich ändern. **Merke: In Ansichten, die den
  Abgleich beobachten, keine Eingabefelder in Listen — und beobachtete
  Werte nie ohne Änderung neu zuweisen.** Nicht gemessen, welcher der
  beiden Gründe es war; beide sind behoben.
- Zwei Swift-Dateien dürfen nicht gleich heißen, auch nicht in
  verschiedenen Ordnern (`Klassencode.swift` in Model und Views: „Multiple
  commands produce …stringsdata“) — deshalb `KlassencodeAnsichten.swift`.
- **Vor TestFlight:** In der CloudKit-Konsole „Deploy Schema Changes to
  Production“ (Typen `Klasse`, `Anmeldung`, `Post`, `Quittung`, `Ich`
  entstehen beim ersten Speichern in Development).
- **Beim ersten Funk fragt iOS nach „Geräte im lokalen Netzwerk“** — auf
  jedem Gerät einmal erlauben (beim Gast: in jeder Sitzung).
- **Nicht gemessen:** Nur übersetzt, nie auf Geräten gelaufen. Zu prüfen
  mit mindestens: Lehrergerät (privat), Kind mit verwalteter Apple-ID,
  Gast ohne Apple-ID — Anmelden, Seite schreiben, in der Übersicht sehen.

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
