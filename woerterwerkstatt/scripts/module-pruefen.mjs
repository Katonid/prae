// Drei Prüfungen über die ES-Module der Wörterwerkstatt.
//
// Die App hat keinen Bauschritt und kein Bündelwerkzeug — der Browser lädt die
// Dateien, wie sie im Repo liegen. Damit fällt auch die einzige Instanz weg,
// die sonst „importiert etwas, das es nicht gibt" bemerkt, bevor es jemand
// öffnet. Ein falscher Import ist hier kein Übersetzungsfehler, sondern eine
// weiße Seite. Genau das ist passiert (`meldung` aus `util.js` statt `ui.js`).
//
//   node --experimental-vm-modules woerterwerkstatt/scripts/module-pruefen.mjs
//
// 0. SYNTAXFEHLER — die Datei parst nicht. Eine fehlende Klammer in einer
//    tief verschachtelten `h(...)`-Reihe fällt beim Lesen nicht auf, und der
//    Browser meldet sie nur in der Entwicklerkonsole: außen bleibt die Seite
//    einfach leer. Bricht ab.
// 1. FEHLENDE AUSFUHR — jemand importiert einen Namen, den es dort nicht gibt.
//    Derselbe Schaden, dieselbe Wirkung. Bricht ab.
// 2. UNBENUTZTER IMPORT — steht in der Klammer, wird aber nie gebraucht.
// 3. TOTE AUSFUHR — wird ausgeführt, aber nirgends importiert.
//
// 2 und 3 sind Aufräumhinweise und lassen den Rückgabewert in Ruhe.

import fs from 'fs';
import path from 'path';
import vm from 'vm';
import { fileURLToPath } from 'url';

const WURZEL = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'js');

// Module, deren Ausfuhren absichtlich nur von außen (oder über einen
// Namensraum-Import) benutzt werden.
const OHNE_TOTE_PRUEFUNG = /sfx|plattform/;

function dateien(ordner) {
  return fs.readdirSync(ordner, { withFileTypes: true }).flatMap((eintrag) => (
    eintrag.isDirectory()
      ? dateien(path.join(ordner, eintrag.name))
      : (eintrag.name.endsWith('.js') ? [path.join(ordner, eintrag.name)] : [])
  ));
}

/** Die Namen, die eine Datei ausführt. */
function ausfuhren(text) {
  const namen = new Set();
  for (const treffer of text.matchAll(/^export\s+(?:async\s+)?(?:function|const|let|var|class)\s+([A-Za-z0-9_$]+)/gm)) {
    namen.add(treffer[1]);
  }
  for (const treffer of text.matchAll(/^export\s*\{([^}]+)\}/gm)) {
    for (const teil of treffer[1].split(',')) {
      const stueck = teil.trim().split(/\s+as\s+/);
      namen.add((stueck[1] || stueck[0] || '').trim());
    }
  }
  namen.delete('');
  return namen;
}

/** Die Namen, die eine Datei einführt — als [Ausfuhrname, örtlicher Name]. */
function einfuhren(text) {
  const gefunden = [];
  for (const treffer of text.matchAll(/import\s+(?:\{([^}]*)\}|\*\s+as\s+\w+)\s+from\s+'([^']+)'/g)) {
    const ziel = treffer[2];
    if (!treffer[1]) { gefunden.push([null, null, ziel]); continue; }
    for (const teil of treffer[1].split(',')) {
      const stueck = teil.trim().split(/\s+as\s+/);
      const aussen = (stueck[0] || '').trim();
      if (aussen) gefunden.push([aussen, (stueck[1] || stueck[0]).trim(), ziel]);
    }
  }
  return gefunden;
}

const alle = dateien(WURZEL);
const text = new Map(alle.map((datei) => [datei, fs.readFileSync(datei, 'utf8')]));
const bekannt = new Map(alle.map((datei) => [datei, ausfuhren(text.get(datei))]));
const kurz = (datei) => path.relative(WURZEL, datei);

/* 0. Parst überhaupt jede Datei? */
let schwer = 0;
for (const datei of alle) {
  try {
    // `vm.SourceTextModule` parst als Modul (mit import/export), ohne etwas
    // auszuführen. Es braucht --experimental-vm-modules; fehlt das Flag,
    // wird diese Prüfung übersprungen statt falschen Alarm zu schlagen.
    if (vm.SourceTextModule) new vm.SourceTextModule(text.get(datei), { identifier: kurz(datei) });
  } catch (problem) {
    console.log('SYNTAXFEHLER:', kurz(datei), '—', problem.message);
    schwer += 1;
  }
}

/* 1. Führt jemand etwas ein, das es nicht gibt? */
for (const datei of alle) {
  for (const [aussen, , ziel] of einfuhren(text.get(datei))) {
    const pfad = path.resolve(path.dirname(datei), ziel);
    if (!bekannt.has(pfad)) {
      console.log('FEHLENDE DATEI:', kurz(datei), '→', ziel);
      schwer += 1;
      continue;
    }
    if (aussen && !bekannt.get(pfad).has(aussen)) {
      console.log('FEHLENDE AUSFUHR:', kurz(datei), 'holt', aussen, 'aus', ziel);
      schwer += 1;
    }
  }
}

/* 2. Steht etwas in der Klammer, das nie gebraucht wird? */
let lose = 0;
for (const datei of alle) {
  const rumpf = text.get(datei).replace(/import\s+[^;]*;/g, '');
  for (const [, innen] of einfuhren(text.get(datei))) {
    if (!innen) continue;
    if (!new RegExp(`\\b${innen.replace(/\$/g, '\\$')}\\b`).test(rumpf)) {
      console.log('UNBENUTZTER IMPORT:', kurz(datei), innen);
      lose += 1;
    }
  }
}

/* 3. Wird etwas ausgeführt, das niemand holt? */
const geholt = new Set();
for (const datei of alle) for (const [aussen] of einfuhren(text.get(datei))) if (aussen) geholt.add(aussen);
let tot = 0;
for (const datei of alle) {
  if (OHNE_TOTE_PRUEFUNG.test(datei)) continue;
  const eigen = text.get(datei).replace(/^export\s+/gm, '');
  for (const name of bekannt.get(datei)) {
    if (geholt.has(name)) continue;
    const treffer = (eigen.match(new RegExp(`\\b${name}\\b`, 'g')) || []).length;
    if (treffer <= 1) { console.log('TOTE AUSFUHR:', kurz(datei), name); tot += 1; }
  }
}

console.log(schwer ? `\n${schwer} schwere(r) Fehler — die App bliebe weiß` : '\nAlle Module parsen, alle Importe stimmen');
console.log(lose ? `${lose} unbenutzte Einfuhr(en)` : 'keine unbenutzten Einfuhren');
console.log(tot ? `${tot} tote Ausfuhr(en)` : 'keine toten Ausfuhren');
process.exit(schwer ? 1 : 0);
