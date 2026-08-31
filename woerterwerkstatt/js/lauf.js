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
import {
  ergebnisMerken, merkeBereich, protokollMerken, laufMerken, laufStand, laufVergessen,
} from './store.js';
import { sterne as sterneAnzeige, balken } from './ui.js';
import { bleibWach } from './plattform.js';
import * as sfx from './sfx.js';

/**
 * Einen gemerkten Stand wieder zu Wörtern machen — oder verwerfen.
 *
 * Gemerkt sind nur Kennungen (`bereichId:wort`). Zwischen zwei Sitzungen kann
 * sich das Päckchen geändert haben: Eine Lehrkraft hat ihren eigenen Bereich
 * bearbeitet, ein Wort ist dazugekommen oder weggefallen. Dann passt der
 * Stand nicht mehr, und weiterzumachen hieße, mit halb falschen Zahlen zu
 * rechnen. In dem Fall wird lieber von vorn begonnen — ein verlorener halber
 * Durchgang ist ärgerlich, ein falscher Zähler ist schlimmer.
 *
 * Geprüft wird deshalb streng: Jede Kennung muss im Päckchen vorkommen, und
 * jedes Wort muss genau einmal entweder offen oder erledigt sein.
 */
function aufgenommen(stand, woerter) {
  if (!stand || !Array.isArray(stand.warteschlange) || !Array.isArray(stand.merkzettel)) return null;
  const nachId = new Map(woerter.map((e) => [e.id, e]));
  const finde = (ids) => {
    const gefunden = ids.map((id) => nachId.get(id));
    return gefunden.some((e) => !e) ? null : gefunden;
  };
  const warteschlange = finde(stand.warteschlange);
  const nachzuegler = finde(stand.nachzuegler || []);
  if (!warteschlange || !nachzuegler) return null;
  if (stand.merkzettel.some((m) => !nachId.has(m.id))) return null;
  if (warteschlange.length + stand.merkzettel.length !== woerter.length) return null;
  // Nichts mehr offen? Dann war der Durchgang in Wahrheit fertig.
  if (!warteschlange.length && !nachzuegler.length) return null;
  return {
    warteschlange,
    nachzuegler,
    merkzettel: stand.merkzettel.map((m) => ({ id: m.id, wort: m.wort, richtig: !!m.richtig })),
    dauer: Number(stand.dauer) || 0,
  };
}

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

  const gesamt = woerter.length;

  // Ein abgebrochener Durchgang von vorhin wird fortgesetzt — im Unterricht
  // ist das der Regelfall, nicht die Ausnahme. Gemerkt sind nur Kennungen;
  // die Wörter selbst kommen frisch aus dem Päckchen.
  const gemerkt = aufgenommen(laufStand(bereich.id, paketNummer, stufeId), woerter);

  // Die Reihenfolge wird gemischt: Sonst lernt ein Kind beim vierten Durchgang
  // die Reihenfolge statt der Wörter.
  let warteschlange = gemerkt ? gemerkt.warteschlange : gemischt(woerter.slice());
  let begonnen = Date.now();
  let vorherigeDauer = gemerkt ? gemerkt.dauer : 0;
  let laufend = true;
  const nachzuegler = gemerkt ? gemerkt.nachzuegler : [];
  const merkzettel = gemerkt ? gemerkt.merkzettel : [];
  // Das Wort, das gerade auf dem Tisch liegt. Es ist aus der Warteschlange
  // heraus, aber noch nicht beantwortet — beim Sichern muss es wieder vorn
  // hinein, sonst fiele es bei einem Abbruch zwischen die Stühle.
  let aktuell = null;
  let erledigt = merkzettel.length;
  let richtig = merkzettel.filter((m) => m.richtig).length;

  bleibWach(true);

  const fortschrittsbalken = balken(0, 'Fortschritt im Päckchen');
  const zaehler = h('span', { class: 'lauf__zaehler' });
  const abbrechen = h('button', { class: 'lauf__zu', type: 'button', title: 'Übung beenden', 'aria-label': 'Übung beenden' }, '✕');
  // Nur beim Fortsetzen: Wer lieber noch einmal ganz von vorn anfängt, soll
  // das können, ohne den Stand irgendwo suchen zu müssen.
  const vonVorn = gemerkt
    ? h('button', { class: 'lauf__vonvorn', type: 'button', title: 'Diesen Durchgang von vorn beginnen' }, '⟲ Von vorn')
    : null;
  const kopf = h('header', { class: 'lauf__kopf' },
    abbrechen,
    h('div', { class: 'lauf__titel' },
      h('span', { class: 'lauf__stufe' }, `${uebung.emoji} ${uebung.name}`),
      h('span', { class: 'lauf__bereich' }, `${bereich.emoji || '📗'} ${bereich.name} · Päckchen ${paketNummer + 1}`)),
    vonVorn,
    zaehler);
  const buehne = h('div', { class: 'lauf__buehne' });
  // Eine Notiz über der Bühne — NICHT darin: `naechstes()` räumt die Bühne
  // für jede Karte leer. Bis 1.7.0 stand „Und jetzt noch einmal die Wörter,
  // die schwer waren" mitten darin und war im selben Augenblick wieder weg,
  // in dem sie erschien. Niemand hat sie je gelesen.
  const laufhinweis = h('p', { class: 'lauf__runde is-versteckt' });
  const wurzel = h('div', { class: 'lauf' }, kopf, fortschrittsbalken, laufhinweis, buehne);

  const hinweisSagen = (text) => {
    laufhinweis.textContent = text;
    laufhinweis.classList.remove('is-versteckt');
  };
  const hinweisWeg = () => laufhinweis.classList.add('is-versteckt');

  leeren(platz).appendChild(wurzel);

  abbrechen.addEventListener('click', async () => {
    if (!laufend) return;
    const { frage } = await import('./ui.js');
    const ja = await frage({
      titel: 'Übung beenden?',
      // Kein Drohsatz mehr: Der Stand bleibt liegen, und das ist die
      // wichtigste Auskunft für ein Kind, dem es gerade klingelt.
      text: erledigt
        ? `Du hast ${erledigt} von ${gesamt} Wörtern geschafft. Dein Stand bleibt gespeichert — `
          + 'beim nächsten Mal geht es hier weiter. Gewertet wird erst das ganze Päckchen.'
        : 'Du hast noch nichts geschafft. Beim nächsten Mal fängst du hier wieder an.',
      ja: 'Beenden',
      nein: 'Weitermachen',
    });
    if (ja) beenden(true);
  });

  if (vonVorn) {
    vonVorn.addEventListener('click', async () => {
      if (!laufend) return;
      const { frage } = await import('./ui.js');
      const ja = await frage({
        titel: 'Von vorn beginnen?',
        text: `Die ${erledigt} schon bearbeiteten Wörter kommen noch einmal dran.`,
        ja: 'Von vorn',
        nein: 'Weiter wie bisher',
      });
      if (!ja) return;
      laufVergessen(bereich.id, paketNummer, stufeId);
      warteschlange = gemischt(woerter.slice());
      nachzuegler.length = 0;
      merkzettel.length = 0;
      erledigt = 0;
      richtig = 0;
      aktuell = null;
      vorherigeDauer = 0;
      begonnen = Date.now();
      vonVorn.remove();
      naechstes();
    });
  }

  /** Den Stand sichern — nach jedem Wort und beim Abbrechen. */
  function standSichern() {
    laufMerken({
      bereichId: bereich.id,
      paket: paketNummer,
      stufe: stufeId,
      bereichName: bereich.name,
      bereichEmoji: bereich.emoji || '',
      gesamt,
      warteschlange: (aktuell ? [aktuell, ...warteschlange] : warteschlange).map((e) => e.id),
      nachzuegler: nachzuegler.map((e) => e.id),
      merkzettel,
      dauer: vorherigeDauer + (Date.now() - begonnen),
    });
  }

  function standZeigen() {
    zaehler.textContent = `${Math.min(erledigt + 1, gesamt)} / ${gesamt}`;
    const anteil = erledigt / gesamt;
    const i = fortschrittsbalken.querySelector('i');
    if (i) i.style.width = `${Math.round(anteil * 100)}%`;
  }

  function naechstes() {
    if (!laufend) return;
    let neueRunde = false;
    if (!warteschlange.length && nachzuegler.length) {
      // Die Wörter, die beim ersten Mal danebengingen, kommen noch einmal —
      // aber sie sind schon gewertet.
      warteschlange = nachzuegler.splice(0, nachzuegler.length);
      neueRunde = true;
    }
    if (!warteschlange.length) { beenden(false); return; }

    // Die Notiz vom vorigen Wort ist überholt.
    hinweisWeg();
    const eintrag = warteschlange.shift();
    aktuell = eintrag;
    standZeigen();

    const karte = h('div', { class: 'lauf__karte' });
    const inhalt = uebung.aufbauen({
      eintrag,
      bereich,
      // Das ganze Päckchen: Die Geheimschrift zeigt daraus die Wortliste. Ein
      // Wortbild ohne Auswahl ist ein Gedächtnistest, kein Rechtschreibtest —
      // niemand kann fünfzehn Wörter nach zweimal Üben an ihrer Silhouette
      // erkennen (Ansage des Nutzers, 08/2026).
      paket: woerter,
      aufFertig: (ergebnis) => aufgabeFertig(eintrag, ergebnis, karte),
    });
    karte.appendChild(inhalt);
    leeren(buehne).appendChild(karte);
    if (neueRunde) hinweisSagen('Und jetzt noch einmal die Wörter, die schwer waren.');
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
    aktuell = null;
    standSichern();
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
      // Der Stand bleibt liegen — beim nächsten Öffnen geht es hier weiter.
      standSichern();
      if (aufAbbruch) aufAbbruch();
      else aufEnde({ richtig, gesamt, sterne: 0, abgebrochen: true });
      return;
    }
    // Durchgezogen: Der gemerkte Stand hat seinen Zweck erfüllt und geht weg.
    laufVergessen(bereich.id, paketNummer, stufeId);
    const dauer = vorherigeDauer + (Date.now() - begonnen);
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
  // Nach `naechstes()`, nicht davor: Sonst räumte es die Notiz gleich wieder
  // weg. Sie bleibt bis zum nächsten Wort stehen.
  if (gemerkt) {
    hinweisSagen(`Weiter geht’s — ${erledigt} von ${gesamt} Wörtern hast du schon geschafft.`);
  }

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
