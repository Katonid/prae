// Aus Absätzen wird eine PDF-Datei.
//
// Die Gegenrichtung zu js/pdf.js: Dort wird gelesen, hier gesetzt. Und
// gesetzt heißt hier wirklich setzen — ein PDF bricht keine Zeile um, es
// kennt nur „schreibe diese Zeichen an diese Stelle". Wo eine Zeile endet,
// entscheidet also diese Datei, und zwar gemessen (js/schriftmasse.js).
//
// GETRENNT WIRD NICHT. Die deutsche Silbentrennung ist nicht ableitbar —
// dieselbe Regel wie in der Wörterwerkstatt —, und eine falsche Trennung
// steht für immer im Dokument. Ohne Trennung aber reißt Blocksatz Löcher in
// die Zeilen, deshalb ist der Satz linksbündig. Das ist die ehrliche
// Reihenfolge: lieber ein flatternder rechter Rand als ein falsch
// getrenntes Wort.

import { familie, breite } from './schriftmasse.js';
import { nachWinAnsi } from './winansi.js';

// Ein Punkt ist 1/72 Zoll; ein Zentimeter also 28,35 Punkt.
const CM = 72 / 2.54;

export const PAPIERE = {
  a4: { name: 'A4', breite: 595.28, hoehe: 841.89 },
  a5: { name: 'A5 (halb so groß, gut zum Lesen)', breite: 419.53, hoehe: 595.28 },
  letter: { name: 'US Letter', breite: 612, hoehe: 792 },
};

export const RAENDER = {
  schmal: { name: 'schmal (1,5 cm)', mass: 1.5 * CM },
  normal: { name: 'normal (2 cm)', mass: 2 * CM },
  breit: { name: 'breit (3 cm)', mass: 3 * CM },
};

export const ABSTAENDE = {
  eng: { name: 'eng', mass: 1.2 },
  normal: { name: 'normal', mass: 1.45 },
  weit: { name: 'weit', mass: 1.8 },
};

// ------------------------------------------------------------ Bytes schreiben

class Schreiber {
  constructor() {
    this.stuecke = [];
    this.laenge = 0;
  }

  bytes(daten) {
    this.stuecke.push(daten);
    this.laenge += daten.length;
    return this;
  }

  // Alles, was an Steuertext in eine PDF geht, ist reines ASCII.
  text(zeichen) {
    const daten = new Uint8Array(zeichen.length);
    for (let i = 0; i < zeichen.length; i++) daten[i] = zeichen.charCodeAt(i) & 0xff;
    return this.bytes(daten);
  }

  fertig() {
    const aus = new Uint8Array(this.laenge);
    let stelle = 0;
    for (const stueck of this.stuecke) { aus.set(stueck, stelle); stelle += stueck.length; }
    return aus;
  }
}

// Eine Zeichenkette im Inhaltsstrom: Klammern und Gegenschrägstrich müssen
// maskiert werden, alles über 127 wird oktal geschrieben. Ein rohes Byte
// wäre erlaubt, aber ein einziges davon in einer Zeile, die ein Werkzeug
// später als Text behandelt, macht die Datei unlesbar.
function alsZeichenkette(bytes) {
  let aus = '(';
  for (const byte of bytes) {
    if (byte === 0x28 || byte === 0x29 || byte === 0x5c) aus += '\\' + String.fromCharCode(byte);
    else if (byte < 32 || byte > 126) aus += '\\' + byte.toString(8).padStart(3, '0');
    else aus += String.fromCharCode(byte);
  }
  return aus + ')';
}

// Titel und Verfasser stehen in den Dateiangaben, und die liest jedes
// Programm anders. UTF-16 mit Vorzeichen ist der Weg, der überall ankommt —
// ein Umlaut in WinAnsi wäre bei manchem Betrachter Buchstabensalat.
function alsTextangabe(zeichen) {
  let aus = '<FEFF';
  for (const z of String(zeichen)) {
    const nummer = z.codePointAt(0);
    if (nummer > 0xffff) {
      const rest = nummer - 0x10000;
      aus += (0xd800 + (rest >> 10)).toString(16).padStart(4, '0');
      aus += (0xdc00 + (rest & 0x3ff)).toString(16).padStart(4, '0');
    } else {
      aus += nummer.toString(16).padStart(4, '0');
    }
  }
  return (aus + '>').toUpperCase();
}

