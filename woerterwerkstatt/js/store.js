// Alles, was das Gerät sich merkt: Einstellungen, eigene Bereiche, Fortschritt
// und die Anmeldung. Gespeichert wird in IndexedDB, mit localStorage als
// Rückfall — auf einem iPad im Privatmodus ist IndexedDB manchmal gesperrt,
// und dann soll die App trotzdem laufen (nur eben ohne Gedächtnis über die
// Sitzung hinaus).

import { entprellt } from './util.js';

const DB_NAME = 'woerterwerkstatt';
const DB_VERSION = 1;
const SPEICHER = 'kv';
const SCHLUESSEL = 'zustand';
const LS_KEY = 'woerterwerkstatt.zustand.v1';

export const SCHRIFTEN = [
  { id: 'andika', label: 'Andika', stack: "'Andika', 'Lexend', sans-serif", hinweis: 'Für Leseanfänger gemacht: einstöckiges a und g, klar getrennte l, I und 1.' },
  { id: 'lexend', label: 'Lexend', stack: "'Lexend', 'Andika', sans-serif", hinweis: 'Weit gelaufen und ruhig — hilft beim flüssigen Lesen.' },
  { id: 'quicksand', label: 'Quicksand', stack: "'Quicksand', 'Andika', sans-serif", hinweis: 'Rund und freundlich; gut für Überschriften.' },
];

/**
 * Die Farbschemata — alle aus Blau, Orange und Gelb (Ansage des Nutzers,
 * 08/2026: kein Grün, kein Lila).
 *
 * Je Schema drei Dinge, und die drei sind mit Absicht getrennt:
 *
 * `von/mitte/bis`  die drei Farbwolken im Hintergrund. Hier dürfen Blau und
 *                  Orange nebeneinanderstehen — sie liegen weit auseinander
 *                  und mischen sich nur weich am Rand.
 * `verlauf`        der Verlauf der gefüllten Knöpfe. Der wird NICHT aus
 *                  von/mitte/bis gerechnet: Ein Verlauf von Blau nach Orange
 *                  läuft auf halbem Weg durch ein schmutziges Grau, weil die
 *                  beiden auf dem Farbkreis gegenüberliegen. Deshalb bleibt
 *                  jeder Knopfverlauf in EINER Farbfamilie.
 * `warm`           der zweite, warme Verlauf: Fortschrittsbalken, der Auftrag
 *                  der Woche, alles, was Belohnung ist.
 */
export const SCHEMATA = [
  {
    id: 'sonnemeer',
    label: 'Sonne & Meer',
    von: '#2563eb', mitte: '#f97316', bis: '#facc15', schein: '37, 99, 235',
    verlauf: 'linear-gradient(135deg, #1d4ed8 0%, #2563eb 45%, #38bdf8 100%)',
    warm: 'linear-gradient(135deg, #f97316 0%, #fbbf24 55%, #facc15 100%)',
  },
  {
    id: 'meer',
    label: 'Meer',
    von: '#1d4ed8', mitte: '#0ea5e9', bis: '#7dd3fc', schein: '29, 78, 216',
    verlauf: 'linear-gradient(135deg, #1e40af 0%, #0284c7 50%, #38bdf8 100%)',
    warm: 'linear-gradient(135deg, #0284c7 0%, #38bdf8 55%, #7dd3fc 100%)',
  },
  {
    id: 'sonne',
    label: 'Sonne',
    von: '#ea580c', mitte: '#f59e0b', bis: '#facc15', schein: '234, 88, 12',
    verlauf: 'linear-gradient(135deg, #ea580c 0%, #f59e0b 55%, #facc15 100%)',
    warm: 'linear-gradient(135deg, #f97316 0%, #fbbf24 55%, #fde68a 100%)',
  },
  {
    id: 'abend',
    label: 'Abend',
    von: '#1e3a8a', mitte: '#c2410c', bis: '#f59e0b', schein: '30, 58, 138',
    verlauf: 'linear-gradient(135deg, #1e3a8a 0%, #1d4ed8 55%, #3b82f6 100%)',
    warm: 'linear-gradient(135deg, #c2410c 0%, #ea580c 55%, #f59e0b 100%)',
  },
  {
    id: 'sand',
    label: 'Sand',
    von: '#92400e', mitte: '#f59e0b', bis: '#fde68a', schein: '146, 64, 14',
    verlauf: 'linear-gradient(135deg, #b45309 0%, #d97706 55%, #f59e0b 100%)',
    warm: 'linear-gradient(135deg, #d97706 0%, #fbbf24 55%, #fde68a 100%)',
  },
];

