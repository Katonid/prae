// Zufälliger Name — Kernfunktion: Namen ziehen, mit/ohne Zurücklegen,
// gezogene Namen sehen, zurücklegen oder von Hand als gezogen markieren.
// Der gezogene Name kann schrittweise aufgedeckt werden, damit die Klasse raten kann.

import { h, clear, pickRandom, parseNames, beep, onTap, confetti, reducedMotion, randomInt } from '../util.js';
import { icon } from '../icons.js';
import { getState, getList, on as onStore, addList } from '../store.js';
import { section, field, toggleRow, button, buttonRow, toast } from '../ui.js';
import { SPIN_SOUNDS, spinSoundById, spinTick, spinEnd, previewSpinSound } from '../sfx.js';

// Feines Raster: viele kleine Kacheln geben pro Tipp wenig preis.
const MOSAIC_COLS = 28;
const MOSAIC_ROWS = 10;
const MOSAIC_TILES = MOSAIC_COLS * MOSAIC_ROWS;
const MOSAIC_STEPS = 12;
const MOSAIC_PER_TAP = Math.ceil(MOSAIC_TILES / MOSAIC_STEPS);
const BLUR_STEPS = 10;

// Das Auslosen läuft wie ein Glücksrad aus: erst schnell, dann immer langsamer.
const SPIN_STEPS = 18;
const SPIN_FAST = 45;
const SPIN_SLOW = 210;

function spinDelay(step) {
  const progress = step / (SPIN_STEPS - 1);
  return SPIN_FAST + Math.pow(progress, 2.4) * (SPIN_SLOW - SPIN_FAST);
}

const REVEAL_MODES = [
  { id: 'instant', label: 'Sofort', hint: 'Der Name steht sofort da.' },
  { id: 'mosaik', label: 'Mosaik', hint: 'Feine Kacheln verschwinden nach und nach — zwölf Tipps bis zum ganzen Namen.' },
  { id: 'blur', label: 'Unschärfe', hint: 'Erst nur ein Farbnebel, mit jedem Tipp schärfer — zehn Tipps.' },
  { id: 'letters', label: 'Buchstaben', hint: 'Ein Buchstabe nach dem anderen erscheint.' },
];

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

function revealMode(state) {
  const mode = state.reveal || 'mosaik';
  return REVEAL_MODES.some((entry) => entry.id === mode) ? mode : 'mosaik';
}

/** Zeichen, die verdeckt werden können (Buchstaben und Ziffern). */
function maskableIndexes(name) {
  const list = [];
  for (let i = 0; i < name.length; i += 1) {
    if (/[\p{L}\p{N}]/u.test(name[i])) list.push(i);
  }
  return list;
}

function revealTotal(state, name) {
  const mode = revealMode(state);
  if (mode === 'instant') return 0;
  if (mode === 'mosaik') return MOSAIC_TILES;
  if (mode === 'blur') return BLUR_STEPS;
  return Math.max(1, maskableIndexes(name || '').length);
}

function revealParts(state) {
  return Array.isArray(state.revealParts) ? state.revealParts : [];
}

function isRevealed(state, name) {
  if (!name) return true;
  if (revealMode(state) === 'instant') return true;
  return revealParts(state).length >= revealTotal(state, name);
}