function zeitstempel(datum) {
  const zwei = (n) => String(n).padStart(2, '0');
  return `D:${datum.getUTCFullYear()}${zwei(datum.getUTCMonth() + 1)}${zwei(datum.getUTCDate())}`
    + `${zwei(datum.getUTCHours())}${zwei(datum.getUTCMinutes())}${zwei(datum.getUTCSeconds())}Z`;
}

// ------------------------------------------------------------------- Umbruch

// Ein Wort, das allein schon breiter ist als die Zeile (eine lange Adresse),
// wird hart zerlegt. Sonst liefe es über den Rand hinaus — und das ist der
// eine Fall, in dem Trennen ohne Regelwerk erlaubt ist: Es gibt keine
// Alternative außer Wegschneiden.
function hartTeilen(wort, schrift, groesse, platz) {
  const teile = [];
  let anfang = 0;
  while (anfang < wort.length) {
    let bis = anfang + 1;
    while (bis < wort.length && breite(wort.subarray(anfang, bis + 1), schrift, groesse) <= platz) bis++;
    teile.push(wort.subarray(anfang, bis));
    anfang = bis;
  }
  return teile;
}

function zeilenUmbrechen(bytes, schrift, groesse, platz) {
  const zeilen = [];
  const woerter = [];
  let anfang = 0;
  for (let i = 0; i <= bytes.length; i++) {
    if (i === bytes.length || bytes[i] === 0x20) {
      if (i > anfang) woerter.push(bytes.subarray(anfang, i));
      anfang = i + 1;
    }
  }
  if (!woerter.length) return [];

  let laufend = null;
  for (const wort of woerter) {
    if (breite(wort, schrift, groesse) > platz) {
      if (laufend) { zeilen.push(laufend); laufend = null; }
      for (const stueck of hartTeilen(wort, schrift, groesse, platz)) zeilen.push(stueck);
      continue;
    }
    const versuch = laufend ? verbinden(laufend, wort) : wort;
    if (breite(versuch, schrift, groesse) <= platz) {
      laufend = versuch;
    } else {
      zeilen.push(laufend);
      laufend = wort;
    }
  }
  if (laufend) zeilen.push(laufend);
  return zeilen;
}

function verbinden(links, rechts) {
  const aus = new Uint8Array(links.length + 1 + rechts.length);
  aus.set(links, 0);
  aus[links.length] = 0x20;
  aus.set(rechts, links.length + 1);
  return aus;
}

// --------------------------------------------------------------------- Satz