export const ABSCHREIB_ARTEN = [
  { id: 'sichtbar', label: 'Wort bleibt stehen', hinweis: 'Zum Anfangen: Das Wort steht die ganze Zeit da.' },
  { id: 'blitz', label: 'Wort verschwindet nach 3 Sekunden', hinweis: 'Erst schauen, merken — dann schreiben.' },
  { id: 'verdeckt', label: 'Wort selbst aufdecken', hinweis: 'Das Kind darf so oft spicken, wie es mag — jedes Aufdecken wird gezählt.' },
];

function leererZustand() {
  return {
    version: 1,
    einstellungen: {
      klang: true,
      schrift: 'andika',
      schema: 'sonnemeer',
      abschreiben: 'sichtbar',
      geheimschrift: 'haus',
      hilfslinien: true,
      grossbuchstaben: false,
      diktatTempo: 0.85,
    },
    eigeneBereiche: [],
    // Welche mitgelieferten Bereiche sichtbar sind: { id: true|false }. Was
    // hier NICHT steht, richtet sich nach der Vorgabe der Gruppe — die
    // Themenbereiche sind an, die Rechtschreibblöcke aus. So bleibt der
    // Eintrag klein, und ein neuer Bereich taucht nicht ungefragt auf.
    sichtbareBereiche: {},
    fortschritt: {},
    protokoll: {},
    nutzer: null,
    klassen: [],
    zuletztBereich: '',
  };
}

let zustand = leererZustand();
let dbPromise = null;
const horcher = new Map();

function db() {
  if (dbPromise) return dbPromise;
  dbPromise = new Promise((fertig, fehler) => {
    if (!window.indexedDB) { fehler(new Error('IndexedDB fehlt')); return; }
    const anfrage = window.indexedDB.open(DB_NAME, DB_VERSION);
    anfrage.onupgradeneeded = () => {
      const datenbank = anfrage.result;
      if (!datenbank.objectStoreNames.contains(SPEICHER)) datenbank.createObjectStore(SPEICHER);
    };
    anfrage.onsuccess = () => fertig(anfrage.result);
    anfrage.onerror = () => fehler(anfrage.error || new Error('IndexedDB'));
  }).catch((error) => { dbPromise = null; throw error; });
  return dbPromise;
}

async function ausDb() {
  const datenbank = await db();
  return new Promise((fertig, fehler) => {
    const t = datenbank.transaction(SPEICHER, 'readonly');
    const anfrage = t.objectStore(SPEICHER).get(SCHLUESSEL);
    anfrage.onsuccess = () => fertig(anfrage.result || null);
    anfrage.onerror = () => fehler(anfrage.error);
  });
}

async function inDb(wert) {
  const datenbank = await db();
  return new Promise((fertig, fehler) => {
    const t = datenbank.transaction(SPEICHER, 'readwrite');
    t.objectStore(SPEICHER).put(wert, SCHLUESSEL);
    t.oncomplete = () => fertig(true);
    t.onerror = () => fehler(t.error);
  });
}

function ausLokal() {
  try {
    const roh = window.localStorage.getItem(LS_KEY);
    return roh ? JSON.parse(roh) : null;
  } catch (_) { return null; }
}

function inLokal(wert) {
  try { window.localStorage.setItem(LS_KEY, JSON.stringify(wert)); } catch (_) { /* voll oder gesperrt */ }
}

/**
 * Zusammenführen statt ersetzen: Kommt eine Fassung mit neuen Einstellungen
 * dazu, sollen die alten Werte des Kindes stehen bleiben und nur die neuen
 * Schalter dazukommen.
 */
