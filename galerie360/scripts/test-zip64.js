/* ZIP64-Weg prüfen: Grenze auf 1000 Byte gesenkt, damit kleine Dateien ihn nehmen.
 *   node scripts/test-zip64.js <ausgabeordner>  — danach mit python3 zipfile / unzip -t prüfen. */
const { chromium } = require('playwright');
const fs = require('fs');
(async () => {
  const quelle = fs.readFileSync(require('path').join(__dirname, '..', 'js', 'speicher.js'), 'utf8').replace('const GRENZE = VOLL;', 'const GRENZE = 1000;');
  const b = await chromium.launch();
  const p = await b.newPage();
  const srv = require('http').createServer((q, r) => { r.writeHead(200, { 'Content-Type': 'text/html' }); r.end('<p></p>'); });
  await new Promise((ok) => srv.listen(0, '127.0.0.1', ok));
  await p.goto('http://127.0.0.1:' + srv.address().port + '/');
  await p.addScriptTag({ content: quelle });
  for (const mitZiel of [false, true]) {
    const b64 = await p.evaluate(async (mitZiel) => {
      const zufall = new Uint8Array(5000); crypto.getRandomValues(zufall);
      const e = [{ pfad: 'g/a.bin', datei: new File([zufall], 'a.bin') }, { pfad: 'g/ü.txt', datei: new File(['hallo'], 'u.txt') }, { pfad: 'g/c.bin', datei: new File([zufall.slice(0, 3000)], 'c.bin') }];
      let blob;
      if (mitZiel) {
        const w = await navigator.storage.getDirectory().catch(() => null);
        if (!w) return 'kein-opfs';
        const h = await w.getFileHandle('z.zip', { create: true });
        await window.G360.zipErstellen(e, await h.createWritable(), () => {});
        blob = await h.getFile();
      } else blob = await window.G360.zipErstellen(e, null, () => {});
      const a = new Uint8Array(await blob.arrayBuffer()); let s = ''; a.forEach((x) => s += String.fromCharCode(x)); return btoa(s);
    }, mitZiel);
    if (b64 === 'kein-opfs') { console.log('OPFS nicht verfügbar auf dieser Seite'); continue; }
    fs.writeFileSync(require('path').join(process.argv[2] || '.', `z64-${mitZiel}.zip`), Buffer.from(b64, 'base64'));
  }
  await b.close();
  srv.close();
})();
