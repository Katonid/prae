#!/usr/bin/env python3
"""Erzeugt das App-Symbol für Anstoß ohne fremde Bibliotheken.

Gezeichnet wird ein dunkelgrüner Rasenhintergrund mit Mittellinie und
Anstoßkreis, darauf ein Fußball. Aufruf:

    python3 scripts/anstoss-icon.py

Ergebnis: AnstossiOS/Anstoss/Assets.xcassets/AppIcon.appiconset/AppIcon1024.png
"""
import math
import os
import struct
import zlib

GROESSE = 1024
ZIEL = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "AnstossiOS", "Anstoss", "Assets.xcassets", "AppIcon.appiconset", "AppIcon1024.png",
)

RASEN_OBEN = (26, 122, 74)
RASEN_UNTEN = (12, 74, 46)
LINIE = (236, 250, 242)
BALL_HELL = (252, 253, 255)
BALL_SCHATTEN = (206, 214, 222)
BALL_FLECK = (24, 30, 38)


def mischen(a, b, anteil):
    return tuple(int(round(a[i] + (b[i] - a[i]) * anteil)) for i in range(3))


def vieleck(mitte_x, mitte_y, radius, ecken, drehung):
    return [
        (
            mitte_x + radius * math.cos(drehung + 2 * math.pi * i / ecken),
            mitte_y + radius * math.sin(drehung + 2 * math.pi * i / ecken),
        )
        for i in range(ecken)
    ]


def im_vieleck(x, y, punkte):
    drin = False
    j = len(punkte) - 1
    for i in range(len(punkte)):
        xi, yi = punkte[i]
        xj, yj = punkte[j]
        if (yi > y) != (yj > y):
            schnitt = (xj - xi) * (y - yi) / (yj - yi) + xi
            if x < schnitt:
                drin = not drin
        j = i
    return drin


def zeichnen():
    mitte = GROESSE / 2
    ball_r = GROESSE * 0.27
    kreis_r = GROESSE * 0.40

    flecken = [vieleck(mitte, mitte, ball_r * 0.34, 5, -math.pi / 2)]
    for i in range(5):
        winkel = -math.pi / 2 + 2 * math.pi * i / 5 + math.pi / 5
        fx = mitte + ball_r * 0.68 * math.cos(winkel)
        fy = mitte + ball_r * 0.68 * math.sin(winkel)
        flecken.append(vieleck(fx, fy, ball_r * 0.27, 5, winkel + math.pi / 2))

    zeilen = []
    for y in range(GROESSE):
        zeile = bytearray()
        zeile.append(0)
        grund = mischen(RASEN_OBEN, RASEN_UNTEN, y / (GROESSE - 1))
        for x in range(GROESSE):
            farbe = grund
            dx = x - mitte
            dy = y - mitte

            # Mittellinie
            if abs(dy) < GROESSE * 0.006:
                farbe = mischen(farbe, LINIE, 0.55)
            # Anstosskreis
            abstand = math.hypot(dx, dy)
            rand = abs(abstand - kreis_r)
            if rand < GROESSE * 0.007:
                farbe = mischen(farbe, LINIE, 0.55)

            if abstand <= ball_r:
                tiefe = abstand / ball_r
                farbe = mischen(BALL_HELL, BALL_SCHATTEN, tiefe ** 2)
                for punkte in flecken:
                    if im_vieleck(x, y, punkte):
                        farbe = BALL_FLECK
                        break
                if ball_r - abstand < GROESSE * 0.010:
                    farbe = mischen(farbe, BALL_FLECK, 0.45)

            zeile += bytes(farbe)
        zeilen.append(bytes(zeile))
    return b"".join(zeilen)


def png(daten):
    def block(name, inhalt):
        roh = name + inhalt
        return struct.pack(">I", len(inhalt)) + roh + struct.pack(">I", zlib.crc32(roh) & 0xFFFFFFFF)

    kopf = struct.pack(">IIBBBBB", GROESSE, GROESSE, 8, 2, 0, 0, 0)
    return (
        b"\x89PNG\r\n\x1a\n"
        + block(b"IHDR", kopf)
        + block(b"IDAT", zlib.compress(daten, 9))
        + block(b"IEND", b"")
    )


if __name__ == "__main__":
    os.makedirs(os.path.dirname(ZIEL), exist_ok=True)
    with open(ZIEL, "wb") as datei:
        datei.write(png(zeichnen()))
    print("geschrieben:", ZIEL)
