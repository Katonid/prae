// Das Feierbild: sechs gezeichnete Abläufe für die Geburtstagsseite —
// Geschenk, Rakete, Ballons, Feuerwerk, Torte, Konfetti. Übernommen aus
// der Tafelbild-App (Feierbild.swift, 1.2.x).
//
// Gezeichnet, nicht abgespielt: Alles entsteht aus Formen in einem Canvas
// und hängt an einem einzigen Fortschrittswert von 0 bis 1. Damit ist das
// Bild zu jedem Zeitpunkt eindeutig bestimmt, passt sich jeder Größe an
// und bleibt auf dem Beamer scharf. Der Zufall steckt in den Startwerten
// der Teilchen (fester Keim je Teilchen), nicht im Ablauf — sonst
// zitterten sie, statt zu fliegen.

const FARBEN = ['#f472b6', '#fbbf24', '#34d399', '#60a5fa', '#c084fc', '#fb7185', '#facc15', '#4ade80'];

/** Kleiner, guter Zufall mit festem Keim (SplitMix-Idee): Jede Eigenschaft
 *  eines Teilchens kommt aus einem eigenen Wurf, nichts hängt starr an
 *  etwas anderem — die Bänder-Falle aus Tafelbild 1.2.4. */
function wuerfel(keim) {
  let zustand = keim >>> 0;
  return () => {
    zustand = (zustand + 0x9e3779b9) >>> 0;
    let z = zustand;
    z = Math.imul(z ^ (z >>> 16), 0x21f0aaad);
    z = Math.imul(z ^ (z >>> 15), 0x735a2d97);
    z ^= z >>> 15;
    return (z >>> 0) / 4294967296;
  };
}

function farbe(zufall) {
  return FARBEN[Math.floor(zufall() * FARBEN.length)];
}

/** Weicher Farb-Himmel unter allem: Ein fester Grund macht jede Bewegung
 *  darüber zu einer Bewegung vor einem Bild. */
function himmel(ctx, w, h, t) {
  const wolken = [
    ['#7c3aed', 0.25, 0.3], ['#db2777', 0.7, 0.55], ['#2563eb', 0.45, 0.8],
  ];
  ctx.save();
  ctx.globalAlpha = 0.22;
  wolken.forEach(([ton, fx, fy], index) => {
    const x = w * (fx + Math.sin(t * Math.PI * 2 + index * 2.1) * 0.06);
    const y = h * (fy + Math.cos(t * Math.PI * 2 + index * 1.7) * 0.05);
    const radius = Math.max(w, h) * 0.42;
    const verlauf = ctx.createRadialGradient(x, y, 0, x, y, radius);
    verlauf.addColorStop(0, ton);
    verlauf.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.fillStyle = verlauf;
    ctx.fillRect(0, 0, w, h);
  });
  ctx.restore();
}

/** Heller Schlag in den ersten Zehntelsekunden — der Grund, warum der
 *  Auftritt ANFÄNGT, statt einfach da zu sein. */
function anfangsblitz(ctx, w, h, t) {
  if (t > 0.08) return;
  ctx.save();
  ctx.globalAlpha = (1 - t / 0.08) * 0.5;
  ctx.fillStyle = '#ffffff';
  ctx.fillRect(0, 0, w, h);
  ctx.restore();
}

function konfettiRegen(ctx, w, h, t, { anzahl = 90, keim = 7, ab = 0, dicht = 1 } = {}) {
  for (let i = 0; i < anzahl; i += 1) {
    const z = wuerfel(keim * 1000 + i);
    const start = ab + z() * (1 - ab) * 0.55;
    if (t < start) continue;
    const leben = (t - start) / (1 - start || 1);
    const x = w * z() + Math.sin((leben * 6 + z() * 6.3)) * w * 0.03;
    const y = -20 + (h + 60) * Math.pow(leben, 0.9) * (0.55 + z() * 0.65) * dicht;
    if (y > h + 20) continue;
    ctx.save();
    ctx.translate(x, y);
    ctx.rotate(leben * 12 * (z() > 0.5 ? 1 : -1) + z() * 6);
    ctx.globalAlpha = Math.min(1, (1 - leben) * 2);
    ctx.fillStyle = farbe(z);
    const groesse = 4 + z() * 7;
    ctx.fillRect(-groesse / 2, -groesse / 4, groesse, groesse / 2);
    ctx.restore();
  }
}

