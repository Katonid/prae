# Projekt Wörterwerkstatt (Web-App, Rechtschreibung)

> Ausgelagert aus der `CLAUDE.md` im Wurzelverzeichnis (09/2026). Die
> übergreifenden Regeln (PR-Rhythmus, iOS-Pflichten, Bau in GitHub
> Actions) stehen weiterhin dort und gelten hier genauso.


- Code: `woerterwerkstatt/` — statische Web-App ohne Bauschritt (ES-Module,
  kein Framework, keine fremde Bibliothek), wird vom Pages-Workflow mit
  ausgeliefert: https://katonid.github.io/prae/woerterwerkstatt/
  Nicht verwechseln mit `klassenraum/` (die Tafel) — das hier ist das
  Übungsheft. Ausführlich: `woerterwerkstatt/README.md`.
- **Fünf Stufen je Lernwort**, die immer weniger zeigen: Abschreiben →
  Buchstabensalat → Geheimschrift → Wortart samt Formen → Diktat. Eine sechste
  Übung wird in `js/uebungen/index.js` eingetragen — sonst nirgends.
- **Ein Bereich darf weniger als fünf Stufen üben** (Feld `stufen`, ab 1.4.0).
  Die Blöcke der 1. Klasse lassen die Wortart weg — Nomen, Verb und Adjektiv
  sind dort noch kein Stoff (Ansage des Nutzers, 08/2026). Gelesen wird das an
  EINER Stelle, `stufenFuer(bereich)` in `js/uebungen/index.js`; danach richten
  sich Kacheln, Sternhöchstzahl, Adressprüfung, der Weiterweg nach drei Sternen
  und die Stufenliste im Auftrag der Woche. Ein festes `STUFEN_IDS` gibt es
  nicht mehr — wer es wieder einführt, zeigt der 1. Klasse „0 von 15 Sternen"
  bei vollem Heft. Gezählt wird auf den Kacheln die Stelle IM BEREICH (1 2 3 4),
  nicht die feste Nummer der Übung (1 2 3 5).
