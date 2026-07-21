# ⛽ Tankbuch – native iOS-App

Vollständig eigenständige, native Neuentwicklung der Tankbuch-PWA
(jerosch.net/apps/tankbuch-pwa) für iPhone und iPad – geschrieben in Swift
und SwiftUI, ohne Web-Anteile. Die bestehende PWA bleibt unverändert.

## Funktionsumfang (wie die PWA)

- **Tankvorgänge erfassen:** Datum, Tankstelle (mit Kartenposition), Kraftstoff,
  Kilometerstand, Literpreis/Liter/Gesamtpreis mit gegenseitiger automatischer
  Umrechnung („zwei Werte genügen“), Notizen
- **Markierungen:** Volltankung/Teiltankung, AdBlue (mit eigenen
  Preis-/Mengenfeldern), Anhänger, Sommer-/Winter-/Ganzjahresreifen
- **Verbrauchsberechnung:** Strecke seit letztem Tanken, Verbrauch und Kosten
  pro 100 km über Teiltankungen hinweg (wie die PWA nur bei Volltankungen)
- **Verlauf:** alle Tankvorgänge mit Bearbeiten/Löschen, Karte aller
  Tankstellen-Positionen (Apple Karten) mit Routenführung zur ausgewählten
  Tankstelle; Export als PDF-Report, Excel (.xlsx) oder CSV über das
  Teilen-Menü (wie in der PWA, ohne Fremdbibliotheken)
- **Übersicht:** Verlaufsgrafik Verbrauch/Literpreis (letzte 9 Werte),
  Gesamtsummen, Jahresstatistik je Fahrzeug
- **Tankstellensuche:** Umkreissuche per Standort oder Ortsname; mit
  Tankerkönig-API-Schlüssel Livepreise (MTS-K), ohne Schlüssel Treffer über
  Apple Karten; Sortierung nach Entfernung oder Preis; Station direkt in das
  Formular übernehmbar
- **Preisvorschlag:** Livepreis der gewählten Station, sonst letzter eigener
  Preis an der Tankstelle, letzter Preis des Fahrzeugs oder Preisvorgabe
- **Mehrere Fahrzeuge:** Name, Kennzeichen, Kraftstoffart, Preisvorgabe,
  Anfangs-Kilometerstand, Foto
- **Bedienung:** Plus-Button auf der Startseite für neue Tankvorgänge;
  auf dem iPad zeigt der Verlauf wie die PWA eine Tabelle mit Karte darüber;
  Hell-/Dunkelmodus unter *Einstellungen → Darstellung* wählbar
  (Automatisch/Hell/Dunkel)

## Datensicherung & iCloud

- **Import:** Unter *Fahrzeuge → Datensicherung* lässt sich die
  JSON-Datensicherung der PWA (`tankbuch-backup-JJJJ-MM-TT.json`, in der PWA
  über „Backup exportieren“ erzeugt) importieren. Der Import ersetzt – wie in
  der PWA – alle Daten der App, inklusive Fahrzeugfotos und
  Tankerkönig-API-Schlüssel.
- **Export:** Die App exportiert dasselbe Format, sodass die Daten auch wieder
  zurück in die Web-App wandern können.
- **iCloud-Sync:** Fahrzeuge und Tankvorgänge liegen in Core Data mit
  CloudKit-Spiegelung (`NSPersistentCloudKitContainer`) und synchronisieren
  automatisch zwischen allen Geräten derselben Apple-ID (privater
  iCloud-Container, keine eigenen Server). Unter *Einstellungen → iCloud*
  wird das letzte Sync-Ereignis angezeigt und der Abgleich lässt sich
  manuell anstoßen (CloudKit kennt keinen offiziellen „Sync jetzt“-Aufruf;
  die App erzeugt dafür eine Mini-Änderung an einem Ping-Datensatz, was den
  Abgleich weckt).
- **Gemeinsames Tankbuch (zwei Apple-IDs):** Unter *Einstellungen →
  Gemeinsames Tankbuch* lässt sich das komplette Tankbuch per
  iCloud-Freigabe (CloudKit-Sharing/CKShare) mit einer anderen Apple-ID
  teilen – z. B. mit der Partnerin. Die Einladung geht per Nachricht raus;
  nach dem Annehmen sehen und bearbeiten beide dieselben Fahrzeuge und
  Tankvorgänge, neue Einträge wandern automatisch in die geteilte Zone.
  Teilnehmer, Berechtigungen und das Beenden der Freigabe verwaltet die
  Standard-Freigabeansicht von iOS.

## Technik

- Swift 5 / SwiftUI, Mindestversion iOS 17, universell für iPhone und iPad
- Persistenz: Core Data mit `NSPersistentCloudKitContainer`, programmatisches
  Modell (`Model/Persistence.swift`), zwei Stores (privat + geteilt für
  angenommene Freigaben); alle Modelle CloudKit-kompatibel (Standardwerte,
  optionale Beziehungen mit Inversen, keine Unique-Constraints)