/** Ein platzender Feuerwerksball: zwei Schalen, gestreute Reichweiten,
 *  Schweife und ein Blitz beim Platzen (Tafelbild 1.2.2). */
function feuerball(ctx, x, y, radius, start, t, keim) {
  if (t < start) return;
  const leben = Math.min(1, (t - start) / 0.4);
  const z0 = wuerfel(keim);
  const ton = farbe(z0);
  if (leben < 0.12) {
    ctx.save();
    ctx.globalAlpha = 1 - leben / 0.12;
    ctx.fillStyle = '#fff7ed';
    ctx.beginPath();
    ctx.arc(x, y, radius * 0.4 * (0.5 + leben * 6), 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  }
  for (let schale = 0; schale < 2; schale += 1) {
    const funken = 14;
    for (let i = 0; i < funken; i += 1) {
      const z = wuerfel(keim + schale * 97 + i * 13);
      const winkel = ((i + schale * 0.5) / funken) * Math.PI * 2 + z() * 0.25;
      const weite = radius * (0.3 + z() * 0.95) * (schale ? 0.7 : 1);
      const fx = x + Math.cos(winkel) * weite * leben;
      const fy = y + Math.sin(winkel) * weite * leben + leben * leben * radius * 0.25;
      ctx.save();
      ctx.globalAlpha = Math.max(0, 1 - leben) * (0.5 + z() * 0.5);
      ctx.strokeStyle = ton;
      ctx.lineWidth = 2.4;
      ctx.beginPath();
      ctx.moveTo(x + (fx - x) * 0.5, y + (fy - y) * 0.5);
      ctx.lineTo(fx, fy);
      ctx.stroke();
      ctx.globalAlpha = Math.max(0, 1 - leben);
      ctx.fillStyle = '#fff';
      ctx.beginPath();
      ctx.arc(fx, fy, 2 + z() * 1.6, 0, Math.PI * 2);
      ctx.fill();
      ctx.restore();
    }
  }
}

function ballon(ctx, x, y, groesse, ton, kippen) {
  ctx.save();
  ctx.translate(x, y);
  ctx.rotate(kippen);
  // Kringelschnur
  ctx.strokeStyle = 'rgba(255,255,255,0.7)';
  ctx.lineWidth = 1.4;
  ctx.beginPath();
  for (let s = 0; s <= 10; s += 1) {
    const sy = groesse * 0.62 + s * groesse * 0.09;
    const sx = Math.sin(s * 1.8) * groesse * 0.08;
    if (s === 0) ctx.moveTo(sx, sy);
    else ctx.lineTo(sx, sy);
  }
  ctx.stroke();
  // Tropfenform mit Rand und Glanz (die flache Ellipse las sich platt).
  ctx.fillStyle = ton;
  ctx.beginPath();
  ctx.ellipse(0, 0, groesse * 0.42, groesse * 0.52, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.strokeStyle = 'rgba(0,0,0,0.25)';
  ctx.lineWidth = 1.5;
  ctx.stroke();
  ctx.fillStyle = 'rgba(255,255,255,0.55)';
  ctx.beginPath();
  ctx.ellipse(-groesse * 0.14, -groesse * 0.18, groesse * 0.1, groesse * 0.16, -0.5, 0, Math.PI * 2);
  ctx.fill();
  // Knoten
  ctx.fillStyle = ton;
  ctx.beginPath();
  ctx.moveTo(-groesse * 0.06, groesse * 0.5);
  ctx.lineTo(groesse * 0.06, groesse * 0.5);
  ctx.lineTo(0, groesse * 0.62);
  ctx.closePath();
  ctx.fill();
  ctx.restore();
}

/** Die Torte: drei flache Etagen, Teller, Zuckerguss — und so viele Kerzen,
 *  wie das Kind alt wird (bis 8 in einer Reihe, darüber zweireihig
 *  gestaffelt, gedeckelt bei 18 — mehr wäre ein Lagerfeuer). */
function torte(ctx, w, h, t, kerzen) {
  const mitteX = w / 2;
  const boden = h * 0.86;
  const breite = Math.min(w * 0.5, h * 0.62);
  const anzahl = Math.max(1, Math.min(18, kerzen || 5));
  const reihen = anzahl <= 8 ? [anzahl] : [Math.ceil(anzahl / 2), Math.floor(anzahl / 2)];

  ctx.save();
  // Teller
  ctx.fillStyle = 'rgba(255,255,255,0.85)';
  ctx.beginPath();
  ctx.ellipse(mitteX, boden, breite * 0.62, breite * 0.07, 0, 0, Math.PI * 2);
  ctx.fill();
  // Drei Etagen
  const etagen = [
    [breite * 1.0, breite * 0.16, '#f9a8d4'],
    [breite * 0.78, breite * 0.14, '#fbcfe8'],
    [breite * 0.56, breite * 0.13, '#f9a8d4'],
  ];
  let oben = boden;
  for (const [eb, ehoehe, ton] of etagen) {
    oben -= ehoehe;
    ctx.fillStyle = ton;
    ctx.beginPath();
    ctx.roundRect(mitteX - eb / 2, oben, eb, ehoehe, 8);
    ctx.fill();
    // Zuckerguss mit Tropfen
    ctx.fillStyle = '#fff1f2';
    ctx.beginPath();
    ctx.roundRect(mitteX - eb / 2, oben, eb, ehoehe * 0.32, 8);
    ctx.fill();
    for (let tropfen = 0; tropfen < Math.floor(eb / 26); tropfen += 1) {
      const tx = mitteX - eb / 2 + 14 + tropfen * 26;
      ctx.beginPath();
      ctx.arc(tx, oben + ehoehe * 0.32, 5, 0, Math.PI);
      ctx.fill();
    }
  }
  // Kerzen: hintere Reihe höher und schmaler, damit sie über die vordere
  // hinwegschaut; eine ungerade Zahl wird hinten eigens mittig gesetzt.
  reihen.forEach((zahl, reihe) => {
    const hinten = reihe === (reihen.length - 1) && reihen.length > 1;
    const kBreite = hinten ? 5 : 7;
    const kHoehe = hinten ? breite * 0.15 : breite * 0.12;
    const spann = Math.min(breite * 0.5 - 16, zahl * 16) * 2;
    const abstand = zahl > 1 ? spann / (zahl - 1) : 0;
    const y0 = oben - kHoehe - (hinten ? breite * 0.05 : 0);
    for (let i = 0; i < zahl; i += 1) {
      const x = mitteX - spann / 2 + (zahl > 1 ? i * abstand : 0);
      const z = wuerfel(400 + reihe * 31 + i);
      ctx.fillStyle = ['#60a5fa', '#f472b6', '#fbbf24', '#34d399'][i % 4];
      ctx.fillRect(x - kBreite / 2, y0, kBreite, kHoehe);
      ctx.fillStyle = '#1f2937';
      ctx.fillRect(x - 1, y0 - 5, 2, 5);
      // Die Flammen gehen nacheinander an.
      const an = t > 0.15 + (i / zahl) * 0.35;
      if (an) {
        const flackern = 1 + Math.sin(t * 40 + z() * 9) * 0.15;
        const flamme = ctx.createRadialGradient(x, y0 - 10, 0, x, y0 - 10, 9 * flackern);
        flamme.addColorStop(0, '#fef9c3');
        flamme.addColorStop(0.5, '#fbbf24');
        flamme.addColorStop(1, 'rgba(251,191,36,0)');
        ctx.fillStyle = flamme;
        ctx.beginPath();
        ctx.arc(x, y0 - 10, 9 * flackern, 0, Math.PI * 2);
        ctx.fill();
      }
    }
  });
  ctx.restore();
}

/* ---------- Die sechs Abläufe ---------- */

const ABLAEUFE = {
  geschenk(ctx, w, h, t) {
    const kante = Math.min(w, h) * 0.42;
    const mitteX = w / 2;
    const boden = h * 0.88;
    const offen = t > 0.22;
    // Konfetti steigt aus dem offenen Kasten
    if (offen) {
      for (let i = 0; i < 70; i += 1) {
        const z = wuerfel(900 + i);
        const start = 0.22 + z() * 0.3;
        if (t < start) continue;
        const leben = (t - start) / (1 - start);
        const tempo = 0.35 + z() * 1.55;
        const winkel = -Math.PI / 2 + (z() - 0.5) * 1.5;
        const x = mitteX + Math.cos(winkel) * kante * 1.6 * leben * tempo;
        const y = boden - kante * 0.6 + Math.sin(winkel) * kante * 2.1 * leben * tempo
          + leben * leben * h * 0.55;
        ctx.save();
        ctx.globalAlpha = Math.max(0, 1 - leben * 1.1);
        ctx.translate(x, y);
        ctx.rotate(leben * 10 + z() * 6);
        ctx.fillStyle = farbe(z);
        ctx.fillRect(-5, -3, 10, 6);
        ctx.restore();
      }
    }
    // Kasten
    ctx.save();
    ctx.translate(mitteX, boden);
    const wippen = offen ? 0 : Math.sin(t * 40) * 0.03;
    ctx.rotate(wippen);
    ctx.fillStyle = '#e11d48';
    ctx.fillRect(-kante / 2, -kante * 0.62, kante, kante * 0.62);
    ctx.fillStyle = '#fda4af';
    ctx.fillRect(-kante * 0.08, -kante * 0.62, kante * 0.16, kante * 0.62);
    // Licht aus dem offenen Kasten
    if (offen) {
      const licht = ctx.createLinearGradient(0, -kante * 1.4, 0, -kante * 0.6);
      licht.addColorStop(0, 'rgba(254,243,199,0)');
      licht.addColorStop(1, 'rgba(254,243,199,0.55)');
      ctx.fillStyle = licht;
      ctx.beginPath();
      ctx.moveTo(-kante * 0.5, -kante * 0.62);
      ctx.lineTo(-kante * 0.8, -kante * 1.5);
      ctx.lineTo(kante * 0.8, -kante * 1.5);
      ctx.lineTo(kante * 0.5, -kante * 0.62);
      ctx.closePath();
      ctx.fill();
    }
    // Deckel (fliegt weg) mit Schleife
    const flug = offen ? Math.min(1, (t - 0.22) / 0.4) : 0;
    ctx.save();
    ctx.translate(kante * 0.7 * flug, -kante * 0.68 - kante * 1.1 * flug);
    ctx.rotate(flug * 0.9);
    ctx.fillStyle = '#be123c';
    ctx.fillRect(-kante * 0.56, -kante * 0.12, kante * 1.12, kante * 0.16);
    ctx.strokeStyle = '#fda4af';
    ctx.lineWidth = 5;
    ctx.beginPath();
    ctx.ellipse(-kante * 0.09, -kante * 0.18, kante * 0.09, kante * 0.05, -0.5, 0, Math.PI * 2);
    ctx.ellipse(kante * 0.09, -kante * 0.18, kante * 0.09, kante * 0.05, 0.5, 0, Math.PI * 2);
    ctx.stroke();
    ctx.restore();
    ctx.restore();
  },

  rakete(ctx, w, h, t) {
    const aufstieg = Math.min(1, t / 0.42);
    const x = w * 0.5 + Math.sin(t * 9) * 6 * (1 - aufstieg);
    const y = h * 0.95 - (h * 0.75) * aufstieg;
    if (aufstieg < 1) {
      // Rauchspur aus Wölkchen
      for (let i = 0; i < 12; i += 1) {
        const z = wuerfel(300 + i);
        const alter = (aufstieg - i / 14);
        if (alter < 0) continue;
        ctx.save();
        ctx.globalAlpha = Math.max(0, 0.35 - alter);
        ctx.fillStyle = '#e2e8f0';
        ctx.beginPath();
        ctx.arc(x + (z() - 0.5) * 20, y + 40 + i * 26, 8 + alter * 26, 0, Math.PI * 2);
        ctx.fill();
        ctx.restore();
      }
      // Rumpf, Spitze, Finnen, Bullauge, Flamme
      ctx.save();
      ctx.translate(x, y);
      ctx.fillStyle = '#e11d48';
      ctx.beginPath();
      ctx.roundRect(-14, -46, 28, 66, 10);
      ctx.fill();
      ctx.fillStyle = '#9f1239';
      ctx.beginPath();
      ctx.moveTo(-14, -40);
      ctx.quadraticCurveTo(0, -78, 14, -40);
      ctx.closePath();
      ctx.fill();
      ctx.fillStyle = '#fda4af';
      ctx.beginPath();
      ctx.moveTo(-14, 12);
      ctx.lineTo(-30, 30);
      ctx.lineTo(-14, 22);
      ctx.moveTo(14, 12);
      ctx.lineTo(30, 30);
      ctx.lineTo(14, 22);
      ctx.fill();
      ctx.fillStyle = '#bae6fd';
      ctx.beginPath();
      ctx.arc(0, -22, 8, 0, Math.PI * 2);
      ctx.fill();
      const flamme = 1 + Math.sin(t * 60) * 0.3;
      ctx.fillStyle = '#fbbf24';
      ctx.beginPath();
      ctx.moveTo(-9, 20);
      ctx.quadraticCurveTo(0, 20 + 34 * flamme, 9, 20);
      ctx.closePath();
      ctx.fill();
      ctx.restore();
    }
    // Oben drei Feuerwerksbälle nacheinander
    feuerball(ctx, w * 0.5, h * 0.22, Math.min(w, h) * 0.3, 0.44, t, 11);
    feuerball(ctx, w * 0.32, h * 0.3, Math.min(w, h) * 0.24, 0.58, t, 23);
    feuerball(ctx, w * 0.68, h * 0.28, Math.min(w, h) * 0.26, 0.72, t, 37);
  },

  ballons(ctx, w, h, t) {
    for (let i = 0; i < 14; i += 1) {
      // Zeitfächer: Jeder Ballon würfelt in seinem eigenen Fach — der
      // Abstand ist damit garantiert, nicht bloß wahrscheinlich.
      const z = wuerfel(500 + i * 7);
      const start = (i / 14) * 0.35 + z() * 0.02;
      const spalte = ((i % 7) + 0.5) / 7 + (z() - 0.5) * 0.08;
      if (t < start) continue;
      const leben = (t - start) / (1 - start);
      const groesse = Math.min(w, h) * (0.16 + z() * 0.08);
      const x = w * spalte + Math.sin(leben * 5 + z() * 6) * w * 0.03;
      const y = h + groesse - (h + groesse * 2) * Math.pow(leben, 0.85) * (0.9 + z() * 0.35);
      ballon(ctx, x, y, groesse, farbe(z), Math.sin(leben * 4 + z() * 3) * 0.15);
    }
  },

  feuerwerk(ctx, w, h, t) {
    const baelle = [
      [0.5, 0.3, 0.32, 0.05], [0.25, 0.42, 0.24, 0.18], [0.75, 0.38, 0.26, 0.3],
      [0.38, 0.22, 0.22, 0.44], [0.65, 0.2, 0.28, 0.56], [0.2, 0.25, 0.2, 0.68], [0.82, 0.24, 0.24, 0.8],
    ];
    baelle.forEach(([fx, fy, fr, start], index) => {
      // Aufsteigende Spur davor
      const anlauf = start - 0.06;
      if (t > anlauf && t < start) {
        const s = (t - anlauf) / 0.06;
        ctx.save();
        ctx.globalAlpha = 0.8;
        ctx.strokeStyle = '#fde68a';
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.moveTo(w * fx, h);
        ctx.lineTo(w * fx, h - (h - h * fy) * s);
        ctx.stroke();
        ctx.restore();
      }
      feuerball(ctx, w * fx, h * fy, Math.min(w, h) * fr, start, t, 60 + index * 17);
    });
  },

  torte(ctx, w, h, t, kerzen) {
    torte(ctx, w, h, t, kerzen);
    // Zum Lied ein wenig Flitter im letzten Drittel — die Feier bekommt
    // einen Schluss, statt einfach aufzuhören.
    if (t > 0.62) konfettiRegen(ctx, w, h, (t - 0.62) / 0.38, { anzahl: 50, keim: 77 });
  },

  konfetti(ctx, w, h, t) {
    konfettiRegen(ctx, w, h, t, { anzahl: 140, keim: 5 });
    // Goldregen im letzten Drittel
    if (t > 0.6) konfettiRegen(ctx, w, h, (t - 0.6) / 0.4, { anzahl: 60, keim: 55 });
  },
};

/**
 * Ein Bild der Feier zeichnen. `t` läuft von 0 (Start) bis 1 (Ende);
 * `kerzen` zählt nur bei der Torte.
 */
export function zeichneFeier(ctx, art, t, breite, hoehe, kerzen = 5) {
  ctx.clearRect(0, 0, breite, hoehe);
  ctx.save();
  // Die ganze Szene atmet: Sie geht beim Start auf und sinkt zum Schluss.
  const atem = 1 + Math.sin(Math.min(1, t * 1.25) * Math.PI) * 0.045;
  ctx.translate(breite / 2, hoehe / 2);
  ctx.scale(atem, atem);
  ctx.translate(-breite / 2, -hoehe / 2);
  himmel(ctx, breite, hoehe, t);
  const ablauf = ABLAEUFE[art] || ABLAEUFE.geschenk;
  ablauf(ctx, breite, hoehe, t, kerzen);
  anfangsblitz(ctx, breite, hoehe, t);
  ctx.restore();
}
