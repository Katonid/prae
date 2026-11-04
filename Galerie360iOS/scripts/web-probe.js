#!/usr/bin/env node
/*
 * Öffnet die Beispiel-Galerie, die `WebFormatTests.testProbeGalerieSchreiben` (iOS-App) erzeugt,
 * im Browser mit dem echten Betrachter (assets/galerie.js) — so wie ein Gast sie auf dem
 * Webspace sieht: Galerieseite → Albumkarte → Albumseite → Foto im 360°-Betrachter, dazu ein
 * Ordner mit Unteralbum. Aufruf: node web-probe.js <ordner-mit-probe.json>
 */
'use strict';
const http = require('http');
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const wurzel = path.resolve(process.argv[2] || '.');
const probe = JSON.parse(fs.readFileSync(path.join(wurzel, 'probe.json'), 'utf8'));
let fehler = 0;
const pruefe = (ok, text) => { console.log((ok ? '  ✓ ' : '  ✗ ') + text); if (!ok) fehler++; };

const typen = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.css': 'text/css', '.jpg': 'image/jpeg', '.json': 'application/json' };
const server = http.createServer((a, b) => {
  let p = decodeURIComponent(new URL(a.url, 'http://x').pathname);
  if (p.endsWith('/')) p += 'index.html';
  const datei = path.join(wurzel, '360Grad', path.normalize(p).replace(/^\/360Grad\//, ''));
  if (!datei.startsWith(path.join(wurzel, '360Grad')) || !fs.existsSync(datei)) { b.writeHead(404); b.end(); return; }
  b.writeHead(200, { 'Content-Type': typen[path.extname(datei)] || 'application/octet-stream' });
  fs.createReadStream(datei).pipe(b);
});

(async () => {
  // Der Webspace-Ordner „360Grad" enthält die Galerie- und Albumordner.
  fs.mkdirSync(path.join(wurzel, '360Grad'), { recursive: true });
  for (const e of fs.readdirSync(wurzel)) {
    if (e !== '360Grad' && e !== 'probe.json') fs.renameSync(path.join(wurzel, e), path.join(wurzel, '360Grad', e));
  }
  await new Promise((ok) => server.listen(0, '127.0.0.1', ok));
  const basis = `http://127.0.0.1:${server.address().port}/360Grad/`;
  const browser = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-webgl', '--ignore-gpu-blocklist'] });
  const konsole = [];
  for (const [name, viewport] of [['Rechner', { width: 1280, height: 800 }], ['Handy', { width: 390, height: 844 }]]) {
    console.log(name);
    const c = await browser.newContext({ viewport, isMobile: name === 'Handy', hasTouch: name === 'Handy' });
    const b = await c.newPage();
    b.on('pageerror', (e) => konsole.push(name + ': ' + e.message));
    await b.goto(basis + probe.galerie + '/');
    await b.waitForSelector('.g-albumkarte', { timeout: 15000 });
    const karten = await b.$$eval('.g-albumkarte', (l) => l.map((a) => a.getAttribute('href')));
    pruefe(karten.join() === probe.alben.map((o) => '../' + o + '/').join(), 'Galerieseite: Karten aller Alben in Reihenfolge');
    await b.waitForFunction(() => [...document.querySelectorAll('.g-albumkarte img')].every((i) => i.complete && i.naturalWidth > 0), null, { timeout: 15000 });
    pruefe(true, 'Vorschaubilder der Karten laden (auch das aus dem Unteralbum)');
    pruefe(!/Galerie wird geladen/.test(await b.textContent('body')), 'Betrachter ist gestartet');

    await b.click('.g-albumkarte');
    await b.waitForSelector('.g-kachel', { timeout: 15000 });
    pruefe(b.url() === basis + probe.alben[0] + '/', 'Karte öffnet die Albumseite');
    pruefe(await b.isVisible('.g-zurueck'), 'Albumseite führt zurück zur Galerie (über die Herkunft)');
    await b.click('.g-kachel');
    await b.waitForFunction(() => document.querySelector('.g-laden') && document.querySelector('.g-laden').hidden, null, { timeout: 20000 });
    pruefe(await b.evaluate(() => document.querySelector('.g-meldung').hidden), 'Foto lädt im 360°-Betrachter');
    const titel = await b.evaluate(() => document.body.textContent);
    pruefe(titel.includes('Blick </script><b>'), 'Titel mit Sonderzeichen erscheint als Text');
    pruefe(!(await b.$('b')), 'kein eingeschleustes HTML');

    await b.goto(basis + probe.alben[1] + '/');
    await b.waitForSelector('.g-albumkarte', { timeout: 15000 });
    const unter = await b.$$eval('.g-albumkarte', (l) => l.map((a) => a.getAttribute('href')));
    pruefe(unter.join() === '../' + probe.unteralbum + '/', 'Ordner zeigt sein Unteralbum als Karte');
    await c.close();
  }
  await browser.close();
  server.close();
  pruefe(konsole.length === 0, 'keine Skriptfehler' + (konsole.length ? ': ' + konsole.join(' | ') : ''));
  console.log(fehler ? `${fehler} Prüfung(en) fehlgeschlagen` : 'Alles in Ordnung.');
  process.exit(fehler ? 1 : 0);
})().catch((e) => { console.error(e); process.exit(1); });
