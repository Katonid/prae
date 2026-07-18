import { useEffect, useState } from 'react';
import { useT } from '../i18n';
import { useApp } from '../state/store';
import type { Place, TravelMode } from '../types';
import { estimateMinutes, formatDistance, formatMinutes } from '../services/geo';
import { resolveImage } from '../services/images';
import { getCategory } from '../config/categories';
import { findSub } from '../services/providers/overpass';
import { NAV_APPS, buildNavUrl, isAppleDevice } from '../services/navigation';
import { getSunTimes } from '../services/sun';
import type { Dict } from '../i18n/de';

const MODES: { id: TravelMode; icon: string }[] = [
  { id: 'drive', icon: '🚗' },
  { id: 'walk', icon: '🚶' },
  { id: 'bike', icon: '🚲' },
  { id: 'transit', icon: '🚌' },
];

function TriState({ label, value }: { label: string; value: boolean | undefined }) {
  const { t } = useT();
  if (value === undefined) return null;
  return (
    <div className="detail-row">
      <span>{label}</span>
      <span>{value ? `✅ ${t('yes')}` : `✖️ ${t('no')}`}</span>
    </div>
  );
}

export function PlaceDetail({ place, onClose }: { place: Place; onClose: () => void }) {
  const { t, lang } = useT();
  const { units, settings } = useApp();
  const [imageUrl, setImageUrl] = useState<string | null>(null);
  const [mode, setMode] = useState<TravelMode>('drive');
  const [copied, setCopied] = useState(false);

  useEffect(() => {
    if (settings.reducedData) return;
    let cancelled = false;
    resolveImage(place).then((url) => {
      if (!cancelled) setImageUrl(url);
    });
    return () => {
      cancelled = true;
    };
  }, [place, settings.reducedData]);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && onClose();
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [onClose]);

  const cat = getCategory(place.category);
  const sub = findSub(place.category, place.subcategory);
  const dist = place.distanceM;
  const sun = getSunTimes(new Date(), place);
  const fmtTime = (d: Date | null) =>
    d ? d.toLocaleTimeString(lang, { hour: '2-digit', minute: '2-digit' }) : '–';

  const share = async () => {
    const url = `https://www.openstreetmap.org/?mlat=${place.lat}&mlon=${place.lon}#map=17/${place.lat}/${place.lon}`;
    const data = { title: place.name, text: place.name, url };
    if (navigator.share) {
      try {
        await navigator.share(data);
        return;
      } catch {
        /* user cancelled */
      }
    } else {
      try {
        await navigator.clipboard.writeText(url);
        setCopied(true);
        setTimeout(() => setCopied(false), 2000);
      } catch {
        /* clipboard blocked */
      }
    }
  };

  const navApps = isAppleDevice()
    ? NAV_APPS
    : NAV_APPS.filter((a) => a.id !== 'apple');

  return (
    <div className="sheet-backdrop" onClick={onClose}>
      <div
        className="sheet"
        role="dialog"
        aria-modal="true"
        aria-label={place.name}
        onClick={(e) => e.stopPropagation()}
      >
        <div className="sheet-handle" aria-hidden />
        <div className="sheet-header">
          <div>
            <h3>{place.name}</h3>
            <p className="place-sub">
              {cat.icon} {sub?.labels[lang] ?? place.subcategory}
              {place.hiddenGem && <> · 💎 {t('hiddenGem')}</>}
            </p>
          </div>
          <button className="icon-btn" onClick={onClose} aria-label={t('close')}>
            ✕
          </button>
        </div>

        {imageUrl && (
          <img className="sheet-image" src={imageUrl} alt={place.name} loading="lazy" />
        )}

        {place.description && <p className="detail-desc">{place.description}</p>}

        <div className="detail-grid">
          {dist !== undefined && (
            <>
              <div className="detail-row">
                <span>📍 {t('sort_distance')}</span>
                <span>{formatDistance(dist, units, lang)}</span>
              </div>
              <div className="detail-row">
                <span>🚗 {t('approxDrive')}</span>
                <span>{formatMinutes(estimateMinutes(dist, 'drive'), lang)}</span>
              </div>
              <div className="detail-row">
                <span>🚶 {t('approxWalk')}</span>
                <span>{formatMinutes(estimateMinutes(dist, 'walk'), lang)}</span>
              </div>
            </>
          )}
          <div className="detail-row">
            <span>🕒 {t('openingHours')}</span>
            <span>
              {place.opening?.isOpen === true && <span className="open">{t('open_now')} · </span>}
              {place.opening?.isOpen === false && <span className="closed">{t('closed_now')} · </span>}
              {place.opening?.raw ?? t('hours_unknown')}
            </span>
          </div>
          {place.fee !== undefined && (
            <div className="detail-row">
              <span>💶</span>
              <span>{place.fee ? t('paid') : t('free')}</span>
            </div>
          )}
          {place.address && (
            <div className="detail-row">
              <span>🏠 {t('address')}</span>
              <span>{place.address}</span>
            </div>
          )}
          <TriState label={`♿ ${t('accessible')}`} value={place.wheelchair} />
          <TriState label={`👨‍👩‍👧 ${t('familyFriendly')}`} value={place.familyFriendly} />
          <TriState label={`🐕 ${t('dogFriendly')}`} value={place.dogFriendly} />
          <TriState label={`🚻 ${t('toilets')}`} value={place.toilets} />
          <TriState label={`🅿️ ${t('parking')}`} value={place.parking} />
          {place.website && (
            <div className="detail-row">
              <span>🔗 {t('website')}</span>
              <a href={place.website} target="_blank" rel="noopener noreferrer">
                {place.website.replace(/^https?:\/\//, '').slice(0, 40)}
              </a>
            </div>
          )}
          {place.phone && (
            <div className="detail-row">
              <span>📞 {t('phone')}</span>
              <a href={`tel:${place.phone}`}>{place.phone}</a>
            </div>
          )}
        </div>

        {place.photospot && (
          <div className="photo-box">
            <h4>📸 {t('photoTips')}</h4>
            <div className="detail-row">
              <span>{t('bestTime')}</span>
              <span>{t(`time_${place.photospot.bestTime ?? 'day'}` as keyof Dict)}</span>
            </div>
            <div className="detail-row">
              <span>🌅 {t('sunrise')} / 🌇 {t('sunset')}</span>
              <span>
                {fmtTime(sun.sunrise)} / {fmtTime(sun.sunset)}
              </span>
            </div>
            {place.photospot.direction !== undefined && (
              <div className="detail-row">
                <span>🧭</span>
                <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}>
                  <span
                    aria-hidden
                    style={{ display: 'inline-block', transform: `rotate(${place.photospot.direction}deg)` }}
                  >
                    ⬆️
                  </span>
                  {place.photospot.direction}°
                </span>
              </div>
            )}
            {place.photospot.tip && (
              <p className="photo-tip">💡 {t(place.photospot.tip as keyof Dict)}</p>
            )}
            <div className="place-meta">
              {place.photospot.kinds.map((k) => (
                <span key={k} className="badge">{t(`ps_${k}` as keyof Dict)}</span>
              ))}
            </div>
          </div>
        )}

        <div className="nav-box">
          <div className="mode-row" role="radiogroup" aria-label={t('navigate')}>
            {MODES.map((m) => (
              <button
                key={m.id}
                className={`chip ${mode === m.id ? 'chip-active' : ''}`}
                onClick={() => setMode(m.id)}
                role="radio"
                aria-checked={mode === m.id}
              >
                {m.icon} {t(m.id)}
              </button>
            ))}
          </div>
          <div className="navapp-row">
            {navApps.map((app) => (
              <a
                key={app.id}
                className="btn btn-primary"
                href={buildNavUrl(app.id, place, mode)}
                target="_blank"
                rel="noopener noreferrer"
              >
                🧭 {app.label}
              </a>
            ))}
          </div>
          <button className="btn" onClick={() => void share()}>
            {copied ? `✅ ${t('linkCopied')}` : `📤 ${t('share')}`}
          </button>
        </div>
      </div>
    </div>
  );
}
