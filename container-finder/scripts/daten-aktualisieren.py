#!/usr/bin/env python3
"""Holt die Standorte von Glas- und Papiercontainern und öffentlichen
Toiletten und legt sie als statische JSON-Dateien in `daten/` ab.

Amtliche Quellen (je eine Datei):
  bochum.json         USB Bochum (Open Data Ruhr), CC0 1.0 — nur Altglas + Wertstoffhöfe
  dortmund.json       EDG + Stadt Dortmund (open-data.dortmund.de), dl-de/zero-2.0
                      — Glas, Papier, Recyclinghöfe, öffentliche Toiletten
  muenchen.json       Landeshauptstadt München (opendata.muenchen.de), dl-de/by-2.0
                      — Altglas (Wertstoffinseln), städtische Toiletten
  salzburg.json       Stadt Salzburg (data.stadt-salzburg.at), CC BY 3.0 AT
                      — Glas, Papier, öffentliche WC-Anlagen
  land-salzburg.json  Land Salzburg (data.gv.at) — Recyclinghöfe

OpenStreetMap-Stand für feste Gebiete (Ruhr um Bochum/Dortmund/Witten/
Castrop-Rauxel, München und Fünfseenland/Pilsensee, Salzburg und
Berchtesgadener Land):
  osm-regionen.json   über die Overpass API, ODbL
Overpass ist aus der Claude-Umgebung NICHT erreichbar — dieser Teil läuft im
Arbeitsablauf `.github/workflows/container-finder-daten.yml`.

Bochum liefert Koordinaten, aber bei fast allen Containerinseln KEINE Adresse.
Die wird einmalig per Nominatim aus den Koordinaten nachgeschlagen und in
`scripts/adressen-cache.json` gemerkt (höchstens eine Anfrage pro Sekunde).

Aufruf:  python3 scripts/daten-aktualisieren.py                  alles
         python3 scripts/daten-aktualisieren.py --ohne-osm        nur amtliche Daten
         python3 scripts/daten-aktualisieren.py --nur-osm         nur OSM-Gebiete
         python3 scripts/daten-aktualisieren.py --ohne-adressen   kein Nominatim
Nur die Standardbibliothek, keine Pakete nötig. Schlägt eine Quelle fehl,
bleibt ihre bisherige Datei stehen.
"""

import csv
import io
import json
import math
import re
import sys
import time
import traceback
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
DORTMUND_API = 'https://open-data.dortmund.de/api/explore/v2.1/catalog/datasets/{}/exports/json'
MUENCHEN_WFS = ('https://geoportal.muenchen.de/geoserver/gsm_wfs/ows?service=WFS&version=1.1.0'
                '&request=GetFeature&typeName=gsm_wfs:{}&outputFormat=application/json&srsName=EPSG:4326')
SALZBURG_WFS = ('https://data.stadt-salzburg.at/geodaten/wfs?service=WFS&version=1.1.0'
                '&request=GetFeature&srsName=EPSG:4326&outputFormat=application/json&typeName=ogdsbg:{}')
LAND_SALZBURG_RH = ('https://service.salzburg.gv.at/arcgis/rest/services/OGD/'
                    'OGD_OeffentlicheEinrichtungen_Land_Salzburg/MapServer/8/query'
                    '?where=1%3D1&outFields=*&outSR=4326&f=geojson')
NOMINATIM = 'https://nominatim.openstreetmap.org/reverse'
OVERPASS = [
    'https://overpass-api.de/api/interpreter',
    'https://z.overpass-api.de/api/interpreter',
    'https://overpass.openstreetmap.fr/api/interpreter',
    'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
]
KENNUNG = 'Container-Finder/1.1 (Datenaufbereitung; https://github.com/katonid/prae)'

# Gebiete mit festem OSM-Stand. Grenzen auf 0,1° ausgerichtet — genau das
# Raster, in dem die App live nachlädt (js/geo.js, ZELLE). So deckt ein Gebiet
# ganze Zellen ab, und die App fragt dort Overpass gar nicht erst.
REGIONEN = [
    {'name': 'Ruhrgebiet (Bochum, Dortmund, Witten, Castrop-Rauxel)', 'kasten': [51.3, 7.0, 51.7, 7.7]},
    {'name': 'München und Fünfseenland (Pilsensee)', 'kasten': [47.9, 11.0, 48.3, 11.8]},
    {'name': 'Salzburg und Berchtesgadener Land', 'kasten': [47.5, 12.7, 48.0, 13.3]},
]

