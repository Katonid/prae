// Aus den Zeilen der Tabelle werden Termine.
//
// Grundfall sind zwei Spalten: Datum und Beschreibung. Welche davon links
// steht, wird nicht vorgeschrieben — gesucht wird die Zelle, die sich als
// Datum lesen lässt; alles Übrige ist die Beschreibung. Zeilen ohne
// erkennbares Datum verschwinden nicht still, sie kommen als Hinweis zurück.

const MONATE = {
  jan: 1, januar: 1, feb: 2, februar: 2, mrz: 3, maerz: 3, märz: 3, mar: 3,
  apr: 4, april: 4, mai: 5, jun: 6, juni: 6, jul: 7, juli: 7, aug: 8, august: 8,
  sep: 9, sept: 9, september: 9, okt: 10, oktober: 10, nov: 11, november: 11,
  dez: 12, dezember: 12,
};
const WOCHENTAGE = /^\s*(mo|di|mi|do|fr|sa|so)(n|ns|ntag|enstag|ttwoch|nnerstag|eitag|mstag|nntag|\.)?\s*[,.]?\s*/i;
const KOPFWORTE = /^(datum|termin|tag|wann|von|bis|zeit|uhrzeit|beginn|ende|beschreibung|titel|thema|ereignis|was|anlass|notiz|bemerkung|ort)$/i;

const zweistellig = (n) => String(n).padStart(2, '0');

export function alsSchluessel(datum) {
  return `${datum.jahr}-${zweistellig(datum.monat)}-${zweistellig(datum.tag)}`;
}

function gueltig(jahr, monat, tag) {
  if (monat < 1 || monat > 12 || tag < 1 || tag > 31) return false;
  const probe = new Date(Date.UTC(jahr, monat - 1, tag));
  return probe.getUTCFullYear() === jahr && probe.getUTCMonth() === monat - 1
    && probe.getUTCDate() === tag;
}

function jahrVoll(roh) {
  const jahr = Number(roh);
  if (roh.length <= 2) return jahr + (jahr < 70 ? 2000 : 1900);
  return jahr;
}

// Sucht alle Datumsangaben in einem Text und gibt sie samt Restsatz zurück.
function datenAusText(text, ersatzJahr) {
  const gefunden = [];
  let rest = text;
  const merke = (jahr, monat, tag, ganz) => {
    if (!gueltig(jahr, monat, tag)) return ganz;
    gefunden.push({ jahr, monat, tag });
    return ' '.repeat(ganz.length);
  };

  rest = rest.replace(/(\d{4})-(\d{1,2})-(\d{1,2})/g,
    (ganz, j, m, t) => merke(Number(j), Number(m), Number(t), ganz));
  rest = rest.replace(/(\d{1,2})\.\s*(\d{1,2})\.\s*(\d{2,4})/g,
    (ganz, t, m, j) => merke(jahrVoll(j), Number(m), Number(t), ganz));
  rest = rest.replace(/(\d{1,2})\s*\/\s*(\d{1,2})\s*\/\s*(\d{2,4})/g,
    (ganz, t, m, j) => merke(jahrVoll(j), Number(m), Number(t), ganz));
  rest = rest.replace(/(\d{1,2})\.\s*([A-Za-zÄÖÜäöü]+)\.?\s*(\d{2,4})?/g,
    (ganz, t, name, j) => {
      const monat = MONATE[name.toLowerCase()];
      if (!monat) return ganz;
      return merke(j ? jahrVoll(j) : ersatzJahr, monat, Number(t), ganz);
    });
  rest = rest.replace(/(\d{1,2})\.\s*(\d{1,2})\.(?!\d)/g,
    (ganz, t, m) => merke(ersatzJahr, Number(m), Number(t), ganz));

  return { daten: gefunden, rest };
}

function zeitenAusText(text) {
  const zeiten = [];
  const rest = text.replace(/(\d{1,2})[:.](\d{2})(?:\s*Uhr)?|(\d{1,2})\s*Uhr/gi,
    (ganz, s1, m1, s2) => {
      const stunde = Number(s1 !== undefined ? s1 : s2);
      const minute = Number(m1 || 0);
      if (stunde > 23 || minute > 59) return ganz;
      zeiten.push({ stunde, minute });
      return ' '.repeat(ganz.length);
    });
  return { zeiten, rest };
}

function textZuDatum(text, ersatzJahr) {
  const ohneTag = text.replace(WOCHENTAGE, '');
  const { daten, rest } = datenAusText(ohneTag, ersatzJahr);
  if (!daten.length) return null;
  const { zeiten, rest: uebrig } = zeitenAusText(rest);
  return {
    von: daten[0],
    bis: daten[1] || null,
    zeitVon: zeiten[0] || null,
    zeitBis: zeiten[1] || null,
    rest: uebrig.replace(/[\s,;–—-]+/g, ' ').trim(),
  };
}

// Eine Zelle, die nur eine Uhrzeit trägt (in Excel eine Zahl unter 1).
function nurZeit(zelle) {
  if (zelle.art === 'datum' && zelle.zahl < 1) {
    return { stunde: zelle.datum.stunde, minute: zelle.datum.minute };
  }
  if (zelle.art === 'text') {
    const treffer = zelle.text.match(/^(\d{1,2})[:.](\d{2})(?:\s*Uhr)?$/i);
    if (treffer && Number(treffer[1]) < 24 && Number(treffer[2]) < 60) {
      return { stunde: Number(treffer[1]), minute: Number(treffer[2]) };
    }
  }
  return null;
}

