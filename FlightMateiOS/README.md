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
    Live-Abfrage mit sichtbarer Quelle und Zeitstempel.
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
- **Lichtplanung (F3):** Sonnenauf-/-untergang, goldene und blaue
  Stunde, vollständig on-device berechnet; das Licht fließt in den
  Score ein (Golden Hour hebt, Mittagslicht senkt).
- **Spots (F4, lokal):** Bis zu 3 gespeicherte Orte (Free-Tier-Grenze
  aus dem PRD); jeder Spot zeigt das beste Fenster der nächsten 7 Tage.
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
- AI-Bildkritik & Shot-Vorschläge (V2), Spot-Entdeckung (V3)
- Abo/StoreKit (Free-Tier-Grenzen sind bereits im Code verankert)
- Validierung der dipul-Layernamen gegen den Live-Dienst und
  Score-Validierung mit realen Flugtagen (PRD Phase 0-Meilenstein)

## Technik

- Swift 5 / SwiftUI, iOS 17+, iPhone, keine externen Abhängigkeiten
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
