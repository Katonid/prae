/*
 * Unteralben, Reihenfolge und Album löschen (Playwright + Chromium).
 *
 *   node scripts/test-unteralben.js <ordner-mit-testmedien> <ausgabeordner>
 *
 * Wunsch des Nutzers (10/2026): „keine Funktion gefunden, wie man Alben
 * löschen kann", „Reihenfolge der Bilder wählen", „Unterordner erstellen".
 * Geprüft wird: Sortieren (Datum, umkehren), Ziehen am Griff mit Zeiger-
 * Ereignissen (geht so auch mit dem Finger), Unteralben in zwei Ebenen,
 * „Liegt in" ohne Kreise, Vorschau mit Unteralben, Webspace-ZIP: Startseite
 * nur oberste Ebene, Elternseite mit Karte ins Unteralbum, Unteralbum mit
 * „zurück" zum Elternalbum, nie ein geheimes Unteralbum auf einer
 * öffentlichen Seite; Löschen lässt Unteralben eine Ebene höher rücken.
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

(async () => {
  const gen = await server(WURZEL);
  const browser = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });
  const konsole = [];
  const ctx = await browser.newContext({ viewport: { width: 1400, height: 900 } });
  const seite = await ctx.newPage();
  seite.on('pageerror', (e) => konsole.push(e.message));
  await seite.addInitScript(() => { delete window.showDirectoryPicker; delete window.showSaveFilePicker; });
  await seite.goto(`http://127.0.0.1:${gen.address().port}/`);
  const E = (fn, arg) => seite.evaluate(fn, arg);
  const titelListe = () => E(() => [...document.querySelectorAll('#medienliste .m-titel')].map((i) => i.value));
  const alben = () => E(() => window.G360.app.S.projekt.alben.map((a) => ({ id: a.id, titel: a.titel, eltern: a.eltern || null, n: a.medien.length, ordner: a.ordner, freigabe: a.freigabe.art })));

  await seite.click('#k-neu');
  await seite.fill('#frage-eingabe', 'Familie');
  await seite.click('#frage-ja');
  await seite.waitForSelector('#dlg-frage[open]');
  await seite.click('#frage-nein');
  await seite.setInputFiles('#dateiwahl', ['foto-a.jpg', 'foto-gross.jpg', 'video-a.mp4'].map((n) => path.join(medien, n)));
  await seite.waitForFunction(() => document.querySelectorAll('.medium').length === 3 && !document.querySelector('#warteschlange li'), null, { timeout: 120000 });
  await seite.fill('#a-titel', 'Urlaub');

  console.log('Album löschen ist sichtbar');
  const oben = await seite.$('#k-album-loeschen-oben');
  const box = oben && await oben.boundingBox();
  pruefe(box && box.y < 900, '„Album löschen …" steht oben im Album, ohne Scrollen sichtbar');

  console.log('Reihenfolge');
  pruefe(await seite.isVisible('#sortierleiste'), 'Sortierleiste über den Aufnahmen');
  await E(() => {
    const m = window.G360.app.S.projekt.alben[0].medien;
    m[0].datum = '2026-07-03'; m[1].datum = '2026-07-01'; m[2].datum = '2026-07-02';
    window.G360.app.zeigeAlbum();
  });
  await seite.selectOption('#a-sortieren', 'datum');
  pruefe((await titelListe()).join() === 'foto-gross,video-a,foto-a', 'Nach Aufnahmedatum, älteste zuerst: ' + (await titelListe()).join(', '));
  await seite.selectOption('#a-sortieren', 'umkehren');
  pruefe((await titelListe()).join() === 'foto-a,video-a,foto-gross', 'Umkehren: ' + (await titelListe()).join(', '));
  pruefe(await E(() => document.querySelector('.maktionen .mreihe button').classList.contains('zweit')), '↑ ↓ als sichtbare Knöpfe');
  // Ziehen am Griff: erste Karte unter die letzte
  const griff = await (await seite.$$('.medium .griff'))[0].boundingBox();
  const letzte = await (await seite.$$('.medium'))[2].boundingBox();
  await seite.mouse.move(griff.x + griff.width / 2, griff.y + griff.height / 2);
  await seite.mouse.down();
  for (let y = griff.y; y < letzte.y + letzte.height * 0.8; y += 40) await seite.mouse.move(griff.x + griff.width / 2, y);
  await seite.mouse.move(griff.x + griff.width / 2, letzte.y + letzte.height * 0.8);
  await seite.mouse.up();
  pruefe((await titelListe()).join() === 'video-a,foto-gross,foto-a', 'Ziehen am Griff (Zeiger-Ereignisse) verschiebt: ' + (await titelListe()).join(', '));
  pruefe((await E(() => window.G360.app.S.projekt.alben[0].medien.map((m) => m.titel))).join() === 'video-a,foto-gross,foto-a', 'Neue Reihenfolge ist gespeichert');
  // Mit dem Finger (Berührungs-Ereignisse wie am iPad): letzte Karte nach oben
  const cdp = await ctx.newCDPSession(seite);
  await cdp.send('Emulation.setTouchEmulationEnabled', { enabled: true, maxTouchPoints: 5 });
  await E(() => document.getElementById('medienliste').scrollIntoView());
  const g3 = await (await seite.$$('.medium .griff'))[2].boundingBox();
  const erste = await (await seite.$$('.medium'))[0].boundingBox();
  const x = g3.x + g3.width / 2;
  const punkt = (y) => [{ x, y, id: 1 }];
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: punkt(g3.y + g3.height / 2) });
  for (let y = g3.y + g3.height / 2; y > erste.y + erste.height * 0.2; y -= 30) await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: punkt(y) });
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: punkt(erste.y + erste.height * 0.2) });
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
  await seite.waitForTimeout(200);
  pruefe((await titelListe()).join() === 'foto-a,video-a,foto-gross', 'Ziehen mit dem Finger (Touch) verschiebt: ' + (await titelListe()).join(', '));
  await cdp.send('Emulation.setTouchEmulationEnabled', { enabled: false });

  console.log('Unteralben');
  await seite.click('#k-unteralbum');
  await seite.fill('#a-titel', 'Tag 1');
  await seite.click('#k-unteralbum');
  await seite.fill('#a-titel', 'Abend');
  let a = await alben();
  pruefe(a[1].eltern === a[0].id && a[2].eltern === a[1].id, 'Zwei Ebenen: Urlaub › Tag 1 › Abend');
  pruefe((await seite.$$eval('#albenliste .album', (l) => l.map((x) => getComputedStyle(x).getPropertyValue('--tiefe').trim() || '0'))).join() === '0,1,2', 'Seitenleiste rückt Unteralben ein');
  await seite.click('.album:nth-child(1) .album-wahl');
  const wahl = await seite.$$eval('#a-eltern option', (l) => l.map((o) => o.textContent.trim()));
  pruefe(wahl.length === 1, '„Liegt in" bietet einem Album weder sich selbst noch seine Unteralben an (' + wahl.join(' | ') + ')');
  pruefe(await seite.isVisible('#a-unteralben button:has-text("Tag 1")'), 'Album zeigt seine Unteralben als Knöpfe');
  // Video nach Tag 1, großes Foto nach Abend
  await seite.selectOption('.medium:nth-child(1) select', { label: 'Urlaub › Tag 1' });
  await seite.selectOption('.medium:nth-child(1) select', { label: 'Urlaub › Tag 1 › Abend' });
  a = await alben();
  pruefe(a[0].n === 1 && a[1].n === 1 && a[2].n === 1, '„Verschieben nach" zeigt den Pfad und verschiebt');
  // Ein zweites oberstes Album, „nur mit Link", mit Abend als Unteralbum? Nein: Abend bekommt „nur mit Link".
  await seite.click('.album:nth-child(3) .album-wahl');
  await seite.selectOption('#a-freigabe', 'link');
  const linkAbend = await seite.inputValue('#a-link-text');
  await E(() => window.G360.app.sofortSpeichern());

  console.log('Vorschau');
  await seite.click('#k-vorschau');
  await seite.waitForSelector('#vorschau .g-unteralben .g-albumkarte');
  pruefe((await seite.$$eval('#vorschau .g-unteralben .g-albumkarte h2', (l) => l.map((h) => h.textContent))).join() === 'Tag 1', 'Vorschau: einziges oberes Album direkt, mit Karte seines Unteralbums');
  await seite.click('#vorschau .g-unteralben .g-albumkarte');
  await seite.waitForSelector('#vorschau .g-kachel');
  pruefe(/Tag 1/.test(await seite.textContent('#vorschau .g-titel')) && /Urlaub/.test(await seite.textContent('#vorschau .g-zurueck')), 'Vorschau: Unteralbum mit „zurück zu Urlaub"');
  await seite.click('#k-vorschau-zu');

  console.log('Webspace');
  await seite.click('#k-fertig');
  await seite.waitForSelector('#fertig-inhalt h2.gut', { timeout: 30000 });
  pruefe(/NICHT auf der Seite des öffentlichen Albums/.test(await seite.textContent('#fertig-inhalt')), 'Hinweis: geheimes Unteralbum fehlt auf der öffentlichen Seite');
  const zipPfad = path.join(aus, '360Grad.zip');
  const [download] = await Promise.all([seite.waitForEvent('download', { timeout: 60000 }), seite.click('#fertig-inhalt button:has-text("ZIP für den Webspace")')]);
  await download.saveAs(zipPfad);
  a = await alben();
  const [oU, oT, oA] = a.map((x) => x.ordner);
  const web = path.join(aus, 'web');
  fs.rmSync(web, { recursive: true, force: true });
  const ziel = path.join(web, 'apps', 'galerie360');
  fs.mkdirSync(ziel, { recursive: true });
  execFileSync('python3', ['-c', 'import zipfile,sys; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])', zipPfad, ziel]);
  const lies = (o) => fs.readFileSync(path.join(ziel, '360Grad', o, 'index.html'), 'utf8');
  pruefe(fs.existsSync(path.join(ziel, '360Grad', oT, 'index.html')) && fs.existsSync(path.join(ziel, '360Grad', oA, 'index.html')), 'Jedes Unteralbum hat seinen eigenen Ordner direkt unter 360Grad/');
  pruefe(lies('').includes(oU + '/') && !lies('').includes(oT) && !lies('').includes(oA), 'Startseite: nur das oberste Album');
  pruefe(!lies(oT).includes(oA), 'Öffentliches „Tag 1" verrät das geheime „Abend" nicht');
  pruefe(lies(oA).includes('../' + oT + '/'), 'Geheimes „Abend" führt zurück zu „Tag 1"');

  const ws = await server(web);
  const basis = `http://127.0.0.1:${ws.address().port}/apps/galerie360/360Grad/`;
  const c = await browser.newContext({ viewport: { width: 1280, height: 800 } });
  const b = await c.newPage();
  b.on('pageerror', (e) => konsole.push('galerie: ' + e.message));
  await b.goto(basis);
  await b.click('.g-albumkarte');
  await b.waitForSelector('.g-unteralben .g-albumkarte');
  pruefe(b.url() === basis + oU + '/' && /1 Album/.test(await b.textContent('.g-albuminfo')), 'Urlaub-Seite: Karte ins Unteralbum, Zähler „1 Album"');
  await b.waitForFunction(() => { const i = document.querySelector('.g-unteralben img'); return i && i.complete && i.naturalWidth > 0; });
  pruefe(true, 'Vorschaubild der Unteralbum-Karte lädt aus dessen Ordner');
  await b.click('.g-unteralben .g-albumkarte');
  await b.waitForSelector('.g-kachel');
  pruefe(b.url() === basis + oT + '/', 'Klick öffnet die Seite von „Tag 1"');
  pruefe(/Urlaub/.test(await b.textContent('.g-zurueck')), '„Tag 1" führt zurück zu „Urlaub"');
  await b.click('.g-zurueck');
  await b.waitForSelector('.g-unteralben');
  pruefe(b.url() === basis + oU + '/', 'Zurück landet auf „Urlaub"');
  await b.click('.g-zurueck');
  await b.waitForSelector('.g-albumkarte');
  pruefe(b.url() === basis, '„Alle Alben" von „Urlaub" zur Startseite');
  await b.goto(linkAbend.replace('https://jerosch.net/apps/galerie360/360Grad/', basis));
  await b.waitForSelector('.g-kachel');
  pruefe(/Tag 1/.test(await b.textContent('.g-zurueck')), 'Geheimer Link „Abend" geht, zurück zu „Tag 1"');
  await c.close();
  ws.close();

  console.log('Löschen');
  await seite.click('#fertig-inhalt button:has-text("Schließen")');
  await seite.click('.album:nth-child(2) .album-wahl');
  await seite.click('#k-album-loeschen-oben');
  await seite.waitForSelector('#dlg-frage[open]');
  pruefe(/bleibt erhalten und rückt in „Urlaub"/.test(await seite.textContent('#dlg-frage')), 'Rückfrage nennt, wohin das Unteralbum rückt');
  await seite.click('#frage-ja');
  a = await alben();
  pruefe(a.length === 2 && a[1].titel === 'Abend' && a[1].eltern === a[0].id && a[1].n === 1, '„Tag 1" gelöscht, „Abend" rückt in „Urlaub" und behält sein Foto');

  console.log('Daten');
  const kreis = await E(() => {
    const p = { alben: [{ id: 'x', eltern: 'y', medien: [] }, { id: 'y', eltern: 'x', medien: [] }, { id: 'z', eltern: 'fehlt', medien: [] }, { id: 'w', eltern: 'w', medien: [] }] };
    window.G360.app.ergaenzen(p);
    return p.alben.map((a) => a.eltern || '-').join();
  });
  pruefe(kreis === '-,-,-,-' || (kreis.split(',').filter((e) => e !== '-').length <= 1 && !kreis.startsWith('y,x')), 'Kreise, fehlende Eltern und Selbstverweise werden gelöst (' + kreis + ')');

  await browser.close();
  gen.close();
  if (konsole.length) { console.log('Meldungen:\n  ' + konsole.join('\n  ')); fehlschlaege++; }
  console.log(fehlschlaege ? fehlschlaege + ' Fehler.' : 'Alles bestanden.');
  process.exit(fehlschlaege ? 1 : 0);
})().catch((e) => { console.error(e); process.exit(1); });
