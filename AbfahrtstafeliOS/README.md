# Abfahrtstafel

Native iOS-App (SwiftUI, iOS 17, keine fremden Abhängigkeiten). Sie zeigt,
**was um einen Punkt herum gerade wegfährt** — mit Abfahrtszeit, Verspätung,
Minutenziffer, allen Zwischenhalten und der Strecke auf der Karte.

Der Punkt ist wahlweise der eigene Standort oder ein frei gewählter Ort.

Auf dem Homescreen heißt die App **Abfahrt** (iOS schneidet dort nach rund
zwölf Zeichen ab), Ordner, Ziel und Bundle-Id bleiben „Abfahrtstafel“ /
`de.familie.abfahrtstafel`.

## Was sie kann

- **Abfahrtstafel in der Nähe.** Alle Haltestellen im Umkreis in einer Liste,
  die nächste zuerst, je Haltestelle die nächsten Abfahrten. Umschaltbar auf
  „nach Zeit“ — dieselben Daten, eine Liste, chronologisch.
- **Verspätungen ehrlich.** Weicht die Echtzeitmeldung vom Fahrplan ab, steht
  die Planzeit durchgestrichen da, daneben `+3` und die neue Zeit. **Die
  geltende Zeit ist dabei nie die kleinere** — im Fahrtlauf steht sie groß und
  die durchgestrichene Planzeit klein darunter; gefahren wird nach der neuen.
  Liegt gar keine Echtzeitmeldung vor, steht **„Plan“** daneben — die App
  behauptet dann nichts über Pünktlichkeit.
- **Minutenziffer.** Rechts, groß, mit gleich breiten Ziffern; unter zwei
  Minuten orange. Sie zählt im Sekundentakt weiter, aus **einer** Uhr für die
  ganze Liste.
- **Der ganze Lauf einer Fahrt.** Ein Tipp auf eine Abfahrt zeigt Start- und
  Endhaltestelle und **alle Zwischenhalte** mit Ankunfts- und Abfahrtszeit,
  eigener Einstieg hervorgehoben, schon zurückgelegte Halte blass.
- **Die Strecke auf der Karte.** Der wirkliche Linienweg, nicht die Luftlinie
  — sofern der Fahrplandienst ihn mitschickt. Tut er es nicht, zeichnet die
  Karte die Verbindung der Halte **gestrichelt** und schreibt darunter, dass
  es die Luftlinie ist.
- **Freier Punkt.** Ortssuche, gemerkte Haltestellen, oder ein Fadenkreuz auf
  der Karte („wie sieht es dort aus, wo ich morgen hinmuss?“). Die Karte
  beginnt beim **zuletzt gewählten Ort** — vor dem eigenen Standort, und
  unabhängig davon, wie lange das her ist. Unter dem Knopf steht, wo sie
  aufgehen wird.
- **Liniennetz auf der Karte.** Die Verläufe aller Linien, die hier
  verkehren, übereinandergelegt — gefiltert mit derselben Leiste wie die
  Liste. Ein Tipp in der Legende hebt eine Linie hervor, die anderen treten
  zurück (sie verschwinden nicht: Wer eine Linie verfolgt, will sehen, wo sie
  die anderen kreuzt). Höchstens zwölf Linien, ein Lauf je Linie.
  Dazu die **Halte der gezeichneten Linien** als kleine Punkte in der Farbe
  ihrer Linie, die Endpunkte größer; ist eine Linie hervorgehoben, stehen
  ihre Haltestellennamen dabei. Auf dem Zug selbst liegt die
  **Liniennummer** als Schild — und wo der Verbund keine eigene Linienfarbe
  führt, wird die Farbe des Verkehrsmittels je Linie leicht abgewandelt, damit
  zwölf Striche übereinander auseinanderzuhalten sind.
  Die **Legende lässt sich ausblenden** (Pfeil in ihrer Kopfzeile); zurück holt
  sie ein kleiner Knopf an derselben Stelle. Hervorheben geht dann weiter über
  die Liniennummern auf der Karte — die sind Knöpfe. Unter der Karte steht
  **eine** Hinweiszeile — die wichtigste; der Knopf daneben klappt die übrigen
  auf.
