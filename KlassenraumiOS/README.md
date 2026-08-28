# Klassenraum — Versuchsfassung

**Das ist nicht die App für den App Store.** Die veröffentlichte App heißt
**Tafelbild** und liegt in `TafelbildiOS/`. Dieser Ordner ist eine Kopie
davon, angelegt am Stand 1.0.57, mit einem einzigen Zweck:

> **Den Abgleich von der öffentlichen auf die private iCloud-Datenbank
> umbauen (Weg A), ohne die laufende App anzufassen.**

Beide Apps lassen sich gleichzeitig auf einem Gerät installieren. Auf dem
Homescreen heißt diese hier **Klassenraum**.

## Was anders ist

| | Tafelbild | Klassenraum |
|---|---|---|
| Bundle-ID | `de.familie.tafelbild` | `de.familie.klassenraum` |
| Anzeigename | Tafelbild | Klassenraum |
| Version | 1.0.x | 0.1.x |
| Vertrieb | App Store + TestFlight | **nur TestFlight, interne Tester** |
| iCloud-Bereich | `iCloud.de.familie.tafelbild` | **derselbe** |

Der iCloud-Bereich ist mit Absicht derselbe. Weg A schreibt ausschließlich in
die **private** Datenbank, die veröffentlichte App ausschließlich in die
**öffentliche** — sie kommen sich nicht in die Quere. Dafür kann die
Versuchsfassung den vorhandenen Bestand aus dem öffentlichen Bereich lesen und
den Umzug an echten Tafeln üben. Mit einem frischen Bereich stünde man vor
einer leeren Tafelliste.

## Regeln für die Arbeit hier

1. **Niemals zur Prüfung einreichen.** Zwei fast gleiche Apps desselben
   Entwicklers gelten nach Apples Regel 4.3 als Dublette und werden
   abgelehnt. Diese Fassung lebt nur in TestFlight bei internen Testern;
   dafür findet keine Prüfung statt.
2. **Hier passiert nur der Abgleichs-Umbau.** Alle sonstigen Verbesserungen
   gehen weiter allein nach `TafelbildiOS/`. Diese Kopie bleibt bei den
   Funktionen bewusst zurück — sonst müsste jede Änderung doppelt gemacht
   werden, und die beiden Fassungen laufen auseinander.
3. **Steht der Umbau, wandert nur die Abgleichsschicht zurück** nach
   `TafelbildiOS/`. Danach wird dieser Ordner gelöscht.

## Stand des Umbaus

| Stufe | Was | Stand |
|---|---|---|
| 1 | Private Datenbank mit eigener Zone `Tafeln` | **fertig** (0.1.1) |
| 2 | Bestand aus dem öffentlichen Bereich übernehmen | **entfällt** |
| 3a | Abgleich über Änderungsmarken statt Abfrage | **fertig** (0.1.5) |
| 3b/3c | Teilen, Widerrufen und Übernehmen über `CKShare` | **fertig** (0.1.6) |
| 4 | Texte, Datenschutzangaben, Manifest | **fertig** (0.1.7) |
| — | Einladung annehmen (Szenen-Delegat) | **fertig** (0.1.9) |

Stufe 2 hat sich erledigt: Der Nutzer ist über Sicherung → Einlesen umgezogen,
und seit 0.1.4 nimmt die Sicherung die Bilder und Klänge mit. Ein eigener
Übernahmeweg aus dem öffentlichen Bereich hätte nur einmal gebraucht und
danach nie wieder.

## Wie es jetzt funktioniert

**Alles liegt in der privaten iCloud der Nutzerin.** Der Entwickler kann
nichts einsehen. Zwischen den eigenen Geräten gleicht sich alles ab wie
gewohnt, auch das Umräumen.

