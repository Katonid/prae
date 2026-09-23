# Urlaubstagebuch

Eine native iOS-App (SwiftUI, iOS 17, keine fremden Abhängigkeiten), die
aus Fotos und einem Tagebuchtext ein **gesetztes Buch** macht: je Tag eine
oder mehrere Seiten mit Text, Bildern und einer Karte der Tagesstrecke.

Auf dem Homescreen heißt sie **Reisebuch**; Ordner, Ziel und Bundle-Id
bleiben `Urlaubstagebuch` / `de.familie.urlaubstagebuch`.

Das Ergebnis ist eine **druckfertige PDF-Datei**: Endformat und Anschnitt
stehen als TrimBox und BleedBox darin, der Text ist Text und keine
Abbildung, und vor dem Ausgeben sagt eine Prüfung, was ein Druckdienst
beanstanden würde.

## Was sie tut

1. **Fotos einlesen.** Aus der Fotomediathek oder aus Dateien. Aufnahmetag
   und Aufnahmeort kommen aus dem Bild; die Fotos verteilen sich von selbst
   auf die Tage, in der Reihenfolge, in der sie entstanden sind.
2. **Tagebuchtext einlesen.** Ein Text am Stück, in dem Datumszeilen
   stehen — die App teilt ihn daran auf und legt die fehlenden Tage an.
3. **Reisespur.** Aus den Aufnahmeorten entsteht die Tagesstrecke. Punkte,
   die dicht beieinander liegen, werden zusammengefasst; fehlende setzt man
   auf der Karte, über ein festes Fadenkreuz.
4. **Satz.** Ein Layoutautomat ordnet Text, Bilder und Karte an — nach
   einem von fünf Mustern, das die App selbst wählt oder man selbst
   vorgibt.
5. **Nachbessern.** Jeder Block lässt sich verschieben, in der Größe
   ändern, drehen; jedes Bild im Rahmen verschieben und vergrößern; an
   jeder Stelle die Schrift ändern.
6. **PDF.** Eine Datei mit echtem Text, in Seitengröße, druckfertig.

## Für den Druck

Gemessen an dem, was deutsche Druckdienste verlangen (BoD, epubli, Saal
Digital und die üblichen Online-Druckereien, abgerufen 09/2026):

| Anforderung | Wie die App sie erfüllt |
| --- | --- |
| **PDF** | Einzige Ausgabe. Kein Word-Umweg — siehe unten. |
| **Endformat** | A4 hoch, A4 quer, 21 x 21, 30 x 30 cm, exakt aus Millimetern gerechnet. |
| **Anschnitt** | Einstellbar, Vorgabe 3 mm (BoD verlangt 5). Steht als BleedBox in der Datei. |
| **TrimBox** | Das Endformat, damit die Druckerei weiß, wo geschnitten wird. |
| **300 dpi** | Bilder bis 3600 Punkte Kante; die Prüfung nennt das schwächste Bild mit Seitenzahl. |
| **Schriften eingebettet** | Die Prüfung liest die Einbettungserlaubnis aus der Schrift selbst (`fsType`). |
| **RGB** | Bleibt RGB — genau das verlangen Fotobuchdienste, sie wandeln selbst um. |
| **Keine Transparenz (PDF/X-1a, X-3)** | Schalter beim Ausgeben; Schatten fallen weg, Verläufe werden zu Feldern. |
| **Umschlag getrennt** | Wahlweise zwei Dateien: Innenteil und Umschlag. Der Umschlag ist EIN breiter Bogen — Rückseite, Rücken, Titelseite. |
| **Rückenbreite** | Aus Seitenzahl, Papierstärke und Einband gerechnet; beide Zahlen einstellbar. Verbindlich ist die Angabe des Druckdienstes. |
| **Bundsteg** | Einstellbar, auf beide Ränder gerechnet (siehe unten, warum). |

**Was die App NICHT kann: CMYK.** Eine klassische Offsetdruckerei, die
ISO Coated v2 verlangt, braucht eine umgewandelte Datei; iOS kann kein
CMYK-PDF schreiben. Für Fotobücher ist das kein Mangel, sondern richtig so
— dort ist RGB die gewünschte Anlieferung.

**Warum kein Word oder Pages als Zwischenstufe.** Eine Textverarbeitung
kennt keinen Anschnitt, bricht Bilder um, wenn sich eine Zeile ändert, und
setzt auf jedem Rechner leicht anders. Genau die Dinge, auf die es bei
einer Druckvorlage ankommt — dass ein Bild drei Millimeter über die
Schnittkante steht und im Juni noch genauso steht wie im Mai —, sind dort
nicht zu haben.

## Der Stil trägt die Gestaltung

Fünf Stile setzen Schrift, Farbe, Ränder, Fugen, Schatten und die Vorliebe
für bestimmte Seitenmuster **auf einmal**: *Magazin*, *Fotoalbum*,
*Journal*, *Klar*, *Postkarte*. Das ist keine Bequemlichkeit — diese
Einstellungen ziehen gegeneinander. Eine schmale Didot mit engen Fugen und
randabfallenden Bildern ergibt ein Magazin, eine runde Groteske mit breiten
Rändern und Sofortbild-Rahmen ein Album, und jede Mischung aus beidem sieht
aus wie ein Versehen.

Die Vorschau in der Stilauswahl ist mit demselben Setzer gebaut wie das
Buch und zeigt die eigenen Fotos. Ein gemaltes Beispielbild wäre einfacher
und gälte nichts.

Acht Seitenmuster, darunter drei, die das Buch tragen:

* **Bild über die ganze Seite** — das erste Foto füllt eine eigene Seite
  bis über den Rand, Datum und Überschrift liegen auf einem Verlauf darauf.
* **Bild über die halbe Seite** — ein Foto bis an drei Kanten, daneben Text
  und Karte.
* **Eingeklebt** — Bilder mit weißem Rand, leicht gedreht, überlappend, mit
  Schatten.

Der Drehwinkel wird **aus der Kennung des Fotos gerechnet** und nicht
gewürfelt: Ein Satz, der sich bei jedem Neuanordnen anders neigt, ist kein
Satz.

## Die Entscheidungen, die den Rest tragen

### Der Tag kommt aus drei Zahlen, nie aus einer Umrechnung

Ein EXIF-Aufnahmedatum hat **keine Zeitzone**. „2026:08:12 19:33:21" ist
die Uhr am Ort der Aufnahme. Wer daraus ein `Date` macht, muss eine Zone
annehmen — und jede Annahme ist irgendwo falsch: Ein Foto vom 12. August,
23:40 Ortszeit in Bangkok wäre in Deutschland der 13., und es rutschte in
den falschen Tagebucheintrag, ohne dass etwas auffiele; die Uhrzeit stimmt
ja.

`Tagesdatum` ist deshalb ein Kalendertag aus drei Zahlen, und die stammen,
wo es geht, unmittelbar aus dem geschriebenen Datum — der EXIF-Zeichenkette
oder der Datumszeile im Text. Das `Date` daneben dient allein dazu, die
Fotos **innerhalb** eines Tages zu sortieren; es trägt eine feste Zone und
ist kein Augenblick auf der Weltuhr.

Die einzige Stelle, an der ein Tag doch aus einer Umrechnung entsteht, ist
der Aufnahmezeitpunkt aus der Fotomediathek — die gibt einen echten
Zeitpunkt heraus und nichts anderes. Das steht so im Quelltext.

### Ohne Mediathekserlaubnis gibt iOS keine Aufnahmeorte heraus

Das ist die Falle, an der ein Reisetagebuch ohne Vorwarnung scheitert. Der
Fotowähler braucht **keine** Berechtigung, und genau deshalb hält man ihn
für den ganzen Weg. Hat eine App aber keinen Zugriff auf die Mediathek,
entfernt iOS die Standortdaten aus den herausgegebenen Bilddaten: Die Fotos
kommen an, die Karte bleibt leer, und es sieht aus, als könne die App kein
EXIF lesen.

Deshalb ist der Fotowähler der von UIKit und nicht SwiftUIs
`PhotosPicker`: Nur ein `PHPickerViewController` mit
`PHPickerConfiguration(photoLibrary: .shared())` gibt zu jedem Treffer
dessen `assetIdentifier` heraus, und nur über den lässt sich der Ort am
Mediathekseintrag nachschlagen. SwiftUIs `PhotosPicker` lässt sich nicht so
bauen; sein `itemIdentifier` bleibt leer.

**Wer die Erlaubnis verweigert, wird nicht ausgesperrt.** Alles außer dem
automatischen Aufnahmeort funktioniert weiter, die Punkte lassen sich von
Hand setzen, und die App sagt in einem Satz, was fehlt und warum. Der Weg
über **Dateien** ist davon ohnehin nicht betroffen: Dort kommt die Datei
unangetastet an, mit Datum und Ort.

Geladen werden immer **Daten**, nie ein `UIImage`. Ein Bild ist schon
entpackt — seine Metadaten sind dann weg.

### Seite und PDF zeichnet derselbe Setzer

Eine Buchseite wird zweimal gezeichnet: auf dem Bildschirm, damit man sie
anfassen kann, und ins PDF, damit man sie drucken kann. Zwei Zeichenwege
bedeuten früher oder später zwei Ergebnisse — und der Unterschied fällt
auf, wenn das Buch beim Drucker liegt.

`Seitensatz` ist deshalb die eine Stelle, die beide benutzen: Textsatz
(CoreText), Linie, Bild im Rahmen. Die Ansicht hängt eine UIView davor
(`Textkasten`), die nichts weiter tut, als diese Funktionen aufzurufen.
Und wo das Bild in seinem Rahmen liegt, rechnet
`Bildausschnitt.zielrechteck` — einmal, für beide.

Gemessen wird der Umbruch mit CoreText (`Textmass`), nicht geschätzt. Eine
Schätzung aus Zeichenzahl mal Schriftgröße ist bei einer
Proportionalschrift regelmäßig um ein Drittel daneben; das Ergebnis wäre
ein Buch, in dem der Text unten aus der Seite läuft.

**Silbentrennung ist hier erlaubt** — anders als in den anderen Projekten
dieses Repos. Getrennt wird nicht von uns, sondern von Apples deutschem
Wörterbuch (`hyphenationFactor` mit `languageIdentifier`). Eine selbst
gebaute Trennung bliebe verboten: Die deutsche ist nicht ableitbar, und
eine falsche stünde für immer im gedruckten Buch.

### Gerechnet wird in Seitenpunkten

Alle Rahmen liegen in PostScript-Punkten der Seite (A4 quer = 842 × 595).
Der Bildschirm ist nur ein Fenster darauf: Der Maßstab liegt als eine
einzige Skalierung über dem Ganzen, und jede Geste wird durch ihn geteilt,
bevor sie ins Modell geht. Ohne diese Division wanderte ein Block auf einer
klein gezoomten Seite dreimal so weit wie der Finger — und ein Buch, das
auf dem iPhone gestaltet wurde, sähe auf dem iPad anders aus.

### Die Karte auf der Seite ist ein Bild

`MKMapSnapshotter` statt einer lebenden `Map`, und das hat drei Wirkungen
auf einmal: Das PDF sieht aus wie die Ansicht; die Karte schluckt keine
Geste, die den Block bewegen wollte (dieselbe Lehre wie in der
Abfahrtstafel); und ohne Netz bleibt das Bild stehen.

Der Punkt dagegen wird auf einer **echten** Karte gewählt, in einem eigenen
Bildschirm — dort ist die Karte die Hauptsache und darf alles. Gewählt wird
über ein festes Fadenkreuz, die Karte bewegt sich darunter: Ein Tippen wäre
naheliegend und schlechter, der Finger verdeckt genau die Stelle, die er
trifft.

Gezeichnet wird die **Verbindung der Punkte**, nicht der gefahrene Weg —
welche Straße es war, steht in keinem Foto. Das steht auch so unter der
Karte.

### Hell oder dunkel entscheidet das Buch, nicht das iPad

Bis 1.0.2 stand über der Helligkeit gar nichts, und damit entschied die
Erscheinung des Geräts: Wer abends am dunkel geschalteten iPad arbeitete,
bekam eine schwarze Karte ins gedruckte Buch. Eine Druckvorlage darf nicht
davon abhängen, wie hell es im Zimmer war. Seit 1.0.3 steht die Helligkeit
in der Gestaltung, und die Vorgabe ist **hell**
(`MKMapSnapshotter.Options.traitCollection`).

### Vier Kartenquellen, und was jede kostet

Apple Karten sind die einzige Quelle, die iOS mitbringt, und ihr Aussehen
ist nicht verhandelbar. Eine topographische Karte mit Höhenlinien gibt es
dort nicht. Eine Kachelkarte ist dagegen nichts als quadratische Bilder
unter einer Adresse (`Dienste/Kachelkarte.swift`, Web-Mercator von Hand).

| Quelle | Gemessen 21.09.2026 | Lizenz |
|---|---|---|
| Apple Karten | vier Stile, hell/dunkel, kein Netzkonto | Apples Bedingungen |
| OpenStreetMap | `tile.openstreetmap.org`, 256 px, `max-age=16144` | ODbL, Namensnennung |
| OpenTopoMap | bis Zoom 17, `max-age=604800` | CC-BY-SA, Abdruck ausdrücklich erlaubt |
| Eigener Server | Adressvorlage `{z}/{x}/{y}` | trägt der Nutzer selbst ein |

Drei Dinge sind dabei Pflicht, nicht Zugabe, und sie stehen so in der
Nutzungsrichtlinie der OpenStreetMap Foundation (abgerufen am 21.09.2026):

* **Ein eigener User-Agent.** Anfragen mit der Vorgabe einer Bibliothek
  werden ausdrücklich gesperrt. Es steht also der Name dieser App darin und
  eine Adresse, unter der man sie findet — keine E-Mail des Nutzers.
* **Ein Zwischenspeicher**, der die Verfallszeiten des Servers achtet
  (`URLCache`, 256 MB auf der Platte).
* **Ein Deckel.** Höchstens 48 Kacheln je Karte; darüber wird die Auflösung
  gesenkt, statt einen fremden Server zu belasten, den niemand dafür
  bezahlt.

Was es mit Absicht **nicht** gibt: einen Knopf, der eine Gegend im Voraus
lädt. Genau das nennt die Richtlinie als verboten. Geholt wird, was auf
einer Seite steht.

**Der Lizenzhinweis wird IN das Bild gezeichnet**, unten rechts, und lässt
sich nicht abschalten. Ein Hinweis als eigener Textblock ließe sich
verschieben, überdecken oder löschen — und stünde dann nicht mehr da, wenn
das Buch beim Drucker liegt.

Und eine Ehrlichkeit dazu: **CC-BY-SA heißt auch Share-alike.** Der
Herausgeber von OpenTopoMap beantwortet die Frage nach dem gedruckten
Wanderführer mit Ja und ohne Gebühren — verlangt aber, dass die abgedruckte
Karte unter denselben Bedingungen weitergegeben werden darf. Für ein
Familienbuch im Schrank ist das folgenlos; für eine Auflage nicht.

### Der Abgleich läuft über iCloud Drive, nicht über CloudKit

Ein Buch ist eine kleine JSON-Datei und zweihundert große Bilder. Genau
dafür ist ein Dateiabgleich gebaut: Er lädt eine Datei erst herunter, wenn
sie gebraucht wird, und überträgt ein Bild nicht noch einmal, nur weil im
Buch ein Komma anders steht. Eine eigene Synchronisierung müsste all das
nachbauen.

Die Bücher liegen deshalb im Behälter der App im iCloud-Laufwerk, und den
Abgleich macht iOS. Was die App dazutut, sind vier Dinge:

* Sie stößt das **Herunterladen** an, was noch nicht auf dem Gerät ist —
  sonst stünde ein Buch im Regal, das sich nicht öffnen lässt.
* Sie **horcht** über `NSMetadataQuery`, statt beim Start einmal zu fragen.
  Das ist der Unterschied zwischen „abgeglichen" und „abgeglichen, sobald
  jemand die App neu startet". Zwei Sekunden Ruhe zwischen den Meldungen,
  sonst baut sich das Regal während einer Übertragung zwanzigmal neu auf.
* Sie löst **Konflikte** — nach dem `geaendert` IM Buch und nicht nach dem
  Zeitstempel der Datei. Die unterlegene Fassung wird nicht überschrieben,
  sondern bleibt als eigene Datei liegen und steht in den Einstellungen.
  Ein Abgleich, der stillschweigend einen Abend Arbeit wegnimmt, ist
  schlimmer als zwei Bücher, die man vergleichen muss.
* Sie **kopiert beim Umschalten** und löscht nichts — in keiner Richtung.

Fehlt das iCloud-Recht, oder ist niemand angemeldet, gibt iOS keinen
Behälter heraus. Dann bleibt alles auf dem Gerät, und die App sagt das.

### Ein ganzes Buch in einer Datei

`.reisebuch` enthält das Buch samt aller Bilder. Der Behälter ist selbst
geschrieben, und zwar aus einem Grund: Zum **Packen** eines ZIP gibt es auf
iOS einen halböffentlichen Weg (`NSFileCoordinator` mit `.forUploading`),
zum **Entpacken** gar keinen. Ein Format, das sich schreiben, aber nicht
lesen lässt, ist kein Austauschformat, und eine fremde Bibliothek wäre die
erste Abhängigkeit dieser App.

    REISEBUCH1\n            11 Bytes Kennung
    [4 Bytes]               Länge des Kopfes, große Ziffer zuerst
    { … }                   der Kopf als JSON: die Reise und eine Liste
                            der Bilder mit ihren Längen
    ……………                   die Bilddateien, unverändert, hintereinander

Geschrieben und gelesen wird stückweise beziehungsweise
speicherabgebildet — ein Buch mit zweihundert Fotos wiegt ein Gigabyte und
gehört nicht am Stück in den Arbeitsspeicher.

### Die Reisespur aus der Tagesspur

Fotos bringen den Ort mit, an dem jemand stand und abgedrückt hat. Die
Tagesspur kennt den Weg dazwischen — die Fahrt über den Pass, an der
niemand angehalten hat, und den Vormittag im Museum, an dem kein Foto
entstand.

**Der Tag kommt auch hier aus drei Zahlen.** Die JSON-Sicherung trägt zu
jedem Tag einen `dayKey` (`2026-07-25`) in der Zeitzone der Aufzeichnung —
also den Tag, den der Mensch erlebt hat. Im GPX steht derselbe Schlüssel
vorn im Namen der Spur. Nur bei einer GPX-Datei aus einer fremden App muss
der Tag aus dem Zeitstempel gerechnet werden; dann ist die Zeitzone
wählbar, und der Befund sagt, bei wie vielen Tagen das gilt.

Ausgedünnt wird mit derselben Regel wie bei den Fotos. **Aufenthalte
werden nie zusammengefasst**: Sie tragen einen Namen, und einen benannten
Ort wegzurechnen, weil er nah am vorigen liegt, nähme genau die Angabe
weg, für die es ihn gibt.

### Der Textimport behauptet nichts, er zeigt

