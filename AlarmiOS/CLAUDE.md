# Projekt Schulalarm (Notfall- und Amokalarm, native iOS-App)

> Ausgelagert aus der `CLAUDE.md` im Wurzelverzeichnis (09/2026). Die
> übergreifenden Regeln (PR-Rhythmus, iOS-Pflichten, Bau in GitHub
> Actions) stehen weiterhin dort und gelten hier genauso.


- App-Code: `AlarmiOS/` (zwei Targets: App + `AlarmNotificationService`,
  iPhone + iPad, iOS 16). Eine Lehrkraft löst aus, alle Dienst-iPads
  eines Kollegiums werden laut, jede meldet mit einem Tipp zurück.
  **Kostenlos im öffentlichen App Store** (Ansage des Nutzers, 09/2026; bis
  1.0.34 war die Custom App über Apple School Manager und Jamf School der
  einzige Weg — der bleibt daneben bestehen). Bundle-Id `de.dboschule.alarm`.
- **Diese App ersetzt keinen Notruf.** Der Satz steht auf dem
  Alarm-Bildschirm, in den Einstellungen und in den Review-Notizen —
  nicht wegrationalisieren.
- **Alles Backend-Nahe liegt hinter EINEM Protokoll** (`AlarmBackend`).
  CloudKit-Typen kommen ausschließlich in `Alarm/Backend/CloudKit/` vor;
  Views und Services importieren CloudKit nie. Das ist kein Stilwunsch:
  CloudKit stellt an Apple-Geräte zu und an sonst nichts, und sobald
  Android dazukommt, soll der Wechsel eine Datei kosten. `MockBackend`
  ist der laufende Beweis — steckte irgendwo ein `CKRecord`, ließe es
  sich nicht übersetzen. Ausführlich: `AlarmiOS/docs/BACKEND_MIGRATION.md`.
- **Die Notification Service Extension ist Pflicht, nicht Kür.** Eine
  CloudKit-Subscription kann `interruptionLevel` nicht setzen; ohne die
  Erweiterung bliebe jede Meldung auf `.active`, und ein aktiver Fokus
  hielte den Alarm zurück. Sie hebt auf `.timeSensitive`, baut Titel und
  Text und schreibt `userInfo` ins neutrale Format um. **Sie verwirft
  nie etwas** — ein unlesbares Paket wird angezeigt, mit dem Grund im
  Text. Ein stillschweigend verschluckter Alarm ist der schlimmste
  denkbare Fehler dieser App.
- **Der Push-Vertrag steht in `AlarmiOS/docs/PUSH_CONTRACT.md`** und wird
  an genau einer Stelle gelesen (`Shared/PushPayloadParser.swift`). Wer
  ihn ändert, ändert ihn dort und im Papier gleichzeitig.
- **`Shared/` liegt in BEIDEN Zielen** und ist als einziger Ordner über
  ausdrückliche Dateiverweise im pbxproj eingebunden, nicht über eine
  synchronisierte Gruppe (die gehört immer genau einem Ziel). Wer dort
  eine Datei anlegt, trägt sie in beide `Sources`-Phasen ein — sonst
  fehlt sie der Erweiterung, und das fällt erst beim Übersetzen auf.
- **Datum im Push ist ISO-8601-TEXT, keine Zahl.** CloudKit kodiert ein
  `Date`-Feld als nackte Zahl, und ob die ab 1970 oder ab Apples
  Bezugsdatum 2001 zählt, steht nirgends verlässlich. Ein falscher
  Nullpunkt machte jeden Alarm 31 Jahre alt — und die App schaltet alte
  Alarme (über drei Minuten) auf `.passive`. Der Fehler wäre nicht
  sichtbar falsch, sondern still stumm.
- **Das Feld `headline` ist Absicht.** Kommt die Erweiterung nicht zum
  Zug, zeigt iOS den Rückfalltext aus `alertLocalizationKey` mit den
  ROHEN Feldwerten als Argumenten — „amok" auf einem Sperrbildschirm
  hilft niemandem. Deshalb steht die deutsche Überschrift als eigenes
  Feld auf dem Datensatz. Aus demselben Grund wird `location` nie leer
  geschrieben: Ein fehlendes Argument lässt iOS die ganze Meldung fallen.
- **`instructionShort` statt `instruction` in den `desiredKeys`.** Ein
  APNs-Paket ist auf 4 KB gedeckelt, und ein einziges zu großes Feld
  nimmt die ganze Meldung mit. Der volle Text steht auf dem Datensatz und
  ist eine Sekunde später auf dem Alarm-Bildschirm.
- **`collapseIDKey` nennt ein FELD, nicht den Datensatznamen.** Darum
  trägt der Alarm seinen eigenen Namen zusätzlich im Feld `alarmId`.
  Ohne das stapeln sich mehrere Zustellungen desselben Alarms als
  mehrere Banner.
- **Öffentliche CloudKit-Datenbank — mit ehrlich benannten Grenzen.**
  Sie unterscheidet nur „irgendein angemeldeter iCloud-Nutzer" und
  „Ersteller". Sie kann NICHT „nur Mitglieder dieser Gruppe". Wer den
  sechsstelligen Code hat und eine Apple-ID besitzt, kann in der Gruppe
  schreiben. **Seit 1.0.35 trägt der Beitrittscode das ALLEIN**: Bis dahin
  stand daneben, dass es die App nur auf verwalteten Schul-iPads gab, und im
  öffentlichen Laden gilt das nicht mehr. Was bleibt, ist Sichtbarkeit statt
  Türsteher (Beitrittsdatum in der Mitgliederliste, doppelte Kürzel markiert,
  Entfernen und Zurückziehen des Codes) und Datensparsamkeit (Kürzel statt
  Namen). Das steht so im README, in den Review-Notizen, auf der
  Datenschutzseite und in BACKEND_MIGRATION — **wer den Satz „nur an
  Schul-iPads" irgendwo wiederfindet, streicht ihn**; er ist seit dem
  öffentlichen Vertrieb schlicht falsch.
- **Indizes und Sicherheitsrolle sind hier NÖTIG** (anders als bei
  Tafelbild, das privat abgleicht): Ohne Queryable-Index scheitert jede
  Abfrage, ohne `_icloud`-Schreibrecht kann ein zweiter Admin nichts
  pflegen. Die Tabelle steht im README unter „CloudKit einrichten", dazu
  einmalig „Deploy Schema Changes to Production".
