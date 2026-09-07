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
// Was nach Datum und Uhrzeit von der Datumszelle übrig bleibt: eine leere
// oder eine Wochentagsklammer sagt nichts, Bindewörter allein auch nicht.
const KLAMMER_LEER = /\(\s*(?:mo|di|mi|do|fr|sa|so|montag|dienstag|mittwoch|donnerstag|freitag|samstag|sonnabend|sonntag)?\s*\.?\s*\)/gi;
const FUELLWORT = /^(ab|bis|zum|zur|von|vom|am|im|und|oder|jeweils|ca|etwa|ggf|voraussichtlich)$/i;

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
  // Ein Datum ohne Jahreszahl merkt sich das: Steht in derselben Zelle ein
  // Datum MIT Jahr, gilt dessen Jahr — „14.09.-25.09.2026" meint zweimal
  // 2026, und „28.12.-04.01.2027" meint für den ersten Tag 2026.
  const merke = (jahr, monat, tag, ganz, bekannt = true) => {
    if (!gueltig(jahr, monat, tag)) return ganz;
    gefunden.push({ jahr, monat, tag, bekannt });
    return ' '.repeat(ganz.length);
  };
  const beide = (ganz, t1, m1, t2, m2, j) => {
    const jahr = jahrVoll(j);
    if (!gueltig(jahr, m2, t2)) return ganz;
    // Der erste Tag liegt vor dem zweiten; ein späterer Monat heißt Vorjahr.
    const jahr1 = m1 > m2 ? jahr - 1 : jahr;
    if (!gueltig(jahr1, m1, t1)) return ganz;
    gefunden.push({ jahr: jahr1, monat: m1, tag: t1, bekannt: true });
    gefunden.push({ jahr, monat: m2, tag: t2, bekannt: true });
    return ' '.repeat(ganz.length);
  };

  rest = rest.replace(/(\d{4})-(\d{1,2})-(\d{1,2})/g,
    (ganz, j, m, t) => merke(Number(j), Number(m), Number(t), ganz));
  // Zeitraum über zwei Monate: 17.10.- 31.10.2026, 28.12.-04.01.2027
  rest = rest.replace(/(\d{1,2})\.\s*(\d{1,2})\.\s*[-–—/]\s*(\d{1,2})\.\s*(\d{1,2})\.\s*(\d{2,4})/g,
    (ganz, t1, m1, t2, m2, j) => beide(ganz, Number(t1), Number(m1), Number(t2), Number(m2), j));
  // Zeitraum innerhalb eines Monats: 12.-14.10.2026, 10./11.07.2027
  rest = rest.replace(/(\d{1,2})\.\s*[-–—/]\s*(\d{1,2})\.\s*(\d{1,2})\.\s*(\d{2,4})/g,
    (ganz, t1, t2, m, j) => beide(ganz, Number(t1), Number(m), Number(t2), Number(m), j));
  rest = rest.replace(/(\d{1,2})\.\s*(\d{1,2})\.\s*(\d{2,4})/g,
    (ganz, t, m, j) => merke(jahrVoll(j), Number(m), Number(t), ganz));
  rest = rest.replace(/(\d{1,2})\s*\/\s*(\d{1,2})\s*\/\s*(\d{2,4})/g,
    (ganz, t, m, j) => merke(jahrVoll(j), Number(m), Number(t), ganz));
  rest = rest.replace(/(\d{1,2})\.\s*([A-Za-zÄÖÜäöü]+)\.?\s*(\d{2,4})?/g,
    (ganz, t, name, j) => {
      const monat = MONATE[name.toLowerCase()];
      if (!monat) return ganz;
      return merke(j ? jahrVoll(j) : ersatzJahr, monat, Number(t), ganz, Boolean(j));
    });
  rest = rest.replace(/(\d{1,2})\.\s*(\d{1,2})\.(?!\d)/g,
    (ganz, t, m) => merke(ersatzJahr, Number(m), Number(t), ganz, false));

  jahreErgaenzen(gefunden);
  // Der frühere Tag ist der Beginn, gleich in welcher Reihenfolge er im Text
  // steht: „Ab 07.09. bis zum 18.09.2026" nennt das vollständige Datum hinten.
  gefunden.sort((a, b) => Date.UTC(a.jahr, a.monat - 1, a.tag) - Date.UTC(b.jahr, b.monat - 1, b.tag));
  return { daten: gefunden, rest };
}

