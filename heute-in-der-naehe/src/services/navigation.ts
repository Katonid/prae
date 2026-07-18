import type { NavApp, Place, TravelMode } from '../types';

/**
 * Hand-off to external navigation apps – no own turn-by-turn routing.
 * All links are universal URLs that work on iOS, Android and desktop.
 */

const GOOGLE_MODES: Record<TravelMode, string> = {
  drive: 'driving',
  walk: 'walking',
  bike: 'bicycling',
  transit: 'transit',
};

const APPLE_MODES: Record<TravelMode, string> = {
  drive: 'd',
  walk: 'w',
  bike: 'w', // Apple Maps URL API has no cycling flag – falls back to walking
  transit: 'r',
};

export function buildNavUrl(app: NavApp, place: Place, mode: TravelMode): string {
  const dest = `${place.lat},${place.lon}`;
  const name = encodeURIComponent(place.name);
  switch (app) {
    case 'google':
      return `https://www.google.com/maps/dir/?api=1&destination=${dest}&travelmode=${GOOGLE_MODES[mode]}`;
    case 'apple':
      return `https://maps.apple.com/?daddr=${dest}&q=${name}&dirflg=${APPLE_MODES[mode]}`;
    case 'waze':
      return `https://waze.com/ul?ll=${dest}&navigate=yes`;
    case 'osm':
      return `https://www.openstreetmap.org/directions?to=${place.lat}%2C${place.lon}`;
  }
}

export const NAV_APPS: { id: NavApp; label: string }[] = [
  { id: 'google', label: 'Google Maps' },
  { id: 'apple', label: 'Apple Karten' },
  { id: 'waze', label: 'Waze' },
  { id: 'osm', label: 'OpenStreetMap' },
];

export function isAppleDevice(): boolean {
  return /iPhone|iPad|iPod|Macintosh/.test(navigator.userAgent);
}
