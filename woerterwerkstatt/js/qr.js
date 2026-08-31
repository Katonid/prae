// QR-Code — selbst gerechnet, ohne fremde Bibliothek.
//
// Warum nicht eine der vielen fertigen Bibliotheken? Weil jede davon entweder
// nachgeladen werden müsste (bricht den Offline-Betrieb und meldet den Aufruf
// an einen fremden Server) oder als Kopie im Repo läge, die niemand mehr
// pflegt. Ein QR-Code ist gut dokumentiert und in zweihundert Zeilen zu haben;
// gebraucht wird hier ohnehin nur ein Bruchteil des Standards:
//
//   Modus         Byte (8 Bit), das reicht für eine URL
//   Fehlerkorrektur  Stufe M (rund 15 % Verlust verkraftbar) — der übliche
//                    Kompromiss für einen Code, der an der Tafel hängt und aus
//                    zwei Metern abfotografiert wird
//   Fassungen     1 bis 10, das sind bis zu 271 Zeichen
//
// Ausgegeben wird SVG, kein Bild: Der Code muss am Beamer scharf sein und auf
// einem Ausdruck ebenso — und er lässt sich so ohne Umweg ausdrucken.
//
// Geprüft ist die Rechnung gegen eine unabhängige Umsetzung (segno); die
// Prüfung liegt in scripts/qr-pruefen.py.

import { s } from './util.js';

/* ---------- Rechnen in GF(256) ---------- */

const EXP = new Uint8Array(512);
const LOG = new Uint8Array(256);
(function tabellen() {
  let x = 1;
  for (let i = 0; i < 255; i += 1) {
    EXP[i] = x;
    LOG[x] = i;
    x <<= 1;
    if (x & 0x100) x ^= 0x11d; // das Standardpolynom des QR-Codes
  }
  for (let i = 255; i < 512; i += 1) EXP[i] = EXP[i - 255];
}());

function malen(a, b) {
  if (!a || !b) return 0;
  return EXP[LOG[a] + LOG[b]];
}

/** Das Generatorpolynom für `anzahl` Fehlerkorrektur-Stellen. */
function generator(anzahl) {
  let poly = [1];
  for (let i = 0; i < anzahl; i += 1) {
    const neu = new Array(poly.length + 1).fill(0);
    for (let j = 0; j < poly.length; j += 1) {
      neu[j] ^= poly[j];
      neu[j + 1] ^= malen(poly[j], EXP[i]);
    }
    poly = neu;
  }
  return poly;
}

/** Die Fehlerkorrektur-Stellen eines Blocks (Polynomdivision). */
function fehlerkorrektur(daten, anzahl) {
  const gen = generator(anzahl);
  const rest = new Array(daten.length + anzahl).fill(0);
  for (let i = 0; i < daten.length; i += 1) rest[i] = daten[i];
  for (let i = 0; i < daten.length; i += 1) {
    const faktor = rest[i];
    if (!faktor) continue;
    for (let j = 0; j < gen.length; j += 1) rest[i + j] ^= malen(gen[j], faktor);
  }
  return rest.slice(daten.length);
}

/* ---------- Tabellen des Standards ---------- */

// Gesamtzahl der Stellen (Daten + Fehlerkorrektur) je Fassung 1…10.
const STELLEN = [0, 26, 44, 70, 100, 134, 172, 196, 242, 292, 346];

// Je Fassung und Stufe: [Korrekturstellen je Block, Blöcke A, Datenstellen A, Blöcke B, Datenstellen B]
const BLOECKE = {
  L: [null,
    [7, 1, 19, 0, 0], [10, 1, 34, 0, 0], [15, 1, 55, 0, 0], [20, 1, 80, 0, 0], [26, 1, 108, 0, 0],
    [18, 2, 68, 0, 0], [20, 2, 78, 0, 0], [24, 2, 97, 0, 0], [30, 2, 116, 0, 0], [18, 2, 68, 2, 69]],
  M: [null,
    [10, 1, 16, 0, 0], [16, 1, 28, 0, 0], [26, 1, 44, 0, 0], [18, 2, 32, 0, 0], [24, 2, 43, 0, 0],
    [16, 4, 27, 0, 0], [18, 4, 31, 0, 0], [22, 2, 38, 2, 39], [22, 3, 36, 2, 37], [26, 4, 43, 1, 44]],
};

