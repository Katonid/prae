// Die Wörterwerkstatt — Einstiegspunkt und Oberfläche.
//
// Aufbau in drei Ebenen, mehr braucht es nicht:
//
//   Bereich wählen  →  Päckchen und Stufe wählen  →  üben
//
// Der Weg dorthin steht in der Adresse (`#/bereich/schule/0`), damit der
// Zurück-Knopf des Browsers das tut, was ein Kind von ihm erwartet — und damit
// ein Beitrittslink (`#/beitreten/ABC234`) an derselben Stelle ankommt.

import { h, leeren } from './util.js';
import { sterne as sterneAnzeige, balken, blatt, frage } from './ui.js';
import {
  ladeZustand, eigeneBereiche, fortschritt, sterneImBereich,
  nutzer, setzeNutzer, klassen, horch, schwereWoerter, protokollLeeren,
  bereichSichtbar, laufStand, letzterOffenerLauf,
} from './store.js';
import { anwenden as themaAnwenden } from './theme.js';
import { BEREICHE } from './woerter.js';
import { RECHTSCHREIBUNG } from './rechtschreibung.js';
import { RECHTSCHREIBUNG1 } from './rechtschreibung1.js';
import { RECHTSCHREIBUNG2 } from './rechtschreibung2.js';
import { RECHTSCHREIBUNG3 } from './rechtschreibung3.js';
import { pakete, paketzahl, PAKETGROESSE, paketspanne } from './paket.js';
import { UEBUNGEN, uebungNachId, stufenFuer, stufenIdsFuer } from './uebungen/index.js';
import { laufStarten } from './lauf.js';
import { einstellungenZeigen } from './einstellungen.js';
import { bereicheVerwalten } from './bereiche.js';
import {
  lehrkraftAnmeldung, klassenVerwalten, beitreten, fortschrittHochladen,
  anmeldenMitCode, klasseAuffrischen,
} from './klasse.js';
import { angemeldet, wolkeStarten, abmelden, beiKontoWechsel, verwaltungPruefen } from './cloud.js';
import { schulverwaltung } from './admin.js';
import { alsApp } from './plattform.js';
import * as sfx from './sfx.js';
import { FASSUNG } from './version.js';

// „Die 4 Stufen" liest ein Zweitklässler stockend. Bis fünf reicht das Wort.
const ZAHLWORT = ['keine', 'eine', 'zwei', 'drei', 'vier', 'fünf'];

const buehne = () => document.getElementById('buehne');
let laufAbbrechen = null;

/* ---------- Bereiche zusammenstellen ---------- */

/**
 * Alle Bereiche, die es gibt — auch die ausgeblendeten. Für den Wegweiser und
 * die Auswahl. Was auf der Startseite erscheint, entscheidet
 * `sichtbareBereiche()`: Ein Kind, das einen Auftrag für einen Block bekommt,
 * muss ihn öffnen können, auch wenn er nicht auf der Startseite steht.
 */
function alleBereiche() {
  return BEREICHE.concat(
    RECHTSCHREIBUNG1, RECHTSCHREIBUNG2, RECHTSCHREIBUNG3, RECHTSCHREIBUNG, eigeneBereiche());
}


function bereichNachId(id) {
  return alleBereiche().find((b) => b.id === id) || null;
}

/* ---------- Ansicht 1: die Bereiche ---------- */

