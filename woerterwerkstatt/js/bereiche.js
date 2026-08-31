// Eigene Themenbereiche der Lehrkraft.
//
// Die zwanzig mitgelieferten Bereiche decken den Grundwortschatz ab — die
// Lernwörter DIESER Woche stehen aber im Sprachbuch dieser Klasse. Deshalb
// kann eine angemeldete Lehrkraft eigene Bereiche anlegen.
//
// Warum die Formen von Hand eingetragen werden
// ---------------------------------------------
// Beim Anlegen fragt die App zu jedem Wort nach Wortart, Artikel und Mehrzahl
// (bzw. „du“-Form oder Steigerung). Das ist Tipparbeit — und Absicht: Eine
// automatisch erzeugte Mehrzahl wäre bei jedem fünften Wort falsch (Baum →
// Bäume, aber Raum → Räume und Traum → Träume; Wort → Wörter, aber Ort →
// Orte). Ein Kind, dem die App eine erfundene Form als richtig verkauft, lernt
// das Falsche, und niemand merkt es.
//
// Was die App abnimmt: einen VORSCHLAG, der sich mit einem Tipp übernehmen
// oder überschreiben lässt (siehe `vorschlag`). Vorgeschlagen wird nur, was
// verlässlich regelmäßig ist.

import { h, leeren, kennung } from './util.js';
import { blatt, abschnitt, zeile, frage, auswahl, meldung } from './ui.js';
import { WORTARTEN, eintragAusZeile, zeileAusEintrag } from './grammatik.js';
import {
  eigeneBereiche, bereichSichern, bereichLoeschen,
  bereichSichtbar, setzeBereichSichtbar, sichtbareBereiche,
} from './store.js';
import { angemeldet, bereicheHochladen, bereicheHolen } from './cloud.js';
import { PAKETGROESSE } from './paket.js';
import { BEREICHE } from './woerter.js';
import { RECHTSCHREIBUNG } from './rechtschreibung.js';
import { RECHTSCHREIBUNG2 } from './rechtschreibung2.js';
import { RECHTSCHREIBUNG3 } from './rechtschreibung3.js';

const EMOJIS = ['📗', '🍎', '🌳', '🚂', '⭐', '🐬', '🎵', '🧁', '🏰', '🦕', '🌍', '🎨', '⚽', '🚀', '🐝', '🎪'];
const FARBEN = ['#2563eb', '#0ea5e9', '#38bdf8', '#0369a1', '#f97316', '#ea580c', '#f59e0b', '#eab308', '#dc2626'];

/**
 * Ein Vorschlag für die Formen — bewusst zurückhaltend.
 *
 * Bei Verben ist die 2. Person Einzahl regelmäßig genug, um sie anzubieten
 * (laufen → laufst; der Umlaut bei starken Verben fehlt dann, deshalb steht
 * der Vorschlag zum Überschreiben da und nicht als Ergebnis). Bei Adjektiven
 * gilt dasselbe für -er/-sten. Für die Mehrzahl der Nomen gibt es KEINEN
 * Vorschlag — dort liegt man zu oft daneben.
 */
export function vorschlag(wort, art) {
  const w = String(wort).trim();
  if (!w) return {};
  if (art === 'v') {
    const stamm = w.replace(/e[nl]$/, '').replace(/n$/, '');
    if (/[dt]$/.test(stamm)) return { duForm: `${stamm}est` };
    if (/[sßxz]$/.test(stamm)) return { duForm: `${stamm}t` };
    return { duForm: `${stamm}st` };
  }
  if (art === 'a') {
    const stamm = w.replace(/e$/, '');
    const hoch = /[dtsßxz]$/.test(stamm) ? `am ${stamm}esten` : `am ${stamm}sten`;
    return { steigerung: `${stamm}er`, hoechste: hoch };
  }
  if (art === 'n') return { artikel: 'der' };
  return {};
}

function leererBereich() {
  return {
    id: kennung('eigen'),
    name: '',
    emoji: EMOJIS[0],
    farbe: FARBEN[0],
    eigen: true,
    woerter: [],
    geaendertAm: Date.now(),
  };
}

/* ---------- Ein einzelnes Wort bearbeiten ---------- */

