/* Service Worker: App-Dateien offline verfügbar halten — und zuverlässig aktualisieren. */

const VERSION = 'v40';
const CACHE = `klassenraum-${VERSION}`;
const ASSETS = [
  './',
  './index.html',
  './css/app.css',
  './css/fonts.css',
  './fonts/lexend-latin.woff2',
  './fonts/lexend-latin-ext.woff2',
  './manifest.webmanifest',
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
  './js/sync.js',
  './js/fonts.js',
  './js/sfx.js',
  './js/version.js',
  './js/theme.js',
  './js/media.js',
  './js/draw.js',
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
  './js/widgets/sound.js',
  './js/widgets/video.js',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE)
      // 'reload' erzwingt frische Dateien vom Server statt aus dem Browser-Cache.
      .then((cache) => cache.addAll(ASSETS.map((url) => new Request(url, { cache: 'reload' }))))
      .then(() => self.skipWaiting())
      .catch(() => self.skipWaiting()),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((key) => key !== CACHE).map((key) => caches.delete(key))))
      .then(() => self.clients.claim())
      .then(() => self.clients.matchAll({ type: 'window' }))
      .then((clients) => clients.forEach((client) => client.postMessage({ type: 'sw-updated', version: VERSION }))),
  );
});

self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'skip-waiting') self.skipWaiting();
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;

  event.respondWith(
    // Immer beim Server nachfragen (mit Revalidierung), damit neue Fassungen
    // sofort ankommen; nur ohne Netz wird aus dem Zwischenspeicher geliefert.
    fetch(new Request(request, { cache: 'no-cache' }))
      .then((response) => {
        if (response && response.ok) {
          const copy = response.clone();
          caches.open(CACHE).then((cache) => cache.put(request, copy)).catch(() => {});
        }
        return response;
      })
      .catch(() => caches.match(request).then((cached) => cached || caches.match('./index.html'))),
  );
});
