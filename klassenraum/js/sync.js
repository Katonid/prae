// Abgleich zwischen Geräten: alle Tafeln und Namenslisten liegen in einem
// „Bereich" der Firebase-Datenbank und werden zwischen den angemeldeten Geräten
// abgeglichen — iPad, Rechner und interaktive Tafel zeigen denselben Stand.
//
// Regeln, bewusst einfach gehalten:
// * Jede Tafel und jede Liste ist ein eigener Datensatz mit Zeitstempel.
// * Bei zwei Ständen gewinnt der neuere („zuletzt gespeichert gewinnt").
// * Gelöschtes wird als Vermerk mitgeschickt, damit es überall verschwindet.
// * Ohne Netz läuft alles lokal weiter; beim nächsten Verbinden wird nachgeholt.

import { uid, debounce } from './util.js';
import {
  getState, saveNow, emit, on as onStore, upsertBoard, upsertList, removeBoard, removeList,
  markDeleted, getTombstones, pruneTombstones, getActiveBoard, addBoard,
} from './store.js';
import {
  initCloud, createSpace, fetchSpace, putRecord, subscribeSpace, createLinkCode, resolveLinkCode,
  putMediaRecord, fetchMediaRecord, listMediaRecords, deleteMediaRecord,
  rememberSpaceForAccount, spaceOfAccount, onAccountChanged,
} from './cloud.js';
import { mediaGet, mediaPut, mediaKeys } from './store.js';
import { usedMediaIds } from './media.js';
import { renderBoard } from './board.js';

const PUSH_DELAY = 2200;
// Nur Dateien bis zu dieser Größe wandern mit — größere bleiben auf dem Gerät.
export const MEDIA_SYNC_LIMIT = 25 * 1024 * 1024;

let unsubscribeSpace = null;
let activeSpaceId = null;
let status = 'off'; // off | busy | ok | error
let lastError = '';
let applying = false;
const listeners = new Set();

/** Abgleich-Einstellungen im Zustand — werden bei Bedarf angelegt. */
export function syncSettings() {
  const cloud = getState().cloud;
  if (!cloud.sync || typeof cloud.sync !== 'object') {
    cloud.sync = { spaceId: null, deviceId: uid('dev'), auto: true, pushed: {}, pushedMedia: {}, lastSyncAt: 0 };
  }
  if (!cloud.sync.deviceId) cloud.sync.deviceId = uid('dev');
  if (!cloud.sync.pushed || typeof cloud.sync.pushed !== 'object') cloud.sync.pushed = {};
  if (!cloud.sync.pushedMedia || typeof cloud.sync.pushedMedia !== 'object') cloud.sync.pushedMedia = {};
  return cloud.sync;
}

export function syncInfo() {
  const settings = syncSettings();
  return {
    active: Boolean(settings.spaceId),
    spaceId: settings.spaceId,
    auto: settings.auto !== false,
    lastSyncAt: settings.lastSyncAt || 0,
    status,
    error: lastError,
  };
}

export function onSyncChanged(listener) {
  listeners.add(listener);
  listener(syncInfo());
  return () => listeners.delete(listener);
}

function announce(next, error = '') {
  if (next) status = next;
  lastError = error;
  const info = syncInfo();
  listeners.forEach((listener) => {
    try {
      listener(info);
    } catch (_) { /* eine kaputte Anzeige darf den Abgleich nicht stoppen */ }
  });
}

/* ---------- Hochladen ---------- */

function boardRecord(board, deviceId) {
  return { updatedAt: board.updatedAt || Date.now(), by: deviceId, kind: 'board', data: JSON.parse(JSON.stringify(board)) };
}

function listRecord(list, deviceId) {
  return { updatedAt: list.updatedAt || Date.now(), by: deviceId, kind: 'list', data: JSON.parse(JSON.stringify(list)) };
}

