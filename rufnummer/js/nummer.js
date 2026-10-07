/* Alles, was sich an einer deutschen Rufnummer ohne Internet ablesen lässt.
 *
 * Reine Funktionen, kein Zugriff auf die Seite — damit lässt sich die Datei
 * auch mit Node prüfen (siehe CLAUDE.md).
 *
 * Schreibweise intern: „national" = nur Ziffern, MIT führender Null
 * („0234910 0" → „02349100"). Die Vorwahlliste der BNetzA führt die
 * Kennzahlen OHNE Null („234").
 */

// ── Eingabe bereinigen ──────────────────────────────────────────────────

/** Liefert { art, national?, land?, text }.
 *  art: 'leer' | 'national' | 'ausland' | 'kurz' | 'ungueltig' */
export function bereinigen(eingabe) {
  let text = String(eingabe ?? '').trim();
  if (!text) return { art: 'leer', text };
  // „+49 (0)89 …" — die Null in Klammern gehört nicht zur Nummer.
  text = text.replace(/\(\s*0\s*\)/g, '');
  // Schreibweisen wie „tel:+49…" aus Links und Kontakten.
  text = text.replace(/^tel:/i, '');
  const plus = /^\s*\+/.test(text);
  const ziffern = text.replace(/\D/g, '');
  if (!ziffern) return { art: 'ungueltig', text };

  let international = null;
  if (plus) international = ziffern;
  else if (ziffern.startsWith('00')) international = ziffern.slice(2);

  if (international !== null) {
    if (international.startsWith('49')) {
      const rest = international.slice(2).replace(/^0/, '');
      if (!rest) return { art: 'ungueltig', text };
      return { art: 'national', national: `0${rest}`, text };
    }
    return { art: 'ausland', land: laendervorwahl(international), ziffern: international, text };
  }
  if (ziffern.startsWith('0')) {
    if (ziffern.length < 3) return { art: 'ungueltig', text };
    return { art: 'national', national: ziffern, text };
  }
  return { art: 'kurz', ziffern, text };
}

// Nur, um bei einer ausländischen Nummer das Land zu nennen.
const LAENDER = {
  1: 'USA/Kanada', 7: 'Russland/Kasachstan', 20: 'Ägypten', 27: 'Südafrika', 30: 'Griechenland',
  31: 'Niederlande', 32: 'Belgien', 33: 'Frankreich', 34: 'Spanien', 36: 'Ungarn', 39: 'Italien',
  40: 'Rumänien', 41: 'Schweiz', 43: 'Österreich', 44: 'Großbritannien', 45: 'Dänemark',
  46: 'Schweden', 47: 'Norwegen', 48: 'Polen', 351: 'Portugal', 352: 'Luxemburg', 353: 'Irland',
  358: 'Finnland', 359: 'Bulgarien', 370: 'Litauen', 371: 'Lettland', 372: 'Estland',
  380: 'Ukraine', 385: 'Kroatien', 386: 'Slowenien', 420: 'Tschechien', 421: 'Slowakei',
  423: 'Liechtenstein', 90: 'Türkei', 91: 'Indien', 86: 'China', 81: 'Japan', 61: 'Australien',
  55: 'Brasilien', 52: 'Mexiko', 971: 'Vereinigte Arabische Emirate', 972: 'Israel',
};

function laendervorwahl(ziffern) {
  for (const laenge of [3, 2, 1]) {
    const vorwahl = ziffern.slice(0, laenge);
    if (LAENDER[vorwahl]) return { vorwahl: `+${vorwahl}`, name: LAENDER[vorwahl] };
  }
  return { vorwahl: `+${ziffern.slice(0, 3)}…`, name: null };
}

// ── Kurznummern ohne Vorwahl ─────────────────────────────────────────────

const KURZNUMMERN = {
  110: 'Polizei-Notruf',
  112: 'Feuerwehr und Rettungsdienst (Notruf)',
  115: 'Behördennummer (einheitliche Auskunft der Verwaltung)',
  116116: 'Sperr-Notruf für Karten und Konten',
  116117: 'Ärztlicher Bereitschaftsdienst',
  116111: 'Nummer gegen Kummer (Kinder- und Jugendtelefon)',
  116000: 'Hotline für vermisste Kinder',
  116006: 'Hilfetelefon für Opfer von Straftaten',
  116123: 'Telefonseelsorge',
};

