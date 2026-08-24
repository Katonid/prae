// Kleine Helfer für die Klassenraum-App.

export function uid(prefix = 'id') {
  return prefix + '-' + Math.random().toString(36).slice(2, 10);
}

export function clamp(value, min, max) {
  return Math.min(max, Math.max(min, value));
}

export function debounce(fn, wait) {
  let timer = null;
  return function debounced(...args) {
    if (timer) clearTimeout(timer);
    timer = setTimeout(() => {
      timer = null;
      fn.apply(null, args);
    }, wait);
  };
}

/** Erzeugt DOM-Knoten: h('div', {class:'x', onclick:fn}, 'Text', kindNode) */
export function h(tag, props, ...children) {
  const el = document.createElement(tag);
  if (props) {
    for (const [key, value] of Object.entries(props)) {
      if (value === null || value === undefined || value === false) continue;
      if (key === 'class') el.className = value;
      else if (key === 'style' && typeof value === 'object') Object.assign(el.style, value);
      else if (key === 'html') el.innerHTML = value;
      else if (key.startsWith('on') && typeof value === 'function') {
        el.addEventListener(key.slice(2).toLowerCase(), value);
      } else if (key === 'value' || key === 'checked' || key === 'disabled') {
        el[key] = value;
      } else {
        el.setAttribute(key, value === true ? '' : String(value));
      }
    }
  }
  appendChildren(el, children);
  return el;
}

function appendChildren(el, children) {
  for (const child of children) {
    if (child === null || child === undefined || child === false) continue;
    if (Array.isArray(child)) appendChildren(el, child);
    else if (child instanceof Node) el.appendChild(child);
    else el.appendChild(document.createTextNode(String(child)));
  }
}

export function clear(el) {
  while (el.firstChild) el.removeChild(el.firstChild);
  return el;
}

/** Zeit als mm:ss bzw. h:mm:ss */
export function formatDuration(totalSeconds) {
  const sign = totalSeconds < 0 ? '-' : '';
  let s = Math.abs(Math.round(totalSeconds));
  const hours = Math.floor(s / 3600);
  s -= hours * 3600;
  const minutes = Math.floor(s / 60);
  const seconds = s - minutes * 60;
  const pad = (n) => String(n).padStart(2, '0');
  if (hours > 0) return `${sign}${hours}:${pad(minutes)}:${pad(seconds)}`;
  return `${sign}${pad(minutes)}:${pad(seconds)}`;
}

/** Bild verkleinern und als JPEG/PNG-DataURL zurückgeben (spart Speicher & Sync-Volumen). */
export function readImageFile(file, maxEdge = 1400, quality = 0.78) {
  return new Promise((resolve, reject) => {
    if (!file || !file.type.startsWith('image/')) {
      reject(new Error('Keine Bilddatei'));
      return;
    }
    const reader = new FileReader();
    reader.onerror = () => reject(new Error('Datei konnte nicht gelesen werden'));
    reader.onload = () => {
      const img = new Image();
      img.onerror = () => reject(new Error('Bild konnte nicht geladen werden'));
      img.onload = () => {
        const scale = Math.min(1, maxEdge / Math.max(img.width, img.height));
        const width = Math.max(1, Math.round(img.width * scale));
        const height = Math.max(1, Math.round(img.height * scale));
        const canvas = document.createElement('canvas');
        canvas.width = width;
        canvas.height = height;
        const ctx = canvas.getContext('2d');
        ctx.drawImage(img, 0, 0, width, height);
        const transparent = file.type === 'image/png' || file.type === 'image/webp';
        const url = canvas.toDataURL(transparent ? 'image/png' : 'image/jpeg', quality);
        resolve({ url, width, height });
      };
      img.src = String(reader.result);
    };
    reader.readAsDataURL(file);
  });
}

let audioContext = null;

export function audio() {
  if (!audioContext) {
    const Ctx = window.AudioContext || window.webkitAudioContext;
    if (!Ctx) return null;
    audioContext = new Ctx();
  }
  if (audioContext.state === 'suspended') audioContext.resume().catch(() => {});
  return audioContext;
}

/** Kurzer Signalton (ohne Audiodateien, damit die App offline funktioniert). */
export function beep({ frequency = 880, duration = 0.18, gain = 0.18, type = 'sine', delay = 0 } = {}) {
  try {
    const ctx = audio();
    if (!ctx) return;
    const start = ctx.currentTime + delay;
    const osc = ctx.createOscillator();
    const amp = ctx.createGain();
    osc.type = type;
    osc.frequency.value = frequency;
    amp.gain.setValueAtTime(0.0001, start);
    amp.gain.exponentialRampToValueAtTime(gain, start + 0.02);
    amp.gain.exponentialRampToValueAtTime(0.0001, start + duration);
    osc.connect(amp).connect(ctx.destination);
    osc.start(start);
    osc.stop(start + duration + 0.05);
  } catch (_) {
    // Ton ist Beiwerk — spielt das Gerät ihn nicht ab, läuft alles andere weiter.
  }
}

