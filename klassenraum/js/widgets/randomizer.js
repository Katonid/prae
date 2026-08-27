// Zufälliger Name — Kernfunktion: Namen ziehen, mit/ohne Zurücklegen,
// gezogene Namen sehen, zurücklegen oder von Hand als gezogen markieren.
// Der gezogene Name kann schrittweise aufgedeckt werden, damit die Klasse raten kann.

import { h, clear, pickRandom, parseNames, beep, onTap, confetti, reducedMotion, randomInt } from '../util.js';
import { icon } from '../icons.js';
import { getState, getList, on as onStore, addList } from '../store.js';
import { section, field, toggleRow, button, buttonRow, toast } from '../ui.js';
import { SPIN_SOUNDS, spinSoundById, spinTick, spinEnd, previewSpinSound } from '../sfx.js';

// Feines Raster: viele kleine Kacheln geben pro Tipp wenig preis.
const MOSAIC_COLS = 28;
const MOSAIC_ROWS = 10;
const MOSAIC_TILES = MOSAIC_COLS * MOSAIC_ROWS;
const MOSAIC_STEPS = 12;
const MOSAIC_PER_TAP = Math.ceil(MOSAIC_TILES / MOSAIC_STEPS);
const BLUR_STEPS = 10;

// Das Auslosen läuft wie ein Glücksrad aus: erst schnell, dann immer langsamer.
const SPIN_STEPS = 18;
const SPIN_FAST = 45;
const SPIN_SLOW = 210;

function spinDelay(step) {
  const progress = step / (SPIN_STEPS - 1);
  return SPIN_FAST + Math.pow(progress, 2.4) * (SPIN_SLOW - SPIN_FAST);
}

const REVEAL_MODES = [
  { id: 'instant', label: 'Sofort', hint: 'Der Name steht sofort da.' },
  { id: 'mosaik', label: 'Mosaik', hint: 'Feine Kacheln verschwinden nach und nach — zwölf Tipps bis zum ganzen Namen.' },
  { id: 'blur', label: 'Unschärfe', hint: 'Erst nur ein Farbnebel, mit jedem Tipp schärfer — zehn Tipps.' },
  { id: 'letters', label: 'Buchstaben', hint: 'Ein Buchstabe nach dem anderen erscheint.' },
];

// Alle Auswahlmodi — die Anzeigenamen lassen sich in den Einstellungen ändern.
const MODES = [
  { id: 'exhaust', label: 'Ohne Zurücklegen' },
  { id: 'repeat', label: 'Mit Zurücklegen' },
  { id: 'gruppen', label: 'Gruppen' },
  { id: 'tagesgruppe', label: 'Tagesgruppe' },
];

const HISTORY_MAX = 60;

function modeLabel(state, id) {
  const custom = state.modeNames && typeof state.modeNames === 'object' ? state.modeNames[id] : '';
  const fallback = (MODES.find((entry) => entry.id === id) || MODES[0]).label;
  return (custom || '').trim() || fallback;
}

function isGroupMode(state) {
  return state.mode === 'gruppen' || state.mode === 'tagesgruppe';
}

function marksOf(state) {
  if (state.listId) {
    const list = getList(state.listId);
    if (list && list.marks && typeof list.marks === 'object') return list.marks;
  }
  return {};
}

function groupSizeOf(state) {
  const raw = Number(state.groupSize) || 2;
  return Math.max(1, Math.min(15, Math.round(raw)));
}

function dayCountOf(state) {
  const raw = Number(state.dayCount) || 3;
  return Math.max(1, Math.min(30, Math.round(raw)));
}

/** Merkmal-Vorgabe fürs Gruppen-Auslosen: 'mix', 'gleich' oder 'egal'. */
function markModeOf(state) {
  if (['mix', 'gleich', 'egal'].includes(state.markMode)) return state.markMode;
  // Älterer Stand: Schalter „Merkmale mischen" (an/aus).
  return state.mixMarks === false ? 'egal' : 'mix';
}

function shuffled(list) {
  const copy = list.slice();
  for (let i = copy.length - 1; i > 0; i -= 1) {
    const j = randomInt(i + 1);
    [copy[i], copy[j]] = [copy[j], copy[i]];
  }
  return copy;
}

function chunk(list, size) {
  const groups = [];
  for (let i = 0; i < list.length; i += size) groups.push(list.slice(i, i + size));
  return groups;
}

function pairKey(a, b) {
  return a < b ? `${a}|${b}` : `${b}|${a}`;
}

/** Wie oft standen zwei Namen in der Vergangenheit schon zusammen in einer Gruppe? */
function pastPairCounts(history) {
  const counts = new Map();
  for (const entry of history || []) {
    if (entry.mode !== 'gruppen') continue;
    for (const group of chunk(entry.flat || [], entry.size || 2)) {
      for (let i = 0; i < group.length; i += 1) {
        for (let j = i + 1; j < group.length; j += 1) {
          const key = pairKey(group[i], group[j]);
          counts.set(key, (counts.get(key) || 0) + 1);
        }
      }
    }
  }
  return counts;
}

/**
 * Einen Anordnungsversuch bauen: Ab `prefix` (bereits feststehende Namen)
 * werden die restlichen Namen so verteilt, dass jede Gruppe möglichst
 * verschiedene Merkmale mischt (z. B. ein Junge und ein Mädchen).
 */
function arrangeOnce(pool, marks, size, prefix, mode) {
  const buckets = new Map();
  for (const name of shuffled(pool)) {
    const mark = marks[name] || '';
    if (!buckets.has(mark)) buckets.set(mark, []);
    buckets.get(mark).push(name);
  }
  const flat = prefix.slice();
  const total = prefix.length + pool.length;
  while (flat.length < total) {
    const posInGroup = flat.length % size;
    const groupStart = flat.length - posInGroup;
    const groupMarks = new Set(flat.slice(groupStart).map((name) => marks[name] || ''));
    const filled = Array.from(buckets.values()).filter((list) => list.length);
    // „mix": bevorzugt ein Merkmal, das in der Gruppe noch fehlt.
    // „gleich": bevorzugt dasselbe Merkmal wie die bisherigen der Gruppe.
    let candidates = filled;
    if (mode === 'mix') {
      candidates = filled.filter((list) => !groupMarks.has(marks[list[list.length - 1]] || ''));
    } else if (mode === 'gleich' && posInGroup > 0) {
      candidates = filled.filter((list) => groupMarks.has(marks[list[list.length - 1]] || ''));
    }
    if (!candidates.length) candidates = filled;
    const most = Math.max(...candidates.map((list) => list.length));
    const top = candidates.filter((list) => list.length === most);
    flat.push(top[randomInt(top.length)].pop());
  }
  return flat;
}

