// Ampel — antippen schaltet weiter, in den Einstellungen auch mit Beschriftung.

import { h, clear, beep, onTap } from '../util.js';
import { section, toggleRow, field } from '../ui.js';

const ORDER = ['green', 'yellow', 'red'];
const DEFAULT_LABELS = { red: 'Stopp', yellow: 'Leise arbeiten', green: 'Los geht’s' };

export default {
  type: 'traffic',
  label: 'Ampel',
  icon: 'traffic',
  defaultSize: { w: 220, h: 340 },
  minSize: { w: 130, h: 200 },
  createState() {
    return { active: 'green', showLabel: false, labels: Object.assign({}, DEFAULT_LABELS), horizontal: false };
  },

  mount(ctx) {
    const el = h('div', { class: 'w-traffic' });
    const lightsBox = h('div', { class: 'w-traffic__body' });
    const labelEl = h('div', { class: 'w-traffic__label' });
    el.append(lightsBox, labelEl);

    function render() {
      const state = ctx.widget.state;
      clear(lightsBox);
      el.classList.toggle('is-horizontal', Boolean(state.horizontal));
      for (const color of ['red', 'yellow', 'green']) {
        lightsBox.appendChild(onTap(h('button', {
          class: `w-traffic__light w-traffic__light--${color}` + (state.active === color ? ' is-on' : ''),
          'data-nodrag': '',
          title: (state.labels && state.labels[color]) || DEFAULT_LABELS[color],
        }), () => {
          ctx.widget.state.active = color;
          ctx.save();
          beep({ frequency: color === 'red' ? 320 : color === 'yellow' ? 520 : 720, duration: 0.1, gain: 0.08 });
          render();
        }));
      }
      const labels = state.labels || DEFAULT_LABELS;
      labelEl.textContent = state.showLabel ? (labels[state.active] || '') : '';
      labelEl.classList.toggle('is-hidden', !state.showLabel);
    }

    function cycle() {
      const state = ctx.widget.state;
      const index = ORDER.indexOf(state.active);
      state.active = ORDER[(index + 1) % ORDER.length];
      ctx.save();
      render();
    }

    render();
    return { el, refresh: render, onTap: cycle };
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
      const labels = state.labels || DEFAULT_LABELS;
      wrap.appendChild(section('Anzeige',
        toggleRow('Beschriftung anzeigen', Boolean(state.showLabel), (value) => {
          ctx.widget.state.showLabel = value;
          ctx.save();
          rerender();
        }),
        toggleRow('Quer statt hochkant', Boolean(state.horizontal), (value) => {
          ctx.widget.state.horizontal = value;
          ctx.save();
          rerender();
        })));

      wrap.appendChild(section('Beschriftungen',
        ['red', 'yellow', 'green'].map((color) => field(
          color === 'red' ? 'Rot' : color === 'yellow' ? 'Gelb' : 'Grün',
          h('input', {
            class: 'input', type: 'text', value: labels[color] || '',
            oninput: (event) => {
              if (!ctx.widget.state.labels) ctx.widget.state.labels = Object.assign({}, DEFAULT_LABELS);
              ctx.widget.state.labels[color] = event.target.value;
              ctx.save();
              ctx.refresh();
            },
          })))));
    }

    build();
    return wrap;
  },
};
