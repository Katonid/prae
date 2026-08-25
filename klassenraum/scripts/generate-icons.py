#!/usr/bin/env python3
"""Erzeugt die App-Icons (PNG) ohne externe Bibliotheken.

Motiv: eine grüne Tafel, darauf eine helle Karte mit Uhr und Ampelpunkten —
die drei Dinge, die im Unterricht am häufigsten gebraucht werden. Gezeichnet
wird mit dreifacher Überabtastung, damit Rundungen glatt aussehen.

Aufruf:  python3 scripts/generate-icons.py
"""

import struct
import zlib
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / 'icons'
SS = 3  # Überabtastung je Achse

# Farben (0–255)
GRUEN_HELL = (19, 122, 99)
GRUEN_DUNKEL = (10, 59, 51)
KARTE_OBEN = (255, 255, 255)
KARTE_UNTEN = (238, 242, 255)
TINTE = (30, 41, 59)
ROT = (239, 68, 68)
GELB = (250, 204, 21)
GRUEN = (34, 197, 94)

# Geometrie im 512er-Raster (wie in icons/icon.svg)
CARD = (80, 132, 432, 380, 40)          # x0, y0, x1, y1, radius
CLOCK = (196, 256, 62, 18)              # Mittelpunkt, Radius, Strichstärke
HANDS = (((196, 212), (196, 256)), ((196, 256), (228, 276)))
DOTS = ((330, 196, ROT), (330, 258, GELB), (330, 320, GRUEN))
DOT_R = 26
CORNER = 115


def mix(a, b, t):
    t = min(1.0, max(0.0, t))
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def over(base, color, alpha):
    return tuple(base[i] + (color[i] - base[i]) * alpha for i in range(3))


def in_rounded(px, py, x0, y0, x1, y1, radius):
    if px < x0 or px > x1 or py < y0 or py > y1:
        return False
    cx = min(max(px, x0 + radius), x1 - radius)
    cy = min(max(py, y0 + radius), y1 - radius)
    return (px - cx) ** 2 + (py - cy) ** 2 <= radius * radius


def in_circle(px, py, cx, cy, r):
    return (px - cx) ** 2 + (py - cy) ** 2 <= r * r


def in_ring(px, py, cx, cy, r, width):
    d2 = (px - cx) ** 2 + (py - cy) ** 2
    return (r - width / 2) ** 2 <= d2 <= (r + width / 2) ** 2


def in_segment(px, py, a, b, width):
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    laenge = dx * dx + dy * dy
    t = 0.0 if laenge == 0 else ((px - ax) * dx + (py - ay) * dy) / laenge
    t = min(1.0, max(0.0, t))
    qx, qy = ax + t * dx, ay + t * dy
    return (px - qx) ** 2 + (py - qy) ** 2 <= (width / 2) ** 2


def farbe(px, py, ecken):
    """Farbe und Deckkraft eines Punktes im 512er-Raster."""
    rand = CORNER if ecken else 0
    # Außerhalb der abgerundeten Ecke bleibt der Punkt durchsichtig.
    if rand and not in_rounded(px, py, 0, 0, 512, 512, rand):
        return (0, 0, 0), 0.0
    grund = mix(GRUEN_HELL, GRUEN_DUNKEL, (px * 0.35 + py * 0.65) / 512)

    x0, y0, x1, y1, r = CARD

    # weicher Schatten unter der Karte
    for schritt in range(6):
        wachstum = 4 + schritt * 5
        if in_rounded(px, py, x0 - wachstum, y0 - wachstum + 14, x1 + wachstum, y1 + wachstum + 14, r + wachstum):
            grund = over(grund, (4, 18, 26), 0.06)

    if not in_rounded(px, py, x0, y0, x1, y1, r):
        return grund, 1.0

    karte = mix(KARTE_OBEN, KARTE_UNTEN, (py - y0) / (y1 - y0))

    cx, cy, cr, cw = CLOCK
    if in_ring(px, py, cx, cy, cr, cw):
        return TINTE, 1.0
    for a, b in HANDS:
        if in_segment(px, py, a, b, cw):
            return TINTE, 1.0
    for dx, dy, color in DOTS:
        if in_circle(px, py, dx, dy, DOT_R):
            return color, 1.0
    return karte, 1.0


def render(size, ecken=True, inhalt=1.0):
    rows = bytearray()
    schritt = 512 / (size * SS)
    for y in range(size):
        rows.append(0)
        for x in range(size):
            summe = [0.0, 0.0, 0.0]
            deckung = 0.0
            for sy in range(SS):
                for sx in range(SS):
                    px = (x * SS + sx + 0.5) * schritt
                    py = (y * SS + sy + 0.5) * schritt
                    if inhalt != 1.0:
                        px = 256 + (px - 256) / inhalt
                        py = 256 + (py - 256) / inhalt
                    teil, alpha = farbe(px, py, ecken)
                    deckung += alpha
                    for i in range(3):
                        summe[i] += teil[i] * alpha
            anzahl = SS * SS
            if deckung > 0:
                rows.extend(int(min(255, max(0, round(summe[i] / deckung)))) for i in range(3))
            else:
                rows.extend((0, 0, 0))
            rows.append(int(round(deckung / anzahl * 255)))
    return bytes(rows)


def write_png(path, size, ecken=True, inhalt=1.0):
    raw = render(size, ecken, inhalt)

    def chunk(tag, data):
        return (struct.pack('>I', len(data)) + tag + data
                + struct.pack('>I', zlib.crc32(tag + data) & 0xFFFFFFFF))

    header = struct.pack('>IIBBBBB', size, size, 8, 6, 0, 0, 0)
    png = (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', header)
           + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b''))
    path.write_bytes(png)
    print(f'{path.name}: {len(png)} Bytes')


def main():
    OUT.mkdir(exist_ok=True)
    # „any": mit eigenen runden Ecken
    write_png(OUT / 'icon-192.png', 192)
    write_png(OUT / 'icon-512.png', 512)
    # Apple rundet selbst — deshalb randlos, sonst blitzen dunkle Ecken durch.
    write_png(OUT / 'icon-180.png', 180, ecken=False)
    # „maskable": randlos und mit kleinerem Inhalt, damit runde Masken nichts abschneiden.
    write_png(OUT / 'icon-512-maskable.png', 512, ecken=False, inhalt=0.78)


if __name__ == '__main__':
    main()
