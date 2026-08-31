# Wörterwerkstatt

Rechtschreibung üben in der Grundschule. Statische Web-App ohne Bauschritt
(ES-Module, kein Framework, keine Abhängigkeiten), wird vom Pages-Workflow des
Repos mit ausgeliefert:

**https://katonid.github.io/prae/woerterwerkstatt/**

Nicht zu verwechseln mit `klassenraum/` — das ist die Tafel-App. Diese hier ist
das Übungsheft.

## Die fünf Stufen

Ein Lernwort sitzt nicht, weil man es einmal abgeschrieben hat. Die App führt
es durch fünf Stufen, die immer weniger zeigen und immer mehr verlangen:

| # | Stufe | Was zu sehen ist | Was gefragt ist |
|---|-------|------------------|-----------------|
| 1 | **Abschreiben** | das Wort (dauerhaft, drei Sekunden lang oder auf Knopfdruck) | genau abschreiben |
| 2 | **Buchstabensalat** | die Buchstaben, durcheinander | das Wort erkennen und schreiben |
| 3 | **Geheimschrift** | nur die Gestalt: groß/klein, Dach/Mitte/Keller | das Wort erkennen und schreiben |
| 4 | **Wortart** | das Wort | Nomen, Verb oder Adjektiv? Und dann die Formen |
| 5 | **Diktat** | nichts | nach Gehör schreiben |

Stufe 4 fragt je nach Wortart andere Formen ab: Nomen in Ein- und Mehrzahl
(mit Artikel), Verben in Grundform und 2. Person Einzahl, Adjektive in allen
drei Steigerungsstufen. Wörter, die nichts davon sind („heute“, „zusammen“),
gibt es auch — sonst wäre die Frage nach der Wortart keine.

### Zur Geheimschrift

Das ist das **Buchstabenhaus**, wie es in der Grundschule seit Jahrzehnten an
der Tafel steht (auch „Häuschenschrift“, „Wortbild“, „Wortkontur“):

```
Dachgeschoss   b d f h k l t ß  und alle großen Buchstaben
Erdgeschoss    a c e i m n o r s u v w x z ä ö ü   (hier wohnen alle)
Keller         g j p q y
```

Es gibt fertige Wortbild- und Konturschriften der Schulbuchverlage, aber sie
sind fast durchweg kostenpflichtig lizenziert und müssten nachgeladen werden.
Beides bricht die Zusagen dieser App (läuft ohne Netz, meldet nichts an
Dritte), deshalb zeichnet `js/wortbild.js` die Wortbilder selbst als SVG —
beliebig groß skalierbar, färbbar, und in einer nativen Hülle unverändert
brauchbar. Zwei Darstellungen: **Häuschen** (ein Kasten je Buchstabe, man kann
sie zählen) und **Umriss** (die Kästen wachsen zu einer Kontur zusammen — die
schwerere Fassung, wie beim „Wortbilder umranden“ im Heft).

## Trainingspäckchen

Fünfzehn Lernwörter je Päckchen — die übliche Größe einer Wochenliste, und in
einer Viertelstunde zu schaffen. Die Wörter werden **reihum über die Wortarten**
auf die Päckchen verteilt, nicht der Reihe nach: Sonst bestünde Päckchen 1 aus
lauter Nomen und Stufe 4 wäre darin ein Witz. Die Verteilung ist fest gerechnet,
nicht gespeichert — „Päckchen 2“ ist deshalb auf jedem Gerät dasselbe Päckchen.

Sterne: drei, wenn jedes Wort gleich beim ersten Versuch saß; zwei ab 80 %,
einer ab 60 %. Gemerkt wird der **beste** Durchgang.

**Nicht jeder Bereich übt alle fünf.** Ein Bereich darf über das Feld `stufen`
weniger verlangen — die Blöcke der 1. Klasse lassen die Wortart-Stufe weg, denn
ob ein Wort Nomen, Verb oder Adjektiv ist, ist dort noch kein Stoff (Ansage des
Nutzers). Wer das liest, ist `stufenFuer(bereich)` in `js/uebungen/index.js`;
danach richten sich die Kacheln, die Sternhöchstzahl, der Weiterweg nach drei
Sternen und die Stufenliste im Auftrag der Woche. Fehlt das Feld, gelten alle
fünf. Gezählt wird auf den Kacheln, was der Bereich übt (1 2 3 4), nicht die
feste Nummer der Übung (1 2 3 5).

