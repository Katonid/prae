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

/** Alle deutschen Stimmen dieses Geräts — für die Auswahl in den Einstellungen. */
export function deutscheStimmen() {
  const liste = stimmen.length ? stimmen : stimmenLaden();
  return liste.filter((v) => String(v.lang).toLowerCase().startsWith('de'))
    .map((v) => ({ name: v.name, lang: v.lang, oertlich: !!v.localService }));
}

/**
 * Welche Stimme spricht?
 *
 * Welche deutschen Stimmen ein Gerät mitbringt, ist von Gerät zu Gerät völlig
 * verschieden — von der guten iOS-Stimme bis zur blechernen Notlösung eines
 * Linux-Browsers. Welche davon ein Kind versteht, kann die App nicht wissen;
 * deshalb lässt sie die Lehrkraft wählen (Einstellungen → Sprechstimme) und
 * merkt sich den Namen. Ohne Wahl gilt die alte Reihenfolge.
 *
 * `localService` zuerst: Eine Stimme aus dem Netz schweigt ohne Netz, und die
 * App verspricht, ohne Netz zu laufen.
 */
function deutscheStimme(wunsch) {
  const liste = stimmen.length ? stimmen : stimmenLaden();
  if (wunsch) {
    const gewaehlt = liste.find((v) => v.name === wunsch);
    if (gewaehlt) return gewaehlt;
  }
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
export function sprich(text, { tempo = 0.7, stimme: wunsch = '' } = {}) {
  const b = bruecke();
  if (b && typeof b.sprich === 'function') {
    try { b.sprich(String(text), tempo); return true; } catch (_) { /* weiter zum Web-Weg */ }
  }
  if (!window.speechSynthesis) return false;
  try {
    window.speechSynthesis.cancel();
    // Mit Punkt am Ende. Ein nacktes Wort behandeln die meisten Stimmen als
    // abgerissenes Bruchstück und nuscheln die letzte Silbe weg; mit
    // Satzzeichen sprechen sie es zu Ende und lassen die Stimme fallen — so,
    // wie eine Lehrkraft ein Diktatwort spricht.
    const roh = String(text).trim();
    const spruch = new window.SpeechSynthesisUtterance(/[.!?]$/.test(roh) ? roh : `${roh}.`);
    spruch.lang = 'de-DE';
    spruch.rate = tempo;
    // Neutrale Tonhöhe. Die früheren 1.05 klangen dünner und undeutlicher —
    // eine angehobene Stimme verliert gerade in den Vokalen an Fülle.
    spruch.pitch = 1;
    const stimme = deutscheStimme(wunsch);
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

/* ---------- QR-Code lesen (Beitritt zur Klasse) ---------- */

/**
 * Kann dieses Gerät einen QR-Code einlesen?
 *
 * Heute scannen die Kinder den Code mit der Kamera-App des iPads, die dann
 * Safari öffnet (`docs/woerterwerkstatt/ios.md`, Punkt 1). Auf einem
 * Schul-iPad im geführten Zugriff ist dieser Weg oft versperrt, und in einer
 * nativen Hülle gehört ein eigener Scanner hinein.
 *
 * Deshalb steht der Weg von der Kamera zum Code ab hier in der Brücke —
 * dieselbe Stelle, die später die Hülle bedient. Im Browser trägt ihn
 * `BarcodeDetector`: Chrome und Chromebooks können das, Safari nicht. Das ist
 * kein Grund, einen eigenen Decoder zu schreiben (der QR-Code wird in
 * `qr.js` nur GEZEICHNET, und Lesen ist die ungleich schwerere Hälfte) —
 * wer nicht scannen kann, tippt die sechs Zeichen ein. Dieser Weg bleibt der
 * wichtigste und wird durch den Knopf nicht ersetzt.
 */
export function kannScannen() {
  const b = bruecke();
  if (b && typeof b.qrScannen === 'function') return true;
  return Boolean(window.BarcodeDetector && navigator.mediaDevices
    && typeof navigator.mediaDevices.getUserMedia === 'function');
}

/**
 * Die Kamera öffnen und auf einen QR-Code warten.
 *
 * Gibt `{ gelesen, abbrechen }` zurück: `gelesen` ist ein Versprechen auf den
 * gefundenen Text oder `null` (abgebrochen, keine Erlaubnis, nichts gefunden),
 * `abbrechen()` macht die Kamera wieder zu. Die Kamera MUSS wieder zugehen —
 * eine Leuchte, die nach dem Schließen des Blattes weiterbrennt, erschreckt
 * zu Recht.
 *
 * Im Browser läuft das Bild in das übergebene `<video>`. Eine native Hülle
 * bringt ihre eigene Oberfläche mit und bekommt es gar nicht erst zu sehen;
 * sie stellt `qrScannen()` (Versprechen auf Text oder null) und, wenn sie mag,
 * `qrAbbrechen()` bereit.
 */
export function qrScannen(bild) {
  const b = bruecke();
  if (b && typeof b.qrScannen === 'function') {
    return {
      gelesen: Promise.resolve().then(() => b.qrScannen()).then((x) => (x ? String(x) : null)).catch(() => null),
      abbrechen: () => { try { if (typeof b.qrAbbrechen === 'function') b.qrAbbrechen(); } catch (_) { /* egal */ } },
    };
  }

  let laeuft = true;
  let strom = null;
  const abbrechen = () => {
    laeuft = false;
    if (!strom) return;
    strom.getTracks().forEach((spur) => { try { spur.stop(); } catch (_) { /* egal */ } });
    strom = null;
  };

  const gelesen = (async () => {
    if (!kannScannen()) return null;
    const leser = new window.BarcodeDetector({ formats: ['qr_code'] });
    // Die rückwärtige Kamera, sonst filmt das iPad das Kind statt der Tafel.
    strom = await navigator.mediaDevices.getUserMedia({ video: { facingMode: 'environment' } });
    if (!laeuft) { abbrechen(); return null; }
    bild.srcObject = strom;
    // Ohne `playsinline` reißt iOS das Video ins Vollbild und das Blatt
    // darunter ist weg.
    bild.setAttribute('playsinline', '');
    bild.muted = true;
    await bild.play().catch(() => {});
    while (laeuft) {
      try {
        const treffer = await leser.detect(bild);
        if (treffer && treffer.length && treffer[0].rawValue) {
          const text = String(treffer[0].rawValue);
          abbrechen();
          return text;
        }
      } catch (_) { /* ein einzelnes Bild zu verlieren ist belanglos */ }
      await new Promise((warte) => { setTimeout(warte, 200); });
    }
    return null;
  })().catch(() => { abbrechen(); return null; });

  return { gelesen, abbrechen };
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
