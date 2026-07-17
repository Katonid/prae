/* Himmelskompass – App-Logik */
(function () {
  'use strict';

  // ---------- Zustand ----------
  const state = {
    lat: 52.52,          // Fallback: Berlin
    lng: 13.405,
    date: new Date(),    // ausgewählter Kalendertag
    sliderMinutes: null, // Uhrzeit für den Kompass (Minuten seit Mitternacht)
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
    return d.toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' });
  }
  function fmtRange(a, b) {
    if (!a || !b) return '–';
    return fmtTime(a) + ' – ' + fmtTime(b);
  }
  function fmtDateTime(d) {
    if (!d) return '–';
    return d.toLocaleDateString('de-DE', { day: '2-digit', month: '2-digit' }) + ' ' + fmtTime(d);
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

  // Datum des gewählten Tages mit gegebener Uhrzeit (Minuten seit Mitternacht)
  function dateAtMinutes(minutes) {
    const d = new Date(state.date);
    d.setHours(0, minutes, 0, 0);
    return d;
  }

  function selectedIsToday() {
    const now = new Date();
    return state.date.getFullYear() === now.getFullYear() &&
      state.date.getMonth() === now.getMonth() &&
      state.date.getDate() === now.getDate();
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
      setLocation(ev.latlng.lat, ev.latlng.lng, false);
    });
  }

  function setLocation(lat, lng, panTo) {
    state.lat = lat;
    state.lng = ((lng + 180) % 360 + 360) % 360 - 180; // auf -180..180 normalisieren
    if (marker) marker.setLatLng([state.lat, state.lng]);
    if (panTo && map) map.setView([state.lat, state.lng], Math.max(map.getZoom(), 10));
    updateLocationLabel();
    renderAll();
  }

  function updateLocationLabel() {
    const el = $('location-label');
    const coords = state.lat.toFixed(4) + '°, ' + state.lng.toFixed(4) + '°';
    el.textContent = '📍 ' + coords;
    // Ortsname per Reverse-Geocoding (optional, scheitert offline still)
    const url = 'https://nominatim.openstreetmap.org/reverse?format=jsonv2&zoom=10' +
      '&lat=' + state.lat + '&lon=' + state.lng;
    fetch(url, { headers: { 'Accept-Language': 'de' } })
      .then((r) => r.ok ? r.json() : null)
      .then((j) => {
        if (!j) return;
        const a = j.address || {};
        const name = a.city || a.town || a.village || a.municipality || a.county || j.name;
        if (name) el.textContent = '📍 ' + name + (a.country ? ', ' + a.country : '') + ' (' + coords + ')';
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
      const now = new Date();
      const nm = document.createElement('div');
      nm.className = 'now-marker';
      nm.style.left = ((now.getHours() * 60 + now.getMinutes()) / 1440 * 100) + '%';
      nm.title = 'Jetzt';
      el.appendChild(nm);
    }
  }

  // ---------- Mond ----------
  function renderMoon() {
    const noon = dateAtMinutes(12 * 60);
    const times = Astro.getMoonTimes(noon, state.lat, state.lng);
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

  // ---------- 3D-Kompass ----------
  const R = 140; // Radius des Horizonts in px (Hälfte von 280)

  function compassDate() {
    return dateAtMinutes(state.sliderMinutes);
  }

  function renderCompass() {
    const d = compassDate();
    const sun = Astro.getSunPosition(d, state.lat, state.lng);
    const moon = Astro.getMoonPosition(d, state.lat, state.lng);

    placeBody('sun', sun);
    placeBody('moon', moon);

    $('sun-azalt').textContent = bodyText(sun);
    $('moon-azalt').textContent = bodyText(moon);
    $('sun-state').textContent = sun.altitude >= 0 ? 'über dem Horizont' : 'unter dem Horizont';
    $('moon-state').textContent = moon.altitude >= 0 ? 'über dem Horizont' : 'unter dem Horizont';

    $('time-slider-label').textContent = fmtTime(d) + ' Uhr';
    applySceneTransform();
    placeCardinals();
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
    const x = R * Math.cos(pos.altitude) * Math.sin(pos.azimuth);
    const y = -R * Math.cos(pos.altitude) * Math.cos(pos.azimuth);
    const z = R * Math.sin(pos.altitude);

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
      if (state.deviceOrientation) toggleDeviceOrientation(); // manuelles Drehen beendet Sensor-Modus
      renderCompass();
    });
    const stop = () => { dragging = false; };
    scene.addEventListener('pointerup', stop);
    scene.addEventListener('pointercancel', stop);
  }

  // Ausrichtung am echten Kompass (Gerätesensor)
  function onDeviceOrientation(ev) {
    let heading = null;
    if (typeof ev.webkitCompassHeading === 'number') {
      heading = ev.webkitCompassHeading; // iOS
    } else if (ev.absolute && typeof ev.alpha === 'number') {
      heading = 360 - ev.alpha;
    } else if (typeof ev.alpha === 'number') {
      heading = 360 - ev.alpha; // bester verfügbarer Wert
    }
    if (heading != null && state.deviceOrientation) {
      state.heading = (heading + 360) % 360;
      renderCompass();
    }
  }

  function toggleDeviceOrientation() {
    const btn = $('orient-btn');
    if (state.deviceOrientation) {
      state.deviceOrientation = false;
      window.removeEventListener('deviceorientationabsolute', onDeviceOrientation);
      window.removeEventListener('deviceorientation', onDeviceOrientation);
      btn.textContent = '📱 Am echten Kompass ausrichten';
      return;
    }
    const start = () => {
      state.deviceOrientation = true;
      if ('ondeviceorientationabsolute' in window) {
        window.addEventListener('deviceorientationabsolute', onDeviceOrientation);
      } else {
        window.addEventListener('deviceorientation', onDeviceOrientation);
      }
      btn.textContent = '📱 Sensor-Ausrichtung beenden';
    };
    if (typeof DeviceOrientationEvent !== 'undefined' &&
        typeof DeviceOrientationEvent.requestPermission === 'function') {
      DeviceOrientationEvent.requestPermission()
        .then((res) => { if (res === 'granted') start(); })
        .catch(() => { btn.textContent = '📱 Sensor nicht verfügbar'; });
    } else if (typeof DeviceOrientationEvent !== 'undefined') {
      start();
    } else {
      btn.textContent = '📱 Sensor nicht verfügbar';
    }
  }

  // ---------- Rendering & Events ----------
  function renderAll() {
    renderSun();
    renderMoon();
    renderCompass();
  }

  function setDateFromInput() {
    const v = $('date-input').value;
    if (!v) return;
    const [y, m, d] = v.split('-').map(Number);
    state.date = new Date(y, m - 1, d, 12, 0, 0);
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
    const now = new Date();
    state.sliderMinutes = now.getHours() * 60 + now.getMinutes();
    $('time-slider').value = String(state.sliderMinutes);
  }

  function setDateInput(d) {
    const pad = (n) => String(n).padStart(2, '0');
    $('date-input').value = d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate());
  }

  function init() {
    // Datum: heute vorauswählen
    state.date = new Date();
    state.date.setHours(12, 0, 0, 0);
    setDateInput(new Date());
    setSliderToNow();

    initMap();
    initCompassDrag();
    updateLocationLabel();
    renderAll();
    locate(); // automatische Standortbestimmung

    $('date-input').addEventListener('change', setDateFromInput);
    $('today-btn').addEventListener('click', () => {
      setDateInput(new Date());
      state.live = true;
      setDateFromInput();
    });
    $('locate-btn').addEventListener('click', locate);
    $('time-slider').addEventListener('input', () => {
      state.live = false;
      state.sliderMinutes = Number($('time-slider').value);
      renderCompass();
    });
    $('now-btn').addEventListener('click', () => {
      state.live = true;
      setDateInput(new Date());
      state.date = new Date();
      state.date.setHours(12, 0, 0, 0);
      setSliderToNow();
      renderAll();
    });
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
