// Checkliste / Tagesablauf — Punkte abhaken, Fortschritt sehen.

import { h, clear, uid, beep, onTap } from '../util.js';
import { icon } from '../icons.js';
import { section, toggleRow, field, button } from '../ui.js';

export default {
  type: 'checklist',
  label: 'Tagesablauf',
  icon: 'checklist',
  // Die Schrift richtet sich nach der Feldbreite (siehe contentScale).
  scaleBy: 'width',
  defaultSize: { w: 480, h: 380 },
  minSize: { w: 260, h: 200 },
  createState() {
    return { title: 'Tagesablauf', items: [], showProgress: true, strikeDone: true };
  },

  mount(ctx) {
    const el = h('div', { class: 'w-check' });
    const titleEl = h('div', { class: 'w-check__title' });
    const progressEl = h('div', { class: 'w-check__progress' }, h('span', { class: 'w-check__bar' }));
    const listEl = h('div', { class: 'w-check__list', 'data-nodrag': '' });
    const addRow = h('div', { class: 'w-check__add', 'data-nodrag': '' });
    el.append(titleEl, progressEl, listEl, addRow);

    function render() {
      const state = ctx.widget.state;
      const items = state.items || [];
      titleEl.textContent = state.title || 'Tagesablauf';
      const done = items.filter((item) => item.done).length;
      progressEl.classList.toggle('is-hidden', state.showProgress === false || items.length === 0);
      progressEl.querySelector('.w-check__bar').style.width = items.length ? `${(done / items.length) * 100}%` : '0%';
      progressEl.setAttribute('data-count', `${done}/${items.length}`);

      clear(listEl);
      for (const item of items) {
        listEl.appendChild(onTap(h('button', {
          class: 'w-check__item' + (item.done ? ' is-done' : '') + (state.strikeDone === false ? ' no-strike' : ''),
          'data-nodrag': '',
        },
        h('span', { class: 'w-check__box', html: item.done ? icon('check', 16) : '' }),
        h('span', { class: 'w-check__text' }, item.text)), () => {
          item.done = !item.done;
          ctx.save();
          if (item.done) beep({ frequency: 880, duration: 0.09, gain: 0.09 });
          render();
        }));
      }
      if (!items.length) {
        listEl.appendChild(h('p', { class: 'muted small' }, 'Noch keine Punkte — unten hinzufügen.'));
      }
      // Direkt und noch einmal nach dem Layout — beim ersten Aufbau ist die
      // Breite noch 0, erst danach lässt sich messen.
      fitWidth();
      window.requestAnimationFrame(fitWidth);

      clear(addRow);
      addRow.classList.toggle('is-hidden', !ctx.isEditing());
      if (!ctx.isEditing()) return;
      const input = h('input', { class: 'input input--flat', type: 'text', placeholder: 'Punkt hinzufügen …', 'data-nodrag': '' });
      const add = () => {
        const text = input.value.trim();
        if (!text) return;
        if (!ctx.widget.state.items) ctx.widget.state.items = [];
        ctx.widget.state.items.push({ id: uid('i'), text, done: false });
        input.value = '';
        ctx.save();
        render();
        setTimeout(() => {
          const next = addRow.querySelector('input');
          if (next) next.focus();
        }, 0);
      };
      input.addEventListener('keydown', (event) => {
        if (event.key === 'Enter') add();
      });
      addRow.append(input, onTap(h('button', {
        class: 'icon-button', 'data-nodrag': '', title: 'Hinzufügen', html: icon('plus', 18),
      }), add));
    }

    /**
     * Die Schrift der Zeilen so wählen, dass die längste Zeile die Breite des
     * Feldes ausfüllt — kürzere Listen bekommen dadurch richtig große Schrift.
     * Zwei Durchläufe, weil Kästchen und Abstände mit der Schrift mitwachsen.
     */
    const meter = document.createElement('canvas').getContext('2d');

    function fitWidth() {
      el.style.setProperty('--check-fit', '1');
      for (let pass = 0; pass < 2; pass += 1) {
        const texts = Array.from(listEl.querySelectorAll('.w-check__text'));
        if (!texts.length) return;
        let worst = Infinity;
        for (const text of texts) {
          const room = text.clientWidth;
          const style = window.getComputedStyle(text);
          meter.font = `${style.fontWeight} ${style.fontSize} ${style.fontFamily}`;
          const need = meter.measureText(text.textContent || '').width;
          if (need > 0 && room > 0) worst = Math.min(worst, room / need);
        }
        if (!Number.isFinite(worst)) return;
        const current = parseFloat(el.style.getPropertyValue('--check-fit')) || 1;
        const factor = Math.min(3, Math.max(0.7, current * worst * 0.95));
        el.style.setProperty('--check-fit', factor.toFixed(3));
      }
    }

    render();
    return { el, refresh: render, onResize: fitWidth };
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
      const items = state.items || [];

      wrap.appendChild(section('Überschrift',
        field('Titel', h('input', {
          class: 'input', type: 'text', value: state.title || '',
          oninput: (event) => {
            ctx.widget.state.title = event.target.value;
            ctx.save();
            ctx.refresh();
          },
        }))));

      const rows = h('div', { class: 'stack' });
      items.forEach((item, index) => {
        rows.appendChild(h('div', { class: 'sort-row' },
          h('input', {
            class: 'input', type: 'text', value: item.text,
            oninput: (event) => {
              item.text = event.target.value;
              ctx.save();
              ctx.refresh();
            },
          }),
          h('button', {
            class: 'icon-button', title: 'Nach oben', disabled: index === 0,
            onclick: () => {
              const list = ctx.widget.state.items;
              [list[index - 1], list[index]] = [list[index], list[index - 1]];
              ctx.save();
              rerender();
            },
            html: icon('chevron', 16),
            style: { transform: 'rotate(180deg)' },
          }),
          h('button', {
            class: 'icon-button', title: 'Nach unten', disabled: index === items.length - 1,
            onclick: () => {
              const list = ctx.widget.state.items;
              [list[index + 1], list[index]] = [list[index], list[index + 1]];
              ctx.save();
              rerender();
            },
            html: icon('chevron', 16),
          }),
          h('button', {
            class: 'icon-button icon-button--danger', title: 'Löschen',
            onclick: () => {
              ctx.widget.state.items = ctx.widget.state.items.filter((entry) => entry.id !== item.id);
              ctx.save();
              rerender();
            },
            html: icon('trash', 16),
          })));
      });

      wrap.appendChild(section(`Punkte (${items.length})`, rows,
        h('div', { class: 'button-row' },
          button('Punkt hinzufügen', {
            icon: 'plus', small: true,
            onClick: () => {
              if (!ctx.widget.state.items) ctx.widget.state.items = [];
              ctx.widget.state.items.push({ id: uid('i'), text: 'Neuer Punkt', done: false });
              ctx.save();
              rerender();
            },
          }),
          button('Alle Haken lösen', {
            icon: 'reset', small: true, ghost: true,
            onClick: () => {
              (ctx.widget.state.items || []).forEach((entry) => { entry.done = false; });
              ctx.save();
              rerender();
            },
          }))));

      const bulk = h('textarea', {
        class: 'input input--area', rows: 6, placeholder: 'Ein Punkt pro Zeile',
        value: items.map((item) => item.text).join('\n'),
      });
      wrap.appendChild(section('Schnell erfassen', bulk,
        button('Liste ersetzen', {
          small: true, primary: true,
          onClick: () => {
            const lines = bulk.value.split(/\r?\n/).map((line) => line.trim()).filter(Boolean);
            ctx.widget.state.items = lines.map((text) => ({ id: uid('i'), text, done: false }));
            ctx.save();
            rerender();
          },
        })));

      wrap.appendChild(section('Anzeige',
        toggleRow('Fortschrittsbalken', state.showProgress !== false, (value) => {
          ctx.widget.state.showProgress = value;
          ctx.save();
          ctx.refresh();
        }),
        toggleRow('Erledigtes durchstreichen', state.strikeDone !== false, (value) => {
          ctx.widget.state.strikeDone = value;
          ctx.save();
          ctx.refresh();
        })));
    }

    build();
    return wrap;
  },
};
