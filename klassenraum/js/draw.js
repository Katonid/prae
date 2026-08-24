// Schreiben und Markieren auf der Tafel — mit Stift (Apple Pencil), Finger oder Maus.
// Die Striche gehören zum Klassenraum, werden mitgespeichert und mitgeteilt.

import { h, clear, uid, onTap } from './util.js';
import { icon } from './icons.js';
import { BOARD_WIDTH, BOARD_HEIGHT, getActiveBoard, touch, on as onStore } from './store.js';
import { confirmDialog } from './ui.js';

const COLORS = ['#f8fafc', '#0f172a', '#ef4444', '#f59e0b', '#22c55e', '#38bdf8', '#a855f7'];
const WIDTHS = [3, 6, 12];
const ERASER_RADIUS = 14;

let canvas = null;
let ctx2d = null;
let toolbar = null;
let active = false;
let tool = 'pen';
let color = '#f8fafc';
let width = 6;
let penOnly = false;
let drawingStroke = null;
let onChange = () => {};

export function isDrawActive() {
  return active;
}

export function initDrawing(host, options = {}) {
  onChange = options.onChange || (() => {});
  canvas = document.createElement('canvas');
  canvas.className = 'draw-layer';
  canvas.width = BOARD_WIDTH;
  canvas.height = BOARD_HEIGHT;
  canvas.style.width = `${BOARD_WIDTH}px`;
  canvas.style.height = `${BOARD_HEIGHT}px`;
  ctx2d = canvas.getContext('2d');
  host.appendChild(canvas);

  canvas.addEventListener('pointerdown', onPointerDown);
  canvas.addEventListener('pointermove', onPointerMove);
  canvas.addEventListener('pointerup', onPointerUp);
  canvas.addEventListener('pointercancel', onPointerUp);
  canvas.addEventListener('pointerleave', onPointerUp);

  onStore('board-switch', () => redraw());
  redraw();
  return canvas;
}

function strokes() {
  const board = getActiveBoard();
  if (!board) return [];
  if (!Array.isArray(board.drawing)) board.drawing = [];
  return board.drawing;
}

export function redraw() {
  if (!ctx2d) return;
  ctx2d.clearRect(0, 0, BOARD_WIDTH, BOARD_HEIGHT);
  for (const stroke of strokes()) paint(stroke);
}

function paint(stroke) {
  const points = stroke.points || [];
  if (!points.length) return;
  ctx2d.save();
  ctx2d.lineCap = 'round';
  ctx2d.lineJoin = 'round';
  ctx2d.strokeStyle = stroke.color;
  ctx2d.globalAlpha = stroke.tool === 'marker' ? 0.34 : 1;
  ctx2d.lineWidth = stroke.width * (stroke.tool === 'marker' ? 3.4 : 1);

  if (points.length === 1) {
    ctx2d.beginPath();
    ctx2d.arc(points[0][0], points[0][1], ctx2d.lineWidth / 2, 0, Math.PI * 2);
    ctx2d.fillStyle = stroke.color;
    ctx2d.fill();
    ctx2d.restore();
    return;
  }

  ctx2d.beginPath();
  ctx2d.moveTo(points[0][0], points[0][1]);
  for (let i = 1; i < points.length - 1; i += 1) {
    const midX = (points[i][0] + points[i + 1][0]) / 2;
    const midY = (points[i][1] + points[i + 1][1]) / 2;
    ctx2d.quadraticCurveTo(points[i][0], points[i][1], midX, midY);
  }
  const last = points[points.length - 1];
  ctx2d.lineTo(last[0], last[1]);
  ctx2d.stroke();
  ctx2d.restore();
}

function toBoard(event) {
  const rect = canvas.getBoundingClientRect();
  const scaleX = rect.width / BOARD_WIDTH;
  const scaleY = rect.height / BOARD_HEIGHT;
  return [(event.clientX - rect.left) / scaleX, (event.clientY - rect.top) / scaleY];
}

function eraseAt(point) {
  const list = strokes();
  let removed = false;
  for (let i = list.length - 1; i >= 0; i -= 1) {
    const stroke = list[i];
    const radius = ERASER_RADIUS + (stroke.width || 4);
    const hit = (stroke.points || []).some(([x, y]) =>
      Math.abs(x - point[0]) < radius && Math.abs(y - point[1]) < radius);
    if (hit) {
      list.splice(i, 1);
      removed = true;
    }
  }
  if (removed) {
    redraw();
    touch({ reason: 'draw-erase' });
  }
}

function onPointerDown(event) {
  if (!active) return;
  if (penOnly && event.pointerType !== 'pen') return;
  canvas.setPointerCapture(event.pointerId);
  event.preventDefault();
  const point = toBoard(event);

  if (tool === 'eraser') {
    drawingStroke = { erasing: true };
    eraseAt(point);
    return;
  }

  drawingStroke = {
    id: uid('s'),
    tool,
    color,
    width: event.pointerType === 'pen' && event.pressure ? width * (0.55 + event.pressure) : width,
    points: [point],
  };
  strokes().push(drawingStroke);
  paint(drawingStroke);
}

