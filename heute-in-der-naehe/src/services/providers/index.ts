import type { Place, SearchQuery, SearchResult } from '../../types';
import { overpassProvider } from './overpass';
import { nominatimProvider } from './nominatim';
import type { PlaceProvider } from './types';
import { haversineM } from '../geo';
import { getCachedSearch, putCachedSearch } from '../cache';

/**
 * Provider registry. To add a source (e.g. a server-side Google Places
 * proxy), implement PlaceProvider and append it here – merging and
 * de-duplication happen automatically.
 */
const providers: PlaceProvider[] = [overpassProvider];

export const geocoder = nominatimProvider;

function normalizeName(name: string): string {
  return name.toLowerCase().replace(/[^\p{L}\p{N}]+/gu, ' ').trim();
}

/**
 * Merge duplicate places across providers: same normalized name within 150 m
 * (or identical id). The entry with more filled fields wins; missing fields
 * are backfilled from the duplicate.
 */
export function dedupePlaces(places: Place[]): Place[] {
  const byId = new Map<string, Place>();
  const result: Place[] = [];
  for (const p of places) {
    if (byId.has(p.id)) continue;
    byId.set(p.id, p);
    const key = normalizeName(p.name);
    const dup = result.find(
      (q) =>
        normalizeName(q.name) === key &&
        key.length > 2 &&
        haversineM(p, q) < 150,
    );
    if (dup) {
      // backfill missing fields on the kept entry
      for (const field of ['website', 'phone', 'address', 'opening', 'imageUrl', 'wikidataId', 'wikipedia', 'description'] as const) {
        if (dup[field] === undefined && p[field] !== undefined) {
          (dup as unknown as Record<string, unknown>)[field] = p[field];
        }
      }
      continue;
    }
    result.push(p);
  }
  return result;
}

/**
 * Search all available providers, merge + dedupe, sort by distance.
 * Falls back to cached results when offline or when every provider fails.
 */
export async function searchPlaces(
  query: SearchQuery,
  signal?: AbortSignal,
): Promise<SearchResult> {
  const cached = await getCachedSearch(query);
  if (cached && Date.now() - cached.fetchedAt < 5 * 60 * 1000) {
    return { ...cached, fromCache: true };
  }

  const active = providers.filter((p) => p.isAvailable());
  const settled = await Promise.allSettled(active.map((p) => p.search(query, signal)));
  const places: Place[] = [];
  const errors: string[] = [];
  settled.forEach((s, i) => {
    if (s.status === 'fulfilled') places.push(...s.value);
    else errors.push(active[i].id);
  });

  if (!places.length && errors.length === active.length) {
    if (cached) return { ...cached, fromCache: true, partial: true, providerErrors: errors };
    throw new Error('all-providers-failed');
  }

  const deduped = dedupePlaces(places).sort(
    (a, b) => (a.distanceM ?? 0) - (b.distanceM ?? 0),
  );
  const result: SearchResult = {
    places: deduped,
    fetchedAt: Date.now(),
    fromCache: false,
    partial: errors.length > 0,
    providerErrors: errors.length ? errors : undefined,
  };
  await putCachedSearch(query, result);
  return result;
}
