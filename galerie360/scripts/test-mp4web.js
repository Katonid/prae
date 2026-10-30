/*
 * MP4 fürs Netz umordnen, ohne neu zu kodieren (Node + ffmpeg, kein Browser).
 *
 *   node scripts/test-mp4web.js <arbeitsordner>
 *
 * Anlass (10/2026): Ein Video wurde „fast zur Hälfte vorgeladen", bevor es
 * lief. Geprüft wird G.mp4FuerWeb aus js/medien.js an drei Dateien:
 * Verzeichnis hinten (ffmpeg-Standard), Bild und Ton nacheinander statt
 * verzahnt (scripts/mp4-unverzahnt.py) und eine schon gute Datei (faststart).
 * Danach: Verzeichnis vorn, Bild/Ton verzahnt, und die dekodierten Bilder
 * und Töne sind Bit für Bit dieselben (MD5 über ffmpeg).
 */
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const { execFileSync } = require('child_process');

const WURZEL = path.resolve(__dirname, '..');
const aus = path.resolve(process.argv[2] || 'mp4web');
fs.mkdirSync(aus, { recursive: true });
let fehler = 0;
const pruefe = (b, t) => { if (!b) fehler++; console.log((b ? '  ok      ' : '  FEHLER  ') + t); };
const ff = (...a) => execFileSync('ffmpeg', ['-loglevel', 'error', '-y', ...a]);
const md5 = (f, sel) => execFileSync('ffmpeg', ['-loglevel', 'error', '-i', f, '-map', sel, '-f', 'md5', '-']).toString().trim();
function lage(f) {
  const out = JSON.parse(execFileSync('ffprobe', ['-v', 'error', '-show_entries', 'packet=stream_index,pos,pts_time', '-of', 'json', f]).toString());
  const p = out.packets.filter((x) => x.pos).sort((a, b) => +a.pos - +b.pos);
  let max = 0, rueck = 0;
  for (const x of p) { const t = +x.pts_time; max = Math.max(max, t); rueck = Math.max(rueck, max - t); }
  const d = fs.readFileSync(f);
  const arten = [];
  for (let q = 0; q < d.length;) { let g = d.readUInt32BE(q); const a = d.toString('latin1', q + 4, q + 8); if (g === 1) g = Number(d.readBigUInt64BE(q + 8)); arten.push(a); q += g; }
  return { rueck, moovVorne: arten.indexOf('moov') < arten.indexOf('mdat'), arten };
}

(async () => {
  const fenster = { G360: {} };
  vm.runInNewContext(fs.readFileSync(path.join(WURZEL, 'js/medien.js'), 'utf8'), { window: fenster, Blob, File, DataView, Uint8Array, ArrayBuffer, Math, Date, String, Map, Set, console, Promise, Error, Object, Array, Number, document: {} });
  const G = fenster.G360;
  const v = path.join(aus, 'v.mp4'), a = path.join(aus, 'a.m4a');
  ff('-f', 'lavfi', '-i', 'testsrc2=size=1920x960:rate=30', '-t', '12', '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-g', '60', v);
  ff('-f', 'lavfi', '-i', 'sine=frequency=440:sample_rate=48000', '-t', '12', '-c:a', 'aac', a);
  // Wie Insta360-Exporte: H.265 mit Kennung hvc1
  const v265 = path.join(aus, 'v265.mp4');
  ff('-f', 'lavfi', '-i', 'testsrc2=size=1920x960:rate=30', '-t', '12', '-c:v', 'libx265', '-x265-params', 'log-level=error', '-tag:v', 'hvc1', '-pix_fmt', 'yuv420p', v265);
  const h265 = path.join(aus, 'h265-hinten.mp4'), h265schlecht = path.join(aus, 'h265-schlecht.mp4');
  ff('-i', v265, '-i', a, '-c', 'copy', '-map', '0', '-map', '1', h265);
  execFileSync('python3', [path.join(WURZEL, 'scripts/mp4-unverzahnt.py'), h265, h265schlecht]);
  const hinten = path.join(aus, 'hinten.mp4'), schlecht = path.join(aus, 'schlecht.mp4'), gut = path.join(aus, 'gut.mp4');
  ff('-i', v, '-i', a, '-c', 'copy', '-map', '0', '-map', '1', hinten);
  ff('-i', v, '-i', a, '-c', 'copy', '-map', '0', '-map', '1', '-movflags', '+faststart', gut);
  execFileSync('python3', [path.join(WURZEL, 'scripts/mp4-unverzahnt.py'), hinten, schlecht]);

  for (const [name, f] of [['Verzeichnis hinten', hinten], ['Bild und Ton nacheinander', schlecht], ['H.265 (hvc1), Bild und Ton nacheinander', h265schlecht], ['schon gut', gut]]) {
    const vorher = lage(f);
    const datei = new File([fs.readFileSync(f)], path.basename(f), { type: 'video/mp4' });
    const aufbau = await G.mp4Aufbau(datei);
    pruefe(aufbau && aufbau.moovVorne === vorher.moovVorne && Math.abs(aufbau.verzahnung - vorher.rueck) < 0.2,
      name + ': erkannt (Verzeichnis ' + (aufbau && aufbau.moovVorne ? 'vorn' : 'hinten') + ', Vorauslauf ' + (aufbau ? aufbau.verzahnung.toFixed(1) : '?') + ' s; ffprobe: ' + vorher.rueck.toFixed(1) + ' s)');
    const neu = await G.mp4FuerWeb(datei, aufbau);
    if (name === 'schon gut') { pruefe(neu === null, name + ': bleibt unverändert'); continue; }
    pruefe(!!neu, name + ': wird umgeordnet');
    if (!neu) continue;
    const ziel = path.join(aus, 'web-' + path.basename(f));
    fs.writeFileSync(ziel, Buffer.from(await neu.arrayBuffer()));
    const nachher = lage(ziel);
    pruefe(nachher.moovVorne && nachher.rueck < 1, name + ': danach Verzeichnis vorn, Bild und Ton verzahnt (Vorauslauf ' + nachher.rueck.toFixed(2) + ' s; ' + nachher.arten.join(' ') + ')');
    pruefe(md5(ziel, '0:v') === md5(f, '0:v') && md5(ziel, '0:a') === md5(f, '0:a'), name + ': Bild und Ton dekodiert Bit für Bit gleich (MD5)');
    pruefe(Math.abs(neu.size - datei.size) < 1024, name + ': Größe praktisch gleich (' + datei.size + ' → ' + neu.size + ' Bytes)');
  }
  console.log(fehler ? fehler + ' Fehler.' : 'Alles bestanden.');
  process.exit(fehler ? 1 : 0);
})().catch((e) => { console.error(e); process.exit(1); });