## Bereiche: zwanzig Themen, hundertdrei Rechtschreibblöcke

Zwei Sorten, in fünf Dateien:

| Datei | sortiert nach | Stufe | Umfang | von Haus aus |
|---|---|---|---|---|
| `js/woerter.js` | **Inhalt** (Schule, Tiere, Wetter) | — | 20 × 30 Wörter (2 Päckchen) | **sichtbar** |
| `js/rechtschreibung1.js` | **Rechtschreibstelle** | 1. Schuljahr | 23 × 8 Wörter | ausgeblendet |
| `js/rechtschreibung2.js` | **Rechtschreibstelle** | 2. Schuljahr | 28 × 10 Wörter | ausgeblendet |
| `js/rechtschreibung3.js` | **Rechtschreibstelle** | 3. Schuljahr | 25 × 15 Wörter | ausgeblendet |
| `js/rechtschreibung.js` | **Rechtschreibstelle** | 4. Schuljahr | 27 × 15 Wörter | ausgeblendet |

Zusammen **1844 Wörter in 123 Bereichen**. Die Rechtschreibpäckchen sind
ausgeblendet, weil hundert zusätzliche Karten für ein Kind, das eine Woche
lang ein einziges Päckchen übt, nur Gestrüpp wären.

**Ein Päckchen ist so groß wie sein Bereich.** Die Klasse-1-Blöcke haben acht
Wörter, die der 2. Klasse zehn, die anderen fünfzehn; gerechnet wird mit der tatsächlichen Zahl, nicht
mit einer festen. Ein Bereich mit mehr als fünfzehn Wörtern wird in mehrere
Päckchen geteilt (die Themenbereiche in zwei). Die Lehrkraft schaltet unter
**⚙︎ → Bereiche wählen** frei, was gerade dran ist — und kann dort auch
Themenbereiche abwählen. Hat sie eine Klasse, gibt sie ihre Auswahl über
**Klasse → Bereiche für die Klasse** an die Kinder weiter; deren Geräte
übernehmen sie beim nächsten Öffnen.

Ein ausgeblendeter Bereich bleibt über die Adresse erreichbar. Das ist
Absicht: Ein Auftrag der Woche darf auf einen Block zeigen, der nicht auf der
Startseite steht.

### Drei Entscheidungen in den Rechtschreibpäckchen

1. **Wo die Rechtschreibstelle erst in der abgeleiteten Form steckt, steht die
   Grundform als Lernwort.** Im Block „ä/äu ableiten“ also `Baum` mit der
   Mehrzahl `Bäume`, nicht `Bäume` allein — der Block heißt „ableiten“, und
   abgeleitet wird in Stufe 4. Dasselbe beim silbentrennenden h (`Schuh` →
   `die Schuhe`, `früh` → `früher`).
2. **Nicht steigerbare Adjektive haben leere Steigerungsfelder** (`wahr|a||`).
   Stufe 4 fragt sie dann nicht ab, statt eine Form zu verlangen, die es nicht
   gibt.
3. **Wortgruppen sind „keines davon“** (`beim Essen|x`). Im Block
   „Großschreibung“ geht es um die Großschreibung, und die prüfen die Stufen
   1, 2, 3 und 5 ohnehin buchstabengenau.

Dazu drei Kleinigkeiten: **Trennbare Verben** stehen mit der ganzen „du“-Form
da (`anfangen|v|fängst an` → „du fängst an“). **`gern`** ist streng genommen
ein Adverb, steht aber in jedem Schulbuch bei der unregelmäßigen Steigerung
und ist deshalb als Adjektiv eingetragen. Und in Klasse 2 wird **nicht
gesteigert**, wo es nicht Stoff ist — Farbwörter bleiben Adjektive mit leeren
Steigerungsfeldern, statt zu „keines davon“ zu werden.

**Dieselben Wörter kommen in mehreren Klassenstufen vor** (ck, tz, ie,
Dehnungs-h). Das ist richtig so: Es sind getrennte Sätze für getrennte
Jahrgänge, und freigeschaltet wird ohnehin nur einer. Die Mehrzahl der
Wochentage steht deshalb erst in Klasse 3 — in Klasse 2 geht es um den
Artikel.

