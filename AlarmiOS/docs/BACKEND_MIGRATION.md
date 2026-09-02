# Auf eine andere Gegenstelle wechseln

Diese App ist so gebaut, dass der Wechsel des Backends eine Datei kostet und
keinen Umbau der Oberfläche. Das Papier hier sagt, welche Datei, was sie
können muss — und was CloudKit prinzipbedingt nicht kann, also der Grund
ist, aus dem dieser Wechsel überhaupt kommen wird.

## Warum es überhaupt kommt: Android

**CloudKit stellt an Apple-Geräte zu und an sonst nichts.** Kein Android, kein
Windows-Rechner im Sekretariat, kein Browser. Sobald eine einzige
Kollegin ein Android-Telefon dabeihat und trotzdem gewarnt werden soll, ist
CloudKit als alleinige Gegenstelle erledigt. Nicht schlecht — erledigt.

Der zweite Grund ist kleiner, aber echt: **es gibt keinen Servercode.** Es
lässt sich nichts nachrechnen, nichts nachträglich abweisen, nichts
protokollieren, was ein Gerät nicht selbst schreibt. Wer eine Regel wie
„nur ein Admin darf einen Probealarm auslösen" hart durchsetzen will,
braucht eine Stelle, die das ablehnen kann. CloudKit ist diese Stelle nicht
(siehe „Was CloudKit nicht kann").

## Die drei Verträge

Eine zweite Umsetzung muss genau drei Dinge liefern.

### 1. Das Protokoll `AlarmBackend`

`Alarm/Backend/AlarmBackend.swift`. Eine Klasse, die es erfüllt, und fertig.
In keiner Signatur steht ein Typ irgendeines SDKs — das ist die Regel, die
den Wechsel billig macht, und `MockBackend` ist der laufende Beweis dafür:
Steckte irgendwo ein `CKRecord`, ließe sich `MockBackend` nicht übersetzen.

Zwei Sorten Methoden, mit Absicht getrennt:

* `async throws` — eine Frage mit Antwort oder eine Änderung mit Quittung.
  Sie scheitern laut.
* `observe…` liefert einen `AsyncStream` — ein Wert jetzt und jeder weitere
  danach. Sie scheitern nie; ein abgerissener Strom hört einfach auf zu
  liefern, und der Aufrufer behält seinen letzten Wert. Im Alarmfall ist das
  richtig herum: Die letzte bekannte Rückmeldeliste ist mehr wert als eine
  Fehlermeldung.

### 2. Der Push-Vertrag

`docs/PUSH_CONTRACT.md`. Der neue Sender erzeugt das dort beschriebene
neutrale Paket. `Shared/PushPayloadParser.swift` liest es bereits — dort ist
nichts zu ändern.

Der eine Schlüssel, an dem alles hängt: `"mutable-content": 1`. Ohne ihn
läuft die Notification Service Extension nicht, ohne die Erweiterung bleibt
`interruptionLevel` auf `.active`, und ein aktiver Fokus hält den Alarm
zurück. Der Alarm käme also an — und wäre trotzdem nicht zu hören.

### 3. Das Datenmodell

`Alarm/Backend/Models.swift`. Reine `Codable`-Strukturen ohne
Framework-Typen. Sie beschreiben, was auf der Gegenstelle liegen muss:
`AlarmGroup`, `Member`, `Alarm`, `Ack`, `Message`, `DeviceStatus`,
`InviteCode`. Wie das dort gespeichert wird — Tabellen, Dokumente,
JSON-Blobs —, ist Sache der Umsetzung.

## Welche Dateien betroffen sind

**Neu:**

* `Alarm/Backend/<Neu>/…Backend.swift` — die Umsetzung des Protokolls.
* Serverseitig: ein Sender, der bei jedem neuen Alarm die Pushes verschickt.

**Zu ändern, insgesamt drei Zeilen:**

* `Alarm/Backend/BackendConfiguration.swift` — ein `case` mehr und ein Zweig
  in `makeBackend()`. Der `case remote(baseURL:)` steht schon da und wirft
  „nicht eingebaut"; er ist absichtlich vorhanden, damit der Compiler jede
  Stelle nennt, die erweitert werden muss.
* `Config/Alarm.entitlements` — iCloud kann raus, `aps-environment` bleibt.
* `Config/Info.plist` — unverändert.

**Nicht zu ändern:**

* Alles unter `Alarm/Views/` und `Alarm/Services/`.
* `Shared/` — Domäne, Push-Vertrag, Parser.
* `NotificationService/`.
* `Alarm/Backend/MembershipStore.swift` — was das Gerät sich merkt, ist keine
  Frage der Gegenstelle.

**Zu löschen:** `Alarm/Backend/CloudKit/` — vier Dateien, sonst nichts.
Dass das reicht, ist die Regel „CloudKit-Typen nur in diesem Ordner". Wer
sie aufweicht, macht diesen Absatz zur Lüge.

## Was CloudKit nicht kann

Ehrlich aufgezählt, weil beim Wechsel jemand fragen wird, was damals eigentlich
das Problem war.

* **Keine Zustellung an Android.** Siehe oben. Der eigentliche Grund.
* **Kein Servercode.** Keine Prüfung, kein Ableiten, keine Aufräumarbeit im
  Hintergrund. Das Aufräumen der alten Datensätze macht deshalb die App
  eines Admins beim Start — was heißt: Öffnet ein halbes Jahr lang niemand
  mit Adminrechten die App, wird nicht aufgeräumt.
* **Rechte nur grob.** Die öffentliche Datenbank unterscheidet „irgendein
  angemeldeter iCloud-Nutzer" und „Ersteller des Datensatzes". Sie kann
  **nicht** „nur Mitglieder dieser Gruppe". Wer den sechsstelligen Code hat
  und eine Apple-ID besitzt, kann in dieser Gruppe schreiben — auch einen
  Alarm. Die Schutzwirkung kommt aus der Verteilung ausschließlich an
  Schul-iPads und aus der Datensparsamkeit (Kürzel statt Namen), nicht aus
  der Datenbank. Das steht so auch im README und in den Review-Notizen.
* **Kein Zustellnachweis.** Ob ein Push angekommen ist, weiß nur das Gerät.
  Die Geräteübersicht zeigt darum „zuletzt gehört von", nicht „erreichbar".
* **Zwei getrennte Umgebungen.** Über Xcode installiert läuft die App gegen
  *Development*, über TestFlight und den Store gegen *Production* — mit
  getrennten Daten. Ein Schema, das nur in Development steht, wirkt im
  ausgelieferten Bau, als sei nichts da.
* **Kein Push ohne Apple-ID.** Ein iPad ohne angemeldete Apple-ID bekommt
  gar nichts. Das ist keine Einschränkung, das ist ein Totalausfall — und der
  Grund, warum die Einrichtung ohne angekommenen Selbsttest nicht als fertig
  gilt.

## Der Ersatzweg, falls die Zustellung nicht reicht

Kommt der Alarm im Feldtest (`docs/ZUSTELLTEST.md`) nicht binnen zehn
Sekunden hörbar an, ist der kleinste Ersatz **nicht** ein anderes Backend,
sondern ein winziger eigener APNs-Sender hinter demselben Protokoll:

* Ein Dienst, der ein APNs-Token hält und auf Zuruf ein Paket nach
  `docs/PUSH_CONTRACT.md` an alle registrierten Tokens schickt.
* Die App registriert ihr Gerätetoken dort statt bei CloudKit; sie tut das
  ohnehin schon bei APNs (`registerForRemoteNotifications`).
* Datenhaltung kann zunächst bei CloudKit bleiben — der Sender ersetzt nur
  die Subscriptions.

Das ist deshalb der günstigste Schritt, weil er genau die Stelle ersetzt, die
sich als zu langsam erwiesen hätte, und alles andere stehen lässt. Er ist
zugleich der halbe Weg nach Android: Ein Sender, der APNs bedient, bedient
mit denselben Feldern auch FCM.
