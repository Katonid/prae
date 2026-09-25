# Projekt Abfahrtstafel (ÖPNV-Abfahrten, native iOS-App)

> Ausgelagert aus der `CLAUDE.md` im Wurzelverzeichnis (09/2026). Die
> übergreifenden Regeln (PR-Rhythmus, iOS-Pflichten, Bau in GitHub
> Actions) stehen weiterhin dort und gelten hier genauso.


- App-Code: `AbfahrtstafeliOS/` (ein Target: App, iPhone + iPad, iOS 17,
  keine fremden Abhängigkeiten). Zeigt, was um einen Punkt herum gerade
  wegfährt — Abfahrtszeit, Verspätung, Minutenziffer, alle Zwischenhalte
  und die Strecke auf der Karte. Der Punkt ist der eigene Standort ODER
  ein frei gewählter. Ausführlich: `AbfahrtstafeliOS/README.md`.
- **Homescreen-Name „Abfahrt"**, Ordner/Ziel/Bundle-Id bleiben
  „Abfahrtstafel" / `de.familie.abfahrtstafel` — nach dem ersten
  Signieren nicht mehr ändern.
- **Alles Fahrplan-Nahe liegt hinter EINEM Protokoll** (`Fahrplandienst`).
  Die Schnittstelle kennt ausschließlich `Fahrplan/Transitous/`; Ansichten
  und Modelle sehen sie nie. Das ist kein Stilwunsch: Öffentliche
  Fahrplanschnittstellen werden abgeschaltet (HAFAS bei der Bahn),
  verlangen plötzlich einen Schlüssel oder decken eine Gegend nicht ab.
  `Musterdienst` ist der laufende Beweis — steckte in einer Ansicht ein
  JSON-Feld von Transitous, ließe er sich nicht übersetzen.
- **Datenquelle ist Transitous (MOTIS v1), ohne Schlüssel und ohne Konto.**
  Es führt die DELFI-Daten (alle deutschen Verbünde) und große Teile
  Europas zusammen. `v6.db.transport.rest` wäre die naheliegende
  Alternative und antwortete beim Bau (09/2026) über Stunden mit 503.
  Ein Schlüssel in der App wäre keiner — was in einer App steckt, ist
  kein Geheimnis.
- **Drei Abfragen, mehr nicht:** `/reverse-geocode` (nächste Haltestelle
  zum Punkt), `/stoptimes` (Abfahrten), `/trip` (Lauf samt Geometrie).
  **`radius` an `/stoptimes` ist der Grund, warum die Tafel mit EINER
  Abfrage fertig ist** — der Dienst liefert die Abfahrten aller
  Haltestellen im Umkreis mit. Eine Abfrage je Haltestelle wären zehn
  Anfragen, und die Liste baute sich ruckweise auf. `/reverse-geocode`
  gibt immer genau FÜNF Treffer zurück (nachgemessen mit `n`, `limit`,
  `count`) — die Liste der Haltestellen baut die App deshalb aus den
  ABFAHRTEN, denn nur die wissen, ob dort heute noch etwas fährt.
- **`/reverse-geocode` sucht nur rund einen Kilometer weit und gibt sonst
  eine LEERE Liste zurück** (nachgemessen 09/2026: Bayerischer Wald und
  Allgäu leer, Eppenschlag 305 m gefunden, Frankfurt 84 m). Ein Punkt
  mitten im Feld hat also keine Ankerhaltestelle, und der Umkreis der App
  ändert daran nichts — was der Dienst nicht liefert, lässt sich nicht
  filtern. Dafür gibt es `Fahrplanfehler.keineHaltestelleInDerNaehe` als
  EIGENEN Fall: Die Antwort darauf ist ein anderer Punkt, nicht ein
  zweiter Versuch, und `Ladestand.fehler` trägt deshalb `ortswahlHilft`
  bis zum Knopf durch. „Noch einmal versuchen" über einem Waldstück wäre
  eine Sackgasse mit Bedienelement.
- **„Plan" ist nicht „pünktlich".** Liegt keine Echtzeitmeldung vor
  (`realTime == false`), steht neben der Zeit das Wort „Plan" und sonst
  nichts. Ein grüner Haken für „nicht nachgesehen" wäre die teuerste Lüge,
  die diese App erzählen kann — dieselbe Regel wie bei Schulalarms
  Prüfliste. Weicht die Echtzeit ab, steht die PLANZEIT durchgestrichen
  da, daneben `+3` und die neue Zeit: Nur die neue zu zeigen verschwiege,
  dass es eine Verspätung gibt, und wer den Fahrplan im Kopf hat, hielte
  die App für falsch. **Ein Zufrüh (`-1`) wird ebenfalls gezeigt** — ein
  Bus, der zwei Minuten zu früh fährt, ist für den Wartenden weg.
- **Die GELTENDE Zeit ist nie die kleinere** (`Haltzeit` in `FahrtView`, ab
  1.0.10, gemeldet 09/2026: „Wenn mich die Abfahrtszeit auch nicht mehr ändert,
  dann ist ja die neue korrigierte Zeit die richtige … sie soll bitte nicht
  kleiner sein als die ursprünglich geplante Zeit."). Bis 1.0.9 stand im
  Fahrtlauf die Planzeit groß und durchgestrichen da und die wirkliche darunter
  in Kleinschrift — also die ungültige Angabe als Hauptangabe. Jetzt steht die
  geltende Zeit oben und groß, die durchgestrichene Planzeit klein darunter.
  **Stehen bleibt sie trotzdem**: Ohne sie verschwiege die App die Verspätung,
  und wer den Fahrplan im Kopf hat, hielte sie für falsch — sie ist nur die
  Erklärung und nicht mehr die Auskunft. In der TAFEL (`Zeitangabe`) stehen
  beide in EINER Zeile und bleiben gleich groß; dort trägt die geltende Zeit
  das Halbfett, denn ein Größenunterschied nebeneinander wäre Unruhe und kein
  Hinweis.
- **Es gibt GENAU EINE Uhr** (`Dienste/Uhrwerk.swift`), und jede
  Minutenziffer rechnet aus ihr. Holte sich jede Zeile selbst `Date()`,
  stünden zwei Abfahrten derselben Minute mit verschiedenen Ziffern
  nebeneinander, und die Liste zählte nur dort weiter, wo SwiftUI zufällig
  neu zeichnet. Sekundentakt, und der Timer hängt in `.common` — in der
  Vorgabeschleife stünde er still, solange gescrollt wird, also genau
  dann, wenn jemand die Tafel durchsieht.
- **Haltestellen werden über den NAMEN gruppiert, nicht über Kennungen**
  (`Haltestellengruppe.bauen`). Der Dienst führt Haltestellen auf
  Steig-Ebene: „Marienplatz" sind mindestens drei Einträge (`…:09162:2`,
  `…:09162:2_G`, `…:09162:2:51:51`), und die Elternkennung ist nicht
  überall gepflegt — ungruppiert stünde dieselbe Haltestelle dreimal
  untereinander, jedes Mal mit einem Teil der Abfahrten. Dazu eine
  Abstandsprüfung (400 m), weil es „Bahnhof" und „Kirche" in einem
  Landkreis dutzendfach gibt. **Umlaute werden beim Vergleich NICHT
  eingeebnet** — dieselbe Regel wie bei Schulalarms Kürzeln.
- **Eine fehlende Streckengeometrie wird nicht erfunden.** Schickt der
  Dienst keinen Linienzug mit, zeichnet `StreckenKarte` die Verbindung der
  Halte GESTRICHELT und schreibt darunter, dass es die Luftlinie ist. Eine
  durchgezogene Linie quer über einen Berg, wo ein Tunnel liegt, sieht aus
  wie eine Auskunft und ist keine.
- **Die Genauigkeit der Polylinie ist ein Parameter, keine Konstante**
  (`Polylinie.auspacken`). Google schreibt mit fünf Nachkommastellen,
  MOTIS mit sieben, und die Antwort sagt es selbst (`precision`). Wer rät,
  legt die Strecke um den Faktor 100 daneben.
