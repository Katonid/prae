// Uhr — modern, klassisch oder als Lernuhr; dazu digital.

import { h, clear, reducedMotion } from '../util.js';
import { section, toggleRow, colorSwatches } from '../ui.js';
import { accentPair } from '../theme.js';
import { getActiveBoard } from '../store.js';

const WEEKDAYS = ['Sonntag', 'Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag'];
const MONTHS = ['Januar', 'Februar', 'März', 'April', 'Mai', 'Juni', 'Juli', 'August',
  'September', 'Oktober', 'November', 'Dezember'];

const FACES = [
  { id: 'modern', label: 'Modern' },
  { id: 'klassisch', label: 'Klassisch' },
  { id: 'lernuhr', label: 'Lernuhr' },
  { id: 'minimal', label: 'Minimal' },
];

const HOUR_COLOR = '#2563eb';
const MINUTE_COLOR = '#ea580c';

function polar(radius, degrees) {
  const rad = (degrees - 90) * (Math.PI / 180);
  return { x: 100 + Math.cos(rad) * radius, y: 100 + Math.sin(rad) * radius };
}

function ticks(face, accent) {
  const parts = [];
  for (let i = 0; i < 60; i += 1) {
    const major = i % 5 === 0;
    // Nur das Zifferblatt „Minimal" verzichtet auf die kleinen Minutenstriche.
    if (face === 'minimal' && !major) continue;
    const angle = i * 6;
    const outer = face === 'lernuhr' ? 79 : 88;
    const inner = major ? outer - (face === 'minimal' ? 9 : 8) : outer - 4;
    const a = polar(outer, angle);
    const b = polar(inner, angle);
    const width = major ? (face === 'modern' ? 3.2 : 3) : 1.4;
    const color = major ? accent : `${accent}66`;
    parts.push(`<line x1="${a.x.toFixed(1)}" y1="${a.y.toFixed(1)}" x2="${b.x.toFixed(1)}" y2="${b.y.toFixed(1)}" `
      + `stroke="${color}" stroke-width="${width}" stroke-linecap="round"/>`);
  }
  return parts.join('');
}

function numbers(face) {
  const parts = [];
  if (face === 'minimal') {
    for (const n of [12, 3, 6, 9]) {
      const p = polar(68, n * 30);
      parts.push(`<text class="clock-number clock-number--light" x="${p.x.toFixed(1)}" y="${(p.y + 7).toFixed(1)}" text-anchor="middle">${n}</text>`);
    }
    return parts.join('');
  }
  for (let n = 1; n <= 12; n += 1) {
    const p = polar(face === 'lernuhr' ? 60 : 66, n * 30);
    const fill = face === 'lernuhr' ? HOUR_COLOR : 'var(--card-ink)';
    const cls = face === 'modern' ? 'clock-number clock-number--modern' : 'clock-number';
    parts.push(`<text class="${cls}" x="${p.x.toFixed(1)}" y="${(p.y + 7).toFixed(1)}" text-anchor="middle" fill="${fill}">${n}</text>`);
  }
  if (face === 'lernuhr') {
    for (let n = 5; n <= 60; n += 5) {
      const p = polar(89, n * 6);
      parts.push(`<text class="clock-number clock-number--minute" x="${p.x.toFixed(1)}" y="${(p.y + 4).toFixed(1)}" `
        + `text-anchor="middle" fill="${MINUTE_COLOR}">${n === 60 ? 0 : n}</text>`);
    }
  }
  return parts.join('');
}

function buildFace(face, accent, showSeconds) {
  const id = `clk-${Math.random().toString(36).slice(2, 8)}`;
  const parts = [];

  // userSpaceOnUse ist wichtig: eine senkrechte Linie hat keine Breite, ein
  // Farbverlauf in Objektkoordinaten würde deshalb gar nicht gezeichnet.
  const tone = accentPair(getActiveBoard());
  parts.push(`<defs><linearGradient id="${id}" gradientUnits="userSpaceOnUse" x1="60" y1="20" x2="140" y2="180">`
    + `<stop offset="0%" stop-color="${tone.from}"/><stop offset="100%" stop-color="${tone.to}"/></linearGradient></defs>`);

  if (face === 'modern' || face === 'minimal') {
    parts.push(`<circle cx="100" cy="100" r="94" fill="var(--clock-face)" stroke="${accent}33" stroke-width="2"/>`);
  } else {
    parts.push(`<circle cx="100" cy="100" r="94" fill="var(--clock-face)" stroke="${face === 'lernuhr' ? HOUR_COLOR : accent}" stroke-width="${face === 'lernuhr' ? 2.5 : 3}"/>`);
  }

  const tickColor = face === 'lernuhr' ? MINUTE_COLOR : (face === 'klassisch' ? accent : '#334155');
  parts.push(ticks(face, tickColor));
  parts.push(numbers(face));

  const hourColor = face === 'lernuhr' ? HOUR_COLOR : 'var(--card-ink)';
  const minuteColor = face === 'lernuhr' ? MINUTE_COLOR : 'var(--card-ink)';

  if (face === 'modern' || face === 'minimal') {
    parts.push('<line class="clock-hand clock-hand--hour" x1="100" y1="112" x2="100" y2="54" '
      + `stroke="${hourColor}" stroke-width="7" stroke-linecap="round"/>`);
    parts.push('<line class="clock-hand clock-hand--minute" x1="100" y1="116" x2="100" y2="30" '
      + `stroke="${minuteColor}" stroke-width="5" stroke-linecap="round"/>`);
  } else {
    parts.push(`<line class="clock-hand clock-hand--hour" x1="100" y1="110" x2="100" y2="${face === 'lernuhr' ? 58 : 54}" `
      + `stroke="${hourColor}" stroke-width="${face === 'lernuhr' ? 8 : 7}" stroke-linecap="round"/>`);
    parts.push(`<line class="clock-hand clock-hand--minute" x1="100" y1="114" x2="100" y2="${face === 'lernuhr' ? 26 : 28}" `
      + `stroke="${minuteColor}" stroke-width="${face === 'lernuhr' ? 5.5 : 4.6}" stroke-linecap="round"/>`);
  }

  if (showSeconds) {
    parts.push(`<line class="clock-hand clock-hand--second" x1="100" y1="118" x2="100" y2="24" stroke="url(#${id})" stroke-width="2.2" stroke-linecap="round"/>`);
  }

  parts.push(`<circle class="clock-pin" cx="100" cy="100" r="${face === 'lernuhr' ? 4.5 : 5}" fill="url(#${id})"/>`);
  parts.push('<circle cx="100" cy="100" r="2" fill="var(--clock-face)"/>');
  return parts.join('');
}

