// Liest den Aufbau einer PDF-Datei: Objekte, Ströme, Seitenbaum.
//
// Eine PDF ist keine Textdatei, sondern eine Sammlung nummerierter Objekte mit
// einem Verzeichnis am Ende. Dieses Verzeichnis wird hier ABSICHTLICH nicht
// gelesen: Es ist die Stelle, die in freier Wildbahn am häufigsten kaputt ist
// (abgeschnittene Downloads, Werkzeuge, die falsche Stellen schreiben), und
// eine PDF mit falschem Verzeichnis öffnet jeder Betrachter trotzdem. Statt
// dessen wird die ganze Datei nach „N G obj" durchsucht. Das ist ein Zug durch
// den Speicher — bei zehn Megabyte ein Wimpernschlag, dafür ohne Fehlerquelle.

import { entpacke } from './inflate.js';

const LEER = new Set([0x00, 0x09, 0x0a, 0x0c, 0x0d, 0x20]);
const TRENNER = new Set([0x28, 0x29, 0x3c, 0x3e, 0x5b, 0x5d, 0x7b, 0x7d, 0x2f, 0x25]);

const istLeer = (b) => LEER.has(b);
const istTrenner = (b) => TRENNER.has(b);
const istZeichen = (b) => !istLeer(b) && !istTrenner(b);

// Ein Name wie /Type oder /Adobe#20Deutsch — die Raute maskiert ein Byte.
function nameLesen(daten, pos) {
  let text = '';
  while (pos < daten.length && istZeichen(daten[pos])) {
    if (daten[pos] === 0x23 && pos + 2 < daten.length) {
      const wert = parseInt(String.fromCharCode(daten[pos + 1], daten[pos + 2]), 16);
      if (Number.isFinite(wert)) {
        text += String.fromCharCode(wert);
        pos += 3;
        continue;
      }
    }
    text += String.fromCharCode(daten[pos]);
    pos++;
  }
  return { wert: text, pos };
}

// (Klammertext) — Klammern dürfen verschachtelt sein, der Rückstrich maskiert.
function textLesen(daten, pos) {
  const aus = [];
  let tiefe = 1;
  pos++;
  while (pos < daten.length) {
    const b = daten[pos];
    if (b === 0x5c) {
      pos++;
      const z = daten[pos];
      if (z === undefined) break;
      const einfach = { 0x6e: 10, 0x72: 13, 0x74: 9, 0x62: 8, 0x66: 12 };
      if (einfach[z] !== undefined) { aus.push(einfach[z]); pos++; }
      else if (z >= 0x30 && z <= 0x37) {
        let ziffern = '';
        while (ziffern.length < 3 && daten[pos] >= 0x30 && daten[pos] <= 0x37) {
          ziffern += String.fromCharCode(daten[pos]);
          pos++;
        }
        aus.push(parseInt(ziffern, 8) & 0xff);
      } else if (z === 0x0a) pos++;
      else if (z === 0x0d) { pos++; if (daten[pos] === 0x0a) pos++; }
      else { aus.push(z); pos++; }
      continue;
    }
    if (b === 0x28) tiefe++;
    if (b === 0x29) {
      tiefe--;
      if (tiefe === 0) { pos++; break; }
    }
    aus.push(b);
    pos++;
  }
  return { wert: Uint8Array.from(aus), pos };
}

function hexLesen(daten, pos) {
  const aus = [];
  let ziffern = '';
  pos++;
  while (pos < daten.length && daten[pos] !== 0x3e) {
    const z = String.fromCharCode(daten[pos]);
    if (/[0-9a-fA-F]/.test(z)) {
      ziffern += z;
      if (ziffern.length === 2) { aus.push(parseInt(ziffern, 16)); ziffern = ''; }
    }
    pos++;
  }
  if (ziffern.length === 1) aus.push(parseInt(ziffern + '0', 16));
  return { wert: Uint8Array.from(aus), pos: pos + 1 };
}

function ueberspringe(daten, pos) {
  while (pos < daten.length) {
    if (istLeer(daten[pos])) { pos++; continue; }
    if (daten[pos] === 0x25) {                       // Kommentar bis Zeilenende
      while (pos < daten.length && daten[pos] !== 0x0a && daten[pos] !== 0x0d) pos++;
      continue;
    }
    break;
  }
  return pos;
}

