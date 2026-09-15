// Aus dem Inhaltsstrom einer Seite wird Text mit Ort.
//
// Ein PDF kennt keine Zeilen und keine Wörter. Es kennt „setze diese Zeichen an
// diese Stelle" — hundertmal je Seite, in beliebiger Reihenfolge. Zeilen und
// Leerzeichen müssen deshalb aus den STELLEN zurückgerechnet werden: Was auf
// gleicher Höhe steht, ist eine Zeile; wo eine Lücke breiter ist als ein
// Viertel der Schrifthöhe, stand ein Leerzeichen.
//
// Deshalb werden auch die Zeichenbreiten der Schrift gelesen: Ohne sie wüsste
// niemand, wo ein Wort aufhört, und der Text käme ohne Leerzeichen an.

import { objektLesen } from './pdf.js';
import { schriftLesen, Schrift } from './schrift.js';

// [a b c d e f] — die übliche Matrix aus dem PDF-Handbuch.
const EINS = [1, 0, 0, 1, 0, 0];

function mal(m, n) {
  return [
    m[0] * n[0] + m[1] * n[2],
    m[0] * n[1] + m[1] * n[3],
    m[2] * n[0] + m[3] * n[2],
    m[2] * n[1] + m[3] * n[3],
    m[4] * n[0] + m[5] * n[2] + n[4],
    m[4] * n[1] + m[5] * n[3] + n[5],
  ];
}

const punkt = (m) => ({ x: m[4], y: m[5] });
// Wie groß eine Schrift auf dem Papier wirklich ist, steckt in der Matrix.
const hoehe = (m) => Math.hypot(m[2], m[3]) || Math.hypot(m[0], m[1]) || 1;

function drehe(x, y, winkel) {
  const w = ((winkel % 360) + 360) % 360;
  if (w === 90) return { x: y, y: -x };
  if (w === 180) return { x: -x, y: -y };
  if (w === 270) return { x: -y, y: x };
  return { x, y };
}

// Die Zeichen einer Seite einsammeln — je Aufruf eines Textbefehls ein Stück.
class Sammler {
  constructor(drehung) {
    this.stuecke = [];
    this.drehung = drehung || 0;
  }

  lege(text, m, groesse, breite) {
    if (!text) return;
    const anfang = punkt(m);
    const gedreht = drehe(anfang.x, anfang.y, this.drehung);
    this.stuecke.push({
      text,
      x: gedreht.x,
      y: gedreht.y,
      bis: gedreht.x + breite,
      groesse: Math.max(groesse, 0.01),
    });
  }
}

