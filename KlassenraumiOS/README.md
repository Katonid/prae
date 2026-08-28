# Klassenraum — Versuchsfassung

**Das ist nicht die App für den App Store.** Die veröffentlichte App heißt
**Tafelbild** und liegt in `TafelbildiOS/`. Dieser Ordner ist eine Kopie
davon, angelegt am Stand 1.0.57, mit einem einzigen Zweck:

> **Den Abgleich von der öffentlichen auf die private iCloud-Datenbank
> umbauen (Weg A), ohne die laufende App anzufassen.**

Beide Apps lassen sich gleichzeitig auf einem Gerät installieren. Auf dem
Homescreen heißt diese hier **Klassenraum**.

## Was anders ist

| | Tafelbild | Klassenraum |
|---|---|---|
| Bundle-ID | `de.familie.tafelbild` | `de.familie.klassenraum` |
| Anzeigename | Tafelbild | Klassenraum |
| Version | 1.0.x | 0.1.x |
| Vertrieb | App Store + TestFlight | **nur TestFlight, interne Tester** |
| iCloud-Bereich | `iCloud.de.familie.tafelbild` | **derselbe** |

Der iCloud-Bereich ist mit Absicht derselbe. Weg A schreibt ausschließlich in
die **private** Datenbank, die veröffentlichte App ausschließlich in die
**öffentliche** — sie kommen sich nicht in die Quere. Dafür kann die
Versuchsfassung den vorhandenen Bestand aus dem öffentlichen Bereich lesen und
den Umzug an echten Tafeln üben. Mit einem frischen Bereich stünde man vor
einer leeren Tafelliste.

## Regeln für die Arbeit hier

1. **Niemals zur Prüfung einreichen.** Zwei fast gleiche Apps desselben
   Entwicklers gelten nach Apples Regel 4.3 als Dublette und werden
   abgelehnt. Diese Fassung lebt nur in TestFlight bei internen Testern;
   dafür findet keine Prüfung statt.
2. **Hier passiert nur der Abgleichs-Umbau.** Alle sonstigen Verbesserungen
   gehen weiter allein nach `TafelbildiOS/`. Diese Kopie bleibt bei den
   Funktionen bewusst zurück — sonst müsste jede Änderung doppelt gemacht
   werden, und die beiden Fassungen laufen auseinander.
3. **Steht der Umbau, wandert nur die Abgleichsschicht zurück** nach
   `TafelbildiOS/`. Danach wird dieser Ordner gelöscht.

## Nicht verwechseln

`klassenraum/` (kleingeschrieben, im Wurzelverzeichnis) ist die **Web-App**
gleichen Namens. Sie hat mit diesem Ordner nichts zu tun.
