import type { LatLng, Units, UserLocation } from '../types';

const EARTH_R = 6371000;

export function haversineM(a: LatLng, b: LatLng): number {
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(b.lat - a.lat);
  const dLon = toRad(b.lon - a.lon);
  const la1 = toRad(a.lat);
  const la2 = toRad(b.lat);
  const h =
    Math.sin(dLat / 2) ** 2 + Math.cos(la1) * Math.cos(la2) * Math.sin(dLon / 2) ** 2;
  return 2 * EARTH_R * Math.asin(Math.sqrt(h));
}

export function formatDistance(meters: number, units: Units, lang: string): string {
  const nf = (v: number, digits = 1) =>
    v.toLocaleString(lang, { maximumFractionDigits: digits, minimumFractionDigits: 0 });
  if (units === 'imperial') {
    const miles = meters / 1609.344;
    if (miles < 0.19) return `${nf(Math.round(meters * 3.28084 / 10) * 10, 0)} ft`;
    return `${nf(miles, miles < 10 ? 1 : 0)} mi`;
  }
  if (meters < 1000) return `${nf(Math.round(meters / 10) * 10, 0)} m`;
  const km = meters / 1000;
  return `${nf(km, km < 10 ? 1 : 0)} km`;
}

/**
 * Rough travel time estimates (no routing API needed):
 * driving ~ mixed urban/rural average, walking 4.7 km/h, cycling 16 km/h.
 * Road distance is approximated as 1.3 × beeline.
 */
export function estimateMinutes(meters: number, mode: 'drive' | 'walk' | 'bike'): number {
  const road = meters * 1.3;
  const kmh = mode === 'drive' ? (road > 20000 ? 70 : road > 5000 ? 50 : 32) : mode === 'bike' ? 16 : 4.7;
  return Math.max(1, Math.round(road / 1000 / kmh * 60));
}

export function formatMinutes(min: number, lang: string): string {
  if (min < 60) return `${min} min`;
  const h = Math.floor(min / 60);
  const m = min % 60;
  const sep = lang.startsWith('de') ? ' Std ' : ' h ';
  return m ? `${h}${sep}${m} min` : `${h}${sep.trim()}`;
}

/** Radius that corresponds to a given drive time (inverse of estimateMinutes, approx.). */
export function driveMinutesToRadiusM(minutes: number): number {
  const kmh = minutes >= 30 ? 70 : minutes >= 15 ? 55 : 35;
  return Math.round((minutes / 60) * kmh * 1000 / 1.3);
}

export function getCurrentPosition(highAccuracy = true): Promise<UserLocation> {
  return new Promise((resolve, reject) => {
    if (!('geolocation' in navigator)) {
      reject(new Error('unsupported'));
      return;
    }
    navigator.geolocation.getCurrentPosition(
      (pos) =>
        resolve({
          lat: pos.coords.latitude,
          lon: pos.coords.longitude,
          accuracy: pos.coords.accuracy,
          source: 'gps',
          timestamp: Date.now(),
        }),
      (err) => reject(err),
      { enableHighAccuracy: highAccuracy, timeout: 12000, maximumAge: 60000 },
    );
  });
}

export function isPermissionDenied(err: unknown): boolean {
  return (
    typeof err === 'object' &&
    err !== null &&
    'code' in err &&
    (err as GeolocationPositionError).code === 1
  );
}
