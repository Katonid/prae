#!/usr/bin/env python3
"""Entscheidet, welche iOS-Apps ein Bau anfassen muss.

Gerufen vom Arbeitsablauf `.github/workflows/ios-apps-build.yml`. Schreibt
zwei Zeilen für `$GITHUB_OUTPUT`:

    matrix={"include":[{"ordner":"TafelbildiOS","app":"Tafelbild"}]}
    anzahl=1

Warum es das gibt
-----------------

Vorher horchte der Arbeitsablauf auf `**/*.swift` und baute daraufhin
**alle elf Apps**. Eine Änderung an Tafelbild ließ also Anstoß, Tagesspur,
Kartenwallet und acht weitere fertige Apps neu übersetzen — jede auf einem
eigenen macOS-Läufer. Da nur wenige macOS-Läufer gleichzeitig laufen
dürfen, warteten die Aufträge dann aufeinander: gemessen 2,7 bis 5,7
Minuten, für Bauten, die niemand angefordert hatte und deren Ergebnis
niemand ansah.

Jetzt wird gebaut, was sich geändert hat. Sonst nichts.

Was trotzdem alles baut
-----------------------

Ändert sich der Arbeitsablauf selbst, dieses Skript oder die gemeinsame
Vorprüfung, dann laufen alle Apps. Eine Änderung am Bauwerkzeug will man
überall geprüft haben — sonst fällt sie erst Wochen später bei einer App
auf, die gerade niemand anfasst.

Beim **ersten Push eines neuen Zweiges** gibt es keinen Vorgänger, gegen
den sich vergleichen ließe. Dann wird gegen den Hauptzweig verglichen —
das ist genau das, was dieser Zweig bisher geändert hat. Ohne diesen Weg
wäre der Rundumbau der Regelfall statt der Ausnahme, denn Arbeit beginnt
hier fast immer auf einem frischen Zweig.

Bleibt selbst das erfolglos (eine flache Kopie ohne Historie), wird alles
gebaut: Ein Bau zu viel ist harmlos — ein Bau zu wenig nicht.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys

# Ordner → Name des Xcode-Projekts und des Schemas. Die einzige Stelle, an
# der die Apps aufgezählt sind; der Arbeitsablauf holt sich die Auswahl
# hierher.
APPS = [
    ("AnstossiOS", "Anstoss"),
    ("CadUsdEuriOS", "CadUsdEur"),
    ("FlightMateiOS", "FlightMate"),
    ("HimmelskompassiOS", "Himmelskompass"),
    ("KartenwalletiOS", "Kartenwallet"),
    ("PhotoSpotRadariOS", "PhotoSpotRadar"),
    ("ReisekasseiOS", "Reisekasse"),
    ("SoundboardiOS", "Soundboard"),
    ("TafelbildiOS", "Tafelbild"),
    ("TagesspuriOS", "Tagesspur"),
    ("TankbuchiOS", "Tankbuch"),
]

# Ändert sich davon etwas, wird alles gebaut.
GEMEINSAM = (
    ".github/workflows/ios-apps-build.yml",
    ".github/scripts/welche-apps.py",
    "scripts/swift-quelltext-pruefen.py",
)

LEER = "0000000000000000000000000000000000000000"


def git(*args: str) -> list[str]:
    ergebnis = subprocess.run(["git", *args], capture_output=True, text=True)
    if ergebnis.returncode != 0:
        raise RuntimeError(ergebnis.stderr.strip())
    return [zeile for zeile in ergebnis.stdout.splitlines() if zeile]


def geaenderte_dateien() -> list[str] | None:
    """Welche Dateien dieser Anstoß berührt — None heißt „nicht feststellbar"."""
    ereignis = os.environ.get("EREIGNIS", "")
    sha = os.environ.get("SHA", "HEAD")

    if ereignis == "pull_request":
        basis = os.environ.get("BASIS", "")
        if not basis or basis == LEER:
            return None
        try:
            return git("diff", "--name-only", f"{basis}...{sha}")
        except RuntimeError:
            return None

    vorher = os.environ.get("VORHER", "")
    if vorher and vorher != LEER:
        try:
            return git("diff", "--name-only", vorher, sha)
        except RuntimeError:
            # Der Vorgänger liegt nicht mehr vor (Zweig neu geschrieben,
            # Historie gekürzt) — weiter unten gegen den Hauptzweig.
            pass

    # Erster Push eines neuen Zweiges: Es gibt keinen Vorgänger. Dann gegen
    # den Hauptzweig vergleichen — das ist genau das, was dieser Zweig
    # bisher geändert hat.
    #
    # Ohne diesen Weg baute der allererste Push eines Zweiges jedes Mal
    # alle elf Apps, und da Arbeit hier fast immer auf einem frischen Zweig
    # beginnt, wäre das der Regelfall statt der Ausnahme gewesen.
    haupt = os.environ.get("HAUPTZWEIG", "main")
    for verweis in (f"origin/{haupt}", haupt):
        try:
            basis = git("merge-base", verweis, sha)[0]
        except (RuntimeError, IndexError):
            continue
        if basis == sha:
            # Der Zweig ist noch nicht weiter als der Hauptzweig.
            return []
        try:
            return git("diff", "--name-only", basis, sha)
        except RuntimeError:
            continue
    return None


def auswahl() -> tuple[list[dict[str, str]], str]:
    """Die zu bauenden Apps und ein Satz, warum."""
    wunsch = os.environ.get("WUNSCH", "").strip()
    if wunsch and wunsch != "alle":
        treffer = [{"ordner": o, "app": a} for o, a in APPS if a == wunsch]
        if treffer:
            return treffer, f"Von Hand angefordert: {wunsch}."
        return [], f"Unbekannte App „{wunsch}“ — nichts zu bauen."
    if wunsch == "alle":
        return [{"ordner": o, "app": a} for o, a in APPS], "Von Hand angefordert: alle."

    dateien = geaenderte_dateien()
    if dateien is None:
        return ([{"ordner": o, "app": a} for o, a in APPS],
                "Die geänderten Dateien ließen sich nicht feststellen — "
                "sicherheitshalber alle.")

    if any(datei in GEMEINSAM for datei in dateien):
        return ([{"ordner": o, "app": a} for o, a in APPS],
                "Etwas Gemeinsames hat sich geändert — alle.")

    getroffen = [
        {"ordner": ordner, "app": app}
        for ordner, app in APPS
        if any(datei.startswith(ordner + "/") for datei in dateien)
    ]
    if not getroffen:
        return [], "Keine App-Ordner berührt — nichts zu bauen."
    namen = ", ".join(eintrag["app"] for eintrag in getroffen)
    return getroffen, f"Geändert: {namen}."


def main() -> None:
    gewaehlt, grund = auswahl()
    # Auf stderr, damit es im Protokoll steht, ohne die Ausgabe zu stören.
    print(grund, file=sys.stderr)
    print(f"matrix={json.dumps({'include': gewaehlt}, separators=(',', ':'))}")
    print(f"anzahl={len(gewaehlt)}")
    print(f"grund={grund}")


if __name__ == "__main__":
    main()