function zusammen(gelesen) {
  const frisch = leererZustand();
  if (!gelesen || typeof gelesen !== 'object') return frisch;
  return {
    version: 1,
    einstellungen: Object.assign(frisch.einstellungen, gelesen.einstellungen || {}),
    eigeneBereiche: Array.isArray(gelesen.eigeneBereiche) ? gelesen.eigeneBereiche : [],
    sichtbareBereiche: (gelesen.sichtbareBereiche && typeof gelesen.sichtbareBereiche === 'object') ? gelesen.sichtbareBereiche : {},
    fortschritt: (gelesen.fortschritt && typeof gelesen.fortschritt === 'object') ? gelesen.fortschritt : {},
    protokoll: (gelesen.protokoll && typeof gelesen.protokoll === 'object') ? gelesen.protokoll : {},
    nutzer: gelesen.nutzer || null,
    klassen: Array.isArray(gelesen.klassen) ? gelesen.klassen : [],
    zuletztBereich: gelesen.zuletztBereich || '',
  };
}

export async function ladeZustand() {
  let gelesen = null;
  try { gelesen = await ausDb(); } catch (_) { gelesen = null; }
  if (!gelesen) gelesen = ausLokal();
  zustand = zusammen(gelesen);
  return zustand;
}

const sichereGleich = entprellt(() => {
  const kopie = JSON.parse(JSON.stringify(zustand));
  inDb(kopie).catch(() => {});
  inLokal(kopie);
}, 400);

export function sichere() {
  sichereGleich();
}

export function daten() {
  return zustand;
}

export function einstellungen() {
  return zustand.einstellungen;
}

export function setzeEinstellung(name, wert) {
  zustand.einstellungen[name] = wert;
  sichere();
  melde('einstellungen', zustand.einstellungen);
}

/* ---------- Horcher ---------- */

export function horch(ereignis, fn) {
  if (!horcher.has(ereignis)) horcher.set(ereignis, new Set());
  horcher.get(ereignis).add(fn);
  return () => horcher.get(ereignis).delete(fn);
}

export function melde(ereignis, nutzlast) {
  const menge = horcher.get(ereignis);
  if (menge) menge.forEach((fn) => fn(nutzlast));
}

/* ---------- Welche Bereiche sichtbar sind ---------- */

/**
 * Ist dieser Bereich zu sehen?
 *
 * Ohne ausdrückliche Wahl entscheidet die Gruppe: Themenbereiche sind an,
 * Rechtschreibblöcke aus. Siebenundzwanzig zusätzliche Karten auf der
 * Startseite wären für ein Kind, das eine Woche lang einen einzigen Block
 * übt, nur Gestrüpp — die Lehrkraft schaltet frei, was gerade dran ist.
 */
export function bereichSichtbar(bereich) {
  if (!bereich) return false;
  if (bereich.eigen) return true;
  const gewaehlt = zustand.sichtbareBereiche[bereich.id];
  if (typeof gewaehlt === 'boolean') return gewaehlt;
  return bereich.gruppe !== 'rechtschreibung';
}

export function setzeBereichSichtbar(id, an) {
  zustand.sichtbareBereiche[id] = Boolean(an);
  sichere();
  melde('sichtbarkeit', zustand.sichtbareBereiche);
}

/** Die ganze Auswahl auf einmal setzen — so kommt sie aus einer Klasse an. */
export function setzeSichtbareBereiche(auswahl) {
  if (!auswahl || typeof auswahl !== 'object') return;
  zustand.sichtbareBereiche = Object.assign({}, auswahl);
  sichere();
  melde('sichtbarkeit', zustand.sichtbareBereiche);
}

export function sichtbareBereiche() {
  return zustand.sichtbareBereiche;
}

/* ---------- Eigene Bereiche ---------- */

export function eigeneBereiche() {
  return zustand.eigeneBereiche;
}

/** Alles außer dem Zeitstempel — daran wird gemessen, ob sich etwas geändert hat. */
function bereichsinhalt(bereich) {
  if (!bereich) return '';
  const ohneZeit = Object.assign({}, bereich);
  delete ohneZeit.geaendertAm;
  return JSON.stringify(ohneZeit);
}