# Standorte näher als das gelten als EIN Platz.
ZUSAMMEN_M = 25


def holen(url, daten=None):
    anfrage = urllib.request.Request(url, data=daten, headers={'User-Agent': KENNUNG})
    with urllib.request.urlopen(anfrage, timeout=300) as antwort:
        return antwort.read()


def holen_json(url):
    return json.loads(holen(url))


def abstand_m(a_lat, a_lon, b_lat, b_lon):
    r = 6371000.0
    p1, p2 = math.radians(a_lat), math.radians(b_lat)
    dp, dl = p2 - p1, math.radians(b_lon - a_lon)
    h = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(h))


def sauber(text):
    text = str(text or '').strip()
    return '' if text.upper() in ('NULL', 'NONE') else ' '.join(text.split())


def ja(wert):
    return str(wert).strip().lower() in ('1', 'ja', 'yes', 'true')


def platz_suchen(plaetze, lat, lon, passt=lambda p: True):
    for p in plaetze:
        if passt(p) and abstand_m(lat, lon, p['lat'], p['lon']) < ZUSAMMEN_M:
            return p
    return None


def container(lat, lon, **felder):
    return {'lat': round(lat, 6), 'lon': round(lon, 6), 'glas': False, 'papier': False, **felder}


def toilette(lat, lon, **felder):
    ort = {'lat': round(lat, 6), 'lon': round(lon, 6), 'wc': True}
    ort.update({k: v for k, v in felder.items() if v not in (None, '', False)})
    return ort


# ── Rückwärtssuche (Bochum) ───────────────────────────────────────────────

def cache_laden():
    try:
        return json.loads(CACHE.read_text(encoding='utf-8'))
    except (OSError, ValueError):
        return {}


