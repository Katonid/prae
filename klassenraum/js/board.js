// Die Tafelfläche: Elemente anzeigen, verschieben, vergrößern, auswählen.

import { h, clear, clamp, armTapGuard } from './util.js';
import { icon } from './icons.js';
import { getWidgetType } from './widgets/index.js';
import {
  BOARD_WIDTH, BOARD_HEIGHT, AURORA, getActiveBoard, touch, removeWidget, duplicateWidget,
  nextZ, on as onStore,
} from './store.js';
import { openPanel, closePanel, confirmDialog } from './ui.js';

const instances = new Map();
let canvasEl = null;
let stageEl = null;
let selectionEl = null;
let selectedId = null;
let scale = 1;
let hooks = { onOpenLists: () => {} };
let stackMode = false;
let mode = 'edit';

export function configureBoard(options) {
  hooks = Object.assign(hooks, options || {});
}

/** 'edit' = Tafel einrichten, 'use' = im Unterricht bedienen (ohne Bearbeiten-Elemente). */
export function getMode() {
  return mode;
}

export function isEditing() {
  return mode === 'edit';
}

export function setMode(value) {
  const next = value === 'use' ? 'use' : 'edit';
  if (next === mode) return;
  mode = next;
  document.body.classList.toggle('is-using', mode === 'use');
  if (mode === 'use') select(null);
  refreshAll();
  layout();
}

export function isStackMode() {
  return stackMode;
}

export function setStackMode(value) {
  stackMode = Boolean(value);
  document.body.classList.toggle('is-stacked', stackMode);
  if (stackMode) select(null);
  layout();
}

export function getSelectedId() {
  return selectedId;
}

export function initBoard(elements) {
  canvasEl = elements.canvas;
  stageEl = elements.stage;
  selectionEl = elements.selection;

  stageEl.addEventListener('pointerdown', (event) => {
    if (event.target === stageEl || event.target === canvasEl) select(null);
  });

  window.addEventListener('resize', () => {
    updateScale();
    layout();
  });

  window.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') select(null);
    const tag = document.activeElement ? document.activeElement.tagName : '';
    if (tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT') return;
    if ((event.key === 'Delete' || event.key === 'Backspace') && selectedId) {
      event.preventDefault();
      const id = selectedId;
      select(null);
      removeWidget(id);
    }
  });

  onStore('board-switch', () => {
    select(null);
    renderBoard();
  });
  onStore('widgets-changed', () => renderBoard());
}

export function updateScale() {
  if (!stageEl) return;
  const rect = stageEl.getBoundingClientRect();
  if (stackMode) {
    scale = 1;
    canvasEl.style.transform = '';
    canvasEl.style.width = '';
    canvasEl.style.height = '';
    return;
  }
  scale = Math.min(rect.width / BOARD_WIDTH, rect.height / BOARD_HEIGHT);
  const offsetX = (rect.width - BOARD_WIDTH * scale) / 2;
  const offsetY = (rect.height - BOARD_HEIGHT * scale) / 2;
  canvasEl.style.width = `${BOARD_WIDTH}px`;
  canvasEl.style.height = `${BOARD_HEIGHT}px`;
  canvasEl.style.transform = `translate(${offsetX}px, ${offsetY}px) scale(${scale})`;
}

export function applyBackground() {
  const board = getActiveBoard();
  if (!board || !stageEl) return;
  const layer = document.getElementById('stage-bg');
  const background = board.background || { type: 'aurora', value: 'nordlicht' };
  if (layer) {
    layer.className = 'stage__bg';
    layer.style.background = '';
    layer.style.backgroundImage = '';
    if (background.type === 'aurora') {
      const preset = AURORA.find((entry) => entry.id === background.value) || AURORA[0];
      layer.style.setProperty('--bg-base', preset.base);
      preset.blobs.forEach((color, index) => layer.style.setProperty(`--blob-${index + 1}`, color));
    } else if (background.type === 'image' && background.value) {
      layer.classList.add('stage__bg--plain', 'stage__bg--image');
      layer.style.background = `#0b1120 center/cover no-repeat url("${background.value}")`;
    } else if (background.type === 'gradient') {
      layer.classList.add('stage__bg--plain');
      layer.style.background = background.value;
    } else {
      layer.classList.add('stage__bg--plain');
      layer.style.setProperty('--bg-base', background.value || '#33415c');
    }
  }
  document.body.classList.toggle('is-light-board', isLight(background));
  const style = board.cardStyle || 'glass';
  stageEl.dataset.cards = style;
  document.body.dataset.cards = style;
}

