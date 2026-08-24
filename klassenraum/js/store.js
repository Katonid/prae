// Zustand der App: Klassenräume (Boards), Widgets, Namenslisten, Einstellungen.
// Gespeichert wird lokal in IndexedDB (Fallback: localStorage).

import { uid, debounce } from './util.js';

const DB_NAME = 'klassenraum';
const DB_STORE = 'kv';
const STATE_KEY = 'state';
const LS_KEY = 'klassenraum.state.v1';
const STATE_VERSION = 1;

export const BOARD_WIDTH = 1600;
export const BOARD_HEIGHT = 1000;

let dbPromise = null;

function openDb() {
  if (dbPromise) return dbPromise;
  dbPromise = new Promise((resolve, reject) => {
    if (!window.indexedDB) {
      reject(new Error('IndexedDB nicht verfügbar'));
      return;
    }
    const request = window.indexedDB.open(DB_NAME, 1);
    request.onupgradeneeded = () => {
      const db = request.result;
      if (!db.objectStoreNames.contains(DB_STORE)) db.createObjectStore(DB_STORE);
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error || new Error('IndexedDB Fehler'));
  }).catch((error) => {
    dbPromise = null;
    throw error;
  });
  return dbPromise;
}

async function idbGet(key) {
  const db = await openDb();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(DB_STORE, 'readonly');
    const request = tx.objectStore(DB_STORE).get(key);
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

async function idbSet(key, value) {
  const db = await openDb();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(DB_STORE, 'readwrite');
    tx.objectStore(DB_STORE).put(value, key);
    tx.oncomplete = () => resolve(true);
    tx.onerror = () => reject(tx.error);
  });
}

export const AURORA = [
  { id: 'nordlicht', label: 'Nordlicht', base: '#0b1120', blobs: ['#4f46e5', '#06b6d4', '#a855f7'] },
  { id: 'sonnenaufgang', label: 'Sonnenaufgang', base: '#1e1b4b', blobs: ['#f97316', '#ec4899', '#6366f1'] },
  { id: 'waldgruen', label: 'Waldgrün', base: '#04241f', blobs: ['#10b981', '#22d3ee', '#84cc16'] },
  { id: 'beere', label: 'Beere', base: '#2b0b3a', blobs: ['#d946ef', '#6366f1', '#f43f5e'] },
  { id: 'tafel', label: 'Tafelgrün', base: '#0c231c', blobs: ['#0f766e', '#134e4a', '#15803d'] },
  { id: 'kreide', label: 'Kreide hell', base: '#eef2ff', blobs: ['#c7d2fe', '#a5f3fc', '#fbcfe8'] },
];

export const PALETTE = [
  '#33415c', '#1f2937', '#0f766e', '#3f3d56', '#4c1d95',
  '#7c2d12', '#1e3a8a', '#134e4a', '#111827', '#f8fafc',
  '#fef3c7', '#dbeafe', '#dcfce7', '#fee2e2', '#ede9fe',
];

export function defaultBoard(name = 'Neuer Klassenraum') {
  return {
    id: uid('board'),
    name,
    background: { type: 'aurora', value: 'nordlicht' },
    cardStyle: 'glass',
    widgets: [],
    updatedAt: Date.now(),
  };
}

function starterBoard() {
  const board = defaultBoard('Klasse 4a');
  board.widgets = [
    {
      id: uid('w'), type: 'clock', x: 80, y: 130, w: 420, h: 420, z: 1,
      state: { mode: 'analog', showSeconds: true, showDate: false, accent: '#6366f1' },
    },
    {
      id: uid('w'), type: 'randomizer', x: 560, y: 130, w: 620, h: 470, z: 2,
      state: {
        listId: null, localNames: ['Ada B.', 'Ada K.', 'Alma', 'Antonia', 'Bo', 'Bruno'],
        mode: 'exhaust', drawn: [], current: null, showDrawn: 'edit', animate: true,
        reveal: 'mosaik', revealParts: [],
      },
    },
    {
      id: uid('w'), type: 'timer', x: 1230, y: 130, w: 300, h: 300, z: 3,
      state: { seconds: 300, remaining: 300, running: false, endsAt: null, sound: true, mode: 'timer', elapsed: 0 },
    },
    {
      id: uid('w'), type: 'traffic', x: 80, y: 600, w: 220, h: 320, z: 4,
      state: { active: 'green' },
    },
    {
      id: uid('w'), type: 'checklist', x: 340, y: 600, w: 480, h: 320, z: 5,
      state: {
        title: 'Tagesablauf',
        items: [
          { id: uid('i'), text: 'Morgenkreis', done: true },
          { id: uid('i'), text: 'Deutsch: Lesetext', done: false },
          { id: uid('i'), text: 'Frühstückspause', done: false },
          { id: uid('i'), text: 'Mathe: Einmaleins', done: false },
        ],
      },
    },
    {
      id: uid('w'), type: 'noise', x: 860, y: 640, w: 420, h: 280, z: 6,
      state: { threshold: 55, sensitivity: 1, alarmSound: false, running: false },
    },
  ];
  return board;
}

