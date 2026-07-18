import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useT } from '../i18n';
import { useApp } from '../state/store';
import type { CategoryId, LatLng, Place, QuickFilterId, SearchResult, SortMode } from '../types';
import { searchPlaces } from '../services/providers';
import { applyQuickFilter, sortPlaces } from '../services/logic';
import { driveMinutesToRadiusM, formatDistance } from '../services/geo';
import { PlaceCard } from './PlaceCard';
import { PlaceDetail } from './PlaceDetail';
import { MapView } from './MapView';
import { SIMILAR_CATEGORY } from '../config/categories';
import { navigateTo } from '../App';

const RADII = [1000, 2000, 5000, 10000, 25000, 50000, 100000];
const DRIVE_TIMES = [5, 10, 15, 30, 60];
const SORTS: SortMode[] = ['distance', 'rating', 'open', 'free', 'best', 'photo'];
const PAGE_SIZE = 25;

interface Props {
  category?: CategoryId;
  initialFilter?: QuickFilterId;
}

export function ResultsView({ category, initialFilter }: Props) {
  const { t, lang } = useT();
  const { location, settings, units } = useApp();
  const [radiusM, setRadiusM] = useState(settings.defaultRadiusM);
  const [byDriveTime, setByDriveTime] = useState<number | null>(null);
  const [sort, setSort] = useState<SortMode>('distance');
  const [filter, setFilter] = useState<QuickFilterId>(initialFilter ?? 'all');
  const [result, setResult] = useState<SearchResult | null>(null);
  const [loading, setLoading] = useState(false);
  const [slow, setSlow] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [showMap, setShowMap] = useState(false);
  const [selected, setSelected] = useState<Place | null>(null);
  const [searchCenter, setSearchCenter] = useState<LatLng | null>(null);
  const [visibleCount, setVisibleCount] = useState(PAGE_SIZE);
  const abortRef = useRef<AbortController | null>(null);

  const effectiveRadius = byDriveTime ? driveMinutesToRadiusM(byDriveTime) : radiusM;
  const center = searchCenter ?? location;

  const runSearch = useCallback(
    async (c: LatLng, radius: number) => {
      abortRef.current?.abort();
      const ctrl = new AbortController();
      abortRef.current = ctrl;
      setLoading(true);
      setSlow(false);
      setError(null);
      const slowTimer = setTimeout(() => setSlow(true), 8000);
      try {
        const res = await searchPlaces(
          {
            center: c,
            radiusM: radius,
            category,
            countryCode: location?.countryCode,
          },
          ctrl.signal,
        );
        if (!ctrl.signal.aborted) {
          setResult(res);
          setVisibleCount(PAGE_SIZE);
        }
      } catch (err) {
        if (!ctrl.signal.aborted) {
          setError(err instanceof TypeError ? t('errNetwork') : t('errApi'));
        }
      } finally {
        clearTimeout(slowTimer);
        if (!ctrl.signal.aborted) setLoading(false);
      }
    },
    [category, location?.countryCode, t],
  );

  useEffect(() => {
    if (center) void runSearch(center, effectiveRadius);
    return () => abortRef.current?.abort();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [center?.lat, center?.lon, effectiveRadius, category]);

  const places = useMemo(() => {
    if (!result) return [];
    let list = applyQuickFilter(result.places, filter);
    if (settings.familyMode && filter === 'all') {
      list = [...list].sort(
        (a, b) => Number(b.familyFriendly ?? false) - Number(a.familyFriendly ?? false),
      );
      return sortPlaces(list, sort === 'distance' ? 'distance' : sort);
    }
    return sortPlaces(list, sort);
  }, [result, filter, sort, settings.familyMode]);

  if (!location && !searchCenter) {
    return (
      <div className="results-empty">
        <p>{t('locationError')}</p>
      </div>
    );
  }

  const title = category ? t(`cat_${category}`) : t('resultsNearby');
  const similar = category ? SIMILAR_CATEGORY[category] : undefined;

  return (
    <div className="results">
      <div className="results-toolbar">
        <button className="icon-btn" onClick={() => history.back()} aria-label={t('back')}>
          ←
        </button>
        <h2 className="results-title">{title}</h2>
        <button
          className="btn btn-toggle"
          onClick={() => setShowMap((v) => !v)}
          aria-pressed={showMap}
        >
          {showMap ? `☰ ${t('list')}` : `🗺️ ${t('map')}`}
        </button>
      </div>

      <div className="results-controls">
        <label className="control">
          <span>{t('radius')}</span>
          <select
            value={byDriveTime ? `t${byDriveTime}` : String(radiusM)}
            onChange={(e) => {
              const v = e.target.value;
              if (v.startsWith('t')) {
                setByDriveTime(parseInt(v.slice(1), 10));
              } else {
                setByDriveTime(null);
                setRadiusM(parseInt(v, 10));
              }
            }}
          >
            {RADII.map((r) => (
              <option key={r} value={r}>
                {formatDistance(r, units, lang)}
              </option>
            ))}
            <optgroup label={t('searchByDriveTime')}>
              {DRIVE_TIMES.map((m) => (
                <option key={m} value={`t${m}`}>
                  🚗 {m} {t('minutes')}
                </option>
              ))}
            </optgroup>
          </select>
        </label>
        <label className="control">
          <span>{t('sort')}</span>
          <select value={sort} onChange={(e) => setSort(e.target.value as SortMode)}>
            {SORTS.map((s) => (
              <option key={s} value={s}>
                {t(`sort_${s}`)}
              </option>
            ))}
          </select>
        </label>
        <label className="control">
          <span>{t('qf_all')}</span>
          <select value={filter} onChange={(e) => setFilter(e.target.value as QuickFilterId)}>
            {(['all', 'open', 'free', 'family', 'badweather', 'outdoor', 'photospots', 'hiddengems', 'max15min'] as QuickFilterId[]).map((f) => (
              <option key={f} value={f}>
                {t(`qf_${f}`)}
              </option>
            ))}
          </select>
        </label>
      </div>

      {result?.fromCache && <div className="hint">💾 {t('resultsFromCache')}</div>}
      {result?.partial && !result.fromCache && <div className="hint">⚠️ {t('partialResults')}</div>}

      {loading && (
        <div className="loading" role="status">
          <div className="spinner" aria-hidden />
          <p>{slow ? t('errSlow') : t('loading')}</p>
        </div>
      )}

      {error && !loading && (
        <div className="notice" role="alert">
          <p>{error}</p>
          <button className="btn btn-primary" onClick={() => center && runSearch(center, effectiveRadius)}>
            {t('retry')}
          </button>
        </div>
      )}

      {!loading && !error && showMap && center && (
        <MapView
          center={center}
          radiusM={effectiveRadius}
          places={places}
          onSelect={setSelected}
          onSearchArea={(c) => {
            setSearchCenter(c);
          }}
        />
      )}

      {!loading && !error && !showMap && (
        <>
          {places.length === 0 ? (
            <div className="results-empty">
              <p className="empty-emoji" aria-hidden>🔍</p>
              <p>{t('noResults')}</p>
              <p className="hint">{t('noResultsHint')}</p>
              <div className="empty-actions">
                {effectiveRadius < 100000 && (
                  <button
                    className="btn"
                    onClick={() => {
                      setByDriveTime(null);
                      setRadiusM(RADII.find((r) => r > effectiveRadius) ?? 100000);
                    }}
                  >
                    ➕ {t('enlargeRadius')}
                  </button>
                )}
                {similar && (
                  <button
                    className="btn"
                    onClick={() => navigateTo({ name: 'results', category: similar })}
                  >
                    🔀 {t('trySimilar')}: {t(`cat_${similar}`)}
                  </button>
                )}
                <button className="btn" onClick={() => setShowMap(true)}>
                  🗺️ {t('searchElsewhere')}
                </button>
              </div>
            </div>
          ) : (
            <div className="place-list">
              {places.slice(0, visibleCount).map((p) => (
                <PlaceCard key={p.id} place={p} onOpen={() => setSelected(p)} />
              ))}
            </div>
          )}
          {places.length > visibleCount && (
            <button className="btn btn-block" onClick={() => setVisibleCount((v) => v + PAGE_SIZE)}>
              {t('showMore')} ({places.length - visibleCount})
            </button>
          )}
          <p className="attribution">{t('dataFromOsm')}</p>
        </>
      )}

      {selected && <PlaceDetail place={selected} onClose={() => setSelected(null)} />}
    </div>
  );
}
