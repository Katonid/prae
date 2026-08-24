// Die Tafelfläche: Elemente anzeigen, verschieben, vergrößern, auswählen.

import { h, clear, clamp, armTapGuard } from './util.js';
import { icon } from './icons.js';
import { getWidgetType } from './widgets/index.js';
import {
  BOARD_WIDTH, BOARD_HEIGHT, AURORA, getActiveBoard, touch, removeWidget, duplicateWidget,
  nextZ, on as onStore,
} from './store.js';
import { openPanel, closePanel, confirmDialog } from './ui.js';
import { applyScheme } from './theme.js';

const instances = new Map();
let canvasEl = null;
let stageEl = null;
let selectionEl = null;
let selectionFrame = null;
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
  applyBackground();
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
  buildSelectionFrame();

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
    canvasEl.style.setProperty('--board-scale', '1');
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
  canvasEl.style.setProperty('--board-scale', String(scale));
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
  applyScheme(board);
  const labels = board.labels || 'always';
  document.body.dataset.labels = labels === 'edit' && mode === 'use' ? 'never' : labels;
  layout();
}

/**
 * Wie groß ist das Element im Vergleich zu seiner Grundgröße? Daraus wächst die
 * Schrift der Inhalte mit — so lässt sich jedes Feld stufenlos vergrößern.
 */
function contentScale(widget) {
  const definition = getWidgetType(widget.type);
  const size = (definition && definition.defaultSize) || { w: 360, h: 260 };
  const ratio = Math.min(widget.w / size.w, widget.h / size.h);
  return clamp(ratio, 0.6, 4);
}