// Liest EIN Objekt ab `pos`. Namen kommen als JS-Zeichenkette zurück,
// Textstücke als Uint8Array — daran sind die beiden zu unterscheiden.
export function objektLesen(daten, pos) {
  pos = ueberspringe(daten, pos);
  if (pos >= daten.length) return { wert: null, pos };
  const b = daten[pos];

  if (b === 0x2f) return nameLesen(daten, pos + 1);
  if (b === 0x28) return textLesen(daten, pos);
  if (b === 0x3c && daten[pos + 1] === 0x3c) {
    const woerterbuch = {};
    pos += 2;
    for (;;) {
      pos = ueberspringe(daten, pos);
      if (pos >= daten.length) break;
      if (daten[pos] === 0x3e && daten[pos + 1] === 0x3e) { pos += 2; break; }
      if (daten[pos] !== 0x2f) {                      // etwas Unerwartetes: weiter
        const notfall = objektLesen(daten, pos);
        if (notfall.pos <= pos) { pos++; continue; }
        pos = notfall.pos;
        continue;
      }
      const schluessel = nameLesen(daten, pos + 1);
      const wert = objektLesen(daten, schluessel.pos);
      woerterbuch[schluessel.wert] = wert.wert;
      pos = wert.pos;
    }
    return { wert: woerterbuch, pos, istWoerterbuch: true };
  }
  if (b === 0x3c) return hexLesen(daten, pos);
  if (b === 0x5b) {
    const liste = [];
    pos++;
    for (;;) {
      pos = ueberspringe(daten, pos);
      if (pos >= daten.length) break;
      if (daten[pos] === 0x5d) { pos++; break; }
      const wert = objektLesen(daten, pos);
      if (wert.pos <= pos) { pos++; continue; }
      liste.push(wert.wert);
      pos = wert.pos;
    }
    return { wert: liste, pos };
  }
  if (b === 0x5d || b === 0x3e || b === 0x29 || b === 0x7b || b === 0x7d) {
    return { wert: null, pos: pos + 1 };
  }

  // Zahl, Verweis oder Schlüsselwort
  let text = '';
  while (pos < daten.length && istZeichen(daten[pos])) {
    text += String.fromCharCode(daten[pos]);
    pos++;
  }
  if (text === '') return { wert: null, pos: pos + 1 };
  if (text === 'true') return { wert: true, pos };
  if (text === 'false') return { wert: false, pos };
  if (text === 'null') return { wert: null, pos };

  const zahl = Number(text);
  if (/^[-+.\d]/.test(text) && Number.isFinite(zahl)) {
    // Steht dahinter „G R", ist es ein Verweis auf ein anderes Objekt.
    if (Number.isInteger(zahl) && zahl >= 0) {
      const merk = pos;
      const zweite = ueberspringe(daten, pos);
      let zahl2 = '';
      let p = zweite;
      while (p < daten.length && istZeichen(daten[p])) { zahl2 += String.fromCharCode(daten[p]); p++; }
      if (/^\d+$/.test(zahl2)) {
        const dritte = ueberspringe(daten, p);
        if (daten[dritte] === 0x52 && !istZeichen(daten[dritte + 1])) {
          return { wert: { verweis: zahl }, pos: dritte + 1 };
        }
      }
      pos = merk;
    }
    return { wert: zahl, pos };
  }
  return { wert: { wort: text }, pos };
}

// ---------------------------------------------------------------- Stromfilter

function vorhersageAufloesen(daten, parameter) {
  const art = parameter.Predictor || 1;
  if (art <= 1) return daten;
  const spalten = parameter.Columns || 1;
  const farben = parameter.Colors || 1;
  const tiefe = parameter.BitsPerComponent || 8;
  const breiteByte = Math.ceil((farben * tiefe) / 8);
  const zeilenbreite = Math.ceil((spalten * farben * tiefe) / 8);

  if (art === 2) {                                   // TIFF
    if (tiefe !== 8) return daten;
    for (let z = 0; z + zeilenbreite <= daten.length; z += zeilenbreite) {
      for (let i = breiteByte; i < zeilenbreite; i++) {
        daten[z + i] = (daten[z + i] + daten[z + i - breiteByte]) & 0xff;
      }
    }
    return daten;
  }

  // PNG: jede Zeile trägt ihre Art als erstes Byte.
  const aus = new Uint8Array(Math.floor(daten.length / (zeilenbreite + 1)) * zeilenbreite);
  let vorher = new Uint8Array(zeilenbreite);
  let ziel = 0;
  for (let q = 0; q + 1 <= daten.length; q += zeilenbreite + 1) {
    const typ = daten[q];
    const zeile = daten.subarray(q + 1, q + 1 + zeilenbreite);
    if (!zeile.length) break;
    const jetzt = new Uint8Array(zeilenbreite);
    for (let i = 0; i < zeile.length; i++) {
      const roh = zeile[i];
      const links = i >= breiteByte ? jetzt[i - breiteByte] : 0;
      const oben = vorher[i];
      const schraeg = i >= breiteByte ? vorher[i - breiteByte] : 0;
      let wert;
      if (typ === 0) wert = roh;
      else if (typ === 1) wert = roh + links;
      else if (typ === 2) wert = roh + oben;
      else if (typ === 3) wert = roh + ((links + oben) >> 1);
      else if (typ === 4) {
        const p = links + oben - schraeg;
        const pa = Math.abs(p - links);
        const pb = Math.abs(p - oben);
        const pc = Math.abs(p - schraeg);
        wert = roh + (pa <= pb && pa <= pc ? links : pb <= pc ? oben : schraeg);
      } else wert = roh;
      jetzt[i] = wert & 0xff;
    }
    if (ziel + zeilenbreite <= aus.length) aus.set(jetzt, ziel);
    ziel += zeilenbreite;
    vorher = jetzt;
  }
  return aus.subarray(0, Math.min(ziel, aus.length));
}

