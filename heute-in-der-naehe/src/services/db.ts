/**
 * Local persistence via IndexedDB (idb). Everything stays on-device:
 * favorites (with place snapshots for offline use), visited history,
 * cached search results and recently used locations.
 */
import { openDB, type DBSchema, type IDBPDatabase } from 'idb';
import type { FavoriteEntry, SearchResult, UserLocation, VisitedEntry } from '../types';

interface AppDB extends DBSchema {
  favorites: { key: string; value: FavoriteEntry };
  visited: { key: string; value: VisitedEntry };
  searchCache: { key: string; value: SearchResult & { cacheKey: string } };
  recentLocations: { key: number; value: UserLocation };
}

let dbPromise: Promise<IDBPDatabase<AppDB>> | null = null;

export function getDB(): Promise<IDBPDatabase<AppDB>> {
  if (!dbPromise) {
    dbPromise = openDB<AppDB>('heute-in-der-naehe', 1, {
      upgrade(db) {
        db.createObjectStore('favorites', { keyPath: 'placeId' });
        db.createObjectStore('visited', { keyPath: 'placeId' });
        db.createObjectStore('searchCache', { keyPath: 'cacheKey' });
        db.createObjectStore('recentLocations', { keyPath: 'timestamp' });
      },
    });
  }
  return dbPromise;
}

// ---- favorites ----
export async function getFavorites(): Promise<FavoriteEntry[]> {
  return (await getDB()).getAll('favorites');
}
export async function putFavorite(entry: FavoriteEntry): Promise<void> {
  await (await getDB()).put('favorites', entry);
}
export async function removeFavorite(placeId: string): Promise<void> {
  await (await getDB()).delete('favorites', placeId);
}

// ---- visited ----
export async function getVisited(): Promise<VisitedEntry[]> {
  return (await getDB()).getAll('visited');
}
export async function putVisited(entry: VisitedEntry): Promise<void> {
  await (await getDB()).put('visited', entry);
}

// ---- search cache ----
export async function dbGetSearch(cacheKey: string) {
  return (await getDB()).get('searchCache', cacheKey);
}
export async function dbPutSearch(value: SearchResult & { cacheKey: string }) {
  const db = await getDB();
  await db.put('searchCache', value);
  // keep the cache bounded
  const keys = await db.getAllKeys('searchCache');
  if (keys.length > 40) {
    const all = await db.getAll('searchCache');
    all.sort((a, b) => a.fetchedAt - b.fetchedAt);
    for (const old of all.slice(0, all.length - 40)) {
      await db.delete('searchCache', old.cacheKey);
    }
  }
}

// ---- recent locations ----
export async function getRecentLocations(): Promise<UserLocation[]> {
  const all = await (await getDB()).getAll('recentLocations');
  return all.sort((a, b) => b.timestamp - a.timestamp).slice(0, 5);
}
export async function addRecentLocation(loc: UserLocation): Promise<void> {
  const db = await getDB();
  await db.put('recentLocations', loc);
  const all = await db.getAll('recentLocations');
  if (all.length > 8) {
    all.sort((a, b) => a.timestamp - b.timestamp);
    for (const old of all.slice(0, all.length - 8)) {
      await db.delete('recentLocations', old.timestamp);
    }
  }
}

/** Privacy: wipe everything (IndexedDB + localStorage + SW caches). */
export async function deleteAllLocalData(): Promise<void> {
  const db = await getDB();
  await Promise.all([
    db.clear('favorites'),
    db.clear('visited'),
    db.clear('searchCache'),
    db.clear('recentLocations'),
  ]);
  localStorage.clear();
  if ('caches' in window) {
    const names = await caches.keys();
    await Promise.all(names.map((n) => caches.delete(n)));
  }
}