function isLight(background) {
  if (!background) return false;
  if (background.type === 'aurora') {
    const preset = AURORA.find((entry) => entry.id === background.value);
    return Boolean(preset && preset.id === 'kreide');
  }
  if (background.type !== 'color' || !background.value) return false;
  const hex = background.value.replace('#', '');
  if (hex.length !== 6) return false;
  const r = parseInt(hex.slice(0, 2), 16);
  const g = parseInt(hex.slice(2, 4), 16);
  const b = parseInt(hex.slice(4, 6), 16);
  return (0.299 * r + 0.587 * g + 0.114 * b) > 165;
}

export function renderBoard() {
  const board = getActiveBoard();
  if (!board || !canvasEl) return;
  applyBackground();

  const seen = new Set();
  for (const widget of board.widgets) {
    seen.add(widget.id);
    if (!instances.has(widget.id)) mountWidget(widget);
    else instances.get(widget.id).widget = widget;
  }
  for (const [id, instance] of Array.from(instances.entries())) {
    if (!seen.has(id)) {
      if (instance.api && instance.api.destroy) instance.api.destroy();
      instance.el.remove();
      instances.delete(id);
    }
  }
  updateScale();
  layout();
  renderSelection();
}

function makeContext(widget) {
  return {
    widget,
    save() {
      touch({ reason: 'widget-state' });
    },
    refresh() {
      const instance = instances.get(widget.id);
      if (instance && instance.api && instance.api.refresh) instance.api.refresh();
    },
    instance() {
      const instance = instances.get(widget.id);
      return instance ? instance.api : null;
    },
    setSize(w, h) {
      widget.w = clamp(Math.round(w), 120, BOARD_WIDTH);
      widget.h = clamp(Math.round(h), 90, BOARD_HEIGHT);
      touch({ reason: 'widget-size' });
      layout();
      const instance = instances.get(widget.id);
      if (instance && instance.api && instance.api.onResize) instance.api.onResize();
    },
    openLists() {
      hooks.onOpenLists();
    },
    isEditing() {
      return mode === 'edit';
    },
    openSettings() {
      openWidgetSettings(widget.id);
    },
  };
}

function mountWidget(widget) {
  const definition = getWidgetType(widget.type);
  if (!definition) return;
  const el = h('div', { class: `widget widget--${widget.type}`, 'data-id': widget.id });
  const inner = h('div', { class: 'widget__inner' });
  el.appendChild(inner);
  const ctx = makeContext(widget);
  const api = definition.mount(ctx);
  inner.appendChild(api.el);

  for (const corner of ['nw', 'ne', 'sw', 'se']) {
    el.appendChild(h('span', { class: `handle handle--${corner}`, 'data-handle': corner }));
  }

  el.addEventListener('pointerdown', (event) => onWidgetPointerDown(event, widget, el));
  attachCardTap(el, widget);
  el.addEventListener('dblclick', (event) => {
    if (!api.onDoubleClick) return;
    // Wegen der Pointer-Erfassung zeigt event.target auf das Widget selbst —
    // deshalb das tatsächlich getroffene Element über die Position bestimmen.
    const hit = document.elementFromPoint(event.clientX, event.clientY);
    if (hit && hit.closest('[data-nodrag]')) return;
    api.onDoubleClick();
  });
  el.style.setProperty('--enter-delay', `${Math.min(canvasEl.children.length, 12) * 45}ms`);
  el.classList.add('is-entering');
  el.addEventListener('animationend', () => el.classList.remove('is-entering'), { once: true });
  canvasEl.appendChild(el);
  instances.set(widget.id, { el, api, widget, ctx, definition });
}

/** Ein sauberer Tipp auf die Karte (nicht auf ein Bedienelement) löst die Hauptaktion aus. */
function attachCardTap(el, widget) {
  let armed = false;
  let startX = 0;
  let startY = 0;
  let startTime = 0;

  el.addEventListener('pointerdown', (event) => {
    const target = event.target;
    armed = !(target.closest && (target.closest('[data-nodrag]') || target.closest('[data-handle]')));
    startX = event.clientX;
    startY = event.clientY;
    startTime = Date.now();
  });
  el.addEventListener('pointercancel', () => { armed = false; });
  el.addEventListener('pointerup', (event) => {
    if (!armed) return;
    armed = false;
    if (Date.now() - startTime > 800) return;
    if (Math.abs(event.clientX - startX) + Math.abs(event.clientY - startY) > 14) return;
    const instance = instances.get(widget.id);
    if (!instance || !instance.api || !instance.api.onTap) return;
    if (mode === 'use' && instance.api.tapNeedsEditing) return;
    if (event.pointerType !== 'mouse') armTapGuard(event);
    instance.api.onTap();
  });
}

