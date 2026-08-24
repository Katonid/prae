// Timer und Stoppuhr — mit einem Tipp gestartet, Voreinstellungen für den Unterricht.

import { h, clear, formatDuration, chime, beep, onTap } from '../util.js';
import { icon } from '../icons.js';
import { section, toggleRow, button, buttonRow, field } from '../ui.js';

const PRESETS = [1, 2, 3, 5, 10, 15, 20, 30, 45];

export default {
  type: 'timer',
  label: 'Timer',
  icon: 'timer',
  defaultSize: { w: 320, h: 320 },
  minSize: { w: 220, h: 220 },
  createState() {
    return {
      mode: 'timer',
      seconds: 300,
      remaining: 300,
      running: false,
      endsAt: null,
      elapsed: 0,
      startedAt: null,
      sound: true,
      label: '',
    };
  },

  mount(ctx) {
    const el = h('div', { class: 'w-timer' });
    const labelEl = h('div', { class: 'w-timer__label' });
    const timeEl = h('div', { class: 'w-timer__time' });
    const ring = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    ring.setAttribute('viewBox', '0 0 120 120');
    ring.classList.add('w-timer__ring');
    const gradientId = `timer-${Math.random().toString(36).slice(2, 8)}`;
    ring.innerHTML = `<defs><linearGradient id="${gradientId}" x1="0" y1="0" x2="1" y2="1">`
      + '<stop offset="0%" stop-color="#6366f1"/><stop offset="55%" stop-color="#a855f7"/>'
      + '<stop offset="100%" stop-color="#ec4899"/></linearGradient></defs>'
      + '<circle class="w-timer__track" cx="60" cy="60" r="52"/>'
      + `<circle class="w-timer__progress" cx="60" cy="60" r="52" stroke="url(#${gradientId})"/>`;
    const progress = ring.querySelector('.w-timer__progress');
    const CIRC = 2 * Math.PI * 52;
    progress.style.strokeDasharray = String(CIRC);

    const playButton = h('button', { class: 'round-button round-button--primary', 'data-nodrag': '', title: 'Start / Pause' });
    const resetButton = h('button', { class: 'round-button', 'data-nodrag': '', title: 'Zurücksetzen', html: icon('reset', 20) });
    const minusButton = h('button', { class: 'round-button round-button--small', 'data-nodrag': '', title: '1 Minute weniger' }, '−1');
    const plusButton = h('button', { class: 'round-button round-button--small', 'data-nodrag': '', title: '1 Minute mehr' }, '+1');

    el.append(
      labelEl,
      h('div', { class: 'w-timer__face' }, ring, timeEl),
      h('div', { class: 'w-timer__controls', 'data-nodrag': '' }, minusButton, resetButton, playButton, plusButton));

    let ticker = null;
    let alarmed = false;

    function currentSeconds() {
      const state = ctx.widget.state;
      if (state.mode === 'stopwatch') {
        const base = state.elapsed || 0;
        if (state.running && state.startedAt) return base + (Date.now() - state.startedAt) / 1000;
        return base;
      }
      if (state.running && state.endsAt) return Math.max(0, (state.endsAt - Date.now()) / 1000);
      return Math.max(0, state.remaining || 0);
    }

    function render() {
      const state = ctx.widget.state;
      const value = currentSeconds();
      timeEl.textContent = formatDuration(value);
      labelEl.textContent = state.label || (state.mode === 'stopwatch' ? 'Stoppuhr' : 'Timer');
      playButton.innerHTML = icon(state.running ? 'pause' : 'play', 22);
      const total = state.mode === 'stopwatch' ? Math.max(60, Math.ceil(value / 60) * 60) : Math.max(1, state.seconds || 1);
      const ratio = state.mode === 'stopwatch' ? (value % total) / total : value / total;
      progress.style.strokeDashoffset = String(CIRC * (1 - Math.max(0, Math.min(1, ratio))));
      el.classList.toggle('is-finished', state.mode === 'timer' && value <= 0 && !state.running && alarmed);
      el.classList.toggle('is-warning', state.mode === 'timer' && state.running && value <= 10);
      minusButton.style.visibility = state.mode === 'stopwatch' ? 'hidden' : 'visible';
      plusButton.style.visibility = state.mode === 'stopwatch' ? 'hidden' : 'visible';
      fit();
    }

    function fit() {
      const size = Math.max(26, Math.min(ctx.widget.w, ctx.widget.h) * 0.24);
      timeEl.style.fontSize = `${size}px`;
    }

    function tick() {
      const state = ctx.widget.state;
      if (state.mode === 'timer' && state.running) {
        const value = currentSeconds();
        if (value <= 0) {
          state.running = false;
          state.remaining = 0;
          state.endsAt = null;
          alarmed = true;
          ctx.save();
          if (state.sound !== false) chime(4);
          el.classList.add('is-flash');
          setTimeout(() => el.classList.remove('is-flash'), 4000);
        }
      }
      render();
    }

    function startTicker() {
      if (ticker) return;
      ticker = setInterval(tick, 200);
    }

    function stopTicker() {
      if (!ticker) return;
      clearInterval(ticker);
      ticker = null;
    }

    function toggle() {
      const state = ctx.widget.state;
      beep({ frequency: 520, duration: 0.08, gain: 0.08 });
      if (state.mode === 'stopwatch') {
        if (state.running) {
          state.elapsed = currentSeconds();
          state.running = false;
          state.startedAt = null;
        } else {
          state.startedAt = Date.now();
          state.running = true;
        }
      } else if (state.running) {
        state.remaining = currentSeconds();
        state.running = false;
        state.endsAt = null;
      } else {
        const seconds = state.remaining > 0 ? state.remaining : state.seconds;
        if (seconds <= 0) return;
        alarmed = false;
        state.remaining = seconds;
        state.endsAt = Date.now() + seconds * 1000;
        state.running = true;
      }
      ctx.save();
      render();
    }

    function reset() {
      const state = ctx.widget.state;
      alarmed = false;
      if (state.mode === 'stopwatch') {
        state.elapsed = 0;
        state.startedAt = state.running ? Date.now() : null;
      } else {
        state.remaining = state.seconds;
        state.endsAt = state.running ? Date.now() + state.seconds * 1000 : null;
      }
      ctx.save();
      render();
    }

    function addMinutes(delta) {
      const state = ctx.widget.state;
      if (state.mode === 'stopwatch') return;
      const base = state.running ? currentSeconds() : state.remaining;
      const next = Math.max(0, Math.round((base + delta * 60) / 30) * 30);
      state.remaining = next;
      state.seconds = Math.max(next, state.running ? state.seconds : next);
      if (state.running) state.endsAt = Date.now() + next * 1000;
      if (!state.running) state.seconds = next;
      alarmed = false;
      ctx.save();
      render();
    }

    onTap(playButton, toggle);
    onTap(resetButton, reset);
    onTap(minusButton, () => addMinutes(-1));
    onTap(plusButton, () => addMinutes(1));

    startTicker();
    render();

    return {
      el,
      refresh: render,
      onResize: fit,
      destroy() {
        stopTicker();
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
      wrap.appendChild(section('Art',
        h('div', { class: 'segmented' },
          h('button', {
            class: 'segmented__item' + (state.mode !== 'stopwatch' ? ' is-active' : ''),
            onclick: () => {
              ctx.widget.state.mode = 'timer';
              ctx.widget.state.running = false;
              ctx.widget.state.endsAt = null;
              ctx.widget.state.remaining = ctx.widget.state.seconds;
              ctx.save();
              rerender();
            },
          }, 'Timer'),
          h('button', {
            class: 'segmented__item' + (state.mode === 'stopwatch' ? ' is-active' : ''),
            onclick: () => {
              ctx.widget.state.mode = 'stopwatch';
              ctx.widget.state.running = false;
              ctx.widget.state.startedAt = null;
              ctx.save();
              rerender();
            },
          }, 'Stoppuhr'))));

      if (state.mode !== 'stopwatch') {
        const chips = h('div', { class: 'chips' }, PRESETS.map((minutes) => h('button', {
          class: 'chip' + (state.seconds === minutes * 60 ? ' is-active' : ''),
          onclick: () => {
            const next = ctx.widget.state;
            next.seconds = minutes * 60;
            next.remaining = minutes * 60;
            next.running = false;
            next.endsAt = null;
            ctx.save();
            rerender();
          },
        }, `${minutes} min`)));

        const minutesInput = h('input', {
          class: 'input', type: 'number', min: '0', max: '180', step: '1',
          value: Math.floor((state.seconds || 0) / 60),
        });
        const secondsInput = h('input', {
          class: 'input', type: 'number', min: '0', max: '59', step: '5',
          value: (state.seconds || 0) % 60,
        });
        const apply = () => {
          const total = Math.max(0, (parseInt(minutesInput.value, 10) || 0) * 60 + (parseInt(secondsInput.value, 10) || 0));
          const next = ctx.widget.state;
          next.seconds = total;
          next.remaining = total;
          next.running = false;
          next.endsAt = null;
          ctx.save();
          ctx.refresh();
        };
        minutesInput.addEventListener('change', apply);
        secondsInput.addEventListener('change', apply);

        wrap.appendChild(section('Dauer', chips,
          h('div', { class: 'row' },
            field('Minuten', minutesInput),
            field('Sekunden', secondsInput))));
      }

      wrap.appendChild(section('Weiteres',
        field('Beschriftung', h('input', {
          class: 'input', type: 'text', value: state.label || '', placeholder: 'z. B. Stillarbeit',
          oninput: (event) => {
            ctx.widget.state.label = event.target.value;
            ctx.save();
            ctx.refresh();
          },
        })),
        toggleRow('Signalton am Ende', state.sound !== false, (value) => {
          ctx.widget.state.sound = value;
          ctx.save();
        }),
        buttonRow(button('Ton testen', { small: true, icon: 'play', onClick: () => chime(2) }))));
    }

    build();
    return wrap;
  },
};
