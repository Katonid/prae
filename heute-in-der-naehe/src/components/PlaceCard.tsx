import { useEffect, useRef, useState, type CSSProperties } from 'react';
import { useT } from '../i18n';
import { useApp } from '../state/store';
import type { Place } from '../types';
import { estimateMinutes, formatDistance, formatMinutes } from '../services/geo';
import { resolveImage } from '../services/images';
import { getCategory } from '../config/categories';
import { findSub } from '../services/providers/overpass';
import { buildNavUrl } from '../services/navigation';

export function PlaceCard({ place, onOpen }: { place: Place; onOpen: () => void }) {
  const { t, lang } = useT();
  const { units, settings, favorites, toggleFavorite } = useApp();
  const [imageUrl, setImageUrl] = useState<string | null>(null);
  const [visible, setVisible] = useState(false);
  const ref = useRef<HTMLElement>(null);

  // Lazy-load images only when the card scrolls into view (and not in data-saver mode)
  useEffect(() => {
    const el = ref.current;
    if (!el || settings.reducedData) return;
    const io = new IntersectionObserver(
      (entries) => {
        if (entries.some((e) => e.isIntersecting)) {
          setVisible(true);
          io.disconnect();
        }
      },
      { rootMargin: '200px' },
    );
    io.observe(el);
    return () => io.disconnect();
  }, [settings.reducedData]);

  useEffect(() => {
    if (!visible) return;
    let cancelled = false;
    resolveImage(place).then((url) => {
      if (!cancelled) setImageUrl(url);
    });
    return () => {
      cancelled = true;
    };
  }, [visible, place]);

  const cat = getCategory(place.category);
  const sub = findSub(place.category, place.subcategory);
  const subLabel = sub?.labels[lang] ?? place.subcategory;
  const isFav = favorites.has(place.id);
  const dist = place.distanceM;

  return (
    <article ref={ref} className="place-card">
      <button className="place-card-main" onClick={onOpen}>
        <div className="place-thumb" style={{ '--tile-color': cat.color } as CSSProperties}>
          {imageUrl ? (
            <img src={imageUrl} alt="" loading="lazy" />
          ) : (
            <span className="place-thumb-icon" aria-hidden>{cat.icon}</span>
          )}
        </div>
        <div className="place-info">
          <div className="place-name-row">
            <strong className="place-name">{place.name}</strong>
            {place.hiddenGem && <span className="badge badge-gem" title={t('hiddenGem')}>💎</span>}
            {place.isBrand && <span className="badge" title={t('localBrand')}>🏷️</span>}
          </div>
          <div className="place-sub">{subLabel}</div>
          <div className="place-meta">
            {dist !== undefined && (
              <>
                <span>📍 {formatDistance(dist, units, lang)}</span>
                <span>🚗 {formatMinutes(estimateMinutes(dist, 'drive'), lang)}</span>
                {dist < 4000 && <span>🚶 {formatMinutes(estimateMinutes(dist, 'walk'), lang)}</span>}
              </>
            )}
          </div>
          <div className="place-meta">
            {place.opening?.isOpen === true && <span className="open">● {t('open_now')}</span>}
            {place.opening?.isOpen === false && <span className="closed">● {t('closed_now')}</span>}
            {place.fee === false && <span className="free">{t('free')}</span>}
            {place.fee === true && <span>{t('paid')}</span>}
            {place.familyFriendly && <span title={t('familyFriendly')}>👨‍👩‍👧</span>}
            {place.photospot && <span title={t('cat_photospots')}>📸</span>}
          </div>
        </div>
      </button>
      <div className="place-actions">
        <button
          className={`icon-btn ${isFav ? 'fav-active' : ''}`}
          onClick={() => void toggleFavorite(place)}
          aria-label={isFav ? t('remembered') : t('remember')}
          title={isFav ? t('remembered') : t('remember')}
        >
          {isFav ? '❤️' : '🤍'}
        </button>
        <a
          className="icon-btn"
          href={buildNavUrl(settings.preferredNavApp, place, 'drive')}
          target="_blank"
          rel="noopener noreferrer"
          aria-label={t('navigate')}
          title={t('navigate')}
        >
          🧭
        </a>
      </div>
    </article>
  );
}
