/* Service Worker: die App offline verfügbar halten — und zuverlässig auffrischen.
 *
 * Dieselbe Bauart wie im Klassenraum: Es wird IMMER beim Server nachgefragt,
 * nur ohne Netz kommt die Antwort aus dem Zwischenspeicher. Andersherum
 * („erst der Zwischenspeicher“) läuft ein iPad im Schrank monatelang mit einer
 * alten Fassung, ohne dass jemand merkt, warum ein Fehler nicht verschwindet.
 *
 * Die Fassungsnummer muss bei jeder neuen Fassung hochgezählt werden — sonst
 * bleibt der alte Zwischenspeicher stehen.
 */

const FASSUNG = 'v19';
const SPEICHER = `woerterwerkstatt-${FASSUNG}`;

const DATEIEN = [
  './',
  './index.html',
  './manifest.webmanifest',
  './css/app.css',
  './css/fonts.css',
  './fonts/andika-400-latin.woff2',
  './fonts/andika-400-latin-ext.woff2',
  './fonts/andika-700-latin.woff2',
  './fonts/lexend-latin.woff2',
  './fonts/quicksand-latin.woff2',
  './icons/icon.svg',
  './icons/icon-32.png',
  './icons/icon-120.png',
  './icons/icon-152.png',
  './icons/icon-167.png',
  './icons/icon-180.png',
  './icons/icon-192.png',
  './icons/icon-512.png',
  './icons/icon-192-maskable.png',
  './icons/icon-512-maskable.png',
  './js/admin.js',
  './js/app.js',
  './js/util.js',
  './js/ui.js',
  './js/store.js',
  './js/theme.js',
  './js/sfx.js',
  './js/plattform.js',
  './js/version.js',
  './js/woerter.js',
  './js/rechtschreibung.js',
  './js/rechtschreibung1.js',
  './js/rechtschreibung2.js',
  './js/rechtschreibung3.js',
  './js/grammatik.js',
  './js/wortbild.js',
  './js/paket.js',
  './js/lauf.js',
  './js/qr.js',
  './js/cloud.js',
  './js/klasse.js',
  './js/bereiche.js',
  './js/einstellungen.js',
  './js/uebungen/index.js',
  './js/uebungen/schreibfeld.js',
  './js/uebungen/abschreiben.js',
  './js/uebungen/salat.js',
  './js/uebungen/geheimschrift.js',
  './js/uebungen/wortart.js',
  './js/uebungen/diktat.js',
];

self.addEventListener('install', (ereignis) => {
  ereignis.waitUntil(
    caches.open(SPEICHER)
      // 'reload' holt frische Dateien vom Server statt aus dem Browser-Cache.
      .then((speicher) => speicher.addAll(DATEIEN.map((adresse) => new Request(adresse, { cache: 'reload' }))))
      .then(() => self.skipWaiting())
      .catch(() => self.skipWaiting()),
  );
});

self.addEventListener('activate', (ereignis) => {
  ereignis.waitUntil(
    caches.keys()
      .then((namen) => Promise.all(namen.filter((name) => name !== SPEICHER).map((name) => caches.delete(name))))
      .then(() => self.clients.claim()),
  );
});

self.addEventListener('message', (ereignis) => {
  if (ereignis.data && ereignis.data.type === 'skip-waiting') self.skipWaiting();
});

self.addEventListener('fetch', (ereignis) => {
  const anfrage = ereignis.request;
  if (anfrage.method !== 'GET') return;
  const adresse = new URL(anfrage.url);
  // Alles Fremde (Firebase) geht am Zwischenspeicher vorbei: Eine
  // zwischengespeicherte Anmeldung oder Klassenliste wäre schlimmer als keine.
  if (adresse.origin !== self.location.origin) return;

  ereignis.respondWith(
    fetch(new Request(anfrage, { cache: 'no-cache' }))
      .then((antwort) => {
        if (antwort && antwort.ok) {
          const kopie = antwort.clone();
          caches.open(SPEICHER).then((speicher) => speicher.put(anfrage, kopie)).catch(() => {});
        }
        return antwort;
      })
      .catch(() => caches.match(anfrage).then((gefunden) => gefunden || caches.match('./index.html'))),
  );
});
