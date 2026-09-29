// Amtliche Daten laden und mit OSM zusammenführen.
//
// Zwei Arten von Standorten: Container (glas/papier/hof) und Toiletten (wc).
// Vorrang haben die amtlichen Daten: Ein OSM-Standort, der näher als
// DOPPELT_M an einem amtlichen Standort DERSELBEN Art steht, gilt als derselbe
// Platz und verschwindet. Kennt OSM bei einem Container eine Art, die der
// amtliche Datensatz nicht hat (Bochum und München führen kein Altpapier),
// wird sie dem amtlichen Standort angehängt — mit Vermerk, woher sie stammt.

import { abstandM } from './geo.js';

export const DOPPELT_M = 30;

// Dateien in daten/ — je eine je Quelle (scripts/daten-aktualisieren.py).
const DATEIEN = ['bochum', 'dortmund', 'muenchen', 'salzburg', 'land-salzburg'];

export const QUELLEN = {
  bochum: {
    kurz: 'Open Data Bochum',
    lang: 'Umweltservice Bochum (USB) — Open Data Bochum, Lizenz CC0 1.0',
    stelle: ['vom Umweltservice Bochum (USB)', 'dem Umweltservice Bochum (USB)'],
    link: 'https://bochum.opendata.ruhr/dataset/1b5c33bb-cfa6-40ab-b394-be3f0037ad32',
  },
  dortmund: {
    kurz: 'Open Data Dortmund',
    lang: 'EDG Entsorgung Dortmund und Stadt Dortmund — Open Data Dortmund, Datenlizenz Deutschland Zero 2.0',
    stelle: ['von der Stadt Dortmund bzw. der EDG', 'der Stadt Dortmund bzw. der EDG'],
    link: 'https://open-data.dortmund.de/',
  },
  muenchen: {
    kurz: 'Open Data München',
    lang: 'Landeshauptstadt München — Open Data München, Datenlizenz Deutschland Namensnennung 2.0',
    stelle: ['von der Landeshauptstadt München', 'der Landeshauptstadt München'],
    link: 'https://opendata.muenchen.de/',
  },
  salzburg: {
    kurz: 'Stadt Salzburg',
    lang: 'Stadt Salzburg — data.stadt-salzburg.at, Lizenz CC BY 3.0 AT',
    stelle: ['von der Stadt Salzburg', 'der Stadt Salzburg'],
    link: 'https://www.data.gv.at/katalog/dataset/3810778f-f3ad-4032-9df7-dadaa8dd9726',
  },
  'land-salzburg': {
    kurz: 'Land Salzburg',
    lang: 'Land Salzburg — Open Government Data (data.gv.at)',
    stelle: ['vom Land Salzburg', 'dem Land Salzburg'],
    link: 'https://www.data.gv.at/katalog/dataset/198fb2f8-6b56-40a3-b9ab-e4ab20210ee9',
  },
  osm: {
    kurz: 'OpenStreetMap',
    lang: '© OpenStreetMap-Mitwirkende, Lizenz ODbL 1.0',
    link: 'https://www.openstreetmap.org/copyright',
  },
};

export const stand = {};

/** Liefert { amtlich, osmFest, regionen }. */
export async function datenLaden() {
  const amtlich = [];
  await Promise.all(DATEIEN.map(async (quelle) => {
    try {
      const antwort = await fetch(`./daten/${quelle}.json`);
      if (!antwort.ok) return;
      const daten = await antwort.json();
      stand[quelle] = daten.stand;
      daten.orte.forEach((o, i) => amtlich.push({ ...o, id: `${quelle}-${i}`, quelle }));
    } catch {
      // Ohne diese Datei bleiben die übrigen — die App ist trotzdem brauchbar.
    }
  }));

  // Fester OSM-Stand für die Gebiete, die der Nutzer oft braucht. Kommt vom
  // Arbeitsablauf container-finder-daten.yml; fehlt die Datei, lädt die App
  // dort eben live nach wie überall sonst.
  let osmFest = [];
  let regionen = [];
  try {
    const antwort = await fetch('./daten/osm-regionen.json');
    if (antwort.ok) {
      const daten = await antwort.json();
      stand.osm = daten.stand;
      regionen = daten.regionen || [];
      osmFest = daten.orte.map((o) => ({
        ...o, quelle: 'osm', osm: `https://www.openstreetmap.org/${
          { n: 'node', w: 'way', r: 'relation' }[o.id[4]]}/${o.id.slice(5)}`,
      }));
    }
  } catch { /* live */ }
  return { amtlich, osmFest, regionen };
}

