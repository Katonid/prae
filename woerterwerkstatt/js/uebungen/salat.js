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
import { eintraege, schreibform, wortkern } from '../grammatik.js';
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
  farbe: '#38bdf8',
  beschreibung: 'Die Buchstaben sind durcheinander. Welches Wort ist es?',

  aufbauen({ eintrag, bereich, paket = [], aufFertig }) {
    const wort = wortkern(eintrag);
    const loesung = schreibform(eintrag);
    const buchstaben = Array.from(wort);
    const salat = wirklichGemischt(buchstaben);

    /*
     * Welche anderen Wörter aus GENAU diesen Buchstaben bestehen.
     *
     * Dieselbe Mehrdeutigkeit wie bei der Geheimschrift, nur viel seltener: In
     * den eigenen Wortlisten gibt es genau EIN Paar („schneien" und
     * „scheinen"), und keines innerhalb desselben Päckchens. Trotzdem richtig
     * so — wer aus den gezeigten Buchstaben ein anderes echtes Wort legt, hat
     * die Aufgabe gelöst, und eine Abweisung wäre dieselbe Ungerechtigkeit.
     *
     * Verglichen wird MIT Rücksicht auf groß und klein, anders als beim
     * Hinweis zum Buchstabenvorrat unten: Die Kacheln zeigen die Buchstaben so,
     * wie sie im Wort stehen — ein großes B bleibt groß. „Lager" ist deshalb
     * kein zulässiger Salat von „Regal": Das große L liegt gar nicht da.
     */
    const alsVorrat = (text) => Array.from(String(text)).sort().join('');
    const zielvorrat = alsVorrat(wort);
    const auchRichtig = Array.from(new Set(
      (bereich ? eintraege(bereich) : paket)
        .filter((kandidat) => alsVorrat(wortkern(kandidat)) === zielvorrat)
        .map(schreibform),
    )).filter((form) => form !== loesung);

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
      weitereLoesungen: auchRichtig,
      nebenlob: (eingabe) => `Richtig! „${eingabe}“ steckt in genau denselben Buchstaben.`
        + ` Gemeint war „${loesung}“ — beides geht.`,
      platzhalter: 'Das richtige Wort',
      hinweis: eintrag.art === 'n' ? 'Nomen bitte mit Artikel: der, die oder das.' : '',
      // Die Buchstaben liegen oben — dann kann die App auch sagen, welcher
      // davon nicht dabei ist. „Bis „Som" stimmt es" hilft hier weniger als
      // „ein r kommt oben gar nicht vor": Beim Salat ist der Vorrat die
      // Aufgabe. Verglichen wird ohne Rücksicht auf groß und klein — die
      // Großschreibung ist eine eigene Rückmeldung und hat Vorrang.
      zusatzhinweis: (eingabe) => {
        const kern = Array.from(eingabe.replace(/^(der|die|das)\s+/i, '').toLocaleLowerCase('de-DE'));
        const vorrat = new Map();
        for (const zeichen of buchstaben) {
          const klein = zeichen.toLocaleLowerCase('de-DE');
          vorrat.set(klein, (vorrat.get(klein) || 0) + 1);
        }
        for (const zeichen of kern) {
          const da = vorrat.get(zeichen) || 0;
          if (!da) {
            // Der Schlüssel bleibt stehen, wenn der Vorrat aufgebraucht ist —
            // daran hängt der Unterschied zwischen „gibt es nicht" und
            // „schon zu oft benutzt".
            return vorrat.has(zeichen)
              ? `Den Buchstaben „${zeichen}“ hast du öfter benutzt, als er oben vorkommt.`
              : `Der Buchstabe „${zeichen}“ kommt oben gar nicht vor.`;
          }
          vorrat.set(zeichen, da - 1);
        }
        if (kern.length !== buchstaben.length) {
          return `Oben liegen ${buchstaben.length} Buchstaben — dein Wort hat ${kern.length}.`;
        }
        return null;
      },
      aufFertig,
    });
    wurzel.appendChild(feld.wurzel);
    return wurzel;
  },
};
