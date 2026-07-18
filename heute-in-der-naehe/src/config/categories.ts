import type { CategoryId } from '../types';

/**
 * Declarative mapping from app categories to OpenStreetMap/Overpass selectors.
 * Selectors use Overpass filter syntax fragments: 'key=value', 'key~"a|b"'.
 * This file is pure configuration – adding a subcategory here is enough to
 * make it searchable, listable and filterable everywhere in the app.
 */

export interface SubcategoryDef {
  id: string;
  labels: { de: string; en: string; fr: string };
  selectors: string[];
  /** require a name tag (filters out unnamed micro-features) */
  named?: boolean;
  outdoor?: boolean;
  indoor?: boolean;
  typicallyFree?: boolean;
  family?: boolean;
  /** photospot classification kinds (see PhotospotInfo.kinds) */
  photo?: string[];
  photoTip?: string; // i18n key
  bestTime?: 'sunrise' | 'sunset' | 'day' | 'night' | 'bluehour';
}

export interface CategoryDef {
  id: CategoryId;
  icon: string; // emoji – rendered inside styled tile
  color: string; // accent for markers/tiles
  sub: SubcategoryDef[];
}

const sc = (
  id: string,
  de: string,
  en: string,
  fr: string,
  selectors: string[],
  opts: Partial<SubcategoryDef> = {},
): SubcategoryDef => ({ id, labels: { de, en, fr }, selectors, ...opts });

