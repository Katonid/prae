# Routenplaner

Native iOS-App (iPhone + iPad, iOS 17, keine fremden Abhängigkeiten), die
Routen für das Fahrzeug plant, mit dem man wirklich unterwegs ist:

- **Auto** — mit Höhe und Breite (Gespann: 3,20 m / 2,50 m), Anhängertempo
  (80 km/h, Autobahn 100 mit Tempo-100-Zulassung) und Aufschlägen fürs
  Anfahren. Verkehrsmeldungen der Autobahn GmbH (Sperrungen, Baustellen mit
  Durchfahrtsbreite, Staus) werden berücksichtigt.
- **Fahrrad** — der kürzeste ERLAUBTE Weg, Belag egal. Autobahnen,
  Kraftfahrstraßen und Wege mit Radverbot sind ausgeschlossen. Gehwege und
  Fußgängerzonen dürfen wahlweise schiebend benutzt werden; sie stehen
  gestrichelt orange auf der Karte. Der Schalter „Schieben erlaubt / Ohne
  Schieben" steht im Bedienfeld; ohne Schieben werden Gehwege,
  Fußgängerzonen und Treppen ohne Radfreigabe umfahren.
- **Zu Fuß**.

Start und Ziel lassen sich eintippen (Knöpfe unten) oder auf der Karte
antippen: Die Karte lässt sich frei schieben, ein Tipp fragt „Route hierhin
– von meinem Standort", „Als Ziel" oder „Als Start".

**Jede Planung bringt Alternativen mit** (ab 1.0.4): Unter der Karte stehen
bis zu drei, beim Auto mit einer Stauumfahrung vier Vorschläge zur Wahl; die
gewählte Route ist blau, die übrigen liegen grau darunter. Beim Auto steht die
SCHNELLSTE vorn — gerechnet MIT dem Zeitverlust aus den Staumeldungen der
Autobahn GmbH, nicht in der Reihenfolge des Dienstes, der ohne Verkehrslage
rechnet. Liegt auf ihr ein Stau ab 10 Minuten, fragt die App eigens nach einem
Weg, der die Mitte des Staus meidet, und stellt ihn als weiteren Vorschlag
daneben („um den Stau"). Beim Rad und zu Fuß steht die kürzeste vorn.

Der Ebenen-Knopf oben links an der Karte (ab 1.0.3) wählt:

- **Karte**: Apple Karten, Apple Satellit, OpenStreetMap, CyclOSM (Radwege,
  Radstreifen und Belag gezeichnet), OpenTopoMap (Gelände).
- **Helligkeit**: wie das Gerät, hell oder dunkel — wirkt nur auf Apples
  Karte; die freien Kacheln gibt es nur hell.
- **Einblenden**: Radwege (CyclOSM als durchsichtige Schicht über jeder
  Karte), ausgeschilderte Radrouten (Waymarked Trails), den Belag der
  berechneten Radroute (farbig, samt Kilometern je Belag) und Apples
  Verkehrslage (nur auf Apples Karte).

**Strecke aufzeichnen** (ab 1.0.5): der runde Knopf unter dem Ebenen-Knopf.
Gemessen wird so genau, wie das Gerät es kann — GPS dauernd an
(`BestForNavigation`), jede Messung (meist eine je Sekunde), kein
automatisches Anhalten beim Stehen — und ohne Rücksicht auf den Akku. Die
Aufzeichnung läuft im Hintergrund und bei gesperrtem Bildschirm weiter (blaues
Zeichen in der Statusleiste). Im Bedienfeld stehen Zeit, Strecke, die
Genauigkeit der letzten Messung, Tempo, Pause und Beenden. Jeder Punkt wird
sofort auf die Platte geschrieben; wird die App mittendrin beendet, lässt sich
die Fahrt beim nächsten Öffnen fortsetzen. Gesicherte Fahrten stehen unter
„Aufgezeichnete Strecken": auf der Karte zeigen (violett), als GPX (mit Zeit
und Höhe) weitergeben, umbenennen, löschen.

Solange die App vorn ist, sperrt sich der Bildschirm nicht; im Hintergrund
gilt wieder die Einstellung des Geräts.

Profile (Fahrzeuge) lassen sich anlegen und bearbeiten. Ergebnis: Route auf
der Karte, Fahrzeit mit Posten (woher jede Minute kommt), Hinweise,
Verkehrsmeldungen, Wegbeschreibung, GPX-Ausgabe.

## Quellen (alle ohne Schlüssel, gemessen am 23.09.2026)