/** Schickt alles hoch, was sich seit dem letzten Mal geändert hat. */
async function pushChanges() {
  const settings = syncSettings();
  if (!settings.spaceId) return;
  const state = getState();
  const jobs = [];

  for (const board of state.boards) {
    const stamp = board.updatedAt || 0;
    if (settings.pushed[board.id] === stamp) continue;
    jobs.push({ kind: 'boards', id: board.id, record: boardRecord(board, settings.deviceId), stamp });
  }
  for (const list of state.lists) {
    const stamp = list.updatedAt || 0;
    if (settings.pushed[list.id] === stamp) continue;
    jobs.push({ kind: 'lists', id: list.id, record: listRecord(list, settings.deviceId), stamp });
  }
  for (const [id, when] of Object.entries(getTombstones())) {
    if (settings.pushed[id] === when) continue;
    const kind = String(id).startsWith('list') ? 'lists' : 'boards';
    jobs.push({ kind, id, record: { updatedAt: when, by: settings.deviceId, deleted: true }, stamp: when });
  }

  const wantMedia = Array.from(usedMediaIds()).some((id) => !settings.pushedMedia[id]);
  if (!jobs.length && !wantMedia) return;
  announce('busy');
  try {
    for (const job of jobs) {
      await putRecord(settings.spaceId, job.kind, job.id, job.record);
      settings.pushed[job.id] = job.stamp;
    }
    await pushMedia();
    settings.lastSyncAt = Date.now();
    await saveNow();
    announce('ok');
  } catch (error) {
    announce('error', 'Senden nicht möglich');
  }
}

/* ---------- Dateien (Klänge, Videos) ---------- */

function blobToBase64(blob) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result).split(',')[1] || '');
    reader.onerror = () => reject(reader.error || new Error('Lesen fehlgeschlagen'));
    reader.readAsDataURL(blob);
  });
}

async function base64ToBlob(data, type) {
  const response = await fetch(`data:${type || 'application/octet-stream'};base64,${data}`);
  return response.blob();
}

/** Alle benutzten Dateien hochladen, die der Bereich noch nicht kennt. */
async function pushMedia() {
  const settings = syncSettings();
  if (!settings.spaceId) return;
  const used = usedMediaIds();
  for (const mediaId of used) {
    if (settings.pushedMedia[mediaId]) continue;
    const record = await mediaGet(mediaId).catch(() => null);
    if (!record || !record.blob) continue;
    if (record.size > MEDIA_SYNC_LIMIT) {
      // Zu groß fürs Mitschicken — merken, damit es nicht jedes Mal geprüft wird.
      settings.pushedMedia[mediaId] = 'zu-gross';
      continue;
    }
    const data = await blobToBase64(record.blob);
    await putMediaRecord(settings.spaceId, mediaId, {
      name: record.name || 'Datei',
      type: record.type || '',
      size: record.size || 0,
      updatedAt: record.savedAt || Date.now(),
      by: settings.deviceId,
      data,
    });
    settings.pushedMedia[mediaId] = true;
  }
}

/** Dateien holen, auf die Tafeln zeigen, die aber lokal fehlen. */
async function pullMissingMedia() {
  const settings = syncSettings();
  if (!settings.spaceId) return false;
  const used = usedMediaIds();
  if (!used.size) return false;
  const local = new Set(await mediaKeys().catch(() => []));
  let fetched = false;
  for (const mediaId of used) {
    if (local.has(mediaId)) continue;
    const record = await fetchMediaRecord(settings.spaceId, mediaId).catch(() => null);
    if (!record || !record.data) continue;
    const blob = await base64ToBlob(record.data, record.type).catch(() => null);
    if (!blob) continue;
    await mediaPut(mediaId, {
      blob,
      name: record.name || 'Datei',
      type: record.type || '',
      size: record.size || blob.size,
      savedAt: record.updatedAt || Date.now(),
    });
    settings.pushedMedia[mediaId] = true;
    fetched = true;
  }
  if (fetched) {
    // Klang- und Videokarten zeigen die Datei erst nach einem Neuaufbau an.
    renderBoard();
    emit('media-synced');
  }
  return fetched;
}

