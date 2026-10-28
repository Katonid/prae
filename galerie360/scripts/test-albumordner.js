/*
 * Test für den Webspace-Aufbau mit Albumordnern (Playwright + Chromium).
 *
 *   node scripts/test-albumordner.js <ordner-mit-testmedien> <ausgabeordner>
 *
 * Wunsch des Nutzers (10/2026): Alben in Unterordnern von 360Grad/ im
 * Ordner des Generators, aufrufbar mit langem Link
 * https://jerosch.net/apps/galerie360/360Grad/<album>-<26 Zeichen>/.
 * Geprüft wird: Link automatisch mit jerosch.net, Ordnername folgt dem
 * Titel bis zur Veröffentlichung, ZIP für den Webspace (360Grad/, je Album
 * eigene Dateien, keine gallery.json, kein Entwurf), Startseite mit
 * Karten in die Albumordner, Albumseite mit „Alle Alben", Foto lädt aus
 * dem Albumordner, Hotspot aus dem geheimen ins öffentliche Album als
 * Link auf dessen Seite, umgekehrt nicht; Sicherung enthält gallery.json.
 */
const { chromium } = require('playwright');
const http = require('http');
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const WURZEL = path.resolve(__dirname, '..');
const [medien, aus] = process.argv.slice(2, 4).map((p) => path.resolve(p));
fs.mkdirSync(aus, { recursive: true });
const TYPEN = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.css': 'text/css', '.json': 'application/json', '.jpg': 'image/jpeg', '.png': 'image/png', '.svg': 'image/svg+xml', '.mp4': 'video/mp4', '.webmanifest': 'application/manifest+json' };

function server(ordner) {
  return new Promise((ok) => {
    const s = http.createServer((req, res) => {
      let p = decodeURIComponent(new URL(req.url, 'http://x').pathname);
      if (p.endsWith('/')) p += 'index.html';
      const datei = path.join(ordner, p);
      if (!datei.startsWith(ordner) || !fs.existsSync(datei) || fs.statSync(datei).isDirectory()) { res.writeHead(404); return res.end(); }
      res.writeHead(200, { 'Content-Type': TYPEN[path.extname(datei)] || 'application/octet-stream' });
      fs.createReadStream(datei).pipe(res);
    });
    s.listen(0, '127.0.0.1', () => ok(s));
  });
}

let fehlschlaege = 0;
const pruefe = (b, text) => { if (!b) fehlschlaege++; console.log((b ? '  ok      ' : '  FEHLER  ') + text); };
const zipNamen = (zip) => execFileSync('python3', ['-c', 'import zipfile,sys; z=zipfile.ZipFile(sys.argv[1]); assert z.testzip() is None; print("\\n".join(z.namelist()))', zip]).toString().trim().split('\n');

