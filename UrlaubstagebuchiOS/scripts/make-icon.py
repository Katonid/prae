#!/usr/bin/env python3
"""Erzeugt das App-Symbol für das Reisebuch — reines Python, ohne fremde
Bibliotheken (wie die Symbolskripte der anderen Apps dieses Repos).

WAS ES ZEIGT (Wahl des Nutzers, 09/2026): ein Buch von vorn, mit einem Bild
auf dem Deckel und zwei Strichen als Bildunterschrift darunter. Also genau
das, was die App ist — ein Fotobuch.

WIE ES DAHIN KAM. Bis 1.0.19 lag hier ein aufgeschlagenes Buch in
Papierweiß über drei Vierteln der Fläche; der Nutzer meldete: „Das
Programm-Icon sieht von Weitem aus wie eine weiße Fläche mit einem Rand
drumherum." Er hatte recht: Auf einem Homescreen misst ein Symbol vierzig
Bildpunkte, und dann bleibt von Papier, Falz und Lineatur nichts übrig.
1.0.20 setzte deshalb einen Weg mit Anfang und Ziel — eine Farbe und eine
Form. Der Nutzer wollte 09/2026 etwas anderes sehen, und aus fünf Entwürfen
wählte er diesen; auf seinen Wunsch hin sagen Foto UND Buch, worum es geht.

DREI REGELN, UND JEDE IST BEZAHLT:

1. **Ein Symbol trägt bei vierzig Bildpunkten eine FARBE und eine FORM.**
   Wer das prüfen will, rechnet das Ergebnis auf vierzig Bildpunkte herunter
   und sieht es sich an — was dort verschwindet, verschwindet auf dem Gerät.
   Genau daran ist der Entwurf vor 1.0.20 gescheitert, und genau daran sind
   beim Aussuchen vier von fünf Entwürfen gescheitert: Ihr Buch hing an
   einer dünnen Bundlinie, und die ist bei dieser Größe weg. Hier trägt das
   Buch die ganze Form.

2. **Die Kontur unter dem Weiß ist keine Zierde.** Der Verlauf ist oben
   links deutlich heller als unten rechts; ohne sie verlöre die weiße Fläche
   dort ihren Halt. Dieselbe Überlegung wie bei den Linienzügen der
   Abfahrtstafel.

3. **Der Verlauf läuft DIAGONAL.** Ein senkrechter sieht auf einem
   Homescreen wie ein Farbfeld aus, ein diagonaler hat eine Richtung.

Alles bleibt zwischen 140 und 884 — was näher an der Ecke liegt, schneidet
iOS mit seiner abgerundeten Maske weg.

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

GRUND_A = (236, 106, 148)    # oben links
GRUND_B = (92, 36, 130)      # unten rechts
WEISS = (255, 253, 250)
KONTUR = (66, 22, 96)        # Kontur, Bildfenster und Striche


def mischen(a, b, anteil):
    anteil = max(0.0, min(1.0, anteil))
    return tuple(a[i] + (b[i] - a[i]) * anteil for i in range(3))


def grundfarbe(x, y):
    """Der Verlauf an dieser Stelle — diagonal von oben links nach unten
    rechts."""
    return mischen(GRUND_A, GRUND_B, (x + y) / (2 * (GROESSE - 1)))


def leinwand():
    return [[list(grundfarbe(x, y)) for x in range(GROESSE)] for y in range(GROESSE)]


def setzen(bild, x, y, farbe, deckung):
    """Ein Punkt mit Deckung — daraus entstehen die weichen Kanten.

    Ohne diese eine Zeile hätte jedes Rund im Symbol eine Treppe, und das
    sieht man auf einem Homescreen sofort.
    """
    if deckung <= 0 or x < 0 or y < 0 or x >= GROESSE or y >= GROESSE:
        return
    if deckung >= 1:
        bild[y][x] = list(farbe)
        return
    bild[y][x] = list(mischen(bild[y][x], farbe, deckung))


def kreis(bild, mx, my, radius, farbe):
    for y in range(max(0, int(my - radius - 2)), min(GROESSE, int(my + radius + 3))):
        for x in range(max(0, int(mx - radius - 2)), min(GROESSE, int(mx + radius + 3))):
            abstand = math.hypot(x + 0.5 - mx, y + 0.5 - my) - radius
            setzen(bild, x, y, farbe, max(0.0, min(1.0, 0.5 - abstand)))


def strecke(bild, ax, ay, bx, by, breite, farbe):
    """Eine Strecke mit runden Enden, über den Abstand Punkt-zu-Strecke.

    Langsamer als ein Bresenham-Algorithmus und dafür in fünf Zeilen
    richtig — samt weicher Kante.
    """
    halb = breite / 2
    dx, dy = bx - ax, by - ay
    laenge = dx * dx + dy * dy
    for y in range(max(0, int(min(ay, by) - halb - 2)),
                   min(GROESSE, int(max(ay, by) + halb + 3))):
        for x in range(max(0, int(min(ax, bx) - halb - 2)),
                       min(GROESSE, int(max(ax, bx) + halb + 3))):
            px, py = x + 0.5 - ax, y + 0.5 - ay
            anteil = 0.0 if laenge == 0 else max(0.0, min(1.0, (px * dx + py * dy) / laenge))
            abstand = math.hypot(px - anteil * dx, py - anteil * dy) - halb
            setzen(bild, x, y, farbe, max(0.0, min(1.0, 0.5 - abstand)))


def rundeck(bild, mx, my, halbbreite, halbhoehe, radius, farbe):
    """Ein abgerundetes Rechteck, über den vorzeichenbehafteten Abstand.

    Das gibt die weiche Kante geschenkt und kommt ohne eine einzige
    Fallunterscheidung an den Ecken aus.
    """
    reichweite = int(math.hypot(halbbreite, halbhoehe)) + 3
    for y in range(max(0, int(my) - reichweite), min(GROESSE, int(my) + reichweite)):
        for x in range(max(0, int(mx) - reichweite), min(GROESSE, int(mx) + reichweite)):
            px, py = x + 0.5 - mx, y + 0.5 - my
            qx = abs(px) - (halbbreite - radius)
            qy = abs(py) - (halbhoehe - radius)
            abstand = (math.hypot(max(qx, 0.0), max(qy, 0.0))
                       + min(max(qx, qy), 0.0) - radius)
            setzen(bild, x, y, farbe, max(0.0, min(1.0, 0.5 - abstand)))


def flaeche(bild, punkte, farbe):
    """Ein Vieleck, vierfach überabgetastet. Gebraucht für den Berg im
    Bildfenster — der ist die eine Form, die kein Rechteck ist."""
    xs = [p[0] for p in punkte]
    ys = [p[1] for p in punkte]
    anzahl = len(punkte)
    for y in range(max(0, int(min(ys)) - 2), min(GROESSE, int(max(ys)) + 3)):
        for x in range(max(0, int(min(xs)) - 2), min(GROESSE, int(max(xs)) + 3)):
            treffer = 0
            for sy in range(4):
                py = y + (sy + 0.5) / 4
                for sx in range(4):
                    px = x + (sx + 0.5) / 4
                    drin = False
                    j = anzahl - 1
                    for i in range(anzahl):
                        xi, yi = punkte[i]
                        xj, yj = punkte[j]
                        if ((yi > py) != (yj > py)
                                and px < (xj - xi) * (py - yi) / (yj - yi) + xi):
                            drin = not drin
                        j = i
                    if drin:
                        treffer += 1
            setzen(bild, x, y, farbe, treffer / 16)


def bauen():
    bild = leinwand()

    # Das Buch: Kontur, darin der weiße Deckel.
    rundeck(bild, 512, 512, 296, 346, 34, KONTUR)
    rundeck(bild, 512, 512, 274, 324, 26, WEISS)

    # Die Bundlinie. Sie ist der eine Strich, der aus einem weißen Rechteck
    # ein Buch macht — hier trägt sie nicht allein, weil das Bildfenster
    # und die Striche daneben ohnehin für sich sprechen.
    strecke(bild, 298, 188, 298, 836, 22, KONTUR)

    # Das Bild auf dem Deckel: ein dunkles Fenster, darin Berg und Sonne.
    # Der Grund scheint hier NICHT durch — ein Fenster in der Konturfarbe
    # steht ruhiger als eines, durch das der Verlauf läuft.
    rundeck(bild, 556, 424, 182, 158, 14, KONTUR)
    flaeche(bild, [(414, 522), (552, 370), (691, 522)], WEISS)
    kreis(bild, 640, 351, 43, WEISS)

    # Zwei Striche als Bildunterschrift. Bei vierzig Bildpunkten
    # verschwinden sie, und das schadet nichts: Sie sind die Zugabe, nicht
    # die Auskunft.
    strecke(bild, 400, 664, 712, 664, 26, KONTUR)
    strecke(bild, 400, 740, 616, 740, 26, KONTUR)

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