def adresse_nachschlagen(lat, lon, cache, letzte):
    schluessel = f'{lat:.6f},{lon:.6f}'
    if schluessel in cache:
        return cache[schluessel], letzte
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
            roh = holen_json(f'{NOMINATIM}?{abfrage}')
            break
        except urllib.error.HTTPError as fehler:
            # 429 „Too many requests": Nominatim will eine längere Pause.
            if fehler.code != 429 or versuch == 2:
                print(f'  Nominatim-Fehler bei {schluessel}: {fehler}', file=sys.stderr)
                return '', time.monotonic()
            time.sleep(30 * (versuch + 1))
        except Exception as fehler:  # Netz weg: ohne Adresse weitermachen
            print(f'  Nominatim-Fehler bei {schluessel}: {fehler}', file=sys.stderr)
            return '', time.monotonic()
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
    hoefe, inseln = [], []
    for z in csv.DictReader(io.StringIO(text)):
        lage = z['Standort'].strip().strip('()').split(',')
        if len(lage) != 2:
            continue
        lat, lon = float(lage[0]), float(lage[1])
        glas = int(z['Glascontainer'] or 0)
        name, adresse = sauber(z['Name']), sauber(z['Adresse'])
        if z['Typ'] == 'Wertstoffhof':
            for kuerzel in ('WEH ', 'WSH '):  # beide Schreibweisen stehen in der CSV
                if name.startswith(kuerzel):
                    name = 'Wertstoffhof ' + name[len(kuerzel):]
            hoefe.append(container(lat, lon, glas=True, papier=True, hof=True,
                                   name=name, adresse=adresse))
        elif z['Typ'] == 'Containerinsel' and glas > 0:
            inseln.append(container(lat, lon, glas=True, name=name, adresse=adresse, anzahl=glas))
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
    plaetze = []
    for r in holen_json(DORTMUND_API.format('edg-abfallentsorgung')):
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
        lat, lon = lage['lat'], lage['lon']
        if titel.startswith('Depotcontainer'):
            art = 'glas' if 'glas' in titel.lower() else 'papier' if 'papier' in titel.lower() else ''
            if not art:
                continue
            platz = platz_suchen(plaetze, lat, lon, lambda p: not p.get('hof'))
            if platz is None:
                platz = container(lat, lon, adresse=adresse)
                plaetze.append(platz)
            platz[art] = True
        elif titel.startswith(('Recyclinghof', 'Recyclingzentrum', 'Wertstoffzentrum')):
            hof = container(lat, lon, glas=True, papier=True, hof=True, name=titel, adresse=adresse)
            zeiten = sauber(r.get('offnungszeiten'))
            if zeiten:
                hof['info'] = zeiten
            plaetze.append(hof)
        # Die Deponie nimmt weder Glas noch Papier in Containern an.

    for r in holen_json(DORTMUND_API.format('offentliche-toiletten')):
        lage = r.get('geo_point_2d') or {}
        if 'lat' not in lage:
            continue
        beschr = sauber(r.get('i_beschr'))
        zusatz = sauber(r.get('i_zusinfo'))
        strasse = ' '.join(x for x in (sauber(r.get('strasse')), sauber(r.get('hausnummer'))) if x)
        if not strasse and beschr.startswith('Standort:'):
            strasse, beschr = beschr[len('Standort:'):].strip().replace('_', '-'), ''
        nett = sauber(r.get('objektzusa')) == 'Nette Toilette'
        info = [x for x in (beschr, zusatz) if x and not x.lower().startswith(('rollstuhl', 'kostenlos'))]
        if nett:
            info.insert(0, '„Nette Toilette" — in einem Geschäft oder Lokal, ohne Verzehr nutzbar')
        plaetze.append(toilette(
            lage['lat'], lage['lon'],
            name=sauber(r.get('objektname')) or 'Öffentliche Toilette',
            adresse=f'{strasse}, Dortmund' if strasse else 'Dortmund',
            barrierefrei=True if re.search(r'rollstuhl\w*: ja', zusatz, re.I) else None,
            gebuehr='kostenlos' if 'kostenlos' in beschr.lower() or nett else None,
            info=' · '.join(info),
        ))
    return plaetze


# ── München ───────────────────────────────────────────────────────────────

