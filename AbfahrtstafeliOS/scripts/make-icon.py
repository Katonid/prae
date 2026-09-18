#!/usr/bin/env python3
"""Erzeugt das App-Symbol für die Abfahrtstafel — reines Python, ohne fremde
Bibliotheken (wie die Symbolskripte der anderen Apps dieses Repos).

Gezeichnet wird eine Anzeigetafel, wie sie an einem Bahnsteig hängt: dunkler
Grund, darauf drei leuchtende Zeilen — links ein Linienschild, rechts eine
Minutenziffer. Kein Fahrzeug: Diese App zeigt nicht Züge, sondern WANN sie
fahren.

    python3 AbfahrtstafeliOS/scripts/make-icon.py

Ergebnis: Abfahrtstafel/Assets.xcassets/AppIcon.appiconset/AppIcon1024.png
"""
import os
import struct
import zlib

GROESSE = 1024
ZIEL = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "Abfahrtstafel", "Assets.xcassets", "AppIcon.appiconset", "AppIcon1024.png",
)

GRUND_OBEN = (24, 30, 44)
GRUND_UNTEN = (12, 16, 26)
SCHILD = (0, 132, 76)
SCHILD_ZWEI = (24, 84, 168)
SCHILD_DREI = (196, 44, 40)
ZIFFER = (255, 186, 62)
ZEILE = (120, 132, 156)


def mischen(a, b, anteil):
    return tuple(round(x + (y - x) * anteil) for x, y in zip(a, b))


def leinwand():
    return [[GRUND_OBEN[:] for _ in range(GROESSE)] for _ in range(GROESSE)]


def rechteck(bild, x0, y0, x1, y1, farbe, radius=0):
    """Ein Rechteck mit runden Ecken. Die Rundung wird über den Abstand zum
    jeweiligen Eckmittelpunkt geprüft — das ist langsamer als vier Bögen und
    dafür in fünf Zeilen richtig."""
    for y in range(max(0, int(y0)), min(GROESSE, int(y1))):
        for x in range(max(0, int(x0)), min(GROESSE, int(x1))):
            if radius:
                cx = min(max(x, x0 + radius), x1 - radius)
                cy = min(max(y, y0 + radius), y1 - radius)
                if (x - cx) ** 2 + (y - cy) ** 2 > radius * radius:
                    continue
            bild[y][x] = list(farbe)


# Die Ziffern 0-9 als 5x7-Raster. Selbst gesetzt, weil eine Schrift zu laden
# eine Abhängigkeit wäre — und für vier Ziffern lohnt das nicht.
ZIFFERNBILD = {
    "1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
    "3": ["####.", "....#", "....#", ".###.", "....#", "....#", "####."],
    "7": ["#####", "....#", "...#.", "..#..", "..#..", "..#..", "..#.."],
    "S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
    "U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "6": [".###.", "#....", "#....", "####.", "#...#", "#...#", ".###."],
    "2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
}


def zeichen(bild, text, x, y, punkt, farbe):
    """Setzt Zeichen aus dem Raster. `punkt` ist die Kantenlänge eines
    Rasterpunktes."""
    for spalte, buchstabe in enumerate(text):
        muster = ZIFFERNBILD.get(buchstabe)
        if not muster:
            continue
        versatz = x + spalte * punkt * 6
        for zeile, reihe in enumerate(muster):
            for stelle, wert in enumerate(reihe):
                if wert != "#":
                    continue
                rechteck(
                    bild,
                    versatz + stelle * punkt,
                    y + zeile * punkt,
                    versatz + (stelle + 1) * punkt,
                    y + (zeile + 1) * punkt,
                    farbe,
                )


def bauen():
    bild = leinwand()
    # Grund mit sanftem Verlauf von oben nach unten.
    for y in range(GROESSE):
        farbe = mischen(GRUND_OBEN, GRUND_UNTEN, y / GROESSE)
        for x in range(GROESSE):
            bild[y][x] = list(farbe)

    # Drei Zeilen, wie auf einer Tafel. Oben die nächste (hell), darunter die
    # weiteren (blasser) — dasselbe Gefälle wie in der App.
    zeilen = [
        (208, SCHILD, "S", "3", 255),
        (446, SCHILD_ZWEI, "U", "6", 190),
        (684, SCHILD_DREI, "2", "7", 135),
    ]
    for oben, schildfarbe, schildzeichen, minutenzeichen, kraft in zeilen:
        anteil = kraft / 255
        # Das Linienschild links.
        rechteck(bild, 118, oben, 368, oben + 150, mischen(GRUND_UNTEN, schildfarbe, anteil), radius=28)
        zeichen(bild, schildzeichen, 168, oben + 36, 14, mischen(GRUND_UNTEN, (255, 255, 255), anteil))
        zeichen(bild, "3" if schildzeichen == "S" else ("6" if schildzeichen == "U" else "7"),
                268, oben + 36, 14, mischen(GRUND_UNTEN, (255, 255, 255), anteil))
        # Der Strich, der für den Zielnamen steht. Ein echter Name wäre in
        # einem Symbol nicht zu lesen.
        rechteck(bild, 404, oben + 58, 640, oben + 92, mischen(GRUND_UNTEN, ZEILE, anteil * 0.75), radius=17)
        # Die Minutenziffer rechts.
        zeichen(bild, minutenzeichen, 716, oben + 10, 19, mischen(GRUND_UNTEN, ZIFFER, anteil))

    return bild


def schreiben(bild, pfad):
    roh = b"".join(
        b"\x00" + b"".join(bytes(punkt) for punkt in zeile) for zeile in bild
    )

    def block(art, inhalt):
        return (
            struct.pack(">I", len(inhalt))
            + art
            + inhalt
            + struct.pack(">I", zlib.crc32(art + inhalt) & 0xFFFFFFFF)
        )

    # Farbtyp 2 (RGB) ohne Alphakanal: Ein App-Symbol mit Alphakanal weist
    # App Store Connect zurück.
    kopf = struct.pack(">IIBBBBB", GROESSE, GROESSE, 8, 2, 0, 0, 0)
    daten = (
        b"\x89PNG\r\n\x1a\n"
        + block(b"IHDR", kopf)
        + block(b"IDAT", zlib.compress(roh, 9))
        + block(b"IEND", b"")
    )
    os.makedirs(os.path.dirname(pfad), exist_ok=True)
    with open(pfad, "wb") as datei:
        datei.write(daten)


if __name__ == "__main__":
    schreiben(bauen(), ZIEL)
    print(f"geschrieben: {ZIEL}")
