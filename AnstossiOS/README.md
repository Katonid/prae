# Anstoß — Liveticker für die fünf großen Ligen

Native iOS-App (SwiftUI, iOS 17, keine fremden Abhängigkeiten) für
Bundesliga, Premier League, La Liga, Serie A und Ligue 1.

## Namen

| wo | Name |
| --- | --- |
| Homescreen (`INFOPLIST_KEY_CFBundleDisplayName`) | **Anstoß** |
| App Store, Feld „Name" (max. 30 Zeichen) | **Anstoß – Liveticker** |
| App Store, Feld „Untertitel" (max. 30 Zeichen) | **Top-Ligen unter Beobachtung** |
| Ordner, Target, Bundle-Id, Schlüsselbund | `Anstoss` / `de.familie.anstoss` |

„Anstoß" allein ist im App Store schon vergeben — deshalb der Zusatz im
Store-Namen. Auf dem Homescreen bleibt es beim kurzen Wort, weil iOS
dort nach rund zwölf Zeichen abschneidet.

Der App-Eintrag wird in App Store Connect **von Hand** angelegt (Meine
Apps → +). Xcodes „Create App Record" im Distribute-Ablauf schlägt den
Anzeigenamen vor und läuft damit erneut in den Namenskonflikt; steht
der Eintrag dagegen schon, lädt Distribute einfach in ihn hinein.

## Was die App kann

- **Liveticker** — alle heutigen Begegnungen der fünf Ligen auf einem
  Blatt. Laufende Spiele stehen oben, darunter laufen die Meldungen
  (Anpfiff, Tor, Halbzeit, Abpfiff) in zeitlicher Reihenfolge. Filter je
  Liga, zum Aufräumen ein „Meldungen löschen“.
- **Ligen** — jede Liga mit einer Leiste zum Blättern durch alle
  Spieltage (Pfeile links/rechts oder Auswahlmenü) und mit Umschalter
  zur **Tabelle** samt Platzierung, Spielen, Tordifferenz, Punkten und
  Formkurve der letzten fünf Spiele.
- **Spielansicht** — Anzeigetafel, Torfolge (soweit der Dienst sie
  hergibt), Halbzeitstand und Eckdaten.
- **Ligameldungen** — Transfers, Gerüchte, Ausfälle und Vereinsthemen
  aus freien Nachrichtenquellen, filterbar nach Art und Liga.

## Mitteilungen

Pro Begegnung freischaltbar (Glocke in der Spielansicht) oder gleich für eine
ganze Liga. Welche Ereignisse gemeldet werden, ist einzeln einstellbar:
Anpfiff, Tor, Platzverweis, Halbzeit, Abpfiff — dazu eine Erinnerung vor dem
Anpfiff mit wählbarem Vorlauf.

**Es sind örtliche Mitteilungen, keine echten Push-Nachrichten.** Die App hat
keinen Server; sie fragt football-data.org mit dem Schlüssel des Nutzers.
Mitteilungen entstehen deshalb dort, wo die App den Spielstand vergleicht:

| Lage | Wie schnell |
| --- | --- |
| Ticker-Ansicht offen | alle 45 Sekunden — praktisch sofort |
| App geschlossen | wenn iOS eine Hintergrund-Auffrischung gewährt: eine Viertelstunde bis mehrere Stunden |
| aus dem App-Umschalter geschoben, Stromsparmodus | gar nicht |
| Erinnerung vor dem Anpfiff | auf die Minute — iOS stellt den Wecker, die Anstoßzeit steht vorher fest |

Die Rechnung selbst steckt im `Tickerwerk` und läuft im Vorder- wie im
Hintergrund gleich; verglichen wird gegen den gesicherten `Standspeicher`.
Weil die Kennung einer Mitteilung die der Tickermeldung ist, kann dasselbe
Ereignis nicht zweimal auf dem Sperrbildschirm landen.

### Was es bewusst NICHT gibt