export function defaultState() {
  const board = starterBoard();
  return {
    version: STATE_VERSION,
    boards: [board],
    activeBoardId: board.id,
    lists: [
      {
        id: uid('list'),
        name: 'Beispielklasse',
        names: ['Ada B.', 'Ada K.', 'Alma', 'Antonia', 'Bo', 'Bruno', 'Charlotte C.', 'Emil', 'Frida', 'Hannes'],
      },
    ],
    settings: {
      profileName: '',
      stackModeManual: null,
      showGrid: false,
      mode: 'edit',
    },
    cloud: {
      // Pro Board: { code, editKey, autoPush, followCode }
      shares: {},
      account: null,
    },
  };
}

const listeners = new Map();
let state = defaultState();
let ready = false;

export function getState() {
  return state;
}

export function isReady() {
  return ready;
}

export function on(event, handler) {
  if (!listeners.has(event)) listeners.set(event, new Set());
  listeners.get(event).add(handler);
  return () => listeners.get(event).delete(handler);
}

export function emit(event, payload) {
  const set = listeners.get(event);
  if (!set) return;
  for (const handler of Array.from(set)) {
    try {
      handler(payload);
    } catch (error) {
      console.error('Listener-Fehler', event, error);
    }
  }
}

function normalizeState(loaded) {
  const base = defaultState();
  if (!loaded || typeof loaded !== 'object') return base;
  const next = {
    version: STATE_VERSION,
    boards: Array.isArray(loaded.boards) && loaded.boards.length ? loaded.boards : base.boards,
    activeBoardId: loaded.activeBoardId || null,
    lists: Array.isArray(loaded.lists) ? loaded.lists : [],
    settings: Object.assign({}, base.settings, loaded.settings || {}),
    cloud: Object.assign({}, base.cloud, loaded.cloud || {}),
  };
  next.boards = next.boards.map((board) => ({
    id: board.id || uid('board'),
    name: board.name || 'Klassenraum',
    background: board.background || { type: 'aurora', value: 'nordlicht' },
    cardStyle: board.cardStyle || 'glass',
    widgets: Array.isArray(board.widgets) ? board.widgets.map(normalizeWidget) : [],
    updatedAt: board.updatedAt || Date.now(),
  }));
  if (!next.boards.some((board) => board.id === next.activeBoardId)) {
    next.activeBoardId = next.boards[0].id;
  }
  if (!next.cloud.shares || typeof next.cloud.shares !== 'object') next.cloud.shares = {};
  return next;
}

function migrateWidgetState(widget) {
  if (widget.type === 'randomizer' && widget.state) {
    // Frühere Fassung: showDrawn war ein Schalter, heute drei Stufen.
    if (widget.state.showDrawn === true) widget.state.showDrawn = 'edit';
    if (widget.state.showDrawn === false) widget.state.showDrawn = 'never';
    if (!widget.state.reveal) widget.state.reveal = 'mosaik';
    if (!Array.isArray(widget.state.revealParts)) widget.state.revealParts = [];
  }
  return widget;
}

function normalizeWidget(rawWidget) {
  const widget = migrateWidgetState(rawWidget);
  return {
    id: widget.id || uid('w'),
    type: widget.type,
    x: Number.isFinite(widget.x) ? widget.x : 100,
    y: Number.isFinite(widget.y) ? widget.y : 100,
    w: Number.isFinite(widget.w) ? widget.w : 360,
    h: Number.isFinite(widget.h) ? widget.h : 260,
    z: Number.isFinite(widget.z) ? widget.z : 1,
    locked: Boolean(widget.locked),
    state: widget.state && typeof widget.state === 'object' ? widget.state : {},
  };
}

export async function loadState() {
  let loaded = null;
  try {
    loaded = await idbGet(STATE_KEY);
  } catch (_) {
    loaded = null;
  }
  if (!loaded) {
    try {
      const raw = window.localStorage.getItem(LS_KEY);
      if (raw) loaded = JSON.parse(raw);
    } catch (_) {
      loaded = null;
    }
  }
  state = normalizeState(loaded);
  ready = true;
  emit('loaded', state);
  return state;
}

async function persist() {
  const snapshot = JSON.parse(JSON.stringify(state));
  try {
    await idbSet(STATE_KEY, snapshot);
  } catch (_) {
    try {
      window.localStorage.setItem(LS_KEY, JSON.stringify(snapshot));
    } catch (error) {
      console.warn('Speichern fehlgeschlagen', error);
    }
  }
  emit('saved', state);
}

const persistSoon = debounce(persist, 400);

/** Änderungen melden: markiert das aktive Board als geändert und speichert verzögert. */
export function touch(options = {}) {
  const board = getActiveBoard();
  if (board && options.board !== false) board.updatedAt = Date.now();
  persistSoon();
  emit('change', { reason: options.reason || 'update' });
}

