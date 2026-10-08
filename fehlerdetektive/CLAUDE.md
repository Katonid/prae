# Projekt Fehlerdetektive (Web-App, Rechtschreibübung 4. Klasse)

> Die übergreifenden Regeln (PR-Rhythmus, Bau in GitHub Actions) stehen in
> der `CLAUDE.md` im Wurzelverzeichnis und gelten hier genauso.

- Code: `fehlerdetektive/index.html` — **eine einzige Datei** (HTML, CSS, JS
  inline), kein Bauschritt, keine fremde Bibliothek, keine externe Schrift.
  Der Nutzer will sie unverändert auf einen beliebigen Webserver laden
  können — deshalb bewusst kein Service Worker, kein Manifest, keine
  Zusatzdateien. Pages liefert sie mit aus:
  https://katonid.github.io/prae/fehlerdetektive/
- Zielgerät: iPad, Safari, Hoch- und Querformat.

## Übungstext

- Steht in `TEXT` im Skript. `[[N|falsch|richtig]]` = Nomen kleingeschrieben,
  `[[S|falsch|richtig]]` = sonstiger Fehler. Buchstaben direkt hinter einer
  Markierung gehören zum selben Wort (`[[S|gelp|gelb]]es` → „gelpes").
- **Schreibweisen des Textes nie eigenmächtig ändern** (Vorgabe des Nutzers,
  10/2026). Genau 20 × N, 20 × S = 40. `pruefe()` zählt beim Laden und
  schreibt bei Abweichung einen roten `console.error`; zusätzlich wird
  geprüft, dass ein N-Fehler nur die Großschreibung betrifft.
- **Die Lösung steht nur im Skript, nie am Wort-Element** (keine Klasse,
  kein `data-`, kein `title`, kein `aria-label` vor der Auswertung). Am
  `<span>` hängt nur die laufende Nummer `data-i`.

## Mit Klasse: in der Wörterwerkstatt

Seit Wörterwerkstatt 1.9.0 gibt es dieselbe Übung MIT Ergebnisprotokoll
(Zeit, Fund, alle Versuche) in der Wörterwerkstatt — Einzelheiten in
`woerterwerkstatt/CLAUDE.md`. Der Text steht dort in `js/fehlertexte.js`
noch einmal: Wer ihn hier ändert, ändert ihn dort mit.

## Versionierung

`Fassung x.y.z` in der Fußzeile, Patch +1 bei jeder Änderung.
