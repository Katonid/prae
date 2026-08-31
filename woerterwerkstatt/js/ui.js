// Bausteine der Oberfläche: Blätter, Meldungen, Knöpfe, Sterne.
// Nichts davon weiß etwas über Rechtschreibung — hier geht es nur um Form.

import { h, leeren, wenigBewegung } from './util.js';

const blattWurzel = () => document.getElementById('blatt-wurzel');
const meldungWurzel = () => document.getElementById('meldung-wurzel');

/**
 * Kurze Meldung am unteren Rand. Bewusst ohne Knopf: Was hier steht, muss man
 * nicht wegklicken können — es verschwindet von selbst.
 */
export function meldung(text, art = 'info', dauer = 2600) {
  const wurzel = meldungWurzel();
  if (!wurzel) return;
  const knoten = h('div', { class: `meldung meldung--${art}` }, text);
  wurzel.appendChild(knoten);
  setTimeout(() => {
    knoten.classList.add('is-weg');
    setTimeout(() => knoten.remove(), 320);
  }, dauer);
}

/**
 * Ein Blatt (Modal). Gibt ein Objekt mit `schliessen()` zurück.
 *
 * `beimSchliessen` wird immer gerufen — auch beim Tippen daneben und bei Esc.
 */
export function blatt({ titel, breit = false, inhalt, fusszeile = null, beimSchliessen = null }) {
  const wurzel = blattWurzel();
  const koerper = h('div', { class: 'blatt__koerper' });
  const kasten = h('div', { class: `blatt${breit ? ' blatt--breit' : ''}` },
    h('header', { class: 'blatt__kopf' },
      h('h2', { class: 'blatt__titel' }, titel),
      h('button', { class: 'blatt__zu', type: 'button', title: 'Schließen', 'aria-label': 'Schließen', onclick: () => zu() }, '✕')),
    koerper,
    fusszeile ? h('footer', { class: 'blatt__fuss' }, fusszeile) : null);
  const hintergrund = h('div', { class: 'blatt-grund', onclick: (ereignis) => { if (ereignis.target === hintergrund) zu(); } }, kasten);

  let offen = true;
  function zu() {
    if (!offen) return;
    offen = false;
    hintergrund.classList.add('is-weg');
    document.removeEventListener('keydown', beiTaste);
    setTimeout(() => hintergrund.remove(), wenigBewegung() ? 0 : 220);
    if (beimSchliessen) beimSchliessen();
  }
  function beiTaste(ereignis) {
    if (ereignis.key === 'Escape') { ereignis.preventDefault(); zu(); }
  }
  document.addEventListener('keydown', beiTaste);

  const gefuellt = typeof inhalt === 'function' ? inhalt({ schliessen: zu, koerper }) : inhalt;
  if (gefuellt) koerper.appendChild(gefuellt);
  wurzel.appendChild(hintergrund);
  // Erst nach dem Einhängen fokussieren, sonst springt Safari an den Anfang.
  requestAnimationFrame(() => {
    const erstes = koerper.querySelector('input, textarea, select, button');
    if (erstes && !('ontouchstart' in window)) erstes.focus();
  });
  return { schliessen: zu, koerper, kasten };
}

/** Rückfrage mit zwei Knöpfen. Gibt ein Versprechen auf true/false. */
export function frage({ titel, text, ja = 'Ja', nein = 'Abbrechen', gefahr = false }) {
  return new Promise((antwort) => {
    let entschieden = false;
    const fertig = (wert) => { if (!entschieden) { entschieden = true; antwort(wert); } };
    const dialog = blatt({
      titel,
      inhalt: h('p', { class: 'blatt__text' }, text),
      fusszeile: [
        h('button', { class: 'knopf knopf--still', type: 'button', onclick: () => { fertig(false); dialog.schliessen(); } }, nein),
        h('button', { class: `knopf ${gefahr ? 'knopf--gefahr' : 'knopf--voll'}`, type: 'button', onclick: () => { fertig(true); dialog.schliessen(); } }, ja),
      ],
      beimSchliessen: () => fertig(false),
    });
  });
}

/**
 * Ein Blatt mit einem einzigen Eingabefeld. Ersetzt `window.prompt` — das gibt
 * es zwar im Browser, wird in einer späteren nativen Hülle (WKWebView) aber
 * nur beantwortet, wenn die Hülle es ausdrücklich abfängt. Sonst passiert
 * schlicht nichts, ohne jede Fehlermeldung.
 */
