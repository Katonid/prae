// Amtliche Daten laden und mit OSM zusammenführen.
//
// Vorrang haben die amtlichen Daten: Ein OSM-Container, der näher als
// DOPPELT_M an einem amtlichen Standort steht, gilt als derselbe Platz und
// verschwindet. Kennt OSM dort eine Art, die der amtliche Datensatz nicht hat
// (Bochum führt kein Altpapier), wird sie dem amtlichen Standort angehängt —
// mit Vermerk, woher sie stammt.

import { abstandM } from './geo.js';

export const DOPPELT_M = 30;

export const QUELLEN = {
  bochum: {
    kurz: 'Open Data Bochum',
    lang: 'Umweltservice Bochum (USB) — Open Data Bochum, Lizenz CC0 1.0',
    link: 'https://bochum.opendata.ruhr/dataset/1b5c33bb-cfa6-40ab-b394-be3f0037ad32',
  },
  dortmund: {
    kurz: 'Open Data Dortmund (EDG)',
    lang: 'EDG Entsorgung Dortmund — Open Data Dortmund, Datenlizenz Deutschland Zero 2.0',
    link: 'https://open-data.dortmund.de/explore/dataset/edg-abfallentsorgung/',
  },
  osm: {
    kurz: 'OpenStreetMap',
    lang: '© OpenStreetMap-Mitwirkende, Lizenz ODbL 1.0',
    link: 'https://www.openstreetmap.org/copyright',
  },
};

export const stand = {};

export async function amtlichLaden() {
  const orte = [];
  await Promise.all(['bochum', 'dortmund'].map(async (quelle) => {
    try {
      const antwort = await fetch(`./daten/${quelle}.json`);
      if (!antwort.ok) return;
      const daten = await antwort.json();
      stand[quelle] = daten.stand;
      daten.orte.forEach((o, i) => orte.push({
        ...o,
        id: `${quelle}-${i}`,
        hof: Boolean(o.hof),
        quelle,
      }));
    } catch {
      // Ohne diese Datei bleiben OSM-Daten — die App ist trotzdem brauchbar.
    }
  }));
  return orte;
}

// Raster über die amtlichen Standorte, damit nicht jeder OSM-Punkt gegen
// alle 900 geprüft wird. 0,001° ≈ 110 m × 70 m — mit den Nachbarzellen
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

export function passtZuFilter(ort, filter) {
  if (filter === 'glas') return ort.glas;
  if (filter === 'papier') return ort.papier;
  return ort.glas || ort.papier;
}

export function artText(ort) {
  if (ort.hof) return ort.quelle === 'dortmund' ? 'Recyclinghof' : 'Wertstoffhof';
  if (ort.glas && ort.papier) return 'Altglas & Altpapier';
  return ort.glas ? 'Altglas' : 'Altpapier';
}
