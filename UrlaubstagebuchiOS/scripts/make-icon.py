#!/usr/bin/env python3
"""Erzeugt das App-Symbol für das Urlaubstagebuch — reines Python, ohne
fremde Bibliotheken (wie die Symbolskripte der anderen Apps dieses Repos).

Gezeichnet wird ein aufgeschlagenes Buch von oben, und darüber läuft die
Reisespur mit ihren Punkten. Beides zusammen ist die App: das Tagebuch und
der Weg, den es festhält. Kein Koffer, kein Globus — die sagen „Reise", aber
nicht, was diese App tut.

    python3 UrlaubstagebuchiOS/scripts/make-icon.py

Ergebnis: Urlaubstagebuch/Assets.xcassets/AppIcon.appiconset/AppIcon1024.png
"""
import math
import os
import struct
import zlib

GROESSE = 1024
ZIEL = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "Urlaubstagebuch", "Assets.xcassets", "AppIcon.appiconset", "AppIcon1024.png",
)

GRUND_OBEN = (38, 62, 74)
GRUND_UNTEN = (20, 36, 46)
PAPIER = (250, 246, 238)
PAPIER_SCHATTEN = (226, 218, 205)
FALZ = (206, 196, 180)
SPUR = (208, 105, 60)
PUNKT_RAND = (255, 252, 246)
LINEATUR = (214, 206, 192)


def mischen(a, b, anteil):
    anteil = max(0.0, min(1.0, anteil))
    return tuple(a[i] + (b[i] - a[i]) * anteil for i in range(3))


def leinwand():
    """Der Grund als senkrechter Verlauf."""
    bild = []
    for y in range(GROESSE):
        farbe = mischen(GRUND_OBEN, GRUND_UNTEN, y / (GROESSE - 1))
        bild.append([list(farbe) for _ in range(GROESSE)])
    return bild


def setzen(bild, x, y, farbe, deckung):
    """Ein Punkt mit Deckung — daraus entstehen weiche Kanten.

    Ohne diese eine Zeile hätte jedes Rund im Symbol eine Treppe, und das
    sieht man auf einem Homescreen sofort. Ein Bildpunkt wird also nicht
    gesetzt oder nicht gesetzt, sondern anteilig gemischt.
    """
    if deckung <= 0 or x < 0 or y < 0 or x >= GROESSE or y >= GROESSE:
        return
    if deckung >= 1:
        bild[y][x] = list(farbe)
        return
    bild[y][x] = list(mischen(bild[y][x], farbe, deckung))


def deckung_aus_abstand(abstand, weichheit=1.0):
    """Innen 1, außen 0, dazwischen ein Übergang von einem Bildpunkt."""
    return max(0.0, min(1.0, 0.5 - abstand / weichheit))


def rundrechteck(bild, x0, y0, x1, y1, radius, farbe):
    for y in range(max(0, int(y0 - 2)), min(GROESSE, int(y1 + 2))):
        for x in range(max(0, int(x0 - 2)), min(GROESSE, int(x1 + 2))):
            cx = min(max(x + 0.5, x0 + radius), x1 - radius)
            cy = min(max(y + 0.5, y0 + radius), y1 - radius)
            abstand = math.hypot(x + 0.5 - cx, y + 0.5 - cy) - radius
            setzen(bild, x, y, farbe, deckung_aus_abstand(abstand))


def kreis(bild, mx, my, radius, farbe):
    for y in range(max(0, int(my - radius - 2)), min(GROESSE, int(my + radius + 2))):
        for x in range(max(0, int(mx - radius - 2)), min(GROESSE, int(mx + radius + 2))):
            abstand = math.hypot(x + 0.5 - mx, y + 0.5 - my) - radius
            setzen(bild, x, y, farbe, deckung_aus_abstand(abstand))