function onPointerMove(event) {
  if (!active || !drawingStroke) return;
  const point = toBoard(event);
  if (drawingStroke.erasing) {
    eraseAt(point);
    return;
  }
  const points = drawingStroke.points;
  const previous = points[points.length - 1];
  if (Math.abs(point[0] - previous[0]) + Math.abs(point[1] - previous[1]) < 1.2) return;
  points.push(point);
  // Nur das neue Stück zeichnen — das bleibt auch bei langen Linien flüssig.
  ctx2d.save();
  ctx2d.lineCap = 'round';
  ctx2d.lineJoin = 'round';
  ctx2d.strokeStyle = drawingStroke.color;
  ctx2d.globalAlpha = drawingStroke.tool === 'marker' ? 0.34 : 1;
  ctx2d.lineWidth = drawingStroke.width * (drawingStroke.tool === 'marker' ? 3.4 : 1);
  ctx2d.beginPath();
  ctx2d.moveTo(previous[0], previous[1]);
  ctx2d.lineTo(point[0], point[1]);
  ctx2d.stroke();
  ctx2d.restore();
}

function onPointerUp() {
  if (!drawingStroke) return;
  const wasErasing = drawingStroke.erasing;
  drawingStroke = null;
  if (!wasErasing) {
    redraw();
    touch({ reason: 'draw' });
  }
  onChange();
}

export function undoStroke() {
  const list = strokes();
  if (!list.length) return;
  list.pop();
  redraw();
  touch({ reason: 'draw-undo' });
  updateToolbar();
}

export async function clearDrawing({ ask = true } = {}) {
  const list = strokes();
  if (!list.length) return;
  if (ask) {
    const ok = await confirmDialog('Alles löschen?', 'Alle Striche auf dieser Tafel werden entfernt.', 'Löschen');
    if (!ok) return;
  }
  list.length = 0;
  redraw();
  touch({ reason: 'draw-clear' });
  updateToolbar();
}

export function setDrawActive(value) {
  active = Boolean(value);
  document.body.classList.toggle('is-drawing', active);
  if (canvas) canvas.classList.toggle('is-active', active);
  if (active) buildToolbar();
  else if (toolbar) {
    toolbar.remove();
    toolbar = null;
  }
  onChange();
}

function updateToolbar() {
  if (!toolbar) return;
  const buttons = toolbar.querySelectorAll('[data-tool]');
  buttons.forEach((element) => element.classList.toggle('is-active', element.dataset.tool === tool));
  toolbar.querySelectorAll('[data-color]').forEach((element) => {
    element.classList.toggle('is-active', element.dataset.color === color);
  });
  toolbar.querySelectorAll('[data-width]').forEach((element) => {
    element.classList.toggle('is-active', Number(element.dataset.width) === width);
  });
  const undo = toolbar.querySelector('[data-action="undo"]');
  if (undo) undo.disabled = strokes().length === 0;
}

function buildToolbar() {
  if (toolbar) toolbar.remove();
  toolbar = h('div', { class: 'draw-toolbar', 'data-nodrag': '' });

  const tools = [
    { id: 'pen', label: 'Stift', iconName: 'pen' },
    { id: 'marker', label: 'Marker', iconName: 'marker' },
    { id: 'eraser', label: 'Radierer', iconName: 'eraser' },
  ];

  const toolGroup = h('div', { class: 'draw-toolbar__group' }, tools.map((entry) => onTap(h('button', {
    class: 'draw-tool' + (tool === entry.id ? ' is-active' : ''),
    'data-tool': entry.id,
    title: entry.label,
    html: icon(entry.iconName, 20),
  }), () => {
    tool = entry.id;
    updateToolbar();
  })));

  const colorGroup = h('div', { class: 'draw-toolbar__group' }, COLORS.map((entry) => onTap(h('button', {
    class: 'draw-color' + (color === entry ? ' is-active' : ''),
    'data-color': entry,
    style: { background: entry },
    title: 'Farbe',
  }), () => {
    color = entry;
    if (tool === 'eraser') tool = 'pen';
    updateToolbar();
  })));

  const widthGroup = h('div', { class: 'draw-toolbar__group' }, WIDTHS.map((entry) => onTap(h('button', {
    class: 'draw-width' + (width === entry ? ' is-active' : ''),
    'data-width': entry,
    title: `Strichstärke ${entry}`,
  }, h('span', { style: { width: `${entry + 4}px`, height: `${entry + 4}px` } })), () => {
    width = entry;
    if (tool === 'eraser') tool = 'pen';
    updateToolbar();
  })));

  const actions = h('div', { class: 'draw-toolbar__group' },
    onTap(h('button', { class: 'draw-tool', 'data-action': 'undo', title: 'Letzten Strich zurücknehmen', html: icon('undo', 20) }), undoStroke),
    onTap(h('button', { class: 'draw-tool', title: 'Alles löschen', html: icon('trash', 20) }), () => clearDrawing()),
    onTap(h('button', { class: 'draw-tool draw-tool--pen-only' + (penOnly ? ' is-active' : ''), title: 'Nur mit Stift schreiben (Handballen-Schutz)' },
      h('span', { html: icon('pen', 18) }), h('small', null, 'nur Stift')), (event) => {
      penOnly = !penOnly;
      event.currentTarget.classList.toggle('is-active', penOnly);
    }));

  toolbar.append(toolGroup, colorGroup, widthGroup, actions);
  document.body.appendChild(toolbar);
  updateToolbar();
}