// Zerlegt einen Inhaltsstrom in Operanden und Befehle und führt die
// Textbefehle aus. Alles andere (Linien, Farben, Bilder) wird übergangen.
async function stromAusfuehren(dokument, daten, mittel, sammler, tiefe, schriften) {
  let pos = 0;
  let operanden = [];
  let ctm = mittel.ctm;
  const stapel = [];

  let tm = EINS.slice();
  let tlm = EINS.slice();
  let schrift = mittel.schrift || new Schrift();
  let groesse = 0;
  let zeichenabstand = 0;
  let wortabstand = 0;
  let waagrecht = 1;
  let zeilenabstand = 0;

  const zeigeText = (bytes) => {
    let text = '';
    let vorschub = 0;
    for (const code of schrift.codes(bytes)) {
      text += schrift.zuText(code);
      let breite = schrift.breite(code) * groesse + zeichenabstand;
      if (code === 32 && !schrift.zweiByte) breite += wortabstand;
      vorschub += breite * waagrecht;
    }
    const gesamt = mal(tm, ctm);
    sammler.lege(text, gesamt, groesse * hoehe(gesamt), vorschub * hoehe(ctm));
    tm = mal([1, 0, 0, 1, vorschub, 0], tm);
  };

  const neueZeile = (tx, ty) => {
    tlm = mal([1, 0, 0, 1, tx, ty], tlm);
    tm = tlm.slice();
  };

  while (pos < daten.length) {
    const vorher = pos;
    const { wert, pos: naechste } = objektLesen(daten, pos);
    pos = naechste <= vorher ? vorher + 1 : naechste;
    if (wert === null && pos >= daten.length) break;

    if (!(wert && typeof wert === 'object' && 'wort' in wert)) {
      operanden.push(wert);
      if (operanden.length > 32) operanden.shift();
      continue;
    }

    const befehl = wert.wort;
    const zahl = (i) => {
      const w = operanden[operanden.length - i];
      return typeof w === 'number' ? w : 0;
    };

    switch (befehl) {
      case 'q': stapel.push(ctm); break;
      case 'Q': if (stapel.length) ctm = stapel.pop(); break;
      case 'cm':
        ctm = mal([zahl(6), zahl(5), zahl(4), zahl(3), zahl(2), zahl(1)], ctm);
        break;
      case 'BT': tm = EINS.slice(); tlm = EINS.slice(); break;
      case 'ET': break;
      case 'Tf': {
        groesse = zahl(1);
        const name = operanden[operanden.length - 2];
        if (typeof name === 'string' && schriften.has(name)) schrift = schriften.get(name);
        break;
      }
      case 'Td': neueZeile(zahl(2), zahl(1)); break;
      case 'TD': zeilenabstand = -zahl(1); neueZeile(zahl(2), zahl(1)); break;
      case 'Tm':
        tlm = [zahl(6), zahl(5), zahl(4), zahl(3), zahl(2), zahl(1)];
        tm = tlm.slice();
        break;
      case 'T*': neueZeile(0, -zeilenabstand); break;
      case 'TL': zeilenabstand = zahl(1); break;
      case 'Tc': zeichenabstand = zahl(1); break;
      case 'Tw': wortabstand = zahl(1); break;
      case 'Tz': waagrecht = zahl(1) / 100 || 1; break;
      case 'Tj':
      case 'TJ':
      case "'":
      case '"': {
        if (befehl === "'") neueZeile(0, -zeilenabstand);
        if (befehl === '"') {
          wortabstand = zahl(3);
          zeichenabstand = zahl(2);
          neueZeile(0, -zeilenabstand);
        }
        const letztes = operanden[operanden.length - 1];
        if (befehl === 'TJ' && Array.isArray(letztes)) {
          for (const teil of letztes) {
            if (teil instanceof Uint8Array) zeigeText(teil);
            else if (typeof teil === 'number') {
              const rueck = (-teil / 1000) * groesse * waagrecht;
              // Eine große Lücke zwischen zwei Stücken IST ein Leerzeichen —
              // viele Erzeuger schreiben nie eines, sondern rücken nur vor.
              if (rueck > groesse * 0.18) {
                const gesamt = mal(tm, ctm);
                sammler.lege(' ', gesamt, groesse * hoehe(gesamt), rueck * hoehe(ctm));
              }
              tm = mal([1, 0, 0, 1, rueck, 0], tm);
            }
          }
        } else if (letztes instanceof Uint8Array) {
          zeigeText(letztes);
        }
        break;
      }
      case 'Do': {
        const name = operanden[operanden.length - 1];
        if (typeof name === 'string' && tiefe < 8) {
          const formen = mittel.xobjekte || {};
          const form = dokument.hole(formen[name]);
          if (form && form.strom && dokument.hole(form.strom.Subtype) === 'Form') {
            const eigeneMittel = await mittelSammeln(
              dokument,
              dokument.hole(form.strom.Resources) || mittel.roh,
              mittel,
            );
            const matrix = dokument.hole(form.strom.Matrix);
            eigeneMittel.ctm = Array.isArray(matrix) && matrix.length === 6
              ? mal(matrix.map((w) => dokument.hole(w)), ctm)
              : ctm;
            eigeneMittel.schrift = schrift;
            try {
              const inhalt = await dokument.stromDaten(form);
              await stromAusfuehren(dokument, inhalt, eigeneMittel, sammler, tiefe + 1,
                eigeneMittel.schriften);
            } catch (fehler) {
              // Eine kaputte Form kostet ihren Text, nicht die ganze Seite.
            }
          }
        }
        break;
      }
      case 'BI': {
        // Ein eingebettetes Bild: rohe Bytes mitten im Strom. Sie müssen
        // übersprungen werden, sonst liest der Zerleger Unsinn.
        const endeMuster = [0x45, 0x49];               // „EI"
        let p = pos;
        while (p + 1 < daten.length) {
          if (daten[p] === endeMuster[0] && daten[p + 1] === endeMuster[1]
              && (p === 0 || daten[p - 1] <= 0x20)
              && (p + 2 >= daten.length || daten[p + 2] <= 0x20)) break;
          p++;
        }
        pos = Math.min(p + 2, daten.length);
        break;
      }
      default: break;
    }
    operanden = [];
  }
}

