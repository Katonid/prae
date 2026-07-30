# Tagesspur (iOS)

Tagesspur zeichnet ressourcenschonend im Hintergrund den genauen Standort
auf und speichert den Tagesverlauf als Track. Fotos und Videos aus der
Mediathek werden anhand ihrer Zeit- und GPS-Daten eingeblendet.

Native SwiftUI-App, iOS 17+, keine externen Abhängigkeiten.

## Funktionen

- **Hintergrund-Tracking, akkuschonend**
  - Besuchs- (CLVisit) und Signifikanz-Monitoring laufen dauerhaft mit
    minimalem Verbrauch und wecken die App auch nach Beendigung wieder.
  - Beste GPS-Stufe (kCLLocationAccuracyBest, 20 m Distanzfilter) bei
    Bewegung — NearestTenMeters wurde von iOS im Hintergrund teils
    minutenlang gedrosselt (Lücken trotz wacher App);
    nach 5 Minuten Stillstand Ruhemodus. Wichtig: Der Ruhemodus stellt
    GPS nur grob (100 m) statt aus — Bewegungsbeginn wird dadurch in
    Sekunden selbst erkannt (kein Warten auf grobe Systemereignisse,
    keine geraden Linien im Track). Apples Auto-Pause ist deaktiviert
    (springt nach Stillstand unzuverlässig wieder an).
  - Einstellung „Hohe Genauigkeit“: dauerhaft präzise ohne Ruhemodus —
    bestes Trackbild, mehr Akkuverbrauch.
  - Bewegungssensor-Wecker: Der Motion-Coprozessor (CMMotionActivity)
    meldet „fährt / radelt / geht“ in Sekunden und praktisch ohne
    Akkuverbrauch — der Ruhemodus endet damit sofort beim Losfahren,
    unabhängig davon, wie grob die Ortung gerade ist. Der Sensor weckt
    nur auf; ob Bewegung anhält, bestätigt das GPS (Herumlaufen in der
    Wohnung hält die präzise Erfassung nicht dauerhaft wach).
  - Rückfallebene GPS-Aufwachen: grobe Fixe (Funkzellen-Ortung) zählen
    mit ungenauigkeitsabhängiger Schwelle (×2, gedeckelt bei 300 m) —
    ein Streu-Fix weckt nicht, ein Funkzellen-Fix verschleppt das
    Aufwachen aber auch nicht kilometerweit.
  - Hintergrund-Sitzung (CLBackgroundActivitySession, iOS 17): der
    moderne, dokumentierte Weg, iOS eine bewusste laufende
    Ortungsaufgabe anzuzeigen. Ohne sie drosselt iOS Legacy-Sessions
    (nur allowsBackgroundLocationUpdates) zunehmend — nachgewiesen
    30.7.: unsere App bekam minutenlang nichts, während Geory auf
    demselben Gerät lückenlos beliefert wurde. Sitzung wird vor dem
    Update-Start aufgebaut, beim Watchdog-Eingriff erneuert und beim
    Abschalten invalidiert.
  - Preis der Sitzung: Solange sie existiert, zeigt iOS den blauen
    Ortungspfeil in der Dynamic Island — Apples Datenschutz-Anzeige,
    von der App nicht abschaltbar. Deshalb lebt die Sitzung nur
    während erkannter Bewegung: Im Ruhemodus wird sie beendet (Pfeil
    erlischt, iOS darf die App zwischen Ereignissen schlafen legen =
    weniger Akku) und beim Aufwachen — Bewegungssensor, Geofence oder
    grober Fix verschaffen dabei die nötige Hintergrund-Laufzeit —
    neu aufgebaut; greift das wider Erwarten nicht, erneuert der
    Watchdog sie beim ersten Liefer-Stillstand. Während einer Fahrt
    bleibt der Pfeil sichtbar — das ist bei jeder App so, die selbst
    live GPS im Hintergrund aufzeichnet (auch Komoot). Geory zeigt
    keinen Pfeil, weil es keine eigene Dauer-Ortung betreibt, sondern
    laut eigener Beschreibung Apples systemseitig ohnehin gesammelten
    Standortverlauf ausliest. Ausnahme: Im Modus „Hohe Genauigkeit“
    gibt es keinen Ruhemodus, der Pfeil bleibt dann dauerhaft.
  - Ortungs-Watchdog: iOS kann die Hintergrund-Lieferung mitten in
    Bewegung minutenlang einstellen (nachgewiesen 30.7., App wach,
    keine Fixe geliefert); ein erneutes startUpdatingLocation belebt
    sie sofort wieder. Der Watchdog (Flush-Timer + Bewegungssensor-
    Callback) startet die Updates deshalb automatisch neu, wenn in
    Bewegung > 2 min nichts geliefert wurde — protokolliert als
    „Ortungs-Stillstand“. Zusätzlich meldet die App iOS einen
    Navigations-Aktivitätstyp (automotiveNavigation/fitness statt
    „other“, dynamisch per Bewegungssensor) — Navigations-Sessions
    drosselt iOS deutlich seltener.
  - Aufwach-Karenz: 45 s nach dem Wecken (Ruhemodus-Ende, Geofence,
    Hintergrund-Neustart) zählen auch mittelmäßige Fixe (≤ 500 m),
    solange Bewegung erkannt ist — der GPS-Empfänger braucht nach dem
    Aufwachen einige Sekunden bis zur vollen Präzision, und bei
    zügiger Abfahrt fehlten sonst die ersten Kilometer.
  - Diagnose sichtbar: Einstellungen zeigen den Status des
    Bewegungssensors („Verweigert“ = Aufwachen nur über GPS); ein
    verweigerter/fehlender Sensor steht auch im Ereignisprotokoll.
  - „Genauer Standort“-Wächter: Ist der iOS-Schalter „Genauer
    Standort“ aus, liefert iOS nur ±1–2 km (Stadtteile stimmen,
    Straßenverläufe unmöglich). Die Einstellungen zeigen den Zustand
    rot an, das Ereignisprotokoll vermerkt ihn — die häufigste
    unsichtbare Ursache für „nur grob aufgezeichnet“.
  - Durchgehende Linie: Jede Gerätespur wird auf allen Karten als eine
    zusammenhängende Linie gezeichnet. Datenlücken werden nicht optisch
    aufgetrennt — sie bleiben über die Lücken-Diagnose im Tagesdetail
    nachvollziehbar (`TrackMath.segments` liefert die Lückenanalyse).
  - Anti-Verhungern, dreistufig: kommt > 60 s kein präziser Fix
    (≤ 100 m), wird auch ein mittelmäßiger (≤ 500 m) aufgezeichnet;
    nach > 150 s zählt im Notbetrieb JEDER Fix — ein grober Punkt ist
    ehrlicher als eine Kilometer-Lücke; die Ungenauigkeit steht am
    Punkt (`hAcc`). Greift nur in Bewegung — im Stillstand bleibt die
    100-m-Sperre, damit Indoor-Streuung nicht als Zacken landet.
    Verworfene Fixe werden sofort protokolliert (nicht erst ab 25),
    Notpunkte ebenfalls — Lücken sagen in der Diagnose, ob Fixe kamen.
  - Geofence-Austritte während laufender Aufzeichnung (der Zaun
    wandert mit jeder Speicherung mit) gelten nicht als Weck-Ereignis
    und landen nicht mehr im Protokoll.
  - Stillstands-Filter: Nach 5 Minuten ohne Bewegung wird höchstens
    ein Punkt pro 5 Minuten übernommen — GPS-Streuung in Gebäuden
    („Sternchen“ um den Standort) verschwindet aus dem Trackbild.
    Wichtig: Stillstand gilt NIE, solange der Bewegungssensor Fahrt/
    Rad/Lauf meldet — die GPS-Verschiebungs-Heuristik allein kann bei
    groben, um Funkmasten clusternden Fixen fälschlich anschlagen und
    dampfte sonst ganze Fahrten auf 1 Punkt / 5 min ein (Symptom:
    exakt getaktete 4–5-min-Lücken ohne Protokoll-Einträge). Jede
    Unterdrückung wird zudem protokolliert (Lücken-Diagnose), und der
    Ruhemodus startet nicht, solange das Fahr-Signal anliegt.
  - Ausreißer-Filter: Punkte, die eine Sprunggeschwindigkeit
    > 250 km/h implizieren, werden als GPS-Spike verworfen und im
    Ereignisprotokoll vermerkt.
  - Lücken-Diagnose: Tracker-Ereignisse (Ruhemodus, Neustarts,
    verworfene Fixe, Schalter) werden protokolliert (Ringpuffer, keine
    Ortsdaten); das Tagesdetail zeigt je Lücke Zeitraum, Distanz und
    die Ereignisse in diesem Fenster.
  - Punkte werden gepuffert (20 Punkte / 90 s) und pro Tag als kompakter
    Blob gespeichert — wenig I/O, wenig Sync-Volumen.
