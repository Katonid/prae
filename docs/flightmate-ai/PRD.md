# FlightMate AI — Product Requirement Document (PRD)

**Produkt:** FlightMate AI — Der intelligente KI-Copilot für Drohnenpiloten und Landschaftsfotografen
**Plattform:** iOS (iPhone), später iPad
**Dokumentstatus:** v1.0 — Entwurf
**Datum:** 22.07.2026

---

## Inhaltsverzeichnis

1. [Vision](#1-vision)
2. [Zielgruppe](#2-zielgruppe)
3. [User Personas](#3-user-personas)
4. [Probleme, die gelöst werden](#4-probleme-die-gelöst-werden)
5. [User Journey](#5-user-journey)
6. [MVP](#6-mvp)
7. [Version 2](#7-version-2)
8. [Version 3](#8-version-3)
9. [Nicht-Ziele](#9-nicht-ziele)
10. [Technische Anforderungen](#10-technische-anforderungen)
11. [Datenschutz](#11-datenschutz)
12. [AI-Funktionen](#12-ai-funktionen)
13. [Monetarisierung](#13-monetarisierung)
14. [Risiken](#14-risiken)
15. [Roadmap](#15-roadmap)

---

## 1. Vision

> **„Dem Benutzer helfen, zur richtigen Zeit am richtigen Ort die bestmöglichen Luftaufnahmen zu machen."**

FlightMate AI ist kein Drohnen-Controller, keine Wetter-App und kein Karten-Tool. Es ist die eine App, die ein Drohnenpilot öffnet, **bevor** er die Drohne aus der Tasche nimmt — und die ihm in einem Satz sagt, ob sich der Flug lohnt, ob er legal ist und wie das beste Bild entsteht.

Heute muss ein Pilot für einen einzigen guten Flug vier bis sechs Apps konsultieren: Wetter, Wind, Sonnenstand, Luftraum, Karten, Foto-Planung. Jede App liefert Rohdaten. Keine liefert eine **Entscheidung**. FlightMate AI verdichtet alle relevanten Faktoren zu einer einzigen, verständlichen Empfehlung:

> *„Heute Abend, 20:41 Uhr, Golden Hour mit 8 km/h Wind aus West — perfekte Bedingungen für deine geplante Aufnahme am Seeufer. Flug dort erlaubt, max. 120 m."*

**Produktprinzipien (Apple-Denkweise):**

1. **Eine Antwort statt zehn Datenpunkte.** Die App trifft keine Entscheidung für den Piloten, aber sie bereitet jede Entscheidung so vor, dass sie in Sekunden fällt.
2. **Wenige Funktionen, extrem hoher Nutzen.** Jede Funktion muss ein reales, dokumentiertes Nutzerproblem lösen. Was das Kernversprechen nicht stärkt, fliegt raus.
3. **Der Pilot bleibt Pilot.** Die App steuert niemals die Drohne. Sie ist Copilot, nicht Autopilot.
4. **Vertrauen ist das Produkt.** Falsche Luftraum- oder Wetterangaben zerstören das Produkt. Genauigkeit und transparente Quellen stehen über allem.

---

## 2. Zielgruppe

### Primäre Zielgruppe (Launch)

**Besitzer von DJI-Mini-Drohnen (Mini 3, Mini 4K, Mini 4 Pro) im DACH-Raum und EU.**

Begründung dieser Fokussierung:

- **Größtes Segment:** Die Mini-Serie ist die meistverkaufte Consumer-Drohnenklasse (< 250 g). Sie ist der Einstiegspunkt für Hobbyisten und ambitionierte Fotografen.
- **Höchster Schmerz:** Gerade Mini-Piloten sind wetterempfindlich (leichte Drohne, windanfällig), rechtlich unsicher (C0-Klasse, „Darf ich hier?") und fotografisch ambitioniert, aber oft ohne Planungsroutine.
- **Homogene Anforderungen:** Eine Drohnenklasse, eine Regulierungsklasse (EU C0/„Open A1"), ein Windlimit-Profil. Das erlaubt präzise statt generische Empfehlungen.
- **EU-Regulierung ist maschinenlesbar:** EU-Drohnenverordnung + nationale Geo-Zonen sind strukturiert verfügbar — ideal für ein datengetriebenes Produkt.

### Sekundäre Zielgruppe (ab V2/V3)

- Besitzer anderer DJI-Modelle (Air, Mavic) und weiterer Hersteller (Autel, Potensic u. a.)
- Semi-professionelle Content-Creator (YouTube, Stock-Footage, Immobilien)
- Reisende Landschaftsfotografen, die Drohne + Kamera kombinieren

### Explizit nicht Zielgruppe

- Gewerbliche Inspektions-/Vermessungspiloten (Enterprise-Segment, andere Bedürfnisse)
- FPV-Racer (Fluggefühl statt Bildplanung)
- Piloten, die eine Steuerungs-App suchen (das ist DJI Fly)

---

## 3. User Personas

### Persona 1 — „Markus, der Wochenend-Pilot" (Kernpersona)

| | |
|---|---|
| **Alter** | 42 |
| **Beruf** | IT-Projektleiter |
| **Drohne** | DJI Mini 4 Pro, seit 14 Monaten |
| **Flughäufigkeit** | 2–4× pro Monat, fast nur am Wochenende |
| **Fotokenntnisse** | Ambitionierter Amateur, fotografiert in RAW |

**Verhalten:** Markus plant Flüge spontan („Das Wetter sieht gut aus, ich fahre mal los"). Er hat drei Wetter-Apps, UTM-Karten im Browser-Lesezeichen und einen Sonnenstands-Rechner, benutzt aber selten alle zusammen.

**Frustrationen:**
- Fährt 40 Minuten zu einem Spot und stellt fest: zu windig für die Mini, oder das Licht ist flach und langweilig.
- Ist sich bei Naturschutzgebieten nie sicher und fliegt deshalb manchmal gar nicht — oder mit schlechtem Gewissen.
- Seine Aufnahmen sehen „okay, aber nicht wie bei den Profis" aus und er weiß nicht, woran es liegt.

**Was Erfolg für ihn bedeutet:** Einmal pro Monat ein Bild, das er stolz drucken oder posten kann — ohne dass die Planung zur zweiten Arbeit wird.

---

### Persona 2 — „Lena, die Landschaftsfotografin"

| | |
|---|---|
| **Alter** | 29 |
| **Beruf** | Grafikdesignerin, nebenbei Instagram/Stock-Fotografie |
| **Drohne** | DJI Mini 3 (ergänzt ihre Systemkamera) |
| **Flughäufigkeit** | Wöchentlich, plant Shootings Tage im Voraus |
| **Fotokenntnisse** | Fortgeschritten (Komposition, Licht, Bearbeitung) |

**Verhalten:** Lena plant präzise: Sie recherchiert Locations, prüft Sonnenaufgangszeiten und will zur blauen Stunde am Spot stehen. Die Drohne ist für sie eine zweite Perspektive, kein Spielzeug.

**Frustrationen:**
- Planungs-Tools für Bodenfotografie (Sonnenstand, Photopills-artige Apps) ignorieren die Drohnen-Realität: Wind in 100 m Höhe, Luftraum, Akkulaufzeit bei Kälte.
- Sie verliert Aufnahmen, weil sich Bedingungen zwischen Planung (Dienstag) und Shooting (Samstag) ändern und keine App sie proaktiv warnt.
- Auf Reisen kennt sie die lokalen Drohnenregeln nicht und verzichtet lieber ganz.

**Was Erfolg für sie bedeutet:** Verlässliche Planung. Wenn die App sagt „Samstag 6:12 Uhr passt", dann passt es.

---

### Persona 3 — „Tobias, der Einsteiger"

| | |
|---|---|
| **Alter** | 24 |
| **Beruf** | Student |
| **Drohne** | DJI Mini 4K, geschenkt bekommen vor 2 Monaten |
| **Flughäufigkeit** | Unregelmäßig, hohe Anfangs-Euphorie |
| **Fotokenntnisse** | Anfänger (Automatikmodus) |

**Verhalten:** Tobias fliegt dort, wo er gerade ist. Er kennt die EU-Drohnenregeln nur grob („unter 250 g darf man doch fast alles?").

**Frustrationen:**
- Angst, unwissentlich etwas Illegales zu tun (Bußgelder, Ärger mit Anwohnern).
- Seine Videos sind verwackelte Rundflüge ohne Konzept; die Ergebnisse enttäuschen ihn im Vergleich zu YouTube-Vorbildern.
- Offizielle Informationsquellen (LBA, Verordnungstexte) überfordern ihn.

**Was Erfolg für ihn bedeutet:** Sicherheit („Ich darf das hier") und schnelle, sichtbare Fortschritte bei der Bildqualität.

**Priorisierung:** Das Produkt wird für **Markus** gebaut, muss von **Tobias** ohne Anleitung verstanden werden und darf **Lena** in ihrer Planungstiefe nicht limitieren.

---

## 4. Probleme, die gelöst werden

Jedes Problem ist die Existenzberechtigung mindestens einer Funktion. Funktionen ohne zugeordnetes Problem existieren nicht.

### P1 — „Lohnt sich der Flug?" ist heute eine Rechercheaufgabe
Der Pilot muss Wind (in Flughöhe!), Böen, Niederschlag, Sicht, Sonnenstand und Temperatur aus mehreren Quellen zusammensetzen und selbst interpretieren, was das für *seine* Drohne bedeutet. Eine DJI Mini mit ~38 km/h Windtoleranz hat andere Grenzen als eine Mavic. **Folge:** Umsonst gefahrene Kilometer, abgebrochene Flüge, im Zweifel Nichtfliegen.

### P2 — Rechtsunsicherheit lähmt oder gefährdet
„Darf ich hier fliegen?" ist für Laien kaum zu beantworten: Kontrollzonen, Naturschutzgebiete, Abstandsregeln zu Menschen, Wohngrundstücken und Infrastruktur, nationale Sonderregeln. **Folge:** Entweder Verzicht aus Angst oder unwissentliche Verstöße mit Bußgeldrisiko.

### P3 — Gutes Licht wird verpasst
Die beste Aufnahme entsteht in einem Zeitfenster von oft nur 20–40 Minuten (Golden Hour, blaue Stunde, Nebellagen). Fotografie-Planungstools kennen keinen Luftraum und keinen Wind; Drohnen-Apps kennen kein Licht. **Folge:** Technisch korrekte, aber langweilige Bilder um 13 Uhr mittags.

### P4 — Kein Feedback-Loop für bessere Aufnahmen
Nach dem Flug hat der Pilot 200 Fotos und 15 Videoclips — und niemanden, der ihm sagt, welche davon stark sind und **warum** die anderen schwach sind. **Folge:** Stagnation. Der Pilot wiederholt dieselben Fehler (Horizont mittig, kein Vordergrund, falsche Höhe).

### P5 — Gute Spots sind Zufallsfunde
Locations werden über Instagram-Geotags oder Zufall entdeckt. Ob ein Spot drohnentauglich ist (legal, Startplatz, Sichtverbindung), zeigt sich erst vor Ort. **Folge:** Zeitverschwendung, immer dieselben übervollen Spots.

### Bewusst *nicht* adressierte Probleme
Flugsteuerung, Logbuch-Pflichten für Gewerbliche, Versicherungsabwicklung, Drohnen-Hardware-Diagnose. Siehe [Nicht-Ziele](#9-nicht-ziele).

---

## 5. User Journey

Die Journey folgt dem natürlichen Dreiklang **Vor dem Flug → Am Spot → Nach dem Flug**. Die App bildet genau diese drei Phasen ab — nicht mehr.

### Phase 0 — Onboarding (einmalig, < 2 Minuten)

1. Nutzer wählt sein Drohnenmodell (Mini 3 / Mini 4K / Mini 4 Pro).
2. Die App leitet daraus automatisch ab: Windtoleranz, Gewichtsklasse (C0), geltende EU-Regeln, Kameraprofil.
3. Standortfreigabe + optional Benachrichtigungen.
4. Fertig. Kein Account-Zwang für die Kernfunktion.

*Designprinzip: Das Drohnenmodell ist die einzige Frage, die die App stellen muss. Alles andere wird abgeleitet.*

### Phase 1 — Entscheiden (zu Hause, abends oder morgens)

**Trigger:** Nutzer öffnet die App oder erhält eine proaktive Benachrichtigung („Morgen Abend: beste Flugbedingungen der Woche an deinen gespeicherten Spots").

**Erlebnis:** Der Home-Screen zeigt **eine** Kernaussage — den **Flight Score** für den aktuellen Standort bzw. gespeicherte Spots:

> **Heute 20:41 — Flight Score 9/10**
> Golden Hour · Wind 8 km/h W · keine Flugbeschränkung · Sicht 40 km
> *„Bestes Fenster: 20:20–21:05 Uhr"*

Der Nutzer versteht in **unter 5 Sekunden**, ob und wann sich ein Flug lohnt. Details (Stundenverlauf, Windprofil in Höhe, Lichtkurve) sind eine Ebene tiefer erreichbar, nie aufgedrängt.

### Phase 2 — Vorbereiten & Vor Ort (am Spot)

1. Nutzer wählt den Spot (Karte oder gespeicherte Location).
2. Die App zeigt den **Legal-Check** für exakt diese Koordinate: erlaubt / erlaubt mit Auflagen / verboten — mit Klartext-Begründung und Quelle.
3. **Pre-Flight-Briefing** (eine Karte, 10 Sekunden Lesezeit): Windfenster, Lichtstand, maximale Höhe, Hinweis auf Besonderheiten („Böen nehmen ab 21 Uhr zu").
4. Optional: **Shot-Vorschläge** — konkrete Bildideen für diesen Ort und dieses Licht („Niedrige Höhe, Gegenlicht, See als Vordergrund").

*Die App verabschiedet den Piloten hier bewusst: Während des Flugs gehört die volle Aufmerksamkeit der DJI-Fly-App und dem Luftraum. FlightMate AI drängt sich nicht in den Flug.*

### Phase 3 — Lernen (nach dem Flug, zu Hause)

1. Nutzer importiert seine besten Aufnahmen (Foto-Mediathek, Auswahl bleibt beim Nutzer).
2. Die **AI-Bildkritik** bewertet Komposition, Licht, Horizont, Perspektive — konstruktiv, konkret, mit einem Verbesserungsvorschlag pro Bild.
3. Das Gelernte fließt zurück: Beim nächsten Briefing am selben Spot erinnert die App an den Verbesserungsvorschlag („Letztes Mal: Horizont zu mittig. Versuch heute die Drittel-Regel").

**Der Loop schließt sich:** Entscheiden → Fliegen → Lernen → besser entscheiden. Das ist der Kern des Produkts und der Grund, warum Nutzer bleiben.

---

## 6. MVP

**Leitfrage für jede MVP-Funktion:** *„Würde Markus ohne diese Funktion einen schlechteren Flugtag haben?"* Wenn nein → raus.

**MVP-Versprechen in einem Satz:** *Öffne die App und wisse in 5 Sekunden, ob, wann und wo sich dein Flug heute lohnt — und ob er legal ist.*

### Funktionsumfang

#### F1 — Flight Score (Kernfunktion)
Ein Score von 0–10 pro Standort und Zeitfenster, berechnet aus Wind (Boden + Höhenwind), Böen, Niederschlag, Sicht, Temperatur und Lichtqualität — **gewichtet nach dem konkreten Drohnenmodell** des Nutzers.

- **Löst:** P1 („Lohnt sich der Flug?")
- **Begründung:** Das ist die Verdichtung, die keine Wetter-App leistet. Ohne den Score ist FlightMate nur eine weitere Datenquelle. Mit ihm ist es eine Entscheidung.
- **Umfang:** Heute + 7-Tage-Ausblick, Stundenauflösung, „bestes Fenster"-Hervorhebung.

#### F2 — Legal-Check (Karte mit Geo-Zonen)
Kartenansicht mit EU-/nationalen Geo-Zonen. Tap auf einen Punkt → Klartext-Antwort: **„Erlaubt"**, **„Erlaubt mit Auflagen: …"** oder **„Verboten: …"** — abgestimmt auf die Drohnenklasse des Nutzers (C0, < 250 g), inklusive Quellenangabe und Stand der Daten.

- **Löst:** P2 (Rechtsunsicherheit)
- **Begründung:** Rechtssicherheit ist für alle drei Personas ein Blocker. Eine App, die Flüge empfiehlt, ohne die Legalität zu prüfen, wäre unverantwortlich — Score und Legal-Check sind untrennbar.
- **Umfang MVP:** Deutschland + Österreich + Schweiz vollständig; klare Kennzeichnung, wo keine Daten vorliegen. Lieber ehrliche Lücken als falsche Sicherheit.
- **Scope-Ergänzung (Product-Owner-Entscheidung, 07/2026):** Kanada als erstes Reiseland — Nationalparks (Parks-Canada-Drohnenverbot, NRCan-CLSS-Daten) und Flughäfen mit Flugsicherung (Transport Canada) als Live-Abfrage; Luftraumklasse F, NOTAMs und Provinzparks als transparent gekennzeichnete, nicht prüfbare Zonentypen mit Verweis auf NAV Drone. Regelbasis: CARs Part IX (Mikrodrohnen < 250 g).
- **Scope-Ergänzung (07/2026, zweite Stufe):** Lufträume in Kanada (Kontrollzonen CTR, Class F CYR/CYD/CYA — das Zonenbild der NAV-Drone-Karte) über openAIP als Live-Abfrage auf Karte und im Legal-Check. Die NAV-Drone-Schnittstelle selbst ist login-pflichtig und scheidet aus; openAIP führt dieselben Lufträume aus den amtlichen AIPs und ist mit kostenlosem eigenem API-Schlüssel abfragbar (Bring-your-own-key wie bei den KI-Funktionen, Schlüssel nur in der Keychain, Lizenz CC BY-NC — private Nutzung). Ohne Schlüssel bleibt die Lücke ehrlich ausgewiesen.
- **Scope-Ergänzung (07/2026, dritte Stufe — Reisefestigkeit):** (a) **USA** als vollwertiger Rechtsraum über die offenen FAA-Dienste (UAS Facility Maps/LAANC-Grids mit Höhen-Obergrenze, Luftraumklassen, Special Use Airspace) und die NPS-Parkgrenzen — komplett ohne Schlüssel; New-York-City-Verbot als deterministische Regel; TFRs/State Parks/Stadien als ehrliche Lücke mit B4UFLY-Verweis. (b) **EU-Nachbarländer** (NL, BE, LU, FR, DK, CZ, PL, AT) als gemeinsamer Provider: harmonisierte EU-Basisregeln (Open A1/C0) plus redaktionelle Landes-Besonderheiten, Lufträume über openAIP, nationale Geozonen-Portale je Land als Gegenprüf-Hinweis (keine durchgängig offenen Schnittstellen — ehrliche Lücke). (c) **Nationale Geozonen direkt in der App** (Nutzerfeedback: kein Verweis auf externe Portale), wo amtliche offene Dienste existieren: Niederlande (Natura 2000 via PDOK), Frankreich (DGAC-Restriktionskarte via IGN), Luxemburg (amtliche ED-269-Geozonen). BE/DK/CZ/PL/AT bleiben Portal-Verweis, bis offene Dienste verfügbar sind. (d) **Kanada zweite Stufe** (gleicher Nutzerwunsch): Waldbrand-Sperrzonen live aus den CWFIS-Satelliten-Hotspots von NRCan (9,3-km-Regel, CARs 601.15), Ontario-Provinzparks vom offenen LIO-Dienst der Provinz, kleine Flugplätze/Heliports über openAIP (3-NM-/1-NM-Hinweis) — im Legal-Check und als Karten-Overlays. Verbleibende ehrliche Lücken: NOTAMs, Provinzparks außerhalb Ontarios. (e) **F4 zweite Stufe + Phase-0-Start (07/2026):** Hintergrund-Aktualisierung der Benachrichtigungen per BGAppRefresh (on-device, iOS bestimmt die Laufzeitpunkte; Widget vom Product Owner bewusst abgelehnt) und Score-Validierung als Ein-Tipp-Tagesrückmeldung im Heute-Tab (lokal, 90 Tage, manuelle Nachjustierung der Gewichte statt automatischem Lernen).

#### F3 — Licht- & Golden-Hour-Planung
Sonnenauf-/untergang, Golden Hour, blaue Stunde und Sonnenrichtung für jeden Spot — integriert in den Flight Score (gutes Licht hebt den Score, Mittagslicht senkt ihn).

- **Löst:** P3 (verpasstes Licht)
- **Begründung:** Das Produktziel ist „die bestmöglichen Luftaufnahmen", nicht „irgendein Flug". Licht ist der größte Hebel für Bildqualität und kostet in der Berechnung fast nichts — maximaler Nutzen pro Komplexität.

#### F4 — Gespeicherte Spots + eine tägliche Benachrichtigung
Nutzer speichern bis zu 3 Spots (Free-Tier). Die App prüft täglich die Bedingungen und sendet **maximal eine** Benachrichtigung, wenn ein außergewöhnlich gutes Fenster bevorsteht.

- **Löst:** P1 + P3 (proaktiv statt reaktiv)
- **Begründung:** Der magische Moment ist nicht, wenn der Nutzer die App öffnet — sondern wenn die App **ihn** anspricht: „Morgen früh ist es perfekt." Genau eine Benachrichtigung, streng kuratiert, weil Vertrauen in die Relevanz wichtiger ist als Engagement-Metriken.

#### Bewusst NICHT im MVP

| Ausgelassen | Warum |
|---|---|
| AI-Bildkritik | Hoher Wert, aber der Entscheidungs-Loop (F1–F4) muss zuerst sitzen. Kommt in V2 als klarer Neuigkeitswert. |
| Spot-Entdeckung / Community | Braucht kritische Masse; ohne Inhalte ein leeres Feature. V3. |
| Flug-Logbuch | „Nice to have", löst kein Top-Problem der Personas. |
| Android | Fokus. Eine Plattform exzellent statt zwei mittelmäßig. |
| Andere Drohnenmodelle | Präzision vor Breite. Ein Modellprofil, das stimmt, schlägt zwanzig geschätzte. |

### MVP-Erfolgskriterien

- **Aktivierung:** ≥ 60 % der Installationen schließen das Onboarding ab und sehen einen Flight Score.
- **Kernmetrik:** ≥ 35 % der wöchentlich aktiven Nutzer prüfen den Score vor einem realen Flug (Selbstauskunft + Nutzungsmuster Wochenende/Golden Hour).
- **Vertrauen:** < 1 % gemeldete Fehleinschätzungen bei Legal-Check-Antworten.
- **Retention:** ≥ 25 % Week-4-Retention (wetterabhängige Nutzung eingerechnet).

---

## 7. Version 2

**Thema von V2: Der Loop schließt sich — aus Fliegen wird Lernen.**

V2 baut ausschließlich Funktionen, die den MVP-Loop vertiefen. Keine neuen Zielgruppen, keine Plattform-Expansion.

### F5 — AI-Bildkritik („Flight Review")
Nutzer wählt nach dem Flug 5–10 Aufnahmen aus. Die AI bewertet jede Aufnahme entlang fester fotografischer Kriterien (Komposition, Horizont, Licht, Perspektive/Höhe, Motiv-Isolation) und liefert **pro Bild genau einen priorisierten Verbesserungsvorschlag** in verständlicher Sprache.

- **Löst:** P4 (kein Feedback-Loop)
- **Begründung:** Das ist die Funktion, die aus einem Planungstool einen *Copiloten* macht. Sie differenziert FlightMate von jeder Wetter- und Karten-App — und sie erzeugt den Grund, nach jedem Flug zurückzukehren.
- **Apple-Prinzip:** Ein Vorschlag pro Bild, nicht zehn. Kritik, die man umsetzen kann, statt einer Analyse, die man wegklickt.

### F6 — Shot-Vorschläge im Briefing
Vor dem Flug schlägt die App 2–3 konkrete Bildideen vor, abgeleitet aus Ortstyp (See, Wald, Küste, Stadt-Rand), Lichtrichtung und den Schwächen aus vergangenen Flight Reviews („Du fliegst oft zu hoch — versuch heute 30 m mit Vordergrund").

- **Löst:** P4 + P3
- **Begründung:** Verbindet Vorher und Nachher zu einem Lernsystem. Erst mit F5 sinnvoll möglich — deshalb V2, nicht MVP.

### F7 — Erweiterte Modellunterstützung (alle DJI-Consumer-Drohnen)
Air- und Mavic-Serie mit eigenen Wind-/Kameraprofilen.

- **Begründung:** Erste kontrollierte Verbreiterung, nachdem das Mini-Profil bewiesen hat, dass modellspezifische Empfehlungen funktionieren. Geringe Zusatzkomplexität (Profildaten), großer Marktzuwachs.

### F8 — Legal-Check-Ausbau EU
Vollständige Abdeckung der wichtigsten EU-Reiseländer (FR, IT, ES, PT, NL, SK, HR, GR).

- **Löst:** P2 für Reisende (Persona Lena)
- **Begründung:** Reise-Nutzung ist der häufigste Kontext, in dem selbst erfahrene Piloten rechtlich unsicher sind — und ein starker Premium-Kaufgrund.

---

## 8. Version 3

**Thema von V3: Vom Werkzeug zum Wissensnetz — Orte, Community, alle Drohnen.**

### F9 — Spot-Entdeckung
Kuratierte, drohnentaugliche Foto-Locations: legal geprüft, mit Startplatz-Hinweis, bester Tageszeit/Jahreszeit und Beispiel-Blickrichtungen. Quellen: redaktionelle Kuration + anonymisierte, aggregierte Community-Daten (Opt-in).

- **Löst:** P5 (Spots sind Zufallsfunde)
- **Begründung:** Erst jetzt sinnvoll: Es braucht eine aktive Nutzerbasis (Daten) und den etablierten Legal-Check (jeder Spot ist geprüft, nicht nur „schön"). Ein Spot-Feature ohne Legal-Garantie wäre ein Instagram-Klon — mit ihr ist es einzigartig.
- **Apple-Prinzip:** Kuration statt offenem User-Generated-Content-Strom. Qualität vor Menge; keine Likes, keine Feeds, kein Social-Druck.
- **Scope-Ergänzung (Product-Owner-Entscheidung, 07/2026):** Erste Ausbaustufe vorgezogen — datengetrieben statt redaktionell: Foto-Orte (Aussichtspunkte, Gipfel, Wasserfälle, Burgen, Leuchttürme) kommen aus OpenStreetMap; jeder Kandidat wird beim Öffnen automatisch mit dem echten Legal-Check und dem Flight Score geprüft. Redaktionelle Kuration und Community-Daten bleiben die spätere V3-Ausbaustufe.

### F10 — Herstellerübergreifende Unterstützung
Offenes Drohnenprofil-System (Autel, Potensic, weitere): Gewichtsklasse, Windtoleranz, Kameradaten. Nutzer wählen ihr Modell aus einem gepflegten Katalog.

- **Begründung:** Erfüllt die Mission („später alle Drohnen") auf dem bewährten Fundament. Die Architektur ist von Tag 1 modellagnostisch (siehe Kap. 10), V3 öffnet nur den Katalog.

### F11 — Saison- & Ereignisfenster
Proaktive Hinweise auf seltene fotografische Gelegenheiten an gespeicherten Spots: Nebellagen im Herbst, Schneefall, Rapsblüte, außergewöhnliche Sonnenstände (Alignments).

- **Löst:** P3 in seiner wertvollsten Form (seltene Fenster)
- **Begründung:** Die höchste Stufe des Kernversprechens: Die App kennt den Spot, das Wetter und die Jahreszeit — und meldet sich genau dann, wenn ein Bild möglich ist, das es nur wenige Male im Jahr gibt.

### F12 — iPad-Version
Große Karten- und Planungsansicht für die Vorbereitung zu Hause.

- **Begründung:** Lena und ambitionierte Planer arbeiten am großen Bildschirm. Kein neues Feature-Set — dieselbe App, besseres Planungs-Canvas.
- **Scope-Ergänzung (Product-Owner-Entscheidung, 07/2026):** Teilweise vorgezogen — die App läuft bereits ab MVP nativ und bildschirmfüllend auf dem iPad (Lesebreiten-Layout, Karte in Vollbild). Das erweiterte Planungs-Canvas (Split-View Karte + Ausblick) bleibt V3.

---

## 9. Nicht-Ziele

Nicht-Ziele sind verbindlich. Sie schützen das Produkt vor Feature-Bloat und die Nutzer vor einem verwässerten Versprechen.

| # | Nicht-Ziel | Begründung |
|---|---|---|
| N1 | **Keine Drohnensteuerung.** Keine Verbindung zur Drohne, kein Livestream, keine Missionsplanung mit Wegpunkten. | Sicherheits- und Haftungsrisiko, SDK-Abhängigkeit von DJI, direkter Wettbewerb zu DJI Fly. Der Copilot fliegt nicht selbst. |
| N2 | **Kein Social Network.** Keine Profile-Feeds, Likes, Follower, Kommentare. | Social-Mechaniken optimieren auf Aufmerksamkeit, nicht auf bessere Bilder. Community-Daten fließen nur kuratiert und anonymisiert in Spots (F9) ein. |
| N3 | **Keine Rechtsberatung.** Die App liefert Geo-Daten und Regelwerke mit Quellen, aber keine verbindliche Rechtsauskunft. | Haftungsgrenze. Wird in der App transparent kommuniziert („Angaben ohne Gewähr, verbindlich ist die zuständige Behörde"). |
| N4 | **Kein Bildbearbeitungs-Editor.** Keine Filter, kein RAW-Entwickler. | Lightroom & Co. lösen das besser. FlightMate sagt, *was* am Bild besser sein könnte — nicht *macht* es besser. |
| N5 | **Kein Enterprise-/Behördenprodukt.** Keine Compliance-Dokumentation, keine Flottenverwaltung, keine SORA-Anträge. | Anderes Produkt, andere Kaufprozesse, andere UX. Würde die Consumer-Klarheit zerstören. |
| N6 | **Kein Android im ersten Jahr.** | Fokus auf eine exzellente iOS-App. Entscheidung wird nach V2 anhand der Nachfrage neu bewertet. |
| N7 | **Keine Gamification.** Keine Abzeichen, Streaks, Punkte. | Der Anreiz ist das bessere Bild, nicht die App-Nutzung. Streaks würden zum Fliegen bei schlechten Bedingungen verleiten — das Gegenteil der Mission. |

---

## 10. Technische Anforderungen

### Architekturprinzipien

1. **iOS-nativ:** Swift + SwiftUI, Zielversion iOS 17+. Begründung: Systemintegration (WeatherKit, MapKit, Widgets, Push), Performance und das Qualitätsniveau, das die Zielgruppe von einer „Apple-artigen" App erwartet.
2. **Modellagnostischer Kern von Tag 1:** Drohnenprofile (Gewicht, Klasse, Windtoleranz, Kamera) sind Daten, kein Code. Das MVP shipped mit drei Profilen; V3 öffnet den Katalog ohne Architekturänderung.
3. **Offline-first für den kritischen Pfad:** Am Spot gibt es oft kein Netz. Legal-Zonen der Region, letztes Wetter-Briefing und Sonnendaten werden lokal gecacht. Der Pre-Flight-Check muss offline funktionieren (mit sichtbarem Datenstand).
4. **Dünner Server, dicker Client:** Das Backend aggregiert und cached Datenquellen (Wetter, Geo-Zonen) und hostet die AI-Endpunkte. Keine Nutzerinhalte auf dem Server, solange nicht zwingend nötig (siehe Datenschutz).

### Systemkomponenten

| Komponente | Technologie / Quelle | Anmerkung |
|---|---|---|
| App | Swift, SwiftUI, iOS 17+ | iPhone zuerst, iPad in V3 |
| Wetter | Apple WeatherKit + spezialisierte Höhenwind-Quelle (z. B. Open-Meteo-Windprofile) | Höhenwind (50–120 m) ist Pflicht — Bodenwind allein ist für Drohnen irreführend |
| Sonnen-/Lichtberechnung | Lokale Berechnung on-device (Astronomie-Bibliothek) | Kein Netzwerk nötig, deterministisch |
| Geo-Zonen | Nationale UAS-Geo-Zonen-Datensätze (DE: dipul; AT/CH: nationale Quellen), normalisiert im Backend | Versionierte Datensätze mit Stands-Datum; Anzeige der Quelle in der App |
| Karten | Apple MapKit | Satellitendarstellung für Spot-Planung |
| Flight-Score-Engine | On-device-Regelwerk (deterministisch) | Kein LLM für den Score — Nachvollziehbarkeit und Offline-Fähigkeit (siehe Kap. 12) |
| AI-Dienste | Claude API (Bildkritik, Shot-Vorschläge, Regel-Klartext) über eigenes Backend | Kein Direktzugriff der App auf den AI-Anbieter; API-Schlüssel bleiben serverseitig |
| Benachrichtigungen | APNs + serverseitiger Bedingungs-Scheduler | Max. 1 Benachrichtigung/Tag, serverseitig durchgesetzt |
| Accounts/Abo | Sign in with Apple (optional), StoreKit 2 | Kernfunktion ohne Account nutzbar |

### Nichtfunktionale Anforderungen

- **Kaltstart bis Flight Score:** < 2 s bei bestehendem Cache.
- **Legal-Check-Datenaktualität:** Zonen-Datensätze maximal 24 h alt; jede Antwort trägt sichtbar ihr Stands-Datum.
- **Verfügbarkeit Backend:** 99,5 %; bei Ausfall degradiert die App sichtbar auf gecachte Daten statt zu raten.
- **Batterie/Standort:** Kein dauerhaftes GPS-Tracking. Standort nur bei aktiver Nutzung („While Using").
- **Barrierefreiheit:** Dynamic Type, VoiceOver für alle Kern-Screens, keine rein farbcodierten Statusanzeigen (Score zusätzlich numerisch/textlich).

---

## 11. Datenschutz

Datenschutz ist ein Produktmerkmal, kein Compliance-Anhang. Zielgruppe und Rechtsraum (EU/DSGVO) verlangen es; das Vertrauensversprechen der App (Kap. 1) setzt es voraus.

### Grundsätze

1. **Datenminimierung:** Die App funktioniert im Kern ohne Account, ohne E-Mail, ohne Werbe-IDs. Es wird nur erhoben, was eine Funktion unmittelbar braucht.
2. **On-Device zuerst:** Sonnenberechnung, Flight-Score-Regelwerk und Caches laufen lokal. Standortkoordinaten verlassen das Gerät nur zur Abfrage von Wetter/Geo-Zonen — und werden dafür auf die nötige Genauigkeit reduziert (gerundete Koordinaten für Wetter).
3. **Fotos bleiben beim Nutzer:** Für die AI-Bildkritik (V2) wählt der Nutzer Bilder explizit einzeln aus (PhotosPicker, kein Vollzugriff auf die Mediathek). Bilder werden zur Analyse übertragen, **nicht gespeichert** und **nicht für Training verwendet**; Verarbeitung über Anbieter mit vertraglicher No-Training-Zusage. Löschung nach Analyse, dokumentiert in der Datenschutzerklärung.
4. **Keine Bewegungsprofile:** Gespeicherte Spots liegen lokal (bzw. verschlüsselt in iCloud des Nutzers via CloudKit, wenn Sync gewünscht). Der Server kennt keine dauerhafte Verknüpfung Nutzer ↔ Orte.
5. **Kein Tracking, keine Datenweitergabe:** Keine Third-Party-Ad-SDKs. Analytics nur aggregiert und opt-out-fähig (privacy-freundliches Tool, EU-Hosting).

### Konkrete Zusagen (App-Store-Privacy-Label-tauglich)

| Datum | Zweck | Speicherort | Dauer |
|---|---|---|---|
| Standort (bei Nutzung) | Wetter, Score, Legal-Check | Gerät; Server nur transient | Nicht serverseitig gespeichert |
| Drohnenmodell | Profilgewichtung | Gerät / iCloud (Nutzer) | Bis Löschung durch Nutzer |
| Gespeicherte Spots | Benachrichtigungen, Planung | Gerät / iCloud (Nutzer); Server pseudonymisiert nur für Benachrichtigungs-Scheduler | Bis Löschung durch Nutzer |
| Ausgewählte Fotos (V2) | AI-Bildkritik | Transient auf AI-Endpunkt | Löschung nach Analyse |
| Abo-Status | Feature-Freischaltung | StoreKit/Apple | Gemäß Apple |

### DSGVO-Pflichten

- Rechtsgrundlagen je Verarbeitung dokumentiert (Art. 6 Abs. 1 lit. b für Kernfunktion, lit. a für Foto-Analyse und Benachrichtigungen).
- Auftragsverarbeitungsverträge mit allen Prozessoren (Wetter-, AI-, Hosting-Anbieter); EU-Hosting für das Backend.
- Export und Löschung aller Nutzerdaten direkt in der App (kein E-Mail-Support-Umweg).

---

## 12. AI-Funktionen

**Grundsatz:** AI wird nur eingesetzt, wo sie ein Nutzerproblem besser löst als deterministische Logik — und niemals dort, wo Nachvollziehbarkeit sicherheits- oder rechtsrelevant ist.

**Scope-Ergänzung (Product-Owner-Entscheidung, 07/2026):** Für das persönliche MVP werden F5 (Bildkritik) und F6 (Shot-Vorschläge) ohne Backend umgesetzt: Der Nutzer hinterlegt seinen eigenen Anthropic-API-Schlüssel in der App (Keychain, nur auf dem Gerät); die App ruft die Claude-API direkt auf. Für einen öffentlichen Release gilt weiterhin die Architektur aus Kap. 10 (Server-Proxy, Schlüssel serverseitig).

### Wo bewusst KEINE generative AI eingesetzt wird

| Bereich | Warum deterministisch |
|---|---|
| **Flight Score** | Sicherheitsrelevant. Ein Regelwerk aus Windtoleranzen, Schwellwerten und Lichtkurven ist erklärbar („Score 4, weil Böen 32 km/h > 70 % deiner Windtoleranz"), testbar, offline-fähig und halluziniert nicht. |
| **Legal-Check-Entscheidung** | Rechtsrelevant. Die Antwort „erlaubt/verboten" kommt ausschließlich aus versionierten Geo-Daten + Regelwerk. Ein LLM darf hier formulieren, aber nie entscheiden. |

### AI-Funktion 1 — Bildkritik „Flight Review" (V2)

- **Problem:** P4 — kein Feedback nach dem Flug.
- **Umsetzung:** Vision-fähiges Modell (Claude) bewertet ausgewählte Aufnahmen entlang eines festen Kriterienkatalogs (Komposition/Drittel, Horizontlage, Lichtnutzung, Flughöhe/Perspektive, Motiv-Klarheit). Output ist strukturiert: Stärken (max. 2), **ein** priorisierter Verbesserungsvorschlag, Konfidenz.
- **Leitplanken:** Kein Urteil über künstlerischen Geschmack als „falsch"; Ton ist der eines wohlwollenden Mentors. Bewertungs-Rubrik ist versioniert und wird mit Referenzbildern getestet, damit Kritik konsistent bleibt.

### AI-Funktion 2 — Shot-Vorschläge (V2)

- **Problem:** P3/P4 — Nutzer wissen nicht, *was* sie bei diesem Licht an diesem Ort aufnehmen sollen.
- **Umsetzung:** LLM generiert 2–3 Bildideen aus strukturiertem Kontext (Ortstyp, Lichtrichtung/-zeit, Wind, frühere Kritikpunkte des Nutzers). Vorschläge sind konkret und ausführbar („30 m Höhe, Kamera 20° geneigt, Sonne im Rücken, Steg als Führungslinie").
- **Leitplanken:** Vorschläge respektieren immer die legalen Grenzen des Spots (max. Höhe aus dem Legal-Check wird als harte Bedingung übergeben). Kein Vorschlag darf zu regelwidrigem Fliegen anleiten — das prüft eine nachgelagerte Regel-Schicht, nicht das LLM allein.

### AI-Funktion 3 — Regel-Klartext (MVP, eng begrenzt)

- **Problem:** P2 — Verordnungssprache ist unverständlich.
- **Umsetzung:** Vorab generierte und **redaktionell geprüfte** Klartext-Erklärungen der Zonen-Typen und Auflagen („Kontrollzone: Du darfst hier bis 50 m fliegen, weil…"). Generierung offline im Redaktionsprozess, nicht live — die App zeigt nur geprüfte Texte.
- **Begründung:** Nutzt AI-Stärke (Verständlichkeit) ohne Live-Halluzinationsrisiko in einem rechtsnahen Bereich.

### AI-Funktion 4 — Ereignisfenster-Erkennung (V3)

- **Problem:** P3 — seltene fotografische Gelegenheiten werden verpasst.
- **Umsetzung:** Muster-Erkennung auf Wetter-/Saisondaten (Nebelwahrscheinlichkeit, Schneefall, Blühphasen) kombiniert mit LLM-formulierten, kontextuellen Hinweisen.

### Qualitätssicherung für alle AI-Funktionen

- Golden-Set-Evaluierung vor jedem Modell- oder Prompt-Update (Referenzbilder mit Soll-Kritiken, Soll-Vorschläge pro Spot-Typ).
- Nutzer-Feedback pro AI-Output („hilfreich / nicht hilfreich") fließt in die Rubrik-Iteration, nicht ins Modelltraining.
- Alle AI-Ausgaben sind als solche gekennzeichnet.

---

## 13. Monetarisierung

### Modell: Freemium mit einem einzigen Abo („FlightMate Pro")

**Begründung der Modellwahl:**

- **Kein Werbemodell:** Werbung zerstört das Vertrauens- und Fokusversprechen (und wäre mit dem Datenschutzkapitel unvereinbar).
- **Kein Einmalkauf:** Laufende Kosten (Wetterdaten, Geo-Daten-Pflege, AI-Inferenz, Backend) erfordern wiederkehrende Einnahmen; ein Einmalkauf erzwänge langfristig Feature-Bloat für Upgrade-Verkäufe.
- **Ein einziges Abo, keine Staffeln:** Zwei oder drei Tiers erzeugen Entscheidungslast und verwässern das Wertversprechen. Eine Grenze, ein Preis, sofort verständlich — Apple-Prinzip.

### Free (dauerhaft kostenlos)

- Flight Score für den aktuellen Standort (heute + morgen)
- Legal-Check (vollumfänglich — **Sicherheitsinformationen werden nie paywalled**)
- Sonnen-/Golden-Hour-Zeiten
- 1 gespeicherter Spot

*Begründung: Free muss das Kernversprechen erlebbar machen (sonst keine Konversion) und darf sicherheitsrelevante Informationen nicht zurückhalten (sonst kein Vertrauen — und ein ethisches Problem).*

### FlightMate Pro — ca. 4,99 €/Monat oder 39,99 €/Jahr

- 7-Tage-Score-Ausblick mit „bestes Fenster der Woche"
- Unbegrenzte Spots + proaktive Benachrichtigungen
- AI-Bildkritik und Shot-Vorschläge (ab V2)
- EU-weiter Legal-Check auf Reisen (ab V2)
- Saison-/Ereignisfenster (ab V3)

*Preislogik: Unter der Schwelle eines Streaming-Abos; der Jahrespreis (~2 Flugakkus) ist gegen die realen Kosten eines einzigen umsonst gefahrenen Foto-Ausflugs leicht zu rechtfertigen. AI-Inferenzkosten werden durch das Abo gedeckt; Free enthält bewusst keine laufenden AI-Kosten.*

### Geschäftsziele (erste 18 Monate)

- Free→Pro-Konversion: 4–6 % (Benchmark für Utility-Apps mit starkem Free-Tier)
- Jahresabo-Anteil: > 60 % der Pro-Nutzer (Preisgestaltung incentiviert Jahrespreis)
- Churn Pro: < 4 %/Monat (Saisonalität Winter einkalkuliert; Ereignisfenster in V3 wirken gezielt gegen Winter-Churn)

---

## 14. Risiken

| # | Risiko | Wahrscheinlichkeit | Auswirkung | Gegenmaßnahme |
|---|---|---|---|---|
| R1 | **Fehlerhafte Legal-Daten** führen zu einem Verstoß eines Nutzers | Mittel | Sehr hoch (Vertrauen, Haftung, Presse) | Versionierte amtliche Quellen, tägliche Aktualisierung, sichtbares Stands-Datum, konservative Auslegung bei Unklarheit, klare Gewährleistungsgrenze (N3), Meldefunktion für Nutzer |
| R2 | **Wetter-/Windprognose falsch**, Nutzer verliert Vertrauen in den Score | Mittel | Hoch | Mehrere Datenquellen, Konfidenz-Anzeige („Prognose unsicher"), Score konservativ gewichten, Erwartungsmanagement in der UI (Prognose ≠ Garantie) |
| R3 | **DJI oder Apple baut die Kernfunktion nach** (Score/Briefing in DJI Fly, Wetter-Features in iOS) | Mittel | Hoch | Differenzierung über den Lern-Loop (Bildkritik + Historie + Spots) — Daten und Beziehung zum Nutzer sind schwer kopierbar; Geschwindigkeit bei V2 |
| R4 | **Saisonalität:** Nutzung und Abos brechen im Winter ein | Hoch | Mittel | Jahresabo-Incentive, Winter-Content (Nebel-/Schnee-Ereignisfenster in V3), Planungs-Features die auch bei Nichtflug-Wetter Wert bieten |
| R5 | **AI-Kritik wirkt beliebig oder verletzend**, Feature wird abgelehnt | Mittel | Mittel | Feste Rubrik, Golden-Set-Tests, Mentor-Tonalität, „ein Vorschlag pro Bild", Feedback-Schleife, schneller Kill-Switch pro AI-Feature |
| R6 | **AI-Inferenzkosten** übersteigen Abo-Marge bei Power-Usern | Niedrig–Mittel | Mittel | Bildanzahl pro Review begrenzt (Produktentscheidung, keine versteckte Quote), Modellwahl nach Kosten/Qualität, Caching von Shot-Vorschlägen pro Spot/Licht-Kombination |
| R7 | **Regulatorische Änderungen** (EU-Drohnenrecht) machen Datenmodell obsolet | Niedrig | Mittel | Regelwerk als versionierte Daten, nicht hartkodiert; Monitoring der EASA-Änderungen als fester Prozess |
| R8 | **App-Store-Konkurrenz durch Feature-Bloat-Apps** (UAV Forecast u. a.) mit mehr „Häkchen" | Hoch | Niedrig–Mittel | Nicht auf Feature-Listen konkurrieren, sondern auf Verständlichkeit und Ergebnisqualität; Bewertungen/Empfehlungen als Kanal; Nicht-Ziele diszipliniert halten |
| R9 | **Kritische Datenquelle fällt aus oder ändert Konditionen** (Wetter-API, Geo-Daten) | Niedrig | Hoch | Abstraktionsschicht über allen Quellen, mindestens eine Fallback-Quelle pro Datentyp, vertragliche Absicherung vor Launch |

---

## 15. Roadmap

Die Roadmap ist thematisch geschnitten: **Entscheiden (MVP) → Lernen (V2) → Entdecken (V3).** Zeiträume sind Planungsgrößen, keine Zusagen; Qualitätskriterien (Kap. 6) gaten jeden Release.

### Phase 0 — Fundament (Monate 1–3)

- Datenpipelines: Wetter/Höhenwind, Geo-Zonen DACH (Normalisierung, Versionierung)
- Flight-Score-Engine inkl. Validierung gegen reale Flugtage (Beta-Piloten-Gruppe, ≥ 30 Piloten)
- App-Grundgerüst, Onboarding, Karten-Integration
- **Meilenstein:** Interner Prototyp sagt für 10 Testspots verlässlich „gutes/schlechtes Fenster" voraus

### Phase 1 — MVP-Launch (Monate 4–6)

- F1 Flight Score, F2 Legal-Check DACH, F3 Lichtplanung, F4 Spots + Benachrichtigung
- Closed Beta (TestFlight, ~200 Nutzer aus Drohnen-Communities) → öffentlicher Launch DACH
- **Meilenstein:** App Store Launch; Aktivierung ≥ 60 %, Legal-Check-Fehlerrate < 1 %

### Phase 2 — Lern-Loop / V2 (Monate 7–12)

- F5 AI-Bildkritik (Monat 7–9, inkl. Golden-Set-Aufbau)
- F6 Shot-Vorschläge (Monat 9–10)
- F7 DJI-Gesamtkatalog, F8 Legal-Check EU-Reiseländer (Monat 10–12)
- Pro-Abo-Optimierung auf Basis realer Konversionsdaten
- **Meilenstein:** Week-4-Retention ≥ 30 %; ≥ 40 % der Pro-Nutzer nutzen die Bildkritik monatlich

### Phase 3 — Entdecken / V3 (Monate 13–18)

- F9 Spot-Entdeckung (Kuration DACH zuerst)
- F11 Saison-/Ereignisfenster (rechtzeitig zur Nebelsaison Herbst)
- F10 herstellerübergreifende Profile, F12 iPad
- **Meilenstein:** ≥ 500 kuratierte Spots; Winter-Churn gegenüber Vorjahr messbar reduziert

### Laufend (alle Phasen)

- Wöchentliche Aktualisierungs-/Qualitätsprüfung der Geo-Daten
- Monatliche Auswertung: Score-Prognose vs. reale Bedingungen (Prognosegüte als interne Kernmetrik)
- Vierteljährliches Nicht-Ziele-Review: Jede Feature-Idee wird gegen Kap. 9 geprüft — Standardantwort ist „Nein"

---

*Ende des Dokuments. Änderungen an diesem PRD erfordern eine Begründung entlang der Produktprinzipien in Kapitel 1.*