/** Zeigt dieses Element gerade einen Rahmen? */
function isBare(widget, board) {
  if (widget.bare) return true;
  const frames = board.frames || 'always';
  if (frames === 'never') return true;
  if (frames === 'edit' && mode === 'use') return true;
  return false;
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

  attachInteractions(el, widget);
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

const MIN_FALLBACK = { w: 140, h: 110 };

function minSizeOf(widget) {
  const definition = getWidgetType(widget.type) || {};
  return definition.minSize || MIN_FALLBACK;
}

function boxOf(widget) {
  return { x: widget.x, y: widget.y, w: widget.w, h: widget.h };
}

/** Neue Maße setzen — begrenzt auf Mindestgröße und Tafelfläche. */
function applyBox(widget, box) {
  const min = minSizeOf(widget);
  const w = clamp(Math.round(box.w), min.w, BOARD_WIDTH);
  const h = clamp(Math.round(box.h), min.h, BOARD_HEIGHT);
  widget.w = w;
  widget.h = h;
  widget.x = Math.round(clamp(box.x, 0, Math.max(0, BOARD_WIDTH - w)));
  widget.y = Math.round(clamp(box.y, 0, Math.max(0, BOARD_HEIGHT - h)));
  const instance = instances.get(widget.id);
  if (instance && instance.api && instance.api.onResize) instance.api.onResize();
}

/** Größe um den Mittelpunkt ändern — für die Knöpfe und die Zwei-Finger-Geste. */
export function scaleWidget(widget, factor) {
  const centerX = widget.x + widget.w / 2;
  const centerY = widget.y + widget.h / 2;
  const w = widget.w * factor;
  const h = widget.h * factor;
  applyBox(widget, { x: centerX - w / 2, y: centerY - h / 2, w, h });
  touch({ reason: 'widget-size' });
  layout();
}

const pointDistance = (a, b) => Math.hypot(a.x - b.x, a.y - b.y);
const pointMiddle = (a, b) => ({ x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 });

/**
 * Alles an einem Element in einer Hand: Tippen löst die Hauptfunktion aus,
 * Ziehen verschiebt, zwei Finger verändern stufenlos die Größe.
 */
function attachInteractions(el, widget) {
  const points = new Map();
  let gesture = null;
  let tap = null;

  el.addEventListener('pointerdown', (event) => {
    if (event.button !== undefined && event.button > 0) return;
    points.set(event.pointerId, { x: event.clientX, y: event.clientY });
    if (mode === 'edit') select(widget.id);

    const onControl = Boolean(event.target.closest && event.target.closest('[data-nodrag]'));
    const movable = mode === 'edit' && !stackMode && !widget.locked;

    if (points.size === 1) {
      tap = { x: event.clientX, y: event.clientY, time: Date.now(), armed: !onControl };
      if (movable && !onControl) {
        el.setPointerCapture(event.pointerId);
        bringToFront(widget);
        el.classList.add('is-dragging');
        gesture = { type: 'drag', start: { x: event.clientX, y: event.clientY }, origin: boxOf(widget), moved: false };
      }
      return;
    }

    if (points.size === 2 && movable) {
      const [a, b] = Array.from(points.values());
      tap = null;
      el.classList.remove('is-dragging');
      el.classList.add('is-sizing');
      gesture = {
        type: 'pinch',
        startDistance: Math.max(16, pointDistance(a, b)),
        startCenter: pointMiddle(a, b),
        origin: boxOf(widget),
      };
      try {
        el.setPointerCapture(event.pointerId);
      } catch (_) { /* manche Geräte erlauben nur eine Erfassung */ }
    }
  });

  el.addEventListener('pointermove', (event) => {
    if (!points.has(event.pointerId)) return;
    points.set(event.pointerId, { x: event.clientX, y: event.clientY });
    if (!gesture) return;

    if (gesture.type === 'drag') {
      const dx = (event.clientX - gesture.start.x) / scale;
      const dy = (event.clientY - gesture.start.y) / scale;
      if (!gesture.moved && Math.abs(dx) + Math.abs(dy) < 2) return;
      gesture.moved = true;
      widget.x = Math.round(clamp(gesture.origin.x + dx, 0, Math.max(0, BOARD_WIDTH - widget.w)));
      widget.y = Math.round(clamp(gesture.origin.y + dy, 0, Math.max(0, BOARD_HEIGHT - widget.h)));
      layout();
      return;
    }

    if (gesture.type === 'pinch' && points.size >= 2) {
      const [a, b] = Array.from(points.values());
      const ratio = clamp(pointDistance(a, b) / gesture.startDistance, 0.15, 8);
      const center = pointMiddle(a, b);
      const origin = gesture.origin;
      const w = origin.w * ratio;
      const h = origin.h * ratio;
      const centerX = origin.x + origin.w / 2 + (center.x - gesture.startCenter.x) / scale;
      const centerY = origin.y + origin.h / 2 + (center.y - gesture.startCenter.y) / scale;
      applyBox(widget, { x: centerX - w / 2, y: centerY - h / 2, w, h });
      layout();
    }
  });

  const release = (event) => {
    points.delete(event.pointerId);
    const finished = gesture;

    if (finished && points.size === 0) {
      el.classList.remove('is-dragging', 'is-sizing');
      if (finished.type === 'pinch' || finished.moved) touch({ reason: 'widget-move' });
      gesture = null;
      if (finished.type === 'pinch' || finished.moved) tap = null;
    } else if (finished && finished.type === 'pinch' && points.size < 2) {
      // Ein Finger bleibt liegen — die Geste endet, es beginnt kein Verschieben.
      el.classList.remove('is-sizing');
      gesture = null;
      tap = null;
      touch({ reason: 'widget-size' });
    }

    if (!tap || points.size > 0) return;
    const finger = tap;
    tap = null;
    if (!finger.armed) return;
    if (Date.now() - finger.time > 800) return;
    if (Math.abs(event.clientX - finger.x) + Math.abs(event.clientY - finger.y) > 14) return;
    const instance = instances.get(widget.id);
    if (!instance || !instance.api || !instance.api.onTap) return;
    if (mode === 'use' && instance.api.tapNeedsEditing) return;
    if (event.pointerType !== 'mouse') armTapGuard(event);
    instance.api.onTap();
  };

  el.addEventListener('pointerup', release);
  el.addEventListener('pointercancel', (event) => {
    points.delete(event.pointerId);
    gesture = null;
    tap = null;
    el.classList.remove('is-dragging', 'is-sizing');
  });
}

/** Ziehen an einem Eck-Anfasser des Auswahlrahmens. */
function startFrameResize(event, corner) {
  const board = getActiveBoard();
  const widget = board ? board.widgets.find((entry) => entry.id === selectedId) : null;
  if (!widget || widget.locked) return;
  event.preventDefault();
  event.stopPropagation();
  const target = event.currentTarget;
  target.setPointerCapture(event.pointerId);
  const start = { x: event.clientX, y: event.clientY };
  const origin = boxOf(widget);
  const min = minSizeOf(widget);

  const move = (moveEvent) => {
    const dx = (moveEvent.clientX - start.x) / scale;
    const dy = (moveEvent.clientY - start.y) / scale;
    let { x, y, w, h } = origin;
    if (corner.includes('e')) w = origin.w + dx;
    if (corner.includes('s')) h = origin.h + dy;
    if (corner.includes('w')) {
      w = origin.w - dx;
      x = origin.x + dx;
    }
    if (corner.includes('n')) {
      h = origin.h - dy;
      y = origin.y + dy;
    }
    if (w < min.w) {
      if (corner.includes('w')) x -= min.w - w;
      w = min.w;
    }
    if (h < min.h) {
      if (corner.includes('n')) y -= min.h - h;
      h = min.h;
    }
    applyBox(widget, { x, y, w, h });
    layout();
  };

  const up = () => {
    target.removeEventListener('pointermove', move);
    target.removeEventListener('pointerup', up);
    target.removeEventListener('pointercancel', up);
    touch({ reason: 'widget-size' });
  };

  target.addEventListener('pointermove', move);
  target.addEventListener('pointerup', up);
  target.addEventListener('pointercancel', up);
}

/** Der Auswahlrahmen liegt über der Tafel — so werden die Anfasser nicht beschnitten. */
function buildSelectionFrame() {
  selectionFrame = h('div', { class: 'selection-frame' });
  for (const corner of ['nw', 'ne', 'sw', 'se']) {
    const handle = h('span', { class: `handle handle--${corner}`, 'data-handle': corner, title: 'Größe ändern' });
    handle.addEventListener('pointerdown', (event) => startFrameResize(event, corner));
    selectionFrame.appendChild(handle);
  }
  canvasEl.appendChild(selectionFrame);
}

function updateSelectionFrame() {
  if (!selectionFrame) return;
  const board = getActiveBoard();
  const widget = board ? board.widgets.find((entry) => entry.id === selectedId) : null;
  const show = Boolean(widget) && mode === 'edit' && !stackMode && !widget.locked
    && !document.body.classList.contains('is-presenting');
  selectionFrame.classList.toggle('is-visible', show);
  if (!show) return;
  selectionFrame.style.transform = `translate(${widget.x}px, ${widget.y}px)`;
  selectionFrame.style.width = `${widget.w}px`;
  selectionFrame.style.height = `${widget.h}px`;
  selectionFrame.style.zIndex = String((widget.z || 1) + 500);
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
    el.classList.toggle('widget--bare', isBare(widget, board));
    el.style.setProperty('--w-scale', contentScale(widget).toFixed(3));
  }
  if (stackMode) {
    for (const [, instance] of instances) {
      if (instance.api && instance.api.onResize) instance.api.onResize();
    }
  }
  updateSelectionFrame();
  renderSelection();
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
  updateSelectionFrame();
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
      class: 'tool-button', title: 'Kleiner',
      onclick: () => scaleWidget(widget, 0.85),
      html: icon('minus', 18),
    }),
    h('button', {
      class: 'tool-button', title: 'Größer',
      onclick: () => scaleWidget(widget, 1.18),
      html: icon('plus', 18),
    }),
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
      class: 'tool-button' + (widget.bare ? ' is-on' : ''), title: widget.bare ? 'Rahmen zeigen' : 'Rahmen ausblenden',
      onclick: () => {
        widget.bare = !widget.bare;
        touch({ reason: 'widget-frame' });
        layout();
        renderSelection();
      },
      html: icon(widget.bare ? 'frameOff' : 'frameOn', 18),
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
