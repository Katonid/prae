// Prüft die Dateiliste des Service Workers gegen die Wirklichkeit.
//
//   node woerterwerkstatt/scripts/dateien-pruefen.mjs
//
// Warum das eine eigene Prüfung braucht: `caches.addAll()` ist ALLES ODER
// NICHTS. Steht in der Liste eine Datei, die es nicht gibt, scheitert der
// ganze Aufruf — und `sw.js` fängt das ab (`.catch(() => self.skipWaiting())`),
// damit eine kaputte Liste die App nicht am Starten hindert. Die Folge: Online
// läuft alles weiter, und niemand merkt, dass der Zwischenspeicher LEER ist.
// Auffallen würde es erst ohne Netz, im Zug oder in der Turnhalle.
//
// Andersherum genauso still: Eine Datei, die referenziert wird, aber NICHT in
// der Liste steht, wird online nachgeladen und fehlt offline einfach. Genau so
// fehlten bis 1.8.5 drei der acht Schriftschnitte — die „-ext"-Dateien mit
// Latein Erweitert. Online unsichtbar; ohne Netz stand der Name eines Kindes
// (Łukasz, Şeyma, Jabłońska) plötzlich in einer fremden Schrift.
//
// Drei Prüfungen:
// 1. FEHLT AUF DER PLATTE — steht in der Liste, gibt es aber nicht. Bricht ab.
// 2. NICHT IM SPEICHER — wird von HTML/CSS/Manifest gebraucht, steht aber
//    nicht in der Liste. Bricht ab.
// 3. VERWAIST — liegt im Ordner, wird nirgends gebraucht. Nur ein Hinweis.

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const WURZEL = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const lies = (datei) => fs.readFileSync(path.join(WURZEL, datei), 'utf8');

/* ---------- Was der Service Worker mitnimmt ---------- */

const swText = lies('sw.js');
const liste = /const DATEIEN = \[([\s\S]*?)\n\];/.exec(swText);
if (!liste) {
  console.log('sw.js: die Liste DATEIEN ist nicht zu finden — hat sie jemand umbenannt?');
  process.exit(1);
}
const imSpeicher = new Set(
  [...liste[1].matchAll(/'\.\/([^']*)'/g)].map((treffer) => treffer[1]).filter(Boolean),
);
// './' ist der Ordner selbst, nicht eine Datei.
imSpeicher.delete('');

/* ---------- Was die App wirklich braucht ---------- */

const gebraucht = new Set(['index.html', 'manifest.webmanifest']);

// Aus dem index.html: Stilvorlagen, Symbole, das Manifest, Module.
for (const treffer of lies('index.html').matchAll(/(?:href|src)="\.\/([^"]+)"/g)) {
  gebraucht.add(treffer[1]);
}
// Das Startmodul und alles, was es nach sich zieht, steht in den Modulen
// selbst — die prüft module-pruefen.mjs. Hier reicht: Jede .js unter js/
// gehört in den Speicher, sonst fehlt sie offline.
const jsDateien = (ordner) => fs.readdirSync(path.join(WURZEL, ordner), { withFileTypes: true })
  .flatMap((eintrag) => (eintrag.isDirectory()
    ? jsDateien(path.join(ordner, eintrag.name))
    : (eintrag.name.endsWith('.js') ? [path.join(ordner, eintrag.name)] : [])));
for (const datei of jsDateien('js')) gebraucht.add(datei.split(path.sep).join('/'));

// Aus den Stilvorlagen: Schriften. Die Pfade dort sind relativ zu css/.
for (const stil of ['css/app.css', 'css/fonts.css']) {
  gebraucht.add(stil);
  for (const treffer of lies(stil).matchAll(/url\('\.\.\/([^']+)'\)/g)) gebraucht.add(treffer[1]);
}

// Aus dem Manifest: Symbole.
for (const treffer of lies('manifest.webmanifest').matchAll(/"\.\/([^"]+\.(?:png|svg))"/g)) {
  gebraucht.add(treffer[1]);
}

/* ---------- Was im Ordner liegt ---------- */

// Werkzeug, Doku und die Datenbankregeln gehören nicht auf den Webspace.
const NICHT_FUERS_NETZ = /^scripts\/|\.md$|^firebase-rules\.json$|^sw\.js$/;
const alleDateien = (ordner = '') => fs.readdirSync(path.join(WURZEL, ordner), { withFileTypes: true })
  .flatMap((eintrag) => {
    const pfad = ordner ? `${ordner}/${eintrag.name}` : eintrag.name;
    return eintrag.isDirectory() ? alleDateien(pfad) : [pfad];
  });
const aufDerPlatte = new Set(alleDateien().filter((datei) => !NICHT_FUERS_NETZ.test(datei)));

/* ---------- Die drei Prüfungen ---------- */

let schwer = 0;

for (const datei of [...imSpeicher].sort()) {
  if (!fs.existsSync(path.join(WURZEL, datei))) {
    console.log('FEHLT AUF DER PLATTE:', datei, '— addAll() scheitert, der Speicher bleibt LEER');
    schwer += 1;
  }
}

for (const datei of [...gebraucht].sort()) {
  if (!imSpeicher.has(datei)) {
    console.log('NICHT IM SPEICHER:', datei, '— wird gebraucht, fehlt aber ohne Netz');
    schwer += 1;
  }
}

let verwaist = 0;
for (const datei of [...aufDerPlatte].sort()) {
  if (!gebraucht.has(datei) && !imSpeicher.has(datei)) {
    console.log('VERWAIST:', datei, '— liegt da, wird nirgends gebraucht');
    verwaist += 1;
  }
}

console.log(schwer
  ? `\n${schwer} Problem(e) — die App wäre ohne Netz nicht vollständig`
  : `\nDer Service Worker nimmt alles mit, was gebraucht wird (${imSpeicher.size} Dateien)`);
console.log(verwaist ? `${verwaist} verwaiste Datei(en)` : 'keine verwaisten Dateien');
process.exit(schwer ? 1 : 0);