- **iCloud-Sync (SwiftData + CloudKit, privater Container)**
  - Sync-Diagnose in den Einstellungen: Datenbank-Modus (iCloud aktiv
    vs. stiller Lokal-Rückfall), iCloud-Konto-Status, letztes
    Hochladen/Empfangen und der letzte CloudKit-Fehler im Klartext
    (SyncMonitor beobachtet NSPersistentCloudKitContainer-Events),
    dazu je Gerät die Zahl der Tage samt letztem Stand. Wichtigste
    Hinweise: Xcode-Builds syncen in der CloudKit-Entwicklungsumgebung,
    TestFlight-/App-Store-Builds in der Produktionsumgebung — die
    beiden Welten sehen einander nicht; alle Geräte müssen dieselbe
    Installationsart nutzen. Und: Das CloudKit-Schema muss einmalig in
    der CloudKit Console von Development nach Production deployt
    werden (Production legt Record-Typen nicht automatisch an) —
    sonst steht der Sync für TestFlight-Builds komplett still. Nach
    jeder Modell-Änderung: erst Xcode-Build laufen lassen (erzeugt das
    Dev-Schema), dann erneut deployen.
  - Track-Blobs (`pointsData`) liegen mit `.externalStorage` außerhalb
    des Datensatzes (CKAsset) — CloudKit begrenzt Records auf ~1 MB,
    dichte Best-GPS-Tage sprengten das sonst.
  - Sync-Fehler räumen sich selbst auf: Gelingt derselbe Vorgang
    (Hochladen/Empfangen) später erfolgreich, verschwindet die rote
    Fehlerzeile automatisch.
  - Fehler stehen im Klartext statt als Nummerncode: CloudKit meldet
    Sammel-Fehlschläge nur als „Fehler 2“ (partialFailure) — die
    echten Gründe pro Datensatz packt SyncMonitor aus und zeigt die
    ersten davon verständlich an (z. B. „Versionskonflikt — löst sich
    beim nächsten Abgleich selbst“, „Datensatz zu groß“ oder
    „Schema-Deploy prüfen“). Das Auspacken steigt rekursiv ab
    (Sammel-Fehler → Zone → Datensatz, auch Underlying Errors) —
    eine Ebene reichte nachweislich nicht (30.7., 12:29). Zusätzlich
    wird der komplette technische Originaltext gesichert und ist in
    den Einstellungen unter „Technische Details“ aufklappbar —
    letzte Diagnose-Instanz, falls CloudKit die Einzelgründe wieder
    versteckt.
  - Wenn selbst der Roh-Dump leer ist (nachgewiesen 30.7., 12:45:
    „Code=2 (null)“ — CoreData übergibt den Export-Fehler ohne jedes
    Detail), hilft der Knopf „CloudKit-Protokoll auslesen“ unter den
    Technischen Details: Er liest die CloudKit-/Sync-Fehlerzeilen der
    letzten Stunde aus dem Systemprotokoll des eigenen Prozesses
    (OSLogStore) — dorthin schreibt CoreData die echten Gründe pro
    Datensatz. Ablauf: „Sync jetzt anstoßen“, kurz warten, auslesen.
  - Gelöster Ernstfall (30.7., Uploads hingen ab 4:59): „Zone Not
    Found“ — wird die Familien-Zone „TagesspurFamilie“ auf dem Server
    gelöscht, während sich CoreDatas Geräte-Sync deren zonenweite
    Freigabe gemerkt hat, scheitert dessen Initialisierung („Never
    successfully initialized“) und ALLE Uploads stehen still, nicht
    nur die Familien-Spiegelung. Deshalb gilt die Invariante: Die
    Zone existiert immer. autoSync legt sie bei jedem App-Start
    notfalls leer neu an (Ereignisprotokoll: „Sync-Reparatur“), und
    „Freigabe beenden“ legt sie nach dem Löschen sofort leer wieder
    an.
  - Stufe 2 desselben Ernstfalls (13:23): Die Zone allein reicht
    CoreData nicht — es verlangt auch den gemerkten zonenweiten
    Freigabe-Datensatz („cloudkit.zoneshare“, „Record not found“
    blockierte weiter). Deshalb legt autoSync bei anstehendem
    Sync-Fehler und fehlender Freigabe auch die Freigabe leer neu an
    (ohne Teilnehmer; Ereignisprotokoll: „Sync-Reparatur Stufe 2“).
    Endzustand-Invariante also: Zone UND leerer Share existieren
    immer — Teilnehmer nach so einem Vorfall neu einladen.
  - Manueller Anstoß: „Sync jetzt anstoßen“ in der iCloud-Sektion.
    Apples CloudKit-Sync kennt keinen offiziellen Sofort-Befehl —
    der Knopf markiert den jüngsten eigenen Tag als geändert (zwingt
    den Export an) und fährt den Familien-Abgleich ungedrosselt;
    Erfolg ist an „Letztes Hochladen/Empfangen“ ablesbar.
  - Geräte-Umbenennung wirkt rückwirkend: Beim App-Start und beim
    Bestätigen des Namensfelds wird der aktuelle Gerätename auf alle
    Bestandsdaten übertragen (`DeviceInfo.normalizeStoredNames`) —
    sonst erschiene dasselbe Gerät doppelt („iPhone“ und „17 Pro“).
  - Tagesbeschreibungen heilen sich selbst: `summaryPointCount` merkt
    sich, aus wie vielen Punkten die „Ort – Ort – Ort“-Beschreibung
    entstand — weicht der aktuelle Punktebestand ab (z. B. nach
    nachgelieferten Sync-Daten), wird sie automatisch neu berechnet.
  - Fernstrecken-Granularität: Lange Tage (> 30 km) nennen Städte;
    fällt das aber auf einen einzigen Namen zusammen (lange Fahrt
    innerhalb einer Großstadt → „Dortmund“), schaltet die Beschreibung
    automatisch auf Stadtteil-Ebene zurück. Bestandstage mit
    Ein-Wort-Beschreibung berechnen sich einmalig neu.
  - Aufräumen: In der Sync-Diagnose lassen sich fremde Geräte per
    Wischgeste löschen (Löschung synct auf alle Geräte); in der
    Familien-Ansicht lassen sich angenommene Freigaben einzeln
    verlassen (Zone wird aus der Shared-DB entfernt, lokaler Spiegel
    der Person aufgeräumt; `FamilyDay.ownerName` ordnet die Daten der
    Freigabe zu).
  - Jedes Gerät schreibt ausschließlich Datensätze mit seiner eigenen
    Geräte-ID → keine Konflikte.
  - Alle Geräte sehen den gemeinsamen Bestand (geräteübergreifende
    Ansicht in „Tage“, Karten mit einer Farbe pro Gerät).
  - Ohne iCloud-Anmeldung arbeitet die App lokal weiter.