const pullMediaSoon = debounce(() => {
  pullMissingMedia().catch(() => {});
}, 1200);

/** Nicht mehr benutzte Dateien auch aus dem Bereich entfernen. */
async function cleanupRemoteMedia() {
  const settings = syncSettings();
  if (!settings.spaceId) return;
  const used = usedMediaIds();
  const remote = await listMediaRecords(settings.spaceId).catch(() => []);
  for (const mediaId of remote) {
    if (used.has(mediaId)) continue;
    await deleteMediaRecord(settings.spaceId, mediaId).catch(() => {});
    delete settings.pushedMedia[mediaId];
  }
}

const pushSoon = debounce(() => {
  const settings = syncSettings();
  if (!settings.spaceId || settings.auto === false || applying) return;
  pushChanges();
}, PUSH_DELAY);

/* ---------- Herunterladen und zusammenführen ---------- */

function mergeBoardRecord(id, record) {
  if (!record) return false;
  const settings = syncSettings();
  const state = getState();
  const local = state.boards.find((board) => board.id === id);
  const stones = getTombstones();

  if (record.deleted) {
    settings.pushed[id] = record.updatedAt;
    if (!local) {
      markDeleted(id, record.updatedAt);
      return false;
    }
    if ((local.updatedAt || 0) > record.updatedAt) return false;
    // Die letzte Tafel bleibt stehen — ohne Tafel könnte die App nichts zeigen.
    if (state.boards.length <= 1) return false;
    removeBoard(id, { tombstone: false });
    markDeleted(id, record.updatedAt);
    return true;
  }

  if (!record.data) return false;
  if (stones[id] && stones[id] >= record.updatedAt) return false;
  // Der lokale Stand ist neuer — er wird beim nächsten Senden hochgeladen.
  if (local && (local.updatedAt || 0) >= record.updatedAt) return false;
  upsertBoard(Object.assign({}, record.data, { id, updatedAt: record.updatedAt }));
  settings.pushed[id] = record.updatedAt;
  return true;
}

function mergeListRecord(id, record) {
  if (!record) return false;
  const settings = syncSettings();
  const state = getState();
  const local = state.lists.find((list) => list.id === id);
  const stones = getTombstones();

  if (record.deleted) {
    settings.pushed[id] = record.updatedAt;
    if (!local) {
      markDeleted(id, record.updatedAt);
      return false;
    }
    if ((local.updatedAt || 0) > record.updatedAt) return false;
    removeList(id, { tombstone: false });
    markDeleted(id, record.updatedAt);
    return true;
  }

  if (!record.data) return false;
  if (stones[id] && stones[id] >= record.updatedAt) return false;
  if (local && (local.updatedAt || 0) >= record.updatedAt) return false;
  upsertList(Object.assign({}, record.data, { id, updatedAt: record.updatedAt }));
  settings.pushed[id] = record.updatedAt;
  return true;
}

/** Übernimmt einen ganzen Bereich (Erststart, Neuladen, Nachfragen ohne Ereignisstrom). */
function mergeSpace(payload) {
  if (!payload) return false;
  let changed = false;
  const activeBefore = getActiveBoard();
  applying = true;
  for (const [id, record] of Object.entries(payload.boards || {})) {
    if (mergeBoardRecord(id, record)) changed = true;
  }
  for (const [id, record] of Object.entries(payload.lists || {})) {
    if (mergeListRecord(id, record)) changed = true;
  }
  applying = false;
  if (changed) afterMerge(activeBefore);
  return changed;
}