// Mittelpunkte der Ausrichtungsmuster je Fassung.
const AUSRICHTUNG = [[], [], [6, 18], [6, 22], [6, 26], [6, 30], [6, 34], [6, 22, 38], [6, 24, 42], [6, 26, 46], [6, 28, 50]];

// Zusätzliche Füllbits nach den Stellen (Fassung 2…6 brauchen sieben).
const FUELLBITS = [0, 0, 7, 7, 7, 7, 7, 0, 0, 0, 0];

const STUFENBITS = { L: 0b01, M: 0b00, Q: 0b11, H: 0b10 };

/* ---------- Daten in Bits ---------- */

function bitfolge() {
  const bits = [];
  return {
    bits,
    schieben(wert, laenge) {
      for (let i = laenge - 1; i >= 0; i -= 1) bits.push((wert >> i) & 1);
    },
  };
}

function inBytes(text) {
  return Array.from(new TextEncoder().encode(String(text)));
}

function datenstellen(fassung, stufe) {
  const [ec, b1, d1, b2, d2] = BLOECKE[stufe][fassung];
  return b1 * d1 + b2 * d2;
}

function passendeFassung(laenge, stufe) {
  for (let fassung = 1; fassung <= 10; fassung += 1) {
    const kopf = 4 + (fassung < 10 ? 8 : 16);
    if (Math.ceil((kopf + laenge * 8) / 8) <= datenstellen(fassung, stufe)) return fassung;
  }
  return 0;
}

function stellenBauen(bytes, fassung, stufe) {
  const kapazitaet = datenstellen(fassung, stufe);
  const folge = bitfolge();
  folge.schieben(0b0100, 4);                       // Byte-Modus
  folge.schieben(bytes.length, fassung < 10 ? 8 : 16);
  for (const b of bytes) folge.schieben(b, 8);
  // Abschluss (höchstens vier Nullen) und auf volle Bytes auffüllen.
  const rest = kapazitaet * 8 - folge.bits.length;
  folge.schieben(0, Math.min(4, Math.max(0, rest)));
  while (folge.bits.length % 8) folge.bits.push(0);
  const stellen = [];
  for (let i = 0; i < folge.bits.length; i += 8) {
    let byte = 0;
    for (let j = 0; j < 8; j += 1) byte = (byte << 1) | folge.bits[i + j];
    stellen.push(byte);
  }
  const fueller = [0xec, 0x11];
  let i = 0;
  while (stellen.length < kapazitaet) { stellen.push(fueller[i % 2]); i += 1; }
  return stellen;
}

/** Daten- und Korrekturstellen blockweise verschränken — so will es der Standard. */
function verschraenken(stellen, fassung, stufe) {
  const [ecAnzahl, b1, d1, b2, d2] = BLOECKE[stufe][fassung];
  const datenbloecke = [];
  const ecbloecke = [];
  let stelle = 0;
  for (let i = 0; i < b1; i += 1) {
    const block = stellen.slice(stelle, stelle + d1);
    stelle += d1;
    datenbloecke.push(block);
    ecbloecke.push(fehlerkorrektur(block, ecAnzahl));
  }
  for (let i = 0; i < b2; i += 1) {
    const block = stellen.slice(stelle, stelle + d2);
    stelle += d2;
    datenbloecke.push(block);
    ecbloecke.push(fehlerkorrektur(block, ecAnzahl));
  }
  const out = [];
  const maxDaten = Math.max(d1, d2);
  for (let i = 0; i < maxDaten; i += 1) {
    for (const block of datenbloecke) if (i < block.length) out.push(block[i]);
  }
  for (let i = 0; i < ecAnzahl; i += 1) {
    for (const block of ecbloecke) out.push(block[i]);
  }
  return out;
}

/* ---------- Das Feld ---------- */

function leeresFeld(groesse) {
  const feld = [];
  for (let i = 0; i < groesse; i += 1) feld.push(new Array(groesse).fill(null));
  return feld;
}