function bereicheZeigen() {
  const gitter = h('div', { class: 'bereiche' });
  const eigene = eigeneBereiche();
  const themen = BEREICHE.filter(bereichSichtbar);
  const bloecke = RECHTSCHREIBUNG1
    .concat(RECHTSCHREIBUNG2, RECHTSCHREIBUNG3, RECHTSCHREIBUNG).filter(bereichSichtbar);

  const karte = (bereich, eigen) => {
    const anzahl = paketzahl(bereich);
    // Nicht jeder Bereich übt alle fünf Stufen — die 1. Klasse lässt die
    // Wortart weg. Sonst stünde dort für immer „0 von 120", obwohl alles
    // geschafft ist.
    const stufenIds = stufenIdsFuer(bereich);
    const moeglich = anzahl * stufenIds.length * 3;
    const erreicht = sterneImBereich(bereich.id, anzahl, stufenIds);
    return h('button', {
      class: `bereichskarte${eigen ? ' is-eigen' : ''}`,
      type: 'button',
      style: { '--bereichsfarbe': bereich.farbe || '#2563eb' },
      onclick: () => { sfx.tipp(); gehZu(`#/bereich/${bereich.id}`); },
    },
      h('span', { class: 'bereichskarte__emoji' }, bereich.emoji || '📗'),
      h('span', { class: 'bereichskarte__name' }, bereich.name),
      h('span', { class: 'bereichskarte__zahl' }, `${bereich.woerter.length} Wörter · ${anzahl} Päckchen`),
      h('span', { class: 'bereichskarte__balken' }, balken(moeglich ? erreicht / moeglich : 0, `${erreicht} von ${moeglich} Sternen`)),
      h('span', { class: 'bereichskarte__sterne' }, `${erreicht} / ${moeglich} ★`));
  };

  const auftragskarte = auftragZeigen();
  const weiterkarte = weitermachenZeigen();

  for (const bereich of eigene) gitter.appendChild(karte(bereich, true));
  for (const bereich of themen) gitter.appendChild(karte(bereich, false));

  const blockgitter = h('div', { class: 'bereiche' });
  for (const bereich of bloecke) blockgitter.appendChild(karte(bereich, false));

  leeren(buehne()).appendChild(h('div', { class: 'seite' },
    auftragskarte,
    weiterkarte,
    h('div', { class: 'seite__kopf' },
      h('h1', { class: 'seite__titel' }, 'Wörterwerkstatt'),
      h('p', { class: 'seite__untertitel' },
        'Such dir einen Bereich aus. Ein Trainingspäckchen hat höchstens '
        + `${PAKETGROESSE} Lernwörter und bis zu fünf Stufen.`)),
    eigene.length ? h('h2', { class: 'seite__abschnitt' }, 'Von deiner Lehrerin oder deinem Lehrer') : null,
    gitter,
    bloecke.length ? h('h2', { class: 'seite__abschnitt' }, 'Rechtschreibung') : null,
    bloecke.length ? blockgitter : null,
    (!eigene.length && !themen.length && !bloecke.length)
      ? h('p', { class: 'seite__untertitel' },
        'Zurzeit ist kein Bereich freigeschaltet. Unter ⚙︎ → „Bereiche wählen" lässt sich das ändern.')
      : null));
}

/**
 * „Weitermachen" — der angefangene Durchgang von vorhin.
 *
 * Im Unterricht kommt ein Kind selten bis zum Ende eines Päckchens. Ohne
 * diese Karte müsste es sich merken, wo es war, und sich dreimal durchtippen;
 * mit ihr ist es ein Tipp (Ansage des Nutzers, 08/2026).
 */
function weitermachenZeigen() {
  const stand = letzterOffenerLauf();
  if (!stand) return null;
  const bereich = bereichNachId(stand.bereichId);
  const uebung = uebungNachId(stand.stufe);
  if (!bereich || !uebung) return null;
  const geschafft = (stand.merkzettel || []).length;
  return h('button', {
    class: 'weiter', type: 'button',
    onclick: () => { sfx.tipp(); gehZu(`#/ueben/${stand.bereichId}/${stand.paket}/${stand.stufe}`); },
  },
    h('span', { class: 'weiter__marke' }, 'Angefangen'),
    h('span', { class: 'weiter__text' },
      `${bereich.emoji || '📗'} ${bereich.name} · Päckchen ${(stand.paket || 0) + 1} · ${uebung.emoji} ${uebung.name}`),
    h('span', { class: 'weiter__stand' }, `${geschafft} von ${stand.gesamt || '?'} Wörtern`),
    h('span', { class: 'auftrag__pfeil' }, '→'));
}

