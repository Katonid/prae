#!/usr/bin/env python3
"""Erzeugt das App-Icon von Tafelbild — in mehreren Farben.

Motiv wie in der Web-App „Klassenraum" (`klassenraum/icons/icon.svg`): eine
Tafel im Farbverlauf, darauf eine helle Karte mit **Uhr** und
**Ampelpunkten** — die beiden Elemente, an denen man die App sofort erkennt.

Es gibt sechs Farben. Warum ein fester Satz und kein Regler? iOS lässt eine
App ihr Icon nicht zur Laufzeit zeichnen; erlaubt sind nur *Alternativ-Icons*,
also im Bündel mitgelieferte Bilder, zwischen denen umgeschaltet wird
(`setAlternateIconName`). Ein freier Farbwähler ist damit ausgeschlossen.

    python3 TafelbildiOS/scripts/generate-icon.py

Erzeugt wird:
  * `Assets.xcassets/AppIcon.appiconset/AppIcon1024.png` — die Vorgabe, also
    auch das Bild im App Store.
  * `Tafelbild/Symbole/Icon<Farbe>@2x.png`, `@3x.png`, `@2x~ipad.png` — die
    Alternativen. Die müssen als lose Dateien im Bündel liegen, nicht im
    Asset-Katalog; iOS findet sie über `CFBundleAlternateIcons` in der
    Info.plist. Die Namen dort und hier müssen übereinstimmen.

Bewusst ohne runde Ecken und ohne Transparenz: iOS legt die Maske selbst an,
und ein App-Icon mit Alphakanal weist App Store Connect zurück.

Nicht die PNGs bearbeiten — hier ändern und neu laufen lassen.
"""

from __future__ import annotations

import os
from PIL import Image, ImageDraw, ImageFilter

# Farbverläufe der Tafel. Die Namen entsprechen den Farbschemata der App;
# die Töne sind dunkler gewählt, damit die helle Karte darauf steht.
FARBEN = {
    "Ozean":     ((0x16, 0x68, 0xA8), (0x0A, 0x2C, 0x4A)),   # Vorgabe
    "Rot":       ((0xB3, 0x32, 0x2F), (0x4A, 0x11, 0x13)),
    "Indigo":    ((0x4C, 0x4E, 0xD0), (0x24, 0x1D, 0x5C)),
    "Beere":     ((0x9C, 0x2F, 0x7A), (0x3D, 0x10, 0x38)),
    "Tafelgrün": ((0x13, 0x7A, 0x63), (0x0A, 0x3B, 0x33)),
    "Schiefer":  ((0x47, 0x56, 0x6B), (0x1B, 0x24, 0x32)),
}
# Diese Farbe ist die Vorgabe und liegt im Asset-Katalog.
VORGABE = "Ozean"
# Dateiname je Farbe — ohne Umlaut, damit nichts an der Info.plist scheitert.
DATEINAME = {"Tafelgrün": "IconGruen", "Ozean": "IconOzean", "Rot": "IconRot",
             "Indigo": "IconIndigo", "Beere": "IconBeere", "Schiefer": "IconSchiefer"}

KARTE_OBEN = (0xFF, 0xFF, 0xFF)
KARTE_UNTEN = (0xEE, 0xF2, 0xFF)
TINTE = (0x1E, 0x29, 0x3B)
ROT, GELB, GRUEN = (0xEF, 0x44, 0x44), (0xFA, 0xCC, 0x15), (0x22, 0xC5, 0x5E)

# Zeichenkante: großzügig, danach wird auf die gebrauchten Größen verkleinert.
P = 2048