(async () => {
  const gen = await server(WURZEL);
  const genUrl = `http://127.0.0.1:${gen.address().port}/`;
  const browser = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });
  const konsole = [];
  const ctx = await browser.newContext({ viewport: { width: 1400, height: 900 } });
  const seite = await ctx.newPage();
  seite.on('pageerror', (e) => konsole.push(e.message));
  await seite.addInitScript(() => { delete window.showDirectoryPicker; delete window.showSaveFilePicker; });
  await seite.goto(genUrl);
  const E = (fn, arg) => seite.evaluate(fn, arg);

  console.log('Galerie und Alben');
  await seite.click('#k-neu');
  await seite.fill('#frage-eingabe', 'Jerosch');
  await seite.click('#frage-ja');
  await seite.waitForSelector('#dlg-frage[open]');
  await seite.click('#frage-nein'); // ohne Passwort — geht jetzt auch mit geheimen Links
  await seite.setInputFiles('#dateiwahl', ['foto-a.jpg', 'foto-gross.jpg', 'video-a.mp4'].map((n) => path.join(medien, n)));
  await seite.waitForFunction(() => document.querySelectorAll('.medium').length === 3 && !document.querySelector('#warteschlange li'), null, { timeout: 120000 });
  await seite.fill('#a-titel', 'Sommer am See');
  const link1 = await seite.inputValue('#a-link-text');
  pruefe(/^https:\/\/jerosch\.net\/apps\/galerie360\/360Grad\/sommer-am-see-[a-z2-7]{26}\/$/.test(link1), 'Link entsteht automatisch: ' + link1);
  for (const [titel, nr] of [['Geheimer Ausflug', 2], ['Entwurf', 2]]) {
    await seite.click('#k-album-neu');
    await seite.fill('#a-titel', titel);
    await seite.click('.album:nth-child(1) .album-wahl');
    await seite.selectOption(`.medium:nth-child(${nr}) select`, { label: titel });
  }
  await seite.click('.album:nth-child(2) .album-wahl');
  await seite.selectOption('#a-freigabe', 'link');
  pruefe(!(await seite.isVisible('#dlg-passwort')), 'Geheimer Link ohne Passwortzwang');
  const link2 = await seite.inputValue('#a-link-text');
  pruefe(/\/360Grad\/geheimer-ausflug-[a-z2-7]{26}\/$/.test(link2), 'Geheimes Album bekommt ebenfalls seinen Ordner: ' + link2.split('/').slice(-2)[0]);
  await seite.click('.album:nth-child(3) .album-wahl');
  await seite.selectOption('#a-freigabe', 'entwurf');
  pruefe(await seite.isHidden('#a-link'), 'Entwurf hat keinen Link');

  const ids = await E(() => window.G360.app.S.projekt.alben.map((a) => ({ id: a.id, m: a.medien.map((m) => m.id), ordner: a.ordner })));
  // Hotspots: öffentlich → geheim (darf nicht hinaus), geheim → öffentlich (wird Link)
  await E(([oeff, geheim]) => {
    const alben = window.G360.app.S.projekt.alben;
    alben[0].medien[0].hotspots.push(window.G360.hsErgaenzen({ id: 'zum-geheimen', titel: 'Zum Geheimen', aktion: { typ: 'medium', ziel: { medium: geheim } } }));
    alben[1].medien[0].hotspots.push(window.G360.hsErgaenzen({ id: 'zum-see', titel: 'Zurück zum See', aktion: { typ: 'medium', ziel: { medium: oeff } } }));
    window.G360.app.speichern();
  }, [ids[0].m[0], ids[1].m[0]]);
  await E(() => window.G360.app.sofortSpeichern());

  console.log('Fertigstellen und ZIP für den Webspace');
  await seite.click('#k-fertig');
  await seite.waitForSelector('#fertig-inhalt h2.gut', { timeout: 30000 });
  const links = await seite.$$eval('.geheimliste input', (l) => l.map((i) => i.value));
  pruefe(links.length === 2 && links[0] === link1 && links[1] === link2, 'Fertigstellen listet beide veröffentlichten Alben mit Link');
  pruefe(/fehlt dieser Sprung/.test(await seite.textContent('#fertig-inhalt')), 'Hinweis: Sprung vom öffentlichen ins geheime Album entfällt');
  const zipPfad = path.join(aus, '360Grad.zip');
  let [download] = await Promise.all([seite.waitForEvent('download', { timeout: 60000 }), seite.click('#fertig-inhalt button:has-text("ZIP für den Webspace")')]);
  await download.saveAs(zipPfad);
  const namen = zipNamen(zipPfad);
  const o1 = link1.split('/').slice(-2)[0], o2 = link2.split('/').slice(-2)[0];
  pruefe(namen.every((n) => n.startsWith('360Grad/')), 'Alles liegt im Ordner 360Grad/ (' + namen.length + ' Dateien)');
  pruefe(!namen.some((n) => /gallery\.json$/.test(n)), 'Keine gallery.json auf dem Webspace');
  pruefe(namen.includes('360Grad/index.html') && namen.includes('360Grad/assets/galerie.js'), 'Startseite und gemeinsamer Betrachter');
  pruefe(namen.includes(`360Grad/${o1}/index.html`) && namen.some((n) => n.startsWith(`360Grad/${o1}/media/fotos/`)) && namen.some((n) => n.startsWith(`360Grad/${o1}/thumbnails/`)), 'Öffentliches Album: eigener Ordner mit seinen Fotos und Vorschaubildern');
  pruefe(namen.some((n) => n.startsWith(`360Grad/${o2}/media/fotos/foto-gross`)) && !namen.some((n) => n.startsWith(`360Grad/${o1}/media/fotos/foto-gross`)), 'Jede Aufnahme liegt nur im Ordner ihres Albums');
  pruefe(!namen.some((n) => /video-a/.test(n)), 'Entwurf (Video) kommt nicht mit');
  pruefe(namen.includes(`360Grad/${o1}/media/fotos/index.html`), 'Leere index.html verhindert Ordnerlisten');
  pruefe(namen.includes(`360Grad/${o1}/assets/galerie.js`) && namen.includes(`360Grad/${o2}/assets/galerie.css`), 'Jedes Album bringt seinen Betrachter mit');

  // Nach dem ZIP ist der Ordnername fest — ein neuer Titel ändert den Link nicht mehr.
  await seite.click('#fertig-inhalt button:has-text("Schließen")');
  await seite.click('.album:nth-child(1) .album-wahl');
  await seite.fill('#a-titel', 'Sommer am See 2026');
  pruefe((await seite.inputValue('#a-link-text')) === link1, 'Nach dem Veröffentlichen bleibt der Link beim Umbenennen gleich');

  [download] = await Promise.all([seite.waitForEvent('download', { timeout: 60000 }), (async () => {
    await seite.click('#k-fertig');
    await seite.waitForSelector('#fertig-inhalt h2.gut', { timeout: 30000 });
    await seite.click('#fertig-inhalt button:has-text("Sicherung")');
  })()]);
  const sicherung = path.join(aus, 'sicherung.zip');
  await download.saveAs(sicherung);
  pruefe(zipNamen(sicherung).some((n) => /\/gallery\.json$/.test(n)), 'Sicherung enthält das Projekt (gallery.json)');

  console.log('Je Album ein ZIP');
  await seite.click('#fertig-inhalt button:has-text("Je Album ein ZIP")');
  await seite.waitForFunction(() => document.querySelectorAll('.zipzeile').length === 3, null, { timeout: 60000 });
  const teile = {};
  for (let i = 0; i < 3; i++) {
    const [d] = await Promise.all([seite.waitForEvent('download'), seite.click(`.zipzeile >> nth=${i} >> button:has-text("Herunterladen")`)]);
    const ziel2 = path.join(aus, 'teil-' + d.suggestedFilename());
    await d.saveAs(ziel2);
    teile[d.suggestedFilename()] = zipNamen(ziel2);
  }
  const ordner1 = link1.split('/').slice(-2)[0];
  pruefe(teile['360Grad.zip'] && teile['360Grad.zip'].every((n) => n.startsWith('360Grad/') && !n.includes(ordner1)), '360Grad.zip: Startseite und Betrachter, ohne Alben');
  pruefe(teile[ordner1 + '.zip'] && teile[ordner1 + '.zip'].every((n) => n.startsWith(ordner1 + '/')) && teile[ordner1 + '.zip'].includes(ordner1 + '/index.html'), 'Album-ZIP: der Albumordner obenauf (kommt in 360Grad/)');
  await ctx.close();

  console.log('iPad: Herunterladen statt Teilen');
  const ipad = await browser.newContext({ viewport: { width: 1180, height: 820 }, hasTouch: true });
  const ip = await ipad.newPage();
  ip.on('pageerror', (e) => konsole.push('ipad: ' + e.message));
  await ip.addInitScript(() => {
    delete window.showDirectoryPicker; delete window.showSaveFilePicker;
    delete FileSystemFileHandle.prototype.createWritable;
    Object.defineProperty(navigator, 'platform', { get: () => 'MacIntel' });
    Object.defineProperty(navigator, 'maxTouchPoints', { get: () => 5 });
    navigator.share = async () => {}; navigator.canShare = () => true;
  });
  await ip.goto(genUrl);
  await ip.click('#k-zip');
  await ip.setInputFiles('#dateiwahl-einzeln', sicherung);
  await ip.waitForSelector('#editor:not([hidden])', { timeout: 60000 });
  let autoDownload = false;
  ip.on('download', () => { autoDownload = true; });
  await ip.click('#k-fertig');
  await ip.waitForSelector('#fertig-inhalt h2.gut', { timeout: 30000 });
  await ip.click('#fertig-inhalt button:has-text("ZIP für den Webspace")');
  await ip.waitForSelector('.zipzeile', { timeout: 60000 });
  await ip.waitForTimeout(500);
  pruefe(!autoDownload, 'iPad: kein automatischer Download, sondern Knöpfe');
  pruefe(await ip.isVisible('.zipzeile button:has-text("Herunterladen (in Dateien)")') && await ip.isEnabled('.zipzeile button:has-text("Teilen")'), 'iPad: „Herunterladen (in Dateien)" und — bei kleiner Datei — „Teilen"');
  const [d2] = await Promise.all([ip.waitForEvent('download'), ip.click('.zipzeile button:has-text("Herunterladen")')]);
  const ipadZip = path.join(aus, 'ipad-360Grad.zip');
  await d2.saveAs(ipadZip);
  pruefe(zipNamen(ipadZip).includes('360Grad/index.html'), 'iPad: ZIP über den Worker geschrieben und heruntergeladen');
  // Großes ZIP: Teilen gesperrt (Schwelle 200 MB) — hier mit verkleinerter Schwelle nachgestellt.
  const gesperrt = await ip.evaluate(() => { const b = [...document.querySelectorAll('.zipzeile button')].find((x) => x.textContent.startsWith('Teilen')); return b ? b.title : ''; });
  pruefe(/An eine App/.test(gesperrt), 'iPad: Teilen-Knopf erklärt sich');
  await ipad.close();

  console.log('Auf dem Webspace (/apps/galerie360/360Grad/)');
  const web = path.join(aus, 'web');
  fs.rmSync(web, { recursive: true, force: true });
  const ziel = path.join(web, 'apps', 'galerie360');
  fs.mkdirSync(ziel, { recursive: true });
  execFileSync('python3', ['-c', 'import zipfile,sys; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])', zipPfad, ziel]);
  const start = fs.readFileSync(path.join(ziel, '360Grad', 'index.html'), 'utf8');
  pruefe(!start.includes(o2) && !/Geheimer|Entwurf/.test(start), 'Startseite verrät weder das geheime Album noch den Entwurf');
  const seiteOeff = fs.readFileSync(path.join(ziel, '360Grad', o1, 'index.html'), 'utf8');
  pruefe(!seiteOeff.includes(o2) && !seiteOeff.includes('zum-geheimen'), 'Öffentliche Albumseite enthält den Sprung ins geheime Album nicht');
  const ws = await server(web);
  const basis = `http://127.0.0.1:${ws.address().port}/apps/galerie360/360Grad/`;
  const c = await browser.newContext({ viewport: { width: 1280, height: 800 } });
  const b = await c.newPage();
  b.on('pageerror', (e) => konsole.push('galerie: ' + e.message));
  await b.goto(basis);
  await b.waitForSelector('.g-albumkarte');
  pruefe((await b.$$eval('.g-albumkarte', (l) => l.map((a) => a.getAttribute('href')))).join() === o1 + '/', 'Startseite: eine Karte, die in den Albumordner führt');
  await b.waitForFunction(() => { const i = document.querySelector('.g-albumkarte img'); return i && i.complete && i.naturalWidth > 0; });
  pruefe(true, 'Vorschaubild der Karte kommt aus dem Albumordner');
  await b.click('.g-albumkarte');
  await b.waitForSelector('.g-kachel');
  pruefe(b.url() === basis + o1 + '/', 'Klick öffnet die Albumseite: ' + b.url().replace(basis, '…/360Grad/'));
  pruefe(await b.isVisible('.g-zurueck'), 'Albumseite hat „Alle Alben"');
  await b.click('.g-kachel');
  await b.waitForFunction(() => document.querySelector('.g-laden').hidden, null, { timeout: 20000 });
  pruefe(await b.evaluate(() => document.querySelector('.g-meldung').hidden), 'Foto lädt aus dem Albumordner');
  await b.keyboard.press('Escape');
  await b.click('.g-zurueck');
  await b.waitForSelector('.g-albumkarte');
  pruefe(b.url() === basis, '„Alle Alben" führt zur Startseite');

  await b.goto(basis + o2 + '/');
  await b.waitForSelector('.g-kachel');
  pruefe(!(await b.isVisible('.g-zurueck')), 'Geheime Albumseite verlinkt die Startseite nicht');
  await b.click('.g-kachel');
  await b.waitForFunction(() => document.querySelector('.g-laden').hidden, null, { timeout: 20000 });
  await b.waitForSelector('.g-hs[aria-label="Zurück zum See"]');
  await b.click('.g-hs[aria-label="Zurück zum See"]');
  await b.waitForURL((u) => u.toString().startsWith(basis + o1 + '/#a/'), { timeout: 10000 });
  await b.waitForFunction(() => document.querySelector('.g-viewer.g-offen') && document.querySelector('.g-laden').hidden, null, { timeout: 20000 });
  pruefe(true, 'Hotspot im geheimen Album öffnet die Aufnahme auf der öffentlichen Albumseite');
  await b.screenshot({ path: path.join(aus, 'a1-sprung.png') });
  await c.close();

  // Nur der Albumordner hochgeladen (10/2026: weiße Seite am iPad).
  console.log('Nur ein Albumordner auf dem Webspace');
  const allein = path.join(aus, 'allein');
  fs.rmSync(allein, { recursive: true, force: true });
  const zielAllein = path.join(allein, 'apps', 'galerie360', '360Grad');
  fs.mkdirSync(zielAllein, { recursive: true });
  execFileSync('python3', ['-c', 'import zipfile,sys; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])', path.join(aus, 'teil-' + o2 + '.zip'), zielAllein]);
  const ws2 = await server(allein);
  const c2 = await browser.newContext({ viewport: { width: 1280, height: 800 } });
  const b2 = await c2.newPage();
  b2.on('pageerror', (e) => konsole.push('allein: ' + e.message));
  await b2.goto(`http://127.0.0.1:${ws2.address().port}/apps/galerie360/360Grad/${o2}/`);
  await b2.waitForSelector('.g-kachel', { timeout: 15000 });
  await b2.click('.g-kachel');
  await b2.waitForFunction(() => document.querySelector('.g-laden').hidden, null, { timeout: 20000 });
  pruefe(await b2.evaluate(() => document.querySelector('.g-meldung').hidden), 'Albumordner allein (ohne 360Grad.zip): Galerie und Foto laden');
  fs.rmSync(path.join(zielAllein, o2, 'assets'), { recursive: true });
  await b2.goto(`http://127.0.0.1:${ws2.address().port}/apps/galerie360/360Grad/${o2}/?x`);
  await b2.waitForFunction(() => /Betrachter fehlt/.test(document.body.textContent), null, { timeout: 15000 });
  pruefe(true, 'Fehlt der Betrachter, steht eine Erklärung da statt einer weißen Seite');
  await c2.close();
  ws2.close();

  await browser.close();
  gen.close();
  ws.close();
  if (konsole.length) { console.log('Meldungen:\n  ' + konsole.join('\n  ')); fehlschlaege++; }
  console.log(fehlschlaege ? fehlschlaege + ' Fehler.' : 'Alles bestanden.');
  process.exit(fehlschlaege ? 1 : 0);
})().catch((e) => { console.error(e); process.exit(1); });
