/*
 * Ende-zu-Ende-Test für Galerie 360 (Playwright + Chromium).
 *
 *   node scripts/test-e2e.js <ordner-mit-testmedien> <ausgabeordner> [modus]
 *
 * modus: „ordner" (Vorgabe, wie Chrome/Edge), „einzeldatei" (dasselbe mit
 * galerie360-generator.html) oder „browser" (wie Firefox/Safari: kein
 * Ordnerzugriff, Galerie im Browser-Speicher, ZIP als Download) oder
 * „safari" (wie „browser", zusätzlich ohne createWritable — so wie Safari
 * auf iPad/iPhone: geschrieben wird über den Worker mit SyncAccessHandle).
 * Am Ende wird das ZIP in einem frischen Browser wieder als Galerie übernommen.
 *
 * Der Ordnerdialog lässt sich nicht fernsteuern; er wird durch den privaten
 * Browser-Speicher (OPFS) ersetzt — dieselbe Schnittstelle
 * (FileSystemDirectoryHandle), derselbe Code im Generator.
 * Ablauf: Galerie anlegen → importieren → Blick festlegen → Vorschau →
 * fertigstellen → ZIP → ZIP entpacken → über HTTP ausliefern → Galerie
 * und Betrachter bedienen.
 */
const { chromium } = require('playwright');
const http = require('http');
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const WURZEL = path.resolve(__dirname, '..');
const [medien, aus] = process.argv.slice(2, 4).map((p) => path.resolve(p));
const MODUS = process.argv[4] || 'ordner';
const BROWSERMODUS = MODUS === 'browser' || MODUS === 'safari';
fs.mkdirSync(aus, { recursive: true });

const TYPEN = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.css': 'text/css', '.json': 'application/json', '.jpg': 'image/jpeg', '.svg': 'image/svg+xml', '.mp4': 'video/mp4', '.webm': 'video/webm' };

/** Kleiner Webserver mit Range-Anfragen (wie Apache/nginx) — Safari und Chrome brauchen sie für Videos. */
function server(ordner) {
  return new Promise((ok) => {
    const s = http.createServer((req, res) => {
      let p = decodeURIComponent(new URL(req.url, 'http://x').pathname);
      if (p.endsWith('/')) p += 'index.html';
      const datei = path.join(ordner, p);
      if (!datei.startsWith(ordner) || !fs.existsSync(datei) || fs.statSync(datei).isDirectory()) { res.writeHead(404); return res.end(); }
      const groesse = fs.statSync(datei).size;
      const typ = TYPEN[path.extname(datei)] || 'application/octet-stream';
      const r = /bytes=(\d*)-(\d*)/.exec(req.headers.range || '');
      if (r) {
        const a = r[1] ? +r[1] : 0, b = r[2] ? +r[2] : groesse - 1;
        res.writeHead(206, { 'Content-Type': typ, 'Content-Range': `bytes ${a}-${b}/${groesse}`, 'Content-Length': b - a + 1, 'Accept-Ranges': 'bytes' });
        fs.createReadStream(datei, { start: a, end: b }).pipe(res);
      } else {
        res.writeHead(200, { 'Content-Type': typ, 'Content-Length': groesse, 'Accept-Ranges': 'bytes' });
        fs.createReadStream(datei).pipe(res);
      }
    });
    s.listen(0, '127.0.0.1', () => ok(s));
  });
}

const pruefe = (bedingung, text) => {
  if (!bedingung) throw new Error('FEHLGESCHLAGEN: ' + text);
  console.log('  ok  ' + text);
};

