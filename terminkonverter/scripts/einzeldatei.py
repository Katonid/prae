#!/usr/bin/env python3
"""Baut die App zu EINER HTML-Datei zusammen, die per Doppelklick läuft.

Warum überhaupt: Die App besteht aus ES-Modulen, und die weist jeder Browser
ab, wenn die Seite über file:// geöffnet wird. Für den Betrieb auf einem
Rechner ohne Webserver — Windows-PC, USB-Stick, Mailanhang — wird deshalb
alles in eine Datei gelegt: Stil, Zeichen und die sieben Module.

Jedes Modul bekommt dabei seinen eigenen Geltungsbereich (eine sofort
aufgerufene Funktion) und gibt seine Ausfuhren an ein gemeinsames Objekt
weiter. Ein blosses Aneinanderhängen ginge nicht: `zwei` steht sowohl in
ics.js als auch in app.js, und zweimal derselbe `const`-Name im selben
Bereich ist ein Syntaxfehler.

Aufruf:  python3 scripts/einzeldatei.py
"""

import re
from pathlib import Path

HIER = Path(__file__).resolve().parent
WURZEL = HIER.parent
ZIEL = WURZEL / 'einzeldatei.html'

# Reihenfolge = Abhängigkeitsreihenfolge; app.js zuletzt.
MODULE = ['xml.js', 'zip.js', 'xlsx.js', 'docx.js', 'termine.js', 'ics.js', 'app.js']

AUSFUHR = re.compile(r'^export\s+(async\s+function|function|const|let|class)\s+([A-Za-z_$][\w$]*)',
                     re.MULTILINE)
EINFUHR = re.compile(r'^import\s*\{([^}]*)\}\s*from\s*[\'"][^\'"]+[\'"];\s*$', re.MULTILINE)


def modul(pfad):
    text = pfad.read_text(encoding='utf-8')
    namen = [treffer.group(2) for treffer in AUSFUHR.finditer(text)]
    text = EINFUHR.sub(lambda t: 'const {' + t.group(1) + '} = TEILE;', text)
    text = re.sub(r'^export\s+', '', text, flags=re.MULTILINE)
    weitergabe = ''.join(f'\n  TEILE.{name} = {name};' for name in namen)
    return f'\n/* ---- {pfad.name} ---- */\n(function () {{\n{text}{weitergabe}\n}})();\n'


def main():
    html = (WURZEL / 'index.html').read_text(encoding='utf-8')
    css = (WURZEL / 'css' / 'style.css').read_text(encoding='utf-8')
    zeichen = (WURZEL / 'icons' / 'icon.svg').read_text(encoding='utf-8').strip()

    quelltext = 'const TEILE = {};\n' + ''.join(modul(WURZEL / 'js' / name) for name in MODULE)

    # Alles, was eine Datei daneben bräuchte, fliegt raus: Manifest, Service
    # Worker und die PNG-Zeichen. Übrig bleibt das SVG als Datenadresse.
    html = re.sub(r'\n *<link rel="(icon|manifest|apple-touch-icon)"[^>]*>', '', html)
    html = html.replace('<link rel="stylesheet" href="./css/style.css" />',
                        '<link rel="icon" href="data:image/svg+xml,'
                        + zeichen.replace('#', '%23').replace('"', "'").replace('\n', '')
                        + '" />\n    <style>\n' + css + '\n    </style>')
    html = html.replace('<script type="module" src="./js/app.js"></script>',
                        '<script>\n' + quelltext + '\n    </script>')
    # Der Verweis auf die Einzeldatei ist IN der Einzeldatei sinnlos.
    html = re.sub(
        r' *<li><strong>Ganz ohne Netz.*?</li>\n',
        '          <li><strong>Diese Datei ist die Einzeldatei</strong> — sie '
        'enthält die ganze App und braucht weder Netz noch Webserver. '
        'Kopieren, mitnehmen, per Doppelklick öffnen.</li>\n',
        html, flags=re.DOTALL)

    ZIEL.write_text(html, encoding='utf-8')
    print(f'{ZIEL} geschrieben ({ZIEL.stat().st_size // 1024} KB)')


if __name__ == '__main__':
    main()
