// OpenStreetMap über die Overpass API: Glas- und Papiercontainer in ganz
// Deutschland (und darüber hinaus — die Abfrage kennt keine Grenzen).
//
// Geladen wird in festen Rasterzellen (siehe geo.js). Jede Zelle wird eine
// Woche lang gemerkt, im Speicher und auf dem Gerät (IndexedDB); ohne Netz
// gilt auch eine ältere Zelle. Mehrere fehlende Zellen gehen in EINER Abfrage
// hinaus — die öffentlichen Server zählen Anfragen, nicht Treffer.

import { zellenGrenzen, zelleVon } from './geo.js';
import * as speicher from './speicher.js';

// Öffentliche Server, der Reihe nach versucht. Dieselbe Liste wie in
// „Heute in der Nähe" (geprüft 07/2026 mit .github/workflows/overpass-check.yml);
// z.overpass-api.de statt overpass-api.de, weil der Verteiler davor
// gelegentlich Verbindungen abweist.
const SERVER = [
  'https://z.overpass-api.de/api/interpreter',
  'https://overpass.openstreetmap.fr/api/interpreter',
  'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
];

const FRISCH_MS = 7 * 24 * 3600 * 1000;
const MAX_ZELLEN_JE_ABFRAGE = 6;

const imSpeicher = new Map();   // zelle → { zeit, orte }
const unterwegs = new Map();    // zelle → Promise

function abfrage([s, w, n, o]) {
  const kasten = `(${s},${w},${n},${o})`;
  const grund = 'nwr["amenity"="recycling"]["recycling_type"="container"]';
  return `[out:json][timeout:25];(
${grund}["recycling:glass_bottles"="yes"]${kasten};
${grund}["recycling:glass"="yes"]${kasten};
${grund}["recycling:paper"="yes"]${kasten};
${grund}["recycling:cardboard"="yes"]${kasten};
);out center tags;`;
}

function adresseAus(t) {
  const strasse = [t['addr:street'], t['addr:housenumber']].filter(Boolean).join(' ');
  const ort = [t['addr:postcode'], t['addr:city']].filter(Boolean).join(' ');
  return [strasse, ort].filter(Boolean).join(', ');
}

function standortAus(e) {
  const t = e.tags || {};
  if (t.access === 'private' || t.access === 'no') return null;
  const lat = e.lat ?? e.center?.lat;
  const lon = e.lon ?? e.center?.lon;
  if (lat == null || lon == null) return null;
  const glas = t['recycling:glass_bottles'] === 'yes' || t['recycling:glass'] === 'yes';
  const papier = t['recycling:paper'] === 'yes' || t['recycling:cardboard'] === 'yes';
  if (!glas && !papier) return null;
  const info = [t.opening_hours && `Einwurfzeiten: ${t.opening_hours}`, t.description, t.note]
    .filter(Boolean).join(' · ');
  return {
    id: `osm-${e.type[0]}${e.id}`,
    lat, lon, glas, papier,
    hof: false,
    name: t.name || '',
    adresse: adresseAus(t),
    betreiber: t.operator || '',
    info,
    quelle: 'osm',
    osm: `https://www.openstreetmap.org/${e.type}/${e.id}`,
  };
}

async function beiServerFragen(text) {
  let letzterFehler;
  for (const server of SERVER) {
    const abbruch = new AbortController();
    const uhr = setTimeout(() => abbruch.abort(), 35000);
    try {
      const antwort = await fetch(server, {
        method: 'POST',
        body: new URLSearchParams({ data: text }),
        signal: abbruch.signal,
      });
      if (!antwort.ok) throw new Error(`Overpass ${antwort.status}`);
      const daten = await antwort.json();
      // Eine Zeitüberschreitung auf dem Server kommt als 200 mit „remark".
      if (daten.remark && /runtime error|timed out|out of memory/i.test(daten.remark)) {
        throw new Error(daten.remark);
      }
      return daten.elements || [];
    } catch (fehler) {
      letzterFehler = fehler;
    } finally {
      clearTimeout(uhr);
    }
  }
  throw letzterFehler || new Error('Overpass nicht erreichbar');
}

