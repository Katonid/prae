// Die Tafelfläche: Elemente anzeigen, verschieben, vergrößern, auswählen.

import { h, clear, clamp, armTapGuard } from './util.js';
import { icon } from './icons.js';
import { getWidgetType } from './widgets/index.js';
import {
  BOARD_WIDTH, boardHeight, AURORA, getActiveBoard, getActivePage, getState, touch, removeWidget,
  duplicateWidget, nextZ, on as onStore,
} from './store.js';
import { openPanel, closePanel, confirmDialog, field, button, buttonRow, toast } from './ui.js';
import { transferWidget } from './transfer.js';
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
// Ansicht: 1 = ganze Tafel im Bild, größer = hineingezoomt (wichtig am Telefon).
let zoom = 1;
let panX = 0;
let panY = 0;
const ZOOM_MIN = 1;
const ZOOM_MAX = 6;
const viewListeners = new Set();
let mode = 'edit';
let armedId = null;

// Manche Chromium-Browser auf interaktiven Tafeln (IR-Touchrahmen) brechen
// laufende Zieh-Gesten ab, wenn touchmove nicht ausdrücklich beansprucht wird.
// Safari (iPad/iPhone) ist das Gegenteil: Fängt man dort touchmove ab, versiegt
// der Zeigerstrom und das Ziehen friert ein — deshalb gilt der Zusatzgriff nur
// für Chromium; Safari respektiert touch-action: none von allein.
const CLAIM_TOUCHMOVE = /Chrome|Chromium|CriOS|Edg|SamsungBrowser|Android/.test(navigator.userAgent);

/* ---------- Berührungs-Fehlersuche ----------
 * Zeigt am Gerät selbst, welche Zeiger-Ereignisse ankommen — für Fälle, in
 * denen sich Ziehen oder Tippen nur auf echter Hardware seltsam verhält.
 * Einschalten im Menü unter „Über". Ausgeschaltet kostet das nichts.
 */
let debugBox = null;

export function togglePointerDebug() {
  if (debugBox) {
    debugBox.remove();
    debugBox = null;
    return false;
  }
  debugBox = h('div', { class: 'pointer-debug' });
  document.body.appendChild(debugBox);
  dlog('Fehlersuche an — jetzt ein Element ziehen. Ausschalten wieder im Menü.');
  return true;
}

function dlog(text) {
  if (!debugBox) return;
  const line = document.createElement('div');
  line.textContent = text;
  debugBox.appendChild(line);
  while (debugBox.childElementCount > 16) debugBox.firstElementChild.remove();
}

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

/* ---------- Ansicht: hineinzoomen und verschieben ---------- */

// Ein Finger auf der freien Fläche verschiebt, zwei Finger zoomen.
const stagePoints = new Map();
let stageGesture = null;

function startStageGesture(event) {
  // Beim Schreiben gehört die Fläche dem Stift.
  if (stackMode || document.body.classList.contains('is-drawing')) return;
  // Verwaiste Zeiger verwerfen (siehe attachInteractions) — sonst würde ein
  // Ein-Finger-Wischen auf der Fläche fälschlich zoomen statt verschieben.
  if (event.isPrimary && stagePoints.size) {
    stagePoints.clear();
    stageGesture = null;
  }
  stagePoints.set(event.pointerId, { x: event.clientX, y: event.clientY });
  if (stagePoints.size === 1) {
    stageGesture = { type: 'pan', last: { x: event.clientX, y: event.clientY }, moved: false };
    return;
  }
  if (stagePoints.size === 2) {
    const [a, b] = Array.from(stagePoints.values());
    stageGesture = {
      type: 'pinch',
      startDistance: Math.hypot(a.x - b.x, a.y - b.y) || 1,
      startZoom: zoom,
    };
  }
}