Die ganze Schwierigkeit steckt in einer Frage: Was **ist** eine
Datumszeile? Ein Datum kommt in einem Reisetagebuch auch mitten im Satz vor
(„die Fähre am 14.08. war ausgebucht"), und wer jedes Datum als Trenner
nimmt, zerlegt einen Absatz in drei Tage.

Die Regel: Eine Zeile ist eine Datumszeile, wenn nach dem Abziehen von
Datum, Wochentag und Beiwörtern höchstens 60 Zeichen übrig bleiben. Was
übrig bleibt, ist die **Überschrift** des Tages — „12.08.2026 – Ankunft in
Lissabon" ergibt beides auf einmal.

Weil sich diese Regel nicht in jedem Text bewähren kann, zeigt die Vorschau
**vor** dem Übernehmen jede erkannte Zeile mit ihrer Nummer, die daraus
gelesene Überschrift und die Zeichenzahl. Und was vor der ersten
Datumszeile steht, wird nie weggeworfen, sondern als Vorspann gezeigt.

Erkannt werden `12.08.2026`, `12.8.26`, `12. August 2026`, `Mo, 12.08.`,
`2026-08-12` — auch ohne Jahr. Fehlt es, gilt das des vorigen Tages; rutscht
das Datum dabei in die Vergangenheit, ist es der Jahreswechsel (eine Reise
über Silvester ist nichts Besonderes, ein Tagebuch, das dabei elf Monate
zurückspringt, schon).

Ein Monatsname muss ein echter sein: Ohne diese Prüfung würde aus „3. Tag
in Porto" ein Datum, und der Monat wäre geraten.

### Was von Hand geändert wurde, bleibt

Jeder Block, den jemand angefasst hat, trägt `vonHand` und wird vom
Neuanordnen in Ruhe gelassen. Vor dem Überschreiben eines Tages, an dem
gearbeitet wurde, fragt die App ausdrücklich nach — eine Automatik, die
eine Stunde Handarbeit ohne Rückfrage überschreibt, benutzt man genau
einmal. In der Tagesliste steht dafür ein Zeichen an jedem Tag.

Dazu ein flacher Rückgängig-Stapel (25 Stände). Er ersetzt keine
Fassungsverwaltung; er fängt den Griff daneben — ohne ihn traut sich
niemand, etwas auszuprobieren.

### Örtlich heißt Abweichung, nicht Kopie

`Schriftabweichung` hat dieselben Felder wie `Schriftbild`, alle
freiwillig. Was dort `nil` ist, folgt weiter der globalen Einstellung.
Würde eine örtliche Änderung stillschweigend alle Werte kopieren, wäre jede
spätere Änderung am Buchganzen an allen schon einmal angefassten Stellen
wirkungslos — und genau das will man beim Umstellen einer Schrift nicht.

### Nichts geht stillschweigend verloren

* Fotos ohne Aufnahmedatum landen in der **Ablage** und werden gezählt.
* Fotos ohne Ort werden gezählt; für sie entsteht kein Punkt.
* Ein Wisch nimmt ein Foto vom Tag, nicht von der Platte.
* Eine Reise, die sich nicht lesen lässt, wird in der Übersicht gezählt.
* Der Einfuhrbericht sagt in einem Satz, was ankam und was nicht.

## Wie groß ein Foto wird (1.0.42)

Gemeldet 09/2026: Ein Tag mit fünf Fotos, einer Karte und mäßig viel Text lief
über vier Seiten; am Ende standen Bilder allein auf der Seite, und die Größen
gingen weit auseinander — „einige Fotos riesengroß, während andere dort, wo der
Text noch mit im Spiel ist, ein Bruchteil dieser Größe haben."

**Nachgerechnet an der Geometrie.** Die Höhe einer randbündigen Reihe ist
Satzbreite geteilt durch die Summe der Seitenverhältnisse. Auf A4 mit den
Vorgaberändern (Satz 178 × 261 mm):

| Reihe | Höhe | Anteil der Satzhöhe |
| --- | --- | --- |
| ein Hochformat (3:4) allein | 237 mm | 91 % |
| ein Querformat (4:3) allein | 134 mm | 51 % |
| drei Kacheln nebeneinander | 45 mm | 17 % |

Faktor 5,3 zwischen der ersten und der letzten Zeile — und welcher Fall eintrat,
hing allein daran, wie viele Kacheln zufällig auf dieser Seite gelandet waren.
Die kamen aus einer Zählung (offene Kacheln geteilt durch geschätzte
Restseiten), und korrigiert wurde danach allein über die Dehnung. Die sagt aber
nur, ob die Spalte den Kasten füllt: Zwei randbündige Hochformate untereinander
füllen ihn genauso gut wie sechs kleine Kacheln.

**Seit 1.0.42 hat jeder Tag eine Zielreihenhöhe, und sie ist gerechnet.** Eine
Reihe der Höhe h trägt Kacheln mit der Verhältnissumme B/h; für alle Kacheln
eines Tages (Summe S) sind das S·h/B Reihen, und die Spalte wird S·h²/B hoch.
Aus der Fläche A, die den Bildern an diesem Tag bleibt, folgt damit genau eine
Höhe: **h = √(A·B/S)**. Mehr Bilder werden kleiner, weniger größer — stetig
statt in Sprüngen.

Daraus folgt der Rest:

* **Eine Reihe darf schmaler sein als der Satz.** Was über dem Deckel
  (Zielhöhe × 1,3) läge, wird nicht höher, sondern schmaler; die Kacheln
  behalten ihr Verhältnis und die Reihe steht mittig. Der alte Weg
  (`naechsteReihe`) konnte das immer schon — 1.0.35 hat ihn durch das Mosaik
  ersetzt und den Deckel dabei verloren.
* **Wie viele Bilder auf eine Seite gehören, folgt aus der Fläche** und nicht
  mehr aus der Zahl der Seiten.
* **Nach unten gibt es keine Dehnungsgrenze mehr.** Sie stand da, solange eine
  Reihe die Satzbreite füllen musste; jetzt heißt Stauchen „kleiner und mittig"
  und kostet nichts. Mit der alten Grenze wurde die Spalte höher als der Kasten,
  die letzte Reihe fiel heraus und ihr Bild landete allein auf der nächsten
  Seite — die zweite Hälfte des gemeldeten Fehlers.
* **Keine hungernde letzte Seite:** Passt alles Offene noch auf diese Seite,
  kommt es mit.

**Und die App misst nach.** „Vor dem Druck prüfen" nennt seit 1.0.42 den größten
Größenunterschied innerhalb eines Tages, mit Datum und beiden Maßen, und wie
viel Prozent der Satzhöhe das höchste Foto des Buches nimmt. Gemessen am
fertigen Satz und nicht an der Absicht.

## Ein Wasserzeichen auf jeder Seite (1.0.46)

Ansage des Nutzers, 09/2026:

> Ich lege einmal eine Bilddatei fest, für die das gelten soll. Und diese
> erscheint dann auf jeder Seite halbtransparent, möglichst an Stellen, an
> denen sonst noch kein Text oder Bild zu sehen ist. Da es halbtransparent
> ist, wäre es aber auch nicht schlimm, wenn ein Teil des Textes über es
> hinweggehen würde.

**Gestalten → Wasserzeichen…** Eine Bilddatei wählen, Sichtbarkeit und Größe
einstellen, fertig — es gilt für das ganze Buch.

### Es ist kein Block

Ein Wasserzeichen gehört dem Buch, nicht einer Seite. Es steht deshalb in
`Gestaltung.wasserzeichen` und wird beim Zeichnen jeder Seite ergänzt —
dieselbe Regel wie bei Seitenzahl und Kopfzeile. Als Block läge es im Satz
herum: verschiebbar, löschbar, und beim nächsten Neuanordnen weg.

Gezeichnet wird es **über dem Hintergrund und unter allen Blöcken**. Das ist
genau die Lage, die der Nutzer beschreibt: Text darf darüber hinweggehen.
Obenauf läge ein Schleier über jedem Foto.

### „Wo gerade Platz ist" ist gemessen

Für jede Seite geht die App ein Raster von 7 × 7 Lagen im Satzspiegel durch
und wertet, wie viel der Fläche schon belegt ist. **Die Gewichte sind der
Kern der Sache:** Ein Foto oder eine Karte **deckt das Zeichen zu** — dort ist
es schlicht weg und wiegt 8. Text läuft nur darüber hinweg und wiegt 1.
Gleiche Gewichte legten das Zeichen lieber unter ein Foto als unter drei
Zeilen Text.

Wo die Suche anfängt, hängt an der Kennung der Seite. Damit landet das Zeichen
auf zwei gleich leeren Seiten an verschiedenen Stellen — und dieselbe Seite
bekommt beim nächsten Öffnen dieselbe. Wer es lieber fest hat, stellt eine der
vier Ecken oder die Mitte ein.

### Warum die Dateien und nicht die Fotos

Ein Wasserzeichen braucht einen **durchsichtigen Grund**. Das kann PNG; die
Fotomediathek gibt fast nur JPEG und HEIC heraus, und deren weißer Grund legte
sich als helles Rechteck über die Seite. Deshalb führt der Knopf in die
Dateien. Das steht auch so in der App — ein Weg, der ohne Begründung enger ist
als erwartet, sieht wie ein Fehler aus.

### Was daran nicht selbstverständlich ist

* **Die Größe ist ein Anteil der Satzbreite**, keine Millimeterzahl. So
  übersteht sie den Formatwechsel von A4 auf A5, ohne dass
  `Formatwechsel` eine eigene Zeile dafür braucht.
* **Das Seitenverhältnis wird einmal beim Einlesen gemessen.** Ohne diese Zahl
  müsste die Lagerechnung das Bild von der Platte holen, nur um seine
  Proportion zu erfahren — je Seite, bei jedem Neuzeichnen.
* **Eingepasst, nie gefüllt.** Ein beschnittenes Ahornblatt ist kein Zeichen
  mehr, sondern ein Fleck.
* **Die Bilddatei reist mit.** `Buchdatei.schreiben` läuft über `reise.fotos`,
  und dort steht das Wasserzeichen nicht drin — es wird ausdrücklich
  dazugepackt. Ohne das verlöre ein ausgetauschtes Buch sein Zeichen, und zwar
  still: Die Einstellung stünde weiter drin, die Datei fehlte.
* **Mit „Ohne Transparenz" fällt es weg**, statt deckend gezeichnet zu werden.
  Der Verlauf unter einer Überschrift wird dort zu einem geschlossenen Feld,
  weil er etwas lesbar machen muss; das Zeichen muss gar nichts.
* **Die Druckprüfung zählt nach**, auf wie vielen Seiten das Zeichen unter
  einem Foto liegt und deshalb kaum zu sehen ist. Auf einer Seite mit
  randabfallendem Bild gibt es keine freie Stelle — das gehört gesagt, nicht
  versprochen.

**Nicht gemessen:** Keine Seite ist damit gesehen worden. Alle Zahlen sind
gewählt und nicht gemessen — die Gewichte, das Raster, die Vorgaben (10 %
Sichtbarkeit, 34 % Breite). Ob ein Zeichen bei 10 % im Druck noch zu sehen ist
oder schon stört, sagt erst der erste Ausdruck; auf dem Bildschirm wirkt es
kräftiger als auf Papier.

## Nur diese eine Karte (1.0.51)

Befund des Nutzers, 09/2026: „Hier wollte ich gerade speziell nur für diese
Karte Änderungen in den Einstellungen treffen. Zum Beispiel, dass
Standortpunkte doch angezeigt werden und nicht nur die Linien. Offenbar kann
ich das aber nicht für einzelne Karten, sondern nur global."

Er hat recht. Es gab die Einstellung für das ganze **Buch** und seit der
ersten Fassung eine Abweichung je **Tag** — für die einzelne Karte auf der
Seite nicht. Seit 1.0.39 lässt sich eine Karte auf eine zweite Seite
kopieren; damit standen zwei Karten im Buch, die sich nicht auseinanderhalten
ließen.

Jetzt sind es **drei Ebenen**, und die untere gewinnt:

| Ebene | Wo | Was `nil` heißt |
|---|---|---|
| Buch | Ganzes Buch → Ränder, Karte, Seitenzahlen | — |
| Tag | Auswahl → „Weiter oben" → Eigene Karte für diesen Tag | wie im Buch |
| Diese Karte | Auswahl → „Diese Karte" → Eigene Einstellung nur für diese Karte | wie an diesem Tag |

Einstellbar ist auf jeder Ebene dasselbe: Kartenanbieter, Stil, Helligkeit,
Beschriftung und die **Reisepunkte** (keine, dezent, nur Anfang und Ziel, mit
hellem Ring). Dazu je Karte ein eigener **Ausschnitt** — der Maßstab und die
Kartenwahl schreiben dann nur noch in diese eine Karte, und unter dem
Abschnitt steht, welche von beiden gerade gemeint ist.

**Abweichung, keine Kopie.** Der Schalter aus heißt „folgt dem Tag", und wo
der Tag nichts sagt, „folgt dem ganzen Buch". Wer später buchweit die
Reisepunkte umstellt, trifft damit weiterhin jede Karte, die nichts Eigenes
trägt. Kopierte der Block beim Anlegen die Werte, wäre genau das nicht mehr
möglich — dieselbe Bauweise wie bei Schrift und Fotostil.

Zwei Dinge, die dabei herauskamen und für sich falsch waren:

- **Der Abschnitt fragte den falschen Tag.** Er hing am *gewählten* Tag, und
  der folgt seit 1.0.28 dem, was oben im Bild steht — nicht dem angetippten
  Block. Wer eine Karte antippte, während darüber noch die letzte Seite des
  Vortags stand, stellte am Vortag etwas um. Zeigte der gewählte Tag ins
  Leere, fiel der ganze Abschnitt weg, und von der Karte aus war gar keine
  Karteneinstellung mehr erreichbar.
- **Auf dem Bildschirm blieb ein verschobener Ausschnitt liegen.** Die
  Kennung, an der die Vorschau neu lädt, nannte nur die *Spanne* des
  Ausschnitts. Wer die Karte verschob, ohne den Maßstab zu ändern, sah
  weiter das alte Bild; im PDF stand das neue.

**Nicht gemessen:** Keine Karte ist damit gesehen worden. Gerechnet ist die
Ursache; ob der Befund des Nutzers wirklich am fehlenden Abschnitt lag, ist
nicht nachgewiesen.

## Der Umschlag ist ein Bogen (1.0.50)

Vier Befunde aus einem Durchgang; drei davon betreffen den Umschlag.

### Seitenzahlen gab es nur im PDF

> Im Menü kann ich Seitenzahlen aktivieren. Diese kommen auf dem Dokument
> aber niemals zum Vorschein.

Das ließ sich am Quelltext abzählen. `Buchausgabe.zeichneFusszeile` war die
**einzige Stelle im ganzen Quelltext**, die `gestaltung.seitenzahlen`
überhaupt las — und sie läuft nur beim Schreiben des PDF. Auf dem Bildschirm
wurde davon nichts gezeichnet; der Schalter war dort seit 1.0.0 ohne jede
Wirkung. Dasselbe galt für die Kopfzeile.

Das verstieß gegen die erste Regel dieser App: **Seite und PDF zeichnet
derselbe Setzer.** Wo Seitenzahl und Kopfzeile stehen, rechnet seither
`Seitenbeiwerk`, und beide Zeichner holen sich dieselben Rechtecke — auf dem
Bildschirm über denselben `Textkasten`, mit dem auch jeder andere Text
gesetzt wird.

Blöcke sind die beiden weiterhin nicht, und das ist Absicht: Sie gehören dem
**Buch** und nicht dem Tag. Als Block lägen sie im Satz herum, wo sie jemand
verschöbe und der Layoutautomat sie beim nächsten Neuanordnen wegräumte.

Wo sie nicht stehen, sagt die Fußzeile der Einstellung jetzt auch:
Titelseite, Rückseite und jede Seite, die ein Bild ganz ausfüllt — dort stünde
die Zahl auf dem Foto.

### Der Umschlag ist ein Bogen, keine Seite

> Die Gestaltung der Titelseite. Diese soll völlig unabhängig von der
> Gestaltung der restlichen Seiten sein. … In meiner Erinnerung ist es bei
> Saal Digital beispielsweise so, dass die Titelseite bzw. der Umschlag des
> Buches so dargestellt wird, dass die rechte Hälfte einer Doppelseite die
> tatsächliche Titelseite ist und die linke Seite die Rückseite des Buches.

Er hat recht, und bis 1.0.49 war es nicht so: Die Titelseite war eine Seite
wie jede andere. Sie nahm den Satzspiegel des Buches, seine Schrift, seinen
Hintergrund und seinen Stil — wer den Innenteil umgestaltete, gestaltete den
Umschlag mit. Bei einem gebundenen Buch ist das falsch: Der Umschlag ist ein
eigenes Stück Papier und läuft an der Druckerei durch eine eigene Maschine.

In der Doppelseitenansicht ist der erste Bogen jetzt der Umschlag: links die
Rückseite, in der Mitte der Rücken, rechts die Titelseite. **Dafür brauchte
es keine einzige neue Paarungsregel.** `Bogenlage` sagt seit 1.0.47: gerade
Nummer links, ungerade rechts. Die Rückseite trägt die Nummer 0, die
Titelseite die 1 — und damit liegen beide von selbst richtig. Gezählt wird
der Innenteil trotzdem ab 1; der Umschlag gehört nicht zum Buchblock.

Im vollständigen PDF fällt die Rückseite weg. Sie stünde sonst als erste
Seite vor dem Titel — eine Reihenfolge, die es im gebundenen Buch nirgends
gibt. „Umschlag als eigene Datei" gibt dafür genau **einen** breiten Bogen
aus.

**Keine TrimBox in der Mitte.** Sie sagt einer Druckerei, wo geschnitten
wird; auf einem Bogen mit zwei Seiten und einem Rücken gäbe es dafür keine
einzige richtige Stelle — geschnitten wird außen, gefalzt wird am Rücken.
Dieselbe Überlegung wie bei der Broschüre seit 1.0.27.

### Der Rücken

> Vielleicht findest du auch noch eine Lösung dafür, dass bei Saal Digital
> normalerweise beim Umschlag auch festgelegt werden kann, was an die Seite
> des Buches, also den Bereich, der die Dicke des Buches ausmacht, drauf
> gedruckt werden kann. Bislang habe ich dort immer den Titel des Buches
> untergebracht.

Blätter mal Papierstärke, beim Hardcover plus die beiden Deckel. Leer heißt:
der Titel des Buches — ein Feld, das man erst füllen muss, um das
Naheliegende zu bekommen, wäre eine Hürde ohne Gewinn.

**Die Breite ist gerechnet und nicht gemessen**, und das steht in der App
auch so da: Wie dick ein Blatt aufträgt, weiß der Druckdienst und nicht
diese App. Beide Zahlen sind deshalb einstellbar.

Die Schrift läuft von oben nach unten, wie es hierzulande üblich ist: Ein
Buch, das flach auf dem Tisch liegt, soll sich mit dem Titel nach oben lesen
lassen.

### Was am Umschlag nicht gesetzt ist, folgt weiter dem Buch

Hintergrund, Rand, Schrift und Titelgröße sind **Abweichungen und keine
Kopien** — dieselbe Regel wie bei der Schrift eines einzelnen Textkastens
und bei der Wirkung eines einzelnen Fotos, und aus demselben Grund: Kopierte
der Umschlag beim ersten Antippen alle Werte des Buches, wäre jede spätere
Änderung am Buchganzen an ihm wirkungslos, und zwar unsichtbar.

Zu finden unter **Ganzes Buch → Umschlag und Titelseite**.

### Was daran nicht selbstverständlich ist

- **Der Rücken macht den Bogen breiter**, und das gehört in jede Rechnung,
  die die Bühne einpasst. Ohne ihn wäre der Inhalt schmaler als das, was
  darin steht, und das letzte Stück des Umschlags ließe sich nicht
  heranschieben — dieselbe Falle wie 1.0.22.
- **Jede Hälfte wird beschnitten gezeichnet**, auf ihre Fläche plus den außen
  liegenden Anschnitt. Ohne das liefe ein randabfallendes Titelfoto über den
  Rücken — also genau über die Beschriftung, die dort stehen soll.
- **Der Umschlag lässt sich nicht von Hand umbauen.** Titelseite und
  Rückseite werden gerechnet und bei jeder Änderung neu gesetzt; ein
  verschobener Block darauf wäre beim nächsten Durchgang weg. Das war bei der
  Titelseite seit 1.0.0 so und bleibt es.
- **Nicht gemessen:** Kein Umschlag ist damit gedruckt worden. Gerechnet ist
  die Geometrie; gewählt und nicht gemessen sind 0,13 mm je Blatt, 4 mm
  Deckelstärke und die Warnschwelle von 4 mm Rückenbreite. Ungeprüft ist vor
  allem, ob ein Druckdienst diesen Bogen annimmt — die Boxen sind gesetzt,
  die Falze stehen nur als Rückenbreite darin, und das ist die Stelle, an der
  die Anbieter auseinandergehen.

## Pinsel und Buch, die große Karte, die Ausreißer (1.0.49)

Drei Befunde aus einem Durchgang, und alle drei sind Bedienung.

### Der Pinsel gehört dem einzelnen Element

> „Bei der Bedienung der App komme ich immer durcheinander mit dem
> Pinsel-Symbol und dem Symbol für die Einstellungsmöglichkeiten. Irgendwie
> habe ich fast sogar das Gefühl, dass die beiden Symbole vertauscht sind.
> Wenn ich zum Beispiel in Pages arbeite, ist der Pinsel dafür zuständig, die
> Einstellungen einzelner Elemente im Dokument zu ändern."

Sie waren vertauscht. In Pages öffnet der Pinsel die Einstellungen des
**gewählten** Elements; hier tat das der Schieberegler, und der Pinsel führte
in die buchweite Gestaltung.

Der Tausch allein hätte es nicht gerichtet. „Ausgewähltes" und „Gestalten"
sagen beide etwas über die *Tätigkeit* — und der Unterschied zwischen diesen
beiden Knöpfen ist nicht die Tätigkeit, sondern der **Geltungsbereich**. Sie
heißen deshalb jetzt **„Auswahl"** (Pinsel, ganz rechts) und **„Ganzes Buch"**
(Buchsymbol), und im Menü steht „Gilt für das ganze Buch" als Abschnittstitel
darüber.

Mitgezogen wurden alle Stellen, die den Knopf beim Namen nennen: die
Bedienungskarte hinter dem „?", die Querverweise in den Einstellungen und der
Satz in der Druckprüfung. Eine Karte, die einen Knopf bei einem Namen nennt,
den es nicht mehr gibt, ist schlimmer als gar keine.

### Die Karte war nicht klein gebaut — sie war ein Blatt in einem Blatt

> „Zum einen möchte ich die Punkte auf der Karte auswählen und merke, dass
> diese viel zu klein öffnet. Diese Karte könnte sich ja tatsächlich über
> einen großen Teil des Bildschirms erstrecken."

Die Punkteliste ist selbst ein Blatt, und auf dem iPad ist ein Blatt ein
Kärtchen in der Bildschirmmitte. Die Karte hing als zweites daran und konnte
damit nie größer werden als das erste. Sie geht jetzt über den ganzen
Bildschirm auf.

Die kleine Vorschau oben ist seither ein **Bild** und kein Bedienelement: Sie
lässt sich nicht mehr schieben und zoomen — auf 240 Punkten Höhe war das eine
Karte, an der sich nichts machen ließ, und sie schluckte ausgerechnet den
Tipp, mit dem man die richtige öffnen wollte. Ein Tipp darauf öffnet jetzt die
volle Karte.

### Punkte, die aus der Linie springen

> „Mein Gerät hat den Standort zuweilen sehr ungenau aufgezeichnet und somit
> sind Punkte mit einer Linie verbunden worden, die sehr weit auseinander
> sind. In diesem Fall sticht die Linie sehr hervor, obwohl sie gar nicht dem
> Reiseverlauf entspricht."

Gegen die Messung lässt sich nichts tun: Ein GPS-Empfänger zwischen zwei
Häuserwänden meldet zuweilen eine Stelle einige Kilometer daneben, und weil
die Spur eine Reihenfolge ist, zeichnet die Karte getreulich hin und wieder
zurück. Gegen die **Linie** lässt sich etwas tun.

Gemessen wird der **Umweg** — was der Punkt an zusätzlicher Linie kostet
(`hin + zurück − direkt`). Das ist genau der Schaden, um den es geht: Bei
einem Sprung hin und gleich zurück ist er das Doppelte der Abweichung, bei
einer Kurve unterwegs fast null.

Die Schwelle hängt an der Spur selbst. Zwei Kilometer sind in einer
Stadtbesichtigung ein Ausreißer und auf einer Fahrt durch Kanada nichts;
verglichen wird deshalb gegen den **Median** der Schrittweiten dieser Spur —
nicht gegen den Mittelwert, denn den verderben genau die Ausreißer, die
gesucht werden. Dazu ein Boden von anderthalb Kilometern: Was darunter liegt,
sticht auf einer Buchseite nicht heraus. Ein zweiter Grund ist ein unmögliches
Tempo (über 1200 km/h) — aber nur in **beide** Richtungen: Ein Linienflug ist
auch schnell, er kommt nur nicht in derselben Minute zurück.

**Gelöscht wird nichts von selbst.** Ein Abstecher zum Aussichtspunkt und
zurück sieht von außen genauso aus wie ein Messfehler, und welcher von beidem
es war, weiß nur, wer dabei war. Über der Punkteliste steht ein Abschnitt mit
Stelle, Namen und der zusätzlichen Linie in Kilometern; von dort lassen sich
alle auf einmal entfernen (mit Rückfrage) oder nur auswählen und einzeln
ansehen. Markiert sind sie in der Liste, auf der Vorschau und auf der großen
Karte — mit Zeichen *und* Farbe, denn Orange allein sieht nicht jeder.

Der erste und der letzte Punkt werden nicht geprüft: Ein Ausreißer wird an
seinen Nachbarn erkannt, und die beiden haben nur einen.

**Nicht gemessen:** Keine Spur ist damit angesehen worden. Alle drei Zahlen
sind gewählt und nicht gemessen (Boden 1,5 km, Faktor 8 auf den Median,
1200 km/h) — ob sie das Richtige treffen, sagt erst der nächste Befund, und
weil die App die Zahlen hinschreibt, sagt er es mit Zahlen. Zwei
aufeinanderfolgende Ausreißer kann diese Erkennung nicht trennen: Der zweite
ist der Nachbar des ersten, und dann ist der Umweg klein.

## Die zweite Überschrift — der Ort unter dem Datum (1.0.48)

> „In dem zu importierenden Text … ist es so, dass nach dem Datum eine zweite
> Überschrift kommt, in der der Ort des Geschehens aufgeführt wird oder ein
> bestimmtes Schlagwort. Erst dann beginnt der Fließtext mit den Erlebnissen.
> … Diese soll nicht genauso aussehen wie die Datumsüberschrift, sondern es
> soll erkennbar sein, dass es eine zweite Ebene … sein soll.“

Bis 1.0.47 wurde diese Zeile Fließtext. Sie ging also nicht verloren — sie
stand als erster Absatz im Tagebuchtext des Tages.

### Erkannt wird die Kürze

Das ist in BEIDEN Textsorten ein Merkmal, und darauf beruht die ganze Regel:
In einem hart umbrochenen Text reicht eine gewöhnliche Zeile bis nahe an die
Umbruchspalte (gemessen in 1.0.12: rund 88 Zeichen), in einem frei
geschriebenen ist ein ganzer Absatz EINE sehr lange Zeile. Eine kurze Zeile
unmittelbar nach dem Datum ist damit in keinem der beiden Fälle Fließtext.

Dazu vier Bedingungen: höchstens 42 Zeichen und sechs Wörter, groß oder mit
einer Ziffer anfangend, kein Satzzeichen am Ende (der Doppelpunkt ausgenommen
und abgeschnitten), und kein Datum darin.

**Die wichtigste Bedingung ist, dass danach noch Text kommt.** Ein Tag, der nur
aus dieser einen Zeile besteht, hat keine Überschrift — er hat einen sehr
kurzen Text, und den als Überschrift zu setzen hieße, ihn aus dem Tagebuch zu
nehmen. Der Fehler in diese Richtung ist der teure: Was als Überschrift
gesetzt wird, fehlt danach im Fließtext.

### Behauptet wird nichts, gezeigt wird

Dieselbe Bauweise wie bei der Absatzerkennung seit 1.0.12. Die Vorschau nennt
die gefundene Zeile je Tag eigens — und sie sieht dort anders aus als die
erste Überschrift, denn sie wird dem Fließtext weggenommen. Die Fußzeile
zählt „an n von m Tagen gefunden“, und **auch der Fall „nirgends“ steht da**,
samt der Regel im Klartext. Ein Schalter stellt die Erkennung ab.

### Wie sie aussieht

`Typografie.unterueberschrift` ist **optional**, und `nil` heißt
„abgeleitet“ — nicht „leer“: dieselbe Familie wie die Überschrift, 58 % der
Größe, kursiv, nicht fett, in der Akzentfarbe. Der Grund ist derselbe wie bei
einer `Schriftabweichung`: Die sechs Buchstile setzen `titel` je einzeln, und
ein fest eingetragener Vorgabewert stünde in jedem davon in einer fremden
Schrift — ein siebter Stil vergäße ihn obendrein. Der erste Griff an einen
Regler löst sie aus der Ableitung, ein Knopf nimmt das zurück, und das
Schrift-Blatt sagt beides.

### Was daran nicht selbstverständlich ist

* **Das Feld steht am Tag, nicht im Block** (`Reisetag.unterueberschrift`), wie
  Überschrift und Datumszeile: Der Block ist ein Vorschlag über dem Inhalt und
  wird beim Neuanordnen neu gerechnet. Eintippen lässt es sich deshalb auch
  ohne Einlesen — im Tagesmenü — und auf der Seite mit dem Doppeltipp wie
  jeder Textkasten.
* **`groessenSkalieren` und `familieUeberall` überspringen eine abgeleitete
  zweite Überschrift.** Beide rechnen über das Schreiben des Wertes, und ein
  Schreiben macht aus der Ableitung eine Kopie. Am Ergebnis änderte das nichts
  — aber ab da folgte sie dem Titel nicht mehr, und das fällt erst beim
  nächsten Stilwechsel auf.
* **`Typografie` liest sich jetzt von Hand.** Die Regel gilt seit 1.0.3 und
  galt für diesen Typ noch nicht: `Reise` holt ihn über
  `b.wert(.typografie, Typografie())` — ein Feld, das der erzeugte Leser
  vermisst, hätte in jedem vorhandenen Buch alle vier Schriften auf die
  Vorgaben zurückgesetzt, und zwar still.
* **Gesetzt wird sie nur auf dem Aufmacher.** Auf der Fortsetzungsseite wäre
  sie dieselbe Angabe ein zweites Mal — dieselbe Regel wie beim Titel. Auf der
  ganzseitigen Aufmacherseite geht ihre Höhe in die Rechnung ein, bevor `y`
  gesetzt wird: Der Kopf wird dort von unten aufgebaut, und eine nachträglich
  eingeschobene Zeile schöbe den Titel aus dem Satzspiegel.
* **Ein leerer Fund überschreibt nichts**, auch beim Ersetzen: Wer die zweite
  Überschrift von Hand eingetippt hat und denselben Text noch einmal einliest,
  verlöre sie sonst.

**Nicht gemessen:** Keine Seite ist damit gesetzt worden, und an der Vorlage
des Nutzers ist die Erkennung nicht gelaufen — die Datei liegt hier nicht.
Gerechnet ist, warum Kürze in beiden Textsorten ein Merkmal ist; gewählt und
nicht gemessen sind alle vier Zahlen (42 Zeichen, sechs Wörter, 58 % der
Titelgröße, Zeilenabstand 1,18). Ob die zweite Ebene auf der gedruckten Seite
als solche zu lesen ist und ob die Erkennung an seinem Tagebuch trifft, sagt
erst der nächste Befund — und seit 1.0.48 sagt er es mit einer Zahl in der
Vorschau.

## Ein Hintergrundbild über die Doppelseite (1.0.47)

> „Ich möchte einstellen können, dass ein Hintergrundbild über eine
> Doppelseite geht. Da ich nicht absehen kann, ob es vielleicht andere
> Konstellationen gibt, wo es sinnvoll ist, das Bild auf jeder Seite zu haben,
> hätte ich gerne hier einen Schalter."

**Gestalten → Hintergrund → Wie weit das Bild reicht.** Aus füllt das Bild
jede Seite für sich; an füllt es die ganze aufgeschlagene Doppelseite, und
jede Seite zeigt ihre Hälfte davon.

**Ein Schalter und keine Automatik**, weil beides richtig ist — nur für
verschiedene Bilder: Ein Muster, ein Himmel oder eine Struktur gehört auf jede
Seite, eine Landschaft über den Bund. Aus als Vorgabe; was bisher gesetzt
wurde, sieht danach unverändert aus.

### Welche Hälfte wohin fällt, ist Buchbinderei

Seite 1 ist ein Recto, also rechts, und jede rechte Seite trägt eine ungerade
Nummer. Diese Regel stand seit 1.0.17 in `Reisewerk.doppelseiten`; sie steht
jetzt als Funktion in `Model/Bogenlage.swift`, und die Doppelseitenansicht holt
sie von dort. Zwei Fassungen ergäben eine Ansicht, die anders paart als der
Satz — und das sähe man erst im gedruckten Buch.

Die Fläche ist **zwei Endformate breit, mit Anschnitt nur außen**: Am Bund
stoßen die Endformate aneinander, innen deckt die Nachbarseite ab. Beschnitten
wird trotzdem am Bogen — die Nachbarseite ist ein eigenes Blatt Papier.
Gerechnet wird das an einer Stelle: `Bogenlage.bildflaeche` für das PDF,
`Bogenlage.versatz` für SwiftUI (dieselbe Zahl, einmal als Rechteck in
Seitenkoordinaten, einmal als Versatz gegen die Bogenmitte, weil ein `ZStack`
mittig ausrichtet).

### Was daran nicht selbstverständlich ist

* **`Seitenhintergrund` liest sich jetzt von Hand.** Er hatte keinen eigenen
  Leser, und das wäre hier still teuer geworden: `Gestaltung` holt ihn über
  `b.wert(.hintergrund, .weiss)`, eine einzelne Seite über
  `b.wahlweise(.hintergrund)` — ein neues Feld hätte in jedem vorhandenen Buch
  den Buchhintergrund auf Weiß zurückgesetzt und jeden eigenen Seitengrund
  verschwinden lassen, ohne eine Meldung.
* **`HintergrundFlaeche` bekommt eine feste Größe.** Ein `ZStack` ist so groß
  wie sein größtes Kind; ein Bild über die Doppelseite ist breiter als diese
  Seite und zöge das Blatt auseinander. Der Rahmen steht deshalb vor dem
  `.clipped()`.
* **Die Probe im Hintergrund-Blatt spannt nicht.** Sie steht nicht im Buch und
  hat keine Nachbarseite; `bogen` und `seitennummer` sind dort leer.
* **Die Druckprüfung zählt die Bögen, die nicht aufgehen.** Setzt jemand den
  Hintergrund je Seite, braucht die Nachbarseite dasselbe Bild mit demselben
  Schalter — sonst steht im Buch die Hälfte des einen neben der Hälfte des
  anderen, und auf dem Bildschirm sieht jede Seite für sich tadellos aus. Die
  Hälfte, die auf die Innenseite des Umschlags fällt (erster und letzter
  Bogen), wird eigens genannt und nicht als Fehler gezählt: Sie wird nie
  gedruckt, und das ist das Buch und kein Versehen.

**Nicht gemessen:** Keine Doppelseite ist damit gesehen worden. Gerechnet ist
die Geometrie. Ungeprüft ist, ob der Bund im gedruckten Buch etwas verschluckt
— ein Hardcover verschwindet in der Bindung, und wie viel, sagt der
Druckdienst und nicht diese App; wer ein Gesicht genau in den Bund legt,
verliert es möglicherweise. Der Bundsteg schiebt den Satz davon weg, das Bild
nicht.

## Das Schriftenrecht ist wieder heraus — die App ließ sich nicht mehr signieren (1.0.45)

Gemeldet 09/2026 mit einem Bildschirmfoto aus Xcode:

> Automatic signing failed — Provisioning profile „iOS Team Provisioning
> Profile: de.familie.urlaubstagebuch" doesn't match the entitlements file's
> value for the com.apple.developer.user-fonts entitlement.

1.0.44 hatte genau dieses Recht eingetragen, damit die selbst installierten
Schriften auftauchen. Die Absicht war richtig, der Preis war zu hoch: **Mit
dem Recht in der Datei ließ sich die App überhaupt nicht mehr bauen** — nicht
nur ohne Schriftwahl, sondern gar nicht. Ein Bereitstellungsprofil kann nur
bewilligen, was die App-Id in der Entwicklerkonsole kann; steht in der Datei
mehr, findet die automatische Signierung kein Profil mehr.

Das Recht ist deshalb **ersatzlos heraus** und nicht auf einen anderen Wert
gestellt. Erst muss die App-Id es tragen, dann darf es in die Datei.

**Der Bau in GitHub Actions konnte das nicht melden.** Er übersetzt mit
`CODE_SIGNING_ALLOWED=NO` gegen den Simulator und sieht Entitlements nie an.
Der Bau zu 1.0.44 war grün — und die App war auf kein iPad mehr zu bringen.

**Der Wert war obendrein geraten.** `system-installed-fonts` steht in keinem
nachschlagbaren Papier; belegt ist allein `system-installation`, und das ist
das Recht, Schriften systemweit zu *installieren* — was diese App nicht tut.

### Was dieser Bau darf, wird jetzt gelesen

„Schriften prüfen" beginnt seit 1.0.45 mit einem Abschnitt **Was dieser Bau
darf**. Gelesen wird die Rechteliste aus dem eingebetteten
Bereitstellungsprofil (`Model/Profilrechte.swift`) — also das, was dem Bau
wirklich bewilligt ist, statt dessen, was im Repo steht. Bis dahin behauptete
die App, das Recht sei „seit 1.0.44 in Kraft": eine Auskunft über das Repo,
ausgegeben als Auskunft über das Gerät.

Zwei Dinge hält der Befund auseinander: Die Entitlements-Datei sagt, was die
App **verlangt**; das Profil sagt, was ihr **bewilligt** ist. Nur das Zweite
lässt sich von innen sehen. Über TestFlight und aus dem App Store liegt gar
kein Profil im Bündel — dann sagt die Zeile, dass sich hier nichts messen
lässt, statt etwas zu behaupten.

Und die Fußzeile der Schriftwahl hört auf zu raten: Liegt ein Profil vor und
nennt es das Schriftenrecht nicht, steht dort kein „das kann zweierlei
heißen" mehr, sondern der Befund.

### Der Weg zurück, falls die Schriften doch hierher sollen

1. In der Entwicklerkonsole bekommt die App-Id `de.familie.urlaubstagebuch`
   die Fähigkeit **Fonts**.
2. In Xcode: Signing & Capabilities → **Fonts**, Haken bei **Use Installed
   Fonts** — **einmal**, nicht zweimal.
3. Xcode schreibt dann selbst in `Config/Urlaubstagebuch.entitlements`, was
   richtig ist.
4. Lässt es sich danach signieren, nennt „Schriften prüfen" die bewilligte
   Zeichenkette aus dem Profil. **Erst die gehört ins Repo** — vorher nicht.

Alles, was 1.0.41 bis 1.0.44 daneben gebaut haben (der Wähler von iOS, die
Systemabfrage, die Anmeldung, die Probe), bleibt unverändert stehen und
wirkt, sobald das Recht da ist.

## Das Recht, die Schriften des Geräts zu sehen (1.0.44)

Zum dritten Mal gemeldet, diesmal mit Bildschirmfotos — und die haben
entschieden: In **Pages** stehen Poppins, Proxima Nova, Publico Text und
Quicksand in der Schriftliste. Im **Wähler von iOS**, den diese App seit
1.0.41 zeigt, springt dieselbe Liste von „PingFang TC" auf „Rockwell".

Es fehlte also weder die Liste dieser App noch der Weg zum Wähler, sondern
das, was iOS der App überhaupt herausgibt. Dafür gibt es ein Recht:
`com.apple.developer.user-fonts` mit dem Wert `system-installed-fonts`. Ohne
das sieht eine App nur die Schriften des Systems und die aus ihrem eigenen
Bündel — über den Wähler genauso wenig wie über
`CTFontManagerCopyRegisteredFontDescriptors`. Damit ist auch gesagt, warum
1.0.43 nichts ändern konnte: Die Abfrage war richtig und fragte in einen
leeren Raum.

Eine Bewilligung braucht es nicht; in Xcode ist es die Fähigkeit „Fonts" mit
dem Haken „Use Installed Fonts". **Wirksam wird es erst in einem signierten
Bau** — GitHub Actions baut ohne Signierung und sieht Entitlements nie an.

**Die Gegenprobe stand die ganze Zeit zur Verfügung** und steht jetzt auch in
der App: Der Wähler ist Apples eigener, also zeigt er, was das System der App
zeigt. Fehlt deine Schrift dort, liegt es nicht an dieser Liste. „Schriften
prüfen" sagt das im Klartext, und die Fußzeile der Schriftwahl unterscheidet
seither „keine da" von „diese App darf sie nicht sehen".

## Die Schriften des Geräts holen (1.0.43)

Gemeldet, nachdem 1.0.41 ausgeliefert war: „Die Schriftarten tauchen immer
noch nicht auf."

1.0.41 hat die Ursache richtig benannt und die zu kleine Antwort gegeben. Die
LISTE blieb dieselbe; daneben stand ein Knopf, der eine Schrift nach der
anderen holt — und er stand unter zwei Abschnitten, von denen der erste
(„Rundes a") auf einem iPad schon eine Bildschirmhöhe füllt.

**Das System lässt sich sehr wohl fragen.**
`CTFontManagerCopyRegisteredFontDescriptors(.persistent, true)` gibt zurück,
was auf diesem Gerät dauerhaft angemeldet ist — also auch, was eine
Schriftverwaltung dort abgelegt hat. Die App fragt das beim Start, meldet die
Fundstücke für ihren Prozess an, und danach stehen sie in der gewohnten Liste.
Ob die Abfrage auf einem bestimmten iPad etwas hergibt, ist hier nicht
gemessen; die App zählt es und schreibt es hin.

**Die Frage in 1.0.41 kam zu früh.**
`CTFontManagerRegisterFontDescriptors` arbeitet asynchron. Bis 1.0.42 wurde
ohne Rückrufblock angemeldet und unmittelbar danach nachgesehen, ob die
Schrift auffindbar sei — der Befund konnte also „NICHT auffindbar" sagen,
während alles in Ordnung war. Gemeldet wird jetzt aus dem Block.

**Der Abschnitt steht ganz oben**, gleich unter der Probe, mit den Familien
des Geräts als Zeilen darin. Dazu ein zweiter Zugang im Schrift-Blatt
(„Selbst installierte Schriften…"): Hinter „Schriftart überall" steht der Name
der gerade gewählten Schrift, und das liest sich wie eine Auswahlliste.

**„Schriften prüfen" ist eine Probe, keine Erklärung.** Kopierbar stehen dort
die Zahl der vom System gemeldeten Einträge, wie viele davon lesbar waren, wie
viele Familien der Prozess danach kennt, jede gewählte Schrift samt
Auffindbarkeit — und ein Protokoll der letzten Starts, das den Neustart
überlebt. Nur so lässt sich „geht gar nicht" von „geht, hält aber den Neustart
nicht" unterscheiden.

## Selbst installierte Schriften (1.0.41)

Gemeldet 09/2026: „Quicksand und … sind auf dem iPad installiert und können
beispielsweise in Pages auch genutzt werden. In der App werden sie allerdings
nicht einmal angezeigt."

**Die App war nicht kaputt — sie hat an der falschen Stelle gefragt.**
`Schriftfamilie.alleDesGeraets` baut die Liste aus `UIFont.familyNames`, und
das ist das Verzeichnis DIESES PROZESSES: die Schriften des Systems und die,
die eine App in ihrem Bündel mitbringt. Was jemand über eine
Schriftverwaltung auf das iPad legt, liegt woanders. Dafür gibt es seit
iOS 13 den `UIFontPickerViewController` — genau den zeigt Pages, und genau
den zeigt die Schriftwahl jetzt auch, in einem eigenen Abschnitt über der
vollen Liste.

Dass sich eine Liste nicht nachrüsten lasse, stand hier und war falsch —
siehe den Abschnitt darunter.

**Gewählt wird ein Deskriptor, gesichert wird ein Name.** Nur ein Name passt
in ein Buch, das auf einem zweiten Gerät wieder aufgehen soll. Die App meldet
die Schrift deshalb für ihren Prozess an (`CTFontManagerRegisterFontDescriptors`,
Umfang `.process` — installiert hat sie der Nutzer längst) und sieht danach
nach, ob sie unter ihrem Namen auffindbar ist. Was dabei herauskommt, steht
als Satz in der Schriftwahl; behauptet wird nichts. Weil eine Anmeldung auf
`.process` mit dem Prozess endet, wird bei jedem Start wieder angemeldet, was
einmal gewählt wurde.

**Eine fehlende Schrift wird gesagt.** `Schriftbild.uiFont` fällt auf die
Systemschrift zurück, wenn ein Name nicht auflöst — richtig, denn eine Seite
ohne Schrift gibt es nicht. Nur sieht man es der Seite nicht an: Sie ist
gesetzt, sie ist lesbar, und sie ist in einer anderen Schrift als der, die
oben steht. In einer Druckvorlage ist das der teuerste stille Fehler. Gezählt
und benannt wird er jetzt in der Druckprüfung für das ganze Buch und als
Zeile in der Schriftwahl für die gerade gewählte.

**Nicht gemessen:** Hier gibt es keine selbst installierte Schrift.
Gerechnet ist nur, warum sie in der Liste fehlten; ob der Wähler sie zeigt,
ob die Anmeldung greift, ob der Name nach einem Neustart trägt und ob eine so
gewählte Schrift ins PDF eingebettet wird, ist offen. Genau deshalb sagt die
App nach jeder Wahl, was sie vorfindet.

## Aufbau

```
Urlaubstagebuch/
  Model/       Reise, Tag, Seite, Block, Schriftbild, Layoutautomat, Einrasten,
               Wasserzeichen
  Dienste/     EXIF, Textimport, Textquelle (Word/PDF/Text), Zipleser,
               Wordtext, Pdftext, Bildarchiv, Ablage, Wolke, Spurbau,
               Spureinfuhr, Buchdatei, Kartenwerk, Kachelkarte,
               Seitensatz, Buchausgabe, Standortdienst
  Views/       Regal, Reise, Seitenfläche, Inspektor, Importe, Karte, PDF,
               Fotostil und Textstil (fürs ganze Buch), Bedienung (die Gesten)
```

`Reise` ist eine JSON-Datei je Buch im Dokumentenordner, die Bilder liegen
daneben. Gesichert wird über eine temporäre Datei, die danach getauscht
wird: Eine halb geschriebene Reise wäre der Verlust eines ganzen Buches.

Das App-Symbol rechnet `scripts/make-icon.py` (reines Python, ohne fremde
Bibliotheken) — nicht von Hand bearbeiten.

## Was der erste gedruckte Stand zeigte (1.0.2)

Sechs Befunde aus einem ausgegebenen PDF, alle behoben:

| Befund | Ursache | Jetzt |
| --- | --- | --- |
| Jede Zeile ein eigener Absatz | Der Text war hart umbrochen, Zeilen durch Leerzeilen getrennt | `Textaufbereitung` erkennt das an der Zeilenlänge und führt zusammen |
| Text endete mitten im Satz | Der Notausgang gegen Endlosschleifen warf den Rest weg | Neue Seite; passt es nirgends, läuft der Text sichtbar über |
| Griffe nicht zu treffen | Damals angenommen: Sie ragten über den Blockrahmen hinaus. Das war nur die halbe Wahrheit — siehe unten, 1.0.5 | Eine Geste je Block; die Griffe sind nur noch gezeichnet |
| Text nur im Inspektor änderbar | — | Doppeltipp öffnet ein Textfeld an Ort und Stelle, in der Druckschrift |
| Datumszeile fest | — | Sieben Formate für das Buch, je Tag überschreibbar |
| Kein Seitenhintergrund | — | Einfarbig, Verlauf, Foto mit Schleier, Papierkorn — global und je Seite |

Dazu: Fotos lassen sich drehen (Griff über dem Block, rastet bei 45°),
überlappen (Ebene) und der Restplatz einer Seite wird zwischen den
Fotoreihen verteilt statt unten liegen gelassen.

## Die Anfasser, zum zweiten Mal (1.0.5)

Gemeldet 09/2026, nach 1.0.4: „Leider kann ich die Bilder immer noch nicht
verschieben oder skalieren. Und den Text kann ich zwar bearbeiten und
drehen, aber die Anfasser an den Seiten lassen auch hier keine Änderung des
Textfensters zu."

**Die Erklärung von 1.0.2 war damit widerlegt**, und zwar durch die Meldung
selbst: Der DREHGRIFF liegt als einziger ganz außerhalb des Blockrahmens —
er ist der, der geht. Läge es am Hinausragen, wäre es genau andersherum.
Was hier stand, war also eine Vermutung, die einmal geholfen hat und die
Ursache nicht war; das gehört gesagt, statt eine dritte Vermutung
danebenzustellen.

Messen ließ es sich hier nicht — es gibt kein Gerät in der Bauumgebung, und
gleich mehrere Verdächtige lagen übereinander:

* der `Textkasten`, eine UIKit-Ansicht mitten im Block; eine solche nimmt
  sich den Finger und gibt ihn nicht weiter,
* die Karte und die Fotokachel darunter,
* zwei Tipp-Gesten und eine Ziehgeste an derselben Ansicht, die sich um den
  Vorrang streiten,
* neun Griffe als eigene Ebene, jeder mit eigener Geste, die einander
  überlappen.

Deshalb sind jetzt **alle auf einmal** weg statt einer nach dem anderen:

* Was in einem Block liegt, ist ein BILD (`allowsHitTesting(false)`) — auch
  der Textkasten (`isUserInteractionEnabled = false`). Dieselbe Lehre wie
  bei der Netzkarte der Abfahrtstafel: Eine Geste gehört der Fläche, was
  darauf liegt, ist Zeichnung.
* Ein Block hat **genau eine** Ziehgeste. Sie entscheidet an der Stelle, an
  der der Finger aufsetzt, EINMAL, was gemeint war — schieben, an einer der
  acht Kanten und Ecken ziehen oder drehen (`Grifflage.getroffen`).
* Die Griffe sind eine reine Zeichnung. Wo sie liegen, steht an EINER
  Stelle (`Grifflage.punkte`) und wird von Zeichnung und Treffprüfung
  gemeinsam gelesen — damit kann der sichtbare Griff nicht mehr woanders
  liegen als der wirksame.
* Die Trefferfläche des gewählten Blocks ist ein eigener, größerer Rahmen —
  **kein negativer Saum**: Ein Kind, das über seinen Elternrahmen
  hinausragt, nimmt in SwiftUI wirklich keinen Finger an, und das war an
  1.0.2 richtig.
* Die Strecke einer Geste wird **nicht mehr durch den Maßstab geteilt**.
  Eine Geste wird in den eigenen Koordinaten der Ansicht gemeldet, an der
  sie hängt, und die liegen innerhalb des `scaleEffect` — also schon in
  Seitenpunkten. Das ist die Lesart der Dokumentation und keine Messung.

## Und dann kam der Befund, der die Sache erklärt (1.0.5)

Noch im selben Durchgang gemeldet: „Es scheint wohl ein größeres Problem zu
sein, denn ich habe mitunter auch Schwierigkeiten, Textblöcke auswählen zu
können."

**Damit ist es nicht mehr die Geste, sondern schon der TIPP** — und das
erklärt beides auf einmal. Zwei Gründe, und beide sind am Quelltext
nachzurechnen statt zu plausibeln:

1. **Ein Textblock ist FLACH.** Eine Datumszeile misst rund 14 Seitenpunkte;
   eine A4-Seite auf einem iPhone wird mit gut halbem Maßstab gezeigt, also
   sind das **sieben Bildschirmpunkte**. Apple nennt 44 als Mindestmaß für
   ein Fingerziel. Eine Trefferfläche, die genau so groß ist wie das
   Gezeichnete, ist bei Text damit grundsätzlich zu klein — unabhängig von
   jeder Gestenfrage. Das trifft die Textblöcke und sonst kaum etwas, und
   genau so wurde es gemeldet.
2. **Die Gesten lagen übereinander** (siehe oben).

Gebaut ist deshalb dieselbe Trennung wie bei der Netzkarte der
Abfahrtstafel: **Ein Block ist eine Zeichnung, die SEITE nimmt den Finger
entgegen.**

* Der Tipp geht an die Seite. Sie sucht hinterher, was gemeint war — erst
  genau, dann im Umkreis einer knappen Fingerbreite (20 Punkte), jeweils von
  oben nach unten, damit bei zwei übereinanderliegenden Blöcken der gewinnt,
  den man sieht. Gerechnet wird erst, wenn klar ist, dass ein Tipp gemeint
  war; die Fangweite kostet also keine Fläche.
* **Die Ziehgeste liegt NUR über dem gewählten Block** samt Griffsaum. Das
  ist kein Detail: Die Seite steckt in einem `ScrollView`, und eine Geste
  über der ganzen Fläche nähme ihm das Blättern. Ein Tipp tut das nicht —
  also **erst antippen, dann anfassen**. Wo keine Auswahl ist, scrollt die
  Seite wie zuvor.
* Die Tipps hängen auch an dieser Ziehfläche. Ohne das käme über dem
  gewählten Block kein Tipp mehr an — weder das Abwählen noch der
  Doppeltipp, der den Text öffnet.

**Und weil sich das hier nicht messen lässt, misst es die App.**
Buch → Satz → „Bedienung prüfen" legt eine Zeile über die Seite, die nach
jeder Ziehbewegung sagt, was angekommen ist: welcher Griff, an welcher
Blockart, wie weit in Millimetern, bei welchem Maßstab — und nach jedem
Tipp, ob er einen Block getroffen hat oder ins Leere ging. Dasselbe Muster wie
die Stufenprobe bei Schulalarm und der Kartenmesser der Abfahrtstafel — nach
zwei falschen Vermutungen ist das keine Zugabe mehr, sondern die Arbeit
selbst. **Nicht als erledigt darstellen**, bevor diese Zeile es sagt.

## Was an 1.0.5 noch fehlte (1.0.6)

Gemeldet: „Bei Fotos und Textfeldern wird nun ein Verschieben zugelassen. Die
Anpasser bewirken aber leider noch keine Größen- oder Formatänderung."

**Der Unterschied zwischen beiden ist die Erklärung, und er ist am Quelltext
nachzurechnen:** Verschoben wird erst am Ende der Geste — bis dahin bewegt
sich nur ein Versatz beim Zeichnen, der Rahmen bleibt. Die GRÖSSE dagegen
ändert sich bei jedem Bildpunkt. Und an diesem Rahmen hing seit 1.0.5 die
Ziehfläche, die die Geste trägt: Sie wuchs unter dem eigenen Finger mit,
ihre lokalen Koordinaten wanderten mit, die gemeldete Strecke bezog sich
plötzlich auf einen anderen Ursprung — und die Geste brach ab. Das Drehen
war davon nicht betroffen, weil die Fläche nicht am Winkel hängt; auch das
passt zum Befund.

**Merke: Eine Fläche, die eine Geste trägt, darf sich während dieser Geste
nicht bewegen.** Sie steht jetzt still, solange gezogen wird
(`ausgangsrahmen`). Dazu erkennt die Geste am Aufsetzpunkt, ob sie neu ist —
nach einem Abbruch bliebe sonst der alte Griff stehen, und die nächste
Bewegung täte etwas, das niemand angefasst hat.

**Nicht gemessen** — wie alles an dieser Bedienung. „Bedienung prüfen" sagt
es.

## Die Anfasser, zum vierten Mal — und diesmal gerechnet (1.0.7)

Gemeldet: „Na, das hat ja mal so gar nichts gebracht. Jetzt geht nicht mal
mehr drehen. Die Anfasser sind zu sehen, aber egal, ob ich auf einen
Anfasser tippe und halte oder auf das Foto selbst oder den Text, es wird
immer nur verschoben."

**Das ist der Befund, der sich rechnen lässt, statt ihn zu deuten.** Die
Geste kommt an — es wird ja verschoben. Nur gibt `Grifflage.getroffen` nie
einen Griff zurück, sondern immer `nil`, und `?? .verschieben` macht daraus
stillschweigend ein Verschieben. Damit ist es weder die Geste noch die
Fläche noch das Neuzeichnen: **Es ist der PUNKT, den die Geste liefert.**
Dass das Drehen „jetzt auch nicht mehr" geht, sagt dasselbe noch einmal —
der Drehgriff ist auch nur ein Griff, er ging seit dem Umbau von 1.0.5 nie,
und ausprobiert wurde er erst jetzt.

**Woher ein falscher Punkt kommt.** Eine Geste meldet ihren Punkt im Raum
derjenigen Ansicht, an der sie hängt. Das ist hier die Ziehfläche des
gewählten Blocks: verschoben (`offset`), um einen Saum vergrößert, und seit
1.0.6 zusätzlich eine, die während des Ziehens ihre Größe ändert. Der
Quelltext rechnete den gemeldeten Punkt deshalb auf die Seite um
(`aufSeite`). Liegt der Ursprung dieses Raumes aber **vor** dem Versatz, ist
der Punkt schon ein Seitenpunkt, die Umrechnung addiert den Blockursprung
ein zweites Mal, und der Griffpunkt landet um den halben Block daneben —
mitten in der Fläche, nie an einer Ecke. Genau das gemeldete Bild.

**Welche der beiden Lesarten stimmt, lässt sich hier nicht messen. Also
wird die Frage abgeschafft.** Gemessen wird ab 1.0.7 in einem BENANNTEN
Raum (`Seitenraum`, an der Seite selbst deklariert); `DragGesture` und Tipp
bekommen ihn mit (`coordinateSpace: .named(…)`). Damit ist der Aufsetzpunkt
dieselbe Zahl, die auch ein Tipp auf die Seite liefert — unabhängig davon,
an welcher Ansicht die Geste hängt und wie weit die verschoben ist.
`aufSeite` ist ersatzlos gestrichen.

> **Merke:** Wer einen Punkt aus einer Geste braucht, nennt den Raum, in dem
> er gilt. „Lokal" ist eine Auskunft über den Ansichtsbaum und keine über
> die Seite.

Die Tipps an der Seite selbst bleiben bei `.local`: Diese Ansicht ist nicht
verschoben, ihr Raum IST der Seitenraum, und das Auswählen über sie hat im
Feld funktioniert. Es wird eine Sache auf einmal geändert.

**Zwei Dinge fielen beim Nachrechnen mit ab:**

* **Die Greifweite darf einen kleinen Block nicht ganz ausfüllen.** Sie war
  fest eine Fingerkuppe (24 Bildschirmpunkte). Bei einem Block von 60 × 40
  Seitenpunkten liegt damit *jeder* Punkt im Umkreis einer Ecke — er ließe
  sich nur noch in der Größe ziehen und nie mehr verschieben. Gedeckelt auf
  gut ein Drittel der kürzeren Seite, mit einem Boden, unter den es nicht
  geht. Bei einer flachen Datumszeile fallen obere und untere Kante
  trotzdem zusammen; dort gewinnt die Ecke, und die zieht beide Maße. Bei
  vierzehn Punkten Höhe gibt es keine vier unterscheidbaren Kanten — das
  ist Geometrie und keine Einstellung.
* **Die Probe nennt jetzt Zahlen statt einer Deutung.** Bis 1.0.6 stand in
  „Bedienung prüfen" nur der Name des Griffs — und der lautete in jedem
  Fall „Fläche", also genau das, was die Frage offenließ. Jetzt steht dort,
  wo der Finger IM Block aufgesetzt hat, wie groß der Block ist und wie
  weit ein Griff greift: `Fläche an Foto · Punkt 144/244 in 0…400/0…200 ·
  greift 20`. Stimmt der Punkt nicht zum Griff, den man angefasst hat,
  steht die Antwort da. **Eine Probe, die nur ihr Ergebnis nennt, ist die
  Frage von vorhin noch einmal.**

## Was nach 1.0.7 übrig blieb (1.0.8)

Gemeldet: „Es ist jetzt tatsächlich schon hundertmal besser. Aber immer noch
ausbaufähig." Vier Punkte, und drei davon lassen sich am Quelltext
nachrechnen.

### „Warum wandert der nicht einfach mit?"

Bis 1.0.7 bewegte das Verschieben nur einen Versatz beim **Zeichnen**
(`schiebt`/`zieht`); der Rahmen im Modell blieb stehen und wurde erst am
Ende der Geste gesetzt. Das hat drei Folgen, und alle drei waren zu sehen:

* Der Block läuft dem Finger nach, statt unter ihm zu liegen.
* **Die Griffe bleiben zurück** — sie lesen den Rahmen, und der hat sich ja
  nicht bewegt.
* Bricht die Geste ab, ohne dass `onEnded` kommt, steht das Bild **für
  immer** neben seinem eigenen Rahmen. Genau das zeigt das erste
  Bildschirmfoto: die Griffe links oben, das Foto rechts unten.

Die **Größenänderung** hat es von Anfang an richtig gemacht — sie schreibt
bei jedem Bildpunkt ins Modell —, und genau die ging.

> **Merke:** Was der Finger bewegt, wird sofort ins Modell geschrieben. Eine
> zweite Wahrheit fürs Zeichnen läuft früher oder später auseinander.

Gerechnet wird dabei vom `ausgangsrahmen` aus und nie vom jetzigen:
`translation` ist die ganze Bewegung seit dem Aufsetzen; auf einen
mitgewanderten Rahmen addiert liefe der Block davon.

### Der verzerrte Text nach jeder Größenänderung

Gemeldet: „ein Textfeld, das in der Größe verändert wurde, [stellt] den Text
verzerrt dar. Man muss erst auf eine andere Seite des Projektes wechseln und
wieder zurückkommen." Die Bildschirmfotos zeigen es zweimal — einmal
gestaucht, einmal gestreckt.

Das ist kein Fehler im Satz, sondern **dokumentiertes UIKit-Verhalten**: Eine
`UIView` steht von Haus aus auf `contentMode = .scaleToFill`. Ändert sich ihr
Rahmen, zeichnet UIKit nicht neu, sondern **zieht das zuletzt gezeichnete
Bild auf die neue Größe** — aus gesetztem Text wird eine Grafik. Der
Seitenwechsel half, weil er die Ansicht neu aufbaute.

`TextkastenView` steht seit 1.0.8 auf `.redraw`. Das gilt für jede Ansicht
dieses Repos, die in `draw(_:)` selbst zeichnet.

### Zwei Finger vergrößern das Bild im Rahmen

Gewünscht: „die Vergrößerung des Fotos innerhalb des Rahmens. Den Rahmen kann
man ja jetzt mittlerweile gut anpassen."

Der Unterschied steht seit 1.0.0 im Quelltext — „wer ein Foto größer haben
will, ändert den Rahmen; wer ein Gesicht in die Mitte rücken will, den
Ausschnitt" —, es fehlte nur der Griff dafür. Jetzt: **Kanten und Ecken
ziehen den Rahmen, zwei Finger den Ausschnitt.** Die Seite selbst wird nicht
mit zwei Fingern gezoomt (dafür stehen die Lupen unten links), es gibt also
nichts, womit sich die Geste streiten könnte. Der Regler im Inspektor bleibt
daneben stehen, und dort steht jetzt auch, dass es die Geste gibt.

Dabei fiel ein zweiter Fehler auf: Das **Schieben des Ausschnitts** addierte
die Gesamtstrecke bei jedem Bildpunkt auf den laufenden Wert — das Bild schoss
unter dem Finger weg, und zwar immer schneller. `translation` und
`magnification` sind die ganze Bewegung seit dem Aufsetzen; gerechnet wird
jetzt auch dort vom Anfangswert.

### Abgeschnittener Text — drei Dinge, und keines reicht allein

Gemeldet: „Leider kann es aber passieren, dass Text abgeschnitten wird, wenn
Textfeld zu klein für die Menge an Text ist. Das fällt zunächst nicht
unbedingt auf. Würde mir wünschen, dass sich die Textfelder so verhalten wie
zum Beispiel die Textfelder in Pages für iPad."

* **Der Kasten wächst beim Tippen mit**, wie in Pages. Nur wachsen, nie
  schrumpfen: Ein Kasten, der von selbst kleiner wird, nähme eine Größe weg,
  die jemand mit der Hand eingestellt hat.
* **Wer ihn von Hand zu klein zieht, sieht eine Marke** an der Unterkante —
  ein oranges Kästchen mit Pluszeichen, dieselbe Zeichensprache wie in Pages.
  Dazu der Knopf **„Rahmen an Text anpassen"** in der Fußleiste und im
  Inspektor, samt der Angabe, wie viel Höhe fehlt. Ein Hinweis ohne Weg, ihn
  aufzulösen, wäre die Frage von vorhin noch einmal.
* **Die Druckprüfung zählt das ganze Buch.** Die Marke sieht nur, wer gerade
  auf dieser Seite ist; ein fehlender Satz fällt sonst erst auf, wenn das
  Buch gedruckt ist — und dann ist er bezahlt.

Der Befund ist **gespeichert, nicht gerechnet** (`Reisewerk.textUeberlauf`):
Dahinter steckt ein voller CoreText-Satz, und als berechnete Eigenschaft
liefe er bei jedem Neuzeichnen mit. Gemessen wird an einer Stelle, wenn sich
Auswahl, Rahmenmaße oder Textlänge ändern.

**Was die Marke NICHT tut:** Sie steht nur am gewählten Block. Auf jedem
anderen Kasten wäre sie eine zweite Messung je Neuzeichnen — und der Fall
entsteht praktisch nur dort, wo man gerade gezogen hat. Fürs ganze Buch ist
die Druckprüfung zuständig.

## Das Textfeld und die Fotowirkung (1.0.9)

### „Das Textfeld erscheint dupliziert"

Gemeldet: „Sobald ich einen Doppeltipp auf den Text ausübe, erscheint das
Textfeld dupliziert, übereinander liegend und lässt sich auch nicht mehr
entfernen."

Der erste Teil ist am Quelltext zu sehen: Beim Bearbeiten lag das
Eingabefeld (UIKit, TextKit) **über** dem weiter gezeichneten Block
(CoreText). Dieselben Wörter, zwei Umbruchmaschinen — die brechen nie an
derselben Stelle, und übereinander sieht das aus wie zwei Textfelder. Der
bearbeitete Block wird deshalb nicht mehr zusätzlich gezeichnet.

> **Merke:** Zwei Zeichner für denselben Inhalt zeigen nie dasselbe.

Der zweite Teil — „lässt sich nicht mehr entfernen" — hatte einen eigenen
Grund: Das Feld ließ sich nur schließen, indem man **daneben** tippte, und
traf man dabei einen anderen Textblock, ging sofort das nächste Feld auf.
Jetzt liegt eine unsichtbare Fläche hinter dem Feld, die es schließt und den
Tipp nicht weiterreicht, dazu der Knopf **„Text fertig"** in der Fußleiste.
Wer einen Modus baut, baut den Ausgang mit — und zwar sichtbar.

**Nicht beantwortet:** ob auf dieser Seite wirklich ZWEI Textkästen liegen.
Das Bildschirmfoto lässt beides zu. Die Druckprüfung meldet ab 1.0.9
denselben Wortlaut mehrfach auf einer Seite — das wäre im gedruckten Buch
ein doppelter Absatz, und mit dem Hinweis ist er nicht mehr zu übersehen.
Woher ein zweiter Kasten käme, sagt sie nicht.

### Wie sich Fotos abheben — einmal fürs ganze Buch

Gewünscht: „Ich möchte die Einstellung, wie die einzelnen Fotos sich abheben
sollen, beziehungsweise wie der Rahmen um sie herum aussehen soll, global
einstellen können."

Bis 1.0.8 schrieb der Layoutautomat Schatten und weißen Rand in **jeden**
Fotoblock. Danach war die Einstellung nicht mehr zu ändern, ohne
zweihundert Fotos einzeln anzufassen — genau der Fall, den
`Schriftabweichung` für die Schrift längst vermeidet.

* **Buch → „Fotos…"**: Schatten, weißer Rand (wie bei einem Sofortbild),
  Linie ringsum und deren Farbe. Gilt für jedes Foto. (Bis 1.0.9 lag das
  hinter „Format, Ränder, Karte" — siehe unten.)
* **Am einzelnen Block steht eine Abweichung**, kein Wert: Wer im Inspektor
  nichts anfasst, folgt dem Buch — und eine spätere Änderung am Buch trifft
  dieses Foto mit. Ein Knopf „Wieder wie im Buch" nimmt die Abweichung
  zurück, einer in der Gestaltung nimmt alle zurück.
* **Aufgelöst wird an einer Stelle** (`Block.wirkung`), die Bildschirm und
  PDF gemeinsam fragen. Zwei Fassungen liefen auseinander, und der
  Unterschied fiele auf, wenn das Buch beim Drucker liegt.

Der Umbau von `schatten`/`fotorand`/`randbreite` auf optional ist für ältere
Bücher gefahrlos: Der erzeugte `Codable`-Leser verlangt einen Schlüssel nur
für nicht-optionale Eigenschaften. Ein vorhandener Wert wird gelesen, ein
fehlender wird `nil` — also „wie im Buch".

## Die Silbentrennung war ein Schalter ohne Draht (1.0.40)

> „Trotz aktivierter Silbentrennung sieht es dann so aus."
> — mit einem Bildschirmfoto: Blocksatz, handbreite Lücken zwischen den
> Wörtern, kein einziger Trennstrich.

Er hat recht, und die Ursache ist am Quelltext abzuzählen.

`Schriftbild.attribute` setzte `NSMutableParagraphStyle.hyphenationFactor`.
Gesetzt wird die Seite aber mit **CoreText**
(`CTFramesetterCreateWithAttributedString`, `CTFrameDraw`), und CoreText
übersetzt einen `NSParagraphStyle` in einen `CTParagraphStyle`. Dessen
Aufzählung `CTParagraphStyleSpecifier` kennt Ausrichtung, Einzüge,
Zeilenhöhen, Absatzabstände und den Umbruchmodus — eine Silbentrennung steht
nicht darin. Das Feld fällt beim Übersetzen weg.

**Damit hat der Schalter „Silben trennen" von 1.0.0 bis 1.0.39 nichts getan**
— weder auf dem Bildschirm noch im PDF, denn beide gehen durch dieselbe
Funktion (`Seitensatz.zeichneText`).

### Warum es zehn Fassungen lang niemandem auffiel

Im Textfeld beim Bearbeiten wirkte die Einstellung sehr wohl.
`TextflaecheBruecke` ist ein `UITextView`, setzt also über TextKit — und
TextKit liest `hyphenationFactor`. Beim Doppeltipp war der Text getrennt,
auf der Seite darunter nicht: dieselbe Einstellung, zwei Satzmaschinen.

**Merke: Ein Attribut, das im Modell steht, ist noch nicht gesetzt.** Wer
eine Einstellung an zwei Wege reicht, prüft sie an beiden.

### Und die App behauptete das Gegenteil

Unter den Schaltern stand „Blocksatz ohne Silbentrennung reißt Löcher in die
Zeilen" — aber nur, **solange der Schalter aus war**. Wer ihn umlegte, sah
die Warnung verschwinden und die Löcher bleiben. Ein Hinweis, der mit dem
Schalter verschwindet, sagt „erledigt", und das war hier falsch.

Jetzt stehen dort Zeilen, die etwas aussagen: woher die Trennstellen kommen,
ob dieses Gerät überhaupt ein deutsches Wörterbuch hat, und dass in
Großbuchstaben nicht getrennt wird.

### Getrennt wird weiterhin nicht von uns

Die Stellen kommen aus `CFStringGetHyphenationLocationBeforeIndex`, also aus
demselben deutschen Wörterbuch des Systems, das TextKit benutzt hätte. Die
Regel bleibt: Eine selbst gebaute Trennung ist verboten — die deutsche ist
nicht ableitbar, und eine falsche stünde für immer im gedruckten Buch. Neu
ist nur, dass die App das Wörterbuch selbst fragt und den Strich selbst
einfügt.

**Ein weiches Trennzeichen (U+00AD) wäre der naheliegende Weg und ist bewusst
nicht gebaut.** Ob CoreText es als Umbruchstelle nimmt und dabei einen
sichtbaren Strich zeichnet, ließ sich hier nicht messen — und der Fehlerfall
wäre der teuerste denkbare: ein Strich mitten im Wort auf jeder Seite des
gedruckten Buches. Eingefügt wird deshalb ein **echter** Strich (U+002D und
nicht U+2010; das Viertelgeviert fehlt in mancher Schrift, und eine fehlende
Glyphe wäre ein Kästchen im Wort), und zwar nur dort, wo die Zeile ohnehin
umbricht. Damit hängt nichts an einer Annahme über CoreText.

### Wie es rechnet

Ein Setzer je Absatz, nicht einer je Trennstelle: Ein eingefügter Strich
gehört zur ablaufenden Zeile, die nächste beginnt an einer Stelle, die es im
Urtext gibt. `CTTypesetterSuggestLineBreak` lässt sich also weiter mit
demselben Setzer fragen, und die Striche werden erst am Ende in den Text
geschrieben. Ein Setzer je Trennstelle wäre quadratisch — bei einem `Mosaik`,
das zwölf Spaltenbreiten durchprobiert, ist das der Unterschied zwischen
Millisekunden und Sekunden.

Gemessen wird die Zeile **mit** dem Strich und nicht die Zeile plus einen
einzeln gemessenen Strich. Der Unterschied ist die Unterschneidung zwischen
letztem Buchstaben und Strich, und er entscheidet: Rechnete man zu knapp,
passte die Zeile beim Setzen nicht mehr, CoreText bräche an der Lücke davor
um — und der Strich stünde am **Anfang** der nächsten Zeile mitten im Wort.
Vorgeschaltet ist eine grobe Prüfung über denselben Setzer; genau gemessen
wird nur der eine Kandidat, der sie überstanden hat.

Zwei Zahlen sind gewählt und nicht gemessen: mindestens zwei Zeichen vor dem
Strich und drei danach, höchstens drei getrennte Zeilen hintereinander.
Beides ist Handwerk des Schriftsatzes.

### Zwei Dinge, die daran hängen

**Die Breite gehört an jede Aufrufstelle von `Textmass`.** Seit die Trennung
von Hand gesetzt wird, hängt der gesetzte Text an der Breite: Wo die Zeile
umbricht, entscheidet, welches Wort getrennt wird. Messen und Zeichnen müssen
dieselbe Breite nennen — sonst hätte der Setzer, der die Höhe ausrechnet,
andere Striche als der, der die Seite zeichnet, und der Text liefe unten aus
seinem Block.

**`passtBis` rechnet auf den Urtext zurück.** Es sagt, wie viel Text auf eine
Seite passt, und `teilen` schneidet danach den Tagebuchtext. Käme dort eine
Länge aus dem gesetzten Text zurück, wanderten die eingefügten Striche über
`Neuverteilung` in `tag.text` — mitten in die Wörter, und zwar dauerhaft.
Versalien bleiben aus demselben Grund ungetrennt: `uppercased()` kann die
Länge ändern („ß" wird „SS"), und dann ginge die Rückrechnung um ein Zeichen
daneben.

### Gezählt statt zugesagt

Nach einem Schalter, der zehn Fassungen lang nichts tat, steht in der
Druckprüfung keine Zusage, sondern eine Zahl: so viele Trennstriche in so
vielen Textblöcken, gezählt am gesetzten Buch. Ist sie null, obwohl der
Schalter an ist, sieht man das, statt es zu vermuten.

### Nicht gemessen

Keine Seite ist damit gesehen worden. Gerechnet und am Quelltext abgezählt
ist die Ursache und die Geometrie der Einfügung. **Ungemessen bleibt der
Preis:** Die Trennung läuft bei jeder Messung mit, und `Mosaik` misst
denselben Text in zwölf Breiten. Der Zwischenspeicher fängt die
Wiederholungen ab, aber wie sich ein Buch mit zwanzig Tagen beim Neuanordnen
anfühlt, sagt erst der nächste Befund; der Zeichenmesser unter „Bedienung
prüfen" zählt die Dauer mit.

## Verschieben findbar, Kopieren gebaut (1.0.39)

> „Ich suche noch nach der Funktion, Elemente auf eine andere Seite zu
> kopieren oder zu verschieben. Sie ist zu versteckt."

Beides trifft zu, und auf zweierlei Weise. **Verschieben** gab es seit 1.0.29 —
aber nur im Block-Inspektor, dort ganz unten, hinter Schrift, Wirkung, Lage und
Ausschnitt; und der Inspektor selbst liegt hinter dem Schieberegler in der
Werkzeugleiste. **Kopieren** gab es überhaupt nicht.

### Der Kommentar behauptete ein Menü, das es nicht gab

Über `Reisewerk.seitenlage` steht seit 1.0.29: „Gebraucht an zwei Stellen
(Inspektor und Blockmenü)". Ein Blockmenü gab es nie — die Funktion wurde von
genau einer Stelle gerufen. Es war geplant und nur halb gebaut.

**Ein Kommentar, der eine zweite Aufrufstelle behauptet, ist kein Beleg dafür,
dass es sie gibt.** Dieselbe Wurzel wie bei jedem anderen Fall in diesem
Papier, in dem ein Kommentar eine Prüfung ersetzen sollte.

### Der Inspektor ist für Einstellungen, nicht für Handgriffe

Was man mit einem Block **tut**, gehört dorthin, wo man ihn gerade anfasst. Das
Blockmenü steht deshalb unten in der Leiste neben dem Tagesmenü, beschriftet
mit der Art des Blocks („Foto", „Textblock", „Karte" …), und erscheint nur,
solange ein Block gewählt ist. Darin: Verschieben (zurück, vor, neue Seite,
bestimmte Seite), Kopieren, Teilen, Nach vorn holen, Entfernen.

Der Abschnitt im Inspektor bleibt — zwei Zugänge, dieselben Funktionen im Werk.

### Kopiert werden kann, was sich selbst gehört

Fotos, Karten, Linien und Flächen ja; Fließtext, Überschrift, Datumszeile und
Bildunterschrift nein. Das folgt aus dem Modell und ist keine Bequemlichkeit:
Ein Tagebuchtext gehört dem **Tag** und steht einmal darin. Eine Kopie wäre im
Druck derselbe Absatz zweimal — `Druckpruefung.doppelterText` meldet genau das
seit 1.0.9 als Fehler —, und `Neuverteilung.fliesstexte` schriebe ihn beim
nächsten Neuverteilen doppelt in den Tagebuchtext zurück.

Der Grund steht im Fußtext des Inspektors. Im Menü fehlt der Eintrag ganz,
statt ausgegraut dazustehen: Ein Knopf ohne Wirkung ist für den Menschen davor
ein kaputter Knopf, ein fehlender wird nicht gesucht. Wer einen Textkasten
aufteilen will, teilt ihn — das ist die Sache, die dahinter gemeint ist.

**Eine Kopie erbt keine Kennung** (Lehre aus Tafelbild 1.4.5): Zwei Blöcke mit
derselben `id` sind für jede Suche ein Block, und der zweite ließe sich nie
wieder anfassen. Auf derselben Seite liegt sie versetzt und auf den Satzspiegel
geklemmt.

### Zwei eigene Fallen beim Gegenlesen

Beide stehen namentlich in diesem Papier, und beide standen trotzdem im eigenen
Entwurf: ein `min` über eine `CGRect`-Kante und einen `Double` (die
CGFloat-Falle aus 1.0.37), und ein Menükörper aus verschachtelten Sections,
Bedingungen und `ForEach` (die Typprüfer-Falle aus 1.0.38). **Die Regeln zu
kennen genügt nicht; sie müssen am eigenen Diff angewandt werden, bevor der Bau
es tut.**

**Nicht gemessen:** Nichts davon ist auf einem Gerät gesehen worden. Dass das
Blockmenü auffindbar *ist*, folgt daraus, dass es unten in der Leiste steht und
den Namen des Blocks trägt — gesehen hat es niemand.

## Alles neu verteilen — und kein Satz geht dabei verloren (1.0.38)

> „Ich frage mich, wie die nun geschaffene Funktion auf dem bereits
> eingegebenen Text angewendet werden kann. Vielleicht wäre eine Funktion
> sinnvoll, das Ganze einmal so weit zurückzusetzen, dass der Bild- und
> Textverteiler in Aktion treten kann."

Die Antwort auf die erste Hälfte lautet: **gar nicht von selbst**, und das ist
kein Mangel. Was in `Gestaltung` und im `Layoutautomat` steht, wirkt beim
SETZEN einer Seite; ein fertiges Buch trägt seine Blöcke als Rahmen im Modell.
Würde eine neue Fassung das von selbst umstellen, bekäme jemand nach einem
Update sein Buch neu gesetzt, ohne es gewollt zu haben.

`alleNeuAnordnen(nurUnberuehrte: true)` gab es schon — es überspringt aber
jeden Tag mit Handarbeit, und Handarbeit ist bereits ein verschobener Block.
Für jeden angefassten Tag hätte man einzeln ins Tagesmenü gemusst.

### Der eigentliche Befund: Das Neusetzen verlor Text

Beim Nachsehen kam etwas heraus, das schwerer wiegt als die Frage.
`Reisewerk.textSchreiben` legt einen auf der SEITE bearbeiteten Fließtext in
den **Block** (Zweig `.text`) — `Layoutautomat.seiten(fuer:)` setzt aber aus
`tag.text`, und der weiß davon nichts. Wer einen Tag mit bearbeitetem Text neu
anordnen ließ, verlor seinen Wortlaut. Still, denn die Seite steht ja danach
da.

**Das gab es schon lange vor dieser Fassung:** an „Seiten neu anordnen" im
Tagesmenü und an beiden Muster-Wegen. „Alle unberührten Tage" war nur deshalb
ungefährlich, weil es solche Tage übersprang.

`Reisewerk.wortlautSichern` schreibt den Wortlaut deshalb **vor** dem Setzen an
den Tag zurück. Der Aufruf gehört an jede Stelle, die Seiten setzt — wer einen
neuen Weg dorthin baut und ihn vergisst, baut denselben stillen Verlust wieder
ein.

### Eine Ansicht setzt keine Seiten

Zwei der vier Stellen, die den Automaten aufriefen, standen in **Ansichten**
(der Picker in `TagInhaltView` und `ReiseView.musterSetzen`) und hatten
dieselbe Folge zweimal gebaut. Keine von beiden wusste vom Wortlaut in den
Blöcken. Beide gehen jetzt über `Reisewerk.musterSetzen`: Die Ansicht sagt, was
gewollt ist; wie daraus Seiten werden, weiß das Werk.

Dass der Befund genau dort saß, wo der neue Kommentar davor warnt, ist kein
Zufall — er war schon da, bevor der Kommentar geschrieben war.

### Zusammenfügen heißt zuerst nachsehen, nicht raten

Das Teilen hat die Ränder abgeschnitten, also steht nirgends mehr, ob zwischen
zwei Stücken ein Absatzwechsel lag oder ein Leerzeichen mitten im Satz. Beides
falsch zu machen kostet: Ein Leerzeichen statt eines Absatzes zieht zwei
Absätze zusammen, ein Absatz statt eines Leerzeichens reißt einen Satz
auseinander — und genau diesen Riss hat 1.0.37 gerade abgestellt.

Kommen beide Stücke **unverändert** im Tagebuchtext vor, steht dort auch, was
dazwischen lag; das deckt den häufigsten Fall ab (von zehn Kästen ist einer
bearbeitet). Geraten wird nur an einer bearbeiteten Naht — Satzzeichen davor
heißt Absatz —, und **wie oft, wird gezählt und hingeschrieben**.

### Zwei Fehler im eigenen Entwurf, beim Gegenlesen gefunden

Beide hätten Text im Tagebuch beschädigt, und keiner wäre aufgefallen:

* **`Seite.sortiert` ist die Zeichen-Reihenfolge** (nach `ebene`) und sagt über
  die Lesereihenfolge nichts. Der Automat setzt je Seite nur einen Textkasten,
  aber „Nach einem Absatz teilen" (1.0.14) kann zwei auf derselben Seite
  hinterlassen — dann stünde der zweite Absatz vor dem ersten. Sortiert wird
  nach der Lage.
* **Zwei gleiche Stücke hintereinander zählen einmal.** Es gibt sie:
  `Druckpruefung.doppelterText` kennt seit 1.0.9 „derselbe Wortlaut in zwei
  Kästen auf einer Seite", und woher der zweite Kasten kommt, ist bis heute
  nicht geklärt. Ungeprüft stünde der Absatz hinterher doppelt im
  Tagebuchtext — ein Schaden, den die Rettungsfunktion selbst anrichtet.

### Was bleibt und was wegfällt

Steht vorher da, Tag für Tag. **Bleibt:** Tagebuchtext, Überschrift,
Datumszeile, Bildunterschriften, die Fotos, die Reisepunkte. **Fällt weg:**
Lage, Größe, Drehung und eigene Schrift der Blöcke, von Hand angelegte oder
entfernte Seiten, geteilte Textkästen. Die harte Fassung fragt zusätzlich nach,
bevor sie Handarbeit wegnimmt.

**Nicht gemessen:** Nichts davon ist auf einem Gerät gesehen worden. Gerechnet
ist, warum der Wortlaut verlorenging und wie er sich zurückholen lässt;
ungeprüft an echten Daten ist, wie oft die Naht geraten werden muss — das sagt
erst die Zahl in der Vorschau an einem wirklichen Buch.

## Der Absatz gewinnt, der Text wird schmaler (1.0.37)

Fünf Befunde des Nutzers (09/2026), und alle fünf sind am Quelltext
nachzurechnen statt zu plausibeln.

### Trennstellen mitten im Text

> „Ich hatte aber gesagt, dass die Trennstellen dabei nach den Absätzen sein
> sollen. Ich finde aber Trennstellen, die quasi mitten im Text passieren.
> Das möchte ich nicht."

Er hat recht, und die Stelle steht im Quelltext: `Textmass.teilen` trug ein
`mindestfuellung` von 0,62. Die Absatzgrenze galt nur, wenn der Kopf danach
noch 62 Prozent des Kastens füllte — sonst wurde an der WORTgrenze getrennt.

**Diese Abwägung war seit 1.0.35 hinfällig, und das ist der ganze Befund.**
Gebaut wurde sie in 1.0.14 gegen eine große weiße Fläche am Seitenfuß: Damals
bestand eine Seite aus einer Textspalte und darunter aus Fotoreihen, und was
der Text nicht brauchte, blieb Papier. Seither füllt `Mosaik` die Seite — was
der Text nicht braucht, bekommen die Bilder, und `seiteFuellen` nimmt so lange
ein Bild dazu, bis der Platz aufgeht. Die Lücke, gegen die die Regel gebaut
war, gibt es nicht mehr; sie stand nur noch da und hat geschadet.

**Wer eine Regel stehen lässt, deren Grund eine spätere Fassung beseitigt hat,
baut einen Fehler ein, den niemand mehr begründen kann.** Dieselbe Lehre wie
beim Rückbau von 1.0.25 und beim Wegfall von `Seitenrhythmus` (1.0.34) und
`Seitenform` (1.0.35).

Sie ist **ersatzlos entfernt** und nicht auf 0 gestellt: Ein Parameter, der nur
noch einen Wert haben darf, wird irgendwann wieder ein anderer. An der
Wortgrenze wird nur noch getrennt, wo es im Kasten ÜBERHAUPT keine Absatzgrenze
gibt — ein einzelner Absatz, der für sich schon länger ist als der Platz.

**Und diese Stellen werden gezählt** (`Druckpruefung.mittenImSatz`). Sonst wäre
„der Absatz gewinnt" eine Zusage, die sich niemand ansehen kann. Gemessen wird
am ERGEBNIS und nicht an der Absicht: Ein Textblock, der nicht mit einem
Satzzeichen aufhört und dem ein weiterer folgt, endet mitten im Satz.

### Der Text lief über die ganze Seitenbreite

> „Mir fällt auf, dass der Text des Tagebuches in der Regel über die gesamte
> Breite einer Seite geht. Das finde ich nicht gut, denn ich denke, er ist
> besser lesbar, wenn er maximal über zwei Drittel der Seite geht."

`Gestaltung.textspaltenanteil` (Vorgabe 0,66, Regler unter Gestalten → Ränder,
Karte, Seitenzahlen → „Textspalte").

* **Gemessen wird gegen die Satzbreite**, nicht gegen den gerade freien Raum.
  Sonst käme ein Deckel auf den anderen: Bei „Karte neben dem Text" ist die
  Spalte schon auf gut die halbe Satzbreite eingeengt, und zwei Drittel DAVON
  wären ein Streifen. Es ist eine Obergrenze, keine Vorschrift.
* **Eine Zahl, eine Stelle** (`Layoutautomat.satzTextbreite`) — gefragt beim
  Messen für den Plan, beim TEILEN und beim Setzen. Liefen die drei
  auseinander, würde an einer Breite geteilt und in einer anderen gesetzt: Der
  Text wäre anderthalbmal so hoch wie gerechnet und liefe unten heraus.
* **Der Deckel gilt auch im alten Weg** (`textSpalte`, die acht übrigen
  Muster). Ihn nur im Mosaik zu ziehen hieße, dass „Text zuerst" und „Karte
  oben" weiter Zeilen von neunzig Zeichen ergäben.
* **Wie viele Zeichen wirklich auf einer Zeile stehen, misst die App**
  (`Textmass.zeichenJeZeile`, Zeile in der Druckprüfung, gezählt mit demselben
  CoreText-Umbruch, der zeichnet). Eine Einstellung, die sich auf eine
  Behauptung stützt, wäre in diesem Buch die falsche. **Die Spanne 45 bis 75
  Zeichen ist Handwerk des Schriftsatzes und an diesem Buch nicht
  nachgeprüft** — die Zeile sagt das auch.

### Textblöcke im Wechsel mit den Bildern

> „Auch hier wäre es dann gut, vielleicht verschiedene Textblöcke zu haben, die
> sich mit den Bildern abwechseln."

Bis 1.0.36 gab es zwei Lagen — ganz oben oder ganz unten
(`textOben = nummer % 2 == 0`). Damit stand auf jeder Seite ein Block Text und
darunter ein Block Bilder; einen Wechsel gab es nur von Seite zu Seite, nicht
auf der Seite. Die Textreihe ist jetzt eine Reihe unter den anderen: 0 heißt
oben, `reihen.count` unten, alles dazwischen ZWISCHEN zwei Fotoreihen. Gewählt
aus der Seitennummer und nicht gewürfelt.

* **Bricht eine Reihe ab, bricht alles ab** (`abgebrochen`). Die Kacheln liegen
  in einer Folge, und `seiteFuellen` nimmt hinterher die ersten
  `gesetzteKacheln` aus dem Vorrat. Würde Reihe 2 übersprungen und Reihe 3
  gesetzt, wären zwei Bilder vertauscht — still und unauffindbar.
* **`restplatzVerteilen` läuft nur im letzten Abschnitt.** Im oberen liefe die
  gewonnene Luft in den Textblock hinein, und die Funktion kennt ihn nicht.

### Die Punkte auf der Buchkarte waren eine Perlenkette

> „Diese Punkte haben eine bestimmte Farbe und einen Kreis um sich herum. Das
> sieht etwas merkwürdig aus. Ich habe noch keine richtige Lösung dafür."

Am Quelltext abzulesen: Je Punkt wurde ein VOLLER weißer Kreis gezeichnet und
darauf ein farbiger Kern von 58 Prozent des Radius — der Rest war ein weißer
Ring von fast einem Viertel des Durchmessers. Bei dreißig Fotopunkten an einem
Tag übernimmt der die Karte. Gedacht war er als Kontrast (dieselbe Rechnung wie
unter der Linie); als Zeichnung war er zu laut.

**Weil der Nutzer ausdrücklich sagt, er habe noch keine Lösung, ist keiner
seiner drei Auswege weggelassen** (`Spurpunktstil`): `ohne` (nur die Linie),
`dezent` (volle Punkte in der Linienfarbe mit haardünner Kontur — die Vorgabe),
`enden` (nur Anfang und Ziel) und `ring` (der alte, dünner). **Eine Kontur ist
kein Ring:** Sie liegt AUF der Kante und nimmt dem Punkt nichts weg.

`punktstil` steht im `merkmal` des Zwischenspeichers — eine vergessene Stelle
im Schlüssel zeigt nach dem Umstellen das Bild von vorhin, und das sieht aus,
als tue der Schalter nichts.

### Einen Punkt findet man auf der Karte, nicht in der Liste

> „Ich möchte die Reisepunkte auf einer Karte, die möglichst bildschirmfüllend
> ist, auswählen können und verschieben können bzw. löschen können. Innerhalb
> der Liste ist es schwierig, einen bestimmten Punkt wiederzufinden."

Die Karte gab es seit 1.0.20 — bildschirmfüllend, samt Verschieben und Löschen.
Nur der WEG hinein führte über die Liste: `punktID` war ein `let` von außen, und
die Punkte auf der Karte waren `Marker`, also unantastbar.

* **`punktID` ist ein Zustand.** Ein Tipp auf einen Punkt wählt ihn, die Leiste
  nennt ihn beim Namen und sagt, der wievielte er ist; „Neuer Punkt" führt
  zurück. Ohne diesen Rückweg käme man, einmal auf einem Punkt gelandet, nie
  wieder zum Anlegen.
* **Auf der Karte liegt kein Bedienelement** (`.allowsHitTesting(false)`, Lehre
  aus Abfahrtstafel 1.1.18). Den Tipp nimmt die Karte entgegen und sucht
  hinterher den nächsten Punkt — in BILDPUNKTEN und nicht in Grad, denn was
  „nah" heißt, hängt am Maßstab.
* **Verschoben wird über das Fadenkreuz**, nicht durch Ziehen des Punktes. Eine
  Ziehgeste auf einer Karte streitet mit dem Schieben der Karte — und genau
  diese Art Geste hat dieses Projekt von 1.0.5 bis 1.0.8 gekostet.
* **Löschen schließt das Blatt nicht mehr.** Wer Punkte durchsieht, löscht oft
  mehrere.

### Die Broschüre lag drei Ebenen tief

> „Noch nicht gefunden habe ich die gewünschte Option, das Reisetagebuch auf
> dem heimischen Drucker doppelseitig als Broschüre drucken zu können."

Es gibt sie seit 1.0.27, und sie ist vollständig gebaut. Gefunden hat sie
niemand, und daran waren drei Dinge auf einmal schuld: das falsche Menü („…" →
„Als PDF sichern…" klingt nach einer Datei, nicht nach einem Drucker), ein
zugeklappter Picker darüber, und dessen Name „Umfang" — ein Wort, das nach
Seitenzahl klingt.

Jetzt ein eigener Menüpunkt **„Broschüre drucken…"**, sprechende Namen im
Picker und je ein Satz darunter. **Kein zweiter Bildschirm:** derselbe, nur mit
Vorwahl.

**Und sie stand mit dem richtigen Weg in der Bedienungskarte.** Seit 1.0.27,
wörtlich. Gefunden wurde sie trotzdem nicht. **Eine Bedienungskarte ist ein
Nachschlagewerk für jemanden, der etwas Bestimmtes sucht — sie ersetzt keinen
auffindbaren Menüpunkt.**

**Gedruckt wird aus der App heraus** (`Druckauftrag`). Die Datei erst zu
sichern, dann in „Dateien" zu suchen und von dort zu drucken, ist der Umweg um
genau den Knopf herum, um den gebeten wurde. `UIPrintInteractionController`
zeigt sich SELBST — eingebettet in ein SwiftUI-`.sheet` bliebe das Blatt
schwarz. `duplex` ist ein WUNSCH, keine Einstellung: Was der Drucker tut und
über welche Kante er wendet, entscheidet der Mensch im Dialog, und die App kann
es weder setzen noch auslesen.

### Was 1.0.37 NICHT beweist

Keine Seite ist damit gesehen worden. Gerechnet sind die Geometrie und die
Ursachen; **gewählt und nicht gemessen** sind die Vorgabe 0,66 für die
Textspalte (sie ist die Zahl aus der Ansage) und die Maße der Punkte (Radius
`breite/130`, Kontur `breite/900`). Ob eine Doppelseite mit wandernder
Textspalte ruhig wirkt oder unruhig, ob ein dezenter Punkt auf einer bunten
Karte noch zu sehen ist und ob der Systemdruckdialog die Broschüre richtig aufs
Papier bringt, sagt erst der nächste Befund.

## Eine Reihe ist ein Stapel, kein Raster (1.0.36)

Befund des Nutzers 09/2026 zu 1.0.35: „Allerdings ist die Anordnung der Fotos
jetzt schon wieder sehr, sehr nüchtern. Alle sind rechtwinklig ausgerichtet,
keins davon leicht gedreht oder gar so, dass sich eine Ecke überlappt. Das
hätte ich nach wie vor gerne."

Er hat recht, und es war ein Rückschritt: 1.0.34 hatte das Staffeln und Drehen
in `reihenIn` eingebaut — und 1.0.35 hat genau diese Funktion durch das Mosaik
ersetzt, samt der Mechanik darin. **Wer eine Funktion ablöst, zählt vorher auf,
was in ihr steckte.**

**Zwei Fugen, nicht eine.** `Mosaik` kannte bis 1.0.35 einen einzigen Abstand
und benutzte ihn sowohl innerhalb einer Reihe als auch zwischen den Reihen.
Damit ließ sich „zwei Bilder überlappen einander" gar nicht ausdrücken: Ein
negativer Wert hätte auch die Reihen ineinandergeschoben. Seit 1.0.36 gibt es
`quer` (in der Reihe) und `fuge` (zwischen den Reihen).

**Überlappt wird in der Rechnung, nicht erst beim Setzen.** `quer` darf negativ
sein; `reihenhoehe` rechnet dann mit `breite − quer · (n−1)`, die Kacheln
werden dadurch BREITER und die Reihe höher, und die Satzbreite bleibt gefüllt.
Wer die Bilder bloß beim Zeichnen enger rückte, ließe rechts einen Streifen
stehen — also genau das, was 1.0.35 abgestellt hat.

**Der Staffelhub gehört ebenfalls in die Rechnung.** Jede zweite Kachel sitzt
ein Stück höher; das kostet die Reihe Höhe, und `Mosaik.spalte` zieht sie
vorher ab (`staffel`). Gestaffelt wird erst ab zwei Kacheln — ein einzelnes
Bild stünde sonst schief da, ohne dass etwas daneben die Absicht zeigte —, und
diese Bedingung steht in der Rechnung UND beim Setzen gleich.

**Der Winkel kommt aus der Kennung des Fotos**, nie aus dem Zufall: Derselbe
Satz sieht nach jedem Neuanordnen gleich aus. Die Karte wird nicht gedreht —
sie ist eine Auskunft und kein Erinnerungsstück —, und die Bildunterschrift
auch nicht: Sie würde um ihre eigene Mitte gedreht und rückte damit vom Bild
ab. Welches von zwei überlappenden Bildern obenauf liegt, sagt `Block.ebene`.

**Nur in Stilen, die das vertragen** (`Buchstil.lebendig`: Tagebuch, Album,
Postkarte). In einem Magazin wäre ein schiefes Bild ein Fehler.

**Der alte Weg staffelt und dreht wieder mit** (`reihenSetzen`, die acht
übrigen Muster): Ein Tag ganz ohne Text kommt nicht durch das Mosaik.
Überlappt wird dort NICHT — die Breiten rechnet `naechsteReihe` mit der ganzen
Fuge, und zwei Rechnungen nebeneinander liefen auseinander.

### Das Wort, das wie eine Regieanweisung wirkte

Dazu der zweite Befund: „an manchen Stellen steht Text, der wie eine
Regieanweisung wirkt. Ich weiß nicht, wo das herkommt."

Woher, ist am Quelltext abzulesen. Von sich aus schreibt die App auf eine Seite
nur vier Texte: die Seitenzahl, die Kopfzeile, „Kartenbild fehlt" (und das nur,
wo eine Karte fehlt) und — auf dem Bildschirm — den Platzhalter einer leeren
Bildunterschrift. Nur der letzte wiederholt sich, und er hieß bis 1.0.35
„Bildunterschrift …". Eingeschaltet wird die Unterschrift durch einen
**Doppeltipp auf das Foto**, also mit demselben Griff, mit dem man Text
bearbeitet; wer danach nichts schreibt, hat das Wort von da an unter dem Bild
stehen.

Drei Dinge, und keines reicht allein:

* **Statt des Wortes steht dort eine Marke** — eine dünne Linie. Der Grund für
  die Anzeige bleibt richtig: Eine eingeschaltete Unterschrift ohne Text wäre
  sonst eine unsichtbare Fläche, die sich nicht antippen lässt. Falsch war das
  Wort. Ins PDF geht beides nicht.
* **Gezählt wird trotzdem.** Der Block hält weiterhin eine Zeile unter dem Foto
  frei, und gedruckt ist das eine leere Zeile, die niemand bestellt hat.
  `Druckpruefung.leereUnterschriften` nennt Tag und Seite.
* **Und es gibt einen Ausweg**: „…" oben rechts → „Leere Bildunterschriften
  abschalten". Ein Hinweis ohne Weg, ihn aufzulösen, ist die Frage von vorhin
  noch einmal.

### Was 1.0.36 NICHT tut

Text, der ein Foto auf beiden Seiten umfließt, ist weiterhin nicht gebaut — der
Nutzer hat das ausdrücklich hingenommen. Der Grund steht seit 1.0.34 im Papier:
CoreText legt einen Rahmen in ein Rechteck; alles andere verlangte, jede Zeile
einzeln zu setzen, also einen zweiten Umbruch neben dem, mit dem `Textmass`
misst — und der Textblock wäre danach nicht mehr das, was man in dieser App
anfassen, verschieben und teilen kann.

**Nicht gemessen:** Keine Seite ist damit gesehen worden. Gerechnet ist die
Geometrie; gewählt und nicht gemessen sind alle drei Zahlen — die Überlappung
(`−fuge · 1,1`), der Staffelhub (`fuge · 0,9`) und der Winkel (±2,1° aus
1.0.34). Ob eine Doppelseite damit nach „hingelegt" aussieht oder nach
„verrutscht", sagt erst der nächste Befund; ebenso, wie weit die gedrehten
Ecken am Satzspiegel überstehen. Und der Befund zur „Regieanweisung" ist am
Quelltext hergeleitet und nicht am Buch des Nutzers nachgesehen.

## Text ist ein Feld wie ein Foto (1.0.35)

Gemeldet 09/2026 im Vergleich mit einer fremden Foto-App: Dort seien „die
Bilder wesentlich größer und verschenken wesentlich weniger Platz auf der
Seite". Dazu die Diagnose, die diesen Umbau ausgelöst hat:

> „ob ein grundlegendes Problem vielleicht ist, dass du Text auf der einen
> Seite und Bilder auf der anderen Seite als streng getrennte Formate
> betrachtest. Ich glaube, ich hätte gedacht, dass Text ein
> gleichberechtigtes Gestaltungselement einer Seite ist, wie auch ein Foto."

**Er hat recht, und es stand so im Quelltext.** Eine Seite bestand aus einer
TEXTSPALTE und darunter aus FOTOREIHEN. Die sechs Seitenformen aus 1.0.34
(`nurText`, `nurBilder`, `seitlich`, `band`, `reihenOben`, `reihenUnten`)
waren allesamt Antworten auf eine einzige Frage: in welcher REIHENFOLGE Text
und Bilder kommen. Diese Frage gibt es nur, wenn man beide für getrennte
Formate hält.

Dazu kam die zweite Hälfte des Befundes, und die ist reine Geometrie: Die
Höhe einer Fotoreihe rechnete `zielhoehe` allein aus der ZAHL der Kacheln
und sah die Seite nie an. Was unten übrig blieb, verteilte
`restplatzVerteilen` in die Lücken zwischen den Reihen. **Damit war weißer
Platz der Normalfall und ein großes Bild der Ausnahmefall.**

### Die Umkehrung (`Model/Mosaik.swift`)

1. **Eine Seite ist eine Spalte aus Reihen, die zusammen die volle Satzhöhe
   ergeben.** Nicht die Zahl der Bilder bestimmt ihre Höhe, sondern der
   Platz, der da ist. Gesucht wird über die ZAHL der Reihen (eins bis vier)
   und nicht über eine Formel: Eine größere Zielhöhe nimmt Kacheln aus den
   Reihen heraus und kann damit eine Reihe MEHR ergeben — der Zusammenhang
   ist nicht monoton. Gewertet wird die **Dehnung**: Am besten ist die
   Aufteilung, die am wenigsten gedehnt oder gestaucht werden muss.
2. **Ein Textfeld ist eine Kachel in einer dieser Reihen**, mit derselben
   Höhe wie die Fotos daneben. Seine Breite ist die eine Unbekannte: Ein
   Text hat kein festes Seitenverhältnis, sondern zu jeder Breite eine
   gemessene Höhe. `Mosaik.mischreihe` probiert zwölf Breiten zwischen 30
   und 70 Prozent der Satzbreite durch und nimmt die, bei der die Fotohöhe
   gerade noch über der Texthöhe liegt — dann steht der Text vollständig in
   der Reihe und darunter bleibt nichts liegen. Jede Stufe kostet genau eine
   Messung; eine Umkehrfunktion gibt es nicht, weil die Texthöhe von Zeile
   zu Zeile springt.
3. **Wie viele Bilder auf eine Seite gehören, entscheidet der Platz.**
   `Tagesplan` macht einen Vorschlag aus der Verteilung über die Tage; ob er
   aufgeht, weiß erst die Seite. Bleibt zu viel Luft, kommt ein Bild dazu;
   wird es zu eng, geht eines zurück. Das ist die Antwort auf „verschenkt
   wesentlich weniger Platz": Nicht die Zahl der Bilder bestimmt den Satz,
   sondern der Platz bestimmt die Zahl der Bilder.

### Die Dehnung ist gedeckelt

Was nach der besten Aufteilung noch fehlt, wird auf die Reihen verteilt: Ein
Foto wird dann ein wenig höher, als sein Verhältnis vorgibt, und verliert
seitlich etwas — der Rahmen wird ja GEFÜLLT und nicht eingepasst. Gedeckelt
ist das auf **1,22**, also gut 18 Prozent der Breite. Mehr wäre genau der
Ausschnitt, den 1.0.34 am Aufmacherband abgestellt hat („Ein Band folgt dem
Seitenverhältnis, sonst ist es ein Ausschnitt"). Reicht der Deckel nicht,
bleibt der Rest als Luft zwischen den Reihen stehen: Lieber etwas Weiß als
ein Bild, dem ein Fünftel fehlt.

### Was daraus von selbst folgt

* **Text neben einem Foto** ist kein Sonderfall mehr, sondern das Ergebnis
  einer kurzen Textmenge neben einem Bild.
* **Eine reine Bilderseite** entsteht, wo kein Text mehr wartet — und in der
  bilderreichen Gangart bleibt der Text jetzt ganz auf der ersten Seite
  (Ansage des Nutzers: „den Text nicht noch weiter auseinanderzuziehen").
* **Ein Text über die volle Breite** entsteht, wo er mehr als die halbe
  Seite braucht — ein Foto daneben wäre dort eine Briefmarke.

### Nicht gemessen

**Keine Seite ist damit gesehen worden.** Gerechnet ist die Geometrie: dass
die Reihen die Satzhöhe treffen, dass die Textbreite gefunden wird und dass
die Dehnung beschnitten bleibt. Wie eine Doppelseite AUSSIEHT, sagt erst der
nächste Befund. Gewählt und nicht gemessen sind: die Dehnungsgrenze 1,22,
die Spanne der Textbreite (30 bis 70 Prozent), die zwölf Stufen, die Schwelle
von 56 Prozent Seitenhöhe, ab der der Text die volle Breite bekommt, und die
Reihenzahl eins bis vier. **Ungemessen ist auch, was die Rechnung kostet:**
Je Seite fallen bis zu zwölf CoreText-Messungen für die Textbreite an, dazu
je Anlauf der Bildzahl eine neue Aufteilung — das läuft beim Neuanordnen und
nicht beim Zeichnen, aber gesehen hat es niemand.

## Die Seite entsteht aus dem Inhalt des Tages (1.0.34)

Gemeldet 09/2026, mit zwei Bildschirmfotos eines ausgegebenen Buches und
einem Befund, der genauer war als jede Vermutung von hier: Es habe den
Eindruck, als werde nur ein vorgegebenes Design mit sechs unterschiedlichen
Seiten der Reihe nach abgespult, ohne darauf zu achten, wie der konkrete
Inhalt eines Tages wirklich ist — und genau das wäre die Stärke der App: für
jeden Tag flexibel zu entscheiden, wie die beste Anordnung sein könnte.

**Er hatte recht, und es stand wortwörtlich so im Quelltext.**
`Seitenrhythmus` war eine Liste von sechs Seitenbildern, durchlaufen mit
`(seite + versatz) % 6`. Wie viel Text der Tag hat, wie viele Bilder und ob
sie hoch oder quer stehen, ging in diese Wahl mit keinem einzigen Wert ein.
Die Datei ist ersatzlos entfernt und nicht auf einen Sonderfall
zurückgestellt: Ein Mechanismus, dessen Grund widerlegt ist, bleibt nicht
liegen.

### Erst messen, dann planen, dann setzen

An ihrer Stelle steht `Model/Tagesplan.swift`. Gemessen werden zwei Höhen —
wie hoch der Text über die volle Satzbreite wird (`Textmass.hoehe`) und wie
hoch alle Bilder zusammen werden, wenn man sie in Reihen setzt
(`Layoutautomat.stapelhoehe`). Beide kommen aus denselben Funktionen, die
hinterher auch setzen; eine zweite Schätzung daneben liefe auseinander, und
dann hielte die Seite nicht, was der Plan sagt.

Aus dem VERHÄLTNIS der beiden folgt die **Gangart**, aus ihrer SUMME die Zahl
der Seiten. Das sind genau die drei Fälle, die der Nutzer genannt hat:

* **bilderreich** (unter einem Fünftel Text) — „Dann habe ich vielleicht 25
  Fotos und nur 5 Sätze Text. Dann bietet es sich vielleicht doch an, eine
  reine Bilderseite zu machen, und den Text nicht noch weiter
  auseinanderzuziehen." Der Text bleibt beisammen, danach dürfen reine
  Bilderseiten stehen.
* **ausgewogen** — „Ich habe 20 Fotos und einen sehr langen Text. Das
  verteile ich einigermaßen gleichmäßig auf die Seiten. So dass immer Bilder
  und Text auf jeder Seite sind. Das Design wechsle ich dabei ab." Jede Seite
  bekommt ihren Anteil an beidem, und die Stellung wechselt.
* **textreich** (über sieben Zehnteln Text) — „bei sehr viel Text und wenig
  Bildern wird es bestimmt auch eine Möglichkeit geben, diese so anzuordnen,
  dass der Text sie umfließt."

**Die Zahl der Seiten ist eine Schätzung mit Absicht.** Sie steuert die
Verteilung und ist keine Zusage: Geht am Ende doch mehr hinein oder weniger,
setzt der Automat weiter, und was übrig ist, kommt auf eine zusätzliche
Seite. Wie viele Kacheln auf die Seite gehören, wird bei JEDER Seite neu aus
dem gerechnet, was noch offen ist — nicht aus einer beim Start festgelegten
Liste. Damit bleibt die Verteilung gleichmäßig, auch wenn eine Seite mehr
aufgenommen hat als geplant.

**Nichts daran ist gewürfelt, und nichts hängt an der Kennung des Tages.**
Derselbe Inhalt ergibt denselben Satz. Die Abwechslung kommt jetzt aus dem
Inhalt und aus dem Wechsel der Seitenstellung — nicht aus einem Katalog.

### Die fünf gemeldeten Seiten

**Seite 3/4 — „Das einzige Foto … erscheint nun super groß auf einer leeren
Seite 4. Dabei wäre auf Seite 3 noch Platz gewesen."** Zwei Ursachen, beide
am Quelltext nachzurechnen. Erstens bekam der Text die ganze Seite, obwohl
noch ein Bild für sie vorgesehen war: Freigehalten wurde nur, wenn Reihe UND
sechs Zeilen Text danebenpassten, und sonst gar nichts. Zweitens brach die
Seite um, sobald die nächste Reihe in ihrer ZIELHÖHE nicht mehr hineinpasste
— und auf der neuen, leeren Seite durfte dieselbe Reihe dann wachsen. Eine
Reihe ist aber kein festes Maß: Ihre Höhe folgt aus der Zielhöhe, und die
lässt sich für diese eine Reihe senken. **Eine Reihe schrumpft jetzt, bevor
sie umbricht** (`reihenIn`), und der Text wird gedeckelt, solange Bilder für
diese Seite vorgesehen sind.

**Seite 5 — „ein Ausschnitt eines Fotos auf die ganze Seitenbreite gezogen.
Das macht keinen Sinn."** Das war das Aufmacherband aus 1.0.32: Höhe fest bei
gut einem Drittel der Satzhöhe, Breite fest bei voller Satzbreite. Ein
Hochformat wurde damit zu einem Streifen quer durch das Bild — der Rahmen
wird ja gefüllt, nicht eingepasst. Ein Band folgt jetzt dem
Seitenverhältnis: Gedeckelt wird die HÖHE, was an Breite fehlt, bleibt Rand,
und ein Band bekommt nur ein Querformat.

**Seite 6 — „könnte zumindest eins der Fotos noch neben den Text gezogen
werden und die anderen Fotos entsprechend verteilt."** Neue Seitenform
`seitlich`: ein Hochformat in einer Spalte am Rand, der Text daneben und
DARUNTER über die volle Breite weiter, die übrigen Bilder als Reihe unten.
Die Seite wechselt die Kante, damit zwei solche Seiten hintereinander nicht
wie ein Doppeldruck aussehen.

**Seite 7/8 — „sind plötzlich drei Fotos schnurgerade nebeneinander" und
„nur drei Fotos".** Drei gleich hohe Bilder in einer Flucht sind ein Raster
und kein Satz: In Stilen, die das vertragen (`Buchstil.lebendig` — Tagebuch,
Fotoalbum, Postkarte), liegen die Kacheln einer Reihe wieder gegeneinander
versetzt und leicht gedreht, immer mit demselben Winkel je Bild. Und eine
Reihe, die ihre Zielhöhe nicht erreicht, steht MITTIG statt linksbündig: Ein
einzelnes Bild an der linken Kante sieht aus wie der Rest einer Reihe.

### Umflossen wird in einem L — und warum nicht ringsum

Der Text legt sich um das Bild, indem er in ZWEI Blöcken steht: eine schmale
Spalte neben dem Bild, darunter die volle Breite. Ein Bild, das auf BEIDEN
Seiten Text hat, ist bewusst nicht gebaut, und das ist keine Bequemlichkeit:
CoreText legt einen Rahmen in ein Rechteck, für alles andere müsste jede
Zeile einzeln gesetzt werden — mit einem zweiten Umbruch neben dem, mit dem
`Textmass` misst, also genau der Fehler, den dieses Papier an anderer Stelle
beschreibt. Und der Textblock wäre danach nicht mehr das, was man in dieser
App anfassen, verschieben und teilen kann. Zwei Blöcke sind hier das
ehrlichere Mittel: Sie messen und zeichnen mit demselben Satz wie jeder
andere Text.

### Das Muster heißt jetzt „Nach Inhalt gesetzt"

`Seitenmuster.wechsel` ist kein Sonderfall mehr für Tage mit sehr viel Text
UND sehr vielen Bildern (bis 1.0.33: über 1200 Zeichen, mindestens vier
Fotos), sondern der REGELFALL für jeden Tag, der Text und Bilder hat. Genau
an dieser Schwelle scheiterte der 3. August im gemeldeten Buch: ein Tag mit
Text und EINEM Foto fiel durch, landete bei einem Muster ohne Planer, und
dessen Bild stand allein auf der nächsten Seite. Ohne Text oder ohne Bild
greift das Muster weiterhin nicht — dann gibt es nichts zu verteilen, und
die eigenen Bildideen der übrigen acht Muster sind die bessere Antwort.

### Nicht gemessen

**Keine Seite ist damit gesehen worden.** Gerechnet ist, WARUM das Foto auf
der leeren Seite landete, warum das Band ein Ausschnitt wurde und was der
Rhythmus mit dem Inhalt zu tun hatte (nichts). Wie eine Doppelseite im neuen
Plan AUSSIEHT, sagt erst der nächste Befund. Gewählt und nicht gemessen sind
alle Zahlen darin: die beiden Gangart-Schwellen (0,20 und 0,72), die
Spaltenbreite des seitlichen Bildes (0,40 der Satzbreite), seine Höhe
(höchstens 0,46 der Satzhöhe), die Bandhöhe (0,40), der Zuschlag von einem
Viertel auf den Textanteil je Seite und die Schwelle von zwölf Zeilen, ab der
ein Bild neben den Text darf. **Und es sind mehrere Dinge auf einmal
geändert** — die sonst geltende Regel, eine Sache auf einmal zu ändern, ist
hier bewusst gebrochen: Die fünf gemeldeten Seiten haben eine gemeinsame
Ursache, und fünf Fassungen nacheinander hätten sie einzeln kuriert, ohne sie
zu beheben.

## Seiten von Hand, und ein Buch zweimal (1.0.33)

Zwei Ansagen, und die erste hat einen stillen Fehler mit ans Licht gebracht.

### „Seiten an bestimmten Stellen hinzufügen oder löschen"

Es gab dafür zwei halbe Wege. **„Seite anfügen"** im Tagesmenü hängte immer
HINTEN an — wer zwischen der zweiten und der dritten Seite Platz brauchte,
musste die Seite am Ende anlegen und alles von Hand dorthin schieben. Und
**„Diese Seite entfernen"** stand im Block-Inspektor, also dort, wo man einen
Block bearbeitet, und galt nur für die Seite, auf der der gewählte Block
gerade liegt. Eine bestimmte Stelle ließ sich so gar nicht ansprechen.

Jetzt: **Tagesmenü → „Seiten…"**. Eine Liste, die jede Seite mit ihrer Nummer
nennt und sagt, was darauf steht („2 Texte · 3 Fotos"). Eine Nummer ist die
einzige Angabe, mit der sich eine Stelle benennen lässt; Miniaturbilder wären
hübscher und beantworteten die Frage nicht. Darin:

* **Davor einfügen** (Wischen nach rechts oder Kontextmenü),
* **danach einfügen**,
* **entfernen** (Wischen nach links),
* **Reihenfolge ziehen** über „Bearbeiten",
* **am Ende anfügen** als sichtbarer Knopf unter der Liste.

Die letzte Seite eines Tages bleibt stehen: Ein Tag ohne Seite wäre ein Loch
im Buch, und `fehlendeSeitenNachholen` setzte ihn beim nächsten Öffnen
ohnehin neu.

### Der Fehler dahinter: eine leere Seite war keine Handarbeit

`Seite.vonHand` war ausschließlich **gerechnet** — „irgendein Block auf dieser
Seite wurde angefasst". Eine von Hand eingefügte **leere** Seite trägt aber
keinen Block. Sie galt damit als unberührt, und das nächste Neuanordnen des
Tages räumte sie weg, ohne ein Wort. „Seite anfügen" war seit 1.0.0 eine
Zusage, die beim nächsten Handgriff daneben zurückgenommen wurde.

Daneben steht jetzt ein **gespeicherter** Vermerk (`vonHandAngelegt`). Er
steht an der SEITE und nicht am Tag, weil `Seite.vonHand` die eine Stelle
ist, durch die alles fragt — `hatHandarbeit`, `alleNeuAnordnen`,
`handarbeitstage`, die Marke in der Tagesliste, die Rückfrage beim
Stilwechsel. Ein zweites Feld am Tag müsste an jeder davon einzeln beachtet
werden, und die eine vergessene Stelle wäre wieder ein stiller Verlust.
Entfernen und Verschieben setzen ihn ebenfalls: Wer an der Seitenfolge
arbeitet, hat von Hand gearbeitet.

Was das kostet, steht unter der Liste: Der Tag wird danach beim
automatischen Neuanordnen übersprungen. Wer das nicht weiß, hält den
Automaten für kaputt.

### „Ich möchte ein Projekt duplizieren können"

Im Regal über Wischgeste und Kontextmenü, im offenen Buch unter „…". Ein
Buch ist **zweierlei**: eine JSON-Datei und ein Ordner voller Bilder, und
kopiert werden müssen beide. Ein Buch mit fremdem Bilderordner wäre eine
Zeitbombe — `Ablage.loeschen` räumt den Ordner der Reise mit weg, wer also
die Kopie löscht, nähme dem Urbuch alle Fotos mit, und zwar still: Das Buch
öffnet sich ja weiterhin.

* **Die inneren Kennungen bleiben.** Tage, Seiten, Blöcke und Fotos gelten
  innerhalb eines Buches, und zwei Bücher sehen einander nie. Mehr noch — sie
  müssen bleiben, denn Papierkorn und Seitenrhythmus rechnen aus `UUID.saat`;
  mit neuen Kennungen sähe die Kopie anders aus als das Urbuch. Neu ist genau
  eine Zahl: die der Reise, denn die ist der Dateiname.
* **Halb kopiert wird zurückgenommen.** Scheitert das Sichern, wird der schon
  angelegte Bilderordner wieder weggeräumt.
* **Die Bilder gehen abseits des Hauptfadens.** Ein Buch mit zweihundert
  Fotos wiegt ein Gigabyte; auf dem Hauptfaden stünde die App währenddessen
  still, und für den Menschen davor wäre sie abgestürzt.
* Der Titel bekommt „(Kopie)", beim zweiten Mal „(Kopie 2)" — im Regal sieht
  man die Kennung nicht, und zwei gleich heißende Bücher wären nicht
  auseinanderzuhalten.

### Nicht gemessen

Nichts davon ist auf einem Gerät gesehen. Gerechnet ist, warum eine leere
Seite verschwand; dass sie jetzt stehen bleibt, folgt daraus. Wie lange das
Kopieren eines Buches mit zweihundert Fotos dauert, ist **nicht gemessen** —
und ob `FileManager.copyItem` dabei eine APFS-Kopie anlegt oder die Bytes
wirklich verdoppelt, ebenso wenig.

## Tagebuch ist ein Stil — und die letzte Seite wird gefüllt (1.0.32)

Drei Befunde des Nutzers zu 1.0.31, und der erste ist der wichtigste.

### „Die Option Tagebuch finde ich nach wie vor nicht"

Es gab sie seit 1.0.29 — als **Seitenmuster**, also hinter dem Tagesmenü,
dort, wo man einen einzelnen Tag anders setzen lässt. 1.0.31 hat dieses Menü
findbar gemacht (Datum auf dem Knopf, der Menüpunkt nennt seinen eigenen
Stand), und der Nutzer hat es trotzdem nicht gefunden. Er hat auch gesagt,
wo er sucht: „da, wo ich Fotobuch und Magazin auswählen kann."

**Er hat nicht an der falschen Stelle gesucht — es lag an der falschen.**
Ein durchgehend erzählendes Buch ist eine Handschrift und kein Sonderfall
eines Tages. „Tagebuch" ist seit 1.0.32 ein **Stil** und steht als sechster
in der Liste, vor Magazin. Fünfte Auflage von „es war da, man fand es
nicht" — und die erste, bei der nicht der Weg zu kurz war, sondern die
Zuordnung falsch. Wird etwas zum zweiten Mal nicht gefunden, ist nicht der
Weg dorthin zu prüfen, sondern die Zuordnung.

Der Stil setzt warmes Papier, Iowan Old Style für Titel und Fließtext, ein
gesperrtes Datum in Braun, weite Fugen und `lebendig` — Bilder dürfen also
leicht gegeneinander versetzt und eine Spur gedreht liegen. Das Muster
`.wechsel` steht bei ihm an erster Stelle; es steht das auch in allen fünf
anderen Stilen, greift dort aber erst ab 1200 Zeichen und vier Fotos. Der
Unterschied zwischen den Stilen ist nicht das Muster, sondern Schrift,
Papier, Fugen und Lebendigkeit.

Dazu heißt `Seitenmuster.wechsel` nicht mehr „Tagebuch: Text und Bilder im
Wechsel", sondern nur noch „Text und Bilder im Wechsel": Zwei Dinge mit
demselben Namen sind eines zu viel.

### „Sehr nüchtern, und es wird häufig Platz verschenkt"

Zwei Sachen, und beide sind am Quelltext nachzurechnen.

**Ein Tag fing nicht mit einem Bild an.** Kopfzeile, Textspalte, darunter
eine Reihe gleich hoher Bilder — richtig gesetzt und wie ein Bericht. Im
Muster `.wechsel` steht jetzt unter der Kopfzeile ein **Aufmacherband** über
die ganze Satzbreite, auch wenn die Textspalte darunter schmaler ist: Genau
dieser Unterschied macht es zum Aufmacher. Es kostet ein Foto aus dem
Vorrat, deshalb erst ab dreien — bei zweien wäre die Reihe darunter leer,
und der Tag sähe ärmer aus statt reicher.

**Die letzte Seite eines Tages war die verschenkte.** `zielhoehe(fuer:)`
leitet die Reihenhöhe allein aus der ZAHL der Kacheln ab und sieht die Seite
nie an. Solange viele Bilder warten, ist das richtig — die nächste Reihe
füllt ohnehin nach. Auf der letzten Seite warten aber oft nur noch zwei oder
drei: Eine Reihe steht oben, darunter bleibt die halbe Seite weiß. Und
`restplatzVerteilen` hilft dort **prinzipiell nicht** — es verteilt die
Lücken ZWISCHEN den Reihen, und bei einer einzigen Reihe gibt es keine.

`ausfuellendesZiel` fragt deshalb zu Beginn jeder Seite nach:

* **Vergrößert wird nur, wenn ALLES Offene auf diese eine Seite passt und
  kein Text mehr wartet.** Sonst gehört der Platz dem Text, bzw. die nächste
  Reihe füllt die Seite ohnehin. Damit ist die Änderung eng auf den
  gemeldeten Fall begrenzt und lässt jede andere Seite, wie sie war.
* **Gesucht wird in Schritten, nicht gerechnet.** Eine größere Zielhöhe nimmt
  Kacheln aus den Reihen heraus und kann damit eine Reihe MEHR ergeben — der
  Zusammenhang ist nicht monoton, eine geschlossene Formel gäbe es nicht.
  Gehalten wird der letzte Wert, der nachweislich passte.
* **Gemessen wird mit derselben Funktion, die auch setzt** (`naechsteReihe`,
  samt Staffelhub). Eine zweite Schätzung daneben liefe auseinander, und dann
  hielte die Seite nicht, was die Probe sagt.

### „Ich möchte das frei entscheiden können"

Bis 1.0.31 wurden von Hand bearbeitete Tage beim Stilwechsel **immer**
verschont. Die Vorsicht ist richtig — eine Automatik, die eine Stunde
Handarbeit ohne Rückfrage überschreibt, benutzt man genau einmal. Falsch
war, daraus eine Regel zu machen: Wer den Stil wechselt, will das ganze Buch
anders haben, und dann stehen ein paar Seiten im alten Satz mitten darin.

Gefragt wird weiterhin, nur ist die Antwort jetzt eine Wahl: „Bearbeitete
Seiten behalten" oder „Alles neu setzen". **Eine Rückfrage, die nur eine
Antwort zulässt, ist keine Rückfrage.** Die Meldung nennt die Zahl der
betroffenen Tage — „an einigen Tagen" lässt einen raten, ob es um einen geht
oder um zwanzig — und weist auf „Widerrufen" hin. Gezählt wird beim Tipp und
nicht im Körper der Ansicht; ein Lauf über alle Tage und Seiten gehört nicht
in etwas, das bei jedem Neuzeichnen läuft.

### Nicht gemessen

Keine Seite ist damit gesehen worden. Gerechnet ist, WARUM unten Platz
blieb; dass die Seite jetzt gefüllt aussieht, folgt aus der Geometrie. Die
Zahlen sind gewählt und nicht gemessen: ein Drittel der Satzhöhe fürs Band,
Deckel 2,2 und Schrittweite 1,05 beim Füllen, die Schwellen 600 Zeichen und
drei Fotos. Ob der neue Stil auf einem Gerät nach Tagebuch aussieht, sagt
erst der nächste Befund.

**Zwei Dinge auf einmal geändert** (Aufmacher und Füllung). Das ist hier
vertretbar, weil sie sich auf der Seite nicht verwechseln lassen: ein
breites Bild oben ist der eine, größere Reihen unten der andere.

## Keine zwei Seiten gleich — und der Streifen gehört der Reihe (1.0.31)

Zum dritten Mal dieselbe Sache (09/2026): „Ein langer Text soll
abschnittsweise auf mehrere Seiten verteilt werden und die Bilder
entsprechend auch auf die zusätzlichen Seiten sortiert werden. Dabei soll
nicht jede Seite gleich aussehen, sondern es immer abwechselnd
unterschiedlich gestaltet sein. Mal soll der Textblock oben links sein, mal
in der Mitte, mal leicht verschoben, vielleicht auch sogar einmal gedreht."
Dazu: „Die angekündigte Option Tagebuch, Text und Bilder im Wechsel finde
ich nicht."

Drei Befunde in einer Meldung, und jeder hat eine eigene Ursache.

### Der freigehaltene Streifen wurde wieder mit Text gefüllt

Das ist die Ursache für das Bildschirmfoto: oben ein voller Textblock,
unten weißer Rest, die Bilder eine Seite weiter. Sie ist am Quelltext
nachzurechnen:

* `.wechsel` hält auf der ersten Seite die **gemessene Höhe der nächsten
  Fotoreihe** frei (so seit 1.0.29) und übergibt an `reihenSetzen`.
* `reihenSetzen` prüft zu Beginn jeder Seite selbst, ob neben einer
  Fotoreihe noch **sechs Zeilen Text** Platz haben. Auf genau diesem
  Streifen haben sie das nicht — also gab die Prüfung null zurück, und der
  ganze Rest der Seite ging an den Text.
* Ging dem Text dabei die Luft aus, blieb unten Weiß stehen, und die
  Fotoreihe passte nicht mehr: neue Seite, nur Bilder.

**Wer Platz für ein Bild freihält, stellt das Bild auch hinein.** Reicht die
Resthöhe für eine Reihe, aber nicht für Reihe und sechs Zeilen, bekommt sie
jetzt die **Reihe** und nicht der Text.

### Jede Seite hatte dasselbe Seitenbild

Verteilt wurde seit 1.0.14; was fehlte, war das Zweite: Textspalte über die
volle Satzbreite, darunter randbündige Fotoreihen — Seite für Seite
dasselbe. Ein Buch, dessen Seiten sich nur im Inhalt unterscheiden, ist
gesetzt wie eine Tabelle.

`Model/Seitenrhythmus.swift` gibt jeder Seite eines Tages ein eigenes
**Seitenbild**: die Textspalte zwischen 58 und 100 Prozent der Satzbreite,
an der linken oder rechten Kante, die Fotoreihe ebenso, dazu in den Stilen
**Fotoalbum** und **Postkarte** leicht gedrehte und gegeneinander versetzte
Bilder und eine Spur Schräge am Textblock.

* **Bestimmt, nicht gewürfelt.** Sechs Seitenbilder in fester Folge; der
  Einstieg kommt aus der Kennung des Tages (`UUID.saat`), damit nicht jeder
  Tag mit demselben Bild beginnt. **Nie aus `hashValue`** — den streut Swift
  bei jedem Programmlauf neu, und dasselbe Buch sähe nach jedem Start anders
  aus (dieselbe Regel wie beim Drehwinkel eines Albumfotos und beim
  Papierkorn aus 1.0.16).
* **Die Folge ist eine Folge, keine Menge.** Auf eine volle Breite folgt
  eine schmale, auf einen linken Block ein rechter. Wer etwas einfügt, sieht
  die Liste als Reihenfolge an.
* **Die Spanne ist eng mit Absicht.** Was es NICHT gibt, ist ein frei im
  Blatt schwebender Kasten: Ein Buch, dessen Ränder von Seite zu Seite
  springen, wirkt nicht lebendig, sondern unfertig.
* **Gedreht wird nur, wo es hingehört** (`Buchstil.lebendig`). In einem
  Magazin wäre ein schiefes Bild ein Fehler, in einem Album fehlte es. Die
  Drehung des TEXTBLOCKS ist auf 0,6 Grad gedeckelt — über 400 Punkt Breite
  sind das gut zwei Punkt an der Ecke; ein schief laufender Fließtext liest
  sich sonst nicht als Absicht, sondern als Druckfehler. Die gehobene Ecke
  wird der Blockhöhe **zugerechnet**, statt sich darauf zu verlassen, dass
  es schon passen wird.
* **Den Rhythmus bekommt NUR `.wechsel`.** Die übrigen Muster sind je eine
  eigene Bildidee (ein Vollbild, eine Karte neben dem Text, ein
  Bilderbogen); wandernde Spalten würden dort mit der Idee des Musters
  streiten. Es wird eine Sache auf einmal geändert.

### Und gefunden hat das Muster niemand

Fünfte Auflage des alten Befundes, diesmal doppelt: Der Menüpunkt hieß
**„Seitenmuster"** — ein Fachwort statt einer Frage — und lag hinter einem
Knopf, der nur ein **Kalendersymbol** trug, also einer von vier gleich
aussehenden Kreisen in der Werkzeugleiste war. Dass darin alles zu genau
diesem Tag steht, war nirgends zu sehen.

* Der Knopf trägt jetzt das **Datum** sichtbar neben dem Symbol.
* Der Menüpunkt heißt **„Seiten setzen: …"** und nennt, was gerade gilt —
  ausdrücklich gewählt oder „automatisch (Tagebuch: Text und Bilder im
  Wechsel)". **Ein Menü, das seinen eigenen Stand verschweigt, lässt einen
  raten** — und genau daran ist die Frage entstanden, ob es das Muster
  überhaupt gibt.
* **„Für ALLE Tage übernehmen"** steht dort, wo die Frage entsteht — wer es
  für einen Tag einstellt, ist die Person, die als Nächstes „und für alle?"
  fragt (dieselbe Lehre wie beim Fotostil in 1.0.10). Tage mit Handarbeit
  bleiben dabei stehen und werden gezählt: Ein Musterwechsel, der eine
  Stunde Handarbeit stillschweigend wegräumt, wird genau einmal benutzt.

## Alle Fotos auf einmal, und keines mehr in der Ablage (1.0.30)

Zwei Beschwerden in einer Nachricht (09/2026): „Beim Foto-Import muss ich
bislang die Fotos einzeln auswählen. Ich möchte, dass sie alle ausgewählt
werden können. Das Importmodul sagt mir, dass Fotos automatisch auf die Tage
verteilt werden und wenn das Datum fehlt, dann liegen sie in der Ablage. Das
möchte ich nicht. Ich möchte, dass bei einem fehlenden Datum der Tag einfach
automatisch angelegt wird."

### Alle auf einmal ist nicht der Wähler, sondern der Zeitraum

Apples Fotowähler kennt keinen Knopf „alle auswählen", und eine App kann ihm
keinen einbauen: `PHPickerViewController` läuft in einem EIGENEN Prozess —
genau das ist der Grund, warum er ohne Mediathekserlaubnis arbeiten darf. Die
Mehrfachauswahl war übrigens nie beschränkt (`selectionLimit = 0` steht seit
1.0.0 dort); was fehlt, ist der eine Knopf, und der gehört nicht uns.

Also wird nicht nach Bildern gefragt, sondern nach einem **Zeitraum** — und
das ist für ein Reisetagebuch ohnehin die richtige Frage: Eine Reise IST ein
Zeitraum. `Dienste/Zeitraumeinfuhr.swift` fragt die Mediathek mit einem
Prädikat auf `creationDate` und gibt die Treffer in ihrer Aufnahmereihenfolge
zurück.

* **Gezählt wird, bevor etwas geladen wird.** Die Zeile „Gefunden: 1284
  Fotos" steht unter den beiden Datumsfeldern und kostet keine einzige
  Bilddatei. Ohne sie wäre der Knopf ein Sprung ins Dunkle.
* **Geholt wird Foto für Foto.** Tausend Rohbilder auf einmal sind mehrere
  Gigabyte und passen nicht in den Arbeitsspeicher. `fotosAufnehmen` gibt es
  deshalb seit 1.0.30 in zwei Fassungen, und die eine ruft die andere: Die
  Liste ist der gewöhnliche Weg, der Strom der für Zeitraum und Fotowähler.
  **Es gibt trotzdem nur EINE Stelle, an der ein Rohbild zu einem `Foto`
  wird** — zwei liefen auseinander.
* **Auch der FOTOWÄHLER geht jetzt über den Strom.** Er sammelte bis 1.0.29
  erst alle Rohbilder in einer Liste — tragbar, solange man Fotos einzeln
  antippt, und nicht mehr tragbar, seit der Wunsch ausdrücklich „alle"
  lautet: Fünfhundert ausgewählte Bilder wären ein Gigabyte im
  Arbeitsspeicher, bevor das erste auf der Platte liegt.
* **`isNetworkAccessAllowed = true`, ausdrücklich.** Ein Foto kann in iCloud
  liegen und nicht auf dem Gerät. Ohne diese Zeile käme gar nichts zurück,
  ohne Fehler und ohne Erklärung — der Zeitraum sähe halb leer aus.
* **`requestImageDataAndOrientation` darf seinen Rückruf mehrmals aufrufen.**
  Ein zweites `resume` an einer `CheckedContinuation` ist kein Fehler,
  sondern ein ABSTURZ. Deshalb der Wächter `Einmal`.
* **Der Zeitraum wird am `creationDate` gemessen, und das ist ein Augenblick
  auf der Weltuhr.** Die Grenzen entstehen in der GERÄTEZONE — dieselbe
  ausdrückliche Ausnahme wie beim Datum aus der Mediathek. Wer in Toronto
  fotografiert und zu Hause einliest, kann an den Rändern einen Tag
  danebenliegen; deshalb ist der Zeitraum frei wählbar und nicht fest.
* **Bei `.limited` liefert die Abfrage nur die freigegebenen Fotos.** Das ist
  kein Fehler, aber es sieht aus wie einer, wenn es niemand sagt — die
  Fußzeile sagt es.
* **Der Fotowähler bleibt.** Ohne Mediathekserlaubnis geht der Zeitraum gar
  nicht; der Wähler ist deshalb nicht der Notbehelf, sondern der Weg für alle
  anderen Fälle.

### „Wenn das Datum fehlt" war zweierlei

Der TAG wurde immer schon angelegt: `Reise.tagIndex(fuer:)` hängt einen neuen
Reisetag an, sobald ein Foto ein Datum trägt, das es im Buch noch nicht gibt.
In die Ablage kam nur, was **gar kein** Datum trägt. Die Fußzeile des
Einlesen-Blattes sagte das so verkürzt, dass es wie das Gegenteil klang; sie
ist neu geschrieben.

Bleibt der Fall, um den es wirklich geht — und der bekommt zwei Antworten:

* **Eine dritte Datumsquelle: der DATEINAME** (`Dienste/Namensdatum.swift`).
  Der häufigste Grund für ein fehlendes EXIF-Datum ist kein fehlendes Datum,
  sondern eine Datei, die durch einen Messenger, einen Bildbearbeiter oder
  eine Ausfuhr gelaufen ist: Die Metadaten sind weg, der NAME steht noch da,
  und Kameras schreiben das Datum hinein (`IMG_20260812_193321.jpg`,
  `PXL_20260812_173321123.jpg`, `2026-08-12 19.33.21.jpg`, `Foto
  12.08.2026.jpg`). Gelesen wird nach derselben Regel wie überall: **Der Tag
  kommt aus drei Zahlen** — ein Dateiname trägt Ziffern und keine Zeitzone,
  hier wird nichts umgerechnet.
* **Geraten wird dabei NICHT.** Erkannt werden drei Schreibweisen
  (`2026-08-12` mit Trenner, `12.08.2026`, und `20260812` bzw.
  `20260812193321` am Stück); eine Ziffernfolge anderer Länge wird nicht
  beschnitten, und das Jahr muss zwischen 1990 und 2100 liegen — enger als
  `Tagesdatum.gueltig`, weil ein Dateiname die schwächere Quelle ist. Aus
  `IMG_1234.jpg` wird kein Datum. Die Alternative — irgendeine Ziffernfolge
  als Datum zu lesen — legte ein Foto stillschweigend auf einen erfundenen
  Tag, und das ist der Fehler, den man dem gedruckten Buch nicht ansieht.
* **`deletingPathExtension` schneidet stur hinter dem letzten Punkt ab.** Bei
  einem Namen ohne Endung („2026.08.12") nähme es den Tag mit. Gelesen wird
  deshalb erst ohne Endung, dann mit.
* **Und wenn auch dann keines übrig bleibt, entscheidet der Mensch.** Die
  Zeile „Fotos ohne Datum" steht sichtbar im Einlesen-Blatt: Ablage oder ein
  bestimmter Tag, vorbelegt mit dem ersten Reisetag. **Ein Foto ohne jede
  Datumsangabe trägt keine Auskunft darüber, wann es aufgenommen wurde — an
  WELCHEN Tag es geht, ist deshalb eine Entscheidung und keine Messung.**
  Genau deshalb steht sie vorne und nicht im Stillen, und der Bericht nennt
  hinterher den Tag beim Namen.
* **Was keine Aufnahmezeit hat, kommt ans ENDE des Tages** und nicht an den
  Anfang. Bis 1.0.29 stand dort `.distantPast`, und das war folgenlos,
  solange ein Tag gar kein undatiertes Foto tragen konnte. Jetzt wäre es die
  falsche Richtung: Es schöbe sich vor den Morgen eines Tages, über den es
  nichts aussagt. Dieselbe Regel wie beim Handpunkt ohne Uhrzeit in der
  Reisespur.

### Der Weg über „Dateien"

Er hat keinen eigenen Bildschirm — er ist der Dateiwähler und sonst nichts
(`allowsMultipleSelection` steht dort seit 1.0.0 auf `true`). Für Fotos ohne
Datum gilt deshalb dieselbe Vorgabe wie beim Foto-Import: der erste Reisetag,
und die Ablage nur, solange es gar keinen Tag gibt. Der Bericht sagt
hinterher, wo sie gelandet sind.

### Ein Feld, das nie gelesen wird, ist ein halb gebautes Vorhaben

Beim Gegenlesen gefunden und wieder ausgebaut: Der erste Entwurf trug eine
Aufzählung `Datumsquelle` am `Bildbefund` mit — geschrieben an drei Stellen,
gelesen an keiner. Gezählt wird ohnehin dort, wo die Quelle greift, und der
Bericht nennt beide Zahlen („Bei 12 Fotos kam das Datum aus der
Fotomediathek", „Bei 30 Fotos stand das Datum nur im Dateinamen"). Dieselbe
Lehre wie beim Kartenausschnitt in 1.0.11.

## Schriften, Seitenwechsel, und die fehlende Vorlage (1.0.29)

Drei Ansagen des Nutzers, 09/2026:

> Ich möchte noch weitere Schriftarten verwenden. Standardmäßig möchte ich
> eine serifenlose Schrift verwenden, bei der das kleine A so aussieht wie bei
> der Systemschrift Futura. Futura selbst ist mir etwas zu dick gedruckt.
> Bitte finde dort Alternativen.

> Ich möchte ein Bild problemlos von einer Seite auf eine andere schieben
> können beziehungsweise auch andere Elemente wie zum Beispiel Textfelder.

> Bei den Vorlagen vermisse ich etwas … Ich möchte ein Reisetagebuch mit sehr
> viel Text mit ebenfalls sehr vielen Bildern verknüpfen. Hier möchte ich, dass
> der Text automatisch auf den einzelnen Seiten … verteilt wird und die Bilder
> entsprechend auch.

### Die Schriftwahl misst, statt aufzuschreiben

`Schriftfamilie` war eine Aufzählung mit sechzehn Namen — eine Liste, die
jemand einmal aufgeschrieben hat. Welche Schriften ein iPad wirklich
mitbringt, entscheidet aber das Gerät. Jetzt steht dort der **Familienname**,
und die Wahl zeigt, was da ist (derselbe Umbau wie beim `Seitenformat` in
1.0.27, samt demselben nachsichtigen Leser für alte Dateien).

Dazu kommt der **Schnitt** — und der ist der eigentliche Grund. Bis 1.0.28
baute `uiFont` den Deskriptor allein aus dem Familiennamen; damit kam immer
der Regelschnitt und nie ein leichterer. „Futura ist mir etwas zu dick
gedruckt" ist genau diese Lücke. Sie ist geschlossen, soweit das geht:
**Futura liefert iOS nur ab Medium aufwärts** — einen Buch- oder Light-Schnitt
gibt es dort nicht, und wo keiner ist, steht auch keiner in der Liste.

**Ob ein kleines a rund ist, misst die App an der Glyphe.** Der Unterschied
zwischen einstöckig (Futura: ein Kreis mit Stamm) und zweistöckig (Helvetica:
eine Schale unten mit einem Bogen darüber) steckt in der Gegenform, also im
Loch: Beim einstöckigen füllt sie fast die ganze Buchstabenhöhe, beim
zweistöckigen gut ein Drittel.

Nachgemessen an elf Schriftdateien (22.09.2026, dieselbe Rechnung in Python
nachgezogen):

| | Höhe der Gegenform |
| --- | --- |
| Liberation Sans / Serif / Mono, DejaVu Sans / Serif, FreeSans, Loma | 0,362 – 0,397 |
| FreeSerif, DejaVu Serif | 0,429 – 0,468 |
| **Poppins, Questrial, Josefin Sans** | **0,719 – 0,913** |

Zwischen 0,468 und 0,719 liegt eine breite Lücke; die Schwelle steht mittig
darin (0,55).

**Welche Kontur die äußere ist, entscheidet das Umfassen und nicht die
Fläche.** Das ist an einer echten Schrift gelernt: Jost zeichnet sein a aus
zwei einander überlappenden Formen statt aus Umriss und Loch. Nach der Fläche
gerechnet gewann dort die falsche Kontur, und heraus kam „zweistöckig" für
eine Schrift, die einstöckig ist. Wo keine Kontur alle anderen umfasst, gibt
die Messung deshalb **keine Antwort** und sagt das auch — eine Messung, die im
Zweifel etwas behauptet, ist schlechter als eine, die schweigt.

Wichtiger als jede Messung ist aber, dass **jede Zeile der Schriftwahl in ihrer
eigenen Schrift gesetzt ist**, mit einem Wort, das drei kleine a trägt. Wer die
Form sucht, sieht sie. Die Messung ordnet nur die Liste und nennt ihre Zahlen
unter der Probe.

Mitgeliefert wird weiterhin keine Schriftdatei: Ein Buch wird weitergegeben,
und dafür bräuchte jede Schrift eine Lizenz.

### Auf eine andere Seite — ein Befehl, keine Geste

Im Inspektor steht unter **„Auf welcher Seite"**: zurück, vor, oder eine
bestimmte; auf der letzten Seite legt „Neue Seite" eine an.

Bewusst kein Ziehen über die Blattgrenze. Eine Ziehgeste, die ein Blatt
verlässt, müsste *mitten im Ziehen* entscheiden, zu welcher Seite der Finger
gerade gehört — in einer Bühne, die sich dabei rollt und zoomt. Das ist die Art
Ziehgeste, die dieses Projekt von 1.0.5 bis 1.0.8 gekostet hat und deren Zoom
bis 1.0.28 nicht stand. Ein Knopf, der immer tut, was draufsteht, ist hier mehr
wert als eine Geste, die meistens tut, was gemeint war.

Die **Lage auf dem Blatt bleibt** dabei, wie sie ist; danach trägt der Block
`vonHand`. Verschoben wird innerhalb **eines Tages** — über Tagesgrenzen hinweg
ist es keine Frage der Seite mehr, sondern der Zuordnung, und die wird in der
Fotoliste des Tages beantwortet.

### „Text und Bilder im Wechsel"

`reihenSetzen` wechselt seit 1.0.14 auf den **Folgeseiten** zwischen Text und
Fotoreihen. Die **erste** Seite war davon ausgenommen: Dort füllte der Text bis
zum Satzspiegelende, und das erste Bild stand eine Seite weiter. Bei einem Tag
mit viel von beidem ergibt das genau den gemeldeten Eindruck — erst ein Kapitel
Text, dann eines mit Bildern.

Das neue Muster hält schon auf der ersten Seite die **Zielhöhe der nächsten
Fotoreihe** frei; dieselbe Zahl, mit der `reihenSetzen` weiterrechnet, und kein
geschätzter Anteil. Bleiben daneben keine sechs Zeilen Text mehr, wird gar
nichts freigehalten: Eine Seite mit vier Zeilen über einem Bild ist kein Satz,
sondern ein Rest.

Vorgeschlagen wird es ab **1200 Zeichen und vier Fotos** — ein Tag mit drei
Sätzen und zwei Bildern ist nicht gemeint und bekommt weiter, was er vorher
bekam. Von Hand steht es im Tagesmenü unter „Seitenmuster".

## Das ganze Buch untereinander, und ein Wort an der Geste (1.0.28)

Zwei Befunde des Nutzers, 09/2026:

> Das [Zoomen] fühlt sich immer noch spröde an und ich kann dir versichern,
> dass ich kein Bild ausgewählt habe. Die Geste müsste eigentlich allein der
> Seite gehören, aber trotzdem muss ich mehrere Male anfassen.

> Lieb, wenn alle Seiten fortlaufend untereinander stehen würden,
> beziehungsweise in dieser Ansicht die Doppelseiten, sodass man mühelos von
> einem Seitenpaar zum nächsten wischen kann, ohne dass man links die Liste
> der Seiten [braucht].

### Ein Buch blättert man

Bis 1.0.27 filterten `sichtbareSeiten` und `sichtbareDoppelseiten` nach dem
gewählten Tag. Damit war die Tagesliste links keine Übersicht, sondern der
**einzige** Weg durch das Buch: Wer die letzte Seite eines Tages sah und
weiterblättern wollte, musste zur Liste greifen. Der Filter ist ersatzlos
weg; die Liste ist jetzt eine **Sprungmarke**.

Damit heißt „gewählter Tag" etwas anderes als vorher. Er sagt nicht mehr, was
gezeigt wird, sondern worauf der Titel, das Tagesmenü unten rechts und das
Neuanordnen zielen — und **das muss dem folgen, was man sieht**. Wer zum
6. August scrollt und dann „Seiten neu anordnen" tippt, meint den 6. August;
still am Tag von vorhin zu arbeiten wäre genau die Art Fehler, die diese App
sonst überall vermeidet.

Gemeldet wird das über `onAppear`/`onDisappear` der Reihen
(`ReiseView.imBlick`: Reihennummer auf Tageskennung, die kleinste ist die
oberste). Das fällt **einmal je Reihe** an und nicht bei jedem Bildpunkt — aus
dem Rollversatz zu rechnen wäre der naheliegende Weg und schriebe einen
Zustand sechzigmal in der Sekunde; dieselbe Überlegung, aus der `Inhaltslage`
seit 1.0.18 kein `@State` ist.

**Den Kreis hält auf beiden Seiten dieselbe Prüfung.** Liste → Bühne und
Bühne → Liste setzen denselben Wert; ohne Bremse sprängen sie einander
hinterher. Gebremst wird mit der Frage, ob der Tag schon oben im Bild steht —
steht er, ist nichts zu tun, und genau daran erkennt die Stelle auch, dass die
Änderung vom Rollen kam. Ein Merker „das war ich" wäre der übliche Griff und
läge bei jeder Änderung der Reihenfolge wieder daneben.

Einzelseiten und Doppelseiten zählen ihre Reihen **verschieden** (Seitenzahl
gegen Bogennummer); beim Umschalten wird `imBlick` deshalb geleert. Eine alte
Meldung wäre dort nicht bloß veraltet, sondern falsch.

### Ein Wort an der Geste

Über dem Inhalt der Bühne liegt der `ScrollView` und damit dessen
Schiebeerkenner — und der beginnt schon bei **einem** Finger. Zwei Finger auf
einer Rollfläche sind für ihn ein Wisch; ohne ausdrückliche Erlaubnis zur
**gleichzeitigen** Erkennung muss einer der beiden verlieren, und welcher,
entscheiden die ersten Millisekunden der Bewegung. Das ist „mal beim ersten,
mal beim dritten Versuch".

Das ist keine Vermutung, sondern ein Vergleich **in dieser App**:

| Stelle | Angehängt mit | Verhalten |
| --- | --- | --- |
| Bildausschnitt (`SeitenflaecheView`, seit 1.0.8) | `simultaneousGesture` | greift |
| Seitenzoom (`ReiseView`, seit 1.0.17) | `.gesture` | greift unzuverlässig |

Dieselbe Gestenart, dieselbe Rollfläche, derselbe Bildschirm — der Unterschied
zwischen beiden ist dieses eine Wort. Wo zwei gleichartige Stellen sich
verschieden verhalten, ist ihr Unterschied die erste Spur, und diese hier
lässt sich am Quelltext nachlesen statt an einer Erinnerung.

### Der Verdacht aus 1.0.27 ist widerlegt

1.0.27 schrieb als naheliegenden Grund auf, ein gewähltes Foto sperre den
Seitenzoom (seit 1.0.17 gehören zwei Finger dort dem Bildausschnitt) und ein
zu kurzes Aufziehen komme als Tipp an, der die Auswahl aufhebt. Der Nutzer hat
dem ausdrücklich widersprochen: „ich kann dir versichern, dass ich kein Bild
ausgewählt habe."

Die Zeile im Befund bleibt trotzdem stehen. Sie war nie eine Erklärung,
sondern eine **Messung**, und sie hat genau das getan, wofür sie gebaut war:
einen Zweig ausgeschlossen. Eine Probe, die eine Vermutung umwirft, ist nicht
gescheitert — das ist ihr Sinn. Dieselbe Bauweise wie die Zeile „Soll/Ist" aus
1.0.24, die in 1.0.26 die Geometrie entlastet und den Blick verschoben hat.

## Formate, A5 aus A4, Broschüre (1.0.27)

Ansage des Nutzers, 09/2026:

> Ich möchte verschiedene Maßvorlagen für die Seiten haben. DIN A4
> Hochkant, DIN A4 Breit, DIN A5 dasselbe und quadratisch 28 x 28 cm.
> Ansonsten möchte ich aber auch die Möglichkeit haben, eine Seite frei
> skalieren zu können, also eigene Maßeingaben tätigen zu können. […]
> Allerdings möchte ich zusätzlich eine Version auf dem heimischen Drucker
> ausdrucken können, damit ich Vorder- und Rückseiten gut bedrucken kann,
> würde das Format dann auf ein DIN A5 Buch schrumpfen. Ich weiß, dass es
> problematisch sein könnte, die Größe der Schriften im Dokument
> herunterzurechnen, aber ich hoffe, dass es eine Möglichkeit gibt, ohne
> viel Aufwand aus dem DIN A4 Projekt ein A5 Projekt zu machen. Wenn dann
> noch die Möglichkeit besteht, automatisch einen Buchdruck auswählen zu
> können, so dass die Seiten des Dokumentes automatisch umsortiert werden,
> so dass ich eine doppelseitige Broschüre drucken kann.

Drei Dinge, und sie hängen aneinander.

### Das Format ist kein Wort mehr

`Seitenformat` war eine Aufzählung mit vier Fällen; ein freies Maß lässt
sich darin nicht ausdrücken. Es ist jetzt ein Wertetyp aus `breite`,
`hoehe` und einem **optionalen** Vorlagennamen — `nil` heißt „selbst
eingetippt". Sieben Vorlagen:

| Vorlage | Maß |
| --- | --- |
| A4 hoch / quer | 210 × 297 / 297 × 210 mm |
| A5 hoch / quer | 148 × 210 / 210 × 148 mm |
| Quadrat | 21 × 21, 28 × 28, 30 × 30 cm |

Dazu ein freies Maß, 70 bis 500 mm je Kante. Darunter wären die Ränder
breiter als die Seite, darüber nimmt kein Druckdienst dieser
Größenordnung an.

**Der Leser nimmt weiterhin den alten Text entgegen.** In jeder
gesicherten Reise steht dort `"a4quer"`, also eine Zeichenkette und kein
Objekt. Ohne den Einzelwert-Zweig in `init(from:)` wäre `format` beim
Lesen auf die Vorgabe gefallen — und weil `Reise` das Feld über
`wert(.format, …)` holt, **still**: Das Buch ginge auf, und die Seiten
hätten das falsche Maß. Wer einen Typ von einer Aufzählung auf eine
Struktur umbaut, schreibt den Leser für beide Formen.

Das Format hat seit 1.0.27 einen eigenen Bildschirm (Gestalten →
Seitenformat). Es ist die eine Entscheidung, an der alles andere hängt,
und seit dieser Fassung rechnet sie das Buch um; das gehört nicht hinter
eine Auswahlzeile zwischen Anschnitt und Bundsteg. In der Gestaltung
steht die Zeile weiter, jetzt als Auskunft mit dem Weg dorthin.

### A4 nach A5 ist eine Multiplikation

Die ganze A-Reihe hat dasselbe Seitenverhältnis — das ist ihre
Bauvorschrift. Ein einziger Faktor (1/√2 ≈ 0,707) trifft also beide
Kanten, und `Model/Formatwechsel.swift` rechnet ihn auf **alles, was eine
Länge ist**: Blockrahmen, Ränder, Fuge, Bundsteg, Eckenradius,
Schriftgrößen, Innenabstände, Linienbreiten. Danach steht jeder Block
relativ an derselben Stelle und wirkt in derselben Größe; nur das Papier
ist kleiner.

Was **nicht** mitgerechnet wird:

* **Der Anschnitt.** Er ist keine Gestaltung, sondern eine Angabe der
  Druckerei: Drei Millimeter sind drei Millimeter, egal wie groß die Seite
  ist. Wer ihn mitschrumpfte, lieferte eine Datei, die formal stimmt und
  beim Schneiden den weißen Faden bekommt, wegen dem es den Anschnitt
  gibt.
* **Der Bildausschnitt.** `zoom` und die beiden Versätze sind Anteile am
  Bild und keine Längen; mitgerechnet verschöben sie jedes Foto in seinem
  Rahmen.
* **Die Breite der Karte** (ein Anteil) und die **Drehung** (ein Winkel).

Bei unähnlichen Formaten — A4 hoch auf 28 × 28 cm — gibt es keinen
Faktor, der beides trifft. Genommen wird der kleinere der beiden, denn das
ist der einzige, bei dem kein Block aus der Seite fällt; an einer Kante
bleibt dann mehr Luft als vorher. Der Satz wird davon nicht falsch, sieht
aber danach aus, wenn niemand es sagt — das Blatt sagt es.

**Erst zeigen, dann übernehmen.** Ein Formatwechsel fasst jeden Block des
Buches an. Vorher stehen da: beide Formate mit Maß, der Faktor in Prozent,
die Zahl der Blöcke und die Fließtextgröße vorher und nachher. Zwei Wege,
weil es zwei Fragen sind — „mitrechnen" für ein fertiges Buch, „nur das
Format wechseln" für eines, das danach ohnehin neu angeordnet wird. Beides
hängt an `werk.merken()` und ist mit „Widerrufen" zurückzunehmen.

### Die Broschüre ist ein Bogen, keine Druckvorlage

„… → Als PDF sichern → Umfang: Broschüre" setzt den Rückenstich. Die
Seitenfolge wird mit Leerseiten auf ein Vielfaches von **vier** aufgefüllt
(anders geht ein gefalteter Bogen nicht auf), dann trägt Bogen `i` vorn
`[n−1−2i | 2i]` und hinten `[2i+1 | n−2−2i]`. Der Bogen ist doppelt so
breit wie das Endformat.

**Ohne TrimBox und BleedBox, mit Absicht.** Beide sagen einer Druckerei,
wo geschnitten wird — auf einem Bogen mit zwei Seiten nebeneinander gäbe
es dafür keine einzige richtige Stelle, und eine Schnittmarke am falschen
Ort ist schlimmer als keine. Aus demselben Grund läuft an der Broschüre
keine Druckprüfung: Sie misst genau diese beiden Kästen und meldete hier
garantiert Falsches. Was stattdessen dasteht, ist die Rechnung selbst —
Seiten, Leerseiten, Bogen, Bogenmaß.

**Die Rückseiten lassen sich um 180 Grad drehen, und das ist eine Frage an
den Drucker.** Ob er beim beidseitigen Druck über die lange oder die kurze
Kante wendet, steht in keiner Datei; es ist eine Einstellung des Treibers
und je Gerät anders. Deshalb ein Schalter mit einem Satz daneben und keine
Automatik: Eine App, die das errät, druckt bei der Hälfte aller Geräte
jede zweite Seite auf dem Kopf.

### „Erst beim dritten Versuch" — ein Verdacht mit Zähler

Der Nutzer meldete zu 1.0.26: „Jetzt scheint es zu funktionieren. Mitunter
reagiert der Zoom erst beim dritten Versuch."

Die naheliegende Erklärung steht im Quelltext: `seitenzoomErlaubt`
schaltet die Zweifingergeste der Seite ab, solange ein Foto gewählt ist
oder der Ausschnittsmodus läuft — dann gehört sie dem Bild (so seit
1.0.17). Eine zu kurze Aufziehbewegung kommt als Tipp an, der Tipp hebt
die Auswahl auf, und der nächste Versuch geht. Das wäre genau das
gemeldete Muster.

**Gemessen ist es nicht.** Nach sechs Fassungen an dieser Bühne wird hier
nicht mehr geraten, also steht es nicht als Ursache da, sondern als Zeile
im Befund („Bedienung prüfen"):

```
Seitenzoom: erlaubt
Seitenzoom: gesperrt (ein Foto ist gewählt)
Seitenzoom: gesperrt (Ausschnittsmodus)
```

Dazu zählt der `Zeichenmesser` Beginn und Ende jeder Geste. Sagt der
Befund beim nächsten Mal „gesperrt", ist es das. Sagt er „erlaubt" und die
Geste zählt trotzdem nicht hoch, kommt sie gar nicht an — und das ist
etwas anderes.

## Die Seite hing aus ihrem eigenen Rahmen heraus (1.0.26)

Gemeldet 09/2026, und dieser Befund nennt drei Dinge auf einmal:

> „Wenn ich die Seite aufgezoomt habe, springt sie grundsätzlich so, dass der
> Fokus in der linken oberen Ecke liegt … Nachdem ich die Seite herangezoomt
> habe, kann ich sie mit einer Zwei-Finger-Geste nicht wieder herauszoomen …
> Die untere rechte Ecke erreiche ich nie. Dafür bleibt am oberen Rand
> grundsätzlich Abstand bis zur eigentlichen Buchseite.“

**Drei Beschwerden, eine Ursache**, und sie steht in zwei Zeilen
`SeitenflaecheView`:

```swift
.scaleEffect(massstab, anchor: .topLeading)
.frame(width: bogen.width * massstab, height: bogen.height * massstab)
```

`scaleEffect` ändert nur die ZEICHNUNG, nie die Layoutgröße: Das Kind darüber
meldet weiterhin `bogen`, also die **unskalierte** Größe. Der Rahmen hier ist
die skalierte — und **ein `.frame` ohne Ausrichtung stellt ein kleineres Kind
mittig hinein.** Gezeichnet wurde danach ab der Ecke dieses zentrierten Kindes,
also um `bogen · (Maßstab − 1) / 2` versetzt.

### Damit erklärt sich jeder der drei Sätze

| Befund | Ursache |
| --- | --- |
| „am oberen Rand bleibt Abstand bis zur Buchseite“ | die leere Lücke oben links |
| „die untere rechte Ecke erreiche ich nie“ | der Überhang unten rechts — gerollt wird der RAHMEN, nicht die Zeichnung |
| „nicht wieder herauszoomen“ | was außerhalb eines Frames liegt, nimmt in SwiftUI keinen Finger an; der Zoom hängt an der Fläche der Bühne |
| „irgendein oberer linker Punkt der Arbeitsfläche“ | `Zoomanker` rechnet ab der Rahmenecke, gezeichnet wird aber weiter unten rechts |

Der Nutzer hat das genauer gesagt als jede Vermutung davor: **„es ist nicht die
Seite, sondern irgendein oberer linker Punkt der Arbeitsfläche, den du
willkürlich festgelegt hast“** — genau so ist es, und der Punkt liegt um den
halben Zuwachs daneben.

### Nachgemessen, in beide Richtungen

An zwei Bildschirmfotos desselben Buches:

| Maßstab | gemessen | gerechnet `bogen·(m−1)/2` |
| --- | --- | --- |
| 94 % | Blattkante 93 pt vom Bühnenrand, wo `Zoomanker` 121,5 erwartet → **−28,5** | **−28,0** |
| 187 % | Inhalt bei rund −201/−1139 statt −588/−1411 → **+387/+272** | **+373,5/+266,1** |

Unter 100 % liegt die Zeichnung also weiter oben links als ihr Rahmen, darüber
weiter unten rechts — beide Vorzeichen stimmen, beide Beträge auch.

Und damit ist die Zeile aufgelöst, die 1.0.25 in die Irre geführt hat:
`Soll −588/−1411 · Ist −588/−1411 · Abweichung 0/−0` war **richtig**. Gerollt
wurde genau dorthin, wo die Rechnung es wollte; nur stand die Seite nicht dort,
wo die Rechnung sie vermutete.

### Der Griff ist ein Wort

`alignment: .topLeading` am äußeren `.frame`. Dann liegt die Ecke des Kindes
auf der Ecke des Rahmens, `scaleEffect` skaliert um genau diese Ecke, und die
Zeichnung füllt ihren Rahmen auf den Punkt.

### Was aus 1.0.25 wieder ausgebaut ist

Die **Nachführung** und der **Deckel für den `LazyVStack`**. Beide waren die
Antwort auf eine Frage, die es nicht gab — der Versatz wurde nie „nachträglich
verstellt“, er war von Anfang an ein anderer, als die Rechnung annahm.
`ReiseView` steht wieder auf dem Stand von 1.0.24. Ein Mechanismus, dessen
Grund widerlegt ist, bleibt nicht liegen; und der nächste Befund soll wieder
zuzuordnen sein.

**Was aus 1.0.24 bleibt, ist die Probe** — ohne die Zeile `Soll … Ist …` wäre
dieser Durchgang die fünfte Vermutung geworden. Dass sie „alles in Ordnung“
meldete, war ihr Verdienst und nicht ihr Versagen: Sie hat die Rechnung
entlastet und den Blick auf das gelenkt, was sie nicht misst.

### Nicht gemessen

Gesehen hat es niemand. Gerechnet und an zwei Bildern nachgemessen ist die
Ursache; dass die drei Beschwerden damit weg sind, folgt aus der Geometrie.

## Die Rechnung stimmte — und wurde hinterher überschrieben (1.0.25)

Gemeldet 09/2026, zum wiederholten Mal: „Ich möchte auf das Bild unten rechts
zoomen und wenn ich die Finger noch drauf halte, geht der Zoom auch in die
richtige Richtung. Sobald ich aber loslasse, ist wieder die linke obere Ecke im
Fokus.“

Diesmal entscheidet die Probe, und sie entlastet die Rechnung vollständig:

```
Zoom 94 % → 187 % · Blattbreite 803 pt · Bühne 1046×864
Griff #2 quer 0.85 hoch 0.75 · Brennpunkt 803/673
Ziel #2 · Anker 1.00/0.63 · roh 1.00/0.63
Soll -588/-1411 · Ist -588/-1411 · Abweichung 0/-0
```

**`scrollTo` hat den Anker eingelöst, auf den Punkt** — 0,4 Sekunden nach dem
Loslassen. Damit ist die Frage, die seit 1.0.18 offen stand, beantwortet: Die
Geometrie taugt, und ein Anker außerhalb der Mitte wird genommen wie
beschrieben.

### Und trotzdem steht danach etwas anderes da

Nachgerechnet am Bildschirmfoto desselben Augenblicks: Das Ballonfoto liegt
dort bei 69 % der Blattbreite und steht auf dem Schirm bei 937 Punkten; mit der
Blattbreite bei 187 % (1606 pt, ebenfalls am Bild nachgemessen) ergibt das
einen Inhaltsversatz von rund **−201/−1139** — nicht −588/−1411. Der Versatz
wird also **nach** der Messung wieder zurechtgerückt, in Richtung Ursprung.

Damit heißt die Frage nicht mehr „wie rechnet man den Anker“, sondern „wer
verstellt ihn hinterher“. Zwei Griffe, und die Probe trennt sie.

### Erstens: eine Regelung statt einer Rechnung

`nachfuehren` rollt, sieht nach und rollt noch einmal, wenn es nicht steht —
nach 0,05 / 0,12 / 0,25 / 0,4 / 0,7 Sekunden. Abgebrochen wird, sobald der
Versatz auf einen Bildpunkt sitzt, und sofort, wenn eine neue Geste anfängt:
Wer die Finger aufsetzt, führt. Gegen etwas, das den Versatz später verstellt,
hilft keine bessere Formel; es hilft, noch einmal hinzusehen.

### Zweitens: der `LazyVStack` gilt erst ab zwölf Elementen

1.0.16 hat ihn eingebaut, und der Grund gilt weiter: Ist kein Tag gewählt,
stehen hier alle Seiten des Buches. **Er hat aber einen Preis, der genau hier
weh tut** — er kennt nur die Höhe der Elemente, die er schon gebaut hat.
Während nach einem Zoom Seiten gesetzt und Fotos geladen werden, ändert sich
die Gesamthöhe, und ein `ScrollView` rückt seinen Versatz dann nach. Ein
gewählter Tag hat zwei bis sechs Seiten; dort ist die Faulheit kein Gewinn und
kostet die Verlässlichkeit. Über der Grenze bleibt sie.

### Die Probe sagt, welcher der beiden Griffe gewirkt hat

Die letzte Zeile endet seit 1.0.25 mit „ohne Nachführung“ oder „3×
nachgeführt“. Steht dort „ohne“ und stimmt das Bild, war die Rolle von selbst
still — dann lag es am Stapel. Steht dort eine Zahl, hat die Regelung es
geradegezogen.

Geschrieben wird die Zeile **einmal je Zoom** und nicht bei jedem Takt: Das
Feld liegt im `Reisewerk`, und jede Zuweisung zeichnet die Bühne neu — mitten
in einer Regelung wäre das genau die Unruhe, gegen die sie gebaut ist.

### Was weiter offen ist

Ob es auf dem Gerät jetzt steht, hat niemand gesehen. Gemessen ist, dass die
Rechnung stimmt und dass der Versatz hinterher ein anderer war; **welcher
Mechanismus ihn verstellt, ist nicht bewiesen** — die Höhenschätzung des
`LazyVStack` ist die Erklärung, die dazu passt, und mehr nicht. Die Regelung
wirkt unabhängig davon, aber sie ist ein Netz und kein Beweis.

## Der Sprung in die linke obere Ecke — selbst gebaut (1.0.24)

Gemeldet 09/2026: „Schon besser, aber immer noch nicht genug. … Ich möchte
das Foto unten rechts näher heranzoomen. Wenn ich das tue, dann wird die
Zoom-Geste korrekt ausgeführt. Lasse ich allerdings die beiden Finger los,
dann springt das Bild wieder auf die linke obere Ecke. Ein Verschieben der
Arbeitsfläche ist auch nach wie vor nicht möglich.“

Der erste Satz ist die Diagnose: **Während der Geste stimmt es, beim
Loslassen nicht.** Während der Geste skaliert ein `scaleEffect` um den Punkt
zwischen den Fingern — das ist eine Abbildung und kann gar nicht danebenliegen.
Beim Loslassen wird der Maßstab gesetzt und einmal gerollt. Wird **nicht**
gerollt, behält die Rolle ihren Versatz, während der Inhalt um den Faktor der
Geste WÄCHST — man sieht dann einen Punkt, der um genau diesen Faktor näher am
Ursprung liegt. Das IST der Sprung in die linke obere Ecke.

### Es war 1.0.23

Dort stand am Ende des Zooms `guard griff.imBlatt`: Lag der Mittelpunkt der
Finger nicht auf dem Blatt, wurde gar nicht gerollt. Gedacht war das gegen den
Sprung an eine Blattkante — gebaut war damit der Sprung in die Ecke, also der
Zustand von vor 1.0.18. Die Bedingung ist weg; gerollt wird immer.

Dasselbe gilt für das **Klemmen der beiden Griffanteile** auf 0 bis 1. Der
Brennpunkt ist ein Punkt IM INHALT, und das Blatt ist nur das Maß, in dem er
ausgedrückt wird. `hoch = 1,05` heißt „eine Blatthöhe und fünf Prozent unter
der Oberkante“, und damit lässt sich genauso rechnen wie mit 0,5. Geklemmt
werden darf erst der fertige `UnitPoint`, denn DER kann nichts anderes
ausdrücken.

### Ein geklemmter Anker geht über den NACHBARN

Im Befund des Nutzers stand `Anker … 0.76 (geklemmt)`. Ein Anker kann nur Werte
von 0 bis 1 tragen und damit nur Elementkanten zwischen 0 und
`Sichtfeld − Element`; alles darüber hinaus wurde bisher an den Rand geklemmt.
Die Reichweite lässt sich aber ohne jede Annahme vergrößern, **weil alle
Elemente gleich hoch sind und im selben Abstand stehen**: Die Kante von Element
`k` liegt um `(k − Index) · Schritt` unter der des gegriffenen. Rollt man also
ein Nachbarelement an den passenden Anker, steht das gegriffene genau dort, wo
es stehen soll. `Zoomanker.rollziel` sucht das Element, dessen Anker am
wenigsten geklemmt werden muss; passt der des gegriffenen schon, ändert sich
nichts. Das ist reine Geometrie und keine Vermutung.

### Und zum ersten Mal wird die WIRKUNG gemessen

Seit 1.0.18 steht im Papier, dass die Rechnung stimmt und ungeprüft ist, ob
`scrollTo` einen Anker außerhalb der Mitte wirklich einlöst. Die Probe nennt
deshalb seit 1.0.24 eine Zeile mehr:

```
Soll -1073/-2528 · Ist -1070/-2531 · Abweichung 3/-3
```

`Soll` ist der Versatz, den der Inhalt nach dem Rollen haben MÜSSTE; `Ist` der,
den er 0,4 Sekunden später WIRKLICH hat. Stimmen beide überein, löst `scrollTo`
den Anker ein und ein verbleibender Fehler liegt woanders; weichen sie ab, liegt
er an genau dieser Stelle. **Damit ist die Frage zum ersten Mal entscheidbar,
statt aus der Dokumentation gefolgert.**

### Zum Schieben: gezählt, nicht erklärt

Die zweite Hälfte der Meldung lässt sich von hier aus nicht aufklären — ein
`ScrollView` rollt oder rollt nicht, und am Quelltext sieht man es nicht.
`Inhaltslage` zählt deshalb seit 1.0.24 mit, wie weit der Ursprung des Inhalts
seit dem Öffnen überhaupt gewandert ist; die Zeile steht in „Befund kopieren“:

```
Gewandert seit dem Öffnen: ⇄0 ↕0 (412 Meldungen)
```

Bleibt die Spanne null, während jemand schiebt, rollt die Bühne nicht — dann
ist es keine Frage der Rechnung oben. Wächst sie, rollt sie, und die Frage ist
eine andere. Dazu sagt die Zeile `frei ⇄` weiterhin, ob es überhaupt etwas zu
schieben gibt: Bei eingepasster Seite passt das Blatt in die Breite, und quer
gibt es nichts.

Ein zweiter Weg steht seit 1.0.24 in der Bedienungskarte und hängt an keiner
Rolle: **mit zwei Fingern ein kleines Stück auf der Stelle aufziehen, auf die
man sehen will.** Der Zoom hält den Punkt zwischen den Fingern fest und holt ihn
damit in die Mitte — das ist eine unmittelbare Folge daraus, dass jetzt immer
gerollt wird.

### Was NICHT geändert wurde, und warum

Es liegt nahe, dass die Zweifingergeste einen Zweifinger-Wisch verschluckt —
also genau die Bewegung, die nach einem Aufziehen am nächsten liegt. Das wäre
mit `simultaneousGesture` zu ändern, wie es `SeitenflaecheView` beim
Bildausschnitt schon tut. **Es ist bewusst nicht in derselben Fassung gemacht
worden**: Hier ändert sich gerade, wohin nach dem Zoomen gerollt wird, und wer
zwei Dinge auf einmal ändert, kann den nächsten Befund nicht mehr zuordnen.
Es ist eine Vermutung und steht als solche da.

## Der erste echte Befund (1.0.23)

Gemeldet 09/2026: „Beim Zoomen springt die Seite irgendwo hin. Da hat sich
nichts geändert. Ich habe sie jetzt klein gezoomt und kann sie nicht wieder
größer bekommen." — dazu der kopierte Befund aus „Bedienung prüfen".

**Zum ersten Mal in dieser Sache entscheidet eine Messung und keine
Überlegung.** Die Antwort steht in zwei Zahlen derselben Zeile:

    Inhalt 1046×429 · Bühne 1046×864

### Die Geste braucht Fläche

Die Zweifingergeste hängt am **Inhalt**. Bei 25 % deckte der die oberen 429
von 864 Punkten ab; darunter lag nackte Leinwand ohne Geste. Wer in der Mitte
des Bildschirms aufzieht, greift also ins Leere — **und die Falle zieht sich
zu, je kleiner man zoomt.** Genau der gemeldete Zustand.

Der Inhalt ist seither mindestens so hoch wie das Sichtfeld. **Oben
ausgerichtet, nicht mittig**: Die Lagen der Elemente gehen in `Zoomanker` ein,
und eine senkrechte Zentrierung verschöbe jede davon. Die Breite konnte 1.0.22
exakt setzen; die Höhe wird als Mindestmaß gesetzt, denn unter der Bogenliste
kann noch ein Hinweis stehen, und eine feste Höhe schnitte ihn ab.

### Eine glatte 1,00 heißt „geklemmt", nicht „unten"

Derselbe Befund nannte `Griff #1 quer 0.50 hoch 1.00`. Der Finger lag an der
Unterkante des Inhalts, also **neben** dem Blatt. Daraus wurde trotzdem ein
Anker gerechnet, und der legte die Blattunterkante unter den Finger: der
Sprung „irgendwo hin". Wo kein Blatt unter dem Finger ist, gibt es keinen
Brennpunkt zu halten — dann wird gar nicht mehr gerollt.

Es ist dieselbe Ursache wie oben, von der anderen Seite gesehen: Beide
Symptome kommen daher, dass die Geste dort ankam, wo kein Inhalt war.

### Und die Probe hat sich selbst belastet

Zwei Zahlen darin waren falsch, und beide sind am Befund aufgefallen:

* `Inhalt 570×423` stand über einem Rahmen, der 1046 breit gesetzt war.
  `Inhaltslage` wird durch den `scaleEffect` hindurch gemessen, und am **Ende**
  einer Geste steht dort die skalierte Größe. Beim Aufsetzen ist der Faktor
  noch 1 — dort wird sie jetzt gemerkt.
* `Blatt 990 pt` war die Inhaltsbreite minus Ränder, bei einer kleinen Seite
  also die Bühne und nicht das Blatt. Gerechnet wird jetzt Bogenbreite mal
  Maßstab.

**Wer eine Probe baut, prüft, ob sie misst, was ihre Beschriftung sagt.**

### Was der Befund ausgeschlossen hat

Die Breite stimmte — `Inhalt 1046` ist genau die in 1.0.22 gesetzte
Inhaltsbreite, der Umbau wirkt also. Und `frei ⇄0 ↕-435` sagt, dass bei
kleiner Seite gar nichts zu schieben ist; das ist richtig so und war nie der
Fehler. Erst diese Zahlen haben die Frage von „warum springt es" auf „wo
kommt die Geste überhaupt an" gedreht.

## Die Seite ließ sich nicht schieben (1.0.22)

Gemeldet 09/2026, mit drei Bildschirmfotos bei 68 %, 116 % und 208 %: „Die
Seite kann leider nicht verschoben werden. Wenn ich sie zoome, dann springt
sie immer in irgendeine offenbar vorgerasterte Position. Diese ist aber selten
die, mit der ich dann an der Stelle gerne weiterarbeiten würde."

Zwei Dinge, beide am Quelltext abzuzählen und beide unabhängig voneinander
falsch.

### Ein Höchstmaß macht einen Inhalt nie breiter

Der Inhalt der Bühne trug `.frame(maxWidth: .infinity)`. In einem
**senkrechten** `ScrollView` ist das der übliche Griff: Die Rolle bietet ihre
eigene Breite an, das Höchstmaß setzt sie ein, der Inhalt steht mittig. Diese
Bühne rollt aber in **beide** Richtungen — und dort kann ein Höchstmaß den
Inhalt niemals *breiter* machen als das, was ihm angeboten wird. Wie breit ein
`ScrollView` seinen Inhalt auf einer Rollachse anbietet, steht nirgends
verbindlich; genau daran hing, ob sich eine herangezoomte Seite quer schieben
lässt.

Gesetzt wird jetzt eine **ausgerechnete** Breite (`ReiseView.inhaltsbreite`):
mindestens das Sichtfeld — sonst ließe sich ein schmales Blatt nicht
zentrieren — und mindestens das Blatt samt seinen beiden Rändern — sonst gäbe
es nichts zu schieben, wo es etwas zu schieben gibt. Beide Zahlen sind
bekannt: die eine ist gemessen, die andere ist Bogenbreite mal Maßstab. Damit
hängt das Schieben an keiner Zusage mehr, die niemand nachlesen kann.

Über `Zoomanker.griff` stand dazu seit 1.0.18 der Satz „Der Inhalt ist
mindestens so breit wie das Sichtfeld (`maxWidth: .infinity`)" — ein Höchstmaß
als Beleg für ein Mindestmaß. **Ein Kommentar ersetzt keine Prüfung.**

### Ein asynchroner Block läuft nicht zwingend nach dem Durchgang

`zoomAuf` setzte den neuen Maßstab und rollte im selben Atemzug in einem
`DispatchQueue.main.async` hinterher, mit dem Kommentar „erst stehen lassen,
dann rollen". Eine Zustandsänderung löst aber einen Durchgang von SwiftUI aus,
und ein Block in der Hauptschlange kann davor laufen. Dann rechnet `scrollTo`
mit der **alten** Größe des Elements und rollt an eine Stelle, die mit dem
neuen Maßstab nichts zu tun hat — genau so sieht „springt in irgendeine
Position" aus.

Der Wunsch reist jetzt durch den Zustand und wird in `onChange` eingelöst;
das läuft garantiert nach dem Durchgang, der ihn gesetzt hat. Die laufende
Nummer im Wunsch gehört dazu: `onChange` meldet sich nur bei einer Änderung,
und zweimal derselbe Anker hintereinander wäre keine.

### Geklemmt heißt „geht hier nicht"

`Zoomanker` klemmte den Anker stumm auf 0 bis 1. Ein roher Wert außerhalb
davon heißt aber etwas Bestimmtes: Der Brennpunkt ist an dieser Stelle gar
nicht zu halten — weiter als bis zum Rand rollt kein `ScrollView`, und am
Anfang und Ende der Liste ist das der Normalfall. Geklemmt sieht genau das aus
wie eine Handvoll fester Stellungen. Geklemmt wird jetzt erst beim Bauen des
`UnitPoint`, und der Befund trägt beide Zahlen.

### Und die Probe nennt den freien Weg

„Bedienung prüfen" (⋯ → Prüfen) zeigt seither auch die Bühne: Sichtfeld,
Inhalt, Versatz, Maßstab, Blattbreite, Griff, Brennpunkt und den Anker roh wie
geklemmt — dazu `frei ⇄` und `↕`, also Inhalt minus Sichtfeld. **Ist diese
Zahl waagerecht null, gibt es nichts zu schieben, und jede weitere Erklärung
erübrigt sich.** Die jetzige Lage wird erst beim Tippen auf „Befund kopieren"
gelesen und nirgends laufend mitgeschrieben.

## Mehrere Punkte, eine Zeitverschiebung (1.0.21)

Ansage des Nutzers: „mehrere von ihnen auswählen zu können und ihren
Zeitstempel gemeinsam verschieben zu können, beispielsweise um drei Stunden
nach hinten." Der Fall dahinter ist der Regelfall auf einer Reise — eine
Kamera, deren Uhr auf der Zeit von zu Hause stand, oder eine Spur aus einer
fremden App ohne Zonenangabe.

Tagesmenü → Reisepunkte → **„Auswählen"**, dann die Punkte antippen; unten
stehen „Alle wählen", „Zeiten verschieben…" und „Gewählte löschen".

- **Der Modus ist sichtbar**: Die Überschrift zählt mit, der Knopf heißt
  „Fertig", vor jeder Zeile steht ein Kreis statt eines Pfeils. Ein Modus, den
  man nicht sieht, darf die Bedeutung eines Tipps nicht ändern.
- **Ordnen und Auswählen gibt es nicht gleichzeitig** — sonst hätte ein Tipp
  auf eine Zeile drei Bedeutungen.
- **Das Blatt rechnet vor**: Zahl der Gewählten, Zahl der Punkte ohne Uhrzeit
  (an denen sich nichts verschieben lässt) und der erste Punkt mit alter und
  neuer Zeit. Wer „drei Stunden nach hinten" liest, hat noch nicht geprüft, ob
  es die richtige Richtung ist.
- **Verschoben wird die Uhrzeit am Ort**, dieselbe, die in der Liste steht.
  Punkte, die dabei über Mitternacht rutschen, bleiben an diesem Tag: Der Tag
  ist der, den du erlebt hast, und nicht das Ergebnis einer Rechnung.
- Danach wird stabil neu nach Zeit geordnet; Punkte ohne Uhrzeit behalten ihre
  Reihenfolge am Ende.

## Punkte bearbeiten, klarere Menüs, neues Symbol (1.0.20)

### Reisepunkte lassen sich ändern

Ein Tipp auf einen Punkt in der Liste (Tagesmenü → Reisepunkte) öffnet ihn:
Ort, Name, Uhrzeit, Löschen. Es ist derselbe Bildschirm wie beim Setzen eines
neuen Punktes — ein eigener Editor daneben wäre ein zweiter Weg zu derselben
Sache und liefe irgendwann auseinander.

Der **Ort** wird per Tipp auf die Karte gesetzt. Der Tipp übernimmt die Stelle
aber nicht blind, sondern rückt sie unter das Fadenkreuz: Der Finger verdeckt
genau die Stelle, die er trifft, und so sieht man hinterher, wo sie gelandet
ist, und schiebt die Karte nach.

Die **Uhrzeit** wird getippt, nicht gedreht. Angenommen wird alles Eindeutige —
„9:05", „0905", „9.05", „9". Eine geänderte Uhrzeit sortiert den Punkt neu in
die Spur ein: Die Reihenfolge der Liste ist die Reihenfolge der gezeichneten
Linie, und ein Punkt von 8 Uhr hinter einem von 17 Uhr ergäbe einen Weg, den
niemand gefahren ist.

### Das Symbol

Befund des Nutzers: „Das Programm-Icon sieht von Weitem aus wie eine weiße
Fläche mit einem Rand drumherum." Das stimmte, und der Grund stand im alten
Entwurf: ein aufgeschlagenes Buch in Papierweiß über drei Vierteln der Fläche.
Aus zehn Zentimetern sah man ein Buch; auf einem Homescreen misst ein Symbol
vierzig Bildpunkte, und dann bleiben eine helle Fläche und ein dunkler Saum.

Bei dieser Größe trägt ein Symbol **eine Farbe und eine Form** — so machen es
die Apps mit derselben Aufgabe. Jetzt: ein Weg mit Anfang und Ziel, weiß mit
dunkler Kontur auf einem diagonalen Verlauf von Abendsonne nach Tiefrot.

### Vier Orte, vier Fragen

Bis 1.0.19 standen oben drei gleich aussehende Menüs — „Einlesen", „Anordnen",
„Buch" —, und wo etwas lag, ergab sich aus der Geschichte und nicht aus der
Sache: der Satzspiegel unter „Anordnen", das PDF unter „Buch" neben der
Stilwahl, und alles zu einem Tag verteilt auf zwei Menüs und die Fußleiste.

| Ort | Frage |
| --- | --- |
| `+` | Was kommt ins Buch hinein? |
| Buchsymbol („Ganzes Buch") | Wie sieht das **ganze Buch** aus? |
| `…` | Alles Seltene: ausgeben, prüfen, Hilfen beim Anordnen |
| Pinsel („Auswahl") | Was nur für das **Angetippte** gilt |
| Unten rechts, mit dem Datum | Alles zu **diesem** Tag |

(Bis 1.0.48 trug der Pinsel die buchweite Gestaltung und ein Schieberegler
die Auswahl — genau andersherum als in Pages; seit 1.0.49 sind sie
getauscht und nach ihrem Geltungsbereich benannt.)

**Nichts steht an zwei Stellen.** „Zurück" heißt jetzt „Widerrufen" — es stand
neben einem Zurück-Pfeil, der das Buch schließt.

Die **Plus-Minus-Lupen sind weg**: Stufenweises Zoomen können zwei Finger
besser. Geblieben ist ein Knopf, der den Maßstab nennt („68 %") und
„Einpassen" oder 100 % setzt — was zwei Finger eben *nicht* können.

### Das Blatt liegt jetzt auf etwas

Der Schatten unter der Seite stand innerhalb des Maßstabs und wurde
mitskaliert: Bei eingepasster Ansicht blieben von neun Punkten dreieinhalb.
Er liegt jetzt außerhalb und ist in Bildschirmpunkten gerechnet. Dazu eine
richtige Leinwand statt eines fast weißen Grundes — Pages, Keynote und Books
stellen Papier auf einen deutlich dunkleren Grund, und nur davor lässt sich
beurteilen, wie hell ein Foto auf dem Papier wirklich steht.

In der Tagesliste steht ein Bild zum Tag, im Regal das Titelfoto als
Buchrücken.

**Nicht gemessen:** Ob die neue Aufteilung sich besser bedienen lässt, sagt
erst der nächste Befund — geändert sind Wege und Namen, und das ist keine
Messung. Ebenso ungesehen: wie das Symbol auf einem Homescreen wirkt, ob der
Tipp auf die Karte den richtigen Punkt trifft und ob der Schatten auf einem
Gerät nicht zu schwer ist.

## Uhrzeiten sind Ortszeiten (1.0.19)

Ansage des Nutzers: Die Zeiten „müssten dann angepasst werden gemäß der
Zeitzone des Ortes, also in Deutschland der mitteleuropäischen Sommerzeit und
für Kanada die Sommerzeit in Toronto."

In dieser App ist eine Uhrzeit immer die **Wanduhr am Ort** und nie ein
Augenblick auf der Weltuhr — dieselbe Regel wie beim Tag, der aus drei Zahlen
kommt. Sie galt bisher nur für die eine Hälfte der Daten:

- Ein **Foto** hält sich von selbst daran. Im EXIF steht „19:33:21" ohne jede
  Zone; die App legt genau diese Ziffern mit einer festen Zone ab und zeichnet
  mit derselben. Auf dem Bildschirm steht, was die Kamera angezeigt hat.
- Die **Reisespur** hielt sich nicht daran. Tagesspur-Sicherung und GPX
  schreiben echte Augenblicke (`2026-07-25T18:14:03Z`), und die landeten
  unverändert im selben Feld. Mit derselben festen Zone gezeichnet hieß das:
  UTC. In einer Liste standen damit Fotopunkte richtig und Spurpunkte falsch —
  in Toronto um vier Stunden, in Deutschland um zwei.

Umgerechnet wird jetzt beim **Einlesen**, nicht beim Zeichnen; danach bedeutet
das Feld überall dasselbe. Welche Zone gilt, wird **je Tag am ersten Ort
nachgeschlagen** — je Punkt wären es Tausende Anfragen, je Datei wäre es
falsch, denn eine Reise kreuzt Zonen. Eine eigene Tabelle wäre geraten: iOS
bringt keine mit, und Zonengrenzen folgen Staats- und Provinzgrenzen, nicht
Längengraden.

Ohne Netz wird nichts behauptet. Dann gilt die im Blatt eingestellte Zone, und
die Vorschau sagt je Tag, welche es war: nachgeschlagen steht grau da,
angenommen orange und mit dem Wort dabei. Unter den Reisepunkten eines Tages
steht, worauf sich seine Uhrzeiten beziehen.

**Der Tag wird dabei nicht neu gerechnet.** Wo ein Tagesschlüssel in der Datei
steht, ist er der Tag, den der Mensch erlebt hat — dass eine umgerechnete
Uhrzeit über Mitternacht rutscht, ändert daran nichts.

**Schon eingelesene Tage bleiben, wie sie sind.** Aus welcher Zone sie kamen,
weiß die App nicht mehr, und eine Spur um vier Stunden zu verschieben, weil es
plausibel aussieht, wäre geraten. Wer sie berichtigen will, liest die Datei
noch einmal ein; das ersetzt die Spurpunkte des Tages.

**Nicht gemessen:** Ob der Geocoder für die Orte dieser Reise wirklich eine
Zone hergibt, hat niemand gesehen — hier gibt es weder Netz zu Apples
Geocoder noch eine echte Sicherung. Die Zeile „Nachgeschlagen: n von m Tagen"
im Einlesen-Blatt sagt es.

## Buch aufbauen, und der Zoom bleibt unter dem Finger (1.0.18)

### „Buch aufbauen" — die Reihenfolge war da, sie stand nur nirgends

Befund des Nutzers: „Bislang ist die App auf jeder einzelnen Seite ja eher
ein noch etwas sperrig zu bedienender Bild- und Texteditor … Was das Programm
auszeichnen würde, wäre ja, dass automatisch Texte, Bilder und Koordinaten
bestimmten Tagen zugeordnet werden und diese Seiten automatisch erstellt
werden."

Das tut die App seit 1.0.0. Der Text legt die Tage an, die Reisespur hängt an
jeden Tag eine Karte, die Fotos verteilen sich über ihr Aufnahmedatum, und der
Layoutautomat setzt daraus die Seiten. Nur stand davon nirgends etwas: Die drei
Wege lagen als drei gleichrangige Punkte in einem Menü, und in welcher
Reihenfolge sie zusammengehören, wusste nur, wer die App gebaut hat.

Das ist die **fünfte Auflage desselben Befundes** — „es war da, man fand es
nicht". Die vier davor: die Bildunterschrift (1.0.5/1.0.6), das Zurücksetzen,
der Zweifinger-Zoom und die Foto-Einstellung (1.0.10).

**Einlesen → Buch aufbauen** zeigt jetzt die drei Schritte in ihrer
Reihenfolge, je mit dem Stand („12 Tage angelegt, 11 davon mit Text"), einer
Zeile, was der Schritt tut, und dem Knopf dorthin. Darunter steht Tag für Tag,
was zugeordnet wurde: Zeichen, Fotos, Orte (davon aus der Tagesspur), Seiten —
und was fehlt. Dazu die Fotos in der Ablage, ohne Datum und ohne Ort. Der
ganze Bericht lässt sich kopieren.

Drei Entscheidungen dahinter:

- **Kein neuer Einleseweg.** Die Arbeit machen unverändert `TextimportView`,
  `SpurimportView` und `FotoeinfuhrView`. Dieser Bildschirm ist die
  Reihenfolge, der Stand und der Bericht — ein zweiter Weg zu derselben Sache
  liefe irgendwann auseinander.
- **Die Blätter werden nicht gestapelt.** Jede Einleseansicht bringt einen
  eigenen `NavigationStack` mit, und ein Blatt über einem Blatt ist auf dem
  iPad ein Kärtchen auf einem Kärtchen. Der Aufbau macht deshalb zu, die
  Wurzel öffnet das nächste Blatt, und wenn das zugeht, kommt der Aufbau
  zurück — dort steht dann, was daraus geworden ist.
- **Ein Tag ohne Foto ist kein Fehler.** Was fehlt, steht orange da und nicht
  rot; es steht aber da, sonst bemerkt es niemand.

Die drei Einzelwege bleiben daneben stehen: Wer weiß, was er will, soll nicht
durch einen Ablauf laufen müssen.

### Der Zoom geschieht um den Mittelpunkt der Geste

Ansage des Nutzers zu 1.0.17: „Und der Seitenzoom soll um den Mittelpunkt der
Geste geschehen." 1.0.17 hatte das als offenen Punkt aufgeschrieben — der
`ScrollView` behält seinen Versatz, während der Inhalt wächst, also wurde um
die obere linke Ecke gezoomt.

**Ein SwiftUI-`ScrollView` hat unter iOS 17 keinen Versatz zum Setzen.**
`scrollPosition(id:)` zeigt auf eine Ansicht, `scrollTo(point:)` gibt es erst
ab iOS 18. Der einzige Hebel ist `ScrollViewProxy.scrollTo(_:anchor:)`, und
der legt den Punkt `a` eines Elements auf den Punkt `a` des Sichtfelds.
`Model/Zoomanker.swift` löst diese Gleichung nach `a` auf.

Den `ScrollView` durch eine eigene Schiebe- und Zoomfläche zu ersetzen wäre
der naheliegende Weg und der teurere: Daran hängen das Blättern, die Faulheit
des `LazyVStack` aus 1.0.16 und die Ziehgesten der Blöcke, für die 1.0.5 bis
1.0.8 gebraucht wurden.

Gebaut ist es in zwei Hälften, und nur eine rechnet:

- **Während der Geste** skaliert ein `scaleEffect` mit Anker auf den Punkt
  zwischen den Fingern. Das ist eine Abbildung und kann gar nicht
  danebenliegen — und die Seiten werden dabei nicht bei jedem Bildpunkt neu
  gesetzt.
- **Am Ende** wird der Maßstab gesetzt und einmal gerollt.

Dazu drei Kleinigkeiten, die die Rechnung tragen:

- Der Anteil gilt für das **Blatt**, nicht für das ganze Element: Die
  Beschriftungszeile darunter wächst nicht mit. Damit nichts geschätzt wird,
  hat sie eine feste Höhe, und Fuge, Rand und Beschriftungshöhe stehen als
  `Buehnenmasse` an einer Stelle.
- Wo der Inhalt gerade steht, wird in eine **Klasse** geschrieben
  (`Inhaltslage`) und nicht in `@State`: Der Wert ändert sich bei jedem
  Bildpunkt des Scrollens, und ein Zustand an dieser Stelle zeichnete die
  Bühne sechzigmal in der Sekunde neu — genau das, was 1.0.16 abgestellt hat.
  Dieselbe Bauweise wie beim `Zeichenmesser`.
- Die **Lupen** zoomen über denselben Weg auf die Mitte des Sichtfelds.

Am Anfang und am Ende der Liste hält der Brennpunkt nicht — weiter rollt kein
`ScrollView`, und das ist richtig so.

**Nicht gemessen:** Ob der Punkt auf einem Gerät wirklich stehen bleibt, hat
niemand gesehen. Gerechnet ist die Geometrie; ungeprüft sind die beiden
Annahmen darunter — dass `MagnifyGesture.Value.startLocation` im Raum des
Inhalts gemeldet wird und dass `scrollTo` mit einem Anker außerhalb der Mitte
tut, was die Dokumentation sagt. Und beim Übergang von der Skalierung auf den
gesetzten Maßstab kann ein Bild lang ein Sprung stehen bleiben: Gerollt wird
einen Durchgang später, weil `scrollTo` die Größe braucht, die das Element
dann erst hat.

## Zwei Finger, Doppelseiten — und eine Karte, die nie kam (1.0.17)

Drei Wünsche und ein Fehler, der beim Nachrechnen des dritten auffiel.

### Zwei Finger zoomen die Seite

Gewünscht: „Ich weiß, dass es links einen Regler gibt, aber der ist mir zu
umständlich zu bedienen." Die Geste hängt am Inhalt der Bühne, nicht an einer
einzelnen Seite: Gezoomt wird das Blatt und nicht, was darauf liegt.

**Damit gibt es erstmals zwei Bedeutungen für dieselbe Geste.** Seit 1.0.8
vergrößern zwei Finger über dem gewählten Foto den Bildausschnitt im Rahmen.
Aufgelöst wird das an einer Stelle: Ist ein Foto gewählt, gehört die Geste dem
Bild, sonst der Seite. Das ist erlaubt, weil der Unterschied **sichtbar** ist —
die Anfasser stehen da, ein Tipp daneben hebt die Auswahl auf — und weil die
Lupen unten links immer gehen, unabhängig von jeder Auswahl.

Beim Bauen fiel daneben auf: Der geltende Maßstab war bei eingepasster Ansicht
eine feste **0,7**, also eine Schätzung. Die Lupen sprangen damit auf einen
Wert, der mit dem Bild auf dem Schirm nichts zu tun hatte. Jetzt wird die
Bühnenbreite gemessen und der eingepasste Maßstab daraus gerechnet.

### Doppelseiten, und das Vorsatzpapier gehört dazu

Gewünscht: „Ein Buch hat ja Seiten mit Vorder- und Rückseite. Und auf das
Titelblatt kommt ja zunächst einmal die Innenseite des Hardcovers."

Das ist Buchbinderei und keine Geschmacksfrage: Ein Recto trägt eine ungerade
Nummer, **Seite 1 liegt also rechts**. Der erste Bogen zeigt links die
Innenseite des Umschlags — beim Hardcover das Vorsatzpapier. Die kommt von der
Druckerei, steht in keinem PDF und zählt in keiner Seitenzahl; gezeigt wird sie
trotzdem, denn sonst läge Seite 1 links und damit falsch. Und sie steht mit
ihrem Namen da: Eine leere graue Fläche ohne ein Wort hielte man für einen
Fehler.

* **Gepaart wird über das ganze Buch und erst danach nach Tag gefiltert.**
  Sonst verschöbe eine Auswahl die Paarung, und ein Tag, der auf einer linken
  Seite anfängt, stünde plötzlich rechts. Gezeigt wird jeder Bogen, auf dem eine
  Seite der Auswahl liegt — samt der Nachbarseite, auch wenn die zu einem
  anderen Tag gehört. Genau so liegt das Buch auf dem Tisch.
* **Zwischen zwei gegenüberliegenden Seiten liegt kein Abstand.** Im gebundenen
  Buch stoßen sie am Bund aneinander; der helle Streifen dazwischen ist der
  Anschnitt beider Seiten, und wo der endet, zeigt die rote Schnittkante.
* **Der Umschalter steht unten neben den Lupen**, nicht in einem Menü: Er
  gehört zur Ansicht.
* Hat das Buch eine **ungerade** Seitenzahl, steht das unter den Bogen — mit
  dem Hinweis, dass viele Druckdienste eine gerade verlangen. Geprüft ist das
  nicht, gezählt schon.

Am PDF ändert die Ansicht nichts: Der Bundsteg wird seit 1.0.1 ohnehin auf
beide Ränder gerechnet.

### Die Automatik läuft — die Reisespur setzte aber keine Seite neu

Gefragt: „Was das Programm auszeichnen würde, wäre ja, dass automatisch Texte,
Bilder und Koordinaten bestimmten Tagen zugeordnet werden und diese Seiten
automatisch erstellt werden."

Das tut sie, und zwar an drei Stellen — nur eine davon war kaputt. Der
Textimport (`textVerteilen`) und die Fotoeinfuhr setzen nach dem Einlesen alle
unberührten Tage neu. Die Reisespur rief dagegen nur „fehlende Seiten
nachholen", **und das überspringt jeden Tag, dessen Seiten schon stehen**. Der
Kartenblock entsteht aber erst, wenn der Tag eine Spur hat. In genau der
Reihenfolge, die der Nutzer beschreibt — erst der Text, dann die Reisespur —
kam damit auf keiner Seite eine Karte, und zwar stumm: Die Tage standen da, die
Punkte standen in der Liste, gesetzt wurde nichts. Dass es beim anschließenden
Einlesen der Fotos doch noch aufgefallen wäre, war Zufall.

Dieselbe Wurzel eine Ebene tiefer: Der erste von Hand gesetzte Punkt brachte
die Karte auch nicht. Neu gesetzt wird jetzt, wenn „hat eine Spur" umkippt —
nicht bei jedem weiteren Punkt, und nie über Handarbeit hinweg.

**Nicht gemessen:** Ob die Geste auf einem Gerät flüssig ist und sich mit dem
Blättern verträgt, ist am Quelltext entschieden und nicht gesehen. Der Zoom
verfolgt den Mittelpunkt der Geste nicht — gezoomt wird um die obere linke Ecke.

## Nur bauen, was zu sehen ist (1.0.16)

Gemeldet, gleich nach 1.0.15: „Erst ging es. Als ich auf eine andere Seite
wollte, fror es ein." Dazu das Bild des Messfühlers:

```
Inspektor 18/s (48 in 2,7 s) · Seite 36/s (98 in 2,7 s) · Absätze 0,0 ms
```

**Damit ist die Erklärung von 1.0.15 für diesen Fall widerlegt.** Der
Absatzlauf kostet null Millisekunden, die Raten sind mäßig — und der
Inspektor war auf dem Bild zugeklappt; er zählte trotzdem mit, weil eine
Spalte auch zugeklappt einen Körper hat. Was 1.0.15 abgestellt hat, war
richtig abgestellt. Es war nicht das hier. Genau dafür war die Probe da.

Was sich stattdessen abzählen lässt, und es passt zum Zeitpunkt:

* **Die Bühne baute jede Seite sofort auf.** Ein `VStack` ist nicht lazy; er
  baut auch das Kind, das zwanzig Seiten tiefer liegt. An jeder Seite hängen
  alle Textkästen (je ein voller CoreText-Satz) und alle Fotos (je ein
  Vorschaubild, von der Platte gelesen und auf dem Hauptfaden entpackt). Ist
  kein Tag gewählt, sind das sämtliche Seiten des Buches — und beim Wechsel
  entsteht das alles neu. Jetzt ein `LazyVStack`.
* **Die Seitenliste setzte das Titelblatt neu, zweimal je Durchgang.**
  `Reise.seitenfolge` ist eine berechnete Eigenschaft; darin baut `automat`
  ein Wörterbuch über alle Fotos des Buches, und `titelseite(…)` setzt das
  Titelblatt samt zwei CoreText-Messungen. Gelesen wurde sie im Körper von
  `ReiseView` — einmal für die Liste, einmal für die Prüfung auf leer. Die
  Liste steht jetzt im Reisewerk, das Titelblatt wird gemerkt.
* **`Textkasten.updateUIView` forderte bedingungslos eine Neuzeichnung an.**
  Diese Methode läuft bei jedem Durchgang des SwiftUI-Körpers, und dahinter
  steckt ein CoreText-Satz je Textkasten. Jetzt nur bei echter Änderung.

Gemerkt wird ausdrücklich **nur das Titelblatt**: Es ist die einzige Seite,
die es nicht gibt, sondern die gerechnet wird. Die Blöcke eines Tages zu
merken hieße, beim Schieben einen alten Stand zu zeichnen.

### Das Papierkorn flimmerte

Beim Nachrechnen gefunden: Bildschirm und PDF würfelten das Korn getrennt,
jeder mit einem Zufallsstrom, der sich nicht wiederholen lässt. Auf dem
Bildschirm war es damit bei jeder Neuzeichnung ein anderes — ein Flimmern
statt einer Struktur —, und die gedruckte Seite sah nie aus wie die
angesehene. Im Quelltext stand daneben, der Strom sei „an der Seite
festgemacht"; er war es nie. **Ein Kommentar ersetzt keine Prüfung.**

Gerechnet wird es jetzt an einer Stelle, von Ansicht und PDF gemeinsam, mit
einer Saat aus der Seitenkennung — und die kommt aus deren Bytes und nie aus
`hashValue`, den Swift bei jedem Programmlauf neu streut.

### Die Probe zählt jetzt auch Summen

`Zeichenmesser.sammelt` nennt, wie oft etwas im Zeitfenster gelaufen ist und
wie viel Zeit dabei zusammenkam — Fotos, Seitenliste, Titelblatt. Die letzte
Dauer sagt darüber nichts; sie ist gerade dann klein, wenn der
Zwischenspeicher zufällig traf. Dazu ein Knopf **„Befund kopieren"** unter
Anordnen: Eine Messung, die man abfotografieren muss, kommt verkürzt an.

**Nicht gemessen:** Abgezählt ist, was je Neuzeichnung und je Seitenwechsel
anfiel. Ob das Gerät danach flüssig ist, sagt erst der nächste Befund — es
ist die zweite Erklärung für dasselbe Einfrieren.

## Was bei jedem Bildpunkt lief (1.0.15)

Gemeldet: „Nach kurzer Zeit ist die App nun eingefroren." Gemessen werden
kann das hier nicht — es gibt kein Gerät. Abzählen lässt sich dagegen, wie
viel Arbeit je Neuzeichnung anfällt, und in 1.0.14 war das zu viel.

Der Block-Inspektor ist eine **Spalte**: Er steht offen, während gearbeitet
wird, und sein Körper läuft bei jeder Meldung des Reisewerks noch einmal.
Seit 1.0.8 wandert ein geschobener Rahmen sofort ins Modell — beim Schieben
meldet sich das Werk also bei jedem Bildpunkt. Drei Dinge lagen in diesem
Körper:

* **Ein Menü mit einem Knopf je Absatz.** Der Inhalt eines `Menu` entsteht
  beim Zeichnen des Formulars, nicht beim Aufklappen. Ein eingelesener
  Tagebuchtext ist hart umbrochen, also ist jede Zeile ein Absatz: Bei einem
  Tag mit zweihundert Zeilen wurden zweihundert Knöpfe gebaut, sechzigmal in
  der Sekunde. Die Auswahl steht jetzt in einem Blatt mit einer Liste — die
  baut nur, was zu sehen ist, und erst beim Öffnen.
* **Zweimal die Absatzliste** über den ganzen Text. Sie wird jetzt einmal je
  Änderung gerechnet und gemerkt.
* **Zwei Suchläufe durch alle Blöcke** in der Werkzeugleiste, wo einer reicht.

**Und weil sich das hier nicht nachmessen lässt, misst es die App.** Unter
Anordnen → „Bedienung prüfen" steht seit 1.0.15 neben dem letzten Griff auch,
wie oft sich Seite und Inspektor in der Sekunde neu zeichnen — mit der
Zeitspanne dabei, denn eine Rate ohne ihren Zeitraum ist keine Messung. Der
Messfühler ist bewusst nicht beobachtbar: Ein Messgerät, dessen Meldung ein
Neuzeichnen auslöst, erzeugt seinen eigenen Messwert.

Beim Nachrechnen fiel noch etwas auf: Die **Notbremse** des Layoutautomaten
(200 Durchgänge, gegen eine Endlosschleife) gab den Rest des Textes zurück,
und danach setzte ihn niemand mehr — derselbe Verlust wie im ersten
gedruckten Stand, nur in einem Zweig, den bisher niemand betrat. Er wird
jetzt gesetzt und läuft notfalls sichtbar über.

**Nicht gemessen, samt Gegenprobe:** Die Rechnung gilt nur, wenn der
Inspektor offen war. War er zu, ist sie widerlegt — dann sagt der Messfühler
beim nächsten Mal, wo es hakt.

## Der Weg durch ein ganzes Buch (1.0.14)

Beschrieben hat ihn der Nutzer selbst: erst das Tagebuch aus Word — daraus
entstehen die Reisetage —, dann die Reisespur, die an jedem Tag eine Karte
hinterlässt, zuletzt die Fotos, die sich in unterschiedlicher Stückzahl auf
die Tage verteilen. Die drei Einfuhrwege gab es schon (`Dienste/Textimport.swift`,
`Dienste/Spureinfuhr.swift`, `Dienste/Fotoeinfuhr.swift`); was daran nicht
stimmte, war das Zusammensetzen danach.

**Der Seitenumbruch sucht jetzt zuerst einen Absatz.** Dass ein zu langer Text
auf der nächsten Seite weitergeht, konnte der Layoutautomat seit 1.0.0 —
geteilt wurde aber an der letzten Wortgrenze, also mitten im Gedanken. Vor ihr
wird nun die letzte Absatzgrenze gesucht, die noch auf die Seite passt.

Der Absatz gewinnt nicht um jeden Preis. Steht seine Grenze weit oben, weil ein
einziger langer Absatz den Rest der Seite füllt, bliebe unten eine große weiße
Fläche stehen — und die sieht nach Abbruch aus. Gemessen wird deshalb mit
CoreText, wie hoch der Kopf bis zu dieser Grenze wird, und verglichen mit dem
Platz, den es gibt: Bleiben weniger als 62 Prozent gefüllt, wird wie bisher an
der Wortgrenze geteilt. **Die Zahl ist gewählt und nicht gemessen.**

Ein Absatz ist dabei der Zeilenwechsel und nicht die Leerzeile: `Schriftbild`
setzt den Absatzabstand als `paragraphSpacing`, und CoreText zählt dafür genau
dieselbe Grenze. Zwei Meinungen darüber, wo ein Absatz aufhört, wären zwei
verschiedene Umbrüche.

**Die Fotos warten nicht mehr, bis der Text fertig ist.** Bis 1.0.13 füllte der
Text auf jeder Folgeseite die ganze Höhe; ein Tag mit langem Text und vielen
Bildern ergab erst mehrere reine Textseiten und danach reine Fotoseiten — das
Bild zum Erzählten stand drei Seiten weiter. Freigehalten wird jetzt die
gemessene Höhe der nächsten Fotoreihe (`naechsteReihe` rechnet sie ohnehin aus)
und kein geschätzter Anteil: Ein Anteil, der zu klein ist, lässt die Reihe doch
nicht hinein, und dann bliebe unten weißer Platz, den niemand bestellt hat.
Passen nach der Reihe keine sechs Zeilen Text mehr auf die Seite, wird gar
nichts freigehalten — eine Seite mit vier Zeilen über einem Bild ist kein Satz,
sondern ein Rest. Ist kein Foto mehr offen, gilt wieder die ganze Seite.

**Und im Nachhinein lässt sich ein Textkasten teilen.** Zwei Wege, weil es zwei
Fragen sind:

* **„Rest auf die nächste Seite"** lässt stehen, was in den Kasten passt, und
  legt den Überhang als zweiten Kasten auf die folgende Seite. Die Stelle sagt
  der Satz; man muss sie nicht suchen.
* **„Nach einem Absatz teilen"** trennt an einer selbst gewählten Stelle und
  gilt auch dann, wenn gar nichts herausfällt. Ausgesucht wird nach dem Anfang
  des Absatzes — „Absatz 4" sagt niemandem etwas, „Am Morgen zogen wir …"
  schon.

Der erste Kasten behält dabei seine Größe. Ihn auf den verbliebenen Text zu
schrumpfen wäre der naheliegende Griff und der falsche: dieselbe Regel wie beim
Mitwachsen — ein Kasten, der von selbst kleiner wird, nimmt eine Größe weg, die
jemand mit der Hand eingestellt hat. Die Fortsetzung ist eine Kopie mit neuer
Kennung und sieht aus wie ihr Anfang (Schrift, Grund, Innenabstand, Linie,
Breite); steht auf der Folgeseite schon etwas, bekommt sie eine eigene Seite
unmittelbar dahinter. Beide Kästen gelten danach als Handarbeit und werden
nicht ohne Rückfrage neu angeordnet.

Zu finden ist das an drei Stellen: Block → Teilen, unten in der Leiste neben
„Rahmen an Text anpassen", sobald die orange Marke zu sehen ist, und als Zeile
in der Bedienungskarte hinter dem „?".

**Nicht gemessen:** Kein Buch ist damit gesetzt worden. Gerechnet sind die
Regeln — wo ein Absatz aufhört, wie hoch der Kopf wird, wie hoch die nächste
Fotoreihe ist. Wie eine Doppelseite damit aussieht, sagt erst der nächste
Befund.

## Der Textimport nimmt jetzt Word, PDF und reinen Text (1.0.13)

Gewünscht: „Ich möchte Texte im Word-Format, PDF oder reinen Text eingeben
können." Bis 1.0.12 nahm der Import nur eine Textdatei entgegen.

Alles, was eine Datei in Text verwandelt, steht seither an **einer** Stelle
(`Dienste/Textquelle.swift`). Der Bildschirm ruft eine Funktion und bekommt
einen Befund; ob dahinter PDFKit, ein ZIP-Leser oder eine Kodierungsleiter
steckt, weiß er nicht.

**Entschieden wird an den ersten Bytes, nicht an der Endung** — dieselbe
Lehre wie in Textauszug, wo sechs Kilobyte HTML mit `.pdf` im Namen ankamen.
Eine Endung ist eine Behauptung, die ersten Bytes sind eine Tatsache.

### PDF

Gelesen mit PDFKit. Textauszug muss seinen PDF-Leser selbst schreiben, weil
im Browser keiner mitgeliefert wird; auf iOS gehört einer zum System.

Der Preis ist die Kopfzeilenerkennung: Textauszug misst den **Abstand** zum
Satzspiegel, PDFKit gibt die Zeilenlagen nicht heraus. Erkannt wird hier
deshalb die **Wiederholung** — eine Zeile, die auf den meisten Seiten ganz
oben oder ganz unten steht und sich nur in ihren Ziffern unterscheidet
(„Seite 3 von 30" und „Seite 4 von 30" werden auf dasselbe Muster gebracht).
Das ist ein anderes Merkmal und wird auch anders falsch: Ein Buch mit
wiederkehrendem Refrain als erster Zeile verlöre ihn. **Deshalb steht
hinterher wörtlich da, was entfernt wurde.**

Unter drei Seiten wird gar nichts entfernt. Ein Scan und eine
kennwortgeschützte PDF sagen je einen Satz, der den Weg drumherum nennt.

### Word

Eine `.docx` ist ein ZIP mit `word/document.xml` darin — und auf iOS gibt es
keinen öffentlichen Entpacker, dieselbe Lücke, wegen der `Buchdatei` ein
eigenes Format schreibt. Ausgepackt wird mit Apples `Compression`:
`COMPRESSION_ZLIB` ist dort das **rohe DEFLATE** nach RFC 1951, und genau das
steht in einem ZIP. Gelesen wird über das zentrale Verzeichnis am Ende, nicht
durch Vorwärtssuche nach lokalen Köpfen.

`NSAttributedString` wäre der kurze Weg und kann es auf iOS nicht: Der
`officeOpenXML`-Typ existiert nur auf dem Mac. RTF dagegen kann es wirklich,
und ohne WebKit — deshalb bleibt genau dieser eine Weg bei Apple.

Aus dem XML wird **nur `w:t` in einem `w:r`** gelesen: `w:instrText` trägt
Feldbefehle, `w:delText` gelöschten Text aus der Nachverfolgung. Zwei Fallen
daneben — `w:tab` gibt es im Lauf (ein Zeichen) und in den
Absatzeigenschaften (die Definition eines Tabstopps), und „p" und „t" gibt es
auch in DrawingML, also in Schaubildern; gezählt wird deshalb der Namensraum.

Ein `w:br` wird zur **Zeile**, nicht zum Absatz — genau der hart umbrochene
Text, den `Textaufbereitung` seit 1.0.12 wieder zusammenführt.

Die alte binäre `.doc` wird an ihrer Kennung erkannt und mit einem klaren
Satz abgewiesen.

### Reiner Text

Byte-Vorzeichen zuerst, dann UTF-8, dann Windows-1252, dann ISO 8859-1.

**Die Reihenfolge ist der ganze Punkt.** `isoLatin1` nimmt jedes Byte an und
scheitert nie; bis 1.0.12 stand es vor `windowsCP1252`, und damit war dessen
Zweig unerreichbarer Quelltext: Die Bytes 0x80 bis 0x9F einer Windows-Datei —
also die typografischen Anführungszeichen, der Gedankenstrich, die Auslassung
— wurden zu unsichtbaren Steuerzeichen, ohne eine einzige Fehlermeldung. Und
eine UTF-16-Datei kam als Salat mit Nullbytes an, aus demselben Grund.

### Was hinterher dasteht

Art, Dateiname, Seiten, Absätze, Kodierung, Zeichenzahl — und die entfernten
Randzeilen im Wortlaut.

**Nicht gemessen:** Keiner der vier Wege ist an einer echten Datei gelaufen;
hier gibt es weder Word noch PDFKit. Gerechnet ist der Aufbau — ZIP-Verzeichnis,
DEFLATE-Sorte, welche Word-Elemente Text tragen, welche Kodierung wann
scheitert. Ob eine bestimmte Datei durchgeht, sagt erst der nächste Befund.

## Drei Befunde aus dem laufenden Buch (1.0.12)

### Der Text stand wieder außerhalb seines Rahmens

Gemeldet, zum zweiten Mal: „Das Bearbeiten des Textes im Kasten funktioniert
noch nicht richtig. Wieder wird beim Doppeltipp der Text außerhalb des
Rahmens dargestellt."

1.0.9 hatte die DOPPELUNG behoben — der Block wird seither nicht mehr
zusätzlich gezeichnet, solange sein Text im Feld steht. Der Überstand blieb,
und er war ein zweiter Befund im selben Bild.

Die Ursache lässt sich am Quelltext nachzählen: Das Feld ist ein
`UITextView` mit `isScrollEnabled = false`, und so eines meldet die Größe,
die sein Text BRAUCHT. Ein `UIViewRepresentable` ohne `sizeThatFits` gibt
SwiftUI genau diese Zahl weiter — und **ein `.frame()` beschneidet nicht, es
stellt ein zu großes Kind mittig hin.** Genau das zeigte das Bildschirmfoto:
der Text über die halbe Seite, mittig auf dem orangen Rechteck, die Absätze
zu drei sehr langen Zeilen geworden.

Zurückgegeben wird jetzt die angebotene BREITE — nie mehr — und die HÖHE,
die der Text darin wirklich braucht. Ausgerichtet wird oben links, und die
Höhe steht als `minHeight` statt als feste Zahl: So wächst der Kasten beim
Tippen nach unten, wie ein Textfeld in Pages, statt Zeilen zu verschlucken.

### Textfelder lassen sich jetzt fürs ganze Buch einstellen

Gefragt: „Kann ich global einstellen, wie die Einstellungen für die
Textfelder sein sollen? Ich möchte das können."

**Buch → „Textfelder…"** — farbiger Grund samt Deckkraft, Innenabstand,
Linie ringsum, Schatten. Dieselbe Bauweise wie bei den Fotos seit 1.0.9:
Was hier steht, ist eine Vorgabe und keine Kopie. `nil` am einzelnen Block
heißt „wie im Buch", aufgelöst an der einen Stelle (`Block.wirkung`), die
Bildschirm und PDF gemeinsam fragen. Im Inspektor führt ein Knopf dorthin
und sagt, wo man steht („Folgt dem Buch" oder „Für alle Textfelder
einstellen").

Zwei getrennte Sätze für Foto und Text, nicht einer: Ein Textkasten mit dem
Schatten aller Fotos wäre eine Überraschung, und wer den weißen
Sofortbild-Rand seiner Bilder hochzieht, meint nicht die Schrift.

Dazu ein neues Feld `Block.ohneGrund`. Solange es nur den Block gab, hieß
`grund == nil` zweierlei auf einmal: „nichts gesetzt" und „keiner". Sobald
das Buch einen vorgibt, fällt das auseinander — der Schalter ginge aus, der
Grund käme zurück, und für den Menschen davor wäre der Schalter kaputt.

### Der Textimport machte aus jeder Zeile einen Absatz

Gefragt: „Der Textimport hat offenbar am Ende jeder Zeile einen Absatz
erzeugt. Ich frage mich, ob das an meiner Vorlage lag … oder ob der
Textinterpreter nicht richtig funktioniert."

Der Textinterpreter. Und die Rechnung sagt auch, warum. **Nachgerechnet am
gemeldeten Tag** (4. Juni 2026, sieben Zeilen von 46, 102, 104, 56, 43, 31
und 16 Zeichen): die längste 104, die Grenze bei 85 % davon, also 88 — und
nur zwei der sieben Zeilen erreichen sie. Das sind 29 % gegen eine Schwelle
von 35 %, die Erkennung stand still.

Gemessen wurde bis 1.0.11 je TAG. Ein kurzer Tag endet aber nun einmal mit
einer kurzen Zeile, und je kürzer der Tag, desto schwerer wiegt sie. Wo die
Umbruchspalte lag, hat der Schreiber dagegen EINMAL für die ganze Datei
entschieden. Gemessen wird deshalb einmal über den gesamten Text, und das
Ergebnis wird an jeden Tag weitergereicht.

Dazu zwei Zeichen, die unabhängig von der Länge entscheiden — beide stehen
im gemeldeten Text: ein **Bindestrich am Zeilenende** („Boeing 747-" /
„400") ist ein zerrissenes Wort, und ein **Komma am Zeilenanfang** („,
zurück nach Frankfurt") kann kein Absatzanfang sein. „Fängt klein an" allein
reicht bewusst nicht: Ein zu Unrecht zusammengezogener Absatz ist der
teurere Fehler, weil er im gedruckten Buch nicht mehr zu sehen ist.

Und die Zahlen stehen jetzt im Einlesen-Blatt: längste Zeile, Anteil,
Zeilenzahl, Schwelle, Ergebnis. Je Tag steht die Zeile auch dann da, wenn
NICHT zusammengeführt wurde — eine Erkennung, die schweigt, wenn sie nichts
tut, lässt einen raten.

### Beim Gegenlesen gefunden

* `Gestaltung`, `Block` und `Seite` lesen sich seit 1.0.12 von Hand
  (`Model/Nachsicht.swift`). Die Regel galt seit 1.0.3 für `Reise` und
  `Reisetag`; die Typen darunter hatten sie nicht, und genau in ihnen wuchs
  diese Fassung. Ein neues Feld in `Gestaltung` hätte in jedem vorhandenen
  Buch Format, Ränder, Bundsteg, Anschnitt und Fotowirkung auf die Vorgaben
  zurückgesetzt — still, denn das Buch öffnet sich ja. Ein neues Feld in
  `Block` hätte die ganze Seitenliste eines Tages mitgenommen.
* `Farbwert(_:deckung:)` hält die Deckkraft fest. Der Farbwähler steht auf
  `supportsOpacity: false` und gibt immer volle Deckung zurück; seit 1.0.11
  steht daneben ein eigener Deckkraft-Schieber — jeder Griff an die
  Grundfarbe setzte ihn also stillschweigend auf 100 %.

**Nicht gemessen:** ob das Textfeld beim Doppeltipp jetzt wirklich im Rahmen
steht, und ob die Umbruch-Erkennung an der Vorlage des Nutzers greift. Das
erste ist gerechnet, das zweite an seinen Zahlen nachgerechnet; ein Gerät
und die Datei gibt es hier nicht.

## Vier Befunde aus dem laufenden Buch (1.0.11)

### Die Karte zeigte nichts — und es gab keinen Weg heraus

Gemeldet: „Auf der Karte wird ja quasi nichts dargestellt. Der Ort könnte
sonst wo sein. … Ich möchte die Karte rein und heraus nehmen können."

Den Wert dafür (`Reisetag.kartenausschnitt`) gibt es seit der ersten
Fassung. **Setzen konnte ihn niemand**: Im Inspektor stand einzig der Knopf
„Wieder automatisch rahmen" — das Rückgängig zu einer Tat, die es nicht
gab. Gerahmt wurde deshalb immer selbsttätig um die Tagesspur, und bei
einem einzigen Punkt rechnet `Kartenwerk.region` eine Spanne von 0,008 Grad,
also rund 900 Meter. Die Karte war nicht falsch, sie war zu nah.

**Merke: Ein Knopf, der etwas zurücknimmt, setzt voraus, dass es einen Weg
hin gibt.** Ein Feld, das nur gelesen und nie geschrieben wird, ist ein halb
gebautes Vorhaben — dieselbe Art Befund wie bei der Bildunterschrift in
1.0.5.

* **Block → Ausschnitt → „Ausschnitt auf der Karte wählen"** öffnet eine
  echte Karte. Übernommen wird das FENSTER, nicht eine Stelle — deshalb ein
  Rahmen und kein Fadenkreuz wie bei der Ortswahl.
* **„näher" und „weiter"** stehen daneben im Inspektor: Wer nur etwas
  herauszoomen will, soll dafür keinen Bildschirm öffnen müssen. Beide
  rechnen vom GELTENDEN Ausschnitt aus, also auch vom automatischen.
* Die Spanne steht in Kilometern da. Eine Gradzahl sagt niemandem etwas.

### Beschriftungsdichte gibt es bei MapKit nicht

Gewünscht war, „wie dicht die Beschriftungen sein sollen". Was sich
wirklich einstellen lässt, ist der Filter für ORTE (`pointOfInterestFilter`):
Geschäfte, Museen, Haltestellen. Straßen- und Ortsnamen setzt Apple selbst,
nach Maßstab — dafür gibt es keine Schraube; wer weniger davon will, nimmt
die Karte näher heran.

**Genau das steht in der Oberfläche**, statt einen Regler anzubieten, der
nichts tut. Drei Stufen: „Alle Orte", „Wenige", „Keine Orte".

* Beim **Satellitenbild** entscheidet die Wahl über die Art des Aufbaus:
  `MKImageryMapConfiguration` zeigt überhaupt keine Namen, die gibt es nur
  über `MKHybridMapConfiguration`.
* Bei **OpenStreetMap, OpenTopoMap und eigenem Server** ist die Beschriftung
  fertig im Kachelbild. Keine Einstellung dieser App kann daran etwas
  ändern, und die App sagt das dort auch.
* Geändert gegenüber 1.0.10: „Gelände" schaltete die Orte fest ab. Das war
  als Stilfrage gebaut und ist jetzt eine eigene Einstellung.

### Das Einrasten war stumm

Gewünscht: „Der Randindikator soll sich an den Rand und die Fotos
orientieren, aber im Einzelfall auch veränderbar sein."

Gefangen hat der Block an Rand und Nachbarn schon immer — er sprang dabei um
zwei Punkte, und ob das der Satzspiegel war, die Schnittkante, das Foto
darüber oder gar nichts, stand nirgends. **Eine Hilfe, die man nicht sieht,
ist für den Menschen davor ein Zucken.**

* Beim Schieben steht jetzt eine **Linie über den ganzen Bogen**, mit der
  Herkunft als Wort und als Farbe: „Rand", „Schnittkante", „Nachbar". Das
  sind drei verschiedene Auskünfte.
* Die Kanten kommen aus **einer** Quelle (`Einrasten.kanten`). Vorher baute
  das Verschieben seine Liste selbst und das Größenändern eine zweite, und
  nur die zweite kannte die Schnittkante.
* „Im Einzelfall veränderbar" sind zwei Dinge: der Schalter **„An Rand und
  Nachbarn einrasten"** unter „Anordnen" — wer ihn ausmacht, bekommt auch
  keine Linien, denn eine Linie ohne Wirkung wäre eine Behauptung — und die
  Zahl in Millimetern im Inspektor unter „Lage auf der Seite".

### „Warum so viel Platz nach jedem Absatz?"

Den Absatzabstand gibt es buchweit seit der ersten Fassung (Buch → Schrift).
Gefehlt haben zwei Dinge, und das zweite ist das wichtigere:

* **Die Ausnahme an der einzelnen Stelle** — Block → Schrift an dieser
  Stelle → Absatzabstand.
* **Der Grund.** Er steht im Text selbst: Ein hart umbrochen eingelesener
  Tagebuchtext hat je ZEILE einen Absatz, und dann steht der Abstand eben
  nach jeder Zeile. Der Inspektor zählt die Absätze deshalb und bietet das
  Zusammenführen dort an, wo die Frage entsteht. **Eine Zahl, die den Befund
  erklärt, ist mehr wert als ein Regler, der ihn verdeckt.**

Warum die Erkennung aus 1.0.2 bei genau diesem Text nicht gegriffen hat, ist
**nicht geklärt** — gemessen ist sie an zwei Texten, der gemeldete ist ein
dritter.

### Ein Textfeld mit Hintergrund

Gewünscht: „Ein Hintergrund … und dessen Transparenz … So könnte
beispielsweise auch Text auf einem Hintergrundbild gemacht werden."

Den farbigen Grund gab es; was fehlte, waren die zwei Dinge, die ihn
brauchbar machen — beide unter Block → Rand und Grund:

* **Deckkraft als eigener Schieber.** Der Farbwähler von iOS kann sie, aber
  hinter einem Tipp auf das Farbfeld; wer sie sucht, findet sie nicht. Sie
  ist hier kein Schmuck, sondern der Zweck.
* **Innenabstand.** Schrift, die unmittelbar an der Kante einer Fläche
  anfängt, sieht aus wie ein Satzfehler. Er wird beim Einschalten des
  Grundes gesetzt und beim Ausschalten nicht zurückgenommen.

Der Innenabstand wird an **allen vier** Textstellen mitgerechnet: Bildschirm,
PDF, Überlaufmessung und Druckprüfung. Vergäße man eine davon, sagte die
Marke „passt", während im Druck eine Zeile fehlt.

### Nebenbei gefunden

**Ein neues nicht-optionales Feld macht jede gesicherte Datei unlesbar —
auch in einem kleinen Typ.** `Kartenbild` bekam die Beschriftung und braucht
deshalb einen Leser von Hand. Aufgefallen beim Gegenlesen und nicht im Bau:
`Reisetag` liest sein `kartenbild` über `wahlweise`, und das schluckt den
Fehler — die Karteneinstellung wäre still auf die Vorgabe zurückgefallen.
Die Regel steht seit 1.0.3 im Papier und galt bis dahin nur für `Reise` und
`Reisetag`; sie gilt für jeden Typ, der wächst.

## Finden statt suchen (1.0.10)

Gemeldet 09/2026: „Kann ich das jetzt für alle Fotos global einstellen und
wenn ja, wo? Irgendwie ist die App nicht intuitiv zu bedienen."

Die Einstellung gab es seit 1.0.9. Sie lag hinter **Buch → „Format, Ränder,
Karte…"** — hinter einem Menüpunkt, der nach Papiermaßen klingt. Das ist in
dieser App jetzt der vierte Befund derselben Art: die Bildunterschrift
(1.0.6), das Zurücksetzen in Tafelbild, der Gruppenchat in Schulalarm, und
nun das. **Ein Menüpunkt, der nicht sagt, was dahinter liegt, ist so wenig
wert wie ein Knopf, den niemand findet.**

* **„Fotos…" steht eigenständig im Buch-Menü**, gleich unter Stil und
  Schrift. Die Felder selbst stehen einmal da (`Views/Fotostil.swift`,
  `Fotostilfelder`) und werden an zwei Stellen gezeigt — im eigenen Blatt
  und weiterhin als Unterseite der Gestaltung. Zwei Fassungen desselben
  Formulars liefen auseinander.
* **Vom einzelnen Foto zum ganzen Buch führt ein Knopf.** Wer im Inspektor
  die Wirkung eines Fotos ändert, ist genau die Person, die „und für alle?"
  fragt. Der Knopf sagt, wo man steht („Für alle Fotos einstellen" bzw.
  „Dieses Foto weicht ab — für alle einstellen"); „Wieder wie im Buch" nimmt
  die Abweichung zurück.
* **Die Gesten stehen aufgeschrieben** („?" unten in der Leiste,
  `Views/BedienungView.swift`). Eine Buchseite ist seit 1.0.5 eine
  Zeichnung, und jeder Griff daran ist eine Geste: Tipp, Doppeltipp, Ziehen
  am Punkt, zwei Finger auf dem Foto. Nichts davon sieht man. Die Karte
  zählt auf, was geht und wo was eingestellt wird — sie erklärt nichts,
  denn wer sie öffnet, sucht etwas Bestimmtes. Wer eine neue Geste einbaut,
  trägt sie dort ein.
* **„Satz" heißt jetzt „Anordnen".** „Satz" ist das Fachwort für das, was der
  Layoutautomat tut; gesucht wird es von jemandem, der eine Seite neu
  verteilt haben will.

**Ob sich die App dadurch anders anfühlt, ist nicht gemessen.** Gemessen
sind Wege: Die Einstellung liegt eine Ebene höher und heißt nach ihrer
Sache, die Gesten stehen an einer Stelle. Ob das reicht, sagt erst der
nächste Befund.

## Bildunterschriften (1.0.5)

Gewünscht 09/2026: „Ich möchte zu jedem Foto einen Beschreibungstext
zufügen können … Dies soll jedoch eine Option für jedes Foto sein. Kein
muss."

Dabei kam heraus, dass die Unterschrift eine **halb gebaute** Sache war:
Der Layoutautomat hielt Platz für sie frei, das PDF zeichnete sie — auf dem
Bildschirm erschien sie nie, und anfassen ließ sie sich gar nicht. Ein Feld
im Inspektor gab es, aber keinen Weg zu sehen, was es bewirkt.

* **Sie ist jetzt ein eigener Block** (`Blockinhalt.bildunterschrift`) und
  damit verschiebbar, drehbar und in der Größe zu ziehen wie jeder andere.
  Der TEXT steht weiter am Foto: Wer ein Bild auf eine andere Seite zieht,
  soll seine Unterschrift nicht zurücklassen, und beim Neuanordnen darf sie
  nicht verschwinden — dieselbe Überlegung wie bei Überschrift und
  Datumszeile, die am Tag stehen.
* **Eingeschaltet wird sie je Foto** (`Foto.unterschriftZeigen`), im
  Inspektor oder mit dem Sprechblasen-Knopf in der Fotoliste des Tages. Was
  aus ist, kostet auch keinen Platz im Satz. Der Text bleibt beim
  Ausschalten stehen — wer sie wieder anschaltet, soll seinen Satz
  wiederfinden.
* **Schrift, Größe und Farbe stellt man einmal für alle ein**, unter
  Buch → Schrift, Rolle „Bildunterschrift"; je Block lässt sich davon
  abweichen wie überall sonst.
* **Wer schon eine Unterschrift getippt hatte, behält sie sichtbar**: Beim
  Einlesen eines älteren Buches gilt ein nicht leerer Text als
  eingeschaltet.
* **Gefunden hat den Weg dorthin niemand** (gemeldet 09/2026: „Ich habe noch
  nicht gefunden, wie ich eine Unterschrift unter ein Bild setzen kann.").
  Der Schalter stand im Inspektor hinter dem Abschnitt „Foto" und in der
  Fotoliste des Tages — beides Wege, die man kennen muss. Seit 1.0.6 gibt es
  zwei, die man nicht kennen muss: **ein Doppeltipp auf das Foto** schreibt
  seine Unterschrift (derselbe Griff wie beim Text — man tippt zweimal auf
  das, was man beschriften will), und bei gewähltem Foto steht unten in der
  Leiste der Knopf **„Bildunterschrift"**. Eine Geste, die niemand kennt, ist
  so wenig wert wie ein Knopf, den niemand findet — deshalb beides.
* Ein eingeschalteter, aber noch leerer Kasten steht auf dem Bildschirm als
  blasses „Bildunterschrift …" da und im PDF gar nicht. Eine unsichtbare
  Fläche, die sich nicht antippen lässt, weil niemand weiß, wo sie liegt,
  wäre der schlechtere Tausch.

## Offene Punkte

* **Ob sich die App nach 1.0.45 wieder signieren lässt, ist nicht gemessen.**
  Hier gibt es keinen Mac. Gemessen ist die *Ursache*: Das Recht kam in
  1.0.44 hinein, vorher ließ sich signieren, nachher nicht, und die
  Fehlermeldung nennt genau diesen Schlüssel.
* **Ob `Profilrechte` auf dem Gerät eine Liste findet, ist nicht gemessen.**
  Der Aufbau eines Bereitstellungsprofils ist nachgelesen, nicht an einer
  Datei geprüft. Der Befund sagt es selbst, wenn nichts zu lesen war.
* **Ob das Schriftenrecht wirkt, bleibt offen.** Dass es fehlt, ist am
  Unterschied zwischen Pages und dem Wähler dieser App abgelesen; dass es mit
  dem Recht geht, zeigt erst ein signierter Bau auf dem Mac — und dafür muss
  die App-Id es zuerst tragen.
* **Nichts an 1.0.43 ist auf einem Gerät gesehen.** Ob
  `CTFontManagerCopyRegisteredFontDescriptors(.persistent, true)` auf dem
  iPad des Nutzers überhaupt etwas zurückgibt, ob sich die Einträge als
  `UIFontDescriptor` lesen lassen, ob die Anmeldung greift und ob eine so
  erreichte Schrift ins PDF eingebettet wird, ist offen. Deshalb nennt die
  Probe zwei Zahlen (gemeldet und lesbar) statt einer.
* **Nichts an 1.0.42 ist auf einem Gerät gesehen.** Gerechnet ist die Ursache
  (91 gegen 17 Prozent der Satzhöhe für dasselbe Foto) und die Geometrie der
  Abhilfe. Gewählt und nicht gemessen sind die Grenzen der Zielhöhe (0,16 bis
  0,42 der Satzhöhe), der Deckel darüber (1,3) und die Schwellen der neuen
  Befundzeile. Ob eine Doppelseite damit ausgewogen aussieht, sagt erst der
  nächste Befund — jetzt mit Zahlen daneben.
* **Nichts an 1.0.41 ist auf einem Gerät gesehen.** Ob der Systemwähler die
  selbst installierten Schriften zeigt, ob die Anmeldung auf `.process`
  greift, ob der Name nach einem Neustart trägt und ob eine so gewählte
  Schrift ins PDF eingebettet wird — alles vier offen. Die App misst es und
  sagt es; der nächste Befund ist die Messung.
* **Nichts an 1.0.36 ist auf einem Gerät gesehen.** Überlappung, Staffelhub und
  Drehwinkel sind gerechnet und gewählt, nicht gemessen; ob eine Doppelseite
  damit nach „hingelegt" aussieht oder nach „verrutscht", sagt erst der nächste
  Befund. Der Befund zur „Regieanweisung" ist am Quelltext hergeleitet.
* **Nichts an 1.0.35 ist auf einem Gerät gesehen.** Die Füllung der Seite ist
  gerechnet, nicht angesehen; alle Zahlen darin sind gewählt und nicht
  gemessen, und was die Rechnung an Zeit kostet, ist unbekannt (siehe den
  Abschnitt zu 1.0.35).

* **Nichts an 1.0.34 ist auf einem Gerät gesehen.** Der Planer ist
  gerechnet, nicht angesehen; alle Zahlen darin sind gewählt und nicht
  gemessen (siehe den Abschnitt zu 1.0.34). Ob eine Doppelseite damit nach
  einem Reisebuch aussieht, sagt erst der nächste Befund.

* **Nichts an 1.0.33 ist auf einem Gerät gesehen.** Gerechnet ist, warum eine
  von Hand eingefügte leere Seite beim nächsten Neuanordnen verschwand
  (`Seite.vonHand` fragt die Blöcke, und eine leere Seite hat keine) — dass
  sie jetzt stehen bleibt, folgt daraus. **Wie lange das Duplizieren eines
  Buches mit zweihundert Fotos dauert, ist nicht gemessen**: Es läuft abseits
  des Hauptfadens und sperrt die Liste so lange; ob dabei eine
  Fortschrittsanzeige fehlt, sagt erst der nächste Befund. Und ob
  `FileManager.copyItem` auf dem Gerät eine APFS-Kopie anlegt oder die Bytes
  wirklich verdoppelt, ist ungeprüft — die Platzfrage bleibt damit offen.

* **Nichts an 1.0.32 ist auf einem Gerät gesehen.** Gerechnet ist, warum
  unten auf der letzten Seite eines Tages Platz blieb; dass sie jetzt gefüllt
  aussieht, folgt aus der Geometrie. Die Zahlen sind **gewählt und nicht
  gemessen**: ein Drittel der Satzhöhe fürs Aufmacherband, Deckel 2,2 und
  Schrittweite 1,05 beim Füllen, die Schwellen 600 Zeichen und drei Fotos.
  Ob der Stil „Tagebuch" auf einem Gerät nach Tagebuch aussieht — Iowan Old
  Style, warmes Papier, leicht versetzte Bilder —, sagt erst der nächste
  Befund. Und ob ein Buch, das im alten Stil gesetzt war, nach „Alles neu
  setzen" wirklich besser dasteht, weiß nur, wer es angesehen hat.

* **Wie eine Doppelseite im neuen Rhythmus AUSSIEHT, hat niemand gesehen**
  (1.0.31). Gerechnet ist die Ursache des vollen Textblocks — sie ist am
  Quelltext nachzuzählen und passt zum Bildschirmfoto, gemessen auf einem
  Gerät ist sie nicht. Die sechs Seitenbilder und ihre Zahlen (58 bis 100
  Prozent Spaltenbreite, 0,6 Grad Drehung, ein knapper Fugenhub beim
  Staffeln) sind **gewählt und nicht gemessen**; ob die Folge abwechslungs­-
  reich wirkt oder unruhig, sagt erst der nächste Befund. Ebenso ungeprüft:
  ob ein leicht gedrehter Textblock im PDF sauber steht.
* **Nichts davon ist auf einem Gerät gesehen** (1.0.30). Gerechnet ist, wie
  die Namen zerlegt werden und was die Mediathek auf eine Zeitraumabfrage
  herausgibt; ob eine bestimmte Kamera ihre Dateien so benennt, sagt erst der
  Einfuhrbericht des Nutzers — er nennt die Zahl („Bei n Fotos stand das
  Datum nur im Dateinamen"). Ebenso ungemessen: **wie sich ein Zeitraum mit
  tausend Fotos anfühlt.** Das Einlesen läuft auf dem Hauptfaden und gibt
  zwischen zwei Fotos ab, die Fortschrittszeile zählt also mit — ob das
  flüssig bleibt und ob Bilder aus iCloud rechtzeitig eintreffen, ist nicht
  geprüft. Und ob `PHPickerResult.itemProvider.suggestedName` auf dem Gerät
  wirklich den ursprünglichen Dateinamen trägt, ist die Lesart der
  Dokumentation und keine Messung; der Weg über „Dateien" und der über den
  Zeitraum holen ihn aus verlässlicheren Quellen.
* **Welche Schriften mit rundem a auf dem iPad des Nutzers stehen, weiß hier
  niemand** (1.0.29). Die Messung läuft auf dem Gerät; erst die Liste dort
  sagt, ob Futura Gesellschaft bekommt. Gut möglich, dass die Gruppe dünn
  ausfällt — unter den Schriften, die iOS mitbringt, ist ein einstöckiges a
  selten. Steht dort nichts Brauchbares, wäre der nächste Schritt eine
  mitgelieferte Schrift unter der SIL Open Font License (sie erlaubt
  Einbettung und Weitergabe ausdrücklich, und dieses Repo führt in
  `woerterwerkstatt/fonts/` bereits solche Dateien). Das wäre eine Abkehr von
  der Regel „keine Schriftdatei mitliefern" und gehört abgesprochen, nicht
  nebenbei gemacht.
* **Ungesehen (1.0.29):** ob sich das Verschieben auf eine andere Seite
  richtig anfühlt, und wie eine Doppelseite im Muster „Text und Bilder im
  Wechsel" aussieht. Die beiden Zahlen dahinter (1200 Zeichen, vier Fotos)
  sind gewählt und nicht gemessen.
* **Ob die Geste jetzt verlässlich ankommt, ist NICHT gesehen** (1.0.28). Es
  folgt daraus, wie UIKit zwei Erkenner gegeneinander abwägt, und aus dem
  Vergleich mit dem Bildausschnitt in derselben App — gemessen wird es erst
  durch den Zähler „Zoomgeste" im Befund („Bedienung prüfen"). **Ein
  Nebeneffekt steht offen:** Mit `simultaneousGesture` rollt die Bühne während
  des Aufziehens mit; am Ende rückt der Brennpunkt sie wieder zurecht (so seit
  1.0.18), aber ob das ruhig aussieht oder wie ein Ruck, sagt erst der nächste
  Befund.
* **Die Bühne trägt jetzt wieder das GANZE Buch** (1.0.28). Der `LazyVStack`
  aus 1.0.16 ist genau dafür da; wie sich ein Buch mit zweihundert Fotos dabei
  anfühlt, ist weiterhin ungemessen. Der Zeichenmesser nennt die Summen.
* **Die Broschüre ist nie gedruckt worden** (1.0.27). Gerechnet ist die
  Bogenfolge des Rückenstichs; ob sie gefaltet aufgeht, sagt erst ein
  Probedruck mit vier Seiten. Und welche Wendeeinstellung ein bestimmter
  Drucker benutzt — lange oder kurze Kante —, steht in keiner Datei: Deshalb
  der Schalter „Rückseiten um 180° drehen" und keine Automatik.
* **Die Umrechnung von A4 auf A5 ist gerechnet, nicht gesehen** (1.0.27). Ob
  ein Fließtext, der von 11 pt auf 7,8 pt geht, noch angenehm zu lesen ist,
  sagt erst der Ausdruck. Die Rechnung selbst geht bei A4/A5 ohne Rest auf,
  weil die A-Reihe ein einziges Seitenverhältnis hat; bei unähnlichen
  Formaten bleibt an einer Kante Luft, und das steht in der App.
* **„Erst beim dritten Versuch" ist ein Verdacht, kein Befund** (1.0.27). Die
  Zeile „Seitenzoom: erlaubt/gesperrt (…)" im Befund und die Zähler des
  `Zeichenmessers` sind dafür gebaut, ihn zu bestätigen oder zu widerlegen —
  gemessen ist bisher nichts.
* **Ob die Anfasser jetzt gehen, ist NICHT gemessen.** Es ist die vierte
  Erklärung in dieser Sache. Die ersten drei waren Vermutungen; diese hier
  ist am Quelltext gerechnet und erklärt, warum ausnahmslos jeder Griff als
  „Fläche" ankam — aber ein Gerät gibt es hier nicht. „Bedienung prüfen"
  nennt seit 1.0.7 den gemessenen Punkt; **erst was dort steht, ist ein
  Befund.**
* **Ob sich die Seite jetzt überall aufziehen lässt, ist NICHT gemessen**
  (1.0.23). Gemessen ist, WARUM die Geste nicht ankam — der Inhalt war kleiner
  als das Sichtfeld; dass sie es jetzt tut, folgt aus der Geometrie und hat
  niemand gesehen. Der Weg zurück aus einer zu kleinen Seite hängt an keiner
  Geste: der Knopf mit der Prozentzahl unten links → „Einpassen".
* **Ob der Brennpunkt jetzt steht, ist NICHT gesehen** (1.0.26). Die URSACHE ist
  diesmal gemessen — an zwei Bildschirmfotos, in beide Richtungen, mit
  gerechneten und gemessenen Beträgen, die auf ein paar Punkte zusammenfallen.
  Dass die drei Beschwerden damit weg sind, folgt aus der Geometrie und hat
  niemand auf einem Gerät gesehen.
* **Die Erklärung von 1.0.25 war falsch und ist zurückgenommen** (Nachführung,
  `LazyVStack`-Deckel). Der Versatz wurde nie nachträglich verstellt. Gerechnet
  ist, warum er in 1.0.23 nicht stand — ohne Rollen wächst der Inhalt unter
  einem stehenden Versatz, und das ist der Sprung in die linke obere Ecke.
  **Neu ist, dass es sich messen lässt:** Die Zeile `Soll … Ist … Abweichung`
  in „Befund kopieren“ sagt, ob `scrollTo` den Anker einlöst. Erst was dort
  steht, ist ein Befund.
* **Warum sich die Arbeitsfläche nicht schieben lässt, ist NICHT geklärt**
  (1.0.24, zum zweiten Mal gemeldet). Gezählt wird es seither: `Gewandert seit
  dem Öffnen` nennt die Spanne, um die der Inhalt überhaupt je gerollt ist.
  Die Vermutung, dass die Zweifingergeste einen Zweifinger-Wisch verschluckt,
  ist absichtlich NICHT in derselben Fassung ausprobiert — es wird eine Sache
  auf einmal geändert.
* **Ob sich die Seite jetzt schieben lässt und der Zoom steht, ist NICHT
  gemessen** (1.0.18, fortgeschrieben 1.0.22). Abgezählt ist die Geometrie:
  dass ein Höchstmaß die Breite nicht wachsen lässt, und dass der asynchrone
  Block vor dem Durchgang liegen kann. Ungeprüft bleiben die zwei Annahmen von
  1.0.18 — dass `MagnifyGesture.Value.startLocation` im Raum des Inhalts
  gemeldet wird und dass `scrollTo` mit einem Anker außerhalb der Mitte tut,
  was die Dokumentation sagt. Beim Übergang von der Skalierung auf den
  gesetzten Maßstab kann ein Bild lang ein Sprung stehen bleiben. **Erst was
  in „Bedienung prüfen" steht, ist ein Befund** — vor allem `frei ⇄`.
* **Ob die neue Menüaufteilung intuitiver ist, ist NICHT gemessen** (1.0.20).
  Geändert sind Wege und Namen; ob sie den Befund „nicht selbsterklärend"
  auflösen, sagt erst der nächste. Dasselbe gilt für das Symbol auf einem
  Homescreen und für den Tipp auf die Karte.
* **Ob die Zeitzonen wirklich nachgeschlagen werden, ist NICHT gemessen**
  (1.0.19). Gerechnet ist die Umrechnung; ob `CLPlacemark.timeZone` für die
  Orte dieser Reise etwas hergibt, sagt erst die Zeile „Nachgeschlagen: n von
  m Tagen" im Einlesen-Blatt.
* **Die Schrifteinbettung ist halb gemessen.** Die App liest aus jeder
  benutzten Schrift, ob sie eingebettet werden DARF (`fsType` der
  OS/2-Tabelle) — das ist eine echte Messung. Ob CoreGraphics sie dann
  wirklich einbettet, steht damit noch nicht fest; das zeigt erst ein Blick
  in die fertige Datei mit einem Werkzeug wie Acrobat. Die drei
  Systemschnitte geben die Auskunft gar nicht heraus, und die Prüfung sagt
  das auch. Nicht als erledigt darstellen.
* **Das PDF ist noch nie gedruckt worden.** Boxen, Anschnitt und Auflösung
  sind gerechnet und in der Datei nachgemessen; ob ein Druckdienst die
  Datei ohne Rückfrage annimmt, weiß man nach dem ersten Auftrag.
* **Der Bau in GitHub Actions beweist nicht, dass sich signieren lässt.**
  Er läuft mit `CODE_SIGNING_ALLOWED=NO` gegen den Simulator; Entitlements
  werden dabei nie geprüft.
* **Seitenvorlagen mit Platzhaltern stehen noch aus.** Drei Fotos in einer
  randbündigen Reihe füllen eine A4-quer-Seite zu 40 % — höher kann die
  Reihe nicht werden, das ist Geometrie. Die Antwort darauf ist eine
  Vorlage (eines groß, zwei gestapelt), nicht eine weitere Stellschraube.
* **Warum die App einfror, ist NICHT gemessen.** Was 1.0.15 und 1.0.16
  entfernen, ist am Quelltext abgezählte Arbeit je Neuzeichnung und je
  Seitenwechsel; ob sie der Grund war, zeigt erst der Messfühler unter
  „Bedienung prüfen" auf einem echten Gerät. Die Erklärung von 1.0.15 hat
  der erste Befund bereits umgeworfen — 1.0.16 ist die zweite.
* **Der neue Umbruch ist nicht gesetzt worden.** Die Absatzgrenze, die
  62-Prozent-Schwelle und der freigehaltene Platz für die nächste Fotoreihe
  sind gerechnet; wie eine Doppelseite damit aussieht, zeigt erst ein Buch.
  Die beiden Zahlen sind gewählt und nicht gemessen.
* **Wie sich ein Buch mit zweihundert Fotos anfühlt, ist nicht gemessen.**
  Vorschaubilder sind gedeckelt und der Kartenvorrat begrenzt, aber beides
  ist eine Vorsichtsmaßnahme und keine Messung.
