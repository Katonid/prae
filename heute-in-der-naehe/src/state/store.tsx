import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react';
import {
  DEFAULT_SETTINGS,
  type FavoriteEntry,
  type Place,
  type Settings,
  type Units,
  type UserLocation,
  type WeatherInfo,
} from '../types';
import { getCurrentPosition, isPermissionDenied } from '../services/geo';
import { geocoder } from '../services/providers';
import { fetchWeather } from '../services/weather';
import { addRecentLocation, getFavorites, putFavorite, removeFavorite } from '../services/db';
import { getDict, resolveLang, I18nContext } from '../i18n';
import { FAHRENHEIT_COUNTRIES, IMPERIAL_COUNTRIES } from '../config/brands';

const SETTINGS_KEY = 'hin-settings';

export type LocationStatus = 'idle' | 'locating' | 'ready' | 'denied' | 'error';

interface AppState {
  settings: Settings;
  updateSettings(patch: Partial<Settings>): void;
  location: UserLocation | null;
  locationStatus: LocationStatus;
  locate(): Promise<void>;
  setManualLocation(loc: UserLocation): void;
  weather: WeatherInfo | null;
  online: boolean;
  favorites: Map<string, FavoriteEntry>;
  toggleFavorite(place: Place): Promise<void>;
  units: Units;
  tempUnit: 'c' | 'f';
}

const AppContext = createContext<AppState | null>(null);

export function useApp(): AppState {
  const ctx = useContext(AppContext);
  if (!ctx) throw new Error('useApp outside provider');
  return ctx;
}

function loadSettings(): Settings {
  try {
    const raw = localStorage.getItem(SETTINGS_KEY);
    if (raw) return { ...DEFAULT_SETTINGS, ...JSON.parse(raw) };
  } catch {
    /* corrupted settings → defaults */
  }
  return DEFAULT_SETTINGS;
}

export function AppProvider({ children }: { children: ReactNode }) {
  const [settings, setSettings] = useState<Settings>(loadSettings);
  const [location, setLocation] = useState<UserLocation | null>(null);
  const [locationStatus, setLocationStatus] = useState<LocationStatus>('idle');
  const [weather, setWeather] = useState<WeatherInfo | null>(null);
  const [online, setOnline] = useState(navigator.onLine);
  const [favorites, setFavorites] = useState<Map<string, FavoriteEntry>>(new Map());

  const lang = resolveLang(settings.lang);
  const dict = getDict(lang);

  useEffect(() => {
    const on = () => setOnline(true);
    const off = () => setOnline(false);
    window.addEventListener('online', on);
    window.addEventListener('offline', off);
    return () => {
      window.removeEventListener('online', on);
      window.removeEventListener('offline', off);
    };
  }, []);

  // theme
  useEffect(() => {
    const root = document.documentElement;
    if (settings.theme === 'auto') root.removeAttribute('data-theme');
    else root.setAttribute('data-theme', settings.theme);
  }, [settings.theme]);

  // favorites from IndexedDB
  useEffect(() => {
    getFavorites()
      .then((list) => setFavorites(new Map(list.map((f) => [f.placeId, f]))))
      .catch(() => undefined);
  }, []);

  const updateSettings = useCallback((patch: Partial<Settings>) => {
    setSettings((prev) => {
      const next = { ...prev, ...patch };
      try {
        localStorage.setItem(SETTINGS_KEY, JSON.stringify(next));
      } catch {
        /* storage full/blocked – keep in memory */
      }
      return next;
    });
  }, []);

  const enrichLocation = useCallback(
    async (loc: UserLocation) => {
      setLocation(loc);
      setLocationStatus('ready');
      addRecentLocation(loc).catch(() => undefined);
      fetchWeather(loc)
        .then(setWeather)
        .catch(() => undefined);
      if (!loc.label || !loc.countryCode) {
        try {
          const rev = await geocoder.reverse(loc.lat, loc.lon, lang);
          if (rev) {
            const enriched = { ...loc, label: rev.label, countryCode: rev.countryCode };
            setLocation(enriched);
            addRecentLocation(enriched).catch(() => undefined);
          }
        } catch {
          /* offline reverse geocoding is optional */
        }
      }
    },
    [lang],
  );

  const locate = useCallback(async () => {
    setLocationStatus('locating');
    try {
      const loc = await getCurrentPosition();
      await enrichLocation(loc);
    } catch (err) {
      setLocationStatus(isPermissionDenied(err) ? 'denied' : 'error');
    }
  }, [enrichLocation]);

  const setManualLocation = useCallback(
    (loc: UserLocation) => {
      void enrichLocation(loc);
    },
    [enrichLocation],
  );

  const toggleFavorite = useCallback(
    async (place: Place) => {
      setFavorites((prev) => {
        const next = new Map(prev);
        if (next.has(place.id)) {
          next.delete(place.id);
          removeFavorite(place.id).catch(() => undefined);
        } else {
          const entry: FavoriteEntry = {
            placeId: place.id,
            place,
            addedAt: Date.now(),
            lists: [],
          };
          next.set(place.id, entry);
          putFavorite(entry).catch(() => undefined);
        }
        return next;
      });
    },
    [],
  );

  const cc = location?.countryCode?.toLowerCase();
  const units: Units =
    settings.units !== 'auto'
      ? settings.units
      : cc && IMPERIAL_COUNTRIES.has(cc)
        ? 'imperial'
        : 'metric';
  const tempUnit: 'c' | 'f' =
    settings.tempUnit !== 'auto'
      ? settings.tempUnit
      : cc && FAHRENHEIT_COUNTRIES.has(cc)
        ? 'f'
        : 'c';

  const value = useMemo<AppState>(
    () => ({
      settings,
      updateSettings,
      location,
      locationStatus,
      locate,
      setManualLocation,
      weather,
      online,
      favorites,
      toggleFavorite,
      units,
      tempUnit,
    }),
    [settings, updateSettings, location, locationStatus, locate, setManualLocation, weather, online, favorites, toggleFavorite, units, tempUnit],
  );

  const i18nValue = useMemo(
    () => ({ t: (k: keyof typeof dict) => dict[k], lang }),
    [dict, lang],
  );

  return (
    <AppContext.Provider value={value}>
      <I18nContext.Provider value={i18nValue}>{children}</I18nContext.Provider>
    </AppContext.Provider>
  );
}