**Platzverweise.** In 1.0.5/1.0.6 stand dafür ein Schalter, der nie etwas
auslöste: Karten gehören bei football-data.org zu den kostenpflichtigen
Stufen. Geprüft wurde, ob eine freie Quelle einspringen kann — OpenLigaDB
führt keine Karten, TheSportsDB ebenso wenig. Also ist der Schalter in 1.0.7
wieder raus. Was zu einem Platzverweis bekannt wird, läuft über die
Ligameldungen (Art „Spielbericht & Analyse").

## Ligameldungen (Transfer, Gerüchte, Ausfälle)

football-data.org kennt nur Spieldaten — Transfers und Gerüchte stehen dort
nirgends. Dafür liest die App zwei frei zugängliche RSS-Ausgaben:

| Quelle | Adresse | Schwerpunkt |
| --- | --- | --- |
| kicker — Fußball | `newsfeed.kicker.de/news/fussball` | alles |
| kicker — Bundesliga | `newsfeed.kicker.de/news/bundesliga` | Bundesliga, dichter |
| kicker — Champions League | `newsfeed.kicker.de/news/champions-league` | Europapokal |
| Transfermarkt | `transfermarkt.de/rss/news` | Wechsel und Gerüchte |

Kein Schlüssel, keine Anmeldung. Gelesen werden Überschrift, Anriss, Verweis,
Zeit und Schlagworte — **keine ganzen Texte**; zum Lesen führt ein Tippen zur
Quelle. Geholt wird höchstens alle zehn Minuten (`Nachrichtenpflege`), im
Vordergrund beim Öffnen der Meldungsliste, im Hintergrund bei jeder
Auffrischung.

**Einteilung.** Die Art einer Meldung — Aufstellung & Vorbericht, Transfer,
Gerücht, Verletzung & Sperre, Spielbericht & Analyse, Rund um den Verein,
Sonstiges — schätzt `Nachrichtensieb` anhand der
Wortwahl in Überschrift und Anriss. Die Reihenfolge zählt: Ein Gerücht ist
auch ein Transfer, geht aber als Gerücht durch. Das trifft meistens, nicht
immer — die App sagt das in der Oberfläche auch.

**Ligazuordnung.** Zuerst über die Schlagworte der Quelle (der kicker liefert
Wettbewerb und Verein mit), dann über den Text, zuletzt über das
`Vereinsverzeichnis`. Das füllt sich von selbst aus den Tabellen und
Spieltagen, die die App ohnehin lädt — dadurch braucht es keine Namensliste im
Quelltext, die jeden Sommer veraltet. Ließ sich keine Liga erkennen, bleibt
sie offen; gemeldet wird das nur, wenn „Auch ohne erkennbare Liga“ an ist
(sonst käme jede Regionalligameldung durch).

Der allererste Durchgang füllt nur den Bestand und meldet nichts — sonst
kämen auf einen Schlag zwanzig Mitteilungen. Je Durchgang klingeln höchstens
vier, und zwar lautlos (`interruptionLevel = .passive`).

`Config/Info.plist` trägt dafür `BGTaskSchedulerPermittedIdentifiers` (Kennung
muss zu `Hintergrundpflege.kennung` passen) und `UIBackgroundModes = fetch`.

## Was zu einem Spiel angezeigt wird

| Angabe | Herkunft |
| --- | --- |
| Spielstand, Halbzeit, Minute, Zustand | football-data.org |
| Torfolge mit Schütze und Minute | football-data.org; für die **Bundesliga** ersatzweise **OpenLigaDB** |
| Tabellenplatz, Bilanz und Formkurve beider Mannschaften | aus der geladenen Tabelle — kostet keine zusätzliche Abfrage |
| Direkter Vergleich (Begegnungen, Siege, Remis, Tore) | kommt mit der Abfrage zum einzelnen Spiel mit |
| Spielort, Schiedsrichter | football-data.org, soweit vorhanden |
| Aufstellung, Auswechslungen, Karten | **gibt es nicht** — kostenpflichtige Stufen |

Die Spielansicht sagt selbst dazu, woher die Torfolge stammt und was fehlt.

### Torschützen für die Bundesliga: OpenLigaDB

Weil der freie Zugang die Torfolge oft nicht mitliefert, fragt
`Torschuetzendienst.swift` bei fehlender Torfolge **OpenLigaDB** —
schlüssellos, mit eigenem Kontingent, das **nicht** gegen die zehn Abfragen
je Minute von football-data.org zählt. Geliefert werden Schütze, Minute,
Elfmeter und Eigentor.

Zugeordnet wird über vereinfachte Vereinsnamen (klein, ohne Umlaut­besonder­
heiten, ohne Kürzel wie „FC"): **beide** Mannschaften müssen passen. Ein
falsch zugeordneter Torschütze wäre schlimmer als gar keiner. Für die vier
anderen Ligen ist keine vergleichbare freie Quelle bekannt — dort bleibt es
beim Rückfall aus dem Sprung im Spielstand.

## Woher die Daten kommen

Die App fragt **football-data.org** (Fassung v4). Der kostenlose Zugang
deckt genau diese fünf Ligen ab. Beim ersten Start führt die App durch
die Anmeldung; der Schlüssel landet im **Schlüsselbund** des Geräts,
nicht in den Voreinstellungen.

Der freie Zugang erlaubt **zehn Abfragen je Minute**. Darum:

- Eine einzige Abfrage holt die heutigen Spiele **aller fünf** Ligen.
- Eine Bremse (`Anfragenbremse`) hält das Limit selbst ein, statt sich
  auf Fehler 429 zu verlassen.
- Läuft gerade ein Spiel, frischt der Ticker alle 45 Sekunden auf, sonst
  alle fünf Minuten — und nur, solange die Ticker-Ansicht sichtbar ist.
- Spieltage und Tabellen liegen im Zwischenspeicher (60 bzw. 120
  Sekunden), Ziehen zum Aktualisieren erzwingt einen neuen Abruf.

Der freie Zugang liefert keine Torschützen zu jedem Spiel. Fehlen sie,
**baut die App den Ticker selbst**: Sie vergleicht jeden Abruf mit dem
vorigen und schreibt aus jedem Sprung im Spielstand eine Tormeldung.

## Ohne Zugangsschlüssel

Über „Beispieldaten“ lässt sich alles ansehen, ohne Zugang und ohne
Netz: erfundene, in sich stimmige Spielpläne, Tabellen und Ticker,
überall klar gekennzeichnet.

## Aufbau

```
Anstoss/
  AnstossApp.swift          Einstieg
  Model/
    Liga.swift              die fünf Ligen (Rohwert = Wettbewerbscode)
    Modelle.swift           Spiel, Tabelle, Tickermeldung, Zeitformate
    FussballDienst.swift    Zugriff auf football-data.org v4 + Bremse
    Datenhaltung.swift      Zwischenspeicher, Ticker-Erkennung, Abruf
    Schluesselbund.swift    Zugangsschlüssel im Keychain
    Meldungen.swift         Wunsch: Arten, Ligen, einzelne Spiele
    Benachrichtiger.swift   örtliche Mitteilungen und Anpfiff-Wecker
    Tickerwerk.swift        Standvergleich + Standspeicher (geteilt)
    Torschuetzendienst.swift Torschützen der Bundesliga von OpenLigaDB
    Nachrichten.swift       Art, Quellen, Vereinsverzeichnis, Ablage
    Nachrichtendienst.swift RSS lesen + ein Durchgang für beide Wege
    Hintergrundpflege.swift Nachsehen, während die App geschlossen ist
    Beispieldaten.swift     erfundene Daten für den Beispielmodus
  Views/
    Startsicht.swift        vier Bereiche (Ticker, Ligen, Meldungen, Einstellungen)
    Tickersicht.swift       Liveticker
    Ligensicht.swift        Menü der fünf Ligen
    Ligasicht.swift         Spieltag blättern / Tabelle
    Tabellensicht.swift     Tabelle
    Spielsicht.swift        einzelne Begegnung
    Spielzeile.swift        Begegnung als Listenzeile
    Willkommenssicht.swift  Einrichtung beim ersten Start
    Meldungssicht.swift     Einstellungen für Mitteilungen
    Nachrichtensicht.swift  Ligameldungen mit Filter nach Art und Liga
    Einstellungssicht.swift Schlüssel, Beispielmodus, Auskunft
    Gestaltung.swift        Wappen, Ligazeichen, Formkurve
```

Das App-Symbol erzeugt `scripts/anstoss-icon.py` — nicht von Hand
bearbeiten.

## Versionierung

`MARKETING_VERSION` und `CURRENT_PROJECT_VERSION` stehen an je zwei
Stellen im pbxproj (Debug + Release); es gibt keine Skript-Bauphase,
beide Werte werden im Repo gepflegt. **Jede Arbeitseinheit hebt beide
um +1 an** — Fassung und Build-Nummer. Zählung ab 08/2026: 1.0.4
(Build 2), 1.0.5 (Build 3), 1.0.6 (Build 4), 1.0.7 (Build 5) usw.

Hintergrund: App Store Connect nimmt keinen Build an, dessen Nummer
nicht höher ist als die des vorherigen.

## Export-Compliance

`INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` steht in beiden
Konfigurationen. Die App bringt keine eigene Verschlüsselung mit; ohne
diesen Eintrag fragt App Store Connect bei jedem TestFlight-Build
danach. Nicht entfernen.
