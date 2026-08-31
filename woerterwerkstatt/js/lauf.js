// Der Durchgang: fünfzehn Wörter, eine Stufe, ein Ergebnis.
//
// Der Lauf hält die Aufgaben zusammen und weiß als Einziger, wie es dem Kind
// gerade geht. Die Übungen selbst wissen nichts voneinander — sie bekommen ein
// Wort und melden zurück, ob es saß.
//
// Zwei Regeln, die den Ton der App bestimmen:
//
// * **Es geht immer weiter.** Ein falsch geschriebenes Wort hält niemanden auf;
//   es wandert ans Ende der Runde und kommt noch einmal. Wer ein Päckchen
//   anfängt, bringt es zu Ende.
// * **Kein Zeitdruck.** Die Zeit wird gemessen, aber nirgends angezeigt,
//   solange gearbeitet wird. Rechtschreibung lernt man nicht auf Zeit.

import { h, leeren, gemischt, warte, wenigBewegung } from './util.js';
import { paket, paketzahl } from './paket.js';
import { uebungNachId } from './uebungen/index.js';
import { ergebnisMerken, merkeBereich, protokollMerken } from './store.js';
import { sterne as sterneAnzeige, balken } from './ui.js';
import { bleibWach } from './plattform.js';
import * as sfx from './sfx.js';

/**
 * Startet einen Durchgang und hängt ihn in `platz`.
 *
 * aufEnde({ richtig, gesamt, sterne, abgebrochen }) — wird immer gerufen,
 * auch beim Abbrechen. Der Aufrufer entscheidet, wohin es danach geht.
 */
