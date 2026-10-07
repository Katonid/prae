#!/usr/bin/env python3
"""Erzeugt die App-Icons des Rufnummer-Detektivs (SVG und PNG), ohne fremde
Bibliotheken.

Motiv: eine weiße Lupe auf blauem Grund, im Glas die neun Punkte einer
Telefontastatur.

Gezeichnet wird mit dreifacher Überabtastung, damit die Rundungen glatt sind.
PNG-Schreiber und maskierbare Fassung stammen aus
container-finder/scripts/icons-erzeugen.py.

Aufruf:  python3 scripts/icons-erzeugen.py
"""

import math
import struct
import zlib
from pathlib import Path

HIER = Path(__file__).resolve().parent
AUS = HIER.parent / 'icons'
UEBER = 3  # Überabtastung je Achse

GRUND_OBEN = (22, 52, 120)
GRUND_UNTEN = (40, 96, 200)
WEISS = (255, 255, 255)

# Geometrie im 512er-Raster
GLAS_X, GLAS_Y = 222, 222
RING_AUSSEN, RING_INNEN = 136, 102
GRIFF_A = (322, 322)
GRIFF_B = (412, 412)
GRIFF_HALB = 28
PUNKT_R = 13
PUNKT_ABSTAND = 42


def mische(a, b, t):
    t = min(1.0, max(0.0, t))
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def abstand_strecke(x, y, a, b):
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    t = max(0.0, min(1.0, ((x - ax) * dx + (y - ay) * dy) / (dx * dx + dy * dy)))
    return math.hypot(x - (ax + t * dx), y - (ay + t * dy))


def punkte():
    for zeile in (-1, 0, 1):
        for spalte in (-1, 0, 1):
            yield GLAS_X + spalte * PUNKT_ABSTAND, GLAS_Y + zeile * PUNKT_ABSTAND


def ist_weiss(x, y):
    r = math.hypot(x - GLAS_X, y - GLAS_Y)
    if RING_INNEN <= r <= RING_AUSSEN:
        return True
    if r > RING_AUSSEN and abstand_strecke(x, y, GRIFF_A, GRIFF_B) <= GRIFF_HALB:
        return True
    return any(math.hypot(x - px, y - py) <= PUNKT_R for px, py in punkte())


def farbe_an(px, py, groesse):
    x = px * 512.0 / groesse
    y = py * 512.0 / groesse
    if ist_weiss(x, y):
        return WEISS
    return mische(GRUND_OBEN, GRUND_UNTEN, (x + y) / 1024.0)


def bild(groesse):
    fein = groesse * UEBER
    zeilen = []
    for py in range(groesse):
        zeile = bytearray()
        for px in range(groesse):
            summe = [0.0, 0.0, 0.0]
            for sy in range(UEBER):
                for sx in range(UEBER):
                    farbe = farbe_an(px * UEBER + sx, py * UEBER + sy, fein)
                    for i in range(3):
                        summe[i] += farbe[i]
            teiler = UEBER * UEBER
            zeile += bytes(int(round(summe[i] / teiler)) for i in range(3))
        zeilen.append(bytes(zeile))
    return zeilen


def png_schreiben(pfad, groesse, zeilen):
    """Schreibt ein PNG vom Farbtyp 2 — also OHNE Alphakanal.

    Mit Alphakanal legt iOS das Homescreen-Icon auf Schwarz, und mancher
    Android-Starter zeigt gar keines.
    """
    roh = b''.join(b'\x00' + zeile for zeile in zeilen)

    def stueck(art, daten):
        return (struct.pack('>I', len(daten)) + art + daten
                + struct.pack('>I', zlib.crc32(art + daten) & 0xffffffff))

    kopf = struct.pack('>IIBBBBB', groesse, groesse, 8, 2, 0, 0, 0)
    pfad.write_bytes(
        b'\x89PNG\r\n\x1a\n'
        + stueck(b'IHDR', kopf)
        + stueck(b'IDAT', zlib.compress(roh, 9))
        + stueck(b'IEND', b'')
    )


def svg_schreiben(pfad):
    ring_mitte = (RING_AUSSEN + RING_INNEN) / 2
    ring_breite = RING_AUSSEN - RING_INNEN
    kreise = ''.join(f'<circle cx="{x}" cy="{y}" r="{PUNKT_R}"/>' for x, y in punkte())
    pfad.write_text(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">'
        '<defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1">'
        f'<stop offset="0" stop-color="rgb{GRUND_OBEN}"/>'
        f'<stop offset="1" stop-color="rgb{GRUND_UNTEN}"/></linearGradient></defs>'
        '<rect width="512" height="512" rx="112" fill="url(#g)"/>'
        f'<line x1="{GRIFF_A[0]}" y1="{GRIFF_A[1]}" x2="{GRIFF_B[0]}" y2="{GRIFF_B[1]}" '
        f'stroke="#fff" stroke-width="{2 * GRIFF_HALB}" stroke-linecap="round"/>'
        f'<circle cx="{GLAS_X}" cy="{GLAS_Y}" r="{ring_mitte}" fill="none" '
        f'stroke="#fff" stroke-width="{ring_breite}"/>'
        f'<g fill="#fff">{kreise}</g>'
        '</svg>\n',
        encoding='utf-8',
    )


def maskierbar(groesse, rand_anteil=0.125):
    """Dasselbe Motiv mit Luft am Rand.

    Ein maskierbares Icon wird je nach Android-Starter zum Kreis, zum Quadrat
    oder zum Tropfen beschnitten. Ohne den Rand fehlten dem Blatt die Ecken.
    """
    gross = bild(groesse)
    rand = int(groesse * rand_anteil)
    innen = groesse - 2 * rand
    verkleinert = []
    for y in range(innen):
        quelle = gross[int(y * groesse / innen)]
        zeile = bytearray()
        for x in range(innen):
            stelle = int(x * groesse / innen) * 3
            zeile += quelle[stelle:stelle + 3]
        verkleinert.append(bytes(zeile))
    grundfarbe = bytes(GRUND_OBEN)
    voll = []
    for y in range(groesse):
        if y < rand or y >= groesse - rand:
            voll.append(grundfarbe * groesse)
        else:
            voll.append(grundfarbe * rand + verkleinert[y - rand] + grundfarbe * rand)
    return voll


# Welche Größen gebraucht werden und wofür:
#
#   32               Reiterleiste im Browser.
#   120/152/167/180  iOS. Für den Homescreen liest iOS das Manifest NICHT
#                    zuverlässig — es nimmt `apple-touch-icon`. Fehlt ein
#                    passendes, zeigt es einen Schnappschuss der Seite.
#   192/512          das Mindestmaß, das Chrome für „Installieren" verlangt.
#   256              damit Android-Starter nicht hochskalieren müssen.
GROESSEN = (32, 120, 152, 167, 180, 192, 256, 512)


def main():
    AUS.mkdir(parents=True, exist_ok=True)
    svg_schreiben(AUS / 'icon.svg')
    for groesse in GROESSEN:
        png_schreiben(AUS / f'icon-{groesse}.png', groesse, bild(groesse))
    for groesse in (192, 512):
        png_schreiben(AUS / f'icon-{groesse}-maskable.png', groesse, maskierbar(groesse))
    print('Icons geschrieben nach', AUS)


if __name__ == '__main__':
    main()
