/*
 * astro.js — Sonnen- und Mondberechnungen
 * Basierend auf den Formeln aus Jean Meeus, "Astronomical Algorithms",
 * in der vereinfachten Form der bekannten SunCalc-Algorithmen.
 * Genauigkeit: ~1 Minute für Sonnenzeiten, wenige Minuten für Mondzeiten.
 */
(function (global) {
  'use strict';

  const rad = Math.PI / 180;
  const dayMs = 1000 * 60 * 60 * 24;
  const J1970 = 2440588;
  const J2000 = 2451545;

  function toJulian(date) { return date.valueOf() / dayMs - 0.5 + J1970; }
  function fromJulian(j) { return new Date((j + 0.5 - J1970) * dayMs); }
  function toDays(date) { return toJulian(date) - J2000; }

  // Ekliptikschiefe
  const e = rad * 23.4397;

  function rightAscension(l, b) {
    return Math.atan2(Math.sin(l) * Math.cos(e) - Math.tan(b) * Math.sin(e), Math.cos(l));
  }
  function declination(l, b) {
    return Math.asin(Math.sin(b) * Math.cos(e) + Math.cos(b) * Math.sin(e) * Math.sin(l));
  }
  // Azimut hier: 0 = Süd; wird in den öffentlichen Funktionen auf 0 = Nord umgerechnet
  function azimuth(H, phi, dec) {
    return Math.atan2(Math.sin(H), Math.cos(H) * Math.sin(phi) - Math.tan(dec) * Math.cos(phi));
  }
  function altitude(H, phi, dec) {
    return Math.asin(Math.sin(phi) * Math.sin(dec) + Math.cos(phi) * Math.cos(dec) * Math.cos(H));
  }
  function siderealTime(d, lw) { return rad * (280.16 + 360.9856235 * d) - lw; }

  function astroRefraction(h) {
    if (h < 0) h = 0; // Formel gilt nur für positive Höhen
    return 0.0002967 / Math.tan(h + 0.00312536 / (h + 0.08901179));
  }

  // ---------- Sonne ----------

  function solarMeanAnomaly(d) { return rad * (357.5291 + 0.98560028 * d); }

  function eclipticLongitude(M) {
    const C = rad * (1.9148 * Math.sin(M) + 0.02 * Math.sin(2 * M) + 0.0003 * Math.sin(3 * M));
    const P = rad * 102.9372; // Perihel der Erde
    return M + C + P + Math.PI;
  }

  function sunCoords(d) {
    const M = solarMeanAnomaly(d);
    const L = eclipticLongitude(M);
    return { dec: declination(L, 0), ra: rightAscension(L, 0) };
  }

  function getSunPosition(date, lat, lng) {
    const lw = rad * -lng;
    const phi = rad * lat;
    const d = toDays(date);
    const c = sunCoords(d);
    const H = siderealTime(d, lw) - c.ra;
    return {
      azimuth: normalizeAz(azimuth(H, phi, c.dec) + Math.PI), // 0 = Nord, im Uhrzeigersinn
      altitude: altitude(H, phi, c.dec)
    };
  }

  function normalizeAz(a) {
    a = a % (2 * Math.PI);
    if (a < 0) a += 2 * Math.PI;
    return a;
  }

  // ---------- Sonnenzeiten ----------

  const J0 = 0.0009;

  function julianCycle(d, lw) { return Math.round(d - J0 - lw / (2 * Math.PI)); }
  function approxTransit(Ht, lw, n) { return J0 + (Ht + lw) / (2 * Math.PI) + n; }
  function solarTransitJ(ds, M, L) { return J2000 + ds + 0.0053 * Math.sin(M) - 0.0069 * Math.sin(2 * L); }
  function hourAngle(h, phi, d) {
    return Math.acos((Math.sin(h) - Math.sin(phi) * Math.sin(d)) / (Math.cos(phi) * Math.cos(d)));
  }

  function getSetJ(h, lw, phi, dec, n, M, L) {
    const w = hourAngle(h, phi, dec);
    const a = approxTransit(w, lw, n);
    return solarTransitJ(a, M, L);
  }

  // Winkel (Grad) → [Name Aufstieg, Name Abstieg]
  const timeAngles = [
    [-0.833, 'sunrise', 'sunset'],
    [-4, 'blueHourDawnEnd', 'blueHourDuskStart'],
    [-6, 'dawn', 'dusk'],
    [-8, 'blueHourDawnStart', 'blueHourDuskEnd'],
    [-12, 'nauticalDawn', 'nauticalDusk'],
    [-18, 'nightEnd', 'night'],
    [6, 'goldenHourDawnEnd', 'goldenHourDuskStart']
  ];

  function getSunTimes(date, lat, lng) {
    const lw = rad * -lng;
    const phi = rad * lat;
    const d = toDays(date);
    const n = julianCycle(d, lw);
    const ds = approxTransit(0, lw, n);
    const M = solarMeanAnomaly(ds);
    const L = eclipticLongitude(M);
    const dec = declination(L, 0);
    const Jnoon = solarTransitJ(ds, M, L);

    const result = {
      solarNoon: fromJulian(Jnoon),
      nadir: fromJulian(Jnoon - 0.5)
    };

    for (const [angle, riseName, setName] of timeAngles) {
      const Jset = getSetJ(angle * rad, lw, phi, dec, n, M, L);
      const Jrise = Jnoon - (Jset - Jnoon);
      result[riseName] = isNaN(Jrise) ? null : fromJulian(Jrise);
      result[setName] = isNaN(Jset) ? null : fromJulian(Jset);
    }
    return result;
  }

  // ---------- Mond ----------

  function moonCoords(d) {
    const L = rad * (218.316 + 13.176396 * d); // mittlere ekliptikale Länge
    const M = rad * (134.963 + 13.064993 * d); // mittlere Anomalie
    const F = rad * (93.272 + 13.229350 * d);  // mittlerer Abstand vom Knoten

    const l = L + rad * 6.289 * Math.sin(M);   // Länge
    const b = rad * 5.128 * Math.sin(F);       // Breite
    const dt = 385001 - 20905 * Math.cos(M);   // Entfernung in km

    return { ra: rightAscension(l, b), dec: declination(l, b), dist: dt };
  }

  function getMoonPosition(date, lat, lng) {
    const lw = rad * -lng;
    const phi = rad * lat;
    const d = toDays(date);
    const c = moonCoords(d);
    const H = siderealTime(d, lw) - c.ra;
    let h = altitude(H, phi, c.dec);
    const pa = Math.atan2(Math.sin(H), Math.tan(phi) * Math.cos(c.dec) - Math.sin(c.dec) * Math.cos(H));
    h = h + astroRefraction(h);
    return {
      azimuth: normalizeAz(azimuth(H, phi, c.dec) + Math.PI), // 0 = Nord
      altitude: h,
      distance: c.dist,
      parallacticAngle: pa
    };
  }

  function getMoonIllumination(date) {
    const d = toDays(date || new Date());
    const s = sunCoords(d);
    const m = moonCoords(d);
    const sdist = 149598000; // Entfernung Erde–Sonne in km

    const phi = Math.acos(
      Math.sin(s.dec) * Math.sin(m.dec) +
      Math.cos(s.dec) * Math.cos(m.dec) * Math.cos(s.ra - m.ra)
    );
    const inc = Math.atan2(sdist * Math.sin(phi), m.dist - sdist * Math.cos(phi));
    const angle = Math.atan2(
      Math.cos(s.dec) * Math.sin(s.ra - m.ra),
      Math.sin(s.dec) * Math.cos(m.dec) - Math.cos(s.dec) * Math.sin(m.dec) * Math.cos(s.ra - m.ra)
    );

    return {
      fraction: (1 + Math.cos(inc)) / 2,
      phase: 0.5 + 0.5 * inc * (angle < 0 ? -1 : 1) / Math.PI,
      angle: angle
    };
  }

  function hoursLater(date, h) { return new Date(date.valueOf() + h * dayMs / 24); }

  // Mondauf-/-untergang in den 24 Stunden ab dem übergebenen Zeitpunkt.
  // Der Aufrufer übergibt Mitternacht in der Zeitzone des Ortes.
  function getMoonTimes(date, lat, lng) {
    const t = new Date(date);

    const hc = 0.133 * rad;
    let h0 = getMoonPosition(t, lat, lng).altitude - hc;
    let rise, set, ye;

    // stundenweise nach Nulldurchgängen suchen (Interpolation über 2 Stunden)
    for (let i = 1; i <= 24; i += 2) {
      const h1 = getMoonPosition(hoursLater(t, i), lat, lng).altitude - hc;
      const h2 = getMoonPosition(hoursLater(t, i + 1), lat, lng).altitude - hc;

      const a = (h0 + h2) / 2 - h1;
      const b = (h2 - h0) / 2;
      const xe = -b / (2 * a);
      ye = (a * xe + b) * xe + h1;
      const d = b * b - 4 * a * h1;
      let roots = 0, x1, x2;

      if (d >= 0) {
        const dx = Math.sqrt(d) / (Math.abs(a) * 2);
        x1 = xe - dx;
        x2 = xe + dx;
        if (Math.abs(x1) <= 1) roots++;
        if (Math.abs(x2) <= 1) roots++;
        if (x1 < -1) x1 = x2;
      }

      if (roots === 1) {
        if (h0 < 0) rise = i + x1;
        else set = i + x1;
      } else if (roots === 2) {
        rise = i + (ye < 0 ? x2 : x1);
        set = i + (ye < 0 ? x1 : x2);
      }

      if (rise !== undefined && set !== undefined) break;
      h0 = h2;
    }

    const result = {};
    result.rise = rise !== undefined ? hoursLater(t, rise) : null;
    result.set = set !== undefined ? hoursLater(t, set) : null;
    if (rise === undefined && set === undefined) {
      result[ye > 0 ? 'alwaysUp' : 'alwaysDown'] = true;
    }
    return result;
  }

  // ---------- Galaktisches Zentrum (Milchstraße) ----------
  // J2000: RA 17h 45m 40s, Deklination −29° 00′ 28″ (Sagittarius A*)
  const GC_RA = rad * 266.4168;
  const GC_DEC = rad * -29.0078;

  function getGalacticCenterPosition(date, lat, lng) {
    const lw = rad * -lng;
    const phi = rad * lat;
    const d = toDays(date);
    const H = siderealTime(d, lw) - GC_RA;
    return {
      azimuth: normalizeAz(azimuth(H, phi, GC_DEC) + Math.PI), // 0 = Nord
      altitude: altitude(H, phi, GC_DEC)
    };
  }

  // Galaktische Ebene (b = 0) als Punktkette in Äquatorialkoordinaten,
  // einmalig vorberechnet. Nordgalaktischer Pol (J2000): RA 192,85948°,
  // Dek 27,12825°; galaktische Länge des Himmelsnordpols: 122,93192°.
  const NGP_RA = rad * 192.85948;
  const NGP_DEC = rad * 27.12825;
  const L_NCP = rad * 122.93192;
  const galacticPlane = [];
  for (let l = 0; l < 360; l += 4) {
    const dl = L_NCP - rad * l;
    const dec = Math.asin(Math.cos(NGP_DEC) * Math.cos(dl));
    const ra = NGP_RA + Math.atan2(Math.sin(dl), -Math.sin(NGP_DEC) * Math.cos(dl));
    galacticPlane.push({ ra, dec, l });
  }

  // Aktuelle Lage des Milchstraßen-Bands am Himmel des Ortes.
  // l = galaktische Länge (0 = galaktisches Zentrum, hellster Bereich).
  function getMilkyWayBand(date, lat, lng) {
    const lw = rad * -lng;
    const phi = rad * lat;
    const st = siderealTime(toDays(date), lw);
    return galacticPlane.map((p) => {
      const H = st - p.ra;
      return {
        azimuth: normalizeAz(azimuth(H, phi, p.dec) + Math.PI), // 0 = Nord
        altitude: altitude(H, phi, p.dec),
        l: p.l
      };
    });
  }

  // Phasenname aus Phasenwert (0 = Neumond, 0.5 = Vollmond)
  function moonPhaseName(phase) {
    const names = [
      'Neumond', 'Zunehmende Sichel', 'Erstes Viertel', 'Zunehmender Mond',
      'Vollmond', 'Abnehmender Mond', 'Letztes Viertel', 'Abnehmende Sichel'
    ];
    const idx = Math.round(phase * 8) % 8;
    return names[idx];
  }

  // Äquatorialkoordinaten der Sonne (für Beleuchtungsprüfung von Satelliten)
  function getSunRaDec(date) {
    return sunCoords(toDays(date));
  }

  // RA/Dek → Azimut/Höhe für Ort und Zeitpunkt (z. B. für Planeten)
  function raDecToAzAlt(ra, dec, date, lat, lng) {
    const lw = rad * -lng;
    const phi = rad * lat;
    const H = siderealTime(toDays(date), lw) - ra;
    return {
      azimuth: normalizeAz(azimuth(H, phi, dec) + Math.PI), // 0 = Nord
      altitude: altitude(H, phi, dec)
    };
  }

  global.Astro = {
    getSunPosition,
    getSunRaDec,
    raDecToAzAlt,
    getSunTimes,
    getMoonPosition,
    getMoonIllumination,
    getMoonTimes,
    getGalacticCenterPosition,
    getMilkyWayBand,
    moonPhaseName
  };
})(typeof window !== 'undefined' ? window : globalThis);