export function pdfBauen(bloecke, einstellungen = {}) {
  const schriften = familie(einstellungen.schrift);
  const papier = PAPIERE[einstellungen.papier] || PAPIERE.a4;
  const rand = (RAENDER[einstellungen.rand] || RAENDER.normal).mass;
  const abstand = (ABSTAENDE[einstellungen.zeilenabstand] || ABSTAENDE.normal).mass;
  const groesse = Math.min(30, Math.max(6, Number(einstellungen.groesse) || 12));
  const seitenzahlen = einstellungen.seitenzahlen !== false;
  const titel = (einstellungen.titel || '').trim();
  const verfasser = (einstellungen.verfasser || '').trim();
  const jetzt = einstellungen.jetzt || new Date();

  const platz = papier.breite - 2 * rand;
  const obenY = papier.hoehe - rand;
  // Unten bleibt Luft für die Seitenzahl; ohne sie klebt sie am Text.
  const untenY = rand + (seitenzahlen ? groesse * 1.8 : 0);

  const seiten = [];
  let aktuell = null;
  let y = 0;
  let ersetzt = 0;
  const unbekannt = new Set();
  const marken = [];                        // Überschriften für das Lesezeichen-Verzeichnis

  const neueSeite = () => {
    aktuell = [];
    seiten.push(aktuell);
    y = obenY;
  };
  neueSeite();

  const setze = (bytes, schrift, hoehe, x) => {
    aktuell.push({ bytes, schrift, groesse: hoehe, x, y: y - hoehe * 0.85 });
    y -= hoehe * abstand;
  };

  for (const block of bloecke) {
    const roh = String(block.text || '').replace(/\s+/g, ' ').trim();
    if (!roh) continue;
    const ueberschrift = Boolean(block.ueberschrift);
    const marke = Boolean(block.marke);
    const hoehe = ueberschrift
      ? groesse * ((block.ebene || 2) === 1 ? 1.5 : 1.22)
      : (marke ? groesse * 0.85 : groesse);
    const schrift = ueberschrift ? schriften.fett : schriften.normal;

    const gewandelt = nachWinAnsi(roh);
    ersetzt += gewandelt.ersetzt;
    for (const z of gewandelt.unbekannt) if (unbekannt.size < 12) unbekannt.add(z);

    const zeilen = zeilenUmbrechen(gewandelt.bytes, schrift, hoehe, platz);
    if (!zeilen.length) continue;

    // Luft davor — nur wenn oben schon etwas steht. Sonst rutschte die
    // erste Seite nach unten weg.
    const luftDavor = ueberschrift ? hoehe * 0.7 : 0;
    if (y < obenY) y -= luftDavor;

    // Eine Überschrift, unter die nichts mehr passt, gehört auf die nächste
    // Seite: Eine Kapitelzeile allein am Fuß ist ein Satzfehler, den jeder
    // sieht. Sie braucht deshalb Platz für sich UND für zwei Zeilen des
    // Absatzes darunter — den kennt die Schleife hier nicht, aber zwei
    // Zeilen sind sicher, denn ein leeres Kapitel gibt es nicht.
    const gebraucht = hoehe * abstand * zeilen.length
      + (ueberschrift ? groesse * abstand * 2 : 0);
    if (y - gebraucht < untenY && y < obenY) neueSeite();

    for (const zeile of zeilen) {
      if (y - hoehe * abstand < untenY) neueSeite();
      const x = marke ? rand + (platz - breite(zeile, schrift, hoehe)) / 2 : rand;
      if (ueberschrift && zeile === zeilen[0]) {
        marken.push({ titel: roh, seite: seiten.length - 1, y, ebene: block.ebene || 2 });
      }
      setze(zeile, schrift, hoehe, x);
    }
    y -= ueberschrift ? hoehe * 0.35 : groesse * 0.5;
  }

  return {
    daten: zusammensetzen(seiten, marken, {
      schriften, papier, groesse, seitenzahlen, titel, verfasser, jetzt, rand,
    }),
    seiten: seiten.length,
    ersetzt,
    unbekannt: [...unbekannt],
  };
}

// ------------------------------------------------------------- Datei bauen