// ── Mobilfunk: ursprünglich vergebene Netze ─────────────────────────────
// Nur die Blöcke der drei großen Netze, die sicher feststehen. Seit der
// Rufnummernmitnahme sagt das wenig über den heutigen Anbieter.
const MOBILNETZE = {
  151: 'Telekom', 160: 'Telekom', 170: 'Telekom', 171: 'Telekom', 175: 'Telekom',
  152: 'Vodafone', 162: 'Vodafone', 172: 'Vodafone', 173: 'Vodafone', 174: 'Vodafone',
  155: 'Telefónica (o2)', 157: 'Telefónica (o2)', 159: 'Telefónica (o2)', 163: 'Telefónica (o2)',
  176: 'Telefónica (o2)', 177: 'Telefónica (o2)', 178: 'Telefónica (o2)', 179: 'Telefónica (o2)',
};

// ── Dienste-Nummern (alles, was mit 01 beginnt und kein Handy ist) ──────
// Reihenfolge wichtig: längere Anfänge zuerst.
const DIENSTE = [
  ['118', 'Auskunftsdienst', 'Teurer Auskunftsdienst. Der Anbieter ist bei der Bundesnetzagentur eingetragen.', 'warnung'],
  ['137', 'Massenverkehrs-Dienst (Televoting)', 'Kostenpflichtig — wird für Gewinnspiele und Abstimmungen genutzt.', 'warnung'],
  ['138', 'Massenverkehrs-Dienst', 'Kostenpflichtig.', 'warnung'],
  ['180', 'Service-Nummer (0180)', 'Kostet je nach fünfter Ziffer, höchstens 14 ct/Min. aus dem Festnetz und 42 ct/Min. aus dem Mobilfunk. Firmen-Hotlines.', 'hinweis'],
  ['181', 'Internationale Virtuelle Private Netze', '', 'hinweis'],
  ['12', 'Innovative Dienste (012)', 'Kosten sind nicht festgelegt — vorsichtig sein.', 'warnung'],
  ['19', 'Online-Dienste / Nutzergruppen (019)', '', 'hinweis'],
  ['10', 'Betreiberauswahl (Call-by-Call, 010…)', 'Davor gewählt wird eine Anbieterkennung; die eigentliche Nummer folgt danach.', 'hinweis'],
  ['11', 'Netzinterne Dienste', '', 'hinweis'],
];

// ── Analyse ─────────────────────────────────────────────────────────────

