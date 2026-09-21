// Von Byte zu Buchstabe.
//
// Ein PDF speichert keinen Text, sondern Zeichennummern für eine bestimmte
// Schrift. Welcher Buchstabe dahintersteckt, sagen drei Quellen, in dieser
// Reihenfolge: die Tabelle /ToUnicode (wenn vorhanden, immer die beste), die
// Kodierung samt /Differences, und zuletzt die Annahme, es sei WinAnsi.
//
// Ohne diesen Schritt wird aus „für" je nach Schrift „f¸r" oder Buchstabensalat
// aus Zeichennummern — und das fällt erst auf, wenn der Text in den Notizen
// steht.

import { standardbreiten } from './schriftmasse.js';

// Namen von Zeichen, wie sie in /Differences stehen. Buchstaben und Ziffern
// heißen wie sie sind; aufgeführt wird nur, was anders heißt.
const NAMEN = {
  space: 32, exclam: 33, quotedbl: 34, numbersign: 35, dollar: 36, percent: 37,
  ampersand: 38, quotesingle: 39, quoteright: 0x2019, parenleft: 40, parenright: 41,
  asterisk: 42, plus: 43, comma: 44, hyphen: 45, period: 46, slash: 47,
  zero: 48, one: 49, two: 50, three: 51, four: 52, five: 53, six: 54, seven: 55,
  eight: 56, nine: 57, colon: 58, semicolon: 59, less: 60, equal: 61, greater: 62,
  question: 63, at: 64, bracketleft: 91, backslash: 92, bracketright: 93,
  asciicircum: 94, underscore: 95, grave: 96, quoteleft: 0x2018, braceleft: 123,
  bar: 124, braceright: 125, asciitilde: 126,
  exclamdown: 161, cent: 162, sterling: 163, currency: 164, yen: 165, brokenbar: 166,
  section: 167, dieresis: 168, copyright: 169, ordfeminine: 170, guillemotleft: 171,
  logicalnot: 172, registered: 174, macron: 175, degree: 176, plusminus: 177,
  acute: 180, mu: 181, paragraph: 182, periodcentered: 183, cedilla: 184,
  ordmasculine: 186, guillemotright: 187, onequarter: 188, onehalf: 189,
  threequarters: 190, questiondown: 191, multiply: 215, divide: 247,
  germandbls: 223, sharps: 223, eth: 240, thorn: 254, Eth: 208, Thorn: 222,
  AE: 198, ae: 230, Oslash: 216, oslash: 248, Lslash: 0x141, lslash: 0x142,
  OE: 0x152, oe: 0x153, Scaron: 0x160, scaron: 0x161, Zcaron: 0x17d, zcaron: 0x17e,
  Ydieresis: 376, florin: 0x192, circumflex: 0x2c6, tilde: 0x2dc,
  endash: 0x2013, emdash: 0x2014, quotedblleft: 0x201c, quotedblright: 0x201d,
  quotedblbase: 0x201e, quotesinglbase: 0x201a, dagger: 0x2020, daggerdbl: 0x2021,
  bullet: 0x2022, ellipsis: 0x2026, perthousand: 0x2030, guilsinglleft: 0x2039,
  guilsinglright: 0x203a, fraction: 0x2044, Euro: 0x20ac, trademark: 0x2122,
  minus: 0x2212, fi: 0xfb01, fl: 0xfb02, ffi: 0xfb03, ffl: 0xfb04, ff: 0xfb00,
  nbspace: 32,
};

// Buchstaben mit Zeichen darüber heißen „Grundbuchstabe + Name des Zeichens".
const ZUSATZ = {
  acute: { a: 225, e: 233, i: 237, o: 243, u: 250, y: 253, n: 0x144, c: 0x107, s: 0x15b, z: 0x17a,
           A: 193, E: 201, I: 205, O: 211, U: 218, Y: 221, N: 0x143, C: 0x106, S: 0x15a, Z: 0x179 },
  grave: { a: 224, e: 232, i: 236, o: 242, u: 249, A: 192, E: 200, I: 204, O: 210, U: 217 },
  circumflex: { a: 226, e: 234, i: 238, o: 244, u: 251, A: 194, E: 202, I: 206, O: 212, U: 219 },
  tilde: { a: 227, n: 241, o: 245, A: 195, N: 209, O: 213 },
  dieresis: { a: 228, e: 235, i: 239, o: 246, u: 252, y: 255, A: 196, E: 203, I: 207, O: 214, U: 220, Y: 376 },
  ring: { a: 229, A: 197, u: 0x16f, U: 0x16e },
  cedilla: { c: 231, C: 199, s: 0x15f, S: 0x15e, t: 0x163, T: 0x162 },
  caron: { c: 0x10d, s: 0x161, z: 0x17e, e: 0x11b, r: 0x159, d: 0x10f, t: 0x165, n: 0x148,
           C: 0x10c, S: 0x160, Z: 0x17d, E: 0x11a, R: 0x158, D: 0x10e, T: 0x164, N: 0x147 },
  breve: { a: 0x103, g: 0x11f, A: 0x102, G: 0x11e },
  ogonek: { a: 0x105, e: 0x119, A: 0x104, E: 0x118 },
  dotaccent: { z: 0x17c, Z: 0x17b },
  macron: { a: 0x101, e: 0x113, i: 0x12b, o: 0x14d, u: 0x16b },
};