// Schriften und Formen einer Seite bereitstellen.
async function mittelSammeln(dokument, quellen, erbe) {
  const mittel = {
    ctm: EINS.slice(),
    schriften: new Map(),
    xobjekte: {},
    roh: quellen,
  };
  const woerterbuch = dokument.hole(quellen);
  if (!woerterbuch || typeof woerterbuch !== 'object') {
    if (erbe) {
      mittel.schriften = erbe.schriften;
      mittel.xobjekte = erbe.xobjekte;
    }
    return mittel;
  }
  const schriften = dokument.hole(woerterbuch.Font);
  if (schriften && typeof schriften === 'object') {
    for (const [name, verweis] of Object.entries(schriften)) {
      const eintrag = dokument.hole(verweis);
      if (!eintrag || typeof eintrag !== 'object') continue;
      try {
        mittel.schriften.set(name, await schriftLesen(dokument, eintrag));
      } catch (fehler) {
        mittel.schriften.set(name, new Schrift());
      }
    }
  }
  const xobjekte = dokument.hole(woerterbuch.XObject);
  if (xobjekte && typeof xobjekte === 'object') mittel.xobjekte = xobjekte;
  if (erbe) {
    for (const [name, schrift] of erbe.schriften) {
      if (!mittel.schriften.has(name)) mittel.schriften.set(name, schrift);
    }
  }
  return mittel;
}

// Stücke zu Zeilen bündeln: gleiche Höhe = eine Zeile, breite Lücke =
// Leerzeichen.
function zeilenBauen(stuecke) {
  if (!stuecke.length) return [];
  const sortiert = stuecke.slice().sort((a, b) => (b.y - a.y) || (a.x - b.x));
  const zeilen = [];
  let aktuell = null;

  for (const stueck of sortiert) {
    const schwelle = Math.max(stueck.groesse * 0.5, 1.2);
    if (!aktuell || Math.abs(aktuell.y - stueck.y) > schwelle) {
      aktuell = { y: stueck.y, groesse: stueck.groesse, teile: [stueck] };
      zeilen.push(aktuell);
    } else {
      aktuell.teile.push(stueck);
      aktuell.groesse = Math.max(aktuell.groesse, stueck.groesse);
    }
  }

  return zeilen.map((zeile) => {
    const teile = zeile.teile.sort((a, b) => a.x - b.x);
    let text = '';
    let bis = null;
    for (const teil of teile) {
      if (bis !== null) {
        const luecke = teil.x - bis;
        if (luecke > teil.groesse * 0.22 && !/\s$/.test(text) && !/^\s/.test(teil.text)) text += ' ';
      }
      text += teil.text;
      bis = Math.max(bis === null ? teil.bis : bis, teil.bis);
    }
    return {
      text: text.replace(/[ \t]+/g, ' ').trim(),
      y: zeile.y,
      groesse: zeile.groesse,
      x: teile.length ? teile[0].x : 0,
      // Wo die Zeile AUFHÖRT, entscheidet später über den Absatz: Eine Zeile,
      // die vor dem rechten Rand endet, hat den Absatz beendet.
      bis: bis === null ? 0 : bis,
    };
  }).filter((zeile) => zeile.text !== '');
}

// Der Text EINER Seite, als Zeilen.
export async function seitenZeilen(dokument, seite) {
  const drehung = Number(dokument.hole(seite.Rotate)) || 0;
  const sammler = new Sammler(drehung);
  const mittel = await mittelSammeln(dokument, seite.Resources, null);

  let inhalte = dokument.hole(seite.Contents);
  if (!Array.isArray(inhalte)) inhalte = [seite.Contents];
  const stuecke = [];
  for (const verweis of inhalte) {
    const strom = dokument.hole(verweis);
    if (!strom || !strom.strom) continue;
    try {
      stuecke.push(await dokument.stromDaten(strom));
    } catch (fehler) {
      // Ein unlesbarer Teilstrom kostet seinen Text, nicht die Seite.
    }
  }
  if (!stuecke.length) return [];

  // Mehrere Ströme einer Seite sind EIN Strom — ein Befehl darf an der Naht
  // geteilt sein.
  let gesamt = stuecke[0];
  if (stuecke.length > 1) {
    const laenge = stuecke.reduce((summe, s) => summe + s.length + 1, 0);
    gesamt = new Uint8Array(laenge);
    let ziel = 0;
    for (const stueck of stuecke) {
      gesamt.set(stueck, ziel);
      ziel += stueck.length;
      gesamt[ziel] = 0x0a;
      ziel++;
    }
  }

  await stromAusfuehren(dokument, gesamt, mittel, sammler, 0, mittel.schriften);
  return zeilenBauen(sammler.stuecke);
}
