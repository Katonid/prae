# Projekt Routenplaner (Auto/Gespann, Fahrrad, zu Fuß — native iOS-App)

> Ausgelagert aus der `CLAUDE.md` im Wurzelverzeichnis (09/2026). Die
> übergreifenden Regeln (PR-Rhythmus, iOS-Pflichten, Bau in GitHub
> Actions) stehen weiterhin dort und gelten hier genauso.


- App-Code: `RoutenplaneriOS/` (ein Target: App, iPhone + iPad, iOS 17, keine
  fremden Abhängigkeiten), Bundle-Id `de.familie.routenplaner`, Homescreen-Name
  „Routenplaner". Ausführlich: `RoutenplaneriOS/README.md`. Anlass (Ansage des
  Nutzers, 09/2026): Keine Routen-App plant für ein Gespann mit 2,50 m Breite
  und 3,20 m Höhe, rechnet Anhängertempo ein oder findet den kürzesten
  ERLAUBTEN Radweg.
- **Drei Dienste, alle ohne Schlüssel, jeder an echten Antworten gemessen
  (23.09.2026):** Valhalla (FOSSGIS) für Auto und zu Fuß, BRouter für das
  Rad, Autobahn GmbH für Verkehrsmeldungen. Ein Schlüssel in einer App ist
  keiner — dieselbe Regel wie in der Abfahrtstafel.
- **Gespann = Valhallas PKW-Profil mit `height`/`width`, NICHT das
  Lkw-Profil.** Gemessen: `auto` mit 9 m × 6 m wählt einen anderen Weg (49,9
  statt 48,1 km), die Maße wirken also. Das Lkw-Profil meidet zusätzlich
  Lkw-Verbote, die für Pkw mit Wohnwagen gar nicht gelten.
- **Die Fahrzeit rechnet die App selbst**, aus `trace_attributes` (Klasse,
  Tempo, Tempolimit, Bebauungsdichte je Stück): Anhänger außerorts 80,
  Autobahn 80/100, dazu Innerorts- und Abbiegeaufschlag aus dem Profil. Sie
  steht in POSTEN da, jede Zeile mit Grund; die Zeit des Dienstes daneben zum
  Vergleich. Die Aufschläge und die Innerorts-Schwelle (Dichte ≥ 11) sind
  gewählt, nicht gemessen — und stehen deshalb im Profil, nicht im Quelltext.
- **Mit dem Rad fährt Valhalla NIE über einen Gehweg ohne Radfreigabe**
  (gemessen in der Dortmunder Fußgängerzone — es fährt drumherum). Schieben
  kennt es nicht; es ist deshalb nur Rückfall, und das steht dann in der App.
- **BRouters „shortest" reichte NICHT:** Es hält `highway=pedestrian` für
  befahrbar. Das eigene Regelwerk (`BRouter.regelwerk`) sperrt Gehweg,
  Fußgängerzone, Treppe und Reitweg für Räder, solange nichts anderes
  eingetragen ist, und schaltet Schieben über `profile:schieben` ein und aus.
  Gemessen: 895 m mit, 1345 m ohne Schieben. Hochgeladen wird es über
  `POST /brouter/profile`; die Kennung verfällt, dann wird neu hochgeladen.
- **`BRouter.einordnen` ist dieselbe Regel noch einmal auf App-Seite** und
  entscheidet, was „Schieben" heißt. Wer das Regelwerk ändert, ändert beides —
  liefen sie auseinander, stünde eine Schiebestrecke als Fahrstrecke da.
  Geprüft: Ohne Schieben ordnet die App 0 m als Schieben ein.
