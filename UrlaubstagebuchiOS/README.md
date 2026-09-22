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

* **Ob die Anfasser jetzt gehen, ist NICHT gemessen.** Es ist die vierte
  Erklärung in dieser Sache. Die ersten drei waren Vermutungen; diese hier
  ist am Quelltext gerechnet und erklärt, warum ausnahmslos jeder Griff als
  „Fläche" ankam — aber ein Gerät gibt es hier nicht. „Bedienung prüfen"
  nennt seit 1.0.7 den gemessenen Punkt; **erst was dort steht, ist ein
  Befund.**
* **Ob der Zoom den Brennpunkt wirklich hält, ist NICHT gemessen** (1.0.18).
  Gerechnet ist die Geometrie; ungeprüft sind die zwei Annahmen darunter —
  dass `MagnifyGesture.Value.startLocation` im Raum des Inhalts gemeldet wird
  und dass `scrollTo` mit einem Anker außerhalb der Mitte tut, was die
  Dokumentation sagt. Beim Übergang von der Skalierung auf den gesetzten
  Maßstab kann ein Bild lang ein Sprung stehen bleiben.
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
