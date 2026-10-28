#!/usr/bin/env python3
"""Erzeugt die Symbolbibliothek des Hotspot-Editors aus den npm-Paketen
lucide-static (Icons, ISC) und emojibase-data (Emoji mit deutschen Namen, MIT).

Ergebnis (eingecheckt, nur der Generator lädt sie):
  vendor/lucide.js  — window.G360_LUCIDE = {n: {name: [[tag, {attr}]...]}, t: {name: "tags"}}
  vendor/emoji.js   — window.G360_EMOJI  = {g: [Gruppennamen], e: [[zeichen, name, stichwörter, gruppe]]}

In die exportierte Galerie kommen nur die tatsächlich benutzten Icons
(als Knotenliste im Hotspot), nie die ganze Bibliothek.

Aufruf:
  curl -sSO https://registry.npmjs.org/lucide-static/-/lucide-static-1.63.0.tgz
  curl -sSO https://registry.npmjs.org/emojibase-data/-/emojibase-data-18.0.0.tgz
  mkdir l e && tar xzf lucide-static-*.tgz -C l && tar xzf emojibase-data-*.tgz -C e
  python3 scripts/symbolbibliothek.py l/package e/package
"""
import json
import sys
from pathlib import Path

ZIEL = Path(__file__).resolve().parent.parent / 'vendor'


def lucide(paket):
    knoten = json.loads((paket / 'icon-nodes.json').read_text())
    tags = json.loads((paket / 'tags.json').read_text())
    version = json.loads((paket / 'package.json').read_text())['version']
    lizenz = (paket / 'LICENSE').read_text().strip()
    # Zahlen in Attributen bleiben Text — so baut der Betrachter sie unverändert ein.
    n = {name: [[t, {k: str(v) for k, v in a.items()}] for t, a in nodes] for name, nodes in sorted(knoten.items())}
    t = {name: ' '.join(tags.get(name, [])) for name in n}
    daten = json.dumps({'v': version, 'n': n, 't': t}, ensure_ascii=False, separators=(',', ':'))
    kopf = '/* Lucide ' + version + ' — https://lucide.dev\n' + '\n'.join(' * ' + z if z else ' *' for z in lizenz.splitlines()) + '\n */\n'
    (ZIEL / 'lucide.js').write_text(kopf + 'window.G360_LUCIDE=' + daten + ';\n', encoding='utf-8')
    return len(n)


def emoji(paket):
    daten = json.loads((paket / 'de' / 'data.json').read_text())
    gruppen = json.loads((paket / 'de' / 'messages.json').read_text())['groups']
    version = json.loads((paket / 'package.json').read_text())['version']
    namen = [g['message'] for g in sorted(gruppen, key=lambda g: g['order'])]
    liste = []
    for e in sorted((x for x in daten if 'group' in x and x['group'] != 2), key=lambda x: x['order']):
        liste.append([e['emoji'], e['label'], ' '.join(e.get('tags', [])), e['group']])
    kopf = ('/* Emoji-Namen und Stichwörter: emojibase-data ' + version + ' (MIT-Lizenz, https://emojibase.dev),\n'
            ' * Copyright (c) 2017-present Miles Johnson. Die Zeichen selbst zeichnet die Schrift des Geräts. */\n')
    (ZIEL / 'emoji.js').write_text(kopf + 'window.G360_EMOJI=' + json.dumps({'g': namen, 'e': liste}, ensure_ascii=False, separators=(',', ':')) + ';\n', encoding='utf-8')
    return len(liste)


if __name__ == '__main__':
    ZIEL.mkdir(exist_ok=True)
    print(lucide(Path(sys.argv[1])), 'Icons,', emoji(Path(sys.argv[2])), 'Emoji')
    for f in sorted(ZIEL.glob('*.js')):
        print(f.name, f.stat().st_size // 1024, 'KB')
