// Die Brücke zur Plattform.
//
// Alles, was NICHT reines HTML ist — Sprachausgabe, Vibration, Vollbild,
// „darf ich in die Zwischenablage schreiben“ — läuft über diese eine Datei.
// Der Grund steht in docs/woerterwerkstatt/ios.md: Soll aus der App später
// eine native iOS-App werden, ist das hier die einzige Stelle, die eine Hülle
// (WKWebView) bedienen muss. Ruft die Oberfläche dagegen überall direkt
// `speechSynthesis` und `navigator.vibrate` auf, muss man die halbe App
// durchsuchen.
//
// Meldet sich eine Hülle über `window.wwBruecke`, wird sie bevorzugt; sonst
// nimmt jede Funktion den Web-Weg. Fehlt beides, tut sie still nichts — ein
// fehlender Klang darf nie eine Übung anhalten.

const bruecke = () => (window.wwBruecke && typeof window.wwBruecke === 'object' ? window.wwBruecke : null);

/** Läuft die App in einer nativen Hülle? */
export function nativ() {
  return Boolean(bruecke());
}

/** Läuft die App vom Homescreen (iOS) bzw. als installierte App? */
export function alsApp() {
  if (nativ()) return true;
  if (window.navigator.standalone === true) return true;
  return Boolean(window.matchMedia && window.matchMedia('(display-mode: standalone)').matches);
}

/* ---------- Sprachausgabe (Diktat) ---------- */

let stimmen = [];

function stimmenLaden() {
  if (!window.speechSynthesis) return [];
  stimmen = window.speechSynthesis.getVoices() || [];
  return stimmen;
}

if (window.speechSynthesis) {
  stimmenLaden();
  window.speechSynthesis.addEventListener('voiceschanged', stimmenLaden);
}

/** Gibt es überhaupt eine deutsche Stimme? Danach richtet sich die Diktatübung. */
export function kannSprechen() {
  if (nativ() && typeof bruecke().sprich === 'function') return true;
  if (!window.speechSynthesis) return false;
  // Manche Geräte melden die Stimmen erst nach dem ersten Sprechversuch —
  // deshalb gilt die vorhandene Schnittstelle bereits als „geht wohl“.
  return true;
}

function deutscheStimme() {
  const liste = stimmen.length ? stimmen : stimmenLaden();
  return liste.find((v) => v.lang === 'de-DE' && v.localService)
    || liste.find((v) => v.lang === 'de-DE')
    || liste.find((v) => String(v.lang).startsWith('de'))
    || null;
}

/**
 * Ein Wort vorlesen. Gibt zurück, ob es losging — die Übung braucht das, um
 * ehrlich „Dieses Gerät kann nicht vorlesen“ sagen zu können, statt das Kind
 * auf eine Stille warten zu lassen.
 */
export function sprich(text, { tempo = 0.85 } = {}) {
  const b = bruecke();
  if (b && typeof b.sprich === 'function') {
    try { b.sprich(String(text), tempo); return true; } catch (_) { /* weiter zum Web-Weg */ }
  }
  if (!window.speechSynthesis) return false;
  try {
    window.speechSynthesis.cancel();
    const spruch = new window.SpeechSynthesisUtterance(String(text));
    spruch.lang = 'de-DE';
    spruch.rate = tempo;
    spruch.pitch = 1.05;
    const stimme = deutscheStimme();
    if (stimme) spruch.voice = stimme;
    window.speechSynthesis.speak(spruch);
    return true;
  } catch (_) {
    return false;
  }
}

export function schweig() {
  const b = bruecke();
  if (b && typeof b.schweig === 'function') { try { b.schweig(); } catch (_) { /* egal */ } }
  if (window.speechSynthesis) { try { window.speechSynthesis.cancel(); } catch (_) { /* egal */ } }
}

/* ---------- Kleine Rückmeldungen ---------- */

/** Kurzes Rütteln — auf iOS im Browser gibt es das nicht, in der Hülle schon. */
export function haptik(art = 'leicht') {
  const b = bruecke();
  if (b && typeof b.haptik === 'function') { try { b.haptik(art); return; } catch (_) { /* weiter */ } }
  if (navigator.vibrate) {
    const muster = art === 'fehler' ? [18, 40, 18] : (art === 'erfolg' ? [12, 30, 12] : [10]);
    try { navigator.vibrate(muster); } catch (_) { /* egal */ }
  }
}

export async function inZwischenablage(text) {
  const b = bruecke();
  if (b && typeof b.kopiere === 'function') { try { b.kopiere(String(text)); return true; } catch (_) { /* weiter */ } }
  try {
    await navigator.clipboard.writeText(String(text));
    return true;
  } catch (_) {
    return false;
  }
}

/**
 * Der Bildschirm soll während einer Übung nicht schlafen gehen — ein Kind
 * denkt beim Schreiben auch mal eine Minute nach.
 */
let wachSperre = null;

export async function bleibWach(an) {
  const b = bruecke();
  if (b && typeof b.bleibWach === 'function') { try { b.bleibWach(Boolean(an)); return; } catch (_) { /* weiter */ } }
  try {
    if (an && navigator.wakeLock && !wachSperre) {
      wachSperre = await navigator.wakeLock.request('screen');
      wachSperre.addEventListener('release', () => { wachSperre = null; });
    } else if (!an && wachSperre) {
      await wachSperre.release();
      wachSperre = null;
    }
  } catch (_) {
    wachSperre = null;
  }
}

/**
 * Vollbild für den Beamer. In einer nativen Hülle gibt es kein Vollbild —
 * dort IST die App schon Vollbild, also passiert nichts.
 */
export function vollbild(an) {
  if (nativ()) return;
  try {
    if (an && document.documentElement.requestFullscreen) document.documentElement.requestFullscreen();
    else if (!an && document.exitFullscreen && document.fullscreenElement) document.exitFullscreen();
  } catch (_) { /* manche Browser verbieten es ohne Geste */ }
}
