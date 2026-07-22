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
    Transport-Canada-Dienst (3-NM-Umkreis). Nicht abfragbare
    Zonentypen (Luftraumklasse F, NOTAMs, Provinzparks) werden
    sichtbar als „nicht geprüft" gelistet, mit Verweis auf NAV Drone.

  Außerhalb der abgedeckten Länder oder ohne Netz zeigt die App
  ehrlich „Keine Daten" statt zu raten.
- **Zonen-Umrisse auf der Karte (DE + CA):** In Kanada zeichnet die
  Karte Nationalpark-Polygone (rot, NRCan) und 3-NM-Kreise um
  Flughäfen mit Flugsicherung (orange, Transport Canada). In
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
  dem gewählten Tag.
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
- **Onboarding < 2 min:** Einzige Frage ist das Drohnenmodell
  (Mini 3 / Mini 4K / Mini 4 Pro) — Windtoleranz, EU-Klasse und Regeln
  werden abgeleitet. Kein Account.
- **Offline-first:** Letzte Wetterprognose wird pro Ort gecacht und
  bei Netzausfall mit sichtbarem Datenstand verwendet.

## Noch offen (bewusst, siehe PRD-Roadmap)

- Geo-Zonen Österreich (Dronespace/Austro Control hat keinen offen
  abfragbaren Dienst; aktuell ehrlich als Lücke markiert)
- Benachrichtigungen im Hintergrund aktualisieren (BGAppRefresh bzw.
  später serverseitiger Scheduler, PRD Kap. 10) — aktuell wird bei
  jedem App-Start neu geplant
- Kanada: Luftraumklasse F (CYR/CYD/CYA) und NOTAMs als Live-Abfrage —
  derzeit kein offen abfragbarer Dienst; wird als „nicht geprüft"
  angezeigt
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
