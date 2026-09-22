#!/usr/bin/env python3
"""Erzeugt das App-Symbol für das Urlaubstagebuch — reines Python, ohne
fremde Bibliotheken (wie die Symbolskripte der anderen Apps dieses Repos).

WARUM ES SEIT 1.0.20 ANDERS AUSSIEHT (Befund des Nutzers, 09/2026): „Das
Programm-Icon sieht von Weitem aus wie eine weiße Fläche mit einem Rand
drumherum."

Er hat recht, und der Grund ist am alten Entwurf abzulesen: Dort lag ein
aufgeschlagenes Buch in Papierweiß über drei Vierteln der Fläche, auf einem
dunklen Grund. Aus zehn Zentimetern sah man das Buch; auf einem Homescreen
misst ein Symbol vierzig Bildpunkte, und dann bleibt von Papier, Falz und
Lineatur nichts als eine helle Fläche mit dunklem Saum.

Ein Symbol hat bei dieser Größe **eine Farbe und eine Form**, mehr nicht —
so machen es die Apps mit derselben Aufgabe: Polarsteps eine Route, Karten
eine Nadel, Apple Books ein weißes Zeichen auf einem kräftigen Verlauf.
Hier ist es beides zusammen, und es sagt genau, was die App tut: ein Weg
mit Anfang und Ziel.

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

# Der Verlauf läuft DIAGONAL von warm nach tief: Ein senkrechter Verlauf
# sieht auf einem Homescreen wie ein Farbfeld aus, ein diagonaler hat eine
# Richtung. Die Farben sind so dunkel gewählt, dass Weiß darauf überall
# trägt — auf einem hellen Gelb täte es das nicht.
GRUND_A = (247, 148, 56)     # oben links, Abendsonne
GRUND_B = (176, 32, 86)      # unten rechts, tiefes Rot
WEISS = (255, 253, 250)
# Die Kontur unter dem Weiß. Sie ist keine Zierde: Der Verlauf ist oben
# links deutlich heller als unten rechts, und ohne sie verlöre die Linie
# dort an Halt. Dieselbe Überlegung wie bei den Linienzügen der
# Abfahrtstafel.
KONTUR = (104, 18, 52)


def mischen(a, b, anteil):
    anteil = max(0.0, min(1.0, anteil))
    return tuple(a[i] + (b[i] - a[i]) * anteil for i in range(3))


def grundfarbe(x, y):
    """Der Verlauf an dieser Stelle — diagonal von oben links nach unten
    rechts. Gebraucht wird er zweimal: für die Leinwand und für die Löcher
    in Nadel und Startpunkt, die den Grund wieder durchscheinen lassen."""
    return mischen(GRUND_A, GRUND_B, (x + y) / (2 * (GROESSE - 1)))


def leinwand():
    return [[list(grundfarbe(x, y)) for x in range(GROESSE)] for y in range(GROESSE)]


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


def kreis(bild, mx, my, radius, farbe=None):
    """Ein Kreis. Ohne Farbe wird der GRUND wiederhergestellt — so entsteht
    das Loch in der Nadel, ohne dass ein zweiter Verlauf gerechnet wird."""
    for y in range(max(0, int(my - radius - 2)), min(GROESSE, int(my + radius + 2))):
        for x in range(max(0, int(mx - radius - 2)), min(GROESSE, int(mx + radius + 2))):
            abstand = math.hypot(x + 0.5 - mx, y + 0.5 - my) - radius
            setzen(bild, x, y, farbe or grundfarbe(x, y), deckung_aus_abstand(abstand))


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


def feine_kurve(punkte, schritte=16):
    """Catmull-Rom durch die gegebenen Punkte. Eine Reisespur aus geraden
    Knicken sähe aus wie ein Diagramm und nicht wie ein Weg."""
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
    return fein


def kurve(bild, fein, breite, farbe):
    for i in range(len(fein) - 1):
        strecke(bild, fein[i][0], fein[i][1], fein[i + 1][0], fein[i + 1][1], breite, farbe)


def nadel(bild, mx, my, radius, spitze, farbe):
    """Die Kartennadel: ein Kopf und ein Auslauf zur Spitze.

    Der Auslauf wird zeilenweise gefüllt, die Breite nimmt mit einem Exponenten
    ab — linear ergäbe ein Dreieck, und ein Dreieck unter einem Kreis sieht aus
    wie ein Eis und nicht wie eine Nadel.
    """
    kreis(bild, mx, my, radius, farbe)
    hoehe = spitze - my
    for y in range(int(my), int(spitze) + 2):
        anteil = (y - my) / hoehe
        if anteil < 0:
            continue
        halb = radius * max(0.0, (1 - min(anteil, 1.0)) ** 0.62)
        for x in range(int(mx - halb - 2), int(mx + halb + 2)):
            deckung = max(0.0, min(1.0, halb - abs(x + 0.5 - mx) + 0.5))
            setzen(bild, x, y, farbe, deckung)


def bauen():
    bild = leinwand()

    # Der Weg. Er windet sich mit Absicht, statt gleichmäßig zu steigen:
    # Eine Linie, die nur nach rechts oben läuft, liest sich als Diagramm.
    # Alles bleibt innerhalb von 140 bis 884 — was näher an der Ecke liegt,
    # schneidet iOS mit seiner abgerundeten Maske weg.
    spur = [(232, 806), (338, 700), (262, 592), (416, 552), (536, 602), (648, 539)]
    fein = feine_kurve(spur)
    kurve(bild, fein, 74, KONTUR)
    kurve(bild, fein, 48, WEISS)

    # Das Ziel: eine Nadel, deren Spitze auf dem Ende des Weges steht.
    nadel(bild, 648, 300, 118, 539, KONTUR)
    nadel(bild, 648, 300, 104, 528, WEISS)
    kreis(bild, 648, 300, 41)

    # Der Anfang: ein Punkt mit Loch, damit er zur Nadel gehört und nicht
    # wie ein abgeschnittenes Linienende aussieht.
    kreis(bild, 232, 806, 62, KONTUR)
    kreis(bild, 232, 806, 50, WEISS)
    kreis(bild, 232, 806, 21)

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
