#!/usr/bin/env python3
"""Erzeugt die App-Icons des Container-Finders (SVG und PNG), ohne fremde
Bibliotheken.

Motiv: eine weiße Kartennadel auf grünem Grund, im Kopf der Nadel ein
Kreis halb in Glasgrün, halb in Papierblau — genau die zwei Farben, mit denen
die App die Container auf der Karte markiert.

Gezeichnet wird mit dreifacher Überabtastung, damit die Rundungen glatt sind.
Der PNG-Schreiber und die maskierbare Fassung stammen aus
textauszug/scripts/generate-icons.py.

Aufruf:  python3 scripts/icons-erzeugen.py
"""

import math
import struct
import zlib
from pathlib import Path

HIER = Path(__file__).resolve().parent
AUS = HIER.parent / 'icons'
UEBER = 3  # Überabtastung je Achse

GRUND_OBEN = (12, 84, 56)
GRUND_UNTEN = (22, 138, 88)
NADEL = (255, 255, 255)
GLAS = (22, 163, 74)
PAPIER = (37, 99, 235)

# Geometrie im 512er-Raster
KOPF_X, KOPF_Y, KOPF_R = 256, 214, 132
SPITZE_Y = 448
INNEN_R = 72
_D = SPITZE_Y - KOPF_Y
TAN = KOPF_R / math.sqrt(_D * _D - KOPF_R * KOPF_R)
BERUEHR_Y = KOPF_Y + KOPF_R * KOPF_R / _D   # dort gehen Kreis und Spitze ineinander über


def mische(a, b, t):
    t = min(1.0, max(0.0, t))
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def in_nadel(x, y):
    if (x - KOPF_X) ** 2 + (y - KOPF_Y) ** 2 <= KOPF_R ** 2:
        return True
    return BERUEHR_Y <= y <= SPITZE_Y and abs(x - KOPF_X) <= (SPITZE_Y - y) * TAN


def farbe_an(px, py, groesse):
    x = px * 512.0 / groesse
    y = py * 512.0 / groesse
    farbe = mische(GRUND_OBEN, GRUND_UNTEN, (x + y) / 1024.0)
    if in_nadel(x, y):
        farbe = NADEL
        if (x - KOPF_X) ** 2 + (y - KOPF_Y) ** 2 <= INNEN_R ** 2:
            farbe = GLAS if x < KOPF_X else PAPIER
    return farbe


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
    bx = (SPITZE_Y - BERUEHR_Y) * TAN
    pfad.write_text(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">'
        '<defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1">'
        f'<stop offset="0" stop-color="rgb{GRUND_OBEN}"/>'
        f'<stop offset="1" stop-color="rgb{GRUND_UNTEN}"/></linearGradient></defs>'
        '<rect width="512" height="512" rx="112" fill="url(#g)"/>'
        f'<path d="M{KOPF_X} {SPITZE_Y} L{KOPF_X - bx:.1f} {BERUEHR_Y:.1f} '
        f'A{KOPF_R} {KOPF_R} 0 1 1 {KOPF_X + bx:.1f} {BERUEHR_Y:.1f} Z" fill="rgb{NADEL}"/>'
        f'<path d="M{KOPF_X} {KOPF_Y - INNEN_R} A{INNEN_R} {INNEN_R} 0 0 0 {KOPF_X} {KOPF_Y + INNEN_R} Z" fill="rgb{GLAS}"/>'
        f'<path d="M{KOPF_X} {KOPF_Y - INNEN_R} A{INNEN_R} {INNEN_R} 0 0 1 {KOPF_X} {KOPF_Y + INNEN_R} Z" fill="rgb{PAPIER}"/>'
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
