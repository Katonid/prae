/*
 * Großes ZIP im Safari-Weg (ohne createWritable → Worker mit SyncAccessHandle).
 *
 *   node scripts/test-grosses-zip.js <ausgabeordner> [megabyte]
 *
 * Anlass (10/2026): Am iPhone stürzte Safari beim Teilen eines 1-GB-ZIPs ab;
 * das ZIP lag als Blob aus vielen Teilen im Arbeitsspeicher. Geprüft wird:
 * Das ZIP entsteht als Datei im Browser-Speicher, der JS-Speicher wächst
 * dabei nicht mit der Dateigröße, und Python liest es fehlerfrei (CRC).
 * Belegt kurzzeitig etwa dreimal die Größe auf der Platte.
 */
const { chromium } = require('playwright');
const http = require('http');
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const WURZEL = path.resolve(__dirname, '..');
const aus = path.resolve(process.argv[2] || '.');
const MB = +(process.argv[3] || 400);
fs.mkdirSync(aus, { recursive: true });
const TYPEN = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.css': 'text/css', '.svg': 'image/svg+xml', '.png': 'image/png', '.webmanifest': 'application/manifest+json' };

(async () => {
  const srv = http.createServer((q, r) => { let p = decodeURIComponent(q.url.split('?')[0]); if (p.endsWith('/')) p += 'index.html'; const f = path.join(WURZEL, p); if (!fs.existsSync(f)) { r.writeHead(404); return r.end(); } r.writeHead(200, { 'Content-Type': TYPEN[path.extname(f)] || 'application/octet-stream' }); r.end(fs.readFileSync(f)); });
  await new Promise((ok) => srv.listen(0, '127.0.0.1', ok));
  // Echtes Profil auf der Platte: Ein Wegwerf-Profil hält den Browser-Speicher
  // im Arbeitsspeicher und meldet ab etwa 1 GB QuotaExceeded.
  const profil = fs.mkdtempSync(path.join(aus, 'profil-'));
  const b = await chromium.launchPersistentContext(profil, { args: ['--enable-precise-memory-info'], acceptDownloads: true });
  const p = b.pages()[0] || await b.newPage();
  const fehler = [];
  p.on('pageerror', (e) => fehler.push(e.message));
  await p.addInitScript(() => { delete window.showDirectoryPicker; delete window.showSaveFilePicker; delete FileSystemFileHandle.prototype.createWritable; });
  await p.goto(`http://127.0.0.1:${srv.address().port}/`);
  const t0 = Date.now();
  const ergebnis = await p.evaluate(async (mb) => {
    const G = window.G360;
    const root = await navigator.storage.getDirectory();
    for await (const n of root.keys()) await root.removeEntry(n, { recursive: true });
    const d = await (await G.browserSpeicher()).getDirectoryHandle('gross', { create: true });
    // Eine große Datei aus 1-MB-Stücken — der Blob verweist nur auf dasselbe Stück.
    const stueck = new Uint8Array(1024 * 1024);
    for (let i = 0; i < stueck.length; i++) stueck[i] = (i * 31 + 7) & 255;
    await G.dateiSchreiben(d, 'video.bin', new Blob(new Array(mb).fill(stueck)));
    const datei = await G.dateiLesen(d, 'video.bin');
    const vorher = performance.memory.usedJSHeapSize;
    let spitze = vorher;
    const zip = await G.zipInDatei([
      { pfad: '360Grad/album-' + 'a'.repeat(26) + '/media/videos/video.bin', datei },
      { pfad: '360Grad/index.html', datei: new File(['<!doctype html>'], 'index.html') }
    ], 'gross.zip', () => { spitze = Math.max(spitze, performance.memory.usedJSHeapSize); });
    const a = document.createElement('a');
    a.href = URL.createObjectURL(zip);
    a.download = 'gross.zip';
    document.body.append(a);
    a.click();
    return { groesse: zip.size, datei: datei.size, zuwachs: spitze - vorher, mitWritable: 'createWritable' in FileSystemFileHandle.prototype };
  }, MB).catch((e) => ({ fehler: e.message }));
  console.log(JSON.stringify(ergebnis));
  if (ergebnis.fehler) { console.log('FEHLER'); process.exit(1); }
  const download = await p.waitForEvent('download', { timeout: 600000 });
  const pfad = path.join(aus, 'gross.zip');
  await download.saveAs(pfad);
  const dauer = ((Date.now() - t0) / 1000).toFixed(0);
  let ok = true;
  const pruefe = (b, t) => { if (!b) ok = false; console.log((b ? '  ok      ' : '  FEHLER  ') + t); };
  pruefe(!ergebnis.mitWritable, 'Safari-Weg: ohne createWritable, also über den Worker');
  pruefe(ergebnis.groesse > ergebnis.datei, 'ZIP ' + (ergebnis.groesse / 1048576).toFixed(0) + ' MB als Datei im Browser-Speicher erstellt (' + dauer + ' s)');
  pruefe(ergebnis.zuwachs < 64 * 1024 * 1024, 'JS-Speicher wuchs dabei nur um ' + (ergebnis.zuwachs / 1048576).toFixed(1) + ' MB — die Datei lief nicht durch den Arbeitsspeicher');
  const py = execFileSync('python3', ['-c', 'import zipfile,sys; z=zipfile.ZipFile(sys.argv[1]); print(z.testzip() is None, [i.file_size for i in z.infolist()])', pfad]).toString().trim();
  pruefe(py.startsWith('True'), 'Python liest das ZIP fehlerfrei, Prüfsummen stimmen (' + py + ')');
  fs.unlinkSync(pfad);
  await p.evaluate(async () => { const r = await navigator.storage.getDirectory(); for await (const n of r.keys()) await r.removeEntry(n, { recursive: true }); });
  await b.close();
  fs.rmSync(profil, { recursive: true, force: true });
  srv.close();
  if (fehler.length) { console.log('Meldungen: ' + fehler.join('; ')); ok = false; }
  console.log(ok ? 'Alles bestanden.' : 'Fehler.');
  process.exit(ok ? 0 : 1);
})().catch((e) => { console.error(e); process.exit(1); });
