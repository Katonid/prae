import { useEffect, useState } from 'react';
import { useT } from '../i18n';
import { useApp } from '../state/store';
import { describeWeather } from '../services/weather';

export function Header({ onPickLocation }: { onPickLocation: () => void }) {
  const { t, lang } = useT();
  const { location, locationStatus, locate, weather, tempUnit } = useApp();
  const [now, setNow] = useState(new Date());

  useEffect(() => {
    const id = setInterval(() => setNow(new Date()), 30000);
    return () => clearInterval(id);
  }, []);

  const temp =
    weather &&
    (tempUnit === 'f'
      ? `${Math.round((weather.temperatureC * 9) / 5 + 32)} °F`
      : `${Math.round(weather.temperatureC)} °C`);
  const wDesc = weather ? describeWeather(weather.weatherCode, weather.isDay) : null;

  return (
    <header className="header">
      <div className="header-top">
        <button className="header-location" onClick={onPickLocation} title={t('chooseLocation')}>
          <span className="header-pin" aria-hidden>📍</span>
          <span className="header-place">
            {locationStatus === 'locating'
              ? t('locating')
              : location?.label ??
                (location ? `${location.lat.toFixed(3)}, ${location.lon.toFixed(3)}` : t('chooseLocation'))}
          </span>
          <span className="header-caret" aria-hidden>▾</span>
        </button>
        <button
          className="icon-btn"
          onClick={() => void locate()}
          title={t('refreshLocation')}
          aria-label={t('refreshLocation')}
        >
          🔄
        </button>
      </div>
      <div className="header-meta">
        <span>{now.toLocaleTimeString(lang, { hour: '2-digit', minute: '2-digit' })}</span>
        {wDesc && temp && (
          <span>
            {wDesc.emoji} {t(wDesc.key)} · {temp}
          </span>
        )}
        {location?.accuracy !== undefined && location.source === 'gps' && (
          <span className="header-accuracy">
            {t('locationAccuracy')}: ±{Math.round(location.accuracy)} m
          </span>
        )}
      </div>
    </header>
  );
}