function wortzeile(eintrag, beiAenderung, beiLoeschen) {
  const wurzel = h('div', { class: 'wortzeile' });

  const wortfeld = h('input', {
    class: 'wortzeile__wort', type: 'text', value: eintrag.wort || '',
    placeholder: 'Lernwort', autocomplete: 'off', spellcheck: 'false',
  });
  const formenplatz = h('div', { class: 'wortzeile__formen' });

  function formenZeichnen() {
    leeren(formenplatz);
    if (eintrag.art === 'n') {
      formenplatz.appendChild(feldchen('Artikel', eintrag.artikel || 'der', (wert) => { eintrag.artikel = wert; beiAenderung(); }, 'der', 5));
      formenplatz.appendChild(feldchen('Mehrzahl', eintrag.mehrzahl || '', (wert) => { eintrag.mehrzahl = wert; beiAenderung(); }, 'Bäume — leer = keine'));
    } else if (eintrag.art === 'v') {
      formenplatz.appendChild(feldchen('du …', eintrag.duForm || '', (wert) => { eintrag.duForm = wert; beiAenderung(); }, 'läufst'));
    } else if (eintrag.art === 'a') {
      formenplatz.appendChild(feldchen('1. Steigerung', eintrag.steigerung || '', (wert) => { eintrag.steigerung = wert; beiAenderung(); }, 'schneller'));
      formenplatz.appendChild(feldchen('2. Steigerung', eintrag.hoechste || '', (wert) => { eintrag.hoechste = wert; beiAenderung(); }, 'am schnellsten'));
    } else {
      formenplatz.appendChild(h('span', { class: 'wortzeile__notiz' }, 'Weder Nomen noch Verb noch Adjektiv — hier gibt es keine Formen.'));
    }
  }

  function feldchen(beschriftung, wert, beiEingabe, platzhalter = '', groesse = 0) {
    const feld = h('input', {
      class: `wortzeile__form${groesse ? ' wortzeile__form--kurz' : ''}`,
      type: 'text', value: wert, placeholder: platzhalter,
      autocomplete: 'off', spellcheck: 'false', 'aria-label': beschriftung,
    });
    feld.addEventListener('input', () => beiEingabe(feld.value.trim()));
    return h('label', { class: 'wortzeile__formfeld' }, h('span', {}, beschriftung), feld);
  }

  const artwahl = auswahl(
    Object.values(WORTARTEN).map((a) => ({ id: a.id, label: a.kurz, emoji: a.emoji })),
    eintrag.art || 'n',
    (id) => {
      eintrag.art = id;
      Object.assign(eintrag, vorschlag(eintrag.wort, id));
      formenZeichnen();
      beiAenderung();
    },
  );

  wortfeld.addEventListener('input', () => {
    eintrag.wort = wortfeld.value.trim();
    beiAenderung();
  });
  // Der Vorschlag kommt erst, wenn das Wort fertig getippt ist — und nur, wenn
  // das Feld noch leer war. Wer schon etwas eingetragen hat, wird nicht
  // überschrieben.
  wortfeld.addEventListener('blur', () => {
    const neu = vorschlag(eintrag.wort, eintrag.art);
    let etwas = false;
    for (const [name, wert] of Object.entries(neu)) {
      if (!eintrag[name]) { eintrag[name] = wert; etwas = true; }
    }
    if (etwas) { formenZeichnen(); beiAenderung(); }
  });

  wurzel.appendChild(h('div', { class: 'wortzeile__kopf' },
    wortfeld,
    h('button', { class: 'wortzeile__weg', type: 'button', title: 'Wort entfernen', 'aria-label': 'Wort entfernen', onclick: beiLoeschen }, '✕')));
  wurzel.appendChild(artwahl);
  wurzel.appendChild(formenplatz);
  formenZeichnen();
  return wurzel;
}

/* ---------- Das Blatt zum Bearbeiten eines Bereichs ---------- */

