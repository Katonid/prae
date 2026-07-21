# 🍁 Canada 2026 – native iOS-App

Native Neuentwicklung der Canada-2026-PWA (`https://jerosch.net/apps/canada-2026`)
für iPhone und iPad – geschrieben in Swift und SwiftUI, **ohne Firebase**.
Die Synchronisation zwischen allen Geräten läuft über **iCloud / CloudKit**,
also über die Apple-Infrastruktur, die mit dem Apple-Developer-Konto für
TestFlight ohnehin vorhanden ist. Es wird kein eigener Server und kein
Drittanbieter-Backend benötigt.

## Benutzerkonten & Rollen

Wie in der PWA gibt es zwei Ebenen:

| Rolle | Wer | Rechte |
|---|---|---|
| **Admin** | Andreas | Vollzugriff + Zugangscodes verwalten |
| **STAN on Tour (Crew)** | Andreas, Nadine, Simon, Tobias | Vollzugriff auf alle Bereiche |
| **Familie** (Betrachter) | beliebig viele, per Name + Code | Mitlesen: Journal, Fotos, Karte, Reiseplan, Flüge – plus Bingo/Challenges ansehen und Nachrichten schreiben |
| **Begleiter** (Betrachter) | beliebig viele, per Name + Code | Wie Familie, aber ohne Bingo und Challenges |

Die Anmeldung erfolgt beim ersten Start über Name/Mitglied + Zugangscode.

**Persönliche Einladungscodes aus der Web-App funktionieren direkt:**
Codes im PWA-Format `CANADA2026-XXXX-XXXX` werden erkannt, das Mitglieds-Kürzel
im zweiten Block (`ANDR`, `NADI`, `SIMO`, `TOBI`) bestimmt automatisch das
Crew-Mitglied – z. B. meldet `CANADA2026-ANDR-EA26` direkt Andreas an.
Der Admin kann in den Einstellungen pro Mitglied einen festen Code hinterlegen;
dann zählt für dieses Mitglied nur noch genau dieser Code.

Zusätzliche Standard-Codes (vom Admin änderbar, Verteilung über iCloud):

- Crew (gemeinsam, mit Mitglieder-Auswahl): `AHORN26`
- Familie: `FAMILIE26`
- Begleiter: `BEGLEITER26`

## Funktionsumfang

- **Start:** Tageszentrum mit Countdown/Reisetag, aktueller Station, Tagesfrage,
  neuen Nachrichten, neuestem Foto und Aktivitäts-Feed – eigene Variante für Betrachter
- **Reiseplan:** alle Stationen (Toronto, Niagara Falls, Picton, Kingston,
  Thousand Islands, Ottawa, Gatineau) mit Notizen, Aufgaben (synchronisierte
  Häkchen) und allen Google-Maps-Links aus der PWA
- **Karte & Route:** MapKit-Karte mit Stationsroute und gemeinsamer
  **Reise-Spur** – Crew-Mitglieder teilen ihren Standort per Knopfdruck
- **Nachrichten:** Gruppenchat mit den Kanälen „STAN Crew" (nur Crew) und
  „Alle zusammen" (Crew + Familie + Begleiter), Ungelesen-Badge, löschbar
- **Journal:** Reisetagebuch pro Tag mit Stimmung und Station, Betrachter lesen mit
- **Fotoalbum:** gemeinsames Album; Bilder werden verkleinert (max. 1600 px),
  lokal gespeichert und als CloudKit-Asset an alle Geräte verteilt
- **Kosten:** Ausgaben in CAD mit EUR-Umrechnung (Kurs 0,67), Kategorien und
  Auswertung pro Mitglied (nur Crew)
- **Checklisten:** Dokumente (Pässe, eTA, ESTA, …) und Stations-Aufgaben mit
  synchronisierten Häkchen inklusive „erledigt von"
- **Flüge:** LH240 (FRA → YYZ) und LH6779 (YYZ → FRA) mit allen Status-,
  Check-in- und Flightradar-Links