/** Deckt den nächsten Schritt auf; gibt true zurück, wenn der Name danach ganz zu sehen ist. */
function revealStep(state, name) {
  const total = revealTotal(state, name);
  const done = new Set(revealParts(state));
  const open = [];
  for (let i = 0; i < total; i += 1) {
    if (!done.has(i)) open.push(i);
  }
  const count = revealMode(state) === 'mosaik' ? MOSAIC_PER_TAP : 1;
  for (let i = 0; i < count && open.length; i += 1) {
    const pick = open.splice(randomInt(open.length), 1)[0];
    done.add(pick);
  }
  state.revealParts = Array.from(done);
  return state.revealParts.length >= total;
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
      showDrawn: 'edit',
      animate: true,
      reveal: 'mosaik',
      revealParts: [],
      spinSound: 'karten',
    };
  },

  mount(ctx) {
    const el = h('div', { class: 'w-random' });
    const head = h('div', { class: 'w-random__head' });
    const display = h('div', { class: 'w-random__display' });
    const nameBox = h('div', { class: 'w-random__namebox' });
    const nameEl = h('div', { class: 'w-random__name' });
    const maskEl = h('div', { class: 'w-random__mask' });
    const hintEl = h('div', { class: 'w-random__hint' });
    const drawnBox = h('div', { class: 'w-random__drawn', 'data-nodrag': '' });

    nameBox.append(nameEl, maskEl);
    display.append(nameBox, hintEl);
    // Bewusst ohne Knöpfe: Gezogen und aufgedeckt wird durch Tippen auf die Karte.
    el.append(head, display, drawnBox);

    let spinTimer = null;
    let spinning = false;
    let armed = false;

    function stopSpin() {
      if (spinTimer) clearTimeout(spinTimer);
      spinTimer = null;
      spinning = false;
      nameEl.classList.remove('is-spinning');
    }

    function celebrate() {
      nameEl.classList.remove('is-pop');
      void nameEl.offsetWidth;
      nameEl.classList.add('is-pop');
      confetti(display);
      beep({ frequency: 720, duration: 0.12, gain: 0.12 });
      beep({ frequency: 980, duration: 0.16, gain: 0.1, delay: 0.1 });
    }

    function draw() {
      if (spinning) return;
      const state = ctx.widget.state;
      const pool = state.mode === 'repeat' ? namesOf(state) : remainingOf(state);
      if (pool.length === 0) {
        const empty = namesOf(state).length === 0;
        nameEl.textContent = empty ? 'Keine Namen' : 'Liste ist durch';
        nameEl.classList.add('is-empty');
        hintEl.textContent = empty
          ? 'Einstellungen öffnen und Namen eintragen.'
          : 'Alle Namen gezogen — unten zurücksetzen.';
        fitName();
        return;
      }

      const finish = (name) => {
        const next = ctx.widget.state;
        next.current = name;
        next.revealParts = [];
        if (!next.drawn) next.drawn = [];
        if (!next.drawn.includes(name)) next.drawn.push(name);
        ctx.save();
        render();
        if (isRevealed(next, name)) celebrate();
        else beep({ frequency: 520, duration: 0.1, gain: 0.1 });
      };

      const chosen = pickRandom(pool);
      if (state.animate === false || pool.length < 2 || reducedMotion()) {
        finish(chosen);
        return;
      }
      stopSpin();
      spinning = true;
      nameEl.classList.remove('is-empty', 'is-pop');
      nameEl.classList.add('is-spinning');
      maskEl.classList.add('is-hidden');
      const sound = spinSoundById(state.spinSound).id;

      const stepOnce = (index) => {
        nameEl.textContent = pickRandom(pool);
        fitName();
        spinTick(sound, index / (SPIN_STEPS - 1));
        if (index >= SPIN_STEPS - 1) {
          stopSpin();
          spinEnd(sound);
          finish(chosen);
          return;
        }
        spinTimer = setTimeout(() => stepOnce(index + 1), spinDelay(index));
      };
      stepOnce(0);
    }

    function step() {
      const state = ctx.widget.state;
      if (!state.current || isRevealed(state, state.current)) {
        draw();
        return;
      }
      const complete = revealStep(state, state.current);
      ctx.save();
      render();
      if (complete) celebrate();
      else beep({ frequency: 620, duration: 0.07, gain: 0.07 });
    }

    function revealAll() {
      const state = ctx.widget.state;
      if (!state.current || isRevealed(state, state.current)) return;
      const total = revealTotal(state, state.current);
      state.revealParts = Array.from({ length: total }, (_, index) => index);
      ctx.save();
      render();
      celebrate();
    }

    function fitName() {
      const text = nameEl.textContent || '';
      const boxWidth = Math.max(140, ctx.widget.w - 70);
      let size = Math.min(ctx.widget.h * 0.29, boxWidth / Math.max(4, text.length * 0.6));
      size = Math.max(20, Math.min(size, 128));
      nameEl.style.fontSize = `${size}px`;
    }

    function renderMask(state, name, hidden) {
      const mode = revealMode(state);
      nameEl.style.filter = '';
      maskEl.classList.toggle('is-hidden', !hidden || mode !== 'mosaik');
      if (!hidden) {
        clear(maskEl);
        return;
      }
      if (mode === 'blur') {
        const progress = Math.min(1, revealParts(state).length / BLUR_STEPS);
        // Die Unschärfe richtet sich nach der Schriftgröße — sonst bleibt ein
        // großer Name auch mit festem Wert lesbar.
        const size = parseFloat(nameEl.style.fontSize) || 48;
        const amount = size * 0.42 * Math.pow(1 - progress, 1.5) + 1.5;
        nameEl.style.filter = `blur(${amount.toFixed(1)}px)`;
        clear(maskEl);
        return;
      }
      if (mode !== 'mosaik') {
        clear(maskEl);
        return;
      }
      const open = new Set(revealParts(state));
      if (maskEl.childElementCount !== MOSAIC_TILES) {
        clear(maskEl);
        maskEl.style.gridTemplateColumns = `repeat(${MOSAIC_COLS}, 1fr)`;
        maskEl.style.gridTemplateRows = `repeat(${MOSAIC_ROWS}, 1fr)`;
        for (let i = 0; i < MOSAIC_TILES; i += 1) maskEl.appendChild(h('span', { class: 'w-random__tile' }));
      }
      Array.from(maskEl.children).forEach((tile, index) => {
        tile.classList.toggle('is-open', open.has(index));
      });
      void name;
    }

    function render() {
      const state = ctx.widget.state;
      const all = namesOf(state);
      const drawn = state.drawn || [];
      const remaining = remainingOf(state);
      const name = state.current;
      const hidden = Boolean(name) && !isRevealed(state, name);
      const mode = revealMode(state);

      clear(head);
      head.append(
        h('span', { class: 'w-random__list' }, listTitle(state)),
        h('span', { class: 'w-random__count' },
          state.mode === 'repeat' ? `${all.length} Namen` : `${remaining.length}/${all.length}`));

      nameEl.classList.toggle('is-empty', !name);
      if (name && hidden && mode === 'letters') {
        const maskable = new Set(maskableIndexes(name));
        const open = new Set(revealParts(state).map((index) => maskableIndexes(name)[index]));
        nameEl.textContent = Array.from(name)
          .map((char, index) => (maskable.has(index) && !open.has(index) ? '•' : char))
          .join('');
      } else {
        nameEl.textContent = name || (all.length ? 'Bereit' : 'Keine Namen');
      }
      fitName();
      renderMask(state, name, hidden);

      if (all.length === 0) {
        hintEl.textContent = 'Einstellungen öffnen und Namen eintragen.';
      } else if (hidden) {
        const perTap = mode === 'mosaik' ? MOSAIC_PER_TAP : 1;
        const total = Math.ceil(revealTotal(state, name) / perTap);
        const done = Math.min(total, Math.ceil(revealParts(state).length / perTap));
        hintEl.textContent = `Tippen deckt auf — Schritt ${done} von ${total}`;
      } else if (state.mode !== 'repeat' && remaining.length === 0) {
        hintEl.textContent = 'Alle Namen gezogen.';
      } else {
        hintEl.textContent = armed
          ? 'Bereit — der nächste Tipp zieht'
          : 'Antippen, dann nochmal tippen zum Ziehen';
      }

      const showDrawn = state.showDrawn === true ? 'edit' : (state.showDrawn || 'edit');
      const mayShow = showDrawn === 'always' || (showDrawn === 'edit' && ctx.isEditing());
      // Der aktuelle Name bleibt versteckt, solange er noch nicht aufgedeckt ist.
      const visibleDrawn = hidden ? drawn.filter((entry) => entry !== name) : drawn;

      clear(drawnBox);
      const show = mayShow && visibleDrawn.length > 0;
      if (show) {
        drawnBox.append(h('div', { class: 'w-random__drawn-head' },
          h('span', null, `Gezogen (${visibleDrawn.length})`),
          onTap(h('button', { class: 'link-button', 'data-nodrag': '' }, 'Zurücksetzen'), reset)));
        const chips = h('div', { class: 'chips' });
        for (const entry of visibleDrawn) {
          chips.appendChild(onTap(h('button', {
            class: 'chip-name', 'data-nodrag': '', title: 'Zurücklegen (wieder ziehbar machen)',
          }, h('span', null, entry), h('span', { class: 'chip-name__x', html: icon('close', 12) })), () => {
            const next = ctx.widget.state;
            next.drawn = (next.drawn || []).filter((item) => item !== entry);
            if (next.current === entry) next.current = null;
            ctx.save();
            render();
          }));
        }
        drawnBox.appendChild(chips);
      }
      // In der Unterrichtsansicht steht nichts unter dem Namen; zurückgesetzt wird
      // beim Bearbeiten oder in den Einstellungen.
      drawnBox.classList.toggle('is-hidden', !show);
    }

    function reset() {
      const state = ctx.widget.state;
      state.drawn = [];
      state.current = null;
      state.revealParts = [];
      ctx.save();
      render();
    }

    const off = onStore('lists-changed', render);
    render();

    return {
      el,
      refresh: render,
      onResize: fitName,
      onTap: step,
      // Erst der zweite Tipp löst aus — sonst zieht ein versehentlicher Tipp einen Namen.
      tapNeedsFocus: true,
      // Solange etwas verdeckt ist, bietet die kleine Leiste beim Bearbeiten das Augensymbol an.
      get actions() {
        const state = ctx.widget.state;
        if (!state.current || isRevealed(state, state.current)) return [];
        return [{ icon: 'eye', title: 'Namen ganz aufdecken', run: revealAll }];
      },
      onArmedChange(value) {
        armed = value;
        render();
      },
      destroy() {
        stopSpin();
        off();
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
      const lists = getState().lists;
      const select = h('select', {
        class: 'input',
        onchange: (event) => {
          const value = event.target.value;
          ctx.widget.state.listId = value === '__local' ? null : value;
          ctx.widget.state.drawn = [];
          ctx.widget.state.current = null;
          ctx.widget.state.revealParts = [];
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
          button('Listen verwalten', { icon: 'layers', small: true, onClick: () => ctx.openLists() }),
          state.listId ? null : button('Als Liste speichern', {
            icon: 'download', small: true,
            onClick: () => {
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
        wrap.appendChild(section('Namen (eine Zeile pro Name)', h('textarea', {
          class: 'input input--area', rows: 8, placeholder: 'Ein Name pro Zeile',
          value: (state.localNames || []).join('\n'),
          oninput: (event) => {
            ctx.widget.state.localNames = parseNames(event.target.value);
            ctx.save();
            ctx.refresh();
          },
        })));
      }

      wrap.appendChild(section('Ziehen',
        h('div', { class: 'segmented' },
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
          }, 'Mit Zurücklegen')),
        h('p', { class: 'muted small' }, state.mode === 'repeat'
          ? 'Jeder Name kann mehrfach gezogen werden.'
          : 'Ein gezogener Name kommt erst nach dem Zurücksetzen wieder in den Topf.'),
        toggleRow('Namen durchlaufen lassen', state.animate !== false, (value) => {
          ctx.widget.state.animate = value;
          ctx.save();
          rerender();
        }, 'Aus: Der Name steht sofort da — dann gibt es auch keinen Klang.')));

      const sound = spinSoundById(state.spinSound).id;
      wrap.appendChild(section('Klang beim Ziehen',
        h('div', { class: 'chips' }, SPIN_SOUNDS.map((entry) => h('button', {
          class: 'chip' + (sound === entry.id ? ' is-active' : ''),
          onclick: () => {
            ctx.widget.state.spinSound = entry.id;
            ctx.save();
            // Direkt zum Anhören — so lässt sich vergleichen, ohne zu ziehen.
            previewSpinSound(entry.id);
            rerender();
          },
        }, entry.label))),
        h('p', { class: 'muted small' }, `${spinSoundById(sound).hint} Zum Anhören auf die Auswahl tippen.`),
        state.animate === false
          ? h('p', { class: 'muted small' }, 'Zurzeit ohne Wirkung: „Namen durchlaufen lassen" ist ausgeschaltet.')
          : null));

      const current = revealMode(state);
      wrap.appendChild(section('Aufdecken',
        h('div', { class: 'chips' }, REVEAL_MODES.map((entry) => h('button', {
          class: 'chip' + (current === entry.id ? ' is-active' : ''),
          onclick: () => {
            const next = ctx.widget.state;
            next.reveal = entry.id;
            // Der gerade sichtbare Name bleibt sichtbar; die neue Art gilt ab dem nächsten Ziehen.
            const total = revealTotal(next, next.current || '');
            next.revealParts = Array.from({ length: total }, (_, index) => index);
            ctx.save();
            rerender();
          },
        }, entry.label))),
        h('p', { class: 'muted small' },
          `${(REVEAL_MODES.find((entry) => entry.id === current) || REVEAL_MODES[0]).hint} `
          + (current === 'instant' ? '' : 'Jeder Tipp auf die Karte deckt einen Schritt auf. '
            + 'Beim Bearbeiten zeigt das Augensymbol in der kleinen Leiste sofort alles.'))));

      const showDrawn = state.showDrawn === true ? 'edit' : (state.showDrawn || 'edit');
      wrap.appendChild(section('Gezogene Namen anzeigen',
        h('div', { class: 'segmented' },
          [['never', 'Nie'], ['edit', 'Beim Bearbeiten'], ['always', 'Immer']].map(([value, label]) => h('button', {
            class: 'segmented__item' + (showDrawn === value ? ' is-active' : ''),
            onclick: () => {
              ctx.widget.state.showDrawn = value;
              ctx.save();
              rerender();
            },
          }, label))),
        h('p', { class: 'muted small' },
          'In der Unterrichtsansicht bleibt die Liste bei „Beim Bearbeiten“ verborgen — so lässt sich nicht ablesen, wer noch fehlt.')));

      const drawn = state.drawn || [];
      const remaining = remainingOf(state);
      const manageBox = h('div', { class: 'stack' });

      if (drawn.length) {
        manageBox.append(
          h('p', { class: 'muted small' }, 'Tippen legt einen Namen zurück in den Topf.'),
          h('div', { class: 'chips' }, drawn.map((name) => h('button', {
            class: 'chip-name', title: 'Zurücklegen',
            onclick: () => {
              ctx.widget.state.drawn = (ctx.widget.state.drawn || []).filter((entry) => entry !== name);
              if (ctx.widget.state.current === name) ctx.widget.state.current = null;
              ctx.save();
              rerender();
            },
          }, h('span', null, name), h('span', { class: 'chip-name__x', html: icon('close', 12) })))));
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
            ctx.widget.state.revealParts = [];
            ctx.save();
            rerender();
          },
        }),
        button('Aktuellen Namen löschen', {
          icon: 'trash', small: true, ghost: true,
          onClick: () => {
            ctx.widget.state.current = null;
            ctx.widget.state.revealParts = [];
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
