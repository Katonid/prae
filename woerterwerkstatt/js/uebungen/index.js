// Die fünf Stufen in ihrer Reihenfolge. Sie bauen aufeinander auf:
// abschreiben → erkennen → aus dem Wortbild erkennen → durchschauen → hören.
//
// Wer eine sechste Übung anlegt, trägt sie hier ein — sonst nirgends.

import { UEBUNG as abschreiben } from './abschreiben.js';
import { UEBUNG as salat } from './salat.js';
import { UEBUNG as geheimschrift } from './geheimschrift.js';
import { UEBUNG as wortart } from './wortart.js';
import { UEBUNG as diktat } from './diktat.js';

export const UEBUNGEN = [abschreiben, salat, geheimschrift, wortart, diktat];

export function uebungNachId(id) {
  return UEBUNGEN.find((u) => u.id === id) || null;
}


/**
 * Welche Stufen ein Bereich übt — in der Reihenfolge von oben.
 *
 * Nicht jeder Bereich übt alle fünf. Die Blöcke der 1. Klasse lassen die
 * Wortart-Stufe weg (Ansage des Nutzers): Ob ein Wort Nomen, Verb oder
 * Adjektiv ist, ist dort noch kein Stoff. Ein Block sagt das über das Feld
 * `stufen`; fehlt es, gelten alle fünf. Ergibt die Liste nichts Bekanntes,
 * gelten ebenfalls alle — ein Bereich ohne einzige Übung wäre eine Sackgasse.
 */
export function stufenFuer(bereich) {
  if (!bereich || !Array.isArray(bereich.stufen)) return UEBUNGEN;
  const erlaubt = UEBUNGEN.filter((u) => bereich.stufen.includes(u.id));
  return erlaubt.length ? erlaubt : UEBUNGEN;
}

/** Dieselbe Liste, nur die Kennungen — für Sternsummen und den Weiterweg. */
export function stufenIdsFuer(bereich) {
  return stufenFuer(bereich).map((u) => u.id);
}
