# Anstoß — Liveticker für die fünf großen Ligen

Native iOS-App (SwiftUI, iOS 17, keine fremden Abhängigkeiten) für
Bundesliga, Premier League, La Liga, Serie A und Ligue 1.

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
    Beispieldaten.swift     erfundene Daten für den Beispielmodus
  Views/
    Startsicht.swift        drei Bereiche (Ticker, Ligen, Einstellungen)
    Tickersicht.swift       Liveticker
    Ligensicht.swift        Menü der fünf Ligen
    Ligasicht.swift         Spieltag blättern / Tabelle
    Tabellensicht.swift     Tabelle
    Spielsicht.swift        einzelne Begegnung
    Spielzeile.swift        Begegnung als Listenzeile
    Willkommenssicht.swift  Einrichtung beim ersten Start
    Einstellungssicht.swift Schlüssel, Beispielmodus, Auskunft
    Gestaltung.swift        Wappen, Ligazeichen, Formkurve
```

Das App-Symbol erzeugt `scripts/anstoss-icon.py` — nicht von Hand
bearbeiten.

## Versionierung

`MARKETING_VERSION` steht an zwei Stellen im pbxproj (Debug + Release).
Jede Arbeitseinheit hebt die Patch-Nummer um +1 an.