export function eingabe({ titel, text, wert = '', platzhalter = '', art = 'text', pruefung = null, ja = 'Übernehmen' }) {
  return new Promise((antwort) => {
    let entschieden = false;
    const fertig = (ergebnis) => { if (!entschieden) { entschieden = true; antwort(ergebnis); } };
    const feld = h('input', {
      class: 'feld feld--gross', type: 'text', inputmode: art === 'zahl' ? 'numeric' : 'text',
      value: wert, placeholder: platzhalter, autocomplete: 'off', spellcheck: 'false',
    });
    const fehler = h('p', { class: 'blatt__fehler', 'aria-live': 'polite' });
    const uebernehmen = () => {
      const eingegeben = feld.value.trim();
      const beschwerde = pruefung ? pruefung(eingegeben) : null;
      if (beschwerde) { fehler.textContent = beschwerde; feld.focus(); return; }
      fertig(eingegeben);
      dialog.schliessen();
    };
    feld.addEventListener('keydown', (ereignis) => {
      if (ereignis.key === 'Enter') { ereignis.preventDefault(); uebernehmen(); }
    });
    const dialog = blatt({
      titel,
      inhalt: h('div', {}, text ? h('p', { class: 'blatt__text' }, text) : null, feld, fehler),
      fusszeile: [
        h('button', { class: 'knopf knopf--still', type: 'button', onclick: () => dialog.schliessen() }, 'Abbrechen'),
        h('button', { class: 'knopf knopf--voll', type: 'button', onclick: uebernehmen }, ja),
      ],
      beimSchliessen: () => fertig(null),
    });
  });
}

/** Abschnitt mit Überschrift — die Grundform aller Einstellungsblätter. */
export function abschnitt(titel, ...kinder) {
  return h('section', { class: 'abschnitt' },
    titel ? h('h3', { class: 'abschnitt__titel' }, titel) : null,
    ...kinder);
}

/** Zeile mit Beschriftung links und Bedienelement rechts. */
export function zeile(beschriftung, bedienung, hinweis = '') {
  return h('div', { class: 'zeile' },
    h('div', { class: 'zeile__text' },
      h('span', { class: 'zeile__label' }, beschriftung),
      hinweis ? h('span', { class: 'zeile__hinweis' }, hinweis) : null),
    h('div', { class: 'zeile__bedienung' }, bedienung));
}

export function schalter(anfangs, beiWechsel) {
  const knopf = h('button', {
    class: `schalter${anfangs ? ' is-an' : ''}`,
    type: 'button',
    role: 'switch',
    'aria-checked': anfangs ? 'true' : 'false',
  }, h('span', { class: 'schalter__knauf' }));
  knopf.addEventListener('click', () => {
    const neu = !knopf.classList.contains('is-an');
    knopf.classList.toggle('is-an', neu);
    knopf.setAttribute('aria-checked', neu ? 'true' : 'false');
    beiWechsel(neu);
  });
  return knopf;
}

/** Auswahl aus wenigen Möglichkeiten — als Reihe von Knöpfen, nicht als Liste. */
export function auswahl(werte, aktuell, beiWahl) {
  const gruppe = h('div', { class: 'auswahl', role: 'radiogroup' });
  for (const wert of werte) {
    const knopf = h('button', {
      class: `auswahl__knopf${wert.id === aktuell ? ' is-aktiv' : ''}`,
      type: 'button',
      role: 'radio',
      'aria-checked': wert.id === aktuell ? 'true' : 'false',
      title: wert.hinweis || '',
      onclick: () => {
        gruppe.querySelectorAll('.auswahl__knopf').forEach((k) => {
          k.classList.remove('is-aktiv');
          k.setAttribute('aria-checked', 'false');
        });
        knopf.classList.add('is-aktiv');
        knopf.setAttribute('aria-checked', 'true');
        beiWahl(wert.id);
      },
    }, wert.emoji ? h('span', { class: 'auswahl__emoji' }, wert.emoji) : null, wert.label);
    gruppe.appendChild(knopf);
  }
  return gruppe;
}

/** Sterne als Zeichenkette — überall gleich, damit nichts auseinanderläuft. */
export function sterne(zahl, von = 3) {
  const reihe = h('span', { class: 'sterne', 'aria-label': `${zahl} von ${von} Sternen` });
  for (let i = 0; i < von; i += 1) {
    reihe.appendChild(h('span', { class: `sterne__stern${i < zahl ? ' is-voll' : ''}` }, i < zahl ? '★' : '☆'));
  }
  return reihe;
}

/** Fortschrittsbalken 0…1. */
export function balken(anteil, beschriftung = '') {
  return h('div', { class: 'balken', role: 'progressbar', 'aria-valuenow': Math.round(anteil * 100), 'aria-valuemin': 0, 'aria-valuemax': 100, 'aria-label': beschriftung },
    h('i', { style: { width: `${Math.round(Math.max(0, Math.min(1, anteil)) * 100)}%` } }));
}

export function ladeplatz(text = 'Einen Augenblick …') {
  return h('div', { class: 'ladeplatz' }, h('span', { class: 'ladeplatz__kringel' }), text);
}

export { leeren };
