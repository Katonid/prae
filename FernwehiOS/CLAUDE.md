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
  hebt Patch- UND Build-Nummer um je +1.** Start: 1.0.0 (Build 1), dann 1.0.1 (Build 2), 1.0.2 (Build 3), 1.0.3 (Build 4), 1.0.4 (Build 5), 1.0.5 (Build 6), 1.0.6 (Build 7), 1.0.7 (Build 8), 1.0.8 (Build 9), 1.0.9 (Build 10), 1.0.10 (Build 11), 1.0.11 (Build 12), 1.0.12 (Build 13).
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
  Abschnitt gilt der schwerste WMO-Code. Gespeichert am Eintrag (Attribut
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