- **Entfallende Halte.** Fährt eine Linie eine Umleitung, kommt das als
  Merkmal am einzelnen Halt aus den Daten (`cancelled`, oder Ein- UND Ausstieg
  verboten). Der Halt steht dann durchgestrichen im Fahrtlauf und **rot
  durchgestrichen auf beiden Karten** — mit Namen, auch wenn sonst keine
  Beschriftung steht. Betrifft es die eigene Haltestelle, fällt die Abfahrt in
  der Tafel aus. **Der gezeichnete Linienweg bleibt der planmäßige**, und
  genau das steht dabei: Welchen Weg das Fahrzeug stattdessen fährt, gibt
  keine Quelle heraus.
- **Betriebsmeldungen.** Umleitung, Sperrung, verlegte Haltestelle,
  Ersatzverkehr — als Band über der Tafel, als Dreieck neben der betroffenen
  Linie und als Liste mit Volltext. Sie kommen **ausschließlich vom Verbund
  vor Ort**: Die Quelle der Abfahrtszeiten führt keine einzige.
- **Merkliste** für die Handvoll Haltestellen des Alltags — auf dem Gerät,
  ohne Konto.

## Verbindungsauskunft

Der zweite Reiter beantwortet die andere Hälfte der Frage: nicht „was fährt
hier weg", sondern **„wie komme ich dorthin"**.

- **Vorschläge beim Tippen.** Ab drei Zeichen — darunter antwortet die Quelle
  gar nicht, und die App schreibt hin, wie viele Zeichen noch fehlen, statt
  eine leere Liste zu zeigen.
- **Zuerst das Nahe.** Vorgeschlagen wird, was um den Startpunkt herum liegt:
  um den eigenen Standort, oder — sobald ein Start eingetippt ist — um diesen.
  **Weiter entfernte Ziele bleiben trotzdem erreichbar**; dafür laufen zwei
  Abfragen nebeneinander (siehe unten).
- **Haltestellen und Adressen**, und was ein Treffer ist, steht an der Zeile.
- **Alternativen**: bis zu sechs Vorschläge mit Abfahrt, Ankunft, Dauer,
  Umstiegen, Fußweg und den Linien als Schilderkette.
