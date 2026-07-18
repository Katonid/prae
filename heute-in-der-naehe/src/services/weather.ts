import type { LatLng, WeatherInfo } from '../types';
import type { Dict } from '../i18n/de';

const WEATHER_URL =
  import.meta.env.VITE_WEATHER_URL || 'https://api.open-meteo.com/v1/forecast';

export async function fetchWeather(pos: LatLng, signal?: AbortSignal): Promise<WeatherInfo> {
  const url =
    `${WEATHER_URL}?latitude=${pos.lat.toFixed(3)}&longitude=${pos.lon.toFixed(3)}` +
    `&current=temperature_2m,weather_code,is_day,wind_speed_10m&timezone=auto`;
  const res = await fetch(url, { signal });
  if (!res.ok) throw new Error(`weather:${res.status}`);
  const data = await res.json();
  const c = data.current;
  return {
    temperatureC: c.temperature_2m,
    weatherCode: c.weather_code,
    isDay: c.is_day === 1,
    windKmh: c.wind_speed_10m,
    fetchedAt: Date.now(),
  };
}

/** Map WMO weather code to an i18n key + emoji. */
export function describeWeather(code: number, isDay: boolean): { key: keyof Dict; emoji: string } {
  if (code === 0) return { key: 'weather_clear', emoji: isDay ? '☀️' : '🌙' };
  if (code <= 2) return { key: 'weather_partly', emoji: isDay ? '🌤️' : '☁️' };
  if (code === 3) return { key: 'weather_cloudy', emoji: '☁️' };
  if (code <= 48) return { key: 'weather_fog', emoji: '🌫️' };
  if (code <= 57) return { key: 'weather_drizzle', emoji: '🌦️' };
  if (code <= 67) return { key: 'weather_rain', emoji: '🌧️' };
  if (code <= 77) return { key: 'weather_snow', emoji: '🌨️' };
  if (code <= 82) return { key: 'weather_showers', emoji: '🌦️' };
  if (code <= 86) return { key: 'weather_snow', emoji: '🌨️' };
  return { key: 'weather_thunder', emoji: '⛈️' };
}

export function isBadWeather(w: WeatherInfo | null): boolean {
  if (!w) return false;
  return w.weatherCode >= 51; // any precipitation
}
export function isHot(w: WeatherInfo | null): boolean {
  return Boolean(w && w.temperatureC >= 28);
}
