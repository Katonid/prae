/*
 * ar.js — AR-Himmelsansicht: Kamera auf den Himmel richten, die App blendet
 * die aktuelle Position der ISS (plus Sonne, Mond und Milchstraße) ein.
 * Erwartet die globalen Objekte `satellite`, `Astro` und `ISS`.
 */
(function (global) {
  'use strict';

  const rad = Math.PI / 180;
  const FOV_V = 65 * rad; // angenommenes vertikales Sichtfeld der Kamera

  let opts = null;        // { lat, lng, tle, fmtTime, fmtRange }
  let satrec = null;
  let active = false;
  let rafId = null;
  let stream = null;
  let canvas, ctx, video;

  // Blickrichtung: Sensor-Basis (rechts/oben/vorn in Weltkoordinaten Ost/Nord/Oben)
  let basis = null;
  let hasSensor = false;
  // Fallback ohne Sensor: manuelles Umschauen per Wischen
  let yaw = 180 * rad, pitch = 25 * rad;

  let nextPassText = '';
  let trail = [];         // ISS-Bahnspur der nächsten Minuten
  let trailComputed = 0;
  let sunPath = [], moonPath = []; // Tagesbahnen für den Sonne-&-Mond-Modus

  // ---------- Orientierung ----------

  // W3C-Rotationsmatrix (ZXY): bildet Gerätekoordinaten auf Ost/Nord/Oben ab
  function orientationBasis(alpha, beta, gamma) {
    const _x = (beta || 0) * rad, _y = (gamma || 0) * rad, _z = (alpha || 0) * rad;
    const cX = Math.cos(_x), cY = Math.cos(_y), cZ = Math.cos(_z);
    const sX = Math.sin(_x), sY = Math.sin(_y), sZ = Math.sin(_z);
    const m = [
      cZ * cY - sZ * sX * sY, -cX * sZ, cY * sZ * sX + cZ * sY,
      cY * sZ + cZ * sX * sY, cZ * cX, sZ * sY - cZ * cY * sX,
      -cX * sY, sX, cX * cY
    ];
    // Spalten der Matrix = Geräteachsen in Weltkoordinaten
    return {
      r: [m[0], m[3], m[6]],            // Geräte-x (rechts)
      u: [m[1], m[4], m[7]],            // Geräte-y (oben)
      f: [-m[2], -m[5], -m[8]]          // Blickrichtung der Rückkamera (−z)
    };
  }

  function onOrient(ev) {
    let alpha = ev.alpha;
    if (typeof ev.webkitCompassHeading === 'number') {
      alpha = 360 - ev.webkitCompassHeading; // iOS: echten Kompass nutzen
    }
    if (alpha == null || ev.beta == null) return;
    basis = orientationBasis(alpha, ev.beta, ev.gamma);
    hasSensor = true;
  }

  // Fallback-Basis aus Blickrichtung (yaw = Azimut, pitch = Höhe)
  function manualBasis() {
    const sy = Math.sin(yaw), cy = Math.cos(yaw);
    const sp = Math.sin(pitch), cp = Math.cos(pitch);
    return {
      r: [cy, -sy, 0],
      u: [-sy * sp, -cy * sp, cp],
      f: [sy * cp, cy * cp, sp]
    };
  }

  // ---------- Projektion ----------

  function project(az, alt, b, w, h, fpx) {
    const v = [Math.sin(az) * Math.cos(alt), Math.cos(az) * Math.cos(alt), Math.sin(alt)];
    const x = v[0] * b.r[0] + v[1] * b.r[1] + v[2] * b.r[2];
    const y = v[0] * b.u[0] + v[1] * b.u[1] + v[2] * b.u[2];
    const depth = v[0] * b.f[0] + v[1] * b.f[1] + v[2] * b.f[2];
    if (depth <= 0.02) return { visible: false, x, y };
    const px = w / 2 + fpx * x / depth;
    const py = h / 2 - fpx * y / depth;
    return { visible: px > -60 && px < w + 60 && py > -60 && py < h + 60, px, py, x, y };
  }

  // Blickrichtung der Bildmitte (für die Anzeige oben)
  function viewCenter(b) {
    const az = Math.atan2(b.f[0], b.f[1]);
    const alt = Math.asin(Math.max(-1, Math.min(1, b.f[2])));
    return { az: ((az / rad) + 360) % 360, alt: alt / rad };
  }

  // ---------- ISS ----------

  function issNow(date) {
    let pv;
    try { pv = satellite.propagate(satrec, date); } catch (e) { return null; }
    if (!pv || !pv.position) return null;
    const gmst = satellite.gstime(date);
    const ecf = satellite.eciToEcf(pv.position, gmst);
    const look = satellite.ecfToLookAngles(
      { latitude: opts.lat * rad, longitude: opts.lng * rad, height: 0.05 }, ecf);
    const sunAlt = Astro.getSunPosition(date, opts.lat, opts.lng).altitude;
    const sun = Astro.getSunRaDec(date);
    const r = [pv.position.x, pv.position.y, pv.position.z];
    const s = [Math.cos(sun.dec) * Math.cos(sun.ra), Math.cos(sun.dec) * Math.sin(sun.ra), Math.sin(sun.dec)];
    const dot = r[0] * s[0] + r[1] * s[1] + r[2] * s[2];
    const perp = Math.sqrt(Math.max(0, r[0] * r[0] + r[1] * r[1] + r[2] * r[2] - dot * dot));
    const sunlit = dot >= 0 || perp > 6371;
    return { az: look.azimuth, el: look.elevation, sunlit, darkSky: sunAlt < -6 * rad };
  }

  function updateTrail(now) {
    if (now - trailComputed < 5000) return;
    trailComputed = now;
    trail = [];
    for (let s = -120; s <= 360; s += 20) {
      const p = issNow(new Date(now + s * 1000));
      if (p) trail.push(p);
    }
  }

  function computeNextPass() {
    nextPassText = '';
    const res = ISS.computePasses(opts.tle.l1, opts.tle.l2, opts.lat, opts.lng, new Date(), 24);
    if (res.passes) {
      const vis = res.passes.find((p) => p.visibleFrom);
      if (vis) {
        nextPassText = 'Nächster sichtbarer Überflug: ' + opts.fmtRange(vis.visibleFrom, vis.visibleTo) +
          ' (max. ' + Math.round(vis.maxEl / rad) + '°)';
      } else {
        nextPassText = 'In den nächsten 24 h kein sichtbarer Überflug.';
      }
    }
  }

  // Tagesbahnen von Sonne und Mond (±12 h um jetzt), mit Stunden-Markierungen
  function buildDayPaths() {
    sunPath = [];
    moonPath = [];
    const base = new Date();
    base.setMinutes(0, 0, 0); // an voller Stunde ausrichten, damit Labels "glatt" sind
    for (let m = -720; m <= 780; m += 15) {
      const t = new Date(base.valueOf() + m * 60000);
      const isHour = t.getMinutes() === 0 && (t.getHours() % 2 === 0);
      const label = isHour ? opts.fmtTime(t) : null;
      const s = Astro.getSunPosition(t, opts.lat, opts.lng);
      sunPath.push({ az: s.azimuth, alt: s.altitude, label });
      const mo = Astro.getMoonPosition(t, opts.lat, opts.lng);
      moonPath.push({ az: mo.azimuth, alt: mo.altitude, label });
    }
  }

  // ---------- Zeichnen ----------

  function drawLabel(text, px, py, color, font) {
    ctx.font = font || '14px system-ui, sans-serif';
    ctx.textAlign = 'center';
    ctx.fillStyle = 'rgba(13,27,42,0.75)';
    const wTxt = ctx.measureText(text).width;
    ctx.fillRect(px - wTxt / 2 - 5, py - 11, wTxt + 10, 20);
    ctx.fillStyle = color;
    ctx.fillText(text, px, py + 4);
  }

  // Pfeil am Bildrand in Richtung eines Objekts außerhalb des Sichtfelds.
  // radiusOffset staffelt mehrere Pfeile, damit sie sich nicht überdecken.
  function drawEdgeArrow(p, color, labelText, w, h, radiusOffset) {
    const ang = Math.atan2(-(p.y || 0), p.x || 1);
    const rr = Math.min(w, h) / 2 - 70 + (radiusOffset || 0);
    const ax = w / 2 + rr * Math.cos(ang);
    const ay = h / 2 + rr * Math.sin(ang);
    ctx.save();
    ctx.translate(ax, ay);
    ctx.rotate(ang);
    ctx.beginPath();
    ctx.moveTo(22, 0); ctx.lineTo(-8, -12); ctx.lineTo(-8, 12); ctx.closePath();
    ctx.fillStyle = color;
    ctx.fill();
    ctx.restore();
    drawLabel(labelText, ax, ay + 28, color);
  }

  // Tagesbahn als Punktkette mit Uhrzeit-Markierungen zeichnen
  function drawDayPath(path, b, w, h, fpx, color, labelColor) {
    ctx.fillStyle = color;
    for (const q of path) {
      if (q.alt < -0.05) continue;
      const p = project(q.az, q.alt, b, w, h, fpx);
      if (!p.visible) continue;
      ctx.beginPath();
      ctx.arc(p.px, p.py, 2, 0, 2 * Math.PI);
      ctx.fill();
      if (q.label) drawLabel(q.label, p.px, p.py - 14, labelColor, '11px system-ui');
      ctx.fillStyle = color;
    }
  }

  function render() {
    if (!active) return;
    const w = canvas.clientWidth, h = canvas.clientHeight;
    if (canvas.width !== w * devicePixelRatio) {
      canvas.width = w * devicePixelRatio;
      canvas.height = h * devicePixelRatio;
    }
    ctx.setTransform(devicePixelRatio, 0, 0, devicePixelRatio, 0, 0);
    ctx.clearRect(0, 0, w, h);

    const b = hasSensor && basis ? basis : manualBasis();
    const fpx = (h / 2) / Math.tan(FOV_V / 2);
    const now = Date.now();
    const nowDate = new Date(now);

    // Horizontlinie mit Himmelsrichtungen
    ctx.strokeStyle = 'rgba(154,190,235,0.8)';
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    let started = false;
    for (let a = 0; a <= 360; a += 3) {
      const p = project(a * rad, 0, b, w, h, fpx);
      if (p.visible) {
        if (started) ctx.lineTo(p.px, p.py); else { ctx.moveTo(p.px, p.py); started = true; }
      } else started = false;
    }
    ctx.stroke();
    [['N', 0], ['NO', 45], ['O', 90], ['SO', 135], ['S', 180], ['SW', 225], ['W', 270], ['NW', 315]]
      .forEach(([name, a]) => {
        const p = project(a * rad, 0, b, w, h, fpx);
        if (p.visible) drawLabel(name, p.px, p.py + 16, '#9abeeb', 'bold 13px system-ui');
      });

    // Milchstraßen-Band
    for (const q of Astro.getMilkyWayBand(nowDate, opts.lat, opts.lng)) {
      const p = project(q.azimuth, q.altitude, b, w, h, fpx);
      if (!p.visible) continue;
      const core = q.l <= 40 || q.l >= 320;
      ctx.beginPath();
      ctx.arc(p.px, p.py, core ? 3.5 : 2, 0, 2 * Math.PI);
      ctx.fillStyle = core ? 'rgba(217,200,255,0.95)' : 'rgba(183,148,255,0.55)';
      ctx.fill();
    }
    const gc = Astro.getGalacticCenterPosition(nowDate, opts.lat, opts.lng);
    const gp = project(gc.azimuth, gc.altitude, b, w, h, fpx);
    if (gp.visible) { ctx.font = '22px serif'; ctx.fillText('🌌', gp.px, gp.py); }

    // Sonne und Mond (im Sonne-&-Mond-Modus mit Tagesbahnen, Ringen und Pfeilen)
    const sunMoonFocus = opts.focus === 'sunmoon';
    if (sunMoonFocus) {
      drawDayPath(sunPath, b, w, h, fpx, 'rgba(255,209,102,0.55)', '#ffd166');
      drawDayPath(moonPath, b, w, h, fpx, 'rgba(106,183,255,0.55)', '#8ec9ff');
    }
    const sun = Astro.getSunPosition(nowDate, opts.lat, opts.lng);
    const sp = project(sun.azimuth, sun.altitude, b, w, h, fpx);
    if (sp.visible) {
      if (sunMoonFocus) {
        ctx.beginPath();
        ctx.arc(sp.px, sp.py, 28, 0, 2 * Math.PI);
        ctx.strokeStyle = '#ffd166';
        ctx.lineWidth = 2.5;
        ctx.stroke();
      }
      ctx.font = '30px serif'; ctx.fillText('☀️', sp.px, sp.py);
      drawLabel('Sonne ' + (sun.altitude / rad).toFixed(0) + '°', sp.px, sp.py + (sunMoonFocus ? 46 : 28), '#ffd166');
    } else if (sunMoonFocus) {
      drawEdgeArrow(sp, '#ffd166',
        '→ ☀️ (Az ' + ((sun.azimuth / rad + 360) % 360).toFixed(0) + '°, ' + (sun.altitude / rad).toFixed(0) + '°)', w, h);
    }
    const moon = Astro.getMoonPosition(nowDate, opts.lat, opts.lng);
    const mp = project(moon.azimuth, moon.altitude, b, w, h, fpx);
    if (mp.visible) {
      if (sunMoonFocus) {
        ctx.beginPath();
        ctx.arc(mp.px, mp.py, 26, 0, 2 * Math.PI);
        ctx.strokeStyle = '#8ec9ff';
        ctx.lineWidth = 2.5;
        ctx.stroke();
      }
      ctx.font = '28px serif'; ctx.fillText('🌙', mp.px, mp.py);
      drawLabel('Mond ' + (moon.altitude / rad).toFixed(0) + '°', mp.px, mp.py + (sunMoonFocus ? 44 : 26), '#8ec9ff');
    } else if (sunMoonFocus) {
      drawEdgeArrow(mp, '#8ec9ff',
        '→ 🌙 (Az ' + ((moon.azimuth / rad + 360) % 360).toFixed(0) + '°, ' + (moon.altitude / rad).toFixed(0) + '°)', w, h, -64);
    }

    const bottom = $('ar-bottom');
    if (opts.focus === 'iss') {
      // ISS: Bahnspur und aktuelle Position
      updateTrail(now);
      ctx.strokeStyle = 'rgba(255,120,120,0.7)';
      ctx.setLineDash([6, 5]);
      ctx.lineWidth = 2;
      ctx.beginPath();
      started = false;
      for (const q of trail) {
        const p = project(q.az, q.el, b, w, h, fpx);
        if (p.visible && q.el > -0.15) {
          if (started) ctx.lineTo(p.px, p.py); else { ctx.moveTo(p.px, p.py); started = true; }
        } else started = false;
      }
      ctx.stroke();
      ctx.setLineDash([]);

      const iss = issNow(nowDate);
      if (iss) {
        const ip = project(iss.az, iss.el, b, w, h, fpx);
        const state = iss.el > 0
          ? (iss.sunlit && iss.darkSky ? 'jetzt sichtbar!' : iss.sunlit ? 'über dem Horizont (Himmel zu hell)' : 'über dem Horizont, im Erdschatten')
          : 'unter dem Horizont';
        if (ip.visible) {
          ctx.beginPath();
          ctx.arc(ip.px, ip.py, 26, 0, 2 * Math.PI);
          ctx.strokeStyle = iss.el > 0 && iss.sunlit && iss.darkSky ? '#7cff9b' : '#ff7878';
          ctx.lineWidth = 2.5;
          ctx.stroke();
          ctx.font = '30px serif';
          ctx.fillText('🛰️', ip.px, ip.py + 4);
          drawLabel('ISS · ' + (iss.el / rad).toFixed(0) + '°', ip.px, ip.py + 44, '#ffffff', 'bold 14px system-ui');
        } else {
          drawEdgeArrow(ip, '#ff9e9e',
            '→ ISS (Az ' + ((iss.az / rad + 360) % 360).toFixed(0) + '°, ' + (iss.el / rad).toFixed(0) + '°)', w, h);
        }
        bottom.textContent = '🛰️ ISS ' + state +
          ' · Azimut ' + ((iss.az / rad + 360) % 360).toFixed(0) + '°, Höhe ' + (iss.el / rad).toFixed(0) + '°' +
          (nextPassText ? ' · ' + nextPassText : '');
      } else {
        bottom.textContent = 'ISS-Position konnte nicht berechnet werden.' + (nextPassText ? ' · ' + nextPassText : '');
      }
    } else {
      // Sonne-&-Mond-Modus: Statuszeile mit Auf-/Untergang und Mondphase
      const t = Astro.getSunTimes(nowDate, opts.lat, opts.lng);
      const illum = Astro.getMoonIllumination(nowDate);
      bottom.textContent =
        '☀️ Az ' + ((sun.azimuth / rad + 360) % 360).toFixed(0) + '°, Höhe ' + (sun.altitude / rad).toFixed(0) + '°' +
        ' · Auf ' + opts.fmtTime(t.sunrise) + ' / Unter ' + opts.fmtTime(t.sunset) +
        '  |  🌙 Az ' + ((moon.azimuth / rad + 360) % 360).toFixed(0) + '°, Höhe ' + (moon.altitude / rad).toFixed(0) + '°' +
        ' (' + Math.round(illum.fraction * 100) + ' % beleuchtet)';
    }

    // Blickrichtung oben anzeigen
    const vc = viewCenter(b);
    $('ar-center-info').textContent =
      (hasSensor ? '' : '👆 Wischen zum Umschauen · ') +
      'Blick: ' + vc.az.toFixed(0) + '° / ' + vc.alt.toFixed(0) + '°';

    rafId = requestAnimationFrame(render);
  }

  const $ = (id) => document.getElementById(id);

  // ---------- Öffnen / Schließen ----------

  function startSensors() {
    const attach = () => {
      if ('ondeviceorientationabsolute' in window) {
        window.addEventListener('deviceorientationabsolute', onOrient);
      }
      window.addEventListener('deviceorientation', onOrient);
    };
    if (typeof DeviceOrientationEvent !== 'undefined' &&
        typeof DeviceOrientationEvent.requestPermission === 'function') {
      DeviceOrientationEvent.requestPermission()
        .then((res) => { if (res === 'granted') attach(); })
        .catch(() => { /* Fallback: Wischen */ });
    } else if (typeof DeviceOrientationEvent !== 'undefined') {
      attach();
    }
  }

  function startCamera() {
    if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) return;
    navigator.mediaDevices.getUserMedia({ video: { facingMode: 'environment' }, audio: false })
      .then((s) => {
        stream = s;
        video.srcObject = s;
        video.hidden = false;
      })
      .catch(() => { video.hidden = true; /* dunkler Hintergrund reicht */ });
  }

  function initDrag() {
    let dragging = false, lx = 0, ly = 0;
    canvas.addEventListener('pointerdown', (e) => { dragging = true; lx = e.clientX; ly = e.clientY; canvas.setPointerCapture(e.pointerId); });
    canvas.addEventListener('pointermove', (e) => {
      if (!dragging) return;
      // Wischen übersteuert den Sensor (z. B. am Schreibtisch ausprobieren)
      hasSensor = false;
      yaw = (yaw + (e.clientX - lx) * 0.004 + 2 * Math.PI) % (2 * Math.PI);
      pitch = Math.max(-0.4, Math.min(1.45, pitch + (e.clientY - ly) * 0.004));
      lx = e.clientX; ly = e.clientY;
    });
    canvas.addEventListener('pointerup', () => { dragging = false; });
    canvas.addEventListener('pointercancel', () => { dragging = false; });
  }

  let dragInited = false;

  function open(options) {
    opts = options;
    opts.focus = opts.focus || 'iss';
    satrec = null;
    if (opts.focus === 'iss') {
      try {
        satrec = satellite.twoline2satrec(opts.tle.l1, opts.tle.l2);
      } catch (e) {
        return false;
      }
    }
    canvas = $('ar-canvas');
    ctx = canvas.getContext('2d');
    video = $('ar-video');
    $('ar-view').hidden = false;
    document.body.classList.add('ar-open');
    active = true;
    hasSensor = false;
    trailComputed = 0;
    if (!dragInited) { initDrag(); dragInited = true; }
    startSensors();
    startCamera();
    nextPassText = '';
    if (opts.focus === 'iss') computeNextPass();
    else buildDayPaths();
    render();
    return true;
  }

  function close() {
    active = false;
    if (rafId) cancelAnimationFrame(rafId);
    window.removeEventListener('deviceorientationabsolute', onOrient);
    window.removeEventListener('deviceorientation', onOrient);
    if (stream) {
      stream.getTracks().forEach((t) => t.stop());
      stream = null;
      video.srcObject = null;
    }
    $('ar-view').hidden = true;
    document.body.classList.remove('ar-open');
  }

  global.AR = { open, close };
})(typeof window !== 'undefined' ? window : globalThis);