- **Fotos & Videos**
  - Werden zur Laufzeit per Aufnahmezeit (und GPS, falls vorhanden) dem
    Tag zugeordnet und im Tagesdetail zu „Momenten“ gruppiert
    (deterministisch: > 45 min Pause oder > 500 m Abstand = neue Gruppe),
    wenn möglich mit dem passenden Aufenthalt beschriftet.
  - Antippbar: Vollbild-Betrachter mit Wischen, Video-Wiedergabe und
    Teilen; Thumbnails auf der Karte öffnen denselben Betrachter.
  - Datenminimierung: nur Lesezugriff, keine Kopien in der App.
- **Fotoanalyse (opt-in, komplett auf dem Gerät)**
  - Apples Vision-Framework klassifiziert Aufnahmen lokal; gespeichert
    werden nur Stichwörter pro Aufnahme (MediaTag), nie Bilddaten.
  - Die Suche versteht damit auch Motive: „Picknick“, „Lagerfeuer“,
    „Hund“ … — Treffer sind als „Fotoanalyse“ gekennzeichnet, kuratierte
    Deutsch→Vision-Synonymtabelle in `SearchEngine.photoSynonyms`.
  - Ein Tag trifft, wenn jedes Suchwort belegt ist — durch Ort **oder**
    Foto („Picknick am See“).
