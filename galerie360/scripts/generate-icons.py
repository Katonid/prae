#!/usr/bin/env python3
"""Zeichnet die App-Symbole (PNG) nach icons/icon.svg — für Home-Bildschirm und Manifest.
iOS nimmt für „Zum Home-Bildschirm" nur PNG (apple-touch-icon), kein SVG.

Aufruf:  python3 scripts/generate-icons.py
"""
from pathlib import Path
from PIL import Image, ImageDraw

ZIEL = Path(__file__).resolve().parent.parent / 'icons'


def symbol(groesse, rund=True):
    f = 8  # vierfach zeichnen, dann verkleinern = glatte Kanten
    n = groesse * f
    im = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    blau = (29, 78, 216, 255)
    if rund:
        d.rounded_rectangle([0, 0, n - 1, n - 1], radius=n * 14 // 64, fill=blau)
    else:
        d.rectangle([0, 0, n, n], fill=blau)  # iOS rundet selbst ab
    m = n / 2
    s = n / 64
    d.ellipse([m - 19 * s, m - 19 * s, m + 19 * s, m + 19 * s], outline='white', width=round(4 * s))
    d.ellipse([m - 8 * s, m - 19 * s, m + 8 * s, m + 19 * s], outline='white', width=round(3 * s))
    d.line([m - 19 * s, m, m + 19 * s, m], fill='white', width=round(3 * s))
    return im.resize((groesse, groesse), Image.LANCZOS)


for g in (192, 512):
    symbol(g).save(ZIEL / f'icon-{g}.png')
symbol(180, rund=False).convert('RGB').save(ZIEL / 'icon-180.png')
print('Symbole geschrieben:', ', '.join(p.name for p in sorted(ZIEL.glob('*.png'))))