function zelleZuDatum(zelle, ersatzJahr) {
  if (!zelle) return null;
  if (zelle.art === 'datum') {
    if (zelle.zahl < 1) return null;
    const d = zelle.datum;
    return {
      von: { jahr: d.jahr, monat: d.monat, tag: d.tag },
      bis: null,
      zeitVon: d.hatZeit ? { stunde: d.stunde, minute: d.minute } : null,
      zeitBis: null,
      rest: '',
    };
  }
  if (zelle.art === 'text') return textZuDatum(zelle.text, ersatzJahr);
  return null;
}

function istKopfzeile(zeilen) {
  const erste = zeilen[0];
  if (!erste) return false;
  const worte = erste.zellen.filter(Boolean);
  if (!worte.length || worte.some((z) => z.art !== 'text')) return false;
  return worte.some((z) => KOPFWORTE.test(z.text.trim()));
}

export function termineLesen(zeilen, einstellungen = {}) {
  const ersatzJahr = einstellungen.jahr || new Date().getFullYear();
  const termine = [];
  const hinweise = [];
  let start = 0;
  if (istKopfzeile(zeilen)) start = 1;

  for (let i = start; i < zeilen.length; i++) {
    const zeile = zeilen[i];
    const zellen = zeile.zellen;

    let datum = null;
    let datumIndex = -1;
    for (let s = 0; s < zellen.length; s++) {
      const gelesen = zelleZuDatum(zellen[s], ersatzJahr);
      if (gelesen) { datum = gelesen; datumIndex = s; break; }
    }
    if (!datum) {
      const text = zellen.filter(Boolean).map((z) => z.text).join(' ').trim();
      if (text) hinweise.push({ zeile: zeile.nummer, text, grund: 'Kein Datum erkannt' });
      continue;
    }

    const beschreibung = [];
    if (datum.rest) beschreibung.push(datum.rest);
    for (let s = 0; s < zellen.length; s++) {
      if (s === datumIndex || !zellen[s]) continue;
      const zelle = zellen[s];
      const zeit = nurZeit(zelle);
      if (zeit) {
        if (!datum.zeitVon) datum.zeitVon = zeit;
        else if (!datum.zeitBis) datum.zeitBis = zeit;
        continue;
      }
      const weiteres = zelleZuDatum(zelle, ersatzJahr);
      if (weiteres && !datum.bis && !weiteres.rest) {
        datum.bis = weiteres.von;
        if (weiteres.zeitVon && !datum.zeitVon) datum.zeitVon = weiteres.zeitVon;
        continue;
      }
      beschreibung.push(zelle.art === 'zahl' ? String(zelle.zahl) : zelle.text);
    }

    const titel = beschreibung.join(' – ').trim();

    // Eine Uhrzeit steht oft in der Beschreibung („Elternabend 19:30"). Sie
    // wird nur mit Doppelpunkt oder dem Wort „Uhr" genommen — „3.45" in einem
    // Text ist meist eine Zahl und keine Viertel vor vier.
    if (!datum.zeitVon && titel) {
      const gefunden = [];
      for (const t of titel.matchAll(/\b(\d{1,2}):(\d{2})\b|\b(\d{1,2})\s*Uhr\b/gi)) {
        const stunde = Number(t[1] !== undefined ? t[1] : t[3]);
        const minute = Number(t[2] || 0);
        if (stunde < 24 && minute < 60) gefunden.push({ stunde, minute });
      }
      if (gefunden.length) {
        datum.zeitVon = gefunden[0];
        if (gefunden[1]) datum.zeitBis = gefunden[1];
      }
    }
    if (!titel) {
      hinweise.push({
        zeile: zeile.nummer,
        text: alsSchluessel(datum.von),
        grund: 'Keine Beschreibung — Termin heißt „Termin"',
      });
    }

    if (datum.bis) {
      const a = Date.UTC(datum.von.jahr, datum.von.monat - 1, datum.von.tag);
      const b = Date.UTC(datum.bis.jahr, datum.bis.monat - 1, datum.bis.tag);
      if (b < a) datum.bis = null;
    }

    termine.push({
      zeile: zeile.nummer,
      von: datum.von,
      bis: datum.bis,
      zeitVon: datum.zeitVon,
      zeitBis: datum.zeitBis,
      titel: titel || 'Termin',
    });
  }

  return { termine, hinweise, kopfzeile: start === 1 };
}

export function alsAnzeige(termin) {
  const tag = `${zweistellig(termin.von.tag)}.${zweistellig(termin.von.monat)}.${termin.von.jahr}`;
  if (!termin.zeitVon && !termin.bis) return tag;
  let text = tag;
  if (termin.zeitVon) {
    text += `, ${zweistellig(termin.zeitVon.stunde)}:${zweistellig(termin.zeitVon.minute)}`;
    if (termin.zeitBis) {
      text += `–${zweistellig(termin.zeitBis.stunde)}:${zweistellig(termin.zeitBis.minute)}`;
    }
    text += ' Uhr';
  }
  if (termin.bis) {
    text += ` bis ${zweistellig(termin.bis.tag)}.${zweistellig(termin.bis.monat)}.${termin.bis.jahr}`;
  }
  return text;
}