- **Tages-Replay**
  - Jeder Tag lässt sich wie ein Film abspielen: animierter Punkt mit
    geneigter 3D-Kamera entlang des Tracks, Live-Uhrzeit, Zeitstrahl,
    Play/Pause und Tempo (1×/2×/4×).
- **Statistik (Swift Charts, ohne externe Abhängigkeiten)**
  - Kopfkarte im Tab „Tage“: Gesamtkilometer, Tage-Serie, Mini-Diagramm.
  - Statistikseite: Balkendiagramm der letzten 30 Tage, Summen,
    Aufenthalte, längster Tag.
- **Kartenstile & Darstellung**
  - Umschalter auf jeder Karte: Standard / Hybrid / Satellit (Apple,
    3D-Gelände) sowie **Outdoor** — OpenTopoMap-Kacheln (OSM-Daten mit
    Höhenlinien/Wanderwegen) via MKTileOverlay, inkl. Pflicht-Attribution.
    Stilwahl wird gemerkt.
  - Personen/Geräte-Filter auf jeder Karte (Symbol oben links, ab zwei
    Tracks): einzelne Geräte und Familienmitglieder ein-/ausblenden;
    Farbzuordnung bleibt dabei stabil.
  - Outdoor-Performance: getunte Session (8 parallele Verbindungen,
    10-s-Timeout, Subdomain-Retry), 512-MB-Kachel-Cache, Overzoom > Z17.
    Optional in den Einstellungen: Thunderforest-API-Key (kostenloser
    „Hobby Project“-Tarif) → Outdoor-Stil lädt über deren CDN deutlich
    schneller; Attribution wechselt automatisch.