function moveStageGesture(event) {
  if (!stageGesture || !stagePoints.has(event.pointerId)) return;
  stagePoints.set(event.pointerId, { x: event.clientX, y: event.clientY });
  if (stageGesture.type === 'pan') {
    const dx = event.clientX - stageGesture.last.x;
    const dy = event.clientY - stageGesture.last.y;
    if (Math.abs(dx) + Math.abs(dy) < 1) return;
    stageGesture.moved = true;
    panBy(dx, dy);
    stageGesture.last = { x: event.clientX, y: event.clientY };
    return;
  }
  if (stageGesture.type === 'pinch' && stagePoints.size >= 2) {
    const [a, b] = Array.from(stagePoints.values());
    const distance = Math.hypot(a.x - b.x, a.y - b.y) || 1;
    setZoom(stageGesture.startZoom * (distance / stageGesture.startDistance), {
      x: (a.x + b.x) / 2,
      y: (a.y + b.y) / 2,
    });
  }
}

function endStageGesture(event) {
  stagePoints.delete(event.pointerId);
  if (stagePoints.size === 0) {
    // Nur speichern, wenn wirklich verschoben wurde — ein Tipp ins Leere nicht.
    if (stageGesture && (stageGesture.type === 'pinch' || stageGesture.moved)) storeView();
    stageGesture = null;
  } else if (stagePoints.size === 1) {
    const [only] = Array.from(stagePoints.values());
    stageGesture = { type: 'pan', last: { x: only.x, y: only.y }, moved: false };
  }
}

export function getZoom() {
  return zoom;
}

export function onViewChanged(listener) {
  viewListeners.add(listener);
  listener(zoom);
  return () => viewListeners.delete(listener);
}

function announceView() {
  viewListeners.forEach((listener) => {
    try {
      listener(zoom);
    } catch (_) { /* eine kaputte Anzeige darf die Tafel nicht stoppen */ }
  });
}

function storeView() {
  const settings = getState().settings;
  settings.view = { zoom, panX, panY };
  touch({ board: false, reason: 'view' });
}

/** Verschiebung so begrenzen, dass die Tafel nicht aus dem Bild wandert. */
function clampPan() {
  if (!stageEl) return;
  const rect = stageEl.getBoundingClientRect();
  const overX = Math.max(0, (BOARD_WIDTH * scale - rect.width) / 2);
  const overY = Math.max(0, (boardHeight() * scale - rect.height) / 2);
  panX = clamp(panX, -overX, overX);
  panY = clamp(panY, -overY, overY);
}

/**
 * Zoom setzen; `anchor` (Bildschirmpunkt) bleibt dabei möglichst an Ort und Stelle.
 */
export function setZoom(next, anchor = null) {
  if (stackMode || !stageEl) return;
  const wanted = clamp(next, ZOOM_MIN, ZOOM_MAX);
  if (Math.abs(wanted - zoom) < 0.001) return;
  const rect = stageEl.getBoundingClientRect();
  const point = anchor || { x: rect.left + rect.width / 2, y: rect.top + rect.height / 2 };
  const relX = point.x - rect.left - rect.width / 2 - panX;
  const relY = point.y - rect.top - rect.height / 2 - panY;
  const factor = wanted / zoom;
  panX -= relX * (factor - 1);
  panY -= relY * (factor - 1);
  zoom = wanted;
  updateScale();
  layout();
  storeView();
  announceView();
}

export function zoomBy(factor, anchor = null) {
  setZoom(zoom * factor, anchor);
}

/** Zurück auf „ganze Tafel im Bild". */
export function resetView() {
  zoom = 1;
  panX = 0;
  panY = 0;
  updateScale();
  layout();
  storeView();
  announceView();
}

function panBy(dx, dy) {
  panX += dx;
  panY += dy;
  clampPan();
  updateScale();
  layout();
}