| Wofür | Dienst |
|---|---|
| Auto, zu Fuß (Rückfall Rad), Alternativen über `alternates` | Valhalla, öffentlicher Server der FOSSGIS (`valhalla1.openstreetmap.de`) |
| Fahrrad | BRouter (`brouter.de`) mit eigenem Regelwerk (`BRouter.regelwerk`), Alternativen über `alternativeidx` 1 und 2 |
| Verkehrsmeldungen | Autobahn GmbH (`verkehr.autobahn.de`) |
| Ortssuche | Apple (`MKLocalSearch`) |
| Aufzeichnung | das GPS des Geräts — nichts verlässt das Gerät, außer man gibt die GPX-Datei weiter |
| Kartenkacheln | OpenStreetMap, CyclOSM (auch „lite" als Radweg-Schicht), OpenTopoMap, Waymarked Trails |

Alle Kachelquellen antworteten am 23.09.2026 ohne Schlüssel mit PNG
256 × 256. Geholt wird nach der OSM-Richtlinie: eigener User-Agent,
Zwischenspeicher (256 MB, Verfallszeiten des Servers), höchstens zwei
Verbindungen je Server, kein Vorausladen. Der Lizenzhinweis steht unten
rechts auf der Karte und lässt sich nicht abschalten.

**OpenCycleMap fehlt mit Absicht.** Thunderforest antwortete zwar auch ohne
Schlüssel, die Bedingungen verlangen aber einen — und ein Schlüssel in einer
App ist keiner. CyclOSM zeigt dasselbe (Radinfrastruktur, Belag) frei. Wer
einen eigenen Thunderforest-Schlüssel hat, bekäme ein Eingabefeld dafür (im
Schlüsselbund, nie im Repo).

## Was die App nicht kann — ehrlich

- Eine Durchfahrtshöhe oder -breite wird nur beachtet, wenn sie in
  OpenStreetMap eingetragen ist. Eine Unterführung ohne Eintrag gilt als frei.
- Das Gewicht wird nicht geprüft.
- Verkehrsmeldungen gibt es nur für Autobahnen. Staus zählen in Fahrzeit und
  Reihenfolge; ab 10 Minuten kommt ein Umfahrungsvorschlag dazu (Schwelle
  gewählt, nicht gemessen). Gemieden wird ein Kästchen von rund 250 m um die
  MITTE des Staus, in beiden Richtungen — die Umfahrung kann also einen
  Bogen um eine Stelle machen, an der in der eigenen Richtung gar nichts
  steht, und sie meidet nicht den ganzen Stau, nur seine Mitte. Ob sie sich
  lohnt, zeigt der Zeitvergleich. Sperrungen und zu schmale Baustellen werden
  immer umfahren. Meldungen ohne Zeitangabe zählen NICHT in die Zeit; die App
  sagt dann, wie viele es sind.
- Die Staumeldungen sind der Stand beim Rechnen. Bis man an der Stelle ist,
  kann sich der Stau aufgelöst haben oder einer dazugekommen sein.
- Die Aufschläge fürs Anfahren sind geschätzt, nicht gemessen.
- Die Verkehrslage auf der Karte ist Apples Anzeige und geht NICHT in die
  Berechnung ein — dafür liefert MapKit keine Daten heraus. In die Route
  gehen nur die Meldungen der Autobahn GmbH ein (Schalter „Meldungen").
- Der Belag steht nur dort, wo er in OpenStreetMap eingetragen ist
  (`surface`); „nicht eingetragen" heißt nicht „asphaltiert". Gerechnet
  wird die Radroute weiterhin OHNE Rücksicht auf den Belag.
- Es ist ein Planer, keine Navigation mit Sprachansage.
- **Aufzeichnung:** In die Strecke gehen nur Messungen mit ±30 m oder besser
  ein, und weitergezählt wird erst, wenn die Bewegung größer ist als die
  Messunsicherheit (sonst wüchse die Strecke an jeder Ampel). Beide Regeln
  sind gewählt, nicht gemessen. Die Datei behält jede Messung. Wird die App
  vom System ganz beendet (Neustart, leerer Akku, weggewischt), hört die
  Aufzeichnung auf — iOS kann sie nur mit der Erlaubnis „Immer" neu starten,
  und die fragt die App nicht an. Im Tunnel gibt es keine Messungen; die
  Linie springt dort gerade durch.
- **CarPlay geht nicht.** Eine Karten-App darf nur mit dem Entitlement
  `com.apple.developer.carplay-maps` auf CarPlay, und das bewilligt Apple
  auf Antrag — für Apps mit Zielführung Schritt für Schritt. Beides fehlt;
  ohne Bewilligung darf das Recht nicht in eine Entitlements-Datei, sonst
  lässt sich die App nicht mehr signieren.

## Bau

Übersetzt wird in GitHub Actions (`.github/workflows/ios-apps-build.yml`,
Eintrag `("RoutenplaneriOS", "Routenplaner")` in `welche-apps.py`).
Das App-Symbol rechnet `scripts/make-icon.py`.
