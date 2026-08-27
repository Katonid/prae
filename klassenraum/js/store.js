// Zustand der App: Klassenräume (Boards), Widgets, Namenslisten, Einstellungen.
// Gespeichert wird lokal in IndexedDB (Fallback: localStorage).

import { uid, debounce } from './util.js';

const DB_NAME = 'klassenraum';
const DB_VERSION = 2;
const DB_STORE = 'kv';
const MEDIA_STORE = 'media';
const STATE_KEY = 'state';
const LS_KEY = 'klassenraum.state.v1';
const STATE_VERSION = 1;

export const BOARD_WIDTH = 1600;
// Vorgabe-Höhe (16:10) — die tatsächliche Höhe einer Tafel liefert boardHeight().
export const BOARD_HEIGHT = 1000;

/**
 * Wählbares Format der Tafelfläche: Die Breite bleibt immer 1600, die Höhe
 * richtet sich nach dem Format. So füllt die Tafel z. B. ein 16:9-Whiteboard
 * ohne Seitenränder — und weil das Format zur Tafel gehört (und mitwandert),
 * sieht die Anordnung auf allen Geräten weiterhin identisch aus.
 */
export const BOARD_FORMATS = [
  { id: '16:10', label: '16:10', height: 1000, hint: 'Der Mittelweg (Vorgabe) — kleine Ränder auf Whiteboard und iPad.' },
  { id: '16:9', label: '16:9 (Whiteboard/Beamer)', height: 900, hint: 'Füllt Whiteboards und Beamer randlos.' },
  { id: '4:3', label: '4:3 (iPad)', height: 1200, hint: 'Füllt das iPad-Querformat fast randlos.' },
];

export function boardHeight(board = getActiveBoard()) {
  const entry = board ? BOARD_FORMATS.find((format) => format.id === board.format) : null;
  return entry ? entry.height : BOARD_HEIGHT;
}

/** Format einer Tafel ändern; alles wird in die neue Fläche hineingeholt. */
export function setBoardFormat(board, formatId) {
  if (!board || !BOARD_FORMATS.some((format) => format.id === formatId)) return;
  board.format = formatId;
  const height = boardHeight(board);
  for (const page of board.pages || []) {
    for (const widget of page.widgets || []) {
      if (widget.h > height) widget.h = height;
      widget.y = Math.max(0, Math.min(widget.y, height - widget.h));
    }
  }
  touch({ reason: 'board-format' });
  emit('widgets-changed', board);
}

let dbPromise = null;

function openDb() {
  if (dbPromise) return dbPromise;
  dbPromise = new Promise((resolve, reject) => {
    if (!window.indexedDB) {
      reject(new Error('IndexedDB nicht verfügbar'));
      return;
    }
    const request = window.indexedDB.open(DB_NAME, DB_VERSION);
    request.onupgradeneeded = () => {
      const db = request.result;
      if (!db.objectStoreNames.contains(DB_STORE)) db.createObjectStore(DB_STORE);
      // Klänge und Videos liegen als Datei-Objekte in einem eigenen Speicher.
      if (!db.objectStoreNames.contains(MEDIA_STORE)) db.createObjectStore(MEDIA_STORE);
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

/* ---------- Dateien (Klänge, Videos) ---------- */

export async function mediaPut(key, record) {
  const db = await openDb();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(MEDIA_STORE, 'readwrite');
    tx.objectStore(MEDIA_STORE).put(record, key);
    tx.oncomplete = () => resolve(true);
    tx.onerror = () => reject(tx.error);
  });
}

export async function mediaGet(key) {
  const db = await openDb();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(MEDIA_STORE, 'readonly');
    const request = tx.objectStore(MEDIA_STORE).get(key);
    request.onsuccess = () => resolve(request.result || null);
    request.onerror = () => reject(request.error);
  });
}

