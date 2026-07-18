import { useState } from 'react';
import { useT } from '../i18n';
import { useApp } from '../state/store';
import type { CategoryId, Lang, NavApp, ThemeMode } from '../types';
import { CATEGORIES } from '../config/categories';
import { NAV_APPS } from '../services/navigation';
import { deleteAllLocalData } from '../services/db';
import { formatDistance } from '../services/geo';

const RADII = [1000, 2000, 5000, 10000, 25000, 50000, 100000];

export function SettingsView() {
  const { t, lang } = useT();
  const { settings, updateSettings, units } = useApp();
  const [deleted, setDeleted] = useState(false);

  const toggleHidden = (id: CategoryId) => {
    const hidden = settings.hiddenCategories.includes(id)
      ? settings.hiddenCategories.filter((c) => c !== id)
      : [...settings.hiddenCategories, id];
    updateSettings({ hiddenCategories: hidden });
  };

  return (
    <div className="settings">
      <h2>⚙️ {t('settings')}</h2>

      <label className="setting-row">
        <span>{t('set_language')}</span>
        <select
          value={settings.lang}
          onChange={(e) => updateSettings({ lang: e.target.value as Lang | 'auto' })}
        >
          <option value="auto">{t('set_auto')}</option>
          <option value="de">Deutsch</option>
          <option value="en">English</option>
          <option value="fr">Français</option>
        </select>
      </label>

      <label className="setting-row">
        <span>{t('set_theme')}</span>
        <select
          value={settings.theme}
          onChange={(e) => updateSettings({ theme: e.target.value as ThemeMode })}
        >
          <option value="auto">{t('set_auto')}</option>
          <option value="light">{t('theme_light')}</option>
          <option value="dark">{t('theme_dark')}</option>
        </select>
      </label>

      <label className="setting-row">
        <span>{t('set_units')}</span>
        <select
          value={settings.units}
          onChange={(e) => updateSettings({ units: e.target.value as 'metric' | 'imperial' | 'auto' })}
        >
          <option value="auto">{t('set_auto')}</option>
          <option value="metric">{t('units_metric')}</option>
          <option value="imperial">{t('units_imperial')}</option>
        </select>
      </label>

      <label className="setting-row">
        <span>{t('set_temp')}</span>
        <select
          value={settings.tempUnit}
          onChange={(e) => updateSettings({ tempUnit: e.target.value as 'c' | 'f' | 'auto' })}
        >
          <option value="auto">{t('set_auto')}</option>
          <option value="c">°C</option>
          <option value="f">°F</option>
        </select>
      </label>

      <label className="setting-row">
        <span>{t('set_radius')}</span>
        <select
          value={settings.defaultRadiusM}
          onChange={(e) => updateSettings({ defaultRadiusM: parseInt(e.target.value, 10) })}
        >
          {RADII.map((r) => (
            <option key={r} value={r}>
              {formatDistance(r, units, lang)}
            </option>
          ))}
        </select>
      </label>

      <label className="setting-row">
        <span>{t('set_navapp')}</span>
        <select
          value={settings.preferredNavApp}
          onChange={(e) => updateSettings({ preferredNavApp: e.target.value as NavApp })}
        >
          {NAV_APPS.map((a) => (
            <option key={a.id} value={a.id}>
              {a.label}
            </option>
          ))}
        </select>
      </label>

      <label className="setting-row">
        <span>
          {t('set_familyMode')}
          <small className="hint-inline">{t('set_familyMode_hint')}</small>
        </span>
        <input
          type="checkbox"
          checked={settings.familyMode}
          onChange={(e) => updateSettings({ familyMode: e.target.checked })}
        />
      </label>

      <label className="setting-row">
        <span>
          {t('set_reducedData')}
          <small className="hint-inline">{t('set_reducedData_hint')}</small>
        </span>
        <input
          type="checkbox"
          checked={settings.reducedData}
          onChange={(e) => updateSettings({ reducedData: e.target.checked })}
        />
      </label>

      <h3>{lang === 'de' ? 'Kategorien' : lang === 'fr' ? 'Catégories' : 'Categories'}</h3>
      <div className="quick-filters">
        {CATEGORIES.map((c) => (
          <button
            key={c.id}
            className={`chip ${settings.hiddenCategories.includes(c.id) ? '' : 'chip-active'}`}
            onClick={() => toggleHidden(c.id)}
            aria-pressed={!settings.hiddenCategories.includes(c.id)}
          >
            {c.icon} {t(`cat_${c.id}`)}
          </button>
        ))}
      </div>

      <h3>🔒 {t('set_privacy')}</h3>
      <p className="privacy-text">{t('privacy_text')}</p>
      <button
        className="btn btn-danger"
        onClick={async () => {
          if (window.confirm(t('deleteAllDataConfirm'))) {
            await deleteAllLocalData();
            setDeleted(true);
            setTimeout(() => window.location.reload(), 1200);
          }
        }}
      >
        🗑️ {t('deleteAllData')}
      </button>
      {deleted && <p className="hint">✅ {t('dataDeleted')}</p>}

      <h3>ℹ️ {t('about')}</h3>
      <p className="privacy-text">{t('aboutText')}</p>
      <p className="attribution">
        {t('dataFromOsm')} · Overpass API · Nominatim · Open-Meteo · Wikimedia
      </p>
    </div>
  );
}
