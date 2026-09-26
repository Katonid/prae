# Projekt Fernweh (gemeinsames Reisetagebuch, native iOS-App)

> Ausgelagert aus der `CLAUDE.md` im Wurzelverzeichnis (09/2026). Die
> übergreifenden Regeln (PR-Rhythmus, iOS-Pflichten, Bau in GitHub
> Actions) stehen weiterhin dort und gelten hier genauso.


- App-Code: `FernwehiOS/` (ein Target: App, iPhone + iPad, iOS 17, keine
  fremden Abhängigkeiten), Bundle-Id `de.familie.fernweh`, iCloud-Container
  `iCloud.de.familie.fernweh`, Homescreen-Name „Fernweh". **Store-Name
  „Fernweh – Reisegeschichten"** (Ansage des Nutzers, 09/2026, weil „Fernweh" im
  App Store vergeben ist; 26 Zeichen, Grenze 30 — „Fernweh – Geschichten der
  Reise" war mit 31 eines zu lang). Store-Name und Anzeigename sind getrennte
  Felder. Den App-Eintrag von Hand in App Store Connect anlegen, nie über
  Xcodes „Create App Record“ (Lehre aus Anstoß). Ordner, Ziel, Bundle-Id und
  Container bleiben. Anlass (Ansage des
  Nutzers, 09/2026): „so etwas wie Polarsteps für mich selbst und einige
  wenige Miturlauber bzw. Betrachter". Ausführlich: `FernwehiOS/README.md`.
- **Abgleich über `NSPersistentCloudKitContainer`, nicht über eine eigene
  Maschine wie Tafelbild.** Eine Reise ist ein Geflecht (Reise → Einträge →
  Fotos, dazu Spuren), und geteilt wird immer das ganze. Genau das kann der
  Container: Er legt die Reise samt allem Anhängenden in eine Zone, teilt sie
  per `CKShare` und nimmt Späteres von selbst auf. Zwei Speicher (privat,
  geteilt); **ein neues Objekt muss in den Speicher seiner Reise**
  (`Persistenz.anlegen(_:bei:)`) — eine Beziehung über zwei Speicher weist
  Core Data ab.
- **Das Datenmodell steht im Quelltext** (`Model/Modell.swift`), nicht als
  `.xcdatamodeld`. CloudKit verlangt: alles optional oder mit Vorgabe, keine
  Eindeutigkeit, jede Beziehung optional mit Umkehrung, nichts geordnet.
  **Attribute nur anhängen** — umbenennen bricht jede Reise in einer iCloud.
  Nach jedem neuen Attribut: Debug-Bau → Einstellungen → „CloudKit-Schema
  anlegen", dann „Deploy Schema Changes to Production".
- **Miturlauber und Betrachter sind Apples eigenes Blatt mit zwei
  Voreinstellungen** (`Teilen.swift`): `availablePermissions` nur
  `.allowReadWrite` bzw. nur `.allowReadOnly`. Ob jemand schreiben darf,
  entscheidet `container.canUpdateRecord` — Betrachter bekommen keinen
  Bearbeiten-Knopf. Das Blatt wird über UIKit präsentiert, nie in einem
  SwiftUI-`.sheet` (schwarz, Lehre aus Tafelbild 1.0.60), und mit einer
  fertigen Freigabe geöffnet (Tafelbild 1.1.1).
- **Reisespur = Tagesspurs Strategie** (`Model/Aufzeichner.swift`): „Immer",
  `CLBackgroundActivitySession` im Vordergrund aufgebaut, Auto-Pause aus,
  eigener Ruhemodus (grob statt aus), Besuche + signifikante Ortswechsel +
  150-m-Zaun für den Neustart durch iOS. Rohpunkte sofort auf die Platte (eine
  Datei je Tag), in die Reise gedünnt (15 m) je Tag UND Gerät — jede
  Mitreisende trägt ihre eigene Spur bei; Kilometer zählt je Tag die längste,
  sonst doppelt gezählt.
- **Bearbeitete Fotos**: Gemerkt werden `localIdentifier` UND
  `PHCloudIdentifier`. Angezeigt wird aus der eigenen Mediathek (immer die
  aktuelle Fassung); die mitreisende Kopie (2048 px) erneuert `Fotodienst.abgleichen`
  bei `modificationDate`-Änderung — beim Aktivwerden und auf
  `PHPhotoLibraryChangeObserver`.
- `MARKETING_VERSION` und `CURRENT_PROJECT_VERSION` stehen an je zwei Stellen
  im pbxproj (Debug + Release), KEINE Skript-Bauphase. **Jede Arbeitseinheit
  hebt Patch- UND Build-Nummer um je +1.** Start: 1.0.0 (Build 1), dann 1.0.1 (Build 2), 1.0.2 (Build 3), 1.0.3 (Build 4), 1.0.4 (Build 5), 1.0.5 (Build 6), 1.0.6 (Build 7), 1.0.7 (Build 8), 1.0.8 (Build 9), 1.0.9 (Build 10), 1.0.10 (Build 11), 1.0.11 (Build 12), 1.0.12 (Build 13), 1.0.13 (Build 14), 1.0.14 (Build 15), 1.0.15 (Build 16), 1.0.16 (Build 17), 1.0.17 (Build 18), 1.0.18 (Build 19), 1.0.19 (Build 20), 1.0.20 (Build 21), 1.0.21 (Build 22), 1.0.22 (Build 23), 1.0.23 (Build 24), 1.0.24 (Build 25), 1.0.25 (Build 26), 1.0.26 (Build 27), 1.0.27 (Build 28), 1.0.28 (Build 29), 1.0.29 (Build 30), 1.0.30 (Build 31).
  `DEVELOPMENT_TEAM = F4989GSTWS`, Kategorie Reisen,
  `ITSAppUsesNonExemptEncryption = NO` in `Config/Info.plist` UND als
  Build-Einstellung — nicht entfernen. Zwei Entitlements-Dateien
  (`aps-environment` development/production, Lehre aus Schulalarm 1.0.18).
- **Berechtigungstexte stehen als Build-Einstellung, NICHT in der Info.plist**
  (`INFOPLIST_KEY_NS…UsageDescription`, ab 1.0.2, gemeldet 09/2026: „Xcode
  stürzt ab, wenn ich das Projekt öffne“). Der Absturzbericht (Xcode 27) zeigt
  den Weg: Reiter „General“ → `launchScreenBinding` → `PBXTarget
  _adjustBuildSettingsForProductSettings` → Assertion in
  `DVTMutableMacroDefinitionTable`. Xcode will Schlüssel, für die es eine
  Build-Einstellung gibt, selbst aus der Info.plist dorthin umziehen und bricht
  dabei ab. Tagesspur und Kassenbuch führen dieselben Texte (samt „Immer“) als
  Build-Einstellung und öffnen sich. **In die Info.plist gehört nur, was keine
  `INFOPLIST_KEY_`-Entsprechung hat** (Hintergrundmodi, `CKSharingSupported`,
  das Wörterbuch für die genaue Ortung). Welcher der Texte die Assertion
  auslöste, ist nicht gemessen — umgezogen sind alle fünf.