def muenchen():
    plaetze = []
    for f in holen_json(MUENCHEN_WFS.format('awm_container'))['features']:
        p = f['properties']
        if not any(p.get(k) for k in ('glas_braun', 'glas_gruen', 'glas_weiss')):
            continue  # nur Altkleider oder Verpackungen
        lon, lat = f['geometry']['coordinates'][:2]
        adresse = sauber(p.get('adresse'))
        plaetze.append(container(lat, lon, glas=True,
                                 adresse=f'{adresse}, München' if adresse else 'München'))
    for f in holen_json(MUENCHEN_WFS.format('awm_container_barrierefrei'))['features']:
        lon, lat = f['geometry']['coordinates'][:2]
        platz = platz_suchen(plaetze, lat, lon)
        if platz is None:
            platz = container(lat, lon, glas=True,
                              adresse=f"{sauber(f['properties'].get('adresse'))}, München")
            plaetze.append(platz)
        platz['info'] = 'Barrierefreier Altglascontainer (Einwurf in niedriger Höhe)'

    # Das WC-Verzeichnis hat eine Zeile je Kabine (Damen, Herren, barrierefrei)
    # — die werden zu einem Standort zusammengefasst.
    wcs = []
    for f in holen_json(MUENCHEN_WFS.format('wc_finder_opendata'))['features']:
        p = f['properties']
        lon, lat = f['geometry']['coordinates'][:2]
        wc = platz_suchen(wcs, lat, lon)
        if wc is None:
            strasse = ' '.join(x for x in (sauber(p.get('strasse')), sauber(p.get('hausnr'))) if x)
            ort = ' '.join(x for x in (sauber(p.get('plz')), sauber(p.get('stadt')) or 'München') if x)
            name = sauber(p.get('name'))
            name = re.sub(r'\s*DSMDecaux GmbH', '', name)
            wc = {'lat': lat, 'lon': lon, 'name': name or 'Öffentliche Toilette',
                  'adresse': ', '.join(x for x in (strasse, ort) if x),
                  'zeiten': sauber(p.get('oeffnungszeiten')), 'preise': [], 'barrierefrei': False,
                  'wickeln': False, 'eurokey': False, 'defekt': [], 'hinweise': []}
            wcs.append(wc)
        if p.get('preis') is not None:
            wc['preise'].append(float(p['preis']))
        if 'barrierefrei' in sauber(p.get('kategorie')) or ja(p.get('din_18040_1')):
            wc['barrierefrei'] = True
        wc['wickeln'] |= ja(p.get('wickeln'))
        wc['eurokey'] |= ja(p.get('eingangstuer_euro_schluessel')) or ja(p.get('wctuer_euro_schluessel'))
        wc['defekt'].append(sauber(p.get('zustand')) == 'defekt oder nicht zugänglich')
        for k in ('standort_beschreibung', 'einschraenkungen'):
            # „… | Bild: http://badsyip001.srv.muenchen.de/…" zeigt ins Intranet der Stadt.
            text = re.sub(r'\s*\|?\s*Bild:\s*\S+', '', sauber(p.get(k))).strip(' |')
            if text and text not in wc['hinweise']:
                wc['hinweise'].append(text)
    for wc in wcs:
        preis = min(wc['preise']) if wc['preise'] else None
        hinweise = wc['hinweise']
        if wc['defekt'] and all(wc['defekt']):
            hinweise.insert(0, 'Laut Stadt derzeit defekt oder nicht zugänglich')
        plaetze.append(toilette(
            wc['lat'], wc['lon'], name=wc['name'], adresse=wc['adresse'], zeiten=wc['zeiten'],
            gebuehr=None if preis is None else 'kostenlos' if preis == 0
            else f'{preis:.2f} €'.replace('.', ','),
            barrierefrei=wc['barrierefrei'], wickeln=wc['wickeln'], eurokey=wc['eurokey'],
            info=' · '.join(hinweise),
        ))
    return plaetze


# ── Salzburg ──────────────────────────────────────────────────────────────

def salzburg():
    plaetze = []
    standplaetze = {}
    for f in holen_json(SALZBURG_WFS.format('abfallsammelstelle'))['features']:
        p = f['properties']
        fraktion = sauber(p.get('FRAKTION')).lower()
        art = 'glas' if fraktion == 'glas' else 'papier' if fraktion == 'papier' else ''
        if not art:
            continue  # Textilien
        lon, lat = f['geometry']['coordinates'][:2]
        schluessel = p.get('STANDPLATZNUMMER')
        platz = standplaetze.get(schluessel) if schluessel is not None else None
        platz = platz or platz_suchen(plaetze, lat, lon)
        if platz is None:
            strasse = ' '.join(x for x in (sauber(p.get('STRASSENNAME')), sauber(p.get('HAUSNUMMER'))) if x)
            platz = container(lat, lon, adresse=f'{strasse}, Salzburg' if strasse else 'Salzburg')
            zusatz = sauber(p.get('ADRESSZUSATZ'))
            if zusatz:
                platz['info'] = zusatz
            plaetze.append(platz)
        if schluessel is not None:
            standplaetze[schluessel] = platz
        platz[art] = True

    for f in holen_json(SALZBURG_WFS.format('wcanlage'))['features']:
        p = f['properties']
        lon, lat = f['geometry']['coordinates'][:2]
        adresse = sauber(p.get('ADRESSE'))
        if ', ' in adresse:  # „Altstadt, Mirabellplatz 3" → „Mirabellplatz 3, Salzburg-Altstadt"
            teil, strasse = adresse.split(', ', 1)
            adresse = f'{strasse}, Salzburg-{teil}'
        gebuehr = sauber(p.get('GEBUEHR'))
        gebuehr = 'kostenlos' if gebuehr == 'gebührenfrei' else \
            gebuehr.replace('gebührenpflichtig', '').strip(' ()') or None
        typ = sauber(p.get('TYP'))
        info = [sauber(p.get('BEMERKUNG'))]
        if typ == 'Nette Toilette':
            info.insert(0, '„Nette Toilette" — in einem Geschäft oder Lokal, ohne Verzehr nutzbar')
        elif typ == 'ÖKO-WC':
            info.insert(0, 'Öko-WC (Trockentoilette)')
        zeiten = '; '.join(z.strip().rstrip(';') for z in str(p.get('OEFFNUNGSZEITEN') or '').splitlines()
                           if z.strip().rstrip(';'))
        plaetze.append(toilette(
            lat, lon, name=sauber(p.get('NAME')) or 'Öffentliches WC',
            adresse=adresse or 'Salzburg', zeiten=zeiten, gebuehr=gebuehr,
            barrierefrei=True if ja(p.get('BARRIEREFREI')) else None,
            eurokey=ja(p.get('EUROKEY')), info=' · '.join(x for x in info if x),
        ))
    return plaetze


