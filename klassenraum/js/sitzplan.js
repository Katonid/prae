// Der Sitzplan: der Klassenraum als Grundriss, die Plätze darin, und was
// beim Verteilen gilt. Reine Rechnung, ohne Ansicht — übernommen aus der
// Tafelbild-App (Sitzplan.swift / Sitzverteilung.swift, 1.3.0–1.3.14).
//
// „Nah" ist hier eine einzige Größe: der Abstand zweier Tischmitten,
// GEMESSEN in Tischbreiten. Der deckt Nachbar (~1,0), gegenüber (1,0–1,5),
// schräg (~1,4) und übernächster (2,0) ohne Sonderregeln ab — Reihen und
// Spalten zu erkennen bräche, sobald die Tische nicht im Raster stehen,
// und genau das sollen sie dürfen.

import { uid } from './util.js';

/* ---------- Maße ---------- */

export const SITZMASSE = {
  breit: 8,
  tief: 6,
  einheit: 8,
  // Ab wann ein Platz als belegt-daneben gilt, wenn jemand Ruhe braucht —
  // etwas mehr als eine Tischbreite, damit auch schräg gegenüber zählt.
  neben: 1.45,
  // Die Fuge zwischen zwei bündigen Tischen — nur beim Zeichnen.
  fuge: 0.25,
};

export const RAUMFORMEN = [
  { id: 'quer', label: 'Normal (4:3)', w: 120, h: 90 },
  { id: 'breit', label: 'Breit (5:3)', w: 150, h: 90 },
  { id: 'tief', label: 'Tief (3:4)', w: 90, h: 120 },
];

export function raumform(id) {
  return RAUMFORMEN.find((entry) => entry.id === id) || RAUMFORMEN[0];
}

export function tafeltiefe(form) {
  return Math.min(form.w, form.h) * 0.09;
}

export const TAFELSEITEN = [
  { id: 'unten', label: 'Unten' },
  { id: 'oben', label: 'Oben' },
  { id: 'links', label: 'Links' },
  { id: 'rechts', label: 'Rechts' },
];

/** Wie weit ein Punkt von der Tafelwand weg ist, in Raumeinheiten. */
export function abstandZurTafel(seite, punkt, form) {
  switch (seite) {
    case 'oben': return punkt.y;
    case 'links': return punkt.x;
    case 'rechts': return form.w - punkt.x;
    default: return form.h - punkt.y;
  }
}

/** Wo das Tafelband liegt — Mitte der Wand, gut die halbe Breite. */
export function tafelband(seite, form) {
  const tiefe = tafeltiefe(form);
  const dick = tiefe * 0.62;
  const luft = tiefe * 0.25;
  if (seite === 'links' || seite === 'rechts') {
    const lang = form.h * 0.52;
    return {
      x: seite === 'links' ? luft : form.w - luft - dick,
      y: (form.h - lang) / 2,
      w: dick,
      h: lang,
    };
  }
  const lang = form.w * 0.52;
  return {
    x: (form.w - lang) / 2,
    y: seite === 'oben' ? luft : form.h - luft - dick,
    w: lang,
    h: dick,
  };
}

/** Wie weit der Grundriss gedreht wird, damit die Tafelwand oben liegt —
 *  für den Blick der Kinder auf die Tafel. */
export function drehungFuerKinder(seite) {
  return { oben: 0, links: 90, unten: 180, rechts: 270 }[seite] || 0;
}

/* ---------- Blickwinkel: gedrehte Koordinaten, lesbare Namen ---------- */