## Zwanzig mitgelieferte Bereiche

600 Wörter in `js/woerter.js`, je 30 pro Bereich (= zwei Päckchen), ausgewählt
nach den typischen Rechtschreibstellen der Grundschule: Doppelkonsonant, ie,
Dehnungs-h, ck/tz, äu/eu, v/f und die Umlautbildung in der Mehrzahl.

Format je Wort — ein Textstück mit senkrechten Strichen:

```
Tornister|n|der|Tornister         Nomen:    Wort | n | Artikel | Mehrzahl („-“ = keine)
laufen|v|läufst                   Verb:     Wort | v | 2. Person Einzahl
schnell|a|schneller|am schnellsten Adjektiv: Wort | a | 1. Steigerung | 2. Steigerung
heute|x                           sonst:    Wort | x
```

**Die Formen stehen in den Daten und werden nicht gerechnet.** Die deutsche
Mehrzahl ist nicht regelmäßig (Baum → Bäume, Raum → Räume, aber Wort → Wörter
und Ort → Orte). Ein Kind, dem die App eine erfundene Form als richtig
vorsetzt, lernt das Falsche — und niemand merkt es.

## Eigene Bereiche und Klassen

Zum Üben braucht es keine Anmeldung. Mit einem Konto (Firebase, dieselbe
`firebase-config.js` wie der Klassenraum) kann eine Lehrkraft:

* **eigene Bereiche** anlegen — die Lernwörter dieser Woche. Beim Eintragen
  schlägt die App Verbformen und Steigerungen vor (nie eine Mehrzahl, siehe
  oben); der Vorschlag lässt sich überschreiben.
* **Klassen** anlegen. Dabei entsteht ein sechsstelliger Code, den die App als
  QR-Code zeigt (groß für den Beamer, mit Druckansicht). Die Kinder scannen
  ihn, suchen sich Benutzernamen und vierstellige PIN aus, und ihre Sterne
  laufen in die Klassenansicht zurück.
* einen **Auftrag der Woche** setzen („Päckchen 2, Stufe Diktat“) — er steht
  bei den Kindern ganz oben.
* **nachsehen, welche Wörter die Kinder bearbeitet haben und wie sie sie
  geschrieben haben** (siehe unten).

### Was die Kinder geschrieben haben

Zwei Ansichten in der Klasse:

* **„Was der Klasse schwerfällt“** — alle Wörter über alle Kinder, die
  schwersten zuerst, mit den tatsächlichen Falschschreibungen und der Zahl der
  betroffenen Kinder. Das ist die Ansicht, für die das Ganze da ist: Sie sagt
  in fünf Sekunden, was am Montag noch einmal an die Tafel gehört.
* **Ein Kind antippen** — seine Wörter einzeln, getrennt nach „schwer
  gefallen“ und „saß auf Anhieb“, je Stufe aufgeschlüsselt.

Festgehalten wird je Wort: wie oft es drankam, wie oft es beim ersten Versuch
saß, in welchen Stufen — und **wie das Kind es geschrieben hat**, wenn es
danebenlag. Letzteres ist der eigentliche Wert: „Somer“ statt
„Sommer“ zeigt, *was* falsch gemerkt wurde. Bei Stufe 4 wandert auch eine
falsch geratene Wortart mit hinein („hielt Verb für Nomen“) — das ist eine
andere Auskunft als ein Rechtschreibfehler.

Gedeckelt auf sechs Falschschreibungen je Wort und 500 Wörter je Kind; die
siebte sagt nichts Neues mehr, und jedes weitere Datum über ein Kind, das ohne
Nutzen herumliegt, ist eins zu viel.

**Wer darf das sehen:** nur die Lehrkraft, der die Klasse gehört. Das
Protokoll liegt in einem eigenen Zweig (`protokoll/<CODE>/<Kind>`), in den
jedes Kind schreiben, aber nur die angemeldete Besitzerin lesen darf — unter
`klassen/` läge es für alle Kinder offen. Das Kind selbst sieht seine eigene
Liste unter „?“ → „Deine schweren Wörter“.

