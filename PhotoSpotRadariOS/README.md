# PhotoSpot Radar

Native iOS-18-App in Swift 6 und SwiftUI. Die App kombiniert OpenStreetMap/Overpass mit Wikipedia, speichert geladene Spots offline in SwiftData und bewertet Benachrichtigungskandidaten mit einem konfigurierbaren `SpotScore`.

Das App-Icon wurde als originales 1024×1024-Radar-/Kamera-Motiv erzeugt und ohne Alpha-Kanal in den Asset Catalog eingebunden.

## Projekt öffnen

Voraussetzungen: macOS, Xcode 16 oder neuer und [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
cd PhotoSpotRadar
xcodegen generate
open PhotoSpotRadar.xcodeproj
```

Vor dem Archivieren müssen in Xcode ein eigenes Development Team und ein eindeutiger Bundle Identifier gesetzt werden. Derselbe Bundle Identifier muss im Background-Task-Identifier in `Info.plist` und `BackgroundTaskManager.swift` verwendet werden. Overpass verlangt außerdem eine echte Kontaktadresse im `User-Agent` von `HTTPClient.swift`.

Die reine Kernlogik lässt sich separat testen:

```sh
swift test
```

## Architektur

- `Sources/PhotoSpotCore`: Framework-neutrale Modelle, Geo-Mathematik, Richtungsanalyse, SpotScore und Benachrichtigungsregeln.
- `App/Models`: SwiftData-Entitäten und UI-nahe Einstellungen.
- `App/Services`: Provider, HTTP, Wikipedia-Enrichment, Persistenz und Bildcache.
- `App/Managers`: Apple-Systemdienste für Standort, Mitteilungen, Einstellungen und Background Refresh.
- `App/Engine`: Ereignisgesteuerte Orchestrierung ohne Polling.
- `App/ViewModels` und `App/Views`: MVVM-Oberfläche mit MapKit, Suche, Filtern und Deep Links aus Mitteilungen.
- `Tests` und `AppTests`: deterministische Kern- und Persistenztests.

## Energie- und Hintergrundkonzept

Die App ruft niemals `startUpdatingLocation()` auf. Im stabilen Zustand werden Significant Location Change Monitoring, Visits und höchstens 20 priorisierte Kreisregionen verwendet. `requestLocation()` liefert nur kurzzeitig einen einzelnen Fix. Background App Refresh ist lediglich eine vom System nach Nutzungsmustern ausgeführte Ergänzung und kein garantierter Timer.

iOS kann die App nach einer signifikanten Ortsänderung oder Region Entry im Hintergrund erneut starten, sofern die Berechtigung „Immer“ erteilt ist. Nach einem manuellen Force-Quit startet iOS Standortereignisse grundsätzlich erst wieder, nachdem der Nutzer die App geöffnet hat. Visits können verzögert eintreffen. Benachrichtigungen sind daher „best effort“ – eine garantierte Turn-by-Turn-Navigation wäre mit App-Store-konformen Hintergrundmitteln nicht möglich.

Apple Maps und Google Maps veröffentlichen ihre aktive Route nicht an Drittanbieter-Apps. PhotoSpot Radar liest daher keine fremde Navigation aus. Der Vorwärtskegel wird aus den letzten rauscharmen, ausreichend weit auseinanderliegenden System-Standortereignissen bestimmt. Eine spätere eigene Routenplanung kann über ein neues `RouteProviding`-Modul ergänzt werden.

## Datenschutz und Datenquellen

Standortproben verlassen das Gerät nicht als Telemetriedaten; sie werden nur für Umkreissuche und Richtungsbewertung verwendet. Anbieterabfragen enthalten technisch notwendige Mittelpunktkoordinaten. Vor einer Veröffentlichung sind Datenschutzerklärung, App-Privacy-Angaben und die jeweiligen Attributions-/Lizenzhinweise sichtbar in die App aufzunehmen. OpenStreetMap-Daten benötigen ODbL-Attribution; Wikipedia-/Wikimedia-Inhalte behalten ihre jeweiligen Lizenzen.

`PrivacyInfo.xcprivacy` deklariert den funktionalen Versand der Suchkoordinate sowie die Required-Reason-APIs für App-eigene UserDefaults und Cache-Dateimetadaten. Diese Angaben müssen vor jedem Release gegen den tatsächlichen Datenfluss und App Store Connect geprüft werden.

Kostenlose öffentliche Overpass-Endpunkte haben keine SLA. Für Produktion sind Caching, ein konform betriebener eigener Endpunkt oder ein vertraglich abgesicherter Provider einzuplanen. Unsplash und Flickr wurden absichtlich nur architektonisch vorbereitet: Beide benötigen API-Schlüssel und die jeweils aktuellen Nutzungsbedingungen.

## Erweiterungspunkte

`SpotProvider` ermöglicht weitere Quellen und eigene Spots. Die normalisierten IDs und das SwiftData-Repository sind für spätere CloudKit-Synchronisation vorbereitet. Separate Targets können ViewModels und Kernlogik für iPad, macOS, Watch, Widgets, App Intents, CarPlay, Live Activities oder GPX-Import wiederverwenden, ohne Standort- und Providerlogik zu duplizieren.
