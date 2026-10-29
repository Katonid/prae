/*
 * Test für Passwortschutz und geheime Album-Links (Playwright + Chromium).
 *
 *   node scripts/test-schutz.js <ordner-mit-testmedien> <ausgabeordner>
 *
 * Läuft im Browser-Speicher (wie Safari/iPad). Geprüft wird:
 *   Passwort beim Anlegen (zu kurz, ungleich, gültig), gallery.json
 *   verschlüsselt, Zufallsendung der Dateinamen, Freigabe öffentlich /
 *   geheimer Link / Entwurf, vollständiger Link mit Webadresse, neuer
 *   Link löscht den alten Ordner, Passwort ändern, Entfernen gesperrt
 *   solange es geheime Links gibt, Neuladen nur mit Passwort (falsches
 *   wird abgewiesen), ZIP-Übernahme fragt das Passwort; veröffentlichte
 *   Galerie: Startseite verrät nichts Geheimes, die geheime Seite zeigt
 *   ihr Album, der Entwurf steht nirgends, Hotspot ins geheime Album fehlt
 *   auf der Startseite, kein Referrer; ganz private Galerie zeigt nichts.
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
const PW = 'Sommer 2026 am See';
const PW2 = 'Herbst 2026 im Wald';

(async () => {
  const gen = await server(WURZEL);
  const genUrl = `http://127.0.0.1:${gen.address().port}/`;
  const browser = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });
  const konsole = [];
  const neueSeite = async (ctx) => {
    const s = await ctx.newPage();
    s.on('pageerror', (e) => konsole.push(e.message));
    s.on('crash', () => konsole.push('Seite abgestürzt'));
    await s.addInitScript(() => { delete window.showDirectoryPicker; delete window.showSaveFilePicker; });
    return s;
  };
  const ctx = await browser.newContext({ viewport: { width: 1400, height: 900 }, permissions: ['clipboard-read', 'clipboard-write'] });
  const seite = await neueSeite(ctx);
  await seite.goto(genUrl);
  const E = (fn, arg) => seite.evaluate(fn, arg);
  const opfsDatei = (pfad) => E(async (p) => {
    let d = await (await navigator.storage.getDirectory()).getDirectoryHandle('galerien');
    const t = p.split('/');
    for (const x of t.slice(0, -1)) d = await d.getDirectoryHandle(x);
    return (await (await d.getFileHandle(t[t.length - 1])).getFile()).text();
  }, pfad);
  const opfsOrdner = (pfad) => E(async (p) => {
    let d = await (await navigator.storage.getDirectory()).getDirectoryHandle('galerien');
    for (const x of p.split('/')) d = await d.getDirectoryHandle(x);
    const n = [];
    for await (const k of d.keys()) n.push(k);
    return n;
  }, pfad);

  console.log('Passwort beim Anlegen');
  await seite.click('#k-neu');
  await seite.fill('#frage-eingabe', 'Familie');
  await seite.click('#frage-ja');
  await seite.waitForSelector('#dlg-frage[open]');
  await seite.click('#frage-ja'); // „Passwort festlegen"
  await seite.waitForSelector('#dlg-passwort[open]');
  await seite.fill('#pw-1', 'kurz');
  await seite.fill('#pw-2', 'kurz');
  await seite.click('#pw-ja');
  pruefe(/mindestens 8/.test(await seite.textContent('#pw-fehler')), 'Zu kurzes Passwort wird abgelehnt');
  await seite.fill('#pw-1', PW);
  await seite.fill('#pw-2', PW + 'x');
  await seite.click('#pw-ja');
  pruefe(/stimmen nicht/.test(await seite.textContent('#pw-fehler')), 'Ungleiche Wiederholung wird abgelehnt');
  await seite.fill('#pw-2', PW);
  await seite.click('#pw-ja');
  await seite.waitForSelector('#dlg-frage[open]');
  pruefe(/geschützt/.test(await seite.textContent('#frage-text')), 'Passwort festgelegt');
  await seite.click('#frage-ja');
  pruefe(/Mit Passwort geschützt/.test(await seite.textContent('#schutz-text')), 'Seitenleiste meldet den Schutz');

  console.log('Alben mit verschiedener Freigabe');
  await seite.fill('#a-titel', 'Öffentliche Runde');
  await seite.setInputFiles('#dateiwahl', ['foto-a.jpg', 'foto-gross.jpg', 'video-a.mp4'].map((n) => path.join(medien, n)));
  await seite.waitForFunction(() => document.querySelectorAll('.medium').length === 3 && !document.querySelector('#warteschlange li'), null, { timeout: 120000 });
  const p0 = await E(() => window.G360.app.S.projekt.alben[0].medien.map((m) => ({ id: m.id, datei: m.datei })));
  pruefe(p0.every((m) => /-[a-z2-7]{8}\.(jpg|mp4)$/.test(m.datei)), 'Dateinamen bekommen eine Zufallsendung (' + p0[0].datei + ')');
  await seite.fill('.medium:nth-child(2) .m-titel', 'Geheimes Foto');
  await seite.fill('.medium:nth-child(3) .m-titel', 'Entwurfsvideo');
  // Zwei weitere Alben, Aufnahmen verschieben
  for (const [titel, nr] of [['Geheimes Album', 2], ['Entwurfsalbum', 3]]) {
    await seite.click('#k-album-neu');
    await seite.fill('#a-titel', titel);
    await seite.click('.album:nth-child(1) .album-wahl');
    await seite.selectOption('.medium:nth-child(2) select', { label: titel });
  }
  // Hotspot im öffentlichen Foto, der ins geheime Album zeigt
  await E(([a, b]) => {
    const m = window.G360.app.S.projekt.alben[0].medien[0];
    m.hotspots.push(window.G360.hsErgaenzen({ id: 'hsgeheim', titel: 'Zum Geheimen', yaw: 0, pitch: 0, aktion: { typ: 'medium', ziel: { medium: b } } }));
    window.G360.app.speichern();
  }, [p0[0].id, p0[1].id]);
  await seite.click('.album:nth-child(2) .album-wahl');
  await seite.selectOption('#a-freigabe', 'link');
  const roh1 = await seite.inputValue('#a-link-text');
  pruefe(/^https:\/\/jerosch\.net\/apps\/galerie360\/360Grad\/geheimes-album-[a-z2-7]{26}\/$/.test(roh1), 'Geheimer Link: Albumname + 26 Zufallszeichen, ohne Eintrag auf jerosch.net (' + roh1 + ')');
  const link1 = roh1.split('/').slice(-2)[0] + '/';
  await seite.fill('#g-webadresse', 'https://example.org/360/');
  await seite.click('.album:nth-child(2) .album-wahl');
  const voll = await seite.inputValue('#a-link-text');
  pruefe(voll === 'https://example.org/360/' + link1, 'Eigene Webadresse ersetzt jerosch.net');
  await seite.click('#k-link-kopieren');
  pruefe(await E(() => navigator.clipboard.readText()) === voll, 'Link lässt sich kopieren');
  await seite.click('.album:nth-child(3) .album-wahl');
  await seite.selectOption('#a-freigabe', 'entwurf');
  await seite.click('.album:nth-child(2) .album-wahl');
  await seite.screenshot({ path: path.join(aus, 's0-generator.png') });
  await E(() => window.G360.app.sofortSpeichern());
  const token1 = link1.slice(0, -1); // Ordnername des geheimen Albums

  console.log('Projektdatei verschlüsselt');
  const json = await opfsDatei('familie/gallery.json');
  pruefe(/"verschluesselt"/.test(json) && !/Geheimes|Entwurf|Familie|foto-gross/.test(json) && !json.includes(token1.slice(-26)), 'gallery.json enthält nur Verschlüsseltes — keine Titel, Dateinamen oder Links');

  console.log('Neuer Link');
  await seite.click('.album:nth-child(2) .album-wahl');
  pruefe((await opfsOrdner('familie')).includes(token1), 'Ordner des geheimen Albums angelegt');
  await seite.click('#k-link-neu');
  await seite.click('#frage-ja');
  const token2 = (await seite.inputValue('#a-link-text')).replace('https://example.org/360/', '').slice(0, -1);
  await E(() => window.G360.app.sofortSpeichern());
  const ordner = await opfsOrdner('familie');
  pruefe(token2 !== token1 && ordner.includes(token2) && !ordner.includes(token1), 'Neuer Link: neuer Ordner, der alte ist gelöscht');

  console.log('Passwort ändern und entfernen');
  // Seit 1.0.5 kommt gallery.json nicht auf den Webspace — Entfernen ist auch mit geheimen Links möglich (und verlangt das Passwort).
  await seite.click('#k-passwort-weg');
  await seite.waitForSelector('#dlg-passwort[open]');
  pruefe(/Passwort entfernen/.test(await seite.textContent('#pw-titel')), 'Entfernen fragt nach dem Passwort');
  await seite.click('#pw-nein');
  await seite.click('#k-passwort');
  await seite.fill('#pw-1', 'falsch falsch');
  await seite.click('#pw-ja');
  await seite.waitForFunction(() => /stimmt nicht/.test(document.getElementById('pw-fehler').textContent));
  pruefe(true, 'Ändern verlangt das bisherige Passwort (falsches abgewiesen)');
  await seite.fill('#pw-1', PW);
  await seite.click('#pw-ja');
  await seite.waitForFunction(() => document.getElementById('pw-titel').textContent === 'Neues Passwort');
  await seite.fill('#pw-1', PW2);
  await seite.fill('#pw-2', PW2);
  await seite.click('#pw-ja');
  await seite.waitForSelector('#dlg-frage[open]');
  await seite.click('#frage-ja');

  console.log('Fertigstellen und veröffentlichen');
  await seite.click('#k-fertig');
  await seite.waitForSelector('#fertig-inhalt h2.gut', { timeout: 30000 });
  const fertigText = await seite.textContent('#fertig-inhalt');
  const linkFelder = await seite.$$eval('.geheimliste input', (l) => l.map((i) => i.value));
  pruefe(linkFelder.includes('https://example.org/360/' + token2 + '/'), 'Fertigstellen listet den geheimen Link');
  pruefe(/fehlt dieser Sprung/.test(fertigText), 'Hinweis: Hotspot ins geheime Album entfällt');
  const zipPfad = path.join(aus, 'familie.zip');
  const [download] = await Promise.all([seite.waitForEvent('download', { timeout: 60000 }), seite.click('#fertig-inhalt button:has-text("Sicherung")')]);
  await download.saveAs(zipPfad);
  await seite.click('#fertig-inhalt button:has-text("Schließen")');
  const web = path.join(aus, 'webspace');
  fs.rmSync(web, { recursive: true, force: true });
  execFileSync('python3', ['-c', 'import zipfile,sys; z=zipfile.ZipFile(sys.argv[1]); assert z.testzip() is None; z.extractall(sys.argv[2])', zipPfad, web]);
  const g = path.join(web, 'familie-sicherung');
  const start = fs.readFileSync(path.join(g, 'index.html'), 'utf8');
  const ids = p0.map((m) => m.id);
  pruefe(!/Geheimes|Entwurf/.test(start) && !start.includes(token2) && !start.includes(ids[1]) && !start.includes(ids[2]), 'Startseite enthält weder geheime noch Entwurfs-Alben (Titel, Ids, Link)');
  pruefe(!start.includes('hsgeheim'), 'Hotspot ins geheime Album fehlt auf der Startseite');
  pruefe(/<meta name="referrer" content="no-referrer">/.test(start), 'Kein Referrer — Adressen gelangen nicht an fremde Seiten');
  const geheimSeite = fs.readFileSync(path.join(g, token2, 'index.html'), 'utf8');
  pruefe(/Geheimes Album/.test(geheimSeite) && !/Entwurf|Öffentliche Runde/.test(geheimSeite) && /noindex/.test(geheimSeite), 'Geheime Seite enthält nur ihr Album und ist für Suchmaschinen gesperrt');
  const htmlDateien = [];
  const suche = (d) => fs.readdirSync(d, { withFileTypes: true }).forEach((e) => { const q = path.join(d, e.name); if (e.isDirectory()) suche(q); else if (e.name.endsWith('.html')) htmlDateien.push(q); });
  suche(g);
  pruefe(htmlDateien.every((f) => !/Entwurfsvideo|Entwurfsalbum/.test(fs.readFileSync(f, 'utf8'))) && htmlDateien.every((f) => !fs.readFileSync(f, 'utf8').includes(ids[2])), 'Entwurf steht in keiner Seite (' + htmlDateien.length + ' HTML-Dateien geprüft)');
  pruefe(!fs.existsSync(path.join(g, token1)), 'Ordner des alten Links ist nicht im Export');

  const ws = await server(web);
  const c = await browser.newContext({ viewport: { width: 1280, height: 800 } });
  const b = await c.newPage();
  b.on('pageerror', (e) => konsole.push('galerie: ' + e.message));
  await b.goto(`http://127.0.0.1:${ws.address().port}/familie-sicherung/`);
  await b.waitForSelector('.g-albumkarte');
  // Nur ein öffentliches Album: Die Startseite (Galerie „Familie") zeigt es als Karte (seit 1.0.13).
  pruefe((await b.$$eval('.g-albumkarte', (l) => l.length)) === 1 && /Familie/.test(await b.textContent('.g-titel')) && !/Geheim|Entwurf/.test(await b.textContent('body')), 'Startseite zeigt nur das öffentliche Album');
  await b.click('.g-albumkarte');
  await b.waitForSelector('.g-kachel');
  pruefe((await b.$$eval('.g-kachel', (l) => l.length)) === 1, 'Karte öffnet das öffentliche Album mit seiner Aufnahme');
  await b.goto(`http://127.0.0.1:${ws.address().port}/familie-sicherung/${token2}/`);
  await b.waitForSelector('.g-kachel');
  pruefe(/Geheimes Album/.test(await b.textContent('.g-titel')), 'Geheimer Link öffnet das geheime Album');
  await b.click('.g-kachel');
  await b.waitForFunction(() => document.querySelector('.g-laden').hidden, null, { timeout: 20000 });
  pruefe(await b.evaluate(() => document.querySelector('.g-meldung').hidden), 'Foto im geheimen Album lädt über ../media');
  await b.screenshot({ path: path.join(aus, 's1-geheim.png') });
  const falsch = await b.goto(`http://127.0.0.1:${ws.address().port}/familie-sicherung/${token1}/`);
  pruefe(falsch.status() === 404, 'Alter Link führt ins Leere');
  await c.close();

  console.log('Neu öffnen nur mit Passwort');
  await seite.reload();
  await seite.waitForSelector('#zuletzt-liste .projekt-oeffnen');
  pruefe(/🔒/.test(await seite.textContent('#zuletzt-liste')) && !/Familie/.test(await seite.textContent('#zuletzt-liste strong')), 'Liste zeigt das Schloss statt des Titels');
  await seite.click('#zuletzt-liste .projekt-oeffnen');
  await seite.waitForSelector('#dlg-passwort[open]');
  await seite.fill('#pw-1', PW);
  await seite.click('#pw-ja');
  await seite.waitForFunction(() => /stimmt nicht/.test(document.getElementById('pw-fehler').textContent), null, { timeout: 20000 });
  pruefe(await seite.isHidden('#editor'), 'Altes Passwort wird nach dem Ändern abgewiesen');
  await seite.fill('#pw-1', PW2);
  await seite.click('#pw-ja');
  await seite.waitForSelector('#editor:not([hidden])', { timeout: 20000 });
  const alben = await E(() => window.G360.app.S.projekt.alben.map((a) => a.titel + ':' + a.freigabe.art));
  pruefe(alben.join(',') === 'Öffentliche Runde:oeffentlich,Geheimes Album:link,Entwurfsalbum:entwurf', 'Mit richtigem Passwort ist alles wieder da (' + alben.join(', ') + ')');

  console.log('Ganz private Galerie');
  await seite.click('.album:nth-child(1) .album-wahl');
  await seite.selectOption('#a-freigabe', 'entwurf');
  await E(() => window.G360.app.sofortSpeichern());
  const leer = await opfsDatei('familie/index.html');
  pruefe(/"privat":true/.test(leer) && !/Familie|Öffentliche Runde/.test(leer), 'Ohne öffentliche Alben verrät die Startseite nicht einmal den Titel');
  await ctx.close();

  console.log('ZIP auf einem anderen Gerät übernehmen');
  const c2 = await browser.newContext({ viewport: { width: 1280, height: 800 } });
  const s2 = await neueSeite(c2);
  await s2.goto(genUrl);
  await s2.click('#k-zip');
  await s2.setInputFiles('#dateiwahl-einzeln', zipPfad);
  await s2.waitForSelector('#dlg-passwort[open]', { timeout: 60000 });
  await s2.fill('#pw-1', PW2);
  await s2.click('#pw-ja');
  await s2.waitForSelector('#editor:not([hidden])', { timeout: 20000 });
  pruefe((await s2.evaluate(() => window.G360.app.S.projekt.alben.length)) === 3, 'Übernommenes ZIP öffnet nur mit Passwort');
  await c2.close();

  await browser.close();
  gen.close();
  ws.close();
  if (konsole.length) { console.log('Meldungen:\n  ' + konsole.join('\n  ')); fehlschlaege++; }
  console.log(fehlschlaege ? fehlschlaege + ' Fehler.' : 'Alles bestanden.');
  process.exit(fehlschlaege ? 1 : 0);
})().catch((e) => { console.error(e); process.exit(1); });
