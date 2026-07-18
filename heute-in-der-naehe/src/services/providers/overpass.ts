import type { CategoryId, Place, PhotospotInfo, SearchQuery } from '../../types';
import { CATEGORIES, HIGHLIGHT_SUBS, getCategory, type SubcategoryDef } from '../../config/categories';
import { getCountryConfig, matchBrand } from '../../config/brands';
import { haversineM } from '../geo';
import { isOpenNow } from '../openingHours';
import type { PlaceProvider } from './types';

/**
 * Public Overpass instances, tried in order with automatic failover.
 * Health-verified 2026-07 (see .github/workflows/overpass-check.yml):
 * z.overpass-api.de is pinned directly because the overpass-api.de
 * round-robin also routes to a broken backend (lz4 → 406); the French
 * and VK instances host full planet data and send CORS headers. The
 * last working endpoint is remembered across sessions. Override the
 * list via VITE_OVERPASS_URL (comma-separated).
 */
const DEFAULT_ENDPOINTS = [
  'https://z.overpass-api.de/api/interpreter',
  'https://overpass.openstreetmap.fr/api/interpreter',
  'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
];
const ENDPOINTS = (import.meta.env.VITE_OVERPASS_URL
  ? String(import.meta.env.VITE_OVERPASS_URL).split(',')
  : DEFAULT_ENDPOINTS
)
  .map((s) => s.trim())
  .filter(Boolean);

const EP_KEY = 'hin-overpass-ep';
let preferredEp = 0;
try {
  // stored by URL so a changed endpoint list can never revive a stale index
  const saved = localStorage.getItem(EP_KEY);
  const idx = saved ? ENDPOINTS.indexOf(saved) : -1;
  if (idx >= 0) preferredEp = idx;
} catch {
  /* storage unavailable */
}

/** Start the next mirror if the current one hasn't answered after this long. */
const HEDGE_DELAY_MS = 5000;
/** Hard per-endpoint timeout. */
const ENDPOINT_TIMEOUT_MS = 25000;

function rememberEndpoint(idx: number): void {
  if (idx === preferredEp) return;
  preferredEp = idx;
  try {
    localStorage.setItem(EP_KEY, ENDPOINTS[idx]);
  } catch {
    /* non-fatal */
  }
}

/**
 * Hedged failover: query the preferred endpoint first; if it hasn't
 * answered within HEDGE_DELAY_MS (or fails outright), the next mirror is
 * queried in parallel. The first successful response wins and the rest
 * are aborted – a hanging server no longer blocks the search for its
 * full timeout.
 */
function overpassFetch(query: string, signal?: AbortSignal): Promise<unknown> {
  const order = ENDPOINTS.map((_, i) => (preferredEp + i) % ENDPOINTS.length);
  return new Promise((resolve, reject) => {
    const controllers: AbortController[] = [];
    const timers: ReturnType<typeof setTimeout>[] = [];
    let started = 0;
    let failures = 0;
    let settled = false;
    let lastError: unknown = new Error('overpass:unavailable');

    const finish = (fn: () => void) => {
      settled = true;
      timers.forEach(clearTimeout);
      controllers.forEach((c) => c.abort());
      fn();
    };

    const onOuterAbort = () => {
      if (!settled) finish(() => reject(new DOMException('aborted', 'AbortError')));
    };
    signal?.addEventListener('abort', onOuterAbort, { once: true });

    const startNext = () => {
      if (settled || started >= order.length) return;
      const idx = order[started++];
      const ctrl = new AbortController();
      controllers.push(ctrl);
      timers.push(setTimeout(() => ctrl.abort(), ENDPOINT_TIMEOUT_MS));
      timers.push(setTimeout(startNext, HEDGE_DELAY_MS));

      fetch(ENDPOINTS[idx], {
        method: 'POST',
        body: 'data=' + encodeURIComponent(query),
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        signal: ctrl.signal,
      })
        .then(async (res) => {
          if (!res.ok) throw new Error(`overpass:${res.status}`);
          return res.json();
        })
        .then((data) => {
          if (settled) return;
          rememberEndpoint(idx);
          finish(() => resolve(data));
        })
        .catch((err) => {
          if (settled) return;
          if (signal?.aborted) {
            finish(() => reject(err));
            return;
          }
          lastError = err;
          failures++;
          if (failures >= order.length) finish(() => reject(lastError));
          else startNext(); // hard failure → don't wait for the hedge timer
        });
    };

    startNext();
  });
}

