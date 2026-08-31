#!/usr/bin/env python3
"""Erzeugt die App-Icons (SVG und PNG) ohne fremde Bibliotheken.

Motiv: ein Blatt Papier mit den drei Linien des Buchstabenhauses und einem
Wort darauf, dessen Buchstaben als Kästchen in Dach, Mitte und Keller stehen —
also genau das, was die Geheimschrift-Stufe zeigt. Ein Bleistift liegt quer
darüber.

Gezeichnet wird mit dreifacher Überabtastung, damit Rundungen glatt aussehen.

Aufruf:  python3 scripts/generate-icons.py
"""

import struct
import zlib
from pathlib import Path

HIER = Path(__file__).resolve().parent
AUS = HIER.parent / 'icons'
UEBER = 3  # Überabtastung je Achse

# Farben (0–255)
GRUND_OBEN = (99, 102, 241)
GRUND_UNTEN = (236, 72, 153)
BLATT = (255, 255, 255)
BLATT_RAND = (226, 232, 240)
LINIE = (203, 213, 225)
KASTEN = (20, 184, 166)
KASTEN_GROSS = (13, 148, 136)
STIFT_HOLZ = (250, 204, 21)
STIFT_SPITZE = (120, 53, 15)

# Geometrie im 512er-Raster
BLATT_KASTEN = (74, 96, 438, 416, 34)     # x0, y0, x1, y1, Radius
LINIEN_Y = (168, 222, 288, 342)           # Dach, Mitte oben, Mitte unten, Keller
LINKS, RECHTS = 116, 396

# Die Kästchen des Wortbildes: (x0, x1, y0, y1, gross)
# Zusammen ergibt das die Gestalt eines Wortes mit großem Anfang,
# Oberlänge, Mittelband und einer Unterlänge.
KAESTCHEN = [
    (124, 168, 168, 288, True),    # großer Buchstabe: Dach bis Mitte unten
    (180, 216, 190, 288, False),   # Oberlänge
    (228, 264, 222, 288, False),   # Mittelband
    (276, 312, 222, 342, False),   # Unterlänge
    (324, 360, 222, 288, False),   # Mittelband
]

STIFT = ((150, 402), (392, 330), 26)      # Anfang, Ende, halbe Breite


def mische(a, b, t):
    t = min(1.0, max(0.0, t))
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def ueber(grund, farbe, deckung):
    return tuple(grund[i] + (farbe[i] - grund[i]) * deckung for i in range(3))


def in_rundeck(px, py, x0, y0, x1, y1, radius):
    if px < x0 or px > x1 or py < y0 or py > y1:
        return False
    cx = min(max(px, x0 + radius), x1 - radius)
    cy = min(max(py, y0 + radius), y1 - radius)
    return (px - cx) ** 2 + (py - cy) ** 2 <= radius ** 2 or (
        x0 + radius <= px <= x1 - radius or y0 + radius <= py <= y1 - radius)


def auf_strecke(px, py, ax, ay, bx, by):
    """Abstand eines Punktes zur Strecke a→b."""
    dx, dy = bx - ax, by - ay
    laenge = dx * dx + dy * dy
    if laenge == 0:
        return ((px - ax) ** 2 + (py - ay) ** 2) ** 0.5, 0.0
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / laenge))
    nx, ny = ax + t * dx, ay + t * dy
    return ((px - nx) ** 2 + (py - ny) ** 2) ** 0.5, t


def farbe_an(px, py, groesse):
    """Die Farbe eines Punktes im 512er-Raster."""
    x = px * 512.0 / groesse
    y = py * 512.0 / groesse

    # Hintergrund: Verlauf mit abgerundeten Ecken (iOS schneidet selbst zu).
    farbe = mische(GRUND_OBEN, GRUND_UNTEN, (x + y) / 1024.0)

    if in_rundeck(x, y, *BLATT_KASTEN):
        farbe = BLATT
        # Blattrand
        rx0, ry0, rx1, ry1, rr = BLATT_KASTEN
        if not in_rundeck(x, y, rx0 + 4, ry0 + 4, rx1 - 4, ry1 - 4, rr - 4):
            farbe = BLATT_RAND

        for linie_y in LINIEN_Y:
            if abs(y - linie_y) <= 2 and LINKS - 8 <= x <= RECHTS + 8:
                farbe = LINIE

        for x0, x1, y0, y1, gross in KAESTCHEN:
            if in_rundeck(x, y, x0, y0, x1, y1, 8):
                farbe = KASTEN_GROSS if gross else KASTEN
                if not gross and not in_rundeck(x, y, x0 + 5, y0 + 5, x1 - 5, y1 - 5, 5):
                    farbe = KASTEN_GROSS

    (ax, ay), (bx, by), dicke = STIFT
    abstand, t = auf_strecke(x, y, ax, ay, bx, by)
    if abstand <= dicke * (1.0 - 0.82 * max(0.0, t - 0.86) / 0.14):
        farbe = STIFT_SPITZE if t > 0.86 else STIFT_HOLZ

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
            zeile += b'\xff'
        zeilen.append(bytes(zeile))
    return zeilen


