// Schriftauswahl für die ganze App.
//
// Vorgabe ist eine Schrift mit „einstöckigem" a und g — also einem runden a
// mit Strich, so wie es in der Grundschule geschrieben wird. Die gedruckte
// Form mit Bogen (wie in den meisten Systemschriften) verwirrt Leseanfänger.
// Alle Schriften liegen im Ordner fonts/ und werden nicht nachgeladen.

import { getState, touch } from './store.js';

const SYSTEM_STACK = '"SF Pro Display", "SF Pro Text", -apple-system, BlinkMacSystemFont, '
  + '"Segoe UI Variable", "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif';

export const FONTS = [
  {
    id: 'lexend',
    label: 'Lexend',
    hint: 'Vorgabe: ruhig, gerade, sehr gut lesbar — auch von hinten im Klassenraum.',
    stack: `"Lexend", ${SYSTEM_STACK}`,
  },
  {
    id: 'andika',
    label: 'Andika',
    hint: 'Eigens für Leseanfänger entworfen; unterscheidet deutlich zwischen I, l und 1.',
    stack: `"Andika", ${SYSTEM_STACK}`,
  },
  {
    id: 'quicksand',
    label: 'Quicksand',
    hint: 'Rund und freundlich, etwas verspielter — ohne handschriftlich zu wirken.',
    stack: `"Quicksand", ${SYSTEM_STACK}`,
  },
  {
    id: 'poppins',
    label: 'Poppins',
    hint: 'Klar und geometrisch, kräftig in großen Größen.',
    stack: `"Poppins", ${SYSTEM_STACK}`,
  },
  {
    id: 'system',
    label: 'Systemschrift',
    hint: 'Die Schrift des Geräts — mit dem gedruckten a (zwei Stockwerke).',
    stack: SYSTEM_STACK,
  },
];

export const DEFAULT_FONT = 'lexend';

export function fontById(id) {
  return FONTS.find((font) => font.id === id) || FONTS.find((font) => font.id === DEFAULT_FONT);
}

export function currentFontId() {
  const settings = getState().settings || {};
  return fontById(settings.font).id;
}

/** Schrift anwenden — die ganze App hängt an der Eigenschaft --font. */
export function applyFont(id = currentFontId()) {
  const font = fontById(id);
  document.documentElement.style.setProperty('--font', font.stack);
  document.body.dataset.font = font.id;
  return font;
}

export function setFont(id) {
  const font = fontById(id);
  getState().settings.font = font.id;
  touch({ board: false, reason: 'font' });
  applyFont(font.id);
  return font;
}