interface OverpassElement {
  type: 'node' | 'way' | 'relation';
  id: number;
  lat?: number;
  lon?: number;
  center?: { lat: number; lon: number };
  tags?: Record<string, string>;
}

function selectorToFilter(selector: string): string {
  // 'key=value' → ["key"="value"], 'key~"re"' → ["key"~"re"], chained '][' supported
  return (
    '[' +
    selector
      .split('][')
      .map((s) => {
        const tilde = s.indexOf('~');
        const eq = s.indexOf('=');
        if (tilde > -1 && (eq === -1 || tilde < eq)) {
          const key = s.slice(0, tilde);
          let re = s.slice(tilde + 1);
          if (!re.startsWith('"')) re = `"${re}"`;
          return `"${key}"~${re}`;
        }
        const key = s.slice(0, eq);
        const value = s.slice(eq + 1);
        return `"${key}"="${value}"`;
      })
      .join('][') +
    ']'
  );
}

function buildQuery(
  subs: { cat: CategoryId; sub: SubcategoryDef }[],
  query: SearchQuery,
): string {
  const { center, radiusM } = query;
  const around = `(around:${Math.round(radiusM)},${center.lat.toFixed(6)},${center.lon.toFixed(6)})`;
  const clauses = subs
    .flatMap(({ sub }) =>
      sub.selectors.map((sel) => {
        const nameFilter = sub.named ? '["name"]' : '';
        return `nwr${selectorToFilter(sel)}${nameFilter}${around};`;
      }),
    )
    .join('\n  ');
  return `[out:json][timeout:25];\n(\n  ${clauses}\n);\nout center 500;`;
}

function matchesSelector(tags: Record<string, string>, selector: string): boolean {
  return selector.split('][').every((s) => {
    const tilde = s.indexOf('~');
    const eq = s.indexOf('=');
    if (tilde > -1 && (eq === -1 || tilde < eq)) {
      const key = s.slice(0, tilde);
      let re = s.slice(tilde + 1);
      if (re.startsWith('"') && re.endsWith('"')) re = re.slice(1, -1);
      const v = tags[key];
      if (!v) return false;
      try {
        return new RegExp(re).test(v);
      } catch {
        return false;
      }
    }
    const key = s.slice(0, eq);
    const value = s.slice(eq + 1);
    return tags[key] === value;
  });
}

function classify(
  tags: Record<string, string>,
  subs: { cat: CategoryId; sub: SubcategoryDef }[],
): { cat: CategoryId; sub: SubcategoryDef } | null {
  for (const entry of subs) {
    if (entry.sub.selectors.some((sel) => matchesSelector(tags, sel))) return entry;
  }
  return null;
}

function parseBool(v: string | undefined): boolean | undefined {
  if (v === undefined) return undefined;
  if (['yes', 'designated', 'permissive', 'limited'].includes(v)) return true;
  if (v === 'no') return false;
  return undefined;
}

function parseFee(tags: Record<string, string>, sub: SubcategoryDef): boolean | undefined {
  const fee = tags.fee;
  if (fee === 'no') return false;
  if (fee === 'yes') return true;
  if (sub.typicallyFree) return false;
  return undefined;
}

function buildAddress(tags: Record<string, string>): string | undefined {
  const street = tags['addr:street'];
  const nr = tags['addr:housenumber'];
  const city = tags['addr:city'];
  const parts = [street ? `${street}${nr ? ' ' + nr : ''}` : undefined, city].filter(Boolean);
  return parts.length ? parts.join(', ') : undefined;
}

