# Übergabedatei Fernweh → Reisebuch (`.fernweh`)

Fernweh (FernwehiOS) schreibt sie unter Reise → „…“ → **Fürs Fotobuch übergeben**.
Das Reisebuch (`UrlaubstagebuchiOS/`) soll sie einlesen. Dieses Papier ist der
Vertrag zwischen beiden. **Wer auf einer Seite ein Feld ändert, ändert es hier
gleichzeitig.** Neue Felder werden angehängt, nie umbenannt; ein Leser
überliest, was er nicht kennt.

Erzeugt wird sie in `FernwehiOS/Fernweh/Model/Uebergabe.swift`, gelesen seit
Reisebuch 1.0.106 in `UrlaubstagebuchiOS/Urlaubstagebuch/Dienste/Fernweheinfuhr.swift`
(Seiten, Wanderungen und Bildtexte seit Reisebuch 1.0.109, das Wetter des
Tages seit 1.0.110).

## Behälter

- Ein gewöhnliches **ZIP, ungepackt (Methode 0)**, Dateinamen in UTF-8
  (Flag 0x0800). Ohne ZIP64 — über 4 GB bricht Fernweh ab, statt eine Datei zu
  schreiben, die niemand öffnet.
- Endung **`.fernweh`**. Der Inhalt ist ein ZIP; das Reisebuch liest ZIP seit
  1.0.13 selbst (`Dienste/Zipleser.swift`, Methode 0 und 8), eine eigene
  Bibliothek braucht es nicht.
- Inhalt:
  - `uebergabe.json` — die Beschreibung (immer; steht als LETZTE Datei im ZIP,
    gefunden wird sie über das zentrale Verzeichnis)
  - `fotos/<Kennung>.<jpg|heic|png>` — nur, wenn mit Fotos übergeben wurde

## Zeiten

- **Tage stehen als Text** `JJJJ-MM-TT` (`tage[].datum`, `reise.beginn`,
  `reise.ende`). Es ist genau der Tag, unter dem Fernweh den Eintrag zeigt.
  Nicht aus einem Zeitpunkt zurückrechnen — die Regel des Reisebuchs („der Tag
  kommt aus drei Zahlen“) gilt hier genauso.
- **Zeitpunkte** sind ISO 8601 mit dem Versatz der ZONE DES EINTRAGS:
  `2026-08-12T19:33:21-04:00` heißt „19:33 in Toronto“. Seit Fernweh 1.0.6
  (Format weiterhin Version 1, das Feld ist angehängt) steht die Zone je
  Eintrag als `zeitzone` (IANA-Name, z. B. `America/Toronto`) dabei, und
  `datum` des Tages sowie `uhrzeit` sind in dieser Zone gerechnet — ein
  später Eintrag aus Übersee landet nicht mehr auf dem Folgetag, nur weil
  daheim übergeben wird. **Fehlt `zeitzone`** (alter Eintrag ohne Ort), gilt
  die Zone des Geräts, das die Datei erzeugt hat — dann steht der Versatz im
  Zeitpunkt, aber nicht der Ort dahinter.
  Dazu steht, wo es passt, `uhrzeit` (`HH:mm`) als Wanduhr — das ist die
  Zahl, die im Buch stehen soll.
- Punkte der Reisespur tragen **Unix-Sekunden** (echter Augenblick).

## `uebergabe.json`

