#!/usr/bin/env python3
"""Erzeugt das App-Icon von Tafelbild.

Dasselbe Motiv wie in der Web-App „Klassenraum" (`klassenraum/icons/icon.svg`):
eine dunkelgrüne Tafel, darauf eine helle Karte mit **Uhr** und
**Ampelpunkten** — die beiden Elemente, an denen man die App sofort erkennt.

Warum ein Skript und nicht von Hand? Damit das Motiv nachvollziehbar bleibt
und sich zusammen mit der Web-App ändern lässt. Nicht das PNG bearbeiten.

    python3 TafelbildiOS/scripts/generate-icon.py

Bewusst ohne runde Ecken und ohne Transparenz: iOS legt die Maske selbst an,
und ein App-Icon mit Alphakanal weist App Store Connect zurück.
"""

from __future__ import annotations

import os
from PIL import Image, ImageDraw, ImageFilter

KANTE = 1024
# Vierfach zeichnen und am Ende verkleinern — das glättet Kanten und Rundungen
# besser als jedes Antialiasing beim Zeichnen selbst.
UEBER = 4
P = KANTE * UEBER

TAFEL_OBEN = (0x13, 0x7A, 0x63)
TAFEL_UNTEN = (0x0A, 0x3B, 0x33)
KARTE_OBEN = (0xFF, 0xFF, 0xFF)
KARTE_UNTEN = (0xEE, 0xF2, 0xFF)
TINTE = (0x1E, 0x29, 0x3B)
ROT = (0xEF, 0x44, 0x44)
GELB = (0xFA, 0xCC, 0x15)
GRUEN = (0x22, 0xC5, 0x5E)


def mische(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def verlauf_diagonal(groesse, von, bis):
    """Schräger Verlauf wie `linearGradient` von (0.1,0) nach (0.9,1)."""
    bild = Image.new("RGB", (groesse, groesse))
    pixel = bild.load()
    # Für jede Zeile eine Farbe je Spalte wäre teuer; der Verlauf hängt nur
    # von (x + y) ab, also einmal ausrechnen und zeilenweise setzen.
    for y in range(groesse):
        for x in range(groesse):
            t = (x / groesse * 0.8 + y / groesse) / 1.8
            pixel[x, y] = mische(von, bis, min(max(t, 0), 1))
    return bild


def verlauf_senkrecht(breite, hoehe, von, bis):
    bild = Image.new("RGB", (breite, hoehe))
    zeichner = ImageDraw.Draw(bild)
    for y in range(hoehe):
        zeichner.line([(0, y), (breite, y)], fill=mische(von, bis, y / max(hoehe - 1, 1)))
    return bild


def male() -> Image.Image:
    # --- Tafel als Grund ---
    grund = verlauf_diagonal(P, TAFEL_OBEN, TAFEL_UNTEN)

    # --- Karte: Maße aus der SVG, mal zwei (512 -> 1024), mal Überabtastung ---
    def s(wert):
        return round(wert * 2 * UEBER)

    karte_kasten = (s(80), s(132), s(80 + 352), s(132 + 248))
    karte_radius = s(40)

    # Schlagschatten: eigene Maske, weichgezeichnet, dann dunkel einfärben.
    schatten = Image.new("L", (P, P), 0)
    ImageDraw.Draw(schatten).rounded_rectangle(
        [karte_kasten[0], karte_kasten[1] + s(14), karte_kasten[2], karte_kasten[3] + s(14)],
        radius=karte_radius, fill=90)
    schatten = schatten.filter(ImageFilter.GaussianBlur(s(14)))
    grund.paste(Image.new("RGB", (P, P), (0x04, 0x12, 0x1A)), (0, 0), schatten)

    karte = verlauf_senkrecht(karte_kasten[2] - karte_kasten[0],
                              karte_kasten[3] - karte_kasten[1],
                              KARTE_OBEN, KARTE_UNTEN)
    maske = Image.new("L", karte.size, 0)
    ImageDraw.Draw(maske).rounded_rectangle([0, 0, karte.size[0] - 1, karte.size[1] - 1],
                                            radius=karte_radius, fill=255)
    grund.paste(karte, (karte_kasten[0], karte_kasten[1]), maske)

    zeichner = ImageDraw.Draw(grund)

    # --- Uhr ---
    ux, uy, ur = s(196), s(256), s(62)
    strich = s(18)
    zeichner.ellipse([ux - ur, uy - ur, ux + ur, uy + ur], outline=TINTE, width=strich)
    # Zeiger: von 12 Uhr zur Mitte, dann nach halb vier — wie im SVG-Pfad.
    for anfang, ende in ((((ux, s(212))), (ux, uy)), ((ux, uy), (s(228), s(276)))):
        zeichner.line([anfang, ende], fill=TINTE, width=strich)
    # Runde Enden und ein sauberer Knick in der Mitte.
    for punkt in ((ux, s(212)), (ux, uy), (s(228), s(276))):
        r = strich // 2
        zeichner.ellipse([punkt[0] - r, punkt[1] - r, punkt[0] + r, punkt[1] + r], fill=TINTE)

    # --- Ampelpunkte ---
    ax, ar = s(330), s(26)
    for y, farbe in ((s(196), ROT), (s(258), GELB), (s(320), GRUEN)):
        zeichner.ellipse([ax - ar, y - ar, ax + ar, y + ar], fill=farbe)

    return grund.resize((KANTE, KANTE), Image.LANCZOS)


def main():
    ziel = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                        "Tafelbild", "Assets.xcassets", "AppIcon.appiconset", "AppIcon1024.png")
    bild = male()
    assert bild.mode == "RGB", "App-Icons dürfen keinen Alphakanal haben"
    bild.save(ziel, "PNG", optimize=True)
    print(f"{ziel}  {os.path.getsize(ziel) // 1024} kB, {bild.size[0]}x{bild.size[1]}, {bild.mode}")


if __name__ == "__main__":
    main()
