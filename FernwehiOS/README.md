# Fernweh — Reisetagebuch für dich und deine Miturlauber

Native iOS-App (SwiftUI, iOS 17, iPhone + iPad, keine fremden Abhängigkeiten).
Eine Reise sammelt Tagebucheinträge mit Fotos, die Reisespur jedes Tages und
lässt sich teilen — mit **Miturlaubern**, die mitschreiben, und mit
**Betrachtern**, die nur mitlesen.

## Was die App kann

- **Reisespur im Hintergrund.** Solange eine Reise läuft und die Aufzeichnung
  an ist, zeichnet die App den Weg auf — Strategie aus Tagesspur übernommen
  (`Model/Aufzeichner.swift`): „Immer"-Ortung, `CLBackgroundActivitySession`,
  eigener Ruhemodus statt Apples Auto-Pause, Besuche, signifikante
  Ortswechsel und ein Zaun um die letzte Position, damit iOS die App nach dem
  Beenden wieder startet. Jeder Punkt geht sofort auf die Platte; in die
  Reise (und die iCloud) wandert die Spur gedünnt alle paar Minuten, eine je
  Tag und Gerät.
- **Eintrag mit Ortsvorschlag.** Ein neuer Eintrag bekommt als Titel den Ort,
  an dem du gerade bist (bei einem vergangenen Tag den ersten wichtigen Ort
  des Tages). Darunter die **Orte des Tages** aus der Spur: iOS-Besuche plus
  Aufenthalte ab acht Minuten in 120 m — ein Tipp übernimmt sie.
- **Fotos des Tages.** Alle Aufnahmen des Kalendertages liegen zum Antippen
  bereit.
- **Bearbeitete Fotos erscheinen bearbeitet.** Gemerkt werden die örtliche und
  die iCloud-Kennung (`PHCloudIdentifier`). Liegt ein Foto in der eigenen
  Mediathek, zeigt die App immer dessen aktuelle Fassung. Für die Miturlauber
  reist eine Kopie (2048 px) mit; ändert sich das Original
  (`modificationDate`), wird sie beim Aktivwerden und bei jeder Meldung der
  Mediathek neu gerechnet.
- **Teilen.** Zwei Wege mit Apples eigenem Teilen-Blatt: „Miturlauber
  einladen" bietet nur Schreibrecht an, „Betrachter einladen" nur Leserecht.
  Betrachter sehen alles, aber keinen Bearbeiten-Knopf.

## Einrichten (einmalig, auf dem Mac)

1. In Xcode → Target **Fernweh** → *Signing & Capabilities*:
   - **iCloud** → *CloudKit* → Container `iCloud.de.familie.fernweh` anlegen
     bzw. anhaken,
   - **Push Notifications**,
   - **Background Modes** → *Location updates* und *Remote notifications*.
   Die Entitlements-Dateien (`Config/Fernweh.entitlements` für Debug,
   `Config/Fernweh-Release.entitlements` für Release) stehen schon im Repo;
   Xcode muss die Fähigkeiten nur an der App-Id eintragen.
2. Einmal über Xcode auf ein Gerät bauen, dann **Einstellungen →
   „CloudKit-Schema anlegen (Entwicklung)"** (nur im Debug-Bau sichtbar).
3. In der CloudKit-Konsole **„Deploy Schema Changes to Production"**. Ohne
   diesen Schritt geht über TestFlight nichts in die iCloud.

## Aufbau

| Datei | Aufgabe |
|---|---|
| `Model/Modell.swift` | Datenmodell im Quelltext (Reise, Eintrag, Foto, Spur) |
| `Model/Persistenz.swift` | `NSPersistentCloudKitContainer`, privat + geteilt, Rechte, Freigaben |
| `Model/Teilen.swift` | Apples Teilen-Blatt über UIKit, Beteiligte aus der Freigabe |
| `Model/Aufzeichner.swift` | Reisespur, Rohspur auf der Platte, Übertragung in die Reisen |
| `Model/Tagesorte.swift` | Aufenthalte aus der Spur, Ortsnamen (gedrosselt, gemerkt) |
| `Model/Fotodienst.swift` | Mediathek, Übernehmen, Abgleich bearbeiteter Fotos |
| `Views/WillkommenView.swift` | Erster Start: 3D-Flug über Landschaften, Erklärung, Erlaubnisse |

Das App-Symbol rechnet `scripts/make-icon.py` — nicht von Hand bearbeiten.

## Nicht gemessen

Nichts davon ist auf einem Gerät gesehen worden; übersetzt wird in GitHub
Actions ohne Signierung. Offen sind vor allem: ob die Freigabe über
`NSPersistentCloudKitContainer` mit dieser App-Id auf Anhieb durchgeht, wie
zuverlässig die Spur über einen ganzen Urlaubstag läuft und wie lange das
Übernehmen vieler Fotos dauert.
