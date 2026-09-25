#!/usr/bin/env python3
"""Erzeugt das App-Symbol von Fernweh — reines Python, ohne fremde
Bibliotheken (wie die Symbolskripte der anderen Apps dieses Repos).

Ab 1.0.4 (Wahl des Nutzers aus fünf Entwürfen, 09/2026): eine Landschaft —
Himmel mit Sonne und zwei Bergen, ein Streifen Meer, darunter Sand — und
eine Füllfeder, die ihre Tintenspur durch den Sand zieht. Anlass: Der Stift
aus 1.0.1 auf einer dicken weißen Wellenlinie sah dem Routenplaner zu
ähnlich; die Form, die dort die Arbeit macht, ist genau diese Linie. Hier
ist die Spur deshalb dünn und dunkel (Tinte), die Feder trägt das Symbol,
und die Farben sind die, die der Nutzer genannt hat: Orange und Blau —
Sand und Sonne, Himmel und Meer. Die Berge stehen dabei, weil Fernweh
nicht nur ans Meer führt.

Auf 40 Bildpunkten bleiben die Feder und die Teilung Blau/Orange; Sonne und
Berge sind dort Farbflecken — geprüft, bevor gewählt wurde (Lehre aus dem
Reisebuch 1.0.20/1.0.105).

Gezeichnet wird über Abstandsfelder mit einem halben Bildpunkt
Kantenglättung; die Tintenspur wird gestempelt (je Stützpunkt die Pixel im
Umkreis), sonst läge der Lauf bei jedem Pixel über alle Segmente.

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

HIMMEL_OBEN = (120, 200, 245)
HIMMEL_UNTEN = (55, 140, 215)
SAND_OBEN = (255, 200, 110)
SAND_UNTEN = (242, 140, 50)
MEER_OBEN = (40, 120, 200)
MEER_UNTEN = (20, 80, 160)
SONNE = (255, 236, 170)
BERG_DUNKEL = (60, 80, 125)
BERG_HELL = (88, 110, 150)
SCHNEE = (245, 248, 255)
TINTE = (16, 36, 84)
FEDER = (20, 70, 150)
HALTER = (18, 40, 100)
RING = (255, 205, 95)
WEISS = (255, 255, 255)

HORIZONT = 470
KUESTE = 540  # Unterkante des Meeres, darum eine Welle

R = [0.0] * (GROESSE * GROESSE)
G = [0.0] * (GROESSE * GROESSE)
B = [0.0] * (GROESSE * GROESSE)


def mischen(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(x + (y - x) * t for x, y in zip(a, b))


def setzen(i, farbe, deckung):
    if deckung <= 0:
        return
    if deckung >= 1:
        R[i], G[i], B[i] = farbe
        return
    R[i] += (farbe[0] - R[i]) * deckung
    G[i] += (farbe[1] - G[i]) * deckung
    B[i] += (farbe[2] - B[i]) * deckung


def grund():
    for y in range(GROESSE):
        t = y / GROESSE
        himmel = mischen(HIMMEL_OBEN, HIMMEL_UNTEN, t)
        sand = mischen(SAND_OBEN, SAND_UNTEN, t)
        meer = mischen(MEER_OBEN, MEER_UNTEN, t)
        for x in range(GROESSE):
            welle = KUESTE + 10 * math.sin(x / 60)
            if y < HORIZONT:
                farbe = himmel
            elif y < welle - 0.5:
                farbe = meer if y < KUESTE - 20 else MEER_OBEN
            elif y < welle + 0.5:
                farbe = mischen(MEER_OBEN, sand, y - welle + 0.5)
            else:
                farbe = sand
            i = y * GROESSE + x
            R[i], G[i], B[i] = farbe


def kreis(mitte, radius, farbe):
    cx, cy = mitte
    for y in range(int(cy - radius - 2), int(cy + radius + 3)):
        for x in range(int(cx - radius - 2), int(cx + radius + 3)):
            if 0 <= x < GROESSE and 0 <= y < GROESSE:
                d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
                setzen(y * GROESSE + x, farbe, radius - d + 0.5)


def konvex_abstand(px, py, ecken):
    """Vorzeichenbehafteter Abstand zu einem konvexen Vieleck (innen < 0)."""
    flaeche = 0
    for (ax, ay), (bx, by) in zip(ecken, ecken[1:] + ecken[:1]):
        flaeche += ax * by - bx * ay
    richtung = 1 if flaeche > 0 else -1
    best = -1e9
    for (ax, ay), (bx, by) in zip(ecken, ecken[1:] + ecken[:1]):
        nx, ny = (by - ay), -(bx - ax)
        laenge = math.hypot(nx, ny) or 1
        best = max(best, richtung * ((px - ax) * nx + (py - ay) * ny) / laenge)
    return best


def vielecke(stuecke, farbe):
    """Vereinigung konvexer Stücke, EINMAL eingefärbt — so bleibt an den
    gemeinsamen Kanten keine helle Naht."""
    xs = [p[0] for s in stuecke for p in s]
    ys = [p[1] for s in stuecke for p in s]
    for y in range(max(0, int(min(ys)) - 2), min(GROESSE, int(max(ys)) + 3)):
        for x in range(max(0, int(min(xs)) - 2), min(GROESSE, int(max(xs)) + 3)):
            d = min(konvex_abstand(x + 0.5, y + 0.5, s) for s in stuecke)
            if d > 1:
                continue
            if d < -1:
                setzen(y * GROESSE + x, farbe, 1)
                continue
            # An der Kante 4x4 Proben: Ein Abstand würde an einer INNEREN
            # Naht zweier Stücke auf null stehen und dort eine Linie malen.
            treffer = sum(
                1 for a in range(4) for b in range(4)
                if any(konvex_abstand(x + (a + 0.5) / 4, y + (b + 0.5) / 4, s) <= 0 for s in stuecke)
            )
            setzen(y * GROESSE + x, farbe, treffer / 16)


def spur(punkte, radius, farbe):
    naechst = {}
    for (px, py) in punkte:
        for y in range(int(py - radius - 2), int(py + radius + 3)):
            for x in range(int(px - radius - 2), int(px + radius + 3)):
                if 0 <= x < GROESSE and 0 <= y < GROESSE:
                    d = math.hypot(x + 0.5 - px, y + 0.5 - py)
                    i = y * GROESSE + x
                    if d < naechst.get(i, 1e9):
                        naechst[i] = d
    for i, d in naechst.items():
        setzen(i, farbe, radius - d + 0.5)


def bezier(stuecke, schritte=400):
    punkte = []
    for p0, p1, p2, p3 in stuecke:
        for n in range(schritte):
            t = n / schritte
            u = 1 - t
            punkte.append((
                u**3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t**3 * p3[0],
                u**3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t**3 * p3[1],
            ))
    punkte.append(stuecke[-1][3])
    return punkte


def feder(spitze):
    """Füllfeder, Spitze unten links, Achse 45 Grad nach oben rechts."""
    sx, sy = spitze
    w = math.radians(45)
    c, s = math.cos(w), math.sin(w)

    def T(punkte):
        return [(sx + x * c + y * s, sy - x * s + y * c) for x, y in punkte]

    L, Bt = 300, 140
    vielecke([T([(-18, 0), (L * 0.55, -Bt * 0.5 - 15), (L + 135, -Bt * 0.62 - 15),
                 (L + 135, Bt * 0.62 + 15), (L * 0.55, Bt * 0.5 + 15)])], WEISS)
    vielecke([T([(0, 0), (L * 0.55, -Bt * 0.5), (L * 0.85, -Bt * 0.5), (L, -Bt * 0.35),
                 (L, Bt * 0.35), (L * 0.85, Bt * 0.5), (L * 0.55, Bt * 0.5)])], FEDER)
    schlitz = T([(8 + i, 0) for i in range(0, int(L * 0.62) - 8)])
    spur(schlitz, 5, WEISS)
    kreis(T([(L * 0.62, 0)])[0], 20, WEISS)
    vielecke([T([(L, -Bt * 0.62), (L + 120, -Bt * 0.62), (L + 120, Bt * 0.62), (L, Bt * 0.62)])], HALTER)
    vielecke([T([(L + 30, -Bt * 0.62), (L + 60, -Bt * 0.62), (L + 60, Bt * 0.62), (L + 30, Bt * 0.62)])], RING)


def main():
    grund()
    kreis((215, 200), 80, SONNE)
    # Großer Berg samt Schneekappe (Kappe als Vereinigung konvexer Stücke)
    vielecke([[(80, 470), (260, 250), (440, 470)]], BERG_DUNKEL)
    vielecke([[(260, 250), (236, 300), (260, 320), (284, 300)],
              [(260, 250), (212, 309), (236, 300)],
              [(260, 250), (284, 300), (308, 309)]], SCHNEE)
    vielecke([[(300, 470), (430, 320), (560, 470)]], BERG_HELL)
    vielecke([[(430, 320), (398, 357), (430, 350)],
              [(430, 320), (430, 350), (462, 357)]], SCHNEE)
    # Das Meer liegt vor den Bergfüßen: noch einmal übermalen.
    for y in range(HORIZONT, KUESTE - 20):
        farbe = mischen(MEER_OBEN, MEER_UNTEN, y / GROESSE)
        for x in range(GROESSE):
            i = y * GROESSE + x
            R[i], G[i], B[i] = farbe

    linie = bezier([((180, 870), (260, 740), (420, 900), (440, 760)),
                    ((440, 760), (455, 650), (330, 640), (380, 580)),
                    ((380, 580), (420, 530), (470, 560), (500, 500))])
    spur(linie, 13, TINTE)
    kreis((180, 870), 34, TINTE)
    kreis((180, 870), 16, SAND_OBEN)
    feder((500, 500))

    zeilen = []
    for y in range(GROESSE):
        zeile = bytearray([0])
        for x in range(GROESSE):
            i = y * GROESSE + x
            zeile += bytes((int(round(R[i])), int(round(G[i])), int(round(B[i]))))
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