export function nameZuZeichen(name) {
  if (!name) return null;
  if (name.length === 1) return name.codePointAt(0);
  if (Object.prototype.hasOwnProperty.call(NAMEN, name)) return NAMEN[name];
  let treffer = /^uni([0-9A-Fa-f]{4})/.exec(name);
  if (treffer) return parseInt(treffer[1], 16);
  treffer = /^u([0-9A-Fa-f]{4,6})$/.exec(name);
  if (treffer) return parseInt(treffer[1], 16);
  for (const [zusatz, tabelle] of Object.entries(ZUSATZ)) {
    if (name.length === 1 + zusatz.length && name.endsWith(zusatz)) {
      const grund = name[0];
      if (tabelle[grund]) return tabelle[grund];
    }
  }
  // „g23" oder „cid45" nennen nur eine Nummer in der Schrift — daraus lässt
  // sich kein Buchstabe ableiten.
  return null;
}

// Die oberen 128 Plätze der drei üblichen Kodierungen. Unten sind sie bis auf
// zwei Anführungszeichen gleich.
const WINANSI_OBEN = [
  0x20ac, 0x81, 0x201a, 0x192, 0x201e, 0x2026, 0x2020, 0x2021, 0x2c6, 0x2030,
  0x160, 0x2039, 0x152, 0x8d, 0x17d, 0x8f, 0x90, 0x2018, 0x2019, 0x201c,
  0x201d, 0x2022, 0x2013, 0x2014, 0x2dc, 0x2122, 0x161, 0x203a, 0x153, 0x9d,
  0x17e, 0x178,
];
const MACROMAN_OBEN = [
  196, 197, 199, 201, 209, 214, 220, 225, 224, 226, 228, 227, 229, 231, 233, 232,
  234, 235, 237, 236, 238, 239, 241, 243, 242, 244, 246, 245, 250, 249, 251, 252,
  0x2020, 176, 162, 163, 167, 0x2022, 182, 223, 174, 169, 0x2122, 180, 168, 0x2260,
  198, 216, 0x221e, 177, 0x2264, 0x2265, 165, 181, 0x2202, 0x2211, 0x220f, 0x3c0,
  0x222b, 170, 186, 0x3a9, 230, 248, 0xbf, 0xa1, 0xac, 0x221a, 0x192, 0x2248,
  0x2206, 171, 187, 0x2026, 32, 192, 195, 213, 0x152, 0x153, 0x2013, 0x2014,
  0x201c, 0x201d, 0x2018, 0x2019, 247, 0x25ca, 255, 0x178, 0x2044, 0x20ac,
  0x2039, 0x203a, 0xfb01, 0xfb02, 0x2021, 183, 0x201a, 0x201e, 0x2030, 194,
  202, 193, 203, 200, 205, 206, 207, 204, 211, 212, 0xf8ff, 210, 218, 219,
  217, 305, 0x2c6, 0x2dc, 175, 0x2d8, 0x2d9, 0x2da, 184, 0x2dd, 0x2db, 0x2c7,
];

function grundtabelle(name) {
  const tabelle = new Array(256).fill(0);
  for (let i = 32; i < 127; i++) tabelle[i] = i;
  if (name === 'MacRomanEncoding') {
    for (let i = 0; i < MACROMAN_OBEN.length; i++) tabelle[128 + i] = MACROMAN_OBEN[i];
    return tabelle;
  }
  if (name === 'StandardEncoding') {
    tabelle[39] = 0x2019;                              // quoteright
    tabelle[96] = 0x2018;                              // quoteleft
    return tabelle;
  }
  for (let i = 0; i < WINANSI_OBEN.length; i++) tabelle[128 + i] = WINANSI_OBEN[i];
  for (let i = 160; i < 256; i++) tabelle[i] = i;      // deckt sich mit Latin-1
  tabelle[173] = 0x2d;                                 // weicher Trennstrich
  return tabelle;
}

