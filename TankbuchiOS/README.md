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
  Tankstellen-Positionen (Apple Karten)
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
- **iCloud-Sync:** Fahrzeuge und Tankvorgänge liegen in SwiftData mit
  CloudKit-Spiegelung und synchronisieren automatisch zwischen allen Geräten
  derselben Apple-ID (privater iCloud-Container, keine eigenen Server).
  Unter *Einstellungen → iCloud* wird das letzte Sync-Ereignis angezeigt und
  der Abgleich lässt sich manuell anstoßen (CloudKit kennt keinen offiziellen
  „Sync jetzt“-Aufruf; die App erzeugt dafür eine Mini-Änderung an einem
  Ping-Datensatz, was den Abgleich weckt).

## Technik

- Swift 5 / SwiftUI, Mindestversion iOS 17, universell für iPhone und iPad
- Persistenz: SwiftData mit `cloudKitDatabase: .automatic`
  (NSPersistentCloudKitContainer-Unterbau); alle Modelle CloudKit-kompatibel
  (Standardwerte, keine Unique-Constraints)
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

Die App fragt beim ersten Antippen der Tankstellensuche nach der
Standort-Berechtigung; ohne Standort funktioniert alles außer der
Umkreissuche (Ortssuche per Eingabe bleibt möglich).