- **Wetter:** Open-Meteo-Vorhersage je Reiseort mit den Tagesabschnitten
  Vormittag/Nachmittag/Abend/Nacht (wie die PWA, 45-Minuten-Cache)
- **Fotospots:** alle 54 kuratierten Fotospots der PWA mit Region-Filter,
  Karte, bester Uhrzeit, Tipps und Google-Maps-Links
- **Heute in der Nähe:** Live-Suche über die Overpass-API (OpenStreetMap) im
  3-km-Umkreis – Parken, Essen, Cafés, Supermärkte, Shopping, Tankstellen –
  um den eigenen Standort oder eine Station
- **Interessantes:** die 22 kuratierten Orte passend zu den Crew-Interessen
  (Sneaker, Sport, Technik, Shopping …) mit Interessen-Filter
- **Canada Awards:** tägliche Abstimmungen in den sechs Kategorien der PWA
  (Bestes Foto des Tages, Tagesheld, …) mit Live-Ergebnissen und Tagessiegern
- **Canada Bingo:** alle 50 Bingo-Felder in 10 Kategorien, pro Crew-Mitglied
- **Roadtrip Challenges:** alle 40 Challenges pro Station, pro Crew-Mitglied
- **STAN Roadbook:** Reisebuch als PDF (Deckblatt, Route, Journal, Fotoalbum,
  Awards, Statistik) mit wählbaren Inhalten, plus JSON-Rohdaten-Export
- **Score & Erfolge:** Rangliste und die 10 Achievements der PWA
  (Tierbeobachter, Kanada-Profi, Roadtrip Champion, …), automatisch berechnet
