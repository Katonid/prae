# 🪧 Tafelbild — die Klassenraum-Tafel als native iOS-App

Ersatz für Classroomscreen & Co.: eine frei gestaltbare Tafel für den
Unterricht — ohne Abo, ohne Werbung, ohne fremde Server. Swift/SwiftUI,
iOS 17+, keine externen Abhängigkeiten. Gemacht fürs **iPad am Beamer**,
läuft genauso auf dem **Mac** (Apple-Silicon-Macs führen iPad-Apps direkt
aus) und auf dem **iPhone** in einer eigenen Stapelansicht.

## Was die App kann

### Tafeln (Homescreens)
- Beliebig viele Tafeln — je Klasse, Fach oder Tageszeit eine eigene.
  Umschalten über den Namen oben links.
- **Frei anordnen:** „Anordnen" antippen, Elemente ziehen, an der Ecke
  an **allen vier Ecken** in der Größe ändern (mit Fangraster) oder
  stufenweise über „−/+" in der Werkzeugleiste, nach vorn/hinten
  sortieren, duplizieren, löschen.
- Jede Tafel liegt auf einer festen Arbeitsfläche von 1600 × 1000
  Punkten, die auf jedes Gerät skaliert wird — die Anordnung sieht auf
  iPad, Mac und Beamer identisch aus.
- **Hintergrund:** sechs bewegte Farbwolken-Vorlagen (Nordlicht,
  Sonnenaufgang, Waldgrün, Beere, Tafelgrün, Kreide hell), dazu
  Farbverläufe, einfarbige Flächen oder ein eigenes Bild (mit
  stufenlosem Abdunkeln, damit Text lesbar bleibt).
- **Farbschema:** Indigo, Ozean, Wald, Sonne, Schiefer oder Kreide —
  färbt Knöpfe, Ringe, Zeiger und gezogene Namen auf der ganzen Tafel,
  wahlweise als Verlauf oder als eine Farbe.
- **Kartenstil:** Glas (Milchglas), Hell (deckendes Weiß, der stärkste
  Kontrast am Beamer) oder Dunkel.
- **Ruhe auf der Tafel:** Rahmen und Beschriftungen lassen sich je Tafel
  auf „Immer", „Beim Bearbeiten" oder „Nie" stellen — im Unterricht
  bleibt dann nur der Inhalt stehen. Einzelne Elemente können zusätzlich
  ohne Karte stehen oder festgesteckt werden, damit sie nicht mehr aus
  Versehen verrutschen.
- **Präsentationsmodus:** blendet die Bedienleiste aus, versteckt die
  Statusleiste, hält den Bildschirm wach.

### Elemente
| Element | Was es tut |
|---|---|
| **Zufälliger Name** | Zieht Namen aus einer Namensliste — siehe unten |
| **Timer** | Countdown oder Stoppuhr, Ring-Anzeige, Schnellwahl 1/2/5/10/15/20 Min., „+1 Minute", Signal am Ende |
| **Uhr** | Analog mit vier Zifferblättern (Modern, Klassisch, **Lernuhr** mit blauem Stunden- und orangem Minutenzeiger, Minimal), digital oder beides, wahlweise mit Datum |
| **Ampel** | Rot/Gelb/Grün mit frei beschriftbaren Arbeitsphasen, senkrecht oder waagerecht |
| **Lautstärke** | Misst den Geräuschpegel über das Mikrofon: Tacho, Balken oder große Lampe, mit einstellbarer Schwelle und „Zu laut"-Warnung |
| **Tagesablauf** | Checkliste zum Abhaken, mit Fortschrittsbalken und optionalem täglichem Zurücksetzen |
| **Text** | Überschriften und Arbeitsaufträge: Größe, Farbe, Ausrichtung, Hintergrund |
| **Bild** | Foto aus der Mediathek oder Datei, füllend oder vollständig, mit Bildunterschrift |
| **Klänge** | Tonfelder auf Knopfdruck: eigene Dateien oder direkt in der App aufgenommene Ansagen |
| **Arbeitssymbol** | Zeigt die Arbeitsform groß an (Einzel-, Partner-, Gruppenarbeit, Stillarbeit, Flüsterstimme, Melden, Zuhören, Aufräumen) — ein Tipp schaltet weiter |

### Zufälliger Name — im Detail
Das meistgenutzte Element, deshalb vollständig ausgebaut:

- **Zwei Ziehweisen:** „Ohne Wiederholung" (ein gezogener Name kommt
  erst zurück in den Topf, wenn die ganze Liste durch ist — die App
  zeigt „8/22 übrig" und bietet danach „Neue Runde" an) und „Immer alle
  Namen" (bei jedem Zug steht die ganze Liste zur Verfügung).
