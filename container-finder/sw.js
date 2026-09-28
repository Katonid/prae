/* Service Worker: die App auch ohne Netz starten und die zuletzt gesehenen
 * Kartenkacheln zeigen.
 *
 * App-Dateien und amtliche Daten: IMMER zuerst beim Server nachfragen; nur
 * ohne Antwort aus dem Zwischenspeicher (wie bei den anderen Web-Apps im
 * Repo — sonst liefe ein Gerät monatelang mit einer alten Fassung).
 *
 * Kartenkacheln: erst der Zwischenspeicher, dann das Netz — das schont die
 * OSM-Server, wie es deren Nutzungsregeln verlangen. Gespeichert werden NUR
 * angesehene Kacheln (kein Vorab-Laden, das verbieten die Regeln), höchstens
 * KACHEL_MAX Stück, die ältesten fliegen zuerst.
 *
 * OSM-Containerdaten legt die App selbst in IndexedDB ab (js/speicher.js);
 * Overpass und Nominatim laufen hier nur durch.
 *
 * FASSUNG bei jeder neuen Fassung hochzählen — sonst bleibt der alte
 * Zwischenspeicher stehen.
 */

const FASSUNG = 'v1';
const SPEICHER = `container-finder-${FASSUNG}`;
const KACHELN = 'container-finder-kacheln';
const KACHEL_MAX = 800;
const KACHEL_ALTER_MS = 30 * 24 * 3600 * 1000;

const DATEIEN = [
  './',
  './index.html',
  './manifest.webmanifest',
  './css/app.css',
  './js/app.js',
  './js/daten.js',
  './js/geo.js',
  './js/osm.js',
  './js/speicher.js',
  './vendor/leaflet/leaflet.js',
  './vendor/leaflet/leaflet.css',
  './daten/bochum.json',
  './daten/dortmund.json',
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
        .filter((n) => n !== SPEICHER && n !== KACHELN)
        .map((n) => caches.delete(n))))
      .then(() => self.clients.claim())
  );
});

let kachelnSeitAufraeumen = 0;
async function kachelnAufraeumen() {
  const speicher = await caches.open(KACHELN);
  const schluessel = await speicher.keys();
  // keys() liefert in Einfügereihenfolge — vorne stehen die ältesten.
  const zuviel = schluessel.length - KACHEL_MAX;
  for (let i = 0; i < zuviel; i += 1) await speicher.delete(schluessel[i]);
}

async function kachel(anfrage) {
  const speicher = await caches.open(KACHELN);
  const gemerkt = await speicher.match(anfrage);
  if (gemerkt) {
    const zeit = Number(gemerkt.headers.get('X-Gemerkt') || 0);
    if (Date.now() - zeit < KACHEL_ALTER_MS) return gemerkt;
  }
  try {
    const antwort = await fetch(anfrage);
    if (antwort.ok && antwort.type === 'cors') {
      const koerper = await antwort.clone().blob();
      const kopf = new Headers(antwort.headers);
      kopf.set('X-Gemerkt', String(Date.now()));
      await speicher.delete(anfrage); // neu einfügen = ans Ende der Reihe
      await speicher.put(anfrage, new Response(koerper, { status: 200, headers: kopf }));
      kachelnSeitAufraeumen += 1;
      if (kachelnSeitAufraeumen >= 50) { kachelnSeitAufraeumen = 0; kachelnAufraeumen(); }
    }
    return antwort;
  } catch (fehler) {
    if (gemerkt) return gemerkt; // lieber alt als gar nicht
    throw fehler;
  }
}

self.addEventListener('fetch', (ereignis) => {
  const anfrage = ereignis.request;
  if (anfrage.method !== 'GET') return;
  const adresse = new URL(anfrage.url);

  if (adresse.hostname === 'tile.openstreetmap.org') {
    ereignis.respondWith(kachel(anfrage));
    return;
  }
  if (adresse.origin !== self.location.origin) return;

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
