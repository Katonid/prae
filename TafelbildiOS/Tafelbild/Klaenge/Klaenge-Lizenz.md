# Klänge der App

Zwei Gruppen, auf zwei verschiedenen Wegen entstanden: Die Klänge beim
Ziehen sind echte Aufnahmen, die Endklänge des Timers sind gerechnet.
Warum das kein Widerspruch ist, steht weiter unten.

## Klänge beim Ziehen

Echte Aufnahmen, keine Synthese. Alle Quellen sind **gemeinfrei**
(CC0 1.0 bzw. Public Domain) — auch kommerziell nutzbar, ohne Pflicht
zur Namensnennung.
Genannt werden sie hier trotzdem; das gehört sich.

| Klang | Datei | Urheber | Lizenz | Nachweis |
|---|---|---|---|---|
| Kartenmischen | `zieh-karten.wav` | Kenney Vleugels (kenney.nl), Paket „Casino Audio“ | CC0 1.0 | https://kenney.nl/assets/casino-audio |
| Trommelwirbel | `zieh-trommel.wav` | Iwan Sounds and DIY | CC0 1.0 | https://commons.wikimedia.org/wiki/File:Drum_Roll_Intro.ogg |
| Glücksrad | `zieh-rad.wav` | Kenney Vleugels (kenney.nl), Paket „Interface Sounds“ | CC0 1.0 | https://kenney.nl/assets/interface-sounds |
| Kärtchen rastet ein (Karten) | `karte-karten-*.wav` | Kenney Vleugels (kenney.nl), Paket „Casino Audio“ | CC0 1.0 | https://kenney.nl/assets/casino-audio |
| Kärtchen rastet ein (Rad) | `karte-rad-*.wav` | Wikimedia Commons, „Tools Ratchet“ | CC0 1.0 | https://commons.wikimedia.org/wiki/File:Tools_Ratchet.ogg |
| Kärtchen rastet ein (Trommel) | `karte-trommel-*.wav` | Iwan Sounds and DIY | CC0 1.0 | https://commons.wikimedia.org/wiki/File:Drum_Roll_Intro.ogg |
| Zähler hoch (Kassenglocke) | `zaehler-hoch.wav` | SoundBible (über Wikimedia Commons) | gemeinfrei | https://commons.wikimedia.org/wiki/File:Cash_register.ogg |
| Zähler runter (Auswischen) | `zaehler-runter.wav` | Kenney Vleugels (kenney.nl), Paket „Interface Sounds“ | CC0 1.0 | https://kenney.nl/assets/interface-sounds |

Die `zieh-*.wav` sind auf einen Kanal gemischt, auf die Länge eines
Zuges (1,72 s plus Nachklang) zugeschnitten und auf gleichen Pegel
gebracht. Die `karte-*.wav` sind kurze Einzelklänge (höchstens 0,5 s):
Beim Auslosen von Gruppen bekommt jedes Kärtchen einen davon, in dem
Augenblick, in dem es stehen bleibt.

**Nicht von Hand bearbeiten** — `TafelbildiOS/scripts/fetch-sounds.py`
holt und erzeugt sie.

## Endklänge des Timers

`endklang-*.wav` — **im Gerät gerechnet**, keine fremden Dateien, keine
Lizenzfragen. Erzeugt von `TafelbildiOS/scripts/make-endklaenge.py`.

| Klang | Datei | Grundlage |
|---|---|---|
| Handglocke | `endklang-glocke.wav` | Teiltöne einer Glocke: Hum, Prime, Terz, Quinte, Nominal |
| Glockenspiel | `endklang-glockenspiel.wav` | Frei schwingender Stab, drei Töne aufwärts (c''' e''' g''') |
| Triangel | `endklang-triangel.wav` | Gebogener Stab — unharmonische Moden ohne Tonhöhe |
| Klangschale | `endklang-klangschale.wav` | Aufgespaltene Moden, daher das Schweben |
| Gong | `endklang-gong.wav` | Platte mit vielen dichten Moden, lange Abklingzeit |
| Klingel | `endklang-wecker.wav` | Kleine Glocke, elf Schläge in der Sekunde |
| Piepton | `endklang-piep.wav` | Drei reine Töne mit weicher Hülle |

**Warum hier gerechnet und dort aufgenommen wird.** Bei den Ziehklängen
steht oben das Gegenteil — Synthese klang synthetisch. Das galt für
Kartenmischen, Trommelwirbel und Ratsche: Vorgänge aus hundert kleinen
Zufälligkeiten, die sich nicht nachrechnen lassen.

Ein angeschlagenes Metall ist das Gegenteil davon. Sein Klang **ist**
eine Summe exponentiell abklingender Teiltöne auf den Eigenfrequenzen
des Körpers; die Frequenzverhältnisse einer Glocke sind seit
Jahrhunderten vermessen, die eines Stabes stehen in jeder
Akustik-Formelsammlung. Wer sie richtig addiert, bekommt keinen Ersatz
für eine Aufnahme, sondern denselben Vorgang.

Alle Dateien sind Mono, 44,1 kHz, 16 Bit und auf gleiche **Lautheit**
gebracht (gemessen im lautesten Fenster von 300 ms, nicht am
Spitzenwert). **Nicht von Hand bearbeiten.**
