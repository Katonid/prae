# Projekt Rufnummer-Detektiv (Web-App)

> Die übergreifenden Regeln (PR-Rhythmus, Bau in GitHub Actions) stehen in
> der `CLAUDE.md` im Wurzelverzeichnis und gelten hier genauso.

- Code: `rufnummer/` — statische PWA ohne Bauschritt (ES-Module, kein
  Framework, keine fremde Bibliothek). Wird vom Pages-Arbeitsablauf
  automatisch mit ausgeliefert: https://katonid.github.io/prae/rufnummer/
- Zweck: „Wem gehört diese Nummer?" — Ort/Netz ablesen, mögliche
  Firmenzentrale (Stammnummer + Durchwahl) vermuten, mit eigenem
  Nummernbuch und eingelesenen Kontakten abgleichen, Rückwärts- und
  Websuche mit einem Tipp.
- Zielgeräte: iPhone und iPad, Safari, „Zum Home-Bildschirm".

## Festlegungen des Nutzers (10/2026)

- **Nur auf dem Gerät speichern** — kein Firebase, kein Server. Alles in
  `localStorage` (`js/speicher.js`, Schlüssel dort beschrieben). Gesichert
  wird per JSON-Datei („Sichern"/„Sicherung laden" im Nummernbuch).
- **Nur deutsche Nummern** werden genau ausgewertet. Ausländische zeigen
  nur das Land und eine Websuche.

## Versionierung

Bei jeder neuen Fassung, ohne Nachfrage:
- `FASSUNG` in `sw.js` hochzählen (`v1` → `v2` …).
- `FASSUNG` in `js/app.js` (Anzeige unten und im Info-Blatt), Patch +1.
- Neue Dateien in `DATEIEN` in `sw.js` eintragen.

## Aufbau

| Datei | Inhalt |
|---|---|
| `js/nummer.js` | reine Logik: bereinigen, analysieren, Zentralen, Schreibweisen, Suchlinks, Abgleich |
| `js/vcard.js` | vCard lesen — behält NUR Name, Firma, Telefonnummern |
| `js/speicher.js` | localStorage: Nummernbuch, Kontakte, Verlauf, Thema |
| `js/app.js` | Oberfläche |
| `daten/vorwahlen.json` | Ortsnetzkennzahlen der BNetzA (ohne führende 0) |

Intern ist eine Nummer „national": nur Ziffern MIT führender 0.

`js/nummer.js` greift nicht auf die Seite zu und lässt sich mit Node
prüfen (`import('./js/nummer.js')`) — vor jeder Änderung daran die Fälle
durchspielen: `+49 (0)…`, `0049…`, Ortsnetz mit 2- bis 5-stelliger
Vorwahl, Handy, 0800/0180/0900/032, 116117, ohne Vorwahl.

## Vorwahlen

`python3 rufnummer/scripts/vorwahlen-aktualisieren.py` holt das
Vorwahlverzeichnis der Bundesnetzagentur (ZIP mit CSV, aus der Claude-
Umgebung erreichbar). Stand der Quelle 10/2026: 27.07.2022, 5200 aktive
Kennzahlen. Unter 5000 gelesenen Einträgen bleibt die Datei unverändert.
Die Kennzahlen sind präfixfrei; gesucht wird trotzdem die längste (5 → 2).

## Zentrale vermuten

Stammnummer = Teilnehmernummer ohne die letzten 1–4 Ziffern (mindestens
3 Ziffern bleiben), Zentrale = Stamm + `0`. Die Websuche nach
`"0234 910"` findet Seiten mit `0234 910-0`, `0234 910-1234` usw., weil
Suchmaschinen am Bindestrich trennen — das ist der Kern des Tricks, nicht
entfernen.

Abgleich (`abgleichen`): „Nachbarn" nur bei Ortsnetznummern, mindestens
3 gemeinsame Ziffern nach der Vorwahl, beide weichen höchstens in den
letzten 4 Ziffern ab. Gespeicherte „Anschlüsse" (bereich: true) passen
per Anfang.

## Suchlinks — Stand 10/2026

- Das Örtliche: `/rueckwaertssuche/?ph=<national>` (GET, wie das eigene
  Formular der Seite).
- Das Telefonbuch: `/Rückwärts-Suche?phone=…&stype=RBP&mode=search`.
  Das eigene Formular schickt POST; GET füllt das Feld nachweislich, ob es
  sofort sucht, ließ sich aus der Claude-Umgebung nicht prüfen (die Seiten
  liefern dorthin keine Treffer aus). Bei Beschwerden zuerst hier ansehen.
- tellows (`/num/<national>`) antwortet Skripten mit Cloudflare-Sperre —
  im Browser geht es.
- Ergebnisse der Seiten auslesen ist NICHT möglich und nicht erlaubt
  (keine Schnittstelle, CORS, Nutzungsbedingungen) — die App öffnet nur.

## Kurzbefehl

`?nr=` öffnet die App mit einer Nummer. Wird von Hand zerlegt, weil
`URLSearchParams` ein unkodiertes `+49` zu ` 49` macht. Anleitung steht im
Info-Blatt.
