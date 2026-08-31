// Das Schreibfeld — der eine Ort, an dem in dieser App etwas kontrolliert wird.
//
// Vier Entscheidungen, die überall gleich gelten sollen und deshalb hier
// stehen und nicht fünfmal in den Übungen:
//
// 1. **Groß und klein wird verglichen.** Sonst prüft die App nicht das, was in
//    der Grundschule der halbe Rechtschreibstoff ist. Nomen groß, Verben und
//    Adjektive klein — das IST die Aufgabe.
// 2. **Zwei Versuche, dann die Lösung.** Beim ersten Fehler bekommt das Kind
//    die Stelle gezeigt, an der es abgewichen ist, und darf noch einmal. Nach
//    dem zweiten Fehler steht das richtige Wort da und muss abgeschrieben
//    werden. Ein Kind, das dreimal rät, lernt das Raten.
// 3. **Für die Wertung zählt nur der erste Versuch.** Das Abschreiben danach
//    hilft dem Kind, verdient aber keinen Stern.
// 4. **Was die Tastatur von selbst verschlimmbessert, zählt nicht als Fehler.**
//    Ein Gedankenstrich statt Bindestrich ist kein Rechtschreibfehler des
//    Kindes, sondern eine Bequemlichkeit von iOS.

import { h, geputzt, entglaettet, ersteAbweichung } from '../util.js';
import * as sfx from '../sfx.js';
import { einstellungen } from '../store.js';

/**
 * schreibfeld({ loesung, platzhalter, hinweis, gross, aufFertig })
 *
 * aufFertig({ richtig, versuche, eingabe }) wird genau einmal gerufen, wenn
 * die Aufgabe erledigt ist — richtig gelöst oder richtig abgeschrieben.
 */
