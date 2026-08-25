// Klangtasten — auf Tastendruck läuft eine Klangdatei (aus dem Gerät oder von einem Link).

import { h, clear, uid, onTap } from '../util.js';
import { icon } from '../icons.js';
import { mediaUrl, pickMedia, removeMedia, formatSize, looksLike } from '../media.js';
import { section, field, toggleRow, button, buttonRow, toast } from '../ui.js';

const COLORS = ['#6366f1', '#0ea5e9', '#10b981', '#f59e0b', '#ef4444', '#a855f7'];

// Vorschläge für das Symbol auf einer Taste — freie Eingabe geht zusätzlich.
const SYMBOLS = ['🎵', '🔔', '⏰', '👏', '🤫', '🧹', '🍎', '🚪', '🎉', '☀️', '🐦', '🌊'];

function defaultEntry(index = 0) {
  // color2 gesetzt = Farbverlauf von color nach color2.
  return { id: uid('snd'), label: 'Klang', icon: '', mediaId: null, url: '', fileName: '', color: COLORS[index % COLORS.length], color2: '' };
}

export default {
  type: 'sound',
  label: 'Klang',
  icon: 'sound',
  // Die Schrift richtet sich nach der Feldbreite (siehe contentScale) —
  // so bekommt auch ein flaches, breites Tonfeld richtig große Beschriftungen.
  scaleBy: 'width',
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

    // Fortschrittsbalken auf der spielenden Taste — so ist zu sehen,
    // wann die Datei endet.
    function updateProgress() {
      const bar = grid.querySelector('.w-sound__button.is-playing .w-sound__progress-bar');
      if (!bar) return;
      const duration = player.duration;
      const known = Number.isFinite(duration) && duration > 0;
      bar.parentElement.classList.toggle('is-hidden', !known);
      if (known) bar.style.width = `${Math.min(100, (player.currentTime / duration) * 100)}%`;
    }
    player.addEventListener('timeupdate', updateProgress);
    player.addEventListener('durationchange', updateProgress);

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
        const style = { '--tone': entry.color || COLORS[0] };
        if (entry.color2) style['--tone-grad'] = `linear-gradient(160deg, ${entry.color || COLORS[0]}, ${entry.color2})`;
        grid.appendChild(onTap(h('button', {
          class: 'w-sound__button' + (active ? ' is-playing' : '') + (ready ? '' : ' is-empty'),
          'data-nodrag': '',
          style,
          title: entry.fileName || entry.url || 'Noch keine Datei',
        },
        // Mit Symbol zeigt die Taste das Symbol groß; beim Abspielen immer das Pause-Zeichen.
        active || !entry.icon
          ? h('span', { class: 'w-sound__icon', html: icon(active ? 'pause' : 'play', 20) })
          : h('span', { class: 'w-sound__emoji' }, entry.icon),
        h('span', { class: 'w-sound__label' }, h('span', { class: 'w-sound__text' }, entry.label || 'Klang')),
        active ? h('span', { class: 'w-sound__progress' }, h('span', { class: 'w-sound__progress-bar' })) : null), () => play(entry)));
      }
      updateProgress();
      // Direkt und noch einmal nach dem Layout — beim ersten Aufbau ist die
      // Breite noch 0, erst danach lässt sich messen.
      fitWidth();
      window.requestAnimationFrame(fitWidth);
    }

    /**
     * Jede Beschriftung so groß wählen, dass sie ihre Taste ausfüllt — kurze
     * Wörter bekommen richtig große Schrift, statt zwischen breiten Rändern
     * zu verschwinden. Was auch in Grundgröße nicht in eine Zeile passt,
     * bricht stattdessen um.
     */
    function fitWidth() {
      for (const button of grid.querySelectorAll('.w-sound__button')) {
        const label = button.querySelector('.w-sound__label');
        const text = label ? label.firstElementChild : null;
        if (!text) continue;
        button.style.setProperty('--sound-fit', '1');
        label.classList.remove('is-wrap');
        const room = label.clientWidth;
        const need = text.offsetWidth;
        if (!(room > 0 && need > 0)) continue;
        if (need <= room) {
          const factor = Math.min(4, Math.max(1, (room / need) * 0.95));
          button.style.setProperty('--sound-fit', factor.toFixed(3));
        } else {
          label.classList.add('is-wrap');
        }
      }
    }

    // Beim Größenändern erst nach dem nächsten Bildaufbau messen — dann
    // stehen die neuen Maße des Feldes wirklich im Layout.
    function refit() {
      fitWidth();
      window.requestAnimationFrame(fitWidth);
    }

    render();
    // Nach dem Laden der Schriften stimmen die Maße — noch einmal anpassen.
    if (document.fonts && document.fonts.ready) document.fonts.ready.then(() => fitWidth()).catch(() => {});

    return {
      el,
      refresh: render,
      onResize: refit,
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

    async function chooseFile(entry) {
      const result = await pickMedia();
      if (!result) return;
      if (result.error === 'ZU_GROSS') {
        toast('Die Datei ist zu groß (mehr als 60 MB).', 'warn');
        return;
      }
      if (!looksLike('audio', result.file)) {
        toast('Das sieht nicht nach einer Klangdatei aus — falls sie stumm bleibt, bitte eine MP3 oder M4A wählen.', 'warn');
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
            onClick: () => chooseFile(entry),
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
        }))),
        h('div', { class: 'row' },
          field('Eigene Farbe', h('input', {
            class: 'input input--color', type: 'color', value: /^#[0-9a-fA-F]{6}$/.test(entry.color || '') ? entry.color : '#6366f1',
            oninput: (event) => {
              entry.color = event.target.value;
              ctx.save();
              ctx.refresh();
            },
          })),
          field('Farbverlauf nach …', h('div', { class: 'row' },
            h('input', {
              class: 'input input--color', type: 'color',
              value: /^#[0-9a-fA-F]{6}$/.test(entry.color2 || '') ? entry.color2 : '#0ea5e9',
              oninput: (event) => {
                entry.color2 = event.target.value;
                ctx.save();
                ctx.refresh();
              },
              // Erst wenn der Farbwähler zu ist, die Zeile neu aufbauen —
              // dann erscheint auch der Knopf „Ohne Verlauf".
              onchange: () => rerender(),
            }),
            entry.color2 ? button('Ohne Verlauf', {
              small: true, ghost: true,
              onClick: () => {
                entry.color2 = '';
                ctx.save();
                rerender();
              },
            }) : null),
          'Zweite Farbe antippen und wählen — die Taste bekommt einen Verlauf.')),
        field('Symbol auf der Taste', h('div', { class: 'chips' },
          h('button', {
            class: 'chip' + (entry.icon ? '' : ' is-active'),
            onclick: () => {
              entry.icon = '';
              ctx.save();
              rerender();
            },
          }, 'Ohne'),
          SYMBOLS.map((symbol) => h('button', {
            class: 'chip chip--symbol' + (entry.icon === symbol ? ' is-active' : ''),
            onclick: () => {
              entry.icon = symbol;
              ctx.save();
              rerender();
            },
          }, symbol)),
          h('input', {
            class: 'input input--symbol', type: 'text', placeholder: '…',
            title: 'Eigenes Symbol (Emoji) eintippen',
            value: entry.icon && !SYMBOLS.includes(entry.icon) ? entry.icon : '',
            oninput: (event) => {
              // Kurz halten — gedacht ist ein einzelnes Emoji (das mehrere Zeichen belegen kann).
              entry.icon = event.target.value.trim().slice(0, 8);
              ctx.save();
              ctx.refresh();
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
        'Es gehen MP3, M4A, WAV, AAC und OGG. Die Auswahl zeigt bewusst alle Dateien an — iPadOS graut sonst '
        + 'MP3-Dateien aus iCloud Drive oder vom Netzlaufwerk aus. Titel aus der Musik-App sind systembedingt '
        + 'nicht auswählbar; eine Datei aus „Dateien“ funktioniert.'));
      wrap.appendChild(h('p', { class: 'muted small' },
        'Dateien vom Gerät bleiben auf diesem Gerät — beim Teilen über einen Code werden sie nicht mitgeschickt. '
        + 'Ein Link funktioniert dagegen überall.'));
    }

    build();
    return wrap;
  },
};