function layout() {
  const board = getActiveBoard();
  if (!board) return;
  const sorted = board.widgets.slice().sort((a, b) => (a.y - b.y) || (a.x - b.x));
  for (const widget of board.widgets) {
    const instance = instances.get(widget.id);
    if (!instance) continue;
    const el = instance.el;
    if (stackMode) {
      el.style.transform = '';
      el.style.width = '';
      el.style.height = '';
      el.style.zIndex = '';
      el.style.order = String(sorted.indexOf(widget));
    } else {
      el.style.order = '';
      el.style.transform = `translate(${widget.x}px, ${widget.y}px)`;
      el.style.width = `${widget.w}px`;
      el.style.height = `${widget.h}px`;
      el.style.zIndex = String(widget.z || 1);
    }
    el.classList.toggle('is-locked', Boolean(widget.locked));
    el.classList.toggle('is-selected', widget.id === selectedId);
  }
  if (stackMode) {
    for (const [, instance] of instances) {
      if (instance.api && instance.api.onResize) instance.api.onResize();
    }
  }
  renderSelection();
}

function onWidgetPointerDown(event, widget, el) {
  const handle = event.target.closest('[data-handle]');
  if (mode === 'use') return;
  select(widget.id);
  if (stackMode || widget.locked) return;
  if (!handle && event.target.closest('[data-nodrag]')) return;
  if (event.button !== undefined && event.button !== 0) return;

  const startX = event.clientX;
  const startY = event.clientY;
  const origin = { x: widget.x, y: widget.y, w: widget.w, h: widget.h };
  const definition = getWidgetType(widget.type) || {};
  const min = definition.minSize || { w: 140, h: 110 };
  let moved = false;

  bringToFront(widget);
  el.setPointerCapture(event.pointerId);
  el.classList.add('is-dragging');

  const onMove = (moveEvent) => {
    const dx = (moveEvent.clientX - startX) / scale;
    const dy = (moveEvent.clientY - startY) / scale;
    if (!moved && Math.abs(dx) + Math.abs(dy) < 2) return;
    moved = true;
    if (handle) {
      const mode = handle.dataset.handle;
      let { x, y, w, h } = origin;
      if (mode.includes('e')) w = origin.w + dx;
      if (mode.includes('s')) h = origin.h + dy;
      if (mode.includes('w')) {
        w = origin.w - dx;
        x = origin.x + dx;
      }
      if (mode.includes('n')) {
        h = origin.h - dy;
        y = origin.y + dy;
      }
      if (w < min.w) {
        if (mode.includes('w')) x -= min.w - w;
        w = min.w;
      }
      if (h < min.h) {
        if (mode.includes('n')) y -= min.h - h;
        h = min.h;
      }
      widget.w = Math.round(clamp(w, min.w, BOARD_WIDTH));
      widget.h = Math.round(clamp(h, min.h, BOARD_HEIGHT));
      widget.x = Math.round(clamp(x, 0, Math.max(0, BOARD_WIDTH - widget.w)));
      widget.y = Math.round(clamp(y, 0, Math.max(0, BOARD_HEIGHT - widget.h)));
      const instance = instances.get(widget.id);
      if (instance && instance.api && instance.api.onResize) instance.api.onResize();
    } else {
      widget.x = Math.round(clamp(origin.x + dx, 0, Math.max(0, BOARD_WIDTH - widget.w)));
      widget.y = Math.round(clamp(origin.y + dy, 0, Math.max(0, BOARD_HEIGHT - widget.h)));
    }
    layout();
  };

  const onUp = () => {
    el.classList.remove('is-dragging');
    el.removeEventListener('pointermove', onMove);
    el.removeEventListener('pointerup', onUp);
    el.removeEventListener('pointercancel', onUp);
    if (moved) touch({ reason: 'widget-move' });
  };

  el.addEventListener('pointermove', onMove);
  el.addEventListener('pointerup', onUp);
  el.addEventListener('pointercancel', onUp);
}

function bringToFront(widget) {
  const top = nextZ();
  if ((widget.z || 1) < top - 1) {
    widget.z = top;
    touch({ reason: 'widget-z' });
  }
}

export function select(widgetId) {
  selectedId = mode === 'use' ? null : widgetId;
  for (const [id, instance] of instances) {
    instance.el.classList.toggle('is-selected', id === widgetId);
  }
  renderSelection();
}

