// Elemente und Seiten in einen anderen Klassenraum übertragen.
//
// Was hängt woran? Namenslisten gelten für alle Klassenräume — Verweise
// bleiben beim Übertragen automatisch gültig. Klang- und Videodateien liegen
// einmal im Gerät und werden über Kennungen verknüpft: Beim VERSCHIEBEN
// wandert der Verweis einfach mit; beim KOPIEREN wird die Datei unter neuer
// Kennung mitkopiert, damit Original und Kopie nicht an derselben Datei
// hängen. Der Abgleich nimmt die neuen Dateien wie gewohnt mit.

import { uid } from './util.js';
import {
  getState, getActiveBoard, getActivePage, boardHeight, BOARD_WIDTH,
  emptyPage, touch, touchBoard,
} from './store.js';
import { duplicateMedia } from './media.js';

function targetOf(boardId) {
  return getState().boards.find((board) => board.id === boardId) || null;
}

async function cloneWidget(widget, { copyMedia }) {
  const copy = JSON.parse(JSON.stringify(widget));
  copy.id = uid('w');
  const state = copy.state || {};
  if (copyMedia) {
    if (state.mediaId) state.mediaId = (await duplicateMedia(state.mediaId)) || state.mediaId;
    for (const entry of Array.isArray(state.entries) ? state.entries : []) {
      if (entry.mediaId) entry.mediaId = (await duplicateMedia(entry.mediaId)) || entry.mediaId;
    }
  }
  return copy;
}

/** In ein kleineres Tafel-Format darf nichts über den Rand ragen. */
function clampToBoard(widget, board) {
  const height = boardHeight(board);
  widget.w = Math.min(widget.w, BOARD_WIDTH);
  widget.h = Math.min(widget.h, height);
  widget.x = Math.max(0, Math.min(widget.x, BOARD_WIDTH - widget.w));
  widget.y = Math.max(0, Math.min(widget.y, height - widget.h));
}

/**
 * Ein Element übertragen — in einen anderen Klassenraum oder (mit
 * `targetPageId`) auf eine andere Seite, auch desselben Klassenraums.
 * Ohne `targetPageId` landet es auf der dort aufgeschlagenen Seite.
 */
export async function transferWidget(widgetId, targetBoardId, { move = false, targetPageId = null } = {}) {
  const source = getActiveBoard();
  const target = targetOf(targetBoardId);
  if (!source || !target) return false;
  const page = (source.pages || []).find((entry) => (entry.widgets || []).some((w) => w.id === widgetId));
  const widget = page && page.widgets.find((w) => w.id === widgetId);
  if (!widget) return false;
  const targetPage = (target.pages || []).find((entry) => entry.id === targetPageId) || getActivePage(target);
  if (!targetPage || (target.id === source.id && targetPage.id === page.id)) return false;
  const copy = await cloneWidget(widget, { copyMedia: !move });
  // Eine KOPIE löst sich von der Kopplung (Herkunfts-Kennung) — sonst hingen
  // zwei Elemente an demselben gekoppelten Stand. Beim Verschieben wandert
  // die Kennung mit, es bleibt ja dasselbe Element.
  if (!move) delete copy.originId;
  clampToBoard(copy, target);
  copy.z = Math.max(0, ...targetPage.widgets.map((w) => w.z || 1)) + 1;
  targetPage.widgets.push(copy);
  if (move) page.widgets = page.widgets.filter((w) => w.id !== widgetId);
  touchBoard(target.id, { reason: 'transfer' });
  touch({ reason: move ? 'widget-remove' : 'transfer' });
  return true;
}

/* ---------- Zwischenablage (aus der Tafelbild-App) ---------- */

/**
 * Ein Element merken. Liegt in den Geräte-Einstellungen (übersteht den
 * Neustart, wandert nicht in den Abgleich) — auf jeder Seite und jeder Tafel
 * steht danach vorn in der Elementleiste „Einfügen".
 */
export function copyWidgetToClipboard(widgetId) {
  const board = getActiveBoard();
  const page = board && (board.pages || []).find((entry) => (entry.widgets || []).some((w) => w.id === widgetId));
  const widget = page && page.widgets.find((w) => w.id === widgetId);
  if (!widget) return false;
  const data = JSON.parse(JSON.stringify(widget));
  delete data.id;
  // Die Kopie löst sich von der Kopplung — sonst hingen zwei Elemente
  // an demselben gekoppelten Stand.
  delete data.originId;
  getState().settings.clipboard = { at: Date.now(), widget: data };
  touch({ board: false, reason: 'clipboard' });
  return true;
}

/** Der gemerkte Inhalt der Zwischenablage — oder null. */
export function clipboardWidget() {
  const clip = getState().settings.clipboard;
  return clip && clip.widget && clip.widget.type ? clip : null;
}

/** Das gemerkte Element auf der aufgeschlagenen Seite einfügen. */
export async function pasteWidgetFromClipboard() {
  const clip = clipboardWidget();
  const board = getActiveBoard();
  const page = getActivePage(board);
  if (!clip || !board || !page) return null;
  const copy = await cloneWidget(clip.widget, { copyMedia: true });
  // Leicht versetzt, damit mehrmaliges Einfügen nicht deckungsgleich stapelt.
  const cascade = (page.widgets || []).length % 6;
  copy.x = (Number(copy.x) || 100) + cascade * 26;
  copy.y = (Number(copy.y) || 100) + cascade * 20;
  clampToBoard(copy, board);
  copy.z = Math.max(0, ...page.widgets.map((w) => w.z || 1)) + 1;
  page.widgets.push(copy);
  touch({ reason: 'widget-add' });
  return copy;
}

/** Eine ganze Seite (Elemente + Zeichnungen) in einen anderen Klassenraum übertragen. */
export async function transferPage(pageId, targetBoardId, { move = false } = {}) {
  const source = getActiveBoard();
  const target = targetOf(targetBoardId);
  if (!source || !target || source.id === target.id) return false;
  const index = (source.pages || []).findIndex((entry) => entry.id === pageId);
  if (index < 0) return false;
  const page = source.pages[index];
  const copy = {
    id: uid('page'),
    name: page.name || '',
    widgets: [],
    drawing: JSON.parse(JSON.stringify(page.drawing || [])),
  };
  for (const widget of page.widgets || []) {
    const clone = await cloneWidget(widget, { copyMedia: !move });
    clampToBoard(clone, target);
    copy.widgets.push(clone);
  }
  target.pages.push(copy);
  if (move) {
    source.pages.splice(index, 1);
    // Die letzte Seite einer Tafel bleibt immer bestehen — notfalls leer.
    if (!source.pages.length) source.pages.push(emptyPage());
    if (!source.pages.some((entry) => entry.id === source.activePageId)) {
      source.activePageId = source.pages[Math.max(0, index - 1)].id;
    }
  }
  touchBoard(target.id, { reason: 'transfer' });
  touch({ reason: move ? 'page-remove' : 'transfer' });
  return true;
}
