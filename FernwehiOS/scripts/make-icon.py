#!/usr/bin/env python3
"""Erzeugt das App-Symbol von Fernweh — reines Python, ohne fremde
Bibliotheken (wie die Symbolskripte der anderen Apps dieses Repos).

Eine Farbe und eine Form (Lehre aus dem Reisebuch 1.0.20): ein weißer,
geschwungener Reiseweg, der in einer Stecknadel endet, auf einem diagonalen
Verlauf von Abendsonne über Magenta nach Nachtblau. Die dunkle Kontur unter
dem Weiß hält die Linie auch dort, wo der Verlauf hell ist. Alles bleibt
zwischen 140 und 884 — was näher an der Ecke liegt, schneidet iOS weg.

    python3 FernwehiOS/scripts/make-icon.py
"""
import math
import os
import struct
import zlib

GROESSE = 1024
ZIEL = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "Fernweh", "Assets.xcassets", "AppIcon.appiconset", "AppIcon1024.png",
)

SONNE = (255, 170, 80)
MAGENTA = (232, 70, 120)
NACHT = (48, 36, 120)
WEISS = (255, 255, 255)
KONTUR = (40, 20, 70)


def mischen(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(x + (y - x) * t for x, y in zip(a, b))


def verlauf(x, y):
    t = (x + (GROESSE - y)) / (2 * GROESSE)  # unten links hell, oben rechts dunkel
    t = 1 - t
    return mischen(SONNE, MAGENTA, t / 0.55) if t < 0.55 else mischen(MAGENTA, NACHT, (t - 0.55) / 0.45)


def kurve():
    stuecke = [
        ((230, 820), (330, 600), (560, 820), (560, 600)),
        ((560, 600), (560, 420), (700, 470), (700, 380)),
    ]
    punkte = []
    for p0, p1, p2, p3 in stuecke:
        for i in range(140):
            t = i / 140
            u = 1 - t
            punkte.append((
                u**3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t**3 * p3[0],
                u**3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t**3 * p3[1],
            ))
    punkte.append(stuecke[-1][3])
    return punkte


def abstand(px, py, linie):
    best = 1e18
    for (ax, ay), (bx, by) in zip(linie, linie[1:]):
        dx, dy = bx - ax, by - ay
        l2 = dx * dx + dy * dy
        t = 0 if l2 == 0 else max(0, min(1, ((px - ax) * dx + (py - ay) * dy) / l2))
        d = (px - ax - t * dx) ** 2 + (py - ay - t * dy) ** 2
        best = min(best, d)
    return math.sqrt(best)


def deckung(d, radius):
    return max(0.0, min(1.0, radius - d + 0.5))


def nadel(x, y):
    """Abstand zur Stecknadel: ein Kreis mit einer Spitze nach unten."""
    cx, cy, r = 700, 260, 118
    d_kreis = math.hypot(x - cx, y - cy) - r
    # Spitze: Dreieck von den Tangentenpunkten bis (700, 420)
    spitze_y = 420
    if cy <= y <= spitze_y:
        halb = r * 0.86 * (spitze_y - y) / (spitze_y - cy)
        d_drei = abs(x - cx) - halb
    else:
        d_drei = 1e9
    return min(d_kreis, d_drei)


def main():
    linie = kurve()
    zeilen = []
    for y in range(GROESSE):
        zeile = bytearray([0])
        for x in range(GROESSE):
            farbe = verlauf(x, y)
            if 150 <= x <= 860 and 110 <= y <= 880:
                d = abstand(x, y, linie) if y > 360 else 1e9
                start = math.hypot(x - 230, y - 820)
                n = nadel(x, y)
                # Erst EINE Kontur um alles, dann EIN Weiß darüber — sonst
                # legt sich die Kontur des Weges als grauer Ring über Punkt
                # und Nadel.
                kontur = max(deckung(d, 44), deckung(start, 62), deckung(n, 12))
                weiss = max(deckung(d, 30), deckung(start, 48), deckung(n, 0))
                farbe = mischen(farbe, KONTUR, kontur * 0.45)
                farbe = mischen(farbe, WEISS, weiss)
                farbe = mischen(farbe, SONNE, deckung(start, 26))
                loch = math.hypot(x - 700, y - 260)
                farbe = mischen(farbe, MAGENTA, deckung(loch, 46))
            zeile += bytes(int(round(c)) for c in farbe)
        zeilen.append(bytes(zeile))
    roh = zlib.compress(b"".join(zeilen), 9)

    def block(art, daten):
        return struct.pack(">I", len(daten)) + art + daten + struct.pack(">I", zlib.crc32(art + daten) & 0xFFFFFFFF)

    # Farbtyp 2 (RGB) ohne Alphakanal — mit Alpha legt iOS das Symbol auf Schwarz.
    png = b"\x89PNG\r\n\x1a\n" + block(b"IHDR", struct.pack(">IIBBBBB", GROESSE, GROESSE, 8, 2, 0, 0, 0))
    png += block(b"IDAT", roh) + block(b"IEND", b"")
    os.makedirs(os.path.dirname(ZIEL), exist_ok=True)
    with open(ZIEL, "wb") as f:
        f.write(png)
    print("geschrieben:", ZIEL)


if __name__ == "__main__":
    main()