function hexEntpacken(daten) {
  const aus = [];
  let ziffern = '';
  for (const b of daten) {
    const z = String.fromCharCode(b);
    if (z === '>') break;
    if (!/[0-9a-fA-F]/.test(z)) continue;
    ziffern += z;
    if (ziffern.length === 2) { aus.push(parseInt(ziffern, 16)); ziffern = ''; }
  }
  if (ziffern.length === 1) aus.push(parseInt(ziffern + '0', 16));
  return Uint8Array.from(aus);
}

function ascii85Entpacken(daten) {
  const aus = [];
  let gruppe = [];
  for (let i = 0; i < daten.length; i++) {
    const b = daten[i];
    if (b === 0x7e) break;                            // ~> beendet
    if (istLeer(b)) continue;
    if (b === 0x7a && gruppe.length === 0) { aus.push(0, 0, 0, 0); continue; }
    if (b < 0x21 || b > 0x75) continue;
    gruppe.push(b - 0x21);
    if (gruppe.length === 5) {
      let wert = 0;
      for (const z of gruppe) wert = wert * 85 + z;
      aus.push((wert >>> 24) & 0xff, (wert >>> 16) & 0xff, (wert >>> 8) & 0xff, wert & 0xff);
      gruppe = [];
    }
  }
  if (gruppe.length > 1) {
    const fehlt = 5 - gruppe.length;
    for (let i = 0; i < fehlt; i++) gruppe.push(84);
    let wert = 0;
    for (const z of gruppe) wert = wert * 85 + z;
    const voll = [(wert >>> 24) & 0xff, (wert >>> 16) & 0xff, (wert >>> 8) & 0xff, wert & 0xff];
    for (let i = 0; i < 4 - fehlt; i++) aus.push(voll[i]);
  }
  return Uint8Array.from(aus);
}

function laufEntpacken(daten) {
  const aus = [];
  let i = 0;
  while (i < daten.length) {
    const laenge = daten[i++];
    if (laenge === 128) break;
    if (laenge < 128) {
      for (let n = 0; n <= laenge; n++) aus.push(daten[i++]);
    } else {
      const byte = daten[i++];
      for (let n = 0; n < 257 - laenge; n++) aus.push(byte);
    }
  }
  return Uint8Array.from(aus);
}

// LZW, wie es ältere Erzeuger benutzen. Der Code wächst von 9 auf 12 Bit.
function lzwEntpacken(daten, frueh = 1) {
  const aus = [];
  let woerter = [];
  const zuruecksetzen = () => {
    woerter = [];
    for (let i = 0; i < 256; i++) woerter[i] = [i];
    woerter.length = 258;
  };
  zuruecksetzen();
  let breite = 9;
  let vorher = null;
  let puffer = 0;
  let bits = 0;
  for (let i = 0; i < daten.length; i++) {
    puffer = (puffer << 8) | daten[i];
    bits += 8;
    while (bits >= breite) {
      const code = (puffer >> (bits - breite)) & ((1 << breite) - 1);
      bits -= breite;
      if (code === 256) { zuruecksetzen(); breite = 9; vorher = null; continue; }
      if (code === 257) return Uint8Array.from(aus);
      let eintrag;
      if (woerter[code]) eintrag = woerter[code];
      else if (vorher) eintrag = [...vorher, vorher[0]];
      else continue;
      aus.push(...eintrag);
      if (vorher) woerter.push([...vorher, eintrag[0]]);
      vorher = eintrag;
      const grenze = woerter.length + frueh;
      if (grenze >= 512 && breite === 9) breite = 10;
      else if (grenze >= 1024 && breite === 10) breite = 11;
      else if (grenze >= 2048 && breite === 11) breite = 12;
    }
  }
  return Uint8Array.from(aus);
}