- **Sortiert wird nach dem Systemzeitstempel, aber IN DER APP** (ab 1.0.11).
  Nach `creationDate` und nicht nach dem eigenen `createdAt`, weil den der
  Server setzt und ein Gerät mit falscher Uhr ihn nicht verbiegen kann. Aber
  ohne `NSSortDescriptor`: Der verlangt einen SORTABLE-Index auf
  `___createTime`, und fehlt der, lehnt CloudKit die Abfrage ab — getroffen
  hätte es `activeAlarm`, also das AUSLÖSEN und den Nachfasslauf (gemeldet
  09/2026: „Field '___createTime' is not marked sortable"). Damit war der
  Alarm nicht auslösbar und das Netz unter den Subscriptions gerissen: Der
  Nachfasslauf hätte den Testalarm auch ohne Push gefunden. Die wichtigste
  Abfrage dieser App darf an keinem Häkchen in einer Web-Oberfläche hängen.
  `query()` nimmt deshalb gar keine Sortierung mehr entgegen.
- **Irgendwer muss anfangen: `createGroup`.** Bis 1.0.1 gab es nur
  `joinGroup` — das sucht einen Beitrittscode-Datensatz, der einen
  Group-Datensatz braucht, den nichts in der App je anlegte. Die App war
  damit gar nicht zu betreten (gemeldet 09/2026). Wer die Schule
  einrichtet, IST der erste Admin; der erste Beitrittscode entsteht gleich mit
  und wird auf dem Einrichtungsbildschirm gezeigt. Reihenfolge beim
  Anlegen: Group, dann Member, dann Code — eine Referenz auf einen
  Datensatz, den es noch nicht gibt, weist CloudKit ab. Und `store.role`
  muss VOR `createInviteCode` stehen, denn das fragt `requireAdmin()`.
- **Eine Subscription braucht den Record-Typ VORHER** (`ensureSchema`, ab
  1.0.3). `CKQuerySubscription` nennt einen Record-Typ, und CloudKit lehnt
  eine für einen Typ ab, den es nie gesehen hat. Genau das war die Lage
  direkt nach dem Einrichten: `Group`, `Member` und `InviteCode` standen,
  `Alarm` und `Ping` nicht — der erste Alarm liegt ja noch in der Zukunft.
  Die Subscriptions wurden also abgewiesen, und ein Gerät ohne Subscription
  ist für immer stumm, ohne es zu sagen. `ensureSchema` schreibt je einen
  Datensatz und löscht ihn wieder; der Datensatz geht, der Typ bleibt. Der
  Alarm-Platzhalter ist NIE `active` und trägt `targetUser = "schema"` —
  scheitert das Löschen, darf daraus kein Alarmbildschirm auf 30 iPads
  werden.
- **`ensureSchema` läuft NUR als Rückfall, nicht bei jedem Start** (ab 1.0.27).
  Bis 1.0.26 schrieb `refreshSubscriptions` bei jedem Start vier Platzhalter —
  darunter einen vom Typ `Message`. Seit 1.0.21 gibt es das Abonnement
  `message-created-v1`, dessen Prädikat nur nach der Gruppe fragt: Jeder
  Platzhalter löste also auf ALLEN anderen Geräten eine Mitteilung aus,
  „Nachricht von Schema: Schema" (gemeldet 09/2026). Wer die App nur einmal
  öffnete, ließ dreißig iPads piepen. Die anderen drei Platzhalter waren von
  Anfang an harmlos, weil sie `targetUser = "schema"` tragen und die Alarm- und
  Ping-Prädikate `"*"` oder die eigene Kennung verlangen — beim
  Nachrichten-Abonnement gab es diesen Schutz nicht, und ein Prädikat lässt sich
  nachträglich nicht ändern. **Merke: Wer ein Abonnement hinzufügt, prüft, ob
  `ensureSchema` dessen Prädikat trifft.** Jetzt versucht `reconcile` es zuerst;
  `reconcile` kehrt von selbst um, wenn nichts fehlt, und die Platzhalter werden
  nur nach einem gescheiterten Anlegen geschrieben — also genau in dem Fall, für
  den sie gedacht waren.
- **Zwei Tests, weil es zwei Fehler sind** (ab 1.0.3). Der **Tontest**
  (`Services/Tontest.swift`) weckt das Gerät örtlich, ohne einen Meter Netz:
  Er beweist, dass das iPad laut werden DARF (Erlaubnis, Ton, Fokus,
  Lautlos-Schalter, Sperrbildschirm). Der **Selbsttest** geht über CloudKit
  und beweist die Zustellung. Der Selbsttest allein kann nicht sagen, an
  welcher Stelle die Kette reißt — deshalb sind es zwei Zeilen in der
  Prüfliste und nicht eine.
- **Ein Prädikat fragt mehr Felder ab als die Probeabfrage** (ab 1.0.4).
  Die Diagnose prüfte je Record-Typ nur `groupRef` — die Subscriptions
  fragen zusätzlich nach `targetUser` und `status`. Fehlt DORT der
  Queryable-Index, meldet die Probeabfrage „geht" und die Subscription
  entsteht trotzdem nicht (gemeldet 09/2026: alle vier fehlten, alle
  Abfragen grün). Die Prädikate stehen deshalb einmal in
  `CloudKitSubscriptions` und werden von Subscription UND Diagnose benutzt;
  zwei Fassungen prüften garantiert etwas anderes, als die Zustellung
  braucht.
- **CloudKit stellt dem SCHREIBENDEN Gerät nichts zu** (gefunden 09/2026).
  Alle fünf Abonnements angelegt, alle Prädikate abfragbar, APNs angemeldet —
  und der Selbsttest kam trotzdem nie an. Ein Gerät kann sich die Zustellung
  nicht selbst beweisen. Der Testalarm geht deshalb an ein ANDERES Mitglied
  (Verwaltung → Mitglieder → „Testalarm senden"), und der Haken „Zustellung
  geprüft" setzt sich auf dem EMPFANGENDEN iPad von selbst, sobald dort ein
  Push eintrifft (`store.letzterPush`). Einen Knopf, der auf einem einzelnen
  Gerät nie funktionieren kann, darf diese App nicht anbieten.
- **Eine gekoppelte Apple Watch fängt den Ton ab** (gefunden 09/2026). Wird
  sie getragen, leitet iOS die Mitteilung ans Handgelenk und das iPhone
  bleibt STILL — und die Uhr spielt nie den eigenen Ton einer App, sondern
  ihren Systemton. **Abstellen lässt sich das pro App** (ab 1.0.24 in der
  Prüfliste): App „Watch“ → Mitteilungen → „Mitteilungen von iPhone spiegeln“
  → Schulalarm aus. Es ist eine Einstellung des GERÄTS: Eine App kann die
  Spiegelung nicht selbst abschalten und auch nicht auslesen, ob sie aus ist.
  Deshalb steht die Zeile auf iPhones als Anleitung mit `.unknown` da und
  nicht als Häkchen — und auf einem iPad gar nicht, dort gibt es keine
  Spiegelung. Die Dienst-iPads haben keine Uhr; für den Test gilt es
  trotzdem. Zweite Falle daneben: der Lautlos-Schalter — ohne kritische
  Hinweise bleibt auch eine zeitkritische Meldung stumm.
- **Klingeltonlautstärke ist NICHT Medienlautstärke** (gefunden 09/2026).
  Ein Mitteilungston hängt an der Klingeltonlautstärke; die
  Lautstärketasten regeln die Medien, solange etwas spielt — also auch
  während der Tonprobe. „Ton direkt abspielen geht, die Mitteilung bleibt
  stumm" ist damit kein Widerspruch, sondern der Normalfall bei
  heruntergeregeltem Klingelton. Auslesen lässt sich der Wert nicht (keine
  öffentliche API), deshalb steht er als erster Punkt in der Anleitung und
  nicht als Häkchen.
- **Der Tontest kann auch mit dem Standardton** (ab 1.0.9). Das ist der
  Vergleich, der die letzte Zweideutigkeit auflöst: Standardton hörbar und
  Alarmton nicht heißt, iOS mag die Datei als Mitteilungston nicht; beide
  stumm heißt, es liegt am Gerät. Ohne diesen Vergleich stehen beide
  Erklärungen nebeneinander und keine lässt sich aus der Ferne ausschließen.
- **Die Tonprobe spielt an den Mitteilungen vorbei** (`Tonprobe`, ab 1.0.8).
  Sie spielt dieselbe Datei über AVFoundation in der Kategorie `playback` —
  das klingt auch bei stummem Gerät. Damit trennt sich „iOS kann die Datei
  nicht lesen" von „das Gerät darf gerade nicht laut werden"; ohne sie standen
  drei Erklärungen nebeneinander und keine ließ sich ausschließen. Die
  Berechtigungen stehen aus demselben Grund im kopierbaren Befund und nicht
  nur in der Prüfliste.
- **Töne sind WAV, nicht CAF.** Der von Hand geschriebene CAF-Container war
  formal in Ordnung (`file` erkannte ihn, `desc`- und `data`-Block stimmten)
  — iOS spielte trotzdem den Standardton. Was es nicht laden kann, ersetzt
  es stillschweigend, ohne Fehler. Geschrieben wird jetzt mit Pythons
  `wave`-Modul: kein fremdes Paket, aber auch nichts Selbstgebasteltes.
  Und die Diagnose schlägt die Datei im Bündel nach und nennt ihre Größe —
  „kommt an, aber leise" sieht sonst genauso aus wie ein falscher Dateiname.
- **Höchstens DREI `desiredKeys` je Subscription.** Mit zehn lehnte CloudKit
  jedes Alarm-Abonnement ab („notification additional fields limit
  exceeded"), und ein Gerät ohne Abonnement ist für immer stumm — die
  Ping-Abonnements kamen durch, weil sie gar keine Felder mitschicken.
  Es sind jetzt `type`, `location`, `triggeredByName` (bei der Entwarnung
  `type`, `clearedByName`). `alertLocalizationArgs` nennt ebenfalls Felder
  und bleibt deshalb leer; der Rückfalltext ist ein fester Satz. Damit
  fällt bei CloudKit auch die Altersprüfung der Erweiterung aus (`createdAt`
  reist nicht mehr mit) — ein zu laut gemeldeter alter Alarm ist der
  kleinere Schaden als gar keiner. Für ein eigenes Backend gilt die Grenze
  nicht; der Push-Vertrag bleibt vollständig.
- **CloudKit kennt kein `OR` im Prädikat** (gefunden 09/2026). „an alle ODER
  an mich" wurde mit „Invalid predicate: Unexpected expression" abgelehnt —
  und zwar erst beim Anlegen auf dem Gerät, nicht beim Übersetzen. Der Ping
  hat deshalb ZWEI Subscriptions mit je einem `==` (`ping-all-v2`,
  `ping-me-v2`). Nur `==`, `!=`, Vergleiche und `AND` sind hier belegt.
- **`modifySubscriptions` wirft bei Einzelfehlern NICHT.** Es wirft nur, wenn
  der ganze Aufruf scheitert; abgelehnte Abonnements stehen in
  `saveResults`. Bis 1.0.4 warf `reconcile` das Ergebnis mit `_ =` weg — die
  Diagnose meldete „ohne Fehler durchgelaufen", während kein einziges
  Abonnement entstanden war. Dasselbe Muster wie bei `partialErrorsByItemID`,
  eine Ebene höher: Wo CloudKit ein Ergebnis je Element zurückgibt, ist das
  Ergebnis die Fehlermeldung.
- **`aps-environment` MUSS zur Umgebung passen — zwei Entitlements-Dateien**
  (ab 1.0.18). `Config/Alarm.entitlements` (Debug) sagt `development`,
  `Config/Alarm-Release.entitlements` (Release) sagt `production`; im pbxproj
  zeigt jede Konfiguration auf ihre. Bis 1.0.17 stand `development` für beide,
  und das kostete einen Abend: Über TestFlight ist der Container Production,
  der Push-Client war Development, und CloudKit wies daraufhin JEDES Abonnement
  ab — auch eines ohne Prädikat und ohne Meldung — mit „attempting to create a
  subscription in a production container". **Die Meldung zeigt auf den
  Container und meint das Profil.** Alle Abfragen waren grün, alle Prädikate
  abfragbar; es sah nach einem Fehler bei Apple aus und war einer von uns.
  Die Diagnose nennt deshalb seit 1.0.18 die APNs-Umgebung und meldet ROT, wenn
  sie nicht zur Umgebung passt. **Über TestFlight und aus dem Laden liegt aber
  gar kein Profil im Bündel** — Apple signiert dort neu und entfernt es (ab
  1.0.19 abgefangen). Dann bleibt die Bau-Konfiguration als Quelle, und die
  Zeile sagt dazu, woher ihr Wert stammt: gelesen oder erschlossen. Eine
  Auskunft über den Bau als Messung auszugeben wäre genau die Art Lüge, die
  diese Diagnose nicht erzählen darf. Keine der beiden
  Dateien darf die andere ersetzen: Ein Debug-Bau mit `production` meldet sich
  bei der falschen APNs-Umgebung an.
- **Wo eine Fehlermeldung nur auf die Umgebung zeigt, muss eine PROBE
  entscheiden** (`stufenprobe`, `CloudKitSubscriptions.stufen`, ab 1.0.17).
  Scheitert das Anlegen, legt die Diagnose drei Abonnements an, die sich um je
  EINE Sache unterscheiden — schlicht (nur `groupRef`, nackte Meldung), mit
  vollem Prädikat, mit Meldung —, und löscht jedes sofort wieder. Die erste rote Zeile
  sagt, wovon der Fehler abhängt: von Abonnements überhaupt (dann ist es Apples
  Sache), vom Prädikat (Index) oder von der Meldung (dann ist es unsere).
  Dasselbe Muster wie bei den Prädikatsproben in 1.0.4: Eine Diagnose, die den
  Fehler bloß wiedergibt, ist die Frage von vorhin noch einmal.
- **`ensureSchema` verschluckte seine Fehler** (bis 1.0.16 `await` ohne `try`).
  Es gibt sie jetzt zurück, und die Diagnose zeigt sie — ein blinder Fleck
  genau dort, wo die Zustellung hängt: Ein Record-Typ, den es in Production
  nicht gibt, lässt sich dort auch nicht durch Schreiben anlegen.
- **Ein NEUES FELD braucht einen Deploy — in Production entsteht keines durch
  Schreiben** (getroffen 09/2026 mit `alarmId` auf `Message`, eingeführt in
  1.0.21). Der Befund war eindeutig, seit `ensureSchema` seine Fehler zurückgibt:
  „Cannot create or modify field 'alarmId' in record 'Message' in production
  schema", und daraufhin lehnte CloudKit das Abonnement ab, weil seine
  `desiredKeys` ein Feld nennen, das Production nicht kennt („could not find
  requested additional field"). **Nach jeder Fassung, die ein Feld oder einen
  Record-Typ hinzufügt, gehört „Deploy Schema Changes to Production" dazu** —
  in der Konsole, von Hand, und die App kann es nicht für einen erledigen. Die
  Diagnose sagt diesen Satz seit 1.0.23 im Klartext unter dem Rohtext.
- **`NSPredicate(value: true)` ist in Production verboten — und die Meldung
  dazu lügt.** Ein Abonnement ohne Prädikat wird abgelehnt mit „attempting to
  create a subscription in a production container", also mit demselben Satz,
  der 1.0.18 einen Abend gekostet hat. Nachgewiesen 09/2026: Stufe 1 der
  Stufenprobe rot, Stufen 2 und 3 im selben Durchgang angenommen. Damit war die
  Probe selbst die Irreführung — sie war in Production IMMER rot. Stufe 1 fragt
  seit 1.0.23 mit dem einfachsten GÜLTIGEN Prädikat (nur `groupRef`).
  **Merke: Dieser eine Fehlertext hat mindestens zwei Ursachen** — ein
  `aps-environment`, das nicht zur Umgebung passt, und ein Abonnement ohne
  Prädikat. Er zeigt auf den Container und meint beide Male etwas anderes.
- **Development und Production trennen auch die DATEN, nicht nur die Indizes.**
  Über Xcode installiert läuft die App gegen Development, über TestFlight gegen
  Production. Eine über Xcode eingerichtete Schule gibt es in der
  TestFlight-Fassung nicht — die App merkt sich Gruppe und Rolle aber ÖRTLICH
  und übersteht damit die Neuinstallation: Sie sieht eingerichtet aus, während
  in Production nichts steht. Prüfstein ist die Mitgliederliste. Deshalb nennt
  die Diagnose seit 1.0.16 als zweite Zeile die vermutete Umgebung
  (`umgebungsvermutung` — geraten am Beleg im Bündel, denn `CKContainer` gibt
  sie nicht her).
- **„Diesen Beitrittscode gibt es nicht" heißt oft: nicht in DIESER Umgebung**
  (`Umgebung.swift`, ab 1.0.31). Gemeldet 09/2026: Schule über TestFlight
  eingerichtet, Kollegium beigetreten, alles lief — und auf einem per Xcode
  angeschlossenen iPad wurde derselbe Code abgewiesen. Der Beitrittscode IST
  der Name seines Datensatzes, und in Development gibt es diesen Datensatz
  nicht; `joinGroup` bekommt `.unknownItem` und meldet wörtlich richtig, dass
  es den Code nicht gibt. Als Auskunft war das irreführend — der Nutzer suchte
  den Fehler im Update. Die Meldung nennt den Riss deshalb jetzt selbst, samt
  der Umgebung, in der diese Fassung läuft, und derselbe Satz steht unter dem
  Codefeld. **Der Riss geht in BEIDE Richtungen**, deshalb kein `#if DEBUG` um
  den Hinweis: Welche Seite gerade fehlt, weiß die App nicht.
- **`Umgebung.beschreibung` ist die eine Quelle** für „Development oder
  Production". Vorher stand die Logik nur in `CloudKitBackend.umgebungsvermutung`
  für die Diagnose; die Fehlermeldung braucht sie genauso, und zwei Fassungen
  wären zwei Wahrheiten. `umgebungsvermutung` reicht seither nur noch durch.
- **Teilfehler auspacken.** `modifySubscriptions` meldet ein Scheitern als
  EINEN Fehler mit `partialErrorsByItemID` darin. Ohne Auspacken liest man
  „Some items failed" und weiß nichts.
- **Die Diagnose legt fehlende Subscriptions gleich an** und schreibt das
  Ergebnis hin. Eine Diagnose, die „FEHLT" meldet und den Grund
  verschweigt, ist die Frage von vorhin noch einmal.
- **`mapped()` gehört nicht in eine Diagnose.** Es macht aus „unknown record
  type Ack" ein „Der Datensatz wurde nicht gefunden" — richtig für die
  Oberfläche, tödlich für die Fehlersuche. Dafür gibt es `rohAbfrage`.
- **„Zustellung prüfen" gibt den ROHEN Fehlertext aus** (`DiagnoseView`,
  `AlarmBackend.diagnose()`). Je Record-Typ eine Probeabfrage, dazu jede
  der vier Subscriptions einzeln, der Kontostatus, die APNs-Anmeldung und
  der Zeitpunkt des letzten angekommenen Pushes. „Field 'groupRef' is not
  marked queryable" ist für die Person, die es richten muss, mehr wert als
  ein aufgeräumtes „Verbindung fehlgeschlagen". Kopierbar, weil der Nutzer
  am iPad sitzt.
- **Wer beitritt, wird MITGLIED — nie Admin** (ab 1.0.13). Bis dahin
  wurde die erste Person einer noch leeren Gruppe automatisch zum Admin.
  Gedacht als Notausgang, tatsächlich eine Rechtevergabe, die niemand
  angeordnet hat (gemeldet 09/2026: „das andere Gerät wurde automatisch zu
  einem Leitungs-Gerät, das will ich gar nicht"). Admin wird man auf genau
  zwei Wegen: die Schule einrichten, oder von einem Admin ernannt werden.
  Die Zahl der Admins ist unbegrenzt. Eine Ausnahme, die keine ist: Hat
  das Konto hier schon ein Mitglied, behält es seine Rolle — sonst verlöre
  ein Admin seine Rechte beim Neuinstallieren.
- **Ein Kürzel darf der Admin berichtigen** (`setDisplayName`, ab 1.0.25).
  Getippt wird es beim Beitreten, und dabei passiert alles. Die Kennung des
  Mitglieds bleibt dabei UNVERÄNDERT — sie ist abgeleitet
  (`member-<Gruppe>-<Nutzer>`), und daran hängen Rückmeldungen und Geräte.
  Alte Rückmeldungen behalten das Kürzel von damals: Sie sind ein Nachweis,
  kein Zustand. Damit die Änderung auf dem betroffenen Gerät ankommt, übernimmt
  `AppModel.uebernimmEigenesMitglied()` bei jedem Start und jeder Rückkehr in
  den Vordergrund, was der Server über das eigene Konto sagt — Rolle UND
  Kürzel. Ohne das schriebe das Gerät seine nächste Rückmeldung weiter unter
  dem alten, und die Änderung wäre nur in der Mitgliederliste zu sehen.
- **Ein Kürzel gehört einer Person — abgewiesen wird das KÜRZEL, nicht der
  Beitritt** (ab 1.0.28). Wer ein schon vergebenes Kürzel tippt, wird beim
  Beitreten abgelehnt (`Member.vergleichbaresKuerzel`: Groß/Klein und
  Leerzeichen zählen nicht, **Umlaute werden NICHT eingeebnet** — „MU“ und „MÜ“
  sind zwei Personen), dieselbe Prüfung noch einmal in `setDisplayName`. Das
  eigene Mitglied ist ausgenommen, sonst käme niemand nach einer Neuinstallation
  zurück. **Die naheliegende Bestätigung durch das schon angemeldete Gerät ist
  bewusst NICHT gebaut** (Vorschlag des Nutzers, 09/2026): Steht dieses iPad im
  Schrank, bliebe eine Lehrkraft im Ernstfall stumm — in einer Alarm-App ist
  Aussperren der größere Schaden als ein doppeltes Kürzel. Und sie hielte
  niemanden auf, der ein freies Kürzel nimmt. Die Kontrolle ist deshalb
  **Sichtbarkeit**: Die Mitgliederliste nennt seit 1.0.28 das Beitrittsdatum und
  markiert noch vorhandene Doppel; ein unerwarteter Eintrag wird entfernt und der
  Beitrittscode zurückgezogen.
- **Das Gerät heißt, wie es heißt** (`Services/Geraetename.swift`, ab 1.0.36,
  gemeldet 09/2026). Auf einem iPhone stand „Dieses iPad ist nicht
  einsatzbereit" — die App war für dreißig Dienst-iPads gebaut, und die Texte
  sagten das wörtlich. Ein Warnband, das vom falschen Gerät redet, liest sich
  wie ein Fehler in der App. **Die Regel für JEDEN neuen Text:** Geht es um
  DIESES Gerät, steht dort `Geraetename.wort` („iPad", „iPhone", sonst
  „Gerät"); geht es um IRGENDEIN Gerät (eine Aussage über die Schule, ein
  anderes Mitglied, zwei Geräte an einer Apple-ID), steht dort schlicht
  „Gerät" — ein „iPad" wäre da nicht bloß unpassend, sondern falsch, denn der
  Satz gilt für jedes Gerät. Grammatisch geht das auf, weil iPad, iPhone und
  Gerät alle sächlich sind. Kein `default`-Zweig mit Rateversuch: Läuft die App
  eines Tages auf einem Mac, ist „Gerät" richtig und „iPad" gelogen.
- **Die Kamera folgt der Lage des GERÄTS, nicht der des Sensors**
  (`QRCodeView.richteVorschauAus`, ab 1.0.36, gemeldet 09/2026). Auf einem quer
  gehaltenen iPad stand das Kamerabild hochkant, und ein fremder Beitrittscode
  ließ sich kaum treffen. Eine `AVCaptureVideoPreviewLayer` beginnt immer im
  Hochformat — die Verbindung übernimmt die Lage der Oberfläche NICHT von
  selbst. **Erkannt hätte die Kamera den Code trotzdem**: Gesucht wird im
  Sensorbild, und das ist von der Anzeige unabhängig. Genau das macht den
  Fehler zäh — nichts ist kaputt, es lässt sich nur nicht zielen; für den
  Menschen davor ist das dasselbe. Gesetzt wird der Winkel bei jedem Layout,
  also auch beim Drehen. Zwei Dinge dabei: **Gefragt wird die Szene DIESER
  Ansicht** (`view.window?.windowScene`), nie `connectedScenes` — das ist eine
  ungeordnete Menge, und hängt ein Beamer am iPad, greift `first { … }` mal die
  eine und mal die andere (derselbe Fehler wie bei Tafelbilds
  Dokumentenkamera). Und **die Winkel sind Apples eigene Entsprechungen** aus
  der Abkündigung von `videoOrientation` (portrait 90, portraitUpsideDown 270,
  landscapeLeft 180, landscapeRight 0), nicht selbst nachgerechnet: Die
  Bezugslage der Kamera ist Querformat, und 180 Grad daneben fällt nur auf
  einem echten Gerät auf. Der iOS-16-Weg steht in einer eigenen, als veraltet
  markierten Funktion — `#available` schaltet eine Abkündigungswarnung nicht
  ab, die hängt an der Übersetzung.
- **Der eigene Alarm bleibt auf dem eigenen iPad stumm** (`istEigenerAlarm`, ab
  1.0.34, gemeldet 09/2026). Der örtliche Nachfasslauf `AlarmReminder` fragt
  nicht, wessen Alarm er anschreit — das auslösende Gerät schlug 30 Sekunden
  später selbst an und dann noch neunmal. Wer auslöst, steht am Ort; in einer
  Gefahrenlage ist ein Ton aus der eigenen Tasche das Letzte, was gebraucht
  wird. Verglichen wird `alarm.triggeredByUserId` mit der eigenen Kennung
  (`member?.userId ?? store.userId` — persistiert, weil beim Start der Alarm
  schon dasteht, bevor die Mitgliedsabfrage zurück ist). **Beide müssen gefüllt
  sein:** leer heißt „weiß ich nicht", und dann wird laut — ein Ton zu viel ist
  der kleinere Schaden. Angezeigt wird unverändert ALLES, samt einer Zeile auf
  dem Alarm-Bildschirm, die die Stille erklärt; ein iPad, das ohne Grund
  schweigt, hält man für kaputt. **Ein zweites Gerät desselben Kontos schlägt
  einmal an**: CloudKit stellt nur dem SCHREIBENDEN Gerät nichts zu, und die
  Erweiterung kann den Auslöser nicht kennen (eigener Behälter, keine
  App-Gruppe, `desiredKeys` mit drei Feldern voll). Das über das Prädikat zu
  lösen (`triggeredByUserId != …`) ist bewusst NICHT gebaut — dann hinge die
  Zustellung an einem weiteren Queryable-Index, und fehlt der, entsteht kein
  Abonnement und das Gerät ist für immer stumm. Die wichtigste Kette dieser App
  wird nicht für einen einzelnen Ton verlängert.
- **Austreten gibt es, Mehrfachmitgliedschaft nicht** (`leaveGroup`, ab 1.0.33,
  Ansage des Nutzers 09/2026). Einstellungen → „Verbindung zur Schule lösen".
  Ein Gerät gehört zu genau EINER Schule; ein Wähler „an welche Schule geht
  dieser Alarm?" wurde ausdrücklich verworfen — im Ernstfall ist jede
  Zusatzfrage eine zu viel. Der Musikschullehrer an drei Schulen ist ein
  Sonderfall, den diese App bewusst nicht bedient.
- **Die TESTSTRECKE ist kein eigener Modus, sondern der Austritt** (Wunsch des
  Nutzers 09/2026: „einen zweiten Kanal … an anderen Geräten, die nicht an der
  Schule registriert sind"). Ein Mitglied ist die Apple-ID, die aktive Schule
  steht ÖRTLICH je Gerät (`store.groupId`), und `member-<Gruppe>-<Nutzer>`
  trägt die Gruppe im Namen — dasselbe Konto kann also in zwei Gruppen ein
  Mitglied haben, ohne dass sich etwas überschreibt. Ein zweites Gerät tritt
  aus und richtet eine eigene Testschule ein; das Haupt-iPad bleibt unberührt.
  **Dafür braucht es keinen Umschalter und keine zweite Datenhaltung** — wer
  einen baut, holt sich genau die Auswahlfrage zurück, die hier nicht sein soll.
- **Beim Austritt muss BEIDES weg, sonst gar nichts** (`CloudKitBackend.leaveGroup`).
  Bleibt das Mitglied stehen, zählt der Admin im Ernstfall jemanden mit, der
  nichts mehr bekommt — die gefährlichere Hälfte. Bleiben die Abonnements
  stehen, klingelt das Gerät weiter für eine fremde Schule, und `reconcile`
  räumt sie NIE wieder ab, weil es dafür eine Gruppe bräuchte
  (`CloudKitSubscriptions.entferneAlle`). Scheitert ein Schritt, bleibt alles
  wie es war: Ein Austritt ist nie eilig, und auf eine Verbindung zu bestehen
  ist billiger als ein halb gelöster Zustand, den niemand mehr sieht.
- **Der letzte Admin darf weder entfernt werden noch austreten**
  (`pruefeLetztenAdmin`, in BEIDEN Backends). Ohne Admin ist eine Schule tot —
  `createInviteCode`, `setRole`, `updateLocations` und die Entwarnung fragen
  alle `requireAdmin()`, und aus der App heraus gibt es keinen Weg zurück. Ist
  er das EINZIGE Mitglied, ist es kein Ausfall, sondern das Ende der Schule;
  dann geht es.
- **„Kein Mitglied gefunden" und „konnte nicht nachsehen" sind NICHT dasselbe**
  (`AppModel.Mitgliedschaftsstand`, ab 1.0.33). Ein `try?` wirft den
  Unterschied weg, und ein Netzaussetzer sähe dann aus wie ein Rauswurf. Nur
  eine GELUNGENE Abfrage, die nichts fand, setzt `.fehlt` — dieselbe Regel wie
  beim Alarm-Bildschirm. **Und auch dann meldet sich die App nur**: Die
  Prüfliste zeigt die Zeile rot, gelöst wird von Hand. Ein Gerät, das sich
  selbst abmeldet, wäre im Ernstfall stumm, ohne dass es jemand gemerkt hat.
- **Ein Admin entfernt ein Mitglied über einen KNOPF**, nicht nur über die
  Wischgeste (ab 1.0.33) — dieselbe Lehre wie beim Gruppenchat. Sich selbst
  entfernt man dort nicht: Nur der Austritt in den Einstellungen räumt auch die
  Abonnements DIESES Geräts ab, und die erreicht kein fremdes iPad.
- **Ein Mitglied ist eine APPLE-ID, kein iPad.** Zwei iPads mit derselben
  Apple-ID sind EIN Mitglied mit EINER Rolle, und eine Rückmeldung lässt
  sich ihnen nicht einzeln zuordnen (`ack-<Alarm>-<Nutzer>`). Jede Lehrkraft
  braucht eine eigene Apple-ID. Sichtbar wird der Fall in der
  Geräteübersicht: `DeviceStatus` heißt seit 1.0.13
  `device-<Gruppe>-<Nutzer>-<Gerät>` und zählt die Geräte je Kürzel — vorher
  überschrieben sich zwei iPads gegenseitig, und der Admin erfuhr nie,
  dass es zwei sind.
- **Ein Fehlerband unter einem Blatt sieht niemand** (behoben in 1.0.26). Die
  drei Bänder (Hinweis, Problem, Wiederholung) hingen ausschließlich an
  `RootView`; Verwaltung, Einstellungen und Auslösen sind aber BLÄTTER und
  liegen darüber. Aufgefallen beim Ernennen eines zweiten Admins: „Das Drücken
  des Textes zeigt keine Funktion" — der Knopf meldete sehr wohl einen Fehler,
  nur erschien der hinter dem Blatt. Die Bänder liegen jetzt in
  `Views/Meldungen.swift` und werden über `.meldungen(model)` an die Wurzel UND
  an jedes Blatt gehängt. **Wer ein neues Blatt baut, hängt sie mit dran.**
  Dazu meldet sich seit 1.0.26 auch der Erfolgsfall: Ein Knopf, der schweigt,
  ist für den Menschen davor ein kaputter Knopf.
- **Es ist NIE nur ein Record-Typ** (`mappedFremderDatensatz`, ab 1.0.37).
  1.0.26 rückte `.permissionFailure` für `Member` gerade, weil es dort zuerst
  auffiel. 09/2026 kam derselbe Satz beim **Entwarnen des Alarms einer
  Kollegin**: „Nur ein Admin darf das" — gemeldet von einem Admin. Ein Alarm
  gehört dem, der ihn ausgelöst hat, und `Alarm` war derselbe blinde Fleck.
  Betroffen sind ALLE Wege, die auf fremde Datensätze schreiben: `clearAlarm`
  (`Alarm`), `updateGroup` (`Group`, also Standorte und Handlungstexte eines
  ZWEITEN Admins), `revokeInviteCode` (`InviteCode`) und das Aufräumen
  (`Alarm`, `Ack`, `Message`). Die Erklärung steht deshalb einmal in
  `mappedFremderDatensatz` und nennt den Typ, um den es gerade geht, dazu einen
  Satz, was ohne das Häkchen NICHT geht. **Wer einen neuen Schreibweg auf einen
  fremden Datensatz baut, hängt ihn dort ein und nicht an `mapped`.** Und:
  `clearAlarm` ruft bewusst kein `requireAdmin()` — wer entwarnen darf,
  entscheidet `mayClear`; jedes `.notPermitted` von dort kommt also von
  CloudKit und nie von uns.
- **Das Aufräumen zählte die ABSICHT, nicht das Ergebnis** (bis 1.0.36).
  `modifyRecords` wirft nur, wenn der ganze Aufruf scheitert; einzelne
  Ablehnungen stehen in `deleteResults`, und die warf `cleanUp` mit `_ =` weg.
  Gemeldet hätte es „12 Alarme gelöscht", während keiner gelöscht war — und der
  wahrscheinlichste Grund ist genau der Punkt darüber: ohne WRITE räumt ein
  Admin nur das Eigene weg. Dasselbe Muster wie bei `modifySubscriptions` in
  1.0.4. **Wo CloudKit ein Ergebnis je Element zurückgibt, IST das Ergebnis die
  Fehlermeldung** — gezählt wird seither, was wirklich weg ist, und bleibt alles
  liegen, sagt die App es.
- **`.permissionFailure` beim Schreiben auf einen FREMDEN Datensatz heißt etwas
  anderes** (`mappedMitgliedsschreiben`, ab 1.0.26). In der öffentlichen
  Datenbank gehört ein Datensatz dem, der ihn angelegt hat; der Mitgliedseintrag
  einer Kollegin gehört ihr. Ohne WRITE für die Rolle `_icloud` auf `Member`
  kann kein Admin einen zweiten ernennen, ein Kürzel berichtigen oder jemanden
  entfernen. `mapped` machte daraus „Nur ein Admin darf das" — den einen Satz,
  der hier garantiert falsch ist. Jetzt nennt die Meldung den Weg durch die
  Konsole.
- **Zwei Admins, nicht einer** (`setRole`). Ein einziger Admin ist ein
  Ausfallpunkt: Wird dieses iPad im Sommer zurückgesetzt, kann niemand mehr
  Codes vergeben oder Entwarnung geben. Der Hinweis steht unter der
  Mitgliederliste.
- **Abgeleitete Datensatznamen gegen Doppel:** `member-<Gruppe>-<Nutzer>`,
  `ack-<Alarm>-<Nutzer>`, `device-<Gruppe>-<Nutzer>`, und der
  Beitrittscode IST der Name seines Datensatzes (kein Index, keine
  Abfrage, kein Wettlauf). Ein zweiter Tipp auf „Gesehen" ist damit eine
  Änderung und keine zweite Zeile — und die Zahl der Rückmeldungen ist
  die eine Zahl, auf die im Ernstfall geschaut wird.
- **Subscriptions werden abgeglichen, nicht neu angelegt** (`reconcile`).
  Erst alles löschen und dann neu anlegen ließe das Gerät dazwischen taub
  zurück — und dauerhaft taub, wenn die zweite Hälfte an einer schlechten
  Verbindung scheitert. Das `-v1` in `SubscriptionID` ist dafür da, dass
  ein geändertes Prädikat eine neue Kennung bekommt: Ein Prädikat lässt
  sich nachträglich nicht ändern.
- **Polling ist das Netz unter den Subscriptions, nicht der Weg:** fünf
  Sekunden bei laufendem Alarm, dreißig sonst. Und: **Nur eine Abfrage,
  die GELUNGEN ist und nichts fand, räumt den Alarm-Bildschirm.** Eine
  abgerissene Verbindung darf nie wie eine Entwarnung aussehen.
- **Was ein Hintergrundereignis beendet, gehört auf den HAUPTFADEN**
  (`BackgroundRefresh`, behoben in 1.0.20). `BGTask.setTaskCompleted` und der
  Rückruf von `didReceiveRemoteNotification` schließen für iOS ein
  Hintergrundereignis ab; UIKit schreibt daraufhin den
  Wiederherstellungsstand fort und macht ein Bildschirmfoto. Beides prüft den
  Hauptfaden — und bricht sonst ab: `SIGABRT` aus
  `_performBlockAfterCATransactionCommitSynchronizes:`. Ein nacktes `Task { }`
  in einem nicht isolierten Rückruf erbt KEINEN Actor und landet im
  Nebenläufigkeits-Pool; im Absturzprotokoll steht dann
  `com.apple.root.user-initiated-qos.cooperative` statt `com.apple.main-thread`
  (gemeldet 09/2026). Also: `using: .main` beim Anmelden, `Task { @MainActor in }`,
  und ein Wächter, der genau EINMAL fertigmeldet — ein zweites
  `setTaskCompleted` quittiert iOS ebenfalls mit einem Abbruch. Der Absturz
  sah nach dem Alarm-Bildschirm aus und kam von der Auffrischung; die Zeile
  mit der Warteschlange im Protokoll ist die, die es entscheidet.
- **Ein `async`-Delegat von UserNotifications ist eine FALLE** (behoben in
  1.0.22). `userNotificationCenter(_:didReceive:)` in der `async`-Fassung sieht
  harmlos aus; Swift baut daraus die Fassung mit Rückruf, und der Rückruf läuft
  auf dem Faden, auf dem die async-Funktion ENDET — nach einem
  `await MainActor.run` also im Nebenläufigkeits-Pool. Mit dem Rückruf endet
  für iOS ein Hintergrundereignis, UIKit macht Bildschirmfoto und
  Wiederherstellungsstand, und beides bricht abseits des Hauptfadens ab.
  Kennzeichen im Feld: **Absturz nur beim Tippen auf die Mitteilung, nie beim
  Öffnen über das Symbol** (gemeldet 09/2026). Also immer die Fassung MIT
  Rückruf schreiben und ihn am Ende eines `Task { @MainActor in }` aufrufen.
  Dieselbe Wurzel wie `BackgroundRefresh` in 1.0.20 — wo ein Rückruf ein
  Hintergrundereignis abschließt, gehört er auf den Hauptfaden.
- **Ein Knopf, der „Fertig" heißt, verschluckt Nachrichten** (1.0.22). Im
  Nachrichtenblatt stand oben „Fertig" und unten ein Papierflieger-Symbol; der
  Nutzer tippte zweimal „Fertig" und hielt die Nachricht für gesendet. Jetzt
  heißt der Knopf oben „Schließen", das Senden ist ein breiter Knopf mit dem
  Wort **Senden**, die Eingabetaste sendet ebenfalls, ein Hinweis unter dem
  Feld sagt „noch nicht gesendet", und beim Schließen mit Text im Feld fragt
  die App nach. **Im Ernstfall wäre das dreißigmal passiert.**
- **Die Nachrichten stehen OFFEN auf dem Alarm-Bildschirm** (ab 1.0.22), in
  einer Karte wie die Rückmeldungen — nicht hinter einem Tipp. Wer diesen
  Bildschirm liest, liest ihn unter Druck und tippt nicht auf Verdacht. Die
  Zahl „ungelesen" gibt es deshalb nur noch auf der Karte „Alarm läuft" auf
  dem Startbildschirm, also genau dann, wenn der Alarm-Bildschirm zur Seite
  gelegt ist.
- **`DefaultInstructions.locations` ist eine VORLAGE, kein Bestand.** Was eine
  Schule benutzt, steht auf ihrem Group-Datensatz; eine neue Fassung der App
  ändert das nie von selbst. Deshalb gibt es seit 1.0.22 unter Verwaltung →
  Standorte den Knopf „Vorlage einsetzen" — sonst müsste jemand sechzehn
  Einträge am iPad abtippen.
- **`NSLock.lock()` ist `noasync`** — in einer async-Funktion heute eine
  Warnung, unter Swift 6 ein Fehler. Gesperrt wird deshalb ausschließlich
  über `NSLock.around` (`Backend/Locked.swift`), einen synchronen
  Abschluss: Darin kann nichts suspendieren.
- **Die Prüfliste ist keine Einrichtungshilfe, sie bleibt für immer.**
  Berechtigungen ändern sich hinter dem Rücken der App (Fokus-Ausnahme
  weg, iOS-Update, jemand meldet sich von iCloud ab). Sie wird bei jedem
  Start neu geprüft, und was fehlt, steht als Banner auf dem
  Startbildschirm. **Was iOS nicht herausgibt, wird als Anleitung gezeigt
  und nicht als Häkchen** — ein grünes Häkchen für „nicht nachgesehen"
  wäre die teuerste Lüge, die diese App erzählen kann.
- **Der Zustellnachweis darf die Einrichtung NICHT sperren** (ab 1.0.10).
  Er war Bedingung für „Einrichtung abschließen" — und damit zirkulär: Der
  Nachweis braucht einen Push von einem anderen Gerät, den schickt die
  ein Admin aus der Verwaltung, die Verwaltung liegt hinter dem
  Startbildschirm, der lag hinter „Einrichtung abschließen". Niemand kam
  mehr hinein, auch der Admin nicht, der die Schule gerade angelegt hatte
  (gemeldet 09/2026). Gesperrt wird nur noch, was dieses eine Gerät selbst
  lösen kann (`ChecklistItem.blocksCompletion`); der Punkt bleibt rot, das
  Warnband bleibt stehen, und das iPad gilt weiter als ungeprüft.
  **Allgemein: Was ein zweites Gerät braucht, darf nie Bedingung für den
  ersten Start sein.**
- **Angekommen ist angekommen.** Der Haken „Zustellung geprüft" hängt an
  `store.letzterPush` und setzt sich auf dem EMPFANGENDEN Gerät von selbst.
  Bestätigen muss ihn niemand — ein Knopf „ist angekommen" wäre eine
  Behauptung, der Zeitstempel ist eine Tatsache.
- **Die Rolle heißt „Admin", nicht „Leitung"** (ab 1.0.14, Ansage des Nutzers,
  09/2026). Nur das Wort in der Oberfläche; der Rohwert der Aufzählung war
  immer schon `admin` und bleibt es — an ihm hängen Datensätze, die auf den
  Geräten liegen.
- **Die Namen der Rückmeldungen sehen Admin UND auslösende Person** (ab
  1.0.14, `AppModel.darfRueckmeldungenSehen`). Dieselbe Regel wie bei
  `mayClear` und aus demselben Grund: Wer ausgelöst hat, steht am Ort und
  muss wissen, wer sich noch nicht gemeldet hat — auf ein fremdes iPad zu
  warten hilft dort niemandem. Für alle anderen bleibt es bei der blanken
  Zahl; wer sich wann gemeldet hat, geht das Kollegium untereinander nichts
  an. **Unter der Liste steht, was sie NICHT ist:** Sie zeigt, wer
  geantwortet hat, nicht, wer den Alarm bekommen hat. Eine
  Zustellbestätigung gibt CloudKit nicht her, und ein Kürzel, das fehlt,
  darf nie als „hat es nicht bekommen" gelesen werden.
- **Keine iOS-App holt sich selbst in den Vordergrund** (Wunsch des Nutzers,
  09/2026: „Im Alarmfall soll die App sichtbar im Vordergrund sein."). Es gibt
  dafür keine Schnittstelle — nicht über kritische Hinweise, nicht über die
  Custom-App-Verteilung, nicht über Jamf School; ein Push kann eine App weder
  starten noch nach vorn bringen. Nach vorn kommt die MITTEILUNG, und ein Tipp
  darauf öffnet die App direkt auf dem Alarm-Bildschirm. Das nie anders
  darstellen. Was ein Gerät dauerhaft auf diese App festnagelt, ist der
  Einzel-App-Modus des MDM — sinnvoll für ein festes Gerät, unsinnig für das
  Arbeits-iPad einer Lehrkraft.
- **Ab dem Augenblick, in dem die App vorne IST, liegt der Alarm oben** (ab
  1.0.15). Drei Dinge dafür, und alle drei waren vorher falsch:
  - **Ein offenes Blatt macht sich zu** (`AppModel.offenesBlatt`,
    `zeigeAlarmBildschirm`). Ein Sheet und der `fullScreenCover` des
    Alarm-Bildschirms sind beide modal, und iOS zeigt davon zuverlässig nur
    das erste: Wer die Verwaltung offen hatte, sah beim Alarm weiter die
    Mitgliederliste. Deshalb liegt der Zustand der drei Blätter im Modell und
    nicht als `@State` in `HomeView` — im Alarmfall muss ihn jemand anderes
    zumachen können. Die 300 ms danach sind die Umdrehung, die SwiftUI zum
    Zumachen braucht; ohne sie verschluckt UIKit die zweite Darstellung.
  - **Der Bildschirm bleibt an, solange ein Alarm läuft**
    (`isIdleTimerDisabled` im `didSet` von `activeAlarm`). Ein iPad, das sich
    nach zwei Minuten sperrt, nimmt den Alarm-Bildschirm mit.
  - **„Zur Seite legen" bleibt liegen** (`zurueckgestellt`). Bis 1.0.14 setzte
    jeder Nachfasslauf `showsAlarmScreen` wieder auf `true` — der Knopf hielt
    also fünf Sekunden. Und er geht erst auf, NACHDEM jemand geantwortet hat:
    vorher wäre er eine Abkürzung an der einen Handlung vorbei, um die diese
    App gebaut ist. Ein neuer Alarm holt den Bildschirm immer zurück.
- **Den Gruppenchat gab es seit der ersten Fassung — gefunden hat ihn niemand**
  (Bitte des Nutzers 09/2026 um genau das, was schon da war). Der Knopf hieß
  „Nachrichten zum Alarm", stand UNTER der Rückmeldeliste und war auf einem
  vollen, scrollenden Alarm-Bildschirm unsichtbar. Seit 1.0.21 steht er direkt
  unter Rückmeldung und Notruf, heißt „Nachricht an das Kollegium", ist gefüllt
  gezeichnet und zählt ungelesene mit. Dieselbe Lehre wie beim Zurücksetzen in
  Tafelbild: **Ein Knopf, den niemand findet, ist kein Knopf** — und eine Bitte
  um etwas Vorhandenes ist ein Befund über die Oberfläche, keine Verwechslung.
- **Nachrichten kommen jetzt auch an, wenn die App hinten liegt**
  (`message-created-v1`, ab 1.0.21). Vorher holte sie nur der Nachfasslauf, und
  der läuft nur, solange die App vorn ist: Wer das iPad weggelegt hatte, erfuhr
  nichts. Das Abonnement ist bewusst ein eigenes und bewusst leiser — `.active`
  statt `.timeSensitive`, Standardton statt Alarmton, KEIN `collapseID` (jede
  Nachricht ist eine eigene und darf die vorherige nicht ersetzen; gruppiert
  wird über `threadIdentifier`). Und es holt den Alarm-Bildschirm NICHT zurück:
  Wer ihn zur Seite gelegt hat, hat das gemeint. Die drei `desiredKeys` sind
  `senderName`, `text`, `alarmId` — Letzteres als NAME, weil eine Referenz im
  Push als Wörterbuch ankommt und gegen die Dreiergrenze zählt.
- **Eine Rückmeldung beendet KEINEN Alarm** — das tut nur die Entwarnung.
  „Gesehen" heißt „ich weiß Bescheid", nicht „es ist vorbei". Genau eine
  Ausnahme: der gezielte Probealarm (Zustelltest). Der räumt sich mit der
  Rückmeldung selbst weg, sonst bliebe jeder Test für immer „aktiv" — und
  ein Stapel alter Tests wurde der Reihe nach zum laufenden Alarm, das iPad
  klingelte immer wieder (gemeldet 09/2026). Zusätzlich verfällt ein
  gezielter Probealarm nach zehn Minuten (`Alarm.giltNoch`): Er ist in
  Sekunden zu sehen oder gar nicht. **Echte Alarme verfallen nie** — ein
  Amokalarm, den seit zwei Stunden niemand entwarnt hat, ist gültig; die
  Entwarnung beendet ihn, nicht die Uhr.
- **„Alle laufenden Alarme beenden"** (Verwaltung → Nachbereitung) ist der
  Ausweg, wenn sich doch etwas aufstaut. Nur Admins, nur ausdrücklich
  getippt.
- **Der Countdown vor dem Auslösen ist fünf Sekunden und bleibt.** Ein
  Fehlalarm kostet eine Schule mehr als die fünf Sekunden — beim nächsten
  echten Alarm zuckt niemand mehr.
- **Der zweite Bildschirm zeigt NIE den Alarm** (eigene Szene in
  `Config/Info.plist`, `ExternalDisplaySceneDelegate`). Sonst erführe die
  Klasse die Bedrohungslage vor der Kollegin nebenan. Was die App nicht
  kontrollieren kann, ist das System-Banner davor — das spiegelt iOS. Ob
  die Sperrbildschirm-Vorschau den Alarmtext zeigt, entscheidet das
  Krisenteam im Konfigurationsprofil, nicht die App.
- **Vier Alarmtöne, und die Lautstärke steckt in der DATEI** (ab 1.0.30, Ansage
  des Nutzers 09/2026: Probealarme sollen vor den Kindern verborgen bleiben).
  `alarm.wav` (laut) plus `dezent.wav`, `holz.wav`, `tropfen.wav` — auf 0,22 bis
  0,32 Spitze gerechnet statt 0,92. Ein Lautstärkeregler wäre wirkungslos:
  Kritische Hinweise spielen seit 1.0.29 mit `withAudioVolume: 1.0`, unabhängig
  vom Gerät. Alle Töne rechnet `scripts/make-sounds.py`.
- **Der Name ist fest, die Datei wechselt** (`Alarmklang.swift`,
  `PushAsset.signalSound`). Die Erweiterung setzt den Ton und kann die Wahl der
  Lehrkraft NICHT kennen — eigener Prozess, eigener Behälter. Eine gemeinsame
  Einstellung bräuchte eine **App-Gruppe** und damit eine Entitlements-Datei an
  der Erweiterung; das ist die eine Sache, die dieses Projekt unsignierbar
  macht. Also nennt die Erweiterung immer `signal.wav`, und die App legt den
  gewählten Ton unter diesem Namen in `Library/Sounds` ab —
  `Klanginstallation.sicherstellen` bei jedem Start und sofort beim Wechseln.
  **`signal.wav` darf nie ins Bündel**, sonst ist nicht entschieden, welche
  Fassung `UNNotificationSound(named:)` nimmt. Fehlt die Datei, spielt iOS den
  Standardton — nicht den gewählten, aber auch nie gar nichts.
- **Ein eigener Ton wird umgerechnet UND leise gemacht** (`Eigenklang.swift`,
  ab 1.0.32). Drei Fallen, jede davon still: (1) iOS nimmt als Mitteilungston
  nur PCM/MA4/µ-law/a-law in WAV, AIFF oder CAF — eine MP3 wird nicht
  abgelehnt, sondern durch den STANDARDTON ersetzt, ohne Fehler; also wird
  alles, was AVFoundation lesen kann, in 16-Bit-PCM-WAV umgerechnet. (2) Über
  30 Sekunden spielt iOS gar nichts — lieber beim Übernehmen mit einem klaren
  Satz abweisen. (3) Eine mitgebrachte Datei ist meist bis Vollausschlag
  ausgesteuert, und kritische Hinweise spielen mit `withAudioVolume: 1.0`:
  ungebremst wäre der erste eigene Ton auf dreißig iPads unerwartet laut,
  ausgerechnet in der Lage, für die die leisen Töne gebaut wurden. Normiert
  wird deshalb auf dieselbe Spitze wie „Holzton" — **nach oben wie nach
  unten**, denn eine sehr leise Aufnahme wäre im Ernstfall wertlos.
  Geschrieben wird neben das Ziel und dann getauscht; ein halb geschriebener
  Alarmton wäre schlimmer als der alte.
- **`Alarmklang.quelle` ist die eine Stelle, an der Bündel und eigener Ton
  zusammenlaufen.** Die vier eingebauten liegen im App-Bündel, der eigene in
  Application Support. Wer die Unterscheidung woanders noch einmal trifft
  (Tonprobe, Installation), baut den zweiten Weg ein zweites Mal. Und ein
  gewählter eigener Ton, dessen Datei fehlt, gilt NICHT: `store.alarmklang`
  fällt auf `.alarm` zurück, sonst käme der Alarm mit dem iOS-Standardton.
- **Der Rückfall-Ton eines Abonnements lässt sich nachträglich nicht ändern.**
  `info.soundName` nennt seit 1.0.30 `signal.wav`, aber `reconcile` legt nur an,
  was FEHLT — schon eingerichtete Geräte behalten `alarm.wav` als Rückfall bis
  zum Neuaufsetzen. Ein Abonnement dafür zu löschen und neu anzulegen wäre der
  empfindlichste Weg dieser App für einen Ton, der nur bei ausgefallener
  Erweiterung spielt. Nicht nachrüsten.
- **Kritische Hinweise sind AN — seit 1.0.29** (von Apple bewilligt am
  08.09.2026 für die App-Id `de.dboschule.alarm`). Bis dahin durfte das
  Entitlement nirgends stehen: Eine Entitlements-Datei, die es ohne Bewilligung
  nennt, lässt jedes Signieren scheitern. Jetzt steht
  `com.apple.developer.usernotifications.critical-alerts` in BEIDEN
  Entitlements-Dateien, und `CRITICAL_ALERTS` steht in
  `SWIFT_ACTIVE_COMPILATION_CONDITIONS` an den **Projekt**-Konfigurationen
  Debug und Release — beide Ziele erben es, die Erweiterung braucht es genauso,
  denn sie setzt `interruptionLevel`. **Drei Dinge müssen zusammenkommen, und
  jedes kann einzeln fehlen:** Entitlement (Apple), Compilerbedingung (Repo),
  Erlaubnis auf dem Gerät (die Lehrkraft). Fehlt das dritte, ist die App nicht
  kaputt — der Quelltext fällt in jedem Zweig auf `.timeSensitive` zurück, und
  die Prüfliste zeigt die Zeile rot.
- **Eine Compilerbedingung weiß nichts über die ERLAUBNIS auf dem Gerät**
  (`Shared/Meldungsstufe.swift`, ab 1.1.0/Build 42). **Das war die erste
  Ablehnung durch Apple** (Guideline 2.1(a), 17.09.2026, iPad Air 11" /
  iPadOS 27): „the Tontest starten button was unresponsive, even when we put
  the device in standby it was not woken up". Der Knopf war nicht kaputt —
  `interruptionLevel = .critical` und `criticalSoundNamed(…)` brauchen ZWEI
  Dinge, das Entitlement UND die Erlaubnis des Menschen, und ohne die zweite
  weist `add(_:)` die Anfrage ab. `Tontest` und `AlarmReminder` fragten aber nur
  `#if CRITICAL_ALERTS`. Der Prüfer hatte kritische Hinweise nicht erlaubt;
  damit war jede dieser Mitteilungen von vornherein abgewiesen. **Schlimmer als
  die Ablehnung ist der Feldfehler dahinter:** Auf jedem Gerät, dessen Lehrkraft
  kritische Hinweise abgelehnt hat, entstand keine einzige der zehn
  Erinnerungen — der Push kam, das Netz danach fehlte, still. Die Entscheidung
  steht jetzt an EINER Stelle, liegt in `Shared/` (App UND Erweiterung, also
  sechs Einträge im pbxproj) und liest `criticalAlertSetting` zur Laufzeit; der
  Rückfall ist `.timeSensitive` mit demselben Ton. **Wer eine neue Mitteilung
  baut, setzt Stufe und Ton über `Meldungsstufe.setze` und nirgends von Hand.**
  Und: Die Falle stand in `requestAuthorization` wörtlich beschrieben („it
  simply never succeeds, which is the kind of quiet defect this app cannot
  afford") — ein Kommentar ersetzt keine Prüfung.
- **Diese App sperrt niemanden aus — sie SAGT, was fehlt** (ab 1.1.0/Build 43).
  **Das war die zweite Ablehnung durch Apple** (Guideline 4.5.4, 19.09.2026,
  iPad Air 11"): „The app requires push notifications in order to function.
  Push notifications must be optional and must obtain the user's consent to be
  used within the app." Der Prüfer hatte recht. „Einrichtung abschließen" war
  grau, solange eine Mitteilungszeile rot stand (`ChecklistItem.blocksCompletion`,
  `AppModel.finishBlockers`) — wer die Systemfrage mit „Nicht erlauben"
  beantwortete, kam aus der Einrichtung nie wieder heraus: kein Auslösen, keine
  Verwaltung, keine Prüfliste. Dieselbe Sackgasse wie 1.0.10 beim
  Zustellnachweis, nur eine Etage tiefer und diesmal vollständig — und 1.0.10
  hatte die Lehre schon aufgeschrieben („Was ein zweites Gerät braucht, darf
  nie Bedingung für den ersten Start sein"), nur nicht zu Ende gezogen. Der
  Sperrmechanismus ist deshalb **ersatzlos aus dem Quelltext entfernt**, nicht
  auf „false" gestellt: Ein Feld, das nur noch falsch sein darf, wird
  irgendwann wieder wahr. **Wer einen Knopf ausgraut, solange etwas fehlt,
  holt diese Ablehnung zurück.**
- **Ohne Mitteilungen bleibt die App benutzbar, und das steht auch da**
  (`Views/OhneMitteilungenView.swift`, ab 1.1.0/Build 43). Auslösen,
  Rückmelden, Nachrichten, Entwarnen, Verwaltung und Diagnose hängen an keiner
  Erlaubnis, und die Abfrage (fünf Sekunden bei laufendem Alarm, sonst
  dreißig) läuft unabhängig davon — eine offene App zeigt einen Alarm also
  binnen Sekunden von selbst. Was fehlt, ist der Ton bei hinten liegender App,
  der Nachfasslauf und der Tontest. Die Seite zählt beides Punkt für Punkt auf
  und redet nichts schön; der Satz „dieses Gerät ist dann kein Alarmgerät,
  sondern eine Ansicht" steht ausdrücklich darin.
- **Die Einwilligung wird IN der App eingeholt, erklärt, und nie von selbst.**
  Ein eigener Abschnitt „Mitteilungen — freiwillig" steht in der Einrichtung
  UND dauerhaft in den Einstellungen (wer beim ersten Start ablehnt, käme sonst
  nie wieder daran vorbei); daneben immer der Weg zu „Was ohne Mitteilungen
  geht". Den Systemdialog löst ausschließlich ein Tipp aus — beim Start fragt
  die App nichts (`kritischeHinweiseNachfragen` ist an `.authorized` gebunden
  und kommt damit erst nach einer Zusage zum Zug). Und `melde(abgewiesen:)`
  meldet einen Ausfall nur als FEHLER, wenn die Erlaubnis da ist: Wer sie
  bewusst verneint hat, bekommt einen Hinweis statt eines roten Bandes — eine
  App, die eine getroffene Entscheidung als Störung ausgibt, drängt.
- **Eine verweigerte Kamera ist kein schwarzer Bildschirm** (`QRCodeView`, ab
  1.1.0/Build 44, im eigenen Durchgang gefunden). `configure()` bestand aus drei
  `guard … else { return }`: Ohne Erlaubnis — oder im Simulator, oder auf einem
  Gerät ohne Kamera — wurde nichts eingerichtet, und stehen blieb eine schwarze
  Fläche ohne ein Wort. **Das ist genau die Form der ersten Ablehnung** („the
  button was unresponsive"), nur an einem anderen Knopf; getroffen hätte es auch
  jede Lehrkraft, die die Kamerafrage einmal verneint hat. Jetzt entscheidet
  `AVCaptureDevice.authorizationStatus` vorher: noch nie gefragt → fragen,
  verweigert → ein Satz, ein Knopf in die Einstellungen und der Hinweis auf den
  Weg daneben. **Der Weg daneben ist der wichtigere** — den sechsstelligen Code
  kann man abtippen. Die Kamera ist eine Abkürzung, nie eine Bedingung; dieselbe
  Regel wie bei den Mitteilungen, und beide Male hat Apple sie uns beigebracht.
  **Merke: Jeder `guard … else { return }` in einem Einrichtungsweg ist ein
  stummer Knopf, bis das Gegenteil bewiesen ist.**
- **Das Wort „Platzhalter" gehört nicht in die Oberfläche** (ab 1.1.0/Build 44).
  Die Handlungstexte begannen mit „Platzhalter — bitte mit Schulleitung und
  Polizei abstimmen". Gemeint war die SCHULE, gelesen wird es über die APP:
  Guideline 2.1 nennt „placeholder text" ausdrücklich als Ablehnungsgrund, und
  ein Prüfer sieht diesen Bildschirm, sobald er einen Alarm auslöst. Der Satz
  sagt jetzt dasselbe von der Schule her („Diese Schule hat noch keinen eigenen
  Text hinterlegt … verbindlich wird der Wortlaut erst, wenn …"). **An der Sache
  ändert sich nichts** — die Texte bleiben erkennbar unfertig, und genau das ist
  ihr Sinn: Ein Text, der bloß amtlich klingt, ist gefährlicher als ein sichtbar
  unfertiger. Geändert hat sich nur, worüber der Satz spricht.
- **Kein Name eines MDM-Anbieters in einem Oberflächentext** (ab 1.1.0/Build 44).
  `BackendAvailability.restricted` sagte „bitte an die Jamf-Administration
  wenden". Für eine Schule, die Jamf benutzt, ist das hilfreich; für einen
  Prüfer bei Apple ist es das Kennzeichen einer Firmen-App, die in den
  öffentlichen Laden nicht gehört (Guideline 4.3, dieselbe Ecke wie „nur an
  Schul-iPads"). Es heißt jetzt „Das gibt die Geräteverwaltung vor" — richtig
  für jedes MDM und ohne Firmenschild. Die Anleitung für Jamf bleibt im Papier,
  wo sie hingehört.
- **Der Meldeweg gehört AN den Inhalt** (`AlarmChatView`, `Hilfeadressen.meldung(zu:)`,
  ab 1.1.0/Build 44). Es gab ihn (Einstellungen → Hilfe), aber dort findet ihn
  niemand, der gerade etwas liest, das dort nicht stehen sollte — dieselbe Lehre
  wie beim Gruppenchat selbst, den bis 1.0.21 niemand fand. Apples Regel zu von
  Nutzern eingestelltem Inhalt verlangt genau das. Jede Nachricht trägt jetzt ein
  „…"-Menü mit „Diese Nachricht melden"; die Mail ist mit Kürzel, Uhrzeit,
  Kennung und Wortlaut vorbelegt, **abgeschickt wird sie vom Menschen** — eine
  Mail, die die App still hinausschickt, wäre keine Meldung, sondern eine
  Übermittlung.
- **Wer nur die Dateigröße braucht, fragt nach der Größe** (`Alarmklang.befund`,
  ab 1.1.0/Build 44). `attributesOfItem` holt das ganze Attributbündel und damit
  die Datei-ZEITSTEMPEL — die stehen auf Apples Liste der
  begründungspflichtigen Schnittstellen, und ein Prüflauf streicht sie an
  (ITMS-91053). `resourceValues(forKeys: [.fileSizeKey])` steht auf keiner
  Liste. Eine Begründung in `PrivacyInfo.xcprivacy` einzutragen wäre der andere
  Weg gewesen und der schlechtere: Sie wäre unwahr, denn gelesen wird kein
  Zeitstempel.
- **Kontolöschung: Es gibt kein Konto** (Guideline 5.1.1(v), festgehalten
  09/2026). Die App legt keines an — sie benutzt die Apple-ID, die auf dem Gerät
  schon angemeldet ist, und fragt weder E-Mail noch Kennwort. Was sie anlegt,
  ist eine MITGLIEDSCHAFT, und die löscht „Verbindung zur Schule lösen" samt der
  Abonnements dieses Geräts. Rückmeldungen und Nachrichten bleiben bewusst
  stehen: Sie sind ein Nachweis, der der Schule gehört, und nach 90 Tagen räumt
  sie das Aufräumen ohnehin weg. **Das gehört in die Prüfhinweise**, auch wenn
  niemand danach fragt — die Frage kommt sonst als Ablehnung.
- **`try?` an einer Mitteilung ist verboten.** Dasselbe `try?`, das den
  Ablehnungsgrund verschluckte, hat die App die erste Einreichung gekostet: Der
  Prüfer tippte, iOS wies ab, der Knopf schwieg. `Tontest.starten` gibt seither
  einen Befund zurück (geplant, oder der ROHE Fehlertext), `AlarmReminder`
  zählt die abgewiesenen und meldet den vollständigen Ausfall, und
  `AppModel.runTontest` zeigt beides. „Ein Knopf, der schweigt, ist für den
  Menschen davor ein kaputter Knopf" stand seit 1.0.26 im Papier — für diesen
  Knopf galt es nicht. **Bei jedem neuen Knopf prüfen, ob er im Fehlerfall
  etwas sagt.**
- **Ein Prüfer von Apple geht die Prüfliste nicht durch.** Er tippt auf den
  größten Knopf. Deshalb fragt der Tontest die Mitteilungserlaubnis selbst
  nach, wenn sie noch nie erfragt wurde, statt an ihr zu scheitern — und die
  Prüfhinweise bitten seit der Ablehnung ausdrücklich darum, beide
  Erlaubnisdialoge mit „Erlauben" zu beantworten. **Was ein Mensch übersehen
  kann, darf keine Sackgasse sein.**
- **Wer die Erlaubnis erst nachträglich braucht, muss NACHGEFRAGT werden**
  (`NotificationCenterService.kritischeHinweiseNachfragen()`, ab 1.0.29).
  `requestAuthorization` läuft nur beim Einrichten; die dreißig iPads, die vor
  der Bewilligung eingerichtet wurden, hätten die Frage nie gesehen und wären
  bei stummem Gerät still geblieben — obwohl die Fassung dafür gebaut ist.
  Gefragt wird bei jedem Start, solange die Erlaubnis fehlt; hat iOS die Frage
  einmal beantwortet, zeigt es sie nicht wieder und der Aufruf kehrt still
  zurück. **Allgemein: Eine Berechtigung, die eine neue Fassung zusätzlich
  braucht, erreicht die schon eingerichteten Geräte nur, wenn jemand sie dort
  ausdrücklich nachfragt.**
- **Handlungstexte sind Platzhalter, die als solche zu erkennen sind.**
  Was im Ernstfall dort steht, gehört mit Schulleitung, Polizei und
  Feuerwehr abgestimmt; ein Text, der bloß amtlich klingt, ist schlimmer
  als ein sichtbares Leerfeld.
- **Töne und App-Symbol werden gerechnet, nicht geladen**
  (`scripts/make-sounds.py`, `scripts/make-icon.py`, reines Python ohne
  fremde Bibliotheken). Über 30 Sekunden spielt iOS einen Mitteilungston
  gar nicht ab — das Skript bricht vorher ab, damit der Fehler beim
  Erzeugen auffällt und nicht auf dem Gerät.
- `MARKETING_VERSION` und `CURRENT_PROJECT_VERSION` stehen an **vier**
  Stellen im pbxproj (App Debug+Release, Erweiterung Debug+Release) und
  müssen überall gleich sein — eine Erweiterung mit abweichender Nummer
  weist App Store Connect ab. Es gibt KEINE Skript-Bauphase. **Jede
  Arbeitseinheit hebt Patch- UND Build-Nummer um je +1**, ohne Nachfrage,
  als Teil des PRs. Zählung ab 09/2026: 1.0.0 (Build 1), dann 1.0.1
  (Build 2), 1.0.2 (Build 3), 1.0.3 (Build 4), 1.0.4 (Build 5) usw. Dazu gesetzt (Ansage des Nutzers,
  09/2026): `DEVELOPMENT_TEAM = F4989GSTWS` — dieselbe Id wie Schulalarm und
  Tafelbild — und `INFOPLIST_KEY_LSApplicationCategoryType =
  public.app-category.navigation`. Beides steht als Build-Einstellung, weil
  das Ziel `GENERATE_INFOPLIST_FILE = YES` benutzt.
- **1.1.0 (Build 39) ist die Fassung, die in den App Store geht** (Ansage des
  Nutzers, 09/2026: „Ich möchte gerne ein einigermaßen rundes Bild
  einreichen."). Der Sprung von 1.0.37 ist bewusst und derselbe Gedanke wie bei
  Tafelbild 1.4.0: Was hier eingereicht wird, ist keine achtunddreißigste
  Nachbesserung, sondern die erste öffentliche Fassung. Die siebenunddreißig
  Stände davor gab es nur im Repo und über TestFlight; niemand außerhalb hat
  sie je gesehen. **Die Marken „ab 1.0.x" in diesem Papier bleiben stehen** —
  sie sagen, wann etwas in den Quelltext kam, und das ändert sich durch eine
  Umbenennung nicht. Danach zählt es wie gewohnt weiter: 1.1.1, 1.1.2 …
  **Solange 1.1.0 noch nicht hochgeladen ist, hebt eine Arbeitseinheit nur die
  BUILD-Nummer** (39 → 40 → …) und lässt die 1.1.0 stehen. Die Patch-Nummer zu
  heben verschöbe genau den runden Stand, um den der Nutzer gebeten hat; die
  Build-Nummer ist davon unabhängig und muss ohnehin nur steigen. Ab dem ersten
  angenommenen Upload gilt wieder die normale Regel: beides um je +1.
- `ITSAppUsesNonExemptEncryption = NO` steht in beiden Info.plists und als
  Build-Einstellung — nicht entfernen.
- **Die Erweiterung hat KEINE Entitlements-Datei, und das bleibt so.**
  `com.apple.developer.usernotifications.time-sensitive` gehört
  ausschließlich an das App-Ziel. Beim ersten Signieren stand es auch in
  der Erweiterung — mit der Folge „Entitlement … not found and could not be
  included in profile": Für die App-Id einer Erweiterung gibt es diese
  Fähigkeit nicht, Xcode bietet sie dort nicht einmal an, und die
  automatische Signierung findet daraufhin gar kein Profil mehr. Gebraucht
  wird sie dort auch nicht — die Mitteilung gehört der App, und an deren
  Entitlement prüft iOS, ob `.timeSensitive` gilt. Wer der Erweiterung
  wieder eine Entitlements-Datei gibt, macht das Projekt unsignierbar.
- **Für den öffentlichen Laden muss die App JEDER Schule gehören** (ab 1.0.35).
  Apple weist Apps zurück, die erkennbar nur einer einzelnen Einrichtung nützen
  — dafür gibt es die Custom Apps. Die Review-Notizen begannen bis 1.0.34
  wörtlich mit „internal … app for the staff of a single German primary school
  … not intended for the public App Store": derselbe Text, der bei Apple
  eingereicht wird. Die Sache stimmt ja auch gar nicht — wer die App
  installiert, richtet sich seine eigene Schule ein, und die Schulen wissen
  nichts voneinander. Der Text sagt das jetzt zuerst.
- **Nachrichten im Alarm sind von Nutzern eingestellter Inhalt** (ab 1.0.35).
  Damit gilt Apples Regel dazu: ein Weg zu melden, ein Weg, jemanden
  loszuwerden, und eine erreichbare Adresse. Das Entfernen gab es schon
  (Verwaltung → Mitglieder, dazu den Code zurückziehen); dazugekommen sind der
  Abschnitt „Hilfe" in den Einstellungen und `Services/Hilfeadressen.swift` —
  die drei Adressen an EINER Stelle, sonst lauten sie irgendwann verschieden.
- **Der Prüfer richtet seine EIGENE Schule ein, er tritt keiner bei**
  (`docs/APP_REVIEW_NOTES.md`, ab 09/2026). Wer über einen Code beitritt, ist
  seit 1.0.13 Mitglied und kein Admin — und ein Mitglied sieht die Auswahl
  „PROBEALARM" gar nicht, weil Probealarme Admins vorbehalten sind. Die
  Prüfhinweise verlangten aber genau das: mit Code beitreten und einen
  Probealarm auslösen. Sie nannten obendrein einen Knopf („Testalarm an dieses
  Gerät senden"), den es seit 1.0.12 nicht mehr gibt. Beides sind vermeidbare
  Ablehnungsgründe: Findet ein Prüfer nicht, was die Notizen versprechen,
  lehnt er ab. Mit „Schule einrichten" ist der Prüfer Admin seiner eigenen,
  getrennten Gruppe — kein Beitrittscode, keine Berührung mit echten Daten.
  **Nach jeder Änderung an Rollen, Knöpfen oder Einrichtungsablauf gehören die
  Prüfhinweise mitgezogen.**
- **iCloud-Konto und App-Store-Konto sind zwei Paar Schuhe** (festgehalten
  09/2026 in `docs/VERTEILUNG_JAMF_SCHOOL.md`, Abschnitt 3b). Schulalarm hängt
  am **iCloud**-Konto (Einstellungen → ganz oben) — daran erkennt CloudKit die
  Lehrkraft, daran hängen Mitgliedschaft, Rolle und Rückmeldungen. TestFlight
  hängt an **Medien & Käufe** (Einstellungen → App Store). Beide dürfen
  verschieden sein, und oft ist das die einzige Aufteilung, die geht: schulische
  Apple-ID für iCloud, eine andere für die Installation. **Ohne iCloud-Konto
  läuft die App gar nicht** — auch nicht bei gerätebasierter Zuweisung über
  Jamf, die sonst ganz ohne Apple-ID installiert. Beim Vorbereiten eines Geräts
  ist das die erste Frage, nicht die letzte.
- **Die Nutzungsbedingungen stehen auf einer SEITE, nicht in der App**
  (`docs/schulalarm/nutzungsbedingungen.html`, ab 1.1.0/Build 40). Ein Text, der
  sich ändern muss — ein Satz nach einer Rückfrage —, darf nicht an einer
  Fassung hängen, die erst durch Apples Prüfung muss; und die dreißig schon
  eingerichteten iPads läsen dann die alte. Verlinkt ist er im Abschnitt
  „Hilfe" der Einstellungen (`Hilfeadressen`), auf der Support-Seite und in App
  Store Connect. **Die Klausel ist bewusst ENG**: Haftung nur für Vorsatz und
  grobe Fahrlässigkeit (§ 521 BGB entsprechend, weil kostenlos), aber
  ausdrücklich NICHT ausgeschlossen für Leben, Körper, Gesundheit, wesentliche
  Vertragspflichten und das Produkthaftungsgesetz. Ein Rundum-Ausschluss wäre
  nach § 309 Nr. 7 BGB unwirksam — und zwar GANZ, es gibt keine erhaltende
  Reduktion. Eine zu weite Klausel schützt also schlechter als eine enge. **Wer
  hier etwas hinzufügt, prüft zuerst, ob es diese Ausnahmen antastet.**
- **Kein Gewerbe, keine Anschrift — Punkt** (Ansage des Nutzers, 09/2026, nach
  einer früheren Überlegung in die andere Richtung). Die App wird als PRIVATE
  Person unentgeltlich angeboten: keine Einnahmen, keine Werbung, keine Käufe in
  der App. Unter „Anbieter" stehen deshalb Name und E-Mail und sonst nichts; die
  Impressumspflicht des § 5 DDG trifft geschäftsmäßige Dienste, nicht ein rein
  privates, kostenloses Angebot. **Wer hier je wieder eine Adresse einbaut,
  fragt vorher.**
- **Die eine Stelle, an der eine Anschrift trotzdem öffentlich würde, ist der
  HÄNDLERSTATUS** in App Store Connect (Digital Services Act). Wer dort
  „Händler" angibt, dessen Name, Anschrift und Telefonnummer zeigt Apple auf der
  Produktseite an. Für dieses Angebot ist „kein Händler" die zutreffende Angabe.
  Steht in der Einreichungsliste; nicht nebenbei wegklicken.
- **Was wirklich schützt, ist die Ehrlichkeit der App selbst.** Keine Zusage
  über die Zustellung, kein grünes Häkchen für „nicht nachgesehen", die
  Rückmeldeliste, die sagt, was sie NICHT ist. Diese Linie ist deshalb nicht nur
  eine Frage des Anstands, sondern das, was einer Zusicherung am ehesten den
  Boden entzieht. **In der Store-Beschreibung nie „zuverlässig", „sicher",
  „garantiert" oder „in Sekunden" versprechen** — genau daraus wird sonst eine
  Beschaffenheitsvereinbarung.
- **Datenschutz- und Hilfeseite liegen in `docs/schulalarm/`** und werden vom
  Pages-Ablauf mitgeliefert:
  `https://katonid.github.io/prae/schulalarm/datenschutz.html` und
  `.../support.html`. Die Datenschutz-URL ist **Pflichtfeld schon für eine
  externe TestFlight-Gruppe**, nicht erst für den Laden. Die Seite benennt die
  Grenzen der öffentlichen CloudKit-Datenbank ausdrücklich (der Entwickler kann
  die Datensätze einsehen; wer den Beitrittscode hat, kommt in die Gruppe) —
  dieselbe Ehrlichkeit wie im README, nicht schönreden.
- **Für den Probelauf: externe TestFlight-Gruppe mit öffentlichem Link.** Die
  acht Zeichen hinter `testflight.apple.com/join/` sind ein Code, der sich in
  der TestFlight-App unter „Code einlösen" eintippen lässt — es braucht also
  KEINE Einladungsmail, was schulische Apple-IDs ohne Postfach sonst
  ausschlösse. Den Link gibt es nur für externe Gruppen und erst nach
  bestandener Beta App Review; einen Termin im Kollegium also danach ansetzen.
  Ob eine Managed Apple ID TestFlight überhaupt darf, hängt an Rolle und
  ASM-Einstellungen — an EINEM Gerät ausprobieren, bevor dreißig Leute
  eingeladen werden. **Ein TestFlight-Bau läuft nach 90 Tagen ab**; für den
  Dauerbetrieb einer Alarm-App taugt er deshalb nicht.
- **Der App-Eintrag wird VON HAND in App Store Connect angelegt**, nie über
  Xcodes „Create App Record" im Distribute-Ablauf (gemeldet 09/2026:
  „App Record Creation failed due to request containing an attribute already
  in use"). Xcode schlägt dort den Anzeigenamen vor, und `Schulalarm` ist
  vergeben — App-Namen sind bei Apple weltweit eindeutig, **auch für Custom
  Apps**, die nie im öffentlichen Laden auftauchen. Derselbe Fehler wie bei
  Anstoß, dieselbe Lösung: freier Store-Name, Eintrag von Hand, dann lädt
  Distribute über die Bundle-Id hinein. Vergeben ist seit 09/2026
  **„Schulalarm - Der Warnmelder"** (Ansage des Nutzers). **Store-Name und Homescreen-Name sind getrennte Felder**
  und dürfen auseinandergehen; `INFOPLIST_KEY_CFBundleDisplayName` bleibt
  „Schulalarm", Ordner, Ziel, Bundle-Id und iCloud-Container bleiben ebenfalls.
  Das Archiv muss dafür nicht neu gebaut werden.
- **Ein Bau in GitHub Actions beweist NICHT, dass sich signieren lässt.**
  Er läuft mit `CODE_SIGNING_ALLOWED=NO` gegen den Simulator; Entitlements
  werden dabei nie geprüft. Alles, was mit Profilen, App-Ids und
  Fähigkeiten zu tun hat, fällt erst auf dem Mac des Nutzers auf. Einen
  grünen Bau also nie als „signierbar" ausgeben.
- **Offen: der Zustellnachweis.** Ob der Alarm auf einem gesperrten iPad
  mit aktivem Fokus binnen zehn Sekunden hörbar ankommt, lässt sich nur
  auf zwei echten Geräten messen — nicht im Simulator, nicht in GitHub
  Actions. Das Messprotokoll samt Abbruchkriterium steht in
  `AlarmiOS/docs/ZUSTELLTEST.md`. Scheitert es, ist der Ersatz ein
  winziger eigener APNs-Sender hinter demselben Protokoll, nicht ein
  anderes Backend. **Diesen offenen Punkt nicht als erledigt darstellen.**
- Übersetzt wird in GitHub Actions (`.github/workflows/ios-apps-build.yml`,
  Eintrag `("AlarmiOS", "Alarm")` in `welche-apps.py`). **Erst pushen, Bau
  abwarten, Fehler beheben — den PR-Link erst herausgeben, wenn der Bau
  grün ist.**