function scoreArrangement(flat, size, marks, pairCounts, mode) {
  let score = 0;
  for (const group of chunk(flat, size)) {
    for (let i = 0; i < group.length; i += 1) {
      for (let j = i + 1; j < group.length; j += 1) {
        // Frühere Paarungen möglichst vermeiden …
        score += pairCounts.get(pairKey(group[i], group[j])) || 0;
        // … aber die Merkmal-Vorgabe wiegt deutlich schwerer.
        const a = marks[group[i]] || '';
        const b = marks[group[j]] || '';
        if (mode === 'mix' && a && a === b) score += 100;
        if (mode === 'gleich' && a !== b) score += 100;
      }
    }
  }
  return score;
}

/**
 * Beste von mehreren zufälligen Anordnungen — meidet alte Paare und setzt die
 * Merkmal-Vorgabe um: 'mix' (unterschiedliche Merkmale je Gruppe), 'gleich'
 * (gleiche Merkmale je Gruppe) oder 'egal' (Merkmale spielen keine Rolle).
 */
function drawArrangement(pool, marks, size, history, prefix = [], mode = 'mix') {
  const pairCounts = pastPairCounts(history);
  const useMarks = mode === 'egal' ? {} : marks;
  let best = null;
  let bestScore = Infinity;
  for (let attempt = 0; attempt < 40; attempt += 1) {
    const flat = arrangeOnce(pool, useMarks, size, prefix, mode);
    const score = scoreArrangement(flat, size, useMarks, pairCounts, mode);
    if (score < bestScore) {
      bestScore = score;
      best = flat;
    }
    if (bestScore === 0) break;
  }
  return best || prefix.concat(shuffled(pool));
}

/** Tagesgruppe: Wer bisher am seltensten dran war, kommt bevorzugt dran. */
function drawDayGroup(pool, count, history) {
  const used = new Map();
  for (const entry of history || []) {
    if (entry.mode !== 'tagesgruppe') continue;
    for (const name of entry.flat || []) used.set(name, (used.get(name) || 0) + 1);
  }
  const ranked = shuffled(pool).sort((a, b) => (used.get(a) || 0) - (used.get(b) || 0));
  return shuffled(ranked.slice(0, Math.max(0, Math.min(count, ranked.length))));
}

function stampLabel(at) {
  const date = new Date(at);
  return `${date.toLocaleDateString('de-DE', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })}, `
    + `${date.toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' })} Uhr`;
}

function namesOf(state) {
  if (state.listId) {
    const list = getList(state.listId);
    // Pausierte Namen (z. B. krank) zählen nicht mit und werden nicht gezogen.
    if (list) {
      const paused = Array.isArray(list.paused) ? list.paused : [];
      return list.names.filter((name) => !paused.includes(name));
    }
  }
  return Array.isArray(state.localNames) ? state.localNames.slice() : [];
}

function remainingOf(state) {
  const drawn = state.drawn || [];
  return namesOf(state).filter((name) => !drawn.includes(name));
}

function listTitle(state) {
  if (state.listId) {
    const list = getList(state.listId);
    if (list) return list.name;
    return 'Liste fehlt';
  }
  return 'Eigene Liste';
}

function revealMode(state) {
  const mode = state.reveal || 'mosaik';
  return REVEAL_MODES.some((entry) => entry.id === mode) ? mode : 'mosaik';
}

/** Zeichen, die verdeckt werden können (Buchstaben und Ziffern). */
function maskableIndexes(name) {
  const list = [];
  for (let i = 0; i < name.length; i += 1) {
    if (/[\p{L}\p{N}]/u.test(name[i])) list.push(i);
  }
  return list;
}

function revealTotal(state, name) {
  const mode = revealMode(state);
  if (mode === 'instant') return 0;
  if (mode === 'mosaik') return MOSAIC_TILES;
  if (mode === 'blur') return BLUR_STEPS;
  return Math.max(1, maskableIndexes(name || '').length);
}

function revealParts(state) {
  return Array.isArray(state.revealParts) ? state.revealParts : [];
}

function isRevealed(state, name) {
  if (!name) return true;
  if (revealMode(state) === 'instant') return true;
  return revealParts(state).length >= revealTotal(state, name);
}

/** Deckt den nächsten Schritt auf; gibt true zurück, wenn der Name danach ganz zu sehen ist. */
function revealStep(state, name) {
  const total = revealTotal(state, name);
  const done = new Set(revealParts(state));
  const open = [];
  for (let i = 0; i < total; i += 1) {
    if (!done.has(i)) open.push(i);
  }
  const count = revealMode(state) === 'mosaik' ? MOSAIC_PER_TAP : 1;
  for (let i = 0; i < count && open.length; i += 1) {
    const pick = open.splice(randomInt(open.length), 1)[0];
    done.add(pick);
  }
  state.revealParts = Array.from(done);
  return state.revealParts.length >= total;
}

