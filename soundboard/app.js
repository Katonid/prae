/* Theater-Soundboard */
'use strict';

const PAD_COUNT = 16;
const LONG_PRESS_MS = 500;
const DB_NAME = 'theater-soundboard';
const DB_VERSION = 1;
const STORE = 'pads';

const DEFAULT_COLORS = [
  '#e63946', '#f4845f', '#f7b32b', '#8ac926',
  '#2a9d8f', '#4cc9f0', '#4361ee', '#7209b7',
  '#f72585', '#ff6b6b', '#ffd166', '#06d6a0',
  '#118ab2', '#9b5de5', '#ef476f', '#83c5be'
];

const SWATCH_COLORS = [
  '#e63946', '#f4845f', '#f7b32b', '#ffd166',
  '#8ac926', '#06d6a0', '#2a9d8f', '#83c5be',
  '#4cc9f0', '#118ab2', '#4361ee', '#7209b7',
  '#9b5de5', '#f72585', '#ef476f', '#6c757d'
];

let db = null;
let editMode = false;
let editIndex = -1;
const pads = [];

/* ---------- IndexedDB ---------- */

function openDb() {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, DB_VERSION);
    req.onupgradeneeded = () => {
      req.result.createObjectStore(STORE, { keyPath: 'id' });
    };
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

function dbGetAll() {
  return new Promise((resolve, reject) => {
    const req = db.transaction(STORE, 'readonly').objectStore(STORE).getAll();
    req.onsuccess = () => resolve(req.result || []);
    req.onerror = () => reject(req.error);
  });
}

function dbPut(record) {
  return new Promise((resolve, reject) => {
    const tx = db.transaction(STORE, 'readwrite');
    tx.objectStore(STORE).put(record);
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
  });
}

function savePad(i) {
  const p = pads[i];
  return dbPut({
    id: i,
    label: p.label,
    color: p.color,
    fileName: p.fileName,
    fileType: p.fileType,
    blob: p.blob
  }).catch((err) => {
    console.error('Speichern fehlgeschlagen', err);
    showToast('Speichern fehlgeschlagen – möglicherweise ist der Speicher voll.');
  });
}

/* ---------- Hilfsfunktionen ---------- */

function hexToRgba(hex, alpha) {
  const h = hex.replace('#', '');
  const r = parseInt(h.substring(0, 2), 16);
  const g = parseInt(h.substring(2, 4), 16);
  const b = parseInt(h.substring(4, 6), 16);
  return 'rgba(' + r + ', ' + g + ', ' + b + ', ' + alpha + ')';
}

function fmtTime(sec) {
  if (!isFinite(sec) || sec < 0) sec = 0;
  const m = Math.floor(sec / 60);
  const s = Math.floor(sec % 60);
  return m + ':' + String(s).padStart(2, '0');
}

let toastTimer = null;
function showToast(msg) {
  const el = document.getElementById('toast');
  el.textContent = msg;
  el.hidden = false;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => { el.hidden = true; }, 2600);
}

/* ---------- Audio ---------- */

function loadAudio(i) {
  const p = pads[i];
  if (p.url) {
    URL.revokeObjectURL(p.url);
    p.url = null;
  }
  if (p.audio) {
    p.audio.pause();
    p.audio.src = '';
    p.audio = null;
  }
  p.duration = 0;
  if (!p.blob) return;

  p.url = URL.createObjectURL(p.blob);
  const audio = new Audio();
  audio.preload = 'auto';
  audio.src = p.url;
  audio.addEventListener('loadedmetadata', () => {
    p.duration = audio.duration;
    updatePadUI(i);
  });
  audio.addEventListener('ended', () => {
    audio.currentTime = 0;
    updatePadUI(i);
  });
  p.audio = audio;
}

function togglePad(i) {
  const p = pads[i];
  if (!p.audio) {
    showToast('Dieses Feld ist leer – über „Bearbeiten“ eine Tondatei zuweisen.');
    return;
  }
  if (p.audio.paused) {
    p.audio.play().catch((err) => {
      console.error('Abspielen fehlgeschlagen', err);
      showToast('Abspielen fehlgeschlagen: ' + (p.fileName || ''));
    });
  } else {
    p.audio.pause();
  }
  updatePadUI(i);
}

function resetPad(i, withFlash) {
  const p = pads[i];
  if (!p.audio) return;
  p.audio.pause();
  try { p.audio.currentTime = 0; } catch (e) { /* noch nicht geladen */ }
  if (withFlash) {
    p.el.classList.remove('flash');
    void p.el.offsetWidth; /* Animation neu starten */
    p.el.classList.add('flash');
  }
  updatePadUI(i);
}

function resetAll() {
  for (let i = 0; i < PAD_COUNT; i++) resetPad(i, false);
  showToast('Alle Tondateien auf Anfang gesetzt.');
}

