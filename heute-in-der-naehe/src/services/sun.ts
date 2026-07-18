/**
 * Minimal astronomical calculations (NOAA-based) for sunrise/sunset and
 * solar position – no external API or library required.
 */
import type { LatLng } from '../types';

const rad = Math.PI / 180;

function toDays(date: Date): number {
  return date.getTime() / 86400000 - 0.5 + 2440588 - 2451545;
}

function solarMeanAnomaly(d: number): number {
  return rad * (357.5291 + 0.98560028 * d);
}

function eclipticLongitude(M: number): number {
  const C = rad * (1.9148 * Math.sin(M) + 0.02 * Math.sin(2 * M) + 0.0003 * Math.sin(3 * M));
  const P = rad * 102.9372;
  return M + C + P + Math.PI;
}

const e = rad * 23.4397; // obliquity

function declination(L: number): number {
  return Math.asin(Math.sin(e) * Math.sin(L));
}
function rightAscension(L: number): number {
  return Math.atan2(Math.sin(L) * Math.cos(e), Math.cos(L));
}
function siderealTime(d: number, lw: number): number {
  return rad * (280.16 + 360.9856235 * d) - lw;
}

export interface SunTimes {
  sunrise: Date | null;
  sunset: Date | null;
}

function hourAngle(h: number, phi: number, dec: number): number {
  const cosH =
    (Math.sin(h) - Math.sin(phi) * Math.sin(dec)) / (Math.cos(phi) * Math.cos(dec));
  if (cosH < -1 || cosH > 1) return NaN; // polar day/night
  return Math.acos(cosH);
}

function fromJulian(j: number): Date {
  return new Date((j + 0.5 - 2440588 + 2451545) * 86400000);
}

export function getSunTimes(date: Date, pos: LatLng): SunTimes {
  const lw = rad * -pos.lon;
  const phi = rad * pos.lat;
  const d = toDays(date);
  const n = Math.round(d - 0.0009 - lw / (2 * Math.PI));
  const ds = 0.0009 + lw / (2 * Math.PI) + n;
  const M = solarMeanAnomaly(ds);
  const L = eclipticLongitude(M);
  const dec = declination(L);
  const Jnoon = 2451545 + ds + 0.0053 * Math.sin(M) - 0.0069 * Math.sin(2 * L);
  const w = hourAngle(rad * -0.833, phi, dec);
  if (Number.isNaN(w)) return { sunrise: null, sunset: null };
  const Jset = 2451545 + (ds + w / (2 * Math.PI)) + 0.0053 * Math.sin(M) - 0.0069 * Math.sin(2 * L);
  const Jrise = Jnoon - (Jset - Jnoon);
  return { sunrise: fromJulian(Jrise), sunset: fromJulian(Jset) };
}

/** Sun azimuth (0=N, 90=E) and altitude in degrees for a given time and place. */
export function getSunPosition(date: Date, pos: LatLng): { azimuth: number; altitude: number } {
  const lw = rad * -pos.lon;
  const phi = rad * pos.lat;
  const d = toDays(date);
  const M = solarMeanAnomaly(d);
  const L = eclipticLongitude(M);
  const dec = declination(L);
  const ra = rightAscension(L);
  const H = siderealTime(d, lw) - ra;
  const alt = Math.asin(Math.sin(phi) * Math.sin(dec) + Math.cos(phi) * Math.cos(dec) * Math.cos(H));
  const az = Math.atan2(Math.sin(H), Math.cos(H) * Math.sin(phi) - Math.tan(dec) * Math.cos(phi));
  return { azimuth: ((az / rad + 180) % 360 + 360) % 360, altitude: alt / rad };
}