- Freigabe: Wurzel-Objekt „Tankbuch“ als CKShare-Anker; Fahrzeuge hängen am
  Tankbuch, Einträge am Fahrzeug – dadurch landen auch künftige Datensätze
  automatisch in der geteilten Zone. Einladung/Verwaltung über
  `UICloudSharingController`, Annahme über den Scene-Delegate
  (`CKSharingSupported` in `Config/Info.plist`)
- Verbrauchslogik in `Model/TripMath.swift`, 1:1 aus der PWA portiert
- Backup-Format in `Model/Backup.swift` (tolerantes Parsen wie
  `normalizeState` der PWA)
- Tankstellen: Tankerkönig-REST-API (Livepreise) bzw. `MKLocalSearch`
  (Fallback); Geocoding über `CLGeocoder`; Karten: MapKit;
  Diagramm: Swift Charts – keine externen Abhängigkeiten

## Bauen und über TestFlight verteilen

Voraussetzung: Mac mit Xcode 16+, **bezahltes** Apple-Developer-Konto
(99 €/Jahr – für TestFlight und iCloud/CloudKit erforderlich).

1. `TankbuchiOS/Tankbuch.xcodeproj` in Xcode öffnen.
2. Unter *Signing & Capabilities* das eigene Team auswählen. Die Bundle-ID
   `de.familie.tankbuch` bei Bedarf durch eine eigene ersetzen (z. B.
   `de.<name>.tankbuch`) – der iCloud-Container
   `iCloud.$(CFBundleIdentifier)` passt sich automatisch an.
   Xcode legt Container und Push-Zertifikate bei automatischem Signing selbst an
   (Capabilities *iCloud → CloudKit*, *Push Notifications* und
   *Background Modes → Remote notifications* sind im Projekt bereits
   hinterlegt).
3. Einmal auf einem echten Gerät testen: Gerät verbinden, als Ziel wählen,
   **Run**. iCloud-Sync funktioniert nur mit angemeldeter Apple-ID.
4. **TestFlight:**
   1. In [App Store Connect](https://appstoreconnect.apple.com) unter
      *Apps → „+“ → Neue App* eine App mit derselben Bundle-ID anlegen.
   2. In Xcode Ziel *Any iOS Device (arm64)* wählen, dann
      *Product → Archive*.
   3. Im Organizer *Distribute App → TestFlight & App Store → Upload*.
   4. Nach der automatischen Verarbeitung (einige Minuten) in App Store
      Connect unter *TestFlight* die Build-Freigabe für interne Tester
      aktivieren: eigene Apple-ID (und Familienmitglieder) als interne
      Tester hinzufügen – interne Tests brauchen **kein** Review.
   5. Auf iPhone/iPad die TestFlight-App aus dem App Store laden, Einladung
      annehmen, installieren. Builds bleiben 90 Tage gültig; neue Versionen
      einfach erneut archivieren und hochladen.
5. **Erster Start:** Unter *Fahrzeuge* ein Fahrzeug anlegen **oder** direkt
   die PWA-Datensicherung importieren (Datei vorher z. B. über iCloud Drive,
   AirDrop oder „Dateien“ aufs Gerät bringen). Auf weiteren Geräten genügt
   Warten auf den iCloud-Abgleich.

Hinweis CloudKit: Nach dem ersten Entwicklungs-Test das CloudKit-Schema in
der [CloudKit Console](https://icloud.developer.apple.com) über
*Deploy Schema Changes* in die Produktionsumgebung übernehmen, bevor der
TestFlight-Build verteilt wird – TestFlight-Builds nutzen die
Produktions-Datenbank.

Hinweis Umstieg von der SwiftData-Version: Der Wechsel auf Core Data nutzt
neue Store-Dateien – Testdaten aus einem früheren Build erscheinen nicht
automatisch. Vorher in der alten Version *Einstellungen → Backup
exportieren*, danach in der neuen Version importieren. Falls in der
CloudKit-Entwicklungsumgebung noch Datenreste der SwiftData-Version stören,
in der CloudKit Console die Development-Umgebung zurücksetzen
(*Reset Development Environment*).

Hinweis Freigabe testen: CloudKit-Sharing funktioniert nur auf echten
Geräten mit zwei verschiedenen Apple-IDs (nicht im Simulator) und braucht
eine Internetverbindung auf beiden Seiten.

Die App fragt beim ersten Antippen der Tankstellensuche nach der
Standort-Berechtigung; ohne Standort funktioniert alles außer der
Umkreissuche (Ortssuche per Eingabe bleibt möglich).