(async () => {
  const gen = await server(WURZEL);
  const genUrl = `http://127.0.0.1:${gen.address().port}/`;
  const browser = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader', '--autoplay-policy=no-user-gesture-required'] });
  const ctx = await browser.newContext({ viewport: { width: 1400, height: 900 } });
  const seite = await ctx.newPage();
  const fehler = [];
  seite.on('pageerror', (e) => fehler.push(e.message));
  seite.on('console', (m) => { if (m.type() === 'error') fehler.push(m.text()); });
  seite._initSkript = (modus) => {
    if (modus === 'browser' || modus === 'safari') {
      delete window.showDirectoryPicker;
      delete window.showSaveFilePicker;
      if (modus === 'safari' && self.FileSystemFileHandle) delete FileSystemFileHandle.prototype.createWritable;
      return;
    }
    window.showDirectoryPicker = async () => {
      const w = await navigator.storage.getDirectory();
      return w.getDirectoryHandle('testprojekte', { create: true });
    };
    window.showSaveFilePicker = async () => {
      const w = await navigator.storage.getDirectory();
      return w.getFileHandle('export.zip', { create: true });
    };
  };
  await seite.addInitScript(seite._initSkript, MODUS);
  console.log('Generator');
  await seite.goto(genUrl + (MODUS === 'einzeldatei' ? 'galerie360-generator.html' : ''));
  await seite.evaluate(async () => {
    const w = await navigator.storage.getDirectory();
    for await (const n of w.keys()) await w.removeEntry(n, { recursive: true });
  });
  await seite.click('#k-neu');
  await seite.fill('#frage-eingabe', 'Sommer in Norwegen');
  await seite.click('#frage-ja');
  if (!BROWSERMODUS) await seite.click('#frage-ja'); // Hinweis „Ordner wählen"
  await seite.waitForSelector('#editor:not([hidden])');
  // Rückfrage „Mit Passwort schützen?" — hier ohne; den Passwort-Weg prüft test-schutz.js.
  await seite.waitForSelector('#dlg-frage[open]');
  await seite.click('#frage-nein');
  const ORDNER = BROWSERMODUS ? ['galerien', 'sommer-in-norwegen'] : ['testprojekte'];
  pruefe(await seite.textContent('#projektname') === (BROWSERMODUS ? 'Browser-Speicher › sommer-in-norwegen' : 'Ordner › testprojekte'), 'Projekt angelegt: ' + await seite.textContent('#projektname'));
  await seite.screenshot({ path: path.join(aus, '1-editor-leer.png') });

  await seite.fill('#g-beschreibung', 'Fjorde, Berge und Mitternachtssonne.');
  await seite.fill('#a-titel', 'Lofoten');
  const dateien = fs.readdirSync(medien).filter((n) => /\.(jpg|mp4|webm)$/.test(n)).sort().map((n) => path.join(medien, n));
  await seite.setInputFiles('#dateiwahl', dateien);
  await seite.waitForFunction((n) => document.querySelectorAll('#medienliste .medium').length === n && !document.querySelector('#warteschlange li'), dateien.length, { timeout: 120000 });
  pruefe(true, dateien.length + ' Dateien importiert');
  await seite.fill('.medium:nth-child(1) .m-titel', 'Reine am Morgen');
  await seite.fill('.medium:nth-child(1) .m-beschreibung', 'Blick über den Hafen.\nZweite Zeile.');
  await seite.evaluate(() => window.G360.app.sofortSpeichern());

  const projekt = await seite.evaluate(async (ordner) => {
    let w = await navigator.storage.getDirectory();
    for (const o of ordner) w = await w.getDirectoryHandle(o);
    return JSON.parse(await (await (await w.getFileHandle('gallery.json')).getFile()).text());
  }, ORDNER);
  const m = projekt.alben[0].medien;
  const gross = m.find((x) => x.original === 'foto-gross.jpg');
  pruefe(gross && gross.bilder.map((b) => b.breite).join(',') === '4096,8192,9000', 'Großes Foto: Fassungen 4096, 8192 und Original');
  const video = m.find((x) => x.typ === 'video');
  pruefe(video && video.quellen[0].codec.startsWith('avc1.64') && video.quellen[0].breite === 1920, 'Video: H.264-Kennung und Breite gelesen (' + (video && video.quellen[0].codec) + ')');
  pruefe(video && video.poster && video.dauer > 5, 'Video: Standbild und Dauer');
  pruefe(m[0].titel === 'Reine am Morgen' && projekt.alben[0].titel === 'Lofoten', 'Titel gespeichert');
  await seite.screenshot({ path: path.join(aus, '2-editor-medien.png'), fullPage: true });

  // Reihenfolge per Knopf
  const vorher = await seite.$$eval('.medium', (l) => l.map((x) => x.dataset.id));
  await seite.click('.medium:nth-child(1) .mreihe button:nth-child(2)');
  const nachher = await seite.$$eval('.medium', (l) => l.map((x) => x.dataset.id));
  pruefe(nachher[0] === vorher[1] && nachher[1] === vorher[0], 'Reihenfolge geändert');

  // Blick festlegen
  await seite.click('.medium:nth-child(1) .mbild');
  await seite.waitForSelector('#dlg-blick[open]');
  const lw = await seite.$('#blick-leinwand');
  const box = await lw.boundingBox();
  await seite.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
  await seite.mouse.down();
  await seite.mouse.move(box.x + box.width / 2 - 200, box.y + box.height / 2 + 60, { steps: 8 });
  await seite.mouse.up();
  await seite.waitForTimeout(300);
  await seite.screenshot({ path: path.join(aus, '3-blick.png') });
  await seite.click('#k-blick-ok');
  await seite.waitForFunction(() => !document.querySelector('#dlg-blick[open]'));
  await seite.waitForTimeout(400);
  const blick = await seite.evaluate(() => window.G360.app.S.projekt.alben[0].medien[0].blick);
  pruefe(blick.yaw > 10 && blick.pitch > 0, 'Blick übernommen (yaw ' + blick.yaw + ', pitch ' + blick.pitch + ')');

  // zweites Album, Datei dorthin verschieben
  await seite.click('#k-album-neu');
  await seite.fill('#a-titel', 'Bergen');
  await seite.click('.album:nth-child(1) .album-wahl');
  await seite.selectOption('.medium:nth-child(2) select', { label: 'Bergen' });
  pruefe(await seite.$$eval('.medium', (l) => l.length) === dateien.length - 1, 'Aufnahme in anderes Album verschoben');

  // Vorschau
  await seite.click('#k-vorschau');
  await seite.waitForSelector('#vorschau .g-albumkarte');
  pruefe(await seite.$$eval('#vorschau .g-albumkarte', (l) => l.length) === 2, 'Vorschau zeigt zwei Alben');
  await seite.waitForTimeout(500);
  await seite.screenshot({ path: path.join(aus, '4-vorschau.png') });
  await seite.click('#vorschau .g-albumkarte');
  await seite.click('#vorschau .g-kachel');
  await seite.waitForSelector('#vorschau .g-viewer.g-offen');
  await seite.waitForFunction(() => document.querySelector('#vorschau .g-laden').hidden, null, { timeout: 30000 });
  await seite.screenshot({ path: path.join(aus, '5-vorschau-betrachter.png') });
  await seite.keyboard.press('Escape');
  await seite.click('#k-vorschau-zu');

  // Fertigstellen und ZIP
  await seite.click('#k-fertig');
  await seite.waitForSelector('#fertig-inhalt h2.gut', { timeout: 30000 });
  pruefe(true, 'Website fertiggestellt: ' + await seite.textContent('#fertig-inhalt h2'));
  await seite.screenshot({ path: path.join(aus, '6-fertig.png') });
  const zipPfad = path.join(aus, 'galerie.zip');
  if (BROWSERMODUS) {
    const [download] = await Promise.all([seite.waitForEvent('download', { timeout: 60000 }), seite.click('#fertig-inhalt button:has-text("ZIP")')]);
    await download.saveAs(zipPfad);
    await seite.waitForSelector('.zipbereich p.gut', { timeout: 60000 });
  } else {
    await seite.click('#fertig-inhalt button:has-text("ZIP")');
    await seite.waitForSelector('.zipbereich p.gut', { timeout: 60000 });
    const zip = await seite.evaluate(async () => {
      const f = await (await (await navigator.storage.getDirectory()).getFileHandle('export.zip')).getFile();
      const b = new Uint8Array(await f.arrayBuffer());
      let s = '';
      for (let i = 0; i < b.length; i += 0x8000) s += String.fromCharCode.apply(null, b.subarray(i, i + 0x8000));
      return btoa(s);
    });
    fs.writeFileSync(zipPfad, Buffer.from(zip, 'base64'));
  }
  const entpackt = path.join(aus, 'webspace');
  fs.rmSync(entpackt, { recursive: true, force: true });
  execFileSync('python3', ['-c', 'import zipfile,sys; z=zipfile.ZipFile(sys.argv[1]); assert z.testzip() is None, "CRC"; z.extractall(sys.argv[2]); print(len(z.namelist()))', zipPfad, entpackt], { stdio: 'inherit' });
  pruefe(true, 'ZIP ist gültig (Prüfsummen stimmen) und entpackt');

  // Rückweg: das ZIP in einem frischen Browser (leerer Speicher) wieder übernehmen.
  {
    const c = await browser.newContext({ viewport: { width: 1280, height: 900 } });
    const s = await c.newPage();
    s.on('pageerror', (e) => fehler.push('zip: ' + e.message));
    await s.addInitScript(seite._initSkript, MODUS);
    await s.goto(genUrl + (MODUS === 'einzeldatei' ? 'galerie360-generator.html' : ''));
    await s.click('#k-zip');
    await s.setInputFiles('#dateiwahl-einzeln', zipPfad);
    await s.waitForSelector('#editor:not([hidden])', { timeout: 60000 });
    const p2 = await s.evaluate(() => window.G360.app.S.projekt);
    pruefe(p2.alben.length === 2 && p2.alben[0].medien.length + p2.alben[1].medien.length === dateien.length, 'ZIP wieder als Galerie übernommen (' + await s.textContent('#projektname') + ')');
    await s.click('#k-vorschau');
    await s.click('#vorschau .g-albumkarte');
    await s.click('#vorschau .g-kachel');
    await s.waitForFunction(() => document.querySelector('#vorschau .g-laden').hidden, null, { timeout: 30000 });
    pruefe(true, 'übernommene Galerie lässt sich ansehen');
    await c.close();
  }

  // Zweiter Schritt: Website „hochladen" (in ein Unterverzeichnis) und ansehen.
  console.log('Veröffentlichte Galerie');
  const web = await server(entpackt);
  const webUrl = `http://127.0.0.1:${web.address().port}/sommer-in-norwegen/`;
  for (const [name, vp] of [['desktop', { width: 1280, height: 800 }], ['handy', { width: 390, height: 844 }]]) {
    const c = await browser.newContext({ viewport: vp, deviceScaleFactor: name === 'handy' ? 3 : 1, isMobile: name === 'handy', hasTouch: name === 'handy' });
    const s = await c.newPage();
    s.on('pageerror', (e) => fehler.push(name + ': ' + e.message));
    s.on('console', (msg) => { if (msg.type() === 'error') fehler.push(name + ': ' + msg.text()); });
    const anfragen = [];
    s.on('request', (r) => anfragen.push(r.url()));
    await s.goto(webUrl);
    await s.waitForSelector('.g-albumkarte');
    await s.waitForTimeout(400);
    pruefe(anfragen.every((u) => u.startsWith(webUrl) || u.startsWith('data:')), name + ': keine Anfrage außerhalb des Galerieordners');
    pruefe(!anfragen.some((u) => /\.mp4/.test(u)), name + ': kein Video vorab geladen');
    await s.screenshot({ path: path.join(aus, `7-${name}-start.png`) });
    await s.click('.g-albumkarte');
    await s.waitForSelector('.g-kachel');
    await s.waitForTimeout(400);
    await s.screenshot({ path: path.join(aus, `8-${name}-album.png`), fullPage: true });
    await s.click('.g-kachel');
    await s.waitForSelector('.g-viewer.g-offen');
    await s.waitForFunction(() => document.querySelector('.g-laden').hidden, null, { timeout: 30000 });
    await s.waitForTimeout(300);
    // Bildschirmfoto auswerten: WebGL-Flächen lassen sich nach dem Anzeigen nicht mehr auslesen.
    const foto = path.join(aus, `9-${name}-foto.png`);
    await s.screenshot({ path: foto });
    const hell = +execFileSync('python3', ['-c', 'import sys; from PIL import Image, ImageStat; print(sum(ImageStat.Stat(Image.open(sys.argv[1]).convert("RGB")).mean) / 3)', foto]).toString();
    pruefe(hell > 40, name + ': 360°-Foto wird gezeichnet (Helligkeit ' + hell.toFixed(0) + ')');
    pruefe(/#a\/.+\/.+/.test(s.url()), name + ': Adresse verweist direkt auf die Aufnahme');
    // Blättern bis zum Video (Album 1 enthält 2 Fotos + evtl. Video)
    const n = await s.$$eval('.g-kachel', (l) => l.length);
    let istVideo = false;
    for (let i = 0; i < n && !istVideo; i++) {
      istVideo = await s.evaluate(() => document.querySelector('.g-viewer').classList.contains('g-istvideo'));
      if (!istVideo) await s.click('.g-pfeil-rechts');
      await s.waitForTimeout(200);
    }
    if (istVideo) {
      await s.waitForSelector('.g-startknopf:not([hidden])');
      await s.screenshot({ path: path.join(aus, `10-${name}-video-start.png`) });
      await s.click('.g-startknopf');
      await s.waitForFunction(() => { const v = document.querySelector('.g-videoquelle'); return v.currentTime > 1; }, null, { timeout: 20000 });
      pruefe(true, name + ': Video spielt');
      await s.waitForTimeout(300);
      await s.screenshot({ path: path.join(aus, `11-${name}-video.png`) });
      await s.click('.g-steuer .g-knopf'); // Pause
      pruefe(await s.evaluate(() => document.querySelector('.g-videoquelle').paused), name + ': Pause');
    }
    await s.click('.g-oben .g-knopf');
    await s.waitForFunction(() => !document.querySelector('.g-viewer.g-offen'));
    pruefe(await s.evaluate(() => !document.querySelector('.g-videoquelle').getAttribute('src')), name + ': Video nach dem Schließen freigegeben');
    await c.close();
  }

  // Helles Design
  const c = await browser.newContext({ viewport: { width: 1280, height: 800 }, colorScheme: 'light' });
  const s = await c.newPage();
  await s.goto(webUrl);
  await s.click('.g-themaknopf');
  await s.waitForTimeout(200);
  await s.screenshot({ path: path.join(aus, '12-hell.png') });
  await c.close();

  await browser.close();
  gen.close();
  web.close();
  if (fehler.length) {
    console.log('Fehler in der Konsole:\n  ' + fehler.join('\n  '));
    process.exit(1);
  }
  console.log('Alles bestanden.');
})().catch((e) => { console.error(e); process.exit(1); });
