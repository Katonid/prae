/* Service Worker: die App auch ohne Netz starten.
 *
 * Wie bei den anderen Web-Apps im Repo: IMMER zuerst beim Server nachfragen,
 * nur ohne Antwort aus dem Zwischenspeicher — sonst liefe ein Gerät
 * monatelang mit einer alten Fassung. Fremde Seiten (Suchlinks) laufen
 * hier nicht durch.
 *
 * FASSUNG bei jeder neuen Fassung hochzählen — sonst bleibt der alte
 * Zwischenspeicher stehen. Neue Dateien in DATEIEN eintragen.
 */

const FASSUNG = 'v1';
const SPEICHER = `rufnummer-${FASSUNG}`;

const DATEIEN = [
  './',
  './index.html',
  './manifest.webmanifest',
  './css/app.css',
  './js/app.js',
  './js/nummer.js',
  './js/speicher.js',
  './js/vcard.js',
  './daten/vorwahlen.json',
  './icons/icon.svg',
  './icons/icon-32.png',
  './icons/icon-180.png',
  './icons/icon-192.png',
  './icons/icon-512.png',
];

self.addEventListener('install', (ereignis) => {
  ereignis.waitUntil(
    caches.open(SPEICHER)
      .then((speicher) => speicher.addAll(DATEIEN))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (ereignis) => {
  ereignis.waitUntil(
    caches.keys()
      .then((namen) => Promise.all(namen
        .filter((n) => n.startsWith('rufnummer-') && n !== SPEICHER)
        .map((n) => caches.delete(n))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (ereignis) => {
  const anfrage = ereignis.request;
  if (anfrage.method !== 'GET') return;
  if (new URL(anfrage.url).origin !== self.location.origin) return;

  ereignis.respondWith(
    fetch(anfrage)
      .then((antwort) => {
        if (antwort && antwort.ok) {
          const kopie = antwort.clone();
          caches.open(SPEICHER).then((speicher) => speicher.put(anfrage, kopie));
        }
        return antwort;
      })
      .catch(() => caches.match(anfrage, { ignoreSearch: true })
        .then((gefunden) => gefunden || caches.match('./index.html')))
  );
});