```json
{
  "format": "fernweh-uebergabe",
  "version": 1,
  "erzeugt": "2026-09-25T09:30:00+02:00",
  "app": "Fernweh 1.0.5",
  "fotos": "keine | kopie | original",
  "reise": {
    "kennung": "UUID",
    "titel": "Portugal 2027",
    "untertitel": "",
    "symbol": "🏖️",
    "farbe": "sonne",
    "beginn": "2027-08-01",
    "ende": "2027-08-14"            // fehlt, wenn offen
  },
  "tage": [
    {
      "datum": "2027-08-03",
      "eintraege": [
        {
          "kennung": "UUID",
          "zeitpunkt": "2027-08-03T21:14:00+01:00",
          "uhrzeit": "21:14",
          "zeitzone": "Europe/Lisbon",
          "tagebuch": "Nadine",            // ab Fernweh 1.0.7, fehlt wenn keins
          "titel": "Lissabon",
          "text": "Fließtext, Absätze mit \n",
          "autor": "Name aus den Einstellungen",
          "ort": { "name": "Lissabon", "land": "Portugal", "breite": 38.72, "laenge": -9.14 },
          "orte": [ { "name": "Belém", "breite": 38.69, "laenge": -9.2, "uhrzeit": "10:40" } ],
          "wetter": {
            "vorhersage": false,
            "geholt": "2027-08-04T08:00:00+01:00",
            "abschnitte": [
              { "name": "Vormittag", "stunden": "6–11", "code": 1,
                "beschreibung": "Überwiegend klar", "tiefst": 19.2, "hoechst": 24.8, "regen": 0.0 }
            ]
          },
          "fotos": [
            { "kennung": "UUID", "datei": "fotos/UUID.heic", "aufnahme": "2027-08-03T11:02:10+01:00",
              "breite": 38.69, "laenge": -9.2, "pixelBreite": 4032, "pixelHoehe": 3024,
              "reihenfolge": 0, "mediathek": "lokale PHAsset-Kennung", "icloud": "PHCloudIdentifier",
              "text": "Blick vom Castelo" }        // ab Fernweh 1.0.17, fehlt wenn keiner
          ],
          "art": "wanderung",                     // ab Fernweh 1.0.17: "seite" | "wanderung", fehlt beim gewöhnlichen Eintrag
          "wanderung": {                          // ab Fernweh 1.0.17, nur bei art "wanderung"
            "sportart": "hike", "sportname": "Wanderung",
            "quelle": "https://www.komoot.com/tour/1234567890",   // fehlt bei einer GPX-Datei
            "beginn": "2027-08-03T09:12:00+01:00", "ende": "2027-08-03T15:40:00+01:00",
            "uhrzeitVon": "09:12", "uhrzeitBis": "15:40",
            "meter": 14210.0, "hoehenmeter": 620.0, "dauer": 23280.0,
            "punkte": [[38.7, -9.1, 1880000000.0]]
          }
        }
      ],
      "spuren": [
        { "geraet": "Kennung", "reisender": "Name",
          "punkte": [[38.7, -9.1, 1880000000.0]],
          "besuche": [ { "breite": 38.7, "laenge": -9.1,
                         "ankunft": "2027-08-03T10:00:00+01:00", "abfahrt": "2027-08-03T12:30:00+01:00" } ] }
      ]
    }
  ]
}
```

### Einzelheiten, die eine Leserin wissen muss

- **`reise.symbol`** ist ein Emoji ODER ein Apple-Symbol in der Form
  `sf:<Name>` (z. B. `sf:mountain.2.fill`). Ein Leser, der Symbole nicht
  zeigen kann, lässt es weg — nie `sf:…` als Text drucken.
- **Nur Einträge der Reise.** Private Einträge aus dem Lebenstagebuch (ohne
  Reise, auch wenn sie in den Zeitraum fallen) gehen nicht mit.
- **Mehrere Einträge je Tag** sind der Normalfall (mehrere Miturlauber, oder
  morgens und abends geschrieben). Zeitlich geordnet. Im Buch werden die Texte
  eines Tages aneinandergehängt; wie, entscheidet das Reisebuch.
- **`titel`** kann leer sein — dann ist `ort.name` die naheliegende
  Überschrift (so zeigt Fernweh es auch an).
- **`wetter`** fehlt, wenn der Eintrag keinen Ort hatte. `vorhersage: true`
  heißt: nachgeschlagen, als der Tag noch nicht vorbei war — also keine
  Messung. `code` ist ein WMO-Wettercode (Open-Meteo); `beschreibung` ist
  Fernwehs deutscher Wortlaut dazu. Die Abschnitte sind Ortszeit am Ort des
  Eintrags: Vormittag 6–11, Tagsüber 11–14, Nachmittag 14–18, Nacht 21–5.
  Temperaturen in °C, `regen` in mm.
- **Fotos:**
  - `fotos: "keine"` — kein Bild im ZIP; `datei` fehlt bei jedem Foto, die
    übrigen Angaben stehen trotzdem da.
  - `"kopie"` — höchstens 2048 Bildpunkte an der langen Kante, JPEG ohne
    EXIF. Datum und Ort stehen dann NUR in der JSON (`aufnahme`, `breite`,
    `laenge`).
  - `"original"` — die Aufnahme aus der Mediathek, samt EXIF, oft HEIC. Liegt
    ein Foto nur bei einem Miturlauber, geht die verkleinerte Kopie mit.
  - `fehlt` (Text) statt `datei`: Das Bild war auf dem Gerät nicht zu holen.
    Nicht still übergehen — zählen und sagen.
  - `aufnahme` ist der Zeitpunkt aus der Mediathek. **Für den Tag gilt der
    Tag des EINTRAGS**, nicht der der Aufnahme: Wer ein Foto einem Eintrag
    zugeordnet hat, hat damit entschieden, wohin es gehört.
  - `mediathek` gilt nur auf dem Gerät, das die Datei geschrieben hat;
    `icloud` (PHCloudIdentifier) lässt sich auf jedem Gerät derselben Apple-ID
    zurück auf ein Foto abbilden
    (`PHPhotoLibrary.localIdentifierMappings(for:)`).
- **`spuren`** fehlt, wenn ohne Reisespur übergeben wurde. Eine Spur je Gerät
  und Tag; zwei Miturlauber auf demselben Weg sind zwei Spuren. Die Punkte
  sind schon ausgedünnt (15 m).
- Ein Tag kann **nur eine Spur und keine Einträge** haben (gefahren, nichts
  geschrieben).

### Seiten, Wanderungen, Bildtexte (ab Fernweh 1.0.17)