export function bereichBearbeiten(bereich, beiFertig) {
  const arbeit = bereich
    ? Object.assign({}, bereich, { woerter: bereich.woerter.slice() })
    : leererBereich();
  const eintraege = arbeit.woerter.map((z) => eintragAusZeile(z, arbeit.id));
  if (!eintraege.length) eintraege.push({ wort: '', art: 'n', artikel: 'der' });

  const liste = h('div', { class: 'wortliste' });
  const zaehler = h('p', { class: 'wortliste__zaehler' });

  function zaehlerZeichnen() {
    const gefuellt = eintraege.filter((e) => e.wort).length;
    const pakete = Math.ceil(gefuellt / PAKETGROESSE) || 0;
    const rest = gefuellt % PAKETGROESSE;
    zaehler.textContent = gefuellt
      ? `${gefuellt} Wörter — das ergibt ${pakete} Trainingspäckchen${rest ? ` (das letzte mit ${rest})` : ''}.`
      : `Noch keine Wörter. Ein Trainingspäckchen fasst ${PAKETGROESSE}.`;
  }

  function listeZeichnen() {
    leeren(liste);
    eintraege.forEach((eintrag, stelle) => {
      liste.appendChild(wortzeile(eintrag, zaehlerZeichnen, () => {
        eintraege.splice(stelle, 1);
        if (!eintraege.length) eintraege.push({ wort: '', art: 'n', artikel: 'der' });
        listeZeichnen();
        zaehlerZeichnen();
      }));
    });
    zaehlerZeichnen();
  }

  const namensfeld = h('input', { class: 'feld', type: 'text', value: arbeit.name, placeholder: 'Name des Bereichs, z. B. „Lernwörter Woche 12“' });
  const emojiwahl = h('div', { class: 'emojiwahl' });
  for (const emoji of EMOJIS) {
    const knopf = h('button', { class: `emojiwahl__knopf${emoji === arbeit.emoji ? ' is-aktiv' : ''}`, type: 'button' }, emoji);
    knopf.addEventListener('click', () => {
      arbeit.emoji = emoji;
      emojiwahl.querySelectorAll('.emojiwahl__knopf').forEach((k) => k.classList.remove('is-aktiv'));
      knopf.classList.add('is-aktiv');
    });
    emojiwahl.appendChild(knopf);
  }
  const farbwahl = h('div', { class: 'farbwahl' });
  for (const farbe of FARBEN) {
    const knopf = h('button', {
      class: `farbwahl__knopf${farbe === arbeit.farbe ? ' is-aktiv' : ''}`,
      type: 'button', style: { background: farbe }, 'aria-label': `Farbe ${farbe}`,
    });
    knopf.addEventListener('click', () => {
      arbeit.farbe = farbe;
      farbwahl.querySelectorAll('.farbwahl__knopf').forEach((k) => k.classList.remove('is-aktiv'));
      knopf.classList.add('is-aktiv');
    });
    farbwahl.appendChild(knopf);
  }

  const einfuegen = h('textarea', {
    class: 'feld feld--flaeche', rows: 3,
    placeholder: 'Mehrere Wörter auf einmal: eines je Zeile oder mit Komma getrennt. Die Wortart wird geraten und lässt sich danach richtigstellen.',
  });

  const dialog = blatt({
    titel: bereich ? 'Bereich bearbeiten' : 'Neuer Bereich',
    breit: true,
    inhalt: h('div', {},
      abschnitt('Name und Aussehen',
        namensfeld,
        zeile('Symbol', emojiwahl),
        zeile('Farbe', farbwahl)),
      abschnitt('Wörter',
        zaehler,
        liste,
        h('button', {
          class: 'knopf knopf--still', type: 'button',
          onclick: () => { eintraege.push({ wort: '', art: 'n', artikel: 'der' }); listeZeichnen(); },
        }, '+ Wort'),
      ),
      abschnitt('Viele auf einmal',
        einfuegen,
        h('button', {
          class: 'knopf knopf--still', type: 'button',
          onclick: () => {
            const roh = einfuegen.value.split(/[\n,;]+/).map((t) => t.trim()).filter(Boolean);
            if (!roh.length) return;
            for (const wort of roh) {
              const art = geratenerArt(wort);
              eintraege.push(Object.assign({ wort, art }, vorschlag(wort, art)));
            }
            einfuegen.value = '';
            // Leere Platzhalterzeilen aufräumen, sonst stehen sie zwischen den
            // eingefügten Wörtern.
            for (let i = eintraege.length - 1; i >= 0; i -= 1) if (!eintraege[i].wort) eintraege.splice(i, 1);
            listeZeichnen();
            meldung(`${roh.length} Wörter eingefügt — bitte die Wortarten prüfen.`, 'info');
          },
        }, 'Einfügen')),
    ),
    fusszeile: [
      bereich ? h('button', {
        class: 'knopf knopf--gefahr', type: 'button',
        onclick: async () => {
          const ja = await frage({
            titel: 'Bereich löschen?',
            text: `„${bereich.name}“ wird von diesem Gerät entfernt. Der Fortschritt dazu bleibt stehen, ist aber nicht mehr zu sehen.`,
            ja: 'Löschen', gefahr: true,
          });
          if (!ja) return;
          bereichLoeschen(bereich.id);
          dialog.schliessen();
          if (beiFertig) beiFertig(null);
        },
      }, 'Löschen') : null,
      h('button', { class: 'knopf knopf--still', type: 'button', onclick: () => dialog.schliessen() }, 'Abbrechen'),
      h('button', { class: 'knopf knopf--voll', type: 'button', onclick: () => sichern() }, 'Sichern'),
    ],
  });

  function sichern() {
    const name = namensfeld.value.trim();
    if (!name) { meldung('Der Bereich braucht einen Namen.', 'warnung'); namensfeld.focus(); return; }
    const gefuellt = eintraege.filter((e) => e.wort);
    if (!gefuellt.length) { meldung('Mindestens ein Wort braucht der Bereich.', 'warnung'); return; }
    const unvollstaendig = gefuellt.filter((e) => (e.art === 'v' && !e.duForm)
      || (e.art === 'a' && !e.steigerung));
    if (unvollstaendig.length) {
      meldung(`Bei ${unvollstaendig.length} Wort/Wörtern fehlt noch eine Form — Stufe 4 fragt sie dann nicht ab.`, 'info', 4200);
    }
    arbeit.name = name;
    arbeit.woerter = gefuellt.map(zeileAusEintrag);
    const gesichert = bereichSichern(arbeit);
    dialog.schliessen();
    if (beiFertig) beiFertig(gesichert);
    if (angemeldet()) {
      bereicheHochladen(eigeneBereiche())
        .then(() => meldung('Im Konto gesichert.', 'gut'))
        .catch(() => meldung('Gesichert — aber nicht ins Konto (kein Netz?).', 'warnung'));
    }
  }

  listeZeichnen();
  return dialog;
}

