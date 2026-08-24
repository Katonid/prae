// Video — Datei vom Gerät oder Link, mit Bedienleiste und Vollbild.

import { h, clear, onTap } from '../util.js';
import { icon } from '../icons.js';
import { mediaUrl, pickMedia, removeMedia, formatSize, looksLike } from '../media.js';
import { section, field, toggleRow, button, buttonRow, toast } from '../ui.js';

export default {
  type: 'video',
  label: 'Video',
  icon: 'video',
  defaultSize: { w: 640, h: 400 },
  minSize: { w: 240, h: 160 },
  createState() {
    return { mediaId: null, url: '', fileName: '', label: '', loop: false, controls: true, muted: false };
  },

  mount(ctx) {
    const el = h('div', { class: 'w-video' });
    let video = null;
    let renderToken = 0;

    function fullscreen() {
      if (!video) return;
      if (video.webkitEnterFullscreen) video.webkitEnterFullscreen();
      else if (video.requestFullscreen) video.requestFullscreen().catch(() => {});
    }

    async function render() {
      const state = ctx.widget.state;
      // Zwei Aufrufe kurz hintereinander dürfen nicht zwei Inhalte einhängen.
      const token = ++renderToken;
      const source = await mediaUrl(state);
      if (token !== renderToken) return;
      clear(el);
      video = null;

      if (!source) {
        const empty = h('div', { class: 'w-video__empty' },
          h('span', { html: icon('video', 34) }),
          h('span', null, state.mediaId ? 'Datei liegt nicht auf diesem Gerät' : 'Kein Video'));
        if (ctx.isEditing()) {
          el.appendChild(onTap(h('button', { class: 'w-video__empty', 'data-nodrag': '' },
            h('span', { html: icon('video', 34) }),
            h('span', null, state.mediaId ? 'Datei fehlt — neu auswählen' : 'Video auswählen')), choose));
        } else {
          el.appendChild(empty);
        }
        return;
      }

      video = h('video', {
        class: 'w-video__player',
        'data-nodrag': '',
        src: source,
        playsinline: '',
        preload: 'metadata',
      });
      video.controls = state.controls !== false;
      video.loop = Boolean(state.loop);
      video.muted = Boolean(state.muted);
      el.appendChild(video);
      if (state.label) el.appendChild(h('div', { class: 'w-video__label' }, state.label));
    }

    async function choose() {
      const result = await pickMedia();
      if (!result) return;
      if (result.error === 'ZU_GROSS') {
        toast('Das Video ist zu groß (mehr als 60 MB). Besser einen Link verwenden.', 'warn');
        return;
      }
      if (!looksLike('video', result.file)) {
        toast('Das sieht nicht nach einer Videodatei aus — falls nichts läuft, bitte MP4 oder MOV wählen.', 'warn');
      }
      const state = ctx.widget.state;
      if (state.mediaId) await removeMedia(state.mediaId);
      state.mediaId = result.id;
      state.url = '';
      state.fileName = `${result.name} · ${formatSize(result.size)}`;
      ctx.save();
      render();
    }

    render();

    return {
      el,
      refresh: render,
      choose,
      onTap() {
        if (!video) {
          if (ctx.isEditing()) choose();
          return;
        }
        if (video.paused) video.play().catch(() => {});
        else video.pause();
      },
      actions: [{ icon: 'expand', title: 'Vollbild', run: fullscreen }],
      destroy() {
        if (video) {
          video.pause();
          video.removeAttribute('src');
        }
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

      wrap.appendChild(section('Quelle',
        h('p', { class: 'muted small' }, state.fileName
          ? `Datei: ${state.fileName}`
          : (state.url ? `Link: ${state.url}` : 'Noch kein Video ausgewählt.')),
        buttonRow(
          button(state.mediaId || state.url ? 'Anderes Video' : 'Video vom Gerät', {
            icon: 'upload', small: true, primary: !state.mediaId && !state.url,
            onClick: () => {
              const instance = ctx.instance();
              if (instance && instance.choose) instance.choose();
            },
          }),
          button('Link', {
            icon: 'share', small: true,
            onClick: () => {
              const value = window.prompt('Adresse des Videos (https://…)', state.url || '');
              if (value === null) return;
              ctx.widget.state.url = value.trim();
              ctx.widget.state.mediaId = null;
              ctx.widget.state.fileName = '';
              ctx.save();
              rerender();
            },
          }),
          state.mediaId || state.url ? button('Entfernen', {
            icon: 'trash', small: true, ghost: true,
            onClick: async () => {
              if (state.mediaId) await removeMedia(state.mediaId);
              ctx.widget.state.mediaId = null;
              ctx.widget.state.url = '';
              ctx.widget.state.fileName = '';
              ctx.save();
              rerender();
            },
          }) : null)));

      wrap.appendChild(section('Abspielen',
        toggleRow('Bedienleiste anzeigen', state.controls !== false, (value) => {
          ctx.widget.state.controls = value;
          ctx.save();
          ctx.refresh();
        }),
        toggleRow('In Schleife wiederholen', Boolean(state.loop), (value) => {
          ctx.widget.state.loop = value;
          ctx.save();
          ctx.refresh();
        }),
        toggleRow('Ohne Ton starten', Boolean(state.muted), (value) => {
          ctx.widget.state.muted = value;
          ctx.save();
          ctx.refresh();
        }),
        field('Beschriftung', h('input', {
          class: 'input', type: 'text', value: state.label || '',
          oninput: (event) => {
            ctx.widget.state.label = event.target.value;
            ctx.save();
            ctx.refresh();
          },
        }))));

      wrap.appendChild(h('p', { class: 'muted small' },
        'Es gehen MP4, MOV, M4V und WebM. Die Auswahl zeigt bewusst alle Dateien an, weil iPadOS sonst Dateien ausgraut, '
        + 'deren Art das Netzlaufwerk oder iCloud nicht mitliefert. '
        + 'Videos vom Gerät bleiben auf diesem Gerät und werden beim Teilen über einen Code nicht mitgeschickt. '
        + 'Ein Link funktioniert überall. Für Vollbild das Symbol in der kleinen Leiste über dem Element nutzen.'));
    }

    build();
    return wrap;
  },
};
