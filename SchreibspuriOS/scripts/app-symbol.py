#!/usr/bin/env python3
"""Zeichnet das App-Symbol: ein A auf dem Linienblatt, halb nachgespurt.

Aufruf:  python3 SchreibspuriOS/scripts/app-symbol.py
Schreibt `Schreibspur/Assets.xcassets/AppIcon.appiconset/AppIcon1024.png`.
Braucht Pillow (pip install pillow).
"""
import colorsys
import math
import os

from PIL import Image, ImageDraw

HIER = os.path.dirname(os.path.abspath(__file__))
ZIEL = os.path.join(HIER, "..", "Schreibspur", "Assets.xcassets", "AppIcon.appiconset", "AppIcon1024.png")
G = 2048  # doppelt zeichnen, dann verkleinern — glatte Kanten

bild = Image.new("RGB", (G, G), (0, 181, 212))
d = ImageDraw.Draw(bild)

# Linienblatt: Oberlinie, Mittellinie, Grundlinie
m, oben = 1300, 380  # Pixel je Einheit, Lage der Oberlinie
y = lambda v: oben + v * m
d.rectangle([0, y(0.5), G, y(1)], fill=(26, 191, 219))
for v, w in ((0, 8), (0.5, 8), (1, 12)):
    d.line([(0, y(v)), (G, y(v))], fill=(200, 240, 248), width=w)

x0 = G / 2 - 0.4 * m
p = lambda a, b: (x0 + a * m, y(b))
links = [p(0.04, 1), p(0.4, 0)]
rechts = [p(0.4, 0), p(0.76, 1)]
quer = [p(0.166, 0.65), p(0.634, 0.65)]
breite = int(0.085 * m)


def linie(punkte, farbe, w):
    d.line(punkte, fill=farbe, width=w)
    for q in (punkte[0], punkte[-1]):
        d.ellipse([q[0] - w / 2, q[1] - w / 2, q[0] + w / 2, q[1] + w / 2], fill=farbe)


for s in (links, rechts, quer):
    linie(s, "white", breite)

# Erster Strich in Regenbogenfarben geschrieben
(ax, ay), (bx, by) = links
schritte = 40
for k in range(schritte):
    t0, t1 = k / schritte, (k + 1) / schritte
    r, g, b = colorsys.hsv_to_rgb((k / schritte) * 0.8, 0.75, 1)
    linie([(ax + (bx - ax) * t0, ay + (by - ay) * t0), (ax + (bx - ax) * t1, ay + (by - ay) * t1)],
          (int(r * 255), int(g * 255), int(b * 255)), int(0.1 * m))

# Roter Start am zweiten Strich mit Pfeil nach unten rechts
cx, cy = rechts[0]
r = 0.075 * m
d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(214, 31, 61), outline="white", width=14)
w = math.atan2(rechts[1][1] - cy, rechts[1][0] - cx)
spitze = (cx + math.cos(w) * r * 0.55, cy + math.sin(w) * r * 0.55)
d.line([(cx - math.cos(w) * r * 0.5, cy - math.sin(w) * r * 0.5), spitze], fill="white", width=22)
for dw in (2.5, -2.5):
    d.line([spitze, (spitze[0] + math.cos(w + dw) * r * 0.5, spitze[1] + math.sin(w + dw) * r * 0.5)],
           fill="white", width=22)

# Zielkreis
ex, ey = rechts[1]
r2 = 0.065 * m
d.ellipse([ex - r2, ey - r2, ex + r2, ey + r2], fill=(214, 31, 61), outline="white", width=12)
d.ellipse([ex - r2 * 0.42, ey - r2 * 0.42, ex + r2 * 0.42, ey + r2 * 0.42], fill="white")

bild.resize((1024, 1024), Image.LANCZOS).save(ZIEL)
print("→", ZIEL)
