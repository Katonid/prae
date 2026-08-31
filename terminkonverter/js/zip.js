// Lesen von ZIP-Dateien (und damit von .xlsx) ohne fremde Bibliothek.
//
// Entpackt wird mit DecompressionStream('deflate-raw'), wo der Browser es
// mitbringt; sonst mit dem eigenen Inflate weiter unten. Der Rückfall ist
// kein Luxus: Ohne ihn bliebe die App auf älteren Geräten stumm, und ein
// Tabellenblatt ist klein genug, dass die eigene Rechnung nicht auffällt.

const LAENGE_BASIS = [3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31,
  35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258];
const LAENGE_EXTRA = [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3,
  3, 4, 4, 4, 4, 5, 5, 5, 5, 0];
const ABSTAND_BASIS = [1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129,
  193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289,
  16385, 24577];
const ABSTAND_EXTRA = [0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8,
  8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13];
const CODE_ORDNUNG = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15];

function huffman(laengen) {
  const anzahl = new Array(16).fill(0);
  for (const l of laengen) anzahl[l]++;
  anzahl[0] = 0;
  const versatz = new Array(16).fill(0);
  for (let i = 1; i < 15; i++) versatz[i + 1] = versatz[i] + anzahl[i];
  const symbole = new Array(laengen.length).fill(0);
  for (let s = 0; s < laengen.length; s++) {
    if (laengen[s]) symbole[versatz[laengen[s]]++] = s;
  }
  return { anzahl, symbole };
}

// Roher DEFLATE-Strom (ohne zlib-Kopf), wie er im ZIP steht.
export function inflateRoh(daten) {
  let bitPos = 0;
  let aus = new Uint8Array(Math.max(1024, daten.length * 4));
  let ende = 0;

  const platz = (n) => {
    if (ende + n <= aus.length) return;
    let groesse = aus.length * 2;
    while (groesse < ende + n) groesse *= 2;
    const neu = new Uint8Array(groesse);
    neu.set(aus.subarray(0, ende));
    aus = neu;
  };
  const bits = (n) => {
    let wert = 0;
    for (let i = 0; i < n; i++) {
      const byte = daten[bitPos >> 3];
      if (byte === undefined) throw new Error('Die Datei bricht mitten im Datenstrom ab.');
      wert |= ((byte >> (bitPos & 7)) & 1) << i;
      bitPos++;
    }
    return wert;
  };
  const symbol = (baum) => {
    let code = 0, erster = 0, index = 0;
    for (let laenge = 1; laenge <= 15; laenge++) {
      code |= bits(1);
      const anzahl = baum.anzahl[laenge];
      if (code - erster < anzahl) return baum.symbole[index + (code - erster)];
      index += anzahl;
      erster = (erster + anzahl) << 1;
      code <<= 1;
    }
    throw new Error('Der gepackte Datenstrom ist beschädigt.');
  };

  let festLiteral = null, festAbstand = null;
  let letzter = 0;
  do {
    letzter = bits(1);
    const art = bits(2);
    if (art === 0) {
      bitPos = (bitPos + 7) & ~7;
      const p = bitPos >> 3;
      const laenge = daten[p] | (daten[p + 1] << 8);
      bitPos = (p + 4) << 3;
      platz(laenge);
      aus.set(daten.subarray(p + 4, p + 4 + laenge), ende);
      ende += laenge;
      bitPos += laenge << 3;
      continue;
    }
    let literal, abstand;
    if (art === 1) {
      if (!festLiteral) {
        const l = new Array(288);
        for (let i = 0; i < 288; i++) l[i] = i < 144 ? 8 : i < 256 ? 9 : i < 280 ? 7 : 8;
        festLiteral = huffman(l);
        festAbstand = huffman(new Array(30).fill(5));
      }
      literal = festLiteral;
      abstand = festAbstand;
    } else if (art === 2) {
      const anzLiteral = bits(5) + 257;
      const anzAbstand = bits(5) + 1;
      const anzCode = bits(4) + 4;
      const codeLaengen = new Array(19).fill(0);
      for (let i = 0; i < anzCode; i++) codeLaengen[CODE_ORDNUNG[i]] = bits(3);
      const codeBaum = huffman(codeLaengen);
      const laengen = new Array(anzLiteral + anzAbstand).fill(0);
      let i = 0;
      while (i < laengen.length) {
        const s = symbol(codeBaum);
        if (s < 16) laengen[i++] = s;
        else if (s === 16) {
          const vorher = laengen[i - 1];
          let n = 3 + bits(2);
          while (n--) laengen[i++] = vorher;
        } else if (s === 17) {
          let n = 3 + bits(3);
          while (n--) laengen[i++] = 0;
        } else {
          let n = 11 + bits(7);
          while (n--) laengen[i++] = 0;
        }
      }
      literal = huffman(laengen.slice(0, anzLiteral));
      abstand = huffman(laengen.slice(anzLiteral));
    } else {
      throw new Error('Unbekannte Blockart im gepackten Datenstrom.');
    }

    for (;;) {
      const s = symbol(literal);
      if (s < 256) {
        platz(1);
        aus[ende++] = s;
      } else if (s === 256) {
        break;
      } else {
        const li = s - 257;
        const laenge = LAENGE_BASIS[li] + bits(LAENGE_EXTRA[li]);
        const ai = symbol(abstand);
        const weite = ABSTAND_BASIS[ai] + bits(ABSTAND_EXTRA[ai]);
        platz(laenge);
        let von = ende - weite;
        for (let n = 0; n < laenge; n++) aus[ende++] = aus[von++];
      }
    }
  } while (!letzter);

  return aus.subarray(0, ende);
}

