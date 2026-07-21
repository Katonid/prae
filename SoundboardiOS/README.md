# Soundboard (native iOS-App)

Die native iOS-Version des [Theater-Soundboards](https://jerosch.net/apps/theater-soundboard):
5 Boards mit je 16 frei belegbaren Feldern für Soundeffekte und Lieder – für iPhone und iPad,
mit SwiftUI neu gestaltet und zusätzlich mit Anbindung an Streamingdienste
(Apple Music, Deezer, Spotify).

## Funktionen

**Boards & Felder**
- 5 Boards mit je 16 Feldern, umschaltbar über die Board-Leiste oben
- Boards lassen sich umbenennen, einfärben, sortieren und ausblenden
- Optionales Hintergrundbild pro Board (aus der Fotomediathek)
- Felder mit Beschriftung, Farbe (16 Vorschläge + freie Farbwahl), Lautstärke,
  Ausblenddauer beim Stoppen (0–10 s) und Sichtbarkeits-Schalter
- Felder im Bearbeiten-Modus per Ziehen sortieren

**Abspielen**
- Frei belegbare Gesten pro Feld: einfacher Tipp, Doppeltipp, langes Drücken –
  jeweils mit wählbarer Aktion (starten/fortsetzen, immer von vorn, Pause,
  stoppen und auf Anfang, Abspielen/Pause …)
- Mehrere Felder können gleichzeitig spielen (z. B. Musik + Effekt)
- Fortschrittsbalken, Spielzeit und Gesamtlänge auf jedem Feld
- „⏮ Alle auf Anfang“ stoppt alles und setzt alle Töne zurück
- Der Bildschirm bleibt während der Nutzung wach (kein Ruhezustand in der Vorstellung)

**Tonquellen pro Feld**
- **Lokale Audiodatei** (über die Dateien-App, z. B. MP3/M4A/WAV) – wird in der App gespeichert
  und funktioniert komplett offline
- **Apple Music**: Titel direkt im Apple-Music-Katalog suchen und in voller Länge nativ
  abspielen (aktives Apple-Music-Abo und Anmeldung auf dem Gerät vorausgesetzt)
- **Deezer**: Titel über die öffentliche Deezer-Suche finden; in der App wird die
  30-Sekunden-Vorschau angespielt – ideal zum kurzen Anspielen von Musiktiteln
- **Spotify**: Titel-Link aus der Spotify-App einfügen („Teilen“ → „Link kopieren“);
  beim Antippen wird der Titel in der installierten Spotify-App abgespielt
  (dort angemeldeter Account wird genutzt)

**Sichern & Übertragen**
- Vollständiger Export (Boards, Einstellungen, lokale Tondateien, Hintergrundbilder)
  als JSON-Datei, z. B. zum Übertragen auf ein anderes Gerät
- Import ersetzt nach Rückfrage alle vorhandenen Daten

## Projekt öffnen und bauen

1. `SoundboardiOS/Soundboard.xcodeproj` in Xcode 16 (oder neuer) öffnen
2. Unter *Signing & Capabilities* das eigene Team auswählen
3. Auf iPhone/iPad (iOS 17+) oder im Simulator starten

### Hinweise zu Apple Music (MusicKit)

Für die Apple-Music-Wiedergabe auf einem echten Gerät muss die App-ID in der
Apple-Developer-Konfiguration den Dienst **MusicKit** aktiviert haben
(developer.apple.com → Certificates, Identifiers & Profiles → Identifiers →
App-ID `de.familie.soundboard` → App Services → MusicKit). Beim ersten Zugriff
fragt die App die Medien-Berechtigung ab (`NSAppleMusicUsageDescription` ist
bereits hinterlegt). Die Wiedergabe in voller Länge erfordert ein aktives
Apple-Music-Abo des angemeldeten Apple-Accounts.

### Hinweise zu Spotify und Deezer

- Spotify bietet ohne eigene Entwickler-Registrierung keine native Wiedergabe in
  Dritt-Apps an. Die App öffnet Spotify-Titel deshalb per Link direkt in der
  Spotify-App – dort läuft die Wiedergabe über den angemeldeten Account.
- Die Deezer-Suche nutzt die öffentliche Deezer-API ohne Anmeldung. In der App
  wird die offizielle 30-Sekunden-Vorschau abgespielt.

## Technik

- SwiftUI, iOS 17+, keine externen Abhängigkeiten
- Audio: `AVAudioPlayer` (lokale Dateien), `AVPlayer` (Deezer-Vorschau),
  `MusicKit`/`ApplicationMusicPlayer` (Apple Music)
- Persistenz: JSON + Mediendateien im Documents-Verzeichnis der App
- Projektstruktur analog zu `HimmelskompassiOS` (Xcode 16, synchronisierte Ordnergruppen)