export async function mediaDelete(key) {
  const db = await openDb();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(MEDIA_STORE, 'readwrite');
    tx.objectStore(MEDIA_STORE).delete(key);
    tx.oncomplete = () => resolve(true);
    tx.onerror = () => reject(tx.error);
  });
}

export async function mediaKeys() {
  const db = await openDb();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(MEDIA_STORE, 'readonly');
    const request = tx.objectStore(MEDIA_STORE).getAllKeys();
    request.onsuccess = () => resolve(request.result || []);
    request.onerror = () => reject(request.error);
  });
}

export const PALETTE = [
  '#33415c', '#1f2937', '#0f766e', '#3f3d56', '#4c1d95',
  '#7c2d12', '#1e3a8a', '#134e4a', '#111827', '#f8fafc',
  '#fef3c7', '#dbeafe', '#dcfce7', '#fee2e2', '#ede9fe',
];

/** Eine leere Seite einer Tafel — jede Tafel hat mindestens eine. */
export function emptyPage() {
  return { id: uid('page'), name: '', widgets: [], drawing: [] };
}

export function defaultBoard(name = 'Neuer Klassenraum') {
  const page = emptyPage();
  return {
    id: uid('board'),
    name,
    background: { type: 'aurora', value: 'nordlicht' },
    cardStyle: 'glass',
    accent: 'indigo',
    gradient: true,
    frames: 'always',
    labels: 'always',
    format: '16:10',
    pages: [page],
    activePageId: page.id,
    updatedAt: Date.now(),
  };
}

function starterBoard() {
  const board = defaultBoard('Klasse 4a');
  board.pages[0].widgets = [
    {
      id: uid('w'), type: 'clock', x: 80, y: 130, w: 420, h: 420, z: 1,
      state: { mode: 'analog', face: 'modern', showSeconds: true, showDate: false, accent: null },
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
      // Schrift der App — Vorgabe ist eine Grundschulschrift mit rundem a.
      font: 'lexend',
      stackModeManual: null,
      showGrid: false,
      mode: 'edit',
    },
    cloud: {
      // Pro Board: { code, editKey, autoPush, followCode }
      shares: {},
      account: null,
      // Abgleich zwischen Geräten: { spaceId, deviceId, auto, pushed, lastSyncAt }
      sync: null,
      // Gelöschte Tafeln und Listen: { id: Zeitpunkt } — damit das Löschen mitwandert.
      tombstones: {},
    },
  };
}

const listeners = new Map();
let state = defaultState();
let ready = false;
// true, wenn beim Start nichts im Speicher lag (frisches Gerät oder geleert).
let freshStart = false;

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
  next.boards = next.boards.map((board) => {
    const pages = normalizePages(board);
    return {
      id: board.id || uid('board'),
      name: board.name || 'Klassenraum',
      background: board.background || { type: 'aurora', value: 'nordlicht' },
      cardStyle: board.cardStyle || 'glass',
      accent: board.accent || 'indigo',
      gradient: board.gradient !== false,
      frames: board.frames || 'always',
      labels: board.labels || 'always',
      format: BOARD_FORMATS.some((format) => format.id === board.format) ? board.format : '16:10',
      pages,
      activePageId: pages.some((page) => page.id === board.activePageId) ? board.activePageId : pages[0].id,
      updatedAt: board.updatedAt || Date.now(),
      // Wann zuletzt umgeblättert wurde — eigener Stempel NEBEN updatedAt.
      viewedAt: Number(board.viewedAt) || 0,
    };
  });
  if (!next.boards.some((board) => board.id === next.activeBoardId)) {
    next.activeBoardId = next.boards[0].id;
  }
  if (!next.cloud.shares || typeof next.cloud.shares !== 'object') next.cloud.shares = {};
  if (!next.cloud.tombstones || typeof next.cloud.tombstones !== 'object') next.cloud.tombstones = {};
  next.lists = next.lists.map((list) => ({
    id: list.id || uid('list'),
    name: list.name || 'Liste',
    names: Array.isArray(list.names) ? list.names : [],
    // Pausierte Namen (z. B. krank) bleiben in der Liste, werden aber nicht gezogen.
    paused: Array.isArray(list.paused) ? list.paused : [],
    // Merkmale je Name (z. B. „J“/„M“) — fürs Mischen beim Gruppen-Auslosen.
    marks: list.marks && typeof list.marks === 'object' ? list.marks : {},
    // Gedächtnis der Auslosungen — gehört zur Liste (gilt über alle Tafeln):
    // paare zählt, wer mit wem zusammen war; dran, wer schon Tagesgruppe war.
    paare: list.paare && typeof list.paare === 'object' ? list.paare : {},
    dran: list.dran && typeof list.dran === 'object' ? list.dran : {},
    updatedAt: list.updatedAt || Date.now(),
  }));
  return next;
}

