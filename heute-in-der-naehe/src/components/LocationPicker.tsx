import { useEffect, useRef, useState } from 'react';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { useT } from '../i18n';
import { useApp } from '../state/store';
import type { UserLocation } from '../types';
import { geocoder } from '../services/providers';
import type { GeocodeResult } from '../services/providers/types';
import { getRecentLocations } from '../services/db';

/**
 * Location fallback: search a place/address (Nominatim, debounced),
 * pick a point on a map, or reuse a recent location. Ensures the app
 * stays fully usable when geolocation is denied or unavailable.
 */
export function LocationPicker({ onClose }: { onClose: () => void }) {
  const { t, lang } = useT();
  const { setManualLocation, locate, location } = useApp();
  const [text, setText] = useState('');
  const [results, setResults] = useState<GeocodeResult[]>([]);
  const [searching, setSearching] = useState(false);
  const [error, setError] = useState(false);
  const [recents, setRecents] = useState<UserLocation[]>([]);
  const [mapMode, setMapMode] = useState(false);
  const mapDivRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<L.Map | null>(null);
  const markerRef = useRef<L.Marker | null>(null);
  const pickedRef = useRef<{ lat: number; lon: number } | null>(null);
  const debounceRef = useRef<ReturnType<typeof setTimeout>>();

  useEffect(() => {
    getRecentLocations().then(setRecents).catch(() => undefined);
  }, []);

  // debounced geocoding
  useEffect(() => {
    clearTimeout(debounceRef.current);
    if (text.trim().length < 3) {
      setResults([]);
      return;
    }
    debounceRef.current = setTimeout(async () => {
      setSearching(true);
      setError(false);
      try {
        const r = await geocoder.search(text.trim(), lang);
        setResults(r);
      } catch {
        setError(true);
      } finally {
        setSearching(false);
      }
    }, 450);
    return () => clearTimeout(debounceRef.current);
  }, [text, lang]);

  // map picker
  useEffect(() => {
    if (!mapMode || !mapDivRef.current || mapRef.current) return;
    const start = location ?? { lat: 48.2, lon: 11.5 };
    const map = L.map(mapDivRef.current).setView([start.lat, start.lon], location ? 11 : 4);
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '© OpenStreetMap contributors',
      maxZoom: 19,
    }).addTo(map);
    map.on('click', (e: L.LeafletMouseEvent) => {
      pickedRef.current = { lat: e.latlng.lat, lon: e.latlng.lng };
      if (markerRef.current) markerRef.current.setLatLng(e.latlng);
      else markerRef.current = L.marker(e.latlng).addTo(map);
    });
    mapRef.current = map;
    return () => {
      map.remove();
      mapRef.current = null;
      markerRef.current = null;
    };
  }, [mapMode, location]);

  const choose = (loc: UserLocation) => {
    setManualLocation(loc);
    onClose();
  };

  return (
    <div className="sheet-backdrop" onClick={onClose}>
      <div
        className="sheet"
        role="dialog"
        aria-modal="true"
        aria-label={t('chooseLocation')}
        onClick={(e) => e.stopPropagation()}
      >
        <div className="sheet-header">
          <h3>{t('chooseLocation')}</h3>
          <button className="icon-btn" onClick={onClose} aria-label={t('close')}>
            ✕
          </button>
        </div>

        <button
          className="btn btn-block"
          onClick={() => {
            void locate();
            onClose();
          }}
        >
          🎯 {t('myLocation')}
        </button>

        <input
          className="input"
          type="search"
          value={text}
          placeholder={t('searchPlacePlaceholder')}
          onChange={(e) => setText(e.target.value)}
          autoFocus
        />
        {searching && <p className="hint">{t('loading')}</p>}
        {error && <p className="hint">⚠️ {t('errApi')}</p>}
        {results.length > 0 && (
          <ul className="picker-list">
            {results.map((r, i) => (
              <li key={i}>
                <button
                  className="picker-item"
                  onClick={() =>
                    choose({
                      lat: r.lat,
                      lon: r.lon,
                      label: r.label,
                      countryCode: r.countryCode,
                      source: 'manual',
                      timestamp: Date.now(),
                    })
                  }
                >
                  📍 {r.label}
                </button>
              </li>
            ))}
          </ul>
        )}

        {!mapMode ? (
          <button className="btn btn-block" onClick={() => setMapMode(true)}>
            🗺️ {t('pickOnMap')}
          </button>
        ) : (
          <>
            <div ref={mapDivRef} className="picker-map" />
            <button
              className="btn btn-primary btn-block"
              onClick={() => {
                if (pickedRef.current) {
                  choose({
                    ...pickedRef.current,
                    source: 'map',
                    timestamp: Date.now(),
                  });
                }
              }}
            >
              ✅ {t('useThisPoint')}
            </button>
          </>
        )}

        {recents.length > 0 && (
          <>
            <h4 className="picker-heading">{t('recentLocations')}</h4>
            <ul className="picker-list">
              {recents.map((r) => (
                <li key={r.timestamp}>
                  <button
                    className="picker-item"
                    onClick={() => choose({ ...r, source: 'recent', timestamp: Date.now() })}
                  >
                    🕘 {r.label ?? `${r.lat.toFixed(3)}, ${r.lon.toFixed(3)}`}
                  </button>
                </li>
              ))}
            </ul>
          </>
        )}
      </div>
    </div>
  );
}