export function chime(times = 3) {
  for (let i = 0; i < times; i += 1) {
    beep({ frequency: i % 2 === 0 ? 880 : 1180, delay: i * 0.32, duration: 0.24, gain: 0.22 });
  }
}

export async function copyText(text) {
  try {
    await navigator.clipboard.writeText(text);
    return true;
  } catch (error) {
    const area = document.createElement('textarea');
    area.value = text;
    area.setAttribute('readonly', '');
    area.style.position = 'fixed';
    area.style.opacity = '0';
    document.body.appendChild(area);
    area.select();
    let ok = false;
    try {
      ok = document.execCommand('copy');
    } catch (_) {
      ok = false;
    }
    document.body.removeChild(area);
    return ok;
  }
}

export function randomInt(maxExclusive) {
  if (maxExclusive <= 0) return 0;
  const values = new Uint32Array(1);
  if (window.crypto && window.crypto.getRandomValues) {
    window.crypto.getRandomValues(values);
    return values[0] % maxExclusive;
  }
  return Math.floor(Math.random() * maxExclusive);
}

export function pickRandom(list) {
  if (!list || list.length === 0) return null;
  return list[randomInt(list.length)];
}

export function parseNames(text) {
  return String(text || '')
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line.length > 0);
}

export function shareCode() {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let out = '';
  for (let i = 0; i < 6; i += 1) out += alphabet[randomInt(alphabet.length)];
  return out;
}

/** Bewegungsreduzierung der Systemeinstellungen respektieren. */
export function reducedMotion() {
  return window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
}

/*
 * Zuverlässiges Antippen: Touchgeräte lösen sofort bei pointerup aus (ohne die
 * übliche Verzögerung), der danach folgende „Geister-Klick" wird unterdrückt —
 * sonst würde eine neu aufgebaute Schaltfläche an derselben Stelle doppelt zählen.
 */
let ghostUntil = 0;
let ghostX = 0;
let ghostY = 0;
let ghostGuardReady = false;

export function armTapGuard(event) {
  ghostUntil = Date.now() + 700;
  ghostX = event.clientX;
  ghostY = event.clientY;
  if (ghostGuardReady) return;
  ghostGuardReady = true;
  document.addEventListener('click', (click) => {
    if (Date.now() > ghostUntil) return;
    if (Math.abs(click.clientX - ghostX) + Math.abs(click.clientY - ghostY) > 44) return;
    ghostUntil = 0;
    click.stopPropagation();
    click.preventDefault();
  }, true);
}

export function onTap(el, handler) {
  let armed = false;
  let startX = 0;
  let startY = 0;

  el.addEventListener('pointerdown', (event) => {
    armed = true;
    startX = event.clientX;
    startY = event.clientY;
  });
  el.addEventListener('pointercancel', () => { armed = false; });
  el.addEventListener('pointerup', (event) => {
    if (!armed) return;
    armed = false;
    if (event.pointerType === 'mouse') return;
    if (Math.abs(event.clientX - startX) + Math.abs(event.clientY - startY) > 24) return;
    armTapGuard(event);
    handler(event);
  });
  el.addEventListener('click', (event) => handler(event));
  return el;
}

/** Kleiner Konfetti-Regen als Belohnung — rein visuell, ohne Abhängigkeiten. */
export function confetti(host, { count = 70, colors = ['#6366f1', '#22d3ee', '#f472b6', '#facc15', '#34d399'] } = {}) {
  if (!host || reducedMotion()) return;
  const layer = document.createElement('div');
  layer.className = 'confetti';
  for (let i = 0; i < count; i += 1) {
    const piece = document.createElement('span');
    const angle = (Math.PI * (0.15 + 0.7 * (i / count))) * -1;
    const distance = 120 + randomInt(220);
    piece.style.setProperty('--dx', `${Math.cos(angle) * distance * (randomInt(2) ? 1 : -1)}px`);
    piece.style.setProperty('--dy', `${Math.sin(angle) * distance - randomInt(80)}px`);
    piece.style.setProperty('--rot', `${randomInt(720) - 360}deg`);
    piece.style.setProperty('--delay', `${randomInt(120)}ms`);
    piece.style.background = colors[i % colors.length];
    if (i % 3 === 0) piece.style.borderRadius = '50%';
    layer.appendChild(piece);
  }
  host.appendChild(layer);
  setTimeout(() => layer.remove(), 1600);
}
