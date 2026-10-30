/*
 * Videos starten im Netz ohne langes Vorladen (Playwright + Chromium + ffmpeg).
 *
 *   node scripts/test-videostart.js <arbeitsordner>
 *
 * Anlass (10/2026): „In einem Fall wird das Video fast zur Hälfte vorgeladen,
 * bis es abgespielt wird." Läuft im Safari-Weg (ohne createWritable, Worker).
 * Geprüft wird: Ein Video mit Verzeichnis am Ende und Bild/Ton nacheinander
 * wird beim Hinzufügen verlustfrei umgeordnet; ein schon früher hinzugefügtes
 * (nachgestellt) ordnet „Website fertigstellen" um, die alte Datei verschwindet;
 * das Video spielt in der Vorschau; der Hinweis zur Datenrate erscheint.
 */
const { chromium } = require('playwright');
const http = require('http');
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const WURZEL = path.resolve(__dirname, '..');
const aus = path.resolve(process.argv[2] || 'videostart');
fs.mkdirSync(aus, { recursive: true });
const TYPEN = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.css': 'text/css', '.json': 'application/json', '.png': 'image/png', '.svg': 'image/svg+xml', '.webmanifest': 'application/manifest+json' };
let fehler = 0;
const pruefe = (b, t) => { if (!b) fehler++; console.log((b ? '  ok      ' : '  FEHLER  ') + t); };
const ff = (...a) => execFileSync('ffmpeg', ['-loglevel', 'error', '-y', ...a]);