**Geteilt wird über einen Link, nicht über einen Code.** Der Einladungscode
ist ersatzlos entfallen — er konnte nur funktionieren, solange alle Tafeln im
selben öffentlichen Bereich lagen und jeder darin suchen durfte. An seine
Stelle tritt `CKShare` mit `publicPermission = .readWrite`: Wer den Link
öffnet, ist eingeladen und darf sofort mitschreiben. Eine Rechteabfrage gibt
es bewusst nicht (Ansage des Nutzers, 08/2026) — von einer Auslosung, die man
nicht auslösen kann, hat niemand etwas.

Dazu: Freigabe zurücknehmen, Teilnahme beenden und **„Als eigene Tafel
übernehmen"** — eine abgekoppelte Kopie samt Kopien der Namenslisten unter
neuen Kennungen. Ohne die zeigten beide Tafeln weiter auf dieselbe Liste, und
die Namen der einen Klasse stünden in der anderen.

**Drei Dinge tragen das unter der Oberfläche** (`CloudSync.swift`):

1. **Herkunft.** Eine geteilte Tafel liegt in der iCloud derjenigen, die sie
   geteilt hat. Die Engine merkt sich beim Empfangen je Datensatz den Bereich
   (`sync.herkunft`) und schickt Änderungen über die richtige Datenbank
   zurück. Ein Push-Paket geht immer in genau einen Bereich.
2. **Dateien hängen an der Tafel.** Eine Freigabe reicht den ganzen Baum unter
   dem Wurzel-Datensatz weiter, deshalb bekommen Bilder und Klänge die Tafel
   als `parent` (`elternProvider`). Erst die Tafel hochladen, dann die
   Dateien — ein Verweis auf einen Datensatz, den es noch nicht gibt, wird
   abgewiesen.
3. **Sichtbarkeit.** In einer empfangenen Tafel steht weder die eigene
   iCloud-Kennung noch der eigene Name. Sie wird beim Ankommen in
   `ownBoardIDs` eingetragen, sonst bliebe sie unsichtbar.

**Einladungen nimmt ein Szenen-Delegat entgegen**
(`FreigabeSceneDelegate`, `windowScene(_:userDidAcceptCloudKitShareWith:)`).
Den Rückruf gibt es nur an der Szene, nicht am App-Delegaten. Der Delegat
trägt `var window: UIWindow?` — so wie `BeamerSceneDelegate` — beantwortet
aber `scene(_:willConnectTo:options:)` NICHT: Wer das tut, verdrängt die
`WindowGroup` von SwiftUI und die App startet ins Schwarze. Für alle anderen
Szenen-Rollen gibt `configurationForConnecting` die Konfiguration aus der
`Info.plist` zurück, sonst bliebe der Beamer schwarz. Dazu
`CKSharingSupported`, damit iOS den Link überhaupt an die App gibt.

**Dateiwähler** (`WidgetSettingsSheet`, `Dateiwunsch`, `Dateiwaehler`) — vier
Regeln, jede einmal teuer gelernt:

1. **Einer je Blatt.** Zwei streiten sich; einer gewinnt, der andere
   schweigt (0.1.9: Bild und Video gingen nicht mehr auf).
2. **An der Wurzel.** Ein `Form` ist eine `List` und baut ihre Zeilen erst
   auf, wenn sie in Sichtweite kommen — an einer Zeile mitten in der Liste
   ist der Wähler beim Tippen oft noch gar nicht da (0.1.8: Ton schwieg).
3. **Der Wunsch IST die Präsentation** (`sheet(item:)`). Ein Schalter neben
   dem Ziel läuft aus dem Tritt: zusammengezogen ist das Ziel beim Auswerten
   schon gelöscht (0.1.9: Datei landete nirgends), getrennt springt einer zu
   früh zurück.
