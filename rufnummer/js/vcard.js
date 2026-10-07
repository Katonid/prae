/* Liest eine vCard-Datei (.vcf), wie sie die Kontakte-App von iPhone, iPad
 * und Mac exportiert (vCard 3.0), und behält davon NUR Name, Firma und
 * Telefonnummern. Alles andere (Adressen, Geburtstage, Fotos) wird verworfen.
 */

export function vcardLesen(text) {
  // Lange Zeilen sind umbrochen: Zeilenende + Leerzeichen/Tab = Fortsetzung.
  // Ältere Android-Exporte (Quoted-Printable) umbrechen mit „=" am Zeilenende.
  const zeilen = String(text).replace(/\r\n?/g, '\n').replace(/\n[ \t]/g, '')
    .replace(/=\n/g, '').split('\n');
  const kontakte = [];
  let k = null;

  for (const zeile of zeilen) {
    const doppelpunkt = zeile.indexOf(':');
    if (doppelpunkt < 0) continue;
    const kopf = zeile.slice(0, doppelpunkt);
    let wert = zeile.slice(doppelpunkt + 1);
    const teile = kopf.split(';');
    // „item1.TEL" → „TEL"
    const name = teile[0].replace(/^.*\./, '').toUpperCase();
    const parameter = teile.slice(1).map((p) => p.toUpperCase());

    if (name === 'BEGIN' && wert.trim().toUpperCase() === 'VCARD') { k = { name: '', firma: '', nummern: [] }; continue; }
    if (!k) continue;
    if (name === 'END') {
      if (!k.name) k.name = k.firma || k.nname || '';
      delete k.nname;
      if (k.nummern.length) kontakte.push(k);
      k = null;
      continue;
    }
    if (parameter.some((p) => p.includes('QUOTED-PRINTABLE'))) wert = qpDekodieren(wert);

    if (name === 'FN') k.name = entschaerfen(wert).trim();
    else if (name === 'N' && !k.name) {
      const [nachname = '', vorname = ''] = wert.split(';').map(entschaerfen);
      k.nname = `${vorname} ${nachname}`.trim();
    } else if (name === 'ORG') k.firma = entschaerfen(wert.split(';')[0]).trim();
    else if (name === 'TEL') {
      const nummer = wert.replace(/^tel:/i, '').trim();
      if (nummer) k.nummern.push({ nummer, art: telArt(parameter) });
    }
  }
  return kontakte;
}

function entschaerfen(text) {
  return String(text).replace(/\\n/gi, ' ').replace(/\\([,;\\])/g, '$1');
}

function telArt(parameter) {
  const p = parameter.join(';');
  if (p.includes('MAIN')) return 'Zentrale';
  if (p.includes('CELL')) return p.includes('WORK') ? 'Handy (Arbeit)' : 'Handy';
  if (p.includes('FAX')) return 'Fax';
  if (p.includes('WORK')) return 'Arbeit';
  if (p.includes('HOME')) return 'privat';
  return '';
}

function qpDekodieren(text) {
  const bytes = [];
  const roh = text.replace(/=$/, '');
  for (let i = 0; i < roh.length; i += 1) {
    if (roh[i] === '=' && /^[0-9A-F]{2}$/i.test(roh.slice(i + 1, i + 3))) {
      bytes.push(parseInt(roh.slice(i + 1, i + 3), 16));
      i += 2;
    } else bytes.push(roh.charCodeAt(i) & 0xff);
  }
  try { return new TextDecoder('utf-8').decode(new Uint8Array(bytes)); } catch { return text; }
}