/** Der Auftrag der Woche, falls die Lehrkraft einen gesetzt hat. */
function auftragZeigen() {
  const kind = nutzer();
  if (!kind || kind.art !== 'kind') return null;
  const klasse = klassen().find((k) => k.code === kind.klasse);
  const auftrag = klasse && klasse.auftrag;
  if (!auftrag || !auftrag.bereichId) return null;
  const bereich = bereichNachId(auftrag.bereichId);
  if (!bereich) return null;
  const stufe = auftrag.stufe ? uebungNachId(auftrag.stufe) : null;
  return h('button', {
    class: 'auftrag', type: 'button',
    onclick: () => gehZu(auftrag.stufe
      ? `#/ueben/${bereich.id}/${auftrag.paket || 0}/${auftrag.stufe}`
      : `#/bereich/${bereich.id}/${auftrag.paket || 0}`),
  },
    h('span', { class: 'auftrag__marke' }, 'Aufgabe für diese Woche'),
    h('span', { class: 'auftrag__text' },
      `${bereich.emoji || '📗'} ${bereich.name} · Päckchen ${(auftrag.paket || 0) + 1}`
      + (stufe ? ` · ${stufe.emoji} ${stufe.name}` : '')),
    h('span', { class: 'auftrag__pfeil' }, '→'));
}

/* ---------- Ansicht 2: Päckchen und Stufen ---------- */

function paketeZeigen(bereichId, offenesPaket = 0) {
  const bereich = bereichNachId(bereichId);
  if (!bereich) { gehZu('#/'); return; }
  const alle = pakete(bereich);
  const gewaehlt = Math.min(Math.max(0, offenesPaket), alle.length - 1);
  const stufenliste = stufenFuer(bereich);

  const reiter = h('div', { class: 'paketreiter', role: 'tablist' });
  alle.forEach((liste, nummer) => {
    const erreicht = stufenliste.reduce((summe, uebung) => {
      const stand = fortschritt(bereich.id, nummer, uebung.id);
      return summe + (stand ? stand.sterne || 0 : 0);
    }, 0);
    reiter.appendChild(h('button', {
      class: `paketreiter__knopf${nummer === gewaehlt ? ' is-aktiv' : ''}`,
      type: 'button', role: 'tab', 'aria-selected': nummer === gewaehlt ? 'true' : 'false',
      onclick: () => gehZu(`#/bereich/${bereich.id}/${nummer}`),
    },
      h('span', { class: 'paketreiter__nummer' }, `Päckchen ${nummer + 1}`),
      h('span', { class: 'paketreiter__sterne' }, `${erreicht} ★`)));
  });

  const woerter = h('div', { class: 'wortvorschau' });
  for (const eintrag of alle[gewaehlt]) {
    woerter.appendChild(h('span', { class: `wortvorschau__wort wortvorschau__wort--${eintrag.art}` },
      eintrag.art === 'n' && eintrag.artikel ? `${eintrag.artikel} ${eintrag.wort}` : eintrag.wort));
  }

  const stufen = h('div', { class: 'stufen' });
  // Durchgezählt wird, was dieser Bereich übt — nicht die feste Nummer der
  // Übung. Sonst stünde in der 1. Klasse „1 2 3 5" auf den Kacheln.
  stufenliste.forEach((uebung, stelle) => {
    const stand = fortschritt(bereich.id, gewaehlt, uebung.id);
    const offen = laufStand(bereich.id, gewaehlt, uebung.id);
    stufen.appendChild(h('button', {
      class: 'stufe', type: 'button',
      style: { '--stufenfarbe': uebung.farbe },
      onclick: () => { sfx.tipp(); gehZu(`#/ueben/${bereich.id}/${gewaehlt}/${uebung.id}`); },
    },
      h('span', { class: 'stufe__nummer' }, stelle + 1),
      h('span', { class: 'stufe__emoji' }, uebung.emoji),
      h('span', { class: 'stufe__text' },
        h('strong', {}, uebung.name),
        h('span', {}, uebung.beschreibung)),
      h('span', { class: 'stufe__sterne' }, sterneAnzeige(stand ? stand.sterne || 0 : 0)),
      // Ein angefangener Durchgang muss an der Kachel zu sehen sein — sonst
      // wüsste ein Kind erst nach dem Tippen, dass es weitergeht.
      offen ? h('span', { class: 'stufe__offen' }, `▸ ${(offen.merkzettel || []).length} / ${offen.gesamt}`) : null));
  });

  leeren(buehne()).appendChild(h('div', { class: 'seite' },
    h('div', { class: 'seite__kopf' },
      h('button', { class: 'zurueck', type: 'button', onclick: () => gehZu('#/') }, '‹ Alle Bereiche'),
      h('h1', { class: 'seite__titel' }, `${bereich.emoji || '📗'} ${bereich.name}`),
      h('p', { class: 'seite__untertitel' }, `${bereich.woerter.length} Lernwörter in ${alle.length} Päckchen`)),
    reiter,
    h('div', { class: 'paketkarte' },
      h('h2', { class: 'paketkarte__titel' }, `Päckchen ${gewaehlt + 1}`),
      h('p', { class: 'paketkarte__spanne' }, paketspanne(alle[gewaehlt])),
      woerter),
    h('h2', { class: 'seite__abschnitt' }, `Die ${ZAHLWORT[stufenliste.length] || stufenliste.length} Stufen`),
    stufen));
}

