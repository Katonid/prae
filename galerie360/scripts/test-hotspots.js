/*
 * Test der Hotspots (Playwright + Chromium).
 *
 *   node scripts/test-hotspots.js <ordner-mit-testmedien> <ausgabeordner>
 *
 * Testmedien wie für test-e2e.js (foto-a.jpg, foto-gross.jpg, video-a.mp4).
 * Läuft im Browser-Speicher (wie Safari/iPad); den Ordner-Weg prüft test-e2e.js.
 * Geprüft wird über die echte Oberfläche — Klicks, Ziehen, Tastatur, Touch:
 *   Editor: anlegen, verschieben, Lage bei gedrehtem Blick, Rückgängig/
 *   Wiederholen, duplizieren, löschen, ausblenden, Symbolwahl, Aktionen,
 *   Zeitfenster im Video; speichern + neu öffnen; Datenfassung 1 → 2;
 *   exportierte Galerie auf statischem Server: Fenster öffnen/schließen,
 *   kein eingeschleustes HTML/JS, Rundgang Foto → Foto → Video → zurück,
 *   Zeitfenster; Handy mit Touch: Fenster als Blatt, Ziehen auf dem Symbol
 *   dreht das Panorama statt etwas auszulösen.
 */
const { chromium } = require('playwright');
const http = require('http');
const fs = require('fs');
const path = require('path');
const { execFileSync, spawn } = require('child_process');

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

let fehlschlaege = 0;
const pruefe = (bedingung, text) => {
  if (!bedingung) {
    fehlschlaege++;
    console.log('  FEHLER  ' + text);
  } else {
    console.log('  ok      ' + text);
  }
};
const nah = (a, b, toleranz) => Math.abs(a - b) <= toleranz;