- **Gesamtkarte aller Tracks**
  - Tab „Tage“ → Kartensymbol: alle jemals aufgezeichneten Tracks
    (eigene Geräte + Familie) auf einer Karte. Antippen wählt einen Track
    aus (hervorgehoben + herangezoomt), Infokarte mit Datum, Person,
    Strecke, Dauer, Punktzahl; „Nur diesen Track zeigen“ und Sprung ins
    Tagesdetail. Treffertoleranz zoomabhängig (30 pt).
- **Tages-Beschreibung („Ort – Ort – Ort“)**
  - `DaySummarizer`: pro vergangenem Tag einmalig bis zu drei Orte
    entlang des Tracks (Stichproben nach Strecke, Reverse-Geocoding).
    Fernstrecken (> 30 km Strecke oder > 15 km Ausdehnung) → Städte;
    lokale Runden → Ortsteile/markante Orte. Ergebnis wird im
    Tages-Datensatz gespeichert (synct via iCloud + Familienfreigabe)
    und in der Tagesliste angezeigt; Berechnung gedrosselt
    (max. 5 Tage pro Aufruf, neueste zuerst).
- **„Wo war ich um …?“ (Zeit-Cursor)**
  - Im Tagesdetail Uhrzeit wählen (Picker + Schieberegler): Marker zeigt
    die interpolierte Position auf der Karte, dazu Adresse
    (Reverse-Geocoding), umgebende Messpunkte und ehrliche Kennzeichnung
    von Messlücken (Ruhemodus) — `TrackMath.position(at:in:)`.
  - Hell/Dunkel getrennt für App und Karte einstellbar (Einstellungen →
    Darstellung), z. B. dunkle App mit heller Karte.
  - Designsprache in `Views/Theme.swift`: Markenverlauf, Hero-Karten mit
    wanderndem Licht-Schimmer, Tracks mit weißer Kontur, gebrandete
    Aufenthalts- und Start/Ziel-Marker.
