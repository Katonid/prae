# 🌗 Himmelskompass – native iOS-App

Vollständig eigenständige, native Neuentwicklung der Himmelskompass-Web-App
für iPhone und iPad – geschrieben in Swift und SwiftUI, ohne Web-Anteile.
Die bestehende PWA (`../himmelskompass/`) bleibt unverändert und wird von
diesem Projekt weder benutzt noch berührt.

## Funktionsumfang (wie die PWA)

- **Sonne:** Auf- und Untergang, bürgerliche/nautische/astronomische Dämmerung,
  goldene und blaue Stunde, Sonnenhöchststand, Tageslänge und farbiger
  Tagesverlaufs-Balken
- **Mond:** Mondphase mit Grafik, Beleuchtungsgrad, Auf-/Untergang, Entfernung,
  nächster Voll- und Neumond
- **3D-Kompass:** Sonne, Mond und Milchstraßenzentrum 🌌 am Himmel (auch unter
  dem Horizont) samt Tagesbahnen mit Uhrzeiten und Milchstraßen-Band;
  Zeit-Schieberegler mit ▶-Zeitraffer, per Fingergeste dreh-/kippbar und an die
  Gerätesensoren koppelbar
- **Milchstraße:** Sichtbarkeit des galaktischen Zentrums für die gewählte
  Nacht – Zeitfenster, beste Zeit, Richtung/Höhe, Mondstörung
- **Karten-Overlay:** Sonnen-/Mondbahn, Auf-/Untergangsrichtungen mit Uhrzeiten
  um den gewählten Ort (Apple Maps); Vollbild per Tipp, Ortswahl per Tippen
- **Zeitzonen:** Alle Zeiten in der Zeitzone des gewählten Ortes
- **ISS-Überflüge:** Sichtbare Überflüge der Raumstation (eigene
  SGP4-Bahnberechnung, Bahndaten von CelesTrak mit Cache)
- **AR-Himmelsansicht:** Kamera auf den Himmel richten – ISS-Modus (Live-Position
  mit Bahnspur, Richtungspfeil, nächster sichtbarer Überflug), Sonne-&-Mond-Modus
  (Ringe, Pfeile, Tagesbahnen mit Uhrzeiten) oder Planeten-Modus (Merkur bis
  Saturn mit Helligkeit, dazu Mond und ISS); immer mit Milchstraßen-Band und
  Horizont, ohne Sensoren per Wischen bedienbar
- **Planeten:** Positionen und Helligkeiten der hellen Planeten
  (JPL-Keplerbahn-Elemente, offline berechnet)
- **Polarlicht-Chance:** Abschätzung aus NOAA-Kp-Prognose und geomagnetischer
  Breite
- **Bedienung:** Tab-Navigation (Zeiten / Kompass / Nacht), Datum frei wählbar,
  Standort automatisch per GPS oder per Tipp auf die Karte

## Technik

- Swift 5 / SwiftUI, Mindestversion iOS 17, universell für iPhone und iPad
- Astronomie in `Model/Astro.swift` (Meeus/SunCalc-Algorithmen, wie die PWA)
- Planeten in `Model/Planets.swift` (JPL "Approximate Positions of the Planets")
- ISS in `Model/SGP4.swift` + `Model/ISSPasses.swift`: eigener SGP4-Propagator
  (Near-Earth-Modell nach Vallado), numerisch gegen satellite.js verifiziert
  (Abweichung < 1 mm über 10 Tage Propagation)
- Karte: MapKit · Sensoren: CoreMotion · Kamera: AVFoundation ·
  Standort: CoreLocation – keine externen Abhängigkeiten
- ISS-Bahndaten (CelesTrak) und Kp-Prognose (NOAA SWPC) werden mit Cache
  geladen (UserDefaults, 6 h bzw. 30 min); alles andere rechnet offline

## Bauen und auf Familiengeräte bringen

1. `HimmelskompassiOS/Himmelskompass.xcodeproj` in Xcode (16 oder neuer) öffnen.
2. Unter *Signing & Capabilities* das eigene Team (Apple-Developer-Konto)
   auswählen. Falls die Bundle-ID `de.familie.himmelskompass` im Konto schon
   vergeben ist, einfach eine eigene eintragen (z. B.
   `de.<name>.himmelskompass`).
3. iPhone/iPad per Kabel oder WLAN verbinden, als Ziel auswählen, **Run**.
   Beim ersten Start auf dem Gerät unter *Einstellungen → Allgemein →
   VPN & Geräteverwaltung* dem Entwicklerprofil vertrauen.
4. Für die vier Familiengeräte entweder jedes Gerät einmal anschließen und
   installieren, oder über *Product → Archive* ein Ad-hoc-IPA exportieren
   (die Geräte-UDIDs müssen dazu im Developer-Konto registriert sein) und
   z. B. per Apple Configurator verteilen.

Hinweis zum Konto: Mit einem **bezahlten** Developer-Konto laufen die
Signaturen ein Jahr; mit einem kostenlosen Konto muss die App alle 7 Tage neu
installiert werden.

Die App fragt beim ersten Start nach Standort-, Kamera- und
Bewegungssensor-Berechtigung (Texte sind in den Build-Einstellungen unter
`INFOPLIST_KEY_*` hinterlegt). Alle drei sind optional – ohne Standort gilt
der Fallback Berlin bzw. Ortswahl über die Karte, ohne Kamera zeigt die
AR-Ansicht einen dunklen Hintergrund, ohne Sensoren steuert man per Wischen.