function suchmusterSetzen(feld, zeile, spalte) {
  const groesse = feld.length;
  for (let r = -1; r <= 7; r += 1) {
    for (let c = -1; c <= 7; c += 1) {
      const y = zeile + r; const x = spalte + c;
      if (y < 0 || y >= groesse || x < 0 || x >= groesse) continue;
      const imRing = (r >= 0 && r <= 6 && (c === 0 || c === 6)) || (c >= 0 && c <= 6 && (r === 0 || r === 6));
      const imKern = r >= 2 && r <= 4 && c >= 2 && c <= 4;
      feld[y][x] = imRing || imKern ? 1 : 0;
    }
  }
}

function ausrichtungSetzen(feld, fassung) {
  const punkte = AUSRICHTUNG[fassung];
  for (const zeile of punkte) {
    for (const spalte of punkte) {
      if (feld[zeile][spalte] !== null) continue; // liegt auf einem Suchmuster
      for (let r = -2; r <= 2; r += 1) {
        for (let c = -2; c <= 2; c += 1) {
          feld[zeile + r][spalte + c] = (Math.abs(r) === 2 || Math.abs(c) === 2 || (r === 0 && c === 0)) ? 1 : 0;
        }
      }
    }
  }
}

function bchFormat(wert) {
  let rest = wert << 10;
  for (let i = 14; i >= 10; i -= 1) if ((rest >> i) & 1) rest ^= 0b10100110111 << (i - 10);
  return ((wert << 10) | rest) ^ 0b101010000010010;
}

function bchVersion(fassung) {
  let rest = fassung << 12;
  for (let i = 17; i >= 12; i -= 1) if ((rest >> i) & 1) rest ^= 0b1111100100101 << (i - 12);
  return (fassung << 12) | rest;
}

function formatSetzen(feld, stufe, maske) {
  const groesse = feld.length;
  const bits = bchFormat((STUFENBITS[stufe] << 3) | maske);
  const lies = (i) => (bits >> i) & 1;
  // Erste Ausfertigung: senkrecht an der linken Kante, dann waagrecht unter
  // dem Suchmuster oben links. Achtung — die Reihenfolge des Standards ist
  // NICHT spiegelbildlich, hier steckt die häufigste Verwechslung (Zeile und
  // Spalte vertauscht ergibt einen Code, der tadellos aussieht und den keine
  // Kamera liest).
  for (let i = 0; i <= 5; i += 1) feld[i][8] = lies(i);
  feld[7][8] = lies(6);
  feld[8][8] = lies(7);
  feld[8][7] = lies(8);
  for (let i = 9; i <= 14; i += 1) feld[8][14 - i] = lies(i);
  // Zweite Ausfertigung: die niedrigen Bits waagrecht rechts oben, die hohen
  // senkrecht links unten — genau andersherum als in der ersten. Auch das ist
  // keine Nachlässigkeit des Standards, sondern Absicht: Wird eine Ecke
  // verdeckt, bleibt die andere Ausfertigung lesbar.
  for (let i = 0; i <= 7; i += 1) feld[8][groesse - 1 - i] = lies(i);
  for (let i = 8; i <= 14; i += 1) feld[groesse - 15 + i][8] = lies(i);
  feld[groesse - 8][8] = 1; // die immer dunkle Stelle
}

function versionSetzen(feld, fassung) {
  if (fassung < 7) return;
  const groesse = feld.length;
  const bits = bchVersion(fassung);
  for (let i = 0; i < 18; i += 1) {
    const bit = (bits >> i) & 1;
    const zeile = Math.floor(i / 3);
    const spalte = i % 3;
    feld[groesse - 11 + spalte][zeile] = bit;
    feld[zeile][groesse - 11 + spalte] = bit;
  }
}

const MASKEN = [
  (r, c) => (r + c) % 2 === 0,
  (r) => r % 2 === 0,
  (r, c) => c % 3 === 0,
  (r, c) => (r + c) % 3 === 0,
  (r, c) => (Math.floor(r / 2) + Math.floor(c / 3)) % 2 === 0,
  (r, c) => ((r * c) % 2) + ((r * c) % 3) === 0,
  (r, c) => (((r * c) % 2) + ((r * c) % 3)) % 2 === 0,
  (r, c) => (((r + c) % 2) + ((r * c) % 3)) % 2 === 0,
];

