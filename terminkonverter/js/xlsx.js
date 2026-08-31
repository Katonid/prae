// Liest ein Excel-Blatt (.xlsx) zu Zeilen aus Zellen.
//
// Eine Zelle kommt als { art, text, zahl } heraus. Ob eine Zahl ein Datum
// meint, steht in .xlsx nicht am Wert, sondern am ZAHLENFORMAT — deshalb
// wird styles.xml mitgelesen. Ohne das wäre der 31.08.2026 einfach 46265.

import { zipLesen } from './zip.js';

const DATUM_FORMATE = new Set([14, 15, 16, 17, 18, 19, 20, 21, 22, 27, 28, 29,
  30, 31, 32, 33, 34, 35, 36, 45, 46, 47, 50, 51, 52, 53, 54, 55, 56, 57, 58]);

function entziffere(text) {
  return text.replace(/&(#x?[0-9a-fA-F]+|amp|lt|gt|quot|apos);/g, (ganz, kern) => {
    if (kern === 'amp') return '&';
    if (kern === 'lt') return '<';
    if (kern === 'gt') return '>';
    if (kern === 'quot') return '"';
    if (kern === 'apos') return "'";
    const nummer = kern[1] === 'x' || kern[1] === 'X'
      ? parseInt(kern.slice(2), 16)
      : parseInt(kern.slice(1), 10);
    return Number.isFinite(nummer) ? String.fromCodePoint(nummer) : ganz;
  });
}

function alsText(dateien, pfad) {
  const daten = dateien.get(pfad);
  return daten ? new TextDecoder('utf-8').decode(daten) : null;
}

// Ein eigenes Zahlenformat gilt als Datum, wenn darin Tag, Monat oder Jahr
// vorkommt — außerhalb von Anführungszeichen und eckigen Klammern ([rot],
// [h]:mm) und ohne die Farb- und Bedingungsteile.
function formatIstDatum(format) {
  let inText = false, inKlammer = false;
  for (let i = 0; i < format.length; i++) {
    const z = format[i];
    if (inText) { if (z === '"') inText = false; continue; }
    if (inKlammer) { if (z === ']') inKlammer = false; continue; }
    if (z === '"') { inText = true; continue; }
    if (z === '[') { inKlammer = true; continue; }
    if (z === '\\') { i++; continue; }
    if ('dmyhsDMYHS'.includes(z)) return true;
  }
  return false;
}

function spalteZuIndex(bezug) {
  let index = 0;
  for (const z of bezug) {
    const code = z.charCodeAt(0);
    if (code >= 65 && code <= 90) index = index * 26 + (code - 64);
    else if (code >= 97 && code <= 122) index = index * 26 + (code - 96);
    else break;
  }
  return index - 1;
}

function sharedStrings(xml) {
  if (!xml) return [];
  const liste = [];
  for (const treffer of xml.matchAll(/<si\b[^>]*>([\s\S]*?)<\/si>/g)) {
    let stueck = '';
    for (const t of treffer[1].matchAll(/<t\b[^>]*>([\s\S]*?)<\/t>/g)) stueck += entziffere(t[1]);
    liste.push(stueck);
  }
  return liste;
}

function stilFormate(xml) {
  const formate = new Map();
  if (!xml) return { stile: [], eigene: formate };
  for (const t of xml.matchAll(/<numFmt\b[^>]*numFmtId="(\d+)"[^>]*formatCode="([^"]*)"/g)) {
    formate.set(Number(t[1]), entziffere(t[2]));
  }
  const block = xml.match(/<cellXfs\b[^>]*>([\s\S]*?)<\/cellXfs>/);
  const stile = [];
  if (block) {
    for (const xf of block[1].matchAll(/<xf\b[^>]*>/g)) {
      const id = xf[0].match(/numFmtId="(\d+)"/);
      stile.push(id ? Number(id[1]) : 0);
    }
  }
  return { stile, eigene: formate };
}

function blattPfad(dateien) {
  const workbook = alsText(dateien, 'xl/workbook.xml');
  const rels = alsText(dateien, 'xl/_rels/workbook.xml.rels');
  if (workbook && rels) {
    const erstes = workbook.match(/<sheet\b[^>]*>/);
    const id = erstes && erstes[0].match(/r:id="([^"]+)"/);
    if (id) {
      const bezug = rels.match(new RegExp(`<Relationship\\b[^>]*Id="${id[1]}"[^>]*>`));
      const ziel = bezug && bezug[0].match(/Target="([^"]+)"/);
      if (ziel) {
        const pfad = ziel[1].replace(/^\/xl\//, '').replace(/^\.\//, '');
        if (dateien.has('xl/' + pfad)) return 'xl/' + pfad;
        if (dateien.has(pfad)) return pfad;
      }
    }
  }
  for (const name of dateien.keys()) {
    if (/^xl\/worksheets\/[^/]+\.xml$/.test(name)) return name;
  }
  return null;
}

// Excel zählt Tage ab dem 30.12.1899 (bzw. ab 1904 auf altem Mac-Excel).
export function serieZuDatum(serie, ab1904 = false) {
  const tage = serie + (ab1904 ? 1462 : 0);
  // Auf die Minute gerundet: 10:30 kommt in .xlsx gern als 10:29:59,9 an,
  // und in einem Kalendereintrag zählen ohnehin nur Stunde und Minute.
  const ms = Math.round((tage - 25569) * 1440) * 60000;
  const d = new Date(ms);
  return {
    jahr: d.getUTCFullYear(),
    monat: d.getUTCMonth() + 1,
    tag: d.getUTCDate(),
    stunde: d.getUTCHours(),
    minute: d.getUTCMinutes(),
    hatZeit: Math.abs(tage - Math.floor(tage)) > 1e-9,
  };
}

