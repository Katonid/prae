/* Service Worker: die App auf dem Homescreen auch ohne Netz starten lassen.
 *
 * Es wird IMMER beim Server nachgefragt; nur wenn keine Antwort kommt, kommt
 * sie aus dem Zwischenspeicher. Andersherum („erst der Zwischenspeicher")
 * liefe ein Gerät monatelang mit einer alten Fassung, ohne dass jemand merkt,
 * warum ein behobener Fehler nicht verschwindet.
 *
 * Die Fassungsnummer muss bei jeder neuen Fassung hochgezählt werden — sonst
 * bleibt der alte Zwischenspeicher stehen.
 */

const FASSUNG = 'v1';
const SPEICHER = `textauszug-${FASSUNG}`;

const DATEIEN = [
  './',
  './index.html',
  './manifest.webmanifest',
  './css/style.css',
  './js/app.js',
  './js/auszug.js',
  './js/pdf.js',
  './js/inflate.js',
  './js/schrift.js',
  './js/inhalt.js',
  './js/aufbereiten.js',
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
      .then((namen) => Promise.all(namen.filter((n) => n !== SPEICHER).map((n) => caches.delete(n))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (ereignis) => {
  const anfrage = ereignis.request;
  if (anfrage.method !== 'GET' || !anfrage.url.startsWith(self.location.origin)) return;
  ereignis.respondWith(
    fetch(anfrage)
      .then((antwort) => {
        if (antwort && antwort.ok) {
          const kopie = antwort.clone();
          caches.open(SPEICHER).then((speicher) => speicher.put(anfrage, kopie));
        }
        return antwort;
      })
      .catch(() => caches.match(anfrage).then((gefunden) => gefunden || caches.match('./index.html')))
  );
});
