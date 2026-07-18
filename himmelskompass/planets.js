/*
 * planets.js — Positionen der hellen Planeten (Merkur bis Saturn).
 * Keplerbahn-Elemente und Raten aus JPL "Approximate Positions of the Planets"
 * (Table 1, gültig 1800–2050 n. Chr., Genauigkeit für AR-Zwecke weit ausreichend).
 * Erwartet das globale Objekt `Astro` (für die Umrechnung nach Azimut/Höhe).
 */
(function (global) {
  'use strict';

  const rad = Math.PI / 180;

  // [a (au), e, I (°), L (°), ϖ (°), Ω (°)] bei J2000 und Raten pro Julianischem Jahrhundert
  const ELEMENTS = {
    Merkur: {
      el: [0.38709927, 0.20563593, 7.00497902, 252.25032350, 77.45779628, 48.33076593],
      rate: [0.00000037, 0.00001906, -0.00594749, 149472.67411175, 0.16047689, -0.12534081]
    },
    Venus: {
      el: [0.72333566, 0.00677672, 3.39467605, 181.97909950, 131.60246718, 76.67984255],
      rate: [0.00000390, -0.00004107, -0.00078890, 58517.81538729, 0.00268329, -0.27769418]
    },
    Erde: {
      el: [1.00000261, 0.01671123, -0.00001531, 100.46457166, 102.93768193, 0.0],
      rate: [0.00000562, -0.00004392, -0.01294668, 35999.37244981, 0.32327364, 0.0]
    },
    Mars: {
      el: [1.52371034, 0.09339410, 1.84969142, -4.55343205, -23.94362959, 49.55953891],
      rate: [0.00001847, 0.00007882, -0.00813131, 19140.30268499, 0.44441088, -0.29257343]
    },
    Jupiter: {
      el: [5.20288700, 0.04838624, 1.30439695, 34.39644051, 14.72847983, 100.47390909],
      rate: [-0.00011607, -0.00013253, -0.00183714, 3034.74612775, 0.21252668, 0.20469106]
    },
    Saturn: {
      el: [9.53667594, 0.05386179, 2.48599187, 49.95424423, 92.59887831, 113.66242448],
      rate: [-0.00125060, -0.00050991, 0.00193609, 1222.49362201, -0.41897216, -0.28867794]
    }
  };

  const NAMES = ['Merkur', 'Venus', 'Mars', 'Jupiter', 'Saturn'];

  function julianCenturies(date) {
    return (date.valueOf() / 86400000 - 10957.5) / 36525; // ab J2000.0
  }

  // Heliozentrische ekliptikale Koordinaten (au)
  function heliocentric(name, T) {
    const p = ELEMENTS[name];
    const a = p.el[0] + p.rate[0] * T;
    const e = p.el[1] + p.rate[1] * T;
    const I = (p.el[2] + p.rate[2] * T) * rad;
    const L = (p.el[3] + p.rate[3] * T) * rad;
    const varpi = (p.el[4] + p.rate[4] * T) * rad;
    const Omega = (p.el[5] + p.rate[5] * T) * rad;

    const omega = varpi - Omega;
    let M = (L - varpi) % (2 * Math.PI);

    // Kepler-Gleichung iterativ lösen
    let E = M + e * Math.sin(M);
    for (let i = 0; i < 8; i++) {
      const dE = (E - e * Math.sin(E) - M) / (1 - e * Math.cos(E));
      E -= dE;
      if (Math.abs(dE) < 1e-8) break;
    }

    const xv = a * (Math.cos(E) - e);
    const yv = a * Math.sqrt(1 - e * e) * Math.sin(E);

    const cO = Math.cos(Omega), sO = Math.sin(Omega);
    const co = Math.cos(omega), so = Math.sin(omega);
    const cI = Math.cos(I), sI = Math.sin(I);

    return [
      (cO * co - sO * so * cI) * xv + (-cO * so - sO * co * cI) * yv,
      (sO * co + cO * so * cI) * xv + (-sO * so + cO * co * cI) * yv,
      (so * sI) * xv + (co * sI) * yv
    ];
  }

  // Näherungsformeln (Meeus) für die scheinbare Helligkeit
  function magnitude(name, r, delta, iDeg) {
    const base = 5 * Math.log10(r * delta);
    switch (name) {
      case 'Merkur': return -0.42 + base + 0.0380 * iDeg - 0.000273 * iDeg * iDeg + 0.000002 * iDeg * iDeg * iDeg;
      case 'Venus': return -4.40 + base + 0.0009 * iDeg + 0.000239 * iDeg * iDeg - 0.00000065 * iDeg * iDeg * iDeg;
      case 'Mars': return -1.52 + base + 0.016 * iDeg;
      case 'Jupiter': return -9.40 + base + 0.005 * iDeg;
      case 'Saturn': return -8.88 + base + 0.044 * iDeg; // ohne Ringanteil
      default: return base;
    }
  }

  /*
   * Geozentrische Position eines Planeten:
   * { ra, dec (rad), delta (au, Entfernung zur Erde), mag (scheinbare Helligkeit) }
   */
  function compute(name, date) {
    const T = julianCenturies(date);
    const p = heliocentric(name, T);
    const earth = heliocentric('Erde', T);
    const g = [p[0] - earth[0], p[1] - earth[1], p[2] - earth[2]];

    // Ekliptik → Äquator
    const eps = 23.43928 * rad;
    const x = g[0];
    const y = g[1] * Math.cos(eps) - g[2] * Math.sin(eps);
    const z = g[1] * Math.sin(eps) + g[2] * Math.cos(eps);

    const ra = Math.atan2(y, x);
    const dec = Math.atan2(z, Math.hypot(x, y));
    const delta = Math.hypot(g[0], g[1], g[2]);
    const r = Math.hypot(p[0], p[1], p[2]);
    const R = Math.hypot(earth[0], earth[1], earth[2]);

    // Phasenwinkel Sonne–Planet–Erde
    const cosI = (r * r + delta * delta - R * R) / (2 * r * delta);
    const iDeg = Math.acos(Math.max(-1, Math.min(1, cosI))) / rad;

    return { ra, dec, delta, mag: magnitude(name, r, delta, iDeg) };
  }

  // Position am Himmel eines Ortes: { azimuth, altitude, mag, delta }
  function position(name, date, lat, lng) {
    const c = compute(name, date);
    const aa = Astro.raDecToAzAlt(c.ra, c.dec, date, lat, lng);
    return { azimuth: aa.azimuth, altitude: aa.altitude, mag: c.mag, delta: c.delta };
  }

  global.Planets = { NAMES, compute, position };
})(typeof window !== 'undefined' ? window : globalThis);