**Abschaltbar und löschbar:** In der Klassenansicht gibt es einen Schalter
„Mitschreiben“ und einen Knopf, der das Protokoll der ganzen Klasse löscht.
Das sind Leistungsdaten namentlich genannter Kinder — sie liegen in der
Datenbank, bis jemand sie löscht.

### Wie die Kinder hineinkommen

Drei Wege, alle enden im selben Blatt:

* **QR-Code scannen** — der Regelfall an der Tafel.
* **Link antippen**, wenn die Lehrkraft ihn verschickt hat.
* **Code abtippen** — Knopf „👋 Mitmachen“ in der Kopfzeile, dann die sechs
  Zeichen. Für ein Kind auf einem frischen Gerät ohne QR-Code in Sichtweite;
  ohne diesen Weg käme es gar nicht hinein.

Beim ersten Mal sucht sich das Kind Namen und vierstellige PIN aus, danach
meldet es sich damit wieder an. **Vergisst es die PIN**, gibt es zwei
Auswege: Die Lehrkraft vergibt eine neue (Knopf „PIN“ bei jedem Kind), oder
sie erlaubt für ihre Klasse die **Anmeldung ohne PIN** (Schalter in der
Klassenansicht). Das ist bequem und ehrlich gesagt kein Schutz mehr — wer den
Klassencode hat, kommt dann als jedes Kind hinein. Deshalb ist es aus und
gehört der Entscheidung der Lehrkraft. Ein *neues* Kind braucht immer eine
PIN, sonst hätte es später keine, die man ihm sagen könnte.

### Wie die PIN geschützt ist

Gespeichert wird nie die PIN, sondern ein SHA-256-Abdruck über Klassencode,
Benutzernamen und PIN. Der liegt in einem Zweig, den **niemand lesen darf** —
auch die App nicht. Angemeldet wird durch einen Schreibversuch: Die
Datenbankregel nimmt den Abdruck nur an, wenn er mit dem hinterlegten
übereinstimmt. Geht der Schreibversuch durch, war die PIN richtig.

Ehrlich dazugesagt: Vier Ziffern sind zehntausend Möglichkeiten, und gegen
jemanden, der sie durchprobiert, hilft ohne eigenen Server nichts. Es geht um
Rechtschreibfortschritte einer Grundschulklasse. Wer mehr Schutz braucht, gibt
den Kindern keinen Zugang, sondern übt am gemeinsamen Gerät.

### Datenbankregeln — ohne sie geht keine Klasse

**Einzufügen ist `firebase-rules.json` aus dem Wurzelverzeichnis des Repos**
(Firebase-Konsole → Realtime Database → Reiter „Regeln“ → alles ersetzen →
Veröffentlichen). Diese Datei enthält die Zweige **beider** Web-Apps.

Warum beide zusammen: Die Konsole ersetzt beim Veröffentlichen die kompletten
Regeln. Wer nur den Zweig einer App einfügt, sperrt die andere aus — genau das
ist im August 2026 passiert, als die Wörterwerkstatt dazukam und ihr Zweig
fehlte. Die Datenbank wies dort jeden Zugriff ab: keine Klasse anzulegen, kein
Kind beizutreten. Alles Üben lief weiter, weil es das Netz nicht braucht.

`woerterwerkstatt/firebase-rules.json` und `klassenraum/firebase-rules.json`
sind die Einzelfassungen zum Nachschlagen; maßgeblich ist die Datei im
Wurzelverzeichnis. Was die einzelnen Regeln tun und warum in der JSON-Datei
keine Kommentare stehen dürfen, erklärt `../firebase-rules.md`.

Seit 1.0.2 sagt die App selbst Bescheid: Wer „Meine Klassen“ öffnet, während
der Zweig gesperrt ist, bekommt keinen leeren Kasten und keine Meldung, die
nach vier Sekunden verschwindet, sondern einen stehenden Hinweis mit den drei
Schritten — und der Knopf „Neue Klasse“ ist so lange ausgegraut, statt etwas
zu versprechen, das hinterher nicht geht.

Konten brauchen außerdem eine einmalige Freischaltung (Authentication →
E-Mail/Passwort). Ohne sie zeigt die App einen Hinweis; alles Üben läuft
trotzdem.

### Schulverwaltung