export function laufStarten({ platz, bereich, paketNummer, stufeId, aufEnde, aufAbbruch }) {
  const uebung = uebungNachId(stufeId);
  const woerter = paket(bereich, paketNummer);
  if (!uebung || !woerter.length) {
    aufEnde({ richtig: 0, gesamt: 0, sterne: 0, abgebrochen: true });
    return () => {};
  }

  // Die Reihenfolge wird gemischt: Sonst lernt ein Kind beim vierten Durchgang
  // die Reihenfolge statt der Wörter.
  let warteschlange = gemischt(woerter.slice());
  const gesamt = woerter.length;
  const begonnen = Date.now();
  let erledigt = 0;
  let richtig = 0;
  let laufend = true;
  const nachzuegler = [];
  const merkzettel = [];

  bleibWach(true);

  const fortschrittsbalken = balken(0, 'Fortschritt im Päckchen');
  const zaehler = h('span', { class: 'lauf__zaehler' });
  const abbrechen = h('button', { class: 'lauf__zu', type: 'button', title: 'Übung beenden', 'aria-label': 'Übung beenden' }, '✕');
  const kopf = h('header', { class: 'lauf__kopf' },
    abbrechen,
    h('div', { class: 'lauf__titel' },
      h('span', { class: 'lauf__stufe' }, `${uebung.emoji} ${uebung.name}`),
      h('span', { class: 'lauf__bereich' }, `${bereich.emoji || '📗'} ${bereich.name} · Päckchen ${paketNummer + 1}`)),
    zaehler);
  const buehne = h('div', { class: 'lauf__buehne' });
  const wurzel = h('div', { class: 'lauf' }, kopf, fortschrittsbalken, buehne);

  leeren(platz).appendChild(wurzel);

  abbrechen.addEventListener('click', async () => {
    if (!laufend) return;
    const { frage } = await import('./ui.js');
    const ja = await frage({
      titel: 'Übung beenden?',
      text: erledigt ? `Du hast ${erledigt} von ${gesamt} Wörtern geschafft. Der Durchgang wird nicht gewertet.` : 'Du hast noch nichts geschafft — der Durchgang wird nicht gewertet.',
      ja: 'Beenden',
      nein: 'Weitermachen',
      gefahr: true,
    });
    if (ja) beenden(true);
  });

  function standZeigen() {
    zaehler.textContent = `${Math.min(erledigt + 1, gesamt)} / ${gesamt}`;
    const anteil = erledigt / gesamt;
    const i = fortschrittsbalken.querySelector('i');
    if (i) i.style.width = `${Math.round(anteil * 100)}%`;
  }

  function naechstes() {
    if (!laufend) return;
    if (!warteschlange.length && nachzuegler.length) {
      // Die Wörter, die beim ersten Mal danebengingen, kommen noch einmal —
      // aber sie sind schon gewertet.
      warteschlange = nachzuegler.splice(0, nachzuegler.length);
      buehne.appendChild(h('p', { class: 'lauf__runde' }, 'Und jetzt noch einmal die Wörter, die schwer waren.'));
    }
    if (!warteschlange.length) { beenden(false); return; }

    const eintrag = warteschlange.shift();
    standZeigen();

    const karte = h('div', { class: 'lauf__karte' });
    const inhalt = uebung.aufbauen({
      eintrag,
      bereich,
      aufFertig: (ergebnis) => aufgabeFertig(eintrag, ergebnis, karte),
    });
    karte.appendChild(inhalt);
    leeren(buehne).appendChild(karte);
    requestAnimationFrame(() => karte.classList.add('is-da'));
  }

  async function aufgabeFertig(eintrag, ergebnis, karte) {
    if (!laufend) return;
    // Jede bearbeitete Aufgabe wandert ins Wortprotokoll — auch die im
    // zweiten Durchgang: Dass ein Wort zweimal drankam und beim zweiten Mal
    // saß, ist für die Lehrkraft eine Auskunft und keine Doppelzählung.
    protokollMerken({
      bereich,
      eintrag,
      stufeId,
      richtig: Boolean(ergebnis.richtig),
      fehlversuche: ergebnis.fehlversuche || [],
    });
    const zumErstenMal = !merkzettel.some((m) => m.id === eintrag.id);
    if (zumErstenMal) {
      erledigt += 1;
      if (ergebnis.richtig) richtig += 1;
      else nachzuegler.push(eintrag);
      merkzettel.push({ id: eintrag.id, wort: eintrag.wort, richtig: Boolean(ergebnis.richtig) });
    }
    standZeigen();
    karte.classList.add(ergebnis.richtig ? 'is-geschafft' : 'is-daneben');
    karte.dispatchEvent(new CustomEvent('uebung-ende', { bubbles: true }));
    await warte(wenigBewegung() ? 200 : 720);
    if (!laufend) return;
    karte.classList.add('is-fort');
    await warte(wenigBewegung() ? 0 : 200);
    naechstes();
  }

  function beenden(abgebrochen) {
    if (!laufend) return;
    laufend = false;
    bleibWach(false);
    buehne.querySelectorAll('.lauf__karte').forEach((k) => k.dispatchEvent(new CustomEvent('uebung-ende', { bubbles: true })));
    if (abgebrochen) {
      if (aufAbbruch) aufAbbruch();
      else aufEnde({ richtig, gesamt, sterne: 0, abgebrochen: true });
      return;
    }
    const dauer = Date.now() - begonnen;
    const stand = ergebnisMerken(bereich.id, paketNummer, stufeId, { richtig, gesamt, dauer });
    merkeBereich(bereich.id);
    zeigeErgebnis(stand, dauer);
  }

  function zeigeErgebnis(stand, dauer) {
    const anzahlSterne = stand.sterne;
    sfx.fertig(anzahlSterne);
    const falscheWoerter = merkzettel.filter((m) => !m.richtig);
    const letztesPaket = paketNummer + 1 >= paketzahl(bereich);

    const ergebnis = h('div', { class: 'ergebnis' },
      h('div', { class: 'ergebnis__krone' }, anzahlSterne === 3 ? '🏆' : (anzahlSterne >= 1 ? '🎉' : '💪')),
      h('h2', { class: 'ergebnis__titel' },
        anzahlSterne === 3 ? 'Alles richtig!' : (anzahlSterne >= 2 ? 'Stark gemacht!' : (anzahlSterne >= 1 ? 'Gut dabei!' : 'Weiter üben!'))),
      h('div', { class: 'ergebnis__sterne' }, sterneAnzeige(anzahlSterne)),
      h('p', { class: 'ergebnis__zahl' }, `${richtig} von ${gesamt} Wörtern gleich richtig`),
      h('p', { class: 'ergebnis__dauer' }, dauerText(dauer)),
      falscheWoerter.length
        ? h('div', { class: 'ergebnis__merkliste' },
          h('h3', {}, 'Diese Wörter schau dir noch einmal an:'),
          h('div', { class: 'ergebnis__woerter' }, falscheWoerter.map((m) => h('span', { class: 'ergebnis__wort' }, m.wort))))
        : h('p', { class: 'ergebnis__lob' }, 'Kein einziges Wort war schwer für dich.'),
      h('div', { class: 'ergebnis__knoepfe' },
        h('button', { class: 'knopf knopf--still', type: 'button', onclick: () => aufEnde({ richtig, gesamt, sterne: anzahlSterne, abgebrochen: false }) }, 'Zur Übersicht'),
        h('button', {
          class: 'knopf knopf--voll',
          type: 'button',
          onclick: () => aufEnde({ richtig, gesamt, sterne: anzahlSterne, abgebrochen: false, weiter: true, letztesPaket }),
        }, anzahlSterne === 3 ? 'Nächste Übung' : 'Noch einmal')));

    leeren(buehne).appendChild(ergebnis);
    requestAnimationFrame(() => ergebnis.classList.add('is-da'));
    if (anzahlSterne >= 2 && !wenigBewegung()) konfetti(buehne);
  }

  naechstes();

  return () => { laufend = false; bleibWach(false); };
}

/** „Dafür hast du eine Minute gebraucht." — mit richtiger Ein- und Mehrzahl. */
function dauerText(dauer) {
  const sekunden = Math.round(dauer / 1000);
  if (sekunden < 90) return `Dafür hast du ${sekunden} Sekunden gebraucht.`;
  const minuten = Math.round(sekunden / 60);
  return `Dafür hast du ${minuten} Minuten gebraucht.`;
}

/**
 * Konfetti — sparsam: dreißig Schnipsel, anderthalb Sekunden, danach weg.
 * Bei „Bewegung reduzieren“ passiert gar nichts (siehe Aufrufer).
 */
function konfetti(platz) {
  const farben = ['#2563eb', '#38bdf8', '#f97316', '#facc15', '#dc2626'];
  const feld = h('div', { class: 'konfetti', 'aria-hidden': 'true' });
  for (let i = 0; i < 30; i += 1) {
    feld.appendChild(h('i', {
      style: {
        '--x': `${Math.random() * 100}%`,
        '--verzug': `${Math.random() * 400}ms`,
        '--dreh': `${Math.random() * 720 - 360}deg`,
        background: farben[i % farben.length],
      },
    }));
  }
  platz.appendChild(feld);
  setTimeout(() => feld.remove(), 2200);
}