// ---------------------------------------------------------------- ToUnicode

function ausHex(text) {
  const sauber = text.replace(/[^0-9a-fA-F]/g, '');
  let aus = '';
  for (let i = 0; i + 4 <= sauber.length; i += 4) {
    aus += String.fromCharCode(parseInt(sauber.slice(i, i + 4), 16));
  }
  if (sauber.length % 4 === 2) aus += String.fromCharCode(parseInt(sauber.slice(-2), 16));
  return aus;
}

// Der Text steht als UTF-16BE in der Tabelle — auch Ligaturen (zwei Buchstaben
// für ein Zeichen), deshalb wird eine ZEICHENKETTE abgelegt und kein einzelner
// Codepunkt.
export function toUnicodeLesen(text) {
  const karte = new Map();
  let codeLaenge = 0;

  const bereich = /begincodespacerange([\s\S]*?)endcodespacerange/g;
  let treffer;
  while ((treffer = bereich.exec(text)) !== null) {
    const paare = treffer[1].match(/<([0-9a-fA-F]+)>/g) || [];
    if (paare.length) codeLaenge = Math.max(codeLaenge, Math.ceil((paare[0].length - 2) / 2));
  }

  const zeichenBlock = /beginbfchar([\s\S]*?)endbfchar/g;
  while ((treffer = zeichenBlock.exec(text)) !== null) {
    const zeile = /<([0-9a-fA-F]+)>\s*(?:<([0-9a-fA-F]*)>|\/(\S+))/g;
    let t2;
    while ((t2 = zeile.exec(treffer[1])) !== null) {
      const code = parseInt(t2[1], 16);
      if (!codeLaenge) codeLaenge = Math.ceil(t2[1].length / 2);
      if (t2[2] !== undefined) karte.set(code, ausHex(t2[2]));
      else {
        const punkt = nameZuZeichen(t2[3]);
        if (punkt) karte.set(code, String.fromCodePoint(punkt));
      }
    }
  }

  const bereichBlock = /beginbfrange([\s\S]*?)endbfrange/g;
  while ((treffer = bereichBlock.exec(text)) !== null) {
    const zeile = /<([0-9a-fA-F]+)>\s*<([0-9a-fA-F]+)>\s*(?:<([0-9a-fA-F]*)>|\[([\s\S]*?)\])/g;
    let t2;
    while ((t2 = zeile.exec(treffer[1])) !== null) {
      const von = parseInt(t2[1], 16);
      const bis = parseInt(t2[2], 16);
      if (!codeLaenge) codeLaenge = Math.ceil(t2[1].length / 2);
      if (bis < von || bis - von > 65535) continue;
      if (t2[3] !== undefined) {
        const text16 = ausHex(t2[3]);
        if (!text16) continue;
        // Nur das LETZTE Zeichen zählt hoch — davor kann eine Ligatur stehen.
        const vorn = text16.slice(0, -1);
        const letztes = text16.charCodeAt(text16.length - 1);
        for (let code = von; code <= bis; code++) {
          karte.set(code, vorn + String.fromCharCode(letztes + (code - von)));
        }
      } else {
        const stuecke = t2[4].match(/<[0-9a-fA-F]*>/g) || [];
        stuecke.forEach((stueck, i) => karte.set(von + i, ausHex(stueck.slice(1, -1))));
      }
    }
  }
  return { karte, codeLaenge: codeLaenge || 1 };
}

// ------------------------------------------------------------------ Schrift

export class Schrift {
  constructor() {
    this.zweiByte = false;
    this.karte = null;            // aus /ToUnicode
    this.tabelle = grundtabelle('WinAnsiEncoding');
    this.breiten = new Map();
    this.standardbreite = 500;
  }

  // Zerlegt eine Zeichenkette in Codes — ein oder zwei Byte je Zeichen.
  * codes(bytes) {
    if (this.zweiByte) {
      for (let i = 0; i + 1 < bytes.length; i += 2) yield (bytes[i] << 8) | bytes[i + 1];
      if (bytes.length % 2) yield bytes[bytes.length - 1];
      return;
    }
    for (const byte of bytes) yield byte;
  }

