#!/usr/bin/env python3
"""Erzeugt das App-Symbol des Routenplaners — reines Python, ohne fremde
Bibliotheken (wie die Symbolskripte der anderen Apps dieses Repos).

Eine Farbe und eine Form (Lehre aus dem Reisebuch 1.0.20): ein weißer,
geschwungener Weg mit grünem Anfang und rotem Ziel auf einem diagonalen
Verlauf von Tannengrün nach Petrol. Die dunkle Kontur unter dem Weiß hält
die Linie auch dort, wo der Verlauf hell ist.

    python3 RoutenplaneriOS/scripts/make-icon.py
"""
import math
import os
import struct
import zlib

GROESSE = 1024
ZIEL = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "Routenplaner", "Assets.xcassets", "AppIcon.appiconset", "AppIcon1024.png",
)

OBEN = (46, 150, 96)
UNTEN = (18, 70, 110)
WEISS = (255, 255, 255)
KONTUR = (10, 40, 60)
GRUEN = (70, 200, 110)
ROT = (230, 60, 55)


def mischen(a, b, t):
    return tuple(x + (y - x) * t for x, y in zip(a, b))


def kurve():
    """Ein S-förmiger Weg aus kubischen Bézierstücken, fein abgetastet."""
    stuecke = [
        ((250, 800), (250, 560), (560, 700), (560, 500)),
        ((560, 500), (560, 300), (780, 420), (780, 230)),
    ]
    punkte = []
    for p0, p1, p2, p3 in stuecke:
        for i in range(120):
            t = i / 120
            u = 1 - t
            x = u**3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t**3 * p3[0]
            y = u**3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t**3 * p3[1]
            punkte.append((x, y))
    punkte.append(stuecke[-1][3])
    return punkte


def abstand_zur_linie(px, py, linie):
    best = 1e9
    for (ax, ay), (bx, by) in zip(linie, linie[1:]):
        dx, dy = bx - ax, by - ay
        l2 = dx * dx + dy * dy
        t = 0 if l2 == 0 else max(0, min(1, ((px - ax) * dx + (py - ay) * dy) / l2))
        x, y = ax + t * dx, ay + t * dy
        d = (px - x) ** 2 + (py - y) ** 2
        if d < best:
            best = d
    return math.sqrt(best)


def deckung(d, radius):
    """Weiche Kante über einen Bildpunkt — ohne Überabtastung."""
    return max(0.0, min(1.0, radius - d + 0.5))


def main():
    linie = kurve()
    anfang, ende = linie[0], linie[-1]
    minx = min(p[0] for p in linie) - 90
    maxx = max(p[0] for p in linie) + 90
    miny = min(p[1] for p in linie) - 90
    maxy = max(p[1] for p in linie) + 90
    zeilen = []
    for y in range(GROESSE):
        zeile = bytearray([0])
        for x in range(GROESSE):
            farbe = mischen(OBEN, UNTEN, (x + y) / (2 * GROESSE))
            if minx <= x <= maxx and miny <= y <= maxy:
                d = abstand_zur_linie(x, y, linie)
                farbe = mischen(farbe, KONTUR, deckung(d, 52) * 0.55)
                farbe = mischen(farbe, WEISS, deckung(d, 38))
                farbe = mischen(farbe, WEISS, deckung(math.hypot(x - anfang[0], y - anfang[1]), 70))
                farbe = mischen(farbe, GRUEN, deckung(math.hypot(x - anfang[0], y - anfang[1]), 52))
                farbe = mischen(farbe, WEISS, deckung(math.hypot(x - ende[0], y - ende[1]), 70))
                farbe = mischen(farbe, ROT, deckung(math.hypot(x - ende[0], y - ende[1]), 52))
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
