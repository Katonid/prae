// Fehlerdetektive — die Rechtschreibwerkstatt in drei Stufen.
//
//   1  Fehler finden    Jedes Wort ist antippbar. Wie viele Fehler im Text
//                       stecken, erfährt das Kind ERST nach dem endgültigen
//                       Auswerten (Vorgabe des Nutzers, 10/2026). Danach:
//                       gefunden grün, übersehen orange, falsch markiert
//                       rot — aber noch KEINE richtige Schreibweise.
//   2  Verbessern       Einzeln nacheinander selbst richtig schreiben —
//                       von Haus aus nur, was danebenging: übersehene
//                       Fehler und versehentlich markierte richtige Wörter
//                       (`CONFIG.correctionMode`, Ansage des Nutzers 10/2026). Tipp nach dem zweiten, „Lösung
//                       zeigen" nach dem dritten Fehlversuch.
//   3  Strategien       `CONFIG.strategyQuestions` S-Fehler, zufällig
//                       gelost: Welche Strategie hilft?
//   Abschluss           drei getrennte Bereiche, keine Note; erst jetzt die
//                       Lösungsübersicht.
//
// Die Logik ist für ALLE Texte dieselbe; die Texte und `CONFIG` stehen in
// `fehlertexte.js`. Ein Fehler ist an seine POSITION im Text gebunden (die
// laufende Nummer des Wortes), nie an seine Buchstabenfolge: „Weg" kann an
// einer Stelle richtig und an einer anderen („Wek") ein Fehler sein.
//
// Vor dem Auswerten trägt kein Wort-Element die Lösung — keine Klasse, kein
// `data-`, kein `title`, kein `aria-label`; nur seine laufende Nummer.
//
// Grün/rot/orange ist hier die Ausnahme von „kein Grün" der Wörterwerkstatt —
// für genau diese Übung vom Nutzer vorgegeben. Jede Farbe trägt zusätzlich
// eine eigene Linienart (unterstrichen, durchgestrichen, umrandet).
//
// Der Durchgang überlebt ein Neuladen (ab 1.11.2): Nach jedem Schritt geht
// er als einfaches Objekt an `merken`, und `gemerkt` setzt ihn beim Öffnen
// wieder ein — an der Stelle, an der das Kind war. Gemerkt werden nur
// Wortnummern, keine Wörter; passt der Text nicht mehr dazu (`kennung`),
// wird neu angefangen statt halb falsch fortgesetzt.
//
// Nach jedem abgeschlossenen Schritt geht der Stand an `beiErgebnis` — immer
// unter demselben Schlüssel (Beginn), damit die Lehrkraft auch einen nicht
// ganz beendeten Durchgang sieht. Ob und wohin, entscheidet der Aufrufer.

import { h, leeren, gemischt } from './util.js';
import { frage } from './ui.js';
import { CONFIG, FEHLERTEXTE, uebungsnummer } from './fehlertexte.js';

/* ---------- Strategien ---------- */

export const STRATEGIEN = {
  Ableiten: {
    knopf: 'Ableiten',
    erklaerung: (wort) => `„${wort}“ kannst du ableiten: Such ein verwandtes Wort mit a oder au — dann weißt du, dass es ä oder äu geschrieben wird.`,
  },
  'Verlängern': {
    knopf: 'Verlängern',
    erklaerung: (wort) => `Verlängere „${wort}“ (zum Beispiel in die Mehrzahl oder in eine andere Form) — dann hörst du am Ende deutlich, ob b oder p, d oder t, g oder k.`,
  },
  'Silben sprechen': {
    knopf: 'Silben sprechen / Mitsprechen',
    erklaerung: (wort) => `Sprich „${wort}“ langsam in Silben — dann hörst du jeden Laut: das h, das die Silben trennt, oder den doppelten Mitlaut nach einem kurzen Selbstlaut.`,
  },
  Merkwort: {
    knopf: 'Merkwort',
    erklaerung: (wort) => `„${wort}“ ist ein Merkwort. Hier hilft keine Regel — dieses Wort musst du dir einprägen.`,
  },
};

const STRATEGIE_NAMEN = Object.keys(STRATEGIEN);
const SOLL = { N: 20, S: 20 };

/* ---------- Text zerlegen ---------- */

