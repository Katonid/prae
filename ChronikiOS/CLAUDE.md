# Projekt Kapitelweise – Das Buch (Ordner/Ziel „Chronik", native iOS-App)

> Die übergreifenden Regeln (PR-Rhythmus, iOS-Pflichten, Bau in GitHub
> Actions) stehen in der `CLAUDE.md` im Wurzelverzeichnis und gelten hier
> genauso.

## Was diese App ist: eine Abwandlung des Reisebuchs

**Ab 1.0.2 ist Kapitelweise eine KOPIE des Reisebuchs** (`UrlaubstagebuchiOS/`,
Stand Reisebuch 1.0.128). Ansage des Nutzers 11/2026: „Die Reisebuch-App ist
mittlerweile perfekt für die Gestaltung von Urlaubstagebüchern. Aber diese App
hier soll ja eigentlich gar nicht so viel anders sein. Die Quelle der Daten ist
halt eine andere und es soll nicht nach Tagen, sondern nach anderen Zeiträumen
sortiert werden. … Hier habe ich das Gefühl, als ob wir wieder bei Null
anfangen würden. … Modifiziere die Reisebuch-App nur dahingehend, dass der
Import von Daten so stattfinden kann, wie ich es dir anfangs beschrieben habe."

1.0.0–1.0.1 waren ein Neubau von Grund auf (eigener Seitensatz, eigene
Vorschau). Er ist verworfen: In der Seitenübersicht ließ sich nichts machen,
eine Seite öffnete sich nicht groß, Blöcke ließen sich nicht anfassen — alles,
was das Reisebuch in 128 Fassungen gelernt hat. **Nicht wieder neu bauen.**

**Deshalb gilt `UrlaubstagebuchiOS/CLAUDE.md` hier vollständig** — jede Lehre,
jede Falle, jede Regel (Tagesdatum aus drei Zahlen, Seite und PDF aus einem
Setzer, wortlautSichern, Handarbeit, Druck …). Vor jeder Änderung dort lesen.
Wo ein Name „Tag" sagt, ist hier ein Kapitel gemeint.

**Was das Reisebuch später lernt, wird NICHT automatisch übernommen.** Die
beiden Apps sind getrennte Ordner. Eine Verbesserung dort hierher zu holen
heißt, die betreffenden Dateien zu vergleichen — die Abweichungen unten sind
klein und stehen alle mit „KAPITELWEISE" im Quelltext.

## Die Abweichungen vom Reisebuch (alle mit „KAPITELWEISE" markiert)

- **Ein „Tag" ist ein KAPITEL** (`Reisetag`, Feld `datum` = Beginn des
  Abschnitts). Das Zeitraster steht in `Reise.zeitraster`
  (`Model/Zeitraster.swift`): Einheit × Anzahl ab einem Beginn, Vorgaben
  Kalenderjahr (**Grundeinstellung**), Schuljahr (1. August), Halbjahr,
  Quartal, Monat, Woche, eigenes Raster. Gerechnet mit dem Kalender, jeder
  Kapitelbeginn vom Beginn aus (nicht vom Vorgänger).
- **Die Zuordnung geschieht an EINER Stelle: `Reise.tagIndex(fuer:)`.** Darüber
  laufen Fotoeinfuhr, Texteinfuhr, Spureinfuhr, Fernweh und „Kapitel anlegen".
  Ein neues Kapitel bekommt die Überschrift aus dem Raster („2009",
  „1. Quartal 2024"), den Zeitraum als Datumszeile (`datumstext`) und
  `karteZeigen = false` (ein Jahr mit Fotos von überall ergäbe ein Knäuel).
- **Texte sind EINTRÄGE mit Zeitstempel** (`Model/Texteintrag.swift`,
  `Reise.eintraege`). Der Kapiteltext wird daraus zusammengesetzt
  (`Reise.kapiteltext`: je Eintrag eine Kopfzeile „Überschrift – Datum", dann
  der Text). **`wortlautSichern` holt bei einem Kapitel mit Einträgen nichts
  von der Seite zurück**, sondern setzt den Text aus den Einträgen neu —
  sonst überschriebe der alte Wortlaut der Seite jeden geänderten Eintrag.
  Folge: Text wird über die Einträge bearbeitet, nicht im Textblock.
- Die Texteinfuhr aus einer Datei (`textVerteilen`) macht aus jedem
  Datumsabschnitt einen Eintrag (früher: Text eines Tages).
- `Dienste/Kapitelwerk.swift`: `eintragSichern`/`eintragLoeschen` (setzen das
  Kapitel neu, außer bei Handarbeit — dann eine Meldung), `rasterSetzen` und
  `kapitelNeuEinteilen` (Fotos nach Aufnahmetag, Einträge nach Zeitstempel;
  alle Seiten neu, Handarbeit fällt weg — steht vorher in der Oberfläche,
  „Widerrufen" holt zurück), `pdfEinfuegen`.
- **PDF-Dateien** gehen über „Bild oder PDF aus Dateien": jede PDF-Seite wird
  eine eigene, von Hand angelegte Buchseite mit der Seite als Bild (2400 px,
  ~300 dpi auf A4) im Satzspiegel. Freie Seiten an beliebiger Stelle gibt es
  über die Seitenliste des Reisebuchs (`seiteEinfuegen`).
- **Sprachliche Überarbeitung** (`Dienste/Sprachhilfe.swift`,
  `Views/EintragView.swift`): vier Arten; Apple Intelligence auf dem Gerät
  (`FoundationModels`, iOS 26, hinter `#if canImport` + `#available`, Texte in
  Stücken ≤ 1800 Zeichen) oder über einen KI-Chat per Zwischenablage. Erst
  Vorschlag, dann „Übernehmen"; die vorige Fassung bleibt (`vorfassung`).
- **Fotos aus einem ALBUM der Galerie** (ab 1.0.5, Ansage des Nutzers 11/2026):
  „Fotos aus der Mediathek…" hat neben dem Zeitraum einen Abschnitt „Alle
  Fotos eines Albums" (`Albumeinfuhr` in `Dienste/Zeitraumeinfuhr.swift`):
  eigene Alben und Favoriten, leere nicht; eingelesen über denselben Weg wie
  der Zeitraum (`Zeitraumeinfuhr.rohbild` → `fotosAufnehmen`), also mit
  Kapitel nach Aufnahmedatum. Braucht den Mediathekszugriff. Doppelt
  eingelesene Fotos findet „Doppelte Fotos" (aus dem Reisebuch).
- Oberfläche: „Kapitel" statt „Tage" in Kapitelliste und Kapitelinhalt,
  Plusmenü „Neuer Text… / Alle Texte… / Texte aus einer Datei…", „Ganzes
  Buch → Kapitel und Zeitraster…". Handbuch und Aufbau-Assistent sprechen
  noch vom Reisebuch (nicht angepasst).

## Das Lebensbuch (ab 1.0.4)

Vorlage des Nutzers 11/2026 (PDF „Simon 18", sechs Seiten, ein Buch zum 18.
Geburtstag des Sohnes): „Für jeden seiner Geburtstage die Titelseite einer
lokalen Tageszeitung … einzelne Meldungen zur Weltgeschichte an diesem Tag …
dann Fotos aus diesem Lebensjahr … relativ groß, aber doch leicht
überlappend angeordnet." Umgesetzt — alles über gewöhnliche Blöcke, also mit
allem, was das Reisebuch an Bearbeitung, Prüfung und PDF kann:

- **Zeitraster „Lebensjahr (ab Geburtstag)"** (`Zeitraster.Vorgabe.lebensjahr`,
  Beginn = Geburtsdatum, dazu `Reise.person`). Ein Kapitel heißt nach dem Jahr
  des Geburtstags („2019", nicht „2019/20"), die zweite Überschrift sagt
  „Simon wird 10 Jahre alt" (`Reise.alterszeile`), die Datumszeile ist der
  Geburtstag, die Zeitungsüberschrift „Der Tag deines 10. Geburtstags".
- **Stil „Lebensbuch"** (`Buchstil.lebensbuch`, erster in der Liste und
  Vorgabe neuer Bücher, dazu Kopfzeile an und A4 hoch): Cremepapier, Didot
  fett in Nachtblau, Gold als Akzent, Iowan kursiv, Unterschriften in
  Handschrift, Fotos mit weißem Rand, Schatten, gedreht.
- **Kopfzeile „KAPITEL 2019"** mittig, gesperrt, in der Akzentfarbe
  (`Seitenbeiwerk`) — für jeden Stil, sobald die Kopfzeile an ist.
- **Je Kapitel** (`Reisetag.zeitung`, `.zeitungstitel`, `.zeitungstext`,
  `.meldungen`, Oberfläche `KapitelseitenView`, erreichbar im Kapitelinhalt):
  die Zeitungsseite (Titelseite groß rechts, −1,2° gedreht; links Goldstrich,
  Überschrift, Text) und „Was an diesem Tag geschah" (2×2 je Seite: Bild,
  Goldbalken, Überschrift, Text). Die Bilder sind GRAFIKEN (`Foto.grafik`), aus
  Mediathek oder Dateien; aus einer PDF zählt die erste Seite.
- **Satz im Lebensbuch** (`Layoutautomat.lebensseiten`, Erweiterung am Ende von
  `Layoutautomat.swift`): Zeitung → Meldungen → Fotoseiten → Text. Fotos und Texte
  seit 1.0.10 als frei aufgeteilter Fluss (siehe unten). Trägt ein Kapitel ein
  eigenes Seitenmuster, setzt es wie im Reisebuch; Zeitung und Meldungen kommen
  in JEDEM Stil vor die Seiten.