function renderSelection() {
  if (!selectionEl) return;
  clear(selectionEl);
  const board = getActiveBoard();
  const widget = board ? board.widgets.find((entry) => entry.id === selectedId) : null;
  if (!widget || stackMode || mode === 'use' || document.body.classList.contains('is-presenting')) {
    selectionEl.classList.remove('is-visible');
    return;
  }
  selectionEl.classList.add('is-visible');
  const rect = stageEl.getBoundingClientRect();
  const offsetX = (rect.width - BOARD_WIDTH * scale) / 2;
  const offsetY = (rect.height - BOARD_HEIGHT * scale) / 2;
  const left = offsetX + widget.x * scale;
  const top = offsetY + widget.y * scale;
  selectionEl.style.left = `${clamp(left, 8, rect.width - 180)}px`;
  selectionEl.style.top = `${Math.max(6, top - 52)}px`;

  const definition = getWidgetType(widget.type);
  const instance = instances.get(widget.id);
  const extras = (instance && instance.api && instance.api.actions) || [];
  for (const action of extras) {
    selectionEl.appendChild(h('button', {
      class: 'tool-button tool-button--accent', title: action.title,
      onclick: () => action.run(),
      html: icon(action.icon, 18),
    }));
  }
  selectionEl.append(
    h('button', {
      class: 'tool-button', title: 'Löschen',
      onclick: async () => {
        const ok = await confirmDialog('Element löschen?', 'Das Element wird von dieser Tafel entfernt.', 'Löschen');
        if (!ok) return;
        select(null);
        removeWidget(widget.id);
      },
      html: icon('trash', 18),
    }),
    definition && definition.settings ? h('button', {
      class: 'tool-button', title: 'Einstellungen',
      onclick: () => openWidgetSettings(widget.id),
      html: icon('gear', 18),
    }) : null,
    h('button', {
      class: 'tool-button', title: 'Duplizieren',
      onclick: () => duplicateWidget(widget.id),
      html: icon('copy', 18),
    }),
    h('button', {
      class: 'tool-button', title: widget.locked ? 'Entsperren' : 'Position sperren',
      onclick: () => {
        widget.locked = !widget.locked;
        touch({ reason: 'widget-lock' });
        layout();
      },
      html: icon(widget.locked ? 'lock' : 'unlock', 18),
    }),
    h('button', {
      class: 'tool-button', title: 'Nach vorne holen',
      onclick: () => {
        widget.z = nextZ();
        touch({ reason: 'widget-z' });
        layout();
      },
      html: icon('layers', 18),
    }));
}

export function openWidgetSettings(widgetId) {
  const instance = instances.get(widgetId);
  if (!instance) return;
  const definition = instance.definition;
  if (!definition.settings) return;
  openPanel({
    title: definition.label,
    subtitle: 'Einstellungen für dieses Element',
    content: definition.settings(instance.ctx),
  });
}

export function addWidgetOfType(type) {
  const definition = getWidgetType(type);
  const board = getActiveBoard();
  if (!definition || !board) return null;
  const size = definition.defaultSize || { w: 360, h: 260 };
  const spot = findFreeSpot(size, board.widgets);
  const widget = {
    type,
    x: spot.x,
    y: spot.y,
    w: size.w,
    h: size.h,
    z: nextZ(),
    state: definition.createState ? definition.createState() : {},
  };
  return widget;
}

function findFreeSpot(size, widgets) {
  const step = 40;
  for (let y = 80; y < BOARD_HEIGHT - size.h; y += step) {
    for (let x = 60; x < BOARD_WIDTH - size.w; x += step) {
      const overlaps = widgets.some((widget) => !(x + size.w < widget.x || x > widget.x + widget.w
        || y + size.h < widget.y || y > widget.y + widget.h));
      if (!overlaps) return { x, y };
    }
  }
  const cascade = widgets.length % 8;
  return {
    x: Math.min(120 + cascade * 44, Math.max(0, BOARD_WIDTH - size.w)),
    y: Math.min(120 + cascade * 38, Math.max(0, BOARD_HEIGHT - size.h)),
  };
}

export function refreshAll() {
  for (const [, instance] of instances) {
    if (instance.api && instance.api.refresh) instance.api.refresh();
  }
}

export function resetInstances() {
  for (const [, instance] of instances) {
    if (instance.api && instance.api.destroy) instance.api.destroy();
    instance.el.remove();
  }
  instances.clear();
  if (canvasEl) clear(canvasEl);
}

export { closePanel };
