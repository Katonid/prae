/**
 * Lazy preview image resolution via open sources:
 *  1. OSM `image` tag (direct URL)
 *  2. Wikimedia Commons (P18) via the `wikidata` tag
 *  3. Wikipedia page image via the `wikipedia` tag
 *  4. Nearest geotagged Wikimedia Commons photo (within ~250 m)
 * Results are memoized; `null` means "no photo found" – the UI then falls
 * back to a map-tile thumbnail (see tileThumb) so every hit has a preview.
 */
import type { Place } from '../types';

const memo = new Map<string, Promise<string | null>>();

async function fetchWikidataImage(wikidataId: string): Promise<string | null> {
  const url = `https://www.wikidata.org/wiki/Special:EntityData/${wikidataId}.json`;
  const res = await fetch(url);
  if (!res.ok) return null;
  const data = await res.json();
  const claims = data?.entities?.[wikidataId]?.claims?.P18;
  const file: string | undefined = claims?.[0]?.mainsnak?.datavalue?.value;
  if (!file) return null;
  return `https://commons.wikimedia.org/wiki/Special:FilePath/${encodeURIComponent(file)}?width=480`;
}

const PHOTO_EXT = /\.(jpe?g|png|webp)$/i;

async function fetchCommonsNearbyImage(
  lat: number,
  lon: number,
  placeName?: string,
): Promise<string | null> {
  const url =
    'https://commons.wikimedia.org/w/api.php?action=query&list=geosearch&gsnamespace=6' +
    `&gscoord=${lat.toFixed(5)}%7C${lon.toFixed(5)}&gsradius=250&gslimit=20&format=json&origin=*`;
  const res = await fetch(url);
  if (!res.ok) return null;
  const data = await res.json();
  const items: { title: string }[] = data?.query?.geosearch ?? [];
  const photos = items.filter((i) => PHOTO_EXT.test(i.title));
  if (!photos.length) return null;
  // Prefer a photo whose file name mentions the place; else take the nearest.
  const words = (placeName ?? '')
    .toLowerCase()
    .split(/[^\p{L}\p{N}]+/u)
    .filter((w) => w.length > 3);
  const match = words.length
    ? photos.find((i) => {
        const t = i.title.toLowerCase();
        return words.some((w) => t.includes(w));
      })
    : undefined;
  const name = (match ?? photos[0]).title.replace(/^File:/, '');
  return `https://commons.wikimedia.org/wiki/Special:FilePath/${encodeURIComponent(name)}?width=480`;
}

async function fetchWikipediaImage(wikipedia: string): Promise<string | null> {
  const [lang, ...titleParts] = wikipedia.split(':');
  const title = titleParts.join(':');
  if (!lang || !title) return null;
  const url = `https://${lang}.wikipedia.org/api/rest_v1/page/summary/${encodeURIComponent(title)}`;
  const res = await fetch(url);
  if (!res.ok) return null;
  const data = await res.json();
  return data?.thumbnail?.source ?? null;
}

export function resolveImage(place: Place): Promise<string | null> {
  const cached = memo.get(place.id);
  if (cached) return cached;
  const p = (async () => {
    try {
      const direct = place.tags.image;
      if (direct?.startsWith('https://')) return direct;
      if (place.wikidataId && /^Q\d+$/.test(place.wikidataId)) {
        const img = await fetchWikidataImage(place.wikidataId);
        if (img) return img;
      }
      if (place.wikipedia) {
        const img = await fetchWikipediaImage(place.wikipedia);
        if (img) return img;
      }
      return await fetchCommonsNearbyImage(place.lat, place.lon, place.name);
    } catch {
      return null;
    }
  })();
  memo.set(place.id, p);
  return p;
}

/**
 * Guaranteed fallback preview: a small crop of the OSM raster tile around
 * the place, positioned so the POI sits in the middle (clamped at tile
 * edges). Works offline for recently viewed areas via the SW tile cache.
 */
export function tileThumb(lat: number, lon: number, sizePx = 74) {
  const z = 16;
  const n = 2 ** z;
  const xf = ((lon + 180) / 360) * n;
  const latRad = (lat * Math.PI) / 180;
  const yf = ((1 - Math.log(Math.tan(latRad) + 1 / Math.cos(latRad)) / Math.PI) / 2) * n;
  const x = Math.floor(xf);
  const y = Math.floor(yf);
  const px = (xf - x) * 256;
  const py = (yf - y) * 256;
  const half = sizePx / 2;
  const offX = Math.min(Math.max(px - half, 0), 256 - sizePx);
  const offY = Math.min(Math.max(py - half, 0), 256 - sizePx);
  return {
    url: `https://a.tile.openstreetmap.org/${z}/${x}/${y}.png`,
    objectPosition: `-${offX}px -${offY}px`,
    pinLeft: px - offX,
    pinTop: py - offY,
  };
}
