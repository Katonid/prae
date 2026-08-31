// Stufe 4 — Wortart erkennen und die Formen schreiben.
//
// Zwei Schritte in einer Aufgabe, und das mit Absicht: Erst entscheidet das
// Kind, WAS für ein Wort das ist — dann folgt daraus, welche Formen es
// aufschreiben muss.
//
//   Nomen      Einzahl und Mehrzahl        der Baum · die Bäume
//   Verb       Grundform und „du“-Form     laufen · du läufst
//   Adjektiv   Grundstufe und zwei Steigerungen   schnell · schneller · am schnellsten
//   sonst      nur das Wort selbst
//
// Die Wortart falsch zu raten kostet nichts außer der Wertung — danach geht es
// mit der RICHTIGEN Wortart weiter. Ein Kind, das „laufen“ für ein Nomen hält
// und dann eine Mehrzahl von „laufen“ bilden soll, lernt Unsinn.
//
// Warum keine Formen ausgerechnet werden, steht in grammatik.js: Die deutsche
// Mehrzahl ist nicht regelmäßig, und eine erfundene Form wäre schlimmer als
// keine Übung.

import { h, warte } from '../util.js';
import { WORTARTEN, formen, schreibform } from '../grammatik.js';
import { schreibkette } from './schreibfeld.js';
import * as sfx from '../sfx.js';

const REIHENFOLGE = ['n', 'v', 'a', 'x'];

export const UEBUNG = {
  id: 'wortart',
  nummer: 4,
  name: 'Wortart',
  kurz: 'Nomen, Verb oder Adjektiv?',
  emoji: '🧩',
  farbe: '#f97316',
  beschreibung: 'Erkenne die Wortart — und schreibe dann die passenden Formen auf.',

  aufbauen({ eintrag, aufFertig }) {
    let artRichtig = false;
    let entschieden = false;

    const wortkasten = h('div', { class: 'vorlage vorlage--wort' },
      h('span', { class: 'vorlage__wort' }, eintrag.art === 'n' ? schreibform(eintrag) : eintrag.wort));

    const knoepfe = h('div', { class: 'wortarten' });
    const rueckmeldung = h('div', { class: 'wortarten__antwort', 'aria-live': 'polite' });
    const formenplatz = h('div', { class: 'wortarten__formen' });

    const wurzel = h('div', { class: 'uebung uebung--wortart' },
      wortkasten,
      h('p', { class: 'uebung__frage' }, 'Was für ein Wort ist das?'),
      knoepfe,
      rueckmeldung,
      formenplatz);

    for (const id of REIHENFOLGE) {
      const art = WORTARTEN[id];
      const knopf = h('button', {
        class: `wortarten__knopf wortarten__knopf--${id}`,
        type: 'button',
        style: { '--art-farbe': art.farbe },
        title: art.hilfe,
      },
        h('span', { class: 'wortarten__emoji' }, art.emoji),
        h('span', { class: 'wortarten__name' }, art.name));
      knopf.addEventListener('click', () => waehlen(id, knopf));
      knoepfe.appendChild(knopf);
    }

    async function waehlen(gewaehlt, knopf) {
      if (entschieden) return;
      entschieden = true;
      artRichtig = gewaehlt === eintrag.art;
      knoepfe.querySelectorAll('.wortarten__knopf').forEach((k) => { k.disabled = true; });
      knopf.classList.add(artRichtig ? 'is-richtig' : 'is-falsch');
      if (!artRichtig) {
        const richtige = knoepfe.querySelector(`.wortarten__knopf--${eintrag.art}`);
        if (richtige) richtige.classList.add('is-loesung');
        sfx.falsch();
        rueckmeldung.className = 'wortarten__antwort is-falsch';
        rueckmeldung.textContent = `✗ Es ist ein ${WORTARTEN[eintrag.art].name}. ${WORTARTEN[eintrag.art].hilfe}`;
      } else {
        sfx.richtig();
        rueckmeldung.className = 'wortarten__antwort is-richtig';
        rueckmeldung.textContent = `✓ Stimmt — ein ${WORTARTEN[eintrag.art].name}.`;
      }
      await warte(700);
      formenSchreiben();
    }

    function formenSchreiben() {
      const liste = formen(eintrag);
      formenplatz.appendChild(h('p', { class: 'uebung__frage' },
        liste.length > 1 ? 'Und jetzt die Formen:' : 'Und jetzt das Wort:'));
      formenplatz.appendChild(schreibkette(liste, ({ richtig }) => {
        // Als richtig zählt die Aufgabe nur, wenn BEIDES saß: die Wortart und
        // jede Form im ersten Versuch.
        aufFertig({ richtig: artRichtig && richtig, artRichtig });
      }));
      formenplatz.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
    }

    return wurzel;
  },
};
