// Kopplung über den Teilen-Code: Nach dem Laden einer Kopie bleibt das
// Design unabhängig, ABER
//  - neue Auslosungs- und Klangfelder der teilenden Person erscheinen auch
//    auf den gekoppelten Geräten (und können dort gelöscht werden — sie
//    kommen dann nicht wieder),
//  - der Stand dieser Felder (ausgeloste/abgehakte Namen, Klangbelegung)
//    bleibt auf allen verknüpften Geräten gleich („neuer gewinnt").
//
// Ablage: shares/<CODE>/state/<Herkunfts-Kennung> je Feld; Klang-/Videodateien
// wandern base64-kodiert nach media/share-<CODE>/<Datei-Kennung> — bewusst
// NEBEN dem Teilen-Eintrag, damit der Abruf des Codes sie nicht mitlädt.

import { debounce, uid } from './util.js';
import {
  getState, getActiveBoard, boardHeight, BOARD_WIDTH, saveNow,
  on as onStore, mediaGet, mediaPut,
} from './store.js';
import { subscribeShare, putShareState, putMediaRecord, fetchMediaRecord } from './cloud.js';
import { blobToBase64, base64ToBlob, MEDIA_SYNC_LIMIT } from './sync.js';
import { renderBoard, refreshAll } from './board.js';

// Nur diese Feldarten werden gekoppelt — alles andere bleibt Design.
const COUPLE_TYPES = ['randomizer', 'sound'];

const subscriptions = new Map(); // boardId -> unsubscribe
let started = false;

function originIdOf(widget) {
  return widget.originId || widget.id;
}

function coupleEntries() {
  const shares = getState().cloud.shares || {};
  const result = [];
  for (const board of getState().boards) {
    const entry = shares[board.id];
    // Gekoppelt sind Kopien (coupled) UND die teilende Seite selbst —
    // beide sollen die Stände der jeweils anderen sehen. Live-Folgen
    // spiegelt ohnehin alles und braucht keine Kopplung.
    if (entry && entry.code && !entry.follow && (entry.coupled || entry.editKey)) {
      result.push({ board, entry });
    }
  }
  return result;
}

function bookkeeping(entry) {
  if (!entry.couple || typeof entry.couple !== 'object') {
    entry.couple = { hashes: {}, stamps: {}, dismissed: [], media: {} };
  }
  const c = entry.couple;
  if (!c.hashes || typeof c.hashes !== 'object') c.hashes = {};
  if (!c.stamps || typeof c.stamps !== 'object') c.stamps = {};
  if (!Array.isArray(c.dismissed)) c.dismissed = [];
  if (!c.media || typeof c.media !== 'object') c.media = {};
  return c;
}

function coupledWidgetsOf(board) {
  const list = [];
  for (const page of board.pages || []) {
    for (const widget of page.widgets || []) {
      if (COUPLE_TYPES.includes(widget.type)) list.push(widget);
    }
  }
  return list;
}

function stateHash(state) {
  return JSON.stringify(state || {});
}

function mediaIdsOf(state) {
  const ids = [];
  if (state && state.mediaId) ids.push(state.mediaId);
  for (const entry of (state && state.entries) || []) {
    if (entry.mediaId) ids.push(entry.mediaId);
  }
  return ids;
}

/** Fehlende Dateien eines übernommenen Standes aus der Kopplungs-Ablage holen. */
async function pullCoupleMedia(code, state) {
  for (const mediaId of mediaIdsOf(state)) {
    const local = await mediaGet(mediaId).catch(() => null);
    if (local) continue;
    const record = await fetchMediaRecord(`share-${code}`, mediaId).catch(() => null);
    if (!record || !record.data) continue;
    const blob = await base64ToBlob(record.data, record.type).catch(() => null);
    if (!blob) continue;
    await mediaPut(mediaId, {
      blob,
      name: record.name || 'Datei',
      type: record.type || '',
      size: record.size || blob.size,
      savedAt: record.updatedAt || Date.now(),
    }).catch(() => {});
  }
}