/* ---------- Matrix / UI ---------- */

function createPadElement(i) {
  const el = document.createElement('button');
  el.type = 'button';
  el.className = 'pad';
  el.innerHTML =
    '<span class="pad-label"></span>' +
    '<span class="pad-status"><span class="pad-icon"></span><span class="pad-time"></span></span>' +
    '<span class="pad-progress"><span class="pad-progress-fill"></span></span>' +
    '<span class="pad-edit-badge">✎</span>';

  let pressTimer = null;
  let longFired = false;
  let activePointer = null;

  el.addEventListener('pointerdown', (e) => {
    if (editMode) return;
    activePointer = e.pointerId;
    longFired = false;
    clearTimeout(pressTimer);
    pressTimer = setTimeout(() => {
      longFired = true;
      resetPad(i, true);
    }, LONG_PRESS_MS);
  });

  el.addEventListener('pointerup', (e) => {
    if (editMode) return;
    if (e.pointerId !== activePointer) return;
    clearTimeout(pressTimer);
    activePointer = null;
    if (!longFired) togglePad(i);
  });

  const cancelPress = () => {
    clearTimeout(pressTimer);
    activePointer = null;
  };
  el.addEventListener('pointercancel', cancelPress);
  el.addEventListener('pointerleave', (e) => {
    if (e.pointerId === activePointer) cancelPress();
  });

  el.addEventListener('click', () => {
    if (editMode) openEditor(i);
  });

  el.addEventListener('contextmenu', (e) => e.preventDefault());
  return el;
}

function updatePadUI(i) {
  const p = pads[i];
  const el = p.el;
  el.style.setProperty('--pad-color', p.color);
  el.style.setProperty('--pad-bg', hexToRgba(p.color, 0.25));

  const hasFile = !!p.audio;
  el.classList.toggle('empty', !hasFile);

  const labelEl = el.querySelector('.pad-label');
  labelEl.textContent = p.label || (hasFile ? p.fileName : 'leer');

  const iconEl = el.querySelector('.pad-icon');
  const timeEl = el.querySelector('.pad-time');
  const fillEl = el.querySelector('.pad-progress-fill');

  if (!hasFile) {
    el.classList.remove('playing');
    iconEl.textContent = '';
    timeEl.textContent = editMode ? 'antippen zum Belegen' : '';
    fillEl.style.width = '0';
    return;
  }

  const playing = !p.audio.paused;
  const cur = p.audio.currentTime || 0;
  const dur = p.duration || p.audio.duration || 0;
  el.classList.toggle('playing', playing);

  if (playing) {
    iconEl.textContent = '▶';
  } else if (cur > 0.05) {
    iconEl.textContent = '⏸';
  } else {
    iconEl.textContent = '▶';
  }

  timeEl.textContent = dur > 0 ? fmtTime(cur) + ' / ' + fmtTime(dur) : fmtTime(cur);
  fillEl.style.width = dur > 0 ? (100 * cur / dur) + '%' : '0';
}

function updateAllPadsUI() {
  for (let i = 0; i < PAD_COUNT; i++) updatePadUI(i);
}

/* ---------- Bearbeiten-Modus ---------- */

const editDialog = document.getElementById('editDialog');
const editLabel = document.getElementById('editLabel');
const editColor = document.getElementById('editColor');
const editFileInfo = document.getElementById('editFileInfo');
const filePicker = document.getElementById('filePicker');
const swatchesEl = document.getElementById('swatches');

function buildSwatches() {
  SWATCH_COLORS.forEach((color) => {
    const b = document.createElement('button');
    b.type = 'button';
    b.className = 'swatch';
    b.style.background = color;
    b.dataset.color = color;
    b.setAttribute('aria-label', 'Farbe ' + color);
    b.addEventListener('click', () => setEditColor(color));
    swatchesEl.appendChild(b);
  });
}

function setEditColor(color) {
  if (editIndex < 0) return;
  pads[editIndex].color = color;
  editColor.value = color;
  markSelectedSwatch(color);
  updatePadUI(editIndex);
  savePad(editIndex);
}

function markSelectedSwatch(color) {
  swatchesEl.querySelectorAll('.swatch').forEach((s) => {
    s.classList.toggle('selected', s.dataset.color.toLowerCase() === color.toLowerCase());
  });
}

function updateEditFileInfo() {
  const p = pads[editIndex];
  if (p && p.blob) {
    const dur = p.duration ? ' (' + fmtTime(p.duration) + ')' : '';
    editFileInfo.textContent = p.fileName + dur;
  } else {
    editFileInfo.textContent = 'keine Datei';
  }
}

