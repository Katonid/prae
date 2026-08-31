// Trainingspäckchen: fünfzehn Lernwörter, die zusammen geübt werden.
//
// Warum fünfzehn? Weil das die übliche Größe einer Lernwörterliste einer
// Schulwoche ist — und weil eine Übung damit in einer Viertelstunde zu
// schaffen ist. Ein Päckchen, das ein Kind nicht zu Ende bringt, motiviert
// niemanden.
//
// Wie die Wörter auf die Päckchen verteilt werden
// ------------------------------------------------
// NICHT einfach die ersten fünfzehn: In einem Bereich stehen die Nomen
// beieinander, dann die Verben, dann die Adjektive. Wer so teilt, bekommt ein
// Päckchen aus lauter Nomen — und Stufe 4 („Wortart erkennen“) wäre darin ein
// Witz, weil die Antwort immer dieselbe ist.
//
// Verteilt wird deshalb reihum über die Wortarten, in fester Reihenfolge: Auf
// jedem Gerät entstehen dieselben Päckchen, ohne dass irgendwo eine Zuordnung
// gespeichert werden müsste. Das ist wichtig, sobald eine Lehrkraft sagt
// „heute Päckchen 2“ — das muss bei allen Kindern dasselbe Päckchen sein.

import { eintraege } from './grammatik.js';

export const PAKETGROESSE = 15;

/**
 * Alle Einträge eines Bereichs in der Reihenfolge, in der sie auf die
 * Päckchen verteilt werden: reihum Nomen, Verb, Adjektiv, Sonstiges — jeweils
 * so viele, wie ihrem Anteil entspricht.
 */
function verteilt(liste) {
  const nach = { n: [], v: [], a: [], x: [] };
  for (const eintrag of liste) (nach[eintrag.art] || nach.x).push(eintrag);
  const arten = ['n', 'v', 'a', 'x'].filter((art) => nach[art].length);
  const gesamt = liste.length;
  // Je Wortart ein Zähler, der mit ihrem Anteil wächst. Wer den höchsten
  // Übertrag hat, ist als Nächstes dran — so liegen die seltenen Wortarten
  // gleichmäßig verstreut statt am Ende geklumpt.
  const stand = {};
  const schritt = {};
  for (const art of arten) { stand[art] = 0; schritt[art] = nach[art].length / gesamt; }
  const out = [];
  const offen = {};
  for (const art of arten) offen[art] = nach[art].slice();
  while (out.length < gesamt) {
    let beste = null;
    for (const art of arten) {
      if (!offen[art].length) continue;
      stand[art] += schritt[art];
      if (!beste || stand[art] > stand[beste]) beste = art;
    }
    if (!beste) break;
    stand[beste] -= 1;
    out.push(offen[beste].shift());
  }
  return out;
}

/** Wie viele Päckchen hat dieser Bereich? Ein Rest bildet ein kleineres letztes. */
export function paketzahl(bereich) {
  const anzahl = bereich && Array.isArray(bereich.woerter) ? bereich.woerter.length : 0;
  return Math.max(1, Math.ceil(anzahl / PAKETGROESSE));
}

/** Die Einträge des Päckchens Nummer `nummer` (0-basiert). */
export function paket(bereich, nummer) {
  const alle = verteilt(eintraege(bereich));
  return alle.slice(nummer * PAKETGROESSE, (nummer + 1) * PAKETGROESSE);
}

/** Alle Päckchen eines Bereichs, für die Übersicht. */
export function pakete(bereich) {
  const alle = verteilt(eintraege(bereich));
  const out = [];
  for (let i = 0; i < alle.length; i += PAKETGROESSE) out.push(alle.slice(i, i + PAKETGROESSE));
  return out.length ? out : [[]];
}

export function paketspanne(liste) {
  if (!liste.length) return '';
  return `${liste[0].wort} … ${liste[liste.length - 1].wort}`;
}