/** Einzelne Meldung des Ereignisstroms, z. B. { path: '/boards/board-7', data: {...} }. */
function mergeEvent(detail) {
  if (!detail || typeof detail.path !== 'string') return;
  const parts = detail.path.split('/').filter(Boolean);
  const activeBefore = getActiveBoard();
  applying = true;
  let changed = false;
  if (parts.length === 2 && parts[0] === 'boards') changed = mergeBoardRecord(parts[1], detail.data);
  else if (parts.length === 2 && parts[0] === 'lists') changed = mergeListRecord(parts[1], detail.data);
  else if (parts.length === 1 && parts[0] === 'boards') {
    for (const [id, record] of Object.entries(detail.data || {})) {
      if (mergeBoardRecord(id, record)) changed = true;
    }
  } else if (parts.length === 1 && parts[0] === 'lists') {
    for (const [id, record] of Object.entries(detail.data || {})) {
      if (mergeListRecord(id, record)) changed = true;
    }
  }
  applying = false;
  if (changed) afterMerge(activeBefore);
}

function afterMerge(activeBefore) {
  const settings = syncSettings();
  const state = getState();
  if (!state.boards.some((board) => board.id === state.activeBoardId)) {
    state.activeBoardId = state.boards[0] ? state.boards[0].id : null;
    emit('board-switch', state.activeBoardId);
  }
  settings.lastSyncAt = Date.now();
  saveNow();
  renderBoard();
  emit('lists-changed', state.lists);
  emit('change', { reason: 'sync' });
  if (activeBefore && getActiveBoard() !== activeBefore) emit('board-switch', state.activeBoardId);
  announce('ok');
  // Zeigen die neuen Tafeln auf Dateien, die hier fehlen, werden sie nachgeladen.
  pullMediaSoon();
}

/* ---------- Verbindung ---------- */

async function connect(spaceId) {
  if (unsubscribeSpace && activeSpaceId === spaceId) return;
  if (unsubscribeSpace) {
    unsubscribeSpace();
    unsubscribeSpace = null;
  }
  activeSpaceId = spaceId;
  announce('busy');
  try {
    unsubscribeSpace = await subscribeSpace(spaceId, (payload, detail) => {
      if (detail) mergeEvent(detail);
      else mergeSpace(payload);
    });
    await pushChanges();
    announce('ok');
  } catch (error) {
    announce('error', 'Keine Verbindung');
  }
}

function disconnect() {
  if (unsubscribeSpace) unsubscribeSpace();
  unsubscribeSpace = null;
  activeSpaceId = null;
}

/* ---------- Öffentliche Bedienung ---------- */

/** Abgleich einrichten: neuen Bereich anlegen und alles hochladen. */
export async function startSync() {
  await initCloud();
  const settings = syncSettings();
  const spaceId = await createSpace(getState().settings.profileName || '');
  settings.spaceId = spaceId;
  settings.auto = true;
  settings.pushed = {};
  settings.pushedMedia = {};
  await saveNow();
  rememberSpaceCookie(spaceId);
  await rememberSpaceForAccount(spaceId);
  await connect(spaceId);
  return spaceId;
}

/** Kopplungscode für ein weiteres Gerät erzeugen (eine Stunde gültig). */
export async function linkCode() {
  const settings = syncSettings();
  if (!settings.spaceId) throw new Error('Abgleich ist nicht eingerichtet');
  return createLinkCode(settings.spaceId);
}

/**
 * Dieses Gerät an einen vorhandenen Bereich hängen (Kennung liegt schon vor).
 * `keepLocal = false` heißt: Dieses Gerät übernimmt nur den Stand des Bereichs —
 * praktisch für ein frisches Gerät, das sonst seine Beispieltafel mitbrächte.
 */
export async function adoptSpace(spaceId, { keepLocal = true } = {}) {
  await initCloud();
  const settings = syncSettings();
  settings.spaceId = spaceId;
  settings.auto = true;
  settings.pushed = {};
  settings.pushedMedia = {};
  const state = getState();
  if (!keepLocal) {
    state.boards = [];
    state.lists = [];
    state.cloud.shares = {};
  }
  await saveNow();
  rememberSpaceCookie(spaceId);
  await rememberSpaceForAccount(spaceId);
  const payload = await fetchSpace(spaceId);
  mergeSpace(payload);
  if (!state.boards.length) addBoard('Klassenraum');
  await pullMissingMedia().catch(() => {});
  await connect(spaceId);
  await pushChanges();
  return spaceId;
}