- **Gezogene Namen** stehen als Chips unter der Anzeige. Ein Tipp auf
  einen Chip öffnet: **„Zurück in den Topf"** oder **„Aus Liste
  löschen"**.
- **Von Hand als gezogen markieren:** über das ⋯-Menü → „Als gezogen
  markieren" (oder in den Element-Einstellungen jeden Namen antippen).
  So lässt sich jemand eintragen, den der Zufall gar nicht gewählt hat.
- **Alle zurücklegen** setzt die Runde zurück.
- **Namenslisten** sind zentral (Menü ⋯ → „Namenslisten") und lassen
  sich in mehreren Tafeln verwenden. Namen einzeln anlegen, mehrere auf
  einmal einfügen (eine Zeile pro Name), umsortieren, löschen — und
  einzelne Namen **pausieren**, wenn jemand krank ist: pausierte Namen
  werden nicht gezogen.
- Die Ziehung wird animiert („Durchrattern" der Namen), das lässt sich
  abschalten.
- **Aufdecken zum Mitraten:** Der gezogene Name erscheint wahlweise
  **sofort**, hinter einem **Mosaik** (zwölf Tipps, bis alle Kacheln weg
  sind), als **Unschärfe** (zehn Stufen) oder **Buchstabe für
  Buchstabe**. Jeder Tipp auf die Karte deckt einen Schritt auf, das
  Auge daneben zeigt sofort alles — und wenn der Name ganz da ist, gibt
  es Konfetti. Der Stand des Aufdeckens wird mitsynchronisiert.
- **Gezogene Namen anzeigen:** „Immer", „Beim Bearbeiten" oder „Nie" —
  bei „Beim Bearbeiten" lässt sich im Unterricht nicht ablesen, wer noch
  fehlt.

### Teilen mit Kolleginnen und Kollegen
- Menü ⋯ → **„Tafel teilen"** zeigt einen sechsstelligen
  Einladungscode und verschickt auf Wunsch eine fertige Einladung
  (Nachrichten, Mail, WhatsApp …).
- Die Kollegin öffnet **Tafeln → „Tafel beitreten (Code)"**, gibt den
  Code ein — fertig. Danach sehen beide dieselbe Tafel, Änderungen
  gleichen sich über iCloud ab. Der mitgeschickte Link
  `tafelbild://join/CODE` öffnet die App direkt.
- Es ist **kein gemeinsames iCloud-Konto nötig** — jedes Gerät braucht
  nur irgendein iCloud-Konto.

## Wie der Abgleich funktioniert

- **Eigene Geräte:** Tafeln und Namenslisten erscheinen automatisch auf
  allen Geräten mit derselben Apple-ID — ohne Einstellung, ohne Code. Die
  App merkt sich dafür die iCloud-Kennung des Kontos (die vergibt CloudKit
  je App-Container) und zeigt jedem Gerät genau die Tafeln, die zu diesem
  Konto gehören.
- **Kolleginnen und Kollegen:** über den sechsstelligen Einladungscode.
  Beim Beitritt trägt sich das Gerät mit seiner Kennung in die Tafel ein;
  ab dann laufen Änderungen in beide Richtungen.
- **Wann wird abgeglichen:** beim Start, bei jeder Rückkehr in die App,
  nach jeder Änderung (gebündelt nach ~1,5 Sekunden), alle 15 Sekunden
  solange die Tafel zu sehen ist, und zusätzlich über stille
  iCloud-Mitteilungen. Eine Änderung der Kollegin — auch ein gezogener Name — steht damit
  spätestens eine Viertelminute später auf der eigenen Tafel.
- **Selbstständig vollständig:** Jede Tafel nimmt Kopien der Namenslisten
  mit, die sie benutzt. Kommt sie auf einem anderen Gerät an, ist sie damit
  sofort komplett — auch wenn der eigene Datensatz einer Liste noch
  unterwegs ist. Beim Empfangen wandern die Listen in den gemeinsamen
  Bestand und lassen sich dort ganz normal bearbeiten.
- **Konflikte:** Es gewinnt die zuletzt gespeicherte Fassung (je Tafel).
- **Offline:** Alles läuft weiter; Änderungen warten in einer Warteschlange
  und gehen hoch, sobald wieder Netz da ist.
- **Wenn etwas klemmt:** *Einstellungen → „Abgleich prüfen"* prüft Konto,
  Kennung, Schreiben und Lesen einzeln und nennt zu jedem Fehler die
  Abhilfe im Klartext. Dort steht auch, welche CloudKit-Umgebung das Gerät
  benutzt — das ist die häufigste Stolperstelle: **Eine über Xcode
  installierte App nutzt „Development", eine über TestFlight installierte
  „Production".** Zwei Geräte reden nur miteinander, wenn sie in derselben
  Umgebung sind.

## Datenhaltung und Privatsphäre

- Alles liegt zuerst **lokal** (JSON im Documents-Ordner, Bilder und
  Töne unter `Documents/Media`). Ohne Netz funktioniert die App
  vollständig.
- Ist der Abgleich eingeschaltet (Standard), liegen Tafeln,
  Namenslisten und Mediendateien zusätzlich als Records vom Typ
  `Entity` in der **öffentlichen CloudKit-Datenbank des App-Containers**
  — dasselbe bewährte Muster wie in der Reisekasse-App dieses Repos.
  Das ist der Preis dafür, dass Teilen ohne gemeinsame Apple-ID
  funktioniert: Technisch kann jedes Gerät, auf dem diese App läuft,
  die Datenbank abfragen; die App zeigt nur, wofür man Mitglied ist.
  **Deshalb: in Namenslisten Vornamen (ggf. mit Anfangsbuchstaben des
  Nachnamens) verwenden — so wie in Classroomscreen auch.**
- Wer nichts hochladen möchte: **Einstellungen → „Abgleich über
  iCloud" ausschalten.** Dann bleibt alles auf dem Gerät; Teilen ist
  damit nicht möglich.
- **Die Lautstärkemessung verlässt das Gerät nie.** Es wird nichts
  aufgezeichnet und nichts gespeichert — nur der Pegel wird angezeigt.
  Eine Aufnahme entsteht ausschließlich, wenn man in den Klang-Feldern
  bewusst „Selbst aufnehmen" wählt.

## In fünf Schritten auf TestFlight

Voraussetzungen: Mac mit Xcode 16+, Apple-Developer-Programm.

1. **Öffnen:** `TafelbildiOS/Tafelbild.xcodeproj` in Xcode öffnen.
2. **Team wählen:** Target „Tafelbild" → *Signing & Capabilities* →
   *Team*. Bundle-ID ist `de.familie.tafelbild`; die Capabilities
   **iCloud (CloudKit)**, **Push Notifications** und **Background Modes →
   Remote notifications** stehen schon in den Entitlements. Xcode legt
   den Container `iCloud.de.familie.tafelbild` beim ersten Signieren an
   (bei geänderter Bundle-ID auch `Config/Tafelbild.entitlements`
   anpassen).
3. **CloudKit einrichten** (einmalig, ohne das bleibt der Abgleich stumm):

   a) **Record-Typ anlegen.** [CloudKit Console](https://icloud.developer.apple.com)
      → Container `iCloud.de.familie.tafelbild` → oben **Development** →
      links **Schema → Record Types → +** → Name: **`Entity`**. Dann diese
      Felder hinzufügen (Groß-/Kleinschreibung genau so):

      | Feldname | Typ |
      |---|---|
      | `kind` | String |
      | `entityId` | String |
      | `payload` | String |
      | `updatedAtMs` | Int(64) |
      | `author` | String |
      | `asset` | Asset |

      *Alternativ, wenn ein Mac mit Xcode da ist:* App aus Xcode starten und
      in der App *Einstellungen → Abgleich prüfen → „Schema in iCloud
      anlegen"* antippen — dann entsteht der Typ mitsamt allen Feldern von
      selbst. Beides führt zum selben Ergebnis; von Hand geht auch vom iPad
      aus im Browser.

   b) **Indexes → +** — der Dialog hat vier Zeilen: *Record Type*, *Name*
      (frei wählbare Bezeichnung), *Type* und *Field*. **„Field" ist die
      Auswahl, auf die es ankommt** — ohne sie meldet der Dialog „This
      field is required".

      | Record Type | Field | Type | |
      |---|---|---|---|
      | `Entity` | `updatedAtMs` | **QUERYABLE** | Pflicht |
      | `Entity` | `recordName` | QUERYABLE | optional, als Reserve |

      Mehr braucht es nicht: Die App sortiert selbst, ein **SORTABLE**-Index
      ist nicht nötig. Ohne den Index auf `updatedAtMs` lehnt CloudKit jede
      Abfrage ab — das Hochladen funktioniert aber weiter, es sieht dann so
      aus, als käme auf dem zweiten Gerät nichts an.

   c) **Security Roles → Zeile `Entity`** → für die Rolle `_icloud`
      **Read und Write** ankreuzen (Pflicht fürs Teilen: sonst darf nur
      die Person schreiben, die eine Tafel angelegt hat).

   d) Oben rechts **„Deploy Schema Changes to Production"** — sonst gilt
      alles nur für Xcode-Installationen, nicht für TestFlight.

   Danach in der App *Einstellungen → Abgleich prüfen → „Verbindung
   prüfen"*: Alle vier Zeilen müssen grün sein.

