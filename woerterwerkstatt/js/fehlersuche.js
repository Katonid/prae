// Fehlerdetektive — einen Text nach versteckten Rechtschreibfehlern absuchen.
//
// Jedes Wort ist antippbar; erst „Auswerten" verrät, was ein Fehler war.
// Bis dahin trägt kein Element im Dokument die Lösung — keine Klasse, kein
// `data-`, kein `title`, kein `aria-label`. Am Wort hängt nur seine laufende
// Nummer, die Lösung steht in `woerter` hier im Modul.
//
// Ausgewertet wird in drei Farben, und das bewusst gegen die Hausregel „kein
// Grün" (Vorgabe des Nutzers für genau diese Übung, 10/2026): grün =
// gefunden, rot = richtiges Wort markiert, orange = übersehen. Damit es nicht
// an der Farbe allein hängt, hat jede ihre eigene Linienart (unterstrichen,
// durchgestrichen, umrandet), und die Legende sagt es in Worten.
//
// Die Lösung kommt in STUFEN (ab 1.9.2, Ansage des Nutzers 10/2026: „liefert
// leider sofort auch die nicht gefundenen Wörter"). Jedes Prüfen geht eine
// Stufe weiter, dazwischen sucht das Kind weiter:
//   1. wie viele Fehler noch fehlen (gefunden grün, falsch markiert rot)
//   2. wie viele davon kleingeschriebene Nomen sind, wie viele andere
//   3. die ZEILEN, in denen noch Fehler stecken (Bänder über die ganze Breite)
//   4. die Lösung: übersehene Fehler orange, richtige Schreibweise antippbar
// Sind vorher alle gefunden und nichts falsch markiert, ist sofort Schluss.
//
// Ein Durchgang geht nach JEDEM Prüfen an `beiErgebnis`, immer unter
// demselben Schlüssel (Beginn): die Zahlen des ersten Prüfens bleiben stehen,
// `verlauf` kommt Prüfen für Prüfen dazu. Ob und wohin es gemeldet wird,
// entscheidet der Aufrufer (app.js → klasse.js).

import { h, leeren } from './util.js';
import * as sfx from './sfx.js';

/* ---------- Text zerlegen und prüfen ---------- */