- **Jetzt, oder zu einer Zeit** — wahlweise als Abfahrt oder als **Ankunft**
  („ich muss um neun da sein" ist die häufigere Frage).
- **Im Einzelnen**: jeder Abschnitt mit Ein- und Ausstieg, aufklappbaren
  Zwischenhalten, entfallenden Halten und allen Teilstrecken auf einer Karte;
  Fußwege gepunktet. Von dort führt ein Weg in den ganzen Linienlauf.
- **Die Liste lädt sich NICHT von selbst nach.** Eine Ergebnisliste, die sich
  unter den Fingern neu sortiert, während jemand sie liest, ist keine Hilfe.

### Was die Ortssuche gelernt hat (gemessen 19.09.2026)

`/geocode` kennt `placeBias`, und der wirkt kräftig. Zwei Fallen stecken darin:

- **`type=STOP` schaltet den Ortsbezug aus.** Mit beiden zusammen gab „kle" bei
  Dortmund wieder Paris und Tschechien. Gefragt wird deshalb ohne `type`, und
  die Haltestellen werden in der App herausgesucht. (Bis 1.0.10 stand genau
  diese Kombination im Quelltext, mit einem Kommentar, der das Gegenteil
  behauptete — die Haltestellensuche war nie örtlich.)
- **Mit Ortsbezug ist die Ferne unerreichbar.** „Köln Hbf" gab bei Dortmund den
  Dortmunder Hauptbahnhof zurück. Eine Auskunft, die Köln nicht findet, ist
  keine. Deshalb läuft eine zweite Abfrage ohne Ortsbezug nebenher; beide
  Listen werden zusammengeführt.

## Auf dem iPad

Eine `List` füllt, was da ist — im Querformat sind das gut zweitausend Punkte,
und die Zeile wird von der Breite auseinandergezogen statt sie zu benutzen
(gemeldet 09/2026). Zwei Dinge dagegen:

- **Liste und Karte stehen nebeneinander**, sobald die Breitenklasse `regular`
  ist. Die Liste bekommt eine begrenzte Spalte, die Karte den Rest — Karten
  gewinnen durch Fläche, Abfahrtszeilen nicht.
- **Jede Zeile hat eine Lesebreite** (`Views/Lesebreite.swift`, 760 Punkte,
  mittig). Sie liegt auf der GANZEN Zeile und nicht auf ihrem Inhalt: Bei
  einem Verweis stünde der Pfeil sonst weiter ganz außen. Auf dem iPhone ist
  sie wirkungslos.

## Der Umschalter

Unter der Ortsleiste steht eine Segmentleiste: **Haltestellen | Zeit |
Karte**. Sie steht IM INHALT und nicht in der Werkzeugleiste (ab 1.0.5,
gemeldet 09/2026: „Ich kann die Karte bei der Darstellung auf dem iPhone
nirgends finden."). Auf dem iPad fiel das nicht auf, weil die Karte dort von
Haus aus neben der Liste steht; auf dem iPhone lag sie hinter einem Symbol,
das niemand aufklappt. **Ein Knopf, den niemand findet, ist kein Knopf.**

„Karte" heißt auch auf dem iPad: die ganze Breite fürs Liniennetz, ohne Liste
daneben.

## Woher die Daten kommen

Eine **Kette aus drei Stufen** (`Fahrplan/Kettendienst.swift`). Eine
Abfahrtstafel wird an einer Haltestelle aufgeschlagen, oft mit einem Balken
Empfang — genau dort ist eine einzelne Quelle ein einzelner Ausfallpunkt.

| # | Quelle | Deckung | Echtzeit |
| --- | --- | --- | --- |
| 1 | **Transitous** (MOTIS) | DE, AT, CH + große Teile Europas | wo der Verbund sie herausgibt |
| 2 | **Verbund vor Ort** (EFA / opendata.ch) | wo einer antwortet | ja |
| 3 | **Zwischenspeicher** | zuletzt geholter Stand | nein — und das steht dabei |

**Stufe 1 trägt die App.** Sie liefert Haltestellen, Abfahrten, Zwischenhalte
und die Strecke auf der Karte — überall. Stufe 2 ist ein Netz darunter, kein
Ersatz: Wo kein Verbund zuständig ist, fehlt nichts, was Stufe 1 nicht schon
hätte. Zeilen aus Stufe 2 stehen ohne Pfeil da, weil diese Schnittstellen
keinen Fahrtlauf herausgeben.

### Was in Stufe 2 steht — jede Zeile gemessen

Angefragt am 18.09.2026 mit einer echten Koordinatenabfrage; aufgenommen wurde
nur, was Abfahrten **mit Echtzeit** zurückgab.

| Quelle | Gebiet | Ergebnis der Messung |
| --- | --- | --- |
| MVV | Großraum München | 6 Abfahrten, 6 mit Echtzeit |
| Bayern-Fahrplan | ganz Bayern | Nürnberg, Würzburg, Augsburg, Regensburg: je 7–10 von 8–10 |
| VRR | Rhein-Ruhr, Niederrhein | 6 / 5 |
| VVS | Region Stuttgart | 6 / 5 |
| DING | Ulm, Donau-Iller | 6 / 6 |
| VRN | Rhein-Neckar | 6 / 6 |
| VVO | Dresden, Oberelbe | 6 / 6 |
| efa-bw | ganz Baden-Württemberg | 6 / 6 |
| opendata.ch | Schweiz | Zürich, Bern, Basel, Genf — durchweg Echtzeit |

Die Reihenfolge ist Absicht: **erst örtlich, dann weiträumig.** Für Stuttgart
und Ulm antworten sowohl der örtliche Verbund als auch das landesweite
`efa-bw`; der örtliche kennt seine Stadtbusse besser.

**Die Liste ist ausdrücklich nicht vollständig.** Sie muss es nicht sein —
fehlt ein Verbund, bleibt es dort bei Stufe 1.

### Österreich

Stufe 1 deckt Österreich ab (Haltestellen, Abfahrten, Zwischenhalte, Karte).
Die **Echtzeit ist dort regional verschieden** — gemessen am 18.09.2026:
Graz 11 von 12 Abfahrten mit Echtzeit, Wien, Linz und Innsbruck keine,
Salzburg eine von zehn. Wo sie fehlt, steht „Plan" an der Zeile.

Eine zweite Quelle gibt es dort **nicht**, und zwar aus einem ehrlichen Grund:
Die EFA-Stellen von VVT, OÖVV, SVV und VOR waren aus der Bauumgebung nicht
erreichbar (Verbindungsabbruch bzw. 502 am Proxy). Ungeprüfte Adressen kommen
hier nicht hinein — eine Quelle, die niemand gemessen hat, ist in einer Kette
kein Rückfall, sondern nur eine zusätzliche Wartezeit davor.

**[Transitous](https://transitous.org)**, angesprochen über die
MOTIS-Schnittstelle v1 (`https://api.transitous.org/api/v1`).

Warum diese Quelle:

- **Kein Schlüssel, kein Konto.** Alles andere hieße, ein Geheimnis in die App
  zu legen — und was in einer App liegt, ist kein Geheimnis.
- **Ganz Deutschland in einem Topf** (DELFI, also die Fahrpläne aller
  Verbünde) und dazu große Teile Europas. Eine Lösung je Verbund wäre eine
  Liste, die niemand pflegt.
- **Echtzeit ist dabei**, wo der Verbund sie herausgibt (GTFS-RT).
- **Die Streckengeometrie kommt mit.** Ohne sie gäbe es die Kartenansicht
  dieser App nicht.

Die Schnittstelle der Bahn (`v6.db.transport.rest`, HAFAS) wäre die
naheliegende Alternative und war beim Bau nicht erreichbar (HTTP 503 über
Stunden). Genau dafür gibt es das Protokoll unten.

### Drei Abfragen, mehr nicht

| Was | Endpunkt |
| --- | --- |
| Nächste Haltestelle zu einem Punkt | `GET /reverse-geocode?place=<lat>,<lon>&type=STOP` |
| Abfahrten (samt Umkreis) | `GET /stoptimes?stopId=…&radius=…&n=…&time=…` |
| Lauf einer Fahrt samt Strecke | `GET /trip?tripId=…` |

Der **Umkreis an `/stoptimes`** ist der Grund, warum die Tafel mit einer
einzigen Abfrage fertig ist: Der Dienst liefert die Abfahrten aller
Haltestellen im Umkreis mit. Eine Abfrage je Haltestelle wären zehn Anfragen,
und die Liste baute sich ruckweise auf.

## Aufbau

```
Abfahrtstafel/
  Model/          Haltestelle, Abfahrt, Fahrt, Verkehrsmittel, AppModel
  Fahrplan/       Fahrplandienst + Abfahrtsquelle (Protokolle),
                  Kettendienst, Musterdienst
    Transitous/   die einzige Stelle, die MOTIS kennt
    Efa/          die einzige Stelle, die EFA kennt (+ Tabelle der Verbünde)
    Schweiz/      die einzige Stelle, die opendata.ch kennt
  Dienste/        Standort, Uhrwerk, Merkliste, Abfahrtsspeicher
  Views/          Tafel, Haltestelle, Fahrt, Karte, Ortswahl, Einstellungen
```

**Alles Fahrplan-Nahe liegt hinter `Fahrplandienst`.** Das ist kein
Stilwunsch: Öffentliche Fahrplanschnittstellen werden abgeschaltet, verlangen
plötzlich einen Schlüssel oder decken eine Gegend nicht ab. Solange die
Ansichten nur dieses Protokoll kennen, kostet ein Wechsel **eine Datei**.
`Musterdienst` ist der laufende Beweis, dass die Trennung hält — steckte in
einer Ansicht ein JSON-Feld von Transitous, ließe er sich nicht übersetzen.

**Daneben steht `Abfahrtsquelle` — mit Absicht ein zweites Protokoll.** Nicht
jede Quelle kann alles: EFA liefert eine vorzügliche Abfahrtstafel, aber keine
Streckengeometrie, und eine Fahrt ohne Strecke hat in dieser App keinen
Bildschirm. Sie als `Fahrplandienst` auszugeben hieße, vier Methoden zu
versprechen und zwei davon mit „geht nicht“ zu beantworten; das ist keine
Trennung, sondern eine Lüge mit Protokoll. Die Ansichten sehen weiterhin nur
`Fahrplandienst` — `Kettendienst` fügt beides zusammen.

## Grenzen, die die App auch selbst nennt

- **Entfernungen sind Luftlinien**, keine Fußwege. Ein Fußweg bräuchte je
  Haltestelle eine Routing-Abfrage und wäre trotzdem geraten, solange niemand
  weiß, wo der Zugang liegt. Die Beschriftung sagt „Luftlinie“.
- **Der Umkreis gilt um die nächstgelegene Haltestelle**, nicht um den Punkt
  selbst — so fragt der Dienst. Auf dem Land kann die nächste Haltestelle weit
  weg sein; der Kreis liegt dann dort.
- **Mitten im Feld gibt es gar nichts.** Die Haltestellensuche des Dienstes
  reicht rund einen Kilometer weit (nachgemessen 09/2026); weiter draußen
  liefert sie eine leere Liste. Die App sagt das dann so und bietet die
  Ortswahl an, statt einen zweiten Versuch vorzuschlagen, der nichts ändern
  könnte.
- **Echtzeit gibt es nur, wo der Verbund sie herausgibt.** Und auch eine
  Echtzeitmeldung ist eine Meldung, keine Zusage.
- Kein Verbindungsauskunft-Teil („von A nach B“). Diese App beantwortet
  „was fährt hier weg und wohin“ — und das vollständig.
- **Der Zwischenspeicher ist kein Netzersatz.** Er greift erst, wenn keine
  Quelle mehr antwortet, hält höchstens zwei Stunden, und seine Zeiten sind
  immer als alt gekennzeichnet — mit Uhrzeit, und **ohne laufende
  Minutenziffern**. Eine alte Tafel, die weiterzählt, sähe richtig aus und
  wäre es nicht.
- **Der eingestellte Umkreis erreicht die EFA-Schnittstellen nicht.** Sie
  kennen keinen Umkreisparameter und nehmen ihren eigenen; eine Tafel aus
  einer solchen Quelle kann deshalb schmaler ausfallen als die eingestellten
  Meter.
- **Nicht jede Zeile lässt sich öffnen.** Die Schnittstellen der Verbünde geben
  eine Abfahrtstafel heraus, aber keinen Fahrtlauf mit Zwischenhalten; solche
  Zeilen stehen ohne Pfeil da.
- **Betriebsmeldungen gibt es nur dort, wo ein Verbund zuständig ist.** Die
  erste Quelle führt keine (nachgemessen 18.09.2026: weder an den Abfahrten
  noch am Fahrtlauf). Steht in der App keine Meldung, heißt das deshalb
  **nicht**, dass alles planmäßig fährt — es heißt, dass niemand
  nachgesehen hat. Die App schreibt genau das hin.
- **In Österreich gibt es keine zweite Quelle** und regional keine Echtzeit —
  siehe oben. Die App sagt das an der Zeile („Plan"), statt es zu verwischen.

## Bauen

Übersetzt wird in GitHub Actions
(`.github/workflows/ios-apps-build.yml`, Eintrag
`("AbfahrtstafeliOS", "Abfahrtstafel")` in `.github/scripts/welche-apps.py`),
gegen das iOS-Simulator-SDK und ohne Signierung.

Das App-Symbol rechnet `scripts/make-icon.py` (reines Python, ohne fremde
Bibliotheken) — nicht von Hand bearbeiten.

## Versionierung

`MARKETING_VERSION` und `CURRENT_PROJECT_VERSION` stehen an je zwei Stellen im
pbxproj (Debug + Release); es gibt keine Skript-Bauphase. **Jede
Arbeitseinheit hebt Patch- UND Build-Nummer um je +1.** Zählung ab 09/2026:
1.0.0 (Build 1), dann 1.0.1 (Build 2), 1.0.2 (Build 3), 1.0.3 (Build 4), 1.0.4 (Build 5),
1.0.5 (Build 6), 1.0.6 (Build 7), 1.0.7 (Build 8), 1.0.8 (Build 9), 1.0.9 (Build 10), 1.0.10 (Build 11), 1.0.11 (Build 12) …

`ITSAppUsesNonExemptEncryption = NO` steht in `Config/Info.plist` und als
Build-Einstellung — nicht entfernen.