4. **App-Eintrag anlegen** (einmalig) in
   [App Store Connect](https://appstoreconnect.apple.com): *Meine Apps*
   → **+** → *Neue App*, gleiche Bundle-ID. Ist der Name „Tafelbild"
   im App Store schon vergeben, hier einfach einen freien Namen
   eintragen (z. B. „Tafelbild Schule") — der Homescreen-Name der App
   bleibt davon unberührt.
5. **Archivieren & hochladen:** *Product → Archive* → *Distribute App*
   → *TestFlight & App Store*. Danach in App Store Connect die
   Kolleginnen als Tester einladen.

Zwei Dinge sind bewusst automatisiert, damit dabei nichts hakt:

- **Die Build-Nummer setzt die Bauphase „Build-Nummer setzen" selbst**
  (Anzahl der Git-Commits, ersatzweise ein Datumsstempel). Jeder Upload
  ist damit automatisch neuer als der vorherige — „Build-Nummer schon
  vergeben" kann nicht mehr passieren, und es muss nichts von Hand
  gepflegt werden. Die sichtbare Version (1.0.x) wird bei jeder
  Arbeitseinheit im Repo angehoben.
- **Die Export-Compliance-Frage entfällt:**
  `ITSAppUsesNonExemptEncryption = NO` ist sowohl in
  `Config/Info.plist` als auch als Build-Einstellung hinterlegt. Die App
  bringt keine eigene Verschlüsselung mit, deshalb fragt App Store
  Connect bei keinem Build danach.

Auf dem Mac: im TestFlight-/App-Eintrag „Auf Macs mit Apple Silicon
verfügbar machen" aktivieren — dann läuft dieselbe App als iPad-App auf
dem Mac.

## Übersetzt wird automatisch

Jeder Push auf `TafelbildiOS/` baut die App auf einem macOS-Läufer von
GitHub Actions (`.github/workflows/tafelbild-build.yml`): `xcodebuild`
gegen das iOS-Simulator-SDK, ohne Signierung. Am Ende des Protokolls
stehen alle `error:`- und `warning:`-Zeilen zusammengefasst; scheitert
der Bau, hängt das vollständige Protokoll als Artefakt am Lauf.

Der Nutzen: Übersetzungsfehler fallen auf, **bevor** das Projekt auf dem
Mac geöffnet wird — und wer am Code arbeitet (auch Claude), sieht das
Ergebnis, ohne selbst einen Mac zu brauchen. Das Repo ist öffentlich,
macOS-Minuten kosten damit nichts.

Läufe stehen unter *Actions → „Tafelbild bauen"*; von Hand starten geht
dort über *Run workflow*.

## Technik

- Swift 5 / SwiftUI, iOS 17+ (iPhone + iPad), keine externen
  Abhängigkeiten: CloudKit (Abgleich), AVFoundation (Pegelmessung,
  Wiedergabe, Aufnahme), PhotosUI (Bilder).
- `Model/Models.swift` — Tafel, Element, Inhalte, Namenslisten,
  Hintergründe (ausdrückliches `Codable` mit Typkennung, damit
  gespeicherte Tafeln auch nach Erweiterungen lesbar bleiben)
- `Model/BoardStore.swift` — Zustand, Persistenz, Mitgliedschaften,
  Medien, Beitritt per Code
- `Model/CloudSync.swift` — CloudKit-Engine (Outbox, Delta-Pull,
  Subscription, Medien auf Anforderung)
- `Model/Audio.swift` — Audio-Sitzung, Pegelmessung, Klangfelder,
  Sprachaufnahme
- `Model/MediaCache.swift` — Bildzwischenspeicher und Medienablage
- `Views/BoardCanvasView.swift` — Tafel mit freier Anordnung, Auswahl,
  Größengriff; dazu die Stapelansicht fürs iPhone
- `Views/WidgetHostView.swift` — Rahmen, Verschieben, Verbindung zum
  Speicher
- `Views/Widgets/…` — die neun Elemente
- `Views/Sheets/…` — Tafeln, Teilen, Namenslisten, Element- und
  App-Einstellungen

### Warum eine feste Arbeitsfläche?
Elemente speichern ihre Lage in Tafelpunkten (0…1600 / 0…1000). Die
Ansicht rechnet einmal den Maßstab aus und skaliert die ganze Fläche.
Dadurch bleibt eine Tafel auf jedem Gerät gleich — und eine geteilte
Tafel sieht bei der Kollegin genauso aus wie bei einem selbst, auch
wenn sie ein anderes iPad benutzt.
