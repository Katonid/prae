/**
 * Country-specific brand/chain knowledge.
 *
 * This is pure configuration – nothing here is hard-wired into the UI.
 * Brands are matched (case-insensitively) against the `brand` and `name`
 * tags of search results to badge well-known chains, and each country can
 * contribute extra "regional highlight" Overpass selectors that are added
 * to the mixed nearby search (e.g. Biergärten in Germany).
 *
 * Extend by adding a new country entry or new names to `brands`.
 * Keys are lowercase ISO 3166-1 alpha-2 country codes.
 */

export interface RegionalExtra {
  id: string;
  labels: { de: string; en: string; fr: string };
  selectors: string[];
  named?: boolean;
}

export interface CountryConfig {
  brands: string[];
  regionalExtras?: RegionalExtra[];
}

export const COUNTRY_CONFIG: Record<string, CountryConfig> = {
  ca: {
    brands: ['Tim Hortons', 'Canadian Tire', 'Walmart', 'LCBO', 'Shoppers Drug Mart', 'Loblaws', 'Sobeys', 'Petro-Canada', 'A&W'],
    regionalExtras: [
      {
        id: 'provincial_park',
        labels: { de: 'Provincial Park', en: 'Provincial park', fr: 'Parc provincial' },
        selectors: ['boundary=protected_area][protect_class=2'],
        named: true,
      },
    ],
  },
  de: {
    brands: ['Aldi', 'Aldi Süd', 'Aldi Nord', 'Lidl', 'REWE', 'EDEKA', 'dm', 'Rossmann', 'OBI', 'Bauhaus', 'Netto', 'Penny', 'Kaufland'],
    regionalExtras: [
      {
        id: 'biergarten',
        labels: { de: 'Biergarten', en: 'Beer garden', fr: 'Biergarten' },
        selectors: ['amenity=biergarten'],
      },
    ],
  },
  at: {
    brands: ['Billa', 'Spar', 'Hofer', 'dm', 'OBI'],
    regionalExtras: [
      {
        id: 'biergarten',
        labels: { de: 'Biergarten', en: 'Beer garden', fr: 'Biergarten' },
        selectors: ['amenity=biergarten'],
      },
      {
        id: 'alm',
        labels: { de: 'Almhütte', en: 'Alpine hut', fr: "Refuge d'alpage" },
        selectors: ['tourism=alpine_hut'],
      },
    ],
  },
  ch: {
    brands: ['Migros', 'Coop', 'Denner', 'Landi'],
    regionalExtras: [
      {
        id: 'alm',
        labels: { de: 'Berghütte', en: 'Mountain hut', fr: 'Cabane de montagne' },
        selectors: ['tourism=alpine_hut'],
      },
    ],
  },
  us: {
    brands: ['Target', 'Walmart', 'Walgreens', 'CVS', 'Home Depot', 'Trader Joe’s', 'Costco', 'REI', '7-Eleven'],
    regionalExtras: [
      {
        id: 'state_park',
        labels: { de: 'State Park', en: 'State park', fr: "Parc d'État" },
        selectors: ['boundary=protected_area][protect_class=2'],
        named: true,
      },
      {
        id: 'diner',
        labels: { de: 'Diner', en: 'Diner', fr: 'Diner' },
        selectors: ['cuisine=diner'],
      },
    ],
  },
  fr: {
    brands: ['Carrefour', 'E.Leclerc', 'Intermarché', 'Auchan', 'Monoprix', 'Decathlon'],
    regionalExtras: [
      {
        id: 'winery',
        labels: { de: 'Weingut', en: 'Winery', fr: 'Domaine viticole' },
        selectors: ['craft=winery'],
        named: true,
      },
      {
        id: 'chateau',
        labels: { de: 'Schloss', en: 'Château', fr: 'Château' },
        selectors: ['historic=castle'],
        named: true,
      },
    ],
  },
  it: {
    brands: ['Conad', 'Coop', 'Esselunga', 'Eurospin'],
    regionalExtras: [
      {
        id: 'gelateria',
        labels: { de: 'Gelateria', en: 'Gelateria', fr: 'Gelateria' },
        selectors: ['amenity=ice_cream'],
      },
      {
        id: 'agriturismo',
        labels: { de: 'Agriturismo', en: 'Agriturismo', fr: 'Agritourisme' },
        selectors: ['tourism=agritourism'],
        named: true,
      },
    ],
  },
  gb: {
    brands: ['Tesco', 'Sainsbury’s', 'Boots', 'Greggs', 'B&Q', 'Marks & Spencer'],
  },
  nl: {
    brands: ['Albert Heijn', 'Jumbo', 'HEMA', 'Kruidvat'],
  },
  es: {
    brands: ['Mercadona', 'Carrefour', 'El Corte Inglés', 'Dia'],
  },
};

export function getCountryConfig(countryCode?: string): CountryConfig | undefined {
  if (!countryCode) return undefined;
  return COUNTRY_CONFIG[countryCode.toLowerCase()];
}

/** Case-insensitive brand match against name/brand tags. */
export function matchBrand(tags: Record<string, string>, countryCode?: string): boolean {
  const cfg = getCountryConfig(countryCode);
  if (!cfg) return false;
  const hay = `${tags.brand ?? ''}|${tags.name ?? ''}`.toLowerCase();
  if (!hay || hay === '|') return false;
  return cfg.brands.some((b) => hay.includes(b.toLowerCase()));
}

/** Countries that customarily use miles. */
export const IMPERIAL_COUNTRIES = new Set(['us', 'gb', 'lr', 'mm']);
/** Countries that customarily use Fahrenheit. */
export const FAHRENHEIT_COUNTRIES = new Set(['us', 'bs', 'bz', 'ky', 'pw']);
