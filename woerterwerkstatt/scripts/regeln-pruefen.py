#!/usr/bin/env python3
"""Prüft die Firebase-Regeldateien, bevor sie jemand in die Konsole einfügt.

Der Regel-Editor der Firebase-Konsole ist streng: Er kennt oben nur `rules`,
als Regelarten nur `.read`, `.write`, `.validate` und `.indexOn`, und als deren
Werte nur `true`/`false`/Text. Ein erklärender Schlüssel oder ein Array lässt
das Einfügen mit einem Syntaxfehler scheitern — und wer die Regeln nicht
einfügen kann, für den ist die App kaputt. Genau das ist schon passiert.

Zusätzlich wird geprüft, dass die Einzelfassung in `woerterwerkstatt/` Zeichen
für Zeichen dem Zweig in der Gesamtdatei entspricht. Die Konsole ersetzt beim
Veröffentlichen IMMER die kompletten Regeln; die Gesamtdatei ist deshalb die
maßgebliche, die Einzelfassungen sind nur zum Nachschlagen.

    python3 woerterwerkstatt/scripts/regeln-pruefen.py
"""

import json
import sys
from pathlib import Path

WURZEL = Path(__file__).resolve().parents[2]
GESAMT = WURZEL / 'firebase-rules.json'
EINZELN = {
    'woerterwerkstatt': WURZEL / 'woerterwerkstatt' / 'firebase-rules.json',
    'klassenraum': WURZEL / 'klassenraum' / 'firebase-rules.json',
}

ERLAUBTE_REGELN = {'.read', '.write', '.validate', '.indexOn'}


def knoten_pruefen(knoten, pfad, klagen):
    if not isinstance(knoten, dict):
        klagen.append(f'{pfad}: {type(knoten).__name__} statt Objekt')
        return
    for name, wert in knoten.items():
        stelle = f'{pfad}/{name}'
        if name.startswith('.'):
            if name not in ERLAUBTE_REGELN:
                klagen.append(f'{stelle}: unbekannte Regelart — der Editor lehnt sie ab')
            elif not isinstance(wert, (bool, str)):
                klagen.append(f'{stelle}: {type(wert).__name__} statt true/false/Text')
        else:
            knoten_pruefen(wert, stelle, klagen)


def datei_pruefen(pfad, klagen):
    try:
        daten = json.loads(pfad.read_text())
    except json.JSONDecodeError as problem:
        klagen.append(f'{pfad.name}: kein gültiges JSON — {problem}')
        return None
    if list(daten) != ['rules']:
        klagen.append(f'{pfad.name}: oben steht {list(daten)} statt nur "rules"')
        return None
    knoten_pruefen(daten['rules'], pfad.name, klagen)
    return daten['rules']


def main():
    klagen = []
    gesamt = datei_pruefen(GESAMT, klagen)

    for zweig, pfad in EINZELN.items():
        einzeln = datei_pruefen(pfad, klagen)
        if gesamt is None or einzeln is None:
            continue
        if zweig not in gesamt:
            klagen.append(f'{GESAMT.name}: der Zweig "{zweig}" fehlt — die andere App wäre ausgesperrt')
        elif einzeln.get(zweig) != gesamt.get(zweig):
            klagen.append(f'{pfad}: weicht vom Zweig "{zweig}" in {GESAMT.name} ab')

    if klagen:
        print('Probleme:')
        for klage in klagen:
            print('  ·', klage)
        return 1

    zweige = ', '.join(gesamt)
    print(f'{GESAMT.name}: in Ordnung — Zweige: {zweige}')
    for pfad in EINZELN.values():
        print(f'{pfad.relative_to(WURZEL)}: deckungsgleich')
    return 0


if __name__ == '__main__':
    sys.exit(main())
