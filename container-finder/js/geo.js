// Kleine Geometrie: Entfernungen, Rasterzellen, Anzeige.

const ERDRADIUS = 6371000;

export function abstandM(aLat, aLon, bLat, bLon) {
  const rad = Math.PI / 180;
  const p1 = aLat * rad;
  const p2 = bLat * rad;
  const dp = (bLat - aLat) * rad;
  const dl = (bLon - aLon) * rad;
  const h = Math.sin(dp / 2) ** 2 + Math.cos(p1) * Math.cos(p2) * Math.sin(dl / 2) ** 2;
  return 2 * ERDRADIUS * Math.asin(Math.sqrt(h));
}

export function entfernungText(meter) {
  if (meter < 950) return `${Math.max(10, Math.round(meter / 10) * 10)} m`;
  const km = meter / 1000;
  return `${km.toLocaleString('de-DE', { maximumFractionDigits: km < 10 ? 1 : 0 })} km`;
}

// OSM-Daten werden in festen Zellen geladen und gemerkt. Feste Zellen statt
// „genau der Ausschnitt": Ein verschobener Ausschnitt fragt nur die neuen
// Zellen nach, und der Speicher auf dem Gerät hat einen festen Schlüssel.
// 0,1° ≈ 11 km × 7 km — ein iPhone-Ausschnitt bei Zoom 13 berührt 2–4 Zellen.
export const ZELLE = 0.1;

export function zellenIm(sued, west, nord, ost) {
  const zellen = [];
  for (let y = Math.floor(sued / ZELLE); y <= Math.floor(nord / ZELLE); y += 1) {
    for (let x = Math.floor(west / ZELLE); x <= Math.floor(ost / ZELLE); x += 1) {
      zellen.push(`${y}:${x}`);
    }
  }
  return zellen;
}

export function zellenUm(lat, lon, radiusM) {
  const dLat = radiusM / 111320;
  const dLon = radiusM / (111320 * Math.cos((lat * Math.PI) / 180));
  return zellenIm(lat - dLat, lon - dLon, lat + dLat, lon + dLon);
}

export function zelleVon(lat, lon) {
  return `${Math.floor(lat / ZELLE)}:${Math.floor(lon / ZELLE)}`;
}

export function zellenGrenzen(zellen) {
  let s = Infinity; let w = Infinity; let n = -Infinity; let o = -Infinity;
  for (const z of zellen) {
    const [y, x] = z.split(':').map(Number);
    s = Math.min(s, y * ZELLE); n = Math.max(n, (y + 1) * ZELLE);
    w = Math.min(w, x * ZELLE); o = Math.max(o, (x + 1) * ZELLE);
  }
  // Auf sechs Stellen runden — sonst stehen 51.300000000000004 in der Abfrage.
  const r = (v) => Math.round(v * 1e6) / 1e6;
  return [r(s), r(w), r(n), r(o)];
}