/**
 * Seiten einer Tafel aufbereiten. Ältere Stände kannten keine Seiten —
 * dort werden `widgets` und `drawing` der Tafel zur ersten Seite.
 */
function normalizePages(board) {
  const raw = Array.isArray(board.pages) && board.pages.length
    ? board.pages
    : [{ id: board.activePageId, widgets: board.widgets, drawing: board.drawing }];
  return raw.map((page) => ({
    id: page.id || uid('page'),
    name: typeof page.name === 'string' ? page.name : '',
    widgets: Array.isArray(page.widgets) ? page.widgets.map(normalizeWidget) : [],
    drawing: Array.isArray(page.drawing) ? page.drawing : [],
  }));
}

function migrateWidgetState(widget) {
  if (widget.type === 'clock' && widget.state && widget.state.accent === '#6366f1') {
    // Frühere Vorgabe: Indigo. Ab jetzt folgt die Uhr dem Farbschema.
    widget.state.accent = null;
  }
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
    // Herkunfts-Kennung für per Code gekoppelte Elemente (Auslosung/Klang):
    // darüber finden sich dasselbe Feld auf verschiedenen Geräten wieder.
    originId: typeof widget.originId === 'string' && widget.originId ? widget.originId : undefined,
    type: widget.type,
    x: Number.isFinite(widget.x) ? widget.x : 100,
    y: Number.isFinite(widget.y) ? widget.y : 100,
    w: Number.isFinite(widget.w) ? widget.w : 360,
    h: Number.isFinite(widget.h) ? widget.h : 260,
    z: Number.isFinite(widget.z) ? widget.z : 1,
    locked: Boolean(widget.locked),
    bare: Boolean(widget.bare),
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
  freshStart = !loaded;
  state = normalizeState(loaded);
  // Altbestand aufräumen: gleichnamige Tafeln deterministisch unterscheiden.
  enforceUniqueBoardNames();
  ready = true;
  emit('loaded', state);
  return state;
}

/** Lag beim Start nichts im Speicher? (Gerät neu oder Speicher geleert.) */
export function isFreshStart() {
  return freshStart;
}

// Wurde in dieser Sitzung schon inhaltlich gearbeitet? (Unterscheidet ein
// unberührtes frisches Gerät von einem, auf dem bereits etwas entstand.)
let contentTouched = false;

export function boardsTouched() {
  return contentTouched;
}

/** Eindeutigen Tafel-Namen finden — hängt notfalls „(2)", „(3)" … an. */
export function uniqueBoardName(base, ignoreId = null) {
  const wanted = String(base || '').trim() || 'Klassenraum';
  const taken = (name) => state.boards.some((board) => board.id !== ignoreId && board.name === name);
  if (!taken(wanted)) return wanted;
  let n = 2;
  while (taken(`${wanted} (${n})`)) n += 1;
  return `${wanted} (${n})`;
}

/**
 * Gleichnamige Tafeln deterministisch auseinanderhalten: je Namensgruppe
 * behält die Tafel mit der kleinsten Kennung den Namen, die übrigen bekommen
 * „(2)", „(3)" … — auf jedem Gerät dieselbe Zuordnung, bewusst OHNE neuen
 * Zeitstempel (reine Aufbereitung, kein Abgleich-Ping-Pong).
 */
