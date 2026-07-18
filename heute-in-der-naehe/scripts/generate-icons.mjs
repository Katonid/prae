/**
 * Generates PWA icons (192/512/512-maskable) without any dependencies:
 * draws a location-pin on a blue rounded square and encodes PNG via zlib.
 * Run: npm run icons
 */
import { deflateSync } from 'node:zlib';
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const outDir = join(dirname(fileURLToPath(import.meta.url)), '..', 'public', 'icons');
mkdirSync(outDir, { recursive: true });

function crc32(buf) {
  let table = crc32.table;
  if (!table) {
    table = crc32.table = new Int32Array(256);
    for (let n = 0; n < 256; n++) {
      let c = n;
      for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
      table[n] = c;
    }
  }
  let c = 0xffffffff;
  for (let i = 0; i < buf.length; i++) c = table[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const body = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(body));
  return Buffer.concat([len, body, crc]);
}

function encodePNG(width, height, rgba) {
  const sig = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8; // bit depth
  ihdr[9] = 6; // RGBA
  const raw = Buffer.alloc(height * (1 + width * 4));
  for (let y = 0; y < height; y++) {
    raw[y * (1 + width * 4)] = 0; // filter none
    rgba.copy(raw, y * (1 + width * 4) + 1, y * width * 4, (y + 1) * width * 4);
  }
  return Buffer.concat([
    sig,
    chunk('IHDR', ihdr),
    chunk('IDAT', deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

/** Draw the icon: gradient background, rounded corners, white pin with hole. */
function drawIcon(size, { maskable = false } = {}) {
  const rgba = Buffer.alloc(size * size * 4);
  const cornerR = maskable ? 0 : size * 0.18;
  // pin geometry (centered, slightly above middle)
  const scale = maskable ? 0.72 : 0.9;
  const cx = size / 2;
  const cy = size * (maskable ? 0.44 : 0.42);
  const headR = size * 0.21 * scale;
  const holeR = size * 0.085 * scale;
  const tipY = cy + size * 0.34 * scale;

  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const i = (y * size + x) * 4;
      // rounded-corner mask
      let inside = true;
      if (cornerR > 0) {
        const dx = Math.max(cornerR - x, x - (size - 1 - cornerR), 0);
        const dy = Math.max(cornerR - y, y - (size - 1 - cornerR), 0);
        inside = dx * dx + dy * dy <= cornerR * cornerR;
      }
      if (!inside) {
        rgba[i + 3] = 0;
        continue;
      }
      // vertical gradient sky-blue → deeper blue
      const tGrad = y / size;
      let r = Math.round(14 + (2 - 14) * tGrad + 20 * (1 - tGrad));
      let g = Math.round(165 + (132 - 165) * tGrad);
      let b = Math.round(233 + (199 - 233) * tGrad);

      // pin: circle head + triangle to tip, minus hole
      const dxp = x - cx;
      const dyp = y - cy;
      const inHead = dxp * dxp + dyp * dyp <= headR * headR;
      let inTriangle = false;
      if (y > cy && y < tipY) {
        const tT = (y - cy) / (tipY - cy);
        const half = headR * (1 - tT) * 0.98;
        inTriangle = Math.abs(dxp) <= half;
      }
      const inHole = dxp * dxp + dyp * dyp <= holeR * holeR;
      if ((inHead || inTriangle) && !inHole) {
        r = 255;
        g = 255;
        b = 255;
      }
      rgba[i] = r;
      rgba[i + 1] = g;
      rgba[i + 2] = b;
      rgba[i + 3] = 255;
    }
  }
  return encodePNG(size, size, rgba);
}

writeFileSync(join(outDir, 'icon-192.png'), drawIcon(192));
writeFileSync(join(outDir, 'icon-512.png'), drawIcon(512));
writeFileSync(join(outDir, 'icon-512-maskable.png'), drawIcon(512, { maskable: true }));
console.log('Icons written to', outDir);
