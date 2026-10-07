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
// 5. **Vor jeder Antwort steht ein Zeichen: ✓, ↻ oder ✗.** Seit „richtig"
//    blau ist und nicht mehr grün, ist der Unterschied zu „falsch" (rot) für
//    ein farbfehlsichtiges Kind schwächer geworden — und auf einem
//    ausgeblichenen Beamer für alle. Die Farbe darf die Antwort begleiten,
//    tragen muss sie das Zeichen und der Wortlaut.
// 6. **Eine mehrdeutige Vorlage hat mehrere richtige Lösungen** — und alle
//    zählen (`weitereLoesungen`, ab 1.8.7). Die Geheimschrift zeigt nur die
//    Gestalt des Wortes; „die Mutter" und „der Keller" sind darin dasselbe
//    Bild. Welche Wörter infrage kommen, weiß nur die Übung; dass sie zählen,
//    steht hier.

import { h, geputzt, entglaettet, ersteAbweichung } from '../util.js';
import * as sfx from '../sfx.js';
import { einstellungen } from '../store.js';

/**
 * schreibfeld({ loesung, weitereLoesungen, nebenlob, platzhalter, hinweis, aufFertig })
 *
 * `weitereLoesungen` sind Schreibweisen, die genauso richtig sind wie
 * `loesung` — die Übung entscheidet, welche (siehe Punkt 6 oben). `nebenlob`
 * ist die Rückmeldung für diesen Fall; ohne sie steht nur „Richtig!" da, und
 * das Kind erfährt nicht, dass es ein anderes Wort gelesen hat als gemeint war.
 *
 * aufFertig({ richtig, versuche, eingabe, fehlversuche }) wird genau einmal
 * gerufen, wenn die Aufgabe erledigt ist — richtig gelöst oder richtig
 * abgeschrieben. `eingabe` ist immer das, was das Kind TATSÄCHLICH geschrieben
 * hat, auch wenn das eine der weiteren Lösungen war.
 *
 * `fehlversuche` sind die Wörter, wie das Kind sie geschrieben hat, bevor es
 * stimmte. Sie sind das Wertvollste, was hier entsteht: „Somer" statt
 * „Sommer" sagt einer Lehrkraft mehr als jede Fehlerzahl — man sieht, WAS
 * das Kind sich falsch gemerkt hat. Wohin sie gehen und wer sie sehen darf,
 * entscheidet nicht diese Datei (siehe lauf.js und store.js).
 */