def strecke(bild, ax, ay, bx, by, breite, farbe):
    """Eine Strecke mit runden Enden, über den Abstand Punkt-zu-Strecke.

    Das ist langsamer als ein Bresenham-Algorithmus und dafür in fünf Zeilen
    richtig — samt weicher Kante und ohne Lücken an den Knicken.
    """
    halb = breite / 2
    minx = int(min(ax, bx) - halb - 2)
    maxx = int(max(ax, bx) + halb + 2)
    miny = int(min(ay, by) - halb - 2)
    maxy = int(max(ay, by) + halb + 2)
    dx, dy = bx - ax, by - ay
    laenge = dx * dx + dy * dy
    for y in range(max(0, miny), min(GROESSE, maxy)):
        for x in range(max(0, minx), min(GROESSE, maxx)):
            px, py = x + 0.5 - ax, y + 0.5 - ay
            anteil = 0.0 if laenge == 0 else max(0.0, min(1.0, (px * dx + py * dy) / laenge))
            abstand = math.hypot(px - anteil * dx, py - anteil * dy) - halb
            setzen(bild, x, y, farbe, deckung_aus_abstand(abstand))


def kurve(bild, punkte, breite, farbe, schritte=14):
    """Eine weiche Linie durch die gegebenen Punkte (Catmull-Rom), gezeichnet
    als Kette kurzer Strecken. Eine Reisespur aus geraden Knicken sähe aus
    wie ein Diagramm und nicht wie ein Weg."""
    erweitert = [punkte[0]] + list(punkte) + [punkte[-1]]
    fein = []
    for i in range(len(erweitert) - 3):
        p0, p1, p2, p3 = erweitert[i:i + 4]
        for s in range(schritte):
            t = s / schritte
            t2, t3 = t * t, t * t * t
            x = 0.5 * ((2 * p1[0]) + (-p0[0] + p2[0]) * t
                       + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t2
                       + (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t3)
            y = 0.5 * ((2 * p1[1]) + (-p0[1] + p2[1]) * t
                       + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2
                       + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t3)
            fein.append((x, y))
    fein.append(punkte[-1])
    for i in range(len(fein) - 1):
        strecke(bild, fein[i][0], fein[i][1], fein[i + 1][0], fein[i + 1][1], breite, farbe)


def bauen():
    bild = leinwand()

    # Das aufgeschlagene Buch: ein Schattenblatt, darauf die beiden Seiten.
    rundrechteck(bild, 118, 250, 906, 800, 26, PAPIER_SCHATTEN)
    rundrechteck(bild, 108, 232, 896, 782, 26, PAPIER)

    # Die Lineatur der rechten Seite. Sie macht aus einer weißen Fläche ein
    # Tagebuch — ohne sie wäre es irgendein Blatt.
    for i in range(6):
        y = 356 + i * 62
        rundrechteck(bild, 540, y, 826, y + 13, 6, LINEATUR)

    # Der Falz in der Mitte.
    rundrechteck(bild, 496, 250, 508, 764, 6, FALZ)

    # Die Reisespur über der linken Seite. Sie windet sich mit Absicht, statt
    # gleichmäßig zu steigen: Eine Linie, die nur nach rechts oben läuft,
    # liest sich als Diagramm und nicht als Weg.
    spur = [(178, 700), (272, 606), (206, 486), (330, 428), (296, 328), (438, 288)]
    kurve(bild, spur, 26, (255, 253, 248))
    kurve(bild, spur, 15, SPUR)

    for i, (x, y) in enumerate(spur):
        if i not in (0, len(spur) - 1):
            continue
        kreis(bild, x, y, 34, PUNKT_RAND)
        kreis(bild, x, y, 21, SPUR)
    for i, (x, y) in enumerate(spur):
        if i in (0, len(spur) - 1):
            continue
        kreis(bild, x, y, 22, PUNKT_RAND)
        kreis(bild, x, y, 12, SPUR)

    return bild


def schreiben(bild, pfad):
    roh = b"".join(
        b"\x00" + bytes(
            max(0, min(255, int(round(wert))))
            for punkt in zeile for wert in punkt
        )
        for zeile in bild
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