- **Die große Jahreszahl steht NUR auf der Geburtstagsseite** (ab 1.0.6,
  Ansage des Nutzers zu Bildschirmfotos: „Die große Jahreszahl muss nicht auf
  jeder Seite stehen. Dort steht ja bereits kleiner ‚Kapitel [Jahreszahl]'.").
  Geburtstagsseite = die Zeitungsseite, sonst die erste Fotoseite. Meldungen
  und Kapiteltext tragen eine Überschrift ohne Jahr (`seitenueberschrift`),
  weitere Fotoseiten gar keine.
- **Doppelseiten-Ansicht folgt dem Produkt** (ab 1.0.6, Frage des Nutzers:
  „Das von mir eingestellte Format will eigentlich Doppelseiten. Warum werden
  trotzdem Einzelseiten angezeigt?"). Die Ansicht war eine eigene Einstellung
  (`@AppStorage("doppelseiten")`, Umschalter unten links). Verlangt
  `Druckprodukt.produkt(format.vorlage)` Doppelseiten, schaltet `ReiseView`
  beim Öffnen und beim Wechsel des Produkts auf Doppelseiten
  (`ansichtNachProdukt`); zurück geht es unten links.
- **Zeitung und Meldungen sind direkt erreichbar** (ab 1.0.7, Rückmeldung
  des Nutzers: „Ja, das ist zu versteckt."): oben im Kapitel-Menü (Knopf unten
  rechts) und im Plusmenü, je als `Blatt.kapitelseiten`. Der Kapitel-Knopf
  heißt „Kapitel 2026" statt eines Datums.
- **Fotos und Texte in EINEM Fluss, FREI aufgeteilt** (ab 1.0.10).
  Vorgeschichte: 1.0.8 gab jedem Text eine eigene Textseite („Nein! Nur der
  Text! Als Textfeld. Dessen Größe hängt vom Inhalt ab … möglichst wenig leere
  Flächen!"), 1.0.9 setzte deshalb starre Spalten („‚Spalten' finde ich starr …
  Ich möchte, dass so etwas wie im Bild weiterhin möglich ist" — mit einem
  Bild der freien, überlappenden Felder aus 1.0.4). **Weder Textseiten noch
  Spalten wieder bauen.**
  - Folge: Fotos und Einträge in ihrer Zeitfolge (`zeitfolge`: Foto nach
    `aufnahme`, Eintrag nach `zeit`, bei Gleichstand der Text zuerst, Fotos
    ohne Zeit ans Ende); ohne Einträge läuft ein freier Kapiteltext als
    letztes Stück mit. Lange Texte werden vorher geteilt (höchstens halbe
    Seitenbreite × 78 % Höhe).
  - Je Seite (`flussseiten`): Stückzahl aus dem Rhythmus 4, 3, 5, 4, 3, 5 ± 1
    (notfalls weniger). Für diese Stücke werden ALLE Teilungen der Fläche in
    zwei Hälften — nebeneinander oder übereinander, rekursiv, Reihenfolge
    bleibt — durchprobiert (`Teilung`, bei 6 Stücken 1344). Ein Foto darf
    dabei beschnitten werden (Verzug ≤ 1,45), ein Textfeld muss seinen
    GEMESSENEN Text fassen (`Textmass`, mit Vorrat je Breite); was im
    Textfeld frei bleibt, zählt als verschenkt, der Beschnitt im Mittel als
    Strafe. Unter fast gleich guten (± 0,02) wechselt die Form mit der
    Seitennummer.
  - Danach Album: Fotos 4 % größer und gedreht (`drehwinkel` × 0,7), Ebene
    steigend; Textfelder gerade, mit Goldstrich und Kopfzeile „Überschrift –
    Datum" (fett). Simuliert (Python, je 200 Zufallsseiten): für 3–6 Fotos
    findet sich immer eine Teilung, für 2 in gut der Hälfte der Fälle.
- **Nachladen ohne Doppel und Erinnerungen zum Foto** (ab 1.0.11, Ansage des
  Nutzers 11/2026: „regelmäßig in ein bestehendes Projekt neue Fotos
  hineinladen … Vorhandene Fotos werden automatisch nicht importiert. …
  auf ein Foto tippen und … einen Text einsprechen, der dann neben dieses Foto
  sortiert wird").
  - `fotosAufnehmen` überspringt Vorhandenes: gleicher Mediathekseintrag
    (`Foto.mediathek`, ab 1.0.11 gemerkt) ODER gleiche Aufnahmesekunde und
    gleiche Maße (`fingerabdruck`, für ältere Fotos und Dateien). Fotos in der
    Ablage zählen mit. Der Bericht nennt die Zahl.
  - Ist ein Foto gewählt, steht unten „Erinnerung einsprechen" (nicht bei
    Grafiken). Es öffnet `EintragView` mit dem Foto oben und startet das Diktat
    sofort (`sofortDiktieren`). Der Eintrag trägt `Texteintrag.foto` und die
    Aufnahmezeit + 1 s (fürs Kapitel). Im Satz steht er DIREKT hinter seinem
    Foto (`zeitfolge`), ohne Datumszeile (nur Überschrift, wenn eine da ist),
    und wird nicht von ihm auf die nächste Seite getrennt (Strafe 0,5 in
    `flussseiten`).
- **Automatische Textpflege, „fertig" schützt** (ab 1.0.12, Ansage des
  Nutzers 11/2026: „Texte automatisch mittels KI korrigieren … offensichtliche
  Tippfehler und vor allem … doppelte Leerzeichen oder Leerzeichenfehler bei
  Satzzeichen … automatisch … einen bereits überarbeiteten Text als fertig
  markieren, sodass er bei erneuten Prüfungen nicht mehr berücksichtigt
  wird"). `Dienste/Textpflege.swift`: Stufe 1 feste Regeln (`aufraeumen`:
  Mehrfach-Leerzeichen, Leerzeichen vor/nach Satzzeichen und Klammern,
  Leerzeichen nach , ; ! ? und nach Wortende-Punkt vor Großbuchstaben — NICHT
  in „z.B.", „3.5", Adressen; doppelte Kommas/Punkte, Leerzeilen), unter Linux
  an Beispielsätzen geprüft. Stufe 2 Apple Intelligence „Nur korrigieren",
  Ergebnis VERWORFEN bei mehr als 10 % Längenänderung. Ausgelöst beim Sichern
  eines Eintrags (`eintragSichern`), nach der Texteinfuhr und mit „Alle Texte
  prüfen" in der Textliste (`texteAutomatischPruefen`). Übersprungen: `fertig`
  (Schalter im Editor, Wischgeste in der Liste, Siegel in der Zeile) und
  `geprueft == text` (seit der letzten Prüfung unverändert; auch nach
  bewusstem Wechsel zur anderen Fassung). Die alte Fassung landet in
  `vorfassung`.
- **Sicherungsdateien eines oder aller Bücher** (ab 1.0.13, Ansage des
  Nutzers 11/2026). Im Regal: Knopf oben rechts „Alle Bücher sichern", je
  Buch Wischgeste nach rechts „Sichern" und Kontextmenü. `RegalView.sichern`
  schreibt Buch für Buch eine `.kapitelweise`-Datei (`Buchdatei.schreiben`,
  abseits des Hauptfadens, abbrechbar über `Haltesignal`) und bietet alle über
  das Teilen-Blatt an („In Dateien sichern"). Eingelesen wird eine Datei wie
  im Reisebuch (antippen/öffnen). Im offenen Buch bleibt „Buch als Datei
  sichern…" unter „Mehr". Die Textliste zeigt bei geprüften, unveränderten
  Texten ein graues Häkchen (die Prüfung überspringt sie von selbst, seit
  1.0.12). Abgleich über iCloud: Einstellungen im Regal → „Über iCloud
  abgleichen", je Gerät einschalten (aus dem Reisebuch, Vorgabe aus).
- **„Ab der gewählten Seite neu verteilen"** (ab 1.0.14, Ansage des Nutzers
  11/2026: nach Handarbeit an einer Seite — Foto verkleinert und Text daneben,
  oder Foto vergrößert — sollen die folgenden Fotos neu angeordnet bzw. auf
  spätere Seiten verteilt werden). Seine Wahl: **auf Knopfdruck** (Kapitel-Menü),
  und **frei gewordener Platz auf der bearbeiteten Seite bleibt frei**.
  `Reisewerk.abHierNeuVerteilen` (Kapitelwerk): Auf der gewählten Seite
  fliegen Fotos heraus, die zu mehr als 50 % von darüberliegenden Blöcken
  verdeckt sind oder zu mehr als 25 % außerhalb der Seite liegen (samt
  Bildunterschrift). Fest bleiben die Seiten bis zur gewählten und jede
  spätere Seite mit Handarbeit; der Rest des Kapitels (Fotos nach Kennung,
  Texte nach Wortlaut, die auf keiner festen Seite stehen) wird mit
  `Layoutautomat.restseiten` neu gesetzt und HINTER die gewählte Seite
  gestellt, spätere Handarbeitsseiten folgen danach. Nur im Stil Lebensbuch.
  Ein Foto eine Seite zurück holt das Blockmenü des Reisebuchs („Eine Seite
  zurück"); seit 1.0.14 geht dabei die Bildunterschrift mit
  (`blockVerschieben`).
- **Vorwort** (ab 1.0.15, Ansage des Nutzers 11/2026: „einen einleitenden
  Text dem eigentlichen Chronikbuch voranstellen … persönliche Worte …
  mindestens 7 Seiten … einzelne Fotos … zweispaltig … dass der Text sie
  umfließt"). Ein besonderes Kapitel (`Reisetag.vorwort`, Datum 1.1.1900,
  immer vorn; `Reise.vorwortIndex`), bearbeitet in `Views/VorwortView.swift`
  (Plusmenü und „Ganzes Buch → Vorwort…": Überschrift, Text aus der
  Zwischenablage, Aufräumen nach Textpflege, Fotos aus Mediathek/Dateien in
  fester Reihenfolge). Es zählt nicht zum Zeitraum, `kapitelNeuEinteilen`
  lässt es stehen, die Kopfzeile sagt seine Überschrift. Satz:
  `Layoutautomat.vorwortseiten` — zwei Spalten, Blocksatz mit Trennung, Fotos
  gleichmäßig auf die geschätzten Seiten verteilt, je eins in einer Spalte
  oben oder unten (≤ 42 % der Höhe, Lage wechselt reihum), der Text füllt die
  freien Stücke jeder Spalte darüber/darunter (`Textmass.teilen`). Übrige
  Fotos nach dem Text auf eine Albumseite.
- **Vorwort wie in einer Textverarbeitung** (ab 1.0.16, Ansage des Nutzers
  11/2026: „dass die App sich an dieser Stelle wirklich wie eine
  Textverarbeitung verhält … ein Foto, das ich irgendwo einfüge oder
  hinschiebe, bewirkt, dass der Text es umfließt"). Nach JEDER Änderung an
  einer Vorwortseite fließt der Text neu (`Reisewerk.vorwortNachfuehren` →
  `Layoutautomat.vorwortUmflossen`): beim Loslassen nach Schieben, Drehen,
  Größe ändern (`SeitenflaecheView.gestenendeAufraeumen`, nicht je
  Bildpunkt — CoreText-Messung), nach Einfügen, Löschen, Kopieren,
  Verschieben auf eine andere Seite, Bild einsetzen (je ein `defer` in den
  Funktionen von `Reisewerk`), nach Textänderung auf der Seite
  (`textSchreiben` → `vorwortWortlaut` ersetzt das Stück im Vorworttext).
  Alles außer dem Fließtext bleibt stehen und wird umflossen. Fließtext =
  `.text`-Kasten höchstens eine Spalte breit, dessen Wortlaut im Vorworttext
  steht (`imVorwortfluss`); die Überschrift und eigene Kästen bleiben.
  Umflossen wird „rechteckig": jede Spalte in Bänder an den Kanten der
  Hindernisse, je Band das breiteste freie Stück (mindestens 38 % der
  Spalte), so läuft der Text auch NEBEN einem schmalen oder überstehenden
  Foto. Seiten kommen dazu oder fallen am Ende weg; die Kennungen der
  Textkästen werden der Reihe nach wiederverwendet (gleicher Stand → gleiche
  Seiten). `wortlautSichern` lässt das Vorwort aus (`fliesstexte` läse über
  beide Spalten quer und nähme die Überschrift mit — mit 1.0.15 hätte ein
  zweites Sichern im Vorwort-Blatt den neuen Text so überschrieben).
  Erneutes Sichern im Vorwort-Blatt lässt die Fotos stehen, neue kommen auf
  die Seite mit den wenigsten Fotos (`vorwortFoto`). Kapitel-Menü:
  „Vorwort bearbeiten…", „Text neu umfließen lassen" (nach Änderungen im
  Inspektor). „Automatisch neu verteilen" setzt alles neu.
- **Eigene Schrift fürs Vorwort** (ab 1.0.17, Ansage des Nutzers 11/2026:
  „Ich möchte die Schriftart des Vorwortes auch einstellen können").
  `Reisetag.vorwortschrift: Schriftbild?`, `nil` = Fließtext des Buches,
  gerade, Blocksatz, Trennung (`Layoutautomat.vorwortbild(tag)`, von
  `vorwortseiten` und `vorwortUmflossen` benutzt). Im Vorwort-Blatt Abschnitt
  „Schrift": Schalter „Eigene Schrift", Schriftart (`SchriftwahlView`, also
  auch selbst installierte), Größe, Zeilen- und Absatzabstand, Ausrichtung,
  kursiv, Trennung, Farbe, Probe in Druckgröße. Beim Sichern fließt der Text
  neu, die Fotos bleiben stehen. Die Überschrift behält die Titelschrift.
- **Fotos im Vorwort-Blatt über `photosPicker`** (ab 1.0.17, gemeldet
  11/2026: „Fotos, die ich auswähle, werden leider nicht ins Vorwort
  eingefügt"). Vorher `Fotowahl` (UIKit) in einem `.sheet`: Der Wähler
  schließt sich selbst (`picker.dismiss`), dazu `mediathek = false` — in einem
  Blatt IM Blatt kann der zweite Befehl das Vorwort-Blatt mitschließen, und
  mit ihm geht die Fotoliste verloren. **Ursache nicht auf einem Gerät
  bestätigt**, nur aus dem Quelltext geschlossen. Dieselbe Bauweise steht noch
  in `KapitelseitenView` (Zeitung, Meldungen; dort je ein Bild) — klemmt es
  dort auch, genauso umbauen. Nach dem Hinzufügen sagt ein Hinweis, dass erst
  „Sichern" die Fotos ins Buch bringt.
- **Textänderung im Vorwort-Blatt kam nicht an** (behoben 1.0.17, gemeldet
  11/2026: „Wenn ich dies im Menüfenster tu, dann werden die Änderungen nicht
  übernommen"). `imVorwortfluss` erkannte Fließtext daran, dass sein
  Wortlaut im Vorworttext steht — nach dem Ändern im Blatt stand er dort
  nicht mehr, die alten Kästen galten als eigene Kästen und blieben, der neue
  Text floss um sie herum. Jetzt: `vorwortNachfuehren(_:frueher:)` prüft auch
  den alten Text, und jeder Kasten mit `vonHand == false` zählt als Fließtext
  (eigene Kästen tragen `vonHand`, `blockHinzufuegen`) — das räumt auch Reste
  aus 1.0.16 weg.
- **Schrift und Absätze immer sichtbar** (ab 1.0.17, Ansage des Nutzers
  11/2026: „Schriftfarbe und Absatzformatierungen … nach jedem Absatz eine
  Reihenhöhe Abstand … Das möchte ich nicht"). Kein Schalter „Eigene Schrift"
  mehr: gleich der Buchschrift → `nil` gesichert. Abschnitt „Absätze":
  Ausrichtung, Zeilenabstand, Abstand nach jedem Absatz (0–24 pt),
  „Leerzeilen zwischen Absätzen behalten" (Vorgabe AUS: beim Sichern werden
  Leerzeilen zu einem Zeilenwechsel, `VorwortView.ohneLeerzeilen`, unter
  Linux geprüft). Die Zeile Abstand war eine leere Zeile im eingefügten
  Text — im Satz ein leerer Absatz. Einen Erstzeileneinzug gibt es nicht
  (`Schriftbild` kennt keinen; bräuchte `Seitensatz` und Abweichung).
- **Schriftwahl des Vorworts als eigenes Blatt** (ab 1.0.18, gemeldet
  11/2026: „Die App stürzt ab, wenn ich eine andere Schriftart für das
  Vorwort wählen möchte."). **Ursache nicht gefunden** — kein Absturzbericht,
  aus dem Quelltext nicht abzulesen. 1.0.17 schob `SchriftwahlView` per
  `NavigationLink` in den Stapel des Vorwort-Blatts, direkt an `schrift`
  gebunden (jede Wahl zeichnete das Blatt mit dem langen Textfeld neu).
  Jetzt wie im `BlockInspektor`: eigenes Blatt mit eigenem Stapel, Entwurf
  (`schriftEntwurf`), übernommen mit „Fertig". Dazu `Absturzspur`-Marken
  („Vorwort: Schriftwahl öffnen …", „… übernehmen …"): Stürzt es wieder ab,
  nennt die App beim nächsten Start den Schritt und den freien Speicher —
  danach fragen, bevor weiter geraten wird.
- **Der Wähler von iOS schloss sich doppelt** (behoben 1.0.19, gemeldet
  11/2026: „Offenbar ist es immer wieder ein Problem, tatsächlich eine
  Schrift auszuwählen, die ich per Profil auf dem Gerät installiert habe …
  wann immer ich eine solche Schrift auswählen möchte, funktioniert es
  nicht."). `Schriftwahl` (`Views/Waehler.swift`, aus dem Reisebuch) rief im
  Delegaten `waehler.dismiss(animated:)`, und `SchriftwahlView` schloss
  dasselbe Blatt zusätzlich über `waehlerOffen = false`. Der zweite Befehl
  traf das Blatt DARUNTER — die Schriftwahl oder gleich das Vorwort-Blatt —,
  und die eben gewählte Schrift ging mit ihm verloren (im Vorwort in 1.0.17
  wohl auch der Absturz). In der Typografie fiel es nicht auf, weil die Wahl
  dort sofort ins Buch schreibt. Jetzt schließt NUR SwiftUI; die
  Schriftwahl im Vorwort ist direkt an `schrift.familie` gebunden (der
  Entwurf aus 1.0.18 ist weg). **Dieselbe Bauweise steht noch im
  Reisebuch** (`UrlaubstagebuchiOS/Urlaubstagebuch/Views/Waehler.swift`) und
  in `Fotowahl` hier (dort schließen `GrafikEinfuehrView` und
  `FotoeinfuhrView` NICHT selbst — nur `KapitelseitenView` doppelt). **Nicht
  gemessen:** auf einem Gerät.
- **Vorwortfotos der Zeit nach** (ab 1.0.19, Wunsch des Nutzers 11/2026:
  „dass die eingefügten Fotos im Vorwort in chronologischer Reihenfolge
  erscheinen"). `grafikAblegen` merkt jetzt `Foto.aufnahme` aus dem
  Bildbefund (OHNE `tagesschluessel` — eine Grafik gehört keinem Kapitel);
  ältere Vorwortfotos lesen sie beim Öffnen des Vorwort-Blatts einmal aus der
  abgelegten Datei nach. Die Liste im Blatt wird nach jedem Hinzufügen und
  beim Öffnen sortiert (`VorwortView.zeitlichOrdnen`, ohne Zeit ans Ende,
  sonst stabil). Beim Sichern bleiben stehende Fotos, wo sie sind; ein neues
  kommt zwischen die Seite seines Vorgängers und die seines Nachfolgers in
  der Liste, dort auf die mit den wenigsten Fotos (`vorwortSichern`). Alles
  der Reihe nach von vorn: Kapitel-Menü → „Automatisch neu verteilen".
- **Foto und Erinnerung sind EIN Stück** (ab 1.0.20, Ansage des Nutzers
  11/2026: „Der Text soll auf jeden Fall mit dem Foto verbunden werden, also
  bei Verschiebungen immer an ihm haften bleiben … links oder rechts daneben
  … oder darunter … Es muss aber jeweils klar sein, zu welchem Foto der Text
  gehört … Ein Text aus einem Satz bestehend darf nicht dazu führen, dass ein
  anderes Foto … auf die nächste Seite wandert und eine Riesenlücke
  hinterlässt."). Bis 1.0.19 war eine Erinnerung ein eigenes Feld der
  Aufteilung: Ein Satz kostete ein Feld und verdrängte ein Bild.
  - `flussseiten`: Eine Erinnerung (`Fluss.text(zu:)`) direkt hinter ihrem
    Foto wird an dessen `Stueck` gehängt (`notizKopf`/`notizRumpf`), solange
    sie bei halber Breite höchstens 36 % der Satzhöhe braucht; sonst bleibt
    sie ein eigenes Feld (wie bisher, mit Trennstrafe). Das Stück zählt in
    der Aufteilung mit dem Seitenverhältnis von Foto PLUS Text.
  - `notizteilung`: Im Feld gibt das Foto der Erinnerung einen Streifen ab —
    darunter (wenn der Text < halbe Feldhöhe braucht) oder daneben in 30/38/46 %
    der Breite, und zwar zur AUSSENKANTE der Seite (die Nachbarbilder greifen
    im Album über). Gewählt wird der kleinste Verzug des Fotos (≤ 1,45 wie
    sonst) plus frei bleibender Textstreifen. Daneben steht der Text unten
    bündig zum Bild, links davon rechtsbündig.
  - `notizbloecke`: Foto 3 % größer, halbe Drehung; Text ohne Goldstrich,
    Ebene + 50 (über übergreifenden Nachbarn), mit dem Bild mitgedreht
    (`angelegt`) und mit `Block.zuFoto` = Kennung des Fotos.
  - **`Block.zuFoto` hält zusammen** (`Reisewerk.anhaengsel`: Unterschrift
    UND Erinnerung): `schiebeMitUnterschrift`, `drehe`, `blockVerschieben`,
    `blockAufNeueSeite` nehmen alles mit; `blockLoeschen` eines Fotos nimmt
    die Erinnerung von der Seite (der Eintrag bleibt); `abHierNeuVerteilen`
    zählt sie nicht als Verdeckung und nimmt sie mit dem Foto heraus.
  - Auf der Seite geänderte Erinnerung geht in den EINTRAG zurück
    (`textSchreiben` → `erinnerungSchreiben`, Kapitelwerk) — sonst setzte das
    nächste Neuanordnen den alten Wortlaut ein.
  - **Nicht gemessen:** wie die Felder aussehen; die Varianten sind
    gerechnet, nicht angesehen.
- **Einzelne Wörter formatieren** (ab 1.0.20, Ansage des Nutzers 11/2026:
  „in allen Bereichen … einzelne Wörter oder Abschnitte anders zu
  formatieren. Also Schriftgröße, Schriftart, fett oder unterstrichen").
  - **Gespeichert wird Text mit Marken** (`Model/Auszeichnung.swift`):
    `[b]…[/b]`, `[i]…[/i]`, `[u]…[/u]`, `[gr=14]…[/gr]`,
    `[schrift=Hoefler+Text]…[/schrift]` (`+` statt Leerzeichen — das Teilen
    sucht rückwärts ein Leerzeichen und darf nie in einer Marke landen).
    Kein zweites Format im Modell: Jeder Weg (Einträge, Vorwort, Teilen,
    Wiederfinden am Wortlaut, Buchdatei, iCloud) rechnet mit Text.
  - Gesetzt an EINER Stelle: `Schriftbild.gesetzt` → `Auszeichnung.gesetzt`
    (Schrift je Lauf, Unterstreichung, größere Zeilenhöhe im Absatz eines
    größeren Wortes). Damit messen, teilen und zeichnen Seite und PDF
    gleich. `Textmass.passtBis` rechnet die sichtbare Länge über
    `Zerlegt.quelle` in den Urtext zurück und nie in eine Marke
    (`ausserhalbMarke`); `teilenMitArt` schließt offene Marken im Kopf und
    öffnet sie im Rest wieder (`ausgleichen`) — unter Linux geprüft.
  - **Text mit Marken wird nicht getrennt** (Silbentrennung rechnet mit einer
    Schrift; mit fetten/größeren Wörtern stünden Striche mitten in der
    Zeile). Betrifft nur Kästen, in denen eine Marke steht.
  - **Unterstrichen zeichnet CoreText nicht** — `Seitensatz.unterstreichen`
    zieht die Linie selbst (Lage/Stärke aus der Schrift des Laufs).
  - Bearbeiten: `Views/Formatfeld.swift` — `Formatwerkzeug` (Leiste über der
    Tastatur: Fett, Kursiv, Unterstrichen, kleiner, größer, Schrift mit den
    Schriften des Buches und „Weitere Schriften…" = Wähler von iOS, von
    UIKit dargestellt, schließt sich selbst EINMAL; „Normal"; dazu
    `allowsEditingTextAttributes`). Nach jeder Änderung zurück in Marken
    (`auszeichnen`, verglichen mit der Grundschrift des Blocks) und aus
    ihnen neu gezeigt. Eingebaut in den Text auf der Seite
    (`TextflaecheBruecke`), den Eintrag (`EintragView`), das Vorwort und den
    Textkasten im Inspektor (`Formatfeld`).
  - Texte mit Marken gehen NICHT ans Sprachmodell (`Textpflege.pruefen`).
    Listen zeigen den Text ohne Marken (`Auszeichnung.ohne`).
  - **Nicht gemessen:** auf einem Gerät; ob iOS bei „Format" im
    Bearbeiten-Menü dieselben Attribute setzt, die `auszeichnen` erkennt.
- **Erinnerung erscheint sofort, lässt sich direkt bearbeiten und löschen**
  (ab 1.0.21, gemeldet 11/2026: Erinnerung zu einem Foto am unteren
  Seitenrand eingesprochen — nichts zu sehen, ein zweites Mal — wieder
  nichts; erst „Alles neu verteilen" zeigte beide; einen Textkasten gelöscht,
  nach erneutem Neuverteilen waren beide wieder da; „Ich brauche eine direkte
  Zugriffsmöglichkeit auf den eingesprochenen Text.").
  - Ursache 1: `kapitelAuffrischen` setzt ein Kapitel mit Handarbeit NICHT
    neu (nur Meldung). Jetzt: `eintragSichern`/`eintragLoeschen` rufen bei
    einer Erinnerung in einem Kapitel mit Handarbeit
    `erinnerungEinhaengen(fotoID)` — nur dieses Foto wird umgebaut: Feld =
    Foto ∪ bisherige Erinnerung (so schrumpft das Foto bei wiederholtem
    Aufruf nicht), darin `Layoutautomat.fotoMitNotiz` (drei Lagen wie im
    Fluss plus 55 % daneben; passt nichts, unter das Feld). Das Foto behält
    Ausschnitt, Drehung, Wirkung; alles neu Gesetzte ist `vonHand`.
  - Ursache 2: `blockLoeschen` nahm nur den Kasten weg, der Eintrag blieb.
    Jetzt löscht das Löschen eines Erinnerungskastens (`zuFoto`) den/die
    Einträge, deren Text darin steht (oder deren Überschrift er ist); sonst
    alle des Fotos. „Zurück" holt sie wieder (`merken` vorher).
  - Zugriff: Foto gewählt → unten „Erinnerungen (n)" (Menü: jede Erinnerung
    zum Bearbeiten, „Weitere Erinnerung einsprechen"); Erinnerungstext
    gewählt → „Erinnerung bearbeiten". Beides öffnet `EintragView` über
    `Blatt.eintrag(id)` (dort ändern, nachdiktieren, löschen). Daneben
    weiter Plusmenü → „Alle Texte…".
- **Ein gelöschtes Foto kommt nicht zurück** (ab 1.0.22, gemeldet 11/2026:
  „Wenn ich ein Foto lösche, dann bleibt es im Hintergrund trotzdem immer
  noch gespeichert. Wenn ich auf Seiten neu verteilen gehe, wird dieses Foto
  wieder eingefügt."). `blockLoeschen` nahm nur den Block; das Foto blieb in
  `tag.fotos`, und daraus setzt jedes Neuverteilen. Jetzt: Steht das Foto
  danach auf keiner Seite des Kapitels mehr, geht es auch aus `tag.fotos` —
  in die Fotoablage („Fotos ohne Kapitel", `Reise.heimatlose`, Plusmenü →
  Fotoablage), NICHT von der Platte; von dort lässt es sich einem Kapitel
  zurückgeben, „Zurück" holt es sofort. Eine Kopie auf einer anderen Seite
  hält es im Kapitel. Die Bildunterschrift geht mit dem Foto von der Seite.
  `AblageView` spricht von „Kapitel" statt „Tag".
- **Kein aufgeblasenes Kapitelende** (ab 1.0.22, Befund des Nutzers
  11/2026: „Ich habe den Eindruck, dass [ein neues Kapitel] immer nur zu
  Beginn einer Doppelseite beginnen kann. Daraus resultiert, dass … Fotos am
  Ende des vorangegangenen Kapitels unsinnig groß gezogen werden müssen.").
  **Ein Kapitel beginnt NICHT an einer Doppelseite** — es beginnt immer auf
  der nächsten Seite, links oder rechts; nirgends im Quelltext wird auf
  einen Bogen ausgerichtet (geprüft: `doppelseiten`, `Bogenlage`,
  `sonderseiten`). Was er sah: Jede Seite eines Kapitels gehört nur ihm, und
  `flussseiten` füllt die letzte immer ganz — ein oder zwei übrige Fotos
  wurden zum Poster. Jetzt: Strafe 0,3/0,15, wenn nach einer Seite nur 1/2
  Stücke übrig blieben (lieber eines weniger oder alle); und hat die letzte
  Seite nur 1–2 Stücke, bekommen sie die oberen 60 % (sonst 80 %) der Fläche.
  **Zwei Kapitel auf EINER Seite gibt es nicht** — eine Seite gehört einem
  `Reisetag`; geteilte Seiten hießen, Neuverteilen, Handarbeit, Kopfzeile und
  „Ab hier neu verteilen" über Kapitelgrenzen hinweg zu bauen.
- **„Ab hier neu aufbauen" ab einem Foto oder Text** (ab 1.0.23, Ansage des
  Nutzers 11/2026: „wenn ich Fotos auf einer Seite lösche … eine schnelle
  Möglichkeit …, die folgenden Fotos hochzuziehen, ohne dass ich erst mühsam
  von der folgenden Seite zurück verschieben muss … ein Foto markiere oder
  eine Textstelle und dann … ab hier neu aufbauen"). Unterschied zu „Ab der
  gewählten Seite neu verteilen" (1.0.14): dort bleibt frei gewordener Platz
  FREI, hier wird er gefüllt. `Reisewerk.abHierNeuAufbauen(block:)`
  (Kapitelwerk): Rang jedes Blocks in der Zeitfolge des Kapitels (Foto,
  Erinnerung und Unterschrift über ihr Foto, Text über seinen Wortlaut in
  einem Fluss-Text). Auf der Seite gehen alle Blöcke mit Rang ≥ dem gewählten
  weg (samt Goldstrich über einem Textfeld); fest sind frühere Seiten, das
  Bleibende hier, spätere `vonHand`-Seiten und alles mit kleinerem Rang. Der
  Rest wird mit `restseiten(…, ersteFlaeche:)` gesetzt: zuerst in den freien
  Streifen UNTER dem untersten bleibenden Block (volle Breite, ab 70 pt Höhe;
  `flussseiten` gibt eine leere erste Seite zurück, wenn dort nichts ohne
  starken Beschnitt passt), dann Seite für Seite. Knopf unten „Ab hier neu
  aufbauen" bei gewähltem Foto/Text (Lebensbuch, nicht Vorwort) und im
  Kapitel-Menü. **Nicht gemessen:** auf einem Gerät; der freie Rest ist nur
  der Streifen unten — Lücken neben bleibenden Blöcken werden nicht gefüllt.
- **Text auf der Seite ändern wird gespeichert** (ab 1.0.24, gemeldet
  11/2026: „Ich suche nach wie vor nach der Bearbeitungsfunktion für einen
  Text. Vor allem möchte ich, dass diese Bearbeitung auch intern gespeichert
  wird. Nicht, dass beim Neuaufbau einer Seite plötzlich wieder der alte Text
  dort steht."). In einem Kapitel mit Einträgen setzt `wortlautSichern` den
  Text beim Neusetzen aus den EINTRÄGEN — eine Änderung nur im Kasten ging
  verloren. Jetzt `textSchreiben` → `textInEintrag` (Kapitelwerk): Das
  Kastenstück wird im Eintragstext ersetzt; ist der Kasten die Kopfzeile,
  wird der Titel gesetzt (ohne „ – Datum"). Findet sich kein Eintrag, sagt
  eine Meldung, dass die Änderung nur auf der Seite steht. Dazu unten
  „Text bearbeiten" bei gewähltem Textkasten (`eintrag(zuText:)` →
  `Blatt.eintrag`).
- **Wozu gehört eine Erinnerung?** (ab 1.0.24, Frage des Nutzers: „kann er …
  auch neben einem Bild stehen? Wenn ja … sicherstellen …, zu welchem Bild
  der Text gehört."). Ja: darunter ODER daneben (zur Außenkante). Jetzt ein
  Strich in der Akzentfarbe in der Fuge zwischen Text und Bild (daneben
  senkrecht über die Texthöhe, darunter kurz waagerecht über dem
  Textanfang), `.linie` mit `zuFoto` — wandert mit. Das Foto mit Erinnerung
  greift nicht mehr über (Zugabe 0), und der weiße Fotorand zählt zur Fuge
  (`notizluft`), sonst läge er auf dem Text.
- **Eingabefeld lesbar, Textliste vollständig** (ab 1.0.25, gemeldet
  11/2026 mit Bildschirmfoto: „Der Text ist leider nicht lesbar. Und in der
  Gesamtübersicht aller Texte werden immer nur 2 Reihen angezeigt."). Das
  `Formatfeld` (1.0.20) zeigte die Buchschrift in Druckfarbe und -größe —
  Nachtblau 11 pt auf dunklem Grund. Jetzt `Formatwerkzeug.lesbar` (nur in
  Formularen, nicht auf der Seite): Farbe `UIColor.label`, mindestens 16 pt;
  `massstab` vergrößert Größenmarken beim Zeigen und rechnet sie beim
  Zurückschreiben zurück (`Auszeichnung.gesetzt/auszeichnen(massstab:)`) —
  gespeichert wird unverändert. Die Textliste („Alle Texte") zeigt den ganzen
  Text statt zwei Zeilen.
- **Fett bleibt fett** (ab 1.0.26, gemeldet 11/2026: „Das wird dann aber
  automatisch wieder zurückgeändert."). Die Leiste setzte Fett über
  `fontDescriptor.withSymbolicTraits` und las es beim Zurückschreiben aus
  der Schrift. Eine auf einen Schnitt festgelegte Buchschrift (Lebensbuch:
  Iowan kursiv) bekam von iOS stillschweigend DIESELBE Schrift zurück — das
  Fett war nach dem Zurückschreiben weg. Jetzt eigene Merkmale am Text
  (`NSAttributedString.Key.kwFett/kwKursiv/kwSchrift`, `Auszeichnung`):
  `gesetzt` setzt sie aus den Marken, `auszeichnen` liest zuerst sie, dann
  die Schrift; die Leiste schaltet sie um. Hat eine Familie keinen fetten
  Schnitt, wird die Kontur verstärkt (`strokeWidth` −3, Seite und PDF).
  Das „Format" von iOS (`allowsEditingTextAttributes`) ist AUS — es kennt
  die Merkmale nicht, ein Wort ließe sich damit nicht wieder entfetten.
- **Vorwort: weniger Abstand um Fotos, einstellbar** (ab 1.0.26, gemeldet
  11/2026: „Gerade im Vorwort wird bei einem Foto ringsum zu viel Abstand zum
  Text gelassen."). Bis 1.0.25 rund um den Umriss 1,5 Fugen + 2 pt (gut
  6 mm, plus weißer Rand), dazu Fotos MITTIG in der Spalte (zwei schmale
  Streifen daneben, beide leer) und Text neben Fotos erst ab 38 % der
  Spaltenbreite. Jetzt: `Reisetag.vorwortabstand` (pt, Vorgabe 6, Regler
  0–24 im Vorwort-Blatt unter „Absätze", `Layoutautomat.vorwortabstand`),
  neue Fotos an der AUSSENKANTE ihrer Spalte (`vorwortseiten`,
  `vorwortFoto`), Text daneben ab 28 % / 50 pt. Stehende Fotos bleiben, wo
  sie sind; enger wird es beim nächsten Umfließen (Sichern im Blatt oder
  „Text neu umfließen lassen").
- **Zeilenabstand bis 0,5** (ab 1.0.27, gemeldet 11/2026: „einen exotischen
  Zeichensatz, bei dem selbst bei geringstmöglichem Zeilenabstand die Reihen
  noch zu weit auseinander sind"). Alle drei Regler (Typografie, Inspektor
  „Schrift an dieser Stelle", Vorwort) jetzt 0,5–2,6 in Schritten von 0,01
  (vorher 0,9 bzw. 1,0 als Untergrenze). Der Wert ist ein Faktor auf die
  Schriftgröße und wird als feste Zeilenhöhe gesetzt (`Schriftbild.attribute`,
  min = max) — darunter überlappen sich die Zeilen, das ist dann gewollt.
- **Bedienung nach dem Gegenstand, Funktionssuche** (ab 1.0.28, Ansage des
  Nutzers 11/2026: „die Bedienung der App [wird] immer unübersichtlicher …
  Funktionen, von denen ich weiß, dass sie vorhanden sind, [springen] mir
  nicht auf den ersten Blick entgegen … Dann frage ich dich und bin
  überrascht, in welchem Menü sie gelandet sind."). **Die Regel für jede neue
  Funktion:**
  - Plus (`hinzufuegenMenue`) = HINZUFÜGEN: Abschnitte „Texte" (Neuer Text,
    Text vor dem gewählten Foto, Alle Texte, Texte aus Datei), „Fotos"
    (Mediathek, Dateien, Fotoablage), „Auf die gewählte Seite"; Reisebuch-
    Erbe (Buch aufbauen, Reisespur, Fernweh) unter „Weitere Quellen".
  - „Ganzes Buch" (`gestaltenMenue`) = gilt für das ganze Buch: „Aufbau"
    (Vorwort, Kapitel und Zeitraster, Titel/Umschlag), „Aussehen" (Karten,
    Wetter, Vorlagen unter „Weitere"), „Neu verteilen" (Alles neu verteilen —
    bis 1.0.27 unter „Mehr"!), „Druck".
  - Kapitel-Menü unten rechts (`tagMenue`) = dieses Kapitel: „Inhalt",
    „Neu verteilen" (gesperrt → ausgegraut), „Kapitel" (Sperre, Seiten
    setzen, Seiten, Seite anfügen, Reisepunkte). Zeitung/Vorwort nicht mehr
    im Plusmenü.
  - „Mehr" = Prüfen, Ausgeben, Sichern, Hilfe.
  - **Funktionssuche** (`Views/BefehleView.swift`, Lupe oben, `Blatt.befehle`):
    Suchfeld über ~45 Funktionen in Alltagswörtern („fett", „aufrücken",
    „sperren", „zurückholen"); jede Zeile nennt, wo die Funktion sonst steht,
    und führt sie aus, wo es geht (sonst Weg als Hinweis, etwa bei Gesten).
    **Neue Funktionen dort eintragen.** Umschalten auf ein anderes Blatt: erst
    schließen, nach 0,45 s öffnen.
  - Unten bei gewähltem Foto zusätzlich „Text davor" (`Blatt.textVor`,
    `EintragView.textVor`: freier Eintrag 60 s vor der Aufnahme, kein
    `foto` — steht als eigenes Feld VOR der Bildgruppe; Antwort auf „Texte …
    auf einen ganzen Abschnitt von Bildern").
- **Kapitel sperren** (ab 1.0.28, Ansage des Nutzers 11/2026: „ein Kapitel,
  nachdem ich es fertig bearbeitet habe, so sperren können, dass es nicht
  versehentlich noch einmal zurückgesetzt [wird]"). `Reisetag.gesperrt`,
  Kapitel-Menü „Kapitel sperren (fertig)" / „Sperre aufheben"
  (`sperreUmschalten`), Schloss im Kapitel-Knopf und in der Kapitelliste.
  Geprüft in `seitenNeuSetzen` — JEDER Weg zum Neusetzen läuft dort durch
  (Neuanordnen, Alles neu verteilen, Stil, Muster, Wetter, Doppelte …) —,
  dazu Meldung in `neuAnordnen(erzwingen:)`, `abHierNeuVerteilen`,
  `abHierNeuAufbauen`; `kapitelNeuEinteilen` verweigert ganz, solange ein
  Kapitel gesperrt ist; `kapitelAuffrischen` setzt nicht neu (Meldung),
  Erinnerungen kommen trotzdem lokal ans Foto. Handarbeit bleibt möglich.
- **Kein Strich mehr zwischen Erinnerung und Foto** (ab 1.0.29, Ansage des
  Nutzers 11/2026: Beim Verschieben oder Vergrößern blieb der Strich aus
  1.0.24 stehen — „dass ich dann stattdessen auf diesen Strich verzichten
  kann"). `notizbloecke` setzt keinen mehr; vorhandene nimmt
  `erinnerungsstricheEntfernen` beim Öffnen des Buches einmal von allen
  Seiten (`.linie` mit `zuFoto`).
- **Schrift der vorhandenen Texte global ändern** (ab 1.0.29, gemeldet
  11/2026: „die Schriftgröße der bestehenden Texte zu den Fotos nachträglich
  global zu ändern … nur für jeden Text einzeln"). Ursache:
  `Layoutautomat.abweichung` schrieb ALLE Schriftwerte in jeden gesetzten
  Textkasten — „Schrift und Ausrichtung → Fließtext" erreichte keinen
  vorhandenen. Jetzt steht im Kasten nur, was vom Fließtext ABWEICHT. Für
  ältere Kästen: Typografie, Rolle Fließtext → „Auf alle vorhandenen Texte
  übertragen" (`textschriftAngleichen`: entfernt Familie, Größe,
  Zeilen-/Absatzabstand, Farbe, Kursiv, Versalien, Sperrung, Trennung aus
  allen `.text`-Kästen außer Vorwort und fetten Überschriften; Ausrichtung
  bleibt; Kästen wachsen bei Bedarf, `hoeheAnTextAnpassen`).
- **Alle Texte zum Kopieren** (ab 1.0.29, Ansage des Nutzers 11/2026: „alle
  Texte … an einer Stelle so anzeigen …, dass ich sie komplett markieren
  kann und kopieren"). `Views/TexteExportView.swift`, Text aus
  `alleTexteAlsText(mitUnterschriften:)` (Buchfolge: Vorwort; je Kapitel
  Zeitung, Meldungen, Einträge mit Kopfzeile — Erinnerungen benannt —,
  wahlweise Bildunterschriften; ohne Formatmarken). „Alles kopieren",
  Teilen. Erreichbar: Plusmenü → Texte, „Alle Texte" (Knopf oben),
  Funktionssuche.
- **Keine Zeitraum-Zeile unter dem Kapitel** (ab 1.0.29, Ansage des Nutzers
  11/2026 zu „1. Januar – 31. Dezember 2009" unter „2009": „komplett
  sinnfrei … ein Überbleibsel aus der Reisebuch-App … Die Möglichkeit einer
  zweiten Überschrift würde ich als Option aber gerne noch beibehalten.").
  `neuesKapitel` setzt `datumstext` nicht mehr; `lebenskopf` zeigt die
  Datumszeile nur, wenn eine eingetragen ist (sonst fiele sie auf den
  Datumsstil des Buches zurück). Vorhandene: `zeitraumzeilenEntfernen` beim
  Öffnen (nur Lebensbuch, nicht im Raster Lebensjahr — dort ist sie der
  Geburtstag) nimmt `datumstext == Zeitraum` und die `.datum`-Blöcke weg.
  Die zweite Überschrift (`unterueberschrift`) bleibt wie sie war.
- **Geburtstagsseiten im Kalenderjahr** (ab 1.0.29, Ansage des Nutzers
  11/2026: „Nachdem ich den Geburtstag eingegeben habe, soll jährlich an
  diesem Tag in den bereits vorhandenen Jahren automatisch eine Seite
  angelegt werden für die Zeitungsseite und eine zweite Seite mit Meldungen
  aus aller Welt.").
  - `Reise.geburtsdatum` (unabhängig vom Raster), `Reise.geburtstag`
    (Lebensjahr: Rasterbeginn), `geburtstagIm(tag)` → Datum und Alter, wenn
    ein Geburtstag ins Kapitel fällt (29.2. → 28.2.). Eingabe: Ganzes Buch →
    Kapitel und Zeitraster → Abschnitt „Geburtstag" (Name, Datum, Knopf
    „Geburtstagsseiten in allen Jahren anlegen").
  - `Layoutautomat.geburtstage` (gesetzt in `Reise.automat`); `lebensseiten`
    teilt den Fluss AM Geburtstag (Fotos nach `aufnahme`, Einträge nach
    `zeit`) und stellt `geburtstagsseiten` dazwischen; fällt er auf den
    Kapitelbeginn (Lebensjahr), stehen sie vorn mit dem Kapitelkopf.
    Mitten im Jahr bekommt die Zeitungsseite eine Seitenüberschrift
    („Dein 10. Geburtstag") statt der großen Jahreszahl, die Spalte links
    „Der Tag deines 10. Geburtstags".
  - Fehlt Zeitung oder Meldungen: PLATZHALTERSEITE mit grauem Hinweis, wie
    man einsetzt. **Steht im PDF, solange nichts eingesetzt ist** (sagt der
    Hinweis selbst).
  - `Seite.geburtstag` markiert sie. `geburtstagsseitenAnlegen` fügt sie in
    bestehende Kapitel ohne Neusetzen ein (gesperrte nicht);
    `geburtstagsseitenEinordnen` stellt sie vor die erste Seite mit einem
    Foto vom Geburtstag oder später (nie vor den Kapitelkopf) — benutzt
    auch von „Ab hier neu aufbauen" und „Ab der gewählten Seite neu
    verteilen", die Geburtstagsseiten wie Handarbeit stehen lassen.
    `geburtstagsseitenErneuern` nach „Fertig" in Zeitung und Meldungen,
    wenn das Kapitel sonst nicht neu gesetzt wird.
- **Das Datum der Mediathek geht vor** (ab 1.0.30, gemeldet 11/2026:
  Bildschirmfotos aus alten Videos, Zeitstempel danach mit Insta360Datum in
  der Mediathek geändert — Fotos von Apple sortiert sie richtig ein, die
  Chronik nach dem Erstellungstag). Ursache: `fotosAufnehmen` nahm das Datum
  zuerst aus der DATEI (EXIF); die Mediathek fragte es nur, wenn dort nichts
  stand. Geändert wird aber nur der Eintrag in der Mediathek. Jetzt: Hat das
  Foto einen Mediathekseintrag (`bild.kennung`) und die App Zugriff, gilt
  dessen `creationDate`, sobald es um mehr als 36 h vom EXIF-Datum abweicht
  (darunter ist es die Zeitzone — EXIF ist Ortszeit ohne Zone). Für schon
  eingelesene Fotos: Plusmenü → Fotos → „Datum aus der Mediathek abgleichen"
  (`aufnahmedatenAbgleichen`, Kapitelwerk): gleiche Schwelle, Foto samt
  Unterschrift/Erinnerung von den Seiten des alten Kapitels, ins neue
  (`tagIndex(fuer:)`, legt es bei Bedarf an), Fotos nach Zeit sortiert,
  Kapitel ohne Handarbeit neu gesetzt, die übrigen in der Meldung genannt;
  gesperrte Kapitel unberührt. Fotos aus Dateien (ohne Mediathekseintrag)
  erreicht das nicht.
- **Freie Texte erscheinen auch bei Handarbeit** (ab 1.0.31, gemeldet
  11/2026 mit Bildschirmfoto: „Was soll der Text am oberen Rand bedeuten?
  Das Kapitel trägt Handarbeit. Ich habe jetzt zweimal versucht, einen Text
  erstellen zu lassen, der vom Datum her vor ein angetipptes Foto sortiert
  werden sollte. Er erscheint aber leider nicht … Ich möchte … nicht die
  bereits arrangierten ersten Fotos wieder neu verschieben lassen."). Dieselbe
  Lücke wie bei Erinnerungen vor 1.0.21, nur für freie Texte:
  `kapitelAuffrischen` setzt ein Kapitel mit Handarbeit nicht neu.
  - `freienTextEinhaengen` (Kapitelwerk, aus `eintragSichern` bei Handarbeit
    oder Sperre): Ziel = erstes Foto des Kapitels auf einer Seite mit
    Aufnahme ≥ Zeitpunkt des Textes; der Text (`Layoutautomat.textfeld`:
    Goldstrich, Kopfzeile, Text wie im Fluss) steht ÜBER ihm, das Foto gibt
    oben einen Streifen ab (≤ 55 % seiner Höhe, Unterkante bleibt — so
    bleiben Unterschrift und Erinnerung, wo sie sind). Ohne späteres Foto:
    UNTER dem letzten. Nichts sonst auf der Seite bewegt sich.
  - Für ältere Texte, die nirgends stehen: Kapitel-Menü → „Fehlende Texte
    einsetzen (n)" (`fehlendeTexte`, `stehtAufSeite`), auch in der
    Funktionssuche. Nicht automatisch beim Öffnen — ein auf der Seite
    abweichender Wortlaut ergäbe sonst ein Doppel.
  - Nach der automatischen Textpflege wird ein Kasten mit genau dem alten
    Wortlaut mitgeändert (`textAufSeitenErsetzen`).
  - Die Meldung bei Handarbeit sagt jetzt, was gemeint ist („Im Kapitel …
    hast du Seiten von Hand gestaltet — deshalb setzt die App es nicht von
    selbst neu. Neue Texte und Erinnerungen kommen trotzdem gleich an ihre
    Stelle.").
- **Ein neues Foto in ein gestaltetes Kapitel** (ab 1.0.32, gemeldet
  11/2026: ein einzelnes Foto aus der Mediathek gewählt — Absturz; dazu die
  Sorge, ein erneutes Einlesen verschiebe alles). **Absturzursache NICHT
  gefunden** (kein Befund; aus dem Quelltext nicht abzulesen). Jetzt
  `Absturzspur`-Marken in `fotosAufnehmen` (je Foto, Neusetzen,
  Einschieben) — beim nächsten Absturz den Befund beim Start erfragen.
  Eigentliche Lücke: `fotosAufnehmen` setzt nur unberührte Kapitel neu; in
  einem Kapitel mit Handarbeit stand ein neues Foto auf KEINER Seite. Jetzt
  `fotoEinzelnEinsetzen` (Kapitelwerk) für bis zu 6 neue Fotos je Kapitel:
  Der Rahmen des zeitlichen Nachbarn (erstes späteres Foto auf einer Seite,
  sonst das letzte) wird geteilt — breit: nebeneinander, hoch: übereinander;
  das neue Foto vor einem späteren Nachbarn links/oben, hinter dem letzten
  rechts/unten; Wirkung des Nachbarn übernommen, Ausschnitt frisch. Bei mehr
  als 6 nennt der Bericht die Zahl und „Ab hier neu aufbauen".
- **Geänderter Text erscheint auch auf gestalteten Seiten** (ab 1.0.33,
  gemeldet 11/2026 mit Bildschirmfoto: Text über das Bearbeiten-Symbol
  geändert — „Beim Abspeichern erscheint aber nicht der neue Text aus dem
  Speicher an der Stelle, sondern weiterhin der alte."). `freienTextEinhaengen`
  fand den Eintrag an seiner Kopfzeile und hielt ihn für „steht schon da".
  Jetzt ruft `eintragSichern` bei Handarbeit/Sperre zuerst
  `eintragAufSeitenErneuern(vorher:nachher:)`: Kasten mit genau dem alten
  Wortlaut → neuer Text (über mehrere Kästen geteilt → erster bekommt alles,
  übrige Stücke ab 20 Zeichen gehen weg), Kopfzeile mit, Kasten wächst
  (`hoeheAnTextAnpassen`). Für schon gespeicherte Abweichungen: Kapitel-Menü
  „Texte auf den Seiten auffrischen (n)" (`veralteteTexte` = Kopfzeile steht
  da, Text nicht; `texteAufSeitenAuffrischen` setzt den gespeicherten Text in
  den Kasten direkt unter der Kopfzeile mit gleicher linker Kante und fügt
  fehlende ein; ersetzt „Fehlende Texte einsetzen"), auch in der
  Funktionssuche.
- **Emojis erscheinen auf der Seite** (ab 1.0.34, gemeldet 11/2026:
  „Leider werden Emojis im Text nicht auf den Seiten dargestellt. Im Speicher
  sind sie zwar vorhanden, aber sie werden nicht übernommen."). Für ein Emoji
  setzt iOS im Eingabefeld von selbst die Schrift „Apple Color Emoji";
  `Auszeichnung.auszeichnen` sah darin eine abweichende Schrift und schrieb
  `[schrift=Apple+Color+Emoji]` in den Text. Auf der Seite bekam das Emoji
  diese Schrift mit den Merkmalen der Grundschrift (Lebensbuch: kursiv) —
  und CoreText zeichnete nichts. Jetzt: `auszeichnen` übergeht Läufe in einer
  Emoji-Schrift (nur Fett/Kursiv/Unterstrichen zählen), `zerlegen` setzt eine
  Emoji-Schriftmarke als Grundschrift (CoreText greift selbst auf die
  Emoji-Schrift zurück), und `emojiMarkenAufraeumen` (Kapitelwerk) nimmt die
  Marken beim Öffnen des Buches einmal aus Einträgen, Vorwort, Zeitung,
  Meldungen, Unterschriften und Textkästen (`emojiMarkenEntfernen`, unter
  Linux geprüft). **Ursache aus dem Quelltext geschlossen, nicht gemessen.**
- **Ein gelöschter Text ist weg** (ab 1.0.35, gemeldet 11/2026: „Wenn ich
  einen Text durch Antippen lösche … verbleibt er trotzdem noch im Speicher
  und wird beim nächsten Texte neu aufbauen Befehl wieder an die Stelle
  gesetzt"). Dieselbe Lücke wie bei Erinnerungen (1.0.21) und Fotos (1.0.22):
  `blockLoeschen` nahm bei einem freien Textkasten nur den Kasten. Jetzt
  findet es den Eintrag (`eintrag(zuText:)`, nicht im Vorwort, nicht bei
  `zuFoto`) und ruft `freienTextLoeschen` (Kapitelwerk): Eintrag weg, dazu
  auf allen Seiten des Kapitels seine Textstücke (gleicher Wortlaut oder
  Stück ab 12 Zeichen), die Kopfzeile (mit Titel überall, nur-Datum nur
  direkt über einem gelöschten Stück — die kann ein anderer Text desselben
  Tages tragen) und den Goldstrich darüber. „Zurück" holt alles. Umgekehrt
  nimmt `eintragLoeschen` (Textliste, Editor) den Text bei Handarbeit/Sperre
  jetzt auch von der Seite.
- **„Text davor" lässt das Foto in Ruhe** (ab 1.0.35, Ansage des Nutzers
  11/2026: „dann soll sich die Größe und die Position und das Format des
  Bildes nicht ändern … bin ich ja sowieso an der Stelle dabei, die Seite
  per Hand zu gestalten … dass der Text nicht einfach in einem für ihn
  passenden, möglichst quadratischen Textfeld erscheint"). `EintragView.textVor`
  merkt das Foto in `Reisewerk.textBeiFoto` (nicht gespeichert);
  `eintragSichern` setzt einen solchen NEUEN Text nie neu (auch ohne
  Handarbeit), sondern `freienTextEinhaengen(_:beiFoto:)` legt ihn auf die
  Seite DIESES Fotos. Für alle freien Texte, die eingehängt werden, gilt
  jetzt: Das Foto bleibt unverändert (bis 1.0.34 gab es oben einen
  Streifen ab); `textfeldAufSeite` nimmt die schmalste Breite ab 110 pt, bei
  der der Text nicht höher als breit wird, und sucht im Satzspiegel (Raster
  8 pt) den freien Platz, der der Stelle über (bzw. unter) dem Foto am
  nächsten ist; ist nichts frei, liegt das Feld in der oberen linken Ecke
  des Fotos (Meldung sagt es). **Nicht gemessen:** auf einem Gerät; Album-
  seiten sind meist voll, dann liegt der Text über dem Foto.
- **Datumszeile löschen löscht nicht den Text; Datum und Strich nur auf
  Wunsch** (ab 1.0.36, gemeldet 11/2026 zu 1.0.35: „wird ein hinzugefügter
  Text leider auch mitgelöscht, wenn ich den entsprechenden Datumseintrag
  lösche … die Option, das Datum anzuzeigen und diesen unsinnigen Strich …
  standardmäßig deaktiviert lassen. Erst auf Bedarf … bei der Bearbeitung
  des Textes … aktivieren").
  - `blockLoeschen`: Ist der gelöschte Kasten die KOPFZEILE eines freien
    Textes (`kopfzeile` oder die alte `kopfMitDatum`, nicht der Text), geht
    nur sie samt Strich weg; im Eintrag werden Titel, `datumZeigen` und
    `strichZeigen` gelöscht, damit sie beim Neuaufbau nicht wiederkommen.
  - `Texteintrag.datumZeigen`/`.strichZeigen` (Vorgabe AUS, auch für ältere
    Einträge). `kopfzeile` = Titel, mit Datum nur bei `datumZeigen` (leer →
    keine Kopfzeile); `kopfMitDatum` = die alte Form (Textausgabe „Alle Texte
    zum Kopieren", Wiederfinden alter Kästen). Goldstrich im Fluss nur über
    Texten in `Layoutautomat.mitStrich` (gesetzt in `Reise.automat`),
    `textfeld(strich:)`.
  - Editor (`EintragView`, nur freie Texte): Abschnitt „Darstellung im Buch"
    mit beiden Schaltern. Auf gestalteten Seiten zieht
    `kopfUndStrichNachfuehren` nach (Kopfzeile über dem Text einsetzen/
    ändern/weg, Strich darüber; ist oben kein Platz, rückt der Text nach
    unten).
  - Beim Öffnen räumt `kopfzeilenAufraeumen` die alten Kopfzeilen mit Datum
    und die Striche über Texten ab, die beides nicht zeigen sollen; ohne
    Kopfzeile rückt der Text an ihre Stelle (wiederholbar, was gewünscht
    ist, bleibt). **Nicht gemessen:** auf einem Gerät.
- **Verschieben und Kopieren über die Kapitelgrenze** (ab 1.0.37, Ansage
  des Nutzers 11/2026: „ein bisschen schummeln … ein Foto, das im Januar
  eines Jahres geschossen wurde, auf die Dezemberseite des vorangegangenen
  Jahres vorziehen … Verschieben oder Kopieren offenbar nur kapitelweise").
  `Reisewerk.blockInsNachbarkapitel(_:richtung:kopie:)`: zurück auf die
  LETZTE Seite des vorigen Kapitels, vor auf die ERSTE des nächsten (Vorwort
  ist kein Nachbar; `nachbarkapitel`). Beim Verschieben gehen Unterschrift
  und Erinnerung mit; ein Foto wechselt `tag.fotos` (`fotoDemTagZuordnen`),
  das Aufnahmedatum bleibt — beim Neuverteilen steht es im neuen Kapitel
  hinten (Zeitfolge). Damit die Erinnerung mitkommt, ordnet
  `Reise.eintragKapitel` einen Eintrag mit `foto` dem Kapitel zu, in dessen
  `tag.fotos` das Foto steht (`kapiteleintraege`, `Reise.automat`); sonst
  nach Zeitpunkt. Im Blockmenü (Abschnitte „Verschieben" und „Kopieren")
  und im Inspektor unter „Auf welcher Seite", dazu in der Funktionssuche.
  **Achtung:** „Kapitel und Zeitraster → neu einteilen" ordnet wieder nach
  Aufnahmedatum — das Foto käme zurück. **Nicht gemessen:** auf einem Gerät.
- **Geburtstagsseiten auch in gesperrten Kapiteln** (ab 1.0.38, Ansage des
  Nutzers 11/2026: Kapitel gesperrt, „Für meine Fotos und die Texte soll das
  auch weiterhin gelten. Allerdings muss ich ja noch die Geburtstagsseiten
  erstellen. Dies soll bitte trotzdem möglich sein"). `geburtstagsseitenAnlegen`
  überspringt gesperrte Kapitel nicht mehr (fügt nur Seiten ein, setzt nichts
  neu); `geburtstagsseitenErneuern` (nach „Fertig" in Zeitung und Meldungen)
  legt sie an, wenn es noch keine gibt. Die Sperre schützt weiter alles
  andere (`seitenNeuSetzen`).
- **Meldungen auf einmal einlesen, Satz als Fluss** (ab 1.0.38, Ansage des
  Nutzers 11/2026: „Meldungen des Tages mit oder ohne Foto in die App
  hineinladen …, sodass diese automatisch eine Anordnung auf der Seite trifft,
  sodass man die Texte gut lesen kann und auch erkennen kann, welches Bild zu
  welchem [Text] gehört").
  - `Meldung.ausText` (unter Linux an Beispielen geprüft): Absätze (Leerzeile)
    = je eine Meldung, erste Zeile ≤ 90 Zeichen = Überschrift; ohne
    Leerzeilen jede Zeile eine Meldung; „1964 – …"/„1964: …" → Jahreszahl als
    Überschrift; Aufzählungszeichen fallen weg.
  - `KapitelseitenView`, Abschnitt „Mehrere Meldungen auf einmal": aus der
    Zwischenablage, aus einer Textdatei (derselbe `fileImporter`, Typen nach
    `textdateiwahl`), „Bilder der Reihe nach zuordnen" (Mehrfachwahl, an
    Meldungen ohne Bild in Reihenfolge, übrige Bilder als neue Meldungen).
    Leere Meldungen fallen beim Einfügen weg.
  - `meldungsseiten`: statt 2×2-Raster zwei Spalten im Fluss; jede Meldung ist
    ein Stück (`meldungsstueck`: Bild ≤ 34 % der Satzhöhe, 6 pt darunter
    Goldbalken + Überschrift, Text) und kommt in die niedrigere Spalte;
    zwischen Meldungen 4 Fugen. Ohne Bild nur so hoch wie der Text; lange
    Texte werden nicht mehr auf eine Viertelseite gekürzt.
  - **Nicht gemessen:** auf einem Gerät; wie Texte aus Webseiten (Wikipedia
    „Was geschah am …") tatsächlich zerlegt werden.
- **Handarbeit zurücksetzen, je Abschnitt** (ab 1.0.20 nur umbenannt;
  Frage des Nutzers 11/2026: „dass es tatsächlich eine Funktion gibt,
  manuelle Verschiebungen quasi wieder zurückzusetzen … nicht nur global …
  sondern abschnittsweise. Also für das Vorwort, für das Nachwort … und für
  alle einzelnen Jahre"). Es GAB sie: Kapitel-Menü → bis 1.0.19 „Seiten neu
  anordnen" (`neuAnordnen(erzwingen: true)`), sprach aber vom „Tag" und
  sagte nicht, was bleibt. Heißt jetzt „Automatisch neu verteilen"; die
  Rückfrage (nur bei Handarbeit) nennt, was wegfällt (Lage, Drehung, Größe,
  von Hand eingefügte Seiten samt PDF-Seiten) und was bleibt (Texte,
  Erinnerungen, Fotos, Unterschriften). Gilt für jedes Kapitel und das
  Vorwort; ein künftiges NACHWORT bekommt sie, wenn es wie das Vorwort ein
  `Reisetag` ist, von selbst. Für das ganze Buch: „Ganzes Buch → Alles neu
  verteilen…" (Vorschau, `NeuverteilenView`). Rückgängig: „Zurück".
- **Nicht gebaut:** die Titelseite der Vorlage (Filmstreifen, Collage) — sie
  ist ein gemaltes Plakat; die Titelseite bleibt die des Reisebuchs (Titelbild
  plus Schrift). Ebenso der QR-Code-Kasten und die Stadtsilhouette.

## Konfiguration

- **Bundle-Id `de.familie.kapitelweise`** (ab 1.0.3; gemeldet 11/2026: der
  Upload zu TestFlight scheiterte, weil `de.familie.chronik` bereits vergeben
  war). Homescreen „Kapitelweise", Store-Name „Kapitelweise – Das Buch"
  (getrennte Felder; den App-Eintrag von Hand in App Store Connect anlegen,
  nie über Xcodes „Create App Record"). Ordner `ChronikiOS/`, Ziel/Schema
  „Chronik" bleiben. Ist auch diese Id vergeben, eine andere wählen und an
  ALLEN Stellen mitziehen: pbxproj (2×), beide Entitlements, `Info.plist`
  (Behälter und Dateityp), `Wolke.behaelter`.
- **iCloud-Abgleich und selbst installierte Schriften** (ab 1.0.3, Ansage
  des Nutzers 11/2026). `Config/Chronik.entitlements`: Behälter
  `iCloud.de.familie.kapitelweise` (CloudDocuments, wie das Reisebuch) und
  `com.apple.developer.user-fonts` = `app-usage`. **Nicht gemessen, dass die
  App-Id beides trägt** — der Nutzer bestätigt es einmal in Xcode (Signing &
  Capabilities: „iCloud" mit dem Behälter angehakt, „Fonts" mit „Use
  Installed Fonts"). Was das Profil danach wirklich bewilligt, nennt die App
  unter „Schriften prüfen" (`Profilrechte`); steht dort etwas anderes als in
  der Datei, gilt die Anzeige, und die Datei wird angeglichen (Lehre Reisebuch
  1.0.44/1.0.45/1.0.66). Der iCloud-Ordner heißt im Laufwerk „Kapitelweise",
  darin `Buecher` (`Wolke.ordnername`).
- Mac (`Config/Chronik-Mac.entitlements`): Sandkasten-Rechte des Reisebuchs,
  dazu `device.audio-input` (Mikrofon fürs Diktat) und derselbe Behälter.
- **Diktieren** (`Dienste/Diktat.swift`, unverändert aus Fernweh 1.0.40 bis auf
  den Text der Fehlermeldung; Knopf im Texteditor `EintragView`). Ab iOS 26
  `SpeechAnalyzer`, davor `SFSpeechRecognizer`, beides auf dem Gerät; als
  Hinweise gehen Buchtitel, Kapitel- und Textüberschriften mit.
  Berechtigungstexte (Mikrofon, Spracherkennung) als Build-Einstellung.
  Verbesserungen dort in Fernweh gehören auch hierher.
- Eigenes Dateiformat `.kapitelweise` (`de.familie.kapitelweise.buch`) — nicht
  das des Reisebuchs, zwei Apps dürfen keinen Typ gemeinsam exportieren.
- Versionierung: `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION` je zweimal im
  pbxproj, je Arbeitseinheit Patch UND Build +1. Verlauf: 1.0.0 (1), 1.0.1 (2),
  1.0.2 (3), 1.0.3 (4), 1.0.4 (5), 1.0.5 (6), 1.0.6 (7), 1.0.7 (8), 1.0.8 (9), 1.0.9 (10), 1.0.10 (11), 1.0.11 (12), 1.0.12 (13), 1.0.13 (14), 1.0.14 (15), 1.0.15 (16), 1.0.16 (17), 1.0.17 (18), 1.0.18 (19), 1.0.19 (20), 1.0.20 (21), 1.0.21 (22), 1.0.22 (23), 1.0.23 (24), 1.0.24 (25), 1.0.25 (26), 1.0.26 (27), 1.0.27 (28), 1.0.28 (29), 1.0.29 (30), 1.0.30 (31), 1.0.31 (32), 1.0.32 (33), 1.0.33 (34), 1.0.34 (35), 1.0.35 (36), 1.0.36 (37), 1.0.37 (38), 1.0.38 (39). `DEVELOPMENT_TEAM = F4989GSTWS`,
  `ITSAppUsesNonExemptEncryption = NO` (Info.plist UND Build-Einstellung).
  Mac Catalyst wie im Reisebuch.

## Stand

- **1.0.2 (Build 3)**, 11/2026: Neuaufbau als Abwandlung des Reisebuchs.
  Bücher aus 1.0.0/1.0.1 (eigene Datei `Buecher.json`) werden NICHT übernommen
  — es waren Probebücher; Fotos neu einlesen. **Nicht gemessen:** auf keinem
  Gerät gesehen; ob die Kapitel-Einteilung bei tausenden Fotos je Jahr flüssig
  bleibt (das Reisebuch ist für Dutzende Fotos je Tag gebaut).
- **1.0.3 (Build 4)**, 11/2026: Bundle-Id `de.familie.kapitelweise`,
  iCloud-Abgleich und Schriftenrecht eingetragen, Diktieren aus Fernweh.
  **Nicht gemessen:** Signieren mit den neuen Rechten, Abgleich, Diktat.
- **1.0.4 (Build 5)**, 11/2026: Lebensbuch (Stil, Lebensjahr-Raster, Zeitung,
  Meldungen, überlappende Fotoseiten). **Nicht gemessen:** wie die Seiten auf
  dem Gerät aussehen; die Felder der Fotoseiten sind gerechnet, nicht
  angesehen.
- **1.0.5 (Build 6)**, 11/2026: Fotos aus einem Album der Galerie einlesen.
  **Nicht gemessen:** auf einem Gerät.
- **1.0.6 (Build 7)**, 11/2026: große Jahreszahl nur auf der Geburtstagsseite,
  Doppelseitenansicht nach Produkt. **Nicht gemessen:** auf einem Gerät.
- **1.0.7 (Build 8)**, 11/2026: Zeitung und Meldungen im Kapitel- und
  Plusmenü, Kapitel-Knopf mit Kapitelname. **Nicht gemessen:** auf einem Gerät.
- **1.0.8 (Build 9)**, 11/2026: Texte nach Datum zwischen den Fotos.
  **Nicht gemessen:** auf einem Gerät.
- **1.0.9 (Build 10)**, 11/2026: Fotos und Texte in einem Fluss, Texte als
  Felder nach Inhalt, Spalten unten gefüllt. **Nicht gemessen:** auf einem
  Gerät; wie oft die letzte Seite eines Kapitels halb leer bleibt.
- **1.0.10 (Build 11)**, 11/2026: freie Aufteilung statt Spalten, Texte als
  Felder darin. **Nicht gemessen:** auf einem Gerät; wie lange das
  Durchprobieren bei einem Kapitel mit Hunderten Fotos dauert.
- **1.0.11 (Build 12)**, 11/2026: Nachladen ohne Doppel, Erinnerung zum Foto
  einsprechen. **Nicht gemessen:** auf einem Gerät.
- **1.0.12 (Build 13)**, 11/2026: automatische Textpflege, Texte als fertig
  markieren. **Nicht gemessen:** auf einem Gerät; wie zuverlässig das
  Sprachmodell nur Tippfehler korrigiert.
- **1.0.13 (Build 14)**, 11/2026: Sicherung eines oder aller Bücher aus dem
  Regal, Häkchen für geprüfte Texte. **Nicht gemessen:** auf einem Gerät;
  wie lange die Sicherung aller Bücher mit Hunderten Fotos dauert.
- **1.0.14 (Build 15)**, 11/2026: ab der gewählten Seite neu verteilen,
  Bildunterschrift wandert beim Verschieben mit. **Nicht gemessen:** auf
  einem Gerät; ob die Schwellen (50 % verdeckt, 25 % außerhalb) treffen,
  was der Nutzer als „passt nicht mehr" empfindet.
- **1.0.15 (Build 16)**, 11/2026: Vorwort, zweispaltig, Text fließt um die
  Fotos. **Nicht gemessen:** auf einem Gerät; ob die Seitenschätzung bei sehr
  langen Texten die Fotos gut verteilt.
- **1.0.16 (Build 17)**, 11/2026: Vorwort fließt wie in einer
  Textverarbeitung um geschobene und eingefügte Fotos. **Nicht gemessen:**
  auf einem Gerät; wie lange das Umfließen bei zehn und mehr Seiten nach dem
  Loslassen dauert.
- **1.0.17 (Build 18)**, 11/2026: Schrift und Absätze fürs Vorwort,
  Leerzeilen weg, Textänderung im Vorwort-Blatt kommt an, Fotos über den
  SwiftUI-Fotowähler.
  **Nicht gemessen:** auf einem Gerät.
- **1.0.18 (Build 19)**, 11/2026: Schriftwahl des Vorworts als eigenes Blatt
  (Absturz beim Wählen gemeldet). **Nicht gemessen:** ob der Absturz damit
  weg ist.
- **1.0.19 (Build 20)**, 11/2026: Wähler von iOS schließt nicht mehr doppelt
  (selbst installierte Schriften gingen verloren), Vorwortfotos der Zeit
  nach. **Nicht gemessen:** auf
  einem Gerät.
- **1.0.20 (Build 21)**, 11/2026: Erinnerung im Feld ihres Fotos (daneben
  oder darunter, haftet beim Verschieben), einzelne Wörter formatieren.
  **Nicht gemessen:** auf einem Gerät.
- **1.0.21 (Build 22)**, 11/2026: Erinnerung erscheint auch bei Handarbeit
  sofort am Foto, direkt bearbeiten, Löschen löscht den Eintrag.
  **Nicht gemessen:** auf einem Gerät.
- **1.0.22 (Build 23)**, 11/2026: gelöschtes Foto geht aus dem Kapitel in die
  Fotoablage und kommt beim Neuverteilen nicht zurück; kein aufgeblasenes
  Kapitelende. **Nicht gemessen:**
  auf einem Gerät.
- **1.0.23 (Build 24)**, 11/2026: „Ab hier neu aufbauen" ab gewähltem Foto
  oder Text, frei gewordener Platz wird gefüllt. **Nicht gemessen:** auf
  einem Gerät.
- **1.0.24 (Build 25)**, 11/2026: Textänderung auf der Seite geht in den
  Eintrag, „Text bearbeiten", Strich zwischen Erinnerung und Foto.
  **Nicht gemessen:** auf einem Gerät.
- **1.0.25 (Build 26)**, 11/2026: Eingabefeld lesbar (Bildschirmfarbe, ≥ 16 pt),
  Textliste mit vollem Text. **Nicht gemessen:** auf einem Gerät.
- **1.0.26 (Build 27)**, 11/2026: Fett/kursiv als eigenes Merkmal, bleibt
  erhalten; Vorwort mit engerem, einstellbarem Abstand um Fotos. **Nicht gemessen:** auf einem Gerät.
- **1.0.27 (Build 28)**, 11/2026: Zeilenabstand-Regler bis 0,5.
  **Nicht gemessen:** auf einem Gerät.
- **1.0.28 (Build 29)**, 11/2026: Menüs nach dem Gegenstand, Funktionssuche,
  „Text davor", Kapitel sperren. **Nicht gemessen:** auf einem Gerät.
- **1.0.29 (Build 30)**, 11/2026: Strich an Erinnerungen weg, Textschrift
  global änderbar (auch für vorhandene Kästen), alle Texte zum Kopieren,
  keine Zeitraum-Zeile, Geburtstagsseiten im Kalenderjahr.
  **Nicht gemessen:** auf einem Gerät.
- **1.0.30 (Build 31)**, 11/2026: Datum aus der Mediathek geht vor,
  Abgleich für eingelesene Fotos. **Nicht gemessen:** auf einem Gerät; ob
  Insta360Datum wirklich nur `creationDate` ändert (aus dem Befund
  geschlossen: Fotos von Apple zeigt das neue Datum, die Chronik das alte).
- **1.0.31 (Build 32)**, 11/2026: freie Texte kommen auch bei Handarbeit
  sofort an ihre Stelle (über ihr Foto), „Fehlende Texte einsetzen".
  **Nicht gemessen:** auf einem Gerät.
- **1.0.32 (Build 33)**, 11/2026: neue Fotos in gestalteten Kapiteln neben
  ihren Nachbarn, Absturzspur beim Einlesen. **Nicht gemessen:** auf einem
  Gerät; die Absturzursache.
- **1.0.33 (Build 34)**, 11/2026: geänderter Text ersetzt den alten auch auf
  gestalteten Seiten, „Texte auf den Seiten auffrischen". **Nicht gemessen:**
  auf einem Gerät.
- **1.0.34 (Build 35)**, 11/2026: Emojis erscheinen auf den Seiten
  (Emoji-Schrift nicht mehr als Marke gespeichert, alte Marken entfernt).
  **Nicht gemessen:** auf einem Gerät.
- **1.0.35 (Build 36)**, 11/2026: gelöschter Text geht aus Seite, Textliste
  und Speicher; „Text davor" ändert das Foto nicht und setzt ein
  quadratisches Textfeld. **Nicht gemessen:** auf einem Gerät.
- **1.0.36 (Build 37)**, 11/2026: Datumszeile löschen lässt den Text stehen;
  Datum und Goldstrich über Texten zunächst aus, im Editor einschaltbar.
  **Nicht gemessen:** auf einem Gerät.
- **1.0.37 (Build 38)**, 11/2026: Fotos und andere Blöcke ins vorige/nächste
  Kapitel verschieben oder kopieren, Erinnerung zieht mit.
  **Nicht gemessen:** auf einem Gerät.
- **1.0.38 (Build 39)**, 11/2026: Geburtstagsseiten auch in gesperrten
  Kapiteln, Meldungen aus Zwischenablage/Textdatei, Bilder der Reihe nach,
  Meldungen als zweispaltiger Fluss. **Nicht gemessen:** auf einem Gerät.
