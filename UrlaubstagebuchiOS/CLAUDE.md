# Projekt Urlaubstagebuch (Reisebuch aus Fotos und Text, native iOS-App)

> Ausgelagert aus der `CLAUDE.md` im Wurzelverzeichnis (09/2026). Die
> übergreifenden Regeln (PR-Rhythmus, iOS-Pflichten, Bau in GitHub
> Actions) stehen weiterhin dort und gelten hier genauso.


- App-Code: `UrlaubstagebuchiOS/` (ein Target: App, iPhone + iPad, iOS 17,
  keine fremden Abhängigkeiten). Aus Fotos und einem Tagebuchtext entsteht
  ein gesetztes Buch: je Tag Seiten mit Text, Bildern und einer Karte der
  Tagesstrecke, als PDF ausgebbar. Ausführlich:
  `UrlaubstagebuchiOS/README.md`.
- **Homescreen-Name „Reisebuch"**, Ordner/Ziel/Bundle-Id bleiben
  „Urlaubstagebuch" / `de.familie.urlaubstagebuch` — nach dem ersten
  Signieren nicht mehr ändern.
- **Der Tag kommt aus DREI ZAHLEN, nie aus einer Umrechnung**
  (`Model/Tagesdatum.swift`). Ein EXIF-Aufnahmedatum hat KEINE Zeitzone:
  „2026:08:12 19:33:21" ist die Uhr am Ort der Aufnahme. Wer daraus ein
  `Date` macht, muss eine Zone annehmen, und jede Annahme ist irgendwo
  falsch — ein Foto vom 12. August, 23:40 Ortszeit in Bangkok wäre in
  Deutschland der 13. und rutschte in den falschen Tagebucheintrag, ohne
  dass etwas auffiele; die Uhrzeit stimmt ja. Der Tagesschlüssel wird
  deshalb unmittelbar aus den ZIFFERN gebaut (EXIF-Zeichenkette,
  Datumszeile im Text). Das `Date` daneben sortiert nur INNERHALB eines
  Tages, trägt eine feste Zone und ist kein Augenblick auf der Weltuhr.
  **Die einzige Stelle, an der ein Tag doch aus einer Umrechnung entsteht,
  ist der Zeitpunkt aus der Fotomediathek** — die gibt nichts anderes her,
  und das steht so im Quelltext.
- **Ohne Mediathekserlaubnis gibt iOS keine Aufnahmeorte heraus.** Das ist
  die Falle, an der ein Reisetagebuch ohne Vorwarnung scheitert: Der
  Fotowähler braucht KEINE Berechtigung, und genau deshalb hält man ihn für
  den ganzen Weg. Hat die App keinen Zugriff auf die Mediathek, entfernt
  iOS die Standortdaten aus den herausgegebenen Bilddaten — die Fotos
  kommen an, die Karte bleibt leer, und es sieht aus, als könne die App
  kein EXIF lesen. Deshalb ist der Fotowähler der von UIKit
  (`Views/Waehler.swift`): Nur ein `PHPickerViewController` mit
  `PHPickerConfiguration(photoLibrary: .shared())` gibt den
  `assetIdentifier` heraus, über den sich der Ort am Mediathekseintrag
  nachschlagen lässt. SwiftUIs `PhotosPicker` kann das nicht, sein
  `itemIdentifier` bleibt leer. **Nicht auf `PhotosPicker` zurückbauen.**
- **Geladen werden DATEN, nie ein `UIImage`.** Ein Bild ist schon entpackt
  — seine Metadaten sind dann weg, und damit Datum und Ort. Daran
  scheitern die meisten Versuche, EXIF aus einem Fotowähler zu bekommen.
  Der Weg über **Dateien** ist von alldem nicht betroffen: Dort kommt die
  Datei unangetastet an. Er ist der verlässlichere und deshalb kein
  Notbehelf.
- **Wer die Erlaubnis verweigert, wird nicht ausgesperrt** (dieselbe Lehre
  wie Schulalarm 1.1.0/Build 43). Alles außer dem automatischen
  Aufnahmeort läuft weiter, die Punkte lassen sich von Hand setzen, und
  die App sagt in einem Satz, was fehlt und warum.
- **Breite und Höhe stehen so in der Datei, wie der Sensor sie gelesen
  hat.** Ein hochkant gehaltenes Telefon liefert 4032 × 3024 plus eine
  Orientierung (5 bis 8 = gedreht). Ohne das Tauschen wäre jedes
  Hochformat im Layout ein Querformat, und die Fotoreihen gingen nicht
  auf. Beim Vorschaubild macht das
  `kCGImageSourceCreateThumbnailWithTransform` — ohne diese Zeile liegt
  jedes Hochformat quer, und zwar NUR in der Vorschau.
- **Der GPS-Betrag ist immer positiv**; ob Süd oder West, steht in einem
  eigenen Feld. Wer es überliest, verlegt jede Reise auf die Nordhalbkugel
  und nach Osten.
- **Seite und PDF zeichnet DERSELBE Setzer** (`Dienste/Seitensatz.swift`,
  CoreText). Eine Buchseite wird zweimal gezeichnet — auf dem Bildschirm,
  damit man sie anfassen kann, und ins PDF, damit man sie drucken kann.
  Zwei Zeichenwege bedeuten früher oder später zwei Ergebnisse, und der
  Unterschied fällt auf, wenn das Buch beim Drucker liegt. Die Ansicht
  hängt eine UIView davor (`Views/Textkasten.swift`), die nichts weiter
  tut, als diese Funktionen aufzurufen. **Wer eine neue Blockart baut,
  zeichnet sie dort und nicht zweimal.**
- **Ein `Text` aus SwiftUI taugt hier nicht:** kein Blocksatz, keine feste
  Zeilenhöhe, keine Silbentrennung, eigener Umbruch. Und `draw(with:)` aus
  UIKit setzt über TextKit, also über einen ANDEREN Umbruch als den, mit
  dem `Textmass` (CoreText) gerechnet hat — ein Text, der beim Messen
  sechs Zeilen hatte und beim Zeichnen sieben, läuft unten aus seinem
  Block.
- **Gemessen wird der Umbruch, nicht geschätzt** (`Model/Textmass.swift`).
  Eine Schätzung aus Zeichenzahl mal Schriftgröße ist bei einer
  Proportionalschrift regelmäßig um ein Drittel daneben.
- **Silbentrennung ist hier ERLAUBT**, anders als in Textauszug und
  Wörterwerkstatt. Getrennt wird nicht von uns, sondern von Apples
  deutschem Wörterbuch (`hyphenationFactor` mit `languageIdentifier`).
  Eine selbst gebaute Trennung bleibt verboten: Die deutsche ist nicht
  ableitbar, und eine falsche stünde für immer im gedruckten Buch.
- **Wo das Bild im Rahmen liegt, rechnet EINE Funktion**
  (`Bildausschnitt.zielrechteck`), benutzt von der Ansicht und vom PDF.
  Grundlage ist FÜLLEN, nicht Einpassen; was überragt, wird beschnitten.
  Rahmen und Ausschnitt sind zwei Dinge: Der Rahmen ist der Platz auf der
  Seite, der Ausschnitt der sichtbare Teil des Bildes. Beides muss gehen.
- **Gerechnet wird in SEITENPUNKTEN, nicht in Bildschirmpunkten.** Der
  Maßstab liegt als eine einzige Skalierung über der Seite, und jede Geste
  wird durch ihn geteilt, bevor sie ins Modell geht. Ohne diese Division
  wanderte ein Block auf einer klein gezoomten Seite dreimal so weit wie
  der Finger — und ein Buch, das auf dem iPhone gestaltet wurde, sähe auf
  dem iPad anders aus.
- **Die Karte auf der Seite ist ein BILD** (`MKMapSnapshotter`,
  `Dienste/Kartenwerk.swift`), mit drei Wirkungen auf einmal: Das PDF
  sieht aus wie die Ansicht; die Karte schluckt keine Geste, die den Block
  bewegen wollte (Lehre aus Abfahrtstafel 1.1.18, deshalb
  `.allowsHitTesting(false)`); und ohne Netz bleibt das Bild stehen. Der
  Punkt wird dagegen auf einer ECHTEN Karte gewählt, in einem eigenen
  Bildschirm, über ein festes Fadenkreuz — ein Tippen wäre naheliegend und
  schlechter, der Finger verdeckt genau die Stelle, die er trifft.
- **Gezeichnet wird die Verbindung der Punkte, nicht der gefahrene Weg**,
  und das steht unter der Karte. Welche Straße es war, steht in keinem
  Foto. Dieselbe Ehrlichkeit wie bei der gestrichelten Luftlinie in der
  Abfahrtstafel.
- **Die Spur wird AUSGEDÜNNT und dabei gezählt** (`Dienste/Spurbau.swift`,
  Vorgabe 150 m). Wer an einem Tag zweihundert Fotos macht, macht
  hundertachtzig davon an fünf Orten; ungefiltert wäre die Spur ein Knäuel.
  Zusammengefasst wird nach ENTFERNUNG und nicht nach Zeit: eine Stunde im
  Museum ist ein Punkt, eine Stunde im Zug sind viele. Was
  zusammengefasst wurde, zählt `zusammengefasst` mit — stillschweigend
  wegzulassen wäre eine Lücke, die niemand bemerkt.
- **Ein Handpunkt OHNE Uhrzeit kommt ans Ende und wird nicht einsortiert.**
  Wohin er in der Tagesfolge gehört, weiß niemand — auch die App nicht.
  Eine Reihenfolge, die sie sich ausdenkt, sähe aus wie eine, die aus den
  Daten kommt. Verschieben geht in der Punktliste, und das steht dabei.
- **Der Textimport behauptet nichts, er ZEIGT** (`Dienste/Textimport.swift`,
  `Views/TextimportView.swift`). Die Regel hat zwei Hälften, beide an 18
  echten Sätzen gemessen (sechs davon dürfen NICHT treffen): Vor dem Datum
  darf nur Beiwerk stehen (Wochentag, „am", „Tag 5", Satzzeichen); nach dem
  Datum steht die Überschrift, höchstens 60 Zeichen und **groß
  anfangend**. Damit fallen „Heute, am 12.08., war es heiß." und „Am 12.08.
  begann alles mit einem verspäteten Flug" heraus, und „12.08.2026 –
  Ankunft in Lissabon" ergibt Datum und Überschrift auf einmal.
- **Vorn wird NUR ein Wochentag oder eine Zahl abgeschnitten, nie ein
  Artikel** (gefunden beim Messen). Ein früherer Entwurf strich „der" und
  „den" überall, und aus „Der Weg nach oben" wurde „Weg nach oben" — ein
  Artikel steht am Anfang jeder zweiten Überschrift.
- **Ein Monatsname muss ein echter sein.** Ohne diese Prüfung würde aus
  „3. Tag in Porto" ein Datum, und der Monat wäre geraten.
- **Fehlt die Jahreszahl, gilt die des vorigen Tages** — rutscht das Datum
  dabei in die Vergangenheit, ist es der Jahreswechsel. Eine Reise über
  Silvester ist nichts Besonderes, ein Tagebuch, das dabei elf Monate
  zurückspringt, schon.
- **Was von Hand geändert wurde, bleibt.** Jeder angefasste Block trägt
  `vonHand` und wird vom Neuanordnen in Ruhe gelassen; vor dem
  Überschreiben eines bearbeiteten Tages fragt die App ausdrücklich nach,
  und die Tagesliste zeigt an jedem solchen Tag ein Zeichen. Eine
  Automatik, die eine Stunde Handarbeit ohne Rückfrage überschreibt,
  benutzt man genau einmal. Dazu ein flacher Rückgängig-Stapel (25 Stände)
  — ohne ihn traut sich niemand, etwas auszuprobieren.
- **Gemerkt wird beim ANFANG einer Geste, nicht bei jedem Bildpunkt.** Bei
  sechzig Zwischenständen je Fingerbewegung wäre der Stapel nach einer
  Geste voll und der Zustand davor unerreichbar.
- **Örtlich heißt ABWEICHUNG, nicht Kopie** (`Schriftabweichung`). Alle
  Felder sind freiwillig; was `nil` ist, folgt weiter der globalen
  Einstellung. Würde eine örtliche Änderung stillschweigend alle Werte
  kopieren, wäre jede spätere Änderung am Buchganzen an allen schon einmal
  angefassten Stellen wirkungslos — genau das, was man beim Umstellen
  einer Schrift nicht will.
- **Nur Schriftfamilien anbieten, die das Gerät wirklich hat**
  (`Schriftfamilie.alleDesGeraets`, geprüft mit `.vorhanden`). Eine, die dann doch die Systemschrift
  zeichnet, wäre eine Auskunft, die nicht stimmt. Mitgeliefert wird keine:
  Ein Buch wird weitergegeben, und dafür bräuchte jede Schrift eine Lizenz.
- **Ein Modus, den man nicht sieht, darf die Bedeutung einer Geste nicht
  ändern.** Im Ausschnittsmodus verschiebt das Ziehen das Bild IM Rahmen
  statt den Rahmen auf der Seite — und ein Band über der Seite sagt das.
  Dieselbe Regel wie beim Fußwegmesser der Abfahrtstafel.
- **Nichts geht stillschweigend verloren:** Fotos ohne Datum landen in der
  Ablage und werden gezählt, Fotos ohne Ort werden gezählt, ein Wisch
  nimmt ein Foto vom Tag und nicht von der Platte, eine unlesbare Reise
  wird in der Übersicht gezählt, und der Einfuhrbericht sagt in einem Satz,
  was ankam.
- **Gesichert wird über eine temporäre Datei, die getauscht wird.** Eine
  halb geschriebene Reise wäre der Verlust eines ganzen Buches — und die
  Wahrscheinlichkeit dafür ist am höchsten, wenn viel darin steht.
- **Kein `@AppStorage` in `Reisewerk`** — dieselbe Falle wie in der
  Abfahrtstafel: Der Wrapper ist eine `DynamicProperty`, schreibt zwar in
  die Voreinstellungen, löst aber kein `objectWillChange` aus.
- **Der Layoutautomat rechnet in `CGFloat`, wo ein `CGRect` im Spiel ist**
  (getroffen beim ersten Bau): Bei einer TUPEL-Zuweisung rechnet Swift
  `Double` und `CGFloat` NICHT ineinander um, obwohl beide auf diesen
  Geräten dasselbe sind. Bei gewöhnlichen Zuweisungen und Argumenten tut
  er es — der Fehler zeigt sich also nur an dieser einen Stelle.
  **Zum zweiten Mal getroffen in 1.0.37** (`PunktwahlView.punktBei`):
  `hypot` über zwei `CGFloat` gibt `CGFloat` zurück, und das Tupel war als
  `(punkt: Reisepunkt, abstand: Double)` deklariert. Der Bau hat es
  gemeldet, nicht die Quelltextprüfung — die sieht String-Literale an.
  **Merke: Überall, wo ein Wert aus einem `CGPoint`, `CGRect` oder
  `CGSize` in ein Tupel, einen Rückgabetyp oder eine Eigenschaft vom Typ
  `Double` geht, gehört ein `Double(…)` darum.**
- **Das Ergebnis ist eine DRUCKVORLAGE, kein Bildschirmdokument** (ab
  1.0.1). Gemessen an dem, was deutsche Druckdienste verlangen (BoD,
  epubli, Saal Digital, 09/2026): PDF, Endformat exakt aus Millimetern,
  3 mm Anschnitt (BoD 5), 300 dpi, Schriften eingebettet, **RGB** — und
  damit ausdrücklich NICHT CMYK: Fotobuchdienste verlangen RGB und wandeln
  selbst um. Wer bei einer Offsetdruckerei mit ISO Coated v2 bestellt,
  braucht eine umgewandelte Datei; iOS kann kein CMYK-PDF schreiben. **Das
  nicht als lösbar versprechen.**
- **Kein Word oder Pages als Zwischenstufe** (Frage des Nutzers, 09/2026).
  Eine Textverarbeitung kennt keinen Anschnitt, bricht Bilder um, wenn sich
  eine Zeile ändert, und setzt auf jedem Rechner leicht anders. Genau das,
  worauf es bei einer Druckvorlage ankommt, ist dort nicht zu haben.
- **Das PDF entsteht über einen `CGContext`, nicht über
  `UIGraphicsPDFRenderer`** (ab 1.0.1). Der Unterschied ist genau eine
  Sache, und die entscheidet beim Druckdienst: Nur so lassen sich **TrimBox
  und BleedBox** setzen. Daran erkennt die Druckerei, wo das Endformat
  aufhört; ohne sie nimmt sie den Bogen für das Endformat und schneidet den
  Anschnitt ins Bild. Die Boxen werden als rohe `CGRect`-Bytes übergeben —
  ein `NSValue` nimmt CoreGraphics dort nicht an.
- **Der Anschnitt ist NEGATIVER Raum.** Alle Blockkoordinaten liegen im
  Endformat, dessen linke obere Ecke bei (0,0) sitzt; ein randabfallender
  Block beginnt bei `-anschnitt`. Beim Zeichnen wird der Kontext einmal um
  den Anschnitt verschoben. Das hält jede Zahl im Modell bei dem Wert, der
  auf dem Lineal steht — die Alternative (Ursprung in der Bogenecke) hätte
  jeden Rand um drei Millimeter verschoben.
- **Gerechnet wird in MILLIMETERN, gesetzt in Punkten** (`Druckmass`). Ein
  Buch wird in Millimetern bestellt; niemand kann einschätzen, ob 184
  Punkte viel sind. Die Umrechnung steht an einer Stelle und nicht als
  gerundete 2,83 verstreut — bei A4 liegt man damit schon um einen halben
  Millimeter daneben.
- **Der Bundsteg wird auf BEIDE Seitenränder gerechnet**, nicht nur auf den
  inneren. Welche Seite innen liegt, hängt an der laufenden Seitenzahl, und
  die verschiebt sich, sobald ein Tag eine Seite mehr braucht. Ein Bundsteg
  auf der falschen Seite fällt erst im gebundenen Buch auf; ein paar
  Millimeter Verschwendung sind der billigere Fehler.
- **Die Druckprüfung misst, sie behauptet nicht** (`Dienste/Druckpruefung.swift`,
  dieselbe Bauweise wie „Zustellung prüfen" bei Schulalarm). Vorab: dpi je
  Fotoblock samt Seitenzahl des schwächsten, Anschnitt, randabfallende
  Blöcke, Transparenz, Schrifteinbettung. Danach an der fertigen Datei:
  Seitenzahl, MediaBox und TrimBox, gelesen aus dem PDF und nicht aus dem
  Modell, das es geschrieben hat. Ein Buch geht einmal in den Druck und
  kommt eine Woche später als Stapel Papier zurück.
- **Ob eine Schrift eingebettet werden DARF, steht in ihr selbst** — im
  Feld `fsType` der OS/2-Tabelle. Eine Schrift mit „Restricted License
  Embedding" landet nicht im PDF, und die Druckerei ersetzt sie
  stillschweigend. Gelesen wird die Tabelle über `CTFontCopyTable`; gibt
  eine Schrift sie nicht heraus (die drei Systemschnitte tun das), sagt die
  Prüfung genau das und rät nicht. **Ob CoreGraphics die erlaubte Schrift
  dann wirklich einbettet, ist damit NICHT gemessen** — das zeigt erst ein
  Blick in die fertige Datei.
- **Die dpi-Rechnung nimmt den ZOOM des Ausschnitts mit.** Wer in ein Bild
  hineinzoomt, benutzt weniger Pixel für dieselbe Fläche; ohne diesen
  Faktor meldete die Prüfung 300 dpi für ein Bild, das mit 120 gedruckt
  wird.
- **Ein Stil setzt alles auf einmal** (`Model/Buchstil.swift`, fünf Stück).
  Schrift, Farbe, Ränder, Fugen, Schatten und die Vorliebe für bestimmte
  Seitenmuster ziehen gegeneinander: Eine schmale Didot mit engen Fugen und
  randabfallenden Bildern ergibt ein Magazin, eine runde Groteske mit
  breiten Rändern und Sofortbild-Rahmen ein Album — jede Mischung daraus
  sieht aus wie ein Versehen. Der Stil ist ein Anfang und keine Schranke;
  danach lässt sich jede Einzelheit weiter ändern.
- **Die Akzentfarbe gehört der REISE, nicht dem Stil.** Wer sie ändert,
  will sie behalten; wer den Stil wechselt, will dessen Farbe. Der Stil
  trägt sie deshalb nur als Vorschlag. Und es gibt sie **nur einmal** — ein
  zweites Feld „Linienfarbe" für die Karte gab es in 1.0.0 und lief
  unweigerlich auseinander.
- **Der Drehwinkel im Album-Muster kommt aus der KENNUNG des Fotos**, nicht
  aus dem Zufall. Ein Satz, der sich bei jedem Neuanordnen anders neigt,
  ist kein Satz, sondern ein Würfel. Die Grenze von gut vier Grad ist der
  Unterschied zwischen „mit der Hand eingeklebt" und „schief".
- **Die Schnittkante liegt ÜBER allem** (`SeitenflaecheView`). Sie ist die
  Linie, an der beschnitten wird; unter den randabfallenden Bildern
  gezeichnet wäre sie genau dort versteckt, wo man sie braucht.
- **Weiße Schrift auf einem Foto braucht einen Verlauf darunter**
  (`Blockinhalt.verlauf`). Sie ist genau so lange lesbar, bis jemand ein
  Bild mit hellem Himmel wählt — und dann verschwindet die Überschrift des
  Tages. Beim Ausgeben ohne Transparenz wird der Verlauf zu einem
  geschlossenen Feld: weniger elegant, aber lesbar, und das ist hier das
  Wichtigere.
- **Seitenzahl und Kopfzeile sind KEINE Blöcke.** Sie gehören zum Buch und
  nicht zum Tag; als Blöcke im Satz verschöbe sie irgendwann jemand. Sie
  werden beim Zeichnen jeder Seite ergänzt, und eine ganzseitig bebilderte
  Seite bekommt keine (`Seite.ohneSeitenzahl`) — die Zahl stünde auf dem
  Foto und sähe aus wie ein Versehen.
- **Eine berechnete Eigenschaft sieht billig aus** (dieselbe Falle wie bei
  der Netzkarte der Abfahrtstafel, hier zweimal getroffen): Die
  Druckprüfung läuft über alle Seiten und alle Fotos, die Datumserkennung
  über jede Zeile des Textes. Beide standen zuerst als berechnete
  Eigenschaft in einer `Form` und liefen damit bei JEDEM Neuzeichnen. Jetzt
  hängen sie an `.task` und `.onChange`.
## Was der erste gedruckte Stand zeigte (1.0.2)

Der Nutzer hat 1.0.1 als PDF ausgegeben und die Seiten geschickt. Sechs
Befunde, und keiner davon war Geschmack:

- **Jede Zeile stand als eigener Absatz** (`Dienste/Textaufbereitung.swift`).
  Der eingelesene Text war bei rund hundert Zeichen hart umbrochen und die
  Zeilen zusätzlich durch LEERZEILEN getrennt; der Setzer machte daraus
  getreulich sechs Absätze mit Absatzabstand, und ein Satz lief über zwei
  davon („… Nissan Kicks gegen Jeep" / „Grand Cherokee. Leider …").
  **Erkannt wird das an der LÄNGE der Zeilen, nicht an den Leerzeilen:**
  Hart umbrochener Text hat eine enge Verteilung — viele Zeilen enden dicht
  unter derselben Grenze. Gemessen an den Texten des Nutzers (50 % und 60 %
  lange Zeilen) gegen frei geschriebenen Text (33 %); die Schwelle liegt bei
  35 %, und wo sie nicht greift, bleibt der Text unangetastet. Eine Zeile
  setzt den Absatz fort, wenn die vorige bis an die Grenze reichte UND nicht
  mit einem Satzzeichen endete (oder die nächste klein anfängt).
- **Text ging beim Seitenumbruch verloren.** Auf Seite 5 endete ein Tag
  mitten im Satz („mussten von Passagieren, die"), der Rest war weg:
  `if kopf.isEmpty { text = "" }` — der „Notausgang" gegen eine
  Endlosschleife warf den Rest fort. Jetzt wird eine neue Seite begonnen,
  und passt der Text selbst auf einer leeren Seite nicht (zu große Schrift),
  läuft er SICHTBAR über. **Ein Tagebuch darf keinen Satz verlieren** — ein
  überlaufender Block fällt auf, ein fehlender Satz nicht.
- **Die Griffe waren da und nicht zu treffen** (`Views/Griffe.swift`).
  Gemeldet als „Ich kann ein Textfeld nicht in der Größe skalieren." Sie
  hingen als `.overlay` IM Block und ragten mit ihrer halben Breite über
  dessen Rahmen hinaus — **was außerhalb eines Frames liegt, nimmt in
  SwiftUI keinen Finger an**, und das nachgestellte
  `.contentShape(Rectangle())` beschnitt den Rest. Daraufhin lagen sie als
  eigene Ebene über der Seite. **Merke: Ein Bedienelement, das über seinen
  Elternrahmen hinausragt, gehört eine Ebene höher.** Der Satz gilt
  weiterhin — die DIAGNOSE war trotzdem nicht die Ursache, siehe der
  nächste Punkt.
- **Dieselbe Meldung ein zweites Mal — und die Erklärung von 1.0.2 war
  widerlegt** (ab 1.0.5, gemeldet 09/2026: „Leider kann ich die Bilder immer
  noch nicht verschieben oder skalieren. Und den Text kann ich zwar
  bearbeiten und drehen, aber die Anfasser an den Seiten lassen auch hier
  keine Änderung des Textfensters zu."). **Widerlegt durch die Meldung
  selbst:** Der DREHGRIFF liegt als einziger ganz außerhalb des
  Blockrahmens — und er ist der, der geht. Läge es am Hinausragen, wäre es
  genau andersherum. Eine Erklärung, die einmal geholfen hat, ist damit noch
  keine Ursache; das gehört gesagt, statt eine dritte Vermutung
  danebenzustellen (dieselbe Lehre wie beim Zoomen der Abfahrtstafel, wo
  zweimal eine Vermutung als Diagnose ausgegeben wurde).
- **Messen ging nicht, also wurden ALLE Verdächtigen auf einmal
  ausgeräumt** (ab 1.0.5). Es lagen mehrere übereinander, und keiner ließ
  sich ohne Gerät von den anderen trennen: der `Textkasten` (eine
  UIKit-Ansicht mitten im Block — die nimmt sich den Finger und gibt ihn
  nicht weiter), die Foto- und Kartenkachel, zwei Tipp-Gesten neben einer
  Ziehgeste an derselben Ansicht, und neun Griffe mit je eigener Geste, die
  einander überlappen. Jetzt gilt:
  - **Was in einem Block liegt, ist ein BILD** (`allowsHitTesting(false)`,
    am Textkasten zusätzlich `isUserInteractionEnabled = false`). Dieselbe
    Lehre wie bei der Netzkarte der Abfahrtstafel.
  - **Ein Block hat GENAU EINE Geste.** Sie entscheidet an der Stelle, an
    der der Finger aufsetzt, EINMAL, was gemeint war — sonst wechselte die
    Bedeutung mitten im Ziehen, sobald der Finger über einen anderen Griff
    wandert.
  - **Wo ein Griff liegt, steht an EINER Stelle** (`Grifflage.punkte`) und
    wird von Zeichnung UND Treffprüfung gelesen. Zwei Fassungen liefen
    auseinander, und dann läge der sichtbare Griff woanders als der
    wirksame — genau der Fehler, um den es hier geht.
  - **Die Trefferfläche ist ein eigener, größerer Rahmen und kein negativer
    Saum.** `padding(-saum)` liefe der Lehre von 1.0.2 genau entgegen.
  - **Eine Geste wird NICHT durch den Maßstab geteilt.** Sie wird in den
    eigenen Koordinaten der Ansicht gemeldet, an der sie hängt, und die
    liegen innerhalb des `scaleEffect` — also schon in Seitenpunkten. Bis
    1.0.4 wurde zusätzlich geteilt. Das ist die Lesart der Dokumentation und
    **keine Messung**; deshalb nennt die Probe Strecke und Maßstab.
- **Der Befund, der die Sache erklärt: auch das AUSWÄHLEN geht nicht**
  (gemeldet 09/2026, noch im selben Durchgang: „Es scheint wohl ein größeres
  Problem zu sein, denn ich habe mitunter auch Schwierigkeiten, Textblöcke
  auswählen zu können."). Damit ist es nicht die Geste, sondern schon der
  TIPP. Zwei Gründe, beide am Quelltext nachzurechnen:
  - **Ein Textblock ist FLACH.** Eine Datumszeile misst rund 14
    Seitenpunkte; eine A4-Seite wird auf einem iPhone mit gut halbem Maßstab
    gezeigt, also sieben Bildschirmpunkte. Apple nennt 44 als Mindestmaß für
    ein Fingerziel. **Eine Trefferfläche in Größe des Gezeichneten ist bei
    Text grundsätzlich zu klein** — unabhängig von jeder Gestenfrage, und
    das trifft die Textblöcke und sonst kaum etwas.
  - Die Gesten lagen übereinander (Punkt darüber).
- **Also: Ein Block ist eine ZEICHNUNG, die SEITE nimmt den Finger
  entgegen** (ab 1.0.5) — dieselbe Trennung wie bei der Netzkarte der
  Abfahrtstafel. Die Seite sucht HINTERHER, was gemeint war: erst genau,
  dann im Umkreis einer knappen Fingerbreite (`fangweite`, 20 Punkte),
  jeweils von oben nach unten, damit bei zwei übereinanderliegenden Blöcken
  der gewinnt, den man sieht. Damit kostet die Fangweite keine Fläche.
- **Die Ziehgeste liegt NUR über dem gewählten Block** samt Griffsaum, und
  das ist kein Detail: Die Seite steckt in einem `ScrollView`, und eine
  Ziehgeste über der ganzen Fläche nähme ihm das Blättern. Ein Tipp tut das
  nicht — deshalb **erst antippen, dann anfassen**; wo keine Auswahl ist,
  scrollt die Seite wie zuvor. **Die Tipps hängen mit auf dieser Fläche**,
  sonst käme über dem gewählten Block keiner mehr an (kein Abwählen, kein
  Doppeltipp für den Text). **Wer eine Geste über eine ganze Fläche legt,
  prüft, was diese Fläche sonst noch tut.**
- **Und weil sich das hier nicht messen lässt, misst es die App**
  (`Reisewerk.letzterGriff`, Buch → Satz → „Bedienung prüfen", ab 1.0.5).
  Eine Zeile über der Seite sagt nach jeder Ziehbewegung, was angekommen
  ist: welcher Griff, an welcher Blockart, wie weit in Millimetern, bei
  welchem Maßstab — und nach jedem Tipp, ob er einen Block getroffen hat
  oder ins Leere ging. Dasselbe Muster wie Schulalarms Stufenprobe und der
  Kartenmesser der Abfahrtstafel. **Nicht als erledigt darstellen**, bevor
  diese Zeile es sagt.
- **Verschieben ging, Größe ändern nicht — und der Unterschied IST die
  Erklärung** (ab 1.0.6, gemeldet 09/2026: „Bei Fotos und Textfeldern wird nun
  ein Verschieben zugelassen. Die Anpasser bewirken aber leider noch keine
  Größen- oder Formatänderung."). Verschoben wird erst am ENDE der Geste — bis
  dahin bewegt sich nur ein Versatz beim Zeichnen, der Rahmen bleibt. Die
  GRÖSSE ändert sich bei jedem Bildpunkt. Und an diesem Rahmen hing seit 1.0.5
  die Ziehfläche: Sie wuchs unter dem eigenen Finger mit, ihre lokalen
  Koordinaten wanderten mit, die gemeldete Strecke bezog sich auf einen
  anderen Ursprung als eben noch — und die Geste brach ab. Das Drehen war
  nicht betroffen, weil die Fläche nicht am Winkel hängt; auch das passt zum
  Befund. **Merke: Eine Fläche, die eine Geste TRÄGT, darf sich während dieser
  Geste nicht bewegen** — sie steht jetzt still (`ausgangsrahmen`), solange
  gezogen wird. Dazu erkennt die Geste am AUFSETZPUNKT, ob sie neu ist: Nach
  einem Abbruch bliebe sonst der alte Griff stehen, und die nächste Bewegung
  täte etwas, das niemand angefasst hat.
- **Die Erklärung von 1.0.6 war die fünfte und wieder daneben** (ab 1.0.7,
  gemeldet 09/2026: „Jetzt geht nicht mal mehr drehen. Die Anfasser sind zu
  sehen, aber egal, ob ich auf einen Anfasser tippe und halte oder auf das
  Foto selbst oder den Text, es wird immer nur verschoben."). Das ist der
  Befund, der sich RECHNEN lässt, statt ihn zu deuten: Die Geste kommt an
  (es wird ja verschoben), nur liefert `Grifflage.getroffen` nie einen Griff
  — also ist der PUNKT falsch, den sie bekommt, und nichts sonst. Und es galt
  auch schon in 1.0.5; dass das Drehen „jetzt auch nicht mehr" geht, heißt,
  dass es seit dem Umbau nie ging und erst jetzt ausprobiert wurde.
- **Eine Geste meldet ihren Punkt im Raum DERJENIGEN Ansicht, an der sie
  hängt** — und das war hier die Ziehfläche des gewählten Blocks: verschoben
  (`offset`), um einen Saum vergrößert, und seit 1.0.6 zusätzlich eine, die
  ihre Größe während des Ziehens ändert. Der Quelltext rechnete den
  gemeldeten Punkt deshalb auf die Seite um (`aufSeite`). Liegt der Ursprung
  dieses Raumes aber VOR dem Versatz, ist der Punkt schon ein Seitenpunkt und
  die Umrechnung addiert den Blockursprung ein zweites Mal — der Griffpunkt
  landet dann um den halben Block daneben, `getroffen` gibt `nil` zurück und
  `?? .verschieben` macht daraus stillschweigend ein Verschieben. Genau das
  Bild, das gemeldet wurde.
- **Welche der beiden Lesarten stimmt, lässt sich hier nicht messen — also
  wird die Frage abgeschafft.** Gemessen wird seit 1.0.7 in einem BENANNTEN
  Raum (`Seitenraum.name`, deklariert an der Seite selbst), und `DragGesture`
  wie Tipp bekommen ihn mit: `coordinateSpace: .named(…)`. Damit ist der
  Aufsetzpunkt dieselbe Zahl wie bei einem Tipp auf die Seite, unabhängig
  davon, an welcher Ansicht die Geste hängt und wie die verschoben ist.
  `aufSeite` ist ersatzlos gestrichen. **Merke: Wer einen Punkt aus einer
  Geste braucht, nennt den Raum, in dem er gilt — „lokal" ist eine Auskunft
  über den Ansichtsbaum und keine über die Seite.** Die Tipps an der Seite
  selbst bleiben bei `.local`: Diese Ansicht ist nicht verschoben, und das
  Auswählen über sie hat nachweislich funktioniert — es wird eine Sache auf
  einmal geändert.
- **Die Greifweite darf einen kleinen Block nicht ganz ausfüllen** (ab
  1.0.7, beim Nachrechnen gefunden). Sie war fest eine Fingerkuppe (24
  Bildschirmpunkte); bei einem Block von 60 x 40 Seitenpunkten liegt damit
  JEDER Punkt im Umkreis einer Ecke — er ließe sich nur noch in der Größe
  ziehen und nie mehr verschieben. Gedeckelt auf gut ein Drittel der
  kürzeren Seite, mit einem Boden, unter den es nicht geht. Bei einer
  flachen Datumszeile fallen obere und untere Kante trotzdem zusammen; dort
  gewinnt die Ecke, und die zieht beide Maße — bei vierzehn Punkten Höhe
  gibt es keine vier unterscheidbaren Kanten, und das ist Geometrie und
  keine Einstellung.
- **Die Probe nennt jetzt ZAHLEN** (`letzterGriff`, Buch → Satz → „Bedienung
  prüfen"): wo der Finger IM Block aufgesetzt hat, wie groß der Block ist,
  wie weit ein Griff greift. Bis 1.0.6 stand dort nur der gedeutete Name des
  Griffs — und der lautete in jedem Fall „Fläche", also genau das, was die
  Frage offenließ. **Eine Probe, die nur ihr Ergebnis nennt, ist die Frage
  von vorhin noch einmal.**
- **Was der Finger bewegt, wird SOFORT ins Modell geschrieben** (ab 1.0.8,
  gemeldet 09/2026: „Beim Verschieben bleibt grundsätzlich die Erfahrung
  bestehen. Warum wandert der nicht einfach mit?"). Bis 1.0.7 bewegte das
  Verschieben nur einen Versatz beim ZEICHNEN (`schiebt`/`zieht`); der Rahmen
  im Modell blieb stehen und wurde erst am Ende der Geste gesetzt. Drei
  Folgen, und alle drei waren zu sehen: Der Block lief dem Finger nach, die
  GRIFFE blieben zurück (die lesen den Rahmen), und brach die Geste ab, ohne
  dass `onEnded` kam, stand das Bild für immer neben seinem eigenen Rahmen —
  genau das zeigte das Bildschirmfoto des Nutzers. Die GRÖSSENÄNDERUNG machte
  es von Anfang an richtig, und genau die ging. **Eine zweite Wahrheit fürs
  Zeichnen läuft früher oder später auseinander.** Gerechnet wird dabei vom
  `ausgangsrahmen` aus und nie vom jetzigen: `translation` ist die ganze
  Bewegung seit dem Aufsetzen, und auf einen mitgewanderten Rahmen addiert
  liefe der Block davon.
- **`contentMode` einer selbst zeichnenden `UIView` MUSS `.redraw` sein**
  (`Textkasten`, ab 1.0.8, gemeldet 09/2026: „ein Textfeld, das in der Größe
  verändert wurde, [stellt] den Text verzerrt dar. Man muss erst auf eine
  andere Seite … wechseln"). Die Vorgabe ist `.scaleToFill`: Ändert sich der
  Rahmen, zeichnet UIKit NICHT neu, sondern zieht das zuletzt gezeichnete
  Bild auf die neue Größe — aus gesetztem Text wird eine gestauchte Grafik.
  Der Seitenwechsel half, weil er die Ansicht neu aufbaute. Das ist
  dokumentiertes UIKit-Verhalten und keine Vermutung; es trifft JEDE Ansicht
  dieses Repos, die in `draw(_:)` selbst zeichnet.
- **Zwei Finger vergrößern das BILD, die Griffe den RAHMEN** (`zoomgeste`, ab
  1.0.8, Wunsch des Nutzers 09/2026). Der Unterschied stand seit 1.0.0 im
  Papier (`Bildausschnitt`: „Wer ein Foto größer haben will, ändert den
  Rahmen; wer ein Gesicht in die Mitte rücken will, den Ausschnitt") — es
  fehlte der Griff dafür. Die Seite selbst wird nicht mit zwei Fingern
  gezoomt (dafür stehen die Lupen unten links), es gibt also nichts, womit
  sich die Geste streiten könnte.
- **`translation` und `magnification` sind die GESAMTE Bewegung seit dem
  Aufsetzen** (behoben in 1.0.8). `ausschnittSchieben` addierte sie bei jedem
  Bildpunkt auf den laufenden Wert — das Bild schoss unter dem Finger weg,
  und zwar immer schneller. Gerechnet wird vom Wert beim Aufsetzen
  (`ausgangsausschnitt`), wie überall sonst in dieser Ansicht.
- **Ein Textkasten sagt, wenn etwas herausfällt** (ab 1.0.8, gemeldet
  09/2026: „Leider kann es aber passieren, dass Text abgeschnitten wird …
  Das fällt zunächst nicht unbedingt auf."). Drei Dinge zusammen, und keines
  reicht allein:
  - **Er WÄCHST beim Tippen mit**, wie ein Textfeld in Pages
    (`hoeheAnTextAnpassen` am Ende von `textSchreiben`). Nur wachsen, nie
    schrumpfen — ein Kasten, der von selbst kleiner wird, nähme eine Größe
    weg, die jemand mit der Hand eingestellt hat.
  - **Wer ihn von Hand zu klein zieht, sieht eine MARKE** an der Unterkante
    (`Ueberlaufmarke`, orange, mit Pluszeichen — dieselbe Zeichensprache wie
    in Pages), dazu den Knopf „Rahmen an Text anpassen" in der Fußleiste und
    im Inspektor. Ein Hinweis ohne Weg, ihn aufzulösen, ist die Frage von
    vorhin noch einmal.
  - **Die Druckprüfung zählt das GANZE Buch** (`abgeschnittenerText`). Die
    Marke sieht nur, wer gerade auf dieser Seite ist; ein fehlender Satz
    fällt sonst erst auf, wenn das Buch gedruckt ist.
  **Der Befund ist GESPEICHERT, nicht gerechnet** (`Reisewerk.textUeberlauf`):
  Dahinter steckt ein voller CoreText-Satz, und als berechnete Eigenschaft
  liefe der bei jedem Neuzeichnen der Seite mit — dieselbe Falle wie bei der
  Netzkarte der Abfahrtstafel. Gemessen wird an EINER Stelle, wenn sich
  Auswahl, Rahmenmaße oder Textlänge ändern.
- **Zwei Zeichner für denselben Inhalt zeigen nie dasselbe** (ab 1.0.9,
  gemeldet 09/2026: „Sobald ich einen Doppeltipp auf den Text ausübe,
  erscheint das Textfeld dupliziert, übereinander liegend"). Beim Bearbeiten
  lag das `InlineText`-Feld (UIKit/TextKit) ÜBER dem weiter gezeichneten
  Block (CoreText). Dieselben Wörter, zwei Umbruchmaschinen — die brechen
  nie an derselben Stelle. Der bearbeitete Block wird deshalb nicht mehr
  zusätzlich gezeichnet.
- **Ein Zustand ohne sichtbaren Ausgang ist ein hängengebliebenes Programm**
  (ab 1.0.9). Das Textfeld ließ sich nur schließen, indem man DANEBEN tippte
  — und traf man dabei einen anderen Textblock, ging sofort das nächste Feld
  auf. Jetzt liegt eine unsichtbare Fläche hinter dem Feld, die es schließt
  und den Tipp nicht weiterreicht, dazu der Knopf „Text fertig" in der
  Fußleiste. **Wer einen Modus baut, baut den Ausgang mit — und zwar
  sichtbar.**
- **Wie sich Fotos abheben, gehört dem BUCH** (`Gestaltung.fotoschatten`,
  `.fotorand`, `.fotorandbreite`, `.fotorandfarbe`, ab 1.0.9, Ansage des
  Nutzers 09/2026: „Ich möchte die Einstellung, wie die einzelnen Fotos sich
  abheben sollen … global einstellen können."). Bis 1.0.8 schrieb der
  Layoutautomat Schatten und weißen Rand in JEDEN Fotoblock — danach war die
  Einstellung nicht mehr zu ändern, ohne zweihundert Fotos einzeln
  anzufassen. Am Block stehen sie seither als **Abweichung** (`nil` = wie im
  Buch), genau wie `Schriftabweichung`; aufgelöst wird an EINER Stelle
  (`Block.wirkung`), die Bildschirm UND PDF gemeinsam fragen. Der Stil setzt
  das Buch, nicht die Blöcke. Ein Knopf in der Gestaltung nimmt alle
  Abweichungen zurück.
- **Eine Eigenschaft, die als Wert gedacht war, wird durch `nil` zur
  Abweichung — ohne dass alte Dateien brechen.** Der erzeugte
  `Codable`-Leser verlangt einen Schlüssel nur für NICHT-optionale
  Eigenschaften; ein vorhandener Wert wird gelesen, ein fehlender wird
  `nil`. Deshalb war der Umbau von `schatten`/`fotorand`/`randbreite` auf
  optional gefahrlos — im Gegensatz zum umgekehrten Weg.
- **Derselbe Text zweimal auf einer Seite ist ein DRUCKFEHLER**
  (`Druckpruefung.doppelterText`, ab 1.0.9). Auf dem Bildschirm sieht das
  aus wie eine Unsauberkeit der Anzeige; gedruckt sind es zwei Absätze.
  **Woher ein zweiter Kasten kommt, ist damit nicht beantwortet** — die
  Prüfung macht ihn nur unübersehbar und nennt den Weg, ihn zu entfernen.
  Nicht als geklärt darstellen.
- **Viermal derselbe Befund: „Es war da, man fand es nicht"** (ab 1.0.10,
  gemeldet 09/2026: „Kann ich das jetzt für alle Fotos global einstellen und
  wenn ja, wo? Irgendwie ist die App nicht intuitiv zu bedienen."). Die
  Foto-Einstellung war in 1.0.9 gebaut — sie lag hinter **Buch → „Format,
  Ränder, Karte…"**, also hinter einem Menüpunkt, der nach Papiermaßen
  klingt. Derselbe Befund wie bei der Bildunterschrift (1.0.6), beim
  Zurücksetzen in Tafelbild und beim Gruppenchat in Schulalarm. **Ein
  Menüpunkt, der nicht sagt, was dahinter liegt, ist so wenig wert wie ein
  Knopf, den niemand findet.** Deshalb heißt der Eintrag jetzt schlicht
  **„Fotos…"** und steht eigenständig im Buch-Menü, gleich unter Stil und
  Schrift — dort, wo die Frage gestellt wird.
- **Die Felder stehen EINMAL da und werden an zwei Stellen gezeigt**
  (`Views/Fotostil.swift`, `Fotostilfelder`). Das eigene Blatt (Buch →
  Fotos) und die Unterseite der Gestaltung, wo sie bisher lagen, zeigen
  dieselbe Ansicht. Zwei Fassungen desselben Formulars liefen auseinander —
  dieselbe Regel wie bei `Block.wirkung`, die Bildschirm und PDF gemeinsam
  fragen.
- **Der Weg vom Einzelfall zum Ganzen steht im Inspektor** (ab 1.0.10). Wer
  ein Foto gewählt hat und dessen Wirkung ändern will, ist genau die Person,
  die die Frage „und für alle?" stellt. Im Abschnitt „Wirkung" führt deshalb
  ein Knopf ins Buch-Blatt; seine Beschriftung sagt, wo man steht („Für alle
  Fotos einstellen" oder „Dieses Foto weicht ab — für alle einstellen"),
  und „Wieder wie im Buch" nimmt die Abweichung zurück. Dafür reicht
  `ReiseView` sein `blatt` als `@Binding` in den Inspektor durch: Ein
  zweites Blatt über dem Inspektor wäre eine zweite Ebene für dieselbe
  Einstellung.
- **Gesten sind unsichtbar — also stehen sie aufgeschrieben**
  (`Views/BedienungView.swift`, ab 1.0.10). Eine Buchseite ist seit 1.0.5
  eine ZEICHNUNG, und jeder Griff daran ist eine Geste: Tipp, Doppeltipp,
  Ziehen am Punkt, zwei Finger. Nichts davon sieht man. Die Karte hinter dem
  **„?" unten in der Leiste** zählt auf, was geht und wo was eingestellt
  wird; sie erklärt nichts, denn wer sie öffnet, sucht etwas Bestimmtes.
  **Wer eine neue Geste einbaut, trägt sie dort ein** — eine Geste, die dort
  fehlt, gibt es für den Menschen davor nicht.
- **„Satz" heißt jetzt „Anordnen"** (ab 1.0.10). „Satz" ist das Fachwort für
  das, was der Layoutautomat tut; gesucht wird es von jemandem, der eine
  Seite neu verteilt haben will. Ein Menü, das die Aufgabe nennt statt des
  Handwerks, findet man ohne Vorwissen.
- **Nicht gemessen: ob die App sich jetzt anders anfühlt.** Was gemessen ist,
  sind Wege — die Einstellung liegt eine Ebene höher und heißt nach ihrer
  Sache, die Gesten stehen an einer Stelle. Ob das reicht, sagt erst der
  nächste Befund des Nutzers. **Eine Oberflächenänderung als gelöstes
  Bedienproblem auszugeben wäre genau die Art Behauptung, die dieses Papier
  sonst verbietet.**
- **Ein Knopf, der etwas ZURÜCKNIMMT, setzt voraus, dass es einen Weg hin
  gibt** (`Views/KartenausschnittView.swift`, ab 1.0.11, gemeldet 09/2026:
  „Auf der Karte wird ja quasi nichts dargestellt. Der Ort könnte sonst wo
  sein."). `Reisetag.kartenausschnitt` gibt es seit 1.0.0 — und bis 1.0.10
  konnte ihn NIEMAND setzen: Im Inspektor stand einzig „Wieder automatisch
  rahmen". Gerahmt wurde deshalb immer selbsttätig um die Spur, und für die
  rechnet `Kartenwerk.region` bei einem einzigen Punkt eine Spanne von
  0,008 Grad — rund 900 Meter. Die Karte war also nicht falsch, sie war zu
  nah, und zwar ohne jeden Ausweg. **Ein Feld, das nur gelesen und nie
  geschrieben wird, ist ein halb gebautes Vorhaben** — dieselbe Art Befund
  wie bei der Bildunterschrift in 1.0.5.
- **Gewählt wird auf einer ECHTEN Karte, und übernommen wird das FENSTER.**
  Kein Fadenkreuz wie bei der Ortswahl: Dort wird eine Stelle gewählt, hier
  ein Ausschnitt. Dazu „näher" und „weiter" unmittelbar im Inspektor — wer
  nur etwas herauszoomen will, soll dafür keinen Bildschirm öffnen müssen.
  Beide rechnen vom GELTENDEN Ausschnitt aus, also auch vom automatischen;
  sonst spränge der erste Tipp auf einen Wert, der mit dem Bild auf der
  Seite nichts zu tun hat. Die Spanne steht in Kilometern da (ein Grad
  Breite ≈ 111 km) — eine Gradzahl sagt niemandem etwas.
- **Beschriftungsdichte gibt es bei MapKit NICHT — es gibt einen POI-Filter**
  (`Kartenbeschriftung`, ab 1.0.11). Gewünscht war, „wie dicht die
  Beschriftungen sein sollen". Was sich wirklich einstellen lässt, ist
  `pointOfInterestFilter`: Geschäfte, Museen, Haltestellen. Straßen- und
  Ortsnamen setzt Apple selbst nach Maßstab, und dafür gibt es keine
  Schraube — wer weniger davon will, nimmt die Karte näher heran. **Genau
  das steht in der Oberfläche**, statt einen Regler anzubieten, der nichts
  tut. Beim SATELLITENBILD entscheidet die Wahl sogar über die Art des
  Aufbaus: `MKImageryMapConfiguration` zeigt überhaupt keine Namen, die
  gibt es nur über `MKHybridMapConfiguration`. Bei den Kachelquellen ist die
  Beschriftung fertig IM BILD — das sagt die App dort auch.
  Geändert gegenüber 1.0.10: „Gelände" schaltete die Orte fest ab; das war
  als Stilfrage gebaut und ist jetzt eine eigene Einstellung.
- **`.castle` und `.landmark` gibt es erst ab iOS 18.** Sie wären für eine
  Reisekarte die naheliegenden Kategorien und kosteten einen Bau: Diese App
  baut gegen iOS 17, und ein `@available` für eine Zierde wäre der falsche
  Preis.
- **Ein neues NICHT-optionales Feld macht jede gesicherte Datei unlesbar —
  auch in einem kleinen Typ.** `Kartenbild` bekam `beschriftung` und braucht
  deshalb seit 1.0.11 einen Leser von Hand (`Model/Nachsicht.swift`). Beim
  Gegenlesen gefunden, nicht im Bau: `Reisetag` liest sein `kartenbild` über
  `wahlweise`, und das schluckt den Fehler — die Karteneinstellung wäre
  STILL auf die Vorgabe zurückgefallen. **Die Regel steht seit 1.0.3 im
  Papier und galt bis dahin nur für `Reise` und `Reisetag`; sie gilt für
  jeden Typ, der wächst.**
- **Einrasten sagt jetzt, WORAN** (`Einrasten.Fang`, `Fanglinie`, ab 1.0.11,
  Ansage des Nutzers 09/2026: „Der Randindikator soll sich an den Rand und
  die Fotos orientieren, aber im Einzelfall auch veränderbar sein."). Bis
  1.0.10 rastete der Block stumm ein: Er sprang um zwei Punkte, und ob das
  der Satzspiegel war, die Schnittkante, das Foto darüber oder gar nichts,
  stand nirgends. **Eine Hilfe, die man nicht sieht, ist für den Menschen
  davor ein Zucken.** Gezeichnet wird eine Linie über den ganzen Bogen, mit
  der Herkunft als Wort und als Farbe — „Rand" und „Nachbar" sind zwei
  verschiedene Auskünfte.
- **Die Kanten kommen aus EINER Quelle** (`Einrasten.kanten`). Bis 1.0.10
  baute das Verschieben seine Liste selbst und das Größenändern eine zweite,
  und nur die zweite kannte die Schnittkante: Ein randabfallendes Foto rastete
  beim Ziehen an der Ecke am Anschnitt ein und beim Verschieben nicht.
- **„Im Einzelfall veränderbar" sind zwei Dinge**: der Schalter „An Rand und
  Nachbarn einrasten" unter „Anordnen" (wer ihn ausmacht, bekommt auch keine
  Linien — eine Linie ohne Wirkung wäre eine Behauptung) und die Zahl in
  Millimetern im Inspektor unter „Lage auf der Seite". Der Schalter liegt in
  `@AppStorage` und damit in einer VIEW, nie im `Reisewerk`.
- **Der Absatzabstand war da, die ERKLÄRUNG fehlte** (ab 1.0.11, gemeldet
  09/2026: „Nach wie vor weiß ich nicht, warum bei dem Text nach jedem Absatz
  so viel Platz gelassen wird."). Buchweit steht er seit 1.0.0 unter Buch →
  Schrift. Was fehlte, war zweierlei: die Ausnahme an der einzelnen Stelle
  (`Schriftabweichung.absatzabstand`) und der Grund. Der Grund steht im Text
  selbst: In einem hart umbrochenen Tagebuchtext ist JEDE ZEILE ein eigener
  Absatz, und dann steht der Abstand eben nach jeder Zeile. **Der Inspektor
  zählt die Absätze deshalb und bietet das Zusammenführen an der Stelle an,
  an der die Frage entsteht** (`Textaufbereitung.erzwingen`). Eine Zahl, die
  den Befund erklärt, ist mehr wert als ein Regler, der ihn verdeckt.
  **Offen bleibt, warum die Erkennung aus 1.0.2 bei diesem Text nicht
  gegriffen hat** — gemessen ist sie an zwei Texten des Nutzers, und der
  gemeldete ist ein dritter. Nicht als geklärt darstellen.
- **Ein Textkasten darf einen Grund haben, und der darf durchscheinen**
  (`Block.grund`, `Block.innenabstand`, ab 1.0.11, Ansage des Nutzers
  09/2026: „So könnte beispielsweise auch Text auf einem Hintergrundbild
  gemacht werden."). Den farbigen Grund gab es; was fehlte, waren die zwei
  Dinge, die ihn brauchbar machen:
  - **Die Deckkraft als eigener Schieber.** `Farbwert` trägt sie seit 1.0.0,
    und der Farbwähler von iOS kann sie — aber hinter einem Tipp auf das
    Farbfeld, und wer sie sucht, findet sie nicht. Sie ist hier kein Schmuck,
    sondern der Zweck: Ein halbdurchsichtiges Feld lässt ein Foto durch und
    die Schrift trotzdem lesbar bleiben.
  - **Ein Innenabstand.** Schrift, die unmittelbar an der Kante einer Fläche
    anfängt, sieht aus wie ein Satzfehler. Er wird beim Einschalten des
    Grundes gesetzt und beim Ausschalten NICHT zurückgenommen — wer ihn von
    Hand geändert hat, soll ihn behalten.
- **Ein Innenabstand muss an ALLEN VIER Textstellen mitgerechnet werden**:
  auf dem Bildschirm (`Textkasten`), im PDF (`Buchausgabe`), bei der
  Überlaufmessung (`Reisewerk.fehlendeHoehe`) und in der Druckprüfung.
  Gerechnet wird er an einer Stelle (`Block.textrechteck` / `textbreite`);
  vergäße man eine der vier, sagte die Marke „passt", während im Druck eine
  Zeile fehlt. Das Textfeld beim Bearbeiten bekommt denselben Wert als
  `textContainerInset` — sonst spränge der Text beim Doppeltipp an die Kante
  und beim Schließen wieder zurück.
- **Nicht gemessen:** wie sich das alles auf einem Gerät anfühlt. Gemessen
  sind Wege und Rechnungen; ob die Fanglinie beim Schieben hilft oder stört
  und ob der gewählte Kartenausschnitt im Druck das Erwartete zeigt, sagt
  erst der nächste Befund.
- **Ein `UIViewRepresentable` ohne `sizeThatFits` bestimmt seine Größe SELBST**
  (`TextflaecheBruecke`, ab 1.0.12; gemeldet 09/2026, zum zweiten Mal: „Das
  Bearbeiten des Textes im Kasten funktioniert noch nicht richtig. Wieder wird
  beim Doppeltipp der Text außerhalb des Rahmens dargestellt."). 1.0.9 hatte
  die DOPPELUNG behoben (der Block wird nicht mehr zusätzlich gezeichnet) und
  den Überstand stehen lassen — zwei Befunde in einem Bild, und nur einer war
  gelesen. Die Rechnung dahinter ist am Quelltext nachzuzählen und keine
  Vermutung: Das Feld ist ein `UITextView` mit `isScrollEnabled = false`, und
  so eines meldet die Größe, die sein Text BRAUCHT, nicht die, die es bekommt.
  Ohne `sizeThatFits` nimmt SwiftUI genau diese Zahl — und **`.frame()`
  beschneidet nicht, es stellt ein zu großes Kind MITTIG hin**. Genau so sah
  das Bildschirmfoto aus: der Text über die halbe Seite, mittig auf dem
  orangen Rechteck, die Absätze zu drei sehr langen Zeilen geworden.
  Zurückgegeben wird jetzt die angebotene BREITE (nie mehr) und die HÖHE, die
  der Text darin braucht; ausgerichtet wird oben links, und die Höhe hängt an
  `.frame(minHeight:)` statt an einer festen — so wächst der Kasten beim
  Tippen nach unten, wie in Pages, statt Zeilen zu verschlucken. **Merke: Wer
  eine UIKit-Ansicht in SwiftUI einhängt, sagt ihr, wie groß sie sein darf.**
- **Textfelder lassen sich buchweit einstellen** (`Gestaltung.textgrund`,
  `.textinnenabstand`, `.textrandbreite`, `.textrandfarbe`, `.textschatten`,
  Blatt „Buch → Textfelder…", ab 1.0.12, Ansage des Nutzers 09/2026: „Kann ich
  global einstellen, wie die Einstellungen für die Textfelder sein sollen? Ich
  möchte das können."). Dieselbe Bauweise wie bei den Fotos in 1.0.9/1.0.10 und
  aus demselben Grund: **Abweichung, keine Kopie** — `nil` am Block heißt „wie
  im Buch", aufgelöst an der einen Stelle (`Block.wirkung`), die Bildschirm UND
  PDF fragen. Zwei getrennte Sätze für Foto und Text, nicht einer: Ein
  Textkasten mit dem Schatten aller Fotos wäre eine Überraschung, und wer den
  weißen Sofortbild-Rand seiner Bilder hochzieht, meint nicht die Schrift.
- **„Nichts gesetzt" und „hier ausdrücklich keiner" sind NICHT dasselbe**
  (`Block.ohneGrund`, ab 1.0.12). Solange es nur den Block gab, hieß
  `grund == nil` beides auf einmal. Sobald das Buch einen Grund vorgibt, fällt
  das auseinander: Der Schalter „Farbiger Grund" ginge aus, der Grund käme vom
  Buch zurück, und für den Menschen davor wäre der Schalter kaputt — dieselbe
  Lehre wie bei „Ein Knopf, der schweigt". **Wer eine buchweite Vorgabe
  nachrüstet, prüft, ob sich das Abschalten noch sagen lässt.**
- **`Gestaltung`, `Block` und `Seite` lesen sich seit 1.0.12 von Hand**
  (`Model/Nachsicht.swift`). Die Regel stand seit 1.0.3 im Papier und galt für
  `Reise` und `Reisetag`; die Typen DARUNTER hatten sie nicht, und genau in
  ihnen wuchs diese Fassung. Was das gekostet hätte, ist auszurechnen:
  `Reise` holt die Gestaltung über `b.wert(.gestaltung, Gestaltung())` — ein
  neues Feld dort hätte in jedem vorhandenen Buch **Format, Ränder, Bundsteg,
  Anschnitt und Fotowirkung** auf die Vorgaben zurückgesetzt, still, denn das
  Buch öffnet sich ja. Und ein neues Feld in `Block` hätte über
  `seiten = b.wert(.seiten, [])` die ganze Seitenliste eines Tages
  mitgenommen, also die Handarbeit eines Abends. **Jeder Typ, der wächst,
  bekommt seinen Leser, bevor er wächst.**
- **Der Umbruch ist eine Eigenschaft der DATEI, nicht des Tages**
  (`Textaufbereitung.vermessen`, ab 1.0.12; gemeldet 09/2026: „Der Textimport
  hat offenbar am Ende jeder Zeile einen Absatz erzeugt. Ich frage mich, ob das
  an meiner Vorlage lag … oder ob der Textinterpreter nicht richtig
  funktioniert."). Er hat nicht richtig funktioniert, und die Rechnung sagt
  auch, warum. **Nachgerechnet am gemeldeten Tag** (4. Juni 2026, sieben Zeilen
  von 46, 102, 104, 56, 43, 31 und 16 Zeichen): `laengste` = 104, `grenze` = 88,
  und nur zwei der sieben Zeilen erreichen sie — 29 % gegen eine Schwelle von
  35 %. Die Erkennung stand also still, obwohl die Vorlage hart umbrochen war.
  Gemessen wurde bis 1.0.11 je Tag (`Textimport.lesen` ruft `pruefen` in
  `abschliessen()`, also einmal je Abschnitt), und ein kurzer Tag endet nun
  einmal mit einer kurzen Zeile — je kürzer der Tag, desto schwerer wiegt sie.
  Wo die Umbruchspalte lag, hat der Schreiber aber EINMAL für die ganze Datei
  entschieden. Gemessen wird deshalb einmal über den gesamten Text und das
  Ergebnis an jeden Tag weitergereicht. **Merke: Bevor eine Schwelle als zu
  streng gilt, prüfen, ob sie am richtigen Gegenstand gemessen wird.**
- **Zwei Zeichen entscheiden unabhängig von der Länge** (`Textaufbereitung.fortsetzt`).
  Beide stehen im gemeldeten Text: ein **Bindestrich am Ende** der vorigen Zeile
  („Boeing 747-" / „400") ist ein zerrissenes Wort, und ein **Komma am Anfang**
  dieser Zeile („, zurück nach Frankfurt") kann kein Absatzanfang sein. Eng
  gefasst mit Absicht — „fängt klein an" allein reicht NICHT: In einem frei
  geschriebenen Text gibt es kleingeschriebene Absatzanfänge, und ein zu
  Unrecht zusammengezogener Absatz ist der teurere Fehler, weil er im
  gedruckten Buch nicht mehr zu sehen ist.
- **Die Zahlen stehen im Einlesen-Blatt, und auch der Fall „nichts getan" sagt
  es** (ab 1.0.12). Längste Zeile, Anteil, Zeilenzahl, Schwelle und das
  Ergebnis — und je Tag steht die Zeile jetzt auch dann da, wenn NICHT
  zusammengeführt wurde. Das ist die Antwort auf die Frage, mit der dieser
  Durchgang anfing: „lag das an meiner Vorlage oder am Textinterpreter?" Eine
  Erkennung, die schweigt, wenn sie nichts tut, lässt einen raten. Gemerkt wird
  das Maß in `@State` und nicht als berechnete Eigenschaft — der Lauf geht über
  jede Zeile, und das Blatt zeichnet sich bei jedem Tastendruck neu (dieselbe
  Falle wie bei der Netzkarte der Abfahrtstafel).
- **`Farbwert(_:deckung:)` hält die Deckkraft fest** (ab 1.0.12, beim
  Gegenlesen gefunden). Der Farbwähler steht auf `supportsOpacity: false` und
  gibt deshalb IMMER volle Deckung zurück; seit 1.0.11 steht daneben ein
  eigener Deckkraft-Schieber — jeder Griff an die Grundfarbe setzte ihn also
  stillschweigend auf 100 % zurück. Genau das, wofür der Schieber gebaut wurde
  (Text auf einem Hintergrundbild), war damit nach einem Farbwechsel weg.
- **Nicht gemessen:** ob das Textfeld beim Doppeltipp jetzt wirklich im Rahmen
  steht. Gerechnet ist, WARUM es überstand (ein Kind ohne Maßangabe, ein
  `.frame`, das nicht beschneidet); gesehen hat es niemand. Ebenso ungemessen
  bleibt, ob die Umbruch-Erkennung an der Vorlage des Nutzers jetzt greift —
  sie ist an seinen Zahlen nachgerechnet, und die Datei selbst liegt hier
  nicht. **Beides nicht als erledigt darstellen**, bevor der nächste Befund es
  sagt.
- **Was eine Datei IST, sagen die ersten Bytes — nicht die Endung**
  (`Dienste/Textquelle.swift`, ab 1.0.13, Wunsch des Nutzers 09/2026: „Ich
  möchte Texte im Word-Format, PDF oder reinen Text eingeben können."). Bis
  1.0.12 nahm der Textimport nur eine Textdatei; wer sein Tagebuch in Word
  geschrieben hatte, musste es erst irgendwo hindurchkopieren. Alles, was eine
  Datei in Text verwandelt, steht jetzt an EINER Stelle — der Bildschirm ruft
  eine Funktion und bekommt einen Befund; ob dahinter PDFKit, ein ZIP-Leser
  oder eine Kodierungsleiter steckt, weiß er nicht. **Dieselbe Lehre wie in
  Textauszug**, wo sechs Kilobyte HTML mit `.pdf` im Namen ankamen: Eine
  Endung ist eine Behauptung, die ersten Bytes sind eine Tatsache. Die Endung
  entscheidet nur da, wo die Bytes nichts sagen — bei reinem Text.
- **PDF liest PDFKit, und was es NICHT hergibt, ist die Lage der Zeilen**
  (`Dienste/Pdftext.swift`, ab 1.0.13). Textauszug muss seinen PDF-Leser
  selbst schreiben, weil im Browser keiner mitgeliefert wird; auf iOS gehört
  einer zum System, und ihn nachzubauen wäre dieselbe Arbeit noch einmal samt
  einer zweiten Fehlerquelle. Der Preis ist die Kopfzeilenerkennung: Dort
  misst der ABSTAND zum Satzspiegel, hier bleibt nur der Text je Seite.
  Erkannt wird deshalb die **Wiederholung** — eine Zeile, die auf den meisten
  Seiten ganz oben oder ganz unten steht und sich nur in ihren Ziffern
  unterscheidet (`marke` ebnet Zifferngruppen zu `#` ein, sonst käme „Seite 3
  von 30" nie zweimal vor). **Das ist ein anderes Merkmal und wird auch anders
  falsch**: Ein Buch mit wiederkehrendem Refrain als erster Zeile verlöre ihn.
  Deshalb steht hinterher WÖRTLICH da, was entfernt wurde — eine Zahl („2
  Zeilen entfernt") wäre keine Auskunft, sondern eine Behauptung. Unter drei
  Seiten wird gar nichts entfernt, und eine Zeile über 90 Zeichen gilt als
  Fließtext.
- **Ein Scan und eine kennwortgeschützte PDF sagen je EINEN Satz**, der den
  Weg drumherum nennt — dieselbe Regel wie in Textauszug. Die Scan-Grenze ist
  gemessen und nicht gefühlt: unter zwanzig Nicht-Leerzeichen je Seite ist
  kein Text mehr da, sondern nur noch Versprengtes aus einer Textebene.
- **Eine `.docx` ist ein ZIP, und auf iOS gibt es keinen Entpacker**
  (`Dienste/Zipleser.swift`, `Dienste/Wordtext.swift`, ab 1.0.13). Dieselbe
  Lücke, wegen der `Buchdatei` ein eigenes Format schreibt. Ausgepackt wird
  über Apples `Compression`: **`COMPRESSION_ZLIB` ist dort das ROHE DEFLATE
  nach RFC 1951**, und genau das steht in einem ZIP — ohne zlib-Kopf und ohne
  Prüfsumme davor; dieselbe Überlegung wie `DecompressionStream('deflate-raw')`
  in Textauszug. Gelesen wird über das **zentrale Verzeichnis** am Ende und
  nicht durch Vorwärtssuche nach lokalen Köpfen: `PK\u{03}\u{04}` kann auch
  mitten in gepackten Daten stehen. Und die Namens- und Extralängen kommen aus
  dem **lokalen** Kopf, nicht aus dem Verzeichnis — Word schreibt dort andere
  Extrafelder, und wer die Zahlen von der falschen Stelle nimmt, landet ein
  paar Bytes neben den Daten.
- **`NSAttributedString` kann `.docx` auf iOS NICHT.** Sein
  `officeOpenXML`-Dokumenttyp gibt es nur auf dem Mac; der Weg über `.html`
  startet intern WebKit, muss auf den Hauptfaden und liest eine `.docx`
  ohnehin nicht. RTF dagegen kann es wirklich und ohne WebKit — deshalb bleibt
  genau dieser eine Weg bei Apple.
- **Aus `word/document.xml` wird NUR `w:t` in einem `w:r` gelesen.**
  `w:instrText` trägt Feldbefehle („HYPERLINK \\l …"), `w:delText` den
  gelöschten Text aus der Nachverfolgung — beides stünde sonst im Tagebuch.
  Dazu zwei Fallen: **`w:tab` gibt es zweimal** (im Lauf als Zeichen, in den
  Absatzeigenschaften als Definition eines Tabstopps — nur das erste ist
  Text), und **„p" und „t" gibt es auch in DrawingML**, also in Schaubildern;
  gezählt wird deshalb der Namensraum und nicht der nackte Name. Ein `w:br`
  wird zur ZEILE und nicht zum Absatz: Das ist genau der hart umbrochene Text,
  den `Textaufbereitung` seit 1.0.12 wieder zusammenführt.
- **Die alte `.doc` wird an ihrer Kennung erkannt und abgewiesen.** Sie ist
  kein ZIP, sondern ein zusammengesetztes Dokument von 1997
  (`D0 CF 11 E0 A1 B1 1A E1`); ohne diese Prüfung meldete der Zipleser „kein
  ZIP-Archiv" — wörtlich richtig und für den Menschen davor wertlos. Der Satz
  nennt jetzt den Weg: in Word öffnen, als `.docx` sichern.
- **Die Reihenfolge der Kodierungen IST die Sache** (`Textquelle.reinerText`,
  ab 1.0.13). `isoLatin1` nimmt JEDES Byte an und scheitert nie — bis 1.0.12
  stand es vor `windowsCP1252`, und damit war der CP1252-Zweig unerreichbarer
  Quelltext: Die Bytes 0x80 bis 0x9F einer Windows-Datei (also „ “ – …) wurden
  zu unsichtbaren Steuerzeichen, ohne eine einzige Fehlermeldung. Gelesen wird
  jetzt: Byte-Vorzeichen zuerst (eine UTF-16-Datei kam vorher als Salat mit
  Nullbytes an), dann UTF-8, dann Windows-1252, dann ISO 8859-1 als letzte
  Rettung. **Merke: Ein Decoder, der nie scheitert, darf nie vor einem stehen,
  der scheitern kann.**
- **Der Bildschirm sagt, was angekommen ist** — Art, Dateiname, Seiten,
  Absätze, Kodierung, Zeichenzahl, dazu die entfernten Randzeilen. Dieselbe
  Regel wie beim Einfuhrbericht der Fotos: Ein stummer Import lässt die Frage
  offen, ob überhaupt die richtige Datei gewählt wurde.
- **Nicht gemessen:** Keine der vier Wege ist an einer echten Datei des
  Nutzers gelaufen — hier gibt es weder Word noch PDFKit. Gerechnet ist der
  Aufbau (ZIP-Verzeichnis, DEFLATE-Sorte, welche Word-Elemente Text tragen,
  welche Kodierung wann scheitert); ob eine bestimmte `.docx` oder PDF
  durchgeht, sagt erst der nächste Befund. **Nicht als erledigt darstellen.**
- **Der Umbruch sucht ZUERST einen Absatz** (`Textmass.teilenMitArt`, ab 1.0.14,
  Ansage des Nutzers 09/2026: „Sodass Texte, die in der angegebenen Schriftgröße
  zu groß für eine Seite sind, automatisch auf einer weiteren Seite fortgesetzt
  werden. Dabei wäre es schön, wenn an einem bestehenden Absatz umgebrochen
  wird."). Fortgesetzt wurde schon vorher — geteilt wurde aber an der
  WORTgrenze, also mitten im Gedanken. Jetzt wird vor der Wortgrenze die letzte
  Absatzgrenze gesucht, die noch auf die Seite passt.
  - **Der Absatz gewinnt nicht um jeden Preis.** Steht die letzte Grenze weit
    oben — ein einziger langer Absatz füllt den Rest —, bliebe unten eine große
    weiße Fläche stehen, und die sieht nach Abbruch aus. Gemessen wird deshalb,
    wie hoch der Kopf bis zu dieser Grenze WIRD (`Textmass.hoehe`, also
    CoreText, nicht die Zeichenzahl), und verglichen mit dem Platz, den es gibt.
    Unter 62 Prozent Füllung bleibt es bei der Wortgrenze. **Die Zahl ist
    gewählt und nicht gemessen** — sie lässt höchstens gut ein Drittel Seite
    frei.
  - **Ein Absatz ist der ZEILENWECHSEL**, nicht die Leerzeile. `Schriftbild`
    setzt den Absatzabstand als `paragraphSpacing`, und CoreText zählt dafür
    genau dieselbe Grenze; zwei Meinungen darüber, wo ein Absatz aufhört, wären
    zwei verschiedene Umbrüche. Mitgelesen werden U+2028 und U+2029 — die
    stehen in Texten aus Word und aus PDFs und wären sonst unsichtbar.
- **Fotos warten nicht mehr, bis der Text fertig ist** (`Layoutautomat.reihenSetzen`,
  ab 1.0.14). Bis 1.0.13 füllte der Text auf jeder Folgeseite die ganze Höhe;
  ein Tag mit langem Text und vielen Bildern ergab erst mehrere reine
  Textseiten und danach reine Fotoseiten — das Bild zum Erzählten stand drei
  Seiten weiter. **Freigehalten wird die GEMESSENE Höhe der nächsten Fotoreihe**
  (`naechsteReihe` rechnet sie ohnehin aus) und kein geschätzter Anteil: Ein
  Anteil, der zu klein ist, lässt die Reihe doch nicht hinein, und dann bliebe
  unten weißer Platz, den niemand bestellt hat. Passen nach der Reihe keine
  sechs Zeilen Text mehr auf die Seite, wird gar nichts freigehalten — eine
  Seite mit vier Zeilen über einem Bild ist kein Satz, sondern ein Rest. Ist
  kein Foto mehr offen, gilt wieder die ganze Seite.
- **Einen Textkasten von Hand teilen** (`Reisewerk.textTeilen`, ab 1.0.14,
  Ansage des Nutzers 09/2026: „Im Nachhinein möchte ich eine Textbox
  gegebenenfalls teilen können und sie manuell auf einer weiteren Seite
  fortführen können."). Zwei Wege, weil es zwei Fragen sind: „Rest auf die
  nächste Seite" lässt stehen, was in den Kasten passt, und schiebt den
  Überhang weiter — die Stelle sagt der Satz, man muss sie nicht suchen;
  „Nach einem Absatz teilen" trennt an einer selbst gewählten Stelle und gilt
  auch dann, wenn gar nichts herausfällt. Ausgesucht wird nach dem ANFANG des
  Absatzes: „Absatz 4" sagt niemandem etwas, „Am Morgen zogen wir …" schon.
  - **Der erste Kasten behält seinen Rahmen.** Ihn auf den verbliebenen Text zu
    schrumpfen wäre der naheliegende Griff und der falsche — dieselbe Regel wie
    bei `hoeheAnTextAnpassen`: Ein Kasten, der von selbst kleiner wird, nimmt
    eine Größe weg, die jemand mit der Hand eingestellt hat.
  - **Die Fortsetzung ist eine KOPIE mit neuer Kennung** — Schrift, Grund,
    Innenabstand, Linie und Breite bleiben, nur Inhalt, Lage und Höhe sind neu.
    Sie soll aussehen wie ihr Anfang.
  - **Auf eine schon gefüllte Folgeseite kommt sie nicht**, sonst läge sie über
    dem, was dort steht; dann bekommt sie eine eigene, und die steht
    unmittelbar hinter dem Anfang — eine Fortsetzung drei Seiten später findet
    niemand. Beide Kästen tragen danach `vonHand`, der Tag gilt also als
    Handarbeit und wird nicht ohne Rückfrage neu angeordnet.
  - **Geteilt wird nur der Tagebuchtext.** Überschrift, Datumszeile und
    Bildunterschrift stehen am Tag bzw. am Foto; von ihnen eine zweite Hälfte
    anzulegen hieße, eine Kopie zu bauen, die beim nächsten Neuanordnen
    auseinanderläuft.
  - **Drei Wege dorthin**, und keiner davon ist eine Geste: Block → Teilen, der
    Knopf unten in der Leiste (er steht neben „Rahmen an Text anpassen", sobald
    die orange Marke zu sehen ist — auf einer vollen Seite ist er der einzige
    Ausweg, der bleibt) und die Zeile in der Bedienungskarte. **Wer einen neuen
    Griff einbaut, trägt ihn dort ein.**
- **Nicht gemessen (1.0.14):** Kein Buch ist damit gesetzt worden. Gerechnet
  sind die Regeln — wo ein Absatz aufhört, wie hoch der Kopf wird, wie hoch die
  nächste Fotoreihe ist; wie eine Doppelseite damit AUSSIEHT, sagt erst der
  nächste Befund des Nutzers. Die beiden Zahlen (62 Prozent Füllung, sechs
  Zeilen neben einer Fotoreihe) sind gewählt und nicht gemessen. **Nicht als
  erledigt darstellen.**
- **Der Inspektor ist eine SPALTE und läuft bei jedem Bildpunkt mit** (ab
  1.0.15; gemeldet 09/2026: „Nach kurzer Zeit ist die App nun eingefroren.").
  **Nicht gemessen, sondern am Quelltext abgezählt** — ein Gerät gibt es hier
  nicht. `BlockInspektor` hängt an `.inspector(isPresented:)`, steht also offen,
  während gearbeitet wird, und sein Körper läuft bei JEDER Meldung des
  `Reisewerk`s noch einmal. Seit 1.0.8 wandert ein geschobener Rahmen sofort
  ins Modell — beim Schieben meldet sich das Werk damit bei jedem Bildpunkt.
  In 1.0.14 baute der Inspektor dabei drei Dinge, die keine sind:
  - **Ein `Menu` mit einem Knopf je Absatz.** Der Inhalt eines `Menu`
    entsteht beim Zeichnen des Formulars, nicht beim Aufklappen; und ein
    eingelesener Tagebuchtext ist hart umbrochen, also ist JEDE ZEILE ein
    Absatz. Bei einem Tag mit zweihundert Zeilen sind das zweihundert Knöpfe
    samt zweihundert Textausschnitten — sechzigmal in der Sekunde. Die
    Auswahl steht seit 1.0.15 in einem Blatt mit einer `List`: Die baut nur,
    was zu sehen ist, und erst beim Öffnen.
  - **Zweimal die Absatzliste** über den ganzen Text (einmal für die Zahl,
    einmal für das Menü). Sie wird jetzt EINMAL je Änderung gerechnet
    (`.task(id:)`, Schlüssel ist der Text selbst) und liegt in `@State` —
    dieselbe Bauweise wie `textUeberlauf` seit 1.0.8.
  - **Zwei Suchläufe in der Werkzeugleiste.** `werk.block(_:)` geht durch
    alle Tage, Seiten und Blöcke; 1.0.14 stellte `teilbarerText` neben
    `gewaehltesFoto`. Es ist jetzt ein Lauf (`ReiseView.gewaehlterBlock`).
  **Die Lehre ist alt und stand für die Karte schon da** („Eine berechnete
  Eigenschaft sieht billig aus"): **Was im Körper einer Ansicht steht, läuft
  so oft, wie gezeichnet wird — und wer das nicht weiß, misst es.**
- **Und weil sich das hier nicht nachmessen lässt, misst es die App**
  (`Dienste/Zeichenmesser.swift`, sichtbar unter Anordnen → „Bedienung
  prüfen", ab 1.0.15). Neuzeichnungen je Sekunde von Seite und Inspektor,
  dazu die Dauer des Absatzlaufs — **immer mit der Zeitspanne dabei**, denn
  eine Rate ohne ihren Zeitraum ist keine Messung. Dasselbe Muster wie der
  Kartenmesser der Abfahrtstafel und die Stufenprobe bei Schulalarm.
  **Kein `@Published` und kein `ObservableObject`**: Die Ansichten melden
  sich dort an, und wäre der Messfühler beobachtbar, löste jede Meldung ein
  Neuzeichnen aus, das seinerseits gemeldet würde — ein Messgerät, das seinen
  eigenen Messwert erzeugt. Gemeldet wird im KÖRPER und nicht in `onAppear`:
  Nur der Körper läuft bei jedem Neuzeichnen.
- **Die Notbremse des Layoutautomaten verlor den Rest des Textes** (gefunden
  beim Nachrechnen 09/2026, behoben in 1.0.15). `reihenSetzen` bricht nach
  200 Durchgängen ab — gedacht gegen eine Endlosschleife. Das nackte `break`
  gab den Resttext aber nur zurück, und der Aufrufer setzt ihn danach
  nirgends mehr: Genau der Fehler aus dem ersten gedruckten Stand („mussten
  von Passagieren, die"), nur in einem Zweig, den bis dahin niemand betrat.
  Seit 1.0.14 laufen Text und Fotoreihen abwechselnd, die Zahl der Durchgänge
  ist also gestiegen. Was beim Abbruch übrig ist, wird jetzt gesetzt und
  läuft notfalls sichtbar über. **Ein Tagebuch darf keinen Satz verlieren —
  auch nicht in einem Notausgang.**
- **Nicht gemessen (1.0.15) — und die Gegenprobe steht dabei:** Ob das
  Einfrieren wirklich daher kam, weiß niemand. Die Rechnung gilt nur, wenn
  der Block-Inspektor offen WAR; war er zu, ist sie widerlegt, und dann sagt
  der Messfühler beim nächsten Mal, wo es hakt. **Nicht als erledigt
  darstellen** — es ist die erste Erklärung für diesen Befund, und in diesem
  Papier stehen genug Fälle, in denen die erste eine Vermutung war.
- **Die Gegenprobe kam sofort, und sie ging gegen 1.0.15** (gemeldet 09/2026:
  „Erst ging es. Als ich auf eine andere Seite wollte, fror es ein.", dazu das
  Bild des Messfühlers: `Inspektor 18/s (48 in 2,7 s) · Seite 36/s (98 in
  2,7 s) · Absätze 0,0 ms`). Drei Dinge stehen darin, und sie widerlegen die
  Erklärung von 1.0.15 für DIESEN Fall: Der Absatzlauf kostet **null**
  Millisekunden, die Raten sind mäßig, und der Inspektor war auf dem Bild
  **zu** — er zählte trotzdem mit, weil eine `.inspector`-Spalte auch
  zugeklappt einen Körper hat. Was 1.0.15 abgestellt hat, war richtig
  abgestellt; es war nicht das hier. **Genau dafür war die Probe da** — und
  dass sie die eigene Erklärung umwirft, ist ihr Sinn und kein Rückschlag.
- **Ein `VStack` ist nicht lazy — und baute damit das GANZE Buch** (behoben in
  1.0.16). Das ist der erste Befund in dieser Sache, der zum Zeitpunkt passt:
  Die Bühne ist ein `ScrollView` mit einem `VStack` und einem `ForEach` über
  die sichtbaren Seiten, und ein gewöhnlicher `VStack` baut JEDES Kind sofort
  auf, auch das zwanzig Seiten tiefer. Je Seite hängen daran alle Textkästen
  (je ein voller CoreText-Satz) und alle Fotos (je ein Vorschaubild, von der
  Platte gelesen und auf dem HAUPTFADEN entpackt). Ist kein Tag gewählt, sind
  das sämtliche Seiten des Buches. **Und genau das geschieht beim Wechsel**:
  Die Liste wird eine andere, und alles darin entsteht neu. Jetzt ein
  `LazyVStack` — gebaut wird, was in Sichtweite kommt.
- **`Reise.seitenfolge` sah billig aus und setzte das Titelblatt neu** (ab
  1.0.16). Es ist eine berechnete Eigenschaft, und darin steckt zweierlei:
  `reise.automat` baut `fotoIndex`, also ein Wörterbuch über ALLE Fotos des
  Buches, und `automat.titelseite(…)` setzt das Titelblatt samt zwei
  CoreText-Messungen. Gelesen wurde sie im Körper von `ReiseView`, und dort
  **zweimal** je Durchgang — einmal für die Liste, einmal für die Prüfung auf
  leer. Dritte Auflage derselben Falle (Netzkarte der Abfahrtstafel,
  Druckprüfung und Datumserkennung in 1.0.0): **Eine berechnete Eigenschaft
  sieht billig aus.**
- **Gemerkt wird NUR das Titelblatt** (`Reisewerk.titelblatt`). Es ist die
  einzige Seite, die es nicht GIBT, sondern die gerechnet wird; alle anderen
  stehen als `Seite` am Tag und werden nur aufgereiht. Die Blöcke eines Tages
  zu merken hieße, beim Schieben einen alten Stand zu zeichnen — die Lehre aus
  1.0.8, und sie gilt hier genauso. **Der Schlüssel nennt alles, was in das
  Titelblatt eingeht** (Titel, Untertitel, Zeitraum, Titelfoto samt der Frage,
  ob es das noch gibt, Format, Gestaltung, Typografie, Stil); fehlte ein Feld,
  bliebe ein alter Titel stehen, ohne dass etwas darauf hinwiese. Wer
  `Layoutautomat.titelseite` ändert, ändert den Schlüssel mit.
- **`updateUIView` läuft bei JEDEM Durchgang, nicht bei jeder Änderung**
  (`Textkasten`, ab 1.0.16). Dort stand ein `setNeedsDisplay()` ohne
  Bedingung, und die drei Zuweisungen darüber lösten über ihre
  `didSet`-Beobachter je eines aus. Dahinter steckt ein voller CoreText-Satz
  je Textkasten, und eine Seite hat drei bis fünf davon. Verglichen wird
  jetzt vorher — `Schriftbild` ist `Hashable`. **Merke: Eine
  `UIViewRepresentable` bekommt ihr `update` bei jedem Neuzeichnen; was darin
  teuer ist, gehört hinter einen Vergleich.**
- **Das Papierkorn flimmerte, und der Kommentar daneben behauptete das
  Gegenteil** (`Saatstrom`, `Seitensatz.kornpunkte`, ab 1.0.16, beim
  Nachrechnen gefunden). Bildschirm und PDF würfelten es getrennt, jeder mit
  einem `SystemRandomNumberGenerator` — der lässt sich nicht wiederholen. Zwei
  Folgen: Auf dem Bildschirm war das Korn bei jeder Neuzeichnung ein anderes,
  also ein Flimmern statt einer Struktur; und die gedruckte Seite sah nie aus
  wie die angesehene — in einer App, deren erste Regel lautet, dass Seite und
  PDF derselbe Setzer zeichnet. Im Quelltext stand dazu, der Zufallsstrom sei
  „AN DER SEITE festgemacht"; er war es nie. **Ein Kommentar ersetzt keine
  Prüfung** — dieselbe Lehre wie bei Schulalarms `requestAuthorization` und
  den Navigationszielen der Abfahrtstafel. Gerechnet wird es jetzt an EINER
  Stelle, mit einer Saat aus der Seitenkennung.
- **Die Saat kommt aus den BYTES der Kennung, nie aus `hashValue`**
  (`UUID.saat`). Den streut Swift bei jedem Programmlauf neu; dieselbe Seite
  sähe nach jedem Start der App anders aus. Dieselbe Falle wie bei den
  Linienfarben der Abfahrtstafel.
- **Der Messfühler nennt seit 1.0.16 auch SUMMEN** (`Zeichenmesser.sammelt`):
  wie oft etwas im Zeitfenster gelaufen ist und wie viel Zeit dabei
  zusammenkam — Fotos, Seitenliste, Titelblatt. Die LETZTE Dauer sagt darüber
  nichts; sie ist gerade dann klein, wenn der Zwischenspeicher zufällig traf.
  Dazu ein Knopf „Befund kopieren" unter Anordnen: Eine Messung, die man
  abschreiben oder abfotografieren muss, kommt verkürzt an.
- **Nicht gemessen (1.0.16), und das ist die zweite Erklärung für dasselbe
  Einfrieren.** Abgezählt ist, WAS je Neuzeichnung und je Seitenwechsel
  anfiel; ob das Gerät danach flüssig ist, sagt erst der nächste Befund. Die
  Zahl der gezeichneten Korn-Punkte ist unverändert — nur der Zufall daran ist
  weg. **Nicht als erledigt darstellen.**
- **Zwei Finger zoomen die SEITE — außer über einem gewählten Foto** (`seitenzoom`,
  ab 1.0.17, Ansage des Nutzers 09/2026: „Ich weiß, dass es links einen Regler
  gibt, aber der ist mir zu umständlich zu bedienen. Eine Zwei-Finger-Geste auf
  die Seite wäre mir lieber."). Die Geste hängt am INHALT der Bühne, nicht an
  einer einzelnen Seite: Gezoomt wird das Blatt und nicht, was darauf liegt.
  **Damit gibt es erstmals zwei Bedeutungen für dieselbe Geste** — seit 1.0.8
  vergrößern zwei Finger über dem gewählten Foto den Bildausschnitt IM Rahmen,
  und der Satz „die Seite selbst wird nicht mit zwei Fingern gezoomt, es gibt
  also nichts, womit sich die Geste streiten könnte" stand genau deshalb im
  Papier. Aufgelöst wird das an EINER Stelle (`seitenzoomErlaubt`): Ist ein Foto
  gewählt oder der Ausschnittsmodus an, gehört die Geste dem Bild, sonst der
  Seite. **Das ist erlaubt, weil der Unterschied SICHTBAR ist** (die Anfasser
  stehen da, ein Tipp daneben hebt die Auswahl auf) und weil es daneben immer
  einen Weg gibt, der nicht von der Auswahl abhängt: die Lupen unten links.
  Dieselbe Regel wie beim Fußwegmesser der Abfahrtstafel — **ein Modus, den man
  nicht sieht, darf die Bedeutung einer Geste nicht ändern.**
- **`magnification` ist die GESAMTE Bewegung seit dem Aufsetzen** — gerechnet
  wird vom Maßstab beim Aufsetzen (`zoomAnfang`) und nie vom laufenden Wert,
  sonst beschleunigt der Zoom mit jedem Bildpunkt. Dieselbe Falle wie beim
  Bildausschnitt in 1.0.8, jetzt zum zweiten Mal.
- **Der eingepasste Maßstab wird GEMESSEN, nicht geschätzt** (`passenderMassstab`,
  `buehnenbreite`, ab 1.0.17, beim Bau der Geste gefunden). `massstabJetzt` gab
  bei eingepasster Ansicht eine feste **0,7** zurück — eine Zahl, die mit dem
  Bild auf dem Schirm nichts zu tun hat. Die Lupen sprangen damit beim ersten
  Tipp aus der eingepassten Ansicht auf 0,56 bzw. 0,875, egal wie groß die
  Seite gerade stand, und die neue Geste hätte denselben Sprung gemacht.
  Gemessen wird die Bühnenbreite über `onChange(of: raum.size.width)` und
  gemerkt in `@State` — **nicht im Körper geschrieben**: Ein `@State`, das
  während des Zeichnens gesetzt wird, löst das nächste Zeichnen aus.
- **Seite 1 ist eine RECHTE Seite** (`Reisewerk.Doppelseite`,
  `Views/DoppelseiteView.swift`, ab 1.0.17, Ansage des Nutzers 09/2026: „Ein
  Buch hat ja Seiten mit Vorder- und Rückseite. Und auf das Titelblatt kommt ja
  zunächst einmal die Innenseite des Hardcovers, bevor die erste wirkliche
  Buchseite anfängt."). Das ist Buchbinderei und keine Geschmacksfrage: Ein
  Recto trägt eine ungerade Nummer. Der erste Bogen zeigt also rechts die
  Seite 1 und links die **Innenseite des Umschlags** — beim Hardcover das
  Vorsatzpapier. Die kommt von der Druckerei, steht in KEINEM PDF und zählt in
  keiner Seitenzahl; gezeigt wird sie trotzdem, denn sonst läge die Seite 1
  links und damit falsch. **Und sie steht mit ihrem Namen da** („Kommt von der
  Druckerei – nicht im PDF"): Eine leere graue Fläche ohne ein Wort hielte man
  für einen Fehler. Am anderen Ende gilt dasselbe — eine fehlende rechte Seite
  kann es nur am Buchende geben, dort liegt die Innenseite des Rückens.
- **Gepaart wird über das GANZE Buch und erst danach nach Tag gefiltert**
  (`sichtbareDoppelseiten`). Andernfalls verschöbe eine Auswahl die Paarung:
  Fängt ein Tag auf einer linken Seite an, stünde er bei einer Paarung
  innerhalb der Auswahl plötzlich rechts — die Doppelseite zeigte dann etwas,
  das im gedruckten Buch nie so aussieht. Gezeigt wird jeder Bogen, auf dem
  eine Seite der Auswahl liegt, **samt der Nachbarseite, auch wenn die zu
  einem anderen Tag gehört**. Genau so liegt das Buch auf dem Tisch.
- **Zwischen zwei gegenüberliegenden Seiten liegt KEIN Abstand** (`spacing: 0`).
  Im gebundenen Buch stoßen sie am Bund aneinander; was dazwischen hell stehen
  bleibt, ist der ANSCHNITT beider Seiten, und wo der endet, zeigt die rote
  Schnittkante (Anordnen → „Satzspiegel zeigen"). Eine Lücke zu zeichnen wäre
  bequemer und behauptete einen Falz, den es nicht gibt.
- **Der Umschalter steht UNTEN neben den Lupen**, nicht in einem Menü: Er
  gehört zur Ansicht, und wer ihn sucht, sucht ihn dort, wo der Maßstab liegt.
  Dieselbe Lehre wie beim Sichtumschalter der Abfahrtstafel (1.0.5) — **ein
  Knopf, den niemand findet, ist kein Knopf.** Die Wahl liegt in
  `@AppStorage` und damit in einer VIEW, nie im `Reisewerk`.
- **Eine ungerade Seitenzahl wird GEZÄHLT und hingeschrieben, nicht geprüft**
  (ab 1.0.17). In der Doppelseitenansicht sieht man, dass der letzte Bogen
  keine Rückseite hat; darunter steht dann, dass viele Druckdienste eine gerade
  Seitenzahl verlangen und dass die Angabe des jeweiligen Anbieters gilt. Was
  ein bestimmter Dienst annimmt, ist hier NICHT gemessen — die Zeile sagt
  deshalb, was sie weiß, und verspricht nichts.
- **Die Automatik läuft — aber die Reisespur setzte keine Seite neu** (behoben
  in 1.0.17, beim Nachrechnen der Frage des Nutzers gefunden: „Was das Programm
  auszeichnen würde, wäre ja, dass automatisch Texte, Bilder und Koordinaten
  bestimmten Tagen zugeordnet werden und diese Seiten automatisch erstellt
  werden. Ich hoffe, dass das so funktioniert."). Zwei der drei Wege riefen
  `alleNeuAnordnen(nurUnberuehrte: true)` — `textVerteilen` und die
  Fotoeinfuhr. `spurUebernehmen` rief dagegen nur `fehlendeSeitenNachholen()`,
  **und das überspringt jeden Tag, dessen Seitenliste schon gefüllt ist.** Der
  Kartenblock entsteht aber erst, wenn der Tag eine Spur HAT
  (`Layoutautomat.seiten`: `tag.karteZeigen && tag.hatSpur`). In der
  Reihenfolge, die der Nutzer beschreibt — erst der Text, dann die Reisespur —
  kam damit auf keiner Seite eine Karte, und zwar STUMM: Die Tage standen da,
  die Punkte standen in der Liste, gesetzt wurde nichts. Dass es beim
  anschließenden Einlesen der FOTOS doch noch aufgefallen wäre, war Zufall.
  **Merke: Wer einen Einleseweg baut, prüft, ob die Seiten danach neu gesetzt
  werden — `fehlendeSeitenNachholen` ist dafür nie die Antwort**, es ist der
  Notnagel für eine leere Liste.
- **Der erste Punkt von Hand bringt die Karte, der letzte nimmt sie weg**
  (`spurGeaendert`, ab 1.0.17). Dieselbe Wurzel, eine Ebene tiefer:
  `punktHinzufuegen` und `punkteLoeschen` änderten die Spur, ohne die Seite neu
  zu setzen. Neu gesetzt wird nur, wenn `hatSpur` UMKIPPT — ein Punkt mehr in
  einer vorhandenen Spur soll die Seite nicht durcheinanderwerfen —, und mit
  `erzwingen: false`, damit die Handarbeit stehen bleibt.
- **Nicht gemessen (1.0.17):** Ob die Zweifingergeste auf einem Gerät flüssig
  ist, ob sie sich mit dem Blättern des `ScrollView` verträgt und ob sie mit
  dem Bildausschnitt wirklich nie kollidiert, ist am Quelltext entschieden und
  nicht auf einem iPad gesehen. **Der Zoom verfolgt den Mittelpunkt der Geste
  NICHT** — der `ScrollView` behält seinen Versatz, es wird also um die obere
  linke Ecke gezoomt; das nicht anders darstellen. Und die Doppelseitenansicht
  ändert am PDF nichts: Der Bundsteg wird seit 1.0.1 ohnehin auf beide Ränder
  gerechnet, die Ansicht zeigt nur, was daraus wird.
- **Buch aufbauen: die Reihenfolge war da, sie stand nur nirgends**
  (`Views/AufbauView.swift`, `Dienste/Aufbaubericht.swift`, ab 1.0.18;
  Befund des Nutzers 09/2026: „Bislang ist die App auf jeder einzelnen Seite
  ja eher ein noch etwas sperrig zu bedienender Bild- und Texteditor … Was
  das Programm auszeichnen würde, wäre ja, dass automatisch Texte, Bilder und
  Koordinaten bestimmten Tagen zugeordnet werden."). Das TUT die App seit
  1.0.0 — der Text legt die Tage an, die Spur hängt je eine Karte daran, die
  Fotos verteilen sich über ihr Aufnahmedatum. Gestanden hat davon nirgends
  etwas: Die drei Wege lagen als drei gleichrangige Punkte in einem Menü,
  und in welcher Reihenfolge sie zusammengehören, wusste nur, wer es gebaut
  hat. **Fünfte Auflage desselben Befundes** („es war da, man fand es
  nicht") — die vier davor waren die Bildunterschrift, das Zurücksetzen, der
  Zweifinger-Zoom und die Foto-Einstellung.
  - **Kein neuer Einleseweg.** Die Arbeit machen unverändert
    `TextimportView`, `SpurimportView` und `FotoeinfuhrView`; dieser
    Bildschirm ist die Reihenfolge, der Stand und der Bericht. Ein zweiter
    Weg zu derselben Sache liefe irgendwann auseinander — dieselbe Regel wie
    bei `Block.wirkung` und bei den Fotostilfeldern aus 1.0.10.
  - **Die Blätter werden NICHT gestapelt.** Jede der drei Einleseansichten
    bringt einen eigenen `NavigationStack` mit, und ein Blatt über einem
    Blatt ist auf dem iPad ein Kärtchen auf einem Kärtchen. Stattdessen macht
    der Aufbau zu, die WURZEL öffnet das nächste Blatt im `onDismiss`, und
    wenn das zugeht, kommt der Aufbau zurück — dort steht dann, was daraus
    geworden ist. Dieselbe Regel wie bei den Dateiwählern in Tafelbild: Der
    Wunsch trägt das Ziel (`alsNaechstes`), kein Schalter daneben.
  - **Der Bericht zählt, er behauptet nicht.** Je Tag Zeichen, Fotos, Orte
    (davon aus der Tagesspur) und Seiten, dazu, was fehlt; darunter die
    Fotos in der Ablage, ohne Datum und ohne Ort. Kopierbar — dieselbe
    Bauweise wie „Zustellung prüfen" bei Schulalarm. **Ein Tag ohne Foto ist
    kein Fehler**, deshalb steht das Fehlende orange und nicht rot; es steht
    aber da, sonst bemerkt es niemand.
  - **Gerechnet wird beim Öffnen, nicht im Körper** (`.task`). Der Bericht
    geht über alle Tage und alle Fotos — dieselbe Falle wie bei der
    Druckprüfung in 1.0.0.
  - **Die drei Einzelwege bleiben stehen.** Wer weiß, was er will, soll nicht
    durch einen Ablauf laufen müssen.
- **Der Zoom geschieht um den Mittelpunkt der Geste** (`Model/Zoomanker.swift`,
  ab 1.0.18, Ansage des Nutzers 09/2026). 1.0.17 hatte es als offenen Punkt
  aufgeschrieben: Der `ScrollView` behält seinen Versatz, während der Inhalt
  wächst — gezoomt wurde also um die obere linke Ecke.
  - **Ein SwiftUI-`ScrollView` hat unter iOS 17 keinen Versatz zum SETZEN.**
    `scrollPosition(id:)` zeigt auf eine Ansicht, `scrollTo(point:)` gibt es
    erst ab iOS 18. Der einzige Hebel ist
    `ScrollViewProxy.scrollTo(_:anchor:)` — und der legt den Punkt `a` eines
    ELEMENTS auf den Punkt `a` des Sichtfelds. `Zoomanker` löst diese
    Gleichung nach `a` auf. **Den `ScrollView` durch eine eigene Schiebe- und
    Zoomfläche zu ersetzen wäre der naheliegende Weg und der teurere**: Daran
    hängen das Blättern, die Faulheit des `LazyVStack` aus 1.0.16 und die
    Ziehgesten der Blöcke, für die 1.0.5 bis 1.0.8 gebraucht wurden.
  - **Zwei Hälften, und nur eine rechnet.** Solange die Finger auf dem Glas
    sind, skaliert ein `scaleEffect` mit Anker — das ist eine Abbildung und
    kann gar nicht danebenliegen, und die Seiten werden dabei nicht bei jedem
    Bildpunkt neu gesetzt. Erst am Ende wird der Maßstab gesetzt und EINMAL
    gerollt.
  - **Der Anteil gilt für das BLATT, nicht für das Element.** Die
    Beschriftungszeile darunter wächst beim Zoomen nicht mit; ein Anteil über
    beides zusammen ginge daneben. Damit die Rechnung nicht schätzt, hat die
    Zeile eine FESTE Höhe (`Buehnenmasse`), und Fuge, Rand und
    Beschriftungshöhe stehen an EINER Stelle — wer sie in der Ansicht ändert
    und dort nicht, zoomt wieder auf einen Punkt, auf den niemand gezeigt hat.
  - **Wo der Inhalt steht, wird in eine KLASSE geschrieben** (`Inhaltslage`),
    nicht in `@State` und nicht über eine Preference. Der Wert ändert sich bei
    jedem Bildpunkt des Scrollens; ein Zustand an dieser Stelle zeichnete die
    Bühne sechzigmal in der Sekunde neu — genau das, was 1.0.16 abgestellt
    hat. Dieselbe Bauweise wie beim `Zeichenmesser`, der aus demselben Grund
    kein `@Published` hat. Gelesen wird nur im Augenblick einer Geste.
  - **Die Lupen zoomen auf die MITTE des Sichtfelds**, über denselben Weg.
    Ihr Wunsch reist über `lupenwunsch` durch den Zustand, weil der
    `ScrollViewProxy` nur innerhalb des `ScrollViewReader`s gilt und die
    Knöpfe in der Werkzeugleiste stehen; ihn außerhalb zu merken wäre der
    naheliegende Weg und einer, den SwiftUI nicht zusagt.
  - **Am Rand hält der Brennpunkt nicht** — weiter als bis zum Anfang und
    zum Ende rollt kein `ScrollView`. Das ist richtig so und kein Fehler.
  - **Nicht gemessen:** Ob der Punkt auf einem Gerät wirklich stehen bleibt,
    hat niemand gesehen. Gerechnet ist die Geometrie; ungeprüft sind die
    beiden Annahmen darunter — dass `MagnifyGesture.Value.startLocation` im
    Raum des Inhalts gemeldet wird und dass `scrollTo` mit einem Anker
    außerhalb der Mitte tut, was die Dokumentation sagt. Und beim Übergang
    von der Skalierung auf den gesetzten Maßstab kann ein Bild lang ein
    Sprung stehen: Gerollt wird einen Durchgang später, weil `scrollTo` die
    Größe braucht, die das Element dann erst hat. **Nicht als erledigt
    darstellen.**
- **Eine Uhrzeit ist die WANDUHR am Ort, nie ein Augenblick auf der Weltuhr**
  (`Dienste/Ortszeit.swift`, ab 1.0.19, Ansage des Nutzers 09/2026: Die Zeiten
  „müssten dann angepasst werden gemäß der Zeitzone des Ortes, also in
  Deutschland der mitteleuropäischen Sommerzeit und für Kanada die Sommerzeit
  in Toronto."). Das ist dieselbe Regel wie beim TAG, der aus drei Zahlen
  kommt — sie galt bisher nur für die eine Hälfte der Daten.
  - **Ein Foto hält sich von selbst daran.** Im EXIF steht „19:33:21" ohne
    jede Zone; `Bildbefund` legt genau diese Ziffern mit einer FESTEN Zone ab,
    und `SpurView` wie `BlockInspektor` zeichnen mit derselben. Auf dem
    Bildschirm steht damit, was die Kamera angezeigt hat.
  - **Die Reisespur hielt sich NICHT daran.** Tagesspur-Sicherung und GPX
    schreiben echte Augenblicke (`2026-07-25T18:14:03Z`), und die landeten
    unverändert in demselben Feld. Gezeichnet mit derselben festen Zone hieß
    das: UTC. In einer Liste standen damit Fotopunkte richtig und Spurpunkte
    falsch — in Toronto um vier Stunden, in Deutschland um zwei. **Ein Feld
    mit zwei Bedeutungen läuft auseinander**, und hier war es schon
    auseinandergelaufen, nebeneinander in derselben Zeile.
  - **Umgerechnet wird beim EINLESEN, nicht beim Zeichnen**
    (`Spureinfuhr.ortszeitenSetzen`). Danach bedeutet `Reisepunkt.zeit`
    überall dasselbe. Der Versatz wird für den jeweiligen Augenblick erfragt
    (`zone.secondsFromGMT(for:)`) und nicht als fester Wert der Zone: Eine
    Reise über den Oktober hinweg läge sonst an einem Ende falsch.
  - **Welche Zone gilt, wird je TAG nachgeschlagen** (`Zonensucher`,
    `CLPlacemark.timeZone` am ersten Ort des Tages). Je Punkt wären es
    Tausende Anfragen, je Datei wäre es falsch — der Nutzer nennt Deutschland
    und Toronto in einem Satz. **Eine eigene Tabelle wäre geraten**: iOS
    bringt keine mit, und Zonengrenzen folgen Staats- und Provinzgrenzen,
    nicht Längengraden. Gemerkt wird auf einem Viertelgrad-Gitter, und ein
    `actor` hält die Anfragen auseinander — `CLGeocoder` nimmt immer nur eine
    gleichzeitig und weist die zweite ab.
  - **Ohne Netz wird nichts behauptet.** Dann gilt die im Blatt eingestellte
    Zone, und die Vorschau sagt je Tag, welche es war — nachgeschlagen steht
    grau da, angenommen orange und mit dem Wort „angenommen". Dieselbe Regel
    wie beim Wort „Plan" an einer Abfahrt ohne Echtzeit.
  - **Der TAG wird dabei NICHT neu gerechnet.** Wo ein `dayKey` in der Datei
    stand, ist er der Tag, den der Mensch erlebt hat; dass eine umgerechnete
    Uhrzeit über Mitternacht rutscht, ändert daran nichts. Wo der Tag
    gerechnet werden muss (fremdes GPX), gilt weiter die eingestellte Zone —
    sonst müsste erst gruppiert werden, um die Zone zu finden, und die Zone
    bestimmte die Gruppierung.
  - **`Reisetag.zeitzone` ist eine AUSKUNFT, keine Rechenvorschrift.** Die
    Uhrzeiten sind schon umgerechnet; das Feld sagt nur, worauf sie sich
    beziehen, und steht unter den Reisepunkten und im Aufbaubericht. Wer damit
    noch einmal umrechnet, rechnet zweimal.
  - **Schon eingelesene Tage bleiben, wie sie sind.** Aus welcher Zone sie
    kamen, weiß die App nicht mehr; eine Wanderung um vier Stunden zu
    verschieben, weil es plausibel aussieht, wäre geraten. Wer sie berichtigen
    will, liest die Datei noch einmal ein — das ersetzt die Spurpunkte des
    Tages (die Regel steht seit 1.0.4 dort).
  - **Nicht gemessen:** Ob `CLPlacemark.timeZone` für die Orte dieser Reise
    etwas hergibt, hat niemand gesehen — hier gibt es weder Netz zu Apples
    Geocoder noch eine echte Sicherung. Gerechnet ist die Umrechnung und der
    Weg drumherum; ob die Zonen ankommen, sagt die Zeile „Nachgeschlagen: n
    von m Tagen" im Einlesen-Blatt. **Nicht als erledigt darstellen.**
- **Ein Reisepunkt lässt sich ÄNDERN, nicht nur setzen und wegwischen**
  (`PunktwahlView` mit `punktID`, `Reisewerk.punktAendern`, ab 1.0.20, Ansage
  des Nutzers 09/2026: „Ich möchte sie löschen, örtlich und zeitlich verändern
  können.").
  - **Ein Bildschirm für beides.** Ein eigener Editor neben der Punktwahl wäre
    ein zweiter Weg zu derselben Sache — dieselbe Regel wie bei den
    Fotostilfeldern (1.0.10) und bei `Block.wirkung`.
  - **Der TIPP auf die Karte setzt die Stelle** (ausdrücklich gewünscht). Bis
    1.0.19 stand hier die Regel, ein Tipp sei schlechter als ein Fadenkreuz,
    weil der Finger die Stelle verdeckt. Beides gilt: Der Tipp rückt die
    Stelle unter das FADENKREUZ, statt sie blind zu übernehmen — man sieht
    hinterher, wo sie gelandet ist, und schiebt die Karte nach. Der Maßstab
    bleibt dabei (`spanne`), sonst spränge er bei jedem Tipp zurück.
  - **Die Uhrzeit wird GETIPPT, nicht gedreht** (ebenfalls ausdrücklich).
    Angenommen wird alles Eindeutige — „9:05", „0905", „9.05", „9" —, und was
    keine Uhrzeit ist, sperrt den Knopf mit einem Satz daneben. Der
    `DatePicker` ist damit weg; zwei Wege wären einer zu viel.
  - **Eine geänderte Uhrzeit sortiert den Punkt NEU ein.** Die Reihenfolge der
    Liste ist die Reihenfolge der gezeichneten Linie; ein Punkt von 8 Uhr
    hinter einem von 17 Uhr ergäbe einen Weg, den niemand gefahren ist. Punkte
    OHNE Uhrzeit bleiben, wo sie sind — wohin sie gehören, weiß auch die App
    nicht (die Regel steht seit 1.0.0 dort).
  - **`starten()` läuft nur EINMAL** (`geladen`). `.task` läuft nach einer
    Rückkehr aus dem Hintergrund noch einmal, und dann stünde die gerade
    verschobene Karte wieder am Anfang.
- **Das App-Symbol ist eine FARBE und eine FORM** (`scripts/make-icon.py`, ab
  1.0.20, Befund des Nutzers 09/2026: „Das Programm-Icon sieht von Weitem aus
  wie eine weiße Fläche mit einem Rand drumherum."). Er hat recht, und der
  Grund ist am alten Entwurf abzulesen: ein aufgeschlagenes Buch in
  Papierweiß über drei Vierteln der Fläche, auf dunklem Grund. Aus zehn
  Zentimetern sah man ein Buch; auf einem Homescreen misst ein Symbol vierzig
  Bildpunkte, und dann bleiben von Papier, Falz und Lineatur eine helle
  Fläche und ein dunkler Saum. **Bei dieser Größe trägt ein Symbol eine Farbe
  und eine Form** — so machen es die Apps mit derselben Aufgabe (Polarsteps
  eine Route, Karten eine Nadel, Books ein weißes Zeichen auf kräftigem
  Verlauf). Jetzt: ein Weg mit Anfang und Ziel, weiß auf einem diagonalen
  Verlauf von Abendsonne nach Tiefrot. **Die Kontur unter dem Weiß ist keine
  Zierde** — der Verlauf ist oben links deutlich heller, und ohne sie verlöre
  die Linie dort ihren Halt (dieselbe Überlegung wie bei den Linienzügen der
  Abfahrtstafel). Der Verlauf läuft DIAGONAL: ein senkrechter sieht wie ein
  Farbfeld aus, ein diagonaler hat eine Richtung. Alles bleibt zwischen 140
  und 884 — was näher an der Ecke liegt, schneidet iOS mit seiner Maske weg.
- **Vier Orte, vier Fragen — die Menüs** (ab 1.0.20, Befund des Nutzers
  09/2026: „Ich finde, dass viele Funktionen nicht selbsterklärend in
  verschachtelten Menüs abgelegt wurden."). Bis 1.0.19 standen oben drei
  gleich aussehende Menüs („Einlesen", „Anordnen", „Buch"), und wo etwas lag,
  ergab sich aus der Geschichte und nicht aus der Sache: der Satzspiegel (eine
  Ansichtssache) unter „Anordnen", das PDF (eine Ausgabe) unter „Buch" neben
  der Stilwahl, und die Sachen DIESES Tages verteilt auf zwei Menüs und die
  Fußleiste.
  - `+` — **was ins Buch hineinkommt** (Buch aufbauen, Text, Fotos, Dateien,
    Spur, Ablage samt Zahl).
  - Pinsel — **wie das Buch aussieht** (Stil, Schrift, Fotos, Textfelder,
    Hintergrund, Format).
  - `…` — **alles Seltene**: ausgeben, alle Tage neu anordnen, Hilfen beim
    Anordnen (Satzspiegel, Einrasten), Prüfen.
  - Unten rechts, mit dem DATUM beschriftet — **alles zu diesem Tag**: Text
    und Fotos, Reisepunkte, neu anordnen, Seitenmuster, Seite anfügen.
  - **Nichts steht an zwei Stellen.** Wer eine Funktion hinzufügt, sucht
    zuerst die Frage, die sie beantwortet.
  - „Zurück" heißt jetzt **„Widerrufen"**: Es stand direkt neben einem
    Zurück-Pfeil, der das Buch schließt (jetzt „Bücher"). Zwei Dinge mit
    demselben Wort sind eines zu viel.
  - **Die Plus-Minus-Lupen sind ersatzlos weg** (Ansage des Nutzers: keine
    doppelten Funktionen). Stufenweises Zoomen können zwei Finger besser; was
    sie NICHT können, ist ein bestimmter Maßstab. Geblieben ist EIN Knopf, der
    den Maßstab **nennt** („68 %") und „Einpassen" bzw. 100 % setzt — die
    Beschriftung ist zugleich die Auskunft.
  - **Die Fußleiste steht INLINE in der `ToolbarItemGroup`.** Eine Gruppe
    verteilt ihre Kinder auf eigene Plätze; ein einzelner weitergereichter
    Ausdruck ist für sie EIN Kind.
- **Das Blatt braucht einen Schatten, der nicht mitschrumpft** (ab 1.0.20).
  Er stand vor dem `scaleEffect` und wurde mitskaliert: Bei eingepasster
  Ansicht (rund 0,4) blieben von neun Punkten dreieinhalb — die Seite lag
  flach auf dem Grund, statt als Blatt darauf zu liegen. Jetzt liegt er
  außerhalb und ist in BILDSCHIRMpunkten gerechnet, also auf jedem Maßstab
  derselbe (dieselbe Überlegung wie bei den Säumen der Werkzeugleiste in
  Tafelbild).
- **Die Leinwand ist ein Mittelton, kein Fast-Weiß** (`ReiseView.leinwand`, ab
  1.0.20). `systemGroupedBackground` ist sehr hell, und darauf ist ein weißes
  Blatt kaum ein Blatt. So macht es keine App, die Seiten zeigt: Pages und
  Keynote stellen das Papier auf einen deutlich dunkleren Grund, Books auf
  einen ganz dunklen. Das ist kein Geschmack — **nur vor einem neutralen
  Mittelton lässt sich beurteilen, wie hell ein Foto auf dem Papier wirklich
  steht.**
- **Ein Bild sagt, welcher Tag das war** (`TagListeView`, ab 1.0.20). Ein
  Datum in einer Liste sagt nichts; das erste Foto des Tages sofort. Dieselbe
  Bauweise wie in Fotos und Books. Gibt es keines, bleibt der Platz stehen,
  damit die Zeilen nicht unterschiedlich weit eingerückt sind. Im Regal steht
  seither das **Titelfoto** und nicht mehr das erste Foto der Reise (zwei
  Bücher mit demselben Anreisetag sahen sonst gleich aus), hochkant wie ein
  Buchrücken.
- **Nicht gemessen (1.0.20):** Ob die neue Aufteilung sich besser bedienen
  lässt, sagt erst der nächste Befund — geändert sind Wege und Namen, und das
  ist keine Messung (dieselbe Einschränkung wie bei 1.0.10). Ebenso ungesehen:
  wie das Symbol auf einem Homescreen wirkt, ob der Tipp auf die Karte den
  richtigen Punkt trifft und ob der Schatten auf einem Gerät nicht zu schwer
  ist. **Nicht als erledigt darstellen.**
- **Mehrere Zeitstempel auf einmal verschieben** (`Views/Zeitverschiebung.swift`,
  `Reisewerk.zeitenVerschieben`, ab 1.0.21, Ansage des Nutzers 09/2026:
  „mehrere von ihnen auswählen zu können und ihren Zeitstempel gemeinsam
  verschieben zu können, beispielsweise um drei Stunden nach hinten."). Der
  Fall dahinter ist der Regelfall auf einer Reise: eine Kamera, deren Uhr auf
  der Zeit von zu Hause stand, oder eine Spur aus einer fremden App ohne
  Zonenangabe.
  - **Der Auswahlmodus ist SICHTBAR**: Die Überschrift zählt mit („4 von 37
    gewählt"), der Knopf heißt „Fertig", und vor jeder Zeile steht ein Kreis
    statt eines Pfeils. Ein Modus, den man nicht sieht, darf die Bedeutung
    eines Tipps nicht ändern — dieselbe Regel wie beim Fußwegmesser der
    Abfahrtstafel.
  - **Ordnen und Auswählen gibt es nicht gleichzeitig.** Der `EditButton`
    verschwindet im Auswahlmodus; sonst hätte ein Tipp auf eine Zeile drei
    Bedeutungen (öffnen, auswählen, anfassen).
  - **Das Blatt rechnet VOR, statt zu versprechen**: Zahl der Gewählten, Zahl
    der Punkte ohne Uhrzeit (an denen sich nichts verschieben lässt) und der
    erste Punkt mit alter und neuer Zeit. Wer „drei Stunden nach hinten" liest,
    hat noch nicht geprüft, ob es die richtige Richtung ist. Dieselbe Bauweise
    wie bei jeder Einfuhr dieser App: erst zeigen, dann übernehmen.
  - **Verschoben wird die WANDUHR am Ort** — dieselbe, die in der Liste steht
    (siehe `Dienste/Ortszeit.swift`); addiert werden schlicht Sekunden. Punkte,
    die dabei über Mitternacht rutschen, **bleiben an diesem Tag**: Der Tag ist
    der, den der Mensch erlebt hat, und nicht das Ergebnis einer Rechnung.
  - **Danach wird STABIL neu nach Zeit geordnet** (`nachZeitGeordnet`). `sorted`
    ist in Swift nicht als stabil zugesichert; ohne den Index als zweites
    Merkmal stünden zwei Punkte derselben Minute nach jedem Verschieben anders.
    Punkte ohne Uhrzeit behalten ihre Reihenfolge am Ende.
  - **Was nicht verschoben wurde, steht in der Meldung.** Eine stillschweigend
    übergangene Auswahl sieht aus wie ein Fehler.
- **Ein HÖCHSTMASS macht einen Inhalt nie breiter** (`ReiseView.inhaltsbreite`,
  ab 1.0.22; gemeldet 09/2026: „Die Seite kann leider nicht verschoben werden.
  Wenn ich sie zoome, dann springt sie immer in irgendeine offenbar
  vorgerasterte Position. Diese ist aber selten die, mit der ich dann an der
  Stelle gerne weiterarbeiten würde."). Der Inhalt der Bühne trug
  `.frame(maxWidth: .infinity)`. In einem SENKRECHTEN `ScrollView` ist das der
  übliche Griff — dort bietet die Rolle ihre eigene Breite an, das Höchstmaß
  setzt sie ein, und der Inhalt steht mittig. Diese Bühne rollt aber in BEIDE
  Richtungen, und dort ist es der falsche Griff: **Ein Höchstmaß kann einen
  Inhalt niemals BREITER machen als das, was ihm angeboten wird**, und wie
  breit ein `ScrollView` seinen Inhalt auf einer ROLLACHSE anbietet, steht
  nirgends verbindlich. Genau daran hing, ob sich eine herangezoomte Seite
  quer schieben lässt. Gesetzt wird jetzt eine AUSGERECHNETE Breite:
  mindestens das Sichtfeld (sonst ließe sich ein schmales Blatt nicht
  zentrieren) und mindestens das Blatt samt seinen beiden Rändern (sonst gäbe
  es nichts zu schieben, wo es etwas zu schieben gibt). Beide Zahlen sind
  bekannt — die eine gemessen, die andere Bogenbreite mal Maßstab. **Damit
  hängt das Schieben an keiner Zusage mehr, die niemand nachlesen kann.**
- **Und der Kommentar daneben behauptete das Gegenteil.** Über
  `Zoomanker.griff` stand seit 1.0.18: „Der Inhalt ist mindestens so breit wie
  das Sichtfeld (`maxWidth: .infinity`)" — ein Höchstmaß als Beleg für ein
  Mindestmaß, in einer Klammer, in der die Prüfung hätte stehen müssen.
  Dieselbe Wurzel wie bei Schulalarms `requestAuthorization` und den
  Navigationszielen der Abfahrtstafel: **Ein Kommentar ersetzt keine Prüfung.**
  Die Zeile nennt jetzt `ReiseView.inhaltsbreite`, also die Stelle, an der das
  Mindestmaß wirklich gesetzt wird.
- **Ein `DispatchQueue.main.async` aus einem Gestenrückruf ist NICHT „nach dem
  nächsten Durchgang"** (behoben in 1.0.22). `zoomAuf` setzte `zoom = neu` und
  rollte im selben Atemzug asynchron hinterher, mit dem Kommentar „erst stehen
  lassen, dann rollen". Eine Zustandsänderung löst aber einen Durchgang von
  SwiftUI aus, und ein Block in der Hauptschlange kann davor laufen: Dann
  rechnet `scrollTo` mit der ALTEN Größe des Elements und rollt an eine
  Stelle, die mit dem neuen Maßstab nichts zu tun hat. Genau so sieht
  „springt in irgendeine Position" aus. Der Wunsch reist deshalb durch den
  Zustand (`rollwunsch`) und wird in `onChange` eingelöst — das läuft
  garantiert nach dem Durchgang, der ihn gesetzt hat. **Die laufende Nummer im
  Wunsch gehört dazu**: `onChange` meldet sich nur bei einer Änderung, und
  zweimal derselbe Anker hintereinander wäre keine.
- **Geklemmt heißt „geht hier nicht", nicht „ist falsch gerechnet"**
  (`Zoomanker.Ankerbefund`, ab 1.0.22). `teil` klemmte den Anker stumm auf 0
  bis 1. Ein roher Wert außerhalb davon heißt aber etwas Bestimmtes: Der
  Brennpunkt ist an dieser Stelle GAR NICHT zu halten — weiter als bis zum
  Rand rollt kein `ScrollView`, und am Anfang und Ende der Liste ist das der
  Normalfall. Geklemmt sieht genau das aus wie eine Handvoll fester
  Stellungen, in die die Seite nach jedem Zoomen springt. Geklemmt wird jetzt
  erst beim Bauen des `UnitPoint`, und der Befund trägt beide Zahlen.
- **Die Probe nennt seither den FREIEN WEG** („Bedienung prüfen", darunter
  „Befund kopieren"). Sichtfeld, Inhalt, Versatz, Maßstab, Blattbreite, Griff,
  Brennpunkt, Anker roh und geklemmt — und `frei ⇄`/`↕`, also Inhalt minus
  Sichtfeld. **Ist diese Zahl waagerecht null, gibt es nichts zu schieben, und
  jede weitere Erklärung erübrigt sich.** Die jetzige Lage wird erst beim
  Tippen auf „Befund kopieren" gelesen und nirgends laufend mitgeschrieben —
  `Inhaltslage` ist aus demselben Grund eine schlichte Klasse und kein
  `@State` (die Lehre aus 1.0.16).
- **Nicht gemessen (1.0.22), und es ist die dritte Erklärung für diese Bühne.**
  Abgezählt ist die Geometrie: dass ein Höchstmaß die Breite nicht wachsen
  lässt, und dass der asynchrone Block vor dem Durchgang liegen kann.
  **Gesehen hat es niemand** — ob sich die Seite auf dem iPad jetzt schieben
  lässt und ob der Brennpunkt beim Zoomen steht, sagt erst der nächste Befund.
  1.0.18 hatte beides schon als offen aufgeschrieben („dass `scrollTo` mit
  einem Anker außerhalb der Mitte tut, was die Dokumentation sagt"), und diese
  Fassung prüft davon nichts nach; sie stellt zwei Dinge ab, die unabhängig
  davon falsch waren, und gibt der nächsten Meldung Zahlen mit. **Nicht als
  erledigt darstellen.**
- **Die Geste braucht FLÄCHE — und der Befund hat es gesagt** (ab 1.0.23;
  gemeldet 09/2026: „Beim Zoomen springt die Seite irgendwo hin. Da hat sich
  nichts geändert. Ich habe sie jetzt klein gezoomt und kann sie nicht wieder
  größer bekommen.", dazu der kopierte Befund). **Zum ersten Mal in dieser
  Sache entscheidet eine Messung und keine Überlegung**, und sie steht in zwei
  Zahlen derselben Zeile: `Inhalt 1046×429 · Bühne 1046×864`. Die
  Zweifingergeste hängt am INHALT. Bei 25 % deckte der die oberen 429 von 864
  Punkten ab; darunter lag nackte Leinwand OHNE Geste. Wer in der Mitte des
  Bildschirms aufzieht, greift also ins Leere — **und die Falle zieht sich zu,
  je kleiner man zoomt**: genau der gemeldete Zustand. Der Inhalt ist seither
  mindestens so hoch wie das Sichtfeld. **Oben ausgerichtet, nicht mittig** —
  die Lagen der Elemente gehen in `Zoomanker` ein, und eine senkrechte
  Zentrierung verschöbe jede davon. Die Breite konnte 1.0.22 exakt setzen
  (`.frame(width:)`); die Höhe wird als MINDESTMASS gesetzt, denn unter der
  Bogenliste kann noch ein Hinweis stehen, und eine feste Höhe schnitte ihn ab.
- **Eine glatte 1,00 in einem Anteil heißt „geklemmt", nicht „unten"**
  (`Zoomanker.Griff.imBlatt`, ab 1.0.23). Derselbe Befund nannte
  `Griff #1 quer 0.50 hoch 1.00` — der Finger lag an der Unterkante des
  Inhalts, also NEBEN dem Blatt. Daraus wurde trotzdem ein Anker gerechnet,
  und der legte die Blattunterkante unter den Finger: der Sprung „irgendwo
  hin". Wo kein Blatt unter dem Finger ist, gibt es keinen Brennpunkt zu
  halten — dann wird gar nicht mehr gerollt, und die Rolle bleibt stehen, wo
  sie steht. **Es ist dieselbe Ursache wie beim Punkt darüber**, von der
  anderen Seite gesehen: Beide Symptome kommen daher, dass die Geste dort
  ankam, wo kein Inhalt war.
- **Eine Probe, die ihre eigene Zahl verzerrt, ist schlimmer als keine**
  (ab 1.0.23, zwei Berichtigungen, beide am ersten echten Befund aufgefallen):
  - `Inhalt 570×423` stand über einem Rahmen, der 1046 breit gesetzt war.
    `Inhaltslage` wird durch den `scaleEffect` HINDURCH gemessen, und am ENDE
    einer Geste steht dort die skalierte Größe (570/1046 ist ungefähr der
    Zoomfaktor jener Geste). Beim AUFSETZEN ist `lupe` noch 1, also stimmt sie
    dort — seither wird sie dort gemerkt.
  - `Blatt 990 pt` war `inhaltsbreite` minus Ränder, bei einer kleinen Seite
    also die BÜHNE und nicht das Blatt. Gerechnet wird jetzt Bogenbreite mal
    Maßstab (`blattbreite(bei:)`).
  **Wer eine Probe baut, prüft, ob sie misst, was ihre Beschriftung sagt.**
- **Was der Befund AUSGESCHLOSSEN hat, zählt auch.** Die Breite stimmte
  („Inhalt 1046", genau die gesetzte `inhaltsbreite`) — der Umbau von 1.0.22
  wirkt also. Und `frei ⇄0 ↕-435` sagt, dass bei kleiner Seite gar nichts zu
  schieben ist; das ist richtig so und war nie der Fehler. **Erst diese
  Zahlen haben die Frage von „warum springt es" auf „wo kommt die Geste
  überhaupt an" gedreht** — nach drei Erklärungen, die alle am Quelltext
  abgezählt und keine gemessen waren.
- **Nicht gemessen (1.0.23):** Ob sich die Seite jetzt überall aufziehen lässt
  und ob der Brennpunkt steht, sagt erst der nächste Befund. Gemessen ist,
  WARUM die Geste nicht ankam; dass sie es jetzt tut, folgt aus der Geometrie
  und ist nicht gesehen. **Nicht als erledigt darstellen.** Der Weg zurück aus
  einer zu kleinen Seite liegt daneben und hängt an keiner Geste: der Knopf
  mit der Prozentzahl unten links → „Einpassen".
- **Wer nicht rollt, springt in die linke obere Ecke** (ab 1.0.24, gemeldet
  09/2026: „Wenn ich das tue, dann wird die Zoom-Geste korrekt ausgeführt.
  Lasse ich allerdings die beiden Finger los, dann springt das Bild wieder auf
  die linke obere Ecke."). **Der Befund sagt selbst, wo es liegt:** Während der
  Geste skaliert ein `scaleEffect` um den Punkt zwischen den Fingern — das ist
  eine Abbildung und kann gar nicht danebenliegen; erst beim Loslassen wird
  gerechnet. Also liegt es am Loslassen. Und dort stand seit 1.0.23 ein
  `guard griff.imBlatt`: Lag der Mittelpunkt der Finger nicht auf dem Blatt,
  wurde GAR NICHT gerollt — dann behält die Rolle ihren Versatz, während der
  Inhalt um den Faktor der Geste WÄCHST, und man sieht einen Punkt, der um
  genau diesen Faktor näher am Ursprung liegt. Das IST der Sprung in die Ecke,
  also der Zustand von vor 1.0.18. Gerollt wird jetzt immer; `imBlatt` ist nur
  noch eine Auskunft für die Probe.
- **Der Brennpunkt ist ein Punkt IM INHALT, das Blatt nur das Maß dafür**
  (ab 1.0.24). Aus demselben Grund werden die beiden Griffanteile nicht mehr
  auf 0 bis 1 geklemmt: `hoch = 1,05` heißt „eine Blatthöhe und fünf Prozent
  unter der Oberkante" und rechnet sich genauso wie 0,5. Geklemmt werden darf
  erst der fertige `UnitPoint`, denn DER kann nichts anderes ausdrücken.
- **Ein geklemmter Anker wird über den NACHBARN ausgedrückt**
  (`Zoomanker.rollziel`, ab 1.0.24). Ein Anker trägt nur Werte von 0 bis 1 und
  damit nur Elementkanten zwischen 0 und `Sichtfeld − Element`; im Befund des
  Nutzers stand `Anker … 0.76 (geklemmt)`. Die Reichweite lässt sich aber ohne
  jede Annahme vergrößern, **weil alle Elemente gleich hoch sind und im selben
  Abstand stehen**: Die Kante von Element `k` liegt um `(k − Index) · Schritt`
  unter der des gegriffenen, also rollt man das Nachbarelement an den
  passenden Anker und das gegriffene steht, wo es stehen soll. Gesucht wird
  das Element mit dem geringsten Überstand; passt der eigene Anker schon,
  ändert sich nichts. Reine Geometrie, keine Vermutung.
- **Seit 1.0.24 wird die WIRKUNG gemessen und nicht gefolgert** (`sollversatz`,
  Zeile `Soll … Ist … Abweichung`). Seit 1.0.18 steht hier, dass ungeprüft
  ist, ob `scrollTo` einen Anker außerhalb der Mitte einlöst — drei Fassungen
  lang wurde gerechnet und die Wirkung nicht nachgesehen. `Soll` ist der
  Versatz, den der Inhalt danach haben MÜSSTE, `Ist` der, den er 0,4 s später
  WIRKLICH hat. Stimmen sie überein, liegt ein verbleibender Fehler nicht an
  dieser Rechnung. **Wer eine Geometrie baut, baut die Gegenprobe mit.**
- **„Lässt sich nicht schieben" wird GEZÄHLT, nicht erklärt**
  (`Inhaltslage.spanne`, ab 1.0.24, zum zweiten Mal gemeldet). Ein `ScrollView`
  rollt oder rollt nicht, und am Quelltext sieht man es nicht. Gezählt wird
  deshalb, wie weit der Ursprung des Inhalts seit dem Öffnen überhaupt
  gewandert ist — bleibt die Spanne null, während jemand schiebt, rollt die
  Bühne nicht; wächst sie, ist die Frage eine andere. Gezählt wird in einer
  schlichten Klasse OHNE `@Published`, aus demselben Grund wie beim
  `Zeichenmesser`: Ein Zustand, der bei jedem Bildpunkt geschrieben wird,
  zeichnet die Bühne sechzigmal in der Sekunde neu.
- **Die Vermutung zum Schieben ist AUFGESCHRIEBEN und nicht ausprobiert**
  (1.0.24). Naheliegend ist, dass die Zweifingergeste einen Zweifinger-Wisch
  verschluckt — also genau die Bewegung, die nach einem Aufziehen am nächsten
  liegt; zu ändern wäre das mit `simultaneousGesture`, wie es
  `SeitenflaecheView` beim Bildausschnitt tut. Bewusst NICHT in derselben
  Fassung: Hier ändert sich gerade, wohin nach dem Zoomen gerollt wird, und
  wer zwei Dinge auf einmal ändert, kann den nächsten Befund nicht mehr
  zuordnen.
- **Nicht gemessen (1.0.24):** Ob der Brennpunkt jetzt steht, hat niemand
  gesehen; gerechnet ist nur, warum er in 1.0.23 nicht stand. Ob sich die
  Arbeitsfläche schieben lässt, ist weiterhin ungeklärt — neu ist allein,
  dass es sich ablesen lässt. **Nicht als erledigt darstellen.**
- **Die Rechnung stimmte — und wurde HINTERHER überschrieben** (ab 1.0.25,
  zum wiederholten Mal gemeldet 09/2026: „Sobald ich aber loslasse, ist wieder
  die linke obere Ecke im Fokus."). **Die Probe aus 1.0.24 hat entschieden, und
  sie entlastet die Geometrie vollständig:** `Soll −588/−1411 ·
  Ist −588/−1411 · Abweichung 0/−0`. `scrollTo` löst einen Anker außerhalb der
  Mitte also ein, auf den Punkt — die Frage, die seit 1.0.18 offen stand, ist
  damit beantwortet. **Nachgerechnet am Bildschirmfoto desselben Augenblicks**
  (Ballonfoto bei 69 % der Blattbreite, auf dem Schirm bei 937 pt, Blattbreite
  1606 pt am Bild nachgemessen) stand der Inhalt dort aber bei rund
  −201/−1139. **Der Versatz wird nach der Messung wieder zurechtgerückt**, in
  Richtung Ursprung. Damit heißt die Frage nicht mehr „wie rechnet man den
  Anker", sondern „wer verstellt ihn hinterher".
- **Wo etwas den Versatz später verstellt, hilft eine REGELUNG und keine
  bessere Formel** (`ReiseView.nachfuehren`, ab 1.0.25): rollen, nachsehen,
  und wenn es nicht steht, noch einmal rollen — nach 0,05 / 0,12 / 0,25 / 0,4 /
  0,7 Sekunden. Abbruch, sobald der Versatz auf einen Bildpunkt sitzt, und
  sofort beim Aufsetzen der nächsten Geste: **Wer die Finger auf dem Glas hat,
  führt** — eine laufende Nachführung zöge ihm die Seite weg. Die Zahl der
  Korrekturen steht in der Probe; geschrieben wird sie EINMAL am Ende und nicht
  bei jedem Takt, denn jede Zuweisung an `werk.letzteBuehne` zeichnet die Bühne
  neu (die Lehre aus 1.0.16) — mitten in einer Regelung wäre das genau die
  Unruhe, gegen die sie gebaut ist.
- **Ein `LazyVStack` weiß nur, wie hoch die Elemente sind, die er GEBAUT hat**
  (`ReiseView.faulAb = 12`, ab 1.0.25). 1.0.16 hat ihn eingebaut, und der Grund
  gilt weiter: Ist kein Tag gewählt, stehen dort alle Seiten des Buches. Sein
  Preis trifft aber genau diese Stelle — während nach einem Zoom Seiten gesetzt
  und Fotos geladen werden, ändert sich die Gesamthöhe, und ein `ScrollView`
  rückt seinen Versatz dann nach. Ein gewählter Tag hat zwei bis sechs Seiten;
  dort ist die Faulheit kein Gewinn und kostet die Verlässlichkeit. Gezählt
  werden ELEMENTE, nicht Seiten — eine Doppelseite trägt zwei.
- **Zwei Griffe auf einmal sind hier erlaubt, WEIL die Probe sie trennt.** Die
  Regel „eine Sache auf einmal" gilt, damit der nächste Befund zuzuordnen ist;
  hier tut das die Zeile selbst: „ohne Nachführung" heißt, die Rolle war von
  selbst still und es lag am Stapel, „n× nachgeführt" heißt, die Regelung hat
  es geradegezogen. **Wer zwei Dinge zugleich ändert, baut vorher die Messung
  ein, die sie auseinanderhält** — sonst gilt die Regel unverändert.
- **Nicht gemessen (1.0.25):** Ob es auf dem Gerät jetzt steht, hat niemand
  gesehen. Und **welcher Mechanismus den Versatz verstellt, ist nicht
  bewiesen** — die Höhenschätzung des `LazyVStack` ist die Erklärung, die zu
  den Zahlen passt, und mehr nicht. Die Nachführung wirkt unabhängig davon,
  aber sie ist ein Netz und kein Beweis. **Nicht als erledigt darstellen.**
- **`scaleEffect` ändert die ZEICHNUNG, nie die LAYOUTGRÖSSE — und ein `.frame`
  ohne Ausrichtung stellt ein kleineres Kind MITTIG hinein** (behoben in
  1.0.26, gemeldet 09/2026 zum wiederholten Mal). Zwei Zeilen in
  `SeitenflaecheView`:
  `.scaleEffect(massstab, anchor: .topLeading)` und darunter
  `.frame(width: bogen.width * massstab, height: bogen.height * massstab)`.
  Das Kind meldet weiterhin die UNSKALIERTE Bogengröße, der Rahmen ist die
  skalierte — also stand das Kind mittig darin, und gezeichnet wurde ab SEINER
  Ecke, um `bogen · (Maßstab − 1) / 2` versetzt. Der Griff ist ein Wort:
  `alignment: .topLeading`.
- **Drei Beschwerden, eine Ursache — und der Nutzer hatte sie genauer benannt
  als jede Vermutung davor.** „Es ist nicht die Seite, sondern irgendein oberer
  linker Punkt der Arbeitsfläche, den du willkürlich festgelegt hast": genau
  so, und der Punkt lag um den halben Zuwachs daneben. Dazu „am oberen Rand
  bleibt grundsätzlich Abstand bis zur eigentlichen Buchseite" (die leere
  Lücke oben links), „die untere rechte Ecke erreiche ich nie" (der Überhang
  unten rechts — gerollt wird der RAHMEN, nicht die Zeichnung) und „nicht
  wieder herauszoomen" (**was außerhalb eines Frames liegt, nimmt in SwiftUI
  keinen Finger an** — dieselbe Regel wie bei den Griffen in 1.0.2, eine Ebene
  höher; der Zoom hängt an der Fläche der Bühne). **Merke: Drei Beschwerden,
  die sich widersprechen, haben oft eine Ursache — und die Beschwerde, die eine
  GEOMETRIE beschreibt, ist die, an der man rechnen kann.**
- **Nachgemessen an zwei Bildschirmfotos, in BEIDE Richtungen.** Bei 94 % steht
  die Blattkante 93 pt vom Bühnenrand, wo `Zoomanker` 121,5 erwartet (−28,5
  gegen gerechnet −28,0); bei 187 % liegt der Inhalt um +387/+272 daneben
  (gerechnet +373,5/+266,1). Unter 100 % zeichnet es weiter oben links als der
  Rahmen, darüber weiter unten rechts — beide Vorzeichen stimmen, beide
  Beträge auch. **Eine Ursache, die nur in einer Richtung passt, ist keine.**
- **Eine Probe, die „alles in Ordnung" meldet, ist nicht gescheitert.** Die
  Zeile aus 1.0.24 nannte `Soll −588/−1411 · Ist −588/−1411 · Abweichung 0/−0`
  — und das war RICHTIG: Gerollt wurde genau dorthin, wo die Rechnung es
  wollte. Falsch war, wo die Rechnung die Seite VERMUTETE. Ohne diese Zeile
  wäre 1.0.26 die fünfte Vermutung geworden; sie hat die Geometrie entlastet
  und den Blick auf das gelenkt, was sie nicht misst. **Wer eine Probe baut,
  schreibt dazu, was sie NICHT misst** — hier: wo das Gezeichnete innerhalb
  seines Rahmens liegt.
- **1.0.25 war falsch und ist zurückgenommen.** Die Nachführung (rollen,
  nachsehen, noch einmal rollen) und der Deckel für den `LazyVStack` waren die
  Antwort auf eine Frage, die es nicht gab: Der Versatz wurde nie nachträglich
  verstellt, er war von Anfang an ein anderer, als die Rechnung annahm.
  `ReiseView` steht wieder auf dem Stand von 1.0.24. **Ein Mechanismus, dessen
  Grund widerlegt ist, bleibt nicht liegen** — sonst steht beim nächsten Befund
  eine Regelung im Weg, die niemand mehr begründen kann.
- **Nicht gemessen (1.0.26):** Gesehen hat es niemand. Gerechnet und an zwei
  Bildern nachgemessen ist die URSACHE; dass die drei Beschwerden damit weg
  sind, folgt aus der Geometrie. **Nicht als erledigt darstellen.**
- **Das Format ist kein Wort mehr, sondern zwei Zahlen** (`Seitenformat`, ab
  1.0.27, Ansage des Nutzers 09/2026: „Ich möchte verschiedene Maßvorlagen für
  die Seiten haben. DIN A4 Hochkant, DIN A4 Breit, DIN A5 dasselbe und
  quadratisch 28 x 28 cm. Ansonsten möchte ich aber auch die Möglichkeit
  haben, eine Seite frei skalieren zu können."). Bis 1.0.26 war es eine
  Aufzählung mit vier festen Fällen; ein freies Maß lässt sich darin gar nicht
  ausdrücken. Jetzt ein Wertetyp aus `breite`, `hoehe` und einem **optionalen**
  Vorlagennamen — `nil` heißt „selbst eingetippt". Sieben Vorlagen (A4 und A5
  je hoch und quer, 21, 28 und 30 cm im Quadrat), Grenzen 70 bis 500 mm je
  Kante: Darunter wären die Ränder breiter als die Seite, darüber nimmt kein
  Druckdienst dieser Größenordnung an.
- **Der Leser nimmt weiterhin den alten TEXT entgegen.** In jeder gesicherten
  Reise steht an dieser Stelle `"a4quer"`, also eine Zeichenkette und kein
  Objekt. Ohne den Einzelwert-Zweig in `init(from:)` wäre `format` beim Lesen
  auf die Vorgabe gefallen — und weil `Reise` das Feld über `wert(.format, …)`
  holt, **still**: Das Buch ginge auf, und die Seiten hätten das falsche Maß.
  Dieselbe Regel wie seit 1.0.3, nur diesmal nicht für ein neues Feld, sondern
  für ein Feld, das seine GESTALT gewechselt hat. **Wer einen Typ von einer
  Aufzählung auf eine Struktur umbaut, schreibt den Leser für beide Formen.**
- **A4 nach A5 ist EINE Multiplikation** (`Model/Formatwechsel.swift`, ab
  1.0.27, Ansage des Nutzers 09/2026: „ich hoffe, dass es eine Möglichkeit
  gibt, ohne viel Aufwand aus dem DIN A4 Projekt ein A5 Projekt zu machen").
  Die ganze A-Reihe hat dasselbe Seitenverhältnis — das ist ihre Bauvorschrift
  —, also trifft ein einziger Faktor (1/√2 ≈ 0,707) beide Kanten. Gerechnet
  wird er auf **alles, was eine Länge ist**: Blockrahmen, Ränder, Fuge,
  Bundsteg, Eckenradius, Schriftgrößen, Innenabstände, Linienbreiten. Danach
  steht jeder Block relativ an derselben Stelle und wirkt in derselben Größe;
  nur das Papier ist kleiner. Die Sorge des Nutzers („problematisch, die Größe
  der Schriften herunterzurechnen") ist damit beantwortet, solange das
  Verhältnis stimmt.
- **Der Anschnitt wird NICHT mitgerechnet.** Er ist keine Gestaltung, sondern
  eine Angabe der Druckerei: Drei Millimeter sind drei Millimeter, egal wie
  groß die Seite ist. Wer ihn mitschrumpfte, lieferte eine Datei, die formal
  stimmt und beim Schneiden den weißen Faden bekommt, wegen dem es den
  Anschnitt gibt. Ebenso bleiben **`kartenanteil`** (ein Anteil), der
  **Bildausschnitt** (`zoom` und die beiden Versätze sind Anteile am Bild —
  mitgerechnet verschöben sie jedes Foto in seinem Rahmen) und die
  **Drehung** (ein Winkel).
- **Bei UNÄHNLICHEN Formaten gilt der kleinere Faktor, und das steht dabei.**
  Von A4 hoch auf 28 × 28 cm gibt es keinen, der beides trifft; genommen wird
  `min(neu.breite/alt.breite, neu.hoehe/alt.hoehe)`, denn das ist der einzige,
  bei dem kein Block aus der Seite fällt. An einer Kante bleibt dann mehr Luft
  als vorher — der Satz wird davon nicht falsch, sieht aber danach aus, wenn
  niemand es sagt. Das Blatt sagt es.
- **Erst zeigen, dann übernehmen** (`Formatwechsel.vorschau`, `Wechselblatt`).
  Ein Formatwechsel fasst JEDEN Block des Buches an. Vorher stehen da: beide
  Formate mit Maß, der Faktor in Prozent, die Zahl der betroffenen Blöcke und
  die Fließtextgröße vorher und nachher. Dieselbe Bauweise wie bei jeder
  Einfuhr dieser App. **Zwei Wege**, weil es zwei Fragen sind: „mitrechnen"
  für ein fertiges Buch, „nur das Format wechseln" für eines, das danach
  ohnehin neu angeordnet wird. Beides hängt an `werk.merken()` und ist mit
  „Widerrufen" zurückzunehmen.
- **Das Format bekommt einen EIGENEN Bildschirm** (Gestalten → Seitenformat).
  Bis 1.0.26 war es eine Auswahlzeile im Gestaltungsblatt, zwischen Anschnitt
  und Bundsteg. Das Format ist aber die eine Entscheidung, an der alles
  andere hängt, und seit 1.0.27 rechnet sie das Buch um — das gehört nicht
  hinter einen Auswahlknopf in einer Liste. In der Gestaltung steht die
  Zeile weiterhin, jetzt aber als Auskunft mit dem Weg dorthin: **Ein
  Bildschirm, der einen Wert nur noch anzeigt, muss sagen, wo er geändert
  wird** — sonst ist er für den Menschen davor kaputt.
- **Die Broschüre ist ein BOGEN und keine Druckvorlage**
  (`Buchausgabe.broschuere`, ab 1.0.27, Ansage des Nutzers 09/2026: „Wenn dann
  noch die Möglichkeit besteht, automatisch einen Buchdruck auswählen zu
  können, so dass die Seiten des Dokumentes automatisch umsortiert werden, so
  dass ich eine doppelseitige Broschüre drucken kann."). Gesetzt wird der
  Rückenstich: Die Seitenfolge wird mit Leerseiten auf ein Vielfaches von VIER
  aufgefüllt (anders geht ein gefalteter Bogen nicht auf), dann trägt Bogen `i`
  vorn `[n−1−2i | 2i]` und hinten `[2i+1 | n−2−2i]`. Der Bogen ist doppelt so
  breit wie das Endformat.
- **Ohne TrimBox und BleedBox, mit Absicht.** Beide sagen einer Druckerei, wo
  geschnitten wird — auf einem Bogen mit zwei Seiten nebeneinander gäbe es
  dafür keine einzige richtige Stelle, und eine Schnittmarke am falschen Ort
  ist schlimmer als keine. Aus demselben Grund läuft an der Broschüre **keine
  Druckprüfung**: Sie misst genau diese beiden Kästen und meldete hier
  garantiert Falsches. Was stattdessen dasteht, ist die Rechnung selbst —
  Seiten, Leerseiten, Bogen, Bogenmaß.
- **Die Rückseiten lassen sich um 180 Grad drehen, und das ist eine Frage an
  den DRUCKER.** Ob er beim beidseitigen Druck über die lange oder die kurze
  Kante wendet, steht in keiner Datei; es ist eine Einstellung des Treibers
  und je Gerät anders. Deshalb ein Schalter mit einem Satz daneben und keine
  Automatik: Eine App, die das errät, druckt bei der Hälfte aller Geräte jede
  zweite Seite auf dem Kopf. **Das nicht als gelöst darstellen** — geprüft ist
  es erst am eigenen Drucker, mit vier Seiten Probe.
- **„Der Zoom reagiert erst beim dritten Versuch" ist ein VERDACHT mit
  Zähler, kein Befund** (ab 1.0.27, gemeldet 09/2026 neben der Rückmeldung,
  dass es jetzt funktioniere). Die naheliegende Erklärung steht im Quelltext:
  `seitenzoomErlaubt` schaltet die Zweifingergeste der Seite ab, solange ein
  Foto gewählt ist oder der Ausschnittsmodus läuft — dann gehört sie dem Bild.
  Eine zu kurze Aufziehbewegung kommt als TIPP an, der Tipp hebt die Auswahl
  auf, und der nächste Versuch geht. Das wäre genau das gemeldete Muster.
  **Gemessen ist es nicht**, deshalb steht es nicht als Ursache da, sondern
  als Zeile im Befund: „Seitenzoom: erlaubt" bzw. „gesperrt (ein Foto ist
  gewählt)" / „gesperrt (Ausschnittsmodus)", dazu zählt der `Zeichenmesser`
  Beginn und Ende jeder Geste. Sagt der Befund beim nächsten Mal „gesperrt",
  ist es das; sagt er „erlaubt" und die Geste zählt trotzdem nicht hoch, kommt
  sie gar nicht an, und das ist etwas anderes. Dasselbe Muster wie bei
  Schulalarms Stufenprobe — **nach sechs Fassungen an dieser Bühne wird hier
  nicht mehr geraten.**
- **Nicht gemessen (1.0.27):** Keine Broschüre ist gedruckt worden, und welche
  Wendeeinstellung ein bestimmter Drucker benutzt, lässt sich aus einer Datei
  nicht wissen. Die Umrechnung von A4 auf A5 ist gerechnet und nicht auf einem
  Gerät gesehen — ob ein Fließtext von 11 pt bei 7,8 pt noch angenehm zu lesen
  ist, sagt erst der Ausdruck. Und die Ursache des „dritten Versuchs" ist ein
  Verdacht, siehe oben. **Nichts davon als erledigt darstellen.**
- **Das ganze Buch steht untereinander — die Tagesliste ist eine SPRUNGMARKE**
  (ab 1.0.28, Ansage des Nutzers 09/2026: „Lieb, wenn alle Seiten fortlaufend
  untereinander stehen würden, beziehungsweise in dieser Ansicht die
  Doppelseiten, sodass man mühelos von einem Seitenpaar zum nächsten wischen
  kann, ohne dass man links die Liste der Seiten [braucht]."). Bis 1.0.27
  filterten `sichtbareSeiten` und `sichtbareDoppelseiten` nach dem gewählten
  Tag. Damit war die Liste links keine Übersicht, sondern der EINZIGE Weg
  durch das Buch: Wer die letzte Seite eines Tages sah, musste zur Liste
  greifen, um weiterzublättern. **Ein Buch blättert man, man schlägt es nicht
  neu auf.** Der Filter ist ersatzlos weg; ein Tipp in der Liste rollt jetzt
  dorthin.
- **Damit heißt „gewählter Tag" etwas anderes — und muss dem folgen, was man
  SIEHT.** Vorher hieß es „was wird gezeigt", jetzt „worauf zielt das
  Tagesmenü unten rechts, der Titel und das Neuanordnen". Wer zum 6. August
  scrollt und dann „Seiten neu anordnen" tippt, meint den 6. August und nicht
  den Tag, den er vor zehn Minuten angetippt hat — eine stillschweigend am
  falschen Tag ausgeführte Handlung ist genau die Art Fehler, die diese App
  sonst überall vermeidet. Gemeldet wird über `onAppear`/`onDisappear` der
  Reihen (`ReiseView.imBlick`, Reihennummer auf Tageskennung, die kleinste
  ist die oberste): Das fällt EINMAL je Reihe an und nicht bei jedem
  Bildpunkt — dieselbe Überlegung, aus der `Inhaltslage` kein `@State` ist.
  Aus dem Rollversatz zu rechnen wäre der naheliegende Weg und schriebe einen
  Zustand sechzigmal in der Sekunde (die Lehre aus 1.0.16).
- **Den Kreis hält auf BEIDEN Seiten dieselbe Prüfung, kein zweiter
  Schalter.** Liste → Bühne und Bühne → Liste setzen denselben Wert; ohne
  Bremse sprängen sie einander hinterher. Gebremst wird mit der Frage, ob der
  Tag schon oben im Bild steht — steht er, ist nichts zu tun, und genau daran
  erkennt die Stelle auch, dass die Änderung vom Rollen kam. Ein Merker „das
  war ich" wäre der übliche Griff und liegt bei jeder Änderung der
  Reihenfolge wieder daneben; dieselbe Überlegung wie bei
  `Liniennetz.eigeneBewegung` in der Abfahrtstafel.
- **Einzelseiten und Doppelseiten zählen ihre Reihen VERSCHIEDEN** (Seitenzahl
  gegen Bogennummer). Beim Umschalten wird `imBlick` deshalb geleert — eine
  alte Meldung wäre dort nicht bloß veraltet, sondern falsch.
- **Der Zoom hängt als `simultaneousGesture` an der Bühne** (ab 1.0.28;
  gemeldet 09/2026: „Die Geste müsste eigentlich allein der Seite gehören,
  aber trotzdem muss ich mehrere Male anfassen."). Über dem Inhalt liegt der
  `ScrollView` und damit dessen Schiebeerkenner, und der beginnt schon bei
  EINEM Finger. Zwei Finger auf einer Rollfläche sind für ihn ein Wisch; ohne
  ausdrückliche Erlaubnis zur GLEICHZEITIGEN Erkennung muss einer der beiden
  verlieren, und welcher, entscheiden die ersten Millisekunden der Bewegung.
  Das IST „mal beim ersten, mal beim dritten Versuch".
- **Das ist keine Vermutung, sondern ein Vergleich IN DIESER App.**
  `SeitenflaecheView` hängt den Zoom des Bildausschnitts seit 1.0.8 mit
  `simultaneousGesture` in denselben `ScrollView` — dieselbe Gestenart,
  dieselbe Rollfläche, derselbe Bildschirm —, und der greift; die Bühne hing
  mit `.gesture` daran, und die greift nicht verlässlich. Der Unterschied
  zwischen beiden ist dieses eine Wort. **Wo zwei gleichartige Stellen sich
  verschieden verhalten, ist ihr Unterschied die erste Spur** — und eine, die
  sich am Quelltext nachlesen lässt, statt an der Erinnerung des Nutzers.
- **Der Verdacht aus 1.0.27 ist WIDERLEGT** (Nutzer 09/2026: „ich kann dir
  versichern, dass ich kein Bild ausgewählt habe"). 1.0.27 schrieb als
  naheliegenden Grund auf, ein gewähltes Foto sperre den Seitenzoom und ein
  zu kurzes Aufziehen komme als Tipp an. Die Zeile im Befund BLEIBT trotzdem
  stehen: Sie war nie eine Erklärung, sondern eine Messung, und sie hat genau
  das getan, wofür sie gebaut war — einen Zweig ausgeschlossen. **Eine Probe,
  die eine Vermutung umwirft, ist nicht gescheitert; das ist ihr Sinn.**
  Dieselbe Bauweise wie die Zeile „Soll/Ist" aus 1.0.24, die 1.0.26 die
  Geometrie entlastet hat.
- **Nicht gemessen (1.0.28):** Gesehen hat niemand etwas davon. Dass die
  Geste jetzt verlässlich ankommt, folgt aus der Art, wie UIKit zwei Erkenner
  gegeneinander abwägt, und aus dem Vergleich mit dem Bildausschnitt —
  gemessen wird es erst durch den Zähler „Zoomgeste" im Befund. **Ein
  Nebeneffekt steht offen:** Mit `simultaneousGesture` ROLLT die Bühne
  während des Aufziehens mit; am Ende der Geste rückt sie der Brennpunkt
  wieder zurecht (so seit 1.0.18), aber ob das ruhig aussieht oder wie ein
  Ruck, sagt erst der nächste Befund. Und die Bühne trägt jetzt wieder das
  GANZE Buch: Der `LazyVStack` aus 1.0.16 ist genau dafür da, aber wie sich
  ein Buch mit zweihundert Fotos dabei anfühlt, ist weiterhin ungemessen.
- **Welche Schriften ein Gerät hat, misst die App — sie schreibt es nicht
  auf** (`Schriftfamilie` ab 1.0.29 ein Wertetyp, `Model/Buchstabenform.swift`,
  `Views/SchriftwahlView.swift`; Ansage des Nutzers 09/2026: „Ich möchte noch
  weitere Schriftarten verwenden. Standardmäßig möchte ich eine serifenlose
  Schrift verwenden, bei der das kleine A so aussieht wie bei der Systemschrift
  Futura. Futura selbst ist mir etwas zu dick gedruckt. Bitte finde dort
  Alternativen."). Bis 1.0.28 war die Auswahl eine Aufzählung mit sechzehn
  Namen, die jemand einmal aufgeschrieben hatte. Welche Schriften ein iPad
  wirklich mitbringt, entscheidet aber das Gerät und ändert sich mit jeder
  iOS-Fassung. Jetzt steht dort der FAMILIENNAME, und gezeigt wird, was da ist.
  Dieselbe Umstellung wie beim `Seitenformat` in 1.0.27 — samt demselben
  Leser: Alte Dateien tragen `"futura"` als Text, und ohne den Einzelwert-Zweig
  fiele die Schrift beim Lesen STILL auf die Vorgabe zurück.
- **Der SCHNITT ist der eigentliche Grund für den Umbau.** Bis 1.0.28 baute
  `uiFont` den Deskriptor allein aus dem Familiennamen — damit kam immer der
  Regelschnitt und nie ein leichterer, den eine Familie vielleicht hat. „Futura
  ist mir etwas zu dick gedruckt" ist genau diese Lücke. Sie ist jetzt
  geschlossen, soweit sie sich schließen lässt: **Futura liefert iOS nur ab
  Medium aufwärts** — einen Buch- oder Light-Schnitt gibt es dort nicht, und
  wo keiner ist, steht auch keiner in der Liste. Das sagt die Oberfläche
  ausdrücklich, statt eine Einstellung anzubieten, die nichts ändert.
- **Ob ein kleines a rund ist, wird an der GLYPHE gemessen**
  (`Buchstabenform`). Der Unterschied zwischen einem einstöckigen a (Futura:
  ein Kreis mit Stamm) und einem zweistöckigen (Helvetica: eine Schale unten
  mit einem Bogen darüber) steckt in der GEGENFORM, also im Loch: Beim
  einstöckigen füllt sie fast die ganze Buchstabenhöhe, beim zweistöckigen gut
  ein Drittel. **Nachgemessen an elf Schriftdateien** (22.09.2026, dieselbe
  Rechnung in Python nachgezogen): zweistöckig 0,362 bis 0,468 (Liberation
  Sans/Serif/Mono, DejaVu Sans/Serif, FreeSans, FreeSerif, Loma), einstöckig
  0,719 bis 0,913 (Poppins, Questrial, Josefin Sans). Zwischen 0,468 und 0,719
  liegt eine breite Lücke; die Schwelle steht mittig darin.
- **Welche Kontur die äußere ist, entscheidet das UMFASSEN und nicht die
  Fläche — und wo keine alle anderen umfasst, gibt es KEINE Antwort.** Das ist
  an einer echten Schrift gelernt: **Jost zeichnet sein a aus zwei einander
  überlappenden Formen** statt aus Umriss und Loch. Nach der Fläche gerechnet
  gewann dort die falsche Kontur, und heraus kam „zweistöckig" für eine
  Schrift, die einstöckig ist. Jetzt schweigt die Messung in diesem Fall und
  sagt das auch. **Eine Messung, die im Zweifel etwas behauptet, ist schlechter
  als eine, die schweigt** — dieselbe Regel wie bei „Plan" gegen „pünktlich".
- **Jede Zeile der Schriftwahl ist in ihrer eigenen Schrift gesetzt**, mit
  einem Wort, das drei kleine a trägt. Das ist mehr wert als jede Messung: Wer
  die Form des a sucht, sieht sie. Die Messung ordnet nur die Liste und nennt
  ihre Zahlen unter der Probe — nachlesbar, nicht geglaubt.
- **Mitgeliefert wird weiterhin keine Schriftdatei.** Ein Buch wird
  weitergegeben, und dafür bräuchte jede Schrift eine Lizenz. Was zur Wahl
  steht, bringt das Gerät mit; ob es sich einbetten lässt, sagt seit 1.0.1 die
  Druckprüfung aus der OS/2-Tabelle.
- **Ein `NavigationLink` im Inspektor ist ein Knopf, der nichts tut** (ab
  1.0.29, beim Bau bemerkt). `BlockInspektor` ist eine `.inspector`-Spalte und
  bringt keinen eigenen Navigationsstapel mit — dieselbe Falle wie bei den
  Fahrplanzielen der Abfahrtstafel. Die Schriftwahl liegt dort deshalb als
  BLATT mit eigenem Stapel, und der Block wird darin neu nachgeschlagen statt
  hineingereicht: Ein mitgegebener Block wäre der Stand von dem Augenblick, in
  dem das Blatt aufging.
- **Einen Block auf eine andere Seite schieben — als BEFEHL und nicht als
  Geste** (`Reisewerk.blockVerschieben`, `blockAufNeueSeite`, Abschnitt „Auf
  welcher Seite" im Inspektor, ab 1.0.29; Ansage des Nutzers 09/2026: „ich
  möchte ein Bild problemlos von einer Seite auf eine andere schieben können
  beziehungsweise auch andere Elemente wie zum Beispiel Textfelder."). Eine
  Ziehgeste, die ein Blatt verlässt, müsste MITTEN im Ziehen entscheiden, zu
  welcher Seite der Finger gerade gehört — in einer Bühne, die sich dabei rollt
  und zoomt. Das ist die Art Ziehgeste, die dieses Projekt von 1.0.5 bis 1.0.8
  gekostet hat und deren Zoom bis 1.0.28 nicht stand. **Ein Knopf, der immer
  tut, was draufsteht, ist hier mehr wert als eine Geste, die meistens tut, was
  gemeint war.**
- **Die Lage auf dem Blatt bleibt beim Verschieben, wie sie ist.** Den Block
  auf der neuen Seite zu zentrieren wäre bequemer und verschöbe etwas, das
  niemand angefasst hat. Danach trägt er `vonHand` — ein Neuanordnen, das ihn
  stillschweigend zurückholte, nähme genau die Entscheidung zurück, die jemand
  gerade getroffen hat. **Verschoben wird innerhalb EINES Tages:** Über
  Tagesgrenzen hinweg ist es keine Frage der Seite mehr, sondern der Zuordnung
  (`tag.fotos`), und die wird dort beantwortet, wo sie gestellt wird — in der
  Fotoliste des Tages.
- **„Text und Bilder im Wechsel" ist ein eigenes Muster, kein neuer Name**
  (`Seitenmuster.wechsel`, ab 1.0.29; Ansage des Nutzers 09/2026: „Bei den
  Vorlagen vermisse ich etwas … Ich möchte ein Reisetagebuch mit sehr viel Text
  mit ebenfalls sehr vielen Bildern verknüpfen."). `reihenSetzen` wechselt seit
  1.0.14 auf den FOLGESEITEN zwischen Text und Fotoreihen — die ERSTE Seite war
  davon ausgenommen: Dort füllte der Text bis zum Satzspiegelende, und das
  erste Bild stand eine Seite weiter. Bei einem Tag mit viel von beidem ergibt
  das genau den gemeldeten Eindruck: erst ein Kapitel Text, dann eines mit
  Bildern. Das neue Muster hält auf der ersten Seite die ZIELHÖHE der nächsten
  Fotoreihe frei — dieselbe Zahl, mit der `reihenSetzen` weiterrechnet, und
  kein geschätzter Anteil. Bleiben daneben keine sechs Zeilen Text mehr, wird
  gar nichts freigehalten; eine Seite mit vier Zeilen über einem Bild ist kein
  Satz, sondern ein Rest.
- **Die Schwelle ist hoch mit Absicht** (über 1200 Zeichen UND mindestens vier
  Fotos). Ein Tag mit drei Sätzen und zwei Bildern ist damit nicht gemeint und
  bekommt weiter, was er vorher bekam. Das Muster steht in allen fünf
  Buchstilen an erster Stelle — es greift also überall, aber nur für die Tage,
  um die es geht.
- **Nicht gemessen (1.0.29):** Welche Schriften auf dem iPad des Nutzers ein
  rundes a haben, weiß hier niemand — die Messung läuft auf dem Gerät, und
  erst die Liste dort sagt, ob Futura Gesellschaft bekommt. Gut möglich, dass
  die Gruppe dünn ausfällt: Unter den Schriften, die iOS mitbringt, ist ein
  einstöckiges a selten. **Sollte dort nichts Brauchbares stehen, ist der
  nächste Schritt eine mitgelieferte Schrift unter der SIL Open Font License**
  (die erlaubt Einbettung und Weitergabe ausdrücklich, und dieses Repo führt in
  `woerterwerkstatt/fonts/` bereits solche Dateien) — das wäre aber eine
  Abkehr von der Regel oben und gehört ausdrücklich abgesprochen, nicht
  nebenbei gemacht. Ebenso ungesehen: ob das Verschieben auf eine andere Seite
  sich richtig anfühlt und wie eine Doppelseite im neuen Muster aussieht.
- **„Alle auswählen" kann Apples Fotowähler nicht — ein ZEITRAUM kann es**
  (`Dienste/Zeitraumeinfuhr.swift`, ab 1.0.30, gemeldet 09/2026: „Beim Foto-Import
  muss ich bislang die Fotos einzeln auswählen. Ich möchte, dass sie alle
  ausgewählt werden können."). Die Mehrfachauswahl war nie beschränkt
  (`selectionLimit = 0` steht seit 1.0.0 dort); was fehlt, ist der eine Knopf, und
  der gehört nicht uns: `PHPickerViewController` läuft in einem EIGENEN Prozess —
  genau deshalb darf er ohne Mediathekserlaubnis arbeiten, und genau deshalb kann
  ihm keine App etwas hinzufügen. Gefragt wird deshalb nicht nach Bildern, sondern
  nach einem Zeitraum: **Eine Reise IST ein Zeitraum**, und die Mediathek gibt ihn
  über ein Prädikat auf `creationDate` her, sobald die Erlaubnis da ist, die diese
  App ohnehin für die Aufnahmeorte braucht.
  - **Gezählt wird, bevor etwas geladen wird** („Gefunden: 1284 Fotos"). Ein Knopf,
    der ungefragt tausend Dateien holt, ist ein Sprung ins Dunkle.
  - **Geholt wird Foto für Foto**, und zwar auf BEIDEN Wegen. Tausend Rohbilder
    sind mehrere Gigabyte; der Fotowähler sammelte sie bis 1.0.29 erst alle in
    einer Liste, was tragbar war, solange man einzeln antippt. `fotosAufnehmen`
    gibt es seit 1.0.30 zweimal — als Liste und als Strom —, und die Liste ruft
    den Strom: **Es gibt nur EINE Stelle, an der ein Rohbild zu einem `Foto`
    wird.**
  - **`isNetworkAccessAllowed = true`, ausdrücklich.** Ein Foto kann in iCloud
    liegen; ohne diese Zeile käme gar nichts zurück, ohne Fehler — der Zeitraum
    sähe halb leer aus.
  - **`requestImageDataAndOrientation` darf seinen Rückruf MEHRMALS aufrufen.** Ein
    zweites `resume` an einer `CheckedContinuation` ist kein Fehler, sondern ein
    Absturz; daher der Wächter `Einmal`.
  - Die Grenzen des Zeitraums entstehen in der GERÄTEZONE — dieselbe ausdrückliche
    Ausnahme wie beim Datum aus der Mediathek. Bei `.limited` liefert die Abfrage
    nur die freigegebenen Fotos, und die Fußzeile sagt das.
- **„Wenn das Datum fehlt" war ZWEIERLEI** (ab 1.0.30, gemeldet 09/2026: „wenn das
  Datum fehlt, dann liegen sie in der Ablage. Das möchte ich nicht. Ich möchte,
  dass bei einem fehlenden Datum der Tag einfach automatisch angelegt wird."). Der
  TAG wurde immer schon angelegt — `Reise.tagIndex(fuer:)` hängt einen Reisetag an,
  sobald ein Foto ein Datum trägt, das es im Buch noch nicht gibt. In die Ablage kam
  nur, was GAR KEIN Datum trägt. Die Fußzeile des Einlesen-Blattes sagte das so
  verkürzt, dass es wie das Gegenteil klang. **Merke: Ein Befund über eine Funktion
  kann ein Befund über ihren Beschreibungstext sein** — erst prüfen, was die App
  wirklich tut, bevor man sie umbaut.
- **Die dritte Datumsquelle ist der DATEINAME** (`Dienste/Namensdatum.swift`, ab
  1.0.30). Der häufigste Grund für ein fehlendes EXIF-Datum ist kein fehlendes
  Datum, sondern eine Datei, die durch einen Messenger oder eine Bildbearbeitung
  gelaufen ist: Die Metadaten sind weg, der NAME steht noch da
  (`IMG_20260812_193321.jpg`, `PXL_20260812_173321123.jpg`, `2026-08-12 19.33.21.jpg`,
  `Foto 12.08.2026.jpg`). Es gilt dieselbe Regel wie überall: **Der Tag kommt aus
  drei Zahlen** — ein Dateiname trägt Ziffern und keine Zeitzone, hier wird nichts
  umgerechnet; der Zeitpunkt daneben ist wie beim EXIF-Datum ein Sortierschlüssel in
  fester Zone.
  - **Geraten wird NICHT.** Drei Schreibweisen, und eine Ziffernfolge anderer Länge
    wird nicht beschnitten; das Jahr muss zwischen 1990 und 2100 liegen — enger als
    `Tagesdatum.gueltig`, weil ein Dateiname die schwächere Quelle ist. Aus
    `IMG_1234.jpg` wird kein Datum. Irgendeine Ziffernfolge als Datum zu lesen legte
    ein Foto still auf einen erfundenen Tag, und das ist der Fehler, den man dem
    gedruckten Buch nicht ansieht.
  - **`deletingPathExtension` schneidet stur hinter dem letzten Punkt ab.** Bei
    „2026.08.12" ohne Endung nähme es den Tag mit — gelesen wird erst ohne Endung,
    dann mit.
- **Wo gar kein Datum übrig bleibt, entscheidet der MENSCH, und zwar vorher**
  (`Fotoziel`, Zeile „Fotos ohne Datum" im Einlesen-Blatt, ab 1.0.30). Ein Foto ohne
  jede Datumsangabe trägt keine Auskunft darüber, wann es aufgenommen wurde — an
  WELCHEN Tag es geht, ist eine Entscheidung und keine Messung. Vorbelegt mit dem
  ersten Reisetag, Ablage nur, solange es gar keinen Tag gibt; der Bericht nennt den
  Tag hinterher beim Namen. Einen Tag mit erfundenem Datum anzulegen wäre der
  naheliegende Griff und der falsche: `Reisetag` ist über sein `Tagesdatum`
  geschlüsselt, und ein erfundenes stünde für immer im Buch. Der Weg über „Dateien"
  hat keinen eigenen Bildschirm und nimmt dieselbe Vorgabe.
- **Was keine Aufnahmezeit hat, kommt ans ENDE des Tages** (ab 1.0.30). Bis dahin
  stand in der Sortierung `.distantPast`, und das war folgenlos, solange ein Tag gar
  kein undatiertes Foto tragen konnte. Jetzt wäre es die falsche Richtung: Es schöbe
  sich vor den Morgen eines Tages, über den es nichts aussagt. Dieselbe Regel wie
  beim Handpunkt ohne Uhrzeit in der Reisespur.
- **Ein Feld, das nie gelesen wird, ist ein halb gebautes Vorhaben** (beim
  Gegenlesen von 1.0.30 wieder ausgebaut). Der erste Entwurf trug eine Aufzählung
  `Datumsquelle` am `Bildbefund` — geschrieben an drei Stellen, gelesen an keiner.
  Gezählt wird ohnehin dort, wo die Quelle greift, und der Einfuhrbericht nennt die
  Zahlen. Dieselbe Lehre wie beim Kartenausschnitt in 1.0.11, nur diesmal vor dem
  Ausliefern bemerkt.
- **Nicht gemessen (1.0.30):** Nichts davon ist auf einem Gerät gesehen. Gerechnet
  ist, wie ein Name zerlegt wird und was die Mediathek auf eine Zeitraumabfrage
  herausgibt; ob eine bestimmte Kamera so benennt, sagt erst der Einfuhrbericht des
  Nutzers. Ebenso ungemessen, **wie sich ein Zeitraum mit tausend Fotos anfühlt** —
  das Einlesen läuft auf dem Hauptfaden und gibt zwischen zwei Fotos ab. Und ob
  `PHPickerResult.itemProvider.suggestedName` wirklich den ursprünglichen Dateinamen
  trägt, ist die Lesart der Dokumentation und keine Messung. **Nicht als erledigt
  darstellen.**
- **Der freigehaltene Streifen gehört der REIHE, nicht dem Text** (ab 1.0.31,
  gemeldet 09/2026: „Es gibt einen riesigen Textblock und danach werden die Bilder
  auf die Seite geknallt."). Das ist am Quelltext nachzurechnen und passt zum
  Bildschirmfoto: `.wechsel` hält auf der ersten Seite die gemessene Höhe der
  nächsten Fotoreihe frei (seit 1.0.29) — und `reihenSetzen` prüft zu Beginn jeder
  Seite NOCH EINMAL selbst, ob neben einer Reihe sechs Zeilen Text Platz haben.
  Auf genau diesem Streifen haben sie das nicht, also gab die Prüfung null zurück
  und der ganze Rest ging an den Text. Ging dem Text dabei die Luft aus, blieb
  unten Weiß stehen und die Reihe passte nicht mehr: neue Seite, nur Bilder.
  **Wer Platz für ein Bild freihält, stellt das Bild auch hinein** — reicht die
  Resthöhe für eine Reihe, aber nicht für Reihe UND sechs Zeilen, bekommt sie die
  Reihe. **Merke: Wenn zwei Stellen dieselbe Frage stellen, muss die zweite die
  Antwort der ersten kennen.**
- **Jede Seite bekommt ein eigenes Seitenbild** (`Model/Seitenrhythmus.swift`, ab
  1.0.31, Ansage des Nutzers 09/2026: „Dabei soll nicht jede Seite gleich aussehen
  … Mal soll der Textblock oben links sein, mal in der Mitte, mal leicht
  verschoben, vielleicht auch sogar einmal gedreht."). Verteilt wurde seit 1.0.14;
  was fehlte, war das Zweite — Textspalte über die volle Satzbreite, darunter
  randbündige Fotoreihen, Seite für Seite dasselbe. **Ein Buch, dessen Seiten sich
  nur im Inhalt unterscheiden, ist gesetzt wie eine Tabelle.**
  - **Sechs Seitenbilder in FESTER Folge**, der Einstieg aus `UUID.saat` des
    Tages — sonst begänne jeder Tag mit demselben Bild, also derselbe Befund eine
    Ebene höher. **Nie aus `hashValue`**: Den streut Swift je Programmlauf neu,
    und dasselbe Buch sähe nach jedem Start anders aus (dieselbe Falle wie bei
    den Linienfarben der Abfahrtstafel und beim Papierkorn in 1.0.16).
  - **Die Liste ist eine FOLGE, keine Menge.** Auf eine volle Breite folgt eine
    schmale, auf einen linken Block ein rechter. Wer etwas einfügt, ordnet ein.
  - **Die Spanne ist eng mit Absicht** (58 bis 100 Prozent Spaltenbreite, linke
    oder rechte Kante). Einen frei im Blatt schwebenden Kasten gibt es NICHT: Ein
    Buch, dessen Ränder von Seite zu Seite springen, wirkt nicht lebendig,
    sondern unfertig.
  - **Gedreht und gestaffelt wird nur, wo es hingehört** (`Buchstil.lebendig` —
    Fotoalbum und Postkarte ja, Magazin, Journal und Klar nein). In einem Magazin
    wäre ein schiefes Bild ein Fehler, in einem Album fehlte es.
  - **Die Drehung des Textblocks ist auf 0,6 Grad gedeckelt, und die gehobene
    Ecke wird MITGERECHNET.** Ein halbes Grad auf 400 Punkt Breite sind gut
    dreieinhalb Punkt — weniger als die Fuge, aber nicht nichts; wer es nicht
    dazurechnet, verlässt sich darauf, dass es schon passen wird. Mehr als ein
    Grad liest sich nicht als Absicht, sondern als Druckfehler.
  - **Den Rhythmus bekommt NUR `.wechsel`.** Die übrigen Muster sind je eine
    eigene Bildidee; wandernde Spalten würden dort mit der Idee des Musters
    streiten. Es wird eine Sache auf einmal geändert.
- **Ein Menü, das seinen eigenen Stand verschweigt, lässt einen raten** (ab
  1.0.31, gemeldet 09/2026: „Die angekündigte Option Tagebuch, Text und Bilder im
  Wechsel finde ich nicht."). Fünfte Auflage von „es war da, man fand es nicht",
  diesmal doppelt: Der Menüpunkt hieß **„Seitenmuster"** — ein Fachwort statt
  einer Frage — und lag hinter einem Knopf, der nur ein KALENDERSYMBOL trug, also
  einer von vier gleich aussehenden Kreisen in der Werkzeugleiste war. Jetzt
  trägt der Knopf das DATUM sichtbar, der Menüpunkt heißt „Seiten setzen: …" und
  nennt, was gerade gilt (ausdrücklich gewählt oder „automatisch (…)").
- **„Für ALLE Tage übernehmen" steht dort, wo die Frage entsteht**
  (`Reisewerk.musterFuerAlle`, ab 1.0.31) — im Menü des einzelnen Tages. Wer für
  einen Tag einstellt, wie seine Seiten gesetzt werden, ist genau die Person, die
  als Nächstes „und für alle?" fragt; dieselbe Lehre wie beim Fotostil in 1.0.10.
  **Tage mit Handarbeit bleiben dabei stehen und werden gezählt**: Ein
  Musterwechsel, der eine Stunde Handarbeit stillschweigend wegräumt, wird genau
  einmal benutzt.
- **Nicht gemessen (1.0.31):** Wie eine Doppelseite im neuen Rhythmus AUSSIEHT,
  hat niemand gesehen. Gerechnet ist die Ursache des vollen Textblocks; die sechs
  Seitenbilder und ihre Zahlen sind gewählt und nicht gemessen — ob die Folge
  abwechslungsreich wirkt oder unruhig, sagt erst der nächste Befund. Ebenso
  ungeprüft, ob ein leicht gedrehter Textblock im PDF sauber steht. **Nicht als
  erledigt darstellen.**
- **„Tagebuch" ist ein STIL, kein Seitenmuster** (`Buchstil.tagebuch`, ab
  1.0.32; Ansage des Nutzers 09/2026: „Die Option Tagebuch finde ich nach wie
  vor nicht. Ich möchte, dass sie dort eingefügt wird, wo die anderen Optionen
  sind. Nämlich da, wo ich Fotobuch und Magazin auswählen kann."). Es gab
  „Text und Bilder im Wechsel" seit 1.0.29 — als `Seitenmuster`, also hinter
  dem Tagesmenü, dort, wo man einen EINZELNEN Tag anders setzen lässt. 1.0.31
  hat dieses Menü findbar gemacht, und der Nutzer hat es trotzdem nicht
  gefunden: **Er hat nicht an der falschen Stelle gesucht, es lag an der
  falschen.** Ein durchgehend erzählendes Buch ist eine Handschrift und kein
  Sonderfall eines Tages. Fünfte Auflage von „es war da, man fand es nicht" —
  und die erste, bei der nicht der Weg zu kurz war, sondern die Sache am
  falschen Ort stand. **Merke: Wird etwas zum zweiten Mal nicht gefunden, ist
  nicht der Weg dorthin zu prüfen, sondern die Zuordnung.**
- **Ein sechster Stil ist EINE Zeile** (`Buchstil.alle`). `StilView` läuft über
  diese Liste; wer einen Stil anlegt und dort nicht einträgt, hat ihn gebaut
  und nicht ausgeliefert. Das Muster `.wechsel` steht in `tagebuch` an erster
  Stelle der `musterVorliebe` — es steht das auch in allen fünf anderen Stilen,
  greift dort aber erst ab 1200 Zeichen und vier Fotos; der Unterschied ist
  nicht das Muster, sondern Schrift, Papier, Fugen und `lebendig`. Und
  `Seitenmuster.wechsel` heißt seither nicht mehr „Tagebuch: …": Zwei Dinge
  mit demselben Namen sind eines zu viel.
- **Ein Tag fängt mit einem Bild an** (Aufmacherband, ab 1.0.32). Befund des
  Nutzers zu 1.0.31: „Ich finde sie nach wie vor sehr nüchtern." Die Seiten
  waren richtig gesetzt und sahen aus wie ein Bericht — Kopfzeile, Textspalte,
  darunter eine Reihe gleich hoher Bilder. Im Muster `.wechsel` steht jetzt
  unter der Kopfzeile ein Bild über die **ganze Satzbreite**, auch wenn die
  Textspalte darunter schmaler ist: Genau dieser Unterschied macht es zum
  Aufmacher. Es kostet ein Foto aus dem Vorrat, deshalb erst ab dreien — bei
  zweien wäre die Reihe darunter leer, und der Tag sähe ärmer aus statt
  reicher. Höhe ein Drittel der Satzhöhe; die Zahl ist **gewählt und nicht
  gemessen**.
- **Die letzte Seite eines Tages war die verschenkte**
  (`ausfuellendesZiel`, `stapelhoehe`, ab 1.0.32). Zweiter Teil desselben
  Befundes: „es wird häufig Platz verschenkt." Am Quelltext nachzurechnen und
  keine Vermutung: `zielhoehe(fuer:)` leitet die Reihenhöhe allein aus der
  ZAHL der Kacheln ab und sieht die Seite nie an. Solange viele Bilder warten,
  ist das richtig — die nächste Reihe füllt ohnehin nach. Auf der letzten Seite
  warten aber oft nur noch zwei oder drei: Eine Reihe steht oben, darunter
  bleibt die halbe Seite weiß. Und `restplatzVerteilen` hilft dort **prinzipiell
  nicht** — es verteilt die Lücken ZWISCHEN den Reihen, und bei einer einzigen
  Reihe gibt es keine.
  - **Vergrößert wird nur, wenn ALLES Offene auf diese eine Seite passt und
    kein Text mehr wartet.** Sonst gehört der Platz dem Text bzw. füllt die
    nächste Reihe die Seite ohnehin. Damit ist die Änderung eng auf den
    gemeldeten Fall begrenzt und lässt jede andere Seite, wie sie war.
  - **Gesucht wird in Schritten, nicht gerechnet.** Eine größere Zielhöhe nimmt
    Kacheln aus den Reihen heraus und kann damit eine Reihe MEHR ergeben — der
    Zusammenhang ist nicht monoton, eine geschlossene Formel gäbe es nicht.
    Gehalten wird der letzte Wert, der nachweislich passte.
  - **Gemessen wird mit derselben Funktion, die auch setzt** (`naechsteReihe`,
    samt Staffelhub). Eine zweite Schätzung daneben liefe auseinander, und dann
    hielte die Seite nicht, was die Probe sagt.
- **Wer entscheidet, ob Handarbeit stehen bleibt, ist der Nutzer** (ab 1.0.32,
  Ansage 09/2026: „Ich möchte außerdem die Option haben, wenn ich eine
  Gestaltungsansicht ändere, dass auch bereits bearbeitete Seiten wieder
  zurückgesetzt werden. Ich möchte das frei entscheiden können."). Bis 1.0.31
  wurden von Hand bearbeitete Tage beim Stilwechsel IMMER verschont. Die
  Vorsicht ist richtig — eine Automatik, die eine Stunde Handarbeit ohne
  Rückfrage überschreibt, benutzt man genau einmal. Falsch war, daraus eine
  Regel zu machen: Wer den Stil wechselt, will das ganze Buch anders haben, und
  dann stehen ein paar Seiten im alten Satz mitten darin. Gefragt wird
  weiterhin, nur ist die Antwort jetzt eine **Wahl** („Bearbeitete Seiten
  behalten" / „Alles neu setzen") und keine Ansage. **Merke: Eine Rückfrage,
  die nur eine Antwort zulässt, ist keine Rückfrage.** Die Zahl der betroffenen
  Tage steht in der Meldung — „an einigen Tagen" lässt einen raten, ob es um
  einen geht oder um zwanzig; gezählt wird beim TIPP und nicht im Körper der
  Ansicht (dieselbe Falle wie bei der Druckprüfung in 1.0.0).
- **Eine pauschale Ersetzung trifft auch BEZEICHNER** (Selbstfund beim Bau von
  1.0.32). Beim Geradeziehen von Umlauten in Kommentaren wurde aus `gehoert`
  ein `gehört` — auch im Funktionsnamen; `ReiseView` rief danach etwas, das es
  nicht mehr gab. Gemeldet hat es der Bau, nicht
  `scripts/swift-quelltext-pruefen.py`: Der sieht String-Literale an und keine
  Bezeichner. **Wer Umlaute in Kommentaren richtet, prüft vorher, ob dieselbe
  Zeichenfolge auch in einem Bezeichner vorkommt** — deutsche Namen im
  Quelltext sind in diesem Repo die Regel, also ist es nicht der Sonderfall,
  sondern der Normalfall.
- **Nicht gemessen (1.0.32):** Keine Seite ist damit gesehen worden. Gerechnet
  ist, WARUM unten Platz blieb; dass die Seite jetzt gefüllt aussieht, folgt
  aus der Geometrie. Die Zahlen sind **gewählt und nicht gemessen**: ein
  Drittel der Satzhöhe fürs Band, Deckel 2,2 und Schrittweite 1,05 beim
  Füllen, die Schwellen 600 Zeichen und drei Fotos. Ob der neue Stil auf einem
  Gerät nach Tagebuch aussieht, sagt erst der nächste Befund. **Zwei Dinge auf
  einmal geändert** (Aufmacher und Füllung) — das ist hier vertretbar, weil sie
  sich auf der Seite nicht verwechseln lassen: ein breites Bild oben ist der
  eine, größere Reihen unten der andere.
- **Eine LEERE Seite war keine Handarbeit — und verschwand deshalb**
  (`Seite.vonHandAngelegt`, ab 1.0.33). `Seite.vonHand` war ausschließlich
  GERECHNET: „irgendein Block auf dieser Seite wurde angefasst". Eine von
  Hand eingefügte leere Seite trägt aber keinen Block; sie galt damit als
  unberührt, und das nächste Neuanordnen des Tages räumte sie weg, ohne ein
  Wort. Damit war „Seite anfügen" seit 1.0.0 eine Zusage, die beim nächsten
  Handgriff daneben zurückgenommen wurde. Daneben steht jetzt ein
  GESPEICHERTER Vermerk.
  - **Er steht an der SEITE und nicht am Tag.** `Seite.vonHand` ist die eine
    Stelle, durch die alles fragt — `hatHandarbeit`, `alleNeuAnordnen`,
    `handarbeitstage`, die Marke in der Tagesliste, die Rückfrage beim
    Stilwechsel. Ein zweites Feld am Tag müsste an jeder davon einzeln
    beachtet werden, und die eine vergessene Stelle wäre wieder ein stiller
    Verlust.
  - **Auch das ENTFERNEN und das VERSCHIEBEN einer Seite setzen ihn**
    (`Reisewerk.seitenfolgeGemerkt`). Wer an der Seitenfolge arbeitet, hat
    von Hand gearbeitet; ohne den Vermerk holte das nächste Neuanordnen die
    Seite zurück, als wäre nichts gewesen. Welche Seite ihn trägt, ist
    gleichgültig — gefragt wird überall nur, OB der Tag Handarbeit enthält.
  - Das Feld ist neu und NICHT optional, `Seite` liest sich aber seit 1.0.12
    von Hand (`b.wert(.vonHandAngelegt, false)`) — ein Buch von gestern
    öffnet sich unverändert.
- **Seiten an bestimmten Stellen** (`Views/SeitenView.swift`,
  `Reisewerk.seiteEinfuegen`, ab 1.0.33; Ansage des Nutzers 09/2026: „Für die
  manuelle Bearbeitung brauche ich die Option Seiten an bestimmten Stellen
  hinzufügen zu können oder eben auch löschen zu können."). Bis 1.0.32 gab es
  dafür zwei halbe Wege: „Seite anfügen" im Tagesmenü hängte immer HINTEN an,
  und „Diese Seite entfernen" stand im Block-Inspektor — also dort, wo man
  einen Block bearbeitet, und nur für die Seite, auf der der gewählte Block
  gerade liegt. Eine bestimmte Stelle ließ sich damit gar nicht ansprechen.
  - **Eine LISTE mit Nummern, keine Miniaturbilder.** Eine Nummer ist die
    einzige Angabe, mit der sich eine Stelle benennen lässt; daneben steht,
    was auf der Seite steht („2 Texte · 3 Fotos"), sonst wäre es eine Folge
    von Zahlen, von denen sich keine wiedererkennen lässt.
  - **`seiteHinzufuegen` ist seither der Sonderfall „einfügen ganz hinten"**
    und keine zweite Funktion daneben — zwei Fassungen desselben Anfügens
    liefen auseinander.
  - **Die letzte Seite eines Tages bleibt stehen.** Ein Tag ohne Seite wäre
    ein Loch im Buch, und `fehlendeSeitenNachholen` setzte ihn beim nächsten
    Öffnen ohnehin neu.
  - **Unter der Liste steht, was die Handarbeit KOSTET:** Der Tag wird danach
    beim automatischen Neuanordnen übersprungen. Wer das nicht weiß, hält den
    Automaten für kaputt.
- **Ein Buch duplizieren heißt ZWEI Hälften kopieren** (`Regal.duplizieren`,
  `Bildarchiv.ordnerKopieren`, ab 1.0.33; Ansage des Nutzers 09/2026: „Ich
  möchte ein Projekt duplizieren können."). Ein Buch ist eine JSON-Datei UND
  ein Ordner voller Bilder. **Ein Buch mit fremdem Bilderordner wäre eine
  Zeitbombe**: `Ablage.loeschen` räumt den Ordner der Reise mit weg — wer die
  Kopie löscht, nähme dem Urbuch alle Fotos mit, und zwar still, denn das
  Buch öffnet sich ja weiterhin.
  - **Die INNEREN Kennungen bleiben, wie sie sind**, und das ist kein
    Versehen: Tage, Seiten, Blöcke und Fotos gelten innerhalb eines Buches,
    und zwei Bücher sehen einander nie. Mehr noch — sie MÜSSEN bleiben, denn
    Papierkorn und Seitenrhythmus rechnen aus `UUID.saat`; mit neuen
    Kennungen sähe die Kopie anders aus als das Urbuch. **Tafelbild hat
    1.4.5 das Gegenteil gelernt** („Eine Kopie erbt keine Kennungen") — dort
    lagen die Kopien in DERSELBEN Tafel, und dann ist eine doppelte Kennung
    wirklich eine. Neu ist genau eine Zahl: die der Reise, denn die ist der
    Dateiname.
  - **Die Dateinamen der Bilder bleiben ebenfalls.** Sie gelten innerhalb
    eines Ordners; sie umzubenennen hieße, jede Fotoangabe im kopierten Buch
    mitzuziehen, ohne dass irgendetwas besser würde.
  - **Halb kopiert wird zurückgenommen.** Scheitert das Sichern, wird der
    schon angelegte Bilderordner wieder weggeräumt — ein Buch ohne seine
    Bilder sieht aus wie eines, dem die Fotos abhandengekommen sind.
  - **Die Bilder gehen ABSEITS des Hauptfadens** (`Task.detached`), und
    `duplizieren` ist `@MainActor`, weil `neuLesen()` am Ende `@Published`
    schreibt: Eine nicht isolierte `async`-Funktion läuft im
    Nebenläufigkeits-Pool und nicht beim Aufrufer.
  - **Zwei Wege, eine Stelle:** Wischgeste und Kontextmenü im Regal, dazu
    „Dieses Buch duplizieren" im `…`-Menü des offenen Buches — dort mit
    `sofortSichern()` davor, sonst fehlte der Kopie, was in den letzten
    Minuten getan wurde.
- **Nicht gemessen (1.0.33):** Nichts davon ist auf einem Gerät gesehen.
  Gerechnet ist, WARUM eine leere Seite verschwand (`vonHand` ist eine
  berechnete Eigenschaft über die Blöcke, und eine leere Seite hat keine) —
  dass sie jetzt stehen bleibt, folgt daraus. **Wie lange das Kopieren eines
  Buches mit zweihundert Fotos dauert, ist nicht gemessen**: Es läuft abseits
  des Hauptfadens und sperrt die Liste so lange, aber ob dabei eine
  Fortschrittsanzeige fehlt, sagt erst der nächste Befund. Ebenso ungeprüft,
  ob `FileManager.copyItem` auf diesem Gerät eine APFS-Kopie anlegt oder die
  Bytes wirklich verdoppelt — die Platzfrage ist damit offen.
- **Die Seite entsteht aus dem INHALT des Tages** (`Model/Tagesplan.swift`, ab
  1.0.34; Befund des Nutzers 09/2026 zu zwei Bildschirmfotos eines
  ausgegebenen Buches: „Es hat tatsächlich den Eindruck, als ob hier nur ein
  vorgegebenes Design mit sechs unterschiedlichen Seiten der Reihe nach
  abgespult wird, ohne darauf zu achten, wie der konkrete Inhalt eines Tages
  wirklich ist."). **Er hatte recht, und es stand wortwörtlich so im
  Quelltext**: `Seitenrhythmus` war eine Liste von sechs Seitenbildern,
  durchlaufen mit `(seite + versatz) % 6`; wie viel Text der Tag hat, wie
  viele Bilder und ob sie hoch oder quer stehen, ging in diese Wahl mit keinem
  einzigen Wert ein. Die Datei ist **ersatzlos entfernt** und nicht auf einen
  Sonderfall zurückgestellt — dieselbe Regel wie beim Rückbau von 1.0.25:
  Ein Mechanismus, dessen Grund widerlegt ist, bleibt nicht liegen.
  - **Gemessen werden zwei Höhen** — der Text über die volle Satzbreite
    (`Textmass.hoehe`) und alle Bilder zusammen in Reihen
    (`Layoutautomat.stapelhoehe`), beide mit den Funktionen, die hinterher
    auch SETZEN. Eine zweite Schätzung daneben liefe auseinander, und dann
    hielte die Seite nicht, was der Plan sagt.
  - **Aus dem Verhältnis folgt die GANGART, aus der Summe die Zahl der
    Seiten** — und das sind genau die drei Fälle, die der Nutzer genannt hat:
    `bilderreich` (unter einem Fünftel Text: der Text bleibt beisammen, danach
    dürfen reine Bilderseiten stehen), `ausgewogen` (auf jeder Seite beides),
    `textreich` (über sieben Zehnteln: Bilder neben dem Text).
  - **Die Seitenzahl ist eine Schätzung mit Absicht.** Sie steuert die
    Verteilung und ist keine Zusage; was am Ende übrig ist, kommt auf eine
    zusätzliche Seite. Wie viele Kacheln auf die Seite gehören, wird bei JEDER
    Seite neu aus dem Offenen gerechnet und nicht beim Start festgelegt —
    sonst stimmte die Verteilung nicht mehr, sobald eine Seite mehr aufnimmt
    als geplant.
  - **Nichts daran ist gewürfelt und nichts hängt an der Kennung des Tages.**
    Derselbe Inhalt ergibt denselben Satz; die Abwechslung kommt aus dem
    Inhalt und aus dem Wechsel der Seitenstellung.
- **Eine Reihe SCHRUMPFT, bevor sie umbricht** (`Layoutautomat.reihenIn`, ab
  1.0.34). Gemeldet: „Das einzige Foto … erscheint nun super groß auf einer
  leeren Seite 4. Dabei wäre auf Seite 3 noch Platz gewesen." Zwei Ursachen,
  beide nachzurechnen: Der Text bekam die ganze Seite, obwohl noch ein Bild
  für sie vorgesehen war (freigehalten wurde nur, wenn Reihe UND sechs Zeilen
  danebenpassten, sonst gar nichts) — und die Seite brach um, sobald die
  nächste Reihe in ihrer ZIELHÖHE nicht mehr hineinpasste, worauf dieselbe
  Reihe auf der neuen, leeren Seite wachsen durfte (`ausfuellendesZiel` aus
  1.0.32). Eine Reihe ist aber kein festes Maß: Ihre Höhe folgt aus der
  Zielhöhe, und die lässt sich für diese eine Reihe senken. **Erst wenn auch
  das nichts mehr hergibt, bleibt der Umbruch.**
- **Ein Band folgt dem SEITENVERHÄLTNIS, sonst ist es ein Ausschnitt** (ab
  1.0.34, gemeldet: „Auf der Seite 5 ist ein Ausschnitt eines Fotos auf die
  ganze Seitenbreite gezogen. Das macht keinen Sinn."). Das Aufmacherband aus
  1.0.32 stand fest auf gut einem Drittel der Satzhöhe bei voller Satzbreite —
  und weil ein Rahmen GEFÜLLT und nicht eingepasst wird (`Bildausschnitt`),
  wurde aus einem Hochformat ein Streifen quer durch das Bild. Gedeckelt wird
  jetzt die HÖHE, was an Breite fehlt, bleibt Rand, und ein Band bekommt nur
  ein Querformat. **Wer einen Rahmen setzt, dessen Verhältnis vom Bild
  abweicht, hat einen Ausschnitt gewählt — absichtlich beim Vollbild, versehentlich
  überall sonst.**
- **Ein Bild NEBEN dem Text, und der Text läuft darunter weiter**
  (`Seitenform.seitlich`, ab 1.0.34). Antwort auf zwei Punkte zugleich: auf
  Seite 6 („könnte zumindest eins der Fotos noch neben den Text gezogen
  werden und die anderen Fotos entsprechend verteilt") und auf den dritten
  der drei Fälle („bei sehr viel Text und wenig Bildern … dass der Text sie
  umfließt"). Umflossen wird in einem **L**: eine schmale Spalte neben dem
  Bild, darunter die volle Breite — zwei Blöcke, kein neuer Satz.
  **Ein Bild, das auf BEIDEN Seiten Text hat, ist bewusst nicht gebaut:**
  CoreText legt einen Rahmen in ein Rechteck; alles andere verlangte, jede
  Zeile einzeln zu setzen, also einen zweiten Umbruch neben dem, mit dem
  `Textmass` misst — und der Textblock wäre danach nicht mehr das, was man in
  dieser App anfassen, verschieben und teilen kann.
- **Drei Fotos in einer Flucht sind ein Raster, kein Satz** (ab 1.0.34,
  gemeldet zu Seite 7). In Stilen mit `Buchstil.lebendig` liegen die Kacheln
  einer Reihe wieder gegeneinander versetzt und leicht gedreht — mit dem
  Winkel aus der Kennung des Fotos, also bei jedem Neuanordnen demselben. Und
  eine Reihe, die ihre Zielhöhe nicht erreicht, steht **mittig** statt
  linksbündig: Ein einzelnes Bild an der linken Kante sieht aus wie der Rest
  einer Reihe.
- **`Seitenmuster.wechsel` heißt „Nach Inhalt gesetzt" und ist der REGELFALL**
  (ab 1.0.34). Bis 1.0.33 verlangte es über 1200 Zeichen und mindestens vier
  Fotos. Genau daran scheiterte der 3. August im gemeldeten Buch: Ein Tag mit
  Text und EINEM Foto fiel durch die Schwelle und landete bei einem Muster
  ohne Planer. Jetzt greift es, sobald ein Tag Text UND Bild hat; ohne eines
  von beidem gibt es nichts zu verteilen, und die eigenen Bildideen der
  übrigen acht Muster sind die bessere Antwort. Dieses eine Muster geht weder
  durch den Musterschalter noch durch `reihenSetzen` — ein Satz, der sich nach
  dem Inhalt richtet, lässt sich nicht als Sonderfall in eine Kette einbauen,
  die Text und Bilder nacheinander abarbeitet; er muss beide zugleich vor sich
  haben.
- **Nicht gemessen (1.0.34):** Keine Seite ist damit gesehen worden. Gerechnet
  ist, WARUM das Foto auf der leeren Seite landete, warum das Band ein
  Ausschnitt wurde und was der Rhythmus mit dem Inhalt zu tun hatte (nichts).
  **Gewählt und nicht gemessen sind alle Zahlen im Planer** — die beiden
  Gangart-Schwellen (0,20 und 0,72), die Spaltenbreite des seitlichen Bildes
  (0,40 der Satzbreite) und seine Höhe (höchstens 0,46), die Bandhöhe (0,40),
  der Zuschlag von einem Viertel auf den Textanteil je Seite und die zwölf
  Zeilen, ab denen ein Bild neben den Text darf. **Und es sind mehrere Dinge
  auf einmal geändert**: Die Regel „eine Sache auf einmal" ist hier bewusst
  gebrochen, weil die fünf gemeldeten Seiten EINE gemeinsame Ursache haben —
  fünf Fassungen nacheinander hätten sie einzeln kuriert, ohne sie zu beheben.
- **TEXT IST EIN FELD WIE EIN FOTO — und die Seite wird GEFÜLLT**
  (`Model/Mosaik.swift`, ab 1.0.35; Diagnose des Nutzers 09/2026 im Vergleich
  mit einer fremden Foto-App: „ob ein grundlegendes Problem vielleicht ist,
  dass du Text auf der einen Seite und Bilder auf der anderen Seite als
  streng getrennte Formate betrachtest. Ich glaube, ich hätte gedacht, dass
  Text ein gleichberechtigtes Gestaltungselement einer Seite ist, wie auch
  ein Foto." — dazu der Befund: dort seien „die Bilder wesentlich größer und
  verschenken wesentlich weniger Platz auf der Seite"). **Er hat recht, und
  es stand so im Quelltext**: Eine Seite bestand aus einer TEXTSPALTE und
  darunter aus FOTOREIHEN, und die sechs Seitenformen aus 1.0.34 waren
  allesamt Antworten auf die Frage, in welcher REIHENFOLGE beide kommen —
  eine Frage, die es nur unter dieser Annahme gibt. `Seitenform` ist deshalb
  **ersatzlos entfernt**, wie `Seitenrhythmus` eine Fassung zuvor.
  - **Eine Seite ist eine SPALTE aus Reihen, die zusammen die volle Satzhöhe
    ergeben.** Bis 1.0.34 rechnete `zielhoehe` die Reihenhöhe allein aus der
    ZAHL der Kacheln und sah die Seite nie an; was unten übrig blieb, schob
    `restplatzVerteilen` in die Lücken. **Damit war weißer Platz der
    Normalfall und ein großes Bild der Ausnahmefall.**
  - **Gesucht wird über die ZAHL der Reihen, nicht über eine Formel**
    (`Mosaik.beste`, eins bis vier): Eine größere Zielhöhe nimmt Kacheln aus
    den Reihen heraus und kann eine Reihe MEHR ergeben — derselbe nicht
    monotone Zusammenhang wie bei `ausfuellendesZiel` seit 1.0.32. Gewertet
    wird die Dehnung.
  - **Ein Text hat kein Seitenverhältnis, sondern zu jeder Breite eine
    gemessene Höhe** (`Mosaik.mischreihe`). Probiert werden zwölf Breiten
    zwischen 30 und 70 Prozent der Satzbreite; genommen wird die, bei der die
    Fotohöhe gerade noch über der Texthöhe liegt. Eine Umkehrfunktion gibt es
    nicht — die Texthöhe springt von Zeile zu Zeile. Gemessen wird vom
    AUFRUFER (`Textmass`, also derselbe Satz, der zeichnet) und als Abschluss
    hereingereicht; `Mosaik` selbst enthält nur Arithmetik.
  - **Wie viele Bilder auf eine Seite gehören, entscheidet der PLATZ.**
    `Tagesplan` schlägt eine Zahl vor, die Seite prüft sie: Bleibt Luft,
    kommt ein Bild dazu; wird es eng, geht eines zurück (bis zu zehn
    Anläufe). **Nicht die Zahl der Bilder bestimmt den Satz, sondern der
    Platz bestimmt die Zahl der Bilder.**
  - **Die Dehnung ist auf 1,22 gedeckelt.** Gedehnt heißt: Das Bild wird
    höher, als sein Verhältnis vorgibt, und verliert seitlich gut 18
    Prozent — der Rahmen wird GEFÜLLT, nicht eingepasst. Mehr wäre genau der
    Ausschnitt, den 1.0.34 am Aufmacherband abgestellt hat. Reicht der Deckel
    nicht, bleibt der Rest als Luft zwischen den Reihen stehen: Lieber etwas
    Weiß als ein Bild, dem ein Fünftel fehlt.
  - **Was daraus von selbst folgt**, ohne einen einzigen Sonderfall: Text
    neben einem Foto, wo der Text kurz ist; Text über die volle Breite, wo er
    mehr als die halbe Seite braucht; eine reine Bilderseite, wo kein Text
    mehr wartet. In der Gangart `bilderreich` bleibt der Text ganz auf der
    ersten Seite (Ansage des Nutzers: „den Text nicht noch weiter
    auseinanderzuziehen").
  - **Die Seitenschätzung des Plans rechnet jetzt mit einer Reihenhöhe von
    einem Drittel der Seite** statt mit `zielhoehe`. Seit die Reihen die
    Seite füllen, schätzte die alte Zahl die Bilder zu klein und damit den
    Tag zu kurz.
- **Nicht gemessen (1.0.35):** Keine Seite ist damit gesehen worden.
  Gerechnet ist die Geometrie; **gewählt und nicht gemessen** sind die
  Dehnungsgrenze 1,22, die Spanne der Textbreite (30 bis 70 Prozent), die
  zwölf Stufen, die Schwelle von 56 Prozent Seitenhöhe für die volle Breite
  und die Reihenzahl eins bis vier. **Ungemessen ist auch der Preis der
  Rechnung**: bis zu zwölf CoreText-Messungen je Seite für die Textbreite,
  dazu je Anlauf der Bildzahl eine neue Aufteilung. Das läuft beim
  Neuanordnen und nicht beim Zeichnen — gesehen hat es trotzdem niemand.
- **EINE REIHE IST EIN STAPEL, KEIN RASTER** (`Layoutautomat.querfuge`,
  `.staffelhub`, `.neigung`, ab 1.0.36; Befund des Nutzers 09/2026 zu 1.0.35:
  „Allerdings ist die Anordnung der Fotos jetzt schon wieder sehr, sehr
  nüchtern. Alle sind rechtwinklig ausgerichtet, keins davon leicht gedreht
  oder gar so, dass sich eine Ecke überlappt."). **Er hat recht, und es war
  ein Rückschritt von mir**: 1.0.34 hatte das Staffeln und Drehen in
  `reihenIn` eingebaut — und 1.0.35 hat genau diese Funktion durch das Mosaik
  ersetzt, samt der Mechanik darin. **Wer eine Funktion ablöst, zählt vorher
  auf, was in ihr steckte** — sonst löst man mit dem Fehler auch das mit, was
  schon richtig war.
  - **`Mosaik` hat seit 1.0.36 ZWEI Fugen**: `quer` innerhalb einer Reihe,
    `fuge` zwischen den Reihen. Bis dahin war es ein einziger Wert, und damit
    ließ sich „zwei Bilder überlappen einander" gar nicht ausdrücken — ein
    negativer Wert hätte auch die Reihen ineinandergeschoben.
  - **Überlappt wird in der RECHNUNG, nicht erst beim Setzen.** `quer` darf
    negativ sein; `reihenhoehe` rechnet dann mit `breite - quer * (n-1)`, die
    Kacheln werden BREITER und die Reihe höher, und die Satzbreite bleibt
    gefüllt. Wer die Kacheln bloß beim Zeichnen enger rückte, ließe rechts
    einen Streifen stehen — also genau das, was 1.0.35 abgestellt hat.
  - **Der Staffelhub gehört ebenfalls in die Rechnung** (`staffel` je Reihe,
    nur ab zwei Kacheln — dieselbe Bedingung in `Mosaik.spalte` und beim
    Setzen). Sonst hielte die Spalte ihre Höhe nicht, sobald versetzt wird.
  - **Nur in Stilen mit `Buchstil.lebendig`** (Tagebuch, Album, Postkarte).
    In einem Magazin wäre ein schiefes Bild ein Fehler, in einem Album fehlte
    es.
  - **Der Winkel kommt aus der KENNUNG des Fotos** (`drehwinkel`, ±2,1°),
    nie aus dem Zufall: Ein Satz, der sich bei jedem Neuanordnen anders
    neigt, ist kein Satz, sondern ein Würfel. **Die Karte wird nicht
    gedreht** (sie ist eine Auskunft, kein Erinnerungsstück), **die
    Bildunterschrift auch nicht** — sie würde um ihre EIGENE Mitte gedreht
    und rückte damit vom Bild ab.
  - **`Block.ebene` entscheidet, wer obenauf liegt** (`Seite.sortiert`). Jede
    zweite Kachel sitzt höher UND liegt oben; so sieht die Überlappung gelegt
    aus und nicht verrutscht.
  - **Der alte Weg staffelt und dreht wieder mit** (`reihenSetzen`, die acht
    übrigen Muster) — ein Tag ganz ohne Text kommt nicht durch das Mosaik.
    **Überlappt wird dort NICHT**: Die Breiten rechnet `naechsteReihe` mit der
    ganzen Fuge, und zwei Rechnungen nebeneinander liefen auseinander.
- **Das Wort „Bildunterschrift …" war die „Regieanweisung"** (ab 1.0.36,
  gemeldet 09/2026: „an manchen Stellen steht Text, der wie eine
  Regieanweisung wirkt. Ich weiß nicht, wo das herkommt."). **Woher es kommt,
  ist am Quelltext abzulesen und nicht geraten:** Auf eine Seite schreibt die
  App von sich aus nur vier Texte — die Seitenzahl, die Kopfzeile, „Kartenbild
  fehlt" (nur wo eine Karte fehlt) und, auf dem Bildschirm, den Platzhalter
  einer leeren Bildunterschrift. Nur der letzte wiederholt sich. Und
  `SeitenflaecheView.unterschriftOeffnen` schaltet die Unterschrift bei einem
  **Doppeltipp auf das Foto** ein — also mit demselben Griff, mit dem man Text
  bearbeitet. Wer danach nichts schreibt, hat das Wort von da an unter dem
  Bild stehen.
  - **Statt des Wortes steht dort eine MARKE** — eine dünne Linie. Der Grund
    für die Anzeige bleibt richtig (eine eingeschaltete Unterschrift ohne Text
    wäre sonst eine unsichtbare Fläche, die sich nicht antippen lässt); was
    falsch war, ist das WORT. Ins PDF geht beides nicht.
  - **Gezählt wird trotzdem** (`Druckpruefung.leereUnterschriften`): Der Block
    hält weiterhin eine Zeile unter dem Foto frei, und im Druck ist das eine
    leere Zeile, die niemand bestellt hat. Die Zeile nennt Tag und Seite.
  - **Und es gibt einen Ausweg** (`Reisewerk.leereUnterschriftenAbschalten`,
    „…" oben rechts): Ein Hinweis ohne Weg, ihn aufzulösen, ist die Frage von
    vorhin noch einmal. Gemerkt wird dabei EINMAL und nicht je Foto — der
    Rückgängig-Stapel ist flach (25 Stände), und zwanzig Einzelschritte hätten
    ihn geleert.
- **Text um ein Foto herum ist weiterhin nicht gebaut**, und der Nutzer hat
  das ausdrücklich hingenommen („wird wahrscheinlich nicht möglich sein").
  Der Grund steht seit 1.0.34 da: CoreText legt einen Rahmen in ein Rechteck;
  alles andere verlangte, jede Zeile einzeln zu setzen — also einen zweiten
  Umbruch neben dem, mit dem `Textmass` misst.
- **Nicht gemessen (1.0.36):** Keine Seite ist damit gesehen worden.
  Gerechnet ist die Geometrie (dass die Satzbreite bei negativer `quer` gefüllt
  bleibt, dass der Staffelhub in die Spaltenhöhe eingeht). **Gewählt und nicht
  gemessen** sind alle drei Zahlen: die Überlappung (`-fuge * 1,1`), der
  Staffelhub (`fuge * 0,9`) und der Winkel (±2,1° aus 1.0.34). Ob das auf
  einer gedruckten Doppelseite nach „hingelegt" aussieht oder nach
  „verrutscht", sagt erst der nächste Befund — und wie weit die gedrehten
  Ecken am Satzspiegel überstehen, ist ebenfalls nur gerechnet. **Und der
  Befund zur „Regieanweisung" ist am Quelltext hergeleitet, nicht an seinem
  Buch nachgesehen**: Sollte er etwas anderes gemeint haben, steht es in
  seinem eingelesenen Text und nicht in der App. **Nichts davon als erledigt
  darstellen.**
- **DER ABSATZ GEWINNT — immer** (`Textmass.teilen`, ab 1.0.37; Ansage des
  Nutzers 09/2026, zum zweiten Mal: „Ich hatte aber gesagt, dass die
  Trennstellen dabei nach den Absätzen sein sollen. Ich finde aber
  Trennstellen, die quasi mitten im Text passieren."). Er hat recht, und die
  Stelle ist auszurechnen: Bis 1.0.36 stand dort ein `mindestfuellung` von
  0,62 — die Absatzgrenze galt nur, wenn der Kopf danach noch 62 Prozent des
  Kastens füllte, sonst wurde an der WORTgrenze geteilt.
  **Die Abwägung war seit 1.0.35 hinfällig, und das ist der ganze Befund.**
  Gebaut wurde sie in 1.0.14 gegen eine große weiße Fläche am Seitenfuß —
  damals bestand eine Seite aus einer Textspalte und darunter aus
  Fotoreihen, und was der Text nicht brauchte, blieb Papier. Seither füllt
  `Mosaik` die Seite: Was der Text nicht braucht, bekommen die Bilder, und
  `seiteFuellen` nimmt so lange ein Bild dazu, bis der Platz aufgeht. Die
  Lücke, gegen die die Regel gebaut war, gibt es nicht mehr — sie stand nur
  noch da und hat geschadet. **Merke: Wer eine Regel stehen lässt, deren
  Grund eine spätere Fassung beseitigt hat, baut einen Fehler ein, den
  niemand mehr begründen kann** (dieselbe Lehre wie beim Rückbau von 1.0.25
  und beim Wegfall von `Seitenrhythmus` und `Seitenform`).
  Ersatzlos entfernt und NICHT auf 0 gestellt: Ein Parameter, der nur noch
  einen Wert haben darf, wird irgendwann wieder ein anderer (dieselbe Regel
  wie beim Sperrmechanismus in Schulalarm 1.1.0). An der Wortgrenze wird nur
  noch geteilt, wo es im Kasten ÜBERHAUPT keine Absatzgrenze gibt — ein
  einzelner Absatz, der für sich schon länger ist als der Platz.
- **Und diese Stellen werden GEZÄHLT** (`Druckpruefung.mittenImSatz`, ab
  1.0.37). Sonst wäre „der Absatz gewinnt" eine Zusage, die sich niemand
  ansehen kann. Gemessen wird am ERGEBNIS und nicht an der Absicht: Ein
  Textblock, der nicht mit einem Satzzeichen aufhört und dem ein weiterer
  folgt, endet mitten im Satz — unabhängig davon, was die Teilung gemeint
  hat, und damit die ehrlichere Zahl.
- **DIE TEXTSPALTE HAT EINE HÖCHSTBREITE** (`Gestaltung.textspaltenanteil`,
  Vorgabe 0,66, ab 1.0.37; Ansage des Nutzers 09/2026: „Mir fällt auf, dass
  der Text des Tagebuches in der Regel über die gesamte Breite einer Seite
  geht. Das finde ich nicht gut, denn ich denke, er ist besser lesbar, wenn
  er maximal über zwei Drittel der Seite geht.").
  - **Gemessen wird gegen die SATZBREITE, nicht gegen den freien Raum.**
    Sonst käme ein Deckel auf den anderen: Bei „Karte neben dem Text" ist
    die Spalte schon auf gut die halbe Satzbreite eingeengt, und zwei
    Drittel DAVON wären ein Streifen. Es ist eine Obergrenze und keine
    Vorschrift — wer ohnehin weniger bekommt, behält, was er hat.
  - **Eine Zahl, EINE Stelle** (`Layoutautomat.satzTextbreite`). Gefragt
    wird sie überall, wo bisher `satz.width` für einen Textblock stand:
    beim Messen für den Plan, beim TEILEN und beim Setzen. Liefen die drei
    auseinander, würde an einer Breite geteilt und in einer anderen
    gesetzt — der Text wäre auf der Seite anderthalbmal so hoch wie
    gerechnet und liefe unten heraus.
  - **Der Deckel gilt auch im alten Weg** (`textSpalte`, also die acht
    übrigen Muster). Ihn nur im Mosaik zu ziehen hieße, dass „Text zuerst"
    und „Karte oben" weiter Zeilen von neunzig Zeichen ergäben.
  - **Wie viele Zeichen wirklich auf einer Zeile stehen, MISST die App**
    (`Textmass.zeichenJeZeile`, Zeile in der Druckprüfung). Eine
    Einstellung, die sich auf eine Behauptung stützt, wäre in diesem Buch
    die falsche. Gezählt wird mit demselben CoreText-Umbruch, der zeichnet;
    die letzte Zeile bleibt draußen, weil sie dort endet, wo der Text
    aufhört. **Die Spanne 45 bis 75 Zeichen ist Handwerk des Schriftsatzes
    und an diesem Buch NICHT nachgeprüft** — die Zeile sagt das auch.
- **Die Textreihe steht an jeder Stelle der Spalte** (ab 1.0.37, Ansage des
  Nutzers: „Auch hier wäre es dann gut, vielleicht verschiedene Textblöcke
  zu haben, die sich mit den Bildern abwechseln."). Bis 1.0.36 gab es zwei
  Lagen — ganz oben oder ganz unten (`textOben = nummer % 2 == 0`); einen
  Wechsel gab es damit nur von Seite zu Seite, nicht auf der Seite. Die
  Textreihe ist jetzt eine Reihe unter den anderen: 0 heißt oben,
  `reihen.count` unten, alles dazwischen ZWISCHEN zwei Fotoreihen. Gewählt
  aus der Seitennummer und nicht gewürfelt — derselbe Inhalt ergibt
  denselben Satz.
  - **Bricht eine Reihe ab, bricht ALLES ab** (`abgebrochen`). Die Kacheln
    liegen in einer Folge, und `seiteFuellen` nimmt hinterher die ersten
    `gesetzteKacheln` aus dem Vorrat. Würde Reihe 2 übersprungen und Reihe 3
    gesetzt, wären zwei Bilder vertauscht — still und unauffindbar.
  - **`restplatzVerteilen` läuft nur im LETZTEN Abschnitt.** Im oberen liefe
    die gewonnene Luft in den Textblock hinein, und die Funktion kennt ihn
    nicht: Sie verschiebt nur die Reihen, die sie bekommt.
- **Die Reisepunkte auf der Buchkarte waren eine Perlenkette**
  (`Spurpunktstil`, ab 1.0.37; Befund des Nutzers 09/2026: „Diese Punkte
  haben eine bestimmte Farbe und einen Kreis um sich herum. Das sieht etwas
  merkwürdig aus. Ich habe noch keine richtige Lösung dafür."). Am Quelltext
  abzulesen und kein Eindruck: Je Punkt wurde ein VOLLER weißer Kreis
  gezeichnet und darauf ein farbiger Kern von 58 Prozent des Radius — der
  Rest war ein weißer Ring von fast einem Viertel des Durchmessers. Bei
  dreißig Fotopunkten an einem Tag übernimmt der die Karte. Gedacht war er
  als KONTRAST (dieselbe Rechnung wie unter der Linie); als Zeichnung war er
  zu laut. **Weil der Nutzer ausdrücklich sagt, er habe noch keine Lösung,
  ist keiner seiner drei Auswege weggelassen**: `ohne` (nur die Linie),
  `dezent` (volle Punkte in der Linienfarbe mit haardünner Kontur — die
  Vorgabe), `enden` (nur Anfang und Ziel) und `ring` (der alte, dünner).
  **Eine Kontur ist kein Ring**: Sie liegt AUF der Kante und nimmt dem Punkt
  nichts weg. Und `punktstil` steht im `merkmal` des Zwischenspeichers —
  eine vergessene Stelle im Schlüssel zeigt nach dem Umstellen das Bild von
  vorhin, und das sieht aus, als tue der Schalter nichts.
- **Einen Punkt findet man auf der KARTE, nicht in der Liste**
  (`PunktwahlView`, ab 1.0.37; Befund des Nutzers 09/2026: „Ich möchte die
  Reisepunkte auf einer Karte, die möglichst bildschirmfüllend ist,
  auswählen können und verschieben können bzw. löschen können. Innerhalb der
  Liste ist es schwierig, einen bestimmten Punkt wiederzufinden."). Die
  Karte gab es seit 1.0.20, bildschirmfüllend, samt Verschieben und
  Löschen — nur der WEG hinein führte über die Liste: `punktID` war ein
  `let` von außen, und die Punkte auf der Karte waren `Marker`, also
  unantastbar. Siebte Auflage von „es war da, man fand es nicht", und
  diesmal fehlte nicht der Knopf, sondern der Weg zu ihm.
  - **`punktID` ist ein ZUSTAND.** Ein Tipp auf einen Punkt wählt ihn, die
    Leiste nennt ihn beim Namen und sagt, der wievielte er ist; „Neuer
    Punkt" führt zurück. Ohne diesen Rückweg käme man, einmal auf einem
    Punkt gelandet, nie wieder zum Anlegen.
  - **Auf der Karte liegt kein Bedienelement** (`.allowsHitTesting(false)`,
    Lehre aus Abfahrtstafel 1.1.18). Den Tipp nimmt die Karte entgegen und
    sucht HINTERHER den nächsten Punkt — in BILDPUNKTEN und nicht in Grad,
    denn was „nah" heißt, hängt am Maßstab. Gerechnet wird erst, wenn klar
    ist, dass ein Tipp gemeint war; die Griffweite kostet damit keine
    Kartenfläche.
  - **Verschoben wird über das FADENKREUZ, nicht durch Ziehen des Punktes.**
    Eine Ziehgeste auf einer Karte streitet mit dem Schieben der Karte — und
    genau diese Art Geste hat dieses Projekt von 1.0.5 bis 1.0.8 gekostet.
  - **Löschen schließt das Blatt nicht mehr.** Wer Punkte auf der Karte
    durchsieht, löscht oft mehrere; ein Blatt, das nach jedem Löschen
    zugeht, macht aus drei Handgriffen dreimal denselben Weg.
- **Die Broschüre lag drei Ebenen tief** (ab 1.0.37, gemeldet 09/2026: „Noch
  nicht gefunden habe ich die gewünschte Option, das Reisetagebuch auf dem
  heimischen Drucker doppelseitig als Broschüre drucken zu können"). Es gibt
  sie seit 1.0.27 und sie ist vollständig gebaut. Gefunden hat sie niemand,
  und daran waren drei Dinge auf einmal schuld: das falsche Menü („…" →
  „Als PDF sichern…" klingt nach einer Datei und nicht nach einem Drucker),
  ein zugeklappter Picker darüber, und dessen Name „Umfang" — ein Wort, das
  nach Seitenzahl klingt. Jetzt ein eigener Menüpunkt **„Broschüre
  drucken…"**, sprechende Namen im Picker („Broschüre zum Selberfalten"),
  und je ein Satz darunter, was dahintersteht. **Kein zweiter Bildschirm:**
  derselbe, nur mit Vorwahl — ein zweiter Weg zu derselben Sache liefe
  irgendwann auseinander.
- **Und sie stand mit dem RICHTIGEN Weg in der Bedienungskarte.** Seit
  1.0.27, wörtlich. Gefunden wurde sie trotzdem nicht. **Merke: Eine
  Bedienungskarte ist ein Nachschlagewerk für jemanden, der etwas Bestimmtes
  sucht — sie ersetzt keinen auffindbaren Menüpunkt.** Wer eine Funktion für
  auffindbar hält, weil sie dort steht, hat die Frage nicht beantwortet,
  sondern verschoben.
- **Gedruckt wird aus der App heraus** (`Druckauftrag`, ab 1.0.37). Bis
  1.0.36 gab es nur eine Datei zum Teilen; sie erst zu sichern, dann in
  „Dateien" zu suchen und von dort zu drucken, ist der Umweg um genau den
  Knopf herum, um den gebeten wurde. `UIPrintInteractionController` zeigt
  sich SELBST — eingebettet in ein SwiftUI-`.sheet` bliebe das Blatt
  schwarz; dieselbe Lehre wie beim Teilen-Blatt und beim Dateiwähler in
  Tafelbild. **`duplex` ist ein WUNSCH, keine Einstellung:** Was der Drucker
  tut und über welche Kante er wendet, entscheidet der Mensch im Dialog, und
  die App kann es weder setzen noch auslesen — deshalb steht daneben
  weiterhin der Schalter „Rückseiten um 180° drehen" und keine Automatik.
  Das Fenster für den Anker kommt aus der Szene DIESER App und nie aus
  `connectedScenes.first` (ungeordnete Menge — dieselbe Falle wie bei
  Tafelbilds Dokumentenkamera).
- **EIN GESETZTES BUCH ÄNDERT SICH NICHT VON SELBST** (`Neuverteilung`,
  „…" → „Alles neu verteilen…", ab 1.0.38; Frage des Nutzers 09/2026: „Ich
  frage mich, wie die nun geschaffene Funktion auf dem bereits eingegebenen
  Text angewendet werden kann. Vielleicht wäre eine Funktion sinnvoll, das
  Ganze einmal so weit zurückzusetzen, dass der Bild- und Textverteiler in
  Aktion treten kann.").
  Die Antwort auf die erste Hälfte lautet NEIN, und das ist kein Mangel: Was
  in `Gestaltung` und im `Layoutautomat` steht, wirkt beim SETZEN einer
  Seite; ein fertiges Buch trägt seine Blöcke als Rahmen im Modell. Würde
  eine neue Fassung das von selbst umstellen, bekäme jemand nach einem
  Update sein Buch neu gesetzt, ohne es gewollt zu haben. **Angestoßen wird
  es ausdrücklich** — und vorher steht Tag für Tag da, was dabei wegfällt.
  `alleNeuAnordnen(nurUnberuehrte: true)` gab es schon, es überspringt aber
  jeden Tag mit Handarbeit, und Handarbeit ist bereits ein verschobener
  Block; für jeden angefassten Tag hätte man einzeln ins Tagesmenü gemusst.
- **UND BEIM NACHSEHEN KAM DER EIGENTLICHE BEFUND HERAUS: Das Neusetzen
  verlor den auf der Seite geschriebenen Text** (`Reisewerk.wortlautSichern`,
  ab 1.0.38). `textSchreiben` legt einen bearbeiteten Fließtext in den BLOCK
  (Zweig `.text`), `Layoutautomat.seiten(fuer:)` setzt aber aus `tag.text` —
  und der weiß davon nichts. Wer also einen Tag mit bearbeitetem Text neu
  anordnen ließ, verlor seinen Wortlaut, STILL, denn die Seite steht ja
  danach da. **Das gab es schon lange vor dieser Fassung**: an „Seiten neu
  anordnen" im Tagesmenü und an beiden Muster-Wegen; „Alle unberührten Tage"
  war nur deshalb ungefährlich, weil es solche Tage übersprang. Der Wortlaut
  wandert jetzt VOR dem Setzen an den Tag zurück. **Der Aufruf gehört an
  JEDE Stelle, die Seiten setzt** — wer einen neuen Weg dorthin baut und ihn
  vergisst, baut denselben stillen Verlust wieder ein.
- **Eine Ansicht setzt keine Seiten** (`Reisewerk.musterSetzen`, ab 1.0.38).
  Zwei der vier Stellen, die den Automaten aufriefen, standen in ANSICHTEN
  (`TagInhaltView`-Picker und `ReiseView.musterSetzen`) und hatten dieselbe
  Folge zweimal gebaut — keine von beiden wusste vom Wortlaut in den
  Blöcken. Die Ansicht sagt, was gewollt ist; wie daraus Seiten werden,
  weiß das Werk. **Dass der Befund genau dort saß, wo der neue Kommentar
  davor warnt, ist kein Zufall: Er war schon da, bevor der Kommentar
  geschrieben war.**
- **Beim Zusammenfügen wird zuerst NACHGESEHEN, nicht geraten**
  (`Neuverteilung.zusammenfuegen`). Das Teilen hat die Ränder abgeschnitten
  (`trimmingCharacters`), also steht nirgends mehr, ob zwischen zwei Stücken
  ein Absatzwechsel lag oder ein Leerzeichen mitten im Satz. Beides falsch
  zu machen kostet: ein Leerzeichen statt eines Absatzes zieht zwei Absätze
  zusammen, ein Absatz statt eines Leerzeichens reißt einen Satz
  auseinander — und genau diesen Riss hat 1.0.37 gerade abgestellt. Kommen
  beide Stücke UNVERÄNDERT im Tagebuchtext vor, steht dort auch, was
  dazwischen lag; das deckt den häufigsten Fall ab (von zehn Kästen ist
  einer bearbeitet). Geraten wird nur an einer bearbeiteten Naht — Satzzeichen
  davor heißt Absatz —, und **wie oft, wird gezählt und hingeschrieben**.
  Gesucht wird das zweite Stück HINTER dem ersten: Stünde derselbe Wortlaut
  zweimal im Text, nähme eine Suche von vorn die falsche Stelle.
- **Zwei Fehler im eigenen Entwurf, beim Gegenlesen gefunden** (1.0.38) —
  beide hätten Text im Tagebuch beschädigt, und keiner wäre aufgefallen:
  - **`Seite.sortiert` ist die ZEICHEN-Reihenfolge** (nach `ebene`) und sagt
    über die LESE-Reihenfolge nichts. Der Automat setzt je Seite nur einen
    Textkasten, aber „Nach einem Absatz teilen" (1.0.14) kann zwei auf
    derselben Seite hinterlassen — dann stünde der zweite Absatz vor dem
    ersten im Tagebuchtext. Sortiert wird nach der LAGE (y, dann x).
  - **Zwei gleiche Stücke hintereinander zählen einmal.** Es gibt sie:
    `Druckpruefung.doppelterText` kennt seit 1.0.9 „derselbe Wortlaut in
    zwei Kästen auf einer Seite", und woher der zweite Kasten kommt, ist bis
    heute nicht geklärt. Ungeprüft stünde der Absatz hinterher DOPPELT im
    Tagebuchtext — ein Schaden, den die Rettungsfunktion selbst anrichtet.
    Eng gefasst auf das unmittelbare Nacheinander: Ein Tagebuch darf
    denselben kurzen Satz zweimal enthalten, nur nicht zweimal an derselben
    Stelle.
- **Was beim Neuverteilen BLEIBT und was WEGFÄLLT, steht vorher da.** Bleibt:
  Tagebuchtext, Überschrift, Datumszeile, Bildunterschriften (die stehen am
  Tag bzw. am Foto), die Fotos und die Reisepunkte. Fällt weg: Lage, Größe,
  Drehung und eigene Schrift der Blöcke, von Hand angelegte oder entfernte
  Seiten, geteilte Textkästen. Die harte Fassung fragt zusätzlich nach,
  bevor sie Handarbeit wegnimmt — dieselbe Regel wie beim Stilwechsel seit
  1.0.32, und eine Rückfrage, die nur eine Antwort zulässt, ist keine.
- **Eine `+`-KETTE MIT `?:` UND INTERPOLATION SPRENGT DEN TYPPRÜFER**
  (getroffen beim Bau von 1.0.38). `NeuverteilenView` trug einen `Text(…)`
  aus fünf per `+` verketteten Teilen, darin ein ternärer Ausdruck und ein
  `\(geratene)`. Der Übersetzer gab auf: „the compiler is unable to
  type-check this expression in reasonable time". **Lange `+`-Ketten aus
  reinen LITERALEN gehen in diesem Repo an hundert Stellen gut** — was sie
  sprengt, ist die MISCHUNG: `+`, `?:` und `\(…)` im selben Ausdruck. Jeder
  Teil für sich ist mehrdeutig (`+` gibt es für String und Zahl, `?:`
  verzweigt die Typen, Interpolation nimmt alles), und der Prüfer muss die
  Kreuzung aller Möglichkeiten durchgehen.
  **Gebaut wird so etwas außerhalb des Körpers**, Stück für Stück in eine
  `String`-Variable — dann ist jeder Schritt eindeutig. Die Meldung nennt
  übrigens nur die ERSTE solche Stelle einer Datei; wer sie behebt, sieht
  sich die anderen gleich mit an, statt einen zweiten roten Bau zu
  riskieren (in 1.0.38 standen noch drei daneben).
- **VERSCHIEBEN GAB ES, KOPIEREN NICHT — und beides war zu versteckt**
  (Blockmenü in der Fußleiste, `Reisewerk.blockKopieren`, ab 1.0.39; Befund
  des Nutzers 09/2026: „Ich suche noch nach der Funktion, Elemente auf eine
  andere Seite zu kopieren oder zu verschieben. Sie ist zu versteckt.").
  Achte Auflage von „es war da, man fand es nicht" — und diesmal mit einem
  Beleg dafür, dass es nie fertig gebaut wurde: **Über `seitenlage` stand
  seit 1.0.29 der Kommentar „Gebraucht an zwei Stellen (Inspektor und
  Blockmenü)", und das Blockmenü gab es nicht.** Ein Kommentar, der eine
  zweite Aufrufstelle behauptet, ist kein Beleg dafür, dass es sie gibt;
  dieselbe Wurzel wie bei jedem anderen Fall in diesem Papier, in dem ein
  Kommentar eine Prüfung ersetzen sollte.
  Verschieben lag im Block-Inspektor GANZ UNTEN, hinter Schrift, Wirkung,
  Lage und Ausschnitt — und der Inspektor selbst hinter dem Schieberegler
  in der Werkzeugleiste. **Der Inspektor ist der Ort für EINSTELLUNGEN; was
  man mit einem Block TUT, gehört dorthin, wo man ihn gerade anfasst.**
  Das Menü steht jetzt unten in der Leiste neben dem Tagesmenü, beschriftet
  mit der Art des Blocks, und erscheint nur bei gewähltem Block. Der
  Abschnitt im Inspektor bleibt: zwei Zugänge, dieselben Funktionen im Werk
  (die Regel aus 1.0.10).
- **Kopiert werden kann, was sich SELBST gehört** (`Reisewerk.kopierbar`,
  ab 1.0.39). Fotos, Karten, Linien und Flächen ja; Fließtext,
  Überschrift, Datumszeile und Bildunterschrift nein. Das ist keine
  Bequemlichkeit, sondern folgt aus dem Modell: Ein Tagebuchtext gehört dem
  TAG und steht einmal darin. Eine Kopie wäre im Druck derselbe Absatz
  zweimal — `Druckpruefung.doppelterText` meldet genau das seit 1.0.9 als
  Fehler —, und `Neuverteilung.fliesstexte` schriebe ihn beim nächsten
  Neuverteilen DOPPELT in den Tagebuchtext zurück. Der Grund steht im
  Fußtext des Inspektors; im Menü fehlt der Eintrag ganz, statt ausgegraut
  dazustehen: **Ein Knopf ohne Wirkung ist für den Menschen davor ein
  kaputter Knopf, ein fehlender wird nicht gesucht.** Wer einen Textkasten
  aufteilen will, teilt ihn — das ist die Sache, die dahinter gemeint ist.
- **Eine Kopie erbt keine Kennung** (dieselbe Lehre wie Tafelbild 1.4.5).
  Zwei Blöcke mit derselben `id` sind für jede Suche EIN Block:
  `Reisewerk.block(_:)` fände immer nur den ersten, und der zweite ließe
  sich nie wieder anfassen. Auf derselben Seite liegt die Kopie zudem
  VERSETZT und auf den Satzspiegel geklemmt — deckungsgleich sähe sie aus,
  als wäre nichts geschehen, und der nächste Griff verschöbe das Original.
- **Zwei eigene Fallen beim Gegenlesen von 1.0.39 gefunden**, beide
  namentlich in diesem Papier: ein `min` über eine `CGRect`-Kante und einen
  `Double` (die CGFloat-Falle aus 1.0.37 — jetzt mit `Double(…)` darum),
  und ein Menükörper aus verschachtelten Sections, Bedingungen und
  `ForEach` (die Typprüfer-Falle aus 1.0.38 — jetzt drei Funktionen). **Die
  Regeln zu kennen genügt nicht; sie müssen am eigenen Diff angewandt
  werden, bevor der Bau es tut.**
- **`hyphenationFactor` IST EIN FELD VON TEXTKIT — CoreText wirft es weg**
  (`Model/Silbentrennung.swift`, ab 1.0.40; gemeldet 09/2026 mit
  Bildschirmfoto: „Trotz aktivierter Silbentrennung sieht es dann so aus"
  — Blocksatz mit handbreiten Lücken und keinem einzigen Trennstrich).
  **Die Ursache ist am Quelltext abzuzählen und keine Vermutung:**
  `Schriftbild.attribute` setzt `NSMutableParagraphStyle.hyphenationFactor`,
  gesetzt wird die Seite aber mit CoreText. Reicht man CoreText eine
  `NSAttributedString`, übersetzt es den `NSParagraphStyle` in einen
  `CTParagraphStyle` — und dessen Aufzählung `CTParagraphStyleSpecifier`
  kennt Ausrichtung, Einzüge, Zeilenhöhen, Absatzabstände und den
  Umbruchmodus. Eine Silbentrennung steht nicht darin, also fällt das Feld
  beim Übersetzen weg.
  **Damit hat der Schalter „Silben trennen" von 1.0.0 bis 1.0.39 NICHTS
  getan** — weder auf dem Bildschirm noch im PDF, denn beide gehen durch
  `Seitensatz.zeichneText`. **Merke: Ein Attribut, das im Modell steht, ist
  noch nicht gesetzt.** TextKit und CoreText nehmen dieselbe
  `NSAttributedString` entgegen und werten NICHT dieselben Schlüssel aus.
- **Warum es nie auffiel: im Textfeld wirkte es.** `TextflaecheBruecke` ist
  ein `UITextView`, setzt also über TextKit und liest `hyphenationFactor`
  sehr wohl. Beim Doppeltipp war der Text getrennt, auf der Seite darunter
  nicht — dieselbe Einstellung, zwei Satzmaschinen. Wer eine Einstellung an
  zwei Wege reicht, prüft sie an BEIDEN.
- **Und die App behauptete das Gegenteil.** `TypografieView` zeigte
  „Blocksatz ohne Silbentrennung reißt Löcher in die Zeilen" nur, SOLANGE
  der Schalter aus war. Wer ihn umlegte, sah die Warnung verschwinden und
  die Löcher bleiben. Ein Hinweis, der mit dem Schalter verschwindet, sagt
  aus: „erledigt" — und das war hier falsch. Seit 1.0.40 sagen die Zeilen
  darunter, woher die Trennstellen kommen, ob das Gerät überhaupt ein
  deutsches Wörterbuch hat und dass in Großbuchstaben nicht getrennt wird.
- **Getrennt wird weiterhin NICHT von uns.** Die Stellen kommen aus
  `CFStringGetHyphenationLocationBeforeIndex`, also aus demselben deutschen
  Wörterbuch des Systems, das TextKit benutzt hätte. Die Regel dieses Repos
  („eine selbst gebaute Trennung ist verboten, die deutsche ist nicht
  ableitbar, und eine falsche stünde für immer im gedruckten Buch") bleibt
  unangetastet — neu ist nur, dass die App das Wörterbuch selbst fragt und
  den Strich selbst einfügt.
- **Ein WEICHES Trennzeichen (U+00AD) wäre der naheliegende Weg und ist
  bewusst NICHT gebaut.** Ob CoreText es als Umbruchstelle nimmt und dabei
  einen sichtbaren Strich zeichnet, lässt sich hier nicht messen — und der
  Fehlerfall wäre der teuerste denkbare: ein Strich mitten im Wort auf jeder
  Seite des gedruckten Buches. Eingefügt wird deshalb ein ECHTER Strich
  (U+002D, nicht U+2010 — das Viertelgeviert fehlt in mancher Schrift, und
  eine fehlende Glyphe wäre ein Kästchen im Wort), und zwar nur dort, wo die
  Zeile ohnehin umbricht. Damit hängt nichts an einer Annahme über CoreText.
- **EIN Setzer je Absatz, nicht einer je Trennstelle.** Ein eingefügter
  Strich gehört zur ABLAUFENDEN Zeile; die nächste beginnt an einer Stelle,
  die es im Urtext gibt. `CTTypesetterSuggestLineBreak` lässt sich also
  weiter mit demselben Setzer fragen, und die Striche werden erst am Ende in
  den Text geschrieben. Ein Setzer je Trennstelle wäre der naheliegende Weg
  und quadratisch — bei einem `Mosaik`, das zwölf Spaltenbreiten
  durchprobiert, ist das der Unterschied zwischen Millisekunden und
  Sekunden.
- **Gemessen wird die Zeile MIT dem Strich, nicht die Zeile plus einen
  einzeln gemessenen Strich.** Der Unterschied ist die Unterschneidung
  zwischen letztem Buchstaben und Strich, und er entscheidet: Rechnete man
  zu knapp, passte die Zeile beim Setzen nicht mehr, CoreText bräche an der
  Lücke davor um — und der Strich stünde am ANFANG der nächsten Zeile mitten
  im Wort. Vorgeschaltet ist eine grobe Prüfung über denselben Setzer (die
  kostet nichts Zusätzliches); genau gemessen wird nur der eine Kandidat,
  der sie überstanden hat.
- **DIE BREITE GEHÖRT AN JEDE AUFRUFSTELLE VON `Textmass`** (ab 1.0.40).
  Seit die Trennung von Hand gesetzt wird, hängt der gesetzte Text an der
  Breite: Wo die Zeile umbricht, entscheidet, welches Wort getrennt wird.
  Messen und Zeichnen müssen deshalb dieselbe Breite nennen — sonst hätte
  der Setzer, der die Höhe ausrechnet, andere Striche als der, der die Seite
  zeichnet, und der Text liefe unten aus seinem Block. Genau die Regel, aus
  der `Textmass` überhaupt entstanden ist, eine Ebene tiefer.
- **`passtBis` rechnet auf den URTEXT zurück** (`Ergebnis.imUrtext`). Es
  sagt, wie viel Text auf eine Seite passt, und `teilen` schneidet danach
  den TAGEBUCHTEXT. Käme dort eine Länge aus dem gesetzten Text zurück,
  wanderten die eingefügten Striche über `Neuverteilung.fliesstexte` in
  `tag.text` — mitten in die Wörter, und zwar dauerhaft. **Wer einen Text
  für die Anzeige verändert, braucht den Weg zurück, bevor er ihn misst.**
- **Versalien bleiben ungetrennt, und das ist Absicht.**
  `Schriftbild.gesetzt` schreibt den Text dann groß, und `uppercased()` kann
  die Länge ändern (aus „ß" wird „SS"). Die Rückrechnung auf den Urtext
  ginge damit um ein Zeichen daneben, und ein Tagebuchtext verlöre beim
  nächsten Neuverteilen einen Buchstaben. Versalien stehen in Überschriften,
  und die sind kurz; die Oberfläche sagt es dazu.
- **Was das Wörterbuch vorschlägt, wird MITGELESEN.**
  `CFStringGetHyphenationLocationBeforeIndex` gibt auch das Zeichen zurück,
  das an die Stelle gehört. Für Deutsch ist das seit 1996 ein gewöhnlicher
  Trennstrich; schlägt es etwas anderes vor, könnte sich die Schreibung
  ändern (die alte „Zuk-ker"-Regel), und das wäre eine Entscheidung über den
  Text, die uns nicht zusteht — solche Stellen werden übersprungen.
- **Wie oft wirklich getrennt wurde, ZÄHLT die Druckprüfung**
  (`Druckpruefung.trennungsbefund`). Nach einem Schalter, der zehn Fassungen
  lang nichts tat, steht dort keine Zusage, sondern eine Zahl: so viele
  Trennstriche in so vielen Textblöcken, gezählt am gesetzten Buch. Ist sie
  null, obwohl der Schalter an ist, sieht man das, statt es zu vermuten.
- **Zwei Zahlen sind gewählt und nicht gemessen:** mindestens zwei Zeichen
  vor dem Strich und drei danach, und höchstens drei getrennte Zeilen
  hintereinander. Beides ist Handwerk des Schriftsatzes, an diesem Buch
  nicht nachgeprüft.
- **Nicht gemessen (1.0.40):** Keine Seite ist damit gesehen worden.
  Gerechnet und am Quelltext abgezählt ist die URSACHE — dass
  `hyphenationFactor` bei CoreText wegfällt — und die Geometrie der
  Einfügung. **Ungemessen bleibt der PREIS:** Die Trennung läuft bei jeder
  Messung mit, und `Mosaik` misst denselben Text in zwölf Breiten; der
  Zwischenspeicher fängt die Wiederholungen ab, aber wie sich ein Buch mit
  zwanzig Tagen beim Neuanordnen anfühlt, sagt erst der nächste Befund. Der
  Zeichenmesser unter „Bedienung prüfen" zählt die Dauer mit. **Nicht als
  erledigt darstellen.**
- **Nicht gemessen (1.0.39):** Nichts davon ist auf einem Gerät gesehen
  worden. Dass das Blockmenü auffindbar IST, folgt daraus, dass es unten in
  der Leiste steht und den Namen des Blocks trägt — gesehen hat es niemand,
  und eine Oberflächenänderung als gelöstes Bedienproblem auszugeben wäre
  genau die Behauptung, die dieses Papier sonst verbietet.
- **Nicht gemessen (1.0.38):** Nichts davon ist auf einem Gerät gesehen
  worden. Gerechnet ist, WARUM der Wortlaut verlorenging und wie er sich
  zurückholen lässt; **ungeprüft an echten Daten** ist, wie oft die Naht
  geraten werden muss — das sagt erst die Zahl in der Vorschau an einem
  wirklichen Buch. **Nicht als erledigt darstellen.**
- **Nicht gemessen (1.0.37):** Keine Seite ist damit gesehen worden.
  Gerechnet sind die Geometrie und die Ursachen; **gewählt und nicht
  gemessen** sind die Vorgabe 0,66 für die Textspalte (sie ist die Zahl aus
  der Ansage) und die Maße der Punkte (Radius `breite/130`, Kontur
  `breite/900`). Ob eine Doppelseite mit wandernder Textspalte ruhig wirkt
  oder unruhig, ob ein dezenter Punkt auf einer bunten Karte noch zu sehen
  ist und ob der Systemdruckdialog die Broschüre richtig auf das Papier
  bringt, sagt erst der nächste Befund. **Nichts davon als erledigt
  darstellen.**
- **DIE GRÖSSE EINES FOTOS WAR KEINE ENTSCHEIDUNG, SONDERN EINE
  NEBENWIRKUNG** (`Tagesplan.zielreihenhoehe`, `Mosaik`-Deckel, ab 1.0.42;
  Befund des Nutzers 09/2026: „Mir ist nicht klar, wie das zustande kommt,
  dass einige Fotos riesengroß auf der Seite platziert werden, während andere
  dort, wo der Text noch mit im Spiel ist, ein Bruchteil dieser Größe haben.
  Das ist nicht ausgewogen." — dazu ein Tag mit fünf Fotos, der über vier
  Seiten lief und am Ende Bilder allein auf der Seite stehen ließ).
  **Nachgerechnet an der Geometrie, nicht geraten:** Die Höhe einer
  randbündigen Reihe ist `Satzbreite / Σ Seitenverhältnisse`. Auf A4 mit den
  Vorgaberändern (Satz 178 × 261 mm) wird ein HOCHFORMAT allein in seiner
  Reihe 237 mm hoch — 91 Prozent der Satzhöhe; dasselbe Foto zu dritt misst
  45 mm. Faktor **5,3**, und welcher der beiden Fälle eintrat, hing allein
  daran, wie viele Kacheln zufällig auf dieser Seite gelandet waren.
  - **Und die Kachelzahl kam aus einer ZÄHLUNG**: `kachelnAufSeite` teilte
    die offenen Kacheln durch die geschätzten Restseiten. Korrigiert wurde
    danach allein über die DEHNUNG — und die sagt nur, ob die Spalte den
    Kasten füllt. Zwei randbündige Hochformate untereinander füllen ihn
    genauso gut wie sechs kleine Kacheln. Über die GRÖSSE sagt sie nichts,
    und deshalb konnte niemand sie steuern.
  - **Die Zielreihenhöhe ist gerechnet, nicht gewählt.** Eine Reihe der Höhe
    h trägt Kacheln mit der Verhältnissumme B/h; für alle Kacheln eines
    Tages (Summe S) sind das S·h/B Reihen, und die Spalte wird S·h²/B hoch.
    Die Spaltenhöhe wächst also mit dem QUADRAT der Reihenhöhe — und aus der
    Fläche A, die den Bildern an diesem Tag bleibt, folgt genau eine Höhe:
    **h = √(A·B/S)**. Mehr Bilder werden kleiner, weniger größer, stetig
    statt in Sprüngen. Gedeckelt auf 0,16 bis 0,42 der Satzhöhe.
  - **Eine Reihe darf SCHMALER sein als der Satz.** Was über dem Deckel
    (Zielhöhe × 1,3) läge, wird nicht höher, sondern schmaler: Die Kacheln
    behalten ihr Verhältnis, die Reihe steht mittig, und rechts und links
    bleibt Rand. **Genau das konnte der alte Weg immer schon**
    (`naechsteReihe`: „sie wird gedeckelt und steht dann linksbündig, statt
    als Riese die Seite zu sprengen") — 1.0.35 hat diese Funktion durch das
    Mosaik ersetzt und den Deckel dabei verloren. **Dasselbe Muster wie beim
    Staffeln in 1.0.36: Wer eine Funktion ablöst, zählt vorher auf, was in
    ihr steckte.** Zum zweiten Mal an derselben Ablösung.
  - **Die Kachelzahl je Seite folgt jetzt aus der FLÄCHE** (`kachelnFuer`,
    dieselbe Rechnung rückwärts): so viele Kacheln, wie bei der Zielhöhe auf
    den Platz nach dem Text gehen. `kachelnAufSeite` ist ersatzlos entfernt —
    ein Mechanismus, dessen Grund widerlegt ist, bleibt nicht liegen.
  - **Nach unten gibt es keine Dehnungsgrenze mehr.** Sie stand da, solange
    eine Reihe die Satzbreite füllen MUSSTE: Stauchen hieß dann, das Bild
    seitlich zu beschneiden. Seit eine Reihe schmaler werden darf, heißt
    Stauchen „kleiner und mittig" und kostet nichts — und es rettet die
    Seite: Mit der alten Grenze wurde die Spalte höher als der Kasten, die
    letzte Reihe fiel heraus (`abgebrochen`), und ihr Bild landete allein auf
    der nächsten Seite. **Das war die zweite Hälfte des gemeldeten Fehlers.**
    Nach OBEN bleibt die Grenze, denn Dehnen beschneidet weiterhin.
  - **Keine hungernde letzte Seite.** Passt alles Offene noch auf diese
    Seite — gemessen an der Zielhöhe und der Stauchung, die ohnehin erlaubt
    ist —, kommt es mit. Der Grenzwert ist die Dehnungsgrenze selbst und
    keine zweite Zahl: Bei mehr Stauchung ginge die Spalte über den Kasten
    hinaus und die letzte Reihe fiele wieder heraus.
  - **Gehalten wird der BESTE Versuch, nicht der letzte.** Zwischen zwei
    Kachelzahlen kann eine Seite springen (mit drei Bildern zu hoch, mit
    zweien zu niedrig, keine im Band); bis 1.0.41 nahm die Schleife, was im
    zehnten Durchgang zufällig dastand. Gewertet wird jetzt wie in
    `Mosaik.beste`, und eine schon versuchte Zahl wird nicht wiederholt.
- **Und weil sich das hier nicht ansehen lässt, misst es die App**
  (`Druckpruefung.bildgroessen`, ab 1.0.42). Eine Zeile im Befund nennt den
  größten Größenunterschied innerhalb EINES Tages, samt Datum und beiden
  Maßen in Millimetern, und wie viel Prozent der Satzhöhe das höchste Foto
  des Buches nimmt. Gemessen am fertigen Satz und nicht an der Absicht —
  dasselbe Muster wie die Stufenprobe bei Schulalarm. Ein Faktor bis etwa
  2,5 gilt als Akzent, darüber steht die Zeile orange.
- **Nicht gemessen (1.0.42):** Keine Seite ist damit gesehen worden.
  Gerechnet und an den Vorgabemaßen nachgerechnet ist die URSACHE (91 gegen
  17 Prozent der Satzhöhe für dasselbe Foto) und die Geometrie der Abhilfe.
  **Gewählt und nicht gemessen** sind die Grenzen der Zielhöhe (0,16 bis 0,42
  der Satzhöhe), der Deckel darüber (1,3) und die Schwellen der neuen
  Befundzeile (2,5 und 3,2). Ob eine Doppelseite damit ausgewogen AUSSIEHT,
  sagt erst der nächste Befund — und seit 1.0.42 sagt er es mit Zahlen.
- **SELBST INSTALLIERTE SCHRIFTEN ZÄHLT `UIFont.familyNames` NICHT MIT**
  (`Model/Geraeteschriften.swift`, `Schriftwahl` in `Views/Waehler.swift`, ab
  1.0.41; gemeldet 09/2026: „Quicksand und … sind auf dem iPad installiert
  und können beispielsweise in Pages auch genutzt werden. In der App werden
  sie allerdings nicht einmal angezeigt."). **Die App war nicht kaputt, sie
  hat an der falschen Stelle gefragt:** `Schriftfamilie.alleDesGeraets` baut
  die Liste aus `UIFont.familyNames`, und das ist das Verzeichnis DIESES
  PROZESSES — die Schriften des Systems und die, die eine App in ihrem Bündel
  mitbringt. Was jemand über eine Schriftverwaltung auf das iPad legt, liegt
  woanders; dafür gibt es seit iOS 13 den `UIFontPickerViewController`, und
  genau den zeigt Pages. **Merke: Eine Aufzählung ist keine Frage an das
  Gerät, sondern eine an den eigenen Prozess.**
  - **„Der Wähler ist der einzige Weg" stand hier und war falsch**
    (berichtigt in 1.0.43). Es gibt sehr wohl eine Abfrage —
    `CTFontManagerCopyRegisteredFontDescriptors(.persistent, true)` —, und
    sie steht seit 1.0.43 davor; siehe den Absatz darunter. Der Satz war
    eine Annahme über Apples Absicht, ausgegeben als Auskunft über die
    Schnittstelle. Der Knopf bleibt daneben: Was die Abfrage nicht hergibt,
    holt der Wähler.
  - **Gewählt wird ein DESKRIPTOR, gesichert wird ein NAME.** Nur ein Name
    passt in ein Buch, das auf einem zweiten Gerät wieder aufgehen soll.
    Also wird die Schrift für den Prozess angemeldet
    (`CTFontManagerRegisterFontDescriptors`, Umfang `.process` — installiert
    hat sie der Nutzer längst) und danach NACHGESEHEN, ob sie unter ihrem
    Namen auffindbar ist. Das Ergebnis steht als Satz in der Schriftwahl.
    **Angenommen wird nichts**; dieselbe Bauweise wie die Stufenprobe bei
    Schulalarm.
  - **Eine Anmeldung auf `.process` endet mit dem Prozess.** Deshalb meldet
    `beimStartAnmelden()` bei jedem Start alles wieder an, was einmal
    gewählt wurde — und zählt, wie viel davon trägt. Die Namensliste liegt
    in den Voreinstellungen und NICHT im Buch: Welche Schriften auf einem
    Gerät liegen, ist eine Eigenschaft des Geräts.
  - **Kein `@AppStorage`** dafür — das ist eine `DynamicProperty` und gehört
    in eine View (die Regel steht seit 1.0.0 im Papier).
  - **Erst anmelden, dann nach dem Familiennamen fragen.** `UIFont(descriptor:)`
    gibt für eine dem Prozess unbekannte Schrift eine ERSATZSCHRIFT zurück —
    und deren Familienname stünde dann im Buch.
- **Eine fehlende Schrift ist der teuerste stille Fehler einer Druckvorlage**
  (`Druckpruefung`, ab 1.0.41). `Schriftbild.uiFont` fällt auf die
  Systemschrift zurück, wenn ein Name nicht auflöst — richtig, denn eine
  Seite ohne Schrift gibt es nicht. Nur sieht man es der Seite nicht an: Sie
  ist gesetzt, sie ist lesbar, und sie ist in einer anderen Schrift als der,
  die in der Schriftwahl steht. Getroffen wird das vor allem von selbst
  installierten Schriften und von einem Buch, das von einem anderen Gerät
  kommt. Gezählt und benannt wird es jetzt an zwei Stellen: in der
  Druckprüfung für das ganze Buch und als Zeile in der Schriftwahl für die
  gerade gewählte. **Wer einen stillen Rückfall baut, baut die Zeile dazu,
  die ihn sichtbar macht.**
- **Nicht gemessen (1.0.41):** Auf einem Gerät gesehen hat das niemand — hier
  gibt es keine selbst installierte Schrift. Gerechnet ist, WARUM sie in der
  Liste fehlten (`UIFont.familyNames` ist die Aufzählung des Prozesses);
  **ungeprüft ist alles danach**: ob `UIFontPickerViewController` die
  Schriften des Nutzers zeigt, ob die Anmeldung auf `.process` greift, ob der
  Name nach einem Neustart noch trägt und ob eine so gewählte Schrift ins PDF
  eingebettet wird. Genau deshalb sagt die App nach jeder Wahl selbst, was
  sie vorfindet, statt es zu behaupten. **Nichts davon als erledigt
  darstellen** — der nächste Befund des Nutzers ist hier die Messung.
- **EINE AUFZÄHLUNG IST KEINE FRAGE AN DAS GERÄT — ABER ES GIBT EINE**
  (`Geraeteschriften.systemfund`, ab 1.0.43; gemeldet 09/2026, nachdem
  1.0.41 ausgeliefert war: „Die Schriftarten tauchen immer noch nicht
  auf."). 1.0.41 hat die Ursache richtig benannt und die falsche Antwort
  gegeben: Die LISTE blieb dieselbe, daneben stand ein Knopf, der EINE
  Schrift nach der anderen holt — und er stand unter zwei Abschnitten, von
  denen der erste („Rundes a") auf einem iPad schon eine Bildschirmhöhe
  füllt. Wer die Liste ansieht, sieht also genau das, was vorher dastand.
  **Neunte Auflage von „es war da, man fand es nicht"** — und diesmal war
  zusätzlich zu wenig da.
  - **Das System lässt sich fragen.**
    `CTFontManagerCopyRegisteredFontDescriptors(.persistent, true)` gibt die
    Schriften zurück, die auf diesem Gerät dauerhaft angemeldet sind — also
    auch, was eine Schriftverwaltung dort abgelegt hat. `beimStartAnmelden`
    meldet sie für DIESEN Prozess an (`.process`); danach stehen sie in
    `UIFont.familyNames` und damit in der gewohnten Liste, ohne dass jemand
    einen Wähler öffnen muss. **Ob die Abfrage auf dem iPad des Nutzers
    etwas hergibt, ist NICHT gemessen** — deshalb zählt die App das
    Ergebnis, statt es zu behaupten.
  - **`CTFontManagerRegisterFontDescriptors` arbeitet ASYNCHRON.** Bis
    1.0.42 wurde ohne Rückrufblock angemeldet und unmittelbar danach
    gefragt, ob die Schrift unter ihrem Namen auffindbar sei — eine Frage,
    die zu diesem Zeitpunkt noch gar nicht beantwortet sein kann. Der
    Befund konnte also „NICHT auffindbar" sagen, während alles in Ordnung
    war, und `beimStartAnmelden` zählte beim ersten Start garantiert null.
    Gemeldet wird jetzt aus dem Block, und zwar erst, wenn er sich als
    abgeschlossen meldet. **Merke: Wo eine Schnittstelle einen
    Rückrufblock anbietet, ist die Frage davor zu früh.**
  - **Ein Deskriptor, der nur einen NAMEN trägt, ist der schwächste Weg.**
    Genau das blieb von einer über den Wähler gewählten Schrift übrig, und
    ob sich damit eine dem Prozess unbekannte Schrift wiederfinden lässt,
    ist offen. Die Systemabfrage steht deshalb DAVOR; der Namensweg bleibt
    als zweiter stehen, und beides wird getrennt gezählt.
  - **Der Abschnitt steht ganz oben**, gleich unter der Probe, und die
    Familien, die das Gerät meldet, stehen als Zeilen darin — in ihrer
    eigenen Schrift gesetzt wie jede andere. Dazu ein zweiter Zugang im
    Schrift-Blatt („Selbst installierte Schriften…"), denn hinter
    „Schriftart überall" steht der Name der gerade gewählten Schrift, und
    das liest sich wie eine Auswahlliste. Der irreführende Fußtext dort
    („Nur die Schriftfamilien, die dieses Gerät wirklich mitbringt, stehen
    zur Wahl") ist berichtigt — er beschrieb den Prozess und klang wie eine
    Aussage über das Gerät.
  - **„Schriften prüfen" ist eine PROBE, keine Erklärung**
    (`Views/Schriftenprobe.swift`). Nach einer Erklärung, die nicht
    geholfen hat, wird nicht ein zweites Mal geraten: kopierbar stehen dort
    die Zahl der vom System gemeldeten Einträge, wie viele davon lesbar
    waren, wie viele Familien der Prozess danach kennt, jede über den
    Wähler gewählte Schrift samt Auffindbarkeit — und ein PROTOKOLL der
    letzten Starts, das den Neustart überlebt. Nur so lässt sich „geht gar
    nicht" von „geht, hält aber den Neustart nicht" unterscheiden.
    Dasselbe Muster wie Schulalarms Stufenprobe und der Kartenmesser der
    Abfahrtstafel.
- **Nicht gemessen (1.0.43):** Auf einem Gerät gesehen hat das niemand —
  hier gibt es kein iPad und keine selbst installierte Schrift. Gerechnet
  ist, warum die Frage in 1.0.41 zu früh kam (der Aufruf ist asynchron) und
  warum der Weg nicht gefunden wurde (er lag unter zwei Abschnitten).
  **Ungeprüft bleibt das Entscheidende**: ob
  `CTFontManagerCopyRegisteredFontDescriptors(.persistent, true)` auf
  diesem iPad überhaupt etwas zurückgibt, ob sich die Einträge als
  `UIFontDescriptor` lesen lassen, ob die Anmeldung greift und ob eine so
  erreichte Schrift ins PDF eingebettet wird. Genau deshalb nennt die Probe
  zwei Zahlen (gemeldet und lesbar) statt einer. **Nichts davon als
  erledigt darstellen** — der Befund aus „Schriften prüfen" ist hier die
  Messung.
- **OHNE EIN RECHT GIBT iOS DIE SCHRIFTEN GAR NICHT HERAUS**
  (`com.apple.developer.user-fonts` = `system-installed-fonts`, ab 1.0.44;
  gemeldet 09/2026 zum dritten Mal, diesmal mit drei Bildschirmfotos).
  **Die Bilder sind die Messung, und sie zeigen auf etwas anderes als 1.0.41
  und 1.0.43:** In Pages stehen Poppins, Proxima Nova, Publico Text und
  Quicksand in der Schriftliste; im Wähler von iOS — demselben Wähler, den
  diese App seit 1.0.41 zeigt — springt dieselbe Liste von „PingFang TC"
  unmittelbar auf „Rockwell". Es fehlte also weder die Liste dieser App noch
  der Weg zum Wähler: **Es fehlte, was iOS der App überhaupt herausgibt.**
  - **Das Recht deckt beide Wege ab.** Ohne es sieht eine App ausschließlich
    die Schriften des Systems und die aus dem eigenen Bündel — der
    `UIFontPickerViewController` zeigt dann genau dieselbe Auswahl, und
    `CTFontManagerCopyRegisteredFontDescriptors(.persistent, true)` gibt
    nichts her. Damit ist auch gesagt, warum 1.0.43 nichts ändern konnte:
    Die Abfrage war richtig und fragte in einen leeren Raum.
  - **Eine Bewilligung braucht es nicht** (anders als bei Schulalarms
    kritischen Hinweisen, wo eine Entitlements-Datei ohne Bewilligung jedes
    Signieren scheitern lässt). In Xcode ist es die Fähigkeit „Fonts" mit
    dem Haken „Use Installed Fonts"; bei automatischer Signierung trägt
    Xcode es an der App-Id nach.
  - **Wirksam wird es erst SIGNIERT.** GitHub Actions baut mit
    `CODE_SIGNING_ALLOWED=NO` und sieht Entitlements nie an — ein grüner Bau
    sagt hier also nichts, und das ist dieselbe Regel wie beim iCloud-Recht
    seit 1.0.4. Gesehen wird es auf dem Gerät des Nutzers oder gar nicht.
  - **Zweimal an der falschen Stelle gesucht, und beide Male ohne Not.**
    1.0.41 baute den Wähler, 1.0.43 die Systemabfrage; beides war für sich
    richtig und beides konnte nichts ausrichten. **Was gefehlt hat, war eine
    Gegenprobe, die zwischen „diese App findet sie nicht" und „iOS gibt sie
    nicht heraus" trennt** — und die stand die ganze Zeit zur Verfügung: Der
    Wähler ist Apples eigener, also zeigt er, was das System der App zeigt.
    Die Probe nennt sie seit 1.0.44 im Klartext („Stehen deine Schriften im
    Wähler? Wenn nein, liegt es nicht an dieser Liste."), und die Fußzeile
    der Schriftwahl unterscheidet „keine da" von „diese App darf sie nicht
    sehen". **Merke: Wo zwei Erklärungen nebeneinander stehen und eine
    fremde App dieselbe Frage sichtbar beantwortet, ist der Vergleich mit
    ihr die billigste Messung.**
- **Nicht gemessen (1.0.44):** Dass das Recht fehlt, ist am Unterschied
  zwischen Pages und dem Wähler dieser App abgelesen und passt zu dem, was
  Apple dafür verlangt. **Dass es mit dem Recht geht, ist NICHT gemessen** —
  es braucht einen signierten Bau, und der entsteht auf dem Mac des Nutzers.
  Ebenso offen bleibt alles, was 1.0.43 offen gelassen hat (ob die
  Systemabfrage dann Einträge zurückgibt, ob sie sich als `UIFontDescriptor`
  lesen lassen, ob die Anmeldung greift, ob eine so erreichte Schrift ins
  PDF eingebettet wird). **Nichts davon als erledigt darstellen** — der
  Befund aus „Schriften prüfen" ist hier weiterhin die Messung.
- **EIN RECHT, DAS DIE APP-ID NICHT TRÄGT, MACHT DAS PROJEKT UNSIGNIERBAR**
  (Schriftenrecht wieder heraus in 1.0.45; gemeldet 09/2026 mit einem
  Bildschirmfoto aus Xcode: „Automatic signing failed — Provisioning profile
  ‚iOS Team Provisioning Profile: de.familie.urlaubstagebuch' doesn't match
  the entitlements file's value for the com.apple.developer.user-fonts
  entitlement."). 1.0.44 trug `com.apple.developer.user-fonts` in
  `Config/Urlaubstagebuch.entitlements` ein, damit die selbst installierten
  Schriften auftauchen. Die Absicht war richtig; der Preis war, dass sich die
  App **gar nicht mehr signieren ließ** — und damit war nicht nur die
  Schriftwahl weg, sondern jede Fassung, auch die davor gebauten.
  Ein Profil kann nur bewilligen, was die App-Id in der Entwicklerkonsole
  kann; steht in der Datei mehr, findet die automatische Signierung gar kein
  Profil mehr. **Genau diese Lehre steht seit dem ersten Signieren bei
  Schulalarm im Papier** („Wer der Erweiterung wieder eine Entitlements-Datei
  gibt, macht das Projekt unsignierbar") — sie galt hier genauso und wurde
  nicht gezogen. Das Recht ist deshalb **ersatzlos heraus** und nicht auf
  einen anderen Wert gestellt: Erst muss die App-Id es tragen, dann darf es
  in die Datei.
- **Ein grüner Bau in GitHub Actions kann das NICHT melden.** Er übersetzt
  mit `CODE_SIGNING_ALLOWED=NO` gegen den Simulator und sieht Entitlements
  nie an. Der Bau zu 1.0.44 war grün, „Fehler" leer, „Warnungen" leer — und
  die App war trotzdem auf kein iPad mehr zu bringen. Der Satz „Einen grünen
  Bau nie als signierbar ausgeben" stand für Schulalarm schon da; **er gilt
  für jede App dieses Repos, und eine Änderung an einer Entitlements-Datei
  ist genau der Fall, für den er gemacht ist.**
- **Der WERT war der zweite Fehler, und er war geraten.**
  `system-installed-fonts` steht in keinem nachschlagbaren Papier; belegt ist
  allein `system-installation` — und das ist das Recht, Schriften systemweit
  zu INSTALLIEREN, was diese App nicht tut. In Xcode heißt der gemeinte Haken
  „Use Installed Fonts"; welche Zeichenkette er schreibt, war von hier aus
  nicht zu messen. **Wer eine Zeichenkette in eine Entitlements-Datei
  schreibt, die er nicht nachschlagen kann, rät — und ein geratenes Recht
  kostet nicht eine Funktion, sondern den ganzen Bau.**
  **Nachtrag 1.0.66: `system-installed-fonts` gibt es nicht.** Die Probe aus
  1.0.45 hat am 23.09.2026 geantwortet — das Profil bewilligt
  `["app-usage", "system-installation"]`. **`app-usage` ist der Wert hinter
  „Use Installed Fonts"**, also der, um den es die ganze Zeit ging; er stand
  hier nie, weil er von hier aus nicht nachzuschlagen war. Der Absatz bleibt
  trotzdem stehen: Er ist der Beleg dafür, dass die Regel greift — die
  richtige Zeichenkette kam aus einer Messung auf dem Gerät und aus keiner
  Überlegung hier.
- **Was ein Bau DARF, wird seit 1.0.45 GELESEN** (`Model/Profilrechte.swift`,
  im Befund unter „Schriften prüfen" als erster Abschnitt). Gelesen wird die
  Rechteliste aus dem eingebetteten `embedded.mobileprovision` — also das,
  was das Profil bewilligt. Bis dahin stand in Quelltext und Oberfläche, das
  Recht sei „seit 1.0.44 in Kraft": eine Auskunft über das REPO, ausgegeben
  als Auskunft über das GERÄT. Dieselbe Art Lüge wie bei Schulalarms
  APNs-Umgebung, und dieselbe Antwort — **wo sich eine Frage nicht
  erschließen lässt, muss eine Probe entscheiden.** Zwei Dinge hält der
  Befund dabei auseinander: Die Entitlements-Datei sagt, was die App
  VERLANGT, das Profil sagt, was ihr BEWILLIGT ist; nur das Zweite ist von
  innen zu sehen. **Über TestFlight und aus dem Laden liegt gar kein Profil
  im Bündel** (dieselbe Beobachtung wie Schulalarm 1.0.19) — dann sagt die
  Zeile, dass sich hier nichts messen lässt, statt etwas zu behaupten.
- **Und die Fußzeile der Schriftwahl hört auf zu raten.** „Das kann zweierlei
  heißen: keine da — oder diese App darf sie nicht sehen" stand auch dann da,
  wenn sich die Frage beantworten ließ. Liegt ein Profil im Bündel und nennt
  es das Schriftenrecht nicht, ist es keine von zwei Möglichkeiten mehr,
  sondern der Befund, und die Zeile sagt ihn.
- **Der Weg zurück ist aufgeschrieben und wird nicht geraten:** in der
  Entwicklerkonsole bekommt die App-Id `de.familie.urlaubstagebuch` die
  Fähigkeit „Fonts", danach in Xcode die Fähigkeit „Fonts" mit dem Haken
  „Use Installed Fonts" — EINMAL, nicht zweimal (auf dem Bildschirmfoto
  standen zwei solche Abschnitte). Xcode schreibt dann selbst in die
  Entitlements-Datei, was richtig ist. Lässt es sich danach signieren, nennt
  „Schriften prüfen" die bewilligte Zeichenkette aus dem Profil, und **erst
  die gehört ins Repo.** Vorher nicht.
- **Nicht gemessen (1.0.45):** Dass die App sich jetzt wieder signieren
  lässt, hat niemand gesehen — hier gibt es keinen Mac. Gemessen ist die
  URSACHE: Das Recht kam in 1.0.44 hinein, vorher ließ sich signieren,
  nachher nicht, und die Fehlermeldung nennt genau diesen Schlüssel.
  Ungemessen bleibt auch, ob `Profilrechte` auf dem Gerät wirklich eine
  Liste findet — der Aufbau eines Profils ist nachgelesen, nicht an einer
  Datei geprüft; der Befund sagt es selbst, wenn nichts zu lesen war.
  **Nicht als erledigt darstellen.**
- **EIN WASSERZEICHEN IST KEIN BLOCK** (`Model/Wasserzeichen.swift`,
  `Gestaltung.wasserzeichen`, ab 1.0.46; Ansage des Nutzers 09/2026: „Ich
  lege einmal eine Bilddatei fest, für die das gelten soll. Und diese
  erscheint dann auf jeder Seite halbtransparent, möglichst an Stellen, an
  denen sonst noch kein Text oder Bild zu sehen ist."). Es steht deshalb am
  BUCH und wird beim Zeichnen jeder Seite ergänzt — dieselbe Regel wie bei
  Seitenzahl und Kopfzeile seit 1.0.0: Als Block läge es im Satz herum, ließe
  sich verschieben, löschen, und der Layoutautomat räumte es beim nächsten
  Neuanordnen weg. „Einmal festlegen" verträgt sich mit einem Block nicht.
- **Es liegt ÜBER dem Hintergrund und UNTER allen Blöcken.** Der Nutzer sagt
  selbst, dass Text darüber hinweggehen darf; obenauf läge dagegen ein
  Schleier über jedem Foto, und dann wäre die Deckkraft gar nicht mehr zu
  beurteilen. Gezeichnet wird es an beiden Stellen, an denen diese App eine
  Seite zeichnet (`SeitenflaecheView` und `Buchausgabe.zeichneSeite`) — die
  LAGE aber rechnet nur EINE Funktion (`Wasserzeichenlage.rechteck`): Zwei
  Fassungen ergäben eine Vorschau, die anders aussieht als der Druck.
- **„Wo gerade Platz ist" wird GEMESSEN, nicht geraten**
  (`Wasserzeichenlage`). Ein Raster von sieben mal sieben Lagen im
  Satzspiegel, gewertet wird die gewichtete Fläche, die schon belegt ist.
  **Die Gewichte sind der Kern:** Ein Foto (8) oder eine Karte DECKT das
  Zeichen zu — dort ist es weg; Text (1) läuft nur darüber hinweg, und
  genau das hat der Nutzer ausdrücklich erlaubt. Gleiche Gewichte legten
  das Zeichen lieber unter ein Foto als unter drei Zeilen Text. Die
  Gewichte sind **gewählt und nicht gemessen**.
- **Der Suchanfang hängt an der SEITE** (`seite.id.saat`, nie `hashValue`
  — den streut Swift je Programmlauf neu; dieselbe Falle wie beim
  Papierkorn in 1.0.16 und bei den Linienfarben der Abfahrtstafel). Damit
  landet das Zeichen auf zwei gleich leeren Seiten an verschiedenen Stellen,
  und dieselbe Seite bekommt beim nächsten Öffnen dieselbe.
- **Die Größe ist ein ANTEIL der Satzbreite, keine Millimeterzahl.** So
  übersteht sie den Formatwechsel von A4 auf A5 ohne eigene Zeile in
  `Formatwechsel` — dieselbe Überlegung wie bei `kartenanteil` und
  `textspaltenanteil`.
- **Das Seitenverhältnis wird EINMAL beim Einlesen gemessen** und steht in
  der Einstellung. Ohne diese Zahl müsste die Lagerechnung das Bild von der
  Platte holen, nur um seine Proportion zu erfahren — je Seite, bei jedem
  Neuzeichnen. Dieselbe Falle wie bei den berechneten Eigenschaften der
  Netzkarte in der Abfahrtstafel.
- **Eingepasst, nie gefüllt** (`Wasserzeichenlage.eingepasst`). Beim Foto
  ist das Füllen richtig, weil dort der Rahmen der Platz auf der Seite ist;
  hier wäre es ein Ausschnitt — und ein beschnittenes Ahornblatt ist kein
  Zeichen mehr, sondern ein Fleck (dieselbe Lehre wie beim Aufmacherband in
  1.0.34).
- **Der Weg führt in die DATEIEN, nicht in die Fotos**, und der Grund steht
  in der Oberfläche: Ein Wasserzeichen braucht einen durchsichtigen Grund,
  das kann PNG — die Mediathek gibt fast nur JPEG und HEIC heraus, und
  deren weißer Grund legte sich als helles Rechteck über die Seite. Die
  Datei wandert mit ihrer ECHTEN Endung ins Bildarchiv der Reise; ein
  `Foto`-Eintrag entsteht dabei nicht (es ist kein Reisefoto und gehört in
  keine Tagesliste).
- **Und genau deshalb muss sie in `Buchdatei.schreiben` ausdrücklich mit.**
  Dort läuft die Schleife über `reise.fotos`; das Wasserzeichen steht da
  nicht drin. Ohne die Zeile verlöre ein ausgetauschtes Buch sein Zeichen,
  und zwar STILL: Die Einstellung stünde weiter in der Datei, die Bilddatei
  fehlte. **Wer eine neue Bildart anlegt, trägt sie dort ein.**
- **Mit „Ohne Transparenz" fällt es WEG, statt deckend gezeichnet zu
  werden.** Beim Verlauf unter einer Überschrift ist das anders (dort wird
  ein geschlossenes Feld daraus), und der Unterschied hat einen Grund: Der
  Verlauf muss etwas LESBAR machen, das Zeichen muss gar nichts. Ein
  undurchsichtiges Ahornblatt mitten auf der Seite wäre keine abgeschwächte
  Fassung, sondern ein Fehler im Buch.
- **Was die Automatik nicht kann, ZÄHLT die Druckprüfung**
  (`Druckpruefung.wasserzeichen`). „Möglichst an Stellen, an denen sonst
  nichts steht" ist eine Zusage, die sich nur am fertigen Satz einlösen
  lässt: Auf einer Seite mit randabfallendem Foto gibt es keine freie
  Stelle, und dann liegt das Zeichen unter dem Bild. Die Zeile sagt, auf
  wie vielen Seiten das so ist — statt dass es jemand im gedruckten Buch
  sucht.
- **Nicht gemessen (1.0.46):** Keine Seite ist damit gesehen worden.
  Gerechnet ist die Geometrie; **gewählt und nicht gemessen** sind alle
  Zahlen — die Gewichte (Foto 8, Fläche 4, Überschrift 1,5, Text 1, Linie
  0,5), das Raster (7 × 7), die Vorgaben für Deckkraft (10 %) und Breite
  (34 % der Satzbreite) und die Schwelle der Befundzeile (gewichtete
  Belegung 4). Ob ein Zeichen bei 10 % im Druck noch zu sehen ist oder
  schon stört, sagt erst der erste Ausdruck — auf dem Bildschirm wirkt es
  kräftiger als auf Papier. **Nicht als erledigt darstellen.**
- **EIN HINTERGRUNDBILD ÜBER DIE DOPPELSEITE** (`Model/Bogenlage.swift`,
  `Seitenhintergrund.ueberDoppelseite`, ab 1.0.47; Ansage des Nutzers
  09/2026: „ich möchte einstellen können, dass ein Hintergrundbild über eine
  Doppelseite geht"). Bis 1.0.46 füllte ein Hintergrundfoto immer genau eine
  Seite; im aufgeschlagenen Buch standen damit zwei Ausschnitte desselben
  Bildes nebeneinander, jeder für sich vollständig.
  - **Ein SCHALTER und keine Automatik**, wörtlich erbeten: „Da ich nicht
    absehen kann, ob es vielleicht andere Konstellationen gibt, wo es
    sinnvoll ist, das Bild auf jeder Seite zu haben." Beides ist richtig, nur
    für verschiedene Bilder — ein Muster, ein Himmel oder eine Struktur
    gehört auf jede Seite, eine Landschaft über den Bund. Aus als Vorgabe:
    Was bisher gesetzt wurde, sieht danach unverändert aus.
  - **Welche Hälfte auf diese Seite fällt, ist BUCHBINDEREI und keine
    Einstellung.** Seite 1 ist ein Recto, also rechts; jede rechte Seite
    trägt eine ungerade Nummer. Die Regel stand seit 1.0.17 in
    `Reisewerk.doppelseiten` („Links die gerade, rechts die ungerade Nummer
    — nie umgekehrt") und steht jetzt als Funktion in `Bogenlage`; die
    Doppelseitenansicht holt sie von dort. Zwei Fassungen ergäben eine
    Ansicht, die anders paart als der Satz — und das sähe man erst im
    gedruckten Buch.
  - **Die Fläche ist 2 × Endformat breit, mit Anschnitt nur AUSSEN.** Am Bund
    stoßen die Endformate aneinander (deshalb zeichnet die
    Doppelseitenansicht sie ohne Abstand); innen deckt die Nachbarseite ab,
    dort gibt es nichts zu beschneiden. **Beschnitten wird trotzdem am
    Bogen** — die Nachbarseite ist ein eigenes Blatt Papier.
  - **Gerechnet wird an EINER Stelle** (`Bogenlage.bildflaeche` für das PDF,
    `Bogenlage.versatz` für SwiftUI — dieselbe Zahl, einmal als Rechteck in
    Seitenkoordinaten, einmal als Versatz gegen die Bogenmitte, weil ein
    `ZStack` mittig ausrichtet). Zwei Fassungen ergäben eine Vorschau, in der
    das Bild anders steht als im Druck.
  - **`HintergrundFlaeche` bekommt eine FESTE Größe.** Ein `ZStack` ist so
    groß wie sein größtes Kind; ein Bild über die Doppelseite ist breiter
    als diese Seite und zöge das Blatt auseinander. Der Rahmen steht deshalb
    VOR dem `.clipped()`. `bogen` und `seitennummer` sind wahlweise — die
    Probe im Hintergrund-Blatt steht nicht im Buch und hat keine
    Nachbarseite; dort gibt es keine Doppelseite, über die etwas gehen
    könnte.
  - **`Seitenhintergrund` liest sich seit 1.0.47 von Hand.** Er hatte keinen
    eigenen Leser, und das wäre hier still teuer geworden: `Gestaltung` holt
    ihn über `b.wert(.hintergrund, .weiss)`, eine einzelne Seite über
    `b.wahlweise(.hintergrund)` — ein neues Feld hätte in jedem vorhandenen
    Buch den Buchhintergrund auf Weiß zurückgesetzt und jeden eigenen
    Seitengrund verschwinden lassen, ohne eine Meldung. **Die Regel gilt für
    jeden Typ, der wächst**, und sie galt für diesen noch nicht.
  - **Was der Schalter NICHT kann, steht darunter.** Setzt jemand den
    Hintergrund je SEITE, braucht die Nachbarseite dasselbe Bild mit
    demselben Schalter — sonst steht im Buch die Hälfte des einen neben der
    Hälfte des anderen, und auf dem Bildschirm sieht jede Seite für sich
    tadellos aus. Deshalb zählt `Druckpruefung.doppelseitenhintergrund` die
    Bögen, die nicht aufgehen. Die Hälfte, die auf die Innenseite des
    Umschlags fällt (erster und letzter Bogen), wird eigens genannt und
    nicht als Fehler gezählt: Sie wird nie gedruckt, und das ist das Buch
    und kein Versehen.
- **DIE ZWEITE ÜBERSCHRIFT KOMMT AUS DER ZEILE NACH DEM DATUM**
  (`Textimport.zweiteUeberschrift`, `Reisetag.unterueberschrift`,
  `Blockinhalt.unterueberschrift`, `Schriftrolle.unterueberschrift`, ab
  1.0.48; Ansage des Nutzers 09/2026: „In dem zu importierenden Text … ist
  es so, dass nach dem Datum eine zweite Überschrift kommt, in der der Ort
  des Geschehens aufgeführt wird oder ein bestimmtes Schlagwort. Erst dann
  beginnt der Fließtext … Diese soll nicht genauso aussehen wie die
  Datumsüberschrift, sondern es soll erkennbar sein, dass es eine zweite
  Ebene … sein soll.“). Bis 1.0.47 wurde diese Zeile Fließtext — sie ging
  also nicht verloren, sie stand nur als erster Absatz im Tagebuchtext.
  - **Erkannt wird die KÜRZE, und das ist in BEIDEN Textsorten ein
    Merkmal.** In einem hart umbrochenen Text reicht eine gewöhnliche Zeile
    bis nahe an die Umbruchspalte (gemessen in 1.0.12: rund 88 Zeichen), in
    einem frei geschriebenen ist ein ganzer Absatz EINE sehr lange Zeile.
    Eine kurze Zeile unmittelbar nach dem Datum ist damit in keinem der
    beiden Fälle Fließtext. Dazu vier Bedingungen: höchstens 42 Zeichen
    und sechs Wörter, groß oder mit einer Ziffer anfangend, kein
    Satzzeichen am Ende (der Doppelpunkt ausgenommen und abgeschnitten),
    und kein Datum darin.
  - **Die wichtigste Bedingung ist, dass DANACH noch Text kommt.** Ein Tag,
    der nur aus dieser einen Zeile besteht, hat keine Überschrift — er hat
    einen sehr kurzen Text, und den als Überschrift zu setzen hieße, ihn
    aus dem Tagebuch zu nehmen. **Der Fehler in diese Richtung ist der
    teure**: Was als Überschrift gesetzt wird, fehlt danach im Fließtext.
  - **Behauptet wird nichts, gezeigt wird** — dieselbe Bauweise wie bei der
    Absatzerkennung seit 1.0.12: Die Vorschau nennt die gefundene Zeile je
    Tag eigens (und anders aussehend als die erste Überschrift, denn sie
    wird dem Fließtext WEGGENOMMEN), die Fußzeile zählt „an n von m Tagen
    gefunden“, **und auch der Fall „nirgends“ steht da** samt der Regel im
    Klartext. Ein Schalter stellt die Erkennung ab.
  - **Das Feld steht am TAG, nicht im Block** (`Reisetag.unterueberschrift`),
    wie Überschrift und Datumszeile: Der Block ist ein Vorschlag über dem
    Inhalt und wird beim Neuanordnen neu gerechnet. Eintippen lässt es sich
    deshalb auch ohne Einlesen — im Tagesmenü unter „Überschriften und
    Datumszeile“ — und auf der Seite mit dem Doppeltipp wie jeder Textkasten.
  - **`Typografie.unterueberschrift` ist OPTIONAL, und `nil` heißt
    „abgeleitet“ — nicht „leer“.** Abgeleitet wird aus der Überschrift:
    dieselbe Familie, 58 % der Größe, kursiv, nicht fett, in der
    Akzentfarbe. Der Grund ist derselbe wie bei `Schriftabweichung` — die
    sechs Buchstile setzen `titel` je einzeln, und ein fest eingetragener
    Vorgabewert stünde in jedem davon in einer fremden Schrift; ein siebter
    Stil vergäße ihn obendrein. Der erste Griff an einen Regler löst sie
    aus der Ableitung, und ein Knopf nimmt das zurück; das Schrift-Blatt
    sagt beides.
  - **`groessenSkalieren` und `familieUeberall` überspringen eine
    abgeleitete zweite Überschrift** (`Typografie.gesetzteRollen`). Beide
    rechnen über das SCHREIBEN des Wertes, und ein Schreiben macht aus der
    Ableitung eine Kopie. Am Ergebnis änderte das nichts (beide wirken
    gleichmäßig, und die Ableitung nimmt Größe und Familie aus dem Titel)
    — aber ab da folgte sie dem Titel nicht mehr, und das fällt erst beim
    nächsten Stilwechsel auf.
  - **`Typografie` liest sich seit 1.0.48 von Hand.** Die Regel steht seit
    1.0.3 im Papier und galt für diesen Typ noch nicht: `Reise` holt ihn
    über `b.wert(.typografie, Typografie())` — ein Feld, das der erzeugte
    Leser vermisst, hätte in jedem vorhandenen Buch ALLE vier Schriften auf
    die Vorgaben zurückgesetzt, und zwar still.
  - **Gesetzt wird sie nur auf dem AUFMACHER** (`Layoutautomat.kopfzeile`
    unter `!knapp`, und auf der ganzseitigen Aufmacherseite in Weiß). Auf
    der Fortsetzungsseite wäre sie dieselbe Angabe ein zweites Mal —
    dieselbe Regel wie beim Titel. Auf der ganzseitigen Aufmacherseite geht
    ihre Höhe in die Rechnung ein, BEVOR `y` gesetzt wird: Der Kopf wird
    dort von unten aufgebaut, und eine nachträglich eingeschobene Zeile
    schöbe den Titel aus dem Satzspiegel. Abgewichen wird dort nur die
    FARBE — Schrift und Größe holt der Satz über die Rolle des Blocks; sie
    zu kopieren machte aus der Ableitung wieder eine Kopie.
  - **Ein leerer Fund überschreibt nichts** (`Fotoeinfuhr.textVerteilen`),
    auch beim Ersetzen: Wer die zweite Überschrift von Hand eingetippt hat
    und denselben Text noch einmal einliest, verlöre sie sonst.
- **SEITENZAHLEN GAB ES NUR IM PDF** (`Model/Seitenbeiwerk.swift`, ab 1.0.50;
  gemeldet 09/2026: „Im Menü kann ich Seitenzahlen aktivieren. Diese kommen auf
  dem Dokument aber niemals zum Vorschein."). **Am Quelltext abzuzählen und
  keine Vermutung:** `Buchausgabe.zeichneFusszeile` war die EINZIGE Stelle im
  ganzen Quelltext, die `gestaltung.seitenzahlen` überhaupt las, und sie läuft
  nur beim Schreiben des PDF. Auf dem Bildschirm wurde nichts davon gezeichnet
  — der Schalter im Menü war dort seit 1.0.0 ohne jede Wirkung. Dasselbe galt
  für die Kopfzeile.
  - **Das verstieß gegen die erste Regel dieser App** („Seite und PDF zeichnet
    DERSELBE Setzer"), und zwar an der einen Stelle, an der eine Seite nicht
    aus Blöcken besteht. Blöcke sind Seitenzahl und Kopfzeile bewusst nicht:
    Sie gehören dem BUCH und nicht dem Tag; als Block lägen sie im Satz herum,
    wo sie jemand verschöbe und der Layoutautomat sie beim nächsten
    Neuanordnen wegräumte. Gerechnet wird jetzt in `Seitenbeiwerk`, und beide
    Zeichner holen sich dieselben Rechtecke — auf dem Bildschirm über denselben
    `Textkasten`, mit dem auch jeder andere Text gesetzt wird.
  - **Merke: Wer etwas beim Zeichnen einer Seite ergänzt, ergänzt es an BEIDEN
    Zeichnern.** Sonst steht es entweder nur auf dem Bildschirm oder nur im
    Druck, und beides sieht für den Menschen davor nach einem Fehler aus.
  - Die Fußzeile der Einstellung sagt seither auch, wo sie NICHT stehen:
    Titelseite, Rückseite und jede Seite, die ein Bild ganz ausfüllt
    (`ohneSeitenzahl`). Ein Schalter, der an drei Stellen wirkungslos ist,
    ohne dass es dabeisteht, führt wieder auf dieselbe Frage.
- **DER UMSCHLAG IST EIN BOGEN, KEINE SEITE** (`Model/Umschlag.swift`,
  `Model/Umschlagmass.swift`, ab 1.0.50; Ansage des Nutzers 09/2026: „Die
  Gestaltung der Titelseite. Diese soll völlig unabhängig von der Gestaltung
  der restlichen Seiten sein. … In meiner Erinnerung ist es bei Saal Digital
  beispielsweise so, dass die Titelseite bzw. der Umschlag des Buches so
  dargestellt wird, dass die rechte Hälfte einer Doppelseite die tatsächliche
  Titelseite ist und die linke Seite die Rückseite des Buches.").
  - **Er hat recht, und es stand so im Quelltext:** Die Titelseite nahm den
    Satzspiegel des Buches, seine Schrift, seinen Hintergrund und seinen Stil.
    Wer den Innenteil umgestaltete, gestaltete den Umschlag mit — bei einem
    gebundenen Buch schlicht falsch: Der Umschlag ist ein eigenes Stück Papier
    und läuft an der Druckerei durch eine eigene Maschine.
  - **Die Rückseite trägt die NUMMER 0, und damit paart sich der Bogen von
    selbst.** `Bogenlage` sagt seit 1.0.47: gerade Nummer links, ungerade
    rechts. 0 ist gerade, 1 ist die Titelseite — also liegt links die
    Rückseite und rechts der Titel, ohne eine einzige zusätzliche Regel.
    **Das ist der ganze Trick**, und er ist der Grund, warum die
    Doppelseitenansicht, die Hintergrundhälften und der Umschlag dieselbe
    Rechnung benutzen. Gezählt wird der Innenteil trotzdem ab 1: Der Umschlag
    gehört nicht zum Buchblock.
  - **Im vollständigen PDF fällt die Rückseite WEG** (`nummer > 0`). Sie
    stünde sonst als erste Seite vor dem Titel — eine Reihenfolge, die es im
    gebundenen Buch nirgends gibt. „Umschlag als eigene Datei" gibt dafür
    genau EINEN breiten Bogen aus.
  - **Keine TrimBox in der Mitte.** Sie sagt einer Druckerei, wo geschnitten
    wird; auf einem Bogen mit zwei Seiten und einem Rücken gäbe es dafür keine
    einzige richtige Stelle — geschnitten wird außen, gefalzt wird am Rücken.
    Dieselbe Überlegung wie bei der Broschüre seit 1.0.27.
  - **Jede Hälfte wird BESCHNITTEN gezeichnet** (`clip` auf ihre Fläche plus
    den außen liegenden Anschnitt). Ohne das liefe ein randabfallendes
    Titelfoto über den Rücken — also genau über die Beschriftung, die dort
    stehen soll.
- **DER RÜCKEN: gerechnet, nicht gemessen** (`Umschlagmass.rueckenbreite`, ab
  1.0.50; Ansage des Nutzers: „was an die Seite des Buches, also den Bereich,
  der die Dicke des Buches ausmacht, drauf gedruckt werden kann. Bislang habe
  ich dort immer den Titel des Buches untergebracht."). Blätter mal
  Papierstärke, beim Hardcover plus die beiden Deckel. **Beide Zahlen sind
  einstellbar, und daneben steht der Satz, dass die Angabe des Druckdienstes
  gilt** — wie dick ein Blatt aufträgt, weiß diese App nicht. Leer heißt: der
  Titel des Buches; ein Feld, das man erst füllen muss, um das Naheliegende zu
  bekommen, ist eine Hürde ohne Gewinn.
  - **Die Schrift läuft von OBEN nach UNTEN**, wie es hierzulande üblich ist:
    Ein Buch, das flach auf dem Tisch liegt, soll sich mit dem Titel nach oben
    lesen lassen. Im schon umgedrehten Zeichensystem ist das eine Drehung um
    +90 Grad.
  - **Der Rücken macht den Bogen BREITER**, und das gehört in jede Rechnung,
    die die Bühne einpasst (`ReiseView.breitesterBogen`). Ohne ihn wäre der
    Inhalt schmaler als das, was darin steht, und das letzte Stück des
    Umschlags ließe sich nicht heranschieben — dieselbe Falle wie 1.0.22.
- **Was am Umschlag `nil` ist, folgt weiter dem BUCH** (ab 1.0.50). Hintergrund,
  Rand, Schrift und Titelgröße sind Abweichungen und keine Kopien — dieselbe
  Regel wie bei `Schriftabweichung` seit 1.0.0 und bei `Block.wirkung` seit
  1.0.9, und aus demselben Grund: Kopierte der Umschlag beim ersten Antippen
  alle Werte des Buches, wäre jede spätere Änderung am Buchganzen an ihm
  wirkungslos, und zwar unsichtbar. Der Hintergrund läuft über denselben
  Bildschirm wie der des Buches und der einer Seite (`HintergrundView`,
  drittes Ziel) — drei Bildschirme für dieselbe Entscheidung liefen
  auseinander.
- **Was 1.0.50 NICHT baut: der Umschlag lässt sich nicht von Hand
  umbauen.** Titelseite und Rückseite werden gerechnet und bei jeder Änderung
  neu gesetzt; ein verschobener Block darauf wäre beim nächsten Durchgang
  weg. Das war bei der Titelseite seit 1.0.0 so und bleibt es. **Nicht als
  gelöst darstellen** — wer es baut, legt beide Seiten als echte `Seite` in
  der Reise ab und nimmt sie aus `alleNeuAnordnen` heraus.
- **EINE EINSTELLUNG, DIE ES NUR GLOBAL GIBT, IST HALB GEBAUT**
  (`Model/Kartenwahl.swift`, `Block.kartenbild`, `.kartenausschnitt`, ab
  1.0.51; Befund des Nutzers 09/2026: „Hier wollte ich gerade speziell nur
  für diese Karte Änderungen in den Einstellungen treffen. Zum Beispiel,
  dass Standortpunkte doch angezeigt werden und nicht nur die Linien.
  Offenbar kann ich das aber nicht für einzelne Karten, sondern nur
  global."). Er hat recht, und es war seit 1.0.0 so: Das Buch trug eine
  Karteneinstellung, ein TAG durfte sie überschreiben — die einzelne Karte
  auf der Seite nicht. Seit 1.0.39 lässt sich eine Karte auf eine zweite
  Seite KOPIEREN; damit gab es zwei Karten, die sich nicht auseinanderhalten
  ließen.
  - **Drei Ebenen, aufgelöst an EINER Stelle** (`Kartenwahl.geltend`):
    Block vor Tag vor Buch. Bildschirm (`KartenKachel`) und PDF
    (`Buchausgabe.kartenbilder`) fragen dieselbe Funktion — zwei Fassungen
    ergäben ein gedrucktes Buch, das anders aussieht als die Vorschau, und
    zwar erst dann anders, wenn es gedruckt ist. Dieselbe Regel wie bei
    `Block.wirkung` und `Bildausschnitt.zielrechteck`.
  - **Abweichung, keine Kopie.** `nil` heißt „wie der Tag", und wo der Tag
    nichts sagt, „wie das Buch". Kopierte der Block beim Anlegen die Werte,
    wäre jede spätere Änderung am Buchganzen an jeder schon einmal
    angefassten Karte wirkungslos — dieselbe Bauweise wie
    `Schriftabweichung` und der Fotostil seit 1.0.9.
  - **Der Abschnitt fragte den FALSCHEN Tag** (behoben in 1.0.51,
    `BlockInspektor.kartenstelle`). Er hing an `werk.tag`, also am gerade
    gewählten Tag — und der folgt seit 1.0.28 dem, was oben im Bild steht,
    nicht dem angetippten Block. Wer eine Karte antippte, während über ihr
    noch die letzte Seite des Vortags stand, stellte am VORTAG etwas um.
    Und zeigte `gewaehlterTag` auf einen Tag, den es nicht mehr gibt, fiel
    der ganze Abschnitt weg — dann war von der Karte aus GAR KEINE
    Karteneinstellung erreichbar. **Wer einen Abschnitt zu einem BLOCK
    baut, fragt den Tag des Blocks und nie den gewählten.**
  - **Die Kennung der `KartenKachel` nannte nur die SPANNE** (behoben in
    1.0.51). Wer die Karte verschob, ohne den Maßstab zu ändern, sah auf
    dem Bildschirm weiter den alten Ausschnitt; im PDF stand der neue. Der
    Schlüssel kommt jetzt aus `Kartenwahl.Geltend.merkmal` und nennt Mitte,
    Spanne und alles aus `Kartenbild.merkmal`. **Ein Zwischenspeicher-
    Schlüssel muss ALLES nennen, was das Bild verändert** — die Regel steht
    seit 1.0.37 an `Kartenbild.merkmal` und galt für die Ansicht daneben
    nicht.
  - **Die Einstellung überlebt das Neuanordnen** (`Reisewerk.seitenNeuSetzen`).
    Der Layoutautomat baut den Kartenblock frisch und weiß von der
    Abweichung nichts; ohne diese Stelle wäre sie nach jedem Neuanordnen
    weg, und zwar STILL — die Seite steht ja danach da. Es gibt seither
    genau EINEN Weg, der Seiten setzt (vorher sechs gleichlautende Zeilen);
    **wer einen zweiten baut, ruft diesen hier**, sonst ist derselbe stille
    Verlust wieder eingebaut. Dasselbe Muster wie `wortlautSichern` seit
    1.0.38.
  - **Eine Karteneinstellung ist keine Handarbeit am Satz**
    (`Reisewerk.karteAendern`). `aendere` setzt `vonHand`, und das ist
    richtig, wo jemand einen Block schiebt, dreht oder zieht. Wer die
    Reisepunkte einer Karte umstellt, hat an der ANORDNUNG nichts getan —
    der Tag fiele sonst wegen einer Farbe für immer aus dem automatischen
    Neuanordnen heraus.
- **DER UMSCHLAG ZÄHLTE IM BUCHBLOCK MIT — und schob damit jede Seite auf
  die falsche Hälfte** (`Buchteil`, ab 1.0.52; gemeldet 09/2026: „die erste
  wirkliche Seite im Fotobuch ist ja eine rechte Seite, also eine ungerade
  Seite. Bislang hast du es so dargestellt, dass die Seite 1 eine linke Seite
  ist. Denn links von der Seite 1 wäre ja praktisch die Innenseite des
  Umschlags, die nicht bearbeitet bzw. bedruckt wird."). **Er hat recht, und
  es ist am Quelltext abzuzählen:** `seitenfolge` vergab Rückseite 0,
  Titelseite 1 und der Buchblock begann bei 2 — und `Bogenlage.rechts` sagt
  seit 1.0.47, dass eine gerade Nummer LINKS liegt.
  - **Die Regel von 1.0.47 war richtig, die ZÄHLUNG darunter war falsch.**
    Der Umschlag ist ein eigenes Stück Papier und läuft an der Druckerei
    durch eine eigene Maschine (das steht seit 1.0.50 im Papier) — er kann
    also gar nicht in derselben Folge liegen wie der gebundene Block.
    **Merke: Wenn eine Paarung an der falschen Stelle beginnt, ist zuerst
    zu prüfen, was überhaupt mitgezählt wird, und erst danach die
    Paarungsregel.**
  - **`Buchteil` trennt die beiden Angaben**, die bis 1.0.51 eine waren:
    WO eine Seite liegt (`.rueckseite`, `.titel`, `.innen`) und WELCHE Zahl
    auf ihr steht (`nummer`, ab 1, nur im Block). Gilt der Umschlag als
    Bogen, tragen seine beiden Seiten die 0 und erscheinen in keiner
    Seitenzahl; ohne Bogen ist die Titelseite die gewöhnliche Seite 1 und
    liegt als ungerade Nummer ebenfalls rechts.
  - **Die Nummer taugt seither nicht mehr als Schlüssel** — Rückseite und
    Titelseite tragen beide 0. Dafür gibt es `Buchseite.rang` (die Stelle
    in der Folge, ab 0): Die Bühne bildet damit ab, welcher Tag oben im
    Bild steht (`imBlick`), und ohne den Rang löschte die eine
    Umschlagseite beim Verschwinden den Eintrag der anderen. **Wer aus
    einer Seite einen Schlüssel bildet, nimmt den Rang und nie die Nummer.**
  - **Die Seitenfolge stand ZWEIMAL da** — in `Reise.seitenfolge` und in
    `Reisewerk.seitenfolge`, die sich die gesetzten Umschlagseiten merkt,
    weil ihr Satz zwei CoreText-Messungen kostet. Genau so etwas läuft
    auseinander, und hier wäre es ein Buch gewesen, dessen Vorschau anders
    paart als die Datei. Gezählt wird jetzt in
    `Reise.seitenfolge(titelblatt:rueckblatt:)`; wer die Seiten SETZT,
    entscheidet der Aufrufer. Dasselbe gilt für `Buchseite.liegtRechts`,
    `.bogennummer` und `.kurzname` — drei Fragen, je eine Stelle.
  - **Die Druckprüfung baute die Nummerierung EBENFALLS selbst nach** (der
    Befund zum Hintergrund über die Doppelseite). Sie hätte nach diesem
    Umbau lauter Bogen gemeldet, die „nicht aufgehen". **Wer eine Zählung
    ändert, sucht nach jeder Stelle, die sie nachbaut** — hier waren es
    drei.
- **Ein Wasserzeichen darf SCHRÄG stehen** (`Wasserzeichen.drehspanne`, ab
  1.0.52, Ansage des Nutzers 09/2026: „ob diese Bilddatei so wie sie ist
  erscheint oder in einem einzustellenden Toleranzbereich gedreht ist,
  beispielsweise von minus 30 Grad bis plus 30 Grad").
  - **Der Winkel wird NICHT gewürfelt**, sondern aus `seite.id.saat`
    gezogen — nie aus `hashValue`, den streut Swift je Programmlauf neu.
    Dieselbe Seite steht damit beim nächsten Öffnen wieder gleich schief,
    und das PDF zeigt, was auf dem Bildschirm steht. Dritte Auflage
    derselben Regel nach dem Papierkorn (1.0.16) und dem Seitenrhythmus
    (1.0.31).
  - **Gezogen wird eine ZWEITE Zahl aus derselben Kennung**, nicht
    dieselbe: Die Lage nimmt den Rest zur Feldzahl, und wer denselben Rest
    auch für den Winkel nähme, koppelte beide — jedes Zeichen in derselben
    Ecke stünde gleich schief.
  - **Der PLATZ wird für den gedrehten Umriss gesucht** (`umschliessend`,
    `Wasserzeichenlage.Ort`). Ein um 30 Grad gedrehtes Bild braucht mehr
    Fläche als ein gerades; wer den Winkel erst beim Zeichnen draufsetzt,
    lässt es über den Satzspiegel ragen. Beide Zeichner drehen um dieselbe
    Mitte und passen das Bild in denselben inneren Rahmen ein — zwei
    Fassungen ergäben ein PDF, das anders aussieht als die Vorschau.
- **WER AUS EINEM VOLLBILD HERAUS MELDET, MELDET IN DIESEM VOLLBILD**
  (`PunktwahlView.quittung`, ab 1.0.52; gemeldet 09/2026: „Es wäre schön,
  wenn hier doch noch eine genauere Bestätigung durch die App erfolgen
  könnte. Ich bekomme zumindest keine Rückmeldung … Normalerweise kann ja
  dann dieses Fenster im unteren Bereich auch wieder schließen. Das tut es
  bislang nicht."). Gemeldet hat die App sehr wohl — über `werk.meldung`,
  und das Band wird in `ReiseView` gezeigt, während die Punktwahl seit
  1.0.49 als VOLLBILD darüberliegt. Es erschien also hinter der Karte.
  Dieselbe Lehre wie bei Schulalarm 1.0.26 („Ein Fehlerband unter einem
  Blatt sieht niemand"), und sie galt für diese Ansicht nicht.
  - **Die Quittung nennt, was übernommen wurde** — Ort, Name UND Uhrzeit.
    Wer eine Uhrzeit tippt, will genau diese zurückgelesen bekommen;
    „Gespeichert" allein ist keine Bestätigung, sondern eine Behauptung.
    Gelesen wird sie in derselben festen Zone, in der sie geschrieben
    wurde — mit der Zone des Geräts stünde dort eine andere Zahl als die
    getippte.
  - **Sie blendet NICHT von selbst weg.** Ein Band, das während des
    Nachlesens verschwindet, ist wieder keine Bestätigung. Weggeräumt wird
    sie durch eine Handlung: einen der beiden Knöpfe oder einen Tipp auf
    die Karte. Solange sie steht, ist die Eingabe zu und die Karte frei —
    das ist die zweite Hälfte des Befundes.
- **DIE TABELLE DES DRUCKDIENSTES SCHLÄGT DIE RECHNUNG**
  (`Umschlag.rueckentabelle`, ab 1.0.52, Ansage des Nutzers 09/2026: „Bei
  Saal Digital werden in einer Tabelle Breiten für den Buchrücken
  angegeben, die in Abhängigkeit der Seitenzahl des Buches zu erwarten
  sind."). Abhängig von der Seitenzahl war die Breite schon immer —
  gerechnet aus Blattzahl, Papierstärke und Einband. Was fehlte, ist der
  Weg, die Zahlen des Anbieters zu NEHMEN statt sie zu rechnen.
  - **Mitgeliefert wird keine Tabelle.** Versucht am 23.09.2026 (Saals
    Profi-Bereich und Preisseite) — beide geben die Zahlen nicht als Text
    heraus, sie stehen hinter einer Oberfläche. Eine nach Gefühl
    hingeschriebene Tabelle sähe aus wie eine Auskunft des Anbieters und
    wäre geraten; dieselbe Regel wie bei den Fahrplanquellen der
    Abfahrtstafel. Eingetragen wird sie unter Umschlag, Zeile für Zeile.
  - **Gilt die Zeile mit dem größten `abSeiten`, das das Buch erreicht** —
    und sagt die Tabelle über ein Buch nichts (leer, oder dünner als ihre
    erste Zeile), wird gerechnet. Die kleinste Zeile zu nehmen wäre
    falsch: Eine Tabelle, die bei 20 Seiten anfängt, hat über ein Buch mit
    12 Seiten keine Aussage getroffen.
  - **Woher die Zahl stammt, steht überall dabei**
    (`Umschlagmass.rueckenherkunft`). Eine gerechnete Zahl als Angabe des
    Druckdienstes auszugeben wäre genau die Art Lüge, die diese App nicht
    erzählt — dieselbe Regel wie bei „Plan" gegen „pünktlich".
- **Ein eigenes Seitenformat wird GEMERKT, nicht geraten**
  (`Model/Formatvorlagen.swift`, ab 1.0.52, Ansage des Nutzers 09/2026:
  „Speichere bitte auch die drei von mir gewählten Formate von Saal Digital
  als Formate für das Fotobuch."). Welche drei das sind, weiß diese App
  nicht, und eine Anbieterliste im Quelltext veraltet mit dem nächsten
  Angebot. Wer ein Maß eintippt, sichert es mit einem Tipp als Vorlage;
  sie liegt in den VOREINSTELLUNGEN und nicht im Buch — welche Formate ein
  Druckdienst anbietet, ist keine Eigenschaft dieser einen Reise (dieselbe
  Überlegung wie bei den selbst installierten Schriften seit 1.0.41).
  - **Angewandt ergibt eine eigene Vorlage ein FREIES Maß**, keinen neuen
    Vorlagennamen. `Seitenformat.init(from:)` löst einen alten
    Textschlüssel über `Seitenformat.vorlagen` auf; ein selbst vergebener
    Name stünde dort nie, und ein Buch mit einem Namen, den es beim
    nächsten Öffnen nicht mehr gibt, fiele still auf A4 quer zurück.
  - **21 × 28 cm und 28 × 21 cm sind dazugekommen**, weil sie zu den
    gängigsten Fotobuchformaten gehören und bisher fehlten. **Die Maße
    folgen der Formatangabe des Anbieters und sind nicht gemessen**; das
    steht so in der Oberfläche.
  - **Ein Beleg dafür, dass es SEINE Formate sind, gibt es nicht — und der,
    den ich zu haben glaubte, war keiner.** Das am 23.09.2026 geschickte
    PDF misst 595 × 793,72 Punkte (also 210 × 280 mm), und genau daraus
    stand hier kurzzeitig, 21 × 28 sei nachweislich sein Format. Beim
    Nachsehen enthielt die Datei aber ausschließlich Bilddaten und keinen
    einzigen Textzug: Es ist eine Zusammenführung von Bildschirmfotos, und
    ihr Seitenmaß gehört dem Werkzeug, das sie zusammengefügt hat.
    **Merke: Bevor ein Dateimaß als Beleg für den Inhalt gilt, ist zu
    prüfen, was in der Datei überhaupt steht.**
- **Zwei Dateien gab es seit 1.0.50 — gefunden hat sie niemand** (eigener
  Menüpunkt ab 1.0.52; gemeldet 09/2026: „Ich möchte bei der Exportfunktion
  Einbauen, dass automatisch ein Export von zwei PDF-Dateien vorgenommen
  werden soll."). Der Weg lag als eine von drei Zeilen in einem
  zugeklappten Picker hinter „Als PDF sichern…". **Zehnte Auflage von „es
  war da, man fand es nicht"**, und dieselbe Antwort wie bei der Broschüre
  in 1.0.37: derselbe Bildschirm, nur mit Vorwahl — und ein Name, der die
  Sache nennt („Umschlag und Innenteil getrennt…") statt des Werkzeugs.
  Kein zweiter Bildschirm; zwei Wege zu derselben Sache liefen auseinander.
  **Und bei einem Umschlagbogen sind zwei Dateien seither die VORWAHL** —
  das ist das „automatisch" aus der Ansage und nicht bloß Bequemlichkeit:
  Ein Bogen ist doppelt so breit wie eine Seite und hat mitten in einer
  Datei mit Buchseiten nichts zu suchen. Weggelassen wird dabei nichts;
  ausgegeben wird alles, nur eben zweimal.
- **Die Broschüre setzte die RÜCKSEITE nach vorn** (behoben in 1.0.52, beim
  Gegenlesen gefunden). In der Seitenfolge steht sie vorn, weil sie dort die
  linke Hälfte des Umschlagbogens ist — ein gefaltetes Heft hat aber weder
  Bogen noch Rücken: Dort ist die Titelseite die erste Seite und die
  Rückseite die letzte. Bis 1.0.51 lief sie als Heftseite 1 mit, also noch
  vor dem Titel. **Das war schon damals falsch und fiel erst auf, als die
  Zählung selbst zum Thema wurde** — dieselbe Wurzel, eine Ansicht weiter.
- **EIN `scaleEffect` IST EINE ABBILDUNG, KEINE ZEICHNUNG**
  (`Model/Bildschaerfe.swift`, ab 1.0.53; gemeldet 09/2026 mit einem
  Bildschirmfoto bei 400 %: „Wie wird der Text eigentlich gerendert? Er wirkt
  unscharf."). **Am Quelltext abzuzählen und keine Vermutung:** Core Animation
  rastert eine Ebene GENAU EINMAL, mit `layer.contentsScale` Bildpunkten je
  Punkt, und der Vorgabewert ist der Maßstab des Bildschirms. Der
  `scaleEffect` über der Seite zieht dieses fertige Bild danach auf. Der Text
  wurde also weiterhin mit zwei Bildpunkten je Seitenpunkt GESETZT und bei
  400 % auf acht GEZEIGT — ein halber gerasterter Punkt je Bildschirmpunkt.
  Nichts daran war falsch gezeichnet, es war zu grob gezeichnet.
  **Merke: Wer in einer UIView selbst zeichnet und sie vergrößern lässt, setzt
  `contentsScale` — sonst wird das Bild gedehnt statt neu gesetzt.** Dieselbe
  Wurzel wie `contentMode = .redraw` aus 1.0.8, eine Ebene tiefer: Dort wurde
  das Bild bei einer Größenänderung gedehnt, hier bei einer Vergrößerung.
  - **Dasselbe eine Ebene weiter bei den FOTOS.** `vorschaukante` stand auf
    festen 2,2 Bildpunkten je Seitenpunkt — richtig für die unvergrößerte
    Seite auf einem gewöhnlichen Gerät und sonst nirgends; bei 400 % blieb ein
    halber. Es war also nie ein Fehler des Textsatzes, sondern einer, den
    jedes gerasterte Element auf dieser Seite hatte.
  - **Die Zahl steht an EINER Stelle** (`Bildschaerfe`) und gilt für Text,
    Fotos, Wasserzeichen und Hintergrundfoto. Liefen sie auseinander, wäre auf
    derselben Seite das eine scharf und das andere weich.
  - **Der GERÄTEMASSSTAB kommt aus der eigenen Ansicht** —
    `traitCollection.displayScale` bzw. `\.displayScale` —, nie aus
    `UIScreen.main`: Hängt ein Beamer am iPad, wäre das die falsche Auskunft
    (dieselbe Lehre wie bei Tafelbilds Dokumentenkamera).
  - **Gestuft und gedeckelt.** Gestuft, weil jede Zwischengröße sonst ihre
    eigene Rasterung bekäme — und im `Bildarchiv` einen eigenen Eintrag, denn
    dessen Schlüssel nennt die Kante. Gedeckelt durch ein Pixelbudget je
    Fläche, weil ein Textkasten von 430 × 700 Punkten bei achtfacher
    Rasterung 77 MB wöge und mehrere davon in der Bühne liegen.
  - **`traitCollectionDidChange` ist seit iOS 17 abgekündigt** und wird
    deshalb NICHT überschrieben; ein Wechsel des Bildschirms läuft ohnehin
    durch `didMoveToWindow` und `layoutSubviews`.
  - **Die KARTE bleibt, wie sie ist**, und das ist kein Vergessen: Sie wird
    seit jeher mit vier Bildpunkten je Seitenpunkt aufgenommen
    (`Kartenwerk.massstab` = 2 auf eine doppelt so große Fläche). Weiter
    hinauf hilft es nicht — `Kachelkarte` ist auf 48 Kacheln gedeckelt (so
    will es die Nutzungsrichtlinie der OSM Foundation), und eine größere
    Anforderung zöge nur eine tiefere Zoomstufe nach sich, die an derselben
    Grenze wieder gröber wird. Bei starker Vergrößerung ist sie damit das
    gröbste Element auf der Seite; das gehört gesagt und nicht verschwiegen.
  - **Das Textfeld beim Bearbeiten ist NICHT mitgezogen.** `InlineText` ist
    ein `UITextView`, und der setzt über TextKit in eigene Unterebenen; ein
    `contentsScale` an der äußeren Ansicht erreicht sie nicht verlässlich.
    Wer bei starker Vergrößerung doppeltippt, sieht also weiter weichen Text.
    Nicht als erledigt darstellen.
- **Und weil sich das hier nicht nachmessen lässt, sagt es die App**
  (`Schaerfeprobe`, im Befund unter „Bedienung prüfen", ab 1.0.53). Gemeldet
  wird, was WIRKLICH gesetzt wurde: Bildpunkte je Seitenpunkt gegen die, die
  gebraucht würden, dazu Gerätemaßstab, Bühnenmaßstab, die Größe des Kastens
  und ob das Budget gedeckelt hat. Nach einer Fassung, deren Ursache gerechnet
  und nicht gesehen ist, ist das der einzige Weg, die nächste Frage mit Zahlen
  statt mit Vermutungen zu beantworten — dasselbe Muster wie Schulalarms
  Stufenprobe und der Kartenmesser der Abfahrtstafel. **Ein schlichtes
  `final class` ohne `@Published`**, aus demselben Grund wie beim
  `Zeichenmesser`: Wäre es beobachtbar, löste jede Rasterung ein Neuzeichnen
  aus, das seinerseits gemeldet würde.
- **DIE TABELLE LAG SCHON HIER — im PDF, das der Nutzer mitgeschickt hatte**
  (`Model/Rueckentabellen.swift`, ab 1.0.54; Ansage des Nutzers 09/2026:
  „Ich habe dir bereits eine Tabelle von Saal Digital hochgeladen. Das war
  das PDF-Dokument mit den eingescannten Bildern. Schau dort bitte rein und
  übernimm diese Werte."). In 1.0.52 stand an dieser Stelle das Gegenteil:
  Die Tabelle werde „EINGETRAGEN und nicht mitgeliefert", weil sie sich von
  hier aus nicht abrufen lasse. Für die Webseite stimmte das; die Zahlen
  lagen trotzdem längst hier. Dieselbe Datei war in 1.0.52 schon einmal
  untersucht worden — aber nur auf die Frage, ob ihr Seitenmaß als Beleg für
  ein Buchformat taugt, und die Antwort („sie enthält nur Bilddaten") wurde
  zur Auskunft über ihren INHALT verallgemeinert. **Merke: Bevor etwas als
  unerreichbar gilt, wird nachgesehen, was schon dasteht — und ein Befund
  über eine Datei beantwortet nur die Frage, die ihm gestellt wurde.**
- **Gelesen wurde aus den BILDDATEN, nicht aus Textzügen** (23.09.2026). Das
  PDF trägt neun Bildschirmfotos zu je 2048 × 2732 Bildpunkten, flate-gepackt
  in einem ICC-RGB-Raum und ohne einen einzigen Textzug. Entpackt und
  angesehen ergeben sie drei vollständige Tabellen: „Fotobuch 21 × 28
  (ca. A4)", „Fotobuch 28 × 28" und „Fotobuch 28 × 19 (ca. A4 quer)", jeweils
  Hardcover, jeweils von 26 bis 160 Innenseiten. **Damit ist auch die Frage
  aus 1.0.52 beantwortet, welche drei Formate der Nutzer meint.**
- **Was dort steht, sind PIXEL.** Saal gibt den Buchrücken als Bildbreite
  samt Auflösung an — 142 px bei 300 dpi, beim Querformat 143 px bei 302 dpi;
  das sind 12,02 bzw. 12,03 mm. Alle drei Tabellen ergeben dieselbe Leiter
  aus ganzen Millimetern, und die größte Abweichung dabei ist 0,05 mm. Im
  Quelltext stehen deshalb die ganzen Millimeter, die Pixelwerte daneben im
  Kommentar: Das ist eine Rundung und keine Erfindung.
- **Zwei Eigenarten der Leiter sind übernommen, nicht geglättet.** Sie
  überspringt 17 und 23 mm (189 → 213 px, 260 → 283 px), und die Formate
  unterscheiden sich NICHT in den Millimetern, sondern nur darin, bei welcher
  Seitenzahl eine Stufe anfängt: 21 × 28 ist den beiden anderen um genau eine
  Stufe voraus (26–28 → 12 mm, dann 30–34 → 13 mm; sonst 26–30 → 12 mm).
  Warum, sagt die Tabelle nicht, also steht auch keine Erklärung da. Eine
  Zeile ist nicht unmittelbar abgelesen: 72 fiel in die Lücke zwischen zwei
  Bildschirmfotos und folgt aus ihrer Dreiergruppe — das steht so im
  Quelltext.
- **Über ihrer letzten Zeile schweigt eine Tabelle genauso wie unter ihrer
  ersten** (`Vorlage.bisSeiten`, 160). Einem Buch mit 200 Seiten die 36 mm
  der Zeile 158 zu geben wäre kein Nachschlagen mehr, sondern eine
  Hochrechnung — dort wird wieder gerechnet. Die EIGENE, eingetippte Tabelle
  hat diese Grenze nicht: Sie gehört dem Nutzer, und was er einträgt, gilt.
- **Eigene Zeilen gehen jeder mitgelieferten Tabelle vor** (`Umschlag.tabellenbreite`).
  Was jemand selbst einträgt, hat er von seinem Druckdienst; was hier
  beiliegt, ist von einem Bildschirmfoto abgelesen. Die Reihenfolge ist
  damit: eigene Tabelle, eingebaute Tabelle, Rechnung aus Papierstärke und
  Einband — und `rueckenherkunft` nennt bei jeder Zahl, welche der drei es
  war. Eine abgelesene Zahl als Rechnung auszugeben (oder umgekehrt) wäre
  genau die Art Lüge, die diese App nicht erzählt.
- **Welche Tabelle gilt, entscheidet das SEITENFORMAT — mit großzügiger
  Toleranz, und die ist gemessen.** Der Produktname und das Maß der
  mitgelieferten Vorlage gehen bei Saal auseinander: Die Innenseiten-Vorlage
  des „21 × 28" misst 5031 × 3260 px bei 300 dpi, abzüglich der angegebenen
  35 px Beschnitt also 420,0 × 270,1 mm — zwei Seiten von **210 × 270**.
  Beim „28 × 28" sind es 270 × 270, beim „28 × 19" 280 × 188. Eine Toleranz
  unter einem Zentimeter verfehlte damit genau das Format, für das die
  Tabelle gedacht ist; sie steht auf 12 mm. **Die Maße der Vorlagen folgen
  trotzdem dem PRODUKTNAMEN**, und die abweichende Messung steht als Messung
  daneben: Welches von beidem die Druckerei schneidet, sagt der Anbieter und
  nicht diese App.
- **Verglichen wird das ungeordnete PAAR der Kanten.** Ob ein Buch hoch oder
  quer steht, ändert am Papier nichts, und die Dicke hängt am Papier — Saals
  eigene Zahlen belegen das, denn 28 × 19 quer trägt dieselbe Millimeterleiter
  wie 28 × 28.
- **Der Nutzer kann die Zuordnung übergehen** (`Umschlag.tabellenvorlage`,
  `.ohneVorlage`). „Nichts gewählt" und „ausdrücklich keine" sind zwei
  verschiedene Aussagen und stehen deshalb in zwei Feldern — dieselbe Lehre
  wie bei `Block.ohneGrund` seit 1.0.12. Dazu ein Knopf, der die Zeilen in
  die eigene Tabelle übernimmt: Wer die Zahlen ändern will, will sie danach
  auch vor sich sehen.
- **DIE AUTOMATIK GAB ES, DIE KORREKTUR NICHT** (`Wasserzeichenabweichung`,
  `Views/WasserzeichenSeiteView.swift`, ab 1.0.54; Ansage des Nutzers
  09/2026: „Ich habe mich unpräzise ausgedrückt. Bei dem Wasserzeichen hätte
  ich gerne eine automatische Ausrichtung durch dich im einstellbaren
  Toleranzbereich … Dennoch soll es mir möglich sein, einzelne Seiten
  bezüglich des Wasserzeichens noch anzupassen und die Drehung oder eine
  Verschiebung zu korrigieren. Offenbar hast du mich falsch verstanden.").
  Die automatische Hälfte war gebaut: Die LAGE wird seit 1.0.46 auf jeder
  Seite neu gesucht, der WINKEL seit 1.0.52 je Seite aus ihrer Kennung
  gezogen. Was fehlte, ist die zweite Hälfte — und im Quelltext stand sogar
  wörtlich das Gegenteil davon („die Seite selbst kann nichts davon
  abweichen — genau das ist der Sinn eines Wasserzeichens"). **Merke: Wo ein
  Nutzer sagt, er sei missverstanden worden, ist zuerst zu prüfen, welche
  Hälfte seiner Bitte schon dasteht — und dann die andere zu bauen, nicht
  die erste noch einmal.**
- **Abweichung, keine Kopie.** `Seite.wasserzeichen` ist wahlweise; `nil`
  heißt „ganz automatisch", ein eigener Winkel `nil` heißt „der gezogene".
  Würde eine angefasste Seite alle Werte kopieren, wäre jede spätere Änderung
  an Größe, Deckkraft oder Drehspanne an ihr wirkungslos — und zwar
  unsichtbar. Dieselbe Regel wie bei `Schriftabweichung`, `Block.wirkung` und
  `Kartenwahl`. Eine Abweichung, die nichts mehr sagt, wird wieder `nil`:
  Sonst zählte die Druckprüfung eine Korrektur, die keine ist.
- **Aufgelöst wird an EINER Stelle** (`Wasserzeichenlage.ort`), gefragt von
  der Ansicht UND vom PDF. Der eigene Winkel gilt auch dann, wenn die
  Drehung im Buch ausgeschaltet ist — wer eine einzelne Seite schräg haben
  will, sagt das dort. Und die Verschiebung bleibt IM SATZSPIEGEL: Dieselbe
  Grenze gilt für die Automatik, und was darüber hinausginge, wäre im Druck
  angeschnitten. Die Oberfläche schreibt das hin, statt den Regler ins Leere
  laufen zu lassen.
- **Der Versatz ist eine LÄNGE und wird beim Formatwechsel mitgerechnet**,
  der Winkel nicht — dieselbe Trennung wie zwischen Blockrahmen und
  Blockdrehung seit 1.0.27.
- **Ohne Rettung wäre die Korrektur nach dem nächsten Neuanordnen weg**
  (`Reisewerk.seitenNeuSetzen`). Der Layoutautomat baut die Seiten frisch;
  übernommen wird die Korrektur nach der STELLE im Tag und nicht nach der
  Kennung, denn die neuen Seiten haben neue — und damit zieht die Automatik
  ohnehin einen anderen Winkel. Das ist eine Entscheidung und keine Messung,
  und die Oberfläche sagt sie auch. Dasselbe Muster wie die Karteneinstellung
  seit 1.0.51: **Es gibt genau EINEN Weg, der Seiten setzt, und wer einen
  zweiten baut, ruft diesen hier.**
- **Eine Wasserzeichen-Korrektur ist KEINE Handarbeit am Satz.** Sie setzt
  `vonHand` nicht — sonst fiele ein Tag wegen eines halben Grads für immer
  aus dem automatischen Neuanordnen heraus; dieselbe Überlegung wie bei
  `karteAendern` seit 1.0.51. Genau deshalb muss die Rettung darüber
  existieren.
- **Die Oberfläche zeigt die Automatik, statt sie zu behaupten.** Das Blatt
  nennt den Winkel, den diese Seite automatisch bekommt, und zeichnet eine
  SKIZZE: Satzspiegel, die Blöcke als graue Flächen, das Zeichen an seiner
  gerechneten Stelle und in seinem gerechneten Winkel — gezeichnet aus
  demselben `ort`, den auch das PDF fragt. Dass Winkel und Lage von Seite zu
  Seite wechseln, lässt sich hinschreiben; hier steht es als Zahl und als
  Bild. Das ist die halbe Antwort auf „offenbar hast du mich falsch
  verstanden".
- **EIN SCHLEIER NIMMT DEN FARBEN IHREN ABSTAND — UND DAS IST AUSZURECHNEN**
  (`Model/Farbkraft.swift`, `Seitenhintergrund.farbkraft`, ab 1.0.55;
  Befund des Nutzers 09/2026: „Beim Seitenhintergrund stelle ich fest, dass
  eine Einstellung von Transparenz dazu führt, dass die Farben sich eher
  Richtung Grau in Grau verschieben. … ich könnte mir vorstellen, dass man
  gleichzeitig beim Zurücknehmen der Deckungskraft auch die Kräftigkeit der
  Farben erhöht."). Er hat recht, und es ist kein Eindruck: Über dem
  Hintergrundfoto liegt eine Fläche in der Papierfarbe mit der Deckkraft a,
  herauskommt `(1 − a) · foto + a · papier`. Der ABSTAND zwischen größtem
  und kleinstem Kanal eines Bildpunktes — also genau das, was eine Farbe
  von einem Grau unterscheidet — wird damit mit `(1 − a)` multipliziert.
  Beim Vorgabeschleier von 72 % bleibt gut ein Viertel übrig, und weil das
  JEDE Farbe des Bildes trifft, rücken sie alle zusammen.
- **Dagegen hilft genau EIN Faktor.** Wird das Foto VOR dem Schleier
  gesättigt (`neu = licht + k · (kanal − licht)`), wächst derselbe Abstand
  um k; mit `k = 1 / (1 − a)` steht er nach dem Schleier wieder dort, wo er
  war. Das Bild bleibt blass und wird trotzdem bunt — pastell statt grau,
  also genau das Erbetene.
- **Was der Faktor NICHT kann, steht in derselben Zeile.** Zurückgeholt wird
  der ABSTAND der Kanäle, nicht die Sättigung im engeren Sinn: Sättigung ist
  Abstand geteilt durch Helligkeit, und die Helligkeit hebt der Schleier
  mit. Rechnerisch kommt der bunteste denkbare Bildpunkt hinter einem
  Schleier von a auf `1 − a` Sättigung heraus — bei 72 % also 28 %, und
  mehr ist dort überhaupt nicht möglich, ganz gleich, was das Foto zeigt.
  Der Regler führt bis an diese Decke und keinen Schritt weiter; die
  Oberfläche nennt die Zahl. **Eine Grenze, die man verschweigt, wird für
  einen kaputten Regler gehalten.**
- **Was er kostet, wird GEMESSEN und nicht geschätzt** (`Farbkraft.randanteil`).
  Was über 1 oder unter 0 gestreckt wird, klemmt ab, und dort verliert das
  Bild seine Zeichnung. Gezählt wird an einer 48 Bildpunkte großen Fassung,
  einmal vorher und einmal nachher — gemessen ist damit das SIEB selbst und
  keine Annahme darüber, mit welchen Gewichten `CIColorControls` rechnet.
  Ein Foto mit weißem Himmel liegt schon ohne Faktor am Rand; das dem
  Schieber anzulasten wäre eine falsche Auskunft, deshalb die Differenz.
- **Gesättigt wird an EINER Stelle.** `Farbkraft.verstaerkt` ruft der
  Bildschirm (über `Bildarchiv.vorschau(…farbkraft:)`) und das PDF
  (`Seitensatz.zeichneHintergrund`); den Faktor nennt beiden
  `Seitenhintergrund.farbkraftfaktor`. Zwei Wege ergäben zwei Bilder, und
  der Unterschied fiele erst auf, wenn das Buch beim Drucker liegt — die
  erste Regel dieser App. Gerundet wird auf Zwanzigstel (`Farbkraft.stufe`),
  weil der Faktor im Schlüssel des Bildvorrats steht: **Ohne ihn im
  Schlüssel stünde nach dem Umstellen das Bild von vorhin da, und der
  Schieber sähe aus, als täte er nichts** — dieselbe Falle wie beim
  `merkmal` des Kartenbildes in 1.0.51.
- **Nur beim FOTO, und der Grund gehört dazu.** Eine einfarbige Fläche mit
  halber Deckung über weißem Papier IST eine hellere Farbe — dort ist
  nichts auszugleichen, dort wählt man gleich die hellere. Grau in Grau
  wird nur ein Bild, weil darin viele Farben zugleich zusammenrücken. Das
  steht so in der Fußzeile, statt einen Regler anzubieten, der dort nichts
  tut.
- **Dieselbe Arithmetik gilt für das Wasserzeichen und für einen farbigen
  Textgrund — dort wird sie bewusst NICHT ausgeglichen.** Ein Wasserzeichen
  SOLL zurücktreten, und ein Grund unter Schrift soll die Schrift tragen
  und nicht mit ihr konkurrieren. Wer es dort nachrüstet, sagt vorher, was
  dadurch besser wird.
- **Vorgabe 0.** Jedes vorhandene Buch sieht nach dem Update unverändert
  aus — dieselbe Überlegung wie bei `ueberDoppelseite` in 1.0.47.
- **ZEHN WASSERZEICHEN STATT EINEM — und die Kennung der Seite zieht**
  (`Zeichenbild`, `Wasserzeichen.bilder`, `Wasserzeichenlage.automatischesBild`,
  ab 1.0.56; Ansage des Nutzers 09/2026: „Ich möchte die Möglichkeit haben,
  noch mehr Bilder für ein Wasserzeichen hochzuladen. Möglich sein sollen
  insgesamt bis zu zehn verschiedene. Diese sollen dann nach dem
  Zufallsprinzip auf den einzelnen Seiten abgelegt werden. Auch hier möchte
  ich im Nachhinein entscheiden können, welches Symbol auf einer Seite zu
  liegen kommt.").
- **Das Seitenverhältnis gehört dem BILD, nicht dem Wasserzeichen.** Bis
  1.0.55 stand die Zahl an `Wasserzeichen`, weil es nur ein Bild gab; bei
  zehn gilt sie je Bild — und die Lagerechnung braucht genau die des
  Bildes, das auf DIESER Seite liegt. Deshalb der eigene Typ `Zeichenbild`.
  Alles andere (Deckkraft, Größe, Lage, Drehspanne, Titelblatt) bleibt am
  Wasserzeichen: Das ist eine Entscheidung über das Buch und nicht über
  ein einzelnes Symbol.
- **`Ort` sagt seit 1.0.56 auch, WELCHES Bild hier liegt.** Es steht in
  derselben Antwort wie der Rahmen, weil beides zusammenhängt: Die Höhe
  folgt dem Seitenverhältnis dieses Bildes. Wer es getrennt ermittelte,
  zeichnete irgendwann ein Bild in den Rahmen eines anderen — und das
  fiele erst im gedruckten Buch auf. **Buchausgabe holt deshalb erst die
  LAGE und dann die Datei**, nicht mehr umgekehrt: Vorher lässt sich gar
  nicht wissen, welche Datei zu holen ist.
- **Gezogen wird aus der KENNUNG der Seite, nie aus dem Zufall.** Dritte
  Auflage derselben Regel nach Papierkorn (1.0.16), Seitenrhythmus (1.0.31)
  und Zeichenwinkel (1.0.52): Dasselbe Buch muss beim nächsten Öffnen
  gleich aussehen, und das PDF muss zeigen, was auf dem Bildschirm steht.
  Es ist die DRITTE Zahl aus derselben Kennung und wird eigens gemischt —
  die Lage nimmt den Rest zur Feldzahl, der Winkel einen anderen Rest.
  Nähme das Bild denselben, hinge es an der Ecke, und jedes Zeichen oben
  links wäre dasselbe.
- **Eine laufende Nummer wäre gleichmäßiger und ist bewusst NICHT gebaut.**
  Die Kennung der Seite ist das Einzige, worüber sich alle vier
  Aufrufstellen einig sind (Bildschirm, PDF, Druckprüfung, das Blatt für
  eine Seite). `Buchseite.rang` gibt es in zweien davon, in den anderen
  nicht in derselben Zählung — und zwei Zählungen ergäben ein PDF, das
  anders aussieht als die Vorschau. **Der Preis steht dafür im Befund:**
  Gleichverteilt ist das Ziehen im ERWARTUNGSWERT und nicht gleich oft; bei
  zehn Bildern auf vierzig Seiten bleibt rechnerisch mit rund einem Siebtel
  Wahrscheinlichkeit eines ganz ungenutzt. Die Druckprüfung zählt deshalb
  seit 1.0.56, wie oft jedes Bild wirklich vorkommt, und sagt es, wenn
  eines gar nicht vorkommt. Dieselbe Lehre wie bei den Linienfarben der
  Abfahrtstafel: **Ein Streuwert verteilt zufällig, nicht gleichmäßig.**
- **Die Korrektur nennt den DATEINAMEN, nicht die Nummer**
  (`Wasserzeichenabweichung.bild`). Wer ein anderes Bild entfernt,
  verschöbe sonst alle Nummern dahinter, und die Seite zeigte plötzlich ein
  fremdes Zeichen. **Ein Name, den es nicht mehr gibt, zählt als nicht
  gesetzt** — die Seite fällt auf die Automatik zurück, statt eine leere
  Fläche zu versprechen; dieselbe Regel gilt im Wähler, sonst stünde dort
  eine Auswahl, die es nirgends gibt.
- **Ein alter Schlüssel wird weiter GELESEN** (`AlteZeichenschluessel`,
  dieselbe Bauweise wie in `Model/Reise.swift`). Jede Datei von vor 1.0.56
  trägt `datei` und `seitenverhaeltnis` statt der Liste; ohne diesen Weg
  verlöre jedes vorhandene Buch sein Wasserzeichen, und zwar STILL — die
  Einstellung stünde weiter in der Datei, das Bild fehlte. Gelesen wird der
  alte Schlüssel nur, wenn die Liste LEER ist, sonst stünde ein längst
  entferntes Bild wieder darin.
- **Hinzugefügt, nicht ersetzt** — und mehrere Dateien auf einmal
  (`Dateiwahl(mehrere: true)`): Wer zehn Symbole hat, soll nicht zehnmal
  denselben Weg gehen. Was über die Zehn hinausgeht, wird GEZÄHLT und
  gemeldet; stillschweigend die Hälfte zu verschlucken wäre der schlimmere
  Fehler.
- **Und wer eine neue Bildart anlegt, trägt sie in `Buchdatei.schreiben`
  ein.** Die Zeichenbilder sind keine Reisefotos und stehen in keiner
  Fotoliste; seit 1.0.56 ist es eine Schleife über `gueltigeBilder` statt
  einer einzelnen Datei. Vergäße man sie, verlöre ein ausgetauschtes Buch
  seine Zeichen.
- **VIER GIGABYTE WAREN DREI FEHLER AUF EINMAL** (ab 1.0.70; gemeldet
  09/2026: „muss auch einen Link geben, dass die Exportdatei bei 62 Seiten
  nicht 4 Gigabyte groß wird. Denn das wird von den Druckdiensten leider
  nicht angenommen.“). Jeder für sich ist unauffällig; zusammen ergeben sie
  eine Datei, die niemand hochladen kann.
  - **Jedes Bild bekam dieselbe Höchstkante.** `fuerAusgabe` rechnete alles
    auf `bildkante` herunter — ein Briefmarkenfoto auf dieselben 3600
    Bildpunkte wie ein randabfallendes. Gedruckt wird aber eine FLÄCHE, und
    was mehr Bildpunkte je Zoll trägt, als das Papier auflöst, ist Platz
    ohne Bild. Gerechnet wird die Kante seit 1.0.70 je Bild aus dem Rahmen,
    in den es gezeichnet wird (`Ausgabeguete.ausgabekante`): `ziel / 72 *
    dpi`, gedeckelt durch die Güte. **Wer diese Rechnung ändert, ändert die
    Prüfung mit** — `Ausgabeguete.dpi` kennt den neuen Deckel, sonst nennt
    sie wieder eine Zahl, die die Datei nicht hält (die Lehre aus 1.0.59).
  - **Das Wasserzeichen wurde JE SEITE frisch geladen** — mit voller
    Höchstkante, auf jeder der 62 Seiten. Das allein sind Dutzende
    Megabyte für ein Zeichen, das auf dem Papier eine Handbreit misst. Es
    kommt jetzt einmal je Datei aus `wasserzeichenbilder`, in der Größe,
    die es wirklich einnimmt. Dass CoreGraphics dasselbe `UIImage` zu
    einem einzigen Bild in der Datei zusammenfasst, ist die Erwartung und
    **nicht gemessen**; die kleinere Kante wirkt unabhängig davon.
  - **`UIImage.draw(in:)` schreibt UNKOMPRIMIERT.** Drei Byte je
    Bildpunkt — ein seitenfüllendes Foto bei 300 dpi sind rund 25 MB.
    Stammt ein `CGImage` dagegen aus einem JPEG-Datenstrom, übernimmt
    CoreGraphics diesen Strom unverändert (DCTDecode), statt ihn zu
    entpacken (`Seitensatz.jpegEingebettet`). **Erwartung, keine Messung**:
    Greift es nicht, ist die Datei so groß wie vorher, kaputt ist nichts.
  - **Ein Bild MIT Alphakanal wird NIE als JPEG geschrieben.** JPEG kennt
    keine Durchsichtigkeit; eine eingesetzte Grafik mit freigestelltem
    Grund bekäme einen weißen Kasten. Das ist die eine Stelle, an der
    diese Abkürzung sichtbar falsch wäre — deshalb wird sie geprüft und
    nicht angenommen. **Das Wasserzeichen bleibt aus demselben Grund
    unkomprimiert** und wird gar nicht erst gefragt.
  - **Gezeichnet wird dann mit `CGContext.draw`, und das rechnet von UNTEN
    links.** Der Zeichenkontext dieser App ist längst umgedreht, also wird
    um die Mittellinie des Zielrechtecks noch einmal gespiegelt. Wer das
    vergisst, bekommt jedes Foto auf dem Kopf — und zwar nur im PDF.
  - **Die Güte trägt seither DREI Zahlen** (Höchstkante, Ziel-dpi,
    JPEG-Güte), und der Auftrag wird an EINER Stelle gebaut
    (`AusgabeView.auftrag(…)`). Sechsmal derselbe Aufruf mit drei Feldern
    wäre sechsmal die Gelegenheit, eines zu vergessen — und ein vergessenes
    `jpegGuete` fällt erst an der Dateigröße auf.
  - **Die Größe steht VOR dem Ausgeben da** (`Ausgabeguete.groessenschaetzung`,
    Zeile unter der Gütewahl). Bis 1.0.69 stand sie erst danach — nach
    zwanzig Minuten Rechnen und mit einer Datei, die kein Dienst annimmt.
    **Es ist eine SCHÄTZUNG und sagt das auch**: Gezählt werden die
    Bildpunkte, die wirklich geschrieben werden; wie dicht ein JPEG die
    packt, hängt am Motiv. Danebengestellt wird, was dieselben Bilder
    unkomprimiert wögen — das ist die Zahl, die der Nutzer gesehen hat.
  - **Nicht gemessen (1.0.70):** Keine Datei ist damit ausgegeben worden.
    Gerechnet ist die Geometrie; **die beiden großen Hebel — JPEG-Strom
    und Zusammenfassen gleicher Bilder — sind Erwartungen an CoreGraphics
    und keine Messungen**. Was sicher wirkt, ist die kleinere Kante. Ob aus
    vier Gigabyte ein paar hundert Megabyte werden, sagt erst die nächste
    Ausgabe des Nutzers — und seit 1.0.70 sagt die Schätzung vorher eine
    Zahl, die sich daran messen lässt. **Nicht als erledigt darstellen.**
- **EIN VORSCHAUBILD HIELT DEN HAUPTFADEN AN — seit 1.0.59 als offen
  notiert** (`Views/Vorschaubild.swift`, `Bildarchiv.ausVorrat`/`.holen`, ab
  1.0.81; gemeldet 09/2026, zum wiederholten Mal: „Das Scrollen über mehrere
  Seiten hinweg gestaltet sich auf dem iPad echt schwierig. Offenbar muss da
  doch noch sehr viel im Hintergrund nachgeladen und aufgebaut werden.").
  - **Am Quelltext abzuzählen, und der Punkt stand dort seit 1.0.59:**
    `Bildarchiv.vorschau` liest bei einem Fehlschlag im Vorrat SYNCHRON von
    der Platte und entpackt das Bild sofort
    (`kCGImageSourceShouldCacheImmediately`) — aufgerufen wurde sie im
    KÖRPER der Seitenansicht, also auf dem Hauptfaden. Beim Scrollen baut
    der `LazyVStack` laufend neue Blätter, und jedes zog seine drei bis
    sechs Bilder nach; das Hintergrundfoto ist dabei das größte, es füllt
    Seite oder Doppelseite ganz aus. **Merke: Ein offener Punkt, der
    zweimal als „nicht gemessen" dasteht, ist beim dritten Befund der erste
    Verdacht.**
  - **`ausVorrat` fragt nur den Vorrat und kostet nichts**; ist dort nichts,
    holt `Vorschaubild` es über `holen` abseits des Hauptfadens.
    `Task.detached` und nicht bloß `Task`: Ein nacktes `Task` in einer
    `@MainActor`-Ansicht erbt den Hauptfaden — dann wäre nichts gewonnen
    (dieselbe Falle wie bei Schulalarms `BackgroundRefresh`, nur
    andersherum).
  - **Kein Platzhalter mit Symbol.** Eine Seite, auf der für einen
    Augenblick graue Kästen mit Bildzeichen stehen, sieht kaputter aus als
    eine, auf der das Bild eine Wimper später erscheint.
  - **Der Schlüssel nennt Datei, Kante UND Farbkraft.** Eine vergessene
    Stelle zeigte nach dem Umstellen das Bild von vorhin — dieselbe Falle
    wie beim `merkmal` des Kartenbildes in 1.0.51.
  - **Die Zähler im `Bildarchiv` sind GESPERRT.** `vorschau` läuft seit
    1.0.81 auch aus einem Hintergrundfaden; zwei Fäden, die auf dieselbe
    Zahl addieren, sind ein Datenrennen — auch wenn die Zahl nur eine
    Auskunft ist.
  - **Und weil sich das hier nicht nachmessen lässt, misst es die App:** Der
    Befund unter „Bedienung prüfen" nennt seither „Bilder: n× aus dem
    Vorrat, m× von Platte". Bleibt m beim Blättern klein, liegt es nicht
    mehr an den Bildern — dann ist der nächste Verdacht der CoreText-Satz je
    Textkasten. Dasselbe Muster wie Schulalarms Stufenprobe.
  - **Offen und nicht als erledigt darstellen:** Umgestellt sind die drei
    Stellen der BÜHNE (Fotokachel, Hintergrundfoto, Wasserzeichen). Die
    Listen und Blätter (Regal, Tagesliste, Hintergrundwahl, Stilwahl) holen
    ihre kleinen Bilder weiterhin synchron; sie scrollen auch, sind aber
    nicht der gemeldete Fall, und eine Sache wird auf einmal geändert.
- **WAS IN DEN ANSCHNITT ODER IN DEN SICHERHEITSABSTAND RAGT, BEKOMMT EINEN
  DICKEN ROTEN RAHMEN** (`Reise.ueberDerSchnittkante`, `.amRandGefaehrdet`,
  `Randmarke`, ab 1.0.81; Ansage des Nutzers 09/2026: „Ich möchte ab jetzt,
  dass ein Element, was in den Beschnittbereich oder den Sicherheitsbereich
  hineinragt, mit einem noch besser zu sehenden Rand versehen wird. Gerne
  ein dicker roter Rand.").
  - **Der ANSCHNITT wurde gar nicht geprüft.** Markiert war seit 1.0.76 nur
    der Sicherheitsabstand — dabei ist der andere Fall der teurere: Ein
    Block, der über die Schnittkante ragt und nicht randabfallend ist, wird
    im gedruckten Buch ANGESCHNITTEN, und das fiel erst am Papier auf. Die
    Druckprüfung zählt ihn seither als eigene Zeile.
  - **Die Marke hängt NICHT mehr an „Linien zeigen".** Sie tat es seit
    1.0.76, und das war falsch: Die Linien sind eine Hilfe beim Anordnen,
    die Marke ist eine WARNUNG. **Eine Warnung, die sich mit den
    Hilfslinien abschalten lässt, ist keine.**
  - **Rot, obwohl die Schnittkante auch rot ist** — das ist die Ansage des
    Nutzers, und sie geht auf: Die Marke ist dreimal so dick, durchgezogen
    statt gestrichelt, läuft um einen BLOCK und nicht am Blattrand und
    trägt eine Kontur. Zu verwechseln sind die beiden nicht.
  - **Randabfallende Blöcke bleiben ausgenommen, ohne Ausnahme** — sie
    SOLLEN über die Kante laufen; nach der dritten falschen Marke sieht
    niemand mehr hin.
- **Nicht gemessen (1.0.81):** Nichts davon ist auf einem Gerät gesehen
  worden. **Am Quelltext ABGEZÄHLT ist die Ursache des zähen Scrollens** (ein
  synchroner Griff auf die Platte samt sofortigem Entpacken, im Körper jeder
  Seite, bei jedem neuen Blatt) — **dass es danach flüssig ist, folgt daraus
  NICHT**: Es kann eine zweite Ursache darüberliegen, und der
  wahrscheinlichste nächste Verdacht ist der CoreText-Satz je Textkasten.
  Genau dafür nennt der Befund jetzt zwei Zahlen statt einer Zusage. Ebenso
  ungesehen: ob die leere Fläche vor dem Eintreffen des Bildes stört und ob
  ein dicker roter Rahmen neben der roten Schnittkante wirklich zu
  unterscheiden ist. **Nichts davon als erledigt darstellen.**
- **DREI LINIEN, DREI FARBEN — UND EINE KONTUR, DAMIT MAN SIE AUF JEDEM
  GRUND SIEHT** (`Model/Seitenlinien.swift`, ab 1.0.80; gemeldet 09/2026 mit
  Bildschirmfoto: „Die dünn gestrichelte rote Linie für den Mindestabstand
  kann ich nur schwer erkennen. Ich hätte hier gerne eine ebenso dicke Linie
  wie für den Beschnitt, nur in einer anderen Farbe, zum Beispiel hier blau.
  Ich frage mich, ob man diese Linien auch sieht, wenn der Seitenhintergrund
  dunkel gewählt wird. … Auf dem Beispielbild sind noch weitere Linien zu
  sehen. Welche sind das denn eigentlich?").
  - **Drei Befunde in einer Frage, und alle drei treffen.**
  - **Die Abwägung von 1.0.73 war falsch herum.** Dort stand, der
    Sicherheitsabstand sei orange und „**nicht blau**: Das ist beim
    Einrasten seit jeher der NACHBAR, und dieselbe Farbe für zwei Auskünfte
    ist eine Auskunft weniger." Der Satz stimmt — nur trägt die Fanglinie
    des Nachbarn ihren NAMEN am Strich und steht nur, solange ein Finger
    zieht; die Schutzzone steht dauernd da und trägt nichts. **Wer von zwei
    Auskünften eine benennen kann, gibt der anderen die klarere Farbe.** Der
    Sicherheitsabstand ist seither blau und ebenso dick wie die
    Schnittkante, der Nachbar violett.
  - **Farbe allein trägt nicht**: Die beiden dicken Linien unterscheiden
    sich zusätzlich im Strichbild (lang gegen kurz), sonst wären sie für
    einen farbfehlsichtigen Menschen dieselbe Linie — dieselbe Regel wie
    beim entfallenden Halt in der Abfahrtstafel.
  - **Die dritte Linie war der SATZSPIEGEL, und niemand hatte sie je
    benannt.** Sie lief in `Color.accentColor`, also in einem Ton, den die
    App setzt; auf einem Buch mit warmer Akzentfarbe stand sie neben zwei
    rötlichen Linien. Sie ist jetzt neutral grau und fein gepunktet: Sie ist
    die schwächste der drei Auskünfte — eine Hilfe für den Satz und keine
    Angabe der Druckerei.
  - **Auf dunklem Grund verschwanden alle drei.** `Seitenhintergrund.dunkel`
    gibt es seit 1.0.0, und gefragt hat sie nur der Textsatz. Jede Linie
    bekommt deshalb eine KONTUR in der Gegenfarbe und auf dunklem Grund
    einen helleren Ton. **Die Kontur ist der wichtigere Teil**: Bei einem
    FOTO als Hintergrund hilft keine Farbwahl, weil der Untergrund
    stellenweise hell und stellenweise dunkel ist — dieselbe Bauweise wie
    bei den Linienzügen der Abfahrtstafel (1.1.9).
  - **Die Farben standen DOPPELT da** — in `SeitenflaecheView` und in
    `Fanglinie` — und waren schon auseinandergelaufen (verschiedene
    Strichstärken für dieselbe Sache). Sie stehen jetzt in `Seitenlinie`,
    gefragt von der Seite, der Fanglinie, der Skizze und der Legende. **Wer
    eine vierte Stelle baut, fragt dort.**
  - **„Welche sind das denn eigentlich?" ist ein Befund über die
    OBERFLÄCHE.** Die Legende gab es — in der Skizze unter „Ränder und
    Druckzugaben", also dort, wo man die Zahlen einstellt, und nicht dort,
    wo man die Linien sieht. Sie steht seit 1.0.80 zusätzlich als Band über
    der Bühne, solange die Linien eingeschaltet sind, und verschwindet mit
    dem Schalter. Als ÜBERLAGERUNG und nicht als Zeile im Stapel: Eine Zeile
    nähme der Bühne Höhe, und `buehnenhoehe` geht in die Zoomrechnung ein.
    `allowsHitTesting(false)`, damit sie keine Geste schluckt (1.1.18).
  - **Die orange Warnfarbe in der Beschriftungszeile BLEIBT** („⚠ 2 Blöcke
    im Sicherheitsabstand"). Sie sagt „hier stimmt etwas nicht" und nicht
    „das ist diese Linie"; der Bezug steht im Wort. Die MARKE um den Block
    auf der Seite folgt dagegen der Linie und ist jetzt blau — sie hat kein
    Wort daneben.
- **Nicht gemessen (1.0.80):** Keine Seite ist damit gesehen worden. Die
  Farben und Strichbilder sind **gewählt und nicht gemessen** — ob Rot und
  Blau in diesen Tönen auf einem hellblauen Seitenhintergrund wie dem des
  Nutzers deutlich auseinandertreten, sagt erst der nächste Befund. Ebenso
  ungeprüft, ob die Kontur bei 0,28 Deckung auf einem Foto reicht und ob die
  Legende über der Bühne an der richtigen Stelle sitzt. **Und der Befund zum
  dunklen Hintergrund ist am Quelltext hergeleitet, nicht gesehen:** Dass
  die Linien dort verschwanden, folgt aus den festen Farben — angesehen hat
  es niemand. **Nichts davon als erledigt darstellen.**
- **GEZÄHLT WURDE ANWESENHEIT, GEMEINT IST SICHTBARKEIT**
  (`ReiseView.reiheInDerMitte`, ab 1.0.79; gemeldet 09/2026 mit
  Bildschirmfoto: „Das Datumsfeld hängt immer mindestens einen Tag
  hinterher. Im Blickfeld sind eigentlich schon die Seiten des 4. Augustes
  und auswählbar ist der 3. Das stört.").
  - **Am Quelltext abzuzählen:** `tagImBlick` nahm seit 1.0.28 die KLEINSTE
    anwesende Reihennummer. Ein Bogen, der nur noch mit einem Streifen oben
    am Bildschirmrand hängt, zählt damit genauso wie der, der den ganzen
    Schirm füllt — und gewinnt, weil seine Nummer kleiner ist. Auf dem
    Bildschirmfoto ist genau das zu sehen: oben der letzte Zentimeter von
    „Seiten 0 und 1", darunter vollflächig „Seiten 2 und 3", und im
    Datumsfeld der Tag des ersten.
  - **Dazu feuert `onAppear` in einem `LazyVStack` nicht am Sichtrand**,
    sondern am Rand des Vorbereitungsbereichs — SwiftUI baut ein Stück im
    Voraus. Die „oberste anwesende" Reihe ist also oft eine, die gar nicht
    zu sehen ist. **Merke: `onAppear` meldet Anwesenheit, nicht
    Sichtbarkeit; wer aus mehreren Meldungen EINE auswählt, braucht ein
    Maß dafür, welche gemeint ist.**
  - **Gewählt wird die Reihe, welche die MITTE des Sichtfelds überdeckt** —
    gerechnet aus derselben Geometrie, an der auch der Zoom hängt
    (`Zoomanker.griff`), und mit derselben Umrechnung wie `massstabSetzen`.
    Der AUSLÖSER bleibt `onAppear`/`onDisappear`: Gerechnet wird damit nur,
    wenn eine Reihe kommt oder geht, und nicht bei jedem Bildpunkt —
    `Inhaltslage` hat aus gutem Grund kein `@Published` (die Lehre aus
    1.0.16). Findet sich für die Mitte keine Meldung, gilt wie bisher die
    oberste: ein Rückfall und keine Behauptung.
  - **Die Seitenvorwahl hing an derselben Zeile** (`seitenvorwahl`, seit
    1.0.61) und ist mitgezogen. Wer eine Auswahl aus „was man sieht"
    ableitet, hat sie meist an mehr als einer Stelle.
- **WER EINEN SAMMELBILDSCHIRM NACH EINEM TEIL SEINES INHALTS BENENNT, MACHT
  DEN ANDEREN TEIL UNSICHTBAR** (`Views/KartenstilView.swift`, ab 1.0.79;
  Frage des Nutzers 09/2026: „Gibt es eigentlich irgendwo eine Möglichkeit,
  eine globale Einstellung für die Reisepunkte zu treffen? Im vorliegenden
  Fall möchte ich beispielsweise einstellen können, dass überall nur die
  Spur angezeigt wird und nicht die Punkte.").
  - **Es gab sie — und 1.0.77 hat sie versteckt.** Die buchweite
    `KartenbildWahl` lag in `GestaltungView`, und deren Menüpunkt hieß
    „Ränder, Karte, Seitenzahlen…". In 1.0.77 wurde er zu „Ränder und
    Druckzugaben…", weil er nach seinem Inhalt heißen sollte — dahinter
    liegen tatsächlich Anschnitt, Sicherheitsabstand und Bundsteg. Mit dem
    Wort „Karte" ist aber der einzige Hinweis darauf verschwunden, dass
    auch die Karteneinstellung dort wohnt. **Dreizehnte Auflage von „es war
    da, man fand es nicht" — und die erste, die aus einer Verbesserung
    entstanden ist.** Merke: Wer einen Menüpunkt umbenennt, zählt vorher
    auf, was alles dahinterliegt.
  - Die Karten bekommen deshalb einen EIGENEN Menüpunkt („Ganzes Buch →
    Karten…"), wie „Fotos…" (1.0.10) und „Textfelder…" (1.0.12) und aus
    demselben Grund: Es ist eine Wirkung, die für alle gilt, und sie wird
    dort gesucht, wo die Frage entsteht. Gezeigt wird dieselbe
    `KartenbildWahl`, die auch Tag und einzelne Karte benutzen — zwei
    Fassungen desselben Formulars liefen auseinander.
  - **In der Gestaltung bleibt eine AUSKUNFT mit dem Weg** (Reisepunkte und
    Kartenbreite als Zeile, dazu wo es eingestellt wird). Ein Bildschirm,
    der einen Wert nicht mehr führt, muss sagen, wo er jetzt steht —
    dieselbe Regel wie beim Seitenformat seit 1.0.27. Und der Knopf „Für
    alle Karten im Buch einstellen" im Inspektor zeigt seither dorthin; ein
    Weg, der auf einen Bildschirm zeigt, der die Sache nicht mehr führt,
    ist schlimmer als kein Weg (Lehre aus 1.0.49).
- **Nicht gemessen (1.0.79):** Nichts davon ist auf einem Gerät gesehen
  worden. **Am Quelltext ABGEZÄHLT ist die Ursache des hinterherhängenden
  Datums** (die kleinste anwesende Nummer gewinnt, und `onAppear` meldet
  früher als das Auge sieht) — und sie passt Punkt für Punkt zum
  Bildschirmfoto. **Ungeprüft ist die Abhilfe:** Ob `Inhaltslage.ursprung`
  im Augenblick des `onAppear` schon den neuen Stand trägt, ist die Lesart
  der Reihenfolge und keine Messung; hinkt sie um einen Durchgang, steht
  das Datum weiterhin eine Reihe daneben — dann ist der nächste Griff, die
  Rechnung an `onChange(of: lage.meldungen)` zu hängen. Ebenso ungesehen,
  ob der neue Menüpunkt gefunden wird: Geändert sind Wege und Namen, und
  das ist keine Messung (dieselbe Einschränkung wie bei den Menüs in
  1.0.20 und 1.0.49). **Nichts davon als erledigt darstellen.**
- **AM BUND WIRD NICHT GESCHNITTEN — und die Ansicht behauptete es doch**
  (`Bogenkante`, `Schnittlinien`, ab 1.0.78; gemeldet 09/2026: „In der
  Gestaltungsansicht sehe ich an der Falz innen immer noch zwei gestrichelte
  Linien. Eine für den Beschnitt und eine für den Sicherheitsabstand. Laut
  Druckerei wird aber doch dort kein Beschnitt ausgeführt. Und in den
  Seitenmaßen sieht man ja auch, dass drei Millimeter von einer Doppelseite
  ringsherum abgezogen werden, aber nicht innen.").
  - **Er hat recht, und die Stelle steht seit 1.0.58 im Papier — als
    „richtig so".** Dort hieß es: „Am Bund liegen ZWEI Anschnitte, und die
    stehen doppelt da … Das ist keine Panne der Ansicht." Für die
    EINZELSEITEN-Ausgabe stimmte das: Dort trägt jede Seite ringsum
    Anschnitt. Seit 1.0.69 gibt es die DOPPELSEITEN-Ausgabe, und die
    schreibt den Bogen so, wie er gedruckt wird — „der Anschnitt liegt
    ringsum AUSSEN, am Bund keiner"; seit 1.0.50 gilt dasselbe für den
    Umschlagbogen. **Damit war aus einer hingeschriebenen Ungenauigkeit eine
    Abweichung zwischen Ansicht und Datei geworden** — und die verbietet die
    erste Regel dieser App. **Merke: Eine Ungenauigkeit, die man
    hinschreibt, bleibt nur so lange vertretbar, wie keine zweite Stelle es
    besser macht. Wer eine Ausgabe hinzufügt, prüft, welche Erklärung sie
    widerlegt.**
  - **`Bogenkante` sagt, an welcher Kante die Nachbarhälfte anstößt** —
    `.links`, `.rechts`, `.keine`. Dort fällt der Anschnittstreifen weg und
    mit ihm die rote Schnittkante; die Endformate stoßen aneinander, genau
    wie in `doppelseitenPdf`. `.keine` ist die Einzelseitenansicht, und dort
    bleibt alles, wie es war: Die Einzelseiten-PDF trägt ringsum Anschnitt.
  - **Die ORANGE Linie bleibt am Bund, und das ist kein Versehen.** Dort
    wird nicht geschnitten, aber es verschwindet etwas im Falz — genau
    dafür gibt es seit 1.0.76 den eigenen Innenwert. Zwei Linien an einer
    Kante waren zu viel, eine ist die Auskunft.
  - **`Rectangle().strokeBorder` kann nur alle vier Kanten**, gebraucht
    werden drei. `Schnittlinien` ist deshalb ein `Shape`. **Wer eine neue
    Aufrufstelle anlegt, gibt ihr die Kante mit** — auch `Schutzzonenskizze`
    zeichnet seither dasselbe.
  - **Die Bühne wird schmaler, und das musste mitgezogen werden**
    (`ReiseView.breitesterBogen`, `massstaebe`). Bis 1.0.77 wurde die Breite
    eines Einzelbogens verdoppelt, also zwei Anschnitte zu viel. Das war
    folgenlos, solange die Ansicht sie auch zeichnete; jetzt stünde rechts
    ein leerer Streifen, und der Zoom rechnete auf einer falschen Zahl (die
    Lehre aus 1.0.22). Gerechnet wird an EINER Stelle
    (`Bogenlage.doppelbogen`).
  - **`HintergrundFlaeche` baute die Doppelseitenfläche NACH** (`bogen.width
    + format.width`). Das ging nur auf, solange der Bogen an beiden Seiten
    einen Anschnitt trug. Sie fragt jetzt `Bogenlage.bildflaeche`, also die
    Funktion, die auch das PDF bekommt. **Wer eine Rechnung nachbaut,
    bezahlt sie beim nächsten Mal, wenn sich ihre Voraussetzung ändert.**
    `Bogenlage.versatz` wird damit nirgends mehr gebraucht und ist
    ersatzlos entfernt — ein Feld, das niemand liest, ist ein halb gebautes
    Vorhaben.
- **EIN SCHALTER, DER NACH DER BESCHRIFTUNG HEISST, DARF NICHT DIE GEOMETRIE
  ÄNDERN** (`Umschlagmass.rueckenbreite`, ab 1.0.78; gemeldet 09/2026: „Auf
  der anderen Seite bekomme ich in das Format des Umschlages offenbar nicht
  die 2 mm Rückenbreite hineingesetzt. Ich kann sie zwar eingeben und
  bestätigen lassen … aber nach wie vor steht dort als Gesamtbreite 426 mm
  und nicht 428, wie es sein müsste.").
  - **Die Zahl IST der Befund, und sie ist nachzurechnen:** 426 =
    2 × 210 + 2 × 3. Der Rücken zählte also mit null — und die einzige
    Stelle im ganzen Quelltext, die null zurückgeben konnte, war
    `guard umschlag.rueckenZeigen else { return 0 }`. Gerechnet wäre die
    Breite bei einem Hardcover nie null (allein die Deckel tragen auf), eine
    Tabelle sagt entweder etwas oder gar nichts, und eine von Hand
    eingetragene Zahl schlägt seit 1.0.72 beides. **Wo eine Zahl um genau
    einen Summanden danebenliegt, wird nicht geraten, sondern der Summand
    gesucht.**
  - Der Schalter heißt „Rücken bedrucken" und nahm die ganze RÜCKENBREITE
    aus dem Bogenmaß. Wer keinen Titel auf dem Rücken wollte, bekam damit
    stillschweigend einen Umschlag ohne Rücken, und der Knopf „Rückenstärke
    übernehmen" nahm die Zahl an, ohne dass sie irgendwo ankam — ein Knopf,
    der schweigt. **Ein Buch hat einen Rücken, auch wenn nichts darauf
    steht.** Er heißt jetzt „Text auf dem Rücken" und steuert nur noch die
    Schrift; die Prüfung steht in `rueckenbeschriftung`, also an der einen
    Stelle, die Bildschirm UND PDF fragen. Wer wirklich keinen Rücken hat,
    trägt 0 mm ein (das geht ausdrücklich) oder gibt den Umschlag ohne Bogen
    aus. Dieselbe Trennung wie bei `Block.ohneGrund` und
    `sicherheitsabstandInnen`: zwei Fragen, zwei Felder.
  - **Einband, Papierstärke und die Tabellen lagen hinter demselben
    Schalter** und waren damit unerreichbar, sobald er aus war — obwohl sie
    allesamt die BREITE bestimmen. Sie stehen jetzt davor.
  - **Ein Knopf unter einem Zahlenfeld braucht immer zwei Tipps** („wobei
    auch diese Bestätigung etwas hakelig ist. Ich muss mehrmals drücken.").
    Das ist kein Gefühl, sondern iOS: Solange ein Textfeld den Fokus hat,
    beendet der erste Tipp daneben die Eingabe, erst der zweite erreicht den
    Knopf. `.onSubmit` hilft nicht — ein `.decimalPad` hat keine
    Eingabetaste. Übernommen wird deshalb beim Verlassen des Feldes
    (`@FocusState`), der Knopf bleibt für den daneben, der ihn sucht.
    **Gemerkt wird nur bei echter Änderung:** Der Rückgängig-Stapel ist
    flach (25 Stände), und ein zweimal angesehenes Feld darf ihn nicht
    leeren.
  - **Das Feld zeigt, WAS GILT.** Ohne Vorbelegung ließ sich beim Öffnen
    nicht unterscheiden, ob nichts eingetragen ist oder nur nichts dasteht.
    Und unter dem Bogenmaß steht seither „Davon Rücken" samt Herkunft —
    ohne diese Zeile war gar nicht zu sehen, ob eine eingetippte Zahl
    ankommt. Eine gerechnete Zahl als Angabe des Druckdienstes auszugeben
    wäre die Art Lüge, die diese App nicht erzählt.
- **Nicht gemessen (1.0.78):** Keine Seite ist damit gesehen und keine Datei
  ausgegeben worden. **Gerechnet und am Quelltext abgezählt sind BEIDE
  Ursachen** — dass die Doppelseitenansicht zwei Anschnitte und zwei
  Schnittkanten an den Bund legte (sie stand dort seit 1.0.17 und war seit
  1.0.69 im Widerspruch zur Ausgabe), und dass `rueckenZeigen` die einzige
  Stelle war, die die Rückenbreite auf null ziehen konnte (426 = 2 × 210 +
  2 × 3 geht auf den Millimeter auf). **Ungeprüft bleibt, ob der zweite
  Befund WIRKLICH daher kam:** Dass die Rechnung stimmt, heißt nicht, dass
  dieser Schalter in seinem Buch aus war — seit 1.0.78 nennt der Abschnitt
  deshalb Breite und Herkunft, und die nächste Rückmeldung sagt es mit
  Zahlen statt mit einer Vermutung. Ebenso ungesehen: ob die
  Doppelseitenansicht nach dem Wegfall der Bundanschnitte auf dem Gerät
  ruhig aussieht, ob der Zoom über die schmalere Bühne noch stimmt und ob
  die Übernahme beim Fokuswechsel wirklich einen Tipp spart. **Und ein
  vorhandenes Buch, in dem der Rücken abgeschaltet war, bekommt nach dem
  Update einen breiteren Umschlagbogen** — das ist die gewollte Richtung,
  aber es ist eine Änderung an einem fertigen Buch. **Nichts davon als
  erledigt darstellen.**
- **DER SATZSPIEGEL DARF BIS AN DEN SICHERHEITSABSTAND** (ab 1.0.82; gefragt
  09/2026: „Okay, den Satzspiegel hatte ich vergessen. Warum ist denn der so
  weit vom Rand entfernt? Der Satzspiegel könnte doch tatsächlich innerhalb
  des Sicherheitsabstandes ausgeführt werden."). **Er könnte, und er konnte
  nicht** — die drei Regler gingen nur bis 5 mm hinunter, der
  Sicherheitsabstand liegt bei 3. Die Untergrenze war eine gewählte Zahl ohne
  Grund; die technische Grenze ist der Sicherheitsabstand, und der steht seit
  1.0.80 als eigene blaue Linie daneben. Die Spanne ist jetzt `0...45`, dazu
  ein Knopf, der alle drei auf einmal darauf setzt (außen auf den größeren der
  beiden Werte, denn dort kann der Bund einen eigenen tragen).
  - **Die Vorgaben 16 / 17 / 19 sind GEWÄHLT und nicht gemessen** — übliche
    Buchränder, unten mehr als oben, weil der optische Mittelpunkt über dem
    geometrischen liegt. Das stand nirgends, und deshalb sah die Zahl aus wie
    eine Vorschrift. Der Fußtext des Abschnitts trennt jetzt beides: Der
    Sicherheitsabstand ist die technische Untergrenze, der Rand eine
    Entscheidung über das Aussehen.
  - **Wer eine Grenze freigibt, sucht alles, was sich bisher auf sie verlassen
    hat.** `Seitenbeiwerk` setzt Seitenzahl und Kopfzeile als ANTEIL der
    Ränder (0,6 bzw. 0,42). Solange die Ränder 16 bis 19 mm maßen, lag das von
    selbst weit genug innen; bei 3 mm Rand unten stünde die Seitenzahl 1,8 mm
    vom Papierrand und würde ANGESCHNITTEN. **Und es fiele niemandem auf:**
    Die rote Marke aus 1.0.81 greift dort nicht, denn Seitenzahl und Kopfzeile
    sind keine Blöcke — sie gehören dem Buch und werden beim Zeichnen ergänzt
    (Regel seit 1.0.0). Geklemmt wird deshalb in `Seitenbeiwerk` selbst, in die
    Schutzzone hinein und nicht über den Satzspiegel hinaus.
  - **Wird der Rand so knapp, dass zwischen Satzspiegel und Sicherheitslinie
    nichts mehr bleibt, SAGT es die Druckprüfung** (`beiwerkplatz`). Gemessen
    wird am ERGEBNIS: Überschneidet sich das gesetzte Rechteck mit dem
    Satzspiegel, steht die Zahl im Text. Angeschnitten wird sie nicht — aber
    sie liegt dann dort, wo der Fließtext anfängt, und das hat niemand
    eingestellt. Als Hinweis und nicht als Warnung: Es ist eine Folge der
    eigenen Einstellung und kein Druckfehler.
  - **Was der Rand sonst noch tut, steht dabei:** Beim Lesen liegt dort der
    Daumen, und am Bund verschwindet in der Bindung ohnehin ein Streifen —
    dafür gibt es seit 1.0.76 den eigenen Innenwert.
- **GEMESSEN WURDE DER RAHMEN, GESEHEN WIRD DER UMRISS** (`Block.umriss`,
  ab 1.0.83; gemeldet 09/2026: „Wenn ich jetzt ein Element in den
  Sicherheitsbereich hineinschiebe, erscheint noch kein roter Rand. Auch
  nicht, wenn ich ihn in den Beschnittbereich schiebe. Erst wenn er
  definitiv über den weißen Rand hinausragt, wird es rot. … Der Rahmen soll
  bereits rot erscheinen, wenn eine Ecke des Elementes in den
  Sicherheitsbereich hineinragt.").
  - **Die Prüfung stand seit 1.0.76 auf `block.rahmen.rect` — und der ist
    kleiner als das, was auf der Seite steht.** Zwei Gründe, beide am
    Quelltext abzuzählen und beide in die Richtung, um die es geht:
    **Der weiße Fotorand liegt AUSSERHALB des Rahmens** (`blockAnsicht`
    zeichnet ihn über `padding(randPt)`, dann `padding(-randPt)` — das
    Layoutmaß geht zurück, die Zeichnung bleibt groß); im Stil „Fotoalbum"
    sind das 2,6 mm ringsum. Und **die Drehung wurde gar nicht gerechnet**:
    In den lebhaften Stilen (Tagebuch, Fotoalbum, Postkarte) ist jede
    Kachel seit 1.0.36 um bis zu 2,1 Grad gedreht, und bei einem Block von
    300 Punkt Höhe steht seine ECKE gut 5 Punkt weiter draußen als seine
    Kante. Zusammen sind das mehrere Millimeter — genau der Betrag, um den
    die Marke zu spät kam. **Und die Ecke ist wörtlich das, wonach gefragt
    wurde.**
  - **Der SCHATTEN bleibt draußen.** Er liegt ebenfalls außerhalb des
    Rahmens, ist aber weich, hat keine Kante und ist kein Inhalt; ihn
    mitzumessen hieße, jeden Block mit Schatten zu markieren — und nach der
    dritten falschen Marke sieht niemand mehr hin. Dieselbe Abwägung wie
    bei den randabfallenden Blöcken, die ohne Ausnahme ausgenommen bleiben.
  - **Die Nachsicht von einem halben Punkt ist weg** (`Reise.randnachsicht`,
    ein Zehntelpunkt). Sie klingt nach nichts und ist an dieser Stelle zu
    viel: Gefangen wird beim Schieben mit `6 / massstab` Toleranz, und damit
    parkt ein Block regelmäßig GENAU auf einer Linie. Was dahinter noch als
    „nicht drin" galt, war ein Stück Sicherheitsabstand.
  - **Gemessen wird an EINER Stelle** (`Reise.ragtHinaus`), gefragt von der
    Schnittkanten- und der Sicherheitsprüfung, und damit von der Marke auf
    der Seite, der Zeile unter dem Blatt und der Druckprüfung. **Die Marke
    liegt seit 1.0.83 um denselben Umriss**, den sie prüft — eine Marke, die
    den weißen Fotorand ausließe, säße innerhalb dessen, was man sieht.
  - **Und weil sich das hier nicht nachmessen lässt, sagt es die App**
    (`SeitenflaecheView.randbefund`, in „Bedienung prüfen"): Für den
    gewählten Block stehen dort Rahmen, gerechneter Umriss, Drehung,
    Fotorand, Endformat, Schutzzone und das Urteil samt Grund —
    „randabfallend, wird nie markiert" ist eines davon. Dasselbe Muster wie
    Schulalarms Stufenprobe: **Wo sich eine Ursache nicht erschließen
    lässt, muss eine Probe entscheiden.**
- **DER ZEITRAUM UNTER DEM TITEL IST EINE RECHNUNG, KEINE WAHRHEIT**
  (`Reise.zeitraumtext`, `.zeitraumZeigen`, ab 1.0.97; Ansage des Nutzers
  09/2026: „Dadurch, dass ich ein Bild aus der Reisevorbereitung mit
  eingefügt habe, steht jetzt auf dem Titel 4. Juni. Das trifft aber nicht
  für die Reise zu.").
  - Er kam aus dem ersten und letzten Tag — die richtige VORGABE, denn sie
    stimmt von selbst und zieht mit. Nur ist sie keine Wahrheit: Ein Foto
    von der Reisevorbereitung legt einen Tag an, und die Titelseite
    behauptet ein Datum, an dem niemand unterwegs war.
  - **`nil` heißt „gerechnet"** — Abweichung, keine Kopie, wie bei
    `regalname` seit 1.0.84. Der gerechnete Zeitraum steht als PLATZHALTER
    im Feld; leer holt ihn zurück.
  - **„Nichts gesetzt" und „ausdrücklich keiner" sind ZWEI Aussagen** und
    brauchen zwei Felder (die Lehre aus `Block.ohneGrund`): ohne den
    Schalter käme niemand zu „gar kein Zeitraum".
  - **Aufgelöst an EINER Stelle** (`Reise.zeitraum`), gefragt von
    Titelseite, Regal und den Angaben im PDF.
  - **Nebenbefund: Ausgeblendete Tage zählten mit.** Was nicht ins Buch
    kommt, darf nicht auf seinem Titel stehen; `gerechneterZeitraum` filtert
    sie seit 1.0.97 heraus. **Wer eine Zahl aus `tage` rechnet, prüft, ob
    `ausgeblendet` dazugehört.**
- **WO EINE ZAHL EINGETRAGEN WIRD, GEHÖRT IN DIE MELDUNG ÜBER SIE**
  (`Druckpruefung.bestellung`, ab 1.0.97; gemeldet 09/2026: „Ich weiß nicht
  mehr, an welcher Stelle ich überhaupt eine Seitenzahl eingegeben habe.").
  Den Fall „noch nichts eingetragen" erklärte die Zeile seit 1.0.72 —
  ausgerechnet der Fall, in dem man die Zahl ÄNDERN will, nannte den Weg
  nicht. Sechzehnte Auflage von „es war da, man fand es nicht", diesmal an
  einer Meldung statt an einem Menü.
- **EIN MODUS BRAUCHT EINEN SICHTBAREN AUSGANG — auch dieser** (Befundband in
  `ReiseView.baender`, ab 1.0.96; gemeldet 09/2026: „Es gibt die Option, die
  Fehler im Buch anzeigen zu lassen. Ich möchte aber auch genauso die Funktion
  haben, die Umrandungen wieder unsichtbar zu machen.").
  - **Die Regel steht seit 1.0.9 im Papier** („Wer einen Modus baut, baut den
    Ausgang mit — und zwar sichtbar") und galt für die Befundmarken aus 1.0.93
    nicht: Eingeschaltet wurden sie mit einem Knopf UNTER dem Befund,
    ausgeschaltet nur mit einem Schalter drei Ebenen weit weg im
    Drei-Punkte-Menü. **Eine Regel, die für den nächsten Modus nicht gezogen
    wird, ist keine Regel, sondern eine Notiz.**
  - **Ein `Label` in einer Werkzeugleiste verliert seinen TEXT, sobald es eng
    wird.** Auf der Bühne stand deshalb ein rotes Warndreieck ohne ein Wort —
    es sagte weder die Zahl der Befunde noch, dass ein Tipp weiterspringt.
    **Wer eine Auskunft in eine Werkzeugleiste legt, prüft, ob sie dort
    ankommt**; das Band über der Seite hat Platz für Worte.
  - **Und der Weg zur LÖSUNG gehört dazu.** „Rahmen an Text anpassen" gab es
    für EINEN Kasten, den man vorher antippen muss — bei einundzwanzig ist das
    einundzwanzigmal derselbe Weg. `Reisewerk.alleRahmenAnpassen` nimmt sie
    zusammen, merkt EINMAL und frischt EINMAL am Ende auf (`befundeAuffrischen`
    geht über jeden Block des Buches). Der Knopf nennt die Zahl, die er
    anfasst.
  - **DIE NÖTIGE HÖHE WIRD MIT DERSELBEN MESSUNG GESUCHT, DIE AUCH PRÜFT**
    (`Textpassung.noetigeHoehe`). Bis 1.0.95 kam sie aus `Textmass.hoehe`
    (`SuggestFrameSize` samt Zuschlag), geprüft wird seit 1.0.94 mit
    `Textmass.passtBis` (echter `CTFrame`). Wo die beiden auseinandergehen,
    blieb `max(gemessen, jetzt + 1)` übrig: Der Knopf machte den Kasten einen
    Punkt höher, und die Prüfung meldete ihn weiter — **ein Knopf, der einen
    Befund nicht auflösen kann, ist schlimmer als keiner.** Dieselbe Lehre wie
    überall in diesem Papier, nur diesmal zwischen PRÜFUNG und ABHILFE.
- **Nicht gemessen (1.0.96):** Keine Seite ist damit gesehen worden. Am
  Quelltext abgezählt ist beides — dass ein `Label` dort seinen Text verliert
  und dass die beiden Messungen auseinandergehen können. **Ob die
  einundzwanzig gemeldeten Kästen schon mit 1.0.94 verschwinden, ist nicht
  nachgesehen**: Die 0,3 mm sind auf den Punkt der Zuschlag von einem Punkt,
  was dafür spricht — die Bildschirmfotos zeigten aber eine ältere Fassung
  (1.0.93, am Wortlaut der Prüfzeile erkennbar), und sicher ist es erst nach
  dem nächsten Lauf. **Nicht als erledigt darstellen.**
- **EINE VORLAGE TRÄGT EINSTELLUNGEN UND NIE INHALT** (`Model/Vorlage.swift`,
  `Dienste/Vorlagenablage.swift`, `Views/VorlagenView.swift`, ab 1.0.95;
  Ansage des Nutzers 09/2026: „gewisse Einstellungen, die ich für ein Fotobuch
  getroffen habe, abzuspeichern, möglichst auch in der Cloud. Und gerne auch
  als Konfigurationsdatei, die man exportieren kann. … Genauso möchte ich die
  Einstellungen, die ich jetzt für eine bestimmte Druckerei getroffen habe,
  abspeichern können.").
  - **ZWEI ARTEN, und die Einteilung ist seine.** Er nennt zwei Dinge, und
    sie ändern sich unabhängig: dasselbe Aussehen an zwei Druckereien,
    dieselbe Druckerei für zwei Bücher. Eine Vorlage, die beides trägt,
    zwänge bei jedem Wechsel dazu, das andere mitzunehmen — und dann nimmt
    man sie nicht mehr. **Die Grenze ist nicht Maß gegen Farbe, sondern
    MEINE Entscheidung gegen DEREN Vorgabe:** Die Ränder stehen deshalb beim
    Aussehen (die wählt man), der Bundsteg bei der Druckerei (der hängt an
    der Bindung).
  - **Was eine Vorlage überschreibt, steht an EINER Stelle**
    (`Vorlagenwerte.anwenden`) und wird Feld für Feld gesetzt, nie als
    ganzer Typ: Eine Aussehensvorlage, die `gestaltung` in einem Zug
    ersetzte, nähme den Anschnitt der fremden Druckerei mit — und das fiele
    erst auf, wenn die Datei abgewiesen wird. Die Aufzählung im
    Anwenden-Blatt ist dieselbe Liste in Worten; **wer die eine ändert,
    ändert die andere mit.**
  - **Getragen werden die VOLLEN Typen** (`Gestaltung`, `Typografie`,
    `Umschlag`), weil die ihren nachsichtigen Leser schon haben und ein Feld,
    das morgen dazukommt, damit von selbst mitreist. Angewandt wird trotzdem
    nur, was in der Liste steht.
  - **Bilder reisen nicht.** Ein Hintergrundfoto und die Wasserzeichenbilder
    liegen als Dateien im Bildarchiv DIESER Reise; eine Vorlagendatei mit
    Bilddaten wäre keine Konfigurationsdatei mehr, sondern eine halbe
    Buchdatei. Die EINSTELLUNGEN reisen (Deckkraft, Größe, Drehspanne,
    Schleier), die Bilder bleiben die des Zielbuchs — und das steht vor dem
    Anwenden da (`Vorlagenwerte.bildhinweise`). Geleert wird beim SICHERN
    (`init(aus:)`), nicht beim Anwenden: Was nicht in der Datei steht, kann
    auch nicht weitergegeben werden.
  - **In der Wolke ohne zweite Abgleichsmaschine: je eine DATEI im Ordner
    `Vorlagen` neben `Reisen`.** Damit gilt automatisch, was für die Bücher
    gilt — Abgleich an heißt iCloud, aus heißt Gerät —, und beim Umschalten
    ziehen sie mit (`Wolke.nebenordnerKopieren`). **Eine Liste unter einem
    Schlüssel in den Voreinstellungen wäre hier falsch** (anders als bei
    `Formatvorlagen` seit 1.0.52, die nicht reisen): Zwei Geräte
    überschrieben einander die ganze Liste, statt je eine Datei zu ergänzen.
  - **Eine eingelesene Vorlage bekommt eine NEUE Kennung.** Der Dateiname ist
    die Kennung; sonst überschriebe eine weitergegebene Vorlage auf dem
    Zielgerät die gleichnamige. Wer dieselbe zweimal einliest, hat zwei —
    nicht eine halb ersetzte.
  - **Das FORMAT ist der heikle Teil einer Druckvorlage.** Es einfach zu
    setzen ließe jeden Block auf einer anders großen Seite an seiner alten
    Stelle stehen. Gefragt wird deshalb wie beim Formatwechsel seit 1.0.27
    (mitrechnen / nur das Format / lassen) — und nur dann, wenn das Maß
    wirklich ein anderes ist. **Ein NEUES Buch braucht die Frage nicht**
    (`Regal.anlegen`): Es hat noch keinen Block, den eine Umrechnung treffen
    könnte.
  - **Vorbelegt, aber sichtbar.** Eine Vorlage lässt sich als Vorschlag für
    neue Bücher markieren; beim Anlegen steht sie dann im Wähler und ist
    wegzunehmen. Eine App, die ein neues Buch still nach einer Vorlage
    anlegt, sieht aus wie eine App mit seltsamen Vorgaben (dieselbe
    Überlegung wie beim Deutschland-Ticket-Filter der Abfahrtstafel). Die
    Vorgabe steht in den VOREINSTELLUNGEN und nicht in der Wolke: „Was
    schlägt dieses Gerät vor" ist eine Gewohnheit dieses Geräts.
  - **Der Anlege-Alert ist ein BLATT geworden.** Ein Alert kann keine Auswahl
    tragen, und zwei Wege nebeneinander (Alert ohne Vorlagen, Blatt mit)
    wären zwei Fassungen derselben Sache.
- **Nicht gemessen (1.0.95):** Keine Vorlage ist auf einem Gerät angewandt
  worden. Am Quelltext abgezählt ist die Feldzuordnung und dass ein neues
  Buch keinen Formatwechsel braucht. **Ungeprüft ist der Abgleich** — dass
  ein Ordner neben den Büchern in iCloud mitzieht, folgt daraus, dass beide
  im selben Behälter liegen, gesehen hat es niemand. Und ob die Trennung in
  „Aussehen" und „Druckerei" an einem wirklichen zweiten Urlaub aufgeht,
  sagt erst der nächste Befund. **Nicht als erledigt darstellen.**
- **EINE SETZHÖHE IST KEINE PRÜFSCHWELLE** (`Model/Textpassung.swift`, ab
  1.0.94; gemeldet 09/2026 mit zwei Bildschirmfotos: „Ich weiß nicht, wo da
  bei der Bildunterschrift Platz fehlt und wie man es beheben kann.").
  - Die Druckprüfung nannte 28 zu kleine Textkästen, darunter
    „Bildunterschrift, es fehlen 0,3 mm" — und die Zeile stand daneben
    vollständig auf der Seite. **Die Ursache steht in `Textmass.hoehe`:**
    `ceil(…) + 1`, „ein Punkt Zuschlag, damit eine abgeschnittene letzte
    Zeile nicht wie ein Fehler im Buch aussieht". Beim SETZEN richtig, als
    PRÜFSCHWELLE falsch — verglichen wurde diese großzügige Zahl mit der
    Rahmenhöhe, und jede Rundung dazwischen (etwa die aus `Formatwechsel`,
    der Rahmen und Schriftgrößen je für sich auf ein Zehntel rundet) ergab
    einen Fehlbetrag von Bruchteilen eines Millimeters. **Ein Befund, den
    man auf der Seite nicht sehen kann, ist kein Befund, sondern Lärm — und
    er verdeckt die echten.**
  - **Gemessen wird am ERGEBNIS.** `Seitensatz.zeichneText` legt einen
    `CTFrame` über das Blockrechteck; was darin keinen Platz hat, wird nicht
    gezeichnet, und genau das zählt `Textmass.passtBis` (dieselbe Maschine,
    dieselbe Silbentrennung, dieselbe Breite). Bleibt nach dem Trimmen
    nichts übrig, ist nichts zu melden.
  - **Im Befund steht, WAS herausfällt** (`Textpassung.anriss`). Eine
    Millimeterzahl sagt nur, DASS etwas fehlt; die ersten Wörter des
    Überhangs sagen, wo man hinsehen muss.
  - **Der Zuschlag bleibt, wo er hingehört:** `Textpassung.noetigeHoehe`
    nimmt ihn für „Rahmen an Text anpassen" — dort SOLL der Rahmen
    großzügig sein. Gewachsen wird nur, nie geschrumpft.
  - **Und es ist EINE Stelle.** Bis 1.0.93 stand dieselbe Rechnung zweimal
    da (`Reisewerk.fehlendeHoehe` für die orange Marke,
    `Befundstellen.fehlendeHoehe` für die Prüfung) — mit dem Kommentar „zwei
    Fassungen ergaben eine Seite, auf der die Marke schweigt und die Prüfung
    anschlägt". **Ein Kommentar, der eine Doppelung benennt, hebt sie nicht
    auf.**
  - **Nicht gemessen (1.0.94):** Keine Seite ist damit gesehen worden. Wie
    viele der 28 gemeldeten Kästen danach übrig bleiben, sagt erst der
    nächste Lauf. **Nicht als erledigt darstellen.**
- **EINE PRÜFUNG, DIE EINE STELLE NENNT, ABER NICHT ZEIGT, VERSCHIEBT DIE
  ARBEIT NUR** (`Model/Befundstelle.swift`, `Reisewerk.befundstellen`,
  `.zeigeBefunde`, ab 1.0.93; Ansage des Nutzers 09/2026: „Ich möchte, dass
  nach der Dokumentprüfung alle Stellen im Dokument, an denen etwas
  auszusetzen war, rot umrandet erscheinen. Ich habe jetzt beispielsweise
  recht viel Zeit dafür verwendet, an den angegebenen Tagen die Textfelder zu
  suchen, die angeblich zu klein sind.").
  - Die Druckprüfung nannte Tag und Blockart im FLIESSTEXT („6. August 2026:
    Tagebuchtext, es fehlen 4,2 mm") — und danach saß man vor einem Tag mit
    vier Seiten und suchte. Unter jedem Befund mit Ortsbezug steht jetzt „Im
    Buch zeigen": Das Blatt macht sich zu, die Kästen werden rot umrandet,
    die Ansicht springt zum ersten, und unten steht „Befund 3 von 12" mit
    einem Knopf zum nächsten (am Ende wieder von vorn — ein Knopf, der
    plötzlich nichts mehr tut, sieht kaputt aus).
  - **Gerechnet wird an EINER Stelle** (`Befundstellen.alle`). Die drei
    Prüfungen mit Blockbezug (`abgeschnittenerText`, `doppelterText`,
    `leereUnterschriften`) standen bis 1.0.92 als eigene Schleifen in
    `Druckpruefung` und bauen ihre Zeilen seither aus dieser Liste — sonst
    stünde in der Prüfung ein Kasten, um den auf der Seite keine Marke liegt.
    `vorab` sammelt EINMAL und reicht die Liste durch: Der Lauf misst jeden
    Textblock mit CoreText, dreimal gerufen wäre er dreimal bezahlt.
  - **Dieselbe rote Marke wie am Rand** (seit 1.0.81) — es ist dieselbe
    Aussage, und zwei Rottöne nebeneinander wären eine Unterscheidung, die
    niemand lesen kann. Sie liegt um den gezeichneten UMRISS, nicht um den
    Rahmen (die Lehre seit 1.0.83).
  - **Die Liste ist GESPEICHERT, nicht gerechnet** — dieselbe Falle wie bei
    `textUeberlauf` seit 1.0.8. Gesammelt wird auf einen Anlass, und nur
    solange `zeigeBefunde` an ist; ist der Schalter aus, kostet das Ganze
    nichts. Zugewiesen wird nur bei echter Änderung, und **`Befundstelle.id`
    ist deshalb ABGELEITET und nicht gewürfelt**: Ein frisches `UUID()` je
    Sammeln machte zwei gleiche Listen ungleich, und die Bühne zeichnete bei
    jedem Lauf neu.
  - **Was behoben ist, verliert seine Marke von selbst.**
    `hoeheAnTextAnpassen`, `textSchreiben`, `textTeilen`,
    `leereUnterschriftenAbschalten` und `alleNeuAnordnen` frischen auf; das
    Ziehen an einer Ecke über `onChange(of: werk.textUeberlauf)` — die
    Messung läuft dort seit 1.0.8 ohnehin. **Wer einen neuen Griff baut, der
    einen Block ändern kann, ruft `befundeAuffrischen()`.**
  - **Was am RAND steht, ist NICHT in der Liste.** Das hat seit 1.0.81 seine
    eigene Marke aus `Reise.amRandGefaehrdet`, die die Lage selbst misst —
    mit der Bundseite DIESER Seite. Zweimal aufgenommen wären es zwei Marken
    übereinander und zwei Rechnungen dafür.
  - **Nicht gemessen (1.0.93):** Keine Seite ist damit gesehen worden. Am
    Quelltext abgezählt ist, was je Anlass gerechnet wird; ob das Blättern
    sich schnell anfühlt, sagt erst der nächste Befund. Die eigenen Felder
    auf Titel- und Rückseite werden gezählt, aber nicht angesprungen — sie
    stehen in keinem Tag. **Nicht als erledigt darstellen.**
- **DIE BILDUNTERSCHRIFT HÄLT ABSTAND — und schon gesetzte Zeilen werden
  NACHGEZOGEN** (`Gestaltung.unterschriftabstand`, `.unterschriftfugePt`,
  `Reisewerk.zeilenAnsBildLegen`, ab 1.0.92; gemeldet 09/2026 mit
  Bildschirmfoto: „Die Bildunterschrift soll nicht halb noch im weißen
  Rahmen des Bildes stehen, sondern Abstand zu ihm halten.").
  - **Zwei Ursachen, beide am Quelltext abzuzählen.** Erstens war der
    Abstand feste drei Punkte hinter dem weißen Rand, also gut ein
    Millimeter — er ist jetzt einstellbar (Vorgabe 2 mm, **gewählt und nicht
    gemessen**) und wird ab der Unterkante des SICHTBAREN Bildes gemessen.
    Zweitens, und das ist die Stelle, an der es auf einer fertigen Seite
    hängt: `zeilenAnsBildLegen` trug seit 1.0.90 ein `guard` auf die
    Drehung und richtete AUSSCHLIESSLICH die Neigung aus. Bei einem gerade
    stehenden Bild lief die Schleife leer durch, und eine Seite aus einem
    Stand vor 1.0.86 behielt ihre Zeile drei Punkte unter dem RAHMEN, also
    mitten im weißen Rand.
  - **Zweite Auflage derselben Lehre wie 1.0.90:** Wer eine Regel an den
    Entstehungsstellen einbaut, erreicht keinen Block, der schon dasteht.
    Damals wurde sie für die Neigung gezogen und für den Abstand nicht —
    im Quelltext stand sogar wörtlich „Der Abstand bleibt, wie er ist".
    **Merke: Wer eine solche Nachrichtung baut, zählt auf, WAS sie alles
    ausrichten muss, und nicht nur, was gerade gemeldet wurde.**
  - **Gerechnet wird an EINER Stelle** (`Gestaltung.unterschriftfugePt`),
    gefragt vom Layoutautomaten, der die Zeile SETZT, und von
    `zeilenAnsBildLegen`, das sie ausrichtet. Zwei Fassungen ergäben eine
    Seite, die nach dem Öffnen anders aussieht als nach dem Neuanordnen.
  - **Der weiße Rand geht mit ein, weil er AUSSERHALB des Rahmens liegt**
    (die Lehre steht seit 1.0.83 an `Block.umriss`) — und zwar der des
    BLOCKS (`wirkung.fotorand`), nicht der des Buches: Ein einzelnes Foto
    darf abweichen. **Eine KARTE hat keinen**; ihn dort mitzurechnen war ein
    alter blinder Fleck, der die Karte um genau diesen Betrag kürzte.
  - **Die Regler ziehen nach** (weißer Rand und Abstand im Fotos-Blatt, der
    Fotorand im Block-Inspektor, „Abweichungen aufheben"). Ohne das bliebe
    jede schon gesetzte Zeile stehen — für den Menschen davor ein Regler,
    der nichts tut. Gerechnet wird in `onEditingChanged`, also beim
    Loslassen: Der Lauf geht über jede Seite des Buches und schreibt in
    `reise`, und bei jedem Bildpunkt wäre das ein Sicherungslauf je
    Bildpunkt.
  - **Geschrieben wird nur bei echter Änderung.** `reise` sichert über sein
    `didSet`; ein Sicherungslauf bei jedem Öffnen wäre beim Abgleich ein
    Buch, das sich ohne Zutun als neuer ausgibt. Verglichen wird auf einen
    halben Punkt.
  - **Was `vonHand` trägt, bleibt liegen** — wer eine Zeile selbst gesetzt,
    gedreht oder mit ihrem Bild verschoben hat, behält sie.
  - **Nicht gemessen (1.0.92):** Keine Seite ist damit gesehen worden.
    **Welche der beiden Ursachen auf der gemeldeten Seite zutraf, ließ sich
    von hier aus nicht entscheiden** — beide sind behoben, und welche es
    war, sagt erst der nächste Befund. **Nicht als erledigt darstellen.**
- **DER UMSCHLAG HAT SEIN EIGENES MASS** (`Umschlag.format`, `.anschnitt`,
  aufgelöst in `Umschlagmass.seitenformat`/`.anschnitt`, ab 1.0.91; Ansage des
  Nutzers 09/2026 mit der Cover-Seite seines Druckdienstes daneben: „Für das
  Cover muss es noch weitere Einstellmöglichkeiten geben. Die Vorgaben der
  Druckerei kann ich sonst nicht einhalten.").
  - **Die Zahlen sind der Befund, und sie gehen auf:** Verlangt waren Brutto
    457 × 295 mm, Beschnittzugabe 10 mm ringsum, Buchrücken 17 mm — also
    437 × 275 netto und (437 − 17) / 2 = **210 × 275 je Hälfte**. Die App gab
    418 × 276 aus: 2 × 205 + 2 + 2 × 3 und 270 + 2 × 3. Sie benutzte also
    Format UND Anschnitt des BUCHBLOCKS, denn der Umschlag hatte bis 1.0.90
    kein eigenes Maß. **Bei einem gebundenen Buch stimmt das nie** — der Bezug
    ist größer als der Block, und wie viel größer, entscheidet die Bindung.
  - **Abgeleitet wird NICHTS.** Aus 210 × 275 gegen 205 × 270 ließe sich ein
    „Überstand von 5 mm" lesen; über die Höhe gerechnet wären es 2,5 mm je
    Kante, über die Breite 5 — die beiden gehen nicht auf. Eingetragen wird,
    was in der Bestellung steht (`Druckvorgabe.umschlaghaelfte` rechnet vom
    Bruttomaß zurück, wie `endformat` seit 1.0.72 für die Innenseiten).
  - **`nil` heißt „wie das Buch" — Abweichung, keine Kopie.** Dieselbe Regel
    wie bei `rand`, `hintergrund` und `titellage`; jedes vorhandene Buch gibt
    nach dem Update dieselbe Datei aus wie vorher.
  - **Aufgelöst an EINER Stelle**, gefragt von der Bühne
    (`Reise.flaeche(_:)`, `.anschnittPt(_:)`, `.satzspiegel(_:)`), vom PDF
    (`umschlagPdf`, `zeichneSeite`), vom Layoutautomaten (`umschlagbogen`),
    vom Ausgabesteckbrief und von der Druckprüfung. Der Satzspiegel der Bühne
    zeigte auf dem Umschlag bis 1.0.90 den des BUCHES, während der Automat
    `umschlagsatz` setzte — dieselbe Doppelung, nur älter.
  - **Es gilt für JEDE Seite des Umschlagbogens, auch U2 und U3**: Zwei
    Hälften und der Rücken müssen zusammen den Bogen ergeben. Tragen die
    Innenseiten Inhalt, sind das Seiten, die für den Buchblock gesetzt
    wurden — die Druckprüfung sagt das, statt es zu verschweigen.
  - **Beim Formatwechsel wird das MASS mitgerechnet, die ZUGABE nicht**: Das
    Spiel der Schneidemaschine ist dasselbe, ob eine Seite A4 misst oder A5
    (die Regel steht seit 1.0.27 im Papier). Die Rückenstärke bleibt aus
    demselben Grund stehen — sie hängt am Papier.
  - **Die Eingabe steht in einem EIGENEN Abschnitt.** Ein `Section`-Körper
    nimmt höchstens zehn Kinder an; mit vier Auskunftszeilen, vier Feldern
    und bis zu fünf Knöpfen wäre die Grenze überschritten. Oben steht, was
    GILT, darunter, was man EINTRÄGT — samt der Herkunft je Zahl.
  - **Nicht gemessen (1.0.91):** Keine Datei ist damit hochgeladen worden.
    Gerechnet und an der Vorgabe nachgerechnet ist die Umrechnung; ungeprüft
    bleibt, ob dieser Dienst die Datei annimmt, wie der größere Umschlagbogen
    auf dem Bildschirm neben den Buchseiten aussieht und ob ein Titelfoto auf
    der breiteren Hälfte noch steht, wo es stehen soll. **Nicht als erledigt
    darstellen.**
- **EINE REGEL AN DEN ENTSTEHUNGSSTELLEN ERREICHT KEINEN BLOCK, DER SCHON
  DASTEHT** (`Reisewerk.zeilenAnsBildLegen`, ab 1.0.90; Ansage des Nutzers
  09/2026 an einer Zeile, die waagerecht unter einem schief stehenden Bild
  hing: „Ich hätte es gerne so, dass die Schrift sich automatisch mit dem
  Bild mitdreht und am unteren Rand zu sehen ist.").
  - **Gebaut war das seit 1.0.86** — an den drei Stellen, die eine Zeile
    ANLEGEN, und beim Drehen von Hand. Zwei Lücken blieben, und beide
    zeigen dasselbe: **eine Seite, die vor 1.0.86 gesetzt wurde** (sie wird
    nie wieder durch den Automaten geschickt, und die Blöcke liegen fertig
    auf der Platte), und **der Aufmacher in `bildZuerst`**, der `angelegt`
    als einzige der drei Stellen nicht fragte. Der fiel nicht auf, weil der
    Automat dort selbst nichts dreht — von Hand gedreht wird das Bild
    trotzdem.
  - **Angelegt wird deshalb beim ÖFFNEN**, in `fehlendeSeitenNachholen`,
    und nur, was NICHT `vonHand` trägt. Das ist der Schutz, den dieses Haus
    ohnehin kennt: Wer eine Zeile selbst gesetzt, gedreht oder mit ihrem
    Bild verschoben hat, hat sie damit zu Handarbeit gemacht (beides setzt
    `vonHand` seit 1.0.86) — und Handarbeit wird nicht gerichtet.
  - **Gerichtet wird die NEIGUNG, nicht der Abstand.** Die Zeile wird um
    die Bildmitte zurückgedreht und neu gedreht; wie weit sie unter dem
    Bild steht, hat entweder der Automat gerechnet oder jemand gesetzt.
  - **Geschrieben wird nur, wo sich etwas ändert.** `reise` sichert über
    sein `didSet`; ohne Zuweisung gibt es keine Sicherung. Ein
    Sicherungslauf bei jedem Öffnen wäre beim Abgleich ein Buch, das sich
    ohne Zutun als neuer ausgibt.
- **Nicht gemessen (1.0.90):** Keine Seite ist damit gesehen worden. **Und
  es ist NICHT bewiesen, dass es der gemeldete Fall war:** Ob die Zeile auf
  seiner Seite aus einem alten Stand stammt oder aus `bildZuerst`, lässt
  sich von hier aus nicht entscheiden — beide Lücken sind geschlossen, und
  welche davon zugetroffen hat, sagt erst der nächste Befund. **Nicht als
  erledigt darstellen.**
- **ALLES, WAS IN DIE DATEI GEHT, IST sRGB** (`Dienste/Farbraum.swift`, ab
  1.0.89; gefragt 09/2026: „ist der Farbraum eigentlich sRGB?", danach die
  Ansage: „Ich möchte die automatische Umwandlung in der App.").
  - **Die ehrliche Antwort war: nicht durchgehend, und drei Wege liefen
    nebeneinander.** Die Farben der App kamen über
    `UIColor(red:green:blue:alpha:)` und die Verläufe über
    `CGColorSpaceCreateDeviceRGB()` — beides landet im PDF als
    `/DeviceRGB`, also OHNE Profil; jeder Betrachter liest es faktisch als
    sRGB, dagestanden hat es nie. Die FOTOS behielten das Profil ihrer
    Datei, und ein iPhone-Foto ist seit Jahren häufig **Display P3** — im
    selben Buch standen damit P3-Bilder neben profillosen Textfarben. Und
    die KARTEN entstanden im Vorgabebereich des Geräts.
  - **Gewandelt wird an EINER Stelle** (`Farbraum`), gefragt von den
    Farben (`Farbwert.cgFarbe`), den Verläufen, den Ausgabebildern
    (`Bildarchiv.fuerAusgabe`), der Sättigung (`Farbkraft`) und den
    Kartenzeichnern (`preferredRange = .standard`). Wer einen neuen Weg in
    die Datei baut, fragt dort.
  - **Nur, was nicht schon sRGB IST.** Ein Bild ohne Not durch einen
    Bitmap-Kontext zu schicken kostet Speicher (3600 Punkte Kante sind rund
    39 MB) und Genauigkeit — und der häufigste Fall ist das Bild, das schon
    passt.
  - **Durchsichtigkeit bleibt durchsichtig.** Eine freigestellte Grafik
    bekäme sonst einen weißen Kasten — und `Seitensatz.jpegEingebettet`
    entscheidet an genau diesem Kanal, ob es komprimieren darf.
  - **Misslingt die Umwandlung, kommt das Bild unverändert zurück.** Ein
    Bild ohne Umwandlung ist besser als kein Bild; das ist der Stand von
    vor 1.0.89 und nicht schlechter als vorher.
  - **Die Prüfung zählt, was anfällt** (`Druckpruefung.farbraum`): wie viele
    Bilddateien welches Profil tragen und wie viele umgerechnet werden —
    gemessen an den ORIGINALEN auf der Platte, gedeckelt auf vierzig, und
    mit dem Satz dabei, dass erst ein Blick in die fertige Datei sagt, was
    wirklich darin steht.
- **Nicht gemessen (1.0.89):** In keine ausgegebene Datei ist hineingesehen
  worden. **Am Quelltext ABGEZÄHLT ist, welcher Weg welchen Raum benutzt
  hat** — `/DeviceRGB` bei Farben und Verläufen, das Dateiprofil bei
  Fotos. **Ungeprüft bleibt das Ergebnis:** ob CoreGraphics den benannten
  Raum wirklich als ICC-Profil in das PDF schreibt, ob `jpegData` das
  Profil eines sRGB-Bildes mitschreibt und ob ein Druckdienst die Datei
  danach anders behandelt. Ebenso ungemessen, was die Umwandlung an
  Zeit kostet — sie läuft je Bild beim Ausgeben. **Nicht als erledigt
  darstellen.**
- **DIE AUSRICHTUNG EINER UNTERSCHRIFT GEHÖRT DEM BILD** (`Foto.unterschriftAusrichtung`,
  `Reisetag.kartentextAusrichtung`, ab 1.0.88; gemeldet 09/2026 an einer
  Zeile, die halb unter dem Nachbarfoto verschwand: „Hier verschwindet der
  Text leider unter dem anderen Bild. Ich möchte bei jedem Bild die
  Möglichkeit haben, die Standardausrichtung zu durchbrechen und einmalig
  einstellen können, ob links, rechts oder zentriert ausgerichtet wird.").
  - **Die Einstellung gab es — am falschen Ort.** `Schriftabweichung.ausrichtung`
    steht seit 1.0.0 am BLOCK, und der Inspektor bietet sie unter „Schrift an
    dieser Stelle" an. Zwei Dinge machen sie dort wertlos: Der Block wird beim
    Neuanordnen neu gebaut, die Einstellung wäre still weg — und um ihn
    auszuwählen, müsste man die Zeile antippen, die genau in dem gemeldeten
    Fall UNTER einem Bild liegt. **Ein Weg, der durch das Problem führt, das
    er lösen soll, ist keiner.**
  - **Sie steht deshalb am FOTO und am TAG**, wie der Text selbst, und `nil`
    heißt „wie im Buch" — Abweichung, keine Kopie. Aufgelöst wird sie an EINER
    Stelle (`Seitensatz.schriftbild`) in drei Stufen: Rolle im Buch, Ausnahme
    am Foto bzw. Tag, Abweichung am Block. Die letzte ist die unmittelbarste
    Handarbeit und gewinnt.
  - **Der Picker im Schrift-Abschnitt schreibt bei einer Unterschrift
    woanders hin** — an die dauerhafte Stelle. Zwei Wege zu derselben Sache,
    von denen einer das Neuanordnen nicht übersteht, laufen garantiert
    auseinander.
  - **`tag` ist an `schriftbild` wahlweise**, weil nur die KARTENunterschrift
    ihn braucht. Wo er fehlt, gilt die Rolle — das betrifft ausschließlich
    Stellen, die MESSEN (Texthöhe, Zeilenlänge), und dort ändert die
    Ausrichtung nichts. Wer eine Stelle baut, die ZEICHNET, reicht ihn durch.
- **Nicht gemessen (1.0.88):** Keine Seite ist damit gesehen worden. **Die
  Ursache der Überdeckung ist NICHT behoben, sondern umgehbar gemacht:** Zwei
  Blöcke, die einander überlappen, überlappen sich weiterhin — neu ist, dass
  sich die Zeile dorthin ausrichten lässt, wo Platz ist. Ob das im gemeldeten
  Fall reicht oder ob die Zeile auch umbrechen müsste, sagt erst der nächste
  Befund. **Nicht als erledigt darstellen.**
- **GEFANGEN WIRD, WAS GEMESSEN WIRD** (`Einrasten.Herkunft.misstUmriss`,
  `Block.ueberstand(_:)`, ab 1.0.87; gemeldet 09/2026: „der dicke rote Rand
  um die Bilder, wenn sie über den Sicherheitsabstand ragen, gefällt mir
  gut. Allerdings stimmt die Einrastfunktion jetzt nicht. Wenn ich die
  Bilder verschiebe, rasten sie erst ein, wenn der rote Rand sich schon
  bildet. Natürlich wäre es wünschenswert, dass sie vorher einrasten, quasi
  am letztmöglichen Punkt, bevor sie in den Sicherheitsbereich reisen.").
  - **Er hat recht, und es ist auszurechnen.** Seit 1.0.83 misst die rote
    Marke den gezeichneten UMRISS — weißer Fotorand außerhalb des Rahmens,
    Drehung eingerechnet. Gefangen wurde weiter der RAHMEN. Ein Bild, das
    sauber an der blauen Linie einrastete, ragte mit seinem Rand längst
    darüber hinaus: **Zwei Stellen maßen zwei verschiedene Dinge, und die
    eine belohnte genau das, was die andere anstrich.**
  - **An GRENZEN gilt der Umriss, an LAYOUTkanten der Rahmen.** Schnittkante
    und Sicherheitsabstand sagen, wie weit etwas SICHTBAR reichen darf; der
    Satzspiegel und die Nachbarn sagen, wo der Automat gesetzt hätte, und
    ein von Hand geschobenes Bild soll neben einem gesetzten bündig stehen
    und nicht um seinen weißen Rand versetzt. Entschieden wird das an der
    HERKUNFT der Kante und nicht am Block.
  - **Beim Ziehen an einer Ecke trägt der Aufrufer das Vorzeichen**
    (`kanteGefangen(versatz:)`): „Innen" liegt beim Ziehen an der linken
    Kante rechts und umgekehrt, und nur er weiß, welche Kante er zieht.
    **Gezeichnet wird die Linie trotzdem dort, wo die Kante wirklich
    liegt** — eine Fanglinie ein Stück neben ihrer Kante wäre eine falsche
    Auskunft.
- **EINE KARTE IST AUCH NUR EIN BILD** (`Blockinhalt.kartenunterschrift`,
  `Reisetag.kartentext`, `Layoutautomat.karteBloecke`, ab 1.0.87; Wunsch des
  Nutzers 09/2026: „Nicht nur Bilder sollen eine Bildunterschrift tragen
  können, sondern auch die Kartendarstellungen. Die sind ja im Endeffekt
  auch nichts anderes als Bilder.").
  - **Der Text steht am TAG, nicht am Block und nicht am Foto.** Beim Foto
    steht er am Foto, weil ein Foto den Tag wechseln kann; eine Karte kann
    das nicht — sie zeigt die Spur DIESES Tages. Im Block stünde er beim
    nächsten Neuanordnen nicht mehr da; das ist die Regel seit 1.0.5.
  - **Die Karte wird um die Höhe der Zeile KÜRZER, statt Platz zu
    verlangen.** Das ist der Grund, warum an keiner der fünf Stellen, die
    eine Karte setzen, eine Höhenrechnung angefasst werden musste: Beim Foto
    hält `unterschriftHoehe` den Streifen eigens frei und geht in jede
    Reihenrechnung ein; die Karte hat keine Größe, an der etwas hängt, und
    ein paar Punkte weniger Karte sieht niemand. **Wer das umdreht, rechnet
    fünf Stellen nach.**
  - **Der Automat kennt keinen Tag — `seiten(fuer:)` schon.** Es setzt die
    Zeile in einer KOPIE seiner selbst (`kartenzeile`) und ruft damit den
    eigentlichen Bau. Der Text durch fünf Aufrufstellen hindurchgereicht
    wäre fünfmal die Gelegenheit, ihn zu vergessen.
  - **Derselbe Weg wie beim Foto, überall:** Doppeltipp auf die Karte, Knopf
    in der Fußleiste, Schalter im Inspektor — und `Reisewerk.tagZuBlock`
    fragt den Tag des BLOCKS und nie den gewählten (die Lehre aus 1.0.51).
  - **Was die Zeile beim Abschalten hergibt, bekommt die Karte zurück.**
    Sonst bliebe nach dem Ausschalten ein leerer Streifen stehen, und
    niemand wüsste, woher er kommt.
- **DIE PRÜFUNG NENNT, WAS MAN SIEHT** (`Druckpruefung.roteMarken`, ab
  1.0.87; Ansage des Nutzers: „Und natürlich soll dann auch die Druckprüfung
  anschlagen, wenn irgendwo ein roter Rahmen ist."). Beide Fälle wurden
  schon gezählt (1.0.76 und 1.0.81) — aber getrennt und unter Namen, die die
  Marke nicht nennen. Ganz oben steht jetzt EINE Zeile mit der Zahl der rot
  umrandeten Blöcke, gezählt über dieselbe Liste, die auch die Marke setzt
  (`Reise.amRandGefaehrdet`, die Vereinigung, jeder Block einmal); die beiden
  Zeilen darunter sagen, welcher Fall es ist. **Eine Prüfung, die dasselbe
  meint wie die Seite, soll es auch so nennen.**
- **Nicht gemessen (1.0.87):** Keine Seite ist damit gesehen worden. **Am
  Quelltext ABGEZÄHLT ist die Ursache des zu späten Einrastens** — die Marke
  misst den Umriss, das Einrasten maß den Rahmen, und die Differenz ist
  genau der weiße Rand plus die Drehung. **Ungeprüft bleibt, wie es sich
  anfühlt:** ob der Block jetzt an der richtigen Stelle stehen bleibt und ob
  die Fanglinie, die weiter auf ihrer Kante liegt, während der Block davor
  hält, als Hilfe gelesen wird oder als Versatz. Ebenso ungesehen, wie eine
  Karte mit Zeile auf der Seite aussieht und ob die gekürzte Karte irgendwo
  zu knapp wird. **Nicht als erledigt darstellen.**
- **DIE BILDUNTERSCHRIFT GEHÖRT ZUM BILD — SIE DREHT MIT UND SIE SCHIEBT
  MIT** (`Reisewerk.drehe`, `.schiebeMitUnterschrift`, `Rahmen.gedreht(um:grad:)`,
  ab 1.0.86; gemeldet 09/2026: „Ich habe jetzt erstmalig eine
  Bildunterschrift einfügen wollen und habe festgestellt, dass sie sich bei
  Drehung des Bildes nicht mitdreht. Im vorliegenden Fall ist es so, dass sie
  sogar zum großen Teil vom Bild verdeckt ist.").
  - **Der Satz stand im Quelltext, mit Begründung — und die Begründung traf
    nur die halbe Sache.** Dort hieß es seit 1.0.36: „Die Bildunterschrift
    dreht NICHT mit … mitgedreht würde sie um ihre EIGENE Mitte gedreht und
    rückte damit vom Bild ab." Richtig für eine Drehung, die nur den WINKEL
    setzt; falsch, sobald auch die LAGE mitgedreht wird. **Merke: Eine
    Begründung, die gegen einen Weg spricht, trifft oft nur seine einfachste
    Form.** Gedreht wird deshalb um die Mitte des BILDES und um die DIFFERENZ
    zum bisherigen Winkel — der Griff setzt ihn absolut, und die gespeicherte
    Lage trägt die vorherige Drehung schon in sich.
  - **Die Verdeckung hatte DREI Ursachen, und nur eine war die Drehung.**
    (1) Der weiße Fotorand liegt AUSSERHALB des Rahmens (die Lehre steht seit
    1.0.83 an `Block.umriss`); die Zeile stand drei Punkte unter dem Rahmen
    und damit mitten darin — im Stil „Fotoalbum" sind das 2,6 mm, also gut
    sieben Punkte. `Layoutautomat.unterschriftfuge` rechnet ihn jetzt mit,
    und die Reihenhöhe wächst mit (`unterschriftHoehe`, sonst rutschte die
    Zeile in die nächste Reihe). (2) Eine gedrehte Kachel ragt mit ihrer Ecke
    weit über den Rahmen. (3) `Seite.sortiert` rief `sorted`, und das ist in
    Swift NICHT als stabil zugesichert — bei gleicher Ebene hing vom Zufall
    ab, welcher von zwei Blöcken obenauf liegt, und ein Foto und seine
    Unterschrift liegen immer gleich hoch. **Dieselbe Falle wie beim Ordnen
    der Reisepunkte in 1.0.21.**
  - **Die GRÖSSENÄNDERUNG nimmt sie bewusst nicht mit.** Drehen und Schieben
    sind starre Bewegungen — die Gruppe bleibt, wie sie ist. Beim Ziehen an
    einer Ecke müsste die Zeile neu umbrechen und ihre Höhe neu messen; sie
    liegt danach sichtbar neben dem Bild und ist in einem Griff nachgezogen.
    Eine gedrehte Zeile unter dem Bild war dagegen gar nicht mehr zu greifen,
    und das ist der Unterschied.
  - **Gesucht wird die Zeile in DERSELBEN Seite** (`unterschriftZu`). Seit
    `blockKopieren` (1.0.39) darf dasselbe Foto zweimal im Buch stehen; über
    das ganze Buch gesucht bewegte ein Griff die Zeile der anderen Kopie mit.
  - **Beim Schieben wird sie NICHT auf die Seite geklemmt.** Starr ist starr:
    Was dabei über die Kante gerät, meldet die rote Marke — das ist die
    ehrlichere Auskunft als eine Zeile, die sich still an ihr Bild
    heranschiebt.
  - **Eine Stelle für das Drehen** (`Reisewerk.drehe`), gefragt vom Drehgriff
    UND vom Regler im Inspektor; eine für die Automatik
    (`Layoutautomat.angelegt(_:an:)`). Zwei Fassungen ergäben einen Satz, der
    nach dem ersten Anfassen anders aussieht als vorher.
- **Nicht gemessen (1.0.86):** Keine Seite ist damit gesehen worden.
  **Am Quelltext ABGEZÄHLT sind alle drei Ursachen der Verdeckung** — der
  Fotorand außerhalb des Rahmens, die Ecke des gedrehten Bildes und die
  unstabile Sortierung —, und die Geometrie der Drehung ist gerechnet.
  **Bewiesen ist damit nicht, welche davon es auf seiner Seite war:** Es kann
  eine zweite darüberliegen, und in diesem Papier stehen genug Fälle, in denen
  die erste Erklärung eine Vermutung war. Ebenso ungesehen, ob eine
  mitgedrehte Zeile unter einem stark gedrehten Bild gut aussieht oder ob man
  sie dort lieber gerade hätte. **Nicht als erledigt darstellen.**
- **AM BUND BRAUCHT NICHT JEDE DRUCKEREI EINEN ANSCHNITT**
  (`Gestaltung.anschnittAmBund`, `offeneKante(_:)`, ab 1.0.85; Ansage des
  Nutzers 09/2026 mit der Vorgabe seines Druckdienstes vor Augen: „Auch hier
  stimmt es wieder nicht, weil die App in der Mitte auch die 3 mm abzieht.
  Hier soll es aber nicht der Fall sein. Ich möchte also noch die
  Einstellmöglichkeit auf den Beschnitt an der Falz verzichten zu können.").
  - **Die Vorgabe rechnet es vor, und damit ist es keine Auslegung:**
    Bruttomaß 208 × 276 mm, Beschnittzugabe oben | unten | außen | innen =
    3 | 3 | 3 | 0, Nettomaß 205 × 270 mm. Waagerecht wird der Anschnitt genau
    EINMAL abgezogen (208 − 3 = 205), senkrecht zweimal. Die App zog ihn
    immer zweimal ab und zeigte 202 × 270 — drei Millimeter zu schmal.
  - **Die Sache war schon halb gebaut, und genau das ist der Befund.** Für
    die DOPPELSEITEN-Ausgabe gilt seit 1.0.69 „der Anschnitt liegt ringsum
    AUSSEN, am Bund keiner", für den Umschlagbogen seit 1.0.50, und die
    Doppelseitenansicht lässt ihn seit 1.0.78 über `Bogenkante` weg. Was
    fehlte, war der Fall, den dieser Dienst verlangt: EINZELSEITEN, die
    trotzdem am Bund nichts zuzugeben haben, weil die Druckerei sie selbst
    zusammenlegt. **Merke: Eine Regel, die für die eine Ausgabeart gilt, ist
    damit noch keine Einstellung — wer sie fest einbaut, kann sie für die
    andere nicht mehr abschalten.**
  - **Die Breite hängt nicht an der Seite, die LAGE schon.**
    `Gestaltung.bogen` rechnet waagerecht eine Zugabe statt zweier —
    dieselbe Zahl für jede Seite; WO das Endformat darin liegt, sagt
    `anschnittLinksPt(_:)`, und das wechselt mit `Buchseite.bundlage`.
    Deshalb wandern TrimBox und Verschiebung seit 1.0.85 IN die
    Seitenschleife: Eine feste TrimBox verschöbe die Hälfte aller Seiten um
    drei Millimeter, und zwar still — die Datei sieht tadellos aus, und erst
    das geschnittene Buch zeigt es.
  - **Aufgelöst wird an EINER Stelle** (`Gestaltung.offeneKante(_:)`),
    gefragt von der Ansicht, vom PDF und von der Druckprüfung. In der
    DOPPELSEITENansicht ist die Kante trotzdem immer offen, ganz gleich was
    eingestellt ist: Dort stoßen zwei Endformate aneinander, und das ist die
    Sache selbst und keine Einstellung. Die Entscheidung trifft deshalb der
    Aufrufer und nicht die Seitenfläche.
  - **Das Anschnittrechteck bleibt RINGSUM** (`Gestaltung.randabfallend`).
    Ein Bild darf am Bund über das Endformat hinauslaufen; die MediaBox
    beschneidet es. Ein Streifen zu viel deckt die Kante sicher ab, ein
    fehlender wäre der weiße Faden. **Was die Ansicht daran FÄNGT, ist eine
    andere Frage** — `SeitenflaecheView.fangbogen` lässt die offene Kante
    weg: Eine Kante, an der etwas einrastet, ohne dass man sie sieht, ist
    dieselbe Art stiller Widerspruch wie eine Linie ohne Wirkung (1.0.11).
  - **Der Schalter steht an ZWEI Stellen** — bei den Druckzugaben, wo der
    Anschnitt eingestellt wird, und unter „Maß der Druckerei", wo er die
    Umrechnung entscheidet. Dieselbe Einstellung, eine Quelle; wer die Zahl
    der Druckerei vor sich hat, soll die Regel daneben umlegen können, ohne
    den Bildschirm zu wechseln. Vorgabe bleibt AN: Jedes vorhandene Buch
    gibt danach dieselbe Datei aus wie vorher.
- **Nicht gemessen (1.0.85):** Keine Datei ist damit ausgegeben worden.
  **GERECHNET und an der Vorgabe des Druckdienstes nachgerechnet** ist die
  Umrechnung — 208 − 3 = 205 und 276 − 6 = 270 gehen auf das Nettomaß auf,
  das der Dienst selbst nennt. **Ungeprüft bleibt alles danach:** ob dieser
  Dienst die Datei so annimmt, ob eine TrimBox, die von Seite zu Seite die
  Kante wechselt, bei ihm durchgeht, und wie das Blatt auf dem Gerät
  aussieht, wenn die rote Schnittkante am Bund aufhört. **Nicht als erledigt
  darstellen.**
- **DER TITEL GEHÖRT AUF DIE TITELSEITE, DER NAME IN DIE ÜBERSICHT — UND DAS
  SIND ZWEI DINGE** (`Reise.regalname`, `Reise.anzeigename`, ab 1.0.84;
  Ansage des Nutzers 09/2026: „Da ich dieses Projekt noch bei einem anderen
  Druckdienst mit anderen Maßen in Auftrag geben möchte, habe ich jetzt eine
  Kopie des Fotobuches erstellen lassen. Dabei ist mir aufgefallen, dass der
  Titel des Buches versteckt in den Einstellungen zu den Rändern und der
  Druckausgabe steckt. … Was ich aber definitiv möchte, ist eine Trennung
  zwischen dem, was auf der Titelseite steht, und dem, wie ich das Projekt in
  der Übersichtsleiste der anderen Projekte benennen möchte.").
  - **Sein Fall lässt sich mit EINEM Feld gar nicht ausdrücken.** Zwei Bücher
    mit demselben Inhalt für zwei Druckdienste müssen im Regal zu
    unterscheiden sein — auf der Titelseite aber gerade nicht. **Und die App
    hat den Unterschied schon bezahlt, ohne ihn zu kennen:** `duplizieren`
    schrieb „ (Kopie)" in den gedruckten TITEL, ebenso das Einlesen einer
    Buchdatei als Kopie. Wer die Kopie nicht von Hand umbenannte, hatte das
    Wort auf der Titelseite stehen. **Merke: Wenn ein Name an zwei Orten
    auftaucht und einer davon gedruckt wird, sind es zwei Felder.**
  - **`nil` heißt „wie der Titel" — Abweichung, keine Kopie**, dieselbe Regel
    wie bei `Schriftabweichung`, `Block.wirkung` und `Kartenwahl`: Wer den
    Titel ändert, ändert den Namen im Regal mit, solange er nichts anderes
    gesagt hat, und jedes vorhandene Buch sieht nach dem Update unverändert
    aus. Ein LEERES Feld setzt `nil` und nicht einen leeren Namen — sonst
    hieße das Buch „nichts" und wäre nicht mehr davon loszukommen (dieselbe
    Trennung wie `Block.ohneGrund`).
  - **Aufgelöst wird an EINER Stelle** (`Reise.anzeigename`). Gefragt wird
    sie von allem, was eine DATEI benennt oder in einer Liste der App steht:
    Regal, Buchdatei, PDF-Dateiname und -Titel, Druckauftrag, die Befunde und
    die Überschrift der Bühne. `titel` bleibt, wo GESETZT wird: Titelseite,
    Buchrücken, Kopfzeile. Zwei Auflösungen nebeneinander liefen auseinander,
    und dann hieße dasselbe Buch im Regal anders als in seiner Datei.
  - **Der Dateiname und der PDF-Titel folgen dem PROJEKT, nicht dem Buch.**
    Beides ist dazu da, die Datei im Ordner und im Fenster des Betrachters
    wiederzufinden — zwei PDFs, die beide „Kanada 2026" heißen, sind genau
    der Fehler, um den es hier geht.
  - **Der Titel steht jetzt dort, wo er gedruckt wird** (Ganzes Buch → Titel,
    Umschlag und Rücken). Er lag unter „Ränder und Druckzugaben…", weil
    dieser Bildschirm bis 1.0.77 „Ränder, Karte, Seitenzahlen" hieß und der
    Ort für alles war, was sonst nirgends hinpasste. **Vierzehnte Auflage von
    „es war da, man fand es nicht"** — und die zweite, bei der nicht der Weg
    zu kurz, sondern die Zuordnung falsch war (nach dem Tagebuch-Stil in
    1.0.32). In der Gestaltung bleibt eine **Auskunft mit dem Weg** (Regel
    seit 1.0.27), und der Menüpunkt NENNT den Titel jetzt: Ein Menüpunkt, der
    nicht sagt, was dahinterliegt, kostete 1.0.79 schon einmal eine Funktion.
  - **Umbenannt wird auch im Regal** — lange tippen oder wischen. Wer vor der
    Liste steht, meint die Liste; der Alert sagt ausdrücklich, dass auf der
    Titelseite weiter der Titel steht. Ein offenes Buch wird dabei über sein
    `Reisewerk` geändert und nicht an ihm vorbei auf die Platte geschrieben —
    sonst überschriebe der nächste Sicherungslauf den neuen Namen gleich
    wieder.
- **Nicht gemessen (1.0.84):** Nichts davon ist auf einem Gerät gesehen
  worden. Am Quelltext ABGEZÄHLT ist, wo der Name gedruckt wird und wo er nur
  benennt — jede der Stellen ist einzeln durchgegangen. **Ob der Titel jetzt
  gefunden wird, sagt erst der nächste Befund:** Geändert sind Wege und Namen,
  und das ist keine Messung (dieselbe Einschränkung wie bei den Menüs in
  1.0.20, 1.0.49 und 1.0.77). **Nicht als erledigt darstellen.**
- **Nicht gemessen (1.0.83):** Keine Seite ist damit gesehen worden. **Am
  Quelltext ABGEZÄHLT sind die beiden blinden Flecken** (Fotorand außerhalb
  des Rahmens, Drehung ungerechnet) und die Größenordnung, um die sie die
  Marke nach außen schieben — sie passt zu dem, was gemeldet wurde.
  **Bewiesen ist damit nicht, dass es DIE Ursache war:** Es kann eine zweite
  darüberliegen, und in diesem Papier stehen genug Fälle, in denen die erste
  Erklärung eine Vermutung war. Genau deshalb nennt die Probe seit 1.0.83
  Zahlen statt einer Zusage — beim nächsten Mal sagt der Befund, ob die App
  den Block überhaupt für gefährdet hält oder ob es an der Zeichnung liegt.
  **Nicht als erledigt darstellen.**
- **Nicht gemessen (1.0.82):** Keine Seite ist damit gedruckt worden.
  Gerechnet ist die Geometrie (dass die Seitenzahl bei 3 mm Rand auf 1,8 mm an
  die Kante käme und dass das Klemmen sie in die Schutzzone holt). **Ob ein
  Buch mit 3 mm Rändern gut aussieht, ist keine Frage, die diese App
  beantwortet** — sie gibt die Einstellung frei und schreibt hin, was dabei zu
  bedenken ist. Ungeprüft bleibt auch, wie eng ein Druckdienst das nimmt:
  3 mm sind sein Mindestabstand für INHALT, und ob er einen Fließtext meint,
  der dort anfängt, sagt seine Vorgabe nicht. **Nicht als erledigt
  darstellen.**
- **EIN HANDBUCH IN DER APP — UND JEDER EINTRAG TRÄGT SEINEN WEG**
  (`Views/Handbuch.swift`, `Views/HandbuchView.swift`, ab 1.0.77; Ansage des
  Nutzers 09/2026: „Die Funktionen sind sehr mannigfaltig und zum Teil auch
  versteckt, so dass ich finde, dass das sinnvoll wäre.").
  - **Zwei Listen, zwei Fragen.** Die Bedienungskarte (seit 1.0.10) zählt
    die GESTEN auf — was man mit dem Finger tut, und das sieht man einer
    Seite nicht an. Das Handbuch zählt die FUNKTIONEN auf und sagt, WO sie
    stehen. Sie ersetzen einander nicht; das Fragezeichen unten führt
    seither ins Handbuch, und die Gestenkarte steht dort als erster
    Eintrag.
  - **Ein Handbuch ohne Weg ist die Frage von vorhin noch einmal.** Jeder
    Eintrag nennt den Menüpfad, und wo es ein Blatt dafür gibt, springt ein
    Knopf dorthin. Wo es keins gibt (Gesten, Knöpfe in der Leiste), steht
    nur der Weg — ein Knopf, der woanders landet, wäre schlechter als
    keiner.
  - **Der Sprung geht über den BLATTWUNSCH**, nicht über ein zweites Blatt:
    Das Handbuch macht sich zu, die Wurzel öffnet das Ziel im `onDismiss`
    (dieselbe Bauweise wie der geführte Weg seit 1.0.18). Dafür trägt
    `alsNaechstes` jetzt Ziel UND Rückkehr. Bis 1.0.76 wurde die Rückkehr
    ERSCHLOSSEN („alles außer dem Aufbau führt dorthin zurück"), und das
    trug nur, solange ein einziger Weg sprang. **Der Wunsch trägt das Ziel,
    kein Schalter daneben** (Regel seit 1.0.9).
  - **Die Suche ebnet Umlaute EIN — ausdrücklich gegen die Hausregel.**
    Die gilt dem Vergleich von NAMEN, wo eine falsche Gleichsetzung Schaden
    anrichtet (Kürzel in Schulalarm, Haltestellen in der Abfahrtstafel). In
    einer Volltextsuche ist es der umgekehrte Fall: Wer „Ruecken" tippt,
    sucht den Rücken, und ein Treffer zu viel kostet nichts. **Wer eine
    Regel umkehrt, schreibt den Grund dazu.**
  - **Ein eigenes Kapitel „Was die App nicht kann".** Kein CMYK, kein
    Textfluss um eine Form, keine eigenen Felder auf dem Buchrücken, die
    Karte zeichnet die Verbindung und nicht den Weg. Lieber eine Lücke als
    eine Zusage, die nicht hält — und was dort steht, ist nicht vergessen
    worden, sondern bewusst nicht gebaut.
- **EIN MENÜ MIT SECHZEHN EINTRÄGEN IST EIN VERSTECK** (ab 1.0.77). Das
  „…"-Menü ist der Ort, an dem dreimal etwas lag, das niemand fand
  (Broschüre 1.0.37, zwei Dateien 1.0.52, Druckprüfung 1.0.76) — und es trug
  seine Einträge ungegliedert hintereinander. Jetzt fünf Abschnitte, benannt
  nach dem, was man VORHAT: Vor dem Druck, Ausgeben, Das ganze Buch, Hilfen
  beim Anordnen, Hilfe und Prüfen.
- **WER EINEN MENÜPUNKT UMBENENNT, ZIEHT JEDEN VERWEIS MIT** (ab 1.0.77).
  „Ränder, Karte, Seitenzahlen…" heißt jetzt „Ränder und Druckzugaben…" —
  dahinter liegen Anschnitt, Sicherheitsabstand und Bundsteg, also alles,
  was eine Druckerei verlangt, und der Name nannte nichts davon. Der alte
  Name stand an ZWÖLF Stellen (Ausgabesteckbrief, Bedienungskarte,
  Handbuch), teils als Klartext und teils in `\u{00E4}`-Schreibweise — wer
  nur nach der einen Form sucht, lässt die andere stehen. Dabei fiel ein
  Weg auf, den es seit mehreren Fassungen nicht mehr gab („Buch → Format,
  Ränder, Karte" im Block-Inspektor). **Ein Weg, der auf einen Namen zeigt,
  den es nicht mehr gibt, ist schlimmer als kein Weg** (Lehre aus 1.0.49).
- **Nicht gemessen (1.0.77):** Nichts davon ist auf einem Gerät gesehen
  worden. **Und das Wichtigste lässt sich hier grundsätzlich nicht
  messen: Ob die Funktionen damit auffindbar SIND, sagt kein Handbuch,
  sondern der nächste Mensch, der die App zum ersten Mal öffnet.** Geändert
  sind Wege und Namen — dieselbe Einschränkung wie bei den Menüs in 1.0.20
  und 1.0.49. Die Wege im Handbuch sind gegen den Quelltext geprüft, nicht
  in der laufenden App abgeklickt.
- **AM BUND GILT EIN ANDERER SICHERHEITSABSTAND — UND WELCHE SEITE INNEN
  LIEGT, WECHSELT** (`Gestaltung.sicherheitsabstandInnen`, `Bundlage`,
  `Buchseite.bundlage`, ab 1.0.76; Ansage des Nutzers 09/2026: „Im
  vorliegenden Fall soll der 3 mm vom Rand betragen und 5 mm an der
  Innenseite dort, wo die Seite verklebt wird.").
  - **Es sind zwei Ursachen, also zwei Zahlen.** Außen entscheidet das
    Spiel der Schneidemaschine (so steht es seit 1.0.73 hier), innen
    verschwindet ein Streifen im Falz — bei einer Klebebindung mehr als bei
    einer Fadenheftung. **Oben und unten gilt immer der äußere Wert**: Dort
    wird geschnitten und nicht gebunden.
  - **`nil` heißt „wie außen" und ist keine Kopie** — dieselbe Regel wie bei
    `Schriftabweichung`, `Block.wirkung` und `Kartenwahl`. Jedes vorhandene
    Buch sieht nach dem Update unverändert aus, und wer später den äußeren
    Wert ändert, ändert den inneren mit.
  - **Die Bundseite wird HEREINGEREICHT, nicht geraten.** `Gestaltung` weiß
    nicht, welche Seite innen liegt — das hängt an der laufenden
    Seitenzahl. `Buchseite.bundlage` fragt dafür `liegtRechts`, also die
    eine Stelle, die es seit 1.0.47 ohnehin weiß; der AUSSENbogen des
    Umschlags hat keinen Bund (er wird umgelegt, nicht gebunden — dieselbe
    Überlegung, aus der `Umschlagmass.satzspiegel` den Bundsteg wieder
    herausrechnet).
  - **Der Unterschied zum BUNDSTEG ist kein Widerspruch.** Der geht seit
    1.0.1 auf BEIDE Seitenränder, gerade WEIL eine Seite beim Umbruch die
    Buchhälfte wechselt — er verschiebt den Satzspiegel, und ein Satz, der
    je nach Seitenzahl anders steht, wäre nicht zu setzen. Der
    Sicherheitsabstand verschiebt nichts, er PRÜFT nur — er darf die Seiten
    also unterscheiden.
  - **Beim Formatwechsel bleibt er draußen, beide Werte.** Was im Falz
    verschwindet, hängt an der Bindung und nicht am Papierformat.
- **DIE ZWEI GESTRICHELTEN LINIEN GAB ES — DER SCHALTER HIESS NACH EINER VON
  DREIEN** (ab 1.0.76). Rot gestrichelt ist die Schnittkante, orange der
  Sicherheitsabstand, blau der Satzspiegel; alle drei hängen an EINEM
  Schalter, und der hieß „Satzspiegel zeigen". Wer nach der Schnittlinie
  sucht, sucht nicht unter „Satzspiegel" — er heißt jetzt „Linien zeigen:
  Satzspiegel, Schnitt, Sicherheit". Dazu zeigt `Schutzzonenskizze` dort,
  wo die Zahlen eingestellt werden, **zwei gegenüberliegende Seiten** mit
  dem Bund in der Mitte — gezeichnet mit derselben Rechnung wie das Blatt
  daneben, denn eine zweite Fassung zeigte hier etwas anderes als dort.
- **EINE WARNUNG, DIE NUR IN EINEM BLATT STEHT, SIEHT NIEMAND**
  (`Reise.imSicherheitsabstand(_:)`, ab 1.0.76; Ansage des Nutzers 09/2026:
  „Dann möchte ich, dass die App sich bemerkbar macht, falls an irgendeiner
  Stelle einer dieser Sicherheitsabstände nicht berücksichtigt wurde.").
  Zwei Wege, und beide sind nötig: Auf der SEITE bekommt jeder betroffene
  Block einen orange gestrichelten Rahmen (in der Farbe der Linie, an der er
  zu nah steht) — das sieht aber nur, wer die Linien eingeschaltet hat;
  UNTER dem Blatt steht es in Worten und unabhängig davon. Die
  Beschriftungszeile war ohnehin da und behält ihre feste Höhe, denn
  `Zoomanker` rechnet mit ihr.
  **Geprüft wird an EINER Stelle**, gefragt von der Seite, der Bühne und der
  Druckprüfung: Drei Fassungen derselben Prüfung fänden irgendwann
  Verschiedenes, und dann meldete die eine, was die andere nicht zeigt.
  **Randabfallende Blöcke bleiben ausgenommen, ohne Ausnahme** — nach der
  dritten falschen Marke sieht niemand mehr hin.
- **DIE DRUCKPRÜFUNG LAG IM AUSGABEBLATT — ALSO HINTER DER ABSICHT,
  AUSZUGEBEN** (`Views/DruckpruefungView.swift`, ab 1.0.76; Ansage des
  Nutzers 09/2026: „Zu diesem Punkt meine ich mich zu erinnern, dass mir die
  App an irgendeiner Stelle bereits rückgemeldet hat, dass beispielsweise
  Text nicht ganz in ein Textfeld gepasst hat. Ich finde diesen Menüpunkt
  leider nicht mehr wieder.").
  **Er hat sie gesehen.** `Druckpruefung.vorab` läuft seit 1.0.1 und zählt
  `abgeschnittenerText` mit — sie stand aber ausschließlich im Ausgabeblatt,
  unter der halben Seite Einstellungen. **Zwölfte Auflage von „es war da,
  man fand es nicht"**, dieselbe Lehre wie bei der Broschüre (1.0.37), den
  zwei Dateien (1.0.52) und dem Ausgabeformat (1.0.75), und dieselbe
  Antwort: eigener Menüpunkt, nach der SACHE benannt, ganz oben.
  **Kein zweiter Prüfer** — dieselbe Funktion und dieselbe Zeile
  (`BefundZeile`), nur sortiert nach Dringlichkeit und kopierbar; das
  Ausgabeblatt behält seinen Abschnitt und nennt den zweiten Weg.
  **Merke: Eine Prüfung gehört nicht hinter die Handlung, für die sie
  prüft.**
- **`.inspector` IST EINE SPALTE UND NIMMT DER BÜHNE IHRE BREITE** (ab
  1.0.76; Befund des Nutzers 09/2026: „Sobald ich auf den Pinsel tippe,
  klappt rechts eine ganze Seite auf, die bewirkt, dass der
  Bearbeitungsbereich verkleinert wird. Das möchte ich nicht."). Auf einem
  iPad im Hochformat ist das ein knappes Drittel — und genau dort steht das
  Blatt, an dem gearbeitet wird. Der Inspektor hängt seither als **Popover**
  am Pinselknopf: Er deckt nur einen Teil ab und geht bei einem Tipp daneben
  wieder zu; auf dem iPhone macht SwiftUI daraus von selbst ein Blatt, wo
  ein Popover eine Briefmarke wäre. Zwei Dinge gehören dazu: ein Stapel
  darum, damit das Blatt einen sichtbaren Ausgang hat (Regel seit 1.0.9),
  und ein `onChange` auf das geöffnete Blatt — wer aus dem Inspektor heraus
  eines öffnet, bekommt sonst ein Blatt über einem Popover.
  **Der Grund, aus dem der Inspektor Blätter statt `NavigationLink`s
  benutzt, bleibt gültig** (1.0.29): Er bringt weiterhin keinen eigenen
  Stapel mit, den seine Unterseiten benutzen könnten.
- **Nicht gemessen (1.0.76):** Nichts davon ist auf einem Gerät gesehen
  worden. Gerechnet ist die Geometrie — dass die orange Linie auf einer
  rechten Seite links weiter innen läuft und auf einer linken rechts.
  **Ungeprüft bleibt, ob das Popover auf dem iPad an der gewünschten Stelle
  aufgeht** und ob sich die Blätter, die der Inspektor öffnet, darin
  verhalten wie in der Spalte; das ist die Lesart der Dokumentation und
  keine Messung. Die Zahlen 3 mm außen und 5 mm am Bund sind die der
  Druckerei — eingetragen, nicht nachgeprüft. **Nicht als erledigt
  darstellen.**
- **NACH DER DRITTEN DRUCKEREI WEISS NIEMAND MEHR, WAS GILT**
  (`Model/Ausgabesteckbrief.swift`, `Views/AusgabeformatView.swift`, ab
  1.0.75; Ansage des Nutzers 09/2026: „Bei einer anderen Druckerei wird bei
  den Tagebuchseiten auf der Innenseite kein Bundsteg gelassen. Das gipfelt
  jetzt in einer Fülle von Formaten. Vielleicht wäre es gut, sich innerhalb
  der App irgendwo anzeigen lassen zu können, wie denn jetzt das
  Ausgabeformat aussieht und wie die einzelnen Werte sind.").
  **Das ist der Befund aus 1.0.72, eine Ebene breiter.** Damals ging es um
  EINE Zahl, und sie war nie falsch — sie stand nur nirgends so da, dass man
  sie gegen eine Bestellung halten konnte. Jetzt sind es alle: Anschnitt,
  Sicherheitsabstand, Ränder, Bundsteg, Rückenbreite, Umschlagbogen,
  Bildgüte. Jede einzelne ist woanders einstellbar.
  - **Gerechnet wird NICHTS neu.** Jede Zahl kommt aus der Stelle, die sie
    auch beim Ausgeben liefert (`Gestaltung`, `Druckvorgabe`,
    `Umschlagmass`, `Bildguete`), und der Kopiertext entsteht aus DENSELBEN
    Abschnitten wie der Bildschirm. Zwei Fassungen nennten zwei Zahlen, und
    die Druckerei prüft eine — dieselbe Regel, aus der `Bogenlage` und
    `Umschlagmass` entstanden sind.
  - **Jede Zeile sagt, ob sie EINSTELLUNG oder FOLGE ist**, und wo man sie
    umstellt. Das ist kein Zierat: Das Endformat hat jemand gewählt, das
    Bogenmaß folgt. Wer das verwechselt, trägt das Bogenmaß als Format ein —
    genau die Falle, die `Druckvorgabe.bogenverdacht` abfängt.
  - **Der Bundsteg ist die Antwort auf die Frage, die die Fassung ausgelöst
    hat, und es war NICHTS zu ändern:** Die Vorgabe ist seit 1.0.1 null, und
    „innen kein Bundsteg" ist damit der stehende Zustand. Was fehlte, war der
    Satz, der es sagt. Steht doch einer, nennt die Zeile die zweite Hälfte
    dazu (auf BEIDE Seitenränder gerechnet, samt der Zahl, die der äußere
    Rand dann misst).
  - **Ein eigener Menüpunkt, keine Zeile in einem Picker** — die Lehre aus
    1.0.37 und 1.0.52, wo zweimal etwas vollständig Gebautes hinter einem
    zugeklappten Picker lag. Daneben führt ein Weg aus dem Ausgabeblatt
    hinein, mit der DORT gewählten Bildgüte; ohne Übergabe gilt
    `Bildguete.vorgabe`, und die Fußzeile schreibt hin, dass sie es tut.
  - **Gemeldet wird IM Blatt, nicht über `werk.meldung`.** Das Band hängt an
    `ReiseView`, und diese Ansicht liegt als Blatt darüber — die Quittung
    erschiene dahinter (dieselbe Lehre wie bei der Punktwahl in 1.0.52).
  - **`Ausgabeguete.satz` läuft über jedes Bild des Buches** und gehört
    deshalb in eine Aufgabe und nicht in den Körper; hereingereicht wird er
    als fertiger Text, damit `Ausgabesteckbrief.abschnitte` billig bleibt.
  - **Kein `uppercased()` auf einer deutschen Überschrift** im Kopiertext:
    Die Großschreibregel für ß ist SS, und daraus wird ein falsch
    geschriebenes Wort (die Lehre aus Wörterwerkstatt 1.7.1).
- **Nicht gemessen (1.0.75):** Diese Seite sagt, WAS ausgegeben wird, und
  nicht, was in der fertigen Datei steht — das misst weiterhin
  `Druckpruefung.amPDF`. Ob die Übersicht die Fülle der Formate
  beherrschbar macht, sagt erst der nächste Befund: Geändert sind Wege und
  Namen, und das ist keine Messung (dieselbe Einschränkung wie bei den Menüs
  in 1.0.20). **Nicht als erledigt darstellen.**
- **DIE INNENSEITEN DES UMSCHLAGS DÜRFEN INHALT TRAGEN — UND DANN WECHSELT
  JEDE SEITE DIE BUCHHÄLFTE** (`Umschlag.innenseitenInhalt`,
  `Buchteil.innenVorn`/`.innenHinten`, ab 1.0.74; Ansage des Nutzers
  09/2026: „Die von mir beauftragte Druckerei schafft es offenbar auch, die
  Innenseiten des Umschlages bereits zu bedrucken. Das heißt, ich könnte zwei
  Seiten insgesamt am Dokument sparen … Dadurch würden sich aber alle Seiten
  innerhalb des Dokumentes verschieben. Eine linke Seite würde zur rechten
  bzw. umgekehrt.").
  **Er hat die Folge selbst mitgenannt, und sie stimmt** — sie folgt aus der
  Buchbinderei: Die erste Inhaltsseite lag rechts (Seite 1 ist ein Recto),
  links davon die leere Innenseite des Deckels. Wandert sie auf U2, das
  LINKS liegt, rückt alles Folgende um eine Stelle vor; was gegenüberlag,
  liegt es nicht mehr.
  - **Nichts davon muss eigens gebaut werden.** Es fällt aus `seitenfolge`
    heraus, weil `nummer` erst bei der dritten Inhaltsseite bei 1 anfängt —
    und Paarung wie Hintergrundhälfte hängen seit 1.0.47 an
    `Buchseite.liegtRechts`, also an genau einer Stelle. **Das ist der
    Lohn dafür, dass die Seitenfolge gerechnet wird und nicht gespeichert:**
    Umlegen und Zurücknehmen kostet keinen Umbau am Satz, und die
    Doppelseitenansicht zeigt die neue Paarung sofort.
  - **Dass der Satzspiegel dabei stimmt, liegt am Bundsteg.** Er wird seit
    1.0.1 auf BEIDE Ränder gerechnet, mit genau dieser Begründung: „Welche
    Seite innen liegt, hängt an der laufenden Seitenzahl, und die
    verschiebt sich." Eine Fassung, die ihn nur innen rechnete, bräuchte
    hier einen Neusatz des ganzen Buches.
  - **`Buchseite.bogen` ist seit 1.0.74 GESPEICHERT, nicht gerechnet.** Bis
    1.0.73 folgte der Bogen allein aus der Seitennummer; eine
    Umschlaginnenseite trägt aber die Nummer 0 und liegt trotzdem auf einem
    Bogen des Buches (U2 neben Seite 1, U3 neben der letzten). Vergeben wird
    er dort, wo auch die Nummer vergeben wird — in `seitenfolge`, der einen
    Stelle für beides. Ohne das läge U2 auf Bogen 0 und damit neben der
    TITELSEITE.
  - **`blockseiten` zieht die zwei ab**, und das ist nicht Kosmetik: An
    dieser Zahl hängt die RÜCKENBREITE. Ein Rücken, der zwei Seiten zu dick
    gerechnet ist, passt nicht auf das gebundene Buch.
  - **`tag == nil` reicht als Umschlagprüfung NICHT mehr.** U2 und U3 tragen
    Inhalt und damit einen Tag — und gehören trotzdem auf den Umschlagbogen.
    Die Ausgabefilter fragen seither zusätzlich `amUmschlag`; ohne das
    stünden sie mitten im Innenteil, in einem Maß, das dort nicht gilt.
  - **Auf dem Innenbogen zeichnet jede Hälfte ihren EIGENEN Grund**
    (`ohneGrund: false`), anders als auf dem Außenbogen. Dort liegt ein
    Grund über den ganzen Bogen samt Rücken; hier trägt jede Hälfte eine
    Tagebuchseite, und die soll aussehen wie eine. Die Farbe für U2+U3 gilt
    damit nur noch, wenn die Innenseiten LEER bleiben — sie bleibt als Grund
    darunter stehen und trägt den Rücken.
  - **Erst ab vier Inhaltsseiten** (`Reise.umschlagTraegtInhalt`). Zwei
    abzuziehen ließe sonst kein Buch übrig, das sich binden lässt.
  - **Die Druckprüfung FRAGT die Folge, statt sie nachzubauen** (ab 1.0.74).
    `doppelseitenhintergrund` zählte die Seiten bis 1.0.73 selbst durch —
    eine zweite Zählung, und genau davor warnt der Fall von 1.0.52. Sie
    hätte hier jede Seite auf die falsche Hälfte gelegt und daraufhin lauter
    Bogen gemeldet, die „nicht aufgehen". Das Titelblatt muss dafür nicht
    gesetzt werden: Gebraucht werden Nummer, Lage und Hintergrund, und einen
    eigenen Hintergrund hat es nicht — eine leere `Seite()` genügt und kostet
    keine CoreText-Messung.
- **Nicht gemessen (1.0.74):** Keine Datei ist damit gedruckt worden.
  **Gerechnet und am Quelltext durchgezählt** ist die Paarung (U2 links neben
  Seite 1, U3 rechts neben der letzten; bei vier Blockseiten Bogen 1 = U2|1,
  Bogen 2 = 2|3, Bogen 3 = 4|U3). **Wie die Druckerei die beiden Bogen
  erwartet, ist seit 09/2026 BEANTWORTET: „Sie erwartet die Umschlagbogen in
  einer Datei."** Genau so gibt die App sie aus — eine Datei mit zwei Seiten,
  außen zuerst. **Die REIHENFOLGE darin ist damit nicht bestätigt**; sie folgt
  der Anschauung (umgeschlagen liegt außen zuerst) und keiner Ansage. Ebenso
  ungesehen: ob ein Hintergrundbild über die Doppelseite an der neuen
  Paarung aufgeht. **Ein Wasserzeichen über die Doppelseite gibt es nicht
  und gab es nie** — über die Doppelseite kann der HINTERGRUND laufen
  (`Seitenhintergrund.ueberDoppelseite`, seit 1.0.47); das Wasserzeichen
  liegt je Seite einzeln. **Nichts davon als erledigt darstellen.**
- **ANSCHNITT UND SICHERHEITSABSTAND SIND ZWEI STREIFEN IN ENTGEGENGESETZTE
  RICHTUNGEN** (`Gestaltung.sicherheitsabstand`, `.schutzzone`, ab 1.0.73;
  Befund des Nutzers 09/2026 an seinem ersten Druckauftrag: „wenn ich die von
  der Druckerei geforderten Werte mit dem Standardformat DIN A4 vergleiche,
  dann sind die Maße ja größer. Das heißt, die Druckerei erwartet von mir
  eine größere Seite, spricht aber auch von Beschnitt. Ich denke daher, dass
  es sinnvoll sein dürfte, einen Sicherheitsabstand zum Rand zu halten.").
  **Der Schluss ist richtig, die Begründung trifft daneben — und beides
  gehört gesagt.** Die SEITE wird nicht größer; sie bleibt A4. Größer ist die
  DATEI, weil der Anschnitt außen dranhängt und weggeschnitten wird. Wer den
  Satz „die erwarten eine größere Seite" zu Ende denkt, trägt 216 × 303 als
  Seitenformat ein — und genau das ist die Falle aus 1.0.72.
  - **Was den Abstand nötig macht, ist etwas anderes als der Anschnitt, und
    zwar dieselbe Ursache aus der anderen Richtung**: Jede Schneidemaschine
    hat ein Spiel von einem knappen Millimeter, und ein Stapel Bücher wird
    nie auf den Punkt genau getroffen. Der Anschnitt sorgt dafür, dass bei
    einem Schnitt NACH INNEN kein weißer Faden stehen bleibt; der
    Sicherheitsabstand dafür, dass bei einem Schnitt NACH AUSSEN nichts
    Gelesenes abgeschnitten wird. **Der Anschnitt liegt AUSSERHALB des
    Endformats, der Sicherheitsabstand INNERHALB.**
  - **Die App kannte ihn bis 1.0.72 gar nicht.** Die Ränder (16/17/19 mm)
    halten den Satzspiegel weit genug innen, und auch Seitenzahl und
    Kopfzeile sitzen sicher (`Seitenbeiwerk` rechnet mit Anteilen der
    Ränder). Ungeschützt war alles, was jemand VON HAND an die Kante
    geschoben hat — und seit 1.0.61 lassen sich Blöcke frei setzen.
  - **Gezeichnet wird ORANGE und feiner gestrichelt**, gleich neben der
    roten Schnittkante. Zwei rote Linien nebeneinander wären zwei Namen für
    dasselbe, und genau diese Verwechslung ist der Anlass der Fassung.
    **Nicht blau**: Das ist beim Einrasten seit jeher der NACHBAR, und
    dieselbe Farbe für zwei Auskünfte ist eine Auskunft weniger. Aufgefallen
    ist das erst am roten Bau — **wer eine Aufzählung erweitert, sucht jeden
    `switch` darüber** (`Views/Griffe.swift` war der einzige, und er hat
    zugleich die Farbkollision gezeigt).
    Abgeschaltet (0 mm) wird auch keine Linie gezeichnet und an nichts
    gefangen — eine Linie ohne Wirkung wäre eine Behauptung (die Regel steht
    seit 1.0.11 da).
  - **Er ist eine Fangkante wie die anderen** (`Einrasten.Herkunft.sicherheit`).
    Wer einen Block an die Kante schiebt, soll dort fangen und nicht daneben;
    die Linie beim Schieben nennt ihn beim Namen.
  - **Gezählt wird am ERGEBNIS, nicht an der Absicht**
    (`Druckpruefung.schutzzone`): jeder Block, der wirklich hineinragt, mit
    Tag und Seite, und Textblöcke eigens — Text ist der Fall, um den es geht.
    **Randabfallende Blöcke sind ohne Ausnahme ausgenommen.** Sie SOLLEN über
    die Kante laufen; sie zu melden hieße, das als Fehler auszugeben, was
    richtig ist — und nach dem dritten solchen Hinweis liest niemand mehr
    eine Zeile dieser Prüfung. Wer einen Block wirklich bis an die Kante
    will, schaltet ihn auf randabfallend; die Meldung sagt das auch.
  - **Beim Formatwechsel wird er NICHT mitgerechnet** — aus demselben Grund
    wie der Anschnitt: Das Spiel der Schneidemaschine ist dasselbe, ob eine
    Seite A4 misst oder A5. Wer ihn mitschrumpfte, bekäme auf der kleineren
    Seite genau dort weniger Schutz, wo der Rand ohnehin knapper wird.
    `Formatwechsel` zählt die Längen einzeln auf, also ist er von selbst
    draußen — der Kommentar dort sagt seit 1.0.73, dass das eine Entscheidung
    ist und kein Vergessen.
- **Nicht gemessen (1.0.73):** Keine Seite ist damit gedruckt worden.
  **Gewählt und nicht gemessen** sind die Vorgabe von 5 mm und die Spanne des
  Reglers (0 bis 12 mm); 3 bis 5 mm sind das, was Druckdienste üblicherweise
  nennen, und diese App hat es an keinem nachgeprüft. Ob der orange Strich auf
  einem Gerät neben dem roten zu unterscheiden ist, hat ebenfalls niemand
  gesehen. **Nicht als erledigt darstellen.**
- **WAS EINE DRUCKEREI NENNT, IST DER BOGEN — NICHT DIE SEITE**
  (`Model/Druckvorgabe.swift`, ab 1.0.72; gemeldet 09/2026 aus dem ERSTEN
  echten Druckauftrag: „Das Format der erhaltenen Daten stimmt nicht mit der
  Bestellung überein. Bitte legen Sie Ihre Daten im Format 216 mm x 303 mm
  an. Dieses beinhaltet das bestellte Endformat und die benötigte
  Beschnittzugabe.").
  **Nachgerechnet, und die App hatte recht:** 216 − 2 × 3 = 210,
  303 − 2 × 3 = 297. Verlangt wird **A4 hoch mit 3 mm Anschnitt**, und genau
  das gibt `Gestaltung.bogen` seit 1.0.1 aus. Ebenso der Umschlag:
  2 × 210 + 2 (Rücken) + 2 × 3 = **428 × 303**, Wort für Wort die zweite
  Forderung derselben Mail. **Die Zahlen waren nie falsch — sie standen nur
  nirgends so da, dass man sie gegen eine Bestellung halten konnte.**
  - **Die Falle, um die es geht:** Seit 1.0.52 lässt sich ein eigenes Maß
    als Format eintragen. Wer die Zahl der Druckerei DORT einträgt, bekommt
    eine PDF-Seite von 222 × 309 mm — Endformat plus ein zweites Mal
    Anschnitt —, und die Datei kommt wieder zurück. Schlimmer:
    `Formatwechsel` rechnet dabei jeden Block, jeden Rand und jede
    Schriftgröße des Buches um. **Ein Fehler, der wie eine Lösung aussieht.**
  - **Gefragt wird deshalb nach dem Maß der DRUCKEREI, nicht nach dem
    Endformat** (eigener Abschnitt im Formatblatt). Zwei Felder, darunter
    live das Endformat, das daraus folgt. Und wer doch unten tippt, bekommt
    den Hinweis: `Druckvorgabe.bogenverdacht` prüft, ob das eingetippte Maß
    nach Abzug des Anschnitts auf eine bekannte Vorlage fällt. **Eng gefasst
    mit Absicht** — ein Hinweis, der bei jedem zweiten Maß erscheint, wird
    nach dem dritten Mal überlesen —, und **ein Hinweis und keine Sperre**:
    Wer wirklich 216 × 303 als Endformat bestellt hat, soll es eintragen
    können.
  - **Das Bogenmaß steht jetzt dort, wo die Datei entsteht** (Ausgabeblatt,
    Zeile „Bogen im PDF"). Bis 1.0.71 stand dort nur das Endformat, also die
    Seite, wie sie geschnitten in der Hand liegt — geprüft wird aber die
    DATEI. Es folgt der gewählten Anordnung: Einzelseiten, Doppelseiten und
    Umschlag sind drei verschiedene Maße, und gerechnet wird über dieselben
    Stellen wie die Ausgabe. Zwei Fassungen nennten zwei Zahlen, und die
    Druckerei prüft eine.
  - **Die Rückenstärke lässt sich eintragen** (`Umschlag.rueckenbreiteVonHand`).
    Dieselbe Mail: „Dieses Format beinhaltet 2 mm Rückenstärke". Zwei
    Millimeter — eine Zahl, fertig; eintragen ließ sie sich bis 1.0.71 nur
    als Tabellenzeile („ab 0 Seiten: 2 mm"), also über einen Umweg, den
    niemand findet, wenn er eine einzelne Zahl vor sich hat. Sie schlägt
    Tabelle UND Rechnung, und `rueckenherkunft` sagt „von Hand eingetragen".
    Daneben die Gegenrichtung: Nennt die Druckerei nur die Bogenbreite,
    folgt die Rückenstärke daraus (`Druckvorgabe.rueckenAusBogen`) — Format
    und Anschnitt stehen ja fest.
  - **Passt die Bogenbreite gar nicht, ist das der wichtigere Befund.**
    Bleibt nach Abzug zweier Seiten und des Anschnitts nichts übrig, wird
    keine Rückenstärke geraten, sondern gesagt, dass das SEITENFORMAT nicht
    zu der Angabe passt.
  - **Die bestellte Seitenzahl ist eine Zahl, die nur der Mensch kennt**
    (`Reise.bestellteSeiten`, ab 1.0.72). Zweiter Punkt derselben Mail: „Sie
    haben ein Produkt mit 60 Innenseiten bestellt, uns allerdings zu viele
    Seiten für den Innenteil zugeschickt." Die App zählt die Seiten längst;
    was fehlte, ist die Zahl daneben. Eingetragen wird sie im Ausgabeblatt,
    geprüft wird sie dort und in der Druckprüfung — **vor dem Hochladen
    statt in der Antwortmail zwei Tage später**. Ohne eingetragene
    Bestellung wird NICHTS behauptet: Eine Warnung über eine Seitenzahl, die
    niemand bestellt hat, ist keine Auskunft.
  - **Die Innenseiten des Umschlags, U2 und U3** (`Umschlag.innenseitenBogen`,
    ab 1.0.72). Dritter Punkt derselben Mail: „Bitte legen Sie für die
    Aussenseiten (U4+U1) und die Innenseiten (U2+U3) des Umschlags jeweils
    eine Doppelseite im Format 428 mm x 303 mm an." Bis 1.0.71 gab es davon
    nur die Außenseite — die Doppelseitenansicht schreibt an die
    Innenseiten sogar „Kommt von der Druckerei — nicht im PDF", und für ein
    gebundenes Hardcover mit Vorsatzpapier stimmt das auch. **Diese
    Druckerei will sie geliefert bekommen**, und ohne sie nimmt sie den
    Auftrag nicht an. Die Umschlagdatei bekommt deshalb auf Wunsch eine
    ZWEITE Seite in denselben Maßen und mit denselben Boxen, NACH der
    Außenseite: Umgeschlagen liegt außen zuerst, und eine Datei, deren
    Reihenfolge man erklären muss, ist eine Fehlerquelle.
  - **Geliefert wird eine FLÄCHE, kein Satz** — eine Farbe, `nil` heißt
    Papier. Kein Rücken (der Rückentext gehört auf die Außenseite; ihn hier
    noch einmal zu setzen hieße, ihn im fertigen Buch zweimal zu haben,
    einmal davon unsichtbar zwischen Deckel und erster Seite) und **keine
    Blöcke**: Etwas anzubieten, das nach Gestaltung aussieht und keine
    trägt, wäre der schlechtere Anfang. Und bewusst nicht der Hintergrund
    des Umschlags — der ist meist ein Foto, und dasselbe Foto auf der
    Innenseite noch einmal ist keine Gestaltung, sondern ein Versehen, das
    erst im gebundenen Buch auffällt.
- **Nicht gemessen (1.0.72):** Keine Datei ist damit hochgeladen worden.
  **GERECHNET und an der Mail der Druckerei nachgerechnet** sind beide
  Maße — 216 × 303 für die Innenseiten, 428 × 303 für den Umschlag —, und
  sie gehen auf den Millimeter auf. **Ungeprüft bleibt, WARUM die erste
  Lieferung abgewiesen wurde**: Dass die Rechnung stimmt, heißt nicht, dass
  die Einstellungen dieses Buches stimmten; die wahrscheinlichsten
  Kandidaten sind A4 **quer** statt hoch (das war bis 1.0.26 die Vorgabe
  dieser App und steht in `init(from:)` bis heute als Rückfall), ein anderer
  Anschnitt und eine gerechnete Rückenstärke von rund 8 mm statt der
  verlangten 2. **Genau deshalb schreibt die App die Zahlen jetzt hin,
  statt sie zu behaupten** — die Zeile „Bogen im PDF" ist die, die sich
  gegen die Bestellung halten lässt. Ebenso ungeprüft: ob diese Druckerei
  die U2/U3-Fläche so annimmt und ob sie die beiden Umschlagbogen in EINER
  Datei erwartet oder in zweien — die Mail sagt dazu nichts. **Nichts davon
  als erledigt darstellen.**
- **EIN BUCH KOMMT ÜBER iCLOUD AN, BEVOR SEINE BILDER DA SIND**
  (`Dienste/Wolkenbilder.swift`, ab 1.0.71; gemeldet 09/2026: „Auf dem iPad
  ist kein Arbeiten möglich. Vielleicht liegt es daran, dass ich das Projekt
  insgesamt auf einem anderen Gerät erstellt und verarbeitet habe."). **Der
  Verdacht des Nutzers trifft, und die Stelle lässt sich am Quelltext
  abzählen — es sind zwei Fehler übereinander:**
  - **`Wolke.herunterladenAnstossen` sah nur die OBERSTE Ebene.** Es lief
    über `Reisen/` und stieß dort an, was nicht `.current` war — also die
    JSON-Dateien und die Ordner. Die Bilder liegen zwei Ebenen tiefer, in
    `Reisen/<Kennung>/Bilder/`; **nach keiner einzigen Bilddatei wurde je
    gefragt.** Ein Buch vom anderen Gerät ist damit binnen Sekunden lesbar
    (die JSON-Datei ist klein) und hat trotzdem keines seiner zweihundert
    Bilder. Angestoßen wird jetzt für das OFFENE Buch, nicht für alle: Fünf
    Bücher zu je zweihundert Bildern auf einmal sind genau der Schwall, dem
    iCloud Drive aus dem Weg gehen soll — und genau deshalb steht es dort
    und nicht im alten Lauf.
  - **Ein Bild, das nicht da war, wurde bei JEDEM Bildpunkt neu gesucht.**
    `Bildarchiv.vorschau` gab `nil` zurück, und ein `nil` wurde nirgends
    gemerkt — der Vorrat hält nur Treffer. Aufgerufen wird es aber im KÖRPER
    einer SwiftUI-Ansicht, also bei jeder Neuzeichnung der Bühne, und die
    läuft beim Schieben und Zoomen im Sekundentakt und öfter. Bei einem
    Buch, dessen Bilder in der Wolke liegen, war das je Seite und Bildpunkt
    ein vergeblicher Griff auf das Dateisystem, auf dem HAUPTFADEN. **Das
    ist die Form, in der sich „kein Arbeiten möglich" erklärt: Nicht eine
    Rechnung ist zu teuer, sondern dieselbe vergebliche Suche läuft
    hundertfach.**
  - **Der Fehlgriff wird mit seiner ZEIT gemerkt, nicht bloß weggeworfen**
    (`Bildarchiv.fehlgriffe`, `wartezeit` 3 s). Ein Merker ohne Ablauf wäre
    der bequemere Weg und der falsche — er zeigte ein heruntergeladenes Bild
    erst nach einem Neustart. So steht ein ankommendes Bild von selbst
    binnen drei Sekunden auf der Seite, und „Jetzt holen" räumt den Merker
    sofort weg: Ein Knopf, der nichts tut, weil eine Sperre noch läuft, ist
    für den Menschen davor ein kaputter Knopf.
  - **„Liegt noch in iCloud" und „ist weg" sind NICHT dasselbe.** Das eine
    löst sich von selbst, das andere nie; beides als graue Fläche zu zeigen
    lässt den Menschen davor raten — dieselbe Regel wie beim Wort „Plan" in
    der Abfahrtstafel. Das Band über der Bühne zählt beides getrennt, rot
    nur für das, was wirklich fehlt.
  - **Wie ein nicht heruntergeladenes Bild AUSSIEHT, ist von hier aus nicht
    zu messen** — geprüft werden deshalb BEIDE bekannten Gestalten: der
    Platzhalter `.<Name>.icloud` und `isUbiquitousItem` am Namen selbst. Nur
    eine zu fragen hieße, sich auf eine Darstellung zu verlassen, die Apple
    zwischen zwei Fassungen ändern darf; der Preis wäre, dass ein Bild, das
    gleich ankommt, als „fehlt ganz" gemeldet würde.
  - **Das Nachsehen läuft abseits des Hauptfadens und hört von selbst auf.**
    Zweihundert Abfragen an das Dateisystem, über iCloud jede mit Wartezeit;
    zurück kommt nur die Zahl. Wiederholt wird, solange etwas LÄDT — ein
    Band, dessen Zahl nicht kleiner wird, sieht aus wie ein Fehler, und ein
    Lauf, der ewig weiterzählt, ist einer.
  - **Die WASSERZEICHEN gehören dazu** (`Wolkenbilder.dateien`). Sie stehen
    in keiner Fotoliste und liegen im selben Ordner — wer sie vergisst,
    stößt sie nie an, und eines liegt auf JEDER Seite. Dieselbe Überlegung
    wie in `Buchdatei.schreiben`. **Wer eine neue Bildart anlegt, trägt sie
    dort ein.**
- **Nicht gemessen (1.0.71):** Auf einem Gerät gesehen hat das niemand.
  **Am Quelltext ABGEZÄHLT ist die Ursache**, und sie passt zu dem, was der
  Nutzer beschreibt. **Dass das iPad danach flüssig ist, folgt daraus
  NICHT**: Es kann eine zweite Ursache darüberliegen — bei der fehlenden
  Umschlagabbildung in 1.0.67/1.0.68 war genau das der Fall, und die
  sichtbare war die harmlosere. Weiterhin ungemessen sind die beiden
  offenen Punkte, die schon dastanden: dass `Bildarchiv.vorschau` auch bei
  vorhandenen Bildern SYNCHRON auf dem Hauptfaden liest (offen seit 1.0.59)
  und dass die Bühne seit 1.0.28 das GANZE Buch trägt. **Genau deshalb nennt
  der Befund unter „Bedienung prüfen" seit 1.0.71 vier Zahlen statt einer
  Zusage** — gesamt, auf dem Gerät, in iCloud, fehlen, dazu wie viele Namen
  gerade als nicht lesbar gemerkt sind. **Nicht als erledigt darstellen** —
  der nächste Befund des Nutzers ist hier die Messung.
- **ZWEI BUCHSEITEN AUF EINE PDF-SEITE, LINKS DIE GERADE**
  (`Buchausgabe.doppelseitenPdf`, ab 1.0.69; Ansage des Nutzers 09/2026:
  „Offenbar will Saal Digital ein Upload eines PDF mit fertig gestalteten
  Doppelseiten. … dass nun immer zwei Seiten, angefangen mit einer geraden
  Seite, zusammen auf ein PDF-Seite gebracht werden, die dann die doppelte
  Breite hat. Also wenn eine Seite hochkant 21 mal 28 cm wäre, müsste die
  Doppelseite 42 x 28 cm sein.“).
  - **Die Paarung wird NICHT nachgebaut.** Links die gerade Nummer, rechts die
    ungerade — das ist dieselbe Buchbinderei, die seit 1.0.47 in `Bogenlage`
    steht und nach der die Doppelseitenansicht auf dem Bildschirm paart.
    Gefragt werden genau die beiden Angaben, die je eine Stelle haben:
    `Buchseite.bogennummer` und `Buchseite.liegtRechts`. Eine zweite Zählung
    daneben ergäbe eine Datei, die anders paart als die Vorschau — und das
    sähe man erst im gebundenen Buch (dieselbe Lehre wie 1.0.52, wo drei
    Stellen die Nummerierung nachbauten).
  - **Der erste und der letzte Bogen sind HALB, und das ist richtig so.**
    Seite 1 ist ein Recto und hat links von sich die Innenseite des Umschlags;
    die kommt von der Druckerei und steht in keinem PDF. Ausgegeben werden sie
    trotzdem, sonst fehlten Seite 1 und die letzte. **Die leere Hälfte wird
    GEZÄHLT und hingeschrieben** (`doppelseitenbefund`): Ein halber Bogen sieht
    wie ein Fehler aus, wenn niemand ihn benennt.
  - **Der Anschnitt liegt ringsum AUSSEN, am Bund keiner.** Dort stoßen die
    beiden Hälften aneinander; ein randabfallendes Bild liefe sonst über die
    Nachbarseite. Dieselbe Rechnung wie beim Umschlagbogen — und deshalb
    dieselbe Funktion: `zeichneUmschlagseite` heißt seit 1.0.69
    `zeichneBogenhaelfte` und nimmt `ohneGrund` entgegen. Der Unterschied ist
    keine Einstellung, sondern die Sache: Der UMSCHLAG hat EINEN Grund über den
    ganzen Bogen (samt Rücken), eine DOPPELSEITE besteht aus zwei Buchseiten mit
    je eigenem Hintergrund — und läuft eines über beide, rechnet
    `Bogenlage.bildflaeche` in jeder Hälfte ihre Portion aus.
  - **TrimBox über den GANZEN Bogen**, nicht je Hälfte: Geschnitten wird außen,
    in der Mitte wird gebunden. Eine Schnittmarke am Bund wäre die Anweisung,
    das Buch in der Mitte zu zerteilen — dieselbe Überlegung wie beim Umschlag
    (1.0.50) und bei der Broschüre (1.0.27).
  - **Nur der Buchblock** (`teil == .innen`). Der Umschlag ist ein eigenes Stück
    Papier mit eigener Breite und eigenem Rücken und wird mit „Nur den
    Umschlag“ einzeln ausgegeben. Gibt es keinen Umschlagbogen, ist die
    Titelseite die gewöhnliche Seite 1 und damit von selbst dabei.
  - **Eigener Menüpunkt „Doppelseiten ausgeben…“**, nicht nur eine Zeile im
    Picker — der Picker im Ausgabeblatt ist der Ort, an dem in 1.0.52 zehn
    Fassungen lang etwas stand, das niemand fand.
  - **Nicht gemessen (1.0.69):** Keine Datei ist damit hochgeladen worden.
    Gerechnet ist die Geometrie (zwei Endformate nebeneinander, Anschnitt nur
    außen) und die Paarung; **ob Saal Digital genau diese Anordnung erwartet,
    ist NICHT geprüft** — gebaut ist, was der Nutzer beschrieben hat (links die
    gerade Zahl), und die Befundzeile nennt Zahl und Maß der Bogen, damit sich
    das gegen die Vorgabe des Dienstes halten lässt. **Nicht als erledigt
    darstellen.**
- **OHNE `UIGraphicsPushContext` ZEICHNET `UIImage.draw` IN NICHTS — STILL**
  (`Seitensatz.mitUIKit`, ab 1.0.68; derselbe Befund zum zweiten Mal gemeldet,
  09/2026: „Das Bild ist leider wieder nicht mitgekommen.“, dazu ein
  Bildschirmfoto mit weißem Bogen, Titel und Rückentext). **Das ist die
  wirkliche Ursache, und 1.0.67 hat sie nicht berührt.**
  - **`UIImage.draw(in:)`, `UIBezierPath.fill()`, `.stroke()` und `.addClip()`
    fragen NICHT den `CGContext`, den man ihnen daneben hinstellt.** Sie
    zeichnen in den Kontext, der oben auf UIKits eigenem Stapel liegt
    (`UIGraphicsGetCurrentContext`). Liegt dort keiner, tun sie schlicht
    NICHTS — kein Fehler, keine Warnung, kein Absturz.
  - **`umschlagPdf` war der einzige der drei Ausgabewege ohne
    `UIGraphicsPushContext`.** Die Seiten-PDF hatte es seit jeher, die
    Broschüre auch; der Umschlagbogen schiebt seinen eigenen Zeichenblock und
    bekam es beim Bau in 1.0.50 nie. Damit fehlten dort ALLE Bilder:
    Hintergrundfoto, Fotoblöcke, Karten, Wasserzeichen — und zusätzlich jede
    gerundete Fläche und jeder Schatten (`UIBezierPath.fill`). Was ankam, waren
    Text (CoreText zeichnet direkt in den `CGContext`) und Farbflächen
    (`CGContext.fill`). Genau dieses Muster zeigt das Bildschirmfoto.
  - **Das Pushen gehört DORTHIN, wo UIKit zeichnet, nicht an die
    Aufrufstelle.** An drei Aufrufstellen gepflegt, fehlte es an der vierten,
    und aufgefallen ist es erst an der ausgegebenen Datei. Seit 1.0.68 steht es
    in `Seitensatz.mitUIKit`, und die sechs betroffenen Funktionen legen ihren
    Zeichenteil hinein (`zeichneBild`, `zeichneSchatten`, `zeichneFlaeche`,
    `zeichneHintergrund`, `zeichneWasserzeichen`, `zeichneRahmen`). Die beiden
    Paare in `Buchausgabe` sind dafür ersatzlos raus — zwei Stellen für
    dieselbe Sache wären wieder eine, die jemand vergisst. Der Stapel ist
    schachtelbar; dass der Bildschirm (in `draw(_:)` einer `UIView`) denselben
    Kontext ein zweites Mal pusht, ist harmlos.
  - **Eine Ursache, die sich am Quelltext abzählen lässt, ist damit noch nicht
    DIE Ursache.** 1.0.67 hat das Übermalen des Bogengrundes durch die beiden
    Hälften abgestellt — richtig, nachgerechnet und wirkungslos: Das Bild wurde
    nie gezeichnet. **Hier lagen zwei Fehler übereinander, und der sichtbare war
    der harmlosere.** Wer den ersten findet, prüft, ob er den BEFUND erklärt,
    und nicht nur, ob er ein Fehler ist.
- **Was in der Datei steht, wird GEZÄHLT** (`Druckpruefung.bilderImPdf`, ab
  1.0.68). Seitenzahl und Maße konnten „ein Panorama“ und „weißes Papier mit
  einer Zeile Text“ nicht unterscheiden — beide Meldungen betrafen eine Datei,
  die von außen tadellos aussah, und die Prüfung sagte zweimal „geschrieben und
  lesbar“. Gezählt werden jetzt die Bild-XObjects der Seiten; null davon steht
  als Warnung da, mit dem Zusatz, dass es bei einem reinen Textbogen richtig
  ist. **Ein Bild in einem Form-XObject sähe die Zählung nicht** — diese App
  legt keines an, und das steht dort, statt es zu verschweigen.
- **Nicht gemessen (1.0.68):** Keine Datei ist damit ausgegeben worden.
  Am Quelltext ABGEZÄHLT ist die Ursache (der eine fehlende Push, und dass
  genau die UIKit-Aufrufe betroffen sind, deren Ausfall das Bildschirmfoto
  zeigt) — gesehen hat es niemand. **Ungeprüft ist auch die neue Zählung
  selbst**: ob `CGPDFDictionaryApplyFunction` in diesem Aufbau die XObjects
  wirklich findet, sagt erst die Zeile am Gerät. **Nicht als erledigt
  darstellen** — nach zwei Fassungen an derselben Meldung ist der nächste
  Befund des Nutzers hier die Messung, und seit 1.0.68 nennt er eine Zahl.
- **DER UMSCHLAGGRUND WURDE GEZEICHNET UND DANACH ZWEIMAL ÜBERMALT**
  (`Buchausgabe.zeichneSeite(…ohneGrund:)`, ab 1.0.67; gemeldet 09/2026:
  „Der Export hat leider beim Umschlag PDF nicht das Bild mitgenommen.").
  **Am Quelltext abzuzählen und keine Vermutung:** `umschlagPdf` legt seit
  1.0.50 den Grund über den GANZEN Bogen — und rief danach für jede Hälfte
  `zeichneSeite`, die ihren Seitengrund BEDINGUNGSLOS noch einmal zeichnete,
  diesmal in die halbe Fläche. Ein einfarbiger Seitengrund übermalte das
  Bogenbild damit vollständig (stehen blieb nur der Streifen im Rücken, der
  danach gezeichnet wird), ein Fotogrund wurde ZWEIMAL eingepasst — mit
  einem Zoom und einem Versatz, die für den Bogen gerechnet wurden und auf
  einer halben Fläche etwas ganz anderes treffen.
  - **1.0.63 hat den Bildschirm gerichtet und das PDF stehen lassen.** Dort
    heißt es seither „Der Umschlag hatte zwei Fassungen, und sie zeigten
    Verschiedenes"; die Hälften lassen ihren Grund über
    `SeitenflaecheView.ohneGrund` weg. Dieselbe Zeile fehlte im PDF.
    **Wer eine Doppelung auflöst, sucht nach jeder Stelle, die sie hat** —
    hier waren es zwei, und nur eine wurde behoben.
  - **Geprüft wird VOR dem Laden.** Ein Hintergrundfoto wird in voller
    Ausgabegüte von der Platte geholt; für eine Umschlaghälfte wäre das ein
    ganzes Bild umsonst.
  - **Und weil die Ursache gerechnet und nicht gesehen ist, MISST die App**
    (`Druckpruefung.umschlaggrund`, Zeile „Grund des Umschlags" vor dem
    Ausgeben): welcher Grund gilt (Umschlag oder Buch), welche Datei
    dahintersteht, ob sie sich überhaupt öffnen lässt, dazu Ausschnitt und
    Schleier. Eine zweite Ursache lässt sich von hier aus nicht
    ausschließen — dasselbe Muster wie Schulalarms Stufenprobe.
- **NUR DER UMSCHLAG, NUR DER INNENTEIL** (`Umfang.nurUmschlag`,
  `.nurInnenteil`, ab 1.0.67; Ansage des Nutzers 09/2026: „damit ich jetzt
  nicht wieder beide Teile exportieren muss, denn das PDF für das
  eigentliche Buch ist mittlerweile knapp 4 GB groß"). Ein Umschlagbogen ist
  in Sekunden gesetzt, der Innenteil eines vollen Buches wiegt Gigabyte und
  braucht seine Zeit. **Gebaut wird dafür KEIN zweiter Weg:** Es sind
  dieselben zwei Aufträge, die `getrennt` nacheinander stellt — hier einzeln.
  Dazu ein eigener Menüpunkt „Nur den Umschlag…" neben „Umschlag und
  Innenteil getrennt…": Der Picker im Blatt ist genau der Ort, an dem in
  1.0.52 zehn Fassungen lang etwas stand, das niemand fand.
- **DER TITEL LÄSST SICH VERSCHIEBEN — mit einem Regler und nicht mit dem
  Finger** (`Umschlag.titellage`, ab 1.0.67; gemeldet 09/2026: „Die Schrift
  auf der Titelseite ragt ziemlich tief in den dunklen Bereich des Bildes …
  Ich würde sie gerne auf der Seite verschieben, erkenne aber nicht, wie das
  gehen könnte."). Er hat es nicht gefunden, weil es das nicht gab:
  Titelseite und Rückseite werden bei jedem Durchgang GERECHNET, und ein
  dort hineingeschobener Block wäre beim nächsten Durchgang weg — das steht
  seit 1.0.50 hier. Verschoben wird deshalb nicht der Block, sondern die
  RECHNUNG: ein Anteil in der Höhe des Satzspiegels (0 = oben, 1 = unten),
  Regler unter Umschlag → „Gestaltung des Umschlags".
  - **`nil` heißt „wie gerechnet" und ist etwas anderes als 0,5.** Die
    schlichte Titelseite setzt den Titel in die MITTE, die mit Titelfoto ein
    Feld UNTEN; ein fester Vorgabewert hätte eine der beiden beim Update
    still verschoben. Dieselbe Regel wie bei `Schriftabweichung` und
    `Block.wirkung` — eine Abweichung ist keine Kopie. Aufgelöst wird sie an
    EINER Stelle (`geltendeTitellage(mitTitelfoto:)`), gefragt vom
    Layoutautomaten UND vom Regler: Zwei Fassungen ergäben einen Regler, der
    etwas anderes anzeigt, als die Seite tut.
  - **Nur senkrecht.** Waagerecht nimmt der Titel ohnehin die ganze
    Satzbreite ein (schlicht) bzw. steht in einem Feld am linken Rand — dort
    gibt es nichts zu verschieben, was nicht die Breite wäre. Das sagt die
    Fußzeile auch, statt einen Regler anzubieten, der nichts tut.
- **Nicht gemessen (1.0.67):** Kein Umschlag ist damit ausgegeben worden.
  Gerechnet und am Quelltext abgezählt ist die URSACHE des fehlenden
  Bildes — dass die Hälften den Bogengrund übermalten — und die Geometrie
  der Titellage (bei Anteil 0,5 bzw. 1 steht auf den Punkt dieselbe Zeile
  wie bis 1.0.66). **Ungeprüft bleibt, ob das der gemeldete Fehler WAR:**
  Eine zweite Ursache lässt sich von hier aus nicht ausschließen, und genau
  deshalb nennt die neue Befundzeile Zahlen statt einer Zusage. **Nicht als
  erledigt darstellen** — der nächste Umschlag-Export des Nutzers ist hier
  die Messung.
- **DAS SCHRIFTENRECHT STEHT WIEDER IN DER ENTITLEMENTS-DATEI — DIESMAL
  GEMESSEN** (`Config/Urlaubstagebuch.entitlements`, ab 1.0.66; Befund des
  Nutzers aus „Schriften prüfen", 23.09.2026). Die Probe aus 1.0.45 hat
  geliefert, wofür sie gebaut war: Profil „iOS Team Provisioning Profile:
  de.familie.urlaubstagebuch", elf bewilligte Rechte, darunter
  **`com.apple.developer.user-fonts` als `["app-usage",
  "system-installation"]`**. Genau diese Zeichenkette steht jetzt dort, Wort
  für Wort.
  - **`app-usage` ist der Wert hinter Xcodes Haken „Use Installed Fonts"** —
    also der, den 1.0.44 mit `system-installed-fonts` zu erraten versuchte
    und an dem das ganze Projekt unsignierbar wurde. Die Regel von damals
    („wer eine Zeichenkette in eine Entitlements-Datei schreibt, die er nicht
    nachschlagen kann, rät") hat also nicht bloß Schaden verhütet, sie hat
    die richtige Antwort geliefert — nur eben von einem Gerät und nicht von
    hier.
  - **`system-installation` steht mit drin, obwohl die App es nicht
    braucht.** Sie installiert keine Schriften. Eine TEILMENGE der
    bewilligten Werte ist aber nicht gemessen, und der Fehlertext von 1.0.44
    sprach ausdrücklich vom „value" des Rechts. Hier wird nicht zum zweiten
    Mal geraten, auch nicht in die vorsichtige Richtung. **Wer es enger
    haben will, nimmt in Xcode die Fähigkeit weg und meldet, was das Profil
    danach sagt.**
  - **NUR in die iOS-Datei.** `Config/Urlaubstagebuch-Mac.entitlements` ist
    unangetastet: Der Mac-Bau hat ein eigenes Profil, und ein Recht, das
    dieses nicht trägt, macht genau dort dasselbe kaputt wie 1.0.44 auf iOS.
  - **NICHT GEMESSEN — und das ist die wichtigere Hälfte des Befundes.** Im
    selben Bericht meldete `CTFontManagerCopyRegisteredFontDescriptors`
    **null** Einträge, und jede Anmeldung endete mit „Die
    Schriftregistrierung ist fehlgeschlagen." Der Eintrag ins Repo ist der
    belegte erste Schritt, kein Beweis; ob die Abfrage danach etwas hergibt,
    sagt erst der nächste Befund. Und ein grüner Bau in GitHub Actions sagt
    dazu gar nichts (`CODE_SIGNING_ALLOWED=NO`).
- **DER WÄHLER IST EIN EIGENER PROZESS — deshalb geht er, während die
  Abfrage leer bleibt** (ab 1.0.66). Derselbe Befund enthielt einen
  scheinbaren Widerspruch: null gemeldete Einträge, aber drei über den
  Wähler gewählte Schriften (Quicksand Regular, Quicksand Medium, Poppins
  Regular), alle drei **auffindbar**. `UIFontPickerViewController` läuft
  außerhalb der App — wie der Fotowähler, und aus demselben Grund darf er
  ohne Erlaubnis arbeiten. Was er zeigt, sagt über das, was DIESER Prozess
  aufzählen darf, nichts. **Merke: Ein Befund über den einen Weg ist kein
  Befund über den anderen** — 1.0.44 hatte genau daraus („im Wähler fehlen
  sie") auf das Recht geschlossen, und das war damals richtig; als Regel
  wäre es falsch.
- **WAS EIN FEHLER HEISST, STEHT IN SEINER ZAHL** (`Geraeteschriften.fehlernamen`,
  ab 1.0.66). Neunmal derselbe Satz im Protokoll — „Die Schriftregistrierung
  ist fehlgeschlagen" —, und dieselben Schriften danach auffindbar. Das ist
  der allgemeine Text von CoreText und sagt über die Ursache nichts;
  wahrscheinlich heißt er „steht schon" (Code 105). Gemeldet werden seither
  Domäne, Code und, wo die Zahl bekannt ist, ihr Name; was nicht in der
  Tabelle steht, bleibt eine nackte Zahl und wird nicht gedeutet. Dieselbe
  Regel wie bei Schulalarms `rohAbfrage`: **Ein aufgeräumter Satz ist für
  die Person, die es richten muss, weniger wert als der rohe Befund.** Die
  Tabelle nennt Zahlen und keine `CTFontManagerError`-Fälle — die Zahlen
  stehen in Apples Papier, die Swift-Namen sind schon gewandert.
- **Eine Probe, die nach dem Messen dieselbe Vermutung wiederholt, ist die
  Frage von vorhin noch einmal** (ab 1.0.66). Bis 1.0.65 sagte der Befund
  bei leerer Liste immer „Erster Verdacht: das Recht" — auch dann, wenn die
  Zeile zwei Absätze darüber es als bewilligt auswies. Jetzt hängt der Satz
  davon ab: bewilligt → der nächste Verdacht ist, ob diese FASSUNG es
  verlangt; nicht bewilligt → es liegt an der App-Id; kein Profil lesbar →
  es lässt sich nichts sagen. Dasselbe in der Schriftwahl (drei Fälle statt
  zwei) und im Protokoll, wo „Nichts anzumelden" jetzt dazusagt, ob es der
  gute Fall war (alles schon auffindbar) oder der leere.
- **AUSSCHNEIDEN, KOPIEREN, EINFÜGEN — WEIL DAS MENÜ DIE ZIELSEITE NICHT
  AUFZÄHLEN KANN** (`Reisewerk.Ablageinhalt`, `blockAusschneiden`,
  `blockInDieAblage`, `einfuegenGrund`, `blockEinfuegen`, ab 1.0.65; Befund
  des Nutzers 09/2026: „Im Moment ist es so, dass ich zum Beispiel ein Foto
  nur auf eine Seite verschieben kann, die nach der aktuellen Seite neu
  angelegt wird. Etwas anderes steht mir offenbar nicht zur Verfügung. Ich
  würde es begrüßen, wenn ich dort einen ganz normalen Dialog bekommen
  würde, so wie er in jeder App gültig ist. Ausschneiden, kopieren,
  einfügen.").
  **Er hat recht, und es ist am Quelltext abzuzählen:** `verschiebenAbschnitt`
  und `kopierenAbschnitt` rechnen beide mit `seitenlage`, also mit den Seiten
  DIESES Tages. Ein Tag mit EINER Seite lässt davon „eine Seite zurück"
  (ausgegraut, `jetzt == 0`), „eine Seite vor" (fehlt, `jetzt+1 == anzahl`)
  und „auf Seite …" (fehlt, `anzahl <= 2`) wegfallen — übrig bleibt genau
  der eine Eintrag, den er beschreibt. Auf seinem Bildschirmfoto ist das
  Punkt für Punkt zu sehen.
  - **Die Ablage nimmt die Zielseite aus dem Menü heraus.** Eingefügt wird
    auf die GEWÄHLTE Seite (`einsetzbareSeite`), und die wählt man auf der
    Bühne mit einem Tipp — seit 1.0.61 ist sie dort sichtbar umrandet.
    Damit geht es über Seiten-, Tages- und Umschlagsgrenzen hinweg, ohne
    dass ein Menü jede mögliche Zielseite aufzählen müsste. Die beiden
    alten Abschnitte bleiben: Sie sind die Abkürzung für den Nachbarn.
  - **Die Ablage hält eine KOPIE, keinen Verweis**, und jedes Einfügen
    vergibt eine NEUE Kennung — auch beim ausgeschnittenen Block. Zwei
    Blöcke mit derselben Kennung sind für jede Suche einer (`block(_:)`
    fände immer nur den ersten); dieselbe Lehre wie bei `blockKopieren` und
    bei Tafelbild 1.4.5. Nebenwirkung mit Absicht: Zweimal einfügen ergibt
    zwei Blöcke.
  - **Ein FOTO wechselt beim Einfügen den Tag** (`fotoDemTagZuordnen`).
    `tag.fotos` sagt, wem ein Foto gehört; ohne diesen Schritt stünde es
    weiter in der Fotoliste des alten Tages und käme beim nächsten
    Neuanordnen dort wieder auf eine Seite. Aus dem alten Tag genommen wird
    es nur, wenn es dort in KEINEM Block mehr steht — seit `blockKopieren`
    darf dasselbe Foto zweimal im Buch stehen. Eine GRAFIK (seit 1.0.61)
    bleibt außen vor: Sie gehört keinem Tag.
  - **Ein TAGEBUCHTEXT verlässt seinen Tag NICHT** (`einfuegenGrund`).
    `Neuverteilung.fliesstexte` schreibt ihn beim Neuverteilen dorthin
    zurück, wo sein Block liegt; in einem fremden Tag stünde er danach im
    falschen Tagebuchtext, und zwar still. Dasselbe gilt für Überschrift,
    Datumszeile und Bildunterschrift — deren Text steht am Tag bzw. am
    Foto. Und eine KARTE kommt nicht auf den Umschlag; dort gibt es keinen
    Tag. Beides steht als SATZ da und nicht als fehlender Eintrag: Hier
    weiß man, warum es nicht geht, und ein weggelassener Knopf ließe einen
    raten, ob die Ablage leer ist oder das Ziel nicht passt.
  - **Der Rahmen wird auf den Satzspiegel der ZIELfläche geklemmt**
    (`inSatz`). Ein Block vom Umschlag ist breiter als eine Buchseite; ohne
    das Klemmen läge er dort halb im Anschnitt.
  - **Der Einfügeknopf steht in der FUSSLEISTE**, nicht nur im Menü. Wer
    gerade ausgeschnitten hat, hat keinen Block mehr gewählt — dann ist das
    Blockmenü weg, und im Plus-Menü müsste man den Eintrag erst suchen.
    Dieselbe Lehre wie beim Gruppenchat in Schulalarm und beim
    Sichtumschalter der Abfahrtstafel.
- **EIN BILD AUS DER MEDIATHEK GEHT AUCH OHNE DATUM** (`BildAusFotosView`,
  ab 1.0.65; Ansage des Nutzers 09/2026: „Nachdem dies geschehen ist, möchte
  ich über das Plusmenü aber auch Fotos auswählen können, egal ob von
  Dateien oder aus der Fotomediathek, die dann einfach auf der Seite
  eingefügt werden, egal welchen Zeitstempel sie haben."). Den Weg über
  DATEIEN gibt es seit 1.0.61 (`GrafikEinfuehrView`); aus der MEDIATHEK
  führte bis 1.0.64 jeder Weg durch die Fotoeinfuhr — also durch Datum, Ort,
  Tageszuordnung und einen Bericht darüber, was fehlt. Für ein Bild, das
  einfach auf einer Seite liegen soll, ist das alles keine Auskunft, sondern
  Lärm; genau dieser Befund hat 1.0.61 ausgelöst („1 Fotos tragen keinen Ort
  … 1 Fotos tragen kein Datum"), und er galt für die Mediathek weiter.
  **Es ist derselbe Wähler wie in der Fotoeinfuhr und dieselbe Funktion
  dahinter** (`grafikEinfuegen`) — zwei Fassungen desselben Einsetzens
  liefen auseinander. Das Bild gilt danach als `grafik`: keine Fotoliste,
  kein Punkt auf der Karte, kein Eintrag in „Fotos ohne Tag". Der Eintrag
  „Bild oder Grafik…" heißt seither „Bild aus Dateien…", damit die beiden
  Wege nebeneinander sagen, woher sie holen.
- **`loadDataRepresentation` DARF SEINEN RÜCKRUF MEHRMALS AUFRUFEN.** Ein
  zweites `resume` an einer `CheckedContinuation` ist kein Fehler, sondern
  ein Absturz — deshalb auch hier der Wächter `Einmal`, wie in der
  Zeitraumeinfuhr seit 1.0.30. **Wer eine zweite Stelle baut, die ein
  `itemProvider`-Ergebnis in `async` überführt, baut ihn mit.**
- **EIN INSPEKTOR MUSS LESBAR SEIN** (ab 1.0.65, gemeldet 09/2026 mit
  Bildschirmfoto: „Bei der Menüleiste, die sich herausschiebt, wenn ich den
  Pinsel drücke, ist die Transparenz zu groß eingestellt. Dort kann ich kaum
  etwas erkennen."). Eine `.inspector`-Spalte liegt auf iPadOS über dem
  Inhalt und bekommt von SwiftUI ein durchscheinendes Material. Über einer
  weißen Buchseite fällt das nicht auf; über einem randabfallenden Foto
  steht die Schrift im Bild — und genau dort steht sie IMMER, denn der
  Inspektor ist offen, WÄHREND man an einem Foto arbeitet. Zwei Zeilen
  zusammen, und keine reicht allein: `.scrollContentBackground(.hidden)` an
  JEDER `Form` darin (es sind zwei — die gefüllte und die leere) und
  darunter `.background(Color(uiColor: .systemGroupedBackground),
  ignoresSafeAreaEdges: .all)`. Ohne `ignoresSafeAreaEdges` bliebe oben und
  unten ein durchscheinender Streifen stehen.
- **Das Schriftenrecht trägt die App-Id inzwischen** (Ansage des Nutzers,
  09/2026, mit Bildschirmfoto aus Xcode: Capability „Fonts" bzw. „Font
  Enumeration", Haken bei „Use Installed Fonts" — „Es funktioniert nämlich
  mit dem Bild."). Damit ist der Grund weg, aus dem 1.0.45 das Recht wieder
  ausgebaut hat: Es fehlte an der App-Id, und ein Profil kann nur
  bewilligen, was die App-Id kann. **Ins Repo gehört es trotzdem erst,
  wenn die Zeichenkette NACHGESCHLAGEN ist und nicht geraten** — genau
  daran ist 1.0.44 gescheitert, und der Preis war nicht eine Funktion,
  sondern der ganze Bau. Nachzulesen ist sie an zwei Stellen auf dem Mac
  des Nutzers: in `Config/Urlaubstagebuch.entitlements`, die Xcode selbst
  geschrieben hat, und im Befund unter „Schriften prüfen", der seit 1.0.45
  die Rechte aus dem eingebetteten Profil liest. **Erst diese Zeichenkette
  wird eingetragen, nicht vorher.** — **Erledigt in 1.0.66**, siehe dort.
- **EIGENE FELDER AUF TITELSEITE UND RÜCKSEITE — SIE LIEGEN NEBEN DER
  GERECHNETEN SEITE, NICHT DARIN** (`Umschlag.titelbloecke`, `.rueckbloecke`,
  ab 1.0.64; Ansage des Nutzers 09/2026: „Es soll mir zum Beispiel auch
  möglich sein, dort eigene Felder oder Bilder zu positionieren."). Seit
  1.0.50 stand hier, ein Block auf dem Umschlag wäre beim nächsten
  Durchgang weg — und das stimmte: Titel- und Rückseite werden bei JEDEM
  Durchgang von `Layoutautomat.titelseite`/`.rueckseite` neu gesetzt, ein
  hineingeschriebener Block wäre beim nächsten Neuzeichnen verschwunden.
  Der Ausweg, den 1.0.50 nannte (beide Seiten zu echten `Seite`n in der
  Reise einzufrieren), ist bewusst NICHT gegangen worden: Dann hinge der
  Umschlag für immer an dem Stand, den er beim Einfrieren hatte — ein neuer
  Titel, ein anderes Titelfoto, ein anderer Stil schlügen nie mehr durch.
  - **Die eigenen Blöcke liegen deshalb DANEBEN**, als zwei Listen am
    `Umschlag`, und `Reise.seitenfolge(titelblatt:rueckblatt:)` hängt sie
    der gerechneten Seite an (`mitEigenen`). Der gerechnete Teil bleibt
    lebendig, die eigenen Felder überstehen jedes Neuanordnen, jeden
    Stilwechsel und jedes Neuverteilen — sie stehen ja in keinem Tag.
  - **Angehängt heißt OBEN.** Ein eigenes Feld auf einem randabfallenden
    Titelfoto wäre darunter unsichtbar. „Nach vorn holen" ist auf dem
    Umschlag deshalb schlicht das Ende der eigenen Liste.
  - **An EINER Stelle angehängt**, gefragt vom Bildschirm und vom PDF —
    beide holen ihre Seiten aus `seitenfolge`. Zwei Fassungen ergäben eine
    Vorschau, die anders aussieht als die Datei, und der Unterschied fiele
    erst beim Drucker auf.
  - **Der Merker des gemerkten Titelblatts darf sie NICHT kennen**
    (`Umschlag.satzmerkmal`). `Reisewerk` merkt sich die gesetzte Titel-
    und Rückseite, weil ihr Satz zwei CoreText-Messungen kostet; bis 1.0.63
    stand dafür der ganze Umschlag im Schlüssel. Ständen die Blöcke darin,
    setzte jeder Bildpunkt einer Ziehbewegung die Titelseite neu. Gerechnet
    wird das Merkmal über eine KOPIE ohne die beiden Listen und nicht über
    eine Aufzählung der übrigen Felder: Ein Feld, das jemand morgen
    hinzufügt, ist damit von selbst dabei.
  - **`block(_:)` findet sie weiterhin nicht — und das ist richtig.** Es
    gibt Tag, Seite und Stelle zurück; wer einen TAG braucht (Text teilen,
    auf eine andere Seite schieben, kopieren), kann mit einem Umschlagblock
    nichts anfangen. Genau diese Knöpfe erscheinen dort von selbst nicht.
    Alles, was nur den Block selbst betrifft — auswählen, schieben, ziehen,
    drehen, Text schreiben, nach vorn holen, entfernen —, geht seit 1.0.64
    zusätzlich durch `umschlagblock(_:)`; gelesen wird über `blockWert(_:)`,
    sonst bliebe der Inspektor bei einem angetippten Block leer.
  - **Eine KARTE wird dort nicht angeboten.** Sie zeichnet die Spur EINES
    Tages, und auf dem Umschlag gibt es keinen; was dort stünde, wäre ein
    leerer Rahmen mit dem Satz „Kartenbild fehlt". Dasselbe gilt für
    „Rest auf die nächste Seite": Die Fortsetzung bräuchte eine nächste
    Seite, und der Umschlag hat keine — deshalb sagt `teilbar` dort nein,
    und zwar im Werk und nicht in der Ansicht (gefragt wird an zwei
    Stellen).
  - **Mitgezogen an vier weiteren Stellen**, und jede davon wäre ein
    stiller Fehler gewesen: `Formatwechsel` rechnet die Rahmen mit (sonst
    säße nach A4 → A5 jedes Feld halb außerhalb), `fotoEntfernen` räumt
    Blöcke weg, deren Bild es nicht mehr gibt, `Druckpruefung`
    zählt abgeschnittenen Text auch dort, und `Buchdatei` nimmt die Bilder
    ohnehin mit, weil eine eingesetzte Grafik ein gewöhnliches `Foto` der
    Reise ist.
  - **Die AUSGLEICHSSEITE bleibt draußen.** Sie wird gerechnet, gehört
    keinem und hat keinen Ort, an dem etwas liegen bleiben könnte — dort
    wäre ein Block wirklich beim nächsten Durchgang weg.
  - **Nicht gemessen (1.0.65):** Nichts davon ist auf einem Gerät gesehen
  worden. Am Quelltext ABGEZÄHLT ist die Ursache des gemeldeten
  Verschiebe-Engpasses (beide Abschnitte rechnen mit `seitenlage`, und ein
  Tag mit einer Seite lässt davon einen Eintrag übrig) — und sie passt Punkt
  für Punkt zum Bildschirmfoto. **Ungeprüft ist die Abhilfe beim
  Inspektor**: Dass eine `.inspector`-Spalte ihr Material freigibt, sobald
  die `Form` ihren Hintergrund abgibt, ist die Lesart der Dokumentation und
  keine Messung; hilft es nicht, ist der nächste Griff `.presentationBackground`
  bzw. ein eigener `ZStack` um die Spalte. Ebenso ungesehen: ob die Mediathek
  die ECHTE Endung hergibt (bei einem bearbeiteten Foto liefert sie oft JPEG,
  auch wenn das Original ein PNG war) und wie sich das Umhängen eines Fotos
  in einen anderen Tag auf dessen Satz auswirkt — neu angeordnet wird dabei
  NICHTS, der Block bleibt, wo er eingefügt wurde. **Nicht als erledigt
  darstellen.**
- **Nicht gemessen (1.0.64):** Keine Seite ist damit gesehen worden.
    Gerechnet ist, WARUM ein Block in der gerechneten Seite verschwindet
    und warum er daneben stehen bleibt. **Gewählt und nicht gemessen** sind
    die Startmaße eines neuen Umschlagfeldes (60 % der Satzbreite,
    höchstens 280 pt, 90 pt hoch). **Und eigene Felder oder Bilder AUF DEM
    RÜCKEN gibt es weiterhin NICHT** — der Rücken ist ein rund zwölf
    Millimeter breiter Streifen mit eigener Geometrie und eigenem Weg ins
    PDF (`Rueckensatz`, `umschlagPdf`); ein Blockrahmen würde dort auf das
    Buchformat geklemmt und nicht auf die Rückenbreite. Er behält seine
    eine einstellbare Textzeile. **Nicht als erledigt darstellen.**
- **DER UMSCHLAG HATTE ZWEI FASSUNGEN, UND SIE ZEIGTEN VERSCHIEDENES**
  (`Model/Rueckensatz.swift`, ab 1.0.63; Befund des Nutzers 09/2026: „Im
  vorliegenden Beispiel hat es den Eindruck, dass der Buchrücken in einem
  dunklen Grau gestaltet ist … oder ganz einfach das Hintergrundbild von
  Deckblatt und Rückseite durchlaufen zu lassen."). Im PDF lief der Grund
  schon immer über den GANZEN Bogen samt Rücken (`umschlagPdf`); auf dem
  Bildschirm zeichnete jede Hälfte ihren eigenen, und dazwischen lag der
  Rücken als graue Fläche mit einer festen Bildschirmschrift. **Das ist die
  Trennung, die die erste Regel dieser App verbietet** — und sie war kein
  Wunsch des Nutzers, sondern ein Fehler.
  - **Ein Bild über den ganzen Bogen.** Die beiden Hälften lassen ihren
    Grund weg (`SeitenflaecheView.ohneGrund`) — und zwar auch das WEISSE
    Papier darunter, sonst deckte es genau das Bild ab, um das es geht.
  - **Eine Ungenauigkeit bleibt und steht dabei:** Die Ansicht zeigt beide
    Hälften mit eigenem Anschnitt, der gedruckte Umschlag ist innen um zwei
    Anschnitte schmaler (dieselbe Sache wie am Bund seit 1.0.58). Das Bild
    steht auf dem Bildschirm gut ein Prozent breiter als im Druck — eine
    Ungenauigkeit der ANSICHT, nicht der Datei.
  - **Lage und Leserichtung des Rückentextes sind einstellbar.** Die Lage
    ist ein ANTEIL (0 = Kopf, 1 = Fuß) und keine Millimeterzahl, damit sie
    einen Formatwechsel übersteht; in der Oberfläche steht sie in Worten.
  - **Verschieben geht nur mit einem Kasten, der SCHMALER ist als sein
    Platz.** Ein Kasten über die ganze Rückenlänge sähe mittig zentriert
    immer gleich aus, wie weit man den Regler auch schöbe — deshalb misst
    `Textmass.breite` seither die natürliche Breite eines Textes.
  - **Nicht gemessen:** Kein Umschlag ist gedruckt worden. Und die eigenen
    Felder oder Bilder AUF dem Rücken, um die ebenfalls gebeten wurde, gibt
    es noch NICHT: Der Umschlag wird gerechnet und nicht gesetzt, ein Block
    darauf wäre beim nächsten Durchgang weg (der Weg dahin steht seit 1.0.50
    hier). **Nicht als erledigt darstellen.** — Nachtrag: Für Titel- und
    Rückseite ist das seit 1.0.64 gelöst, und zwar anders als hier
    vermutet (die Blöcke liegen NEBEN der gerechneten Seite, nicht darin).
    Für den RÜCKEN gilt der Satz unverändert weiter.
- **DIE APP LÄUFT AUCH AUF DEM MAC — ALS MAC CATALYST** (ab 1.0.62, Ansage
  des Nutzers 09/2026: „Jetzt möchte ich tatsächlich doch noch die Option
  haben, das Ganze auf dem Mac nutzen zu können, und zwar als eigenständige
  Mac-App."). Ein Quelltext, ein Bundle, ein iCloud-Behälter — ein Buch vom
  iPad ist auf dem Mac dasselbe Buch.
  - **„Optimiert für Mac", nicht „auf iPad-Maß skaliert"**
    (`SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD = NO`). Die skalierte Fassung
    zeigt alles um knapp ein Viertel verkleinert; in einer App, in der man
    Millimeter setzt, ist das die falsche Wahl.
  - **ZWEI Rechte-Dateien, und das ist keine Formsache**
    (`CODE_SIGN_ENTITLEMENTS[sdk=macosx*]`). macOS verlangt den Sandkasten
    samt `files.user-selected.read-write`, `network.client`,
    `personal-information.photos-library` und `print`; iOS kennt diese
    Schlüssel gar nicht. Wer sie in die vorhandene Datei schreibt, macht die
    iOS-Fassung unsignierbar — **genau der Fehler aus 1.0.44**. Dieselbe
    Bauweise wie bei Schulalarm seit 1.0.18.
  - **Keines dieser Rechte ist eine Fähigkeit der App-Id.** Sandkasten-Rechte
    wertet das System aus, nicht das Profil; die Ausnahme ist iCloud, und das
    ist dasselbe Recht wie auf iOS.
  - **Ohne `files.user-selected.read-write` kommt aus dem Dateiwähler NICHTS
    an** — und zwar ohne Fehlermeldung. Das trifft „Bilder aus Dateien", die
    Grafik-Einfuhr und das Einlesen einer `.reisebuch`-Datei.
  - **Der Bau prüft es mit.** `ios-apps-build.yml` übersetzt seither jede App,
    deren Projekt `SUPPORTS_MACCATALYST = YES` trägt, zusätzlich gegen das
    Catalyst-SDK; welche das sind, steht im Projekt und nicht in einer zweiten
    Liste (die liefe auseinander). Eine Schnittstelle, die es dort nicht gibt,
    fiele sonst erst auf dem Mac des Nutzers auf.
  - **`userInterfaceIdiom` ist dort `.mac`**, nicht `.pad`. Wer auf `.pad`
    prüft, um einen Anker für einen Dialog zu setzen, verliert ihn auf dem Mac
    (getroffen beim Druckdialog).
  - **Auf dem iPhone bleibt alles, wie es ist** (Ansage des Nutzers): Die App
    startet dort und zeigt die Seiten; für die Bedienung umgebaut wird sie
    nicht.
  - **`LSSupportsOpeningDocumentsInPlace = NO` lehnt macOS AB** — „Either
    remove the entry or set it to YES". **Gefunden hat das der neue Mac-Bau,
    im ersten Lauf, in dem es ihn gab**; der iOS-Bau war dabei grün. Genau
    dafür ist er da. Weggelassen genügt aber nicht: Dann WARNT der Bau, die
    App unterstütze das Öffnen von Dateien, sage aber nicht, ob an Ort und
    Stelle. Der Schlüssel steht deshalb auf `YES` — für diese App keine
    Zusage, die sie nicht hält: Sie liest die Datei und schreibt ihren Inhalt
    in die eigene Ablage. **Dazu gehört zwingend
    `startAccessingSecurityScopedResource` beim Einlesen** (an Ort und Stelle
    kommt die Datei aus einem fremden Ordner und ließe sich sonst nicht
    lesen, ohne Fehlermeldung) — und `aufraeumen` löscht weiterhin NUR im
    Posteingang, ein Buch des Nutzers wird nicht angefasst.
  - **Nicht gemessen:** Auf einem Mac hat das niemand gesehen. Der Bau beweist,
    dass sich der Quelltext übersetzen lässt — **nicht, dass sich signieren
    lässt** (`CODE_SIGNING_ALLOWED=NO`); dafür muss die App-Id iCloud auch für
    macOS können. Und wie sich die Bühne mit Maus und Trackpad anfühlt, ist
    offen: Zoomen mit zwei Fingern, das Ziehen der Blöcke und die Griffe sind
    für Finger gebaut.
- **EIN KNOPF, DER AUF „IRGENDEINE" SEITE WIRKT** (`Reisewerk.gewaehlteSeite`,
  ab 1.0.61; Befund des Nutzers 09/2026: „schwer zu erkennen, ob eine Seite
  ausgewählt wird bzw. auf welcher Seite die Änderungen, die ich vornehmen
  möchte, greifen werden"). „Auf die Seite legen" gab es seit 1.0.0 — im
  Block-Inspektor, und nur, wenn gerade KEIN Block gewählt ist; gefunden hat
  es niemand (elfter Fall von „es war da, man fand es nicht"). Schlimmer war,
  worauf es wirkte: auf `werk.seitenzeiger`, einen Zähler, den Einfügen,
  Löschen und Verschieben setzen und der mit dem, was im Bild steht, NICHTS
  zu tun hat.
  - **Gewählt wird jetzt eine SEITE, und man sieht es**: ein Rahmen in der
    Akzentfarbe um das Blatt, dazu „· ausgewählt" unter der Seite. Gezeichnet
    AUSSERHALB des Maßstabs, wie der Schatten seit 1.0.20 — eine Linie, die
    beim Herauszoomen dünner wird, ist genau dann weg, wenn man die Übersicht
    braucht.
  - **Ein Tipp wählt, sonst folgt die Wahl dem Bild** (dieselbe Regel wie beim
    gewählten Tag seit 1.0.28) — aber nur, wenn das gewählte Blatt gar nicht
    mehr zu sehen ist. Sonst nähme das Scrollen innerhalb einer Doppelseite
    dem Nutzer das Blatt weg, das er eben angetippt hat.
  - **Umschlag und Ausgleichsseite werden nicht angeboten.** Sie werden
    gerechnet und stehen in keinem Tag; ein Block darauf wäre beim nächsten
    Durchgang weg.
  - **Das Menü nennt die Seite beim Namen.** Ein Menü, das nicht sagt, worauf
    es wirkt, ist die Frage von vorhin noch einmal. Inspektor und Plus-Menü
    zeigen dieselbe Seite und rufen dieselbe Stelle.
- **EINE GRAFIK IST KEIN REISEFOTO** (`Foto.grafik`, `Reisewerk.grafikEinfuegen`,
  ab 1.0.61; Ansage des Nutzers 09/2026: „Diese Bilder sollen dann nicht in
  der Reisespur auftauchen und es ist völlig unerheblich, ob sie einen
  Zeitstempel haben oder einen Ort."). Sie geht NICHT durch die Fotoeinfuhr:
  Die ordnet einem Tag zu, liest Datum und Ort, baut daraus Reisepunkte und
  meldet hinterher, was gefehlt hat — für eine Grafik ist jede dieser
  Auskünfte Lärm, und genau das wurde gemeldet („1 Fotos tragen keinen Ort …
  1 Fotos tragen kein Datum und stehen jetzt bei 4. Juni 2026"). Gelesen
  werden nur die MASSE.
  - **Sie ist nicht heimatlos**, sondern liegt da, wo jemand sie hingelegt
    hat: `Reise.heimatlose` lässt sie aus, sonst stünde sie in der Fotoablage
    als Aufgabe, die es nicht gibt. In die Reisespur kommt sie ohnehin nicht —
    die wird aus `tag.fotos` gebaut, und dort steht sie nicht.
  - **Der Weg führt in die DATEIEN, nicht in die Mediathek**, und die ECHTE
    Endung bleibt erhalten: Eine Grafik ist meist ein PNG mit durchsichtigem
    Grund, und den gibt die Mediathek nicht zuverlässig her — dieselbe
    Überlegung wie beim Wasserzeichen.
  - **Der Rahmen folgt dem Seitenverhältnis des Bildes.** Ein fester Rahmen
    schnitte jedes Hochformat an, denn gefüllt wird, nicht eingepasst.
  - **Nicht gemessen:** Ob die Seitenwahl sich richtig anfühlt, sagt erst der
    nächste Befund; geändert sind Wege und Namen, und das ist keine Messung.
- **DIE LETZTE SEITE EINES BUCHES IST EINE LINKE** (`Reise.brauchtAusgleich`,
  `blockseiten`, ab 1.0.60; Ansage des Nutzers 09/2026: „Natürlich muss die
  letzte Seite des Buches eine linke Seite sein, also eine gerade Seitenzahl
  haben. Ist das bei den erstellten Seiten nicht der Fall, dann musst du
  bitte noch eine zusätzliche Seite anlegen."). Ein Blatt hat zwei Seiten,
  also hat ein gebundener Block eine gerade Zahl davon. Bis 1.0.59 hat die
  App den Fall nur GEMELDET — und das war die falsche Art Antwort:
  **Gemeldet wird ein Zustand, den man ändern kann; dieser lässt sich nicht
  ändern, das Papier ist ja da.** Die Frage war allein, ob die letzte Seite
  im PDF steht oder ob der Druckdienst sie stillschweigend anhängt, und das
  Zweite ist eine Seite, die niemand gesehen hat.
  - **Ergänzt wird in `Reise.seitenfolge`**, also dort, wo auch das
    Titelblatt entsteht — NICHT als Seite in einem Tag. Damit fasst sie kein
    Neuanordnen an, kein Muster und kein Stilwechsel, und sie verschwindet
    von selbst, sobald eine echte Seite dazukommt. Bearbeiten lässt sie sich
    nicht; sie steht in keiner Seitenliste.
  - **Ihre Kennung ist FEST** (`Reise.ausgleichsseitenKennung`) und wird
    nicht bei jedem Durchgang gewürfelt: An der Kennung hängen `ForEach`,
    `scrollTo` und der Vergleich aus 1.0.59 — dieselbe Überlegung wie beim
    gemerkten Titelblatt.
  - **Sie gehört dem LETZTEN Tag.** Ohne Tag hielte `wasserzeichen(fuer:)`
    sie für eine Umschlagseite (dort heißt „kein Tag" genau das) und
    `kurzname` nennte sie „Titelseite".
  - **Leer heißt nicht nackt:** Sie trägt den Hintergrund des Buches und
    damit die zweite Hälfte eines Bildes, das über die Doppelseite läuft —
    der letzte Bogen geht dadurch auf. Eine Seitenzahl bekommt sie nicht.
  - **Zwei Zahlen daneben waren falsch.** `innenseiten` (daraus folgt die
    RÜCKENBREITE) ließ die Titelseite aus, wenn sie kein eigener
    Umschlagbogen ist — der Rücken war um ein halbes Blatt zu dünn
    gerechnet. Und `seitenzahl` zählte ausgeblendete Tage mit, nannte also
    im Ausgabeblatt eine andere Zahl, als die Datei hinterher Seiten hatte.
    Beide kommen seither aus `blockseiten`.
  - **Wer eine Zählung ändert, sucht nach jeder Stelle, die sie nachbaut.**
    `Druckpruefung.doppelseitenhintergrund` baut die Nummerierung selbst
    nach; ohne die Ausgleichsseite hätte es genau dort eine halbe
    Doppelseite gemeldet. (Dieselbe Lehre wie bei der Umstellung in 1.0.52,
    dort waren es drei Stellen.)
- **DIE AUFLÖSUNG IM PDF HÄNGT AN ZWEI ZAHLEN, UND DIE PRÜFUNG KANNTE NUR
  EINE** (`Model/Ausgabeguete.swift`, ab 1.0.59; Frage des Nutzers 09/2026:
  „ist eigentlich gewährleistet, dass die PDF-Datei die für den Druck
  erforderliche Auflösung beinhaltet. Ich lasse ja bei einem sehr guten
  Fotodienst entwickeln."). Die Aufnahme liegt unverändert im Bildarchiv —
  beim AUSGEBEN rechnet `Bildarchiv.fuerAusgabe` sie aber auf eine
  Höchstkante herunter (`auftrag.bildkante`, Vorwahl 3600). Die Druckprüfung
  rechnete bis 1.0.58 mit `foto.breite`, also mit den Bildpunkten der
  Originaldatei, und nannte damit eine Zahl, die die Datei gar nicht hält:
  Bei „Zum Ansehen" (1600) war das das Doppelte bis Dreifache, und die
  Meldung „Alle Bilder über 250 dpi" stand über einem PDF, in dem kein
  einziges Bild so fein war. **Eine Prüfung, die eine Zahl nennt, die die
  Datei nicht hält, ist schlimmer als keine** — dieselbe Regel wie bei
  „Plan" gegen „pünktlich".
  - **Die Kante steht an EINER Stelle.** `Bildguete` ist deshalb aus
    `AusgabeView` ins Modell gewandert: Eine Ansicht kann die Druckprüfung
    nicht fragen, und zwei Fassungen derselben Zahl liefen auseinander.
    Gerechnet wird in der Prüfung mit `Bildguete.vorgabe`, weil das der
    Regelfall beim Ausgeben ist — **und die Zeile schreibt hin, dass sie es
    tut**, statt es vorauszusetzen. Wer eine andere Güte wählt, bekommt
    seine Zahl im Ausgabeblatt, dort mit dem gewählten Deckel.
  - **Das HINTERGRUNDFOTO wird mitgezählt.** Es füllt Seite oder
    Doppelseite ganz aus und ist damit fast immer das schwächste Bild eines
    Buches; gezählt wurden bis 1.0.58 nur Fotoblöcke. Die Fläche dafür
    rechnet `Bogenlage.bildflaeche` — dieselbe Funktion, die auch zeichnet.
  - **„Gedeckelt" und „das Foto gibt nicht mehr her" sind zwei Befunde.**
    Nur der erste lässt sich im Ausgabeblatt beheben, und nur dann nennt
    die App die höhere Güte als Antwort. Gerechnet wird beides in einem
    Durchgang (`dpi` gibt zwei Werte zurück).
  - **Gerechnet wird in einer AUFGABE, nicht im Körper.** Der Lauf geht
    über jede Seite und jedes Bild des Buches — dieselbe Falle wie bei der
    Druckprüfung in 1.0.0.
  - **Nicht gemessen:** Keine Datei ist damit gedruckt worden. Gerechnet
    ist, was die Kante mit der Auflösung macht; ob ein Druckdienst sie
    annimmt und wie das Papier aussieht, sagt erst der erste Abzug.
- **EINE ZOOMGESTE DARF NICHT JEDE SEITE NEU BAUEN** (`SeitenflaecheView:
  Equatable`, `.equatable()`, ab 1.0.59; Wunsch des Nutzers 09/2026: „wenn
  Verschiebe- oder Zoom-Aktionen auf dem Bildschirm etwas flüssiger
  ablaufen könnten"). Der Zoom WÄHREND der Geste ist seit 1.0.18 eine reine
  Skalierung, und das ist richtig — gerechnet wird erst am Ende. Nur: `lupe`
  ist ein Zustand im Körper der Bühne und wird bei jedem Bildpunkt gesetzt.
  Damit bekommt jede sichtbare `SeitenflaecheView` einen neuen Wert, und
  ohne Vergleich muss SwiftUI von einer Änderung ausgehen: Hintergrund,
  Wasserzeichenlage (ein Suchlauf über 49 Felder), jeder Textkasten, jedes
  Vorschaubild. Verglichen wird jetzt, was das Aussehen bestimmt — das
  `werk` über die IDENTITÄT, denn was sich in ihm ändert, meldet es selbst
  und geht am Vergleich vorbei. **Es wird nichts abgeschaltet**, es fällt
  nur der Durchgang weg, bei dem sich nichts geändert hat. Dieselbe Bauweise
  wie bei der Netzkarte der Abfahrtstafel (1.1.17). **Wer eine gespeicherte
  Eigenschaft hinzufügt, trägt sie in `==` ein; wer eine dritte Aufrufstelle
  anlegt, hängt `.equatable()` mit dran.**
- **„Zoomgeste" stand im Befund und wurde NIE gezählt** (behoben in 1.0.59).
  In `ReiseView` stand seit 1.0.28 der Satz, die Zeile zähle, wie viele
  Gesten überhaupt angekommen sind — und im ganzen Quelltext gab es keinen
  einzigen `melde("Zoomgeste")`; die Zeile konnte gar nicht erscheinen.
  **Ein Kommentar ersetzt keine Prüfung**, zum wiederholten Mal, und
  diesmal an der Probe selbst. Gezählt wird seither je Bildpunkt der
  Bewegung, dazu die Bühne (`Bühne`). Damit ist die Gegenprobe zum Punkt
  darüber da: „Zoomgeste" hoch und „Seite" bei null heißt, die Geste kommt
  an und die Seiten zeichnen sich nicht mit; laufen beide gleich hoch, ist
  es umgekehrt. Mitgezählt in „Fotos" werden seither auch Hintergrundfoto
  und Wasserzeichen — Letzteres liegt auf JEDER Seite und war damit die
  Art Bild, die sich am ehesten summiert.
- **Offen und nicht als erledigt darstellen:** Am ENDE einer Geste ändert
  sich der Maßstab, und dann holt jede Seite ihre Vorschaubilder eine Stufe
  feiner neu von der Platte — auf dem HAUPTFADEN (`Bildarchiv.vorschau` ist
  synchron). Was das kostet, steht als „Fotos" im Befund; geändert ist
  daran in 1.0.59 nichts.
- **DER BUNDSTEG RÜHRT DEN HINTERGRUND NICHT AN — UND KEINE SCHON GESETZTE
  SEITE** (ab 1.0.58; gemeldet 09/2026 mit einem Bild der Doppelseitenansicht:
  „Der Bund soll offenbar tatsächlich bei 0 mm liegen. Das habe ich jetzt so
  eingestellt. Dennoch sieht es nicht so aus, als ob die App das akzeptiert
  hätte."). **Sie hat es akzeptiert:** 0 ist der Vorgabewert
  (`Gestaltung.bundsteg`) und der Anfang des Reglers, und `satzspiegel` addiert
  ihn schlicht auf `randAussen` — beidseitig, seit 1.0.1. Nicht zu sehen war es
  aus zwei Gründen, und beide gehören gesagt, statt den Regler zu ändern:
  - Er verschiebt den **Satzspiegel**, also den Platz, in den NEUE Seiten
    gesetzt werden. Blöcke stehen als Rechtecke im Buch; eine schon gesetzte
    Seite rückt kein Randwert nach. Wer sie mitziehen will, ordnet sie neu an.
  - Ein **Hintergrund** richtet sich gar nicht nach ihm. Er läuft immer bis in
    den Anschnitt — das ist seit 1.0.1 seine Definition, und eine Fläche, die
    am Endformat aufhörte, hätte nach dem Schneiden den weißen Faden.
  **Der Satz steht jetzt unter dem Regler** (`GestaltungView.zugabenhinweis`),
  also dort, wo die Frage entsteht.
- **Am Bund liegen ZWEI Anschnitte, und die stehen doppelt da.** Die
  Doppelseitenansicht zeichnet zwei Bogen ohne Abstand nebeneinander (Regel seit
  1.0.17), und jeder trägt an seiner Innenkante 3 mm Anschnitt. Bei einem Bild
  über die Doppelseite ist dieser Streifen deshalb **zweimal** im Bild — einmal
  von jeder Seite —, und im gebundenen Buch ist er weg. Genau darauf saß die
  gemeldete Sonne. **Das ist keine Panne der Ansicht**: Der Anschnitt gehört
  dorthin, und wo er endet, zeigt die rote Schnittkante. Was fehlte, war, dass
  es irgendwo steht.
- **EIN HINTERGRUNDFOTO LÄSST SICH ZOOMEN UND VERSCHIEBEN**
  (`Seitenhintergrund.ausschnitt`, ab 1.0.58, Ansage des Nutzers 09/2026: „mir
  würde auch die Funktion helfen, das Bild des Seitenhintergrundes etwas zoomen
  bzw. verschieben zu können. Dann würde ich in diesem Fall die Sonne … etwas
  verschieben."). Es ist derselbe `Bildausschnitt` wie am Fotoblock und dieselbe
  Rechnung — kein zweiter Typ für dieselbe Sache. `.voll` ist die Vorgabe und
  heißt „mittig und ohne Zoom", also genau der Stand von vorher.
  - **Der Bildschirm rechnete bis 1.0.57 ANDERS als das PDF.** Dort stand
    `scaledToFill`, hier `Bildausschnitt.voll.zielrechteck` — bei `.voll`
    dasselbe Ergebnis, mit einem eigenen Ausschnitt nicht mehr. Beide fragen
    seither `Bildausschnitt.gefuelltesZiel`, und das BEGRENZT vorher: Ein
    Versatz, der nach einem Formatwechsel oder nach dem Umlegen von „über die
    Doppelseite" nicht mehr im Bild läge, ließe sonst einen weißen Keil stehen.
    **Merke: Zwei Zeichner, die zufällig dasselbe tun, sind erst dann eine
    Rechnung, wenn sie dieselbe Funktion fragen.**
  - **Der Rahmen ist auf beiden Seiten derselbe**, nur anders ausgedrückt: Das
    PDF bekommt ihn in Seitenkoordinaten (`Bogenlage.bildflaeche`, Ursprung am
    Anschnitt), der Bildschirm rechnet ihn am Bogen aus (`bildrahmen(raum:)`).
    Nachgerechnet geht das auf — die Fläche über die Doppelseite misst
    2 × Endformat + 2 × Anschnitt, und ihre Mitte liegt genau auf dem Bund.
  - **REGLER und keine Geste.** Die Einstellung steht in einem `Form`, also in
    einer scrollenden Liste; eine Ziehgeste über der Probe stritte mit dem
    Scrollen — dieselbe Lehre wie 1.0.5 („Wer eine Geste über eine ganze Fläche
    legt, prüft, was diese Fläche sonst noch tut"). Ein Regler trifft dazu auf
    ein Prozent genau, und nach sieben Fassungen Gestenarbeit an der Bühne ist
    das hier der billigere Weg.
  - **Wo kein Spielraum ist, steht kein Regler.** Bei Zoom 100 % füllt das Bild
    den Rahmen in einer Richtung auf den Punkt; dort steht „kein Spielraum"
    statt eines Schiebers, der nichts bewirkt — ein Bedienelement ohne Wirkung
    ist für den Menschen davor ein kaputtes.
  - **Die Probe ist MASSSTÄBLICH** und zeigt die Fläche, die ins PDF geht, samt
    roter Schnittkante und — beim Bild über die Doppelseite — dem Band am Bund.
    `zielrechteck` misst den Versatz in Anteilen der Rahmenbreite und ist damit
    vom Maßstab unabhängig: Was dort steht, steht im Druck an derselben Stelle.
    Die Leiste ganz oben im Blatt hat dagegen NICHT das Maß einer Seite; das
    sagt die Fußzeile auch.
  - **`Seitenhintergrund` hat seinen Leser seit 1.0.47** — ein neues Feld war
    deshalb gefahrlos. Beide Initialisierer gehören mitgezogen, der eigene
    `init(from:)` UND der ausgeschriebene: Wer in einer Struktur einen
    Initialisierer schreibt, hat danach keinen mitgelieferten mehr.
- **Nicht gemessen (1.0.58):** Keine Seite ist damit gesehen worden. Gerechnet
  ist die Geometrie (dass beide Zeichner denselben Rahmen bekommen und die Probe
  maßstäblich dasselbe zeigt). **Und die Deutung des gemeldeten Bildes ist am
  Quelltext hergeleitet, nicht an seinem Buch nachgesehen** — dass die doppelte
  Sonne die beiden Anschnitte sind, folgt aus der Bauweise der
  Doppelseitenansicht; beweisen würde es erst ein Blick in die ausgegebene
  Datei. Ungeprüft ist außerdem, ob der Umschlag mit einem eigenen Ausschnitt
  zusammengeht: Auf dem Bildschirm wird sein Hintergrund je HÄLFTE gezeichnet,
  im PDF über den ganzen Bogen — die Probe im Blatt nimmt den ganzen Bogen, also
  die Fassung, die gedruckt wird. **Nichts davon als erledigt darstellen.**
- **`.frame` BESCHNEIDET NICHT — es stellt ein zu großes Kind MITTIG hinein**
  (`RegalView.Vorschaubild`, ab 1.0.57; gemeldet 09/2026 mit Bildschirmfoto:
  „Die Beschriftung des Projektes ragt in das Bild mit rein. Das sieht nicht
  gut aus.“). **Nachgerechnet und keine Vermutung:** Das Titelfoto im Regal
  steht in einem `ZStack` mit `.frame(width: 52, height: 68)`. `scaledToFill`
  füllt den vorgeschlagenen Rahmen und wird dabei in einer Richtung GRÖSSER
  als er — ein Querformat-Foto (4:3) misst bei 68 Punkt Höhe gut 90 Punkt in
  der Breite und steht links und rechts um je 19 Punkte über. Der Rahmen
  begrenzt nur das LAYOUT, nicht die Zeichnung; in der `HStack` daneben beginnt
  die Beschriftung genau dort. Weil die Texte NACH dem Bild gezeichnet werden,
  liegen sie obenauf — für den Menschen davor ragt also die Beschriftung ins
  Bild, und genau so ist es gemeldet worden.
  - **Ein `clipShape` am BILD hilft nicht**, und genau eines stand dort seit
    1.0.19: Es beschneidet den Rahmen des Bildes, und der ist ja der zu große.
    Beschnitten wird jetzt der Behälter, also NACH dem `.frame` — dieselbe
    Reihenfolge, die `TagListeView`, `TagInhaltView` und die Hintergrundfläche
    der Seite seit jeher benutzen. Der Schatten liegt dahinter und folgt damit
    der beschnittenen Form.
  - **Dritte Auflage derselben Falle.** 1.0.2 lernte sie an den Griffen („was
    außerhalb eines Frames liegt, nimmt keinen Finger an“), 1.0.12 am
    `TextflaecheBruecke` („`.frame()` beschneidet nicht, es stellt ein zu
    großes Kind MITTIG hin“) — beide Male beim Bearbeiten einer Seite, und
    beide Male stand die Lehre danach im Papier. Sie galt für das Regal nicht,
    weil dort niemand ein zu großes Kind vermutet hat. **Wer `scaledToFill`
    schreibt, schreibt das Beschneiden in derselben Zeile mit.**
  - **Die Textspalte nimmt jetzt, was übrig ist** (`.frame(maxWidth: .infinity,
    alignment: .leading)` statt eines `Spacer` daneben) — die Lehre aus
    Abfahrtstafel 1.1.32. Das ist eine Vorsichtsmaßnahme und NICHT die
    gemeldete Ursache: Mit drei Textzeilen in der Spalte ist die Idealbreite
    die der längsten Zeile, und die geht auf. Es steht trotzdem da, weil eine
    vierte Zeile es morgen nicht mehr täte.
- **Nicht gemessen (1.0.57):** Das Regal ist damit auf keinem Gerät gesehen
  worden. Gerechnet ist der Überstand (90,7 statt 52 Punkte bei einem
  Titelfoto im Verhältnis 4:3, also 19,3 Punkte je Seite) und die Wirkung des
  Beschneidens. **Ungeprüft bleibt**, ob das Bildschirmfoto des Nutzers wirklich
  ein Querformat-Titelfoto zeigt — ein Hochformat (3:4) steht in diesem Rahmen
  nur um gut einen Punkt über und fällt kaum auf; die Ursache wäre dieselbe,
  der Betrag ein anderer. **Nicht als erledigt darstellen.**
- **Nicht gemessen (1.0.56):** Keine Seite ist damit gesehen worden.
  Gerechnet ist die Auswahl und ihre Geometrie; **die Verteilung ist eine
  Wahrscheinlichkeitsaussage und keine Zusage** — wie sie in einem
  wirklichen Buch ausfällt, sagt erst die neue Zeile im Befund. **Gewählt
  und nicht gemessen** sind die Höchstzahl zehn (sie ist die Zahl aus der
  Ansage), der Mischfaktor des Ziehens und die Schwellen von `formtext`
  (1,08 und 0,93). Ungeprüft ist, ob ein Buch mit zehn Zeichenbildern beim
  Ausgeben spürbar langsamer wird — je Seite wird weiterhin genau EIN Bild
  geladen, aber aus zehn verschiedenen Dateien statt aus einer, und der
  Bildvorrat hält nur 120 Einträge. **Nicht als erledigt darstellen.**
- **Nicht gemessen (1.0.55):** Keine Seite ist damit gesehen worden.
  Gerechnet und am Quelltext abgezählt ist die URSACHE (der Schleier
  skaliert den Kanalabstand mit `1 − a`) und die Wirkung des Faktors;
  gemessen wird auf dem Gerät allein der Randanteil. **Gewählt und nicht
  gemessen** sind der Deckel von 3,5 auf den Faktor, die 48er-Messkante,
  die Zwanzigstel-Stufen und die Schwellen der Warnzeile (0,5 % und 8 %).
  **Ungeprüft ist vor allem, ob das gedruckte Blatt so aussieht wie der
  Bildschirm**: Ein gesättigtes Bild hinter einem Schleier wirkt auf einem
  leuchtenden Schirm kräftiger als auf Papier, und wie weit `CIColorControls`
  im PDF dasselbe tut wie in der Vorschau, ist zwar dieselbe Funktion, aber
  auf zwei verschiedenen Bildgrößen. **Nicht als erledigt darstellen.**
- **Nicht gemessen (1.0.54):** Keine Seite ist damit gesehen und keine
  Umschlagdatei gedruckt worden. **Gemessen ist das Ablesen** — die Pixel-
  und dpi-Werte, die Millimeterleiter, die Vorlagenmaße der Innenseiten —,
  und es ist an Bildschirmfotos abgelesen und nicht an einer Datei des
  Anbieters. Ändert Saal sein Papier, ändert sich die Tabelle, und diese App
  merkt davon nichts; verbindlich bleibt die Angabe des Druckdienstes.
  **Gewählt und nicht gemessen** sind die Toleranz der Formatzuordnung
  (12 mm) und die Reglerweite der Verschiebung (halbe Satzbreite bzw.
  -höhe). Ungeprüft ist, ob eine per Hand gedrehte Seite im PDF so steht wie
  auf dem Bildschirm — gerechnet wird es aus derselben Funktion, gesehen hat
  es niemand. **Nichts davon als erledigt darstellen.**
- **Nicht gemessen (1.0.53):** Keine Seite ist damit gesehen worden.
  Gerechnet und am Quelltext abgezählt ist die URSACHE — dass eine Ebene mit
  ihrem `contentsScale` rastert und ein `scaleEffect` das Ergebnis dehnt.
  **Gewählt und nicht gemessen** sind alle Zahlen: das Pixelbudget
  (6 Millionen), die Stufenliste, die obere Grenze der Vorschaubilder (Fotos
  2000, Wasserzeichen 1600, Hintergrund 2000 bzw. 2800 über die Doppelseite)
  und die 200er-Rundung der Kanten. **Ungemessen bleibt der PREIS**: Eine
  feinere Rasterung kostet Speicher und Zeichenzeit, und wie sich ein Buch
  mit zweihundert Fotos bei 400 % anfühlt, sagt erst der nächste Befund —
  seit 1.0.53 sagt er es mit Zahlen. **Nicht als erledigt darstellen.**
- **Nicht gemessen (1.0.52):** Keine Seite ist damit gesehen worden. Am
  Quelltext abgezählt sind die URSACHEN (der Umschlag in der Zählung, das
  Meldeband hinter dem Vollbild) und die Geometrie der Drehung. **Gewählt
  und nicht gemessen** sind die Höchstdrehung (45 Grad) und die Vorgabe
  beim Einschalten (12 Grad). **Ungeprüft bleibt**, ob ein Druckdienst den
  Umschlagbogen annimmt (das stand schon zu 1.0.50 offen), ob die
  Rückentabelle eines Anbieters mit dieser Lesart zusammenpasst — sie ist
  hier an keiner echten Tabelle geprüft — und ob ein gedrehtes Zeichen im
  Druck so steht wie auf dem Bildschirm. **Nichts davon als erledigt
  darstellen.**
- **Nicht gemessen (1.0.51):** Keine Karte ist damit gesehen worden.
  Gerechnet und am Quelltext abgezählt ist die URSACHE (es gab schlicht kein
  Feld am Block, und der Abschnitt fragte den falschen Tag). **Ungeprüft
  bleibt, ob der Befund des Nutzers denselben Grund hatte** — auf seinem
  Bildschirmfoto fehlte der Kartenabschnitt ganz, und das passt zum zweiten
  Fall („`gewaehlterTag` zeigt ins Leere"), ist aber nicht nachgewiesen.
  **Nicht als erledigt darstellen.**
- **Nicht gemessen (1.0.50):** Kein Umschlag ist damit gedruckt worden.
  Gerechnet und am Quelltext abgezählt ist die URSACHE der fehlenden
  Seitenzahlen; die Geometrie des Bogens ist gerechnet und nicht gesehen.
  **Gewählt und nicht gemessen** sind die Vorgaben 0,13 mm je Blatt und 4 mm
  Deckelstärke, die Warnschwelle von 4 mm Rückenbreite und der Anteil 0,62,
  auf den die Rückenschrift gedeckelt wird. **Ungeprüft ist vor allem, ob ein
  Druckdienst diesen Bogen annimmt** — die Boxen sind gesetzt, die Falze
  stehen nur als Rückenbreite darin, und das ist die Stelle, an der Anbieter
  auseinandergehen. Und ein Hintergrundfoto mit „über die Doppelseite" rechnet
  auf dem Umschlag die Rückenbreite nicht mit; über den Umschlag läuft es
  ohnehin als EIN Bild. **Nichts davon als erledigt darstellen.**
- **DER PINSEL GEHÖRT DEM EINZELNEN ELEMENT, DAS BUCH DEM GANZEN BUCH** (ab
  1.0.49; gemeldet 09/2026: „Bei der Bedienung der App komme ich immer
  durcheinander mit dem Pinsel-Symbol und dem Symbol für die
  Einstellungsmöglichkeiten. Irgendwie habe ich fast sogar das Gefühl, dass
  die beiden Symbole vertauscht sind."). **Sie waren es.** In Pages öffnet
  der Pinsel die Einstellungen des GEWÄHLTEN Elements; hier tat das der
  Schieberegler, und der Pinsel führte in die buchweite Gestaltung. Der Nutzer
  hat also nicht eine fremde Gewohnheit mitgebracht, sondern eine verbreitete
  benannt — und in einer App, die Seiten setzt, ist Pages der Vergleich, den
  jeder im Kopf hat.
  - **Der Tausch allein hätte es nicht gerichtet.** „Ausgewähltes" und
    „Gestalten" sagen beide etwas über die TÄTIGKEIT — und der Unterschied
    zwischen diesen beiden Knöpfen ist nicht die Tätigkeit, sondern der
    GELTUNGSBEREICH. Sie heißen seither **„Auswahl"** (Pinsel) und **„Ganzes
    Buch"** (Buchsymbol), und im Menü steht der Abschnittstitel „Gilt für das
    ganze Buch" darüber. **Merke: Wo zwei Wege dasselbe TUN und sich nur
    darin unterscheiden, WORAUF sie wirken, gehört der Geltungsbereich in
    die Beschriftung und nicht die Tätigkeit.**
  - **Wer eine Beschriftung ändert, zieht die Bedienungskarte mit.** In
    `BedienungView` stand siebenmal „Gestalten (Pinsel)" und „Der Pinsel →" —
    eine Karte, die einen Knopf bei einem Namen nennt, den es nicht mehr
    gibt, ist schlimmer als gar keine. Dasselbe gilt für die Querverweise in
    `GestaltungView`, `BlockInspektor` und der Druckprüfung.
  - **Nicht gemessen:** Ob die Verwechslung damit aufhört, sagt erst der
    nächste Befund. Geändert sind Symbole und Namen, und das ist keine
    Messung — dieselbe Einschränkung wie bei den Menüs in 1.0.20.
- **Die Punktekarte war nicht klein gebaut, sie war ein BLATT IN EINEM
  BLATT** (ab 1.0.49; gemeldet 09/2026: „Zum einen möchte ich die Punkte auf
  der Karte auswählen und merke, dass diese viel zu klein öffnet. Diese Karte
  könnte sich ja tatsächlich über einen großen Teil des Bildschirms
  erstrecken."). `SpurView` ist selbst ein `.sheet`, und auf dem iPad ist ein
  Sheet ein Kärtchen in der Bildschirmmitte; `PunktwahlView` hing als zweites
  daran und konnte damit nie größer werden als das erste. **Dieselbe Lehre
  wie beim Platz-Editor in Tafelbild**, wo der Grundriss aus genau diesem
  Grund ein Drittel der Höhe bekam — dort war sie aufgeschrieben und hier
  nicht gezogen. Ein `fullScreenCover` hängt sich nicht in das Kärtchen,
  sondern über alles.
  - **Die Vorschau oben ist seither ein BILD** (`interactionModes: []`) und
    zugleich der Weg zur Karte: Ein Tipp darauf öffnet die volle. Sie war
    schieb- und zoombar — auf 240 Punkten Höhe in einem Kärtchen ist das
    eine Karte, an der sich nichts machen lässt, und sie schluckte
    ausgerechnet den Tipp, mit dem man die richtige öffnen wollte. Dieselbe
    Regel wie überall: **Was auf einer Karte liegt, ist ein Bild; was etwas
    tut, ist ein Knopf.**
- **PUNKTE, DIE AUS DER LINIE SPRINGEN** (`Dienste/Ausreisser.swift`, ab
  1.0.49; gemeldet 09/2026: „Mein Gerät hat den Standort zuweilen sehr
  ungenau aufgezeichnet und somit sind Punkte mit einer Linie verbunden
  worden, die sehr weit auseinander sind. In diesem Fall sticht die Linie
  sehr hervor, obwohl sie gar nicht dem Reiseverlauf entspricht."). Gegen die
  MESSUNG lässt sich nichts tun — ein GPS-Empfänger zwischen zwei Häuserwänden
  meldet zuweilen eine Stelle einige Kilometer daneben. Gegen die LINIE schon.
  - **Gemessen wird der UMWEG, nicht die Entfernung zum Nachbarn.**
    `hin + zurück − direkt` ist genau das, was der Punkt an zusätzlicher
    Linie KOSTET, also genau der Schaden, um den es geht: Bei einem Sprung
    hin und gleich zurück ist er das Doppelte der Abweichung, bei einer
    Kurve unterwegs fast null. Eine senkrechte Entfernung zur Verbindungslinie
    wäre die naheliegende Alternative, bräuchte eine Projektion in eine Ebene
    (über hundert Kilometer hinweg schief) und brächte im einzigen Fall, um
    den es geht, dasselbe Ergebnis.
  - **Die Schwelle hängt an der SPUR selbst.** Zwei Kilometer sind in einer
    Stadtbesichtigung ein Ausreißer und auf einer Fahrt durch Kanada nichts.
    Verglichen wird gegen den MEDIAN der Schrittweiten dieser Spur — nicht
    gegen den Mittelwert, denn den verderben genau die Ausreißer, die gesucht
    werden. Dazu ein absoluter Boden (1,5 km): Was darunter liegt, sticht auf
    einer Buchseite nicht heraus.
  - **Ein unmögliches TEMPO zählt nur in BEIDE Richtungen.** Über 1200 km/h
    fährt und fliegt nichts; ein echter Linienflug ist aber auch schnell, und
    er unterscheidet sich vom Messfehler genau darin, dass er nicht in
    derselben Minute zurückkommt. Fehlt eine der beiden Uhrzeiten, heißt das
    „weiß ich nicht" und nicht „ja" — ein Handpunkt ohne Zeit darf nicht
    auffällig werden, bloß weil er keine trägt.
  - **Der erste und der letzte Punkt werden nicht geprüft**, und das steht
    auch da: Ein Ausreißer wird an seinen NACHBARN erkannt, und die beiden
    haben nur einen. Geraten wird nichts.
  - **GELÖSCHT WIRD NICHTS VON SELBST.** Ein Abstecher zum Aussichtspunkt und
    zurück sieht von außen genauso aus wie ein Messfehler, und welcher von
    beidem es war, weiß nur, wer dabei war. Der Abschnitt über der Punkteliste
    nennt Stelle, Namen und die zusätzliche Linie in Kilometern und bietet
    zweierlei an: alle auf einmal entfernen (mit Rückfrage) oder nur
    auswählen und einzeln ansehen — Letzteres über den Auswahlmodus, den es
    seit 1.0.21 gibt. **Kein zweiter Weg zu derselben Sache.**
  - **Markiert wird an DREI Stellen** — in der Punkteliste, auf der kleinen
    Vorschau und auf der großen Karte —, und immer mit Zeichen UND Farbe: Ein
    farbfehlsichtiger Mensch sieht Orange allein nicht. Auf der großen Karte
    steht unter dem gewählten Punkt im Klartext, warum er auffällt; ein
    Zeichen ohne Erklärung ist ein Rätsel.
  - **Gerechnet wird in `.task(id:)`, nicht als berechnete Eigenschaft.** Der
    Lauf geht über jeden Punkt und misst je drei Entfernungen; der Körper
    dieser Ansichten läuft bei jeder Meldung des Werks und bei jeder
    Kamerabewegung noch einmal. Vierte Auflage derselben Falle — **eine
    berechnete Eigenschaft sieht billig aus.**
- **Nicht gemessen (1.0.49):** Keine Spur ist damit angesehen worden. **Alle
  drei Zahlen der Ausreißererkennung sind GEWÄHLT und nicht gemessen** (Boden
  1,5 km, Faktor 8 auf den Median, 1200 km/h) — ob sie an der Spur des Nutzers
  das Richtige treffen, sagt erst sein nächster Befund, und weil die App die
  Zahlen hinschreibt, sagt er es mit Zahlen. Gerechnet ist, warum die Karte
  nicht größer werden konnte (ein Sheet in einem Sheet); gesehen hat es
  niemand. **Zwei aufeinanderfolgende Ausreißer kann diese Erkennung nicht
  trennen** — der zweite ist der Nachbar des ersten, und dann ist der Umweg
  klein; das nicht als gelöst darstellen. **Nicht als erledigt darstellen.**
- **Nicht gemessen (1.0.48):** Keine Seite ist damit gesetzt worden, und
  **an der Vorlage des Nutzers ist die Erkennung nicht gelaufen** — die
  Datei liegt hier nicht. Gerechnet ist, warum Kürze in beiden Textsorten
  ein Merkmal ist; **gewählt und nicht gemessen** sind alle vier Zahlen (42
  Zeichen, sechs Wörter, 58 % der Titelgröße, Zeilenabstand 1,18). Ob die
  zweite Ebene auf der gedruckten Seite als solche zu lesen ist und ob die
  Erkennung an seinem Tagebuch trifft, sagt erst der nächste Befund — und
  seit 1.0.48 sagt er es mit einer Zahl in der Vorschau. **Nicht als
  erledigt darstellen.**
- **Nicht gemessen (1.0.47):** Keine Doppelseite ist damit gesehen worden.
  Gerechnet ist die Geometrie — dass die Fläche zwei Endformate plus zwei
  Anschnitte misst und der Versatz eine halbe Seitenbreite beträgt.
  **Ungeprüft ist, ob der Bund im gedruckten Buch etwas verschluckt**: Ein
  Hardcover verschwindet in der Bindung, und wie viel, sagt der Druckdienst
  und nicht diese App — wer ein Gesicht genau in den Bund legt, verliert es
  möglicherweise. Der Bundsteg (seit 1.0.1) schiebt den SATZ davon weg, das
  Bild nicht. **Nicht als erledigt darstellen.**
- **Die Bildunterschrift war halb gebaut** (ab 1.0.5, Wunsch des Nutzers
  09/2026: „zu jedem Foto einen Beschreibungstext … Dies soll jedoch eine
  Option für jedes Foto sein. Kein muss."). Der Layoutautomat hielt Platz
  für sie frei, das PDF zeichnete sie — auf dem Bildschirm erschien sie nie,
  und anfassen ließ sie sich gar nicht. Sie ist jetzt ein eigener Block
  (`Blockinhalt.bildunterschrift`), also verschiebbar, drehbar und in der
  Größe zu ziehen; der TEXT steht weiter am Foto und reist mit ihm mit —
  dieselbe Überlegung wie bei Überschrift und Datumszeile, die am Tag
  stehen. **Der Kommentar über `Blockinhalt` behauptete das Gegenteil und
  ist gestrichen.** Eingeschaltet wird je Foto (`Foto.unterschriftZeigen`),
  im Inspektor oder mit dem Sprechblasen-Knopf in der Fotoliste; was aus
  ist, kostet auch keinen Platz im Satz. **Der Text bleibt beim Abschalten
  stehen**, und beim Einlesen eines älteren Buches gilt eine nicht leere
  Unterschrift als eingeschaltet — sonst nähme eine neue Fassung
  stillschweigend Arbeit weg, die jemand gemacht hat. Schrift, Größe und
  Farbe stehen einmal für alle unter der Rolle „Bildunterschrift".
  **Gefunden hat den Weg dorthin aber niemand** (gemeldet 09/2026: „Ich habe
  noch nicht gefunden, wie ich eine Unterschrift unter ein Bild setzen
  kann."): Der Schalter stand im Inspektor hinter dem Abschnitt „Foto" und in
  der Fotoliste des Tages — beides Wege, die man kennen muss. Seit 1.0.6 gibt
  es zwei, die man nicht kennen muss: ein **Doppeltipp auf das Foto**
  (`unterschriftOeffnen` — derselbe Griff wie beim Text, man tippt zweimal auf
  das, was man beschriften will) und bei gewähltem Foto der Knopf
  **„Bildunterschrift"** unten in der Leiste. Eine Geste, die niemand kennt,
  ist so wenig wert wie ein Knopf, den niemand findet — deshalb beides.
  **Ein Knopf, den niemand findet, ist kein Knopf — und das gilt auch für
  einen Schalter in einem Formular.**
  **Sie gehört zur Reihe wie das Bild selbst**: `restplatzVerteilen` schiebt
  die Reihen auseinander, und eine Unterschrift, die dabei liegen bliebe,
  stünde plötzlich im Bild darüber.
- **Text wird auf der SEITE geändert, nicht im Inspektor** (`InlineText`,
  Doppeltipp). Ein `UITextView` mit denselben Attributen an derselben
  Stelle — getippt wird in der Schrift, in der gedruckt wird. Wohin der Text
  zurückgeschrieben wird, hängt an der Blockart: Fließtext in den Block,
  Überschrift und Datumszeile an den TAG. In den Block geschrieben wäre die
  Änderung beim nächsten Neuanordnen weg.
- **Die Datumszeile ist einstellbar** (`Datumsstil`, sieben Fassungen, plus
  `Reisetag.datumstext` je Tag). Sie stand fest auf „Donnerstag, 4. Juni
  2026".
- **Seitenhintergründe global UND je Seite** (`Model/Seitenhintergrund.swift`):
  einfarbig, Verlauf, Foto mit Schleier, Papierkorn. Genau diese Reihenfolge
  — das Buch hat einen Hintergrund, eine einzelne Seite darf einen anderen
  haben. Ein Hintergrund läuft IMMER bis in den Anschnitt; eine Fläche, die
  am Endformat aufhört, hätte nach dem Beschneiden den weißen Faden, wegen
  dem es den Anschnitt gibt. Ob die Schrift hell werden muss, wird über die
  wahrgenommene Helligkeit GERECHNET.
- **Der Restplatz wird verteilt, nicht unten liegen gelassen**
  (`restplatzVerteilen`). Eine Seite trug drei Fotos in einer Reihe und
  darunter die halbe Seite Weiß. Höher kann eine randbündige Reihe nicht
  werden — ihre Höhe ist die Satzbreite geteilt durch die Summe der
  Seitenverhältnisse, das ist Geometrie und keine Einstellung. Was geht, ist
  die Lücken zwischen den Reihen zu strecken, gedeckelt auf das Dreifache
  der Fuge: Luft zwischen den Reihen sieht nach Absicht aus, Luft am Fuß
  nach Abbruch. **Die eigentliche Antwort darauf sind Seitenvorlagen mit
  Platzhaltern** (drei Fotos als eines groß plus zwei gestapelt) — die
  stehen noch aus.
- **Gedreht wird um die MITTE, und der Winkel kommt aus dem Zeiger** von der
  Mitte zum Finger, nicht aus der Wegstrecke. Eine Drehung aus der
  Verschiebung dreht am Rand schneller als in der Mitte und fühlt sich
  sofort falsch an. Bei Vielfachen von 45 Grad rastet sie ein: Ein Bild, das
  um 0,4 Grad schief steht, sieht nicht gewollt aus, sondern nach einem
  Versehen.

## Karten: Quelle, Helligkeit und Lizenz (ab 1.0.3)

- **Hell oder dunkel entscheidet das BUCH, nicht das iPad** (gemeldet
  09/2026: „Die Landkarten sind von Apple Karten in der dunklen Ansicht.").
  Bis 1.0.2 stand über der Helligkeit gar nichts, und damit nahm
  `MKMapSnapshotter` die Erscheinung des Systems an: Wer abends am dunkel
  geschalteten iPad arbeitete, bekam eine schwarze Karte ins gedruckte Buch.
  Das ist kein Geschmack, sondern ein Fehler — eine Druckvorlage darf nicht
  davon abhängen, wie hell es im Zimmer war. Gesetzt wird
  `MKMapSnapshotter.Options.traitCollection`; die Vorgabe ist **hell** und
  nicht `wieApp`. Wer `wieApp` wählt, bekommt einen Warnhinweis daneben.
  **Nicht gemessen**: ob `traitCollection` auf einem echten Gerät wirklich
  greift — das zeigt erst ein Ausdruck. Der Weg daneben ist eine
  Kachelquelle, die ohnehin immer hell ist.
- **Vier Quellen** (`Model/Kartenbild.swift`, `Dienste/Kachelkarte.swift`,
  ab 1.0.3, Ansage des Nutzers 09/2026: „auf andere Kartenanbieter wie
  OpenStreetMap oder andere zurückgreifen"). Apple Karten, OpenStreetMap,
  OpenTopoMap und ein eigener Kachelserver. Alles am 21.09.2026 gemessen:
  `tile.openstreetmap.org` und `tile.opentopomap.org` antworten ohne
  Schlüssel mit 256-px-PNG (`max-age=16144` bzw. `604800`); OpenTopoMap
  rendert bis Zoomstufe 17.
- **Carto ist NICHT gebaut, und der Grund steht hier.**
  `basemaps.cartocdn.com` antwortete zwar ohne Schlüssel (auch mit `@2x`,
  also 512 px — das wäre für den Druck das Beste gewesen), aber Carto
  verlangt seit 2026 einen API-Schlüssel und deckelt bei fünf Millionen
  Kacheln im Monat. **Ein Schlüssel in einer App ist keiner** — dieselbe
  Regel wie in der Abfahrtstafel. Wer einen eigenen holt, trägt ihn über
  „Eigener Kachelserver" ein; dafür ist der Weg da.
  `maps.wikimedia.org` antwortete mit 403.
- **Die Nutzungsrichtlinie der OSM Foundation ist gelesen, nicht vermutet**
  (abgerufen 21.09.2026). Drei Dinge sind daraus Pflicht: ein eigener
  User-Agent (Anfragen mit der Vorgabe einer Bibliothek werden ausdrücklich
  gesperrt — es steht der Name der App darin und eine Adresse, **nie die
  E-Mail des Nutzers**), ein Zwischenspeicher, der die Verfallszeiten des
  Servers achtet (`URLCache`, 256 MB), und ein Deckel (48 Kacheln je Karte;
  darüber sinkt die Auflösung). **Verboten ist das Vorausladen** („bulk
  downloading", „offline use") — einen Knopf, der eine Gegend im Voraus
  holt, gibt es deshalb nicht und darf es nicht geben.
- **Der Lizenzhinweis wird IN das Bild gezeichnet** und ist nirgends
  abschaltbar. Ein Hinweis als eigener Textblock ließe sich verschieben,
  überdecken oder löschen — und stünde dann nicht mehr da, wenn das Buch
  beim Drucker liegt. OpenTopoMap nennt den Wortlaut ausdrücklich
  („Kartendaten: © OpenStreetMap-Mitwirkende, SRTM | Kartendarstellung:
  © OpenTopoMap (CC-BY-SA)"), OSM verlangt ihn sichtbar und nicht hinter
  einem Schalter.
- **CC-BY-SA heißt auch Share-alike, und das gehört gesagt.** Der
  Herausgeber von OpenTopoMap beantwortet die Frage nach dem gedruckten
  Wanderführer mit Ja und ohne Gebühren — verlangt aber, dass die
  abgedruckte Karte unter denselben Bedingungen weitergegeben werden darf.
  Für ein Familienbuch im Schrank folgenlos, für eine Auflage nicht.
- **Entschieden wird an der QUELLE, nicht an der Adresse.** Eine eigene
  Quelle ohne Adresse fiele sonst stillschweigend auf Apple zurück, und der
  Nutzer hielte seinen Kachelserver für einen, der genau so aussieht. Ohne
  Adresse UND ohne Lizenzhinweis gilt die Quelle als unvollständig und die
  Karte bleibt leer — mit einer Zeile, die das sagt.
- **Erst das Mosaik, dann verkleinern** (`Kachelkarte`). Jede Kachel einzeln
  in das verkleinerte Bild zu zeichnen wäre der naheliegende Weg und
  hinterließe an jeder Kachelgrenze einen hellen Haarstrich: Die Ränder
  lägen auf gebrochenen Bildpunkten, und die Glättung rechnet dort mit dem
  weißen Grund.
- **Der Maßstab des Kartenbildes steht FEST auf 2.**
  `UIGraphicsImageRenderer` nähme sonst `UIScreen.main.scale` — und dann
  hinge die Auflösung der gedruckten Karte daran, auf welchem Gerät das Buch
  gerade offen war.
- **Eine leere Kartenfläche hat zwei Gründe, und sie verlangen verschiedene
  Handgriffe**: noch keine Punkte, oder die Karte ließ sich nicht holen.
  Beides gleich aussehen zu lassen wäre ein stummer Befund.
- **Die Karten in Ortswahl und Spurliste bleiben Apples Live-Karten** in der
  Erscheinung der App. Sie sind Werkzeug, nicht Erzeugnis; die Einstellung
  gilt dem gedruckten Bild. Wer das ändert, ändert es für beide.

## Abgleich, Austausch und Tagesspur (ab 1.0.4)

- **Der Abgleich läuft über iCloud DRIVE, nicht über CloudKit** (`Dienste/Wolke.swift`,
  Ansage des Nutzers 09/2026: „über iCloud mit anderen Geräten synchronisieren
  und dies bitte automatisch"). Ein Buch ist eine kleine JSON-Datei und
  zweihundert große Bilder — genau dafür ist ein Dateiabgleich gebaut: Er lädt
  eine Datei erst herunter, wenn sie gebraucht wird, und überträgt ein Bild
  nicht noch einmal, weil im Text ein Komma anders steht. Eine eigene
  Synchronisierung müsste all das nachbauen; wie viel das ist, steht in diesem
  Papier unter Tafelbild, wo sie GEBAUT ist. **Nicht auf CloudKit umstellen,
  ohne diesen Absatz zu widerlegen.**
- **`url(forUbiquityContainerIdentifier:)` BLOCKIERT** und beim ersten Aufruf
  spürbar lange — Apple sagt das ausdrücklich. Es läuft deshalb einmal beim
  Start abseits des Hauptfadens (`Wolke.vorbereiten`), und bis die Antwort da
  ist, arbeitet die App örtlich weiter. Es darf NICHT in einen `init`.
- **`Wolke.wurzel` ist die einzige Stelle, die weiß, wo ein Buch liegt.**
  `Ablage` und `Bildarchiv` fragen dort; zwei Meinungen darüber wären zwei
  Ablagen, und die Bilder lägen auf dem Gerät, während das Buch in der Wolke
  steht.
- **Das Regal HORCHT, statt zu fragen** (`NSMetadataQuery` in `Regal.beobachten`).
  Das ist der Unterschied zwischen „abgeglichen" und „abgeglichen, sobald
  jemand die App neu startet". Zwei Sekunden Ruhe zwischen den Meldungen, sonst
  baut sich das Regal während einer Übertragung zwanzigmal neu auf. **Wer den
  Abgleich in den Einstellungen einschaltet, startet den Beobachter mit**
  (`Regal.wolkeGewechselt`) — sonst liefe er erst nach dem nächsten Start, und
  das sieht aus wie ein Abgleich, der nicht läuft.
- **Konflikte werden nach dem `geaendert` IM BUCH entschieden**, nicht nach dem
  Zeitstempel der Datei. Zwei Gründe: Beim Kopieren bekommt eine Datei ohnehin
  einen neuen, und die Dateizeit steht auf Apples Liste der
  begründungspflichtigen Schnittstellen (dieselbe Lehre wie bei Schulalarms
  Tonbefund). **Die unterlegene Fassung wird NICHT überschrieben**, sondern
  bleibt als `<Kennung>-konflikt-<Zeit>.json` liegen und steht in den
  Einstellungen mit „Diese Fassung nehmen" und „Verwerfen". Ein Abgleich, der
  stillschweigend einen Abend Arbeit wegnimmt, ist schlimmer als zwei Bücher,
  die man vergleichen muss. `Ablage.alle()` überspringt diese Dateien — im
  Regal wären zwei gleich heißende Bücher die schlechtere Art, dasselbe zu
  sagen.
- **Umschalten KOPIERT und löscht nichts**, in beiden Richtungen. Wer
  zurückschaltet, findet seine Bücher auf dem Gerät vor; wer sich vertan hat,
  hat nichts verloren. Ein Buch doppelt ist besser als eines weniger.
- **Ohne iCloud-Recht bleibt die App örtlich und SAGT es.** Fehlt das
  Entitlement oder ist niemand angemeldet, gibt iOS keinen Behälter heraus;
  dann wird der Wunsch zurückgenommen und der Grund genannt. Kein Absperren —
  dieselbe Regel wie bei Schulalarms Mitteilungen.
- **`NSUbiquitousContainers` macht den Ordner SICHTBAR** (Info.plist). Ohne die
  drei Schlüssel läge er versteckt im Behälter, und niemand käme an seine
  Bücher heran, wenn die App einmal nicht mehr da ist. Eine Ablage, die man nur
  mit der App wieder aufbekommt, ist bei einem Tagebuch die falsche.
- **Das Entitlement kann diesen Bau nicht prüfen.** `CODE_SIGN_ENTITLEMENTS`
  steht seit 1.0.4 im pbxproj; GitHub Actions baut mit
  `CODE_SIGNING_ALLOWED=NO` und sieht es nie an. Ob sich signieren lässt,
  entscheidet sich auf dem Mac — und dafür muss die App-Id in der
  Entwicklerkonsole iCloud können und der Behälter
  `iCloud.de.familie.urlaubstagebuch` existieren (in Xcode: Signing &
  Capabilities → + iCloud → iCloud Documents). **Einen grünen Bau nie als
  „signierbar" ausgeben** — dieselbe Regel wie bei Schulalarm.
- **Das Austauschformat ist SELBST geschrieben** (`Dienste/Buchdatei.swift`,
  Endung `.reisebuch`). Zum PACKEN eines ZIP gibt es auf iOS einen
  halböffentlichen Weg (`NSFileCoordinator` mit `.forUploading`), zum
  ENTPACKEN gar keinen. Ein Format, das sich schreiben, aber nicht lesen lässt,
  ist kein Austauschformat, und eine fremde Bibliothek wäre die erste
  Abhängigkeit dieser App. Aufbau: 11 Bytes Kennung, 4 Bytes Kopflänge,
  JSON-Kopf (die Reise plus die Bilderliste mit Längen), dann die Bilddateien
  unverändert hintereinander.
- **Geschrieben wird stückweise, gelesen speicherabgebildet.** Ein Buch mit
  zweihundert Fotos wiegt ein Gigabyte und gehört nicht am Stück in den
  Arbeitsspeicher. Und nach der Dateigröße wird über `resourceValues(forKeys:
  [.fileSizeKey])` gefragt und nicht über `attributesOfItem` — Letzteres liest
  die Zeitstempel mit (ITMS-91053).
- **Erst nachsehen, dann übernehmen.** `Buchdatei.pruefen` sagt, was in der
  Datei steht und ob sie ein vorhandenes Buch überschreiben würde; erst danach
  fragt die App „Ersetzen oder als Kopie". Ein Einlesen, das gleich losschreibt,
  hat keinen Rückweg.
- **Die Tagesspur-Einfuhr liest beide Formate** (`Dienste/Spureinfuhr.swift`,
  Ansage des Nutzers 09/2026: „Ich sehe bislang noch keine Importfunktion für
  Daten aus der Tagesspur-App"). Fotos bringen den Ort mit, an dem jemand stand
  und abgedrückt hat; die Tagesspur kennt den Weg dazwischen.
- **Auch hier kommt der Tag aus DREI ZAHLEN.** Die JSON-Sicherung trägt je Tag
  einen `dayKey` (`2026-07-25`) in der Zeitzone der Aufzeichnung — der Tag, den
  der Mensch erlebt hat, und damit die beste Angabe, die es gibt. Im GPX steht
  derselbe Schlüssel vorn im Spurnamen (`2026-07-25 – iPhone`), und genau
  deshalb wird er dort ABGELESEN und nicht gerechnet. Nur bei einer fremden
  GPX-Datei bleibt die Umrechnung; dann ist die Zeitzone wählbar, und der
  Befund nennt die Zahl der betroffenen Tage. Gesucht wird der Schlüssel nur am
  ANFANG des Namens — „Wanderung am 12.08." ist keiner (dieselbe Falle wie beim
  Textimport).
- **Ein Aufenthalt wird NIE ausgedünnt.** Er trägt einen Namen, und einen
  benannten Ort wegzurechnen, weil er nah am vorigen liegt, nähme genau die
  Angabe weg, für die es ihn gibt. Ausgedünnt wird nur die Strecke, mit
  derselben Regel wie bei den Fotos (`Spurbau.ausgeduennt` — seit 1.0.4 eine
  eigene Funktion, die auch `punkteAusFotos` benutzt; zwei Fassungen desselben
  Ausdünnens liefen auseinander).
- **`Ortsquelle.tagesspur` zählt NICHT als Fotopunkt.** „Aus den Fotos neu
  bauen" lässt solche Punkte stehen — sie sind ausdrücklich eingelesen worden
  und kämen aus keinem Bild zurück. Ein erneutes Einlesen desselben Tages
  ERSETZT sie dagegen: Wer eine Sicherung zweimal wählt, soll nicht die
  doppelte Spur bekommen.

## Ein Tagebuch muss eine neue Fassung überleben (ab 1.0.3)

- Swift baut den Leser einer `Codable`-Struktur selbst — und der verlangt
  JEDEN Schlüssel, **auch wenn die Eigenschaft einen Vorgabewert hat**. Ein
  neues Feld macht damit jede vorher gesicherte Datei unlesbar. Bei einem
  Reisetagebuch ist das der teuerste denkbare Fehler: Es gibt keine zweite
  Ausfertigung. `Reise` und `Reisetag` lesen sich deshalb seit 1.0.3 von
  Hand über `Model/Nachsicht.swift`. Dieselbe Lehre wie bei Anstoß
  („Ablagen müssen Modelländerungen überleben") — dort war sie
  aufgeschrieben und hier nicht gezogen.
- **Die Nachsicht ist GESTAFFELT und deckt damit auch die Typen darunter
  ab.** Ändert sich `Block`, `Seite`, `Gestaltung` oder `Typografie`, fällt
  in `Reisetag` bzw. `Reise` nur das eine Feld auf seinen Vorgabewert
  zurück: Die Seiten eines Tages sind dann leer, und
  `fehlendeSeitenNachholen()` setzt sie beim Öffnen neu. Die Gestaltung
  kostet eine Einstellung, der Inhalt bleibt. **Was NICHT abgedeckt ist**:
  ein Tag ohne `datum` — der reißt die ganze Tagesliste mit. Der Schlüssel
  steht seit 1.0.0 in jeder Datei; wer ihn antastet, baut vorher eine
  nachsichtige Liste.
- **Ein alter Schlüssel wird weiter GELESEN, auch wenn es die Eigenschaft
  nicht mehr gibt** (`AlteSchluessel` in `Model/Reise.swift`). Bis 1.0.2
  hieß die Karteneinstellung `kartenstil` und kannte nur Apples vier Stile;
  sie wird beim Lesen ins neue `kartenbild` gehoben und danach nicht mehr
  geschrieben. Ohne das verlöre jedes Buch von damals seine Einstellung.

- `MARKETING_VERSION` und `CURRENT_PROJECT_VERSION` stehen an je zwei
  Stellen im pbxproj (Debug + Release) — es gibt KEINE Skript-Bauphase.
  **Jede Arbeitseinheit hebt Patch- UND Build-Nummer um je +1**, ohne
  Nachfrage, als Teil des PRs. Zählung ab 09/2026: 1.0.0 (Build 1), dann
  1.0.1 (Build 2) usw. — Stand 09/2026: 1.0.113 (Build 114). Dazu gesetzt:
  `DEVELOPMENT_TEAM = F4989GSTWS` und
  `INFOPLIST_KEY_LSApplicationCategoryType = public.app-category.travel`.
  Seit 1.0.4 steht dort auch `CODE_SIGN_ENTITLEMENTS = Config/Urlaubstagebuch.entitlements`
  (iCloud Documents, seit 1.0.66 wieder `com.apple.developer.user-fonts`
  mit den vom Profil bewilligten Werten)
  — nicht entfernen, sonst liegt der Abgleich still und die selbst
  installierten Schriften bleiben unsichtbar.
- `ITSAppUsesNonExemptEncryption = NO` steht in `Config/Info.plist` UND als
  Build-Einstellung — nicht entfernen.
- Das App-Symbol rechnet `UrlaubstagebuchiOS/scripts/make-icon.py` (reines
  Python, ohne fremde Bibliotheken) — nicht von Hand bearbeiten.
- **ZWEI SEITEN FÜLLEN DEN UMFANG AUF** (`Reise.schmutztitel`, `.schlussseite`,
  `Layoutautomat.schmutztitel`, ab 1.0.98; Ansage des Nutzers 09/2026: „Der
  Druckdienst … nimmt die Datei mit 62 Innenseiten nicht an, wenn das nächste
  Raster bei ihm 64 Seiten ist. Das heißt, er fügt nicht selbst Seiten hinzu,
  sondern möchte, dass ich das mache.").
  - **Die App behauptete bis 1.0.97 das Gegenteil** — `bestellhinweis` sagte
    bei zu wenigen Seiten „Die fehlenden füllt die Druckerei meist mit leeren
    auf". Manche tut das, manche weist die Datei ab; **was gilt, sagt die
    Vorgabe des Anbieters und nicht diese App.** Der Satz sagt das jetzt und
    nennt den Weg zum Auffüllen.
  - **Der SCHMUTZTITEL füllt nicht nur, er gehört dorthin.** Er steht seit
    jeher vorn im Buch: der Titel noch einmal, auf weißem Papier, ohne Bild.
    Gesetzt wird er im Satzspiegel des BUCHES und mit dessen Schriften — er
    wird auf dasselbe Papier gedruckt wie der Text, nicht auf den Umschlag.
    Die SCHLUSSSEITE bleibt leer und weiß.
  - **Einzeln schaltbar, im Ausgabeblatt** („Seiten auffüllen"), also dort,
    wo die Zahl steht, die den Anlass gibt.
  - **Die eigenen Felder liegen NEBEN der gerechneten Seite** — dieselbe
    Bauweise wie bei Titel- und Rückseite seit 1.0.64 und aus demselben
    Grund: Die Seite wird bei jedem Durchgang neu gesetzt, ein Block darin
    wäre beim nächsten Mal weg. Der gerechnete Teil bleibt damit lebendig
    (ein geänderter Titel zieht mit).
  - **`Umschlagflaeche` heißt deshalb seit 1.0.98 `Eigenflaeche`** und meint
    jede gerechnete Seite mit eigenen Feldern. **Zwei Dinge hängen daran, und
    beide wären still falsch gewesen:** Der Satzspiegel eines neuen Feldes ist
    hier der des BUCHES (`satzFuer`) und nicht der des Umschlags — sonst säße
    es um den halben Rücken versetzt —, und ein WASSERZEICHEN liegt auf diesen
    beiden Seiten nie: Die Regel „kein Tag heißt Umschlag" hätte sie über
    `aufTitelblatt` (Vorgabe `true`) mitgenommen, und weiß ist hier Absicht.
  - **Die Kennungen sind FEST** (`Reise.schmutztitelKennung`,
    `.schlussseitenKennung`), wie die der Ausgleichsseite seit 1.0.60: An
    ihnen hängen `ForEach`, `scrollTo`, das Papierkorn, die Lage des
    Wasserzeichens und die Frage, zu welcher Fläche ein Block gehört.
  - **`blockseiten` zählt sie mit**, vor dem Ausgleich — an dieser Zahl hängt
    die Rückenbreite. **Wer eine Seite hinzufügt, trägt sie in BEIDE Zählungen
    ein**: `blockseiten` rechnet, `seitenfolge` setzt, und zwei Zählungen, die
    auseinanderlaufen, ergäben einen Rücken, der nicht auf das Buch passt.
  - Mitgezogen: `Formatwechsel` (ein Rahmen ist eine Länge), `Befundstellen`
    (abgeschnittener Text zählt auch dort), `fotoEntfernen` (ein Block ohne
    Bild wäre eine leere Fläche, an die niemand mehr herankommt).
  - **Nicht gemessen (1.0.98):** Keine Seite ist damit gesehen und keine Datei
    hochgeladen worden. **Gewählt und nicht gemessen** ist die Lage des Titels
    auf dem Schmutztitel (0,28 der freien Höhe). Ob der Druckdienst die Datei
    mit dem aufgefüllten Umfang annimmt, sagt erst der nächste Upload.
- **`tag == nil` TRENNTE UMSCHLAG VON BLOCK — seit 1.0.98 nicht mehr**
  (`Buchseite.zurUmschlagdatei`, ab 1.0.99; gemeldet 09/2026, einen Tag
  nach 1.0.98: „Der Schmutztitel wird dann angelegt im Dokument, jedoch ist
  er in der Druckausgabe nicht enthalten und die zuletzt zugefügte Seite
  auch nicht.").
  - **Am Quelltext abzuzählen, und es ist eine Zeile.** Die Ausgabe siebte
    den Innenteil mit `$0.tag != nil && !$0.amUmschlag`. Schmutztitel und
    Schlussseite tragen keinen Tag — sie gehören dem Buch und nicht einem
    Tag — und fielen damit aus der Datei. Die VOLLE Datei filtert anders
    (`teil != .rueckseite`), dort standen sie; herausgefallen sind sie in
    „getrennt" und „Nur den Innenteil", und das ist bei einem Umschlagbogen
    seit 1.0.52 die VORWAHL. **Merke: Wer eine Seite ohne Tag anlegt, sucht
    jede Stelle, die `tag == nil` für „Umschlag" hält** — die Warnung stand
    seit 1.0.74 im Papier und galt für die neuen Seiten nicht.
  - **Gefragt wird seither POSITIV nach dem Bogen**: `teil != .innen`, dazu
    die Titelseite ohne Bogen an ihrer KENNUNG. Damit sind die beiden
    Zweige wirklich dieselbe Frage, einmal so und einmal andersherum;
    vorher waren es zwei Formeln, die zufällig zusammenpassten.
  - **`schmutzblatt` hat keinen Vorgabewert mehr.** Mit `= nil` wird aus
    „vergessen" ein Buch, dem eine Seite fehlt und das ab dort um eine
    Stelle verrutscht — still. Genau das war die zweite Hälfte desselben
    Fehlers: `Druckpruefung.doppelseitenhintergrund` ruft `seitenfolge`
    selbst und ließ ihn weg, legte also ab dort jede Seite auf die falsche
    Buchhälfte. **Ein Vorgabewert an einem Parameter, dessen Fehlen die
    Zählung ändert, ist kein Komfort, sondern ein stiller Fehler.**
  - **Kennung, Hintergrund und „keine Seitenzahl" stehen an EINER Stelle**
    (`Reise.leererSchmutztitel`, `.leereSchlussseite`). Wer nur die LAGE
    einer Seite braucht, bekommt die Hülle und zahlt keine
    CoreText-Messung; der Automat legt nur noch seine Blöcke hinein.
  - **Und die Druckprüfung vergleicht seither zwei ZÄHLUNGEN**
    (`amPDF(_:erwartet:)`): die Seiten in der Datei gegen `blockseiten`,
    also gegen den Weg, an dem auch Rückenbreite und bestellte Seitenzahl
    hängen. Die Datei mit sich selbst zu vergleichen fände nur einen
    Schreibfehler; dass zwei unabhängige Zählungen um zwei auseinanderlagen,
    hat bis 1.0.98 niemand gesagt — gemerkt hat es der Druckdienst.
  - **Nicht gemessen (1.0.99):** Keine Datei ist damit hochgeladen worden.
    Die Ursache ist abgezählt und erklärt beide Hälften des Befundes;
    ungeprüft bleibt, ob der Dienst die Datei mit dem aufgefüllten Umfang
    annimmt, und die neue Vergleichszeile ist selbst noch nie
    angeschlagen.
- **EIN ABSTURZ NIMMT JEDE MELDUNG MIT, DIE IM SPEICHER STEHT**
  (`Dienste/Absturzspur.swift`, ab 1.0.100; gemeldet 09/2026: „Leider
  stürzt die App nun immer ab, wenn ich ein Foto aus der Galerie auf den
  Schmutztitel positionieren will.").
  - **Die Ursache war am Quelltext NICHT zu finden.** Der ganze Weg ist
    durchgesehen — Wähler, Daten holen, Datei ablegen, Maße lesen, Block
    setzen, Seite zeichnen, Inspektor, Fußleiste, Einrasten,
    Wasserzeichen; jede Stelle ist mit `guard let` und `indices`
    abgesichert, und im ganzen Ziel steht kein einziges erzwungenes
    Auspacken. **Also wird nicht geraten** — in diesem Papier stehen genug
    Fälle, in denen die erste Erklärung eine Vermutung war (das Zoomen der
    Abfahrtstafel dreimal, die Griffe dieser App fünfmal).
  - **Eine Probe, die einen ABSTURZ überleben soll, muss auf die PLATTE,
    bevor der Schritt läuft.** `UserDefaults` sammelt und schreibt später;
    nach einem Absturz ist der Wert oft nicht da. `Absturzspur.beginnt`
    schreibt synchron eine winzige Datei, `endet` räumt sie weg, und was
    beim nächsten Start noch daliegt, steht kopierbar im Regal.
  - **Die Spur bleibt nach dem Einsetzen noch drei Sekunden liegen**
    (`endetSpaeter`). Ob es beim Einsetzen kracht oder beim ersten
    Neuzeichnen danach, ist die entscheidende Hälfte der Frage: Das eine
    wäre ein Fehler im Modell, das andere einer in der Ansicht.
  - **Der Preis gehört dazugesagt:** ein Dateizugriff je Schritt. Er steht
    deshalb nur an den wenigen Schritten, um die es geht, und nie in einer
    Schleife, die je Bildpunkt läuft. **Wer eine Spur an einer heißen
    Stelle einbaut, misst vorher, was sie kostet.**
  - **`max(NaN, x)` GIBT NaN ZURÜCK.** Swifts `max` vergleicht, und jeder
    Vergleich mit NaN ist falsch. Aus einer Höhe von NaN wird ein
    `.frame(height: NaN)`, und daran stirbt SwiftUI mit „Invalid frame
    dimension". In `grafikEinfuegen` ist das Seitenverhältnis seither auf
    `isFinite` geprüft. Beim Suchen gefunden und unabhängig richtig —
    **als Ursache ist es NICHT behauptet.**
  - **`Dictionary(uniqueKeysWithValues:)` TRAPT bei einem Doppel.**
    `Reise.fotoIndex` baute so sein Wörterbuch, und das baut jeder Neusatz
    einer Seite: Zwei Fotos mit derselben Kennung hätten die ganze App
    mitgenommen. `setzeFoto` hält die Liste sauber, `Fotoeinfuhr` hängt
    aber unmittelbar an, und eine eingelesene Buchdatei bringt mit, was
    sie mitbringt. Seit 1.0.100 `uniquingKeysWith`. Ebenfalls beim Suchen
    gefunden und **nicht als Ursache behauptet**.
  - **Nicht gemessen (1.0.100):** Der Absturz ist damit NICHT behoben —
    diese Fassung macht ihn sprechend. Ob der nächste Versuch wieder
    abstürzt, ist offen; wenn ja, steht danach im Regal, in welchem
    Schritt. **Nicht als erledigt darstellen.**
- **EIN FEHLENDER ABSTURZBERICHT IST SELBST EIN BEFUND** (ab 1.0.101;
  gemeldet 09/2026: „Jedes Mal stürzt die App ab, aber es wird nirgendwo
  etwas eingetragen, auch in der Systemsteuerung nicht."). Ein
  gewöhnlicher Absturz legt IMMER einen Bericht ab; bleibt er aus, kommen
  drei Dinge in Frage — und alle drei sind seither unterscheidbar.
  - **DIE APP ZEIGTE IHRE FASSUNGSNUMMER NIRGENDS.** Von außen war nicht
    zu entscheiden, ob auf dem Gerät überhaupt die Fassung lief, über die
    geredet wurde — und genau daran blieb die Diagnose hängen. Sie steht
    jetzt in den Einstellungen, samt Build-Nummer. **Wer über einen
    Befund redet, muss sagen können, woran er entstanden ist.**
  - **WO NICHTS STEHT, HAT DER ERSTE VERMERKTE SCHRITT NOCH NICHT
    GELAUFEN.** Also muss der erste Schritt früher liegen: Die Spur fängt
    seither beim Antippen des Menüpunkts an, vor dem Blatt und vor dem
    fremden Fenster, und der Wähler meldet sich noch einmal, sobald er
    steht.
  - **EIN SPEICHERTOD SCHREIBT KEINEN BERICHT UNTER DEM NAMEN DER APP.**
    iOS legt ihn als `JetsamEvent` ab. Jede Zeile der Spur nennt deshalb
    `os_proc_available_memory` — fällt die Zahl kurz vor dem Ende gegen
    null, ist es keiner Rechnung anzulasten, sondern der Bildgröße.
  - **Eine Spur, die das Lesen mitnimmt, gibt es EINMAL zu sehen.** Bis
    1.0.100 räumte `aufgelesen()` sie gleich weg — begründet damit, ein
    zweimal erscheinender Befund sähe aus wie ein zweiter Absturz. Das
    stimmt und war trotzdem falsch: Wer im falschen Augenblick nicht
    hinsah, hatte ihn für immer verloren. Weggelegt wird jetzt auf
    Tippen. **Merke: Ein Befund, der sich selbst löscht, ist keiner.**
  - **Nicht gemessen (1.0.101):** Der Absturz ist weiterhin nicht behoben
    und seine Ursache nicht bekannt. Diese Fassung macht nur die Frage
    entscheidbar.
- **ZWEI FASSUNGEN, UND MAN SIEHT IHNEN AN, WAS SIE SIND**
  (`Dienste/Konfliktbefund.swift`, `Dienste/Geraetename.swift`,
  `Views/Konfliktansicht.swift`, ab 1.0.102; gemeldet 09/2026: „Ich weiß
  nicht, von welchem Gerät und von wann diese unterschiedlichen Fassungen
  sind. Deshalb kann ich auch nicht beurteilen, welches die aktuelle ist,
  die ich behalten will.").
  - **Das WANN lag die ganze Zeit in den Dateien.** Jede Reise trägt ihr
    `geaendert` — in den Einstellungen stand bis 1.0.101 der DATEINAME und
    sonst nichts, und daneben zwei Knöpfe, von denen einer löscht. Gelesen
    wird jetzt BEIDES, die beiseitegelegte Fassung und die geltende, und
    hingeschrieben wird der UNTERSCHIED (Tage, Fotos, Seiten, Zeichen
    Tagebuchtext, Zeitabstand, abweichender Name). **Mit Sekunden** — ohne
    sie sehen zwei Stände gleich alt aus, die es nicht sind (die Lehre aus
    Tafelbilds Bestandsaufnahme).
  - **Das GERÄT lag nirgends, und das wird GESAGT statt geraten.** Keine
    Fassung dieser App hat es je vermerkt; nachtragen lässt es sich nicht.
    Für jede Konfliktdatei, die heute auf der Platte liegt, steht dort
    „nicht vermerkt". Geschrieben wird es ab 1.0.102 in `Ablage.sichern` —
    der einen Stelle, an der ein Buch auf die Platte geht, und damit der
    einzigen, an der die Angabe gar nicht falsch sein kann.
  - **Den echten Gerätenamen gibt iOS nicht heraus.** Seit iOS 16 liefert
    `UIDevice.current.name` nur die Modellbezeichnung; für den vom Menschen
    vergebenen gibt es ein eigenes Recht. **Eines davon einzutragen, ohne
    dass die App-Id es trägt, hat dieses Projekt in 1.0.44 den ganzen Bau
    gekostet** — das wird nicht wiederholt. Der Name ist deshalb ein selbst
    vergebener: vorbelegt mit Modell plus gewürfeltem Kürzel (sonst hießen
    zwei iPads beide „iPad"), änderbar in den Einstellungen. **Nicht aus
    `identifierForVendor`** — das ist eine Kennung des Geräts und reiste mit
    dem Buch in die Wolke und in jede weitergegebene Buchdatei; ein selbst
    vergebenes Kürzel sagt genauso viel und ist keine.
  - **Gebildet wird der Vorschlag EINMAL beim Start, auf dem Hauptfaden.**
    Gesichert wird ein Buch auch abseits davon, und UIKit gehört dorthin;
    danach kommt `Geraetename.eigener` ohne UIKit aus.
  - **„Diese Fassung nehmen" TAUSCHT, statt zu löschen** (`Wolke.fassungNehmen`).
    Bis 1.0.101 räumte dieser Weg die geltende Fassung weg — ein Tausch war
    damit endgültig, und das ausgerechnet dort, wo jemand gerade zugegeben
    hat, dass er es nicht beurteilen kann. Die bisherige wird jetzt
    ihrerseits beiseitegelegt. Dieselbe Regel, unter der die Konfliktfassung
    überhaupt liegen bleibt: **Ein Abgleich, der stillschweigend einen Abend
    Arbeit wegnimmt, ist schlimmer als zwei Bücher, die man vergleichen
    muss.** Die Bilder bleiben unberührt — beide Fassungen tragen dieselbe
    Kennung und damit denselben Bilderordner.
  - **Wie eine beiseitegelegte Fassung heißt, steht an EINER Stelle**
    (`Wolke.beiseiteName`). Zwei Stellen liefen auseinander, und der Name
    ist kein Schmuck: Vorn steht die Kennung des Buches, daran findet die
    Fassung zurück an ihren Platz und zu ihren Bildern.
  - **Gerechnet wird EINMAL beim Öffnen**, nicht im Körper der Ansicht:
    Dahinter stecken zwei vollständige JSON-Läufe je Konflikt (dieselbe
    Falle wie bei der Netzkarte der Abfahrtstafel). Aus demselben Grund sind
    die Unterschiedssätze GESPEICHERT und nicht berechnet.
  - **Nicht gemessen (1.0.102):** Auf einem Gerät hat das niemand gesehen.
    Am Quelltext abgezählt ist, was in den Dateien steht und was nicht —
    und der zweite Teil ist der wichtigere: **Für die Konfliktdatei, die
    heute auf seinem Gerät liegt, bleibt das Gerät unbekannt.** Diese
    Fassung kann das nicht nachholen; bis beide Geräte einmal gesichert
    haben, steht in mindestens einer Zeile weiter „nicht vermerkt".
    Ungeprüft ist auch, was `UIDevice.current.model` auf Mac Catalyst sagt
    — dort greift der eigene Zweig („Mac").
- **DAS SYMBOL IST EIN BUCH MIT EINEM BILD DARAUF** (`scripts/make-icon.py`,
  ab 1.0.105, Wahl des Nutzers 09/2026 aus fünf Entwürfen: „Foto und Buch
  wären Symbole, die gut zu Fotobuch passen würden"). Buch von vorn,
  Bundlinie links, das Bild auf dem Deckel, darunter zwei Striche als
  Bildunterschrift.
  - **Warum gerade dieser von fünf:** Alle fünf wurden auf vierzig
    Bildpunkte heruntergerechnet und so angesehen — die Prüfung, an der
    der Entwurf vor 1.0.20 gescheitert ist. Bei vieren hängt das Buch an
    einer dünnen **Bundlinie**, und die ist bei dieser Größe weg; übrig
    bleibt ein Fotostapel. Beim gewählten trägt das Buch die ganze Form.
    **Das aufgeschlagene Buch ist dabei zum zweiten Mal durchgefallen** —
    groß gut, klein ein Fleck.
  - Die drei Regeln aus 1.0.20 gelten unverändert (eine Farbe und eine
    Form; die Kontur unter dem Weiß ist keine Zierde; der Verlauf läuft
    diagonal; alles zwischen 140 und 884). **Wer einen neuen Entwurf
    vorschlägt, zeigt ihn zuerst auf vierzig Bildpunkten.**
- **EIN BILD AUS DER MEDIATHEK WIRD ALS DATEI GEHOLT, NICHT ALS BYTES**
  (`loadFileRepresentation`, `Bildarchiv.uebernehmen`,
  `Bildleser.befund(datei: URL)`, ab 1.0.105). Befund des Nutzers, 09/2026:
  „Ich konnte ein kleines Bild auf die letzte freie Seite einfügen. Bei
  meinem größeren Bild ging das nicht. Als ich es jedoch zunächst aus der
  Galerie als Datei exportiert habe und diese Datei dann eingelesen habe,
  ging es."
  - **Das ist die erste Messung an dem Absturz, der seit 1.0.100 offen
    steht**, und sie SCHLIESST AUS: Beide Wege enden in `grafikEinfuegen`;
    `Bildleser`, `Bildarchiv`, das Setzen des Blocks und das Neuzeichnen
    sind bei beiden dieselben. Was sich unterscheidet, ist allein der Griff
    davor. **Merke: Wenn derselbe Inhalt über den einen Weg ankommt und
    über den anderen nicht, liegt es nie an dem, was beide teilen.**
  - `loadDataRepresentation` trägt die ganze Aufnahme durch den
    Arbeitsspeicher (gemessen: 37 MB für EIN Bild); die Datei wird jetzt
    kopiert, und `CGImageSourceCreateWithURL` liest für die Maße ein paar
    Kilobyte statt siebenunddreißig Megabyte.
  - **Die URL im Rückruf gilt NUR, solange der Rückruf läuft** — sie wird
    sofort kopiert, Datei zu Datei.
  - **Die Endung kommt von der GELIEFERTEN Datei.** `registeredTypeIdentifiers`
    sagt, was die Mediathek ANBIETET; geliefert werden kann etwas anderes,
    und dann läge ein JPEG unter dem Namen „heic".
  - **`grafikEinfuegen` gibt es zweimal, der Rest steht EINMAL da**
    (`grafikSetzen`). Der Weg über „Dateien" bleibt absichtlich
    unverändert — er funktioniert, und eine Sache wird auf einmal geändert.
  - **Nicht gemessen (1.0.105):** Der Befund isoliert die Stelle, er
    beweist die URSACHE nicht. Zwei Erklärungen passen weiter, und beide
    werden getroffen: ein Speichertod (dafür legt iOS keinen Bericht unter
    dem Namen der App ab — das passt zu „es wird nirgendwo etwas
    eingetragen") oder ein `loadDataRepresentation`, das für dieses eine
    Bild nichts zurückgab. **Gegen die reine Speichererklärung spricht,
    dass der Weg über „Dateien" dieselben Bytes in den Speicher holt** —
    es sei denn, die exportierte Datei war kleiner als das Original, was
    beim Export aus der Mediathek der Regelfall ist. Welche der beiden es
    war, sagt die Absturzspur.
- **DIE ZAHLEN ENTLASTEN DREI STELLEN — ALSO LIEGT ES AN DER VIERTEN**
  (`Ladebild` an elf Stellen, `Tempomesser.sammeln`, ab 1.0.104). Die Messung
  aus 1.0.103 hat geantwortet, und zwar gegen meine eigene Vermutung: Regal
  lesen 190 ms (2 Bücher), Buch sichern 78 ms (6117 KB JSON), Bild aus der
  Mediathek 53 ms (37721 KB). **Keine der drei Zahlen erklärt „das Öffnen
  dauerte."** Eine Probe, die drei Stellen entlastet, ist nicht gescheitert —
  sie sagt, wo NICHT zu suchen ist (dieselbe Lehre wie die Zeile „Soll/Ist"
  in Abfahrtstafel 1.0.24, die die Geometrie entlastet hat).
  - **Was übrig bleibt, stand seit 1.0.81 als offener Punkt da**, wörtlich:
    „Die Listen und Blätter (Regal, Tagesliste, Hintergrundwahl, Stilwahl)
    holen ihre kleinen Bilder weiterhin synchron; sie scrollen auch, sind
    aber nicht der gemeldete Fall." **Jetzt sind sie es** — das Regal ist das
    erste, was beim Start zu sehen ist, die Tagesliste das erste beim
    Aufschlagen eines Buches. **Merke: Ein offener Punkt, der zweimal als
    „nicht gemessen" dasteht, ist beim dritten Befund der erste Verdacht.**
  - **Es waren ELF Stellen, nicht vier** (dazu Fotoliste, Wasserzeichen
    dreimal, Titelfotowahl, Probebild und Randanteil). Sie holen ihre Bilder
    seit 1.0.104 über `Ladebild` — dieselbe Bauweise wie die Bühne seit
    1.0.81; ein zweiter Weg wäre ein zweiter Weg zu derselben Sache.
  - **Ein `.task` läuft auf dem HAUPTFADEN.** Im Hintergrundblatt lagen darin
    zwei Entpackvorgänge (900 und 600 Punkte Kante) und ein Lauf über jeden
    Bildpunkt (`Farbkraft.randanteil`). Es sah aus wie „abseits" und war nur
    „später".
  - **Der Hebel ist die Größe der Aufnahme:** Ein Kärtchen von 120 Punkten
    Kante wird aus einer Datei von 37 MB gerechnet. Ein Vorschaubild ist nie
    teuer, weil es klein ist, sondern weil das Original groß ist.
  - **Was oft und kurz ist, wird GEZÄHLT und nicht überschrieben**
    (`Tempomesser.sammeln`): Zahl UND Summe, mit Neubeginn nach zwanzig
    Sekunden Ruhe (**gewählt, nicht gemessen**). `melde` behält nur das
    letzte — eine Zeile „Vorschaubild: 40 ms" sähe harmlos aus, während
    dreißig davon anfielen.
  - **Drei neue Messstellen:** „Buch öffnen" („Regal lesen" misst nur das
    Entziffern der Bücher, nicht das Aufschlagen eines Buches), „Bild
    ablegen" (die 37 MB auf die Platte) und „Bild von Platte".
  - **Nicht gemessen (1.0.104):** Auf einem Gerät hat das niemand gesehen.
    Abgezählt ist, WO die synchronen Griffe lagen; **dass der Mac danach
    flüssig ist, folgt daraus NICHT.** Die Kette NACH dem Ablegen eines Bildes
    (Rückgängig-Stapel, Sichern, Neuzeichnen) ist bewusst nicht umgebaut —
    dort steht seit 1.0.100 ein ungeklärter Absturz offen, und zwei
    Änderungen auf einmal ließen den nächsten Befund nicht mehr zuordnen.
- **EIN GIGABYTE GEHÖRT NICHT AUF DEN HAUPTFADEN** (`Views/Arbeitsanzeige.swift`,
  `Dienste/Tempomesser.swift`, ab 1.0.103; gemeldet 09/2026 vom Mac: „Das
  Öffnen dauerte, das Aussuchen eines Bildes aus der Fotogalerie dauerte …
  Nun habe ich mehrfach versucht, das Buch als Datei zu sichern und die App
  reagiert nicht mehr. Es läuft nur der sich drehende farbige Ball.").
  - **Der Hänger ist abzuzählen, nicht zu vermuten.** `Buchdatei.schreiben`
    liest und schreibt jedes Bild des Buches — bei zweihundert Fotos ein
    Gigabyte —, und bis 1.0.102 stand der Aufruf nackt in einer Ansicht,
    also auf dem Hauptfaden. Dasselbe galt für `einlesen` und `pruefen`.
    Beides läuft jetzt in einer abgesetzten Aufgabe.
  - **`Task.detached` ERBT DEN ABBRUCH NICHT.** Wer nur die äußere Aufgabe
    abbricht, hat einen Knopf gebaut, der nichts tut, und das Gigabyte
    liefe weiter. Gehalten und abgebrochen wird deshalb die abgesetzte
    Aufgabe selbst (`abbruch` in `ReiseView` und `RegalView`).
  - **Die Anzeige liegt über allem und nimmt die Tipps an.** Er hat es
    „mehrfach versucht" — jeder weitere Tipp stieß dieselbe Arbeit noch
    einmal an. Gelesen wird der Stand im EIGENEN Takt (`Arbeitsmelder`,
    fünfmal je Sekunde) statt bei jeder Meldung auf den Hauptfaden zu
    springen; bei einem Gigabyte wären das hundert Sprünge für eine
    Anzeige, die nicht feiner ist. Dieselbe Bauweise wie `Zeichenmesser`
    und `Inhaltslage`: eine schlichte Klasse OHNE `@Published`.
  - **Über iCloud steckt das Schlimmere dahinter:** Ein Bild, das noch
    nicht heruntergeladen ist, wird beim ersten Zugriff geholt — je Bild,
    der Reihe nach. Genau deshalb steht die Leseprobe im ersten Durchgang
    und nicht auf dem Hauptfaden.
  - **DER KOPF DARF NICHTS VERSPRECHEN, WAS NICHT DASTEHT.** Bis 1.0.102
    wurde der Kopf aus der Dateigröße gebaut; ließ sich eine Bilddatei
    danach nicht öffnen, sprang die Schleife mit `continue` darüber hinweg.
    Die Datei ist ab dieser Stelle verschoben und wird beim Einlesen als
    „unvollständig" abgewiesen — auf einem anderen Gerät, Tage später, ohne
    dass jemand wüsste warum. Jetzt: erst prüfen, was sich wirklich öffnen
    lässt, nur DAS in den Kopf, jede geschriebene Länge gegenzählen, und
    was fehlt, wird genannt. Bricht etwas ab, wird die halbe Datei
    weggeräumt — eine halb geschriebene Buchdatei sieht aus wie eine.
  - **Eine Kiste trägt das Ergebnis über die Fadengrenze** (`Kiste`,
    `@unchecked Sendable`). Geschrieben wird einmal in der Aufgabe, gelesen
    erst nach dem `await` — dazwischen liegt die Sperre. Der Umweg
    erspart, dass der halbe Datenbestand des Buches `Sendable` sein muss.
  - **Die beiden anderen Sätze sind ein EINDRUCK, und darauf wird keine
    Fassung gebaut** (`Tempomesser`). Gemessen wird an den Stellen, die in
    Frage kommen — Regal lesen (jedes Buch wird als JSON entziffert), Buch
    sichern, Buchdatei schreiben, ein Bild aus der Mediathek holen —, und
    die Zahlen stehen in den Einstellungen unter „Tempo", jede mit ihrem
    Zeitpunkt. Dasselbe Muster wie Schulalarms Stufenprobe.
  - **Der Weg über die Fotomediathek ist mit Absicht NICHT angefasst**
    (außer der Messung): Dort steht seit 1.0.100 ein unerklärter Absturz
    offen, und zwei Änderungen auf einmal ließen den nächsten Befund nicht
    mehr zuordnen.
  - **Nicht gemessen (1.0.103):** Auf einem Gerät hat das niemand gesehen.
    Abgezählt sind die beiden Ursachen; **dass der Mac danach flüssig ist,
    folgt daraus NICHT** — Öffnen und Bildwahl sind unverändert, sie sagen
    jetzt nur, wie lange sie brauchen.
- **DIE ÜBERGABE AUS FERNWEH** (`Dienste/Fernweheinfuhr.swift`,
  `Views/FernwehimportView.swift`, ab 1.0.106; Ansage des Nutzers 09/2026).
  Der Vertrag steht in `FernwehiOS/docs/UEBERGABE.md` — **wer hier ein Feld
  anders liest, ändert das Papier mit.** Plus-Knopf → „Aus Fernweh…" und
  ganz oben in „Buch aufbauen".
  - **Der ZIP-Leser kopiert die Datei nicht mehr** (`Zipleser.verzeichnis`,
    `.inhalt`). Bis 1.0.105 wurde jedes Archiv erst ganz in ein `[UInt8]`
    kopiert — für eine `.docx` gleichgültig, für eine Übergabe mit
    Originalen Gigabyte im Arbeitsspeicher. Geöffnet wird mit
    `.mappedIfSafe`, und `subdata` kopiert nur den einen Eintrag.
  - **Jede Liste ist nachsichtig** (`Nachsichtig<T>`): ein unlesbares
    Element wird übersprungen und GEZÄHLT, statt die ganze Reise
    mitzunehmen. Der erzeugte Leser eines Arrays scheitert am ersten
    falschen Element. Eine NEUERE Fassungsnummer wird abgewiesen, nicht
    erraten.
  - **Die Kennung des Fotos aus Fernweh wird die Kennung im Buch.** Zweimal
    dieselbe Datei eingelesen ergibt jedes Foto einmal. Der Tag eines Fotos
    ist der des EINTRAGS (Vertrag). EXIF geht vor den Angaben der JSON; eine
    Kopie hat keins.
  - **Fotos ohne Bild** (Fernwehs Vorgabe ist „ohne Fotos") holt die App aus
    der eigenen Mediathek: erst über `PHCloudIdentifier` (gilt auf jedem
    Gerät derselben Apple-ID), dann über die lokale Kennung. Was nicht zu
    holen ist, wird gezählt und gesagt. **Doppelt kann es trotzdem werden**,
    wenn jemand dieselben Fotos danach noch einmal über „Fotos aus der
    Mediathek" einliest — die Fotoeinfuhr kennt keine Kennung zum Abgleichen.
  - **Zeiten: Augenblick → Wanduhr am Ort**, je Tag die Zone am ersten Ort
    (`Zonensucher`), sonst die eingestellte — dieselbe Regel wie bei der
    Tagesspur. Umgerechnet wird erst beim ÜBERNEHMEN (`amOrt`), damit ein
    erneutes Nachschlagen nicht doppelt rechnet. Die weiteren Orte eines
    Eintrags tragen nur „10:40"; der Versatz dazu kommt vom Zeitpunkt des
    Eintrags (Zone des schreibenden Geräts).
  - **Mehrere Spuren je Tag sind mehrere GERÄTE auf demselben Weg** —
    genommen wird die längste, und die Vorschau sagt es. Benannte Orte
    werden nie ausgedünnt.
  - **Die Punkte tragen `Ortsquelle.tagesspur`, mit Absicht kein eigener
    Fall.** `Reisepunkt` hat den erzeugten Leser; eine ältere Fassung, die
    dasselbe Buch über iCloud öffnet, verwürfe an einem unbekannten Rohwert
    die ganze Spur des Tages. Preis: Tagesspur- und Fernweh-Einfuhr ersetzen
    einander die Punkte desselben Tages.
  - **Das Wetter hat kein eigenes Feld**; auf Wunsch steht es als eine Zeile
    unter dem Text des Tages, eine Vorhersage als „Wetter (Vorhersage)".
  - **Ein Zug, ein Widerrufen:** Erst werden die Bilder abseits des
    Hauptfadens abgelegt, dann wird das Buch mit EINEM `merken()` geändert.
    Das Einsetzen einer Spur steht dafür seit 1.0.106 an einer Stelle
    (`Reisewerk.tagesspurEinsetzen`), gefragt von beiden Einfuhren.
  - **Nicht gemessen (1.0.106):** Keine echte `.fernweh`-Datei ist hier
    gelesen worden — gebaut ist nach dem Papier. Ungeprüft sind vor allem
    die Mediathek-Zuordnung über `PHCloudIdentifier` und wie lange eine
    Übergabe mit Originalen braucht. **Nicht als erledigt darstellen.**
  - **Woher die Orte kommen, entscheidet der Mensch** (`Fernwehwunsch.orte`,
    Abschnitt „Orte" im Blatt, ab 1.0.107; Ansage des Nutzers 09/2026: „ob
    die Ortsangaben (Fotos, Wanderungen) mit übernommen werden sollen, oder
    ob die App sie selbst anhand der Fotos erstellt"). **Aus Fernweh**
    (Vorgabe, der Stand von 1.0.106): Spur, benannte Orte und die Fotoorte
    aus der JSON. **Aus den Fotos**: Spur und Orte der Datei bleiben
    draußen, ein Foto bekommt seinen Ort aus dem EXIF und sonst aus dem
    Aufnahmeort des Bildes in der EIGENEN Mediathek — die Koordinate aus
    der Datei wird dann bewusst NICHT genommen, auch wenn sie da ist; was
    dadurch ohne Ort bleibt, wird gezählt und gesagt. Die Reisepunkte baut
    danach derselbe Weg wie bei jeder Fotoeinfuhr (`spurAktualisieren`).
    **Eine schon vorhandene Spur bleibt stehen**, außer mit „ersetzen" —
    dann gehen alle `.tagesspur`-Punkte des Tages, also auch die aus der
    Tagesspur-App (sie tragen dieselbe Quelle, siehe oben); das Blatt sagt
    es. **Nicht gemessen:** an keiner echten Datei und keiner echten
    Mediathek gesehen.
  - **Einzelne Filter, und das Wetter hat ein eigenes Feld** (ab 1.0.108;
    Ansage des Nutzers 09/2026: „Tagebuch erstellt eine Gesamtdatei,
    Fotobuch hat einzelne Importfilter (Wetter, Fotos, Orte…)"). Im Blatt
    „Was übernommen wird": Texte und Überschriften, Wetter (eigene Zeile /
    unter den Text / nicht), Fotos; dazu die Orte. `Reisetag.wetter` ist
    TEXT (änderbar wie jede Zeile), `Blockinhalt.wetter` die Zeile auf der
    Seite, gesetzt in der Rolle `.datum` — keine eigene Schriftrolle, sonst
    wäre `Typografie` samt Leser, Stilen und Schrift-Blatt mitgewachsen.
    Nur auf dem Aufmacher, unter der zweiten Überschrift; auf der
    ganzseitigen Aufmacherseite in derselben hellen Farbe wie das Datum,
    und seine Höhe geht VOR `y` in die Rechnung ein.
    **Ein Tag mit Handarbeit wird nicht neu gesetzt** — dort erscheint die
    Zeile erst nach „Seiten neu anordnen", und der Bericht zählt diese Tage.
  - **Ein neuer `Blockinhalt`-Fall ist eine Einbahnstraße.** Eine ÄLTERE
    Fassung liest eine Seite mit Wetterzeile über `b.wert(.bloecke, [])`
    und bekommt eine LEERE Seite; sichert sie danach (über iCloud),
    ist der Satz dieser Seite weg. Dieselbe Lage gab es bei
    `.unterueberschrift` (1.0.48) und `.kartenunterschrift` (1.0.87). Seit
    1.0.108 liest `Seite` ihre Blöcke einzeln (`Nachsichtig<Block>`): Ein
    unbekannter Block fällt allein weg — das schützt erst die FOLGENDEN
    Fassungen. **Vor einem Import mit Wetterzeile alle Geräte auf 1.0.108
    bringen.**
  - Beim Umbau gefunden: Das Muster „halbseitig" räumte vor dem Neulegen
    des Kopfes Datum, Titel und Linie weg, die zweite Überschrift aber
    nicht — sie stand dort doppelt. Weggeräumt wird seither alles, was
    `kopfzeile` legt.
- **SEITEN, WANDERUNGEN UND BILDTEXTE AUS FERNWEH** (`Fernweheinfuhr`, ab
  1.0.109; Ansage des Nutzers 09/2026 in Fernweh 1.0.17: Reisen im
  Nachhinein mit Texten zu den Fotos, freien Seiten und Komoot-Wanderungen —
  „All dies möchte ich ins Fotobuch exportieren können"). Alles im Vertrag
  ANGEHÄNGT (Fassung bleibt 1, `FernwehiOS/docs/UEBERGABE.md`).
  - **Der Text zum Foto wird die BILDUNTERSCHRIFT**, eingeschaltet — jemand
    hat ihn eigens geschrieben. Steht das Foto schon im Buch, wird er nur
    eingetragen, wo noch keine Unterschrift steht: Was im Buch geschrieben
    wurde, bleibt.
  - **Eine Wanderung ist kein GERÄT.** Ihre Strecke steht als Spur mit
    `geraet` = `wanderung:<Kennung>` in der Datei. Bis 1.0.106 wurde von
    mehreren Spuren eines Tages die mit den meisten Punkten genommen — eine
    Wanderung neben der Tagesspur wäre damit entweder verloren gegangen oder
    hätte den Rest des Tages verdrängt. Jetzt: die beste GERÄTEspur PLUS
    jede Wanderung, nach der Zeit eingeordnet (beide tragen echte
    Augenblicke); liegen sie auf demselben Weg, legt das Ausdünnen sie
    zusammen. Die Vorschau sagt „mit 1 Wanderung".
  - **Die Zahlen der Tour stehen als eine Zeile im Text** („Wanderung
    09:12–15:40 · 14,2 km · 5:48 h · 620 m bergauf"), unter ihrem Titel.
    Die Uhrzeiten schreibt Fernweh schon als Wanduhr am Ort — sie werden
    NICHT umgerechnet.
  - **Die Überschrift des Tages kommt aus einem GEWÖHNLICHEN Eintrag**, wenn
    es einen mit Titel gibt. Eine Einleitungsseite oder eine Tour am Morgen
    ist nicht das, worüber der Tag steht; ihr Titel steht dann als Zeile im
    Text, wie der jedes späteren Eintrags.
  - **Eine freie Seite bekommt keine eigene Buchseite**, sondern steht als
    Absatz mit Titel im Text ihres Tages. Eine eigene Seite hieße, eine Seite
    zu setzen, die in keinem Tag liegt — und genau das hat diese App bei
    Schmutztitel und Schlussseite (1.0.98/1.0.99) zwei Fassungen gekostet.
  - **Nicht gemessen (1.0.109):** Keine echte `.fernweh`-Datei mit diesen
    Feldern ist hier gelesen worden — gebaut nach dem Papier. **Nicht als
    erledigt darstellen.**
- **DAS WETTER DES TAGES STEHT MIT SEINEM ORT DA** (`Fernweheinfuhr.wetterzeile`,
  ab 1.0.110; Ansage des Nutzers 09/2026 in Fernweh 1.0.18). Fernweh
  übergibt seither je Tag ein Wetter samt Ort (`tage[].wetter`,
  `.wetterOrt`), auch für Tage nur mit Spur. Gelesen wird es NUR, wo kein
  Eintrag des Tages eines trägt — das des Eintrags gilt an dessen Ort. Die
  Zeile nennt den Ort jetzt („Wetter in Lissabon: Morgens …"), denn an einem
  Reisetag ist das oft ein anderer als der, an dem abends geschrieben wurde.
  Die Abschnittsnamen („Morgens, Mittags, Nachmittags, Nachts", in älteren
  Dateien „Vormittag …") werden gedruckt, wie sie kommen. **Nicht gemessen
  (1.0.110):** an keiner echten Datei. **Nicht als erledigt darstellen.**
- **EIN DRUCKPRODUKT SETZT ALLES, WAS DIE DRUCKEREI VORGIBT, AUF EINMAL**
  (`Model/Druckprodukt.swift`, `Model/Saalprodukte.swift`,
  `scripts/saal-produkte.py`, Abschnitt „Druckprodukte · Saal Digital" im
  Formatblatt, ab 1.0.111; Ansage des Nutzers 09/2026 mit Saals Seite
  „Profibereich" vor Augen: „Verwende sie, so dass nach Auswahl des Formates
  ‚Saal Digital 21x28 hochkant' diese automatisch angewendet werden. …
  Übernimm alle Formate und alle Maße.").
  - **Die Zahlen sind GEHOLT, nicht abgeschrieben.** Die Seite trägt die
    Tabelle nicht als Text; ihr Skript lädt sie von
    `services.saal-digital.net/designservice/api/Configurator/GetFormats`
    (Händler- und Artikelgruppenkennung stehen im Quelltext der Seite).
    Gefragt wird mit Einheit „mm" und je Papiersorte, denn die Rückenbreite
    hängt am Papier. Das Skript schreibt `Saalprodukte.swift` — **nicht von
    Hand bearbeiten**, sondern neu holen. Gemessen am 26.09.2026: 51 Produkte
    in sechs Reihen (Hardcover, Hardcover XT, Softcover, Professional Line,
    Professional Line XT, Portfolio Album). **Eine Antwort (42 × 28) kam in
    Zentimetern, obwohl mm verlangt war** — das Skript erkennt es an der
    Größenordnung und rechnet um; wer es neu schreibt, prüft das mit.
  - **Innenseiten sind bei Saal DOPPELSEITEN, Beschnitt nur außen**
    (`anschnittAmBund = false`). Aus Saals Vorlage folgt das Endformat einer
    Seite — beim „21 × 28" sind das 210 × 270 und nicht 210 × 280, dieselbe
    Abweichung, die 1.0.54 schon an den Bildschirmfotos gemessen hatte. Das
    Portfolio Album liefert Einzelseiten mit Beschnitt ringsum.
  - **Saals Rückenspalte und seine Bogenbreite gehen nicht zusammen auf.**
    Mit einer festen Hälfte lässt sich nur eines von beiden treffen (bis zu
    3,4 mm auseinander). Getroffen wird die BOGENBREITE, denn die prüft der
    Dienst an der Datei; der gesetzte Rücken ist `Bogen − 2·Beschnitt −
    2·Hälfte` und liegt bis zu gut 1,5 mm je Seite neben Saals Angabe — im
    Falzbereich (9–17 mm), in den ohnehin nichts Wichtiges gehört. Beide
    Zahlen stehen im Blatt nebeneinander.
  - **Seitlich schneidet Saal oft mehr ab als oben und unten** (21 × 28:
    9,3 gegen 7 mm). Diese App kennt EINEN Beschnitt je Bogen; gesetzt wird
    der von oben/unten, der Rest steckt in der Hälfte. Das Blatt sagt es
    dazu: Wichtiges nicht bis an die äußere Umschlagkante legen.
  - **Professional Line und Portfolio Album haben keinen Umschlag mit
    Rücken**, sondern ein eigenes Deckelteil. Gesetzt werden dort nur die
    Innenseiten; die Umschlag-Einstellungen bleiben, und das Maß des Teils
    steht als Auskunft da.
  - **Die Tabelle des Produkts geht über `tabellenvorlage`**, nicht über
    `Rueckentabellen.alle`: `passend(zu:)` liefe sonst über 51 Tabellen mit
    gleichen Formaten und nähme still die erste Papiersorte.
    `Rueckentabellen.vorlage(_:)` schlägt beide Listen nach, und der Name
    eines Produktformats kommt aus `Druckprodukt` (`Seitenformat.name`).
  - **Das Format zuerst, der Rest danach.** `Formatwechsel` rechnet ein
    eigenes Umschlagformat mit — setzte das Produkt seine Hälfte vorher,
    stünde sie hinterher um den Faktor daneben. Das Wechselblatt bekommt das
    Produkt deshalb mit und wendet es NACH dem Umrechnen an, im selben
    `merken()`. Eine eingetragene Rückenstärke und eine eigene Tabelle
    werden dabei entfernt (sie gingen sonst vor und stammen fast immer von
    einer anderen Druckerei); das Blatt sagt es vorher.
  - **Nicht gemessen (1.0.111):** Keine Datei ist damit bei Saal
    hochgeladen worden. Gemessen ist die Antwort der Schnittstelle am
    26.09.2026; ändert Saal sein Angebot, merkt diese App nichts davon —
    dann Skript neu laufen lassen. **Nicht als erledigt darstellen.**
- **BEI SAAL IST SEITE 1 EINE LINKE — U2 UND U3 GEHÖREN IN DEN INNENTEIL**
  (`Umschlag.innenseitenImBlock`, `Buchseite.imBlock`, ab 1.0.112; Ansage
  des Nutzers 09/2026, nach einer ersten gegenteiligen Angabe berichtigt:
  „Es ist doch so, dass bei Saal Digital die erste Seite eine linke Seite
  ist und die Innenseite des Umschlages darstellt.").
  - **Gemessen, nicht übernommen:** Saals Innenvorlage für 26 Seiten
    (`GetTemplate`, 26.09.2026) sind 13 volle Doppelseiten von 420 × 270 mm
    — keine halbe am Anfang, keine am Ende. Die erste Hälfte ist also die
    Innenseite des vorderen Deckels (bedruckt, verklebt), die letzte die des
    hinteren, und **beide zählen in Saals Seitenzahl** und damit in seiner
    Rückentabelle. Die Umschlagdatei trägt nur die Außenseite.
  - **Die LAGE gab es seit 1.0.74** (`innenseitenInhalt`: erste Inhaltsseite
    auf U2 links, letzte auf U3 rechts). Neu ist nur, WOHIN die beiden
    geschrieben werden. Entschieden wird das an der Seite selbst:
    `Buchseite.imBlock`, vergeben in `seitenfolge` wie Nummer und Bogen, und
    `amUmschlag` ist dann falsch. **Damit ziehen alle Stellen, die
    `amUmschlag` fragen, von selbst mit** — Maß, Anschnitt und Satzspiegel
    des Buchblocks (`Reise.flaeche`), die Innenteil-Datei
    (`zurUmschlagdatei`), die Doppelseiten-Datei (sie fragt seither
    `!amUmschlag` statt `teil == .innen`; der erste Bogen ist U2 | 1, keiner
    bleibt halb), die volle Datei. `umschlagPdf` lässt die zweite Seite weg,
    `blockseiten` zieht die zwei nicht ab.
  - **Die Seitenzahl fragt `teil == .innen`**, nicht mehr `!amUmschlag`: U2
    trägt die Nummer 0, und eine „0" auf einer verklebten Seite wäre falsch.
    **Wer eine neue Stelle baut, die „Umschlag oder nicht" fragt, entscheidet,
    ob sie den BOGEN meint (`amUmschlag`) oder den TEIL** — seit 1.0.112 ist
    das nicht mehr dasselbe.
  - **Ein Saal-Produkt mit Doppelseiten schaltet es ein** (`Druckprodukt.anwenden`:
    Bogen, U2+U3 mitliefern, Inhalt darauf, im Innenteil). Das Blatt davor
    sagt es, dazu Saals Strichcode auf der letzten Innenseite (7,8 × 5,6 mm,
    8,9 mm von rechts, 4,1 mm von unten — Tabelle „Barcode" derselben
    Schnittstelle).
  - **Am Bund der Innenseiten gibt es bei Saal KEINEN Abstand zu halten.**
    Gefragt 09/2026, weil Saal einen „Abstand" nennt: Das ist der
    Falzbereich des UMSCHLAGS (9–17 mm um den Rücken). Die Innenvorlage hat
    außer der Mittellinie keine Hilfslinie; die Seiten liegen flach
    (Layflat). Der eigene Sicherheitsabstand am Bund bleibt, was er ist —
    eine Entscheidung, keine Vorgabe.
  - **Nicht gemessen (1.0.112):** Keine Datei ist damit bei Saal
    hochgeladen worden. Gerechnet ist die Zählung (26 = 24 + U2 + U3) und
    die Paarung. **Nicht als erledigt darstellen.**
- **WHITEWALL: DIE ZAHLEN STEHEN IN DEN INDESIGN-VORLAGEN**
  (`Model/Whitewallprodukte.swift`, `scripts/whitewall-produkte.py`, ab
  1.0.113; Ansage des Nutzers 09/2026: „Ich möchte, dass du die Formate von
  ‚Whitewall' und die entsprechenden Seitengrößen auch importierst … Ich
  hoffe, dass die Schnitt- und Sicherheitsabstand-Markierungen automatisch
  gesetzt werden.").
  - **Die Schnittstelle der Seite verlangt ein CSRF-Zeichen** und war von
    hier aus nicht zu fragen. Die VORLAGEN liegen dagegen offen unter
    `downloads.whitewall.com/indesign/{cover|block}_<Format>_paper-<Papier>_<Seiten>.idml`
    (den Weg hat der Nutzer geschickt). Eine IDML ist ein ZIP:
    `Resources/Preferences.xml` trägt Seitenmaß und Beschnitt, die Spreads
    die Hilfslinien. Das Skript holt alle 1146 (sechs Formate × sechs
    Papiere × 28 bis 200 Seiten in Viererschritten) und schreibt die Datei
    — **nicht von Hand bearbeiten**. Die Namen der Formate und Papiere
    stehen in keiner abrufbaren Liste; sie sind durch Nachfragen gefunden
    (eine falsche Adresse antwortet mit 403).
  - **Der Rücken wächst in STUFEN** — A4 hoch auf Fuji-Papier: 28 und 32
    Seiten beide 11 mm, dann +1,5 mm je acht Seiten. Aus zwei Fotos
    dazwischen zu rechnen, wie der Nutzer anbot, hätte an genau diesen
    Stufen danebengelegen; gelesen ist deshalb jede Seitenzahl einzeln.
  - **Die frühere Druckerei des Nutzers WAR WhiteWall.** Die Werte aus
    1.0.85 (208 × 276, Beschnitt 3 | 3 | 3 | 0) und 1.0.91 (Bogen 457 × 295,
    10 mm Beschnitt, 17 mm Rücken, Hälfte 210 × 275) stehen Zahl für Zahl
    in den Vorlagen von Exhibition A4 hoch. Die Einstellungen von damals
    waren also schon richtig; neu ist, dass ein Tipp sie setzt.
  - **Der Sicherheitsabstand kommt jetzt mit** (`Druckprodukt.sicherheitsabstand`,
    `.sicherheitsabstandInnen`): 5 mm oben, unten, außen, am Bund 0 — so
    stehen die Ränder in der Vorlage, die Seiten liegen flach. Damit setzt
    das Produkt die blaue Linie, und die rote Marke aus 1.0.81 greift von
    selbst. Bei Saal bleibt `nil`: Saal nennt für die Innenseiten keinen.
  - **Seite 1 ist bei WhiteWall RECHTS** (`seiteEinsLinks = false`):
    Vorsatzpapier, U2 und U3 werden nicht bedruckt, die Umschlagvorlage ist
    EIN Bogen. `anwenden` schaltet die vier U2/U3-Schalter deshalb
    ausdrücklich AUS — ein Buch, das vorher ein Saal-Produkt trug, hätte
    sonst die erste Tagebuchseite auf dem Deckel stehen.
  - **„Ohne Transparenz" wird NICHT von selbst eingeschaltet**, obwohl
    WhiteWalls Exportvorgabe (`.joboptions`) es verlangt. Der Schalter
    lebt im Ausgabeblatt und nimmt die Wasserzeichen ganz heraus; das ist
    eine Entscheidung über das Buch und keine Maßangabe. Das Blatt davor
    sagt es. (Im Gespräch war zuerst das Einschalten angekündigt — die
    Abweichung ist dem Nutzer gesagt.)
  - **Die Seitenzahl wächst in Viererschritten** (`seitenSchritt`); das
    steht als Auskunft da und wird nicht erzwungen.
  - **Ein Abschnitt je Anbieter** im Formatblatt, die Saal-eigenen Sätze
    (Rückenspalte, Falzbereich, Strichcode) nur bei Saal (`istSaal`).
  - **Nicht gemessen (1.0.113):** Keine Datei ist bei WhiteWall
    hochgeladen worden. Gelesen sind die Vorlagen vom 26.09.2026; ändert
    WhiteWall sie, Skript neu laufen lassen. **Nicht als erledigt
    darstellen.**
- **Offen: Ob die Schriften im PDF ankommen, ist nicht gemessen.** Der Text
  wird als Text gesetzt; ob iOS eine Systemschrift einbettet oder nur
  benennt, lässt sich erst an einem echten Ausdruck sehen. **Nicht als
  erledigt darstellen.** Ebenso ungemessen: wie sich ein Buch mit
  zweihundert Fotos anfühlt.
- Übersetzt wird in GitHub Actions (`.github/workflows/ios-apps-build.yml`,
  Eintrag `("UrlaubstagebuchiOS", "Urlaubstagebuch")` in `welche-apps.py`).
  **Erst pushen, Bau abwarten, Fehler beheben — den PR-Link erst
  herausgeben, wenn der Bau grün ist.**
