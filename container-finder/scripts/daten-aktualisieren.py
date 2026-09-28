#!/usr/bin/env python3
"""Holt die amtlichen Containerstandorte von Bochum und Dortmund und legt sie
als statische JSON-Dateien in `daten/` ab.

Quellen:
  Bochum   – Umweltservice Bochum (USB), Open Data Ruhr, CC0 1.0
  Dortmund – EDG über open-data.dortmund.de, Datenlizenz Deutschland Zero 2.0

Bochum liefert Koordinaten, aber bei fast allen Containerinseln KEINE Adresse
(Spalte „Adresse" = NULL). Die wird einmalig per Nominatim aus den Koordinaten
nachgeschlagen (Rückwärtssuche) und in `scripts/adressen-cache.json`
gemerkt — bei der nächsten Aktualisierung werden nur neue Standorte gefragt.
Nominatim-Regeln: höchstens eine Anfrage pro Sekunde, eigener User-Agent.

Aufruf:  python3 scripts/daten-aktualisieren.py
         python3 scripts/daten-aktualisieren.py --ohne-adressen   (kein Nominatim)
Nur die Standardbibliothek, keine Pakete nötig.
"""

import csv
import io
import json
import math
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import date
from pathlib import Path

HIER = Path(__file__).resolve().parent
DATEN = HIER.parent / 'daten'
CACHE = HIER / 'adressen-cache.json'

BOCHUM_CSV = ('https://bochum.opendata.ruhr/dataset/1b5c33bb-cfa6-40ab-b394-be3f0037ad32'
              '/resource/9370542d-efdb-4d05-b7bf-a45ef76aac59/download/bochum_usb_standorte.csv')
DORTMUND_JSON = ('https://open-data.dortmund.de/api/explore/v2.1/catalog/datasets'
                 '/edg-abfallentsorgung/exports/json')
NOMINATIM = 'https://nominatim.openstreetmap.org/reverse'
KENNUNG = 'Container-Finder/1.0 (Datenaufbereitung; https://github.com/katonid/prae)'

# Standorte näher als das gelten als EIN Platz (Glas und Papier stehen in
# Dortmund als getrennte Einträge nebeneinander).
ZUSAMMEN_M = 25


def holen(url):
    anfrage = urllib.request.Request(url, headers={'User-Agent': KENNUNG})
    with urllib.request.urlopen(anfrage, timeout=120) as antwort:
        return antwort.read()


def abstand_m(a_lat, a_lon, b_lat, b_lon):
    r = 6371000.0
    p1, p2 = math.radians(a_lat), math.radians(b_lat)
    dp, dl = p2 - p1, math.radians(b_lon - a_lon)
    h = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(h))


def sauber(text):
    text = (text or '').strip()
    return '' if text.upper() == 'NULL' else ' '.join(text.split())


# ── Rückwärtssuche ────────────────────────────────────────────────────────

def cache_laden():
    try:
        return json.loads(CACHE.read_text(encoding='utf-8'))
    except (OSError, ValueError):
        return {}


def adresse_nachschlagen(lat, lon, cache, letzte):
    schluessel = f'{lat:.6f},{lon:.6f}'
    if schluessel in cache:
        return cache[schluessel], letzte
    # Eine Anfrage pro Sekunde — mit etwas Luft.
    warten = 1.1 - (time.monotonic() - letzte)
    if warten > 0:
        time.sleep(warten)
    abfrage = urllib.parse.urlencode({
        'lat': f'{lat:.6f}', 'lon': f'{lon:.6f}', 'format': 'jsonv2',
        'zoom': 18, 'addressdetails': 1, 'accept-language': 'de',
    })
    roh = None
    for versuch in range(3):
        try:
            roh = json.loads(holen(f'{NOMINATIM}?{abfrage}'))
            break
        except urllib.error.HTTPError as fehler:
            # 429 „Too many requests": Nominatim will eine Pause — die kommt,
            # und zwar deutlich länger als eine Sekunde.
            if fehler.code != 429 or versuch == 2:
                print(f'  Nominatim-Fehler bei {schluessel}: {fehler}', file=sys.stderr)
                return '', time.monotonic()
            time.sleep(30 * (versuch + 1))
        except Exception as fehler:  # Netz weg: ohne Adresse weitermachen
            print(f'  Nominatim-Fehler bei {schluessel}: {fehler}', file=sys.stderr)
            return '', time.monotonic()
    # Nicht gefunden steht leer im Cache — ein erneuter Lauf fragt nur die
    # Fehlschläge (die stehen NICHT im Cache) noch einmal.
    teile = roh.get('address', {})
    strasse = teile.get('road') or teile.get('pedestrian') or teile.get('footway') \
        or teile.get('square') or teile.get('path') or ''
    if strasse and teile.get('house_number'):
        strasse = f"{strasse} {teile['house_number']}"
    ort = teile.get('city') or teile.get('town') or teile.get('village') or 'Bochum'
    plz = teile.get('postcode', '')
    adresse = ', '.join(x for x in (strasse, f'{plz} {ort}'.strip()) if x)
    cache[schluessel] = adresse
    CACHE.write_text(json.dumps(cache, ensure_ascii=False, indent=0, sort_keys=True),
                     encoding='utf-8')
    return adresse, time.monotonic()