/** Dieses Gerät mit einem Kopplungscode an einen vorhandenen Bereich hängen. */
export async function joinSync(code, { keepLocal = true } = {}) {
  await initCloud();
  const spaceId = await resolveLinkCode(code);
  return adoptSpace(spaceId, { keepLocal });
}

/** Von Hand abgleichen: erst holen, dann senden. */
export async function syncNow() {
  const settings = syncSettings();
  if (!settings.spaceId) return false;
  announce('busy');
  try {
    const payload = await fetchSpace(settings.spaceId);
    mergeSpace(payload);
    await pushChanges();
    await pullMissingMedia();
    // Von Hand angestoßen ist der richtige Moment zum Aufräumen.
    await cleanupRemoteMedia();
    settings.lastSyncAt = Date.now();
    await saveNow();
    announce('ok');
    return true;
  } catch (error) {
    announce('error', 'Abgleich nicht möglich');
    return false;
  }
}

/** Abgleich auf diesem Gerät beenden; die Tafeln bleiben lokal erhalten. */
export async function stopSync() {
  const settings = syncSettings();
  settings.spaceId = null;
  settings.pushed = {};
  settings.pushedMedia = {};
  forgetSpaceCookie();
  disconnect();
  await saveNow();
  announce('off');
}

export function setAutoSync(value) {
  const settings = syncSettings();
  settings.auto = Boolean(value);
  saveNow();
  if (settings.auto) pushSoon();
  announce();
}

/*
 * Zweite Sicherung der Bereichskennung in einem langlebigen Cookie: Manche
 * Tafel-Geräte (z. B. Whiteboards im Kiosk-Betrieb) leeren regelmäßig
 * IndexedDB und localStorage — Cookies überleben das teils. Beim nächsten
 * Start verbindet sich das Gerät damit von selbst wieder.
 */
const SPACE_COOKIE = 'klassenraum_raum';

function rememberSpaceCookie(spaceId) {
  try {
    const path = window.location.pathname.replace(/[^/]*$/, '') || '/';
    document.cookie = `${SPACE_COOKIE}=${encodeURIComponent(spaceId)}; max-age=${400 * 24 * 3600}; path=${path}; SameSite=Lax`;
  } catch (_) { /* ohne Cookie eben nur der normale Speicher */ }
}

function forgetSpaceCookie() {
  try {
    const path = window.location.pathname.replace(/[^/]*$/, '') || '/';
    document.cookie = `${SPACE_COOKIE}=; max-age=0; path=${path}; SameSite=Lax`;
  } catch (_) { /* egal */ }
}

export function spaceFromCookie() {
  try {
    const match = document.cookie.match(new RegExp(`(?:^|; )${SPACE_COOKIE}=([^;]+)`));
    return match ? decodeURIComponent(match[1]) : null;
  } catch (_) {
    return null;
  }
}

export function initSync() {
  pruneTombstones();

  onStore('change', (payload) => {
    if (payload && payload.reason === 'sync') return;
    const settings = syncSettings();
    if (settings.auto === false || !settings.spaceId) return;
    pushSoon();
  });

  // Kommt das Gerät aus dem Ruhezustand zurück, wird der Stand nachgeholt.
  document.addEventListener('visibilitychange', () => {
    if (!document.hidden && syncSettings().spaceId) syncNow();
  });

  // Sobald Konten aktiv sind, findet ein neues Gerät den Bereich über die Anmeldung.
  onAccountChanged(async (account) => {
    if (!account || syncSettings().spaceId) return;
    const remembered = await spaceOfAccount().catch(() => null);
    if (!remembered) return;
    const current = syncSettings();
    current.spaceId = remembered;
    current.pushed = {};
    await saveNow();
    const payload = await fetchSpace(remembered).catch(() => null);
    if (payload) mergeSpace(payload);
    connect(remembered);
  });

  const settings = syncSettings();
  if (settings.spaceId) connect(settings.spaceId);
  else announce('off');
}