(async () => {
  const gen = await server(WURZEL);
  const genUrl = `http://127.0.0.1:${gen.address().port}/`;
  const browser = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader', '--autoplay-policy=no-user-gesture-required'] });
  const ctx = await browser.newContext({ viewport: { width: 1400, height: 900 } });
  const seite = await ctx.newPage();
  const konsole = [];
  seite.on('pageerror', (e) => konsole.push(e.message));
  seite.on('crash', () => konsole.push('Seite abgestürzt'));
  seite.on('console', (m) => { if (m.type() === 'error') konsole.push(m.text()); });
  await seite.addInitScript(() => {
    delete window.showDirectoryPicker;
    delete window.showSaveFilePicker;
  });
  await seite.goto(genUrl);
  await seite.evaluate(async () => {
    const w = await navigator.storage.getDirectory();
    for await (const n of w.keys()) await w.removeEntry(n, { recursive: true });
  });

  console.log('Vorbereitung');
  await seite.click('#k-neu');
  await seite.fill('#frage-eingabe', 'Rundgang');
  await seite.click('#frage-ja');
  await seite.waitForSelector('#editor:not([hidden])');
  const dateien = ['foto-a.jpg', 'foto-gross.jpg', 'video-a.mp4'].map((n) => path.join(medien, n));
  await seite.setInputFiles('#dateiwahl', dateien);
  await seite.waitForFunction(() => document.querySelectorAll('.medium').length === 3 && !document.querySelector('#warteschlange li'), null, { timeout: 120000 });
  for (const [i, t] of ['Am See', 'Aussichtspunkt', 'Panoramafahrt'].entries()) await seite.fill(`.medium:nth-child(${i + 1}) .m-titel`, t);
  const ids = await seite.evaluate(() => window.G360.app.S.projekt.alben[0].medien.map((m) => m.id));
  const [fotoA, fotoB, video] = ids;

  const E = (fn, arg) => seite.evaluate(fn, arg);
  const pano = () => E(() => { const p = window.G360.hsEditor.E.pano; return p.blick(); });
  const hotspots = () => E(() => JSON.parse(JSON.stringify(window.G360.hsEditor.E.m.hotspots)));
  const leinwand = async () => (await seite.$('#hs-pano canvas')).boundingBox();
  const bildschirm = (id) => E((i) => window.G360.hsEditor.E.ebene.position(i), id);

  console.log('Editor: anlegen, verschieben, drehen');
  await seite.click('.medium:nth-child(1) button:has-text("Hotspots")');
  await seite.waitForSelector('#hs-editor:not([hidden])');
  await seite.waitForFunction(() => window.G360.hsEditor.E.pano && window.G360.hsEditor.E.pano.hatTextur, null, { timeout: 20000 });
  let box = await leinwand();
  await seite.click('#hs-setzen');
  await seite.mouse.click(box.x + box.width / 2, box.y + box.height / 2);
  await seite.waitForSelector('#hs-f-titel');
  let hs = await hotspots();
  const b0 = await pano();
  pruefe(hs.length === 1 && nah(hs[0].yaw, b0.yaw, 0.5) && nah(hs[0].pitch, b0.pitch, 0.5), 'Hotspot in der Bildmitte angelegt (yaw ' + hs[0].yaw + ', pitch ' + hs[0].pitch + ')');
  const h1 = hs[0].id;
  await seite.fill('#hs-f-titel', 'Hochkalter');
  await seite.fill('#hs-form textarea', 'Der **Hochkalter** ist *2607 m* hoch.\n\n<script>window.boese=1</script><img src=x onerror="window.boese=1">\n\n[Wikipedia](https://de.wikipedia.org/wiki/Hochkalter_(Berg)) [Falle](javascript:window.boese=1)');

  // Verschieben: Symbol ziehen
  let p0 = await bildschirm(h1);
  await seite.mouse.move(box.x + p0.x, box.y + p0.y);
  await seite.mouse.down();
  await seite.mouse.move(box.x + p0.x + 150, box.y + p0.y - 80, { steps: 10 });
  await seite.mouse.up();
  let p1 = await bildschirm(h1);
  hs = await hotspots();
  pruefe(nah(p1.x, p0.x + 150, 3) && nah(p1.y, p0.y - 80, 3), 'Hotspot folgt dem Ziehen genau (' + Math.round(p1.x - p0.x) + ', ' + Math.round(p1.y - p0.y) + ' px)');
  pruefe(hs[0].yaw > b0.yaw + 5 && hs[0].pitch > b0.pitch + 3, 'Verschieben ändert die Kugelkoordinaten (yaw ' + hs[0].yaw + ', pitch ' + hs[0].pitch + ')');
  const nachZiehen = hs[0];

  // Drehen: Panorama an einer freien Stelle ziehen — der Hotspot bleibt an der Kugel.
  const blickVor = await pano();
  await seite.mouse.move(box.x + 120, box.y + box.height - 120);
  await seite.mouse.down();
  await seite.mouse.move(box.x + 120 - 140, box.y + box.height - 120, { steps: 10 });
  await seite.mouse.up();
  await seite.waitForTimeout(1500); // Nachlauf abwarten
  const blickNach = await pano();
  const p2 = await bildschirm(h1);
  const soll = await E(([y, p]) => window.G360.hsEditor.E.pano.projiziere(y, p), [nachZiehen.yaw, nachZiehen.pitch]);
  pruefe(blickNach.yaw > blickVor.yaw + 5, 'Ziehen im Panorama dreht den Blick (' + blickVor.yaw + '° → ' + blickNach.yaw + '°)');
  pruefe(p2 && nah(p2.x, soll.x, 1.5) && nah(p2.y, soll.y, 1.5) && p2.x < p1.x - 100, 'Hotspot bleibt an seiner Kugelposition und wandert mit dem Bild');
  const rundweg = await E(() => {
    const p = window.G360.hsEditor.E.pano;
    let max = 0;
    for (let i = 0; i < 200; i++) {
      const x = Math.random() * p.canvas.clientWidth, y = Math.random() * p.canvas.clientHeight;
      const r = p.richtung(x, y);
      const q = p.projiziere(r.yaw, r.pitch);
      max = Math.max(max, Math.hypot(q.x - x, q.y - y));
    }
    return max;
  });
  pruefe(rundweg < 1, 'Bildschirm → Kugel → Bildschirm ist verlustfrei (größte Abweichung ' + rundweg.toFixed(2) + ' px)');
  const hsUnberuehrt = (await hotspots())[0];
  pruefe(hsUnberuehrt.yaw === nachZiehen.yaw && hsUnberuehrt.pitch === nachZiehen.pitch, 'Drehen des Panoramas verschiebt keinen Hotspot');

  console.log('Editor: Rückgängig, Duplizieren, Löschen, Sichtbarkeit');
  await seite.click('#hs-undo');
  hs = await hotspots();
  pruefe(nah(hs[0].yaw, b0.yaw, 0.5), 'Rückgängig nimmt das Verschieben zurück');
  await seite.click('#hs-redo');
  hs = await hotspots();
  pruefe(hs[0].yaw === nachZiehen.yaw, 'Wiederholen stellt es wieder her');
  await seite.click('#hs-form button:has-text("Duplizieren")');
  pruefe((await hotspots()).length === 2, 'Duplizieren');
  await seite.click('#hs-form button:has-text("Löschen")');
  hs = await hotspots();
  pruefe(hs.length === 1 && hs[0].id === h1, 'Löschen entfernt die Kopie');
  await seite.click('#hs-liste li:nth-child(1) .mini');
  pruefe((await hotspots())[0].sichtbar === false, 'Ausblenden');
  await seite.click('#hs-liste li:nth-child(1) .mini');
  pruefe((await hotspots())[0].sichtbar === true, 'Wieder einblenden');
  await seite.keyboard.press('Escape');
  await seite.click('#hs-liste li:nth-child(1) .hs-eintrag-wahl');

  console.log('Editor: Symbolwahl');
  await seite.click('.hs-symbolzeile button.zweit');
  await seite.fill('#sym-suche', 'kirche');
  await seite.click('#sym-inhalt .sym-zelle >> nth=0');
  hs = await hotspots();
  pruefe(hs[0].symbol.art === 'icon' && hs[0].symbol.name === 'church' && hs[0].symbol.knoten.length > 0, 'Suche „kirche" findet das Kirchen-Icon');
  await seite.click('.hs-symbolzeile button.zweit');
  await seite.click('#sym-reiter button[data-reiter="zeichen"]');
  await seite.fill('#sym-inhalt input[aria-label="Unicode-Nummer"]', 'U+2192');
  await seite.click('#sym-inhalt button:has-text("Übernehmen")');
  pruefe((await hotspots())[0].symbol.text === '→', 'Unicode-Eingabe U+2192 ergibt →');
  await seite.click('.hs-symbolzeile button.zweit');
  await seite.fill('#sym-suche', 'schneebedeckter');
  await seite.click('#sym-inhalt .sym-text >> nth=0');
  pruefe((await hotspots())[0].symbol.text === '🏔️', 'Emoji-Suche auf Deutsch findet 🏔️');
  await seite.screenshot({ path: path.join(aus, 'h1-editor.png') });

  console.log('Editor: Navigation und Kombi-Fenster');
  const neuAn = async (fx, fy, vorlage) => {
    if (vorlage) await seite.selectOption('#hs-vorlage', vorlage);
    box = await leinwand();
    await seite.click('#hs-setzen');
    await seite.mouse.click(box.x + box.width * fx, box.y + box.height * fy);
    await seite.waitForTimeout(150);
    return (await hotspots()).slice(-1)[0].id;
  };
  await neuAn(0.25, 0.55, 'v-weiter');
  await seite.fill('#hs-f-titel', 'Weiter zum Aussichtspunkt');
  await seite.selectOption('#hs-form .hs-abschnitt select', 'medium:foto');
  await seite.selectOption('#hs-form .hs-gruppe select', fotoB);
  await neuAn(0.75, 0.6, 'v-video');
  await seite.fill('#hs-f-titel', 'Panoramafahrt ansehen');
  await seite.selectOption('#hs-form .hs-gruppe select', video);
  // Kombi: Info mit zwei Schaltflächen am ersten Hotspot
  await seite.click('#hs-liste li:nth-child(1) .hs-eintrag-wahl');
  await seite.click('#hs-form button:has-text("Schaltfläche hinzufügen")');
  await seite.fill('#hs-form .hs-knopfbox input[type="text"]', '360°-Foto vom Aussichtspunkt');
  await seite.selectOption('#hs-form .hs-knopfbox .hs-gruppe select', fotoB);
  await seite.click('#hs-form button:has-text("Schaltfläche hinzufügen")');
  await seite.fill('#hs-form .hs-knopfbox >> nth=1 >> input[type="text"]', '360°-Video ansehen');
  await seite.selectOption('#hs-form .hs-knopfbox >> nth=1 >> select >> nth=0', 'medium:video');
  await seite.selectOption('#hs-form .hs-knopfbox >> nth=1 >> .hs-gruppe select', video);
  hs = await hotspots();
  pruefe(hs.length === 3 && hs[1].aktion.ziel.medium === fotoB && hs[2].aktion.ziel.medium === video, 'Navigation zu Foto und zu Video eingerichtet');
  pruefe(hs[0].aktion.knoepfe.length === 2 && hs[0].aktion.knoepfe[1].ziel.medium === video, 'Kombiniertes Fenster mit zwei Schaltflächen');

  // Foto B: Rückweg nach A
  await seite.selectOption('#hs-medium', fotoB);
  await seite.waitForFunction(() => window.G360.hsEditor.E.pano && window.G360.hsEditor.E.pano.hatTextur);
  await neuAn(0.5, 0.5, 'v-weiter');
  await seite.fill('#hs-f-titel', 'Zurück zum See');
  await seite.selectOption('#hs-form .hs-gruppe select', fotoA);

  console.log('Editor: Video mit Zeitfenster');
  await seite.selectOption('#hs-medium', video);
  await seite.waitForFunction(() => window.G360.hsEditor.E.videoOk, null, { timeout: 20000 });
  pruefe(await seite.isVisible('#hs-zeitleiste'), 'Zeitleiste erscheint bei Videos');
  await neuAn(0.5, 0.5, 'v-berg');
  await seite.fill('#hs-f-titel', 'Gipfel (2–4 s)');
  await seite.fill('#hs-f-von', '2');
  await seite.fill('#hs-f-bis', '4');
  await neuAn(0.3, 0.5, 'v-kamera');
  await seite.fill('#hs-f-titel', 'Zurück zum See');
  await seite.selectOption('#hs-form .hs-gruppe select', fotoA);
  await seite.click('#hs-form .hs-abschnitt label:has-text("Immer sichtbar") input');
  hs = await hotspots();
  pruefe(hs[0].zeit.von === 2 && hs[0].zeit.bis === 4 && hs[1].zeit === null, 'Zeitfenster 2–4 s und „immer sichtbar"');
  const zeitBalken = await seite.$$eval('#hs-balken .hs-zeitbalken', (l) => l.length);
  pruefe(zeitBalken === 1, 'Zeitfenster als Balken auf der Zeitleiste');
  // Balkenende ziehen: bis 4 → ca. 5 s
  await seite.click('#hs-liste li:nth-child(1) .hs-eintrag-wahl');
  const griff = await (await seite.$('#hs-balken .hs-griff.rechts')).boundingBox();
  const spur = await (await seite.$('#hs-spur')).boundingBox();
  const dauer = await E(() => window.G360.hsEditor.E.dauer);
  await seite.mouse.move(griff.x + griff.width / 2, griff.y + griff.height / 2);
  await seite.mouse.down();
  await seite.mouse.move(griff.x + griff.width / 2 + spur.width / dauer, griff.y + griff.height / 2, { steps: 5 });
  await seite.mouse.up();
  hs = await hotspots();
  pruefe(nah(hs[0].zeit.bis, 5, 0.3), 'Ende des Zeitfensters auf der Zeitleiste gezogen (bis ' + hs[0].zeit.bis + ' s)');
  await seite.fill('#hs-f-bis', '4');
  await seite.screenshot({ path: path.join(aus, 'h2-video.png') });
  await seite.click('#hs-fertig');
  await seite.evaluate(() => window.G360.app.sofortSpeichern());

  console.log('Speichern und erneut öffnen');
  await seite.reload();
  await seite.click('#zuletzt-liste .projekt-oeffnen');
  await seite.waitForSelector('#editor:not([hidden])');
  const geladen = await E(() => window.G360.app.S.projekt.alben[0].medien.map((m) => m.hotspots.length));
  pruefe(geladen.join(',') === '3,1,2', 'Nach dem Neuladen sind alle Hotspots da (' + geladen.join(', ') + ')');
  const karte = await seite.textContent('.medium:nth-child(1) .maktionen');
  pruefe(/Hotspots \(3\)/.test(karte), 'Medienkarte zeigt die Anzahl der Hotspots');

  console.log('Ältere Projekte (Datenfassung 1)');
  const migriert = await E(async () => {
    const alt = await (await window.G360.browserSpeicher()).getDirectoryHandle('altprojekt', { create: true });
    const p = JSON.parse(JSON.stringify(window.G360.app.S.projekt));
    p.version = 1;
    delete p.hotspotVorlagen;
    delete p.einstellungen.hotspotStil;
    p.alben.forEach((a) => a.medien.forEach((m) => delete m.hotspots));
    const f = await (await alt.getFileHandle('gallery.json', { create: true })).createWritable();
    await f.write(JSON.stringify(p));
    await f.close();
    const aktuell = window.G360.app.S.wurzel;
    await window.G360.app.projektOeffnen(alt, 'browser');
    const q = window.G360.app.S.projekt;
    const ergebnis = { version: q.version, hotspots: q.alben[0].medien.every((m) => Array.isArray(m.hotspots)), stil: !!q.einstellungen.hotspotStil };
    await window.G360.app.projektOeffnen(aktuell, 'browser');
    return ergebnis;
  });
  pruefe(migriert.version === 2 && migriert.hotspots && migriert.stil, 'Projekt aus Fassung 1 öffnet und wird auf Fassung 2 gebracht');

  console.log('Warnung beim Entfernen eines Ziels');
  await seite.click('.medium:nth-child(2) button:has-text("Entfernen")');
  const warnung = await seite.textContent('#frage-text');
  pruefe(/2 Hotspots verweisen/.test(warnung), 'Entfernen warnt vor Hotspots, die auf die Aufnahme zeigen');
  await seite.click('#frage-nein');

  console.log('Export');
  await seite.click('#k-fertig');
  await seite.waitForSelector('#fertig-inhalt h2.gut', { timeout: 30000 });
  const zipPfad = path.join(aus, 'rundgang.zip');
  const [download] = await Promise.all([seite.waitForEvent('download', { timeout: 60000 }), seite.click('#fertig-inhalt button:has-text("ZIP")')]);
  await download.saveAs(zipPfad);
  const web = path.join(aus, 'webspace');
  fs.rmSync(web, { recursive: true, force: true });
  execFileSync('python3', ['-c', 'import zipfile,sys; z=zipfile.ZipFile(sys.argv[1]); assert z.testzip() is None; z.extractall(sys.argv[2])', zipPfad, web]);
  const index = fs.readFileSync(path.join(web, 'rundgang', 'index.html'), 'utf8');
  pruefe(/"hotspots":\[/.test(index) && /Lucide/.test(index), 'Hotspots und Lizenzhinweis stehen in der exportierten index.html');
  pruefe(!/<script>window\.boese/.test(index), 'Eingegebenes <script> steht nicht als HTML in der Seite');
  await ctx.close();

  // Einfachster statischer Server (python -m http.server, ohne Range) für Seite + Fotos …
  const py = spawn('python3', ['-m', 'http.server', '0', '--bind', '127.0.0.1', '--directory', web], { stdio: ['ignore', 'pipe', 'pipe'] });
  const pyPort = await new Promise((ok) => py.stderr.on('data', () => {}) && py.stdout.on('data', (d) => { const m = /port (\d+)/.exec(String(d)); if (m) ok(+m[1]); }));
  // … und unser Server mit Range-Anfragen (wie Apache/nginx) für das Video.
  const rs = await server(web);
  for (const [name, basis] of [['python', `http://127.0.0.1:${pyPort}/rundgang/`], ['range', `http://127.0.0.1:${rs.address().port}/rundgang/`]]) {
    console.log('Galerie (' + name + '-Server)');
    const c = await browser.newContext({ viewport: { width: 1280, height: 800 } });
    const s = await c.newPage();
    s.on('pageerror', (e) => konsole.push(name + ': ' + e.message));
    s.on('dialog', (d) => { konsole.push('Dialog: ' + d.message()); d.dismiss(); });
    await s.goto(basis + '#a/' + (await (async () => { const p = JSON.parse(fs.readFileSync(path.join(web, 'rundgang', 'gallery.json'))); return p.alben[0].id + '/' + fotoA; })()));
    await s.waitForSelector('.g-viewer.g-offen');
    await s.waitForFunction(() => document.querySelector('.g-laden').hidden, null, { timeout: 20000 });
    await s.waitForTimeout(600);
    const anzahl = await s.$$eval('.g-hs', (l) => l.length);
    pruefe(anzahl === 3, name + ': drei Hotspots im Foto');
    // Hotspot per Tastatur erreichbar und benannt
    const namen = await s.$$eval('.g-hs', (l) => l.map((b) => b.getAttribute('aria-label')));
    pruefe(namen.includes('Hochkalter') && namen.includes('Weiter zum Aussichtspunkt'), name + ': Hotspots haben Namen für Screenreader');
    await s.click('.g-hs[aria-label="Hochkalter"]');
    await s.waitForSelector('.g-ifenster:not([hidden])');
    const fenster = await s.evaluate(() => {
      const f = document.querySelector('.g-ifenster');
      return { titel: f.querySelector('h2').textContent, fett: !!f.querySelector('strong'), kursiv: !!f.querySelector('em'), skripte: f.querySelectorAll('script, img[onerror]').length, links: [...f.querySelectorAll('a')].map((a) => a.href), knoepfe: f.querySelectorAll('.g-ifenster-aktion').length, boese: !!window.boese };
    });
    pruefe(fenster.titel === 'Hochkalter' && fenster.fett && fenster.kursiv, name + ': Fenster mit Titel, fett und kursiv');
    pruefe(fenster.skripte === 0 && !fenster.boese && fenster.links.length === 1 && fenster.links[0].includes('wikipedia.org/wiki/Hochkalter_(Berg)'), name + ': kein eingeschleustes HTML/JS, nur der sichere Link');
    pruefe(fenster.knoepfe === 2, name + ': zwei Schaltflächen im Fenster');
    if (name === 'range') await s.screenshot({ path: path.join(aus, 'h3-fenster.png') });
    await s.click('.g-ifenster-zu');
    pruefe(await s.evaluate(() => document.querySelector('.g-ifenster').hidden), name + ': Fenster schließt über das X');
    await s.click('.g-hs[aria-label="Hochkalter"]');
    await s.keyboard.press('Escape');
    pruefe(await s.evaluate(() => document.querySelector('.g-ifenster').hidden && document.querySelector('.g-viewer.g-offen')), name + ': Esc schließt zuerst das Fenster, nicht den Betrachter');

    await s.click('.g-hs[aria-label="Weiter zum Aussichtspunkt"]');
    await s.waitForFunction(() => document.querySelector('.g-vtitel strong').textContent === 'Aussichtspunkt');
    pruefe(true, name + ': Foto → Foto');
    pruefe(await s.isVisible('.g-tour') && /Am See/.test(await s.textContent('.g-tour')), name + ': „Zurück zu Am See" wird angeboten');
    await s.click('.g-tour');
    await s.waitForFunction(() => document.querySelector('.g-vtitel strong').textContent === 'Am See');
    pruefe(!(await s.isVisible('.g-tour')), name + ': zurück zum Ausgangsfoto');

    if (name === 'range') {
      await s.waitForTimeout(400);
      await s.click('.g-hs[aria-label="Panoramafahrt ansehen"]');
      await s.waitForFunction(() => document.querySelector('.g-viewer').classList.contains('g-istvideo'));
      pruefe(true, 'Foto → Video');
      const zustand = () => s.evaluate(() => [...document.querySelectorAll('.g-hs')].map((b) => b.getAttribute('aria-label') + ':' + (b.classList.contains('g-hs-weg') ? 'aus' : 'an')).join(' '));
      await s.waitForSelector('.g-startknopf:not([hidden])');
      pruefe(/Gipfel \(2–4 s\):aus/.test(await zustand()), 'Video-Hotspot vor seinem Zeitfenster unsichtbar');
      await s.click('.g-startknopf');
      await s.waitForFunction(() => document.querySelector('.g-videoquelle').currentTime > 2.3, null, { timeout: 20000 });
      pruefe(/Gipfel \(2–4 s\):an/.test(await zustand()), 'Video-Hotspot innerhalb seines Zeitfensters sichtbar');
      await s.click('.g-hs[aria-label="Gipfel (2–4 s)"]');
      pruefe(await s.evaluate(() => document.querySelector('.g-videoquelle').paused), 'Video hält an, solange das Fenster offen ist');
      await s.click('.g-ifenster-zu');
      await s.waitForFunction(() => !document.querySelector('.g-videoquelle').paused);
      pruefe(true, 'Video läuft nach dem Schließen weiter');
      await s.waitForFunction(() => document.querySelector('.g-videoquelle').currentTime > 4.3, null, { timeout: 20000 });
      pruefe(/Gipfel \(2–4 s\):aus/.test(await zustand()), 'Video-Hotspot nach seinem Zeitfenster wieder unsichtbar');
      await s.click('.g-hs[aria-label="Zurück zum See"]');
      await s.waitForFunction(() => !document.querySelector('.g-viewer').classList.contains('g-istvideo'));
      pruefe(await s.evaluate(() => !document.querySelector('.g-videoquelle').getAttribute('src')), 'Video → Foto, das Video ist freigegeben');
      // Hotspots ausblenden
      await s.keyboard.press('h');
      pruefe(await s.evaluate(() => [...document.querySelectorAll('.g-hs')].every((b) => getComputedStyle(b).visibility === 'hidden')), 'Taste H blendet alle Hotspots aus');
      await s.keyboard.press('h');
    }
    await c.close();
  }
  py.kill();

  console.log('Handy mit Touch');
  const handy = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true });
  const s = await handy.newPage();
  s.on('pageerror', (e) => konsole.push('handy: ' + e.message));
  const p = JSON.parse(fs.readFileSync(path.join(web, 'rundgang', 'gallery.json')));
  await s.goto(`http://127.0.0.1:${rs.address().port}/rundgang/#a/${p.alben[0].id}/${fotoA}`);
  await s.waitForFunction(() => document.querySelector('.g-laden').hidden, null, { timeout: 20000 });
  await s.waitForTimeout(600);
  const ziel = await s.evaluate(() => {
    const b = [...document.querySelectorAll('.g-hs')].find((x) => !x.classList.contains('g-hs-weg'));
    if (!b) return null;
    const r = b.getBoundingClientRect();
    return { name: b.getAttribute('aria-label'), x: r.left + r.width / 2, y: r.top + r.height / 2, w: r.width };
  });
  pruefe(!!ziel, 'Handy: mindestens ein Hotspot im Bild');
  if (ziel) {
    const treffer = await s.evaluate(([x, y]) => { const e = document.elementFromPoint(x, y); return !!(e && e.closest('.g-hs')); }, [ziel.x, ziel.y + 20]);
    pruefe(treffer, 'Handy: Trefferfläche mindestens 44 px (20 px unter der Mitte trifft noch)');
    // Ziehen, das auf dem Symbol beginnt: dreht das Panorama, öffnet nichts.
    const cdp = await handy.newCDPSession(s);
    const yawVor = await s.evaluate(() => document.querySelector('.g-hs').style.transform);
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: ziel.x, y: ziel.y }] });
    for (let i = 1; i <= 10; i++) await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x: ziel.x - i * 12, y: ziel.y }] });
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
    await s.waitForTimeout(500);
    const nachher = await s.evaluate(() => ({ offen: !document.querySelector('.g-ifenster').hidden, titel: document.querySelector('.g-vtitel strong').textContent, t: document.querySelector('.g-hs').style.transform }));
    pruefe(!nachher.offen && nachher.titel === 'Am See' && nachher.t !== yawVor, 'Handy: Wischen über ein Symbol dreht das Bild und löst nichts aus');
    // Antippen öffnet das Fenster als Blatt von unten.
    const neu = await s.evaluate((n) => { const b = document.querySelector('.g-hs[aria-label="' + n + '"]'); const r = b.getBoundingClientRect(); return { x: r.left + r.width / 2, y: r.top + r.height / 2, weg: b.classList.contains('g-hs-weg') }; }, 'Hochkalter');
    if (!neu.weg) {
      await s.touchscreen.tap(neu.x, neu.y);
      await s.waitForSelector('.g-ifenster:not([hidden])');
      pruefe(await s.evaluate(() => document.querySelector('.g-ifenster').classList.contains('g-blatt')), 'Handy: Fenster erscheint als Blatt von unten');
      await s.waitForTimeout(400);
      await s.screenshot({ path: path.join(aus, 'h4-handy.png') });
      await s.touchscreen.tap(195, 120);
      pruefe(await s.evaluate(() => document.querySelector('.g-ifenster').hidden), 'Handy: Tippen ins Bild schließt das Fenster');
    } else {
      pruefe(false, 'Handy: Hochkalter nach dem Wischen nicht im Bild (Testaufbau)');
    }
  }
  await handy.close();

  console.log('Editor auf dem Tablet (Touch)');
  const tablet = await browser.newContext({ viewport: { width: 1180, height: 820 }, hasTouch: true, isMobile: false });
  const t = await tablet.newPage();
  t.on('pageerror', (e) => konsole.push('tablet: ' + e.message));
  await t.addInitScript(() => { delete window.showDirectoryPicker; delete window.showSaveFilePicker; });
  await t.goto(genUrl);
  await t.click('#k-zip');
  await t.setInputFiles('#dateiwahl-einzeln', zipPfad);
  await t.waitForSelector('#editor:not([hidden])', { timeout: 60000 });
  await t.click('.medium:nth-child(1) button:has-text("Hotspots")');
  await t.waitForFunction(() => window.G360.hsEditor.E.pano && window.G360.hsEditor.E.pano.hatTextur, null, { timeout: 20000 });
  const tb = await (await t.$('#hs-pano canvas')).boundingBox();
  const anzahlVor = await t.evaluate(() => window.G360.hsEditor.E.m.hotspots.length);
  await t.tap('#hs-setzen');
  await t.touchscreen.tap(tb.x + tb.width * 0.4, tb.y + tb.height * 0.7);
  await t.waitForTimeout(200);
  pruefe(await t.evaluate(() => window.G360.hsEditor.E.m.hotspots.length) === anzahlVor + 1, 'Tablet: Hotspot per Fingertipp gesetzt');
  const neuId = await t.evaluate(() => window.G360.hsEditor.E.sel);
  const vor = await t.evaluate((i) => ({ p: window.G360.hsEditor.E.ebene.position(i), h: JSON.parse(JSON.stringify(window.G360.hsEditor.E.m.hotspots.find((x) => x.id === i))) }), neuId);
  const tcdp = await tablet.newCDPSession(t);
  const x0 = tb.x + vor.p.x, y0 = tb.y + vor.p.y;
  await tcdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: x0, y: y0 }] });
  for (let i = 1; i <= 10; i++) await tcdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x: x0 + i * 10, y: y0 - i * 5 }] });
  await tcdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
  await t.waitForTimeout(300);
  const nach = await t.evaluate((i) => ({ p: window.G360.hsEditor.E.ebene.position(i), h: window.G360.hsEditor.E.m.hotspots.find((x) => x.id === i) }), neuId);
  pruefe(nah(nach.p.x, vor.p.x + 100, 4) && nah(nach.p.y, vor.p.y - 50, 4) && nach.h.yaw > vor.h.yaw, 'Tablet: Hotspot mit dem Finger verschoben');
  await t.screenshot({ path: path.join(aus, 'h5-tablet-editor.png') });
  await tablet.close();

  await browser.close();
  gen.close();
  rs.close();
  if (konsole.length) {
    console.log('Meldungen in der Konsole:\n  ' + konsole.join('\n  '));
    fehlschlaege++;
  }
  console.log(fehlschlaege ? fehlschlaege + ' Fehler.' : 'Alles bestanden.');
  process.exit(fehlschlaege ? 1 : 0);
})().catch((e) => { console.error(e); process.exit(1); });