function grundgeruest(fassung) {
  const groesse = fassung * 4 + 17;
  const feld = leeresFeld(groesse);
  suchmusterSetzen(feld, 0, 0);
  suchmusterSetzen(feld, 0, groesse - 7);
  suchmusterSetzen(feld, groesse - 7, 0);
  ausrichtungSetzen(feld, fassung);
  for (let i = 8; i < groesse - 8; i += 1) {
    const bit = i % 2 === 0 ? 1 : 0;
    feld[6][i] = bit;
    feld[i][6] = bit;
  }
  // Die Plätze von Format und Fassung freihalten, damit die Daten sie meiden.
  for (let i = 0; i < 9; i += 1) {
    if (feld[8][i] === null) feld[8][i] = 0;
    if (feld[i][8] === null) feld[i][8] = 0;
  }
  for (let i = 0; i < 8; i += 1) {
    if (feld[8][groesse - 1 - i] === null) feld[8][groesse - 1 - i] = 0;
    if (feld[groesse - 1 - i][8] === null) feld[groesse - 1 - i][8] = 0;
  }
  feld[groesse - 8][8] = 1;
  if (fassung >= 7) {
    for (let i = 0; i < 18; i += 1) {
      const zeile = Math.floor(i / 3);
      const spalte = i % 3;
      feld[groesse - 11 + spalte][zeile] = 0;
      feld[zeile][groesse - 11 + spalte] = 0;
    }
  }
  return feld;
}

/** Die Datenbits im Zickzack von rechts unten nach oben einlegen. */
function datenLegen(geruest, stellen, fuellbits) {
  const groesse = geruest.length;
  const belegt = geruest.map((zeile) => zeile.map((wert) => wert !== null));
  const feld = geruest.map((zeile) => zeile.slice());
  const bits = [];
  for (const stelle of stellen) for (let i = 7; i >= 0; i -= 1) bits.push((stelle >> i) & 1);
  for (let i = 0; i < fuellbits; i += 1) bits.push(0);

  let stelle = 0;
  let aufwaerts = true;
  for (let spalte = groesse - 1; spalte > 0; spalte -= 2) {
    if (spalte === 6) spalte -= 1; // die senkrechte Taktreihe wird übersprungen
    for (let schritt = 0; schritt < groesse; schritt += 1) {
      const zeile = aufwaerts ? groesse - 1 - schritt : schritt;
      for (const versatz of [0, 1]) {
        const x = spalte - versatz;
        if (belegt[zeile][x]) continue;
        feld[zeile][x] = stelle < bits.length ? bits[stelle] : 0;
        stelle += 1;
      }
    }
    aufwaerts = !aufwaerts;
  }
  return { feld, belegt };
}

function maskeAnwenden(feld, belegt, maske) {
  const fn = MASKEN[maske];
  return feld.map((zeile, r) => zeile.map((wert, c) => (belegt[r][c] ? wert : (fn(r, c) ? wert ^ 1 : wert))));
}

