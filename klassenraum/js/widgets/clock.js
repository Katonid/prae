// Uhr — analog (mit Ziffernblatt zum Ablesen üben) oder digital.

import { h, clear } from '../util.js';
import { section, toggleRow, colorSwatches } from '../ui.js';

const WEEKDAYS = ['Sonntag', 'Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag'];
const MONTHS = ['Januar', 'Februar', 'März', 'April', 'Mai', 'Juni', 'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember'];

function analogSvg(accent) {
  const ns = 'http://www.w3.org/2000/svg';
  const svg = document.createElementNS(ns, 'svg');
  svg.setAttribute('viewBox', '0 0 200 200');
  svg.classList.add('w-clock__svg');
  const parts = [`<circle class="clock-face" cx="100" cy="100" r="94" style="stroke:${accent}"/>`];
  for (let i = 0; i < 60; i += 1) {
    const angle = (i * 6 * Math.PI) / 180;
    const long = i % 5 === 0;
    const outer = 88;
    const inner = long ? 78 : 83;
    const x1 = 100 + Math.sin(angle) * inner;
    const y1 = 100 - Math.cos(angle) * inner;
    const x2 = 100 + Math.sin(angle) * outer;
    const y2 = 100 - Math.cos(angle) * outer;
    parts.push(`<line class="clock-tick${long ? ' clock-tick--long' : ''}" x1="${x1.toFixed(1)}" y1="${y1.toFixed(1)}" x2="${x2.toFixed(1)}" y2="${y2.toFixed(1)}" style="stroke:${long ? accent : accent + '99'}"/>`);
  }
  for (let n = 1; n <= 12; n += 1) {
    const angle = (n * 30 * Math.PI) / 180;
    const x = 100 + Math.sin(angle) * 64;
    const y = 100 - Math.cos(angle) * 64 + 7;
    parts.push(`<text class="clock-number" x="${x.toFixed(1)}" y="${y.toFixed(1)}" text-anchor="middle">${n}</text>`);
  }
  parts.push('<line class="clock-hand clock-hand--hour" x1="100" y1="108" x2="100" y2="52"/>');
  parts.push('<line class="clock-hand clock-hand--minute" x1="100" y1="112" x2="100" y2="26"/>');
  parts.push('<line class="clock-hand clock-hand--second" x1="100" y1="116" x2="100" y2="22"/>');
  parts.push('<circle class="clock-pin" cx="100" cy="100" r="4.5"/>');
  svg.innerHTML = parts.join('');
  return svg;
}

export default {
  type: 'clock',
  label: 'Uhr',
  icon: 'clock',
  defaultSize: { w: 400, h: 400 },
  minSize: { w: 180, h: 180 },
  createState() {
    return { mode: 'analog', showSeconds: true, showDate: true, accent: '#6366f1' };
  },

  mount(ctx) {
    const el = h('div', { class: 'w-clock' });
    let svg = null;
    let hands = null;
    const digital = h('div', { class: 'w-clock__digital' });
    const dateEl = h('div', { class: 'w-clock__date' });

    function build() {
      clear(el);
      const state = ctx.widget.state;
      if (state.mode === 'analog') {
        svg = analogSvg(state.accent || '#6366f1');
        hands = {
          hour: svg.querySelector('.clock-hand--hour'),
          minute: svg.querySelector('.clock-hand--minute'),
          second: svg.querySelector('.clock-hand--second'),
        };
        hands.second.style.display = state.showSeconds === false ? 'none' : '';
        el.appendChild(h('div', { class: 'w-clock__analog' }, svg));
      } else {
        svg = null;
        hands = null;
        el.appendChild(digital);
      }
      if (state.showDate) el.appendChild(dateEl);
      tick();
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
        hands.second.setAttribute('transform', `rotate(${seconds * 6} 100 100)`);
      } else {
        const pad = (n) => String(n).padStart(2, '0');
        digital.textContent = state.showSeconds === false
          ? `${pad(now.getHours())}:${pad(now.getMinutes())}`
          : `${pad(now.getHours())}:${pad(now.getMinutes())}:${pad(now.getSeconds())}`;
        const size = Math.min(ctx.widget.w / (state.showSeconds === false ? 4.4 : 6.2), ctx.widget.h * 0.55);
        digital.style.fontSize = `${Math.max(28, size)}px`;
      }
      if (state.showDate) {
        dateEl.textContent = `${WEEKDAYS[now.getDay()]}, ${now.getDate()}. ${MONTHS[now.getMonth()]} ${now.getFullYear()}`;
      }
    }

    const timer = setInterval(tick, 200);
    build();

    return {
      el,
      refresh: build,
      onResize: tick,
      destroy() {
        clearInterval(timer);
      },
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
          }, 'Digital')),
        toggleRow('Sekunden anzeigen', state.showSeconds !== false, (value) => {
          ctx.widget.state.showSeconds = value;
          ctx.save();
          rerender();
        }),
        toggleRow('Datum anzeigen', state.showDate !== false, (value) => {
          ctx.widget.state.showDate = value;
          ctx.save();
          rerender();
        })));

      if (state.mode === 'analog') {
        wrap.appendChild(section('Farbe',
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
