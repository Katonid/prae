#!/usr/bin/env python3
"""Baut den Generator zu EINER HTML-Datei zusammen, die per Doppelklick läuft.

Für den Betrieb ohne Netz: galerie360-generator.html herunterladen, in
Chrome oder Edge öffnen, fertig. Darin steckt alles — Stil, Programm und
der Quelltext des Betrachters, den der Generator in jede Galerie kopiert
(über file:// kann er ihn nicht nachladen, deshalb liegt er als Text in
window.G360_QUELLTEXT bei).

Aufruf:  python3 scripts/einzeldatei.py
"""

import json
import re
from pathlib import Path

WURZEL = Path(__file__).resolve().parent.parent
ZIEL = WURZEL / 'galerie360-generator.html'
SKRIPTE = ['galerie/galerie.js', 'js/medien.js', 'js/speicher.js', 'js/export.js', 'js/app.js']


def lies(pfad):
    return (WURZEL / pfad).read_text(encoding='utf-8')


def sicher(js):
    # Ein „</script" mitten im Quelltext würde den Block vorzeitig beenden.
    return js.replace('</script', '<\\/script')


def main():
    html = lies('index.html')
    zeichen = lies('icons/icon.svg').strip()
    css = lies('galerie/galerie.css') + '\n' + lies('css/generator.css')
    quelltext = json.dumps({'js': lies('galerie/galerie.js'), 'css': lies('galerie/galerie.css')}, ensure_ascii=False)

    html = html.replace('<link rel="icon" type="image/svg+xml" href="./icons/icon.svg" />',
                        '<link rel="icon" href="data:image/svg+xml,'
                        + zeichen.replace('#', '%23').replace('"', "'") + '" />')
    html = html.replace('<img src="./icons/icon.svg"',
                        '<img src="data:image/svg+xml,' + zeichen.replace('#', '%23').replace('"', "'") + '"')
    html = html.replace('    <link rel="stylesheet" href="./galerie/galerie.css" />\n', '')
    html = html.replace('<link rel="stylesheet" href="./css/generator.css" />', '<style>\n' + css + '\n    </style>')
    html = re.sub(r'\n *<script src="\./[^"]+"></script>', '', html)
    teile = ['window.G360_QUELLTEXT = ' + quelltext.replace('</', '<\\/') + ';']
    teile += [sicher(lies(s)) for s in SKRIPTE]
    html = html.replace('  </body>', '    <script>\n' + '\n'.join(teile) + '\n    </script>\n  </body>')
    # Die Anleitung liegt neben der Online-Fassung; offline auf sie verweisen.
    html = html.replace('href="./anleitung.html"', 'href="https://katonid.github.io/prae/galerie360/anleitung.html"')
    html = html.replace('<a class="marke" href="./"', '<a class="marke" href="#"')
    ZIEL.write_text(html, encoding='utf-8')
    print(f'{ZIEL} geschrieben ({ZIEL.stat().st_size // 1024} KB)')


if __name__ == '__main__':
    main()