// Raster über die amtlichen Standorte, damit nicht jeder OSM-Punkt gegen
// alle 3000 geprüft wird. 0,001° ≈ 110 m × 70 m — mit den Nachbarzellen
// sicher größer als DOPPELT_M.
const RASTER = 0.001;
const schluessel = (y, x) => `${y}:${x}`;

function rasterBauen(orte) {
  const raster = new Map();
  for (const o of orte) {
    const k = schluessel(Math.floor(o.lat / RASTER), Math.floor(o.lon / RASTER));
    if (!raster.has(k)) raster.set(k, []);
    raster.get(k).push(o);
  }
  return raster;
}

function naechsterAmtlicher(raster, p) {
  const y0 = Math.floor(p.lat / RASTER);
  const x0 = Math.floor(p.lon / RASTER);
  let bester = null;
  let besterAbstand = DOPPELT_M;
  for (let y = y0 - 1; y <= y0 + 1; y += 1) {
    for (let x = x0 - 1; x <= x0 + 1; x += 1) {
      for (const o of raster.get(schluessel(y, x)) || []) {
        if (Boolean(o.wc) !== Boolean(p.wc)) continue; // Toilette ≠ Container
        const d = abstandM(p.lat, p.lon, o.lat, o.lon);
        if (d < besterAbstand) { bester = o; besterAbstand = d; }
      }
    }
  }
  return bester;
}

let amtlichRaster = null;
let amtlichListe = null;

/** Liefert die zusammengeführte Liste aller bekannten Standorte. */
export function zusammenfuehren(amtlich, osmOrte) {
  if (amtlichListe !== amtlich) {
    amtlichListe = amtlich;
    amtlichRaster = rasterBauen(amtlich);
  }
  const ergaenzt = new Map(); // amtliche id → Kopie mit OSM-Ergänzung
  const ergebnis = [];
  for (const p of osmOrte) {
    const amtlicher = naechsterAmtlicher(amtlichRaster, p);
    if (!amtlicher) { ergebnis.push(p); continue; }
    if (p.wc) continue; // amtliche Toilette gewinnt
    const neuGlas = p.glas && !amtlicher.glas;
    const neuPapier = p.papier && !amtlicher.papier;
    if (!neuGlas && !neuPapier) continue;
    const kopie = ergaenzt.get(amtlicher.id) || { ...amtlicher, ergaenzt: [] };
    if (neuGlas && !kopie.glas) { kopie.glas = true; kopie.ergaenzt.push('glas'); }
    if (neuPapier && !kopie.papier) { kopie.papier = true; kopie.ergaenzt.push('papier'); }
    kopie.osm = kopie.osm || p.osm;
    ergaenzt.set(amtlicher.id, kopie);
  }
  for (const o of amtlich) ergebnis.push(ergaenzt.get(o.id) || o);
  return ergebnis;
}

/** filter = { glas, papier, wc } — was jeweils eingeschaltet ist. */
export function passtZuFilter(ort, filter) {
  if (ort.wc) return filter.wc;
  return (ort.glas && filter.glas) || (ort.papier && filter.papier);
}

export function artText(ort) {
  if (ort.wc) return 'Öffentliche Toilette';
  if (ort.hof) return ort.quelle === 'bochum' ? 'Wertstoffhof' : 'Recyclinghof';
  if (ort.glas && ort.papier) return 'Altglas & Altpapier';
  return ort.glas ? 'Altglas' : 'Altpapier';
}