// Markierung | Wort | Leerraum | Satzzeichen
const MUSTER = /\[\[([NS])\|([^|\]]+)\|([^|\]]+)(?:\|([^|\]]+))?\]\]|([\p{L}\p{N}]+(?:-[\p{L}\p{N}]+)*)|(\s+)|([^\s\p{L}\p{N}[]+)/gu;

function absatzZerlegen(absatz, probleme) {
  const teile = [];
  let gelesen = 0;
  MUSTER.lastIndex = 0;
  let m;
  while ((m = MUSTER.exec(absatz)) !== null) {
    if (m.index !== gelesen) probleme.push(`Unlesbare Stelle im Text: „${absatz.slice(gelesen, m.index)}“`);
    gelesen = MUSTER.lastIndex;
    if (m[1]) {
      teile.push({ art: 'wort', text: m[2], richtig: m[3], typ: m[1], strategie: m[4] ? m[4].trim() : null });
    } else if (m[5]) {
      teile.push({ art: 'wort', text: m[5], richtig: m[5], typ: null, strategie: null });
    } else if (m[6]) {
      teile.push({ art: 'leer', text: ' ' });
    } else {
      teile.push({ art: 'zeichen', text: m[7] });
    }
  }
  if (gelesen !== absatz.length) probleme.push(`Unlesbares Textende: „${absatz.slice(gelesen)}“`);

  // Direkt aneinanderstoßende Wortteile sind EIN Wort:
  // [[S|gelp|gelb|Verlängern]]es → „gelpes“, richtig „gelbes“.
  const verbunden = [];
  for (const teil of teile) {
    const vorher = verbunden[verbunden.length - 1];
    if (teil.art === 'wort' && vorher && vorher.art === 'wort') {
      if (vorher.typ && teil.typ) probleme.push(`Zwei Fehler in einem Wort: „${vorher.text}${teil.text}“`);
      vorher.text += teil.text;
      vorher.richtig += teil.richtig;
      vorher.typ = vorher.typ || teil.typ;
      vorher.strategie = vorher.strategie || teil.strategie;
    } else {
      verbunden.push(teil);
    }
  }
  return verbunden;
}

/**
 * Den Satz um jedes Wort herum merken — für Stufe 2 („Im Text stand …").
 * Ein Satz endet an einem Zeichen mit . ! oder ? (auch „!“", „.“").
 */
function saetzeMerken(teile) {
  let start = 0;
  const schliessen = (ende) => {
    const satz = teile.slice(start, ende + 1);
    for (const teil of satz) if (teil.art === 'wort') teil.satz = satz;
    start = ende + 1;
  };
  teile.forEach((teil, i) => {
    if (teil.art === 'zeichen' && /[.!?]/.test(teil.text)) schliessen(i);
  });
  if (start < teile.length) schliessen(teile.length - 1);
}

const zerlegt = new Map();

/**
 * Den Text in Absätze und Wörter zerlegen. Jedes Wort bekommt seine Nummer
 * (`i`) — das ist seine ID. Geprüft wird hier nicht (siehe `uebungPruefen`).
 */
export function textZerlegen(text) {
  if (zerlegt.has(text.id)) return zerlegt.get(text.id);
  const probleme = [];
  const absaetze = String(text.text || '').split(/\n\s*\n/).map((a) => a.trim()).filter(Boolean)
    .map((a) => absatzZerlegen(a, probleme));
  const woerter = [];
  for (const teile of absaetze) {
    saetzeMerken(teile);
    for (const teil of teile) {
      if (teil.art !== 'wort') continue;
      teil.i = woerter.length;
      woerter.push(teil);
    }
  }
  const fehler = woerter.filter((w) => w.typ);
  const ergebnis = { absaetze, woerter, fehler, gesamt: fehler.length, probleme };
  zerlegt.set(text.id, ergebnis);
  return ergebnis;
}

/* ---------- Prüfung beim Laden ---------- */

/**
 * Eine Übung prüfen: 20 × N, 20 × S, 40 insgesamt, jeder Fehler mit falscher
 * und richtiger Form, jeder S-Fehler mit gültiger Strategie. Gibt die
 * Liste der Probleme zurück (leer = in Ordnung).
 */
export function uebungPruefen(text, nummer) {
  const name = `Übung ${nummer}${text.title ? ` („${text.title}“)` : ''}`;
  const { fehler, probleme } = textZerlegen(text);
  const meldungen = probleme.map((p) => `${name}: ${p}`);
  if (!text.id) meldungen.push(`${name} hat keine id.`);
  if (!text.title) meldungen.push(`${name} hat keinen Titel (title).`);
  const zahl = { N: 0, S: 0 };
  for (const f of fehler) {
    zahl[f.typ] += 1;
    if (!f.text || !f.richtig) meldungen.push(`${name}: Ein Fehler hat keine falsche oder keine richtige Form.`);
    if (f.text === f.richtig) meldungen.push(`${name}: „${f.text}“ ist als Fehler markiert, aber falsche und richtige Form sind gleich.`);
    if (f.typ === 'N') {
      const gross = f.text.charAt(0).toUpperCase() + f.text.slice(1);
      if (f.text === gross || gross !== f.richtig) {
        meldungen.push(`${name}: „${f.text}“ → „${f.richtig}“ ist als Nomenfehler (N) markiert, aber kein reiner Kleinschreibfehler.`);
      }
    }
    if (f.typ === 'S') {
      if (!f.strategie) meldungen.push(`${name}: „${f.text}“ (S) hat keine Strategie.`);
      else if (!STRATEGIE_NAMEN.includes(f.strategie)) {
        meldungen.push(`${name}: „${f.text}“ hat keine gültige Strategie („${f.strategie}“). Erlaubt: ${STRATEGIE_NAMEN.join(', ')}.`);
      }
    }
  }
  const nur = (n, soll) => (n < soll ? 'nur ' : '');
  if (zahl.N !== SOLL.N) meldungen.push(`${name} enthält ${nur(zahl.N, SOLL.N)}${zahl.N} Nomenfehler statt ${SOLL.N}.`);
  if (zahl.S !== SOLL.S) meldungen.push(`${name} enthält ${nur(zahl.S, SOLL.S)}${zahl.S} andere Fehler (S) statt ${SOLL.S}.`);
  if (zahl.N + zahl.S !== SOLL.N + SOLL.S) {
    meldungen.push(`${name} enthält ${nur(zahl.N + zahl.S, SOLL.N + SOLL.S)}${zahl.N + zahl.S} Fehler statt ${SOLL.N + SOLL.S}.`);
  }
  return meldungen;
}

/** Alle Übungen prüfen — läuft einmal beim Laden dieses Moduls. */
export function alleUebungenPruefen() {
  const ids = new Set();
  let ok = 0;
  FEHLERTEXTE.forEach((text, stelle) => {
    const meldungen = uebungPruefen(text, stelle + 1);
    if (text.id && ids.has(text.id)) meldungen.push(`Übung ${stelle + 1}: Die id „${text.id}“ gibt es schon.`);
    ids.add(text.id);
    if (meldungen.length) {
      for (const m of meldungen) {
        console.error(`%c FEHLERDETEKTIVE %c ${m}`, 'background:#b91c1c;color:#fff;font-weight:bold;padding:2px 6px;', 'font-weight:bold;');
      }
    } else {
      ok += 1;
    }
  });
  console.info(`Fehlerdetektive: ${ok} von ${FEHLERTEXTE.length} Übungen geprüft und in Ordnung (je 20 × N, 20 × S).`);
  return ok === FEHLERTEXTE.length;
}

alleUebungenPruefen();

/* ---------- Kleine Helfer ---------- */

const anzahlWoerter = (n) => `${n} ${n === 1 ? 'Wort' : 'Wörter'}`;
const sekunden = (von, bis) => Math.max(0, Math.round((bis - von) / 1000));
const gleich = (a, b) => String(a || '').normalize('NFC').trim() === String(b || '').normalize('NFC').trim();

/** Das Eingabefeld, in dem iOS möglichst nichts vorsagt. */
function schreibfeld() {
  return h('input', {
    class: 'feld feld--gross detektiv__eingabe',
    type: 'text',
    // Ein zufälliger Name hält auch das automatische Ausfüllen fern.
    name: `w${Math.random().toString(36).slice(2, 8)}`,
    autocomplete: 'off',
    autocorrect: 'off',
    autocapitalize: 'off',
    spellcheck: 'false',
    enterkeyhint: 'done',
    'data-form-type': 'other',
    'aria-label': 'Schreibe das Wort richtig',
  });
}

/* ---------- Die Übung ---------- */

/**
 * Baut die Übung in `platz` auf.
 *
 * `hinweis`  — ein Knoten über dem Text (ob das Ergebnis gemeldet wird)
 * `zurueck`  — zur Auswahl der Übungen
 * `beiErgebnis(stand)` — nach jedem abgeschlossenen Schritt
 * `gemerkt` / `merken(stand|null)` — der Durchgang auf dem Gerät (Neuladen)
 *
 * Gibt eine Funktion zum Aufräumen zurück.
 */
export function fehlersucheStarten({ platz, text, hinweis = null, zurueck, beiErgebnis, gemerkt = null, merken = null }) {
  const zerlegung = textZerlegen(text);
  const { absaetze, woerter, fehler: alleFehler } = zerlegung;
  const fehlerzahl = alleFehler.length;
  const nummer = uebungsnummer(text);
  // Passt ein gemerkter Durchgang noch zu diesem Text? Wortzahl und die
  // Stellen der Fehler müssen gleich sein.
  const kennung = `${woerter.length}:${alleFehler.map((f) => f.i).join(',')}`;

  let lauf = null; // der aktuelle Durchgang, siehe `neuerLauf`

  /** Den Durchgang aufs Gerät — nach jedem Schritt. */
  function speichern() {
    if (!merken || !lauf) return;
    merken({
      v: 1,
      kennung,
      beginn: lauf.beginn,
      markiert: lauf.markiert.reduce((liste, an, i) => (an ? liste.concat(i) : liste), []),
      auswertung: lauf.auswertung,
      verbessern: lauf.verbessern && {
        stelle: lauf.verbessern.stelle,
        liste: lauf.verbessern.liste.map((e) => ({
          i: e.wort.i, versuche: e.versuche, eingaben: e.eingaben, loesung: e.loesung, fertig: e.fertig,
        })),
      },
      strategien: lauf.strategien && {
        stelle: lauf.strategien.stelle,
        liste: lauf.strategien.liste.map((e) => ({ i: e.wort.i, gewaehlt: e.gewaehlt, fertig: e.fertig })),
      },
      fertig: lauf.fertig,
    });
  }

  /** Einen gemerkten Durchgang einlesen — oder null, wenn er nicht passt. */
  function wiederherstellen(stand) {
    try {
      if (!stand || stand.v !== 1 || stand.kennung !== kennung) return null;
      const wortZu = (i) => {
        const wort = woerter[i];
        if (!wort) throw new Error('Wort fehlt');
        return wort;
      };
      const markiert = woerter.map(() => false);
      for (const i of stand.markiert || []) wortZu(i) && (markiert[i] = true);
      return {
        beginn: Number(stand.beginn) || Date.now(),
        markiert,
        auswertung: stand.auswertung || null,
        verbessern: stand.verbessern ? {
          stelle: Number(stand.verbessern.stelle) || 0,
          liste: stand.verbessern.liste.map((e) => ({
            wort: wortZu(e.i), versuche: e.versuche || 0, eingaben: e.eingaben || [], loesung: !!e.loesung, fertig: !!e.fertig,
          })),
        } : null,
        strategien: stand.strategien ? {
          stelle: Number(stand.strategien.stelle) || 0,
          liste: stand.strategien.liste.map((e) => ({ wort: wortZu(e.i), gewaehlt: e.gewaehlt || [], fertig: !!e.fertig })),
        } : null,
        fertig: stand.fertig || null,
      };
    } catch (_) {
      return null;
    }
  }

  /** Dort weitermachen, wo der gemerkte Durchgang stand. */
  function fortsetzen() {
    if (lauf.fertig) { abschlussZeigen(true); return; }
    if (lauf.strategien) {
      const s = lauf.strategien;
      // Eine schon beantwortete Frage nicht noch einmal stellen
      while (s.stelle < s.liste.length && s.liste[s.stelle].fertig) s.stelle += 1;
      if (s.stelle >= s.liste.length) { abschlussZeigen(); return; }
      stufeZeigen(3);
      strategieZeigen(s.stelle === 0);
      return;
    }
    if (lauf.verbessern) {
      const v = lauf.verbessern;
      while (v.stelle < v.liste.length && v.liste[v.stelle].fertig) v.stelle += 1;
      if (v.stelle >= v.liste.length) { strategienStarten(); return; }
      stufeZeigen(2);
      verbessernZeigen();
      return;
    }
    findenZeigen();
  }

  const fortschritt = h('ol', { class: 'detektiv__stufen', 'aria-label': 'Stufen' },
    ...['Fehler finden', 'Verbessern', 'Strategien'].map((name, i) => h('li', { class: 'detektiv__stufe' },
      h('span', { class: 'detektiv__stufennummer' }, String(i + 1)), name)));
  const buehne = h('div', { class: 'detektiv__buehne' });
  const seite = h('div', { class: 'seite detektiv' },
    h('div', { class: 'detektiv__oben' },
      h('button', { class: 'zurueck', type: 'button', onclick: () => verlassen() }, '‹ Zur Auswahl'),
      fortschritt),
    buehne);

  function stufeZeigen(n) {
    fortschritt.querySelectorAll('.detektiv__stufe').forEach((li, i) => {
      li.classList.toggle('is-aktiv', i + 1 === n);
      li.classList.toggle('is-fertig', i + 1 < n || n === 4);
      if (i + 1 === n) li.setAttribute('aria-current', 'step'); else li.removeAttribute('aria-current');
    });
  }

  function melden() {
    speichern();
    if (!beiErgebnis || !lauf.auswertung) return;
    const a = lauf.auswertung;
    const stand = {
      text: text.id,
      titel: text.title,
      beginn: lauf.beginn,
      ende: a.ende,
      dauer: sekunden(lauf.beginn, a.ende),
      fehler: fehlerzahl,
      gefunden: a.gefunden,
      gefundenN: a.gefundenN,
      gefundenS: a.gefundenS,
      uebersehen: a.uebersehen,
      falsch: a.falsch,
      // Was übersehen wurde, ist die eigentliche Auskunft für die Lehrkraft.
      // Falsch markierte richtige Wörter werden gedeckelt: Wer alles antippt,
      // schickt sonst 300 Wörter mit.
      ue: a.ueListe,
      fa: a.faListe.slice(0, 40),
    };
    if (lauf.verbessern) {
      const v = lauf.verbessern;
      const erledigt = v.liste.filter((e) => e.fertig);
      stand.verb = {
        n: v.liste.length,
        fertig: erledigt.length,
        erster: erledigt.filter((e) => !e.loesung && e.versuche === 1).length,
        selbst: erledigt.filter((e) => !e.loesung && e.versuche <= 2).length,
        hinweis: erledigt.filter((e) => !e.loesung && e.versuche >= 3).length,
        loesung: erledigt.filter((e) => e.loesung).length,
        liste: erledigt.map((e) => ({
          w: e.wort.text, r: e.wort.richtig, t: e.wort.typ, v: e.versuche, l: e.loesung, e: e.eingaben.slice(0, 4),
        })),
      };
    }
    if (lauf.strategien) {
      const s = lauf.strategien;
      const erledigt = s.liste.filter((e) => e.fertig);
      stand.strat = {
        n: s.liste.length,
        fertig: erledigt.length,
        richtig: erledigt.filter((e) => e.gewaehlt[0] === e.wort.strategie).length,
        zweiter: erledigt.filter((e) => e.gewaehlt[0] !== e.wort.strategie && e.gewaehlt[1] === e.wort.strategie).length,
        liste: erledigt.map((e) => ({ w: e.wort.text, r: e.wort.richtig, s: e.wort.strategie, g: e.gewaehlt.slice(0, 2) })),
      };
    }
    if (lauf.fertig) {
      stand.abgeschlossen = true;
      stand.gesamtDauer = sekunden(lauf.beginn, lauf.fertig);
    }
    beiErgebnis(stand);
  }

  function verlassen() {
    // Seit 1.11.2 bleibt der Durchgang auf dem Gerät — Verlassen kostet
    // nichts mehr, eine Rückfrage wäre nur noch im Weg.
    zurueck();
  }

  function neuerLauf() {
    lauf = {
      beginn: Date.now(),
      markiert: woerter.map(() => false),
      auswertung: null,
      verbessern: null,
      strategien: null,
      fertig: null,
    };
    speichern();
    findenZeigen();
  }

  /* ---------- Stufe 1: Fehler finden ---------- */

  function findenZeigen() {
    stufeZeigen(1);
    const spans = [];
    const zaehler = h('strong', {}, anzahlWoerter(0));
    const ergebnisplatz = h('section', { class: 'detektiv__ergebnis', hidden: true, tabindex: '-1', 'aria-live': 'polite' });
    const textplatz = h('div', { class: 'detektiv__text' });
    const knopfFertig = h('button', { class: 'knopf knopf--voll detektiv__knopf', type: 'button' }, 'Ich bin fertig – auswerten');
    const knopfWeiter = h('button', { class: 'knopf knopf--voll detektiv__knopf', type: 'button', hidden: true }, 'Weiter: Fehler verbessern');

    for (const teile of absaetze) {
      const p = h('p', {});
      for (const teil of teile) {
        if (teil.art !== 'wort') { p.appendChild(document.createTextNode(teil.text)); continue; }
        const span = h('span', { class: 'detektiv__wort', role: 'button', tabindex: '0', 'aria-pressed': 'false', 'data-i': String(teil.i) }, teil.text);
        spans.push(span);
        p.appendChild(span);
      }
      textplatz.appendChild(p);
    }

    const zaehlerZeigen = () => { zaehler.textContent = anzahlWoerter(lauf.markiert.filter(Boolean).length); };

    function umschalten(i) {
      if (lauf.auswertung) return; // Nach dem Auswerten ist die Auswahl fest.
      lauf.markiert[i] = !lauf.markiert[i];
      spans[i].classList.toggle('is-markiert', lauf.markiert[i]);
      spans[i].setAttribute('aria-pressed', lauf.markiert[i] ? 'true' : 'false');
      zaehlerZeigen();
      speichern();
    }
    textplatz.addEventListener('click', (ereignis) => {
      const span = ereignis.target.closest('.detektiv__wort');
      if (span) umschalten(Number(span.dataset.i));
    });
    textplatz.addEventListener('keydown', (ereignis) => {
      if (ereignis.key !== 'Enter' && ereignis.key !== ' ') return;
      const span = ereignis.target.closest('.detektiv__wort');
      if (!span) return;
      ereignis.preventDefault();
      umschalten(Number(span.dataset.i));
    });

    knopfFertig.addEventListener('click', async () => {
      if (CONFIG.confirmBeforeEvaluation !== false) {
        const ja = await frage({
          titel: 'Bist du sicher?',
          text: 'Danach kannst du deine Auswahl nicht mehr verändern.',
          ja: 'Jetzt auswerten',
          nein: 'Weiter suchen',
        });
        if (!ja) return;
      }
      auswerten();
    });
    knopfWeiter.addEventListener('click', () => verbessernStarten());

    function auswerten(wiederhergestellt = false) {
      const a = { ende: wiederhergestellt && lauf.auswertung ? lauf.auswertung.ende : Date.now(), gefunden: 0, gefundenN: 0, gefundenS: 0, uebersehen: 0, falsch: 0, ueListe: [], faListe: [] };
      woerter.forEach((wort, i) => {
        const span = spans[i];
        span.classList.remove('is-markiert');
        span.removeAttribute('aria-pressed');
        let art = null;
        if (wort.typ && lauf.markiert[i]) {
          art = 'gefunden'; a.gefunden += 1; a[`gefunden${wort.typ}`] += 1;
        } else if (wort.typ) {
          art = 'uebersehen'; a.uebersehen += 1;
          a.ueListe.push({ w: wort.text, r: wort.richtig, t: wort.typ });
        } else if (lauf.markiert[i]) {
          art = 'falsch'; a.falsch += 1; a.faListe.push(wort.text);
        }
        if (art) {
          // Nur WAS es war — die richtige Schreibweise kommt erst in Stufe 2.
          span.classList.add(`is-${art}`);
          span.setAttribute('aria-label', `${wort.text} – ${{ gefunden: 'Fehler gefunden', uebersehen: 'Fehler übersehen', falsch: 'war richtig geschrieben' }[art]}`);
        } else {
          span.removeAttribute('role');
          span.setAttribute('tabindex', '-1');
        }
      });
      lauf.auswertung = a;
      seite.classList.add('is-ausgewertet');

      leeren(ergebnisplatz);
      ergebnisplatz.append(
        h('p', { class: 'detektiv__haupt' }, `Du hast ${a.gefunden} von ${fehlerzahl} Fehlern gefunden.`),
        h('p', {}, a.uebersehen === 1 ? '1 Fehler hast du übersehen.' : `${a.uebersehen} Fehler hast du übersehen.`),
        h('p', {}, a.falsch === 1
          ? '1 richtiges Wort hast du versehentlich markiert.'
          : `${a.falsch} richtige Wörter hast du versehentlich markiert.`),
        h('ul', { class: 'detektiv__legende' },
          ...[['gefunden', 'gefunden'], ['uebersehen', 'übersehen'], ['falsch', 'war richtig']].map(([art, wort]) => h('li', {},
            h('span', { class: `detektiv__probe is-${art}`, 'aria-hidden': 'true' }), wort))),
        h('p', { class: 'detektiv__tipp' }, 'Wie man die Wörter richtig schreibt, findest du jetzt selbst heraus.'),
        h('button', { class: 'knopf knopf--voll detektiv__knopf', type: 'button', onclick: () => verbessernStarten() }, 'Weiter: Fehler verbessern'));
      ergebnisplatz.hidden = false;
      knopfFertig.hidden = true;
      knopfWeiter.hidden = false;
      ergebnisplatz.scrollIntoView({ block: 'start' });
      ergebnisplatz.focus({ preventScroll: true });
      if (!wiederhergestellt) melden();
    }

    leeren(buehne).append(
      h('div', { class: 'seite__kopf' },
        h('h1', { class: 'seite__titel' }, 'Fehlerdetektive aufgepasst! 🔍'),
        h('p', { class: 'detektiv__auftrag' }, 'Im Text haben sich viele Rechtschreibfehler versteckt.'),
        h('p', { class: 'detektiv__auftrag' }, 'Tippe auf jedes Wort, das deiner Meinung nach falsch geschrieben ist.'),
        h('p', { class: 'detektiv__auftrag detektiv__auftrag--leise' },
          h('strong', {}, 'Aber Vorsicht:'), ' Viele schwierige Wörter sind vollkommen richtig geschrieben!'),
        hinweis,
        ergebnisplatz),
      h('p', { class: 'detektiv__zaehler', 'aria-live': 'polite' }, 'Markiert: ', zaehler),
      h('div', { class: 'detektiv__karte' },
        h('h2', { class: 'detektiv__titel' }, `Übung ${nummer}: ${text.title}`),
        textplatz),
      h('div', { class: 'detektiv__knoepfe' }, knopfFertig, knopfWeiter));
    seite.classList.remove('is-ausgewertet');
    window.scrollTo(0, 0);

    // Ein gemerkter Durchgang: Markierungen wieder setzen, und war schon
    // ausgewertet, die Auswertung wieder zeigen (ohne erneut zu melden).
    lauf.markiert.forEach((an, i) => {
      if (!an) return;
      spans[i].classList.add('is-markiert');
      spans[i].setAttribute('aria-pressed', 'true');
    });
    zaehlerZeigen();
    if (lauf.auswertung) auswerten(true);
  }

  /* ---------- Stufe 2: Verbessern ---------- */

  function verbessernStarten() {
    // Was in Stufe 2 drankommt (CONFIG.correctionMode, in Textreihenfolge):
    //   'mistakes' (Vorgabe) — was danebenging: übersehene Fehler (orange)
    //                          UND versehentlich markierte richtige Wörter (rot)
    //   'all'                — alle Fehler des Textes
    //   'found'              — nur die gefundenen Fehler
    const modus = CONFIG.correctionMode || 'mistakes';
    const welche = modus === 'all'
      ? alleFehler
      : (modus === 'found'
        ? alleFehler.filter((f) => lauf.markiert[f.i])
        : woerter.filter((w) => (w.typ ? !lauf.markiert[w.i] : lauf.markiert[w.i])));
    lauf.verbessern = {
      liste: welche.map((wort) => ({ wort, versuche: 0, eingaben: [], loesung: false, fertig: false })),
      stelle: 0,
    };
    speichern();
    if (!welche.length) { strategienStarten(); return; }
    seite.classList.remove('is-ausgewertet');
    stufeZeigen(2);
    verbessernZeigen();
  }

  function satzZeigen(wort) {
    const satz = wort.satz || [wort];
    const p = h('p', { class: 'detektiv__satz' });
    let begonnen = false;
    for (const teil of satz) {
      if (!begonnen && teil.art === 'leer') continue;
      begonnen = true;
      if (teil.art === 'wort' && teil.i === wort.i) p.appendChild(h('mark', { class: `detektiv__satzwort${wort.typ ? '' : ' is-warrichtig'}` }, teil.text));
      else p.appendChild(document.createTextNode(teil.text));
    }
    return p;
  }

  function verbessernZeigen() {
    const v = lauf.verbessern;
    const eintrag = v.liste[v.stelle];
    const wort = eintrag.wort;
    const feld = schreibfeld();
    const rueckmeldung = h('p', { class: 'detektiv__rueckmeldung', 'aria-live': 'polite' });
    // Ein versehentlich markiertes Wort war richtig — das Kind schreibt es so,
    // wie es im Text stand, und merkt sich dabei, dass es stimmte.
    const warRichtig = !wort.typ;
    const tipp = h('p', { class: 'detektiv__hilfe', hidden: true },
      warRichtig
        ? 'Tipp: Dieses Wort war schon richtig geschrieben. Schreibe es genau so, wie es im Text stand.'
        : (wort.typ === 'N'
          ? 'Tipp: Überlege, ob dieses Wort großgeschrieben werden muss.'
          : 'Tipp: Eine Rechtschreibstrategie kann dir helfen.'));
    const pruefen = h('button', { class: 'knopf knopf--voll detektiv__knopf', type: 'button' }, 'Prüfen');
    const loesungKnopf = h('button', { class: 'knopf knopf--still', type: 'button', hidden: true }, 'Lösung zeigen');
    const weiter = h('button', { class: 'knopf knopf--voll detektiv__knopf', type: 'button', hidden: true },
      v.stelle + 1 < v.liste.length ? 'Weiter' : 'Weiter: Strategien');
    const karte = h('section', { class: 'detektiv__aufgabe' },
      h('p', { class: 'detektiv__aufgabenzahl' }, `Wort ${v.stelle + 1} von ${v.liste.length}`),
      h('div', { class: 'detektiv__balken', 'aria-hidden': 'true' },
        h('span', { style: { width: `${(v.stelle / v.liste.length) * 100}%` } })),
      satzZeigen(wort),
      h('p', { class: 'detektiv__marke' }, 'Im Text stand:'),
      h('p', { class: 'detektiv__falschwort' }, wort.text),
      warRichtig ? h('p', { class: 'detektiv__warrichtig' },
        'Dieses Wort hattest du markiert. Ist es wirklich falsch geschrieben?') : null,
      h('label', { class: 'detektiv__marke' }, 'Schreibe das Wort richtig:'),
      h('div', { class: 'detektiv__eingabezeile' }, feld, pruefen),
      rueckmeldung,
      tipp,
      h('div', { class: 'detektiv__knoepfe detektiv__knoepfe--links' }, loesungKnopf, weiter));

    function abschliessen() {
      eintrag.fertig = true;
      feld.disabled = true;
      pruefen.hidden = true;
      loesungKnopf.hidden = true;
      weiter.hidden = false;
      weiter.focus({ preventScroll: true });
      melden();
    }

    function pruefenJetzt() {
      if (eintrag.fertig) return;
      const eingabe = feld.value;
      if (!eingabe.trim()) { feld.focus(); return; }
      eintrag.versuche += 1;
      speichern();
      if (gleich(eingabe, wort.richtig)) {
        rueckmeldung.className = 'detektiv__rueckmeldung is-richtig';
        rueckmeldung.textContent = 'Richtig! ✓';
        tipp.hidden = true;
        abschliessen();
        return;
      }
      eintrag.eingaben.push(eingabe.trim());
      rueckmeldung.className = 'detektiv__rueckmeldung is-falsch';
      rueckmeldung.textContent = 'Noch nicht richtig. Schau dir das Wort noch einmal genau an.';
      if (eintrag.versuche >= 2) tipp.hidden = false;
      if (eintrag.versuche >= 3) loesungKnopf.hidden = false;
      feld.select();
      feld.focus();
    }

    pruefen.addEventListener('click', pruefenJetzt);
    feld.addEventListener('keydown', (ereignis) => {
      if (ereignis.key === 'Enter') { ereignis.preventDefault(); pruefenJetzt(); }
    });
    loesungKnopf.addEventListener('click', () => {
      eintrag.loesung = true;
      rueckmeldung.className = 'detektiv__rueckmeldung is-loesung';
      rueckmeldung.textContent = '';
      rueckmeldung.append('Richtig geschrieben: ', h('strong', { class: 'detektiv__loesungswort' }, wort.richtig));
      tipp.hidden = true;
      abschliessen();
    });
    weiter.addEventListener('click', () => {
      if (v.stelle + 1 < v.liste.length) {
        v.stelle += 1;
        speichern();
        verbessernZeigen();
      } else {
        strategienStarten();
      }
    });

    leeren(buehne).append(
      h('div', { class: 'seite__kopf' },
        h('h1', { class: 'seite__titel' }, 'Fehler verbessern ✏️'),
        h('p', { class: 'detektiv__auftrag' }, 'Schreibe jedes Wort so, wie es richtig heißt. Achte auch auf groß und klein.')),
      karte);
    // Im Klick des Kindes fokussieren — nur dann öffnet Safari die Tastatur.
    // Die Karte rutscht nach oben, damit die Tastatur nichts verdeckt.
    feld.focus({ preventScroll: true });
    requestAnimationFrame(() => karte.scrollIntoView({ block: 'start' }));

    // Nach dem Neuladen: Was bei diesem Wort schon war, gilt weiter.
    if (eintrag.versuche >= 2) tipp.hidden = false;
    if (eintrag.versuche >= 3) loesungKnopf.hidden = false;
  }

  /* ---------- Stufe 3: Strategien ---------- */

  function strategienStarten() {
    const sFehler = alleFehler.filter((f) => f.typ === 'S' && STRATEGIEN[f.strategie]);
    const zahl = Math.max(0, Math.min(Number(CONFIG.strategyQuestions) || 0, sFehler.length));
    // Bei jedem Durchgang neu gemischt
    lauf.strategien = {
      liste: gemischt(sFehler).slice(0, zahl).map((wort) => ({ wort, gewaehlt: [], fertig: false })),
      stelle: 0,
    };
    speichern();
    if (!zahl) { abschlussZeigen(); return; }
    stufeZeigen(3);
    strategieZeigen(true);
  }

  function strategieZeigen(erste) {
    const s = lauf.strategien;
    const eintrag = s.liste[s.stelle];
    const wort = eintrag.wort;
    const rueckmeldung = h('p', { class: 'detektiv__rueckmeldung', 'aria-live': 'polite' });
    const weiter = h('button', { class: 'knopf knopf--voll detektiv__knopf', type: 'button', hidden: true },
      s.stelle + 1 < s.liste.length ? 'Weiter' : 'Zum Abschluss');
    const knoepfe = STRATEGIE_NAMEN.map((name) => h('button', {
      class: 'detektiv__strategie', type: 'button', 'data-strategie': name,
    }, STRATEGIEN[name].knopf));
    const raster = h('div', { class: 'detektiv__strategien' }, ...knoepfe);

    function beenden(text, art) {
      eintrag.fertig = true;
      rueckmeldung.className = `detektiv__rueckmeldung is-${art}`;
      rueckmeldung.textContent = text;
      for (const k of knoepfe) {
        k.disabled = true;
        if (k.dataset.strategie === wort.strategie) k.classList.add('is-richtig');
      }
      weiter.hidden = false;
      weiter.focus({ preventScroll: true });
      melden();
    }

    raster.addEventListener('click', (ereignis) => {
      const knopf = ereignis.target.closest('.detektiv__strategie');
      if (!knopf || knopf.disabled || eintrag.fertig) return;
      const name = knopf.dataset.strategie;
      eintrag.gewaehlt.push(name);
      if (name === wort.strategie) {
        knopf.classList.add('is-richtig');
        beenden(`Richtig! ${STRATEGIEN[name].erklaerung(wort.richtig)}`, 'richtig');
        return;
      }
      knopf.classList.add('is-daneben');
      knopf.disabled = true;
      speichern();
      if (eintrag.gewaehlt.length === 1) {
        rueckmeldung.className = 'detektiv__rueckmeldung is-falsch';
        rueckmeldung.textContent = 'Noch nicht. Versuche es noch einmal.';
        return;
      }
      beenden(`Hier hilft „${STRATEGIEN[wort.strategie].knopf}“. ${STRATEGIEN[wort.strategie].erklaerung(wort.richtig)}`, 'loesung');
    });
    weiter.addEventListener('click', () => {
      if (s.stelle + 1 < s.liste.length) { s.stelle += 1; speichern(); strategieZeigen(false); } else abschlussZeigen();
    });

    leeren(buehne).append(
      h('div', { class: 'seite__kopf' },
        h('h1', { class: 'seite__titel' }, 'Jetzt wirst du Rechtschreibprofi! 🧠'),
        erste ? h('p', { class: 'detektiv__auftrag' },
          'Für jeden Fehler gibt es eine Strategie, mit der du ihn vermeiden kannst. Welche passt?') : null),
      h('section', { class: 'detektiv__aufgabe' },
        h('p', { class: 'detektiv__aufgabenzahl' }, `Aufgabe ${s.stelle + 1} von ${s.liste.length}`),
        h('div', { class: 'detektiv__balken', 'aria-hidden': 'true' },
          h('span', { style: { width: `${(s.stelle / s.liste.length) * 100}%` } })),
        h('p', { class: 'detektiv__paar' },
          h('span', { class: 'detektiv__paar-falsch' }, wort.text), ' → ',
          h('span', { class: 'detektiv__paar-richtig' }, wort.richtig)),
        h('p', { class: 'detektiv__frage' }, 'Welche Strategie hilft dir besonders?'),
        raster,
        rueckmeldung,
        h('div', { class: 'detektiv__knoepfe detektiv__knoepfe--links' }, weiter)));
    window.scrollTo(0, 0);

    // Nach dem Neuladen: ein schon versuchter Fehlgriff bleibt rot
    for (const name of eintrag.gewaehlt) {
      const knopf = knoepfe.find((k) => k.dataset.strategie === name);
      if (knopf) { knopf.classList.add('is-daneben'); knopf.disabled = true; }
    }
    if (eintrag.gewaehlt.length === 1) {
      rueckmeldung.className = 'detektiv__rueckmeldung is-falsch';
      rueckmeldung.textContent = 'Noch nicht. Versuche es noch einmal.';
    }
  }

  /* ---------- Abschluss ---------- */

  function abschlussZeigen(wiederhergestellt = false) {
    stufeZeigen(4);
    if (!wiederhergestellt) {
      lauf.fertig = Date.now();
      melden();
    }
    const a = lauf.auswertung;
    const v = lauf.verbessern ? lauf.verbessern.liste : [];
    const selbst = v.filter((e) => !e.loesung && e.versuche <= 2).length;
    const hinweisZahl = v.filter((e) => !e.loesung && e.versuche >= 3).length;
    const loesungen = v.filter((e) => e.loesung).length;
    const s = lauf.strategien ? lauf.strategien.liste : [];
    const strategieRichtig = s.filter((e) => e.gewaehlt[0] === e.wort.strategie).length;

    const block = (titel, ...zeilen) => h('section', { class: 'detektiv__bereich' },
      h('h2', { class: 'detektiv__bereichstitel' }, titel),
      ...zeilen.filter(Boolean).map((z) => h('p', {}, z)));

    const uebersicht = h('div', { class: 'detektiv__loesungen', hidden: true });
    const knopfLoesungen = h('button', { class: 'knopf knopf--still detektiv__knopf', type: 'button' }, 'Lösungen ansehen');
    knopfLoesungen.addEventListener('click', () => {
      if (!uebersicht.childNodes.length) {
        uebersicht.append(
          h('h2', { class: 'detektiv__bereichstitel' }, `Alle ${fehlerzahl} Fehler im Text`),
          h('ol', { class: 'detektiv__loesungsliste' },
            ...alleFehler.map((f) => h('li', {},
              h('span', { class: 'detektiv__paar-falsch' }, f.text), ' → ',
              h('strong', {}, f.richtig),
              f.typ === 'S' && STRATEGIEN[f.strategie]
                ? h('span', { class: 'detektiv__loesungsstrategie' }, ` – ${STRATEGIEN[f.strategie].knopf}`)
                : h('span', { class: 'detektiv__loesungsstrategie' }, ' – Nomen schreibt man groß')))));
      }
      uebersicht.hidden = !uebersicht.hidden;
      knopfLoesungen.textContent = uebersicht.hidden ? 'Lösungen ansehen' : 'Lösungen ausblenden';
      if (!uebersicht.hidden) uebersicht.scrollIntoView({ block: 'start' });
    });

    leeren(buehne).append(
      h('div', { class: 'seite__kopf' },
        h('h1', { class: 'seite__titel' }, 'Geschafft! 🎉'),
        h('p', { class: 'detektiv__auftrag' }, `Übung ${nummer}: ${text.title}`)),
      h('div', { class: 'detektiv__bereiche' },
        block('🔍 Fehlerdetektiv',
          `${a.gefunden} von ${fehlerzahl} Fehlern gefunden`,
          a.falsch === 1 ? '1 richtiges Wort versehentlich markiert' : `${a.falsch} richtige Wörter versehentlich markiert`),
        v.length ? block('✏️ Verbesserungsprofi',
          `${anzahlWoerter(selbst)} selbstständig verbessert`,
          `${anzahlWoerter(hinweisZahl)} nach einem Hinweis verbessert`,
          loesungen === 1 ? '1 Lösung benötigt' : `${loesungen} Lösungen benötigt`) : null,
        s.length ? block('🧠 Strategieprofi',
          `${strategieRichtig} von ${s.length} Strategien richtig erkannt`) : null),
      h('div', { class: 'detektiv__knoepfe detektiv__knoepfe--reihe' },
        knopfLoesungen,
        h('button', { class: 'knopf knopf--voll detektiv__knopf', type: 'button', onclick: () => neuerLauf() }, 'Text noch einmal bearbeiten'),
        h('button', { class: 'knopf knopf--still detektiv__knopf', type: 'button', onclick: () => zurueck() }, 'Andere Übung auswählen')),
      uebersicht);
    window.scrollTo(0, 0);
  }

  leeren(platz).appendChild(seite);
  const gefunden = wiederherstellen(gemerkt);
  if (gefunden) {
    lauf = gefunden;
    fortsetzen();
  } else {
    neuerLauf();
  }

  return () => {};
}
