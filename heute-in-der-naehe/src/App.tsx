import { useEffect, useState } from 'react';
import { useT } from './i18n';
import { useApp } from './state/store';
import type { CategoryId, QuickFilterId } from './types';
import { Header } from './components/Header';
import { HomeView } from './components/HomeView';
import { ResultsView } from './components/ResultsView';
import { FavoritesView } from './components/FavoritesView';
import { SettingsView } from './components/SettingsView';
import { LocationPicker } from './components/LocationPicker';
import { UpdateToast } from './components/UpdateToast';

export type Route =
  | { name: 'home' }
  | { name: 'results'; category?: CategoryId; filter?: QuickFilterId }
  | { name: 'favorites' }
  | { name: 'settings' };

function parseHash(): Route {
  const hash = window.location.hash.replace(/^#\/?/, '');
  const [path, query] = hash.split('?');
  if (path === 'results') {
    const params = new URLSearchParams(query);
    return {
      name: 'results',
      category: (params.get('cat') as CategoryId) || undefined,
      filter: (params.get('f') as QuickFilterId) || undefined,
    };
  }
  if (path === 'favorites') return { name: 'favorites' };
  if (path === 'settings') return { name: 'settings' };
  return { name: 'home' };
}

export function navigateTo(route: Route) {
  let hash = '#/';
  if (route.name === 'results') {
    const params = new URLSearchParams();
    if (route.category) params.set('cat', route.category);
    if (route.filter) params.set('f', route.filter);
    const q = params.toString();
    hash = `#/results${q ? '?' + q : ''}`;
  } else if (route.name !== 'home') {
    hash = `#/${route.name}`;
  }
  window.location.hash = hash;
}

export default function App() {
  const { t } = useT();
  const { online, locationStatus, locate, location } = useApp();
  const [route, setRoute] = useState<Route>(parseHash);
  const [pickerOpen, setPickerOpen] = useState(false);

  useEffect(() => {
    const onHash = () => setRoute(parseHash());
    window.addEventListener('hashchange', onHash);
    return () => window.removeEventListener('hashchange', onHash);
  }, []);

  // Ask for the location once on startup (explicit browser consent dialog).
  useEffect(() => {
    if (locationStatus === 'idle') void locate();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // If geolocation failed and no manual location is set, offer the picker.
  const needsLocation =
    !location && (locationStatus === 'denied' || locationStatus === 'error');

  return (
    <div className="app">
      {!online && <div className="offline-banner">📡 {t('offline')}</div>}
      <Header onPickLocation={() => setPickerOpen(true)} />

      <main className="main">
        {route.name === 'home' && (
          <HomeView
            onOpenCategory={(category) => navigateTo({ name: 'results', category })}
            onOpenFilter={(filter) => navigateTo({ name: 'results', filter })}
            needsLocation={needsLocation}
            onPickLocation={() => setPickerOpen(true)}
          />
        )}
        {route.name === 'results' && (
          <ResultsView
            key={`${route.category ?? 'all'}|${route.filter ?? ''}`}
            category={route.category}
            initialFilter={route.filter}
          />
        )}
        {route.name === 'favorites' && <FavoritesView />}
        {route.name === 'settings' && <SettingsView />}
      </main>

      <nav className="bottom-nav" aria-label="Hauptnavigation">
        <button
          className={route.name === 'home' ? 'active' : ''}
          onClick={() => navigateTo({ name: 'home' })}
        >
          <span aria-hidden>🧭</span>
          {t('home')}
        </button>
        <button
          className={route.name === 'results' ? 'active' : ''}
          onClick={() => navigateTo({ name: 'results' })}
        >
          <span aria-hidden>🗺️</span>
          {t('search')}
        </button>
        <button
          className={route.name === 'favorites' ? 'active' : ''}
          onClick={() => navigateTo({ name: 'favorites' })}
        >
          <span aria-hidden>❤️</span>
          {t('favorites')}
        </button>
        <button
          className={route.name === 'settings' ? 'active' : ''}
          onClick={() => navigateTo({ name: 'settings' })}
        >
          <span aria-hidden>⚙️</span>
          {t('settings')}
        </button>
      </nav>

      {pickerOpen && <LocationPicker onClose={() => setPickerOpen(false)} />}
      <UpdateToast />
    </div>
  );
}
