import type { GeocodeProvider, GeocodeResult } from './types';

const NOMINATIM_URL =
  import.meta.env.VITE_NOMINATIM_URL || 'https://nominatim.openstreetmap.org';

interface NominatimItem {
  lat: string;
  lon: string;
  display_name: string;
  address?: Record<string, string>;
}

function toResult(item: NominatimItem): GeocodeResult {
  const a = item.address ?? {};
  const locality =
    a.city ?? a.town ?? a.village ?? a.hamlet ?? a.municipality ?? a.county;
  const label = locality
    ? `${locality}${a.country ? ', ' + a.country : ''}`
    : item.display_name.split(',').slice(0, 2).join(',');
  return {
    lat: parseFloat(item.lat),
    lon: parseFloat(item.lon),
    label,
    countryCode: a.country_code,
  };
}

export const nominatimProvider: GeocodeProvider = {
  id: 'nominatim',

  async search(text, lang, signal): Promise<GeocodeResult[]> {
    const url = `${NOMINATIM_URL}/search?format=jsonv2&addressdetails=1&limit=6&accept-language=${lang}&q=${encodeURIComponent(text)}`;
    const res = await fetch(url, { signal, headers: { Accept: 'application/json' } });
    if (!res.ok) throw new Error(`nominatim:${res.status}`);
    const items = (await res.json()) as NominatimItem[];
    return items.map(toResult);
  },

  async reverse(lat, lon, lang, signal): Promise<GeocodeResult | null> {
    const url = `${NOMINATIM_URL}/reverse?format=jsonv2&addressdetails=1&zoom=12&accept-language=${lang}&lat=${lat}&lon=${lon}`;
    const res = await fetch(url, { signal, headers: { Accept: 'application/json' } });
    if (!res.ok) return null;
    const item = (await res.json()) as NominatimItem & { error?: string };
    if (item.error) return null;
    return toResult(item);
  },
};