# ── Bochum ────────────────────────────────────────────────────────────────

def bochum(mit_adressen):
    text = holen(BOCHUM_CSV).decode('utf-8-sig')
    zeilen = list(csv.DictReader(io.StringIO(text)))
    hoefe, inseln = [], []
    for z in zeilen:
        lage = z['Standort'].strip().strip('()').split(',')
        if len(lage) != 2:
            continue
        lat, lon = float(lage[0]), float(lage[1])
        glas = int(z['Glascontainer'] or 0)
        eintrag = {'lat': round(lat, 6), 'lon': round(lon, 6),
                   'name': sauber(z['Name']), 'adresse': sauber(z['Adresse'])}
        if z['Typ'] == 'Wertstoffhof':
            for kuerzel in ('WEH ', 'WSH '):  # beide Schreibweisen stehen in der CSV
                if eintrag['name'].startswith(kuerzel):
                    eintrag['name'] = 'Wertstoffhof ' + eintrag['name'][len(kuerzel):]
            hoefe.append({**eintrag, 'glas': True, 'papier': True, 'hof': True})
        elif z['Typ'] == 'Containerinsel' and glas > 0:
            inseln.append({**eintrag, 'glas': True, 'papier': False, 'anzahl': glas})
        # Lager, Verwerter, Deponien, Gewerbekunden: keine öffentlichen Container.

    # Eine Containerinsel direkt am Wertstoffhof ist derselbe Platz.
    inseln = [i for i in inseln
              if not any(abstand_m(i['lat'], i['lon'], h['lat'], h['lon']) < 80 for h in hoefe)]

    cache, letzte = cache_laden(), 0.0
    for i in inseln:
        if i['adresse']:
            continue
        if mit_adressen:
            i['adresse'], letzte = adresse_nachschlagen(i['lat'], i['lon'], cache, letzte)
        else:
            i['adresse'] = cache.get(f"{i['lat']:.6f},{i['lon']:.6f}", '')
        i['ungefaehr'] = True  # nächstgelegene Adresse, nicht amtlich
    return hoefe + inseln


# ── Dortmund ──────────────────────────────────────────────────────────────

def dortmund():
    roh = json.loads(holen(DORTMUND_JSON))
    plaetze = []
    for r in roh:
        lage = r.get('geografische_koordinaten') or {}
        if 'lat' not in lage:
            continue
        titel = sauber(r.get('titel'))
        adresse = sauber(r.get('adresse'))
        ort = sauber(r.get('ort'))
        if ort and ort != 'Dortmund':
            adresse = f'{adresse}, {ort}'
        elif adresse:
            adresse = f'{adresse}, Dortmund'
        lat, lon = round(lage['lat'], 6), round(lage['lon'], 6)
        if titel.startswith('Depotcontainer'):
            art = 'glas' if 'glas' in titel.lower() else 'papier' if 'papier' in titel.lower() else ''
            if not art:
                continue
            platz = next((p for p in plaetze if not p.get('hof')
                          and abstand_m(lat, lon, p['lat'], p['lon']) < ZUSAMMEN_M), None)
            if platz is None:
                platz = {'lat': lat, 'lon': lon, 'adresse': adresse,
                         'glas': False, 'papier': False}
                plaetze.append(platz)
            platz[art] = True
        elif titel.startswith(('Recyclinghof', 'Recyclingzentrum', 'Wertstoffzentrum')):
            hof = {'lat': lat, 'lon': lon, 'name': titel, 'adresse': adresse,
                   'glas': True, 'papier': True, 'hof': True}
            zeiten = sauber(r.get('offnungszeiten'))
            if zeiten:
                hof['info'] = zeiten
            plaetze.append(hof)
        # Die Deponie nimmt weder Glas noch Papier in Containern an.
    return plaetze


def schreiben(name, quelle, orte):
    DATEN.mkdir(exist_ok=True)
    orte.sort(key=lambda o: (o['lat'], o['lon']))
    inhalt = {'quelle': quelle, 'stand': date.today().isoformat(), 'orte': orte}
    pfad = DATEN / f'{name}.json'
    pfad.write_text(json.dumps(inhalt, ensure_ascii=False, separators=(',', ':')) + '\n',
                    encoding='utf-8')
    glas = sum(1 for o in orte if o['glas'])
    papier = sum(1 for o in orte if o['papier'])
    hoefe = sum(1 for o in orte if o.get('hof'))
    print(f'{pfad.name}: {len(orte)} Standorte (Glas {glas}, Papier {papier}, Höfe {hoefe}), '
          f'{pfad.stat().st_size // 1024} KB')


def main():
    mit_adressen = '--ohne-adressen' not in sys.argv
    print('Bochum …')
    schreiben('bochum', 'bochum', bochum(mit_adressen))
    print('Dortmund …')
    schreiben('dortmund', 'dortmund', dortmund())


if __name__ == '__main__':
    main()
