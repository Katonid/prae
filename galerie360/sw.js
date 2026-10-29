/*
 * Galerie 360 — Service Worker: Generator offline und als App vom
 * Home-Bildschirm. Bei jeder neuen Fassung FASSUNG hochzählen, sonst
 * bleibt auf den Geräten die alte Fassung im Zwischenspeicher.
 * Die Galerien selbst (Blob-Adressen, Browser-Speicher) laufen nicht hier durch.
 */
const FASSUNG = 'v12';
const DATEIEN = [
  './',
  './index.html',
  './anleitung.html',
  './manifest.webmanifest',
  './css/generator.css',
  './galerie/galerie.css',
  './galerie/galerie.js',
  './js/medien.js',
  './js/speicher.js',
  './js/export.js',
  './js/app.js',
  './js/hotspots.js',
  './vendor/lucide.js',
  './vendor/emoji.js',
  './icons/icon.svg',
  './icons/icon-180.png',
  './icons/icon-192.png',
  './icons/icon-512.png'
];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open('galerie360-' + FASSUNG).then((c) => c.addAll(DATEIEN)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (e) => {
  e.waitUntil(caches.keys()
    .then((k) => Promise.all(k.filter((n) => n.startsWith('galerie360-') && n !== 'galerie360-' + FASSUNG).map((n) => caches.delete(n))))
    .then(() => self.clients.claim()));
});

self.addEventListener('fetch', (e) => {
  const r = e.request;
  const u = new URL(r.url);
  if (r.method !== 'GET' || u.origin !== location.origin) return;
  // Die Galerien im Unterordner 360Grad/ gehören nicht zum Generator — nie aus dessen Zwischenspeicher.
  if (u.pathname.includes('/360Grad/')) return;
  // Zuerst aus dem Zwischenspeicher (offline), sonst übers Netz.
  e.respondWith(caches.match(r, { ignoreSearch: true }).then((t) => t || fetch(r)));
});
