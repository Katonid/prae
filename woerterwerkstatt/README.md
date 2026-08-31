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

## Zwanzig mitgelieferte Bereiche

600 Wörter in `js/woerter.js`, je 30 pro Bereich (= zwei Päckchen), ausgewählt
nach den typischen Rechtschreibstellen der Grundschule: Doppelkonsonant, ie,
Dehnungs-h, ck/tz, äu/eu, v/f und die Umlautbildung in der Mehrzahl.

Format je Wort — ein Textstück mit senkrechten Strichen:

```
Ranzen|n|der|Ranzen               Nomen:    Wort | n | Artikel | Mehrzahl („-“ = keine)
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

## Aufbau

```
index.html          Gerüst; die drei Ebenen entstehen im JavaScript
css/app.css         Oberfläche (Glas, Schatten, sparsame Bewegung, dunkle Umgebung)
css/fonts.css       Andika, Lexend, Quicksand — alle mit einstöckigem a und g
js/app.js           Wegweiser (#/bereich/… , #/ueben/… , #/beitreten/…)
js/woerter.js       die 600 Lernwörter
js/grammatik.js     Wortarten und Wortformen
js/paket.js         Trainingspäckchen
js/wortbild.js      Buchstabenhaus und Wortumriss (SVG)
js/uebungen/        die fünf Stufen, plus das gemeinsame Schreibfeld
js/lauf.js          ein Durchgang: fünfzehn Wörter, ein Ergebnis
js/store.js         IndexedDB (Rückfall: localStorage)
js/cloud.js         Firebase über REST — Konten, Klassen, Anmeldung der Kinder
js/klasse.js        Klassenansicht, QR-Code, Beitreten
js/bereiche.js      eigene Bereiche anlegen
js/qr.js            QR-Code, selbst gerechnet
js/plattform.js     die Brücke zur Plattform (siehe unten)
```

## Werkzeuge

```
python3 scripts/generate-icons.py    App-Icons erzeugen (reines Python)
python3 scripts/qr-pruefen.py        QR-Code gegen OpenCV und segno prüfen
```

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
* **Kein Protokoll der Tippfehler.** Was ein Kind falsch geschrieben hat, steht
  auf seinem Gerät und geht sonst niemanden etwas an — hochgeladen werden nur
  die Sterne.