def png_schreiben(pfad, groesse, zeilen):
    roh = b''.join(b'\x00' + zeile for zeile in zeilen)
    def stueck(art, daten):
        return (struct.pack('>I', len(daten)) + art + daten
                + struct.pack('>I', zlib.crc32(art + daten) & 0xffffffff))
    kopf = struct.pack('>IIBBBBB', groesse, groesse, 8, 6, 0, 0, 0)
    pfad.write_bytes(
        b'\x89PNG\r\n\x1a\n'
        + stueck(b'IHDR', kopf)
        + stueck(b'IDAT', zlib.compress(roh, 9))
        + stueck(b'IEND', b''))
    print(f'{pfad.name}  {groesse}×{groesse}')


SVG = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" role="img"
     aria-label="Wörterwerkstatt">
  <defs>
    <linearGradient id="g" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#6366f1"/>
      <stop offset="1" stop-color="#ec4899"/>
    </linearGradient>
  </defs>
  <rect width="512" height="512" rx="112" fill="url(#g)"/>
  <rect x="74" y="96" width="364" height="320" rx="34" fill="#fff"/>
  {linien}
  {kaesten}
  <path d="M150 402 L392 330" stroke="#facc15" stroke-width="52" stroke-linecap="round"/>
  <path d="M358 341 L392 330" stroke="#78350f" stroke-width="46" stroke-linecap="round"/>
</svg>
'''


def svg_schreiben(pfad):
    linien = '\n  '.join(
        f'<line x1="108" y1="{y}" x2="404" y2="{y}" stroke="#cbd5e1" stroke-width="4"/>'
        for y in LINIEN_Y)
    kaesten = '\n  '.join(
        f'<rect x="{x0}" y="{y0}" width="{x1 - x0}" height="{y1 - y0}" rx="8" '
        + (f'fill="#0d9488"/>' if gross else 'fill="rgba(20,184,166,.3)" stroke="#0d9488" stroke-width="6"/>')
        for x0, x1, y0, y1, gross in KAESTCHEN)
    pfad.write_text(SVG.format(linien=linien, kaesten=kaesten), encoding='utf-8')
    print(f'{pfad.name}')


def main():
    AUS.mkdir(parents=True, exist_ok=True)
    svg_schreiben(AUS / 'icon.svg')
    for groesse, name in ((180, 'icon-180.png'), (192, 'icon-192.png'), (512, 'icon-512.png')):
        png_schreiben(AUS / name, groesse, bild(groesse))
    # Maskierbar: dasselbe Motiv, aber mit Luft am Rand, damit Android nichts
    # Wichtiges abschneidet.
    print('icon-512-maskable.png wird aus icon-512 mit Rand gebaut …')
    gross = bild(512)
    rand = 64
    innen = 512 - 2 * rand
    verkleinert = []
    for y in range(innen):
        quelle = gross[int(y * 512 / innen)]
        zeile = bytearray()
        for x in range(innen):
            stelle = int(x * 512 / innen) * 4
            zeile += quelle[stelle:stelle + 4]
        verkleinert.append(bytes(zeile))
    grundfarbe = bytes((99, 102, 241, 255))
    voll = []
    for y in range(512):
        if y < rand or y >= 512 - rand:
            voll.append(grundfarbe * 512)
        else:
            voll.append(grundfarbe * rand + verkleinert[y - rand] + grundfarbe * rand)
    png_schreiben(AUS / 'icon-512-maskable.png', 512, voll)


if __name__ == '__main__':
    main()
