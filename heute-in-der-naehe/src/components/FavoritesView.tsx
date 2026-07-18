import { useMemo, useState } from 'react';
import { useT } from '../i18n';
import { useApp } from '../state/store';
import type { FavoriteEntry, Place } from '../types';
import { putFavorite } from '../services/db';
import { PlaceCard } from './PlaceCard';
import { PlaceDetail } from './PlaceDetail';

export function FavoritesView() {
  const { t } = useT();
  const { favorites } = useApp();
  const [selected, setSelected] = useState<Place | null>(null);
  const [activeList, setActiveList] = useState<string>('');
  const [newListName, setNewListName] = useState('');
  const [, forceUpdate] = useState(0);

  const entries = useMemo(
    () => [...favorites.values()].sort((a, b) => b.addedAt - a.addedAt),
    [favorites],
  );

  const listNames = useMemo(() => {
    const names = new Set<string>();
    for (const e of entries) for (const l of e.lists) names.add(l);
    return [...names].sort();
  }, [entries]);

  const shown = activeList ? entries.filter((e) => e.lists.includes(activeList)) : entries;

  const toggleList = async (entry: FavoriteEntry, list: string) => {
    if (entry.lists.includes(list)) entry.lists = entry.lists.filter((l) => l !== list);
    else entry.lists = [...entry.lists, list];
    await putFavorite(entry);
    forceUpdate((n) => n + 1);
  };

  return (
    <div className="favorites">
      <h2>❤️ {t('favorites')}</h2>
      {entries.length === 0 ? (
        <div className="results-empty">
          <p className="empty-emoji" aria-hidden>🤍</p>
          <p>{t('noFavorites')}</p>
          <p className="hint">{t('favoritesHint')}</p>
        </div>
      ) : (
        <>
          <p className="hint">💾 {t('savedOffline')}</p>
          <div className="quick-filters">
            <button
              className={`chip ${activeList === '' ? 'chip-active' : ''}`}
              onClick={() => setActiveList('')}
            >
              {t('allFavorites')} ({entries.length})
            </button>
            {listNames.map((l) => (
              <button
                key={l}
                className={`chip ${activeList === l ? 'chip-active' : ''}`}
                onClick={() => setActiveList(l)}
              >
                📁 {l}
              </button>
            ))}
          </div>
          <form
            className="newlist-row"
            onSubmit={(e) => {
              e.preventDefault();
              const name = newListName.trim();
              if (name) setActiveList(name);
              setNewListName('');
            }}
          >
            <input
              className="input"
              value={newListName}
              onChange={(e) => setNewListName(e.target.value)}
              placeholder={t('listNamePlaceholder')}
              aria-label={t('newList')}
            />
            <button className="btn" type="submit">
              ➕ {t('newList')}
            </button>
          </form>
          <div className="place-list">
            {shown.map((e) => (
              <div key={e.placeId} className="fav-entry">
                <PlaceCard place={e.place} onOpen={() => setSelected(e.place)} />
                {(listNames.length > 0 || activeList) && (
                  <div className="fav-lists">
                    {[...new Set([...listNames, activeList].filter(Boolean))].map((l) => (
                      <button
                        key={l}
                        className={`chip chip-small ${e.lists.includes(l) ? 'chip-active' : ''}`}
                        onClick={() => void toggleList(e, l)}
                      >
                        {l}
                      </button>
                    ))}
                  </div>
                )}
              </div>
            ))}
          </div>
        </>
      )}
      {selected && <PlaceDetail place={selected} onClose={() => setSelected(null)} />}
    </div>
  );
}
