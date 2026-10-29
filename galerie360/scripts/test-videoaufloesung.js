/*
 * Videoauflösung am iPad (10/2026: „Qualität schlechter als in der Insta360-App").
 *
 *   node scripts/test-videoaufloesung.js <ausgabe von test-e2e.js ordner> <arbeitsordner>
 *
 * Nimmt die Galerie aus dem e2e-Lauf, ersetzt das Video durch eines in 5760 × 2880
 * und protokolliert jede Textur. Am iPad muss das Video selbst (VIDEO:5760) hochgehen,
 * nicht eine auf 4096 verkleinerte Zeichenfläche (CANVAS:4096, so bis 1.0.7).
 */
const { execFileSync } = require('child_process');
const { chromium } = require('playwright');
const http = require('http'), fs = require('fs'), path = require('path');
const WURZEL = path.resolve(__dirname, '..');
const W = path.resolve(process.argv[3] || 'videoaufloesung');
fs.rmSync(W, { recursive: true, force: true });
fs.cpSync(path.join(path.resolve(process.argv[2]), 'webspace', fs.readdirSync(path.join(path.resolve(process.argv[2]), 'webspace')).find((n) => n.endsWith('-sicherung'))), W, { recursive: true });
for (const n of ['galerie.js', 'galerie.css']) fs.copyFileSync(path.join(WURZEL, 'galerie', n), path.join(W, 'assets', n));
const video = path.join(W, 'media', 'videos', fs.readdirSync(path.join(W, 'media', 'videos')).find((n) => n.endsWith('.mp4')));
execFileSync('ffmpeg', ['-loglevel', 'error', '-y', '-f', 'lavfi', '-i', 'testsrc2=size=5760x2880:rate=10', '-t', '2', '-c:v', 'libx264', '-pix_fmt', 'yuv420p', video]);
const idx = path.join(W, 'index.html');
fs.writeFileSync(idx, fs.readFileSync(idx, 'utf8').replace(/"breite":1920,"hoehe":960/g, '"breite":5760,"hoehe":2880'));
let fehler = 0;
(async () => {
  const srv = http.createServer((q, r) => { let p = decodeURIComponent(q.url.split('?')[0]); if (p.endsWith('/')) p += 'index.html'; const f = path.join(W, p); if (!fs.existsSync(f)) { r.writeHead(404); return r.end(); } const d = fs.readFileSync(f); const t = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.mp4': 'video/mp4', '.jpg': 'image/jpeg' }[path.extname(f)] || 'application/octet-stream'; const rg = q.headers.range && /bytes=(\d+)-(\d*)/.exec(q.headers.range); if (rg) { const a = +rg[1], e = rg[2] ? +rg[2] : d.length - 1; r.writeHead(206, { 'Content-Type': t, 'Content-Range': `bytes ${a}-${e}/${d.length}`, 'Accept-Ranges': 'bytes', 'Content-Length': e - a + 1 }); return r.end(d.slice(a, e + 1)); } r.writeHead(200, { 'Content-Type': t, 'Accept-Ranges': 'bytes' }); r.end(d); });
  await new Promise((ok) => srv.listen(0, '127.0.0.1', ok));
  const b = await chromium.launch();
  for (const ipad of [true, false]) {
    const c = await b.newContext({ viewport: { width: 1180, height: 820 }, hasTouch: ipad });
    const p = await c.newPage();
    await p.addInitScript((ipad) => {
      if (ipad) { Object.defineProperty(navigator, 'platform', { get: () => 'MacIntel' }); Object.defineProperty(navigator, 'maxTouchPoints', { get: () => 5 }); }
      window.__breiten = [];
      for (const n of ['texImage2D', 'texSubImage2D']) { const o = WebGLRenderingContext.prototype[n]; WebGLRenderingContext.prototype[n] = function (...a) { const q = a[a.length - 1]; if (q && (q.videoWidth || q.width) > 1) window.__breiten.push((q.tagName || '') + ':' + (q.videoWidth || q.width)); return o.apply(this, a); }; }
    }, ipad);
    await p.goto(`http://127.0.0.1:${srv.address().port}/`);
    await p.waitForSelector('.g-albumkarte');
    const karten = await p.$$('.g-albumkarte');
    let gefunden = false;
    for (let i = 0; i < karten.length && !gefunden; i++) {
      await p.goto(`http://127.0.0.1:${srv.address().port}/`);
      await p.waitForSelector('.g-albumkarte');
      await (await p.$$('.g-albumkarte'))[i].click();
      await p.waitForSelector('.g-kachel');
      const n = await p.$$eval('.g-kachel', (l) => l.length);
      for (let j = 0; j < n && !gefunden; j++) {
        await (await p.$$('.g-kachel'))[j].click();
        await p.waitForTimeout(800);
        if (await p.evaluate(() => document.querySelector('.g-viewer').classList.contains('g-istvideo'))) {
          gefunden = true;
          await p.waitForSelector('.g-startknopf:not([hidden])', { timeout: 20000 });
          await p.click('.g-startknopf');
          await p.waitForFunction(() => document.querySelector('.g-videoquelle').currentTime > 0.5, null, { timeout: 20000 });
          await p.waitForTimeout(500);
        } else await p.keyboard.press('Escape');
      }
    }
    const br = await p.evaluate(() => [...new Set(window.__breiten)]);
    const ok = br.includes('VIDEO:5760') && !br.some((x) => x.startsWith('CANVAS'));
    if (!ok) fehler++;
    console.log((ok ? '  ok      ' : '  FEHLER  ') + (ipad ? 'iPad' : 'Desktop') + ': Video in voller Breite als Textur (' + br.join(' ') + ')');
    await c.close();
  }
  await b.close(); srv.close();
  console.log(fehler ? fehler + ' Fehler.' : 'Alles bestanden.');
  process.exit(fehler ? 1 : 0);
})().catch((e) => { console.error(e); process.exit(1); });
