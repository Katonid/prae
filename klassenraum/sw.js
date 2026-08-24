/* Service Worker: App-Dateien offline verfügbar halten. */

const CACHE = 'klassenraum-v1';
const ASSETS = [
  './',
  './index.html',
  './css/app.css',
  './manifest.webmanifest',
  '../firebase-config.js',
  './icons/icon.svg',
  './icons/icon-192.png',
  './icons/icon-512.png',
  './js/app.js',
  './js/board.js',
  './js/store.js',
  './js/ui.js',
  './js/util.js',
  './js/icons.js',
  './js/lists.js',
  './js/share.js',
  './js/cloud.js',
  './js/widgets/index.js',
  './js/widgets/randomizer.js',
  './js/widgets/timer.js',
  './js/widgets/clock.js',
  './js/widgets/traffic.js',
  './js/widgets/checklist.js',
  './js/widgets/text.js',
  './js/widgets/image.js',
  './js/widgets/noise.js',
  './js/widgets/symbols.js',
];

self.addEventListener('install', (event) => {
  event.waitUntil(caches.open(CACHE).then((cache) => cache.addAll(ASSETS)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (event) => {
  event.waitUntil(caches.keys().then((keys) => Promise.all(
    keys.filter((key) => key !== CACHE).map((key) => caches.delete(key)),
  )).then(() => self.clients.claim()));
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;

  event.respondWith(
    fetch(request)
      .then((response) => {
        const copy = response.clone();
        caches.open(CACHE).then((cache) => cache.put(request, copy)).catch(() => {});
        return response;
      })
      .catch(() => caches.match(request).then((cached) => cached || caches.match('./index.html'))),
  );
});