function openEditor(i) {
  editIndex = i;
  const p = pads[i];
  document.getElementById('editTitle').textContent = 'Feld ' + (i + 1) + ' bearbeiten';
  editLabel.value = p.label;
  editColor.value = p.color;
  markSelectedSwatch(p.color);
  updateEditFileInfo();
  editDialog.showModal();
}

function toggleEditMode() {
  editMode = !editMode;
  document.body.classList.toggle('edit-mode', editMode);
  const btn = document.getElementById('editBtn');
  btn.classList.toggle('active', editMode);
  btn.textContent = editMode ? '✓  Fertig' : '✎  Bearbeiten';
  if (editMode) {
    showToast('Feld antippen, um Beschriftung, Farbe und Tondatei zu ändern.');
  }
  updateAllPadsUI();
}

/* ---------- Initialisierung ---------- */

async function init() {
  const grid = document.getElementById('grid');

  for (let i = 0; i < PAD_COUNT; i++) {
    const el = createPadElement(i);
    grid.appendChild(el);
    pads.push({
      id: i,
      label: '',
      color: DEFAULT_COLORS[i],
      fileName: '',
      fileType: '',
      blob: null,
      audio: null,
      url: null,
      duration: 0,
      el: el
    });
  }

  try {
    db = await openDb();
    const records = await dbGetAll();
    records.forEach((r) => {
      if (r.id < 0 || r.id >= PAD_COUNT) return;
      const p = pads[r.id];
      p.label = r.label || '';
      p.color = r.color || DEFAULT_COLORS[r.id];
      p.fileName = r.fileName || '';
      p.fileType = r.fileType || '';
      p.blob = r.blob || null;
      loadAudio(r.id);
    });
  } catch (err) {
    console.error('Datenbank konnte nicht geöffnet werden', err);
    showToast('Gespeicherte Daten konnten nicht geladen werden.');
  }

  updateAllPadsUI();
  buildSwatches();

  document.getElementById('resetAllBtn').addEventListener('click', resetAll);
  document.getElementById('editBtn').addEventListener('click', toggleEditMode);

  editLabel.addEventListener('input', () => {
    if (editIndex < 0) return;
    pads[editIndex].label = editLabel.value;
    updatePadUI(editIndex);
  });
  editLabel.addEventListener('change', () => {
    if (editIndex >= 0) savePad(editIndex);
  });

  editColor.addEventListener('input', () => setEditColor(editColor.value));

  document.getElementById('pickFileBtn').addEventListener('click', () => filePicker.click());

  filePicker.addEventListener('change', () => {
    const file = filePicker.files && filePicker.files[0];
    filePicker.value = '';
    if (!file || editIndex < 0) return;
    const p = pads[editIndex];
    p.blob = file;
    p.fileName = file.name;
    p.fileType = file.type || '';
    if (!p.label) {
      p.label = file.name.replace(/\.[^.]+$/, '');
      editLabel.value = p.label;
    }
    loadAudio(editIndex);
    updatePadUI(editIndex);
    updateEditFileInfo();
    savePad(editIndex);
  });

  document.getElementById('removeFileBtn').addEventListener('click', () => {
    if (editIndex < 0) return;
    const p = pads[editIndex];
    p.blob = null;
    p.fileName = '';
    p.fileType = '';
    loadAudio(editIndex);
    updatePadUI(editIndex);
    updateEditFileInfo();
    savePad(editIndex);
  });

  document.getElementById('closeEditBtn').addEventListener('click', () => {
    if (editIndex >= 0) savePad(editIndex);
    editDialog.close();
  });
  editDialog.addEventListener('close', () => {
    if (editIndex >= 0) savePad(editIndex);
    editIndex = -1;
  });

  /* Laufende Anzeige (Zeit / Fortschritt) */
  setInterval(() => {
    for (let i = 0; i < PAD_COUNT; i++) {
      const p = pads[i];
      if (p.audio && (!p.audio.paused || p.audio.currentTime > 0)) updatePadUI(i);
    }
  }, 200);

  /* Speicher dauerhaft anfordern (verhindert, dass iOS/Android die Daten löscht) */
  if (navigator.storage && navigator.storage.persist) {
    navigator.storage.persist().catch(() => {});
  }

  /* Bildschirm während der Aufführung wach halten */
  setupWakeLock();

  /* Service Worker für Offline-Betrieb */
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('./sw.js').catch((err) => {
      console.warn('Service Worker konnte nicht registriert werden', err);
    });
  }
}

/* ---------- Wake Lock ---------- */

let wakeLock = null;

async function requestWakeLock() {
  if (!('wakeLock' in navigator)) return;
  try {
    wakeLock = await navigator.wakeLock.request('screen');
  } catch (e) { /* z. B. Energiesparmodus – ignorieren */ }
}

function setupWakeLock() {
  window.addEventListener('pointerdown', requestWakeLock, { once: true });
  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'visible') requestWakeLock();
  });
}

init();