export function saveNow() {
  return persist();
}

export function getActiveBoard() {
  return state.boards.find((board) => board.id === state.activeBoardId) || state.boards[0] || null;
}

export function setActiveBoard(boardId) {
  if (!state.boards.some((board) => board.id === boardId)) return;
  state.activeBoardId = boardId;
  touch({ board: false, reason: 'board-switch' });
  emit('board-switch', boardId);
}

export function addBoard(name) {
  const board = defaultBoard(name || `Klassenraum ${state.boards.length + 1}`);
  state.boards.push(board);
  state.activeBoardId = board.id;
  touch({ board: false, reason: 'board-add' });
  emit('board-switch', board.id);
  return board;
}

export function duplicateBoard(boardId) {
  const source = state.boards.find((board) => board.id === boardId);
  if (!source) return null;
  const copy = JSON.parse(JSON.stringify(source));
  copy.id = uid('board');
  copy.name = `${source.name} (Kopie)`;
  copy.updatedAt = Date.now();
  copy.widgets = copy.widgets.map((widget) => Object.assign({}, widget, { id: uid('w') }));
  state.boards.push(copy);
  state.activeBoardId = copy.id;
  touch({ board: false, reason: 'board-duplicate' });
  emit('board-switch', copy.id);
  return copy;
}

export function removeBoard(boardId) {
  if (state.boards.length <= 1) return false;
  const index = state.boards.findIndex((board) => board.id === boardId);
  if (index < 0) return false;
  state.boards.splice(index, 1);
  delete state.cloud.shares[boardId];
  if (state.activeBoardId === boardId) {
    state.activeBoardId = state.boards[Math.max(0, index - 1)].id;
    emit('board-switch', state.activeBoardId);
  }
  touch({ board: false, reason: 'board-remove' });
  return true;
}

export function importBoard(board, { activate = true } = {}) {
  const clean = normalizeState({ boards: [board], activeBoardId: board.id }).boards[0];
  clean.id = uid('board');
  clean.widgets = clean.widgets.map((widget) => Object.assign({}, widget, { id: uid('w') }));
  state.boards.push(clean);
  if (activate) {
    state.activeBoardId = clean.id;
    emit('board-switch', clean.id);
  }
  touch({ board: false, reason: 'board-import' });
  return clean;
}

export function nextZ() {
  const board = getActiveBoard();
  if (!board || board.widgets.length === 0) return 1;
  return Math.max(...board.widgets.map((widget) => widget.z || 1)) + 1;
}

export function addWidget(widget) {
  const board = getActiveBoard();
  if (!board) return null;
  const full = normalizeWidget(Object.assign({ z: nextZ() }, widget));
  board.widgets.push(full);
  touch({ reason: 'widget-add' });
  emit('widgets-changed', board);
  return full;
}

export function removeWidget(widgetId) {
  const board = getActiveBoard();
  if (!board) return;
  const index = board.widgets.findIndex((widget) => widget.id === widgetId);
  if (index < 0) return;
  board.widgets.splice(index, 1);
  touch({ reason: 'widget-remove' });
  emit('widgets-changed', board);
}

export function duplicateWidget(widgetId) {
  const board = getActiveBoard();
  if (!board) return null;
  const source = board.widgets.find((widget) => widget.id === widgetId);
  if (!source) return null;
  const copy = JSON.parse(JSON.stringify(source));
  copy.id = uid('w');
  copy.x = Math.min(BOARD_WIDTH - copy.w, copy.x + 40);
  copy.y = Math.min(BOARD_HEIGHT - copy.h, copy.y + 40);
  copy.z = nextZ();
  board.widgets.push(copy);
  touch({ reason: 'widget-duplicate' });
  emit('widgets-changed', board);
  return copy;
}

export function getList(listId) {
  return state.lists.find((list) => list.id === listId) || null;
}

export function addList(name, names) {
  const list = { id: uid('list'), name: name || 'Neue Liste', names: names || [] };
  state.lists.push(list);
  touch({ board: false, reason: 'list-add' });
  emit('lists-changed', state.lists);
  return list;
}

export function updateList(listId, patch) {
  const list = getList(listId);
  if (!list) return null;
  Object.assign(list, patch);
  touch({ board: false, reason: 'list-update' });
  emit('lists-changed', state.lists);
  return list;
}

export function removeList(listId) {
  const index = state.lists.findIndex((list) => list.id === listId);
  if (index < 0) return;
  state.lists.splice(index, 1);
  touch({ board: false, reason: 'list-remove' });
  emit('lists-changed', state.lists);
}

export function replaceState(next) {
  state = normalizeState(next);
  persistSoon();
  emit('change', { reason: 'replace' });
  emit('board-switch', state.activeBoardId);
  emit('lists-changed', state.lists);
}
