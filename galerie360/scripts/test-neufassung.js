/*
 * Neue Fassung erreicht die installierte App (Playwright + Chromium).
 *
 *   node scripts/test-neufassung.js
 *
 * Anlass (10/2026): Am iPad zeigte die App vom Home-Bildschirm Stunden nach
 * dem Hochladen noch eine alte Fassung. Der Testserver schickt absichtlich
 * „Cache-Control: max-age=86400" (schlimmer als jerosch.net, das gar nichts
 * schickt) und ändert bei jeder „Fassung" sw.js und js/app.js. Geprüft wird:
 * Der neue Service Worker holt am Browser-Zwischenspeicher vorbei die NEUE
 * app.js, bei offener Galerie erscheint „Jetzt neu laden", auf der Startseite
 * lädt die App von selbst neu.
 */
const { chromium } = require('playwright');
const http = require('http');
const fs = require('fs');
const path = require('path');

const WURZEL = path.resolve(__dirname, '..');
const TYPEN = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.css': 'text/css', '.json': 'application/json', '.png': 'image/png', '.svg': 'image/svg+xml', '.webmanifest': 'application/manifest+json' };
let generation = 1;

let fehler = 0;
const pruefe = (b, t) => { if (!b) fehler++; console.log((b ? '  ok      ' : '  FEHLER  ') + t); };

(async () => {
  const srv = http.createServer((q, r) => {
    let p = decodeURIComponent(q.url.split('?')[0]);
    if (p.endsWith('/')) p += 'index.html';
    const f = path.join(WURZEL, p);
    if (!f.startsWith(WURZEL) || !fs.existsSync(f) || fs.statSync(f).isDirectory()) { r.writeHead(404); return r.end(); }
    let inhalt = fs.readFileSync(f);
    if (p === '/sw.js') inhalt = inhalt.toString().replace(/const FASSUNG = '[^']*'/, `const FASSUNG = 'test${generation}'`);
    if (p === '/js/app.js') inhalt = inhalt.toString() + `\nwindow.__generation = ${generation};\n`;
    // sw.js prüft der Browser ohnehin am Zwischenspeicher vorbei; alles andere soll „lange frisch" sein.
    r.writeHead(200, { 'Content-Type': TYPEN[path.extname(f)] || 'application/octet-stream', 'Cache-Control': p === '/sw.js' ? 'no-cache' : 'max-age=86400' });
    r.end(inhalt);
  });
  await new Promise((ok) => srv.listen(0, '127.0.0.1', ok));
  const url = `http://127.0.0.1:${srv.address().port}/`;
  const b = await chromium.launch();
  const c = await b.newContext({ viewport: { width: 1280, height: 900 } });
  const s = await c.newPage();
  await s.addInitScript(() => { delete window.showDirectoryPicker; delete window.showSaveFilePicker; });
  await s.goto(url);
  await s.waitForFunction(() => navigator.serviceWorker.controller, null, { timeout: 20000 });
  pruefe(await s.evaluate(() => window.__generation) === 1, 'Fassung 1 läuft, Service Worker hat die Seite übernommen');
  pruefe(await s.isHidden('#neufassung'), 'Erste Installation: kein Hinweis');

  // Galerie offen, dann erscheint Fassung 2
  await s.click('#k-neu');
  await s.fill('#frage-eingabe', 'Test');
  await s.click('#frage-ja');
  await s.waitForSelector('#dlg-frage[open]');
  await s.click('#frage-nein');
  await s.waitForSelector('#editor:not([hidden])');
  generation = 2;
  // Wie die App beim Zurückkehren (visibilitychange): nach einer neuen Fassung fragen
  await s.evaluate(() => navigator.serviceWorker.getRegistration().then((r) => r.update()));
  await s.waitForSelector('#neufassung:not([hidden])', { timeout: 30000 });
  pruefe(true, 'Offene Galerie: „Eine neue Fassung … Jetzt neu laden" erscheint');
  const imSpeicher = await s.evaluate(async () => {
    const c = await caches.open('galerie360-test2');
    const r = await c.match('js/app.js', { ignoreSearch: true });
    return r ? (await r.text()).includes('window.__generation = 2') : false;
  });
  pruefe(imSpeicher, 'Neuer Service Worker hat die NEUE app.js geholt — trotz „max-age=86400" am Browser-Zwischenspeicher vorbei');
  await Promise.all([s.waitForEvent('load'), s.click('#k-neu-laden')]);
  await s.waitForFunction(() => window.__generation, null, { timeout: 20000 });
  pruefe(await s.evaluate(() => window.__generation) === 2, '„Jetzt neu laden" startet Fassung 2');

  // Auf der Startseite: von selbst neu laden
  generation = 3;
  const neuGeladen = s.waitForEvent('load', { timeout: 30000 });
  await s.evaluate(() => navigator.serviceWorker.getRegistration().then((r) => r.update()));
  await neuGeladen;
  await s.waitForFunction(() => window.__generation, null, { timeout: 20000 });
  pruefe(await s.evaluate(() => window.__generation) === 3, 'Startseite lädt bei neuer Fassung von selbst neu (Fassung 3)');

  await b.close();
  srv.close();
  console.log(fehler ? fehler + ' Fehler.' : 'Alles bestanden.');
  process.exit(fehler ? 1 : 0);
})().catch((e) => { console.error(e); process.exit(1); });