export function enforceUniqueBoardNames() {
  const groups = new Map();
  for (const board of state.boards) {
    const key = (board.name || '').trim() || 'Klassenraum';
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(board);
  }
  let changed = false;
  for (const [name, boards] of groups) {
    if (boards.length < 2) continue;
    const sorted = boards.slice().sort((a, b) => (a.id < b.id ? -1 : 1));
    for (let index = 1; index < sorted.length; index += 1) {
      let n = index + 1;
      let candidate = `${name} (${n})`;
      while (state.boards.some((other) => other !== sorted[index] && other.name === candidate)) {
        n += 1;
        candidate = `${name} (${n})`;
      }
      sorted[index].name = candidate;
      changed = true;
    }
  }
  return changed;
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
  if (board && options.board !== false) {
    board.updatedAt = Date.now();
    contentTouched = true;
  }
  persistSoon();
  emit('change', { reason: options.reason || 'update' });
}

/** Änderung an einer bestimmten Tafel melden (z. B. Umbenennen aus der Liste). */
export function touchBoard(boardId, options = {}) {
  const board = state.boards.find((entry) => entry.id === boardId);
  if (board) {
    board.updatedAt = Date.now();
    contentTouched = true;
  }
  persistSoon();
  emit('change', { reason: options.reason || 'board-update' });
}

export function saveNow() {
  return persist();
}

export function getActiveBoard() {
  return state.boards.find((board) => board.id === state.activeBoardId) || state.boards[0] || null;
}

/* ---------- Seiten einer Tafel ---------- */

/** Die gerade aufgeschlagene Seite einer Tafel (Vorgabe: die aktive Tafel). */
export function getActivePage(board = getActiveBoard()) {
  if (!board) return null;
  if (!Array.isArray(board.pages) || !board.pages.length) board.pages = [emptyPage()];
  return board.pages.find((page) => page.id === board.activePageId) || board.pages[0];
}

export function setActivePage(pageId) {
  const board = getActiveBoard();
  if (!board || !board.pages.some((page) => page.id === pageId)) return;
  if (board.activePageId === pageId) return;
  board.activePageId = pageId;
  // Die aufgeschlagene Seite wandert über den Abgleich mit (eigener
  // „view"-Datensatz mit viewedAt) — aber sie stempelt NICHT den Inhalt:
  // Sonst machte bloßes Umblättern eine alte Tafel zur „neueren" und
  // blockierte im Abgleich echte Änderungen anderer Geräte („neuer gewinnt").
  board.viewedAt = Date.now();
  touch({ board: false, reason: 'page-switch' });
  emit('page-switch', pageId);
}

export function addPage() {
  const board = getActiveBoard();
  if (!board) return null;
  const page = emptyPage();
  board.pages.push(page);
  board.activePageId = page.id;
  touch({ reason: 'page-add' });
  emit('page-switch', page.id);
  return page;
}

/** Seite entfernen — die letzte Seite einer Tafel bleibt immer bestehen. */
export function removePage(pageId) {
  const board = getActiveBoard();
  if (!board || board.pages.length <= 1) return false;
  const index = board.pages.findIndex((page) => page.id === pageId);
  if (index < 0) return false;
  board.pages.splice(index, 1);
  if (board.activePageId === pageId) {
    board.activePageId = board.pages[Math.max(0, index - 1)].id;
  }
  touch({ reason: 'page-remove' });
  emit('page-switch', board.activePageId);
  return true;
}

/** Seite umbenennen — ohne Namen zeigt die App „Seite N". */
export function renamePage(pageId, name) {
  const board = getActiveBoard();
  const page = board && (board.pages || []).find((entry) => entry.id === pageId);
  if (!page) return;
  page.name = String(name || '').trim();
  touch({ reason: 'page-rename' });
}

