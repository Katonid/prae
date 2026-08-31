#!/usr/bin/env python3
"""Prüft den selbst gerechneten QR-Code (js/qr.js) gegen fremde Umsetzungen.

Warum das nötig ist: Ein QR-Code, bei dem ein einziges Modul falsch sitzt,
sieht für das Auge tadellos aus und wird von keiner Kamera gelesen. Genau das
ist beim Bau dieser Datei zweimal passiert (beide Male stand die
Format-Information um 90 Grad verdreht im Feld). Ohne eine Gegenprobe wäre es
erst aufgefallen, wenn eine Klasse vor dem Beamer steht.

Zwei unabhängige Prüfungen, beide mit Werkzeugen, die die App selbst NICHT
braucht und die deshalb nicht im Repo liegen:

  1. **Rücklesen** mit dem QR-Leser von OpenCV — kommt derselbe Text heraus?
     Das ist der Test, auf den es ankommt.
  2. **Modulvergleich** mit segno, aber nur dort, wo der Standard genau eine
     Lösung zulässt und die Maske nichts ändert: Suchmuster, Trennstreifen,
     Taktreihen, Ausrichtungsmuster, Fassungsangabe und die immer dunkle
     Stelle. Nicht verglichen werden die Datenfläche und die
     Format-Information — welches Füllzeichen nach dem Abschluss steht, lässt
     der Standard offen (segno füllt anders als diese Umsetzung, beides ist
     richtig), und aus verschiedenen Füllzeichen folgt eine andere beste
     Maske und damit eine andere Format-Information.

     Dass die Format-Information stimmt, prüft dafür Nummer 1 mit: Ein Leser,
     der die Maske aus ihr nicht richtig bekommt, liest gar nichts.

Aufruf:

    pip install segno opencv-python-headless numpy
    python3 scripts/qr-pruefen.py
"""

import json
import subprocess
import sys
from pathlib import Path

HIER = Path(__file__).resolve().parent
JS = HIER.parent / 'js' / 'qr.js'

FAELLE = [
    'A',
    'Hallo',
    'https://katonid.github.io/prae/woerterwerkstatt/',
    'https://katonid.github.io/prae/woerterwerkstatt/#/beitreten/ABC234',
    'https://katonid.github.io/prae/woerterwerkstatt/#/beitreten/ZZ9K3M',
    'Wörterwerkstatt — Lernwörter üben',
    'https://katonid.github.io/prae/woerterwerkstatt/#/beitreten/QWERTY'
    '?klasse=Die%20wilde%204b%20von%20Frau%20M%C3%BCller',
    'ä' * 60,
    'x' * 150,
]


def js_feld(text, stufe):
    quelle = (
        f'import {{ qrFeld }} from {json.dumps(str(JS))};'
        f'console.log(JSON.stringify(qrFeld({json.dumps(text)}, {{ stufe: {json.dumps(stufe)} }})));'
    )
    fertig = subprocess.run(
        ['node', '--input-type=module', '-e', quelle],
        capture_output=True, text=True, check=True,
    )
    return json.loads(fertig.stdout)


def als_bild(feld, rand=8, kante=20):
    import numpy as np
    groesse = len(feld)
    gesamt = groesse + 2 * rand
    bild = np.full((gesamt * kante, gesamt * kante), 255, np.uint8)
    for r, zeile in enumerate(feld):
        for c, wert in enumerate(zeile):
            if wert:
                bild[(r + rand) * kante:(r + rand + 1) * kante,
                     (c + rand) * kante:(c + rand + 1) * kante] = 0
    return bild