/** Zerlegt eine bereinigte Eingabe. `vorwahlen`: { '234': 'Bochum', … } */
export function analysieren(bereinigt, vorwahlen) {
  if (bereinigt.art === 'kurz') return kurzAnalysieren(bereinigt.ziffern);
  if (bereinigt.art !== 'national') return null;

  const national = bereinigt.national;
  const n = national.slice(1); // ohne führende Null
  const ergebnis = {
    national,
    art: 'unbekannt',
    titel: '',
    vorwahl: null,
    rest: n,
    ort: null,
    netz: null,
    hinweise: [],
  };

  if (/^1[5-7]/.test(n)) {
    ergebnis.art = 'mobil';
    ergebnis.vorwahl = `0${n.slice(0, 3)}`;
    ergebnis.rest = n.slice(3);
    ergebnis.netz = MOBILNETZE[n.slice(0, 3)] || null;
    ergebnis.titel = 'Handynummer';
    ergebnis.hinweise.push({
      stufe: 'hinweis',
      text: ergebnis.netz
        ? `Der Block ${ergebnis.vorwahl} wurde ursprünglich an ${ergebnis.netz} vergeben. Weil man Nummern zu einem anderen Anbieter mitnehmen kann, sagt das über den heutigen Anbieter nichts Sicheres.`
        : `Weil man Nummern zu einem anderen Anbieter mitnehmen kann, ist das Netz nicht sicher bestimmbar.`,
    });
    ergebnis.hinweise.push({
      stufe: 'hinweis',
      text: 'Handynummern stehen nur selten in Telefonbüchern. Am meisten bringt hier die Websuche — und dein eigenes Nummernbuch.',
    });
    if (ergebnis.rest.length < 6 || ergebnis.rest.length > 9) {
      ergebnis.hinweise.push({ stufe: 'warnung', text: 'Für eine Handynummer ist sie ungewöhnlich lang oder kurz — ist sie vollständig?' });
    }
    return ergebnis;
  }

  if (n.startsWith('800')) {
    return dienst(ergebnis, '0800', 'Kostenlose Service-Nummer (0800)',
      'Für den Anrufer gebührenfrei — fast immer eine Firma oder Behörde. Websuche lohnt sich.', 'hinweis');
  }
  if (n.startsWith('900')) {
    return dienst(ergebnis, '0900', 'Premium-Dienst (0900)',
      'Teuer: bis 3 € pro Minute oder 30 € je Anruf. Rückrufe auf solche Nummern vermeiden.', 'warnung');
  }
  if (n.startsWith('700')) {
    return dienst(ergebnis, '0700', 'Persönliche Rufnummer (0700)',
      'Wird an eine beliebige andere Nummer weitergeleitet; der Inhaber lässt sich an der Nummer nicht ablesen.', 'hinweis');
  }
  if (n.startsWith('32')) {
    return dienst(ergebnis, '032', 'Ortsunabhängige Nummer (032)',
      'Gehört zu keinem Ort; meist Internettelefonie. Wird auch gern von unseriösen Anrufern benutzt.', 'hinweis');
  }
  if (n.startsWith('31')) {
    return dienst(ergebnis, `0${n.slice(0, 3)}`, 'Testnummer (031)', 'Dient zum Prüfen der Verbindung.', 'hinweis');
  }
  if (n.startsWith('1')) {
    for (const [anfang, titel, text, stufe] of DIENSTE) {
      if (n.startsWith(anfang)) return dienst(ergebnis, `0${anfang}`, titel, text, stufe);
    }
    return dienst(ergebnis, `0${n.slice(0, 3)}`, 'Dienste-Nummer', 'Gehört zu keinem Ort.', 'hinweis');
  }

  // Ortsnetz: längste passende Kennzahl suchen (2 bis 5 Ziffern).
  for (let laenge = 5; laenge >= 2; laenge -= 1) {
    const kennzahl = n.slice(0, laenge);
    if (vorwahlen && vorwahlen[kennzahl] && n.length > laenge) {
      ergebnis.art = 'ortsnetz';
      ergebnis.vorwahl = `0${kennzahl}`;
      ergebnis.rest = n.slice(laenge);
      ergebnis.ort = vorwahlen[kennzahl];
      ergebnis.titel = `Festnetz ${ergebnis.ort}`;
      if (ergebnis.rest.length < 3) {
        ergebnis.hinweise.push({ stufe: 'warnung', text: 'Nach der Vorwahl kommen sehr wenige Ziffern — ist die Nummer vollständig?' });
      }
      if (n.length > 13) {
        ergebnis.hinweise.push({ stufe: 'warnung', text: 'Für eine deutsche Nummer ist sie zu lang — vielleicht doppelt eingefügt?' });
      }
      return ergebnis;
    }
  }

  ergebnis.titel = 'Unbekannte Vorwahl';
  ergebnis.vorwahl = null;
  ergebnis.hinweise.push({ stufe: 'warnung', text: 'Diese Vorwahl steht nicht im Verzeichnis der Bundesnetzagentur. Vielleicht fehlt eine Ziffer, oder die Nummer stammt aus dem Ausland.' });
  return ergebnis;
}

function dienst(ergebnis, vorwahl, titel, text, stufe) {
  ergebnis.art = 'dienst';
  ergebnis.vorwahl = vorwahl;
  ergebnis.rest = ergebnis.national.slice(vorwahl.length);
  ergebnis.titel = titel;
  if (text) ergebnis.hinweise.push({ stufe, text });
  return ergebnis;
}

