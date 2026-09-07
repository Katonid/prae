#!/usr/bin/env python3
"""Erzeugt die App-Icons des Terminkonverters (SVG und PNG), ohne fremde
Bibliotheken.

Motiv: ein Kalenderblatt mit zwei Ringen und blauem Kopf, darauf ein kräftiger
Haken — dasselbe Bild wie das Zeichen in der Reiterleiste, damit die App auf
dem Homescreen und im Browser gleich aussieht. Der Haken ist bernsteinfarben:
Auf dem weißen Blatt ist er auch bei 40 Punkten Kantenlänge noch zu erkennen,
ein blauer verschwämme mit Kopf und Grund.

Gezeichnet wird mit dreifacher Überabtastung, damit die Rundungen glatt sind.

Aufruf:  python3 scripts/generate-icons.py
"""

import struct
import zlib
from pathlib import Path

HIER = Path(__file__).resolve().parent
AUS = HIER.parent / 'icons'
UEBER = 3  # Überabtastung je Achse

GRUND_OBEN = (37, 84, 209)
GRUND_UNTEN = (56, 130, 246)
BLATT = (255, 255, 255)
KOPF = (27, 63, 160)
RING = (226, 232, 240)
HAKEN = (245, 158, 11)

# Geometrie im 512er-Raster
BLATT_KASTEN = (66, 128, 446, 452, 40)   # x0, y0, x1, y1, Radius
KOPF_UNTEN = 214
RINGE = ((146, 84, 186, 160, 20), (326, 84, 366, 160, 20))
HAKEN_A = (162, 318)
HAKEN_B = (226, 380)
HAKEN_C = (356, 250)
HAKEN_DICKE = 27


def mische(a, b, t):
    t = min(1.0, max(0.0, t))
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def in_rundeck(px, py, x0, y0, x1, y1, radius):
    if px < x0 or px > x1 or py < y0 or py > y1:
        return False
    cx = min(max(px, x0 + radius), x1 - radius)
    cy = min(max(py, y0 + radius), y1 - radius)
    if x0 + radius <= px <= x1 - radius or y0 + radius <= py <= y1 - radius:
        return True
    return (px - cx) ** 2 + (py - cy) ** 2 <= radius ** 2


def auf_strecke(px, py, ax, ay, bx, by):
    """Abstand eines Punktes zur Strecke a→b."""
    dx, dy = bx - ax, by - ay
    laenge = dx * dx + dy * dy
    if laenge == 0:
        return ((px - ax) ** 2 + (py - ay) ** 2) ** 0.5
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / laenge))
    nx, ny = ax + t * dx, ay + t * dy
    return ((px - nx) ** 2 + (py - ny) ** 2) ** 0.5


def farbe_an(px, py, groesse):
    """Die Farbe eines Punktes im 512er-Raster."""
    x = px * 512.0 / groesse
    y = py * 512.0 / groesse

    # Grund: Verlauf innerhalb EINER Farbfamilie; die Ecken schneidet das
    # Betriebssystem selbst zu.
    farbe = mische(GRUND_OBEN, GRUND_UNTEN, (x + y) / 1024.0)

    if in_rundeck(x, y, *BLATT_KASTEN):
        farbe = KOPF if y <= KOPF_UNTEN else BLATT

    for ring in RINGE:
        if in_rundeck(x, y, *ring):
            farbe = RING

    if y > KOPF_UNTEN and auf_strecke(x, y, *HAKEN_A, *HAKEN_B) <= HAKEN_DICKE:
        farbe = HAKEN
    if y > KOPF_UNTEN and auf_strecke(x, y, *HAKEN_B, *HAKEN_C) <= HAKEN_DICKE:
        farbe = HAKEN

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
    x0, y0, x1, y1, r = BLATT_KASTEN
    ringe = ''.join(
        f'<rect x="{a}" y="{b}" width="{c - a}" height="{d - b}" rx="{rr}" '
        f'fill="rgb{RING}"/>'
        for a, b, c, d, rr in RINGE
    )
    pfad.write_text(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">'
        '<defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1">'
        f'<stop offset="0" stop-color="rgb{GRUND_OBEN}"/>'
        f'<stop offset="1" stop-color="rgb{GRUND_UNTEN}"/></linearGradient>'
        '<clipPath id="blatt">'
        f'<rect x="{x0}" y="{y0}" width="{x1 - x0}" height="{y1 - y0}" rx="{r}"/>'
        '</clipPath></defs>'
        '<rect width="512" height="512" rx="112" fill="url(#g)"/>'
        f'<rect x="{x0}" y="{y0}" width="{x1 - x0}" height="{y1 - y0}" rx="{r}" '
        f'fill="rgb{BLATT}"/>'
        f'<rect x="{x0}" y="{y0}" width="{x1 - x0}" height="{KOPF_UNTEN - y0}" '
        f'fill="rgb{KOPF}" clip-path="url(#blatt)"/>'
        + ringe +
        f'<path d="M{HAKEN_A[0]} {HAKEN_A[1]} L{HAKEN_B[0]} {HAKEN_B[1]} '
        f'L{HAKEN_C[0]} {HAKEN_C[1]}" fill="none" stroke="rgb{HAKEN}" '
        f'stroke-width="{HAKEN_DICKE * 2}" stroke-linecap="round" '
        'stroke-linejoin="round"/>'
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