/** Seite in der Reihenfolge verschieben (step -1 = nach vorn, +1 = nach hinten). */
export function movePageBy(pageId, step) {
  const board = getActiveBoard();
  if (!board) return false;
  const index = board.pages.findIndex((page) => page.id === pageId);
  const target = index + step;
  if (index < 0 || target < 0 || target >= board.pages.length) return false;
  const [page] = board.pages.splice(index, 1);
  board.pages.splice(target, 0, page);
  touch({ reason: 'page-move' });
  emit('page-switch', board.activePageId);
  return true;
}

/** Alle Elemente einer Tafel über alle Seiten hinweg (z. B. zum Zählen). */
export function allWidgetsOf(board) {
  if (!board || !Array.isArray(board.pages)) return [];
  return board.pages.flatMap((page) => page.widgets || []);
}

export function setActiveBoard(boardId) {
  if (!state.boards.some((board) => board.id === boardId)) return;
  state.activeBoardId = boardId;
  touch({ board: false, reason: 'board-switch' });
  emit('board-switch', boardId);
}

export function addBoard(name) {
  // Gleiche Namen sind tabu — sonst lassen sich Klassenräume nicht unterscheiden.
  const board = defaultBoard(uniqueBoardName(name || `Klassenraum ${state.boards.length + 1}`));
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
  copy.name = uniqueBoardName(`${source.name} (Kopie)`);
  copy.updatedAt = Date.now();
  const activeIndex = Math.max(0, copy.pages.findIndex((page) => page.id === copy.activePageId));
  copy.pages = copy.pages.map((page) => Object.assign({}, page, {
    id: uid('page'),
    widgets: page.widgets.map((widget) => Object.assign({}, widget, { id: uid('w') })),
  }));
  copy.activePageId = copy.pages[activeIndex].id;
  state.boards.push(copy);
  state.activeBoardId = copy.id;
  touch({ board: false, reason: 'board-duplicate' });
  emit('board-switch', copy.id);
  return copy;
}

export function removeBoard(boardId, { tombstone = true } = {}) {
  if (state.boards.length <= 1) return false;
  const index = state.boards.findIndex((board) => board.id === boardId);
  if (index < 0) return false;
  state.boards.splice(index, 1);
  delete state.cloud.shares[boardId];
  if (tombstone) markDeleted(boardId);
  if (state.activeBoardId === boardId) {
    state.activeBoardId = state.boards[Math.max(0, index - 1)].id;
    emit('board-switch', state.activeBoardId);
  }
  touch({ board: false, reason: 'board-remove' });
  return true;
}

/** Merkt sich, dass etwas gelöscht wurde — der Abgleich trägt das weiter. */
export function markDeleted(id, when = Date.now()) {
  if (!state.cloud.tombstones) state.cloud.tombstones = {};
  state.cloud.tombstones[id] = when;
}

export function getTombstones() {
  if (!state.cloud.tombstones) state.cloud.tombstones = {};
  return state.cloud.tombstones;
}

/** Alte Löschvermerke aufräumen (nach 60 Tagen kennt sie ohnehin niemand mehr). */
export function pruneTombstones(maxAgeMs = 60 * 24 * 3600 * 1000) {
  const stones = getTombstones();
  const limit = Date.now() - maxAgeMs;
  for (const [id, when] of Object.entries(stones)) {
    if (!Number.isFinite(when) || when < limit) delete stones[id];
  }
}

export function importBoard(board, { activate = true } = {}) {
  const clean = normalizeState({ boards: [board], activeBoardId: board.id }).boards[0];
  clean.id = uid('board');
  clean.name = uniqueBoardName(clean.name, clean.id);
  for (const page of clean.pages) {
    page.widgets = page.widgets.map((widget) => Object.assign({}, widget, { id: uid('w') }));
  }
  state.boards.push(clean);
  if (activate) {
    state.activeBoardId = clean.id;
    emit('board-switch', clean.id);
  }
  touch({ board: false, reason: 'board-import' });
  return clean;
}