Ein Konto, dem die Regeln das Verzeichnis aller Lehrkräfte öffnen, bekommt in
der Kopfzeile den Knopf **🏫 Schule**: alle Lehrkräfte, alle Klassen, dazu
Klassen, zu denen es keine Lehrkraft mehr gibt. Von dort aus lässt sich

* eine Lehrkraft **anlegen** (E-Mail, Name, erstes Kennwort) — die eigene
  Anmeldung bleibt dabei stehen,
* umbenennen, ihr eine **Mail zum Zurücksetzen des Kennworts** schicken, ihr
  das Verwaltungsrecht geben oder nehmen,
* samt allen Klassen, Kindern, PINs und Protokollen **löschen**,
* und jede Klasse in der gewohnten Klassenansicht öffnen — dort werden Kinder
  angelegt, umbenannt, mit neuer PIN versehen und entfernt.

**Wer verwalten darf, entscheiden die Datenbankregeln, nicht die App.** Die App
probiert schlicht, ob sie `woerterwerkstatt/users` auflisten darf. Damit stehen
die Rechte an genau einer Stelle, und eine weitere Verwaltung braucht keine
neue Fassung der App. Wie man sie einträgt: `../firebase-rules.md`.

Eine Grenze, die keine Bequemlichkeitsfrage ist: **Ein fremdes Firebase-Konto
zu löschen oder seine E-Mail zu ändern, geht von hier aus nicht.** Das verlangt
das Admin-SDK mit einem Dienstschlüssel — und der gehört auf einen Server, nicht
in eine Web-App, die auf jedem Kindergerät liegt. Die App löscht deshalb alle
**Daten** einer Lehrkraft und führt danach in die Firebase-Konsole, wo die
Anmeldung selbst zu entfernen ist. Anlegen und Kennwort-Mail gehen dagegen
ohne Umweg.

Ein Kind umbenennen heißt: **neue PIN.** Der Name ist der Schlüssel und steckt
zugleich im Abdruck (siehe unten) — der alte passt zum neuen Namen nicht mehr,
und lesen lässt er sich nirgends. Sterne und Wortprotokoll ziehen mit um.

## Farben

Blau, Orange und Gelb — kein Grün, kein Lila (Ansage des Nutzers, 08/2026).

* **Blau ist die Arbeitsfarbe**: Knöpfe, Fokus, Zahlen, das Wortbild der
  Geheimschrift.
* **Orange und Gelb sind die Belohnungsfarben**: Sterne, Fortschrittsbalken,
  der Auftrag der Woche, Konfetti.
* Die fünf Stufen laufen von kühl nach warm mit — Blau, Hellblau, Gelb,
  Orange, Rot —, so wie sie schwerer werden. Dieselbe Ordnung tragen die
  Wortarten: Nomen blau, Verben orange, Adjektive gelb.

Zwei Dinge, die man beim Ändern wissen muss:

1. **Kein Verlauf von Blau nach Orange.** Die beiden liegen auf dem Farbkreis
   gegenüber; ein Verlauf zwischen ihnen ist auf halbem Weg schmutziggrau.
   Deshalb hat jedes Farbschema (`js/store.js`, `SCHEMATA`) seinen Verlauf
   ausgeschrieben stehen, statt ihn aus `von/mitte/bis` zu rechnen: Diese drei
   sind die weit auseinanderliegenden Farbwolken im Hintergrund, `verlauf` und
   `warm` bleiben je in einer Farbfamilie.
2. **„Richtig" ist blau, nicht grün.** Damit die Rückmeldung nicht allein an
   der Farbe hängt — was sie ohnehin nie sollte, weder für ein
   farbfehlsichtiges Kind noch auf einem ausgeblichenen Beamer —, steht vor
   jeder Antwort ein Zeichen: ✓ richtig, ↻ noch einmal, ✗ falsch.

## Eine Regel, die teuer gelernt ist

**Der Wegweiser darf nie aus einem Datenereignis heraus laufen.**

`wegLesen()` in `js/app.js` hat Nebenwirkungen: Es öffnet Blätter und stellt
Netzanfragen. In 1.0.3 hing es an der Meldung „Bereiche geändert“ — und ein
Kind, das einer Klasse beitritt, sichert genau dabei die mitgegebenen
Bereiche. Daraus wurde eine Schleife ohne Boden: gemessen **277 Netzanfragen
und 279 übereinandergestapelte Blätter in vier Sekunden**. Auf dem iPad ließ
sich nichts eintippen, weil unter dem Finger sofort das nächste Blatt lag; auf
dem Telefon starb der Tab mit „wiederholt ein Problem aufgetreten“.