export function blickwinkel(form, drehung) {
  const masse = drehung % 180 === 0 ? { w: form.w, h: form.h } : { w: form.h, h: form.w };
  const punkt = (stelle) => {
    switch (drehung) {
      case 90: return { x: form.h - stelle.y, y: stelle.x };
      case 180: return { x: form.w - stelle.x, y: form.h - stelle.y };
      case 270: return { x: stelle.y, y: form.w - stelle.x };
      default: return { x: stelle.x, y: stelle.y };
    }
  };
  const groesse = (feld) => (drehung % 180 === 0 ? { w: feld.w, h: feld.h } : { w: feld.h, h: feld.w });
  const rechteck = (feld) => {
    const mitte = punkt({ x: feld.x + feld.w / 2, y: feld.y + feld.h / 2 });
    const masse2 = groesse(feld);
    return { x: mitte.x - masse2.w / 2, y: mitte.y - masse2.h / 2, w: masse2.w, h: masse2.h };
  };
  return { masse, punkt, groesse, rechteck, drehung };
}

/* ---------- Plätze ---------- */

export function neuerPlatz(x, y, winkel = 0) {
  return { id: uid('platz'), x, y, winkel, gesperrt: false };
}

/** Das kleinste achsenparallele Rechteck um den gedrehten Tisch. */
export function umriss(platz) {
  const bogen = ((platz.winkel || 0) * Math.PI) / 180;
  const c = Math.abs(Math.cos(bogen));
  const s = Math.abs(Math.sin(bogen));
  const w = SITZMASSE.breit * c + SITZMASSE.tief * s;
  const h = SITZMASSE.breit * s + SITZMASSE.tief * c;
  return { x: platz.x - w / 2, y: platz.y - h / 2, w, h };
}

function schneidet(a, b) {
  return a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h;
}

function eingezogen(feld, um) {
  return { x: feld.x + um, y: feld.y + um, w: feld.w - um * 2, h: feld.h - um * 2 };
}

/** Abstand zweier Plätze in Tischbreiten — von Mitte zu Mitte. */
export function abstand(a, b) {
  return Math.hypot(a.x - b.x, a.y - b.y) / SITZMASSE.einheit;
}

/** Alle Plätze, die von `platz` aus als „nah" gelten. */
export function nahe(platz, plaetze, hoechstens) {
  const ergebnis = new Set();
  for (const andere of plaetze) {
    if (andere.id !== platz.id && abstand(platz, andere) <= hoechstens) ergebnis.add(andere.id);
  }
  return ergebnis;
}

/* ---------- Einrasten (Tafelbild 1.3.8/1.3.12) ---------- */

const FANG = 2.0;

function einmalig(werte) {
  const gesehen = new Set();
  const ergebnis = [];
  for (const wert of werte) {
    const schluessel = Math.round(wert * 100);
    if (!gesehen.has(schluessel)) {
      gesehen.add(schluessel);
      ergebnis.push(wert);
    }
  }
  return ergebnis;
}

function frei(platz, stelle, andere) {
  const probe = umriss(Object.assign({}, platz, { x: stelle.x, y: stelle.y }));
  const eigen = eingezogen(probe, 0.05);
  return !andere.some((nachbar) => schneidet(eigen, eingezogen(umriss(nachbar), 0.05)));
}

/**
 * Wohin ein gezogener Platz einrastet: erst an die Achsen und KANTEN der
 * anderen (bündig links/rechts/oben/unten), was übrig bleibt aufs Raster
 * (Schrittweite ein halber Tisch). Belegte Stellen werden nicht angeboten;
 * liegt der Finger auf einem Nachbarn, weicht der Tisch auf die nächste
 * freie Kante aus.
 */
