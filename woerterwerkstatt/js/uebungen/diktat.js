// Stufe 5 — Diktat.
//
// Das Wort wird vorgelesen, das Kind schreibt es auf. Nichts zu sehen: kein
// Wortbild, kein Salat, keine Buchstabenzahl. Das ist die Prüfung darauf, ob
// die vier Stufen davor gesessen haben.
//
// Was hier schiefgehen kann — und wie die App damit umgeht
// --------------------------------------------------------
// Die Sprachausgabe ist die einzige Stelle der App, die nicht überall
// funktioniert. Auf iOS im Browser gibt es sie, aber erst nach einer
// Berührung; auf manchen Android-Geräten fehlt die deutsche Stimme; in einem
// Schul-Kiosk ist sie mitunter ganz abgeschaltet.
//
// Deshalb: Vorgelesen wird erst auf Knopfdruck (nie von selbst), und wenn kein
// Ton kommt, sagt die App das und schaltet auf den **Merkweg** um — das Wort
// blitzt zwei Sekunden auf und ist dann weg. Das ist eine andere Übung, aber
// eine ehrliche. Eine App, die stumm bleibt und das Kind auf ein Geräusch
// warten lässt, das nie kommt, ist die schlechteste aller Möglichkeiten.
//
// Der Satz drumherum: Ein Wort ohne Zusammenhang zu diktieren ist unnatürlich —
// die Lehrkraft sagt „Baum. Der Baum steht im Garten. Baum.“ Genau das macht
// die App auch, sobald man „Im Satz“ drückt.

import { h, warte } from '../util.js';
import { schreibform, WORTARTEN } from '../grammatik.js';
import { einstellungen } from '../store.js';
import { sprich, schweig, kannSprechen } from '../plattform.js';
import { schreibfeld } from './schreibfeld.js';
import * as sfx from '../sfx.js';

/**
 * Ein Trägersatz, damit das Wort nicht nackt im Raum steht. Bewusst schlicht
 * und nach Wortart gebaut — kein Versuch, klug zu klingen: Das Kind soll das
 * WORT hören, nicht den Satz.
 */
function satz(eintrag) {
  const wort = eintrag.wort;
  if (eintrag.art === 'n') return `Ich sehe ${eintrag.artikel === 'der' ? 'den' : (eintrag.artikel === 'die' ? 'die' : 'das')} ${wort}.`;
  if (eintrag.art === 'v') return `Wir wollen ${wort}.`;
  if (eintrag.art === 'a') return `Das ist wirklich ${wort}.`;
  return `Das Wort heißt ${wort}.`;
}

export const UEBUNG = {
  id: 'diktat',
  nummer: 5,
  name: 'Diktat',
  kurz: 'Schreibe nach Gehör',
  emoji: '🎧',
  farbe: '#dc2626',
  beschreibung: 'Das Wort wird vorgelesen — schreib es auf, ohne es zu sehen.',

  aufbauen({ eintrag, aufFertig }) {
    const loesung = schreibform(eintrag);
    const tempo = einstellungen().diktatTempo || 0.7;
    const stimme = einstellungen().diktatStimme || '';
    let gehoert = 0;
    let stummGemeldet = false;

    const hoerknopf = h('button', { class: 'diktat__knopf', type: 'button' },
      h('span', { class: 'diktat__welle' }),
      h('span', { class: 'diktat__symbol' }, '🔊'),
      h('span', { class: 'diktat__text' }, 'Wort vorlesen'));

    const satzknopf = h('button', { class: 'knopf knopf--still knopf--klein', type: 'button' }, '💬 Im Satz hören');
    const langsam = h('button', { class: 'knopf knopf--still knopf--klein', type: 'button' }, '🐢 Langsam');
    const notausgang = h('div', { class: 'diktat__notausgang is-versteckt' });

    const wurzel = h('div', { class: 'uebung uebung--diktat' },
      h('div', { class: 'vorlage vorlage--diktat' }, hoerknopf),
      h('div', { class: 'uebung__werkzeuge' }, satzknopf, langsam),
      notausgang);

    function lesen(text, geschwindigkeit) {
      gehoert += 1;
      hoerknopf.classList.add('is-spricht');
      setTimeout(() => hoerknopf.classList.remove('is-spricht'), 1400);
      const ging = sprich(text, { tempo: geschwindigkeit, stimme });
      if (!ging) zeigeNotausgang();
    }

    /**
     * Kein Ton — also die Übung ehrlich umbauen statt sie ins Leere laufen zu
     * lassen. Der Merkweg zeigt das Wort zwei Sekunden und deckt es wieder zu.
     */
    function zeigeNotausgang() {
      if (stummGemeldet) return;
      stummGemeldet = true;
      notausgang.classList.remove('is-versteckt');
      const blitzknopf = h('button', { class: 'knopf knopf--voll', type: 'button' }, '👁️ Wort kurz zeigen');
      const anzeige = h('div', { class: 'diktat__blitz' });
      blitzknopf.addEventListener('click', async () => {
        gehoert += 1;
        anzeige.textContent = loesung;
        anzeige.classList.add('is-da');
        sfx.tipp();
        await warte(2000);
        anzeige.classList.remove('is-da');
        await warte(320);
        anzeige.textContent = '';
      });
      notausgang.appendChild(h('p', { class: 'diktat__notiz' },
        'Dieses Gerät kann gerade nicht vorlesen. Dann üben wir anders: Das Wort blitzt kurz auf — merk es dir und schreib es auf.'));
      notausgang.appendChild(blitzknopf);
      notausgang.appendChild(anzeige);
      satzknopf.disabled = true;
      langsam.disabled = true;
      hoerknopf.disabled = true;
    }

    if (!kannSprechen()) zeigeNotausgang();

    hoerknopf.addEventListener('click', () => lesen(eintrag.wort, tempo));
    satzknopf.addEventListener('click', () => lesen(satz(eintrag), tempo));
    // Deutlich langsamer, nicht nur ein bisschen: Bei sehr kleinem Tempo
    // trennen die meisten Stimmen die Silben von selbst sauberer ab.
    langsam.addEventListener('click', () => lesen(eintrag.wort, Math.max(0.35, Math.round((tempo - 0.3) * 100) / 100)));

    const feld = schreibfeld({
      loesung,
      platzhalter: 'Das diktierte Wort',
      hinweis: eintrag.art === 'n'
        ? 'Es ist ein Nomen — mit Artikel und großem Anfangsbuchstaben.'
        : `Es ist ein ${WORTARTEN[eintrag.art].name}.`,
      aufFertig: (ergebnis) => {
        schweig();
        aufFertig(Object.assign({}, ergebnis, { gehoert }));
      },
    });
    wurzel.appendChild(feld.wurzel);

    // Beim Verlassen der Aufgabe darf nichts weiterreden.
    wurzel.addEventListener('uebung-ende', () => schweig());
    return wurzel;
  },
};