- **1.0.2 hat den Absturz NICHT behoben** (zweiter Bericht, 25.09.2026, Xcode
  27.0 / macOS 27.0): wörtlich derselbe Stapel bis
  `_setLiteralValue:…wantsCheckForDVTMacroExpansionConformance:`. Ohne
  Meldungstext; die Assertion prüft, ob sich ein Wert als Build-Einstellung
  schreiben lässt. Übrig bleibt der einzige WÖRTERBUCH-Wert der Info.plist,
  den die Apps nicht haben, die sich öffnen lassen:
  `NSLocationTemporaryUsageDescriptionDictionary`. **Ab 1.0.3 ist er draußen**,
  „Genau“ öffnet die Einstellungen der App (dauerhafte Freigabe — für eine
  Reisespur ohnehin die richtige). **Vermutung, nicht Messung.** Der Routenplaner
  trägt denselben Schlüssel seit 1.0.5; stürzt dessen Reiter „General“ auch ab,
  ist die Vermutung bestätigt und er gehört dort ebenso heraus.
- **Der Reisespur-Schalter gilt der DAUERNDEN Aufzeichnung, nicht jeder
  Ortung** (ab 1.0.4, gemeldet 09/2026: iPad mit Spur aus fand beim neuen
  Eintrag keinen Ort und damit kein Wetter). Er steht in `UserDefaults`, gilt
  also je Gerät — iPad aus, iPhone an ist der vorgesehene Fall, und die Spur
  des iPhones reist über die Reise zum iPad (`Tagesorte.orte`). Die Ursache
  war die ERLAUBNIS: Gefragt wurde sie nur beim Einschalten der Spur; auf
  einem Gerät, das sie nie eingeschaltet hatte, stand sie auf „nicht
  gefragt", und `einmalOrten` gab stumm `nil` zurück. Jetzt fragt es selbst
  („Beim Verwenden", nie „Immer") und wartet auf die Antwort. **Nicht
  gesehen**: ob das auf dem iPad des Nutzers die einzige Ursache war — die
  Zeile unter „Orte des Tages" sagt seither, woran es liegt.
