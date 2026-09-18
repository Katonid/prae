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
  die Planzeit durchgestrichen da, daneben `+3` und die neue Zeit. Liegt gar
  keine Echtzeitmeldung vor, steht **„Plan“** daneben — die App behauptet dann
  nichts über Pünktlichkeit.
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
  der Karte („wie sieht es dort aus, wo ich morgen hinmuss?“).
- **Merkliste** für die Handvoll Haltestellen des Alltags — auf dem Gerät,
  ohne Konto.

## Woher die Daten kommen

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
  Fahrplan/       Fahrplandienst (Protokoll), Musterdienst
    Transitous/   die einzige Stelle, die die Schnittstelle kennt
  Dienste/        Standort, Uhrwerk, Merkliste
  Views/          Tafel, Haltestelle, Fahrt, Karte, Ortswahl, Einstellungen
```

**Alles Fahrplan-Nahe liegt hinter `Fahrplandienst`.** Das ist kein
Stilwunsch: Öffentliche Fahrplanschnittstellen werden abgeschaltet, verlangen
plötzlich einen Schlüssel oder decken eine Gegend nicht ab. Solange die
Ansichten nur dieses Protokoll kennen, kostet ein Wechsel **eine Datei**.
`Musterdienst` ist der laufende Beweis, dass die Trennung hält — steckte in
einer Ansicht ein JSON-Feld von Transitous, ließe er sich nicht übersetzen.

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
1.0.0 (Build 1), dann 1.0.1 (Build 2) …

`ITSAppUsesNonExemptEncryption = NO` steht in `Config/Info.plist` und als
Build-Einstellung — nicht entfernen.