4. **An SwiftUI vorbei zeigen** (`Dateiwahl`): UIKit präsentiert, UIKit
   schließt, das Ziel reist im Rückruf mit. Jede Präsentation, die an einem
   Ansichtswert hängt (`.fileImporter`, `.sheet`), räumt SwiftUI beim
   Neuzeichnen des Formulars ab — der Schalter bleibt stehen, im nächsten
   Durchgang geht sie wieder auf: das Flackern aus 0.1.10/0.1.11. Der
   Wechsel des Mechanismus half nicht, weil beide an einem Ansichtswert
   hingen. `asCopy: true` spart zugleich den Zugriff auf fremde Ordner.

`AppSettingsSheet` (Sicherung) und `BoardSettingsSheet` (Tafelhintergrund)
haben je einen eigenen `.fileImporter` an ihrer Wurzel. Die laufen — nicht
anfassen, ohne dass es einen Grund gibt.

**Ein Irrweg, damit er nicht wiederholt wird:** In 0.1.8 war dieser Delegat
ausgebaut — ich hatte ihn für einen stummen Dateiwähler verantwortlich
gemacht. Falsch. Bild und Video ließen sich die ganze Zeit auswählen, nur der
Ton nicht, und das schließt eine Ursache in der Szene aus. Sie lag im
Klang-Abschnitt selbst: Der Wähler hing an einer Zeile mitten in der Liste,
die noch nicht aufgebaut war. Merksatz: Wenn ein Wähler schweigt, zuerst
prüfen, ob die anderen auch schweigen.

Freigeben, Widerrufen und Übernehmen sind davon nicht betroffen.

**Kein Index, keine Security Role.** Beides galt nur für die öffentliche
Datenbank. Der Abgleich liest über Änderungsmarken
(`CKFetchDatabaseChangesOperation` + `CKFetchRecordZoneChangesOperation`) aus
**beiden** Datenbanken, der privaten und der geteilten.

**Eigenes URL-Schema:** `klassenraum://` statt `tafelbild://`. Beide Apps
liegen auf demselben Gerät; registrierten beide dasselbe Schema, entschiede
iOS willkürlich, welche einen Link öffnet. (Der Pfad `join/` darin ist mit dem
Einladungscode entfallen.)

## Datenschutz — was jetzt stimmt und was noch zu tun ist

Seit dem Umbau ist **„keine Datenerfassung" richtig**. Apple erklärt
„erheben" so: Daten so vom Gerät zu schicken, dass der Entwickler oder seine
Partner länger darauf zugreifen können, als der Vorgang es erfordert. Der
**Zugriff** ist der Kern — und den gibt es bei der privaten Datenbank nicht
mehr. `NSPrivacyCollectedDataTypes` bleibt deshalb leer; die Begründung steht
ausführlich im Kopf von `Klassenraum/PrivacyInfo.xcprivacy`.

In der App gibt es dazu eine Ansicht **Einstellungen → Datenschutz**
(`DatenschutzView.swift`): wo die Daten liegen, was bei einer Freigabe
sichtbar wird, was beim Löschen zurückbleibt.

**Offen bleibt — und zwar in Tafelbild, nicht hier:**

* `TafelbildiOS/Tafelbild/PrivacyInfo.xcprivacy` behauptet ebenfalls „keine
  Daten". Solange Tafelbild in der **öffentlichen** Datenbank schreibt, ist
  das falsch. Es wird richtig, sobald die Abgleichsschicht von hier
  zurückwandert — vorher nicht.
* `docs/tafelbild/datenschutz.html` beschreibt bewusst den heutigen Stand der
  veröffentlichten App (öffentliche Datenbank, Einsicht durch den
  Entwickler, gelöschte Datensätze bleiben stehen). **Nicht vorab ändern.**
  Beim Rückbau wird daraus: private Datenbank, keine Einsicht, Freigabe per
  Link.
* Die Antworten unter „App-Datenschutz" in App Store Connect gehören zum
  selben Schritt.

## Nicht verwechseln

`klassenraum/` (kleingeschrieben, im Wurzelverzeichnis) ist die **Web-App**
gleichen Namens. Sie hat mit diesem Ordner nichts zu tun.
