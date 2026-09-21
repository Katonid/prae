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
  Dienste/     EXIF, Textimport, Bildarchiv, Ablage, Spurbau, Kartenwerk,
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
| Griffe nicht zu treffen | Sie ragten über den Blockrahmen hinaus — dort nimmt SwiftUI keinen Finger an | Eigene Ebene über der Seite, dazu ein Drehgriff |
| Text nur im Inspektor änderbar | — | Doppeltipp öffnet ein Textfeld an Ort und Stelle, in der Druckschrift |
| Datumszeile fest | — | Sieben Formate für das Buch, je Tag überschreibbar |
| Kein Seitenhintergrund | — | Einfarbig, Verlauf, Foto mit Schleier, Papierkorn — global und je Seite |

Dazu: Fotos lassen sich drehen (Griff über dem Block, rastet bei 45°),
überlappen (Ebene) und der Restplatz einer Seite wird zwischen den
Fotoreihen verteilt statt unten liegen gelassen.

## Offene Punkte

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