Alle drei sind ANGEHÄNGT; die Fassungsnummer bleibt 1. Ein Leser, der sie
nicht kennt, bekommt weiterhin Gültiges: eine Seite und eine Wanderung als
gewöhnlichen Eintrag mit Titel und Text, die Strecke als Spur (siehe unten).

- **`art: "seite"`** — eine FREIE Seite: Überschrift (`titel`), Text, Fotos.
  Sie hat keine Uhrzeit im Sinn — `zeitpunkt`/`uhrzeit` stehen trotzdem da,
  aber nur für die Reihenfolge am Tag (eine Einleitung steht morgens vor
  allem anderen). Nicht als Uhrzeit ins Buch drucken. Kein Wetter, meist kein
  Ort.
- **`art: "wanderung"`** — eine Tour aus Komoot oder einer GPX-Datei.
  `titel` ist ihr Name, `zeitpunkt` ihr Start, `ort` ihr Startpunkt.
  `wanderung` trägt die Zahlen und die Strecke MIT Uhrzeit je Punkt
  (Unix-Sekunden, echte Augenblicke; bei einer geplanten Tour geschätzt mit
  4 km/h). `uhrzeitVon`/`uhrzeitBis` sind Wanduhr in der Zone des Eintrags —
  das ist, was ins Buch gehört („09:12–15:40“). `hoehenmeter` ist der Anstieg,
  `dauer` Sekunden von Start bis Ziel.
- **Die Strecke steht ZUSÄTZLICH in `spuren` des Tages**, mit `geraet`
  `"wanderung:<Kennung des Eintrags>"` und `reisender` = Name der Tour (nur,
  wenn mit Reisespur übergeben wurde). So zeigt auch ein Leser, der
  `wanderung` nicht kennt, die Strecke. Wer beide kennt, erkennt die Doppelung
  am Präfix `wanderung:`.
- **`fotos[].text`** — der Text zum Foto, gedacht als Bildunterschrift.

### Wetter des Tages (ab Fernweh 1.0.18)

- **`tage[].wetter`** (Aufbau wie `eintraege[].wetter`) und **`tage[].wetterOrt`**
  (`name`, `breite`, `laenge`): das Wetter DES TAGES am Ort. Genommen wird
  das des ersten Eintrags mit Wetter; an einem Tag nur mit Spur holt Fernweh
  es beim Übergeben am Anfang der Spur. Fehlt, wenn es sich nicht holen ließ.
  Ein Leser, der beides kennt, nimmt das des Eintrags und `tage[].wetter` nur,
  wo kein Eintrag eines trägt.
- **Die Abschnitte heißen seit Fernweh 1.0.18 „Morgens" (6–11), „Mittags"
  (11–14), „Nachmittags" (14–18), „Nachts" (21–5)** — dieselben Stunden wie
  vorher unter „Vormittag, Tagsüber, Nachmittag, Nacht". Ältere Dateien tragen
  die alten Namen; `stunden` steht in beiden Fällen dabei. `name` ist zum
  Drucken gedacht, nicht zum Vergleichen.

### Autofahrten und Kartenfarben (ab Fernweh 1.0.21)

Beides ANGEHÄNGT; die Fassungsnummer bleibt 1. Gelesen seit Reisebuch 1.0.114.

- **Autofahrten** stehen als Spur des Tages in `spuren` (nur, wenn mit
  Reisespur übergeben wurde), mit
  - `geraet` = `"fahrt:<Start in Unix-Sekunden>|<Zeitzone>|<Name>"` — der
    Präfix `fahrt:` erkennt sie auch ohne `art`;
  - `art: "fahrt"` und `name` = Name der Fahrt (Titel der GPX-Datei, sonst
    ihr Dateiname);
  - `reisender` = wer sie eingelesen hat; `besuche` leer; Punkte auf 20 m
    gedünnt, mit Uhrzeit.

  Der Tag ist der Tag des STARTS in Ortszeit. Eine Fahrt ist keine
  Aufzeichnung eines Geräts: Neben der längsten Gerätespur des Tages gehören
  ALLE Fahrten und Wanderungen des Tages auf die Karte. Ein älterer Leser,
  der nur die längste Spur je Tag nimmt, zeigt sie als gewöhnliche Spur.
- Wanderspuren (`geraet` `wanderung:…`) tragen seit 1.0.21 ebenfalls
  `art: "wanderung"` und `name`.
- **`karte.farben`** — die Farben der Linien, wie sie in Fernweh eingestellt
  sind, als `"#RRGGBB"`:
  ```json
  "karte": { "farben": { "reisespur": "#D9480F", "wanderung": "#2E9E5B", "fahrt": "#5A6475" } }
  ```
  `reisespur` fehlt, solange in Fernweh keine eigene Farbe gewählt ist — dann
  bleibt es bei der Akzentfarbe des Buchs. `wanderung` und `fahrt` stehen
  immer da (die Vorgabe, wenn nichts gewählt ist).
