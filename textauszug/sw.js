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

const FASSUNG = 'v6';
const SPEICHER = `textauszug-${FASSUNG}`;

const DATEIEN = [
  './',
  './index.html',
  './manifest.webmanifest',
  './css/style.css',
  './js/app.js',
  './js/auszug.js',
  './js/epub.js',
  './js/pdf.js',
  './js/inflate.js',
  './js/schrift.js',
  './js/inhalt.js',
  './js/aufbereiten.js',
  './js/schriftmasse.js',
  './js/winansi.js',
  './js/pdfbauen.js',
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
        .filter((n) => n !== SPEICHER && n !== GETEILT)
        .map((n) => caches.delete(n))))
      .then(() => self.clients.claim())
  );
});

// Der Eintrag im Teilen-Blatt (Android; Apple unterstützt das nicht).
// Das Betriebssystem schickt die Datei als POST hierher — eine Seite kann so
// etwas nicht entgegennehmen, der Service Worker schon. Er legt die Datei in
// einen eigenen Zwischenspeicher und schickt den Browser auf die Startseite,
// die sie dort abholt. Ohne die Umleitung stünde der Nutzer vor einer
// Antwortseite, die es gar nicht gibt.
const GETEILT = 'textauszug-geteilt';
const GETEILT_URL = './geteilte-datei';

self.addEventListener('fetch', (ereignis) => {
  const anfrage = ereignis.request;
  const adresse = new URL(anfrage.url);

  if (anfrage.method === 'POST' && adresse.pathname.endsWith('/teilen')) {
    ereignis.respondWith((async () => {
      try {
        const formular = await anfrage.formData();
        const datei = formular.get('datei');
        if (datei && datei.size) {
          const speicher = await caches.open(GETEILT);
          await speicher.put(GETEILT_URL, new Response(datei, {
            headers: {
              'Content-Type': datei.type || 'application/pdf',
              'X-Dateiname': encodeURIComponent(datei.name || 'geteilt.pdf'),
            },
          }));
          return Response.redirect('./?geteilt=1', 303);
        }
      } catch (fehler) {
        // Unten geht es ohne Datei weiter — die Seite sagt dann, was fehlt.
      }
      return Response.redirect('./?geteilt=leer', 303);
    })());
    return;
  }

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
