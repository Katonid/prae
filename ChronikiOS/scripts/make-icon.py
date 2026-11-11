#!/usr/bin/env python3
"""Erzeugt das App-Symbol für Chronik (braucht Pillow: pip install pillow).

Was es zeigt: ein Buch von vorn mit einem Bild auf dem Deckel und darunter
eine Zeitleiste aus drei Punkten — Fotobuch und Kapitel nach der Zeit.

Regel aus dem Reisebuch: Auf dem Homescreen misst ein Symbol rund vierzig
Bildpunkte und trägt dort eine FARBE und eine FORM. Deshalb füllt das Buch
die halbe Fläche, und es gibt keine feinen Linien. Prüfen: Ergebnis auf
40 px verkleinern und ansehen (`--probe`).
"""
import sys
from PIL import Image, ImageDraw

N = 1024
S = 4  # Überabtastung für glatte Kanten


def gradient(w, h, oben, unten):
    bild = Image.new("RGB", (w, h))
    px = bild.load()
    for y in range(h):
        t = y / (h - 1)
        farbe = tuple(int(oben[i] + (unten[i] - oben[i]) * t) for i in range(3))
        for x in range(w):
            px[x, y] = farbe
    return bild


def main():
    g = N * S
    bild = gradient(g, g, (214, 128, 78), (150, 72, 44))
    d = ImageDraw.Draw(bild)

    def r(x0, y0, x1, y1):
        return [int(x0 * g), int(y0 * g), int(x1 * g), int(y1 * g)]

    # Seitenschnitt hinter dem Deckel
    d.rounded_rectangle(r(0.25, 0.20, 0.79, 0.84), radius=int(0.04 * g), fill=(236, 226, 210))
    # Deckel
    d.rounded_rectangle(r(0.21, 0.17, 0.75, 0.81), radius=int(0.045 * g), fill=(255, 251, 245))
    # Bild auf dem Deckel: Himmel und Hügel
    d.rounded_rectangle(r(0.27, 0.24, 0.69, 0.55), radius=int(0.02 * g), fill=(122, 178, 214))
    d.polygon([(int(0.27 * g), int(0.55 * g)), (int(0.40 * g), int(0.40 * g)), (int(0.50 * g), int(0.49 * g)),
               (int(0.58 * g), int(0.42 * g)), (int(0.69 * g), int(0.53 * g)), (int(0.69 * g), int(0.55 * g))],
              fill=(86, 140, 92))
    d.ellipse(r(0.57, 0.28, 0.64, 0.35), fill=(255, 214, 120))
    # Zeitleiste mit drei Kapiteln
    d.rounded_rectangle(r(0.30, 0.655, 0.66, 0.675), radius=int(0.01 * g), fill=(196, 120, 76))
    for x in (0.31, 0.48, 0.65):
        d.ellipse(r(x - 0.035, 0.63, x + 0.035, 0.70), fill=(184, 107, 62))

    bild = bild.resize((N, N), Image.LANCZOS)
    ziel = "Chronik/Assets.xcassets/AppIcon.appiconset/AppIcon1024.png"
    bild.save(ziel)
    if "--probe" in sys.argv:
        bild.resize((40, 40), Image.LANCZOS).resize((320, 320), Image.NEAREST).save("/tmp/chronik-icon-40.png")
    print("geschrieben:", ziel)


if __name__ == "__main__":
    main()
