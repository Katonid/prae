// Kleine Helfer für die Wörterwerkstatt.

/** Erzeugt DOM-Knoten: h('div', {class:'x', onclick:fn}, 'Text', kindNode) */
export function h(tag, props, ...children) {
  const el = document.createElement(tag);
  if (props) {
    for (const [key, value] of Object.entries(props)) {
      if (value === null || value === undefined || value === false) continue;
      if (key === 'class') el.className = value;
      else if (key === 'style' && typeof value === 'object') stil(el, value);
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
  anhaengen(el, children);
  return el;
}

/** Dasselbe für SVG — dort braucht es den Namensraum, sonst bleibt alles unsichtbar. */
export function s(tag, props, ...children) {
  const el = document.createElementNS('http://www.w3.org/2000/svg', tag);
  if (props) {
    for (const [key, value] of Object.entries(props)) {
      if (value === null || value === undefined || value === false) continue;
      if (key.startsWith('on') && typeof value === 'function') el.addEventListener(key.slice(2).toLowerCase(), value);
      else el.setAttribute(key, String(value));
    }
  }
  anhaengen(el, children);
  return el;
}

function stil(el, style) {
  for (const [name, value] of Object.entries(style)) {
    if (value === null || value === undefined) continue;
    if (name.startsWith('--')) el.style.setProperty(name, String(value));
    else el.style[name] = value;
  }
}

function anhaengen(el, children) {
  for (const child of children) {
    if (child === null || child === undefined || child === false) continue;
    if (Array.isArray(child)) anhaengen(el, child);
    else if (child instanceof Node) el.appendChild(child);
    else el.appendChild(document.createTextNode(String(child)));
  }
}

export function leeren(el) {
  while (el.firstChild) el.removeChild(el.firstChild);
  return el;
}

export function kennung(prefix = 'id') {
  return `${prefix}-${Math.random().toString(36).slice(2, 10)}`;
}

/** Zufallszahl 0…max-1, so unverfälscht wie das Gerät es hergibt. */
export function zufallszahl(max) {
  if (max <= 0) return 0;
  if (window.crypto && window.crypto.getRandomValues) {
    const grenze = Math.floor(0xffffffff / max) * max;
    const feld = new Uint32Array(1);
    do { window.crypto.getRandomValues(feld); } while (feld[0] >= grenze);
    return feld[0] % max;
  }
  return Math.floor(Math.random() * max);
}

/** Mischen nach Fisher-Yates — gibt eine neue Liste zurück. */
export function gemischt(liste) {
  const out = liste.slice();
  for (let i = out.length - 1; i > 0; i -= 1) {
    const j = zufallszahl(i + 1);
    [out[i], out[j]] = [out[j], out[i]];
  }
  return out;
}

export function entprellt(fn, wartezeit) {
  let timer = null;
  return function aufgerufen(...args) {
    if (timer) clearTimeout(timer);
    timer = setTimeout(() => { timer = null; fn.apply(null, args); }, wartezeit);
  };
}

export function warte(ms) {
  return new Promise((fertig) => setTimeout(fertig, ms));
}

/**
 * Code für Klasse und Beitritt: sechs Zeichen ohne I, O, 0 und 1 — die
 * verwechselt ein Kind beim Abtippen zuverlässig.
 */
export function beitrittscode() {
  const zeichen = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let out = '';
  for (let i = 0; i < 6; i += 1) out += zeichen[zufallszahl(zeichen.length)];
  return out;
}

/** Bewegungsreduzierung der Systemeinstellungen respektieren. */
export function wenigBewegung() {
  return Boolean(window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches);
}

let klangkontext = null;

export function tonkontext() {
  if (!klangkontext) {
    const Ctx = window.AudioContext || window.webkitAudioContext;
    if (!Ctx) return null;
    klangkontext = new Ctx();
  }
  if (klangkontext.state === 'suspended') klangkontext.resume().catch(() => {});
  return klangkontext;
}

/** Datum als „30.08.2026“. */
export function datum(zeit) {
  const d = new Date(zeit);
  const zwei = (n) => String(n).padStart(2, '0');
  return `${zwei(d.getDate())}.${zwei(d.getMonth() + 1)}.${d.getFullYear()}`;
}

/**
 * Text zum Vergleichen vorbereiten: Leerzeichen am Rand weg, mehrere
 * Leerzeichen zu einem. Groß- und Kleinschreibung bleibt — sie IST hier der
 * Lernstoff und darf nicht wegnormalisiert werden.
 */
export function geputzt(text) {
  return String(text || '').replace(/\s+/g, ' ').trim();
}

/**
 * Bequemlichkeiten der Tastaturen abfangen: typografische Anführungszeichen
 * und Bindestriche, die iOS und Android von selbst einsetzen. Ein Kind, dessen
 * Tastatur aus dem Bindestrich einen Gedankenstrich macht, hat sich nicht
 * verschrieben.
 */
export function entglaettet(text) {
  return String(text || '')
    .replace(/[‘’‚′]/g, "'")
    .replace(/[“”„″]/g, '"')
    .replace(/[‐‑‒–—]/g, '-')
    .replace(/ /g, ' ');
}

/** Erste Stelle, an der sich zwei Wörter unterscheiden (oder -1). */
export function ersteAbweichung(eingabe, ziel) {
  const laenge = Math.min(eingabe.length, ziel.length);
  for (let i = 0; i < laenge; i += 1) if (eingabe[i] !== ziel[i]) return i;
  return eingabe.length === ziel.length ? -1 : laenge;
}
