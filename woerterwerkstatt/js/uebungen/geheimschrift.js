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
// die Zahl der Buchstaben darunter.
//
// Und darunter die WÖRTER DES PÄCKCHENS (ab 1.6.0, Ansage des Nutzers,
// 08/2026: „Ich glaube nicht, dass die Kinder nach zweimal üben alle Wörter so
// auswendig können, dass sie erkennen, welches Wort gemeint sein könnte.").
// Er hat recht, und es ist keine Erleichterung, sondern die Wiederherstellung
// der Aufgabe: Im Heft steht die Wortliste daneben und man ZUORDNET — ohne sie
// prüft die Übung das Gedächtnis für fünfzehn Wörter, nicht das Wortbild.
// Geschrieben werden muss trotzdem, und bei Nomen mit Artikel; die Liste zeigt
// nur die Wortkerne, wie sie auch im Bild stehen.
//
// Wegschalten geht (Knopf), und die Entscheidung bleibt gespeichert: Wer die
// Wörter dreimal geübt hat, darf es ohne Netz versuchen.

import { h } from '../util.js';
import { schreibform, wortkern } from '../grammatik.js';
import { wortbild, buchstabenzahl, musterPasst } from '../wortbild.js';
import { einstellungen, setzeEinstellung } from '../store.js';
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

  aufbauen({ eintrag, bereich, paket = [], aufFertig }) {
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
      // „dicker Strich links" ist das Kennzeichen, auf das die Klasse trainiert
      // ist — es unterscheidet den großen Buchstaben von b, d, f, h, k, l, t
      // und ß, die auch ins Dach ragen. Die Legende muss es benennen.
      h('span', { class: 'wortbild-legende__eintrag' }, h('i', { class: 'wortbild-legende__probe is-gross' }), 'groß: dicker Strich links'),
      h('span', { class: 'wortbild-legende__eintrag' }, h('i', { class: 'wortbild-legende__probe is-oben' }), 'Dach: b d f h k l t'),
      h('span', { class: 'wortbild-legende__eintrag' }, h('i', { class: 'wortbild-legende__probe is-mitte' }), 'Mitte: a e i m n o …'),
      h('span', { class: 'wortbild-legende__eintrag' }, h('i', { class: 'wortbild-legende__probe is-unten' }), 'Keller: g j p q y'));

    // Die Wörter des Päckchens, alphabetisch — die Reihenfolge im Päckchen
    // würde sonst verraten, welches gerade dran ist. Doppelte fallen weg
    // (ein Wort kann in zwei Formen vorkommen).
    const bankwoerter = Array.from(new Set(paket.map(wortkern)))
      .sort((a, b) => a.localeCompare(b, 'de'));
    const bank = h('div', { class: 'wortbank__woerter' },
      ...bankwoerter.map((w) => h('span', { class: 'wortbank__wort' }, w)));
    let bankAn = e.geheimWortliste !== false;
    const bankkasten = h('div', { class: `wortbank${bankAn ? '' : ' is-versteckt'}` }, bank);
    const bankknopf = h('button', { class: 'knopf knopf--still knopf--klein', type: 'button' },
      bankAn ? '📖 Wörter verbergen' : '📖 Wörter zeigen');
    bankknopf.addEventListener('click', () => {
      bankAn = !bankAn;
      bankkasten.classList.toggle('is-versteckt', !bankAn);
      bankknopf.textContent = bankAn ? '📖 Wörter verbergen' : '📖 Wörter zeigen';
      setzeEinstellung('geheimWortliste', bankAn);
      sfx.tipp();
    });

    const wurzel = h('div', { class: 'uebung uebung--geheim' },
      bereich ? h('p', { class: 'uebung__spur' }, `Aus dem Bereich: ${bereich.emoji || ''} ${bereich.name}`) : null,
      bildplatz,
      h('div', { class: 'uebung__werkzeuge' },
        h('span', { class: 'uebung__zaehler' }, `${buchstabenzahl(wort)} Buchstaben`),
        umschalter,
        bankwoerter.length > 1 ? bankknopf : null),
      legende,
      bankwoerter.length > 1 ? bankkasten : null);

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
