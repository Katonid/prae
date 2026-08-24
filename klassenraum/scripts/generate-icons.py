#!/usr/bin/env python3
"""Erzeugt die App-Icons (PNG) ohne externe Bibliotheken."""

import struct
import zlib
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / 'icons'
BG = (79, 70, 229)
BOARD = (255, 255, 255)
DOTS = [(239, 68, 68), (250, 204, 21), (34, 197, 94)]


def rounded_rect(px, py, x0, y0, x1, y1, radius):
    if px < x0 or px > x1 or py < y0 or py > y1:
        return False
    cx = min(max(px, x0 + radius), x1 - radius)
    cy = min(max(py, y0 + radius), y1 - radius)
    return (px - cx) ** 2 + (py - cy) ** 2 <= radius * radius


def circle(px, py, cx, cy, r):
    return (px - cx) ** 2 + (py - cy) ** 2 <= r * r


def render(size, padding_ratio):
    pad = size * padding_ratio
    inner = size - 2 * pad
    board_x0 = pad + inner * 0.16
    board_x1 = pad + inner * 0.84
    board_y0 = pad + inner * 0.22
    board_y1 = pad + inner * 0.70
    dot_r = inner * 0.062
    dot_y = pad + inner * 0.46
    dot_xs = [pad + inner * (0.32 + step * 0.18) for step in range(3)]

    rows = bytearray()
    for y in range(size):
        rows.append(0)
        for x in range(size):
            color = (15, 23, 42) if padding_ratio > 0.05 else BG
            if rounded_rect(x, y, pad * 0.35, pad * 0.35, size - pad * 0.35, size - pad * 0.35, size * 0.22):
                color = BG
            if rounded_rect(x, y, board_x0, board_y0, board_x1, board_y1, inner * 0.06):
                color = BOARD
                for index, dot_x in enumerate(dot_xs):
                    if circle(x, y, dot_x, dot_y, dot_r):
                        color = DOTS[index]
            rows.extend(color)
    return bytes(rows)


def write_png(path, size, padding_ratio):
    raw = render(size, padding_ratio)

    def chunk(tag, data):
        return (struct.pack('>I', len(data)) + tag + data
                + struct.pack('>I', zlib.crc32(tag + data) & 0xFFFFFFFF))

    header = struct.pack('>IIBBBBB', size, size, 8, 2, 0, 0, 0)
    png = (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', header)
           + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b''))
    path.write_bytes(png)
    print(f'{path.name}: {len(png)} Bytes')


if __name__ == '__main__':
    OUT.mkdir(parents=True, exist_ok=True)
    write_png(OUT / 'icon-180.png', 180, 0.03)
    write_png(OUT / 'icon-192.png', 192, 0.03)
    write_png(OUT / 'icon-512.png', 512, 0.03)
    write_png(OUT / 'icon-512-maskable.png', 512, 0.12)
