// Klänge — vollständig im Gerät erzeugt (Web Audio), ohne eine einzige
// Klangdatei. So bleibt die App klein, läuft ohne Netz und braucht in einer
// späteren nativen Hülle keine mitgelieferten Töne.
//
// Sparsam gehalten: fünf kurze Klänge, alle abstellbar. Eine Rechtschreibübung
// mit Dauergedudel ist nach zehn Minuten unerträglich — für die Kinder und
// für die Lehrkraft daneben.

import { tonkontext } from './util.js';
import { einstellungen } from './store.js';
import { haptik } from './plattform.js';

function an() {
  return einstellungen().klang !== false;
}

function ton({ frequenz = 440, dauer = 0.14, staerke = 0.09, art = 'sine', warten = 0, biegung = 0 } = {}) {
  try {
    const ctx = tonkontext();
    if (!ctx) return;
    const start = ctx.currentTime + warten;
    const osz = ctx.createOscillator();
    osz.type = art;
    osz.frequency.setValueAtTime(frequenz, start);
    if (biegung) osz.frequency.exponentialRampToValueAtTime(Math.max(50, frequenz + biegung), start + dauer);
    const huelle = ctx.createGain();
    huelle.gain.setValueAtTime(0.0001, start);
    huelle.gain.exponentialRampToValueAtTime(staerke, start + 0.012);
    huelle.gain.exponentialRampToValueAtTime(0.0001, start + dauer);
    osz.connect(huelle).connect(ctx.destination);
    osz.start(start);
    osz.stop(start + dauer + 0.04);
  } catch (_) {
    // Klang ist Beiwerk. Spielt das Gerät ihn nicht, läuft die Übung weiter.
  }
}

/** Richtig: eine kleine Terz aufwärts — freundlich, nicht triumphal. */
export function richtig() {
  haptik('erfolg');
  if (!an()) return;
  ton({ frequenz: 587.33, dauer: 0.12, staerke: 0.07, art: 'triangle' });
  ton({ frequenz: 880, dauer: 0.18, staerke: 0.06, art: 'triangle', warten: 0.09 });
}

/**
 * Falsch: ein kurzer, weicher Doppelton nach unten. Bewusst KEIN Summer —
 * das Kind hat sich verschrieben, nicht etwas kaputtgemacht.
 */
export function falsch() {
  haptik('fehler');
  if (!an()) return;
  ton({ frequenz: 320, dauer: 0.1, staerke: 0.06, art: 'sine' });
  ton({ frequenz: 247, dauer: 0.16, staerke: 0.05, art: 'sine', warten: 0.08 });
}

/** Ein Tastendruck, der weiterführt. */
export function tipp() {
  if (!an()) return;
  ton({ frequenz: 660, dauer: 0.05, staerke: 0.04, art: 'triangle' });
}

/** Päckchen geschafft: ein kleiner Dreiklang. */
export function fertig(sterne = 3) {
  haptik('erfolg');
  if (!an()) return;
  const grund = [523.25, 659.25, 783.99, 1046.5];
  const wieviele = Math.max(2, Math.min(4, sterne + 1));
  for (let i = 0; i < wieviele; i += 1) {
    ton({ frequenz: grund[i], dauer: 0.26, staerke: 0.06, art: 'triangle', warten: i * 0.11 });
  }
}

/** Ein Stern springt an. */
export function stern(nummer = 0) {
  if (!an()) return;
  ton({ frequenz: 880 + nummer * 220, dauer: 0.16, staerke: 0.05, art: 'sine' });
}