/** Tafel mit vorhandener Kennung einfügen oder ersetzen (Abgleich). */
export function upsertBoard(raw) {
  const clean = normalizeState({ boards: [raw], activeBoardId: raw.id }).boards[0];
  clean.id = raw.id || clean.id;
  clean.updatedAt = raw.updatedAt || Date.now();
  const index = state.boards.findIndex((board) => board.id === clean.id);
  if (index >= 0) state.boards[index] = clean;
  else state.boards.push(clean);
  return clean;
}

/** Namensliste mit vorhandener Kennung einfügen oder ersetzen (Abgleich). */
export function upsertList(raw) {
  const clean = {
    id: raw.id || uid('list'),
    name: raw.name || 'Liste',
    names: Array.isArray(raw.names) ? raw.names : [],
    paused: Array.isArray(raw.paused) ? raw.paused : [],
    marks: raw.marks && typeof raw.marks === 'object' ? raw.marks : {},
    paare: raw.paare && typeof raw.paare === 'object' ? raw.paare : {},
    dran: raw.dran && typeof raw.dran === 'object' ? raw.dran : {},
    updatedAt: raw.updatedAt || Date.now(),
  };
  const index = state.lists.findIndex((list) => list.id === clean.id);
  if (index >= 0) state.lists[index] = clean;
  else state.lists.push(clean);
  return clean;
}

export function nextZ() {
  const page = getActivePage();
  if (!page || page.widgets.length === 0) return 1;
  return Math.max(...page.widgets.map((widget) => widget.z || 1)) + 1;
}

export function addWidget(widget) {
  const board = getActiveBoard();
  const page = getActivePage(board);
  if (!page) return null;
  const full = normalizeWidget(Object.assign({ z: nextZ() }, widget));
  page.widgets.push(full);
  touch({ reason: 'widget-add' });
  emit('widgets-changed', board);
  return full;
}

export function removeWidget(widgetId) {
  const board = getActiveBoard();
  const page = getActivePage(board);
  if (!page) return;
  const index = page.widgets.findIndex((widget) => widget.id === widgetId);
  if (index < 0) return;
  page.widgets.splice(index, 1);
  touch({ reason: 'widget-remove' });
  emit('widgets-changed', board);
}

export function duplicateWidget(widgetId) {
  const board = getActiveBoard();
  const page = getActivePage(board);
  if (!page) return null;
  const source = page.widgets.find((widget) => widget.id === widgetId);
  if (!source) return null;
  const copy = JSON.parse(JSON.stringify(source));
  copy.id = uid('w');
  copy.x = Math.min(BOARD_WIDTH - copy.w, copy.x + 40);
  copy.y = Math.min(boardHeight(board) - copy.h, copy.y + 40);
  copy.z = nextZ();
  page.widgets.push(copy);
  touch({ reason: 'widget-duplicate' });
  emit('widgets-changed', board);
  return copy;
}

export function getList(listId) {
  return state.lists.find((list) => list.id === listId) || null;
}

export function addList(name, names) {
  const list = { id: uid('list'), name: name || 'Neue Liste', names: names || [], paused: [], updatedAt: Date.now() };
  state.lists.push(list);
  touch({ board: false, reason: 'list-add' });
  emit('lists-changed', state.lists);
  return list;
}

export function updateList(listId, patch) {
  const list = getList(listId);
  if (!list) return null;
  Object.assign(list, patch, { updatedAt: Date.now() });
  touch({ board: false, reason: 'list-update' });
  emit('lists-changed', state.lists);
  return list;
}

export function removeList(listId, { tombstone = true } = {}) {
  const index = state.lists.findIndex((list) => list.id === listId);
  if (index < 0) return;
  state.lists.splice(index, 1);
  if (tombstone) markDeleted(listId);
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
