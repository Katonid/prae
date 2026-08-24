// Textblock — doppeltippen zum Bearbeiten, Größe passt sich automatisch an.

import { h, clear } from '../util.js';
import { section, toggleRow, field, colorSwatches } from '../ui.js';

export default {
  type: 'text',
  label: 'Text',
  icon: 'text',
  defaultSize: { w: 520, h: 240 },
  minSize: { w: 180, h: 100 },
  createState() {
    return {
      text: 'Doppeltippen zum Schreiben',
      color: '#0f172a',
      background: '#ffffff',
      align: 'center',
      bold: true,
      autoSize: true,
      fontSize: 40,
    };
  },

  mount(ctx) {
    const el = h('div', { class: 'w-text' });
    const view = h('div', { class: 'w-text__view' });
    el.appendChild(view);
    let editing = false;

    function apply() {
      const state = ctx.widget.state;
      el.style.background = state.background || '#ffffff';
      view.style.color = state.color || '#0f172a';
      view.style.textAlign = state.align || 'center';
      view.style.fontWeight = state.bold === false ? '500' : '700';
      view.style.justifyContent = state.align === 'left' ? 'flex-start' : state.align === 'right' ? 'flex-end' : 'center';
      fit();
    }

    function fit() {
      const state = ctx.widget.state;
      if (state.autoSize === false) {
        view.style.fontSize = `${state.fontSize || 32}px`;
        return;
      }
      const text = state.text || '';
      const lines = text.split(/\n/);
      const longest = lines.reduce((max, line) => Math.max(max, line.length), 1);
      const byWidth = (ctx.widget.w - 44) / (longest * 0.58);
      const byHeight = (ctx.widget.h - 44) / (lines.length * 1.28);
      view.style.fontSize = `${Math.max(14, Math.min(120, Math.min(byWidth, byHeight)))}px`;
    }

    function render() {
      if (editing) return;
      view.textContent = ctx.widget.state.text || '';
      apply();
    }

    function startEditing() {
      if (editing || !ctx.isEditing()) return;
      editing = true;
      const state = ctx.widget.state;
      const area = h('textarea', {
        class: 'w-text__edit', 'data-nodrag': '',
        value: state.text || '',
        style: { color: state.color, textAlign: state.align || 'center' },
      });
      clear(el);
      el.appendChild(area);
      area.focus();
      area.setSelectionRange(area.value.length, area.value.length);
      const finish = () => {
        ctx.widget.state.text = area.value;
        ctx.save();
        editing = false;
        clear(el);
        el.appendChild(view);
        render();
      };
      area.addEventListener('blur', finish);
      area.addEventListener('keydown', (event) => {
        if (event.key === 'Escape') {
          event.preventDefault();
          area.blur();
        }
      });
    }

    render();

    return {
      el,
      refresh: render,
      onResize: fit,
      onDoubleClick: startEditing,
      edit: startEditing,
      actions: [{ icon: 'text', title: 'Text bearbeiten', run: startEditing }],
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
      wrap.appendChild(section('Text',
        h('textarea', {
          class: 'input input--area', rows: 5, value: state.text || '',
          oninput: (event) => {
            ctx.widget.state.text = event.target.value;
            ctx.save();
            ctx.refresh();
          },
        })));

      wrap.appendChild(section('Ausrichtung',
        h('div', { class: 'segmented' },
          ['left', 'center', 'right'].map((align) => h('button', {
            class: 'segmented__item' + ((state.align || 'center') === align ? ' is-active' : ''),
            onclick: () => {
              ctx.widget.state.align = align;
              ctx.save();
              rerender();
            },
          }, align === 'left' ? 'Links' : align === 'center' ? 'Mitte' : 'Rechts'))),
        toggleRow('Fett', state.bold !== false, (value) => {
          ctx.widget.state.bold = value;
          ctx.save();
          ctx.refresh();
        })));

      wrap.appendChild(section('Schriftgröße',
        toggleRow('Automatisch an das Feld anpassen', state.autoSize !== false, (value) => {
          ctx.widget.state.autoSize = value;
          ctx.save();
          rerender();
        }),
        state.autoSize === false ? field('Größe (px)', h('input', {
          class: 'input', type: 'range', min: '14', max: '120', step: '2', value: state.fontSize || 32,
          oninput: (event) => {
            ctx.widget.state.fontSize = Number(event.target.value);
            ctx.save();
            ctx.refresh();
          },
        })) : null));

      wrap.appendChild(section('Farben',
        field('Schrift', colorSwatches(['#0f172a', '#ffffff', '#1d4ed8', '#b91c1c', '#15803d', '#a16207'], state.color, (color) => {
          ctx.widget.state.color = color;
          ctx.save();
          rerender();
        })),
        field('Hintergrund', colorSwatches(['#ffffff', '#fef9c3', '#dbeafe', '#dcfce7', '#fee2e2', '#111827'], state.background, (color) => {
          ctx.widget.state.background = color;
          ctx.save();
          rerender();
        }))));
    }

    build();
    return wrap;
  },
};