// Filter, hinter denen ein BILD steckt — deren Inhalt braucht diese App nie.
export const BILDFILTER = new Set(['DCTDecode', 'JPXDecode', 'JBIG2Decode', 'CCITTFaxDecode']);

// ------------------------------------------------------------------ Dokument

const koder = new TextDecoder('latin1');

function suche(daten, muster, ab = 0) {
  const erstes = muster[0];
  for (let i = ab; i <= daten.length - muster.length; i++) {
    if (daten[i] !== erstes) continue;
    let passt = true;
    for (let j = 1; j < muster.length; j++) {
      if (daten[i + j] !== muster[j]) { passt = false; break; }
    }
    if (passt) return i;
  }
  return -1;
}

function alleStellen(daten, text) {
  const muster = Uint8Array.from(text, (z) => z.charCodeAt(0));
  const gefunden = [];
  let ab = 0;
  for (;;) {
    const stelle = suche(daten, muster, ab);
    if (stelle < 0) break;
    gefunden.push(stelle);
    ab = stelle + muster.length;
  }
  return gefunden;
}

export class Dokument {
  constructor(daten) {
    this.daten = daten;
    this.stellen = new Map();       // Objektnummer → Stelle in der Datei
    this.imStrom = new Map();       // Objektnummer → { strom, index }
    this.zwischen = new Map();      // schon gelesene Objekte
    this.verschluesselt = false;
  }

  // „12 0 obj" in der ganzen Datei suchen. Eine spätere Fassung desselben
  // Objekts (PDFs werden fortgeschrieben) überschreibt die frühere — deshalb
  // gewinnt die HINTERSTE Stelle.
  objekteSuchen() {
    const daten = this.daten;
    for (let i = 0; i + 2 < daten.length; i++) {
      if (daten[i] !== 0x6f || daten[i + 1] !== 0x62 || daten[i + 2] !== 0x6a) continue;
      if (istZeichen(daten[i + 3])) continue;
      let p = i - 1;
      while (p >= 0 && istLeer(daten[p])) p--;
      let erzeugung = '';
      while (p >= 0 && daten[p] >= 0x30 && daten[p] <= 0x39) { erzeugung = String.fromCharCode(daten[p]) + erzeugung; p--; }
      if (!erzeugung) continue;
      while (p >= 0 && istLeer(daten[p])) p--;
      let nummer = '';
      while (p >= 0 && daten[p] >= 0x30 && daten[p] <= 0x39) { nummer = String.fromCharCode(daten[p]) + nummer; p--; }
      if (!nummer) continue;
      if (p >= 0 && istZeichen(daten[p])) continue;
      this.stellen.set(Number(nummer), i + 3);
    }
  }

  // Zu welchem Objekt gehört eine Stelle in der Datei?
  objektAn(stelle) {
    if (!this.sortiert) {
      this.sortiert = [...this.stellen.entries()].sort((a, b) => a[1] - b[1]);
    }
    let links = 0;
    let rechts = this.sortiert.length - 1;
    let treffer = -1;
    while (links <= rechts) {
      const mitte = (links + rechts) >> 1;
      if (this.sortiert[mitte][1] <= stelle) { treffer = mitte; links = mitte + 1; }
      else rechts = mitte - 1;
    }
    return treffer < 0 ? null : this.sortiert[treffer][0];
  }

  rohObjekt(nummer) {
    const stelle = this.stellen.get(nummer);
    if (stelle === undefined) return null;
    const { wert, pos } = objektLesen(this.daten, stelle);
    if (wert && typeof wert === 'object' && !Array.isArray(wert) && !(wert instanceof Uint8Array)
        && !('verweis' in wert) && !('wort' in wert)) {
      const nach = ueberspringe(this.daten, pos);
      if (this.daten[nach] === 0x73 && koder.decode(this.daten.subarray(nach, nach + 6)) === 'stream') {
        let anfang = nach + 6;
        if (this.daten[anfang] === 0x0d) anfang++;
        if (this.daten[anfang] === 0x0a) anfang++;
        return { woerterbuch: wert, stromAb: anfang };
      }
    }
    return { wert };
  }