export default {
  type: 'clock',
  label: 'Uhr',
  icon: 'clock',
  defaultSize: { w: 400, h: 400 },
  minSize: { w: 180, h: 180 },
  createState() {
    // accent: null bedeutet „wie das Farbschema des Klassenraums".
    return { mode: 'analog', face: 'modern', showSeconds: true, showDate: true, accent: null, sweep: true };
  },

  mount(ctx) {
    const el = h('div', { class: 'w-clock' });
    const digital = h('div', { class: 'w-clock__digital' });
    const dateEl = h('div', { class: 'w-clock__date' });
    let svg = null;
    let hands = null;
    let raf = null;
    let timer = null;
    let lastDateText = '';

    // Das Datum soll so breit sein wie die Uhr selbst: Schriftgröße aus dem
    // Verhältnis von Zifferblatt- zu Textbreite bestimmen (beides am
    // Bildschirm gemessen, der Tafel-Maßstab kürzt sich dadurch heraus).
    function fitDate() {
      if (!dateEl.isConnected || !dateEl.textContent) return;
      const target = svg ? svg.getBoundingClientRect().width : el.getBoundingClientRect().width * 0.92;
      const current = dateEl.getBoundingClientRect().width;
      if (!target || !current) return;
      const size = (parseFloat(dateEl.style.fontSize) || 16) * (target / current);
      dateEl.style.fontSize = `${Math.max(14, Math.min(size, 64))}px`;
    }

    function build() {
      const state = ctx.widget.state;
      clear(el);
      stopLoops();
      if (state.mode === 'analog') {
        const face = FACES.some((entry) => entry.id === state.face) ? state.face : 'modern';
        svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
        svg.setAttribute('viewBox', '0 0 200 200');
        svg.classList.add('w-clock__svg', `w-clock__svg--${face}`);
        const accent = state.accent || accentPair(getActiveBoard()).from;
        svg.innerHTML = buildFace(face, accent, state.showSeconds !== false);
        hands = {
          hour: svg.querySelector('.clock-hand--hour'),
          minute: svg.querySelector('.clock-hand--minute'),
          second: svg.querySelector('.clock-hand--second'),
        };
        el.appendChild(h('div', { class: 'w-clock__analog' }, svg));
      } else {
        svg = null;
        hands = null;
        el.appendChild(digital);
      }
      if (state.showDate) el.appendChild(dateEl);
      tick();
      // Erst nach dem Aufbau messen — vorher hat das Zifferblatt keine Größe.
      requestAnimationFrame(fitDate);
      startLoops();
    }

    function startLoops() {
      const state = ctx.widget.state;
      const smooth = hands && state.showSeconds !== false && state.sweep !== false && !reducedMotion();
      if (smooth) {
        const loop = () => {
          tick();
          raf = requestAnimationFrame(loop);
        };
        raf = requestAnimationFrame(loop);
      } else {
        timer = setInterval(tick, 250);
      }
    }

    function stopLoops() {
      if (raf) cancelAnimationFrame(raf);
      if (timer) clearInterval(timer);
      raf = null;
      timer = null;
    }

    function tick() {
      const state = ctx.widget.state;
      const now = new Date();
      if (hands) {
        const seconds = now.getSeconds() + now.getMilliseconds() / 1000;
        const minutes = now.getMinutes() + seconds / 60;
        const hours = (now.getHours() % 12) + minutes / 60;
        hands.hour.setAttribute('transform', `rotate(${hours * 30} 100 100)`);
        hands.minute.setAttribute('transform', `rotate(${minutes * 6} 100 100)`);
        if (hands.second) {
          const value = state.sweep === false || reducedMotion() ? Math.floor(seconds) : seconds;
          hands.second.setAttribute('transform', `rotate(${value * 6} 100 100)`);
        }
      } else {
        const pad = (n) => String(n).padStart(2, '0');
        digital.textContent = state.showSeconds === false
          ? `${pad(now.getHours())}:${pad(now.getMinutes())}`
          : `${pad(now.getHours())}:${pad(now.getMinutes())}:${pad(now.getSeconds())}`;
        const size = Math.min(ctx.widget.w / (state.showSeconds === false ? 4.4 : 6.2), ctx.widget.h * 0.55);
        digital.style.fontSize = `${Math.max(28, size)}px`;
      }
      if (state.showDate) {
        const text = `${WEEKDAYS[now.getDay()]}, ${now.getDate()}. ${MONTHS[now.getMonth()]} ${now.getFullYear()}`;
        if (text !== lastDateText) {
          // Nur bei geändertem Text neu messen (Mitternacht) — tick() läuft
          // sonst mit jedem Bild und darf kein Layout erzwingen.
          lastDateText = text;
          dateEl.textContent = text;
          requestAnimationFrame(fitDate);
        }
      }
    }

    build();

    return {
      el,
      refresh: build,
      onResize: () => {
        tick();
        // Die neue Größe steht erst nach dem nächsten Layout im Bild.
        requestAnimationFrame(fitDate);
      },
      // Bewusst ohne onTap: Ein Tipp soll die Uhr nicht umschalten.
      // Analog oder digital wird in den Einstellungen gewählt.
      destroy: stopLoops,
    };
  },

  settings(ctx) {
    const wrap = h('div', { class: 'stack' });

    function rerender() {
      clear(wrap);
      build();
      ctx.refresh();
    }

    function build() {
      const state = ctx.widget.state;
      wrap.appendChild(section('Darstellung',
        h('div', { class: 'segmented' },
          h('button', {
            class: 'segmented__item' + (state.mode === 'analog' ? ' is-active' : ''),
            onclick: () => {
              ctx.widget.state.mode = 'analog';
              ctx.save();
              rerender();
            },
          }, 'Analog'),
          h('button', {
            class: 'segmented__item' + (state.mode !== 'analog' ? ' is-active' : ''),
            onclick: () => {
              ctx.widget.state.mode = 'digital';
              ctx.save();
              rerender();
            },
          }, 'Digital'))));

      if (state.mode === 'analog') {
        wrap.appendChild(section('Zifferblatt',
          h('div', { class: 'segmented' }, FACES.map((face) => h('button', {
            class: 'segmented__item' + ((state.face || 'modern') === face.id ? ' is-active' : ''),
            onclick: () => {
              ctx.widget.state.face = face.id;
              ctx.save();
              rerender();
            },
          }, face.label))),
          h('p', { class: 'muted small' }, {
            lernuhr: 'Lernuhr: blaue Stundenzahlen mit blauem Zeiger, orange Minutenzahlen mit orangem Zeiger — zum Ablesen üben.',
            modern: 'Modern: alle Zahlen von 1 bis 12 und alle Minutenstriche, dazu schlanke Zeiger und ein gleitender Sekundenzeiger.',
            klassisch: 'Klassisch: kräftiger Rahmen, alle Zahlen und Minutenstriche wie auf einer Wanduhr.',
            minimal: 'Minimal: nur 12, 3, 6 und 9 sowie die Fünf-Minuten-Striche — schlicht, aber zum Ablesenlernen ungeeignet.',
          }[state.face || 'modern'])));
      }

      wrap.appendChild(section('Anzeige',
        toggleRow('Sekunden anzeigen', state.showSeconds !== false, (value) => {
          ctx.widget.state.showSeconds = value;
          ctx.save();
          rerender();
        }),
        state.mode === 'analog' && state.showSeconds !== false ? toggleRow('Sekundenzeiger gleitet', state.sweep !== false, (value) => {
          ctx.widget.state.sweep = value;
          ctx.save();
          rerender();
        }, 'Aus: der Zeiger springt im Sekundentakt.') : null,
        toggleRow('Datum anzeigen', state.showDate !== false, (value) => {
          ctx.widget.state.showDate = value;
          ctx.save();
          rerender();
        })));

      if (state.mode === 'analog' && (state.face || 'modern') !== 'lernuhr') {
        wrap.appendChild(section('Farbe',
          h('div', { class: 'button-row' },
            h('button', {
              class: 'chip' + (state.accent ? '' : ' is-active'),
              onclick: () => {
                ctx.widget.state.accent = null;
                ctx.save();
                rerender();
              },
            }, 'Wie Farbschema')),
          colorSwatches(['#6366f1', '#0ea5e9', '#16a34a', '#f97316', '#e11d48', '#111827'], state.accent, (color) => {
            ctx.widget.state.accent = color;
            ctx.save();
            rerender();
          })));
      }
    }

    build();
    return wrap;
  },
};