/** Eigene Dateien der gekoppelten Felder hochladen (einmal je Datei). */
async function pushCoupleMedia(code, keeper, state) {
  for (const mediaId of mediaIdsOf(state)) {
    if (keeper.media[mediaId]) continue;
    const record = await mediaGet(mediaId).catch(() => null);
    if (!record || !record.blob || record.size > MEDIA_SYNC_LIMIT) continue;
    try {
      const data = await blobToBase64(record.blob);
      await putMediaRecord(`share-${code}`, mediaId, {
        name: record.name || 'Datei',
        type: record.type || '',
        size: record.size || 0,
        updatedAt: record.savedAt || Date.now(),
        data,
      });
      keeper.media[mediaId] = true;
    } catch (_) { /* nächster Anlauf beim nächsten Senden */ }
  }
}

/** Ein bei uns noch unbekanntes gekoppeltes Feld anlegen (Kopie-Seite). */
function adoptWidget(board, origin) {
  const clone = JSON.parse(JSON.stringify(origin));
  clone.originId = originIdOf(origin);
  clone.id = uid('w');
  const height = boardHeight(board);
  clone.w = Math.min(clone.w || 360, BOARD_WIDTH);
  clone.h = Math.min(clone.h || 260, height);
  clone.x = Math.max(0, Math.min(clone.x || 100, BOARD_WIDTH - clone.w));
  clone.y = Math.max(0, Math.min(clone.y || 100, height - clone.h));
  const page = board.pages.find((entry) => entry.id === board.activePageId) || board.pages[0];
  clone.z = Math.max(0, ...page.widgets.map((widget) => widget.z || 1)) + 1;
  page.widgets.push(clone);
  return clone;
}

/** Einen empfangenen Stand (shares/<CODE>) auf die Tafel anwenden. */
async function applyPayload(board, entry, payload) {
  if (!payload) return;
  const keeper = bookkeeping(entry);
  const known = new Map(coupledWidgetsOf(board).map((widget) => [originIdOf(widget), widget]));
  let changed = false;

  // 1) Neue Auslosungs-/Klangfelder der teilenden Person übernehmen —
  //    auf der Kopie-Seite direkt aus deren Tafel-Stand.
  if (entry.coupled && payload.board) {
    const pages = Array.isArray(payload.board.pages) ? payload.board.pages : [];
    for (const page of pages) {
      for (const origin of page.widgets || []) {
        if (!COUPLE_TYPES.includes(origin.type)) continue;
        const key = origin.originId || origin.id;
        if (known.has(key) || keeper.dismissed.includes(key)) continue;
        const clone = adoptWidget(board, origin);
        known.set(key, clone);
        keeper.hashes[key] = stateHash(clone.state);
        await pullCoupleMedia(entry.code, clone.state);
        changed = true;
      }
    }
  }

  const records = payload.state && typeof payload.state === 'object' ? payload.state : {};

  // 2) Auch andersherum: Legt eine TEILNEHMENDE Person ein Auslosungs- oder
  //    Klangfeld an, kennt es hier noch niemand — die Stand-Datensätze tragen
  //    dafür Art und Maße mit, sodass jedes Gerät (auch der Besitzer) das
  //    Feld daraus übernehmen kann.
  for (const [key, record] of Object.entries(records)) {
    if (!record || typeof record !== 'object' || !record.state) continue;
    if (!COUPLE_TYPES.includes(record.type)) continue;
    if (known.has(key) || keeper.dismissed.includes(key)) continue;
    const clone = adoptWidget(board, {
      id: key,
      originId: key,
      type: record.type,
      x: Number.isFinite(record.x) ? record.x : 100,
      y: Number.isFinite(record.y) ? record.y : 100,
      w: Number.isFinite(record.w) ? record.w : 360,
      h: Number.isFinite(record.h) ? record.h : 260,
      z: 1,
      state: record.state,
    });
    known.set(key, clone);
    keeper.hashes[key] = stateHash(clone.state);
    keeper.stamps[key] = record.updatedAt || 0;
    await pullCoupleMedia(entry.code, clone.state);
    changed = true;
  }

  // 3) Stände zusammenführen — je Feld gewinnt der neuere.
  for (const [key, record] of Object.entries(records)) {
    if (!record || typeof record !== 'object' || !record.state) continue;
    const widget = known.get(key);
    if (!widget) continue;
    const stamp = keeper.stamps[key] || 0;
    if (!(record.updatedAt > stamp)) continue;
    const hash = stateHash(record.state);
    keeper.stamps[key] = record.updatedAt;
    if (hash === stateHash(widget.state)) continue;
    widget.state = JSON.parse(JSON.stringify(record.state));
    keeper.hashes[key] = hash;
    await pullCoupleMedia(entry.code, widget.state);
    changed = true;
  }

  if (changed) {
    saveNow();
    if (getActiveBoard() && getActiveBoard().id === board.id) {
      renderBoard();
      refreshAll();
    }
  }
}