  hole(wert, tiefe = 0) {
    if (wert && typeof wert === 'object' && 'verweis' in wert && tiefe < 32) {
      return this.hole(this.objekt(wert.verweis), tiefe + 1);
    }
    return wert;
  }

  objekt(nummer) {
    if (this.zwischen.has(nummer)) return this.zwischen.get(nummer);
    this.zwischen.set(nummer, null);                   // gegen Ringverweise
    let ergebnis = null;
    const imStrom = this.imStrom.get(nummer);
    if (imStrom) {
      ergebnis = imStrom.wert;
    } else {
      const roh = this.rohObjekt(nummer);
      if (roh && roh.woerterbuch) ergebnis = { strom: roh.woerterbuch, ab: roh.stromAb, nummer };
      else if (roh) ergebnis = roh.wert;
    }
    this.zwischen.set(nummer, ergebnis);
    return ergebnis;
  }

  // Die rohen Bytes eines Stroms — Länge laut Wörterbuch, geprüft an
  // „endstream". Eine falsche /Length ist häufig; das Schlüsselwort nicht.
  rohStrom(strom) {
    const laenge = this.hole(strom.strom.Length);
    const ende = suche(this.daten, Uint8Array.from('endstream', (z) => z.charCodeAt(0)), strom.ab);
    let bis = -1;
    if (typeof laenge === 'number' && laenge >= 0 && strom.ab + laenge <= this.daten.length) {
      const nach = ueberspringe(this.daten, strom.ab + laenge);
      if (koder.decode(this.daten.subarray(nach, nach + 9)) === 'endstream') bis = strom.ab + laenge;
    }
    if (bis < 0) {
      if (ende < 0) return new Uint8Array(0);
      bis = ende;
      while (bis > strom.ab && (this.daten[bis - 1] === 0x0a || this.daten[bis - 1] === 0x0d)) bis--;
    }
    return this.daten.subarray(strom.ab, bis);
  }

  async stromDaten(strom) {
    if (strom.daten) return strom.daten;
    let daten = this.rohStrom(strom);
    const filter = this.hole(strom.strom.Filter);
    const filterliste = filter === undefined || filter === null ? []
      : Array.isArray(filter) ? filter.map((f) => this.hole(f)) : [filter];
    let parameter = this.hole(strom.strom.DecodeParms) || this.hole(strom.strom.DP) || {};
    const parameterliste = Array.isArray(parameter) ? parameter : [parameter];

    for (let i = 0; i < filterliste.length; i++) {
      const name = filterliste[i];
      const teil = this.hole(parameterliste[i]) || (filterliste.length === 1 ? this.hole(parameterliste[0]) : null) || {};
      const aufgeloest = {};
      for (const [k, v] of Object.entries(teil)) aufgeloest[k] = this.hole(v);
      if (BILDFILTER.has(name)) { strom.bild = true; return new Uint8Array(0); }
      if (name === 'FlateDecode' || name === 'Fl') {
        daten = await entpacke(daten);
        daten = vorhersageAufloesen(daten, aufgeloest);
      } else if (name === 'LZWDecode' || name === 'LZW') {
        daten = lzwEntpacken(daten, aufgeloest.EarlyChange === 0 ? 0 : 1);
        daten = vorhersageAufloesen(daten, aufgeloest);
      } else if (name === 'ASCIIHexDecode' || name === 'AHx') daten = hexEntpacken(daten);
      else if (name === 'ASCII85Decode' || name === 'A85') daten = ascii85Entpacken(daten);
      else if (name === 'RunLengthDecode' || name === 'RL') daten = laufEntpacken(daten);
    }
    strom.daten = daten;
    return daten;
  }

