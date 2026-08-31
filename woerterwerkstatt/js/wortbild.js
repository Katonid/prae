// Geheimschrift: das Wort als Buchstabenhaus und als Wortumriss.
//
// Zur Sache
// ---------
// Was hier gezeichnet wird, ist keine Erfindung, sondern das seit Jahrzehnten
// in der Grundschule übliche **Buchstabenhaus** (auch „Häuschenschrift“,
// „Wortbild“ oder „Wortkontur“). Jeder Buchstabe wohnt in einem dreistöckigen
// Haus:
//
//   Dachgeschoss   b d f h k l t ß und alle großen Buchstaben
//   Erdgeschoss    a c e i m n o r s u v w x z ä ö ü   (hier wohnen ALLE)
//   Keller         g j p q y
//
// Die Kinder kennen dieselben Stockwerke unter vielen Namen — Dachboden/
// Wohnung/Keller, Himmel/Mitte/Erde, Kopf/Bauch/Fuß. Die App beschriftet sie
// als Dach, Mitte und Keller.
//
// Warum kein fertiger Zeichensatz?
// --------------------------------
// Es gibt solche Schriften (Wortbild- und Konturschriften der Schulbuch-
// verlage), aber sie sind fast alle kostenpflichtig lizenziert und müssten
// nachgeladen werden. Beides bricht die zwei Zusagen dieser App: Sie läuft
// ohne Netz, und sie meldet nichts an Dritte. Gezeichnet wird deshalb selbst,
// als SVG — das ist obendrein beliebig groß skalierbar (Beamer!), färbbar
// und in einer späteren nativen Hülle unverändert brauchbar.
//
// Die beiden Darstellungen
// ------------------------
// „Häuschen“  Jeder Buchstabe ein eigener Kasten — man kann die Buchstaben
//             zählen. Der Einstieg.
// „Umriss“    Die Kästen wachsen zu EINER Kontur zusammen, wie beim
//             klassischen „Wortbilder umranden“ im Heft. Schwerer, weil die
//             Grenzen zwischen gleich hohen Buchstaben verschwinden.

import { s } from './util.js';

/* Stockwerke im Zeichenraster. Ein Buchstabe ist BREITE breit. */
const DACH_OBEN = 0;
const MITTE_OBEN = 15;
const MITTE_UNTEN = 34;
const KELLER_UNTEN = 49;
const BREITE = 13;
const LUECKE = 3;          // zwischen Buchstaben im Häuschen-Modus
const WORTLUECKE = 10;     // zwischen zwei Wörtern

// Kleine Buchstaben mit Oberlänge fangen etwas unter der Dachlinie an; große
// stoßen bis ganz oben. So sind beide auf einen Blick zu unterscheiden — die
// Farbe sagt es zusätzlich.
const OBERLAENGE_OBEN = 3;

const MIT_OBERLAENGE = new Set(['b', 'd', 'f', 'h', 'k', 'l', 't', 'ß']);
const MIT_UNTERLAENGE = new Set(['g', 'j', 'p', 'q', 'y']);
const MIT_PUNKT = new Set(['i', 'j']);
const MIT_UMLAUTPUNKTEN = new Set(['ä', 'ö', 'ü']);

/**
 * Wo wohnt dieser Buchstabe?
 *
 * Rückgabe: { art, gross, oben, unten, punkte } — `oben`/`unten` sind die
 * Kanten im Zeichenraster, `punkte` die Zahl der Tüpfelchen darüber (i-Punkt
 * oder Umlautpunkte).
 */
