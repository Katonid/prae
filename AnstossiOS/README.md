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
- **Torjäger** — Liste je Liga mit Toren, Spielen, Vorlagen und
  Elfmetern. Das Einzige an Spielerdaten, das der freie Zugang hergibt.
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

**Auswechslungen.** Kein freier Weg gefunden.

**Platzverweise.** Der Schalter dafür war bis 1.0.6 da und löste nie etwas
aus; in 1.0.7 ist er raus. Nachtrag zur Begründung: Dort stand, es gebe
Karten nirgends frei — **das war falsch**, TheSportsDB führt sie in seiner
Zeitleiste. Wieder eingebaut sind sie trotzdem nicht, denn der
Fünf-Ereignis-Deckel derselben Quelle macht sie unzuverlässig. Was zu einem
Platzverweis bekannt wird, läuft über die Ligameldungen (Art „Spielbericht
& Analyse").

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
| Torfolge mit Schütze und Minute | football-data.org; ersatzweise **OpenLigaDB** (Bundesliga) und **TheSportsDB** (alle fünf Ligen) |
| Spielverlauf mit Minute und Stand | aus dem **eigenen Mitschnitt** — funktioniert immer, auch ohne Namen |
| Tabellenplatz, Bilanz und Formkurve beider Mannschaften | aus der geladenen Tabelle — kostet keine zusätzliche Abfrage |
| Heim- bzw. Auswärtsbilanz der jeweiligen Mannschaft | steckt in derselben Tabellenantwort — kostet nichts extra |
| Direkter Vergleich (Begegnungen, Siege, Remis, Tore) | **eigene** Unterabfrage `/matches/{id}/head2head`, nur beim Öffnen einer Begegnung |
| Torjägerliste je Liga | `/competitions/{code}/scorers`, erst beim Ansehen |
| Spielort, Schiedsrichter | football-data.org, soweit vorhanden |
| Aufstellung mit Formation, Bank und Trainer | **api-football**, zweiter und wahlfreier Schlüssel |
| Auswechslungen, Karten | **gibt es nicht** — siehe unten |

Die Spielansicht sagt selbst dazu, woher die Torfolge stammt und was fehlt.

### Torschützen: zwei freie Quellen nacheinander

**OpenLigaDB** zuerst — kennt nur die Bundesliga, gibt dafür die
vollständige Torfolge her. Danach **TheSportsDB** für alles Übrige.

TheSportsDB (`Spielereignisdienst.swift`, freie Kennung `123`, 30 Abfragen
je Minute, eigenes Kontingent) deckt **alle fünf Ligen** ab und liefert
schon während das Spiel läuft — Schütze, Vorlage, Minute und Seite.

**Der Deckel gehört dazu:** Die freie Stufe gibt je Spiel nur die **ersten
fünf Ereignisse** heraus, und Karten zählen mit. Fällt das vierte Tor spät,
steht es nicht in der Liste. Deshalb ergänzt diese Quelle nur *Namen*; wann
welches Tor fiel, weiß die App aus dem eigenen Mitschnitt ohnehin. Sagt der
Spielstand mehr Tore, als Namen vorliegen, schreibt die Spielansicht das
dazu.

### Spielverlauf aus dem eigenen Mitschnitt

Unabhängig von allen Quellen führt die App Buch: Jeder Abruf wird mit dem
vorigen verglichen, jede Standänderung wandert in den Ticker. Die
Spielansicht zeigt daraus den Verlauf mit Minute und Zwischenstand — das
funktioniert auch dann, wenn niemand den Torschützen nennt. Wie fein er
ausfällt, hängt davon ab, wie oft die App nachsehen durfte; das sagt sie
auch dazu.

### Zur alten Bundesliga-Quelle: OpenLigaDB

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

## Aufstellungen: der zweite, wahlfreie Schlüssel

Aufstellungen stehen auf jeder Nachrichtenseite — weil die ihre Daten
einkaufen (Opta, Sportradar, dpa). Frei zugänglich sind sie fast nirgends;
geprüft 08/2026:

| Quelle | Aufstellungen? |
| --- | --- |
| football-data.org, freier Zugang | nein — kostenpflichtige Stufe |
| OpenLigaDB | nein, führt sie gar nicht |
| TheSportsDB, freie Stufe | `lookuplineup.php` gibt **fünf** Namen heraus — im Test alle von derselben Mannschaft. Unbrauchbar. |
| **api-football (API-Sports)** | **ja, im kostenlosen Tarif** — 100 Abfragen am Tag |

Deshalb: ein **zweiter, wahlfreier** Schlüssel unter *Einstellungen →
Aufstellungen*. Ist er hinterlegt, zeigt die Spielansicht Startelf mit
Rückennummern und Positionen, Formation, Ersatzbank und Trainer. Ist er es
nicht, **passiert gar nichts** — die App bleibt genau so, wie sie ohne
diesen Dienst wäre.

Weil 100 Abfragen am Tag knapp sind, ist der Dienst durchweg sparsam:

- Gefragt wird **nur beim Öffnen einer Begegnung**, nie im Ticker.
- Jede Antwort wird gemerkt — vor dem Anpfiff eine Viertelstunde (die
  Aufstellung ändert sich noch), danach einen Tag.
- Die App **zählt selbst mit**, wie viele Abfragen der Tag noch hergibt,
  und hört mit Sicherheitsabstand vor der Grenze auf. Der Reststand steht
  in den Einstellungen.

Aufstellungen erscheinen üblicherweise etwa eine Stunde vor dem Anpfiff;
vorher sagt die App das auch.

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
    Schluesselbund.swift    beide Zugangsschlüssel im Keychain
    Meldungen.swift         Wunsch: Arten, Ligen, einzelne Spiele
    Benachrichtiger.swift   örtliche Mitteilungen und Anpfiff-Wecker
    Tickerwerk.swift        Standvergleich + Standspeicher (geteilt)
    Torschuetzendienst.swift Torschützen der Bundesliga von OpenLigaDB
    Spielereignisdienst.swift Torschützen aller fünf Ligen von TheSportsDB
    Aufstellungsdienst.swift Aufstellungen von api-football (wahlfrei)
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
    Torjaegersicht.swift    Torjägerliste einer Liga
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
(Build 2), 1.0.5 (Build 3), 1.0.6 (Build 4), 1.0.7 (Build 5),
1.0.8 (Build 6), 1.0.9 (Build 7), 1.0.10 (Build 8) usw.

Hintergrund: App Store Connect nimmt keinen Build an, dessen Nummer
nicht höher ist als die des vorherigen.

## Export-Compliance

`INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` steht in beiden
Konfigurationen. Die App bringt keine eigene Verschlüsselung mit; ohne
diesen Eintrag fragt App Store Connect bei jedem TestFlight-Build
danach. Nicht entfernen.
