#!/usr/bin/env python3
"""Prüft Swift-Dateien auf unausgeglichene Anführungszeichen.

Hintergrund: Deutsche Anführungszeichen werden gern als „Text" geschrieben —
das schließende Zeichen ist dann ein gerades ", das ein Swift-String-Literal
vorzeitig beendet. Der Compiler meldet daraufhin „unterminated string literal".
Diese Prüfung findet das in Sekunden, ohne Xcode.

Aufruf:  python3 scripts/swift-quelltext-pruefen.py [Ordner ...]
"""
import re
import sys
import glob
import os

MEHRZEILIG = '"""'
STRING = re.compile(r'(?<!\\)"')


def pruefe_datei(pfad):
    fehler = []
    in_mehrzeiler = False
    for nummer, zeile in enumerate(open(pfad, encoding='utf-8').read().split('\n'), 1):
        gestutzt = zeile.strip()
        if gestutzt.count(MEHRZEILIG) == 1:
            in_mehrzeiler = not in_mehrzeiler
            continue
        if in_mehrzeiler or gestutzt.startswith('//'):
            continue
        ohne_escapes = zeile.replace('\\"', '')
        if len(STRING.findall(ohne_escapes)) % 2 == 1:
            fehler.append((nummer, gestutzt[:120]))
    return fehler


def main():
    ordner = sys.argv[1:] or ['.']
    dateien = []
    for eintrag in ordner:
        if os.path.isfile(eintrag):
            dateien.append(eintrag)
        else:
            dateien += glob.glob(os.path.join(eintrag, '**', '*.swift'), recursive=True)

    alle = []
    for datei in sorted(set(dateien)):
        for nummer, text in pruefe_datei(datei):
            alle.append(f"{datei}:{nummer}: ungerade Anzahl Anführungszeichen -> {text}")

    if alle:
        print("Gefundene Probleme:")
        for zeile in alle:
            print("  " + zeile)
        print(f"\n{len(alle)} Zeile(n) prüfen — meist ein gerades \" innerhalb eines Textes;")
        print("in deutschen Texten gehört dorthin das schließende Zeichen “.")
        return 1

    print(f"{len(set(dateien))} Swift-Dateien geprüft — alle String-Literale sauber geschlossen.")
    return 0


if __name__ == '__main__':
    sys.exit(main())
