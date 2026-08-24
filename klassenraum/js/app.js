// Klassenraum — Start, Bedienleisten, Klassenraum-Verwaltung.

import { h, clear, readImageFile } from './util.js';
import { icon } from './icons.js';
import {
  loadState, getState, getActiveBoard, setActiveBoard, addBoard, duplicateBoard, removeBoard,
  addWidget, touch, saveNow, on as onStore, importBoard, AURORA,
} from './store.js';
import { WIDGETS } from './widgets/index.js';
import {
  initBoard, renderBoard, configureBoard, addWidgetOfType, select, updateScale,
  setStackMode, isStackMode, applyBackground, openWidgetSettings,
} from './board.js';
import { openListsPanel } from './lists.js';
import { initSharing, openSharePanel, isFollowing } from './share.js';
import {
  openPanel, closePanel, section, field, button, buttonRow, toggleRow, toast,
  confirmDialog, promptDialog, colorSwatches, modal,
} from './ui.js';

const BACKGROUND_COLORS = ['#33415c', '#1f2937', '#0b1120', '#0f766e', '#3f3d56', '#4c1d95',
  '#7c2d12', '#1e3a8a', '#f8fafc', '#e2e8f0', '#fef3c7', '#dcfce7'];
const BACKGROUND_GRADIENTS = [
  'linear-gradient(135deg, #1e3a8a, #0f766e)',
  'linear-gradient(135deg, #312e81, #6d28d9)',
  'linear-gradient(135deg, #0f172a, #334155)',
  'linear-gradient(135deg, #7c2d12, #b45309)',
  'linear-gradient(135deg, #f8fafc, #cbd5f5)',
  'linear-gradient(160deg, #064e3b, #10b981)',
];

const dom = {};

function cacheDom() {
  dom.stage = document.getElementById('stage');
  dom.canvas = document.getElementById('canvas');
  dom.selection = document.getElementById('selection-toolbar');
  dom.boardName = document.getElementById('board-name');
  dom.dock = document.getElementById('dock');
  dom.followBadge = document.getElementById('follow-badge');
}

function renderTopbar() {
  const board = getActiveBoard();
  dom.boardName.textContent = board ? board.name : 'Klassenraum';
  dom.followBadge.classList.toggle('is-hidden', !isFollowing());
}

function renderDock() {
  clear(dom.dock);
  for (const definition of WIDGETS) {
    dom.dock.appendChild(h('button', {
      class: 'dock__item',
      title: definition.label,
      onclick: () => {
        const descriptor = addWidgetOfType(definition.type);
        if (!descriptor) return;
        const widget = addWidget(descriptor);
        renderBoard();
        if (widget) {
          select(widget.id);
          if (['randomizer', 'image', 'text'].includes(widget.type)) openWidgetSettings(widget.id);
        }
      },
    },
    h('span', { class: 'dock__icon', html: icon(definition.icon, 26) }),
    h('span', { class: 'dock__label' }, definition.label)));
  }
}

function openBoardsPanel() {
  const container = h('div', { class: 'stack' });

  function render() {
    clear(container);
    const state = getState();
    const rows = h('div', { class: 'stack' });
    for (const board of state.boards) {
      const active = board.id === state.activeBoardId;
      rows.appendChild(h('div', { class: 'list-row' + (active ? ' is-active' : '') },
        h('button', {
          class: 'list-row__main',
          onclick: () => {
            setActiveBoard(board.id);
            renderTopbar();
            closePanel();
          },
        },
        h('strong', null, board.name),
        h('small', { class: 'muted' }, `${board.widgets.length} Elemente${active ? ' · geöffnet' : ''}`)),
        h('button', {
          class: 'icon-button', title: 'Umbenennen',
          onclick: async () => {
            const name = await promptDialog('Klassenraum umbenennen', 'Name', board.name);
            if (!name) return;
            board.name = name;
            touch({ board: false });
            renderTopbar();
            render();
          },
          html: icon('text', 18),
        }),
        h('button', {
          class: 'icon-button', title: 'Duplizieren',
          onclick: () => {
            duplicateBoard(board.id);
            renderTopbar();
            render();
          },
          html: icon('copy', 18),
        }),
        h('button', {
          class: 'icon-button icon-button--danger', title: 'Löschen',
          disabled: state.boards.length <= 1,
          onclick: async () => {
            const ok = await confirmDialog('Klassenraum löschen?', `„${board.name}“ wird dauerhaft entfernt.`);
            if (!ok) return;
            removeBoard(board.id);
            renderTopbar();
            render();
          },
          html: icon('trash', 18),
        })));
    }

    container.append(
      section('Meine Klassenräume', rows),
      buttonRow(
        button('Neuer Klassenraum', {
          icon: 'plus', primary: true,
          onClick: async () => {
            const name = await promptDialog('Neuer Klassenraum', 'Name', `Klasse ${getState().boards.length + 1}`);
            if (!name) return;
            addBoard(name);
            renderTopbar();
            renderBoard();
            closePanel();
          },
        }),
        button('Leeren', {
          icon: 'reset', ghost: true,
          onClick: async () => {
            const board = getActiveBoard();
            const ok = await confirmDialog('Alle Elemente entfernen?',
              `„${board.name}“ wird komplett geleert.`, 'Leeren');
            if (!ok) return;
            board.widgets = [];
            touch();
            renderBoard();
            render();
          },
        })),
      section('Sichern & Übertragen',
        h('p', { class: 'muted small' }, 'Als Datei sichern eignet sich für Backups oder den Wechsel auf ein anderes Gerät.'),
        buttonRow(
          button('Als Datei sichern', { icon: 'download', small: true, onClick: exportFile }),
          button('Datei laden', { icon: 'upload', small: true, onClick: importFile }))));
  }

  openPanel({ title: 'Klassenräume', subtitle: 'Für jede Klasse eine eigene Tafel', content: container, wide: true });
  render();
}