function kurzAnalysieren(ziffern) {
  if (KURZNUMMERN[ziffern]) {
    return {
      national: ziffern, art: 'kurznummer', titel: KURZNUMMERN[ziffern], vorwahl: null,
      rest: ziffern, ort: null, netz: null, hinweise: [],
    };
  }
  if (/^118\d{2,3}$/.test(ziffern)) {
    return {
      national: ziffern, art: 'kurznummer', titel: 'Auskunftsdienst', vorwahl: null, rest: ziffern,
      ort: null, netz: null, hinweise: [{ stufe: 'warnung', text: 'Teurer Auskunftsdienst.' }],
    };
  }
  return {
    national: ziffern, art: 'ohne-vorwahl', titel: 'Nummer ohne Vorwahl', vorwahl: null, rest: ziffern,
    ort: null, netz: null,
    hinweise: [{ stufe: 'warnung', text: 'Ohne Vorwahl lässt sich nichts nachschlagen. Bitte mit Vorwahl eingeben (z. B. 0234 …). Bei Anrufen aus dem eigenen Ort fehlt sie manchmal.' }],
  };
}

// ── Schreibweisen ───────────────────────────────────────────────────────

/** „0234 9100" — Vorwahl und Rest getrennt, sonst nur die Ziffern. */
export function anzeigen(analyse) {
  if (!analyse) return '';
  if (!analyse.vorwahl) return analyse.national;
  return `${analyse.vorwahl} ${analyse.rest}`;
}

export function international(analyse) {
  if (!analyse || !analyse.vorwahl) return null;
  return `+49 ${analyse.vorwahl.slice(1)} ${analyse.rest}`;
}

/** Eine Nummer im Nummernbuch oder in den Kontakten lesbar zeigen.
 *  `national` beginnt mit 0. Mit Stamm (Bereich) wird „…" angehängt. */
export function kurzAnzeigen(national, vorwahlen, { bereich = false } = {}) {
  const a = analysieren({ art: 'national', national }, vorwahlen);
  const text = a && a.vorwahl ? `${a.vorwahl} ${a.rest}` : national;
  return bereich ? `${text}-…` : text;
}

// ── Mögliche Zentralen (Stammnummer + Durchwahl) ────────────────────────
//
// Firmenanschlüsse bestehen aus Stammnummer und Durchwahl; die Zentrale ist
// meist die Stammnummer mit der Durchwahl 0. Wo die Durchwahl beginnt, sieht
// man der Nummer nicht an — also alle Längen von 1 bis 4 durchrechnen.
// Eine Stammnummer hat mindestens 3 Ziffern.

export function zentralen(analyse) {
  if (!analyse || analyse.art !== 'ortsnetz') return [];
  const t = analyse.rest;
  const liste = [];
  for (let d = 1; d <= 4; d += 1) {
    const stamm = t.slice(0, -d);
    if (stamm.length < 3) break;
    const durchwahl = t.slice(-d);
    liste.push({
      durchwahlLaenge: d,
      stamm,
      durchwahl,
      stammNational: analyse.vorwahl + stamm,
      zentraleNational: `${analyse.vorwahl}${stamm}0`,
      geteilt: `${analyse.vorwahl} ${stamm}-${durchwahl}`,
      zentraleAnzeige: `${analyse.vorwahl} ${stamm}-0`,
      istSelbstZentrale: /^0+$/.test(durchwahl),
    });
  }
  return liste;
}

// ── Suchanfragen ────────────────────────────────────────────────────────
//
// Suchmaschinen zerlegen „0234 910-0" in die Wörter 0234 / 910 / 0. Eine
// Phrasensuche nach "0234 910" findet deshalb Seiten, die IRGENDEINE
// Durchwahl dieses Anschlusses nennen — genau das, was man für die
// Zuordnung zu einer Firma braucht.

export function schreibweisen(analyse) {
  if (!analyse || !analyse.vorwahl) return analyse ? [analyse.national] : [];
  const v = analyse.vorwahl;
  const r = analyse.rest;
  const liste = [`${v} ${r}`, `${v}${r}`, `+49 ${v.slice(1)} ${r}`];
  if (analyse.art === 'ortsnetz') {
    for (const z of zentralen(analyse)) {
      if (z.durchwahlLaenge >= 2) liste.push(z.geteilt);
    }
  }
  return [...new Set(liste)];
}