Seit 1.0.4 dreifach abgesichert:

1. Ein Datenereignis darf nur die Bühne **neu zeichnen**, nie den Wegweiser
   erneut ausführen.
2. Der Wegweiser merkt sich, für welchen Klassencode ein Beitrittsblatt offen
   ist, und öffnet kein zweites.
3. `bereichSichern()` meldet nur bei **echter** Änderung — ein unveränderter
   Bereich löst gar nichts mehr aus.

## Aufbau

```
index.html          Gerüst; die drei Ebenen entstehen im JavaScript
css/app.css         Oberfläche (Glas, Schatten, sparsame Bewegung, dunkle Umgebung)
css/fonts.css       Andika, Lexend, Quicksand — alle mit einstöckigem a und g
js/app.js           Wegweiser (#/bereich/… , #/ueben/… , #/beitreten/…)
js/woerter.js       die 600 Lernwörter der Themenbereiche
js/rechtschreibung*.js  die Rechtschreibblöcke der Klassen 1 bis 4
js/grammatik.js     Wortarten und Wortformen
js/paket.js         Trainingspäckchen
js/wortbild.js      Buchstabenhaus und Wortumriss (SVG)
js/uebungen/        die fünf Stufen, plus das gemeinsame Schreibfeld
js/lauf.js          ein Durchgang: fünfzehn Wörter, ein Ergebnis
js/store.js         IndexedDB (Rückfall: localStorage)
js/cloud.js         Firebase über REST — Konten, Klassen, Anmeldung der Kinder
js/klasse.js        Klassenansicht, QR-Code, Beitreten
js/admin.js         Schulverwaltung (nur für Konten, die die Regeln zulassen)
js/bereiche.js      eigene Bereiche anlegen
js/qr.js            QR-Code, selbst gerechnet
js/plattform.js     die Brücke zur Plattform (siehe unten)
```

## Werkzeuge

```
python3 scripts/generate-icons.py      App-Icons erzeugen (reines Python)
python3 scripts/qr-pruefen.py          QR-Code gegen OpenCV und segno prüfen
python3 scripts/regeln-pruefen.py      Firebase-Regeln, bevor jemand sie einfügt
node --experimental-vm-modules scripts/module-pruefen.mjs
                                       Syntax, Importe, tote Ausfuhren
```

`module-pruefen.mjs` nach jeder Änderung am JavaScript laufen lassen. Die App
hat keinen Bauschritt — eine fehlende Klammer oder ein Import, den es nicht
gibt, fällt sonst erst auf, wenn die Seite weiß bleibt. Beides ist beim Bau
schon passiert.

`qr-pruefen.py` braucht `pip install segno opencv-python-headless numpy` — die
App selbst braucht davon nichts. Ein QR-Code, bei dem ein einziges Modul falsch
sitzt, sieht tadellos aus und wird von keiner Kamera gelesen; beim Bau dieser
Datei ist genau das zweimal passiert.

## Später einmal eine iOS-App?

Der Weg ist vorbereitet und in
[`docs/woerterwerkstatt/ios.md`](../docs/woerterwerkstatt/ios.md) beschrieben.
Kurz: Alles, was nicht reines HTML ist — Sprachausgabe, Vibration, Vollbild,
Zwischenablage, Bildschirm wach halten —, läuft über `js/plattform.js`. Das ist
die einzige Datei, die eine native Hülle bedienen muss.

## Was mit Absicht fehlt

* **Kein Zeitdruck.** Die Zeit wird gemessen, aber während der Übung nirgends
  angezeigt. Rechtschreibung lernt man nicht auf Zeit.
* **Keine Bestenliste zwischen Kindern.** Die Lehrkraft sieht die Sterne ihrer
  Klasse; die Kinder sehen ihre eigenen.
* **Keine Bestenliste der Fehler.** Das Wortprotokoll gibt es (die Lehrkraft
  braucht es), aber es taucht nirgends als Rangliste zwischen Kindern auf, und
  kein Kind sieht die Fehler eines anderen.