- **Ein abgebrochener Durchgang geht weiter** (ab 1.7.0, Ansage des Nutzers,
  08/2026: „Im Unterricht ist es oft so, dass die Kinder einen ganzen
  Übungssatz nicht zu Ende bekommen."). Der Stand liegt in `store.laeufe`
  (höchstens acht, je Bereich+Päckchen+Stufe), gesichert nach JEDEM Wort und
  beim Abbrechen. Gemerkt werden nur Kennungen; passt der Stand nicht mehr
  zum Päckchen, wird er verworfen statt halb falsch fortgesetzt
  (`aufgenommen` in `lauf.js`). Er gehört zum Gerät und reist NICHT in die
  Wolke — in der Klassenansicht zählen Sterne, kein halber Durchgang.
- **Eine Notiz im Durchgang gehört ÜBER die Bühne, nicht hinein.**
  `naechstes()` räumt die Bühne für jede Karte leer. Bis 1.7.0 stand „Und
  jetzt noch einmal die Wörter, die schwer waren" mitten darin — und war im
  selben Augenblick wieder weg, in dem sie erschien. Dafür gibt es jetzt
  `laufhinweis` mit `hinweisSagen`/`hinweisWeg`.
- **Kein Fachwort ohne Erklärung.** Stufe 4 fragte nach der „2. Person
  Einzahl"; im 2. Schuljahr kennt das niemand (Ansage des Nutzers, 08/2026).
  Gefragt wird nach der „du-Form", der Fachbegriff steht im Hinweis dahinter —
  im 4. Schuljahr ist er Stoff und soll nicht verschwinden.
- **Trainingspäckchen zu 15 Wörtern.** Verteilt wird REIHUM über die Wortarten
  (`paket.js`), nicht der Reihe nach: Sonst bestünde Päckchen 1 aus lauter
  Nomen und die Wortart-Stufe wäre darin sinnlos. Die Verteilung ist gerechnet
  und nicht gespeichert — „Päckchen 2" ist auf jedem Gerät dasselbe.
- **Fünf Sorten Bereiche.** `woerter.js` = 20 Themenbereiche à 30 Wörter (nach
  Inhalt, von Haus aus sichtbar). Dazu vier Rechtschreiblisten nach
  Rechtschreibstelle, alle von Haus aus AUSGEBLENDET: `rechtschreibung1.js`
  (23 Blöcke à 8 Wörter, 1. Schuljahr, ohne Wortart-Stufe),
  `rechtschreibung2.js` (28 à 10, 2. Schuljahr), `rechtschreibung3.js`
  (25 à 15, 3. Schuljahr), `rechtschreibung.js` (27 à 15, 4. Schuljahr).
  Zusammen 1844 Wörter in 123 Bereichen. Eine neue Liste wird an vier Stellen
  eingetragen: `app.js` (`alleBereiche`, `bereicheZeigen`), `bereiche.js`
  (Wähler), `klasse.js` (Auftrag der Woche) und `sw.js`.
- **Ein Päckchen ist so groß wie sein Bereich**, höchstens aber
  `PAKETGROESSE` (15). Die Klasse-1-Blöcke haben acht Wörter, die der
  2. Klasse zehn — nirgends eine feste Zahl hineinschreiben, `pakete()`
  rechnet mit der tatsächlichen.
- **Dieselben Wörter in mehreren Klassenstufen sind Absicht**, kein Versehen:
  getrennte Sätze für getrennte Jahrgänge, freigeschaltet wird nur einer. Die
  Mehrzahl der Wochentage steht erst in Klasse 3; in Klasse 2 geht es um den
  Artikel. Sichtbarkeit steht in `store.sichtbareBereiche`;
  was dort fehlt, richtet sich nach `bereich.gruppe`. Ein ausgeblendeter
  Bereich bleibt über die Adresse erreichbar — ein Auftrag der Woche darf auf
  ihn zeigen. Die Auswahl der Lehrkraft reist über `klasse.bereicheAn` zu den
  Kindern (`klasseAuffrischen` beim Start).
  - In den Blöcken steht die **Grundform** als Lernwort, wo die
    Rechtschreibstelle erst in der abgeleiteten Form steckt (`Baum|n|der|Bäume`
    im Block „ä/äu ableiten"). Der Block heißt „ableiten"; abgeleitet wird in
    Stufe 4. Nicht auf die abgeleitete Form umstellen.
  - Nicht steigerbare Adjektive: leere Felder (`wahr|a||`), dann fragt Stufe 4
    sie nicht ab. Wortgruppen sind `x`.
- **Drei Wege hinein für Kinder**: QR-Code, Link, oder Code abtippen („👋
  Mitmachen" in der Kopfzeile). Der dritte ist der wichtigste — ohne ihn kommt
  ein Kind auf einem frischen Gerät gar nicht hinein. Die **Anmeldung ohne
  PIN** ist je Klasse zuschaltbar (`klasse.ohnePin`), aus als Vorgabe: Wer den
  Code hat, käme sonst als jedes Kind hinein. Ein NEUES Kind braucht immer eine
  PIN. Der Klassencode kennt kein I, O, 0 oder 1 — deshalb wird bei der Eingabe
  NICHT geraten und umgewandelt, sondern nur großgeschrieben.
- **Wortformen stehen in den Daten, sie werden NIE gerechnet** (`woerter.js`,
  600 Wörter in 20 Bereichen; `rechtschreibung.js`, 405 in 27 Blöcken). Die deutsche Mehrzahl ist nicht regelmäßig
  (Baum → Bäume, aber Wort → Wörter und Ort → Orte). Eine erfundene Form, die
  die App als richtig ausgibt, lehrt das Falsche, und niemand merkt es. Beim
  Anlegen eigener Bereiche schlägt `bereiche.js` deshalb nur Verbformen und
  Steigerungen vor — nie eine Mehrzahl.
- **Die Geheimschrift ist das Buchstabenhaus** (Dach: b d f h k l t ß und alle
  großen; Mitte: alle; Keller: g j p q y), gezeichnet als SVG in
  `js/wortbild.js`. Fertige Wortbildschriften der Schulbuchverlage gibt es,
  aber sie sind lizenzpflichtig und müssten nachgeladen werden — das bricht
  Offline-Betrieb und Datensparsamkeit. Nicht durch eine Schrift ersetzen.
- **Zur Geheimschrift gehört die Wortliste des Päckchens** (ab 1.6.0, Ansage
  des Nutzers 08/2026). Ohne sie prüft die Übung, ob ein Kind fünfzehn Wörter
  auswendig kann — nicht, ob es das Wortbild gespeichert hat. Im Heft steht
  die Liste daneben und man ordnet zu; das ist die Aufgabe. Die Liste zeigt
  nur die Wortkerne (wie das Bild), alphabetisch, und ist wegschaltbar
  (`einstellungen.geheimWortliste`). Dafür reicht `lauf.js` das ganze Päckchen
  an `aufbauen` durch — nicht wieder herausnehmen.
- **Ein Großbuchstabe hat im Wortbild links einen dicken Strich** (ab 1.8.0,
  Ansage des Nutzers, 08/2026: „Die Kinder in meiner Klasse sind darauf
  trainiert."). Das ist das einzige verlässliche Kennzeichen — b, d, f, h, k,
  l, t und ß ragen ebenfalls ins Dachgeschoss. Die zusätzliche Höhe bleibt
  daneben (ausdrücklich erlaubt), der gefüllte Kasten nicht: Auf einer vollen
  Fläche wäre der Strich nicht zu sehen. `grossrand()` in `wortbild.js`,
  gezeichnet in BEIDEN Darstellungen.
- **Was die Sprachausgabe hergibt: Text, Stimme, Tempo, Tonhöhe — mehr nicht.**
  Eine Betonung einzelner Silben verlangt SSML, und das nimmt keine
  Browser-Sprachausgabe entgegen (gefragt 08/2026). Nicht versprechen. Was
  hilft: langsameres Tempo (Vorgabe 0,7), Tonhöhe 1,0 statt 1,05, ein Punkt
  am Ende (ein nacktes Wort wird als Bruchstück genuschelt) und die WAHL der
  Stimme — welche deutschen Stimmen ein Gerät mitbringt und wie deutlich die
  sind, kann die App nicht wissen, also entscheidet die Lehrkraft
  (`einstellungen.diktatStimme`). Silben NICHT selbst trennen: Die deutsche
  Silbentrennung ist nicht ableitbar, und eine falsche lehrt das Falsche —
  dieselbe Regel wie bei den Wortformen.
- **Groß und klein wird beim Prüfen verglichen** (`uebungen/schreibfeld.js`).
  Das IST der halbe Rechtschreibstoff der Grundschule. Zwei Versuche, dann
  steht die Lösung da und wird abgeschrieben; für die Wertung zählt nur der
  erste Versuch. Nicht „großzügiger" machen.
- **Eine Rückmeldung muss den Fehler benennen, den das Kind gemacht hat**
  (`warumFalsch` in `schreibfeld.js`, ab 1.6.0). „baum" statt „der Baum" war
  bis dahin „Schon der erste Buchstabe stimmt nicht" — falsch beschrieben und
  entmutigend: Das Kind konnte das Wort. Vor der Stellenangabe stehen deshalb
  zwei Fälle mit **Vorrang** vor dem übungseigenen `zusatzhinweis`: nur groß
  oder klein (mit der Regel dazu) und der fehlende oder falsche Artikel. Wer
  eine neue Rückmeldung baut, prüft sie an genau diesen Eingaben.
- **Nach dem zweiten Fehlversuch wird die Stelle markiert**, nicht bloß die
  Lösung gezeigt. Abschreiben ohne Hinsehen lehrt niemanden etwas. Die Marke
  ist unterlegt UND unterstrichen — Farbe allein sieht ein farbfehlsichtiges
  Kind nicht.
- **Jede Stufe hilft mit dem, was sie weiß**: Der Salat vergleicht den
  Buchstabenvorrat („ein n kommt oben gar nicht vor"), die Geheimschrift das
  Häuschen, das Abschreiben zeigt im Blitzmodus das Wort nach einem
  Fehlversuch zwei Sekunden wieder (sonst wäre der zweite Versuch geraten —
  die Aufgabe heißt „schreib es ab"). Das zählt wie ein Spicken.
- **Der QR-Code wird selbst gerechnet** (`js/qr.js`, Byte-Modus, Stufe L/M,
  Fassungen 1–10). Geprüft wird mit `scripts/qr-pruefen.py` gegen OpenCV
  (Rücklesen) und segno (feste Muster) — beides nur zum Prüfen, nicht im Repo.
  **Nach jeder Änderung an qr.js laufen lassen:** Ein Code, bei dem ein
  einziges Modul falsch sitzt, sieht tadellos aus und wird von keiner Kamera
  gelesen. Genau das ist beim Bau zweimal passiert (Format-Information um
  90 Grad verdreht, beide Ausfertigungen einzeln).
- **Die PIN eines Kindes liegt nirgends lesbar.** Gespeichert wird ein
  SHA-256-Abdruck über Code, Name und PIN, in einem Zweig ohne Leserecht;
  angemeldet wird durch einen Schreibversuch, den die Datenbankregel nur bei
  Übereinstimmung annimmt (`cloud.js`).
- **Die Schulverwaltung steht in den REGELN, nicht in der App** (`admin.js`, ab
  1.5.0, Ansage des Nutzers 08/2026: „Ich möchte Admin-Befugnisse haben:
  Andere Accounts (Lehrer u. Schüler) erstellen, ändern und löschen."). Die App
  trägt weder eine Adresse noch eine Liste mit sich, sondern PROBIERT
  (`verwaltungPruefen`): Wer `woerterwerkstatt/users` auflisten darf, ist
  Verwaltung — nur dann erscheint „🏫 Schule". So braucht eine weitere
  Verwaltung keine neue Fassung der App. Berechtigt sind die in den Regeln
  genannte E-Mail (der Einstieg, sonst gäbe es ein Henne-Ei-Problem) und alle
  unter `admins/<uid>`.
- **`users/<uid>/klassen` ist nur ein VERZEICHNIS, keine Wahrheit** (ab 1.5.1).
  Die Klasse selbst steht unter `klassen/<CODE>`; das Anlegen schreibt beides,
  aber es sind ZWEI Schreibvorgänge. Bricht der zweite ab, ist die Klasse auf
  jedem anderen Gerät unsichtbar — obwohl der QR-Code gilt und die Kinder
  weiter üben (genau so gemeldet, 08/2026). „Meine Klassen" führt deshalb
  Wolke und Gerät ZUSAMMEN (vorher entweder/oder), trägt fehlende Einträge
  über `klasseWiederEintragen` nach und bietet „Klasse per Code holen" für den
  Fall, dass ein Gerät gar nichts mehr weiß. Angenommen wird nur, was
  `besitzer === konto.uid` trägt — den Code haben alle Kinder der Klasse.
- **Eine misslungene Netzabfrage darf nicht als leere Liste erscheinen.** Bis
  1.5.0 fiel „Meine Klassen" bei jedem Fehler stumm auf die Geräteliste
  zurück; wer nichts sah, konnte „es gibt keine" und „ich durfte nicht
  nachsehen" nicht unterscheiden.
- **Kinder verwaltet die Schulverwaltung NICHT selbst**, sie öffnet die
  gewohnte Klassenansicht. Zwei Oberflächen für dieselbe Aufgabe liefen mit
  Sicherheit auseinander.
- **Kennwort vergessen: Mail statt Setzen.** `zugangsmailSenden` schickt über
  `sendOobCode` (PASSWORD_RESET) einen Link an die hinterlegte Adresse; die
  Kollegin setzt selbst neu, das alte gilt bis dahin weiter. Ein Kennwort
  direkt zu setzen verlangt das Zeichen des betroffenen Kontos — und ein
  Kennwort, das die Verwaltung kennt, ist keines. Zwei Wege in der App: im
  Konto der Lehrkraft und, falls dort keine Adresse steht, „✉️ Kennwort-Mail"
  in der Übersicht an eine frei eingetippte Adresse.
- **Die E-Mail im Verzeichnis trägt sich beim ANMELDEN nach** (ab 1.8.1). Bis
  dahin schrieb nur `kontoAnlegen` ein Profil — wer sich vorher angemeldet
  hatte oder bei wem der Schreibvorgang durchfiel, stand ohne E-Mail da, und
  der Knopf zum Zurücksetzen war ausgerechnet für die Kolleginnen grau, um die
  es geht. `anmelden` schreibt deshalb `profil/email` per PATCH nach — den
  NAMEN aber nicht: Hat die Verwaltung ihn geändert, überschriebe ihn sonst
  die nächste Anmeldung der Lehrkraft.
- **Ein fremdes Firebase-Konto zu löschen geht vom Browser aus nicht** — das
  verlangt das Admin-SDK mit Dienstschlüssel, und der wäre in einer Web-App der
  Generalschlüssel zur Datenbank, mitgeliefert auf jedem Kindergerät. Die App
  löscht die DATEN einer Lehrkraft und führt für die Anmeldung in die
  Firebase-Konsole. Nicht „lösen" wollen. Anlegen (`signUp`) und die Mail zum
  Zurücksetzen (`sendOobCode`) gehen dagegen; beim Anlegen darf das
  zurückgegebene Zeichen NICHT gesichert werden, sonst ist die Verwaltung
  anschließend als die neue Lehrkraft unterwegs.
- **Ein Kind umbenennen heißt neue PIN.** Der Name ist der Schlüssel und steckt
  im Abdruck; lesen lässt der sich nirgends. `kindUmbenennen` legt deshalb erst
  alles Neue an (Abdruck, Kind, Protokoll) und nimmt dann das Alte weg — bricht
  es dazwischen ab, gibt es ein Kind zu viel, nie eines zu wenig.
- **Beim Löschen einer Klasse zählt die Reihenfolge.** `geheim/<CODE>` fragt
  nach `klassen/<CODE>/besitzer`; ist die Klasse zuerst weg, bleiben die
  PIN-Abdrücke für immer liegen — unlesbar und unlöschbar. Erst `geheim`,
  `anmeldung`, `protokoll`, dann die Klasse. Bis 1.4.0 blieben alle drei
  stehen, und „Protokoll der Klasse löschen" scheiterte stillschweigend, weil
  `.write` nur am `$kind` stand.
- **Die Datenbankregeln stehen im Wurzelverzeichnis: `firebase-rules.json`**,
  mit den Zweigen BEIDER Web-Apps in einer Datei. Die Firebase-Konsole ersetzt
  beim Veröffentlichen die kompletten Regeln — wer nur einen Zweig einfügt,
  sperrt die andere App aus. Genau das passierte 08/2026, als die
  Wörterwerkstatt dazukam: Ihr Zweig fehlte, die Datenbank wies dort alles ab,
  und es ließ sich keine Klasse anlegen. Die Dateien in `klassenraum/` und
  `woerterwerkstatt/` sind nur noch Einzelfassungen zum Nachschlagen.
- **In die Regeldateien gehört NICHTS außer Regeln.** Der Editor kennt oben nur
  `rules`, als Regelarten nur `.read`, `.write`, `.validate`, `.indexOn` und als
  deren Werte nur `true`/`false`/Text. Ein erklärender Schlüssel oder ein Array
  lässt das Einfügen mit einem Syntaxfehler scheitern — die Dateien trugen
  kurzzeitig `_hinweis`-Schlüssel und wären so nicht einzufügen gewesen. Die
  Erläuterung steht in `firebase-rules.md` daneben. Vor dem Einfügen prüft
  `woerterwerkstatt/scripts/regeln-pruefen.py` beides — Regelarten und
  Deckungsgleichheit mit den Einzelfassungen.
- **Die Regeln IMMER als Text in die Antwort schreiben, nie als Dateiverweis**
  (Ansage des Nutzers, 08/2026, wörtlich: „Bitte gib mir immer den verfluchten
  Text für die Regeln so an, dass ich ihn hier kopieren kann. Ich habe auf dem
  iPad keine große Möglichkeit, in eine dämliche JSON-Datei einzusehen."). Der
  Nutzer arbeitet am iPad; „steht in `firebase-rules.json`" ist dort keine
  Anweisung, sondern eine Sackgasse. Also: den vollständigen Inhalt in einen
  Codeblock, vorher frisch aus `main` lesen und mit `regeln-pruefen.py`
  prüfen. Das gilt bei JEDER Änderung an den Regeln und bei jeder Antwort, in
  der das Einspielen vorkommt — ohne Nachfrage. Dasselbe gilt sinngemäß für
  alles andere, was der Nutzer irgendwo einfügen soll.
- **Nach jeder Änderung am JavaScript `module-pruefen.mjs` laufen lassen**
  (`node --experimental-vm-modules woerterwerkstatt/scripts/module-pruefen.mjs`).
  Die App hat keinen Bauschritt: Eine fehlende Klammer in einer verschachtelten
  `h(...)`-Reihe und ein Import, den es nicht gibt, sehen beide gleich aus —
  die Seite bleibt weiß, und die Meldung steht nur in der Entwicklerkonsole.
  Beides ist beim Bau passiert (`meldung` aus `util.js` statt `ui.js`; eine
  Klammer zu wenig in `admin.js`).
- **Ein Einrichtungsfehler muss sich erklären.** Die App meldete den Fall oben
  als „NICHT_ERLAUBT" in einem Streifen, der nach vier Sekunden verschwand —
  das ist keine Meldung, das ist ein Rätsel. Seit 1.0.2 prüft
  `cloud.regelnPruefen()` beim Öffnen von „Meine Klassen" einmal nach und
  zeigt bei gesperrtem Zweig einen STEHENDEN Kasten mit den drei Schritten;
  „Neue Klasse" ist so lange ausgegraut. `cloud.klartext()` übersetzt die
  Rohfehler — nie wieder eine Konstante in Großbuchstaben in die Oberfläche
  durchreichen.
- **Der Wegweiser darf NIE aus einem Datenereignis heraus laufen.**
  `wegLesen()` (app.js) öffnet Blätter und stellt Netzanfragen. In 1.0.3 hing
  es an der Meldung „Bereiche geändert" — und ein Kind, das einer Klasse
  beitritt, sichert genau dabei die mitgegebenen Bereiche. Gemessen: 277
  Netzanfragen und 279 gestapelte Blätter in vier Sekunden; auf dem iPad war
  nichts einzutippen, auf dem Telefon starb der Tab. Seit 1.0.4 dreifach
  abgesichert: Ein Datenereignis zeichnet höchstens die Bühne neu; der
  Wegweiser merkt sich den offenen Beitrittscode und öffnet kein zweites
  Blatt; `bereichSichern` meldet nur bei echter Änderung. Wer einen neuen
  Horcher anlegt, ruft darin nie den Wegweiser.
- **Das Wortprotokoll ist die Ausnahme von der Datensparsamkeit** (ab 1.0.5,
  Ansage des Nutzers: „als Lehrer möchte ich nachsehen können, welche Wörter
  die Kinder bearbeitet haben und welche Fehler sie gemacht haben"). Gemeldet
  wird je Wort, wie oft es drankam, wie oft es beim ersten Versuch saß, in
  welchen Stufen — und WIE das Kind es geschrieben hat. Letzteres ist der
  Zweck: „Somer" sagt einer Lehrkraft, was falsch gemerkt wurde; eine
  Fehlerzahl sagt es nicht.
  - **Es liegt in `protokoll/<CODE>/<Kind>`, nicht unter `klassen/`.** Dort
    darf lesen, wer den Code hat — das sind alle Kinder der Klasse. Schreiben
    darf jedes Kind, lesen nur die angemeldete Besitzerin. Nicht verschieben.
  - **Die Leseerlaubnis gehört an den `$code`, nicht an das `$kind`** (ab
    1.5.0). Die Klassenansicht liest `protokoll/<CODE>` in einem Zug; eine
    Erlaubnis, die nur am einzelnen Kind steht, deckt das nicht — RTDB-Regeln
    reichen nach UNTEN durch, nicht nach oben. Von 1.0.5 bis 1.4.0 schrieben
    die Kinder deshalb brav mit, und die Lehrkraft bekam den Zweig nie zu
    sehen (gemeldet 08/2026 als „da wurde wohl nichts übertragen").
  - **Und die App schwieg dazu**: `protokollDerKlasse(...).catch(() => [])`
    machte aus „darf nicht" ein „noch nichts da". Seit 1.5.2 steht bei
    NICHT_ERLAUBT ein stehender Kasten mit den drei Schritten, und die
    Fälle „abgeschaltet" und „noch niemand hat geübt" sagen sich getrennt.
    Kein `catch`, der einen Rechtefehler in Leere verwandelt.
  - Gedeckelt auf sechs Falschschreibungen je Wort und 500 Wörter je Kind
    (`store.js`). Mehr sagt nichts Neues und lädt bei jedem Päckchen mit hoch.
  - **Abschaltbar je Klasse** (`klasse.protokoll === false`) und löschbar
    (Knopf in der Klassenansicht). Das sind Leistungsdaten namentlich
    genannter Kinder — beides nicht wegrationalisieren.
  - **Zwei Ansichten, und die zweite hängt am Namen des Kindes**: „Was der
    Klasse schwerfällt" (Knopf) fasst alle zusammen, ein Tipp auf den NAMEN
    zeigt das einzelne Kind. Der Name muss deshalb wie ein Knopf aussehen —
    📋, gepunktete Unterstreichung, dazu ein Satz über der Liste (ab 1.5.3).
    Bis dahin war er nur eingefärbt, und der Nutzer fragte, ob es die
    Einzelansicht überhaupt gibt (08/2026), obwohl sie seit 1.0.5 steht.
  - **Gezeigt werden nur die Wörter, die danebengingen** (ab 1.7.1). Die
    vollständige Liste „Saß auf Anhieb" darunter war gut gemeint und im Weg:
    Wer nachsieht, sucht Fehler (Ansage des Nutzers, 08/2026). Was gesessen
    hat, sagt eine Zeile. Dieselbe Regel gilt für die Klassenübersicht — und
    die Kopfzeile nennt die Zahl der GEZEIGTEN Wörter, nicht die aller.
  - Das Kind sieht seine eigene Liste unter „?" → „Deine schweren Wörter". Wer
    die Daten erzeugt, darf sie sehen.
- **Sterne gehen weiterhin an die Klasse**, und keine Rangliste zwischen
  Kindern, nirgends.
- **CSS schreibt keine deutschen Wörter groß** (ab 1.7.1). `text-transform:
  uppercase` macht aus „Saß auf Anhieb" ein „SASS AUF ANHIEB" — die
  Großschreibregel für ß ist SS, und der Browser wendet sie an. In einer
  Rechtschreib-App ist das ein Fehler wie jeder andere: Ein Kind liest dort
  ein falsch geschriebenes Wort (gemeldet 08/2026: „geht gar nicht!").
  `seite__abschnitt`, `abschnitt__titel` und `wortzeile__formfeld` zeichnen
  sich deshalb über Gewicht, Farbe und Sperrung aus. Die kleinen festen
  Marken („GESCHRIEBEN ALS") dürfen bleiben — dort steht nie ein ß, und wer
  eine neue anlegt, prüft genau das.
- **Kein `alert`, `confirm` oder `prompt`** — in einer späteren WKWebView-Hülle
  passiert dabei schlicht nichts. Für Ja/Nein gibt es `frage()`, für eine
  Eingabe `eingabe()`, beide in `js/ui.js`.
- **Alles Plattformnahe läuft über `js/plattform.js`** — Sprachausgabe, Haptik,
  Zwischenablage, Bildschirm wach halten, Vollbild. Das ist die einzige Datei,
  die eine native Hülle bedienen müsste; wer irgendwo direkt
  `speechSynthesis` aufruft, verschiebt die Portierungsarbeit von einer Datei
  auf alle. Der Weg zu einer iOS-App steht in `docs/woerterwerkstatt/ios.md`.
- **Blau, Orange, Gelb — kein Grün, kein Lila** (Ansage des Nutzers, 08/2026).
  Blau ist die Arbeitsfarbe (Knöpfe, Fokus, Wortbild), Orange und Gelb sind
  die Belohnung (Sterne, Fortschritt, Auftrag der Woche, Konfetti). Die fünf
  Stufen laufen kühl → warm mit; Nomen blau, Verben orange, Adjektive gelb.
  Zwei Fallen dabei:
  - **Nie einen Verlauf von Blau nach Orange.** Die liegen auf dem Farbkreis
    gegenüber und treffen sich in schmutzigem Grau. Deshalb trägt jedes Schema
    in `SCHEMATA` (`js/store.js`) seinen Verlauf ausgeschrieben, statt ihn aus
    `von/mitte/bis` zu rechnen: Die drei sind die Hintergrundwolken (dort
    dürfen Blau und Orange nebeneinander), `verlauf` und `warm` bleiben je in
    EINER Farbfamilie. `theme.js` reicht beide nur durch.
  - **„Richtig" ist blau statt grün** — deshalb steht vor jeder Rückmeldung ein
    Zeichen (✓ / ↻ / ✗). Die Farbe darf die Antwort begleiten, tragen muss sie
    das Zeichen und der Wortlaut. Nicht wieder entfernen.
- Schriften liegen als woff2 in `woerterwerkstatt/fonts/` (Andika, Lexend,
  Quicksand — alle mit einstöckigem a und g) und werden **nie** von fremden
  Servern geladen. Die App-Icons erzeugt `scripts/generate-icons.py`.
- **Das Homescreen-Icon braucht PNG ohne Alphakanal** (Farbtyp 2, ab 1.4.0).
  Mit Alphakanal legt iOS das Icon auf Schwarz, und mancher Android-Starter
  zeigt gar keins. Erzeugt werden sie von `scripts/generate-icons.py`
  (dreizehn Größen plus zwei maskierbare) — nie von Hand. Im Manifest stehen
  die PNGs VOR dem SVG: Ein SVG mit `"sizes": "any"` gewinnt sonst die Auswahl
  und wird beim Installieren nicht gerastert. iOS liest kein Manifest, es
  braucht `apple-touch-icon` im `index.html`, mit `sizes` je Größe.
- **Der vorgeschlagene Name steht an ZWEI Stellen** (ab 1.8.2): iOS nimmt
  `apple-mobile-web-app-title` aus dem `index.html`, Android `short_name` aus
  dem Manifest. Beide sagen „Wörterwerkstatt" — bis 1.8.1 stand dort „Wörter",
  und genau das schlug das iPad beim Ablegen vor (gemeldet 08/2026). Dass iOS
  unter dem Symbol nach rund zwölf Zeichen abschneidet, ist in Kauf genommen:
  Der Vorschlag soll die App benennen, nicht schon zurechtgestutzt sein —
  ändern kann man ihn beim Ablegen ohnehin. Fehlt das Meta ganz, nimmt iOS den
  `<title>`, und der trägt den Untertitel mit.
- Die Fassungsnummer steht in `js/version.js` UND in `sw.js` (`FASSUNG`) — der
  Service Worker lädt keine Module. Beide bei jeder neuen Fassung hochsetzen,
  sonst bleibt der alte Zwischenspeicher stehen.