export function oderAnfrage(phrasen) {
  return phrasen.map((p) => `"${p}"`).join(' OR ');
}

export function stammAnfrage(analyse, zentrale) {
  return oderAnfrage([`${analyse.vorwahl} ${zentrale.stamm}`, `+49 ${analyse.vorwahl.slice(1)} ${zentrale.stamm}`]);
}

export const SUCHE = {
  oertliche: (national) => `https://www.dasoertliche.de/rueckwaertssuche/?ph=${encodeURIComponent(national)}`,
  telefonbuch: (national) => `https://www.dastelefonbuch.de/R%C3%BCckw%C3%A4rts-Suche?phone=${encodeURIComponent(national)}&stype=RBP&mode=search`,
  google: (anfrage) => `https://www.google.com/search?q=${encodeURIComponent(anfrage)}`,
  duckduckgo: (anfrage) => `https://duckduckgo.com/?q=${encodeURIComponent(anfrage)}`,
  tellows: (national) => `https://www.tellows.de/num/${encodeURIComponent(national)}`,
  cleverdialer: (national) => `https://www.cleverdialer.de/telefonnummer/${encodeURIComponent(national)}`,
};

// ── Abgleich mit Nummernbuch und Kontakten ──────────────────────────────
//
// eintraege: [{ national, name, quelle: 'buch'|'kontakt', bereich?: bool, … }]
//
// Ergebnis:
//   genau    — dieselbe Nummer
//   bereich  — die Nummer liegt in einem gespeicherten Bereich (Stamm-…)
//   nachbarn — Nummern mit langem gemeinsamem Anfang im selben Ortsnetz:
//              mindestens 3 gemeinsame Ziffern nach der Vorwahl, und beide
//              weichen höchstens in den letzten 4 Ziffern ab (= Durchwahl).

export const NACHBAR_MAX_ABWEICHUNG = 4;

export function abgleichen(analyse, eintraege) {
  const leer = { genau: [], bereich: [], nachbarn: [] };
  if (!analyse || !analyse.national || !Array.isArray(eintraege)) return leer;
  const n = analyse.national;
  const mitNachbarn = analyse.art === 'ortsnetz';
  const mindest = mitNachbarn ? analyse.vorwahl.length + 3 : Infinity;
  const ergebnis = { genau: [], bereich: [], nachbarn: [] };

  for (const e of eintraege) {
    if (!e || !e.national) continue;
    if (e.bereich) {
      if (n.startsWith(e.national)) ergebnis.bereich.push({ ...e, gemeinsam: e.national.length });
      continue;
    }
    if (e.national === n) { ergebnis.genau.push(e); continue; }
    if (!mitNachbarn) continue;
    const gemeinsam = gemeinsamerAnfang(n, e.national);
    if (gemeinsam < mindest) continue;
    if (n.length - gemeinsam > NACHBAR_MAX_ABWEICHUNG) continue;
    if (e.national.length - gemeinsam > NACHBAR_MAX_ABWEICHUNG) continue;
    ergebnis.nachbarn.push({ ...e, gemeinsam });
  }
  ergebnis.bereich.sort((a, b) => b.gemeinsam - a.gemeinsam);
  ergebnis.nachbarn.sort((a, b) => b.gemeinsam - a.gemeinsam
    || zentraleZuerst(a.national) - zentraleZuerst(b.national));
  ergebnis.nachbarn = ergebnis.nachbarn.slice(0, 8);
  return ergebnis;
}

// Bei gleich langem Anfang: Nummern, die auf 0 enden (Zentrale), nach vorn.
function zentraleZuerst(national) {
  return national.endsWith('0') ? 0 : 1;
}

export function gemeinsamerAnfang(a, b) {
  const max = Math.min(a.length, b.length);
  let i = 0;
  while (i < max && a[i] === b[i]) i += 1;
  return i;
}