export function initBoard(elements) {
  canvasEl = elements.canvas;
  stageEl = elements.stage;
  selectionEl = elements.selection;
  buildSelectionFrame();

  stageEl.addEventListener('pointerdown', (event) => {
    // Alles, was kein Element und keine Bedienleiste ist, zählt als freie Fläche.
    const held = event.target.closest
      && event.target.closest('.widget, .handle, .selection-toolbar, .view-controls, .page-controls, .draw-toolbar');
    if (held) return;
    select(null);
    clearArmed();
    startStageGesture(event);
  });

  stageEl.addEventListener('pointermove', moveStageGesture);
  for (const name of ['pointerup', 'pointercancel', 'pointerleave']) {
    stageEl.addEventListener(name, endStageGesture);
  }
  // Auch das Verschieben/Zoomen der Fläche vor dem Browser schützen (s. u.
  // bei den Elementen: manche Touch-Rahmen brechen Gesten sonst ab).
  if (CLAIM_TOUCHMOVE) {
    stageEl.addEventListener('touchmove', (event) => {
      if (stageGesture) event.preventDefault();
    }, { passive: false });
  }

  stageEl.addEventListener('wheel', (event) => {
    // Nur mit gedrückter Steuerungstaste zoomen — sonst bliebe die Tafel unruhig.
    if (!event.ctrlKey && !event.metaKey) return;
    event.preventDefault();
    zoomBy(event.deltaY < 0 ? 1.12 : 1 / 1.12, { x: event.clientX, y: event.clientY });
  }, { passive: false });

  stageEl.addEventListener('dblclick', (event) => {
    if (event.target !== stageEl && event.target !== canvasEl && event.target.id !== 'stage-bg') return;
    resetView();
  });

  window.addEventListener('resize', () => {
    updateScale();
    layout();
  });

  const stored = getState().settings.view;
  if (stored && Number.isFinite(stored.zoom)) {
    zoom = clamp(stored.zoom, ZOOM_MIN, ZOOM_MAX);
    panX = Number.isFinite(stored.panX) ? stored.panX : 0;
    panY = Number.isFinite(stored.panY) ? stored.panY : 0;
    announceView();
  }

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
  // Umblättern wirkt wie ein Tafelwechsel: andere Elemente, gleiche Gestaltung.
  onStore('page-switch', () => {
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
  const fit = Math.min(rect.width / BOARD_WIDTH, rect.height / boardHeight());
  scale = fit * zoom;
  clampPan();
  const offsetX = (rect.width - BOARD_WIDTH * scale) / 2 + panX;
  const offsetY = (rect.height - boardHeight() * scale) / 2 + panY;
  canvasEl.style.width = `${BOARD_WIDTH}px`;
  canvasEl.style.height = `${boardHeight()}px`;
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
      // Auf Wunsch abgedunkelt, damit sich Elemente und Schrift abheben.
      const dim = clamp(Number(background.dim) || 0, 0, 0.8);
      layer.style.background = `linear-gradient(rgba(2, 6, 23, ${dim}), rgba(2, 6, 23, ${dim})), `
        + `url("${background.value}") center/cover no-repeat #0b1120`;
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
  // Listen wachsen mit der Breite: Ein breites Feld soll breite, große Zeilen
  // zeigen — wird es dadurch zu hoch, scrollt die Liste einfach.
  const ratio = definition && definition.scaleBy === 'width'
    ? widget.w / size.w
    : Math.min(widget.w / size.w, widget.h / size.h);
  return clamp(ratio, 0.6, 4);
}

/** Die Elemente der gerade aufgeschlagenen Seite dieser Tafel. */
function widgetsOf(board) {
  const page = getActivePage(board);
  return page ? page.widgets : [];
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
  for (const widget of widgetsOf(board)) {
    seen.add(widget.id);
    if (!instances.has(widget.id)) mountWidget(widget);
    else {
      const instance = instances.get(widget.id);
      if (instance.widget !== widget) {
        // Abgleich oder Live-Folgen hat hinter derselben Kennung ein neues
        // Widget-Objekt eingesetzt — Kontext und Anzeige müssen mitziehen,
        // sonst zeigt das Element für immer den alten Stand (und Ziehen
        // schriebe in ein verwaistes Objekt).
        instance.widget = widget;
        if (instance.ctx) instance.ctx.widget = widget;
        if (instance.api && instance.api.refresh) instance.api.refresh();
      }
    }
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
  // ctx.widget wird beim Abgleich/Live-Folgen gegen das neue Objekt getauscht
  // (renderBoard) — deshalb hier überall über ctx.widget zugreifen, nie über
  // die eingefrorene Ausgangsvariable.
  const ctx = {
    widget,
    save() {
      touch({ reason: 'widget-state' });
    },
    refresh() {
      const instance = instances.get(ctx.widget.id);
      if (instance && instance.api && instance.api.refresh) instance.api.refresh();
    },
    instance() {
      const instance = instances.get(ctx.widget.id);
      return instance ? instance.api : null;
    },
    setSize(w, h) {
      ctx.widget.w = clamp(Math.round(w), 120, BOARD_WIDTH);
      ctx.widget.h = clamp(Math.round(h), 90, boardHeight());
      touch({ reason: 'widget-size' });
      layout();
      const instance = instances.get(ctx.widget.id);
      if (instance && instance.api && instance.api.onResize) instance.api.onResize();
    },
    openLists() {
      hooks.onOpenLists();
    },
    isEditing() {
      return mode === 'edit';
    },
    openSettings() {
      openWidgetSettings(ctx.widget.id);
    },
  };
  return ctx;
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
  const h = clamp(Math.round(box.h), min.h, boardHeight());
  widget.w = w;
  widget.h = h;
  widget.x = Math.round(clamp(box.x, 0, Math.max(0, BOARD_WIDTH - w)));
  widget.y = Math.round(clamp(box.y, 0, Math.max(0, boardHeight() - h)));
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

/** In Eingabefeldern gehört die Bewegung dem Text (Auswahl, Cursor) — nie dem Verschieben. */
function inTextField(target) {
  if (!target || !target.closest) return false;
  return Boolean(target.closest('input, textarea, select, [contenteditable]'));
}

/** Video- und Tonspieler behalten ihre eigenen Bedienelemente. */
function inNativeMedia(target) {
  if (!target || !target.closest) return false;
  return Boolean(target.closest('video, audio'));
}

const pointDistance = (a, b) => Math.hypot(a.x - b.x, a.y - b.y);
const pointMiddle = (a, b) => ({ x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 });

/**
 * Alles an einem Element in einer Hand: Tippen löst die Hauptfunktion aus,
 * Ziehen verschiebt, zwei Finger verändern stufenlos die Größe.
 */
function attachInteractions(el, mounted) {
  // Beim Abgleich oder Live-Folgen wird das Widget-Objekt hinter derselben
  // Kennung ausgetauscht — deshalb bei jedem Ereignis das aktuelle Objekt
  // auflösen, statt das beim Aufbau übergebene festzuhalten (sonst schreibt
  // Ziehen in ein verwaistes Objekt und das Element bewegt sich nicht).
  const widgetNow = () => {
    const instance = instances.get(mounted.id);
    return (instance && instance.widget) || mounted;
  };
  const points = new Map();
  let gesture = null;
  let tap = null;

  el.addEventListener('pointerdown', (event) => {
    if (event.button !== undefined && event.button > 0) return;
    const widget = widgetNow();
    // Verwaiste Zeiger aufräumen: Geht ein Loslassen verloren (IR-Rahmen an
    // interaktiven Tafeln und Safari verschlucken so etwas gelegentlich),
    // bliebe der alte Punkt für immer stehen — jeder weitere Ein-Finger-Zug
    // sähe dann aus wie eine Zwei-Finger-Geste und würde skalieren statt
    // verschieben. Ein neuer Erst-Finger (isPrimary) beweist, dass kein
    // anderer Finger mehr aufliegt.
    if (event.isPrimary && points.size) {
      points.clear();
      gesture = null;
      el.classList.remove('is-dragging', 'is-sizing');
      dlog(`verwaiste Zeiger verworfen (${widget.type})`);
    }
    points.set(event.pointerId, { x: event.clientX, y: event.clientY });
    if (mode === 'edit') select(widget.id);

    const onControl = Boolean(event.target.closest && event.target.closest('[data-nodrag]'));
    const movable = mode === 'edit' && !stackMode && !widget.locked;
    if (onControl) setArmed(widget.id);

    if (points.size === 1) {
      tap = { x: event.clientX, y: event.clientY, time: Date.now(), armed: !onControl };
      if (movable && !onControl) {
        // Manche Touch-Rahmen (interaktive Tafeln) verweigern die Übernahme —
        // dann läuft das Ziehen eben ohne sie, statt gar nicht zu beginnen.
        try {
          el.setPointerCapture(event.pointerId);
        } catch (_) { /* dann eben ohne Übernahme */ }
        bringToFront(widget);
        el.classList.add('is-dragging');
        gesture = { type: 'drag', start: { x: event.clientX, y: event.clientY }, origin: boxOf(widget), moved: false };
      } else if (movable && !inTextField(event.target) && !inNativeMedia(event.target)) {
        // Auch Knöpfe und Leuchten dürfen als Griff dienen — gerade am Telefon
        // besteht ein Element oft fast nur aus Bedienfläche. Der Zeiger wird
        // sofort übernommen (mitten in der Geste klappt das auf dem iPad
        // nicht zuverlässig); bleibt es bei einem Tipp, wird der Knopf beim
        // Loslassen von Hand ausgelöst.
        try {
          el.setPointerCapture(event.pointerId);
        } catch (_) { /* dann eben ohne Übernahme */ }
        gesture = {
          type: 'maybe-drag',
          start: { x: event.clientX, y: event.clientY },
          origin: boxOf(widget),
          control: event.target,
        };
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
    dlog(`↓ ${event.pointerType} #${event.pointerId}${event.isPrimary ? '*' : ''} `
      + `Punkte=${points.size} Steuer=${onControl ? 'ja' : 'nein'} beweglich=${movable ? 'ja' : 'nein'} → ${gesture ? gesture.type : '—'}`);
  });

  el.addEventListener('pointermove', (event) => {
    if (!points.has(event.pointerId)) return;
    points.set(event.pointerId, { x: event.clientX, y: event.clientY });
    if (!gesture) return;
    const widget = widgetNow();

    if (gesture.type === 'maybe-drag') {
      const moved = Math.abs(event.clientX - gesture.start.x) + Math.abs(event.clientY - gesture.start.y);
      if (moved < 12) return;
      bringToFront(widget);
      el.classList.add('is-dragging');
      gesture = { type: 'drag', start: gesture.start, origin: gesture.origin, moved: false };
      tap = null;
      dlog('→ wird zu Ziehen (ab Bedienfläche)');
    }

    if (gesture.type === 'drag') {
      const dx = (event.clientX - gesture.start.x) / scale;
      const dy = (event.clientY - gesture.start.y) / scale;
      if (!gesture.moved && Math.abs(dx) + Math.abs(dy) < 2) return;
      if (!gesture.moved) dlog('… zieht');
      gesture.moved = true;
      widget.x = Math.round(clamp(gesture.origin.x + dx, 0, Math.max(0, BOARD_WIDTH - widget.w)));
      widget.y = Math.round(clamp(gesture.origin.y + dy, 0, Math.max(0, boardHeight() - widget.h)));
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
    const widget = widgetNow();
    points.delete(event.pointerId);
    const finished = gesture;
    dlog(`↑ #${event.pointerId} Geste=${finished ? finished.type : '—'}${finished && finished.moved ? ' (bewegt)' : ''} Punkte=${points.size}`);

    if (finished && points.size === 0) {
      el.classList.remove('is-dragging', 'is-sizing');
      if (finished.type === 'pinch' || finished.moved) touch({ reason: 'widget-move' });
      gesture = null;
      if (finished.type === 'pinch' || finished.moved) tap = null;

      // Tipp auf eine Bedienfläche: Der Zeiger war übernommen, der Knopf hat
      // weder pointerup noch click gesehen — deshalb wird er jetzt von Hand
      // ausgelöst. So bleibt jeder Knopf ein Griff UND ein Knopf.
      if (finished.type === 'maybe-drag' && finished.control) {
        const wanderung = Math.abs(event.clientX - finished.start.x) + Math.abs(event.clientY - finished.start.y);
        if (wanderung <= 14 && finished.control.isConnected) {
          tap = null;
          if (event.pointerType !== 'mouse') armTapGuard(event);
          // Trifft der Tipp das Symbol im Knopf (ein SVG ohne click-Methode),
          // wird der umschließende Knopf ausgelöst.
          const control = (finished.control.closest && finished.control.closest('[data-nodrag]')) || finished.control;
          if (typeof control.click === 'function') control.click();
        }
      }
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
    if (instance.api.tapNeedsFocus && armedId !== widget.id) {
      setArmed(widget.id);
      return;
    }
    instance.api.onTap();
  };

  el.addEventListener('pointerup', release);
  el.addEventListener('pointercancel', (event) => {
    points.delete(event.pointerId);
    dlog(`✕ ABBRUCH durch den Browser (#${event.pointerId}) — Geste war ${gesture ? gesture.type : '—'}`);
    gesture = null;
    tap = null;
    el.classList.remove('is-dragging', 'is-sizing');
  });

  // Gürtel und Hosenträger für widerspenstige Touch-Rahmen (interaktive
  // Tafeln): Solange eine Geste läuft, dem Browser die Berührung ausdrücklich
  // wegnehmen — sonst bricht er sie mit pointercancel ab, und das Element
  // lässt sich nicht verschieben. Nur in Chromium — Safari friert sonst ein
  // (siehe CLAIM_TOUCHMOVE oben).
  if (CLAIM_TOUCHMOVE) {
    el.addEventListener('touchmove', (event) => {
      if (gesture) event.preventDefault();
    }, { passive: false });
  }
}

/** Ziehen an einem Eck-Anfasser des Auswahlrahmens. */
function startFrameResize(event, corner) {
  const board = getActiveBoard();
  const widget = board ? widgetsOf(board).find((entry) => entry.id === selectedId) : null;
  if (!widget || widget.locked) return;
  event.preventDefault();
  event.stopPropagation();
  const target = event.currentTarget;
  try {
    target.setPointerCapture(event.pointerId);
  } catch (_) { /* dann eben ohne Übernahme */ }
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
  const widget = board ? widgetsOf(board).find((entry) => entry.id === selectedId) : null;
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
  const sorted = widgetsOf(board).slice().sort((a, b) => (a.y - b.y) || (a.x - b.x));
  for (const widget of widgetsOf(board)) {
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

/**
 * Manche Elemente — die Namenslisten — sollen nicht schon beim ersten Tipp
 * auslösen: Der erste Tipp aktiviert die Karte, erst der zweite zieht.
 */
function setArmed(widgetId) {
  if (armedId === widgetId) return;
  const previous = armedId;
  armedId = widgetId;
  for (const id of [previous, widgetId]) {
    if (!id) continue;
    const instance = instances.get(id);
    if (!instance) continue;
    instance.el.classList.toggle('is-armed', id === armedId);
    if (instance.api && instance.api.onArmedChange) instance.api.onArmedChange(id === armedId);
  }
}

export function clearArmed() {
  setArmed(null);
}

export function select(widgetId) {
  // Ein anderes Element anzutippen hebt die Aktivierung auf.
  if (armedId && armedId !== widgetId) setArmed(null);
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
  const widget = board ? widgetsOf(board).find((entry) => entry.id === selectedId) : null;
  if (!widget || stackMode || mode === 'use' || document.body.classList.contains('is-presenting')) {
    selectionEl.classList.remove('is-visible');
    return;
  }
  selectionEl.classList.add('is-visible');

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

  placeSelectionToolbar(widget);
}

/**
 * Die kleine Leiste sitzt über dem Element — am Telefon wird sie so
 * verschoben, dass sie vollständig auf dem Bildschirm bleibt.
 */
function placeSelectionToolbar(widget) {
  // Auf kleinen Bildschirmen ist die Tafel so verkleinert, dass eine frei
  // schwebende Leiste halbe Tafeln verdecken würde — dort sitzt sie fest unten.
  if (window.innerWidth <= 560) {
    selectionEl.classList.add('is-docked');
    selectionEl.style.left = '';
    selectionEl.style.top = '';
    return;
  }
  selectionEl.classList.remove('is-docked');
  const rect = stageEl.getBoundingClientRect();
  const offsetX = (rect.width - BOARD_WIDTH * scale) / 2 + panX;
  const offsetY = (rect.height - boardHeight() * scale) / 2 + panY;
  const width = selectionEl.offsetWidth || 200;
  const left = offsetX + widget.x * scale;
  const top = offsetY + widget.y * scale;
  selectionEl.style.left = `${clamp(left, 8, Math.max(8, rect.width - width - 8))}px`;
  selectionEl.style.top = `${Math.max(6, top - 52)}px`;
}

export function openWidgetSettings(widgetId) {
  const instance = instances.get(widgetId);
  if (!instance) return;
  const definition = instance.definition;
  if (!definition.settings) return;
  const content = h('div', { class: 'stack' },
    definition.settings(instance.ctx),
    transferFold(widgetId, definition));
  openPanel({
    title: definition.label,
    subtitle: 'Einstellungen für dieses Element',
    content,
  });
}

/** Eingeklappter Bereich unter jedem Element: in einen anderen Klassenraum übertragen. */
function transferFold(widgetId, definition) {
  const board = getActiveBoard();
  const others = getState().boards.filter((entry) => entry.id !== (board && board.id));
  if (!others.length) return null;
  const select = h('select', { class: 'input' },
    others.map((entry) => h('option', { value: entry.id }, entry.name)));
  const run = async (move) => {
    const target = others.find((entry) => entry.id === select.value) || others[0];
    const ok = await transferWidget(widgetId, target.id, { move });
    if (!ok) return;
    toast(`„${definition.label}“ nach „${target.name}“ ${move ? 'verschoben' : 'kopiert'} — dort auf die aufgeschlagene Seite.`, 'success');
    if (move) {
      closePanel();
      renderBoard();
    }
  };
  return h('details', { class: 'fold' },
    h('summary', { class: 'fold__head' }, 'In anderen Klassenraum übertragen'),
    h('div', { class: 'stack fold__body' },
      field('Ziel-Klassenraum', select),
      buttonRow(
        button('Kopieren', { icon: 'copy', small: true, onClick: () => run(false) }),
        button('Verschieben', { icon: 'share', small: true, onClick: () => run(true) })),
      h('p', { class: 'muted small' },
        'Landet dort auf der aufgeschlagenen Seite. Verknüpfte Klang- und Videodateien wandern automatisch mit; '
        + 'Namenslisten gelten ohnehin in allen Klassenräumen.')));
}

export function addWidgetOfType(type) {
  const definition = getWidgetType(type);
  const board = getActiveBoard();
  if (!definition || !board) return null;
  const size = definition.defaultSize || { w: 360, h: 260 };
  const spot = findFreeSpot(size, widgetsOf(board));
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
  for (let y = 80; y < boardHeight() - size.h; y += step) {
    for (let x = 60; x < BOARD_WIDTH - size.w; x += step) {
      const overlaps = widgets.some((widget) => !(x + size.w < widget.x || x > widget.x + widget.w
        || y + size.h < widget.y || y > widget.y + widget.h));
      if (!overlaps) return { x, y };
    }
  }
  const cascade = widgets.length % 8;
  return {
    x: Math.min(120 + cascade * 44, Math.max(0, BOARD_WIDTH - size.w)),
    y: Math.min(120 + cascade * 38, Math.max(0, boardHeight() - size.h)),
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