  zuText(code) {
    if (this.karte) {
      const treffer = this.karte.get(code);
      if (treffer !== undefined) return treffer;
      if (this.zweiByte) return '';                    // lieber nichts als Krempel
    }
    const punkt = this.tabelle[code & 0xff];
    if (!punkt) return '';
    return String.fromCodePoint(punkt);
  }

  breite(code) {
    const wert = this.breiten.get(code);
    return (wert === undefined ? this.standardbreite : wert) / 1000;
  }
}

// Baut aus dem Schrift-Wörterbuch einer Seite ein benutzbares Objekt.
export async function schriftLesen(dokument, woerterbuch) {
  const schrift = new Schrift();
  const hole = (w) => dokument.hole(w);
  const art = hole(woerterbuch.Subtype);

  let breitenQuelle = woerterbuch;
  if (art === 'Type0') {
    schrift.zweiByte = true;
    schrift.standardbreite = 1000;
    const nachkommen = hole(woerterbuch.DescendantFonts);
    const kind = Array.isArray(nachkommen) ? hole(nachkommen[0]) : null;
    if (kind) {
      breitenQuelle = kind;
      const dw = hole(kind.DW);
      if (typeof dw === 'number') schrift.standardbreite = dw;
      const w = hole(kind.W);
      if (Array.isArray(w)) {
        for (let i = 0; i < w.length;) {
          const erstes = hole(w[i]);
          const zweites = hole(w[i + 1]);
          if (Array.isArray(zweites)) {
            zweites.forEach((breite, n) => schrift.breiten.set(erstes + n, hole(breite)));
            i += 2;
          } else {
            const breite = hole(w[i + 2]);
            if (typeof zweites === 'number' && typeof breite === 'number') {
              const bis = Math.min(zweites, erstes + 65535);
              for (let code = erstes; code <= bis; code++) schrift.breiten.set(code, breite);
            }
            i += 3;
          }
        }
      }
    }
  } else {
    const erstes = hole(woerterbuch.FirstChar);
    const breiten = hole(woerterbuch.Widths);
    if (Array.isArray(breiten) && typeof erstes === 'number') {
      breiten.forEach((breite, i) => {
        const wert = hole(breite);
        if (typeof wert === 'number') schrift.breiten.set(erstes + i, wert);
      });
    }
    // Eine der 14 Standardschriften MUSS kein /Widths mitbringen — jedes
    // PDF-Programm kennt ihre Maße, und diese App jetzt auch. Vorher galt
    // hier für jedes Zeichen 500/1000: Das „i" so breit wie das „m", und
    // damit standen Leerzeichen, Zeilenenden und Absatzgrenzen schief.
    if (!schrift.breiten.size) {
      const gemessen = standardbreiten(hole(woerterbuch.BaseFont));
      if (gemessen) {
        for (let code = 32; code < 256; code++) {
          if (gemessen[code]) schrift.breiten.set(code, gemessen[code]);
        }
      }
    }
    const kodierung = hole(woerterbuch.Encoding);
    if (typeof kodierung === 'string') schrift.tabelle = grundtabelle(kodierung);
    else if (kodierung && typeof kodierung === 'object') {
      const grund = hole(kodierung.BaseEncoding);
      schrift.tabelle = grundtabelle(typeof grund === 'string' ? grund : 'StandardEncoding');
      const unterschiede = hole(kodierung.Differences);
      if (Array.isArray(unterschiede)) {
        let code = 0;
        for (const eintrag of unterschiede) {
          const wert = hole(eintrag);
          if (typeof wert === 'number') code = wert;
          else if (typeof wert === 'string') {
            const punkt = nameZuZeichen(wert);
            if (punkt) schrift.tabelle[code & 0xff] = punkt;
            code++;
          }
        }
      }
    }
  }

  const beschreibung = hole(breitenQuelle.FontDescriptor);
  if (beschreibung && !schrift.breiten.size) {
    const fehlend = hole(beschreibung.MissingWidth);
    if (typeof fehlend === 'number') schrift.standardbreite = fehlend;
  }

  const zuUnicode = hole(woerterbuch.ToUnicode);
  if (zuUnicode && zuUnicode.strom) {
    try {
      const daten = await dokument.stromDaten(zuUnicode);
      const { karte, codeLaenge } = toUnicodeLesen(new TextDecoder('latin1').decode(daten));
      if (karte.size) {
        schrift.karte = karte;
        if (codeLaenge >= 2) schrift.zweiByte = true;
      }
    } catch (fehler) {
      // Ohne Tabelle bleibt die Kodierung — besser als gar kein Text.
    }
  }
  return schrift;
}