/* ---------- Ansicht 3: üben ---------- */

function uebenZeigen(bereichId, paketNummer, stufeId) {
  const bereich = bereichNachId(bereichId);
  const uebung = uebungNachId(stufeId);
  if (!bereich || !uebung) { gehZu('#/'); return; }
  // Eine Stufe, die dieser Bereich nicht übt, ist auch über die Adresse nicht
  // zu erreichen — ein alter Auftrag oder ein Lesezeichen käme sonst dorthin.
  if (!stufenIdsFuer(bereich).includes(stufeId)) { gehZu(`#/bereich/${bereich.id}/${paketNummer}`); return; }
  document.body.classList.add('is-uebend');
  laufAbbrechen = laufStarten({
    platz: buehne(),
    bereich,
    paketNummer,
    stufeId,
    aufAbbruch: () => {
      document.body.classList.remove('is-uebend');
      gehZu(`#/bereich/${bereich.id}/${paketNummer}`);
    },
    aufEnde: (ergebnis) => {
      document.body.classList.remove('is-uebend');
      fortschrittHochladen();
      if (!ergebnis.weiter) { gehZu(`#/bereich/${bereich.id}/${paketNummer}`); return; }
      if (ergebnis.sterne === 3) {
        // Geschafft — die nächste Stufe, oder das nächste Päckchen.
        const ids = stufenIdsFuer(bereich);
        const stelle = ids.indexOf(stufeId);
        if (stelle + 1 < ids.length) {
          gehZu(`#/ueben/${bereich.id}/${paketNummer}/${ids[stelle + 1]}`);
          return;
        }
        if (paketNummer + 1 < paketzahl(bereich)) {
          gehZu(`#/ueben/${bereich.id}/${paketNummer + 1}/${ids[0]}`);
          return;
        }
        gehZu(`#/bereich/${bereich.id}/${paketNummer}`);
        return;
      }
      gehZu(`#/ueben/${bereich.id}/${paketNummer}/${stufeId}`, true);
    },
  });
}

/* ---------- Wegweiser ---------- */

function gehZu(adresse, erzwingen = false) {
  if (erzwingen && window.location.hash === adresse) { wegLesen(); return; }
  window.location.hash = adresse;
}