export function schreibfeld({
  loesung,
  platzhalter = 'Hier schreiben',
  hinweis = '',
  aufFertig,
  aufVersuch = null,
  zusatzhinweis = null,
}) {
  const ziel = geputzt(loesung);
  let versuche = 0;
  let ersterVersuchRichtig = false;
  let abgeschlossen = false;
  let abschreibmodus = false;

  const feld = h('input', {
    class: 'schreibfeld__eingabe',
    type: 'text',
    autocomplete: 'off',
    autocorrect: 'off',
    autocapitalize: 'off',
    spellcheck: 'false',
    inputmode: 'text',
    // size=1 nimmt dem Feld die eingebaute Mindestbreite von zwanzig Zeichen;
    // die Breite kommt aus dem CSS.
    size: 1,
    placeholder: platzhalter,
    'aria-label': platzhalter,
  });
  if (einstellungen().grossbuchstaben) feld.classList.add('is-gross');

  const rueckmeldung = h('div', { class: 'schreibfeld__antwort', 'aria-live': 'polite' });
  const loesungsband = h('div', { class: 'schreibfeld__loesung is-versteckt' });
  const knopf = h('button', { class: 'knopf knopf--voll schreibfeld__knopf', type: 'button' }, 'Prüfen');

  const wurzel = h('div', { class: 'schreibfeld' },
    hinweis ? h('p', { class: 'schreibfeld__hinweis' }, hinweis) : null,
    h('div', { class: 'schreibfeld__reihe' }, feld, knopf),
    rueckmeldung,
    loesungsband);

  function markiere(art) {
    feld.classList.remove('is-richtig', 'is-falsch');
    if (art) feld.classList.add(art);
  }

  /** Zeigt, WO es auseinanderging — ohne die restliche Lösung zu verraten. */
  function stelleZeigen(eingabe) {
    const stelle = ersteAbweichung(eingabe, ziel);
    if (stelle < 0) return '';
    if (stelle === 0) return 'Schon der erste Buchstabe stimmt nicht.';
    if (stelle >= eingabe.length) return `Da fehlt noch etwas — nach „${eingabe.slice(0, stelle)}“ geht es weiter.`;
    if (stelle >= ziel.length) return 'Das ist zu lang geworden.';
    return `Bis „${eingabe.slice(0, stelle)}“ stimmt es. Danach schau noch einmal hin.`;
  }

  function abschliessen(richtig) {
    if (abgeschlossen) return;
    abgeschlossen = true;
    feld.disabled = true;
    knopf.disabled = true;
    if (aufFertig) aufFertig({ richtig, versuche, eingabe: geputzt(entglaettet(feld.value)) });
  }

  function pruefen() {
    if (abgeschlossen) return;
    const eingabe = geputzt(entglaettet(feld.value));
    if (!eingabe) { feld.focus(); return; }

    if (eingabe === ziel) {
      markiere('is-richtig');
      if (abschreibmodus) {
        // Richtig abgeschrieben — die Aufgabe ist erledigt, aber schon als
        // Fehler gewertet.
        rueckmeldung.textContent = 'Genau so wird es geschrieben. Merk es dir!';
        rueckmeldung.className = 'schreibfeld__antwort is-lob';
        sfx.tipp();
        abschliessen(false);
        return;
      }
      versuche += 1;
      ersterVersuchRichtig = versuche === 1;
      rueckmeldung.textContent = versuche === 1 ? 'Richtig!' : 'Richtig — beim zweiten Anlauf.';
      rueckmeldung.className = 'schreibfeld__antwort is-richtig';
      sfx.richtig();
      abschliessen(ersterVersuchRichtig);
      return;
    }

    versuche += 1;
    if (aufVersuch) aufVersuch({ eingabe, versuche });
    markiere('is-falsch');
    sfx.falsch();
    if (versuche < 2) {
      // Manche Übungen wissen mehr über den Fehler als das Schreibfeld — die
      // Geheimschrift zum Beispiel sieht, ob die Eingabe überhaupt ins
      // Häuschen passt. Ein solcher Hinweis geht vor.
      const zusatz = zusatzhinweis ? zusatzhinweis(eingabe) : null;
      rueckmeldung.textContent = zusatz || stelleZeigen(eingabe) || 'Noch nicht ganz — versuch es noch einmal.';
      rueckmeldung.className = 'schreibfeld__antwort is-fastrichtig';
      feld.focus();
      feld.select();
      return;
    }

    // Zweiter Fehlversuch: Die Lösung kommt auf den Tisch und wird abgeschrieben.
    abschreibmodus = true;
    loesungsband.classList.remove('is-versteckt');
    loesungsband.textContent = '';
    loesungsband.appendChild(h('span', { class: 'schreibfeld__loesung-marke' }, 'So ist es richtig'));
    loesungsband.appendChild(h('strong', { class: 'schreibfeld__loesung-wort' }, ziel));
    rueckmeldung.textContent = 'Schreib es jetzt genau so ab.';
    rueckmeldung.className = 'schreibfeld__antwort is-falsch';
    feld.value = '';
    markiere(null);
    knopf.textContent = 'Abschreiben prüfen';
    feld.focus();
  }

  knopf.addEventListener('click', pruefen);
  feld.addEventListener('keydown', (ereignis) => {
    if (ereignis.key === 'Enter') { ereignis.preventDefault(); pruefen(); }
  });
  feld.addEventListener('input', () => { markiere(null); });

  return { wurzel, feld, fokus: () => feld.focus(), pruefen };
}

/**
 * Mehrere Schreibfelder hintereinander (Stufe 4 fragt zwei bis drei Formen zu
 * einem Wort ab). Erst wenn alle erledigt sind, ist die Aufgabe fertig; als
 * richtig zählt sie nur, wenn JEDE Form im ersten Versuch saß.
 */
export function schreibkette(formen, aufFertig) {
  const wurzel = h('div', { class: 'schreibkette' });
  let stelle = 0;
  let allesRichtig = true;

  function naechste() {
    if (stelle >= formen.length) {
      if (aufFertig) aufFertig({ richtig: allesRichtig });
      return;
    }
    const form = formen[stelle];
    const karte = h('div', { class: 'schreibkette__glied' },
      h('div', { class: 'schreibkette__frage' },
        h('span', { class: 'schreibkette__nummer' }, `${stelle + 1}/${formen.length}`),
        h('span', { class: 'schreibkette__was' }, form.frage)));
    const feld = schreibfeld({
      loesung: form.loesung,
      hinweis: form.hinweis,
      platzhalter: form.frage,
      aufFertig: ({ richtig }) => {
        if (!richtig) allesRichtig = false;
        stelle += 1;
        setTimeout(naechste, 520);
      },
    });
    karte.appendChild(feld.wurzel);
    wurzel.appendChild(karte);
    requestAnimationFrame(() => {
      karte.classList.add('is-da');
      if (!('ontouchstart' in window)) feld.fokus();
      karte.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
    });
  }

  naechste();
  return wurzel;
}