/**
 * Wortart raten, wenn viele Wörter auf einmal eingefügt werden. Absichtlich
 * grob: Großgeschrieben heißt Nomen, Endung -en/-eln/-ern heißt Verb, alles
 * andere Adjektiv. Das ist kein Ersatz für das Nachsehen — es spart nur die
 * Hälfte der Klicks.
 */
function geratenerArt(wort) {
  const w = String(wort).trim();
  if (!w) return 'n';
  if (w[0] === w[0].toLocaleUpperCase('de-DE') && w[0] !== w[0].toLocaleLowerCase('de-DE')) return 'n';
  if (/(en|eln|ern|n)$/.test(w)) return 'v';
  return 'a';
}

/** Das Verwaltungsblatt: alle eigenen Bereiche auf einen Blick. */
export function bereicheVerwalten(beiAenderung) {
  const liste = h('div', { class: 'bereichsliste' });

  function zeichnen() {
    leeren(liste);
    const eigene = eigeneBereiche();
    if (!eigene.length) {
      liste.appendChild(h('p', { class: 'blatt__text' },
        'Noch keine eigenen Bereiche. Ein eigener Bereich ist die Lernwörterliste dieser Woche — die Kinder üben sie dann mit allen fünf Stufen.'));
      return;
    }
    for (const bereich of eigene) {
      liste.appendChild(h('button', {
        class: 'bereichsliste__eintrag', type: 'button',
        style: { '--bereichsfarbe': bereich.farbe || '#2563eb' },
        onclick: () => bereichBearbeiten(bereich, () => { zeichnen(); if (beiAenderung) beiAenderung(); }),
      },
        h('span', { class: 'bereichsliste__emoji' }, bereich.emoji || '📗'),
        h('span', { class: 'bereichsliste__text' },
          h('strong', {}, bereich.name),
          h('span', {}, `${bereich.woerter.length} Wörter · ${Math.ceil(bereich.woerter.length / PAKETGROESSE)} Päckchen`)),
        h('span', { class: 'bereichsliste__pfeil' }, '›')));
    }
  }

  const dialog = blatt({
    titel: 'Eigene Bereiche',
    breit: true,
    inhalt: h('div', {},
      liste,
      h('div', { class: 'blatt__knopfreihe' },
        h('button', {
          class: 'knopf knopf--voll', type: 'button',
          onclick: () => bereichBearbeiten(null, () => { zeichnen(); if (beiAenderung) beiAenderung(); }),
        }, '+ Neuer Bereich'),
        angemeldet() ? h('button', {
          class: 'knopf knopf--still', type: 'button',
          onclick: async () => {
            try {
              const ausDemKonto = await bereicheHolen();
              let neu = 0;
              for (const bereich of ausDemKonto) {
                const daheim = eigeneBereiche().find((b) => b.id === bereich.id);
                if (!daheim || (bereich.geaendertAm || 0) > (daheim.geaendertAm || 0)) {
                  bereichSichern(bereich);
                  neu += 1;
                }
              }
              zeichnen();
              if (beiAenderung) beiAenderung();
              meldung(neu ? `${neu} Bereich(e) aus dem Konto geholt.` : 'Alles war schon aktuell.', 'gut');
            } catch (_) {
              meldung('Das Konto war nicht erreichbar.', 'warnung');
            }
          },
        }, '↻ Aus dem Konto holen') : null)),
  });

  zeichnen();
  return dialog;
}

