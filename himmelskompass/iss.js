/*
 * iss.js — ISS-Überflugberechnung auf Basis von satellite.js (SGP4).
 * Erwartet die globalen Objekte `satellite` (vendor/satellite) und `Astro`.
 */
(function (global) {
  'use strict';

  const rad = Math.PI / 180;
  const EARTH_R = 6371; // km

  // Ist der Satellit von der Sonne beleuchtet? (zylindrisches Erdschatten-Modell)
  function isSunlit(posEci, sun) {
    const r = [posEci.x, posEci.y, posEci.z];
    const s = [
      Math.cos(sun.dec) * Math.cos(sun.ra),
      Math.cos(sun.dec) * Math.sin(sun.ra),
      Math.sin(sun.dec)
    ];
    const dot = r[0] * s[0] + r[1] * s[1] + r[2] * s[2];
    if (dot >= 0) return true; // auf der Sonnenseite der Erde
    const r2 = r[0] * r[0] + r[1] * r[1] + r[2] * r[2];
    const perp = Math.sqrt(Math.max(0, r2 - dot * dot));
    return perp > EARTH_R;
  }

  /*
   * Überflüge mit Elevation > 10° im Zeitfenster [start, start + hours].
   * Ein Überflug ist "sichtbar", solange der Beobachter im Dunkeln steht
   * (Sonne < −6°) und die ISS von der Sonne angestrahlt wird.
   */
  function computePasses(tle1, tle2, lat, lng, start, hours) {
    let satrec;
    try {
      satrec = satellite.twoline2satrec(tle1, tle2);
    } catch (e) {
      return { error: 'tle' };
    }
    const observer = { latitude: lat * rad, longitude: lng * rad, height: 0.05 };
    const stepS = 15;
    const minEl = 10 * rad;
    const passes = [];
    let cur = null;

    for (let t = 0; t <= hours * 3600; t += stepS) {
      const date = new Date(start.valueOf() + t * 1000);
      let pv;
      try { pv = satellite.propagate(satrec, date); } catch (e) { pv = null; }
      if (!pv || !pv.position) continue;

      const gmst = satellite.gstime(date);
      const ecf = satellite.eciToEcf(pv.position, gmst);
      const look = satellite.ecfToLookAngles(observer, ecf);

      if (look.elevation > minEl) {
        const sunAltObs = Astro.getSunPosition(date, lat, lng).altitude;
        const visible = sunAltObs < -6 * rad && isSunlit(pv.position, Astro.getSunRaDec(date));
        if (!cur) cur = [];
        cur.push({ t: date, el: look.elevation, az: look.azimuth, visible });
      } else if (cur) {
        passes.push(finishPass(cur));
        cur = null;
      }
    }
    if (cur) passes.push(finishPass(cur));
    return { passes };
  }

  function finishPass(samples) {
    let max = samples[0];
    for (const s of samples) if (s.el > max.el) max = s;
    const vis = samples.filter((s) => s.visible);
    return {
      start: samples[0].t,
      end: samples[samples.length - 1].t,
      startAz: samples[0].az,
      endAz: samples[samples.length - 1].az,
      maxTime: max.t,
      maxEl: max.el,
      visibleFrom: vis.length ? vis[0].t : null,
      visibleTo: vis.length ? vis[vis.length - 1].t : null
    };
  }

  global.ISS = { computePasses };
})(typeof window !== 'undefined' ? window : globalThis);
