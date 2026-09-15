// Entpacken von zlib- und roh-DEFLATE-Strömen.
//
// In einer PDF-Datei steckt fast jeder Inhalt hinter /FlateDecode, also in
// einem zlib-Strom. Entpackt wird mit DecompressionStream, wo der Browser es
// mitbringt, sonst mit dem eigenen Inflate darunter — denselben Rückfall hat
// der Terminkonverter, und aus demselben Grund: Ohne ihn bleibt die App auf
// älteren Geräten stumm, statt eine Seite anzuzeigen.

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

// Ein zlib-Strom trägt zwei Byte Kopf und vier Byte Prüfsumme; roher DEFLATE
// trägt nichts davon. Erkannt wird der Kopf an seiner Prüfregel.
function istZlib(daten) {
  if (daten.length < 2) return false;
  const kopf = (daten[0] << 8) | daten[1];
  return (daten[0] & 0x0f) === 8 && kopf % 31 === 0;
}

export async function entpacke(daten) {
  const zlib = istZlib(daten);
  if (typeof DecompressionStream === 'function') {
    try {
      const strom = new Blob([daten]).stream()
        .pipeThrough(new DecompressionStream(zlib ? 'deflate' : 'deflate-raw'));
      return new Uint8Array(await new Response(strom).arrayBuffer());
    } catch (fehler) {
      // Weiter mit dem eigenen Inflate. Das passiert auch bei einem Strom, der
      // ohne ordentlichen Abschluss endet — davon gibt es in freier Wildbahn
      // mehr, als einem lieb ist, und der eigene Inflate nimmt sie hin.
    }
  }
  return inflateRoh(zlib ? daten.subarray(2) : daten);
}
