#!/usr/bin/env python3
"""Erzeugt das App-Symbol von Fernweh — reines Python, ohne fremde
Bibliotheken (wie die Symbolskripte der anderen Apps dieses Repos).

Ein Stift, der die Reisespur zeichnet (Wunsch des Nutzers zu 1.0.1: „Reise
kann ich erkennen, aber nicht Tagebuch"). Die Stecknadel aus 1.0.0 sagte
nur „Karte"; der Stift sagt „schreiben". Eine Farbe und eine Form bleiben
die Regel (Lehre aus dem Reisebuch 1.0.20): weißer Weg und weißer Stift auf
einem diagonalen Verlauf von Abendsonne über Magenta nach Nachtblau. Die dunkle Kontur unter
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


SPITZE = (590, 470)
WINKEL = math.radians(45)
LAENGE = 360
HOLZ = (255, 222, 186)
MINE = (52, 32, 84)
KAPPE = (255, 170, 80)
BAND = (232, 70, 120)


def kurve():
    stuecke = [
        ((230, 820), (330, 610), (520, 800), (500, 610)),
        ((500, 610), (485, 500), (540, 480), SPITZE),
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


def stift(x, y):
    """Abstand zum Stift und die Stelle entlang seiner Achse (0 = Spitze).

    Der Stift liegt schräg nach rechts oben, die Spitze sitzt am Ende des
    Weges. Gerechnet als Radius, der sich entlang der Achse ändert: Kegel an
    der Spitze, gerader Schaft, runde Kappe.
    """
    ax, ay = math.cos(WINKEL), -math.sin(WINKEL)
    dx, dy = x - SPITZE[0], y - SPITZE[1]
    t = dx * ax + dy * ay
    quer = abs(-dx * ay + dy * ax)
    radius = 46
    if t < 0:
        return math.hypot(dx, dy), t
    if t < 90:
        r = radius * t / 90
    elif t < LAENGE - radius:
        r = radius
    elif t <= LAENGE:
        r = math.sqrt(max(0.0, radius * radius - (t - (LAENGE - radius)) ** 2))
    else:
        return 1e9, t
    return quer - r, t


def main():
    linie = kurve()
    zeilen = []
    for y in range(GROESSE):
        zeile = bytearray([0])
        for x in range(GROESSE):
            farbe = verlauf(x, y)
            if 150 <= x <= 880 and 110 <= y <= 880:
                d = abstand(x, y, linie)
                start = math.hypot(x - 230, y - 820)
                s_d, t = stift(x, y)
                kontur = max(deckung(d, 44), deckung(start, 62), deckung(s_d, 12))
                farbe = mischen(farbe, KONTUR, kontur * 0.45)
                farbe = mischen(farbe, WEISS, max(deckung(d, 30), deckung(start, 48)))
                farbe = mischen(farbe, SONNE, deckung(start, 26))
                innen = deckung(s_d, 0)
                if innen > 0:
                    if t < 34:
                        teil = MINE
                    elif t < 90:
                        teil = HOLZ
                    elif LAENGE - 110 < t < LAENGE - 76:
                        teil = BAND
                    elif t > LAENGE - 60:
                        teil = KAPPE
                    else:
                        teil = WEISS
                    farbe = mischen(farbe, teil, innen)
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