def feste_module(groesse, fassung):
    """Die Stellen, die der Standard eindeutig festlegt (ohne Datenfläche)."""
    orte = set()
    for zeile, spalte in ((0, 0), (0, groesse - 7), (groesse - 7, 0)):
        for dr in range(-1, 8):
            for dc in range(-1, 8):
                y, x = zeile + dr, spalte + dc
                if 0 <= y < groesse and 0 <= x < groesse:
                    orte.add((y, x))
    for i in range(groesse):
        orte.add((6, i))
        orte.add((i, 6))
    orte.add((groesse - 8, 8))  # die immer dunkle Stelle
    punkte = [[], [], [6, 18], [6, 22], [6, 26], [6, 30], [6, 34],
              [6, 22, 38], [6, 24, 42], [6, 26, 46], [6, 28, 50]][fassung]
    for zeile in punkte:
        for spalte in punkte:
            if (zeile, spalte) in {(6, 6), (6, punkte[-1]), (punkte[-1], 6)}:
                continue
            for dr in range(-2, 3):
                for dc in range(-2, 3):
                    orte.add((zeile + dr, spalte + dc))
    if fassung >= 7:
        for i in range(18):
            orte.add((i // 3, groesse - 11 + i % 3))
            orte.add((groesse - 11 + i % 3, i // 3))
    return orte


def main():
    try:
        import cv2  # noqa: F401
        import numpy  # noqa: F401
    except ImportError:
        print('OpenCV/numpy fehlen — bitte "pip install opencv-python-headless numpy".', file=sys.stderr)
        return 2
    try:
        import segno
    except ImportError:
        segno = None
        print('Hinweis: segno fehlt, der Modulvergleich entfällt.\n')

    import cv2
    leser = cv2.QRCodeDetector()
    fehler = 0

    for text in FAELLE:
        for stufe in ('L', 'M'):
            feld = js_feld(text, stufe)
            groesse = len(feld)
            fassung = (groesse - 17) // 4
            merker = []

            gelesen, _, _ = leser.detectAndDecode(als_bild(feld))
            if gelesen == text:
                merker.append('gelesen')
            else:
                merker.append(f'NICHT GELESEN ({gelesen[:20]!r})')
                fehler += 1

            if segno is not None:
                # encoding='utf-8' ist wichtig: Ohne die Angabe nimmt segno
                # für den Byte-Modus ISO-8859-1 und braucht für „ä“ ein Byte
                # statt zwei. Diese App schreibt immer UTF-8 — anders wären
                # Umlaute in einem Klassennamen nicht sicher zu übertragen.
                code = segno.make(text, error=stufe.lower(), mode='byte',
                                  encoding='utf-8', boost_error=False, micro=False)
                fremd = [[1 if w else 0 for w in z] for z in code.matrix]
                if len(fremd) != groesse:
                    merker.append(f'GRÖSSE {groesse} statt {len(fremd)}')
                    fehler += 1
                else:
                    schief = [(r, c) for (r, c) in feste_module(groesse, fassung)
                              if feld[r][c] != fremd[r][c]]
                    if schief:
                        merker.append(f'{len(schief)} FESTE MODULE FALSCH {schief[:4]}')
                        fehler += 1
                    else:
                        merker.append(f'Muster stimmen (Maske {maske_aus_feld(feld)})')

            print(f'Fassung {fassung:2d}  Stufe {stufe}  {groesse:2d}×{groesse:<2d}  '
                  f'{" · ".join(merker)}   «{text[:34]}»')

    if fehler:
        print(f'\n{fehler} Prüfung(en) fehlgeschlagen.')
        return 1
    print('\nAlle Fälle gelesen, alle festen Muster stimmen.')
    return 0


def maske_aus_feld(feld):
    """Die gewählte Maske aus der Format-Information zurücklesen."""
    bits = [feld[i][8] for i in range(6)]
    bits += [feld[7][8], feld[8][8], feld[8][7]]
    bits += [feld[8][14 - i] for i in range(9, 15)]
    wert = sum(b << i for i, b in enumerate(bits)) ^ 0b101010000010010
    return (wert >> 10) & 0b111


if __name__ == '__main__':
    sys.exit(main())