/**
 * Einen Bereich sichern.
 *
 * Ist er inhaltlich unverändert, passiert NICHTS — kein Schreiben, keine
 * Meldung. Das spart nicht nur Schreibvorgänge: Ein Beitritt zu einer Klasse
 * sichert deren mitgegebene Bereiche bei jedem Öffnen, und wer daraufhin
 * meldet, weckt jeden Horcher. Aus einer solchen Rückkopplung wurde einmal
 * eine Schleife ohne Boden (siehe app.js). Eine Meldung nur bei echter
 * Änderung schneidet diese Klasse von Fehlern an der Wurzel ab.
 */
export function bereichSichern(bereich) {
  const stelle = zustand.eigeneBereiche.findIndex((b) => b.id === bereich.id);
  if (stelle >= 0 && bereichsinhalt(zustand.eigeneBereiche[stelle]) === bereichsinhalt(bereich)) {
    return zustand.eigeneBereiche[stelle];
  }
  const eintrag = Object.assign({}, bereich, { geaendertAm: Date.now() });
  if (stelle >= 0) zustand.eigeneBereiche[stelle] = eintrag;
  else zustand.eigeneBereiche.push(eintrag);
  sichere();
  melde('bereiche', zustand.eigeneBereiche);
  return eintrag;
}

export function bereichLoeschen(id) {
  zustand.eigeneBereiche = zustand.eigeneBereiche.filter((b) => b.id !== id);
  sichere();
  melde('bereiche', zustand.eigeneBereiche);
}

/* ---------- Fortschritt ---------- */

function fortschrittsschluessel(bereichId, paket, stufe) {
  return `${bereichId}#${paket}#${stufe}`;
}

export function fortschritt(bereichId, paket, stufe) {
  return zustand.fortschritt[fortschrittsschluessel(bereichId, paket, stufe)] || null;
}

/**
 * Ein abgeschlossener Durchgang. Gemerkt wird der BESTE Stand, nicht der
 * letzte: Wer ein Päckchen zur Übung noch einmal halb durchklickt, soll seine
 * drei Sterne nicht verlieren.
 */
export function ergebnisMerken(bereichId, paket, stufe, { richtig, gesamt, dauer = 0 }) {
  const schluessel = fortschrittsschluessel(bereichId, paket, stufe);
  const alt = zustand.fortschritt[schluessel] || { bestRichtig: 0, gesamt: 0, durchgaenge: 0 };
  const neu = {
    bestRichtig: Math.max(alt.bestRichtig || 0, richtig),
    letzteRichtig: richtig,
    gesamt,
    durchgaenge: (alt.durchgaenge || 0) + 1,
    zuletzt: Date.now(),
    dauer,
  };
  neu.sterne = sterne(neu.bestRichtig, gesamt);
  zustand.fortschritt[schluessel] = neu;
  sichere();
  melde('fortschritt', { bereichId, paket, stufe, stand: neu });
  return neu;
}

/** Drei Sterne ab 100 %, zwei ab 80 %, einer ab 60 %. */
export function sterne(richtig, gesamt) {
  if (!gesamt) return 0;
  const anteil = richtig / gesamt;
  if (anteil >= 1) return 3;
  if (anteil >= 0.8) return 2;
  if (anteil >= 0.6) return 1;
  return 0;
}

export function sterneImBereich(bereichId, pakete, stufen) {
  let summe = 0;
  for (let p = 0; p < pakete; p += 1) {
    for (const stufe of stufen) {
      const stand = fortschritt(bereichId, p, stufe);
      if (stand) summe += stand.sterne || 0;
    }
  }
  return summe;
}

/* ---------- Wortprotokoll ---------- */

// Wie viele Falschschreibungen je Wort aufgehoben werden. Sechs reichen: Die
// siebte sagt einer Lehrkraft nichts Neues mehr, und jede weitere ist ein
// Datum über ein Kind, das ohne Nutzen herumliegt.
const EINGABEN_JE_WORT = 6;