export async function xlsxLesen(puffer) {
  const dateien = await zipLesen(puffer);
  const pfad = blattPfad(dateien);
  if (!pfad) throw new Error('In der Datei ist kein Tabellenblatt zu finden.');

  const workbook = alsText(dateien, 'xl/workbook.xml') || '';
  const ab1904 = /date1904="(1|true)"/.test(workbook);
  const texte = sharedStrings(alsText(dateien, 'xl/sharedStrings.xml'));
  const { stile, eigene } = stilFormate(alsText(dateien, 'xl/styles.xml'));
  const blatt = alsText(dateien, pfad);

  const zeilen = [];
  for (const zeile of blatt.matchAll(/<row\b([^>]*)\/>|<row\b([^>]*)>([\s\S]*?)<\/row>/g)) {
    const kopf = zeile[1] || zeile[2] || '';
    const inhalt = zeile[3] || '';
    const nummer = Number((kopf.match(/\br="(\d+)"/) || [])[1] || zeilen.length + 1);
    const zellen = [];
    let spalte = 0;
    for (const c of inhalt.matchAll(/<c\b([^>]*)\/>|<c\b([^>]*)>([\s\S]*?)<\/c>/g)) {
      const merkmale = c[1] || c[2] || '';
      const koerper = c[3] || '';
      const bezug = (merkmale.match(/\br="([A-Za-z]+)\d+"/) || [])[1];
      const index = bezug ? spalteZuIndex(bezug) : spalte;
      spalte = index + 1;
      const typ = (merkmale.match(/\bt="([^"]+)"/) || [])[1] || 'n';
      const stil = Number((merkmale.match(/\bs="(\d+)"/) || [])[1] || -1);

      let zelle = null;
      if (typ === 'inlineStr') {
        let stueck = '';
        for (const t of koerper.matchAll(/<t\b[^>]*>([\s\S]*?)<\/t>/g)) stueck += entziffere(t[1]);
        if (stueck.trim()) zelle = { art: 'text', text: stueck.trim() };
      } else {
        const wert = koerper.match(/<v\b[^>]*>([\s\S]*?)<\/v>/);
        const roh = wert ? entziffere(wert[1]) : '';
        if (roh !== '') {
          if (typ === 's') {
            const text = (texte[Number(roh)] || '').trim();
            if (text) zelle = { art: 'text', text };
          } else if (typ === 'str' || typ === 'e') {
            if (roh.trim()) zelle = { art: 'text', text: roh.trim() };
          } else if (typ === 'b') {
            zelle = { art: 'text', text: roh === '1' ? 'WAHR' : 'FALSCH' };
          } else {
            const zahl = Number(roh);
            if (Number.isFinite(zahl)) {
              const formatId = stil >= 0 && stil < stile.length ? stile[stil] : 0;
              const eigenes = eigene.get(formatId);
              const istDatum = eigenes ? formatIstDatum(eigenes) : DATUM_FORMATE.has(formatId);
              zelle = istDatum
                ? { art: 'datum', zahl, text: roh, datum: serieZuDatum(zahl, ab1904) }
                : { art: 'zahl', zahl, text: roh };
            }
          }
        }
      }
      if (zelle) zellen[index] = zelle;
    }
    if (zellen.some(Boolean)) {
      zeilen.push({ nummer, zellen: Array.from(zellen, (z) => z || null) });
    }
  }
  return zeilen;
}

// CSV wird gleich mitgenommen: Wer seine Termine als .csv exportiert, soll
// nicht erst nach Excel zurückmüssen. Semikolon, Komma und Tabulator werden
// erkannt; Zahlen bleiben Text und gehen durch die Textdatumsprüfung.
export function csvLesen(text) {
  const inhalt = text.replace(/^﻿/, '');
  const kopfzeile = inhalt.split(/\r?\n/)[0] || '';
  const trenner = [';', '\t', ','].map((z) => [z, kopfzeile.split(z).length])
    .sort((a, b) => b[1] - a[1])[0][0];

  const zeilen = [];
  let feld = '', zellen = [], inText = false;
  const zeileFertig = () => {
    zellen.push(feld);
    const gefuellt = zellen.map((w) => {
      const wert = w.trim();
      return wert ? { art: 'text', text: wert } : null;
    });
    if (gefuellt.some(Boolean)) zeilen.push({ nummer: zeilen.length + 1, zellen: gefuellt });
    feld = '';
    zellen = [];
  };
  for (let i = 0; i < inhalt.length; i++) {
    const z = inhalt[i];
    if (inText) {
      if (z === '"') {
        if (inhalt[i + 1] === '"') { feld += '"'; i++; } else inText = false;
      } else feld += z;
    } else if (z === '"') inText = true;
    else if (z === trenner) { zellen.push(feld); feld = ''; }
    else if (z === '\n') zeileFertig();
    else if (z !== '\r') feld += z;
  }
  if (feld || zellen.length) zeileFertig();
  return zeilen;
}