def mische(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def verlauf_diagonal(groesse, von, bis):
    """Schräger Verlauf wie `linearGradient` von (0.1,0) nach (0.9,1).

    Der Wert hängt nur von (0,8·x + y) ab. Statt für jedes Pixel zu rechnen —
    bei 2048 Kantenlänge sind das vier Millionen — wird ein waagerechter
    Farbbalken gezeichnet und schräg verzerrt. Dasselbe Ergebnis, aber in
    Sekundenbruchteilen.
    """
    stufen = 2048
    balken = Image.new("RGB", (stufen, 1))
    zeichner = ImageDraw.Draw(balken)
    for i in range(stufen):
        zeichner.point((i, 0), fill=mische(von, bis, i / (stufen - 1)))
    balken = balken.resize((stufen, groesse), Image.NEAREST)
    # Zielpixel (x,y) soll die Quellspalte (0,8·x + y)/1,8 sehen.
    a = 0.8 / 1.8 * stufen / groesse
    b = 1.0 / 1.8 * stufen / groesse
    return balken.transform((groesse, groesse), Image.AFFINE, (a, b, 0, 0, 1, 0), Image.BILINEAR)


def verlauf_senkrecht(breite, hoehe, von, bis):
    bild = Image.new("RGB", (breite, hoehe))
    zeichner = ImageDraw.Draw(bild)
    for y in range(hoehe):
        zeichner.line([(0, y), (breite, y)], fill=mische(von, bis, y / max(hoehe - 1, 1)))
    return bild


def male(von, bis) -> Image.Image:
    grund = verlauf_diagonal(P, von, bis)

    # Maße aus der SVG (512er Raster) auf die Zeichenkante umrechnen.
    def s(wert):
        return round(wert / 512 * P)

    karte = (s(80), s(132), s(80 + 352), s(132 + 248))
    radius = s(40)

    schatten = Image.new("L", (P, P), 0)
    ImageDraw.Draw(schatten).rounded_rectangle(
        [karte[0], karte[1] + s(14), karte[2], karte[3] + s(14)], radius=radius, fill=90)
    schatten = schatten.filter(ImageFilter.GaussianBlur(s(14)))
    grund.paste(Image.new("RGB", (P, P), (0x04, 0x12, 0x1A)), (0, 0), schatten)

    flaeche = verlauf_senkrecht(karte[2] - karte[0], karte[3] - karte[1], KARTE_OBEN, KARTE_UNTEN)
    maske = Image.new("L", flaeche.size, 0)
    ImageDraw.Draw(maske).rounded_rectangle([0, 0, flaeche.size[0] - 1, flaeche.size[1] - 1],
                                            radius=radius, fill=255)
    grund.paste(flaeche, (karte[0], karte[1]), maske)

    zeichner = ImageDraw.Draw(grund)

    # Uhr
    ux, uy, ur, strich = s(196), s(256), s(62), s(18)
    zeichner.ellipse([ux - ur, uy - ur, ux + ur, uy + ur], outline=TINTE, width=strich)
    for anfang, ende in (((ux, s(212)), (ux, uy)), ((ux, uy), (s(228), s(276)))):
        zeichner.line([anfang, ende], fill=TINTE, width=strich)
    for punkt in ((ux, s(212)), (ux, uy), (s(228), s(276))):
        r = strich // 2
        zeichner.ellipse([punkt[0] - r, punkt[1] - r, punkt[0] + r, punkt[1] + r], fill=TINTE)

    # Ampelpunkte
    ax, ar = s(330), s(26)
    for y, farbe in ((s(196), ROT), (s(258), GELB), (s(320), GRUEN)):
        zeichner.ellipse([ax - ar, y - ar, ax + ar, y + ar], fill=farbe)

    return grund


def sichere(bild, pfad, kante):
    klein = bild.resize((kante, kante), Image.LANCZOS)
    assert klein.mode == "RGB", "App-Icons dürfen keinen Alphakanal haben"
    os.makedirs(os.path.dirname(pfad), exist_ok=True)
    klein.save(pfad, "PNG", optimize=True)
    return os.path.getsize(pfad)


def main():
    wurzel = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    katalog = os.path.join(wurzel, "Tafelbild", "Assets.xcassets",
                           "AppIcon.appiconset", "AppIcon1024.png")
    lose = os.path.join(wurzel, "Tafelbild", "Symbole")

    gesamt = 0
    for name, (von, bis) in FARBEN.items():
        bild = male(von, bis)
        basis = DATEINAME[name]
        if name == VORGABE:
            gesamt += sichere(bild, katalog, 1024)
            print(f"{name:10} Vorgabe -> AppIcon1024.png")
        # Alternativen brauchen lose Dateien: iPhone @2x/@3x, iPad @2x.
        for endung, kante in (("@2x.png", 120), ("@3x.png", 180), ("@2x~ipad.png", 152)):
            gesamt += sichere(bild, os.path.join(lose, basis + endung), kante)
        print(f"{name:10} -> {basis}@2x/@3x/@2x~ipad.png")
    print(f"\n{gesamt // 1024} kB insgesamt")


if __name__ == "__main__":
    main()
