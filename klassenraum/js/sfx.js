// Klänge für das Auslosen — vollständig im Gerät erzeugt (Web Audio), damit
// die App ohne Netz und ohne Klangdateien auskommt.
//
// Grundlage ist gefiltertes Rauschen: Ein kurzer Rauschstoß klingt je nach
// Filter wie eine Karte, die über die Daumenkante läuft, wie ein Trommelschlag
// oder wie das Klacken eines Glücksrads.

import { audio, randomInt } from './util.js';

let noiseBuffer = null;

function noise(ctx) {
  if (noiseBuffer && noiseBuffer.sampleRate === ctx.sampleRate) return noiseBuffer;
  const length = Math.floor(ctx.sampleRate * 0.5);
  const buffer = ctx.createBuffer(1, length, ctx.sampleRate);
  const data = buffer.getChannelData(0);
  for (let i = 0; i < length; i += 1) data[i] = Math.random() * 2 - 1;
  noiseBuffer = buffer;
  return buffer;
}

/** Kurzer gefilterter Rauschstoß. */
export function noiseBurst({
  duration = 0.06, gain = 0.12, frequency = 2400, q = 1, type = 'bandpass', delay = 0, sweep = 0,
} = {}) {
  try {
    const ctx = audio();
    if (!ctx) return;
    const start = ctx.currentTime + delay;
    const source = ctx.createBufferSource();
    source.buffer = noise(ctx);
    source.playbackRate.value = 0.8 + Math.random() * 0.4;
    const filter = ctx.createBiquadFilter();
    filter.type = type;
    filter.frequency.setValueAtTime(Math.max(60, frequency), start);
    if (sweep) filter.frequency.exponentialRampToValueAtTime(Math.max(60, frequency + sweep), start + duration);
    filter.Q.value = q;
    const amp = ctx.createGain();
    amp.gain.setValueAtTime(0.0001, start);
    amp.gain.exponentialRampToValueAtTime(gain, start + 0.006);
    amp.gain.exponentialRampToValueAtTime(0.0001, start + duration);
    source.connect(filter).connect(amp).connect(ctx.destination);
    source.start(start);
    source.stop(start + duration + 0.02);
  } catch (_) {
    // Klang ist Beiwerk — spielt das Gerät ihn nicht, läuft alles andere weiter.
  }
}

/** Kurzer Ton mit Hüllkurve (für den Körper von Trommel und Klacken). */
function tone({ frequency = 200, duration = 0.08, gain = 0.08, type = 'sine', delay = 0, bend = 0 } = {}) {
  try {
    const ctx = audio();
    if (!ctx) return;
    const start = ctx.currentTime + delay;
    const osc = ctx.createOscillator();
    osc.type = type;
    osc.frequency.setValueAtTime(frequency, start);
    if (bend) osc.frequency.exponentialRampToValueAtTime(Math.max(40, frequency + bend), start + duration);
    const amp = ctx.createGain();
    amp.gain.setValueAtTime(0.0001, start);
    amp.gain.exponentialRampToValueAtTime(gain, start + 0.005);
    amp.gain.exponentialRampToValueAtTime(0.0001, start + duration);
    osc.connect(amp).connect(ctx.destination);
    osc.start(start);
    osc.stop(start + duration + 0.03);
  } catch (_) { /* siehe oben */ }
}

/* ---------- Die einzelnen Klangarten ---------- */

/**
 * Karten, die über die Daumenkante laufen. Einzelne Rauschstöße klingen zu
 * dünn — erst ein kleines Bündel dicht aufeinanderfolgender Stöße ergibt das
 * typische Rascheln eines Stapels, der durch die Finger läuft.
 */
function cardTick(progress = 0, delay = 0) {
  const flicks = progress < 0.75 ? 4 : 2;
  for (let i = 0; i < flicks; i += 1) {
    noiseBurst({
      duration: 0.028,
      gain: (0.34 - progress * 0.06) * (1 - i * 0.12),
      frequency: 1500 + randomInt(1800),
      q: 0.8,
      sweep: -700,
      delay: delay + i * (0.011 + Math.random() * 0.006),
    });
  }
}

