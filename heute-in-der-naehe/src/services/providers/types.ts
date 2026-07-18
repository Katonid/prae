import type { Place, SearchQuery } from '../../types';

/**
 * Provider abstraction: any POI source (Overpass, Google Places via proxy,
 * Foursquare, local open-data portals …) implements this interface and is
 * registered in `providers/index.ts`. Results from all enabled providers
 * are merged and de-duplicated.
 */
export interface PlaceProvider {
  id: string;
  /** Human-readable attribution shown in the UI/README. */
  attribution: string;
  /** Whether this provider can serve the given query (e.g. needs an API key). */
  isAvailable(): boolean;
  search(query: SearchQuery, signal?: AbortSignal): Promise<Place[]>;
}

export interface GeocodeResult {
  lat: number;
  lon: number;
  label: string;
  countryCode?: string;
}

export interface GeocodeProvider {
  id: string;
  search(text: string, lang: string, signal?: AbortSignal): Promise<GeocodeResult[]>;
  reverse(lat: number, lon: number, lang: string, signal?: AbortSignal): Promise<GeocodeResult | null>;
}