(async () => {
  const v = path.join(aus, 'v.mp4'), a = path.join(aus, 'a.m4a'), hinten = path.join(aus, 'hinten.mp4');
  const schlecht = path.join(aus, 'Rundgang.mp4');
  ff('-f', 'lavfi', '-i', 'testsrc2=size=1920x960:rate=30', '-t', '8', '-c:v', 'libx264', '-pix_fmt', 'yuv420p', v);
  ff('-f', 'lavfi', '-i', 'sine=frequency=440:sample_rate=48000', '-t', '8', '-c:a', 'aac', a);
  ff('-i', v, '-i', a, '-c', 'copy', '-map', '0', '-map', '1', hinten);
  execFileSync('python3', [path.join(WURZEL, 'scripts/mp4-unverzahnt.py'), hinten, schlecht]);

  const srv = http.createServer((q, r) => {
    let p = decodeURIComponent(q.url.split('?')[0]);
    if (p.endsWith('/')) p += 'index.html';
    const f = path.join(WURZEL, p);
    if (!f.startsWith(WURZEL) || !fs.existsSync(f) || fs.statSync(f).isDirectory()) { r.writeHead(404); return r.end(); }
    r.writeHead(200, { 'Content-Type': TYPEN[path.extname(f)] || 'application/octet-stream' });
    r.end(fs.readFileSync(f));
  });
  await new Promise((ok) => srv.listen(0, '127.0.0.1', ok));
  const b = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });
  const c = await b.newContext({ viewport: { width: 1400, height: 900 } });
  const s = await c.newPage();
  const konsole = [];
  s.on('pageerror', (e) => konsole.push(e.message));
  await s.addInitScript(() => { delete window.showDirectoryPicker; delete window.showSaveFilePicker; delete FileSystemFileHandle.prototype.createWritable; });
  await s.goto(`http://127.0.0.1:${srv.address().port}/`);
  const E = (fn, arg) => s.evaluate(fn, arg);
  await s.click('#k-neu');
  await s.fill('#frage-eingabe', 'Videotest');
  await s.click('#frage-ja');
  await s.waitForSelector('#dlg-frage[open]');
  await s.click('#frage-nein');
  const lage = (pfad) => E(async (p) => { const a = await window.G360.mp4Aufbau(await window.G360.dateiLesen(window.G360.app.S.wurzel, p)); return a && { vorne: a.moovVorne, vorlauf: a.verzahnung }; }, pfad);

  console.log('Beim Hinzufügen');
  await s.setInputFiles('#dateiwahl', schlecht);
  await s.waitForFunction(() => document.querySelectorAll('.medium').length === 1 && !document.querySelector('#warteschlange li'), null, { timeout: 120000 });
  let q = await E(() => window.G360.app.S.projekt.alben[0].medien[0].quellen[0]);
  let l = await lage(q.src);
  pruefe(q.netz === 'umgeordnet' && l && l.vorne && l.vorlauf < 1, 'Ungünstiges Video wird beim Hinzufügen umgeordnet (Verzeichnis vorn, Vorauslauf ' + (l ? l.vorlauf.toFixed(2) : '?') + ' s statt 8 s)');
  pruefe(/für schnellen Start umgeordnet/.test(await s.textContent('.fassungen')) && /Mbit\/s/.test(await s.textContent('.fassungen')), 'Karte nennt Datenrate und „für schnellen Start umgeordnet"');

  console.log('Früher hinzugefügtes Video');
  // Nachstellen: die ungünstige Datei liegt in der Galerie, ohne Prüfvermerk (wie vor 1.0.15).
  await E(async (inhalt) => {
    const G = window.G360, S = window.G360.app.S;
    const q = S.projekt.alben[0].medien[0].quellen[0];
    await G.dateiSchreiben(S.wurzel, q.src, new Blob([Uint8Array.from(atob(inhalt), (x) => x.charCodeAt(0))]));
    delete q.netz;
    window.G360.app.speichern();
  }, fs.readFileSync(schlecht).toString('base64'));
  const altSrc = q.src;
  l = await lage(altSrc);
  pruefe(l && !l.vorne && l.vorlauf > 5, 'Nachgestellt: ungünstige Datei in der Galerie (Vorauslauf ' + (l ? l.vorlauf.toFixed(1) : '?') + ' s)');
  await s.click('#k-fertig');
  await s.waitForSelector('#fertig-inhalt h2.gut', { timeout: 60000 });
  pruefe(/1 Video wurde für den schnellen Start im Netz umgeordnet/.test(await s.textContent('#fertig-inhalt')), '„Website fertigstellen" ordnet es um und sagt es');
  q = await E(() => window.G360.app.S.projekt.alben[0].medien[0].quellen[0]);
  l = await lage(q.src);
  const altDa = await E((p) => window.G360.existiert(window.G360.app.S.wurzel, p), altSrc);
  pruefe(q.src !== altSrc && q.netz === 'umgeordnet' && l.vorne && l.vorlauf < 1 && !altDa, 'Neue Datei ' + q.src.split('/').pop() + ' umgeordnet, alte gelöscht');
  await s.click('#fertig-inhalt button:has-text("Schließen")');
  await s.click('#k-fertig');
  await s.waitForSelector('#fertig-inhalt h2.gut', { timeout: 60000 });
  pruefe(!/umgeordnet/.test(await s.textContent('#fertig-inhalt')), 'Zweites Fertigstellen: nichts mehr zu tun');
  await s.click('#fertig-inhalt button:has-text("Schließen")');

  console.log('Abspielen');
  await s.click('#k-vorschau');
  await s.click('#vorschau .g-albumkarte');
  await s.click('#vorschau .g-kachel');
  await s.waitForFunction(() => { const v = document.querySelector('#vorschau .g-videoquelle'); return v && v.currentTime > 1 && !v.paused; }, null, { timeout: 30000 });
  pruefe(true, 'Umgeordnetes Video spielt in der Vorschau');
  await s.keyboard.press('Escape');
  await s.click('#k-vorschau-zu');

  console.log('Datenrate');
  const h = await E(() => window.G360.videoHinweise({ codec: 'hvc1.1.6.L153.B0', breite: 5760, hoehe: 2880, groesse: 25 * 1e6 / 8 * 60 }, [{ codec: 'avc1.640033', breite: 3840 }], 60));
  pruefe(h.some((x) => /Datenrate nur 25 Mbit\/s/.test(x) && /80–120/.test(x)), '5,7K mit 25 Mbit/s: Hinweis auf zu niedrige Datenrate');
  const ok = await E(() => window.G360.videoHinweise({ codec: 'hvc1.1.6.L153.B0', breite: 5760, hoehe: 2880, groesse: 100 * 1e6 / 8 * 60 }, [{ codec: 'avc1.640033', breite: 3840 }], 60));
  pruefe(!ok.some((x) => /Datenrate/.test(x)), '5,7K mit 100 Mbit/s: kein Hinweis');

  await b.close();
  srv.close();
  if (konsole.length) { console.log('Meldungen:\n  ' + konsole.join('\n  ')); fehler++; }
  console.log(fehler ? fehler + ' Fehler.' : 'Alles bestanden.');
  process.exit(fehler ? 1 : 0);
})().catch((e) => { console.error(e); process.exit(1); });
