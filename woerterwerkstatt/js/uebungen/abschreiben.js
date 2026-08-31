// Stufe 1 — Abschreiben.
//
// Die einfachste Übung und zugleich die wichtigste: Wer ein Wort richtig
// abschreiben kann, hat es angeschaut. Drei Härtegrade, einstellbar in den
// Einstellungen (und von der Lehrkraft für die Klasse vorgebbar):
//
//   „Wort bleibt stehen“   Das Wort steht die ganze Zeit da — reines Abmalen.
//   „Wort verschwindet“    Nach drei Sekunden ist es weg. Jetzt muss das Kind
//                          das Wortbild im Kopf behalten haben.
//   „Selbst aufdecken“     Das Kind darf so oft spicken, wie es will — aber
//                          jedes Aufdecken wird mitgezählt und am Ende gezeigt.
//                          Das ist keine Strafe, sondern eine Rückmeldung:
//                          „dieses Wort musstest du dreimal ansehen“.

import { h } from '../util.js';
import { schreibform } from '../grammatik.js';
import { einstellungen } from '../store.js';
import { schreibfeld } from './schreibfeld.js';
import * as sfx from '../sfx.js';

export const UEBUNG = {
  id: 'abschreiben',
  nummer: 1,
  name: 'Abschreiben',
  kurz: 'Schreibe das Wort ab',
  emoji: '✏️',
  farbe: '#2563eb',
  beschreibung: 'Das Wort steht da — schreib es genau so noch einmal.',

  aufbauen({ eintrag, aufFertig }) {
    const art = einstellungen().abschreiben || 'sichtbar';
    const wort = schreibform(eintrag);
    let blicke = 0;

    const wortkasten = h('div', { class: 'vorlage vorlage--wort' }, h('span', { class: 'vorlage__wort' }, wort));
    const huelle = h('div', { class: 'vorlage-huelle' }, wortkasten);

    const wurzel = h('div', { class: 'uebung uebung--abschreiben' }, huelle);

    if (art === 'blitz') {
      const zaehler = h('div', { class: 'vorlage__uhr' }, '3');
      huelle.appendChild(zaehler);
      let rest = 3;
      const takt = setInterval(() => {
        rest -= 1;
        if (rest > 0) { zaehler.textContent = String(rest); return; }
        clearInterval(takt);
        zaehler.remove();
        wortkasten.classList.add('is-weg');
        wortkasten.setAttribute('aria-hidden', 'true');
      }, 1000);
      wurzel.addEventListener('uebung-ende', () => clearInterval(takt));
    }

    if (art === 'verdeckt') {
      wortkasten.classList.add('is-zugedeckt');
      const decke = h('button', { class: 'vorlage__decke', type: 'button' },
        h('span', { class: 'vorlage__decke-symbol' }, '👀'),
        h('span', {}, 'Zum Spicken drücken und halten'));
      const aufdecken = (an) => {
        wortkasten.classList.toggle('is-zugedeckt', !an);
        if (an) { blicke += 1; sfx.tipp(); }
      };
      decke.addEventListener('pointerdown', () => aufdecken(true));
      decke.addEventListener('pointerup', () => aufdecken(false));
      decke.addEventListener('pointerleave', () => aufdecken(false));
      decke.addEventListener('pointercancel', () => aufdecken(false));
      // Für Tastatur und Vorlesesoftware: Leertaste hält ebenfalls auf.
      decke.addEventListener('keydown', (e) => { if (e.key === ' ' || e.key === 'Enter') { e.preventDefault(); aufdecken(true); } });
      decke.addEventListener('keyup', (e) => { if (e.key === ' ' || e.key === 'Enter') { e.preventDefault(); aufdecken(false); } });
      huelle.appendChild(decke);
    }

    const feld = schreibfeld({
      loesung: wort,
      platzhalter: 'Das Wort abschreiben',
      // Nach einem Fehlversuch kommt das Wort im Blitzmodus noch einmal für
      // zwei Sekunden zurück. Ohne das wäre der zweite Versuch geraten: Die
      // Aufgabe heißt „schreib es ab", und abzuschreiben war nichts mehr da.
      // Gezählt wird es wie ein Spicken.
      aufVersuch: () => {
        if (art !== 'blitz' || !wortkasten.classList.contains('is-weg')) return;
        blicke += 1;
        wortkasten.classList.remove('is-weg');
        wortkasten.removeAttribute('aria-hidden');
        sfx.tipp();
        const zurueck = setTimeout(() => {
          wortkasten.classList.add('is-weg');
          wortkasten.setAttribute('aria-hidden', 'true');
        }, 2000);
        wurzel.addEventListener('uebung-ende', () => clearTimeout(zurueck), { once: true });
      },
      aufFertig: (ergebnis) => aufFertig(Object.assign({}, ergebnis, { blicke })),
    });
    wurzel.appendChild(feld.wurzel);
    return wurzel;
  },
};
