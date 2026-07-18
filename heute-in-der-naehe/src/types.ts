// ---------- Geo ----------
export interface LatLng {
  lat: number;
  lon: number;
}

export type LocationSource = 'gps' | 'manual' | 'map' | 'recent' | 'fallback';

export interface UserLocation extends LatLng {
  accuracy?: number; // meters
  label?: string; // human readable ("Toronto, Kanada")
  countryCode?: string; // ISO 3166-1 alpha-2, lowercase
  source: LocationSource;
  timestamp: number;
}

// ---------- Categories ----------
export type CategoryId =
  | 'nature'
  | 'photospots'
  | 'food'
  | 'family'
  | 'sports'
  | 'shopping'
  | 'culture'
  | 'essentials';

export type QuickFilterId =
  | 'all'
  | 'open'
  | 'free'
  | 'family'
  | 'badweather'
  | 'outdoor'
  | 'photospots'
  | 'hiddengems'
  | 'max15min';

// ---------- Places ----------
export interface OpeningInfo {
  raw?: string; // raw OSM opening_hours string
  isOpen?: boolean; // undefined = unknown
}

export interface Place {
  id: string; // provider-prefixed stable id, e.g. "osm:node/123"
  source: string; // provider id
  name: string;
  lat: number;
  lon: number;
  category: CategoryId;
  subcategory: string; // i18n key within category, e.g. "waterfall"
  tags: Record<string, string>; // raw provider tags
  distanceM?: number; // from current search origin
  address?: string;
  website?: string;
  phone?: string;
  opening?: OpeningInfo;
  fee?: boolean; // true = costs money, false = free, undefined = unknown
  wheelchair?: boolean;
  dogFriendly?: boolean;
  familyFriendly?: boolean;
  toilets?: boolean;
  parking?: boolean;
  wikidataId?: string;
  wikipedia?: string;
  imageUrl?: string; // resolved lazily
  description?: string;
  isBrand?: boolean; // matched a configured local brand/chain
  hiddenGem?: boolean; // heuristics: interesting but low-profile
  photospot?: PhotospotInfo;
}

export interface PhotospotInfo {
  kinds: string[]; // sunrise | sunset | panorama | architecture | nature | water | night | streetart | family | quiet | easy
  bestTime?: 'sunrise' | 'sunset' | 'day' | 'night' | 'bluehour';
  tip?: string; // i18n key of a generic tip
  direction?: number; // suggested viewing direction, degrees
}

// ---------- Favorites / collections ----------
export interface FavoriteEntry {
  placeId: string;
  place: Place; // snapshot for offline use
  addedAt: number;
  lists: string[]; // user defined list names
  note?: string;
}

export interface VisitedEntry {
  placeId: string;
  place: Place;
  visitedAt: number;
  rating?: number; // 1..5
  comment?: string;
}

// ---------- Search ----------
export type SortMode =
  | 'distance'
  | 'rating'
  | 'open'
  | 'free'
  | 'best'
  | 'photo';

export interface SearchQuery {
  center: LatLng;
  radiusM: number;
  category?: CategoryId;
  filter?: QuickFilterId;
  countryCode?: string;
}

export interface SearchResult {
  places: Place[];
  fetchedAt: number;
  fromCache: boolean;
  partial?: boolean; // some providers failed
  providerErrors?: string[];
}

// ---------- Weather ----------
export interface WeatherInfo {
  temperatureC: number;
  weatherCode: number; // WMO code
  isDay: boolean;
  windKmh?: number;
  fetchedAt: number;
}

// ---------- Settings ----------
export type Units = 'metric' | 'imperial';
export type ThemeMode = 'auto' | 'light' | 'dark';
export type Lang = 'de' | 'en' | 'fr';
export type NavApp = 'google' | 'apple' | 'waze' | 'osm';
export type TravelMode = 'drive' | 'walk' | 'bike' | 'transit';

export interface Settings {
  lang: Lang | 'auto';
  theme: ThemeMode;
  units: Units | 'auto';
  tempUnit: 'c' | 'f' | 'auto';
  defaultRadiusM: number;
  preferredNavApp: NavApp;
  familyMode: boolean;
  reducedData: boolean;
  hiddenCategories: CategoryId[];
}

export const DEFAULT_SETTINGS: Settings = {
  lang: 'auto',
  theme: 'auto',
  units: 'auto',
  tempUnit: 'auto',
  defaultRadiusM: 10000,
  preferredNavApp: 'google',
  familyMode: false,
  reducedData: false,
  hiddenCategories: [],
};
