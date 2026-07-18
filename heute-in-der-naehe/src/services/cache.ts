/**
 * Search result caching: in-memory for the session plus IndexedDB for
 * offline fallback. The cache key rounds coordinates (~300 m grid) and
 * radius so panning a few meters doesn't refetch.
 */
import type { SearchQuery, SearchResult } from '../types';
import { dbGetSearch, dbPutSearch } from './db';

const mem = new Map<string, SearchResult>();

export function searchCacheKey(q: SearchQuery): string {
  const lat = q.center.lat.toFixed(3);
  const lon = q.center.lon.toFixed(3);
  const r = Math.round(q.radiusM / 500) * 500;
  return `${q.category ?? 'all'}|${q.filter ?? '-'}|${lat},${lon}|${r}|${q.countryCode ?? ''}`;
}

export async function getCachedSearch(q: SearchQuery): Promise<SearchResult | null> {
  const key = searchCacheKey(q);
  const inMem = mem.get(key);
  if (inMem) return inMem;
  try {
    const fromDb = await dbGetSearch(key);
    if (fromDb) {
      mem.set(key, fromDb);
      return fromDb;
    }
  } catch {
    // IndexedDB unavailable (private mode) – memory cache still works
  }
  return null;
}

export async function putCachedSearch(q: SearchQuery, r: SearchResult): Promise<void> {
  const key = searchCacheKey(q);
  mem.set(key, r);
  try {
    await dbPutSearch({ ...r, cacheKey: key });
  } catch {
    /* non-fatal */
  }
}