- **Familienfreigabe (auch andere Apple-IDs)**
  - Eigene Zone „TagesspurFamilie“ in der privaten CloudKit-Datenbank,
    zonenweit geteilt per CKShare; Einladung/Teilnehmerverwaltung über
    Apples System-Dialog (Nachrichten/Mail).
  - Gespiegelt werden Tages-Tracks (ausgedünnt auf 1500 Punkte) und
    Aufenthalte der letzten 60 Tage — keine Fotos, keine Foto-Stichwörter.
  - Empfangene Freigaben werden aus der Shared-DB gelesen und lokal als
    `FamilyDay`/`FamilyVisit` zwischengespeichert (lokal-only-Konfiguration,
    keine Kopier-Schleifen) und erscheinen in Karte, Tagesliste,
    Tagesdetail und Suche — klar nach Person benannt.
  - Statistik und Replay bleiben bewusst auf eigene Daten beschränkt.
  - Sofort-Übertragung: Die Empfängerseite abonniert stille
    CloudKit-Pushes (CKDatabaseSubscription auf der Shared-DB) —
    spiegelt ein Mitglied neue Daten, weckt iOS die App und sie lädt
    sofort nach, statt aufs nächste App-Öffnen zu warten. Die
    Senderseite spiegelt gedrosselt alle 5 Minuten aus dem
    Aufzeichnungs-Flush heraus.
  - Empfangs-Diagnose (Einstellungen → Familie): Anzahl angenommener
    Freigaben (0 = Einladung fehlt auf diesem Gerät — häufigster
    Grund für „es kommt nichts an“), geladene Tage und Zeitstempel
    der neuesten Familien-Daten.
  - Einrichtung: Einstellungen → Familie; Sync automatisch beim
    Aktivwerden der App plus manueller Knopf.
- **Versionierung**
  - Marketing-Version (`MARKETING_VERSION`, aktuell 1.4.10) wird von
    Hand gepflegt; die Build-Nummer setzt eine Skript-Bauphase
    („Build-Nummer setzen“) bei jedem Build automatisch: primär die
    Anzahl der Git-Commits, bei git-Fehlern ein Datumsstempel
    (JJMMTThhmm) — nie stumm „1“. Die Nummer wird einmal pro
    Build-Lauf berechnet und über einen gemeinsamen Zwischenspeicher
    (`$OBJROOT`) von allen vier Targets identisch übernommen (Apple
    verlangt Gleichstand zwischen App, Widget und Watch-Bundles).
  - TestFlight: Ein hochgeladener Build wird erst angeboten, wenn er
    einer Tester-Gruppe zugewiesen ist — am bequemsten in der internen
    Gruppe „Builds automatisch verteilen“ aktivieren, dann geht jeder
    Upload sofort an alle internen Tester.
