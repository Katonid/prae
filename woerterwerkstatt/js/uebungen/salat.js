// Stufe 2 — Buchstabensalat.
//
// Die Buchstaben des Wortes liegen durcheinander da; das Kind erkennt das Wort
// und schreibt es auf. Anders als beim Abschreiben ist die Vorlage jetzt kein
// Bild mehr, das man abmalen kann — die Reihenfolge muss aus dem Kopf kommen.
//
// Zwei Feinheiten, die die Übung erst brauchbar machen:
//
// * **Die Buchstaben werden angezeigt, wie sie im Wort stehen** — ein großes B
//   bleibt groß. Sonst würde die Übung die Großschreibung verraten oder, noch
//   schlimmer, ihr widersprechen.
// * **Es wird geprüft, dass wirklich gemischt wurde.** Ein „Salat“, der zufällig
//   das fertige Wort zeigt, ist keiner (bei kurzen Wörtern passiert das oft).

import { h, gemischt } from '../util.js';
import { schreibform, wortkern } from '../grammatik.js';
import { schreibfeld } from './schreibfeld.js';
import * as sfx from '../sfx.js';

/** Mischt, bis die Reihenfolge sich wirklich unterscheidet. */
function wirklichGemischt(buchstaben) {
  const original = buchstaben.join('');
  for (let versuch = 0; versuch < 12; versuch += 1) {
    const neu = gemischt(buchstaben);
    if (neu.join('') !== original) return neu;
  }
  // Bei Wörtern aus lauter gleichen Buchstaben gibt es nichts zu mischen.
  return buchstaben.slice();
}

export const UEBUNG = {
  id: 'salat',
  nummer: 2,
  name: 'Buchstabensalat',
  kurz: 'Erkenne das Wort',
  emoji: '🔀',
  farbe: '#a855f7',
  beschreibung: 'Die Buchstaben sind durcheinander. Welches Wort ist es?',

  aufbauen({ eintrag, aufFertig }) {
    const wort = wortkern(eintrag);
    const loesung = schreibform(eintrag);
    const buchstaben = Array.from(wort);
    const salat = wirklichGemischt(buchstaben);

    const kacheln = h('div', { class: 'salat', role: 'img', 'aria-label': `Die Buchstaben ${salat.join(', ')} durcheinander` });
    salat.forEach((zeichen, i) => {
      const kachel = h('span', { class: 'salat__kachel', style: { '--verzug': `${i * 45}ms` } }, zeichen);
      kacheln.appendChild(kachel);
    });

    const mischknopf = h('button', { class: 'knopf knopf--still knopf--klein', type: 'button' }, '🔀 Neu mischen');
    mischknopf.addEventListener('click', () => {
      const neu = wirklichGemischt(buchstaben);
      const alle = Array.from(kacheln.children);
      neu.forEach((zeichen, i) => { alle[i].textContent = zeichen; });
      kacheln.classList.remove('is-neu');
      void kacheln.offsetWidth;
      kacheln.classList.add('is-neu');
      sfx.tipp();
    });

    const wurzel = h('div', { class: 'uebung uebung--salat' },
      h('div', { class: 'vorlage vorlage--salat' }, kacheln),
      h('div', { class: 'uebung__werkzeuge' },
        h('span', { class: 'uebung__zaehler' }, `${buchstaben.length} Buchstaben`),
        mischknopf));

    const feld = schreibfeld({
      loesung,
      platzhalter: 'Das richtige Wort',
      hinweis: eintrag.art === 'n' ? 'Nomen bitte mit Artikel: der, die oder das.' : '',
      aufFertig,
    });
    wurzel.appendChild(feld.wurzel);
    return wurzel;
  },
};
