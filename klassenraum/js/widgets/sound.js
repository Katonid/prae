// Klangtasten — auf Tastendruck läuft eine Klangdatei (aus dem Gerät oder von einem Link).

import { h, clear, uid, onTap } from '../util.js';
import { icon } from '../icons.js';
import { mediaUrl, pickMedia, removeMedia, formatSize } from '../media.js';
import { section, field, toggleRow, button, buttonRow, toast } from '../ui.js';

const COLORS = ['#6366f1', '#0ea5e9', '#10b981', '#f59e0b', '#ef4444', '#a855f7'];

function defaultEntry(index = 0) {
  return { id: uid('snd'), label: 'Klang', mediaId: null, url: '', fileName: '', color: COLORS[index % COLORS.length] };
}

export default {
  type: 'sound',
  label: 'Klang',
  icon: 'sound',
  defaultSize: { w: 340, h: 220 },
  minSize: { w: 180, h: 130 },
  createState() {
    return { entries: [defaultEntry()], volume: 0.85, title: '' };
  },

  mount(ctx) {
    const el = h('div', { class: 'w-sound' });
    const titleEl = h('div', { class: 'w-sound__title' });
    const grid = h('div', { class: 'w-sound__grid', 'data-nodrag': '' });
    el.append(titleEl, grid);

    const player = new Audio();
    player.preload = 'none';
    let playingId = null;

    player.addEventListener('ended', () => {
      playingId = null;
      render();
    });
    player.addEventListener('error', () => {
      playingId = null;
      render();
    });

    async function play(entry) {
      const state = ctx.widget.state;
      if (playingId === entry.id) {
        player.pause();
        player.currentTime = 0;
        playingId = null;
        render();
        return;
      }
      const source = await mediaUrl(entry);
      if (!source) {
        toast(entry.mediaId ? 'Die Datei liegt nicht auf diesem Gerät.' : 'Erst eine Klangdatei auswählen.', 'warn');
        return;
      }
      player.src = source;
      player.volume = typeof state.volume === 'number' ? state.volume : 0.85;
      playingId = entry.id;
      render();
      try {
        await player.play();
      } catch (error) {
        playingId = null;
        toast('Der Klang lässt sich nicht abspielen.', 'warn');
        render();
      }
    }

    function render() {
      const state = ctx.widget.state;
      const entries = state.entries && state.entries.length ? state.entries : [defaultEntry()];
      titleEl.textContent = state.title || '';
      titleEl.classList.toggle('is-hidden', !state.title);

      clear(grid);
      for (const entry of entries) {
        const active = playingId === entry.id;
        const ready = Boolean(entry.mediaId || entry.url);
        grid.appendChild(onTap(h('button', {
          class: 'w-sound__button' + (active ? ' is-playing' : '') + (ready ? '' : ' is-empty'),
          'data-nodrag': '',
          style: { '--tone': entry.color || COLORS[0] },
          title: entry.fileName || entry.url || 'Noch keine Datei',
        },
        h('span', { class: 'w-sound__icon', html: icon(active ? 'pause' : 'play', 20) }),
        h('span', { class: 'w-sound__label' }, entry.label || 'Klang')), () => play(entry)));
      }
    }

    render();

    return {
      el,
      refresh: render,
      onTap() {
        const entries = ctx.widget.state.entries || [];
        if (entries.length === 1) play(entries[0]);
      },
      destroy() {
        player.pause();
        player.src = '';
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

    function entryRow(entry, index) {
      const box = h('div', { class: 'media-row' });
      box.append(
        h('div', { class: 'row' },
          field('Beschriftung', h('input', {
            class: 'input', type: 'text', value: entry.label || '',
            oninput: (event) => {
              entry.label = event.target.value;
              ctx.save();
              ctx.refresh();
            },
          }))),
        h('p', { class: 'muted small' }, entry.fileName
          ? `Datei: ${entry.fileName}`
          : (entry.url ? `Link: ${entry.url}` : 'Noch keine Datei ausgewählt.')),
        buttonRow(
          button(entry.mediaId || entry.url ? 'Andere Datei' : 'Klangdatei wählen', {
            icon: 'upload', small: true, primary: !entry.mediaId && !entry.url,
            onClick: async () => {
              const result = await pickMedia('audio/*');
              if (!result) return;
              if (result.error === 'ZU_GROSS') {
                toast('Die Datei ist zu groß (mehr als 60 MB).', 'warn');
                return;
              }
              if (entry.mediaId) await removeMedia(entry.mediaId);
              entry.mediaId = result.id;
              entry.url = '';
              entry.fileName = `${result.name} · ${formatSize(result.size)}`;
              if (!entry.label || entry.label === 'Klang') {
                entry.label = result.name.replace(/\.[a-z0-9]+$/i, '').slice(0, 24);
              }
              ctx.save();
              rerender();
            },
          }),
          button('Link', {
            icon: 'share', small: true,
            onClick: () => {
              const value = window.prompt('Adresse der Klangdatei (https://…)', entry.url || '');
              if (value === null) return;
              entry.url = value.trim();
              entry.mediaId = null;
              entry.fileName = '';
              ctx.save();
              rerender();
            },
          }),
          (ctx.widget.state.entries || []).length > 1 ? button('Entfernen', {
            icon: 'trash', small: true, ghost: true,
            onClick: async () => {
              if (entry.mediaId) await removeMedia(entry.mediaId);
              ctx.widget.state.entries.splice(index, 1);
              ctx.save();
              rerender();
            },
          }) : null),
        h('div', { class: 'swatches' }, COLORS.map((color) => h('button', {
          class: 'swatch swatch--small' + (entry.color === color ? ' is-active' : ''),
          style: { background: color },
          onclick: () => {
            entry.color = color;
            ctx.save();
            rerender();
          },
        }))));
      return box;
    }

    function build() {
      const state = ctx.widget.state;
      if (!Array.isArray(state.entries) || !state.entries.length) state.entries = [defaultEntry()];

      wrap.appendChild(section('Tasten',
        state.entries.map((entry, index) => entryRow(entry, index)),
        buttonRow(button('Weitere Taste', {
          icon: 'plus', small: true,
          onClick: () => {
            state.entries.push(defaultEntry(state.entries.length));
            ctx.save();
            rerender();
          },
        }))));

      wrap.appendChild(section('Weiteres',
        field(`Lautstärke ${Math.round((state.volume ?? 0.85) * 100)} %`, h('input', {
          class: 'input', type: 'range', min: '0.1', max: '1', step: '0.05', value: state.volume ?? 0.85,
          oninput: (event) => {
            ctx.widget.state.volume = Number(event.target.value);
            ctx.save();
          },
          onchange: () => rerender(),
        })),
        field('Überschrift (optional)', h('input', {
          class: 'input', type: 'text', value: state.title || '',
          oninput: (event) => {
            ctx.widget.state.title = event.target.value;
            ctx.save();
            ctx.refresh();
          },
        }))));

      wrap.appendChild(h('p', { class: 'muted small' },
        'Dateien vom Gerät bleiben auf diesem Gerät — beim Teilen über einen Code werden sie nicht mitgeschickt. '
        + 'Ein Link funktioniert dagegen überall.'));
    }

    build();
    return wrap;
  },
};
