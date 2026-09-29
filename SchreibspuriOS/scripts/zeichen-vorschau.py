#!/usr/bin/env python3
"""Zeichnet alle Schriftzeichen aus `Zeichensatz.swift` in ein Bild.

Jeder Strich bekommt eine eigene Farbe, eine Nummer am Anfang und kleine
Pfeile in Schreibrichtung. So fällt auf, wenn ein Bogen andersherum läuft
oder ein Strich an der falschen Stelle beginnt — Fehler, die der Compiler
nie meldet.

Aufruf:  python3 SchreibspuriOS/scripts/zeichen-vorschau.py [ausgabe.png]
Braucht Pillow (pip install pillow).
"""
import math
import os
import re
import sys

from PIL import Image, ImageDraw

HIER = os.path.dirname(os.path.abspath(__file__))
QUELLE = os.path.join(HIER, "..", "Schreibspur", "Model", "Zeichensatz.swift")
FARBEN = [(220, 30, 60), (30, 110, 220), (20, 160, 80), (200, 120, 0), (140, 60, 200)]


def abtasten(weg):
    """Gleiche Logik wie `Weg.abtasten` in Swift — nur zur Anschauung."""
    t = weg.split()
    i = 0
    punkte = []
    zahl = lambda k: float(t[i + k])
    while i < len(t):
        befehl = t[i]
        if befehl in ("M", "P"):
            punkte.append((zahl(1), zahl(2)))
            i += 3
        elif befehl == "L":
            punkte.append((zahl(1), zahl(2)))
            i += 3
        elif befehl == "A":
            cx, cy, rx, ry, a0, a1 = (zahl(k) for k in range(1, 7))
            n = max(8, int(abs(a1 - a0) / 5))
            for k in range(n + 1):
                a = math.radians(a0 + (a1 - a0) * k / n)
                punkte.append((cx + rx * math.cos(a), cy + ry * math.sin(a)))
            i += 7
        elif befehl == "Q":
            x0, y0 = punkte[-1]
            x1, y1, x, y = (zahl(k) for k in range(1, 5))
            for k in range(1, 17):
                u = k / 16
                punkte.append(((1 - u) ** 2 * x0 + 2 * (1 - u) * u * x1 + u * u * x,
                               (1 - u) ** 2 * y0 + 2 * (1 - u) * u * y1 + u * u * y))
            i += 5
        elif befehl == "C":
            x0, y0 = punkte[-1]
            x1, y1, x2, y2, x, y = (zahl(k) for k in range(1, 7))
            for k in range(1, 25):
                u = k / 24
                a, b, c, d = (1 - u) ** 3, 3 * (1 - u) ** 2 * u, 3 * (1 - u) * u * u, u ** 3
                punkte.append((a * x0 + b * x1 + c * x2 + d * x,
                               a * y0 + b * y1 + c * y2 + d * y))
            i += 7
        else:
            raise ValueError(f"Unbekannter Befehl {befehl!r} in {weg!r}")
    return punkte


def lesen():
    text = open(QUELLE, encoding="utf-8").read()
    eintraege = re.findall(r'\("(.+?)",\s*\[(.*?)\]\)', text)
    return [(z, re.findall(r'"(.*?)"', inhalt)) for z, inhalt in eintraege]


def main():
    ziel = sys.argv[1] if len(sys.argv) > 1 else "zeichen-vorschau.png"
    zeichen = lesen()
    zelle, spalten = 200, 10
    zeilen = math.ceil(len(zeichen) / spalten)
    bild = Image.new("RGB", (zelle * spalten, zelle * zeilen), "white")
    d = ImageDraw.Draw(bild)
    s = 100  # Pixel je Einheit
    for n, (name, wege) in enumerate(zeichen):
        ox = (n % spalten) * zelle + 45
        oy = (n // spalten) * zelle + 30
        for y in (0, 0.5, 1, 1.5):
            d.line([(ox - 40, oy + y * s), (ox + 150, oy + y * s)], fill=(200, 220, 230))
        d.text((ox - 40, oy - 28), name, fill="black")
        p = lambda q: (ox + q[0] * s, oy + q[1] * s)
        for k, weg in enumerate(wege):
            farbe = FARBEN[k % len(FARBEN)]
            pkt = abtasten(weg)
            if len(pkt) == 1:
                x, y = p(pkt[0])
                d.ellipse([x - 5, y - 5, x + 5, y + 5], fill=farbe)
                continue
            d.line([p(q) for q in pkt], fill=farbe, width=4)
            x, y = p(pkt[0])
            d.ellipse([x - 7, y - 7, x + 7, y + 7], outline=farbe, width=2)
            d.text((x + 8, y - 6), str(k + 1), fill=farbe)
            # Richtungspfeile etwa alle 0,3 Einheiten
            laenge = 0
            naechste = 0.15
            for a, b in zip(pkt, pkt[1:]):
                laenge += math.dist(a, b)
                if laenge >= naechste:
                    naechste += 0.3
                    w = math.atan2(b[1] - a[1], b[0] - a[0])
                    bx, by = p(b)
                    for dw in (2.6, -2.6):
                        d.line([(bx, by), (bx + 9 * math.cos(w + dw), by + 9 * math.sin(w + dw))],
                               fill=farbe, width=2)
    bild.save(ziel)
    print(f"{len(zeichen)} Zeichen → {ziel}")


if __name__ == "__main__":
    main()