export function lage(zeichen) {
  const z = String(zeichen);
  if (z === ' ') return { art: 'luecke' };
  const klein = z.toLocaleLowerCase('de-DE');
  const gross = z !== klein && z === z.toLocaleUpperCase('de-DE');
  if (gross) {
    return { art: 'gross', gross: true, oben: DACH_OBEN, unten: MITTE_UNTEN, punkte: 0 };
  }
  const oberlaenge = MIT_OBERLAENGE.has(klein);
  const unterlaenge = MIT_UNTERLAENGE.has(klein);
  return {
    art: oberlaenge ? (unterlaenge ? 'beides' : 'oben') : (unterlaenge ? 'unten' : 'mitte'),
    gross: false,
    oben: oberlaenge ? OBERLAENGE_OBEN : MITTE_OBEN,
    unten: unterlaenge ? KELLER_UNTEN : MITTE_UNTEN,
    punkte: MIT_PUNKT.has(klein) ? 1 : (MIT_UMLAUTPUNKTEN.has(klein) ? 2 : 0),
  };
}

/**
 * Das Muster eines ganzen Wortes — die Kette der Lagen. Zwei Wörter mit
 * demselben Muster sehen in der Geheimschrift gleich aus; genau daran prüft
 * die Übung, ob ein falsch geschriebenes Wort wenigstens „ins Häuschen passt“.
 */
export function muster(wort) {
  return Array.from(String(wort)).map((zeichen) => {
    const l = lage(zeichen);
    if (l.art === 'luecke') return '_';
    return `${l.gross ? 'G' : l.art[0]}${l.punkte}`;
  }).join('.');
}

/** Passt die Eingabe wenigstens ins gezeigte Muster? */
export function musterPasst(eingabe, wort) {
  return muster(eingabe) === muster(wort);
}

/** Bausteine des Bildes: je Zeichen ein Kasten mit seinen Kanten. */
function kaesten(wort, abstand) {
  const out = [];
  let x = 0;
  for (const zeichen of Array.from(String(wort))) {
    const l = lage(zeichen);
    if (l.art === 'luecke') {
      x += WORTLUECKE;
      out.push({ luecke: true, x });
      continue;
    }
    out.push({ x, x2: x + BREITE, oben: l.oben, unten: l.unten, gross: l.gross, punkte: l.punkte });
    x += BREITE + abstand;
  }
  return { kaesten: out, breite: Math.max(BREITE, x - abstand) };
}

/**
 * Die Kontur einer Reihe zusammenhängender Kästen als ein Pfad: oben nach
 * rechts, unten wieder zurück. Weil alle Kanten waagrecht oder senkrecht sind,
 * genügt es, an jeder Buchstabengrenze die Höhe zu wechseln.
 */
function konturPfad(gruppe) {
  if (!gruppe.length) return '';
  const teile = [`M ${gruppe[0].x} ${gruppe[0].oben}`];
  for (let i = 0; i < gruppe.length; i += 1) {
    teile.push(`L ${gruppe[i].x2} ${gruppe[i].oben}`);
    if (i + 1 < gruppe.length) teile.push(`L ${gruppe[i + 1].x} ${gruppe[i + 1].oben}`);
  }
  for (let i = gruppe.length - 1; i >= 0; i -= 1) {
    teile.push(`L ${gruppe[i].x2} ${gruppe[i].unten}`);
    teile.push(`L ${gruppe[i].x} ${gruppe[i].unten}`);
  }
  teile.push('Z');
  return teile.join(' ');
}

function punkteFuer(kasten) {
  const mitte = (kasten.x + kasten.x2) / 2;
  const y = MITTE_OBEN - 5;
  if (kasten.punkte === 1) return [{ x: mitte, y }];
  if (kasten.punkte === 2) return [{ x: mitte - 3.2, y }, { x: mitte + 3.2, y }];
  return [];
}

/**
 * Das Wortbild als SVG.
 *
 * modus     'haus'   Kasten je Buchstabe (Vorgabe)
 *           'umriss' zusammengewachsene Kontur
 * linien    Hilfslinien des Häuschens zeigen
 * beschriftet  Stockwerke benennen (Dach / Mitte / Keller)
 */
