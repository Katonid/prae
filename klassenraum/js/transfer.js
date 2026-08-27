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

/** Ein Element auf die aufgeschlagene Seite eines anderen Klassenraums übertragen. */
export async function transferWidget(widgetId, targetBoardId, { move = false } = {}) {
  const source = getActiveBoard();
  const target = targetOf(targetBoardId);
  if (!source || !target || source.id === target.id) return false;
  const page = (source.pages || []).find((entry) => (entry.widgets || []).some((w) => w.id === widgetId));
  const widget = page && page.widgets.find((w) => w.id === widgetId);
  if (!widget) return false;
  const copy = await cloneWidget(widget, { copyMedia: !move });
  clampToBoard(copy, target);
  const targetPage = getActivePage(target);
  copy.z = Math.max(0, ...targetPage.widgets.map((w) => w.z || 1)) + 1;
  targetPage.widgets.push(copy);
  if (move) page.widgets = page.widgets.filter((w) => w.id !== widgetId);
  touchBoard(target.id, { reason: 'transfer' });
  touch({ reason: move ? 'widget-remove' : 'transfer' });
  return true;
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