function wegabschnitte() {
  return (window.location.hash || '#/').replace(/^#\/?/, '').split('/').filter(Boolean);
}

/**
 * Zeigt die aktuelle Adresse die Bereichsübersicht? Danach richtet sich, ob
 * ein Datenereignis die Bühne neu zeichnen darf — mehr als neu zeichnen darf
 * es nie (siehe start()).
 */
function zeigtBereiche() {
  const teile = wegabschnitte();
  return !teile.length || teile[0] === 'beitreten';
}

// Für welchen Klassencode gerade ein Beitrittsblatt offen ist. Ohne diesen
// Merker öffnet jeder erneute Durchlauf des Wegweisers ein weiteres Blatt —
// und weil ein Beitritt Bereiche sichert und das wiederum meldet, waren das
// in vier Sekunden 279 gestapelte Blätter und ebenso viele Netzanfragen. Auf
// dem Gerät heißt das: Das Eingabefeld liegt sofort unter dem nächsten Blatt,
// und der Tab stirbt.
let offenerBeitritt = null;

function wegLesen() {
  if (laufAbbrechen) { laufAbbrechen(); laufAbbrechen = null; }
  document.body.classList.remove('is-uebend');
  const teile = wegabschnitte();

  if (teile[0] === 'beitreten' && teile[1]) {
    const code = teile[1].toUpperCase();
    if (offenerBeitritt === code) return;
    offenerBeitritt = code;
    bereicheZeigen();
    beitreten(code, () => { gehZu('#/'); kopfleisteZeichnen(); bereicheZeigen(); }, () => { offenerBeitritt = null; });
    return;
  }
  offenerBeitritt = null;
  if (teile[0] === 'ueben' && teile[1] && teile[3]) {
    uebenZeigen(teile[1], Number(teile[2]) || 0, teile[3]);
    return;
  }
  if (teile[0] === 'bereich' && teile[1]) {
    paketeZeigen(teile[1], Number(teile[2]) || 0);
    return;
  }
  bereicheZeigen();
}

/* ---------- Kopfleiste ---------- */

function kopfleisteZeichnen() {
  const platz = document.getElementById('kopf-rechts');
  if (!platz) return;
  leeren(platz);
  const angemeldeteLehrkraft = angemeldet();
  const wer = nutzer();

  if (angemeldeteLehrkraft) {
    platz.appendChild(h('button', { class: 'kopf__knopf', type: 'button', title: 'Eigene Bereiche', onclick: () => bereicheVerwalten(() => wegLesen()) }, '📚 Bereiche'));
    platz.appendChild(h('button', { class: 'kopf__knopf', type: 'button', title: 'Meine Klassen', onclick: () => klassenVerwalten() }, '👩‍🏫 Klassen'));
    // Die Schulverwaltung erscheint erst, wenn die Datenbank sie zulässt.
    // Gefragt wird sie, nicht die App: `verwaltungPruefen` versucht schlicht,
    // das Verzeichnis aller Lehrkräfte zu lesen. Die Antwort kommt aus dem
    // Netz, deshalb wird der Knopf nachgereicht — und nur, wenn die Kopfleiste
    // inzwischen nicht schon jemand anderem gehört.
    verwaltungPruefen().then((darf) => {
      if (!darf || !angemeldet() || !document.getElementById('kopf-rechts')) return;
      if (platz.querySelector('.kopf__knopf--schule')) return;
      const knopf = h('button', {
        class: 'kopf__knopf kopf__knopf--schule', type: 'button', title: 'Schulverwaltung',
        onclick: () => schulverwaltung(),
      }, '🏫 Schule');
      platz.insertBefore(knopf, platz.firstChild);
    }).catch(() => {});
  } else if (wer && wer.art === 'kind') {
    platz.appendChild(h('span', { class: 'kopf__wer' }, `👋 ${wer.name}`));
  } else {
    // Ohne diesen Knopf kommt ein Kind auf einem frischen Gerät gar nicht
    // hinein — es bräuchte den QR-Code, und der hängt nicht immer da.
    platz.appendChild(h('button', {
      class: 'kopf__knopf kopf__knopf--voll', type: 'button',
      onclick: () => anmeldenMitCode(),
    }, '👋 Mitmachen'));
    platz.appendChild(h('button', { class: 'kopf__knopf', type: 'button', onclick: () => lehrkraftAnmeldung(() => kopfleisteZeichnen()) }, 'Für Lehrkräfte'));
  }

  platz.appendChild(h('button', {
    class: 'kopf__knopf kopf__knopf--rund', type: 'button', title: 'Einstellungen', 'aria-label': 'Einstellungen',
    onclick: () => einstellungenZeigen(),
  }, '⚙︎'));
  platz.appendChild(h('button', {
    class: 'kopf__knopf kopf__knopf--rund', type: 'button', title: 'Hilfe und Informationen', 'aria-label': 'Hilfe',
    onclick: () => hilfeZeigen(),
  }, '?'));
}

/**
 * Die eigene Rückschau: Wörter, die danebengingen, mit dem, was man geschrieben
 * hat. Wer die Daten erzeugt, soll sie auch sehen dürfen — und für ein Kind
 * ist „diese sechs Wörter waren schwer für dich" die brauchbarste Auskunft,
 * die die App geben kann.
 */
function meineWoerter() {
  // Der Behälter zeichnet sich selbst neu, statt das ganze Blatt noch einmal
  // zu öffnen — sonst stapeln sich Hilfe-Blätter übereinander.
  const platz = h('div', {});
  function zeichnen() {
    leeren(platz);
    const liste = schwereWoerter(12);
    if (!liste.length) {
      platz.appendChild(h('p', { class: 'blatt__text' },
        'Noch nichts danebengegangen — oder du hast noch nicht geübt.'));
      return;
    }
    for (const wort of liste) {
      platz.appendChild(h('div', { class: 'wortbefund' },
        h('div', { class: 'wortbefund__kopf' },
          h('strong', { class: 'wortbefund__wort' }, wort.wort),
          h('span', { class: 'wortbefund__zahlen' },
            `${wort.richtig} von ${wort.versuche} gleich richtig`)),
        wort.eingaben.length
          ? h('div', { class: 'wortbefund__eingaben' },
            h('span', { class: 'wortbefund__marke' }, 'du schriebst'),
            ...wort.eingaben.map((e) => h('span', { class: 'wortbefund__falsch' }, e)))
          : null));
    }
    platz.appendChild(h('button', {
      class: 'knopf knopf--still knopf--klein', type: 'button',
      onclick: async () => {
        const ja = await frage({
          titel: 'Alles vergessen?',
          text: 'Die Liste deiner schweren Wörter wird geleert. Deine Sterne bleiben.',
          ja: 'Leeren',
        });
        if (ja) { protokollLeeren(); zeichnen(); }
      },
    }, 'Liste leeren'));
  }
  zeichnen();
  return platz;
}

function hilfeZeigen() {
  const wer = nutzer();
  return blatt({
    titel: 'Wörterwerkstatt',
    breit: true,
    inhalt: h('div', {},
      h('p', { class: 'blatt__text' },
        'Fünf Stufen, mit denen ein Lernwort wirklich sitzt — von „einfach abschreiben“ bis „nach Diktat schreiben“. '
        + `Ein Trainingspäckchen sind ${PAKETGROESSE} Wörter.`),
      h('ol', { class: 'hilfe__stufen' },
        ...UEBUNGEN.map((u) => h('li', {},
          h('strong', {}, `${u.emoji} ${u.name}`), ' — ', u.beschreibung))),
      h('h3', {}, 'Sterne'),
      h('p', { class: 'blatt__text' },
        'Drei Sterne gibt es, wenn jedes Wort gleich beim ersten Versuch richtig war, zwei ab vier Fünfteln, einer ab drei Fünfteln. '
        + 'Der beste Durchgang zählt — ein zweiter, schlechterer nimmt nichts weg.'),
      h('h3', {}, 'Für Lehrkräfte'),
      h('p', { class: 'blatt__text' },
        'Mit einem Konto lassen sich eigene Bereiche anlegen (die Lernwörter dieser Woche) und Klassen: '
        + 'Die App zeigt dann einen QR-Code, die Kinder scannen ihn, suchen sich Name und vierstellige PIN aus — '
        + 'und die Sterne laufen in die Klassenansicht zurück.'),
      h('h3', {}, 'Deine schweren Wörter'),
      meineWoerter(),
      h('h3', {}, 'Ohne Netz'),
      h('p', { class: 'blatt__text' },
        'Alles Üben läuft im Gerät. Netz braucht nur, was zwischen Lehrkraft und Klasse hin und her muss.'),
      wer ? h('div', { class: 'blatt__knopfreihe' },
        h('button', {
          class: 'knopf knopf--still', type: 'button',
          onclick: async () => {
            const ja = await frage({
              titel: 'Abmelden?',
              text: wer.art === 'kind'
                ? 'Deine Sterne bleiben auf diesem Gerät. Mit Name und PIN kommst du wieder hinein.'
                : 'Die eigenen Bereiche bleiben auf diesem Gerät.',
              ja: 'Abmelden',
            });
            if (!ja) return;
            abmelden();
            setzeNutzer(null);
            kopfleisteZeichnen();
            wegLesen();
          },
        }, 'Abmelden')) : null,
      h('p', { class: 'blatt__fussnote' }, `Fassung ${FASSUNG} · läuft ${alsApp() ? 'als App' : 'im Browser'}`)),
  });
}

/* ---------- Start ---------- */

async function start() {
  await ladeZustand();
  themaAnwenden();
  document.body.classList.remove('is-ladend');

  // Die Wolke im Hintergrund wecken: Sie wird nur für Konten und Klassen
  // gebraucht — scheitert sie, läuft alles andere weiter.
  wolkeStarten()
    .then(() => { kopfleisteZeichnen(); return klasseAuffrischen(); })
    .catch(() => {});
  beiKontoWechsel(() => kopfleisteZeichnen());

  horch('fortschritt', () => { fortschrittHochladen(); });
  // NIEMALS wegLesen() aus einem Datenereignis heraus aufrufen. Das Wegfinden
  // hat Nebenwirkungen — es öffnet Blätter und stellt Netzanfragen —, und ein
  // Beitritt sichert die mitgegebenen Bereiche, was genau dieses Ereignis
  // auslöst. Daraus wurde eine Schleife ohne Boden. Ein Datenereignis darf
  // hier nur eines: die Bühne neu zeichnen, und auch das nur, wenn sie
  // gerade die Bereiche zeigt.
  horch('bereiche', () => {
    if (document.body.classList.contains('is-uebend')) return;
    if (zeigtBereiche()) bereicheZeigen();
  });
  horch('sichtbarkeit', () => {
    if (document.body.classList.contains('is-uebend')) return;
    if (zeigtBereiche()) bereicheZeigen();
  });

  window.addEventListener('hashchange', wegLesen);
  kopfleisteZeichnen();
  wegLesen();

  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('./sw.js').catch(() => {});
  }
}

start().catch((fehler) => {
  const platz = buehne();
  if (platz) {
    leeren(platz).appendChild(h('div', { class: 'seite' },
      h('h1', { class: 'seite__titel' }, 'Da ging etwas schief'),
      h('p', { class: 'seite__untertitel' }, String(fehler && fehler.message ? fehler.message : fehler))));
  }
  document.body.classList.remove('is-ladend');
});