export const CATEGORIES: CategoryDef[] = [
  {
    id: 'nature',
    icon: '🏞️',
    color: '#16a34a',
    sub: [
      sc('waterfall', 'Wasserfall', 'Waterfall', 'Cascade', ['waterway=waterfall', 'natural=waterfall'], {
        outdoor: true, typicallyFree: true, photo: ['nature', 'water'], photoTip: 'tip_water', bestTime: 'day',
      }),
      sc('viewpoint', 'Aussichtspunkt', 'Viewpoint', 'Point de vue', ['tourism=viewpoint'], {
        outdoor: true, typicallyFree: true, photo: ['panorama', 'sunset', 'sunrise'], photoTip: 'tip_viewpoint', bestTime: 'sunset',
      }),
      sc('beach', 'Strand', 'Beach', 'Plage', ['natural=beach'], {
        outdoor: true, typicallyFree: true, family: true, photo: ['nature', 'water', 'sunset'], photoTip: 'tip_water', bestTime: 'sunset',
      }),
      sc('lake', 'See', 'Lake', 'Lac', ['natural=water][water~"lake|lagoon|reservoir"]'], {
        named: true, outdoor: true, typicallyFree: true, photo: ['nature', 'water'], photoTip: 'tip_water', bestTime: 'sunrise',
      }),
      sc('nature_reserve', 'Naturschutzgebiet', 'Nature reserve', 'Réserve naturelle', ['leisure=nature_reserve'], {
        named: true, outdoor: true, typicallyFree: true, photo: ['nature'], bestTime: 'day',
      }),
      sc('national_park', 'Nationalpark', 'National park', 'Parc national', ['boundary=national_park'], {
        named: true, outdoor: true, photo: ['nature', 'panorama'], bestTime: 'day',
      }),
      sc('trailhead', 'Wanderweg-Einstieg', 'Trailhead', 'Départ de sentier', ['highway=trailhead', 'information=guidepost'], {
        outdoor: true, typicallyFree: true,
      }),
      sc('cave', 'Höhle', 'Cave', 'Grotte', ['natural=cave_entrance'], {
        outdoor: true, photo: ['nature', 'quiet'], bestTime: 'day',
      }),
      sc('rock', 'Felsformation', 'Rock formation', 'Formation rocheuse', ['natural~"^(rock|stone|arch|cliff|peak)$"'], {
        named: true, outdoor: true, typicallyFree: true, photo: ['nature', 'panorama'], bestTime: 'sunset',
      }),
      sc('garden', 'Garten / Botanischer Garten', 'Garden / botanical garden', 'Jardin / jardin botanique', ['leisure=garden'], {
        named: true, outdoor: true, family: true, photo: ['nature'], bestTime: 'day',
      }),
      sc('spring', 'Quelle', 'Spring', 'Source', ['natural=spring'], {
        named: true, outdoor: true, typicallyFree: true,
      }),
      sc('wildlife', 'Tierbeobachtung', 'Wildlife watching', 'Observation animalière', ['leisure=bird_hide', 'tourism=wildlife_hide'], {
        outdoor: true, typicallyFree: true, family: true, photo: ['nature', 'quiet'],
      }),
    ],
  },
  {
    id: 'photospots',
    icon: '📸',
    color: '#d946ef',
    sub: [
      sc('viewpoint', 'Aussichtspunkt', 'Viewpoint', 'Point de vue', ['tourism=viewpoint'], {
        outdoor: true, typicallyFree: true, photo: ['panorama', 'sunset', 'sunrise'], photoTip: 'tip_viewpoint', bestTime: 'sunset',
      }),
      sc('streetart', 'Street-Art', 'Street art', 'Street art', ['tourism=artwork'], {
        outdoor: true, typicallyFree: true, photo: ['streetart', 'easy'], photoTip: 'tip_streetart', bestTime: 'day',
      }),
      sc('lighthouse', 'Leuchtturm', 'Lighthouse', 'Phare', ['man_made=lighthouse'], {
        outdoor: true, photo: ['architecture', 'water', 'sunset'], photoTip: 'tip_generic', bestTime: 'sunset',
      }),
      sc('observation_tower', 'Aussichtsturm', 'Observation tower', 'Tour panoramique', ['man_made=tower][tower:type=observation'], {
        photo: ['panorama', 'architecture'], photoTip: 'tip_viewpoint', bestTime: 'sunset',
      }),
      sc('castle', 'Burg / Schloss', 'Castle', 'Château', ['historic=castle'], {
        named: true, photo: ['architecture', 'family'], photoTip: 'tip_architecture', bestTime: 'day',
      }),
      sc('bridge', 'Bemerkenswerte Brücke', 'Notable bridge', 'Pont remarquable', ['man_made=bridge'], {
        named: true, outdoor: true, typicallyFree: true, photo: ['architecture', 'night'], photoTip: 'tip_night', bestTime: 'bluehour',
      }),
      sc('windmill', 'Windmühle', 'Windmill', 'Moulin à vent', ['man_made=windmill'], {
        outdoor: true, photo: ['architecture', 'quiet'], photoTip: 'tip_generic', bestTime: 'sunset',
      }),
      sc('pier', 'Pier / Seebrücke', 'Pier', 'Jetée', ['man_made=pier'], {
        named: true, outdoor: true, typicallyFree: true, photo: ['water', 'sunset'], photoTip: 'tip_water', bestTime: 'sunset',
      }),
      sc('monument', 'Denkmal', 'Monument', 'Monument', ['historic=monument'], {
        named: true, typicallyFree: true, photo: ['architecture', 'easy'], photoTip: 'tip_architecture', bestTime: 'day',
      }),
    ],
  },
  {
    id: 'food',
    icon: '🍽️',
    color: '#ea580c',
    sub: [
      sc('ice_cream', 'Eisdiele', 'Ice cream', 'Glacier', ['amenity=ice_cream', 'shop=ice_cream'], { family: true }),
      sc('cafe', 'Café', 'Café', 'Café', ['amenity=cafe'], {}),
      sc('bakery', 'Bäckerei', 'Bakery', 'Boulangerie', ['shop=bakery'], {}),
      sc('restaurant', 'Restaurant', 'Restaurant', 'Restaurant', ['amenity=restaurant'], {}),
      sc('fast_food', 'Imbiss', 'Snack / fast food', 'Snack', ['amenity=fast_food'], {}),
      sc('brewery', 'Brauerei', 'Brewery', 'Brasserie', ['craft=brewery', 'microbrewery=yes'], {}),
      sc('winery', 'Weingut', 'Winery', 'Domaine viticole', ['craft=winery'], { named: true }),
      sc('farm_shop', 'Hofladen', 'Farm shop', 'Vente à la ferme', ['shop=farm'], {}),
      sc('marketplace', 'Markt / Markthalle', 'Market / market hall', 'Marché / halles', ['amenity=marketplace'], {
        typicallyFree: true, family: true,
      }),
      sc('picnic', 'Picknickplatz', 'Picnic site', 'Aire de pique-nique', ['tourism=picnic_site'], {
        outdoor: true, typicallyFree: true, family: true,
      }),
    ],
  },
  {
    id: 'family',
    icon: '👨‍👩‍👧',
    color: '#eab308',
    sub: [
      sc('playground', 'Spielplatz', 'Playground', 'Aire de jeux', ['leisure=playground'], {
        outdoor: true, typicallyFree: true, family: true,
      }),
      sc('theme_park', 'Freizeitpark', 'Theme park', "Parc d'attractions", ['tourism=theme_park'], {
        named: true, family: true, photo: ['family'],
      }),
      sc('zoo', 'Zoo / Tierpark', 'Zoo / animal park', 'Zoo / parc animalier', ['tourism=zoo'], {
        named: true, family: true, photo: ['family'],
      }),
      sc('aquarium', 'Aquarium', 'Aquarium', 'Aquarium', ['tourism=aquarium'], { named: true, family: true, indoor: true }),
      sc('water_park', 'Schwimmbad / Badestelle', 'Pool / swimming area', 'Piscine / baignade', ['leisure=water_park', 'leisure=swimming_area', 'sport=swimming'], {
        family: true,
      }),
      sc('minigolf', 'Minigolf', 'Mini golf', 'Minigolf', ['leisure=miniature_golf'], { outdoor: true, family: true }),
      sc('bowling', 'Bowling', 'Bowling', 'Bowling', ['leisure=bowling_alley'], { indoor: true, family: true }),
      sc('climbing_park', 'Kletterpark', 'Climbing / ropes park', "Parc d'accrobranche", ['sport=climbing_adventure', 'leisure=climbing_adventure'], {
        outdoor: true, family: true,
      }),
      sc('indoor_play', 'Indoorspielplatz', 'Indoor playground', 'Aire de jeux couverte', ['leisure=indoor_play'], {
        indoor: true, family: true,
      }),
    ],
  },
  {
    id: 'sports',
    icon: '🚴',
    color: '#0891b2',
    sub: [
      sc('boat_rental', 'Boots-/Kanu-/SUP-Verleih', 'Boat / canoe / SUP rental', 'Location bateau / canoë / SUP', ['amenity=boat_rental'], {
        outdoor: true,
      }),
      sc('bike_rental', 'Fahrradverleih', 'Bike rental', 'Location de vélos', ['amenity=bicycle_rental'], { outdoor: true }),
      sc('fishing', 'Angelstelle', 'Fishing spot', 'Coin de pêche', ['leisure=fishing'], { outdoor: true, typicallyFree: true }),
      sc('swimming_area', 'Badestelle', 'Swimming area', 'Zone de baignade', ['leisure=swimming_area'], {
        outdoor: true, typicallyFree: true, family: true,
      }),
      sc('winter_sports', 'Skigebiet / Rodeln', 'Ski area / sledding', 'Domaine skiable / luge', ['landuse=winter_sports', 'piste:type=sled'], {
        named: true, outdoor: true,
      }),
      sc('surfing', 'Surfspot', 'Surf spot', 'Spot de surf', ['sport=surfing'], { outdoor: true, photo: ['water'] }),
      sc('diving', 'Tauch-/Schnorchelplatz', 'Dive / snorkel site', 'Site de plongée', ['sport=scuba_diving'], { outdoor: true }),
      sc('sports_centre', 'Sportzentrum', 'Sports centre', 'Centre sportif', ['leisure=sports_centre'], { named: true }),
    ],
  },
  {
    id: 'shopping',
    icon: '🛍️',
    color: '#7c3aed',
    sub: [
      sc('mall', 'Einkaufszentrum / Outlet', 'Mall / outlet', 'Centre commercial / outlet', ['shop=mall', 'shop=department_store'], {
        named: true, indoor: true,
      }),
      sc('supermarket', 'Supermarkt', 'Supermarket', 'Supermarché', ['shop=supermarket'], { indoor: true }),
      sc('chemist', 'Drogerie', 'Drugstore', 'Droguerie / parapharmacie', ['shop=chemist'], { indoor: true }),
      sc('diy', 'Baumarkt', 'DIY / hardware store', 'Magasin de bricolage', ['shop=doityourself', 'shop=hardware'], { indoor: true }),
      sc('outdoor_shop', 'Outdoor- & Campingbedarf', 'Outdoor & camping gear', 'Équipement outdoor & camping', ['shop=outdoor', 'shop=camping'], { indoor: true }),
      sc('gift', 'Souvenirladen', 'Souvenir shop', 'Boutique de souvenirs', ['shop=gift'], { indoor: true }),
      sc('local_shop', 'Lokale Geschäfte', 'Local shops', 'Commerces locaux', ['shop=deli', 'shop=cheese', 'shop=chocolate', 'shop=craft'], {}),
    ],
  },
  {
    id: 'culture',
    icon: '🏛️',
    color: '#dc2626',
    sub: [
      sc('museum', 'Museum', 'Museum', 'Musée', ['tourism=museum'], { named: true, indoor: true, photo: ['architecture'] }),
      sc('castle', 'Burg / Schloss', 'Castle / palace', 'Château', ['historic=castle'], {
        named: true, photo: ['architecture', 'family'], photoTip: 'tip_architecture',
      }),
      sc('place_of_worship', 'Kirche / Sakralbau', 'Church / place of worship', 'Église / lieu de culte', ['amenity=place_of_worship'], {
        named: true, typicallyFree: true, photo: ['architecture'], photoTip: 'tip_architecture',
      }),
      sc('monument', 'Denkmal / Gedenkstätte', 'Monument / memorial', 'Monument / mémorial', ['historic~"^(monument|memorial)$"'], {
        named: true, typicallyFree: true,
      }),
      sc('archaeological', 'Archäologische Stätte', 'Archaeological site', 'Site archéologique', ['historic=archaeological_site'], {
        named: true, outdoor: true, photo: ['quiet'],
      }),
      sc('ruins', 'Ruine', 'Ruins', 'Ruines', ['historic=ruins'], { named: true, outdoor: true, photo: ['quiet', 'architecture'] }),
      sc('attraction', 'Sehenswürdigkeit', 'Attraction', 'Site touristique', ['tourism=attraction'], { named: true, photo: ['easy'] }),
      sc('lighthouse', 'Leuchtturm', 'Lighthouse', 'Phare', ['man_made=lighthouse'], { photo: ['architecture', 'water'] }),
      sc('observation_tower', 'Aussichtsturm', 'Observation tower', 'Tour panoramique', ['man_made=tower][tower:type=observation'], {
        photo: ['panorama'],
      }),
    ],
  },
  {
    id: 'essentials',
    icon: '🧭',
    color: '#64748b',
    sub: [
      sc('toilets', 'Öffentliche Toilette', 'Public toilets', 'Toilettes publiques', ['amenity=toilets'], { typicallyFree: true }),
      sc('pharmacy', 'Apotheke', 'Pharmacy', 'Pharmacie', ['amenity=pharmacy'], { indoor: true }),
      sc('fuel', 'Tankstelle', 'Fuel station', 'Station-service', ['amenity=fuel'], {}),
      sc('charging', 'E-Ladestation', 'EV charging', 'Borne de recharge', ['amenity=charging_station'], {}),
      sc('atm', 'Geldautomat', 'ATM', 'Distributeur', ['amenity=atm'], {}),
      sc('post', 'Poststelle', 'Post office', 'Bureau de poste', ['amenity=post_office'], {}),
      sc('laundry', 'Waschsalon', 'Laundromat', 'Laverie', ['shop=laundry'], {}),
      sc('drinking_water', 'Trinkwasser', 'Drinking water', 'Eau potable', ['amenity=drinking_water'], { typicallyFree: true }),
    ],
  },
];

/** Subcategory ids used for the mixed "everything nearby" search. */
export const HIGHLIGHT_SUBS: [CategoryId, string][] = [
  ['nature', 'waterfall'],
  ['nature', 'viewpoint'],
  ['nature', 'beach'],
  ['photospots', 'lighthouse'],
  ['photospots', 'streetart'],
  ['culture', 'museum'],
  ['culture', 'castle'],
  ['culture', 'attraction'],
  ['family', 'zoo'],
  ['family', 'theme_park'],
  ['family', 'playground'],
  ['food', 'cafe'],
  ['food', 'ice_cream'],
  ['food', 'marketplace'],
  ['food', 'picnic'],
];

export function getCategory(id: CategoryId): CategoryDef {
  const c = CATEGORIES.find((c) => c.id === id);
  if (!c) throw new Error(`Unknown category: ${id}`);
  return c;
}

/** Similar-category suggestions for empty result states. */
export const SIMILAR_CATEGORY: Record<CategoryId, CategoryId> = {
  nature: 'photospots',
  photospots: 'nature',
  food: 'shopping',
  family: 'sports',
  sports: 'family',
  shopping: 'essentials',
  culture: 'photospots',
  essentials: 'shopping',
};
