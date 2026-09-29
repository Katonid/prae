#!/usr/bin/env python3
"""Zeigt, ab welchem Lehrgangsschritt welches Wort dran ist.

Nachbildung von `Zeichenvorrat.wortSchritt` (Zeichen.swift): Ein Wort ist
dran, wenn alle seine Buchstaben und alle Verbindungen darin (sch, ei, au,
ch, ie, pf, qu, ng, nk, ck, tz, äu, eu; sp/st nur am Wortanfang) im
Lehrgang schon vorkamen. Meldet außerdem Wörter mit Zeichen, für die es
keine Schreibvorlage gibt.

Aufruf:  python3 SchreibspuriOS/scripts/woerter-pruefen.py
"""
import os
import re

HIER = os.path.dirname(os.path.abspath(__file__))
QUELLE = open(os.path.join(HIER, "..", "Schreibspur", "Model", "Zeichensatz.swift"), encoding="utf-8").read()

VERBINDUNGEN3 = ["sch"]
VERBINDUNGEN2 = ["äu", "eu", "au", "ei", "ie", "ch", "pf", "qu", "ng", "nk", "ck", "tz"]
NUR_AM_ANFANG = ["sp", "st"]


def liste(name):
    block = re.search(r"static let %s: \[String\] = \[(.*?)\]" % name, QUELLE, re.S).group(1)
    return re.findall(r'"(.*?)"', block)


def einheiten(wort):
    aus, i = [], 0
    while i < len(wort):
        klein = wort.lower()
        if klein[i:i + 3] in VERBINDUNGEN3:
            aus.append(klein[i:i + 3]); i += 3
        elif klein[i:i + 2] in VERBINDUNGEN2 or (i == 0 and klein[:2] in NUR_AM_ANFANG):
            aus.append(klein[i:i + 2]); i += 2
        else:
            aus.append(wort[i]); i += 1
    return aus


def main():
    schritte = liste("lehrgangSchritte")
    schritt_von = {}
    for n, s in enumerate(schritte):
        for teil in s.split():
            schritt_von.setdefault(teil.lower(), n)
    glyphen = set(re.findall(r'\("(.)", \[', QUELLE))
    nach_schritt = {}
    for w in liste("woerter"):
        fehlt = [c for c in w if c not in glyphen]
        if fehlt:
            print(f"!! {w}: keine Vorlage für {fehlt}")
            continue
        n = max(schritt_von[e.lower()] for e in einheiten(w))
        nach_schritt.setdefault(n, []).append(w)
    for n, s in enumerate(schritte):
        print(f"{n + 1:2}. {s:8} {' '.join(nach_schritt.get(n, []))}")


if __name__ == "__main__":
    main()