export function schreibfeld({
  loesung,
  weitereLoesungen = [],
  nebenlob = null,
  platzhalter = 'Hier schreiben',
  hinweis = '',
  aufFertig,
  aufVersuch = null,
  zusatzhinweis = null,
}) {
  const ziel = geputzt(loesung);

  /*
   * Weitere Schreibweisen, die GENAUSO richtig sind.
   *
   * Zwei Übungen brauchen das, weil ihre Vorlage mehrdeutig IST — nicht, weil
   * jemand sie mehrdeutig gemacht hätte. In der Geheimschrift haben „die
   * Mutter" und „der Keller" dasselbe Wortbild, „die Rinde", „die Eiche" und
   * „die Birke" alle drei; im Buchstabensalat sind „schneien" und „scheinen"
   * derselbe Haufen Buchstaben. Wer eines davon schreibt, hat die Aufgabe
   * gelöst (gemeldet 10/2026: „Die App lehnt richtige Lösungen ab, obwohl sie
   * der Geheimschrift entsprechen.").
   *
   * Gewertet wird es als voller Treffer, nicht als halber: Dem Kind ist kein
   * Fehler nachzuweisen. Welche Wörter infrage kommen, entscheidet die Übung —
   * das Schreibfeld weiß nicht, WARUM zwei Wörter gleich aussehen.
   */
  const nebenziele = new Set((weitereLoesungen || [])
    .map((wort) => geputzt(String(wort)))
    .filter((wort) => wort && wort !== ziel));
  let versuche = 0;
  let ersterVersuchRichtig = false;
  let abgeschlossen = false;
  let abschreibmodus = false;
  const fehlversuche = [];

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

  /**
   * Sagt, WAS nicht stimmt — ohne die Lösung zu verraten.
   *
   * Die Reihenfolge ist die Rangfolge: Zuerst die beiden Fehler, die ein
   * Grundschulkind am häufigsten macht und die eine Stellenangabe ganz falsch
   * beschreibt.
   *
   * * **Nur groß oder klein.** Wer „baum" schreibt, hat das Wort gekonnt.
   *   „Schon der erste Buchstabe stimmt nicht" war dafür die schlechteste
   *   aller Antworten — sie schickt das Kind auf die Suche nach einem Fehler,
   *   den es nicht gemacht hat. Und die Großschreibung IST der halbe
   *   Rechtschreibstoff der Grundschule; sie verdient einen eigenen Satz.
   * * **Der Artikel.** Bei Nomen steht „der/die/das" mit in der Lösung. Fehlt
   *   er, ist am Wort selbst nichts falsch.
   *
   * Erst danach kommt die Stelle, an der es auseinanderging.
   */
  const ARTIKEL = /^(der|die|das)\s+/i;
  const klein = (wort) => String(wort).toLocaleLowerCase('de-DE');

  /**
   * Gegen WELCHE Lösung wird der Fehler erklärt?
   *
   * Sobald es mehrere richtige Lösungen gibt, ist das nicht mehr
   * selbstverständlich. Gemeint war „die Mutter", und „der Keller" gilt
   * genauso — wer „Keller" ohne Artikel schreibt, hat NICHT „ein Wort, das es
   * hier nicht gibt" geschrieben, sondern eine richtige Lösung ohne Artikel.
   * Erklärt man den Fehler stur am gemeinten Wort, bekommt dieses Kind „passt
   * ins Häuschen, ist aber keines der Lernwörter" zu hören — und sucht einen
   * Fehler, den es nicht gemacht hat. Genau diese Sorte Rückmeldung sollte
   * `warumFalsch` abschaffen.
   *
   * Gewählt wird deshalb die Lösung, der die Eingabe am NÄCHSTEN kommt.
   */
  function naehe(eingabe, kandidat) {
    if (klein(eingabe) === klein(kandidat)) return 1e6;           // nur groß/klein
    const kernE = eingabe.replace(ARTIKEL, '');
    const kernK = kandidat.replace(ARTIKEL, '');
    if (klein(kernE) === klein(kernK)) return 1e5;                // nur der Artikel
    const stelle = ersteAbweichung(eingabe, kandidat);            // wie weit von vorn
    return stelle < 0 ? 1e6 : stelle;
  }

  function naechstesZiel(eingabe) {
    if (!nebenziele.size) return ziel;
    let beste = ziel;
    let bestwert = naehe(eingabe, ziel);
    for (const kandidat of nebenziele) {
      const wert = naehe(eingabe, kandidat);
      if (wert > bestwert) { bestwert = wert; beste = kandidat; }
    }
    return beste;
  }

  /** Welche Richtung? Das entscheidet, welche Regel zu nennen ist. */
  function grossOderKlein(zielKern) {
    return zielKern[0] === zielKern[0].toLocaleUpperCase('de-DE')
      ? 'Das Wort schreibt man groß.'
      : 'Das Wort schreibt man klein.';
  }

  function warumFalsch(eingabe, gegen = ziel) {
    const zielHatArtikel = ARTIKEL.test(gegen);
    const zielKern = gegen.replace(ARTIKEL, '');
    const eingabeKern = eingabe.replace(ARTIKEL, '');
    const gleichbuchstabig = klein(eingabeKern) === klein(zielKern);

    // 1. Alle Buchstaben stimmen, nur groß und klein nicht.
    if (klein(eingabe) === klein(gegen)) {
      return {
        vorrang: true,
        text: `Fast! Jeder Buchstabe sitzt richtig — nur groß und klein noch nicht. ${grossOderKlein(zielKern)}`,
      };
    }
    // 2. Das Wort stimmt, der Artikel fehlt oder passt nicht.
    //    „Nur" darf nur dastehen, wenn es wirklich das Einzige ist — sonst
    //    sucht das Kind einen Fehler und findet zwei.
    if (zielHatArtikel && gleichbuchstabig) {
      const auchGross = eingabeKern !== zielKern;
      const fehlt = !ARTIKEL.test(eingabe);
      if (auchGross) {
        return {
          vorrang: true,
          text: `Zwei Kleinigkeiten: ${fehlt ? 'Der Artikel fehlt davor' : 'Der Artikel passt noch nicht'}`
            + ` — der, die oder das? Und ${grossOderKlein(zielKern).replace(/^Das Wort schreibt man/, 'das Wort schreibt man')}`,
        };
      }
      return {
        vorrang: true,
        text: fehlt
          ? 'Das Wort stimmt! Es fehlt nur der Artikel davor: der, die oder das.'
          : 'Das Wort stimmt — nur der Artikel passt noch nicht. Der, die oder das?',
      };
    }
    // 3. Die Stelle, an der es auseinanderging. Hier darf eine Übung, die
    //    mehr über den Fehler weiß, vorgehen (`zusatzhinweis`).
    const stelle = ersteAbweichung(eingabe, gegen);
    if (stelle < 0) return { vorrang: false, text: '' };
    if (stelle >= eingabe.length) {
      const fehlen = gegen.length - eingabe.length;
      return {
        vorrang: false,
        text: `Da fehlt noch etwas — nach „${eingabe.slice(0, stelle)}“ geht es weiter`
          + `${fehlen === 1 ? ' (ein Zeichen)' : ` (noch ${fehlen} Zeichen)`}.`,
      };
    }
    if (stelle >= gegen.length) {
      const zuviel = eingabe.length - gegen.length;
      return { vorrang: false, text: `Das ist zu lang — ${zuviel === 1 ? 'ein Zeichen' : `${zuviel} Zeichen`} zu viel.` };
    }
    if (stelle === 0) return { vorrang: false, text: 'Schon der erste Buchstabe stimmt nicht.' };
    return { vorrang: false, text: `Bis „${eingabe.slice(0, stelle)}“ stimmt es. Danach schau noch einmal hin.` };
  }

  function abschliessen(richtig) {
    if (abgeschlossen) return;
    abgeschlossen = true;
    feld.disabled = true;
    knopf.disabled = true;
    if (aufFertig) {
      aufFertig({ richtig, versuche, eingabe: geputzt(entglaettet(feld.value)), fehlversuche: fehlversuche.slice() });
    }
  }

  function pruefen() {
    if (abgeschlossen) return;
    const eingabe = geputzt(entglaettet(feld.value));
    if (!eingabe) { feld.focus(); return; }

    // Ein Nebenziel gilt auch im Abschreibmodus. Dort steht zwar das gemeinte
    // Wort auf dem Tisch, aber ein Kind, das statt dessen das andere richtige
    // Wort schreibt, noch einmal abzuweisen, wäre dieselbe Ungerechtigkeit —
    // und es käme aus der Schleife nicht heraus.
    const nebentreffer = nebenziele.has(eingabe);
    if (eingabe === ziel || nebentreffer) {
      markiere('is-richtig');
      if (abschreibmodus) {
        // Richtig abgeschrieben — die Aufgabe ist erledigt, aber schon als
        // Fehler gewertet.
        rueckmeldung.textContent = '✓ Genau so wird es geschrieben. Merk es dir!';
        rueckmeldung.className = 'schreibfeld__antwort is-lob';
        sfx.tipp();
        abschliessen(false);
        return;
      }
      versuche += 1;
      ersterVersuchRichtig = versuche === 1;
      // Bei einem Nebenziel darf die Antwort nicht bei „Richtig!" bleiben: Das
      // Kind soll erfahren, dass es ein ANDERES Wort gelesen hat als gemeint
      // war, und dass beide zur Vorlage passen. Sonst lernt es aus dem Treffer
      // nichts — und wundert sich, wenn dasselbe Bild später ein anderes Wort
      // meint.
      const lob = nebentreffer && nebenlob ? nebenlob(eingabe) : '';
      rueckmeldung.textContent = lob
        ? `✓ ${lob}`
        : (versuche === 1 ? '✓ Richtig!' : '✓ Richtig — beim zweiten Anlauf.');
      rueckmeldung.className = 'schreibfeld__antwort is-richtig';
      sfx.richtig();
      abschliessen(ersterVersuchRichtig);
      return;
    }

    versuche += 1;
    fehlversuche.push(eingabe);
    if (aufVersuch) aufVersuch({ eingabe, versuche });
    markiere('is-falsch');
    sfx.falsch();
    if (versuche < 2) {
      // Manche Übungen wissen mehr über den Fehler als das Schreibfeld — die
      // Geheimschrift zum Beispiel sieht, ob die Eingabe überhaupt ins
      // Häuschen passt. Ein solcher Hinweis geht vor.
      // Manche Übungen wissen mehr über den Fehler als das Schreibfeld — die
      // Geheimschrift sieht, ob die Eingabe überhaupt ins Häuschen passt.
      // Vorrang hat ein solcher Hinweis trotzdem nicht immer: Bei „nur groß
      // und klein" und beim fehlenden Artikel wäre er falsch bis irreführend
      // („passt nicht ins Häuschen", obwohl das Wort gekonnt ist).
      const eigener = warumFalsch(eingabe, naechstesZiel(eingabe));
      const zusatz = zusatzhinweis ? zusatzhinweis(eingabe) : null;
      const text = eigener.vorrang
        ? eigener.text
        : (zusatz || eigener.text || 'Noch nicht ganz — versuch es noch einmal.');
      rueckmeldung.textContent = `↻ ${text}`;
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
    // Nicht nur das Wort, sondern die STELLE, an der es auseinanderging.
    // Abschreiben ohne Hinsehen lernt niemanden etwas; markiert wird deshalb
    // genau der Buchstabe, der anders war als gedacht.
    const stelle = ersteAbweichung(eingabe, ziel);
    loesungsband.appendChild(stelle >= 0 && stelle < ziel.length
      ? h('strong', { class: 'schreibfeld__loesung-wort' },
        ziel.slice(0, stelle),
        h('mark', { class: 'schreibfeld__stelle' }, ziel[stelle]),
        ziel.slice(stelle + 1))
      : h('strong', { class: 'schreibfeld__loesung-wort' }, ziel));
    rueckmeldung.textContent = '✗ Schau auf die farbige Stelle und schreib es genau so ab.';
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
  const fehlversuche = [];

  function naechste() {
    if (stelle >= formen.length) {
      if (aufFertig) aufFertig({ richtig: allesRichtig, fehlversuche });
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
      aufFertig: ({ richtig, fehlversuche: daneben }) => {
        if (!richtig) allesRichtig = false;
        // Mit der Frage davor, sonst steht später „läufst" im Protokoll und
        // niemand weiß mehr, wonach gefragt war.
        for (const versuch of daneben || []) fehlversuche.push(`${form.frage}: ${versuch}`);
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