/* ---------- Welche Bereiche sichtbar sind ---------- */

/**
 * Die Auswahl, welche mitgelieferten Bereiche erscheinen.
 *
 * Von Haus aus sind die zwanzig Themenbereiche an und die siebenundzwanzig
 * Rechtschreibblöcke aus. Eine Lehrkraft schaltet frei, was gerade dran ist —
 * und blendet aus, was ihre Klasse nicht braucht. Beides in derselben Liste,
 * denn es ist dieselbe Frage.
 *
 * `beiWahl` bekommt die vollständige Auswahl gemeldet; die Klassenansicht
 * nutzt das, um sie an die Kinder weiterzugeben.
 */
export function bereichswahl({ titel = 'Bereiche wählen', hinweis = '', beiWahl = null } = {}) {
  function gruppe(ueberschrift, liste, erklaerung) {
    if (!liste.length) return null;
    const kasten = h('div', { class: 'bereichswahl' });
    for (const bereich of liste) {
      const an = bereichSichtbar(bereich);
      kasten.appendChild(h('label', { class: `bereichswahl__zeile${an ? ' is-an' : ''}` },
        h('input', {
          type: 'checkbox',
          checked: an,
          onchange: (ereignis) => {
            setzeBereichSichtbar(bereich.id, ereignis.target.checked);
            ereignis.target.closest('.bereichswahl__zeile').classList.toggle('is-an', ereignis.target.checked);
            if (beiWahl) beiWahl(sichtbareBereiche());
          },
        }),
        h('span', { class: 'bereichswahl__emoji' }, bereich.emoji || '📗'),
        h('span', { class: 'bereichswahl__name' }, bereich.name),
        h('span', { class: 'bereichswahl__zahl' }, `${bereich.woerter.length} Wörter`)));
    }
    const alleSchalten = (an) => {
      for (const bereich of liste) setzeBereichSichtbar(bereich.id, an);
      kasten.querySelectorAll('input').forEach((feld) => { feld.checked = an; });
      kasten.querySelectorAll('.bereichswahl__zeile').forEach((zeile) => zeile.classList.toggle('is-an', an));
      if (beiWahl) beiWahl(sichtbareBereiche());
    };
    return abschnitt(ueberschrift,
      erklaerung ? h('p', { class: 'abschnitt__notiz' }, erklaerung) : null,
      h('div', { class: 'blatt__knopfreihe' },
        h('button', { class: 'knopf knopf--still knopf--klein', type: 'button', onclick: () => alleSchalten(true) }, 'Alle an'),
        h('button', { class: 'knopf knopf--still knopf--klein', type: 'button', onclick: () => alleSchalten(false) }, 'Alle aus')),
      kasten);
  }

  return blatt({
    titel,
    breit: true,
    inhalt: h('div', {},
      hinweis ? h('p', { class: 'blatt__text' }, hinweis) : null,
      gruppe('Themenbereiche', BEREICHE,
        'Grundwortschatz nach Inhalt — Schule, Tiere, Wetter. Von Haus aus alle an.'),
      gruppe('Rechtschreibung — 2. Schuljahr', RECHTSCHREIBUNG2,
        'Achtundzwanzig Blöcke zu je zehn Wörtern. Von Haus aus alle aus.'),
      gruppe('Rechtschreibung — 3. Schuljahr', RECHTSCHREIBUNG3,
        'Fünfundzwanzig Päckchen, nach Rechtschreibstelle sortiert: alle Wörter eines '
        + 'Päckchens tragen dasselbe Problem. Von Haus aus alle aus.'),
      gruppe('Rechtschreibung — 4. Schuljahr', RECHTSCHREIBUNG,
        'Siebenundzwanzig Blöcke, ebenso aufgebaut. Von Haus aus alle aus — schalte '
        + 'frei, was diese Woche dran ist.')),
  });
}