function exportFile() {
  const state = getState();
  const payload = JSON.stringify({ app: 'klassenraum', version: 1, boards: state.boards, lists: state.lists }, null, 2);
  const blob = new Blob([payload], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  const link = h('a', { href: url, download: `klassenraum-${new Date().toISOString().slice(0, 10)}.json` });
  document.body.appendChild(link);
  link.click();
  link.remove();
  setTimeout(() => URL.revokeObjectURL(url), 2000);
}

function importFile() {
  const input = h('input', { type: 'file', accept: 'application/json,.json', style: { display: 'none' } });
  document.body.appendChild(input);
  input.addEventListener('change', () => {
    const file = input.files && input.files[0];
    input.remove();
    if (!file) return;
    const reader = new FileReader();
    reader.onload = async () => {
      try {
        const data = JSON.parse(String(reader.result));
        if (!data || !Array.isArray(data.boards)) throw new Error('Format');
        const ok = await confirmDialog('Datei laden?',
          `${data.boards.length} Klassenräume werden zu deinen bestehenden hinzugefügt.`, 'Laden');
        if (!ok) return;
        for (const board of data.boards) importBoard(board, { activate: false });
        if (Array.isArray(data.lists)) {
          const state = getState();
          const known = new Set(state.lists.map((list) => list.name));
          for (const list of data.lists) {
            if (!known.has(list.name)) state.lists.push(list);
          }
        }
        saveNow();
        renderBoard();
        renderTopbar();
        toast('Datei geladen.', 'success');
      } catch (error) {
        toast('Die Datei konnte nicht gelesen werden.', 'warn');
      }
    };
    reader.readAsText(file);
  });
  input.click();
}

function openBackgroundPanel() {
  const container = h('div', { class: 'stack' });

  function render() {
    clear(container);
    const board = getActiveBoard();
    const background = board.background || { type: 'aurora', value: 'nordlicht' };
    const cardStyle = board.cardStyle || 'glass';

    const auroraGrid = h('div', { class: 'bg-grid' }, AURORA.map((preset) => h('button', {
      class: 'bg-card' + (background.type === 'aurora' && background.value === preset.id ? ' is-active' : ''),
      style: {
        background: `radial-gradient(90% 90% at 20% 15%, ${preset.blobs[0]} 0%, transparent 60%),`
          + `radial-gradient(80% 80% at 85% 80%, ${preset.blobs[1]} 0%, transparent 62%),`
          + `radial-gradient(70% 70% at 60% 40%, ${preset.blobs[2]} 0%, transparent 60%), ${preset.base}`,
        color: preset.id === 'kreide' ? '#1e293b' : '#fff',
        textShadow: preset.id === 'kreide' ? '0 1px 4px rgba(255,255,255,0.8)' : '0 1px 6px rgba(0,0,0,0.6)',
      },
      onclick: () => {
        board.background = { type: 'aurora', value: preset.id };
        touch();
        applyBackground();
        render();
      },
    }, preset.label)));

    container.appendChild(section('Bewegter Hintergrund', auroraGrid,
      h('p', { class: 'muted small' }, 'Sanft wandernde Farbschleier — ruhig genug für den Unterricht.')));

    const custom = h('input', {
      class: 'input input--color', type: 'color',
      value: background.type === 'color' ? background.value : '#33415c',
      oninput: (event) => {
        board.background = { type: 'color', value: event.target.value };
        touch();
        applyBackground();
      },
    });

    container.appendChild(section('Einfarbig',
      colorSwatches(BACKGROUND_COLORS, background.type === 'color' ? background.value : null, (color) => {
        board.background = { type: 'color', value: color };
        touch();
        applyBackground();
        render();
      }),
      field('Eigene Farbe', custom)));

    container.appendChild(section('Farbverlauf',
      h('div', { class: 'bg-grid' }, BACKGROUND_GRADIENTS.map((gradient) => h('button', {
        class: 'bg-card' + (background.value === gradient ? ' is-active' : ''),
        style: { background: gradient },
        onclick: () => {
          board.background = { type: 'gradient', value: gradient };
          touch();
          applyBackground();
          render();
        },
      })))));

    container.appendChild(section('Hintergrundbild',
      button('Bild vom Gerät wählen', {
        icon: 'image', primary: true, full: true,
        onClick: () => {
          const input = h('input', { type: 'file', accept: 'image/*', style: { display: 'none' } });
          document.body.appendChild(input);
          input.addEventListener('change', async () => {
            const file = input.files && input.files[0];
            input.remove();
            if (!file) return;
            try {
              const result = await readImageFile(file, 1920, 0.72);
              board.background = { type: 'image', value: result.url };
              touch();
              applyBackground();
              render();
            } catch (error) {
              toast('Bild konnte nicht geladen werden.', 'warn');
            }
          });
          input.click();
        },
      }),
      background.type === 'image' ? button('Bild entfernen', {
        icon: 'trash', ghost: true, full: true,
        onClick: () => {
          board.background = { type: 'aurora', value: 'nordlicht' };
          touch();
          applyBackground();
          render();
        },
      }) : null,
      h('p', { class: 'muted small' }, 'Das Bild wird verkleinert gespeichert und bleibt auf dem Gerät.')));

    container.appendChild(section('Kartenstil',
      h('div', { class: 'segmented' },
        [['glass', 'Glas'], ['light', 'Hell'], ['dark', 'Dunkel']].map(([value, label]) => h('button', {
          class: 'segmented__item' + (cardStyle === value ? ' is-active' : ''),
          onclick: () => {
            board.cardStyle = value;
            touch();
            applyBackground();
            render();
          },
        }, label))),
      h('p', { class: 'muted small' }, 'Glas wirkt leicht und nimmt die Hintergrundfarbe auf, Hell ist am kontraststärksten, Dunkel schont abends die Augen.')));
  }

  openPanel({ title: 'Hintergrund', subtitle: `Für „${getActiveBoard().name}"`, content: container, wide: true });
  render();
}

function openMenuPanel() {
  const container = h('div', { class: 'stack' });
  const state = getState();

  container.append(
    section('Einrichten',
      buttonRow(
        button('Namenslisten', { icon: 'layers', full: true, onClick: () => { closePanel(); openListsPanel(); } })),
      buttonRow(
        button('Hintergrund', { icon: 'paint', full: true, onClick: () => { closePanel(); openBackgroundPanel(); } })),
      buttonRow(
        button('Klassenräume', { icon: 'home', full: true, onClick: () => { closePanel(); openBoardsPanel(); } })),
      buttonRow(
        button('Teilen & Konto', { icon: 'share', full: true, onClick: () => { closePanel(); openSharePanel(); } }))),
    section('Ansicht',
      toggleRow('Listenansicht (praktisch am Telefon)', isStackMode(), (value) => {
        state.settings.stackModeManual = value;
        touch({ board: false });
        setStackMode(value);
      }, 'Elemente werden untereinander angezeigt statt frei angeordnet.'),
      buttonRow(button('Präsentationsmodus', {
        icon: 'expand', full: true,
        onClick: () => {
          closePanel();
          togglePresentation(true);
        },
      }))),
    section('Über',
      h('p', { class: 'muted small' },
        'Klassenraum ist eine freie Tafel-App: alle Elemente liegen auf deinem Gerät, Teilen geschieht nur, wenn du einen Code erstellst.'),
      buttonRow(button('Kurzanleitung', { icon: 'check', full: true, onClick: () => { closePanel(); openHelp(); } }))));

  openPanel({ title: 'Menü', content: container });
}

function openHelp() {
  modal({
    title: 'Kurzanleitung',
    content: h('div', { class: 'stack' },
      h('p', null, h('strong', null, 'Elemente hinzufügen: '), 'unten in der Leiste antippen.'),
      h('p', null, h('strong', null, 'Bedienen: '), 'Ein Tipp auf die Karte löst die Hauptfunktion aus — '
        + 'Zufälliger Name zieht den nächsten Namen, die Ampel schaltet weiter, das Arbeitssymbol wechselt, '
        + 'die Uhr springt zwischen analog und digital, die Lautstärkemessung startet.'),
      h('p', null, h('strong', null, 'Verschieben: '), 'Element anfassen und ziehen. Ecken ziehen ändert die Größe.'),
      h('p', null, h('strong', null, 'Einstellen: '), 'Element antippen, dann auf das Zahnrad in der kleinen Leiste.'),
      h('p', null, h('strong', null, 'Zufälliger Name: '), 'Liste wählen, „Ohne Zurücklegen“ verhindert Wiederholungen. '
        + 'Gezogene Namen lassen sich antippen, um sie zurückzulegen; einzelne Namen können auch von Hand als gezogen markiert werden.'),
      h('p', null, h('strong', null, 'Lautstärke: '), 'Beim ersten Start fragt das Gerät nach dem Mikrofon — einmal erlauben, dann läuft die Messung.'),
      h('p', null, h('strong', null, 'Text: '), 'Doppeltippen zum Schreiben oder den Stift in der kleinen Leiste nutzen.'),
      h('p', null, h('strong', null, 'Aussehen: '), '„Hintergrund“ bietet bewegte Farbverläufe, eigene Farben, Bilder und drei Kartenstile.'),
      h('p', null, h('strong', null, 'Teilen: '), 'Menü → „Teilen & Konto“ → Code erstellen. Andere geben den Code ein und laden eine Kopie oder folgen live.'),
      h('p', null, h('strong', null, 'Auf dem Homescreen: '), 'In Safari „Teilen“ → „Zum Home-Bildschirm“ — dann startet die App im Vollbild.')),
    actions: [{ label: 'Alles klar', primary: true }],
  });
}

function togglePresentation(force) {
  const on = force !== undefined ? force : !document.body.classList.contains('is-presenting');
  document.body.classList.toggle('is-presenting', on);
  select(null);
  updateScale();
  if (on && document.documentElement.requestFullscreen) {
    document.documentElement.requestFullscreen().catch(() => {});
  } else if (!on && document.fullscreenElement && document.exitFullscreen) {
    document.exitFullscreen().catch(() => {});
  }
}

function applyStackPreference() {
  const manual = getState().settings.stackModeManual;
  const auto = window.matchMedia('(max-width: 760px)').matches;
  setStackMode(manual === null || manual === undefined ? auto : manual);
}

function wireChrome() {
  document.getElementById('btn-boards').addEventListener('click', openBoardsPanel);
  document.getElementById('btn-lists').addEventListener('click', () => openListsPanel());
  document.getElementById('btn-background').addEventListener('click', openBackgroundPanel);
  document.getElementById('btn-share').addEventListener('click', () => openSharePanel());
  document.getElementById('btn-menu').addEventListener('click', openMenuPanel);
  document.getElementById('btn-present').addEventListener('click', () => togglePresentation());
  document.getElementById('btn-exit-present').addEventListener('click', () => togglePresentation(false));

  window.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && document.body.classList.contains('is-presenting')) togglePresentation(false);
  });

  window.matchMedia('(max-width: 760px)').addEventListener('change', () => {
    if (getState().settings.stackModeManual === null || getState().settings.stackModeManual === undefined) {
      applyStackPreference();
    }
  });

  document.addEventListener('klassenraum:board-updated', () => renderTopbar());
  onStore('board-switch', () => renderTopbar());
  onStore('change', () => renderTopbar());
}

async function boot() {
  cacheDom();
  await loadState();
  configureBoard({ onOpenLists: () => openListsPanel() });
  initBoard({ canvas: dom.canvas, stage: dom.stage, selection: dom.selection });
  renderDock();
  applyStackPreference();
  renderBoard();
  renderTopbar();
  wireChrome();
  initSharing();
  document.body.classList.remove('is-loading');

  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('./sw.js').catch(() => {});
  }
}

boot();
