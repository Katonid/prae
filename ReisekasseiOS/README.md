# 💶 Kassenbuch — native iOS-App

**Name:** Die App heißt **„Kassenbuch"** — im App Store (der Eintrag in
App Store Connect), auf dem Homescreen und in allen Texten der App.
Der interne Projektname (Ordner `ReisekasseiOS/`, Target „Reisekasse",
Bundle-ID `de.familie.reisekasse`, iCloud-Container) bleibt unverändert —
er ist für Nutzer unsichtbar, und Bundle-ID/Container dürfen nach dem
ersten Signieren nicht mehr wechseln.

Ausgaben-Tracker für Reisen, ohne Abo und ohne Server: Swift/SwiftUI,
iOS 17+, keine externen Abhängigkeiten. Zahlungen mit **Apple Pay werden
automatisch erfasst** (Kurzbefehle-Automation „Transaktion"), inklusive
Zeit, Händler, Ort/Land und automatischer Kategorie. Synchronisation
zwischen allen Geräten und Mitreisenden läuft über **iCloud / CloudKit** —
dieselbe Technik wie in der Canada2026-App dieses Repos.

## Funktionsumfang

- **Einträge:** Tagesliste mit Kategorien-Icons, Budget-Karten „Gesamt"
  und „Heute" (Ausgegeben, Verbleibend/Budget, Fortschrittsbalken),
  Schnelleingabe in freier Sprache („pizza 13,5 bar" — Diktat über die
  Mikrofontaste der Tastatur) und Plus-Knopf für den vollen Editor.
- **Editor:** Betrag + Währung, Name, Notiz, Datum/Uhrzeit, „Auf Tage
  verteilen", Zahlungsmittel, **„Bezahlt von"** (Teilnehmer wählen oder
  beliebigen Namen eintragen — auch nachträglich änderbar), **Eintrag
  in eine andere Reise verschieben**, Land (mit Flagge), Ort mit
  Koordinaten (automatisch vom Standort), Foto anfügen, „Aus
  Tagesdurchschnitt ausschließen", „Zahlung zurückerstattet", Löschen.
- **Automatische Kategorien:** Stichwort-Klassifikator (deutsch/englisch,
  typische Händlernamen wie Tim Hortons, Uber, Loblaws …) schlägt beim
  Tippen und beim Apple-Pay-Import die Kategorie vor — jederzeit im
  Editor änderbar. Kategorien: Flüge, Transport, Unterkunft,
  Essen & Trinken, Lebensmittel, Shopping, Aktivitäten,
  Haushalt & Wohnen, Abos & Verträge, Gebühren, Gesundheit, Sonstiges
  — damit passt die App auch für Ausgaben daheim (Miete, Strom,
  Baumarkt, Streaming, Handyvertrag, Versicherungen).
- **Mehrere Listen (Reisen):** über den Titel wechseln, „Neue Reise ..."
  anlegen; je Reise Heimatwährung, Gesamt-/Tagesbudget, Zeitraum und
  editierbare Wechselkurse (z. B. 1 CAD = 0,67 EUR). Erste Reise
  „Kanada" wird beim ersten Start automatisch angelegt.
- **Statistiken:** Tageskennzahlen, Kategorien-Donut mit Filtern
  (Kategorie, Land, Monat, Ausgaben/Erstattungen), Monats-Trend,
  Länder-Auswertung, CSV-Export (Excel-tauglich, mit Ort und Person).
- **CSV-Import aus TravelSpend:** Menü (⋯) → „CSV importieren" liest
  die Export-Datei der TravelSpend-App (travelspend_export_….csv)
  in die aktive Reise ein — mit Name, Notiz, Betrag/Währung, Datum,
  Kategorie- und Zahlungsmittel-Zuordnung, Land, Ort samt Koordinaten,
  „Auf Tage verteilen", „Aus Tagesdurchschnitt ausschließen" und
  bezahlender Person. Ein erneuter Import legt nichts doppelt an
  (gleicher Name + Tag + Betrag wird übersprungen).
- **Karte:** alle Einträge mit Standort als Pins, unten Summe und Liste.
- **Suche:** Volltext über Name/Notiz/Ort/Person plus Filter nach
  Kategorie, Land und Zahlungsmittel.
- **Gemeinsame Reisen:** „Freunde hinzufügen" zeigt einen 6-stelligen
  Einladungscode; Mitreisende treten damit bei, und alle Einträge —
  auch automatisch erfasste Zahlungen — erscheinen bei allen, mit
  Namen der zahlenden Person.
- **Apple Watch:** eigenes Watch-Target „ReisekasseWatch" (watchOS 10),
  wird mit der iPhone-App mitinstalliert. Vier Seiten zum Durchblättern:
  Übersicht (Gesamt/Heute mit Budget-Balken), letzte Einträge, neuer
  Eintrag per Diktat („pizza 13,5 bar" — Kategorie automatisch) und
  Einstellungen (Reise wählen, Name, Sync). Die Watch spricht direkt
  mit derselben CloudKit-Datenbank und funktioniert damit auch ohne
  iPhone in der Nähe (z. B. beim Bezahlen nur mit der Uhr); Einträge
  ohne Netz warten in einer Outbox.

## Automatischer Import über Apple Pay

Apple gibt Dritt-Apps **keinen direkten Zugriff** auf Wallet-/Apple-
Pay-Transaktionen (die FinanceKit-API ist auf Apple Card/US beschränkt
und braucht eine Sondergenehmigung). Der offizielle Weg für alle Karten
ist die **Kurzbefehle-Automation „Transaktion"** — einmal eingerichtet,
läuft danach alles automatisch im Hintergrund:

1. **Kurzbefehle**-App öffnen → Tab **Automation** → **+** →
   **„Wenn ich eine Wallet-Karte verwende"** (je nach iOS-Version
   heißt der Auslöser auch **„Transaktion"** — es ist derselbe).
2. **Karte(n)** auswählen (z. B. alle, mit denen ihr in Kanada zahlt),
   „Sofort ausführen" aktivieren (nicht „Vor Ausführen fragen").
3. Als Aktion **„Ausgabe erfassen"** aus der Reisekasse wählen.
4. In der Aktion die Parameter aus der Transaktion belegen:
   **Betrag** ← Transaktionsbetrag (Zahl), **Währung** ← Währung,
   **Händler** ← Händler/Name, optional **Karte** ← Karte.
5. Fertig. Ab jetzt wird jede Apple-Pay-Zahlung als Eintrag in der
   aktiven Reise gespeichert — mit Uhrzeit, Händler, automatischer
   Kategorie und (siehe unten) Ort und Land.

Hinweise:

- **Standort im Hintergrund:** Damit Ort/Land auch bei der
  Hintergrund-Erfassung gespeichert werden, in den iOS-Einstellungen
  unter Reisekasse → Standort die Stufe **„Immer"** erlauben
  (die App fragt zuerst „Beim Verwenden", danach lässt sich „Immer"
  wählen — oder direkt in den Einstellungen). Ohne „Immer" wird der
  Eintrag ohne Ort gespeichert und kann nachträglich ergänzt werden.
- **Die Automation gilt pro Gerät:** auf iPhone UND iPad je einmal
  einrichten — iPad-Zahlungen (In-App/Safari per Apple Pay) erfasst
  nur die iPad-Automation. Doppelte Einträge entstehen nicht, weil
  jede Zahlung nur auf dem Gerät ausgelöst wird, auf dem sie stattfand.
- **Jede Person richtet die Automation auf ihren Geräten ein** — so
  landen auch die Zahlungen der Mitreisenden automatisch in der
  gemeinsamen Reise (nach Beitritt per Einladungscode).
- Bargeld erfasst man in Sekunden über die Schnelleingabe
  („poutine 12 bar") — Kategorie und Ort kommen automatisch.

## Synchronisation & gemeinsame Reisen

- Alle Inhalte liegen als generische Records vom Typ `Entity` in der
  **öffentlichen CloudKit-Datenbank** des App-Containers (`kind`,
  `entityId`, `payload` als JSON, `updatedAtMs`, `author`, optional
  `asset` für Fotos) — identisch zum bewährten Canada2026-Muster.
- **Offline-first:** Erst lokal gespeichert (JSON im Documents-Ordner),
  Änderungen wandern in eine persistierte Outbox und werden hochgeladen,
  sobald Netz da ist. Konflikte: Last-Writer-Wins per Zeitstempel.
- Eine CloudKit-Subscription schickt stille Pushes; zusätzlich wird bei
  jedem App-Start/Aktivieren gesynct.
- Geräteübergreifend: einfach die App auf iPhone und iPad installieren —
  gleiches iCloud-Konto ist **nicht** erforderlich, die Daten laufen
  über die öffentliche Datenbank des App-Containers. Angezeigt werden
  alle synchronisierten Reisen (der Container gehört der eigenen
  App-Familie); der Einladungscode aktiviert eine Reise und trägt den
  eigenen Namen als Teilnehmer ein.
- Die Standard-Reise „Kanada" hat auf allen Geräten dieselbe feste ID,
  und gleichnamige Duplikate (z. B. durch Neuinstallationen entstanden)
  werden automatisch zusammengeführt: Einträge, Teilnehmer und Budgets
  wandern in die älteste Reise, die Doubletten verschwinden — auf allen
  Geräten und der Watch.
- Fotos werden verkleinert (max. 1600 px) als CloudKit-Asset verteilt.

## Projekt öffnen und auf TestFlight bringen

Voraussetzungen: Mac mit Xcode 16+, Apple-Developer-Programm.

1. **Öffnen:** `ReisekasseiOS/Reisekasse.xcodeproj` in Xcode öffnen.
2. **Signing:** Target „Reisekasse" → *Signing & Capabilities* → Team
   wählen. Bundle-ID-Standard: `de.familie.reisekasse`; die Capabilities
   **iCloud (CloudKit)**, **Push Notifications** und **Background Modes →
   Remote notifications** stehen bereits in den Entitlements. Xcode legt
   den Container `iCloud.de.familie.reisekasse` beim ersten Signieren an
   (bei geänderter Bundle-ID auch `Reisekasse/Reisekasse.entitlements`
   anpassen).
3. **Erster Testlauf:** App mit iCloud-Konto starten und einen Eintrag
   anlegen — dadurch entsteht der Record-Typ `Entity` in der
   Development-Umgebung.
4. **Index anlegen:** [CloudKit Console](https://icloud.developer.apple.com)
   → Container → *Schema* → `Entity` → Feld `updatedAtMs` als
   **Queryable** und **Sortable** markieren.
5. **Schema deployen:** *Deploy Schema Changes to Production* —
   TestFlight-Builds nutzen die Production-Umgebung.
6. **App in App Store Connect anlegen (einmalig, vor dem ersten
   Upload):** Der Name „Reisekasse" ist im App Store bereits vergeben —
   der Direkt-Upload aus Xcode konnte den App-Eintrag deshalb nicht
   automatisch anlegen („App Record Creation Error"). Deshalb wurde der
   Eintrag manuell in [App Store Connect](https://appstoreconnect.apple.com)
   angelegt (*Meine Apps* → **+** → *Neue App*, gleiche Bundle-ID) —
   unter dem Namen **„Kassenbuch"**, den die App seither überall trägt.
7. **Archivieren & TestFlight:** *Product → Archive* → Upload; in App
   Store Connect die Tester (Mitreisende) einladen.
   Die Export-Compliance-Frage entfällt: `ITSAppUsesNonExemptEncryption
   = NO` ist im Projekt hinterlegt (die App enthält keine eigene
   Verschlüsselung).
8. **Automation einrichten** (siehe oben) — auf jedem Gerät einmal.

## Technik

- Swift 5 / SwiftUI, iOS 17+ (iPhone + iPad) und watchOS 10+ (zwei
  Targets: App + ReisekasseWatch), keine externen Abhängigkeiten:
  CloudKit (Sync), MapKit (Karte), CoreLocation (Ort), Swift Charts
  (Diagramme), PhotosUI (Fotos), App Intents (Kurzbefehle).
- `Model/Models.swift` — Reise/Eintrag/Kategorien/Zahlungsmittel
- `Model/Classifier.swift` — Auto-Kategorisierung + Schnelleingabe-Parser
- `Model/CloudSync.swift` — CloudKit-Engine (Outbox, Delta-Pull, Subscription)
- `Model/LocationService.swift` — Einmal-Standort + Reverse-Geocoding
- `Model/AppStore.swift` — Zustand, Persistenz, Auswertungen, CSV
- `ReisekasseIntents.swift` — App-Intent „Ausgabe erfassen" für die Automation
- `Views/…` — Einträge, Editor, Statistiken, Karte, Suche, Reisen/Freunde/Einstellungen
- `../ReisekasseWatch/…` — Watch-App (eigenes Target, bewusst ohne
  geteilte Quellen wie bei FlightMateWatch: `WatchStore.swift` spiegelt
  die Modelle mit identischen JSON-Feldnamen und bringt eine schlanke
  CloudKit-Anbindung mit; `WatchViews.swift` die vier Seiten)

Beim ersten Signieren in Xcode auch für das Target „ReisekasseWatch"
das Team wählen — es nutzt denselben iCloud-Container.