function photospotInfo(sub: SubcategoryDef, tags: Record<string, string>): PhotospotInfo | undefined {
  if (!sub.photo) return undefined;
  const kinds = [...sub.photo];
  const at = tags.artwork_type?.toLowerCase();
  if (at && ['mural', 'graffiti', 'streetart', 'street_art'].includes(at) && !kinds.includes('streetart')) {
    kinds.push('streetart');
  }
  let direction: number | undefined;
  const dir = tags.direction ?? tags['camera:direction'];
  if (dir && /^\d+$/.test(dir)) direction = parseInt(dir, 10) % 360;
  return { kinds, bestTime: sub.bestTime ?? 'day', tip: sub.photoTip ?? 'tip_generic', direction };
}

/** Build the subcategory set for a query (category, highlights or photospots). */
export function subsForQuery(query: SearchQuery): { cat: CategoryId; sub: SubcategoryDef }[] {
  const result: { cat: CategoryId; sub: SubcategoryDef }[] = [];
  if (query.category) {
    const cat = getCategory(query.category);
    for (const sub of cat.sub) result.push({ cat: cat.id, sub });
  } else {
    for (const [catId, subId] of HIGHLIGHT_SUBS) {
      const sub = getCategory(catId).sub.find((s) => s.id === subId);
      if (sub) result.push({ cat: catId, sub });
    }
  }
  // Country-specific extras (configurable, see config/brands.ts)
  const cc = getCountryConfig(query.countryCode);
  if (cc?.regionalExtras && !query.category) {
    for (const extra of cc.regionalExtras) {
      result.push({
        cat: 'culture',
        sub: {
          id: extra.id,
          labels: extra.labels,
          selectors: extra.selectors,
          named: extra.named,
        },
      });
    }
  }
  return result;
}

export const overpassProvider: PlaceProvider = {
  id: 'osm',
  attribution: '© OpenStreetMap contributors (ODbL)',
  isAvailable: () => true,

  async search(query: SearchQuery, signal?: AbortSignal): Promise<Place[]> {
    const subs = subsForQuery(query);
    const q = buildQuery(subs, query);
    const data = (await overpassFetch(q, signal)) as { elements: OverpassElement[] };

    const places: Place[] = [];
    for (const el of data.elements) {
      const tags = el.tags ?? {};
      const lat = el.lat ?? el.center?.lat;
      const lon = el.lon ?? el.center?.lon;
      if (lat === undefined || lon === undefined) continue;
      const cls = classify(tags, subs);
      if (!cls) continue;
      const { cat, sub } = cls;
      const opening = tags.opening_hours
        ? { raw: tags.opening_hours, isOpen: isOpenNow(tags.opening_hours) }
        : undefined;
      const wiki = tags.wikipedia;
      const photospot = photospotInfo(sub, tags);
      const hasWiki = Boolean(wiki || tags.wikidata);
      places.push({
        id: `osm:${el.type}/${el.id}`,
        source: 'osm',
        name: tags.name ?? tags['name:en'] ?? sub.labels.en,
        lat,
        lon,
        category: cat,
        subcategory: sub.id,
        tags,
        distanceM: haversineM(query.center, { lat, lon }),
        address: buildAddress(tags),
        website: tags.website ?? tags['contact:website'],
        phone: tags.phone ?? tags['contact:phone'],
        opening,
        fee: parseFee(tags, sub),
        wheelchair: parseBool(tags.wheelchair),
        dogFriendly: parseBool(tags.dog),
        toilets: parseBool(tags.toilets) ?? (tags.amenity === 'toilets' ? true : undefined),
        parking: tags.parking ? true : undefined,
        familyFriendly: sub.family ? true : undefined,
        wikidataId: tags.wikidata,
        wikipedia: wiki,
        description: tags.description,
        isBrand: matchBrand(tags, query.countryCode),
        // photogenic place with a name but no Wikipedia presence → likely a local secret
        hiddenGem: Boolean(photospot) && Boolean(tags.name) && !hasWiki,
        photospot,
      });
    }
    return places;
  },
};

/** Subcategory metadata lookup used by UI components. */
export function findSub(cat: CategoryId, subId: string): SubcategoryDef | undefined {
  return CATEGORIES.find((c) => c.id === cat)?.sub.find((s) => s.id === subId);
}
