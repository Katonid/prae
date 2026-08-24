// Zufälliger Name — Kernfunktion: Namen ziehen, mit/ohne Zurücklegen,
// gezogene Namen sehen, zurücklegen oder von Hand als gezogen markieren.

import { h, clear, pickRandom, parseNames, beep } from '../util.js';
import { icon } from '../icons.js';
import { getState, getList, on as onStore, addList } from '../store.js';
import { section, field, toggleRow, button, buttonRow, toast } from '../ui.js';

function namesOf(state) {
  if (state.listId) {
    const list = getList(state.listId);
    if (list) return list.names.slice();
  }
  return Array.isArray(state.localNames) ? state.localNames.slice() : [];
}

function remainingOf(state) {
  const drawn = state.drawn || [];
  return namesOf(state).filter((name) => !drawn.includes(name));
}

function listTitle(state) {
  if (state.listId) {
    const list = getList(state.listId);
    if (list) return list.name;
    return 'Liste fehlt';
  }
  return 'Eigene Liste';
}

export default {
  type: 'randomizer',
  label: 'Zufälliger Name',
  icon: 'randomizer',
  defaultSize: { w: 600, h: 460 },
  minSize: { w: 300, h: 280 },
  createState() {
    return {
      listId: null,
      localNames: [],
      mode: 'exhaust',
      drawn: [],
      current: null,
      showDrawn: true,
      animate: true,
    };
  },

  mount(ctx) {
    const el = h('div', { class: 'w-random' });
    const head = h('div', { class: 'w-random__head' });
    const display = h('div', { class: 'w-random__display' });
    const nameEl = h('div', { class: 'w-random__name' });
    const hintEl = h('div', { class: 'w-random__hint' });
    const drawButton = h('button', {
      class: 'w-random__draw', 'data-nodrag': '', title: 'Namen ziehen',
      html: icon('randomizer', 30),
    });
    const drawnBox = h('div', { class: 'w-random__drawn', 'data-nodrag': '' });

    display.append(nameEl, hintEl);
    el.append(head, display, h('div', { class: 'w-random__actions', 'data-nodrag': '' }, drawButton), drawnBox);

    let spinTimer = null;

    function stopSpin() {
      if (spinTimer) {
        clearInterval(spinTimer);
        spinTimer = null;
      }
    }

    function draw() {
      const state = ctx.widget.state;
      const pool = state.mode === 'repeat' ? namesOf(state) : remainingOf(state);
      if (pool.length === 0) {
        nameEl.textContent = namesOf(state).length === 0 ? 'Keine Namen' : 'Liste ist durch';
        nameEl.classList.add('is-empty');
        hintEl.textContent = namesOf(state).length === 0
          ? 'In den Einstellungen eine Liste wählen oder Namen eintippen.'
          : 'Alle Namen wurden gezogen — zurücksetzen, um neu zu starten.';
        return;
      }
      const finish = (name) => {
        const next = ctx.widget.state;
        next.current = name;
        if (!next.drawn) next.drawn = [];
        if (!next.drawn.includes(name)) next.drawn.push(name);
        ctx.save();
        render();
        beep({ frequency: 660, duration: 0.12, gain: 0.12 });
      };
      const chosen = pickRandom(pool);
      if (!state.animate || pool.length < 2) {
        finish(chosen);
        return;
      }
      stopSpin();
      nameEl.classList.remove('is-empty');
      let ticks = 0;
      const total = 12;
      spinTimer = setInterval(() => {
        ticks += 1;
        nameEl.textContent = pickRandom(pool);
        fitName();
        if (ticks >= total) {
          stopSpin();
          finish(chosen);
        }
      }, 60);
    }

    function fitName() {
      const text = nameEl.textContent || '';
      const boxWidth = Math.max(140, ctx.widget.w - 60);
      const perChar = 0.62;
      let size = Math.min(ctx.widget.h * 0.28, boxWidth / Math.max(4, text.length * perChar));
      size = Math.max(20, Math.min(size, 130));
      nameEl.style.fontSize = `${size}px`;
    }

    function render() {
      const state = ctx.widget.state;
      const all = namesOf(state);
      const drawn = state.drawn || [];
      const remaining = remainingOf(state);

      clear(head);
      head.append(
        h('span', { class: 'w-random__list' }, listTitle(state)),
        h('span', { class: 'w-random__count' },
          state.mode === 'repeat'
            ? `${all.length} Namen · mit Zurücklegen`
            : `${remaining.length} von ${all.length} übrig`));

      nameEl.classList.toggle('is-empty', !state.current);
      nameEl.textContent = state.current || (all.length ? 'Bereit' : 'Keine Namen');
      hintEl.textContent = all.length === 0
        ? 'Einstellungen öffnen und Namen hinzufügen.'
        : (state.mode !== 'repeat' && remaining.length === 0 ? 'Alle Namen gezogen.' : '');
      fitName();

      clear(drawnBox);
      if (state.showDrawn && drawn.length) {
        drawnBox.append(h('div', { class: 'w-random__drawn-head' },
          h('span', null, `Gezogen (${drawn.length})`),
          h('button', {
            class: 'link-button', 'data-nodrag': '', onclick: () => {
              ctx.widget.state.drawn = [];
              ctx.widget.state.current = null;
              ctx.save();
              render();
            },
          }, 'Zurücksetzen')));
        const chips = h('div', { class: 'chips' });
        for (const name of drawn) {
          chips.appendChild(h('button', {
            class: 'chip-name', 'data-nodrag': '', title: 'Zurücklegen (wieder ziehbar machen)',
            onclick: () => {
              const next = ctx.widget.state;
              next.drawn = (next.drawn || []).filter((entry) => entry !== name);
              if (next.current === name) next.current = null;
              ctx.save();
              render();
            },
          }, h('span', null, name), h('span', { class: 'chip-name__x', html: icon('close', 12) })));
        }
        drawnBox.appendChild(chips);
      }
      drawnBox.classList.toggle('is-hidden', !(state.showDrawn && drawn.length));
    }

    drawButton.addEventListener('click', draw);
    const off = onStore('lists-changed', render);
    render();

    return {
      el,
      refresh: render,
      onResize: fitName,
      onDoubleClick: draw,
      destroy() {
        stopSpin();
        off();
      },
    };
  },

  settings(ctx) {
    const wrap = h('div', { class: 'stack' });
    const state = ctx.widget.state;

    function rerender() {
      clear(wrap);
      build();
      ctx.refresh();
    }

    function build() {
      const lists = getState().lists;
      const select = h('select', {
        class: 'input',
        onchange: (event) => {
          const value = event.target.value;
          ctx.widget.state.listId = value === '__local' ? null : value;
          ctx.widget.state.drawn = [];
          ctx.widget.state.current = null;
          ctx.save();
          rerender();
        },
      },
      h('option', { value: '__local' }, 'Eigene Liste (nur dieses Element)'),
      lists.map((list) => h('option', { value: list.id }, `${list.name} (${list.names.length})`)));
      select.value = state.listId || '__local';

      wrap.appendChild(section('Namensliste',
        field('Liste wählen', select),
        buttonRow(
          button('Listen verwalten', {
            icon: 'layers', small: true, onClick: () => ctx.openLists(),
          }),
          state.listId ? null : button('Als Liste speichern', {
            icon: 'download', small: true,
            onClick: async () => {
              const names = ctx.widget.state.localNames || [];
              if (!names.length) {
                toast('Erst Namen eintragen.', 'warn');
                return;
              }
              const list = addList('Neue Klasse', names.slice());
              ctx.widget.state.listId = list.id;
              ctx.save();
              rerender();
              toast('Liste gespeichert.', 'success');
            },
          }))));

      if (!state.listId) {
        const area = h('textarea', {
          class: 'input input--area', rows: 8, placeholder: 'Ein Name pro Zeile',
          value: (state.localNames || []).join('\n'),
          oninput: (event) => {
            ctx.widget.state.localNames = parseNames(event.target.value);
            ctx.save();
            ctx.refresh();
          },
        });
        wrap.appendChild(section('Namen (eine Zeile pro Name)', area));
      }

      const modeRow = h('div', { class: 'segmented' },
        h('button', {
          class: 'segmented__item' + (state.mode !== 'repeat' ? ' is-active' : ''),
          onclick: () => {
            ctx.widget.state.mode = 'exhaust';
            ctx.save();
            rerender();
          },
        }, 'Ohne Zurücklegen'),
        h('button', {
          class: 'segmented__item' + (state.mode === 'repeat' ? ' is-active' : ''),
          onclick: () => {
            ctx.widget.state.mode = 'repeat';
            ctx.save();
            rerender();
          },
        }, 'Mit Zurücklegen'));

      wrap.appendChild(section('Ziehen',
        modeRow,
        h('p', { class: 'muted small' }, state.mode === 'repeat'
          ? 'Jeder Name kann mehrfach gezogen werden.'
          : 'Ein gezogener Name kommt erst nach dem Zurücksetzen wieder in den Topf.'),
        toggleRow('Gezogene Namen im Element anzeigen', state.showDrawn !== false, (value) => {
          ctx.widget.state.showDrawn = value;
          ctx.save();
          rerender();
        }),
        toggleRow('Trommelwirbel-Animation', state.animate !== false, (value) => {
          ctx.widget.state.animate = value;
          ctx.save();
        })));

      const drawn = state.drawn || [];
      const remaining = remainingOf(state);
      const manageBox = h('div', { class: 'stack' });

      if (drawn.length) {
        const chips = h('div', { class: 'chips' }, drawn.map((name) => h('button', {
          class: 'chip-name', title: 'Zurücklegen',
          onclick: () => {
            ctx.widget.state.drawn = (ctx.widget.state.drawn || []).filter((entry) => entry !== name);
            if (ctx.widget.state.current === name) ctx.widget.state.current = null;
            ctx.save();
            rerender();
          },
        }, h('span', null, name), h('span', { class: 'chip-name__x', html: icon('close', 12) }))));
        manageBox.append(h('p', { class: 'muted small' }, 'Tippen legt einen Namen zurück in den Topf.'), chips);
      } else {
        manageBox.appendChild(h('p', { class: 'muted small' }, 'Noch nichts gezogen.'));
      }

      if (remaining.length) {
        const markSelect = h('select', { class: 'input' },
          h('option', { value: '' }, 'Name auswählen …'),
          remaining.map((name) => h('option', { value: name }, name)));
        manageBox.appendChild(field('Namen von Hand als gezogen markieren',
          h('div', { class: 'row' }, markSelect, button('Markieren', {
            small: true,
            onClick: () => {
              const value = markSelect.value;
              if (!value) return;
              const next = ctx.widget.state;
              if (!next.drawn) next.drawn = [];
              if (!next.drawn.includes(value)) next.drawn.push(value);
              ctx.save();
              rerender();
            },
          })),
          'Praktisch, wenn jemand ohne Zufallsziehung an der Reihe war.'));
      }

      manageBox.appendChild(buttonRow(
        button('Alle zurücksetzen', {
          icon: 'reset', small: true,
          onClick: () => {
            ctx.widget.state.drawn = [];
            ctx.widget.state.current = null;
            ctx.save();
            rerender();
          },
        }),
        button('Aktuellen Namen löschen', {
          icon: 'trash', small: true, ghost: true,
          onClick: () => {
            ctx.widget.state.current = null;
            ctx.save();
            rerender();
          },
        })));

      wrap.appendChild(section(`Gezogene Namen (${drawn.length})`, manageBox));
    }

    build();
    return wrap;
  },
};