async function entpacke(daten) {
  if (typeof DecompressionStream === 'function') {
    try {
      const strom = new Blob([daten]).stream()
        .pipeThrough(new DecompressionStream('deflate-raw'));
      return new Uint8Array(await new Response(strom).arrayBuffer());
    } catch (fehler) {
      // Weiter mit dem eigenen Inflate — lieber langsam als gar nicht.
    }
  }
  return inflateRoh(daten);
}

// Liest ein ZIP-Archiv und gibt eine Map „Pfad → Uint8Array" zurück.
export async function zipLesen(puffer) {
  const daten = new Uint8Array(puffer);
  const sicht = new DataView(daten.buffer, daten.byteOffset, daten.byteLength);

  let eocd = -1;
  for (let i = daten.length - 22; i >= 0 && i > daten.length - 65558; i--) {
    if (sicht.getUint32(i, true) === 0x06054b50) { eocd = i; break; }
  }
  if (eocd < 0) throw new Error('Das ist keine .xlsx-Datei (kein ZIP-Verzeichnis gefunden).');

  const anzahl = sicht.getUint16(eocd + 10, true);
  let zeiger = sicht.getUint32(eocd + 16, true);
  if (zeiger === 0xffffffff) throw new Error('Die Datei nutzt ZIP64 — bitte in Excel neu speichern.');

  const dateien = new Map();
  const text = new TextDecoder('utf-8');
  for (let n = 0; n < anzahl; n++) {
    if (sicht.getUint32(zeiger, true) !== 0x02014b50) break;
    const methode = sicht.getUint16(zeiger + 10, true);
    const gepackt = sicht.getUint32(zeiger + 20, true);
    const nameLaenge = sicht.getUint16(zeiger + 28, true);
    const extraLaenge = sicht.getUint16(zeiger + 30, true);
    const kommentarLaenge = sicht.getUint16(zeiger + 32, true);
    const versatz = sicht.getUint32(zeiger + 42, true);
    const name = text.decode(daten.subarray(zeiger + 46, zeiger + 46 + nameLaenge));
    zeiger += 46 + nameLaenge + extraLaenge + kommentarLaenge;

    if (name.endsWith('/')) continue;
    const lokalName = sicht.getUint16(versatz + 26, true);
    const lokalExtra = sicht.getUint16(versatz + 28, true);
    const start = versatz + 30 + lokalName + lokalExtra;
    const roh = daten.subarray(start, start + gepackt);
    if (methode === 0) dateien.set(name, roh.slice());
    else if (methode === 8) dateien.set(name, await entpacke(roh));
    else throw new Error(`Unbekanntes Packverfahren in „${name}".`);
  }
  return dateien;
}