export function wortbild(wort, { modus = 'haus', linien = true, beschriftet = false } = {}) {
  const abstand = modus === 'umriss' ? 0 : LUECKE;
  const { kaesten: liste, breite } = kaesten(wort, abstand);
  const rand = 8;
  // Die Stockwerksnamen brauchen eine eigene Spalte rechts — ohne sie legen
  // sie sich über die letzten Buchstaben und machen genau das unleserlich,
  // worum es geht.
  const beschriftungsspalte = beschriftet ? 26 : 0;
  const breiteGesamt = breite + rand * 2 + beschriftungsspalte;
  const hoehe = KELLER_UNTEN + rand * 2;

  const svg = s('svg', {
    class: `wortbild wortbild--${modus}`,
    viewBox: `0 0 ${breiteGesamt} ${hoehe}`,
    preserveAspectRatio: 'xMidYMid meet',
    role: 'img',
    'aria-label': `Wortbild mit ${liste.filter((k) => !k.luecke).length} Buchstaben`,
  });
  const gruppe = s('g', { transform: `translate(${rand} ${rand})` });

  if (linien) {
    const zeichnen = (y, art) => s('line', {
      x1: -rand + 2, x2: breite + rand - 2 + beschriftungsspalte, y1: y, y2: y, class: `wortbild__linie wortbild__linie--${art}`,
    });
    gruppe.appendChild(zeichnen(DACH_OBEN, 'dach'));
    gruppe.appendChild(zeichnen(MITTE_OBEN, 'mitte-oben'));
    gruppe.appendChild(zeichnen(MITTE_UNTEN, 'mitte-unten'));
    gruppe.appendChild(zeichnen(KELLER_UNTEN, 'keller'));
  }

  if (modus === 'umriss') {
    // An Wortlücken bricht die Kontur ab — sonst wüchsen zwei Wörter zusammen.
    let laufend = [];
    const abschliessen = () => {
      if (!laufend.length) return;
      gruppe.appendChild(s('path', { d: konturPfad(laufend), class: 'wortbild__kontur' }));
      laufend = [];
    };
    for (const kasten of liste) {
      if (kasten.luecke) { abschliessen(); continue; }
      laufend.push(kasten);
    }
    abschliessen();
    // Große Buchstaben bekommen zusätzlich einen Balken auf dem Dach: In einer
    // durchgehenden Kontur wäre ein großes B von einem kleinen b sonst nur an
    // drei Zeichenbreiten Höhenunterschied zu erkennen.
    for (const kasten of liste) {
      if (kasten.luecke || !kasten.gross) continue;
      gruppe.appendChild(s('rect', {
        x: kasten.x + 1, y: DACH_OBEN - 4.5, width: BREITE - 2, height: 2.6, rx: 1.3, class: 'wortbild__gross-balken',
      }));
    }
  } else {
    for (const kasten of liste) {
      if (kasten.luecke) continue;
      gruppe.appendChild(s('rect', {
        x: kasten.x,
        y: kasten.oben,
        width: BREITE,
        height: kasten.unten - kasten.oben,
        rx: 3,
        class: `wortbild__kasten ${kasten.gross ? 'is-gross' : 'is-klein'}`,
      }));
    }
  }

  for (const kasten of liste) {
    if (kasten.luecke) continue;
    for (const punkt of punkteFuer(kasten)) {
      gruppe.appendChild(s('circle', { cx: punkt.x, cy: punkt.y, r: 2, class: 'wortbild__punkt' }));
    }
  }

  if (beschriftet) {
    const text = (y, inhalt) => s('text', {
      x: breite + rand - 2 + beschriftungsspalte, y, class: 'wortbild__stockwerk', 'text-anchor': 'end',
    }, inhalt);
    gruppe.appendChild(text(MITTE_OBEN - 3, 'Dach'));
    gruppe.appendChild(text(MITTE_UNTEN - 3, 'Mitte'));
    gruppe.appendChild(text(KELLER_UNTEN - 2, 'Keller'));
  }

  svg.appendChild(gruppe);
  return svg;
}

/** Die Zahl der Buchstaben — als Hilfe unter dem Bild. */
export function buchstabenzahl(wort) {
  return Array.from(String(wort)).filter((z) => z !== ' ').length;
}