function zusammensetzen(seiten, marken, o) {
  const { schriften, papier, groesse, seitenzahlen, titel, verfasser, jetzt, rand } = o;
  const schnitte = [schriften.normal, schriften.fett, schriften.kursiv, schriften.fettkursiv];

  // Feste Nummern zuerst, danach je Seite zwei Objekte und zuletzt die
  // Lesezeichen. Ein Verweis auf ein Objekt, das es nicht gibt, macht die
  // Datei unlesbar — deshalb wird hier gerechnet und nicht geraten.
  const ERSTES_FONT = 4;
  const ERSTE_SEITE = ERSTES_FONT + schnitte.length;
  const seiteNr = (i) => ERSTE_SEITE + i * 2;
  const inhaltNr = (i) => ERSTE_SEITE + i * 2 + 1;
  const ERSTE_MARKE = ERSTE_SEITE + seiten.length * 2;
  const WURZEL_MARKE = ERSTE_MARKE + marken.length;
  const gesamt = marken.length ? WURZEL_MARKE : ERSTE_MARKE - 1;

  const schreiber = new Schreiber();
  const stellen = new Array(gesamt + 1).fill(0);

  schreiber.text('%PDF-1.4\n');
  // Vier Bytes über 127: Daran erkennen Werkzeuge, dass die Datei binär ist
  // und nicht zeilenweise umgeschrieben werden darf.
  schreiber.bytes(Uint8Array.from([0x25, 0xe2, 0xe3, 0xcf, 0xd3, 0x0a]));

  const objekt = (nummer, inhalt) => {
    stellen[nummer] = schreiber.laenge;
    schreiber.text(`${nummer} 0 obj\n${inhalt}\nendobj\n`);
  };

  objekt(1, `<< /Type /Catalog /Pages 2 0 R /Lang (de-DE)`
    + `${marken.length ? ` /Outlines ${WURZEL_MARKE} 0 R /PageMode /UseOutlines` : ''} >>`);
  objekt(2, `<< /Type /Pages /Count ${seiten.length} /Kids [`
    + seiten.map((_, i) => `${seiteNr(i)} 0 R`).join(' ') + '] >>');
  objekt(3, '<< ' + (titel ? `/Title ${alsTextangabe(titel)} ` : '')
    + (verfasser ? `/Author ${alsTextangabe(verfasser)} ` : '')
    + `/Producer ${alsTextangabe('Textauszug')} /CreationDate (${zeitstempel(jetzt)}) >>`);

  schnitte.forEach((name, i) => {
    objekt(ERSTES_FONT + i,
      `<< /Type /Font /Subtype /Type1 /BaseFont /${name} /Encoding /WinAnsiEncoding >>`);
  });

  const schriftName = (name) => `/F${schnitte.indexOf(name) + 1}`;
  const mittel = papier.breite / 2;

  seiten.forEach((zeilen, i) => {
    let strom = 'BT\n';
    let letzte = null;
    for (const zeile of zeilen) {
      const kennung = `${zeile.schrift}|${zeile.groesse}`;
      if (kennung !== letzte) {
        strom += `${schriftName(zeile.schrift)} ${runden(zeile.groesse)} Tf\n`;
        letzte = kennung;
      }
      strom += `1 0 0 1 ${runden(zeile.x)} ${runden(zeile.y)} Tm\n`;
      strom += `${alsZeichenkette(zeile.bytes)} Tj\n`;
    }
    if (seitenzahlen) {
      const zahl = nachWinAnsi(String(i + 1)).bytes;
      const klein = Math.max(7, groesse * 0.8);
      strom += `${schriftName(schriften.normal)} ${runden(klein)} Tf\n`;
      strom += `1 0 0 1 ${runden(mittel - breite(zahl, schriften.normal, klein) / 2)} `
        + `${runden(rand * 0.55)} Tm\n${alsZeichenkette(zahl)} Tj\n`;
    }
    strom += 'ET\n';

    objekt(seiteNr(i), `<< /Type /Page /Parent 2 0 R /MediaBox `
      + `[0 0 ${runden(papier.breite)} ${runden(papier.hoehe)}] /Resources << /Font << `
      + schnitte.map((name, k) => `/F${k + 1} ${ERSTES_FONT + k} 0 R`).join(' ')
      + ` >> >> /Contents ${inhaltNr(i)} 0 R >>`);

    // Die Länge zählt BYTES, nicht Zeichen. Im Strom steht nach der
    // Maskierung zwar nur ASCII, aber diese Zeile ist der Ort, an dem sich
    // das eines Tages rächt.
    const bytes = new Schreiber().text(strom).fertig();
    stellen[inhaltNr(i)] = schreiber.laenge;
    schreiber.text(`${inhaltNr(i)} 0 obj\n<< /Length ${bytes.length} >>\nstream\n`);
    schreiber.bytes(bytes);
    schreiber.text('endstream\nendobj\n');
  });

  // Lesezeichen: dieselbe Gliederung wie das Inhaltsverzeichnis der EPUB.
  // Flach, nicht verschachtelt — eine falsch gezählte Verschachtelung
  // lassen manche Betrachter die ganze Liste verwerfen.
  if (marken.length) {
    marken.forEach((mark, i) => {
      const nummer = ERSTE_MARKE + i;
      const vor = i > 0 ? ` /Prev ${nummer - 1} 0 R` : '';
      const nach = i < marken.length - 1 ? ` /Next ${nummer + 1} 0 R` : '';
      objekt(nummer, `<< /Title ${alsTextangabe(mark.titel)} /Parent ${WURZEL_MARKE} 0 R`
        + `${vor}${nach} /Dest [${seiteNr(mark.seite)} 0 R /XYZ null ${runden(mark.y)} null] >>`);
    });
    objekt(WURZEL_MARKE, `<< /Type /Outlines /First ${ERSTE_MARKE} 0 R `
      + `/Last ${ERSTE_MARKE + marken.length - 1} 0 R /Count ${marken.length} >>`);
  }

  const xref = schreiber.laenge;
  schreiber.text(`xref\n0 ${gesamt + 1}\n0000000000 65535 f \n`);
  for (let i = 1; i <= gesamt; i++) {
    schreiber.text(`${String(stellen[i]).padStart(10, '0')} 00000 n \n`);
  }
  schreiber.text(`trailer\n<< /Size ${gesamt + 1} /Root 1 0 R /Info 3 0 R >>\n`
    + `startxref\n${xref}\n%%EOF\n`);

  return schreiber.fertig();
}

// Zwei Nachkommastellen reichen für ein Zehntel Haarbreite und halten die
// Datei klein.
function runden(zahl) {
  return String(Math.round(zahl * 100) / 100);
}
