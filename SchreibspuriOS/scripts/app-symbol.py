#!/usr/bin/env python3
"""Zeichnet das App-Symbol: ein kräftiges A auf einem Heftblatt.

Seit 1.0.9 kräftiger (Nutzer: „zu blass, vom A sieht man nur den ersten
Strich“): satter warmer Hintergrund, das ganze A in dunkelblauer Tinte,
der Querstrich gerade in Arbeit, grüner Start am Fuß des A (das A wird
nach dem Merkblatt hoch und ohne Absetzen wieder hinunter geschrieben).
Kein Türkis, kein Regenbogen.

Aufruf:  python3 SchreibspuriOS/scripts/app-symbol.py
Schreibt `Schreibspur/Assets.xcassets/AppIcon.appiconset/AppIcon1024.png`.
Braucht Pillow (pip install pillow).
"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter

HIER = os.path.dirname(os.path.abspath(__file__))
ZIEL = os.path.join(HIER, "..", "Schreibspur", "Assets.xcassets", "AppIcon.appiconset", "AppIcon1024.png")
G = 2048  # doppelt zeichnen, dann verkleinern — glatte Kanten

# Hintergrund: satter Verlauf von Orange (oben) zu Korallrot (unten)
bild = Image.new("RGB", (G, G))
oben_f, unten_f = (255, 165, 40), (232, 72, 72)
for yy in range(G):
    t = yy / (G - 1)
    bild.paste(tuple(int(a + (b - a) * t) for a, b in zip(oben_f, unten_f)), (0, yy, G, yy + 1))

# Heftblatt mit weichem Schatten
blatt = (190, 300, G - 190, G - 300)
schatten = Image.new("L", (G, G), 0)
ImageDraw.Draw(schatten).rounded_rectangle((blatt[0], blatt[1] + 40, blatt[2], blatt[3] + 40), 110, fill=120)
bild.paste((120, 40, 20), (0, 0), schatten.filter(ImageFilter.GaussianBlur(45)))
d = ImageDraw.Draw(bild)
d.rounded_rectangle(blatt, 110, fill=(255, 250, 238))

m, oben = 1060, 520  # Pixel je Einheit, Lage der Oberlinie
y = lambda v: oben + v * m
d.rectangle([blatt[0], y(0.45), blatt[2], y(1)], fill=(222, 240, 196))
for v, w, farbe in ((0, 12, (120, 150, 185)), (0.45, 12, (120, 150, 185)), (1, 20, (70, 100, 140))):
    d.line([(blatt[0], y(v)), (blatt[2], y(v))], fill=farbe, width=w)

x0 = G / 2 - 0.4 * m
p = lambda a, b: (x0 + a * m, y(b))
breite = int(0.13 * m)
tinte = (22, 58, 160)


def linie(punkte, farbe, w):
    d.line(punkte, fill=farbe, width=w, joint="curve")
    for q in punkte:
        d.ellipse([q[0] - w / 2, q[1] - w / 2, q[0] + w / 2, q[1] + w / 2], fill=farbe)


# Das A: hoch und ohne Absetzen wieder hinunter, dann der Querstrich.
linie([p(0.04, 1), p(0.4, 0), p(0.76, 1)], tinte, breite)
linie([p(0.2, 0.62), p(0.6, 0.62)], tinte, breite)

# Grüner Start am Fuß des A mit Pfeil nach oben rechts
cx, cy = p(0.04, 1)
r = 0.1 * m
d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(30, 160, 95), outline="white", width=18)
w = math.atan2(p(0.4, 0)[1] - cy, p(0.4, 0)[0] - cx)
spitze = (cx + math.cos(w) * r * 0.55, cy + math.sin(w) * r * 0.55)
d.line([(cx - math.cos(w) * r * 0.5, cy - math.sin(w) * r * 0.5), spitze], fill="white", width=26)
for dw in (2.5, -2.5):
    d.line([spitze, (spitze[0] + math.cos(w + dw) * r * 0.5, spitze[1] + math.sin(w + dw) * r * 0.5)],
           fill="white", width=26)

# Violettes Ziel am Ende des Abstrichs
ex, ey = p(0.76, 1)
r2 = 0.085 * m
d.ellipse([ex - r2, ey - r2, ex + r2, ey + r2], fill=(120, 80, 215), outline="white", width=16)
d.ellipse([ex - r2 * 0.4, ey - r2 * 0.4, ex + r2 * 0.4, ey + r2 * 0.4], fill="white")

bild.resize((1024, 1024), Image.LANCZOS).save(ZIEL)
print("→", ZIEL)