export function gefangen(platz, ziel, andere) {
  const eigen = umriss(platz);
  const xWerte = [Math.round(ziel.x / (SITZMASSE.breit / 2)) * (SITZMASSE.breit / 2)];
  const yWerte = [Math.round(ziel.y / (SITZMASSE.tief / 2)) * (SITZMASSE.tief / 2)];

  for (const nachbar of andere) {
    const fremd = umriss(nachbar);
    const dx = (eigen.w + fremd.w) / 2;
    const dy = (eigen.h + fremd.h) / 2;
    for (const wert of [nachbar.x, nachbar.x - dx, nachbar.x + dx]) {
      if (Math.abs(wert - ziel.x) <= FANG) xWerte.push(wert);
    }
    for (const wert of [nachbar.y, nachbar.y - dy, nachbar.y + dy]) {
      if (Math.abs(wert - ziel.y) <= FANG) yWerte.push(wert);
    }
  }

  const xs = einmalig(xWerte).sort((a, b) => Math.abs(a - ziel.x) - Math.abs(b - ziel.x)).slice(0, 6);
  const ys = einmalig(yWerte).sort((a, b) => Math.abs(a - ziel.y) - Math.abs(b - ziel.y)).slice(0, 6);

  const vorschlaege = [];
  for (const x of xs) for (const y of ys) vorschlaege.push({ x, y, weite: Math.abs(x - ziel.x) + Math.abs(y - ziel.y) });
  vorschlaege.sort((a, b) => a.weite - b.weite);
  for (const vorschlag of vorschlaege) {
    if (frei(platz, vorschlag, andere)) return { x: vorschlag.x, y: vorschlag.y };
  }

  const kanten = [];
  for (const nachbar of andere) {
    const fremd = umriss(nachbar);
    const dx = (eigen.w + fremd.w) / 2;
    const dy = (eigen.h + fremd.h) / 2;
    for (const stelle of [
      { x: nachbar.x - dx, y: nachbar.y }, { x: nachbar.x + dx, y: nachbar.y },
      { x: nachbar.x, y: nachbar.y - dy }, { x: nachbar.x, y: nachbar.y + dy },
    ]) {
      kanten.push({ x: stelle.x, y: stelle.y, weite: Math.abs(stelle.x - ziel.x) + Math.abs(stelle.y - ziel.y) });
    }
  }
  kanten.sort((a, b) => a.weite - b.weite);
  for (const kante of kanten) {
    if (frei(platz, kante, andere)) return { x: kante.x, y: kante.y };
  }
  return { x: ziel.x, y: ziel.y };
}

/* ---------- Plätze automatisch hinlegen ---------- */

/** Tische paarweise in Reihen, zur Tafel ausgerichtet — nur ein Anfang. */
export function vorschlag(anzahl, formId, seite = 'unten') {
  if (anzahl <= 0) return [];
  const form = raumform(formId);
  const senkrecht = seite === 'links' || seite === 'rechts';
  const laengs = senkrecht ? form.h : form.w;
  const weg = senkrecht ? form.w : form.h;

  const paarLuecke = SITZMASSE.breit * 0.12;
  const gang = SITZMASSE.breit * 0.6;
  const paarBreite = SITZMASSE.breit * 2 + paarLuecke;
  const rand = SITZMASSE.breit * 0.4;
  const nutzbar = laengs - rand * 2;
  const paareProReihe = Math.max(1, Math.floor((nutzbar + gang) / (paarBreite + gang)));
  const spaltenProReihe = paareProReihe * 2;

  const ersteReihe = tafeltiefe(form) + SITZMASSE.tief * 0.8;
  const reihenAbstand = SITZMASSE.tief * 1.75;
  const reihen = Math.ceil(anzahl / spaltenProReihe);
  const raumTiefe = weg - ersteReihe - SITZMASSE.tief;
  const schritt = reihen > 1 ? Math.min(reihenAbstand, raumTiefe / (reihen - 1)) : reihenAbstand;

  const gesamt = paareProReihe * paarBreite + Math.max(0, paareProReihe - 1) * gang;
  const start = (laengs - gesamt) / 2 + SITZMASSE.breit / 2;

  const ergebnis = [];
  for (let nummer = 0; nummer < anzahl; nummer += 1) {
    const reihe = Math.floor(nummer / spaltenProReihe);
    const spalte = nummer % spaltenProReihe;
    const paar = Math.floor(spalte / 2);
    const inPaar = spalte % 2;
    const l = start + paar * (paarBreite + gang) + inPaar * (SITZMASSE.breit + paarLuecke);
    const w = ersteReihe + reihe * schritt;
    // „Längs und weg von der Tafel" auf x und y drehen; an einer
    // Seitenwand steht der Tisch quer.
    if (seite === 'oben') ergebnis.push(neuerPlatz(l, w));
    else if (seite === 'links') ergebnis.push(neuerPlatz(w, l, 90));
    else if (seite === 'rechts') ergebnis.push(neuerPlatz(form.w - w, l, 90));
    else ergebnis.push(neuerPlatz(l, form.h - w));
  }
  return ergebnis;
}

