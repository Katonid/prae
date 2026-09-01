#!/usr/bin/env python3
"""Erzeugt das App-Symbol.

    python3 AlarmiOS/scripts/make-icon.py

Ergebnis: ``AlarmiOS/Alarm/Assets.xcassets/AppIcon.appiconset/AppIcon.png``
(1024 × 1024). Nicht von Hand bearbeiten.

Reines Python, ohne fremde Bibliotheken — wie ``scripts/anstoss-icon.py``.
Ein PNG ist ein zlib-Strom mit einem Filterbyte je Zeile; das lässt sich
schreiben, ohne Pillow zu verlangen.

**Farbtyp 2 (RGB), kein Alphakanal.** Mit Alphakanal legt iOS das Symbol auf
Schwarz — dieselbe Falle wie bei den Icons der Wörterwerkstatt.

Warum ein Ausrufezeichen und keine Glocke
-----------------------------------------

Auf dem Startbildschirm eines Dienst-iPads stehen zwanzig Symbole, und
mehrere davon tragen eine Glocke (Erinnerungen, Kalender, jede zweite
Messenger-App). Ein Ausrufezeichen in einem Ring ist auf einen halben
Meter Entfernung eindeutig — und darum geht es: Wer im Ernstfall danach
sucht, sucht nicht lange.
"""

from __future__ import annotations

import math
import os
import struct
import zlib

GROESSE = 1024
HIER = os.path.dirname(os.path.abspath(__file__))
ZIEL = os.path.join(os.path.dirname(HIER), "Alarm", "Assets.xcassets",
                    "AppIcon.appiconset", "AppIcon.png")

DUNKEL = (0x5A, 0x08, 0x0C)     # Rand
HELL = (0xC2, 0x16, 0x1B)       # Mitte
WEISS = (0xFF, 0xFF, 0xFF)


def mische(a, b, anteil):
    return tuple(int(round(x + (y - x) * anteil)) for x, y in zip(a, b))


def deckung(abstand: float, kante: float) -> float:
    """Weiche Kante über etwa zwei Bildpunkte — sonst sieht jede Rundung
    ausgefranst aus, und ein gezacktes Symbol fällt auf einem Retina-Schirm
    sofort auf."""
    return max(0.0, min(1.0, (kante - abstand) / 2.0 + 0.5))


def zeichne() -> bytes:
    mitte = GROESSE / 2.0
    # Balken und Punkt des Ausrufezeichens.
    balken_breite = GROESSE * 0.075
    balken_oben = GROESSE * 0.27
    balken_unten = GROESSE * 0.60
    punkt_mitte = GROESSE * 0.71
    punkt_radius = GROESSE * 0.055
    ring_radius = GROESSE * 0.375
    ring_staerke = GROESSE * 0.028

    zeilen = []
    for y in range(GROESSE):
        zeile = bytearray()
        for x in range(GROESSE):
            dx, dy = x - mitte, y - mitte
            radius = math.hypot(dx, dy)

            # Grund: ein weicher Verlauf von innen nach außen.
            grund = mische(HELL, DUNKEL, min(1.0, radius / (GROESSE * 0.72)))

            # Ring.
            weiss = deckung(abs(radius - ring_radius), ring_staerke)

            # Balken mit runden Enden: Abstand zu einer Strecke.
            if y < balken_oben:
                d = math.hypot(dx, y - balken_oben)
            elif y > balken_unten:
                d = math.hypot(dx, y - balken_unten)
            else:
                d = abs(dx)
            weiss = max(weiss, deckung(d, balken_breite / 2))

            # Punkt.
            weiss = max(weiss, deckung(math.hypot(dx, y - punkt_mitte), punkt_radius))

            farbe = mische(grund, WEISS, weiss)
            zeile += bytes(farbe)
        zeilen.append(bytes(zeile))
    return b"".join(b"\x00" + zeile for zeile in zeilen)


def block(art: bytes, daten: bytes) -> bytes:
    return (struct.pack(">I", len(daten)) + art + daten
            + struct.pack(">I", zlib.crc32(art + daten) & 0xFFFFFFFF))


def main() -> None:
    roh = zeichne()
    kopf = struct.pack(">IIBBBBB", GROESSE, GROESSE, 8, 2, 0, 0, 0)
    png = (b"\x89PNG\r\n\x1a\n"
           + block(b"IHDR", kopf)
           + block(b"IDAT", zlib.compress(roh, 9))
           + block(b"IEND", b""))
    os.makedirs(os.path.dirname(ZIEL), exist_ok=True)
    with open(ZIEL, "wb") as datei:
        datei.write(png)
    print(f"{ZIEL}: {GROESSE}×{GROESSE}, {os.path.getsize(ZIEL) // 1024} KiB")


if __name__ == "__main__":
    main()