- **`METRO` ist die S-BAHN, nicht die U-Bahn.** MOTIS benutzt es für
  GTFS-Typ 109 („suburban railway"). Wer das verwechselt, färbt jede
  S-Bahn blau und jede U-Bahn grün — und ein Fahrgast liest diese Farben,
  ohne hinzusehen. Linienfarben kommen aus den GTFS-Daten
  (`route_color`); fehlen sie, gilt die gewohnte deutsche Rückfallfarbe je
  Verkehrsmittel. Ist keine Schriftfarbe angegeben, wird sie aus der
  HELLIGKEIT entschieden und nicht auf Weiß gesetzt: Die S8 in München ist
  hellgrün, und weiße Schrift darauf ist im Sonnenlicht nicht zu lesen.
- **Entfernungen sind Luftlinien, und das steht dabei.** Ein Fußweg
  bräuchte je Haltestelle eine Routing-Abfrage und wäre trotzdem geraten,
  solange niemand weiß, wo der Zugang liegt. Wer die Zahl für eine
  Gehstrecke hält, verpasst den Bus.
- **Ein AUSDRÜCKLICH erfragter Fußweg ist etwas anderes** (`Fusswegquelle`,
  `Fusswegmesser`, ab 1.1.26, Ansage des Nutzers 09/2026: „Ich möchte eine
  Möglichkeit der Entfernungsmessung zu Fuß einbauen … sowohl vor Ort … als
  auch von einem anderen Ort … Dies alles unkompliziert auf der Karte."). Der
  Punkt darüber bleibt gültig und gilt für die LISTE: Ein Dutzend Abfragen
  für Zahlen, die niemand angefordert hat, wäre falsch. Hier fragt jemand
  nach EINER Strecke — eine Abfrage für eine Auskunft, um die gebeten wurde.
  Auf der Netzkarte, über einen sichtbaren Knopf unten links; Start und Ziel
  mit demselben Fadenkreuz wie der Suchpunkt, wahlweise „Mein Standort", und
  ein Tipp auf eine Haltestelle nimmt sie als Punkt.
- **Der Fußweg steht in `direct`, nicht in `itineraries`** (gemessen
  20.09.2026, Karl-Preis-Platz → Ostbahnhof). Ein Weg ganz ohne
  Verkehrsmittel ist für MOTIS keine Verbindung, sondern eine „direkte" —
  `itineraries` blieb in derselben Antwort leer. Wer ihn dort sucht, hält
  die Quelle für stumm.
- **Ohne `maxDirectTime` hört der Fußweg bei 30 Minuten auf — still.**
  Nachgemessen am selben Tag, Marienplatz nach Norden: ein Kilometer
  Luftlinie kam mit 1075 s durch, **zwei Kilometer und alles darüber
  lieferten eine LEERE Antwort mit HTTP 200**. Das sah aus wie „es gibt
  keinen Weg" und war eine Voreinstellung. Dass der Parameter wirkt, ist am
  INHALT geprüft und nicht am Status — dieselben fünf Kilometer ohne ihn
  nichts, mit `maxDirectTime=7200` 4769 s über 5583 m; ein falsch
  geschriebener Parametername wird von `/plan` stillschweigend ignoriert.
  Gesetzt sind vier Stunden (rund 17 km). Teuer ist es nicht: auch eine
  Abfrage über 150 km war in gut einer Sekunde beantwortet.
- **„Kein Fußweg" gibt es wirklich, und dann steht die Luftlinie da.**
  Helgoland vom Festland aus und München → Nürnberg antworteten auch mit
  hohem Deckel mit nichts — richtig, denn über Wasser und über 150 km führt
  keiner. `Fahrplanfehler.keinFussweg` ist deshalb ein eigener Fall: Hier
  hilft weder ein zweiter Versuch noch eine andere Zeit. Gezeichnet wird
  dann die GESTRICHELTE Gerade, und darunter steht, dass es die Luftlinie
  ist — dieselbe Regel wie beim Fahrtlauf ohne Streckengeometrie.
- **Die Luftlinie steht IMMER daneben, auch bei gefundenem Weg.** Der
  Unterschied zwischen beiden ist die eigentliche Auskunft: 1,7 km Weg über
  1,1 km Luftlinie heißt, dass ein Fluss, ein Gleis oder eine Schnellstraße
  dazwischenliegt. Und sie ist die einzige Zahl, die auch bei einem
  Netzaussetzer dasteht.
- **Die Gehzeit ist die Annahme der QUELLE, keine Messung an einem
  Menschen** (rund 1,19 m/s, also gut 4,3 km/h — gemessen). Die Leiste
  schreibt das Tempo hin und dazu, dass langsamer geht, wer Treppen meidet
  oder ein Kind an der Hand hat. Eine nackte Minutenzahl wäre eine Zusage —
  dieselbe Regel wie beim Wort „Plan" an einer Abfahrt ohne Echtzeit.
- **`Fusswegquelle` ist das VIERTE Protokoll, und `VolleQuelle` hält die
  Kette bei EINER Liste.** Eigenes Protokoll aus demselben Grund wie
  `Abfahrtsquelle` und `Verbindungsquelle`: Die Verbünde geben Fußwege nur
  INNERHALB einer Reiseauskunft heraus, nicht zu zwei frei gewählten
  Punkten. `VolleQuelle = Fahrplandienst & Fusswegquelle` ist der Typ der
  ersten Stufe und des Spiegels — so gibt es weiterhin eine einzige Liste
  von Adressen und keinen `as?`-Versuch zur Laufzeit, der den Fehler vom
  Übersetzer auf das Gerät verschöbe.
- **Der `Fusswegmesser` liegt in der UMGEBUNG, nicht in der Karte.** Die
  Netzkarte gibt es zweimal — eingebettet neben der Liste und im Vollbild —,
  und das sind zwei Ansichten mit eigenem `@State`. Eine gerade gemessene
  Strecke, die beim Aufziehen der Karte verschwindet, sähe wie ein Fehler
  aus.
- **Im Messbetrieb heißt derselbe Tipp etwas anderes.** Ein Tipp auf eine
  Haltestelle nimmt sie als Messpunkt, statt ihre Tafel zu öffnen; ein Tipp
  ins Leere zieht die Karte NICHT auf. Beides ist erlaubt, weil der Modus
  sichtbar ist: Der Knopf steht auf „Abbrechen", das Fadenkreuz liegt in der
  Mitte, und die Leiste sagt, was gerade dran ist. **Ein Modus, den man
  nicht sieht, darf die Bedeutung eines Tipps nicht ändern.**
- **Der Name wird NACHGETRAGEN, nicht abgewartet** (`Fusswegmesser.nameNachtragen`).
  Der Geocoder braucht eine Sekunde; wer auf ihn wartet, bevor der Punkt
  dasteht, baut einen Knopf, der eine Sekunde lang nichts tut. Die Messung
  selbst hängt an der Koordinate. Eine späte Antwort schreibt nur, wenn noch
  DERSELBE Punkt gemeint ist — sonst benannte sie den längst ersetzten.
- **Ein Fehler beim Nachladen räumt die stehende Tafel NICHT weg**
  (`AppModel.melden`). Ist noch nichts da, füllt der Fehler den
  Bildschirm; stehen schon Zeiten, bleiben sie und der Fehler wird ein
  Band darüber — zusammen mit „zuletzt geholt um …", das dann ehrlich
  sagt, wie alt die Zahlen sind.
- **Kein `@AppStorage` in `AppModel`.** Der Wrapper ist eine
  `DynamicProperty` und gehört in eine View; in einer
  `ObservableObject`-Klasse schreibt er zwar in die Voreinstellungen, löst
  aber kein `objectWillChange` aus — die Tafel bliebe nach dem Umstellen
  des Umkreises stehen, und niemand sähe, woran es liegt.
- **Die Ortung ist `WhenInUse` und sonst nichts.** Kein Hintergrundmodus:
  Die App zeigt Abfahrten, während jemand auf sie schaut. Wird die Ortung
  abgelehnt, ist das KEIN Fehlerzustand — der Weg über die Ortswahl steht
  gleich daneben. Eine App, die dort nur „Zugriff verweigert" sagt, ist
  für jemanden ohne Ortung zu Ende.
- **Der Punkt auf der Karte wird über ein festes Fadenkreuz gewählt**, die
  Karte bewegt sich darunter. Ein Tippen auf die Karte wäre naheliegend
  und schlechter: Der Finger verdeckt genau die Stelle, die er trifft, und
  ein Tipp löst beim Verschieben leicht aus.
- **Die Kartenwahl beginnt beim ZULETZT GEWÄHLTEN Ort, nicht beim Bezugspunkt**
  (`AppModel.letzterOrt`, `OrtswahlView.kartenstart`, ab 1.0.7, Ansage des
  Nutzers 09/2026: „nicht immer München als Startort, sondern den zuletzt
  gewählten Ort, unabhängig davon, wann das war und wo ich mich momentan
  befinde"). Bis 1.0.6 stand dort `model.punkt?.koordinate` — und `punkt` ist
  im gewöhnlichen Gebrauch der eigene Standort. Die Kartenwahl fiel damit auf
  ihn zurück und ohne Ortung auf einen fest eingebauten Punkt in München. **Wer
  die Karte öffnet, sucht aber gerade NICHT die Stelle, auf der er steht** —
  dafür ist die Zeile darüber da.
  Drei Dinge dabei: Gemerkt wird in `ortWaehlen`, wo Suche, Merkliste und Karte
  zusammenlaufen (ein „zuletzt gewählter Ort", der nur die Karte zählte, wäre
  nach einer Suche wieder der Punkt von vorgestern). **`letzterOrt` ist NICHT
  der Bezugspunkt** — die Tafel startet weiterhin beim eigenen Standort; sie
  mit dem Ort von letzter Woche aufzuschlagen wäre das genaue Gegenteil dessen,
  wofür diese App an einer Haltestelle geöffnet wird. Und die Koordinate liegt
  als DREI Schlüssel in den Voreinstellungen, samt Prüfung auf 0/0: `0,0` ist
  der fehlende Schlüssel und liegt im Golf von Guinea.
- **Die Quellen sind eine KETTE, und die Reihenfolge ist gemessen**
  (`Kettendienst`, ab 1.0.1): Transitous → Verbund vor Ort →
  Zwischenspeicher. Eine Abfahrtstafel wird an einer Haltestelle
  aufgeschlagen, oft mit einem Balken Empfang — genau dort ist eine einzelne
  Quelle ein einzelner Ausfallpunkt. Der Gedanke stammt aus der München-App
  dieses Nutzers (PWA, eigene Sitzung); deren Kette lautet
  Transitous → DB → Cache.
- **Die Kette hat seit 1.1.2 eine Stufe 1b: DIESELBE Schnittstelle auf einer
  ANDEREN Maschine** (`Kettendienst.spiegel`, `TransitousDienst.spiegel` →
  `europe.motis-project.de`, TU Darmstadt). Nachgemessen 18.09.2026 in
  Dortmund, München, Amsterdam, Prag, Kopenhagen, Paris, Zürich und Wien:
  dieselben Abfahrten, dieselbe Echtzeitquote, dieselben Verbindungen mit
  Geometrie — und **austauschbare Fahrtkennungen**, eine Kennung aus der einen
  Instanz öffnet den Lauf in der anderen. Verschieden sind IP, Netz und
  Webserver (`MOTIS v2.11.3` hinter einem eigenen Proxy gegen `Caddy`).
  **Es ist ein zweiter WEG, keine zweite MEINUNG**: dieselben Daten, also
  dieselbe Lücke im Fahrplan. Das hilft gegen einen Ausfall und gegen nichts
  sonst, und genau so steht es im Quelltext.
- **Das größte Loch der Kette war der ANKER** (behoben in 1.1.2). Die Tafel
  holt über `AppModel.ankerHaltestelle` erst die nächste Haltestelle und dann
  die Abfahrten. `haltestellen(um:)` ging aber ausschließlich an Stufe 1 —
  fiel die aus, warf schon dieser Schritt, und `abfahrten(ab:)` wurde nie
  aufgerufen. **Damit waren die Verbünde, die Schweizer Quelle UND der
  Zwischenspeicher unerreichbar, genau in dem Fall, für den es sie gibt.**
  Ein Netz, das nur hält, solange nichts passiert, ist keines. Zwei Griffe:
  `haltestellen`, `haltestellenSuchen`, `orteSuchen` und `fahrt` gehen jetzt
  der Reihe nach an alle VOLLEN Quellen (`Kettendienst.beiEiner`), und
  scheitern die alle, baut `ankerHaltestelle` einen **Behelfsanker** aus dem
  Punkt selbst. Den brauchen die Verbünde auch gar nicht anders: EFA fragt mit
  einer Koordinate, der Schweizer Dienst sucht seine Stationen selbst, der
  Zwischenspeicher schlägt unter Punkt und Umkreis nach. Der Behelfsanker
  trägt **keinen erfundenen Haltestellennamen**, sondern den des Bezugspunkts.
- **„Nichts gefunden" wird in `beiEiner` NICHT weitergereicht.** Beide
  Instanzen führen dieselben Daten; die zweite zu fragen brächte dieselbe
  Antwort und nur eine Wartezeit. Weitergereicht wird nur ein AUSFALL.
- **Niederlande, Tschechien, Dänemark und Frankreich trägt Stufe 1 — gemessen
  18.09.2026** (Ansage des Nutzers, 09/2026: „Braucht bitte die Niederlande,
  Tschechien und Dänemark auch mit ein. Und Frankreich"). Abfahrten mit
  Echtzeit an Amsterdam CS (12 von 30), Utrecht (21 von 24), Rotterdam
  (18 von 28), Praha hl.n. (22 von 28), Brno (1 von 30), København H
  (20 von 31), Aarhus (24 von 25), Odense (21 von 25), Paris Gare de Lyon
  (24 von 26), Lyon Part-Dieu, Toulouse, Strasbourg; Verbindungen mit
  Geometrie in allen vier Ländern, auch über Land (Praha → Brno, København →
  Aarhus, Paris → Lyon). **Diese Länder waren also nie ohne Auskunft** — was
  ihnen fehlte, war das Netz darunter, und das ist seit 1.1.2 der Spiegel.
- **Was es an eigenen Quellen für diese vier Länder gibt — gemessen
  18.09.2026, und das Ergebnis ist mager:**
  - **Niederlande, OVapi** (`v0.ovapi.nl`): antwortet ohne Schlüssel und mit
    Echtzeit (90 Abfahrten an drei Bereichen um Amsterdam CS). **Trotzdem
    nicht gebaut**, und der Grund ist die Geo-Suche: OVapi kennt keine Abfrage
    um einen Punkt, es bräuchte sein Haltestellenverzeichnis
    (`/stopareacode/`, 660 KB, 4574 Bereiche) — und darin tragen **1522
    Einträge, also ein Drittel, dieselbe erfundene Koordinate** 47,974766 /
    3,3135424 (das liegt in Frankreich). Ein Verzeichnis, das ein Drittel des
    Landes still verliert und obendrein bei Lyon 1522 niederländische
    Haltestellen meldet, ist als Rückfall schlimmer als keiner. Wer es doch
    baut, filtert diese Koordinate und schreibt hin, was fehlt.
  - **Dänemark, Rejseplanen**: Die alte offene Schnittstelle
    (`xmlopen.rejseplanen.dk`) ist ABGESCHALTET — sie antwortet mit HTTP 299
    und einem Abkündigungshinweis. Die Nachfolgerin (`www.rejseplanen.dk/api`,
    HAFAS 2.53) ist erreichbar und verlangt `accessId`. Also nein.
  - **Tschechien, Golemio** (`api.golemio.cz`): HTTP 401, Schlüssel nötig.
  - **Frankreich, Navitia und PRIM Île-de-France**: beide HTTP 401, Schlüssel
    nötig. `transport.data.gouv.fr` ist ein Datenkatalog und keine Auskunft.
  Ein Schlüssel in einer App ist keiner — dieselbe Regel wie bei der ersten
  Quelle. Deshalb ist der Spiegel für diese vier Länder der einzige Rückfall,
  den es gibt, und das steht so da, statt mehr zu versprechen.
- **Ein EIGENER Schlüssel lässt sich eintragen** (`Dienste/Schluesselbund.swift`,
  `Fahrplan/Zugang.swift`, `Views/ZugaengeView.swift`, ab 1.1.3; Ansage des
  Nutzers, 09/2026: „In erster Linie möchte ich diese App für mich und meinen
  eigenen Gebrauch haben. Insofern ist doch die Frage, ob man nicht einen
  Schlüssel einlesen kann, wenn denn schon keiner fest verbaut wird."). Der
  Satz „ein Schlüssel in einer App ist keiner" gilt für einen MITGELIEFERTEN
  Schlüssel — der stünde in jedem Bündel. Einer, den der Nutzer selbst holt und
  der in SEINEM Schlüsselbund liegt, ist etwas ganz anderes. **Nicht in den
  Voreinstellungen**: Was dort steht, wandert im Klartext in jedes Backup;
  dieselbe Bauweise wie bei Anstoß.
- **Wo der Schlüssel in die Anfrage gehört, ist GEMESSEN** (18.09.2026, mit
  einem Platzhalter): Wechselt die Fehlermeldung von „kein Schlüssel" zu
  „falscher Schlüssel", liest der Dienst an dieser Stelle. Ergebnis:
  **Navitia** HTTP-Basic (Schlüssel als Benutzername — über `?key=` sieht der
  Dienst gar nichts, „no token"), **NS** Kopfzeile
  `Ocp-Apim-Subscription-Key` („missing" → „invalid"), **Rejseplanen**
  Abfrageparameter `accessId`, **DB API Marketplace** die zwei Kopfzeilen
  `DB-Client-Id` und `DB-Api-Key`. **Golemio als Einziges NICHT bestätigt** —
  es antwortete mit und ohne Kopfzeile wortgleich; `Zugang.gemessen` steht
  dort auf `false`, und die Oberfläche sagt das auch.
- **Der Schlüssel wird ÜBERALL geschwärzt** (`Zugangsprobe.geschwaerzt`), und
  das ist keine Vorsichtsmaßnahme, sondern ein Befund: **Rejseplanen schickt
  einen falschen Schlüssel im Klartext zurück** („access denied for <Schlüssel>
  on location.name"). Ein kopierbarer Befund hätte ihn mitgenommen.
  Geschwärzt wird in der Adresse, im Rohtext und in jeder Fehlermeldung, auch
  in der prozentkodierten Form, und die längsten Geheimnisse zuerst — sonst
  zerlegt ein kurzes Teilstück das lange und der Rest bliebe stehen.
- **Die Probe fragt den ECHTEN Datenweg ab, nicht eine Statusseite.** Das ist
  ihr ganzer Sinn: Was zurückkommt, ist die Antwort, aus der die Quelle gebaut
  wird. Jede Quelle dieser App ist an einer echten Antwort entstanden und
  keine an einer Beschreibung — für einen Zugang, den es ohne Konto nicht zu
  sehen gibt, ist das der einzige ehrliche Weg. Gezeigt werden Status, Deutung
  und die ersten 4000 Zeichen, kopierbar; dieselbe Bauweise wie Schulalarms
  „Zustellung prüfen".
- **Wo der Schlüssel HERKOMMT, steht über dem Eingabefeld** (`Zugang.anmeldung`,
  `Zugang.schritte`, ab 1.1.4, Ansage des Nutzers 09/2026: „Gib mir bitte an, wo
  ich die einzelnen Schlüssel für die einzelnen Länder herunterladen kann. Am
  besten direkt in der App."). Bis 1.1.3 stand dort nur die Startseite des
  Anbieters — und ein Link allein hilft nicht, wenn dahinter ein Portal mit
  zwanzig Produkten liegt. Jetzt: die **Anmeldeseite** als Knopf und zwei bis
  vier Schritte in der Reihenfolge, in der sie zu tun sind. Jede Adresse ist am
  18.09.2026 abgerufen worden:
  - **Navitia (FR)**: `navitia.io/inscription/` — leitet auf `hove.com`, den
    Betreiber. Der Wechsel der Adresse ist richtig so und steht als Schritt da,
    sonst hält man ihn für eine Fehlleitung.
  - **NS (NL)**: `apiportal.ns.nl/signin`. **Das Konto allein genügt nicht** —
    ohne das Abonnement auf das Reisinformatie-API gilt der Schlüssel nicht.
  - **Rejseplanen (DK)**: `labs.rejseplanen.dk/hc/da` — **die einzige Seite,
    die sich aus der Bauumgebung NICHT abrufen ließ** (403, Bot-Schutz). Sie
    steht so in der offiziellen Hilfe; `seiteGeprueft = false`, und die
    Oberfläche sagt es. Damit sind auch die Bedingungen ungeprüft.
  - **Golemio (CZ)**: `api.golemio.cz/api-keys` (braucht JavaScript).
  - **DB (DE)**: `developers.deutschebahn.com/db-api-marketplace/apis/` — hier
    entstehen ZWEI Angaben, Client-Id und Api-Key, und das Produkt Timetables
    muss der Anwendung zugeordnet werden, sonst kommt 401.
- **Ein eingetragener Schlüssel schaltet NOCH KEINE Abfahrten frei**, und die
  Oberfläche sagt das in ihrem ersten Absatz. Die Decoder fehlen, weil sich
  ohne Konto keine einzige Antwort messen ließ; sie zu erraten wäre genau das,
  was dieses Papier sonst verbietet. **Der nächste Schritt ist deshalb: Der
  Nutzer holt einen Schlüssel, tippt auf „Zugang prüfen" und schickt den
  kopierten Befund — daran wird die Quelle gebaut.** Wer das abkürzt und einen
  Decoder nach der Beschreibung schreibt, hat eine Quelle, die aussieht wie
  eine Auskunft und keine ist.
- **Stufe 1 TRÄGT die App, Stufe 2 ist ein Netz darunter** (Ansage des
  Nutzers, 09/2026: „Ich möchte natürlich, dass die App an jeder anderen
  Stelle in Deutschland auch zuverlässig funktioniert."). Transitous deckt
  Deutschland, Österreich, die Schweiz und große Teile Europas ab und
  liefert als Einziges Zwischenhalte und Strecke. **Wo in Stufe 2 nichts
  steht, fehlt also nichts** — das ist kein Loch, sondern der Normalfall.
  Wer das umdreht und die App auf die Verbünde stellt, baut eine App, die
  nur in sieben Gegenden geht.
- **EFA ist KEIN Münchner Sonderweg** (ab 1.0.2). Dieselbe Abfrage, die in
  München antwortet, antwortet Wort für Wort auch in Essen, Stuttgart,
  Karlsruhe, Mannheim, Dresden und Ulm. `MvvDienst` ist deshalb zu
  `EfaDienst` + `EfaStelle` geworden, und München ist eine Zeile in
  `EfaDienst.alle`. **Jede Zeile dieser Tabelle ist am 18.09.2026 mit einer
  echten Koordinatenabfrage geprüft worden und gab Abfahrten MIT Echtzeit
  zurück.** Was sich nicht prüfen ließ, steht dort nicht — auch dann nicht,
  wenn die Adresse plausibel aussieht: Eine ungemessene Quelle ist in einer
  Kette kein Rückfall, sondern nur eine zusätzliche Wartezeit davor.
  Reihenfolge: **erst örtlich, dann weiträumig** (VVS und DING vor `efa-bw`,
  MVV vor `Bayern-Fahrplan` — der örtliche Verbund kennt seine Stadtbusse
  besser). **Ein landesweiter Zugang schlägt einen städtischen**, wo es ihn
  gibt: `Bayern-Fahrplan` (DEFAS) deckt Nürnberg, Würzburg, Augsburg,
  Regensburg und München ab und füllt damit die Lücke, die `VGN` hinterließ
  — dessen Schnittstelle antwortete zwar mit HTTP 200, gab in Nürnberg aber
  null Abfahrten zurück und steht deshalb nicht in der Tabelle.
- **Die Schweiz hängt an `transport.opendata.ch`** (ab 1.0.2), ohne
  Schlüssel, mit Echtzeit (Zürich, Bern, Basel, Genf geprüft). Zwei Fallen:
  **`x` ist die BREITE und `y` die LÄNGE** — die Namen legen das Gegenteil
  nahe, und wer sie nach Gefühl belegt, fragt im Indischen Ozean und bekommt
  eine leere Liste statt einer Fehlermeldung. Und **`delay: nil` heißt
  „keine Echtzeit", `delay: 0` heißt „gemeldet und pünktlich"** — genau der
  Unterschied, den diese App nie verwischen darf. Der Dienst kennt keine
  Tafel um einen Punkt, nur um eine Station: also erst `/v1/locations`, dann
  bis zu drei `/v1/stationboard` nebenläufig. Für eine erste Quelle wäre das
  zu umständlich, für einen Rückfall ist es der richtige Preis.
- **Österreich: Stufe 1 ja, Stufe 2 nein — und das ist gemessen.** Die
  EFA-Stellen von VVT, OÖVV, SVV und VOR waren aus der Bauumgebung nicht
  erreichbar (Verbindungsabbruch bzw. 502 am Proxy), also stehen sie nicht
  in der Tabelle. Die Echtzeit über Stufe 1 ist dort regional verschieden
  (18.09.2026: Graz 11 von 12, Wien/Linz/Innsbruck null, Salzburg eine von
  zehn). **Nicht als erledigt darstellen** — wer die Adressen aus einer
  Umgebung mit freierem Netz prüfen kann, trägt sie nach.
- **Eine API-Abfrage, die einen ALTEN Stand liefert, lügt genauso**
  (Selbstfund 09/2026, beim Bau von 1.1.6). Die Auftragsliste von GitHub
  Actions meldete minutenlang unverändert „Übersetzen — in_progress", während
  der Lauf längst grün durch war. Daraus wurde erst die Diagnose „der
  Typprüfer hängt", dann ein Abbruch des Laufs, dann ein Umbau des Quelltexts
  samt Kommentaren, die diese Messung behaupteten — und nichts davon hatte je
  stattgefunden: Der abgebrochene Lauf war 113 Sekunden alt, der zweite
  übersetzte in 84. **Ein Zustand, der sich nicht ändert, ist zuerst ein
  Verdacht gegen die Abfrage und dann erst einer gegen die Sache.** Dieselbe
  Wurzel wie beim Testskript darunter, nur eine Ebene höher — und dieselbe
  Lehre: **Wer misst, prüft zuerst, dass er wirklich eine frische Antwort in
  der Hand hält.**
- **Es gibt KEINEN frischen Endpunkt — nur Geduld** (Nachtrag beim Bau von
  1.1.7). Oben stand nach dem ersten Fund, beim Warten entscheide `updated_at`
  des LAUFES statt der Schrittliste. Auch das war zu früh geschlossen: Beim
  nächsten Bau stand `updated_at` fünfundzwanzig Minuten lang auf der
  Startminute, die Schrittliste auf „in_progress" und die Protokollabfrage auf
  404 — während der Auftrag in Wahrheit nach 38 Sekunden grün durch war. Alle
  drei Abfragen lagen gleichzeitig daneben. **Aus Unveränderlichkeit lässt
  sich also gar nichts schließen**, weder auf ein Hängen noch auf ein Laufen;
  gezählt hat am Ende allein, dass das Protokoll irgendwann INHALT hatte, und
  darin stehen die wirklichen Zeitstempel. Also: warten, mehrfach fragen, und
  eine Diagnose erst stellen, wenn eine Antwort etwas SAGT — nie, weil eine
  nichts sagt. Und: Was hier nach dem ersten Treffer als Regel notiert wird,
  ist selbst eine Vermutung, solange es nur einmal gesehen wurde.
- **Ein Testskript, das seine Antwortdatei wiederverwendet, lügt**
  (Selbstfund 09/2026). Beim Vermessen der Verbünde schrieb `curl` in eine
  feste Datei; schlug der Aufruf fehl, las das Skript die Antwort des
  VORIGEN Verbundes und meldete für Innsbruck und Linz „6 Abfahrten, 5
  Echtzeit" — in Wahrheit Stuttgarter Daten. Seither: je Messung eine eigene
  Datei, und der HTTP-Code wird mitgedruckt. **Wer eine Quelle misst, prüft
  zuerst, dass er wirklich ihre Antwort in der Hand hält.**
- **`Fahrplandienst` und `Abfahrtsquelle` sind ZWEI Protokolle, mit Absicht.**
  Nicht jede Quelle kann alles: EFA liefert eine vorzügliche Abfahrtstafel,
  aber keine Streckengeometrie — und eine Fahrt ohne Strecke hat in dieser
  App keinen Bildschirm. Sie als `Fahrplandienst` auszugeben hieße, vier
  Methoden zu versprechen und zwei mit „geht nicht" zu beantworten; das ist
  keine Trennung, sondern eine Lüge mit Protokoll. Die Ansichten sehen
  weiterhin NUR `Fahrplandienst` — `Kettendienst` fügt beides zusammen.
- **EFA: was sie kann, ist nachgemessen und nicht angenommen** (09/2026).
  Über eine KOORDINATE (`type_dm=coord`) liefert sie die Abfahrten aller
  Haltestellen im Umkreis samt Echtzeit — aber **nur im Verbundgebiet**
  (Hamburg, Berlin, Frankfurt: null Abfahrten). Über eine KENNUNG
  (`type_dm=any` mit `de:09162:2`) antwortet sie bundesweit, dort aber
  **ohne Echtzeit** (null von vier). Gebaut ist deshalb nur der erste Weg,
  und `zustaendig(fuer:)` hält die Anfrage auf, wo sie nichts brächte.
  Drei Fallen dabei (sie gelten für JEDE EFA-Stelle): In der ANFRAGE steht
  die **Länge zuerst**
  (`11.575:48.137`), in der Antwort die **Breite** — vertauscht kommt keine
  Fehlermeldung, sondern eine leere Liste. Ohne `coordOutputFormat=WGS84`
  kommen Koordinaten in einem fremden Gitter (gemessen: 5870282, 1288570).
  Und ein Kennungs-Suffix `_G` lässt die Abfrage still ins Leere laufen.
- **Echtzeit gilt bei EFA nur mit `isRealtimeControlled`.** Eine geschätzte
  Zeit, die zufällig der Planzeit gleicht, sähe sonst aus wie „pünktlich" —
  und das ist etwas völlig anderes als „niemand hat nachgesehen".
- **Der Zwischenspeicher ist KEIN Beschleuniger** (`Abfahrtsspeicher`, ab
  1.0.1). Er wird nur gelesen, wenn ALLE Quellen ausgefallen sind, und was
  er herausgibt, trägt seinen Zeitstempel bis in die Oberfläche
  (`Fahrplanfehler.veralteterStand` — ein Fehler, der Daten MITBRINGT).
  Dann steht ein Band darüber, die Fußzeile nennt die Uhrzeit, und **die
  Minutenziffern werden abgeschaltet**: Sie sind die einzige Angabe, die
  fortlaufend etwas behauptet, und eine weiterzählende Ziffer über alten
  Daten ist eine Lüge, die wie eine Auskunft aussieht. Höchstalter zwei
  Stunden, höchstens zwölf Haltestellen, und er liegt in den **Caches** —
  was der Nutzer selbst angelegt hat (die Merkliste), liegt woanders.
- **Nicht jede Zeile lässt sich öffnen** (`Abfahrt.hatFahrtlauf`). Die
  Verbünde geben keine Fahrtkennung heraus; solche Zeilen stehen ohne Pfeil da, und die
  Fußzeile sagt warum. Eine Zeile, die aussieht wie ein Knopf und beim
  Tippen nichts tut, ist für den Menschen davor ein kaputter Knopf.
- **`Abfahrt.id` trägt Linie und Richtung mit.** Ohne Fahrtkennung (Stufe 2)
  bildete eine Tafel sonst zwei Abfahrten derselben Minute an derselben
  Haltestelle auf einen Schlüssel ab — eine davon verschwände
  stillschweigend aus der Liste.
- **Auf dem iPad stehen Liste und Karte NEBENEINANDER** (ab 1.0.3, gemeldet
  09/2026: „Die Darstellung auf dem iPad ist doch sehr in die Breite
  gezogen."). Eine `List` füllt, was da ist; im Querformat sind das gut
  zweitausend Punkte, und die Zeile wird von der Breite auseinandergezogen,
  statt sie zu benutzen. Dagegen zwei Dinge: das zweispaltige Layout bei
  Breitenklasse `regular`, und `Views/Lesebreite.swift` (760 Punkte, mittig)
  auf jeder Zeile. **Die Lesebreite liegt auf der GANZEN Zeile und nicht auf
  ihrem Inhalt** — bei einem `NavigationLink` stünde der Pfeil sonst weiter
  ganz außen und die Zeile sähe genauso zerrissen aus wie vorher.
- **Das Liniennetz wird NACHGELADEN und gedeckelt** (`Model/Liniennetz.swift`,
  ab 1.0.3). Eine Abfahrt weiß, WANN etwas fährt, nicht WO es langfährt; der
  Verlauf steht am Fahrtlauf, und den gibt es nur einzeln. Für zwölf Linien
  sind das zwölf Abfragen — deshalb nebenläufig, auf zwölf gedeckelt und erst,
  wenn jemand die Karte ansieht. Zusammengefasst wird über Linie UND
  Verkehrsmittel, nicht über die Richtung: Die Gegenrichtung fährt denselben
  Weg zurück und verdoppelte nur die Abfragen. `gebautAus` verhindert, dass
  jeder Takt des `Uhrwerks` das ganze Netz neu holt — **ohne diese Prüfung
  lüde die Karte im Sekundentakt zwölfmal nach.**
- **Gewählt werden die NÄCHSTEN zwölf Linien, nicht die zuerst abfahrenden**
  (`Liniennetz.wuenscheBauen`, ab 1.1.24; gemeldet 09/2026: „Am Karl-Preis-Platz
  hält die U2. Warum ist die bei den Linien nicht aufgeführt?“). Sie stand sehr
  wohl in den Daten — sie fiel aus der ZWÖLFER-GRENZE. Bis 1.1.23 nahm
  `wuenscheBauen` die ersten zwölf Linien in der Reihenfolge der ABFAHRTEN, und
  die ist nach Zeit sortiert. **Nachgemessen am 19.09.2026 am Karl-Preis-Platz**,
  200 Abfahrten im Umkreis von 3 km: Sie deckten **drei Minuten** ab und
  enthielten **43 verschiedene Linien**; die ersten zwölf waren die, deren
  Fahrzeug in den ersten Sekunden zufällig losfuhr — S5, S6, 100, 132, 139, 145,
  155, 17, 185, 187, 18, 190, größtenteils vom zwei Kilometer entfernten
  Ostbahnhof. **Die U2, die direkt unter dem Bezugspunkt hält, stand auf Platz
  18.** Dieselbe Messung nach Nähe sortiert: 59 (0 m), 155 (85 m), **U2
  (118 m)**, 55, 145, 54, U5, U8, 191 — also die Linien, die dort halten, wo der
  Mensch steht. Bei gleichem Abstand gilt weiter die Zeit. Dasselbe Muster wie
  1.1.10: **Wenn etwas fehlt, ist die Zuordnung der zweite Verdacht und das
  Fenster der erste** — nur ist es hier nicht das Zeitfenster, sondern die
  Auswahl daraus.
- **Der gezeichnete Lauf bleibt der FRÜHESTE** dieser Linie, nicht der
  nächstgelegene. Die Nähe entscheidet, WELCHE Linien gezeichnet werden, nicht
  WELCHER Lauf — geändert wird eine Sache auf einmal, sonst sagt der nächste
  Befund nichts mehr.
- **Was die Grenze weglässt, wird GEZÄHLT** (`Liniennetz.nichtGezeichnet`, ab
  1.1.24). Das ist die schlimmere Hälfte desselben Befundes: `ohneVerlauf` zählt
  nur Linien, deren Quelle gar keinen Lauf herausgibt. Eine Linie MIT
  Fahrtkennung, die bloß nicht mehr in die Zwölf passte, galt als „zeichenbar“
  und tauchte in keiner Zahl auf — die Karte zeichnete zwölf Linien und sagte
  mit keinem Wort, dass einunddreißig fehlten. **Die Regel stand seit 1.0.3
  daneben und galt für diesen Fall nicht**: „Eine Karte, in der stillschweigend
  Linien fehlen, ist eine Karte, der man ihre Unvollständigkeit nicht ansieht.“
  Die Fußzeile nennt jetzt die Zahl und sagt, was hilft (kleinerer Umkreis oder
  ein Filter) — dieselbe Bauweise wie „Hineinzoomen zeigt sie“ bei den Halten.
  **Wer eine neue Grenze einzieht, zählt, was sie wegnimmt.**
- **Die beiden Zählungen werden IMMER nachgeführt, die Abfrage nicht.** Sie
  hängen an ALLEN Abfahrten und nicht an den gewählten zwölf: Kommt eine
  dreizehnte Linie dazu, ohne die Auswahl zu ändern, stimmte die Zahl darunter
  sonst nicht mehr, und `netz.stand` bliebe gleich. Deshalb stehen sie vor dem
  `guard` — und deshalb stehen `nichtGezeichnet` und `ohneVerlauf` seit 1.1.24
  auch in den Auslösern von `neuRechnen`. Zugewiesen wird nur bei echter
  Änderung: Ein `@Published`, das denselben Wert noch einmal bekommt, lässt die
  Karte trotzdem neu zeichnen (die Lehre aus 1.1.16), und `aufbauen` läuft im
  Sekundentakt.
- **Was sich nicht zeichnen lässt, wird GEZÄHLT und hingeschrieben**
  (`Liniennetz.ohneVerlauf`). Linien aus Stufe 2 haben keine Fahrtkennung und
  damit keinen Verlauf. Eine Karte, in der stillschweigend Linien fehlen, ist
  eine Karte, der man ihre Unvollständigkeit nicht ansieht.
- **Die Karte benutzt DENSELBEN Filter wie die Liste** (`AppModel.filter`).
  Zwei Filter für dieselbe Frage wären zwei Antworten.
- **Eine Umleitung steht in den DATEN — als Merkmal am einzelnen HALT**
  (ab 1.0.8, nachgemessen 18.09.2026 an der Linie 448 in Dortmund: „Hombruch
  Friedhof" kam als entfallen zurück, 1 von 23 Halten). Zwei Felder, und beide
  werden gebraucht: `cancelled` am Ort, und — wo die Quelle das nicht setzt —
  `pickupType` UND `dropoffType` auf `NOT_ALLOWED`. **Nur beides zusammen**,
  denn am ersten Halt ist der Ausstieg planmäßig verboten und am letzten der
  Einstieg; eine Oder-Prüfung kappte jede Fahrt an beiden Enden
  (`TransitousDienst.haltEntfaellt`). An der ABFAHRT heißt dasselbe
  `pickupDropoffType` — steht es dort auf `NOT_ALLOWED`, hält das Fahrzeug an
  DIESER Haltestelle nicht, und ohne diese Zeile stünde die Abfahrt unverändert
  in der Tafel: Jemand wartete auf einen Bus, der vorbeifährt.
- **Der UMLEITUNGSWEG steht in KEINER Quelle — er wird nicht erfunden.**
  Dieselbe Messung: Der Halt entfiel, die Streckengeometrie kam unverändert
  planmäßig zurück (457 Punkte). Gezeichnet wird deshalb weiter der Planweg,
  und beide Karten schreiben ausdrücklich hin, dass er es ist
  (`StreckenKarte.entfalltext`, `LiniennetzView`-Fußzeile). Ein Linienzug, der
  sich eine Umleitung ausdenkt, sieht aus wie eine Auskunft und ist keine —
  dieselbe Regel wie bei der gestrichelten Luftlinie.
- **Ein entfallender Halt wird auf der Karte NIE weggelassen.** Über der
  Grenze von 260 Punkten zeichnet `sichtbareHalte` keine gewöhnlichen Halte
  mehr, die entfallenden aber schon: Sie sind der Grund, aus dem jemand die
  Karte aufschlägt. Aus demselben Grund tragen sie ihren Namen auch dann,
  wenn keine Linie hervorgehoben ist. Gezeichnet wird rot UND mit Kreuz —
  Farbe allein sieht ein farbfehlsichtiger Mensch nicht.
- **`Linienzug.halte` sind `Zwischenhalt`e, keine Haltestellen** (ab 1.0.8).
  Nur der Zwischenhalt weiß, ob er heute angefahren wird; mit blossen
  Haltestellen ist eine Umleitung auf der Netzkarte unsichtbar.
- **Ein entfallender Halt steht in den MUSTERDATEN** (`Musterdienst`,
  Fasangarten). Der Fall lässt sich nicht herbeiführen, wenn man ihn ansehen
  will — ohne ihn in den Beispieldaten wäre jede Anzeige dafür nur dann zu
  prüfen, wenn gerade irgendwo eine Straße gesperrt ist.
- **Was Transitous NICHT hat: geplante Sperrungen in der Zukunft.** Gemessen
  18.09.2026 an sieben S8-Stationen (Ismaning, Hallbergmoos, Unterföhring,
  Herrsching, Weßling, Gilching-Argelsried, Daglfing, Johanneskirchen), jeweils
  Sa 17.10. gegen Sa 24.10.: gleiche Zahl S8-Fahrten, kein Ersatzverkehr, keine
  Meldung. Eine Sperrung, die andere Apps für den 24.10. anzeigen, steht in den
  DELFI-Daten also nicht — sie kommt dort aus DBs eigener Auskunft. **Das nicht
  als Fehler der App darstellen und nicht als lösbar versprechen**, solange
  keine Quelle dafür gemessen ist. `/stoptimes` nimmt übrigens `time` entgegen
  und antwortet für künftige Tage; die App fragt bisher immer „jetzt".
- **Züge fielen aus dem FENSTER, nicht aus der Zuordnung** (zweite Abfrage in
  `TransitousDienst.abfahrten`, ab 1.1.10; Ansage des Nutzers 09/2026: „In
  München fahren garantiert noch andere Züge ab … Bitte nimm noch weitere
  Verkehrsverbindungen in die App auf"). `REGIONAL_RAIL` und `HIGHSPEED_RAIL`
  standen seit der ersten Fassung in `verkehrsmittel(_:)` — es kam nur fast nie
  eines an. `/stoptimes` gibt die nächsten `n` Abfahrten ALLER Haltestellen im
  Umkreis zurück, nach Zeit sortiert, und in einer Innenstadt sind das Busse
  und Trams. **Nachgemessen 18.09.2026 an der Arnulfstraße in München:** Die 40
  Abfahrten der App deckten **drei Minuten** ab (16:42–16:45), darin zwei
  Regionalzüge. Ein Zug fährt seltener als eine Tram und verliert dieses Rennen
  immer — je besser die Stadt mit Bussen bedient ist, desto sicherer.
  **Merke: Wenn eine Art Fahrt fehlt, ist die Zuordnung der zweite Verdacht und
  das Zeitfenster der erste.**
- **Die seltenen Verkehrsmittel bekommen eine EIGENE Abfrage.** Dieselben 40
  Zeilen mit `mode=REGIONAL_RAIL,HIGHSPEED_RAIL,LONG_DISTANCE,NIGHT_RAIL,COACH,FERRY`
  deckten **54 Minuten** ab: RE5 nach Salzburg (über Freilassing), RE25, RB16,
  RB6, ICE 500 nach Berlin, dazu Fernbusse. Es ist keine zweite Quelle, sondern
  dieselbe mit einem zweiten Fenster; beide laufen nebenläufig und werden über
  `Abfahrt.id` entdoppelt und neu sortiert. **`FERRY` steht bewusst mit drin**,
  obwohl in München keine fährt — eine Fähre ist genauso selten und verlöre
  dasselbe Rennen. **Die Zusatzabfrage darf die Tafel nie mitreißen**: Scheitert
  sie, fehlen Züge, aber die Busse stehen da; andersherum wäre der Schaden
  größer.
- **`mode` ist der einzige Parametername, der wirkt — und ein falscher fällt
  NICHT auf.** Gemessen 18.09.2026: `modes=` und `transitModes=` werden mit
  HTTP 200 angenommen und **stillschweigend ignoriert**, die Antwort kommt
  ungefiltert zurück und sieht tadellos aus. Ein falscher WERT dagegen wird
  abgewiesen („invalid value … for enum ModeEnum"). Wer hier etwas ändert,
  prüft am ZEITFENSTER der Antwort, ob der Filter gegriffen hat, nicht am
  Status. Und **`RAIL` ist eine Obergruppe**: Damit kamen U-Bahn und S-Bahn mit
  zurück, und das Fenster war wieder zu.
- **`COACH` ist ein FERNBUS, kein Stadtbus** (neunter Fall `fernbus`, ab
  1.1.10). Bis dahin lief er als `.bus` mit und stand zwischen den Stadtbussen;
  ein FlixBus nach Zagreb ist aber weder das eine noch das andere. Eigene
  Rückfallfarbe (Olivbraun — gemessen kleinster Abstand dE 37,8 zu allen
  anderen, Schriftkontrast 7,0:1), eigenes Symbol, eigene Filterzeile. Die
  Filterleiste baut sich aus `AppModel.vorhandeneMittel` und zeigt die neuen
  Zeilen von selbst, sobald so etwas abfährt.
- **Die Zugnummer in Klammern wird abgeschnitten, alles andere nicht**
  (`ohneZugnummer`). Transitous schreibt „RE5 (79039)" und „RB16 (59162)" —
  auf einem Liniensymbol ist das unlesbar. Gemessen an 151 Zugnamen aus
  München, Dortmund, Hamburg, Berlin, Freilassing und Wien: 68 enden auf eine
  Klammer, und in **jedem einzelnen Fall** stehen darin nur Ziffern. Kein
  Gegenbeispiel — also wird genau dieser Fall abgeschnitten. **Ohne Klammern
  wird NICHTS abgeschnitten**: In Österreich hängt die Nummer ohne sie dran
  („REX 7757", „R 2578", „RRR 7757"), und dort ist nicht zu entscheiden, wo die
  Linie aufhört und die Nummer anfängt. Ein langes Schild ist besser als ein
  falsches.
- **Ein Bahnhof stand unter ZWEI Namen in der Liste — behoben in 1.1.23.** Der
  Punkt stand seit 1.1.10 als offener im Papier, mit der Auflage, zuerst an
  echten Daten zu messen. **Nachgemessen am 19.09.2026 an 22 deutschen
  Städten** (je rund 150 Abfahrten im Umkreis von 500 Metern um den
  Hauptbahnhof, 170 verschiedene Haltestellennamen): Der Fall kommt in ACHT von
  22 Städten vor — Augsburg, Bremen, Erfurt, Kiel, Leipzig, Mannheim, München,
  Nürnberg. **Und es sind ZWEI Risse, nicht einer:** „Hbf“ gegen
  „Hauptbahnhof“ (Nürnberg 75 zu 1, Augsburg 111 zu 3, Bremen 53 zu 12) und
  das Komma, mit dem viele Verbünde den Ort vom Halt trennen („Erfurt,
  Hauptbahnhof“ gegen „Erfurt Hbf“; ebenso Leipzig und Mannheim, und in Prag
  „Praha,Hlavní nádraží“ gegen „Praha hlavní nádraží“). Wer nur die
  Abkürzung ausschreibt, lässt drei der acht Städte doppelt stehen.
- **Ausgeschrieben wird Wort für Wort, verglichen wird auf GLEICHHEIT**
  (`Haltestellengruppe.vergleichsname`). Der gefährliche Griff wäre, „Hbf“ und
  „Hauptbahnhof“ irgendwo im Namen zusammenzuziehen — und dieselbe Messung
  zeigt an derselben Stelle, was das kostet: Um den Münchner Hauptbahnhof
  liegen „Hauptbahnhof Nord“, „Hauptbahnhof Süd“ und „Hauptbahnhof (U, Tram)“
  innerhalb von 270 Metern, in Dresden steht „Dresden Hauptbahnhof“ neben
  „Dresden Hauptbahnhof Nord“ und „Dresden Hbf (Strehlener Str.)“, in Kassel
  „Kassel Hauptbahnhof“ neben „Kassel Hauptbahnhof Nord“. Das sind
  verschiedene Haltestellen, und ihr Unterschied ist genau der, den ein
  Wartender braucht. Ergebnis der Messung: acht Zusammenlegungen, **keine
  falsche**. **Umlaute werden weiterhin nicht eingeebnet**, und wer die Liste
  der Abkürzungen erweitert, misst wieder nach.
- **Welche Schreibweise dasteht, entscheidet die MEHRHEIT**
  (`Haltestellengruppe.anzeigename`), nicht die erste und nicht die längere.
  Auch das ist gemessen und geht in beide Richtungen: In Nürnberg und Augsburg
  ist die Kurzform die übliche, in Bremen und Kiel die lange, in Erfurt und
  Mannheim die mit Komma. Eine feste Vorliebe schriebe an jedem zweiten Ort
  etwas hin, was dort niemand sagt. Bei Gleichstand die längere. **Gebaut wird
  kein Name** — was dasteht, hat eine Quelle so geschrieben.
- **Die Tafel hat einen wählbaren ZEITPUNKT** (`AppModel.bezugszeit`, ab
  1.1.11, Ansage des Nutzers 09/2026). „Jetzt" oder ein Datum, umgeschaltet
  über dieselbe `Zeitleiste`-Bauweise wie in der Verbindungsauskunft — es ist
  dieselbe Frage, und zwei Bedienungen dafür wären zwei Dinge zu lernen.
  **Drei Stellen hängen daran, und alle drei behaupteten vorher „jetzt":**
  - `gefiltert` schneidet Abfahrten ab, die länger als eine Minute vorbei
    sind — gemessen gegen die BEZUGSZEIT und nicht gegen die Uhr. Sonst läge
    bei einer Tafel für morgen früh jede Abfahrt vor der Grenze und die Liste
    wäre leer.
  - **Die Minutenziffer wird abgeschaltet** (`AbfahrtsZeile.fuerGewaehlteZeit`).
    „In 3 Minuten" über einer Tafel für morgen früh ist falsch, und zwar auf
    dieselbe Art wie eine weiterzählende Ziffer über altem Stand aus dem
    Zwischenspeicher. Dieselbe Regel, zweiter Anlass.
  - **Der Nachladelauf ruht** (`RootView`): Dieselbe Abfrage alle dreißig
    Sekunden brächte dieselbe Antwort.
  **Der gewählte Zeitpunkt steht NICHT in den Voreinstellungen**, anders als
  Umkreis und Anzahl. Er ist eine einmalige Frage; wer die App am nächsten Tag
  an einer Haltestelle aufschlägt, will die Tafel von jetzt. Eine gespeicherte
  Zeit sähe aus wie eine ganz gewöhnliche Tafel und wäre eine.
- **`anzahl` geht bis 200** (ab 1.1.11, Ansage des Nutzers). Dabei gehört der
  gemessene Zusammenhang aus 1.1.10 in die Fußzeile der Einstellungen: In einer
  Innenstadt kauft eine höhere Zahl vor allem mehr Busse — vierzig Abfahrten
  decken dort rund drei Minuten ab. Züge, Fernbusse und Fähren werden davon
  nicht knapper, sie haben ihr eigenes Fenster.
- **Die Karte lässt sich auf den ganzen Bildschirm ziehen** (`Vollbildkarte`,
  ab 1.1.11, Ansage des Nutzers 09/2026). Auf dem iPad liegt neben der Liste
  nur ein Ausschnitt, und was jemand sucht, liegt oft genau daneben.
  **Zwei Wege mit Absicht**: ein Tipp auf die freie Kartenfläche und ein Knopf
  unten links. Die Halte und die Liniennummern bleiben Knöpfe und behalten ihre
  eigene Aufgabe — ein Tipp auf einen Halt öffnet weiterhin dessen
  Abfahrtstafel (1.1.7). Eine Geste, die niemand kennt, ist so wenig wert wie
  ein Knopf, den niemand findet; deshalb beides.
- **Ein eigener Stapel braucht ALLE Ziele, nicht eines** (`Views/Fahrplanziele.swift`,
  ab 1.1.25; gemeldet 09/2026: „Ein Tipp auf eine Linie bewirkt leider gar
  nichts"). Die Vollbildkarte macht seit 1.1.11 einen eigenen
  `NavigationStack` auf und trug darin `Haltestelle` ein, aber **nicht**
  `Fahrtwunsch`. Wer dort einen Halt antippte, kam in dessen Abfahrtstafel —
  und von da an ging es nicht weiter: Jede Zeile ist ein
  `NavigationLink(value: Fahrtwunsch(…))`, und ein Verweis, dessen Wertetyp im
  Stapel kein Ziel hat, tut NICHTS. Kein Absturz, keine Meldung, keine
  Bewegung; für den Menschen davor ein kaputter Knopf.
- **Die Lehre stand schon da und war trotzdem nicht gezogen.** Über genau
  dieser Zeile stand seit 1.1.11 der Kommentar „Ein eigener Stapel braucht sein
  eigenes Ziel. Dieselbe Falle wie in 1.1.7" — und darunter wurde EINES der
  zwei Ziele eingetragen. Dasselbe Muster wie bei Schulalarms
  `requestAuthorization`, wo die Falle im Kommentar beschrieben stand und die
  Prüfung fehlte: **Ein Kommentar ersetzt keine Prüfung.** Deshalb ist es jetzt
  kein Merksatz mehr, sondern ein Modifikator: `.fahrplanziele()` hängt an
  allen vier Stapeln (Tafel, Vollbildkarte, Merkliste, Verbindung) und trägt
  beide Ziele. **Wer einen neuen Stapel baut, hängt ihn dran; wer ein drittes
  Ziel braucht, trägt es DORT ein.** `Verbindung` steht bewusst nicht darin —
  die gibt es nur in der Auskunft, und ein Ziel für einen Wert anzumelden, der
  in diesem Stapel nie vorkommt, verspräche einen Weg, den es nicht gibt.
- **Erst die LAGE prüfen, dann die Arbeit machen** (`berechneHalte`, ab
  1.1.25). Bis 1.1.24 wurde für JEDEN Halt JEDER Linie ein Punkt gebaut —
  samt `gemeldet(…)`, also einem Textvergleich gegen die Meldungsliste — und
  ERST DANACH auf den Ausschnitt gefiltert. `hoechstzahlHalte` deckelte damit,
  was GEZEICHNET wird, nicht, was durchgegangen wird. **Gemessen am
  19.09.2026 am Karl-Preis-Platz**, 3 km Umkreis: zwölf Linien haben dort 292
  Halte, dreiundvierzig **2.125** — und das lief bei jedem Neurechnen durch,
  also bei jeder Schiebebewegung. Dieselbe Falle wie 1.1.16, nur eine Ebene
  tiefer und mit der Zahl der Linien wachsend. Das Ergebnis ändert sich durch
  das Vorziehen nicht: Eine Haltestelle hat genau eine Koordinate, also fällt
  `imSichtfeld` für alle ihre Vorkommen gleich aus — Filtern und Entdoppeln
  sind vertauschbar.
- **Die Grenze steht auf ZWANZIG (ab 1.1.25), und der Engpass ist nicht der,
  der bis 1.1.24 dabeistand** (Frage des Nutzers 09/2026: „Würde die App
  zusammenbrechen, wenn die Anzahl erhöht würde?"). Nachgemessen am
  19.09.2026 am Karl-Preis-Platz, 3 km Umkreis, 43 verfügbare Linien:
  - **Die Abfragen kosten nichts.** Nebenläufig, also entscheidet die
    langsamste: 12 Linien 1,39 s, 24 Linien 1,39 s, 43 Linien 1,40 s; keine
    Drosselung, kein Fehler, 205 KB gegen 1,4 MB. „Das sind zwölf
    Netzabfragen" stand hier bis 1.1.24 als Begründung und war keine.
  - **Beim Öffnen ist auch das Zeichnen harmlos** — die Vereinfachung aus
    1.1.17 greift sogar besser, je mehr Linien es sind (3,7 % bei zwölf,
    2,1 % bei 43), weil das Netz weiter reicht und ein Bildpunkt mehr Meter
    bedeutet.
  - **Beim Hineinzoomen kippt es.** Gezeichnete Koordinaten am Straßenzug:
    12 Linien 4.530, 20 Linien 20.026, 43 Linien 29.320. Zwanzig erreichen
    damit ungefähr die Größe, die 1.1.17 als das Gewicht gemessen hat (rund
    25.000) — der Unterschied ist, wie OFT sie anfällt: damals bei jeder
    Zeichnung im Sekundentakt, seit 1.1.16/1.1.17 nur auf einen echten
    Auslöser. **Das ist die ehrliche Hälfte der Antwort und kein Freibrief.**
  - **Nicht gemessen ist die Wirkung auf dem Gerät** — gezählt sind
    Koordinaten, nicht Bildwiederholungen. Fühlt sich die Karte hineingezoomt
    zäh an, ist `hoechstzahl` die Zahl, die man senkt; „Karte prüfen" nennt
    die Stützpunkte roh und gezeichnet.
- **Zwei getrennte Hell-Dunkel-Umschalter** (`Views/Darstellung.swift`, ab
  1.1.12, Ansage des Nutzers 09/2026). Einer für die App
  (`preferredColorScheme` an der WURZEL — weiter unten gesetzt erwischte es
  Blätter und Vollbilder nicht), einer für die KARTEN
  (`.kartendarstellung()`, ein `environment(\.colorScheme, …)` über den
  Kartenausschnitt). Getrennt, weil es zwei Fragen sind: Eine dunkle Karte ist
  abends am Bahnsteig angenehm und bei Sonne unlesbar — die Liste daneben hat
  damit nichts zu tun.
  - **Die Kartenwahl gilt für ALLE VIER Karten** — Liniennetz, Fahrtlauf,
    Verbindung und Ortswahl. Eine Einstellung, die nur eine davon trifft, ist
    für den Menschen davor ein Fehler.
  - **Die Haut gehört HINTER die Überlagerungen.** Eine Überlagerung wird von
    außen an das fertige Bild gehängt und erbt die Umgebung des ÄUSSEREN
    Zusammenhangs; davor gesetzt bliebe die Legende hell auf einer dunklen
    Karte. Die Fußzeile unter der Netzkarte bleibt dagegen außen vor: Sie
    erklärt die Zeichenweise und gehört zur App.
  - **„Wie die App" wird an EINER Stelle aufgelöst** (`Kartendarstellung.geltend`).
    Gebraucht wird der Wert an zwei Enden — der Modifikator legt ihn über die
    Karte, und `LiniennetzView` braucht ihn noch einmal als Zahl, weil die
    Kontur unter einem Linienzug die Gegenfarbe zur Karte sein muss. Zwei
    Fassungen liefen auseinander, und dann läge auf einer dunklen Karte eine
    weiße Kontur.
  - **`system` bzw. „wie die App" bleibt die Vorgabe.** Wer nichts einstellt,
    bekommt weiterhin die geplante Umschaltung zur Dämmerung, die iOS von
    selbst macht.
  - **Nicht gemessen:** Ob MapKits SwiftUI-`Map` die überschriebene
    `colorScheme` wirklich annimmt, lässt sich nur auf einem Gerät sehen. Es
    ist der dokumentierte Weg für einen Teilbaum, aber eine Erwartung und
    keine Messung — wer es prüft, trägt das Ergebnis hier nach.
- **Es war nie ein Umkreis, es war eine ZÄHL-GRENZE** (`sichtbareHalte`, ab
  1.1.13; gemeldet 09/2026: „Haltestellen gibt es offenbar nur in einem
  bestimmten Umkreis vom Suchpunkt … bei den S-Bahn-Linien werden weiter
  entfernte Haltestellen nicht angezeigt."). Über 260 Punkten zeichnete die
  Karte GAR KEINE gewöhnlichen Halte mehr, nur noch die entfallenden — und
  zwölf Linien in München haben zusammen weit über dreihundert. Die Grenze riss
  also immer, und was übrig blieb, sah aus wie ein Umkreis um den Suchpunkt:
  Die weißen Kreise in der Mitte sind die Haltestellen aus der LISTE, nicht die
  der Linien. **Wer einen Befund liest, prüft zuerst, ob das beschriebene
  Muster überhaupt das gebaute ist.**
- **Gezählt wird jetzt, was im AUSSCHNITT liegt** (`imSichtfeld`, `sichtfeld`
  über `onMapCameraChange(frequency: .onEnd)`). Die Grenze bleibt, denn ihr
  Grund bleibt — jeder Punkt ist eine eigene SwiftUI-Ansicht, und dreihundert
  davon machen die Karte zäh. Sie zählt aber nur noch das Sichtbare, und damit
  gibt es die Halte überall: Wer zur S-Bahn-Strecke schiebt oder hineinzoomt,
  bekommt dort ALLE. Das ist der Unterschied zwischen „fehlt" und „steht
  gerade nicht im Bild", und die Fußzeile sagt ihn jetzt auch
  („Hineinzoomen zeigt sie"). Rand von einem Zehntel, damit beim Schieben
  nicht an jeder Kante eine Reihe Punkte aufpoppt; `nil` (Kamera hat sich noch
  nicht gemeldet) heißt „alles", sonst wäre die Karte beim ersten Zeichnen
  leer. **`.onEnd` und nicht `.continuous`** — sonst würde die Haltliste
  während jeder Schiebebewegung neu gerechnet.
- **Ein LANGER Tipp auf die Netzkarte setzt den Suchpunkt** (`punktSetzen`, ab
  1.1.13, Ansage des Nutzers 09/2026: „Ich mag nicht immer erst wieder in
  dieses Menü gehen müssen."). Der kurze Tipp zieht die Karte auf (1.1.11),
  der lange versetzt den Punkt.
  - **`LongPressGesture` allein meldet nur, DASS gehalten wurde, nicht WO.**
    Deshalb `.sequenced(before: DragGesture(minimumDistance: 0))` — und
    genommen wird `startLocation`, nicht `location`: Der Finger wandert beim
    Halten ein paar Punkte, gemeint ist die Stelle, auf die gezeigt wurde.
    Umgerechnet wird über `MapProxy.convert` aus einem `MapReader`; welche
    Koordinate unter einem Bildschirmpunkt liegt, weiß allein die Karte.
  - **Erst den Namen holen, dann setzen.** Ein nachträgliches Umbenennen
    änderte `model.punkt` ein zweites Mal, und daran hängt
    `onChange(of: model.punkt)`: Die Karte stellte sich mitten in der Bewegung
    neu ein. Eine Karte, die springt, nachdem man gerade einen Punkt gesetzt
    hat, sieht kaputt aus. Damit die Wartezeit nicht wie ein toter Knopf
    wirkt, meldet sich das Gerät sofort spürbar.
- **Der Name zu einer Koordinate steht an EINER Stelle** (`Dienste/Ortsname.swift`,
  ab 1.1.13). Gebraucht wird er unter dem Fadenkreuz der Ortswahl und beim
  langen Tipp; zwei Fassungen benannten denselben Punkt irgendwann verschieden.
  **`nil` heißt „konnte nicht nachsehen" und nicht „heißt nicht"** — die
  Ortswahl behält dann den Namen von vorhin, statt ihn beim Schieben durch
  einen Platzhalter zu ersetzen.
- **Eine Geste, die „nichts bewirkt", ist zuerst ein Verdacht gegen die
  KAMERA** (ab 1.1.14; gemeldet 09/2026: „Das Zoomen auf der Karte fällt
  manchmal schwer, gerade wenn sie neu geöffnet ist … bewirkt die Geste mit
  zwei Fingern nichts."). Es war keine Geste, die nicht ankam, sondern eine,
  die weggeräumt wurde: `Liniennetz` ersetzt `zuege` in EINEM Zug, sobald alle
  Fahrtläufe da sind — ein bis drei Sekunden nach dem Öffnen —, und genau
  darauf saß ein `onChange`, das den Ausschnitt neu setzte. Wer in dieser
  Zeitspanne zoomte, sah seine Geste wirken und sofort wieder verschwinden.
  Dasselbe noch einmal alle dreißig Sekunden, wenn der Nachladelauf die
  Linienliste ändert; daher das „manchmal". **Der Zeitpunkt in der Meldung war
  die halbe Diagnose** — „gerade wenn sie neu geöffnet ist" ist genau das
  Fenster, in dem die Fahrtläufe eintreffen.
- **Wer die Karte angefasst hat, führt sie.** Ab der ersten eigenen Bewegung
  stellt sie sich nicht mehr selbst ein; zurück gibt der Nutzer sie mit einem
  neuen Bezugspunkt, denn das ist eine neue Lage. In 1.1.14 wurde die
  Berührung über zwei **`simultaneousGesture`** erkannt (Ziehen und Zoomen),
  mit der Begründung, `simultaneousGesture` sehe nur zu. **Beides ist in
  1.1.15 wieder ausgebaut** — siehe unten.
- **Zweimal eine Vermutung als Diagnose ausgegeben — und der Nutzer hat beide
  Male widersprochen.** 1.1.14 nannte die Kamera als Ursache, 1.1.15 die
  Gesten. Die zweite Begründung stützte sich darauf, dass die Beschwerde erst
  nach 1.1.13 kam, also nach dem Einbau des langen Tipps. **Das war schlicht
  falsch** (Ansage des Nutzers 09/2026: „Das Problem ist vorher bereits
  aufgetreten und es tut es jetzt auch wieder."). Eine zeitliche Korrelation,
  die der Nutzer nicht bestätigt hat, ist keine Messung — und wer auf ihr eine
  Fassung baut, baut eine Funktion ab, die jemand ausdrücklich wollte.
  **Die Gesten sind seit 1.1.16 wieder da**, der Nadelknopf mit dem Fadenkreuz
  aus 1.1.15 steht daneben: zwei Wege, wie beim Vollbild.
  Was daneben bestehen bleibt, weil es unabhängig davon richtig ist:
  - **`.automatic` als Kamerastand.** `MapCameraPosition.automatic` heißt
    „rahme, was drinsteht" — und was drinsteht, hängt seit 1.1.13 über
    `sichtbareHalte` am gezeigten Ausschnitt. Das ist eine Rückkopplung: Jede
    Kamerabewegung ändert die Zahl der Halte, die geänderte Zahl rahmt die
    Kamera neu. `.automatic` stand beim Öffnen und nach jedem Wechsel des
    Bezugspunkts — und der `nutzerFuehrt`-Wächter aus 1.1.14 hielt die Karte
    ausgerechnet dann für immer darin fest, wenn der Nutzer früh zoomte.
    Gesetzt wird jetzt ausschließlich ein ausgerechneter `MKMapRect`, und nur
    über `rahmen(_:)`.
  - **Erkannt wird die eigene Bewegung an der Kamera selbst**
    (`eigeneBewegung`): `rahmen(_:)` setzt eine Marke, `onMapCameraChange`
    nimmt sie weg — jede Meldung ohne Marke kam vom Nutzer. Dieselbe Auskunft
    wie die beiden Gesten, ohne eine einzige Geste.
- **Die Karte zeichnete sich JEDE SEKUNDE neu — und rechnete dabei zehnmal
  alles durch** (`neuRechnen`, `Karteninhalt`, ab 1.1.16). Das ist der erste
  Befund in dieser Sache, der am Quelltext nachzuzählen ist statt zu
  plausibeln, und er ist alt genug, um zu passen: Er besteht, seit es Halte
  auf der Karte gibt (1.0.5) und Meldungstexte dazu (1.1.6) — also lange vor
  1.1.13.
  - **Woher die Sekunde kommt:** `AbfahrtstafelView` beobachtet das `Uhrwerk`
    für die Minutenziffern, sein Körper läuft also im Sekundentakt. Er reicht
    an `LiniennetzView` einen frischen Abschluss weiter (`umschalten`), und
    **ein Abschluss ist nicht vergleichbar** — SwiftUI kann nicht sehen, dass
    sich nichts geändert hat, und zeichnet die Karte mit.
  - **Woher der Aufwand kommt:** `sichtbareHalte` und `hinweise` waren
    BERECHNETE EIGENSCHAFTEN. `hinweise` wird an vier Stellen der Fußzeile
    ausgewertet und rechnete je Durchgang dreimal `sichtbareHalte`, dazu
    einmal die Karte selbst: zehn bis dreizehn volle Durchgänge je Zeichnung,
    jeder über bis zu 720 Halte, jeder Halt mit Textvergleich gegen die
    Meldungsliste (`Haltsperrung.passt`, mit Kleinschreibung und
    ausgeschriebenen Abkürzungen). Auf dem Hauptfaden — also genau dort, wo
    auch die Gesten der Karte bedient werden.
  - **Eine berechnete Eigenschaft sieht billig aus.** Genau das ist die Falle:
    `sichtbareHalte` las sich wie ein Feld und war ein Suchlauf. Sie heißt
    deshalb jetzt `berechneHalte()` — ein Name mit Klammern erinnert an jeder
    Aufrufstelle daran, dass dort gerechnet wird. Dieselbe Falle wie bei
    `Liniennetz.gebautAus` und `LiniennetzView.gesperrtJeLinie`, nur eine
    Ebene höher.
  - **Gerechnet wird an EINER Stelle** (`neuRechnen`) und nur auf einen
    Auslöser: neuer Linienstand, andere hervorgehobene Linie, neue
    Betriebsmeldungen, neuer Kartenausschnitt, Legende auf oder zu, neuer
    Bezugspunkt. **Wer etwas hinzufügt, das den Karteninhalt beeinflusst,
    trägt den Auslöser dort ein** — ein alter Stand auf der Karte ist der
    gefährlichere Fehler als ein Durchgang zu viel.
  - **`Liniennetz.stand` ist ein ZÄHLER, nicht `zuege.count`.** Nach einem
    Nachladelauf können dieselben zwölf Linien zurückkommen, bei denen ein
    Halt entfällt: Die Zahl bliebe gleich, der Inhalt nicht.
- **Und weil sich das hier nicht nachmessen lässt, misst es die App**
  (`Dienste/Kartenmesser.swift`, Einstellungen → „Karte prüfen", ab 1.1.16).
  Neuzeichnungen je Sekunde, Dauer eines Aufbaus, Zahl der gezeichneten Halte
  — kopierbar, ohne Deutung, mit der Zeitspanne dabei (eine Rate ohne ihren
  Zeitraum ist keine Messung). Dasselbe Muster wie Schulalarms Stufenprobe:
  **Wo sich eine Ursache nicht erschließen lässt, muss eine Probe
  entscheiden** — und nach zwei falschen Vermutungen ist das keine Zugabe
  mehr, sondern die Arbeit selbst.
  **Der Messfühler hat bewusst KEIN `@Published`**: Die Karte meldet an ihn,
  und wäre er beobachtbar, löste jede Meldung ein Neuzeichnen aus, das
  seinerseits gemeldet würde — ein Messgerät, das seinen eigenen Messwert
  erzeugt. Gelesen wird auf Knopfdruck.
- **Die Zwischenablage aus 1.1.16 reichte nicht** (gemeldet 09/2026). Sie war
  richtig und behandelte die falsche Hälfte: Gerechnet wurde seltener, gezeichnet
  weiterhin jede Sekunde — und der Aufwand steckte im GEZEICHNETEN.
- **Die Linienzüge sind das Gewicht, und das ist jetzt gemessen**
  (`Model/Linienvereinfachung.swift`, ab 1.1.17). **Der Befund kam vom
  Nutzer und war der erste belastbare in dieser Sache:** „Je mehr Linien im
  Spiel sind, desto länger dauert's." Nachgemessen am 18.09.2026 an genau den
  zwölf Linien, die die App am Münchner Hauptbahnhof zeichnet:
  **12.446 Stützpunkte**, davon allein **4.973 auf der Buslinie 68** (195
  Halte) — und jede Linie wird ZWEIMAL gezeichnet (erst alle Konturen, dann
  alle Linien), also rund 25.000 Koordinaten je Aufbau des Karteninhalts.
  - **Gedünnt wird auf den MASSSTAB** (Douglas-Peucker, Toleranz = was EIN
    Bildpunkt gerade bedeutet). Ein weggelassener Stützpunkt läge ohnehin auf
    demselben Pixel wie die Gerade, die ihn ersetzt. Gemessen an denselben
    Linien: 1 m → 3.281 Punkte (26 %), 3 m → 1.894 (15 %), 8 m → 1.055 (8 %),
    20 m → 647 (5 %), 50 m → 402 (3 %). **Beim Öffnen rahmt die Karte das
    ganze Netz** — dort gilt die letzte Zeile, aus 25.000 Koordinaten werden
    rund 800. Wer weit hineinzoomt, bekommt den vollen Verlauf zurück.
  - **Das ist KEINE erfundene Geometrie.** Der gezeichnete Weg bleibt der Weg
    aus den Daten; es fallen nur Punkte weg, die auf ihm liegen. Etwas anderes
    als eine geratene Umleitung oder eine durchgezogene Luftlinie — beides tut
    diese App weiterhin nicht, und die Grenze ist genau hier zu ziehen.
  - **Die Breite der Karte wird GEMESSEN** (`GeometryReader`), nicht
    angenommen: Eine feste Zahl wäre zwischen iPhone und iPad um das
    Zweieinhalbfache daneben. Lässt sich der Maßstab nicht feststellen, wird
    NICHT vereinfacht — eine geratene Toleranz wäre die eine Art Fehler, die
    man der Karte nicht ansieht.
  - **Die Toleranz ist auf Zweierpotenzen gestuft.** Ohne das rechnete jede
    Schiebebewegung alle zwölf Züge neu, weil sich die Breite um ein
    Tausendstel geändert hat.
  - **Douglas-Peucker ohne Rekursion**, mit eigenem Stapel: Fünftausend Punkte
    können tief schachteln, und ein Stapelüberlauf wäre ein Absturz für eine
    Linie, die nur etwas gröber gezeichnet werden sollte.
- **Eine Ansicht, die einen ABSCHLUSS bekommt, zeichnet immer mit**
  (`LiniennetzView: Equatable`, `.equatable()`, ab 1.1.17). `AbfahrtstafelView`
  beobachtet das `Uhrwerk` für die Minutenziffern, sein Körper läuft im
  Sekundentakt — und er reicht `umschalten` weiter. **Ein Abschluss lässt sich
  nicht vergleichen**, also musste SwiftUI von einer Änderung ausgehen und
  baute die Karte samt aller Linienzüge neu auf. Verglichen wird jetzt nur, was
  das Aussehen wirklich bestimmt (`imVollbild`); der Abschluss tut bei jedem
  Durchgang dasselbe. **Das schaltet nichts ab** — was die Ansicht selbst
  beobachtet, löst weiterhin ein Neuzeichnen aus. **Wer eine vierte
  Aufrufstelle anlegt, hängt `.equatable()` mit dran**, sonst zeichnet dort
  wieder die Uhr mit.
- **Ob damit das Zoomproblem erledigt ist, steht noch nicht fest.** Drei
  Erklärungen sind bisher gefallen und zwei davon waren Vermutungen; diese hier
  ist gemessen, aber gemessen ist die DATENMENGE und nicht die Wirkung auf dem
  Gerät. Nicht als erledigt darstellen — der Messfühler nennt seit 1.1.17 auch
  die Stützpunkte roh und gezeichnet.
- **Auf einer Karte darf kein Bedienelement liegen** (ab 1.1.18, Befund des
  Nutzers 09/2026: „wenn ich zoome und Haltestellen in der Nähe sind,
  funktioniert der Zoom nicht. Auch wenn es ein dicht besiedeltes Gebiet mit
  vielen Pins ist, schlägt der Zoom deshalb fehl."). Das ist der erste Befund
  in dieser Sache, der sagt, WANN es fehlschlägt — und er zeigt nicht auf die
  Linien, sondern auf die Punkte. **Nachgezählt am Quelltext:** Bis 1.1.17 war
  jeder der bis zu 260 Halte ein `NavigationLink`, jede Haltestelle aus der
  Liste ebenso und jedes Liniensymbol ein `Button`, und jedes davon trug über
  `trefferflaeche()` einen unsichtbaren Kreis von 32 Punkten. Bei 34 Punkten
  Abstand deckt ein Raster solcher Kreise rund 70 % der Fläche ab; in einer
  Innenstadt landen also beide Finger einer Zoomgeste mit hoher
  Wahrscheinlichkeit auf einem Bedienelement statt auf der Karte. **Merke:
  Eine Geste gehört der Karte; was auf ihr liegt, ist ein BILD.**
  - Die Punkte sind seit 1.1.18 `.allowsHitTesting(false)` — auch der
    Bezugspunkt und die Umstiegspunkte in `VerbindungDetailView`, die gar
    nichts tun: Was keine Aufgabe hat, darf erst recht keinen Finger
    schlucken.
  - Den Tipp nimmt die KARTE an (`LiniennetzView.tippen(_:_:)`) und sucht
    hinterher den nächsten Punkt in **Bildpunkten** (`MapProxy.convert`),
    Griffweite 26. Gerechnet wird also erst, NACHDEM klar ist, dass ein Tipp
    gemeint war — damit kostet die Griffweite keine Kartenfläche mehr und darf
    sogar großzügiger sein als der gezeichnete Punkt. Durchgegangen wird von
    unten nach oben, damit bei gleichem Abstand das gewinnt, was obenauf
    liegt; liegt nichts in Griffweite, zieht der Tipp wie bisher die Karte
    auf.
  - **Dafür braucht die Karte den Navigationsstapel selbst**
    (`LiniennetzView.pfad`, ein `@Binding` an `NavigationPath`). Das Ziel
    bleibt das eine, das in jedem Stapel eingetragen ist
    (`navigationDestination(for: Haltestelle.self)`) — ein eigenes Blatt wäre
    ein zweiter Weg zu derselben Ansicht und liefe irgendwann auseinander.
  - **Der Fahrtlauf (`StreckenKarte`) trägt die alte Bauweise noch.** Das ist
    Absicht: Es wird eine Sache auf einmal geändert, sonst sagt der nächste
    Befund nichts mehr. Hält die Erklärung, gehört sie mitgezogen.
  - **Nicht als erledigt darstellen.** Gemessen ist der AUFBAU (wie viele
    Bedienelemente auf der Karte lagen, jetzt null — der Messfühler nennt die
    Zahl der antippbaren Punkte seit 1.1.18 mit), nicht die Wirkung auf dem
    Gerät. Es ist die vierte Erklärung in dieser Sache; die ersten beiden
    waren Vermutungen, die dritte eine Datenmessung ohne Wirkungsnachweis.
- **Betriebsmeldungen sind eine EIGENE Sache neben der Abfahrtskette**
  (`Betriebsmeldung`, `Meldungsquelle`, `Dienste/Meldungsdienst.swift`, ab
  1.0.4; gemeldet 09/2026: „Ich weiß, dass bei mir vor Ort eine Buslinie
  gerade eine Umleitung fahren muss … Dieser aktuelle Stand ist in der App
  aber leider nicht zu sehen."). **Nachgemessen 18.09.2026: Transitous führt
  überhaupt keine Betriebsmeldungen** — weder an `/stoptimes` noch am
  `/trip`. Es kennt `cancelled` und `tripCancelled`, also Verspätung und
  Ausfall, aber nicht den GRUND und nicht die FOLGEN. Eine Umleitung ist für
  die erste Quelle unsichtbar. Die Verbünde führen sie sehr wohl (EFA:
  `infos[].infoLinks[]` mit Titel, Untertitel und Volltext; VRR Dortmund
  lieferte sechs, VVS Stuttgart hundert).
  **Daraus folgt die Bauweise:** Meldungen werden vom Verbund geholt, AUCH
  WENN die Abfahrten von Transitous kamen. Wer sie an die Abfahrtskette
  hängt, bekommt in ganz Deutschland keine — dort antwortet fast immer die
  erste Quelle. Deshalb ein drittes Protokoll und keine Kette: Antwortet der
  Verbund nicht, gibt es eben keine Meldungen, und die App sagt nichts,
  statt etwas zu behaupten.
- **Welche LINIEN eine Meldung betrifft, steht in den DATEN.** EFA hängt jede
  Meldung an die Abfahrten, für die sie gilt; gesammelt wird also über die
  Linien der Abfahrten, an denen sie hing. Den Titel nach „Linie 453" zu
  durchsuchen wäre die naheliegende Alternative — sie wackelt schon bei
  „Linien 400, 401" und gibt bei „Airport Express // Airport Shuttle" ganz
  auf. Genau diese Zuordnung trägt die Marke an der einzelnen Zeile, und die
  ist der Punkt: Eine Liste von acht Meldungen über der Tafel liest niemand,
  ein Dreieck neben der EIGENEN Linie sieht jeder.
- **Meldungen werden höchstens alle fünf Minuten geholt**, Abfahrten alle
  dreißig Sekunden. Eine Sperrung gilt bis Oktober; sie im Sekundentakt
  nachzuladen wäre eine Abfrage je halbe Minute für eine Auskunft, die sich
  nie ändert. Ein Fehlschlag LEERT die Liste nicht — eine Sperrung, die
  vorhin galt, gilt nach einem Netzaussetzer immer noch.
- **„Keine Meldung" und „keine Quelle" sind NICHT dasselbe.** Wo kein Verbund
  zuständig ist, sagt die App genau das: „Das heißt NICHT, dass alles
  planmäßig fährt — es heißt, dass niemand nachgesehen hat." Dieselbe Regel
  wie beim Wort „Plan" an einer Abfahrt ohne Echtzeit.
- **Eine Meldung sagt SELBST, ob ihre Änderung im Fahrplan steht**
  (`Betriebsmeldung.fahrplanhinweis`, `additionalText` bei EFA, ab 1.1.5;
  gemeldet 09/2026: „Bei der Linie 470 in Dortmund ist zwar die
  Störungsmeldung aufgeführt, die gesperrten Haltestellen sind aber als
  befahrbar aufgeführt."). Nachgemessen am 18.09.2026 an genau dieser Linie:
  Die Meldung des VRR nennt zwei gesperrte Haltestellen
  (Heinrich-Munsbeck-Straße, Hedwigstraße); in den Fahrplandaten entfällt eine
  dritte, ganz andere (Haus Dellwig) — und nur in Richtung Oespel, die
  Gegenrichtung hat gar keinen entfallenden Halt. Transitous und der Spiegel
  antworteten Wort für Wort gleich; es lag also weder an der Kette noch an
  `haltEntfaellt`. **Beides war richtig und wirkte zusammen falsch:** oben
  „Straße gesperrt", unten jeder Halt als angefahren. Die Auflösung stand die
  ganze Zeit in der Meldung — der Herausgeber schreibt dazu „Die beschriebenen
  Änderungen sind in der elektronischen Fahrplanauskunft (EFA) **nicht**
  berücksichtigt", und die App warf diesen Satz weg. Jetzt steht er wörtlich
  in der Meldungsliste, und über der Halteliste wie auf der Netzkarte steht
  das Band „Diese Änderungen stehen NICHT im Fahrplan". **Den Umleitungsweg
  zeigen kann die App weiterhin nicht** — er steht in keiner Quelle; was sie
  kann, ist es sagen.
- **Der Satz wird wörtlich gezeigt UND gedeutet** (`aenderungenImFahrplan`).
  Gedeutet wird an einem einzelnen Wort („nicht"), und das ist sonst genau
  die Art Raten, die dieses Papier verbietet (`linien` kommt ausdrücklich aus
  den Daten und nicht aus dem Titel). Der Unterschied: Dort geht es um eine
  Aufzählung in freier Formulierung, hier um EINEN feststehenden Satz eines
  Herausgebers, in beiden Ausprägungen gemessen — und der Wortlaut steht
  daneben, wer ihn liest, sieht sofort, ob die Deutung stimmt. Gemessen
  18.09.2026: VRR füllt das Feld (in beiden Richtungen), VVS, VRN und MVV
  lassen es leer. Es ist eine Zugabe, keine Zusicherung; `nil` heißt „der
  Verbund sagt nichts dazu" und ist der Regelfall.
- **Welche Haltestellen gesperrt sind, steht im TEXT — und wird daraus
  gelesen** (`Model/Haltsperrung.swift`, ab 1.1.6; Ansage des Nutzers 09/2026
  nach 1.1.5: „In dem Text steht ja, welche Haltestellen gesperrt sind."). Er
  hatte recht, und es ist die einzige Stelle, an der diese Auskunft existiert:
  Bei der Sperrung der Westricher Straße nannte die Meldung SECHS
  Haltestellen, die Fahrplandaten führten genau EINE davon (Haus Dellwig —
  die stand auf dem Kartenbild des Nutzers schon mit rotem Kreuz da, aus dem
  Weg von 1.0.8).
- **Gelesen wird die AUFZÄHLUNG, nicht der Satz — und das ist gemessen.** Am
  18.09.2026 wurden 104 echte Meldungen von zehn EFA-Abfragen (VRR, VVS, VRN,
  VVO, DING, MVV) eingesammelt und beide Schreibweisen ausgewertet:
  - **Überschrift + Liste** („Folgende Haltestellen entfallen:", auch „…der
    Linie 423…", auch „…in Richtung Feuersee:") ergab **29 Namen, jeder
    einzelne ein echter Haltestellenname**. Gebaut.
  - **Der Satz** („Die Haltestellen X und Y … entfallen.") ergab 21 Namen,
    davon mehrere falsch — und zwar auf die gefährlichste Art: In
    „Stadtauswärts fahren die Busse ab der Haltestelle ‚Heinrich-Heine-Allee,
    Steig 7‘ … Die Haltestelle ‚Benrather Straße‘ entfällt" wurde die
    ABFAHRTSHALTESTELLE eingesammelt, anderswo die Starthaltestelle einer
    Umleitungsfahrt. **Eine angefahrene Haltestelle als gesperrt zu markieren
    schickt den Menschen davor zur falschen Haltestelle** — schlimmer als gar
    keine Markierung. Bewusst NICHT gebaut; die Ewald-Görshop-Meldung wird
    deshalb nicht ausgewertet, und das ist kein Versehen.
  Wer die Satzform nachrüstet, misst zuerst wieder gegen echte Meldungen.
- **Der wichtigste Abbruch heißt „Nächste Haltestellen:".** Dahinter stehen
  die ERSATZhaltestellen, also genau die, die angefahren werden. Wer die
  mitliest, dreht die Auskunft um. Abgebrochen wird an jeder Zeile mit
  Doppelpunkt und an einer kurzen Liste von Anfangsworten.
- **Zugeordnet wird über EIN führendes Wort, nicht über das Zeilenende**
  (`Haltsperrung.passt`). Die Meldung schreibt „Haus Dellwig", die Daten
  „Dortmund Haus Dellwig" — der naheliegende Weg wäre eine Endprüfung
  gewesen, dann hätte aber „Dellwig" ebenfalls gepasst und ein zu kurzer Name
  markierte eine fremde Haltestelle. Dazu werden Abkürzungen auf `str`
  ausgeschrieben (VRR schreibt in derselben Meldung „Moltkestr." und
  „Düsseldorfer Str."). 16 von 16 Proben gehen auf, darunter sechs
  Gegenproben, die NICHT treffen dürfen. **Umlaute werden nicht eingeebnet.**
  Trägt ein Verbund einen zweiteiligen Ortsnamen, wird schlicht nicht
  markiert — eine Lücke ist besser als eine falsche Auskunft.
- **Die Richtung wird abgeschnitten und nicht ausgewertet.** Ein Halt, der nur
  in einer Richtung entfällt, wird damit in beiden markiert. Das ist die
  gewollte Richtung des Fehlers — ein Hinweis zu viel schickt jemanden in die
  Meldung, ein fehlender an eine Haltestelle, an der nichts hält. Die
  Oberfläche schreibt hin, dass manche Meldungen nur für eine Richtung gelten.
- **Zwei Herkünfte, zwei Zeichen.** Ein entfallender Halt aus den
  FAHRPLANDATEN bleibt rot durchgestrichen mit Kreuz; ein aus dem TEXT
  gelesener ist orange mit Ausrufezeichen und heißt „laut Meldung gesperrt".
  Sie werden nie vermischt: Der eine ist gemessen, der andere aus Fließtext
  gelesen — wer beides gleich zeichnet, macht aus einer Lesart eine Tatsache.
  Deckt die Datenlage den Halt schon ab, gewinnt Rot. Markiert wird in der
  Halteliste, auf der Streckenkarte und auf der Netzkarte, und unter jeder
  steht, woher die Auskunft kommt.
- **Die Nachschlagetabelle wird EINMAL gebaut** (`LiniennetzView.gesperrtJeLinie`).
  Der erste Entwurf fragte je Halt und baute sie dabei jedes Mal neu — zwölf
  Linien mit je sechzig Halten wären siebenhundert Durchgänge durch die
  Meldungsliste bei jedem Neuzeichnen. Dieselbe Falle wie bei
  `Liniennetz.gebautAus`, eine Ebene tiefer.
- **Einzelne EFA-Felder kommen DOPPELT KODIERT** (`Klartext.geradegerueckt`,
  ab 1.1.5). In derselben VRR-Meldung stand `subtitle` als tadelloses UTF-8
  („Verspätungen") und `additionalText` daneben als „Ã„nderungen" — die
  UTF-8-Bytes ein zweites Mal als UTF-8 geschrieben. Es ist ein Fehler des
  Herausgebers und keiner der Übertragung; `JSONDecoder` liefert dieselben
  Zeichen. Gerichtet wird nur, wenn BEIDES zutrifft: ein verräterisches
  Zeichen ist da, und das Zurückdrehen geht verlustfrei auf. Sonst bleibt der
  Text stehen — ein französischer Ortsname mit Ã ist kein Fehler, und ein
  geratener Fix träfe die Texte, die in Ordnung sind.
- **HTML wird von Hand entpackt** (`Fahrplan/Efa/Klartext.swift`). Die Texte
  der Verbünde kommen mit Markierungen und benannten Zeichen (`&szlig;`,
  `&uuml;`, `&ndash;`, `&nbsp;`) — ohne Rückübersetzung wäre jeder deutsche
  Text unlesbar. `NSAttributedString` könnte es und startet dafür intern
  WebKit, muss auf den Hauptfaden und braucht Zehntelsekunden je Absatz; für
  zwanzig Meldungen beim Laden der Tafel ist das genau die Arbeit, die eine
  scrollende Liste ruckeln lässt. Die Zeichenliste ist bewusst KURZ: Was
  fehlt, bleibt als `&name;` stehen und ist sichtbar falsch statt still
  falsch. **Die Anführungszeichen stehen dort als `\u{201E}` und nicht als
  Zeichen** — sonst schlägt `scripts/swift-quelltext-pruefen.py` an, und zwar
  zu Recht: Ein deutsches Anführungszeichen mitten in einem Swift-Text ist
  die eine Stelle, an der sich Inhalt und verunglücktes Ende nicht
  unterscheiden lassen.
- **`http://noHost` ist KEINE Adresse.** EFA setzt den Platzhalter ein, wenn
  nichts hinterlegt ist; als Verweis angeboten führte er ins Leere.
- **Die Fußzeile nennt die Quellen, die WIRKLICH beigetragen haben**
  (`AppModel.beteiligteQuellen`), nicht die eingebauten. „Transitous, VRR"
  unter einer Tafel, die ganz von Transitous stammt, wäre eine Angabe über
  die App und nicht über die Daten.
- **Der Sichtumschalter steht IM INHALT, nicht in der Werkzeugleiste**
  (`Sichtwahl` in `AbfahrtstafelView`, ab 1.0.5, gemeldet 09/2026: „Ich kann
  die Karte bei der Darstellung auf dem iPhone nirgends finden."). Bis 1.0.4
  war er ein `.pickerStyle(.menu)` in `ToolbarItem(placement: .topBarLeading)`
  — ein Symbol, das niemand aufklappt. **Auf dem iPad fiel das nicht auf**,
  weil die Karte dort von Haus aus neben der Liste steht; der Fehler war damit
  nur auf dem Gerät zu sehen, auf dem er zählt. Jetzt eine Segmentleiste
  „Haltestellen | Zeit | Karte" unter der Ortsleiste. Dieselbe Lehre wie beim
  Gruppenchat in Schulalarm und beim Zurücksetzen in Tafelbild: **Ein Knopf,
  den niemand findet, ist kein Knopf.** Nicht zurück in die Werkzeugleiste.
- **Die Halte der gezeichneten Linien stehen auf der Karte** (`Linienzug.halte`,
  `sichtbareHalte`, ab 1.0.5). Ein Linienzug ohne Punkte ist ein Strich über
  der Karte, an dem sich nicht ablesen lässt, ob er dort hält, wo jemand
  hinwill. Beschriftet wird aber NUR, wenn eine Linie hervorgehoben ist —
  sonst lägen dreihundert Haltestellennamen übereinander. **Über 260 Punkten
  werden GAR KEINE gezeichnet** und die Fußzeile sagt, wie man doch an sie
  kommt (eine Linie antippen): Jeder Punkt ist eine eigene SwiftUI-Ansicht,
  und ein paar willkürlich ausgewählte wären schlechter als keine — man hielte
  die Lücken für Wirklichkeit.
- **Ein Tipp auf einen Halt öffnet seine Abfahrtstafel** (ab 1.1.7, Ansage des
  Nutzers 09/2026: „Wenn ich in der Kartendarstellung bei einer Linie auf eine
  Haltestelle tippe, dann möchte ich Informationen zu dieser angezeigt
  bekommen."). Das Ziel gab es schon: `HaltestelleView`, dieselbe Ansicht wie
  aus der Liste und aus der Merkliste, samt Merken-Stern und eigenem
  Nachladen. Gebaut wurde deshalb KEIN neues Blatt, sondern ein
  `NavigationLink(value: halt.haltestelle)` — der
  `navigationDestination(for: Haltestelle.self)` steht in `AbfahrtstafelView`,
  in deren Stapel die Karte liegt. Ein eigenes Blatt wäre ein zweiter Weg zu
  derselben Ansicht und liefe irgendwann auseinander.
- **Antippbar sind BEIDE Sorten Punkte.** Auf der Netzkarte liegen die Halte
  der gezeichneten Linien (`sichtbareHalte`) UND die Haltestellen um den
  Bezugspunkt (`model.gruppen`) — wer nur die einen verlinkt, baut eine Karte,
  auf der die Hälfte der Punkte tot ist. Dazu die Halte des Fahrtlaufs in
  `StreckenKarte`.
- **Wer einen neuen Verweis auf eine Haltestelle baut, prüft den STAPEL.**
  `navigationDestination(for: Haltestelle.self)` stand in `AbfahrtstafelView`
  und `MerklisteView`, aber NICHT in `VerbindungView` — ein Fahrtlauf, der von
  einer Verbindung aus geöffnet wird, hätte dort einen Verweis gehabt, der
  nichts tut. Ein Verweis, der nichts tut, ist für den Menschen davor ein
  kaputter Knopf; das Ziel ist seit 1.1.7 in allen drei Stapeln eingetragen.
- **Der gezeichnete Punkt bleibt klein, die TREFFERFLÄCHE wird größer**
  (`Views/Trefferflaeche.swift`). 13 bis 17 Punkte sind als Zeichnung richtig
  — eine Buslinie hat sechzig Halte, größere Punkte wären eine Perlenkette
  statt einer Karte — und als Fingerziel zu klein; wer danebentippt,
  verschiebt die Karte und hält den Verweis für kaputt. Gelegt wird deshalb
  ein unsichtbarer Kreis darum, **32 Punkte und nicht die von Apple genannten
  44**: Bei 260 Halten überlappten sich die Flächen sonst so weit, dass
  regelmäßig der Nachbar aufginge. Trifft man doch den falschen, steht sein
  Name in der Überschrift der Tafel — der Irrtum ist sichtbar und nicht still.
- **Ein Weg, den niemand sieht, ist keiner.** Ein Kartenpunkt sieht nicht aus
  wie ein Knopf, deshalb steht der Satz „Ein Tipp auf einen Halt öffnet seine
  Abfahrtstafel" in den Hinweisen unter der Karte — vor den Erklärungen zur
  Zeichenweise, denn er sagt, was man TUN kann, und die anderen nur, was man
  sieht. Dieselbe Lehre wie beim Gruppenchat in Schulalarm und beim
  Sichtumschalter in 1.0.5.
- **Die Liniennummer liegt auf dem Zug**, nicht nur in der Legende
  (`beschriftungen`). Gesetzt an einem Anteil des Verlaufs, der sich mit der
  Stelle der Linie in der Liste verschiebt (0,22 bis 0,78) — zwölf Linien, die
  im Stadtzentrum übereinanderliegen, hätten sonst zwölf Schilder auf
  demselben Fleck.
- **Die Legende lässt sich ausblenden** (`legendeOffen`, ab 1.0.6, gemeldet
  09/2026). Auf einem iPhone deckt sie gut ein Viertel der Karte ab — also
  genau die Fläche, für die jemand die Kartensicht öffnet. Zwei Dinge gehören
  dazu, und beide sind die Lehre aus anderen Apps dieses Repos: **Zugeklappt
  bleibt ein sichtbarer Knopf stehen** (wie das Schloss des Sitzplans in
  Tafelbild — ein Bedienelement darf nicht mit der Beschriftung verschwinden),
  und **die Liniennummern auf der Karte sind KNÖPFE** und heben dieselbe Linie
  hervor wie die Zeile in der Legende. Ohne das wäre die zugeklappte Legende
  eine Sackgasse: Die Haltestellennamen hingen daran, sie wieder aufzuklappen.
  Die Wahl liegt in den Voreinstellungen (`@AppStorage` — in einer VIEW, nie
  in `AppModel`).
- **Unter der Karte steht EINE Hinweiszeile, nicht sechs** (`hinweise`,
  `fusszeileOffen`, ab 1.0.9, gemeldet 09/2026: „Der Text verdeckt einen großen
  Teil der Darstellung."). Bis 1.0.8 standen dort bis zu sechs Absätze
  untereinander und nahmen auf einem iPhone die halbe Karte. Das Missverhältnis
  ist der Punkt: Die Erklärungen sind wichtig, aber EINMAL — die Karte ist das,
  wofür jemand diesen Bildschirm öffnet. **Die Reihenfolge in `hinweise` ist
  die ganze Sache**: Zugeklappt steht nur der erste da, und das muss der sein,
  der etwas über die HEUTIGE Lage sagt (entfallender Halt, fehlende Linie) —
  die Erklärungen zur Zeichenweise gelten immer und stehen zuletzt. Wer einen
  neuen Hinweis anlegt, trägt ihn nach Wichtigkeit ein und nicht ans Ende.
- **Der WUNSCH trägt die Kartenmitte, kein Schalter daneben** (`Kartenwunsch`,
  `.sheet(item:)` in `OrtswahlView`, ab 1.0.9, gemeldet 09/2026: „kommt nach
  wie vor München als erster Vorschlag" — trotz 1.0.7). Bis 1.0.8 standen ein
  `Bool` und eine Koordinate nebeneinander, und das Blatt hing an
  `.sheet(isPresented:)`. **SwiftUI baut den Inhalt eines solchen Blattes aus
  dem Stand des LETZTEN Durchgangs**: Beide Werte in derselben Tat zu setzen
  half nicht — die Koordinate war beim Aufbauen noch `nil` und lief in den
  Rückfall, also nach München. Damit war 1.0.7 zwar richtig gebaut und trotzdem
  wirkungslos. **Dieselbe Regel steht seit Tafelbild 1.0.60 im Papier**
  („Der Wunsch trägt das Ziel, kein Schalter daneben"); hier ist sie ein
  zweites Mal bezahlt worden. Wer ein Blatt mit einem Wert öffnet, nimmt
  `.sheet(item:)`.
- **Der Bezugspunkt der Tafel ist der DRITTE Rückfall der Kartenmitte** (ab
  1.0.9). Zwischen zwei Ortungen ist `standort.stand` kurz nicht `.da`, die
  Tafel zeigt aber längst Abfahrten — ohne ihn fiele die Karte in genau diesem
  Augenblick auf die letzte Rettung zurück.
- **„Alles lila" hatte ZWEI Ursachen, und nur eine war unsere** (gemeldet
  09/2026 aus Berchtesgaden). Nachgemessen am 18.09.2026 an genau diesem Ort:
  Die **S4 ist wirklich violett** — `route_color = 9764ac`, von der
  Bayerischen Regiobahn selbst geführt. Daran wird nichts geändert; eine
  eigene Farbe daneben zu stellen wäre eine Verschlimmbesserung. Die **acht
  Buslinien** (837 bis 848, alle Bus RV Oberbayern) führen dagegen **gar keine
  Farbe** — sie fallen auf das Bus-Violett zurück, und die Abwandlung je Linie
  griff nicht. Wer so einen Befund liest, trennt also zuerst, was aus den
  Daten kommt und was aus dem Rückfall.
- **Der Streuwert stand an den SCHWÄCHSTEN Bits** (`Liniensymbol.streuwert`,
  behoben in 1.1.8). Bis 1.1.7 lief EIN FNV-1a-Durchgang, und die beiden
  Zahlen wurden als zwei Bitfenster daraus geschnitten — die erste aus den
  Bits 8 bis 23. Genau die sind bei FNV-1a die schwächsten: Der letzte Schritt
  ist eine Multiplikation, und deren niedrige Bits hängen nur von den
  niedrigen Bits der Eingabe ab. Namen, die sich bloß im letzten Zeichen
  unterscheiden — also die acht Buslinien einer Gegend —, bekamen damit fast
  denselben Wert. **Gemessen:** Der Farbton aller acht Linien lag in einem
  Fenster von 0,004, obwohl ±0,055 erlaubt sind; 838 und 839 bekamen dieselbe
  Farbe auf den Punkt. Jetzt zwei Durchgänge mit verschiedenem Startwert, je
  mit dem Schlussmischer von splitmix64; der kleinste Farbabstand
  verzehnfacht sich (schlechtester Fall über Berchtesgaden, Dortmund, München
  und einen gemischten Satz: 0,0018 → 0,0178).
- **Die Spanne war zu eng — und die erste Antwort darauf war falsch** (ab
  1.1.9, Ansage des Nutzers 09/2026 nach 1.1.8: „Am Ende des Tages ist immer
  noch alles lila. Selbst wenn man jetzt ein paar leichte Farbnuancen
  unterscheiden kann. Ich möchte es aber deutlicher haben."). In 1.1.8 stand
  hier, ±0,055 im Farbton seien richtig gewählt und nur nie ausgeschöpft
  worden. Das war eine Aussage über HSB-Einheiten, ausgegeben als Aussage über
  das, was ein Mensch sieht. Nachgemessen am 18.09.2026 in CIE Lab, also in
  dem Maß, das für die Wahrnehmung gebaut ist: Der kleinste Abstand zwischen
  zwei der acht Berchtesgadener Linien lag nach 1.1.8 bei **dE 1,6** — die
  Unterscheidungsschwelle liegt bei etwa 2,3. Die „Verzehnfachung" von 1.1.8
  war real und trotzdem unsichtbar. **Wer eine Farbdifferenz beurteilt, misst
  sie in dE und nicht in Farbtonanteilen.**
- **Zwölf Töne in drei Helligkeiten, zugeordnet über die LINIENNUMMER**
  (`Model/Linienfarben.swift`, ab 1.1.9). 36 Plätze, kleinster Abstand
  untereinander dE 15,5. Zugeordnet wird über die Ziffern des Liniennamens,
  NICHT über einen Streuwert: Ein Streuwert verteilt zufällig, und vierzehn
  Linien auf zwölf Farben ergaben in Salzburg nur acht belegte Farben und
  sieben Doppel (Geburtstagsproblem). Benachbarte Buslinien einer Gegend sind
  aber fortlaufend nummeriert — 837, 838, 839 —, und `zahl % 36` gibt genau
  denen garantiert verschiedene Plätze. Gemessen an vier echten Sätzen:
  Berchtesgaden 7/7, Salzburg 14/14, München 10/10, Dortmund 9/10 (448 und
  412 liegen genau 36 auseinander). Eine Linie ganz ohne Ziffern bekommt ihren
  Platz aus dem Streuwert — **nie aus `hashValue`**, den streut Swift je
  Programmlauf zufällig.
- **Die Farbfamilie des Verkehrsmittels ist dafür aufgegeben — beim RÜCKFALL.**
  Das klingt teurer, als es ist: Eine Linie MIT eigener Farbe hielt sich nie
  an die Familie, und genau das stand auf dem Bildschirmfoto des Nutzers — die
  S4 führt `route_color 9764ac` und war damit so violett wie jeder Bus daneben.
  Die Farbe des Schildes hat das Verkehrsmittel also nie verlässlich genannt.
  Wo es wirklich um das Verkehrsmittel geht, steht die Farbe unverändert: in
  der Filterleiste („Busse", „S-Bahnen" — `Verkehrsmittel.rueckfallfarbe`).
  Dazu steht seit 1.1.9 in der Legende der Netzkarte das SYMBOL des
  Verkehrsmittels neben dem Schild, und die Fußzeile sagt ausdrücklich, dass
  eine selbst vergebene Farbe nur unterscheidet.
- **Drei Helligkeiten gehen nur als dunkel / Grundton / hell.** Der erste
  Entwurf hellte in zwei Schritten auf (30 % und 55 %) — und die mittlere
  Stufe trägt WEDER schwarze noch weiße Schrift: gemessen 2,6:1 bis 3,7:1, und
  4,5:1 wären nötig. Gebaut ist jetzt Grundton (weiße Schrift, 4,6:1), mal
  0,60 und 40 % in Richtung Weiß; schlechtester Schriftkontrast über alle 36
  Plätze 4,6:1. **Die beiden Bedingungen ziehen gegeneinander**: Je heller die
  helle Stufe, desto besser trägt schwarze Schrift und desto blasser und
  ähnlicher werden die Töne untereinander (bei 62 % fiel der kleinste Abstand
  von dE 15,5 auf 10,0). Gesucht war nicht das Maximum von einem, sondern das
  beste Paar.
- **Die Schriftfarbe entscheidet ein VERGLEICH, keine Schwelle** (ab 1.1.9).
  Bis 1.1.8 galt `wahrgenommeneHelligkeit > 0,6` → schwarz, sonst weiß. Ein
  mittelheller Ton liegt darunter, bekam weiße Schrift und trug sie nicht.
  Jetzt gewinnt schlicht die Farbe mit dem größeren Kontrastverhältnis.
- **Ein Linienzug bekommt eine KONTUR** (`LiniennetzView.konturfarbe`, ab
  1.1.9). Gemessen 18.09.2026 gegen die Kartenhintergründe: Ein dunkler Ton
  auf der dunklen Karte kommt auf 1,8:1, ein heller auf der hellen Karte auf
  2,0:1 — zu wenig, um einen Strich über die Karte zu verfolgen. **Das galt
  schon vorher und gilt auch für jede Farbe, die ein Verbund selbst führt**;
  es ist also kein Preis der neuen Palette, sondern ein alter blinder Fleck,
  der beim Messen auffiel. Gezeichnet wird deshalb erst die Kontur (drei
  Punkte breiter, Gegenfarbe zur Darstellungsart) und dann die Linie —
  **erst ALLE Konturen, dann ALLE Linien**, sonst deckt die Kontur der einen
  die schon gezeichnete andere zu. Nicht `Color.primary`: Das ist die Farbe
  für Schrift und wäre auf der dunklen Karte ein reines Weiß.
- **Eine Farbe aus den Daten darf doppelt vorkommen.** Gemessen in München:
  Die Buslinien 100, 132, 153 und 154 tragen alle `325868`, die 52, 58, 62 und
  68 alle `d3762b` — das ist die Hausfarbe des Betreibers und keine Panne. Die
  eigene Farbvergabe greift deshalb ausdrücklich NUR beim Rückfall: Wo der
  Verbund eine Farbe führt, gilt seine, auch wenn zwei Linien gleich aussehen.
- **Das Liniensymbol nennt seit 1.1.29 das VERKEHRSMITTEL** (`Liniensymbol.mitMittel`;
  gemeldet 09/2026: „Nur Busse sind ausgewählt" — und in jedem der vier
  Vorschläge stand ein Schild „RE1"). **Der Filter hatte recht.** Nachgemessen
  am 21.09.2026 an derselben Strecke (Duisburg Großenbaum, nachts,
  `transitModes=BUS`): Die Abschnitte kommen als `mode = BUS`, `routeType = 3`
  zurück, `routeLongName = "SEV RE 1"`, Betrieb National Express — ein
  **Schienenersatzverkehr**. Er behält den NAMEN der Bahnlinie und deren Farbe
  (`route_color 9b1b60`). Auf dem Schild stand damit alles, was nach
  Regionalzug aussieht, und nichts, was ihn als Bus ausweist.
  - **Der Name hat das Verkehrsmittel nie genannt, und die Farbe seit 1.1.9
    auch nicht mehr** — dort steht es schon: „eine selbst vergebene Farbe
    unterscheidet nur", und die Legende der Netzkarte bekam deshalb das Symbol
    daneben. Was fehlte, war dieselbe Auskunft überall sonst. **Merke: Wer eine
    Auskunft an EINER Stelle nachrüstet, prüft, wo sie sonst noch fehlt.**
  - **Gezeigt wird das gemessene `mode`, nicht eine Lesart des Namens.** Aus
    „RE1" zu schließen, dass etwas ein Zug ist, wäre genau das Raten, das
    diesen Fehler erzeugt hat. Und ein Textmerkmal für Ersatzverkehr gibt es
    nicht: Derselbe Durchgang gab eine Linie „S1" als Bus zurück, dort aber mit
    **leerem** `routeLongName`. Das `mode` gibt es immer.
  - **Gesetzt ist es, wo Schilder in einer LISTE stehen** (Ergebniszeile der
    Auskunft, Abschnitte einer Verbindung, Abfahrtszeile, Kopf des Fahrtlaufs).
    Bewusst NICHT auf der Netzkarte — dort ist das Schild eine Marke auf einem
    Linienzug, und breitere Marken decken die Fläche zu, für die die Karte
    geöffnet wird (dieselbe Rechnung wie 1.1.18) —, nicht in deren Legende
    (dort steht das Symbol seit 1.1.9 links daneben, es wäre dasselbe zweimal)
    und nicht in der schmalen Leiste der Vergleichskarte (die Kette ist auf
    sechs Schilder gedeckelt, und jedes Schild breiter zu machen nähme genau
    den Platz wieder weg).
  - Dazu ein Satz in der Fußzeile der Auskunft, der den Fall benennt. Eine
    Anzeige, die stimmt, aber missverstanden wird, ist für den Menschen davor
    ein Fehler — dieselbe Regel wie bei „Plan" gegen „pünktlich".
- **Das Symbol sagt WAS, nicht WARUM — und das reichte nicht** (`Ersatzverkehr`,
  `Views/Linienzusatz.swift`, ab 1.1.30; Ansage des Nutzers 09/2026 zu 1.1.29:
  „RE 1 und S1 sind Züge. Definitiv."). **Er hat recht, und 1.1.29 hatte auch
  recht** — es sind zwei verschiedene Sätze: RE1 und S1 SIND Bahnlinien; was
  nachts auf ihnen fährt, ist ein Bus. Nachgemessen am 21.09.2026 auf BEIDEN
  Seiten, und das ist der Teil, der 1.1.29 fehlte:
  - **Duisburg Hbf → Großenbaum**: die S1 als `mode = METRO` in **7 Minuten**
    (mittags), dieselbe Strecke als „S1" mit `mode = BUS` nachts in **20** —
    über „Duisburg Schlenk Bf" und „Duisburg Buchholz Bf", Betrieb
    „Nahreisezug" statt „DB Regio AG NRW", ohne Linienfarbe.
  - **Essen Hbf → Duisburg Hbf** gab es an dem Tag als Bahn GAR NICHT; der
    „RE1" von National Express braucht 41 Minuten und trägt
    `routeLongName = "SEV RE 1"`.
  - Eine „S6" hält als Bus an „Essen Stadtwaldplatz", eine „U76" an
    „Meerbusch Büderich,Landsknecht" — Straßenhaltestellen.
  **Merke: Ein Widerspruch des Nutzers ist nicht automatisch ein Fehler im
  Befund — er kann auch heißen, dass der Befund die falsche Frage beantwortet
  hat.** Hier war die Messung richtig und die ANZEIGE unvollständig: Ein
  Bussymbol auf einem RE1-Schild sagt, was fährt, aber nicht warum, und wer
  weiß, dass der RE1 ein Zug ist, hält das Symbol für einen Fehler der App.
  - **Das Wort stand die ganze Zeit in den Daten** (`routeLongName`), und die
    App warf es weg. **Dieselbe Lehre wie beim `additionalText` in 1.1.5** —
    wo die Quelle ihre eigene Lage erklärt, wird die Erklärung nicht
    weggeworfen. `Linienkennung.langname` trägt sie jetzt mit; gezeigt wird
    sie an EINER Stelle (`Linienzusatz`) und von allen vieren benutzt.
  - **Gedeutet wird ein feststehender Ausdruck, der Wortlaut steht daneben** —
    dieselbe Bauweise wie `Betriebsmeldung.fahrplanhinweis`. **Verglichen wird
    WORTWEISE**: „SEV" steckt auch in „Sevenum" (Grenzort, in dieser App über
    `Grenzfall` längst ein Thema) und in „Sevilla"; eine Teilstringsuche machte
    aus einer Bahn nach Sevenum einen Ersatzverkehr. Dieselbe Lehre wie 1.1.22.
  - **Ein Feld dafür gibt es NICHT.** GTFS kennt den Typ 714 („Rail Replacement
    Bus Service") — gemessen an 194 Busabschnitten über sechs Strecken
    (Düsseldorf, Berlin, Hamburg, Köln, Stuttgart, München, je zwei Zeiten) kam
    er **kein einziges Mal** vor; es gab nur 3 und 700. Und 3 gegen 700 trennt
    nichts: Ein gewöhnlicher Rheinbahn-Stadtbus trägt 3, ein Essener Nachtbus
    700. Auch `alerts` gibt es an `/plan` nicht.
  - **Hingeschrieben hat es genau EINER** (National Express, „SEV RE 1");
    S1, S6, S28 und U76 kamen mit LEEREM Langnamen. Wo der Satz fehlt, sagt die
    App nichts dazu — eine Lücke ist besser als eine erfundene Erklärung, und
    das Verkehrsmittelsymbol bleibt der gemessene Teil der Auskunft.
  - **Ein Ersatzverkehr steht in den MUSTERDATEN** — sonst ließe sich die
    Anzeige nur ansehen, wenn gerade irgendwo eine Strecke gesperrt ist;
    dieselbe Überlegung wie beim entfallenden Halt in Fasangarten.
- **Ersatzverkehr lässt sich HERAUSFILTERN** (`Verbindungsfilter.ohneErsatzverkehr`,
  ab 1.1.31, Ansage des Nutzers 09/2026). Erkannt wird er auf ZWEI Stufen, und
  die werden nie vermischt — dieselbe Bauweise wie bei den entfallenden Halten
  seit 1.1.6.
  - **Stufe 1, die Quelle sagt es selbst — und zwar an ZWEI Stellen.**
    National Express schreibt es in den LANGnamen (`routeLongName = "SEV RE 1"`,
    „SEV RE 5X"), die Albtal-Verkehrs-Gesellschaft in den KURZnamen: Dort heißt
    die Linie schlicht „SEV S7/S71". **Wer nur eines der beiden Felder liest,
    verliert die Hälfte** — 1.1.30 las nur den Langnamen.
  - **Stufe 2, ein BUS trägt den Namen einer Bahnlinie** (RE, RB, S, U, IC,
    ICE, EC, RS, MEX mit Ziffer). Das ist **die eine Stelle, an der diese App
    einen Liniennamen auswertet**, und sie ist gemessen (21.09.2026):
    1434 Busabschnitte an zwölf deutschen Strecken zu vier Tageszeiten, 360
    verschiedene Buslinien; die Buchstabenvorsätze echter Busse waren `M`, `N`,
    `NE`, `SB`, `X` und `BER` — **keiner stößt mit der Liste zusammen**.
    Getroffen wurden 130 Abschnitte, jeder einzelne von einem Bahnbetrieb.
  - **Die 18 gefundenen Linien wurden EINZELN nachgefragt**, auf ihrer eigenen
    Strecke: elf gibt es dort nachweislich als Schiene. Bei den übrigen gab die
    Schienenabfrage **gar nichts** zurück — genau das, wonach eine gesperrte
    Strecke aussieht. **Kein einziger Treffer war eine gewöhnliche Buslinie.**
    Dazu 125 Busabschnitte im Ausland (Amsterdam bis Salzburg): kein
    Fehltreffer. Dänische S-Busse heißen `300S`, die Ziffer steht vorn; `T`
    steht bewusst NICHT in der Liste, weil `T1` in Frankreich eine Straßenbahn
    ist und der Buchstabe ungemessen blieb.
  - **Gesiebt werden BEIDE Stufen.** Von den 130 Abschnitten schrieben nur 39
    es auch hin — ein Filter allein auf das Wort griffe nicht einmal in jedem
    dritten Fall. Der Preis steht in der Fußzeile: Eine Buslinie, die wirklich
    „S5" hieße, fiele mit heraus; in 1559 gemessenen Abschnitten gab es keine,
    ausschließen lässt es sich nicht.
  - **Zwei Hypothesen sind dabei gefallen, und beide stehen hier als
    widerlegt.** Die Form der `routeId` trennt nichts (994 gewöhnliche Busse
    tragen strukturierte Kennungen `de:…`, 310 anonyme; bei den bahnartigen
    42 gegen 88) — sie sah bestechend aus, weil die echte S1
    `de-DELFI_de:nrw:s1:_109` heißt und der Ersatz `de-DELFI_3958503_3`. Und
    `routeType` 3 gegen 700 trennt ebenfalls nichts: Ein Rheinbahn-Stadtbus
    trägt 3, ein Essener Nachtbus 700.
  - **Der Filter kann NICHT in die Anfrage** — anders als Verkehrsmittel und
    Deutschland-Ticket. Der GTFS-Typ **714** („Rail Replacement Bus Service")
    kam in 1559 Abschnitten **kein einziges Mal** vor, `alerts` gibt es an
    `/plan` gar nicht, und einen Parameter dafür kennt MOTIS nicht. Gesiebt
    wird hinterher, und bleibt nichts übrig, sagt die Meldung, dass das eine
    Aussage über den FILTER ist und nicht über den Fahrplan.
  - **Was er nicht findet, steht auch da:** ein Ersatzverkehr unter
    gewöhnlicher Busnummer, und Kürzel, die sich nicht nachprüfen ließen —
    ÖBB „SV190" (Braunau/Inn Bf → Friedburg Bf, 62 min) und DB „EBU" (DB
    Fernverkehr, 115 min). Beide sehen sehr danach aus; **was sich nicht
    nachschlagen lässt, wird nicht geraten.**
  - **Offen und nicht als erledigt darstellen:** Auf der TAFEL gibt es diesen
    Filter nicht. Ein Ersatzverkehr ist dort ein Bus und fällt damit aus dem
    Filter „S-Bahnen" heraus — wer wissen will, ob seine S1 ersetzt wird, sieht
    sie unter „Busse". Markiert ist sie (Symbol und `Linienzusatz`), gefiltert
    nicht.
- **31 Punkte lagen brach, und trotzdem wurde abgeschnitten** (`AbfahrtsZeile`,
  ab 1.1.32; gemeldet 09/2026: „Das ist nicht gut lesbar. Da wird vieles
  abgeschnitten." — in jeder Zeile stand „Dortmund…" und dahinter drei Punkte).
  **Am Bildschirmfoto nachgemessen** (iPhone, 1206 px = 402 pt, 3×), und der
  erste Befund war der überraschende:
  - **Die Titelzeile brach bei 135,3 pt ab — auf den Punkt dort, wo die
    Detailzeile darunter endet** („01 · 07:42 +7 07:49"), während bis zur
    Minutenspalte 166,7 pt zur Verfügung standen. **Eine `VStack` in einer
    `HStack` mit `Spacer` bekommt ihre IDEALBREITE**, und die ist das Maximum
    dessen, was die Kinder für sich verlangen — hier also die schmale Zeile
    darunter. Der `Spacer` nahm den Rest. Abhilfe:
    `.frame(maxWidth: .infinity, alignment: .leading)` an der Spalte, und der
    `Spacer` fällt ersatzlos weg. **Merke: Wenn Text abgeschnitten wird und
    daneben Platz frei ist, ist nicht der Text zu lang — die Spalte ist zu
    schmal.**
  - **Eine Zeile reicht für ein Fahrtziel nicht.** Jetzt zwei; abgeschnitten
    wird erst, wo auch zwei nicht reichen.
  - **Das Liniensymbol ist seit 1.1.29 breiter** (gemessen 70,7 pt statt der
    52 pt Mindestbreite von vorher) — das Verkehrsmittelsymbol kostet knapp
    19 pt. Es bleibt: Es ist die Antwort auf den Befund von 1.1.29. Aber es
    gehört in die Rechnung, wenn wieder einmal etwas nicht passt.
  - **Die Minutenspalte bleibt bei 62 pt.** Gemessen braucht „8 min" nur 38 pt
    — der Wert ist aber für „jetzt" in 24 pt gesetzt, und ohne feste Breite
    wandert die Ziffernspalte, sobald irgendwo „jetzt" auftaucht.
- **Der Ortsname stand ZWEIMAL da** (`Views/Richtungsname.swift`, ab 1.1.32).
  Die Haltestelle hieß „Dortmund Neu-Crengeldanz-Str.", das Ziel „Dortmund …"
  — das zweite „Dortmund" fraß genau den Platz, an dem das Ziel steht.
  **Nachgemessen am 23.09.2026 an 1680 Abfahrten in zwanzig deutschen
  Städten: 33 % aller Ziele beginnen mit demselben Wort wie ihre
  Haltestelle.** Das ist eine Eigenart der Verbünde und verteilt sich
  entsprechend: Essen 86 %, Frankfurt 84 %, Dortmund 76 %, Bochum 74 %,
  Wuppertal 69 %, Hannover 67 %, Köln 66 %, Duisburg 60 %, Augsburg 42 %,
  Berlin 13 %, Kiel 9 %, Dresden 6 %, Hamburg 3 %, Leipzig/Bremen/Mainz 1 % —
  und **München, Stuttgart, Nürnberg, Düsseldorf 0 %**. Wo die
  Haltestellennamen den Ort gar nicht tragen, ändert die Regel also nichts.
  - **Gestrichen wird nur das ERSTE Wort und nur bei Wort-für-Wort-Gleichheit**
    (Groß/Klein egal, **Umlaute nicht eingeebnet**). An den Gegenproben
    derselben Messung geprüft: „Dortmund Hbf → **München Hbf**" bleibt stehen —
    dort ist der Ort die ganze Auskunft —, ebenso „→ Oberhausen Hbf",
    „→ Enschede", „→ Bochum-Langendreer" (ein Bindestrichname ist EIN Wort)
    und „→ DO-Walbertstraße/Schulmuseum" (eine Abkürzung ist nicht der
    Ortsname; sie zu erraten wäre genau das, was diese App nicht tut). Ein
    Ziel, das NUR aus dem Ort besteht, bleibt ebenfalls stehen.
  - **Gekürzt wird in der ANSICHT, nicht in den Daten.** `Abfahrt.richtung`
    trägt weiter den vollen Namen; er steht im Fahrtlauf über der Karte und in
    der Überschrift der Haltestelle. Gekürzt wird nur die Zeile, in der der
    Ort ohnehin direkt daneben steht.
  - **Die Regel lässt sich ansehen** — in der Vorschau von `Richtungsname`, an
    den gemessenen Paaren samt Gegenproben. NICHT in den Musterdaten: Die
    Beispieltafel spielt in München, und dort gibt es den Fall nachweislich
    nicht (0 %).

## Verbindungsauskunft (ab 1.1.0)

- **Zweiter Reiter, nicht Untermenü der Tafel** (Ansage des Nutzers, 09/2026:
  „Ich möchte die App zu einem echten Verbindungsplaner ausbauen."). Das sind
  die zwei Fragen, mit denen man eine ÖPNV-App öffnet — „was fährt hier weg"
  und „wie komme ich dorthin". Eine Auskunft im Untermenü einer Tafel fände
  niemand; eine Tafel, die plötzlich eine Reise plant, wäre zwei Dinge auf
  einmal.
- **`/plan` ist die Auskunft, und die Orte reisen als KOORDINATEN.** Mit einer
  Haltestellenkennung antwortet sie mit 404 (nachgemessen 19.09.2026). Die
  Vorschlagsliste liefert ohnehin zu jedem Treffer Breite und Länge.
- **Eine leere Ergebnisliste ist kein Fehler, sondern eine Auskunft.** `/plan`
  antwortet mit HTTP 200 und null Verbindungen, wenn nichts fährt (gemessen mit
  Dortmund → New York). Dafür gibt es `Fahrplanfehler.keineVerbindung` als
  eigenen Fall, und `zeitHilft` trägt bis zum Knopf durch: „Noch einmal
  versuchen" hilft nicht, wenn nachts nichts fährt — eine andere Zeit schon.
  Dieselbe Bauweise wie `keineHaltestelleInDerNaehe`.
- **Die Vorschlagsliste braucht ZWEI Abfragen** (`TransitousDienst.orteSuchen`).
  `/geocode` kennt `placeBias`, und der wirkt kräftig — mit ihm gibt „kle" bei
  Dortmund lauter Dortmunder Treffer, ohne ihn Zürich, Paris und Cleveland.
  Zwei Fallen, und jede für sich macht die Liste unbrauchbar:
  **`type=STOP` schaltet den Ortsbezug AUS** (mit beiden zusammen kamen für
  „kle" wieder Paris und Tschechien — gefragt wird deshalb ohne `type`, und die
  Haltestellen werden in der App herausgesucht), und **mit Ortsbezug ist die
  Ferne unerreichbar** („Köln Hbf" gab bei Dortmund den Dortmunder
  Hauptbahnhof, „Hamburg Hbf" ebenso). Eine Auskunft, die Köln nicht findet,
  ist keine. Also beides nebenläufig und zusammengeführt: das Nahe zuerst, das
  Ferne dahinter. **Wer hier auf eine Abfrage zurückbaut, bricht eine der
  beiden Hälften.**
- **Bis 1.0.10 war die Haltestellensuche NIE örtlich.** Sie schickte `type=STOP`
  UND `place` — also genau die Kombination, die den Ortsbezug abschaltet — und
  darüber stand ein Kommentar, der das Gegenteil behauptete. Ein Kommentar ist
  keine Messung.
- **Unter drei Zeichen antwortet die Quelle mit einer LEEREN Liste**, nicht mit
  einem Fehler („k" und „kl" null Treffer, „kle" zehn). Die Zahl steht deshalb
  am Protokoll (`Fahrplandienst.kuerzesteSuche`) und nicht in der Ansicht: Wie
  kurz eine Eingabe sein darf, weiß nur die Quelle. Die Oberfläche schreibt
  hin, wie viele Zeichen noch fehlen — eine leere Liste sähe aus wie „nichts
  gefunden".
- **Der Bezugspunkt der Vorschläge ist erst der gewählte Start, dann der eigene
  Standort** (`bezugFuerVorschlaege`). Wer als Start „Dortmund Hbf" eingetippt
  hat, sucht sein Ziel in Dortmund und nicht dort, wo das Telefon gerade liegt.
- **Die Verbindungsauskunft hat seit 1.1.1 eine ZWEITE REIHE**
  (`Verbindungsquelle`, `EfaVerbindungen.swift`, `SchweizVerbindungen.swift`).
  In 1.0.11 stand hier, die Verbünde gäben eine Abfahrtstafel heraus und sonst
  nichts. **Das war falsch**, nachgemessen am 19.09.2026: `XSLT_TRIP_REQUEST2`
  antwortete an ALLEN ACHT Stellen aus `EfaDienst.alle` mit vollständigen
  Verbindungen — Fußwege, Umstiege, Zwischenhalte (`stopSequence`),
  Streckengeometrie (`coords`) und Echtzeit (`isRealtimeControlled`); die
  Schweizer `/v1/connections` ebenso, ohne Geometrie. Der Satz beschrieb also,
  was DIESE App gebaut hatte, und gab sich als Auskunft über die Schnittstelle
  aus. Jetzt ist der Rückfall gebaut.
- **`Verbindungsquelle` ist das DRITTE Protokoll — aus demselben Grund wie das
  zweite.** `Abfahrtsquelle` gibt es, weil EFA keine Streckengeometrie zu einer
  einzelnen Fahrt kennt; `Verbindungsquelle` gibt es, weil dieselben Stellen
  eine Reiseauskunft können, aber weder die Ortssuche für die Vorschlagsliste
  noch einen Fahrtlauf. Sie als `Fahrplandienst` auszugeben hieße, sechs
  Methoden zu versprechen und vier mit „geht nicht" zu beantworten.
- **Zuständig ist eine Quelle nur, wenn BEIDE Punkte in ihrem Gebiet liegen.**
  Das ist der Unterschied zur Tafel: Eine Tafel gilt für einen Punkt, eine
  Verbindung für zwei. Dortmund → Köln kann nur Transitous, und eine Anfrage,
  die garantiert nichts bringt, ist in einer Kette nur Wartezeit. Die
  Gebietsprüfung steht deshalb an EINER Stelle je Quelle
  (`EfaStelle.enthaelt`, `SchweizDienst.imGebiet`) und wird von Tafel und
  Auskunft gemeinsam benutzt.
- **„Nichts gefunden" und „nicht geantwortet" werden in der Kette GETRENNT
  gezählt** (`Kettendienst.Versuch`). Antwortet eine Quelle sauber mit
  `.keineVerbindung`, wird die nächste trotzdem gefragt — am Ende aber genau
  das gemeldet und nicht „keine Quelle antwortet". Die beiden verlangen
  verschiedene Knöpfe: gegen „es fährt nichts" hilft eine andere Zeit, gegen
  „niemand hat geantwortet" ein zweiter Versuch. Derselbe Unterschied wie
  zwischen „Plan" und „pünktlich".
- **Die Verbindungsauskunft hat KEINEN Zwischenspeicher**, die Tafel schon.
  Eine Abfahrtstafel von vorhin ist mit Altersangabe noch etwas wert; eine
  Verbindungssuche gilt für zwei Punkte und eine Uhrzeit, und die sind beim
  nächsten Mal andere. Ein Treffer von gestern wäre kein alter Stand, sondern
  die Antwort auf eine andere Frage.
- **Die Fußzeile nennt die Quelle, die WIRKLICH geantwortet hat**
  (`Verbindung.quelle`, `Verbindungsmodell.beteiligteQuellen`). Bis 1.1.0 stand
  dort fest `dienst.quellenname`, also „Transitous" — auch unter einer
  Auskunft, die vom VRR kam. Dieselbe Regel wie bei `AppModel.beteiligteQuellen`
  an der Tafel.
- **Eine Fahrt OHNE Streckenführung wird GESTRICHELT gezeichnet**
  (`VerbindungsKarte.strichelt`, ab 1.1.1). Der Schweizer Dienst liefert gar
  keine Geometrie; bis 1.1.0 lag daraufhin eine durchgezogene Gerade quer über
  der Karte und sah aus wie ein Fahrweg. Verbunden werden jetzt die HALTE (nicht
  nur Anfang und Ende — die Lage jedes Haltes ist ja bekannt), gestrichelt, und
  unter der Karte steht, was das heißt. Dieselbe Regel wie bei der
  gestrichelten Luftlinie im Fahrtlauf.
- **In der EFA-REISEAUSKUNFT steht in `realtimeStatus` ein WORT, im
  Abfahrtsmonitor eine ZIFFER.** Gemessen 19.09.2026 an allen acht Stellen:
  durchweg `MONITORED`. Die Ziffer `5` („entfällt") des Monitors kommt hier
  nie vor — wer die Prüfung von dort herüberkopiert, prüft auf etwas, das es
  in dieser Antwort nicht gibt.
- **EFA-Produktklasse 13 ist der REGIONALZUG** (gefunden 19.09.2026 bei VRR,
  VVS und VVO: „R-Bahn", „Regionalzug"). Sie fehlte in `verkehrsmittel`, und
  ohne sie fiel jeder RE und jede RB in den Vorgabefall und stand grau als
  „Sonstiges" da — während dieselbe Fahrt über Transitous ein Regionalzug war.
  Der Fehler betraf auch die Tafel, nicht nur die neue Auskunft.
- **Die EFA-Reiseauskunft liegt neben der Tafel, unter demselben Pfad**
  (`XSLT_TRIP_REQUEST2` statt `XML_DM_REQUEST`) — abgeleitet aus
  `EfaStelle.adresse` und nicht als zweites Feld gepflegt. Datum und Uhrzeit
  reisen in der ÖRTLICHEN Zeit (`itdDate=20260919`, `itdTime=1300`), und
  **die Länge steht in der Anfrage zuerst**, wie bei der Tafel.
- **Beim Schweizer Dienst steht bei `from`/`to` die BREITE zuerst**, bei der
  Stationssuche dagegen ist `x` die Breite und `y` die Länge. Zwei
  Schreibweisen in einer Schnittstelle; wer sie verwechselt, fragt im Meer und
  bekommt eine leere Liste statt einer Fehlermeldung. Und `journey == nil`
  heißt Fußweg — das `walk`-Feld taugt dafür nicht, denn es trägt an manchen
  Fußwegen `duration: null`.
- **Der Reiseplaner der DEUTSCHEN BAHN ist kein Weg** (gemessen 18.09.2026,
  Frage des Nutzers). Vier Zugänge, vier Ergebnisse:
  - `www.bahn.de/web/api/reiseloesung/orte` und dasselbe unter `int.bahn.de`:
    **HTTP 403 mit `{"status":"ERROR","code":"OPS_BLOCKED"}`** — mit
    Browser-Kopfzeilen, mit Referer, gleich geblieben. Die Startseite derselben
    Adresse antwortet mit 200, es ist also DB, das die Schnittstelle abweist,
    und kein Netzproblem. Diese Schnittstelle ist nicht veröffentlicht; sie
    bedient die eigene Webseite und darf das.
  - **DB API Marketplace** (`apis.deutschebahn.com`): antwortet, verlangt aber
    Schlüssel und Konto (HTTP 401). Ein Schlüssel in einer App ist keiner.
  - `*.transport.rest` (HAFAS): **weiterhin 503**, bei v5 und v6, für DB, VBB
    und BVG — durchgehend seit dem Bau der App.
  - `app.vendo.noncd.db.de` und `reiseauskunft.bahn.de`: aus DIESER
    Bauumgebung nicht erreichbar (kein DNS-Eintrag, 502 am Proxy). **Nicht
    gemessen heißt nicht „geht nicht"** — es heißt, dass hier niemand
    nachsehen konnte, und ungemessen gehört keine Quelle in die Kette.
- **Was es an Alternativen zu Transitous gibt — gemessen 19.09.2026** (Frage
  des Nutzers): 
  - **EFA-Reiseplanung** bei den acht Stellen aus `EfaDienst.alle` — **seit
    1.1.1 gebaut**. Grenze: Sie gilt nur IM Verbundgebiet, deckt also keine
    Fahrt von Dortmund nach Köln ab.
  - **`transport.opendata.ch/v1/connections`** für die Schweiz — **seit 1.1.1
    gebaut**; ohne Streckengeometrie.
  - **`*.transport.rest` (HAFAS der Bahn)** wäre die einzige bundesweite
    Alternative und antwortete auch am 19.09.2026 mit **503** — bei `v5` und
    `v6`, für DB, VBB und BVG. Seit dem Bau der App durchgehend nicht
    erreichbar; als Rückfall taugt sie erst, wenn sie wieder antwortet.
  - **MOTIS ist quelloffen**, Transitous ist nur EINE öffentliche Instanz.
    Eine zweite Adresse hinter demselben `TransitousDienst` wäre der billigste
    Rückfall überhaupt — es gibt derzeit aber keine gemessene zweite Instanz
    mit DACH-Daten; ungemessen gehört keine in die Kette.
- **Die Ergebnisliste lädt sich NICHT von selbst nach**, anders als die Tafel.
  Eine Liste, die sich unter den Fingern neu sortiert, während jemand sie
  liest, ist keine Hilfe. Aufgefrischt wird durch Ziehen, und die Fußzeile
  nennt die Uhrzeit der Suche.
- **Die Linienschilder SIND die Ergebniszeile.** Wer zwischen fünf Vorschlägen
  wählt, entscheidet nach „S1 oder zweimal umsteigen" und nicht nach Minuten.
  Die Fußwege stehen als Gehsymbol dazwischen — ohne sie sähe ein Vorschlag mit
  zwanzig Minuten Fußweg aus wie einer, bei dem man am Bahnsteig gegenüber
  umsteigt.
- **Eine Verbindung mit ausfallendem Abschnitt wird GEZEIGT**, nicht
  weggelassen — mit rotem Band. Wer sie im Kopf hat, sucht sie sonst und hält
  die App für unvollständig. Dieselbe Regel wie beim entfallenden Halt.
- **Zwischenhalte stehen zugeklappt da.** Bei einer Fahrt über zwanzig
  Stationen wären sie der ganze Bildschirm; gesucht wird hier zuerst, wo man
  ein-, um- und aussteigt.
- **Fußwege sind gerechnet, nicht gemessen**, und das steht unter der Liste:
  Wie lange jemand wirklich braucht, hängt vom Gehtempo ab und davon, wo der
  Zugang zum Bahnsteig liegt. Ein Umstieg mit drei Minuten auf dem Papier kann
  in einem großen Bahnhof knapp werden.
- **`Verbindung` vergleicht sich über die KENNUNG.** Der erzeugte
  `Hashable`-Leser käme nicht durch — in den Abschnitten stecken
  `CLLocationCoordinate2D`, und die sind nicht `Hashable`. Gebraucht wird
  beides nur für `navigationDestination(for:)`.
- **Eine Kette für beide Bildschirme** (`AbfahrtstafelApp.dienst`). Zwei Ketten
  nebeneinander hieße zwei Zwischenspeicher und zwei Meinungen darüber, welcher
  Verbund gerade antwortet.
- **Mehrere Vorschläge auf EINER Karte** (`Views/VergleichsKarte.swift`, ab
  1.1.20, Ansage des Nutzers 09/2026: „Ich suche nach einer Möglichkeit, diese
  gemeinsam auf einer Karte anzeigen zu lassen, sodass man die Verläufe
  vergleichen kann … Auf jeden Fall möchte ich in einem Menü die einzelnen
  Verbindungen auf der Karte ein- und ausblenden können."). Die Liste sagt, wie
  lange etwas dauert und wie oft man umsteigt; sie sagt nicht, WO es langgeht.
  - **Drei Dinge sind auseinanderzuhalten, und jedes bekommt ein EIGENES
    Mittel**: das VERKEHRSMITTEL die Linienfarbe (wie überall in dieser App),
    die VERBINDUNG eine Nummer am Zug samt derselben Nummer in der Liste, und
    was gerade gemeint ist das Hervorheben. **Die Farbe kann die Verbindung
    nicht tragen** — sie ist schon für das Verkehrsmittel vergeben, und genau
    das wollte der Nutzer sehen („ob die Verbindung eine reine ICE-Verbindung
    ist oder fünfmal umsteigen bei Regionalbahnen bedeutet"). Dazu kommt: Zwei
    Vorschläge über dieselbe Strecke liegen ohnehin übereinander, eine zweite
    Farbe daneben verspräche eine Trennung, die es nicht gibt.
  - **Das Menü ist die Liste oben rechts** — aufklappbar wie die Legende der
    Netzkarte, und aus demselben Grund: Auf einem iPhone deckt sie sonst die
    Fläche zu, für die man sie öffnet. **Zwei Aufgaben, zwei Knöpfe**: Das
    Häkchen blendet ein und aus, ein Tipp auf die Zeile hebt hervor. Ein Tipp,
    der mal dies und mal jenes tut, ist für den Menschen davor kaputt.
  - **Die Schilderkette steht in der LISTE, nicht auf der Karte.** Auf der
    Karte wäre dafür kein Platz; gedeckelt auf sechs Schilder, der Rest wird
    gezählt. Kleiner gezeichnet wären sie genau dort unlesbar, wo sie
    gebraucht werden — dieselbe Rechnung wie beim Dauerbalken in 1.1.19.
  - **Umstiegspunkte nur bei der hervorgehobenen Verbindung.** Alle auf einmal
    wären dreißig Punkte, und die Frage „wo steige ich um" hat immer eine
    bestimmte Verbindung im Sinn.
  - **Gerahmt wird, was SICHTBAR ist**, und neu gerahmt beim Ein- und
    Ausblenden. Das widerspricht der Regel der Netzkarte nur scheinbar: Dort
    stellte sich die Karte über den Nutzer hinweg ein, weil eine Antwort aus
    dem Netz eintraf; hier ist der Auslöser sein eigener Tipp.
  - **Auf der Karte liegt kein Bedienelement** (Lehre aus 1.1.18) — alle
    Punkte `.allowsHitTesting(false)`.
  - **`linienzug` und `gestrichelt` sind ans MODELL gewandert**
    (`Verbindungsabschnitt`). Es gibt jetzt zwei Karten, die Verbindungen
    zeichnen; zwei Fassungen zeichneten irgendwann verschiedene Wege für
    dieselbe Fahrt.
- **Der Deutschland-Ticket-Filter gehört in die ANFRAGE, nicht in die Liste**
  (ab 1.1.20, Ansage des Nutzers 09/2026: „Es soll möglich sein, nur
  Verbindungen anzeigen zu lassen, die mit dem Deutschland-Ticket befahrbar
  sind."). **Gemessen 19.09.2026, Dortmund → München:** Ohne Einschränkung
  kamen fünf Vorschläge zurück, und in ALLEN fünf steckte ein ICE oder IC. Wer
  erst hinterher aussiebt, bekommt eine leere Liste und schließt daraus, es
  gebe keine Nahverkehrsverbindung — mit `transitModes` liefert dieselbe
  Strecke sechs Vorschläge aus lauter Regionalzügen (fünf bis sieben Umstiege,
  gut zehn Stunden statt knapp sechs).
  - **`transitModes` wirkt an `/plan` — an `/stoptimes` heißt derselbe Filter
    `mode`.** Gemessen am selben Tag: `mode=` und `modes=` werden von `/plan`
    mit HTTP 200 angenommen und **stillschweigend ignoriert** (die Antwort war
    Byte für Byte die ungefilterte, 457 412 B). Umgekehrt wirkt an
    `/stoptimes` nur `mode`. **Der Parametername ist je Endpunkt ein anderer,
    und ein falscher fällt nicht auf** — geprüft wird am INHALT der Antwort,
    nie am Status. Ein falscher WERT dagegen meldet sich: HTTP 400 samt
    Aufzählung aller gültigen (`ModeEnum`).
  - **`RAIL` steht bewusst NICHT dabei.** Es ist eine Obergruppe und holt
    Fern- und Hochgeschwindigkeitszüge zurück — nachgemessen an Dortmund →
    Köln, Hamburg → Berlin und München → Zürich: mit `RAIL` standen in jeder
    wieder ICE und IC in der Liste, ohne `RAIL` keine, bei gleicher Zahl an
    Vorschlägen. Dieselbe Falle wie an der Tafel, nur an der anderen
    Schnittstelle.
  - **Die Regel steht an EINER Stelle** (`Verkehrsmittel.imDeutschlandTicket`)
    und wird an zwei Enden gebraucht: für die Modi der Anfrage und für die
    Prüfung jeder Antwort. **Im Zweifel NICHT abgedeckt** — `sonstiges` und
    `faehre` fallen heraus. Die beiden Fehler sind nicht gleich schwer: Eine
    Verbindung zu viel wegzulassen kostet eine Auskunft, eine zu viel zu
    zeigen ein erhöhtes Beförderungsentgelt. (Manche Fähren SIND Nahverkehr —
    die HADAG gehört zum HVV —, aber welche, steht in keinem Feld.)
  - **`NIGHT_RAIL` lief bis 1.1.19 als Regionalzug mit** und ist jetzt
    Fernzug. Falsch war das schon auf dem Schild; mit dem Filter wäre es die
    teure Sorte falsch gewesen.
  - **Fragen kann nur Transitous.** Die Verbünde und der Schweizer Dienst
    kennen keinen gemessenen Parameter dafür, und eine geratene Einschränkung
    gehört in keine Anfrage — ihre Antworten siebt `Kettendienst.gesiebt`.
    Damit gilt die Zusage „in dieser Liste steht kein Fernverkehr" für JEDE
    Quelle. Bleibt nach dem Sieben nichts übrig, wird die nächste Quelle
    gefragt: Eine Quelle, die hier nur Fernverkehr kennt, ist für diese Frage
    dasselbe wie eine, die nichts gefunden hat.
  - **Was der Filter NICHT kann, steht unter der Liste.** Er kennt das
    VERKEHRSMITTEL, nicht das LAND: München → Zürich kommt mit
    Nahverkehrsmodi als vollständige Regionalzugverbindung zurück und ist ab
    der Grenze nicht im Deutschland-Ticket. Ausnahmen einzelner Linien stehen
    ebenfalls in keiner Quelle. Dieselbe Ehrlichkeit wie beim Wort „Plan".
  - **Nicht in den Voreinstellungen.** Wer ein Deutschland-Ticket hat, hat es
    dauerhaft — aber eine App, die beim nächsten Öffnen still die schnellen
    Verbindungen weglässt, sieht aus wie eine App, die sie nicht findet. Der
    Schalter steht sichtbar in der Leiste, und steht er an, nennt ihn auch die
    Meldung „nichts gefunden": Sonst liest sich die wie eine Aussage über den
    Fahrplan.
- **Nach VERKEHRSMITTELN filtern — und was dabei nicht geht** (`Verbindungsfilter`,
  ab 1.1.27, Ansage des Nutzers 09/2026: „Beim Verbindungsplaner möchte ich
  Verkehrsmittel filtern können: Bus, Tram, U, S, RE, RB, usw. Ich möchte z. B.
  einstellen können, dass eine Verbindung nur per Bus geschehen soll.").
  - **Der Filter wirkt je Modus und genau — gemessen 20.09.2026.** `BUS` gab in
    München nur Buslinien zurück, `SUBWAY` nur U-Bahnen, `TRAM` nur Trams,
    `BUS,TRAM` beides. München Hbf → Freising ohne Filter S-Bahn und
    Regionalzug, mit `BUS` eine vollständige Busverbindung über die Linie 635.
    **Die wäre durch nachträgliches Aussieben nie erschienen** — dieselbe
    Lehre wie beim Deutschland-Ticket in 1.1.20, und derselbe Grund, warum der
    Filter in die ANFRAGE gehört.
  - **RE und RB lassen sich NICHT trennen, und das steht in der App.**
    Nachgemessen an acht Strecken: Beide kommen als `mode = REGIONAL_RAIL` mit
    `routeType = 106` zurück, und MEX und DRF ebenso.
    `transitModes=REGIONAL_FAST_RAIL` und `REGIONAL_RAIL` gaben an Dortmund →
    Hamm Antworten von **gleicher Bytezahl** (107 340 B), und München →
    Nürnberg lieferte unter beiden auch RB16. Es gibt in diesen Daten kein
    Feld, an dem die Unterscheidung hinge. Der Unterschied existiert nur im
    LINIENNAMEN — und ihn dort auszulesen wäre nicht bloß Raten, sondern
    schädlich: Der Dienst sucht die schnellste Regionalverbindung, und wer
    davon die RB wegsiebt, bekommt eine leere Liste und schließt daraus, es
    führe keine. **Nicht nachrüsten, ohne zuerst an echten Antworten zu
    messen**, ob eine Quelle die Unterscheidung überhaupt herausgibt.
  - **`nil` und „alle acht" sind nicht dasselbe.** Ohne Einschränkung geht gar
    kein `transitModes` mit; wer stattdessen die volle Liste schickte, siebte
    still alle Fahrten aus, deren Art die App nicht kennt (`sonstiges`). Aus
    demselben Grund steht `sonstiges` nicht in `Verbindungsfilter.waehlbare` —
    „nur Sonstiges" ist kein Wunsch, den jemand hat.
  - **Die Abbildung für die ANFRAGE ist NICHT die Umkehrung der fürs Lesen.**
    In `verkehrsmittel(_:)` steht `RAIL` beim Regionalzug, weil eine Antwort so
    zurückkommen kann; in `motisModi` darf es nicht stehen, denn `RAIL` ist eine
    Obergruppe und holt ICE und IC zurück (gemessen 19.09.2026). Wer die beiden
    Listen zusammenzieht, macht aus „nur Regionalzug" eine Anfrage mit
    Fernverkehr.
  - **Ein Wert statt zweier Schalter.** Bis 1.1.26 reiste ein nacktes
    `nurNahverkehr: Bool` durch alle drei Protokolle; ein zweites Feld daneben
    hätte an sechs Stellen einzeln beachtet werden müssen. Die beiden
    Einschränkungen UNDen sich (`geltendeMittel`), und ein Widerspruch („nur
    Fernzug" plus Deutschland-Ticket) wird als SATZ beantwortet, bevor
    irgendjemand gefragt wird — eine Anfrage ohne ein einziges erlaubtes
    Verkehrsmittel brächte eine leere Liste, die wie eine Aussage über den
    Fahrplan aussähe.
  - **Fragen kann weiterhin nur Transitous**; die Verbünde und der Schweizer
    Dienst kennen keinen gemessenen Parameter dafür, ihre Antworten siebt
    `Kettendienst.gesiebt`. Damit gilt die Zusage für JEDE Quelle.
  - **Die Kapsel wird an EINER Stelle gezeichnet** (`Views/Mittelkapsel.swift`),
    von Tafel und Auskunft gemeinsam. Es sind zwei verschiedene Fragen mit
    derselben Bedienung — und genau so soll es sein; zwei Fassungen desselben
    Aussehens liefen auseinander. **Der Unterschied gehört trotzdem
    dazugesagt:** Auf der Tafel filtert die Leiste, was schon geladen ist, in
    der Auskunft löst sie eine neue Suche aus. Und sie bietet dort ALLE acht an
    und nicht nur die vorkommenden — vor der Suche gibt es keine Antwort, aus
    der sich ablesen ließe, was hier fährt.
- **Wie weit höchstens zu Fuß** (`Verbindungsfilter.hoechsterFussweg`, ab
  1.1.28, Ansage des Nutzers 09/2026: „Vielleicht ist es manchmal nötig, eine
  Strecke zu Fuß zu gehen, damit eine Verbindung zustandekommt. Ich möchte die
  maximale Länge dieser Strecke festlegen können.").
  - **Zwei Parameter wirken, fünf tun nichts — gemessen 21.09.2026 am INHALT
    der Antwort.** An Starnberg (Ortsrand) → München Hbf, einer Strecke mit
    Zugangswegen zwischen 334 und 796 m: `maxPreTransitTime` begrenzt den
    ERSTEN Weg (300 s ließ nur noch 334 m zu, 120 s gar keine Verbindung
    mehr), `maxPostTransitTime` den LETZTEN (120 s → jede Verbindung endete
    mit 136 m). **`maxWalkDistance`, `maxTransferTime`, `walkReluctance`,
    `maxMatchingDistance` und `maxTravelTime` lieferten alle fünf eine
    Antwort, die Byte für Byte der ungefilterten glich — mit HTTP 200.** Ein
    unbekannter Parametername fällt an dieser Schnittstelle nicht auf;
    dieselbe Falle wie bei `mode`/`transitModes`, und schon das dritte Mal.
  - **Von Haus aus gilt 900 Sekunden.** `maxPreTransitTime=900` war Byte für
    Byte die ungefilterte Antwort, 1800 gab andere Wege (1561 m statt 796 m).
    Wer nichts einstellt, hat also schon eine Grenze von gut einem Kilometer —
    das gehört gesagt, sonst hält man das Fehlen weiter Zugangswege für einen
    Fehler.
  - **Eine ZEITgrenze hält keine METERgrenze**, und das ist der Befund, der
    die Bauweise bestimmt: 888 s (aus 800 m gerechnet) gaben am Dortmunder
    Stadtrand Zugangswege von 983 m zurück, 555 s (aus 500 m) solche von
    626 m. Der Dienst rundet jede Gehdauer auf **volle Minuten** (gemessen:
    alle Dauern Vielfache von 60), und sein Tempo schwankt je Weg zwischen
    **0,93 und 1,48 m/s** (Mittelwert 1,17). **Deshalb beides:** Die Anfrage
    fragt großzügig (0,9 m/s, auf Minuten aufgerundet), und
    `Verbindungsfilter.passt` hält hinterher die Zahl, die auf dem Knopf
    steht. Wer nur die Zeit schickte, verspräche eine Zahl, die nicht gilt;
    wer nur siebte, verlöre Verbindungen, die gepasst hätten.
  - **Die Grenze gilt für die RÄNDER, nicht für Umstiegswege**
    (`Verbindung.randfusswege`). Ein Fußweg mitten in der Verbindung steht als
    Fußpfad im Fahrplan, lässt sich beim Dienst nicht begrenzen, und ihn
    wegzusieben nähme Verbindungen weg, ohne dass es eine Anfrage gäbe, die
    sie vermeidet. Die Fußzeile schreibt das hin — dieselbe Ehrlichkeit wie
    bei „Plan".
  - **Feste Stufen, kein Schieberegler.** Eine Grenze auf den Meter genau
    täuschte eine Genauigkeit vor, die es nicht gibt: Die gezeigte Länge ist
    der Weg, den der Dienst gerechnet hat, nicht der, den jemand wirklich
    geht.
  - **Sie ist die EINZIGE der drei Einschränkungen, die gemerkt wird.**
    Verkehrsmittel und Ticket gehören zur FAHRT, die Gehstrecke zur PERSON —
    wie weit jemand laufen kann, ändert sich nicht über Nacht. Die Sorge aus
    1.1.20 („eine App, die beim nächsten Öffnen still etwas weglässt") bleibt
    trotzdem beantwortet: Der Wert steht auf dem Knopf.
  - **Ein `didSet` läuft beim Initialisieren nicht mit** — nur deshalb kann
    `Verbindungsmodell.init` den gemerkten Wert setzen, ohne eine Suche
    auszulösen, bevor überhaupt ein Ziel dasteht. Dafür hat `filter` keinen
    Vorgabewert mehr und wird vollständig im `init` belegt.
- **Das LAND steht in der Haltestellenkennung — und nur dort**
  (`Model/Landkennung.swift`, ab 1.1.21, Ansage des Nutzers 09/2026: „Ich
  hätte gedacht, dass es irgendwo ein Verzeichnis gibt. So ist zum Beispiel
  komplett klar, dass eine Fahrt … von München nach Salzburg … auch auf
  österreichischem Gebiet vom Deutschlandticket abgedeckt wird.").
  - **Ein Tarifverzeichnis gibt es in den Daten NICHT** (nachgemessen
    19.09.2026): MOTIS kann GTFS-Fares, der DELFI-Datensatz trägt aber keine —
    `debugOutput.fares` steht auf 0, `agencyFareUrl` ist an jedem Abschnitt
    leer. **Das nicht als lösbar versprechen**, solange keine Quelle dafür
    gemessen ist.
  - **Gelesen wird der Landesvorsatz der Kennung**: `de-DELFI_de:09162:…`,
    `de-DELFI_at:45:50002` (Salzburg), `de-DELFI_NL:S:vl` (Venlo — GROSS
    geschrieben, also ohne Rücksicht auf Schreibweise vergleichen),
    `de-DELFI_nl:…` (Enschede), `ch:` (Basel).
  - **Zwei naheliegende Wege sind gemessen falsch, und beide in BEIDE
    Richtungen.** Erstens sagt der Datensatz vorn nicht das Land:
    `nl-OpenOV_2860697` ist „Aachen Hbf" und `be-sncb_8015345` ist „Aachen Hbf
    (DE)" — deutsche Bahnhöfe in fremden Datensätzen —, während
    `de-DELFI_000008101912` „Reutte in Tirol" ist, also Österreich im
    deutschen. Zweitens sind rein numerische Kennungen KEINE UIC-Nummern: Das
    sieht bestechend aus (Ehrwald `…008100089`, und 81 ist Österreich), aber
    „Finkenwerder" in Hamburg steht als `…015198010` und „Hannover
    Hauptbahnhof" als `…090031022`. **Wer hier eine Systematik erkennt, prüft
    sie an einem Gegenbeispiel, bevor er sie baut.**
  - **Unbekannt heißt unbekannt und nie „Deutschland".** Die Halte der
    Außerfernbahn (Ehrwald, Reutte) tragen im deutschen Datensatz numerische
    Kennungen; daraus „bleibt in Deutschland" zu machen, behauptete genau das
    Falsche. Die Zeile sagt in diesem Fall, dass das Land nicht feststellbar
    ist.
- **Die Grenzabschnitte sind eine LISTE mit Datum und Herkunft**
  (`Model/Grenzfall.swift`, ab 1.1.21). Weil es kein Verzeichnis zu holen
  gibt, steht sie von Hand da — kurz mit Absicht, denn jeder Eintrag ist eine
  Behauptung über einen Fahrschein.
  - **Die App sagt nie „gilt", sondern „steht in dieser Liste".** Tarife
    ändern sich zum Fahrplanwechsel, die Liste nicht von selbst. Dieselbe
    Regel wie beim Wort „Plan" an einer Abfahrt.
  - **`gesichert` trennt Bestätigtes von allgemein Bekanntem** — dieselbe
    Bauweise wie `Zugang.seiteGeprueft`. Bestätigt sind Freilassing –
    Salzburg Hbf und Emmerich – Arnhem Centraal (beides Ansagen des Nutzers,
    Arnheim aus eigener Fahrt); Kufstein, Venlo und Enschede stehen als
    ungeprüft drin und sagen das auch.
  - **Verglichen wird der GANZE Haltename, nicht ein Bruchstück** (ab
    1.1.22). Der erste Entwurf suchte Bruchstücke — und daran wäre genau der
    Fall gescheitert, um den es geht: „venlo" steckt auch in „Venlo,
    Koninginnesingel" und „arnhem" in „Arnhem Velperpoort", also in
    Stadtverkehr, der sicher nicht enthalten ist. Der Preis ist eine
    Schreibweise, die nicht greift; das ist die Richtung, in der ein Fehler
    nichts kostet.
  - **Die Halte eines Eintrags werden ABGEFRAGT, nicht geraten.**
    Nachgemessen 19.09.2026 an Düsseldorf → Arnheim: Die RE19 hält jenseits
    der Grenze zweimal — in Zevenaar und in Arnhem Centraal. Ohne den
    Zwischenhalt fiele jede Fahrt, die dort hält, in den vorsichtigen Zweig.
  - **Alle oder keiner**: Ein Eintrag zählt nur, wenn er JEDEN ausländischen
    Halt der Verbindung abdeckt. Eine Fahrt, die hinter Salzburg weiter nach
    Linz geht, ist keine Salzburgfahrt mehr.
  - **Ein Treffer neben unbekannten Halten ist kein glatter Treffer.**
    Gemessen an Mönchengladbach → Venlo: Der Zug endet in Venlo (Treffer),
    danach geht es mit einem niederländischen Stadtbus weiter, dessen Halte
    keinen Landesvorsatz tragen — und der Bus ist sicher nicht enthalten. Die
    Zeile hängt deshalb den Nachsatz an, statt „steht in der Liste" zu sagen.
  - **Basel steht bewusst NICHT drin.** „Basel Bad Bf" liegt im deutschen
    Tarifgebiet, „Basel SBB" nicht — beide tragen `ch:` und beide heißen
    „Basel". Ein Stichwort „basel" deckte also genau den Fall mit ab, der
    nicht gilt.
- **Die Dauer wird als BALKEN vergleichbar, nicht durch Stauchen der Schilder**
  (`Views/Dauerbalken.swift`, ab 1.1.19, Ansage des Nutzers 09/2026: „Es wäre
  schön, wenn man die angezeigten Verbindungen schnell hinsichtlich ihrer Dauer
  vergleichen könnte … die längste Verbindung geht vom Bildschirmrand zu
  Bildschirmrand, die anderen entsprechend kürzer."). Die Zahl rechts an der
  Zeile ist die Auskunft, aber kein Vergleich: Sechs Angaben untereinander muss
  man lesen und im Kopf voneinander abziehen.
  - **Die vorgeschlagene Form geht nicht auf — nachgezählt am Bildschirmfoto
    des Nutzers** (Duisburg Großenbaum, 19.09.2026): Die LÄNGSTE Verbindung
    (2 h 3 min) trug DREI Schilder, die KÜRZESTE (1 h 20 min) VIER. Auf 65 %
    der Breite gestaucht müsste die kürzeste schmaler sein als die längste und
    dabei ein Schild mehr tragen; es bliebe nur, die Schilder zu verkleinern
    oder abzuschneiden — und „die Linienschilder SIND die Ergebniszeile".
    **Merke: Bevor eine Länge etwas codiert, prüfen, ob der Inhalt in diese
    Länge passt.**
  - **Der Balken ist die Zeitachse DIESER Verbindung.** Jeder Abschnitt liegt
    an seiner echten Stelle (`start`/`ende`), die Lücken dazwischen sind die
    Wartezeit. Nur die Abschnitte zu zeichnen wäre falsch: Sie summieren sich
    NICHT zur Gesamtdauer — zwischen zwei Fahrten steht man am Bahnsteig, und
    in der gemeldeten Liste ist das ein gutes Viertel der Reise.
  - **Verglichen wird die LÄNGE, nicht die Uhrzeit.** Jeder Balken beginnt bei
    seiner eigenen Abfahrt. Eine gemeinsame Achse sagte zusätzlich, wer zuerst
    ankommt, schöbe aber jede spätere Verbindung nach rechts; bei anderthalb
    Stunden Spanne bliebe von den Balken wenig übrig. Die Fußzeile schreibt
    hin, welcher Vergleich gemeint ist.
  - **Maßstab ist die gezeigte LISTE** (`Verbindungsmodell.laengsteDauer`),
    keine feste Obergrenze: Mit „drei Stunden" als Maß wären sechs Vorschläge
    zwischen 80 und 123 Minuten sechs fast gleich lange Balken.
  - **Ein ausfallender Abschnitt wird blass, nicht rot.** Rot IST hier eine
    Linienfarbe (RE1); eine zweite Bedeutung daneben wäre nicht zu trennen.
    Gesagt wird der Ausfall ohnehin zweimal — als Band über der Zeile und als
    Kreuz am Schild.
  - **Für VoiceOver ausgeblendet.** Die Zeile nennt die Dauer bereits in
    Worten; „Balken, 65 Prozent" wäre eine zweite Ansage derselben Sache.
  - **Die Sorge um schmale Geräte erledigt sich damit von selbst**: Der Balken
    trägt keine Schrift und wird beliebig kurz, die Schilderkette liegt seit
    jeher in einer waagerecht scrollbaren Zeile. Ein senkrechtes Layout oder
    eine zweite Schiebefläche braucht es nicht.
  - **Die Musterdaten liefern seit 1.1.19 drei verschieden lange
    Verbindungen.** Vorher waren sie auf die Minute gleich und unterschieden
    sich nur in der Abfahrt — an ihnen ließ sich der Balken gar nicht ansehen.
    **Wer eine Anzeige baut, die Werte VERGLEICHT, prüft, ob die Musterdaten
    überhaupt etwas zu vergleichen hergeben.**

- `MARKETING_VERSION` und `CURRENT_PROJECT_VERSION` stehen an je zwei
  Stellen im pbxproj (Debug + Release) — KEINE Skript-Bauphase. **Jede
  Arbeitseinheit hebt Patch- UND Build-Nummer um je +1**, ohne Nachfrage,
  als Teil des PRs. Zählung ab 09/2026: 1.0.0 (Build 1), dann 1.0.1
  (Build 2), 1.0.2 (Build 3), 1.0.3 (Build 4), 1.0.4 (Build 5), 1.0.5 (Build 6),
  1.0.6 (Build 7), 1.0.7 (Build 8),
  1.0.8 (Build 9), 1.0.9 (Build 10), 1.0.10 (Build 11), 1.0.11 (Build 12) usw.
  **1.1.0 (Build 13) ist ein bewusster Sprung** (Ansage des Nutzers,
  09/2026): Die Verbindungsauskunft ist eine Funktionsfassung und keine
  zwölfte Nachbesserung — derselbe Gedanke wie bei Tafelbild 1.4.0 und
  Schulalarm 1.1.0. Die Marken ab 1.0.x in diesem Papier bleiben stehen;
  sie sagen, wann etwas in den Quelltext kam. Danach zählt es weiter:
  1.1.1 (Build 14), 1.1.2 (Build 15), 1.1.3 (Build 16), 1.1.4 (Build 17), 1.1.5 (Build 18), 1.1.6 (Build 19), 1.1.7 (Build 20), 1.1.8 (Build 21), 1.1.9 (Build 22), 1.1.10 (Build 23), 1.1.11 (Build 24), 1.1.12 (Build 25), 1.1.13 (Build 26), 1.1.14 (Build 27), 1.1.15 (Build 28), 1.1.16 (Build 29), 1.1.17 (Build 30), 1.1.18 (Build 31), 1.1.19 (Build 32), 1.1.20 (Build 33), 1.1.21 (Build 34), 1.1.22 (Build 35), 1.1.23 (Build 36), 1.1.24 (Build 37), 1.1.25 (Build 38), 1.1.26 (Build 39), 1.1.27 (Build 40), 1.1.28 (Build 41), 1.1.29 (Build 42), 1.1.30 (Build 43), 1.1.31 (Build 44), 1.1.32 (Build 45) … Dazu gesetzt (Ansage des Nutzers,
  09/2026): `DEVELOPMENT_TEAM = F4989GSTWS` — dieselbe Id wie Schulalarm und
  Tafelbild — und `INFOPLIST_KEY_LSApplicationCategoryType =
  public.app-category.navigation`. Beides steht als Build-Einstellung, weil
  das Ziel `GENERATE_INFOPLIST_FILE = YES` benutzt.
- `ITSAppUsesNonExemptEncryption = NO` steht in `Config/Info.plist` UND
  als Build-Einstellung — nicht entfernen.
- Das App-Symbol rechnet `AbfahrtstafeliOS/scripts/make-icon.py` (reines
  Python, ohne fremde Bibliotheken) — nicht von Hand bearbeiten.
- Übersetzt wird in GitHub Actions
  (`.github/workflows/ios-apps-build.yml`, Eintrag
  `("AbfahrtstafeliOS", "Abfahrtstafel")` in `welche-apps.py`). **Erst
  pushen, Bau abwarten, Fehler beheben — den PR-Link erst herausgeben,
  wenn der Bau grün ist.**