async function gruppeLaden(zellen) {
  const elemente = await beiServerFragen(abfrage(zellenGrenzen(zellen)));
  const jeZelle = new Map(zellen.map((z) => [z, []]));
  for (const e of elemente) {
    const ort = standortAus(e);
    if (!ort) continue;
    // Die Abfrage deckt das Rechteck um alle Zellen ab — Treffer außerhalb
    // der angefragten Zellen werden verworfen, nicht falsch einsortiert.
    jeZelle.get(zelleVon(ort.lat, ort.lon))?.push(ort);
  }
  const zeit = Date.now();
  for (const [zelle, orte] of jeZelle) {
    const eintrag = { zeit, orte };
    imSpeicher.set(zelle, eintrag);
    speicher.schreiben(zelle, eintrag);
  }
}

// Fehlende Zellen in rechteckige Gruppen aufteilen: zeilenweise, höchstens
// MAX_ZELLEN_JE_ABFRAGE je Gruppe — sonst fragte ein L-förmiger Rest ein
// riesiges Rechteck ab.
function gruppieren(zellen) {
  const zeilen = new Map();
  for (const z of zellen) {
    const y = z.split(':')[0];
    if (!zeilen.has(y)) zeilen.set(y, []);
    zeilen.get(y).push(z);
  }
  const gruppen = [];
  for (const reihe of zeilen.values()) {
    reihe.sort((a, b) => Number(a.split(':')[1]) - Number(b.split(':')[1]));
    let gruppe = [];
    for (const z of reihe) {
      const x = Number(z.split(':')[1]);
      const vorher = gruppe.length ? Number(gruppe[gruppe.length - 1].split(':')[1]) : null;
      if (gruppe.length && (x !== vorher + 1 || gruppe.length >= MAX_ZELLEN_JE_ABFRAGE)) {
        gruppen.push(gruppe);
        gruppe = [];
      }
      gruppe.push(z);
    }
    if (gruppe.length) gruppen.push(gruppe);
  }
  return gruppen;
}

/**
 * Sorgt dafür, dass die Zellen geladen sind. Liefert { neu, fehler }:
 * `neu` = ob sich etwas geändert hat, `fehler` = ob ein Teil nicht kam
 * (dann gelten ältere Daten vom Gerät, falls vorhanden).
 * Mit `netz: false` wird nur vom Gerät gelesen, nichts abgefragt.
 */
export async function zellenLaden(zellen, { netz = true } = {}) {
  const jetzt = Date.now();
  const fehlend = [];
  let neu = false;

  for (const z of zellen) {
    const da = imSpeicher.get(z);
    if (da && jetzt - da.zeit < FRISCH_MS) continue;
    if (unterwegs.has(z)) continue;
    const gemerkt = await speicher.lesen(z);
    if (gemerkt && Array.isArray(gemerkt.orte)) {
      if (!da || gemerkt.zeit > da.zeit) { imSpeicher.set(z, gemerkt); neu = true; }
      if (jetzt - gemerkt.zeit < FRISCH_MS) continue;
    }
    if (netz) fehlend.push(z);
  }

  let fehler = null;
  const auftraege = gruppieren(fehlend).map((gruppe) => {
    const auftrag = gruppeLaden(gruppe);
    for (const z of gruppe) unterwegs.set(z, auftrag);
    return auftrag
      .then(() => { neu = true; })
      .catch((f) => { fehler = f; })
      .finally(() => { for (const z of gruppe) unterwegs.delete(z); });
  });
  // Laufende Aufträge anderer Aufrufe mit abwarten, damit der Aufrufer danach
  // wirklich alle Zellen hat.
  const fremde = [...new Set(zellen.filter((z) => unterwegs.has(z)).map((z) => unterwegs.get(z)))];
  await Promise.all([...auftraege, ...fremde.map((p) => p.catch(() => {}))]);
  if (neu) speicher.aufraeumen();
  return { neu, fehler };
}

export function laedt() {
  return unterwegs.size > 0;
}

/** Alle OSM-Standorte, die im Speicher liegen. */
export function alleOrte() {
  const orte = [];
  for (const { orte: liste } of imSpeicher.values()) orte.push(...liste);
  return orte;
}

export function zelleBekannt(z) {
  return imSpeicher.has(z);
}
