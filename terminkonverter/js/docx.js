// Liest die Tabellen eines Word-Dokuments (.docx).
//
// Der Fließtext drumherum bleibt liegen: Wer Termine in Tabellen notiert,
// hat davor und dazwischen Überschriften, Vorbemerkungen und Fußzeilen — die
// alle als „übergangene Zeile" zu melden, wäre lauter Lärm. Nur wenn das
// Dokument überhaupt keine Tabelle enthält, werden die Absätze angesehen.

import { zipLesen } from './zip.js';
import { entziffere, alsText } from './xml.js';

// Ein Wort-Dokument nennt seine Marken „w:tbl", „w:tr", „w:tc" — die Vorsilbe
// steht aber nicht fest, deshalb wird sie beim Vergleichen abgeschnitten.
const ohneVorsilbe = (name) => name.slice(name.indexOf(':') + 1);

function zellenText(stuecke) {
  return stuecke.join('').replace(/\s+/g, ' ').trim();
}

// Läuft einmal durch das XML und sammelt die Zeilen aller Tabellen. Eine
// verschachtelte Tabelle wird dabei zu eigenen Zeilen — ihr Text landet nicht
// zusätzlich in der Zelle, die sie enthält.
function tabellenZeilen(xml) {
  const tabellen = [];
  const stapel = [];
  let zeile = null;
  let zelle = null;
  let inText = false;
  let tabellenNummer = 0;
  let zeilenNummer = 0;

  const marken = /<(\/?)([\w.-]+(?::[\w.-]+)?)([^>]*?)(\/?)>|([^<]+)/g;
  let treffer;
  while ((treffer = marken.exec(xml)) !== null) {
    const [, schluss, name, , leer, text] = treffer;
    if (text !== undefined) {
      if (inText && zelle) zelle.push(entziffere(text));
      continue;
    }
    const marke = ohneVorsilbe(name);

    if (leer) {
      // Tabulator und Zeilenumbruch trennen Wörter, sonst klebt alles.
      if (zelle && (marke === 'tab' || marke === 'br')) zelle.push(' ');
      continue;
    }

    if (!schluss) {
      if (marke === 'tbl') {
        tabellenNummer++;
        zeilenNummer = 0;
        stapel.push({ tabelle: tabellenNummer, zeile, zelle, inText });
        zeile = null;
        zelle = null;
        inText = false;
      } else if (marke === 'tr' && stapel.length) {
        zeilenNummer++;
        zeile = { tabelle: stapel[stapel.length - 1].tabelle, nummer: zeilenNummer, zellen: [] };
      } else if (marke === 'tc' && zeile) {
        zelle = [];
      } else if (marke === 't' && zelle) {
        inText = true;
      } else if (marke === 'p' && zelle) {
        zelle.push(' ');
      }
      continue;
    }

    if (marke === 't') inText = false;
    else if (marke === 'tc' && zeile && zelle) {
      const wert = zellenText(zelle);
      zeile.zellen.push(wert ? { art: 'text', text: wert } : null);
      zelle = null;
    } else if (marke === 'tr' && zeile) {
      if (zeile.zellen.some(Boolean)) tabellen.push(zeile);
      zeile = null;
    } else if (marke === 'tbl') {
      const vorher = stapel.pop();
      if (vorher) {
        zeile = vorher.zeile;
        zelle = vorher.zelle;
        inText = vorher.inText;
        zeilenNummer = zeile ? zeile.nummer : 0;
      }
    }
  }
  return tabellen;
}

// Nur für Dokumente ganz ohne Tabelle: jeder Absatz wird eine Zeile.
function absatzZeilen(xml) {
  const zeilen = [];
  for (const absatz of xml.matchAll(/<(?:\w+:)?p\b[^>]*>([\s\S]*?)<\/(?:\w+:)?p>/g)) {
    let text = '';
    for (const t of absatz[1].matchAll(/<(?:\w+:)?t\b[^>]*>([\s\S]*?)<\/(?:\w+:)?t>/g)) {
      text += entziffere(t[1]);
    }
    text = text.replace(/\s+/g, ' ').trim();
    if (text) zeilen.push({ nummer: zeilen.length + 1, zellen: [{ art: 'text', text }] });
  }
  return zeilen;
}

export async function docxLesen(puffer) {
  const dateien = await zipLesen(puffer);
  const xml = alsText(dateien, 'word/document.xml');
  if (!xml) throw new Error('In der Datei ist kein Word-Text zu finden.');

  const ausTabellen = tabellenZeilen(xml);
  if (ausTabellen.length) {
    // Nach der Reihenfolge der Zeilen durchnummerieren: Eine verschachtelte
    // Tabelle ist fertig, bevor die Zeile fertig ist, die sie enthält —
    // ohne das stünde in der Herkunftsspalte 4.1 vor 3.1.
    const nummern = new Map();
    for (const zeile of ausTabellen) {
      if (!nummern.has(zeile.tabelle)) nummern.set(zeile.tabelle, nummern.size + 1);
      zeile.tabelle = nummern.get(zeile.tabelle);
    }
    return { zeilen: ausTabellen, quelle: 'tabellen' };
  }
  return { zeilen: absatzZeilen(xml), quelle: 'absaetze' };
}
