import { useEffect, useState, type CSSProperties } from 'react';
import { useT } from '../i18n';
import { useApp } from '../state/store';
import { CATEGORIES, getCategory } from '../config/categories';
import type { CategoryId, Place, QuickFilterId } from '../types';
import { getSunTimes } from '../services/sun';
import { searchPlaces } from '../services/providers';
import { recommend, type Recommendation } from '../services/logic';
import { formatDistance } from '../services/geo';
import { PlaceDetail } from './PlaceDetail';

const QUICK_FILTERS: { id: QuickFilterId; icon: string }[] = [
  { id: 'all', icon: '✨' },
  { id: 'open', icon: '🟢' },
  { id: 'free', icon: '🆓' },
  { id: 'family', icon: '👨‍👩‍👧' },
  { id: 'badweather', icon: '🌧️' },
  { id: 'outdoor', icon: '🌤️' },
  { id: 'photospots', icon: '📸' },
  { id: 'hiddengems', icon: '💎' },
  { id: 'max15min', icon: '⏱️' },
];

interface Props {
  onOpenCategory(category: CategoryId): void;
  onOpenFilter(filter: QuickFilterId): void;
  needsLocation: boolean;
  onPickLocation(): void;
}

export function HomeView({ onOpenCategory, onOpenFilter, needsLocation, onPickLocation }: Props) {
  const { t, lang } = useT();
  const { settings, location, locationStatus, weather, units } = useApp();
  const [recs, setRecs] = useState<Recommendation[]>([]);
  const [selected, setSelected] = useState<Place | null>(null);

  // Context-aware recommendations from the cached highlight search
  useEffect(() => {
    if (!location) return;
    const ctrl = new AbortController();
    searchPlaces(
      {
        center: location,
        radiusM: settings.defaultRadiusM,
        countryCode: location.countryCode,
      },
      ctrl.signal,
    )
      .then((res) => setRecs(recommend(res.places, weather, settings.familyMode)))
      .catch(() => setRecs([]));
    return () => ctrl.abort();
  }, [location, weather, settings.defaultRadiusM, settings.familyMode]);

  const visibleCategories = CATEGORIES.filter(
    (c) => !settings.hiddenCategories.includes(c.id),
  );
  const sun = location ? getSunTimes(new Date(), location) : null;
  const fmtTime = (d: Date | null) =>
    d ? d.toLocaleTimeString(lang, { hour: '2-digit', minute: '2-digit' }) : '–';

  return (
    <div className="home">
      {needsLocation && (
        <div className="notice" role="alert">
          <p>{locationStatus === 'denied' ? t('locationDenied') : t('locationError')}</p>
          <button className="btn btn-primary" onClick={onPickLocation}>
            {t('chooseLocation')}
          </button>
        </div>
      )}

      <h1 className="home-title">{t('tagline')}</h1>

      <div className="category-grid">
        {visibleCategories.map((cat) => (
          <button
            key={cat.id}
            className="category-tile"
            style={{ '--tile-color': cat.color } as CSSProperties}
            onClick={() => onOpenCategory(cat.id)}
          >
            <span className="tile-icon" aria-hidden>{cat.icon}</span>
            <span className="tile-label">{t(`cat_${cat.id}`)}</span>
          </button>
        ))}
      </div>

      <div className="quick-filters">
        {QUICK_FILTERS.map((f) => (
          <button key={f.id} className="chip" onClick={() => onOpenFilter(f.id)}>
            <span aria-hidden>{f.icon}</span> {t(`qf_${f.id}`)}
          </button>
        ))}
      </div>

      {recs.length > 0 && (
        <section className="recs">
          <h2 className="recs-title">✨ {t('forYou')}</h2>
          <div className="recs-row">
            {recs.map(({ place, reasonKey }) => {
              const cat = getCategory(place.category);
              return (
                <button
                  key={place.id}
                  className="rec-card"
                  style={{ '--tile-color': cat.color } as CSSProperties}
                  onClick={() => setSelected(place)}
                >
                  <span className="rec-icon" aria-hidden>{cat.icon}</span>
                  <strong className="rec-name">{place.name}</strong>
                  <span className="rec-reason">{t(reasonKey)}</span>
                  {place.distanceM !== undefined && (
                    <span className="rec-dist">📍 {formatDistance(place.distanceM, units, lang)}</span>
                  )}
                </button>
              );
            })}
          </div>
        </section>
      )}

      {sun?.sunrise && sun.sunset && (
        <p className="sun-info">
          ☀️ {t('sunToday')}: 🌅 {fmtTime(sun.sunrise)} · 🌇 {fmtTime(sun.sunset)}
        </p>
      )}

      {selected && <PlaceDetail place={selected} onClose={() => setSelected(null)} />}
    </div>
  );
}
