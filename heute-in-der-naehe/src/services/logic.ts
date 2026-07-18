import type { Place, QuickFilterId, SortMode, WeatherInfo } from '../types';
import { findSub } from './providers/overpass';
import { estimateMinutes } from './geo';
import { isBadWeather, isHot } from './weather';
import type { Dict } from '../i18n/de';

function isIndoor(p: Place): boolean {
  const sub = findSub(p.category, p.subcategory);
  return Boolean(sub?.indoor);
}
function isOutdoor(p: Place): boolean {
  const sub = findSub(p.category, p.subcategory);
  return Boolean(sub?.outdoor);
}

export function applyQuickFilter(places: Place[], filter: QuickFilterId): Place[] {
  switch (filter) {
    case 'all':
      return places;
    case 'open':
      return places.filter((p) => p.opening?.isOpen === true);
    case 'free':
      return places.filter((p) => p.fee === false);
    case 'family':
      return places.filter((p) => p.familyFriendly === true);
    case 'badweather':
      return places.filter((p) => isIndoor(p));
    case 'outdoor':
      return places.filter((p) => isOutdoor(p));
    case 'photospots':
      return places.filter((p) => p.photospot);
    case 'hiddengems':
      return places.filter((p) => p.hiddenGem);
    case 'max15min':
      return places.filter(
        (p) => p.distanceM !== undefined && estimateMinutes(p.distanceM, 'drive') <= 15,
      );
  }
}

/** Popularity proxy from open data: wiki presence + tag richness. */
export function popularityScore(p: Place): number {
  let s = 0;
  if (p.wikipedia) s += 3;
  if (p.wikidataId) s += 2;
  if (p.website) s += 1;
  if (p.opening) s += 1;
  s += Math.min(2, Object.keys(p.tags).length / 10);
  return s;
}

export function sortPlaces(places: Place[], mode: SortMode): Place[] {
  const arr = [...places];
  const dist = (p: Place) => p.distanceM ?? Number.MAX_SAFE_INTEGER;
  switch (mode) {
    case 'distance':
      return arr.sort((a, b) => dist(a) - dist(b));
    case 'rating':
      return arr.sort((a, b) => popularityScore(b) - popularityScore(a) || dist(a) - dist(b));
    case 'open':
      return arr.sort(
        (a, b) =>
          Number(b.opening?.isOpen === true) - Number(a.opening?.isOpen === true) ||
          dist(a) - dist(b),
      );
    case 'free':
      return arr.sort((a, b) => Number(b.fee === false) - Number(a.fee === false) || dist(a) - dist(b));
    case 'photo':
      return arr.sort(
        (a, b) => Number(Boolean(b.photospot)) - Number(Boolean(a.photospot)) || dist(a) - dist(b),
      );
    case 'best':
      return arr.sort((a, b) => bestScore(b) - bestScore(a));
  }
}

function bestScore(p: Place): number {
  const d = p.distanceM ?? 50000;
  let s = popularityScore(p) * 2 - d / 2500;
  if (p.opening?.isOpen) s += 2;
  if (p.fee === false) s += 0.5;
  return s;
}

export interface Recommendation {
  place: Place;
  reasonKey: keyof Dict;
}

/**
 * Context-aware "For you" picks: weather, time of day, distance,
 * opening state and family mode influence the score.
 */
export function recommend(
  places: Place[],
  weather: WeatherInfo | null,
  familyMode: boolean,
  now = new Date(),
): Recommendation[] {
  const hour = now.getHours();
  const evening = hour >= 17;
  const bad = isBadWeather(weather);
  const hot = isHot(weather);

  const scored = places.map((p) => {
    let score = popularityScore(p) - (p.distanceM ?? 30000) / 3000;
    let reasonKey: keyof Dict = 'recReason_near';
    if (bad && isIndoor(p)) {
      score += 4;
      reasonKey = 'recReason_rain';
    } else if (hot && ['beach', 'lake', 'water_park', 'swimming_area', 'ice_cream'].includes(p.subcategory)) {
      score += 4;
      reasonKey = 'recReason_hot';
    } else if (evening && (p.photospot?.kinds.includes('sunset') || p.subcategory === 'restaurant')) {
      score += 3;
      reasonKey = 'recReason_evening';
    } else if (familyMode && p.familyFriendly) {
      score += 3;
      reasonKey = 'recReason_family';
    } else if (p.opening?.isOpen) {
      score += 1;
      reasonKey = 'recReason_open';
    }
    if (familyMode && p.familyFriendly) score += 1.5;
    if (bad && isOutdoor(p)) score -= 3;
    if (p.opening?.isOpen === false) score -= 4;
    return { place: p, reasonKey, score };
  });

  return scored
    .sort((a, b) => b.score - a.score)
    .slice(0, 6)
    .map(({ place, reasonKey }) => ({ place, reasonKey }));
}