def land_salzburg():
    plaetze = []
    for f in holen_json(LAND_SALZBURG_RH)['features']:
        p = f['properties']
        lon, lat = f['geometry']['coordinates'][:2]
        strasse = ' '.join(x for x in (sauber(p.get('STRASSE')), sauber(p.get('HNR'))) if x)
        plz = str(int(p['PLZ'])) if p.get('PLZ') else ''
        ort = ' '.join(x for x in (plz, sauber(p.get('ORT'))) if x)
        plaetze.append(container(lat, lon, glas=True, papier=True, hof=True,
                                 name=sauber(p.get('NAME')) or 'Recyclinghof',
                                 adresse=', '.join(x for x in (strasse, ort) if x)))
    return plaetze


# ── OpenStreetMap-Gebiete ─────────────────────────────────────────────────

def overpass_fragen(kasten):
    s, w, n, o = kasten
    k = f'({s},{w},{n},{o})'
    grund = 'nwr["amenity"="recycling"]["recycling_type"="container"]'
    abfrage = f'''[out:json][timeout:300];(
{grund}["recycling:glass_bottles"="yes"]{k};
{grund}["recycling:glass"="yes"]{k};
{grund}["recycling:paper"="yes"]{k};
{grund}["recycling:cardboard"="yes"]{k};
nwr["amenity"="toilets"]{k};
);out center tags;'''
    fehler = None
    for server in OVERPASS:
        for versuch in range(2):
            try:
                daten = json.loads(holen(server, urllib.parse.urlencode({'data': abfrage}).encode()))
                if daten.get('remark') and re.search(r'runtime error|timed out|out of memory',
                                                     daten['remark'], re.I):
                    raise RuntimeError(daten['remark'])
                return daten['elements']
            except Exception as f:
                fehler = f
                print(f'  {server}: {f}', file=sys.stderr)
                time.sleep(20)
    raise RuntimeError(f'Overpass nicht erreichbar: {fehler}')


def osm_adresse(t):
    strasse = ' '.join(x for x in (t.get('addr:street'), t.get('addr:housenumber')) if x)
    ort = ' '.join(x for x in (t.get('addr:postcode'), t.get('addr:city')) if x)
    return ', '.join(x for x in (strasse, ort) if x)