- **BRouters eigene Zeit taugt nicht** (641 s für 895 m bei „shortest").
- **`WayTags` nennt nur Merkmale, die das Regelwerk benutzt.** `name=` und
  `ref=` kennt BRouter nicht einmal als Suchbegriff (Hochladefehler „unknown
  lookup name").
- **Verkehrsmeldungen nur für Autobahnen, und das steht in der App.**
  `isBlocked` kommt als TEXT, `future` als Wahrheitswert; `CLOSURE` sperrt,
  `CLOSURE_ENTRY_EXIT` ist nur eine Auf-/Abfahrt. Baustellen nennen
  „Maximale Durchfahrtsbreite" — ist das Fahrzeug breiter, wird umfahren wie
  bei einer Sperrung. Zugeordnet wird eine Meldung über Anfang, Mitte und
  Ende (je höchstens 60 m von der Route) und die RICHTUNG über die Reihenfolge,
  in der die Route an Anfang und Ende vorbeikommt. Umfahren wird über
  `exclude_polygons` (gemessen: wirkt), ein Kästchen von rund 250 m — es
  sperrt beide Richtungen, und die Detailansicht sagt das. Ein Stau
  verlängert die Zeit, verlegt die Route aber nicht.
- **Der Bildschirm bleibt an, solange die App vorn ist** (ab 1.0.1, Ansage
  des Nutzers 09/2026). `isIdleTimerDisabled` hängt an `scenePhase` in
  `RoutenplanerApp`: nur `.active`, im Hintergrund gilt wieder das Gerät.
  **Im Hintergrund arbeitet die App nur, solange eine AUFZEICHNUNG läuft**
  (ab 1.0.5) — Planen, Meldungen und Kacheln nie.
- **Streckenaufzeichnung** (`Dienste/Aufzeichner.swift`, `Model/Fahrt.swift`,
  ab 1.0.5, Ansage des Nutzers 09/2026: „möglichst genau, egal wie viel Akku
  es kostet"). `BestForNavigation`, `distanceFilter = None`,
  `pausesLocationUpdatesAutomatically = false`, `activityType` je
  Fortbewegung. Hintergrund über `UIBackgroundModes = location` plus
  `CLBackgroundActivitySession` — mit „Beim Verwenden", NICHT „Immer".
  **Ohne den Plist-Eintrag stürzt `allowsBackgroundLocationUpdates = true`
  ab — nie entfernen.** Bei ungefährer Ortung wird einmalig die genaue
  erbeten (Schlüssel „Aufzeichnung" in
  `NSLocationTemporaryUsageDescriptionDictionary`).
- **Jede Messung wird SOFORT angehängt** (`<Kennung>.spur`, eine Zeile je
  Messung, in Application Support), der Kopf (`.json`) alle 30 Messungen.
  Wird die App beendet, bleibt eine Fahrt ohne `ende` liegen; beim nächsten
  Start steht „Fortsetzen / So abschließen" im Bedienfeld. Fortgesetzt wird
  als neuer ABSCHNITT — dazwischen hat niemand gemessen, die Linie wird dort
  nicht durchgezogen; Pausen ebenso. **Neu STARTEN kann iOS eine beendete
  App nur mit „Immer"** — nicht als „zeichnet immer auf" darstellen.
- **`Spurrechner` ist die EINE Rechnung** für Live-Anzeige und gesicherte
  Fahrt. Zwei Regeln, gewählt und nicht gemessen: nur Messungen bis ±30 m,
  und gezählt wird erst, wenn der Abstand zum letzten gezählten Punkt die
  Unsicherheit beider übersteigt (sonst wächst die Strecke an jeder Ampel).
  Die Datei behält JEDE Messung, damit sich die Regeln später ändern lassen.
  Die GPX-Ausgabe enthält alle Messungen bis ±30 m mit Zeit und Höhe,
  ungeglättet, ein `trkseg` je Abschnitt.
- **Auf der Karte in Stücken zu 300 Punkten** (`Routenkarte.spurSetzen`):
  Nur das letzte, wachsende Stück wird jede Sekunde ersetzt. Eine Linie aus
  zehntausend Punkten jede Sekunde neu zu bauen wäre der teure Weg.
- **„Ohne Schieben" ist ein Schalter im Bedienfeld** (ab 1.0.1), nicht nur im
  Profil-Editor — ob geschoben werden darf, entscheidet man je Fahrt.
  Gespeichert wird er am gewählten Profil (`Planer.schiebenSetzen`) und
  schickt `profile:schieben=0` an BRouter; gemessen: dann 0 m Schieben.
- **Start und Ziel durch Antippen der Karte** (`Routenkarte` mit `MapReader`,
  `PlanerView.antippen`, ab 1.0.2, Ansage des Nutzers 09/2026). Den Tipp nimmt
  die KARTE entgegen (`onTapGesture` + `MapProxy.convert`); Schieben und
  Zoomen bleiben unberührt, und auf der Karte liegt weiter kein Bedienelement.
  Gefragt wird in einem Dialog: „Route hierhin – von meinem Standort", „Als
  Ziel", „Als Start". **Erst die Frage, dann der Name** — der Geocoder
  braucht eine Sekunde und wird nachgetragen, nur wenn noch derselbe Punkt
  gemeint ist (Lehre aus Abfahrtstafel 1.1.26). **Ohne bekannten Standort
  wird NICHT von einem alten Start gerechnet**: Das Ziel wird gesetzt, der
  Start geleert, und die App sagt, was fehlt.
- **Verkehrslage auf der Karte ist Apples Anzeige** (`.mapStyle(.standard(
  showsTraffic:))`, Autosymbol unten, ab 1.0.2). Sie geht NICHT in die
  Berechnung ein — MapKit gibt diese Daten nicht heraus. In die Route gehen
  nur die Autobahn-Meldungen; ihr Schalter heißt seither „Meldungen" statt
  „Verkehr", sonst hießen zwei verschiedene Dinge gleich. Wahl in
  `@AppStorage` (in der VIEW).
- **CarPlay: nein, und das bleibt so, bis Apple es bewilligt** (Frage des
  Nutzers 09/2026). Eine Karten-App braucht das Entitlement
  `com.apple.developer.carplay-maps`, das Apple nur auf Antrag vergibt, und
  zwar für Apps mit Zielführung Schritt für Schritt — die hat diese App
  nicht. **Ohne Bewilligung nie in eine Entitlements-Datei eintragen**: Das
  Projekt wäre unsignierbar (dieselbe Lehre wie Reisebuch 1.0.45). Weg, falls
  gewünscht: erst eine Zielführung bauen, dann den Antrag unter
  developer.apple.com/carplay stellen, erst danach die CarPlay-Szene.
- **Die Karte ist seit 1.0.3 eine `MKMapView` aus UIKit** (`Routenkarte`,
  Ansage des Nutzers 09/2026: Hell/Dunkel, andere Kartenmodelle, Radwege und
  Belag ein- und ausblenden, „über einen Menüschalter an der Karte"). Die
  SwiftUI-`Map` kann unter iOS 17 keine Kachelschicht zeigen. Auf der Karte
  liegt weiterhin kein Bedienelement: Zeichen sind `isEnabled = false`, den
  Tipp nimmt ein eigener Erkenner, der auf den Doppeltipp-Zoom wartet.
  Ortung, Kompass und Maßstab stehen am Rand, der Ebenen-Knopf oben links.
- **Kachelquellen, alle am 23.09.2026 gemessen** (HTTP 200, PNG 256 px, ohne
  Schlüssel): OSM, CyclOSM, CyclOSM-lite (durchsichtige Radweg-Schicht),
  OpenTopoMap, Waymarked Trails cycling. `Kacheln.sitzung` hält die
  OSM-Richtlinie ein (User-Agent, `URLCache` 256 MB, zwei Verbindungen je
  Server, kein Vorausladen); über der höchsten Stufe eines Dienstes wird die
  letzte Kachel vergrößert statt neu angefragt. Der Lizenzhinweis steht auf
  der Karte und ist nicht abschaltbar. **Thunderforest (OpenCycleMap)
  antwortete ohne Schlüssel, verlangt laut Bedingungen aber einen — nicht
  schlüssellos einbauen**; nur mit einem EIGENEN Schlüssel des Nutzers im
  Schlüsselbund.
- **Dunkel gibt es nur für Apples Karte** (`overrideUserInterfaceStyle`);
  die freien Kacheln liegen nur hell vor, und nachträglich umgefärbte
  Kacheln hätten Farben, die nichts mehr bedeuten. Die Verkehrslage ebenso
  nur auf Apples Karte; ihr Schalter wohnt seit 1.0.3 im Kartenmenü und
  nicht mehr im Bedienfeld (keine doppelten Schalter).
- **Der Belag der Radroute kommt aus `surface` in BRouters WayTags**
  (`Belag.aus`, fünf Klassen, „nicht eingetragen" wird nicht geraten). Eine
  EIGENE Liste (`Route.belaege`) neben den Abschnitten — als Feld am
  Abschnitt zerfiele jede Schiebestrecke in der Detailansicht an jedem
  Belagwechsel. Die Zuordnung der Stellen (`BRouter.stellen`) teilen sich
  beide Listen. Farbe UND Strichbild, und die Legende nennt die Kilometer.
- **Jede Planung liefert Alternativen** (ab 1.0.4, Ansage des Nutzers
  09/2026). Gemessen 23.09.2026: Valhalla `alternates: 2` gibt bei Auto, Rad
  und zu Fuß je zwei echte andere Wege zurück (Dortmund → Köln 94,3 / 99,7 /
  106,3 km); BRouter rechnet `alternativeidx` 0 bis 3 als EINZELNE Anfragen
  (3573 / 4350 / 4964 / 4246 m — nicht nach Länge geordnet, sortiert wird in
  der App). Gefragt werden 0 bis 2; scheitert eine Alternative, zählt nur die
  erste als Fehler. Fast gleich lange Vorschläge (unter 0,5 %) fallen weg.
  Ausgewählt wird in der Leiste unter der Karte, NICHT auf der Karte — dort
  setzt ein Tipp Start oder Ziel. Gerahmt wird nur bei einer neuen Rechnung.
- **Staus zählen in die REIHENFOLGE, nicht nur in die Zeit** (ab 1.0.4,
  gemeldet 09/2026: „dass ein Stau zwar auf der Karte angezeigt wird, aber
  nicht bei der Berechnung … berücksichtigt wird"). Die Autobahn GmbH meldet
  `delayTimeValue` in Minuten als TEXT (gemessen: 1 bis 55 min an A1–A9);
  jede Alternative bekommt ihren eigenen Stauverlust, und die schnellste MIT
  Stau steht vorn. Ab `Planer.stauSchwelleMin` (10 min, gewählt) wird eigens
  eine Umfahrung angefragt: Sperrfläche um die MITTE des Staus. Gemessen, dass
  das wirkt: Dortmund → Wuppertal mit der Mitte des Staus Gevelsberg–Eichenkamp
  gesperrt, erste Route 48,1 → 49,9 km. Die Umfahrung wird mit derselben
  Rechnung bewertet wie alle — gerät sie selbst in einen Stau, zählt der mit.
  Apples Verkehrslage bleibt reine Anzeige; TomTom und HERE hätten Daten für
  alle Straßen, verlangen aber einen Schlüssel. Staus abseits der Autobahn
  kennt die App deshalb NICHT — das steht in jedem Auto-Ergebnis.
- **Meldungen ohne Zeitangabe zählen nicht** — und das wird GESAGT. Nicht
  schätzen: eine erfundene Minutenzahl stünde als Posten in der Rechnung.
- **Overpass war aus der Bauumgebung nicht erreichbar**, die OSM-API schon —
  die ist aber zum Bearbeiten da und kein Datendienst für Apps. Die App fragt
  sie deshalb nicht. Offen: Unterführungen OHNE eingetragene Höhe erkennen.
- `MARKETING_VERSION` und `CURRENT_PROJECT_VERSION` stehen an je zwei Stellen
  im pbxproj (Debug + Release), KEINE Skript-Bauphase. **Jede Arbeitseinheit
  hebt Patch- UND Build-Nummer um je +1.** Start: 1.0.0 (Build 1),
  dann 1.0.1 (Build 2), 1.0.2 (Build 3), 1.0.3 (Build 4), 1.0.4 (Build 5),
  1.0.5 (Build 6).
  `DEVELOPMENT_TEAM = F4989GSTWS`, Kategorie Navigation,
  `ITSAppUsesNonExemptEncryption = NO` in `Config/Info.plist` UND als
  Build-Einstellung — nicht entfernen.
- Das App-Symbol rechnet `RoutenplaneriOS/scripts/make-icon.py`.
- Übersetzt wird in GitHub Actions (Eintrag
  `("RoutenplaneriOS", "Routenplaner")` in `welche-apps.py`). **Erst pushen,
  Bau abwarten, Fehler beheben — den PR-Link erst herausgeben, wenn der Bau
  grün ist.**