- **Verlauf abspielen mit Geräteauswahl**
  - Der Play-Knopf (Heute + Tagesdetail) öffnet ein Menü: „Alle
    eigenen Geräte“ (zusammengelegt, wie bisher) oder ein einzelnes
    Gerät bzw. Familienmitglied — jede Spur lässt sich damit einzeln
    als Film abspielen (`ReplayTarget`, Cover per item-Binding).
  - Zwei Ansichten, umschaltbar im Replay: 3D-Flug (geneigte Kamera
    mit Blickrichtung) und 2D-Draufsicht. Beide per Pinch zoombar —
    die gewählte Flughöhe bleibt beim Abspielen erhalten
    (onMapCameraChange übernimmt sie); pausiert ist die 2D-Ansicht
    zusätzlich frei verschiebbar.
  - Zeitleiste mit Direktsteuerung: Antippen springt zum Zeitpunkt,
    Ziehen scrubbt durch den Verlauf (DragGesture minimumDistance 0);
    die Kamera folgt dem Punkt, das Abspielen pausiert dabei.
- **Spurfarben frei wählbar**
  - Einstellungen → „Spurfarben“: je Gerät (eigene und Familie) ein
    ColorPicker; „Standardfarben wiederherstellen“ setzt zurück.
  - Gespeichert im iCloud-Schlüssel-Wert-Speicher
    (`TrackColorStore`, NSUbiquitousKeyValueStore + lokaler Spiegel)
    — die Wahl gilt automatisch auf allen eigenen Geräten, ganz ohne
    Schema-Änderung. Schlüssel ist die stabile deviceId der Spur;
    Familien-Tracks nutzen dafür die deviceId aus den
    Freigabe-Daten (recordName nur als Altbestands-Rückfall).
  - Wirkt überall: Apple-Karten, Outdoor-Karte, Legenden-Panel,
    Geräteliste im Tagesdetail; ohne Wunschfarbe gilt weiter die
    Standardpalette nach Reihenfolge.
- **Apple Watch (eigene App + Komplikationen)**
  - Watch-App (Target `TagesspurWatch`, watchOS 10): zeigt die
    heutigen Kilometer (CloudKit-Stand aller Geräte bzw. der zuletzt
    vom iPhone gemeldete Wert) und fernbedient das iPhone per
    WatchConnectivity — Aufzeichnung an/aus, hohe Genauigkeit — ohne
    das iPhone aus der Tasche zu holen (`PhoneLink` ↔ `WatchLink`;
    der iPhone-Status wandert als Application-Context aus dem
    WidgetBridge-Update mit).
  - Eigenständige Aufzeichnung: „Weg starten“ öffnet eine
    Workout-Session (watchOS erlaubt Hintergrund-GPS nur so — daher
    HealthKit-Freigabe; Gesundheitsdaten werden weder gelesen noch
    gespeichert) und zeichnet mit Navigations-GPS auf. Die Watch ist
    dabei ein eigenständiges Gerät („Watch“) im selben
    CloudKit-Container — ihre Wege erscheinen wie iPhone-Tracks in
    Karte, Tagesliste und Familienfreigabe. Modell-Spiegel in
    `WatchModels.swift` (strukturgleicher `TrackDay`).
  - Zifferblatt-Komplikationen (Target `TagesspurWatchWidgets`):
    heutige Kilometer + Aufzeichnungsstatus (rund, rechteckig,
    Inline); Datenweg wie beim iPhone-Widget über einen
    App-Gruppen-Schnappschuss (`WatchWidgetBridge`).
  - Verteilung: Die Watch-App wird in die iPhone-App eingebettet und
    kommt automatisch mit jedem TestFlight-Build mit.