/** Einen einzelnen Platz irgendwo hinlegen, wo noch nichts liegt. */
export function freierPlatz(plaetze, formId, seite = 'unten') {
  const form = raumform(formId);
  const band = tafelband(seite, form);
  const sperr = { x: band.x - 2, y: band.y - 2, w: band.w + 4, h: band.h + 4 };
  for (let y = SITZMASSE.tief * 0.6; y < form.h - SITZMASSE.tief * 0.6; y += SITZMASSE.tief * 0.5) {
    for (let x = SITZMASSE.breit * 0.6; x < form.w - SITZMASSE.breit * 0.6; x += SITZMASSE.breit * 0.5) {
      const kandidat = neuerPlatz(x, y);
      const feld = umriss(kandidat);
      const istFrei = !schneidet(sperr, feld) && !plaetze.some(
        (andere) => schneidet(eingezogen(umriss(andere), -1), feld));
      if (istFrei) return kandidat;
    }
  }
  return neuerPlatz(form.w / 2, form.h / 2);
}

/* ---------- Der gezeigte Ausschnitt ---------- */

/**
 * Nicht der ganze Raum: alle Plätze, die Tafel, ein Rand von einer halben
 * Tischbreite — auf den Raum begrenzt. Leere Ecken kosteten sonst genau
 * dort Platz, wo die Namen gebraucht werden.
 */
export function ausschnitt(plaetze, formId, seite) {
  const form = raumform(formId);
  const ganzer = { x: 0, y: 0, w: form.w, h: form.h };
  let feld = null;
  const vereine = (a, b) => {
    if (!a) return Object.assign({}, b);
    const x = Math.min(a.x, b.x);
    const y = Math.min(a.y, b.y);
    return { x, y, w: Math.max(a.x + a.w, b.x + b.w) - x, h: Math.max(a.y + a.h, b.y + b.h) - y };
  };
  for (const platz of plaetze) feld = vereine(feld, umriss(platz));
  feld = vereine(feld, tafelband(seite, form));
  if (!feld) return ganzer;
  const rand = SITZMASSE.breit * 0.45;
  const x = Math.max(0, feld.x - rand);
  const y = Math.max(0, feld.y - rand);
  const w = Math.min(form.w, feld.x + feld.w + rand) - x;
  const h = Math.min(form.h, feld.y + feld.h + rand) - y;
  return w > 0 && h > 0 ? { x, y, w, h } : ganzer;
}

/* ---------- Verteilen (Tafelbild Sitzverteilung.swift) ---------- */

/**
 * Verteilt die Kinder auf die Plätze: mehrere zufällige Anfänge, von jedem
 * aus tauschen, solange es besser wird. Was nicht aufgeht, steht im
 * Bericht im Klartext.
 *
 * kinder: [{ name, alleine, wunsch ('egal'|'vorne'|'hinten'), merkmal }]
 * regeln: [{ a, b, art ('getrennt'|'zusammen'), abstand }] (Namen)
 * vorgabe: 'egal' | 'mix' | 'gleich' (Merkmalsvorgabe wie beim Zufallsnamen)
 */