/** Die vier Strafregeln des Standards — je weniger Strafpunkte, desto lesbarer. */
function strafe(feld) {
  const n = feld.length;
  let summe = 0;

  const reihe = (holen) => {
    for (let a = 0; a < n; a += 1) {
      let laufend = 1;
      for (let b = 1; b < n; b += 1) {
        if (holen(a, b) === holen(a, b - 1)) {
          laufend += 1;
        } else {
          if (laufend >= 5) summe += 3 + (laufend - 5);
          laufend = 1;
        }
      }
      if (laufend >= 5) summe += 3 + (laufend - 5);
    }
  };
  reihe((a, b) => feld[a][b]);
  reihe((a, b) => feld[b][a]);

  for (let r = 0; r < n - 1; r += 1) {
    for (let c = 0; c < n - 1; c += 1) {
      const wert = feld[r][c];
      if (wert === feld[r][c + 1] && wert === feld[r + 1][c] && wert === feld[r + 1][c + 1]) summe += 3;
    }
  }

  const muster1 = [1, 0, 1, 1, 1, 0, 1, 0, 0, 0, 0];
  const muster2 = [0, 0, 0, 0, 1, 0, 1, 1, 1, 0, 1];
  const passt = (holen, a, b, muster) => {
    for (let i = 0; i < 11; i += 1) if (holen(a, b + i) !== muster[i]) return false;
    return true;
  };
  for (let a = 0; a < n; a += 1) {
    for (let b = 0; b + 11 <= n; b += 1) {
      if (passt((y, x) => feld[y][x], a, b, muster1) || passt((y, x) => feld[y][x], a, b, muster2)) summe += 40;
      if (passt((y, x) => feld[x][y], a, b, muster1) || passt((y, x) => feld[x][y], a, b, muster2)) summe += 40;
    }
  }

  let dunkel = 0;
  for (const zeile of feld) for (const wert of zeile) dunkel += wert;
  const anteil = (dunkel * 100) / (n * n);
  summe += Math.floor(Math.abs(anteil - 50) / 5) * 10;
  return summe;
}

/**
 * Der fertige Code als Feld aus 0 und 1.
 * Wirft, wenn der Text für Fassung 10 zu lang ist.
 */
export function qrFeld(text, { stufe = 'M', maske = null } = {}) {
  const bytes = inBytes(text);
  const fassung = passendeFassung(bytes.length, stufe);
  if (!fassung) throw new Error('Text zu lang für einen QR-Code dieser Größe');
  const stellen = verschraenken(stellenBauen(bytes, fassung, stufe), fassung, stufe);
  const geruest = grundgeruest(fassung);
  const { feld, belegt } = datenLegen(geruest, stellen, FUELLBITS[fassung]);

  const bauen = (nummer) => {
    const versuch = maskeAnwenden(feld, belegt, nummer);
    formatSetzen(versuch, stufe, nummer);
    versionSetzen(versuch, fassung);
    return versuch;
  };
  // `maske` erzwingt eine bestimmte Maske — das braucht nur die Gegenprobe in
  // scripts/qr-pruefen.py. Im Betrieb sucht die App die beste selbst.
  if (maske !== null) return bauen(maske);

  let bestes = null;
  let besteStrafe = Infinity;
  for (let nummer = 0; nummer < 8; nummer += 1) {
    const versuch = bauen(nummer);
    const punkte = strafe(versuch);
    if (punkte < besteStrafe) { besteStrafe = punkte; bestes = versuch; }
  }
  return bestes;
}

/**
 * Der Code als SVG. `rand` ist die stille Zone in Modulen — vier ist das
 * Mindestmaß des Standards; darunter finden manche Kameras den Code nicht.
 */
export function qrSvg(text, { stufe = 'M', rand = 4, dunkel = '#0f172a', hell = '#ffffff' } = {}) {
  const feld = qrFeld(text, { stufe });
  const n = feld.length;
  const gesamt = n + rand * 2;
  const svg = s('svg', {
    class: 'qr',
    viewBox: `0 0 ${gesamt} ${gesamt}`,
    'shape-rendering': 'crispEdges',
    role: 'img',
    'aria-label': 'QR-Code zum Beitreten',
  });
  svg.appendChild(s('rect', { x: 0, y: 0, width: gesamt, height: gesamt, fill: hell }));
  // Je Zeile ein Pfad aus waagrechten Strichen — das ist deutlich weniger
  // Knoten als ein Rechteck je Modul und zeichnet auf einem alten iPad spürbar
  // schneller.
  let pfad = '';
  for (let r = 0; r < n; r += 1) {
    let c = 0;
    while (c < n) {
      if (!feld[r][c]) { c += 1; continue; }
      let breite = 0;
      while (c + breite < n && feld[r][c + breite]) breite += 1;
      pfad += `M${c + rand} ${r + rand}h${breite}v1h-${breite}z`;
      c += breite;
    }
  }
  svg.appendChild(s('path', { d: pfad, fill: dunkel }));
  return svg;
}