- **Widgets (Homescreen + Sperrbildschirm)**
  - Eigenes Widget-Target `TagesspurWidgets` (WidgetKit): klein
    (km/Dauer/Status), mittel (Mini-Track des Tages als Vektorpfad auf
    Markenverlauf), Sperrbildschirm rund und rechteckig.
  - Datenaustausch über App-Gruppe `group.de.familie.tagesspur`:
    die App schreibt einen Tages-Schnappschuss (WidgetBridge, gedrosselt
    1×/min) und stößt die Widget-Aktualisierung an.
  - Einrichtung: Beim ersten Build in Xcode auch beim Target
    „TagesspurWidgets“ unter Signing das Team wählen.
- **Export & Import**
  - Umfang: einzelner Tag, Zeitraum oder alles.
  - Zusätzlich im Tagesdetail: beliebigen Uhrzeit-Ausschnitt des
    Tages-Tracks (Von/Bis) als eigene GPX-Datei exportieren — z. B. nur
    die Wanderung von 10:15 bis 13:40.
  - GPX 1.1 (breit kompatibel: Tracks als `<trk>`, Aufenthalte als
    `<wpt>`) und JSON (verlustfreies Tagesspur-Backup).
  - Import: GPX-Dateien und Tagesspur-Backups; Punkte werden
    zusammengeführt, nichts doppelt.
- **Suche („Zeige mir die Tage, an denen ich an einem See war“)**
  - Deterministisch, offline, kein LLM: Stoppwörter entfernen, Synonyme
    aufklappen, Abgleich gegen die per Reverse-Geocoding angereicherten
    Aufenthalte (inkl. `inlandWater`/`ocean` der Placemarks — „See“
    trifft damit direkt erkannte Binnengewässer).
  - Wegesrand-Index: Die Drei-Orte-Beschreibung der Tage (Stichproben
    entlang der Strecke) wird mitdurchsucht — reine Durchfahrts-Tage
    sind damit über Stadtteile/Straßen findbar; Treffer erscheinen als
    „Unterwegs: …“.
  - Zeitfragen: „wo war ich gestern um 17 Uhr“, „12.07. 14:30“ o. Ä.
    beantwortet ein deterministischer Parser direkt mit Position und
    Adresse; Antippen öffnet das Tagesdetail mit vorbelegtem
    Zeit-Cursor.
  - Wegesrand-POI-Suche (OpenStreetMap): expliziter Knopf in der Suche
    fragt die Overpass-API — Namenssuche plus kuratierte Begriffs-Tabelle
    (`POISearch.tagFilters`: Industriebrache→landuse=brownfield, Windrad,
    Halde, Zeche, Aussichtsturm …). Treffer nur im 300-m-Umkreis der
    eigenen Tracks (kompakte Tages-Boxen, max. 45), mit ODbL-Attribution.
    Online-Abfrage, bewusst nicht automatisch pro Tastendruck.
  - Ehrliche Grenze der Offline-Suche: gefunden wird, was Apples
    Geocoder benennt — für freie Beschreibungen wie „Industriebrache“
    die OSM-Wegesrand-Suche nutzen.

## Projektstruktur

```
TagesspuriOS/
├── Tagesspur.xcodeproj
├── Config/               Info.plist, Entitlements (CloudKit, Push)
└── Tagesspur/
    ├── TagesspurApp.swift
    ├── Model/            Models, LocationTracker, Geocoder,
    │                     PhotoMatcher, SearchEngine, Exporter
    └── Views/            Heute, Tage, Suche, Export, Einstellungen
```

## Einrichtung in Xcode

1. `Tagesspur.xcodeproj` öffnen, unter *Signing & Capabilities* das
   eigene Team wählen (Bundle-ID `de.familie.tagesspur`).
2. Der iCloud-Container `iCloud.de.familie.tagesspur` wird über die
   Entitlements automatisch angelegt.
3. Auf dem Gerät: Standort „Immer“ erlauben (für Hintergrund-Tracking)
   und Mediathek-Zugriff gewähren.