export default {
  type: 'randomizer',
  label: 'Zufälliger Name',
  icon: 'randomizer',
  defaultSize: { w: 600, h: 460 },
  minSize: { w: 300, h: 280 },
  createState() {
    return {
      listId: null,
      localNames: [],
      title: '',
      mode: 'exhaust',
      drawn: [],
      current: null,
      showDrawn: 'edit',
      animate: true,
      reveal: 'mosaik',
      revealParts: [],
      spinSound: 'karten',
      // Gruppen & Tagesgruppe
      groupSize: 2,
      dayCount: 3,
      markMode: 'mix',
      groups: null,
      history: [],
      modeNames: {},
      // Anzeige des Ergebnisses: 'karten' oder 'abhaken' (Checkliste).
      groupView: 'karten',
      // Nach jeder Auslosung geschützt — erst das Schloss öffnen, dann neu losen.
      locked: false,
    };
  },

  mount(ctx) {
    const el = h('div', { class: 'w-random' });
    const head = h('div', { class: 'w-random__head' });
    const titleEl = h('div', { class: 'w-random__title' });
    const display = h('div', { class: 'w-random__display' });
    const nameBox = h('div', { class: 'w-random__namebox' });
    const nameEl = h('div', { class: 'w-random__name' });
    const maskEl = h('div', { class: 'w-random__mask' });
    const hintEl = h('div', { class: 'w-random__hint' });
    const drawnBox = h('div', { class: 'w-random__drawn', 'data-nodrag': '' });
    const groupsBox = h('div', { class: 'w-random__groups', 'data-nodrag': '' });

    nameBox.append(nameEl, maskEl);
    display.append(nameBox, groupsBox, hintEl);
    // Bewusst ohne Knöpfe: Gezogen und aufgedeckt wird durch Tippen auf die Karte.
    el.append(head, titleEl, display, drawnBox);

    let spinTimer = null;
    let spinning = false;
    let armed = false;
    let unveilTimer = 0;
    let dealTimers = [];
    let dealing = false;
    // Zum Ausmessen der Schriftbreite (für das Strecken verdeckter Namen).
    const meter = document.createElement('canvas').getContext('2d');

    function stopSpin() {
      if (spinTimer) clearTimeout(spinTimer);
      spinTimer = null;
      spinning = false;
      nameEl.classList.remove('is-spinning');
    }

    function celebrate() {
      nameEl.classList.remove('is-pop');
      void nameEl.offsetWidth;
      nameEl.classList.add('is-pop');
      confetti(display);
      beep({ frequency: 720, duration: 0.12, gain: 0.12 });
      beep({ frequency: 980, duration: 0.16, gain: 0.1, delay: 0.1 });
    }

    function stopDeal() {
      for (const timer of dealTimers) clearTimeout(timer);
      dealTimers = [];
      dealing = false;
    }

    /** Gruppen oder Tagesgruppe auslosen — ab `fromIndex` bleibt alles davor stehen. */
    function drawGroupsNow(fromIndex = 0) {
      if (dealing || spinning) return;
      const state = ctx.widget.state;
      const all = namesOf(state);
      if (!all.length) {
        render();
        return;
      }
      const hasResult = state.groups && state.groups.mode === state.mode && Array.isArray(state.groups.flat);
      // Schutz: Ein bestehendes Ergebnis wird nie aus Versehen überlost.
      if (hasResult && state.locked) {
        toast('Das Ergebnis ist geschützt. Oben das Schloss antippen — danach lost ein Tipp auf einen Namen ab dort neu.', 'warn');
        // Das Schloss kurz wackeln lassen, damit klar ist, wo es sitzt.
        const lockBtn = el.querySelector('.w-random__headbtn--lock');
        if (lockBtn) {
          lockBtn.classList.remove('is-attention');
          void lockBtn.offsetWidth;
          lockBtn.classList.add('is-attention');
        }
        return;
      }
      const isDay = state.mode === 'tagesgruppe';
      const size = isDay ? 1 : groupSizeOf(state);
      const shown = hasResult ? state.groups.flat : [];
      const prefix = fromIndex > 0 ? shown.slice(0, fromIndex).filter((name) => all.includes(name)) : [];
      const pool = all.filter((name) => !prefix.includes(name));
      let flat;
      if (isDay) {
        const count = Math.min(dayCountOf(state), all.length);
        flat = prefix.concat(drawDayGroup(pool, count - prefix.length, state.history));
      } else {
        flat = drawArrangement(pool, marksOf(state), size, state.history, prefix, markModeOf(state));
      }
      if (!Array.isArray(state.history)) state.history = [];
      if (fromIndex > 0 && state.groups && state.groups.at) {
        // Neuauslosung ab einer Stelle berichtigt den laufenden Durchgang —
        // es entsteht kein neuer Verlaufseintrag. Haken bleiben nur für
        // Gruppen, die ganz vor der Stelle liegen.
        const firstChanged = Math.floor(prefix.length / size);
        const done = (state.groups.done || []).filter((groupIndex) => groupIndex < firstChanged);
        state.groups = { at: state.groups.at, mode: state.mode, size, flat, done };
        const entry = state.history.find((item) => item.at === state.groups.at);
        if (entry) {
          entry.flat = flat.slice();
          entry.size = size;
          entry.done = done.slice();
        }
      } else {
        const entry = { at: Date.now(), mode: state.mode, size, flat: flat.slice(), done: [] };
        state.history.unshift(entry);
        if (state.history.length > HISTORY_MAX) state.history.length = HISTORY_MAX;
        state.groups = { at: entry.at, mode: state.mode, size, flat, done: [] };
      }
      state.locked = true;
      ctx.save();
      render(prefix.length);
    }

    /** Haken einer Gruppe umschalten (Checklisten-Anzeige). */
    function toggleDone(groupIndex) {
      const state = ctx.widget.state;
      if (!state.groups) return;
      const done = new Set(state.groups.done || []);
      if (done.has(groupIndex)) done.delete(groupIndex);
      else done.add(groupIndex);
      state.groups.done = Array.from(done);
      const entry = (state.history || []).find((item) => item.at === state.groups.at);
      if (entry) entry.done = state.groups.done.slice();
      beep({ frequency: done.has(groupIndex) ? 760 : 420, duration: 0.08, gain: 0.08 });
      ctx.save();
      render();
    }

    /**
     * Schriftgröße so wählen, dass alle Kärtchen gleich groß sind und ALLE
     * Reihen in die Kachel passen — so groß wie möglich, der Rand gibt nach.
     */
    function fitGroups(size, rows, maxLen, checklist) {
      const cardWidth = Math.max(80, (ctx.widget.w - 40 - (checklist ? 46 : 0)) / size - 10);
      const cardHeight = rows > 0 ? Math.max(30, (ctx.widget.h - 118) / rows - 8) : 40;
      const byWidth = cardWidth / (Math.max(3, maxLen) * 0.58);
      const value = Math.max(13, Math.min(byWidth, cardHeight * 0.58, 64));
      groupsBox.style.fontSize = `${value}px`;
    }

    function renderGroups(animateFrom = Infinity) {
      const state = ctx.widget.state;
      stopDeal();
      clear(groupsBox);
      const shown = state.groups && state.groups.mode === state.mode && Array.isArray(state.groups.flat)
        ? state.groups : null;
      const flat = shown ? shown.flat : [];
      const size = state.mode === 'tagesgruppe' ? 1 : (shown ? shown.size : groupSizeOf(state));
      const checklist = state.groupView === 'abhaken';
      const done = new Set(shown && Array.isArray(shown.done) ? shown.done : []);
      groupsBox.style.gridTemplateColumns = (checklist ? 'auto ' : '') + `repeat(${size}, minmax(0, 1fr))`;
      fitGroups(size, Math.ceil(flat.length / size) || 1,
        flat.reduce((acc, name) => Math.max(acc, name.length), 4), checklist);
      const animateOk = state.animate !== false && !reducedMotion() && animateFrom < flat.length;
      const sound = spinSoundById(state.spinSound).id;
      flat.forEach((name, index) => {
        const groupIndex = Math.floor(index / size);
        if (checklist && index % size === 0) {
          // Abhak-Knopf vor jeder Gruppe — festhalten, wer schon fertig ist.
          groupsBox.appendChild(onTap(h('button', {
            class: 'w-random__gcheck' + (done.has(groupIndex) ? ' is-done' : ''),
            'data-nodrag': '', title: done.has(groupIndex) ? 'Haken entfernen' : 'Als erledigt abhaken',
            html: icon('check', 18),
          }), () => toggleDone(groupIndex)));
        }
        const card = onTap(h('button', {
          class: 'w-random__gcard' + (groupIndex % 2 ? ' is-alt' : '') + (checklist && done.has(groupIndex) ? ' is-done' : ''),
          'data-nodrag': '',
          title: checklist ? 'Gruppe abhaken' : 'Ab hier neu auslosen (alles davor bleibt)',
        }, h('span', { class: 'w-random__gcard-text' }, name)), () => {
          if (checklist) toggleDone(groupIndex);
          else drawGroupsNow(index);
        });
        if (animateOk && index >= animateFrom) {
          card.classList.add('is-waiting');
          const stepIndex = index - animateFrom;
          dealing = true;
          dealTimers.push(setTimeout(() => {
            card.classList.remove('is-waiting');
            card.classList.add('is-dealt');
            spinTick(sound, flat.length > animateFrom + 1 ? stepIndex / (flat.length - animateFrom - 1) : 1);
            if (index === flat.length - 1) {
              dealing = false;
              spinEnd(sound);
              if (animateFrom === 0) confetti(display);
            }
          }, 140 + stepIndex * 110));
        }
        groupsBox.appendChild(card);
      });
    }

    function draw() {
      if (spinning) return;
      const state = ctx.widget.state;
      const pool = state.mode === 'repeat' ? namesOf(state) : remainingOf(state);
      if (pool.length === 0) {
        const empty = namesOf(state).length === 0;
        nameEl.textContent = empty ? 'Keine Namen' : 'Liste ist durch';
        nameEl.classList.add('is-empty');
        hintEl.textContent = empty
          ? 'Einstellungen öffnen und Namen eintragen.'
          : 'Alle Namen gezogen — unten zurücksetzen.';
        fitName();
        return;
      }

      const finish = (name) => {
        const next = ctx.widget.state;
        next.current = name;
        next.revealParts = [];
        if (!next.drawn) next.drawn = [];
        if (!next.drawn.includes(name)) next.drawn.push(name);
        ctx.save();
        render();
        if (isRevealed(next, name)) celebrate();
        else beep({ frequency: 520, duration: 0.1, gain: 0.1 });
      };

      const chosen = pickRandom(pool);
      if (state.animate === false || pool.length < 2 || reducedMotion()) {
        finish(chosen);
        return;
      }
      stopSpin();
      spinning = true;
      nameEl.classList.remove('is-empty', 'is-pop');
      nameEl.classList.add('is-spinning');
      nameEl.style.transform = '';
      nameBox.classList.remove('is-covered');
      maskEl.classList.add('is-hidden');
      const sound = spinSoundById(state.spinSound).id;
      // Beim Durchlaufen nie den gezogenen Namen zeigen — sonst „endet" das
      // Mischen sichtbar auf ihm, bevor die Maske kommt.
      const showPool = pool.length > 1 && revealMode(state) !== 'instant'
        ? pool.filter((entry) => entry !== chosen)
        : pool;

      const stepOnce = (index) => {
        nameEl.textContent = pickRandom(showPool);
        fitName();
        spinTick(sound, index / (SPIN_STEPS - 1));
        if (index >= SPIN_STEPS - 1) {
          stopSpin();
          spinEnd(sound);
          finish(chosen);
          return;
        }
        spinTimer = setTimeout(() => stepOnce(index + 1), spinDelay(index));
      };
      stepOnce(0);
    }

    function step() {
      const state = ctx.widget.state;
      if (isGroupMode(state)) {
        drawGroupsNow(0);
        return;
      }
      if (!state.current || isRevealed(state, state.current)) {
        draw();
        return;
      }
      const complete = revealStep(state, state.current);
      ctx.save();
      render();
      if (complete) celebrate();
      else beep({ frequency: 620, duration: 0.07, gain: 0.07 });
    }

    function revealAll() {
      const state = ctx.widget.state;
      if (!state.current || isRevealed(state, state.current)) return;
      const total = revealTotal(state, state.current);
      state.revealParts = Array.from({ length: total }, (_, index) => index);
      ctx.save();
      render();
      celebrate();
    }

    function fitName() {
      const state = ctx.widget.state;
      const name = state.current;
      const covered = Boolean(name) && !isRevealed(state, name) && revealMode(state) !== 'letters' && !spinning;
      const text = nameEl.textContent || '';
      const boxWidth = Math.max(140, ctx.widget.w - 70);

      if (!covered) {
        const length = Math.max(4, text.length);
        let size = Math.min(ctx.widget.h * 0.29, boxWidth / (length * 0.6));
        size = Math.max(20, Math.min(size, 128));
        nameEl.style.fontSize = `${size}px`;
        nameEl.style.transform = '';
        nameBox.style.minHeight = '';
        return;
      }

      // Verdeckt: EINE feste Schriftgröße für alle Namen — weder Breite noch
      // Höhe der Maske dürfen etwas über den Namen verraten. Der Schriftzug
      // wird als Ganzes auf die Zielbreite gestreckt oder gestaucht — ohne
      // Lücken zwischen den Buchstaben; erst wenn auch das Stauchen nicht
      // reicht, wird die Schrift kleiner.
      let size = Math.max(20, Math.min(Math.min(ctx.widget.h * 0.29, boxWidth / (12 * 0.6)), 128));
      // Die Boxhöhe hängt an der Bezugsgröße, nie am tatsächlichen Namen —
      // auch wenn ein sehr langer Name kleiner gesetzt werden muss.
      nameBox.style.minHeight = `${Math.round(size * 1.35)}px`;
      const target = Math.max(140, ctx.widget.w - 110) * 0.86;
      const measure = (px) => {
        const style = window.getComputedStyle(nameEl);
        meter.font = `${style.fontWeight} ${px}px ${style.fontFamily}`;
        const result = meter.measureText(text).width;
        // Scheitert die Messung (unbekannte Schrift o. Ä.), lieber grob schätzen.
        return result > 0 ? result : text.length * px * 0.6;
      };
      const MIN_X = 0.75;
      const MAX_X = 5;
      let width = measure(size);
      if (width * MIN_X > target) {
        size = Math.max(20, size * (target / (width * MIN_X)));
        width = measure(size);
      }
      nameEl.style.fontSize = `${size}px`;
      const factor = width > 0 ? Math.min(MAX_X, Math.max(MIN_X, target / width)) : 1;
      nameEl.style.transform = `scaleX(${factor.toFixed(3)})`;
    }

    /**
     * Gürtel und Hosenträger gegen jedes Aufblitzen: Ein frisch verdeckter Name
     * wird zunächst unsichtbar eingesetzt und erst zwei Bildaufbauten NACH der
     * Maske sichtbar gemacht. Selbst wenn ein Browser Maske und Text nicht im
     * selben Bild zeichnet, steht der Name nie unbedeckt da.
     */
    function shieldName(covered) {
      if (unveilTimer) window.cancelAnimationFrame(unveilTimer);
      unveilTimer = 0;
      if (!covered) {
        nameEl.style.visibility = '';
        return;
      }
      nameEl.style.visibility = 'hidden';
      unveilTimer = window.requestAnimationFrame(() => {
        unveilTimer = window.requestAnimationFrame(() => {
          nameEl.style.visibility = '';
          unveilTimer = 0;
        });
      });
    }

    function renderMask(state, name, hidden) {
      const mode = revealMode(state);
      nameEl.style.filter = '';
      // Volle Breite, solange verdeckt — die Maskengröße bleibt für alle Namen gleich.
      nameBox.classList.toggle('is-covered', hidden && mode !== 'letters');
      maskEl.classList.toggle('is-hidden', !hidden || mode !== 'mosaik');
      if (!hidden) {
        clear(maskEl);
        return;
      }
      if (mode === 'blur') {
        const progress = Math.min(1, revealParts(state).length / BLUR_STEPS);
        // Die Unschärfe richtet sich nach der Schriftgröße — sonst bleibt ein
        // großer Name auch mit festem Wert lesbar.
        const size = parseFloat(nameEl.style.fontSize) || 48;
        const amount = size * 0.42 * Math.pow(1 - progress, 1.5) + 1.5;
        nameEl.style.filter = `blur(${amount.toFixed(1)}px)`;
        clear(maskEl);
        return;
      }
      if (mode !== 'mosaik') {
        clear(maskEl);
        return;
      }
      const open = new Set(revealParts(state));
      if (maskEl.childElementCount !== MOSAIC_TILES) {
        clear(maskEl);
        maskEl.style.gridTemplateColumns = `repeat(${MOSAIC_COLS}, 1fr)`;
        maskEl.style.gridTemplateRows = `repeat(${MOSAIC_ROWS}, 1fr)`;
        for (let i = 0; i < MOSAIC_TILES; i += 1) maskEl.appendChild(h('span', { class: 'w-random__tile' }));
      }
      Array.from(maskEl.children).forEach((tile, index) => {
        tile.classList.toggle('is-open', open.has(index));
      });
      void name;
    }

    function render(animateFrom = Infinity) {
      const state = ctx.widget.state;
      const all = namesOf(state);
      const drawn = state.drawn || [];
      const remaining = remainingOf(state);
      const name = state.current;
      const hidden = Boolean(name) && !isRevealed(state, name);
      const mode = revealMode(state);
      const groupMode = isGroupMode(state);

      const hasResult = groupMode && state.groups && state.groups.mode === state.mode
        && Array.isArray(state.groups.flat) && state.groups.flat.length > 0;

      clear(head);
      head.appendChild(h('span', { class: 'w-random__list' }, listTitle(state)));
      if (hasResult) {
        // Zwei kleine Knöpfe direkt am Ergebnis: Anzeige umschalten und Schutz.
        // Sie stehen VOR dem Zähler, damit sie beim Bearbeiten nicht unter dem
        // Eck-Anfasser des Auswahlrahmens liegen.
        const checklist = state.groupView === 'abhaken';
        head.append(
          onTap(h('button', {
            class: 'w-random__headbtn' + (checklist ? ' is-on' : ''), 'data-nodrag': '',
            title: checklist ? 'Als Kärtchen anzeigen' : 'Als Checkliste zum Abhaken anzeigen',
            html: icon('checklist', 16),
          }), () => {
            ctx.widget.state.groupView = checklist ? 'karten' : 'abhaken';
            ctx.save();
            render();
          }),
          onTap(h('button', {
            class: 'w-random__headbtn w-random__headbtn--lock' + (state.locked ? ' is-on' : ''), 'data-nodrag': '',
            title: state.locked
              ? 'Geschützt — antippen zum Entsperren (dann ist Neuauslosen möglich)'
              : 'Ungeschützt — antippen schützt das Ergebnis vor Neuauslosung',
            html: icon(state.locked ? 'lock' : 'unlock', 16),
          }), () => {
            ctx.widget.state.locked = !ctx.widget.state.locked;
            ctx.save();
            render();
          }));
      }
      head.appendChild(h('span', { class: 'w-random__count' },
        groupMode
          ? `${modeLabel(state, state.mode)} · ${all.length} Namen`
          : (state.mode === 'repeat' ? `${all.length} Namen` : `${remaining.length}/${all.length}`)));

      titleEl.textContent = state.title || '';
      titleEl.classList.toggle('is-hidden', !state.title);

      nameBox.classList.toggle('is-hidden', groupMode);

      if (groupMode) {
        renderGroups(animateFrom);
        // Ohne Kärtchen bleibt die Fläche weg — sonst schluckt sie als
        // Bedienfläche (data-nodrag) den Tipp, der auslosen soll.
        groupsBox.classList.toggle('is-hidden', groupsBox.childElementCount === 0);
        shieldName(false);
        const shown = state.groups && state.groups.mode === state.mode && Array.isArray(state.groups.flat);
        if (!all.length) {
          hintEl.textContent = 'Einstellungen öffnen und Namen eintragen.';
        } else if (!shown) {
          hintEl.textContent = armed
            ? 'Bereit — der nächste Tipp lost aus'
            : 'Antippen, dann nochmal tippen zum Auslosen';
        } else {
          const latest = Array.isArray(state.history) && state.history[0] && state.history[0].at === state.groups.at;
          if (!latest) {
            hintEl.textContent = `Frühere Auslosung: ${stampLabel(state.groups.at)}`;
          } else if (state.groupView === 'abhaken') {
            hintEl.textContent = 'Tipp auf eine Gruppe hakt sie ab — z. B. wer die Aufgabe erledigt hat.';
          } else if (state.locked) {
            hintEl.textContent = 'Geschützt — zum Neuauslosen das Schloss oben öffnen.';
          } else {
            hintEl.textContent = 'Tipp auf einen Namen lost ab dort neu — alles davor bleibt. Tipp daneben lost alles neu.';
          }
        }
        drawnBox.classList.add('is-hidden');
        return;
      }

      groupsBox.classList.add('is-hidden');
      nameEl.classList.toggle('is-empty', !name);
      if (name && hidden && mode === 'letters') {
        const maskable = new Set(maskableIndexes(name));
        const open = new Set(revealParts(state).map((index) => maskableIndexes(name)[index]));
        nameEl.textContent = Array.from(name)
          .map((char, index) => (maskable.has(index) && !open.has(index) ? '•' : char))
          .join('');
      } else {
        nameEl.textContent = name || (all.length ? 'Bereit' : 'Keine Namen');
      }
      fitName();
      renderMask(state, name, hidden);
      shieldName(hidden && mode !== 'letters');

      if (all.length === 0) {
        hintEl.textContent = 'Einstellungen öffnen und Namen eintragen.';
      } else if (hidden) {
        const perTap = mode === 'mosaik' ? MOSAIC_PER_TAP : 1;
        const total = Math.ceil(revealTotal(state, name) / perTap);
        const done = Math.min(total, Math.ceil(revealParts(state).length / perTap));
        hintEl.textContent = `Tippen deckt auf — Schritt ${done} von ${total}`;
      } else if (state.mode !== 'repeat' && remaining.length === 0) {
        hintEl.textContent = 'Alle Namen gezogen.';
      } else {
        hintEl.textContent = armed
          ? 'Bereit — der nächste Tipp zieht'
          : 'Antippen, dann nochmal tippen zum Ziehen';
      }

      const showDrawn = state.showDrawn === true ? 'edit' : (state.showDrawn || 'edit');
      const mayShow = showDrawn === 'always' || (showDrawn === 'edit' && ctx.isEditing());
      // Der aktuelle Name bleibt versteckt, solange er noch nicht aufgedeckt ist.
      const visibleDrawn = hidden ? drawn.filter((entry) => entry !== name) : drawn;

      clear(drawnBox);
      const show = mayShow && visibleDrawn.length > 0;
      if (show) {
        drawnBox.append(h('div', { class: 'w-random__drawn-head' },
          h('span', null, `Gezogen (${visibleDrawn.length})`),
          onTap(h('button', { class: 'link-button', 'data-nodrag': '' }, 'Zurücksetzen'), reset)));
        const chips = h('div', { class: 'chips' });
        for (const entry of visibleDrawn) {
          chips.appendChild(onTap(h('button', {
            class: 'chip-name', 'data-nodrag': '', title: 'Zurücklegen (wieder ziehbar machen)',
          }, h('span', null, entry), h('span', { class: 'chip-name__x', html: icon('close', 12) })), () => {
            const next = ctx.widget.state;
            next.drawn = (next.drawn || []).filter((item) => item !== entry);
            if (next.current === entry) next.current = null;
            ctx.save();
            render();
          }));
        }
        drawnBox.appendChild(chips);
      }
      // In der Unterrichtsansicht steht nichts unter dem Namen; zurückgesetzt wird
      // beim Bearbeiten oder in den Einstellungen.
      drawnBox.classList.toggle('is-hidden', !show);
    }

    function reset() {
      const state = ctx.widget.state;
      state.drawn = [];
      state.current = null;
      state.revealParts = [];
      ctx.save();
      render();
    }

    // Tipp neben die Kärtchen (auf die freie Fläche) lost alles neu aus.
    groupsBox.addEventListener('click', (event) => {
      if (event.target === groupsBox) drawGroupsNow(0);
    });

    const off = onStore('lists-changed', () => render());
    render();

    return {
      el,
      refresh: render,
      onResize: () => {
        if (isGroupMode(ctx.widget.state)) render();
        else fitName();
      },
      onTap: step,
      // Erst der zweite Tipp löst aus — sonst zieht ein versehentlicher Tipp einen Namen.
      tapNeedsFocus: true,
      // Solange etwas verdeckt ist, bietet die kleine Leiste beim Bearbeiten das Augensymbol an.
      get actions() {
        const state = ctx.widget.state;
        if (isGroupMode(state)) return [];
        if (!state.current || isRevealed(state, state.current)) return [];
        return [{ icon: 'eye', title: 'Namen ganz aufdecken', run: revealAll }];
      },
      onArmedChange(value) {
        armed = value;
        render();
      },
      destroy() {
        stopSpin();
        stopDeal();
        if (unveilTimer) window.cancelAnimationFrame(unveilTimer);
        off();
      },
    };
  },

  settings(ctx) {
    const wrap = h('div', { class: 'stack' });

    function rerender() {
      clear(wrap);
      build();
      ctx.refresh();
    }

    function build() {
      const state = ctx.widget.state;
      const lists = getState().lists;
      const select = h('select', {
        class: 'input',
        onchange: (event) => {
          const value = event.target.value;
          ctx.widget.state.listId = value === '__local' ? null : value;
          ctx.widget.state.drawn = [];
          ctx.widget.state.current = null;
          ctx.widget.state.revealParts = [];
          ctx.save();
          rerender();
        },
      },
      h('option', { value: '__local' }, 'Eigene Liste (nur dieses Element)'),
      lists.map((list) => h('option', { value: list.id }, `${list.name} (${list.names.length})`)));
      select.value = state.listId || '__local';

      // 1) Der Modus zuerst — er bestimmt, was darunter überhaupt gebraucht wird.
      const activeMode = MODES.some((entry) => entry.id === state.mode) ? state.mode : 'exhaust';
      const groupMode = isGroupMode(state);
      wrap.appendChild(section('Auswahlmodus',
        h('div', { class: 'segmented segmented--wrap' }, MODES.map((entry) => h('button', {
          class: 'segmented__item' + (activeMode === entry.id ? ' is-active' : ''),
          onclick: () => {
            ctx.widget.state.mode = entry.id;
            ctx.save();
            rerender();
          },
        }, modeLabel(state, entry.id)))),
        h('p', { class: 'muted small' }, {
          exhaust: 'Ein gezogener Name kommt erst nach dem Zurücksetzen wieder in den Topf.',
          repeat: 'Jeder Name kann mehrfach gezogen werden.',
          gruppen: 'Lost die ganze Liste in Gruppen aus — Partner nebeneinander, Gruppen untereinander. '
            + 'Tipp auf einen Namen lost ab dieser Stelle neu; alles davor bleibt stehen.',
          tagesgruppe: 'Lost eine kleine Auswahl von Kindern aus (untereinander angezeigt) — wer selten dran war, kommt bevorzugt dran.',
        }[activeMode])));

      // 2) Nur die Einstellungen des gewählten Modus.
      if (groupMode) {
        const viewValue = state.groupView === 'abhaken' ? 'abhaken' : 'karten';
        const parts = [];
        if (activeMode === 'gruppen') {
          parts.push(field('Gruppengröße (1–15)', h('input', {
            class: 'input input--small', type: 'number', min: '1', max: '15', value: String(groupSizeOf(state)),
            oninput: (event) => {
              const value = Math.max(1, Math.min(15, Math.round(Number(event.target.value) || 2)));
              ctx.widget.state.groupSize = value;
              ctx.save();
              ctx.refresh();
            },
          }), 'Die letzte Gruppe kann kleiner ausfallen, wenn die Gesamtzahl nicht aufgeht. Gilt ab der nächsten Auslosung.'));
          // Merkmale der gewählten Liste zusammenzählen — so ist sichtbar,
          // ob das Mischen überhaupt greifen kann.
          const marks = marksOf(state);
          const counts = {};
          for (const name of namesOf(state)) {
            if (marks[name]) counts[marks[name]] = (counts[marks[name]] || 0) + 1;
          }
          const kinds = Object.entries(counts).map(([mark, count]) => `${mark}: ${count}`);
          const markMode = markModeOf(state);
          parts.push(field('Merkmale in der Gruppe', h('div', { class: 'segmented' },
            [['egal', 'Egal'], ['mix', 'Unterschiedlich'], ['gleich', 'Gleich']].map(([value, label]) => h('button', {
              class: 'segmented__item' + (markMode === value ? ' is-active' : ''),
              onclick: () => {
                ctx.widget.state.markMode = value;
                ctx.save();
                rerender();
              },
            }, label))),
          {
            egal: 'Merkmale spielen keine Rolle — es wird rein zufällig verteilt.',
            mix: 'Jede Gruppe mischt die Merkmale nach Möglichkeit — z. B. ein Junge und ein Mädchen zusammen.',
            gleich: 'Jede Gruppe besteht nach Möglichkeit aus gleichen Merkmalen — z. B. reine Jungen- und Mädchengruppen oder gleiche Lesestufen.',
          }[markMode] + ' Gilt ab der nächsten Auslosung.'));
          parts.push(h('p', { class: 'muted small' }, kinds.length
            ? `Vergebene Merkmale in dieser Liste — ${kinds.join(', ')}.`
            : 'Diese Liste hat noch keine Merkmale. Vergeben unter „Listen“ → Liste öffnen → „Merkmale (für Gruppen)“ — z. B. „J“/„M“ je Name.'));
          parts.push(h('p', { class: 'muted small' },
            'Frühere Zusammensetzungen werden automatisch gemieden, bis alle Kombinationen durch sind.'));
        } else {
          parts.push(field('Anzahl Kinder (1–30)', h('input', {
            class: 'input input--small', type: 'number', min: '1', max: '30', value: String(dayCountOf(state)),
            oninput: (event) => {
              const value = Math.max(1, Math.min(30, Math.round(Number(event.target.value) || 3)));
              ctx.widget.state.dayCount = value;
              ctx.save();
              ctx.refresh();
            },
          }), 'Gilt ab der nächsten Auslosung.'));
        }
        parts.push(field('Ergebnis anzeigen als', h('div', { class: 'segmented' },
          [['karten', 'Kärtchen'], ['abhaken', 'Zum Abhaken']].map(([value, label]) => h('button', {
            class: 'segmented__item' + (viewValue === value ? ' is-active' : ''),
            onclick: () => {
              ctx.widget.state.groupView = value;
              ctx.save();
              rerender();
            },
          }, label))),
        '„Zum Abhaken“: Ein Tipp auf eine Gruppe hakt sie ab — z. B. wer die Aufgabe schon erledigt hat. '
        + 'Auch nach der Auslosung jederzeit umschaltbar (auch über das Listensymbol oben auf der Karte).'));
        parts.push(toggleRow('Mit Animation auslosen', state.animate !== false, (value) => {
          ctx.widget.state.animate = value;
          ctx.save();
          rerender();
        }, 'Aus: Die Kärtchen stehen sofort da — dann gibt es auch keinen Klang.'));
        parts.push(toggleRow('Ergebnis geschützt', state.locked === true, (value) => {
          ctx.widget.state.locked = value;
          ctx.save();
          rerender();
        }, 'Schützt vor versehentlichem Neuauslosen. Nach jeder Auslosung automatisch an — das Schloss oben auf der Karte schaltet ebenfalls um.'));
        wrap.appendChild(section(modeLabel(state, activeMode), ...parts));
      } else {
        wrap.appendChild(section('Ziehen',
          toggleRow('Namen durchlaufen lassen', state.animate !== false, (value) => {
            ctx.widget.state.animate = value;
            ctx.save();
            rerender();
          }, 'Aus: Der Name steht sofort da — dann gibt es auch keinen Klang.')));
      }

      wrap.appendChild(section('Namensliste',
        field('Liste wählen', select),
        buttonRow(
          button('Listen verwalten', { icon: 'layers', small: true, onClick: () => ctx.openLists() }),
          state.listId ? null : button('Als Liste speichern', {
            icon: 'download', small: true,
            onClick: () => {
              const names = ctx.widget.state.localNames || [];
              if (!names.length) {
                toast('Erst Namen eintragen.', 'warn');
                return;
              }
              const list = addList('Neue Klasse', names.slice());
              ctx.widget.state.listId = list.id;
              ctx.save();
              rerender();
              toast('Liste gespeichert.', 'success');
            },
          }))));

      if (!state.listId) {
        wrap.appendChild(section('Namen (eine Zeile pro Name)', h('textarea', {
          class: 'input input--area', rows: 8, placeholder: 'Ein Name pro Zeile',
          value: (state.localNames || []).join('\n'),
          oninput: (event) => {
            ctx.widget.state.localNames = parseNames(event.target.value);
            ctx.save();
            ctx.refresh();
          },
        })));
      }

      wrap.appendChild(section('Überschrift',
        field('Überschrift (optional)', h('input', {
          class: 'input', type: 'text', value: state.title || '', placeholder: 'z. B. Wer liest vor?',
          oninput: (event) => {
            ctx.widget.state.title = event.target.value;
            ctx.save();
            ctx.refresh();
          },
        }), 'Steht groß über dem Namen — z. B. als Frage an die Klasse.')));

      if (groupMode) {
        const history = Array.isArray(state.history)
          ? state.history.filter((entry) => entry.mode === activeMode)
          : [];
        const historyBox = h('div', { class: 'stack' });
        if (!history.length) {
          historyBox.appendChild(h('p', { class: 'muted small' }, 'Noch keine Auslosung gespeichert.'));
        } else {
          historyBox.append(
            h('p', { class: 'muted small' }, 'Antippen zeigt die frühere Auslosung auf der Karte.'),
            h('div', { class: 'stack stack--tight' }, history.map((entry) => h('button', {
              class: 'list-row__main' + (state.groups && state.groups.at === entry.at ? ' is-active' : ''),
              onclick: () => {
                ctx.widget.state.groups = {
                  at: entry.at,
                  mode: entry.mode,
                  size: entry.size,
                  flat: entry.flat.slice(),
                  done: Array.isArray(entry.done) ? entry.done.slice() : [],
                };
                ctx.save();
                ctx.refresh();
              },
            },
            h('strong', null, stampLabel(entry.at)),
            h('small', { class: 'muted' },
              `${entry.flat.length} Namen${entry.mode === 'gruppen' ? ` · ${Math.ceil(entry.flat.length / (entry.size || 2))} Gruppen` : ''}`)))));
        }
        historyBox.appendChild(buttonRow(button('Verlauf löschen (Reset)', {
          icon: 'trash', small: true, ghost: true,
          onClick: () => {
            ctx.widget.state.history = (ctx.widget.state.history || []).filter((entry) => entry.mode !== activeMode);
            ctx.widget.state.groups = null;
            ctx.save();
            rerender();
            toast('Verlauf gelöscht — alle Kombinationen sind wieder möglich.', 'success');
          },
        })));
        wrap.appendChild(section(`Frühere Auslosungen (${history.length})`, historyBox));
      }

      const sound = spinSoundById(state.spinSound).id;
      wrap.appendChild(section('Klang beim Ziehen',
        h('div', { class: 'chips' }, SPIN_SOUNDS.map((entry) => h('button', {
          class: 'chip' + (sound === entry.id ? ' is-active' : ''),
          onclick: () => {
            ctx.widget.state.spinSound = entry.id;
            ctx.save();
            // Direkt zum Anhören — so lässt sich vergleichen, ohne zu ziehen.
            previewSpinSound(entry.id);
            rerender();
          },
        }, entry.label))),
        h('p', { class: 'muted small' }, `${spinSoundById(sound).hint} Zum Anhören auf die Auswahl tippen.`),
        state.animate === false
          ? h('p', { class: 'muted small' }, 'Zurzeit ohne Wirkung: „Namen durchlaufen lassen" ist ausgeschaltet.')
          : null));

      // Selten gebraucht: eigene Namen für die Modi — eingeklappt am Ende.
      const renameFold = () => h('details', { class: 'fold' },
        h('summary', { class: 'fold__head' }, 'Modi umbenennen'),
        h('div', { class: 'stack fold__body' },
          h('p', { class: 'muted small' }, 'Eigene Namen für die Auswahlmodi — leer lassen für den Standardnamen.'),
          MODES.map((entry) => field(entry.label,
            h('input', {
              class: 'input', type: 'text',
              value: (state.modeNames && state.modeNames[entry.id]) || '',
              placeholder: entry.label,
              oninput: (event) => {
                if (!ctx.widget.state.modeNames || typeof ctx.widget.state.modeNames !== 'object') {
                  ctx.widget.state.modeNames = {};
                }
                ctx.widget.state.modeNames[entry.id] = event.target.value;
                ctx.save();
                ctx.refresh();
              },
            })))));

      // Aufdecken und „gezogene Namen" betreffen nur das Ziehen einzelner Namen.
      if (groupMode) {
        wrap.appendChild(renameFold());
        return;
      }

      const current = revealMode(state);
      wrap.appendChild(section('Aufdecken',
        h('div', { class: 'chips' }, REVEAL_MODES.map((entry) => h('button', {
          class: 'chip' + (current === entry.id ? ' is-active' : ''),
          onclick: () => {
            const next = ctx.widget.state;
            next.reveal = entry.id;
            // Der gerade sichtbare Name bleibt sichtbar; die neue Art gilt ab dem nächsten Ziehen.
            const total = revealTotal(next, next.current || '');
            next.revealParts = Array.from({ length: total }, (_, index) => index);
            ctx.save();
            rerender();
          },
        }, entry.label))),
        h('p', { class: 'muted small' },
          `${(REVEAL_MODES.find((entry) => entry.id === current) || REVEAL_MODES[0]).hint} `
          + (current === 'instant' ? '' : 'Jeder Tipp auf die Karte deckt einen Schritt auf. '
            + 'Beim Bearbeiten zeigt das Augensymbol in der kleinen Leiste sofort alles.'))));

      const showDrawn = state.showDrawn === true ? 'edit' : (state.showDrawn || 'edit');
      wrap.appendChild(section('Gezogene Namen anzeigen',
        h('div', { class: 'segmented' },
          [['never', 'Nie'], ['edit', 'Beim Bearbeiten'], ['always', 'Immer']].map(([value, label]) => h('button', {
            class: 'segmented__item' + (showDrawn === value ? ' is-active' : ''),
            onclick: () => {
              ctx.widget.state.showDrawn = value;
              ctx.save();
              rerender();
            },
          }, label))),
        h('p', { class: 'muted small' },
          'In der Unterrichtsansicht bleibt die Liste bei „Beim Bearbeiten“ verborgen — so lässt sich nicht ablesen, wer noch fehlt.')));

      const drawn = state.drawn || [];
      const remaining = remainingOf(state);
      const manageBox = h('div', { class: 'stack' });

      if (drawn.length) {
        manageBox.append(
          h('p', { class: 'muted small' }, 'Tippen legt einen Namen zurück in den Topf.'),
          h('div', { class: 'chips' }, drawn.map((name) => h('button', {
            class: 'chip-name', title: 'Zurücklegen',
            onclick: () => {
              ctx.widget.state.drawn = (ctx.widget.state.drawn || []).filter((entry) => entry !== name);
              if (ctx.widget.state.current === name) ctx.widget.state.current = null;
              ctx.save();
              rerender();
            },
          }, h('span', null, name), h('span', { class: 'chip-name__x', html: icon('close', 12) })))));
      } else {
        manageBox.appendChild(h('p', { class: 'muted small' }, 'Noch nichts gezogen.'));
      }

      if (remaining.length) {
        const markSelect = h('select', { class: 'input' },
          h('option', { value: '' }, 'Name auswählen …'),
          remaining.map((name) => h('option', { value: name }, name)));
        manageBox.appendChild(field('Namen von Hand als gezogen markieren',
          h('div', { class: 'row' }, markSelect, button('Markieren', {
            small: true,
            onClick: () => {
              const value = markSelect.value;
              if (!value) return;
              const next = ctx.widget.state;
              if (!next.drawn) next.drawn = [];
              if (!next.drawn.includes(value)) next.drawn.push(value);
              ctx.save();
              rerender();
            },
          })),
          'Praktisch, wenn jemand ohne Zufallsziehung an der Reihe war.'));
      }

      manageBox.appendChild(buttonRow(
        button('Alle zurücksetzen', {
          icon: 'reset', small: true,
          onClick: () => {
            ctx.widget.state.drawn = [];
            ctx.widget.state.current = null;
            ctx.widget.state.revealParts = [];
            ctx.save();
            rerender();
          },
        }),
        button('Aktuellen Namen löschen', {
          icon: 'trash', small: true, ghost: true,
          onClick: () => {
            ctx.widget.state.current = null;
            ctx.widget.state.revealParts = [];
            ctx.save();
            rerender();
          },
        })));

      wrap.appendChild(section(`Gezogene Namen (${drawn.length})`, manageBox));
      wrap.appendChild(renameFold());
    }

    build();
    return wrap;
  },
};
