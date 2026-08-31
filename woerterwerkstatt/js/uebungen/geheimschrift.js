// Stufe 3 — Geheimschrift.
//
// Vom Wort ist nur noch die Gestalt übrig: wie viele Buchstaben, welcher davon
// groß, und in welchem Stockwerk des Buchstabenhauses jeder wohnt. Das ist die
// klassische Wortbild- oder Konturübung aus dem Rechtschreibunterricht — nur
// dass sie hier nicht mit dem Bleistift umrandet, sondern gelesen wird.
//
// Warum das eine echte Rechtschreibübung ist: Wer „Kaninchen“ von „Kaninchan“
// unterscheiden soll, muss das Wortbild gespeichert haben. Genau daran hängt
// die Rechtschreibsicherheit — sie kommt aus dem Gedächtnis für Wortbilder,
// nicht aus Regeln.
//
// Damit die Übung lösbar bleibt, steht der Themenbereich als Hilfe darüber und
// die Zahl der Buchstaben darunter. Wer gar nicht draufkommt, kann sich das
// Wort einmal vorsagen lassen (dann ist es aber schon eine Diktatübung — und
// wird als Hilfe gezählt).

import { h } from '../util.js';
import { schreibform, wortkern } from '../grammatik.js';
import { wortbild, buchstabenzahl, musterPasst } from '../wortbild.js';
import { einstellungen } from '../store.js';
import { schreibfeld } from './schreibfeld.js';
import * as sfx from '../sfx.js';

export const UEBUNG = {
  id: 'geheimschrift',
  nummer: 3,
  name: 'Geheimschrift',
  kurz: 'Lies das Wortbild',
  emoji: '🔎',
  farbe: '#eab308',
  beschreibung: 'Nur die Gestalt des Wortes ist zu sehen: groß oder klein, Dach, Mitte oder Keller.',

  aufbauen({ eintrag, bereich, aufFertig }) {
    const wort = wortkern(eintrag);
    const loesung = schreibform(eintrag);
    const e = einstellungen();
    let modus = e.geheimschrift || 'haus';
    let hilfen = 0;

    const bildplatz = h('div', { class: 'vorlage vorlage--wortbild' });
    const zeichnen = () => {
      bildplatz.textContent = '';
      bildplatz.appendChild(wortbild(wort, { modus, linien: e.hilfslinien !== false, beschriftet: false }));
    };
    zeichnen();

    const umschalter = h('button', { class: 'knopf knopf--still knopf--klein', type: 'button' },
      modus === 'haus' ? '🏠 Häuschen' : '〰️ Umriss');
    umschalter.addEventListener('click', () => {
      modus = modus === 'haus' ? 'umriss' : 'haus';
      umschalter.textContent = modus === 'haus' ? '🏠 Häuschen' : '〰️ Umriss';
      zeichnen();
      sfx.tipp();
    });

    const legende = h('div', { class: 'wortbild-legende' },
      h('span', { class: 'wortbild-legende__eintrag' }, h('i', { class: 'wortbild-legende__probe is-gross' }), 'großer Buchstabe'),
      h('span', { class: 'wortbild-legende__eintrag' }, h('i', { class: 'wortbild-legende__probe is-oben' }), 'Dach: b d f h k l t'),
      h('span', { class: 'wortbild-legende__eintrag' }, h('i', { class: 'wortbild-legende__probe is-mitte' }), 'Mitte: a e i m n o …'),
      h('span', { class: 'wortbild-legende__eintrag' }, h('i', { class: 'wortbild-legende__probe is-unten' }), 'Keller: g j p q y'));

    const wurzel = h('div', { class: 'uebung uebung--geheim' },
      bereich ? h('p', { class: 'uebung__spur' }, `Aus dem Bereich: ${bereich.emoji || ''} ${bereich.name}`) : null,
      bildplatz,
      h('div', { class: 'uebung__werkzeuge' },
        h('span', { class: 'uebung__zaehler' }, `${buchstabenzahl(wort)} Buchstaben`),
        umschalter),
      legende);

    const feld = schreibfeld({
      loesung,
      platzhalter: 'Das versteckte Wort',
      hinweis: eintrag.art === 'n' ? 'Nomen bitte mit Artikel — im Bild steht nur das Wort selbst.' : '',
      // Passt die Eingabe nicht einmal ins Häuschen, sagt die App genau das:
      // Es ist die Rückmeldung, um die es in dieser Übung geht.
      zusatzhinweis: (eingabe) => {
        const kern = eintrag.art === 'n' ? eingabe.replace(/^(der|die|das)\s+/i, '') : eingabe;
        if (musterPasst(kern, wort)) return 'Dein Wort passt genau ins Häuschen — aber es ist ein anderes.';
        return 'Dein Wort passt nicht ins Häuschen. Zähl die Buchstaben und schau auf die Stockwerke.';
      },
      aufFertig: (ergebnis) => aufFertig(Object.assign({}, ergebnis, { hilfen })),
    });
    wurzel.appendChild(feld.wurzel);
    return wurzel;
  },
};