- **Bucket List:** gemeinsame Wunschliste inkl. der Standard-Einträge, mit
  Stimmen („Dafür stimmen") und Foto-Verknüpfung aus dem Album wie in der PWA
- **Tagesfrage:** Frage des Tages stellen (mit den PWA-Vorlagen) und von allen
  beantworten lassen
- **Soundtrack:** gemeinsame Songliste mit Musik-Links
- **Hinweise:** Aktivitäts-/Hinweisliste (neue Nachrichten, Fotos, Journal-Einträge)
- **Einstellungen:** Profilwechsel, Zugangscodes (Admin), Einladungen als
  QR-Code, Sync-Diagnose, JSON-Backup-Export
- **Reise-Infos:** Einreise, Geld, Unterwegs, Gesundheit

## Synchronisation ohne Firebase

- Alle Inhalte liegen als generische Records vom Typ `Entity` in der
  **öffentlichen CloudKit-Datenbank** des App-Containers
  (`kind`, `entityId`, `payload` als JSON, `updatedAtMs`, `author`, optional `asset`).
- **Offline-first:** Alles wird zuerst lokal gespeichert (JSON im
  Documents-Ordner); Änderungen wandern in eine persistierte Outbox und werden
  hochgeladen, sobald Netz da ist.
- Konflikte werden per Last-Writer-Wins über den Zeitstempel aufgelöst.
- Eine CloudKit-Subscription schickt stille Pushes, sodass neue Inhalte
  automatisch ankommen; zusätzlich wird bei jedem App-Start/Aktivieren gesynct.
- Voraussetzung pro Gerät: ein angemeldetes iCloud-Konto (jedes beliebige –
  die Nutzer brauchen **keine** gemeinsame Apple-ID).

Hinweis zur Zugriffskontrolle: Die Rollen werden in der App durchgesetzt
(wie auch in der PWA weitgehend clientseitig). Die öffentliche
CloudKit-Datenbank ist für alle Installationen der App les- und schreibbar –
für eine private Familien-App mit TestFlight-Einladungen ist das der
passende, unkomplizierte Kompromiss.

## Projekt öffnen und auf TestFlight bringen

Voraussetzungen: Mac mit Xcode 16+, Apple-Developer-Programm-Mitgliedschaft.

1. **Öffnen:** `Canada2026iOS/Canada2026.xcodeproj` in Xcode öffnen.
2. **Signing:** Target „Canada2026" → *Signing & Capabilities* → Team wählen.
   Bei Bedarf die Bundle-ID anpassen (Standard: `de.familie.canada2026`).
   Die Capabilities **iCloud (CloudKit)**, **Push Notifications** und
   **Background Modes → Remote notifications** sind über die Entitlements
   bereits eingetragen; Xcode legt den iCloud-Container
   `iCloud.de.familie.canada2026` beim ersten Signieren automatisch an.
   (Wenn du die Bundle-ID änderst, auch den Container-Namen in
   `Canada2026/Canada2026.entitlements` entsprechend anpassen.)
3. **Erster Testlauf:** App auf einem Gerät/Simulator mit iCloud-Konto starten
   und z. B. eine Nachricht senden. Dadurch legt CloudKit das Schema
   (Record-Typ `Entity`) in der **Development**-Umgebung automatisch an.
4. **Indexe anlegen:** [CloudKit Console](https://icloud.developer.apple.com)
   → Container → *Schema* → Record-Typ `Entity` → Feld `updatedAtMs` als
   **Queryable** und **Sortable** markieren (Development-Umgebung).
   Ohne diesen Index meldet die Sync-Diagnose einen entsprechenden Fehler.
5. **Schema deployen:** In der CloudKit Console *Deploy Schema Changes to
   Production* ausführen – TestFlight-Builds nutzen die Production-Umgebung.
6. **Archivieren:** In Xcode *Product → Archive*, dann im Organizer
   *Distribute App → App Store Connect → Upload*.
7. **TestFlight:** In App Store Connect die App anlegen (gleiche Bundle-ID),
   den Build unter *TestFlight* freigeben und Andreas, Nadine, Simon, Tobias
   sowie die Familien-/Begleiter-Tester per E-Mail einladen.
8. **Codes verteilen:** Beim ersten Start meldet sich jede Person mit ihrer
   Rolle und dem Zugangscode an (siehe oben). Andreas kann die Codes danach
   in den Einstellungen ändern.

## Technik

- Swift 5 / SwiftUI, Mindestversion iOS 17, iPhone + iPad
- Keine externen Abhängigkeiten: CloudKit (Sync), MapKit (Karte),
  CoreLocation (Reise-Spur), PhotosUI (Fotoauswahl)
- `Model/TravelData.swift` – statische Reisedaten, 1:1 aus `travelData.js`
  der PWA portiert (Stationen, Challenges, Bingo, Achievements, Flüge, …)
- `Model/Models.swift` – synchronisierbare Entitäten und Rollenmodell
- `Model/CloudSync.swift` – CloudKit-Engine (Outbox, Delta-Pull, Subscription)
- `Model/AppStore.swift` – zentraler Zustand, Persistenz, Rollen- und Punktelogik
- `Views/…` – alle Ansichten (Start, Reise, Journal, Nachrichten, STAN-Hub, …)

## Externe Dienste

Die App nutzt neben iCloud nur zwei freie, schlüssellose Dienste – dieselben
wie die PWA: **Open-Meteo** für das Wetter und die **Overpass-API**
(OpenStreetMap) für „Heute in der Nähe". Beide funktionieren ohne Konto und
ohne API-Key; fällt einer aus, bleibt der Rest der App voll nutzbar.

## Abdeckung gegenüber der PWA

Alle Funktionsbereiche der PWA sind nativ umgesetzt: Reiseplan, Karte und
Reise-Spur, Nachrichten, Journal, Fotoalbum, Kosten, Checklisten, Flüge,
Wetter, Fotospots, „Heute in der Nähe", Interessantes, Canada Bingo,
Roadtrip Challenges, Score & Erfolge, Canada Awards, Bucket List (inkl.
Stimmen und Foto-Verknüpfung), Tagesfrage, Soundtrack, Roadbook-PDF,
QR-Einladungen, Hinweise, Backup und die Benutzerkonten mit Admin-, Crew-
und den beiden Betrachter-Rollen. Nicht übernommen wurden nur rein
technische PWA-Interna ohne Nutzerfunktion (Service-Worker-/Cache-Verwaltung,
Firebase-Diagnosewerkzeuge, Performance-Overlays) – deren Rolle übernimmt
nativ die Sync-Diagnose.