// Datumsangaben ohne Jahreszahl bekommen das Jahr des nächsten Datums, das
// eines trägt — über den Jahreswechsel hinweg um eins versetzt.
function jahreErgaenzen(daten) {
  const bekannt = daten.findIndex((d) => d.bekannt);
  if (bekannt < 0) return;
  const anker = daten[bekannt];
  daten.forEach((datum, index) => {
    if (datum.bekannt) return;
    let jahr = anker.jahr;
    if (index < bekannt && datum.monat > anker.monat) jahr -= 1;
    if (index > bekannt && datum.monat < anker.monat) jahr += 1;
    if (gueltig(jahr, datum.monat, datum.tag)) datum.jahr = jahr;
  });
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

function restSaeubern(text) {
  // Erst die Trennzeichen einsammeln, dann die Klammer prüfen: In
  // „Weihnachtsferien (23.12.2026 – 06.01.2027)" bleibt sonst der Gedankenstrich
  // zwischen den Klammern stehen, und „( )" wird nicht als leer erkannt.
  let rein = text.replace(/[\s,;–—-]+/g, ' ').replace(KLAMMER_LEER, ' ')
    .replace(/\s+/g, ' ').trim();
  // Stehen nur noch Bindewörter da, bleibt nichts. Sobald eine Zahl übrig
  // ist, bleibt alles stehen — „15. oder" gehört dem Nutzer vor Augen.
  if (rein && !/\d/.test(rein)) {
    rein = rein.split(' ').filter((wort) => wort && !FUELLWORT.test(wort.replace(/\.$/, ''))).join(' ');
  }
  return rein.trim();
}

// Zeitspanne zuerst: „9-15.30 Uhr" ist eine Angabe, keine zwei.
const ZEITSPANNE = /\b(\d{1,2})(?:[:.](\d{2}))?\s*(?:-|–|—|bis)\s*(\d{1,2})(?:[:.](\d{2}))?\s*(?:Uhr|h)\b/i;
const EINZELZEIT = /\b(\d{1,2})[:.](\d{2})\s*(?:Uhr|h)\b|\b(\d{1,2}):(\d{2})\b|\b(\d{1,2})\s*(?:Uhr|h)\b/gi;

function zeitenAusBeschreibung(text) {
  const spanne = text.match(ZEITSPANNE);
  if (spanne) {
    const von = { stunde: Number(spanne[1]), minute: Number(spanne[2] || 0) };
    const bis = { stunde: Number(spanne[3]), minute: Number(spanne[4] || 0) };
    if (von.stunde < 24 && bis.stunde < 24 && von.minute < 60 && bis.minute < 60) {
      return [von, bis];
    }
  }
  const zeiten = [];
  for (const t of text.matchAll(EINZELZEIT)) {
    const stunde = Number(t[1] !== undefined ? t[1] : t[3] !== undefined ? t[3] : t[5]);
    const minute = Number((t[1] !== undefined ? t[2] : t[3] !== undefined ? t[4] : 0) || 0);
    if (stunde < 24 && minute < 60) zeiten.push({ stunde, minute });
  }
  return zeiten;
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
    rest: restSaeubern(uebrig),
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

// Eine Überschriftenzeile wird an jeder Stelle erkannt, nicht nur ganz oben:
// Ein Word-Dokument bringt mehrere Tabellen mit, und jede hat ihre eigene.
// Eine echte Terminzeile trägt ein Datum und kommt hier nie an.
function istKopfzeile(zeile, erste) {
  const worte = zeile.zellen.filter(Boolean);
  if (!worte.length || worte.some((z) => z.art !== 'text')) return false;
  if (worte.some((z) => KOPFWORTE.test(z.text.trim()))) return true;
  return erste;
}

export function termineLesen(zeilen, einstellungen = {}) {
  const ersatzJahr = einstellungen.jahr || new Date().getFullYear();
  const termine = [];
  const hinweise = [];
  let kopfzeilen = 0;

  for (let i = 0; i < zeilen.length; i++) {
    const zeile = zeilen[i];
    const zellen = zeile.zellen;

    let datum = null;
    let datumIndex = -1;
    for (let s = 0; s < zellen.length; s++) {
      const gelesen = zelleZuDatum(zellen[s], ersatzJahr);
      if (gelesen) { datum = gelesen; datumIndex = s; break; }
    }
    if (!datum) {
      if (istKopfzeile(zeile, i === 0)) {
        kopfzeilen++;
        continue;
      }
      const text = zellen.filter(Boolean).map((z) => z.text).join(' ').trim();
      if (text) {
        hinweise.push({
          zeile: zeile.nummer,
          tabelle: zeile.tabelle,
          text,
          grund: 'Kein Datum erkannt',
        });
      }
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

    // Eine Uhrzeit steht oft in der Beschreibung („Elternabend 19:30",
    // „Unterricht von 8:00 – 11:30 Uhr", „Konferenz 9-15.30 Uhr"). Die
    // Punktform wird nur mit „Uhr" oder „h" genommen: „3.45" in einem Text
    // ist meist eine Zahl und keine Viertel vor vier.
    if (!datum.zeitVon && titel) {
      const gefunden = zeitenAusBeschreibung(titel);
      if (gefunden.length) {
        datum.zeitVon = gefunden[0];
        if (gefunden[1]) datum.zeitBis = gefunden[1];
      }
    }

    if (datum.bis) {
      const a = Date.UTC(datum.von.jahr, datum.von.monat - 1, datum.von.tag);
      const b = Date.UTC(datum.bis.jahr, datum.bis.monat - 1, datum.bis.tag);
      if (b < a) datum.bis = null;
    }

    termine.push({
      zeile: zeile.nummer,
      tabelle: zeile.tabelle,
      von: datum.von,
      bis: datum.bis,
      zeitVon: datum.zeitVon,
      zeitBis: datum.zeitBis,
      titel: titel || 'Termin',
    });
  }

  return { termine, hinweise, kopfzeilen };
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
