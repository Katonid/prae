/* Himmelskompass – Service Worker */
const VERSION = 'v8';
const APP_CACHE = 'himmelskompass-app-' + VERSION;
const RUNTIME_CACHE = 'himmelskompass-runtime-' + VERSION;

const APP_SHELL = [
  './',
  './index.html',
  './style.css',
  './app.js',
  './astro.js',
  './iss.js',
  './ar.js',
  './vendor/satellite/satellite.min.js',
  './manifest.webmanifest',
  './icons/icon.svg',
  './icons/icon-192.png',
  './icons/icon-512.png',
  './icons/icon-maskable-512.png',
  './vendor/tz-lookup/tz.js',
  './vendor/leaflet/leaflet.css',
  './vendor/leaflet/leaflet.js',
  './vendor/leaflet/images/marker-icon.png',
  './vendor/leaflet/images/marker-icon-2x.png',
  './vendor/leaflet/images/marker-shadow.png',
  './vendor/leaflet/images/layers.png',
  './vendor/leaflet/images/layers-2x.png'
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(APP_CACHE)
      .then((cache) => cache.addAll(APP_SHELL))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(
        keys
          .filter((k) => k.startsWith('himmelskompass-') && k !== APP_CACHE && k !== RUNTIME_CACHE)
          .map((k) => caches.delete(k))
      ))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);
  if (event.request.method !== 'GET') return;

  // Live-Daten (Ortsnamen, ISS-Bahndaten, Weltraumwetter) nie cachen –
  // die App hat dafür eigene localStorage-Caches
  if (url.hostname.includes('nominatim') ||
      url.hostname.includes('celestrak') ||
      url.hostname.includes('swpc.noaa.gov')) return;

  // Kartenkacheln: Netz zuerst, Cache als Offline-Fallback
  if (url.hostname.includes('tile.openstreetmap.org')) {
    event.respondWith(
      fetch(event.request)
        .then((resp) => {
          const copy = resp.clone();
          caches.open(RUNTIME_CACHE).then((c) => c.put(event.request, copy));
          return resp;
        })
        .catch(() => caches.match(event.request))
    );
    return;
  }

  // App-Shell: Cache zuerst
  event.respondWith(
    caches.match(event.request).then((cached) => {
      if (cached) return cached;
      return fetch(event.request).then((resp) => {
        if (resp.ok && url.origin === self.location.origin) {
          const copy = resp.clone();
          caches.open(RUNTIME_CACHE).then((c) => c.put(event.request, copy));
        }
        return resp;
      });
    })
  );
});
