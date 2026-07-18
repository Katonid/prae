import { useEffect, useRef, useState } from 'react';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import 'leaflet.markercluster';
import 'leaflet.markercluster/dist/MarkerCluster.css';
import 'leaflet.markercluster/dist/MarkerCluster.Default.css';
import { useT } from '../i18n';
import { useApp } from '../state/store';
import type { LatLng, Place } from '../types';
import { formatDistance } from '../services/geo';
import { getCategory } from '../config/categories';

const OSM_TILES = 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';
const SAT_TILES =
  'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
const OSM_ATTR = '© OpenStreetMap contributors';
const SAT_ATTR = 'Imagery © Esri';

interface Props {
  center: LatLng;
  radiusM: number;
  places: Place[];
  onSelect(place: Place): void;
  onSearchArea(center: LatLng): void;
}

function categoryIcon(place: Place): L.DivIcon {
  const cat = getCategory(place.category);
  return L.divIcon({
    className: 'poi-marker-wrap',
    html: `<div class="poi-marker" style="--tile-color:${cat.color}">${cat.icon}</div>`,
    iconSize: [34, 34],
    iconAnchor: [17, 17],
  });
}

export function MapView({ center, radiusM, places, onSelect, onSearchArea }: Props) {
  const { t, lang } = useT();
  const { units, location } = useApp();
  const containerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<L.Map | null>(null);
  const clusterRef = useRef<L.MarkerClusterGroup | null>(null);
  const circleRef = useRef<L.Circle | null>(null);
  const tileRef = useRef<L.TileLayer | null>(null);
  const [satellite, setSatellite] = useState(false);
  const [moved, setMoved] = useState(false);
  const onSelectRef = useRef(onSelect);
  onSelectRef.current = onSelect;

  // init map once
  useEffect(() => {
    if (!containerRef.current || mapRef.current) return;
    const map = L.map(containerRef.current, { zoomControl: true }).setView(
      [center.lat, center.lon],
      radiusM > 30000 ? 10 : radiusM > 8000 ? 12 : 14,
    );
    tileRef.current = L.tileLayer(OSM_TILES, { attribution: OSM_ATTR, maxZoom: 19 }).addTo(map);
    clusterRef.current = L.markerClusterGroup({ maxClusterRadius: 46 });
    map.addLayer(clusterRef.current);
    circleRef.current = L.circle([center.lat, center.lon], {
      radius: radiusM,
      color: '#0ea5e9',
      weight: 1.5,
      fillOpacity: 0.05,
    }).addTo(map);
    // debounce "map moved" detection
    let timer: ReturnType<typeof setTimeout>;
    map.on('moveend', () => {
      clearTimeout(timer);
      timer = setTimeout(() => setMoved(true), 400);
    });
    mapRef.current = map;
    return () => {
      map.remove();
      mapRef.current = null;
      clusterRef.current = null;
      circleRef.current = null;
      tileRef.current = null;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // tile layer switch
  useEffect(() => {
    const map = mapRef.current;
    if (!map || !tileRef.current) return;
    tileRef.current.remove();
    tileRef.current = L.tileLayer(satellite ? SAT_TILES : OSM_TILES, {
      attribution: satellite ? SAT_ATTR : OSM_ATTR,
      maxZoom: 19,
    }).addTo(map);
  }, [satellite]);

  // markers
  useEffect(() => {
    const cluster = clusterRef.current;
    if (!cluster) return;
    cluster.clearLayers();
    for (const p of places) {
      const marker = L.marker([p.lat, p.lon], { icon: categoryIcon(p) });
      const dist = p.distanceM !== undefined ? formatDistance(p.distanceM, units, lang) : '';
      const status =
        p.opening?.isOpen === true
          ? `<span class="open">● ${t('open_now')}</span>`
          : p.opening?.isOpen === false
            ? `<span class="closed">● ${t('closed_now')}</span>`
            : '';
      const el = document.createElement('div');
      el.className = 'map-popup';
      el.innerHTML = `<strong>${p.name.replace(/</g, '&lt;')}</strong><br>📍 ${dist} ${status}<br>`;
      const btn = document.createElement('button');
      btn.className = 'btn btn-primary btn-small';
      btn.textContent = t('details');
      btn.addEventListener('click', () => onSelectRef.current(p));
      el.appendChild(btn);
      marker.bindPopup(el);
      cluster.addLayer(marker);
    }
  }, [places, units, lang, t]);

  // search circle + recenter on center change
  useEffect(() => {
    circleRef.current?.setLatLng([center.lat, center.lon]);
    circleRef.current?.setRadius(radiusM);
  }, [center.lat, center.lon, radiusM]);

  const recenter = () => {
    if (location) {
      mapRef.current?.setView([location.lat, location.lon], 14);
    }
  };

  const searchHere = () => {
    const c = mapRef.current?.getCenter();
    if (c) {
      setMoved(false);
      onSearchArea({ lat: c.lat, lon: c.lng });
    }
  };

  return (
    <div className="map-wrap">
      <div ref={containerRef} className="map" />
      <div className="map-controls">
        <button className="btn map-btn" onClick={recenter} title={t('myLocation')}>
          🎯
        </button>
        <button
          className="btn map-btn"
          onClick={() => setSatellite((v) => !v)}
          aria-pressed={satellite}
          title="Satellit"
        >
          {satellite ? '🗺️' : '🛰️'}
        </button>
      </div>
      {moved && (
        <button className="btn btn-primary map-search-btn" onClick={searchHere}>
          🔍 {t('searchThisArea')}
        </button>
      )}
    </div>
  );
}