def osm_ort(e):
    """Ein Overpass-Element → Standort; dieselben Regeln wie js/osm.js."""
    t = e.get('tags', {})
    lat = e.get('lat', e.get('center', {}).get('lat'))
    lon = e.get('lon', e.get('center', {}).get('lon'))
    if lat is None or lon is None:
        return None
    grund = {'id': f"osm-{e['type'][0]}{e['id']}", 'lat': round(lat, 6), 'lon': round(lon, 6)}
    if t.get('amenity') == 'toilets':
        if t.get('access') in ('private', 'no', 'customers', 'permit'):
            return None
        gebuehr = None
        if t.get('fee') == 'no':
            gebuehr = 'kostenlos'
        elif t.get('fee') == 'yes':
            gebuehr = t.get('charge') or 'kostenpflichtig'
        rollstuhl = t.get('wheelchair')
        return {**grund, 'wc': True, **{k: v for k, v in {
            'name': t.get('name', ''), 'adresse': osm_adresse(t),
            'betreiber': t.get('operator', ''), 'zeiten': t.get('opening_hours', ''),
            'gebuehr': gebuehr,
            'barrierefrei': True if rollstuhl == 'yes' else False if rollstuhl == 'no' else None,
            'wickeln': t.get('changing_table') == 'yes',
            'eurokey': t.get('centralkey') in ('eurokey', 'yes'),
            'info': ' · '.join(x for x in (t.get('description'), t.get('note')) if x),
        }.items() if v not in (None, '', False)}}
    if t.get('access') in ('private', 'no'):
        return None
    glas = t.get('recycling:glass_bottles') == 'yes' or t.get('recycling:glass') == 'yes'
    papier = t.get('recycling:paper') == 'yes' or t.get('recycling:cardboard') == 'yes'
    if not glas and not papier:
        return None
    info = ' · '.join(x for x in (t.get('opening_hours') and f"Einwurfzeiten: {t['opening_hours']}",
                                  t.get('description'), t.get('note')) if x)
    return {**grund, 'glas': glas, 'papier': papier, **{k: v for k, v in {
        'name': t.get('name', ''), 'adresse': osm_adresse(t),
        'betreiber': t.get('operator', ''), 'info': info}.items() if v}}


def osm_regionen():
    orte = {}
    for region in REGIONEN:
        print(f"  {region['name']} …")
        for e in overpass_fragen(region['kasten']):
            ort = osm_ort(e)
            if ort:
                orte[ort['id']] = ort
        time.sleep(5)
    inhalt = {'quelle': 'osm', 'stand': date.today().isoformat(),
              'regionen': REGIONEN, 'orte': sorted(orte.values(), key=lambda o: (o['lat'], o['lon']))}
    pfad = DATEN / 'osm-regionen.json'
    pfad.write_text(json.dumps(inhalt, ensure_ascii=False, separators=(',', ':')) + '\n',
                    encoding='utf-8')
    wc = sum(1 for o in orte.values() if o.get('wc'))
    print(f'{pfad.name}: {len(orte)} Standorte (davon {wc} Toiletten), '
          f'{pfad.stat().st_size // 1024} KB')


# ── Schreiben ─────────────────────────────────────────────────────────────

def schreiben(name, orte):
    DATEN.mkdir(exist_ok=True)
    for o in orte:
        o['lat'], o['lon'] = round(o['lat'], 6), round(o['lon'], 6)
    orte.sort(key=lambda o: (o['lat'], o['lon']))
    inhalt = {'quelle': name, 'stand': date.today().isoformat(), 'orte': orte}
    pfad = DATEN / f'{name}.json'
    pfad.write_text(json.dumps(inhalt, ensure_ascii=False, separators=(',', ':')) + '\n',
                    encoding='utf-8')
    glas = sum(1 for o in orte if o.get('glas'))
    papier = sum(1 for o in orte if o.get('papier'))
    hoefe = sum(1 for o in orte if o.get('hof'))
    wc = sum(1 for o in orte if o.get('wc'))
    print(f'{pfad.name}: {len(orte)} Standorte (Glas {glas}, Papier {papier}, '
          f'Höfe {hoefe}, WC {wc}), {pfad.stat().st_size // 1024} KB')


def main():
    argumente = set(sys.argv[1:])
    fehlgeschlagen = []
    if '--nur-osm' not in argumente:
        quellen = [
            ('bochum', lambda: bochum('--ohne-adressen' not in argumente)),
            ('dortmund', dortmund),
            ('muenchen', muenchen),
            ('salzburg', salzburg),
            ('land-salzburg', land_salzburg),
        ]
        for name, holer in quellen:
            print(f'{name} …')
            try:
                schreiben(name, holer())
            except Exception:
                traceback.print_exc()
                fehlgeschlagen.append(name)
    if '--ohne-osm' not in argumente:
        print('OpenStreetMap-Gebiete …')
        try:
            osm_regionen()
        except Exception:
            traceback.print_exc()
            fehlgeschlagen.append('osm-regionen')
    if fehlgeschlagen:
        print('FEHLGESCHLAGEN (alte Datei bleibt):', ', '.join(fehlgeschlagen), file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
