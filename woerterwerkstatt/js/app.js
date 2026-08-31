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
  nutzer, setzeNutzer, klassen, horch,
} from './store.js';
import { anwenden as themaAnwenden } from './theme.js';
import { BEREICHE } from './woerter.js';
import { pakete, paketzahl, PAKETGROESSE, paketspanne } from './paket.js';
import { UEBUNGEN, STUFEN_IDS, uebungNachId } from './uebungen/index.js';
import { laufStarten } from './lauf.js';
import { einstellungenZeigen } from './einstellungen.js';
import { bereicheVerwalten } from './bereiche.js';
import {
  lehrkraftAnmeldung, klassenVerwalten, beitreten, fortschrittHochladen,
} from './klasse.js';
import { angemeldet, wolkeStarten, abmelden, beiKontoWechsel } from './cloud.js';
import { alsApp } from './plattform.js';
import * as sfx from './sfx.js';
import { FASSUNG } from './version.js';

const buehne = () => document.getElementById('buehne');
let laufAbbrechen = null;

/* ---------- Bereiche zusammenstellen ---------- */

function alleBereiche() {
  return BEREICHE.concat(eigeneBereiche());
}

function bereichNachId(id) {
  return alleBereiche().find((b) => b.id === id) || null;
}

/* ---------- Ansicht 1: die Bereiche ---------- */

function bereicheZeigen() {
  const gitter = h('div', { class: 'bereiche' });
  const eigene = eigeneBereiche();

  const karte = (bereich, eigen) => {
    const anzahl = paketzahl(bereich);
    const moeglich = anzahl * STUFEN_IDS.length * 3;
    const erreicht = sterneImBereich(bereich.id, anzahl, STUFEN_IDS);
    return h('button', {
      class: `bereichskarte${eigen ? ' is-eigen' : ''}`,
      type: 'button',
      style: { '--bereichsfarbe': bereich.farbe || '#6366f1' },
      onclick: () => { sfx.tipp(); gehZu(`#/bereich/${bereich.id}`); },
    },
      h('span', { class: 'bereichskarte__emoji' }, bereich.emoji || '📗'),
      h('span', { class: 'bereichskarte__name' }, bereich.name),
      h('span', { class: 'bereichskarte__zahl' }, `${bereich.woerter.length} Wörter · ${anzahl} Päckchen`),
      h('span', { class: 'bereichskarte__balken' }, balken(moeglich ? erreicht / moeglich : 0, `${erreicht} von ${moeglich} Sternen`)),
      h('span', { class: 'bereichskarte__sterne' }, `${erreicht} / ${moeglich} ★`));
  };

  const auftragskarte = auftragZeigen();

  for (const bereich of eigene) gitter.appendChild(karte(bereich, true));
  for (const bereich of BEREICHE) gitter.appendChild(karte(bereich, false));

  leeren(buehne()).appendChild(h('div', { class: 'seite' },
    auftragskarte,
    h('div', { class: 'seite__kopf' },
      h('h1', { class: 'seite__titel' }, 'Wörterwerkstatt'),
      h('p', { class: 'seite__untertitel' },
        'Such dir einen Bereich aus. Jedes Trainingspäckchen hat '
        + `${PAKETGROESSE} Lernwörter und fünf Stufen.`)),
    eigene.length ? h('h2', { class: 'seite__abschnitt' }, 'Von deiner Lehrerin oder deinem Lehrer') : null,
    gitter));
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

  const reiter = h('div', { class: 'paketreiter', role: 'tablist' });
  alle.forEach((liste, nummer) => {
    const erreicht = STUFEN_IDS.reduce((summe, stufe) => {
      const stand = fortschritt(bereich.id, nummer, stufe);
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
  for (const uebung of UEBUNGEN) {
    const stand = fortschritt(bereich.id, gewaehlt, uebung.id);
    stufen.appendChild(h('button', {
      class: 'stufe', type: 'button',
      style: { '--stufenfarbe': uebung.farbe },
      onclick: () => { sfx.tipp(); gehZu(`#/ueben/${bereich.id}/${gewaehlt}/${uebung.id}`); },
    },
      h('span', { class: 'stufe__nummer' }, uebung.nummer),
      h('span', { class: 'stufe__emoji' }, uebung.emoji),
      h('span', { class: 'stufe__text' },
        h('strong', {}, uebung.name),
        h('span', {}, uebung.beschreibung)),
      h('span', { class: 'stufe__sterne' }, sterneAnzeige(stand ? stand.sterne || 0 : 0))));
  }

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
    h('h2', { class: 'seite__abschnitt' }, 'Die fünf Stufen'),
    stufen));
}

/* ---------- Ansicht 3: üben ---------- */

function uebenZeigen(bereichId, paketNummer, stufeId) {
  const bereich = bereichNachId(bereichId);
  const uebung = uebungNachId(stufeId);
  if (!bereich || !uebung) { gehZu('#/'); return; }
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
        const stelle = STUFEN_IDS.indexOf(stufeId);
        if (stelle + 1 < STUFEN_IDS.length) {
          gehZu(`#/ueben/${bereich.id}/${paketNummer}/${STUFEN_IDS[stelle + 1]}`);
          return;
        }
        if (paketNummer + 1 < paketzahl(bereich)) {
          gehZu(`#/ueben/${bereich.id}/${paketNummer + 1}/${STUFEN_IDS[0]}`);
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

function wegLesen() {
  if (laufAbbrechen) { laufAbbrechen(); laufAbbrechen = null; }
  document.body.classList.remove('is-uebend');
  const teile = (window.location.hash || '#/').replace(/^#\/?/, '').split('/').filter(Boolean);

  if (teile[0] === 'beitreten' && teile[1]) {
    bereicheZeigen();
    beitreten(teile[1], () => { gehZu('#/'); kopfleisteZeichnen(); bereicheZeigen(); });
    return;
  }
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
  } else if (wer && wer.art === 'kind') {
    platz.appendChild(h('span', { class: 'kopf__wer' }, `👋 ${wer.name}`));
  } else {
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
  wolkeStarten().then(() => kopfleisteZeichnen()).catch(() => {});
  beiKontoWechsel(() => kopfleisteZeichnen());

  horch('fortschritt', () => { fortschrittHochladen(); });
  horch('bereiche', () => { if (!document.body.classList.contains('is-uebend')) wegLesen(); });

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
