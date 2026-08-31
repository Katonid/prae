// Farbschema und Schrift auf die Oberfläche legen. Alles über CSS-Eigen-
// schaften, damit jedes Element von selbst folgt — auch das, was es beim
// Umschalten noch gar nicht gibt.

import { SCHEMATA, SCHRIFTEN, einstellungen } from './store.js';

export function schema() {
  const id = einstellungen().schema;
  return SCHEMATA.find((s) => s.id === id) || SCHEMATA[0];
}

export function schrift() {
  const id = einstellungen().schrift;
  return SCHRIFTEN.find((s) => s.id === id) || SCHRIFTEN[0];
}

export function anwenden() {
  const e = schema();
  const f = schrift();
  const stil = document.body.style;
  stil.setProperty('--akzent', e.von);
  stil.setProperty('--akzent-2', e.mitte);
  stil.setProperty('--akzent-3', e.bis);
  // Warum der Verlauf aus dem Schema kommt und nicht aus von/mitte/bis
  // gerechnet wird, steht bei SCHEMATA in store.js: Blau nach Orange läuft
  // durch Grau.
  stil.setProperty('--akzent-verlauf', e.verlauf);
  stil.setProperty('--warm-verlauf', e.warm);
  stil.setProperty('--akzent-schein', `0 16px 38px -14px rgba(${e.schein}, 0.9)`);
  stil.setProperty('--akzent-zart', `rgba(${e.schein}, 0.14)`);
  stil.setProperty('--schrift-lern', f.stack);
  document.body.dataset.schema = e.id;
  const marke = document.querySelector('meta[name="theme-color"]');
  if (marke) marke.setAttribute('content', e.von);
}
