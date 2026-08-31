// Baut aus den gelesenen Terminen eine .ics-Datei (RFC 5545).
//
// Zeiten stehen bewusst OHNE Zeitzone („schwebend"): Ein Schultermin um
// 8 Uhr ist um 8 Uhr, egal in welcher Zeitzone das Gerät gerade steht. Eine
// mitgelieferte VTIMEZONE wäre die Alternative — sie brächte hier nichts und
// müsste bei jeder Zeitumstellung stimmen.

const zwei = (n) => String(n).padStart(2, '0');

function tagesstempel(datum) {
  return `${datum.jahr}${zwei(datum.monat)}${zwei(datum.tag)}`;
}

function zeitstempel(datum, zeit) {
  return `${tagesstempel(datum)}T${zwei(zeit.stunde)}${zwei(zeit.minute)}00`;
}

function tagPlus(datum, tage) {
  const d = new Date(Date.UTC(datum.jahr, datum.monat - 1, datum.tag + tage));
  return { jahr: d.getUTCFullYear(), monat: d.getUTCMonth() + 1, tag: d.getUTCDate() };
}

function maskiere(text) {
  return String(text)
    .replace(/\\/g, '\\\\')
    .replace(/;/g, '\\;')
    .replace(/,/g, '\\,')
    .replace(/\r?\n/g, '\\n');
}

// Gefaltet wird nach OKTETTEN, nicht nach Zeichen — ein Umlaut zählt zwei.
// Eine mitten im Zeichen geteilte Zeile macht aus „für" Buchstabensalat.
function falte(zeile) {
  const koder = new TextEncoder();
  if (koder.encode(zeile).length <= 75) return zeile;
  const stuecke = [];
  let aktuell = '';
  let laenge = 0;
  let grenze = 75;
  for (const zeichen of zeile) {
    const breite = koder.encode(zeichen).length;
    if (laenge + breite > grenze) {
      stuecke.push(aktuell);
      aktuell = ' ';
      laenge = 1;
      grenze = 75;
    }
    aktuell += zeichen;
    laenge += breite;
  }
  stuecke.push(aktuell);
  return stuecke.join('\r\n');
}

function kennung(termin, nummer) {
  const stoff = `${tagesstempel(termin.von)}|${termin.titel}|${nummer}`;
  let wert = 0x811c9dc5;
  for (let i = 0; i < stoff.length; i++) {
    wert ^= stoff.charCodeAt(i);
    wert = Math.imul(wert, 0x01000193) >>> 0;
  }
  return `${tagesstempel(termin.von)}-${wert.toString(36)}-${nummer}@terminkonverter`;
}

function wecker(termin, art) {
  if (art === 'keine') return [];
  const ganztags = !termin.zeitVon;
  let ausloeser;
  if (art === 'vortag') ausloeser = ganztags ? '-PT16H' : '-P1D';
  else ausloeser = ganztags ? 'PT8H' : '-PT15M';
  return [
    'BEGIN:VALARM',
    'ACTION:DISPLAY',
    `TRIGGER:${ausloeser}`,
    `DESCRIPTION:${maskiere(termin.titel)}`,
    'END:VALARM',
  ];
}

export function icsBauen(termine, einstellungen = {}) {
  const name = einstellungen.name || 'Termine';
  const erinnerung = einstellungen.erinnerung || 'keine';
  const dauer = Number(einstellungen.dauer) > 0 ? Number(einstellungen.dauer) : 60;
  const jetzt = einstellungen.jetzt || new Date();
  const stempel = `${jetzt.getUTCFullYear()}${zwei(jetzt.getUTCMonth() + 1)}`
    + `${zwei(jetzt.getUTCDate())}T${zwei(jetzt.getUTCHours())}`
    + `${zwei(jetzt.getUTCMinutes())}${zwei(jetzt.getUTCSeconds())}Z`;

  const zeilen = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Terminkonverter//Excel nach iCal//DE',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    `X-WR-CALNAME:${maskiere(name)}`,
  ];

  termine.forEach((termin, nummer) => {
    zeilen.push('BEGIN:VEVENT');
    zeilen.push(`UID:${kennung(termin, nummer + 1)}`);
    zeilen.push(`DTSTAMP:${stempel}`);

    if (termin.zeitVon) {
      const beginn = new Date(Date.UTC(termin.von.jahr, termin.von.monat - 1, termin.von.tag,
        termin.zeitVon.stunde, termin.zeitVon.minute));
      const endtag = termin.bis || termin.von;
      let schluss = termin.zeitBis
        ? new Date(Date.UTC(endtag.jahr, endtag.monat - 1, endtag.tag,
          termin.zeitBis.stunde, termin.zeitBis.minute))
        : new Date(Date.UTC(endtag.jahr, endtag.monat - 1, endtag.tag,
          termin.zeitVon.stunde, termin.zeitVon.minute + dauer));
      if (schluss <= beginn) schluss = new Date(beginn.getTime() + dauer * 60000);
      const alsTeile = (d) => ({
        datum: { jahr: d.getUTCFullYear(), monat: d.getUTCMonth() + 1, tag: d.getUTCDate() },
        zeit: { stunde: d.getUTCHours(), minute: d.getUTCMinutes() },
      });
      const a = alsTeile(beginn);
      const e = alsTeile(schluss);
      zeilen.push(`DTSTART:${zeitstempel(a.datum, a.zeit)}`);
      zeilen.push(`DTEND:${zeitstempel(e.datum, e.zeit)}`);
    } else {
      // Bei ganztägigen Terminen ist DTEND der ERSTE Tag danach.
      zeilen.push(`DTSTART;VALUE=DATE:${tagesstempel(termin.von)}`);
      zeilen.push(`DTEND;VALUE=DATE:${tagesstempel(tagPlus(termin.bis || termin.von, 1))}`);
    }

    zeilen.push(`SUMMARY:${maskiere(termin.titel)}`);
    if (termin.beschreibung) zeilen.push(`DESCRIPTION:${maskiere(termin.beschreibung)}`);
    if (termin.ort) zeilen.push(`LOCATION:${maskiere(termin.ort)}`);
    // Ganztägige Termine blockieren den Tag nicht (sonst gilt man den
    // ganzen Tag als beschäftigt); Termine mit Uhrzeit schon.
    zeilen.push(termin.zeitVon ? 'TRANSP:OPAQUE' : 'TRANSP:TRANSPARENT');
    zeilen.push(...wecker(termin, erinnerung));
    zeilen.push('END:VEVENT');
  });

  zeilen.push('END:VCALENDAR');
  return zeilen.map(falte).join('\r\n') + '\r\n';
}
