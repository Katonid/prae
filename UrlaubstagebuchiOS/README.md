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
| **Umschlag getrennt** | Wahlweise zwei Dateien: Titelseite und Innenteil. |
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

## Aufbau

```
Urlaubstagebuch/
  Model/       Reise, Tag, Seite, Block, Schriftbild, Layoutautomat, Einrasten
  Dienste/     EXIF, Textimport, Bildarchiv, Ablage, Wolke, Spurbau,
               Spureinfuhr, Buchdatei, Kartenwerk, Kachelkarte,
               Seitensatz, Buchausgabe, Standortdienst
  Views/       Regal, Reise, Seitenfläche, Inspektor, Importe, Karte, PDF
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

* **Ob die Anfasser jetzt gehen, ist NICHT gemessen.** Es ist die vierte
  Erklärung in dieser Sache. Die ersten drei waren Vermutungen; diese hier
  ist am Quelltext gerechnet und erklärt, warum ausnahmslos jeder Griff als
  „Fläche" ankam — aber ein Gerät gibt es hier nicht. „Bedienung prüfen"
  nennt seit 1.0.7 den gemessenen Punkt; **erst was dort steht, ist ein
  Befund.**
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
* **Wie sich ein Buch mit zweihundert Fotos anfühlt, ist nicht gemessen.**
  Vorschaubilder sind gedeckelt und der Kartenvorrat begrenzt, aber beides
  ist eine Vorsichtsmaßnahme und keine Messung.