/** Eigene Änderungen an gekoppelten Feldern hochladen. */
async function pushChanges() {
  // Neu entstandene Einträge (frisch erstellter Code, frisch geladene Kopie)
  // sollen sofort auch zuhören — nicht erst beim nächsten Tafelwechsel.
  syncSubscriptions();
  for (const { board, entry } of coupleEntries()) {
    const keeper = bookkeeping(entry);
    const widgets = coupledWidgetsOf(board);

    // Gelöschte Felder merken — auf jeder Seite, auch beim Besitzer: einmal
    // weg heißt weg, sonst käme das Feld mit dem nächsten Stand sofort zurück.
    const present = new Set(widgets.map((widget) => originIdOf(widget)));
    for (const key of Object.keys(keeper.hashes)) {
      if (!present.has(key) && !keeper.dismissed.includes(key)) {
        keeper.dismissed.push(key);
        delete keeper.hashes[key];
        delete keeper.stamps[key];
      }
    }

    for (const widget of widgets) {
      const key = originIdOf(widget);
      const hash = stateHash(widget.state);
      if (keeper.hashes[key] === hash) continue;
      const stamp = Date.now();
      try {
        await pushCoupleMedia(entry.code, keeper, widget.state);
        // Art und Maße wandern mit, damit andere Geräte (auch der Besitzer)
        // ein hier neu angelegtes Feld daraus übernehmen können.
        await putShareState(entry.code, key, {
          updatedAt: stamp,
          type: widget.type,
          x: widget.x,
          y: widget.y,
          w: widget.w,
          h: widget.h,
          state: JSON.parse(JSON.stringify(widget.state)),
        });
        keeper.hashes[key] = hash;
        keeper.stamps[key] = stamp;
      } catch (_) { /* ohne Netz beim nächsten Ändern erneut */ }
    }
  }
  saveNow();
}

const pushSoon = debounce(pushChanges, 1800);

/** Zuhörer je gekoppelter Tafel an- und abmelden. */
async function syncSubscriptions() {
  const wanted = new Map(coupleEntries().map(({ board, entry }) => [board.id, entry]));
  for (const [boardId, unsubscribe] of Array.from(subscriptions.entries())) {
    if (!wanted.has(boardId)) {
      unsubscribe();
      subscriptions.delete(boardId);
    }
  }
  for (const [boardId, entry] of wanted.entries()) {
    if (subscriptions.has(boardId)) continue;
    subscriptions.set(boardId, () => {});
    try {
      const unsubscribe = await subscribeShare(entry.code, (payload) => {
        if (!payload) return;
        const board = getState().boards.find((item) => item.id === boardId);
        const current = (getState().cloud.shares || {})[boardId];
        if (board && current && current.code === entry.code) {
          applyPayload(board, current, payload);
        }
      });
      subscriptions.set(boardId, unsubscribe);
    } catch (_) {
      subscriptions.delete(boardId);
    }
  }
}

/** Nach dem Laden einer Kopie sofort koppeln (statt auf die nächste Änderung zu warten). */
export function coupleNow() {
  syncSubscriptions();
  pushSoon();
}

export function initCoupling() {
  if (started) return;
  started = true;
  onStore('change', (payload) => {
    const reason = payload && payload.reason ? String(payload.reason) : '';
    // Nur inhaltliche Änderungen anstoßen — reine Ansichtswechsel nicht.
    if (/^widget-|^board-import|^page-|^transfer|^update$/.test(reason)) pushSoon();
    if (/board-import|board-add|board-remove/.test(reason)) syncSubscriptions();
  });
  onStore('board-switch', () => syncSubscriptions());
  syncSubscriptions();
}
