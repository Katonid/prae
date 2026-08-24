// Bild — vom Gerät hochgeladen, automatisch verkleinert gespeichert.

import { h, clear, readImageFile, onTap } from '../util.js';
import { icon } from '../icons.js';
import { section, toggleRow, field, button, toast } from '../ui.js';

export default {
  type: 'image',
  label: 'Bild',
  icon: 'image',
  defaultSize: { w: 520, h: 380 },
  minSize: { w: 160, h: 120 },
  createState() {
    return { url: '', fit: 'contain', caption: '', rounded: true };
  },

  mount(ctx) {
    const el = h('div', { class: 'w-image' });

    function pickFile() {
      const input = h('input', { type: 'file', accept: 'image/*', style: { display: 'none' } });
      document.body.appendChild(input);
      input.addEventListener('change', async () => {
        const file = input.files && input.files[0];
        input.remove();
        if (!file) return;
        try {
          const result = await readImageFile(file);
          ctx.widget.state.url = result.url;
          if (result.width && result.height) {
            const ratio = result.height / result.width;
            ctx.setSize(ctx.widget.w, Math.round(ctx.widget.w * ratio) + (ctx.widget.state.caption ? 40 : 0));
          }
          ctx.save();
          render();
        } catch (error) {
          toast('Bild konnte nicht geladen werden.', 'warn');
        }
      });
      input.click();
    }

    function render() {
      const state = ctx.widget.state;
      clear(el);
      if (!state.url) {
        if (!ctx.isEditing()) {
          el.appendChild(h('div', { class: 'w-image__empty w-image__empty--quiet' },
            h('span', { html: icon('image', 34) }), h('span', null, 'Kein Bild')));
          return;
        }
        el.appendChild(onTap(h('button', {
          class: 'w-image__empty', 'data-nodrag': '',
        }, h('span', { html: icon('image', 34) }), h('span', null, 'Bild auswählen')), pickFile));
        return;
      }
      const img = h('img', { class: 'w-image__img', src: state.url, alt: state.caption || '' });
      img.style.objectFit = state.fit === 'cover' ? 'cover' : 'contain';
      img.style.borderRadius = state.rounded === false ? '0' : '14px';
      el.appendChild(img);
      if (state.caption) el.appendChild(h('div', { class: 'w-image__caption' }, state.caption));
    }

    render();
    return {
      el,
      refresh: render,
      pickFile,
      onTap: () => {
        if (!ctx.widget.state.url) pickFile();
      },
      tapNeedsEditing: true,
      actions: [{ icon: 'image', title: 'Bild auswählen', run: pickFile }],
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
      wrap.appendChild(section('Bild',
        button(state.url ? 'Anderes Bild wählen' : 'Bild vom Gerät wählen', {
          icon: 'upload', primary: true, full: true,
          onClick: () => {
            const instance = ctx.instance();
            if (instance && instance.pickFile) instance.pickFile();
          },
        }),
        state.url ? button('Bild entfernen', {
          icon: 'trash', ghost: true, full: true,
          onClick: () => {
            ctx.widget.state.url = '';
            ctx.save();
            rerender();
          },
        }) : null,
        h('p', { class: 'muted small' }, 'Bilder werden verkleinert direkt im Klassenraum gespeichert.')));

      wrap.appendChild(section('Darstellung',
        h('div', { class: 'segmented' },
          h('button', {
            class: 'segmented__item' + (state.fit !== 'cover' ? ' is-active' : ''),
            onclick: () => {
              ctx.widget.state.fit = 'contain';
              ctx.save();
              rerender();
            },
          }, 'Ganz sichtbar'),
          h('button', {
            class: 'segmented__item' + (state.fit === 'cover' ? ' is-active' : ''),
            onclick: () => {
              ctx.widget.state.fit = 'cover';
              ctx.save();
              rerender();
            },
          }, 'Fläche füllen')),
        toggleRow('Abgerundete Ecken', state.rounded !== false, (value) => {
          ctx.widget.state.rounded = value;
          ctx.save();
          ctx.refresh();
        }),
        field('Bildunterschrift', h('input', {
          class: 'input', type: 'text', value: state.caption || '',
          oninput: (event) => {
            ctx.widget.state.caption = event.target.value;
            ctx.save();
            ctx.refresh();
          },
        }))));
    }

    build();
    return wrap;
  },
};