  // Objektströme auspacken: Seit PDF 1.5 stecken Seiten, Schriften und der
  // Katalog meist in einem gepackten Sammelstrom statt einzeln in der Datei.
  async objektstroemeLesen() {
    const stellen = alleStellen(this.daten, '/ObjStm');
    const nummern = new Set();
    for (const stelle of stellen) {
      const nummer = this.objektAn(stelle);
      if (nummer !== null) nummern.add(nummer);
    }
    for (const nummer of nummern) {
      const strom = this.objekt(nummer);
      if (!strom || !strom.strom || this.hole(strom.strom.Type) !== 'ObjStm') continue;
      let daten;
      try {
        daten = await this.stromDaten(strom);
      } catch (fehler) {
        continue;                                      // ein kaputter Sammelstrom
      }
      const anzahl = this.hole(strom.strom.N) || 0;
      const erstes = this.hole(strom.strom.First) || 0;
      let pos = 0;
      const paare = [];
      for (let i = 0; i < anzahl; i++) {
        const a = objektLesen(daten, pos);
        const b = objektLesen(daten, a.pos);
        if (typeof a.wert !== 'number' || typeof b.wert !== 'number') break;
        paare.push([a.wert, b.wert]);
        pos = b.pos;
      }
      for (const [objektnummer, versatz] of paare) {
        if (this.stellen.has(objektnummer)) continue;  // eine direkte Fassung gewinnt
        const { wert } = objektLesen(daten, erstes + versatz);
        this.imStrom.set(objektnummer, { wert });
      }
    }
  }

  wurzelFinden() {
    for (const stelle of alleStellen(this.daten, '/Root').reverse()) {
      const { wert } = objektLesen(this.daten, stelle + 5);
      const wurzel = this.hole(wert);
      if (wurzel && wurzel.Pages !== undefined) return wurzel;
    }
    for (const stelle of alleStellen(this.daten, '/Catalog').reverse()) {
      const nummer = this.objektAn(stelle);
      if (nummer === null) continue;
      const wurzel = this.hole(this.objekt(nummer));
      if (wurzel && wurzel.Pages !== undefined) return wurzel;
    }
    for (const nummer of [...this.imStrom.keys()]) {
      const wert = this.hole(this.objekt(nummer));
      if (wert && wert.Type === 'Catalog' && wert.Pages !== undefined) return wert;
    }
    return null;
  }

  // Seiten in der Reihenfolge des Baums. Ohne Baum: alle Objekte vom Typ
  // /Page nach Nummer — besser eine Seite in zweifelhafter Reihenfolge als
  // gar keine.
  seiten() {
    const gefunden = [];
    const wurzel = this.wurzelFinden();
    const gesehen = new Set();
    const geerbt = ['Resources', 'MediaBox', 'CropBox', 'Rotate'];

    const gehe = (knotenWert, erbe, tiefe) => {
      const knoten = this.hole(knotenWert);
      if (!knoten || typeof knoten !== 'object' || tiefe > 64) return;
      const nummer = knotenWert && knotenWert.verweis;
      if (nummer !== undefined) {
        if (gesehen.has(nummer)) return;
        gesehen.add(nummer);
      }
      const eigen = { ...erbe };
      for (const schluessel of geerbt) {
        if (knoten[schluessel] !== undefined) eigen[schluessel] = knoten[schluessel];
      }
      const kinder = this.hole(knoten.Kids);
      if (Array.isArray(kinder)) {
        for (const kind of kinder) gehe(kind, eigen, tiefe + 1);
        return;
      }
      if (knoten.Type === 'Page' || knoten.Contents !== undefined) {
        gefunden.push({ ...eigen, ...knoten });
      }
    };

    if (wurzel) gehe(wurzel.Pages, {}, 0);
    if (gefunden.length) return gefunden;

    const nummern = [...new Set([...this.stellen.keys(), ...this.imStrom.keys()])].sort((a, b) => a - b);
    for (const nummer of nummern) {
      const wert = this.hole(this.objekt(nummer));
      if (wert && !Array.isArray(wert) && wert.Type === 'Page') gefunden.push(wert);
    }
    return gefunden;
  }
}

export async function pdfLesen(puffer) {
  const daten = new Uint8Array(puffer);
  const kopf = koder.decode(daten.subarray(0, Math.min(1024, daten.length)));
  if (!kopf.includes('%PDF-')) {
    throw new Error('Das ist keine PDF-Datei — der Kopf „%PDF-" fehlt.');
  }
  const dokument = new Dokument(daten);
  dokument.objekteSuchen();
  if (!dokument.stellen.size) {
    throw new Error('In der Datei steht kein einziges PDF-Objekt. Vermutlich ist sie unvollständig heruntergeladen.');
  }

  // Verschlüsselt? Dann steht im Anhang ein /Encrypt, und jeder Textstrom ist
  // unlesbar. Das wird gemeldet und nicht geraten.
  for (const stelle of alleStellen(daten, '/Encrypt')) {
    const { wert } = objektLesen(daten, stelle + 8);
    if (wert !== null && wert !== undefined) { dokument.verschluesselt = true; break; }
  }
  await dokument.objektstroemeLesen();
  return dokument;
}