/**
 * Trommelwirbel: tiefe Schläge. Solange der Wirbel schnell läuft, sitzen zwei
 * Schläge dicht beieinander — so klingt es nach Wirbel und nicht nach Klopfen.
 */
function drumTick(progress = 0, delay = 0) {
  const hits = progress < 0.6 ? 2 : 1;
  for (let i = 0; i < hits; i += 1) {
    const when = delay + i * 0.028;
    noiseBurst({ duration: 0.05, gain: (0.16 + progress * 0.12) * (1 - i * 0.25), frequency: 240, q: 1.3, delay: when });
    tone({
      frequency: 110, duration: 0.05, gain: (0.07 + progress * 0.05) * (1 - i * 0.25),
      type: 'triangle', bend: -35, delay: when,
    });
  }
}

/** Glücksrad: trockenes Klacken einer Ratsche. */
function wheelTick(delay = 0, gain = 0.42) {
  noiseBurst({ duration: 0.02, gain, frequency: 3200, q: 3.5, delay });
  tone({ frequency: 900, duration: 0.02, gain: gain * 0.24, type: 'square', bend: -260, delay });
}

/**
 * Kurzer Ratschenlauf (wie in der Tafelbild-App): mehrere Klicks, die
 * langsamer werden — der letzte fällt genau auf das Einrasten des Kärtchens.
 * `lead` ist die Gesamtdauer in Sekunden; der Aufruf erfolgt so früh vorher.
 */
export function wheelRun(lead = 0.32) {
  const steps = [0, 0.14, 0.3, 0.48, 0.72, 1];
  steps.forEach((fraction, index) => {
    const last = index === steps.length - 1;
    wheelTick(fraction * lead, last ? 0.45 : 0.2 + fraction * 0.14);
  });
}

export const SPIN_SOUNDS = [
  { id: 'karten', label: 'Kartenmischen', hint: 'Helles Rascheln, wie ein Kartenstapel, der durch die Finger läuft.' },
  { id: 'trommel', label: 'Trommelwirbel', hint: 'Tiefe, schnelle Schläge, die zum Schluss lauter werden.' },
  { id: 'rad', label: 'Glücksrad', hint: 'Trockenes Klacken, das mit dem Rad langsamer wird.' },
  { id: 'aus', label: 'Ohne Ton', hint: 'Beim Ziehen bleibt es still.' },
];

export function spinSoundById(id) {
  return SPIN_SOUNDS.find((entry) => entry.id === id) || SPIN_SOUNDS[0];
}

/**
 * Einen Schritt des Auslosens hörbar machen.
 * `progress` läuft von 0 (Start) bis 1 (letzter Schritt).
 */
export function spinTick(soundId, progress = 0, delay = 0) {
  if (soundId === 'aus') return;
  if (soundId === 'trommel') drumTick(progress, delay);
  else if (soundId === 'rad') wheelTick(delay);
  else cardTick(progress, delay);
}

/** Abschluss: Der Stapel wird aufgestoßen bzw. der Wirbel endet. */
export function spinEnd(soundId, delay = 0) {
  if (soundId === 'aus') return;
  if (soundId === 'trommel') {
    noiseBurst({ duration: 0.5, gain: 0.16, frequency: 3200, q: 0.5, type: 'highpass', delay });
    tone({ frequency: 90, duration: 0.22, gain: 0.1, type: 'triangle', bend: -40, delay });
    return;
  }
  if (soundId === 'rad') {
    noiseBurst({ duration: 0.05, gain: 0.45, frequency: 2600, q: 2.5, delay });
    return;
  }
  // Karten: zwei kurze Stöße — der Stapel wird auf dem Tisch gerade geklopft.
  noiseBurst({ duration: 0.07, gain: 0.34, frequency: 900, q: 0.9, delay });
  noiseBurst({ duration: 0.09, gain: 0.26, frequency: 700, q: 0.9, delay: delay + 0.085 });
}

