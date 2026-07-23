# ✈️ FlightMate AI — native iOS-App

Der intelligente Copilot für Drohnenpiloten und Landschaftsfotografen.
Die App steuert keine Drohne — sie hilft, **zur richtigen Zeit am richtigen
Ort die bestmöglichen Luftaufnahmen zu machen**.

Grundlage ist das PRD unter [`../docs/flightmate-ai/PRD.md`](../docs/flightmate-ai/PRD.md).
Dieser Stand entspricht dem **MVP-Fundament** (PRD Phase 0/1).

## Was schon funktioniert

- **Flight Score (F1):** 0–10 pro Stunde und Tag, deterministisch und
  erklärbar berechnet aus Wind **in Flughöhe** (120 m, Open-Meteo),
  Böen, Regenrisiko, Sicht, Temperatur und Lichtqualität — gewichtet
  nach dem konkreten Drohnenprofil. Jede Zahl kann per Tipp ihre
  Begründung zeigen („Böen 32 km/h — 84 % deiner Windtoleranz").
  Inklusive „bestes Fenster"-Erkennung und 7-Tage-Ausblick.
- **Legal-Check (F2):** Tipp auf die Karte → „Erlaubt / Erlaubt mit
  Auflagen / Verboten" für genau diese Koordinate, mit redaktionellen
  Klartexten je Zonentyp. Länder-Provider-Architektur:
  - **Deutschland** (EU Open A1, Klasse C0): dipul-WFS (BMDV),
    Live-Abfrage mit sichtbarer Quelle und Zeitstempel. Punktgenau
    (~40-m-GPS-Toleranz statt Umkreissuche — eine Zone in der Nähe
    ist kein Treffer am Startpunkt) und mit 27 Zonentypen inkl.
    Flugbeschränkungsgebieten (ED-R) und temporären Sperrungen;
    Layernamen gegen den Live-Dienst validiert.
  - **Schweiz** (EU-Regeln übernommen): amtliche BAZL-Drohnenkarte via
    geo.admin.ch — die App zeigt den amtlichen Beschränkungstext im
    Wortlaut. Nennt der Text eine Gewichtsgrenze (z. B. „mehr als
    250 g"), unter der die Drohne des Nutzers liegt, wird die Zone als
    „nicht betroffen" markiert — für die C0-Minis oft der
    entscheidende Unterschied.
  - **Kanada** (CARs Part IX, Mikrodrohnen < 250 g): Nationalparks
    aus dem amtlichen NRCan-CLSS-Dienst (Parks-Canada-Drohnenverbot,
    Punkt-in-Polygon) und Flughäfen mit Flugsicherung aus dem
    Transport-Canada-Dienst (3-NM-Umkreis). Mit kostenlosem
    openAIP-Schlüssel (Einstellungen) prüft der Legal-Check zusätzlich
    die Lufträume der NAV-Drone-Karte: Kontrollzonen (CTR) und
    Class-F-Gebiete (CYR/CYD/CYA), punktgenau per Ray-Casting.
    Dazu live (Nutzerwunsch: Antworten in der App statt
    Portal-Verweis): **Waldbrand-Sperrzonen** — Satelliten-Hotspots
    der letzten 24 h vom offenen NRCan/CWFIS-GeoServer, Treffer im
    9,3-km-Umkreis (CARs 601.15) melden „Verboten";
    **Ontario-Provinzparks** (Drohnenverbot) vom offenen LIO-Dienst
    der Provinz; mit openAIP-Schlüssel auch **kleine Flugplätze und
    Heliports** ohne Flugsicherung (3-NM-/1-NM-Hinweis, z. B.
    Tyendinaga/Mohawk). Verbleibende nicht abfragbare Zonentypen
    (NOTAMs, Provinzparks außerhalb Ontarios) werden sichtbar als
    „nicht geprüft" gelistet, mit Verweis auf NAV Drone.
  - **USA** (49 USC 44809, Recreational Exception — komplett ohne
    Schlüssel, alle Quellen offen): FAA UAS Facility Maps
    (LAANC-Rasterzellen mit Höhen-Obergrenze — Obergrenze 0 ft =
    verboten, sonst „mit LAANC-Freigabe bis X ft"), FAA-Luftraum-
    klassen (B/C/D/E-Bodenflächen), FAA Special Use Airspace
    (Prohibited/Restricted rot, MOA & Co. orange) und die Parkgrenzen
    des National Park Service (Drohnenverbot in allen NPS-Gebieten).
    Dazu die New-York-City-Regel (Start/Landung im Stadtgebiet ohne
    Genehmigung verboten, Admin Code § 10-126) als deterministische
    Zone. TFRs/NOTAMs, State Parks und Stadien werden ehrlich als
    „nicht geprüft" gelistet (Verweis auf B4UFLY/Aloft).
  - **EU-Nachbarländer** (NL, BE, LU, FR, DK, CZ, PL, AT): Die
    EU-Regeln (Open A1/C0) sind harmonisiert und werden als Basis
    ausgewiesen, inklusive Landes-Besonderheiten (z. B. Frankreichs
    Verbot über Ortschaften, Polens DroneTower-Check-in-Pflicht).
    Lufträume live über openAIP (mit Schlüssel). **Nationale
    Geozonen direkt in der App** (Nutzerwunsch: kein Portal-Suchen),
    wo eine amtliche offene Quelle existiert — je live verifiziert:
    - Niederlande: Natura-2000-Gebiete (PDOK/RVO-WFS,
      GetPropertyValue — <1 KB pro Punktabfrage statt
      Multi-MB-Polygone); Drohnenverbot in Natura 2000
    - Frankreich: amtliche DGAC-Restriktionskarte für Freizeitpiloten
      (IGN/Géoplateforme-WFS) — „Vol interdit" wird als Verbot
      gemeldet, Höhenwerte als Auflage, amtliche Bemerkungen im
      Wortlaut
    - Luxemburg: amtliche UAS-Geozonen im ED-269-Format
      (drones.geoportail.lu, 5-min-aktuell) — Punkt-in-Polygon lokal,
      abgelaufene temporäre Zonen werden ausgeblendet
    Für BE, DK, CZ, PL, AT gibt es keine offen abfragbaren Dienste —
    dort bleibt der ehrliche Portal-Verweis (Droneguide, Droneluftrum,
    DronView, PANSA, Dronespace).

  Außerhalb der abgedeckten Länder oder ohne Netz zeigt die App
  ehrlich „Keine Daten" statt zu raten.
- **Zonen-Umrisse auf der Karte (DE + CA + US + EU-Nachbarn):** In
  Kanada zeichnet die Karte Nationalpark-Polygone (rot, NRCan),
  3-NM-Kreise um Flughäfen mit Flugsicherung (orange, Transport
  Canada), Waldbrand-Sperrkreise (rot, 9,3 km um CWFIS-Hotspots)
  und in Ontario die Provinzpark-Polygone (rot, LIO); mit
  openAIP-Schlüssel zusätzlich die Lufträume wie auf der
  NAV-Drone-Karte — Flugverbots- und Restricted-Gebiete (CYR) rot,
  Kontrollzonen (CTR) und Advisory-Gebiete (CYA) orange — sowie
  orange 3-NM-/1-NM-Kreise um kleine Flugplätze und Heliports. In den USA
  (ohne Schlüssel): FAA-Luftraumklassen B/C/D/E, Special Use Airspace
  und NPS-Nationalparks; im Grenzband (Great Lakes, Bundesstaat New
  York) werden USA- und Kanada-Quellen kombiniert. In den
  EU-Nachbarländern und der Schweiz zeichnet openAIP die Lufträume
  (mit Schlüssel); in Grenznähe Deutschlands erscheinen so auch die
  Zonen hinter der Grenze. In
  Deutschland: Die Karte zeichnet alle
  flächigen Zonentypen des sichtbaren Ausschnitts als farbige
  Polygone (rot = verboten, orange = mit Auflagen, mit Legende) —
  wie auf der amtlichen dipul-Karte. Zwei Zoom-Stufen: Schutzgebiete
  und Luftfahrt-Zonen früh; dichte Korridore (Straßen, Bahn,
  Wasserstraßen, Strom) und Wohngrundstücke ab ~10 km Ausschnitt,
  damit Städte nicht vollflächig zugedeckt werden (Legende zeigt
  „mehr beim Hineinzoomen"). Kartenstil umschaltbar
  (Karte / Hybrid / Satellit) und Tag-/Nachtansicht unabhängig vom
  Geräte-Erscheinungsbild erzwingbar; beide Einstellungen bleiben
  gespeichert.
- **Sonne auf der Karte:** Das Briefing zeigt je gewähltem Tag eine
  Karte mit Azimut-Linien vom Spot zur Sonne bei Auf- (orange) und
  Untergang (violett), inkl. Uhrzeit-Etiketten in Ortszeit und
  Gradangabe — Blick entlang der Linie = Gegenlicht/Silhouette,
  Motive auf der Gegenseite werden angestrahlt. Komplett on-device
  (SunCalculator), keine weitere Datenquelle.
- **Lichtplanung (F3):** Sonnenauf-/-untergang, goldene und blaue
  Stunde, vollständig on-device berechnet; das Licht fließt in den
  Score ein (Golden Hour hebt, Mittagslicht senkt).
- **Spots (F4, lokal):** Bis zu 3 gespeicherte Orte (Free-Tier-Grenze
  aus dem PRD); jeder Spot zeigt das beste Fenster der nächsten 7 Tage.
  Speichern per Karten-Tipp oder mit einem Tipp auf „+" direkt am
  aktuellen Standort; umbenennen per Wisch-Aktion.
- **iPad-Planungslayout:** Auf breiten Bildschirmen zeigt „Heute"
  zwei Spalten (Score + Tagesverlauf links, Licht + 7-Tage-Ausblick
  rechts) — der Anfang des Planungs-Canvas aus PRD F12.
- **Spot-Entdeckung (F9, erste Ausbaustufe):** Neuer „Entdecken"-Tab
  — Foto-Orte in der Nähe aus OpenStreetMap (Aussichtspunkte, Gipfel,
  Wasserfälle, Burgen & Schlösser, Leuchttürme; Radius 10/25/50 km,
  Kategorie-Chips). Beim Antippen prüft FlightMate den Ort automatisch
  mit Legal-Check und Flight Score („geprüft, nicht nur schön") und
  zeigt das beste Fenster der Woche; ein Tipp speichert ihn als Spot.
  Die Mini-Karte lässt sich antippen und öffnet eine zoombare
  Vollbild-Karte (Hybrid, mit eigenem Standort), um den Spot genau zu
  verorten; „Dorthin navigieren" übergibt den Ort an Apple Karten.
  Jede Kategorie fragt Overpass als eigene kleine Abfrage parallel ab
  (mit Spiegel-Servern als Ausweichlösung) — was durchkommt, wird
  angezeigt; ein Fehler erscheint nur, wenn alle Kategorien scheitern.
  **Reiseplanung:** Gesucht wird nicht nur am eigenen Standort — auf
  der Karte öffnet jeder angetippte Punkt den Knopf „Foto-Orte hier
  entdecken", und im Entdecken-Tab gibt es eine Freitext-Ortssuche
  (Lupe); ein Banner zeigt das aktive Suchzentrum, „Mein Standort"
  stellt zurück.
  **Fotos vom Ort:** Die Detailansicht zeigt eine Bildergalerie —
  zuerst die am OSM-Knoten gepflegten Bildverweise
  (image/wikimedia_commons-Tags), aufgefüllt mit frei lizenzierten
  Wikimedia-Commons-Fotos aus 300 m Umkreis (GeoSearch, ohne
  Schlüssel); ausgeliefert werden kleine Special:FilePath-Thumbnails,
  ein Tipp aufs Bild öffnet die Commons-Seite mit Lizenz/Urheber.
  Keine Likes, keine Feeds (PRD N2). Daten: © OpenStreetMap (ODbL).
- **Score-Erklärung am Ring:** Tipp auf den Score-Ring im Heute-Tab
  öffnet die Faktoren-Begründung der besten Stunde („Warum 7?").
  Darüber steht der per Reverse-Geocoding ermittelte Ortsname.
- **Kalender & Teilen:** Im Briefing lässt sich das beste Fenster als
  .ics-Termin exportieren (Teilen-Blatt → Kalender; inkl. Erinnerung
  „Akkus laden" eine Stunde vorher — ohne Kalender-Berechtigung) und
  das Briefing als Kurztext teilen.
- **Pre-Flight-Briefing (User Journey Phase 2):** Tipp auf einen Spot
  → eine Karte mit 10 Sekunden Lesezeit: bestes Fenster (plus
  Hinweis auf den besten Tag der Woche), Legal-Status mit Maximalhöhe,
  Bedingungen im Fenster und Lichtzeiten. Über Tages-Chips lässt sich
  jeder der nächsten 7 Tage planen — Bildideen und Lichtzeiten folgen
  dem gewählten Tag. Die Rechts-Karte zeigt **alle** vermuteten
  Einschränkungen mit Klartext sowie die „Nicht geprüft"-Liste
  (Nutzerwunsch — nicht nur die erste Zone). **Ortszeit:** Alle
  Zeiten im Briefing (Fenster, Tages-Chips, Licht, Benachrichtigungs-
  texte) stehen in der Zeitzone des Spots, nicht der Gerätezeit —
  bei fernen Spots mit sichtbarem Hinweis; auch die Tagesgrenzen der
  7-Tage-Ansicht folgen der Spot-Zeitzone (Open-Meteo liefert den
  UTC-Versatz mit).
- **Flight Review (F5, KI):** Neuer „Review"-Tab — nach dem Flug bis
  zu 5 Aufnahmen auswählen (PhotosPicker, kein Mediathek-Vollzugriff);
  Claude bewertet jede entlang der festen PRD-Rubrik mit max. 2
  Stärken und genau einem umsetzbaren Verbesserungsvorschlag
  (Mentor-Ton). Bilder werden verkleinert übertragen, nicht
  gespeichert, nicht fürs Training verwendet.
- **Bildideen (F6, KI):** Im Spot-Briefing schlägt Claude 2–3
  konkrete, ausführbare Bildideen für Ort, Licht und Wind vor — die
  legale Maximalhöhe aus dem Legal-Check geht als harte Bedingung in
  den Prompt ein.
- **Lern-Loop (User Journey Phase 3):** Die Verbesserungsvorschläge
  aus dem Flight Review werden lokal gemerkt (letzte 12, nur auf dem
  Gerät). Im nächsten Briefing erscheinen sie als Erinnerung („Denk
  heute dran …") und fließen in die Bildideen ein — der Kreis
  Entscheiden → Fliegen → Lernen schließt sich.
- **Offline-Briefing:** Der letzte erfolgreiche Legal-Check pro Spot
  wird gecacht; ohne Netz zeigt das Briefing ihn mit sichtbarem
  Datenstand statt „keine Daten" (PRD Kap. 10, offline-first).
  Dazu Sonnenauf-/-untergangsrichtung mit Kompasspfeil im Briefing.
- **KI-Anbindung:** Eigener Anthropic-API-Schlüssel des Nutzers
  („bring your own key", Einstellungen → KI-Funktionen), gespeichert
  in der Keychain. Claude-API direkt (`claude-opus-4-8`, adaptives
  Thinking, Structured Outputs für garantiert parsbares JSON). Score
  und Legal-Check bleiben deterministisch (PRD Kap. 12). Für einen
  öffentlichen Release ist weiterhin der Server-Proxy aus dem PRD
  vorgesehen. **Sparmodus:** Schalter in den Einstellungen stellt die
  KI-Aufrufe auf `claude-haiku-4-5` um (~1/5 der Kosten).
- **Proaktive Benachrichtigung (F4):** Maximal eine Meldung pro Tag,
  nur bei außergewöhnlich guten Fenstern (Score ≥ 8) an gespeicherten
  Spots, gemeldet 2 h vor Fensterbeginn. Komplett auf dem Gerät
  vorausgeplant (lokale Notifications) — kein Server, keine Spot-Daten
  verlassen das Gerät. Opt-in in den Einstellungen.
  **Hintergrund-Aktualisierung:** Über BGAppRefresh prüft die App
  auch ungeöffnet regelmäßig das Wetter an den Spots und plant die
  Meldungen neu (iOS entscheidet den Zeitpunkt, typisch 1–2× täglich
  bei regelmäßiger Nutzung; Support/Info.plist trägt die
  Task-Kennung `de.familie.flightmate.refresh`).
- **Score-Validierung (PRD Phase 0):** Karte im Heute-Tab „Warst du
  heute draußen?" — Ein-Tipp-Rückmeldung (passte / zu optimistisch /
  zu pessimistisch), eine pro Tag, lokal gespeichert (letzte 90
  Tage). Ab drei Rückmeldungen zeigt die Karte die Bilanz samt
  Tendenz; damit werden die Score-Gewichte später bewusst von Hand
  nachjustiert — kein automatisches Lernen, das Regelwerk bleibt
  erklärbar (PRD Kap. 12).
- **Onboarding < 2 min:** Einzige Frage ist das Drohnenmodell
  (Mini 3 / Mini 4K / Mini 4 Pro) — Windtoleranz, EU-Klasse und Regeln
  werden abgeleitet. Kein Account.
- **Offline-first:** Letzte Wetterprognose wird pro Ort gecacht und
  bei Netzausfall mit sichtbarem Datenstand verwendet — auch ein
  älterer Stand ist ehrlicher als keiner.
- **Offline-Reisepaket:** Knopf im Spots-Tab lädt für alle
  gespeicherten Spots alles Cachebare vorab aufs Gerät (7-Tage-
  Wetter, Legal-Check-Schnappschuss, mit openAIP-Schlüssel auch
  Lufträume & Flugplätze im Umkreis) — fürs Briefing im
  Provinzpark-Funkloch; ehrliche Zusammenfassung inkl. Hinweis,
  dass das Apple-Kartenbild selbst nicht vorab speicherbar ist.
- **iCloud-Sync & Datenexport:** Spots und Drohnenmodell
  synchronisieren über den iCloud-Key-Value-Store auf alle Geräte
  (Entitlement in Support/FlightMate.entitlements; Konflikt:
  zuletzt geschriebener Stand gewinnt), die API-Schlüssel über den
  iCloud-Schlüsselbund (kSecAttrSynchronizable, Ende-zu-Ende-
  verschlüsselt). Dazu Export/Import als JSON-Sicherung in den
  Einstellungen (Spots, Modell, Score-Feedback — bewusst ohne
  Schlüssel; Import vereinigt nach ID, löscht nichts).

## Noch offen (bewusst, siehe PRD-Roadmap)

- Nationale Geozonen von BE, DK, CZ, PL, AT als Live-Abfrage — diese
  Portale (Droneguide, Droneluftrum, DronView, PANSA, Dronespace)
  haben keine offenen Schnittstellen; NL, FR und LU sind bereits
  live angebunden. Nationale Zonen (Natura 2000, DGAC-Karte) auch
  als Karten-Overlays — die amtlichen Polygone sind sehr groß
  (mehrere MB), dafür braucht es eine Vereinfachungs-Stufe
- Serverseitiger Benachrichtigungs-Scheduler (PRD Kap. 10) für einen
  öffentlichen Release — aktuell BGAppRefresh auf dem Gerät (iOS
  bestimmt die Laufzeitpunkte selbst)
- Kanada: NOTAMs als Live-Abfrage — kein offen abfragbarer Dienst
  (NAV-Drone-API ist login-pflichtig); wird als „nicht geprüft"
  angezeigt. Lufträume (CTR, CYR/CYD/CYA) sind inzwischen über
  openAIP abgedeckt (kostenloser Schlüssel in den Einstellungen)
- Spot-Entdeckung: redaktionelle Kuration & Community-Ebene (V3);
  Server-Proxy für die KI-Funktionen (für einen öffentlichen
  Release — aktuell „bring your own key")
- Abo/StoreKit (Free-Tier-Grenzen sind bereits im Code verankert)
- Validierung der dipul-Layernamen gegen den Live-Dienst und
  Score-Validierung mit realen Flugtagen (PRD Phase 0-Meilenstein)

## Technik

- Swift 5 / SwiftUI, iOS 17+, universell für iPhone und iPad
  (bildschirmfüllend, Lesebreiten-Layout auf großen Displays),
  keine externen Abhängigkeiten
- `Model/FlightScoreEngine.swift` — deterministisches Regelwerk mit
  Faktoren-Ausgabe (bewusst **kein** LLM, PRD Kap. 12)
- `Model/DroneProfile.swift` — Drohnen als Datenprofile, modellagnostischer
  Kern von Tag 1 (PRD Kap. 10)
- `Model/SunCalculator.swift` — Sonnenposition/Lichtfenster on-device
  (Meeus/SunCalc-Näherung)
- `Model/WeatherService.swift` — Open-Meteo inkl. `wind_speed_120m`,
  Koordinaten für Abfragen auf ~1 km gerundet (Datenschutz), Cache
- `Model/LegalService.swift` — dipul-WFS-Abfrage + versioniertes
  Regelwerk, ehrliche Degradation
- Karten: MapKit · Standort: CoreLocation (nur „While Using")

## Bauen

1. `FlightMateiOS/FlightMate.xcodeproj` in Xcode 16+ öffnen.
2. Unter *Signing & Capabilities* eigenes Team wählen (Bundle-ID
   `de.familie.flightmate` ggf. anpassen).
3. iPhone als Ziel wählen, **Run**. Die App fragt beim ersten Start
   nach der Standortberechtigung (optional — Fallback Berlin).
