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

## Übungen

- **Zwei Übungen** (ab 1.0.1): Startseite mit „Übung 1 / Übung 2", Weg in
  der Adresse (`#uebung1`, `#uebung2`) — so führt auch die Zurück-Geste in
  Safari zur Auswahl. „‹ Zur Auswahl" geht per `history.back()` nur, wenn
  das Kind über die Auswahl kam; bei einem Direktlink verließe das die
  Seite.
- **Übung 1 bleibt unverändert** (Vorgabe des Nutzers, 10/2026): Text
  (`TEXT1`), Anleitung und Auswertung wie in 1.0.0. Jede Übung trägt ihre
  eigene Anleitung (`kopf`) in `UEBUNGEN`; eine neue Übung wird dort
  angehängt.
- **Entschieden wird nach Position, nie nach Buchstabenfolge**: „Zettel" ist
  in Übung 2 dreimal richtig und einmal („zettel") ein Fehler. Die Lösung
  hängt an der laufenden Nummer des Wortes.
- In Übung 2 steht „des [[N|hausmeisters|Hausmeisters]]" — die Fehlerliste
  des Nutzers nannte „hausmeister → Hausmeister", maßgeblich ist der Text.
- **Lösung in Stufen** (ab 1.0.2, wie Wörterwerkstatt 1.9.2): jedes Prüfen
  eine Stufe weiter — 1 Anzahl der fehlenden (grün/rot sichtbar), 2 davon
  Nomen/andere, 3 Bänder über die Zeilen mit fehlenden Fehlern (bei
  Größenänderung neu), 4 Lösung in Orange. Alles richtig → sofort Schluss.

## Übungstext

- Stehen in `TEXT1`/`TEXT2` im Skript. `[[N|falsch|richtig]]` = Nomen kleingeschrieben,
  `[[S|falsch|richtig]]` = sonstiger Fehler. Buchstaben direkt hinter einer
  Markierung gehören zum selben Wort (`[[S|gelp|gelb]]es` → „gelpes").
- **Schreibweisen der Texte nie eigenmächtig ändern** (Vorgabe des Nutzers,
  10/2026). Je Übung genau 20 × N, 20 × S = 40. `pruefe()` zählt beim Laden
  der Seite ALLE Übungen und
  schreibt bei Abweichung einen roten `console.error`; zusätzlich wird
  geprüft, dass ein N-Fehler nur die Großschreibung betrifft.
- **Die Lösung steht nur im Skript, nie am Wort-Element** (keine Klasse,
  kein `data-`, kein `title`, kein `aria-label` vor der Auswertung). Am
  `<span>` hängt nur die laufende Nummer `data-i`.

## Mit Klasse: in der Wörterwerkstatt

Seit Wörterwerkstatt 1.9.0 gibt es dieselbe Übung MIT Ergebnisprotokoll
(Zeit, Fund, alle Versuche) in der Wörterwerkstatt — Einzelheiten in
`woerterwerkstatt/CLAUDE.md`. Beide Texte stehen dort in `js/fehlertexte.js`
noch einmal: Wer einen hier ändert, ändert ihn dort mit.

## Versionierung

`Fassung x.y.z` in der Fußzeile, Patch +1 bei jeder Änderung.