/* ---------- Zählansicht (aus der Tafelbild-App) ---------- */

/** Kassenglocke beim Hochzählen: heller Doppelklang mit kurzem Anschlag. */
export function countUp(delay = 0) {
  noiseBurst({ duration: 0.025, gain: 0.1, frequency: 5200, q: 1.1, delay });
  tone({ frequency: 1568, duration: 0.34, gain: 0.16, type: 'sine', delay });
  tone({ frequency: 2349, duration: 0.26, gain: 0.09, type: 'sine', delay: delay + 0.012 });
}

/** Wisch beim Zurücknehmen: kurzes, abfallendes Kratzen. */
export function countDown(delay = 0) {
  noiseBurst({ duration: 0.16, gain: 0.2, frequency: 2100, q: 0.7, sweep: -1400, delay });
}

/* ---------- Benachrichtigungsklänge (z. B. Timer-Ende) ---------- */

export const END_SOUNDS = [
  { id: 'dreiklang', label: 'Dreiklang', hint: 'Der vertraute helle Wechselton.' },
  { id: 'gong', label: 'Gong', hint: 'Ein tiefer, ruhig ausklingender Schlag.' },
  { id: 'glocke', label: 'Glocke', hint: 'Drei helle Glockenschläge.' },
  { id: 'xylophon', label: 'Xylophon', hint: 'Eine kurze, aufsteigende Tonfolge.' },
];

export function endSoundById(id) {
  return END_SOUNDS.find((entry) => entry.id === id) || END_SOUNDS[0];
}

/** Benachrichtigungsklang abspielen — vollständig im Gerät erzeugt. */
export function playEndSound(id, delay = 0) {
  if (id === 'gong') {
    noiseBurst({ duration: 0.12, gain: 0.16, frequency: 480, q: 0.7, delay });
    tone({ frequency: 165, duration: 1.9, gain: 0.26, type: 'sine', delay });
    tone({ frequency: 221, duration: 1.5, gain: 0.12, type: 'sine', delay: delay + 0.012 });
    tone({ frequency: 87, duration: 2.1, gain: 0.18, type: 'triangle', delay });
    return;
  }
  if (id === 'glocke') {
    for (let i = 0; i < 3; i += 1) {
      const when = delay + i * 0.5;
      tone({ frequency: 880, duration: 0.9, gain: 0.2, type: 'sine', delay: when });
      tone({ frequency: 1760, duration: 0.5, gain: 0.08, type: 'sine', delay: when });
      tone({ frequency: 2637, duration: 0.28, gain: 0.05, type: 'sine', delay: when });
    }
    return;
  }
  if (id === 'xylophon') {
    [523, 659, 784, 1047].forEach((frequency, index) => {
      tone({ frequency, duration: 0.3, gain: 0.2, type: 'triangle', delay: delay + index * 0.16 });
      tone({ frequency: frequency * 3, duration: 0.08, gain: 0.05, type: 'sine', delay: delay + index * 0.16 });
    });
    return;
  }
  // Dreiklang (Vorgabe) — wie der bisherige Signalton.
  for (let i = 0; i < 4; i += 1) {
    tone({ frequency: i % 2 === 0 ? 880 : 1180, duration: 0.24, gain: 0.22, type: 'sine', delay: delay + i * 0.32 });
  }
}

/**
 * Hörprobe für die Einstellungen — dieselbe Abfolge wie beim Ziehen,
 * aber im Voraus geplant (das ist genauer als Zeitgeber im Hintergrund).
 */
export function previewSpinSound(soundId, steps = 12, offset = 0) {
  if (soundId === 'aus') return 0;
  let time = offset;
  for (let i = 0; i < steps; i += 1) {
    const progress = i / (steps - 1);
    spinTick(soundId, progress, time);
    time += (45 + Math.pow(progress, 2.4) * 165) / 1000;
  }
  spinEnd(soundId, time);
  return time;
}