// Obergrenze über alle Wörter. Ein Schuljahr mit vielen Bereichen kommt sonst
// auf Tausende Einträge, die bei jedem Päckchen mit hochgeladen würden.
const WOERTER_HOECHSTENS = 500;

function protokollschluessel(bereichId, wort) {
  return `${bereichId}|${wort}`;
}

/**
 * Ein bearbeitetes Wort ins Protokoll schreiben.
 *
 * Gemerkt wird je Wort: wie oft es drankam, wie oft es beim ersten Versuch
 * saß, in welchen Stufen — und wie das Kind es geschrieben hat, wenn es
 * danebenlag. Das Letzte ist der eigentliche Zweck: „Somer" statt
 * „Sommer" zeigt, WAS falsch gemerkt wurde.
 */
export function protokollMerken({ bereich, eintrag, stufeId, richtig, fehlversuche = [] }) {
  if (!bereich || !eintrag) return null;
  const schluessel = protokollschluessel(bereich.id, eintrag.wort);
  const alt = zustand.protokoll[schluessel];
  const stand = alt || {
    wort: eintrag.wort,
    bereichId: bereich.id,
    bereichName: bereich.name,
    art: eintrag.art,
    versuche: 0,
    richtig: 0,
    fehler: 0,
    stufen: {},
    eingaben: [],
    zuletzt: 0,
  };
  stand.versuche += 1;
  if (richtig) stand.richtig += 1; else stand.fehler += 1;
  stand.zuletzt = Date.now();
  const stufe = stand.stufen[stufeId] || { r: 0, f: 0 };
  if (richtig) stufe.r += 1; else stufe.f += 1;
  stand.stufen[stufeId] = stufe;
  for (const versuch of fehlversuche) {
    if (!versuch) continue;
    // Dieselbe Falschschreibung nicht zehnmal aufheben — sie ist einmal
    // aufschlussreich und danach nur noch Ballast.
    if (!stand.eingaben.includes(versuch)) stand.eingaben.unshift(versuch);
  }
  stand.eingaben = stand.eingaben.slice(0, EINGABEN_JE_WORT);
  zustand.protokoll[schluessel] = stand;

  const schluesselAlle = Object.keys(zustand.protokoll);
  if (schluesselAlle.length > WOERTER_HOECHSTENS) {
    schluesselAlle
      .sort((a, b) => (zustand.protokoll[a].zuletzt || 0) - (zustand.protokoll[b].zuletzt || 0))
      .slice(0, schluesselAlle.length - WOERTER_HOECHSTENS)
      .forEach((weg) => delete zustand.protokoll[weg]);
  }
  sichere();
  return stand;
}

export function protokoll() {
  return zustand.protokoll;
}

/** Die schwersten Wörter zuerst — für die eigene Rückschau und für die Klasse. */
export function schwereWoerter(hoechstens = 20) {
  return Object.values(zustand.protokoll)
    .filter((w) => w.fehler > 0)
    .sort((a, b) => (b.fehler - a.fehler) || (b.zuletzt - a.zuletzt))
    .slice(0, hoechstens);
}

export function protokollLeeren() {
  zustand.protokoll = {};
  sichere();
  melde('protokoll', zustand.protokoll);
}

/* ---------- Anmeldung ---------- */

export function nutzer() {
  return zustand.nutzer;
}

export function setzeNutzer(neu) {
  zustand.nutzer = neu;
  sichere();
  melde('nutzer', neu);
}

export function klassen() {
  return zustand.klassen;
}

export function klasseMerken(klasse) {
  const stelle = zustand.klassen.findIndex((k) => k.code === klasse.code);
  if (stelle >= 0) zustand.klassen[stelle] = Object.assign({}, zustand.klassen[stelle], klasse);
  else zustand.klassen.push(klasse);
  sichere();
  melde('klassen', zustand.klassen);
}

export function klasseVergessen(code) {
  zustand.klassen = zustand.klassen.filter((k) => k.code !== code);
  sichere();
  melde('klassen', zustand.klassen);
}

export function merkeBereich(id) {
  zustand.zuletztBereich = id;
  sichere();
}
