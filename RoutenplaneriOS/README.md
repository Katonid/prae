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
– von meinem Standort", „Als Ziel" oder „Als Start". Das Autosymbol unten
blendet Apples Verkehrslage auf der Karte ein und aus.

Solange die App vorn ist, sperrt sich der Bildschirm nicht; im Hintergrund
gilt wieder die Einstellung des Geräts.

Profile (Fahrzeuge) lassen sich anlegen und bearbeiten. Ergebnis: Route auf
der Karte, Fahrzeit mit Posten (woher jede Minute kommt), Hinweise,
Verkehrsmeldungen, Wegbeschreibung, GPX-Ausgabe.

## Quellen (alle ohne Schlüssel, gemessen am 23.09.2026)

| Wofür | Dienst |
|---|---|
| Auto, zu Fuß (Rückfall Rad) | Valhalla, öffentlicher Server der FOSSGIS (`valhalla1.openstreetmap.de`) |
| Fahrrad | BRouter (`brouter.de`) mit eigenem Regelwerk (`BRouter.regelwerk`) |
| Verkehrsmeldungen | Autobahn GmbH (`verkehr.autobahn.de`) |
| Ortssuche | Apple (`MKLocalSearch`) |

## Was die App nicht kann — ehrlich

- Eine Durchfahrtshöhe oder -breite wird nur beachtet, wenn sie in
  OpenStreetMap eingetragen ist. Eine Unterführung ohne Eintrag gilt als frei.
- Das Gewicht wird nicht geprüft.
- Verkehrsmeldungen gibt es nur für Autobahnen. Ein Stau verlängert die
  Zeit, verlegt die Route aber nicht; Sperrungen und zu schmale Baustellen
  werden umfahren (Sperrfläche in beiden Richtungen).
- Die Aufschläge fürs Anfahren sind geschätzt, nicht gemessen.
- Die Verkehrslage auf der Karte ist Apples Anzeige und geht NICHT in die
  Berechnung ein — dafür liefert MapKit keine Daten heraus. In die Route
  gehen nur die Meldungen der Autobahn GmbH ein (Schalter „Meldungen").
- Es ist ein Planer, keine Navigation mit Sprachansage.
- **CarPlay geht nicht.** Eine Karten-App darf nur mit dem Entitlement
  `com.apple.developer.carplay-maps` auf CarPlay, und das bewilligt Apple
  auf Antrag — für Apps mit Zielführung Schritt für Schritt. Beides fehlt;
  ohne Bewilligung darf das Recht nicht in eine Entitlements-Datei, sonst
  lässt sich die App nicht mehr signieren.

## Bau

Übersetzt wird in GitHub Actions (`.github/workflows/ios-apps-build.yml`,
Eintrag `("RoutenplaneriOS", "Routenplaner")` in `welche-apps.py`).
Das App-Symbol rechnet `scripts/make-icon.py`.
