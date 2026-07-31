# PhotoSpotRadar – Übergabe an Claude

## Projekt

Native iOS-App in Swift 6 und SwiftUI. Das Xcode-Projekt wird mit XcodeGen aus
`project.yml` erzeugt. Der plattformunabhängige Kern ist zusätzlich als lokales
Swift Package eingebunden.

## Einstieg

1. `README.md` vollständig lesen.
2. `project.yml` prüfen.
3. Falls nötig XcodeGen installieren: `brew install xcodegen`
4. Projekt neu erzeugen: `xcodegen generate`
5. `PhotoSpotRadar.xcodeproj` in Xcode öffnen.

## Validierte Befehle

Swift-Package-Tests:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

iOS-Simulator-Build:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project PhotoSpotRadar.xcodeproj \
  -scheme PhotoSpotRadar \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath /tmp/PhotoSpotRadar-DerivedData \
  CODE_SIGNING_ALLOWED=NO clean build
```

Der letzte Build und die iOS-Tests waren erfolgreich. Der verbleibende
AppIntents-Hinweis ist unkritisch, weil die App keine Siri-App-Intents nutzt.

## Aktueller Funktionsumfang

- Verschiebbare Apple-Karte mit Standard-, Satelliten- und Hybridansicht
- Suche nach Fotospots am Kartenmittelpunkt
- Quellen: OpenStreetMap/Overpass, Wikipedia, Wikimedia Commons, Wikidata
- Optionale Flickr-Suche mit im iOS-Schlüsselbund gespeichertem API-Key
- Sichtbarer Flickr-Verbindungstest und Suchdiagnose
- Optional ausschließlich Flickr-Ergebnisse
- Fotografische Relevanzfilterung; Stolpersteine und unklassifizierte
  Commons-Einzelbilder werden ausgeschlossen
- Relevanzstufen (Nur Highlights / Ausgewogen / Alle Treffer) in
  `SpotRelevance`; Standard ist „Nur Highlights“. Kuratierte OSM-Kategorien
  zählen mehr als aus Freitext geratene (`categoryIsCurated`); geratene
  Kategorien brauchen auf der strengsten Stufe harte Belege (Denkmalliste,
  Wikidata-Sitelinks ≥ 5 oder Wikipedia-Artikel in ≥ 4 weiteren Sprachen)
- Kategorien aus Freitext werden wortbasiert statt per Teilstring erkannt
  (`CategoryInference` im Core; „Hamburg“ ist keine Burg mehr)
- `CategoryInference.describesNonSpotSubject` verwirft unkategorisierte
  Städte/Stadtteile, Verwaltungsgebiete, Flughäfen, Stadien, Unis, Sender
  usw. (inkl. deutscher Komposita per Suffix). Die Wikidata-Abfrage holt
  dafür die instance-of-Typlabels (P31) und schließt Verwaltungseinheiten
  bereits per SPARQL aus (Q56061/Q486972)
- Quellen-übergreifende Deduplizierung in `CompositeSpotProvider`
  (`dedupeAcrossProviders`): derselbe Ort aus OSM/Wikipedia/Wikidata wird
  zu einem Datensatz verschmolzen; Präferenz OSM > Wikidata > Wikipedia
  (Wikipedia-Seitenbilder sind oft Logos)
- Eine neue Suche ersetzt Treffer im Suchgebiet: `pruneStale` löscht nicht
  erneut bestätigte Spots im Umkreis (max. 10 km, Favoriten/besuchte
  bleiben, Reisemodus ausgenommen). Einstellungen → „Suchergebnisse
  leeren“ setzt den Bestand komplett zurück
- Modernisiertes Design: `Theme` (Golden-Hour-Verlauf), bildbetonte
  `SpotCard`-Hero-Karten in Liste/Favoriten, Glass-Chips, Verlaufs-Pins
  auf der Karte, Hero-Detailansicht mit Scrim
- Liste und Favoriten nutzen ein adaptives Raster
  (`Theme.cardGridColumns`, `LazyVGrid`): eine Spalte auf dem iPhone,
  zwei bis drei auf dem iPad je nach Ausrichtung. Wichtig:
  `scaledToFill`-Bilder brauchen neben `clipped()`/`clipShape` immer
  eine `contentShape`, sonst fängt das unsichtbar überstehende Bild die
  Taps benachbarter Karten ab (zentral in `CachedSpotImage` behoben)
- Erscheinungsbild-Schalter (Wie System / Hell / Dunkel) in
  Einstellungen → Darstellung (`AppAppearance`, per
  `preferredColorScheme` in `RootView`); „Hell“ hält die Apple-Karte
  auch bei System-Dunkelmodus hell
- Davon unabhängige Kartenhelligkeit (Wie App / Hell / Dunkel):
  `settings.mapColorScheme`, angewendet per `ForcedColorScheme`
  (`environment(\\.colorScheme)`) auf die große Karte und die
  Mini-Lagekarte der Detailansicht; umschaltbar im Ebenen-Menü der
  Karte und in Einstellungen → Darstellung
- Motivfilter: alle, Natur oder Architektur
- Detailfilter nach sämtlichen Spot-Kategorien
- Flickr-Fotos innerhalb von 250 Metern als ausklappbare Listengruppe.
  Auf der Stufe „Nur Highlights“ sind Flickr-Fotos reine Ergänzung: sie
  erscheinen nur im 250-m-Umfeld eines echten Highlights
  (`SpotVisibilityPolicy`, gilt für Liste und Benachrichtigungen); der
  Schalter „Nur Flickr-Ergebnisse“ zeigt weiterhin alle Flickr-Treffer
- Benachrichtigungen werden innerhalb von 250 Metern dedupliziert
- Detailansicht mit bildschirmfüllender, zoombarer Fotoansicht
- Öffnen eines Orts in Apple Karten oder Google Maps ohne automatischen
  Navigationsstart
- Reisemodus mit mehreren gespeicherten Reiserouten (Einstellungen →
  Reisemodus → Reiserouten, `TripRoute` in den Settings als JSON):
  Start/Zwischenziel/Ziel, wählbare Korridorbreite, Routen-Detailansicht
  mit Karte (Polyline plus Abdeckungskreise — exakt die Bereiche, die
  geladen werden; `TripCorridor` im Core, deterministisch getestet).
  Gespeicherte Routen erscheinen gestrichelt auf der Hauptkarte.
  Legacy-Felder tripStart/tripDestination werden beim ersten Start in
  die Routenliste migriert
- Die Hauptkarte zeigt gespeicherte Spots im sichtbaren
  Kartenausschnitt (nicht mehr nur im Radius um Standort/Suchpunkt);
  bei mehr als 300 Treffern die höchstbewerteten. Beim Scrollen zu
  einem vorbereiteten Korridor sind dessen Spots damit ohne erneutes
  Laden sichtbar
- Optionale WLAN-Beschränkung für Bilder
- Logbuch-/Beitragsfunktion wurde auf ausdrücklichen Nutzerwunsch im
  Juli 2026 komplett entfernt (Version 1.1.0). Nicht ohne Rücksprache
  wieder einbauen.
- Versionsschema ab 1.1.0: Patch-Stelle zählt bei jeder Änderungsrunde
  automatisch hoch (1.1.1, 1.1.2, …), größere Sprünge (1.2.0/2.0.0) nur
  bei entsprechendem Funktionsumfang; Build-Nummer je Release +1.
  Gepflegt in `project.yml` (MARKETING_VERSION/CURRENT_PROJECT_VERSION),
  sichtbar in Einstellungen → „Über diese App“
- Benachrichtigungen standardmäßig nur für berühmte, belegte
  Sehenswürdigkeiten (harte Notability + Bild); abschaltbar über
  „Nur bekannte Sehenswürdigkeiten melden“ in den Einstellungen
- Übergabe an die webbasierten Upload-Assistenten; direkter Upload ist noch
  nicht per OAuth implementiert
- Sichtbare Attribution „Kartendaten: © OpenStreetMap-Mitwirkende (ODbL)“
  mit Lizenzlink in Einstellungen → Datenquellen

## Wichtige offene Konfiguration

Keine Werte erfinden. Vor Signierung, OAuth, TestFlight oder App Store beim
Benutzer erfragen:

- endgültiger Bundle Identifier
- Apple Development Team
- Overpass-Kontaktadresse/User-Agent

Derzeit steht noch `com.example.PhotoSpotRadar` in `project.yml`,
`Info.plist` und der Background-Task-ID.

## Zugangsdaten

Der Flickr-API-Key befindet sich ausschließlich im iOS-Schlüsselbund und ist
nicht Teil dieser Übergabe. Er muss auf einem neuen Gerät beziehungsweise in
einer neuen Simulatorinstallation erneut unter
„Einstellungen → Flickr-Entdeckung“ eingetragen werden.

Niemals Flickr-Secrets, Wikimedia-Zugangsdaten, Passwörter oder OAuth-Tokens
in den Quellcode eintragen.

## Noch nicht abgeschlossen

- Direkte Wikimedia-Commons-Veröffentlichung benötigt OAuth-Registrierung
  mit endgültigem Bundle Identifier.
- Direkter Flickr-Upload benötigt Flickr OAuth.
- Score-Modell kann weiter verbessert werden. Flickr-Aufrufe werden derzeit
  als Popularitätssignal verwendet; sinnvoll wäre langfristig ein
  ortsgruppenbasierter Score.
- Kartenmarker selbst werden noch nicht visuell geclustert; Liste und
  Benachrichtigungen sind bereits gruppiert.

## Projektregeln

- Keine bestehende Funktion ohne ausdrückliche Zustimmung entfernen.
- `project.yml` ist die Quelle der Xcode-Projektkonfiguration.
- Das erzeugte `PhotoSpotRadar.xcodeproj` ist eingecheckt und muss zum
  Quellstand passen: Neue Dateien und Versionsänderungen erfordern
  `xcodegen generate` und das Mitcommitten des aktualisierten Projekts
  (ohne macOS: `project.pbxproj` von Hand nachpflegen — Dateieinträge
  sowie MARKETING_VERSION/CURRENT_PROJECT_VERSION in Debug+Release).
  Sonst baut Xcode mit „Cannot find type … in scope“ und zeigt eine
  veraltete Versionsnummer.
- Nach Änderungen `xcodegen generate`, Swift-Package-Tests und einen
  Simulator-Build ausführen.
- Swift-6-Concurrency-Warnungen nicht unterdrücken, sondern sauber beheben.
- Bestehende lokale Daten und Benutzerzustände bei Migrationen erhalten.
