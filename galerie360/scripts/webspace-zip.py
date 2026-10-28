#!/usr/bin/env python3
"""Baut das ZIP mit allen Dateien, die auf den Webspace gehören.

Ansage des Nutzers (10/2026): Zu JEDER Arbeitseinheit gehört dieses ZIP —
er lädt es per FTP hoch und will sich nichts zusammensuchen.

Inhalt: der Generator (ohne Testskripte und Projektnotizen) im Ordner
galerie360/, dazu LIESMICH.txt (aus scripts/LIESMICH-webspace.txt) und die
Einzeldatei mit örtlichem Verweis auf die Anleitung. Gebaut wird aus einem
Git-Stand (Vorgabe HEAD), nicht aus dem Arbeitsordner — so landet nie
eine halbfertige Änderung im ZIP.

Aufruf:  python3 scripts/webspace-zip.py [ausgabeordner] [git-stand]
Ergebnis: <ausgabeordner>/galerie360-webspace-<fassung>.zip
"""
import io
import re
import subprocess
import sys
import tarfile
import zipfile
from pathlib import Path

PROJEKT = Path(__file__).resolve().parent.parent
WEG = ('galerie360/scripts/', 'galerie360/CLAUDE.md', 'galerie360/README.md')


def main():
    ziel = Path(sys.argv[1] if len(sys.argv) > 1 else '.').resolve()
    stand = sys.argv[2] if len(sys.argv) > 2 else 'HEAD'
    roh = subprocess.run(['git', 'archive', '--format=tar', stand, 'galerie360'], cwd=PROJEKT.parent,
                         check=True, capture_output=True).stdout
    dateien = {}
    with tarfile.open(fileobj=io.BytesIO(roh)) as tar:
        for t in tar.getmembers():
            if t.isfile() and not t.name.startswith(WEG):
                dateien[t.name] = tar.extractfile(t).read()

    app = dateien['galerie360/js/app.js'].decode()
    fassung = re.search(r"const FASSUNG = '([\d.]+)'", app).group(1)
    betrachter = re.search(r"const FASSUNG = '([\d.]+)'", dateien['galerie360/galerie/galerie.js'].decode()).group(1)
    if fassung != betrachter:
        sys.exit(f'FASSUNG passt nicht zusammen: js/app.js {fassung}, galerie/galerie.js {betrachter}')

    # Alles, was der Service Worker vorhält, muss auch im Paket sein — sonst scheitert die Installation am iPad.
    sw = dateien['galerie360/sw.js'].decode()
    for pfad in re.findall(r"'\./([^']+)'", sw):
        if 'galerie360/' + pfad not in dateien:
            sys.exit('sw.js nennt ' + pfad + ', die Datei fehlt im Paket')

    einzel = 'galerie360/galerie360-generator.html'
    dateien[einzel] = dateien[einzel].replace(
        b'href="https://katonid.github.io/prae/galerie360/anleitung.html"', b'href="./anleitung.html"')
    liesmich = (PROJEKT / 'scripts' / 'LIESMICH-webspace.txt').read_text(encoding='utf-8').replace('{FASSUNG}', fassung)
    dateien['galerie360/LIESMICH.txt'] = liesmich.encode()

    ziel.mkdir(parents=True, exist_ok=True)
    zip_pfad = ziel / f'galerie360-webspace-{fassung}.zip'
    with zipfile.ZipFile(zip_pfad, 'w', zipfile.ZIP_DEFLATED) as z:
        for name in sorted(dateien):
            z.writestr(name, dateien[name])
    with zipfile.ZipFile(zip_pfad) as z:
        if z.testzip() is not None:
            sys.exit('ZIP beschädigt')
    print(f'{zip_pfad} ({zip_pfad.stat().st_size // 1024} KB, {len(dateien)} Dateien, Fassung {fassung}, Stand {stand})')


if __name__ == '__main__':
    main()
