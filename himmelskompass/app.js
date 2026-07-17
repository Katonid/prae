/* Himmelskompass – App-Logik */
(function () {
  'use strict';

  // ---------- Zustand ----------
  const state = {
    lat: 52.52,          // Fallback: Berlin
    lng: 13.405,
    tz: Intl.DateTimeFormat().resolvedOptions().timeZone, // Zeitzone des Ortes
    day: null,           // ausgewählter Kalendertag {y, m, d} in der Orts-Zeitzone
    sliderMinutes: null, // Uhrzeit für den Kompass (Minuten seit Mitternacht, Ortszeit)
    live: true,          // Kompass folgt der aktuellen Uhrzeit
    heading: 0,          // Kompassdrehung (Grad)
    tilt: 62,            // Kippwinkel der 3D-Ansicht (Grad)
    deviceOrientation: false
  };

  const $ = (id) => document.getElementById(id);

  // ---------- Hilfsfunktionen ----------
  const deg = (r) => r * 180 / Math.PI;

  function fmtTime(d) {
    if (!d || isNaN(d)) return '–';
    return d.toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit', timeZone: state.tz });
  }
  function fmtRange(a, b) {
    if (!a || !b) return '–';
    return fmtTime(a) + ' – ' + fmtTime(b);
  }
  function fmtDateTime(d) {
    if (!d) return '–';
    return d.toLocaleDateString('de-DE', { day: '2-digit', month: '2-digit', timeZone: state.tz }) + ' ' + fmtTime(d);
  }
  function fmtDuration(ms) {
    if (ms == null || isNaN(ms) || ms < 0) return '–';
    const min = Math.round(ms / 60000);
    return Math.floor(min / 60) + ' h ' + String(min % 60).padStart(2, '0') + ' min';
  }

  const DIRECTIONS = ['N', 'NNO', 'NO', 'ONO', 'O', 'OSO', 'SO', 'SSO',
    'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW'];
  function dirName(azDeg) {
    return DIRECTIONS[Math.round(azDeg / 22.5) % 16];
  }

  // ---------- Zeitzone des Ortes ----------

  function updateTimezone() {
    try {
      state.tz = tzlookup(state.lat, state.lng);
    } catch (e) {
      state.tz = Intl.DateTimeFormat().resolvedOptions().timeZone;
    }
  }

  // Datum/Uhrzeit eines Zeitpunkts, ausgedrückt in der Orts-Zeitzone
  function tzParts(date) {
    const parts = new Intl.DateTimeFormat('en-CA', {
      timeZone: state.tz, year: 'numeric', month: '2-digit', day: '2-digit',
      hour: '2-digit', minute: '2-digit', hourCycle: 'h23'
    }).formatToParts(date);
    const get = (k) => Number(parts.find((p) => p.type === k).value);
    return { y: get('year'), m: get('month'), d: get('day'), hh: get('hour'), mm: get('minute') };
  }

  // Date-Objekt für "y-m-d hh:mm" in der Orts-Zeitzone
  function dateInTz(y, m, d, hh, mm) {
    let t = Date.UTC(y, m - 1, d, hh, mm);
    // zweifache Korrektur, damit auch Zeitumstellungen richtig getroffen werden
    for (let i = 0; i < 2; i++) {
      const p = tzParts(new Date(t));
      t += Date.UTC(y, m - 1, d, hh, mm) - Date.UTC(p.y, p.m - 1, p.d, p.hh, p.mm);
    }
    return new Date(t);
  }

  function tzLabel() {
    // Offset für den gewählten Tag bestimmen (Sommer-/Winterzeit)
    const ref = state.day ? dateAtMinutes(12 * 60) : new Date();
    const offset = new Intl.DateTimeFormat('de-DE', { timeZone: state.tz, timeZoneName: 'shortOffset' })
      .formatToParts(ref).find((p) => p.type === 'timeZoneName');
    return state.tz.replace(/_/g, ' ') + (offset ? ', ' + offset.value : '');
  }

  // Gewählter Tag mit gegebener Uhrzeit (Minuten seit Mitternacht, Ortszeit)
  function dateAtMinutes(minutes) {
    return dateInTz(state.day.y, state.day.m, state.day.d, 0, minutes);
  }

  function selectedIsToday() {
    const p = tzParts(new Date());
    return p.y === state.day.y && p.m === state.day.m && p.d === state.day.d;
  }

  // ---------- Karte ----------
  let map, marker;

  function initMap() {
    if (typeof L === 'undefined') {
      $('map').textContent = 'Karte konnte nicht geladen werden.';
      return;
    }
    map = L.map('map', { zoomControl: true }).setView([state.lat, state.lng], 10);
    L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 19,
      attribution: '© OpenStreetMap'
    }).addTo(map);

    marker = L.marker([state.lat, state.lng], { draggable: true }).addTo(map);
    marker.on('dragend', () => {
      const p = marker.getLatLng();
      setLocation(p.lat, p.lng, false);
    });
    map.on('click', (ev) => {
      // Erster Tipp auf die kleine Karte öffnet das Vollbild;
      // im Vollbild setzt ein Tipp den Ort.
      if (!mapFullscreen) {
        setMapFullscreen(true);
        return;
      }
      setLocation(ev.latlng.lat, ev.latlng.lng, false);
    });
    map.on('zoomend', () => {
      drawMapOverlay();
      renderCompass(); // zeichnet auch die aktuellen Richtungslinien neu
    });

    $('map-close').addEventListener('click', () => setMapFullscreen(false));
    document.addEventListener('keydown', (ev) => {
      if (ev.key === 'Escape' && mapFullscreen) setMapFullscreen(false);
    });
  }

  let mapFullscreen = false;

  function setMapFullscreen(on) {
    mapFullscreen = on;
    document.body.classList.toggle('map-fullscreen', on);
    if (!map) return;
    // Nach der Größenänderung Kartengröße neu ermitteln und Overlay neu zeichnen
    requestAnimationFrame(() => {
      map.invalidateSize();
      map.setView([state.lat, state.lng], map.getZoom());
      drawMapOverlay();
      renderCompass();
    });
  }

  // ---------- Himmels-Overlay auf der Karte ----------
  let skyOverlay = null;     // Bahnen, Stunden und Auf-/Untergangslinien
  let currentLinesLayer = null; // Linien zur aktuellen Sonnen-/Mondposition

  // Projektion der Himmelskuppel auf die Karte: fester Pixelradius um den Ort
  function mapProjection() {
    if (!map) return null;
    const center = L.latLng(state.lat, state.lng);
    const cpt = map.latLngToLayerPoint(center);
    const size = map.getSize();
    // Genug Rand lassen, damit die Zeit-Beschriftungen nicht abgeschnitten werden
    const radius = Math.max(70, Math.min(size.x, size.y) / 2 - 56);
    return {
      center,
      radius,
      project(az, alt) {
        const r = radius * Math.cos(alt);
        return map.layerPointToLatLng(
          L.point(cpt.x + r * Math.sin(az), cpt.y - r * Math.cos(az))
        );
      }
    };
  }

  function drawMapOverlay() {
    const proj = mapProjection();
    if (!proj) return;
    if (skyOverlay) skyOverlay.remove();
    skyOverlay = L.layerGroup().addTo(map);

    // Horizontkreis
    skyOverlay.addLayer(L.circleMarker(proj.center, {
      radius: proj.radius, color: '#5a7db8', weight: 1, dashArray: '4 4',
      fill: false, opacity: 0.5, interactive: false
    }));

    addPathToMap('sun', Astro.getSunPosition, '#ffd166', proj);
    addPathToMap('moon', Astro.getMoonPosition, '#6ab7ff', proj);

    const noon = dateAtMinutes(12 * 60);
    const st = Astro.getSunTimes(noon, state.lat, state.lng);
    const mt = Astro.getMoonTimes(dateAtMinutes(0), state.lat, state.lng);
    addRiseSetLine(st.sunrise, Astro.getSunPosition, '#ff9e00', '☀️↑', proj);
    addRiseSetLine(st.sunset, Astro.getSunPosition, '#ff5470', '☀️↓', proj);
    addRiseSetLine(mt.rise, Astro.getMoonPosition, '#8ec9ff', '🌙↑', proj);
    addRiseSetLine(mt.set, Astro.getMoonPosition, '#4a90d9', '🌙↓', proj);
  }

  // Bahn über dem Horizont als Linienzug, dazu Stundenpunkte mit Uhrzeit
  function addPathToMap(name, getPos, color, proj) {
    let seg = [];
    const flush = () => {
      if (seg.length > 1) {
        skyOverlay.addLayer(L.polyline(seg, {
          color, weight: 2.5, opacity: 0.85, interactive: false
        }));
      }
      seg = [];
    };
    for (let m = 0; m <= 1440; m += 10) {
      const p = getPos(dateAtMinutes(Math.min(m, 1439)), state.lat, state.lng);
      if (p.altitude >= 0) seg.push(proj.project(p.azimuth, p.altitude));
      else flush();
    }
    flush();

    for (let h = 0; h < 24; h++) {
      const p = getPos(dateAtMinutes(h * 60), state.lat, state.lng);
      if (p.altitude <= 0) continue;
      const dot = L.circleMarker(proj.project(p.azimuth, p.altitude), {
        radius: 3, color, fillColor: color, fillOpacity: 1, weight: 1, interactive: false
      });
      if (h % 3 === 0) {
        dot.bindTooltip(h + ' h', {
          permanent: true, direction: 'top', offset: [0, -4],
          className: 'map-time-tip ' + name
        });
      }
      skyOverlay.addLayer(dot);
    }
  }

  // Beschriftung am Horizontrand nach innen ausrichten, damit nichts abgeschnitten wird
  function tipDirection(az) {
    const x = Math.sin(az);
    const y = -Math.cos(az); // Bildschirm-y: negativ = oben
    if (Math.abs(x) > Math.abs(y)) return x > 0 ? 'left' : 'right';
    return y < 0 ? 'bottom' : 'top';
  }
  const tipOffsets = { top: [0, -4], bottom: [0, 4], left: [-6, 0], right: [6, 0] };

  // Gestrichelte Richtungslinie zum Auf- bzw. Untergangspunkt mit Uhrzeit
  function addRiseSetLine(time, getPos, color, label, proj) {
    if (!time) return;
    const az = getPos(time, state.lat, state.lng).azimuth;
    const end = proj.project(az, 0);
    const dir = tipDirection(az);
    skyOverlay.addLayer(L.polyline([proj.center, end], {
      color, weight: 2, dashArray: '6 4', opacity: 0.9, interactive: false
    }));
    skyOverlay.addLayer(
      L.circleMarker(end, { radius: 2, color, fillColor: color, fillOpacity: 1, interactive: false })
        .bindTooltip(label + ' ' + fmtTime(time), {
          permanent: true, direction: dir, offset: tipOffsets[dir], className: 'map-time-tip'
        })
    );
  }

  // Aktuelle Richtungslinien zu Sonne/Mond und die Lage des Milchstraßen-Bands
  // zur eingestellten Uhrzeit
  function updateMapCurrentLines(sun, moon) {
    const proj = mapProjection();
    if (!proj) return;
    if (currentLinesLayer) currentLinesLayer.remove();
    currentLinesLayer = L.layerGroup().addTo(map);
    [[sun, '#ffd166'], [moon, '#6ab7ff']].forEach(([pos, color]) => {
      const up = pos.altitude >= 0;
      currentLinesLayer.addLayer(L.polyline(
        [proj.center, proj.project(pos.azimuth, pos.altitude)],
        { color, weight: 3, opacity: up ? 0.9 : 0.3, interactive: false }
      ));
    });

    // Milchstraßen-Band: nur der Teil über dem Horizont
    const band = Astro.getMilkyWayBand(compassDate(), state.lat, state.lng);
    band.push(band[0]); // Ring schließen
    let seg = [];
    const flush = () => {
      if (seg.length > 1) {
        currentLinesLayer.addLayer(L.polyline(seg, {
          color: '#b794ff', weight: 2, opacity: 0.7, dashArray: '2 6', interactive: false
        }));
      }
      seg = [];
    };
    for (const p of band) {
      if (p.altitude >= 0) seg.push(proj.project(p.azimuth, p.altitude));
      else flush();
    }
    flush();
  }

  function setLocation(lat, lng, panTo) {
    state.lat = lat;
    state.lng = ((lng + 180) % 360 + 360) % 360 - 180; // auf -180..180 normalisieren
    if (marker) marker.setLatLng([state.lat, state.lng]);
    if (panTo && map) map.setView([state.lat, state.lng], Math.max(map.getZoom(), 10));
    updateTimezone();
    // "Jetzt" bedeutet in der neuen Zeitzone eine andere Uhrzeit
    if (state.live && selectedIsToday()) setSliderToNow();
    updateLocationLabel();
    renderAll();
  }

  function updateLocationLabel() {
    const el = $('location-label');
    const coords = state.lat.toFixed(4) + '°, ' + state.lng.toFixed(4) + '°';
    el.textContent = '📍 ' + coords + ' · 🕐 ' + tzLabel();
    // Ortsname per Reverse-Geocoding (optional, scheitert offline still)
    const url = 'https://nominatim.openstreetmap.org/reverse?format=jsonv2&zoom=10' +
      '&lat=' + state.lat + '&lon=' + state.lng;
    fetch(url, { headers: { 'Accept-Language': 'de' } })
      .then((r) => r.ok ? r.json() : null)
      .then((j) => {
        if (!j) return;
        const a = j.address || {};
        const name = a.city || a.town || a.village || a.municipality || a.county || j.name;
        if (name) {
          el.textContent = '📍 ' + name + (a.country ? ', ' + a.country : '') +
            ' (' + coords + ') · 🕐 ' + tzLabel();
        }
      })
      .catch(() => { /* offline oder blockiert – Koordinaten reichen */ });
  }

  function locate() {
    if (!navigator.geolocation) return;
    $('location-label').textContent = 'Standort wird ermittelt …';
    navigator.geolocation.getCurrentPosition(
      (pos) => setLocation(pos.coords.latitude, pos.coords.longitude, true),
      () => {
        updateLocationLabel();
        renderAll();
      },
      { enableHighAccuracy: false, timeout: 10000, maximumAge: 300000 }
    );
  }

  // ---------- Sonne ----------
  function renderSun() {
    const noon = dateAtMinutes(12 * 60);
    const t = Astro.getSunTimes(noon, state.lat, state.lng);

    $('sunrise-big').textContent = fmtTime(t.sunrise);
    $('sunset-big').textContent = fmtTime(t.sunset);
    $('daylength').textContent = (t.sunrise && t.sunset)
      ? fmtDuration(t.sunset - t.sunrise)
      : polarDayLabel(noon);

    $('t-nightEnd').textContent = fmtTime(t.nightEnd);
    $('t-nauticalDawn').textContent = fmtTime(t.nauticalDawn);
    $('t-dawn').textContent = fmtTime(t.dawn);
    $('t-blueMorning').textContent = fmtRange(t.blueHourDawnStart, t.blueHourDawnEnd);
    $('t-goldenMorning').textContent = fmtRange(t.blueHourDawnEnd, t.goldenHourDawnEnd);
    $('t-sunrise').textContent = fmtTime(t.sunrise);

    $('t-sunset').textContent = fmtTime(t.sunset);
    $('t-goldenEvening').textContent = fmtRange(t.goldenHourDuskStart, t.blueHourDuskStart);
    $('t-blueEvening').textContent = fmtRange(t.blueHourDuskStart, t.blueHourDuskEnd);
    $('t-dusk').textContent = fmtTime(t.dusk);
    $('t-nauticalDusk').textContent = fmtTime(t.nauticalDusk);
    $('t-night').textContent = fmtTime(t.night);
    $('t-solarNoon').textContent = fmtTime(t.solarNoon);
    $('tz-label').textContent = tzLabel();

    renderTimeline();
  }

  function polarDayLabel(noon) {
    const alt = Astro.getSunPosition(noon, state.lat, state.lng).altitude;
    return alt > 0 ? 'Polartag' : 'Polarnacht';
  }

  // Tagesverlauf-Balken: Sonnenhöhe alle 10 Minuten klassifizieren
  function renderTimeline() {
    const el = $('day-timeline');
    el.innerHTML = '';
    const classes = [];
    for (let m = 0; m < 1440; m += 10) {
      const alt = deg(Astro.getSunPosition(dateAtMinutes(m + 5), state.lat, state.lng).altitude);
      classes.push(
        alt < -18 ? 'night' :
        alt < -12 ? 'astro' :
        alt < -8 ? 'naut' :
        alt < -4 ? 'blue' :
        alt < 6 ? 'golden' : 'day'
      );
    }
    const colors = {
      night: 'var(--c-night)', astro: 'var(--c-astro)', naut: 'var(--c-naut)',
      blue: 'var(--c-blue)', golden: 'var(--c-golden)', day: 'var(--c-day)'
    };
    let start = 0;
    for (let i = 1; i <= classes.length; i++) {
      if (i === classes.length || classes[i] !== classes[start]) {
        const seg = document.createElement('div');
        seg.className = 'seg';
        seg.style.flex = String(i - start);
        seg.style.background = colors[classes[start]];
        el.appendChild(seg);
        start = i;
      }
    }
    if (selectedIsToday()) {
      const p = tzParts(new Date());
      const nm = document.createElement('div');
      nm.className = 'now-marker';
      nm.style.left = ((p.hh * 60 + p.mm) / 1440 * 100) + '%';
      nm.title = 'Jetzt';
      el.appendChild(nm);
    }
  }

  // ---------- Mond ----------
  function renderMoon() {
    const noon = dateAtMinutes(12 * 60);
    const times = Astro.getMoonTimes(dateAtMinutes(0), state.lat, state.lng);
    const illum = Astro.getMoonIllumination(noon);
    const pos = Astro.getMoonPosition(noon, state.lat, state.lng);

    $('m-rise').textContent = times.alwaysUp ? 'ganztägig sichtbar'
      : times.alwaysDown ? 'nicht sichtbar'
      : fmtTime(times.rise) + (times.rise ? '' : ' (kein Aufgang)');
    $('m-set').textContent = times.alwaysUp ? '–'
      : times.alwaysDown ? '–'
      : fmtTime(times.set) + (times.set ? '' : ' (kein Untergang)');
    $('m-dist').textContent = Math.round(pos.distance).toLocaleString('de-DE') + ' km';
    $('moon-phase-name').textContent = Astro.moonPhaseName(illum.phase);
    $('moon-illum').textContent = Math.round(illum.fraction * 100) + ' % beleuchtet';

    $('m-fullmoon').textContent = fmtDateTime(findNextPhase(noon, 0.5));
    $('m-newmoon').textContent = fmtDateTime(findNextPhase(noon, 0));

    drawMoon(illum.phase);
  }

  // Nächstes Auftreten einer Zielphase (0 = Neumond, 0.5 = Vollmond), stundenweise gesucht
  function findNextPhase(from, target) {
    let prev = Astro.getMoonIllumination(from).phase;
    for (let h = 1; h <= 31 * 24; h++) {
      const d = new Date(from.valueOf() + h * 3600000);
      const p = Astro.getMoonIllumination(d).phase;
      const crossed = target === 0.5
        ? (prev < 0.5 && p >= 0.5)
        : (p < prev); // Phasensprung 1 → 0 = Neumond
      if (crossed) return d;
      prev = p;
    }
    return null;
  }

  function drawMoon(phase) {
    const canvas = $('moon-canvas');
    const ctx = canvas.getContext('2d');
    const w = canvas.width, h = canvas.height;
    const cx = w / 2, cy = h / 2, r = w / 2 - 6;
    ctx.clearRect(0, 0, w, h);

    // dunkle Mondscheibe
    ctx.beginPath();
    ctx.arc(cx, cy, r, 0, 2 * Math.PI);
    ctx.fillStyle = '#232b3a';
    ctx.fill();
    ctx.strokeStyle = '#3a4a63';
    ctx.lineWidth = 1.5;
    ctx.stroke();

    const waxing = phase <= 0.5;
    const semiX = r * Math.cos(2 * Math.PI * phase); // Terminator-Halbachse

    // beleuchtete Hälfte (rechts bei zunehmendem, links bei abnehmendem Mond)
    ctx.save();
    ctx.beginPath();
    ctx.arc(cx, cy, r, -Math.PI / 2, Math.PI / 2, !waxing);
    ctx.closePath();
    ctx.fillStyle = '#f5f0dc';
    ctx.fill();

    // Terminator-Ellipse: hell bei "gibbous", dunkel bei Sichel
    ctx.beginPath();
    ctx.ellipse(cx, cy, Math.abs(semiX), r, 0, 0, 2 * Math.PI);
    ctx.fillStyle = semiX < 0 ? '#f5f0dc' : '#232b3a';
    ctx.fill();
    ctx.restore();

    // dezente "Krater" nur auf der hellen Fläche andeuten
    ctx.save();
    ctx.globalAlpha = 0.12;
    ctx.fillStyle = '#8d8468';
    [[-0.3, -0.25, 0.16], [0.25, 0.1, 0.11], [-0.05, 0.35, 0.09], [0.4, -0.35, 0.07]]
      .forEach(([dx, dy, dr]) => {
        ctx.beginPath();
        ctx.arc(cx + dx * r, cy + dy * r, dr * r, 0, 2 * Math.PI);
        ctx.fill();
      });
    ctx.restore();
  }

  // ---------- Milchstraße ----------
  // Sichtbarkeit des hellen Zentrums in der Nacht, die am gewählten Tag beginnt:
  // astronomische Nacht (Sonne < −18°), Zentrum ausreichend hoch, möglichst mondfrei.
  function renderMilkyWay() {
    const start = dateAtMinutes(12 * 60); // Scan von Mittag bis Mittag des Folgetags
    const stepMin = 5;
    const samples = [];
    for (let i = 0; i <= (24 * 60) / stepMin; i++) {
      const t = new Date(start.valueOf() + i * stepMin * 60000);
      const gc = Astro.getGalacticCenterPosition(t, state.lat, state.lng);
      samples.push({
        t,
        sunAlt: deg(Astro.getSunPosition(t, state.lat, state.lng).altitude),
        gcAlt: deg(gc.altitude),
        gcAz: deg(gc.azimuth),
        moonAlt: deg(Astro.getMoonPosition(t, state.lat, state.lng).altitude)
      });
    }
    const moonFrac = Astro.getMoonIllumination(dateAtMinutes(24 * 60)).fraction;
    const moonPct = Math.round(moonFrac * 100);
    const moonOk = (s) => s.moonAlt < 0 || moonFrac < 0.2;

    const dark = samples.filter((s) => s.sunAlt < -18);
    const visible = samples.filter((s) => s.sunAlt < -18 && s.gcAlt > 3);
    const clear = visible.filter(moonOk);

    const statusEl = $('mw-status');
    statusEl.className = 'mw-status';

    if (dark.length === 0) {
      statusEl.textContent = 'In dieser Nacht wird es nicht astronomisch dunkel – die Milchstraße ist praktisch nicht sichtbar.';
      statusEl.classList.add('bad');
      $('mw-window').textContent = '–';
      $('mw-best').textContent = '–';
      $('mw-dir').textContent = '–';
      $('mw-moon').textContent = '–';
      return;
    }
    if (visible.length === 0) {
      statusEl.textContent = 'Das galaktische Zentrum steht während der dunklen Stunden unter dem Horizont – das helle Band der Milchstraße ist nicht zu sehen.';
      statusEl.classList.add('bad');
      $('mw-window').textContent = '–';
      $('mw-best').textContent = '–';
      $('mw-dir').textContent = '–';
      $('mw-moon').textContent = 'Dunkel von ' + fmtRange(dark[0].t, dark[dark.length - 1].t);
      return;
    }

    $('mw-window').textContent = intervalsToText(visible, stepMin);

    const bestPool = clear.length > 0 ? clear : visible;
    const best = bestPool.reduce((a, b) => (b.gcAlt > a.gcAlt ? b : a));
    $('mw-best').textContent = fmtTime(best.t);
    $('mw-dir').textContent = dirName(best.gcAz) + ' (Azimut ' + best.gcAz.toFixed(0) +
      '°) · Höhe ' + best.gcAlt.toFixed(0) + '°';

    const disturbed = visible.filter((s) => !moonOk(s));
    if (disturbed.length === 0) {
      $('mw-moon').textContent = 'stört nicht (' + moonPct + ' % beleuchtet)';
    } else if (clear.length === 0) {
      $('mw-moon').textContent = 'stört die ganze Zeit (' + moonPct + ' % beleuchtet, über dem Horizont)';
    } else {
      $('mw-moon').textContent = 'stört ' + intervalsToText(disturbed, stepMin) + ' (' + moonPct + ' %)';
    }

    if (clear.length * stepMin >= 30 && best.gcAlt >= 10) {
      statusEl.textContent = 'Gute Bedingungen: Das Milchstraßenzentrum ist bei dunklem Himmel sichtbar.';
      statusEl.classList.add('good');
    } else if (clear.length > 0) {
      statusEl.textContent = 'Sichtbar, aber eingeschränkt – das Zentrum steht tief oder das mondfreie Fenster ist kurz.';
      statusEl.classList.add('ok');
    } else {
      statusEl.textContent = 'Das Zentrum steht zwar am Himmel, aber der Mond hellt die Nacht auf.';
      statusEl.classList.add('ok');
    }
  }

  // zusammenhängende Zeitfenster aus einer Sample-Liste ableiten, z. B. "23:40 – 03:05"
  function intervalsToText(samples, stepMin) {
    const out = [];
    let runStart = null, prev = null;
    for (const s of samples) {
      if (prev && s.t - prev.t > stepMin * 60000 * 1.5) {
        out.push(fmtRange(runStart.t, prev.t));
        runStart = null;
      }
      if (!runStart) runStart = s;
      prev = s;
    }
    if (runStart) out.push(fmtRange(runStart.t, prev.t));
    return out.join(' und ');
  }

  // ---------- 3D-Kompass ----------
  const R = 140; // Radius des Horizonts in px (Hälfte von 280)

  // Position am Himmel → Koordinaten in der Kompass-Ebene (x, y) plus Höhe (z)
  function skyXYZ(pos) {
    return [
      R * Math.cos(pos.altitude) * Math.sin(pos.azimuth),
      -R * Math.cos(pos.altitude) * Math.cos(pos.azimuth),
      R * Math.sin(pos.altitude)
    ];
  }

  // Tagesbahnen von Sonne und Mond als Punktketten mit Stunden-Beschriftung
  function buildCompassPaths() {
    buildCompassPath('sun', Astro.getSunPosition);
    buildCompassPath('moon', Astro.getMoonPosition);
    buildMilkyWayBand();
    updatePathBillboards();
  }

  // Milchstraßen-Band: feste Punktmenge, deren Positionen sich mit der Uhrzeit ändern
  function buildMilkyWayBand() {
    const cont = $('mw-band');
    if (cont.childElementCount) return; // Punkte existieren schon, nur Positionen ändern sich
    for (let i = 0; i < 90; i++) {
      const dot = document.createElement('div');
      dot.className = 'mw-dot';
      cont.appendChild(dot);
    }
  }

  function placeMilkyWayBand(band) {
    const dots = $('mw-band').children;
    for (let i = 0; i < band.length && i < dots.length; i++) {
      const p = band[i];
      const [x, y, z] = skyXYZ(p);
      const dot = dots[i];
      // Kernbereich um das galaktische Zentrum (±40° galaktische Länge) heller
      const core = p.l <= 40 || p.l >= 320;
      dot.className = 'mw-dot' + (core ? ' core' : '') + (p.altitude < 0 ? ' below' : '');
      dot.style.transform = 'translate3d(' + x + 'px,' + y + 'px,' + z + 'px) translate(-50%,-50%)';
    }
  }

  function buildCompassPath(name, getPos) {
    const cont = $(name + '-path');
    cont.innerHTML = '';
    for (let m = 0; m < 1440; m += 15) {
      const p = getPos(dateAtMinutes(m), state.lat, state.lng);
      const [x, y, z] = skyXYZ(p);
      const dot = document.createElement('div');
      dot.className = 'path-dot ' + name + (p.altitude < 0 ? ' below' : '') +
        (m % 60 === 0 ? ' hour' : '');
      dot.style.transform = 'translate3d(' + x + 'px,' + y + 'px,' + z + 'px) translate(-50%,-50%)';
      cont.appendChild(dot);
    }
    for (let h = 0; h < 24; h += 2) {
      const p = getPos(dateAtMinutes(h * 60), state.lat, state.lng);
      if (p.altitude <= 0.02) continue; // nur über dem Horizont beschriften
      const [x, y, z] = skyXYZ(p);
      const lab = document.createElement('div');
      lab.className = 'path-label ' + name;
      lab.textContent = h + ' h';
      lab.dataset.x = x;
      lab.dataset.y = y;
      lab.dataset.z = z;
      cont.appendChild(lab);
    }
  }

  // Stunden-Beschriftungen zum Betrachter drehen (abhängig von Drehung/Kippung)
  function updatePathBillboards() {
    const bb = ' rotateZ(' + state.heading + 'deg) rotateX(' + -state.tilt + 'deg)';
    document.querySelectorAll('.path-label').forEach((el) => {
      // Sonnen-Labels über, Mond-Labels unter der Bahn – vermeidet Überlappungen
      const off = el.classList.contains('moon') ? ' translate(-50%,45%)' : ' translate(-50%,-145%)';
      el.style.transform = 'translate3d(' + el.dataset.x + 'px,' + el.dataset.y + 'px,' + el.dataset.z + 'px)' + bb + off;
    });
  }

  function compassDate() {
    return dateAtMinutes(state.sliderMinutes);
  }

  let lastSun = null, lastMoon = null, lastGc = null; // für schnelle View-Updates

  function renderCompass() {
    const d = compassDate();
    const sun = Astro.getSunPosition(d, state.lat, state.lng);
    const moon = Astro.getMoonPosition(d, state.lat, state.lng);
    const gc = Astro.getGalacticCenterPosition(d, state.lat, state.lng);
    lastSun = sun;
    lastMoon = moon;
    lastGc = gc;

    placeBody('sun', sun);
    placeBody('moon', moon);
    placeBody('gc', gc);
    placeMilkyWayBand(Astro.getMilkyWayBand(d, state.lat, state.lng));

    $('sun-azalt').textContent = bodyText(sun);
    $('moon-azalt').textContent = bodyText(moon);
    $('sun-state').textContent = sun.altitude >= 0 ? 'über dem Horizont' : 'unter dem Horizont';
    $('moon-state').textContent = moon.altitude >= 0 ? 'über dem Horizont' : 'unter dem Horizont';

    $('time-slider-label').textContent = fmtTime(d) + ' Uhr';
    applySceneTransform();
    placeCardinals();
    updatePathBillboards();
    updateMapCurrentLines(sun, moon);
  }

  function bodyText(pos) {
    const az = deg(pos.azimuth);
    return 'Azimut ' + az.toFixed(0) + '° (' + dirName(az) + ') · Höhe ' + deg(pos.altitude).toFixed(1) + '°';
  }

  function placeBody(name, pos) {
    const group = $(name + '-group');
    const markerEl = $(name + '-marker');
    const lineEl = $(name + '-line');

    // Projektion: Azimut 0° = Nord (oben), Höhe hebt den Marker aus der Ebene
    const [x, y, z] = skyXYZ(pos);

    group.style.transform = 'translate3d(' + x + 'px,' + y + 'px,0)';

    lineEl.style.height = Math.abs(z) + 'px';
    // rotateX(-90°) stellt die Linie senkrecht nach oben (+z), +90° nach unten
    lineEl.style.transform = 'translateX(-1px) rotateX(' + (z >= 0 ? -90 : 90) + 'deg)';

    markerEl.classList.toggle('below', pos.altitude < 0);
    // Marker auf Höhe z heben und zum Betrachter drehen (Billboard)
    markerEl.style.transform =
      'translate(-50%,-50%) translateZ(' + z + 'px)' +
      ' rotateZ(' + state.heading + 'deg) rotateX(' + -state.tilt + 'deg)';
  }

  function placeCardinals() {
    const bb = ' rotateZ(' + state.heading + 'deg) rotateX(' + -state.tilt + 'deg)';
    const put = (cls, azDeg, radius) => {
      const el = document.querySelector('.' + cls);
      if (!el) return;
      const a = azDeg * Math.PI / 180;
      const x = radius * Math.sin(a);
      const y = -radius * Math.cos(a);
      el.style.transform = 'translate(-50%,-50%) translate3d(' + x + 'px,' + y + 'px,4px)' + bb;
    };
    put('cardinal.n', 0, R - 14);
    put('cardinal.e', 90, R - 14);
    put('cardinal.s', 180, R - 14);
    put('cardinal.w', 270, R - 14);
    put('cardinal-minor.ne', 45, R - 14);
    put('cardinal-minor.se', 135, R - 14);
    put('cardinal-minor.sw2', 225, R - 14);
    put('cardinal-minor.nw', 315, R - 14);
  }

  function applySceneTransform() {
    $('compass-tilt').style.transform = 'rotateX(' + state.tilt + 'deg)';
    $('compass-plane').style.transform = 'rotateZ(' + -state.heading + 'deg)';
  }

  // Leichtes View-Update ohne Astro-Neuberechnung – für Drag und Sensor-Events.
  // Über requestAnimationFrame gedrosselt, da Sensoren mit ~60 Hz feuern.
  let viewUpdatePending = false;
  function scheduleViewUpdate() {
    if (viewUpdatePending) return;
    viewUpdatePending = true;
    requestAnimationFrame(() => {
      viewUpdatePending = false;
      applySceneTransform();
      placeCardinals();
      updatePathBillboards();
      if (lastSun) placeBody('sun', lastSun);
      if (lastMoon) placeBody('moon', lastMoon);
      if (lastGc) placeBody('gc', lastGc);
    });
  }

  // Drehen/Kippen per Zeiger (Maus oder Finger)
  function initCompassDrag() {
    const scene = $('compass-scene');
    let dragging = false, lastX = 0, lastY = 0;

    scene.addEventListener('pointerdown', (ev) => {
      dragging = true;
      lastX = ev.clientX;
      lastY = ev.clientY;
      scene.setPointerCapture(ev.pointerId);
    });
    scene.addEventListener('pointermove', (ev) => {
      if (!dragging) return;
      state.heading = (state.heading + (ev.clientX - lastX) * 0.5 + 360) % 360;
      state.tilt = Math.min(85, Math.max(15, state.tilt - (ev.clientY - lastY) * 0.3));
      lastX = ev.clientX;
      lastY = ev.clientY;
      if (state.deviceOrientation) stopDeviceOrientation(); // manuelles Drehen beendet Sensor-Modus
      scheduleViewUpdate();
    });
    const stop = () => { dragging = false; };
    scene.addEventListener('pointerup', stop);
    scene.addEventListener('pointercancel', stop);
  }

  // ---------- Kopplung an den Gerätekompass ----------
  // Drehung folgt der Blickrichtung des Geräts, die Kippung der Geräteneigung:
  // flach gehalten → Draufsicht, hochkant Richtung Horizont → gekippte Ansicht.

  function screenAngle() {
    if (screen.orientation && typeof screen.orientation.angle === 'number') {
      return screen.orientation.angle;
    }
    return typeof window.orientation === 'number' ? window.orientation : 0;
  }

  // kürzester Weg zwischen zwei Winkeln, für ruckelfreie Glättung
  function angleLerp(a, b, t) {
    const d = ((b - a + 540) % 360) - 180;
    return (a + d * t + 360) % 360;
  }

  function onDeviceOrientation(ev) {
    if (!state.deviceOrientation) return;

    let heading = null;
    if (typeof ev.webkitCompassHeading === 'number') {
      heading = ev.webkitCompassHeading + screenAngle(); // iOS liefert echten Kompasswert
    } else if (typeof ev.alpha === 'number') {
      heading = 360 - ev.alpha + screenAngle();
    }

    // Neigung: im Hochformat steuert beta, im Querformat gamma
    let tiltRaw = null;
    const angle = screenAngle();
    if (angle === 90 || angle === -90 || angle === 270) {
      if (typeof ev.gamma === 'number') tiltRaw = Math.abs(ev.gamma);
    } else if (typeof ev.beta === 'number') {
      tiltRaw = Math.abs(ev.beta);
    }

    // Glättung gegen Sensor-Zittern
    if (heading != null) state.heading = angleLerp(state.heading, (heading + 360) % 360, 0.25);
    if (tiltRaw != null) {
      const target = Math.min(85, Math.max(5, tiltRaw));
      state.tilt = state.tilt + (target - state.tilt) * 0.25;
    }
    scheduleViewUpdate();
  }

  function startDeviceOrientation() {
    state.deviceOrientation = true;
    if ('ondeviceorientationabsolute' in window) {
      window.addEventListener('deviceorientationabsolute', onDeviceOrientation);
    } else {
      window.addEventListener('deviceorientation', onDeviceOrientation);
    }
    $('orient-btn').textContent = '📱 Kompass-Kopplung aktiv – tippen zum Beenden';
    $('orient-btn').classList.add('active');
  }

  function stopDeviceOrientation() {
    state.deviceOrientation = false;
    window.removeEventListener('deviceorientationabsolute', onDeviceOrientation);
    window.removeEventListener('deviceorientation', onDeviceOrientation);
    $('orient-btn').textContent = '📱 Am echten Kompass ausrichten';
    $('orient-btn').classList.remove('active');
  }

  function toggleDeviceOrientation() {
    const btn = $('orient-btn');
    if (state.deviceOrientation) {
      stopDeviceOrientation();
      return;
    }
    if (typeof DeviceOrientationEvent === 'undefined') {
      btn.textContent = '📱 Sensor nicht verfügbar';
      return;
    }
    if (typeof DeviceOrientationEvent.requestPermission === 'function') {
      // iOS: Sensorzugriff erfordert Nutzergeste + Berechtigung
      DeviceOrientationEvent.requestPermission()
        .then((res) => {
          if (res === 'granted') startDeviceOrientation();
          else btn.textContent = '📱 Sensor-Zugriff abgelehnt';
        })
        .catch(() => { btn.textContent = '📱 Sensor nicht verfügbar'; });
    } else {
      startDeviceOrientation();
    }
  }

  // Auf Geräten ohne Berechtigungspflicht (z. B. Android) automatisch koppeln,
  // sobald der Sensor tatsächlich Werte liefert. iOS verlangt eine Nutzergeste,
  // dort bleibt es beim Button.
  function tryAutoOrientation() {
    if (typeof DeviceOrientationEvent === 'undefined') return;
    if (typeof DeviceOrientationEvent.requestPermission === 'function') return;
    const probe = (ev) => {
      cleanup();
      if (ev.alpha != null && !state.deviceOrientation) startDeviceOrientation();
    };
    const cleanup = () => {
      window.removeEventListener('deviceorientationabsolute', probe);
      window.removeEventListener('deviceorientation', probe);
    };
    window.addEventListener('deviceorientationabsolute', probe);
    window.addEventListener('deviceorientation', probe);
    setTimeout(cleanup, 4000);
  }

  // ---------- Zeitraffer-Animation ----------
  // Spielt den Tagesverlauf ab: Sonne, Mond und Milchstraße wandern über den Himmel.
  let playTimer = null;

  function togglePlayback() {
    if (playTimer) {
      stopPlayback();
      return;
    }
    state.live = false;
    playTimer = setInterval(() => {
      state.sliderMinutes = (state.sliderMinutes + 4) % 1440;
      $('time-slider').value = String(state.sliderMinutes);
      renderCompass();
    }, 100);
    $('play-btn').textContent = '⏸';
    $('play-btn').classList.add('active');
  }

  function stopPlayback() {
    if (!playTimer) return;
    clearInterval(playTimer);
    playTimer = null;
    $('play-btn').textContent = '▶';
    $('play-btn').classList.remove('active');
  }

  // ---------- Rendering & Events ----------
  function renderAll() {
    renderSun();
    renderMoon();
    renderMilkyWay();
    buildCompassPaths();
    drawMapOverlay();
    renderCompass();
  }

  function setDateFromInput() {
    const v = $('date-input').value;
    if (!v) return;
    const [y, m, d] = v.split('-').map(Number);
    state.day = { y, m, d };
    // Bei "heute" folgt der Kompass wieder der aktuellen Zeit
    if (selectedIsToday() && state.live) {
      setSliderToNow();
    } else if (!selectedIsToday() && state.live) {
      state.sliderMinutes = 12 * 60;
      $('time-slider').value = String(state.sliderMinutes);
    }
    renderAll();
  }

  function setSliderToNow() {
    const p = tzParts(new Date());
    state.sliderMinutes = p.hh * 60 + p.mm;
    $('time-slider').value = String(state.sliderMinutes);
  }

  // Heutigen Tag (in der Orts-Zeitzone) auswählen und ins Eingabefeld schreiben
  function setDateToday() {
    const p = tzParts(new Date());
    state.day = { y: p.y, m: p.m, d: p.d };
    const pad = (n) => String(n).padStart(2, '0');
    $('date-input').value = p.y + '-' + pad(p.m) + '-' + pad(p.d);
  }

  function init() {
    // Datum: heute vorauswählen
    updateTimezone();
    setDateToday();
    setSliderToNow();

    initMap();
    initCompassDrag();
    updateLocationLabel();
    renderAll();
    locate(); // automatische Standortbestimmung
    tryAutoOrientation(); // Kompass-Kopplung, wo ohne Nachfrage möglich

    $('date-input').addEventListener('change', setDateFromInput);
    $('today-btn').addEventListener('click', () => {
      state.live = true;
      setDateToday();
      setSliderToNow();
      renderAll();
    });
    $('locate-btn').addEventListener('click', locate);
    $('time-slider').addEventListener('input', () => {
      stopPlayback();
      state.live = false;
      state.sliderMinutes = Number($('time-slider').value);
      renderCompass();
    });
    $('now-btn').addEventListener('click', () => {
      stopPlayback();
      state.live = true;
      setDateToday();
      setSliderToNow();
      renderAll();
    });
    $('play-btn').addEventListener('click', togglePlayback);
    $('orient-btn').addEventListener('click', toggleDeviceOrientation);

    // Minütlich aktualisieren, solange der Kompass "live" ist
    setInterval(() => {
      if (state.live && selectedIsToday()) {
        setSliderToNow();
        renderCompass();
        renderTimeline();
      }
    }, 60000);

    // Service Worker für Offline-Betrieb
    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.register('sw.js').catch(() => { /* z. B. file:// */ });
    }
  }

  document.addEventListener('DOMContentLoaded', init);
})();
