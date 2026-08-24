// Arbeitssymbole — zeigt die gewünschte Arbeitsform groß an.

import { h, clear } from '../util.js';
import { section, toggleRow } from '../ui.js';

const SYMBOLS = [
  {
    id: 'einzel', label: 'Einzelarbeit',
    svg: '<circle cx="32" cy="20" r="10"/><path d="M14 52c0-9 8-15 18-15s18 6 18 15"/>',
  },
  {
    id: 'partner', label: 'Partnerarbeit',
    svg: '<circle cx="22" cy="21" r="9"/><circle cx="43" cy="23" r="7.5"/><path d="M6 52c0-8.5 7.2-14 16-14s16 5.5 16 14"/><path d="M36 52c0-6.5 4-11 9.5-11S55 45.5 55 52"/>',
  },
  {
    id: 'gruppe', label: 'Gruppenarbeit',
    svg: '<circle cx="18" cy="20" r="7.5"/><circle cx="32" cy="16" r="7.5"/><circle cx="46" cy="20" r="7.5"/><path d="M6 50c0-7 5.4-11.5 12-11.5S30 43 30 50"/><path d="M20 52c0-7.5 5.4-12 12-12s12 4.5 12 12"/><path d="M34 50c0-7 5.4-11.5 12-11.5S58 43 58 50"/>',
  },
  {
    id: 'still', label: 'Stillarbeit',
    svg: '<path d="M12 14h40a4 4 0 0 1 4 4v20a4 4 0 0 1-4 4H30l-12 9v-9h-6a4 4 0 0 1-4-4V18a4 4 0 0 1 4-4z"/><path d="M22 20l20 16"/><path d="M42 20L22 36"/>',
  },
  {
    id: 'fluestern', label: 'Flüsterstimme',
    svg: '<path d="M12 14h40a4 4 0 0 1 4 4v20a4 4 0 0 1-4 4H30l-12 9v-9h-6a4 4 0 0 1-4-4V18a4 4 0 0 1 4-4z"/><path d="M22 28h6"/><path d="M32 28h10"/>',
  },
  {
    id: 'melden', label: 'Melden',
    svg: '<path d="M24 52V30a4 4 0 0 1 8 0v-6a4 4 0 0 1 8 0v6a4 4 0 0 1 8 0v14c0 6-5 8-11 8z"/><path d="M20 22l-6-8"/><path d="M30 16V6"/>',
  },
  {
    id: 'zuhoeren', label: 'Zuhören',
    svg: '<path d="M20 26a12 12 0 0 1 24 0c0 8-8 10-8 16a5 5 0 0 1-10 0"/><path d="M28 46h6"/>',
  },
  {
    id: 'aufraeumen', label: 'Aufräumen',
    svg: '<rect x="12" y="24" width="40" height="26" rx="4"/><path d="M12 32h40"/><path d="M26 24l6-12 6 12"/>',
  },
];

export default {
  type: 'symbols',
  label: 'Arbeitssymbol',
  icon: 'symbols',
  defaultSize: { w: 300, h: 320 },
  minSize: { w: 160, h: 180 },
  createState() {
    return { symbol: 'einzel', showLabel: true, color: '#4338ca' };
  },

  mount(ctx) {
    const el = h('div', { class: 'w-symbol' });

    function render() {
      const state = ctx.widget.state;
      const symbol = SYMBOLS.find((entry) => entry.id === state.symbol) || SYMBOLS[0];
      clear(el);
      el.appendChild(h('div', {
        class: 'w-symbol__art',
        html: `<svg viewBox="0 0 64 64" fill="none" stroke="${state.color || '#4338ca'}" stroke-width="3.4" stroke-linecap="round" stroke-linejoin="round">${symbol.svg}</svg>`,
      }));
      if (state.showLabel !== false) el.appendChild(h('div', { class: 'w-symbol__label' }, symbol.label));
    }

    function next() {
      const state = ctx.widget.state;
      const index = SYMBOLS.findIndex((entry) => entry.id === state.symbol);
      state.symbol = SYMBOLS[(index + 1) % SYMBOLS.length].id;
      ctx.save();
      render();
    }

    render();
    return { el, refresh: render, onTap: next };
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
      const grid = h('div', { class: 'symbol-grid' }, SYMBOLS.map((symbol) => h('button', {
        class: 'symbol-grid__item' + (state.symbol === symbol.id ? ' is-active' : ''),
        title: symbol.label,
        onclick: () => {
          ctx.widget.state.symbol = symbol.id;
          ctx.save();
          rerender();
        },
      },
      h('span', {
        html: `<svg viewBox="0 0 64 64" width="42" height="42" fill="none" stroke="currentColor" stroke-width="3.4" stroke-linecap="round" stroke-linejoin="round">${symbol.svg}</svg>`,
      }),
      h('small', null, symbol.label))));

      wrap.appendChild(section('Symbol', grid));
      wrap.appendChild(section('Anzeige',
        toggleRow('Beschriftung anzeigen', state.showLabel !== false, (value) => {
          ctx.widget.state.showLabel = value;
          ctx.save();
          ctx.refresh();
        })));
    }

    build();
    return wrap;
  },
};
