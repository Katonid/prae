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

export const STUFEN_IDS = UEBUNGEN.map((u) => u.id);