- **Jeder Eintrag trägt seine Zeitzone** (Attribut `zeitzone`, IANA-Name, ab
  1.0.6 — **Schema-Deploy nötig**; Ansage des Nutzers 09/2026: „Das wäre
  doch ein leichtes"). Bis 1.0.5 rechnete Fernweh Tag und Uhrzeit jedes Mal
  in der Zone, in der das Gerät GERADE steht; daheim rutschte ein später
  Eintrag aus Übersee auf den Folgetag. **Tag und Uhrzeit eines Eintrags nur
  über `Eintrag.tagSchluessel`, `.uhrzeitText`, `.tagDatum`** — nie
  `Tag.schluessel(eintrag.datum)`. Neu: die Zone des Geräts beim Schreiben
  (unterwegs also die des Urlaubsorts); der Zeitwähler eines bestehenden
  Eintrags läuft in SEINER Zone. Ältere Einträge MIT Ort bekommen sie
  nachgetragen (`Model/Zeitzonen.swift`, Apples Ortsdienst, gedrosselt, nur
  was ich schreiben darf); ohne Ort bleibt sie leer und es gilt die des
  Geräts — geraten wird nichts. Weicht die Zone ab, steht „Ortszeit (…)"
  hinter der Uhrzeit.
- **Day One einlesen** (`Model/DayOne.swift`, `Model/Ziparchiv.swift`,
  `Views/DayOneView.swift`, Einstellungen → „Aus Day One übernehmen", ab
  1.0.6). Gelesen wird der **JSON-Export** — der einzige, der Fotos, Ort,
  Wetter und Zeitzone trägt. Das Format ist von Day One nicht als Vertrag
  veröffentlicht; jedes Feld wird nachsichtig gelesen. Alles landet PRIVAT
  im Lebenstagebuch, nie in einer geteilten Reise. Die Day-One-Kennung (32
  Hex) wird zur `kennung` — doppelt einlesen überspringt. Fotos als
  2048er-Kopie; Videos, Ton und PDFs werden gezählt, nicht übernommen. Das
  Wetter ist Day Ones Momentaufnahme, als EIN Abschnitt „Beim Schreiben".
  Tagebuchnamen aus Day One gehen verloren (es gibt kein Feld dafür).
  **Nicht an einem echten Export gemessen** — der Aufbau ist nach Kenntnis
  des Formats gebaut; stimmt ein Feld nicht, sagt es der erste Import.
- **Tagebücher als Feld** (Attribut `tagebuch`, ab 1.0.7 — **Schema-Deploy
  nötig**; Ansage des Nutzers 09/2026: die Namen der Day-One-Tagebücher
  sicher behalten). Der Import setzt ihn; schon eingelesene Einträge bekommen
  ihn beim erneuten Einlesen desselben Archivs nachgetragen. Eine eigene Liste
  der Tagebücher gibt es nicht — eines existiert, solange ein Eintrag seinen
  Namen trägt; im Editor wählbar (samt „Neues Tagebuch …"), im Reiter
  „Tagebuch" filterbar. Die Wahl „privat oder in die Reise" heißt deshalb
  seither „Nur für mich" — zweimal „Tagebuch" für zwei Dinge wäre eines zu
  viel. Tagebuch und Reise sind unabhängig voneinander.
- **Das Tagebuch liest sich wie ein Heft** (ab 1.0.8, Ansage des Nutzers
  09/2026: „Ich möchte, dass neue Einträge unten angefügt werden … soll die App
  direkt beim Aufruf an das untere Ende der Einträge springen."). Sortiert wird
  AUFSTEIGEND (`TagebuchView.alleEintraege`, `gliedern`), „Was hast du heute
  erlebt?" steht unten, und die Ansicht springt ans Ende (`springen`): beim
  ersten Öffnen, nach einem Wechsel des Tagebuchs und wenn ein Eintrag
  dazukommt — NICHT bei jeder Rückkehr aus einem Eintrag, sonst verlöre man
  beim Zurückblättern jedes Mal die Stelle.
- **Tagebücher haben eine Farbe** (Entität `Buch`, `Model/Tagebuecher.swift`,
  `Views/TagebuecherView.swift`, ab 1.0.8 — **Schema-Deploy nötig**, neuer
  Record-Typ). Ein Tagebuch bleibt der NAME am Eintrag; `Buch` sagt nur, welche
  Farbe dieser Name hat, liegt im PRIVATEN Speicher und wird über den Namen
  zugeordnet (eine Beziehung ginge über zwei Speicher). Ohne eigene Wahl kommt
  die Farbe aus den BYTES des Namens, nie aus `hashValue`. Zwei Geräte mit
  demselben Namen: der zuletzt geänderte Datensatz gilt, `setzen` räumt Doppel
  weg. **Farben immer über `Buecherei.shared` nachschlagen**, nie selbst
  rechnen. Die Übersicht (Knopf oben rechts im Reiter „Tagebuch") ersetzt das
  Filtermenü aus 1.0.7: Zahl, Zeitraum, Tipp zeigt nur dieses Tagebuch, Pinsel
  ändert Farbe und Namen. Umbenennen legt bei gleichem Namen zusammen;
  Einträge in Reisen, die ich nur lese, behalten den alten Namen, und das wird
  gesagt. Die Farbe steht als Streifen an jeder Eintragskarte.
- **Mehrere Tagebücher zugleich zeigen** (ab 1.0.9, Ansage des Nutzers
  09/2026: „dass ich mehrere Tagebücher aktivieren kann, aber eben auch nicht
  aktivierte nicht in der Liste angezeigt werden"). In der Übersicht schaltet
  ein Tipp ein Tagebuch ein oder aus, das Blatt bleibt offen; lange drücken →
  „Nur dieses zeigen". Gemerkt wird das AUSGEBLENDETE, nicht das Gezeigte
  (`@AppStorage("ausgeblendeteTagebuecher")`, JSON, je Gerät): Ein später
  dazukommendes Tagebuch — etwa aus einem Day-One-Import — wäre sonst still
  unsichtbar. "" steht für „ohne Tagebuch". Ist genau ein benanntes Tagebuch
  gezeigt, landet ein neuer Eintrag darin; sonst wird nichts vorbelegt.
- **Tagebücher mit Passwort** (`Model/Schloss.swift`, `Views/Schlossansichten.swift`,
  ab 1.0.10 — **Schema-Deploy nötig**, neue Felder `schloss` und
  `schlossBiometrie` am `Buch`; Ansage des Nutzers 09/2026: „Ich möchte
  einzelne Tagebücher mit einem Passwort sichern können.“). Gespeichert wird
  nie das Passwort, sondern PBKDF2-SHA256 (100 000 Runden, eigenes Salz); es
  reist mit dem `Buch` über iCloud und gilt auf allen eigenen Geräten.
  **Nicht wiederherstellbar**, und das steht beim Vergeben da. **Ein Schloss
  in der App, keine Verschlüsselung** — und es gilt nur für mich: Einträge
  des Tagebuchs in einer geteilten Reise lesen Miturlauber trotzdem. Beides
  steht so in der Oberfläche; nie als „verschlüsselt“ darstellen.
  Gesperrt heißt: `EintragVerweis` zeigt eine verschlossene Karte (nur
  Tagebuch und Uhrzeit — kein Titel, Text, Foto, Ort), die Karte der Reise
  lässt die Nadel weg, die Übergabe ans Reisebuch lässt den Eintrag aus und
  sagt es, und `Reise.erstesFoto` nimmt aus geschützten Tagebüchern nie das
  Titelbild (auch offen nicht, sonst wechselte es beim Öffnen). **Wer eine
  neue Stelle baut, die Einträge zeigt, fragt `Buecherei.istGesperrt`.**
  Offen ist ein Tagebuch nur im Speicher dieses Geräts und nur bis zum
  Wechsel in den Hintergrund (`alleSperren` in `FernwehApp`). Face ID ist je
  Tagebuch zuschaltbar, aus als Vorgabe, und bewusst NUR Biometrie — den
  Gerätecode eines Familien-iPads kennen oft andere. Wer den Pinsel an einem
  gesperrten Tagebuch tippt, muss es erst öffnen, sonst ließe sich über
  „Passwort entfernen“ jedes Schloss abnehmen. `NSFaceIDUsageDescription`
  steht als Build-Einstellung, nicht in der Info.plist (Lehre aus 1.0.2).
- **Suche** (`Model/Suche.swift`, `Views/SuchView.swift`, Lupe oben im
  Reiter „Tagebuch", ab 1.0.11; Ansage des Nutzers 09/2026: „nach Begriffen
  suchen … und angezeigt bekommen, in welchem Tagebuch bzw. welchem
  Tagesabschnitt sie zu finden sind"). Durchsucht Titel, Text, Ort und Land,
  die Orte des Tages und den Namen der Schreibenden, über beide Speicher.
  Groß/klein und Akzente zählen nicht (Volltext, keine Namensprüfung); alle
  Wörter müssen vorkommen, Anführungszeichen halten eine Wortfolge zusammen.
  Jeder Treffer nennt Tagebuch (in seiner Farbe), Tag, **Tagesabschnitt**
  (Morgen 5–10, Vormittag 10–12, Mittag 12–14, Nachmittag 14–18, Abend 18–22,
  sonst Nacht — in der Zone des EINTRAGS, `Tagesabschnitt.von`) mit Uhrzeit,
  die Reise und einen Ausschnitt mit markierten Fundstellen; neueste Tage
  zuerst. Wählbar: nur ein Tagebuch. **Gesperrte Tagebücher werden weder
  durchsucht noch mitgezählt** — eine Trefferzahl verriete schon etwas; die
  Liste sagt nur, dass sie ausgelassen sind. Gesucht wird 250 ms nach dem
  letzten Tastendruck, in `.task(id:)`, nicht im Körper.
- **Im faulen Stapel ist jede ZEILE ein Kind, nie ein ganzes Kapitel**
  (`TagebuchView.zeilen`, `KapitelZeile`, ab 1.0.12; gemeldet 09/2026:
  „Einträge werden zuweilen nicht angezeigt. Wenn ich das Gerät zwischen
  Hochkant und Quer wechseln lasse, sind sie aber da."). Bis 1.0.11 war ein
  Kapitel ein Kind des `LazyVStack` — ohne Reise also alle Tage zwischen zwei
  Reisen, nach einem Day-One-Import Hunderte Einträge in einem Block. Einen
  so großen Block schätzt der Stapel falsch, und nach dem Sprung ans Ende
  blieb er stellenweise ungezeichnet, bis ein neues Layout kam. Jetzt sind
  Band, Tageskopf und Eintrag einzelne Zeilen; die Hülle eines Reisekapitels
  wird je Zeile als STÜCK gezeichnet (`KapitelHuelle`: Ecken nur an Anfang
  und Ende, der Rand offen, sonst läge zwischen zwei Stücken ein Strich).
  Dazu springt die Ansicht zweimal ans Ende — das zweite Mal nach 350 ms,
  wenn die Zeilen wirklich gemessen sind. **Am Quelltext hergeleitet, nicht
  auf dem Gerät gesehen**; ein Wiederauftreten ist ein Befund.
- **Die Spur gehört auch ins Tagebuch** (`Spurabgleich`, `Views/Tagesspurkarte.swift`,
  ab 1.0.13; Ansage des Nutzers 09/2026: „dass die Reisespur für jeden Tag mit
  einem Eintrag komplett hinterlegt wird … auch die Punkte des Nachmittags").
  Bis 1.0.12 wanderte die Rohspur nur in laufende REISEN. Jetzt bekommt jeder
  Tag mit einem eigenen Eintrag OHNE Reise eine `Spur` mit `reise == nil` im
  privaten Speicher, je Tag und Gerät. Sie wird bei jeder Übertragung (alle
  zehn Minuten beim Aufzeichnen, beim Aktivwerden, beim Wechsel in den
  Hintergrund) aus der Rohspur des GANZEN Tages neu gebaut — ein Eintrag vom
  Morgen zeigt abends auch den Nachmittag. Die Rohspur bleibt auf der Platte,
  also bekommt ein früherer Tag seine Spur nach, sobald dort ein Eintrag
  steht. Kein neues Attribut (die Beziehung `reise` war schon optional), kein
  Schema-Deploy. Die Karte im Eintrag zeigt die Spur des Tages samt
  Kilometern: in einer Reise die der Reise, sonst die Tagebuchspur; fehlt die
  eines Geräts, springt die einer eigenen Reise desselben Tages ein.
  **Aufgezeichnet wird weiterhin nur, solange der Reisespur-Schalter an ist**
  — ein Tag ohne Aufzeichnung hat keine Spur, und das ist keine Lücke der
  Übertragung.
- **Die Tagesspur steht im TAGEBUCH, nicht nur im Eintrag** (`Tagesspurleiste`,
  `Tagesspurwahl`, ab 1.0.14; Befund des Nutzers 09/2026 zu 1.0.13: „kommt
  offenbar immer nur bei Urlaubseinträgen zum Vorschein, nicht aber bei einem
  normalen Tagebucheintrag"). Zwei Gründe, beide abgezählt: Die Reise zeigt
  ihre Spur oben im Kapitel, das Tagebuch zeigte sie NIRGENDS in der Liste —
  nur im geöffneten Eintrag. Und die Spur kam erst mit der nächsten
  Übertragung (bis zu zehn Minuten), beim Aktivwerden gar nicht, wenn auf
  dem Gerät nicht aufgezeichnet wurde. Jetzt: eine Kartenleiste unter jeder
  Tagesüberschrift, sobald es für den Tag eine Spur gibt (Reise- oder
  Tagebuchspur); `EintragEditor.sichern` und `wurdeAktiv` übertragen sofort.
  Welche Spur zu einem Tag gehört, entscheidet `Tagesspurwahl` an EINER
  Stelle. **Wach bleiben beim Schreiben**: Der Editor setzt
  `isIdleTimerDisabled`, solange er offen ist — Diktieren ist für iOS
  Untätigkeit.
- **Die Spurkarte geht bildschirmfüllend auf** (`SpurVollbild` in
  `Views/Tagesspurkarte.swift`, ab 1.0.15; Wunsch des Nutzers 09/2026). Die
  kleinen Karten im Tagebuch und im Eintrag bleiben BILDER
  (`allowsHitTesting(false)` — sie liegen in scrollenden Listen und dürfen
  keinen Wisch schlucken); den Tipp nimmt eine durchsichtige Fläche darüber,
  ein Zeichen oben rechts sagt, dass es geht. Im Vollbild ist die Karte
  bedienbar (zoomen, schieben, Kompass, Maßstab), mit Start- und Endpunkt,
  einem Knopf „ganze Spur zeigen“ und einem sichtbaren Schließen-Knopf —
  ein Wisch gehört auf einer Karte dem Verschieben, nicht dem Schließen.
- **Fotos lassen sich zoomen** (`Views/Bildbetrachter.swift`, ab 1.0.16;
  Wunsch des Nutzers 09/2026: „Bei den Fotos möchte ich bitte auch zoomen
  können"). Ein Tipp aufs Foto im Eintrag öffnet wie bisher das Vollbild;
  dort jetzt Aufziehen mit zwei Fingern (bis 5-fach), Verschieben, Doppeltipp
  an der Stelle vergrößern bzw. zurück aufs ganze Bild, „2 von 5" oben
  links. **Gezoomt wird in einer `UIScrollView`, nie mit SwiftUI-Gesten** —
  die Seiten liegen in einer blätternden `TabView`, und ein eigener
  `DragGesture` nähme ihr jeden Wisch. Verschachtelte Scroll-Ansichten regelt
  UIKit: vergrößert verschiebt ein Wisch das Bild, erst am Rand blättert er.
  Weggeblättert springt ein Bild zurück aufs Ganze. Geladen wird mit Kante
  2048 (aus der Mediathek doppelt so fein). **Nicht auf dem Gerät gesehen.**
- **Reisen im Nachhinein** (ab 1.0.17 — **Schema-Deploy nötig**, neue Felder
  `art`, `quelle`, `strecke`, `streckeMeter`, `hoehenmeter`, `dauer`,
  `sportart` am `Eintrag` und `bildtext` am `Foto`; Ansage des Nutzers
  09/2026: „Reisen auch im Nachhinein anlegen können: Fotos importieren …
  Texte zu den Fotos … freie Seiten … Wanderungen, für die ich einen
  Komoot-Link habe … auf einer Karte zeigen … ins Fotobuch exportieren").
  - **Fotos übernehmen** (`Model/Nachtrag.swift`, `Views/FotoimportView.swift`,
    Reise → „…“ → „Hinzufügen“ bzw. die Karte „Reise nachtragen“ an einer
    vergangenen, leeren Reise): alle Fotos im Zeitraum, ohne Bildschirmfotos
    und ohne die schon übernommenen, **je Tag EIN Eintrag** — Zeitpunkt des
    ersten Fotos, Ort = meistfotografierte Stelle (300 m), bis zu fünf
    weitere als „Orte des Tages“ mit Uhrzeit, Wetter jenes Tages. **Der Tag
    eines Fotos ist der Tag AM ORT**: Zone je halbem Grad über Apples
    Ortsdienst, Fotos ohne Ort nehmen die des zeitlich nächsten.
  - **`Eintragsart`** (`Modell.swift`): "" gewöhnlich, `seite`, `wanderung`.
    Der leere Wert ist der alte Eintrag — eine ältere Fassung zeigt Seite
    und Tour als gewöhnlichen Eintrag. **Freie Seite**: ohne Uhrzeit,
    Wetter, Orte; die Uhrzeit ordnet nur (neu auf einer vergangenen Reise:
    erster Tag 6 Uhr, als Einleitung). Der Editor kann jetzt auch „Andere“
    Fotos von jedem Tag (`PhotosPicker`, `itemIdentifier` → `PHAsset`).
  - **Wanderungen** (`Model/Wanderung.swift`, `Views/WanderungImportView.swift`,
    `Views/Wanderansichten.swift`): Komoot hat KEINE veröffentlichte
    Schnittstelle; gelesen wird, was seine Web-Seite liest —
    `api.komoot.de/v007/tours/<Nr>` und `…/coordinates` (`t` = ms seit
    Start). Gemessen 26.09.2026: öffentliche Tour ohne Anmeldung lesbar,
    sonst 403 „Access denied without authentication.“ — der Teilen-Link
    trägt `share_token`, der an beide Anfragen geht. **Kein Vertrag**: Die
    GPX-Datei steht als zweiter Weg immer daneben. Geplante Touren haben
    keine echten Uhrzeiten → 4 km/h geschätzt, und das wird gesagt. Die
    Strecke liegt am EINTRAG (gepackte `Spurpunkt`e mit Uhrzeit), nicht als
    `Spur` — sie gehört zu keinem Gerät. Karte: grün (`Stil.wanderfarbe`),
    im Vollbild Uhrzeiten an Start, Ziel und jeder vollen Stunde
    (`Zeitmarke`). Kilometer der Reise: je Tag das Größere aus Spur und
    Wanderungen.
  - **Texte zu den Fotos** (`Views/BildtexteView.swift`): unter dem Foto im
    Eintrag, im Menü des Eintrags, im Vollbild unten; durchsuchbar.
  - **Karte der Reise**: Wanderungen grün, im Vollbild (Schalter „Fotos“)
    jedes Foto mit Ort als kleines Bild, eines je 25 m, höchstens 300.
  - **Übergabe**: `art`, `wanderung`, `fotos[].text` angehängt (Fassung
    bleibt 1, `docs/UEBERGABE.md`); die Strecke steht ZUSÄTZLICH als Spur des
    Tages (`geraet` = `wanderung:<Kennung>`), damit ein älterer Leser sie
    zeigt.
  - **Nicht gemessen**: Nichts davon lief auf einem Gerät; Komoot nur mit
    einer öffentlichen Tour per `curl` (Aufbau der Antwort), nie mit einem
    Teilen-Link.
- **Das Wetter jedes Tages am Ort** (`Model/Wetternachtrag.swift`, ab 1.0.18;
  Ansage des Nutzers 09/2026: „das Wetter an den einzelnen Tagen am
  jeweiligen Ort … Morgens, mittags, nachmittags, nachts … an das Fotobuch mit
  übergeben"). Geholt wurde es seit 1.0.1 — aber NUR im Editor. Jetzt:
  - **Nachtragen** beim Öffnen einer Reise, des Tagebuchs und vor jeder
    Übergabe: Einträge ohne Wetter und Vorhersagen vergangener Tage, am Ort
    des Eintrags, sonst an dem seines ersten Fotos, seiner Strecke oder am
    Anfang der Spur des Tages. 30 je Lauf, vergebliche Fragen werden für die
    Sitzung gemerkt, geschrieben wird nur, was ich bearbeiten darf. Freie
    Seiten nie.
  - **Unter jedem Tag der Reise** steht das Wetter samt Ort — auch an einem
    Tag nur mit Spur. Dafür gibt es keinen Datensatz; es wird geholt und für
    die Sitzung gemerkt (`Wettervorrat`), NICHT gespeichert. Kein neues
    Attribut, kein Schema-Deploy.
  - **Die Abschnitte heißen „Morgens, Mittags, Nachmittags, Nachts"**
    (Stunden unverändert 6–11, 11–14, 14–18, 21–5). Gespeicherte Einträge
    tragen die alten Namen; übersetzt wird beim Zeigen
    (`Wetterabschnitt.anzeigename`), nie im Speicher. **Wer einen Abschnitt
    vergleicht, vergleicht `anzeigename`** (das Nachtsymbol tat es mit dem
    Namen).
  - **Übergabe**: `tage[].wetter` und `tage[].wetterOrt` angehängt (Fassung
    1); die Abschnitte gehen unter ihrem neuen Namen hinaus.
  - **Nicht gemessen**: kein Gerät; Open-Meteo ist seit 1.0.1 gemessen, der
    Nachtrag nicht.
- **Fotos aus einem ALBUM übernehmen** (`Fotodienst.alben`, `.fotos(in:)`,
  `Nachtrag.Fund`, ab 1.0.19; gefragt 09/2026: „Die Fotos liegen in einem
  dafür angelegten Album der Galerie."). Oben im Blatt „Fotos übernehmen"
  steht jetzt die Quelle: der Zeitraum der Reise (wie bisher) oder ein Album
  (eigene, auch in Ordnern und geteilte, dazu „Favoriten"). Aus einem Album
  zählen nur Fotos, deren Tag (in Ortszeit) in der Reise liegt; die übrigen
  werden GEZÄHLT und gesagt, samt Knopf „Reise auf … erweitern" — der
  Zeitraum wird nur verlängert, nie verkürzt, und nie über heute hinaus.
  Der Befund des Nutzers zeigte eine vergangene, leere Reise OHNE die Karte
  „Reise nachtragen" — also noch eine Fassung vor 1.0.17 auf dem Gerät.
  **Nicht gemessen**: kein Gerät, keine echte Mediathek.
- **Sonne statt Wolkencode** (`Wettercode.abschnittscode`, ab 1.0.20;
  gemeldet 09/2026: „Im Osterurlaub in Berchtesgaden steht fast
  ausschließlich ‚bedeckt', obwohl es an einzelnen Tagen doch sonnig war.").
  **Nachgemessen** an Open-Meteo für Berchtesgaden, 30.03.–12.04.2026: am
  6. April mittags dreimal Code 3 bei 100 % Sonnenschein, am 9. nachmittags
  viermal. Zwei Fehler übereinander: Die Codes 0–3 folgen der GESAMTbewölkung
  (auch dünnen hohen Schleiern), und „der schwerste Code je Abschnitt“ ließ
  eine trübe Stunde über den ganzen Abschnitt entscheiden.
  - Regen, Schnee, Gewitter (Code ≥ 51): weiter der schwerste Code.
  - Sonst am Tag die **Sonnenscheindauer** (`sunshine_duration`) über die
    hellen Stunden (`is_day` oder Sonne > 0): ab 75 % Sonnig, ab 50 %
    Überwiegend sonnig, ab 20 % Teils bewölkt, darunter der mittlere Code.
    Nachts und ohne Sonnendaten: der mittlere Code. **Schwellen gewählt,
    nicht gemessen.** Tagsüber heißt Code 0/1 jetzt „Sonnig“, nachts „Klar“.
  - Nachgerechnet an denselben Tagen: 5., 6., 9., 11. April nicht mehr
    „Bedeckt“, Regen-/Schneeabschnitte unverändert.
  - **Schon gespeichertes Wetter wird einmal neu geholt**
    (`Tageswetter.rechnung`, `veraltet`): Einträge ohne Rechnungsnummer mit
    Open-Meteo-Abschnitten gelten als fehlend — beim Öffnen von Reise oder
    Tagebuch (30 je Lauf) und im Editor. Day Ones „Beim Schreiben“ bleibt.
    Neues Feld nur im JSON des Attributs `wetter`, **kein Schema-Deploy**.
  - Ans Reisebuch geht die neue Beschreibung; wer schon übergeben hat,
    übergibt nach dem Neuholen noch einmal.
  - **Nicht gemessen**: kein Gerät; nur die Antwort des Dienstes per `curl`.
- **Autofahrten aus GPX-Dateien und einstellbare Kartenfarben**
  (`Model/Fahrten.swift`, `Model/Kartenfarben.swift`,
  `Views/FahrtenImportView.swift`, `Views/KartenfarbenView.swift`, ab 1.0.21;
  Ansage des Nutzers 09/2026: „GPX-Dateien für jede einzelne Fahrt … en bloc
  importieren … den einzelnen Tagen zuweist. Auf der Landkarte der Reise
  sollen Autofahrten mit einer anderen Farbe dargestellt werden. Insgesamt
  möchte ich die Farben auf der Karte einstellen können und auch dies soll
  abschließend an Fotobuch übergeben werden.")
  - **Sammelimport**: Reise → „…" → „Autofahrten (GPX) …" bzw. die Karte
    „Reise nachtragen"; beliebig viele Dateien. Der Tag einer Fahrt ist der
    Tag ihres STARTS in Ortszeit (Zone je halbem Grad über Apples
    Ortsdienst); über Mitternacht wird nicht geteilt. Dateien OHNE Uhrzeiten
    werden genannt, nicht geraten. Fahrten außerhalb der Reise werden gezählt,
    samt „Reise auf … erweitern" (nur länger, nie über heute).
  - **Gespeichert als `Spur` der Reise** mit `geraet` =
    „fahrt:<Start in s>|<Zone>|<Name>" — kein neues Attribut, **kein
    Schema-Deploy**. Derselbe Start zweimal: übersprungen. Auf 20 m gedünnt,
    Kilometer aus der ungedünnten Datei. **Wer Spuren je Gerät auswertet,
    prüft `Spur.istFahrt`** — eine Fahrt ist kein Gerät. Kilometer des Tages
    nur über `Reise.meter(am:)`: das Größere aus längster Gerätespur und der
    Summe aus Fahrten und Wanderungen.
  - **Unter jedem Tag** steht jede Fahrt als Zeile (Name, Uhrzeit, km); lange
    drücken → „Fahrt entfernen".
  - **Kartenfarben** je GERÄT (`UserDefaults`, nicht an der Reise — ein
    Attribut hätte einen Schema-Deploy gekostet): Reisespur (Vorgabe: Farbe
    der Reise, Miturlauber heller), Wanderungen (Vorgabe Grün), Autofahrten
    (Vorgabe Schiefergrau `#5A6475`). Einstellbar in den Einstellungen →
    „Kartenfarben …" und in der Vollbildkarte → „Farben". **Linienfarben nur
    über `Kartenfarben.shared`**, nie `Stil.wanderfarbe` direkt.
  - **Übergabe**: `spuren[].art`/`name` und `karte.farben` angehängt
    (Fassung 1, `docs/UEBERGABE.md`). `reisespur` geht nur mit, wenn gewählt.
  - **Nicht gemessen**: kein Gerät, keine echte GPX-Datei einer Autofahrt.
- **Mehrere Fahrten in EINER GPX-Datei** (`GPXLeser.fahrten`, ab 1.0.22;
  Ansage des Nutzers 09/2026: „Ich habe zum Teil GPX-Dateien, in denen
  mehrere Fahrten aufgelistet sind."). 1.0.21 machte aus jeder Datei EINE
  Linie. Jetzt: getrennt an jeder Spur (`trk`) und innerhalb einer Spur an
  jeder Pause ohne Punkt ab 15 Minuten (im Blatt wählbar: 5/15/30/60 min
  oder „nie", `@AppStorage("fernweh.fahrtenpause")`). Die Dateien werden
  beim Wählen EINMAL gelesen (`Fahrtenimport.Datei`), damit ein Wechsel der
  Pause sie nicht neu öffnen muss. Stücke unter 200 m fallen weg und werden
  gezählt. Mehrere Stücke gleichen Namens: „Name · 2". **Schon da** ist eine
  Fahrt mit demselben Start ODER zeitlich innerhalb einer eingelesenen — so
  wird eine unter 1.0.21 zusammengeklebte Datei nicht doppelt übernommen;
  wer sie getrennt will, entfernt die alte Fahrt und liest neu ein.
  **Nicht gemessen**: an keiner echten Datei mit mehreren Fahrten.
- **Sicherung der Datenbank** (`Model/Sicherung.swift`,
  `Views/SicherungView.swift`, ab 1.0.22; Ansage des Nutzers 09/2026:
  „eine Sicherung der Datenbank der App … Global bzw. auch einzelne
  Tagebücher oder Reisen separat."). Einstellungen → „Sicherung", Reise →
  „…" → „Reise sichern …", Tagebücher → lange drücken → „Sichern …".
  - ZIP mit `sicherung.json` und je Binärfeld einer Datei unter `daten/`;
    **ZIP64**, wenn nötig (`ZipSchreiber(zip64: true)`) — die Übergabe bleibt
    ohne, denn die liest das Reisebuch.
  - **Entlang des Modells** (`NSEntityDescription`), nicht Feld für Feld:
    Ein später angehängtes Attribut geht von selbst mit; Unbekanntes aus
    einer neueren Sicherung wird überlesen. Wer ein Attribut mit neuem TYP
    anlegt (Transformable o. ä.), ergänzt den Fall in `erstellen` und
    `wiederherstellen`.
  - **Wiederherstellen führt zusammen**: gleiche Kennung = schon da, bleibt
    unverändert; ein Tagebuch (`Buch`) gleichen Namens ebenso. Neues kommt in
    den Speicher des Ziels seiner Beziehung (wenn ich dort schreiben darf),
    sonst privat. Fotos ohne ihren Eintrag werden übersprungen und gezählt.
    Angelegt über `insertNewObject(forEntityName:)` — `NSManagedObject(entity:
    insertInto:)` ergäbe keine Modellklasse.
  - **Gesperrte Tagebücher gehen nicht mit** (wie bei der Übergabe); das
    Blatt zählt sie. Gesichert werden die Kopien in Fernweh, nicht die
    Originale der Mediathek. Kartenfarben (je Gerät) gehen nicht mit.
  - **Nicht gemessen**: kein Gerät, keine echte Wiederherstellung.
- **Was der iCloud-Abgleich tut, steht in den Einstellungen**
  (`Model/Abgleichstatus.swift`, ab 1.0.22; gemeldet 09/2026: „eine auf dem
  iPad angelegte Reise [wurde] nicht aufs iPhone übertragen"). Mitgeschrieben
  wird `NSPersistentCloudKitContainer.eventChangedNotification` ab dem Start
  (`AppDelegate`): je Speicher Einrichten/Senden/Empfangen mit Uhrzeit, bei
  Fehler Apples Meldung ROH samt Teilfehlern, dazu ein Rat, wo er sich
  erkennen lässt (Schema, Speicher voll, Konto). Dazu die **Umgebung** des
  Baus: aus Xcode = Entwicklung, TestFlight/App Store = Produktion — zwei
  getrennte Datenbanken, die häufigste Ursache für „das andere Gerät sieht
  nichts". **Die Ursache des gemeldeten Falls ist NICHT gefunden**; die
  Anzeige soll sie zeigen.
  - **Erster Befund (26.09.2026, Bildschirmfotos iPad und iPhone):** beide
    „Produktion", Einrichten/Senden/Empfangen im GETEILTEN Speicher gut,
    **„Senden (privat)" auf BEIDEN Geräten gescheitert** mit CKError 2
    (`partialFailure`) — also verlässt kein privater Datensatz eines der
    Geräte; das erklärt die fehlende Reise. Die Teilfehler zeigte 1.0.22
    nicht. **Vermutung, nicht Messung:** Produktionsschema ohne die Felder
    ab 1.0.17 (`art`, `strecke` … am Eintrag, `bildtext` am Foto) — der
    geteilte Speicher liefe dann nur, weil dort nichts Neues liegt.
  - **Ab 1.0.23 sammelt `beschreibung` rekursiv**: Code mit Namen, die
    Begründung des Servers (`NSDebugDescription`/„ServerErrorDescription"),
    die Teilfehler aus `CKPartialErrorsByItemIDKey` nach Ursache
    zusammengefasst (mit einem Datensatznamen als Beispiel), darunterliegende
    Fehler. Dazu „Meldung kopieren". Eine Zusammenfassung „CKErrorDomain-
    Fehler 2" allein ist keine Auskunft — **wer Fehler zeigt, zeigt die
    Teilfehler mit.**
  - **Zweiter Befund (26.09.2026, 1.0.24, iPad):** wieder nur „CKError 2
    (Teilfehler)" — KEINE Teilfehler unter `CKPartialErrorsByItemIDKey`,
    keine Serverbegründung. Der Nutzer hatte vorher aus Xcode installiert
    und das Schema nach Produktion übertragen (es gab Änderungen) — das
    Senden scheitert trotzdem. **Die Schema-Vermutung ist damit
    geschwächt, nicht widerlegt.** Ab 1.0.25 hängt „Vollständige Meldung
    kopieren" die ROHE Beschreibung des Fehlers (`String(describing:)`,
    3000 Zeichen) und die Namen aller `userInfo`-Schlüssel an; Teilfehler
    werden auch als `NSDictionary` gelesen. Der Bildschirm zeigt nur die
    Kurzfassung. **Merke: erst roh ausgeben, dann deuten** — zweimal wurde
    an der falschen Stelle gesucht.
  - **Gelöst (26.09.2026, Nutzer: „Das Problem scheint jetzt gelöst zu
    sein.")**: Die Xcode-Fassung zeigte „CloudKit-Schema anlegen" mit
    „Failed to initialize CloudKit schema because the requests timed out (a
    30s wait failed)" — gleichzeitig lud sie den ganzen Bestand erstmals in
    die ENTWICKLUNGSumgebung hoch. Das vorige Deploy trug deshalb nicht alle
    Felder; nach erneutem Anlegen und Deploy sendet die Produktion. **Merke:
    Nach „Schema anlegen" steht „Schema angelegt …" da — sonst ist das
    Deploy danach unvollständig.** Die Entwicklung legt Felder beim Senden
    selbst an; dass es aus Xcode klappt, beweist über die Produktion nichts.
- **Wann war ich hier? — Uhrzeit per Tipp auf die Linie** (`Views/Zeitauswahl.swift`,
  ab 1.0.24; Ansage des Nutzers 09/2026: „die einzelnen Punkte der Reise
  anzeigen … durch Auswählen auf der Karte anzeigen …, um welche Uhrzeit ich
  an diesem Ort war"). In der Vollkarte der Reise und im Vollbild eines Tages
  bzw. einer Wanderung sucht ein Tipp den nächsten Punkt einer Linie (Spur,
  Fahrt, Wanderung) innerhalb von 32 Bildpunkten — in Meter umgerechnet über
  `MapProxy` — und zeigt eine Blase: Uhrzeit in ORTSZEIT (Fahrt: ihre Zone;
  Gerätespur: `Reise.zone(am:)` = Zone eines Eintrags des Tages, sonst einer
  Fahrt, sonst des Geräts; Wanderung: die des Eintrags), auf der ganzen Reise
  mit Tag, dazu Art und Name. Ein Tipp daneben schließt sie.
  - **Nur die bedienbaren Karten nehmen den Tipp.** Im Kopf der Reise öffnet
    ein Tipp weiter die Vollkarte — eine eigene Geste der Karte schluckte ihn
    (deshalb `if interaktiv { MapReader … }`).
  - **„Punkte"** (Knopf in der Vollkarte bzw. Rasterzeichen im Vollbild,
    `@AppStorage("fernweh.kartenpunkte")`) blendet die Messpunkte als kleine
    Kreise ein, gleichmäßig verteilt, höchstens 400 — über eine Reise sind
    es sonst Zehntausende Annotationen. Gesucht wird trotzdem in ALLEN
    (40 m gedünnt), flach gerechnet.
  - **Nicht gemessen**: kein Gerät; ob der Tipp neben den Pan-/Zoom-Gesten
    der Karte sauber ankommt, ist nicht gesehen.
- **Vier Ebenen auf jeder Karte der Reise, einzeln schaltbar**
  (`Views/Kartenebenen.swift`, ab 1.0.26; Ansage des Nutzers 09/2026: „Wenn
  ich mir einen einzelnen Urlaubstag … auswähle, sehe ich dort aber nur die
  Komoot-Karten … in beiden Darstellungen alle vier Dinge … einzeln
  ausfilterbar: Komoot, Autofahrt, GPX-Koordinaten der Fotos und … der
  Import aus der Tagesspur.").
  - **Jeder Tag der Reise hat eine Karte** (`TagAbschnitt`): Spur,
    Autofahrten, Wanderungen, Fotos (als Bildchen an ihrem Ort) dieses Tages
    — sobald es davon etwas gibt. Ein BILD in der Rolle; ein Tipp öffnet die
    Vollkarte gleich auf diesem Tag (`Vollkarte(reise:startTag:)`).
  - **Die Schalter** (`Ebenenwahl`, `@AppStorage("fernweh.ebene.…")`) gelten
    für ALLE Karten der Reise zugleich — Kopf, Tageskarten, Vollkarte —,
    stehen unter jeder Tageskarte und in der Vollkarte. Ausgeblendetes wird
    auch beim Tipp nach der Uhrzeit nicht gefunden. Die „Reisespur" umfasst
    Aufzeichnung UND Übernahmen aus der Tagesspur (beides sind Gerätespuren).
  - Das Vollbild eines Tages im Tagebuch (`SpurVollbild`) zeigt jetzt auch
    die Wanderungen des Tages (`Tagesspurwahl`) und dieselben Schalter für
    die Arten, die es dort gibt; die Kilometer zählen die Wanderungen mit
    (wie `Reise.meter(am:)`).
  - **Fahrtnamen ohne Datum vorneweg** (`Fahrtenimport.anzeigename`): Die
    Fahrtenbücher des Nutzers nennen eine Fahrt „29.03.2026 07:28–12:28 ·
    Würzburg → Schönau"; unter dem Tag stand beides doppelt.
  - **Nicht gemessen**: kein Gerät; ob fünfzehn Tageskarten in einer Rolle
    flüssig bleiben, ist nicht gesehen.
- **Texte einer Reise zum Überarbeiten hinaus und wieder herein**
  (`Model/Textglaettung.swift`, `Views/TexteView.swift`, Reise → „…" →
  „Texte überarbeiten (KI) …", ab 1.0.27; Ansage des Nutzers 09/2026: „alle
  Tagebuchtexte einer Reise en bloc exportieren … von einer KI sprachlich
  glätten … wieder in die App einlesen …, sodass diese sich automatisch auf
  die einzelnen Tage verteilt und die jeweiligen Tageseinträge ersetzt.").
  - **Schlichter Text, keine JSON** — er geht durch einen KI-Chat. Kopf mit
    Hinweis an die KI, dann je Eintrag eine Kennzeile „=== Eintrag
    <8 Hex der UUID> · Tag n · Wochentag · Uhrzeit ===", „Titel: …",
    Leerzeile, Text. Als Datei teilen oder alles in die Zwischenablage.
  - **Zugeordnet NUR über die Kennung**, nie über Reihenfolge oder Datum.
    Der Leser ist nachsichtig mit dem, was eine KI aus der Kopfzeile macht
    (fett, `###`, `==`); „Titel:" zählt nur als erste Zeile nach dem Kopf.
    Unbekannte Kennungen, fehlende Einträge, gesperrte und nicht
    bearbeitbare werden gezählt und gesagt. **Ein leerer Block löscht nie
    einen Text** (fast immer ein Kopierfehler).
  - **Vorschau vor dem Ersetzen**: jeder geänderte Eintrag mit Vorher/Nachher,
    einzeln abwählbar. Ersetzt werden Titel und Text.
  - **Zurücknehmen**: Vor dem Ersetzen liegt der alte Stand in
    `Application Support/Textstaende/<Reise>.json` (nur der letzte, je
    Gerät); „Letzte Übernahme zurücknehmen" stellt ihn her.
  - Nicht mit: gesperrte Tagebücher; Bildtexte (noch nicht).
  - **Nicht gemessen**: kein Gerät, keine echte KI-Antwort.
- **Jeder Reisetag ist eine Karte mit Kopfband** (`TagAbschnitt`, ab
  1.0.28; Befund des Nutzers 09/2026 mit Bildschirmfotos: „komplett
  unübersichtlich und man kann kaum erkennen, an welcher Stelle der nächste
  Tag anfängt … die [Autofahrten] in einem sich aufklappenden Verzeichnis").
  - Oben ein Band im Verlauf der Reisefarbe (Tag n, Wochentag, Kilometer),
    darunter der Inhalt auf getöntem Grund mit Rand; Abstand zwischen den
    Tagen.
  - **Sprungleiste „Tag 1 … Tag n"** über den Tagen (`ScrollViewReader`,
    `.id("tag-n")`) und die **Kartenschalter EINMAL** dort — unter jeder
    Tageskarte sahen sie aus wie ein Teil des Tages.
  - **Autofahrten zugeklappt** (`DisclosureGroup`): „7 Autofahrten · 43,2
    km", aufgeklappt die Zeilen wie bisher.
  - **Das Band ist abgedunkelt** (ab 1.0.29, `Color.black.opacity(0.28)`
    über dem Verlauf; Befund: „Weiße Schrift auf hellblauem Grund ist nicht
    so cool"). **Weiße Schrift nie direkt auf `palette.verlauf`** — die
    hellen Paletten tragen sie nicht. Dazu steht die Wetterzeile unter dem
    Band `fixedSize()`: Auf dem iPhone brachen die Temperaturen Ziffer für
    Ziffer um, gekürzt wird jetzt der Ort.
  - Gemeldet dazu: „dass nicht alle [Autofahrten] aufgeführt sind" — die
    Ursache ist NICHT gefunden (in Frage kommen: Stücke unter 200 m, eine
    Pause unter der gewählten Grenze legt zwei Fahrten zusammen, eine Fahrt
    zeitlich innerhalb einer schon eingelesenen gilt als „schon da").
- **EINE Karte, nie zwei** (ab 1.0.30; Ansage des Nutzers 09/2026 mit
  Bildschirmfoto — Tageskarte und darunter die Karte einer Wanderung: „Ich
  möchte keine doppelten Karten mehr. Alle Funktionen müssen in einer (!)
  Karte gebündelt werden."). Die eigene `Wanderkarte` steht nirgends mehr:
  nicht in der Eintragskarte der Liste (Reise wie Tagebuch — dort zeigt die
  Karte des TAGES die Strecke), nicht im geöffneten Eintrag (dort jetzt
  `Tagesspurkarte` auch für Wanderungen). Was sie konnte, kann die
  Tageskarte: Uhrzeiten an Start, Ziel und jeder vollen Stunde JEDER
  Wanderung (`SpurVollbild.alleZeitmarken`), Uhrzeit per Tipp, Schalter.
  **Wer eine neue Ansicht baut, zeigt dort keine zweite Karte** — eine
  Karte je Tag bzw. Eintrag, und die bündelt alles.
- **ZIP64 heißt NICHT „über 4 GB"** (behoben in 1.0.7, gemeldet 09/2026: ein
  Day-One-Export von 250 MB wurde als „größer als 4 GB" abgewiesen). Day One
  schreibt die ZIP64-Erweiterung auch bei kleinen Archiven; die echten Zahlen
  stehen dann im ZIP64-Schlussstück (über den Wegweiser 20 Bytes vor dem
  gewöhnlichen) und im Extrafeld 0x0001 jedes Eintrags. `Ziparchiv` liest
  beides. **Merke: Eine Fehlermeldung, die eine Ursache nennt, muss sie
  gemessen haben** — hier stand eine Vermutung über die Größe, und die
  Dateigröße hätte sie in einer Zeile widerlegt.
- **Lebenstagebuch mit Reisen als Kapiteln** (`Views/TagebuchView.swift`, ab
  1.0.5, Wahl des Nutzers 09/2026). Zwei Reiter: „Tagebuch" (alle Einträge
  aus beiden Speichern, nach Tagen) und „Reisen". Ein Eintrag OHNE Reise
  (`reise == nil`) liegt im PRIVATEN Speicher und reist mit keiner Freigabe
  — `Persistenz.anlegen(_:bei: nil)`. Eine Reise ist ein Zeitraum; Tage in
  ihrem Zeitraum stehen unter ihrem Band (bei zwei Reisen: die mit den
  meisten Einträgen des Tages, sonst die zuletzt begonnene). **Wohin ein
  neuer Eintrag geht, steht im Editor ausdrücklich** (`zielBlock`): Vorgabe
  ist die laufende Reise, umzustellen auf „Nur mein Tagebuch" — und es wird
  gesagt, wer mitliest. **Ein Eintrag wechselt den Speicher nachträglich
  nicht** (Core Data kann kein Objekt zwischen Speichern verschieben; es
  wäre Kopieren samt Fotos). Kein neues Attribut, also kein Schema-Deploy.
- **Reisesymbol: Emoji ODER Apple-Symbol** (`Views/Reisesymbol.swift`, ab
  1.0.5). Weiter im Attribut `emoji`; ein Apple-Symbol steht dort als
  `sf:<Name>`. **Angezeigt wird es nur über `Reisesymbol`** — ein nacktes
  `Text(reise.emoji)` druckt „sf:…". Apple gibt keine Liste seiner Symbole
  heraus; die Auswahl ist eine mitgelieferte Liste, jeder Name wird zur
  Laufzeit mit `UIImage(systemName:)` geprüft. Emojis kommen über die
  Tastatur des Systems — dort gibt es alle.
- **Übergabe ans Reisebuch** (`Model/Uebergabe.swift`,
  `Views/UebergabeView.swift`, ab 1.0.5, Ansage des Nutzers 09/2026: „die
  Apps miteinander vernetzen“). Reise → „…“ → „Fürs Fotobuch übergeben“
  schreibt eine `.fernweh`-Datei: ein ungepacktes ZIP mit
  `uebergabe.json` (Texte, Orte, Wetter je Eintrag, wahlweise die Reisespur)
  und wahlweise `fotos/…` (ohne / verkleinerte Kopie / Original aus der
  Mediathek). **Der Vertrag steht in `FernwehiOS/docs/UEBERGABE.md`** und wird
  vom Reisebuch gelesen — wer ein Feld ändert, ändert es dort mit; Felder nur
  anhängen. Fotos sind aus als Vorgabe (Ansage des Nutzers: zuschaltbar).
  Methode 0, weil Fotos sich nicht weiter packen lassen und das Reisebuch ZIP
  seit 1.0.13 selbst liest; kein ZIP64, über 4 GB wird abgebrochen.
- **Diktieren** (`Model/Diktat.swift`, ab 1.0.1, Wunsch des Nutzers: „die
  Apple-Spracherkennung versteht vieles nicht richtig … vielleicht gibt es
  Alternativen"). Ab iOS 26 Apples NEUES Modell (`SpeechAnalyzer` +
  `SpeechTranscriber`, auf dem Gerät, ohne Zeitgrenze) — nicht dasselbe wie
  die Tastatur-Diktierfunktion; davor `SFSpeechRecognizer`. **Beide bekommen
  die Orte des Tages als Hinweise** (`contextualStrings`) — Ortsnamen sind die
  häufigsten Fehler in einem Reisetagebuch. Fremde Dienste (Whisper u. ä.)
  sind bewusst NICHT gebaut: Schlüssel nötig, und jede Aufnahme verließe das
  Gerät. Nur auf ausdrückliche Ansage.
- **Wetter** (`Model/Wetter.swift`, ab 1.0.1): Open-Meteo, ohne Schlüssel,
  vier Abschnitte in ORTSzeit (`timezone=auto`): Vormittag 6–11, Tagsüber
  11–14, Nachmittag 14–18, Nacht 21–5 (bis in den Folgetag). Gemessen
  24.09.2026: `api.open-meteo.com` nimmt nur gut 90 Tage zurück bis 16 voraus
  an, ältere Tage gehen an `historical-forecast-api.open-meteo.com`. Je
  Abschnitt gilt seit 1.0.20 NICHT mehr der schwerste WMO-Code (siehe
  „Sonne statt Wolkencode“). Gespeichert am Eintrag (Attribut
  `wetter`, JSON) — neues Attribut, also Schema-Deploy. Ein Tag, der beim
  Holen noch nicht vorbei war, heißt „Vorhersage" und wird nachgeholt.
  **WeatherKit bewusst nicht**: braucht eine Fähigkeit an der App-Id (Lehre
  aus dem Reisebuch 1.0.44).
- Das App-Symbol rechnet `FernwehiOS/scripts/make-icon.py` — seit 1.0.4
  (Wahl des Nutzers aus fünf Entwürfen) eine Landschaft: Himmel mit Sonne und
  zwei Bergen, ein Streifen Meer, Sand, darauf eine Füllfeder mit dünner
  Tintenspur. Orange und Blau („Sand und Sonne, Himmel und Meer"), die Berge,
  weil nicht jede Reise ans Meer geht. **Keine dicke weiße Wellenlinie** —
  das ist die Form des Routenplaner-Symbols, und genau daran sah der Stift
  aus 1.0.1 ihm zu ähnlich. Zusammengesetzte Flächen (Schneekappen) werden
  an der Kante abgetastet, nicht über den Abstand geglättet: Ein Abstand
  steht an der inneren Naht zweier Stücke auf null und malt dort eine Linie.
- Übersetzt wird in GitHub Actions (Eintrag `("FernwehiOS", "Fernweh")` in
  `welche-apps.py`). **Erst pushen, Bau abwarten, Fehler beheben — den
  PR-Link erst herausgeben, wenn der Bau grün ist.** Ein grüner Bau beweist
  NICHT, dass sich signieren lässt.
