/**
 * Lazy preview image resolution via open sources:
 *  1. OSM `image` tag (direct URL)
 *  2. Wikimedia Commons (P18) via the `wikidata` tag
 *  3. Wikipedia page image via the `wikipedia` tag
 * Results are memoized; `null` means "no image found".
 */
import type { Place } from '../types';

const memo = new Map<string, Promise<string | null>>();

async function fetchWikidataImage(wikidataId: string): Promise<string | null> {
  const url = `https://www.wikidata.org/wiki/Special:EntityData/${wikidataId}.json`;
  const res = await fetch(url);
  if (!res.ok) return null;
  const data = await res.json();
  const claims = data?.entities?.[wikidataId]?.claims?.P18;
  const file: string | undefined = claims?.[0]?.mainsnak?.datavalue?.value;
  if (!file) return null;
  return `https://commons.wikimedia.org/wiki/Special:FilePath/${encodeURIComponent(file)}?width=480`;
}

async function fetchWikipediaImage(wikipedia: string): Promise<string | null> {
  const [lang, ...titleParts] = wikipedia.split(':');
  const title = titleParts.join(':');
  if (!lang || !title) return null;
  const url = `https://${lang}.wikipedia.org/api/rest_v1/page/summary/${encodeURIComponent(title)}`;
  const res = await fetch(url);
  if (!res.ok) return null;
  const data = await res.json();
  return data?.thumbnail?.source ?? null;
}

export function resolveImage(place: Place): Promise<string | null> {
  const cached = memo.get(place.id);
  if (cached) return cached;
  const p = (async () => {
    try {
      const direct = place.tags.image;
      if (direct?.startsWith('https://')) return direct;
      if (place.wikidataId && /^Q\d+$/.test(place.wikidataId)) {
        const img = await fetchWikidataImage(place.wikidataId);
        if (img) return img;
      }
      if (place.wikipedia) {
        const img = await fetchWikipediaImage(place.wikipedia);
        if (img) return img;
      }
      return null;
    } catch {
      return null;
    }
  })();
  memo.set(place.id, p);
  return p;
}
