#!/usr/bin/env python3
"""Holt das amtliche Verzeichnis der Ortsnetzkennzahlen (Vorwahlen) von der
Bundesnetzagentur und schreibt es als daten/vorwahlen.json.

Quelle: Bundesnetzagentur, „Vorwahlverzeichnis" (ZIP mit einer CSV
`Ortsnetzkennzahl;Ortsnetzname;KennzeichenAktiv`). Die Kennzahlen stehen OHNE
führende Null darin (201 = Essen). Übernommen werden nur aktive Einträge.

Die Datei ändert sich selten (Stand der Quelle 2026: 27.07.2022) — das
Skript nur laufen lassen, wenn die BNetzA ein neues Verzeichnis veröffentlicht.

Aufruf:  python3 scripts/vorwahlen-aktualisieren.py
Nur Standardbibliothek.
"""

import csv
import io
import json
import re
import urllib.request
import zipfile
from pathlib import Path

QUELLE = ('https://www.bundesnetzagentur.de/DE/Fachthemen/Telekommunikation/'
          'Nummerierung/ONRufnr/_DL/Vorwahlverzeichnis_ONB.zip.zip'
          '?__blob=publicationFile&v=1')
ZIEL = Path(__file__).resolve().parent.parent / 'daten' / 'vorwahlen.json'


def main():
    anfrage = urllib.request.Request(QUELLE, headers={'User-Agent': 'prae-rufnummer/1.0'})
    with urllib.request.urlopen(anfrage, timeout=60) as antwort:
        archiv = zipfile.ZipFile(io.BytesIO(antwort.read()))
    name = next(n for n in archiv.namelist() if n.lower().endswith('.csv'))
    # Der Dateiname trägt das Datum: NVONB.INTERNET.20220727.ONB.csv
    treffer = re.search(r'(\d{4})(\d{2})(\d{2})', name)
    stand = f'{treffer.group(1)}-{treffer.group(2)}-{treffer.group(3)}' if treffer else None

    text = archiv.read(name).decode('utf-8-sig')
    vorwahlen = {}
    for zeile in csv.DictReader(io.StringIO(text), delimiter=';'):
        kennzahl = (zeile.get('Ortsnetzkennzahl') or '').strip()
        ort = (zeile.get('Ortsnetzname') or '').strip()
        if not kennzahl.isdigit() or not ort or (zeile.get('KennzeichenAktiv') or '').strip() != '1':
            continue
        vorwahlen[kennzahl] = ort

    if len(vorwahlen) < 5000:
        raise SystemExit(f'Nur {len(vorwahlen)} Vorwahlen gelesen — Datei bleibt unverändert.')

    ZIEL.write_text(json.dumps({
        'quelle': 'Bundesnetzagentur, Verzeichnis der Ortsnetzkennzahlen',
        'stand': stand,
        'vorwahlen': dict(sorted(vorwahlen.items())),
    }, ensure_ascii=False, separators=(',', ':')) + '\n', encoding='utf-8')
    print(f'{len(vorwahlen)} Vorwahlen (Stand {stand}) nach {ZIEL}')


if __name__ == '__main__':
    main()