// Markierung | Wort | Leerraum | Satzzeichen
const MUSTER = /\[\[([NS])\|([^|\]]+)\|([^|\]]+)\]\]|([\p{L}\p{N}]+(?:-[\p{L}\p{N}]+)*)|(\s+)|([^\s\p{L}\p{N}[]+)/gu;

function absatzZerlegen(absatz, probleme) {
  const teile = [];
  let gelesen = 0;
  MUSTER.lastIndex = 0;
  let m;
  while ((m = MUSTER.exec(absatz)) !== null) {
    if (m.index !== gelesen) probleme.push(`Unlesbare Stelle im Text: „${absatz.slice(gelesen, m.index)}“`);
    gelesen = MUSTER.lastIndex;
    if (m[1]) teile.push({ art: 'wort', text: m[2], richtig: m[3], typ: m[1] });
    else if (m[4]) teile.push({ art: 'wort', text: m[4], richtig: m[4], typ: null });
    else if (m[5]) teile.push({ art: 'leer', text: ' ' });
    else teile.push({ art: 'zeichen', text: m[6] });
  }
  if (gelesen !== absatz.length) probleme.push(`Unlesbares Textende: „${absatz.slice(gelesen)}“`);

  // Direkt aneinanderstoßende Wortteile sind EIN Wort:
  // [[S|gelp|gelb]]es → „gelpes“, richtig „gelbes“.
  const verbunden = [];
  for (const teil of teile) {
    const vorher = verbunden[verbunden.length - 1];
    if (teil.art === 'wort' && vorher && vorher.art === 'wort') {
      if (vorher.typ && teil.typ) probleme.push(`Zwei Fehler in einem Wort: „${vorher.text}${teil.text}“`);
      vorher.text += teil.text;
      vorher.richtig += teil.richtig;
      vorher.typ = vorher.typ || teil.typ;
    } else {
      verbunden.push(teil);
    }
  }
  return verbunden;
}

const zerlegt = new Map();

/**
 * Den Text in Absätze und Wörter zerlegen — und dabei nachzählen.
 *
 * Stimmt die Zahl der Fehler nicht mit `soll` überein, steht das laut in der
 * Konsole. Die Übung läuft trotzdem; die Auswertung rechnet mit der
 * tatsächlichen Zahl, damit „40 von 39" nie vorkommt.
 */
export function textZerlegen(text) {
  if (zerlegt.has(text.id)) return zerlegt.get(text.id);
  const probleme = [];
  const absaetze = text.text.split(/\n\s*\n/).map((a) => a.trim()).filter(Boolean)
    .map((a) => absatzZerlegen(a, probleme));

  const zahl = { N: 0, S: 0 };
  for (const teil of absaetze.flat()) {
    if (teil.art !== 'wort' || !teil.typ) continue;
    zahl[teil.typ] += 1;
    if (teil.text === teil.richtig) probleme.push(`Fehler ohne Unterschied: „${teil.text}“`);
    if (teil.typ === 'N') {
      const gross = teil.text.charAt(0).toUpperCase() + teil.text.slice(1);
      if (teil.text === gross || gross !== teil.richtig) {
        probleme.push(`N-Fehler ist keine reine Kleinschreibung: „${teil.text}“ → „${teil.richtig}“`);
      }
    }
  }
  const soll = text.soll || {};
  const gesamt = zahl.N + zahl.S;
  const sollGesamt = (soll.N || 0) + (soll.S || 0);
  if (zahl.N !== soll.N) probleme.push(`Typ N: ${zahl.N} statt ${soll.N} Fehler.`);
  if (zahl.S !== soll.S) probleme.push(`Typ S: ${zahl.S} statt ${soll.S} Fehler.`);
  if (gesamt !== sollGesamt) probleme.push(`Insgesamt: ${gesamt} statt ${sollGesamt} Fehler.`);

  if (probleme.length) {
    console.error(
      `%c FEHLERDETEKTIVE „${text.titel}“ – DER ÜBUNGSTEXT STIMMT NICHT! %c\n\n${probleme.join('\n')}`
      + `\n\nGezählt: N = ${zahl.N}, S = ${zahl.S}, gesamt = ${gesamt}`
      + ` (erwartet: N = ${soll.N}, S = ${soll.S}, gesamt = ${sollGesamt}).`,
      'background:#b91c1c;color:#fff;font-size:16px;font-weight:bold;padding:4px 8px;', '');
  } else {
    console.info(`Fehlerdetektive „${text.titel}“: ${zahl.N} × N, ${zahl.S} × S, insgesamt ${gesamt} Fehler.`);
  }
  const ergebnis = { absaetze, zahl, gesamt, ok: !probleme.length };
  zerlegt.set(text.id, ergebnis);
  return ergebnis;
}

/* ---------- Die Übung ---------- */

const ZAHL_WORT = (n, eins, viele) => `${n} ${n === 1 ? eins : viele}`;

/**
 * Baut die Übung in `platz` auf.
 *
 * `hinweis`  — ein Knoten über dem Text (ob das Ergebnis gemeldet wird)
 * `zurueck`  — wohin „‹ Zurück" führt
 * `beiErgebnis(ergebnis)` — nach jedem Tipp auf „Auswerten"
 *
 * Gibt eine Funktion zum Aufräumen zurück.
 */
export function fehlersucheStarten({ platz, text, hinweis = null, zurueck, beiErgebnis }) {
  const { absaetze, gesamt: fehlerzahl } = textZerlegen(text);

  const woerter = [];
  const spans = [];
  let markiert = [];
  let ausgewertet = false; // Stufe 4: die Lösung steht da
  let stufe = 0;           // 0 = noch nicht geprüft, 1–3 Tipps, 4 Lösung
  let offenesWort = -1;
  let beginn = Date.now();
  let erstesPruefen = null;
  let verlauf = [];
  let fehlendeZeilen = []; // Wortnummern, deren Zeilen Stufe 3 hervorhebt

  const anzahl = h('strong', {}, '0 Wörter');
  const ergebnisplatz = h('section', { class: 'detektiv__ergebnis', hidden: true, tabindex: '-1', 'aria-live': 'polite' });
  const blase = h('div', { class: 'detektiv__blase', role: 'status', hidden: true });
  const textplatz = h('div', { class: 'detektiv__text' });
  const baender = h('div', { class: 'detektiv__baender', 'aria-hidden': 'true' });
  const karte = h('div', { class: 'detektiv__karte' },
    h('h2', { class: 'detektiv__titel' }, text.titel), baender, textplatz, blase);
  const knopfAuswerten = h('button', { class: 'knopf knopf--voll detektiv__knopf', type: 'button' }, 'Auswerten');
  const naechsterTipp = h('p', { class: 'detektiv__naechstes', hidden: true });
  const knopfNochmal = h('button', { class: 'knopf knopf--still detektiv__knopf', type: 'button', hidden: true }, 'Noch einmal versuchen');
  const seite = h('div', { class: 'seite detektiv' },
    h('div', { class: 'seite__kopf' },
      h('button', { class: 'zurueck', type: 'button', onclick: zurueck }, '‹ Zur Auswahl'),
      ...(text.anleitung ? [
        // Eigener Wortlaut eines Textes (Übung 2 und folgende)
        h('h1', { class: 'seite__titel' }, `${text.anleitung.titel} 🔍`),
        ...text.anleitung.saetze.map((satz) => h('p', { class: 'detektiv__auftrag' }, satz)),
        h('p', { class: 'detektiv__auftrag detektiv__auftrag--leise' },
          h('strong', {}, text.anleitung.achtung[0]), text.anleitung.achtung[1]),
      ] : [
        // Übung 1 — Wortlaut unverändert seit 1.9.0
        h('h1', { class: 'seite__titel' }, 'Fehlerdetektive 🔍 – Findest du alle Fehler?'),
        h('p', { class: 'detektiv__auftrag' },
          'Im Text haben sich ', h('strong', {}, `${fehlerzahl} Rechtschreibfehler`),
          ' versteckt. Tippe auf jedes Wort, das deiner Meinung nach falsch geschrieben ist.'),
        h('p', { class: 'detektiv__auftrag detektiv__auftrag--leise' },
          h('strong', {}, 'Achtung:'), ' Viele schwierige Wörter sind vollkommen richtig geschrieben!'),
      ]),
      hinweis,
      ergebnisplatz),
    h('p', { class: 'detektiv__zaehler', 'aria-live': 'polite' }, 'Markiert: ', anzahl),
    karte,
    h('div', { class: 'detektiv__knoepfe' }, knopfAuswerten, knopfNochmal),
    naechsterTipp);

  for (const teile of absaetze) {
    const p = h('p', {});
    for (const teil of teile) {
      if (teil.art !== 'wort') { p.appendChild(document.createTextNode(teil.text)); continue; }
      const i = woerter.length;
      woerter.push({ text: teil.text, richtig: teil.richtig, typ: teil.typ });
      const span = h('span', { class: 'detektiv__wort', role: 'button', tabindex: '0', 'aria-pressed': 'false', 'data-i': String(i) }, teil.text);
      spans.push(span);
      p.appendChild(span);
    }
    textplatz.appendChild(p);
  }
  markiert = woerter.map(() => false);

  function anzahlZeigen() {
    const n = markiert.filter(Boolean).length;
    anzahl.textContent = ZAHL_WORT(n, 'Wort', 'Wörter');
  }

  function umschalten(i) {
    markiert[i] = !markiert[i];
    // Grün oder Rot vom letzten Prüfen gilt nach einer Änderung nicht mehr —
    // was das Kind jetzt markiert, ist wieder gelb, bis es neu prüft.
    spans[i].classList.remove('is-gefunden', 'is-falsch');
    spans[i].removeAttribute('aria-label');
    spans[i].classList.toggle('is-markiert', markiert[i]);
    spans[i].setAttribute('aria-pressed', markiert[i] ? 'true' : 'false');
    anzahlZeigen();
  }

  /* Die Einblendung mit der richtigen Schreibweise. */

  function blaseZu() {
    if (offenesWort >= 0) spans[offenesWort].classList.remove('is-offen');
    offenesWort = -1;
    blase.hidden = true;
    leeren(blase);
  }

  function blaseAuf(i) {
    const wort = woerter[i];
    if (!wort.typ && !markiert[i]) { blaseZu(); return; }
    if (offenesWort === i) { blaseZu(); return; }
    blaseZu();
    if (wort.typ) {
      blase.append(
        h('span', { class: 'detektiv__alt' }, wort.text), ' → ',
        h('span', { class: 'detektiv__neu' }, wort.richtig),
        h('span', { class: 'detektiv__regel' },
          wort.typ === 'N' ? 'Nomen schreibt man groß.' : 'So schreibt man das Wort richtig.'));
    } else {
      blase.append(h('strong', {}, `„${wort.text}“`), ' ist richtig geschrieben.');
    }
    offenesWort = i;
    spans[i].classList.add('is-offen');
    blase.hidden = false;

    // Unter das Wort, innerhalb der Karte
    const k = karte.getBoundingClientRect();
    const zeilen = spans[i].getClientRects();
    const r = zeilen[zeilen.length - 1] || spans[i].getBoundingClientRect();
    const breite = blase.offsetWidth;
    const mitte = r.left + r.width / 2 - k.left;
    const links = Math.max(8, Math.min(mitte - breite / 2, k.width - breite - 8));
    blase.style.left = `${links}px`;
    blase.style.top = `${r.bottom - k.top + 10}px`;
    blase.style.setProperty('--pfeil', `${Math.max(16, Math.min(mitte - links, breite - 16))}px`);
  }

  function angetippt(i) {
    if (ausgewertet) blaseAuf(i);
    else umschalten(i);
  }

  textplatz.addEventListener('click', (ereignis) => {
    const span = ereignis.target.closest('.detektiv__wort');
    if (!span) return;
    ereignis.stopPropagation();
    angetippt(Number(span.dataset.i));
  });
  textplatz.addEventListener('keydown', (ereignis) => {
    if (ereignis.key !== 'Enter' && ereignis.key !== ' ') return;
    const span = ereignis.target.closest('.detektiv__wort');
    if (!span) return;
    ereignis.preventDefault();
    angetippt(Number(span.dataset.i));
  });
  const beiKlick = (ereignis) => { if (offenesWort >= 0 && !blase.contains(ereignis.target)) blaseZu(); };
  const beiTaste = (ereignis) => { if (ereignis.key === 'Escape') blaseZu(); };
  document.addEventListener('click', beiKlick);
  document.addEventListener('keydown', beiTaste);
  // Drehen des iPads bricht die Zeilen neu um — die Bänder ziehen mit.
  const beiGroesse = () => { blaseZu(); zeilenZeichnen(); };
  window.addEventListener('resize', beiGroesse);

  /* Prüfen — in Stufen */

  function bewerten() {
    const stand = { gefunden: 0, uebersehen: 0, falsch: 0, gefundenN: 0, gefundenS: 0, fehltN: 0, fehltS: 0 };
    const uebersehen = [];
    const falsch = [];
    woerter.forEach((wort, i) => {
      if (wort.typ && markiert[i]) {
        stand.gefunden += 1; stand[`gefunden${wort.typ}`] += 1;
      } else if (wort.typ) {
        stand.uebersehen += 1; stand[`fehlt${wort.typ}`] += 1;
        uebersehen.push({ w: wort.text, r: wort.richtig, t: wort.typ, i });
      } else if (markiert[i]) {
        stand.falsch += 1;
        falsch.push(wort.text);
      }
    });
    return { stand, uebersehen, falsch };
  }

  /** Gefunden grün, falsch markiert rot — die übersehenen bleiben verborgen. */
  function farbenSetzen() {
    woerter.forEach((wort, i) => {
      const span = spans[i];
      span.classList.remove('is-markiert', 'is-gefunden', 'is-falsch');
      span.removeAttribute('aria-label');
      if (!markiert[i]) return;
      span.classList.add(wort.typ ? 'is-gefunden' : 'is-falsch');
      span.setAttribute('aria-label', `${wort.text} – ${wort.typ ? 'Fehler gefunden' : 'war richtig geschrieben'}`);
    });
  }

  /**
   * Stufe 3: Bänder über die Zeilen, in denen noch ein Fehler steckt.
   *
   * Gemeint sind die Zeilen, wie sie auf DIESEM Bildschirm umbrechen — im
   * Hoch- und im Querformat sind das andere. Deshalb wird bei jeder
   * Größenänderung neu gezeichnet, aus den Wortnummern, nicht aus Pixeln.
   * Ein Band geht über die ganze Breite des Textes, sonst verriete es das Wort.
   */
  function zeilenZeichnen() {
    leeren(baender);
    if (stufe !== 3 || ausgewertet || !fehlendeZeilen.length) return;
    const k = karte.getBoundingClientRect();
    const t = textplatz.getBoundingClientRect();
    const zeilen = new Map();
    for (const i of fehlendeZeilen) {
      for (const r of spans[i].getClientRects()) {
        const mitte = Math.round((r.top + r.bottom) / 2);
        // Wörter derselben Zeile liegen auf derselben Höhe (±4 px)
        const gleich = Array.from(zeilen.keys()).find((m) => Math.abs(m - mitte) <= 4);
        if (gleich === undefined) zeilen.set(mitte, r);
      }
    }
    for (const r of zeilen.values()) {
      baender.appendChild(h('div', {
        class: 'detektiv__band',
        style: {
          top: `${r.top - k.top - 2}px`,
          height: `${r.height + 4}px`,
          left: `${t.left - k.left - 10}px`,
          width: `${t.width + 20}px`,
        },
      }));
    }
  }

  function melden(bewertet, ende) {
    if (!beiErgebnis) return;
    const { stand, uebersehen, falsch } = bewertet;
    verlauf.push({
      stufe, g: stand.gefunden, f: stand.falsch, n: stand.gefundenN, s: stand.gefundenS,
      d: Math.max(0, Math.round((ende - beginn) / 1000)),
    });
    if (!erstesPruefen) {
      // Die Zahlen des ERSTEN Prüfens — das ist, was das Kind ohne Hilfe sah.
      // Die Klassenansicht liest sie wie bisher (gefunden, ue, fa …).
      erstesPruefen = {
        ende,
        dauer: Math.max(0, Math.round((ende - beginn) / 1000)),
        gefunden: stand.gefunden,
        gefundenN: stand.gefundenN,
        gefundenS: stand.gefundenS,
        uebersehen: stand.uebersehen,
        falsch: stand.falsch,
        // Die falsch markierten richtigen Wörter werden gedeckelt: Wer aus
        // Trotz alles antippt, schickt sonst 300 Wörter mit.
        ue: uebersehen.map(({ w, r, t }) => ({ w, r, t })),
        fa: falsch.slice(0, 40),
      };
    }
    beiErgebnis(Object.assign({
      text: text.id,
      titel: text.titel,
      beginn,
      fehler: fehlerzahl,
    }, erstesPruefen, {
      verlauf: verlauf.slice(),
      loesung: ausgewertet && !(stand.gefunden === fehlerzahl && stand.falsch === 0),
      geschafft: stand.gefunden === fehlerzahl && stand.falsch === 0,
    }));
  }

  const zeile = (inhalt, klasse = '') => h('p', { class: klasse }, inhalt);

  function pruefen() {
    const ende = Date.now();
    blaseZu();
    const bewertet = bewerten();
    const { stand } = bewertet;
    stufe = Math.min(4, stufe + 1);
    const perfekt = stand.gefunden === fehlerzahl && stand.falsch === 0;
    if (perfekt || stufe === 4) {
      loesungZeigen(bewertet, perfekt);
      melden(bewertet, ende);
      return;
    }

    farbenSetzen();
    fehlendeZeilen = bewertet.uebersehen.map((f) => f.i);
    leeren(ergebnisplatz);
    ergebnisplatz.classList.remove('is-perfekt');
    ergebnisplatz.append(zeile(stand.gefunden === fehlerzahl
      ? `Super! Du hast alle ${fehlerzahl} Fehler gefunden!`
      : `Du hast ${stand.gefunden} von ${fehlerzahl} Fehlern gefunden.`, 'detektiv__haupt'));
    if (stand.uebersehen) {
      ergebnisplatz.append(zeile(stand.uebersehen === 1
        ? '1 Fehler hast du noch nicht gefunden.'
        : `${stand.uebersehen} Fehler hast du noch nicht gefunden.`));
    }
    if (stufe >= 2 && stand.uebersehen) {
      ergebnisplatz.append(zeile(
        `Davon ${stand.fehltN === 1 ? 'ist 1 ein kleingeschriebenes Nomen' : `sind ${stand.fehltN} kleingeschriebene Nomen`}`
        + ` und ${stand.fehltS === 1 ? '1 ein anderer Fehler' : `${stand.fehltS} andere Fehler`}.`, 'detektiv__tipp-zeile'));
    }
    if (stufe >= 3 && stand.uebersehen) {
      ergebnisplatz.append(zeile('In den gelb hinterlegten Zeilen steckt noch mindestens ein Fehler.', 'detektiv__tipp-zeile'));
    }
    ergebnisplatz.append(zeile(stand.falsch
      ? `${stand.falsch === 1 ? '1 richtiges Wort' : `${stand.falsch} richtige Wörter`} hast du versehentlich markiert (rot).`
      : 'Du hast kein richtiges Wort versehentlich markiert.'));
    ergebnisplatz.append(
      h('ul', { class: 'detektiv__legende' },
        ...[['gefunden', 'gefunden'], ['falsch', 'war richtig']].map(([art, wort]) => h('li', {},
          h('span', { class: `detektiv__probe is-${art}`, 'aria-hidden': 'true' }), wort))),
      zeile('Such weiter! Du kannst weiter Wörter antippen — auch rote, um sie abzuwählen.', 'detektiv__tipp'));
    ergebnisplatz.hidden = false;

    knopfAuswerten.textContent = 'Noch einmal prüfen';
    naechsterTipp.textContent = [
      '',
      'Beim nächsten Prüfen erfährst du, wie viele davon kleingeschriebene Nomen sind und wie viele andere Fehler.',
      'Beim nächsten Prüfen siehst du, in welchen Zeilen noch Fehler stecken.',
      'Beim nächsten Prüfen siehst du die Lösung.',
    ][stufe];
    naechsterTipp.hidden = false;

    zeilenZeichnen();
    ergebnisplatz.scrollIntoView({ block: 'center' });
    ergebnisplatz.focus({ preventScroll: true });
    melden(bewertet, ende);
  }

  /** Stufe 4 — oder vorher, wenn alles gefunden ist: die ganze Lösung. */
  function loesungZeigen({ stand }, perfekt) {
    woerter.forEach((wort, i) => {
      const span = spans[i];
      span.classList.remove('is-markiert', 'is-gefunden', 'is-falsch');
      let art = null;
      let beschreibung = '';
      if (wort.typ && markiert[i]) {
        art = 'gefunden';
        beschreibung = `Fehler gefunden. Richtig: ${wort.richtig}`;
      } else if (wort.typ) {
        art = 'uebersehen';
        beschreibung = `Fehler übersehen. Richtig: ${wort.richtig}`;
      } else if (markiert[i]) {
        art = 'falsch';
        beschreibung = 'war richtig geschrieben';
      }
      span.removeAttribute('aria-pressed');
      span.removeAttribute('aria-label');
      if (art) {
        span.classList.add(`is-${art}`);
        span.setAttribute('aria-label', `${wort.text} – ${beschreibung}`);
      } else {
        span.removeAttribute('role');
        span.setAttribute('tabindex', '-1');
      }
    });
    ausgewertet = true;
    stufe = 4;
    seite.classList.add('is-ausgewertet');
    fehlendeZeilen = [];
    leeren(baender);

    leeren(ergebnisplatz);
    ergebnisplatz.classList.toggle('is-perfekt', perfekt);
    if (perfekt) {
      ergebnisplatz.append(
        zeile(`Fantastisch! Du hast alle ${fehlerzahl} Fehler gefunden! 🎉`, 'detektiv__haupt'),
        zeile('Und du hast kein einziges richtiges Wort markiert. Ein echter Fehlerdetektiv!'));
      sfx.fertig(3);
    } else {
      ergebnisplatz.append(zeile(stand.gefunden === fehlerzahl
        ? `Super! Du hast alle ${fehlerzahl} Fehler gefunden!`
        : `Du hast ${stand.gefunden} von ${fehlerzahl} Fehlern gefunden.`, 'detektiv__haupt'));
      if (stand.uebersehen) {
        ergebnisplatz.append(zeile(`${ZAHL_WORT(stand.uebersehen, 'Fehler', 'Fehler')} hast du übersehen. Sie sind jetzt orange.`));
      }
      ergebnisplatz.append(zeile(stand.falsch
        ? `${stand.falsch === 1 ? '1 richtiges Wort' : `${stand.falsch} richtige Wörter`} hast du versehentlich markiert.`
        : 'Du hast kein richtiges Wort versehentlich markiert.'));
    }
    ergebnisplatz.append(
      h('ul', { class: 'detektiv__legende' },
        ...[['gefunden', 'gefunden'], ['uebersehen', 'übersehen'], ['falsch', 'war richtig']].map(([art, wort]) => h('li', {},
          h('span', { class: `detektiv__probe is-${art}`, 'aria-hidden': 'true' }), wort))),
      zeile('Tippe auf ein farbiges Wort, um die richtige Schreibweise zu sehen.', 'detektiv__tipp'));
    ergebnisplatz.hidden = false;
    knopfAuswerten.hidden = true;
    knopfNochmal.hidden = false;
    naechsterTipp.hidden = true;
    ergebnisplatz.scrollIntoView({ block: 'center' });
    ergebnisplatz.focus({ preventScroll: true });
  }

  function zuruecksetzen() {
    blaseZu();
    ausgewertet = false;
    stufe = 0;
    erstesPruefen = null;
    verlauf = [];
    fehlendeZeilen = [];
    leeren(baender);
    knopfAuswerten.textContent = 'Auswerten';
    naechsterTipp.hidden = true;
    seite.classList.remove('is-ausgewertet');
    markiert = woerter.map(() => false);
    for (const span of spans) {
      span.className = 'detektiv__wort';
      span.setAttribute('role', 'button');
      span.setAttribute('tabindex', '0');
      span.setAttribute('aria-pressed', 'false');
      span.removeAttribute('aria-label');
    }
    leeren(ergebnisplatz);
    ergebnisplatz.hidden = true;
    ergebnisplatz.classList.remove('is-perfekt');
    knopfAuswerten.hidden = false;
    knopfNochmal.hidden = true;
    anzahlZeigen();
    beginn = Date.now();
    window.scrollTo(0, 0);
  }

  knopfAuswerten.addEventListener('click', pruefen);
  knopfNochmal.addEventListener('click', zuruecksetzen);

  anzahlZeigen();
  leeren(platz).appendChild(seite);
  window.scrollTo(0, 0);

  return () => {
    document.removeEventListener('click', beiKlick);
    document.removeEventListener('keydown', beiTaste);
    window.removeEventListener('resize', beiGroesse);
  };
}