export function verteile({
  plaetze, kinder, regeln = [], naehe = 1.6, formId = 'quer', seite = 'unten',
  vorgabe = 'egal', versuche = 14,
}) {
  const offen = plaetze.filter((platz) => !platz.gesperrt);
  if (!offen.length || !kinder.length) return { belegung: {}, bericht: [] };

  const anzahlPlaetze = offen.length;
  const anzahlKinder = kinder.length;

  // Abstandsmatrix einmal, nicht in jeder Bewertung neu.
  const strecke = Array.from({ length: anzahlPlaetze }, () => new Array(anzahlPlaetze).fill(0));
  for (let i = 0; i < anzahlPlaetze; i += 1) {
    for (let j = i + 1; j < anzahlPlaetze; j += 1) {
      const d = abstand(offen[i], offen[j]);
      strecke[i][j] = d;
      strecke[j][i] = d;
    }
  }

  // Tiefe 0 (an der Tafel) bis 1 — normiert über die belegten Plätze,
  // nicht über den Raum, sonst hinge „vorne" an den Wänden.
  const form = raumform(formId);
  const roh = offen.map((platz) => abstandZurTafel(seite, platz, form));
  const nah = Math.min(...roh);
  const spanne = Math.max(0.001, Math.max(...roh) - nah);
  const tiefe = roh.map((wert) => (wert - nah) / spanne);

  // Nachbarpaare einmal vorberechnen — bewertet wird zehntausendfach.
  const nachbarpaare = [];
  for (let i = 0; i < anzahlPlaetze; i += 1) {
    for (let j = i + 1; j < anzahlPlaetze; j += 1) {
      if (strecke[i][j] <= naehe) nachbarpaare.push([i, j]);
    }
  }

  const stelleVon = new Map(kinder.map((kind, nummer) => [kind.name, nummer]));
  const wuensche = kinder.map((kind) => kind.wunsch || 'egal');
  const alleine = kinder.map((kind) => Boolean(kind.alleine));
  const merkmalswerte = kinder.map((kind) => kind.merkmal || null);
  const merkmalZaehlt = vorgabe !== 'egal' && merkmalswerte.some(Boolean);

  const bedingungen = [];
  for (const regel of regeln) {
    const a = stelleVon.get(regel.a);
    const b = stelleVon.get(regel.b);
    if (a === undefined || b === undefined || a === b) continue;
    bedingungen.push({
      a, b,
      mass: regel.abstand > 0 ? regel.abstand : naehe,
      trennen: regel.art !== 'zusammen',
    });
  }

  // Gewichte wie in der iOS-App: Trennen wiegt am schwersten, das Merkmal
  // als ANTEIL (nach oben begrenzt), leere Plätze werden vorne teuer.
  const G_TRENNEN = 1000;
  const G_ZUSAMMEN = 160;
  const G_ALLEINE = 700;
  const G_RICHTUNG = 150;
  const G_MERKMAL = 420;
  const G_LEER = 110;

  function merkmalsbilanz(belegung) {
    let passend = 0;
    let unpassend = 0;
    for (const [i, j] of nachbarpaare) {
      const a = belegung[i];
      const b = belegung[j];
      if (a < 0 || b < 0) continue;
      const wa = merkmalswerte[a];
      const wb = merkmalswerte[b];
      if (!wa || !wb) continue;
      if ((wa === wb) === (vorgabe === 'gleich')) passend += 1;
      else unpassend += 1;
    }
    return [passend, unpassend];
  }

  function bewerte(belegung) {
    const platzVon = new Array(anzahlKinder).fill(-1);
    belegung.forEach((kind, platz) => {
      if (kind >= 0) platzVon[kind] = platz;
    });
    let summe = 0;

    for (const bedingung of bedingungen) {
      const pa = platzVon[bedingung.a];
      const pb = platzVon[bedingung.b];
      if (pa < 0 || pb < 0) continue;
      const d = strecke[pa][pb];
      if (bedingung.trennen) {
        if (d < bedingung.mass) summe += G_TRENNEN + (bedingung.mass - d) * G_TRENNEN * 0.5;
      } else if (d > bedingung.mass) {
        summe += G_ZUSAMMEN * 0.25 + (d - bedingung.mass) * G_ZUSAMMEN;
      }
    }

    for (let kind = 0; kind < anzahlKinder; kind += 1) {
      if (!alleine[kind]) continue;
      const platz = platzVon[kind];
      if (platz < 0) continue;
      belegung.forEach((wer, andere) => {
        if (wer >= 0 && andere !== platz && strecke[platz][andere] <= SITZMASSE.neben) summe += G_ALLEINE;
      });
    }

    for (let kind = 0; kind < anzahlKinder; kind += 1) {
      const platz = platzVon[kind];
      if (platz < 0) continue;
      if (wuensche[kind] === 'vorne') summe += G_RICHTUNG * tiefe[platz];
      else if (wuensche[kind] === 'hinten') summe += G_RICHTUNG * (1 - tiefe[platz]);
    }

    belegung.forEach((wer, platz) => {
      if (wer < 0) summe += G_LEER * (1 - tiefe[platz]);
    });

    if (merkmalZaehlt) {
      const [passend, unpassend] = merkmalsbilanz(belegung);
      const gesamt = passend + unpassend;
      if (gesamt > 0) summe += (G_MERKMAL * unpassend) / gesamt;
    }
    return summe;
  }

  function gemischt(bis) {
    const werte = Array.from({ length: bis }, (_, index) => index);
    for (let i = werte.length - 1; i > 0; i -= 1) {
      const j = Math.floor(Math.random() * (i + 1));
      [werte[i], werte[j]] = [werte[j], werte[i]];
    }
    return werte;
  }

  let bestes = null;
  let besterWert = Infinity;

  for (let versuch = 0; versuch < Math.max(1, versuche); versuch += 1) {
    const belegung = new Array(anzahlPlaetze).fill(-1);
    const sitzend = gemischt(anzahlKinder).slice(0, Math.min(anzahlKinder, anzahlPlaetze));
    const stellen = gemischt(anzahlPlaetze);
    sitzend.forEach((kind, nummer) => {
      belegung[stellen[nummer]] = kind;
    });

    let wert = bewerte(belegung);
    let runde = 0;
    let verbessert = true;
    while (verbessert && runde < 40) {
      verbessert = false;
      runde += 1;
      for (let i = 0; i < anzahlPlaetze; i += 1) {
        for (let j = i + 1; j < anzahlPlaetze; j += 1) {
          if (belegung[i] < 0 && belegung[j] < 0) continue;
          [belegung[i], belegung[j]] = [belegung[j], belegung[i]];
          const neu = bewerte(belegung);
          if (neu < wert - 0.000001) {
            wert = neu;
            verbessert = true;
          } else {
            [belegung[i], belegung[j]] = [belegung[j], belegung[i]];
          }
        }
      }
    }

    if (wert < besterWert) {
      besterWert = wert;
      bestes = belegung.slice();
    }
    if (besterWert <= 0) break;
  }

  if (!bestes) return { belegung: {}, bericht: [] };

  const ergebnis = { belegung: {}, bericht: [] };
  const platzVon = new Array(anzahlKinder).fill(-1);
  bestes.forEach((kind, platz) => {
    if (kind >= 0) {
      ergebnis.belegung[offen[platz].id] = kinder[kind].name;
      platzVon[kind] = platz;
    }
  });

  // Der Bericht: Ein Plan, der stillschweigend Regeln bricht, ist
  // schlimmer als gar keiner.
  const zahl = (wert) => wert.toFixed(1).replace('.', ',');

  if (anzahlKinder > anzahlPlaetze) {
    const ohne = kinder.filter((_, kind) => platzVon[kind] < 0).map((kind) => kind.name);
    ergebnis.bericht.push(`Es gibt ${anzahlPlaetze} Plätze für ${anzahlKinder} Kinder. Ohne Platz geblieben: ${ohne.join(', ')}.`);
  }

  for (const bedingung of bedingungen) {
    const pa = platzVon[bedingung.a];
    const pb = platzVon[bedingung.b];
    if (pa < 0 || pb < 0) continue;
    const d = strecke[pa][pb];
    const namen = `${kinder[bedingung.a].name} und ${kinder[bedingung.b].name}`;
    if (bedingung.trennen && d < bedingung.mass) {
      ergebnis.bericht.push(`${namen} sitzen ${zahl(d)} Plätze auseinander — gewünscht waren ${zahl(bedingung.mass)}.`);
    } else if (!bedingung.trennen && d > bedingung.mass * 1.35) {
      ergebnis.bericht.push(`${namen} sitzen ${zahl(d)} Plätze auseinander — näher als ${zahl(bedingung.mass)} ging nicht.`);
    }
  }

  if (merkmalZaehlt) {
    const [passend, unpassend] = merkmalsbilanz(bestes);
    const gesamt = passend + unpassend;
    if (gesamt > 0 && passend / gesamt < 0.75) {
      const wort = vorgabe === 'gleich' ? 'gleich' : 'gemischt';
      ergebnis.bericht.push(`Von ${gesamt} Nachbarschaften sitzen ${passend} wie gewünscht (${wort}), ${unpassend} nicht. Mehr Plätze oder weniger Paarregeln schaffen hier Luft.`);
    }
  }

  for (let kind = 0; kind < anzahlKinder; kind += 1) {
    if (!alleine[kind]) continue;
    const platz = platzVon[kind];
    if (platz < 0) continue;
    let nachbarn = 0;
    bestes.forEach((wer, andere) => {
      if (wer >= 0 && andere !== platz && strecke[platz][andere] <= SITZMASSE.neben) nachbarn += 1;
    });
    if (nachbarn > 0) {
      ergebnis.bericht.push(`${kinder[kind].name} sollte einen freien Platz daneben haben, hat aber ${nachbarn === 1 ? 'einen Nachbarn' : `${nachbarn} Nachbarn`}.`);
    }
  }

  for (let kind = 0; kind < anzahlKinder; kind += 1) {
    const platz = platzVon[kind];
    if (platz < 0) continue;
    if (wuensche[kind] === 'vorne' && tiefe[platz] > 0.62) {
      ergebnis.bericht.push(`${kinder[kind].name} wollte nach vorne, sitzt aber hinten.`);
    } else if (wuensche[kind] === 'hinten' && tiefe[platz] < 0.38) {
      ergebnis.bericht.push(`${kinder[kind].name} wollte nach hinten, sitzt aber vorne.`);
    }
  }

  return ergebnis;
}

/* ---------- Archiv ---------- */

/** Kalenderwoche nach ISO 8601. */
export function kalenderwoche(datum = new Date()) {
  const ziel = new Date(Date.UTC(datum.getFullYear(), datum.getMonth(), datum.getDate()));
  const tag = ziel.getUTCDay() || 7;
  ziel.setUTCDate(ziel.getUTCDate() + 4 - tag);
  const anfang = new Date(Date.UTC(ziel.getUTCFullYear(), 0, 1));
  return Math.ceil(((ziel - anfang) / 86400000 + 1) / 7);
}

/** „KW 35 – 30.08.2026" — die Woche, nach der man sucht, und der Tag,
 *  der zwei Auslosungen derselben Woche auseinanderhält. */
export function standardtitel(datum = new Date()) {
  const tag = String(datum.getDate()).padStart(2, '0');
  const monat = String(datum.getMonth() + 1).padStart(2, '0');
  return `KW ${kalenderwoche(datum)} – ${tag}.${monat}.${datum.getFullYear()}`;
}

export const ARCHIV_GRENZE = 40;
